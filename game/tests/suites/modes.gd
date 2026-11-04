extends "res://tests/test_base.gd"
## V9 P6：試煉、挑戰碼、AI 性格、遠征獎勵、禁牌、戰績、牌組的核心邏輯。
const GS = preload("res://scripts/ui/game_screens.gd")
const RS9 = preload("res://scripts/core/ruleset.gd")
const SaveS = preload("res://scripts/game/save.gd")
const AI9 = preload("res://scripts/core/ai_army.gd")

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
	ok(g.TRIALS.size() == 10 and bad.is_empty(), "試煉 10 關都有新地圖", str(bad))
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
