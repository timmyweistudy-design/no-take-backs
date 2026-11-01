extends SceneTree
## 100 組隨機陣型的左右交換逐 tick 比對（N1 驗收）。godot --headless --path game --script res://tools/mirror_100.gd
const AI = preload("res://scripts/core/ai_army.gd")
const MC = preload("res://scripts/core/mirror_check.gd")
func _init() -> void:
	var rng := RandomNumberGenerator.new()
	var bad := 0
	for i in 100:
		rng.seed = 100003 * i + 17
		var why: String = MC.check(AI.build(0, 100, rng)["army"], AI.build(1, 100, rng)["army"])
		if why != "":
			bad += 1
			print("case ", i, ": ", why)
	print("MIRROR100 %d/100 一致" % (100 - bad))
	quit(1 if bad > 0 else 0)
