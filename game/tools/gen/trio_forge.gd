extends SceneTree
## V1.6 #17 一陣三考題組產生器：godot --headless --path game --script res://tools/gen/trio_forge.gd
## 做法：先用固定種子組一套「作者解」（格子陣，0～5 欄），再找三支 AI 敵陣（格子陣，10～15 欄）讓作者解都打得贏 → 保證有解。
## 三支敵陣的原型要不同（才是真的「通用解」題）。輸出 data/trio.json。
const D = preload("res://scripts/core/unit_defs.gd")
const Army = preload("res://scripts/core/army.gd")
const Sim = preload("res://scripts/core/battle_sim.gd")
const AI = preload("res://scripts/core/ai_army.gd")

const SETS := 10

func wins(a, e) -> bool:
	var s = Sim.new(a.copy(), e.copy())
	s.fast = true
	s.run_to_end()
	return s.winner == 0

func cells(a) -> Array:
	var out: Array = []
	for u in a.units:
		out.append([int(u["type"]), int(u["col"]), int(u["row"])])
	out.sort()
	return out

func _init() -> void:
	var out: Array = []
	var seed := 5100
	while out.size() < SETS and seed < 9000:
		seed += 1
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var budget := 60 + (out.size() % 5) * 10
		var sol = AI.build(0, budget, rng)["army"]
		var foes: Array = []
		var used := {}
		for k in 60:
			if foes.size() >= 3:
				break
			var tpl := rng.randi_range(0, AI.TEMPLATES.size() - 1)
			if used.has(tpl) or not AI.template_ok(tpl, (1 << 10) - 1):
				continue
			var e = AI.build(1, budget - 5, rng, tpl)["army"]
			if e.units.is_empty() or not wins(sol, e):
				continue
			used[tpl] = true
			foes.append(cells(e))
		if foes.size() < 3:
			continue
		var allowed := {}
		for u in sol.units:
			allowed[int(u["type"])] = true
		for t in [0, 1, 2, 3, 5]:
			if allowed.size() >= 6:
				break
			allowed[t] = true
		var al: Array = allowed.keys()
		al.sort()
		out.append({"id": "trio%d" % (out.size() + 1), "budget": sol.spent(), "allowed": al, "foes": foes, "sol": cells(sol)})
	var f := FileAccess.open("res://data/trio.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"_說明": "V1.6 #17 一陣三考（tools/gen/trio_forge.gd 產生；sol＝作者解，證明有解）", "sets": out}, "\t"))
	f.close()
	print("TRIO ", out.size())
	quit(0)
