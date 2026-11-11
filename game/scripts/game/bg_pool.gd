extends RefCounted
## 1.1.0 N6：背景工作共用生命週期。覆盤重算、GIF、教練、三考、出題碼（工坊碼驗證）都走這裡：
## ・start：檢查 Thread.start 回傳，開不了回 null（呼叫端顯示失敗、可以再按，不退回主執行緒無期限重算）
## ・ctl：{"stop", "until"（期限，毫秒）, "done"（已完成量）, 可選 "total"（知道上限才寫）}，工作迴圈自己看 stop／until
## ・retire：叫停並交給背景回收（不在主執行緒等）；reap 每幀收已經停下的；drain 結束時叫停全部再等（64 tick 內會停）
## ・take：工作結束後取結果（只在 is_alive() 為 false 時呼叫）
## 世代／頁面驗證（結果還配不配目前畫面）留在呼叫端：各工作判斷條件不同（陣型世代、頁面、題組編號）。

var live: Array = []   # [Thread, ctl]
var old: Array = []    # 已叫停、等回收的 [Thread, ctl]

static func make_ctl(limit_ms: int, extra := {}) -> Dictionary:
	var c := {"stop": false, "until": Time.get_ticks_msec() + limit_ms, "done": 0}
	c.merge(extra, true)
	return c

## 進度 0～1；不知道總量（沒有 total）回 -1，畫面就不顯示百分比。
static func progress(ctl: Dictionary) -> float:
	var tot := int(ctl.get("total", 0))
	if tot <= 0:
		return -1.0
	return clampf(float(ctl.get("done", 0)) / tot, 0.0, 1.0)

func start(fn: Callable, ctl: Dictionary) -> Thread:
	var t := Thread.new()
	if t.start(fn) != OK:
		return null
	live.append([t, ctl])
	return t

func retire(t: Thread) -> void:
	if t == null:
		return
	for i in live.size():
		if live[i][0] == t:
			var e: Array = live[i]
			live.remove_at(i)
			(e[1] as Dictionary)["stop"] = true
			old.append(e)
			return
	for e in old:
		if e[0] == t:
			return
	old.append([t, {}])

func take(t: Thread) -> Variant:
	for i in live.size():
		if live[i][0] == t:
			live.remove_at(i)
			break
	return t.wait_to_finish()

func reap() -> void:
	var i := 0
	while i < old.size():
		var t: Thread = old[i][0]
		if not t.is_alive():
			t.wait_to_finish()
			old.remove_at(i)
		else:
			i += 1

func drain() -> void:
	for e in live + old:
		(e[1] as Dictionary)["stop"] = true
	for e in live + old:
		(e[0] as Thread).wait_to_finish()
	live.clear()
	old.clear()

func busy() -> int:
	return live.size() + old.size()
