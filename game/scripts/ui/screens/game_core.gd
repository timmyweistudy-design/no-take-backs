extends "res://scripts/ui/free_place.gd"
## 由 game_screens.gd 拆出（V9 P1，行為不變）
## 狀態機、模式、輸入、擺放、標題、選單、設定、結果、成就。

## 第七輪 S7：每次啟動一個 session、每局一個 game；彙整工具靠這兩個去重（評分和對戰是兩行，不能重複算局數）。
var pt_session := str(Time.get_unix_time_from_system()) + "-" + str(randi())
var pt_game := 0

var keys_capture := ""   # 第七輪 K1：正在改哪個按鍵（"kb:start"／"pad:place"）

# ───────────────────────── 每幀 ─────────────────────────
## 最小化時 Godot 不繪製，也就沒有垂直同步節流，主迴圈會空轉吃滿一核；降到 10 fps，模擬照常跑（用 delta 累積）。
var _was_minimized := false
## 搖桿連發（第三輪 A2）：超過 0.6 才算推、低於 0.35 才算放開（遲滯）；推下立刻一次，0.35 秒後每 0.12 秒一次。
var stick := {JOY_AXIS_LEFT_X: 0.0, JOY_AXIS_LEFT_Y: 0.0}
var _stick_dir := Vector2i.ZERO
var _stick_t := 0.0

## 結果頁的技能徽章（第四輪）：候選裡雙方合計次數最多的 6 種；不夠 6 種就用經典的預設順序補。支援兵的補血、戰鼓也在候選裡（對支援兵公平）。
const BADGE_KEYS := ["breaker", "charge", "backstab", "braced", "anticav", "counter", "pike_brace", "splash", "breach", "heal", "drum"]
const EV_DEATH := "death"


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
	if mode == Mode.GAUNTLET:
		armies[0].pool = _gauntlet_pool()
		armies[1].pool = _gauntlet_pool()
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
	sfx.play_ambience(str(MapArt.BIOME.get(MapDefs.MAPS[rules.map_id if rules != null and rules.is_free() else 0]["biome"], {}).get("sound", "")))



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



func _ai_pool(r: RandomNumberGenerator) -> int:
	var p1: int = rules.pool_of(1) if rules != null else _pool()
	if rules != null and rules.ai_style != 0:
		p1 = AI.style_pool(p1, rules.ai_style, r)
	return p1

## 第十輪 I4：困難 AI 第二局起要模擬候選陣型，放背景算，畫面不凍住。回傳 true＝已交給背景。
func _build_ai_async() -> bool:
	if not _async_ok() or difficulty != 2 or round_no <= 1 or get("challenge_army") != null:
		return false
	var r := RandomNumberGenerator.new()
	r.seed = rng.randi()
	var p1: int = _ai_pool(r)
	var known: Array = last_player_formation.duplicate(true)
	var lib: Array = _counter_lib()
	var rr = rules.copy() if rules != null else null
	ai_thread = Thread.new()
	ai_thread.start(func(): return HardAI.build(known, lib, r, p1, rr))
	overlay = "ai_busy"
	return true

func _ai_poll() -> void:
	if ai_thread == null or ai_thread.is_alive():
		return
	armies[1] = ai_thread.wait_to_finish()
	ai_thread = null
	ai_name = L.t("diff_hard")
	overlay = ""
	call("_on_start_go")

## 組 AI 的陣型（第六輪：明牌全場時在擺放開始就組好）。
func _build_ai() -> void:
	if get("challenge_army") != null:
		armies[1] = get("challenge_army").copy()     # 挑戰碼：對手就是朋友排好的陣
		ai_name = L.t("ch_name")
		return
	if true:
		var r := RandomNumberGenerator.new()
		r.seed = rng.randi()
		var p1: int = _ai_pool(r)
		match difficulty:
			0:
				armies[1] = AIT.build_full(1, r, 0, [], p1, rules)
				ai_name = L.t("diff_easy")
			1:
				var res = AI.build(1, rules.budget_of(1) if rules != null else 100, r, -1, p1, rules)
				armies[1] = res["army"]
				ai_name = "%s・%s" % [L.t("diff_normal"), res["name"]]
			_:
				armies[1] = _hard_ai(r, p1)
				ai_name = L.t("diff_hard")



## 困難 AI：第 1 局沒有資訊，用會讀對方的落子 AI 自己組；之後讀你上一局的陣型，
## 先查離線反制庫（組成最接近的原型），查不到就用啟發式反制。不偷看你這一局。
func _hard_ai(r: RandomNumberGenerator, pool: int) -> Army:
	# 第四輪：候選陣型各和你上一局的陣型模擬一場，挑最好的（scripts/core/hard_ai.gd）
	var known: Array = last_player_formation if round_no > 1 else []
	return HardAI.build(known, _counter_lib(), r, pool, rules)



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





## 系列結束了沒（第五輪：局數可調；沒有規則＝1.3.0 的先兩勝或打滿 5 局）。給測試直接驗。
static func series_done(w: Array, rn: int, r) -> bool:
	var need: int = r.wins_needed() if r != null else 2
	var cap_r: int = r.max_rounds() if r != null else 5
	return int(w[0]) >= need or int(w[1]) >= need or rn >= cap_r



func _pt_entry(rating: int) -> Dictionary:
	if rating == 0:
		pt_game += 1
	return {"v": 2, "session": pt_session, "game": pt_game, "code": BattleCode.encode(last_armies[0], last_armies[1], battle_rules, last_cmds),
		"event": "rating" if rating > 0 else "battle", "mode": _mode_label(), "round": round_no, "winner": sim.winner,
		"ticks": sim.tick, "reason": sim.reason, "blue": last_armies[0].to_code(), "red": last_armies[1].to_code(),
		"power": [sim.power(0), sim.power(1)], "suspense": report.get("sus", {}), "call_tick": pt_call_tick,
		"rating": rating, "rules": D.RULES_VERSION, "digest": D.data_digest()}



func _build_report() -> void:
	var dealt := [D.zeros(), D.zeros()]
	var taken := [D.zeros(), D.zeros()]
	var mvp = null
	for u in sim.units:
		dealt[u.team][D.report_type(u.type)] += u.dmg_dealt
		taken[u.team][D.report_type(u.type)] += u.dmg_taken
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
		var rem: int = PZ.rem_pct(sim.power(0), sim.budget) if sim.winner == 0 else 0
		report["stars"] = PZ.stars(pz, sim.winner == 0, rem, extra_spent)
		report["star_lines"] = _star_lines(sim.winner == 0, rem, int(pz["star2"]), extra_spent, int(pz["star3"]))



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
	Save.data["unlock_games"] = int(Save.data.get("unlock_games", 0)) + 1   # 只是累計場數（判斷新玩家用），不解鎖任何東西
	var me_won := w == 0 or (mode == Mode.DUEL and w >= 0)
	var stat_key := "stats" if standard else "custom_stats"
	var st: Dictionary = Save.data.get(stat_key, {"wins": 0, "games": 0})
	st["games"] = int(st.get("games", 0)) + 1
	if w == 0 and mode != Mode.DUEL:
		st["wins"] = int(st.get("wins", 0)) + 1
	Save.data[stat_key] = st
	_v8_achievements(w)   # 奇幻軍是娛樂變體，要放在「自訂規則提前返回」之前（Codex 第 3 輪）
	# 圖鑑老兵筆記：派這個兵種贏一場 +1（第二輪方案 R3）。第十輪 B4：自訂規則、奇幻軍也算（放在提前返回之前）
	var types := {}
	if me_won:
		for u in sim.units:
			if u.team == w:
				types[D.report_type(u.type)] = true
		CX.record_win(Save.data, types.keys())
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
		if types.size() == 5:
			_ach("ALL_TYPES")
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
				_gauntlet_clear()
		else:
			_gauntlet_clear()
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
	if mode == Mode.GAUNTLET:
		return RuleSet.types_of(_gauntlet_pool())   # 第八輪：遠征沿用對 AI 的出戰名單
	for t in D.total():
		if t >= D.COUNT and rules == null and mode != Mode.TUTORIAL and mode != Mode.PUZZLE:
			continue
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
	var classic := str(Save.s("roster")) == "classic"
	var kind := "all"
	if mode == Mode.DUEL:
		kind = "duel"
	elif mode == Mode.VS_AI or mode == Mode.GAUNTLET:
		kind = "ai"
	return RS.ntypes_for(kind, classic, _demo())



## 第五輪：這一場的卡池遮罩（R1 前＝前 N 種）。
func _pool() -> int:
	if rules != null:
		return rules.pool_of(0)
	if mode == Mode.GAUNTLET:
		return _gauntlet_pool()
	return RuleSet.prefix_pool(_ntypes())



func _allowed(t: int) -> bool:
	if rules != null and (mode == Mode.VS_AI or mode == Mode.DUEL):
		return RuleSet.has(_cur_army().pool, t)
	if mode == Mode.GAUNTLET:
		return RuleSet.has(_gauntlet_pool(), t)
	if t >= _ntypes() and (t < D.COUNT or not (mode == Mode.TUTORIAL or mode == Mode.PUZZLE)):
		return false
	if mode == Mode.TUTORIAL or mode == Mode.PUZZLE:
		for x in PZ.get_puzzle(puzzle_id)["allowed"]:
			if int(x) == t:
				return true
		return false
	return true



## 遠征的出戰名單（第八輪）：上次對 AI 用的名單，拿掉沒解鎖的；沒有就是解鎖的舊兵。
func _gauntlet_pool() -> int:
	var base := RuleSet.prefix_pool(_ntypes())
	# 第八輪：開打前在「遠征用哪支軍隊」選的，整趟沿用；存檔被改壞就當沒選
	var chosen = Save.data.get("gauntlet_pool", 0)
	if (chosen is int or chosen is float) and int(chosen) > 0:
		var cp: int = int(chosen) & RS.mask(_demo())
		if RuleSet.has_combat(cp) and RuleSet.pool_count(cp) <= RuleSet.ROSTER_MAX:
			return cp
	var lp := _gauntlet_last_pool()
	return lp if lp > 0 else base



## 上次在大廳用的對 AI 名單（有解鎖、合法才算）。
func _gauntlet_last_pool() -> int:
	var code := str(Save.data.get("last_rules", {}).get("ai", ""))
	if code == "":
		return 0
	var d: Dictionary = RuleSet.from_code(code)
	if not d["ok"]:
		return 0
	var p: int = int(d["rules"].pool_of(0)) & RS.mask(_demo())
	return p if RuleSet.has_combat(p) else 0



func _v8_achievements(w: int) -> void:
	if w < 0 or not (mode == Mode.VS_AI or mode == Mode.DUEL or mode == Mode.GAUNTLET):
		return
	if mode == Mode.VS_AI and w != 0:
		return
	if rules != null and rules.is_sandbox():
		return
	if int(ev_count.get("blast_fx%d" % w, 0)) >= 5:
		_ach("BOOM_5")
	if int(ev_count.get("raise%d" % w, 0)) >= 3:
		_ach("RAISE_3")
	var all_new: bool = armies.size() > w and not armies[w].units.is_empty()
	if all_new:
		for au in armies[w].units:
			if int(au["type"]) < D.COUNT:
				all_new = false
	if all_new:
		_ach("FANTASY_WIN")



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
	var field := Rect2(ORIGIN, fld_size)
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


## 結果頁兵種長條要列哪幾種：有出場（造成或承受傷害）的兵種，依雙方合計由多到少，最多 5 種；同分取編號小的。
static func report_rows(dealt: Array, taken: Array) -> Array:
	var rows: Array = []
	for t in D.total():
		if dealt[0][t] + dealt[1][t] + taken[0][t] + taken[1][t] > 0:
			rows.append(t)
	rows.sort_custom(func(p, q):
		var sp: int = dealt[0][p] + dealt[1][p] + taken[0][p] + taken[1][p]
		var sq: int = dealt[0][q] + dealt[1][q] + taken[0][q] + taken[1][q]
		return sp > sq or (sp == sq and p < q))
	return rows.slice(0, 5)



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


## 結果頁：每個條件有沒有達成、這場多少，一眼看出差在哪。
func _star_lines(won: bool, rem: int, need_rem: int, spent: int, need_spent: int) -> String:
	var yes := "✓"
	var no := "×"
	return "%s %s　%s %s　%s %s" % [yes if won else no, L.t("star_c_win"),
		yes if won and rem >= need_rem else no, L.t("star_c_rem", [need_rem, rem]),
		yes if spent <= need_spent else no, L.t("star_c_spent", [need_spent, spent])]

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



func _gauntlet_next() -> void:
	gauntlet_prev = last_armies[0].units.duplicate(true)
	gauntlet_stage += 1
	gauntlet_changes = 3
	_reset_place(false)
	armies[0].budget += int(get("gauntlet_gold"))
	armies[0].unit_cap += int(get("gauntlet_cap"))

## 第十輪 I5：遠征只在每戰之間存檔。
func _gauntlet_save() -> void:
	var prev: Array = []
	for u in gauntlet_prev:
		var o := {}
		for k in u:
			o[str(k)] = int(u[k])
		prev.append(o)
	Save.data["gauntlet_run"] = {"stage": gauntlet_stage, "seed": gauntlet_seed, "gold": int(get("gauntlet_gold")), "cap": int(get("gauntlet_cap")),
		"changes": gauntlet_changes, "pool": _gauntlet_pool(), "prev": prev}   # 存實際卡池：之後改大廳不會影響這次遠征（Codex v10-r1 #2）
	Save.save_data()

func _gauntlet_clear() -> void:
	Save.data["gauntlet_run"] = {}

func _gauntlet_resume() -> void:
	var g: Dictionary = Save.data.get("gauntlet_run", {})
	if g.is_empty():
		return
	Save.data["gauntlet_pool"] = int(g["pool"])
	call("_start_mode", Mode.GAUNTLET)
	set("gauntlet_gold", int(g["gold"]))
	set("gauntlet_cap", int(g["cap"]))
	gauntlet_stage = int(g["stage"])
	gauntlet_seed = int(g["seed"])
	gauntlet_prev = g["prev"].duplicate(true)
	_reset_place(false)
	armies[0].budget += int(g["gold"])
	armies[0].unit_cap += int(g["cap"])
	gauntlet_changes = int(g["changes"])



## 匯出成品自我檢查（第七輪 S3）：tools/export_check.sh 對匯出的 exe 跑，印 SELFCHECK 一行 JSON。
func _self_check() -> void:
	for i in 3:
		await get_tree().process_frame
	var demo := _demo()
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
	out["unit_cap"] = RuleSet.pool_count(RS.mask(demo)) == (RS.DEMO_MAX + 1 if demo else D.total())
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
