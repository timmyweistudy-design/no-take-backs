extends SceneTree
## 第八輪奇幻軍平衡驗收。godot --headless --path game --script res://tools/fantasy_eval.gd -- --mode=repl --shard=0 --shards=4
## mode：
##   repl：每種兵（舊 10＋新 10）拿 25 金左右換進基準陣，對固定對手的勝率變化。舊兵的範圍當標準。
##   core：剋制表每條跑 40 場（主兵種 60 金＋劍士、弓箭手補滿）。
##   army：AI 模板「奇幻軍 vs 王國軍」勝率。
##   cheese：每種新兵買滿硬上限＋主力補滿，打固定對手的勝率（單兵種怪陣）。
const D = preload("res://scripts/core/unit_defs.gd")
const F8 = preload("res://scripts/core/fantasy_defs.gd")
const Army = preload("res://scripts/core/army.gd")
const Sim = preload("res://scripts/core/battle_sim.gd")
const F = preload("res://scripts/core/formations.gd")
const AI = preload("res://scripts/core/ai_army.gd")
const RS = preload("res://scripts/core/ruleset.gd")
const PRE = preload("res://scripts/game/presets.gd")
const AIT = preload("res://scripts/core/ai_turns.gd")

var R
var a := {}

func _init() -> void:
	for x in OS.get_cmdline_user_args():
		if x.begins_with("--") and "=" in x:
			var kv := x.substr(2).split("=", true, 1)
			a[kv[0]] = kv[1]
	R = PRE.make("standard", "ai", RS.all_pool())
	R.pool = [RS.full_pool(), RS.full_pool()]
	match str(a.get("mode", "repl")):
		"repl": repl()
		"core": core()
		"army": army()
		"cheese": cheese()
	quit(0)

func _shard(i: int) -> bool:
	return i % int(a.get("shards", "1")) == int(a.get("shard", "0"))

## 把格子軍轉成標準自由規則（新兵也照擺）。
func free_of(g: Army, rng = null) -> Army:
	return F.to_free(g, R, rng, "stretch")

func duel(x: Army, y: Army) -> float:
	var s1 := Sim.new(x.copy(), y.mirrored(), R)
	s1.fast = true
	s1.run_to_end()
	var s2 := Sim.new(y.copy(), x.mirrored(), R)
	s2.fast = true
	s2.run_to_end()
	return ((1.0 if s1.winner == 0 else (0.5 if s1.winner < 0 else 0.0)) + (1.0 if s2.winner == 1 else (0.5 if s2.winner < 0 else 0.0))) / 2.0

func opponents(n: int) -> Array:
	var out: Array = []
	var rng := RandomNumberGenerator.new()
	for i in n:
		rng.seed = 40100 + i * 613
		var pool: int = RS.all_pool() if i % 2 == 0 else RS.full_pool()
		var g: Army = _gridy(AI.build(0, 100, rng, -1, pool)["army"])
		out.append(free_of(g))
	return out

func _gridy(g: Army) -> Army:
	return g

## t 換進陣型：先拿掉最後面的兵，湊出 budget 再補 t。
func swap_in(g: Army, t: int, gold: int, rng: RandomNumberGenerator) -> Army:
	var c: Army = g.copy()
	c.pool = RS.full_pool()
	var need: int = gold
	var guard := 0
	while need > 0 and c.units.size() > 1 and guard < 40:
		guard += 1
		var k := rng.randi_range(0, c.units.size() - 1)
		need -= D.cost(int(c.units[k]["type"]))
		c.units.remove_at(k)
	var cols: Array = AI.PREF_COLS[t] + [5, 4, 3, 2, 1, 0]
	var placed := true
	while placed and c.left() >= D.cost(t):
		placed = false
		for col in cols:
			for r in AI.ROW_CENTER:
				if c.check_place(t, col, r) == "":
					c.place(t, col, r)
					placed = true
					break
			if placed:
				break
	return _fill(c, rng)   # 硬上限買不完的錢補主力，才公平

func repl() -> void:
	var opp := opponents(int(a.get("opp", "16")))
	var rng := RandomNumberGenerator.new()
	var bases: Array = []
	for i in int(a.get("bases", "12")):
		rng.seed = 7000 + i * 977
		bases.append(AI.build(0, 100, rng, -1, RS.all_pool())["army"])
	var idx := 0
	for t in range(-1, D.total()):
		idx += 1
		if not _shard(idx):
			continue
		var total := 0.0
		var n := 0
		var rr := RandomNumberGenerator.new()
		rr.seed = 3100 + t * 31
		for b in bases:
			var g: Army = b if t < 0 else swap_in(b, t, 25, rr)
			var fg: Army = free_of(g)
			for o in opp:
				total += duel(fg, o)
				n += 1
		print("R ", JSON.stringify({"t": t, "name": "基準" if t < 0 else D.name_of(t), "wr": snappedf(total / n, 0.001), "n": n}))

func core() -> void:
	var AT = AIT
	var idx := 0
	for at in range(D.COUNT, D.total()):
		for bt in AT.BEATS[at] + _beaten_by(at):
			var sign := 1 if bt in AT.BEATS[at] else -1
			idx += 1
			if not _shard(idx):
				continue
			var tot := 0.0
			var rng := RandomNumberGenerator.new()
			rng.seed = 21000 + at * 101 + bt * 7
			var x := _main_army(at, rng)
			for k in 20:
				var y := _main_army(bt, rng)
				tot += duel(free_of(_main_army(at, rng)), free_of(y))
			print("C ", JSON.stringify({"a": D.name_of(at), "b": D.name_of(bt), "want": sign, "wr": snappedf(tot / 20.0, 0.001)}))

func _beaten_by(t: int) -> Array:
	var out: Array = []
	for x in range(0, D.total()):
		if t in AIT.BEATS[x] and not x in AIT.BEATS[t]:
			out.append(x)
	return out

## 主兵種買到 60 金或硬上限；奇襲兵、支援兵由劍士、弓箭手補滿。
func _main_army(t: int, rng: RandomNumberGenerator) -> Army:
	var c := Army.new(0, 100)
	c.pool = RS.full_pool()
	var spent := 0
	var cols: Array = AI.PREF_COLS[t] + [5, 4, 3, 2, 1, 0]
	while spent + D.cost(t) <= 60:
		var ok := false
		for col in cols:
			for r in AI.ROW_CENTER:
				if c.check_place(t, col, r) == "":
					c.place(t, col, r)
					ok = true
					break
			if ok:
				break
		if not ok:
			break
		spent += D.cost(t)
	while c.left() >= 4:
		var ft: int = D.SWORD if rng.randf() < 0.5 and c.left() >= 5 else D.ARCHER
		var ok2 := false
		for col2 in (AI.PREF_COLS[ft] + [5, 4, 3, 2, 1, 0]):
			for r2 in AI.ROW_CENTER:
				if c.check_place(ft, col2, r2) == "":
					c.place(ft, col2, r2)
					ok2 = true
					break
			if ok2:
				break
		if not ok2:
			break
	return c

func army() -> void:
	var n := int(a.get("n", "120"))
	var fant: int = PRE.fantasy_pool(RS.full_pool())
	var tot := 0.0
	var cnt := 0
	var mix := 0.0
	for i in n:
		if not _shard(i):
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = 55000 + i * 37
		var x: Army = free_of(AI.build(0, 100, rng, -1, fant)["army"])
		var y: Army = free_of(AI.build(0, 100, rng, -1, RS.all_pool())["army"])
		tot += duel(x, y)
		cnt += 1
	print("A ", JSON.stringify({"fantasy_wr": snappedf(tot / maxi(1, cnt), 0.001), "n": cnt}))

func cheese() -> void:
	var opp := opponents(int(a.get("opp", "20")))
	var idx := 0
	for t in range(D.COUNT, D.total()):
		idx += 1
		if not _shard(idx):
			continue
		var c := Army.new(0, 100)
		c.pool = RS.full_pool()
		var rng := RandomNumberGenerator.new()
		rng.seed = 91 + t
		var cols: Array = AI.PREF_COLS[t] + [5, 4, 3, 2, 1, 0]
		var going := true
		while going:
			going = false
			for col in cols:
				for r in AI.ROW_CENTER:
					if c.check_place(t, col, r) == "":
						c.place(t, col, r)
						going = true
						break
				if going:
					break
		var rest: Army = _fill(c, rng)
		var fg := free_of(rest)
		var tot := 0.0
		for o in opp:
			tot += duel(fg, o)
		print("X ", JSON.stringify({"name": D.name_of(t), "n_units": c.count_of(t), "wr": snappedf(tot / opp.size(), 0.001)}))

func _fill(c: Army, rng: RandomNumberGenerator) -> Army:
	while c.left() >= 4:
		var ft: int = D.SWORD if c.left() >= 5 and rng.randf() < 0.6 else D.ARCHER
		var done := false
		for col2 in (AI.PREF_COLS[ft] + [5, 4, 3, 2, 1, 0]):
			for r2 in AI.ROW_CENTER:
				if c.check_place(ft, col2, r2) == "":
					c.place(ft, col2, r2)
					done = true
					break
			if done:
				break
		if not done:
			break
	return c
