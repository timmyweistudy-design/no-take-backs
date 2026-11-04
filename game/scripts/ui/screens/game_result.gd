extends "res://scripts/ui/screens/game_place.gd"
## 由 game_screens.gd 拆出（V9 P1，行為不變）

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



func _pt_rate(v: int) -> void:
	pt_rated = true
	if PLAY_EFFECTS[play_kind]["log"]:
		Save.playtest_log(_pt_entry(v))
	_toast(L.t("pt_thanks"))



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
	var list: Array = PZ.tutorials() if mode == Mode.TUTORIAL else (PZ.fantasy_puzzles() if int(PZ.get_puzzle(puzzle_id).get("unit", 0)) >= D.COUNT else PZ.new_puzzles() if PZ.get_puzzle(puzzle_id).has("unit") else PZ.puzzles())
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
