extends RefCounted
## 1.2.0 §11.8 名局棋譜本：把重播碼（對戰代碼）收成冊，最多 MAX 筆（新的在前，滿了丟最舊的）。
## 每筆 {"c": 代碼, "n": 標題（日期＋結果）, "note": 老闆批註（這場的關鍵時刻）, "t": 收進來的時間}。純資料。
const MAX := 6
const CODE_MAX := 6000

static func add(book: Array, code: String, title: String, note: String, now: int) -> Array:
	var out: Array = []
	for e in book:
		if e is Dictionary and str(e.get("c", "")) != code:
			out.append(e)
	out.push_front({"c": code, "n": title.left(80), "note": note.left(120), "t": now})
	return out.slice(0, MAX)

static func remove(book: Array, i: int) -> Array:
	var out := book.duplicate(true)
	if i >= 0 and i < out.size():
		out.remove_at(i)
	return out

## 存檔讀進來時逐筆驗型。壞的不丟：交給 split 隔離（1.6.0 B16）。
static func sanitize(raw) -> Array:
	return split(raw)[0]

const BAD_MAX := 6
const BattleCode = preload("res://scripts/game/battle_code.gd")

static func _entry(e):
	if not (e is Dictionary and e.get("c") is String and str(e["c"]).length() <= CODE_MAX and str(e["c"]) != ""):
		return null
	if not BattleCode.decode(str(e["c"])).get("ok", false):
		return null   # 代碼讀不出來（壞碼）：隔離，不放進冊子（不然「看」會失敗）
	var t = e.get("t", 0)
	var ti := int(t) if ((t is int or t is float) and absf(float(t)) < 1.0e12) else 0
	return {"c": str(e["c"]), "n": str(e.get("n", "")).left(80), "note": str(e.get("note", "")).left(120), "t": ti}

const SCAN_MAX := 32   # 讀檔時最多看幾筆（巨量資料不拖垮讀檔；Codex B16 r1）
const BAD_TEXT := CODE_MAX + 400

## 壞的那筆留原文：只取 c／n／note 三個字串欄（截到上限），不把巢狀資料整個序列化
static func _raw_of(e) -> String:
	if e is String:
		return e.left(BAD_TEXT)
	if e is Dictionary:
		var o := {}
		for k in ["c", "n", "note"]:
			var v = e.get(k)
			o[k] = v.left(CODE_MAX) if v is String else type_string(typeof(v))
		return JSON.stringify(o).left(BAD_TEXT)
	return type_string(typeof(e))

## 1.6.0 B16（P13.1）壞資料隔離：回 [好的, 壞的原文字串]。玩家可以複製出來救、或清掉。
static func split(raw) -> Array:
	var out: Array = []
	var bad: Array = []
	if not raw is Array:
		bad.append(_raw_of(raw))   # 不是陣列（含明確存成 null）：整個欄位隔離
		return [out, bad]
	var seen := {}
	var n := 0
	for e in raw:
		n += 1
		if n > SCAN_MAX:
			bad.push_front("+%d" % (raw.size() - SCAN_MAX))   # 太多筆：多的不看，記一筆數量（放最前面，隔離區截六筆時不會被截掉）
			break
		if e is Dictionary and e.get("c") is String and seen.has(e["c"]):
			continue   # 重複的好碼不再解碼
		var g = _entry(e)   # 冊子滿了也照樣驗（壞的要進隔離區；SCAN_MAX 已經限住成本，Codex B16 r3）
		if g == null:
			bad.append(_raw_of(e))
		elif out.size() < MAX:
			seen[g["c"]] = true
			out.append(g)
		else:
			seen[g["c"]] = true   # 滿了的好碼：照 1.2.0 起的規則收不進來
	return [out, bad]

## 隔離區驗型：只收字串、去重、最多 BAD_MAX（新的在前）
static func sanitize_bad(raw) -> Array:
	var out: Array = []
	var seen := {}
	if raw is Array:
		var n := 0
		for x in raw:
			n += 1
			if out.size() >= BAD_MAX or n > SCAN_MAX:
				break   # 有界：最多看 SCAN_MAX 筆、收 BAD_MAX 筆（字典去重，不是平方成本；Codex B16 r2）
			if x is String and x.length() <= BAD_TEXT and not seen.has(x):
				seen[x] = true
				out.append(x)
	return out

## 加一場之前先問：dup（已收過，會移到最上面）／full（滿了，會擠掉最舊的那筆）／ok
static func add_check(book: Array, code: String) -> String:
	for e in book:
		if e is Dictionary and str(e.get("c", "")) == code:
			return "dup"
	return "full" if book.size() >= MAX else "ok"
