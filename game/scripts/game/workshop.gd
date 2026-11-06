extends RefCounted
## V1.1 D3：殘局工坊碼 NTP1。打贏一場格子對戰 → 把敵陣＋自己的解做成殘局碼傳給朋友解。
## 作者的解就是「可解」的證明：匯入時先驗格式與合法性，再用殘局同一套判定（PZ.play）重跑作者解，要過關才收。
## 星數門檻＝作者的成績：剩餘戰力 ≥ 作者（2 星）、花費 ≤ 作者（3 星）。不寫進存檔、不算殘局進度。
## 格式：NTP1.<base64url(JSON {"v":1,"e":敵陣,"s":作者解,"a":可用兵種})>.<sha256 前 6 碼>；敵陣欄 10～15、解欄 0～5、列 0～8。

const PZ = preload("res://scripts/game/puzzles.gd")
const D = preload("res://scripts/core/unit_defs.gd")
const PREFIX := "NTP1"
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
static func encode(enemy: Array, sol: Array) -> String:
	var e := _clean(enemy, 10, 15)
	var s := _clean(sol, 0, 5)
	if e.is_empty() or s.is_empty():
		return ""
	var allowed: Array = []
	for u in s:
		if not int(u[0]) in allowed:
			allowed.append(int(u[0]))
	allowed.sort()
	var j := JSON.stringify({"v": 1, "e": e, "s": s, "a": allowed})
	var b := Marshalls.utf8_to_base64(j).replace("+", "-").replace("/", "_").replace("=", "")
	var code := "%s.%s.%s" % [PREFIX, b, b.sha256_text().substr(0, 6)]
	return code if bool(decode(code)["ok"]) else ""

## 解碼＋驗證＋重跑作者解。回傳 {ok, pz, sol, why}。
static func decode(code: String) -> Dictionary:
	var bad := {"ok": false, "why": "ws_bad"}
	code = code.strip_edges()
	var parts := code.split(".")
	if code.length() > MAX_LEN or parts.size() != 3 or parts[0] != PREFIX or parts[1].sha256_text().substr(0, 6) != parts[2]:
		return bad
	var b64 := parts[1].replace("-", "+").replace("_", "/")
	while b64.length() % 4 != 0:
		b64 += "="
	var j = JSON.parse_string(Marshalls.base64_to_utf8(b64))
	if not j is Dictionary or not _is_int(j.get("v"), 1, 1):   # Codex v110-impl2：先驗型別再轉，不能讓 {}、1.9 混進來
		return bad
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
	var pz := {"id": ID, "ch": 0, "zh": "工坊殘局", "en": "Workshop Puzzle",
		"hint_zh": "朋友打贏過這一關。用一樣的兵種、一樣多的錢，打得比他漂亮就是三星。",
		"hint_en": "A friend beat this one. Same units, same gold: beat their result for 3 stars.",
		"enemy": e, "fixed": [], "budget": spent, "allowed": allowed, "star2": 0, "star3": spent}
	var r: Dictionary = PZ.play(pz, s)
	if not bool(r.get("ok", false)):
		return {"ok": false, "why": "ws_unsolved"}
	pz["star2"] = int(r["rem"])
	pz["best"] = {"u": s, "p": []}
	return {"ok": true, "pz": pz, "sol": s, "why": ""}
