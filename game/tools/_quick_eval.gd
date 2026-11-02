extends SceneTree
## 調參用的快速評估（不是驗收）：核心關係 20 種排法、替換實驗 50 套 × 3 對手 × 補法 a/b/c。
## godot --headless --path game --script res://tools/_quick_eval.gd -- --units=5,6 --rel=0,1,2,3 --ntypes=7
const UE = preload("res://tools/unit_eval.gd")
const D = preload("res://scripts/core/unit_defs.gd")
const F = preload("res://scripts/core/formations.gd")

func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1]
	var nt := int(args.get("ntypes", "7"))
	var part := int(args.get("part", "0"))
	var parts := int(args.get("parts", "1"))
	var idx := 0
	if args.has("rel"):
		for rs in str(args["rel"]).split(","):
			var ri := int(rs)
			idx += 1
			if idx % parts != part:
				continue
			var sum := 0.0
			for sd in 20:
				var rng := RandomNumberGenerator.new()
				rng.seed = 90001 + ri * 1013 + sd * 7919
				var wx := D.zeros()
				wx[UE.CORE[ri][0]] = 3
				wx[D.SWORD] += 1
				wx[D.ARCHER] += 1
				var wy := D.zeros()
				wy[UE.CORE[ri][1]] = 3
				wy[D.SWORD] += 1
				wy[D.ARCHER] += 1
				var style: String = F.STYLES[sd % F.STYLES.size()]
				var sc := UE.duel2(F.weighted_formation(0, rng, wx, style), F.weighted_formation(0, rng, wy, style))
				sum += (sc[0] + sc[1]) / 2.0
			print("Q core %s %.0f%%" % [UE.CORE[ri][2], sum / 20.0 * 100.0])
	if args.has("units"):
		var opps := F.validation_pool(0, nt)
		for us in str(args["units"]).split(","):
			var x := int(us)
			idx += 1
			if idx % parts != part:
				continue
			var tot := {"orig": 0.0, "a": 0.0, "b": 0.0, "c": 0.0}
			var n := 0
			for i in 50:
				var orig = UE.with_unit(x, nt, i)
				if orig == null:
					continue
				var v := {"orig": orig, "a": UE.refill(orig, x, UE.most_common_other(orig, x)), "b": UE.refill(orig, x, D.SWORD), "c": UE.refill(orig, x, D.ARCHER)}
				for k in 3:
					var opp = opps[(i * 7 + k * 31) % opps.size()]
					for pol in v:
						var sc := UE.duel2(v[pol], opp)
						tot[pol] += (sc[0] + sc[1]) / 2.0
					n += 1
			print("Q repl %s orig %.0f%%  Δa %+.1f  Δb %+.1f  Δc %+.1f" % [D.NAMES[x], tot["orig"] / n * 100, (tot["orig"] - tot["a"]) / n * 100, (tot["orig"] - tot["b"]) / n * 100, (tot["orig"] - tot["c"]) / n * 100])
	if args.has("cover"):
		var opps2 := F.validation_pool(0, nt)
		for us in str(args["cover"]).split(","):
			var sup := int(us)
			idx += 1
			if idx % parts != part:
				continue
			var acc := [0.0, 0.0, 0.0, 0.0]
			var n2 := 0
			for i in 40:
				var rng := RandomNumberGenerator.new()
				rng.seed = 515151 + sup * 100003 + i * 7919
				var w := D.zeros()
				for t in nt:
					if not D.is_support(t):
						w[t] = rng.randi_range(0, 3)
				if w.max() == 0:
					w[D.SWORD] = 1
				var base := F.weighted_formation(0, rng, w)
				for k in 3:
					var opp = opps2[(i * 11 + k * 37) % opps2.size()]
					for kk in 4:
						var sc := UE.duel2(UE.with_supports(base, sup, kk), opp)
						acc[kk] += (sc[0] + sc[1]) / 2.0
					n2 += 1
			print("Q cover %s k0 %.0f%%  Δ1 %+.1f  Δ2 %+.1f  Δ3 %+.1f" % [D.NAMES[sup], acc[0] / n2 * 100, (acc[1] - acc[0]) / n2 * 100, (acc[2] - acc[0]) / n2 * 100, (acc[3] - acc[0]) / n2 * 100])
	quit()
