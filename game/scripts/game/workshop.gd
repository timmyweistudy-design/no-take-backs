extends RefCounted
## V1.1 D3：殘局工坊碼 NTP1。打贏一場格子對戰 → 把敵陣＋自己的解做成殘局碼傳給朋友解。
## 作者的解就是「可解」的證明：匯入時先驗格式與合法性，再用殘局同一套判定（PZ.play）重跑作者解，要過關才收。
## 星數門檻＝作者的成績：剩餘戰力 ≥ 作者（2 星）、花費 ≤ 作者（3 星）。不寫進存檔、不算殘局進度。
## 格式：NTP1.<base64url(JSON {"v":1,"e":敵陣,"s":作者解,"a":可用兵種})>.<sha256 前 6 碼>；敵陣欄 10～15、解欄 0～5、列 0～8。

const PZ = preload("res://scripts/game/puzzles.gd")
const L = preload("res://scripts/game/strings.gd")
const D = preload("res://scripts/core/unit_defs.gd")
const PREFIX := "NTP1"
const PREFIX2 := "NTP2"   # V1.4 #5 接力殘局：多一欄「第幾棒」n（1～99）；NTP1 照舊能用（n＝0）
const PREFIX3 := "NTP3"   # V1.6 #16 出題台：多一欄目標 g（win／kill／survive／draw／margin）與參數；NTP1、NTP2 照舊
const GOALS3 := ["win", "kill", "survive", "draw", "margin", "protect", "flawless"]
const PREFIX4 := "NTP4"   # V1.6.1 A2：出題台作者自己指定目標（多一欄 t＝[欄, 列]：斬首＝敵兵、護送＝己兵、完美＝那隻兵的兵種）；NTP1～3 照舊
const PICK_GOALS := ["kill", "protect", "flawless"]
const ED_GOALS := ["win", "kill", "survive", "draw", "margin", "protect", "flawless", "trio"]   # 出題台的目標（V1.6.1 D2 多一種：一陣三考）
const Trio = preload("res://scripts/game/trio.gd")
const MAX_UNITS := 40
const MAX_LEN := 6000
const ID := "ws"

## 是整數（JSON 讀回是浮點）而且在 [lo, hi] 內。
static func _is_int(v, lo: int, hi: int) -> bool:
	if not (v is int or v is float):
		return false
	var f := float(v)
	return f == floorf(f) and f >= lo and f <= hi

static func _clean(list, c0: int, c1: int) -> Array:
	if not list is Array or list.is_empty() or list.size() > MAX_UNITS:
		return []
	var out: Array = []
	var seen := {}
	for e in list:
		if not e is Array or e.size() != 3:
			return []
		for v in e:
			if not (v is int or v is float) or float(v) != floorf(float(v)):
				return []
		var t := int(e[0])
		var c := int(e[1])
		var r := int(e[2])
		if t < 0 or t >= D.total() or c < c0 or c > c1 or r < 0 or r >= 9:
			return []
		var key := c * 16 + r
		if seen.has(key):
			return []
		seen[key] = true
		out.append([t, c, r])
	return out

## 把一場打贏的格子對戰做成殘局碼。enemy／sol＝[[兵種, 欄, 列], ...]（敵陣用絕對欄 10～15）。
## 先用殘局規則重跑一次，作者解在殘局規則下也要贏才給碼（對戰可能用了不同局長等規則）。不合格回 ""。
static func encode(enemy: Array, sol: Array, n := 0) -> String:
	var e := _clean(enemy, 10, 15)
	var s := _clean(sol, 0, 5)
	if e.is_empty() or s.is_empty():
		return ""
	var allowed: Array = []
	for u in s:
		if not int(u[0]) in allowed:
			allowed.append(int(u[0]))
	allowed.sort()
	var body := {"v": 1, "e": e, "s": s, "a": allowed}
	if n > 0:
		body = {"v": 2, "e": e, "s": s, "a": allowed, "n": clampi(n, 1, 99)}
	var j := JSON.stringify(body)
	var b := Marshalls.utf8_to_base64(j).replace("+", "-").replace("/", "_").replace("=", "")
	var code := "%s.%s.%s" % [PREFIX2 if n > 0 else PREFIX, b, b.sha256_text().substr(0, 6)]
	return code if bool(decode(code)["ok"]) else ""

## V1.6 #16：出題台的碼。goal＝GOALS3 之一；kill 的目標＝最貴的敵兵（同價取欄、列最小），survive 30 秒、draw 60 秒、margin 剩 50%。
static func encode3(enemy: Array, sol: Array, goal: String) -> String:
	var e := _clean(enemy, 10, 15)
	var s := _clean(sol, 0, 5)
	if e.is_empty() or s.is_empty() or not goal in GOALS3:
		return ""
	var allowed: Array = []
	for u in s:
		if not int(u[0]) in allowed:
			allowed.append(int(u[0]))
	allowed.sort()
	var j := JSON.stringify({"v": 3, "e": e, "s": s, "a": allowed, "g": goal})
	var b := Marshalls.utf8_to_base64(j).replace("+", "-").replace("/", "_").replace("=", "")
	var code := "%s.%s.%s" % [PREFIX3, b, b.sha256_text().substr(0, 6)]
	return code if bool(decode(code)["ok"]) else ""

## V1.6.1 A2：作者點了目標（t＝[欄, 列]）就出 NTP4；沒點照舊出 NTP3（自動選）。
static func encode4(enemy: Array, sol: Array, goal: String, t: Vector2i) -> String:
	if not goal in PICK_GOALS or t.x < 0:
		return encode3(enemy, sol, goal)
	var e := _clean(enemy, 10, 15)
	var s := _clean(sol, 0, 5)
	if e.is_empty() or s.is_empty() or pick_fields(goal, e, s, [t.x, t.y]).is_empty():
		return ""
	var allowed: Array = []
	for u in s:
		if not int(u[0]) in allowed:
			allowed.append(int(u[0]))
	allowed.sort()
	var j := JSON.stringify({"v": 4, "e": e, "s": s, "a": allowed, "g": goal, "t": [t.x, t.y]})
	var b := Marshalls.utf8_to_base64(j).replace("+", "-").replace("/", "_").replace("=", "")
	var code := "%s.%s.%s" % [PREFIX4, b, b.sha256_text().substr(0, 6)]
	return code if bool(decode(code)["ok"]) else ""

## V1.6.1 D2：出題台出「一陣三考」題：三支敵陣＋作者解（要三場都贏才給碼）。NTP4，g＝"trio"、e3＝三支敵陣。
static func encode_trio(foes: Array, sol: Array) -> String:
	if foes.size() != 3:
		return ""
	var e3: Array = []
	for f in foes:
		var e := _clean(f, 10, 15)
		if e.is_empty():
			return ""
		e3.append(e)
	var s := _clean(sol, 0, 5)
	if s.is_empty():
		return ""
	var allowed: Array = []
	for u in s:
		if not int(u[0]) in allowed:
			allowed.append(int(u[0]))
	allowed.sort()
	var j := JSON.stringify({"v": 4, "e": e3[0], "e3": e3, "s": s, "a": allowed, "g": "trio"})
	var b := Marshalls.utf8_to_base64(j).replace("+", "-").replace("/", "_").replace("=", "")
	var code := "%s.%s.%s" % [PREFIX4, b, b.sha256_text().substr(0, 6)]
	return code if bool(decode(code)["ok"]) else ""

## 三考碼解出來的題組（和 data/trio.json 同格式；id＝碼的雜湊）
static func trio_set_of(j: Dictionary, s: Array, allowed: Array) -> Dictionary:
	var e3 = j.get("e3")
	if not e3 is Array or e3.size() != 3:
		return {}
	var foes: Array = []
	for f in e3:
		var e := _clean(f, 10, 15)
		if e.is_empty():
			return {}
		foes.append(e)
	var spent := 0
	for u in s:
		spent += D.cost(int(u[0]))
	var al2: Array = allowed.duplicate()
	al2.sort()
	return {"id": "c" + JSON.stringify([foes, spent, al2]).md5_text().substr(0, 12), "budget": spent, "allowed": allowed, "foes": foes, "sol": s}   # 身分含預算與可用兵種（Codex v161-i1 #7）

## 指定的目標要真的有那隻兵（斬首在敵陣、護送與完美在作者解）；不對回 {}。
static func pick_fields(goal: String, e: Array, s: Array, t) -> Dictionary:
	if not t is Array or t.size() != 2 or not _is_int(t[0], 0, 15) or not _is_int(t[1], 0, 8):
		return {}
	var lst: Array = e if goal == "kill" else s
	for u in lst:
		if int(u[1]) == int(t[0]) and int(u[2]) == int(t[1]):
			match goal:
				"kill":
					return {"goal": "kill", "goal_unit": [int(u[1]), int(u[2])]}
				"protect":
					return {"goal": "protect", "goal_unit": [int(u[1]), int(u[2])], "fixed": [[int(u[0]), int(u[1]), int(u[2])]]}
				"flawless":
					return {"goal": "flawless", "goal_type": int(u[0]), "need_type": true}
	return {}

## 目標的細節（解碼時從敵陣、作者解算，不吃碼裡的數字：少一個能被竄改的欄位）
## protect：作者解裡最貴的兵（同價取欄、列最小）變成固定兵，要活到最後；flawless：作者解裡最多的兵種一隻都不能倒
static func goal_fields(goal: String, e: Array, s: Array = []) -> Dictionary:
	match goal:
		"protect":
			var pb: Array = s[0]
			for u in s:
				if D.cost(int(u[0])) > D.cost(int(pb[0])) or (D.cost(int(u[0])) == D.cost(int(pb[0])) and (int(u[1]) * 16 + int(u[2])) < (int(pb[1]) * 16 + int(pb[2]))):
					pb = u
			return {"goal": "protect", "goal_unit": [int(pb[1]), int(pb[2])], "fixed": [[int(pb[0]), int(pb[1]), int(pb[2])]]}
		"flawless":
			var cnt := {}
			for u in s:
				cnt[int(u[0])] = int(cnt.get(int(u[0]), 0)) + 1
			var bt := int(s[0][0])
			for t in cnt:
				if int(cnt[t]) > int(cnt[bt]) or (int(cnt[t]) == int(cnt[bt]) and int(t) < bt):
					bt = int(t)
			return {"goal": "flawless", "goal_type": bt, "need_type": true}
		"kill":
			var best: Array = e[0]
			for u in e:
				if D.cost(int(u[0])) > D.cost(int(best[0])) or (D.cost(int(u[0])) == D.cost(int(best[0])) and (int(u[1]) * 16 + int(u[2])) < (int(best[1]) * 16 + int(best[2]))):
					best = u
			return {"goal": "kill", "goal_unit": [int(best[1]), int(best[2])]}
		"survive":
			return {"goal": "survive", "goal_ticks": 600}
		"draw":
			return {"goal": "draw", "goal_ticks": 1200}
		"margin":
			return {"goal": "margin", "goal_rem": 50}
	return {}

## 解碼＋驗證＋重跑作者解。回傳 {ok, pz, sol, why}。
## V1.0.0 M15：重跑作者解有期限（SOLVE_MS，三考三場合計 3 倍），超過回 ws_slow。
const SOLVE_MS := 8000
## ctl：背景驗證用（{"stop", "until"}，見 PZ.play）；沒給就用 SOLVE_MS 自己的期限。
static func decode(code: String, ctl := {}) -> Dictionary:
	var bad := {"ok": false, "why": "ws_bad"}
	code = code.strip_edges()
	var parts := code.split(".")
	if code.length() > MAX_LEN or parts.size() != 3 or not (parts[0] in [PREFIX, PREFIX2, PREFIX3, PREFIX4]) or parts[1].sha256_text().substr(0, 6) != parts[2]:
		return bad
	var b64 := parts[1].replace("-", "+").replace("_", "/")
	while b64.length() % 4 != 0:
		b64 += "="
	var j = JSON.parse_string(Marshalls.base64_to_utf8(b64))
	var v2 := parts[0] == PREFIX2
	var vv := 4 if parts[0] == PREFIX4 else (3 if parts[0] == PREFIX3 else (2 if v2 else 1))
	if not j is Dictionary or not _is_int(j.get("v"), vv, vv):   # Codex v110-impl2：先驗型別再轉，不能讓 {}、1.9 混進來
		return bad
	var relay := 0
	if v2:
		if not _is_int(j.get("n"), 1, 99):
			return bad
		relay = int(j["n"])
	var e := _clean(j.get("e"), 10, 15)
	var s := _clean(j.get("s"), 0, 5)
	if e.is_empty() or s.is_empty() or not j.get("a") is Array:
		return bad
	var allowed: Array = []
	if j["a"].is_empty() or j["a"].size() > D.total():
		return bad
	for t in j["a"]:
		if not _is_int(t, 0, D.total() - 1) or int(t) in allowed:
			return bad
		allowed.append(int(t))
	var spent := 0
	for u in s:
		if not int(u[0]) in allowed:
			return bad
		spent += D.cost(int(u[0]))
	if spent > 200:
		return bad
	var pz := {"id": ID, "ch": 0, "relay": relay,
		"enemy": e, "fixed": [], "budget": spent, "allowed": allowed, "star2": 0, "star3": spent}
	if relay == 0:
		L.fill(pz, "", "ws_pz_name")
	else:
		L.fill(pz, "", "rl_title", [relay])
	L.fill(pz, "hint", "ws_pz_hint")   # V1.6.1 F6：四種語言都從字串表來
	if vv == 4 and j.get("g") == "trio":
		var ts := trio_set_of(j, s, allowed)
		if ts.is_empty():
			return bad
		var tr := Trio.results(ts, s, 0, ctl if not ctl.is_empty() else {"stop": false, "until": Time.get_ticks_msec() + SOLVE_MS * 3})
		if tr.is_empty():
			return {"ok": false, "why": "ws_slow"}
		if Trio.stars(ts, tr) < 1:
			return {"ok": false, "why": "ws_unsolved"}
		return {"ok": true, "pz": Trio.make_pz(ts, 0), "sol": s, "trio": ts, "why": ""}
	if vv >= 3:
		var g = j.get("g")
		if not g is String or not g in GOALS3 or (vv == 4 and not g in PICK_GOALS):
			return bad
		var gf := goal_fields(g, e, s) if vv == 3 else pick_fields(g, e, s, j.get("t"))
		if vv == 4 and gf.is_empty():
			return bad   # 指定的目標不存在（「打贏」的 NTP3 本來就沒有目標欄位）
		pz.merge(gf, true)
		if gf.has("fixed"):
			# 護送：被護送的兵是固定兵，解題的人擺其他的；作者解扣掉它、預算也扣掉它的錢
			var fx: Array = gf["fixed"][0]
			s = s.filter(func(u): return not (int(u[1]) == int(fx[1]) and int(u[2]) == int(fx[2])))
			pz["budget"] = int(pz["budget"]) - D.cost(int(fx[0]))
			pz["star3"] = int(pz["budget"])
		L.fill(pz, "", "wb_pz_name")
		L.fill(pz, "hint", "wb_pz_hint")
	var r: Dictionary = PZ.play(pz, s, [], true, ctl if not ctl.is_empty() else {"stop": false, "until": Time.get_ticks_msec() + SOLVE_MS})
	if bool(r.get("cancel", false)):
		return {"ok": false, "why": "ws_slow"}   # V1.0.0 M15：作者解跑太久（壞碼或刻意卡住）就不收
	if not bool(r.get("ok", false)):
		return {"ok": false, "why": "ws_unsolved"}
	pz["star2"] = int(r["rem"])
	pz["best"] = {"u": s, "p": []}
	return {"ok": true, "pz": pz, "sol": s, "why": ""}
