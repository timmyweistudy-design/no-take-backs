extends RefCounted
## 1.1.0 N5：殘局最佳解短碼（NTQ1）。「最佳」＝和實驗簿同一個排序：星數多 → 剩餘多 → 花費少（Career.better）。
## 碼裡只有關卡 id 和玩家擺的兵（不含固定兵）；匯入時驗關卡存在、兵合法（PZ.check_extra），然後打開那一關並擺好。
## 不是出題碼：不帶敵陣、不建新關卡；工坊題（ws）、教學不給碼。
const PZ = preload("res://scripts/game/puzzles.gd")
const PREFIX := "NTQ1"
const MAX_LEN := 4000

## plan：時序關卡（有軍令）的軍令計畫（PZ.default_plan 的格式）；沒有軍令的關給 []。
static func encode(pid: String, units: Array, plan: Array = []) -> String:
	var b := Marshalls.utf8_to_base64(JSON.stringify({"v": 1, "p": pid, "u": units, "c": plan})).replace("+", "-").replace("/", "_").replace("=", "")
	return "%s.%s.%s" % [PREFIX, b, b.sha256_text().substr(0, 6)]

static func decode(code: String) -> Dictionary:
	var bad := {"ok": false}
	code = code.strip_edges()
	var parts := code.split(".")
	if code.length() > MAX_LEN or parts.size() != 3 or parts[0] != PREFIX or parts[1].sha256_text().substr(0, 6) != parts[2]:
		return bad
	var b64 := parts[1].replace("-", "+").replace("_", "/")
	while b64.length() % 4 != 0:
		b64 += "="
	var j = JSON.parse_string(Marshalls.base64_to_utf8(b64))
	if not j is Dictionary or not (j.get("p") is String) or not (j.get("u") is Array) or not _int_like(j.get("v")) or int(j["v"]) != 1:
		return bad
	var pid: String = j["p"]
	if pid == "ws":
		return bad
	var pz := PZ.get_puzzle(pid)
	if pz.is_empty() or bool(pz.get("tutorial", false)):
		return bad
	var u: Array = []
	for e in j["u"]:
		if not (e is Array) or e.size() != 3:
			return bad
		for x in e:
			if not _int_like(x):
				return bad
		u.append([int(e[0]), int(e[1]), int(e[2])])
	if u.is_empty() or u.size() > 40 or PZ.check_extra(pz, u) != "":
		return bad
	var plan: Array = []
	var c = j.get("c", [])
	if pz.has("cmd"):
		if not (c is Array) or (c as Array).size() > 64:
			return bad
		for x in c:
			if not _int_like(x) or int(x) < 0:
				return bad
			plan.append(int(x))
		if not plan_legal(pz, plan):
			return bad
	return {"ok": true, "pid": pid, "u": u, "plan": plan}

static func _int_like(x) -> bool:
	return (x is int) or (x is float and float(x) == floorf(float(x)))

## 1.1.0（Codex v110-i2 #1）：軍令合法＝數量、每種技能的次數和這關預設一樣，而且套用遊戲面板的限制（開場、冷卻、局長）後不變
static func plan_legal(pz: Dictionary, plan: Array) -> bool:
	var dp := PZ.default_plan(pz)
	if plan.size() != dp.size():
		return false
	var a: Array = plan.map(func(e): return PZ.plan_skill(pz, int(e)))
	var b: Array = dp.map(func(e): return PZ.plan_skill(pz, int(e)))
	a.sort()
	b.sort()
	if a != b:
		return false
	var lo0: int = maxi(PZ.CMD.START_TICKS, int(pz.get("plan_min", 0)))
	var lim: int = int(pz.get("goal_ticks", 1800)) - 10
	for e in plan:
		var t := PZ.plan_tick(pz, int(e))
		if t < lo0 or t > lim:
			return false   # plan_fix 擠不下時會原樣退回，範圍要自己查
	return PZ.plan_fix(pz, plan, -1, 0) == plan

## 這一場比存的好就換（純函式：回傳新的紀錄字典，沒變回原本的）
static func merge(best: Dictionary, pid: String, stars: int, rem: int, spent: int, units: Array, plan: Array = []) -> Dictionary:
	var old: Dictionary = best.get(pid, {})
	var Career = load("res://scripts/game/career.gd")
	if not old.is_empty() and not Career.better([stars, rem, spent], old.get("r", [])):
		return best
	best[pid] = {"r": [stars, rem, spent], "u": units.duplicate(true), "c": plan.duplicate()}
	return best
