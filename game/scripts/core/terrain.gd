extends RefCounted
## V9 地形格（0.5 格一點）。所有查詢都用「隊伍視角」換算，左右鏡像才會逐位元一致：
## 隊伍 1 看 x 等於隊伍 0 看 W−x。導航也一律在自己視角算完再換回世界座標。
const FREE := 0
const BLOCK := 1
const SLOW := 2
const FAST := 3
const Q := 500
const SLOW_PCT := 70
const FAST_PCT := 120
const INF := 1 << 30

var w: int
var h: int
var n: int       # 欄數
var m: int       # 列數
var grid := PackedByteArray()
var nav := PackedByteArray()      # 導航不走的格（牆＋貼牆一圈），避免身體撞角
var has_block := false
var _fields := {}                 # 目的格 → 距離場
const N8 := [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [1, -1], [-1, 1], [-1, -1]]   # 固定順序破同分

func _init(rects: Array, p_w: int, p_h: int) -> void:
	w = p_w
	h = p_h
	n = w / Q
	m = h / Q
	grid.resize(n * m)
	_paint(rects, true)
	_build_nav()

## 依左半邊千分比矩形塗格子（右半邊鏡像）。all＝true 時沒蓋到的格子設回空地（建構時用）。
func _paint(rects: Array, all: bool) -> void:
	var half := n / 2
	for c in half:
		var nx: int = (c * Q + Q / 2) * 1000 / (w / 2)
		for r in m:
			var ny: int = (r * Q + Q / 2) * 1000 / h
			var v := FREE if all else -1
			for rc in rects:
				if nx >= int(rc[1]) and nx < int(rc[3]) and ny >= int(rc[2]) and ny < int(rc[4]):
					v = int(rc[0])
			if v < 0:
				continue
			grid[c + r * n] = v
			grid[n - 1 - c + r * n] = v
			if v == BLOCK:
				has_block = true

## V1.4 #10 沙盤機關：戰鬥中途改地形（崩塌成擋路）。重算導航、清掉距離場快取。只能用在 clone() 出來的那份。
func apply_rects(rects: Array) -> void:
	_paint(rects, false)
	_build_nav()
	_fields.clear()

func clone():
	var t = get_script().new([], w, h)
	t.grid = grid.duplicate()
	t.has_block = has_block
	t._build_nav()
	return t

## 這一點是不是落在（左半千分比、右半鏡像的）矩形裡。給火牆、推撞板判定用。
func in_rect(x: int, y: int, rc: Array) -> bool:
	var ox: int = x if x < w / 2 else w - x
	var nx: int = ox * 1000 / (w / 2)
	var ny: int = y * 1000 / h
	return nx >= int(rc[0]) and nx < int(rc[2]) and ny >= int(rc[1]) and ny < int(rc[3])

func _build_nav() -> void:
	nav.resize(n * m)
	nav.fill(0)
	for r2 in m:
		for c2 in n:
			if grid[c2 + r2 * n] == BLOCK:
				nav[c2 + r2 * n] = 1
				for d in N8:
					var a: int = c2 + int(d[0])
					var b: int = r2 + int(d[1])
					if a >= 0 and a < n and b >= 0 and b < m:
						nav[a + b * n] = 1

	_seal_pockets()

## 貼牆一圈算不可走之後會隔出小死角：只留最大的連通區，其他也標成不走，
## 站在死角的單位會先走到最近的主要區域。
func _seal_pockets() -> void:
	var comp := PackedInt32Array()
	comp.resize(n * m)
	comp.fill(-1)
	var best_id := -1
	var best_n := 0
	var cid := 0
	for start in n * m:
		if nav[start] == 1 or comp[start] != -1:
			continue
		var stack: Array = [start]
		comp[start] = cid
		var cnt := 0
		while not stack.is_empty():
			var idx: int = stack.pop_back()
			cnt += 1
			var c: int = idx % n
			var r: int = idx / n
			for d in N8:
				var a: int = c + int(d[0])
				var b: int = r + int(d[1])
				if a < 0 or a >= n or b < 0 or b >= m:
					continue
				var j := a + b * n
				if nav[j] == 0 and comp[j] == -1:
					comp[j] = cid
					stack.append(j)
		if cnt > best_n:
			best_n = cnt
			best_id = cid
		cid += 1
	for k in n * m:
		if nav[k] == 0 and comp[k] != best_id:
			nav[k] = 1

func digest() -> String:
	return ("%d,%d," % [w, h] + grid.hex_encode()).sha256_text().substr(0, 16)

## 自己視角的欄：隊伍 1 從右邊數。
func _col(x: int, team: int) -> int:
	var ox: int = x if team == 0 else w - x
	var c: int = clampi(ox / Q, 0, n - 1)
	return c if team == 0 else n - 1 - c

func _row(y: int) -> int:
	return clampi(y / Q, 0, m - 1)

func kind_at(x: int, y: int, team: int) -> int:
	return grid[_col(x, team) + _row(y) * n]

func blocked(x: int, y: int, team: int) -> bool:
	return kind_at(x, y, team) == BLOCK

func speed_pct(x: int, y: int, team: int) -> int:
	match kind_at(x, y, team):
		SLOW:
			return SLOW_PCT
		FAST:
			return FAST_PCT
	return 100

## 最近的可站點（世界座標）。同距用固定順序，隊伍 1 鏡像。
func free_near(x: int, y: int, team: int) -> Vector2i:
	var ox: int = x if team == 0 else w - x
	var c: int = clampi(ox / Q, 0, n - 1)
	var r: int = _row(y)
	for rad in range(0, maxi(n, m)):
		for dc in range(-rad, rad + 1):
			for dr in [-rad, rad] if absi(dc) != rad else range(-rad, rad + 1):
				var a: int = c + dc
				var b: int = r + int(dr)
				if a >= 0 and a < n and b >= 0 and b < m and grid[a + b * n] != BLOCK:
					var cx: int = a * Q + Q / 2
					return Vector2i(cx if team == 0 else w - cx, b * Q + Q / 2)
	return Vector2i(x, y)

## 自己視角的直線能不能走（格子取樣，不切角）。
func _clear(ax: int, ay: int, bx: int, by: int) -> bool:
	var dx := bx - ax
	var dy := by - ay
	var steps: int = maxi(absi(dx), absi(dy)) / (Q / 2) + 1
	for i in range(1, steps + 1):
		var x: int = ax + dx * i / steps
		var y: int = ay + dy * i / steps
		if nav[clampi(x / Q, 0, n - 1) + clampi(y / Q, 0, m - 1) * n] == 1:
			return false
	return true

## 目的格的距離場（BFS，直 10 斜 14，不切角）。
func _field(goal: int) -> PackedInt32Array:
	if _fields.has(goal):
		return _fields[goal]
	var dist := PackedInt32Array()
	dist.resize(n * m)
	dist.fill(INF)
	dist[goal] = 0
	# 小格網用簡單的桶佇列：成本只有 10／14，一輪輪掃就好
	var cur: Array = [goal]
	while not cur.is_empty():
		var nxt: Array = []
		for idx in cur:
			var c: int = idx % n
			var r: int = idx / n
			for d in N8:
				var dc: int = d[0]
				var dr: int = d[1]
				var a := c + dc
				var b := r + dr
				if a < 0 or a >= n or b < 0 or b >= m:
					continue
				var j := a + b * n
				if nav[j] == 1:
					continue
				if dc != 0 and dr != 0 and (nav[c + dc + r * n] == 1 or nav[c + (r + dr) * n] == 1):
					continue
				var nd: int = dist[idx] + (14 if dc != 0 and dr != 0 else 10)
				if nd < dist[j]:
					dist[j] = nd
					nxt.append(j)
		cur = nxt
	_fields[goal] = dist
	return dist

## 離 (c, r) 最近、導航可走的格（固定順序）。
func _nav_cell(c: int, r: int) -> int:
	if nav[c + r * n] == 0:
		return c + r * n
	for rad in range(1, maxi(n, m)):
		for dc in range(-rad, rad + 1):
			for dr in [-rad, rad] if absi(dc) != rad else range(-rad, rad + 1):
				var a: int = c + dc
				var b: int = r + int(dr)
				if a >= 0 and a < n and b >= 0 and b < m and nav[a + b * n] == 0:
					return a + b * n
	return c + r * n

## 導航下一點（世界座標）。直線可達回 (-1, -1)＝直接走目的地。
func nav_step(team: int, ux: int, uy: int, dx: int, dy: int) -> Vector2i:
	var ax: int = ux if team == 0 else w - ux
	var bx: int = dx if team == 0 else w - dx
	if _clear(ax, uy, bx, dy):
		return Vector2i(-1, -1)
	var goal := _nav_cell(clampi(bx / Q, 0, n - 1), clampi(dy / Q, 0, m - 1))
	var dist := _field(goal)
	var start := _nav_cell(clampi(ax / Q, 0, n - 1), clampi(uy / Q, 0, m - 1))
	if dist[start] >= INF:
		return Vector2i(-1, -1)      # 走不到（地圖驗證會擋；這裡退回直線，牆會擋住，時間到照判定）
	# 沿距離場走，取能直線看到的最遠一點（最多看 8 步），路線才不會鋸齒
	var cur := start
	var best := start
	for _k in 8:
		var c: int = cur % n
		var r: int = cur / n
		var nb := cur
		var nd: int = dist[cur]
		for d in N8:
			var dc: int = d[0]
			var dr: int = d[1]
			var a := c + dc
			var b := r + dr
			if a < 0 or a >= n or b < 0 or b >= m:
				continue
			var j := a + b * n
			if nav[j] == 1 or dist[j] >= nd:
				continue
			if dc != 0 and dr != 0 and (nav[c + dc + r * n] == 1 or nav[c + (r + dr) * n] == 1):
				continue
			nd = dist[j]
			nb = j
		if nb == cur:
			break
		cur = nb
		var px: int = cur % n * Q + Q / 2
		var py: int = cur / n * Q + Q / 2
		if _clear(ax, uy, px, py):
			best = cur
	var wx: int = best % n * Q + Q / 2
	var wy: int = best / n * Q + Q / 2
	return Vector2i(wx if team == 0 else w - wx, wy)

## 地圖驗證：鏡像、可達（兩邊部署區互通）、部署面積。回傳問題清單。
func validate(depth: int) -> Array:
	var bad: Array = []
	for r in m:
		for c in n:
			if grid[c + r * n] != grid[n - 1 - c + r * n]:
				bad.append("不鏡像")
				return bad
	var free_cells := 0
	var total := 0
	var starts: Array = []
	var ends: Array = []
	for r2 in m:
		for c2 in n:
			if (c2 + 1) * Q <= depth:
				total += 1
				if grid[c2 + r2 * n] != BLOCK:
					free_cells += 1
				if nav[c2 + r2 * n] == 0:
					starts.append(c2 + r2 * n)
			if c2 * Q >= w - depth and nav[c2 + r2 * n] == 0:
				ends.append(c2 + r2 * n)
	if free_cells * 100 < total * 80:
		bad.append("部署區可站面積 %d%%" % (free_cells * 100 / maxi(1, total)))
	if starts.is_empty() or ends.is_empty():
		bad.append("部署區沒有可走格")
		return bad
	var f := _field(ends[0])
	for s in starts:
		if f[s] >= INF:
			bad.append("有部署格走不到對面")
			break
	return bad
