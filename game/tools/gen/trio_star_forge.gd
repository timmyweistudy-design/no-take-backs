extends SceneTree
## V1.6.1 A3：一陣三考三星解求解器。從作者解出發爬山（移兵、換兵、拿掉、加兵），找「三場都贏、剩餘平均 ≥ S2、花費 ≤ S3%」的陣，
## 存進 trio.json 的 "sol3"（可重現的三星解，測試會重跑驗證）。找不到就用找到的最好那套當三星門檻（單組覆寫 s2／s3，記在輸出）。
## 用法（game/ 下）：godot --headless --path . --script res://tools/gen/trio_star_forge.gd [-- --iters=1500]
const Trio = preload("res://scripts/game/v16_trio.gd")
const PZ = preload("res://scripts/game/puzzles.gd")
const D = preload("res://scripts/core/unit_defs.gd")

var iters := 1500

func evalu(s: Dictionary, ex: Array) -> Array:
	# [分數, 星, 剩餘平均, 花費%]
	if PZ.check_extra(Trio.make_pz(s, 0), ex) != "":
		return [-1e9, 0, 0, 0]
	var res: Array = Trio.results(s, ex)
	var won := 0
	for r in res:
		if bool(r["ok"]):
			won += 1
	var ra := Trio.rem_avg(res)
	var sp := Trio.spent_pct(s, res)
	var sc := won * 1000.0
	if won == 3:
		sc += minf(ra, Trio.S2) * 8.0 + ra * 0.5 - maxf(0.0, sp - Trio.S3) * 10.0 - sp * 0.2
	return [sc, Trio.stars(s, res), ra, sp]

func mutate(s: Dictionary, ex: Array, rng: RandomNumberGenerator) -> Array:
	var b: Array = ex.duplicate(true)
	var al: Array = s["allowed"]
	match rng.randi_range(0, 4):
		0:
			if b.size() > 1:
				b.remove_at(rng.randi_range(0, b.size() - 1))
		1, 2:
			if not b.is_empty():
				var i := rng.randi_range(0, b.size() - 1)
				b[i] = [int(b[i][0]), rng.randi_range(0, 5), rng.randi_range(0, 8)]
		3:
			if not b.is_empty():
				var j := rng.randi_range(0, b.size() - 1)
				b[j] = [int(al[rng.randi_range(0, al.size() - 1)]), int(b[j][1]), int(b[j][2])]
		4:
			b.append([int(al[rng.randi_range(0, al.size() - 1)]), rng.randi_range(0, 5), rng.randi_range(0, 8)])
	return b

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--iters="):
			iters = int(a.substr(8))
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/trio.json"))
	for s in d["sets"]:
		s.erase("s2")
		s.erase("s3")
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(str(s["id"])) & 0x7fffffff
		var best: Array = s["sol"].duplicate(true)
		var bv := evalu(s, best)
		var cur := best.duplicate(true)
		var cv := bv
		for it in iters:
			if int(bv[1]) == 3 and it > iters / 3:
				break
			var cand := mutate(s, cur, rng)
			var v := evalu(s, cand)
			if float(v[0]) >= float(cv[0]):
				cur = cand
				cv = v
				if float(v[0]) > float(bv[0]) or (int(v[1]) == 3 and int(bv[1]) < 3):
					best = cand.duplicate(true)
					bv = v
			if it % 300 == 299:
				cur = best.duplicate(true)   # 回到最好的再走
				cv = bv
		best.sort()
		s["sol3"] = best
		if int(bv[1]) < 3:
			if int(bv[2]) < Trio.S2:
				s["s2"] = int(bv[2])
			if int(bv[3]) > Trio.S3:
				s["s3"] = int(bv[3])
		print("TRIO3 %s stars=%d rem=%d spent=%d units=%d %s" % [s["id"], int(bv[1]), int(bv[2]), int(bv[3]), best.size(), "" if int(bv[1]) == 3 else "OVERRIDE"])
	var f := FileAccess.open("res://data/trio.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(d, "\t", false))
	f.close()
	print("TRIO3 done")
	quit(0)
