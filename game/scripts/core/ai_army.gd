extends RefCounted
## AI 陣型（原型＝企劃 §7 的「普通」：從原型陣型挑一套再隨機微調）。
## AI 只在擺放時用亂數；戰鬥本身沒有亂數。

const D = preload("res://scripts/core/unit_defs.gd")
const Army = preload("res://scripts/core/army.gd")

const TEMPLATES := [
	{"name": "均衡軍", "w": [3, 2, 3, 1, 1]},
	{"name": "鐵壁弓陣", "w": [1, 4, 5, 0, 0]},
	{"name": "鐵騎突擊", "w": [2, 1, 0, 5, 0]},
	{"name": "暗影刺殺", "w": [3, 0, 2, 0, 4]},
	{"name": "劍海", "w": [5, 2, 2, 0, 0]},
	{"name": "騎射混編", "w": [0, 2, 3, 3, 0]},
]

# 每種兵偏好的欄（以藍方 0～5 表示，0＝最後排、5＝最前排；紅方自動鏡像）
const PREF_COLS := [
	[5, 4, 3],          # 劍士：前排
	[5, 4],             # 盾兵：最前排
	[0, 1, 2],          # 弓箭手：後排
	[3, 2, 4],          # 騎兵：中排兩翼
	[2, 3, 1],          # 刺客：中後排
]
const ROW_CENTER := [4, 3, 5, 2, 6, 1, 7, 0, 8]
const ROW_EDGE := [0, 8, 1, 7, 2, 6, 3, 5, 4]

static func build(team: int, budget: int, rng: RandomNumberGenerator, template := -1):
	var a = Army.new(team, budget)
	var ti := template if template >= 0 else rng.randi_range(0, TEMPLATES.size() - 1)
	var w: Array = TEMPLATES[ti]["w"]
	var picks: Array = []
	var guard := 0
	while a.left() >= D.cheapest() and picks.size() < Army.MAX_UNITS and guard < 200:
		guard += 1
		var total := 0
		for t in D.COUNT:
			if D.cost(t) <= a.left() - _cost_sum(picks) and w[t] > 0:
				total += w[t]
		if total == 0:
			break
		var r := rng.randi_range(1, total)
		for t in D.COUNT:
			if D.cost(t) <= a.left() - _cost_sum(picks) and w[t] > 0:
				r -= w[t]
				if r <= 0:
					picks.append(t)
					break
		if _cost_sum(picks) > a.left():
			picks.pop_back()
			break
	# 先放盾兵、劍士，再放其他（讓前排先佔中間）
	picks.sort_custom(func(p, q): return [1, 0, 3, 4, 2].find(p) < [1, 0, 3, 4, 2].find(q))
	for t in picks:
		_place_pref(a, t)
	return {"army": a, "name": TEMPLATES[ti]["name"]}

static func _cost_sum(picks: Array) -> int:
	var s := 0
	for t in picks:
		s += D.cost(t)
	return s

static func _place_pref(a, t: int) -> void:
	var rows: Array = ROW_EDGE if t == D.CAVALRY else ROW_CENTER
	var cols: Array = PREF_COLS[t] + [5, 4, 3, 2, 1, 0]
	for c in cols:
		var col: int = c if a.team == 0 else Army.COLS - 1 - c
		for r in rows:
			if a.place(t, col, r):
				return
