extends SceneTree
## V1.6.1 A6：相鄰陣法 4 組加成各自量（AI 代理，不是真人）。
## 做法：雙方都用王國軍全卡池隨機 AI 陣（勝率接近 50%），同一對陣各打「相鄰陣法開／關」。
## 對每一組 k，只看「一方有這組相鄰、另一方沒有」的場次，算有的那一方開與關的勝率差；樣本少就寫明。
## 為了讓每組都有樣本，一半的場次把我方隨機一隻「拿加成」兵移到同組夥伴旁邊（陣型其他不動）。
## 用法（game/ 下）：godot --headless --path . --script res://tools/balance/adj_eval.gd -- --n=400 --out=res://adj.jsonl
const ADJ = preload("res://scripts/core/adj_defs.gd")
const Sim = preload("res://scripts/core/battle_sim.gd")
const AI = preload("res://scripts/core/ai_army.gd")
const RS = preload("res://scripts/core/ruleset.gd")

func links(units: Array, k: int) -> bool:
	var p: Array = ADJ.PAIRS[k]
	for u in units:
		if int(u["type"]) != int(p[0]):
			continue
		for v in units:
			if v != u and int(v["type"]) == int(p[1]) and absi(int(v["col"]) - int(u["col"])) + absi(int(v["row"]) - int(u["row"])) == 1:
				return true
	return false

func force_link(a, k: int, rng: RandomNumberGenerator) -> void:
	var p: Array = ADJ.PAIRS[k]
	var rs: Array = []
	var ns: Array = []
	for i in a.units.size():
		if int(a.units[i]["type"]) == int(p[0]): rs.append(i)
		if int(a.units[i]["type"]) == int(p[1]): ns.append(i)
	if rs.is_empty() or ns.is_empty():
		return
	var u: Dictionary = a.units[rs[rng.randi_range(0, rs.size() - 1)]]
	var v: Dictionary = a.units[ns[rng.randi_range(0, ns.size() - 1)]]
	for d in [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0)]:
		var c: int = int(v["col"]) + int(d.x)
		var r: int = int(v["row"]) + int(d.y)
		if a.in_zone(c, r) and a.index_at(c, r) == -1:
			u["col"] = c
			u["row"] = r
			return

func run(a0, a1, r) -> int:
	var s = Sim.new(a0.copy(), a1.copy(), r)
	s.fast = true
	s.run_to_end()
	return s.winner

func _init() -> void:
	var n := 400
	var out_path := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--n="): n = int(a.substr(4))
		elif a.begins_with("--out="): out_path = a.substr(6)
	var kingdom := (1 << 10) - 1
	var r_on = RS.standard()
	r_on.adj = true
	var r_off = r_on.copy()
	r_off.adj = false
	var lines: Array = []
	for k in ADJ.PAIRS.size():
		var rng := RandomNumberGenerator.new()
		rng.seed = 7300 + k
		var cnt := 0
		var won := [0, 0]
		for i in n:
			var a0 = AI.build(0, 100, rng, -1, kingdom, r_on)["army"]
			var a1 = AI.build(1, 100, rng, -1, kingdom, r_on)["army"]
			if i % 2 == 0:
				force_link(a0, k, rng)
			var l0 := links(a0.units, k)
			var l1 := links(a1.units, k)
			if l0 == l1:
				continue
			var side := 0 if l0 else 1
			cnt += 1
			won[0] += 1 if run(a0, a1, r_on) == side else 0
			won[1] += 1 if run(a0, a1, r_off) == side else 0
		var p: Array = ADJ.PAIRS[k]
		var rec := {"pair": k, "recv": int(p[0]), "near": int(p[1]), "kind": p[2], "samples": cnt,
			"on_pct": snappedf(won[0] * 100.0 / maxi(1, cnt), 0.1), "off_pct": snappedf(won[1] * 100.0 / maxi(1, cnt), 0.1),
			"delta": snappedf((won[0] - won[1]) * 100.0 / maxi(1, cnt), 0.1)}
		lines.append(JSON.stringify(rec))
		print("ADJ ", rec)
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		f.store_string("\n".join(lines) + "\n")
		f.close()
	print("ADJ done")
	quit(0)
