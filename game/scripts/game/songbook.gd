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

## 存檔讀進來時逐筆驗型（壞的丟掉）
static func sanitize(raw) -> Array:
	var out: Array = []
	if not raw is Array:
		return out
	for e in raw:
		if out.size() >= MAX:
			break
		if e is Dictionary and e.get("c") is String and str(e["c"]).length() <= CODE_MAX and str(e["c"]) != "":
			out.append({"c": str(e["c"]), "n": str(e.get("n", "")).left(80), "note": str(e.get("note", "")).left(120), "t": int(e.get("t", 0)) if (e.get("t") is int or e.get("t") is float) else 0})
	return out
