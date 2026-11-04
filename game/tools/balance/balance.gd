extends SceneTree
## 平衡報表（原型版）：godot --headless --path game --script res://tools/balance/balance.gd
## ①兵種對戰矩陣：各 60 金同種兵、整齊方陣，左右交換各打一次。
## ②AI 陣型聯賽：每套原型陣型 4 個隨機種子，兩兩對打（交換左右），看「激烈」指標。

const D = preload("res://scripts/core/unit_defs.gd")
const Army = preload("res://scripts/core/army.gd")
const Sim = preload("res://scripts/core/battle_sim.gd")
const AI = preload("res://scripts/core/ai_army.gd")

func _init() -> void:
	matrix()
	league()
	quit(0)

func block(team: int, t: int, gold: int):
	var a = Army.new(team, 100)
	var n := gold / D.cost(t)
	var cols := [5, 4, 3, 2, 1, 0] if t != D.ARCHER else [0, 1, 2, 3, 4, 5]
	var rows := [4, 3, 5, 2, 6, 1, 7, 0, 8]
	var k := 0
	for c in cols:
		for r in rows:
			if k < n:
				var col: int = c if team == 0 else Army.COLS - 1 - c
				a.units.append({"type": t, "col": col, "row": r})
				k += 1
	return a

func matrix() -> void:
	print("① 兵種對戰矩陣（各 60 金；格內＝列兵種的勝場/2，括號＝勝方剩餘戰力%）")
	var head := "        "
	for j in D.COUNT:
		head += "%-12s" % D.NAMES[j]
	print(head)
	for i in D.COUNT:
		var line := "%-6s" % D.NAMES[i]
		for j in D.COUNT:
			if i == j:
				line += "%-14s" % "—"
				continue
			var w := 0
			var rem: Array = []
			for side in 2:
				var s
				if side == 0:
					s = Sim.new(block(0, i, 60), block(1, j, 60))
				else:
					s = Sim.new(block(0, j, 60), block(1, i, 60))
				s.run_to_end()
				var my := 0 if side == 0 else 1
				if s.winner == my:
					w += 1
				if s.winner >= 0:
					rem.append(s.power(s.winner) * 100 / (60 * 1000))
			line += "%-14s" % ("%d/2 (%s)" % [w, ",".join(rem.map(func(x): return str(x)))])
		print(line)

func league() -> void:
	var rng := RandomNumberGenerator.new()
	var pool: Array = []
	for ti in AI.TEMPLATES.size():
		for sd in 4:
			rng.seed = ti * 101 + sd * 7 + 3
			pool.append({"t": ti, "a": AI.build(0, 100, rng, ti)["army"]})
	var wins := {}
	var games := {}
	var rems: Array = []
	var secs: Array = []
	var draws := 0
	var timeouts := 0
	var total := 0
	var t0 := Time.get_ticks_msec()
	for i in pool.size():
		for j in range(i + 1, pool.size()):
			for side in 2:
				var A = pool[i] if side == 0 else pool[j]
				var B = pool[j] if side == 0 else pool[i]
				var s = Sim.new(A["a"].copy(), _as_red(B["a"]))
				s.run_to_end()
				total += 1
				secs.append(s.tick / 20.0)
				games[A["t"]] = games.get(A["t"], 0) + 1
				games[B["t"]] = games.get(B["t"], 0) + 1
				if s.reason.begins_with("時間到"):
					timeouts += 1
				if s.winner == -1:
					draws += 1
				else:
					var wt: int = A["t"] if s.winner == 0 else B["t"]
					wins[wt] = wins.get(wt, 0) + 1
					rems.append(s.power(s.winner) * 100 / (100 * 1000))
	rems.sort()
	secs.sort()
	var close := 0
	var blow := 0
	for r in rems:
		if r <= 30:
			close += 1
		if r > 50:
			blow += 1
	print("")
	print("② AI 陣型聯賽：%d 場（%d 套陣型×4 種子，兩兩交換左右）耗時 %d 秒" % [total, AI.TEMPLATES.size(), (Time.get_ticks_msec() - t0) / 1000])
	print("   勝方剩餘戰力中位數 %d%%（目標 ≤30%%）；≤30%% 的接近局 %d%%；>50%% 的碾壓局 %d%%（目標 <20%%）" % [rems[rems.size() / 2], close * 100 / rems.size(), blow * 100 / rems.size()])
	print("   戰鬥秒數 中位數 %.1f、最短 %.1f、最長 %.1f（目標平均 35～75）；平手 %d、時間到 %d" % [secs[secs.size() / 2], secs[0], secs[-1], draws, timeouts])
	for ti in AI.TEMPLATES.size():
		print("   %-8s 勝率 %d%%" % [AI.TEMPLATES[ti]["name"], wins.get(ti, 0) * 100 / games.get(ti, 1)])

func _as_red(a):
	# 藍方陣型鏡像成紅方
	return a.mirrored()
