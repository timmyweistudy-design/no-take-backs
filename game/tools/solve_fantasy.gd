extends SceneTree
## 奇幻軍試玩關的標準解搜尋（第八輪）。每關爬山找含主角兵種的解，印成 JSON；python 把解、星級寫回 puzzles.json。
## godot --headless --path game --script res://tools/solve_fantasy.gd
const D = preload("res://scripts/core/unit_defs.gd")
const Army = preload("res://scripts/core/army.gd")
const Sim = preload("res://scripts/core/battle_sim.gd")
const P = preload("res://scripts/game/puzzles.gd")

func run(pz: Dictionary, extra: Array) -> Sim:
	var a0: Army = P.player_army(pz)
	for e in extra:
		a0.units.append({"type": e[0], "col": e[1], "row": e[2]})
	var s := Sim.new(a0, P.enemy_army(pz))
	s.fast = true
	s.run_to_end()
	return s

func legal(pz: Dictionary, ex: Array) -> bool:
	var a0: Army = P.player_army(pz)
	for e in ex:
		if a0.check_place(int(e[0]), int(e[1]), int(e[2])) != "":
			return false
		a0.place(int(e[0]), int(e[1]), int(e[2]))
	return true

func score(pz: Dictionary, ex: Array) -> Array:
	var s := run(pz, ex)
	var tot: int = s.budget * 1000
	if s.winner == 0:
		return [1000 + s.power(0) * 100 / tot, s.power(0) * 100 / tot]
	return [(s.power(0) - s.power(1)) * 100 / tot, -1]

func rand_ex(pz: Dictionary, allowed: Array, unit: int, rng: RandomNumberGenerator) -> Array:
	var ex: Array = []
	var left: int = pz["budget"]
	var cand: Array = [unit] + allowed
	for k in 8:
		var t: int = cand[0] if k == 0 else allowed[rng.randi_range(0, allowed.size() - 1)]
		if D.cost(t) > left:
			continue
		var e := [t, rng.randi_range(0, 5), rng.randi_range(0, 8)]
		if legal(pz, ex + [e]):
			ex.append(e)
			left -= D.cost(t)
	return ex

func mutate(pz: Dictionary, ex: Array, allowed: Array, unit: int, rng: RandomNumberGenerator) -> Array:
	var e2: Array = ex.duplicate(true)
	match rng.randi_range(0, 3):
		0:
			if not e2.is_empty():
				var i := rng.randi_range(0, e2.size() - 1)
				e2[i][1] = clampi(int(e2[i][1]) + rng.randi_range(-1, 1), 0, 5)
				e2[i][2] = clampi(int(e2[i][2]) + rng.randi_range(-2, 2), 0, 8)
		1:
			if not e2.is_empty():
				e2[rng.randi_range(0, e2.size() - 1)][0] = allowed[rng.randi_range(0, allowed.size() - 1)]
		2:
			if not e2.is_empty():
				e2.remove_at(rng.randi_range(0, e2.size() - 1))
		3:
			e2.append([allowed[rng.randi_range(0, allowed.size() - 1)], rng.randi_range(0, 5), rng.randi_range(0, 8)])
	if e2.filter(func(x): return int(x[0]) == unit).is_empty():
		return ex
	return e2 if legal(pz, e2) else ex

func climb(pz: Dictionary, allowed: Array, unit: int, seed_: int, iters := 240) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var best: Array = []
	var bs := [-9999, -1]
	for restart in 3:
		var cur := rand_ex(pz, allowed, unit, rng)
		var cs := score(pz, cur)
		for it in iters / 3:
			var c2 := mutate(pz, cur, allowed, unit, rng)
			var s2 := score(pz, c2)
			if s2[0] >= cs[0]:
				cur = c2
				cs = s2
		if cs[0] > bs[0]:
			bs = cs
			best = cur
	return {"s": bs[0], "rem": bs[1], "ex": best}

func _init() -> void:
	var want := ""
	for x in OS.get_cmdline_user_args():
		if x.begins_with("--id="):
			want = x.substr(5)
	for pz in P.fantasy_puzzles():
		if want != "" and pz["id"] != want:
			continue
		var allowed: Array = []
		for v in pz["allowed"]:
			allowed.append(int(v))
		var unit := int(pz["unit"])
		var a := climb(pz, allowed, unit, 11)
		var b := climb(pz, allowed, unit, 29)
		var without := climb(pz, allowed.filter(func(x): return x != unit), allowed[1] if allowed.size() > 1 else unit, 5, 120) if allowed.size() > 1 else {"s": -1}
		print("S ", JSON.stringify({"id": pz["id"], "base_lose": run(pz, []).winner != 0, "a": a, "b": b, "no_unit_best": without.get("s")}))
	quit()
