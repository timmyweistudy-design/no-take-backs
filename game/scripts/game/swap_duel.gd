extends RefCounted
## 1.2.0 §11.5 換邊雙局（方案第 5 輪規則）：同一組規則打兩局，玩家 A 第一局藍、第二局紅（先手跟著換）。
## 每局每色的分數＝剩餘戰力百分比（puzzles.rem_pct：存活單位按兵價加權剩血，再按預算換成百分比）；分數跟著玩家走、不跟顏色。
## 總分＝兩局相加；平手比兩局合計倒下數少的；再平手＝和局。純函式。
const PZ = preload("res://scripts/game/puzzles.gd")
const Army = preload("res://scripts/core/army.gd")
const ROUNDS := 2

## 第 rn 局（1 起）color 色是哪位玩家（0＝A、1＝B）
static func owner(rn: int, color: int) -> int:
	return color if rn % 2 == 1 else 1 - color

## 一局打完：把兩色的分數與倒下數加到玩家身上。回傳新的 [pts, dead]（不改傳入的陣列）
static func settle(pts: Array, dead: Array, rn: int, sim) -> Array:
	var p := pts.duplicate()
	var d := dead.duplicate()
	for c in 2:
		var who := owner(rn, c)
		p[who] = int(p[who]) + PZ.rem_pct(sim.power(c), sim.budget_of(c))
		var n := 0
		for u in sim.units:
			if u.team == c and not u.alive and not u.summon:
				n += 1
		d[who] = int(d[who]) + n
	return [p, d]

## 0＝A 勝、1＝B 勝、-1＝和局
static func verdict(pts: Array, dead: Array) -> int:
	if int(pts[0]) != int(pts[1]):
		return 0 if int(pts[0]) > int(pts[1]) else 1
	if int(dead[0]) != int(dead[1]):
		return 0 if int(dead[0]) < int(dead[1]) else 1
	return -1


## ── 1.6.0 B18（P7.3；§3.1）對 AI 換邊雙局的會話：存檔 swap_ai_run ──
## {v, round（現在這一局 1／2）, pts, dead, settled（已記分到第幾局）, ai（這一局 AI 那一色的陣：[[兵種, 欄, 列]...]；還沒擺＝[]）}
## 承諾＝AI 擺好就寫檔（重啟不重抽）；結算＝記分、settled 前進（同一局不重記）；整組結束＝刪掉。
const RUN_V := 1

static func _iv(x, lo: float, hi: float) -> bool:
	return (x is int or (x is float and float(x) == floorf(float(x)))) and float(x) >= lo and float(x) <= hi

## 讀回驗型；壞了回 null（＝沒有進行中的一組）
static func sanitize_run(v):
	if not v is Dictionary or not _iv(v.get("v"), 1, RUN_V) or not _iv(v.get("round"), 1, ROUNDS) or not _iv(v.get("settled"), 0, ROUNDS):
		return null
	var out := {"v": RUN_V, "round": int(v["round"]), "settled": int(v["settled"]), "pts": [], "dead": [], "ai": []}
	for k in ["pts", "dead"]:
		var a = v.get(k)
		if not a is Array or a.size() != 2 or not _iv(a[0], 0, 100000) or not _iv(a[1], 0, 100000):
			return null
		out[k] = [int(a[0]), int(a[1])]
	var ai = v.get("ai")
	if not ai is Array or ai.size() > 64:
		return null
	var cells := {}
	for u in ai:
		if not u is Array or u.size() != 3 or not _iv(u[0], 0, 31) or not _iv(u[1], 0, Army.COLS - 1) or not _iv(u[2], 0, Army.ROWS - 1):
			return null   # 兵種、欄、列都要在範圍內
		var key := Vector2i(int(u[1]), int(u[2]))
		if cells.has(key):
			return null   # 同一格兩隻
		cells[key] = true
		out["ai"].append([int(u[0]), int(u[1]), int(u[2])])
	if out["settled"] > out["round"] or out["settled"] < out["round"] - 1:
		return null   # 狀態一致：這一局要嘛還沒記分（settled＝round−1）、要嘛剛記完（settled＝round）
	return out

static func units_of(army) -> Array:
	var out: Array = []
	for u in army.units:
		out.append([int(u["type"]), int(u["col"]), int(u["row"])])
	return out
