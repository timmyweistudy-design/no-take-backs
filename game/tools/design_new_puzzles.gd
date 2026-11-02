extends SceneTree
## 新兵試玩殘局的設計輔助（第四輪 §4.8）：對每個候選關卡抽樣擺法，回報
##   ・全部允許兵種的勝率、拿掉新兵後的勝率（新兵要真的是解題關鍵）
##   ・贏法的兵種組合數、剩餘戰力分佈、最省花費
##   ・兩組標準解（優先：含新兵、組合不同、剩餘最高／花費最少）
## 用法：godot --headless --path game --script res://tools/design_new_puzzles.gd [-- --samples=600]
## 輸出每關一行 "P {json}"，人工挑門檻後寫進 data/puzzles.json 的 new_units。
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

func sample(pz: Dictionary, allowed: Array, samples: int, seed_: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var fixed_cells := {}
	for f in pz["fixed"]:
		fixed_cells[Vector2i(f[1], f[2])] = true
	var wins := 0
	var classes := {}
	var rems: Array = []
	var sols: Array = []
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
			classes[str(key)] = int(classes.get(str(key), 0)) + 1
			var rem: int = s.power(0) * 100 / (s.budget * 1000)
			rems.append(rem)
			sols.append({"extra": extra, "rem": rem, "spend": spend, "key": str(key)})
	rems.sort()
	return {"rate": wins * 100 / maxi(1, samples), "classes": classes, "rems": rems, "sols": sols}

func _init() -> void:
	var samples := 600
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--samples="):
			samples = int(a.substr(10))
	for pz in P.new_puzzles():
		var nu: int = int(pz["unit"])
		var allowed: Array = []
		for v in pz["allowed"]:
			allowed.append(int(v))
		var without: Array = allowed.filter(func(x): return x != nu)
		var base := run(pz, [])
		var r1 := sample(pz, allowed, samples, hash(pz["id"]))
		var r0 := sample(pz, without, samples, hash(pz["id"]) + 1)
		# 標準解：含新兵；一組剩餘最高、一組花費最少（組合不同優先）
		var with_new: Array = r1["sols"].filter(func(x): return str(nu) in x["key"])
		with_new.sort_custom(func(p, q): return p["rem"] > q["rem"])
		var best_rem = with_new[0] if not with_new.is_empty() else null
		var cheap: Array = with_new.duplicate()
		cheap.sort_custom(func(p, q): return p["spend"] < q["spend"] or (p["spend"] == q["spend"] and p["rem"] > q["rem"]))
		var alt = null
		for c in cheap:
			if best_rem != null and c["key"] != best_rem["key"]:
				alt = c
				break
		if alt == null and cheap.size() > 1:
			alt = cheap[0] if cheap[0] != best_rem else cheap[1]
		var rems: Array = r1["rems"]
		print("P ", JSON.stringify({"id": pz["id"], "base_lose": base.winner != 0, "rate": r1["rate"], "rate_without_new": r0["rate"],
			"classes": r1["classes"].size(), "rem_p50": rems[rems.size() / 2] if not rems.is_empty() else -1,
			"rem_p80": rems[rems.size() * 4 / 5] if not rems.is_empty() else -1,
			"best": best_rem, "alt": alt}))
	quit()
