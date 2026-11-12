extends RefCounted
## 1.2.0 §11.3 分岔同步比較：時光機「如果」播放時，原本時間線（ghost）和現在這條在同一 tick 的存活數。
## 回傳 [原本藍, 原本紅, 如果藍, 如果紅]。只給數字，不說因果（一場模擬不能證明原因，§11.4 同原則）。
static func alive_pair(ghost, now) -> Array:
	return [_alive(ghost, 0), _alive(ghost, 1), _alive(now, 0), _alive(now, 1)]

static func _alive(sm, team: int) -> int:
	if sm == null:
		return 0
	var n := 0
	for u in sm.units:
		if u.alive and u.team == team and not u.get("summon"):
			n += 1
	return n
