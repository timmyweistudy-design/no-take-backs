extends SceneTree
## 騎兵打轉偵測（第二輪方案 §1.4）：訓練池 120 場，40 tick 內走了 >3 格但淨位移 <0.8 格就算一次。
## 同一隻騎兵觸發後隔 40 tick 重新武裝、繼續追蹤（不是第一次就永久放過；Codex R1 審查 #1）。
## 分類看整個視窗，不只最後一刻：
##   T＝視窗內換過目標（第四輪起優先判定）；
##   A＝沒換目標、視窗內任何時刻在繞翼途經點上（nav＝1）；
##   N＝正常纏鬥：離目標在攻擊距離＋0.6 格內，而且視窗內真的出手過；
##   B＝追擊移動中的目標（目標在視窗內淨移動 >0.8 格），且視窗內沒出手；
##   C＝其他（沒換目標、沒出手、目標也沒怎麼動卻在原地繞）。
## 上下 1 格內另標「邊緣」。門檻：A＝0、B≤8、C≤2；否則 exit 1。
## 用法：godot --headless --path game --script res://tools/orbit_detect.gd
const Sim = preload("res://scripts/core/battle_sim.gd")
const F = preload("res://scripts/core/formations.gd")
const D = preload("res://scripts/core/unit_defs.gd")
const WIN := 40
func _init() -> void:
	var pool := F.training_pool(0)
	var found := 0
	var cav_battles := 0
	var kinds := {"A": 0, "B": 0, "C": 0, "N": 0, "T": 0}
	var edge := 0
	var samples: Array = []
	for i in 120:
		var s := Sim.new(pool[i].copy(), pool[(i * 37 + 11) % pool.size()].mirrored())
		s.fast = true
		var hist := {}      # id → 最近 WIN tick 的 [x, y, target, nav, 出手數, 目標 x, 目標 y]
		var armed_at := {}  # id → 下一次可以再判定的 tick
		var has_cav := false
		while not s.finished:
			s.step()
			var hits := {}
			for e in s.events:
				if e.has("dmg"):
					hits[e["src"]] = hits.get(e["src"], 0) + 1
			for u in s.units:
				if u.type != D.CAVALRY or not u.alive:
					continue
				has_cav = true
				var tg = s.units[u.target] if u.target >= 0 else null
				var h: Array = hist.get(u.id, [])
				h.append([u.x, u.y, u.target, u.nav, hits.get(u.id, 0), tg.x if tg else u.x, tg.y if tg else u.y])
				if h.size() > WIN:
					h.pop_front()
				hist[u.id] = h
				if h.size() < WIN or s.tick < armed_at.get(u.id, 0):
					continue
				var path := 0.0
				for k in range(1, WIN):
					path += Vector2(h[k][0], h[k][1]).distance_to(Vector2(h[k - 1][0], h[k - 1][1]))
				if path <= 3000 or Vector2(h[WIN - 1][0], h[WIN - 1][1]).distance_to(Vector2(h[0][0], h[0][1])) >= 800:
					continue
				armed_at[u.id] = s.tick + WIN
				found += 1
				var any_nav := false
				var swapped := false
				var shots := 0
				for r in h:
					any_nav = any_nav or r[3] == 1
					swapped = swapped or r[2] != h[0][2]
					shots += r[4]
				var tgt_moved: float = Vector2(h[WIN - 1][5], h[WIN - 1][6]).distance_to(Vector2(h[0][5], h[0][6]))
				var near: bool = tg != null and Vector2(u.x, u.y).distance_to(Vector2(tg.x, tg.y)) <= u.reach + 600
				var k2 := "C"
				# 第四輪：先看換目標。新兵（投彈兵、醫者站後排）讓騎兵常在視窗內被嘲諷拉走或改追後排，
				# 換目標後走繞翼路線是正常的繞路，不是途經點壞掉（場17、場62 兩例逐 tick 看過）。A 只算「沒換目標還在繞翼途經點上打轉」。
				if swapped:
					k2 = "T"
				elif any_nav:
					k2 = "A"
				elif near and shots > 0:
					k2 = "N"
				elif tgt_moved > 800 and shots == 0:
					k2 = "B"
				kinds[k2] += 1
				if (k2 == "C" or k2 == "A") and samples.size() < 5:
					samples.append([i, s.tick, u.x, u.y, tg.type if tg else -1, tg.x if tg else 0, tg.y if tg else 0, u.nav, shots, u.stun, u.slow, u.chasing])
				if u.y <= 1000 or u.y >= Sim.H - 1000:
					edge += 1
		if has_cav:
			cav_battles += 1
	print("ORBIT cav_battles=%d total=%d A=%d B=%d C(遠離目標)=%d N(正常纏鬥)=%d T(換目標)=%d edge=%d" % [cav_battles, found, kinds["A"], kinds["B"], kinds["C"], kinds["N"], kinds["T"], edge])
	for x in samples:
		print("  例：場%d tick%d 騎兵(%d,%d) 目標兵種%d(%d,%d) nav=%d 出手=%d stun=%d slow=%d chasing=%s" % x)
	quit(0 if kinds["A"] == 0 and kinds["B"] <= 8 and kinds["C"] <= 2 else 1)
