extends RefCounted
## V1.6 #17 一陣三考：同一套格子陣分別迎戰三支敵陣（每場都滿血），三場都贏才過。題組 data/trio.json（tools/gen/trio_forge.gd）。
const PZ = preload("res://scripts/game/puzzles.gd")
const L = preload("res://scripts/game/strings.gd")
static var _sets: Array = []

static func sets() -> Array:
	if _sets.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/trio.json"))
		if d is Dictionary:
			_sets = d.get("sets", [])
	return _sets

## 第 k 支敵陣做成一題（工坊殘局的格式：puzzle_id "ws"，不存殘局星數）
static func make_pz(s: Dictionary, k: int) -> Dictionary:
	var pz := {"id": "ws", "ch": 0, "trio": str(s["id"]), "relay": 0,
		"enemy": s["foes"][k], "fixed": [], "budget": int(s["budget"]), "allowed": s["allowed"], "star2": 0, "star3": int(s["budget"])}
	L.fill(pz, "", "trio_pz_name")   # V1.6.1 F6
	L.fill(pz, "hint", "trio_pz_hint")
	return pz

## 三場的結果：[過關?, …]（不合法的擺法全部算 false）
static func check(s: Dictionary, extra: Array) -> Array:
	var out: Array = []
	for k in 3:
		out.append(bool(PZ.play(make_pz(s, k), extra).get("ok", false)))
	return out

## ── V1.6.1 A3／F7：三場的完整結果與整組星數（三方 v161d §0-3） ──
## 三勝＝1 星；三場剩餘戰力平均（同一支陣、起始戰力相同，平均＝總和÷總和）≥ S2＝2 星；再加花費÷預算 ≤ S3%＝3 星。
## 題組可在 trio.json 單組覆寫（"s2"、"s3"），條件是作者解 sol 要同時達到（tools/gen/trio_stars.gd 驗證、測試釘住）。
const S2 := 45
const S3 := 88

static func play_one(s: Dictionary, k: int, extra: Array, ctl := {}) -> Dictionary:
	var r: Dictionary = PZ.play(make_pz(s, k), extra, [], true, ctl)
	if bool(r.get("cancel", false)):
		return {"cancel": true}
	return {"ok": bool(r.get("ok", false)), "rem": int(r.get("rem", 0)), "spent": int(r.get("spent", 0))}

## ctl：見 PZ.play。被取消或逾時回 []（呼叫端不寫紀錄）。
static func results(s: Dictionary, extra: Array, from := 0, ctl := {}) -> Array:
	var out: Array = []
	for k in range(from, 3):
		var r := play_one(s, k, extra, ctl)
		if r.has("cancel"):
			return []
		out.append(r)
		if ctl.has("total"):
			ctl["done"] = out.size()   # 1.1.0 N6：進度（場數，上限已知）
	return out

static func s2_of(s: Dictionary) -> int:
	return int(s.get("s2", S2))

static func s3_of(s: Dictionary) -> int:
	return int(s.get("s3", S3))

static func rem_avg(res: Array) -> int:
	var t := 0
	for r in res:
		t += int(r["rem"])
	return t / maxi(1, res.size())

static func spent_pct(s: Dictionary, res: Array) -> int:
	return int(res[0]["spent"]) * 100 / maxi(1, int(s["budget"])) if not res.is_empty() else 100

static func stars(s: Dictionary, res: Array) -> int:
	if res.size() != 3 or res.any(func(r): return not bool(r["ok"])):
		return 0
	var st := 1
	var rsum := 0
	for r in res:
		rsum += int(r["rem"])
	if rsum >= s2_of(s) * res.size():   # 平均 ≥ 門檻，用總和比，不先取整（Codex v161-i1 #10）
		st = 2
		if int(res[0]["spent"]) * 100 <= s3_of(s) * maxi(1, int(s["budget"])):   # 花費 ≤ 門檻%：交叉相乘，不截斷
			st = 3
	return st
