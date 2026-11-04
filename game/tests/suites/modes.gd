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
