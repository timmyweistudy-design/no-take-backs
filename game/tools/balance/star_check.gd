extends SceneTree
## 每一關的三星到底拿不拿得到（第十二輪）：先看標準解，沒有就爬山搜尋。印出最好的解。
## godot --headless --path game --script res://tools/balance/star_check.gd -- [--id=p5] [--iters=600]
const D = preload("res://scripts/core/unit_defs.gd")
const Army = preload("res://scripts/core/army.gd")
const Sim = preload("res://scripts/core/battle_sim.gd")
const P = preload("res://scripts/game/puzzles.gd")
const LOW := -1000000000000

## 和遊戲同一套算法。回傳 [星數, 剩餘%, 花費]。
func judge(pz: Dictionary, ex: Array) -> Array:
	var a0: Army = P.player_army(pz)
	var fixed_budget: int = a0.budget - int(pz["budget"])
	for e in ex:
		a0.units.append({"type": int(e[0]), "col": int(e[1]), "row": int(e[2])})
	var extra: int = a0.spent() - fixed_budget
	var s := Sim.new(a0, P.enemy_army(pz))
	s.fast = true
	s.run_to_end()
	var rem: int = P.rem_pct(s.power(0), s.budget) if s.winner == 0 else 0
	return [P.stars(pz, s.winner == 0, rem, extra), rem, extra]

func legal(pz: Dictionary, ex: Array) -> bool:
	var a0: Army = P.player_army(pz)
	for e in ex:
		if a0.check_place(int(e[0]), int(e[1]), int(e[2])) != "":
			return false
		a0.place(int(e[0]), int(e[1]), int(e[2]))
	return true

## 分數：先看星數，再看離兩個條件多近。
func score(pz: Dictionary, ex: Array) -> int:
	var j: Array = judge(pz, ex)
	var v: int = int(j[0]) * 100000 + int(j[1]) * 10
	v -= maxi(0, int(j[2]) - int(pz["star3"])) * 200
	return v

func mutate(pz: Dictionary, ex: Array, allowed: Array, rng: RandomNumberGenerator) -> Array:
	var e2: Array = ex.duplicate(true)
	match rng.randi_range(0, 3):
		0:
			if not e2.is_empty():
				var i := rng.randi_range(0, e2.size() - 1)
				e2[i][1] = clampi(int(e2[i][1]) + rng.randi_range(-2, 2), 0, 5)
				e2[i][2] = clampi(int(e2[i][2]) + rng.randi_range(-2, 2), 0, 8)
		1:
			if not e2.is_empty():
				e2[rng.randi_range(0, e2.size() - 1)][0] = allowed[rng.randi_range(0, allowed.size() - 1)]
		2:
			if not e2.is_empty():
				e2.remove_at(rng.randi_range(0, e2.size() - 1))
		3:
			e2.append([allowed[rng.randi_range(0, allowed.size() - 1)], rng.randi_range(0, 5), rng.randi_range(0, 8)])
	return e2 if legal(pz, e2) else ex

func search(pz: Dictionary, iters: int) -> Array:
	var allowed: Array = pz["allowed"]
	var best: Array = []
	var bs: int = LOW
	for sol in pz.get("solutions", []):
		var sc: int = score(pz, sol)
		if sc > bs:
			bs = sc
			best = sol
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for restart in 6:
		var cur: Array = best.duplicate(true) if restart < 2 else []
		var cs: int = score(pz, cur) if not cur.is_empty() else LOW
		for it in iters / 6:
			var c2: Array = mutate(pz, cur, allowed, rng)
			var s2: int = score(pz, c2) if not c2.is_empty() else LOW
			if s2 >= cs:
				cur = c2
				cs = s2
			if cs >= 300000:
				break
		if cs > bs:
			bs = cs
			best = cur
		if bs >= 300000:
			break
	return best

func _init() -> void:
	var want := ""
	var iters := 600
	for x in OS.get_cmdline_user_args():
		if x.begins_with("--id="):
			want = x.substr(5)
		if x.begins_with("--iters="):
			iters = int(x.substr(8))
	for pz in P.puzzles() + P.new_puzzles() + P.fantasy_puzzles():
		if want != "" and pz["id"] != want:
			continue
		var sols: Array = []
		for sol in pz.get("solutions", []):
			sols.append(judge(pz, sol))
		var b: Array = search(pz, iters)
		var j: Array = judge(pz, b)
		print("STAR ", JSON.stringify({"id": pz["id"], "name": pz["zh"], "budget": pz["budget"], "star2": pz["star2"], "star3": pz["star3"], "sols": sols, "best": j, "ex": b}))
	quit()
