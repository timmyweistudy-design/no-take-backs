extends RefCounted
## 1.1.0 B2：雙人輪流落子紀錄碼（NTD1）。對戰碼（NTB*）只證明「最後陣型合法」，不證明輪序；
## 這個碼帶初始規則、先手、禁牌後的卡池、每一手落子，解碼時用 turn_placement.gd 逐手重放驗合法（照輪序、每手上限、
## 買得起就不能跳過、最後一手要戰鬥兵），全部合法才回傳兩軍。舊的對戰碼照舊拒絕 cmds。
## 格式：NTD1.<base64url(JSON)>.<校驗 6 碼>
## JSON：{v:1, rules: 規則碼或 "", pr: 輪流規則（cap10／snake5／snake5c）, f: 先手, p: [藍卡池, 紅卡池], ba, bb: 預算,
##        m: 落子紀錄（["g", 隊, 兵, 欄, 列, 手]＝格子一隻；["b", 隊, [[兵, x, y]…], 手]＝自由部署一批；["s", 隊, 手]＝沒位置被跳過）,
##        r: 規則版本, d: 數值摘要}

const Army = preload("res://scripts/core/army.gd")
const D = preload("res://scripts/core/unit_defs.gd")
const RSET = preload("res://scripts/core/ruleset.gd")
const TP = preload("res://scripts/core/turn_placement.gd")
const PREFIX := "NTD1"
const MAX_LEN := 12000
const MAX_MOVES := 120

## tp：打完擺陣的 turn_placement（用它的 commands、first、rule）；pools、budgets 是開局時（禁牌後）的值。
static func encode(tp, rules, pools: Array, budgets: Array) -> String:
	var m: Array = []
	for c in tp.commands:
		if c.get("skip", false):
			m.append(["s", int(c["team"]), int(c["turn"])])
		elif c.has("batch"):
			var b: Array = []
			for it in c["batch"]:
				b.append([int(it[0]), int(it[1]), int(it[2])])
			m.append(["b", int(c["team"]), b, int(c["turn"])])
		else:
			m.append(["g", int(c["team"]), int(c["type"]), int(c["col"]), int(c["row"]), int(c["turn"])])
	var j := JSON.stringify({"v": 1, "rules": rules.to_code() if rules != null else "", "pr": tp.rule, "f": tp.first,
		"p": [int(pools[0]), int(pools[1])], "ba": int(budgets[0]), "bb": int(budgets[1]), "m": m,
		"r": D.version_of(tp.armies), "d": D.digest_of(tp.armies)})
	var b64 := Marshalls.utf8_to_base64(j).replace("+", "-").replace("/", "_").replace("=", "")
	return "%s.%s.%s" % [PREFIX, b64, b64.sha256_text().substr(0, 6)]

static func _int_ok(x, lo: int, hi: int) -> bool:
	return (x is int or (x is float and float(x) == floorf(float(x)))) and int(x) >= lo and int(x) <= hi

## 回傳 {ok, why, a0, a1, rules, moves, mismatch}；why：format／checksum／body／rules／budget／pool／illegal（第幾手不合法）
static func decode(code: String) -> Dictionary:
	var c := code.strip_edges()
	var parts := c.split(".")
	if c.length() > MAX_LEN or parts.size() != 3 or parts[0] != PREFIX:
		return {"ok": false, "why": "format"}
	if parts[1].sha256_text().substr(0, 6) != parts[2]:
		return {"ok": false, "why": "checksum"}
	var b64 := parts[1].replace("-", "+").replace("_", "/")
	while b64.length() % 4 != 0:
		b64 += "="
	var j = JSON.parse_string(Marshalls.base64_to_utf8(b64))
	if not j is Dictionary or not _int_ok(j.get("v"), 1, 1) or not (j.get("rules", "") is String) or not (j.get("pr") is String) \
			or not _int_ok(j.get("f"), 0, 1) or not (j.get("p") is Array) or (j["p"] as Array).size() != 2 or not (j.get("m") is Array):
		return {"ok": false, "why": "body"}
	if not str(j["pr"]) in ["cap10", "snake5", "snake5c"]:
		return {"ok": false, "why": "body"}
	for k in ["ba", "bb"]:
		if not _int_ok(j.get(k), 1, 400):
			return {"ok": false, "why": "budget"}
	var full: int = RSET.full_pool()
	for pv in j["p"]:
		if not _int_ok(pv, 1, full) or (int(pv) & ~full) != 0 or not RSET.has_combat(int(pv)):
			return {"ok": false, "why": "pool"}
	var moves: Array = j["m"]
	if moves.is_empty() or moves.size() > MAX_MOVES:
		return {"ok": false, "why": "body"}
	var a0 := Army.new(0, int(j["ba"]))
	var a1 := Army.new(1, int(j["bb"]))
	var rules = null
	if str(j["rules"]) != "":
		var rd: Dictionary = RSET.from_code(str(j["rules"]))
		if not rd["ok"]:
			return {"ok": false, "why": "rules"}
		rules = rd["rules"]
		if rules.budget_of(0) != a0.budget or rules.budget_of(1) != a1.budget:
			return {"ok": false, "why": "budget"}
		a0.apply_rules(rules, 0)
		a1.apply_rules(rules, 1)
		if rules.pool_of(0) != int(j["p"][0]) or rules.pool_of(1) != int(j["p"][1]):
			return {"ok": false, "why": "pool"}   # 有規則時卡池（含禁牌）以規則碼為準，兩邊要一致
	elif a0.budget != 100 or a1.budget != 100:
		return {"ok": false, "why": "budget"}   # 沒有自訂規則＝標準 100 金
	var tp = TP.new(a0, a1, int(j["f"]), str(j["pr"]), rules)
	if rules == null:
		tp.armies[0].pool = int(j["p"][0])
		tp.armies[1].pool = int(j["p"][1])
	for i in moves.size():
		var mv = moves[i]
		if not _apply(tp, mv):
			return {"ok": false, "why": "illegal", "at": i}
	# 最後一手：玩家按「結束這一手」不會記成指令，補按到結束；按不下去（還買得起又沒擺）就是紀錄不完整
	for _k in 24:
		if tp.done():
			break
		if not tp.end_turn():
			return {"ok": false, "why": "illegal", "at": moves.size()}
	if not tp.done():
		return {"ok": false, "why": "illegal", "at": moves.size()}
	var mismatch: bool = str(j.get("r", "")) != D.version_of(tp.armies) or str(j.get("d", "")) != D.digest_of(tp.armies)
	return {"ok": true, "why": "", "a0": tp.armies[0], "a1": tp.armies[1], "rules": rules, "moves": moves.size(), "mismatch": mismatch}

## 套用一筆紀錄；先把輪序推到紀錄寫的那一手（中間的「結束這一手」不記），推不過去或隊伍不對就不合法。
static func _apply(tp, mv) -> bool:
	if not mv is Array or mv.is_empty() or not mv[0] is String:
		return false
	var kind: String = mv[0]
	var want: int = {"g": 6, "b": 4, "s": 3}.get(kind, -1)
	if want < 0 or mv.size() != want:
		return false
	var team = mv[1]
	var turn = mv[mv.size() - 1]
	if not _int_ok(team, 0, 1) or not _int_ok(turn, 0, 200):
		return false
	if kind == "s":
		# 被跳過是 turn_placement 自己記的（沒位置或買不起）：重放時它會自己發生，這裡只核對確實記過
		for c in tp.commands:
			if c.get("skip", false) and int(c["team"]) == int(team) and int(c["turn"]) == int(turn):
				return true
		return false
	for _k in 24:
		if tp.done():
			return false
		if tp.current == int(team) and tp.turn_index == int(turn):
			break
		if tp.is_snake() and tp.turn_index > int(turn):
			return false
		if not tp.end_turn():
			return false
	if tp.current != int(team) or tp.turn_index != int(turn):
		return false
	if kind == "g":
		for x in mv.slice(2, 5):
			if not _int_ok(x, 0, 100):
				return false
		if int(mv[2]) >= D.total():
			return false   # 不存在的兵種：先擋（D.cost 拿到界外編號會中斷）
		return tp.place(int(mv[2]), int(mv[3]), int(mv[4]))
	var items = mv[2]
	if not items is Array or (items as Array).is_empty() or (items as Array).size() > 40:
		return false
	var b: Array = []
	for it in items:
		if not it is Array or it.size() != 3 or not _int_ok(it[0], 0, D.total() - 1) or not _int_ok(it[1], -100000, 100000) or not _int_ok(it[2], -100000, 100000):
			return false
		b.append([int(it[0]), int(it[1]), int(it[2])])
	return tp.place_batch(b)
