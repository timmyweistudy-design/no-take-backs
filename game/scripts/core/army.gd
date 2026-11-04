extends RefCounted
## 一方的陣型：預算、人數上限、部署區、格子佔用。純資料，不碰畫面。

## 擺放錯誤碼（第七輪 H6）：畫面靠這些常數判斷，不再比對中文字串。查過：這些字串沒有進任何代碼或存檔。
const E_ZONE := "只能放在自己的部署區"
const E_TAKEN := "這格已經有兵"
const E_POOL := "這種兵不在這局的卡池裡"
const E_GOLD := "錢不夠"
const E_RESERVE := "要留錢和名額給至少 1 隻戰鬥兵"
const E_NEAR := "離其他兵太近"
const E_NEAR_ENEMY := "離敵兵太近"
const E_CAP_PREFIX := "最多"
const E_TYPE_CAP_PREFIX := "這種兵最多"
const D = preload("res://scripts/core/unit_defs.gd")

const COLS := 16
const ROWS := 9
const ZONE := 6          # 每邊部署區 6 欄
const MAX_UNITS := 24

var team: int
var budget: int
var units: Array = []    # 每筆 {"type", "col", "row"}
# 第五輪：自訂規則的部署限制（預設值＝1.3.0 行為）
var pool := (1 << D.COUNT) - 1   # 可用兵種遮罩
var unit_cap := MAX_UNITS
var type_cap := 0                # 單種上限，0＝不限
var guard_combat := false        # 防卡死：還沒擺戰鬥兵時，不准擺到買不起戰鬥兵（只有玩家擺放與 AI 用，載入舊代碼不開）
# 第六輪：自由排兵（docs/2026-11-03-free-placement-plan-v6.md §3）
# 自由部署的 units 每筆是 {"type", "x", "y"}（世界座標、量化到 50）；格子部署照舊 {"type", "col", "row"}。
const W := COLS * 1000
const H := ROWS * 1000
const EDGE := 200
const QUANT := 50
const E_TERRAIN := "err_terrain"
var deploy := "grid"
var spacing := 1000              # 己方兩隻的最小中心距離
var depth := 6000                # 自己視角 x 上限（全場＝15800）
var enemy_pos: Array = []        # 全場時：敵兵的世界座標（Vector2i），離它們至少 ENEMY_GAP
var enemy_gap := 1500
# V9 地圖：場地大小與地形（標準＝16×9、沒有地形）
var fw := W
var fh := H
var terrain = null

func _init(p_team: int = 0, p_budget: int = 100) -> void:
	team = p_team
	budget = p_budget

func spent() -> int:
	var s := 0
	for u in units:
		s += D.cost(u["type"])
	return s

func left() -> int:
	return budget - spent()

func count() -> int:
	return units.size()

func count_of(t: int) -> int:
	var n := 0
	for u in units:
		if u["type"] == t:
			n += 1
	return n

func in_zone(col: int, row: int) -> bool:
	if row < 0 or row >= ROWS:
		return false
	if team == 0:
		return col >= 0 and col < ZONE
	return col >= COLS - ZONE and col < COLS

func index_at(col: int, row: int) -> int:
	for i in units.size():
		if units[i]["col"] == col and units[i]["row"] == row:
			return i
	return -1

## 回傳空字串＝可以放；否則是不能放的原因（顯示給玩家）。
func check_place(t: int, col: int, row: int) -> String:
	if deploy == "free":
		return check_place_xy(t, col * 1000 + 500, row * 1000 + 500)
	if not in_zone(col, row):
		return E_ZONE
	if index_at(col, row) != -1:
		return E_TAKEN
	return _check_common(t)

## 位置以外的條件（卡池、人數、單種、錢、防卡死），格子與自由共用。
func _check_common(t: int) -> String:
	if t < 0 or t >= D.total() or (pool >> t) & 1 == 0:
		return E_POOL
	if count() >= unit_cap:
		return E_CAP_PREFIX + " %d 隻" % unit_cap
	if type_cap > 0 and count_of(t) >= type_cap:
		return E_TYPE_CAP_PREFIX + " %d 隻" % type_cap
	var hc := D.hard_cap(t)     # 第八輪：奇幻兵一隊的硬上限
	if hc > 0 and count_of(t) >= hc:
		return E_TYPE_CAP_PREFIX + " %d 隻" % hc
	if D.cost(t) > left():
		return E_GOLD
	if guard_combat and not D.is_combat(t) and not has_combat():
		var cc := cheapest_combat()
		if count() + 1 >= unit_cap or left() - D.cost(t) < cc:
			return E_RESERVE
	return ""

## 第五輪：有沒有擺戰鬥兵（開戰條件：雙方各至少 1 隻）。
func has_combat() -> bool:
	for u in units:
		if D.is_combat(int(u["type"])):
			return true
	return false

func cheapest_combat() -> int:
	var c := 1 << 30
	for t in D.total():
		if (pool >> t) & 1 == 1 and D.is_combat(t):
			c = mini(c, D.cost(t))
	return c

func cheapest_in_pool() -> int:
	var c := 1 << 30
	for t in D.total():
		if (pool >> t) & 1 == 1 and (type_cap == 0 or count_of(t) < type_cap):
			c = mini(c, D.cost(t))
	return c

## 第五輪：套用規則（部署層）。
func apply_rules(r, p_team: int) -> void:
	budget = r.budget_of(p_team)
	pool = r.pool_of(p_team)
	unit_cap = r.unit_cap
	type_cap = r.type_cap
	guard_combat = true
	deploy = r.deploy
	spacing = r.spacing
	depth = r.depth_of()
	enemy_gap = r.ENEMY_GAP
	fw = r.field_w()
	fh = r.field_h()
	terrain = r.terrain()

func _copy_limits(a) -> void:
	a.pool = pool
	a.unit_cap = unit_cap
	a.type_cap = type_cap
	a.guard_combat = guard_combat
	a.deploy = deploy
	a.spacing = spacing
	a.depth = depth
	a.enemy_gap = enemy_gap
	a.enemy_pos = enemy_pos.duplicate()
	a.fw = fw
	a.fh = fh
	a.terrain = terrain

func place(t: int, col: int, row: int) -> bool:
	if deploy == "free":
		return place_xy(t, col * 1000 + 500, row * 1000 + 500)
	if check_place(t, col, row) != "":
		return false
	units.append({"type": t, "col": col, "row": row})
	return true

# ───────── 第六輪：自由座標 ─────────
## 自己視角的 x（藍方原樣、紅方 16000−x）；鏡像不變。
func own_x(x: int) -> int:
	return x if team == 0 else fw - x

func world_x(ox: int) -> int:
	return ox if team == 0 else fw - ox

## 量化（§3.8）：q(v)＝floor((v＋24)／50)×50，剛好一半往小的方向（225→200、226→250）。
static func quant(v: int) -> int:
	return int(floor((v + 24) / 50.0)) * 50

## 這一隻的世界座標（格子部署＝格子中心）。
static func pos_of(u: Dictionary) -> Vector2i:
	if u.has("x"):
		return Vector2i(int(u["x"]), int(u["y"]))
	return Vector2i(int(u["col"]) * 1000 + 500, int(u["row"]) * 1000 + 500)

func in_zone_xy(x: int, y: int) -> bool:
	var ox := own_x(x)
	return ox >= EDGE and ox <= depth and y >= EDGE and y <= fh - EDGE

## 自由部署能不能放（自己座標、量化、部署區、間距、全場敵距＋共同條件）。skip＝檢查間距時略過的己方索引（搬移用）。
func check_place_xy(t: int, x: int, y: int, skip := -1) -> String:
	if x % QUANT != 0 or y % QUANT != 0:
		return "位置沒有對齊 0.05 格"
	if not in_zone_xy(x, y):
		return E_ZONE
	if terrain != null and terrain.blocked(x, y, team):
		return E_TERRAIN
	var s2 := spacing * spacing
	for i in units.size():
		if i == skip:
			continue
		var p := pos_of(units[i])
		var dx := p.x - x
		var dy := p.y - y
		if dx * dx + dy * dy < s2:
			return E_NEAR
	var g2 := enemy_gap * enemy_gap
	for e in enemy_pos:
		var dx2: int = e.x - x
		var dy2: int = e.y - y
		if dx2 * dx2 + dy2 * dy2 < g2:
			return E_NEAR_ENEMY
	if skip >= 0:
		return ""
	return _check_common(t)

func place_xy(t: int, x: int, y: int) -> bool:
	if deploy != "free" or check_place_xy(t, x, y) != "":
		return false
	units.append({"type": t, "x": x, "y": y})
	return true

## 最近的一隻（在半徑 r 內），沒有回 -1。點選、搬移、刪除用（第六輪 §5：和精確查找分開）。
func index_near(x: int, y: int, r: int) -> int:
	var best := -1
	var bd := r * r + 1
	for i in units.size():
		var p := pos_of(units[i])
		var d := (p.x - x) * (p.x - x) + (p.y - y) * (p.y - y)
		if d < bd:
			bd = d
			best = i
	return best

## 把第 i 隻搬到 (x, y)（自由部署）；不合法就不動。
func move_xy(i: int, x: int, y: int) -> bool:
	if i < 0 or i >= units.size() or check_place_xy(int(units[i]["type"]), x, y, i) != "":
		return false
	units[i]["x"] = x
	units[i]["y"] = y
	return true

## 整群剛體平移（§3.8）：只量化共同位移；碰到部署區邊界就把位移夾到剛好貼邊；撞到群外的兵或敵兵禁區就整群不動。
## 回傳實際的位移（不動回 Vector2i(-99999, -99999)）。
func move_group(idx: Array, dx: int, dy: int) -> Vector2i:
	if idx.is_empty():
		return Vector2i(-99999, -99999)
	dx = quant(dx)
	dy = quant(dy)
	var lo_x := -(1 << 30)
	var hi_x := 1 << 30
	var lo_y := -(1 << 30)
	var hi_y := 1 << 30
	for i in idx:
		var p := pos_of(units[i])
		var ox := own_x(p.x)
		# 自己視角的 x 範圍換回世界位移的範圍
		var wmin := world_x(EDGE) - p.x
		var wmax := world_x(depth) - p.x
		lo_x = maxi(lo_x, mini(wmin, wmax))
		hi_x = mini(hi_x, maxi(wmin, wmax))
		lo_y = maxi(lo_y, EDGE - p.y)
		hi_y = mini(hi_y, fh - EDGE - p.y)
	dx = clampi(dx, lo_x, hi_x)
	dy = clampi(dy, lo_y, hi_y)
	dx = clampi(quant(dx), lo_x, hi_x)
	dy = clampi(quant(dy), lo_y, hi_y)
	var moved := {}
	for i in idx:
		moved[i] = true
	var s2 := spacing * spacing
	var g2 := enemy_gap * enemy_gap
	for i in idx:
		var p := pos_of(units[i]) + Vector2i(dx, dy)
		for j in units.size():
			if moved.has(j):
				continue
			var q := pos_of(units[j])
			if (q.x - p.x) * (q.x - p.x) + (q.y - p.y) * (q.y - p.y) < s2:
				return Vector2i(-99999, -99999)
		for e in enemy_pos:
			if (e.x - p.x) * (e.x - p.x) + (e.y - p.y) * (e.y - p.y) < g2:
				return Vector2i(-99999, -99999)
	for i in idx:
		var p := pos_of(units[i])
		units[i]["x"] = p.x + dx
		units[i]["y"] = p.y + dy
	return Vector2i(dx, dy)

## 上下翻轉一群（§4.1 的 M）：y → 9000−y（以群的中線為準就會跑出場，所以用整個場地的中線）；不合法就不動。
func flip_group(idx: Array) -> bool:
	var newp := {}
	for i in idx:
		var p := pos_of(units[i])
		newp[i] = Vector2i(p.x, fh - p.y)
	var keep := units.duplicate(true)
	for i in idx:
		units[i]["x"] = newp[i].x
		units[i]["y"] = newp[i].y
	for i in idx:
		var p: Vector2i = newp[i]
		if check_place_xy(int(units[i]["type"]), p.x, p.y, i) != "":
			units = keep
			return false
	return true

## 還有沒有任何合法位置能放卡池裡買得起的兵（§3.8「沒有合法位置」）。
## 完整搜尋 0.05 格點陣（Codex 實作第 1 輪：粗點陣會誤判「沒位置」）：先把每個障礙圓蓋到的點標掉，再找沒被蓋的點，最後用 check_place_xy 確認。
func has_room() -> bool:
	if deploy != "free":
		return true
	var types: Array = []
	for t in D.total():
		if _check_common(t) == "":
			types.append(t)
	if types.is_empty():
		return false
	var t0: int = types[0]
	var nx := (depth - EDGE) / QUANT + 1     # 自己視角 x：EDGE..depth
	var ny := (fh - 2 * EDGE) / QUANT + 1     # y：EDGE..H−EDGE
	if nx <= 0 or ny <= 0:
		return false
	var cov := PackedByteArray()
	cov.resize(nx * ny)
	var obs: Array = []
	for u in units:
		var p := pos_of(u)
		obs.append([own_x(p.x), p.y, spacing])
	for e in enemy_pos:
		obs.append([own_x(e.x), e.y, enemy_gap])
	for o in obs:
		var r: int = o[2]
		var r2 := r * r
		var i0 := maxi(0, (int(o[0]) - r - EDGE) / QUANT - 1)
		var i1 := mini(nx - 1, (int(o[0]) + r - EDGE) / QUANT + 1)
		var j0 := maxi(0, (int(o[1]) - r - EDGE) / QUANT - 1)
		var j1 := mini(ny - 1, (int(o[1]) + r - EDGE) / QUANT + 1)
		for i in range(i0, i1 + 1):
			var dx: int = EDGE + i * QUANT - int(o[0])
			for j in range(j0, j1 + 1):
				var dy: int = EDGE + j * QUANT - int(o[1])
				if dx * dx + dy * dy < r2:
					cov[i * ny + j] = 1
	for i in nx:
		for j in ny:
			if cov[i * ny + j] == 0 and check_place_xy(t0, world_x(EDGE + i * QUANT), EDGE + j * QUANT) == "":
				return true
	return false

func remove_at(col: int, row: int) -> bool:
	var i := index_at(col, row)
	if i == -1:
		return false
	units.remove_at(i)
	return true

func move(fc: int, fr: int, tc: int, tr: int) -> bool:
	var i := index_at(fc, fr)
	if i == -1 or not in_zone(tc, tr) or index_at(tc, tr) != -1:
		return false
	units[i]["col"] = tc
	units[i]["row"] = tr
	return true

func clear() -> void:
	units.clear()

func can_afford_any() -> bool:
	if count() >= unit_cap:
		return false
	if guard_combat and not has_combat():
		return left() >= cheapest_combat()
	return left() >= cheapest_in_pool()

func copy():
	var a = get_script().new(team, budget)
	a.units = units.duplicate(true)
	_copy_limits(a)
	return a

## 左右鏡像並換隊（測試先手偏差用）。
func mirrored():
	var a = get_script().new(1 - team, budget)
	_copy_limits(a)
	a.enemy_pos = []
	for e in enemy_pos:
		a.enemy_pos.append(Vector2i(fw - e.x, e.y))
	for u in units:
		if u.has("x"):
			a.units.append({"type": u["type"], "x": fw - int(u["x"]), "y": u["y"]})
		else:
			a.units.append({"type": u["type"], "col": COLS - 1 - u["col"], "row": u["row"]})
	return a

## 陣型代碼（優化方案 E3）：NTB1.<base64url>.<校驗 4 碼>。
## 位元組：[版本 1, 隻數, 每隻 (兵種<<4 | 以藍方表示的欄 0～5), 列]。欄位一律存成「自己這一側」，所以紅藍都能讀。
const CODE_VERSION := 1

func to_code() -> String:
	if D.uses_new([self]):
		return to_code6()   # 第八輪：用到新兵才用新格式；只有舊兵時輸出不變，舊版還讀得懂
	if deploy == "free":
		return to_code5()
	var b := PackedByteArray([CODE_VERSION, units.size()])
	for u in units:
		var c: int = u["col"] if team == 0 else COLS - 1 - u["col"]
		b.append((int(u["type"]) << 4) | c)
		b.append(u["row"])
	var body := Marshalls.raw_to_base64(b).replace("+", "-").replace("/", "_").replace("=", "")
	return "NTB1.%s.%s" % [body, body.sha256_text().substr(0, 4)]

## 解碼並驗證；成功回傳 ""，失敗回傳原因（不改動目前陣型）。
func load_code(code: String) -> String:
	var parts := code.strip_edges().split(".")
	if parts.size() == 3 and parts[0] == "NTB5":
		return load_code5(code)
	if parts.size() == 3 and parts[0] == "NTB6":
		return load_code6(code)
	if parts.size() != 3 or parts[0] != "NTB1":
		return "格式不對"
	if parts[1].sha256_text().substr(0, 4) != parts[2]:
		return "校驗碼不符"
	var b64 := parts[1].replace("-", "+").replace("_", "/")
	while b64.length() % 4 != 0:
		b64 += "="
	var b := Marshalls.base64_to_raw(b64)
	if b.size() < 2 or b[0] != CODE_VERSION or b.size() != 2 + b[1] * 2:
		return "版本或長度不對"
	var tmp = get_script().new(team, budget)
	_copy_limits(tmp)
	tmp.guard_combat = false
	for i in b[1]:
		var t: int = b[2 + i * 2] >> 4
		var c: int = b[2 + i * 2] & 15
		var r: int = b[3 + i * 2]
		if t >= D.COUNT or c > 5:
			return "內容不合法"
		var col: int = c if team == 0 else COLS - 1 - c
		if not tmp.place(t, col, r):
			return "超過預算、人數或格子重複"
	units = tmp.units
	return ""


# ───────── 第六輪：陣型代碼 NTB5（§3.6、§3.8） ─────────
## NTB5.<base64url>.<校驗 4 碼>；內容 [版本 5][隻數][每隻 3 bytes 大端：兵種 4｜自己視角 x÷50 9｜y÷50 8｜保留 3（0）]。
## 輸出順序＝擺放順序（不排序）。54 是格式上限；規則的人數上限另外驗。
const CODE5_VERSION := 5
const CODE5_MAX := 54

func to_code5() -> String:
	var b := PackedByteArray([CODE5_VERSION, units.size()])
	for u in units:
		var p := pos_of(u)
		var v: int = (int(u["type"]) << 20) | ((own_x(p.x) / QUANT) << 11) | ((p.y / QUANT) << 3)
		b.append((v >> 16) & 255)
		b.append((v >> 8) & 255)
		b.append(v & 255)
	var body := Marshalls.raw_to_base64(b).replace("+", "-").replace("/", "_").replace("=", "")
	return "NTB5.%s.%s" % [body, body.sha256_text().substr(0, 4)]

func load_code5(code: String) -> String:
	var parts := code.strip_edges().split(".")
	if parts.size() != 3 or parts[0] != "NTB5":
		return "格式不對"
	if parts[1].sha256_text().substr(0, 4) != parts[2]:
		return "校驗碼不符"
	var b64 := parts[1].replace("-", "+").replace("_", "/")
	while b64.length() % 4 != 0:
		b64 += "="
	var b := Marshalls.base64_to_raw(b64)
	if b.size() < 2 or b[0] != CODE5_VERSION or b[1] > CODE5_MAX or b.size() != 2 + b[1] * 3:
		return "版本或長度不對"
	if deploy != "free":
		return "這是自由陣型，現在是格子規則"
	var tmp = get_script().new(team, budget)
	_copy_limits(tmp)
	tmp.guard_combat = false
	for i in b[1]:
		var v: int = (b[2 + i * 3] << 16) | (b[3 + i * 3] << 8) | b[4 + i * 3]
		if v & 7 != 0:
			return "內容不合法"
		var t := v >> 20
		var ox := ((v >> 11) & 511) * QUANT
		var y := ((v >> 3) & 255) * QUANT
		if t >= D.COUNT:
			return "內容不合法"
		if not tmp.place_xy(t, world_x(ox), y):
			return "超過預算、人數、部署區或離太近"
	units = tmp.units
	return ""

# ───────── 第八輪：陣型代碼 NTB6 ─────────
## NTB6.<base64url>.<校驗 4 碼>；[版本 6][模式 0 格子／1 自由][隻數][每隻 4 bytes：兵種，再來格子＝欄、列、0；自由＝自己視角 x、y 量化後 3 bytes]。
const CODE6_VERSION := 6

func to_code6() -> String:
	var fr: bool = deploy == "free"
	var b := PackedByteArray([CODE6_VERSION, 1 if fr else 0, units.size()])
	for u in units:
		b.append(int(u["type"]))
		if fr:
			var p := pos_of(u)
			var v: int = ((own_x(p.x) / QUANT) << 11) | ((p.y / QUANT) << 3)
			b.append((v >> 16) & 255)
			b.append((v >> 8) & 255)
			b.append(v & 255)
		else:
			b.append(int(u["col"]) if team == 0 else COLS - 1 - int(u["col"]))
			b.append(int(u["row"]))
			b.append(0)
	var body := Marshalls.raw_to_base64(b).replace("+", "-").replace("/", "_").replace("=", "")
	return "NTB6.%s.%s" % [body, body.sha256_text().substr(0, 4)]

func load_code6(code: String) -> String:
	var parts := code.strip_edges().split(".")
	if parts.size() != 3 or parts[0] != "NTB6":
		return "格式不對"
	if parts[1].sha256_text().substr(0, 4) != parts[2]:
		return "校驗碼不符"
	var b64 := parts[1].replace("-", "+").replace("_", "/")
	while b64.length() % 4 != 0:
		b64 += "="
	var b := Marshalls.base64_to_raw(b64)
	if b.size() < 3 or b[0] != CODE6_VERSION or b[1] > 1 or b[2] > CODE5_MAX or b.size() != 3 + b[2] * 4:
		return "版本或長度不對"
	var fr: bool = b[1] == 1
	if fr and deploy != "free":
		return "這是自由陣型，現在是格子規則"
	var tmp = get_script().new(team, budget)
	_copy_limits(tmp)
	tmp.guard_combat = false
	for i in b[2]:
		var o := 3 + i * 4
		var t: int = b[o]
		if t >= D.total():
			return "內容不合法"
		if fr:
			var v: int = (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3]
			if v & 7 != 0 or (v >> 20) != 0:
				return "內容不合法"
			if not tmp.place_xy(t, own_x(((v >> 11) & 511) * QUANT), ((v >> 3) & 255) * QUANT):
				return "超過預算、人數、部署區或離太近"
		else:
			if b[o + 1] > 5 or b[o + 3] != 0:
				return "內容不合法"
			if not tmp.place(t, b[o + 1] if team == 0 else COLS - 1 - b[o + 1], b[o + 2]):
				return "超過預算、人數或格子重複"
	units = tmp.units
	return ""

## 格子陣型（NTB1）轉成自由座標（格子中心）；自由規則載入舊陣型用。
func grid_to_free() -> void:
	for u in units:
		if u.has("col"):
			var p := pos_of(u)
			u.erase("col")
			u.erase("row")
			u["x"] = p.x
			u["y"] = p.y
