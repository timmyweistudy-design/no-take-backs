extends SceneTree
## 第五輪 P0：封存舊格式對戰代碼（NTB2）＋預期結果。
## 自訂規則上線後，舊代碼要用舊判定（judge=1）播出完全相同的一場；這裡存的是「當時的字串」，不是用新版自己編再自己解。
## 產生（只在 1.3.0 規則下做一次）：godot --headless --path game --script res://tools/seal_codes.gd -- --make
## 檢查：godot --headless --path game --script res://tools/seal_codes.gd
const Sim = preload("res://scripts/core/battle_sim.gd")
const AI = preload("res://scripts/core/ai_army.gd")
const F = preload("res://scripts/core/formations.gd")
const D = preload("res://scripts/core/unit_defs.gd")
const BC = preload("res://scripts/game/battle_code.gd")
const PATH := "res://tests/golden/battle_codes_v2.json"
const N := 40
# 預算組合：一般 100／100，加上遠征、殘局會出現的不等預算（含 30 對 160 這類極端值）
const BUDGETS := [[100, 100], [100, 100], [100, 100], [100, 100], [30, 160], [160, 30], [60, 100], [100, 140], [25, 25], [200, 120]]

static func play(code: String) -> Dictionary:
	var d := BC.decode(code)
	if not d["ok"]:
		return {"ok": false, "why": d["why"]}
	var s = Sim.new(d["a0"], d["a1"])
	s.fast = true
	s.run_to_end()
	return {"ok": true, "w": s.winner, "t": s.tick, "fp": s.fingerprint, "p0": s.power(0), "p1": s.power(1)}

func _init() -> void:
	if "--make" in OS.get_cmdline_user_args():
		var rng := RandomNumberGenerator.new()
		var rows: Array = []
		for i in N:
			rng.seed = 5050 + i * 104729
			var bud: Array = BUDGETS[i % BUDGETS.size()]
			var a0 = AI.build(0, bud[0], rng)["army"] if (i % 3 != 2 or bud[0] < 100) else F.random_formation(0, rng, "mixed", "", D.COUNT)
			var a1 = AI.build(1, bud[1], rng)["army"]
			a0.budget = bud[0]
			a1.budget = bud[1]
			var code := BC.encode(a0, a1)
			var r := play(code)
			if not r["ok"]:
				push_error("封存失敗：第 %d 筆 %s" % [i, r["why"]])
				quit(1)
				return
			rows.append({"code": code, "w": r["w"], "t": r["t"], "fp": r["fp"], "p0": r["p0"], "p1": r["p1"]})
		var f := FileAccess.open(PATH, FileAccess.WRITE)
		f.store_string(JSON.stringify({"rules": D.RULES_VERSION, "digest": D.data_digest(), "rows": rows}))
		f.close()
		print("SEALCODES 已封存 %d 筆" % rows.size())
		quit(0)
		return
	var g = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not g is Dictionary or not g.get("rows") is Array or g["rows"].size() != N:
		print("SEALCODES 失敗：封存檔不存在或筆數不是 %d" % N)
		quit(1)
		return
	var bad := 0
	for row in g["rows"]:
		var r := play(str(row["code"]))
		if not r["ok"] or int(r["w"]) != int(row["w"]) or int(r["t"]) != int(row["t"]) or str(r["fp"]) != str(row["fp"]) \
				or int(r["p0"]) != int(row["p0"]) or int(r["p1"]) != int(row["p1"]):
			bad += 1
			if bad <= 3:
				print("  分歧：", str(row["code"]).substr(0, 40), "… ", r)
	print("SEALCODES %s" % JSON.stringify({"n": g["rows"].size(), "ok": bad == 0}))
	quit(0 if bad == 0 else 1)
