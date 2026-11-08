extends "res://tests/test_base.gd"
## V9 P6：試煉、挑戰碼、AI 性格、遠征獎勵、禁牌、戰績、牌組的核心邏輯。
const GS = preload("res://scripts/ui/game_screens.gd")
const RS9 = preload("res://scripts/core/ruleset.gd")
const SaveS = preload("res://scripts/game/save.gd")
const AI9 = preload("res://scripts/core/ai_army.gd")
const L = preload("res://scripts/game/strings.gd")

func test_modes_v9() -> void:
	var was: bool = SaveS.data_locked
	SaveS.data_locked = true
	var g = GS.new()
	# AI 性格
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var full: int = RS9.full_pool()
	for st in [1, 2, 3, 4]:
		var p: int = AI9.style_pool(full, st, rng)
		ok(p != full and RS9.has_combat(p) and RS9.pool_count(p) <= 10, "性格 %d 限定兵種且有戰鬥兵" % st)
	ok(AI9.style_pool(1 << 7, 1, rng) == 1 << 7, "交集沒有戰鬥兵就用原卡池")
	ok(RS9.has_combat(AI9.style_pool(RS9.all_pool(), 5, rng)), "亂數性格有戰鬥兵")
	# 試煉資料
	var bad: Array = []
	for t in g.TRIALS:
		if int(t[0]) <= 0 or int(t[1]) < 0 or int(t[1]) > 2:
			bad.append(t)
	ok(g.TRIALS.size() == 30 and bad.is_empty(), "試煉 30 關都有新地圖（第十三輪 10→30）", str(bad))
	# 挑戰碼
	var r = RS9.standard()
	r.deploy = "free"
	r.spacing = 800
	r.depth = 6000
	r.map_id = 1
	r.pool = [RS9.all_pool(), RS9.all_pool()]
	var a = Army.new(0, 100)
	a.apply_rules(r, 0)
	ok(a.place_xy(D.SWORD, 3000, 3000) and a.place_xy(D.ARCHER, 2000, 5000), "挑戰碼：擺得下")
	g.rules = r
	g.last_armies = [a, a]
	var code: String = g._challenge_encode()
	ok(code.begins_with("NTC1."), "挑戰碼前綴")
	var d: Dictionary = g._challenge_decode(code)
	ok(d["ok"] and d["army"].team == 1 and d["army"].units.size() == 2 and d["rules"].map_id == 1, "挑戰碼還原陣型與地圖", str(d))
	if d["ok"]:
		ok(Army.pos_of(d["army"].units[0]).x == 16000 - 3000, "挑戰碼的陣型換到紅方鏡像")
	ok(not g._challenge_decode(code + "x")["ok"], "校驗碼錯要拒絕")
	ok(not g._challenge_decode("NTC1.e30." + "e30".sha256_text().substr(0, 6))["ok"], "內容不對要拒絕")
	# 戰績
	SaveS.data["streak"] = 2
	SaveS.data["best_streak"] = 2
	SaveS.data["unit_games"] = {}
	g.armies = [a, a]
	g._record_match(0)
	ok(int(SaveS.data["streak"]) == 3 and int(SaveS.data["best_streak"]) == 3, "贏了連勝加一")
	ok(int(SaveS.data["unit_games"][str(D.SWORD)]) == 1, "記下這場派了誰")
	g._record_match(1)
	ok(int(SaveS.data["streak"]) == 0 and int(SaveS.data["best_streak"]) == 3, "輸了連勝歸零")
	# 存檔型別
	var clean: Dictionary = {"trial_stars": "x", "unit_games": {"1": -5}, "streak": "y", "decks": ["a", 7]}
	SaveS.sanitize_data(clean)
	ok(clean["trial_stars"] is Dictionary and clean["streak"] == 0 and clean["decks"] == [7], "存檔新欄位型別不對就清掉", str(clean))
	# 禁牌
	g.rules = RS9.standard()
	g.rules.pool = [31, 31]
	g.rules.bans = 1
	g.overlay = ""
	g._begin_bans(1)
	ok(g.overlay == "ban" and g.ban_left == [1, 1], "禁牌開始")
	# Codex r1 #6：5 種卡池不會卡死
	g.rules = RS9.standard()
	g.rules.pool = [31, 31]
	g.overlay = ""
	var called: Array = g.ban_left.duplicate()
	ok((RS9.pool_count(31) - 3) / 2 == 1, "5 種卡池每人最多禁 1 張")
	# Codex r1 #10：讓子局的挑戰碼藍紅對調
	var r3 = RS9.standard()
	r3.handicap = true
	r3.budget = [200, 30]
	r3.pool = [RS9.all_pool(), RS9.all_pool()]
	var a3 = Army.new(0, 200)
	a3.apply_rules(r3, 0)
	for i3 in 8:
		a3.place(D.CAVALRY, i3 % 6, i3 % 9)
	g.rules = r3
	g.last_armies = [a3, a3]
	var d3: Dictionary = g._challenge_decode(g._challenge_encode())
	ok(d3["ok"] and d3["rules"].budget_of(1) == 200 and d3["rules"].budget_of(0) == 30, "讓子局挑戰碼：對方的預算跟著他走", str(d3))
	# Codex r1 #5
	g.challenge_army = a3
	g.rules = null
	g.set("sfx", null)
	ok(g.challenge_army != null, "挑戰碼的敵陣有記著")
	SaveS.data_locked = was
	g.free()

## 真的走一遍畫面流程（不開視窗）：試煉、挑戰碼、遠征獎勵、禁牌、地圖戰鬥、重播。
func _fight(g) -> void:
	g._on_start()
	var guard := 0
	while g.state != g.St.RESULT and guard < 12000:
		guard += 1
		if g.view != null and not g.view.finished:
			g._sim_step(false)
		else:
			g._finish_battle()
			break

func _place_some(g, n := 6) -> void:
	var a = g.armies[0]
	var ts0 := [D.SWORD, D.ARCHER, D.SHIELD]
	var i := 0
	var y := 800
	while a.units.size() < n and y < a.fh - 400:
		a.place_xy(int(ts0[i % 3]), a.world_x(Army.quant(mini(a.depth - 200, 3000))), Army.quant(y))
		i += 1
		y += 1000

func test_flows_v9() -> void:
	var was: bool = SaveS.data_locked
	SaveS.data_locked = true
	var saved_stars = SaveS.data.get("trial_stars", {})
	var g = GS.new()
	g.sfx = FakeSfx.new()
	g.time = 1.0
	# 試煉：每一關都開得起來，AI 用對性格，地圖正確
	var bad: Array = []
	for i in g.TRIALS.size():
		g._start_trial(i)
		var t: Array = g.TRIALS[i]
		if g.trial_id != i or g.rules.map_id != int(t[0]) or g.rules.map_size != int(t[1]) or g.mode != g.Mode.VS_AI or g.armies[0].fw != g.rules.field_w():
			bad.append("第 %d 關狀態不對" % i)
		g._build_ai()     # AI 是開戰時才排（不偷看），這裡直接叫
		if g.armies[1].units.is_empty():
			bad.append("第 %d 關 AI 沒兵" % i)
		for u in g.armies[1].units:
			var p: Vector2i = Army.pos_of(u)
			if g.rules.terrain().blocked(p.x, p.y, 1):
				bad.append("第 %d 關 AI 站在牆裡" % i)
	ok(bad.is_empty(), "試煉 10 關都開得起來，AI 有兵、不站牆裡", str(bad))
	# 打完一關：有星、記錄
	SaveS.data["trial_stars"] = {}
	g._start_trial(0)
	_place_some(g, 8)
	var n0: int = g.armies[0].units.size()
	ok(n0 >= 5, "試煉能擺兵", str(n0))
	_fight(g)
	ok(g.state == g.St.RESULT and g.sim.finished and g.sim.tick > 20 and g.sim.alive_count(1) + g.sim.alive_count(0) > 0, "試煉打得完，進到結果頁", "tick %d 原因 %s 我方 %d 敵方 %d 部署 %s/%s 狀態 %d" % [g.sim.tick, g.sim.reason, g.sim.alive_count(0), g.sim.alive_count(1), g.armies[0].deploy, g.armies[1].deploy, g.state])
	# 不管這場誰贏，直接驗星數規則
	SaveS.data["trial_stars"] = {}
	g.report = {}
	g._trial_finish(1)
	ok(not g.report.has("trial_stars") and SaveS.data["trial_stars"].is_empty(), "輸了沒有星")
	g._trial_finish(0)
	ok(g.report.has("trial_stars") and int(SaveS.data["trial_stars"]["0"]) == int(g.report["trial_stars"]), "贏了有星，也記進存檔", str(g.report))
	# 挑戰碼：下一場對手就是這個陣型；開試煉後清掉
	var code: String = g._challenge_encode()
	DisplayServer.clipboard_set(code)
	var d: Dictionary = g._challenge_decode(code)
	ok(d["ok"], "結果頁的挑戰碼解得開", str(d))
	g.rules = d["rules"]
	g.challenge_army = d["army"]
	g._start_mode(g.Mode.VS_AI)
	g._build_ai()
	ok(g.armies[1].units.size() == d["army"].units.size(), "接受挑戰：對手是朋友的陣型")
	g._start_trial(1)
	ok(g.challenge_army == null, "開試煉會清掉挑戰碼的敵陣")
	# 遠征獎勵
	g.overlay = ""
	g._start_mode(g.Mode.GAUNTLET)
	g.last_armies = [g.armies[0].copy(), g.armies[1].copy()]
	var b0: int = g.armies[0].budget
	var c0: int = g.armies[0].unit_cap
	g._gauntlet_reward()
	ok(g.overlay == "reward", "遠征贏了跳獎勵")
	g._take_reward(0)
	ok(g.overlay == "" and g.gauntlet_stage == 2 and g.armies[0].budget == b0 + 10, "選多 10 金進下一戰", "%d %d" % [g.armies[0].budget, b0])
	g.last_armies = [g.armies[0].copy(), g.armies[1].copy()]
	g._take_reward(1)
	ok(g.armies[0].unit_cap == c0 + 2 and g.armies[0].budget == b0 + 10, "獎勵會累積", "%d" % g.armies[0].unit_cap)
	# 禁牌走完
	g.rules = RS9.standard()
	g.rules.pool = [RS9.all_pool(), RS9.all_pool()]
	g.rules.place_rule = "snake5"
	g._begin_bans(1)
	var before: int = RS9.pool_count(g.rules.pool_of(0))
	g._ban(D.SWORD)
	ok(g.ban_turn == 1 and g.overlay == "ban", "藍方禁完換紅方")
	g._ban_skip()
	ok(g.overlay == "" and g.mode == g.Mode.DUEL and RS9.pool_count(g.rules.pool_of(0)) == before - 1, "雙方都用完就開打")
	# 5 種卡池不卡死
	g.rules = RS9.standard()
	g.rules.pool = [31, 31]
	g.overlay = ""
	g._begin_bans(2)
	ok(g.ban_left == [1, 1], "5 種卡池自動少禁")
	# 地圖換局
	g.overlay = ""
	var r = RS9.standard()
	r.deploy = "free"
	r.spacing = 800
	r.depth = 6000
	r.map_id = 1
	r.map_mode = 1
	r.pool = [RS9.all_pool(), RS9.all_pool()]
	g.rules = r
	g._start_mode(g.Mode.VS_AI)
	_place_some(g, 6)
	_fight(g)
	var m0: int = g.rules.map_id
	if not g.series_over:
		g._next_round()
		ok(g.rules.map_id == wrapi(m0 + 1, 0, 6) and g.armies[0].fw == g.rules.field_w(), "輪替：下一局換地圖")
	# 重播
	g._replay()
	ok(g.sim != null and g.sim.fw == g.rules.field_w(), "地圖戰鬥能重播")
	SaveS.data["trial_stars"] = saved_stars
	SaveS.data_locked = was
	g.free()

## 第十輪批次 A：每條對應方案的 B 編號。
func test_v10_fixes() -> void:
	var was: bool = SaveS.data_locked
	SaveS.data_locked = true
	var g = GS.new()
	g.sfx = FakeSfx.new()
	g.time = 1.0
	# B1：困難 AI 要吃性格
	for st in [1, 2, 3, 4]:
		var r = RS9.standard()
		r.deploy = "free"
		r.spacing = 800
		r.depth = 6000
		r.pool = [RS9.full_pool(), RS9.full_pool()]
		r.ai_pool_same = false
		r.ai_level = 2
		r.ai_style = st
		r.preset = "custom"
		g.rules = r
		g.challenge_army = null
		g.rng.seed = 40 + st
		g._start_mode(g.Mode.VS_AI)
		g.difficulty = 2
		g._build_ai()
		var off: Array = []
		for u in g.armies[1].units:
			if not int(u["type"]) in AI9.STYLE_TYPES[st]:
				off.append(int(u["type"]))
		ok(off.is_empty() and not g.armies[1].units.is_empty(), "B1 困難 AI 性格 %d 的兵都在性格卡池內" % st, str(off))
	# B2：禁牌格子不能超出面板
	for n in [5, 10, 11, 15, 20]:
		var panel: Rect2 = g._ban_panel(n)
		var cells: Array = []
		var good := true
		for i in n:
			var c: Rect2 = g._ban_cell(i, n)
			good = good and panel.encloses(c)
			for o in cells:
				good = good and not c.intersects(o)
			cells.append(c)
		ok(good, "B2 %d 張禁牌都在面板內且不重疊" % n)
	# B3：大廳系列選項存讀往返
	var sd := {"last_rules": {"ai": "NTBR4.x", "ai_extra": [1, 2, 1, 0], "bad_extra": ["a"], "worse_extra": [1, 2, 3, 4, 5, 6, 7, 8, 9], "num": 3}}
	SaveS.sanitize_data(sd)
	ok(sd["last_rules"].get("ai_extra") == [1, 2, 1, 0], "B3 系列選項留下來", str(sd["last_rules"]))
	ok(not sd["last_rules"].has("bad_extra") and not sd["last_rules"].has("worse_extra") and not sd["last_rules"].has("num") and sd["last_rules"]["ai"] == "NTBR4.x", "B3 壞資料丟掉")
	# B5：戰報要列得到奇幻兵
	var dealt: Array = [D.zeros(), D.zeros()]
	var taken: Array = [D.zeros(), D.zeros()]
	dealt[0][13] = 500
	dealt[1][17] = 400
	var rows: Array = GS.report_rows(dealt, taken)
	ok(13 in rows and 17 in rows, "B5 戰報列得到奇幻兵", str(rows))
	# B6：環境音跟著音效音量
	var SfxS = load("res://scripts/game/sfx.gd")
	var sx = SfxS.new()
	sx.music = AudioStreamPlayer.new()
	sx.amb = AudioStreamPlayer.new()
	sx.set_volumes(0, 50)
	ok(sx.amb.volume_db <= -60.0, "B6 音效 0 時環境音靜音", str(sx.amb.volume_db))
	sx.set_volumes(100, 50)
	ok(sx.amb.volume_db > -30.0, "B6 音效開回來環境音也回來", str(sx.amb.volume_db))
	# V1.2.1 E1：四條音量各自獨立（介面音不再跟音效共用增益）
	sx.set_volumes(80, 50, 0, 100)
	ok(sx.gain_for("k_click") == 0.0 and absf(sx.gain_for("slash") - 0.8) < 0.001, "E1 介面音 0 不影響音效", "%s %s" % [sx.gain_for("k_click"), sx.gain_for("slash")])
	sx.set_volumes(0, 50, 70, 100)
	ok(sx.gain_for("slash") == 0.0 and absf(sx.gain_for("ui_click") - 0.7) < 0.001 and sx.amb.volume_db > -30.0, "E1 音效 0 時介面音、環境音照常", str(sx.amb.volume_db))
	sx.set_volumes(80, 50, 80, 0)
	ok(sx.amb.volume_db <= -60.0, "E1 環境音可單獨靜音", str(sx.amb.volume_db))
	sx.music.free()
	sx.amb.free()
	sx.free()
	# B7：試玩版不能用挑戰碼帶進正式版兵
	var r7 = RS9.standard()
	r7.deploy = "free"
	r7.spacing = 800
	r7.depth = 6000
	r7.pool = [511 | (1 << 19), 511 | (1 << 19)]    # 每邊最多 10 種
	g.rules = r7
	g.challenge_army = null
	g._start_mode(g.Mode.VS_AI)
	var a7 = g.armies[0]
	a7.pool = RS9.full_pool()
	a7.place_xy(19, a7.world_x(2000), 4000)
	a7.place_xy(0, a7.world_x(3000), 4000)
	ok(a7.units.size() == 2, "B7 測試陣型擺得下", str(a7.units))
	g.last_armies = [a7, a7.copy()]
	var code7: String = g._challenge_encode()
	ok(g._challenge_decode(code7)["ok"], "B7 正式版可以接")
	g.force_demo = true
	ok(not g._challenge_decode(code7)["ok"], "B7 試玩版拒收正式版兵的挑戰碼")
	g.force_demo = false
	# B4：自訂規則贏了也算圖鑑筆記；雙人兩邊都算場數
	var uw0 = SaveS.data.get("unit_wins", {})
	var ug0 = SaveS.data.get("unit_games", {})
	SaveS.data["unit_wins"] = {}
	var r4 = RS9.standard()
	r4.deploy = "free"
	r4.spacing = 800
	r4.depth = 6000
	r4.pool = [RS9.full_pool(), RS9.full_pool()]
	r4.map_id = 1
	r4.preset = "custom"
	g.rules = r4
	g.challenge_army = null
	g._start_mode(g.Mode.VS_AI)
	g.armies[0].units = [{"type": 13, "x": 2000, "y": 4000}, {"type": 0, "x": 3000, "y": 4000}]
	g.armies[1].units = [{"type": 0, "x": 13000, "y": 4000}]
	g.sim = load("res://scripts/core/battle_sim.gd").new(g.armies[0].copy(), g.armies[1].copy(), r4)
	g.sim.winner = 0
	g.report = {"sus": {"max_swing_pct": 0}}
	g._progress_and_achievements()
	ok(int(SaveS.data["unit_wins"].get("13", 0)) == 1, "B4 自訂規則贏了奇幻兵有勝場", str(SaveS.data["unit_wins"]))
	SaveS.data["unit_games"] = {}
	g.mode = g.Mode.DUEL
	g.armies[1].units = [{"type": 5, "x": 13000, "y": 4000}]
	g._record_match(1)
	ok(int(SaveS.data["unit_games"].get("5", 0)) == 1 and int(SaveS.data["unit_games"].get("13", 0)) == 1, "B4 雙人兩邊的兵都算場數", str(SaveS.data["unit_games"]))
	SaveS.data["unit_wins"] = uw0
	SaveS.data["unit_games"] = ug0
	# B9：場地下移，貼上緣的兵頭不被頂列蓋住
	ok(GS.ORIGIN.y + 200.0 / 1000.0 * GS.CS + g.BATTLE_DY - 62.0 >= 86.0, "B9 上緣士兵的頭在頂列下面")
	# B10：系列中途離開要確認
	g.rules = RS9.standard()
	g.overlay = ""
	g._start_mode(g.Mode.VS_AI)
	g.state = g.St.PLACE
	g.wins = [0, 0]
	g.series_over = false
	g._request_leave()
	ok(g.state == g.St.TITLE and g.overlay == "", "B10 第一局沒比分，直接離開")
	g._start_mode(g.Mode.VS_AI)
	g.wins = [1, 0]
	g.series_over = false
	g._request_leave()
	ok(g.overlay == "leave" and g.state != g.St.TITLE, "B10 有比分要先確認")
	g.overlay = ""
	ok(g.state != g.St.TITLE, "B10 取消就留在原地")
	g._request_leave()
	g._leave_confirm()
	ok(g.state == g.St.TITLE and g.overlay == "", "B10 確認才離開")
	g._start_mode(g.Mode.GAUNTLET)
	g.gauntlet_stage = 3
	g._request_leave()
	ok(g.overlay == "leave", "B10 遠征第 3 戰要確認")
	g.overlay = ""
	SaveS.data_locked = was
	g.free()

## 第十輪批次 B：手把提示、代碼輸入、背景計算、遠征存點。
func test_v10_input() -> void:
	var was: bool = SaveS.data_locked
	SaveS.data_locked = true
	var K = load("res://scripts/game/keymap.gd")
	ok(K.pad_glyph({}, "place", "") == "A" and K.pad_glyph({}, "back", "Steam Deck") == "B", "I1 Deck／Xbox 顯示 A、B")
	ok(K.pad_glyph({}, "place", "DualSense Wireless Controller") == "×", "I1 PS 手把顯示 ×")
	ok(K.pad_glyph({}, "place", "Nintendo Switch Pro") == "B", "I1 Switch 手把確定鍵是 B 字樣")
	ok(K.pad_glyph({"place": JOY_BUTTON_Y}, "place", "") == "Y", "I1 重綁後提示跟著變")
	var g = GS.new()
	g.sfx = FakeSfx.new()
	g.time = 1.0
	g.pad_mode = true
	var pad0 = SaveS.settings.get("pad", {})
	SaveS.settings["pad"] = {"place": JOY_BUTTON_Y}
	g.state = g.St.TITLE
	g.overlay = "settings"
	ok(g._pad_footer_items()[0][0] == "Y", "I1 提示列讀重綁設定", str(g._pad_footer_items()))
	SaveS.settings["pad"] = pad0
	g.overlay = ""
	# I3：手把貼不上時不能安靜地失敗
	DisplayServer.clipboard_set("not a code")
	g._accept_challenge()
	ok(g.toast == L.t("bc_pad_hint"), "I3 手把貼挑戰碼失敗會提示用鍵盤", g.toast)
	g.toast = ""
	g.lobby_r = RS9.standard()
	g._lobby_paste_code()
	ok(g.toast == L.t("bc_pad_hint"), "I3 手把貼規則碼失敗會提示用鍵盤", g.toast)
	g.pad_mode = false
	g._accept_challenge()
	ok(g.toast == L.t("ch_bad"), "I3 滑鼠維持原提示", g.toast)
	# I4：重播全長在背景算，結果和同步一樣
	var rf = RS9.standard()
	rf.deploy = "free"
	rf.spacing = 800
	rf.depth = 6000
	g.rules = rf
	g.challenge_army = null
	g._start_mode(g.Mode.VS_AI)
	_place_some(g, 6)
	g._build_ai()
	var ra0 = g.armies[0].copy()
	var ra1 = g.armies[1].copy()
	g._begin_battle(ra0.copy(), ra1.copy(), "replay")
	var sync_total: int = g.replay_total
	g.force_async = true
	g.replay_total = 0
	g._begin_battle(ra0.copy(), ra1.copy(), "replay")
	ok(g.pre_thread != null, "I4 重播改背景算")
	g._pre_join()
	ok(g.pre_thread == null and g.replay_total == sync_total and sync_total > 0, "I4 背景算的全長相同", "%d %d" % [sync_total, g.replay_total])
	g.force_async = false
	# I4：困難 AI 背景算，和同步同一支隊伍
	var rr = RS9.standard()
	rr.ai_level = 2
	rr.preset = "custom"
	g.rules = rr
	g._start_mode(g.Mode.VS_AI)
	_place_some(g, 6)
	g.difficulty = 2
	g.round_no = 2
	g.last_player_formation = g.armies[0].units.duplicate(true)
	g.rng.seed = 77
	g._build_ai()
	var sync_code: String = g.armies[1].to_code()
	g.force_async = true
	g.rng.seed = 77
	ok(g._build_ai_async() and g.overlay == "ai_busy", "I4 困難 AI 改背景算")
	g.ai_thread.wait_to_finish()
	g.ai_thread = null
	g.overlay = ""
	g.rng.seed = 77
	g._build_ai_async()
	while g.ai_thread.is_alive():
		OS.delay_msec(5)
	g.force_async = false
	g._ai_poll()
	ok(g.ai_thread == null and g.overlay == "" and g.state == g.St.BATTLE and g.last_armies != null, "I4 算完自動開戰")
	ok(g.armies[1].to_code() == sync_code, "I4 背景算和同步同一支隊伍")
	# I5：遠征存點
	g.rules = null
	g._start_mode(g.Mode.GAUNTLET)
	_place_some(g, 6)
	g.last_armies = [g.armies[0].copy(), g.armies[1].copy()]
	g._take_reward(0)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(SaveS.data["gauntlet_run"]))
	ok(int(saved["stage"]) == 2 and int(saved["gold"]) == 10, "I5 戰間有存點", str(saved))
	var enemy: String = g.armies[1].to_code()
	var bud: int = g.armies[0].budget
	var n: int = g.armies[0].units.size()
	var g2 = GS.new()
	g2.sfx = FakeSfx.new()
	g2.time = 1.0
	SaveS.data["gauntlet_run"] = SaveS.sanitize_run(saved)
	g2._enter_gauntlet()
	ok(g2.overlay == "gauntlet_resume", "I5 有存點先問要不要接著打")
	g2._gauntlet_resume()
	ok(g2.mode == g2.Mode.GAUNTLET and g2.gauntlet_stage == 2 and g2.armies[0].budget == bud and g2.armies[0].units.size() == n and g2.overlay == "", "I5 接回來狀態相同")
	ok(g2.armies[1].to_code() == enemy, "I5 接回來對手相同")
	ok(SaveS.sanitize_run({"stage": "x"}).is_empty() and SaveS.sanitize_run({"stage": 99, "seed": 1, "gold": 0, "cap": 0, "changes": 3, "pool": 0, "prev": []}).is_empty(), "I5 壞存點當沒有")
	var good_u := {"type": 0, "col": 3, "row": 4}
	var base := {"stage": 3, "seed": 1, "gold": 0, "cap": 0, "changes": 3, "pool": 1023}
	var rg: Dictionary = base.duplicate()
	rg["prev"] = [good_u]
	ok(not SaveS.sanitize_run(rg).is_empty(), "I5 合法存點留下")
	for bad_u in [{"type": 0}, {"type": 99, "col": 1, "row": 1}, {"type": 0, "col": 99, "row": 1}, {"type": 0, "x": -5, "y": 3}]:
		var rb: Dictionary = base.duplicate()
		rb["prev"] = [bad_u]
		ok(SaveS.sanitize_run(rb).is_empty(), "I5 壞兵的存點不要", str(bad_u))
	# Codex #2：存實際卡池，之後改大廳不影響
	var pool_at_save: int = int(saved["pool"])
	ok(pool_at_save > 0, "I5 存的是實際卡池", str(pool_at_save))
	g2._gauntlet_clear()
	g2.free()
	# Codex #3：還沒算完就返回，不等它
	g.force_async = true
	g._begin_battle(ra0.copy(), ra1.copy(), "replay")
	var th: Thread = g.pre_thread
	g._replay_back()
	ok(g.pre_thread == null and (th in g.pre_old or g.pre_old.is_empty()), "I4 返回不等背景工作")
	g._exit_tree()
	ok(g.pre_old.is_empty(), "I4 關閉時全部收回")
	g.force_async = false
	g.free()
	SaveS.data["gauntlet_run"] = {}
	SaveS.data_locked = was

func _final_case(g) -> Array:
	var r = RS9.standard()
	r.deploy = "free"
	r.spacing = 800
	r.depth = 6000
	g.rules = r
	g.challenge_army = null
	g._start_mode(g.Mode.VS_AI)
	var a0 = g.armies[0]
	for y in [2000, 3000, 4000, 5000, 6000, 7000]:
		a0.place_xy(D.SWORD, a0.world_x(5500), y)
	var a1 = g.armies[1]
	a1.place_xy(D.SWORD, a1.world_x(5500), 4500)
	return [a0, a1]

## 第十輪批次 C：最後一擊只改畫面。
func test_v10_feel() -> void:
	var was: bool = SaveS.data_locked
	SaveS.data_locked = true
	var g = GS.new()
	g.sfx = FakeSfx.new()
	g.time = 1.0
	var ar: Array = _final_case(g)
	var fast = Sim.new(ar[0].copy(), ar[1].copy(), g.rules)
	fast.fast = true
	fast.run_to_end()
	ok(fast.winner == 0 and fast.reason == "全滅", "測試場次是碾壓", str(fast.reason))
	var fx0 = SaveS.settings.get("reduce_fx", false)
	var sm0 = SaveS.settings.get("slowmo", true)
	SaveS.settings["reduce_fx"] = false
	SaveS.settings["slowmo"] = true
	g._begin_battle(ar[0].copy(), ar[1].copy(), "official")
	g.start_hold = 0.0
	var saw_slow := false
	var guard := 0
	while not g.view.finished and guard < 20000:
		guard += 1
		g._battle_process(0.05)
		g.time += 0.05
		saw_slow = saw_slow or g.final_left > 0.0
	ok(saw_slow and g.final_used, "F1 碾壓局有最後一擊慢動作")
	ok(g.final_left <= 0.6, "F1 慢動作時間有上限")
	g.final_left = 0.3
	g._seek(10)
	ok(not g.final_used and g.final_left == 0.0, "F1 跳回前段會清掉最後一擊狀態", "%s %s" % [g.final_used, g.final_left])
	while not g.view.finished and guard < 40000:     # 跳完播到結尾，指紋不受影響
		guard += 1
		g._sim_step(false)
	var fp_show: String = g.sim.fingerprint
	var tick_show: int = g.sim.tick
	# 跳過：立刻算完，不演；演不演都是同一場
	g._begin_battle(ar[0].copy(), ar[1].copy(), "official")
	g._on_skip()
	ok(g.view.finished and g.final_left == 0.0 and not g.final_used, "F1 直接看結果不演")
	ok(g.sim.fingerprint == fp_show and g.sim.tick == tick_show and g.sim.tick == fast.tick, "F1 不影響模擬", "%s %s" % [g.sim.fingerprint, fp_show])
	# 簡化特效：不慢放
	SaveS.settings["reduce_fx"] = true
	g._begin_battle(ar[0].copy(), ar[1].copy(), "official")
	g.start_hold = 0.0
	saw_slow = false
	guard = 0
	while not g.view.finished and guard < 20000:
		guard += 1
		g._battle_process(0.05)
		saw_slow = saw_slow or g.final_left > 0.0
	ok(not saw_slow, "F1 簡化特效不慢放")
	SaveS.settings["reduce_fx"] = fx0
	SaveS.settings["slowmo"] = sm0
	# F4：差一點才主推覆盤
	g.sim.winner = 1
	g.last_armies = [ar[0], ar[1]]
	ok(g._near_miss() == (g.sim.power(1) * 100 < g.sim.budget_of(1) * 1000 * 15), "F4 差一點的判定")
	g.sim.winner = 0
	ok(not g._near_miss(), "F4 贏了不算")
	g.free()
	SaveS.data_locked = was

## 第十輪 T4、R1：試玩版的範圍。
func test_v10_demo() -> void:
	var was: bool = SaveS.data_locked
	SaveS.data_locked = true
	var g = GS.new()
	g.sfx = FakeSfx.new()
	g.time = 1.0
	g.force_demo = true
	var P = load("res://scripts/game/presets.gd")
	g.overlay = ""
	g._enter_gauntlet()
	ok(g.overlay == "" and g.toast == L.t("demo_locked"), "R1 試玩版不開遠征")
	g.toast = ""
	g._start_trial(1)
	ok(g.toast == L.t("demo_locked") and g.trial_id != 1, "R1 不開的試煉進不去")
	var mask: int = load("res://scripts/game/roster.gd").mask(true)
	for i in P.DEMO_TRIALS:
		g._start_trial(i)
		ok(g.trial_id == i and g.rules.map_id in P.DEMO_MAPS, "R1 試煉 %d 開得起來、地圖有開放" % i)
		g._build_ai()
		var off: Array = []
		for u in g.armies[1].units:
			if not RS9.has(mask, int(u["type"])):
				off.append(int(u["type"]))
		ok(off.is_empty() and not g.armies[1].units.is_empty(), "R1 試煉 %d 對手沒有正式版兵" % i, str(off))
	g._open_lobby("ai")
	for _i in 8:
		g._lobby_adj("map", 1)
		ok(g.lobby_r.map_id in P.DEMO_MAPS, "R1 大廳換圖只有開放的", str(g.lobby_r.map_id))
	g.lobby_r.ai_level = 1
	g._lobby_adj("ai_level", 1)
	ok(g.lobby_r.ai_level == 1, "R1 大廳選不到困難")
	for _j in 20:
		g._lobby_random()
		ok(g.lobby_r.map_id in P.DEMO_MAPS and g.lobby_r.ai_level <= 1, "R1 隨機一切不超出範圍")
	g.lobby_r.map_id = 0
	g.lobby_r.ai_level = 0
	var ok_block: String = g._lobby_block()
	g.lobby_r.map_id = 4
	g.lobby_r.deploy = "free"
	ok(g._lobby_block() == L.t("demo_locked") and ok_block != L.t("demo_locked"), "R1 貼上不開放的地圖不能開打", ok_block)
	g.free()
	SaveS.data_locked = was

## 選卡時的兵種簡介。
func test_unit_brief() -> void:
	var g = GS.new()
	g.sfx = FakeSfx.new()
	g.time = 1.0
	for t in D.total():
		var st: Array = g._brief_stats(t)
		var good: bool = st.size() == 4
		for v in st:
			good = good and v >= 0.0 and v <= 1.0
		ok(good, "兵種 %d 四條比較條都在 0～1" % t, str(st))
		var m: Dictionary = g._brief_matchups(t)
		ok(m["good"] is Array and m["bad"] is Array, "兵種 %d 剋制資料" % t)
		ok(L.t("blurb_%d" % t) != "blurb_%d" % t and g._brief_role(t) != "", "兵種 %d 有一句話和定位" % t, g._brief_role(t))
	var hi: Array = g._brief_stats(19)
	var lo: Array = g._brief_stats(10)
	ok(hi[0] > g._brief_stats(16)[0], "石魔血比沙漏厚")
	ok(lo[3] == 0.0, "孢子菇不會動，速度條是空的")
	ok(g._brief_stats(17)[2] > g._brief_stats(0)[2], "骷髏法師射程比劍士遠")
	# 沒指到任何卡時：顯示卡池第一張；指過就記住
	g.lobby_brief = -1
	ok(g._brief_pick([3, 5], -1) == 3, "預設顯示第一張")
	ok(g._brief_pick([3, 5], 5) == 5, "指到哪張顯示哪張")
	g.lobby_brief = 5
	ok(g._brief_pick([3, 5], -1) == 5, "移開後留在上一張")
	ok(g._brief_pick([3, 7], -1) == 3, "上一張已不在清單就回第一張")
	# 滑鼠指到或手把焦點都算
	var cell := Rect2(100, 100, 50, 50)
	g.pad_mode = false
	g.mouse = Vector2(120, 120)
	ok(g._brief_hot(cell), "滑鼠指到")
	g.mouse = Vector2(10, 10)
	ok(not g._brief_hot(cell), "滑鼠沒指到")
	g.pad_mode = true
	g._btns = [{"r": cell, "cb": func(): pass, "en": true}]
	g._focus = 0
	ok(g._brief_hot(cell), "手把焦點在這顆")
	g._focus = 5
	ok(not g._brief_hot(cell), "手把焦點在別顆")
	g._btns = []
	g.free()

## 第十一輪：不靠場數解鎖。全新存檔一開始就全部能用；試玩版是版本差異。
func test_no_unlock() -> void:
	var was: bool = SaveS.data_locked
	SaveS.data_locked = true
	var saved: Dictionary = SaveS.data.duplicate(true)
	var RSTR = load("res://scripts/game/roster.gd")
	var P = load("res://scripts/game/presets.gd")
	SaveS.data["unlock_games"] = 0
	SaveS.data["tutorial"] = 0
	SaveS.data["unit_wins"] = {}
	SaveS.data["last_rules"] = {}
	SaveS.data["gauntlet_pool"] = 0
	ok(RSTR.mask() == RS9.full_pool(), "全新存檔 20 種全開")
	var dm: int = RSTR.mask(true)
	ok(RS9.pool_count(dm) == 8 and RS9.has(dm, 11) and not RS9.has(dm, 7), "試玩版固定舊 7 種＋爆爆羊")
	ok(RSTR.available(19) and not RSTR.available(19, true) and RSTR.available(11, true), "正式版都能用；試玩版看內容")
	var g = GS.new()
	g.sfx = FakeSfx.new()
	g.time = 1.0
	# 大廳：預設標準是 10 種王國軍，20 種都選得到，沒有鎖住的兵
	g._open_lobby("ai")
	ok(g.lobby_r.pool_of(0) == RS9.all_pool(), "第一次開大廳是王國軍 10 種", str(g.lobby_r.pool_of(0)))
	ok(P.selectable("ai", g._lobby_unlocked(), false) == RS9.full_pool(), "第一次開大廳 20 種都選得到")
	ok(g._lobby_locked_units().is_empty() and g._lobby_block() == "", "第一次開大廳就能開打", g._lobby_block())
	g._lobby_pick("fantasy")
	ok(g.lobby_r.pool_of(0) == RS9.full_pool() - RS9.all_pool(), "奇幻兵團是 10 種奇幻軍", str(g.lobby_r.pool_of(0)))
	# 不用打場數的快速對戰、遠征
	g.rules = null
	g._start_mode(g.Mode.VS_AI)
	ok(g._ntypes() == 10 and g._pool() == RS9.all_pool(), "快速對戰 10 種全開")
	for t in 10:
		ok(g._allowed(t), "兵種 %d 第一場就能用" % t)
	g._start_mode(g.Mode.GAUNTLET)
	ok(RS9.pool_count(g._gauntlet_pool()) == 10, "遠征第一次就有 10 種")
	# 舊存檔：以前存的「標準」只有 7 種，要變回 10 種
	var old = RS9.standard(127)
	SaveS.data["last_rules"] = {"ai": old.to_code(), "ai_preset": "standard"}
	g._open_lobby("ai")
	ok(g.lobby_r.pool_of(0) == RS9.all_pool(), "舊存檔的標準卡池補回 10 種", str(g.lobby_r.pool_of(0)))
	# 打完不跳解鎖提示，設定沒有全部解鎖
	g.settings_tab = 2
	var names: Array = []
	for row in g._settings_rows():
		names.append(row[0])
	ok(not "set_unlock_all" in names, "設定沒有全部解鎖", str(names))
	ok(L.t("unlock_next") == "unlock_next" and L.t("unit_unlocked") == "unit_unlocked" and L.t("locked_games") == "locked_games", "解鎖提示文字都拿掉了")
	# 圖鑑老兵筆記不用贏也看得到；勝場照記（戰績頁用）
	var CXN = load("res://scripts/game/codex.gd")
	var sd := {}
	CXN.record_win(sd, [D.SWORD, D.SWORD, D.ARCHER])
	ok(CXN.wins_with(sd, D.SWORD) == 1 and CXN.wins_with(sd, D.ARCHER) == 1, "勝場照記，同場同種只算一次")
	g.free()
	SaveS.data = saved
	SaveS.data_locked = was

# ── 第十二輪：手動技能 ──
const CMD = preload("res://scripts/core/cmd_defs.gd")
const BC = preload("res://scripts/game/battle_code.gd")
const MC9 = preload("res://scripts/core/mirror_check.gd")

func _cmd_rules(mask := 7, uses := 2):
	var r = RS9.standard()
	r.deploy = "free"
	r.spacing = 800
	r.depth = 6000
	r.pool = [1023, 1023]
	r.ai_pool_same = false
	r.cmd_mask = [mask, mask]
	r.cmd_uses = uses
	r.cmd_cd = 200
	r.cmd_power = 100
	return r

func _cmd_army(team: int, r, types := [D.SWORD, D.ARCHER, D.SHIELD, D.SWORD, D.CAVALRY, D.ARCHER]):
	var a = Army.new(team, r.budget_of(team))
	a.apply_rules(r, team)
	a.pool = RS9.full_pool()
	var y := 1500
	for t in types:
		a.place_xy(int(t), a.world_x(5000), y)
		y += 1000
	return a

func _hp(s, team: int) -> int:
	var h := 0
	for u in s.units:
		if u.team == team and u.alive:
			h += u.hp
	return h

func test_cmd_sim() -> void:
	var r = _cmd_rules()
	ok(not r.sim_is_legacy() and r.validate().is_empty(), "開技能不走舊路徑", str(r.validate()))
	var off = r.copy()
	off.cmd_mask = [0, 0]
	ok(not off.cmd_on(), "雙方都 0 就是關閉")
	ok(RS9.standard().to_code().begins_with("NTBR1") or not RS9.standard().to_code().begins_with("NTBR5"), "沒開技能規則碼不變")
	# 規則碼往返
	var code: String = r.to_code()
	ok(code.begins_with("NTBR5"), "有技能用 NTBR5", code.substr(0, 6))
	var d: Dictionary = RS9.from_code(code)
	ok(d["ok"] and d["rules"].cmd_mask == [7, 7] and d["rules"].cmd_uses == 2 and d["rules"].cmd_cd == 200 and d["rules"].cmd_power == 100, "規則碼往返", str(d.get("why")))
	ok(d["ok"] and d["rules"].deploy == "free" and d["rules"].spacing == 800, "規則碼保留部署")
	var bad = r.copy()
	bad.cmd_mask = [63, 1]
	ok(not bad.validate().is_empty(), "不合法的技能遮罩擋下")
	var r3 = _cmd_rules(7, 1)
	r3.cmd_mask = [7, 15]
	ok(not r3.validate().is_empty(), "一邊最多帶 3 種")
	# 次數、開場限制、冷卻
	var s = Sim.new(_cmd_army(0, r), _cmd_army(1, r), r)
	ok(not s.cast(0, CMD.AEGIS), "開場 3 秒不能用")
	while s.tick < CMD.START_TICKS:
		s.step()
	ok(s.cast(0, CMD.AEGIS), "3 秒後能用")
	ok(not s.cast(0, CMD.AEGIS), "同一招不能重複排")
	var hp0 := 0
	for u in s.units:
		if u.team == 0:
			hp0 = u.max_hp
			break
	s.step()
	var shielded := true
	for u in s.units:
		if u.team == 0 and u.alive and u.shield != u.max_hp * CMD.AEGIS_PCT / 100:
			shielded = false
		if u.team == 1 and u.shield != 0:
			shielded = false
	ok(shielded and s.cmd_log.size() == 1 and hp0 > 0, "全員護盾：只有我方有盾，數值正確")
	ok(not s.cast(0, CMD.AEGIS), "冷卻中不能再用")
	# 護盾先吃傷害
	var victim = s.units[0]
	var hp_before: int = victim.hp
	victim.shield = 1000
	s._cmd_dmg.fill(0)
	var guard := 0
	while victim.alive and victim.shield == 1000 and guard < 400:
		guard += 1
		s.step()
	ok(victim.hp == hp_before or victim.shield < 1000 or guard == 400, "傷害先扣盾")
	# 次數用完
	var r5 = _cmd_rules(31)   # 測效果用：五招全帶（模擬不看上限，上限在 validate）
	var s2 = Sim.new(_cmd_army(0, r5), _cmd_army(1, r5), r5)
	while s2.tick < CMD.START_TICKS:
		s2.step()
	s2.cast(0, CMD.HEAL)
	s2.step()
	s2.cmd_ready[0][CMD.HEAL] = 0
	s2.cast(0, CMD.HEAL)
	s2.step()
	s2.cmd_ready[0][CMD.HEAL] = 0
	ok(s2.cmd_left[0][CMD.HEAL] == 0 and not s2.cast(0, CMD.HEAL), "次數用完不能再用")
	# 各技能效果
	var h = Sim.new(_cmd_army(0, r5), _cmd_army(1, r5), r5)
	while h.tick < CMD.START_TICKS:
		h.step()
	h.units[0].hp = 10
	var mx: int = h.units[0].max_hp
	h.cast(h.units[0].team, CMD.HEAL)
	h.step()
	ok(h.units[0].hp >= 10 + mx * CMD.HEAL_PCT / 100 - 200 or not h.units[0].alive, "治癒之雨：回血", str(h.units[0].hp))
	var w = Sim.new(_cmd_army(0, r5), _cmd_army(1, r5), r5)
	while w.tick < CMD.START_TICKS:
		w.step()
	w.cast(0, CMD.WARCRY)
	w.step()
	var hasted := true
	for u in w.units:
		if u.alive and ((u.team == 0) != (u.haste_t > 0)):
			hasted = false
	ok(hasted, "戰吼：只有我方加速")
	var f = Sim.new(_cmd_army(0, r5), _cmd_army(1, r5), r5)
	while f.tick < CMD.START_TICKS:
		f.step()
	f.cast(0, CMD.FREEZE)
	f.step()
	var frozen := true
	for u in f.units:
		if u.alive and u.team == 1 and u.stun < CMD.FREEZE_TICKS - 2:
			frozen = false
	ok(frozen, "冰封：敵人全部定身")
	var m = Sim.new(_cmd_army(0, r5), _cmd_army(1, r5), r5)
	while m.tick < CMD.START_TICKS:
		m.step()
	m.cast(0, CMD.METEOR)
	m.step()
	var hit_n := 0
	var mine_hit := 0
	for e in m.events:
		if e["kind"] == "cmd_hit":
			var tu = m.unit_by_id(e["tgt"])
			if tu.team == 1:
				hit_n += 1
			else:
				mine_hit += 1
	ok(hit_n >= 1 and mine_hit == 0, "隕石：打到敵人、不傷友軍", "%d %d" % [hit_n, mine_hit])
	# 重播：同一份紀錄同一個指紋（含 AI）
	var a0 = _cmd_army(0, r)
	var a1 = _cmd_army(1, r)
	var live = Sim.new(a0.copy(), a1.copy(), r)
	live.cmd_auto = [false, true]
	var pressed := false
	while not live.finished:
		if not pressed and live.tick == 80:
			pressed = live.cast(0, CMD.AEGIS)
		live.step()
	ok(pressed and live.cmd_log.size() >= 2, "玩家與 AI 都有放", str(live.cmd_log))
	var rep = Sim.new(a0.copy(), a1.copy(), r)
	rep.cmd_play(live.cmd_log)
	while not rep.finished:
		rep.step()
	ok(rep.fingerprint == live.fingerprint and rep.cmd_log == live.cmd_log and rep.winner == live.winner, "重播同一個指紋")
	var none = Sim.new(a0.copy(), a1.copy(), r)
	while not none.finished:
		none.step()
	ok(none.fingerprint != live.fingerprint, "有放技能的指紋不同")
	var rep2 = Sim.new(a0.copy(), a1.copy(), r)
	rep2.cmd_play(live.cmd_log)
	ok(not rep2.cast(0, CMD.AEGIS), "重播時按了沒用")
	# 對戰代碼帶施放紀錄
	var bc: String = BC.encode(a0, a1, r, live.cmd_log)
	ok(bc.begins_with("NTB7"), "對戰代碼用 NTB7", bc.substr(0, 5))
	var dec: Dictionary = BC.decode(bc)
	ok(dec["ok"] and dec["cmds"] == live.cmd_log and dec["rules"].cmd_on(), "對戰代碼往返", str(dec.get("why")))
	if dec["ok"]:
		var rep3 = Sim.new(dec["a0"], dec["a1"], dec["rules"])
		rep3.cmd_play(dec["cmds"])
		while not rep3.finished:
			rep3.step()
		ok(rep3.fingerprint == live.fingerprint, "貼代碼播出同一場")
	# 鏡像：雙方 AI 都開，左右完全對稱
	for mask in [31, 1 << CMD.METEOR, (1 << CMD.FREEZE) | (1 << CMD.HEAL)]:
		var rm = _cmd_rules(mask, 3)
		var why: String = MC9.check_free(_cmd_army(0, rm), _cmd_army(1, rm), rm, true)
		ok(why == "", "技能鏡像一致 mask=%d" % mask, why)

func test_cmd_ui() -> void:
	var was: bool = SaveS.data_locked
	SaveS.data_locked = true
	var g = GS.new()
	g.sfx = FakeSfx.new()
	g.time = 1.0
	var r = _cmd_rules(7, 2)
	g.rules = r
	g.challenge_army = null
	g._start_mode(g.Mode.VS_AI)
	g.armies[0] = _cmd_army(0, r)
	g.armies[1] = _cmd_army(1, r)
	g._begin_battle(g.armies[0].copy(), g.armies[1].copy(), "official")
	ok(g.sim.cmd_on and g.sim.cmd_auto == [false, true], "對 AI：紅方由 AI 放")
	while g.sim.tick < CMD.START_TICKS + 2:
		g._sim_step(false)
	ok(g._cmd_press(0, 0), "按第一格放第一招")
	g._sim_step(false)
	g._sim_step(false)
	ok(g.sim.cmd_log.size() >= 1 and int(g.sim.cmd_log[0][2]) == CMD.AEGIS, "真的放了")
	ok(not g._cmd_press(1, 0), "對 AI 時不能幫紅方按")
	ok(g._cmd_key(KEY_2), "數字鍵 2 放第二招")
	ok(not g._cmd_key(KEY_5), "不是技能鍵")
	while not g.view.finished:
		g._sim_step(false)
	g._finish_battle()
	var log: Array = g.last_cmds.duplicate(true)
	ok(log.size() >= 2, "結束時記下施放紀錄", str(log))
	var fp: String = g.sim.fingerprint
	g._begin_battle(g.last_armies[0].copy(), g.last_armies[1].copy(), "replay")
	ok(g.sim.cmd_scripted, "重播走紀錄")
	ok(not g._cmd_press(0, 1), "重播不能按")
	while not g.view.finished:
		g._sim_step(false)
	ok(g.sim.fingerprint == fp, "重播同一場", "%s %s" % [g.sim.fingerprint, fp])
	# 跳轉也要照紀錄
	g._begin_battle(g.last_armies[0].copy(), g.last_armies[1].copy(), "replay")
	g._seek(200)
	ok(g.sim.cmd_scripted and g.sim.cmd_log.size() >= 1, "跳轉照紀錄", str(g.sim.cmd_log))
	# 雙人：兩邊都能按、AI 不動
	g.rules = r.copy()
	g._start_mode(g.Mode.DUEL)
	g.armies[0] = _cmd_army(0, r)
	g.armies[1] = _cmd_army(1, r)
	g._begin_battle(g.armies[0].copy(), g.armies[1].copy(), "official")
	ok(g.sim.cmd_auto == [false, false], "雙人沒有 AI 施放")
	while g.sim.tick < CMD.START_TICKS + 2:
		g._sim_step(false)
	ok(g._cmd_press(1, 0), "雙人紅方能按")
	ok(g._cmd_key(KEY_8) == true, "紅方鍵 8")
	# Codex v12-r1：相等比較、護盾承傷
	var eq1 = RS9.standard()
	var eq2 = RS9.standard()
	eq2.cmd_mask = [1, 1]
	ok(not eq1.equals(eq2), "開技能的規則和標準不相等")
	var st = Sim.new(_cmd_army(0, r), _cmd_army(1, r), r)
	var su = st.units[0]
	su.shield = 100000
	su.shield_t = 9999
	var guard2 := 0
	while su.alive and su.dmg_taken == 0 and su.shield == 100000 and guard2 < 800:
		guard2 += 1
		st.step()
	ok(su.shield < 100000 and su.dmg_taken == 0 and su.hp == su.max_hp, "全被盾擋下：承傷是 0、血沒掉", "%d %d" % [su.shield, su.dmg_taken])
	# 大廳設定
	g.mode = g.Mode.VS_AI
	g.rules = null
	g._open_lobby("ai")
	ok(not g.lobby_r.cmd_on(), "大廳預設關閉")
	var badge0: String = load("res://scripts/game/presets.gd").badge(g.lobby_r, "ai")
	g._lobby_adj("cmd_on", 1)
	ok(g.lobby_r.cmd_on() and g.lobby_r.cmd_mask == [CMD.DEFAULT_MASK, CMD.DEFAULT_MASK], "開啟給預設兩招")
	ok(g.lobby_r.preset == "custom", "開技能後不再標成標準", g.lobby_r.preset)
	ok(g._lobby_block() == "", "開啟後能開打", g._lobby_block())
	var badge1: String = load("res://scripts/game/presets.gd").badge(g.lobby_r, "ai")
	ok(badge0 == "cert" and badge1 != "cert", "開技能就不是平衡認證", badge1)
	g._cmd_toggle(0, CMD.HEAL)
	ok(CMD.count_of(g.lobby_r.cmd_mask[0]) == 3, "加一招")
	g._cmd_toggle(0, CMD.FREEZE)
	ok(CMD.count_of(g.lobby_r.cmd_mask[0]) == 3, "超過 3 種擋下")
	g._cmd_toggle(0, CMD.HEAL)
	g._cmd_toggle(0, CMD.METEOR)
	g._cmd_toggle(0, CMD.AEGIS)
	ok(CMD.count_of(g.lobby_r.cmd_mask[0]) == 1, "至少留一招")
	for key in ["cmd_uses", "cmd_cd", "cmd_power"]:
		g._lobby_adj(key, 1)
	ok(g.lobby_r.validate().is_empty() and g.lobby_r.cmd_uses == 2 and g.lobby_r.cmd_cd == 600 and g.lobby_r.cmd_power == 150, "次數、冷卻、強度能調", str(g.lobby_r.validate()))
	ok(RS9.from_code(g.lobby_r.to_code())["ok"], "調完的規則碼有效")
	g._lobby_adj("cmd_on", 1)
	ok(not g.lobby_r.cmd_on(), "可以關回去")
	# 每招都有名字和說明
	for i in CMD.COUNT:
		ok(L.t("cmd_%d" % i) != "cmd_%d" % i and "%d" not in g._cmd_desc(i, 100) and "%s" not in g._cmd_desc(i, 100), "技能 %d 有名字和說明" % i, g._cmd_desc(i, 100))
	# 挑戰碼：朋友的技能要跟著對調
	var rc = _cmd_rules(1, 1)
	rc.cmd_mask = [1, 8]
	rc.pool = [1023, 1023]
	g.rules = rc
	g.challenge_army = null
	g._start_mode(g.Mode.VS_AI)
	_place_some(g, 6)
	g.last_armies = [g.armies[0].copy(), g.armies[0].copy()]
	var dc: Dictionary = g._challenge_decode(g._challenge_encode())
	ok(dc["ok"] and dc["rules"].cmd_mask == [8, 1], "挑戰碼對調雙方技能", str(dc.get("rules").cmd_mask if dc["ok"] else "bad"))
	g.free()
	SaveS.data_locked = was

## 第十二輪：每一關留一組已知三星解。改數值讓三星拿不到時這裡會紅，就要重找解或調門檻。
## 第十三輪：殘局的三星解存在關卡資料的 "best"（提示第二、三層也用它），用 PZ.play 判定（含擺放合法、目標、技能時間）。
func test_star_solutions() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/golden/star_solutions.json"))
	var PZ = load("res://scripts/game/puzzles.gd")
	var Sim = load("res://scripts/core/battle_sim.gd")
	var seen := 0
	var ids := {}
	for pz in PZ.all_puzzles():
		ok(not ids.has(pz["id"]), "殘局 ID 不重複", str(pz["id"]))
		ids[pz["id"]] = true
		# 第十三輪：遊戲用 get_puzzle(ID) 開關；和教學關撞 ID（t1～t3）時會開成教學（截圖抓到）
		ok(str(PZ.get_puzzle(pz["id"]).get("zh", "")) == str(pz["zh"]), "用 ID 開得到同一關（不和教學撞）", str(pz["id"]))
		var best: Dictionary = pz.get("best", {})
		ok(not best.is_empty(), "殘局有三星解紀錄", str(pz["id"]))
		var r: Dictionary = PZ.play(pz, best.get("u", []), best.get("p", []))
		ok(not r.has("illegal"), "三星解擺法合法", "%s %s" % [pz["id"], str(r.get("illegal", ""))])
		ok(int(r["stars"]) == 3, "殘局三星拿得到", "%s 剩 %d 花 %d" % [pz["id"], int(r["rem"]), int(r["spent"])])
		seen += 1
	ok(seen == PZ.CHAPTERS * 10, "殘局 %d 關都驗到" % (PZ.CHAPTERS * 10), str(seen))
	for n in range(1, PZ.CHAPTERS + 1):
		ok(PZ.chapter(n).size() == 10 and not PZ.chapter_info(n).is_empty(), "第 %d 章 10 關、有名稱與故事" % n, str(PZ.chapter(n).size()))
	var was: bool = SaveS.data_locked
	SaveS.data_locked = true
	var g = load("res://scripts/ui/game_screens.gd").new()
	g.sfx = FakeSfx.new()
	g.time = 1.0
	for i in g.TRIALS.size():
		g._start_trial(i)
		g._build_ai()
		var a = g.armies[0].copy()
		a.units = []
		var spec: Array = data["trials"][str(i)] if data["trials"].has(str(i)) else g.trial_x(i).get("best", [])
		ok(not spec.is_empty(), "試煉有三星解紀錄", str(i + 1))
		for u in spec:
			ok(a.place_xy(int(u[0]), a.world_x(int(u[1])), int(u[2])), "試煉三星解擺法合法", "第 %d 關 %s" % [i + 1, str(u)])
		var s2 = Sim.new(a.copy(), g.armies[1].copy(), g.rules)
		if s2.cmd_on:
			s2.cmd_auto = [false, true]   # 和遊戲一樣：紅方自動放技能
		s2.fast = true
		s2.run_to_end()
		var rem2: int = PZ.rem_pct(s2.power(0), s2.budget_of(0))
		var st: int = g.trial_stars(int(g.TRIALS[i][3]), rem2, a.spent(), a.budget, g.trial_spend_pct(i), g.trial_rem(i)) if s2.winner == 0 else 0
		ok(st == 3, "試煉三星拿得到", "第 %d 關 %d 星，剩 %d 花 %d" % [i + 1, st, rem2, a.spent()])
	g.free()
	SaveS.data_locked = was

## 第十三輪（Codex v13-r2 #1）：每關試煉的規則要能通過規則驗證（對戰代碼才讀得回），
## 固定敵陣要照敵方規則一隻隻擺得進去（卡池、預算、隻數、每種上限、位置、間距）。
func test_trial_rules_valid() -> void:
	var was: bool = SaveS.data_locked
	SaveS.data_locked = true
	var g = load("res://scripts/ui/game_screens.gd").new()
	g.sfx = FakeSfx.new()
	g.time = 1.0
	for i in g.TRIALS.size():
		g._start_trial(i)
		var bad: Array = g.rules.validate()
		ok(bad.is_empty(), "試煉規則通過驗證", "第 %d 關 %s" % [i + 1, str(bad)])
		g._build_ai()
		if g.trial_x(i).has("enemy"):
			var e = Army.new(1, g.rules.budget_of(1))
			e.apply_rules(g.rules, 1)
			for u in g.armies[1].units:
				var t: int = int(u["type"])
				ok((g.rules.pool_of(1) >> t) & 1 == 1, "固定敵陣兵種在敵方卡池內", "第 %d 關 兵種 %d" % [i + 1, t])
				ok(e.place_xy(t, int(u["x"]), int(u["y"])), "固定敵陣擺法合法", "第 %d 關 %s：%s" % [i + 1, str(u), e.check_place_xy(t, int(u["x"]), int(u["y"]))])
	g.free()
	SaveS.data_locked = was


## V1.1 D2：每日挑戰。8 種突變都合法、敵陣固定（釘住；改到 AI 或產生器要升 Daily.VER 再更新）、紀錄比較正確。
const DailyS = preload("res://scripts/game/daily.gd")
const DAILY_PIN := {20400: "bb68a92bc1f3", 20407: "3de9eb1ef182"}
func test_daily_v11() -> void:
	var muts := {}
	for d in range(20398, 20398 + 7 * 9):
		var sp: Dictionary = DailyS.spec(d)
		muts[int(sp["mut"])] = true
		var r = DailyS.make_rules(sp, RS9.full_pool())
		var bad: Array = r.validate()
		ok(bad.is_empty(), "D2 第 %d 天規則合法（突變 %d）" % [d, int(sp["mut"])], str(bad))
		var e = DailyS.enemy(sp, r)
		ok(e.has_combat() and e.units.size() > 0, "D2 第 %d 天敵陣有戰鬥兵" % d)
		var e2 = DailyS.enemy(DailyS.spec(d), DailyS.make_rules(DailyS.spec(d), RS9.full_pool()))
		ok(e.to_code() == e2.to_code(), "D2 同一天同一支敵軍")
		for u in e.units:
			ok(RS9.has(r.pool_of(1), int(u["type"])), "D2 敵兵在卡池內")
		if DAILY_PIN.has(d):
			var h: String = e.to_code().sha256_text().substr(0, 12)
			if str(DAILY_PIN[d]) == "":
				print("DAILYPIN %d %s" % [d, h])
			else:
				ok(h == str(DAILY_PIN[d]), "D2 第 %d 天敵陣沒漂移（漂了就升 Daily.VER）" % d, h)
	ok(muts.size() == DailyS.MUTATORS, "D2 九週內 8 種突變都出現")
	ok(DailyS.spec(20400)["key"] == "20400-v%d" % DailyS.VER, "D2 紀錄鍵含版本")
	var best := {}
	ok(DailyS.record(best, DailyS.spec(1), 40, 90), "D2 第一次贏就是紀錄")
	ok(not DailyS.record(best, DailyS.spec(1), 30, 50), "D2 剩得少不算新紀錄")
	ok(DailyS.record(best, DailyS.spec(1), 40, 80), "D2 一樣剩、花得少算新紀錄")
	for d2 in range(2, 20):
		DailyS.record(best, DailyS.spec(d2), 10, 10)
	ok(best.size() == DailyS.KEEP_DAYS and best.has(DailyS.spec(19)["key"]) and not best.has(DailyS.spec(1)["key"]), "D2 只留最近 %d 天" % DailyS.KEEP_DAYS)
	var dirty := {"daily_best": {"5-v1": [120, -3], "x": "bad", "6-v1": [1], "999999999-v1": [100, 0], "ab-v1": [1, 1]}}
	SaveS.sanitize_data(dirty)
	ok(dirty["daily_best"].size() == 1 and int(dirty["daily_best"]["5-v1"][0]) == 100 and int(dirty["daily_best"]["5-v1"][1]) == 0, "D2 存檔壞資料清掉、超界夾住")


## V1.1 D1：遠征路線。節點類型、事件種子固定、募兵換卡池、下一戰敵方變弱、舊續局沒有新欄位也能讀。
func test_gauntlet_route_v11() -> void:
	var was: bool = SaveS.data_locked
	SaveS.data_locked = true
	var g = GS.new()
	g.sfx = FakeSfx.new()
	g.time = 1.0
	ok(g.ga_node(1) == "outpost" and g.ga_node(4) == "elite" and g.ga_node(7) == "boss", "D1 節點：前哨、菁英、首領")
	g.rules = null
	g._start_mode(g.Mode.GAUNTLET)
	_place_some(g, 6)
	g.last_armies = [g.armies[0].copy(), g.armies[1].copy()]
	var o1: Array = g._gauntlet_offers()
	ok(o1.size() == 3 and o1 == g._gauntlet_offers(), "D1 每站固定 3 個事件", str(o1))
	var pool0: int = g._gauntlet_pool()
	var rp: Array = g._recruit_pick()
	if not rp.is_empty():
		g._take_reward(3)
		var pool1: int = g._gauntlet_pool()
		ok(RS9.has(pool1, int(rp[0])) and not RS9.has(pool1, int(rp[1])) and RS9.pool_count(pool1) == RS9.pool_count(pool0), "D1 募兵：一進一出，種數不變")
		ok(int(SaveS.data["gauntlet_run"]["pool"]) == pool1, "D1 募兵後的卡池有存進續局")
	else:
		g._take_reward(0)
	var e_full: int = g.armies[1].budget
	g.last_armies = [g.armies[0].copy(), g.armies[1].copy()]
	g._take_reward(4)
	ok(g.armies[1].budget == e_full + 5 - 10, "D1 斥候劫掠：下一戰敵方少 10 金", "%d %d" % [g.armies[1].budget, e_full])
	ok(g.armies[1].spent() <= g.armies[1].budget and g.armies[1].units.size() <= g.armies[1].unit_cap, "D1 敵陣不超出調低後的預算與隻數（Codex v110-impl #2）", "%d/%d" % [g.armies[1].spent(), g.armies[1].budget])
	g.last_armies = [g.armies[0].copy(), g.armies[1].copy()]
	var rp2: Array = g._recruit_pick()
	var used2 := {}
	for u2 in g.last_armies[0].units:
		used2[int(u2["type"])] = true
	ok(rp2.is_empty() or not used2.has(int(rp2[1])), "D1 募兵離隊的不會是剛打完那一戰的兵（Codex v110-impl #1）")
	g._take_reward(5)
	ok(g.armies[1].units.size() <= g.armies[1].unit_cap and g.armies[1].spent() <= g.armies[1].budget, "D1 截斷援軍：敵方隻數上限照扣、不超出")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(SaveS.data["gauntlet_run"]))
	ok(int(saved["foe_cap"]) == -2 and int(saved["foe_gold"]) == 0, "D1 下一戰效果有存、上一個效果只用一戰", str(saved))
	var g2 = GS.new()
	g2.sfx = FakeSfx.new()
	g2.time = 1.0
	SaveS.data["gauntlet_run"] = SaveS.sanitize_run(saved)
	g2._gauntlet_resume()
	ok(g2.armies[1].to_code() == g.armies[1].to_code(), "D1 接回來敵陣一樣（含下一戰效果）")
	var old := saved.duplicate(true)
	old.erase("foe_gold")
	old.erase("foe_cap")
	var cl: Dictionary = SaveS.sanitize_run(old)
	ok(not cl.is_empty() and int(cl["foe_gold"]) == 0 and int(cl["foe_cap"]) == 0, "D1 舊續局沒有新欄位＝0（遷移）")
	old["foe_gold"] = -500
	ok(int(SaveS.sanitize_run(old)["foe_gold"]) == 0, "D1 超界的值歸 0")
	g._gauntlet_clear()
	g2.free()
	g.free()
	SaveS.data_locked = was


## V1.1 B1：敗因摘要（純函式）。
func test_loss_summary_v11() -> void:
	var GR = preload("res://scripts/ui/screens/game_result.gd")
	ok(GR.loss_summary({}, [0, 1]) == "", "B1 沒資料就不顯示")
	var s: String = GR.loss_summary({"dmgby0_6": 300, "dmgby0_2": 100, "dmgby1_0": 999}, [0, 1, 3, 4])
	ok(s.find(L.t("unit_6")) >= 0 and s.find("75") >= 0, "B1 抓到傷害最多的敵兵與占比（只看藍方受傷）", s)
	var s2: String = GR.loss_summary({"dmgby0_6": 300}, [])
	ok(s2 != "" and s2 == L.t("loss_hint_n", [L.t("unit_6"), 100]), "B1 沒有可建議的兵就只講來源", s2)


## V1.1 D3：工坊碼。拿一關有三星解的一般殘局當「打贏的對戰」出題，驗：可解才給碼、竄改擋下、門檻＝作者成績、不存星數。
## V1.1 D5：新目標 margin／flawless 的判定。
func test_workshop_v11() -> void:
	var WSx = preload("res://scripts/game/workshop.gd")
	var src := {}
	for p in PZ.all_puzzles():
		if PZ.goal(p) == "win" and p.get("fixed", []).is_empty() and not p.has("map") and not p.has("cmd") and p.has("best"):
			src = p
			break
	ok(not src.is_empty(), "D3 找得到一關當素材")
	var sol: Array = src["best"]["u"]
	var code: String = WSx.encode(src["enemy"], sol)
	ok(code.begins_with("NTP1."), "D3 打得贏就給碼", code.substr(0, 20))
	var d: Dictionary = WSx.decode(code)
	ok(bool(d["ok"]), "D3 碼解得回來而且作者解重跑過關", str(d.get("why")))
	var cost := 0
	for u in sol:
		cost += D.cost(int(u[0]))
	ok(int(d["pz"]["star3"]) == cost and int(d["pz"]["budget"]) == cost, "D3 預算與三星花費＝作者花的錢")
	var r: Dictionary = PZ.play(d["pz"], sol)
	ok(int(r["stars"]) == 3, "D3 照作者的解打＝三星", str(r))
	var parts := code.split(".")
	ok(not bool(WSx.decode(parts[0] + "." + parts[1] + "A." + parts[2])["ok"]), "D3 竄改內容擋下（雜湊不符）")
	ok(not bool(WSx.decode("NTP1.xx.yy")["ok"]) and not bool(WSx.decode("")["ok"]), "D3 亂碼擋下")
	ok(WSx.encode(src["enemy"], [sol[0]]) == "" or bool(WSx.decode(WSx.encode(src["enemy"], [sol[0]]))["ok"]), "D3 打不贏的解不給碼")
	ok(WSx.encode([[0, 3, 3]], sol) == "", "D3 敵陣不在敵方欄就不收")
	PZ.set_custom(d["pz"])
	ok(PZ.get_puzzle("ws")["star3"] == cost and not "ws" in PZ.all_ids(), "D3 工坊殘局不進清單")
	# D5：margin 以剩餘戰力判定、flawless 以指定兵種陣亡數判定
	var won: Dictionary = PZ.play(src, sol)
	var m := src.duplicate(true)
	m["goal"] = "margin"
	m["goal_rem"] = int(won["rem"])
	ok(bool(PZ.play(m, sol)["ok"]), "D5 margin：剛好達標算過")
	m["goal_rem"] = int(won["rem"]) + 1
	ok(not bool(PZ.play(m, sol)["ok"]), "D5 margin：差 1% 不過")
	var f := src.duplicate(true)
	f["goal"] = "flawless"
	var unused := -1
	for t in [19, 18, 17, 16, 15]:
		var used := false
		for u in sol:
			used = used or int(u[0]) == t
		if not used:
			unused = t
			break
	f["goal_type"] = unused
	ok(bool(PZ.play(f, sol)["ok"]), "D5 flawless：沒帶的兵種＝不可能陣亡＝過")


## V1.1 Codex v110-impl2：工坊碼的型別漏洞（版本與可用兵種先驗整數性與範圍）。
func test_workshop_types_v11() -> void:
	var WSx = preload("res://scripts/game/workshop.gd")
	var src := {}
	for p in PZ.all_puzzles():
		if PZ.goal(p) == "win" and p.get("fixed", []).is_empty() and not p.has("map") and not p.has("cmd") and p.has("best"):
			src = p
			break
	var sol: Array = src["best"]["u"]
	var types: Array = []
	for u in sol:
		if not int(u[0]) in types:
			types.append(int(u[0]))
	for bad_v in [{}, [], 1.9, "1"]:
		ok(not bool(WSx.decode(_ws_code({"v": bad_v, "e": src["enemy"], "s": sol, "a": types}))["ok"]), "工坊碼：版本 %s 擋下" % str(bad_v))
	for bad_a in [[-0.5] + types, [3.9] + types, types + [types[0]], []]:
		ok(not bool(WSx.decode(_ws_code({"v": 1, "e": src["enemy"], "s": sol, "a": bad_a}))["ok"]), "工坊碼：兵種表 %s 擋下" % str(bad_a))
	ok(bool(WSx.decode(_ws_code({"v": 1, "e": src["enemy"], "s": sol, "a": types}))["ok"]), "工坊碼：正常的照樣收")

func _ws_code(j: Dictionary) -> String:
	var b := Marshalls.utf8_to_base64(JSON.stringify(j)).replace("+", "-").replace("/", "_").replace("=", "")
	return "NTP1.%s.%s" % [b, b.sha256_text().substr(0, 6)]


## V1.4 #5 接力殘局：NTP2 帶第幾棒；NTP1 照舊；改格數計算；打不贏不給碼。
func test_relay_v140() -> void:
	var WSx = preload("res://scripts/game/workshop.gd")
	var GM = load("res://scripts/ui/screens/game_modes.gd")
	var src := {}
	for p in PZ.all_puzzles():
		if PZ.goal(p) == "win" and p.get("fixed", []).is_empty() and not p.has("map") and not p.has("cmd") and p.has("best"):
			src = p
			break
	var sol: Array = src["best"]["u"]
	var c2: String = WSx.encode(src["enemy"], sol, 3)
	ok(c2.begins_with("NTP2."), "接力碼用 NTP2", c2.substr(0, 12))
	var d: Dictionary = WSx.decode(c2)
	ok(bool(d["ok"]) and int(d["pz"]["relay"]) == 3, "解得回來而且是第 3 棒", str(d.get("why")))
	var d1: Dictionary = WSx.decode(WSx.encode(src["enemy"], sol))
	ok(bool(d1["ok"]) and int(d1["pz"]["relay"]) == 0, "NTP1 照舊能用（第 0 棒）")
	var o: Array = [[0, 10, 1], [1, 11, 2], [2, 12, 3]]
	var n1: Array = o.duplicate(true)
	n1[0][0] = 5
	ok(GM.relay_changes(o, n1) == 1, "換兵種＝改一格")
	n1.remove_at(1)
	ok(GM.relay_changes(o, n1) == 2, "再拿掉一隻＝改兩格")
	var n2: Array = o.duplicate(true)
	n2[2] = [2, 13, 3]
	ok(GM.relay_changes(o, n2) == 2, "搬移＝兩格")
	var heavy: Array = src["enemy"].duplicate(true)
	for k in 30:
		heavy.append([19, 10 + k % 6, k % 9])
	ok(WSx.encode(heavy, sol, 1) == "", "改到作者打不贏就不給碼")


## V1.4 #16 遊戲間：競猜區間、輪抽卡池遮罩。
func test_playroom_v140() -> void:
	var GM = load("res://scripts/ui/screens/game_modes.gd")
	ok(GM.wager_band(10) == 0 and GM.wager_band(34) == 1 and GM.wager_band(67) == 2, "剩餘戰力分三區（險勝／普通／大勝）")
	ok(GM.draft_mask([0, 2, 5]) == (1 | 4 | 32), "輪抽卡池遮罩")


## V1.4 #8 指揮官：兩邊交替選，預算＝基礎＋自己的加成，不會越加越多。
func test_commanders_v140() -> void:
	var GS = load("res://scripts/ui/game_screens.gd")
	var RS0 = load("res://scripts/core/ruleset.gd")
	var g = GS.new()
	g.lobby_r = RS0.standard()
	g._cmdr_pick(0, 5)   # 老兵 +10
	ok(g.lobby_r.budget_of(0) == 110 and g.lobby_r.budget_of(1) == 100, "藍選老兵：110／100", str([g.lobby_r.budget_of(0), g.lobby_r.budget_of(1)]))
	g._cmdr_pick(1, 5)
	ok(g.lobby_r.budget_of(0) == 110 and g.lobby_r.budget_of(1) == 110, "紅也選老兵：110／110")
	g._cmdr_pick(0, 2)   # 隕星 +5
	ok(g.lobby_r.budget_of(0) == 105 and g.lobby_r.budget_of(1) == 110, "藍改隕星：105／110（不累加）")
	ok(g.cmdr_of(0) == 2 and int(g.lobby_r.cmd_mask[0]) == 8, "藍的軍令＝隕石")
	g.free()


## V1.4 #11 車輪戰：活下來的兵＝原陣型裡模擬結束時還活著的（原本的格子）。
func test_waves_v140() -> void:
	var GM = load("res://scripts/ui/screens/game_modes.gd")
	var Sim0 = load("res://scripts/core/battle_sim.gd")
	var AI0 = load("res://scripts/core/ai_army.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1411
	var a0 = AI0.build(0, 100, rng)["army"]
	var a1 = AI0.build(1, 70, rng)["army"]
	var s = Sim0.new(a0.copy(), a1.copy())
	s.fast = true
	s.run_to_end()
	var surv: Array = GM.wave_survivors(a0, s)
	var alive := 0
	for u in s.units:
		if u.team == 0 and u.alive and not u.summon:
			alive += 1
	ok(surv.size() == alive and surv.size() <= a0.units.size(), "殘兵數＝模擬結束時我方還活著的（不含召喚物）", "%d/%d" % [surv.size(), alive])
	ok(GM.WAVE_FOE.size() == 3 and GM.WAVE_FOE[2] > GM.WAVE_FOE[0], "三波，敵方預算遞增")


## V1.4 #13 雙封蠟戰書：每人封三陣（封一個清空一次），兩人都封好後第 1 戰用第 1 封；下一局直接換第 2 封。
func test_sealed_v140() -> void:
	var GS = load("res://scripts/ui/game_screens.gd")
	var AI0 = load("res://scripts/core/ai_army.gd")
	var g = GS.new()
	g.sfx = FakeSfx.new()
	g.time = 1.0
	g._sealed_start()
	ok(g.mode == g.Mode.DUEL and g.sealed_on and g.rules.rounds == 3 and g.blind_phase == 0, "開雙封蠟：雙人暗擺三戰兩勝")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1413
	var forms := [[], []]
	for t in 2:
		for k in 3:
			var a = AI0.build(t, g.rules.budget_of(t), rng)["army"]
			forms[t].append(a.units.duplicate(true))
			g.armies[t].units = a.units.duplicate(true)
			g._on_start()
			if k < 2:
				ok(g.blind_phase == t and g.armies[t].units.is_empty() and g.sealed[t].size() == k + 1, "第 %d 方封了 %d 陣、清空、還沒換人" % [t, k + 1])
	ok(g.blind_phase == 2, "兩人都封好三陣")
	ok(g.armies[0].units == forms[0][0] and g.armies[1].units == forms[1][0], "第 1 戰用第 1 封")
	g.round_no = 1
	g._next_round()
	ok(g.round_no == 2 and g.blind_phase == 2 and g.armies[0].units == forms[0][1] and g.armies[1].units == forms[1][1], "下一局直接揭第 2 封", str(g.round_no))
	g.round_no = 3
	g.series_over = true
	g._next_round()
	ok(g.sealed_on and g.sealed[0].is_empty() and g.blind_phase == 0 and g.round_no == 1, "三戰打完再來＝重新封三陣（不會重打同一組）")
	g._start_mode(g.Mode.DUEL)
	ok(not g.sealed_on, "從大廳開一般雙人就不是封蠟")
	g.free()


## V1.4 #11 車輪戰：殘兵鎖在原位（不能撤、清空會放回、被換掉不能開戰）。
func test_waves_lock_v140() -> void:
	var GS = load("res://scripts/ui/game_screens.gd")
	var g = GS.new()
	g.sfx = FakeSfx.new()
	g.time = 1.0
	g.wv_no = 2
	var surv := [{"type": 0, "col": 2, "row": 3}, {"type": 2, "col": 0, "row": 5}]
	g._wave_setup(surv, 40)
	ok(g.wv_active and g.armies[0].units.size() == 2 and g.wave_is_locked(Vector2i(2, 3)), "第 2 波：殘兵放回原位並鎖住")
	g._try_remove(Vector2i(2, 3))
	ok(g.armies[0].units.size() == 2, "殘兵不能撤")
	g.armies[0].units.append({"type": 1, "col": 3, "row": 1})
	g._clear_mine()
	ok(g.armies[0].units == surv, "清空只清新補的兵", str(g.armies[0].units))
	ok(not g.wave_has_lock([surv[0]], surv) and g.wave_has_lock(surv + [{"type": 1, "col": 3, "row": 1}], surv), "缺殘兵就不算完整")
	g.daily_spec = {"seed": 1}
	g._wave_start()
	ok(g.daily_spec.is_empty() and g.wv_lock.is_empty(), "開車輪戰會清掉每日挑戰與舊殘兵")
	g.free()


## V1.4 #4 審查修正：預設排程一定合法；往右推到底會停在最右的合法位置（不整個退回）。
func test_plan_fix_v140() -> void:
	var PZ0 = load("res://scripts/game/puzzles.gd")
	var bad: Array = []
	for id in ["c1", "c2", "c5", "c7", "c10"]:
		var pz: Dictionary = PZ0.get_puzzle(id)
		if pz.is_empty():
			bad.append(id + " 不存在")
			continue
		var p: Array = PZ0.default_plan(pz)
		if PZ0.plan_fix(pz, p, -1, 0) != p:
			bad.append(id + " 預設排程不合法")
		var last := p.size() - 1
		var q: Array = PZ0.plan_fix(pz, p, last, 100000)
		var lim: int = int(pz.get("goal_ticks", 1800)) - 10
		if q == p or PZ0.plan_tick(pz, int(q[last])) > lim:
			bad.append(id + " 推到底沒有停在局末")
	ok(bad.is_empty(), "第 12 章：預設排程合法、推到底停在局末", str(bad))


## V1.4 #7 幽靈軍團＋每週棋盒：30 個幽靈、每週題目固定且合法、陣型打包解包、打贏記錄。
func test_ghosts_v140() -> void:
	var GM = load("res://scripts/ui/screens/game_modes.gd")
	var ST = load("res://scripts/game/steam.gd")
	var GS = load("res://scripts/ui/game_screens.gd")
	var RS0 = load("res://scripts/core/ruleset.gd")
	var gs: Array = GM.ghosts()
	ok(gs.size() == 30, "30 個幽靈陣", str(gs.size()))
	var bad: Array = []
	for g in gs:
		var a = GM.ghost_army(g)
		if a.units.is_empty() or a.spent() > 100:
			bad.append(str(g["id"]))
	ok(bad.is_empty(), "每個幽靈陣都有兵、不超過 100 金", str(bad))
	ok(GM.week_no(1762732800) == GM.week_no(1762732800 + 6 * 86400) and GM.week_no(1762732800) + 1 == GM.week_no(1762732800 + 7 * 86400), "週數：同一週一樣、下週加一（週一換題）")
	var a1: Dictionary = GM.weekly_spec(2913)
	ok(a1 == GM.weekly_spec(2913) and RS0.has_combat(int(a1["pool"])) and int(a1["ghost"]) < gs.size(), "每週題目固定、卡池有戰鬥兵", str(a1))
	var units := [{"type": 3, "col": 12, "row": 4}, {"type": 0, "col": 10, "row": 0}]
	ok(ST.unpack_army(ST.pack_army(units)) == units and ST.unpack_army(PackedInt32Array([9, 1, 5])).is_empty(), "排行榜附加資料：陣型打包解包、壞資料不收")
	var SaveS = load("res://scripts/game/save.gd")
	var keep = SaveS.data.get("ghost_beat", [])
	SaveS.data_locked = true
	SaveS.data["ghost_beat"] = []
	var g = GS.new()
	g.sfx = FakeSfx.new()
	g.time = 1.0
	g._ghost_start(0)
	ok(g.ghost_id == str(gs[0]["id"]) and g.challenge_army != null and g.challenge_army.units.size() == gs[0]["units"].size(), "開幽靈戰：對手就是那個陣")
	g.last_armies = [g.armies[0].copy(), g.challenge_army.copy()]
	g._ghost_settle(0)
	ok(SaveS.data["ghost_beat"] == [str(gs[0]["id"])], "打贏記下來")
	g._start_mode(g.Mode.VS_AI)
	ok(g.ghost_id == "" and not g.wk_active, "開別的對戰就清掉")
	SaveS.data["ghost_beat"] = keep
	g.free()


## V1.4 #9 遠征的木座貼紙事件：固定抽一張、貼在沿用陣型裡還沒貼的一隻；說明的數值從常數來。
func test_sticker_reward_v140() -> void:
	var GS = load("res://scripts/ui/game_screens.gd")
	var Army0 = load("res://scripts/core/army.gd")
	var g = GS.new()
	g.sfx = FakeSfx.new()
	g.time = 1.0
	g._start_mode(g.Mode.GAUNTLET)
	g.gauntlet_seed = 4242
	g.gauntlet_stage = 2
	var a = Army0.new(0, 100)
	a.units = [{"type": 0, "col": 5, "row": 3}, {"type": 2, "col": 3, "row": 4}]
	g.last_armies = [a, a.copy()]
	g.gauntlet_prev = a.units.duplicate(true)
	var sp: Array = g._sticker_pick()
	ok(sp.size() == 3 and sp == g._sticker_pick() and int(sp[0]) >= 1 and int(sp[0]) <= 6, "同一站抽到的貼紙固定", str(sp))
	g.armies[0].units = a.units.duplicate(true)
	g._apply_sticker(sp)
	var hit := 0
	for u in g.gauntlet_prev + g.armies[0].units:
		if int(u.get("st", 0)) == int(sp[0]):
			hit += 1
	ok(hit == 2, "沿用陣型與目前擺陣都貼上")
	ok(g.sticker_desc(1).contains("50") and not g.sticker_desc(5).contains("%d"), "說明數值從常數帶入", g.sticker_desc(1))
	var SV = load("res://scripts/game/save.gd")
	var run: Dictionary = SV.sanitize_run({"stage": 2, "seed": 1, "gold": 0, "cap": 0, "changes": 0, "pool": 1023, "prev": [{"type": 0, "col": 5, "row": 3, "st": 4}, {"type": 1, "col": 4, "row": 3, "st": 99}]})
	ok(int(run["prev"][0].get("st", 0)) == 4 and not run["prev"][1].has("st"), "續局存檔留貼紙、不合法的丟掉")
	g.free()


## V1.4 收尾第 1 輪：契約代價修剪先拿沒貼紙的兵；本戰條件列出契約、巨獸、貼紙。
func test_ga_info_v140() -> void:
	var GS = load("res://scripts/ui/game_screens.gd")
	var g = GS.new()
	g.sfx = FakeSfx.new()
	g.time = 1.0
	g._start_mode(g.Mode.GAUNTLET)
	g.gauntlet_stage = 3
	g.armies[0].budget = 30
	g.armies[0].units = [{"type": 0, "col": 5, "row": 1, "st": 3}, {"type": 0, "col": 5, "row": 2}, {"type": 0, "col": 5, "row": 3, "st": 5}, {"type": 0, "col": 5, "row": 4}, {"type": 0, "col": 5, "row": 5}, {"type": 0, "col": 5, "row": 6}, {"type": 0, "col": 5, "row": 7}]
	g.gauntlet_contract = 5
	g._apply_contract_cost()
	var kept := 0
	for u in g.armies[0].units:
		kept += 1 if int(u.get("st", 0)) > 0 else 0
	ok(kept == 2 and g.armies[0].spent() <= g.armies[0].budget, "修剪先拿沒貼紙的兵", str(g.armies[0].units))
	g.gauntlet_contract = 0
	g.armies[1].units = [{"type": 19, "col": 12, "row": 4, "boss": 1}]
	var txt := ""
	for ln in g._ga_info_lines():
		txt += str(ln[1]) + "|"
	ok(txt.contains(g.L.t("boss_here")) and txt.contains(g.L.t("st_3")) and txt.contains(g.L.t(str(g.CONTRACTS[0][0]))), "本戰條件列出契約、巨獸、貼紙", txt)
	g.free()

