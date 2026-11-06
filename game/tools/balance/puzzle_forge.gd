extends SceneTree
## 第十三輪：殘局量產。讀草稿（敵陣、固定兵、預算、可用兵種、目標），自動：
##   ① 什麼都不放會不會過 ② 隨機擺法過關率 ③ 多種子爬山收集所有過關解 → 前緣（花費少、剩餘多）
##   ④ 從前緣挑三星解並訂門檻 ⑤ 拿掉主角兵種還過不過 ⑥ 兩組不同的標準解 ⑦ 鄰格容錯 ⑧ 戰鬥長度
## 判定一律走 puzzles.gd 的 play()／outcome()，和遊戲同一套。
## godot --headless --path game --script res://tools/balance/puzzle_forge.gd -- --in=<草稿.json> [--id=x] [--iters=1600] [--seeds=3]
const P = preload("res://scripts/game/puzzles.gd")
const D = preload("res://scripts/core/unit_defs.gd")

var _cache := {}

func key_of(pz: Dictionary, ex: Array, plan: Array) -> String:
	var s: Array = ex.duplicate(true)
	s.sort()
	return pz["id"] + JSON.stringify(s) + JSON.stringify(plan)

func run(pz: Dictionary, ex: Array, plan: Array) -> Dictionary:
	var k := key_of(pz, ex, plan)
	if _cache.has(k):
		return _cache[k]
	var r := P.play(pz, ex, plan, false)
	_cache[k] = r
	return r

func legal(pz: Dictionary, ex: Array) -> bool:
	return P.check_extra(pz, ex) == ""

func random_extra(pz: Dictionary, allowed: Array, rng: RandomNumberGenerator, fill := 1.0) -> Array:
	var ex: Array = []
	var left: int = int(int(pz["budget"]) * fill)
	for k in 14:
		var t: int = allowed[rng.randi_range(0, allowed.size() - 1)]
		if D.cost(t) > left:
			continue
		for tries in 12:
			var c := [t, rng.randi_range(0, 5), rng.randi_range(0, 8)]
			var e2: Array = ex.duplicate(true)
			e2.append(c)
			if legal(pz, e2):
				ex = e2
				left -= D.cost(t)
				break
	return ex

func spent_of(ex: Array) -> int:
	var s := 0
	for e in ex:
		s += D.cost(int(e[0]))
	return s

func mutate(pz: Dictionary, ex: Array, allowed: Array, rng: RandomNumberGenerator) -> Array:
	for tries in 8:
		var e2: Array = ex.duplicate(true)
		var op := rng.randi_range(0, 4)
		if e2.is_empty():
			op = 3
		match op:
			0, 4:
				var i := rng.randi_range(0, e2.size() - 1)
				e2[i][1] = clampi(int(e2[i][1]) + rng.randi_range(-2, 2), 0, 5)
				e2[i][2] = clampi(int(e2[i][2]) + rng.randi_range(-2, 2), 0, 8)
			1:
				e2[rng.randi_range(0, e2.size() - 1)][0] = allowed[rng.randi_range(0, allowed.size() - 1)]
			2:
				e2.remove_at(rng.randi_range(0, e2.size() - 1))
			3:
				e2.append([allowed[rng.randi_range(0, allowed.size() - 1)], rng.randi_range(0, 5), rng.randi_range(0, 8)])
		if legal(pz, e2):
			return e2
	return ex

func mutate_plan(pz: Dictionary, plan: Array, rng: RandomNumberGenerator) -> Array:
	if plan.is_empty():
		return plan
	var p2: Array = plan.duplicate()
	var i := rng.randi_range(0, p2.size() - 1)
	var lim: int = int(pz.get("goal_ticks", 1800)) - 10
	p2[i] = clampi(int(p2[i]) + rng.randi_range(-12, 12) * 10, int(pz.get("plan_min", 60)), lim)
	p2.sort()
	var cd: int = P.rules_of(pz).cmd_cd
	for k in range(1, p2.size()):
		p2[k] = maxi(int(p2[k]), int(p2[k - 1]) + cd)   # 和遊戲面板同樣的限制：同一招前後至少隔一個冷卻
	if int(p2[p2.size() - 1]) > lim:
		return plan
	return p2

## 草稿可選 "plan_min"：技能最早第幾 tick 放（提示說「等對方放完」的時序關，三星解要真的等）。
func start_plan(pz: Dictionary) -> Array:
	var out: Array = []
	var pm: int = int(pz.get("plan_min", 0))
	for t in P.default_plan(pz):
		out.append(maxi(int(t), pm))
	return out

## 草稿可選 "need"：三星解一定要有這種兵（提示點名的主角）。
func has_need(pz: Dictionary, ex: Array) -> bool:
	if not pz.has("need"):
		return true
	for e in ex:
		if int(e[0]) == int(pz["need"]):
			return true
	return false

## 目標：先過關，再在「剩餘戰力」和「省錢」之間依 w 取捨。
func score(r: Dictionary, budget: int, w: int) -> int:
	if r.has("illegal"):
		return -100000000
	if not bool(r["ok"]):
		return -1000000 + int(r.get("ticks", 0))
	if r.has("no_need"):
		return -500000
	return 1000000 + int(r["rem"]) * (10 - w) * 10 - int(r["spent"]) * 100 * w * 10 / maxi(1, budget)

func climb(pz: Dictionary, allowed: Array, iters: int, seed_: int, found: Array) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var first := -1
	var evals := 0
	var budget: int = int(pz["budget"])
	for restart in 4:
		var w: int = [2, 5, 8, 0][restart]
		var cur := random_extra(pz, allowed, rng)
		var plan: Array = start_plan(pz)
		var r := run(pz, cur, plan)
		var cs := score(r, budget, w)
		for it in iters / 4:
			var c2: Array = cur
			var p2: Array = plan
			if not plan.is_empty() and rng.randi_range(0, 2) == 0:
				p2 = mutate_plan(pz, plan, rng)
			else:
				c2 = mutate(pz, cur, allowed, rng)
			var r2 := run(pz, c2, p2)
			if not has_need(pz, c2) and bool(r2.get("ok", false)):
				r2 = r2.duplicate()
				r2["no_need"] = true
			evals += 1
			if bool(r2.get("ok", false)) and has_need(pz, c2):
				found.append({"u": c2, "p": p2, "rem": int(r2["rem"]), "spent": int(r2["spent"]), "ticks": int(r2["ticks"])})
				if first < 0:
					first = evals
			var s2 := score(r2, budget, w)
			if s2 >= cs:
				cur = c2
				plan = p2
				cs = s2
	return first

## 前緣：沒有別的解同時更省又剩更多。
func frontier(found: Array) -> Array:
	var out: Array = []
	for a in found:
		var dom := false
		for b in found:
			if (int(b["spent"]) <= int(a["spent"]) and int(b["rem"]) >= int(a["rem"])) and (int(b["spent"]) < int(a["spent"]) or int(b["rem"]) > int(a["rem"])):
				dom = true
				break
		if not dom:
			var dup := false
			for o in out:
				if int(o["spent"]) == int(a["spent"]) and int(o["rem"]) == int(a["rem"]):
					dup = true
			if not dup:
				out.append(a)
	out.sort_custom(func(a, b): return int(a["spent"]) < int(b["spent"]))
	return out

func multiset(ex: Array) -> String:
	var t: Array = []
	for e in ex:
		t.append(int(e[0]))
	t.sort()
	return str(t)

func tolerance(pz: Dictionary, sol: Dictionary) -> int:
	var tot := 0
	var good := 0
	for i in sol["u"].size():
		for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
			var ex: Array = sol["u"].duplicate(true)
			ex[i][1] = int(ex[i][1]) + d[0]
			ex[i][2] = int(ex[i][2]) + d[1]
			if not legal(pz, ex):
				continue
			tot += 1
			if bool(run(pz, ex, sol["p"]).get("ok", false)):
				good += 1
	return good * 100 / maxi(1, tot)

func forge(pz: Dictionary, iters: int, seeds: int) -> Dictionary:
	var allowed: Array = []
	for v in pz["allowed"]:
		allowed.append(int(v))
	var m := {}
	m["empty_ok"] = bool(run(pz, [], P.default_plan(pz)).get("ok", false))
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var ok_n := 0
	for k in 120:
		if bool(run(pz, random_extra(pz, allowed, rng), P.default_plan(pz)).get("ok", false)):
			ok_n += 1
	m["rand_pct"] = ok_n * 100 / 120
	var found: Array = []
	var firsts: Array = []
	for s in seeds:
		firsts.append(climb(pz, allowed, iters, 1000 + s * 77, found))
	m["first"] = firsts
	m["found"] = found.size()
	if found.is_empty():
		return {"metrics": m}
	var fr := frontier(found)
	m["frontier"] = fr.map(func(f): return [f["spent"], f["rem"]])
	var budget: int = int(pz["budget"])
	var pick: Dictionary = fr[0]
	var bv := -99999
	for f in fr:
		var v: int = int(f["rem"]) + (budget - int(f["spent"])) * 100 / maxi(1, budget)
		if v > bv:
			bv = v
			pick = f
	var star3: int = int(pick["spent"])
	var star2: int = int(pick["rem"]) / 5 * 5 if int(pick["rem"]) >= 5 else maxi(1, int(pick["rem"]))   # 三星解剩不到 5% 時門檻就是它（不然三星拿不到）
	m["ticks"] = int(pick["ticks"])
	m["tol"] = tolerance(pz, pick)
	# 兩組標準解：三星解＋兵種組合不同的過關解（沒有就挑位置差最多的）
	var sols: Array = [pick["u"]]
	var plans: Array = [pick["p"]]
	var alt = null
	for f in found:
		if multiset(f["u"]) != multiset(pick["u"]):
			alt = f
			break
	if alt == null:
		for f in found:
			if JSON.stringify(f["u"]) != JSON.stringify(pick["u"]):
				alt = f
				break
	if alt != null:
		sols.append(alt["u"])
		plans.append(alt["p"])
	m["kinds"] = {}
	for f in found:
		m["kinds"][multiset(f["u"])] = true
	m["kinds"] = m["kinds"].size()
	# 主角必要：拿掉主角兵種再找一次
	if pz.has("unit") and allowed.size() > 1:
		var without: Array = allowed.filter(func(t): return t != int(pz["unit"]))
		var f2: Array = []
		climb(pz, without, iters / 2, 4242, f2)
		m["hero_free_ok"] = f2.size()
	var out := {"star2": star2, "star3": star3, "solutions": sols, "best": {"u": pick["u"], "p": pick["p"]}, "metrics": m}
	if pz.has("cmd"):
		out["sol_plans"] = plans
	return out

func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1]
	var drafts: Array = JSON.parse_string(FileAccess.get_file_as_string(str(args.get("in", ""))))
	var want := str(args.get("id", ""))
	var shard := int(args.get("shard", "0"))
	var shards := int(args.get("shards", "1"))
	for i in drafts.size():
		var pz: Dictionary = drafts[i]
		if (want != "" and pz["id"] != want) or (want == "" and i % shards != shard):
			continue
		pz["star2"] = 0
		pz["star3"] = 999
		var t0 := Time.get_ticks_msec()
		var res := forge(pz, int(args.get("iters", "1600")), int(args.get("seeds", "3")))
		res["id"] = pz["id"]
		res["ms"] = Time.get_ticks_msec() - t0
		print("FORGE ", JSON.stringify(res))
	quit()
