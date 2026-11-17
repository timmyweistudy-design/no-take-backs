extends SceneTree
## 1.6.0 B18（P7.4）名局：固定種子掃 AI 對 AI 一般組陣，挑「險勝」（勝方剩 ≤15%、打超過 40 秒）的前 6 場，寫 data/famous_games.json。
## 只寫量得到的事實（勝方、剩餘戰力、秒數），不編故事。
func _init():
	var AI = load("res://scripts/core/ai_army.gd")
	var BC = load("res://scripts/game/battle_code.gd")
	var Sim = load("res://scripts/core/battle_sim.gd")
	var out: Array = []
	var seed := 160400
	while out.size() < 6 and seed < 161400:
		seed += 1
		var r := RandomNumberGenerator.new()
		r.seed = seed
		var a0 = AI.build(0, 100, r)["army"]
		var a1 = AI.build(1, 100, r)["army"]
		var s = Sim.new(a0.copy(), a1.copy())
		s.fast = true
		s.run_to_end()
		if s.winner < 0:
			continue
		var rem := roundi(s.power(s.winner) * 100.0 / (s.budget_of(s.winner) * 1000))
		if rem <= 15 and rem >= 1 and s.tick >= 800:
			out.append({"c": BC.encode(a0, a1), "w": s.winner, "rem": rem, "sec": s.tick / 20, "seed": seed})
	var f := FileAccess.open("res://data/famous_games.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "\t"))
	f.close()
	print("FAMOUS ", out.size())
	quit()
