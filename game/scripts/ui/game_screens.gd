extends "res://scripts/ui/free_place.gd"
## 狀態機、模式、輸入、擺放、標題、選單、設定、結果、成就。

func _ready() -> void:
	on_battle_finished = _finish_battle
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot=") or a.begins_with("--steam-test=") or a.begins_with("--perf=") or a == "--boot-check" or a.begins_with("--mem-check="):
			Save.prefix = "shot_"   # 不讀、不寫玩家真正的存檔
		elif a == "--self-check":
			Save.prefix = "smoke_"
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
	_load_fonts()
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
	if "--self-check" in OS.get_cmdline_user_args():
		_self_check.call_deferred()
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


func _new_demo() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = rng.randi()
	demo = Sim.new(AI.build(0, 100, r)["army"], AI.build(1, 100, r)["army"])
	demo.fast = true
	demo_acc = 0.0


func _start_mode(m: int) -> void:
	free_intro = false
	watch_mode = false
	mode = m
	if m != Mode.VS_AI and m != Mode.DUEL:
		rules = null      # 第五輪：只有對 AI、雙人吃大廳規則；遠征、教學、殘局固定
	elif rules != null:
		difficulty = rules.ai_level
		duel_rule = rules.place_rule
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
	pending_cell = Vector2i(-1, -1)
	ai_prebuilt = false
	_fp_reset()
	# 第一次進擺放畫面自動打開操作說明（第五輪：說明從頂部移到「?」）
	if not bool(Save.data.get("seen_place_help", false)) and (mode == Mode.VS_AI or mode == Mode.DUEL) and shot_dir == "":
		show_place_help = true
		Save.data["seen_place_help"] = true
	fx.clear()
	dying.clear()
	zoom = 1.0
	tp = null
	blind_phase = 0
	_focus = 0
	var keep_ok: bool = keep_blue and not armies.is_empty() and (rules == null or rules.keep_formation)
	var blue_keep = armies[0].copy() if keep_ok else null
	armies = [Army.new(0, 100), Army.new(1, 100)]
	if rules != null and (mode == Mode.VS_AI or mode == Mode.DUEL):
		armies[0].apply_rules(rules, 0)
		armies[1].apply_rules(rules, 1)
	match mode:
		Mode.VS_AI:
			if blue_keep != null:
				armies[0] = blue_keep
			if rules != null and rules.fullfield == 2:
				# 第六輪：對 AI 明牌全場——AI 先在自己半場擺好並公開，你在全場離敵兵 1.5 格外擺
				_build_ai()
				ai_prebuilt = true
				armies[0].enemy_pos = []
				for u in armies[1].units:
					armies[0].enemy_pos.append(armies[1].pos_of(u))
				var keep: Array = armies[0].units.duplicate(true)
				armies[0].units = []
				for u in keep:
					var pp: Vector2i = armies[0].pos_of(u)
					armies[0].place_xy(int(u["type"]), pp.x, pp.y)   # 保留的陣型和新的明牌陣衝突的就拿掉
		Mode.DUEL:
			if duel_rule != "blind":
				tp = TP.new(armies[0], armies[1], (round_no + 1) % 2, duel_rule, rules)
				if rules == null:
					tp.armies[0].pool = _pool()
					tp.armies[1].pool = _pool()
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
			var e := AIT.build_full(1, r, lvl, gauntlet_prev, _pool())
			e.budget = 100 + 5 * (gauntlet_stage - 1)
			var guard := 0
			while e.can_afford_any() and guard < 20:
				guard += 1
				var t := AIT.choose_type(e, gauntlet_prev, e.left(), r, lvl, _pool())
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
	if mode == Mode.VS_AI and not ai_prebuilt:
		_build_ai()
	last_player_formation = armies[0].units.duplicate(true)
	_begin_battle(armies[0].copy(), armies[1].copy())


## 組 AI 的陣型（第六輪：明牌全場時在擺放開始就組好）。
func _build_ai() -> void:
	if true:
		var r := RandomNumberGenerator.new()
		r.seed = rng.randi()
		var p1: int = rules.pool_of(1) if rules != null else _pool()
		match difficulty:
			0:
				armies[1] = AIT.build_full(1, r, 0, [], p1, rules)
				ai_name = L.t("diff_easy")
			1:
				var res = AI.build(1, rules.budget_of(1) if rules != null else 100, r, -1, p1, rules)
				armies[1] = res["army"]
				ai_name = "%s・%s" % [L.t("diff_normal"), res["name"]]
			_:
				armies[1] = _hard_ai(r)
				ai_name = L.t("diff_hard")


## 困難 AI：第 1 局沒有資訊，用會讀對方的落子 AI 自己組；之後讀你上一局的陣型，
## 先查離線反制庫（組成最接近的原型），查不到就用啟發式反制。不偷看你這一局。
func _hard_ai(r: RandomNumberGenerator) -> Army:
	# 第四輪：候選陣型各和你上一局的陣型模擬一場，挑最好的（scripts/core/hard_ai.gd）
	var known: Array = last_player_formation if round_no > 1 else []
	return HardAI.build(known, _counter_lib(), r, rules.pool_of(1) if rules != null else _pool(), rules)


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
	result_tab = 0
	_focus = 0
	slow_left = 0.0
	zoom_target = 1.0
	var w: int = sim.winner
	var eff: Dictionary = PLAY_EFFECTS[play_kind]
	if eff["series"]:
		if w >= 0:
			wins[w] += 1
		series_over = series_done(wins, round_no, rules)
	_build_report()
	if mode == Mode.DUEL:
		sfx.play("win" if w >= 0 else "lose")
	else:
		sfx.play("win" if w == 0 else "lose")
	if eff["progress"]:
		_progress_and_achievements()
	if eff["log"]:
		Save.playtest_log(_pt_entry(0))


## 系列結束了沒（第五輪：局數可調；沒有規則＝1.3.0 的先兩勝或打滿 5 局）。給測試直接驗。
static func series_done(w: Array, rn: int, r) -> bool:
	var need: int = r.wins_needed() if r != null else 2
	var cap_r: int = r.max_rounds() if r != null else 5
	return int(w[0]) >= need or int(w[1]) >= need or rn >= cap_r


## 第七輪 S7：每次啟動一個 session、每局一個 game；彙整工具靠這兩個去重（評分和對戰是兩行，不能重複算局數）。
var pt_session := str(Time.get_unix_time_from_system()) + "-" + str(randi())
var pt_game := 0

func _pt_entry(rating: int) -> Dictionary:
	if rating == 0:
		pt_game += 1
	return {"v": 2, "session": pt_session, "game": pt_game, "code": BattleCode.encode(last_armies[0], last_armies[1], battle_rules),
		"event": "rating" if rating > 0 else "battle", "mode": _mode_label(), "round": round_no, "winner": sim.winner,
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
	if sim.judge == 2:
		eps = 10   # 讓子：用各自預算的比例（每千分之十＝1%）
	for t in sim.power_log.size():
		var d: int = sim.power_log[t] if sim.judge == 1 else sim.diff_permille(t)
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
	# 第五輪：紀錄分欄。平衡認證的規則（或沒有規則的模式）＝標準戰績；其他自訂規則記在自訂戰績；沙盒什麼都不記。
	var kind := "duel" if mode == Mode.DUEL else "ai"
	var badge: String = Presets.badge(rules, kind) if rules != null else Presets.BADGE_CERT
	if badge == Presets.BADGE_LAB:
		_save()
		return
	var standard: bool = rules == null or Presets.is_standard_record(rules, kind)
	if free_intro:
		Save.data["free_intro_done"] = true
		free_intro = false
	var ug_before := int(Save.data.get("unlock_games", 0))
	Save.data["unlock_games"] = ug_before + 1
	# 新兵種解鎖（第四輪 §9）：提示並指向殘局裡的新兵試玩（第五輪：看解鎖累計場數）
	if not bool(Save.s("unlock_all")):
		for nt in RS.newly_unlocked(ug_before, ug_before + 1, OS.has_feature("demo")):
			ach_queue.append(L.t("unit_unlocked", [L.t("unit_%d" % nt)]))
	var me_won := w == 0 or (mode == Mode.DUEL and w >= 0)
	var stat_key := "stats" if standard else "custom_stats"
	var st: Dictionary = Save.data.get(stat_key, {"wins": 0, "games": 0})
	st["games"] = int(st.get("games", 0)) + 1
	if w == 0 and mode != Mode.DUEL:
		st["wins"] = int(st.get("wins", 0)) + 1
	Save.data[stat_key] = st
	if not standard:
		# 自訂規則專屬成就（標準成就只看標準局）
		if me_won and mode == Mode.VS_AI and w == 0:
			if rules.budget_of(0) <= 50:
				_ach("CUSTOM_LOWGOLD")
			if rules.budget_of(0) < rules.budget_of(1):
				_ach("CUSTOM_UNDERDOG")
		if me_won and rules.unit_cap >= 36:
			_ach("CUSTOM_BIG")
		_save()
		return
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
## 卡列要顯示哪些兵種（第五輪 §4.4）：只放這局用得到的兵。
## 自訂規則：卡池；教學／殘局：關卡允許的；遠征與沒有規則的模式：全部（未解鎖的上鎖，提示還要幾場）。
func _card_types() -> Array:
	var out: Array = []
	for t in D.COUNT:
		if mode == Mode.TUTORIAL or mode == Mode.PUZZLE:
			if _allowed(t):
				out.append(t)
		elif rules != null and (mode == Mode.VS_AI or mode == Mode.DUEL):
			if RuleSet.has(_cur_army().pool, t):
				out.append(t)
		else:
			out.append(t)
	return out


func _card_rect(i: int) -> Rect2:
	var types := _card_types()
	var k := types.find(i)
	if k < 0:
		return Rect2()
	var n := types.size()
	var w := minf(CARD_W * 1.5, (860.0 - CARD_GAP * (n - 1)) / n)   # 卡少時卡片變大（最寬 120）
	return Rect2(CARD_X0 + k * (w + CARD_GAP), CARD_Y, w, CARD_H)


## 兵種卡右下角的「?」：開圖鑑到這個兵種（第二輪方案 R3）。第五輪：點擊框 32px。
func _card_help_rect(i: int) -> Rect2:
	var r := _card_rect(i)
	if not r.has_area():
		return Rect2()
	return Rect2(r.end.x - 38, r.end.y - 38, 36, 36)


func _card_at(p: Vector2) -> int:
	for i in _card_types():
		if _card_rect(i).has_point(p):
			return i
	return -1


## 這一場開放幾種兵（第四輪 §9）：朋友對戰看「兵種」設定；對 AI、遠征看解鎖進度（也可選經典 5 種）；教學與殘局由關卡限制。
func _ntypes() -> int:
	var games := _unlock_games()
	var classic := str(Save.s("roster")) == "classic"
	var kind := "all"
	if mode == Mode.DUEL:
		kind = "duel"
	elif mode == Mode.VS_AI or mode == Mode.GAUNTLET:
		kind = "ai"
	return RS.ntypes_for(kind, games, classic, OS.has_feature("demo"))


## 第五輪：這一場的卡池遮罩（R1 前＝前 N 種）。
func _pool() -> int:
	if rules != null:
		return rules.pool_of(0)
	return RuleSet.prefix_pool(_ntypes())


func _allowed(t: int) -> bool:
	if rules != null and (mode == Mode.VS_AI or mode == Mode.DUEL):
		return RuleSet.has(_cur_army().pool, t)
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
	if why == Army.E_ZONE:
		return L.t("err_zone")
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
			# 第五輪防手滑（Antigravity 第二輪）：輪流落子時先點一下出現預覽，再點同一格才落子；設定可關。擺下仍不能收回。
			if bool(Save.s("confirm_place")) and pending_cell != c:
				pending_cell = c
				sfx.play("ui_click")
				return
			pending_cell = Vector2i(-1, -1)
			tp.place(selected, c.x, c.y)
		else:
			_cur_army().place(selected, c.x, c.y)
		show_place_help = false
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
	if _cur_army().remove_at(c.x, c.y):
		sfx.play("ui_click")


var keys_capture := ""   # 第七輪 K1：正在改哪個按鍵（"kb:start"／"pad:place"）

func _keys_input(ev: InputEvent) -> bool:
	if keys_capture == "":
		return false
	var part := keys_capture.split(":")
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.keycode != KEY_ESCAPE and part[0] == "kb":
			if not Keymap.can_bind_key(ev.keycode):
				_toast(L.t("keys_reserved"), true)
				return true
			Save.settings["keys"] = Keymap.rebind(Keymap.ACTIONS, Save.s("keys"), part[1], ev.keycode)
			Save.save_settings()
		keys_capture = ""
		return true
	if ev is InputEventJoypadButton and ev.pressed and part[0] == "pad":
		Save.settings["pad"] = Keymap.rebind(Keymap.PAD_ACTIONS, Save.s("pad"), part[1], ev.button_index)
		Save.save_settings()
		keys_capture = ""
		return true
	return ev is InputEventKey or ev is InputEventJoypadButton


func _draw_keys() -> void:
	_panel(Rect2(190, 60, 900, 680))
	_text(Vector2(640, 70), L.t("keys_title"), tz("H1"), Color.WHITE, true, true)
	var y0 := 140.0
	_text(Vector2(240, y0), L.t("keys_kb"), tz("B"), ACCENT, false, true)
	_text(Vector2(690, y0), L.t("keys_pad"), tz("B"), ACCENT, false, true)
	y0 += tz("B") * 1.6
	var kt: Dictionary = Save.s("keys")
	var pt: Dictionary = Save.s("pad")
	for i in Keymap.ACTIONS.size():
		var act: String = Keymap.ACTIONS[i][0]
		var y := y0 + i * 50
		_text(Vector2(240, y + 8), L.t("key_" + act), tz("S"), Color.WHITE, false, false, 200)
		var cap := keys_capture == "kb:" + act
		_btn(Rect2(450, y, 170, 42), "…" if cap else Keymap.key_name(kt, act), func(): keys_capture = "kb:" + act)
	for i2 in Keymap.PAD_ACTIONS.size():
		var act2: String = Keymap.PAD_ACTIONS[i2][0]
		var y2 := y0 + i2 * 50
		_text(Vector2(690, y2 + 8), L.t("key_" + act2), tz("S"), Color.WHITE, false, false, 200)
		var cap2 := keys_capture == "pad:" + act2
		_btn(Rect2(900, y2, 150, 42), "…" if cap2 else Keymap.pad_name(pt, act2), func(): keys_capture = "pad:" + act2)
	if keys_capture != "":
		_text(Vector2(640, 610), L.t("keys_press"), tz("B"), ACCENT, true, true, 800)
	_btn(Rect2(380, 672, 240, 44), L.t("keys_reset"), func(): Save.settings["keys"] = {}; Save.settings["pad"] = {}; Save.save_settings())
	_btn(Rect2(660, 672, 240, 44), L.t("back"), func(): keys_capture = ""; overlay = "settings")


func _input(ev: InputEvent) -> void:
	if _keys_input(ev):
		return
	if ev is InputEventScreenTouch or ev is InputEventScreenDrag:
		fp_touch = true   # 第六輪：觸控時預覽畫在手指上方
		return
	if ev is InputEventMouseMotion:
		mouse = ev.position
		pad_mode = false
		if ev.device != InputEvent.DEVICE_ID_EMULATION:
			fp_touch = false
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
			var dk: int = Keymap.key_to_default(Save.s("keys"), ev.keycode)
			if dk >= 0:
				_enqueue("key", dk)
		return
	if ev is InputEventJoypadButton:
		var db: int = Keymap.pad_to_default(Save.s("pad"), ev.button_index)
		if db < 0:
			return
		ev = ev.duplicate()
		ev.button_index = db
	if ev is InputEventJoypadButton and _is_free() and overlay != "" and not ev.pressed and ev.button_index in [JOY_BUTTON_A, JOY_BUTTON_X]:
		_fp_abort_drag()   # 覆蓋層開著時放開 A／X：清掉拖曳狀態（Antigravity 實作第 1 輪 #2）
	if ev is InputEventJoypadButton and _is_free() and overlay == "" and ev.button_index in [JOY_BUTTON_A, JOY_BUTTON_X, JOY_BUTTON_B, JOY_BUTTON_Y, JOY_BUTTON_LEFT_STICK, JOY_BUTTON_RIGHT_STICK, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
		pad_mode = true
		_enqueue("padbtn", {"b": ev.button_index, "pressed": ev.pressed})   # 第六輪：自由排兵要知道按下與放開
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
	if _is_free():
		if overlay == "":
			_fp_motion(p)
		return
	if state != St.PLACE or overlay != "" or not painting:
		return
	if _cur_army().team != paint_team:
		painting = false
		return
	var c := _cell_at(p)
	if c.x >= 0 and _cur_army().index_at(c.x, c.y) == -1:
		_try_place(c)


func _mb_release_cleanup() -> void:
	_fp_abort_drag()
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
	if state == St.PLACE and overlay == "" and _fp_mb(d):
		return   # 第六輪：自由排兵處理掉了
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
	if state == St.PLACE and _fp_key(k):
		return
	# 有按鈕焦點的畫面（標題、選單、結果、覆蓋層、戰鬥）：方向鍵移焦點、Enter 按下、Esc 返回
	if state != St.PLACE or overlay != "":
		match k:
			KEY_UP, KEY_LEFT:
				_move_focus(-1)
			KEY_DOWN, KEY_RIGHT:
				_move_focus(1)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if _btns_gen == _gen and _focus >= 0 and _focus < _btns.size() and _btns[_focus]["en"]:   # 按鈕清單要是這個畫面的
					sfx.play("ui_click")
					_btns[_focus]["cb"].call()
			KEY_PAGEUP, KEY_PAGEDOWN:
				if overlay == "codex":
					_scroll_by("left", -160.0 if k == KEY_PAGEUP else 160.0)
			KEY_P, KEY_TAB:
				# 手把 Y 送的是 Tab：戰鬥中＝暫停（第七輪 A6）
				if state == St.BATTLE and overlay == "":
					_toggle_pause()
				elif k == KEY_TAB:
					_move_focus(1)
			KEY_ESCAPE:
				if overlay != "":
					overlay = ""
				elif state == St.BATTLE:
					if play_kind != "official":
						_replay_back()   # 第七輪 A9：重播時 Esc＝返回
					else:
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
	_rv_poll()
	_settings_hover()
	var _t0 := Time.get_ticks_usec()
	_process_inner(delta)
	perf_proc_us = Time.get_ticks_usec() - _t0

## 搖桿連發（第三輪 A2）：超過 0.6 才算推、低於 0.35 才算放開（遲滯）；推下立刻一次，0.35 秒後每 0.12 秒一次。
var stick := {JOY_AXIS_LEFT_X: 0.0, JOY_AXIS_LEFT_Y: 0.0}
var _stick_dir := Vector2i.ZERO
var _stick_t := 0.0

func _stick_repeat(delta: float) -> void:
	if _is_free() and overlay == "":
		_fp_pad_process(delta, Vector2(stick[JOY_AXIS_LEFT_X], stick[JOY_AXIS_LEFT_Y]))   # 第六輪：平滑游標
		return
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
	if removed_banner_t > 0.0:
		removed_banner_t -= delta
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
	probe_btns.clear()
	probe_ctrls.clear()
	_probe_ui = false
	draw_rect(Rect2(0, 0, 1280, 800), Color("#1b2a1f"))
	var cam := Transform2D.IDENTITY
	if state == St.BATTLE or state == St.RESULT:
		var off := Vector2.ZERO
		if shake > 0 and _fx_on("shake"):
			off = Vector2(sin(time * 90) * 2, cos(time * 77) * 2)
		var w := clampf((zoom - 1.0) / 0.5, 0.0, 1.0)
		var c := (ORIGIN + FIELD / 2).lerp(zoom_center, w)
		var half := Vector2(640, 388) / zoom
		var lo := ORIGIN + half - Vector2(60, 100)
		var hi := ORIGIN + FIELD - half + Vector2(60, 100)
		c = Vector2(clampf(c.x, minf(lo.x, hi.x), maxf(lo.x, hi.x)), clampf(c.y, minf(lo.y, hi.y), maxf(lo.y, hi.y)))
		cam = Transform2D(0, Vector2(zoom, zoom), 0, Vector2(640, 388) - c * zoom + off)
	if state == St.TITLE:
		# 第七輪 D4：示範戰場縮小放右邊，不被左側面板壓到
		cam = Transform2D(0, Vector2(0.72, 0.72), 0, Vector2(1270.0 - (ORIGIN.x + FIELD.x) * 0.72, 400.0 - (ORIGIN.y + FIELD.y / 2.0) * 0.72))
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
		if _is_free():
			_fp_draw_zones()   # 第六輪：自由排兵
			_fp_draw()
		else:
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
			_draw_frenzy_edge()
			_draw_start_cue()
			_draw_battle_report()
			_draw_unit_info()
			if skip_busy:
				_draw_busy(roundi(view.tick * 100.0 / maxf(1.0, view.max_ticks)))
			elif seek_target >= 0:
				_draw_busy(roundi(sim.tick * 100.0 / maxf(1.0, seek_target)))
		St.RESULT:
			_draw_battle_hud()
			_draw_result()
	_draw_clutch_banner()
	_draw_overlay()
	_draw_pad_footer()
	if toast_t > 0:
		var a := minf(1.0, toast_t * 2)
		var tw := font.get_string_size(toast, HORIZONTAL_ALIGNMENT_LEFT, -1, ts(20)).x + 40
		var ty := 40.0 if overlay != "" else 600.0   # 覆蓋層開著時放上面；平常放在兵種提示條（y 654）上面（第四輪 Antigravity）
		if overlay == "" and _is_free():
			ty = 50.0   # 第六輪：自由擺放整個戰場都可能有兵，提示改蓋在上方的兵種說明條（Codex 實作第 3 輪 #2）
		draw_rect(Rect2(640 - tw / 2, ty, tw, 44), Color(0, 0, 0, 0.72 * a))
		_text(Vector2(640, ty + 6), toast, ts(20), Color(1, 0.88, 0.5, a), true)
	if _focus >= _btns.size():
		_focus = 0
	_btns_gen = _gen


## 看不到的那一邊：迷霧、問號旗、提示（第七輪：格子與自由共用）。
func _draw_hide_fog(hide_side: int) -> void:
	var cols := 6.0
	if _is_free():
		cols = float(rules.depth) / 1000.0
	var x0 := 16.0 - cols if hide_side == 1 else 0.0
	# 迷霧（R6）：深藍紫半透明＋飄動的雲＋發光紅問號旗，格線仍透出來
	var mr := Rect2(ORIGIN + Vector2(x0 * CS, 0), Vector2(cols * CS, FIELD.y))
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
	# 第七輪 A1：同一系列第 2 局起，留上一局敵陣殘影當參考（對手這局可能換陣）
	if mode == Mode.VS_AI and round_no > 1 and last_armies.size() == 2:
		for gu in last_armies[1].units:
			var gw: Vector2i = Army.pos_of(gu)
			_unit(ORIGIN + Vector2(gw) * CS / 1000.0, int(gu["type"]), 1, -1.0, 0.0, 0.0, 0.0, 0.28, 0.0, 1.0)
	var msg := L.t("ai_hidden") if mode == Mode.VS_AI else L.t("enemy_hidden")
	_text(ORIGIN + Vector2((x0 + cols / 2.0) * CS, FIELD.y / 2 - 10), msg, ts(22), Color(1, 1, 1, 0.85), true, true, cols * CS - 20)
	if mode == Mode.VS_AI:
		# AI 的難度與性格（第三輪 U3）：不洩漏陣型
		_text(ORIGIN + Vector2((x0 + cols / 2.0) * CS, FIELD.y / 2 + 70), L.t("ai_trait_%d" % difficulty), ts(15), Color(1, 0.85, 0.6, 0.8), true, false, cols * CS - 30)


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
		Art.unit(self, mouse + Vector2(0, 24), dragging_type, _cur_army().team, 1.0, 0.0, 0.0, 0.0, 0.75, time)
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
				draw_arc(p, br0, 0, TAU, 32, Color(1, 0.3, 0.25, 0.85), 2.5, true)
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
				items = [["＋", L.t("pk_move")], ["A", L.t("pk_select")]]
			St.BATTLE:
				items = [["A", L.t("pk_select")], ["B", L.t("skip")]]
			St.RESULT:
				items = [["＋", L.t("pk_move")], ["A", L.t("pk_select")], ["B", L.t("menu")]]
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


# ── 標題 ──
## 新手：還沒玩過任何一局、教學也沒碰過。
func _is_new_player() -> bool:
	return int(Save.data.get("tutorial", 0)) == 0 and int(Save.data.get("unlock_games", 0)) == 0 and int(Save.data.get("stats", {}).get("games", 0)) == 0

func _start_free_intro() -> void:
	overlay = ""
	lobby_kind = "ai"
	lobby_r = Presets.make("standard", "ai", _lobby_unlocked())
	lobby_r.rounds = 1
	lobby_r.ai_level = 0
	rules = lobby_r.copy()
	difficulty = 0
	_start_mode(Mode.VS_AI)
	free_intro = true
	free_intro_moved = false


func _draw_save_notice() -> void:
	var msg := ""
	if Save.data_locked:
		msg = L.t("save_locked")
	elif Save.data_source == "bak":
		msg = L.t("save_from_backup")
	elif Save.has_unsaved():
		msg = L.t("save_failed")
	if msg == "":
		return
	var h := text_h(msg, tz("S"), 760) + 14
	draw_rect(Rect2(490, 8, 780, h), Color(0.35, 0.12, 0.08, 0.92))
	_text(Vector2(500, 12 + tz("S")), msg, tz("S"), Color("#ffe8c8"), false, false, 760)


func _draw_title() -> void:
	draw_rect(Rect2(0, 0, 1280, 800), Color(0.05, 0.06, 0.1, 0.18))
	if overlay != "":
		return
	_draw_save_notice()
	# 第七輪 D4：右下角色群像
	for i in D.COUNT:
		var gp := Vector2(560.0 + i * 72.0, 720.0 + (i % 2) * 22.0)
		Art.unit(self, gp, i, i % 2, 1.0 if i % 2 == 0 else -1.0, 0.0, 0.0, 0.0, 1.0, time + i, 1.25, cbm())
	var bob := sin(time * 1.5) * 4
	# 第五輪 §4.4：主選單收成左側一塊面板，背景的自動對決露出來；標題用標題字
	var dk := Color(0.05, 0.06, 0.1, 0.78)
	var cl := Color(0.05, 0.06, 0.1, 0.0)
	var pr := Rect2(0, 0, 470, 800)
	draw_polygon(PackedVector2Array([pr.position, Vector2(pr.end.x, 0), Vector2(pr.end.x, 800), Vector2(0, 800)]), PackedColorArray([dk, dk, dk, dk]))
	draw_polygon(PackedVector2Array([Vector2(pr.end.x, 0), Vector2(pr.end.x + 120, 0), Vector2(pr.end.x + 120, 800), Vector2(pr.end.x, 800)]), PackedColorArray([dk, cl, cl, dk]))
	var tsz := tcap(tz("DX"), 92)
	var tt: String = L.t("title")
	var tf: Font = font_title if (font_title != null and not bool(Save.s("plain_titles"))) else font_bold
	var tw := tf.get_string_size(tt, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz).x
	if tw > 430.0:
		tsz = int(tsz * 430.0 / tw)   # 第七輪：英文 150% 標題原本超出畫面左邊
		tw = tf.get_string_size(tt, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz).x
	var tp := Vector2(235 - tw / 2, 40 + bob + tsz * 0.85)
	for d in 4:
		draw_string(tf, tp + Vector2(1, 1) * (d + 1) * 1.6, tt, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, Color(0.32, 0.17, 0.04, 0.9))
	draw_string_outline(tf, tp, tt, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, 9, Color("#3a2205"))
	draw_string_outline(tf, tp, tt, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, 5, Color("#b8860b"))
	draw_string(tf, tp, tt, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, Color("#ffe8a3"))
	var ty := 40.0 + tsz * 1.2
	_text(Vector2(235, ty), "No Take-Backs" if L.lang == "zh_TW" else "落子無悔", tz("B"), Color(1, 1, 1, 0.85), true, false, 420)
	ty += tz("B") * 1.4
	_text(Vector2(235, ty), L.t("subtitle"), tz("S"), Color(1, 1, 1, 0.8), true, false, 420)
	ty += text_h(L.t("subtitle"), tz("S"), 420) + 18
	var y0 := maxf(250.0, ty)
	# 第七輪 E7：四顆主玩法有兵種圖示與亮邊；其餘縮小。新手第一次進來，主推教學（A4）
	var fresh := _is_new_player()
	var main := [["menu_tutorial" if fresh else "menu_vs_ai", (func(): _open("tutorial")) if fresh else (func(): _open_lobby("ai")), 0],
		["menu_vs_ai" if fresh else "menu_duel", (func(): _open_lobby("ai")) if fresh else (func(): _open_lobby("duel")), 3],
		["menu_duel" if fresh else "menu_gauntlet", (func(): _open_lobby("duel")) if fresh else (func(): _start_mode(Mode.GAUNTLET)), 1],
		["menu_gauntlet" if fresh else "menu_tutorial", (func(): _start_mode(Mode.GAUNTLET)) if fresh else (func(): _open("tutorial")), 4 if fresh else 2]]
	for i in main.size():
		var mr2 := Rect2(70, y0 + i * 60, 330, 52)
		_btn(mr2, "　　" + L.t(main[i][0]), main[i][1], true, i == 0)
		draw_rect(Rect2(mr2.position, Vector2(4, mr2.size.y)), ACCENT if i == 0 else Color(1, 1, 1, 0.35))
		Art.unit(self, mr2.position + Vector2(32, 48), int(main[i][2]), 0, 1.0, 0.0, 0.0, 0.0, 1.0, time, 0.72, cbm())
	if fresh:
		var pulse := 0.5 + 0.5 * sin(time * 3.0)
		draw_rect(Rect2(68, y0 - 2, 334, 56), Color(ACCENT, 0.5 + 0.5 * pulse), false, 3.0)
	var y1 := y0 + 4 * 60 + 8
	_btn(Rect2(70, y1, 162, 44), L.t("menu_puzzle"), func(): _open("puzzles"))
	_btn(Rect2(238, y1, 162, 44), L.t("menu_codex"), func(): _open_codex(0))
	var y2 := y1 + 52
	var sys := [["menu_settings", func(): _open("settings")], ["menu_credits", func(): _open("credits")], ["menu_quit", func(): get_tree().quit()]]
	for i in sys.size():
		_btn(Rect2(70 + i * 112, y2, 106, 38), L.t(sys[i][0]), sys[i][1], true, false, Color(0.12, 0.13, 0.18, 0.9))
	_btn(Rect2(70, y2 + 44, 330, 36), L.t("bc_watch"), func(): _watch_battle_code(), true, false, Color(0.12, 0.13, 0.18, 0.9))
	# 底部：解鎖進度＋最佳紀錄
	var n := RS.unlocked_count(_unlock_games(), OS.has_feature("demo"))
	var cap := RS.DEMO_MAX if OS.has_feature("demo") else D.COUNT
	var prog := L.t("unlock_prog", [n, cap])
	if n < cap:
		prog += "　" + L.t("unlock_next", [RS.games_to_unlock(n, _unlock_games(), OS.has_feature("demo")), L.t("unit_%d" % n)])
	_text(Vector2(70, 728), prog, tz("S"), Color(1, 1, 1, 0.8), false, false, 380)
	_text(Vector2(70, 728 + tz("S") * 1.4), "%s　｜　v%s" % [L.t("gauntlet_best", [int(Save.data.get("gauntlet_best", 0))]), D.RULES_VERSION], tz("C"), Color(1, 1, 1, 0.6), false, false, 380)


func _pick_puzzle(id: String, tut: bool) -> void:
	puzzle_id = id
	_start_mode(Mode.TUTORIAL if tut else Mode.PUZZLE)


# ── 覆蓋層 ──
func _draw_overlay() -> void:
	if overlay != "":
		_btns.clear()   # 覆蓋層底下畫面的按鈕不能被點到（例如擺放畫面的開戰、結果頁的按鈕）
		probe_texts.clear()   # 第五輪：底下畫面的字被遮罩蓋住，版面檢查只量覆蓋層本身
		probe_btns.clear()
		probe_ctrls.clear()
		if state == St.TITLE:
			draw_rect(Rect2(0, 0, 1280, 800), Color(0, 0, 0, 0.72))   # 第七輪：標題的示範戰場不透出來
	match overlay:
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
					var left := RS.games_to_unlock(int(pz["unit"]), _unlock_games(), OS.has_feature("demo"))
					if left != 0:
						en = false
						line = "%d. %s（%s）" % [i + 1, name, L.t("locked_demo") if left < 0 else L.t("locked_short", [left])]
				# 第七輪：標籤靠左、讓開左邊的迷你敵陣（原本置中會被縮圖蓋住）
				_btn(r, "", _pick_puzzle.bind(pz["id"], tut), en, false,
					Color(0.15, 0.32, 0.22) if st > 0 else Color(0, 0, 0, 0))
				_probe_btn_label = true
				_probe_btn_rect = r
				_text(r.position + Vector2(64, 8), line, tz("S"), Color.WHITE if en else Color(1, 1, 1, 0.4), false, false, r.size.x - 72)
				_probe_btn_label = false
				# 第七輪 E12：關卡鈕直接看得到預算、可用兵種、星級條件
				if not tut and en:
					var note: String = L.t("puzzle_note", [int(pz["budget"]), int(pz["star3"])])
					_probe_btn_label = true
					_probe_btn_rect = r
					_text(r.position + Vector2(62, r.size.y - tz("C") * 1.25), note, tz("C"), Color(1, 0.9, 0.6, 0.85), false, false, r.size.x - 70)
					_probe_btn_label = false
				# 主角兵種小頭像（R6）：這關第一個可用的兵種
				_mini_formation(Rect2(r.position + Vector2(6, 6), Vector2(52, 56)), pz, en)   # 迷你敵陣縮圖（第三輪 U4）
			if tut:
				# 第七輪 A4：自由排兵入門（畫筆、搬移、開戰），一步一步帶
				var fr := Rect2(280 + (list.size() % 2) * 370, 210 + (list.size() / 2) * 82, 350, 68)
				_btn(fr, ("✓ " if bool(Save.data.get("free_intro_done", false)) else "") + L.t("intro_btn"), func(): _start_free_intro(), true, false,
					Color(0.15, 0.32, 0.22) if bool(Save.data.get("free_intro_done", false)) else Color(0, 0, 0, 0))
			_btn(Rect2(560, 640, 160, 36), L.t("back"), func(): overlay = "")
		"lobby":
			_draw_lobby()
		"settings":
			_draw_settings()
		"keys":
			_draw_keys()
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


## 設定（第五輪 §4.4）：四組分頁＋右側說明欄；多選項用 ◀ ▶；遊戲規則已經搬到規則大廳。
func _settings_rows() -> Array:
	var groups := {
		0: [["set_lang", L.t("lang_name"), func(d): _cycle_setting("lang", ["zh_TW", "en"]); L.lang = Save.s("lang")],
			["set_text", "%d%%" % int(Save.s("text_scale")), func(d): _step_setting("text_scale", [100, 125, 150], d)],
			["set_plain_titles", _onoff("plain_titles"), func(d): _cycle_setting("plain_titles", [false, true])],
			["set_fullscreen", _onoff("fullscreen"), func(d): _cycle_setting("fullscreen", [false, true]); _apply_fullscreen()]],
		1: [["set_music", "%d%%" % int(Save.s("music")), func(d): _step_setting("music", [0, 30, 50, 70, 100], d); sfx.set_volumes(int(Save.s("sfx")), int(Save.s("music")))],
			["set_sfx", "%d%%" % int(Save.s("sfx")), func(d): _step_setting("sfx", [0, 30, 50, 80, 100], d); sfx.set_volumes(int(Save.s("sfx")), int(Save.s("music")))]],
		2: [["set_speed", "%s×" % _fmt_num(float(Save.s("speed"))), func(d): _step_setting("speed", [0.5, 1.0, 2.0], d)],
			["set_confirm", _onoff("confirm_place"), func(d): _cycle_setting("confirm_place", [true, false])],
			["set_unlock_all", _onoff("unlock_all"), func(d): _cycle_setting("unlock_all", [false, true])],
			["set_playtest", _onoff("playtest"), func(d): _cycle_setting("playtest", [false, true])],
			["set_keys", L.t("open_it"), func(d): _open("keys")]],
		3: [["set_cb", _onoff("colorblind"), func(d): _cycle_setting("colorblind", [false, true]); _rebuild_sprites()],
			["set_shake", _onoff("shake"), func(d): _cycle_setting("shake", [true, false])],
			["set_slowmo", _onoff("slowmo"), func(d): _cycle_setting("slowmo", [true, false])],
			["set_flash", _onoff("flash"), func(d): _cycle_setting("flash", [true, false])],
			["set_reduce_fx", _onoff("reduce_fx"), func(d): _cycle_setting("reduce_fx", [false, true])]],
	}
	return groups[settings_tab]


## 滑鼠停在哪一列：輸入狀態，每幀更新一次（第七輪 H7：原本在繪圖時改狀態）。
func _settings_hover() -> void:
	if overlay != "settings":
		return
	var rows := _settings_rows()
	for i in rows.size():
		if Rect2(370, _settings_row_y(i), 520, 52).has_point(mouse):
			settings_item = rows[i][0]


func _settings_row_y(i: int) -> float:
	return 120.0 + i * 66.0


func _draw_settings() -> void:
	_panel(Rect2(140, 50, 1000, 700))
	_text(Vector2(640, 60), L.t("settings_title"), tz("H1"), Color.WHITE, true, true)
	for i in 4:
		_btn(Rect2(170, 120 + i * 60, 180, 50), L.t("set_tab_%d" % i), func(): settings_tab = i; settings_item = "", true, false,
			Color(0.26, 0.33, 0.5) if i == settings_tab else Color(0, 0, 0, 0))
	var rows: Array = _settings_rows()
	for i in rows.size():
		var y := 120 + i * 66
		if i % 2 == 0:
			draw_rect(Rect2(370, y - 6, 524, 64), Color(1, 1, 1, 0.04))   # 第七輪 E11：斑馬底色
		_text(Vector2(380, y + 13), L.t(rows[i][0]), tz("B"), Color.WHITE, false, false, 240)
		var val: String = rows[i][1]
		var cb: Callable = rows[i][2]
		var r := Rect2(620, y, 260, 52)
		_btn(Rect2(r.position, Vector2(48, r.size.y)), "◀", cb.bind(-1))
		var tint := Color(0.16, 0.5, 0.3) if val == L.t("on") else Color(0.13, 0.15, 0.22)
		_btn(Rect2(r.position + Vector2(54, 0), Vector2(r.size.x - 108, r.size.y)), val, cb.bind(1), true, false, tint)
		_btn(Rect2(r.end.x - 48, r.position.y, 48, r.size.y), "▶", cb.bind(1))
		if val.ends_with("%") and rows[i][0] in ["set_music", "set_sfx"]:
			draw_rect(Rect2(r.position.x + 60, y + 44, (r.size.x - 120) * int(val.trim_suffix("%")) / 100.0, 4), ACCENT)
	# 說明欄
	var D0 := Rect2(900, 120, 220, 560)
	draw_rect(D0, Color(0, 0, 0, 0.25))
	var key: String = settings_item if settings_item != "" else rows[0][0]
	_text(D0.position + Vector2(14, 12), L.t(key), tz("B"), ACCENT, false, true, D0.size.x - 28)
	_text(D0.position + Vector2(14, 12 + tz("B") * 1.6), L.t("sd_" + key), tz("S"), Color(1, 1, 1, 0.85), false, false, D0.size.x - 28)
	if bool(Save.s("playtest")) and settings_tab == 2:
		_btn(Rect2(380, 120 + rows.size() * 66, 240, 44), L.t("pt_folder"), func(): OS.shell_open(ProjectSettings.globalize_path("user://")))
	_btn(Rect2(560, 690, 160, 44), L.t("back"), func(): overlay = "")


## ◀ ▶ 往前／往後切換設定值（第五輪）。
func _step_setting(k: String, opts: Array, d: int) -> void:
	var cur = Save.s(k)
	var i := 0
	for j in opts.size():
		if str(opts[j]) == str(cur):
			i = j
	Save.set_setting(k, opts[clampi(i + d, 0, opts.size() - 1)])


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
		var can_load := code != ""
		var note := ""
		if code != "":
			var tmp = _decode_any(code)
			if not tmp is String:
				var cnt := D.zeros()
				for u in tmp.units:
					cnt[u["type"]] += 1
				desc = _comp_desc(cnt)
				if rules != null:
					# 第五輪：預先算這一局的規則下會拿掉幾隻（Codex 實作第 2 輪：載入前就告訴玩家）
					var n_ok := _slot_fit_count(tmp)
					if n_ok == 0:
						can_load = false
						note = L.t("slot_none_fit")
					elif n_ok < tmp.units.size():
						note = L.t("slot_will_drop", [tmp.units.size() - n_ok])
			else:
				can_load = false
		var tag := ""
		if code != "":
			tag = "［%s］" % L.t("lb_deploy_short_free" if code.begins_with("NTB5.") else "lb_deploy_short_grid")   # 存檔格標自由／格子
		var head := "%s　%s%s" % [L.t("slot", [i + 1]), tag, desc]
		_text(Vector2(360, y + 4), head, ts(16), Color.WHITE, false, false, 330)
		if note != "":
			_text(Vector2(360, y + 4 + text_h(head, ts(16), 330)), note, tz("C"), Color("#ffb4a0"), false, false, 330)   # 依組成實際換行後的高度往下排
		_btn(Rect2(700, y, 100, 42), L.t("save"), _slot_save.bind(i))
		_btn(Rect2(810, y, 100, 42), L.t("load"), _slot_load.bind(i), can_load)
	_btn(Rect2(370, 540, 260, 42), L.t("copy_code"), func(): DisplayServer.clipboard_set(armies[0].to_code()); _toast(L.t("code_copied")))
	_btn(Rect2(650, 540, 260, 42), L.t("paste_code"), func(): _paste_code())
	_btn(Rect2(560, 600, 160, 36), L.t("back"), func(): overlay = "")


## 第六輪：解任何陣型代碼（NTB1 格子／NTB5 自由），不套這局的限制；回傳 Army 或錯誤字串。
func _decode_any(code: String):
	var raw := Army.new(armies[0].team, 400)
	raw.unit_cap = 54
	if code.strip_edges().begins_with("NTB5."):
		raw.deploy = "free"
		raw.spacing = 600
		raw.depth = 15800
	var w0 := raw.load_code(code)
	return raw if w0 == "" else w0

## 把一隻（格子或自由座標）放進 keep：自由規則照座標放；格子規則吸附到最近的格子（Antigravity 第二輪：自由陣型也能用在格子）。
func _place_from(keep, u: Dictionary) -> bool:
	var p: Vector2i = Army.pos_of(u)
	if keep.deploy == "free":
		return keep.place_xy(int(u["type"]), Army.quant(p.x), Army.quant(p.y))
	return keep.place(int(u["type"]), clampi(p.x / 1000, 0, 15), clampi(p.y / 1000, 0, 8))

## 這個陣型在這一局的規則下能放上去幾隻（跟 _load_checked 同一套：先戰鬥兵、保留戰鬥兵名額）。
func _slot_fit_count(raw) -> int:
	var keep = armies[0].copy()
	keep.units = []
	keep.guard_combat = true
	var ordered: Array = raw.units.duplicate()
	ordered.sort_custom(func(p, q): return (0 if not D.is_support(int(p["type"])) else 1) < (0 if not D.is_support(int(q["type"])) else 1))
	var n := 0
	for u in ordered:
		if _place_from(keep, u):
			n += 1
	return n


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
	var why := _load_checked(str(slots[i]))
	_toast(L.t("code_loaded") if why == "" else (L.t("code_locked") if why == "locked" else L.t("code_bad")), why != "")
	overlay = ""


func _paste_code() -> void:
	var why := _load_checked(DisplayServer.clipboard_get())
	_toast(L.t("code_loaded") if why == "" else (L.t("code_locked") if why == "locked" else L.t("code_bad")), why != "")
	if why == "":
		overlay = ""


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
	armies[0].units = tmp.units
	fp_sel = []
	return ""


# ── 擺放 HUD ──
func _draw_place_hud() -> void:
	# 第五輪 §4.4：頂部兩行。第一行＝模式／局數（左）、目前在做什麼＋金幣條＋人數（中）、規則徽章（右）；
	# 第二行＝選中兵種的資訊帶（名稱、一句定位、剋／怕頭像），完全在棋盤外，不蓋部署格。
	draw_rect(Rect2(0, 0, 1280, 92), UI_BG)
	draw_line(Vector2(0, 50), Vector2(1280, 50), Color(1, 1, 1, 0.08), 1.0)
	var a = _cur_army()
	var tcol := Art.team_color(a.team, cbm())
	# 左：模式與局數
	var ml := _mode_label()
	if mode == Mode.DUEL:
		ml = L.t("menu_duel")   # 規則細節已經在中間大字，左上只放模式名稱（避免換行）
	_text(Vector2(16, 6), ml, tz("S"), Color(1, 1, 1, 0.75), false, true, 380)
	if mode == Mode.VS_AI or mode == Mode.DUEL:
		_text(Vector2(16, 6 + tz("S") * 1.35), "%s　%s" % [L.t("round", [round_no]), L.t("score", [wins[0], wins[1]])], tz("C"), Color(1, 1, 1, 0.6), false, false, 300)
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
	elif mode == Mode.TUTORIAL or mode == Mode.PUZZLE:
		var pz := PZ.get_puzzle(puzzle_id)
		head = pz["zh"] if L.lang == "zh_TW" else pz["en"]
	elif mode == Mode.GAUNTLET:
		head = L.t("gauntlet_title", [gauntlet_stage])
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
	_text(Vector2(ux, gb.position.y - tz("S") * 0.45), L.t("units_of", [a.count(), a.unit_cap]), tz("S"), Color(1, 1, 1, 0.8), false, true)
	if mode == Mode.DUEL and tp != null and rules != null and rules.handicap:
		_text(Vector2(440, gb.end.y + 2), L.t("hc_both", [rules.budget_of(0), rules.budget_of(1)]), tz("C"), Color(1, 1, 1, 0.6))
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
		var bg := Color(0.17, 0.18, 0.24)
		if i == selected:
			bg = Color(0.26, 0.31, 0.45)
		elif i == hover_card:
			bg = Color(0.21, 0.23, 0.31)
		var opened := _allowed(i)
		draw_rect(r, bg if afford else Color(bg, 0.45))
		draw_rect(r, tcol if i == selected else Color(1, 1, 1, 0.15), false, 2)
		if layout_probe:
			probe_ctrls.append(r)   # 兵卡是控制項：卡上的小字不算「要讀的文字」段數
		# 三層卡：上＝快捷鍵、價錢；中＝全身圖；下＝已擺數量、?
		Art.unit(self, r.position + Vector2(r.size.x / 2, 74), i, a.team, 1.0, 0.0, 0.0, 0.0, (1.0 if afford else 0.45) if opened else 0.25, time, 0.78, cbm())
		var fz := tz("C")
		_text(r.position + Vector2(5, 3), "%d" % ((i + 1) % 10), fz, Color(1, 1, 1, 0.6), false, false, 20)
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
	if _can_edit_existing():
		_btn(Rect2(1012, 746, 120, 44), L.t("clear"), func(): _clear_mine())
	_btn(Rect2(1140, 746, 128, 44), L.t("menu"), func(): _go_title())
	if removed_banner_t > 0.0:
		var bw := _width(removed_banner, tz("B"), true) + 40
		var br := Rect2(640 - bw / 2, 100, bw, tz("B") * 1.8)
		draw_rect(br, Color(0.45, 0.12, 0.12, 0.92))
		draw_rect(br, Color("#ff8a8a"), false, 2.0)
		_text(Vector2(640, br.position.y + tz("B") * 0.35), removed_banner, tz("B"), Color.WHITE, true, true)


## 資訊帶（第五輪 §4.4）：選中／停留的兵種名稱、一句定位、剋／怕頭像（28px 以上），右邊「?」開操作說明。
## 殘局顯示提示與三星條件；遠征顯示還能改幾隻。
func _draw_info_band(R: Rect2, i: int, team: int) -> void:
	draw_rect(R, Color(0, 0, 0, 0.18))
	var y := R.position.y + (R.size.y - tz("S") * 1.1) / 2
	var x := 16.0
	var help := Rect2(R.end.x - 46, R.position.y + 2, 36, 36)
	_btn(help, "?", func(): show_place_help = not show_place_help)
	if mode == Mode.TUTORIAL or mode == Mode.PUZZLE:
		var pz := PZ.get_puzzle(puzzle_id)
		var hint: String = pz["hint_zh"] if L.lang == "zh_TW" else pz["hint_en"]
		if mode == Mode.PUZZLE:
			var st := "　★★ " + L.t("star2_short", [pz["star2"]]) + "　★★★ " + L.t("star3_short", [pz["star3"]])
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
		var left := RS.games_to_unlock(i, _unlock_games(), OS.has_feature("demo"))
		var lock: String = L.t("locked_demo") if left < 0 else (L.t("locked_classic") if left == 0 else L.t("locked_games", [left]))
		_text(Vector2(x, y), lock, tz("S"), Color(1, 1, 1, 0.8))
		_draw_place_help()
		return
	var blurb: String = L.t("blurb_%d" % i)
	var bw := minf(_width(blurb, tz("S")), 470.0)
	_text(Vector2(x, y), blurb, tz("S"), Color(1, 1, 1, 0.85), false, false, 470)
	x += bw + 20
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
		_text(Vector2(x, y), grp[0], tz("S"), grp[2], false, true)
		x += _width(grp[0], tz("S"), true) + 6
		for t in grp[1]:
			if x > help.position.x - 36:
				break
			draw_circle(Vector2(x + 17, R.get_center().y), 17, Color(1, 1, 1, 0.08))
			Art.unit(self, Vector2(x + 17, R.position.y + 39), t, 1 - team, 1.0, 0.0, 0.0, 0.0, 1.0, time, 0.68, cbm())
			x += 36
		x += 14
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
	else:
		if _is_free():
			_fp_push_undo()   # 自由模式：清空可以 Ctrl＋Z 復原
		a.clear()
	fp_sel = []
	_fp_abort_drag()


func _draw_result() -> void:
	# 第五輪 §4.4：結果頁兩層。第一層＝勝負＋一句事實描述＋放大的戰力走勢＋MVP；第二層「詳細數據」＝對比長條、技能徽章、指紋。
	draw_rect(Rect2(0, 0, 1280, 800), Color(0, 0, 0, 0.7))   # 第七輪 E2：整個畫面（含 HUD）壓暗
	var r := Rect2(200, 100, 880, 610)
	draw_rect(r, PANEL)
	draw_rect(r, Color(1, 1, 1, 0.2), false, 2)
	var w: int = sim.winner
	var title := L.t("draw")
	var col := Color.WHITE
	if w >= 0:
		title = L.t("win_team", [L.t("blue") if w == 0 else L.t("red")])
		col = Art.team_color(w, cbm())
	var title_sz := tcap(tz("D"), 64)
	_text(Vector2(640, 104), title, title_sz, col, true, true, 540)
	_btn(Rect2(214, 112, 140, 40), L.t("bc_copy"), func(): _copy_battle_code())   # 對戰代碼（第三輪 F3）
	var mvp = report.get("mvp")
	_btn(Rect2(926, 112, 140, 40), L.t("menu_codex_short"), _open_codex.bind(mvp.type if mvp != null else 0))
	var y := 104.0 + title_sz * 1.25
	if play_kind == "review":
		_text(Vector2(640, y), L.t("review_tag"), tz("C"), ACCENT, true, false, 480)
		y += tz("C") * 1.4
	var reason_key := {"全滅": "reason_wipe", "同時全滅": "reason_bothwipe", "時間到・戰力相當": "reason_time_even",
		"時間到・剩餘戰力較高": "reason_time_power", "有一方沒有兵": "reason_empty"}
	var p0 := roundi(sim.power(0) * 100.0 / (sim.budget_of(0) * 1000))
	var p1 := roundi(sim.power(1) * 100.0 / (sim.budget_of(1) * 1000))
	# 標題區只用左右按鈕之間的寬度（Antigravity 實作第 1 輪：英文 150% 摘要壓到「詳細數據」按鈕）
	var hw := 540.0 if y < 210 else 820.0
	var line1 := "%s・%.1fs　｜　%s" % [L.t(reason_key.get(sim.reason, "draw")), sim.tick / 20.0, L.t("power_left", [p0, p1])]
	_text(Vector2(640, y), line1, tz("S"), Color(1, 1, 1, 0.8), true, false, hw)
	y += text_h(line1, tz("S"), hw) + 6
	if w >= 0:
		hw = 540.0 if y < 210 else 820.0
		_text(Vector2(640, y), _verdict(w), tz("B"), Color.WHITE, true, true, hw)
		y += text_h(_verdict(w), tz("B"), hw, true) + 8
	if result_tab == 0:
		# 戰力走勢（放大）＋最多 3 個關鍵時刻
		var ch := Rect2(250, y + tz("C") * 1.35 * 2 + 4, 780, 100)   # 上方留兩排標記標籤的空間
		var km := _key_marks()
		Charts.momentum(self, ch, sim.power_log2, sim.budget_of(0), sim.budget_of(1), km, sim.tick)
		# 第七輪 A7：點關鍵時刻直接跳重播
		var span := float(maxi(1, sim.power_log2.size() / 2))
		for m in km:
			var mx := ch.position.x + ch.size.x * clampf(float(m["t"]) / maxf(1.0, span - 1), 0.0, 1.0)
			var tt := int(m["t"])
			_btns.append({"r": Rect2(mx - 18, ch.position.y, 36, ch.size.y), "cb": func(): _replay_from(tt), "en": true})
		_text(Vector2(250, ch.end.y + 4), L.t("mom_caption"), tz("C"), Color(1, 1, 1, 0.6), false, false, 780)
		y = ch.end.y + tz("C") * 1.6 + 6
		if mvp != null:
			var mr := Rect2(250, y, 780, 76)
			draw_rect(mr, Color(1, 0.82, 0.3, 0.08))
			draw_rect(mr, Color(1, 0.82, 0.3, 0.35), false, 1.5)
			Art.ring(self, mr.position + Vector2(52, 62), mvp.team, mvp.type, cbm(), 1.1)
			Art.unit(self, mr.position + Vector2(52, 62), mvp.type, mvp.team, -1.0, 0.0, 0.0, 0.0, 1.0, time, 1.1, cbm())
			_text(mr.position + Vector2(100, 10), "MVP　" + L.t("unit_%d" % mvp.type), tz("B"), ACCENT, false, true, 400)
			_text(mr.position + Vector2(100, 10 + tz("B") * 1.4), L.t("mvp_line", [L.t("blue") if mvp.team == 0 else L.t("red"), mvp.dmg_dealt, mvp.kills]), tz("S"), Color(1, 1, 1, 0.85), false, false, 660)
			y = mr.end.y + 10
		# 第七輪 A1：只列事件紀錄裡查得到的事實，不說「因為」（Codex：不宣稱因果）
		var facts := _result_facts()
		for fi in facts.size():
			_text(Vector2(250, y), "・" + facts[fi], tz("S"), Color(1, 1, 1, 0.85), false, false, 780)
			y += text_h(facts[fi], tz("S"), 780) + 2
		if mode == Mode.VS_AI and sim.winner == 1 and play_kind == "official" and last_armies.size() == 2 and not watch_mode:
			_btn(Rect2(800, y - tz("S") * 1.3 - 8, 230, 40), L.t("res_try_review"), func(): _open_review_on_first_loss())
		if (mode == Mode.VS_AI or mode == Mode.DUEL) and not series_over and play_kind == "official":
			var need: int = rules.wins_needed() if rules != null else 2
			_text(Vector2(640, y + 4), L.t("series_now", [round_no, wins[0], wins[1], need]), tz("B"), Color(1, 1, 1, 0.85), true, false, 780)
			y += tz("B") * 1.6
	else:
		_draw_result_details(Rect2(230, y, 820, 640 - y))
		y = 590.0
	_btn(Rect2(926, 160, 140, 40), L.t("res_details") if result_tab == 0 else L.t("res_summary"), func(): result_tab = 1 - result_tab)
	if report.has("stars"):
		var pz := PZ.get_puzzle(puzzle_id)
		var stn := int(report["stars"])
		_text(Vector2(640, y), "★".repeat(stn) + "☆".repeat(3 - stn) + "　" + L.t("star_rules", [pz["star2"], pz["star3"]]), tz("S"), ACCENT, true, false, 820)
		y += tz("S") * 1.5
	if series_over and (mode == Mode.VS_AI or mode == Mode.DUEL):
		var sw := L.t("series_draw") if wins[0] == wins[1] else L.t("series_win", [L.t("blue") if wins[0] > wins[1] else L.t("red"), wins[0], wins[1]])
		_text(Vector2(640, y), L.t("series_end", [sw]), tz("B"), ACCENT, true, true, 820)
		y += tz("B") * 1.5
	if mode == Mode.GAUNTLET:
		var msg := ""
		if w == 0 and gauntlet_stage >= 7:
			msg = L.t("gauntlet_clear")
		elif w != 0:
			msg = L.t("gauntlet_over", [gauntlet_stage - 1])
		if msg != "":
			_text(Vector2(640, y), msg, tz("B"), ACCENT, true, true, 820)
			y += tz("B") * 1.5
	if bool(Save.s("playtest")) and not pt_rated:
		_text(Vector2(214, 160), L.t("pt_rate"), tz("C"), ACCENT, false, false, 200)
		for i in 5:
			_btn(Rect2(214 + i * 36, 160 + tz("C") * 1.4, 32, 32), str(i + 1), _pt_rate.bind(i + 1))
	# 試玩版結尾（第三輪 F5）
	if OS.has_feature("demo") and series_over and play_kind == "official":
		var wr := Rect2(260, minf(y, 588), 760, 52)
		draw_rect(wr, Color(0.35, 0.22, 0.05, 0.95))
		draw_rect(wr, ACCENT, false, 2.0)
		_text(Vector2(276, wr.position.y + 12), L.t("demo_wish"), tz("S"), Color.WHITE, false, true, 480)
		var url: String = SteamApi.STORE_URL
		_btn(Rect2(780, wr.position.y + 6, 230, 40), L.t("demo_wish_btn") if url != "" else L.t("demo_wish_soon"), func(): OS.shell_open(url), url != "", true)
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


## 結果頁的事實列：來源都是 battle_marks（模擬事件），每條都有秒數、哪一方。最多 2 條（結果頁段數上限）。
func _result_facts() -> Array:
	var out: Array = []
	var pri := [EV_DEATH, "charge", "backstab", "breach", "rally_on", "braced"]
	for k in pri:
		if out.size() >= 2:
			break
		for m in battle_marks:
			if str(m["kind"]) == k:
				var side: String = L.t("blue") if int(m["team"]) == 0 else L.t("red")
				out.append([int(m["tick"]), L.t("fact_" + k, [int(m["tick"]) / 20, side])])
				break
	out.sort_custom(func(x, y): return x[0] < y[0])   # 依時間排
	return out.map(func(x): return x[1])

const EV_DEATH := "death"

## 「在覆盤裡試試」：直接開覆盤，選中第一隻陣亡的同種兵（A1）。
func _open_review_on_first_loss() -> void:
	_open_review()
	var dead_type := -1
	for u in sim.units:
		if u.team == 0 and not u.alive:
			dead_type = u.type
			break
	if dead_type < 0:
		return
	for i in rv_army.units.size():
		if int(rv_army.units[i]["type"]) == dead_type:
			if rv_army.deploy == "free":
				rv_fsel = i
			else:
				rv_sel = Vector2i(int(rv_army.units[i]["col"]), int(rv_army.units[i]["row"]))
			return


## 結果頁第二層：中線對比長條（輸出／承傷切換）＋技能徽章（只列有發生的）＋指紋。
func _draw_result_details(R: Rect2) -> void:
	var dealt: Array = report["dealt"]
	var taken: Array = report["taken"]
	var src: Array = dealt if result_metric == 0 else taken
	var rows: Array = []
	for t in report_rows(dealt, taken):
		rows.append({"label": L.t("unit_%d" % t), "b": src[0][t], "r": src[1][t]})
	_text(R.position, L.t("report_by_type"), tz("B"), Color.WHITE, false, true, 210)
	_btn(Rect2(R.position.x + 220, R.position.y - 6, 120, 38), L.t("report_dealt"), func(): result_metric = 0, true, false, Color(0.26, 0.33, 0.5) if result_metric == 0 else Color(0, 0, 0, 0))
	_btn(Rect2(R.position.x + 346, R.position.y - 6, 120, 38), L.t("report_taken"), func(): result_metric = 1, true, false, Color(0.26, 0.33, 0.5) if result_metric == 1 else Color(0, 0, 0, 0))
	var bh := minf(170.0, rows.size() * 34.0)
	Charts.diverging(self, Rect2(R.position.x + 20, R.position.y + 40, R.size.x - 40, bh), rows)
	var y := R.position.y + 50 + bh
	var ek := report_badges(ev_count)
	for tm in 2:
		var tcl := Art.team_color(tm, cbm())
		var x := R.position.x + 20
		_text(Vector2(x, y + 4), "●" if tm == 0 else "◆", tz("S"), tcl, false, true)
		x += 26
		for k in ek:
			var n := int(ev_count.get("%s%d" % [k, tm], 0))
			if n == 0:
				continue
			var lab := "%s %d" % [L.t("ev_short_" + k), n]
			var bw := _width(lab, tz("S"), true) + 16
			var br := Rect2(x, y, bw, tz("S") * 1.7)
			draw_rect(br, Color(tcl, 0.22))
			draw_rect(br, Color(tcl, 0.7), false, 1.5)
			_text(br.position + Vector2(8, tz("S") * 0.3), lab, tz("S"), Color.WHITE, false, true)
			x += bw + 6
		y += tz("S") * 2.1
	_text(Vector2(640, y + 4), L.t("fingerprint", [sim.fingerprint.substr(0, 12)]), tz("C"), Color(1, 1, 1, 0.45), true, false, 760)


## 戰力走勢的標記：最多 3 個，優先「勝負已定」「領先交換」「最後時刻」，再補第一個技能時刻。
func _key_marks() -> Array:
	var out: Array = []
	var lock_t := int(report.get("lock_sec", 0)) * 20
	if lock_t > 0 and sim.winner >= 0:
		out.append({"t": lock_t, "label": "%s %ds" % [L.t("tl_lock"), lock_t / 20]})
	var leads: Array = report.get("leads", [])
	if not leads.is_empty():
		out.append({"t": int(leads[leads.size() - 1]), "label": "%s %ds" % [L.t("tl_lead"), int(leads[leads.size() - 1]) / 20]})
	for m in battle_marks:
		if out.size() >= 3:
			break
		if str(m["kind"]) == "clutch":
			out.append({"t": int(m["tick"]), "label": "%s %ds" % [L.t("tl_clutch"), int(m["tick"]) / 20]})
	for m in battle_marks:
		if out.size() >= 3:
			break
		if str(m["kind"]) != "clutch":
			out.append({"t": int(m["tick"]), "label": "%s %ds" % [L.t("tl_" + str(m["kind"])), int(m["tick"]) / 20]})
	out.sort_custom(func(a, b): return int(a["t"]) < int(b["t"]))
	return out


## 一句描述（第五輪：只講事實、和 MVP 一致，不宣稱因果——Codex 第二輪）。主角＝MVP（勝方傷害最高的那一隻）。
func _verdict(w: int) -> String:
	var mvp = report.get("mvp")
	var side := L.t("blue") if w == 0 else L.t("red")
	var unit := L.t("unit_%d" % mvp.type) if mvp != null else ""
	var dmg: int = mvp.dmg_dealt if mvp != null else 0
	var sus: Dictionary = report["sus"]
	var lock_s := int(report.get("lock_sec", 0))
	if int(sus.get("max_swing_pct", 0)) >= 15:
		return L.t("res_comeback", [side, unit, dmg, sus["max_swing_pct"]])
	if sim.power(w) * 100 / (sim.budget_of(w) * 1000) <= 10:
		return L.t("res_close", [side, unit, dmg, int(sim.tick / 20)])
	if int(sus.get("lock_ratio_permille", 0)) <= 200:
		return L.t("res_rout", [side, unit, dmg])
	return L.t("res_normal", [side, unit, dmg, lock_s])


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
	replay_marks = _key_marks() if not report.is_empty() else []
	_replay_snapshot()
	if play_kind == "review" and rv_last.size() == 2:
		_begin_battle(rv_last[0].copy(), rv_last[1].copy(), "review")
		return
	_begin_battle(last_armies[0].copy(), last_armies[1].copy(), "replay")


func _next_puzzle() -> void:
	var list: Array = PZ.tutorials() if mode == Mode.TUTORIAL else (PZ.new_puzzles() if PZ.get_puzzle(puzzle_id).has("unit") else PZ.puzzles())
	for i in list.size():
		if list[i]["id"] == puzzle_id and i + 1 < list.size():
			var nx: Dictionary = list[i + 1]
			if nx.has("unit") and RS.games_to_unlock(int(nx["unit"]), _unlock_games(), OS.has_feature("demo")) != 0:
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


## 匯出成品自我檢查（第七輪 S3）：tools/export_check.sh 對匯出的 exe 跑，印 SELFCHECK 一行 JSON。
func _self_check() -> void:
	for i in 3:
		await get_tree().process_frame
	var demo := OS.has_feature("demo")
	var out := {"demo": demo, "exported": OS.has_feature("template"), "engine": Engine.get_version_info().string}
	out["strings"] = L.has("title") and L.t("title") != "title"
	out["data"] = FileAccess.file_exists("res://data/puzzles.json") and FileAccess.file_exists("res://data/codex.json") and FileAccess.file_exists("res://data/strings.csv")
	out["fonts"] = font_title != null and font_bold != null
	out["audio"] = sfx != null and sfx.get_child_count() > 0
	out["art"] = grass != null and plants.size() > 0
	Save.data["tutorial"] = 2
	var w: bool = Save.save_data()
	Save.load_all()
	out["save_roundtrip"] = w and int(Save.data["tutorial"]) == 2 and Save.file_prefix().ends_with("demo_") == demo
	var a0 := Army.new(0, 100)
	a0.place(0, 0, 0)
	var a1 := Army.new(1, 100)
	a1.place(0, 15, 0)
	var dec: Dictionary = BattleCode.decode(BattleCode.encode(a0, a1, null))
	out["battle_code"] = dec.get("ok", false)
	out["unit_cap"] = RS.unlocked_count(999, demo) == (RS.DEMO_MAX if demo else D.COUNT)
	# 出貨包不能帶測試與工具；編輯器跑時略過
	out["no_tools"] = not OS.has_feature("template") or (not ResourceLoader.exists("res://tools/golden.gd") and not ResourceLoader.exists("res://tests/run_tests.gd"))
	var good := true
	for k in ["strings", "data", "fonts", "audio", "art", "save_roundtrip", "battle_code", "unit_cap", "no_tools"]:
		good = good and bool(out[k])
	out["ok"] = good
	for suf in ["settings.json", "save.json"]:
		for ext in ["", ".bak"]:
			var fp := "user://%s%s%s" % [Save.file_prefix(), suf, ext]
			if FileAccess.file_exists(fp):
				DirAccess.remove_absolute(fp)
	print("SELFCHECK ", JSON.stringify(out))
	get_tree().quit(0 if good else 1)


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
			elif c["kind"] == "padbtn" and not c["data"]["pressed"]:
				_fp_abort_drag()   # 手把放開 A／X 的事件過期：同樣清掉（Codex 實作第 3 輪 #1）
			continue
		if c["kind"] == "click":
			done += _do_click(c["data"])
		elif c["kind"] == "mb":
			# 滑鼠按鍵（擺放、拖曳、移除）也走同一個佇列，和鍵盤選兵的先後順序一致（Codex S1 #2）
			_mb_cmd(c["data"])
			done += 1
		elif c["kind"] == "paint":
			_paint_cmd(c["data"])
		elif c["kind"] == "padbtn":
			if not _fp_pad_button(int(c["data"]["b"]), bool(c["data"]["pressed"])) and c["data"]["pressed"]:
				var mp := {JOY_BUTTON_START: KEY_SPACE, JOY_BUTTON_B: KEY_ESCAPE}
				if mp.has(int(c["data"]["b"])):
					_key(mp[int(c["data"]["b"])])
			done += 1
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
