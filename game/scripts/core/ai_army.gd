extends RefCounted
## AI 陣型（原型＝企劃 §7 的「普通」：從原型陣型挑一套再隨機微調）。
## AI 只在擺放時用亂數；戰鬥本身沒有亂數。

const D = preload("res://scripts/core/unit_defs.gd")
const Army = preload("res://scripts/core/army.gd")

# 權重順序：劍、盾、弓、騎、刺、槍、彈、醫、鼓、狂（第四輪加後 5 種）。
# 模板只會在「用到的兵種都已開放」時被選（ntypes：開放編號 0～ntypes−1，經典模式＝5）。
const TEMPLATES := [
	{"name": "均衡軍", "w": [3, 2, 3, 1, 1, 0, 0, 0, 0, 0]},
	{"name": "鐵壁弓陣", "w": [1, 4, 5, 0, 0, 0, 0, 0, 0, 0]},
	{"name": "鐵騎突擊", "w": [2, 1, 0, 5, 0, 0, 0, 0, 0, 0]},
	{"name": "暗影刺殺", "w": [3, 0, 2, 0, 4, 0, 0, 0, 0, 0]},
	{"name": "劍海", "w": [5, 2, 2, 0, 0, 0, 0, 0, 0, 0]},
	{"name": "騎射混編", "w": [0, 2, 3, 3, 0, 0, 0, 0, 0, 0]},
	{"name": "槍盾方陣", "w": [1, 3, 2, 0, 0, 4, 0, 0, 0, 0]},
	{"name": "砲擊陣", "w": [2, 3, 1, 0, 0, 1, 4, 0, 0, 0]},
	{"name": "醫療鐵壁", "w": [2, 3, 2, 0, 0, 1, 0, 2, 0, 0]},
	{"name": "戰鼓衝陣", "w": [4, 1, 0, 2, 1, 0, 0, 0, 2, 0]},
	{"name": "破陣突擊", "w": [2, 0, 3, 0, 0, 1, 0, 0, 0, 4]},
]

# 每種兵偏好的欄（以藍方 0～5 表示，0＝最後排、5＝最前排；紅方自動鏡像）
const PREF_COLS := [
	[5, 4, 3],          # 劍士：前排
	[5, 4],             # 盾兵：最前排
	[0, 1, 2],          # 弓箭手：後排
	[3, 2, 4],          # 騎兵：中排兩翼
	[2, 3, 1],          # 刺客：中後排
	[4, 3],             # 長槍兵：第二排
	[0, 1],             # 投彈兵：最後排
	[1, 2],             # 醫者：後排
	[3, 2],             # 鼓手：中間
	[5, 4],             # 狂戰士：前排
]
# 擺放順序：前排先佔中間（盾、槍、劍、狂），再騎、刺、鼓、醫、彈、弓
const PLACE_ORDER := [1, 5, 0, 9, 3, 4, 8, 7, 6, 2]
const ROW_CENTER := [4, 3, 5, 2, 6, 1, 7, 0, 8]
const ROW_EDGE := [0, 8, 1, 7, 2, 6, 3, 5, 4]

## 這個模板用到的兵種是否都在 0～ntypes−1 裡。
static func template_ok(ti: int, ntypes: int) -> bool:
	var w: Array = TEMPLATES[ti]["w"]
	for t in range(ntypes, w.size()):
		if w[t] > 0:
			return false
	return true

static func eligible_templates(ntypes: int) -> Array:
	var out: Array = []
	for ti in TEMPLATES.size():
		if template_ok(ti, ntypes):
			out.append(ti)
	return out

static func build(team: int, budget: int, rng: RandomNumberGenerator, template := -1, ntypes := D.COUNT):
	var a = Army.new(team, budget)
	var el := eligible_templates(ntypes)
	if template >= 0 and not template_ok(template, ntypes):
		template = -1   # 指定的模板用到未開放的兵種：改從可用的模板抽（Codex 實作審查 #3）
	var ti := template if template >= 0 else int(el[rng.randi_range(0, el.size() - 1)])
	var w: Array = TEMPLATES[ti]["w"]
	var picks: Array = []
	var guard := 0
	while a.left() >= D.cheapest() and picks.size() < Army.MAX_UNITS and guard < 200:
		guard += 1
		var total := 0
		for t in ntypes:
			if D.cost(t) <= a.left() - _cost_sum(picks) and w[t] > 0:
				total += w[t]
		if total == 0:
			break
		var r := rng.randi_range(1, total)
		for t in ntypes:
			if D.cost(t) <= a.left() - _cost_sum(picks) and w[t] > 0:
				r -= w[t]
				if r <= 0:
					picks.append(t)
					break
		if _cost_sum(picks) > a.left():
			picks.pop_back()
			break
	# 先放盾兵、劍士，再放其他（讓前排先佔中間）
	picks.sort_custom(func(p, q): return PLACE_ORDER.find(p) < PLACE_ORDER.find(q))
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
