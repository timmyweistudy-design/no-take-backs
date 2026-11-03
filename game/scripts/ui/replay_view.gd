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
var rv_last: Array = []     # 覆盤播放用的雙方陣型（重播覆盤時用）


# ── 重播控制 ──
func _replay_controls_active() -> bool:
	return state == St.BATTLE and play_kind != "official" and view != null

func _draw_replay_controls() -> void:
	if not _replay_controls_active():
		return
	draw_rect(Rect2(0, 696, 1280, 52), Color(0.06, 0.07, 0.1, 0.92))
	_btn(Rect2(20, 704, 70, 36), "▶" if paused else "Ⅱ", func(): paused = not paused)
	var sp := [0.5, 1.0, 2.0]
	for i in 3:
		_btn(Rect2(98 + i * 74, 704, 68, 36), "%s×" % _fmt_num(sp[i]), func(): speed = sp[i], true, false,
			Color(0.45, 0.3, 0.12) if is_equal_approx(speed, sp[i]) else Color(0, 0, 0, 0))
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
	var hz := fit(L.t("rc_hint"), ts(12), 560)
	var hw := font.get_string_size(L.t("rc_hint"), HORIZONTAL_ALIGNMENT_LEFT, -1, hz).x
	_text(Vector2(RC_BAR.end.x - hw, RC_BAR.position.y - hz * 1.5), L.t("rc_hint"), hz, Color(1, 1, 1, 0.6))
	# 整條是一個按鈕：點哪裡就跳到哪一秒
	_btns.append({"r": RC_BAR, "cb": func(): _seek(int(clampf((mouse.x - RC_BAR.position.x) / RC_BAR.size.x, 0.0, 1.0) * total)), "en": true})
	_text(Vector2(RC_BAR.position.x, RC_BAR.end.y + 2), "%.1f／%.1f 秒" % [view.tick / 20.0, total / 20.0] if L.lang == "zh_TW" else "%.1f / %.1fs" % [view.tick / 20.0, total / 20.0], ts(12), Color(1, 1, 1, 0.75))
	if play_kind == "review":
		_text(Vector2(640, 92), L.t("review_tag"), ts(16), ACCENT, true, true, 600)
	if follow_id >= 0:
		_text(Vector2(640, 92 + ts(16) * 1.4), L.t("rc_following"), ts(14), Color(1, 1, 1, 0.85), true, false, 600)

## 跳到某個 tick：同一組陣型從頭快轉（確定性模擬，結果一定一樣），畫面與音效狀態清空重建。
func _seek(target: int) -> void:
	var armies2: Array = rv_last if play_kind == "review" and not rv_last.is_empty() else last_armies
	sim = Sim.new(armies2[0].copy(), armies2[1].copy(), battle_rules)
	ev_count = {}
	var keep_ct := -1   # 最後時刻在第幾 tick 觸發：快轉時用同一個條件重算，不靠先前的播放紀錄（Codex S7 #2）
	battle_marks.clear()
	var stop := maxi(0, target - ViewBuffer.DELAY)
	while sim.tick < stop and not sim.finished:
		sim.step()
		for ev in sim.events:   # 快轉時也要累計戰報次數與時間軸標記（Codex S5 #4：共用同一個收集函式）
			if ev.has("src"):
				var s = sim.unit_by_id(ev["src"])
				var key := "%s%d" % [ev["kind"], s.team]
				ev_count[key] = int(ev_count.get(key, 0)) + 1
			_collect_mark(ev, sim, sim.tick)
		if keep_ct < 0 and not sim.finished and clutch_cond(sim):
			keep_ct = sim.tick
	var had_clutch := keep_ct >= 0
	view = ViewBuffer.new(sim)
	prev_pos.clear()
	for u in view.units:
		prev_pos[u.id] = Vector2(u.x, u.y)
	fx.clear()
	dying.clear()
	graves.clear()
	atk_hit.clear()
	atk_seq.clear()
	atk_t.clear()
	hurt_t.clear()
	hurt_dir.clear()
	brace_t.clear()
	accum = 0.0
	result_delay = 0.0
	clutch_t = 0.0
	slow_left = 0.0
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
	if not _replay_controls_active():
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
	if best < 0:
		zoom_target = 1.0   # 取消跟拍：回到全景（中心由 _battle_process 拉回）

func _follow_update(delta: float) -> void:
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
	DisplayServer.clipboard_set(BattleCode.encode(armies2[0], armies2[1], battle_rules))
	_toast(L.t("bc_copied"))

func _watch_battle_code() -> void:
	var r := BattleCode.decode(DisplayServer.clipboard_get())
	if not r["ok"]:
		_toast(L.t("bc_bad"), true)
		return
	# 試玩版：對戰代碼裡有正式版才有的兵種就不播（Codex 實作審查 #2）
	if OS.has_feature("demo"):
		for a in [r["a0"], r["a1"]]:
			for u in a.units:
				if int(u["type"]) >= RS.DEMO_MAX:
					_toast(L.t("bc_demo_locked"), true)
					return
	if r["mismatch"]:
		_toast(L.t("bc_mismatch"))
	watch_code(r["a0"], r["a1"], r.get("rules"))

## 看一場對戰代碼：當成全新的一局初始化（Codex S5 #2：原本沿用舊的陣型、比分、局數）
func watch_code(a0, a1, p_rules = null) -> void:
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
func _open_review() -> void:
	rv_orig = last_armies[0].copy()
	rv_army = last_armies[0].copy()
	rv_enemy = last_armies[1].copy()
	rv_sel = Vector2i(-1, -1)
	rv_result = {}
	rv_base = review_run(rv_orig, rv_enemy, battle_rules)
	_open("review")

## 跟原本比改了幾隻（換兵種、移位、拿掉、新增都算一隻）。
static func review_changes(orig, now) -> int:
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
	rv_result = {}

func _rv_cell(c: Vector2i) -> void:
	if rv_sel.x >= 0 and rv_army.index_at(rv_sel.x, rv_sel.y) != -1 and rv_army.index_at(c.x, c.y) == -1:
		var from := rv_sel
		_rv_try(func(): rv_army.move(from.x, from.y, c.x, c.y))
		rv_sel = c
		return
	rv_sel = c

func _rv_set_type(t: int) -> void:
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
	rv_result = {}

## 改了什麼（給畫面顯示）：例如「弓箭手 → 劍士（第 3 列第 5 欄）」
func review_desc() -> String:
	for u in rv_orig.units:
		var i: int = rv_army.index_at(u["col"], u["row"])
		if i == -1:
			# 被移走或拿掉
			for v in rv_army.units:
				if rv_orig.index_at(v["col"], v["row"]) == -1 and int(v["type"]) == int(u["type"]):
					return L.t("rv_moved", [L.t("unit_%d" % int(u["type"])), int(u["row"]) + 1, int(u["col"]) + 1, int(v["row"]) + 1, int(v["col"]) + 1])
			return L.t("rv_removed", [L.t("unit_%d" % int(u["type"])), int(u["row"]) + 1, int(u["col"]) + 1])
		if int(rv_army.units[i]["type"]) != int(u["type"]):
			return L.t("rv_swapped", [L.t("unit_%d" % int(u["type"])), L.t("unit_%d" % int(rv_army.units[i]["type"])), int(u["row"]) + 1, int(u["col"]) + 1])
	for v in rv_army.units:
		if rv_orig.index_at(v["col"], v["row"]) == -1:
			return L.t("rv_added", [L.t("unit_%d" % int(v["type"])), int(v["row"]) + 1, int(v["col"]) + 1])
	return ""

## 重算「如果」：同一個對手、改過的陣型，用確定性模擬直接跑到結束。
static func review_run(a0, a1, p_rules = null) -> Dictionary:
	var s = Sim.new(a0.copy(), a1.copy(), p_rules)
	s.fast = true
	s.run_to_end()
	var rem := roundi(s.power(s.winner) * 100.0 / (s.budget_of(s.winner) * 1000)) if s.winner >= 0 else 0
	return {"winner": s.winner, "rem": rem, "log": s.power_log, "log2": s.power_log2, "b": [s.budget_of(0), s.budget_of(1)], "ticks": s.tick}

func _rv_recalc() -> void:
	rv_result = review_run(rv_army, rv_enemy, battle_rules)

func _rv_play() -> void:
	rv_last = [rv_army.copy(), rv_enemy.copy()]
	overlay = ""
	_begin_battle(rv_army.copy(), rv_enemy.copy(), "review")

func _draw_review() -> void:
	# 第五輪 §4.4：左＝自己的部署區（可改）＋紅方站位（半透明參考）；右＝換兵按鈕（標價）、重算、兩條上下對齊的戰力走勢。
	_panel(Rect2(100, 60, 1080, 680))
	_text(Vector2(640, 70), L.t("rv_title"), tz("H1"), Color.WHITE, true, true, 900)
	_text(Vector2(640, 70 + tz("H1") * 1.3), L.t("rv_hint"), tz("S"), Color(1, 1, 1, 0.75), true, false, 960)
	var cs := 40.0
	var g0 := Vector2(130, 168)
	_text(g0 - Vector2(0, tz("C") * 1.5), L.t("rv_you"), tz("C"), Charts.team_col(0, cbm()), false, true)
	for r in 9:
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
	_text(Vector2(g1.x, g0.y - tz("C") * 1.5), L.t("rv_enemy"), tz("C"), Charts.team_col(1, cbm()), false, true)
	for r in 9:
		for c in 6:
			draw_rect(Rect2(g1 + Vector2(c, r) * cs2, Vector2(cs2 - 2, cs2 - 2)), Color(0.35, 0.2, 0.2, 0.45))
	for u in rv_enemy.units:
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
		var br := Rect2(bx + t * 56, 160, 52, 66)
		_btn(br, "", _rv_set_type.bind(t), rv_sel.x >= 0 and can)
		var py := br.size.y - tz("C") * 1.15 - 2
		Art.unit(self, br.position + Vector2(26, py - 2), t, 0, 1.0, 0.0, 0.0, 0.0, 1.0 if can else 0.3, time, 0.5, cbm())
		_text(br.position + Vector2(26, py), L.t("gold", [D.cost(t)]), tz("C"), ACCENT if can else Color(1, 1, 1, 0.3), true, true)
	_btn(Rect2(bx, 234, 270, 40), L.t("rv_remove"), _rv_set_type.bind(-1), rv_sel.x >= 0)
	_btn(Rect2(bx + 282, 234, 270, 40), L.t("rv_reset"), func(): rv_army = rv_orig.copy(); rv_result = {}; rv_sel = Vector2i(-1, -1))
	_btn(Rect2(bx, 284, 552, 48), L.t("rv_recalc"), func(): _rv_recalc(), review_changes(rv_orig, rv_army) == 1, true)
	# 兩條戰力走勢上下對齊（同一個時間軸長度）
	var y := 350.0
	var span: int = maxi(int(rv_base.get("ticks", 1)), int(rv_result.get("ticks", 1)))
	var b0: Array = rv_base.get("b", [100, 100])
	_text(Vector2(bx, y), L.t("rv_orig", [_rv_outcome(int(rv_base.get("winner", -1)), int(rv_base.get("rem", 0)))]), tz("S"), Color.WHITE, false, true, 552)
	Charts.momentum(self, Rect2(bx, y + tz("S") * 1.5, 552, 70), rv_base.get("log2", PackedInt64Array()), b0[0], b0[1], [], span)
	y += tz("S") * 1.5 + 82
	if not rv_result.is_empty():
		_text(Vector2(bx, y), L.t("rv_new", [_rv_outcome(rv_result["winner"], rv_result["rem"])]), tz("S"), ACCENT, false, true, 552)
		var b1: Array = rv_result.get("b", [100, 100])
		Charts.momentum(self, Rect2(bx, y + tz("S") * 1.5, 552, 70), rv_result.get("log2", PackedInt64Array()), b1[0], b1[1], [], span)
		y += tz("S") * 1.5 + 82
		_text(Vector2(bx, y), L.t("rv_note"), tz("C"), Color(1, 1, 1, 0.6), false, false, 552)
		_btn(Rect2(bx, y + text_h(L.t("rv_note"), tz("C"), 552) + 6, 300, 44), L.t("rv_play"), func(): _rv_play())
	_btn(Rect2(560, 684, 160, 44), L.t("back"), func(): overlay = "")

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
