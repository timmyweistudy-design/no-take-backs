extends SceneTree
## 平衡工具 2.0（優化方案 B2、A2、L2）。由 tools/balance.sh 多行程分片呼叫，每場一行 JSON（前綴 "R "）。
##   --mode=matrix    純兵種 60 金方陣 5×5（剋制）
##   --mode=league    訓練池 200 套，每套對 12 個對手、交換左右
##   --mode=turns     輪流落子先後手測試（--rule=cap10|snake5|snake5c，--games=N）
##   --mode=search    爬山搜尋萬用陣（對保留池評估）
##   --mode=counter   離線反制庫：每個原型陣找訓練池裡最能剋它的陣型
##   --mode=countersearch --target=<代碼>  針對一個（疑似萬用）陣型爬山找反制
##   --shard=i --shards=N

const D = preload("res://scripts/core/unit_defs.gd")
const Army = preload("res://scripts/core/army.gd")
const Sim = preload("res://scripts/core/battle_sim.gd")
const F = preload("res://scripts/core/formations.gd")
const AIT = preload("res://scripts/core/ai_turns.gd")
const TP = preload("res://scripts/core/turn_placement.gd")
const AI = preload("res://scripts/core/ai_army.gd")

var args := {}

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1]
	NT = int(args.get("ntypes", str(D.COUNT)))   # 第四輪：池子開放的兵種數（5＝經典，和第三輪相同）
	var shard := int(args.get("shard", "0"))
	var shards := int(args.get("shards", "1"))
	match args.get("mode", "league"):
		"matrix": matrix(shard, shards)
		"league": league(shard, shards)
		"valleague": league(shard, shards, true)
		"turns": turns(shard, shards)
		"search": search(shard, shards)
		"counter": counter(shard, shards)
		"countersearch": countersearch(shard, shards)
	quit(0)

var NT := D.COUNT

func emit(d: Dictionary) -> void:
	d["digest"] = D.data_digest()
	d["ntypes"] = NT
	print("R ", JSON.stringify(d))

## 打一場：a 是藍方陣型（team 0）、b 也是以藍方表示的陣型（會鏡像成紅方）。回傳以 a 的角度的結果。
func fight(a: Army, b: Army) -> Dictionary:
	var s := Sim.new(a.copy(), b.mirrored())
	s.fast = true
	s.run_to_end()
	var m: Dictionary = s.suspense()
	var res := 0
	if s.winner == 0:
		res = 1
	elif s.winner == 1:
		res = -1
	var rem := 0
	if s.winner >= 0:
		rem = s.power(s.winner) * 100 / (s.budget * 1000)
	return {"res": res, "ticks": s.tick, "rem": rem, "timeout": s.reason.begins_with("時間到"),
		"lc": m["lead_changes"], "lock": m["lock_ratio_permille"], "swing": m["max_swing_pct"]}

func block(t: int, gold: int) -> Army:
	var a := Army.new(0, 100)
	var n := gold / D.cost(t)
	var cols := [5, 4, 3, 2, 1, 0] if t != D.ARCHER else [0, 1, 2, 3, 4, 5]
	var rows := [4, 3, 5, 2, 6, 1, 7, 0, 8]
	var k := 0
	for c in cols:
		for r in rows:
			if k < n:
				a.units.append({"type": t, "col": c, "row": r})
				k += 1
	return a

func matrix(shard: int, shards: int) -> void:
	var idx := 0
	for i in D.COUNT:
		for j in D.COUNT:
			if i == j:
				continue
			idx += 1
			if idx % shards != shard:
				continue
			var r := fight(block(i, 60), block(j, 60))
			r["mode"] = "matrix"; r["a"] = i; r["b"] = j
			emit(r)

func league(shard: int, shards: int, val := false) -> void:
	var pool := F.validation_pool(0, NT) if val else F.training_pool(0, NT)
	for i in pool.size():
		if i % shards != shard:
			continue
		for k in 12:
			var j := (i * 37 + k * 53 + 1) % pool.size()
			if j == i:
				j = (j + 1) % pool.size()
			# 交換左右各打一次：i 當藍方、i 當紅方（結果都以 i 的角度記錄）
			for side in 2:
				var r := fight(pool[i], pool[j]) if side == 0 else fight(pool[j], pool[i])
				if side == 1:
					r["res"] = -r["res"]
				r["mode"] = "valleague" if val else "league"; r["a"] = i; r["b"] = j; r["k"] = k; r["side"] = side; r["comp"] = F.composition(pool[i])
				emit(r)

func turns(shard: int, shards: int) -> void:
	var rule: String = args.get("rule", "cap10")
	var games := int(args.get("games", "400"))   # 200 組×（同種子交換先手）
	var level := int(args.get("level", "1"))
	var rng := RandomNumberGenerator.new()
	for g in games:
		if g % shards != shard:
			continue
		# 成對：同一個種子打兩場，只交換先手（隔離先後手效果）
		rng.seed = 424242 + (g / 2) * 104729
		var first := g % 2
		var tp := TP.new(Army.new(0, 100), Army.new(1, 100), first, rule)
		var guard := 0
		while not tp.done() and guard < 100:
			guard += 1
			AIT.play_turn(tp, rng, level)
		var s := Sim.new(tp.armies[0], tp.armies[1])
		s.fast = true
		s.run_to_end()
		var first_won := 0
		if s.winner == first:
			first_won = 1
		elif s.winner == 1 - first:
			first_won = -1
		emit({"mode": "turns", "rule": rule, "game": g, "first": first, "first_won": first_won,
			"handoffs": tp.handoffs, "spent0": tp.armies[0].spent(), "spent1": tp.armies[1].spent(), "ticks": s.tick, "level": level})

func fitness(a: Army, opps: Array) -> float:
	var w := 0.0
	for o in opps:
		var r := fight(a, o)
		w += 1.0 if r["res"] == 1 else (0.5 if r["res"] == 0 else 0.0)
		var r2 := fight(o, a)
		w += 1.0 if r2["res"] == -1 else (0.5 if r2["res"] == 0 else 0.0)
	return w / (opps.size() * 2)

func mutate(a: Army, rng: RandomNumberGenerator) -> Army:
	var b: Army = a.copy()
	var op := rng.randi_range(0, 2)
	if b.units.is_empty():
		op = 2
	if op == 0:
		# 換一隻的兵種（守預算）
		var i := rng.randi_range(0, b.units.size() - 1)
		var old: int = b.units[i]["type"]
		var t := rng.randi_range(0, NT - 1)
		if b.spent() - D.cost(old) + D.cost(t) <= 100:
			b.units[i]["type"] = t
	elif op == 1:
		# 移動一隻
		var i := rng.randi_range(0, b.units.size() - 1)
		var c := rng.randi_range(0, 5)
		var r := rng.randi_range(0, 8)
		if b.index_at(c, r) == -1:
			b.units[i]["col"] = c
			b.units[i]["row"] = r
	else:
		# 拿掉一隻、補別種
		if not b.units.is_empty():
			b.units.remove_at(rng.randi_range(0, b.units.size() - 1))
		var t := rng.randi_range(0, NT - 1)
		F.place_styled(b, t, "role", rng)
	return b

func search(shard: int, shards: int) -> void:
	var iters := int(args.get("iters", "12"))
	var nopp := int(args.get("opps", "24"))
	var hold := F.holdout_pool(0, NT)
	var spool := F.search_pool(0, NT)
	var opps: Array = []
	for k in nopp:
		opps.append(spool[(k * 2 + shard) % spool.size()])
	var rng := RandomNumberGenerator.new()
	rng.seed = 777 + shard * 1009
	var train := F.training_pool(0, NT)
	var cur: Army = train[rng.randi_range(0, train.size() - 1)].copy()
	var cur_f := fitness(cur, opps)
	for it in iters:
		var cand := mutate(cur, rng)
		var f := fitness(cand, opps)
		if f >= cur_f:
			cur = cand
			cur_f = f
	# 最後對「沒參與演化」的保留池驗證
	var full := fitness(cur, hold)
	emit({"mode": "search", "shard": shard, "fit_sample": cur_f, "fit_holdout": full, "code": cur.to_code(), "comp": F.composition(cur)})

## 反制搜尋：從訓練池不同起點爬山，找能打贏 target 的陣型。
func countersearch(shard: int, shards: int) -> void:
	var target := Army.new(0, 100)
	if target.load_code(args.get("target", "")) != "":
		emit({"mode": "countersearch", "shard": shard, "error": "bad target"})
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 31337 + shard * 7717
	var train := F.training_pool(0, NT)
	var cur: Army = train[(shard * 13) % train.size()].copy()
	var cur_f := fitness(cur, [target])
	for it in int(args.get("iters", "20")):
		var cand := mutate(cur, rng)
		var f := fitness(cand, [target])
		if f >= cur_f:
			cur = cand
			cur_f = f
	emit({"mode": "countersearch", "shard": shard, "fit": cur_f, "code": cur.to_code(), "comp": F.composition(cur)})

## 離線反制庫：原型陣（AI 模板×種子）→ 訓練池中勝它最多的陣型代碼。
func counter(shard: int, shards: int) -> void:
	var rng := RandomNumberGenerator.new()
	var train := F.training_pool(0, NT)
	for ti in AI.TEMPLATES.size():
		if ti % shards != shard:
			continue
		rng.seed = 5150 + ti
		var proto: Army = AI.build(0, 100, rng, ti)["army"]
		var best := -1
		var best_f := -1.0
		for j in range(0, train.size(), 2):
			var f := fitness(train[j], [proto])
			if f > best_f:
				best_f = f
				best = j
		emit({"mode": "counter", "template": ti, "name": AI.TEMPLATES[ti]["name"], "proto_comp": F.composition(proto),
			"best": best, "best_fit": best_f, "code": train[best].to_code()})
