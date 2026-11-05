extends SceneTree
## 手動技能強度（第十二輪）：同一對陣型左右各打一次，只有一邊會放這招（AI 判斷時機），看勝率。
## 用法：godot --headless --path . --script res://tools/balance/cmd_eval.gd -- [--n=40]
const Sim = preload("res://scripts/core/battle_sim.gd")
const AI = preload("res://scripts/core/ai_army.gd")
const RS = preload("res://scripts/core/ruleset.gd")
const CMD = preload("res://scripts/core/cmd_defs.gd")

func _rules(mask0: int, mask1: int, power: int):
	var r = RS.standard()
	r.deploy = "free"
	r.spacing = 800
	r.depth = 6000
	r.ai_pool_same = false
	r.pool = [1023, 1023]
	r.cmd_mask = [mask0, mask1]
	r.cmd_uses = 1
	r.cmd_cd = 400
	r.cmd_power = power
	return r

func _init() -> void:
	var n := 40
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--n="):
			n = int(a.substr(4))
	for power in [100]:
		for s in CMD.COUNT:
			var wins := 0
			var games := 0
			var margin := 0
			for seed_i in n:
				var base = _rules(1 << s, 1 << s, power)
				var r0 := RandomNumberGenerator.new()
				r0.seed = 900 + seed_i * 2
				var a0 = AI.build(0, 100, r0, -1, 1023, base)["army"]
				var r1 := RandomNumberGenerator.new()
				r1.seed = 901 + seed_i * 2
				var a1 = AI.build(1, 100, r1, -1, 1023, base)["army"]
				for tm in 2:
					var r = _rules(1 << s, 1 << s, power)
					var sim = Sim.new(a0.copy(), a1.copy(), r)
					sim.fast = true
					sim.cmd_auto = [tm == 0, tm == 1]
					sim.run_to_end()
					games += 1
					if sim.winner == tm:
						wins += 1
					elif sim.winner < 0:
						wins += 0
			print("CMDEVAL power=%d skill=%d 勝率=%d%% (%d 場)" % [power, s, wins * 100 / maxi(1, games), games])
	quit()
