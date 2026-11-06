extends RefCounted
## 第十三輪：新增試煉（索引 ≥10）的資料快取，讀 data/trials.json。
## 獨立成一支腳本：靜態變數放在畫面的繼承鏈（game_modes.gd）裡，結束時 Windows 版會當掉（exit 5）。
static var cache := {}

static func get_x(i: int) -> Dictionary:
	if cache.is_empty() and FileAccess.file_exists("res://data/trials.json"):
		for d in JSON.parse_string(FileAccess.get_file_as_string("res://data/trials.json")):
			cache[int(d["i"])] = d
	return cache.get(i, {})
