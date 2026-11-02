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
	var idx2 := {}   # s2 的 id → 索引
	for k in s2.units.size():
		byid[s2.units[k].id] = s2.units[k]
		idx2[s2.units[k].id] = k
	# s1 索引 → 對應到 s2 的索引（目標、面向鎖定是索引）
	var imap := {-1: -1}
	for k in s1.units.size():
		imap[k] = idx2[map[s1.units[k].id]]
	while not s1.finished or not s2.finished:
		s1.step()
		s2.step()
		if s1.rally[0] != s2.rally[1] or s1.rally[1] != s2.rally[0]:
			return "tick %d 背水狀態不對稱：%s vs %s" % [s1.tick, s1.rally, s2.rally]
		for u in s1.units:
			var v = byid[map[u.id]]
			var a := [Sim.W - u.x, u.y, u.hp, -u.fx, u.fy, imap[u.target], imap[u.face_lock], u.cd, u.stun, u.slow,
				u.stealth, u.charge, -u.cdx, u.cdy, -u.mx, u.my, (Sim.W - u.wp_x) if u.wp_x >= 0 else -1, u.wp_y, u.alive, u.dmg_dealt, u.dmg_taken, map.get(u.wp_for, -1), u.kills, u.nav, u.chasing,
				u.hcd, u.aura, u.breach, u.bmode, u.heal_done, imap[u.follow], u.drum_cover]
			var b := [v.x, v.y, v.hp, v.fx, v.fy, v.target, v.face_lock, v.cd, v.stun, v.slow,
				v.stealth, v.charge, v.cdx, v.cdy, v.mx, v.my, v.wp_x, v.wp_y, v.alive, v.dmg_dealt, v.dmg_taken, v.wp_for, v.kills, v.nav, v.chasing,
				v.hcd, v.aura, v.breach, v.bmode, v.heal_done, v.follow, v.drum_cover]
			if a != b:
				var names := ["x", "y", "hp", "fx", "fy", "target", "face_lock", "cd", "stun", "slow", "stealth", "charge", "cdx", "cdy", "mx", "my", "wp_x", "wp_y", "alive", "dealt", "taken", "wp_for", "kills", "nav", "chasing", "hcd", "aura", "breach", "bmode", "heal_done", "follow", "drum_cover"]
				var diff := []
				for k in a.size():
					if a[k] != b[k]:
						diff.append("%s %s≠%s" % [names[k], a[k], b[k]])
				return "tick %d 單位 %d（兵種 %d）：%s" % [s1.tick, u.id, u.type, ", ".join(diff)]
		if s1.finished != s2.finished:
			return "結束 tick 不同：%d vs %d" % [s1.tick, s2.tick]
	var expect: int = s1.winner if s1.winner == -1 else 1 - s1.winner
	if s2.winner != expect:
		return "勝方沒對調：%d vs %d" % [s1.winner, s2.winner]
	return ""
