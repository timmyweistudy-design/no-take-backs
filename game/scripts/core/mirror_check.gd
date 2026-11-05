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

## 第六輪（方案 §6.1，Codex 第一輪）：獨立建立左右對應的鏡像檢查——不從 id 反推格子，
## 而是用 tick 0 的起始座標配對（鏡像後 (W−x, y)），比對索引、slot、事件來源／目標與完整狀態（含 tick 0）。
## 格子與自由陣型都適用；rules 兩場共用（兩邊對稱的規則）。
static func check_free(a0, a1, rules = null, cmd_auto := false) -> String:
	var s1 = Sim.new(a0.copy(), a1.copy(), rules)
	var s2 = Sim.new(a1.mirrored(), a0.mirrored(), rules)
	if cmd_auto:      # 第十二輪：雙方 AI 都放手動技能，也要左右對稱
		s1.cmd_auto = [true, true]
		s2.cmd_auto = [true, true]
	if s1.units.size() != s2.units.size():
		return "隻數不同"
	var by_pos := {}
	for k in s2.units.size():
		var v = s2.units[k]
		if v.dormant:
			continue
		by_pos[Vector3i(v.team, v.x, v.y)] = k
	var imap := {-1: -1}
	var idmap := {}
	for k in s1.units.size():
		var u = s1.units[k]
		if u.dormant:
			continue
		var key := Vector3i(1 - u.team, s1.fw - u.x, u.y)
		if not by_pos.has(key):
			return "tick 0 找不到單位 %d 的鏡像" % u.id
		imap[k] = by_pos[key]
		idmap[u.id] = s2.units[by_pos[key]].id
		if s2.units[by_pos[key]].slot != u.slot:
			return "tick 0 單位 %d 的 slot 不對稱：%d vs %d" % [u.id, u.slot, s2.units[by_pos[key]].slot]
	# 第八輪：預留的生兵用「母體＋子序號」配對（座標還沒定，不能用位置）
	for k in s1.units.size():
		var u = s1.units[k]
		if not u.dormant:
			continue
		var want: int = imap[u.parent]
		for m in s2.units.size():
			if s2.units[m].dormant and s2.units[m].parent == want and s2.units[m].sub == u.sub:
				imap[k] = m
				idmap[u.id] = s2.units[m].id
				break
		if not imap.has(k):
			return "生兵 %d 找不到鏡像" % u.id
	var first := true
	while first or not s1.finished or not s2.finished:
		if not first:
			s1.step()
			s2.step()
		first = false
		for k in s1.units.size():
			var u = s1.units[k]
			var v = s2.units[imap[k]]
			# 第七輪 S2：完整狀態投影（原本只比 14 欄）；新增欄位要加進來。不影響出貨指紋。
			var a := [s1.fw - u.x, u.y, u.hp, -u.fx, u.fy, imap[u.target], imap[u.face_lock], u.cd, u.stun, u.slow,
				u.stealth, u.charge, -u.cdx, u.cdy, -u.mx, u.my, (s1.fw - u.wp_x) if u.wp_x >= 0 else -1, u.wp_y, u.alive,
				u.dmg_dealt, u.dmg_taken, idmap.get(u.wp_for, -1), u.nav, u.chasing, u.kills, u.hcd, u.aura, u.breach, u.bmode, u.heal_done, imap[u.follow], u.drum_cover, u.max_hp, u.atk, u.speed, u.reach, u.cd_base]
			var b := [v.x, v.y, v.hp, v.fx, v.fy, v.target, v.face_lock, v.cd, v.stun, v.slow,
				v.stealth, v.charge, v.cdx, v.cdy, v.mx, v.my, v.wp_x, v.wp_y, v.alive,
				v.dmg_dealt, v.dmg_taken, v.wp_for, v.nav, v.chasing, v.kills, v.hcd, v.aura, v.breach, v.bmode, v.heal_done, v.follow, v.drum_cover, v.max_hp, v.atk, v.speed, v.reach, v.cd_base]
			if s1.v8:
				a.append_array([1 if u.dormant else 0, 1 if u.raised else 0, 1 if u.hidden else 0, 1 if u.bite else 0, 1 if u.exploded else 0, imap[u.link], u.link_wait, u.skill_cd, u.windup, 1 if u.used else 0, u.guard, u.zone, -u.pull_x, u.pull_y, u.pull_t])
				b.append_array([1 if v.dormant else 0, 1 if v.raised else 0, 1 if v.hidden else 0, 1 if v.bite else 0, 1 if v.exploded else 0, v.link, v.link_wait, v.skill_cd, v.windup, 1 if v.used else 0, v.guard, v.zone, v.pull_x, v.pull_y, v.pull_t])
			if a != b:
				return "tick %d 單位 %d：%s vs %s" % [s1.tick, u.id, a, b]
		if s1.v8:
			var z1: Array = s1.zones.map(func(z): return [s1.fw - int(z[0]), z[1], z[2], 1 - int(z[3])])
			var z2: Array = s2.zones.duplicate()
			z1.sort()
			z2.sort()
			if str(z1) != str(z2):
				return "tick %d 碎石區不對稱：%s vs %s" % [s1.tick, z1, z2]
		# 事件內容（種類、來源、目標、傷害、數量、隊伍）全部比；只換算 id 與隊伍
		var e1: Array = []
		for e in s1.events:
			e1.append(_ev_sig(e, idmap, s1.fw))
		var e2: Array = []
		for e in s2.events:
			e2.append(_ev_sig(e, {}))
		e1.sort()
		e2.sort()
		if e1 != e2:
			return "tick %d 事件不對稱：%s vs %s" % [s1.tick, e1, e2]
		if s1.finished != s2.finished:
			return "結束 tick 不同：%d vs %d" % [s1.tick, s2.tick]
	var expect: int = s1.winner if s1.winner == -1 else 1 - s1.winner
	if s2.winner != expect:
		return "勝方沒對調：%d vs %d" % [s1.winner, s2.winner]
	return ""


## 事件轉成可比較的字串。map 非空＝把 id、隊伍換成鏡像那邊的。
static func _ev_sig(e: Dictionary, map: Dictionary, fw := 16000) -> String:
	var out := PackedStringArray()
	var keys := e.keys().map(func(k): return str(k))
	keys.sort()
	for k in keys:
		var v = e[k]
		if k in ["src", "tgt", "id", "by"] and not map.is_empty():
			v = map.get(v, -1)
		elif k == "team" and not map.is_empty():
			v = 1 - int(v)
		elif k == "x" and e.get("kind") == "cmd" and not map.is_empty():
			v = fw - int(v)     # 第十二輪：隕石落點是世界座標
		out.append("%s=%s" % [k, str(v)])
	return ";".join(out)
