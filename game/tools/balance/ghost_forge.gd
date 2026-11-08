extends SceneTree
## V1.4 #7：鍛造 30 個「名人幽靈陣」。每個 AI 模板 × 多個種子各組一支紅軍（100 金、標準規則），
## 對 40 支隨機藍軍各打一場算勝率，挑最強的 30 支（每個模板最多 2 支）。輸出一行一個 GHOST {...}。
## godot --headless --path game --script res://tools/balance/ghost_forge.gd

const AI = preload("res://scripts/core/ai_army.gd")
const Sim = preload("res://scripts/core/battle_sim.gd")
const RS = preload("res://scripts/core/ruleset.gd")

func _arg(k: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % k):
			return a.split("=")[1]
	return d

func _init() -> void:
	var foes: Array = []
	var fr := RandomNumberGenerator.new()
	fr.seed = 7001
	for i in int(_arg("foes", "40")):
		foes.append(AI.build(0, 100, fr)["army"])
	var cands: Array = []
	for ti in range(int(_arg("t0", "0")), mini(AI.TEMPLATES.size(), int(_arg("t1", "99")))):
		for s in int(_arg("seeds", "8")):
			var r := RandomNumberGenerator.new()
			r.seed = 9000 + ti * 101 + s * 7
			var b: Dictionary = AI.build(1, 100, r, ti, RS.full_pool() if "--full" in OS.get_cmdline_user_args() else -1)
			var a = b["army"]
			if a.units.is_empty():
				continue
			var wins := 0
			for f in foes:
				var sim = Sim.new(f.copy(), a.copy())
				sim.fast = true
				sim.run_to_end()
				if sim.winner == 1:
					wins += 1
			var cd := {"t": ti, "tpl": str(b["name"]), "units": a.units.duplicate(true), "wr": wins * 100 / foes.size(), "cost": a.spent()}
			cands.append(cd)
			print("CAND ", JSON.stringify(cd))   # 邊算邊印：中途被砍也留得下結果
	cands.sort_custom(func(x, y): return int(x["wr"]) > int(y["wr"]))
	var per := {}
	var out := 0
	for c in cands:
		if out >= 30:
			break
		if int(per.get(c["t"], 0)) >= 2:
			continue
		per[c["t"]] = int(per.get(c["t"], 0)) + 1
		print("GHOST ", JSON.stringify(c))
		out += 1
	quit()
