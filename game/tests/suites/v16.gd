extends "res://tests/test_base.gd"
## V1.6.0 測試（docs/2026-11-10-v1.6.0-plan.md）。會碰存檔的測試自己換前綴、結束還原。

func test_layout_r5_v160() -> void:
	var LR = load("res://scripts/ui/layout_rules.gd")
	var card := func(x: float, ty: float) -> Array:
		return [Rect2(x + 40, 120, 40, 40), Rect2(x + 10, ty, 100, 20), Rect2(x + 10, 170, 100, 60)]
	var ok_res: Dictionary = LR.check({"aligns": [{"id": "cards", "cards": [card.call(100, 140), card.call(300, 140), card.call(500, 140.5)]}]})
	ok(ok_res["fail"].is_empty(), "R5 同列卡片標題基準線一致（容差 1）通過")
	var bad: Dictionary = LR.check({"aligns": [{"id": "cards", "cards": [card.call(100, 140), card.call(300, 146)]}]})
	ok(bad["fail"].size() == 1 and str(bad["fail"][0]["type"]) == "R5", "R5 標題差 6px 被抓")

func test_funnel_v160() -> void:
	var SV = load("res://scripts/game/save.gd")
	var FN = load("res://scripts/game/v16_funnel.gd")
	var old: Dictionary = SV.data.duplicate(true)
	SV.data.erase("funnel")
	ok(FN.mark("boot", 1000), "第一次記里程碑")
	ok(not FN.mark("boot", 2000), "同一個里程碑只記第一次")
	FN.mark("first_battle", 1000 + 300)
	FN.mark("tutorial_done", 1000 + 120)
	var st: Array = FN.steps()
	ok(st.size() == 3 and st[1]["step"] == "tutorial_done" and int(st[1]["min"]) == 2 and st[2]["step"] == "first_battle", "漏斗依步驟順序、算分鐘")
	FN.leave("settings")
	var rep = JSON.parse_string(FN.report("1.6.0", "title"))
	ok(rep is Dictionary and rep["feedback"]["last_screen"] == "settings" and rep["feedback"]["funnel"].size() == 3 and rep["feedback"]["screen"] == "title", "回報含畫面、漏斗、最後離開的畫面")
	ok(not FN.report("1.6.0", "x").contains("player_name"), "回報沒有存檔欄位")
	SV.data = old

func test_guide_v160() -> void:
	var G = load("res://scripts/game/v16_guide.gd")
	var d := {"tutorial": 0, "stats": {"games": 0}}
	ok(G.next_step(d, false, false) == "tut", "新玩家先教學")
	d["tutorial"] = 1
	ok(G.next_step(d, false, false) == "ai", "教學過了：打第一場")
	d["stats"] = {"games": 3}
	ok(G.next_step(d, false, false) == "puzzle", "打過了：殘局")
	d["puzzle_stars"] = {"p1": 1}
	ok(G.next_step(d, false, false) == "daily" and G.next_step(d, false, true) == "", "完整版接每日；試玩版不推沒開的模式")
	d["gauntlet_best"] = 2
	d["funnel"] = {"playroom_open": 1}
	d["trial_stars"] = {"0": 1}
	ok(G.next_step(d, true, false) == "", "全部做過就不顯示")
	var e := {}
	G.seed_seen(e)
	ok(not G.is_new(e, "menu_vs_ai") and G.is_new(e, "rush_open"), "舊入口算看過、V1.6 新入口標新")
	G.see(e, "rush_open")
	ok(not G.is_new(e, "rush_open"), "打開過就不再標新")
	ok(G.demo_end_due({"stats": {"games": 4}}, true, false) and not G.demo_end_due({"stats": {"games": 4}}, true, true) and not G.demo_end_due({"stats": {"games": 9}}, false, false), "試玩版結尾只在試玩版、每次開遊戲一次")

func test_tactical_marks_v160() -> void:
	var G = load("res://scripts/ui/screens/game_v16.gd")
	var Army = load("res://scripts/core/army.gd")
	var g = G.new()
	var a = Army.new(0, 100)
	a.place(0, 2, 2)
	a.place(1, 3, 4)
	a.place(2, 1, 6)
	a.place(5, 4, 1)
	ok(g.tv_toggle_at(a, Vector2i(2500, 2500)), "點到兵就標記")
	ok(not g.tv_toggle_at(a, Vector2i(9500, 8500)), "點空地不標記")
	g.tv_toggle_at(a, Vector2i(3500, 4500))
	g.tv_toggle_at(a, Vector2i(1500, 6500))
	g.tv_toggle_at(a, Vector2i(4500, 1500))
	ok(g.tv_marks.size() == 3 and g.tv_marks[0] == Vector2i(3500, 4500), "最多 3 隻，滿了擠掉最早的")
	g.tv_toggle_at(a, Vector2i(3500, 4500))
	ok(g.tv_marks.size() == 2, "再點一次取消")
	g.free()

func test_terrain_ai_v160() -> void:
	var PRE = load("res://scripts/game/presets.gd")
	var RSx = load("res://scripts/core/ruleset.gd")
	var AIx = load("res://scripts/core/ai_army.gd")
	var Fx = load("res://scripts/core/formations.gd")
	var bad := 0
	var moved := 0
	for m in [1, 2, 3, 4, 5]:
		var R = PRE.make("standard", "ai", RSx.all_pool())
		R.map_id = m
		R.map_size = 1
		for sd in 6:
			var rng := RandomNumberGenerator.new()
			rng.seed = 900 + sd
			var base = AIx.build(1, 100, rng, -1, RSx.all_pool(), R)["army"]
			var before: Array = base.units.duplicate(true)
			var x = Fx.terrain_smart(base.copy())
			var y = Fx.terrain_smart(base.copy())
			var tb: Array = []
			var tx: Array = []
			for u in before:
				tb.append(int(u["type"]))
			for u in x.units:
				tx.append(int(u["type"]))
				if x.terrain.blocked(int(u["x"]), int(u["y"]), x.team):
					bad += 1
			tb.sort()
			tx.sort()
			if tb != tx or JSON.stringify(x.units) != JSON.stringify(y.units):
				bad += 1
			if JSON.stringify(x.units) != JSON.stringify(before):
				moved += 1
	ok(bad == 0, "地形 AI：不少兵、不換兵種、不站牆內、結果固定（壞 %d）" % bad)
	ok(moved > 0, "地形 AI 在地形圖上真的有調整（%d 組）" % moved)

func test_access_settings_v160() -> void:
	var SV = load("res://scripts/game/save.gd")
	var d: Dictionary = SV.sanitize_settings({})
	ok(d.has("hold_confirm") and d["hold_confirm"] == false and d.has("magnify") and d["magnify"] == false, "新設定預設關")
	var e: Dictionary = SV.sanitize_settings({"hold_confirm": "x", "magnify": true})
	ok(e["hold_confirm"] == false and e["magnify"] == true, "型別不對退回預設、合法值保留")

func test_share_v160() -> void:
	var SH = load("res://scripts/game/v16_share.gd")
	var Lx = load("res://scripts/game/strings.gd")
	ok(SH.bar(72) == "■■■■■■■□□□" and SH.bar(0) == "□□□□□□□□□□" and SH.bar(100) == "■■■■■■■■■■", "剩餘戰力 10 格條")
	var st: Dictionary = SH.streak_after({}, 100)
	st = SH.streak_after(st, 101)
	st = SH.streak_after(st, 101)
	ok(int(st["n"]) == 2 and int(st["best"]) == 2, "連續兩天＝2，同一天不重複加")
	st = SH.streak_after(st, 104)
	ok(int(st["n"]) == 1 and int(st["best"]) == 2, "中斷重算，最佳保留")
	var t: String = SH.daily_text(Lx, "2026-11-10", "X", 72, 84, 100, 38, 3)
	ok(t.contains("■■■■■■■□□□") and t.contains("84") and t.split("\n").size() == 5, "每日分享格：條、花費、連續天數、標籤")
	ok(not t.contains("unit_") and not t.contains("NTB"), "分享格不含陣型或代碼（不劇透）")

func test_rush_v160() -> void:
	var RU = load("res://scripts/game/v16_rush.gd")
	var PZx = load("res://scripts/game/puzzles.gd")
	var a: Array = RU.pool(7)
	var b: Array = RU.pool(7)
	ok(a.size() >= 30 and a == b, "題庫夠多（%d）、同種子同順序" % a.size())
	var bad := 0
	var last_ch := -1
	for id in a:
		var pz: Dictionary = PZx.get_puzzle(id)
		if not RU.eligible(pz):
			bad += 1
		var c: int = PZx.chapter_of(id)
		if c < last_ch:
			bad += 1
		last_ch = c
	ok(bad == 0, "只收打贏型、沒有地圖／軍令／上限；章節由淺到深")
	ok(RU.after(10.0, true) == 30.0 and RU.after(10.0, false) == -5.0, "解開 +20、失敗 −15")

func test_coach_v160() -> void:
	var CO = load("res://scripts/game/v16_coach.gd")
	var Army = load("res://scripts/core/army.gd")
	var a = Army.new(0, 100)
	for r in [2, 4, 6]:
		a.place(3, 4, r)
	var e = Army.new(1, 100)
	e.place(0, 10, 4)
	var cs: Array = CO.candidates(a)
	ok(cs.size() >= 6 and cs[0][1] == 5, "候選：往前優先（%d 個）" % cs.size())
	var b = CO.moved(a, cs[0])
	ok(b.units.size() == a.units.size(), "只動一隻，不少兵")
	var res: Dictionary = CO.search(a, e, null, {}, 15)
	ok(bool(res["found"]) and int(res["tries"]) == 1 and res["to"].x == res["from"].x + 1, "大優勢：第一個候選就贏")
	var weak = Army.new(0, 100)
	weak.place(0, 0, 4)
	var strong = Army.new(1, 100)
	for r in [1, 3, 5, 7]:
		strong.place(3, 10, r)
	var r2: Dictionary = CO.search(weak, strong, null, {}, 15)
	ok(not bool(r2["found"]) and int(r2["tries"]) <= 15, "差太多：找不到、最多 15 次")
	var pz: Dictionary = load("res://scripts/game/puzzles.gd").get_puzzle("p1")
	var pa = load("res://scripts/game/puzzles.gd").player_army(pz)
	for c in CO.candidates(pa, pz):
		var u: Dictionary = pa.units[int(c[0])]
		ok(not load("res://scripts/game/puzzles.gd").is_fixed(pz, int(u["col"]), int(u["row"])), "殘局固定兵不動")
		break
