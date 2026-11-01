extends "res://scripts/ui/codex_view.gd"
## 狀態機、模式、輸入、擺放、標題、選單、設定、結果、成就。

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot=") or a.begins_with("--steam-test=") or a.begins_with("--perf="):
			Save.prefix = "shot_"   # 不讀、不寫玩家真正的存檔
	Save.load_all()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--steam-test="):
			var aid := int(a.substr(13))
			SteamApi.init(aid, false)
			var res: Dictionary = SteamApi.self_test(aid)
			print("STEAMTEST ", JSON.stringify(res))
			get_tree().quit(0 if res["ok"] else 1)
			return
	L.lang = Save.s("lang")
	duel_rule = Save.s("duel_rule")
	speed = float(Save.s("speed"))
	var _ua := OS.get_cmdline_user_args()
	var _special := "--video" in _ua
	for x in _ua:
		if x.begins_with("--perf="):
			_special = true
	for x in _ua:
		if x.begins_with("--capsule="):
			_special = true
	if Save.prefix == "" and not _special:   # 截圖／影片／膠囊模式完全不碰 Steam
		SteamApi.init()
	font = _load_font("res://fonts/NotoSansTC-Regular-sub.otf")
	font_bold = _load_font("res://fonts/NotoSansTC-Bold-sub.otf")
	sfx = SfxScript.new()
	add_child(sfx)
	sprites = SpriteCache.new()
	add_child(sprites)
	if capsule_path == "":
		_rebuild_sprites.call_deferred()
	sfx.set_volumes(int(Save.s("sfx")), int(Save.s("music")))
	grass = load("res://art/cainos/TX_Tileset_Grass.png")
	for i in 9:
		var tex = load("res://art/cainos/plant_%02d.png" % i)
		if tex:
			plants.append(tex)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot_dir = a.substr(7)
		elif a.begins_with("--capsule="):
			capsule_path = a.substr(10)
		elif a == "--video":
			video_mode = true
		elif a.begins_with("--perf="):
			perf_path = a.substr(7)
	if capsule_path != "":
		get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		_capture_capsule.call_deferred()
		return
	_apply_fullscreen()
	rng.seed = Time.get_ticks_usec() if (shot_dir == "" and not video_mode) else 12345
	if video_mode:
		Save.prefix = "shot_"
		Save.load_all()
	_go_title()
	if shot_dir != "":
		_run_screenshots.call_deferred()
	elif video_mode:
		_run_video.call_deferred()
	elif perf_path != "":
		_run_perf.call_deferred()


# ───────────────────────── 狀態切換 ─────────────────────────
func _go_title() -> void:
	state = St.TITLE
	overlay = ""
	sim = null
	view = null
	zoom = 1.0
	_focus = 0
	_new_demo()
	sfx.play_music("music_title")


func _new_demo() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = rng.randi()
	demo = Sim.new(AI.build(0, 100, r)["army"], AI.build(1, 100, r)["army"])
	demo.fast = true
	demo_acc = 0.0


func _start_mode(m: int) -> void:
	mode = m
	wins = [0, 0]
	round_no = 1
	series_over = false
	last_player_formation = []
	overlay = ""
	if m == Mode.GAUNTLET:
		gauntlet_stage = 1
		gauntlet_prev = []
		gauntlet_changes = 99
		gauntlet_seed = rng.randi()
	_reset_place()


func _reset_place(keep_blue := false) -> void:
	state = St.PLACE
	sim = null
	view = null
	fx.clear()
	dying.clear()
	zoom = 1.0
	tp = null
	blind_phase = 0
	_focus = 0
	var blue_keep = armies[0].copy() if keep_blue and not armies.is_empty() else null
	armies = [Army.new(0, 100), Army.new(1, 100)]
	match mode:
		Mode.VS_AI:
			if blue_keep != null:
				armies[0] = blue_keep
		Mode.DUEL:
			if duel_rule != "blind":
				tp = TP.new(armies[0], armies[1], (round_no + 1) % 2, duel_rule)
		Mode.TUTORIAL, Mode.PUZZLE:
			var pz := PZ.get_puzzle(puzzle_id)
			armies[0] = PZ.player_army(pz)
			armies[1] = PZ.enemy_army(pz)
			selected = int(pz["allowed"][0])
		Mode.GAUNTLET:
			if not gauntlet_prev.is_empty():
				armies[0].units = gauntlet_prev.duplicate(true)
			var r := RandomNumberGenerator.new()
			r.seed = gauntlet_seed + gauntlet_stage * 7919
			var lvl := mini(2, (gauntlet_stage - 1) / 2)
			var e := AIT.build_full(1, r, lvl, gauntlet_prev)
			e.budget = 100 + 5 * (gauntlet_stage - 1)
			var guard := 0
			while e.can_afford_any() and guard < 20:
				guard += 1
				var t := AIT.choose_type(e, gauntlet_prev, e.left(), r, lvl)
				if t < 0:
					break
				var c := AIT.choose_cell(e, t, gauntlet_prev, r)
				if c.x < 0 or not e.place(t, c.x, c.y):
					break
			armies[1] = e
	sfx.play_music("music_place")


func _cur_army():
	if mode == Mode.DUEL:
		if tp != null:
			return tp.armies[tp.current]
		return armies[0] if blind_phase == 0 else armies[1]
	return armies[0]


func _enemy_visible() -> bool:
	if mode == Mode.TUTORIAL or mode == Mode.PUZZLE or mode == Mode.GAUNTLET:
		return true
	if mode == Mode.DUEL:
		return tp != null
	return false


func _ready_to_fight() -> bool:
	if mode == Mode.DUEL:
		if tp != null:
			return tp.done()
		return blind_phase == 2
	return armies[0].count() > 0


func _on_start() -> void:
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
		blind_phase += 1
		sfx.play("turn")
		return
	if armies[0].count() == 0:
		_toast(L.t("err_empty"), true)
		return
	if mode == Mode.GAUNTLET and gauntlet_stage > 1 and _gauntlet_diff() > gauntlet_changes:
		_toast(L.t("err_changes"), true)
		return
	if mode == Mode.VS_AI:
		var r := RandomNumberGenerator.new()
		r.seed = rng.randi()
		match difficulty:
			0:
				armies[1] = AIT.build_full(1, r, 0, [])
				ai_name = L.t("diff_easy")
			1:
				var res = AI.build(1, 100, r)
				armies[1] = res["army"]
				ai_name = "%s・%s" % [L.t("diff_normal"), res["name"]]
			_:
				armies[1] = _hard_ai(r)
				ai_name = L.t("diff_hard")
	last_player_formation = armies[0].units.duplicate(true)
	_begin_battle(armies[0].copy(), armies[1].copy())


## 困難 AI：第 1 局沒有資訊，用會讀對方的落子 AI 自己組；之後讀你上一局的陣型，
## 先查離線反制庫（組成最接近的原型），查不到就用啟發式反制。不偷看你這一局。
func _hard_ai(r: RandomNumberGenerator) -> Army:
	var known: Array = last_player_formation if round_no > 1 else []
	if not known.is_empty():
		var lib := _counter_lib()
		if not lib.is_empty():
			var mine := [0, 0, 0, 0, 0]
			for u in known:
				mine[u["type"]] += D.cost(u["type"])
			var best = null
			var bd := 1 << 30
			for e in lib:
				var d := 0
				for k in 5:
					d += absi(int(e["proto_comp"][k]) - mine[k])
				if d < bd:
					bd = d
					best = e
			if best != null and bd <= 40:
				var a := Army.new(1, 100)
				if a.load_code(best["code"]) == "":
					return a
	return AIT.build_full(1, r, 2, known)


func _counter_lib() -> Array:
	if not FileAccess.file_exists("res://data/counter_lib.json"):
		return []
	var p = JSON.parse_string(FileAccess.get_file_as_string("res://data/counter_lib.json"))
	return p if typeof(p) == TYPE_ARRAY else []


func _begin_battle(a0, a1) -> void:
	last_armies = [a0.copy(), a1.copy()]
	sim = Sim.new(a0, a1)
	view = ViewBuffer.new(sim)
	atk_hit.clear()
	brace_t.clear()
	state = St.BATTLE
	prev_pos.clear()
	for u in view.units:
		prev_pos[u.id] = Vector2(u.x, u.y)
	_pump_view()   # 開場先預填 DELAY 個 tick
	accum = 0.0
	slow_used = false
	slow_left = 0.0
	hitstop = 0.0
	zoom = 1.0
	zoom_target = 1.0
	fx.clear()
	dying.clear()
	atk_t.clear()
	hurt_t.clear()
	ev_count = {}
	frenzy_seen = false
	result_delay = 0.0
	pt_call_tick = -1
	pt_rated = false
	_focus = 0
	speed = float(Save.s("speed"))
	sfx.play("start")
	sfx.play_music("music_battle")


func _finish_battle() -> void:
	state = St.RESULT
	_focus = 0
	slow_left = 0.0
	zoom_target = 1.0
	var w: int = sim.winner
	if w >= 0:
		wins[w] += 1
	series_over = wins[0] >= 2 or wins[1] >= 2 or round_no >= 5
	_build_report()
	if mode == Mode.DUEL:
		sfx.play("win" if w >= 0 else "lose")
	else:
		sfx.play("win" if w == 0 else "lose")
	_progress_and_achievements()
	Save.playtest_log(_pt_entry(0))


func _pt_entry(rating: int) -> Dictionary:
	return {"event": "rating" if rating > 0 else "battle", "mode": _mode_label(), "round": round_no, "winner": sim.winner,
		"ticks": sim.tick, "reason": sim.reason, "blue": last_armies[0].to_code(), "red": last_armies[1].to_code(),
		"power": [sim.power(0), sim.power(1)], "suspense": report.get("sus", {}), "call_tick": pt_call_tick,
		"rating": rating, "rules": D.RULES_VERSION, "digest": D.data_digest()}


func _pt_rate(v: int) -> void:
	pt_rated = true
	Save.playtest_log(_pt_entry(v))
	_toast(L.t("pt_thanks"))


func _build_report() -> void:
	var dealt := [[0, 0, 0, 0, 0], [0, 0, 0, 0, 0]]
	var taken := [[0, 0, 0, 0, 0], [0, 0, 0, 0, 0]]
	var mvp = null
	for u in sim.units:
		dealt[u.team][u.type] += u.dmg_dealt
		taken[u.team][u.type] += u.dmg_taken
		# MVP：勝方輸出最高的兵（平手時看全場）
		if (sim.winner < 0 or u.team == sim.winner) and (mvp == null or u.dmg_dealt > mvp.dmg_dealt):
			mvp = u
	var sus: Dictionary = sim.suspense()
	report = {"dealt": dealt, "taken": taken, "mvp": mvp, "sus": sus,
		"lock_sec": int(sus["lock_ratio_permille"]) * sim.tick / 1000 / 20}


func _progress_and_achievements() -> void:
	var w: int = sim.winner
	var st: Dictionary = Save.data.get("stats", {"wins": 0, "games": 0})
	st["games"] = int(st.get("games", 0)) + 1
	var me_won := w == 0 or (mode == Mode.DUEL and w >= 0)
	if w == 0 and mode != Mode.DUEL:
		st["wins"] = int(st.get("wins", 0)) + 1
	Save.data["stats"] = st
	if me_won:
		_ach("FIRST_WIN")
		if sim.alive_count(w) == 1:
			_ach("LONE_HERO")
		if int(report["sus"]["max_swing_pct"]) >= 15:
			_ach("COMEBACK")
		if sim.power(w) * 100 / (sim.budget * 1000) <= 5:
			_ach("CLOSE_CALL")
		if sim.tick >= Sim.FRENZY_TICK:
			_ach("FRENZY_WIN")
		var types := {}
		for u in sim.units:
			if u.team == w:
				types[u.type] = true
		if types.size() == 5:
			_ach("ALL_TYPES")
		# 圖鑑老兵筆記：派這個兵種贏一場 +1（第二輪方案 R3）
		for t in CX.record_win(Save.data, types.keys()):
			ach_queue.append(L.t("codex_unlocked", [L.t("unit_%d" % t)]))
		if int(ev_count.get("charge%d" % w, 0)) >= 5:
			_ach("CHARGE_5")
		if int(ev_count.get("backstab%d" % w, 0)) >= 3:
			_ach("BACKSTAB_3")
	if mode == Mode.VS_AI and w == 0 and difficulty == 2:
		_ach("HARD_WIN")
	if mode == Mode.DUEL and tp != null and series_over:
		_ach("NO_TAKEBACKS")
	if series_over and ((mode == Mode.DUEL and (wins == [2, 0] or wins == [0, 2])) or (mode == Mode.VS_AI and wins == [2, 0])):
		_ach("SWEEP")
	if mode == Mode.TUTORIAL or mode == Mode.PUZZLE:
		var pz := PZ.get_puzzle(puzzle_id)
		var extra_spent: int = armies[0].spent() - (armies[0].budget - int(pz["budget"]))
		var rem: int = sim.power(0) * 100 / (sim.budget * 1000) if w == 0 else 0
		var stars := PZ.stars(pz, w == 0, rem, extra_spent)
		var ps: Dictionary = Save.data.get("puzzle_stars", {})
		if stars > int(ps.get(puzzle_id, 0)):
			ps[puzzle_id] = stars
		Save.data["puzzle_stars"] = ps
		report["stars"] = stars
		if mode == Mode.TUTORIAL and w == 0:
			var idx := 0
			for i in PZ.tutorials().size():
				if PZ.tutorials()[i]["id"] == puzzle_id:
					idx = i
			Save.data["tutorial"] = maxi(int(Save.data.get("tutorial", 0)), idx + 1)
			if int(Save.data["tutorial"]) >= PZ.tutorials().size():
				_ach("TUTORIAL")
		if stars == 3:
			_ach("PUZZLE_3STAR")
		var all_done := true
		for p in PZ.puzzles():
			if int(ps.get(p["id"], 0)) == 0:
				all_done = false
		if all_done:
			_ach("PUZZLE_ALL")
	if mode == Mode.GAUNTLET:
		if w == 0:
			if gauntlet_stage >= 7:
				_ach("GAUNTLET")
				Save.data["gauntlet_best"] = 7
		else:
			Save.data["gauntlet_best"] = maxi(int(Save.data.get("gauntlet_best", 0)), gauntlet_stage - 1)
	_save()


func _save() -> void:
	if not Save.save_data():
		_toast(L.t("save_failed"), true)


func _ach(id: String) -> void:
	if SteamApi.unlock(id):
		ach_queue.append(L.t("achievement", [SteamApi.name_of(id, L.lang)]))


# ───────────────────────── 輸入 ─────────────────────────
func _cell_at(p: Vector2) -> Vector2i:
	var q := (p - ORIGIN) / CS
	if q.x < 0 or q.y < 0 or q.x >= 16 or q.y >= 9:
		return Vector2i(-1, -1)
	return Vector2i(int(q.x), int(q.y))


func _card_rect(i: int) -> Rect2:
	return Rect2(128 + i * (CARD_W + 8), CARD_Y, CARD_W, CARD_H)


## 兵種卡右上角的「?」：開圖鑑到這個兵種（第二輪方案 R3）。
func _card_help_rect(i: int) -> Rect2:
	var r := _card_rect(i)
	return Rect2(r.end.x - 24, r.position.y + 3, 21, 22)


func _card_at(p: Vector2) -> int:
	for i in D.COUNT:
		if _card_rect(i).has_point(p):
			return i
	return -1


func _allowed(t: int) -> bool:
	if mode == Mode.TUTORIAL or mode == Mode.PUZZLE:
		for x in PZ.get_puzzle(puzzle_id)["allowed"]:
			if int(x) == t:
				return true
		return false
	return true


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
	if why.begins_with("只能放"):
		return L.t("err_zone")
	if why.begins_with("這格"):
		return L.t("err_taken")
	if why.begins_with("最多"):
		return L.t("err_max", [Army.MAX_UNITS])
	if why.begins_with("錢不夠"):
		return L.t("err_gold")
	if why.begins_with("這一手"):
		return L.t("err_hand", [tp.hand_cap() if tp else 10])
	return why


## 遠征：跟上一戰的陣型比，新出現的「兵種＋格子」數（移動也算一次）。
func _gauntlet_diff() -> int:
	if gauntlet_prev.is_empty():
		return 0
	var a := {}
	for u in gauntlet_prev:
		a["%d,%d,%d" % [u["type"], u["col"], u["row"]]] = true
	var d := 0
	for u in armies[0].units:
		if not a.has("%d,%d,%d" % [u["type"], u["col"], u["row"]]):
			d += 1
	return d


func _try_place(c: Vector2i) -> void:
	var why := _check_place(selected, c)
	if why == "":
		if mode == Mode.DUEL and tp != null:
			tp.place(selected, c.x, c.y)
		else:
			_cur_army().place(selected, c.x, c.y)
		sfx.play(["place_mid", "place_heavy", "place_light", "place_heavy", "place_light"][selected])
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
	if _cur_army().remove_at(c.x, c.y):
		sfx.play("ui_click")


func _input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		mouse = ev.position
		pad_mode = false
		hover_card = _card_at(mouse)
		if state == St.PLACE and overlay == "" and painting:
			if _cur_army().team != paint_team:
				painting = false
			else:
				var c := _cell_at(mouse)
				if c.x >= 0 and _cur_army().index_at(c.x, c.y) == -1:
					_try_place(c)
		return
	if ev is InputEventMouseButton:
		_mouse_button(ev)
		return
	if ev is InputEventKey and ev.pressed:
		if not ev.echo or ev.keycode in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
			_key(ev.keycode)
		return
	if ev is InputEventJoypadButton and ev.pressed:
		pad_mode = true
		var map := {JOY_BUTTON_DPAD_UP: KEY_UP, JOY_BUTTON_DPAD_DOWN: KEY_DOWN, JOY_BUTTON_DPAD_LEFT: KEY_LEFT,
			JOY_BUTTON_DPAD_RIGHT: KEY_RIGHT, JOY_BUTTON_A: KEY_ENTER, JOY_BUTTON_B: KEY_ESCAPE, JOY_BUTTON_X: KEY_BACKSPACE,
			JOY_BUTTON_START: KEY_SPACE, JOY_BUTTON_Y: KEY_TAB, JOY_BUTTON_LEFT_SHOULDER: KEY_Q, JOY_BUTTON_RIGHT_SHOULDER: KEY_E,
			JOY_BUTTON_BACK: KEY_F1}
		if map.has(ev.button_index):
			_key(map[ev.button_index])
		return
	if ev is InputEventJoypadMotion and absf(ev.axis_value) > 0.6 and (ev.axis == JOY_AXIS_LEFT_X or ev.axis == JOY_AXIS_LEFT_Y):
		pad_mode = true
		if ev.axis == JOY_AXIS_LEFT_X:
			_key(KEY_RIGHT if ev.axis_value > 0 else KEY_LEFT)
		else:
			_key(KEY_DOWN if ev.axis_value > 0 else KEY_UP)


func _mouse_button(mb: InputEventMouseButton) -> void:
	mouse = mb.position
	if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
		_click_pending = mouse
	if overlay != "" or state != St.PLACE:
		if not mb.pressed:   # 放開滑鼠一定要清掉拖曳／塗兵狀態，即使上面蓋著覆蓋層
			drag_new = false
			painting = false
			drag_from = Vector2i(-1, -1)
		return
	var c := _cell_at(mouse)
	if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		var k := _card_at(mouse)
		if k >= 0 and _card_help_rect(k).has_point(mouse):
			return   # 放開時由「?」按鈕處理
		if k >= 0:
			if _allowed(k):
				selected = k
				drag_new = true
				sfx.play("ui_click")
			else:
				_toast(L.t("err_type"), true)
			return
		if c.x < 0:
			return
		if _can_edit_existing() and _cur_army().index_at(c.x, c.y) != -1:
			if (mode == Mode.TUTORIAL or mode == Mode.PUZZLE) and PZ.is_fixed(PZ.get_puzzle(puzzle_id), c.x, c.y):
				_toast(L.t("err_locked"), true)
				return
			drag_from = c
		else:
			painting = true
			paint_team = _cur_army().team
			_try_place(c)
	elif mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
		if drag_new and c.x >= 0:
			_try_place(c)
		elif drag_from.x >= 0:
			if c.x < 0:
				_try_remove(drag_from)
			elif c != drag_from:
				if mode == Mode.GAUNTLET and gauntlet_stage > 1 and _gauntlet_diff() >= gauntlet_changes:
					_toast(L.t("err_changes"), true)
				elif not _cur_army().move(drag_from.x, drag_from.y, c.x, c.y):
					_toast(L.t("err_zone"), true)
				else:
					sfx.play("place_light")
		drag_new = false
		painting = false
		drag_from = Vector2i(-1, -1)
	elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and c.x >= 0:
		_try_remove(c)


func _key(k: int) -> void:
	# 有按鈕焦點的畫面（標題、選單、結果、覆蓋層、戰鬥）：方向鍵移焦點、Enter 按下、Esc 返回
	if state != St.PLACE or overlay != "":
		match k:
			KEY_UP, KEY_LEFT:
				_move_focus(-1)
			KEY_DOWN, KEY_RIGHT, KEY_TAB:
				_move_focus(1)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if _focus >= 0 and _focus < _btns.size() and _btns[_focus]["en"]:
					sfx.play("ui_click")
					_btns[_focus]["cb"].call()
			KEY_ESCAPE:
				if overlay != "":
					overlay = ""
				elif state == St.BATTLE:
					_on_skip()
				elif state != St.TITLE:
					_go_title()
		return
	pad_mode = true
	match k:
		KEY_UP: cursor.y = maxi(0, cursor.y - 1)
		KEY_DOWN: cursor.y = mini(8, cursor.y + 1)
		KEY_LEFT: cursor.x = maxi(0, cursor.x - 1)
		KEY_RIGHT: cursor.x = mini(15, cursor.x + 1)
		KEY_F1:
			_open_codex(selected)
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			var t := k - KEY_1
			if _allowed(t):
				selected = t
		KEY_Q, KEY_E:
			for i in 5:
				selected = (selected + (4 if k == KEY_Q else 1)) % 5
				if _allowed(selected):
					break
		KEY_ENTER, KEY_KP_ENTER:
			if _cur_army().index_at(cursor.x, cursor.y) == -1:
				_try_place(cursor)
		KEY_BACKSPACE, KEY_DELETE:
			_try_remove(cursor)
		KEY_SPACE, KEY_TAB:
			_on_start()
		KEY_ESCAPE:
			_go_title()


# ───────────────────────── 每幀 ─────────────────────────
func _process(delta: float) -> void:
	var _t0 := Time.get_ticks_usec()
	_process_inner(delta)
	perf_proc_us = Time.get_ticks_usec() - _t0

func _process_inner(delta: float) -> void:
	time += delta
	SteamApi.run_callbacks()
	if toast_t > 0:
		toast_t -= delta
	if ach_t > 0:
		ach_t -= delta
	elif not ach_queue.is_empty():
		toast = ach_queue.pop_front()
		toast_t = 2.5
		ach_t = 2.6
	shake = maxf(0.0, shake - delta)
	if not freeze_fx:
		for f in fx:
			f["t"] += delta
		fx = fx.filter(func(f): return f["t"] < f["dur"])
	for g in dying:
		g["t"] += delta
	dying = dying.filter(func(g): return g["t"] < 1.0)
	if overlay == "codex":
		_codex_tick(delta)
	if state == St.TITLE and demo != null and shot_dir == "":
		demo_acc += delta
		while demo_acc >= 0.05:
			demo_acc -= 0.05
			demo.step()
		if demo.finished:
			_new_demo()
	if state == St.BATTLE and shot_dir == "":
		_battle_process(delta)
	elif state == St.RESULT:
		zoom = lerpf(zoom, 1.0, delta * 4)
	queue_redraw()


# ───────────────────────── 繪圖 ─────────────────────────
func _draw() -> void:
	var _t0 := Time.get_ticks_usec()
	_draw_inner()
	perf_draw_us = Time.get_ticks_usec() - _t0

func _draw_inner() -> void:
	_btns.clear()
	if capsule_path != "":
		_draw_capsule()
		return
	draw_rect(Rect2(0, 0, 1280, 800), Color("#1b2a1f"))
	var cam := Transform2D.IDENTITY
	if state == St.BATTLE or state == St.RESULT:
		var off := Vector2.ZERO
		if shake > 0 and bool(Save.s("shake")):
			off = Vector2(sin(time * 90) * 2, cos(time * 77) * 2)
		var w := clampf((zoom - 1.0) / 0.5, 0.0, 1.0)
		var c := (ORIGIN + FIELD / 2).lerp(zoom_center, w)
		var half := Vector2(640, 388) / zoom
		var lo := ORIGIN + half - Vector2(60, 100)
		var hi := ORIGIN + FIELD - half + Vector2(60, 100)
		c = Vector2(clampf(c.x, minf(lo.x, hi.x), maxf(lo.x, hi.x)), clampf(c.y, minf(lo.y, hi.y), maxf(lo.y, hi.y)))
		cam = Transform2D(0, Vector2(zoom, zoom), 0, Vector2(640, 388) - c * zoom + off)
	draw_set_transform_matrix(cam)
	Art.base = cam
	var _t := Time.get_ticks_usec()
	_draw_field()
	perf_parts["field"] = Time.get_ticks_usec() - _t
	_t = Time.get_ticks_usec()
	if state == St.TITLE:
		_draw_units_of(demo, true)
	elif state == St.PLACE:
		_draw_place_units()
		_draw_tactical()
	else:
		_draw_units_of(view, false)
	perf_parts["units"] = Time.get_ticks_usec() - _t
	_t = Time.get_ticks_usec()
	for f in fx:
		if not f.get("screen", false):
			_draw_fx(f)
	perf_parts["fx"] = Time.get_ticks_usec() - _t
	draw_set_transform_matrix(Transform2D.IDENTITY)
	Art.base = Transform2D.IDENTITY
	if state == St.BATTLE and slow_left > 0:
		var va := clampf((8.0 - slow_left) / 0.3, 0.0, 1.0) * 0.45
		for i in 14:
			var c2 := Color(0, 0, 0, va * (1.0 - i / 14.0) * 0.35)
			draw_rect(Rect2(0, 86 + i * 9, 1280, 9), c2)
			draw_rect(Rect2(0, 800 - (i + 1) * 9, 1280, 9), c2)
			draw_rect(Rect2(i * 9, 86, 9, 714), c2)
			draw_rect(Rect2(1280 - (i + 1) * 9, 86, 9, 714), c2)
	if state != St.RESULT:
		for f in fx:
			if f.get("screen", false):
				_draw_fx(f)
	match state:
		St.TITLE: _draw_title()
		St.PLACE: _draw_place_hud()
		St.BATTLE: _draw_battle_hud()
		St.RESULT:
			_draw_battle_hud()
			_draw_result()
	_draw_overlay()
	if toast_t > 0:
		var a := minf(1.0, toast_t * 2)
		var tw := font.get_string_size(toast, HORIZONTAL_ALIGNMENT_LEFT, -1, ts(20)).x + 40
		var ty := 40.0 if overlay != "" else 616.0   # 覆蓋層開著時放上面，不蓋住內容（手感輪 R3）
		draw_rect(Rect2(640 - tw / 2, ty, tw, 44), Color(0, 0, 0, 0.72 * a))
		_text(Vector2(640, ty + 6), toast, ts(20), Color(1, 0.88, 0.5, a), true)
	if _focus >= _btns.size():
		_focus = 0
	_handle_click()


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
			list.append([u["row"], u["col"], u["type"], a.team])
	list.sort()
	var pz := PZ.get_puzzle(puzzle_id) if (mode == Mode.TUTORIAL or mode == Mode.PUZZLE) else {}
	for it in list:
		var p := ORIGIN + Vector2(it[1] + 0.5, it[0] + 0.82) * CS
		_ring(p, it[3], it[2])
		_unit(p, it[2], it[3], 1.0 if it[3] == 0 else -1.0, 0.0, 0.0, 0.0, 1.0, time + it[1], 1.0)
		if not pz.is_empty() and it[3] == 0 and PZ.is_fixed(pz, it[1], it[0]):
			draw_rect(Rect2(p + Vector2(12, -62), Vector2(10, 8)), Color(0.9, 0.8, 0.3))
			draw_arc(p + Vector2(17, -62), 4, PI, TAU, 8, Color(0.9, 0.8, 0.3), 2)
	if hide_side >= 0:
		var x0 := 10 if hide_side == 1 else 0
		draw_rect(Rect2(ORIGIN + Vector2(x0 * CS, 0), Vector2(6 * CS, FIELD.y)), Color(0.12, 0.08, 0.05, 0.85))
		var msg := L.t("ai_hidden") if mode == Mode.VS_AI else L.t("enemy_hidden")
		_text(ORIGIN + Vector2((x0 + 3) * CS, FIELD.y / 2 - 30), msg, ts(22), Color(1, 1, 1, 0.8), true, true)
	# 拖曳預覽
	var dragging_type := -1
	if drag_new:
		dragging_type = selected
	elif drag_from.x >= 0:
		var idx: int = _cur_army().index_at(drag_from.x, drag_from.y)
		if idx >= 0:
			dragging_type = _cur_army().units[idx]["type"]
	if dragging_type >= 0:
		Art.unit(self, mouse + Vector2(0, 24), dragging_type, _cur_army().team, 1.0, 0.0, 0.0, 0.0, 0.75, time)
	var c := cursor if pad_mode else _cell_at(mouse)
	if c.x >= 0:
		var okp := _check_place(selected, c) == ""
		draw_rect(Rect2(ORIGIN + Vector2(c) * CS, Vector2(CS, CS)), Color(1, 1, 1, 0.28) if okp else Color(1, 0.25, 0.25, 0.25))
		if pad_mode:
			draw_rect(Rect2(ORIGIN + Vector2(c) * CS, Vector2(CS, CS)), ACCENT, false, 3)


## 戰術預覽（優化方案 E2）：選中兵種在游標格的射程／衝鋒線／刺客路線；已擺弓手的射程；看得到敵陣時標出剋制關係。
func _draw_tactical() -> void:
	var c := cursor if pad_mode else _cell_at(mouse)
	var army = _cur_army()
	var dir := 1.0 if army.team == 0 else -1.0
	if c.x >= 0 and army.in_zone(c.x, c.y):
		var p := ORIGIN + (Vector2(c) + Vector2(0.5, 0.5)) * CS
		match selected:
			D.ARCHER:
				draw_arc(p, 6.0 * CS, 0, TAU, 64, Color(1, 0.9, 0.5, 0.45), 2.0, true)
			D.CAVALRY:
				var q := p + Vector2(3.0 * CS * dir, 0)
				draw_dashed_line(p, q, Color(1, 0.8, 0.3, 0.85), 3.0, 8.0)
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
						draw_dashed_line(p, best, Color(0.78, 0.5, 1.0, 0.85), 2.5, 7.0)
	for u in army.units:
		if u["type"] == D.ARCHER:
			var ap := ORIGIN + Vector2(u["col"] + 0.5, u["row"] + 0.5) * CS
			var a0 := -0.6 if army.team == 0 else PI - 0.6
			draw_arc(ap, 6.0 * CS, a0, a0 + 1.2, 24, Color(1, 0.9, 0.5, 0.14), 2.0, true)
	if _enemy_visible():
		for u in armies[1 - army.team].units:
			var sc := AIT.counter_score(selected, u["type"])
			if sc == 0:
				continue
			var ep := ORIGIN + Vector2(u["col"] + 0.5, u["row"] - 0.12) * CS
			var bc := Color("#4ade80") if sc > 0 else Color("#f87171")
			draw_circle(ep, 11, Color("#111827"), true, -1.0, true)
			draw_arc(ep, 11, 0, TAU, 20, bc, 2.0, true)
			if sc > 0:
				draw_polyline(PackedVector2Array([ep + Vector2(-5, 0), ep + Vector2(-1, 4), ep + Vector2(6, -5)]), bc, 3.0, true)
			else:
				draw_line(ep + Vector2(-5, -5), ep + Vector2(5, 5), bc, 3.0, true)
				draw_line(ep + Vector2(-5, 5), ep + Vector2(5, -5), bc, 3.0, true)


# ── 標題 ──
func _draw_title() -> void:
	draw_rect(Rect2(0, 0, 1280, 800), Color(0.05, 0.06, 0.1, 0.42))
	if overlay != "":
		return
	var bob := sin(time * 1.5) * 4
	draw_rect(Rect2(260, 50, 760, 700), Color(0.05, 0.06, 0.1, 0.6))
	_text(Vector2(640, 64 + bob), L.t("title"), ts(84), Color("#ffe8a3"), true, true)
	_text(Vector2(640, 182), "No Take-Backs" if L.lang == "zh_TW" else "落子無悔", ts(26), Color(1, 1, 1, 0.85), true)
	_text(Vector2(640, 222), L.t("subtitle"), ts(18), Color(1, 1, 1, 0.9), true)
	var items := [["menu_vs_ai", func(): _open("diff")],
		["menu_duel", func(): _open("rule")],
		["menu_tutorial", func(): _open("tutorial")],
		["menu_puzzle", func(): _open("puzzles")],
		["menu_gauntlet", func(): _start_mode(Mode.GAUNTLET)],
		["menu_codex", func(): _open_codex(0)],
		["menu_settings", func(): _open("settings")],
		["menu_credits", func(): _open("credits")],
		["menu_quit", func(): get_tree().quit()]]
	for i in items.size():
		_btn(Rect2(500, 282 + i * 51, 280, 43), L.t(items[i][0]), items[i][1], true, i == 0)
	_text(Vector2(640, 752), "%s　｜　v%s" % [L.t("gauntlet_best", [int(Save.data.get("gauntlet_best", 0))]), D.RULES_VERSION], ts(13), Color(1, 1, 1, 0.5), true)


func _pick_difficulty(d: int) -> void:
	difficulty = d
	_start_mode(Mode.VS_AI)


func _pick_rule(r: String) -> void:
	duel_rule = r
	Save.set_setting("duel_rule", r)
	_start_mode(Mode.DUEL)


func _pick_puzzle(id: String, tut: bool) -> void:
	puzzle_id = id
	_start_mode(Mode.TUTORIAL if tut else Mode.PUZZLE)


# ── 覆蓋層 ──
func _draw_overlay() -> void:
	if overlay != "":
		_btns.clear()   # 覆蓋層底下畫面的按鈕不能被點到（例如擺放畫面的開戰、結果頁的按鈕）
	match overlay:
		"diff":
			_panel(Rect2(440, 250, 400, 310))
			_text(Vector2(640, 266), L.t("choose_diff"), ts(24), Color.WHITE, true, true)
			for i in 3:
				_btn(Rect2(500, 330 + i * 60, 280, 48), L.t(["diff_easy", "diff_normal", "diff_hard"][i]), _pick_difficulty.bind(i), true, i == 1)
			_btn(Rect2(560, 514, 160, 36), L.t("back"), func(): overlay = "")
		"rule":
			_panel(Rect2(400, 240, 480, 330))
			_text(Vector2(640, 256), L.t("choose_rule"), ts(24), Color.WHITE, true, true)
			var rules := ["snake5", "cap10", "blind"]
			for i in 3:
				_btn(Rect2(440, 320 + i * 62, 400, 50), L.t("rule_" + rules[i]), _pick_rule.bind(rules[i]), true, rules[i] == duel_rule)
			_btn(Rect2(560, 518, 160, 36), L.t("back"), func(): overlay = "")
		"tutorial", "puzzles":
			var tut := overlay == "tutorial"
			var list: Array = PZ.tutorials() if tut else PZ.puzzles()
			var stars: Dictionary = Save.data.get("puzzle_stars", {})
			var tdone := int(Save.data.get("tutorial", 0))
			var unlocked := tut or tdone >= 1
			_panel(Rect2(240, 110, 800, 580))
			_text(Vector2(640, 126), L.t("menu_tutorial") if tut else L.t("puzzle_title"), ts(26), Color.WHITE, true, true)
			if not unlocked:
				_text(Vector2(640, 172), L.t("puzzle_locked"), ts(16), ACCENT, true)
			for i in list.size():
				var pz: Dictionary = list[i]
				var r := Rect2(280 + (i % 2) * 370, 210 + (i / 2) * 82, 350, 68)
				var name: String = pz["zh"] if L.lang == "zh_TW" else pz["en"]
				var st := int(stars.get(pz["id"], 0))
				var en := unlocked and (not tut or i <= tdone)
				_btn(r, "%s%d. %s　%s" % ["✓ " if st > 0 else "", i + 1, name, "★".repeat(st) + "☆".repeat(3 - st)], _pick_puzzle.bind(pz["id"], tut), en, false,
					Color(0.15, 0.32, 0.22) if st > 0 else Color(0, 0, 0, 0))
			_btn(Rect2(560, 640, 160, 36), L.t("back"), func(): overlay = "")
		"settings":
			_draw_settings()
		"credits":
			_panel(Rect2(200, 70, 880, 660))
			_text(Vector2(640, 86), L.t("credits_title"), ts(26), Color.WHITE, true, true)
			_text(Vector2(240, 140), FileAccess.get_file_as_string("res://data/credits.txt"), ts(13), Color(1, 1, 1, 0.88))
			_btn(Rect2(560, 680, 160, 36), L.t("back"), func(): overlay = "")
		"slots":
			_draw_slots()
		"codex":
			_draw_codex()


func _draw_settings() -> void:
	_panel(Rect2(300, 60, 680, 680))
	_text(Vector2(640, 74), L.t("settings_title"), ts(26), Color.WHITE, true, true)
	var rows := [
		["set_lang", L.t("lang_name"), func(): _cycle_setting("lang", ["zh_TW", "en"]); L.lang = Save.s("lang")],
		["set_text", "%d%%" % int(Save.s("text_scale")), func(): _cycle_setting("text_scale", [100, 125, 150])],
		["set_shake", _onoff("shake"), func(): _cycle_setting("shake", [true, false])],
		["set_slowmo", _onoff("slowmo"), func(): _cycle_setting("slowmo", [true, false])],
		["set_flash", _onoff("flash"), func(): _cycle_setting("flash", [true, false])],
		["set_cb", _onoff("colorblind"), func(): _cycle_setting("colorblind", [false, true]); _rebuild_sprites()],
		["set_speed", "%s×" % _fmt_num(float(Save.s("speed"))), func(): _cycle_setting("speed", [0.5, 1.0, 2.0])],
		["set_music", "%d%%" % int(Save.s("music")), func(): _cycle_setting("music", [0, 30, 50, 70, 100]); sfx.set_volumes(int(Save.s("sfx")), int(Save.s("music")))],
		["set_sfx", "%d%%" % int(Save.s("sfx")), func(): _cycle_setting("sfx", [0, 30, 50, 80, 100]); sfx.set_volumes(int(Save.s("sfx")), int(Save.s("music")))],
		["set_rule", L.t("rule_" + str(Save.s("duel_rule"))), func(): _cycle_setting("duel_rule", ["snake5", "cap10", "blind"]); duel_rule = Save.s("duel_rule")],
		["set_fullscreen", _onoff("fullscreen"), func(): _cycle_setting("fullscreen", [false, true]); _apply_fullscreen()],
		["set_playtest", _onoff("playtest"), func(): _cycle_setting("playtest", [false, true])],
	]
	for i in rows.size():
		var y := 112 + i * 48
		_text(Vector2(340, y + 6), L.t(rows[i][0]), ts(18), Color.WHITE)
		var on_val: String = rows[i][1]
		var tint := Color(0.16, 0.5, 0.3) if on_val == L.t("on") else Color(0, 0, 0, 0)
		_btn(Rect2(660, y, 280, 40), on_val, rows[i][2], true, false, tint)
		if on_val.ends_with("%") and rows[i][0] in ["set_music", "set_sfx"]:
			draw_rect(Rect2(668, y + 33, 264.0 * int(on_val.trim_suffix("%")) / 100.0, 4), ACCENT)
	if bool(Save.s("playtest")):
		_btn(Rect2(340, 694, 200, 36), L.t("pt_folder"), func(): OS.shell_open(ProjectSettings.globalize_path("user://")))
	_btn(Rect2(560, 694, 160, 36), L.t("back"), func(): overlay = "")


func _draw_slots() -> void:
	_panel(Rect2(330, 150, 620, 500))
	_text(Vector2(640, 166), L.t("code_title"), ts(24), Color.WHITE, true, true)
	var slots: Array = Save.data.get("slots", ["", "", "", "", ""])
	for i in 5:
		var y := 220 + i * 62
		var code: String = slots[i]
		var desc := L.t("empty")
		if code != "":
			var tmp := Army.new(0, 100)
			if tmp.load_code(code) == "":
				var cnt := [0, 0, 0, 0, 0]
				for u in tmp.units:
					cnt[u["type"]] += 1
				desc = ("劍%d 盾%d 弓%d 騎%d 刺%d" if L.lang == "zh_TW" else "Sw%d Sh%d Ar%d Ca%d As%d") % cnt
		_text(Vector2(360, y + 8), "%s　%s" % [L.t("slot", [i + 1]), desc], ts(16), Color.WHITE)
		_btn(Rect2(700, y, 100, 42), L.t("save"), _slot_save.bind(i))
		_btn(Rect2(810, y, 100, 42), L.t("load"), _slot_load.bind(i), code != "")
	_btn(Rect2(370, 540, 260, 42), L.t("copy_code"), func(): DisplayServer.clipboard_set(armies[0].to_code()); _toast(L.t("code_copied")))
	_btn(Rect2(650, 540, 260, 42), L.t("paste_code"), func(): _paste_code())
	_btn(Rect2(560, 600, 160, 36), L.t("back"), func(): overlay = "")


func _slot_save(i: int) -> void:
	var slots: Array = Save.data.get("slots", ["", "", "", "", ""])
	slots[i] = armies[0].to_code()
	Save.data["slots"] = slots
	if Save.save_data():
		_toast(L.t("slot", [i + 1]) + " ✓")
	else:
		_toast(L.t("save_failed"), true)


func _slot_load(i: int) -> void:
	var slots: Array = Save.data.get("slots", ["", "", "", "", ""])
	var why: String = armies[0].load_code(slots[i])
	_toast(L.t("code_loaded") if why == "" else L.t("code_bad"), why != "")
	overlay = ""


func _paste_code() -> void:
	var why: String = armies[0].load_code(DisplayServer.clipboard_get())
	_toast(L.t("code_loaded") if why == "" else L.t("code_bad"), why != "")
	if why == "":
		overlay = ""


# ── 擺放 HUD ──
func _draw_place_hud() -> void:
	draw_rect(Rect2(0, 0, 1280, 86), UI_BG)
	_text(Vector2(20, 8), L.t("title"), ts(26), Color("#ffe8a3"), false, true)
	_text(Vector2(20, 52), _mode_label(), ts(14), Color(1, 1, 1, 0.6))
	if mode == Mode.VS_AI or mode == Mode.DUEL:
		_text(Vector2(1110, 8), L.t("round", [round_no]), ts(16), Color.WHITE)
		_text(Vector2(1110, 34), L.t("score", [wins[0], wins[1]]), ts(16), Color.WHITE)
	var a = _cur_army()
	var tcol := Art.team_color(a.team, cbm())
	var head := L.t("place_title")
	if mode == Mode.DUEL:
		if tp != null:
			head = L.t("both_done") if tp.done() else L.t("turn_of", [L.t("blue") if tp.current == 0 else L.t("red"), tp.turn_left()])
			if tp.is_snake() and not tp.done():
				head += "　" + L.t("hand_n", [mini(5, tp.hands_done[tp.current] + 1)])
		else:
			head = L.t("both_done") if blind_phase == 2 else L.t("blind_turn", [L.t("blue") if blind_phase == 0 else L.t("red"), L.t("red") if blind_phase == 0 else L.t("blue")])
	elif mode == Mode.TUTORIAL or mode == Mode.PUZZLE:
		var pz := PZ.get_puzzle(puzzle_id)
		head = pz["zh"] if L.lang == "zh_TW" else pz["en"]
	elif mode == Mode.GAUNTLET:
		head = L.t("gauntlet_title", [gauntlet_stage])
	_text(Vector2(640, 4), head, ts(22), tcol if mode == Mode.DUEL else Color.WHITE, true, true)
	var bx := 400.0
	var bw := 480.0
	draw_rect(Rect2(bx, 50, bw, 8), Color(0.2, 0.2, 0.25))
	draw_rect(Rect2(bx, 50, bw * clampf(float(a.spent()) / a.budget, 0, 1), 8), tcol)
	_text(Vector2(640, 30), L.t("budget", [L.t("blue") if a.team == 0 else L.t("red"), a.spent(), a.budget, a.count(), Army.MAX_UNITS]), ts(13), Color.WHITE, true)
	var info := "%s：%s" % [L.t("unit_%d" % selected), L.t("blurb_%d" % selected)]
	if mode == Mode.TUTORIAL or mode == Mode.PUZZLE:
		var pz2 := PZ.get_puzzle(puzzle_id)
		info = pz2["hint_zh"] if L.lang == "zh_TW" else pz2["hint_en"]
	elif mode == Mode.GAUNTLET:
		info = L.t("gauntlet_hint") if gauntlet_stage == 1 else L.t("gauntlet_changes", [maxi(0, gauntlet_changes - _gauntlet_diff())])
	elif mode == Mode.DUEL and tp != null:
		info += "　｜　" + L.t("place_hint_turns")
	elif pad_mode:
		info = L.t("pad_hint")
	else:
		info += "　｜　" + L.t("place_hint_free")
	_text(Vector2(640, 62), info, ts(13), Color(1, 1, 1, 0.82), true)
	for i in D.COUNT:
		var r := _card_rect(i)
		var afford: bool = D.cost(i) <= a.left() and a.count() < Army.MAX_UNITS and _allowed(i)
		var bg := Color(0.17, 0.18, 0.24)
		if i == selected:
			bg = Color(0.26, 0.31, 0.45)
		elif i == hover_card:
			bg = Color(0.21, 0.23, 0.31)
		draw_rect(r, bg if afford else Color(bg, 0.45))
		draw_rect(r, tcol if i == selected else Color(1, 1, 1, 0.15), false, 2)
		Art.unit(self, r.position + Vector2(32, 86), i, a.team, 1.0, 0.0, 0.0, 0.0, 1.0 if afford else 0.45, time, 0.95, cbm())
		_text(r.position + Vector2(64, 6), L.t("unit_%d" % i), ts(16), Color.WHITE if afford else Color(1, 1, 1, 0.55), false, true)
		_text(r.position + Vector2(64, 34), L.t("gold", [D.cost(i)]), ts(15), ACCENT if afford else Color("#f87171"), false, not afford)
		_text(r.position + Vector2(64, 60), "×%d　[%d]" % [a.count_of(i), i + 1], ts(13), Color(1, 1, 1, 0.65))
		_btn(_card_help_rect(i), "?", _open_codex.bind(i))
	var start_label := L.t("start")
	var start_en := _ready_to_fight()
	if mode == Mode.DUEL and tp != null and not tp.done():
		start_label = L.t("end_hand")
		start_en = tp.can_end_turn()
	elif mode == Mode.DUEL and tp == null and blind_phase < 2:
		start_label = L.t("blind_ready", [L.t("blue") if blind_phase == 0 else L.t("red")])
		start_en = _cur_army().count() > 0
	_btn(Rect2(884, 690, 384, 50), start_label, func(): _on_start(), start_en, true)
	if mode == Mode.VS_AI or (mode == Mode.GAUNTLET and gauntlet_stage == 1):
		_btn(Rect2(884, 746, 120, 44), L.t("formations"), func(): _open("slots"))
	if _can_edit_existing():
		_btn(Rect2(1012, 746, 120, 44), L.t("clear"), func(): _clear_mine())
	_btn(Rect2(1140, 746, 128, 44), L.t("menu"), func(): _go_title())


func _clear_mine() -> void:
	var a = _cur_army()
	if mode == Mode.TUTORIAL or mode == Mode.PUZZLE:
		var pz := PZ.get_puzzle(puzzle_id)
		a.units = a.units.filter(func(u): return PZ.is_fixed(pz, u["col"], u["row"]))
	elif mode == Mode.GAUNTLET and gauntlet_stage > 1:
		a.units = gauntlet_prev.duplicate(true)
	else:
		a.clear()


func _mode_label() -> String:
	match mode:
		Mode.VS_AI: return "%s・%s" % [L.t("menu_vs_ai"), L.t(["diff_easy", "diff_normal", "diff_hard"][difficulty])]
		Mode.DUEL: return "%s・%s" % [L.t("menu_duel"), L.t("rule_" + duel_rule)]
		Mode.TUTORIAL: return L.t("menu_tutorial")
		Mode.PUZZLE: return L.t("menu_puzzle")
		Mode.GAUNTLET: return L.t("menu_gauntlet")
	return ""


func _draw_result() -> void:
	draw_rect(Rect2(0, 86, 1280, 714), Color(0, 0, 0, 0.5))
	var r := Rect2(240, 100, 800, 610)
	draw_rect(r, PANEL)
	draw_rect(r, Color(1, 1, 1, 0.2), false, 2)
	var w: int = sim.winner
	var title := L.t("draw")
	var col := Color.WHITE
	if w >= 0:
		title = L.t("win_team", [L.t("blue") if w == 0 else L.t("red")])
		col = Art.team_color(w, cbm())
	_text(Vector2(640, 108), title, ts(40), col, true, true)
	var mvp0 = report.get("mvp")
	_btn(Rect2(904, 112, 124, 34), L.t("menu_codex_short"), _open_codex.bind(mvp0.type if mvp0 != null else 0))
	var reason_key := {"全滅": "reason_wipe", "同時全滅": "reason_bothwipe", "時間到・戰力相當": "reason_time_even",
		"時間到・剩餘戰力較高": "reason_time_power", "有一方沒有兵": "reason_empty"}
	var tot := float(sim.budget * 1000)
	_text(Vector2(640, 166), "%s・%.1fs　｜　%s" % [L.t(reason_key.get(sim.reason, "draw")), sim.tick / 20.0,
		L.t("power_left", [roundi(sim.power(0) * 100 / tot), roundi(sim.power(1) * 100 / tot)])], ts(16), Color(1, 1, 1, 0.85), true)
	var y := 196.0
	if w >= 0 and sim.alive_count(w) == 1:
		_text(Vector2(640, y), L.t("lone_hero"), ts(20), ACCENT, true, true)
		y += 30
	var sus: Dictionary = report.get("sus", {})
	if w >= 0 and int(sus.get("max_swing_pct", 0)) >= 15:
		_text(Vector2(640, y), L.t("report_comeback", [sus["max_swing_pct"]]), ts(18), Color("#7dff8a"), true, true)
		y += 28
	if w >= 0:
		_text(Vector2(640, y), _verdict(w), ts(17), Color(1, 1, 1, 0.95), true, true)
		y += 28
	var sus_line := L.t("report_suspense", [sus.get("lead_changes", 0), report.get("lock_sec", 0), sus.get("max_swing_pct", 0)])
	if w >= 0 and int(sus.get("lock_ratio_permille", 0)) == 0:
		sus_line = L.t("report_led_all")
	_text(Vector2(640, y), sus_line, ts(14), Color(1, 1, 1, 0.75), true)
	y += 28
	_text(Vector2(280, y), L.t("report_title"), ts(16), Color.WHITE, false, true)
	_text(Vector2(420, y + 2), "■ " + L.t("report_dealt") + "　□ " + L.t("report_taken"), ts(12), Color(1, 1, 1, 0.6))
	y += 30
	var dealt: Array = report["dealt"]
	var taken: Array = report["taken"]
	var mx := 1
	for tm in 2:
		for t in 5:
			mx = maxi(mx, maxi(dealt[tm][t], taken[tm][t]))
	for t in 5:
		_text(Vector2(280, y + t * 30 - 2), L.t("unit_%d" % t), ts(13), Color.WHITE)
		for tm in 2:
			var x0 := 380.0 + tm * 320.0
			var c := Art.team_color(tm, cbm())
			draw_rect(Rect2(x0, y + t * 30 + 2, 290.0 * dealt[tm][t] / mx, 9), c)
			draw_rect(Rect2(x0, y + t * 30 + 13, maxf(1.0, 290.0 * taken[tm][t] / mx), 9), c, false, 1.5)
	y += 156
	var ek := ["breaker", "charge", "backstab", "braced", "anticav", "counter"]
	for tm in 2:
		var n: Array = []
		for k in ek:
			n.append(int(ev_count.get("%s%d" % [k, tm], 0)))
		_text(Vector2(280, y + tm * 22), ("● " if tm == 0 else "◆ ") + L.t("report_events", n), ts(12), Art.team_color(tm, cbm()))
	y += 50
	var mvp = report.get("mvp")
	if mvp != null:
		var mp := Vector2(980, 300)
		draw_circle(mp + Vector2(0, -30), 46, Color(1, 0.82, 0.3, 0.18 + 0.06 * sin(time * 3)), true, -1.0, true)
		Art.ring(self, mp + Vector2(0, 20), mvp.team, mvp.type, cbm(), 1.8)
		Art.unit(self, mp + Vector2(0, 20), mvp.type, mvp.team, -1.0, 0.0, 0.0, 0.0, 1.0, time, 1.8, cbm())
		_text(mp + Vector2(0, 30), "MVP", ts(16), ACCENT, true, true)
		_text(Vector2(640, y), L.t("mvp", [L.t("blue") if mvp.team == 0 else L.t("red"), L.t("unit_%d" % mvp.type), mvp.dmg_dealt, mvp.kills]), ts(15), Color(1, 1, 1, 0.85), true)
		y += 26
	if report.has("stars"):
		var pz := PZ.get_puzzle(puzzle_id)
		var stn := int(report["stars"])
		_text(Vector2(640, y), "★".repeat(stn) + "☆".repeat(3 - stn) + "　" + L.t("star_rules", [pz["star2"], pz["star3"]]), ts(15), ACCENT, true)
		y += 26
	if series_over and (mode == Mode.VS_AI or mode == Mode.DUEL):
		var sw := L.t("series_draw") if wins[0] == wins[1] else L.t("series_win", [L.t("blue") if wins[0] > wins[1] else L.t("red"), wins[0], wins[1]])
		_text(Vector2(640, y), L.t("series_end", [sw]), ts(17), ACCENT, true, true)
	if mode == Mode.GAUNTLET:
		var msg := ""
		if w == 0 and gauntlet_stage >= 7:
			msg = L.t("gauntlet_clear")
		elif w != 0:
			msg = L.t("gauntlet_over", [gauntlet_stage - 1])
		if msg != "":
			_text(Vector2(640, y), msg, ts(18), ACCENT, true, true)
	if bool(Save.s("playtest")) and not pt_rated:
		_text(Vector2(420, 590), L.t("pt_rate"), ts(15), ACCENT)
		for i in 5:
			_btn(Rect2(600 + i * 52, 584, 44, 32), str(i + 1), _pt_rate.bind(i + 1))
	_text(Vector2(640, 622), L.t("fingerprint", [sim.fingerprint.substr(0, 12)]), ts(11), Color(1, 1, 1, 0.35), true)
	var bs: Array = []
	match mode:
		Mode.VS_AI, Mode.DUEL:
			bs.append([L.t("new_match") if series_over else L.t("next_round"), func(): _next_round()])
		Mode.TUTORIAL, Mode.PUZZLE:
			bs.append([L.t("retry"), func(): _start_mode(mode)])
			if w == 0:
				bs.append([L.t("next_puzzle"), func(): _next_puzzle()])
		Mode.GAUNTLET:
			if w == 0 and gauntlet_stage < 7:
				bs.append([L.t("continue"), func(): _gauntlet_next()])
			else:
				bs.append([L.t("menu_gauntlet"), func(): _start_mode(Mode.GAUNTLET)])
	bs.append([L.t("replay"), func(): _replay()])
	bs.append([L.t("menu"), func(): _go_title()])
	var bw2 := 200.0
	var x := 640.0 - (bs.size() * (bw2 + 12) - 12) / 2.0
	for i in bs.size():
		_btn(Rect2(x + i * (bw2 + 12), 648, bw2, 46), bs[i][0], bs[i][1], true, i == 0)


## 動態判詞：用輸出最高的兵種、結束方式、懸念類型組一句話。
func _verdict(w: int) -> String:
	var dealt: Array = report["dealt"][w]
	var top := 0
	for t in 5:
		if dealt[t] > dealt[top]:
			top = t
	var sus: Dictionary = report["sus"]
	var side := L.t("blue") if w == 0 else L.t("red")
	var unit := L.t("unit_%d" % top)
	var secs := int(sim.tick / 20)
	if int(sus.get("max_swing_pct", 0)) >= 15:
		return L.t("verdict_comeback", [side, unit, sus["max_swing_pct"]])
	if sim.power(w) * 100 / (sim.budget * 1000) <= 10:
		return L.t("verdict_close", [side, unit, secs])
	if int(sus.get("lock_ratio_permille", 0)) <= 200:
		return L.t("verdict_rout", [side, unit, secs])
	return L.t("verdict_normal", [side, unit, secs])


func _next_round() -> void:
	if series_over:
		wins = [0, 0]
		round_no = 1
		series_over = false
		last_player_formation = []
		_reset_place(false)
		return
	round_no += 1
	_reset_place(mode == Mode.VS_AI)


func _replay() -> void:
	var w: int = sim.winner
	if w >= 0:
		wins[w] -= 1
	series_over = false
	_begin_battle(last_armies[0].copy(), last_armies[1].copy())


func _next_puzzle() -> void:
	var list: Array = PZ.tutorials() if mode == Mode.TUTORIAL else PZ.puzzles()
	for i in list.size():
		if list[i]["id"] == puzzle_id and i + 1 < list.size():
			puzzle_id = list[i + 1]["id"]
			_start_mode(mode)
			return
	if mode == Mode.TUTORIAL and not PZ.puzzles().is_empty():
		puzzle_id = PZ.puzzles()[0]["id"]
		_start_mode(Mode.PUZZLE)
		return
	_go_title()


func _gauntlet_next() -> void:
	gauntlet_prev = last_armies[0].units.duplicate(true)
	gauntlet_stage += 1
	gauntlet_changes = 3
	_reset_place(false)
