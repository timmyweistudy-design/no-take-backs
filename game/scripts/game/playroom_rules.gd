extends RefCounted
## 1.1.0 A22：遊戲間（賭局、輪抽、車輪戰、週賽）的純邏輯，從 game_playroom.gd 搬出來（畫面腳本留同名包裝，呼叫端不變）。
## 只放不碰畫面、存檔、節點的函式；UI 分派與繼承鏈不動。

const WG_NARROW := 34   # 觀戰競猜：剩餘 < 34% 算險勝
const WG_CRUSH := 67    # ≥ 67% 算碾壓

static func wager_band(rem: int) -> int:
	return 0 if rem < WG_NARROW else (1 if rem < WG_CRUSH else 2)

static func draft_mask(list: Array) -> int:
	var m := 0
	for t in list:
		m |= 1 << int(t)
	return m

static func wave_code(codes: Array) -> String:
	var b := Marshalls.utf8_to_base64(JSON.stringify({"v": 1, "w": codes}))
	return "NTW1.%s.%s" % [b, b.sha256_text().substr(0, 6)]

static func wave_decode(c: String) -> Array:
	var parts := c.strip_edges().split(".")
	if c.length() > 60000 or parts.size() != 3 or parts[0] != "NTW1" or parts[1].sha256_text().substr(0, 6) != parts[2]:
		return []
	var d = JSON.parse_string(Marshalls.base64_to_utf8(parts[1]))
	if not d is Dictionary or not d.get("w") is Array:
		return []
	var w: Array = d["w"]
	if w.is_empty() or w.size() > 3:
		return []
	for x in w:
		if not x is String or not str(x).get_slice(".", 0) in ["NTB2", "NTB3", "NTB4", "NTB7"]:
			return []
	return w

static func wave_has_lock(units: Array, lock: Array) -> bool:
	for u in lock:
		var hit := false
		for v in units:
			if v.has("col") and int(v["col"]) == int(u["col"]) and int(v["row"]) == int(u["row"]) and int(v["type"]) == int(u["type"]):
				hit = true
				break
		if not hit:
			return false
	return true

static func week_no(unix: int) -> int:
	return int(floor((unix / 86400.0 - 4.0) / 7.0))

