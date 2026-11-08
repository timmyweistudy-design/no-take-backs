extends SceneTree
## V1.4 審查（Codex v140-i5）：舊版本就有的幾種對局（自由排兵＋規則、地形圖、手動技能、奇幻軍）在新版指紋要一樣。
## 印出每一場的指紋；在舊 commit 與新 commit 各跑一次比對，結果寫進 tests/golden/v140_cases.json。
const Sim = preload("res://scripts/core/battle_sim.gd")
const AI = preload("res://scripts/core/ai_army.gd")
const RS = preload("res://scripts/core/ruleset.gd")

func _case(k: int):
	var r = RS.standard()
	match k % 4:
		0:
			r.deploy = "free"
		1:
			r.map_id = 1 + (k / 4) % 5
		2:
			r.cmd_mask = [15, 15]
		3:
			r.pool = [RS.full_pool(), RS.full_pool()]
	return r

func _init() -> void:
	var out: Array = []
	for k in 16:
		var r = _case(k)
		var rng := RandomNumberGenerator.new()
		rng.seed = 31000 + k
		var p0 := RS.full_pool() if k % 4 == 3 else -1
		var a0 = AI.build(0, 100, rng, -1, p0, r)["army"]
		var a1 = AI.build(1, 100, rng, -1, p0, r)["army"]
		var s = Sim.new(a0, a1, r)
		s.run_to_end()
		out.append([k, s.winner, s.tick, s.fingerprint])
	print("GOLD140 ", JSON.stringify(out))
	quit()
