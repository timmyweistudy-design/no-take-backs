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
