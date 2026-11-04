extends SceneTree
## 100 組隨機陣型的左右交換逐 tick 比對（N1 驗收）。godot --headless --path game --script res://tools/mirror_100.gd
const AI = preload("res://scripts/core/ai_army.gd")
const MC = preload("res://scripts/core/mirror_check.gd")
func _init() -> void:
	var rng := RandomNumberGenerator.new()
	var bad := 0
	var sh := [0, 1]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shard="):
			sh = [int(a.substr(8).split("/")[0]), int(a.substr(8).split("/")[1])]
	for i in 100:
		if i % int(sh[1]) != int(sh[0]):
			continue
		rng.seed = 100003 * i + 17
		var why: String = MC.check(AI.build(0, 100, rng)["army"], AI.build(1, 100, rng)["army"])
		if why != "":
			bad += 1
			print("case ", i, ": ", why)
	print("MIRROR100 %d/100 一致" % (100 - bad))   # 分片時 100 是全部案例數，只比自己那片
	quit(1 if bad > 0 else 0)
