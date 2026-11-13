extends RefCounted
## 1.3.0 第 12 大類（方案 §12.7）：每日老闆出題——每天從玩家還沒三星的殘局裡挑三題（固定由日期決定、離線）；
## 當天三題都過（≥1 星）蓋一枚「老闆的印」（一天一枚）。純邏輯，不碰畫面與存檔物件（呼叫端傳進傳出）。

const N := 3

## 這一天的三題：還沒三星的優先（全部挑進來，Codex cat11 #6）；不足三題才用已三星的補滿；全部三星＝從全部挑。
## 依日期雜湊、不重複、依題庫順序排。當天第一次看到就存進存檔（`od.picks`），之後不再重抽（Codex cat11 #1）。
static func pick(day: int, ids: Array, stars: Dictionary) -> Array:
	var open: Array = []
	var rest: Array = []
	for id in ids:
		if int(stars.get(id, 0)) < 3:
			open.append(id)
		else:
			rest.append(id)
	var out: Array = []
	var h := posmod(day * 2654435761, 2147483647)
	for pool in [open, rest]:
		var need := N - out.size()
		if need <= 0 or pool.is_empty():
			continue
		if pool.size() <= need:
			out += pool
			continue
		var got := 0
		while got < need:
			h = posmod(h * 48271 + 11, 2147483647)
			var c = pool[h % pool.size()]
			if not c in out:
				out.append(c)
				got += 1
	var order: Array = []
	for id in ids:
		if id in out:
			order.append(id)
	return order

## 今天的題單：存檔裡是今天的就用存的（題庫移除的題拿掉，完成紀錄一起修）；不是就重抽並開新的一天。回傳 [題單, 新紀錄]。
static func today_picks(rec, day: int, ids: Array, stars: Dictionary) -> Array:
	var r := sanitize(rec)
	if int(r["day"]) == day and not (r["picks"] as Array).is_empty():
		var keep: Array = []
		for p in r["picks"]:
			if p in ids:
				keep.append(p)
		var done: Array = []
		for d in r["done"]:
			if d in keep:
				done.append(d)
		r["picks"] = keep
		r["done"] = done
		if not keep.is_empty():
			return [keep, r]
	var pk := pick(day, ids, stars)
	return [pk, {"day": day, "picks": pk, "done": [], "stamped": false}]

## 存檔欄位整理：{"day": int, "done": [id...], "stamped": bool}；換日就重來。
static func sanitize(raw) -> Dictionary:
	var out := {"day": -1, "picks": [], "done": [], "stamped": false}
	if raw is Dictionary:
		out["day"] = int(raw.get("day", -1)) if (raw.get("day", -1) is int or raw.get("day", -1) is float) else -1
		var pk = raw.get("picks", [])
		if pk is Array:
			for e in pk:
				if e is String and str(e).length() <= 16 and out["picks"].size() < N and not e in out["picks"]:
					out["picks"].append(e)
		var d = raw.get("done", [])
		if d is Array:
			for e in d:
				if e is String and str(e).length() <= 16 and out["done"].size() < N:
					out["done"].append(e)
		out["stamped"] = raw.get("stamped", false) is bool and bool(raw.get("stamped", false))
	return out

## 打完一題：今天的題、≥1 星就記；三題都記到就蓋印。回傳 [新紀錄, 這次有沒有蓋到印]。
static func record(rec: Dictionary, day: int, picks: Array, id: String, stars: int) -> Array:
	var r := sanitize(rec)
	if int(r["day"]) != day:
		r = {"day": day, "picks": picks.duplicate(), "done": [], "stamped": false}
	if stars >= 1 and id in picks and not id in r["done"]:
		r["done"].append(id)
	var got := false
	if not bool(r["stamped"]):
		var all := true
		for p in picks:
			if not p in r["done"]:
				all = false
		if all and not picks.is_empty():
			r["stamped"] = true
			got = true
	return [r, got]
