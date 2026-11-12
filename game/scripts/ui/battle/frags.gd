extends RefCounted
## 1.2.0 §8.2 材料碎片：命中、治療、火、冰掉在地上的小實物碎片（木屑、墨點、木刻火片、白瓷碎片、薄荷葉、紫水彩暈）。
## 規格（方案 §8.2，Antigravity 第 4 輪／Codex 第 3 輪）：每片 3～6px；一次最多 4 片；落地有小影、停 0.25 秒、0.1 秒淡出；
## 單一棋盤格（44px）內最多 2 片、滿了換掉該格最舊的；總數 ≤ 30、超額丟最舊的。和 FX_CAP（特效事件）分開計數，
## 碎片純裝飾，被丟掉不影響任何預警、攻擊、跳字。位置與形狀只由（事件 tick、單位 id、第幾片）決定，截圖可重現。
const CELL := 44.0
const PER_CELL := 2
const TOTAL := 30
const PER_HIT := 4
const STAY := 0.25
const FADE := 0.1
const GRAV := 900.0
## 材料：顏色、邊色、形狀（0 木屑長方、1 墨點、2 火片三角、3 瓷片四邊、4 葉片、5 水彩暈）
const MAT := {
	"wood": [Color("#a8743f"), Color("#5a3a1e"), 0], "ink": [Color("#261c14"), Color("#261c14"), 1],
	"fire": [Color("#d9532b"), Color("#7a2410"), 2], "ice": [Color("#f4f1ea"), Color("#8fb3c9"), 3],
	"leaf": [Color("#8fd6a8"), Color("#3e7d55"), 4], "poison": [Color(0.55, 0.35, 0.75, 0.55), Color(0.4, 0.2, 0.6, 0.0), 5],
}

var list: Array = []   # {p: 地面位置, z: 離地高, vx, vz, mat, sz, rot, t: 落地後經過, land: bool, born: 序號}
var _seq := 0

func clear() -> void:
	list.clear()

## p＝地面位置（螢幕／世界繪製座標）；n 片（會夾到 PER_HIT）；key＝決定散射方向的種子（tick×4096＋id）
func spawn(p: Vector2, mat: String, n: int, key: int, h := 18.0) -> void:
	if not MAT.has(mat):
		return
	for k in mini(n, PER_HIT):
		var r := _hash01(key * 7 + k)
		var r2 := _hash01(key * 13 + k * 3 + 1)
		var f := {"p": p + Vector2((r - 0.5) * 10.0, (r2 - 0.5) * 6.0), "z": h, "vx": (r - 0.5) * 140.0, "vz": 120.0 + r2 * 90.0,
			"mat": mat, "sz": 3.0 + floorf(r2 * 4.0), "rot": r * TAU, "t": 0.0, "land": false, "born": _seq}
		_seq += 1
		_admit(f)

func _admit(f: Dictionary) -> void:
	var c := _cell(f["p"])
	var same: Array = []
	for i in list.size():
		if _cell(list[i]["p"]) == c:
			same.append(i)
	if same.size() >= PER_CELL:
		list.remove_at(_oldest(same))
	if list.size() >= TOTAL:
		var all: Array = []
		for j in list.size():
			all.append(j)
		list.remove_at(_oldest(all))
	list.append(f)

func _oldest(idx: Array) -> int:
	var best: int = idx[0]
	for i in idx:
		if int(list[i]["born"]) < int(list[best]["born"]):
			best = i
	return best

func _cell(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / CELL)), int(floor(p.y / CELL)))

static func _hash01(k: int) -> float:
	var h := (k * 2654435761) & 0xffffffff
	h = ((h >> 16) ^ h) * 0x45d9f3b & 0xffffffff
	return float((h >> 8) & 0xffff) / 65535.0

func step(dt: float) -> void:
	var keep: Array = []
	for f in list:
		if not f["land"]:
			f["vz"] = float(f["vz"]) - GRAV * dt
			f["z"] = float(f["z"]) + float(f["vz"]) * dt
			f["p"] = f["p"] + Vector2(float(f["vx"]) * dt, 0.0)
			if float(f["z"]) <= 0.0:
				f["z"] = 0.0
				f["land"] = true
		else:
			f["t"] = float(f["t"]) + dt
		if float(f["t"]) < STAY + FADE:
			keep.append(f)
	list = keep

func draw(ci: CanvasItem) -> void:
	for f in list:
		var m: Array = MAT[f["mat"]]
		var a := 1.0 if float(f["t"]) <= STAY else clampf(1.0 - (float(f["t"]) - STAY) / FADE, 0.0, 1.0)
		var base: Vector2 = f["p"]
		var c := Vector2(base.x, base.y - float(f["z"]))
		var s: float = f["sz"]
		if f["land"] and int(m[2]) != 5:
			ci.draw_circle(base + Vector2(1.5, 1.5), s * 0.55, Color(0.1, 0.06, 0.03, 0.28 * a))   # 光從左上：影子落右下
		var col: Color = m[0]
		col.a *= a
		var ec: Color = m[1]
		ec.a *= a
		var rot: float = f["rot"]
		match int(m[2]):
			0:
				var d := Vector2(cos(rot), sin(rot))
				ci.draw_line(c - d * s * 0.5, c + d * s * 0.5, col, 2.0)
			1:
				ci.draw_circle(c, s * 0.4, col)
			2:
				var pts := PackedVector2Array([c + Vector2(0, -s * 0.6).rotated(rot), c + Vector2(s * 0.45, s * 0.4).rotated(rot), c + Vector2(-s * 0.45, s * 0.4).rotated(rot)])
				ci.draw_colored_polygon(pts, col)
			3:
				var q := PackedVector2Array([c + Vector2(-s * 0.5, 0).rotated(rot), c + Vector2(0, -s * 0.4).rotated(rot), c + Vector2(s * 0.5, 0).rotated(rot), c + Vector2(0, s * 0.35).rotated(rot)])
				ci.draw_colored_polygon(q, col)
				q.append(q[0])
				ci.draw_polyline(q, ec, 1.0)
			4:
				var lf := PackedVector2Array([c + Vector2(-s * 0.55, 0).rotated(rot), c + Vector2(0, -s * 0.3).rotated(rot), c + Vector2(s * 0.55, 0).rotated(rot), c + Vector2(0, s * 0.3).rotated(rot)])
				ci.draw_colored_polygon(lf, col)
				ci.draw_line(c + Vector2(-s * 0.5, 0).rotated(rot), c + Vector2(s * 0.5, 0).rotated(rot), ec, 1.0)
			5:
				ci.draw_circle(c, s * 0.9, col)
