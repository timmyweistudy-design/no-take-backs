extends "res://scripts/ui/codex_view.gd"
## 回味（第三輪 S5）：重播控制、對戰代碼、覆盤。
## ・重播控制（F2）：重播與覆盤的戰鬥底部有控制列：暫停、0.5／1／2 倍速、點時間軸跳到任一秒（從頭快轉，
##   展示與音效狀態全部清空重建）、點一隻兵讓鏡頭跟它（再點空地取消）。
## ・對戰代碼（F3）：結果頁複製；標題「觀看對戰代碼」從剪貼簿讀，版本不同會提示。
## ・覆盤（F1）：只限「對 AI」。結果頁按「覆盤」，改一隻兵（換兵種、移一格或拿掉），按「重算」並排兩條時間軸；
##   可以「播放如果」看那一場。覆盤只看不算：比分、進度、成就、日誌都不寫（副作用矩陣 review）。

const BattleCode = preload("res://scripts/game/battle_code.gd")
const RC_BAR := Rect2(330, 708, 900, 28)   # 時間軸拖曳條

# 覆盤狀態
var rv_army = null          # 正在改的藍方陣型
var rv_orig = null          # 原本的藍方陣型
var rv_enemy = null         # 對手陣型（不變）
var rv_sel := Vector2i(-1, -1)
var rv_result := {}         # {winner, rem, log}
var rv_base := {}           # 原本那一場（打開覆盤時用同一組陣型重算，不依賴目前的 sim）
var rv_div := -1            # V1.4 #1 時光機：原本與如果第一次不一樣的 tick（-1＝還沒算或完全一樣）
var rv_last: Array = []     # 覆盤播放用的雙方陣型（重播覆盤時用）


# ── 重播控制 ──
func _replay_controls_active() -> bool:
	return state == St.BATTLE and play_kind != "official" and view != null

func _draw_replay_controls() -> void:
	if not _replay_controls_active():
		return
	draw_rect(Rect2(0, 696, 1280, 52), Color(TH_WOOD_D, 0.94))
	_btn(Rect2(20, 704, 70, 36), "▶" if paused else "Ⅱ", func(): paused = not paused)
	# V1.5.1：速度 −／目前／＋，走 0.25～8 倍的共用表（點中間回 1 倍）
	_btn(Rect2(98, 704, 68, 36), "−", func(): speed = speed_step(speed, -1), speed > float(SPEEDS[0]))
	_btn(Rect2(172, 704, 68, 36), "%s×" % _fmt_num(speed), func(): speed = 1.0, true, false, Color(0.45, 0.3, 0.12))
	_btn(Rect2(246, 704, 68, 36), "+", func(): speed = speed_step(speed, 1), speed < float(SPEEDS[SPEEDS.size() - 1]))
	# 時間軸：拉鋸色帶（模擬已跑到的部分）＋目前位置
	var total := float(maxi(1, replay_total if replay_total > 0 else view.max_ticks))   # 以這一場實際長度為滿
	draw_rect(RC_BAR, Color(0, 0, 0, 0.5))
	var tot := 1000.0
	var n: int = sim.power_log.size()
	for i in int(RC_BAR.size.x / 3.0):
		var t := int(i * 3.0 / RC_BAR.size.x * total)
		if t >= n:
			break
		var d: float = clampf(float(sim.diff_permille(t)) / tot * 2.0, -1.0, 1.0)
		var h := absf(d) * RC_BAR.size.y / 2.0
		draw_rect(Rect2(RC_BAR.position.x + i * 3.0, RC_BAR.get_center().y - (h if d > 0 else 0.0), 3.0, h), Color(Art.team_color(0 if d > 0 else 1, cbm()), 0.8))
	var cx := RC_BAR.position.x + RC_BAR.size.x * clampf(float(view.tick) / total, 0.0, 1.0)
	draw_line(Vector2(cx, RC_BAR.position.y - 3), Vector2(cx, RC_BAR.end.y + 3), ACCENT, 3.0)
	var hz := fit(L.t("rc_hint"), tz("C"), 560)   # V1.2.1 B2：走字級表
	var hw := font.get_string_size(L.t("rc_hint"), HORIZONTAL_ALIGNMENT_LEFT, -1, hz).x
	_text(Vector2(RC_BAR.end.x - hw, RC_BAR.position.y - hz * 1.5), L.t("rc_hint"), hz, TXT_DIM)
	# 第七輪 A7：時間軸上的關鍵時刻刻度
	for m in replay_marks:
		var mx := RC_BAR.position.x + RC_BAR.size.x * clampf(float(m["t"]) / total, 0.0, 1.0)
		draw_line(Vector2(mx, RC_BAR.position.y), Vector2(mx, RC_BAR.end.y), Color("#ffd166"), 2.0)
		draw_colored_polygon(PackedVector2Array([Vector2(mx - 5, RC_BAR.position.y - 7), Vector2(mx + 5, RC_BAR.position.y - 7), Vector2(mx, RC_BAR.position.y)]), Color("#ffd166"))
	# 整條是一個按鈕：點哪裡就跳到哪一秒
	_btns.append({"r": RC_BAR, "cb": func(): _seek_async(int(clampf((mouse.x - RC_BAR.position.x) / RC_BAR.size.x, 0.0, 1.0) * total)), "en": true})
	_text(Vector2(RC_BAR.position.x, RC_BAR.end.y + 2), L.t("rc_time", [view.tick / 20.0, total / 20.0]), tz("C"), TXT_DIM)   # V1.2.1 B2／G3：字級表＋字串表
	if play_kind == "review":
		_text(Vector2(640, 92), L.t("review_tag"), ts(16), ACCENT, true, true, 600)
		if tm_ghost != null:
			_text(Vector2(640, 92 + ts(16) * 1.4), L.t("tm_ghost_hint"), tz("C"), TXT_DIM, true, false, 600)
	if play_kind == "replay" and DisplayServer.get_name() != "headless":
		# V1.4 #14：錄 3 秒 GIF（從現在開始播 3 秒，320×172、10 fps）
		if gif_frames.is_empty() and gif_thread == null:
			_btn(Rect2(350, 650, 220, 40), L.t("gif_btn"), func(): gif_on = true; paused = false)
		else:
			_text(Vector2(360, 658), L.t("gif_rec", [gif_frames.size(), GIF_N]) if gif_thread == null else L.t("gif_busy_n", [int(gif_ctl.get("done", 0)), GIF_N]), tz("S"), Color("#ff8a8a"), false, true, 260)
	if play_kind == "review":
		pass
	elif paused and play_kind == "replay" and mode == Mode.VS_AI and last_armies.size() == 2 and not watch_mode:
		# V1.4 #1 時光機：重播暫停時，從這裡回到開戰前改一隻兵
		btn_paper = true   # 羊皮紙按鈕：像翻開推演筆記，不是系統按鈕（Antigravity v140-i1）
		_btn(Rect2(20, 650, 320, 40), L.t("tm_btn"), func(): _open_review())
		btn_paper = false
	if follow_id >= 0:
		_text(Vector2(640, 92 + ts(16) * 1.4), L.t("rc_following"), ts(14), Color(1, 1, 1, 0.85), true, false, 600)

## 跳到某個 tick：同一組陣型從頭快轉（確定性模擬，結果一定一樣），畫面與音效狀態清空重建。
func _seek(target: int) -> void:
	_seek_begin(target)
	while not _seek_tick(1000000):
		pass
	_seek_finish()


## 第七輪 M3：時間軸點下去不再卡畫面，分批算。headless 測試直接走 _seek。
var _seek_stop := 0
var _seek_ct := -1

func _seek_async(target: int) -> void:
	if seek_target >= 0:
		return
	if DisplayServer.get_name() == "headless" or shot_dir != "":
		_seek(target)
		return
	seek_target = target
	_seek_begin(target)

## 這一幀還在算就回傳 true（戰鬥畫面這一幀不動）。
func _seek_pump() -> bool:
	if seek_target < 0:
		return false
	if _seek_tick(10):
		seek_target = -1
		_seek_finish()
	return true

func _seek_begin(target: int) -> void:
	var armies2: Array = rv_last if play_kind == "review" and not rv_last.is_empty() else last_armies
	sim = Sim.new(armies2[0].copy(), armies2[1].copy(), battle_rules)
	call("_cmd_setup", sim, play_kind)
	ev_count = {}
	set("last_blast_tick", -99)
	_seek_ct = -1
	_seek_deaths = {}
	battle_marks.clear()
	var dl: int = ViewBuffer.DELAY if (bool(sim.get("cmd_on")) and not bool(sim.get("cmd_scripted"))) else ViewBuffer.DELAY_LONG   # 和 ViewBuffer 的選法一樣
	_seek_stop = maxi(0, target - (view.delay if view != null else dl))
	_seek_target_now = target

var _seek_target_now := 0
var _seek_deaths := {}   # V1.5.1 B2：快轉時誰在哪個 tick 倒下（跳轉後重建陣亡小旗）

## 算到時間用完或到達目標；到達回傳 true。
func _seek_tick(budget_ms: int) -> bool:
	var t0 := Time.get_ticks_msec()
	while sim.tick < _seek_stop and not sim.finished:
		if Time.get_ticks_msec() - t0 >= budget_ms:
			return false
		sim.step()
		for ev in sim.events:   # 快轉時也要累計戰報次數與時間軸標記（Codex S5 #4：共用同一個收集函式）
			if ev.has("src"):
				var s = sim.unit_by_id(ev["src"])
				var key := "%s%d" % [ev["kind"], s.team]
				ev_count[key] = int(ev_count.get(key, 0)) + 1
				if ev["kind"] == EV.BLAST and not ev.has("dmg"):
					ev_count["blast_fx%d" % s.team] = int(ev_count.get("blast_fx%d" % s.team, 0)) + 1
			_collect_mark(ev, sim, sim.tick)
			if ev["kind"] == EV.DEATH:
				_seek_deaths[int(ev["id"])] = sim.tick
			if ev["kind"] == EV.CMD:
				battle_marks.append({"tick": sim.tick, "kind": "cmd", "team": int(ev["team"]), "skill": int(ev["skill"])})   # V1.5.1：快轉也收軍令標記（原本跳轉後會漏）
		if _seek_ct < 0 and not sim.finished and clutch_cond(sim):
			_seek_ct = sim.tick
	return true

func _seek_finish() -> void:
	call_deferred("_tm_sync")
	var target := _seek_target_now
	var keep_ct := _seek_ct
	var had_clutch := keep_ct >= 0
	view = ViewBuffer.new(sim)
	prev_pos.clear()
	_gait_reset()
	for u in view.units:
		prev_pos[u.id] = Vector2(u.x, u.y)
	fx.clear()
	dying.clear()
	graves.clear()
	# V1.5.1 B2：跳轉前 1～4 秒倒下的兵，陣亡小旗照時間補回（倒地 1 秒後插旗、旗子留 3 秒）
	for did in _seek_deaths:
		var age: float = float(target - int(_seek_deaths[did])) / 20.0
		var dv = view.unit_by_id(int(did))
		if dv != null and age >= 1.0 and age < 4.0:
			graves.append({"pos": _upos(dv), "team": dv.team, "t": age - 1.0})
		elif dv != null and age >= 0.0 and age < 1.0:
			# 不到一秒前倒下：倒地演出接著播完，跨過 1 秒照常插旗（Codex v151-i2 #1）
			dying.append({"pos": _upos(dv), "type": dv.type, "team": dv.team, "face": signf(dv.fx) if dv.fx != 0 else 1.0, "t": age})
	atk_hit.clear()
	atk_seq.clear()
	alt_hit.clear()
	proj_tgt.clear()   # V1.5：跳轉不能留舊的飛行目標（Antigravity v150-i1 #1）
	atk_t.clear()
	hurt_t.clear()
	hurt_dir.clear()
	brace_t.clear()
	accum = 0.0
	result_delay = 0.0
	clutch_t = 0.0
	slow_left = 0.0
	final_left = 0.0     # Codex v10-r1 #4：跳回前段不能留著慢動作，再播到末擊要再演
	final_used = false
	key_used = false
	key_t = -10.0
	last_kill = [-1, -10.0]
	last_hitter.clear()
	hitstop = 0.0
	# 演出狀態依目標時間重建（Codex S5 #5）：最後時刻是否已發生、是否已進狂熱、音樂
	slow_used = had_clutch
	clutch_tick = keep_ct if had_clutch else -1
	if had_clutch:
		battle_marks.append({"tick": keep_ct, "kind": "clutch", "team": -1})
	_pump_view()
	# 畫面推到剛好第 target tick（原本停在 target−DELAY）
	while view.tick < target and not view.finished:
		_sim_step(false)
	frenzy_seen = view.frenzy
	if sfx != null:
		sfx.play_music("music_frenzy" if view.frenzy else "music_battle")

## 點戰場上的兵：鏡頭跟著它；點空地取消。
func _battle_click(p: Vector2) -> void:
	if not _replay_controls_active() and not (paused and state == St.BATTLE):
		return
	var world := _cam.affine_inverse() * p
	var best := -1
	var bd := 40.0
	for u in view.units:
		if u.alive:
			var d := _upos(u).distance_to(world + Vector2(0, 20))
			if d < bd:
				bd = d
				best = u.id
	follow_id = best
	if play_kind == "official":
		return   # 正式對局暫停時只看資料，不動鏡頭
	if best < 0:
		zoom_target = 1.0   # 取消跟拍：回到全景（中心由 _battle_process 拉回）

## 暫停（第七輪 A6）：正式對局也能停下來看；繼續時放掉選取。
func _toggle_pause() -> void:
	paused = not paused
	if not paused and play_kind == "official":
		follow_id = -1


## 進重播前存結算畫面（第七輪 A9）。
func _replay_snapshot() -> void:
	if play_kind != "official" and not replay_snap.is_empty():
		return   # Codex r2：重播完再重播，返回目的地還是最早那個結算
	replay_snap = {"sim": sim, "view": view, "report": report, "marks": battle_marks.duplicate(true), "kind": play_kind,
		"tab": result_tab, "overlay": "", "ev_count": ev_count.duplicate(), "pt_rated": pt_rated, "pt_call": pt_call_tick}

## 重播的「返回」：回到進來的地方。只還原畫面，比分、進度、成就、試玩紀錄都不寫。
func _replay_back() -> void:
	tm_ghost = null   # V1.4 #1：回到結果頁，原本時間線的淡圈不能留下
	call("_pre_drop")
	seek_target = -1   # Codex r1：算到一半返回，不能把下一場快轉到舊目標
	skip_busy = false
	paused = false
	follow_id = -1
	zoom = 1.0
	zoom_target = 1.0
	fx.clear()
	dying.clear()
	report_log.clear()
	sfx.set_muffled(false)
	if watch_mode or replay_snap.is_empty():
		call("_go_title")
		return
	sim = replay_snap["sim"]
	view = replay_snap["view"]
	report = replay_snap["report"]
	battle_marks = replay_snap["marks"]
	play_kind = replay_snap["kind"]
	result_tab = replay_snap["tab"]
	ev_count = replay_snap["ev_count"]   # Codex r1：戰報、評分狀態也要還原，不然同一局能再評一次
	pt_rated = replay_snap["pt_rated"]
	pt_call_tick = replay_snap["pt_call"]
	overlay = replay_snap["overlay"]
	result_delay = 0.0
	state = St.RESULT
	replay_snap = {}


## 從關鍵時刻開始重播（第七輪 A7）。
func _replay_from(t: int) -> void:
	call("_replay")
	_seek_async(t)


func _follow_update(delta: float) -> void:
	if play_kind == "official":
		return
	if follow_id < 0 or view == null or state != St.BATTLE:
		return
	var u = view.unit_by_id(follow_id)
	if u == null or not u.alive:
		follow_id = -1
		return
	zoom_target = 1.45
	zoom_center = zoom_center.lerp(_upos(u), minf(1.0, delta * 6.0))
	zoom = lerpf(zoom, zoom_target, minf(1.0, delta * 4.0))


# ── 對戰代碼 ──
func _copy_battle_code() -> void:
	var armies2: Array = rv_last if play_kind == "review" and not rv_last.is_empty() else last_armies
	DisplayServer.clipboard_set(BattleCode.encode(armies2[0], armies2[1], battle_rules, last_cmds))
	_toast(L.t("bc_copied"))

func _watch_battle_code() -> void:
	_watch_code_str(DisplayServer.clipboard_get())

## 手把：剪貼簿沒有代碼時改開 Steam 鍵盤；沒有 Steam 就提示（第七輪 N4）。
func _watch_code_str(code: String) -> void:
	var r := BattleCode.decode(code)
	if not r["ok"]:
		if code == DisplayServer.clipboard_get() and _ask_code(L.t("bc_watch"), _watch_code_str):
			return
		_toast(L.t("bc_bad"), true)
		return
	# 試玩版：對戰代碼裡有正式版才有的兵種就不播（Codex 實作審查 #2）
	if _demo():
		if r["rules"] != null and not r["rules"].map_id in Presets.DEMO_MAPS:
			_toast(L.t("bc_demo_locked"), true)
			return
		for a in [r["a0"], r["a1"]]:
			for u in a.units:
				if not RS.available(int(u["type"]), true):
					_toast(L.t("bc_demo_locked"), true)
					return
	if r["mismatch"]:
		_toast(L.t("bc_mismatch"))
	last_cmds = r.get("cmds", [])
	watch_code(r["a0"], r["a1"], r.get("rules"))

## 看一場對戰代碼：當成全新的一局初始化（Codex S5 #2：原本沿用舊的陣型、比分、局數）
func watch_code(a0, a1, p_rules = null) -> void:
	replay_marks = []   # V1.5.1：看別人的代碼不能留上一局的時間軸刻度（Codex v151-i2）
	mode = Mode.VS_AI
	rules = p_rules
	battle_rules = p_rules
	ai_name = ""
	overlay = ""
	armies = [a0.copy(), a1.copy()]
	wins = [0, 0]
	round_no = 1
	series_over = false
	last_player_formation = []
	last_armies = [a0.copy(), a1.copy()]
	rv_last = []
	_begin_battle(a0.copy(), a1.copy(), "replay")
	watch_mode = true


# ── 覆盤 ──
var rv_fsel := -1   # 第六輪：自由陣型覆盤選中的那一隻（索引）

func _open_review() -> void:
	rv_orig = last_armies[0].copy()
	rv_army = last_armies[0].copy()
	rv_enemy = last_armies[1].copy()
	rv_fsel = -1
	if rv_orig.deploy == "free":
		# 編輯識別（和戰鬥編號分開，Codex 第一輪）：覆盤時每隻帶 eid，「只改一隻」依 eid 比
		for i in rv_orig.units.size():
			rv_orig.units[i]["eid"] = i
			rv_army.units[i]["eid"] = i
		# 全場：搬移時也要守敵距
		var ep: Array = []
		for u in rv_enemy.units:
			ep.append(Army.pos_of(u))
		if rv_orig.depth > rv_orig.fw / 2:
			rv_army.enemy_pos = ep
			rv_orig.enemy_pos = ep.duplicate()
	rv_sel = Vector2i(-1, -1)
	_rv_dirty()
	rv_base = review_run(rv_orig, rv_enemy, battle_rules, last_cmds)
	_open("review")

## 跟原本比改了幾隻（換兵種、移位、拿掉、新增都算一隻）。
static func review_changes(orig, now) -> int:
	if orig.deploy == "free":
		var ma := {}
		for u in orig.units:
			ma[int(u.get("eid", -1))] = [int(u["type"]), int(u["x"]), int(u["y"])]
		var n := 0
		var seen := {}
		for u in now.units:
			var e := int(u.get("eid", -1))
			seen[e] = true
			if not ma.has(e) or ma[e] != [int(u["type"]), int(u["x"]), int(u["y"])]:
				n += 1
		for e in ma:
			if not seen.has(e):
				n += 1
		return n
	var a := {}
	var b := {}
	for u in orig.units:
		a["%d,%d" % [u["col"], u["row"]]] = int(u["type"])
	for u in now.units:
		b["%d,%d" % [u["col"], u["row"]]] = int(u["type"])
	var gone := 0
	var added := 0
	for k in a:
		if not b.has(k) or b[k] != a[k]:
			gone += 1
	for k in b:
		if not a.has(k) or a[k] != b[k]:
			added += 1
	return maxi(gone, added)

func _rv_try(edit: Callable) -> void:
	var before = rv_army.copy()
	edit.call()
	if review_changes(rv_orig, rv_army) > 1:
		rv_army = before
		_toast(L.t("rv_one"), true)
		return
	_rv_dirty()

func _rv_cell(c: Vector2i) -> void:
	if rv_sel.x >= 0 and rv_army.index_at(rv_sel.x, rv_sel.y) != -1 and rv_army.index_at(c.x, c.y) == -1:
		var from := rv_sel
		_rv_try(func(): rv_army.move(from.x, from.y, c.x, c.y))
		rv_sel = c
		return
	rv_sel = c

## 第六輪：自由陣型覆盤——點小戰場：點到兵就選它；選了之後點空地就搬過去。
func _rv_free_click(w: Vector2i) -> void:
	var hit: int = rv_army.index_near(w.x, w.y, 450)
	if hit >= 0:
		rv_fsel = hit
		return
	if rv_fsel < 0:
		return
	var trial = rv_army.copy()
	if not trial.move_xy(rv_fsel, trial.world_x(Army.quant(trial.own_x(w.x))), Army.quant(w.y)):
		_toast(L.t("err_zone"), true)
		return
	if review_changes(rv_orig, trial) > 1:
		_toast(L.t("rv_one"), true)
		return
	rv_army = trial
	_rv_dirty()

func _rv_free_set_type(t: int) -> void:
	if rv_fsel < 0 or rv_fsel >= rv_army.units.size():
		return
	var trial = rv_army.copy()
	var u: Dictionary = trial.units[rv_fsel]
	var p := Vector2i(int(u["x"]), int(u["y"]))
	trial.units.remove_at(rv_fsel)
	if t >= 0:
		trial.guard_combat = false
		if trial.check_place_xy(t, p.x, p.y) != "":
			_toast(L.t("rv_cant", [L.t("unit_%d" % t)]), true)
			return
		trial.units.insert(rv_fsel, {"type": t, "x": p.x, "y": p.y, "eid": u.get("eid", -1)})
	if review_changes(rv_orig, trial) > 1:
		_toast(L.t("rv_one"), true)
		return
	rv_army = trial
	if t < 0:
		rv_fsel = -1
	_rv_dirty()

func _rv_set_type(t: int) -> void:
	if rv_orig.deploy == "free":
		_rv_free_set_type(t)
		return
	if rv_sel.x < 0:
		return
	# 在副本上換，買不起或不合法就保留原兵並提示（Codex S5 #3：原本會變成直接刪兵）
	var c := rv_sel
	var trial = rv_army.copy()
	trial.remove_at(c.x, c.y)
	if t >= 0:
		var why: String = trial.check_place(t, c.x, c.y)
		if why != "":
			_toast(L.t("rv_cant", [L.t("unit_%d" % t)]), true)
			return
		trial.place(t, c.x, c.y)
	if review_changes(rv_orig, trial) > 1:
		_toast(L.t("rv_one"), true)
		return
	rv_army = trial
	_rv_dirty()

## 改了什麼（給畫面顯示）：例如「弓箭手 → 劍士（第 3 列第 5 欄）」
func review_desc() -> String:
	if rv_orig.deploy == "free":
		for u in rv_orig.units:
			var e := int(u.get("eid", -1))
			var now = null
			for v in rv_army.units:
				if int(v.get("eid", -2)) == e:
					now = v
			if now == null:
				return L.t("rv_f_removed", [L.t("unit_%d" % int(u["type"]))])
			if int(now["type"]) != int(u["type"]):
				return L.t("rv_f_swapped", [L.t("unit_%d" % int(u["type"])), L.t("unit_%d" % int(now["type"]))])
			if int(now["x"]) != int(u["x"]) or int(now["y"]) != int(u["y"]):
				return L.t("rv_f_moved", [L.t("unit_%d" % int(u["type"])), Vector2(int(now["x"]) - int(u["x"]), int(now["y"]) - int(u["y"])).length() / 1000.0])
		return ""
	for u in rv_orig.units:
		var i: int = rv_army.index_at(u["col"], u["row"])
		if i == -1:
			# 被移走或拿掉
			for v in rv_army.units:
				if rv_orig.index_at(v["col"], v["row"]) == -1 and int(v["type"]) == int(u["type"]):
					return L.t("rv_moved", [L.t("unit_%d" % int(u["type"])), absi(int(v["col"]) - int(u["col"]))])
			return L.t("rv_removed", [L.t("unit_%d" % int(u["type"]))])
		if int(rv_army.units[i]["type"]) != int(u["type"]):
			return L.t("rv_swapped", [L.t("unit_%d" % int(u["type"])), L.t("unit_%d" % int(rv_army.units[i]["type"]))])
	for v in rv_army.units:
		if rv_orig.index_at(v["col"], v["row"]) == -1:
			return L.t("rv_added", [L.t("unit_%d" % int(v["type"]))])
	return ""

## 重算「如果」：同一個對手、改過的陣型，用確定性模擬直接跑到結束。
## ctl（1.1.0 H1）：背景用 {"stop", "until"}；每 64 tick 看一次，停了回 {"cancel": true}。沒給就照舊一次跑完。
static func review_run(a0, a1, p_rules = null, cmds: Array = [], ctl := {}) -> Dictionary:
	var s = Sim.new(a0.copy(), a1.copy(), p_rules)
	if s.cmd_on:
		s.cmd_play(cmds)
	s.fast = true
	if ctl.is_empty():
		s.run_to_end()
	else:
		while not s.finished:
			s.step()
			if s.tick & 63 == 0 and PZ._stopped(ctl):
				return {"cancel": true}
		if PZ._stopped(ctl):
			return {"cancel": true}
	var rem := roundi(s.power(s.winner) * 100.0 / (s.budget_of(s.winner) * 1000)) if s.winner >= 0 else 0
	return {"winner": s.winner, "rem": rem, "log": s.power_log, "log2": s.power_log2, "b": [s.budget_of(0), s.budget_of(1)], "ticks": s.tick}

## V1.4 #1 時光機：兩條戰力紀錄第一次不一樣的 tick（兩隊戰力交錯存放）。完全一樣回 -1。
static func diverge_tick(a: PackedInt64Array, b: PackedInt64Array) -> int:
	var n := mini(a.size(), b.size())
	for i in n:
		if a[i] != b[i]:
			return i / 2 + 1   # 模擬先加 tick 才記戰力：第一筆是 tick 1（Codex v140-i1）
	return -1 if a.size() == b.size() else n / 2 + 1

func _rv_set_result(res: Dictionary) -> void:
	rv_result = res
	rv_div = diverge_tick(rv_base.get("log2", PackedInt64Array()), res.get("log2", PackedInt64Array())) if not res.is_empty() else -1

## 第七輪 M3：覆盤重算開背景執行緒（模擬是純計算），畫面不卡；算的時候按鈕不能再按（防重入）。
var rv_thread: Thread = null
var rv_gen := 0          # 陣型改一次加一；算完時世代不同就丟掉（Codex r1：舊陣型的結果不能配新陣型）
var rv_thread_gen := 0

func _rv_dirty() -> void:
	rv_result = {}
	rv_div = -1
	rv_gen += 1

## 1.1.0 H1：可取消、有期限（RV_LIMIT_MS）；改了陣型或離開覆盤就叫停，停了的執行緒放 rv_old 背景回收（不在主執行緒等）。
## 開不了執行緒就提示、可以再按。
const RV_LIMIT_MS := 20000
var rv_ctl := {}
var rv_old: Array = []
func _rv_recalc() -> void:
	if rv_thread != null:
		return
	if DisplayServer.get_name() == "headless" or shot_dir != "":
		_rv_set_result(review_run(rv_army, rv_enemy, battle_rules, last_cmds))
		return
	var a: Variant = rv_army.copy()
	var e: Variant = rv_enemy.copy()
	var r: Variant = battle_rules.copy() if battle_rules != null else null
	var lg: Array = last_cmds.duplicate(true)
	var ctl := {"stop": false, "until": Time.get_ticks_msec() + RV_LIMIT_MS}
	var t := Thread.new()
	if t.start(func(): return review_run(a, e, r, lg, ctl)) != OK:
		_toast(L.t("rv_fail"), true)
		return
	rv_ctl = ctl
	rv_thread_gen = rv_gen
	rv_thread = t

func _rv_cancel() -> void:
	if rv_thread != null:
		rv_ctl["stop"] = true
		rv_old.append(rv_thread)
		rv_thread = null

func _rv_poll() -> void:
	for t in rv_old.duplicate():
		if not (t as Thread).is_alive():
			(t as Thread).wait_to_finish()
			rv_old.erase(t)
	if rv_thread != null and (overlay != "review" or rv_thread_gen != rv_gen):
		_rv_cancel()   # 離開覆盤或改了陣型：舊的不用算完
		return
	if rv_thread != null and not rv_thread.is_alive():
		var res: Dictionary = rv_thread.wait_to_finish()
		rv_thread = null
		if bool(res.get("cancel", false)):
			_toast(L.t("rv_slow"), true)   # 只有逾時會走到這（離開、改陣型在上面就收掉了）
			return
		if rv_thread_gen == rv_gen:
			_rv_set_result(res)

## 結束時：叫停再等（64 tick 內會停）；GIF 也叫停。
func _rv_exit() -> void:
	_rv_cancel()
	for t in rv_old:
		(t as Thread).wait_to_finish()
	rv_old = []
	gif_ctl["stop"] = true

func _rv_play() -> void:
	rv_last = [rv_army.copy(), rv_enemy.copy()]
	_replay_snapshot()
	replay_snap["overlay"] = "review"
	replay_marks = []
	overlay = ""
	_begin_battle(rv_army.copy(), rv_enemy.copy(), "review")
	# V1.4 #1 時光機：原本那條時間線跟著同步跑，畫成淡圈；從分岔前 2 秒開始看
	_tm_new_ghost()
	if rv_div > 40:
		_seek_async(rv_div - 40)

func _draw_review() -> void:
	# 第五輪 §4.4：左＝自己的部署區（可改）＋紅方站位（半透明參考）；右＝換兵按鈕（標價）、重算、兩條上下對齊的戰力走勢。
	_panel(Rect2(100, 40, 1080, 720))   # V1.5.2：面板上緣提到 40、底列移到 704，英文／日文 150% 走勢說明不壓到「重播」鈕
	# V1.5.2 L3：說明從緞帶下緣＋16 起；說明換行時左右兩欄一起往下（dy），不壓到「你的部署」與兵種鈕
	var hint := L.t("rv_hint_free" if rv_orig.deploy == "free" else "rv_hint")
	var hy := _h1(Vector2(640, 40), L.t("rv_title")) + GAP_L
	_text(Vector2(640, hy), hint, tz("S"), TXT_DIM, true, false, 960)
	var hend := hy + text_h(hint, tz("S"), 960)
	var dy := maxf(0.0, maxf(hend + GAP_M - (168.0 - tz("C") * 1.5), hend + GAP_L - 160.0))
	var cs := 40.0
	var g0 := Vector2(130, 168 + dy)
	_text(g0 - Vector2(0, tz("C") * 1.5), L.t("rv_you_free" if rv_orig.deploy == "free" else "rv_you"), tz("C"), Charts.team_col(0, cbm()), false, true, 236)   # 不壓到右邊「對手站位」
	if rv_orig.deploy == "free":
		_rv_free_board(g0)
	for r in (0 if rv_orig.deploy == "free" else 9):
		for c in 6:
			var cell := Rect2(g0 + Vector2(c, r) * cs, Vector2(cs - 2, cs - 2))
			var sel := rv_sel == Vector2i(c, r)
			var changed := false
			var oi: int = rv_orig.index_at(c, r)
			var ni: int = rv_army.index_at(c, r)
			if (oi == -1) != (ni == -1) or (oi != -1 and ni != -1 and rv_orig.units[oi]["type"] != rv_army.units[ni]["type"]):
				changed = true
			draw_rect(cell, Color(0.25, 0.4, 0.2) if not changed else Color(0.55, 0.42, 0.12))
			if sel:
				draw_rect(cell, ACCENT, false, 3.0)
			if ni != -1:
				Art.unit(self, cell.position + Vector2(cs / 2 - 1, cs - 5), int(rv_army.units[ni]["type"]), 0, 1.0, 0.0, 0.0, 0.0, 1.0, time, 0.54, cbm())
			_btns.append({"r": cell, "cb": _rv_cell.bind(Vector2i(c, r)), "en": true})
	# 紅方站位（只看不能改）：同一列對齊，右邊是紅方前排
	var cs2 := 26.0
	var g1 := Vector2(g0.x + 6 * cs + 18, g0.y + (9 * cs - 9 * cs2) / 2)
	if rv_orig.deploy != "free":
		_text(Vector2(g1.x, g0.y - tz("C") * 1.5), L.t("rv_enemy"), tz("C"), Charts.team_col(1, cbm()), false, true, 572.0 - g1.x)   # V1.5.2：不伸進右欄兵種鈕上方
	for r in (0 if rv_orig.deploy == "free" else 9):
		for c in 6:
			draw_rect(Rect2(g1 + Vector2(c, r) * cs2, Vector2(cs2 - 2, cs2 - 2)), Color(0.35, 0.2, 0.2, 0.45))
	for u in (rv_enemy.units if rv_orig.deploy != "free" else []):
		var lc := int(u["col"]) - (Army.COLS - Army.ZONE)
		Art.unit(self, g1 + Vector2(lc * cs2 + cs2 / 2, int(u["row"]) * cs2 + cs2 - 3), int(u["type"]), 1, -1.0, 0.0, 0.0, 0.0, 0.75, time, 0.34, cbm())
	var by := g0.y + 9 * cs + 8
	_text(Vector2(g0.x, by), L.t("rv_budget", [rv_army.spent(), rv_army.budget, review_changes(rv_orig, rv_army)]), tz("S"), Color.WHITE, false, false, 420)
	var dsc := review_desc()
	if dsc != "":
		_text(Vector2(g0.x, by + tz("S") * 1.4), dsc, tz("S"), ACCENT, false, false, 420)
	# 右：換成哪個兵種（頭像＋價錢）／拿掉
	var bx := 580.0
	var nt: int = call("_ntypes") if has_method("_ntypes") else D.COUNT
	for t in D.COUNT:
		var can: bool = (RuleSet.has(rv_army.pool, t) if battle_rules != null else t < nt)
		var br := Rect2(bx + t * 56, 160 + dy, 52, 66)
		_btn(br, "", _rv_set_type.bind(t), _rv_has_sel() and can)
		var py := br.size.y - tz("C") * 1.15 - 7   # V1.2.1：按鈕下緣有 3px 厚度，價錢要在面板內
		Art.unit(self, br.position + Vector2(26, py - 2), t, 0, 1.0, 0.0, 0.0, 0.0, 1.0 if can else 0.3, time, 0.5, cbm())
		_text(br.position + Vector2(26, py), L.t("gold", [D.cost(t)]), tz("C"), ACCENT if can else Color(1, 1, 1, 0.3), true, true)
	_btn(Rect2(bx, 234 + dy, 270, 40), L.t("rv_remove"), _rv_set_type.bind(-1), _rv_has_sel())
	_btn(Rect2(bx + 282, 234 + dy, 270, 40), L.t("rv_reset"), func(): rv_army = rv_orig.copy(); _rv_dirty(); rv_sel = Vector2i(-1, -1); rv_fsel = -1)
	_btn(Rect2(bx, 284 + dy, 552, 48), L.t("busy_review") if rv_thread != null else L.t("rv_recalc"), func(): _rv_recalc(), review_changes(rv_orig, rv_army) == 1 and rv_thread == null, true)
	# 兩條戰力走勢上下對齊（同一個時間軸長度）
	var y := 350.0 + dy
	var span: int = maxi(int(rv_base.get("ticks", 1)), int(rv_result.get("ticks", 1)))
	var b0: Array = rv_base.get("b", [100, 100])
	_text(Vector2(bx, y), L.t("rv_orig", [_rv_outcome(int(rv_base.get("winner", -1)), int(rv_base.get("rem", 0)))]), tz("S"), Color.WHITE, false, true, 552)
	var c0 := Rect2(bx, y + tz("S") * 1.5, 552, 70)
	Charts.momentum(self, c0, rv_base.get("log2", PackedInt64Array()), b0[0], b0[1], [], span)
	y += tz("S") * 1.5 + 82
	if not rv_result.is_empty():
		_text(Vector2(bx, y), L.t("rv_new", [_rv_outcome(rv_result["winner"], rv_result["rem"])]), tz("S"), ACCENT, false, true, 552)
		var b1: Array = rv_result.get("b", [100, 100])
		var c1 := Rect2(bx, y + tz("S") * 1.5, 552, 70)
		Charts.momentum(self, c1, rv_result.get("log2", PackedInt64Array()), b1[0], b1[1], [], span)
		_rv_div_mark(Rect2(c0.position, Vector2(c0.size.x, c1.end.y - c0.position.y)), span)   # 一條金色粉筆線貫穿兩張圖
		y += tz("S") * 1.5 + 82
		if rv_div >= 0:
			# V1.4 #1：兩條時間線從哪一秒開始分岔（播放會從分岔前 2 秒開始）
			_text(Vector2(bx, y), L.t("rv_diverge", [snappedf(rv_div / 20.0, 0.1)]), tz("S"), ACCENT, false, true, 552)
			y += tz("S") * 1.5
		_text(Vector2(bx, y), L.t("rv_note"), tz("C"), TXT_DIM, false, false, 552)
		_btn(Rect2(650, 704, 300, 44), L.t("rv_play"), func(): _rv_play())   # V1.4：和「返回」同一列（Antigravity v140-i1）；V1.5.2 L8：雙按鈕同寬、整組置中
	_btn(Rect2(330 if not rv_result.is_empty() else 560, 704, 300 if not rv_result.is_empty() else 160, 44), L.t("back"), func(): overlay = "")

## V1.4 #1：原本那條時間線（同一組敵陣、原本的我方陣、同樣的軍令紀錄），從頭建一份。
func _tm_new_ghost() -> void:
	tm_ghost = Sim.new(rv_orig.copy(), rv_enemy.copy(), battle_rules)
	if tm_ghost.cmd_on:
		tm_ghost.cmd_play(last_cmds)
	tm_ghost.fast = true

## 讓原本的時間線跟上畫面上的 tick；跳回較早的時間就重建再追（模擬是確定性的，追到同一 tick 狀態一樣）。
func _tm_sync() -> void:
	if tm_ghost == null or view == null:
		return
	if tm_ghost.tick > view.tick:
		_tm_new_ghost()
	var guard := 0
	while tm_ghost.tick < view.tick and not tm_ghost.finished and guard < 20000:
		tm_ghost.step()
		guard += 1

## V1.4 #1：在走勢圖上畫分岔點（墨色虛線＋小三角）。
func _rv_div_mark(r: Rect2, span: int) -> void:
	if rv_div < 0 or span <= 0:
		return
	var x := r.position.x + r.size.x * clampf(float(rv_div) / float(span), 0.0, 1.0)
	_chalk_line(Vector2(x, r.position.y - 2), Vector2(x, r.end.y + 2), Color("#ffd166"), 2.6, 6.0)
	draw_colored_polygon(PackedVector2Array([Vector2(x - 5, r.position.y - 8), Vector2(x + 5, r.position.y - 8), Vector2(x, r.position.y - 1)]), ACCENT)

func _rv_has_sel() -> bool:
	if rv_orig.deploy == "free":
		return rv_fsel >= 0 and rv_fsel < rv_army.units.size()
	return rv_sel.x >= 0

## 第六輪：自由陣型的小戰場。一般＝左邊自己的部署區（可點）＋右邊紅方部署區（小、只看）；
## 全場＝整個戰場一張圖，兩隊都畫。原位置留半透明殘影＋虛線，看得出搬了多遠。
var _rv_map := {}   # 自己這張圖的 {o: 左上, s: 每單位幾像素}

func _rv_free_board(g0: Vector2) -> void:
	var full: bool = rv_orig.depth > rv_orig.fw / 2
	var s := 0.028 if full else 0.038
	s = minf(s, 450.0 / float(rv_orig.fw if full else rv_orig.depth + Army.EDGE))   # 大地圖別蓋到右邊的控制列（Codex #9）
	s = minf(s, 340.0 / float(rv_orig.fh))
	var wpx: float = (rv_orig.fw if full else rv_orig.depth + Army.EDGE) * s
	var r := Rect2(g0, Vector2(wpx, rv_orig.fh * s))
	draw_rect(r, Color(0.25, 0.4, 0.2))
	var rv_tex: Texture2D = _map_tex()
	if rv_tex != null:
		draw_texture_rect_region(rv_tex, r, Rect2(Vector2.ZERO, Vector2(wpx / s, rv_orig.fh) * CS / 1000.0))   # 覆盤也看得到地形
	if full:
		draw_line(g0 + Vector2(rv_orig.fw / 2.0 * s, 0), g0 + Vector2(rv_orig.fw / 2.0 * s, r.size.y), Color(1, 1, 1, 0.25), 1.0)
	_rv_map = {"o": g0, "s": s, "r": r}
	var to_px := func(p: Vector2i) -> Vector2: return g0 + Vector2(p) * s
	# 殘影：原本位置有改的那隻
	var now_by := {}
	for i in rv_army.units.size():
		now_by[int(rv_army.units[i].get("eid", -1))] = i
	for u in rv_orig.units:
		var e := int(u.get("eid", -1))
		var p0 := Army.pos_of(u)
		var changed: bool = not now_by.has(e) or Army.pos_of(rv_army.units[now_by[e]]) != p0 or int(rv_army.units[now_by[e]]["type"]) != int(u["type"])
		if changed:
			Art.unit(self, to_px.call(p0), int(u["type"]), 0, 1.0, 0.0, 0.0, 0.0, 0.3, time, 0.42, cbm())
			if now_by.has(e):
				_dash(to_px.call(p0), to_px.call(Army.pos_of(rv_army.units[now_by[e]])), ACCENT, 2.0)
	if full:
		# 全場：敵兵 1.5 格禁區（點空地搬不過去時看得出原因）
		for u in rv_enemy.units:
			draw_circle(to_px.call(Army.pos_of(u)), float(rv_army.enemy_gap) * s, Color(1, 0.25, 0.25, 0.10))
		for u in rv_enemy.units:
			Art.unit(self, to_px.call(Army.pos_of(u)), int(u["type"]), 1, -1.0, 0.0, 0.0, 0.0, 0.7, time, 0.36, cbm())
	var order: Array = range(rv_army.units.size())
	order.sort_custom(func(a, b): return int(rv_army.units[a]["y"]) < int(rv_army.units[b]["y"]))
	for i in order:
		var p: Vector2 = to_px.call(Army.pos_of(rv_army.units[i]))
		if i == rv_fsel:
			draw_arc(p + Vector2(0, -6), 13.0, 0, TAU, 24, ACCENT, 2.5)
		Art.unit(self, p, int(rv_army.units[i]["type"]), 0, 1.0, 0.0, 0.0, 0.0, 1.0, time, 0.42 if full else 0.5, cbm())
	_btns.append({"r": r, "cb": _rv_free_tap, "en": true})
	if not full:
		# 紅方部署區（小、只看）
		var s2 := 0.018
		var g1 := Vector2(g0.x + wpx + 14, g0.y + (r.size.y - rv_orig.fh * s2) / 2)
		_text(Vector2(g1.x, g0.y - tz("C") * 1.5), L.t("rv_enemy"), tz("C"), Charts.team_col(1, cbm()), false, true, 572.0 - g1.x)   # V1.5.2：不伸進右欄兵種鈕上方
		var x0: int = rv_orig.fw - rv_orig.depth - Army.EDGE
		draw_rect(Rect2(g1, Vector2((rv_orig.fw - x0) * s2, rv_orig.fh * s2)), Color(0.35, 0.2, 0.2, 0.45))
		for u in rv_enemy.units:
			var pe := Army.pos_of(u)
			Art.unit(self, g1 + Vector2(pe.x - x0, pe.y) * s2, int(u["type"]), 1, -1.0, 0.0, 0.0, 0.0, 0.75, time, 0.3, cbm())

func _dash(a: Vector2, b: Vector2, c: Color, w: float) -> void:
	var n: int = maxi(1, int(a.distance_to(b) / 8.0))
	for k in n:
		if k % 2 == 0:
			draw_line(a.lerp(b, float(k) / n), a.lerp(b, float(k + 1) / n), c, w)

func _rv_free_tap() -> void:
	if _rv_map.is_empty():
		return
	var m := get_local_mouse_position()
	var w: Vector2 = (m - (_rv_map["o"] as Vector2)) / float(_rv_map["s"])
	_rv_free_click(Vector2i(int(w.x), int(w.y)))

func _rv_outcome(w: int, rem: int) -> String:
	if w < 0:
		return L.t("draw")
	return L.t("rv_win", [rem]) if w == 0 else L.t("rv_lose", [rem])

func _rv_band(r: Rect2, log: PackedInt64Array) -> void:
	draw_rect(r, Color(0, 0, 0, 0.4))
	var n := log.size()
	if n == 0:
		return
	var tot := 100000.0
	var cols := int(r.size.x / 2.0)
	# 原本與如果用同一個時間尺度：兩場裡比較長的那一場為滿（Antigravity S5）
	var span := float(maxi(n, maxi(int(rv_base.get("ticks", 0)), int(rv_result.get("ticks", 0)))))
	for i in cols:
		var t := int(i * 2.0 / r.size.x * span)
		if t >= n:
			break
		var d: float = clampf(float(log[t]) / tot * 2.0, -1.0, 1.0)
		var h := absf(d) * r.size.y / 2.0
		draw_rect(Rect2(r.position.x + i * 2.0, r.get_center().y - (h if d > 0 else 0.0), 2.0, h), Color(Art.team_color(0 if d > 0 else 1, cbm()), 0.85))
	draw_line(Vector2(r.position.x, r.get_center().y), Vector2(r.end.x, r.get_center().y), Color(1, 1, 1, 0.3), 1.0)


## ── V1.4 #14 錄 GIF ──
const GIFENC = preload("res://scripts/game/gif.gd")
const GIF_N := 30
var gif_on := false
var gif_frames: Array = []
var gif_acc := 0.0
var gif_thread: Thread = null
var gif_ctl := {}

func _gif_tick(delta: float) -> void:
	if gif_thread != null and not gif_thread.is_alive():
		var path: String = gif_thread.wait_to_finish()
		gif_thread = null
		gif_frames = []
		_toast(L.t("pc_saved", [path]) if path != "" else L.t("gif_fail"), path == "")
	if not gif_on:
		return
	if play_kind != "replay" or state != St.BATTLE or overlay != "":
		gif_on = false   # 開了別的畫面就取消，不把設定頁錄進去（Codex v140-i2）
		gif_frames = []
		return
	gif_acc += delta
	if gif_acc < 0.1:
		return
	gif_acc = 0.0
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return
	img = img.get_region(Rect2i(0, 60, 1280, 636))
	img.resize(320, 159, Image.INTERPOLATE_BILINEAR)
	gif_frames.append(img)
	if gif_frames.size() >= GIF_N:
		gif_on = false
		var frames := gif_frames.duplicate()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://gifs"))
		var fn := "user://gifs/battle_%s.gif" % Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
		var gctl := {"stop": false, "done": 0}
		gif_ctl = gctl
		var gt := Thread.new()
		var ok := gt.start(func():
			var b: PackedByteArray = GIFENC.encode(frames, 10, gctl)
			if b.is_empty() or bool(gctl.get("stop", false)):
				return ""   # 1.1.0 H1：被叫停（遊戲結束）就不寫出半個檔；最後一格編完才叫停也不寫（Codex v110-i1 #5）
			# 先寫暫存檔，確定沒被叫停才改名成正式檔；叫停就刪暫存（Codex v110-i2 #4）
			var tmp := fn + ".part"
			var fa := FileAccess.open(tmp, FileAccess.WRITE)
			if fa == null:
				return ""
			fa.store_buffer(b)
			fa.close()
			if bool(gctl.get("stop", false)) or DirAccess.rename_absolute(tmp, fn) != OK:
				DirAccess.remove_absolute(tmp)
				return ""
			return ProjectSettings.globalize_path(fn))
		if ok != OK:
			_toast(L.t("gif_fail"), true)   # 1.1.0 H1：開不了執行緒就說，不卡在「正在存」
		else:
			gif_thread = gt
