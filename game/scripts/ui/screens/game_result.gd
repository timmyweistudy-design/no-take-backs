extends "res://scripts/ui/screens/game_place.gd"
## 由 game_screens.gd 拆出（V9 P1，行為不變）

func _start_mode(m: int) -> void:
	nav_stack.clear()   # V1.5.1：進擺陣後，從擺陣開的圖鑑返回要回擺陣，不能彈出主畫面的卡片面板（Codex v151-i1 #1）
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
	set("trial_id", -1)
	if m != Mode.VS_AI or get("challenge_army") == null:
		set("daily_spec", {})   # V1.1 D2：每日挑戰按「再來一次」時保留（敵陣在 challenge_army）
	if m != Mode.VS_AI:
		set("challenge_army", null)
	set("sealed_on", false)   # V1.4 #13：_sealed_start 會在 _start_mode 之後再設回來
	set("ghost_id", "")       # V1.4 #7：幽靈、每週棋盒也是在 _start_mode 之後才設
	set("wk_active", false)
	set("wv_mode", false)   # V1.4 #11：開別的模式就不是車輪戰（_wave_setup 會在 _start_mode 之後再設回來）
	set("wv_active", false)
	if m == Mode.GAUNTLET:
		set("gauntlet_gold", 0)
		set("gauntlet_cap", 0)
		set("gauntlet_foe_gold", 0)
		set("gauntlet_foe_cap", 0)
		set("gauntlet_contract", -1)
		set("ct_pick", -1)
		set("ct_last", "")
		gauntlet_stage = 1
		gauntlet_prev = []
		gauntlet_changes = 99
		gauntlet_seed = rng.randi()
	_reset_place()



func _finish_battle() -> void:
	sfx.set_muffled(false)
	_pc_capture()   # V1.4 #14：最後一格戰場畫面留給戰報卡
	fx = fx.filter(func(f): return f["kind"] != "text")   # 結果頁不留戰場跳字（Antigravity S3）
	clutch_t = 0.0   # 最後時刻橫幅不跟到結果頁（第三輪 T4 抓到）
	state = St.RESULT
	tm_ghost = null
	result_t = time
	if play_kind == "official" and sim != null:
		last_cmds = sim.cmd_log.duplicate(true)
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
		if bool(get("sealed_on")) and mode == Mode.DUEL and round_no >= 3:
			series_over = true   # V1.4 #13：只封了三陣，平手也不打第四局（Antigravity v140-i3）
		if series_over and bool(get("sealed_on")) and mode == Mode.DUEL and play_kind == "official":
			call("_ach", "SEALED_DONE")   # V1.5
	if bool(get("wv_active")) and mode == Mode.VS_AI and play_kind == "official":
		set("wv_surv", call("wave_survivors", last_armies[0], sim))   # 殘兵在結束當下就定（之後看重播不影響）
		var wc: Array = get("wv_codes")
		wc.append(BattleCode.encode(last_armies[0], last_armies[1], battle_rules, last_cmds))   # V1.5.1 D1
	_build_report()
	call("_ghost_settle", w)   # V1.4 #7
	call("_wager_settle")   # V1.4 #16：競猜結算（要在報告建好之後，不然結果行會被蓋掉，Codex v140-i2）
	if bool(get("wv_active")) and mode == Mode.VS_AI and play_kind == "official" and not (w == 0 and int(get("wv_no")) < 3):
		call("_wave_end", w == 0)   # V1.4 #11：車輪戰結束（輸了或三波打完）
	if mode == Mode.DUEL:
		sfx.play("win" if w >= 0 else "lose")
	elif mode == Mode.PUZZLE and report.has("goal_ok"):
		sfx.play("win" if bool(report["goal_ok"]) else "lose")   # 第十三輪：照過關條件（Codex v13-r1 #6）
	else:
		sfx.play("win" if w == 0 else "lose")
	sfx.play("ui_quill", 0.45)   # V1.3 B4：戰報寫上羊皮紙的筆聲（各模式都有）
	if eff["progress"]:
		_progress_and_achievements()
		if mode == Mode.VS_AI or mode == Mode.GAUNTLET or mode == Mode.DUEL:
			call("_record_match", w)
		call("_trial_finish", w)
		call("_daily_finish", w)
		Save.save_data()     # 統計是最後才記的，要再存一次（Codex #7）
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
	_box(r.grow(5), Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), 14.0)
	_box(r, PANEL, TH_EDGE, 10.0, 3.0)
	var w: int = sim.winner
	var title := L.t("draw")
	var col := Color.WHITE
	if w >= 0:
		title = L.t("win_team", [L.t("blue") if w == 0 else L.t("red")])
		col = Art.team_color(w, cbm())
	if mode == Mode.PUZZLE and report.has("goal_ok") and PZ.goal(PZ.get_puzzle(puzzle_id)) != "win":
		title = L.t("goal_ok") if bool(report["goal_ok"]) else L.t("goal_fail")   # 第十三輪：護送、撐住、斬首看條件
		col = Color("#ffd166") if bool(report["goal_ok"]) else Color(1, 1, 1, 0.8)
	var title_sz := tcap(tz("D"), 64)
	# 第十輪 V2、F2：標題離上緣遠一點；橫幅從上面落下（版面檢查、簡化特效不演）
	var drop := 0.0
	if not layout_probe and not bool(Save.s("reduce_fx")):
		var dk := clampf((time - result_t) / 0.25, 0.0, 1.0)
		drop = (1.0 - dk) * (1.0 - dk) * -60.0
	# V1.2 C3：勝負大字墊一條布幔絲帶（勝方隊色、兩端燕尾、金邊），不再是浮在面板上的單色字
	var rib_in := 0.0   # 有緞帶時，摘要第一行用緞帶內寬排版（Codex v120-final：長行跨出緞帶）
	if not bool(Save.s("plain_ui")):
		var l1 := _result_line1(540.0 - 24.0)
		# 緞帶最寬 540；燕尾依剩下的空間縮短，停在左右按鈕前（x 354～926）
		var tw: float = minf(540.0, maxf(minf(540.0, _width(title, title_sz, true)) + 120.0, _width(l1, tz("S")) + 40.0))
		var tail := clampf((572.0 - tw) / 2.0, 10.0, 34.0)
		rib_in = tw - 24.0
		l1 = _result_line1(rib_in)   # 高度用和正文同一個寬度決定的斷行
		var ry0 := 114.0 - title_sz * 0.02
		var ry := ry0 + drop
		# 布幔上下要留白（Antigravity impl1）：往下一級字級（只能用字級表裡的值）
		var lv: Array = TYPE_SCALE[_scale_key()].values()
		var nxt := title_sz
		for v in lv:
			if v < title_sz and (nxt == title_sz or v > nxt):
				nxt = v
		# 布幔包住標題＋摘要第一行，下緣金邊落在第一行和勝負敘述之間的空隙；高度用實際（fit 後）字級，和正文推進同一算法
		var y1 := 112.0 + nxt * 1.25 + (float(tz("C")) * 1.4 if play_kind == "review" else 0.0)
		var l1h := y1 - (112.0 + nxt * 1.25) + text_h(l1, fit(l1, tz("S"), rib_in), rib_in)
		var rh := 112.0 + nxt * 1.25 + l1h + 4.0 - ry0   # 靜態高度；開場落下時整條一起移動
		var rx0 := 640.0 - tw / 2.0
		var rib: Color = (col.darkened(0.35) if w >= 0 else Color("#5b4632"))
		# V1.2.1 R3：勝方緞帶後方一次性放射光＋燕尾上方 6 顆金星（0.6 秒；畫在緞帶下、只在燕尾外，不擋字；簡化特效時不演）
		var cel_k := clampf((time - result_t - 0.2) / 0.6, 0.0, 1.0)
		if w >= 0 and cel_k < 1.0 and not bool(Save.s("reduce_fx")) and not layout_probe and shot_dir == "":
			var cc := Vector2(640, ry0 + rh * 0.5)
			var ga := sin(cel_k * PI)
			for kk in 6:
				draw_circle(cc, (tw * 0.35 + kk * 18.0) * (0.8 + 0.2 * cel_k), Color(1.0, 0.85, 0.45, 0.05 * ga), true, -1.0, true)
			for si in 6:
				var side := -1.0 if si < 3 else 1.0
				var j := si % 3
				var sp := Vector2(640 + side * (tw / 2.0 + tail * 0.4 - j * 22.0), ry0 - 6.0 - j * 9.0 - cel_k * 16.0)   # 從燕尾上方往上飄（兩側是按鈕，不往外放）
				_icon("star", sp, 14.0 - j * 2.0, Color(1.0, 0.85, 0.4, ga))
		for sgn in [-1.0, 1.0]:
			var ex: float = rx0 if sgn < 0 else rx0 + tw
			draw_colored_polygon(PackedVector2Array([Vector2(ex, ry + 8), Vector2(ex + sgn * tail, ry + 8), Vector2(ex + sgn * tail * 0.6, ry + rh * 0.5 + 4), Vector2(ex + sgn * tail, ry + rh), Vector2(ex, ry + rh)]), rib.darkened(0.35))
		draw_rect(Rect2(rx0, ry, tw, rh), rib)
		draw_rect(Rect2(rx0, ry, tw, 3), Color("#e8c26a"))
		draw_rect(Rect2(rx0, ry + rh - 3, tw, 3), Color("#e8c26a"))
		draw_rect(Rect2(rx0, ry + 3, tw, rh * 0.3), Color(1, 1, 1, 0.08))
		col = Color("#fff6e0")
		title_sz = nxt
	_text(Vector2(640, 114 + drop + (title_sz * 0.08 if not bool(Save.s("plain_ui")) else 0.0)), title, title_sz, col, true, true, 540)
	if not (mode == Mode.PUZZLE and battle_rules != null):   # 第十三輪：殘局自帶規則（地形、撐住、技能）的代碼讀不回來，不給複製（Codex v13-r1 #1）
		_btn(Rect2(214, 112, 140, 40), L.t("bc_copy"), func(): _copy_battle_code())   # 對戰代碼（第三輪 F3）
	if (mode == Mode.VS_AI or mode == Mode.DUEL) and last_armies.size() == 2 and not watch_mode and (rules == null or rules.fullfield == 0):
		_btn(Rect2(214, 158, 140, 40), L.t("ch_copy"), func(): call("_copy_challenge"))
	if report.has("trial_stars"):
		for ks in 3:
			# V1.2 F1：星星一顆一顆彈出（截圖、版面檢查、簡化特效時直接到位）
			var kk := 1.0
			if not layout_probe and shot_dir == "" and not bool(Save.s("reduce_fx")):
				kk = clampf((time - result_t - 0.35 - ks * 0.18) / 0.22, 0.0, 1.0)
			var pop := 1.0 + 0.35 * sin(kk * PI)
			if kk > 0.0:
				_icon("star", Vector2(610 + ks * 30, 84), 26.0 * pop * kk, Color("#ffd166") if ks < int(report["trial_stars"]) else Color(1, 1, 1, 0.2))
	var mvp = report.get("mvp")
	_btn(Rect2(926, 112, 140, 40), L.t("menu_codex_short"), _open_codex.bind(mvp.type if mvp != null else 0))
	var y := 112.0 + title_sz * 1.25
	if play_kind == "review":
		_text(Vector2(640, y), L.t("review_tag"), tz("C"), ACCENT, true, false, 480)
		y += tz("C") * 1.4
	# 標題區只用左右按鈕之間的寬度（Antigravity 實作第 1 輪：英文 150% 摘要壓到「詳細數據」按鈕）
	var hw := 540.0 if y < 210 else 820.0
	var line1 := _result_line1(rib_in if rib_in > 0.0 else hw)
	var hw1 := rib_in if rib_in > 0.0 else hw
	_text(Vector2(640, y), line1, tz("S"), TXT_DIM, true, false, hw1)
	y += text_h(line1, fit(line1, tz("S"), hw1), hw1) + 6   # 和 _text 一樣先 fit 再量
	var goal_mode: bool = mode == Mode.PUZZLE and report.has("goal_ok") and PZ.goal(PZ.get_puzzle(puzzle_id)) != "win"
	var loss := _loss_line(w, goal_mode)
	if loss != "":
		# V1.1 B1：輸的時候這一行改講「主要傷害來源＋可以試的兵」，不另外加高版面
		hw = 540.0 if y < 210 else 820.0
		_text(Vector2(640, y), loss, tz("B"), Color("#ffd8a8"), true, true, hw)
		y += text_h(loss, tz("B"), hw, true) + 8
	elif w >= 0 and not goal_mode:   # 第十三輪：護送、撐住、斬首不寫一般勝負敘述（Codex v13-r1 #6）
		hw = 540.0 if y < 210 else 820.0
		_text(Vector2(640, y), _verdict(w), tz("B"), Color.WHITE, true, true, hw)
		y += text_h(_verdict(w), tz("B"), hw, true) + 8
	if str(report.get("wager_line", "")) != "":
		_text(Vector2(640, y), str(report["wager_line"]), tz("B"), Color("#ffd166"), true, true, 820)   # V1.4 #16 競猜結果
		y += tz("B") * 1.5
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
		_text(Vector2(250, ch.end.y + 4), L.t("mom_caption"), tz("C"), TXT_DIM, false, false, 780)
		y = ch.end.y + tz("C") * 1.6 + 6
		if mvp != null:
			var mr := Rect2(250, y, 780, 76)
			_box(mr, Color(1, 0.82, 0.3, 0.12), Color(1, 0.82, 0.3, 0.5), 7.0, 1.5)
			_icon("trophy", mr.end - Vector2(34, 38), 34.0)
			Art.ring(self, mr.position + Vector2(52, 66), mvp.team, mvp.type, cbm(), 1.25)
			Art.unit(self, mr.position + Vector2(52, 66), mvp.type, mvp.team, 1.0 if mvp.team == 0 else -1.0, 0.0, 0.0, 0.0, 1.0, time, 1.25, cbm())
			_text(mr.position + Vector2(100, 10), "MVP　" + L.t("unit_%d" % mvp.type), tz("B"), ACCENT, false, true, 400)
			_text(mr.position + Vector2(100, 10 + tz("B") * 1.4), L.t("mvp_line", [L.t("blue") if mvp.team == 0 else L.t("red"), mvp.dmg_dealt, mvp.kills]), tz("S"), Color(1, 1, 1, 0.85), false, false, 660)
			y = mr.end.y + 10
		# 第七輪 A1：只列事件紀錄裡查得到的事實，不說「因為」（Codex：不宣稱因果）
		var facts := _result_facts()
		if mode == Mode.PUZZLE and str(report.get("rec_line", "")) != "":
			# V1.4 #6 最小成本懸賞：本次 vs 你的最佳；破紀錄放最前面
			if str(report.get("rec_new", "")) != "":
				facts.insert(0, str(report["rec_new"]))
			facts.append(str(report["rec_line"]))
		if str(report.get("gh_line", "")) != "":
			facts.insert(0, str(report["gh_line"]))   # V1.4 #7：擊破幽靈／每週新紀錄
		var obs := _result_obs()
		for oi in range(obs.size() - 1, -1, -1):
			facts.insert(0, obs[oi])   # V1.5.1 D3：本場觀察放最前面
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
		var sl: String = "★".repeat(stn) + "☆".repeat(3 - stn) + "　" + str(report.get("star_lines", L.t("star_rules", [pz["star2"], pz["star3"]])))
		_text(Vector2(640, y), sl, tz("S"), ACCENT, true, false, 820)
		y += text_h(sl, tz("S"), 820) + 4
	if report.has("trial_lines"):
		var tn := int(report.get("trial_stars", 0))
		var tl: String = "★".repeat(tn) + "☆".repeat(3 - tn) + "　" + str(report["trial_lines"])
		_text(Vector2(640, y), tl, tz("S"), ACCENT, true, false, 820)
		y += text_h(tl, tz("S"), 820) + 4
	# 試煉只有一場，不顯示「三戰兩勝結束」（使用者截圖；大字級時還會壓到按鈕）
	if series_over and (mode == Mode.VS_AI or mode == Mode.DUEL) and int(get("trial_id")) < 0:
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
	if _demo() and series_over and play_kind == "official":
		var wr := Rect2(260, minf(y, 588), 760, 52)
		draw_rect(wr, Color(0.35, 0.22, 0.05, 0.95))
		draw_rect(wr, ACCENT, false, 2.0)
		_text(Vector2(276, wr.position.y + 12), L.t("demo_wish"), tz("S"), Color.WHITE, false, true, 480)
		var url: String = SteamApi.STORE_URL
		_btn(Rect2(780, wr.position.y + 6, 230, 40), L.t("demo_wish_btn") if url != "" else L.t("demo_wish_soon"), func(): OS.shell_open(url), url != "", true)
	var bs: Array = []
	match mode:
		Mode.VS_AI, Mode.DUEL:
			if get("trial_id") >= 0:
				var tid: int = get("trial_id")
				if w == 0 and tid + 1 < get("TRIALS").size():
					bs.append([L.t("next_puzzle"), func(): call("_start_trial", tid + 1)])
				bs.append([L.t("retry"), func(): call("_start_trial", tid)])
				bs.append([L.t("trial_title"), func():
					_go_title()
					_open("trials")])
			else:
				bs.append([(L.t("sealed_again") if bool(get("sealed_on")) else L.t("new_match")) if series_over else L.t("next_round"), func(): _next_round()])
		Mode.TUTORIAL, Mode.PUZZLE:
			bs.append([L.t("retry"), func(): _start_mode(mode)])
			if ((w == 0 and mode == Mode.TUTORIAL) or bool(report.get("goal_ok", false))) and puzzle_id != "ws":
				bs.append([L.t("next_puzzle"), func(): _next_puzzle()])
			if puzzle_id == "ws" and bool(report.get("goal_ok", false)) and play_kind == "official":
				bs.append([L.t("rl_btn"), func(): call("_open_relay")])   # V1.4 #5 接力：改兩隻敵兵傳回去
		Mode.GAUNTLET:
			if w == 0 and gauntlet_stage < 7:
				bs.append([L.t("continue"), func(): call("_gauntlet_reward")])
			else:
				bs.append([L.t("menu_gauntlet"), func(): _start_mode(Mode.GAUNTLET)])
	if bool(get("wv_mode")) and mode == Mode.VS_AI:
		# V1.4 #11 車輪戰：贏了接下一波（殘兵帶著走），輸了或打完三波就結束（結算在戰鬥結束時做一次）
		bs.clear()
		if bool(get("wv_active")) and w == 0 and int(get("wv_no")) < 3:
			bs.append([L.t("wv_next", [int(get("wv_no")) + 1]), func(): call("_wave_next")])
		else:
			bs.append([L.t("wv_again"), func(): call("_wave_start")])
			if not (get("wv_codes") as Array).is_empty():
				bs.append([L.t("wv_copy"), func(): DisplayServer.clipboard_set(call("wave_code", get("wv_codes"))); _toast(L.t("bc_copied"))])
	if watch_mode:
		bs.clear()   # 看對戰代碼：不接正式對局的「下一局」（Codex S5 #2）

	var n_main := bs.size()   # V1.5：前面這幾顆是主動作（繼續、重試、下一題），後面是次入口
	if mode == Mode.VS_AI and last_armies.size() == 2 and not watch_mode:
		if _near_miss():
			bs.insert(0, [L.t("review_near"), func(): _open_review()])   # 第十輪 F4：輸得很近，主推覆盤
			n_main += 1
		else:
			bs.append([L.t("menu_review"), func(): _open_review()])   # 覆盤（第三輪 F1）
	if _ws_ok(w):
		bs.append([L.t("ws_make"), func(): call("_make_workshop")])   # V1.1 D3：打贏的格子對戰可以出題
	if play_kind == "official" and pc_shot != null and bs.size() <= 3:   # 按鈕列滿了就不放（英文 150% 會擠）
		bs.append([L.t("pc_btn"), func(): overlay = "postcard"])   # V1.4 #14 戰報明信片
	bs.append([L.t("replay"), func(): _replay()])
	bs.append([L.t("menu"), func(): _request_leave()])
	# 按鈕寬依結果框內寬分（框 880、左右各留 16）：試煉贏了最多 6 顆，舊的固定 176 會凸出框外（使用者截圖）
	var gap := 8.0
	# V1.5：主動作比次入口寬 1.3 倍、比較高；次入口用木色、矮一點，一眼分得出先按哪顆
	var wsum := 0.0
	for i in bs.size():
		wsum += 1.3 if i < n_main else 1.0
	var unit_w: float = minf(200.0, (848.0 - (bs.size() - 1) * gap) / maxf(1.0, wsum))
	# 每顆至少放得下自己的字（日文 150% 次入口曾被切）；放不下時回到平均寬
	var ws: Array = []
	var tot := 0.0
	for i in bs.size():
		var w0: float = maxf(unit_w * (1.3 if i < n_main else 1.0), _width(str(bs[i][0]), ts(18), true) + 24.0)
		ws.append(w0)
		tot += w0
	if tot + (bs.size() - 1) * gap > 848.0:
		var avg := (848.0 - (bs.size() - 1) * gap) / maxf(1.0, bs.size())
		for i in bs.size():
			ws[i] = avg
		tot = avg * bs.size()
	var x := 640.0 - (tot + (bs.size() - 1) * gap) / 2.0
	if mode == Mode.VS_AI and not watch_mode and _near_miss():
		_text(Vector2(640, 618), L.t("review_near_d", [roundi(sim.power(1) * 100.0 / (sim.budget_of(1) * 1000))]), tz("S"), ACCENT, true, true, 820)
	for i in bs.size():
		var main := i < n_main
		var bw2: float = ws[i]
		if main:
			_btn(Rect2(x, 646, bw2, 50), bs[i][0], bs[i][1], true, i == 0)
		else:
			_btn(Rect2(x, 649, bw2, 44), bs[i][0], bs[i][1], true, false, TH_WOOD)
		x += bw2 + gap



## V1.5.1 D3「本場觀察」：遠征的契約、宿敵、巨獸各一句；只寫事件與數字，不寫因果。最多 2 句。
func _result_obs() -> Array:
	var out: Array = []
	if mode != Mode.GAUNTLET or play_kind != "official" or sim == null:
		return out
	var ct: String = str(get("ct_last"))
	if ct != "":
		out.append(ct)
	if int(get("gauntlet_nemesis")) >= 0:
		out.append(L.t("obs_nem_win") if sim.winner == 0 else L.t("obs_nem_lose"))
	for u in sim.units:
		if u.team == 1 and u.boss:
			var hp_pct: int = 0 if not u.alive else int(u.hp * 100 / maxi(1, u.max_hp))
			out.append(L.t("obs_boss", [hp_pct]))   # 巨獸剩多少血（倒下＝0%）
			break
	return out.slice(0, 2)

## 第十輪 F4：輸了、對手剩不到 15% 戰力。
func _near_miss() -> bool:
	if sim == null or sim.winner != 1 or last_armies.size() != 2:
		return false
	return sim.power(1) * 100 < sim.budget_of(1) * 1000 * 15

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
	var res: Array = out.map(func(x): return x[1])
	# V9：輸了多一條事實：對手誰打最痛、誰克制它（只講數字查得到的，不說「因為」）
	if mode == Mode.VS_AI and sim.winner == 1 and play_kind == "official":
		var dmg := {}
		for u in sim.units:
			if u.team == 1:
				dmg[u.type] = int(dmg.get(u.type, 0)) + u.dmg_dealt
		var top := -1
		for t in dmg:
			if top < 0 or int(dmg[t]) > int(dmg[top]):
				top = t
		if top >= 0 and top < D.total():
			var names: Array = []
			for x in D.total():
				if top in AIT.BEATS[x] and names.size() < 2:
					names.append(L.t("unit_%d" % x))
			if not names.is_empty():
				res.append(L.t("res_top_enemy", [L.t("unit_%d" % top), "、".join(names)]))
	return res


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
		rows.append({"label": L.t("unit_%d" % t), "b": src[0][t], "r": src[1][t], "type": t})
	_text(R.position, L.t("report_by_type"), tz("B"), Color.WHITE, false, true, 210)
	_btn(Rect2(R.position.x + 220, R.position.y - 6, 120, 38), L.t("report_dealt"), func(): result_metric = 0, true, false, TH_ACTIVE if result_metric == 0 else Color(0, 0, 0, 0))
	_btn(Rect2(R.position.x + 346, R.position.y - 6, 120, 38), L.t("report_taken"), func(): result_metric = 1, true, false, TH_ACTIVE if result_metric == 1 else Color(0, 0, 0, 0))
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
	_text(Vector2(640, y + 4), L.t("fingerprint", [sim.fingerprint.substr(0, 12)]), tz("C"), TXT_DIM, true, false, 760)   # V1.2.1 F5：原 45% 白只有 2:1



## 一句描述（第五輪：只講事實、和 MVP 一致，不宣稱因果——Codex 第二輪）。主角＝MVP（勝方傷害最高的那一隻）。
## V1.1 B1：藍方（玩家）輸了才有。傷害最多的敵方兵種與占比；能帶的兵裡剋它最強的那種當建議。雙人、觀戰不顯示。
func _loss_line(w: int, goal_mode: bool) -> String:
	if mode == Mode.DUEL or watch_mode or play_kind == "review":
		return ""
	var lost: bool = (bool(report.get("goal_ok", true)) == false) if goal_mode else (w == 1)
	if not lost:
		return ""
	return loss_summary(ev_count, _loss_pool())

func _loss_pool() -> Array:
	if mode == Mode.PUZZLE or mode == Mode.TUTORIAL:
		return PZ.get_puzzle(puzzle_id).get("allowed", [])
	var out: Array = []
	var pool: int = int(armies[0].pool) if not armies.is_empty() else 0
	for ty in 20:
		if RuleSet.has(pool, ty):
			out.append(ty)
	return out

## 純函式（測試用）。counts＝ev_count（含 dmgby0_<兵種>）、pool＝可以帶的兵種。
static func loss_summary(counts: Dictionary, pool: Array) -> String:
	var total := 0
	var top := -1
	var top_v := 0
	for k in counts:
		if str(k).begins_with("dmgby0_"):
			var v := int(counts[k])
			total += v
			if v > top_v:
				top_v = v
				top = int(str(k).substr(7))
	if top < 0 or total <= 0:
		return ""
	var best := -1
	var best_sc := 0
	for ty in pool:
		var sc: int = AIT.counter_score(int(ty), top)
		if sc > best_sc:
			best_sc = sc
			best = int(ty)
	var pct := roundi(top_v * 100.0 / total)
	if best >= 0:
		return L.t("loss_hint", [L.t("unit_%d" % top), pct, L.t("unit_%d" % best)])
	return L.t("loss_hint_n", [L.t("unit_%d" % top), pct])

## V1.1 D3：這場能不能做成殘局碼（藍方贏、格子部署、平原、沒開技能、不是試煉／每日／觀戰）。
func _ws_ok(w: int) -> bool:
	if w != 0 or watch_mode or play_kind == "review" or last_armies.size() != 2 or not (mode == Mode.VS_AI or mode == Mode.DUEL):
		return false
	if int(get("trial_id")) >= 0 or not (get("daily_spec") as Dictionary).is_empty():
		return false
	if rules != null and (rules.is_free() or rules.map_id != 0 or rules.cmd_on() or rules.fullfield != 0):
		return false
	for u in last_armies[0].units + last_armies[1].units:
		if not u.has("col"):
			return false
	return true

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



## V9：系列每局換地圖。換圖後舊陣型不一定放得下，所以不保留陣型。
func _apply_map_mode() -> void:
	if rules == null or rules.map_mode == 0 or not rules.is_free():
		return
	var n: int = MapDefs.MAPS.size()
	rules.map_id = wrapi(rules.map_id + 1, 0, n) if rules.map_mode == 1 else rng.randi_range(0, n - 1)
	rules.keep_formation = false
	rules.vents = false

func _next_round() -> void:
	if series_over and bool(get("sealed_on")) and mode == Mode.DUEL:
		call("_sealed_start")   # V1.4 #13：三戰打完再來＝重新封三陣（不是重打同一組，Antigravity v140-i3）
		return
	if series_over:
		wins = [0, 0]
		round_no = 1
		series_over = false
		last_player_formation = []
		_reset_place(false)
		return
	round_no += 1
	_apply_map_mode()
	_reset_place(mode == Mode.VS_AI)
	if bool(get("sealed_on")) and mode == Mode.DUEL:
		# V1.4 #13：下一局直接用封好的陣，不再擺
		var k := clampi(round_no - 1, 0, 2)
		call("_sealed_reveal", k)
		_toast(L.t("sealed_open", [k + 1]))



func _replay() -> void:
	# 重播只看不算：比分、進度、成就、日誌都不動（第三輪 A1，原本會重複結算）
	replay_marks = _key_marks() if not report.is_empty() else []
	_replay_snapshot()
	if play_kind == "review" and rv_last.size() == 2:
		_begin_battle(rv_last[0].copy(), rv_last[1].copy(), "review")
		return
	_begin_battle(last_armies[0].copy(), last_armies[1].copy(), "replay")



func _next_puzzle() -> void:
	var list: Array = PZ.tutorials() if mode == Mode.TUTORIAL else PZ.all_puzzles()   # 第十三輪：照章節順序接下一關
	for i in list.size():
		if list[i]["id"] == puzzle_id and i + 1 < list.size():
			var nx: Dictionary = list[i + 1]
			if nx.has("unit") and not RS.available(int(nx["unit"]), _demo()):
				break   # 試玩版沒有下一關的兵
			if _demo() and mode == Mode.PUZZLE and i + 1 >= Presets.DEMO_PUZZLES:
				break   # 試玩版只有第一章前幾關
			puzzle_id = nx["id"]
			_start_mode(mode)
			return
	if mode == Mode.TUTORIAL and not PZ.puzzles().is_empty():
		puzzle_id = PZ.puzzles()[0]["id"]
		_start_mode(Mode.PUZZLE)
		return
	_go_title()


## 結果頁摘要第一行（勝負原因・時間｜剩餘戰力）；緞帶高度和正文共用（V1.2）。
func _result_line1(maxw := 0.0) -> String:
	var reason_key := {"全滅": "reason_wipe", "同時全滅": "reason_bothwipe", "時間到・戰力相當": "reason_time_even",
		"時間到・剩餘戰力較高": "reason_time_power", "有一方沒有兵": "reason_empty"}
	var p0 := roundi(sim.power(0) * 100.0 / (sim.budget_of(0) * 1000))
	var p1 := roundi(sim.power(1) * 100.0 / (sim.budget_of(1) * 1000))
	var a := "%s・%.1fs" % [L.t(reason_key.get(sim.reason, "draw")), sim.tick / 20.0]
	var b := L.t("power_left", [p0, p1])
	var one := "%s　｜　%s" % [a, b]
	# V1.2.1 B1：放不下就在「｜」那裡分兩行（原因／戰力），不讓百分比孤零零掉到下一行
	if maxw > 0.0 and _width(one, tz("S")) > maxw:
		return a + "\n" + b
	return one


## ── V1.4 #14 戰報明信片 ──
var pc_shot: ImageTexture = null
var pc_saving := false

func _pc_capture() -> void:
	if DisplayServer.get_name() == "headless" or get_viewport() == null:
		return
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		return
	img = img.get_region(Rect2i(Vector2i(0, 60), Vector2i(1280, 690)))
	img.resize(560, 302, Image.INTERPOLATE_BILINEAR)
	pc_shot = ImageTexture.create_from_image(img)

func _draw_postcard() -> void:
	draw_rect(Rect2(0, 0, 1280, 800), Color(0.05, 0.03, 0.02, 0.9))   # 底下的結果頁按鈕不能透出來（Antigravity v140-i2）
	var P := Rect2(150, 90, 980, 560)
	probe_panel(P)   # 明信片自己畫紙卡，不走 _panel：照樣登記成模態面板（R1 置中、漏登記守衛）
	_tex_box(P, "paper")
	draw_rect(P.grow(-14), Color("#9a7b3c", 0.85), false, 2.0)   # 暗金內框
	draw_rect(P.grow(-19), Color("#9a7b3c", 0.45), false, 1.0)
	_ink_mode = true
	# 左：戰場快照，木框
	var pic := Rect2(P.position + Vector2(30, 70), Vector2(560, 302))
	_tex_box(pic.grow(10), "wood", Color(0.55, 0.38, 0.22))
	if pc_shot != null:
		draw_texture_rect(pc_shot, pic, false)
	# 標題：戰報（墨字）＋紅印章
	_text(P.position + Vector2(30, 20), L.t("pc_head"), tz("H1"), INK, false, true, 560)
	var w := int(sim.winner) if sim != null else -1
	var res: String = L.t("draw") if w < 0 else L.t("pc_result", [L.t("blue") if w == 0 else L.t("red")])
	var x0 := P.position.x + 630
	var y := P.position.y + 80.0
	_text(Vector2(x0, y), res, tz("H1"), Color("#7a140e"), false, true, 320)
	y += tz("H1") * 1.6
	var lines: Array = [L.t("pc_mode", [_mode_label()]), L.t("pc_time", [_fmt_num(snappedf(sim.tick / 20.0, 0.1))])]
	if w >= 0:
		lines.append(L.t("pc_left", [PZ.rem_pct(sim.power(w), sim.budget_of(w))]))
	var mvp = report.get("mvp")
	if mvp != null:
		lines.append(L.t("pc_mvp", [L.t("unit_%d" % mvp.type), mvp.dmg_dealt]))
	if last_armies.size() == 2:
		lines.append(L.t("pc_armies", [last_armies[0].spent(), last_armies[0].units.size(), last_armies[1].spent(), last_armies[1].units.size()]))
	for ln in lines:
		_text(Vector2(x0, y), ln, tz("B"), INK, false, false, 320)
		y += text_h(ln, tz("B"), 320) + tz("B") * 0.45
	# 下：重播碼（朋友貼上就能看這一場）
	var code := ""
	if last_armies.size() == 2 and not (mode == Mode.PUZZLE and battle_rules != null):
		code = BattleCode.encode(last_armies[0], last_armies[1], battle_rules, last_cmds)
	if code != "":
		# 重播碼不印在卡上（亂碼又會被截斷，Codex／Antigravity v140-i2）：卡上只寫一句，按鈕複製完整的碼
		_text(P.position + Vector2(30, 410), L.t("pc_code"), tz("S"), INK, false, false, 560)
	_ink_mode = false
	# 右上紅色「戰報」印章
	var sp := P.position + Vector2(P.size.x - 84, 70)
	draw_set_transform_matrix(Transform2D(0.2, sp))
	_hand_ring(Vector2.ZERO, 40.0, Color("#8e1b14", 0.95), 5.0)
	_hand_ring(Vector2.ZERO, 33.0, Color("#8e1b14", 0.8), 2.0, false, 2)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var pst := L.t("pc_stamp")
	var psz: int = tz("B") if _width(pst, tz("B"), true) <= 64.0 else tz("C")
	_text(sp - Vector2(0, psz * 0.62), pst, psz, Color("#8e1b14"), true, true, 70)
	if pc_saving:
		return   # 存圖這一格不畫按鈕
	# V1.5.2 L8：明信片下方按鈕同寬、整組置中（原本 300～960 中心 630）
	var nb := 3 if code != "" else 2
	var bx := 640.0 - (nb * 210.0 + (nb - 1) * 10.0) / 2.0
	_btn(Rect2(bx, 670, 210, 46), L.t("pc_save"), func(): _pc_save(), true, true)
	if code != "":
		bx += 220.0
		_btn(Rect2(bx, 670, 210, 46), L.t("pc_copy"), func(): DisplayServer.clipboard_set(code); _toast(L.t("ws_copied")))
	_btn(Rect2(bx + 220.0, 670, 210, 46), L.t("back"), func(): overlay = "")
	probe_align("postcard_btns", [P, Rect2(640.0 - (nb * 210.0 + (nb - 1) * 10.0) / 2.0, 670, nb * 210.0 + (nb - 1) * 10.0, 46)])

func _pc_save() -> void:
	pc_saving = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	pc_saving = false
	if img == null:
		return
	img = img.get_region(Rect2i(150, 90, 980, 560))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://postcards"))
	var fn := "user://postcards/battle_%s_%d.png" % [Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_"), Time.get_ticks_msec() % 1000]
	if img.save_png(fn) != OK:
		_toast(L.t("gif_fail"), true)
		return
	_toast(L.t("pc_saved", [ProjectSettings.globalize_path(fn)]))
