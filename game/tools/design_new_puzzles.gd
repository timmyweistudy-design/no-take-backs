extends SceneTree
## 新兵試玩殘局的設計輔助（第四輪 §4.8）。每關：
##   ① 隨機抽樣（和 validate_puzzles 相同的抽法）量勝率與兵種組合數
##   ② 爬山搜尋「最好的擺法」兩次：允許全部兵種、拿掉新兵。新兵要真的是解題關鍵（有新兵的最佳解明顯比較好）
##   ③ 找兩組含新兵、組合不同的標準解
## 用法：godot --headless --path game --script res://tools/design_new_puzzles.gd [-- --id=n1 --samples=400 --iters=300]
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

## 分數：輸＝剩餘戰力差（負）；贏＝1000＋剩餘%。
func score(pz: Dictionary, extra: Array) -> Array:
	var s := run(pz, extra)
	var tot: int = s.budget * 1000
	if s.winner == 0:
		return [1000 + s.power(0) * 100 / tot, s.power(0) * 100 / tot]
	return [(s.power(0) - s.power(1)) * 100 / tot, -1]

func legal(pz: Dictionary, extra: Array) -> bool:
	var a0: Army = P.player_army(pz)
	for e in extra:
		if a0.check_place(int(e[0]), int(e[1]), int(e[2])) != "":
			return false
		a0.place(int(e[0]), int(e[1]), int(e[2]))
	return true

func random_extra(pz: Dictionary, allowed: Array, rng: RandomNumberGenerator) -> Array:
	var left: int = pz["budget"]
	var extra: Array = []
	var fixed := {}
	for f in pz["fixed"]:
		fixed[Vector2i(f[1], f[2])] = true
	for k in 8:
		var t: int = allowed[rng.randi_range(0, allowed.size() - 1)]
		if D.cost(t) > left:
			continue
		for tries in 20:
			var c := Vector2i(rng.randi_range(0, 5), rng.randi_range(0, 8))
			if not fixed.has(c) and extra.filter(func(e): return e[1] == c.x and e[2] == c.y).is_empty():
				extra.append([t, c.x, c.y])
				left -= D.cost(t)
				break
	return extra

func mutate(pz: Dictionary, extra: Array, allowed: Array, rng: RandomNumberGenerator) -> Array:
	var e2: Array = extra.duplicate(true)
	var op := rng.randi_range(0, 3)
	if e2.is_empty():
		op = 3
	match op:
		0:
			var i := rng.randi_range(0, e2.size() - 1)
			e2[i][1] = clampi(int(e2[i][1]) + rng.randi_range(-1, 1), 0, 5)
			e2[i][2] = clampi(int(e2[i][2]) + rng.randi_range(-2, 2), 0, 8)
		1:
			var i2 := rng.randi_range(0, e2.size() - 1)
			e2[i2][0] = allowed[rng.randi_range(0, allowed.size() - 1)]
		2:
			e2.remove_at(rng.randi_range(0, e2.size() - 1))
		3:
			e2.append([allowed[rng.randi_range(0, allowed.size() - 1)], rng.randi_range(0, 5), rng.randi_range(0, 8)])
	return e2 if legal(pz, e2) else extra

func climb(pz: Dictionary, allowed: Array, iters: int, seed_: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var best: Array = []
	var bs := [-9999, -1]
	for restart in 4:
		var cur := random_extra(pz, allowed, rng)
		var cs := score(pz, cur)
		for it in iters / 4:
			var cand := mutate(pz, cur, allowed, rng)
			var sc := score(pz, cand)
			if sc[0] >= cs[0]:
				cur = cand
				cs = sc
		if cs[0] > bs[0]:
			bs = cs
			best = cur
	return {"score": bs[0], "rem": bs[1], "extra": best}

func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1]
	var samples := int(args.get("samples", "400"))
	var iters := int(args.get("iters", "300"))
	for pz in P.new_puzzles() + P.fantasy_puzzles():
		if args.has("id") and pz["id"] != args["id"]:
			continue
		var nu: int = int(pz["unit"])
		var allowed: Array = []
		for v in pz["allowed"]:
			allowed.append(int(v))
		var without: Array = allowed.filter(func(x): return x != nu)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(pz["id"])
		var wins := 0
		var classes := {}
		for i in samples:
			var ex := random_extra(pz, allowed, rng)
			if ex.is_empty():
				continue
			var s := run(pz, ex)
			if s.winner == 0:
				wins += 1
				var ks := {}
				for e in ex:
					ks[e[0]] = true
				var kk := ks.keys()
				kk.sort()
				classes[str(kk)] = true
		var b1 := climb(pz, allowed, iters, 11)
		var b2 := climb(pz, allowed, iters, 29)
		var b0 := climb(pz, without, iters, 11)
		print("P ", JSON.stringify({"id": pz["id"], "base_lose": run(pz, []).winner != 0, "rate": wins * 100 / samples, "classes": classes.keys(),
			"best_with": b1, "best_with2": b2, "best_without": b0}))
	quit()
