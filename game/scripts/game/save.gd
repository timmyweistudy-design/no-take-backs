extends RefCounted
## 設定與進度存檔（優化方案 L1、N）：JSON、原子寫入（先寫暫存檔再改名）＋保留上一版備份。
## 雲端：Steam Auto-Cloud 只同步 user://save.json（進度、陣型）；設定 user://settings.json 留在本機。

const SAVE_VERSION := 1
static var prefix := ""   # 截圖／測試模式用 "shot_"，不碰玩家真正的存檔

const DEFAULT_SETTINGS := {
	"lang": "zh_TW", "text_scale": 100, "shake": true, "slowmo": true, "flash": true, "colorblind": false,
	"speed": 1.0, "music": 70, "sfx": 80, "duel_rule": "snake5", "fullscreen": false,
}
const DEFAULT_SAVE := {
	"version": SAVE_VERSION, "slots": ["", "", "", "", ""], "tutorial": 0, "puzzle_stars": {},
	"gauntlet_best": 0, "achievements": [], "stats": {"wins": 0, "games": 0},
}

static var settings := {}
static var data := {}

static func load_all() -> void:
	settings = _read(_sp(), DEFAULT_SETTINGS)
	data = _read(_dp(), DEFAULT_SAVE)
	if int(data.get("version", 0)) != SAVE_VERSION:
		data = _migrate(data)

static func _sp() -> String:
	return "user://%ssettings.json" % prefix

static func _dp() -> String:
	return "user://%ssave.json" % prefix

static func _read(path: String, defaults: Dictionary) -> Dictionary:
	var out := defaults.duplicate(true)
	for p in [path, path + ".bak"]:
		if not FileAccess.file_exists(p):
			continue
		var txt := FileAccess.get_file_as_string(p)
		var parsed = JSON.parse_string(txt)
		if typeof(parsed) == TYPE_DICTIONARY:
			for k in parsed:
				out[k] = parsed[k]
			return out
	return out

static func _migrate(d: Dictionary) -> Dictionary:
	var out := DEFAULT_SAVE.duplicate(true)
	for k in d:
		if out.has(k):
			out[k] = d[k]
	out["version"] = SAVE_VERSION
	return out

static func _write(path: String, d: Dictionary) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(d, "\t"))
	f.close()
	var dir := DirAccess.open("user://")
	var name := path.get_file()
	if FileAccess.file_exists(path):
		dir.copy(name, name + ".bak")
	return dir.rename(tmp.get_file(), name) == OK

static func save_settings() -> void:
	_write(_sp(), settings)

static func save_data() -> void:
	_write(_dp(), data)

static func s(key: String):
	return settings.get(key, DEFAULT_SETTINGS.get(key))

static func set_setting(key: String, v) -> void:
	settings[key] = v
	save_settings()
