extends SceneTree
## 騎兵打轉偵測（第二輪方案 §1.4）：訓練池 120 場，40 tick 內走了 >3 格但淨位移 <0.8 格就算一次。
## 分類：A＝繞翼途經點進行中；B＝追擊移動中的目標；C＝其他（推擠、纏鬥）。在上下 1 格內另標「邊緣」。
## 門檻：A 必須 0、B ≤ 8（修正前基準）、C（同一目標、離目標遠、原地繞）≤ 2；否則 exit 1。N＝正常纏鬥、T＝視窗內換目標，不算錯。用法：godot --headless --path game --script res://tools/orbit_detect.gd
const Sim = preload("res://scripts/core/battle_sim.gd")
const F = preload("res://scripts/core/formations.gd")
const D = preload("res://scripts/core/unit_defs.gd")
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
		var hist := {}
		var flagged := {}
		var thist := {}
		var has_cav := false
		while not s.finished:
			s.step()
			for u in s.units:
				if u.type != D.CAVALRY or not u.alive:
					continue
				has_cav = true
				var h: Array = hist.get(u.id, [])
				h.append(Vector2(u.x, u.y))
				var th: Array = thist.get(u.id, [])
				th.append(u.target)
				if th.size() > 40:
					th.pop_front()
				thist[u.id] = th
				if h.size() > 40:
					h.pop_front()
				hist[u.id] = h
				if h.size() == 40 and not flagged.has(u.id):
					var path := 0.0
					for k in range(1, 40):
						path += h[k].distance_to(h[k - 1])
					if path > 3000 and h[39].distance_to(h[0]) < 800:
						flagged[u.id] = true
						found += 1
						var k2 := "C"
						if u.nav == 1:
							k2 = "A"
						elif u.target >= 0 and (s.units[u.target].mx != 0 or s.units[u.target].my != 0):
							k2 = "B"
						var th2: Array = thist[u.id]
						if k2 == "C" and th2.min() != th2.max():
							k2 = "T"   # 視窗內換過目標（集火目標死亡後轉向），不是導航問題
						if k2 == "C" and u.target >= 0:
							var tg = s.units[u.target]
							var near: bool = Vector2(u.x, u.y).distance_to(Vector2(tg.x, tg.y)) <= u.reach + 600
							k2 = "C" if not near else "N"
						kinds[k2] = kinds.get(k2, 0) + 1
						if k2 == "C" and samples.size() < 5:
							var tg2 = s.units[u.target] if u.target >= 0 else null
							samples.append([i, s.tick, u.x, u.y, tg2.type if tg2 else -1, tg2.x if tg2 else 0, tg2.y if tg2 else 0, u.nav, u.stun, u.slow, u.chasing])
						if u.y <= 1000 or u.y >= Sim.H - 1000:
							edge += 1
		if has_cav:
			cav_battles += 1
	print("ORBIT cav_battles=%d total=%d A=%d B=%d C(遠離目標)=%d N(正常纏鬥)=%d T(換目標)=%d edge=%d" % [cav_battles, found, kinds["A"], kinds["B"], kinds["C"], kinds["N"], kinds["T"], edge])
	for x in samples:
		print("  C 例：場%d tick%d 騎兵(%d,%d) 目標兵種%d(%d,%d) nav=%d stun=%d slow=%d chasing=%s" % x)
	quit(0 if kinds["A"] == 0 and kinds["B"] <= 8 and kinds["C"] <= 2 else 1)
