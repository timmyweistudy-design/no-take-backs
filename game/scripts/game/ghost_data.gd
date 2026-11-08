extends RefCounted
## V1.4 #7 幽靈陣資料（data/ghosts.json）的快取。放在獨立檔：UI 繼承鏈上的 static var 會讓結束時資源洩漏（記憶：Godot 匯出陷阱）。
static var _list: Array = []

static func all() -> Array:
	if _list.is_empty():
		var f := FileAccess.open("res://data/ghosts.json", FileAccess.READ)
		if f != null:
			var d = JSON.parse_string(f.get_as_text())
			if d is Array:
				_list = d
	return _list
