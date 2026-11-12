extends RefCounted
## 1.2.0 §7.1 姿勢資料化（22 種兵；第 11 大類從劍士試點擴到全部）。讀 data/poses/<兵>.json 的關鍵幀，回傳和 Art.pose 一樣格式的 [w, rot, sx, sy, dx]。
## 只是畫面：命中事件時間由資料的 events.hit 宣告，測試保證它等於 Art.ATK_STRIKE（模擬命中點），不能因為演出延後。

const FILES: Dictionary = preload("res://scripts/ui/pose_files.gd").FILES   # 兵種 → 姿勢檔（tools/gen/pose_gen.py 產生）
static var _cache := {}

static func has(type: int) -> bool:
	return FILES.has(type) and not _keys(type).is_empty()

static func _keys(type: int) -> Array:
	if _cache.has(type):
		return _cache[type]
	var keys: Array = []
	var f := FileAccess.open(str(FILES.get(type, "")), FileAccess.READ)
	if f != null:
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary and d.get("keys") is Array:
			keys = d["keys"]
	_cache[type] = keys
	return keys

static func event_t(type: int, ev: String) -> float:
	var f := FileAccess.open(str(FILES.get(type, "")), FileAccess.READ)
	if f == null:
		return -1.0
	var d = JSON.parse_string(f.get_as_text())
	return float((d as Dictionary).get("events", {}).get(ev, -1.0)) if d is Dictionary else -1.0

static func _ease(kind: String, u: float) -> float:
	match kind:
		"smooth":
			return u * u * (3.0 - 2.0 * u)
		"ease_out":
			return 1.0 - (1.0 - u) * (1.0 - u)
		"back":
			var c := 1.70158
			return 1.0 + (c + 1.0) * pow(u - 1.0, 3.0) + c * pow(u - 1.0, 2.0)
		"step":
			return 0.0 if u < 1.0 else 1.0
	return u

static func eval(type: int, atk: float) -> Array:
	var keys := _keys(type)
	for i in range(1, keys.size()):
		var k1: Dictionary = keys[i]
		if atk < float(k1["t"]) or i == keys.size() - 1:
			var k0: Dictionary = keys[i - 1]
			var u := clampf((atk - float(k0["t"])) / maxf(0.0001, float(k1["t"]) - float(k0["t"])), 0.0, 1.0)
			var e := _ease(str(k1.get("ease", "linear")), u)
			var out: Array = []
			for j in 5:
				out.append(lerpf(float(k0["pose"][j]), float(k1["pose"][j]), e))
			return out
	return [0.0, 0.0, 1.0, 1.0, 0.0]
