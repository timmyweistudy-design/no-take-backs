extends SceneTree
## 第五輪 P0：效能探測。人數上限、一局時間要依這裡的數字定，不憑感覺。
## 情境：標準 24＋24、大軍 32／40／48 隻、支援兵密集、困難 AI 候選模擬。
## 模擬直接塞兵（繞過 MAX_UNITS），只量模擬本身；畫面 fps 另用截圖模式量。
## 用法：godot --headless --path game --script res://tools/perf_probe.gd
const Sim = preload("res://scripts/core/battle_sim.gd")
const Army = preload("res://scripts/core/army.gd")
const D = preload("res://scripts/core/unit_defs.gd")
const AI = preload("res://scripts/core/ai_army.gd")
const HardAI = preload("res://scripts/core/hard_ai.gd")

static func fill(team: int, n: int, rng: RandomNumberGenerator, types: Array) -> Army:
	var a := Army.new(team, 1000)
	var cells: Array = []
	for c in Army.ZONE:
		for r in Army.ROWS:
			cells.append(Vector2i(c if team == 0 else Army.COLS - 1 - c, r))
	for i in range(cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = cells[i]; cells[i] = cells[j]; cells[j] = t
	for i in mini(n, cells.size()):
		a.units.append({"type": types[rng.randi_range(0, types.size() - 1)], "col": cells[i].x, "row": cells[i].y})
	return a

static func bench(n: int, types: Array, reps: int) -> Dictionary:
	var tot := 0
	var worst := 0
	var ticks := 0
	for k in reps:
		var rng := RandomNumberGenerator.new()
		rng.seed = 777 + k * 31 + n
		var s = Sim.new(fill(0, n, rng, types), fill(1, n, rng, types))
		s.fast = true
		var t0 := Time.get_ticks_usec()
		s.run_to_end()
		var us := Time.get_ticks_usec() - t0
		tot += us
		worst = maxi(worst, us)
		ticks += s.tick
	return {"n": n, "avg_ms": tot / reps / 1000, "worst_ms": worst / 1000, "avg_ticks": ticks / reps, "us_per_tick": tot / maxi(1, ticks)}

func _init() -> void:
	var all: Array = []
	for t in D.COUNT:
		all.append(t)
	var out := {}
	for n in [24, 32, 40, 48]:
		out["mixed_%d" % n] = bench(n, all, 6)
	out["support_40"] = bench(40, [D.SWORD, D.SHIELD, 7, 8, 7, 8], 6)   # 醫者 7、鼓手 8 密集
	out["archers_40"] = bench(40, [D.ARCHER, D.ARCHER, D.SHIELD], 6)
	# 困難 AI：候選陣型各和玩家上一局模擬一場（標準 24 隻）
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var known: Array = AI.build(0, 100, rng)["army"].units
	var t0 := Time.get_ticks_usec()
	for k in 5:
		HardAI.build(known, [], rng)
	out["hard_ai_build_ms"] = (Time.get_ticks_usec() - t0) / 5 / 1000
	print("PERF ", JSON.stringify(out))
	quit()
