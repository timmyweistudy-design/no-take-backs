extends RefCounted
## V1.6 #17 一陣三考：同一套格子陣分別迎戰三支敵陣（每場都滿血），三場都贏才過。題組 data/trio.json（tools/gen/trio_forge.gd）。
const PZ = preload("res://scripts/game/puzzles.gd")
static var _sets: Array = []

static func sets() -> Array:
	if _sets.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/trio.json"))
		if d is Dictionary:
			_sets = d.get("sets", [])
	return _sets

## 第 k 支敵陣做成一題（工坊殘局的格式：puzzle_id "ws"，不存殘局星數）
static func make_pz(s: Dictionary, k: int) -> Dictionary:
	return {"id": "ws", "ch": 0, "trio": str(s["id"]), "zh": "一陣三考", "en": "One Army, Three Tests", "relay": 0,
		"hint_zh": "同一套陣要連打三支敵軍，三場都贏才過關。", "hint_en": "Your one setup must beat all three enemy armies.",
		"enemy": s["foes"][k], "fixed": [], "budget": int(s["budget"]), "allowed": s["allowed"], "star2": 0, "star3": int(s["budget"])}

## 三場的結果：[過關?, …]（不合法的擺法全部算 false）
static func check(s: Dictionary, extra: Array) -> Array:
	var out: Array = []
	for k in 3:
		out.append(bool(PZ.play(make_pz(s, k), extra).get("ok", false)))
	return out
