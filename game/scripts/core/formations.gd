extends RefCounted
## 陣型產生器（平衡工具 2.0 的訓練池／保留池，優化方案 B2）。全部由種子決定。

const D = preload("res://scripts/core/unit_defs.gd")
const Army = preload("res://scripts/core/army.gd")

const STYLES := ["role", "random", "lane_top", "lane_bottom", "center", "front", "spread"]
const ROLE_COLS := [
	[5, 4, 3], [5, 4], [0, 1, 2], [3, 2, 4], [2, 3, 1],
	[4, 3], [0, 1], [1, 2], [3, 2], [5, 4],   # 第四輪：槍、彈、醫、鼓、狂
]

## 產生一套陣型。kind：
##   "mixed" 隨機權重混編；"pure" 單一兵種；"duo" 兩種兵；"template" 用 ai_army 的原型權重。
## ntypes：只用編號 0～ntypes−1 的兵種（預設全部）。亂數呼叫順序和 5 種時完全一樣，所以 ntypes＝5 會產生和舊版相同的池子。
static func random_formation(team: int, rng: RandomNumberGenerator, kind := "mixed", style := "", ntypes := D.COUNT) -> Army:
	var a := Army.new(team, 100)
	var w: Array = D.zeros()
	var nt := ntypes
	# 第四輪：支援兵（醫者、鼓手）不能當主力。純兵種、雙兵種的第一種只從戰鬥兵抽；
	# 混編裡支援兵權重最多 1、每種最多 2 隻（不然一半的池子是「100 金全拿鼓手」這種沒人會擺的陣）。
	# nt ≤ 5 時沒有支援兵，亂數呼叫順序和舊版完全一樣。
	var fighters: Array = []
	for t in nt:
		if not D.is_support(t):
			fighters.append(t)
	match kind:
		"pure":
			w[fighters[rng.randi_range(0, fighters.size() - 1)]] = 1
		"duo":
			var p: int = fighters[rng.randi_range(0, fighters.size() - 1)]
			var q := (p + rng.randi_range(1, nt - 1)) % nt
			w[p] = rng.randi_range(1, 3)
			w[q] = rng.randi_range(1, 3)
		_:
			for t in nt:
				w[t] = rng.randi_range(0, 4)
				if D.is_support(t):
					w[t] = mini(w[t], 1)
			if w.max() == 0:
				w[rng.randi_range(0, nt - 1)] = 1
	if style == "":
		style = STYLES[rng.randi_range(0, STYLES.size() - 1)]
	var picks: Array = []
	var budget_left := 100
	var guard := 0
	while picks.size() < Army.MAX_UNITS and guard < 100:
		guard += 1
		var total := 0
		for t in nt:
			if w[t] > 0 and D.cost(t) <= budget_left and not (D.is_support(t) and picks.count(t) >= 2):
				total += w[t]
		if total == 0:
			break
		var r := rng.randi_range(1, total)
		for t in nt:
			if w[t] > 0 and D.cost(t) <= budget_left and not (D.is_support(t) and picks.count(t) >= 2):
				r -= w[t]
				if r <= 0:
					picks.append(t)
					budget_left -= D.cost(t)
					break
	for t in picks:
		place_styled(a, t, style, rng)
	return a

## 指定權重的陣型（第四輪 unit_eval 用）：w 長度＝D.COUNT；權重 0 的兵種不出現。
static func weighted_formation(team: int, rng: RandomNumberGenerator, w: Array, style := "") -> Army:
	var a := Army.new(team, 100)
	if style == "":
		style = STYLES[rng.randi_range(0, STYLES.size() - 1)]
	var picks: Array = []
	var budget_left := 100
	var guard := 0
	while picks.size() < Army.MAX_UNITS and guard < 100:
		guard += 1
		var total := 0
		for t in w.size():
			if w[t] > 0 and D.cost(t) <= budget_left:
				total += w[t]
		if total == 0:
			break
		var r := rng.randi_range(1, total)
		for t in w.size():
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
## ntypes：池子只用編號 0～ntypes−1 的兵種（第四輪；5＝經典池，和第三輪的池子完全相同）。
static func pool(team: int, count: int, seed_base: int, ntypes := D.COUNT) -> Array:
	var out: Array = []
	var rng := RandomNumberGenerator.new()
	var kinds := ["mixed", "mixed", "mixed", "duo", "pure"]
	for i in count:
		rng.seed = seed_base + i * 7919
		out.append(random_formation(team, rng, kinds[i % kinds.size()], "", ntypes))
	return out

static func training_pool(team: int, ntypes := D.COUNT) -> Array:
	return pool(team, 200, 1000003, ntypes)

static func holdout_pool(team: int, ntypes := D.COUNT) -> Array:
	return pool(team, 50, 9000011, ntypes)

## 驗證池（第三輪 B1）：從來沒有用來挑參數或調關卡的 200 套，用來確認結論不是對訓練池過擬合。
static func validation_pool(team: int, ntypes := D.COUNT) -> Array:
	return pool(team, 200, 7000001, ntypes)

## 封存終驗池（第四輪 §3.4）：只在最後跑一次，不拿來調參或挑冠軍。
static func sealed_pool(team: int, ntypes := D.COUNT) -> Array:
	return pool(team, 200, 3000029, ntypes)

## 搜尋池：萬用陣搜尋演化時用的對手（跟保留池分開，避免資料洩漏）。
static func search_pool(team: int, ntypes := D.COUNT) -> Array:
	return pool(team, 60, 5000017, ntypes)

## 兵種組成向量（每種兵的金額）。
static func composition(a: Army) -> Array:
	var v := D.zeros()
	for u in a.units:
		v[u["type"]] += D.cost(u["type"])
	return v

# ───────── 第六輪：自由陣型（方案 §6.3） ─────────
## 把格子陣型轉成自由陣型。style：
##   "stretch" 欄位依縱深等比拉開（AI 用的擺法）
##   "jitter"  拉開後每隻再加 ±(1000−間距)/2 的偏移（保證間距）
##   "dense"   同樣的兵依原本前後順序，用最小間距排成交錯（六角）密集陣
## 結果一定合法（不合法的點略過）；部署限制照 r（deploy 必須是 free）。
static func to_free(src: Army, r, rng: RandomNumberGenerator, style := "stretch") -> Army:
	var a := Army.new(src.team, src.budget)
	a.apply_rules(r, src.team)
	a.guard_combat = false
	a.depth = r.depth   # 自己的半場（全場模式也一樣，AI 只擺自己這邊）
	var depth: int = r.depth
	var j: int = (1000 - int(r.spacing)) / 2
	if style == "dense":
		# 依「自己視角 x 由大到小（前排先）」排序，用六角排列填
		var lst: Array = []
		for u in src.units:
			var p := Army.pos_of(u)
			lst.append([-src.own_x(p.x) * 10 + int(u["row"]) if u.has("row") else 0, int(u["type"])])
		lst.sort_custom(func(p, q): return p[0] < q[0])
		var sp: int = r.spacing
		var rows_per_col := maxi(1, (8600 - 200) / sp + 1)
		var dx_col := int(sp * 0.87)
		var k := 0
		for e in lst:
			var col := k / rows_per_col
			var rr := k % rows_per_col
			var ox := Army.quant(depth - col * dx_col)
			var y := Army.quant(400 + rr * sp + (sp / 2 if col % 2 == 1 else 0))
			a.place_xy(e[1], a.world_x(ox), y)
			k += 1
		return a
	for u in src.units:
		var p := Army.pos_of(u)
		var ox: int = src.own_x(p.x)
		var nox := 500 + (ox - 500) * (depth - 1000) / 5000
		var ny := p.y
		if style == "jitter" and j > 0:
			nox += rng.randi_range(-j, j)
			ny += rng.randi_range(-j, j)
		nox = clampi(Army.quant(nox), Army.EDGE, depth)
		ny = clampi(Army.quant(ny), Army.EDGE, Army.H - Army.EDGE)
		a.place_xy(int(u["type"]), a.world_x(nox), ny)
	return a

## 自由陣型池：同一個格子池，各自轉成 stretch／jitter／dense（種子固定）。
static func free_pool(team: int, count: int, seed_base: int, r, ntypes := D.COUNT) -> Array:
	var out: Array = []
	var grid := pool(team, count, seed_base, ntypes)
	var rng := RandomNumberGenerator.new()
	for i in grid.size():
		rng.seed = seed_base * 7 + i
		out.append(to_free(grid[i], r, rng, ["stretch", "jitter", "dense"][i % 3]))
	return out
