extends RefCounted
## 陣型產生器（平衡工具 2.0 的訓練池／保留池，優化方案 B2）。全部由種子決定。

const D = preload("res://scripts/core/unit_defs.gd")
const Army = preload("res://scripts/core/army.gd")

const STYLES := ["role", "random", "lane_top", "lane_bottom", "center", "front", "spread"]
const ROLE_COLS := [
	[5, 4, 3], [5, 4], [0, 1, 2], [3, 2, 4], [2, 3, 1],
]

## 產生一套陣型。kind：
##   "mixed" 隨機權重混編；"pure" 單一兵種；"duo" 兩種兵；"template" 用 ai_army 的原型權重。
static func random_formation(team: int, rng: RandomNumberGenerator, kind := "mixed", style := "") -> Army:
	var a := Army.new(team, 100)
	var w: Array = [0, 0, 0, 0, 0]
	match kind:
		"pure":
			w[rng.randi_range(0, 4)] = 1
		"duo":
			var p := rng.randi_range(0, 4)
			var q := (p + rng.randi_range(1, 4)) % 5
			w[p] = rng.randi_range(1, 3)
			w[q] = rng.randi_range(1, 3)
		_:
			for t in 5:
				w[t] = rng.randi_range(0, 4)
			if w.max() == 0:
				w[rng.randi_range(0, 4)] = 1
	if style == "":
		style = STYLES[rng.randi_range(0, STYLES.size() - 1)]
	var picks: Array = []
	var budget_left := 100
	var guard := 0
	while picks.size() < Army.MAX_UNITS and guard < 100:
		guard += 1
		var total := 0
		for t in 5:
			if w[t] > 0 and D.cost(t) <= budget_left:
				total += w[t]
		if total == 0:
			break
		var r := rng.randi_range(1, total)
		for t in 5:
			if w[t] > 0 and D.cost(t) <= budget_left:
				r -= w[t]
				if r <= 0:
					picks.append(t)
					budget_left -= D.cost(t)
					break
	for t in picks:
		place_styled(a, t, style, rng)
	return a

static func place_styled(a: Army, t: int, style: String, rng: RandomNumberGenerator) -> void:
	var cols: Array
	var rows: Array
	match style:
		"random":
			for _i in 60:
				var c := rng.randi_range(0, 5)
				var r := rng.randi_range(0, 8)
				if a.place(t, _abs_col(a, c), r):
					return
			cols = [5, 4, 3, 2, 1, 0]
			rows = [4, 3, 5, 2, 6, 1, 7, 0, 8]
		"lane_top":
			cols = ROLE_COLS[t] + [5, 4, 3, 2, 1, 0]
			rows = [0, 1, 2, 3, 4, 5, 6, 7, 8]
		"lane_bottom":
			cols = ROLE_COLS[t] + [5, 4, 3, 2, 1, 0]
			rows = [8, 7, 6, 5, 4, 3, 2, 1, 0]
		"front":
			cols = [5, 4, 3, 2, 1, 0]
			rows = [4, 3, 5, 2, 6, 1, 7, 0, 8]
		"spread":
			cols = ROLE_COLS[t] + [5, 4, 3, 2, 1, 0]
			rows = [0, 8, 4, 2, 6, 1, 7, 3, 5]
		_:   # role / center
			cols = ROLE_COLS[t] + [5, 4, 3, 2, 1, 0]
			rows = [4, 3, 5, 2, 6, 1, 7, 0, 8] if (style == "center" or t != D.CAVALRY) else [0, 8, 1, 7, 2, 6, 3, 5, 4]
	for c in cols:
		for r in rows:
			if a.place(t, _abs_col(a, c), r):
				return

## 藍方 0＝最後排、5＝最前排；紅方鏡像。
static func _abs_col(a: Army, c: int) -> int:
	return c if a.team == 0 else Army.COLS - 1 - c

## 訓練池（200）與保留池（50）：不同種子範圍，保留池不參與調參。
static func pool(team: int, count: int, seed_base: int) -> Array:
	var out: Array = []
	var rng := RandomNumberGenerator.new()
	var kinds := ["mixed", "mixed", "mixed", "duo", "pure"]
	for i in count:
		rng.seed = seed_base + i * 7919
		out.append(random_formation(team, rng, kinds[i % kinds.size()]))
	return out

static func training_pool(team: int) -> Array:
	return pool(team, 200, 1000003)

static func holdout_pool(team: int) -> Array:
	return pool(team, 50, 9000011)

## 兵種組成向量（每種兵的金額）。
static func composition(a: Army) -> Array:
	var v := [0, 0, 0, 0, 0]
	for u in a.units:
		v[u["type"]] += D.cost(u["type"])
	return v
