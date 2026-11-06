extends SceneTree
## 第十三輪：主題試煉第 11～30 關量產。依規格（tools/gen/trial_specs.py）：
##   ① 用規則變形＋敵方卡池、固定種子讓 AI 組敵陣，凍結成資料 ② 走遊戲同一條路開關（_start_trial、_build_ai）
##   ③ 多起點爬山收集過關解（技能關：敵方照遊戲一樣自動施放）④ 從前緣挑三星解，訂剩餘％與花費％門檻
## godot --headless --path game --script res://tools/balance/trial_forge.gd -- --in=<規格.json> [--id=10] [--iters=600]
const Sim = preload("res://scripts/core/battle_sim.gd")
const D = preload("res://scripts/core/unit_defs.gd")
const P = preload("res://scripts/game/puzzles.gd")
const AI = preload("res://scripts/core/ai_army.gd")
const RS = preload("res://scripts/core/ruleset.gd")
const GM = preload("res://scripts/ui/screens/game_modes.gd")
const FAKE = preload("res://tests/test_base.gd")

func judge(g, spec: Array, e) -> Dictionary:
	var a = g.armies[0].copy()
	a.units = []
	for u in spec:
		a.place_xy(int(u[0]), a.world_x(int(u[1])), int(u[2]))
	if a.units.is_empty() or not a.has_combat():
		return {"won": false, "rem": 0, "spent": 0, "pct": 0, "diff": -1000000}
	var s = Sim.new(a.copy(), e.copy(), g.rules)
	if s.cmd_on:
		s.cmd_auto = [false, true]   # 和遊戲一樣：對 AI 時紅方自動放，玩家不放也要拿得到星
	s.fast = true
	s.run_to_end()
	return {"won": s.winner == 0, "rem": P.rem_pct(s.power(0), s.budget_of(0)), "spent": a.spent(), "pct": a.spent() * 100 / a.budget,
		"diff": s.power(0) - s.power(1), "real": a.units.map(func(u): return [int(u["type"]), a.world_x(int(u["x"])), int(u["y"])])}

func boost_boss(ea, boss: int, need: int) -> void:
	for guard in 40:
		if ea.count_of(boss) >= need:
			return
		var cnt := {}
		for u in ea.units:
			if int(u["type"]) != boss:
				cnt[int(u["type"])] = int(cnt.get(int(u["type"]), 0)) + 1
		if cnt.is_empty():
			return
		var swapped := false
		var order: Array = cnt.keys()
		order.sort_custom(func(a, b): return cnt[a] > cnt[b])
		for t in order:
			for k in range(ea.units.size() - 1, -1, -1):
				var u: Dictionary = ea.units[k]
				if int(u["type"]) != t:
					continue
				ea.units.remove_at(k)
				if ea.place_xy(boss, int(u["x"]), int(u["y"])):
					swapped = true
					break
				ea.units.insert(k, u)
			if swapped:
				break
		if not swapped:
			return

func rand_spec(types: Array, g, r: RandomNumberGenerator) -> Array:
	var out: Array = []
	var a = g.armies[0]
	var left: int = a.budget
	for k in 30:
		var t: int = types[r.randi_range(0, types.size() - 1)]
		if D.cost(t) > left:
			continue
		out.append([t, 200 + r.randi_range(0, (a.depth - 400) / 50) * 50, 400 + r.randi_range(0, (a.fh - 800) / 50) * 50])
		left -= D.cost(t)
	return out

func mutate(sp: Array, types: Array, g, r: RandomNumberGenerator) -> Array:
	var s2: Array = sp.duplicate(true)
	var fh: int = g.armies[0].fh
	var dx: int = g.armies[0].depth - 200
	var op := r.randi_range(0, 3)
	if s2.is_empty():
		op = 3
	match op:
		0:
			var i := r.randi_range(0, s2.size() - 1)
			s2[i][1] = clampi(int(s2[i][1]) + r.randi_range(-20, 20) * 50, 200, dx)
			s2[i][2] = clampi(int(s2[i][2]) + r.randi_range(-20, 20) * 50, 300, fh - 300)
		1:
			s2[r.randi_range(0, s2.size() - 1)][0] = types[r.randi_range(0, types.size() - 1)]
		2:
			s2.remove_at(r.randi_range(0, s2.size() - 1))
		3:
			s2.append([types[r.randi_range(0, types.size() - 1)], 200 + r.randi_range(0, (dx - 200) / 50) * 50, 400 + r.randi_range(0, (fh - 800) / 50) * 50])
	return s2

func score(j: Dictionary, w: int) -> int:
	if not bool(j["won"]):
		return -10000000 + int(j["diff"]) / 10
	return 10000000 + int(j["rem"]) * (10 - w) * 10 - int(j["pct"]) * w * 10

func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1]
	var specs: Array = JSON.parse_string(FileAccess.get_file_as_string(str(args.get("in", ""))))
	var want := int(args.get("id", "-1"))
	var iters := int(args.get("iters", "600"))
	var g = load("res://scripts/ui/game_screens.gd").new()
	g.sfx = FAKE.FakeSfx.new()
	g.time = 1.0
	load("res://scripts/game/save.gd").data_locked = true
	for sp in specs:
		var i: int = int(sp["i"])
		if want >= 0 and i != want:
			continue
		var x: Dictionary = sp.duplicate(true)
		# ① 敵陣：規則變形＋敵方卡池，固定種子
		var r = g._trial_rules(i, x)
		var ep := 0
		for t in x["enemy_pool"]:
			ep |= 1 << int(t)
		r.pool[1] = ep
		var rr := RandomNumberGenerator.new()
		rr.seed = 13000 + i
		var ea = AI.build(1, r.budget_of(1), rr, -1, ep, r)["army"]
		# 頭目主題：AI 組的頭目兵種太少時，把最多的非頭目兵就地換成頭目，每次換都要擺得合法（Antigravity v13-r3 #8）
		if x.has("boss"):
			boost_boss(ea, int(x["boss"]), int(x["boss_min"]))
		x["enemy"] = ea.units.map(func(u): return [int(u["type"]), int(u["x"]), int(u["y"])])
		x.erase("enemy_pool")
		x.erase("boss")
		x.erase("boss_min")
		GM.TD.cache[i] = x
		g._start_trial(i)
		g._build_ai()
		var e = g.armies[1].copy()
		var types: Array = RS.types_of(g.armies[0].pool)
		# ③ 爬山
		var found: Array = []
		var rng := RandomNumberGenerator.new()
		rng.seed = 880 + i
		for restart in 6:
			var w: int = [2, 5, 8, 0, 3, 6][restart]
			var cur: Array = rand_spec(types, g, rng)
			var cj := judge(g, cur, e)
			var cs := score(cj, w)
			for it in iters / 6:
				var c2: Array = mutate(cur, types, g, rng)
				var j2 := judge(g, c2, e)
				if bool(j2["won"]):
					found.append(j2)
				var s2 := score(j2, w)
				if s2 >= cs:
					cur = c2
					cj = j2
					cs = s2
		var out := {"i": i, "found": found.size(), "spec": x}
		if not found.is_empty():
			# ④ 前緣上挑「剩餘＋省下」最大的當三星解
			var pick: Dictionary = found[0]
			var bv := -99999
			for f in found:
				var v: int = int(f["rem"]) + (100 - int(f["pct"]))
				if v > bv:
					bv = v
					pick = f
			x["rem"] = int(pick["rem"]) / 5 * 5 if int(pick["rem"]) >= 5 else maxi(1, int(pick["rem"]))
			x["spend"] = clampi(ceili(int(pick["spent"]) * 100.0 / g.armies[0].budget), 40, 100)
			x["best"] = pick["real"]
			out["pick"] = {"rem": pick["rem"], "pct": pick["pct"], "spent": pick["spent"]}
			out["spec"] = x
		print("TFORGE ", JSON.stringify(out))
	g.free()
	quit()
