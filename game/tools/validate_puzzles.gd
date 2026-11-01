extends SceneTree
## 殘局／教學驗證（優化方案 D、附錄 A）：每關隨機抽樣擺法，檢查
##  ① 什麼都不放（只有固定兵）會輸；② 至少兩類「兵種組合」能贏；③ 抽樣勝率 2%～70%（不太難也不太簡單；教學可到 95%）；
##  ④ ★★、★★★ 門檻至少各有一個解達成。
## 用法：godot --headless --path game --script res://tools/validate_puzzles.gd -- --id=p1 [--samples=300]
## 每關一行 "V {json}"。

const D = preload("res://scripts/core/unit_defs.gd")
const Army = preload("res://scripts/core/army.gd")
const Sim = preload("res://scripts/core/battle_sim.gd")
const P = preload("res://scripts/game/puzzles.gd")

func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1]
	var samples := int(args.get("samples", "300"))
	var ids: Array = [args["id"]] if args.has("id") else P.all_ids()
	var all_ok := true
	for id in ids:
		var r := validate(P.get_puzzle(id), samples)
		all_ok = all_ok and bool(r["ok"])
		print("V ", JSON.stringify(r))
	quit(0 if all_ok else 1)

func run(pz: Dictionary, extra: Array) -> Sim:
	var a0: Army = P.player_army(pz)
	for e in extra:
		a0.units.append({"type": e[0], "col": e[1], "row": e[2]})
	var s := Sim.new(a0, P.enemy_army(pz))
	s.fast = true
	s.run_to_end()
	return s

func validate(pz: Dictionary, samples: int) -> Dictionary:
	var base := run(pz, [])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(pz["id"])
	var wins := 0
	var classes := {}
	var best_rem := 0
	var min_spend := 999
	var three_star := false
	var examples := {}
	var allowed: Array = pz["allowed"]
	var fixed_cells := {}
	for f in pz["fixed"]:
		fixed_cells[Vector2i(f[1], f[2])] = true
	for i in samples:
		var left: int = pz["budget"]
		var extra: Array = []
		var used := {}
		var n := rng.randi_range(1, 6)
		for k in n:
			var t: int = allowed[rng.randi_range(0, allowed.size() - 1)]
			if D.cost(t) > left:
				continue
			for tries in 20:
				var c := Vector2i(rng.randi_range(0, 5), rng.randi_range(0, 8))
				if not fixed_cells.has(c) and not used.has(c):
					used[c] = true
					extra.append([t, c.x, c.y])
					left -= D.cost(t)
					break
		if extra.is_empty():
			continue
		var s := run(pz, extra)
		if s.winner == 0:
			wins += 1
			var types := {}
			var spend := 0
			for e in extra:
				types[e[0]] = true
				spend += D.cost(e[0])
			var key := types.keys()
			key.sort()
			classes[str(key)] = classes.get(str(key), 0) + 1
			var rem: int = s.power(0) * 100 / (s.budget * 1000)
			best_rem = maxi(best_rem, rem)
			min_spend = mini(min_spend, spend)
			if rem >= int(pz["star2"]) and spend <= int(pz["star3"]):
				three_star = true
			if not examples.has(str(key)) and examples.size() < 2:
				examples[str(key)] = extra
	var rate := wins * 100 / maxi(1, samples)
	var max_rate := 95 if pz.get("tutorial", false) else 70
	var need_classes := 1 if pz.get("tutorial", false) else 2
	var ok: bool = base.winner != 0 and classes.size() >= need_classes and rate >= 2 and rate <= max_rate \
		and three_star
	return {"id": pz["id"], "ok": ok, "base_winner": base.winner, "win_rate": rate, "classes": classes.size(),
		"class_list": classes, "best_rem": best_rem, "min_spend": min_spend, "three_star": three_star, "star2": pz["star2"], "star3": pz["star3"], "solutions": examples.values()}
