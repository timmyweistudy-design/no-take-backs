extends RefCounted
## 1.1.0 N5：殘局最佳解短碼（NTQ1）。「最佳」＝和實驗簿同一個排序：星數多 → 剩餘多 → 花費少（Career.better）。
## 碼裡只有關卡 id 和玩家擺的兵（不含固定兵）；匯入時驗關卡存在、兵合法（PZ.check_extra），然後打開那一關並擺好。
## 不是出題碼：不帶敵陣、不建新關卡；工坊題（ws）、教學不給碼。
const PZ = preload("res://scripts/game/puzzles.gd")
const PREFIX := "NTQ1"
const MAX_LEN := 4000

static func encode(pid: String, units: Array) -> String:
	var b := Marshalls.utf8_to_base64(JSON.stringify({"v": 1, "p": pid, "u": units})).replace("+", "-").replace("/", "_").replace("=", "")
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
	if not j is Dictionary or not (j.get("p") is String) or not (j.get("u") is Array):
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
			if not (x is int or x is float) or float(x) != floorf(float(x)):
				return bad
		u.append([int(e[0]), int(e[1]), int(e[2])])
	if u.is_empty() or u.size() > 40 or PZ.check_extra(pz, u) != "":
		return bad
	return {"ok": true, "pid": pid, "u": u}

## 這一場比存的好就換（純函式：回傳新的紀錄字典，沒變回原本的）
static func merge(best: Dictionary, pid: String, stars: int, rem: int, spent: int, units: Array) -> Dictionary:
	var old: Dictionary = best.get(pid, {})
	var Career = load("res://scripts/game/v16_career.gd")
	if not old.is_empty() and not Career.better([stars, rem, spent], old.get("r", [])):
		return best
	best[pid] = {"r": [stars, rem, spent], "u": units.duplicate(true)}
	return best
