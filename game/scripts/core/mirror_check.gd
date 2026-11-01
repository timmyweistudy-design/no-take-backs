extends RefCounted
## 左右交換逐 tick 比對（優化方案 B1／L1）：原本 (隊,列,欄) ↔ 鏡像 (1-隊,列,15-欄)，每 tick 比位置、血、面向、存活。
## 回傳 ""＝完全鏡像一致；否則是第一個分歧的描述。

const Sim = preload("res://scripts/core/battle_sim.gd")

static func check(a0, a1) -> String:
	var s1 = Sim.new(a0.copy(), a1.copy())
	var s2 = Sim.new(a1.mirrored(), a0.mirrored())
	var map := {}
	for u in s1.units:
		var row: int = (u.id % 1000) / 16
		var col: int = (u.id % 1000) % 16
		map[u.id] = (1 - u.team) * 1000 + row * 16 + (15 - col)
	var byid := {}
	for v in s2.units:
		byid[v.id] = v
	while not s1.finished or not s2.finished:
		s1.step()
		s2.step()
		for u in s1.units:
			var v = byid[map[u.id]]
			if Sim.W - u.x != v.x or u.y != v.y or u.hp != v.hp or u.alive != v.alive or -u.fx != v.fx or u.fy != v.fy or u.stealth != v.stealth or u.charge != v.charge:
				return "tick %d 單位 %d（兵種 %d）：%s vs %s" % [s1.tick, u.id, u.type, [u.x, u.y, u.hp, u.fx, u.fy], [Sim.W - v.x, v.y, v.hp, -v.fx, v.fy]]
		if s1.finished != s2.finished:
			return "結束 tick 不同：%d vs %d" % [s1.tick, s2.tick]
	var expect: int = s1.winner if s1.winner == -1 else 1 - s1.winner
	if s2.winner != expect:
		return "勝方沒對調：%d vs %d" % [s1.winner, s2.winner]
	return ""
