extends RefCounted
## 一方的陣型：預算、人數上限、部署區、格子佔用。純資料，不碰畫面。

const D = preload("res://scripts/core/unit_defs.gd")

const COLS := 16
const ROWS := 9
const ZONE := 6          # 每邊部署區 6 欄
const MAX_UNITS := 24

var team: int
var budget: int
var units: Array = []    # 每筆 {"type", "col", "row"}

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
	if not in_zone(col, row):
		return "只能放在自己的部署區"
	if index_at(col, row) != -1:
		return "這格已經有兵"
	if count() >= MAX_UNITS:
		return "最多 %d 隻" % MAX_UNITS
	if D.cost(t) > left():
		return "錢不夠"
	return ""

func place(t: int, col: int, row: int) -> bool:
	if check_place(t, col, row) != "":
		return false
	units.append({"type": t, "col": col, "row": row})
	return true

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
	return count() < MAX_UNITS and left() >= D.cheapest()

func copy():
	var a = get_script().new(team, budget)
	a.units = units.duplicate(true)
	return a

## 左右鏡像並換隊（測試先手偏差用）。
func mirrored():
	var a = get_script().new(1 - team, budget)
	for u in units:
		a.units.append({"type": u["type"], "col": COLS - 1 - u["col"], "row": u["row"]})
	return a

## 陣型代碼（優化方案 E3）：NTB1.<base64url>.<校驗 4 碼>。
## 位元組：[版本 1, 隻數, 每隻 (兵種<<4 | 以藍方表示的欄 0～5), 列]。欄位一律存成「自己這一側」，所以紅藍都能讀。
const CODE_VERSION := 1

func to_code() -> String:
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
