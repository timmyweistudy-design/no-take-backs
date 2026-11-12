extends RefCounted
## 1.2.0 §11.5 換邊雙局（方案第 5 輪規則）：同一組規則打兩局，玩家 A 第一局藍、第二局紅（先手跟著換）。
## 每局每色的分數＝剩餘戰力百分比（puzzles.rem_pct：存活單位按兵價加權剩血，再按預算換成百分比）；分數跟著玩家走、不跟顏色。
## 總分＝兩局相加；平手比兩局合計倒下數少的；再平手＝和局。純函式。
const PZ = preload("res://scripts/game/puzzles.gd")
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
