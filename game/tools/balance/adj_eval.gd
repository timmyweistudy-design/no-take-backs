extends SceneTree
## V1.6.1 A6：相鄰陣法 4 組加成各自量（AI 代理，不是真人）。
## 每組 k：我方卡池＝這組兩種兵＋醫者、投彈兵（不在任何一組裡）；對方卡池＝王國軍拿掉所有「拿加成」的兵種（對方不會拿到加成）。
## 同一批陣型各打「相鄰陣法開」與「關」，差＝開的勝率 − 關的勝率；只算我方真的有排出相鄰的場次另列。
## 用法（game/ 下）：godot --headless --path . --script res://tools/balance/adj_eval.gd -- --n=120 --out=res://adj.jsonl
const ADJ = preload("res://scripts/core/adj_defs.gd")
const Sim = preload("res://scripts/core/battle_sim.gd")
const AI = preload("res://scripts/core/ai_army.gd")
const RS = preload("res://scripts/core/ruleset.gd")
const D = preload("res://scripts/core/unit_defs.gd")

func run(a0, a1, r) -> int:
	var s = Sim.new(a0.copy(), a1.copy(), r)
	s.fast = true
	s.run_to_end()
	return s.winner

func _init() -> void:
	var n := 120
	var out_path := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--n="): n = int(a.substr(4))
		elif a.begins_with("--out="): out_path = a.substr(6)
	var recv := 0
	for p in ADJ.PAIRS:
		recv |= 1 << int(p[0])
	var kingdom := (1 << 10) - 1
	var lines: Array = []
	for k in ADJ.PAIRS.size():
		var p: Array = ADJ.PAIRS[k]
		var pool0 := (1 << int(p[0])) | (1 << int(p[1])) | (1 << D.MEDIC) | (1 << D.BOMBER)
		var pool1 := kingdom & ~recv
		var r_on = RS.standard()
		r_on.adj = true
		r_on.pool = [pool0, pool1]
		var r_off = r_on.copy()
		r_off.adj = false
		var rng := RandomNumberGenerator.new()
		rng.seed = 6100 + k
		var won := [0, 0]
		var linked := 0
		var won_l := [0, 0]
		for i in n:
			var a0 = AI.build(0, 100, rng, -1, pool0, r_on)["army"]
			var a1 = AI.build(1, 100, rng, -1, pool1, r_on)["army"]
			if a0.units.is_empty() or a1.units.is_empty():
				continue
			var s_probe = Sim.new(a0.copy(), a1.copy(), r_on)
			var has_link: bool = int(s_probe.adj_n) > 0
			var w_on := run(a0, a1, r_on)
			var w_off := run(a0, a1, r_off)
			won[0] += 1 if w_on == 0 else 0
			won[1] += 1 if w_off == 0 else 0
			if has_link:
				linked += 1
				won_l[0] += 1 if w_on == 0 else 0
				won_l[1] += 1 if w_off == 0 else 0
		var rec := {"pair": k, "recv": int(p[0]), "near": int(p[1]), "kind": p[2], "n": n, "on_pct": won[0] * 100.0 / n, "off_pct": won[1] * 100.0 / n,
			"linked": linked, "on_l": won_l[0] * 100.0 / maxi(1, linked), "off_l": won_l[1] * 100.0 / maxi(1, linked)}
		lines.append(JSON.stringify(rec))
		print("ADJ ", rec)
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		f.store_string("\n".join(lines) + "\n")
		f.close()
	print("ADJ done")
	quit(0)
