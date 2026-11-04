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
const RSET = preload("res://scripts/core/ruleset.gd")

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

static func bench(n: int, types: Array, reps: int, rules = null) -> Dictionary:
	var tot := 0
	var worst := 0
	var ticks := 0
	for k in reps:
		var rng := RandomNumberGenerator.new()
		rng.seed = 777 + k * 31 + n
		var s = Sim.new(fill(0, n, rng, types), fill(1, n, rng, types), rules)
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
	if "--fantasy" in OS.get_cmdline_user_args():
		# 第八輪：一局每邊最多 10 種；最壞是大量生兵與大招
		var fant: Array = []
		for t8 in range(D.COUNT, D.total()):
			fant.append(t8)
		out["fantasy_24"] = bench(24, fant, 6)
		out["fantasy_40"] = bench(40, fant, 6)
		out["fantasy_summon_40"] = bench(40, [13, 13, 17, 13, 17, D.SWORD], 6)
		out["fantasy_spore_40"] = bench(40, [10, 10, D.SWORD, D.ARCHER], 6)
		out["fantasy_cat_40"] = bench(40, [18, 18, 19, 16, D.SWORD], 6)
		out["old_support_40"] = bench(40, [D.SWORD, D.SHIELD, 7, 8, 7, 8], 6)
		print("PERF ", JSON.stringify(out))
		quit()
		return
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
	# 第五輪（Codex 實作第 1 輪）：最大規則情境——40＋40、150 秒、支援兵密集；困難 AI 在最大規則下組陣；重播跳轉到最後
	var big = RSET.standard()
	big.budget = [200, 200]
	big.unit_cap = 40
	big.ticks = 3000
	out["max_rules_40_150s"] = bench(40, all, 4, big)
	out["max_rules_support_40_150s"] = bench(40, [D.SWORD, D.SHIELD, 7, 8, 7, 8], 4, big)
	# 合法的最大陣（Codex 實作第 2 輪：上面兩項是繞過預算直接塞兵的壓力測試）：200 金、40 隻上限、照規則擺
	var legal_t := 0
	var legal_worst := 0
	for k in 4:
		var lr := RandomNumberGenerator.new()
		lr.seed = 300 + k
		var la = AI.build(0, 200, lr, -1, -1, big)["army"]
		var lb = AI.build(1, 200, lr, -1, -1, big)["army"]
		var ls = Sim.new(la, lb, big)
		ls.fast = true
		var t3 := Time.get_ticks_usec()
		ls.run_to_end()
		var us3 := Time.get_ticks_usec() - t3
		legal_t += us3
		legal_worst = maxi(legal_worst, us3)
	out["legal_max_ai_armies"] = {"avg_ms": legal_t / 4 / 1000, "worst_ms": legal_worst / 1000}
	# 合法的支援兵密集：10 劍士＋醫者／鼓手交替擺到買不起（200 金、40 隻）
	var mk := func(team: int) -> Army:
		var a := Army.new(team, 200)
		a.apply_rules(big, team)
		var cells: Array = []
		for c in Army.ZONE:
			for r in Army.ROWS:
				cells.append(Vector2i(c if team == 0 else Army.COLS - 1 - c, r))
		var i := 0
		for k in 10:
			a.place(D.SWORD, cells[i].x, cells[i].y)
			i += 1
		var t := 7
		while a.can_afford_any() and i < cells.size():
			a.place(t, cells[i].x, cells[i].y)
			t = 15 - t
			i += 1
		return a
	var sup0: Army = mk.call(0)
	var sup1: Army = mk.call(1)
	var ss = Sim.new(sup0, sup1, big)
	ss.fast = true
	var t4 := Time.get_ticks_usec()
	ss.run_to_end()
	out["legal_support_dense"] = {"units": sup0.count(), "ms": (Time.get_ticks_usec() - t4) / 1000, "ticks": ss.tick}
	var known2: Array = AI.build(0, 200, rng, -1, -1, big)["army"].units
	var t1 := Time.get_ticks_usec()
	for k in 3:
		HardAI.build(known2, [], rng, -1, big)
	out["hard_ai_build_max_rules_ms"] = (Time.get_ticks_usec() - t1) / 3 / 1000
	# 重播跳轉：從頭快轉到最後一 tick（畫面的 _seek 也是這樣做）
	rng.seed = 4242
	var sa := fill(0, 40, rng, [D.SWORD, D.SHIELD, 7, 8, 7, 8])
	var sb := fill(1, 40, rng, [D.SWORD, D.SHIELD, 7, 8, 7, 8])
	var t2 := Time.get_ticks_usec()
	var sk = Sim.new(sa, sb, big)
	while not sk.finished:
		sk.step()
	out["seek_to_end_max_ms"] = (Time.get_ticks_usec() - t2) / 1000
	print("PERF ", JSON.stringify(out))
	quit()
