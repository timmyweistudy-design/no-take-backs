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
