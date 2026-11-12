extends RefCounted
## 1.2.0 §11.2 重播書籤：重播前的確定性預跑順手收「誰在哪一 tick 倒下」「每隊第一次破盾」，
## 和既有的關鍵時刻（鎖定、反超、最後時刻、軍令）合併成一串可以跳的時間點。純資料、不碰畫面。
const EV = preload("res://scripts/core/events.gd")

## 每 step 之後呼叫一次：把這一 tick 的事件收進 out（[{t, kind, team}]）。
static func collect(sim, out: Array) -> void:
	for e in sim.events:
		var k := str(e.get("kind", ""))
		if k == EV.DEATH:
			var u = sim.unit_by_id(int(e.get("id", -1)))
			out.append({"t": int(sim.tick), "kind": "death", "team": int(u.team) if u != null else -1})
		elif (e.get("tags", []) as Array).has(EV.BREAKER):
			var src = sim.unit_by_id(int(e.get("src", -1)))
			var tm: int = int(src.team) if src != null else -1
			var dup := false
			for m in out:
				if str(m["kind"]) == "break" and int(m["team"]) == tm:
					dup = true
					break
			if not dup:
				out.append({"t": int(sim.tick), "kind": "break", "team": tm})

## 可以跳的時間點：書籤＋關鍵時刻，由小到大、去重（20 tick＝1 秒內只留一個）。
static func jump_points(bm: Array, marks: Array) -> PackedInt32Array:
	var ts: Array = []
	for m in bm:
		ts.append(int(m["t"]))
	for m2 in marks:
		ts.append(int(m2["t"]))
	ts.sort()
	var out := PackedInt32Array()
	for t in ts:
		if out.is_empty() or t - out[out.size() - 1] >= 20:
			out.append(t)
	return out

## 從 cur 往 dir（+1／−1）找下一個點；往回時離目前不到 1 秒的跳過（不然一直跳回同一點）。沒有就回 -1。
static func next_point(pts: PackedInt32Array, cur: int, dir: int) -> int:
	if dir > 0:
		for t in pts:
			if t > cur + 1:
				return t
		return -1
	for i in range(pts.size() - 1, -1, -1):
		if pts[i] < cur - 20:
			return pts[i]
	return -1
