extends "res://scripts/ui/replay_view.gd"
## 狀態機、模式、輸入、擺放、標題、選單、設定、結果、成就。

func _ready() -> void:
	on_battle_finished = _finish_battle
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot=") or a.begins_with("--steam-test=") or a.begins_with("--perf=") or a == "--boot-check" or a.begins_with("--mem-check="):
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
	for a2 in OS.get_cmdline_user_args():   # 截圖驗證用：--shot-lang=en、--shot-text=150（只改這次記憶體中的設定）
		if a2.begins_with("--shot-lang="):
			Save.settings["lang"] = a2.substr(12)
		elif a2.begins_with("--shot-text="):
			Save.settings["text_scale"] = int(a2.substr(12))
		elif a2 == "--layout-check":
			layout_probe = true
	L.lang = Save.s("lang")
	duel_rule = Save.s("duel_rule")
	speed = float(Save.s("speed"))
	var _ua := OS.get_cmdline_user_args()
	var _special := "--video" in _ua
	for x in _ua:
		if x.begins_with("--perf=") or x.begins_with("--mem-check="):
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
	if "--boot-check" in OS.get_cmdline_user_args():
		_boot_check.call_deferred()
	if capsule_path != "":
		get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		return   # 膠囊圖由 main 接手
	_apply_fullscreen()
	rng.seed = Time.get_ticks_usec() if (shot_dir == "" and not video_mode) else 12345
	if video_mode:
		Save.prefix = "shot_"
		Save.load_all()
	_go_title()   # 截圖、影片、效能量測由 main 接手（S8）


# ───────────────────────── 狀態切換 ─────────────────────────
func _go_title() -> void:
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


func _new_demo() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = rng.randi()
	demo = Sim.new(AI.build(0, 100, r)["army"], AI.build(1, 100, r)["army"])
	demo.fast = true
	demo_acc = 0.0


func _start_mode(m: int) -> void:
	watch_mode = false
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
				tp.ntypes = _ntypes()
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
			var e := AIT.build_full(1, r, lvl, gauntlet_prev, _ntypes())
			e.budget = 100 + 5 * (gauntlet_stage - 1)
			var guard := 0
			while e.can_afford_any() and guard < 20:
				guard += 1
				var t := AIT.choose_type(e, gauntlet_prev, e.left(), r, lvl, _ntypes())
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
				armies[1] = AIT.build_full(1, r, 0, [], _ntypes())
				ai_name = L.t("diff_easy")
			1:
				var res = AI.build(1, 100, r, -1, _ntypes())
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
			var mine := D.zeros()
			for u in known:
				mine[u["type"]] += D.cost(u["type"])
			var best = null
			var bd := 1 << 30
			for e in lib:
				var d := 0
				var pc: Array = e["proto_comp"]
				for k in mine.size():
					d += absi((int(pc[k]) if k < pc.size() else 0) - mine[k])
				if d < bd:
					bd = d
					best = e
			if best != null and bd <= 40:
				var a := Army.new(1, 100)
				if a.load_code(best["code"]) == "" and _types_ok(a):
					return a
	return AIT.build_full(1, r, 2, known, _ntypes())


## 反制庫的陣型只能用這場開放的兵種（第四輪：不會拿你還沒解鎖的兵打你）。
func _types_ok(a: Army) -> bool:
	for u in a.units:
		if int(u["type"]) >= _ntypes():
			return false
	return true


func _counter_lib() -> Array:
	if not FileAccess.file_exists("res://data/counter_lib.json"):
		return []
	return counter_lib_entries(JSON.parse_string(FileAccess.get_file_as_string("res://data/counter_lib.json")))


## 反制庫版本檢查（第三輪 A3）：規則版本或數值摘要對不上就不用（退回啟發式），避免用到過期的反制。
static func counter_lib_entries(p) -> Array:
	if not p is Dictionary:
		return []
	if str(p.get("rules", "")) != D.RULES_VERSION or str(p.get("digest", "")) != D.data_digest():
		push_warning("counter_lib.json 的規則版本或數值摘要和遊戲不同，困難 AI 改用啟發式")
		return []
	var e = p.get("entries", [])
	return e if e is Array else []




func _finish_battle() -> void:
	sfx.set_muffled(false)
	fx = fx.filter(func(f): return f["kind"] != "text")   # 結果頁不留戰場跳字（Antigravity S3）
	clutch_t = 0.0   # 最後時刻橫幅不跟到結果頁（第三輪 T4 抓到）
	state = St.RESULT
	_focus = 0
	slow_left = 0.0
	zoom_target = 1.0
	var w: int = sim.winner
	var eff: Dictionary = PLAY_EFFECTS[play_kind]
	if eff["series"]:
		if w >= 0:
			wins[w] += 1
		series_over = wins[0] >= 2 or wins[1] >= 2 or round_no >= 5
	_build_report()
	if mode == Mode.DUEL:
		sfx.play("win" if w >= 0 else "lose")
	else:
		sfx.play("win" if w == 0 else "lose")
	if eff["progress"]:
		_progress_and_achievements()
	if eff["log"]:
		Save.playtest_log(_pt_entry(0))


func _pt_entry(rating: int) -> Dictionary:
	return {"event": "rating" if rating > 0 else "battle", "mode": _mode_label(), "round": round_no, "winner": sim.winner,
		"ticks": sim.tick, "reason": sim.reason, "blue": last_armies[0].to_code(), "red": last_armies[1].to_code(),
		"power": [sim.power(0), sim.power(1)], "suspense": report.get("sus", {}), "call_tick": pt_call_tick,
		"rating": rating, "rules": D.RULES_VERSION, "digest": D.data_digest()}


func _pt_rate(v: int) -> void:
	pt_rated = true
	if PLAY_EFFECTS[play_kind]["log"]:
		Save.playtest_log(_pt_entry(v))
	_toast(L.t("pt_thanks"))


func _build_report() -> void:
	var dealt := [D.zeros(), D.zeros()]
	var taken := [D.zeros(), D.zeros()]
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
	# 時間軸的領先交換點（第三輪 U5）：戰力差換號（忽略 1% 以內的小波動），最多 4 個
	var leads: Array = []
	var last_sign := 0
	var eps: int = sim.budget * 1000 / 100
	for t in sim.power_log.size():
		var d: int = sim.power_log[t]
		var sg := 0 if absi(d) <= eps else (1 if d > 0 else -1)
		if sg != 0 and last_sign != 0 and sg != last_sign and leads.size() < 4:
			leads.append(t + 1)
		if sg != 0:
			last_sign = sg
	report["leads"] = leads
	# 殘局星等算在報告裡（重播也看得到），只有「寫進存檔」才受副作用矩陣管（Codex S1 #8）
	if mode == Mode.TUTORIAL or mode == Mode.PUZZLE:
		var pz := PZ.get_puzzle(puzzle_id)
		var extra_spent: int = armies[0].spent() - (armies[0].budget - int(pz["budget"]))
		var rem: int = sim.power(0) * 100 / (sim.budget * 1000) if sim.winner == 0 else 0
		report["stars"] = PZ.stars(pz, sim.winner == 0, rem, extra_spent)


func _progress_and_achievements() -> void:
	var w: int = sim.winner
	var st: Dictionary = Save.data.get("stats", {"wins": 0, "games": 0})
	var g_before := int(st.get("games", 0))
	st["games"] = g_before + 1
	# 新兵種解鎖（第四輪 §9）：提示並指向殘局裡的新兵試玩
	for nt in RS.newly_unlocked(g_before, g_before + 1, OS.has_feature("demo")):
		ach_queue.append(L.t("unit_unlocked", [L.t("unit_%d" % nt)]))
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
		var stars := int(report.get("stars", 0))
		var ps: Dictionary = Save.data.get("puzzle_stars", {})
		if stars > int(ps.get(puzzle_id, 0)):
			ps[puzzle_id] = stars
		Save.data["puzzle_stars"] = ps
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


## 兵種卡的矩形：繪製、點擊、焦點、版面探針共用這一個函式（第四輪 §4.1）。
func _card_rect(i: int) -> Rect2:
	return Rect2(CARD_X0 + i * (CARD_W + CARD_GAP), CARD_Y, CARD_W, CARD_H)


## 兵種卡右上角的「?」：開圖鑑到這個兵種（第二輪方案 R3）。
func _card_help_rect(i: int) -> Rect2:
	var r := _card_rect(i)
	return Rect2(r.end.x - 23, r.end.y - 23, 20, 20)   # 下層右邊（第四輪三層卡）


func _card_at(p: Vector2) -> int:
	for i in D.COUNT:
		if _card_rect(i).has_point(p):
			return i
	return -1


## 這一場開放幾種兵（第四輪 §9）：朋友對戰看「兵種」設定；對 AI、遠征看解鎖進度（也可選經典 5 種）；教學與殘局由關卡限制。
func _ntypes() -> int:
	var games := int(Save.data.get("stats", {}).get("games", 0))
	var classic := str(Save.s("roster")) == "classic"
	var kind := "all"
	if mode == Mode.DUEL:
		kind = "duel"
	elif mode == Mode.VS_AI or mode == Mode.GAUNTLET:
		kind = "ai"
	return RS.ntypes_for(kind, games, classic, OS.has_feature("demo"))


func _allowed(t: int) -> bool:
	if t >= _ntypes():
		return false
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
		_enqueue("paint", mouse)   # 一律排入，由執行端判斷有沒有在塗兵（同一幀按下再拖過也不漏格，Codex S3）
		return
	if ev is InputEventMouseButton:
		mouse = ev.position
		if overlay == "codex" and ev.pressed and (ev.button_index == MOUSE_BUTTON_WHEEL_UP or ev.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			_scroll_at(mouse, -48.0 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else 48.0)   # 圖鑑捲動（第三輪 U1）
			return
		_enqueue("mb", {"i": ev.button_index, "pressed": ev.pressed, "pos": ev.position})
		return
	if ev is InputEventKey and ev.pressed:
		if not ev.echo or ev.keycode in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
			_enqueue("key", ev.keycode)
		return
	if ev is InputEventJoypadButton and ev.pressed:
		pad_mode = true
		var map := {JOY_BUTTON_DPAD_UP: KEY_UP, JOY_BUTTON_DPAD_DOWN: KEY_DOWN, JOY_BUTTON_DPAD_LEFT: KEY_LEFT,
			JOY_BUTTON_DPAD_RIGHT: KEY_RIGHT, JOY_BUTTON_A: KEY_ENTER, JOY_BUTTON_B: KEY_ESCAPE, JOY_BUTTON_X: KEY_BACKSPACE,
			JOY_BUTTON_START: KEY_SPACE, JOY_BUTTON_Y: KEY_TAB, JOY_BUTTON_LEFT_SHOULDER: KEY_Q, JOY_BUTTON_RIGHT_SHOULDER: KEY_E,
			JOY_BUTTON_BACK: KEY_F1}
		if map.has(ev.button_index):
			_enqueue("key", map[ev.button_index])
		return
	if ev is InputEventJoypadMotion and ev.axis == JOY_AXIS_RIGHT_Y and overlay == "codex" and absf(ev.axis_value) > 0.3:
		pad_mode = true
		_scroll_by("left", ev.axis_value * 24.0)   # 右搖桿捲圖鑑左欄
		return
	if ev is InputEventJoypadMotion and (ev.axis == JOY_AXIS_LEFT_X or ev.axis == JOY_AXIS_LEFT_Y):
		# 左搖桿：只記下狀態，由 _stick_repeat 依固定節奏送方向鍵（Codex S1 #6：原本每個抖動事件都會送一次）
		stick[ev.axis] = ev.axis_value
		if absf(ev.axis_value) > 0.6:
			pad_mode = true


## 塗兵（佇列命令）：按住拖過格子連續擺。
func _paint_cmd(p: Vector2) -> void:
	if state != St.PLACE or overlay != "" or not painting:
		return
	if _cur_army().team != paint_team:
		painting = false
		return
	var c := _cell_at(p)
	if c.x >= 0 and _cur_army().index_at(c.x, c.y) == -1:
		_try_place(c)


func _mb_release_cleanup() -> void:
	drag_new = false
	painting = false
	drag_from = Vector2i(-1, -1)


## 滑鼠按鍵（佇列命令，第三輪 A2）：按鈕點擊、擺放、拖曳、移除。
func _mb_cmd(d: Dictionary) -> void:
	var mb := InputEventMouseButton.new()
	mb.button_index = d["i"]
	mb.pressed = d["pressed"]
	mb.position = d["pos"]
	mouse = d["pos"]
	if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
		if _do_click(mouse) > 0:
			_mb_release_cleanup()
			return
	if overlay != "" or state != St.PLACE:
		if not mb.pressed:   # 放開滑鼠一定要清掉拖曳／塗兵狀態，即使上面蓋著覆蓋層
			_mb_release_cleanup()
			if overlay == "" and state == St.BATTLE and mb.button_index == MOUSE_BUTTON_LEFT:
				_battle_click(mouse)   # 重播時點兵讓鏡頭跟（第三輪 F2）
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
				if _btns_gen == _gen and _focus >= 0 and _focus < _btns.size() and _btns[_focus]["en"]:   # 按鈕清單要是這個畫面的
					sfx.play("ui_click")
					_btns[_focus]["cb"].call()
			KEY_PAGEUP, KEY_PAGEDOWN:
				if overlay == "codex":
					_scroll_by("left", -160.0 if k == KEY_PAGEUP else 160.0)
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
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0:
			var t := 9 if k == KEY_0 else k - KEY_1
			if t < D.COUNT and _allowed(t):
				selected = t
		KEY_Q, KEY_E:
			for i in D.COUNT:
				selected = (selected + (D.COUNT - 1 if k == KEY_Q else 1)) % D.COUNT
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

## 搖桿連發（第三輪 A2）：超過 0.6 才算推、低於 0.35 才算放開（遲滯）；推下立刻一次，0.35 秒後每 0.12 秒一次。
var stick := {JOY_AXIS_LEFT_X: 0.0, JOY_AXIS_LEFT_Y: 0.0}
var _stick_dir := Vector2i.ZERO
var _stick_t := 0.0

func _stick_repeat(delta: float) -> void:
	var d := _stick_dir
	for ax in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		var v: float = stick[ax]
		var cur: int = d.x if ax == JOY_AXIS_LEFT_X else d.y
		var nv := cur
		if absf(v) > 0.6:
			nv = 1 if v > 0 else -1
		elif absf(v) < 0.35:
			nv = 0
		if ax == JOY_AXIS_LEFT_X:
			d.x = nv
		else:
			d.y = nv
	if d != _stick_dir:
		_stick_dir = d
		_stick_t = 0.35
		_stick_fire()
	elif d != Vector2i.ZERO:
		_stick_t -= delta
		if _stick_t <= 0.0:
			_stick_t += 0.12
			_stick_fire()

func _stick_fire() -> void:
	if _stick_dir.x != 0:
		_enqueue("key", KEY_RIGHT if _stick_dir.x > 0 else KEY_LEFT)
	if _stick_dir.y != 0:
		_enqueue("key", KEY_DOWN if _stick_dir.y > 0 else KEY_UP)


func _process_inner(delta: float) -> void:
	_stick_repeat(delta)
	_process_cmds()
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
			if f.has("pop"):
				f["pop"] = maxf(0.0, f["pop"] - delta)
		fx = fx.filter(func(f): return f["t"] < f["dur"])
		clutch_t = maxf(0.0, clutch_t - delta)
	for g in dying:
		g["t"] += delta
		if g["t"] >= 1.0:
			graves.append({"pos": g["pos"], "team": g["team"], "t": 0.0})
	dying = dying.filter(func(g): return g["t"] < 1.0)
	for g in graves:
		g["t"] += delta
	graves = graves.filter(func(g): return g["t"] < 3.0)
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
		_follow_update(delta)
	elif state == St.RESULT:
		zoom = lerpf(zoom, 1.0, delta * 4)
	if font_bold != null:
		_layout_texts()   # 戰鬥事件產生跳字之後才排版，新跳字第一幀就有位置（Codex S1 #3）
	queue_redraw()


# ───────────────────────── 繪圖 ─────────────────────────
func _draw() -> void:
	var _t0 := Time.get_ticks_usec()
	_draw_inner()
	perf_draw_us = Time.get_ticks_usec() - _t0

func _draw_inner() -> void:
	_btns.clear()
	probe_texts.clear()
	_probe_ui = false
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
	_cam = cam
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
	for f in fx:   # 先畫特效，跳字最後畫（Antigravity S2 #1：特效不能蓋住跳字）
		if not f.get("screen", false) and f["kind"] != "text":
			_draw_fx(f)
	for f in fx:
		if not f.get("screen", false) and f["kind"] == "text":
			_draw_fx(f)
	perf_parts["fx"] = Time.get_ticks_usec() - _t
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_probe_ui = true
	Art.base = Transform2D.IDENTITY
	if state == St.BATTLE and slow_left > 0:
		_draw_vignette(clampf((8.0 - slow_left) / 0.3, 0.0, 1.0))   # 多層暗角（第三輪 V2）
	if state != St.RESULT:
		for f in fx:
			if f.get("screen", false):
				_draw_fx(f)
	match state:
		St.TITLE: _draw_title()
		St.PLACE: _draw_place_hud()
		St.BATTLE:
			_draw_battle_hud()
			_draw_replay_controls()
		St.RESULT:
			_draw_battle_hud()
			_draw_result()
	_draw_clutch_banner()
	_draw_overlay()
	_draw_pad_footer()
	if toast_t > 0:
		var a := minf(1.0, toast_t * 2)
		var tw := font.get_string_size(toast, HORIZONTAL_ALIGNMENT_LEFT, -1, ts(20)).x + 40
		var ty := 40.0 if overlay != "" else 616.0   # 覆蓋層開著時放上面，不蓋住內容（手感輪 R3）
		draw_rect(Rect2(640 - tw / 2, ty, tw, 44), Color(0, 0, 0, 0.72 * a))
		_text(Vector2(640, ty + 6), toast, ts(20), Color(1, 0.88, 0.5, a), true)
	if _focus >= _btns.size():
		_focus = 0
	_btns_gen = _gen


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
			_lock_icon(p + Vector2(17, -60))   # 14px 鎖頭（第三輪 U4）
	if not pz.is_empty() and not pz.get("fixed", []).is_empty():
		# 圖例
		var lg := ORIGIN + Vector2(10, 10)
		draw_rect(Rect2(lg, Vector2(190, 28)), Color(0, 0, 0, 0.5))
		_lock_icon(lg + Vector2(16, 16))
		_text(lg + Vector2(30, 4), L.t("lock_legend"), ts(14), Color.WHITE, false, false, 150)
	if hide_side >= 0:
		var x0 := 10 if hide_side == 1 else 0
		# 迷霧（R6）：深藍紫半透明＋飄動的雲＋發光紅問號旗，格線仍透出來
		var mr := Rect2(ORIGIN + Vector2(x0 * CS, 0), Vector2(6 * CS, FIELD.y))
		draw_rect(mr, Color(0.11, 0.09, 0.24, 0.80))
		for k in 3:
			var cxp := fposmod(time * (14.0 + k * 6.0) + k * 150.0, mr.size.x + 220.0) - 110.0
			var cc := mr.position + Vector2(cxp, 90.0 + k * 170.0)
			for b in 5:
				var off := Vector2((b - 2) * 26.0, -absf(b - 2.0) * -6.0 - 8.0 * float(b % 2))
				var rr := mr.position.x - 10.0
				var cp := cc + off
				if cp.x > rr and cp.x < mr.end.x + 10.0:
					draw_circle(cp, 26.0 - absf(b - 2.0) * 4.0, Color(0.8, 0.82, 1.0, 0.07), true, -1.0, true)
		var fp := mr.position + Vector2(mr.size.x / 2 - 8, mr.size.y / 2 - 120)
		var glow := 0.5 + 0.5 * sin(time * 2.4)
		draw_circle(fp + Vector2(22, 18), 34 + glow * 6, Color(1, 0.25, 0.25, 0.10 + glow * 0.06), true, -1.0, true)
		draw_line(fp, fp + Vector2(0, 74), Color(0.85, 0.78, 0.7), 3.0, true)
		draw_colored_polygon(PackedVector2Array([fp, fp + Vector2(48, 16), fp + Vector2(0, 36)]), Color(0.9, 0.2, 0.22))
		_text(fp + Vector2(15, 2), "?", ts(22), Color.WHITE, true, true)
		var msg := L.t("ai_hidden") if mode == Mode.VS_AI else L.t("enemy_hidden")
		_text(ORIGIN + Vector2((x0 + 3) * CS, FIELD.y / 2 - 10), msg, ts(22), Color(1, 1, 1, 0.85), true, true, 6 * CS - 20)
		if mode == Mode.VS_AI:
			# AI 的難度與性格（第三輪 U3）：不洩漏陣型
			_text(ORIGIN + Vector2((x0 + 3) * CS, FIELD.y / 2 + 70), L.t("ai_trait_%d" % difficulty), ts(15), Color(1, 0.85, 0.6, 0.8), true, false, 6 * CS - 30)
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
				_arc_clipped(p, 6.0 * CS, 0, TAU, Color(1, 0.9, 0.5, 0.45), 2.0)
			D.PIKE:
				_arc_clipped(p, D.STATS[D.PIKE]["reach"] / 1000.0 * CS, 0, TAU, Color(1, 0.9, 0.5, 0.5), 2.0)
			D.BOMBER:
				# 甜甜圈：外圈射程（橘白）＋內圈紅色盲區（第四輪 §4.2）
				_arc_clipped(p, D.STATS[D.BOMBER]["reach"] / 1000.0 * CS, 0, TAU, Color(1, 0.85, 0.7, 0.5), 2.0)
				draw_circle(p, D.BOMB_MIN / 1000.0 * CS, Color(1, 0.25, 0.2, 0.12), true, -1.0, true)
				draw_arc(p, D.BOMB_MIN / 1000.0 * CS, 0, TAU, 32, Color(1, 0.3, 0.25, 0.7), 2.0, true)
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
	# 已擺的弓手射程：只在「選著弓手、游標停在那隻弓手上、或按住 Alt／LT」時顯示，並裁在棋盤內（第三輪 U3）
	var show_all := selected == D.ARCHER or Input.is_key_pressed(KEY_ALT) or Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT) > 0.5
	for u in army.units:
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
				draw_arc(Vector2.ZERO, 24, 0, TAU, 28, Color(bc, 0.7), 2.0, true)
				draw_set_transform_matrix(_cam)
			draw_circle(ep, 11, Color("#111827"), true, -1.0, true)
			draw_arc(ep, 11, 0, TAU, 20, bc, 2.0, true)
			if sc > 0:
				draw_polyline(PackedVector2Array([ep + Vector2(-5, 0), ep + Vector2(-1, 4), ep + Vector2(6, -5)]), bc, 3.0, true)
			else:
				draw_line(ep + Vector2(-5, -5), ep + Vector2(5, 5), bc, 3.0, true)
				draw_line(ep + Vector2(-5, 5), ep + Vector2(5, -5), bc, 3.0, true)


## 手把按鍵提示列（第三輪 U7）：用手把時，每個畫面右下角顯示這個畫面能按的鍵（A／B／X／Y 圓形圖示）；
## 用鍵盤滑鼠時不顯示手把圖示（Steam Deck 規定兩者不能同時出現）。擺放畫面已經在上方列顯示，這裡略過。
func _draw_pad_footer() -> void:
	if not pad_mode or (state == St.PLACE and overlay == ""):
		return
	var items: Array = []
	if overlay == "codex":
		items = [["A", L.t("pk_select")], ["B", L.t("back")], ["R", L.t("pk_scroll")]]
	elif overlay != "":
		items = [["A", L.t("pk_select")], ["B", L.t("back")]]
	else:
		match state:
			St.TITLE:
				items = [["✛", L.t("pk_move")], ["A", L.t("pk_select")]]
			St.BATTLE:
				items = [["A", L.t("pk_select")], ["B", L.t("skip")]]
			St.RESULT:
				items = [["✛", L.t("pk_move")], ["A", L.t("pk_select")], ["B", L.t("menu")]]
	if items.is_empty():
		return
	draw_rect(Rect2(0, 770, 1280, 30), Color(0, 0, 0, 0.45))
	_key_hints(640, 773, items, 14)


## 鎖頭圖示（固定兵）。
func _lock_icon(c: Vector2) -> void:
	draw_arc(c + Vector2(0, -3), 4.5, PI, TAU, 10, Art.OUT, 4.0, true)
	draw_arc(c + Vector2(0, -3), 4.5, PI, TAU, 10, Color(0.95, 0.82, 0.32), 2.2, true)
	draw_rect(Rect2(c + Vector2(-7, -3), Vector2(14, 11)), Art.OUT)
	draw_rect(Rect2(c + Vector2(-6, -2), Vector2(12, 9)), Color(0.95, 0.82, 0.32))
	draw_circle(c + Vector2(0, 2), 1.6, Art.OUT, true, -1.0, true)


## 殘局的迷你敵陣縮圖：右半 6×9 格，每隻敵兵畫一個兵種色點。
func _mini_formation(r: Rect2, pz: Dictionary, en: bool) -> void:
	draw_rect(r, Color(0.2, 0.3, 0.18, 0.9 if en else 0.4))
	var ea = PZ.enemy_army(pz)
	var cw := r.size.x / 6.0
	var ch := r.size.y / 9.0
	# 敵陣：純紅色大菱形（Antigravity S3 第 2 輪：兵種色小點太小分不出敵我）
	for u in ea.units:
		var cx := int(u["col"]) - 10
		var q := r.position + Vector2((cx + 0.5) * cw, (int(u["row"]) + 0.5) * ch)
		var rr := maxf(3.5, minf(cw, ch) * 0.75)
		draw_colored_polygon(PackedVector2Array([q + Vector2(0, -rr), q + Vector2(rr, 0), q + Vector2(0, rr), q + Vector2(-rr, 0)]), Color(Art.team_color(1, cbm()), 1.0 if en else 0.4))
	draw_rect(r, Color(1, 1, 1, 0.3), false, 1.0)


## 裁在棋盤內的圓弧（第三輪 U3）：取樣點，只畫兩端都在場內的線段。
func _arc_clipped(c: Vector2, r: float, a0: float, a1: float, col: Color, w: float) -> void:
	var field := Rect2(ORIGIN, FIELD)
	var n := 72
	var prev := c + Vector2(cos(a0), sin(a0)) * r
	for i in range(1, n + 1):
		var an := a0 + (a1 - a0) * i / n
		var q := c + Vector2(cos(an), sin(an)) * r
		if field.has_point(prev) and field.has_point(q):
			draw_line(prev, q, col, w, true)
		prev = q


## 兵種卡上方的剋制提示條（第三輪 U3）：「剋」＋被剋的小頭像、「怕」＋天敵的小頭像。
func _draw_counter_strip(i: int, team: int) -> void:
	var r := _card_rect(i)
	var beats: Array = []
	var fears: Array = []
	for t in D.COUNT:
		var sc := AIT.counter_score(i, t)
		if sc > 0:
			beats.append(t)
		elif sc < 0:
			fears.append(t)
	# 第四輪：兵種名稱放在提示條最左邊；提示條置中在卡片列上方、寬度依內容（最寬 600）
	var fz := mini(ts(14), 18)
	var nz := mini(ts(16), 20)
	var name: String = L.t("unit_%d" % i)
	var lock := ""
	if i >= _ntypes():
		var g := int(Save.data.get("stats", {}).get("games", 0))
		var left := RS.games_to_unlock(i, g, OS.has_feature("demo"))
		lock = L.t("locked_demo") if left < 0 else (L.t("locked_classic") if left == 0 else L.t("locked_games", [left]))
	var syn: Array = AIT.SYNERGY.get(i, [])
	var lab_b: String = L.t("synergy") if D.is_support(i) else L.t("beats")
	var list_b: Array = syn if D.is_support(i) else beats
	var w := font_bold.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, nz).x + 24
	if lock != "":
		w += font.get_string_size(lock, HORIZONTAL_ALIGNMENT_LEFT, -1, fz).x + 12
	else:
		w += font_bold.get_string_size(lab_b + L.t("fears"), HORIZONTAL_ALIGNMENT_LEFT, -1, fz).x + 8 + 24 * (list_b.size() + fears.size()) + 26
	w = minf(600.0, w)
	var cx := clampf(r.get_center().x, 12 + w / 2.0, 876 - w / 2.0)
	var sr := Rect2(cx - w / 2.0, r.position.y - 40, w, 34)
	draw_rect(sr, Color(0.06, 0.07, 0.1, 0.92))
	draw_rect(sr, Color(1, 1, 1, 0.25), false, 1.5)
	var x := sr.position.x + 8
	_text(Vector2(x, sr.position.y + 5), name, nz, ACCENT, false, true)
	x += font_bold.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, nz).x + 12
	if lock != "":
		_text(Vector2(x, sr.position.y + 7), lock, fz, Color(1, 1, 1, 0.8), false, false)
		return
	_text(Vector2(x, sr.position.y + 6), lab_b, fz, Color("#4ade80"), false, true)
	x += font_bold.get_string_size(lab_b, HORIZONTAL_ALIGNMENT_LEFT, -1, fz).x + 4
	beats = list_b
	for t in beats:
		Art.unit(self, Vector2(x + 12, sr.position.y + 32), t, 1 - team, 1.0, 0.0, 0.0, 0.0, 1.0, time, 0.5, cbm())
		x += 24
	x += 10
	_text(Vector2(x, sr.position.y + 6), L.t("fears"), fz, Color("#f87171"), false, true)
	x += font_bold.get_string_size(L.t("fears"), HORIZONTAL_ALIGNMENT_LEFT, -1, fz).x + 4
	for t in fears:
		Art.unit(self, Vector2(x + 12, sr.position.y + 32), t, 1 - team, 1.0, 0.0, 0.0, 0.0, 1.0, time, 0.5, cbm())
		x += 24


# ── 標題 ──
func _draw_title() -> void:
	draw_rect(Rect2(0, 0, 1280, 800), Color(0.05, 0.06, 0.1, 0.42))
	if overlay != "":
		return
	var bob := sin(time * 1.5) * 4
	# 遮罩改成上濃下淡、左右羽化，讓背景的自動對戰露出來（第三輪 U6）：用頂點色漸層，不會有色階
	var dk := Color(0.05, 0.06, 0.1, 0.66)
	var cl := Color(0.05, 0.06, 0.1, 0.0)
	var mid_a := Color(0.05, 0.06, 0.1, 0.30)
	for q in [[Rect2(330, 30, 620, 380), dk, mid_a], [Rect2(330, 410, 620, 330), mid_a, cl]]:
		var r: Rect2 = q[0]
		draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), PackedColorArray([q[1], q[1], q[2], q[2]]))
		# 左右羽化
		draw_polygon(PackedVector2Array([r.position - Vector2(90, 0), r.position, Vector2(r.position.x, r.end.y), Vector2(r.position.x - 90, r.end.y)]), PackedColorArray([cl, q[1], q[2], cl]))
		draw_polygon(PackedVector2Array([Vector2(r.end.x, r.position.y), Vector2(r.end.x + 90, r.position.y), Vector2(r.end.x + 90, r.end.y), r.end]), PackedColorArray([q[1], cl, cl, q[2]]))
	# 大標：雙層描邊＋深色立體投影（第三輪 U6）
	var tsz := mini(ts(84), 96)
	var tt: String = L.t("title")
	var tw := font_bold.get_string_size(tt, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz).x
	var tp := Vector2(640 - tw / 2, 64 + bob + tsz * 0.85)
	for d in 4:
		draw_string(font_bold, tp + Vector2(1, 1) * (d + 1) * 1.6, tt, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, Color(0.32, 0.17, 0.04, 0.9))
	draw_string_outline(font_bold, tp, tt, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, 9, Color("#3a2205"))
	draw_string_outline(font_bold, tp, tt, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, 5, Color("#b8860b"))
	draw_string(font_bold, tp, tt, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, Color("#ffe8a3"))
	var ty := 64.0 + tsz * 1.25
	_text(Vector2(640, ty), "No Take-Backs" if L.lang == "zh_TW" else "落子無悔", mini(ts(26), 30), Color(1, 1, 1, 0.85), true, false, 740)
	ty += mini(ts(26), 30) * 1.4
	_text(Vector2(640, ty), L.t("subtitle"), ts(18), Color(1, 1, 1, 0.9), true, false, 740)
	# 主戰場三顆大鈕；訓練挑戰並排三顆；設定、名單、離開在底部小鈕（第三輪 U6）
	var y0 := maxf(282.0, ty + ts(18) * 1.6 + 16.0)
	var main := [["menu_vs_ai", func(): _open("diff")], ["menu_duel", func(): _open("rule")], ["menu_gauntlet", func(): _start_mode(Mode.GAUNTLET)]]
	for i in main.size():
		_btn(Rect2(490, y0 + i * 58, 300, 50), L.t(main[i][0]), main[i][1], true, i == 0)
	var y1 := y0 + 3 * 58 + 14
	var side := [["menu_tutorial", func(): _open("tutorial")], ["menu_puzzle", func(): _open("puzzles")], ["menu_codex", func(): _open_codex(0)]]
	for i in side.size():
		_btn(Rect2(400 + i * 164, y1, 156, 44), L.t(side[i][0]), side[i][1])
	var y2 := y1 + 60
	var sys := [["menu_settings", func(): _open("settings")], ["menu_credits", func(): _open("credits")], ["menu_quit", func(): get_tree().quit()]]
	for i in sys.size():
		_btn(Rect2(460 + i * 124, y2, 116, 36), L.t(sys[i][0]), sys[i][1], true, false, Color(0.12, 0.13, 0.18, 0.9))
	_btn(Rect2(20, 744, 220, 38), L.t("bc_watch"), func(): _watch_battle_code())   # 觀看對戰代碼（第三輪 F3）
	_text(Vector2(640, 752), "%s　｜　v%s" % [L.t("gauntlet_best", [int(Save.data.get("gauntlet_best", 0))]), D.RULES_VERSION], ts(13), Color(1, 1, 1, 0.5), true)


## 「兵種：經典 5 種／全部」切換（第四輪 §9）。對 AI 時「全部」＝已解鎖的兵種。
func _roster_btn(r: Rect2, kind: String) -> void:
	var classic := str(Save.s("roster")) == "classic"
	var games := int(Save.data.get("stats", {}).get("games", 0))
	var n := RS.ntypes_for(kind, games, false, OS.has_feature("demo"))
	var lbl: String = L.t("roster_classic") if classic else L.t("roster_all", [n])
	_btn(r, lbl, func(): Save.set_setting("roster", "all" if classic else "classic"))


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
			_panel(Rect2(440, 230, 400, 370))
			_text(Vector2(640, 246), L.t("choose_diff"), ts(24), Color.WHITE, true, true)
			for i in 3:
				_btn(Rect2(500, 306 + i * 60, 280, 48), L.t(["diff_easy", "diff_normal", "diff_hard"][i]), _pick_difficulty.bind(i), true, i == 1)
			_roster_btn(Rect2(460, 490, 360, 40), "ai")
			_btn(Rect2(560, 548, 160, 36), L.t("back"), func(): overlay = "")
		"rule":
			_panel(Rect2(400, 220, 480, 390))
			_text(Vector2(640, 236), L.t("choose_rule"), ts(24), Color.WHITE, true, true)
			var rules := ["snake5", "cap10", "blind"]
			for i in 3:
				_btn(Rect2(440, 300 + i * 62, 400, 50), L.t("rule_" + rules[i]), _pick_rule.bind(rules[i]), true, rules[i] == duel_rule)
			_roster_btn(Rect2(440, 498, 400, 40), "duel")
			_btn(Rect2(560, 556, 160, 36), L.t("back"), func(): overlay = "")
		"tutorial", "puzzles":
			var tut := overlay == "tutorial"
			var list: Array = PZ.tutorials() if tut else (PZ.puzzles() if puzzle_tab == 0 else PZ.new_puzzles())
			var stars: Dictionary = Save.data.get("puzzle_stars", {})
			var tdone := int(Save.data.get("tutorial", 0))
			var unlocked := tut or tdone >= 1
			_panel(Rect2(240, 110, 800, 580))
			_text(Vector2(640, 126), L.t("menu_tutorial") if tut else L.t("puzzle_title"), ts(26), Color.WHITE, true, true)
			if not tut and unlocked:
				# 兩個分頁：經典殘局／新兵試玩（第四輪 §4.8）；頁籤上直接寫各自的總星數（第三輪 U4）
				var tabs := [PZ.puzzles(), PZ.new_puzzles()]
				for ti in 2:
					var total := 0
					for pz0 in tabs[ti]:
						total += int(stars.get(pz0["id"], 0))
					var lbl := "%s　★ %d／%d" % [L.t("puzzle_tab_%d" % ti), total, tabs[ti].size() * 3]
					_btn(Rect2(380 + ti * 270, 160, 250, 36), lbl, func(): puzzle_tab = ti, true, false, Color(0.26, 0.31, 0.45) if ti == puzzle_tab else Color(0, 0, 0, 0))
			if not unlocked:
				_text(Vector2(640, 172), L.t("puzzle_locked"), ts(16), ACCENT, true)
			for i in list.size():
				var pz: Dictionary = list[i]
				var r := Rect2(280 + (i % 2) * 370, 210 + (i / 2) * 82, 350, 68)
				var name: String = pz["zh"] if L.lang == "zh_TW" else pz["en"]
				var st := int(stars.get(pz["id"], 0))
				var en := unlocked and (not tut or i <= tdone)
				var line := "%s%d. %s　%s" % ["✓ " if st > 0 else "", i + 1, name, "★".repeat(st) + "☆".repeat(3 - st)]
				if pz.has("unit"):
					# 新兵試玩：那個兵種解鎖後才能玩
					var left := RS.games_to_unlock(int(pz["unit"]), int(Save.data.get("stats", {}).get("games", 0)), OS.has_feature("demo"))
					if left != 0:
						en = false
						line = "%d. %s（%s）" % [i + 1, name, L.t("locked_demo") if left < 0 else L.t("locked_short", [left])]
				_btn(r, line, _pick_puzzle.bind(pz["id"], tut), en, false,
					Color(0.15, 0.32, 0.22) if st > 0 else Color(0, 0, 0, 0))
				# 主角兵種小頭像（R6）：這關第一個可用的兵種
				_mini_formation(Rect2(r.position + Vector2(6, 6), Vector2(52, 56)), pz, en)   # 迷你敵陣縮圖（第三輪 U4）
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
		"review":
			_draw_review()


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


## 結果頁兵種長條要列哪幾種：有出場（造成或承受傷害）的兵種，依雙方合計由多到少，最多 5 種；同分取編號小的。
static func report_rows(dealt: Array, taken: Array) -> Array:
	var rows: Array = []
	for t in D.COUNT:
		if dealt[0][t] + dealt[1][t] + taken[0][t] + taken[1][t] > 0:
			rows.append(t)
	rows.sort_custom(func(p, q):
		var sp: int = dealt[0][p] + dealt[1][p] + taken[0][p] + taken[1][p]
		var sq: int = dealt[0][q] + dealt[1][q] + taken[0][q] + taken[1][q]
		return sp > sq or (sp == sq and p < q))
	return rows.slice(0, 5)


## 結果頁的技能徽章（第四輪）：候選裡雙方合計次數最多的 6 種；不夠 6 種就用經典的預設順序補。支援兵的補血、戰鼓也在候選裡（對支援兵公平）。
const BADGE_KEYS := ["breaker", "charge", "backstab", "braced", "anticav", "counter", "pike_brace", "splash", "breach", "heal", "drum"]
static func report_badges(cnt: Dictionary) -> Array:
	var used: Array = []
	for k in BADGE_KEYS:
		if int(cnt.get(k + "0", 0)) + int(cnt.get(k + "1", 0)) > 0:
			used.append(k)
	used.sort_custom(func(p, q):
		var sp: int = int(cnt.get(p + "0", 0)) + int(cnt.get(p + "1", 0))
		var sq: int = int(cnt.get(q + "0", 0)) + int(cnt.get(q + "1", 0))
		return sp > sq or (sp == sq and BADGE_KEYS.find(p) < BADGE_KEYS.find(q)))
	var out: Array = used.slice(0, 6)
	for k in BADGE_KEYS:
		if out.size() >= 6:
			break
		if not out.has(k):
			out.append(k)
	return out


## 陣型存檔格的組成摘要：只列有的兵種（兵種多了以後不能再寫死 5 格）。
func _comp_desc(cnt: Array) -> String:
	var parts := PackedStringArray()
	for t in cnt.size():
		if cnt[t] > 0:
			parts.append("%s%d" % [L.t("ushort_%d" % t), cnt[t]])
	return " ".join(parts) if not parts.is_empty() else L.t("empty")


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
				var cnt := D.zeros()
				for u in tmp.units:
					cnt[u["type"]] += 1
				desc = _comp_desc(cnt)
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
	_text(Vector2(20, 8), L.t("title"), ts(26), Color("#ffe8a3"), false, true, 250)
	_text(Vector2(20, 52), _mode_label(), ts(14), Color(1, 1, 1, 0.6), false, false, 250)
	if mode == Mode.VS_AI or mode == Mode.DUEL:
		_text(Vector2(1110, 8), L.t("round", [round_no]), ts(16), Color.WHITE, false, false, 160)
		_text(Vector2(1110, 34), L.t("score", [wins[0], wins[1]]), ts(16), Color.WHITE, false, false, 160)
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
	_text(Vector2(640, 1), head, mini(ts(22), 26), tcol if mode == Mode.DUEL else Color.WHITE, true, true, 560)   # 上方列高度固定，大字時封頂
	var bx := 400.0
	var bw := 480.0
	draw_rect(Rect2(bx, 58, bw, 4), Color(0.2, 0.2, 0.25))
	draw_rect(Rect2(bx, 58, bw * clampf(float(a.spent()) / a.budget, 0, 1), 4), tcol)
	# 圖示膠囊（R6）：隊伍、金幣、人數
	var t_lbl := L.t("blue") if a.team == 0 else L.t("red")
	var g_lbl := "%d / %d" % [a.spent(), a.budget]
	var u_lbl := "%d / %d" % [a.count(), Army.MAX_UNITS]
	var est := 0.0
	for lbl in [t_lbl, g_lbl, u_lbl]:
		est += font_bold.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, mini(ts(13), 15)).x + 40.0   # 跟 _pill 實畫同字級
	est += 16.0   # 兩個間距
	var px := 640.0 - est / 2.0
	px += _pill(Vector2(px, 31), "team", t_lbl, tcol, 13, 15) + 8
	px += _pill(Vector2(px, 31), "coin", g_lbl, ACCENT, 13, 15) + 8
	_pill(Vector2(px, 31), "unit", u_lbl, Color.WHITE, 13, 15)
	var info := "%s：%s" % [L.t("unit_%d" % selected), L.t("blurb_%d" % selected)]
	if mode == Mode.TUTORIAL or mode == Mode.PUZZLE:
		var pz2 := PZ.get_puzzle(puzzle_id)
		info = pz2["hint_zh"] if L.lang == "zh_TW" else pz2["hint_en"]
		if mode == Mode.PUZZLE:
			info += "　｜　" + L.t("star_rules", [pz2["star2"], pz2["star3"]])   # 星級條件放在上方（第三輪 U4）
	elif mode == Mode.GAUNTLET:
		info = L.t("gauntlet_hint") if gauntlet_stage == 1 else L.t("gauntlet_changes", [maxi(0, gauntlet_changes - _gauntlet_diff())])
	elif mode == Mode.DUEL and tp != null:
		info += "　｜　" + L.t("place_hint_turns")
	elif pad_mode:
		info = ""
	else:
		info += "　｜　" + L.t("place_hint_free")
	if info == "":
		_key_hints(640, 64, [["✛", L.t("pk_move")], ["LB/RB", L.t("pk_pick")], ["A", L.t("pk_place")], ["X", L.t("pk_remove")], ["Start", L.t("pk_start")], ["Select", L.t("pk_codex")]], 14)
	else:
		_text(Vector2(640, 64), info, mini(ts(15), 17), Color(1, 1, 1, 0.85), true, false, 720)   # 不壓到左邊的模式名稱
	for i in D.COUNT:
		var r := _card_rect(i)
		var afford: bool = D.cost(i) <= a.left() and a.count() < Army.MAX_UNITS and _allowed(i)
		var bg := Color(0.17, 0.18, 0.24)
		if i == selected:
			bg = Color(0.26, 0.31, 0.45)
		elif i == hover_card:
			bg = Color(0.21, 0.23, 0.31)
		var opened := i < _ntypes()
		draw_rect(r, bg if afford else Color(bg, 0.45))
		draw_rect(r, tcol if i == selected else Color(1, 1, 1, 0.15), false, 2)
		# 三層卡（第四輪 §4.1）：上＝快捷鍵、價錢；中＝全身圖；下＝已擺數量、?
		Art.unit(self, r.position + Vector2(40, 74), i, a.team, 1.0, 0.0, 0.0, 0.0, (1.0 if afford else 0.45) if opened else 0.25, time, 0.78, cbm())
		var fz := mini(ts(13), 15)
		_text(r.position + Vector2(5, 3), "%d" % ((i + 1) % 10), fz, Color(1, 1, 1, 0.6), false, false, 20)
		if opened:
			var gtxt: String = L.t("gold", [D.cost(i)])
			var gz := fit(gtxt, fz, 52, true)
			var gw := font_bold.get_string_size(gtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, gz).x
			_text(r.position + Vector2(r.size.x - 5 - gw, 3), gtxt, gz, ACCENT if afford else Color("#f87171"), false, true)   # 靠右
			if a.count_of(i) > 0:
				_text(r.position + Vector2(5, r.size.y - fz - 6), "×%d" % a.count_of(i), fz, Color(1, 1, 1, 0.85), false, true, 44)
		else:
			_lock_icon(r.position + Vector2(r.size.x / 2.0, 44))
		_btn(_card_help_rect(i), "?", _open_codex.bind(i))
	if hover_card >= 0 or overlay == "":
		_draw_counter_strip(hover_card if hover_card >= 0 else selected, a.team)
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
	var title_sz := mini(ts(40), 48)
	_text(Vector2(640, 106), title, title_sz, col, true, true, 480)
	_btn(Rect2(252, 112, 124, 34), L.t("bc_copy"), func(): _copy_battle_code())   # 對戰代碼（第三輪 F3）
	if play_kind == "review":
		_text(Vector2(640, 106 + title_sz * 1.15), L.t("review_tag"), ts(13), ACCENT, true, false, 480)
	var mvp0 = report.get("mvp")
	_btn(Rect2(904, 112, 124, 34), L.t("menu_codex_short"), _open_codex.bind(mvp0.type if mvp0 != null else 0))
	var reason_key := {"全滅": "reason_wipe", "同時全滅": "reason_bothwipe", "時間到・戰力相當": "reason_time_even",
		"時間到・剩餘戰力較高": "reason_time_power", "有一方沒有兵": "reason_empty"}
	var tot := float(sim.budget * 1000)
	_text(Vector2(640, 106 + title_sz * 1.3), "%s・%.1fs　｜　%s" % [L.t(reason_key.get(sim.reason, "draw")), sim.tick / 20.0,
		L.t("power_left", [roundi(sim.power(0) * 100 / tot), roundi(sim.power(1) * 100 / tot)])], ts(16), Color(1, 1, 1, 0.85), true, false, 740)
	var y := 106.0 + title_sz * 1.3 + ts(16) * 1.4 + 4.0
	if w >= 0 and sim.alive_count(w) == 1:
		_text(Vector2(640, y), L.t("lone_hero"), ts(20), ACCENT, true, true)
		y += 30
	var sus: Dictionary = report.get("sus", {})
	if w >= 0 and int(sus.get("max_swing_pct", 0)) >= 15:
		_text(Vector2(640, y), L.t("report_comeback", [sus["max_swing_pct"]]), ts(18), Color("#7dff8a"), true, true)
		y += 28
	if w >= 0:
		_text(Vector2(640, y), _verdict(w), ts(17), Color(1, 1, 1, 0.95), true, true, 740)
		y += 28
	var sus_line := L.t("report_suspense", [sus.get("lead_changes", 0), report.get("lock_sec", 0), sus.get("max_swing_pct", 0)])
	if w >= 0 and int(sus.get("lock_ratio_permille", 0)) == 0:
		sus_line = L.t("report_led_all")
	_text(Vector2(640, y), sus_line, ts(14), Color(1, 1, 1, 0.75), true, false, 740)
	y += 28
	_text(Vector2(280, y), L.t("report_title"), ts(16), Color.WHITE, false, true, 140)
	_text(Vector2(430, y + 2), "■ " + L.t("report_dealt") + "　□ " + L.t("report_taken"), ts(12), Color(1, 1, 1, 0.6), false, false, 260)
	y += 30
	var dealt: Array = report["dealt"]
	var taken: Array = report["taken"]
	var mx := 1
	for tm in 2:
		for t in D.COUNT:
			mx = maxi(mx, maxi(dealt[tm][t], taken[tm][t]))
	# 兵種多了（第四輪）：只列這場出場、雙方合計（造成＋承受）最多的 5 種，版面高度不變
	var rows := report_rows(dealt, taken)
	for ri in rows.size():
		var t: int = rows[ri]
		_text(Vector2(280, y + ri * 30 - 2), L.t("unit_%d" % t), ts(13), Color.WHITE, false, false, 94)
		for tm in 2:
			var x0 := 380.0 + tm * 320.0
			var c := Art.team_color(tm, cbm())
			draw_rect(Rect2(x0, y + ri * 30 + 2, 290.0 * dealt[tm][t] / mx, 9), c)
			draw_rect(Rect2(x0, y + ri * 30 + 13, maxf(1.0, 290.0 * taken[tm][t] / mx), 9), c, false, 1.5)
	y += 156
	var ek := report_badges(ev_count)
	for tm in 2:
		var n: Array = []
		for k in ek:
			n.append(int(ev_count.get("%s%d" % [k, tm], 0)))
		# 雙陣營徽章卡（R6）
		var tcl := Art.team_color(tm, cbm())
		_text(Vector2(280, y + tm * 34 + 4), "●" if tm == 0 else "◆", ts(16), tcl, false, true)
		for j in ek.size():
			var br := Rect2(306 + j * 96, y + tm * 34, 90, 28)
			var on: bool = n[j] > 0
			draw_rect(br, Color(tcl, 0.22 if on else 0.07))
			draw_rect(br, Color(tcl, 0.7 if on else 0.2), false, 1.5)
			_text(br.position + Vector2(45, 3), "%s %d" % [L.t("ev_short_" + ek[j]), n[j]], ts(15), Color(1, 1, 1, 0.95 if on else 0.4), true, on, 84)
	y += 74
	var mvp = report.get("mvp")
	if mvp != null:
		var mp := Vector2(980, 300)
		draw_circle(mp + Vector2(0, -30), 46, Color(1, 0.82, 0.3, 0.18 + 0.06 * sin(time * 3)), true, -1.0, true)
		Art.ring(self, mp + Vector2(0, 20), mvp.team, mvp.type, cbm(), 1.8)
		Art.unit(self, mp + Vector2(0, 20), mvp.type, mvp.team, -1.0, 0.0, 0.0, 0.0, 1.0, time, 1.8, cbm())
		_text(mp + Vector2(0, 30), "MVP", ts(16), ACCENT, true, true)
		_text(Vector2(640, y), L.t("mvp", [L.t("blue") if mvp.team == 0 else L.t("red"), L.t("unit_%d" % mvp.type), mvp.dmg_dealt, mvp.kills]), ts(15), Color(1, 1, 1, 0.85), true, false, 740)
		y += 26
	# 先排短的結論行，再把剩下的空間給時間軸（第三輪 T4：大字時不能壓到下方按鈕）
	if report.has("stars"):
		var pz := PZ.get_puzzle(puzzle_id)
		var stn := int(report["stars"])
		_text(Vector2(640, y), "★".repeat(stn) + "☆".repeat(3 - stn) + "　" + L.t("star_rules", [pz["star2"], pz["star3"]]), ts(15), ACCENT, true, false, 740)
		y += ts(15) * 1.5
	if series_over and (mode == Mode.VS_AI or mode == Mode.DUEL):
		var sw := L.t("series_draw") if wins[0] == wins[1] else L.t("series_win", [L.t("blue") if wins[0] > wins[1] else L.t("red"), wins[0], wins[1]])
		_text(Vector2(640, y), L.t("series_end", [sw]), ts(17), ACCENT, true, true, 740)
		y += ts(17) * 1.5
	if mode == Mode.GAUNTLET:
		var msg := ""
		if w == 0 and gauntlet_stage >= 7:
			msg = L.t("gauntlet_clear")
		elif w != 0:
			msg = L.t("gauntlet_over", [gauntlet_stage - 1])
		if msg != "":
			_text(Vector2(640, y), msg, ts(18), ACCENT, true, true, 740)
			y += ts(18) * 1.5
	if bool(Save.s("playtest")) and not pt_rated:
		# 試玩評分放在右上角的固定位置，不參與正文排版（Codex S4 #3：150% 時會撞到底部按鈕）
		_text(Vector2(880, 152), L.t("pt_rate"), ts(12), ACCENT, false, false, 150)
		for i in 5:
			_btn(Rect2(880 + i * 30, 152 + ts(12) * 1.4, 26, 26), str(i + 1), _pt_rate.bind(i + 1))
	# 試玩版結尾（第三輪 F5）：打完一整個三戰兩勝，提示加入願望清單（只在匯出時帶 demo 功能的版本）
	if OS.has_feature("demo") and series_over and play_kind == "official":
		var wr := Rect2(300, y, 680, 46)
		draw_rect(wr, Color(0.35, 0.22, 0.05, 0.95))
		draw_rect(wr, ACCENT, false, 2.0)
		_text(Vector2(316, y + 10), L.t("demo_wish"), ts(16), Color.WHITE, false, true, 420)
		var url: String = SteamApi.STORE_URL
		_btn(Rect2(760, y + 4, 210, 38), L.t("demo_wish_btn") if url != "" else L.t("demo_wish_soon"), func(): OS.shell_open(url), url != "", true)
		y += 54.0
	var lab := ts(12) * 1.3
	var tl_y := maxf(y + 8.0 + lab, 540.0)
	var tl_h := minf(40.0, 640.0 - lab - 4.0 - tl_y)
	if tl_h >= 16.0:
		_draw_timeline(Rect2(300, tl_y, 680, tl_h))
		y = tl_y + tl_h + lab + 6.0
	# 指紋放在時間軸下面；大字時放不下就不畫（它是驗證用的小字，第三輪 T4）
	var fp_y := maxf(y, 618.0)
	if fp_y + ts(11) * 1.3 <= 646.0:
		_text(Vector2(640, fp_y), L.t("fingerprint", [sim.fingerprint.substr(0, 12)]), ts(11), Color(1, 1, 1, 0.35), true, false, 760)
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
	if watch_mode:
		bs.clear()   # 看對戰代碼：不接正式對局的「下一局」（Codex S5 #2）

	if mode == Mode.VS_AI and last_armies.size() == 2 and not watch_mode:
		bs.append([L.t("menu_review"), func(): _open_review()])   # 覆盤（第三輪 F1）
	bs.append([L.t("replay"), func(): _replay()])
	bs.append([L.t("menu"), func(): _go_title()])
	var bw2 := 200.0 if bs.size() <= 3 else 176.0
	var x := 640.0 - (bs.size() * (bw2 + 12) - 12) / 2.0
	for i in bs.size():
		_btn(Rect2(x + i * (bw2 + 12), 648, bw2, 46), bs[i][0], bs[i][1], true, i == 0)


## 戰局時間軸（第三輪 U5）：藍紅拉鋸色帶（每 tick 的戰力差）＋關鍵事件點（首次衝鋒／背刺／頂住、領先交換、最後時刻、勝負鎖定）。
func _draw_timeline(r: Rect2) -> void:
	if sim == null or sim.power_log.is_empty():
		return
	var n: int = sim.power_log.size()
	var tot := float(sim.budget * 1000)
	var mid := r.position.y + r.size.y / 2.0
	draw_rect(r, Color(0, 0, 0, 0.35))
	var cols := int(r.size.x / 2.0)
	for i in cols:
		var t := mini(n - 1, i * n / cols)
		var d: float = clampf(float(sim.power_log[t]) / tot * 2.0, -1.0, 1.0)
		var h := absf(d) * r.size.y / 2.0
		var c := Art.team_color(0 if d > 0 else 1, cbm())
		draw_rect(Rect2(r.position.x + i * 2.0, mid - (h if d > 0 else 0.0), 2.0, h), Color(c, 0.85))
	draw_line(Vector2(r.position.x, mid), Vector2(r.end.x, mid), Color(1, 1, 1, 0.3), 1.0)
	var marks: Array = []
	for m in battle_marks:
		marks.append([int(m["tick"]), str(m["kind"]), int(m["team"])])
	for t2 in report.get("leads", []):
		marks.append([int(t2), "lead", -1])
	var lock_t := int(report.get("lock_sec", 0)) * 20
	if lock_t > 0 and sim.winner >= 0:
		marks.append([lock_t, "lock", sim.winner])
	marks.sort()
	var last_lx := -999.0
	var last_ux := -999.0
	for mk in marks:
		var x := r.position.x + r.size.x * clampf(float(mk[0]) / n, 0.0, 1.0)
		var mc := ACCENT if mk[2] < 0 else Art.team_color(mk[2], cbm())
		draw_colored_polygon(PackedVector2Array([Vector2(x, r.position.y - 7), Vector2(x + 5, r.position.y - 2), Vector2(x, r.position.y + 3), Vector2(x - 5, r.position.y - 2)]), mc)
		draw_line(Vector2(x, r.position.y + 3), Vector2(x, r.end.y), Color(mc, 0.5), 1.0)
		var lbl := "%s %ds" % [L.t("tl_" + mk[1]), mk[0] / 20]
		var lw := font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, ts(12)).x
		# 標籤上下兩排交錯：先放下排，放不下改上排（菱形上方），兩排都放不下才省略（Antigravity S3）
		if x - lw / 2.0 > last_lx + 6.0:
			_text(Vector2(x, r.end.y + 2), lbl, ts(12), Color(mc, 0.95), true)
			last_lx = x + lw / 2.0
		elif x - lw / 2.0 > last_ux + 6.0:
			_text(Vector2(x, r.position.y - 9 - ts(12) * 1.25), lbl, ts(12), Color(mc, 0.95), true)
			last_ux = x + lw / 2.0
		else:
			# 兩排都放不下：只寫秒數，不留沒字的孤點（Antigravity S3 第 2 輪）
			var short := "%ds" % (mk[0] / 20)
			var sw := font.get_string_size(short, HORIZONTAL_ALIGNMENT_LEFT, -1, ts(12)).x
			if x - sw / 2.0 > last_lx + 4.0:
				_text(Vector2(x, r.end.y + 2), short, ts(12), Color(mc, 0.95), true)
				last_lx = x + sw / 2.0
			elif x - sw / 2.0 > last_ux + 4.0:
				_text(Vector2(x, r.position.y - 9 - ts(12) * 1.25), short, ts(12), Color(mc, 0.95), true)
				last_ux = x + sw / 2.0


## 動態判詞：用輸出最高的兵種、結束方式、懸念類型組一句話。
func _verdict(w: int) -> String:
	var dealt: Array = report["dealt"][w]
	var top := 0
	for t in D.COUNT:
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
	# 重播只看不算：比分、進度、成就、日誌都不動（第三輪 A1，原本會重複結算）
	if play_kind == "review" and rv_last.size() == 2:
		_begin_battle(rv_last[0].copy(), rv_last[1].copy(), "review")
		return
	_begin_battle(last_armies[0].copy(), last_armies[1].copy(), "replay")


func _next_puzzle() -> void:
	var list: Array = PZ.tutorials() if mode == Mode.TUTORIAL else (PZ.new_puzzles() if PZ.get_puzzle(puzzle_id).has("unit") else PZ.puzzles())
	for i in list.size():
		if list[i]["id"] == puzzle_id and i + 1 < list.size():
			var nx: Dictionary = list[i + 1]
			if nx.has("unit") and RS.games_to_unlock(int(nx["unit"]), int(Save.data.get("stats", {}).get("games", 0)), OS.has_feature("demo")) != 0:
				break   # 下一關的新兵還沒解鎖
			puzzle_id = nx["id"]
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


## 啟動檢查（第三輪 T1）：從正式入口啟動、畫幾幀標題、開關一次圖鑑，印 BOOTOK 後結束。不碰玩家存檔、不碰 Steam。
func _boot_check() -> void:
	for i in 5:
		await get_tree().process_frame
	_open_codex(0)
	for i in 3:
		await get_tree().process_frame
	overlay = ""
	await get_tree().process_frame
	print("BOOTOK state=%d" % state)
	get_tree().quit(0)


## ── 輸入命令佇列的執行端（第三輪 A2；S8 從 ui_base 移下來：基底不再用空函式呼叫上層）──
func _process_cmds() -> int:
	var done := 0
	_update_gen()
	var q := _cmds
	_cmds = []
	for c in q:
		if c["gen"] != _gen:
			# 畫面已經換了：丟掉。但「放開滑鼠」一定要清掉拖曳／塗兵狀態（Codex S1 #2）
			if c["kind"] == "mb" and not c["data"]["pressed"]:
				_mb_release_cleanup()
			continue
		if c["kind"] == "click":
			done += _do_click(c["data"])
		elif c["kind"] == "mb":
			# 滑鼠按鍵（擺放、拖曳、移除）也走同一個佇列，和鍵盤選兵的先後順序一致（Codex S1 #2）
			_mb_cmd(c["data"])
			done += 1
		elif c["kind"] == "paint":
			_paint_cmd(c["data"])
		elif c["kind"] == "key":
			_key(int(c["data"]))
			done += 1
		_update_gen()
	return done


## 點擊：只對這個畫面世代畫出來的按鈕有效。回傳執行了幾個。
func _do_click(p: Vector2) -> int:
	if _btns_gen != _gen:
		return 0
	for i in _btns.size():
		var b: Dictionary = _btns[i]
		if b["r"].has_point(p):
			if b["en"]:
				_focus = i
				if sfx != null:
					sfx.play("ui_click")
				b["cb"].call()
				return 1
			return 0
	return 0
