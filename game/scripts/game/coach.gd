extends RefCounted
## V1.6 #9 差一子教練：輸了之後，只改一隻兵有沒有能翻盤的擺法。純函式（可在背景執行緒跑）；殘局用同一個判定（puzzles.gd outcome）。
## V1.6.1 A5／F5（三方 v161d §0-4）：
##  - 候選：移位最多 MOVES 個（格子＝前後上下一格；自由部署＝8 方向半格）＋同價換兵最多 SWAPS 個；移位不夠時換兵補滿 LIMIT。
##  - 每 64 tick 看一次「取消／期限」（ctl），總上限 TIME_MS；取消回應在一場模擬的 64 tick 內。
##  - 結果分清楚：found（找到）、exhausted（這一類改法全試過都不行）、budget（候選用完，還有沒試的）、timeout（時間到）、cancel。不說「無解」。
const Army = preload("res://scripts/core/army.gd")
const Sim = preload("res://scripts/core/battle_sim.gd")
const PZ = preload("res://scripts/game/puzzles.gd")
const D = preload("res://scripts/core/unit_defs.gd")

const LIMIT := 32
const MOVES := 20
const SWAPS := 12
const TIME_MS := 6000
const FREE_STEP := 500   # 自由部署移半格
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(0, 1)]   # 自己視角：前、後、上、下
const DIRS8 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(-1, 1)]

## 前排先（往敵方的方向排），同排照原本順序
static func _order(a: Army) -> Array:
	var idx: Array = range(a.units.size())
	var fwd := 1 if a.team == 0 else -1
	idx.sort_custom(func(p, q):
		var cp: int = Army.pos_of(a.units[p]).x * fwd
		var cq: int = Army.pos_of(a.units[q]).x * fwd
		return cp > cq if cp != cq else p < q)
	return idx

static func _fixed(pz: Dictionary, u: Dictionary) -> bool:
	return not pz.is_empty() and u.has("col") and PZ.is_fixed(pz, int(u["col"]), int(u["row"]))

## 移位候選：["m", 第幾隻, 新欄, 新列]（格子）／["x", 第幾隻, 新 x, 新 y]（自由）。照「方向優先、前排先」的固定順序。
static func move_cands(a: Army, pz := {}) -> Array:
	var idx := _order(a)
	var fwd := 1 if a.team == 0 else -1
	var free := a.deploy == "free"
	var out: Array = []
	for d in (DIRS8 if free else DIRS):
		for i in idx:
			var u: Dictionary = a.units[i]
			if _fixed(pz, u):
				continue
			if free:
				var nx: int = int(u["x"]) + int(d.x) * fwd * FREE_STEP
				var ny: int = int(u["y"]) + int(d.y) * FREE_STEP
				if a.check_place_xy(int(u["type"]), nx, ny, i) == "":
					out.append(["x", i, nx, ny])
			else:
				var nc: int = int(u["col"]) + int(d.x) * fwd
				var nr: int = int(u["row"]) + int(d.y)
				var b: Army = a.copy()
				b.units.remove_at(i)
				if b.check_place(int(u["type"]), nc, nr) == "":
					out.append(["m", i, nc, nr])
	return out

## 同價換兵候選：["s", 第幾隻, 新兵種]。殘局只換這關允許的兵種；照前排先、兵種編號小的先。
static func swap_cands(a: Army, pz := {}) -> Array:
	var allowed: Array = []
	for v in pz.get("allowed", []):
		allowed.append(int(v))
	var out: Array = []
	for i in _order(a):
		var u: Dictionary = a.units[i]
		if _fixed(pz, u):
			continue
		var t := int(u["type"])
		for t2 in D.total():
			if t2 == t or D.cost(t2) != D.cost(t) or (not allowed.is_empty() and not t2 in allowed):
				continue
			var b: Army = a.copy()
			b.units.remove_at(i)
			var p := Army.pos_of(u)
			var why: String = b.check_place_xy(t2, p.x, p.y) if a.deploy == "free" else b.check_place(t2, int(u["col"]), int(u["row"]))
			if why == "":
				out.append(["s", i, t2])
	return out

## 這次要試的候選（移位最多 MOVES、換兵最多 SWAPS，移位不夠時換兵補到 LIMIT）＋全部合法候選有幾個
static func plan(a: Army, pz := {}, limit := LIMIT) -> Dictionary:
	var mv := move_cands(a, pz)
	var sw := swap_cands(a, pz)
	var nm := mini(mv.size(), mini(MOVES, limit))
	var ns := mini(sw.size(), limit - nm)
	return {"list": mv.slice(0, nm) + sw.slice(0, ns), "total": mv.size() + sw.size()}

## 舊介面（V1.6 測試用）：格子移位候選照舊回 [第幾隻, 新欄, 新列]
static func candidates(a: Army, pz := {}) -> Array:
	return move_cands(a, pz).map(func(c): return [c[1], c[2], c[3]] if c[0] == "m" else c)

static func moved(a: Army, cand: Array) -> Army:
	var b: Army = a.copy()
	var i := int(cand[1]) if cand[0] is String else int(cand[0])
	var u: Dictionary = b.units[i].duplicate()
	b.units.remove_at(i)
	if not cand[0] is String or cand[0] == "m":
		var o := 1 if cand[0] is String else 0
		u["col"] = int(cand[o + 1])
		u["row"] = int(cand[o + 2])
	elif cand[0] == "x":
		u["x"] = int(cand[2])
		u["y"] = int(cand[3])
	else:
		u["type"] = int(cand[2])
	b.units.append(u)
	return b

static func _stop(ctl: Dictionary) -> bool:
	return bool(ctl.get("stop", false)) or (int(ctl.get("until", 0)) > 0 and Time.get_ticks_msec() > int(ctl["until"]))

## 1＝贏、0＝沒贏、-1＝中途被取消或時間到
static func play(a0: Army, a1: Army, rules, pz: Dictionary, ctl := {}) -> int:
	var s = Sim.new(a0.copy(), a1.copy(), rules)
	s.fast = true
	while not s.finished:
		s.step()
		if s.tick & 63 == 0 and _stop(ctl):
			return -1
	if pz.is_empty():
		return 1 if s.winner == 0 else 0
	return 1 if bool(PZ.outcome(pz, s, 0)["ok"]) else 0

## 1.2.0 §11.4 教練解釋證據：同一組敵陣，改之前與改之後各跑一場，回傳
## {"dmg0": [前, 後], "dmg1": [前, 後], "alive0": [前, 後], "first": [前, 後]（第一隻倒下的 tick，-1＝沒人倒）, "top": [[兵種, 傷害], …]（改之後我方傷害前兩名）}。
## 只描述「這一場這樣改的結果」，畫面不說因果。
static func evidence(before: Army, after: Army, a1: Army, rules, ctl := {}) -> Dictionary:
	var r0 := _ev_run(before, a1, rules, ctl)
	if r0.is_empty():
		return {}
	var r1 := _ev_run(after, a1, rules, ctl)
	if r1.is_empty() or _stop(ctl):
		return {}
	return {"dmg0": [r0["dmg0"], r1["dmg0"]], "dmg1": [r0["dmg1"], r1["dmg1"]], "alive0": [r0["alive0"], r1["alive0"]], "first": [r0["first"], r1["first"]], "top": r1["top"]}

static func _ev_run(a0: Army, a1: Army, rules, ctl: Dictionary) -> Dictionary:
	if _stop(ctl):
		return {}   # 每場開始前就看取消／期限（短戰可能不到 64 tick；Codex cat08 #4）
	var s = Sim.new(a0.copy(), a1.copy(), rules)
	s.fast = true
	var first := -1
	while not s.finished:
		s.step()
		if first < 0:
			for e in s.events:
				if str(e.get("kind", "")) == "death":
					first = s.tick
					break
		if s.tick & 63 == 0 and _stop(ctl):
			return {}
	var d := [0, 0]
	var alive0 := 0
	var per: Array = []
	for u in s.units:
		d[u.team] += u.dmg_dealt
		if u.team == 0:
			if u.alive and not u.summon:
				alive0 += 1
			if not u.summon:
				per.append([u.type, u.dmg_dealt, u.id])
	per.sort_custom(func(p, q): return p[1] > q[1] if p[1] != q[1] else p[2] < q[2])
	var top: Array = []
	for k in mini(2, per.size()):
		top.append([per[k][0], per[k][1]])
	return {"dmg0": d[0], "dmg1": d[1], "alive0": alive0, "first": first, "top": top}

static func wins(a0: Army, a1: Army, rules, pz: Dictionary) -> bool:
	return play(a0, a1, rules, pz) == 1

## 能不能給教練：沒有軍令（殘局的定時技能、手動技能局都不做）。V1.6.1 起自由部署也做。
static func supported(a0: Army, rules, pz: Dictionary) -> bool:
	if a0.units.is_empty():
		return false
	if not pz.is_empty() and pz.has("cmd"):
		return false
	return rules == null or int(rules.cmd_mask[0]) == 0

## 回傳 {"found", "status", "tries", "total", "kind"("move"/"swap"), "i", "type", "to_type", "from", "to", "army"}
## ctl：{"stop": bool, "until": 毫秒期限, "done": 已試幾個}（背景執行緒共用；主執行緒只寫 stop）
static func search(a0: Army, a1: Army, rules, pz := {}, limit := LIMIT, ctl := {}) -> Dictionary:
	if not ctl.has("until"):
		ctl["until"] = Time.get_ticks_msec() + TIME_MS
	var pl := plan(a0, pz, limit)
	var lst: Array = pl["list"]
	var tries := 0
	for cand in lst:
		if _stop(ctl):
			return {"found": false, "status": "cancel" if bool(ctl.get("stop", false)) else "timeout", "tries": tries, "total": int(pl["total"])}
		var b := moved(a0, cand)
		var r := play(b, a1, rules, pz, ctl)
		if r < 0:
			return {"found": false, "status": "cancel" if bool(ctl.get("stop", false)) else "timeout", "tries": tries, "total": int(pl["total"])}
		tries += 1
		ctl["done"] = tries
		if r == 1:
			var i := int(cand[1])
			var u: Dictionary = a0.units[i]
			var p0 := Army.pos_of(u)
			var p1 := Army.pos_of(b.units[b.units.size() - 1])
			var grid := u.has("col")
			var ev := evidence(a0, b, a1, rules, ctl)   # 1.2.0 §11.4
			if ev.is_empty() and _stop(ctl):
				return {"found": false, "status": "cancel" if bool(ctl.get("stop", false)) else "timeout", "tries": tries, "total": int(pl["total"])}   # 證據跑到一半被取消／逾時：不能當成找到（不快取；Codex cat08 #4）
			return {"found": true, "status": "found", "tries": tries, "total": int(pl["total"]), "kind": "swap" if cand[0] == "s" else "move",
				"i": i, "type": int(u["type"]), "to_type": int(cand[2]) if cand[0] == "s" else int(u["type"]),
				"from": Vector2i(int(u["col"]), int(u["row"])) if grid else p0,
				"to": Vector2i(int(cand[2]), int(cand[3])) if cand[0] == "m" else (p1 if not grid else Vector2i(int(u["col"]), int(u["row"]))),
				"grid": grid, "army": b, "ev": ev}
	return {"found": false, "status": "exhausted" if lst.size() >= int(pl["total"]) else "budget", "tries": tries, "total": int(pl["total"])}
