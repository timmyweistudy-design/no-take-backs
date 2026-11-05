extends SceneTree
## 主題試煉 10 關的星數拿不拿得到（第十二輪）：走遊戲同一條路開關（同一支對手），爬山找陣型。
## godot --headless --path game --script res://tools/balance/trial_check.gd -- [--id=0] [--iters=240]
const Sim = preload("res://scripts/core/battle_sim.gd")
const D = preload("res://scripts/core/unit_defs.gd")
const LOW := -1000000000000
const P = preload("res://scripts/game/puzzles.gd")
const FAKE = preload("res://tests/test_base.gd")

func judge(g, spec: Array, e) -> Array:
	var a = g.armies[0].copy()
	a.units = []
	for u in spec:
		a.place_xy(int(u[0]), a.world_x(int(u[1])), int(u[2]))
	if a.units.is_empty() or not a.has_combat():
		return [0, 0, 0, a, -1000000]
	var s = Sim.new(a.copy(), e.copy(), g.rules)
	s.fast = true
	s.run_to_end()
	var st := 0
	var rem: int = P.rem_pct(s.power(0), s.budget_of(0))
	if s.winner == 0:
		st = g.trial_stars(int(g.TRIALS[g.trial_id][3]), rem, a.spent(), a.budget, g.trial_spend_pct(g.trial_id))
	return [st, rem, a.spent() * 100 / a.budget, a, s.power(0) - s.power(1)]

func score(j: Array) -> int:
	var over: int = maxi(0, int(j[2]) - 80)      # 第 8 關門檻 85% 不特別處理，搜尋只會更保守
	return int(j[0]) * 100000000 + int(j[4]) / 10 + int(j[1]) * 100 - over * 300

func rand_spec(types: Array, g, r: RandomNumberGenerator) -> Array:
	var out: Array = []
	var a = g.armies[0]
	var left: int = a.budget      # 先用滿預算找贏法，爬山再省錢
	for k in 30:
		var t: int = types[r.randi_range(0, types.size() - 1)]
		if D.cost(t) > left:
			continue
		out.append([t, 200 + r.randi_range(0, 110) * 50, 400 + r.randi_range(0, (a.fh - 800) / 50) * 50])
		left -= D.cost(t)
	return out

func mutate(sp: Array, types: Array, g, r: RandomNumberGenerator) -> Array:
	var s2: Array = sp.duplicate(true)
	var fh: int = g.armies[0].fh
	match r.randi_range(0, 3):
		0:
			if not s2.is_empty():
				var i := r.randi_range(0, s2.size() - 1)
				s2[i][1] = clampi(int(s2[i][1]) + r.randi_range(-20, 20) * 50, 200, 5800)
				s2[i][2] = clampi(int(s2[i][2]) + r.randi_range(-20, 20) * 50, 300, fh - 300)
		1:
			if not s2.is_empty():
				s2[r.randi_range(0, s2.size() - 1)][0] = types[r.randi_range(0, types.size() - 1)]
		2:
			if not s2.is_empty():
				s2.remove_at(r.randi_range(0, s2.size() - 1))
		3:
			s2.append([types[r.randi_range(0, types.size() - 1)], 200 + r.randi_range(0, 110) * 50, 400 + r.randi_range(0, (fh - 800) / 50) * 50])
	return s2

func _init() -> void:
	var want := -1
	var iters := 240
	var seed_off := 0
	for x in OS.get_cmdline_user_args():
		if x.begins_with("--id="):
			want = int(x.substr(5))
		if x.begins_with("--iters="):
			iters = int(x.substr(8))
		if x.begins_with("--seed="):
			seed_off = int(x.substr(7))
	var g = load("res://scripts/ui/game_screens.gd").new()
	g.sfx = FAKE.FakeSfx.new()
	g.time = 1.0
	load("res://scripts/game/save.gd").data_locked = true
	for i in g.TRIALS.size():
		if want >= 0 and i != want:
			continue
		g._start_trial(i)
		g._build_ai()
		var e = g.armies[1].copy()
		var types: Array = load("res://scripts/core/ruleset.gd").types_of(g.armies[0].pool)
		var rr := RandomNumberGenerator.new()
		rr.seed = 880 + i + seed_off
		var best: Array = []
		var bj: Array = [0, 0, 0, null, 0]
		var bs: int = LOW
		for restart in 6:
			var cur: Array = rand_spec(types, g, rr)
			var cj: Array = judge(g, cur, e)
			var cs: int = score(cj)
			for it in iters / 4:
				var c2: Array = mutate(cur, types, g, rr)
				var j2: Array = judge(g, c2, e)
				var s2: int = score(j2)
				if s2 >= cs:
					cur = c2
					cj = j2
					cs = s2
				if int(cj[0]) == 3:
					break
			if cs > bs:
				bs = cs
				best = cur
				bj = cj
			if int(bj[0]) == 3:
				break
		var names: Dictionary = {}
		for u in best:
			names[int(u[0])] = int(names.get(int(u[0]), 0)) + 1
		print("TRIAL ", JSON.stringify({"i": i + 1, "map": g.TRIALS[i][0], "size": g.TRIALS[i][1], "style": g.TRIALS[i][2], "level": g.TRIALS[i][3], "budget": g.armies[0].budget, "enemy_n": e.units.size(), "stars": bj[0], "rem": bj[1], "spent_pct": bj[2], "types": names, "spec": best}))
	g.free()
	quit()
