extends "res://scripts/ui/screens/game_core.gd"
## 由 game_screens.gd 拆出（V9 P1，行為不變）

# ───────────────────────── 狀態切換 ─────────────────────────
## 第十輪 B10：玩家按離開。系列打到一半或遠征途中，先確認（自動導頁直接呼叫 _go_title，不跳確認）。
func _leave_at_risk() -> bool:
	if state == St.TITLE or watch_mode:
		return false
	if mode == Mode.GAUNTLET:
		if state == St.RESULT and sim != null:
			return sim.winner == 0 and gauntlet_stage < 7
		return gauntlet_stage > 1
	if mode == Mode.VS_AI or mode == Mode.DUEL:
		return wins[0] + wins[1] > 0 and not series_over
	return false

func _request_leave() -> void:
	if _leave_at_risk():
		overlay = "leave"
		_focus = 0
	else:
		_go_title()

func _leave_confirm() -> void:
	overlay = ""
	_go_title()

func _go_title() -> void:
	set("wv_active", false)   # V1.4 #11：離開就結束車輪戰
	set("wv_mode", false)
	set("sealed_on", false)   # V1.4 #13
	set("sealed", [[], []])
	set("ghost_id", "")
	set("wk_active", false)
	set("wg_active", false)   # V1.4 #16：離開就取消押注，不能拿下一場來結算（Codex v140-i2）
	call("_pre_drop")
	Save.retry_pending()   # 第七輪 R7：上次沒寫成功的補寫；還是失敗，標題頁會常駐提示
	sfx.set_muffled(false)
	watch_mode = false
	clutch_t = 0.0
	state = St.TITLE
	overlay = ""
	sim = null
	view = null
	zoom = 1.0
	_focus = 0
	_new_demo()
	sfx.play_music("music_title")
	sfx.play_ambience("")



func _new_demo() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = rng.randi()
	demo = Sim.new(AI.build(0, 100, r)["army"], AI.build(1, 100, r)["army"])
	demo.fast = true
	demo_acc = 0.0



## 第六輪（Codex 實作第 1 輪 #5）：雙人全場被封鎖到跳完手、一方沒有戰鬥兵時，照樣按「開戰」——
## 模擬在第 0 tick 就依 §3.8 判定（有戰鬥兵的一方勝、雙方都沒有＝和局），不能卡在開戰鈕永久灰掉。
func _full_blocked_ok() -> bool:
	return mode == Mode.DUEL and tp != null and tp.done() and rules != null and rules.is_free() and rules.fullfield == RuleSet.FULL_DUEL


func _ready_to_fight() -> bool:
	if mode == Mode.DUEL:
		if tp != null:
			return tp.done() and (rules == null or _full_blocked_ok() or (armies[0].has_combat() and armies[1].has_combat()))
		return blind_phase == 2
	if rules != null:
		return armies[0].has_combat()
	return armies[0].count() > 0



## 第五輪：開戰鈕灰掉時要直接寫的原因（空字串＝可以開戰）。
func _start_block_reason() -> String:
	if state != St.PLACE:
		return ""
	if mode == Mode.DUEL and tp != null and not tp.done():
		return ""
	var a = _cur_army()
	if a.count() == 0:
		return ""
	if rules != null and not a.has_combat() and not _full_blocked_ok():
		return L.t("err_need_combat")
	return ""



func _on_start() -> void:
	_fp_abort_drag()   # 第六輪：拖曳中按開戰／準備好，拖曳作廢（Codex 實作第 2 輪 #2）
	if mode == Mode.DUEL and tp != null and not tp.done():
		if not tp.end_turn():
			_toast(L.t("err_cantskip"), true)
		else:
			sfx.play("turn")
		return
	if mode == Mode.DUEL and tp == null and blind_phase < 2:
		if _cur_army().count() == 0:
			_toast(L.t("err_empty"), true)
			return
		if rules != null and not _cur_army().has_combat():
			_toast(L.t("err_need_combat"), true)
			return
		if bool(get("sealed_on")):
			# V1.4 #13 雙封蠟戰書：每人封三個陣，封好一個就清空再擺下一個；三個都封好才換人
			var tm: int = blind_phase
			var sl: Array = get("sealed")[tm]
			sl.append(_cur_army().units.duplicate(true))
			sfx.play("turn")
			_cur_army().units = []
			if sl.size() < 3:
				_toast(L.t("sealed_done", [sl.size()]))
				return
			blind_phase += 1
			if blind_phase == 2:
				call("_sealed_reveal", 0)
				_toast(L.t("sealed_ready"))
			else:
				_toast(L.t("sealed_swap"))   # Antigravity v140-i3：第三封封完要說換人
			return
		blind_phase += 1
		sfx.play("turn")
		return
	if armies[0].count() == 0 and not _full_blocked_ok():
		_toast(L.t("err_empty"), true)
		return
	if rules != null and not _full_blocked_ok() and (not armies[0].has_combat() or (mode == Mode.DUEL and not armies[1].has_combat())):
		_toast(L.t("err_need_combat"), true)
		return
	for u in armies[0].units:   # 開戰前再驗一次（Codex 實作審查 #1）
		if not _allowed(int(u["type"])) and not (mode == Mode.TUTORIAL or mode == Mode.PUZZLE):
			_toast(L.t("code_locked"), true)
			return
	if mode == Mode.GAUNTLET and gauntlet_stage > 1 and _gauntlet_diff() > gauntlet_changes:
		_toast(L.t("err_changes"), true)
		return
	if mode == Mode.VS_AI and bool(get("wv_active")) and not bool(call("wave_has_lock", armies[0].units, get("wv_lock"))):
		_toast(L.t("wv_missing"), true)   # V1.4 #11：載入陣型等方式把殘兵換掉了
		return
	if mode == Mode.VS_AI and not ai_prebuilt:
		if _build_ai_async():
			return
		_build_ai()
	_on_start_go()

func _on_start_go() -> void:
	last_player_formation = armies[0].units.duplicate(true)
	_begin_battle(armies[0].copy(), armies[1].copy())



func _can_edit_existing() -> bool:
	return not (mode == Mode.DUEL and (tp != null or blind_phase == 2))



func _locked() -> bool:
	return mode == Mode.DUEL and tp == null and blind_phase == 2



func _check_place(t: int, c: Vector2i) -> String:
	if _locked():
		return L.t("both_done")
	if not _allowed(t):
		return L.t("err_type")
	if mode == Mode.DUEL and tp != null:
		var why: String = tp.check_place(t, c.x, c.y)
		return _err_key(why)
	if mode == Mode.GAUNTLET and gauntlet_stage > 1 and _gauntlet_diff() + 1 > gauntlet_changes:
		return L.t("err_changes")
	return _err_key(_cur_army().check_place(t, c.x, c.y))



func _err_key(why: String) -> String:
	if why == "":
		return ""
	if why == Army.E_ZONE:
		return L.t("err_zone")
	if why == Army.E_TERRAIN:
		return L.t("err_terrain")
	if why == Army.E_TAKEN:
		return L.t("err_taken")
	if why.begins_with(Army.E_CAP_PREFIX):
		return L.t("err_max", [_cur_army().unit_cap])
	if why.begins_with("這種兵最多"):
		return L.t("err_type_cap", [_cur_army().type_cap])
	if why.begins_with("這種兵不在"):
		return L.t("err_type")
	if why.begins_with("要留錢"):
		return L.t("err_reserve")
	if why.begins_with("最後一手"):
		return L.t("err_last_hand")
	if why == Army.E_GOLD:
		return L.t("err_gold")
	if why.begins_with("這一手"):
		return L.t("err_hand", [tp.hand_cap() if tp else 10])
	return why



func _try_place(c: Vector2i) -> void:
	var why := _check_place(selected, c)
	if why == "":
		if mode == Mode.DUEL and tp != null:
			# 第五輪防手滑（Antigravity 第二輪）：輪流落子時先點一下出現預覽，再點同一格才落子；設定可關。擺下仍不能收回。
			if bool(Save.s("confirm_place")) and pending_cell != c:
				pending_cell = c
				sfx.play("k_click", 0.7)
				return
			pending_cell = Vector2i(-1, -1)
			tp.place(selected, c.x, c.y)
		else:
			_cur_army().place(selected, c.x, c.y)
		show_place_help = false
		settle_t[Vector2i(c.x, c.y)] = time   # V1.3.1 P2：格子模式也有放下沉降
		sfx.play(["place_mid", "place_heavy", "place_light", "place_heavy", "place_light", "place_heavy", "place_light", "place_light", "place_light", "place_heavy"][selected])
	elif why != L.t("err_taken"):
		_toast(why, true)



func _try_remove(c: Vector2i) -> void:
	if _locked():
		return
	if mode == Mode.DUEL and tp != null:
		_toast(L.t("err_notakeback"), true)
		return
	if (mode == Mode.TUTORIAL or mode == Mode.PUZZLE) and PZ.is_fixed(PZ.get_puzzle(puzzle_id), c.x, c.y):
		_toast(L.t("err_locked"), true)
		return
	if mode == Mode.VS_AI and bool(call("wave_is_locked", c)):
		_toast(L.t("wv_locked"), true)   # V1.4 #11：殘兵不能撤（Antigravity v140-i3）
		return
	if _cur_army().remove_at(c.x, c.y):
		sfx.play("k_click", 0.7)



## 看不到的那一邊：迷霧、問號旗、提示（第七輪：格子與自由共用）。
func _draw_hide_fog(hide_side: int) -> void:
	var cols := 6.0
	if _is_free():
		cols = float(rules.half_depth()) / 1000.0
	var x0 := float(fld_w) / 1000.0 - cols if hide_side == 1 else 0.0
	# 迷霧（R6）：深藍紫半透明＋飄動的雲＋發光紅問號旗，格線仍透出來
	var mr := Rect2(ORIGIN + Vector2(x0 * CS, 0), Vector2(cols * CS, fld_size.y))
	# V1.2 C4：敵陣遮擋改成木製屏風（木紋、三扇接縫、銅鉸鏈），不再是黑色半透明罩
	if not bool(Save.s("plain_ui")) and _tex_box(mr, "wood", Color(0.62, 0.46, 0.33)):
		var panels := 3
		for pj in panels:   # 屏風的扇面交替明暗，看得出折角
			var pr := Rect2(mr.position.x + mr.size.x * pj / panels, mr.position.y, mr.size.x / panels, mr.size.y)
			draw_rect(pr, Color(1, 0.95, 0.85, 0.06) if pj % 2 == 0 else Color(0, 0, 0, 0.12))
		for pi in range(1, panels):
			var sx := mr.position.x + mr.size.x * pi / panels
			draw_line(Vector2(sx, mr.position.y + 4), Vector2(sx, mr.end.y - 4), Color(0.1, 0.06, 0.03, 0.75), 3.0)
			draw_line(Vector2(sx + 2, mr.position.y + 4), Vector2(sx + 2, mr.end.y - 4), Color(1, 0.9, 0.7, 0.12), 1.0)
			for hy in [0.18, 0.5, 0.82]:
				var hp := Vector2(sx, mr.position.y + mr.size.y * hy)
				draw_circle(hp, 4.5, Color("#2a190d"), true, -1.0, true)
				draw_circle(hp, 3.2, Color("#b98a45"), true, -1.0, true)
				draw_circle(hp - Vector2(1, 1), 1.2, Color("#f0d9a0"), true, -1.0, true)
		draw_rect(mr, Color(0, 0, 0, 0.18))   # 壓暗一點，讓上面的字更清楚
	else:
		draw_rect(mr, Color(0.11, 0.09, 0.24, 0.80))
	var fp := mr.position + Vector2(mr.size.x / 2 - 8, mr.size.y / 2 - 120)
	var glow := 0.5 + 0.5 * sin(time * 2.4)
	draw_circle(fp + Vector2(22, 18), 34 + glow * 6, Color(1, 0.25, 0.25, 0.10 + glow * 0.06), true, -1.0, true)
	draw_line(fp, fp + Vector2(0, 74), Color(0.85, 0.78, 0.7), 3.0, true)
	draw_colored_polygon(PackedVector2Array([fp, fp + Vector2(48, 16), fp + Vector2(0, 36)]), Color(0.9, 0.2, 0.22))
	_text(fp + Vector2(15, 2), "?", ts(22), Color.WHITE, true, true)
	# V1.2.1 R5：旗竿底座的小木牌，只寫公開資訊（敵方預算、兵數上限），不洩漏陣型
	if not bool(Save.s("plain_ui")):
		var eb: int = rules.budget_of(hide_side) if rules != null else 100
		var ec: int = rules.unit_cap if rules != null else 24
		var sg := L.t("fog_sign", [eb, ec])
		if mode == Mode.GAUNTLET and int(get("gauntlet_nemesis")) >= 0:
			sg = L.t("nem_sign", [ai_name])   # V1.4 #2：宿敵攔路時木牌寫它的名號
		var sfs: int = tz("C")
		var sw := _width(sg, sfs, true) + 24.0
		var sr := Rect2(fp.x - sw / 2.0, fp.y + 74, sw, sfs * 1.5)
		_tex_box(sr, "wood", Color(0.62, 0.44, 0.3))
		draw_rect(Rect2(sr.position.x + 3, sr.end.y - 2, sr.size.x - 6, 2), Color(0, 0, 0, 0.3))
		_text(Vector2(fp.x, sr.position.y + sfs * 0.2), sg, sfs, Color.WHITE, true, true, sw)
	# 第七輪 A1：同一系列第 2 局起，留上一局敵陣殘影當參考（對手這局可能換陣）
	if mode == Mode.VS_AI and round_no > 1 and last_armies.size() == 2 and _is_free():
		for gu in last_armies[1].units:
			var gw: Vector2i = Army.pos_of(gu)
			_unit(ORIGIN + Vector2(gw) * CS / 1000.0, int(gu["type"]), 1, -1.0, 0.0, 0.0, 0.0, 0.28, 0.0, 1.0)
	var msg := L.t("ai_hidden") if mode == Mode.VS_AI else L.t("enemy_hidden")
	_text(ORIGIN + Vector2((x0 + cols / 2.0) * CS, fld_size.y / 2 - 10), msg, ts(22), Color(1, 1, 1, 0.85), true, true, cols * CS - 20)
	var dsp = get("daily_spec")
	if mode == Mode.VS_AI and dsp is Dictionary and not dsp.is_empty():
		# V1.1 D2：每日挑戰把本週突變、計分方式、今日最佳寫在迷霧區（不洩漏陣型）
		var dw := cols * CS - 30
		var dy: float = fld_size.y / 2 - 10 + text_h(msg, ts(22), cols * CS - 20, true) + 14   # 接在「AI 的陣型開戰後揭曉」（大字會換行）下面
		var dl: Array = [str(call("_daily_desc", dsp, rules)), L.t("daily_score")]
		var b0: Array = Save.data.get("daily_best", {}).get(str(dsp["key"]), [])
		if not b0.is_empty():
			dl.append(L.t("daily_best", [int(b0[0]), int(b0[1])]))
		for s0 in dl:
			_text(ORIGIN + Vector2((x0 + cols / 2.0) * CS, dy), s0, ts(15), Color(1, 0.85, 0.6, 0.85), true, false, dw)
			dy += text_h(s0, ts(15), dw) + 6
	elif mode == Mode.VS_AI:
		# AI 的難度與性格（第三輪 U3）：不洩漏陣型
		_text(ORIGIN + Vector2((x0 + cols / 2.0) * CS, fld_size.y / 2 + 70), L.t("ai_trait_%d" % difficulty), ts(15), Color(1, 0.85, 0.6, 0.8), true, false, cols * CS - 30)



## V1.1 B3：部署剋制提示。選中的兵剋這隻敵兵＝頭上綠色 ▲，被這隻剋＝紅色 ▼（只讀剋制表，不跑模擬）。
func _counter_mark(p: Vector2, mine: int, foe: int) -> void:
	if mine == foe:
		return
	var sc: int = AIT.counter_score(mine, foe)
	if sc == 0:
		return
	var c := p + Vector2(0, -74 if foe != D.CAVALRY else -82)
	var s := 9.0
	var up := sc > 0
	var tri := PackedVector2Array([c + Vector2(0, -s if up else s), c + Vector2(s, s * 0.6 if up else -s * 0.6), c + Vector2(-s, s * 0.6 if up else -s * 0.6)])
	draw_colored_polygon(tri, Color("#4ade80") if up else Color("#f87171"))
	draw_polyline(tri + PackedVector2Array([tri[0]]), Art.OUT, 2.0, true)

func _draw_place_units() -> void:
	var list: Array = []
	var hide_side := -1
	if mode == Mode.VS_AI:
		hide_side = 1
	elif mode == Mode.DUEL and tp == null:
		hide_side = 1 if blind_phase == 0 else (0 if blind_phase == 1 else -1)
	for a in armies:
		if a.team == hide_side:
			continue
		for u in a.units:
			if drag_from.x >= 0 and a == _cur_army() and u["col"] == drag_from.x and u["row"] == drag_from.y:
				continue
			list.append([u["row"], u["col"], u["type"], a.team, int(u.get("st", 0)), int(u.get("boss", 0))])
	list.sort()
	var pz := PZ.get_puzzle(puzzle_id) if (mode == Mode.TUTORIAL or mode == Mode.PUZZLE) else {}
	for it in list:
		var p := ORIGIN + Vector2(it[1] + 0.5, it[0] + 0.82) * CS
		var bsc := BossD.DRAW_SCALE if int(it[5]) == 1 else 1.0   # V1.4 #12 巨獸
		_ring(p, it[3], it[2], bsc)
		if int(it[4]) > 0:
			_sticker_badge(p, int(it[4]), 1.0)
		_unit(p + Vector2(0, _settle_dy(Vector2i(it[1], it[0]))), it[2], it[3], 1.0 if it[3] == 0 else -1.0, 0.0, 0.0, 0.0, 1.0, time + it[1], bsc)
		if int(it[5]) == 1:
			_text(p + Vector2(0, -84.0 * bsc), L.t("boss_name"), tz("C"), Color("#ffb4a8"), true, true, 120)
		if it[3] == 1 and selected >= 0 and _cur_army().team == 0:
			_counter_mark(p, selected, int(it[2]))   # V1.1 B3
		if not pz.is_empty() and it[3] == 0 and PZ.is_fixed(pz, it[1], it[0]):
			_lock_icon(p + Vector2(17, -60))   # 14px 鎖頭（第三輪 U4）
		elif it[3] == 0 and mode == Mode.VS_AI and bool(call("wave_is_locked", Vector2i(it[1], it[0]))):
			_lock_icon(p + Vector2(17, -60))   # V1.4 #11：車輪戰殘兵
		if not pz.is_empty() and PZ.goal(pz) == "flawless" and it[3] == 0 and int(it[2]) == int(pz["goal_type"]):
			_goal_marker(ORIGIN + Vector2(it[1] + 0.5, it[0] + 0.82) * CS, "protect")   # V1.1：不能倒的那種兵每隻都標
		if not pz.is_empty() and pz.has("goal_unit") and int(pz["goal_unit"][0]) == it[1] and int(pz["goal_unit"][1]) == it[0] and it[3] == (0 if PZ.goal(pz) == "protect" else 1):
			_goal_marker(ORIGIN + Vector2(it[1] + 0.5, it[0] + 0.82) * CS, PZ.goal(pz))
	# V1.1 C5：擺放時被下排蓋到臉的也補畫半透明
	var xr: Array = []
	for it2 in list:
		xr.append([ORIGIN + Vector2(it2[1] + 0.5, it2[0] + 0.82) * CS, [it2[2], it2[3], 1.0 if it2[3] == 0 else -1.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0]])
	_draw_xray(xr)
	if not pz.is_empty() and not pz.get("fixed", []).is_empty():
		# 圖例
		var lg := ORIGIN + Vector2(10, 10)
		draw_rect(Rect2(lg, Vector2(190, 28)), Color(0, 0, 0, 0.5))
		_lock_icon(lg + Vector2(16, 16))
		_text(lg + Vector2(30, 4), L.t("lock_legend"), ts(14), Color.WHITE, false, false, 150)
	if hide_side >= 0:
		_draw_hide_fog(hide_side)
	# 拖曳預覽
	var dragging_type := -1
	if drag_new:
		dragging_type = selected
	elif drag_from.x >= 0:
		var idx: int = _cur_army().index_at(drag_from.x, drag_from.y)
		if idx >= 0:
			dragging_type = _cur_army().units[idx]["type"]
	if dragging_type >= 0:
		_lift_shadow(mouse + Vector2(0, 24 + LIFT_PX))   # V1.3 B3：拿起來的棋子在地上留影子
		Art.unit(self, mouse + Vector2(0, 24), dragging_type, _cur_army().team, 1.0, 0.0, 0.0, 0.0, 0.75, time, 1.0, cbm(), Art.M_SURPRISE)   # V1.3.1：被抓起來的驚訝臉
	var c := cursor if pad_mode else _cell_at(mouse)
	if c.x >= 0:
		var okp := _check_place(selected, c) == ""
		draw_rect(Rect2(ORIGIN + Vector2(c) * CS, Vector2(CS, CS)), Color(1, 1, 1, 0.28) if okp else Color(1, 0.25, 0.25, 0.25))
		if pad_mode:
			draw_rect(Rect2(ORIGIN + Vector2(c) * CS, Vector2(CS, CS)), ACCENT, false, 3)
	# 點兩下落子的預覽（第五輪）：半透明兵＋金框＋「再點一次落子」
	if pending_cell.x >= 0 and mode == Mode.DUEL and tp != null and not tp.done():
		var pr := Rect2(ORIGIN + Vector2(pending_cell) * CS, Vector2(CS, CS))
		draw_rect(pr, Color(ACCENT, 0.25))
		draw_rect(pr, ACCENT, false, 3.0)
		Art.unit(self, pr.get_center() + Vector2(0, 22), selected, _cur_army().team, 1.0, 0.0, 0.0, 0.0, 0.55, time, UNIT_SCALE, cbm())
		_text(pr.get_center() + Vector2(0, CS * 0.55), L.t("tap_again"), tz("C"), ACCENT, true, true)



## 戰術預覽（優化方案 E2）：選中兵種在游標格的射程／衝鋒線／刺客路線；已擺弓手的射程；看得到敵陣時標出剋制關係。
func _draw_tactical() -> void:
	var c := cursor if pad_mode else _cell_at(mouse)
	var army = _cur_army()
	var dir := 1.0 if army.team == 0 else -1.0
	if c.x >= 0 and army.in_zone(c.x, c.y):
		var p := ORIGIN + (Vector2(c) + Vector2(0.5, 0.5)) * CS
		match selected:
			D.ARCHER:
				_arc_clipped(p, 6.0 * CS, 0, TAU, Color(1, 0.9, 0.5, 0.45), 2.0)
			D.PIKE:
				_arc_clipped(p, D.STATS[D.PIKE]["reach"] / 1000.0 * CS, 0, TAU, Color(1, 0.9, 0.5, 0.5), 2.0)
			D.BOMBER:
				# 甜甜圈：外圈射程（橘白）＋內圈紅色盲區（第四輪 §4.2）
				_arc_clipped(p, D.STATS[D.BOMBER]["reach"] / 1000.0 * CS, 0, TAU, Color(1, 0.85, 0.7, 0.5), 2.0)
				# 盲區：半透明紅底＋紅斜線（Antigravity：只有細紅線會被看成增益光環）
				var br0 := D.BOMB_MIN / 1000.0 * CS
				draw_circle(p, br0, Color(1, 0.2, 0.15, 0.22), true, -1.0, true)
				var hn := Vector2(1, 1).normalized()
				var ht := Vector2(1, -1).normalized()
				for hk in range(-4, 5):
					var dd := hk * br0 / 5.0
					var hh := sqrt(maxf(0.0, br0 * br0 - dd * dd))
					var hc := p + hn * dd
					draw_line(hc - ht * hh, hc + ht * hh, Color(1, 0.3, 0.25, 0.5), 1.5, true)
				_hand_ring(p, br0, Color(1, 0.3, 0.25, 0.85), 2.5)
			D.MEDIC, D.DRUMMER:
				# 補血／戰鼓範圍：醫者草綠、鼓手暖金；圈內的友軍微亮
				var rad: float = (D.HEAL_RANGE if selected == D.MEDIC else D.DRUM_RANGE) / 1000.0 * CS
				var rc := Color(0.55, 0.95, 0.45) if selected == D.MEDIC else Color(1, 0.82, 0.35)
				draw_circle(p, rad, Color(rc, 0.08), true, -1.0, true)
				_arc_clipped(p, rad, 0, TAU, Color(rc, 0.7), 2.0)
				for u in army.units:
					var up := ORIGIN + Vector2(u["col"] + 0.5, u["row"] + 0.5) * CS
					if up.distance_to(p) <= rad and not D.is_support(u["type"]):
						draw_circle(up + Vector2(0, 14), 9.0, Color(rc, 0.45), true, -1.0, true)
			D.CAVALRY:
				var q := p + Vector2(3.0 * CS * dir, 0)
				_chalk_line(p, q, Color(1, 0.8, 0.3, 0.85), 3.0, 8.0)
				draw_circle(q, 6, Color(1, 0.8, 0.3, 0.9), true, -1.0, true)
				_text(q + Vector2(0, -30), L.t("ev_charge"), ts(13), Color(1, 0.85, 0.4), true, true)
			D.ASSASSIN:
				if _enemy_visible():
					var best := Vector2.ZERO
					var bd := 1e9
					for u in armies[1 - army.team].units:
						if u["type"] == D.SHIELD or u["type"] == D.CAVALRY:
							var ep := ORIGIN + Vector2(u["col"] + 0.5, u["row"] + 0.5) * CS
							if ep.distance_to(p) < bd:
								bd = ep.distance_to(p)
								best = ep
					if bd < 1e9:
						_chalk_line(p, best, Color(0.78, 0.5, 1.0, 0.85), 2.5, 7.0)
	# 已擺的弓手射程：只在「選著弓手、游標停在那隻弓手上、或按住 Alt／LT」時顯示，並裁在棋盤內（第三輪 U3）
	var show_all := selected == D.ARCHER or Input.is_key_pressed(KEY_ALT) or Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT) > 0.5
	# 第七輪 D8：不再一隻一條弧線疊在一起，只畫全軍最前緣那一條；按 Alt／LT 才看全部
	var want_all := Input.is_key_pressed(KEY_ALT) or Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT) > 0.5
	var front := -1
	for fi in army.units.size():
		var fu: Dictionary = army.units[fi]
		if fu["type"] == D.ARCHER and (front < 0 or (int(fu["col"]) - int(army.units[front]["col"])) * dir > 0):
			front = fi
	for ui in army.units.size():
		var u: Dictionary = army.units[ui]
		if ui != front and not want_all and not (c.x == u["col"] and c.y == u["row"]):
			continue
		if u["type"] == D.ARCHER and (show_all or (c.x == u["col"] and c.y == u["row"])):
			var ap := ORIGIN + Vector2(u["col"] + 0.5, u["row"] + 0.5) * CS
			var a0 := -0.6 if army.team == 0 else PI - 0.6
			var hov: bool = c.x == u["col"] and c.y == u["row"]
			_arc_clipped(ap, 6.0 * CS, a0, a0 + 1.2, Color(1, 0.9, 0.5, 0.45 if hov else 0.12), 2.0 if hov else 1.5)   # 停著的那隻亮、其他淡（Antigravity S3）
	if _enemy_visible():
		for u in armies[1 - army.team].units:
			var sc := AIT.counter_score(selected, u["type"])
			if sc == 0:
				continue
			var ep := ORIGIN + Vector2(u["col"] + 0.5, u["row"] - 0.12) * CS
			var bc := Color("#4ade80") if sc > 0 else Color("#f87171")
			if drag_new or drag_from.x >= 0:
				# 拖曳時敵軍腳下亮圈：被剋淡綠、天敵淡紅（第三輪 U3）
				var fp := ORIGIN + Vector2(u["col"] + 0.5, u["row"] + 0.82) * CS
				draw_set_transform_matrix(_cam * Transform2D(0, Vector2(1, 0.5), 0, fp))
				draw_circle(Vector2.ZERO, 24, Color(bc, 0.28), true, -1.0, true)
				_hand_ring(Vector2.ZERO, 24, Color(bc, 0.7), 2.0)
				draw_set_transform_matrix(_cam)
			draw_circle(ep, 11, Color("#111827"), true, -1.0, true)
			_hand_ring(ep, 11, bc, 2.0)
			if sc > 0:
				draw_polyline(PackedVector2Array([ep + Vector2(-5, 0), ep + Vector2(-1, 4), ep + Vector2(6, -5)]), bc, 3.0, true)
			else:
				draw_line(ep + Vector2(-5, -5), ep + Vector2(5, 5), bc, 3.0, true)
				draw_line(ep + Vector2(-5, 5), ep + Vector2(5, -5), bc, 3.0, true)



## 把一隻（格子或自由座標）放進 keep：自由規則照座標放；格子規則吸附到最近的格子（Antigravity 第二輪：自由陣型也能用在格子）。
func _place_from(keep, u: Dictionary) -> bool:
	var p: Vector2i = Army.pos_of(u)
	if keep.deploy == "free":
		return keep.place_xy(int(u["type"]), Army.quant(p.x), Army.quant(p.y))
	return keep.place(int(u["type"]), clampi(p.x / 1000, 0, 15), clampi(p.y / 1000, 0, 8))


## 載入陣型（存檔格、貼上代碼）：先解碼到暫存陣型，全軍都是這場開放的兵種才替換（Codex 實作審查 #1）。
## 回傳 ""＝成功、"locked"＝含未開放兵種、其他＝格式錯誤。
func _load_checked(code: String) -> String:
	if rules != null:
		# 第五輪：自訂規則下，存檔格的陣型照這局的限制重新驗證——合法的放上去、不合法的拿掉，並用橫幅列出來
		var raw = _decode_any(code)
		if raw is String:
			return raw
		var keep = armies[0].copy()
		keep.units = []
		keep.guard_combat = true   # 保留戰鬥兵需要的錢與名額（Codex 實作第 2 輪：不會載入成只剩支援兵）
		var gone := {}
		var ordered: Array = raw.units.duplicate()
		ordered.sort_custom(func(p, q): return (0 if not D.is_support(int(p["type"])) else 1) < (0 if not D.is_support(int(q["type"])) else 1))
		for u in ordered:
			var t := int(u["type"])
			if not _place_from(keep, u):
				gone[t] = int(gone.get(t, 0)) + 1
		armies[0].units = keep.units
		_fp_abort_drag()
		fp_sel = []   # 換了陣型，舊的框選索引作廢（Codex 實作第 2 輪 #8）
		if not gone.is_empty():
			var bits: Array = []
			for t in gone:
				bits.append("%s×%d" % [L.t("unit_%d" % t), gone[t]])
			removed_banner = L.t("removed_by_rules", ["、".join(bits)])
			removed_banner_t = 4.0
		return ""
	var tmp := Army.new(armies[0].team, armies[0].budget)
	var why := tmp.load_code(code)
	if why != "":
		return why
	for u in tmp.units:
		if not _allowed(int(u["type"])):
			return "locked"
		u.erase("st")     # V1.4 #9 #12：貼紙只在遠征裡貼，貼上陣型碼不帶進來（Codex v140-i5）
		u.erase("boss")
	armies[0].units = tmp.units
	fp_sel = []
	return ""



# ── 擺放 HUD ──
func _draw_place_hud() -> void:
	# 第五輪 §4.4：頂部兩行。第一行＝模式／局數（左）、目前在做什麼＋金幣條＋人數（中）、規則徽章（右）；
	# 第二行＝選中兵種的資訊帶（名稱、一句定位、剋／怕頭像），完全在棋盤外，不蓋部署格。
	_hud_bar(Rect2(0, 0, 1280, 92))   # V1.2：頂部資訊列改深木紋（原本是平塗深底）
	draw_line(Vector2(0, 50), Vector2(1280, 50), Color(1, 1, 1, 0.08), 1.0)
	var a = _cur_army()
	var tcol := Art.team_color(a.team, cbm())
	# 左：模式與局數
	var ml := _mode_label()
	if mode == Mode.DUEL:
		ml = L.t("menu_duel")   # 規則細節已經在中間大字，左上只放模式名稱（避免換行）
	_text(Vector2(16, 6), ml, tz("S"), TXT_DIM, false, true, 380)
	if mode == Mode.VS_AI or mode == Mode.DUEL:
		_text(Vector2(16, 6 + tz("S") * 1.35), "%s　%s" % [L.t("round", [round_no]), L.t("score", [wins[0], wins[1]])], tz("C"), TXT_DIM, false, false, 300)
	# 中：一句話＋金幣條
	var head := L.t("place_title")
	if mode == Mode.DUEL:
		if tp != null:
			if tp.done():
				head = L.t("both_done")
			else:
				var hand := "" if not tp.is_snake() else L.t("hand_of", [mini(tp.hands_max(), tp.hands_done[tp.current] + 1), tp.hands_max()])
				head = L.t("turn_big", [L.t("blue") if tp.current == 0 else L.t("red"), hand, tp.turn_left()])
		else:
			head = L.t("both_done") if blind_phase == 2 else L.t("blind_turn", [L.t("blue") if blind_phase == 0 else L.t("red"), L.t("red") if blind_phase == 0 else L.t("blue")])
			if bool(get("sealed_on")) and blind_phase < 2:
				head = L.t("sealed_turn", [L.t("blue") if blind_phase == 0 else L.t("red"), get("sealed")[blind_phase].size() + 1])   # V1.4 #13
	elif mode == Mode.VS_AI and bool(get("wv_active")):
		head = L.t("wv_head", [int(get("wv_no")), int(rules.budget_of(1)) if rules != null else 0])   # Antigravity v140-i3：常駐波數
	elif mode == Mode.TUTORIAL or mode == Mode.PUZZLE:
		var pz := PZ.get_puzzle(puzzle_id)
		head = L.field(pz, "")
	elif mode == Mode.GAUNTLET:
		head = "%s・%s" % [L.t("gauntlet_title", [gauntlet_stage]), L.t("ga_node_" + str(call("ga_node", gauntlet_stage)))]
	var hz := tcap(tz("H2"), 26)
	_text(Vector2(640, 2), head, hz, tcol if mode == Mode.DUEL else Color.WHITE, true, true, 520)
	var star := -1
	if mode == Mode.PUZZLE:
		var pzs := PZ.get_puzzle(puzzle_id)
		star = a.budget - int(pzs["budget"]) + int(pzs["star3"])   # 三星條件（只花 ≤N 金）換算成金幣條上的位置
	var gb := Rect2(440, 6 + hz * 1.35, 230, 12)
	Charts.gold_bar(self, gb, a.units, a.budget, star)
	if _is_free():
		_fp_gold_preview(gb, a)
	var gtxt := L.t("gold_of", [a.spent(), a.budget])
	_text(Vector2(gb.end.x + 10, gb.position.y - tz("S") * 0.45), gtxt, tz("S"), ACCENT, false, true)
	var ux := gb.end.x + 18 + _width(gtxt, tz("S"), true)
	_text(Vector2(ux, gb.position.y - tz("S") * 0.45), L.t("units_of", [a.count(), a.unit_cap]), tz("S"), TXT_DIM, false, true)
	if mode == Mode.DUEL and tp != null and rules != null and rules.handicap:
		_text(Vector2(440, gb.end.y + 2), L.t("hc_both", [rules.budget_of(0), rules.budget_of(1)]), tz("C"), TXT_DIM)
	# 右：規則徽章（非標準時）
	if rules != null and (mode == Mode.VS_AI or mode == Mode.DUEL):
		var b := Presets.badge(rules, "duel" if mode == Mode.DUEL else "ai")
		if b != Presets.BADGE_CERT or not rules.diff(Presets.make("standard", "duel" if mode == Mode.DUEL else "ai", rules.pool_of(0))).is_empty():
			_badge_pill(Vector2(1100, 8), b)
	# 第二行：資訊帶
	_draw_info_band(Rect2(0, 52, 1280, 40), hover_card if hover_card >= 0 else selected, a.team)
	# 卡列
	for i in _card_types():
		var r := _card_rect(i)
		var cap_ok: bool = a.type_cap == 0 or a.count_of(i) < a.type_cap
		var afford: bool = D.cost(i) <= a.left() and a.count() < a.unit_cap and _allowed(i) and cap_ok
		var bg := TH_WOOD   # V1.2：兵卡改木牌色（原本藍灰，像工程介面）
		if i == selected:
			bg = TH_ACTIVE
		elif i == hover_card:
			bg = TH_WOOD_L
		var opened := _allowed(i)
		if afford and not bool(Save.s("plain_ui")) and _tex_box(r, "wood", Color(bg.r * 1.28, bg.g * 1.28, bg.b * 1.28)):
			pass
		else:
			draw_rect(r, bg if afford else Color(bg, 0.45))
		draw_rect(r, tcol if i == selected else Color(1, 1, 1, 0.15), false, 2)
		if layout_probe:
			probe_ctrls.append(r)   # 兵卡是控制項：卡上的小字不算「要讀的文字」段數
		# 三層卡：上＝快捷鍵、價錢；中＝全身圖；下＝已擺數量、?
		Art.unit(self, r.position + Vector2(r.size.x / 2, 74), i, a.team, 1.0, 0.0, 0.0, 0.0, (1.0 if afford else 0.45) if opened else 0.25, time, 0.78, cbm())
		var fz := tz("C")
		_text(r.position + Vector2(5, 3), "%d" % ((_card_types().find(i) + 1) % 10), fz, TXT_DIM, false, false, 20)
		if opened:
			var gt: String = L.t("gold", [D.cost(i)])
			var gw := _width(gt, fz, true)
			_text(r.position + Vector2(r.size.x - 5 - gw, 3), gt, fz, ACCENT if afford else Color("#f87171"), false, true)
			if a.count_of(i) > 0:
				var cnt := "×%d" % a.count_of(i) if a.type_cap == 0 else "×%d/%d" % [a.count_of(i), a.type_cap]
				_text(r.position + Vector2(5, r.size.y - fz - 8), cnt, fz, Color(1, 1, 1, 0.85) if cap_ok else Color("#f87171"), false, true, r.size.x - 40)
		else:
			_lock_icon(r.position + Vector2(r.size.x - 14, 14))
		_btn_quiet(_card_help_rect(i), "?", _open_codex.bind(i))   # 第七輪 N6：點擊框不變，外觀只留一個小問號，不切到角色
	var start_label := L.t("start")
	var start_en := _ready_to_fight()
	if mode == Mode.DUEL and tp != null and not tp.done():
		start_label = L.t("end_hand")
		start_en = tp.can_end_turn()
	elif mode == Mode.DUEL and tp == null and blind_phase < 2:
		start_label = L.t("blind_ready", [L.t("blue") if blind_phase == 0 else L.t("red")])
		start_en = _cur_army().count() > 0 and (rules == null or _cur_army().has_combat())
	var why := _start_block_reason()
	if why != "":
		start_en = false
		_text(Vector2(1076, 664), why, tz("C"), Color("#ff8a8a"), true, true, 380)   # 開戰鈕灰掉時直接寫原因（Antigravity 第二輪）
	_btn(Rect2(884, 690, 384, 50), start_label, func(): _on_start(), start_en, true)
	if mode == Mode.VS_AI or (mode == Mode.GAUNTLET and gauntlet_stage == 1):
		_btn(Rect2(884, 746, 120, 44), L.t("formations"), func(): _open("slots"))
	if mode == Mode.GAUNTLET and gauntlet_stage > 1:
		_btn(Rect2(884, 746, 120, 44), L.t("ga_info"), func(): overlay = "ga_info")   # V1.4 收尾：本戰條件（契約、加成、宿敵／巨獸、貼紙）
	if mode == Mode.PUZZLE:
		_btn(Rect2(884, 746, 120, 44), L.t("menu_hint"), func(): call("_puzzle_hint"))
		if PZ.get_puzzle(puzzle_id).has("cmd"):
			_draw_plan_panel(Rect2(520, 692, 356, 100))
	if _can_edit_existing():
		_btn(Rect2(1012, 746, 120, 44), L.t("clear"), func(): _clear_mine())
	_btn(Rect2(1140, 746, 128, 44), L.t("menu"), func(): _request_leave())
	if removed_banner_t > 0.0:
		var bw := _width(removed_banner, tz("B"), true) + 40
		var br := Rect2(640 - bw / 2, 100, bw, tz("B") * 1.8)
		draw_rect(br, Color(0.45, 0.12, 0.12, 0.92))
		draw_rect(br, Color("#ff8a8a"), false, 2.0)
		_text(Vector2(640, br.position.y + tz("B") * 0.35), removed_banner, tz("B"), Color.WHITE, true, true)



## 資訊帶（第五輪 §4.4）：選中／停留的兵種名稱、一句定位、剋／怕頭像（28px 以上），右邊「?」開操作說明。
## 殘局顯示提示與三星條件；遠征顯示還能改幾隻。
func _draw_info_band(R: Rect2, i: int, team: int) -> void:
	draw_rect(R, Color(0, 0, 0, 0.35))
	var y := R.position.y + (R.size.y - tz("S") * 1.1) / 2
	var x := 16.0
	var help := Rect2(R.end.x - 46, R.position.y + 2, 36, 36)
	_btn(help, "?", func(): show_place_help = not show_place_help)
	if mode == Mode.TUTORIAL or mode == Mode.PUZZLE:
		var pz := PZ.get_puzzle(puzzle_id)
		var hint: String = L.field(pz, "hint")
		if mode == Mode.PUZZLE:
			var st := "　★ " + L.t("star2_short", [pz["star2"]]) + "　★ " + L.t("star3_short", [pz["star3"]])
			if PZ.goal(pz) != "win":
				st = "　" + L.t("goal_prefix") + _goal_text(pz) + st   # 第十三輪：護送、撐住、斬首（V1.1：前面加「過關：」，和星數條件分開）
			if pz.has("cap"):
				st = "　" + L.t("cap_note", [int(pz["cap"])]) + st
			_text(Vector2(R.end.x - 60 - _width(st, tz("S"), true), y), st, tz("S"), ACCENT, false, true)
			_text(Vector2(x, y), hint, tz("S"), Color(1, 1, 1, 0.85), false, false, R.size.x - 120 - _width(st, tz("S"), true))
		else:
			_text(Vector2(x, y), hint, tz("S"), Color(1, 1, 1, 0.85), false, false, R.size.x - 80)
		_draw_place_help()
		return
	if mode == Mode.GAUNTLET and gauntlet_stage > 1:
		var gt := L.t("gauntlet_changes", [maxi(0, gauntlet_changes - _gauntlet_diff())])
		_text(Vector2(R.end.x - 60 - _width(gt, tz("S")), y), gt, tz("S"), ACCENT)
	var name: String = L.t("unit_%d" % i)
	_text(Vector2(x, y - 2), name, tz("B"), ACCENT, false, true)
	x += _width(name, tz("B"), true) + 12
	if not _allowed(i) and not (rules != null):
		var lock: String = L.t("locked_demo") if not RS.available(i, _demo()) else L.t("locked_classic")
		_text(Vector2(x, y), lock, tz("S"), TXT_DIM)
		_draw_place_help()
		return
	var blurb: String = L.t("blurb_%d" % i)
	# 第八輪：放不下一行就換行並墊底色，免得掉進戰場讀不到（不縮字：字級表是無障礙底線）
	var bsz: int = tz("S")
	if _width(blurb, bsz) > 470.0:
		var bh: float = font.get_multiline_string_size(blurb, HORIZONTAL_ALIGNMENT_LEFT, 470, bsz).y
		draw_rect(Rect2(x - 4, y - 2, 478, bh + 6), Color(0.07, 0.08, 0.11, 0.9))
	_text(Vector2(x, y), blurb, bsz, Color(1, 1, 1, 0.85), false, false, 470)
	x += minf(_width(blurb, bsz), 470.0) + 20
	var beats: Array = []
	var fears: Array = []
	for t in D.COUNT:
		var sc := AIT.counter_score(i, t)
		if sc > 0:
			beats.append(t)
		elif sc < 0:
			fears.append(t)
	var lab_b: String = L.t("synergy") if D.is_support(i) else L.t("beats")
	var list_b: Array = AIT.SYNERGY.get(i, []) if D.is_support(i) else beats
	for grp in [[lab_b, list_b, Color("#4ade80")], [L.t("fears"), fears, Color("#f87171")]]:
		if grp[1].is_empty():
			continue
		# 第十輪 V8：一組一個底框，圖示不貼字
		var pill_w: float = _width(grp[0], tz("S"), true) + 16.0 + grp[1].size() * 38.0
		_box(Rect2(x - 6, R.position.y + 2, minf(pill_w, help.position.x - x), R.size.y - 4), Color(0, 0, 0, 0.22), Color(0, 0, 0, 0), 8.0)
		_text(Vector2(x, y), grp[0], tz("S"), grp[2], false, true)
		x += _width(grp[0], tz("S"), true) + 10
		for t in grp[1]:
			if x > help.position.x - 40:
				break
			draw_circle(Vector2(x + 17, R.get_center().y), 17, Color(1, 1, 1, 0.08))
			Art.unit(self, Vector2(x + 17, R.position.y + 39), t, 1 - team, 1.0, 0.0, 0.0, 0.0, 1.0, time, 0.68, cbm())
			x += 38
		x += 18
	_draw_place_help()



## 操作說明（第五輪：從頂部移到「?」；第一次進擺放畫面自動打開）。
func _draw_place_help() -> void:
	if not show_place_help:
		return
	var lines: Array = [L.t("place_hint_lock")]
	if _is_free():
		# 第六輪：自由排兵的手勢（雙人＝放開即落子、不能收回）
		lines.append(L.t("place_hint_fp_turns" if mode == Mode.DUEL and tp != null else "place_hint_fp"))
		lines.append(L.t("place_hint_fp_tools"))
	elif mode == Mode.DUEL and tp != null:
		lines.append(L.t("place_hint_turns"))
	else:
		lines.append(L.t("place_hint_free"))
	var kt: Dictionary = Save.s("keys")
	lines.append(L.t("place_hint_keys", [Keymap.key_name(kt, "prev"), Keymap.key_name(kt, "next"), Keymap.key_name(kt, "start"), Keymap.key_name(kt, "codex")]))
	var body := "\n".join(lines)
	var w := 520.0
	var h := text_h(body, tz("S"), w - 28) + 24
	var r := Rect2(1280 - w - 12, 96, w, h)
	draw_rect(r, Color(0.06, 0.07, 0.1, 0.95))
	draw_rect(r, ACCENT, false, 1.5)
	_text(r.position + Vector2(14, 12), body, tz("S"), Color.WHITE, false, false, w - 28)



func _clear_mine() -> void:
	var a = _cur_army()
	if mode == Mode.TUTORIAL or mode == Mode.PUZZLE:
		var pz := PZ.get_puzzle(puzzle_id)
		a.units = a.units.filter(func(u): return PZ.is_fixed(pz, u["col"], u["row"]))
	elif mode == Mode.GAUNTLET and gauntlet_stage > 1:
		a.units = gauntlet_prev.duplicate(true)
	elif mode == Mode.VS_AI and bool(get("wv_active")):
		a.units = get("wv_lock").duplicate(true)   # 車輪戰：清空只清新補的兵
	else:
		if _is_free():
			_fp_push_undo()   # 自由模式：清空可以 Ctrl＋Z 復原
		a.clear()
	fp_sel = []
	_fp_abort_drag()

## 第十三輪：時序殘局的施放時間（戰鬥中不能按，照這裡設定的秒數放）。每格 0.5 秒。
func _draw_plan_panel(R: Rect2) -> void:
	# V1.4 #4：擺陣畫面只放精簡摘要＋「排軍令」按鈕；完整的木刻度尺在 overlay（_draw_plan_overlay）
	var pz := PZ.get_puzzle(puzzle_id)
	_tex_box(R, "paper")
	_ink_mode = true
	var parts: Array = []
	for e in puzzle_plan:
		parts.append(L.t("plan_item", [L.t("cmd_%d" % PZ.plan_skill(pz, int(e))), _fmt_num(PZ.plan_tick(pz, int(e)) / 20.0)]))
	_text(R.position + Vector2(12, 8), L.t("plan_title"), tz("C"), INK, false, true, R.size.x - 24)
	_text(R.position + Vector2(12, 8 + tz("C") * 1.35), "・".join(parts), tz("C"), INK, false, false, R.size.x - 24)
	_ink_mode = false
	_btn(Rect2(R.end.x - 132, R.end.y - 46, 124, 40), L.t("plan_open"), func(): overlay = "puzzle_plan")
	if pad_mode:
		_text(Vector2(R.position.x + 10, R.position.y - tz("C") * 1.4), L.t("plan_pad"), tz("C"), TXT_DIM, false, false, R.size.x)

## V1.4 #4 軍令連鎖：連鎖的組合（先放 a、3 秒內放 b）。只是提示，模擬照原本規則算。
const CHAINS := [[4, 3, "chain_freeze_meteor"], [0, 1, "chain_aegis_war"], [4, 1, "chain_freeze_war"], [1, 2, "chain_war_heal"]]
var plan_sel := 0
var plan_drag := -1          # V1.4 #4：正在拖的軍令（Codex v140-i4：說好可拖曳）
var plan_press_prev := false

## 完整的軍令時間軸：木刻度尺（羊皮紙底＋墨線刻度），我方軍令是木棋子、敵方是紅旗；同一種技能的冷卻畫成淡帶，
## 連鎖用金色弧線連起來。點棋子選取、點尺上任一處把選取的那一道移過去；◀▶ 微調半秒（手把用）。
func _draw_plan_timeline(R: Rect2) -> void:
	var pz := PZ.get_puzzle(puzzle_id)
	var c: Dictionary = pz["cmd"]
	plan_sel = clampi(plan_sel, 0, maxi(0, puzzle_plan.size() - 1))   # 換關後索引不越界（Antigravity v140-i4）
	var goal: int = int(pz.get("goal_ticks", Sim.MAX_TICKS))
	var cd: int = PZ.rules_of(pz).cmd_cd
	var ruler := Rect2(R.position.x + 20, R.position.y + 64, R.size.x - 40, 74)
	_tex_box(Rect2(ruler.position - Vector2(6, 6), ruler.size + Vector2(12, 14 + tz("C") * 1.3)), "paper")   # 秒數也在紙上（版面檢查：墨字落到深色底對比不足）
	var x_of := func(t: int) -> float: return ruler.position.x + ruler.size.x * clampf(float(t) / float(goal), 0.0, 1.0)
	# 刻度：每秒一小刻、每 5 秒一大刻＋秒數
	_ink_mode = true
	for sec in int(goal / 20) + 1:
		var x: float = x_of.call(sec * 20)
		var big := sec % 15 == 0   # 收尾第 2 輪：每 15 秒才標數字，細刻度淡一點（不像事件編輯器）
		var mid := sec % 5 == 0
		draw_line(Vector2(x, ruler.end.y - (14 if big else (9 if mid else 5))), Vector2(x, ruler.end.y), Color(INK, 0.75 if big else (0.4 if mid else 0.2)), 1.6 if big else 1.0, true)
		if big and sec > 0 and sec * 20 < goal:   # 兩端的 0s、最後一秒不寫（會壓到紙邊；版面檢查）
			_text(Vector2(x, ruler.end.y + 4), "%ds" % sec, tz("C"), INK, true, false, 60)
	_ink_mode = false
	# 冷卻淡帶
	for e in puzzle_plan:
		var t := PZ.plan_tick(pz, int(e))
		draw_rect(Rect2(x_of.call(t), ruler.position.y + 44, x_of.call(t + cd) - x_of.call(t), 8), Color(0.42, 0.3, 0.16, 0.22))
	# 敵方軍令：紅色小旗（在尺的上緣）
	for en in c.get("enemy", []):
		var ex: float = x_of.call(int(en[0]))
		draw_line(Vector2(ex, ruler.position.y - 18), Vector2(ex, ruler.position.y + 6), Color("#5a1d14"), 2.0, true)
		draw_colored_polygon(PackedVector2Array([Vector2(ex, ruler.position.y - 18), Vector2(ex + 14, ruler.position.y - 13), Vector2(ex, ruler.position.y - 8)]), Color("#b3261e"))
		_icon(CmdD.ICONS[int(en[1])], Vector2(ex + 26, ruler.position.y - 13), 16.0, Color("#ffb4a8"))
	# 連鎖：金色弧線
	var chains_on: Array = []
	for a in puzzle_plan.size():
		for b in puzzle_plan.size():
			var ta := PZ.plan_tick(pz, int(puzzle_plan[a]))
			var tb := PZ.plan_tick(pz, int(puzzle_plan[b]))
			if tb < ta or tb - ta > 60 or a == b or (tb == ta and b < a):
				continue   # 同一刻照排程順序（和 cmd_log 一致）
			for ch in CHAINS:
				if PZ.plan_skill(pz, int(puzzle_plan[a])) == int(ch[0]) and PZ.plan_skill(pz, int(puzzle_plan[b])) == int(ch[1]):
					var xa: float = x_of.call(ta)
					var xb: float = x_of.call(tb)
					var mid := Vector2((xa + xb) * 0.5, ruler.position.y + 4)
					draw_polyline(PackedVector2Array([Vector2(xa, ruler.position.y + 20), mid - Vector2(0, 10), Vector2(xb, ruler.position.y + 20)]), Color("#d4a017"), 3.0, true)
					if not chains_on.has(str(ch[2])):
						chains_on.append(str(ch[2]))
	# 我方軍令：木棋子（技能圖示），選取的那一個金框。同一秒附近的棋子往右錯開、拉一條細線指回真正的時間（Codex v140-i4）
	var pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var placed: Array = []
	for i in puzzle_plan.size():
		var t2 := PZ.plan_tick(pz, int(puzzle_plan[i]))
		var cx: float = x_of.call(t2)
		var lane := 0
		for px in placed:
			if absf(float(px) - cx) < 30.0:
				lane += 1
		placed.append(cx)
		var cpos := Vector2(cx + lane * 32.0, ruler.position.y + 26)
		if lane > 0:
			draw_line(Vector2(cx, ruler.position.y + 40), cpos + Vector2(-10, 10), Color(INK, 0.6), 1.4, true)
		var hit := Rect2(cpos - Vector2(16, 16), Vector2(32, 32))
		if pressed and not plan_press_prev and plan_drag < 0 and hit.has_point(mouse) and not pad_mode:
			plan_drag = i
			plan_sel = i
		if plan_drag == i:
			cpos.x = clampf(mouse.x, ruler.position.x, ruler.end.x)   # 拖曳中跟著滑鼠
		var sk := PZ.plan_skill(pz, int(puzzle_plan[i]))
		draw_circle(cpos + Vector2(0, 2), 15.0, Color(0.2, 0.12, 0.06, 0.5), true, -1.0, true)
		draw_circle(cpos, 15.0, Color("#8a5f37"), true, -1.0, true)
		draw_circle(cpos, 12.0, Color("#b5895a"), true, -1.0, true)
		_icon(CmdD.ICONS[sk], cpos, 16.0, Color.WHITE)
		if i == plan_sel:
			_hand_ring(cpos, 19.0, ACCENT, 2.6, true)
		var ii := i
		_btns.append({"r": Rect2(cpos - Vector2(16, 16), Vector2(32, 32)), "cb": func(): plan_sel = ii, "en": true})
	if plan_drag >= 0 and not pressed:
		# 放開：照冷卻與開場限制修正後落子
		if plan_drag < puzzle_plan.size():
			var td := int(clampf((mouse.x - ruler.position.x) / ruler.size.x, 0.0, 1.0) * goal / 10.0) * 10
			puzzle_plan = PZ.plan_fix(pz, puzzle_plan, plan_drag, td - PZ.plan_tick(pz, int(puzzle_plan[plan_drag])))
			sfx.play("place_light")
		plan_drag = -1
	plan_press_prev = pressed
	# 點尺：把選取的軍令移過去（照冷卻與開場限制修正）
	_btns.append({"r": Rect2(ruler.position.x, ruler.position.y + 44, ruler.size.x, ruler.size.y - 44), "cb": func():
		var tt := int(clampf((mouse.x - ruler.position.x) / ruler.size.x, 0.0, 1.0) * goal / 10.0) * 10
		if plan_sel >= 0 and plan_sel < puzzle_plan.size():
			puzzle_plan = PZ.plan_fix(pz, puzzle_plan, plan_sel, tt - PZ.plan_tick(pz, int(puzzle_plan[plan_sel]))), "en": true})
	# 說明列：選取的是哪一道、幾秒；連鎖
	var y := ruler.end.y + tz("C") * 1.6 + 8
	if plan_sel >= 0 and plan_sel < puzzle_plan.size():
		var se := int(puzzle_plan[plan_sel])
		_text(Vector2(R.position.x + 20, y), L.t("plan_sel", [L.t("cmd_%d" % PZ.plan_skill(pz, se)), _fmt_num(PZ.plan_tick(pz, se) / 20.0)]), tz("S"), Color.WHITE, false, true, R.size.x - 180)
		_btn(Rect2(R.end.x - 132, y - 6, 56, 40), "◀", func(): puzzle_plan = PZ.plan_fix(pz, puzzle_plan, plan_sel, -10))
		_btn(Rect2(R.end.x - 72, y - 6, 56, 40), "▶", func(): puzzle_plan = PZ.plan_fix(pz, puzzle_plan, plan_sel, 10))
	y += tz("S") * 1.6
	if not chains_on.is_empty():
		var names: Array = []
		for k in chains_on:
			names.append(L.t(k))
		_text(Vector2(R.position.x + 20, y), L.t("chain_on", [L.t("list_sep").join(names)]), tz("S"), Color("#ffd166"), false, true, R.size.x - 40)

## 第 i 次能設的範圍：不早於開場可放的時間、和前後兩次至少隔一個冷卻，不晚於局長（Codex v13-r1 #4）。
func _plan_range(i: int) -> Array:
	var pz := PZ.get_puzzle(puzzle_id)
	var cd: int = PZ.rules_of(pz).cmd_cd
	var lo: int = CmdD.START_TICKS if i == 0 else int(puzzle_plan[i - 1]) + cd
	var hi: int = int(pz.get("goal_ticks", Sim.MAX_TICKS)) - 10
	if i + 1 < puzzle_plan.size():
		hi = mini(hi, int(puzzle_plan[i + 1]) - cd)
	return [lo, hi]

func _plan_nudge(i: int, d: int) -> void:
	var lo_hi := _plan_range(i)
	puzzle_plan[i] = clampi(int(puzzle_plan[i]) + d, int(lo_hi[0]), maxi(int(lo_hi[0]), int(lo_hi[1])))
	sfx.play("k_click", 0.6)

## 手把：L3 開提示、R3 開時間設定（格子部署時方向鍵是游標，進不了畫面按鈕，Codex v13-r1 #3）。
func _draw_plan_overlay() -> void:
	draw_rect(Rect2(0, 0, 1280, 800), Color(0, 0, 0, 0.55))
	var R := Rect2(170, 170, 940, 470)
	_panel(R)
	_h1(Vector2(640, 182), L.t("plan_title"))
	_text(Vector2(640, 182 + tz("H1") * 1.4), L.t("plan_help"), tz("C"), TXT_DIM, true, false, 860)
	_draw_plan_timeline(Rect2(R.position.x + 20, R.position.y + 90, R.size.x - 40, 300))
	_btn(Rect2(560, R.end.y - 60, 160, 44), L.t("plan_done"), func(): overlay = "", true, true)
