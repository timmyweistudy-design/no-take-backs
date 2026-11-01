extends RefCounted
## 設定與進度存檔（優化方案 L1、N）：JSON、原子寫入（先寫暫存檔再改名）＋保留上一版備份。
## 雲端：Steam Auto-Cloud 只同步 user://save.json（進度、陣型）；設定 user://settings.json 留在本機。

const SAVE_VERSION := 2   # 存檔格式版本（schema_version）。2：加 unit_wins（圖鑑老兵筆記，第二輪方案 R3／R8）
static var prefix := ""   # 截圖／測試模式用 "shot_"，不碰玩家真正的存檔

const DEFAULT_SETTINGS := {
	"lang": "zh_TW", "text_scale": 100, "shake": true, "slowmo": true, "flash": true, "colorblind": false,
	"speed": 1.0, "music": 70, "sfx": 80, "duel_rule": "snake5", "fullscreen": false, "playtest": false,
}
const DEFAULT_SAVE := {
	"schema_version": SAVE_VERSION, "slots": ["", "", "", "", ""], "tutorial": 0, "puzzle_stars": {},
	"gauntlet_best": 0, "achievements": [], "stats": {"wins": 0, "games": 0}, "unit_wins": {},
}

static var settings := {}
static var data := {}

static func load_all() -> void:
	settings = _read(_sp(), DEFAULT_SETTINGS)
	data = migrate(_read(_dp(), DEFAULT_SAVE))

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

## 逐版遷移（純函式，測試用）：舊進度一律保留；不認得的欄位也保留（新版遊戲寫的存檔被舊版讀到時不會被刪掉）。
## 比目前新的版本：原樣回傳，不降版。
static func migrate(d: Dictionary) -> Dictionary:
	var out := d.duplicate(true)
	var v := int(out.get("schema_version", out.get("version", 1)))
	if v > SAVE_VERSION:
		return out
	if v < 2:
		# 1 → 2：欄位名 version 改成 schema_version；加 unit_wins
		out.erase("version")
		if not out.get("unit_wins") is Dictionary:
			out["unit_wins"] = {}
		v = 2
	for k in DEFAULT_SAVE:
		if not out.has(k):
			out[k] = DEFAULT_SAVE[k].duplicate(true) if DEFAULT_SAVE[k] is Dictionary or DEFAULT_SAVE[k] is Array else DEFAULT_SAVE[k]
	out["schema_version"] = v
	return out

static func _write(path: String, d: Dictionary) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	var txt := JSON.stringify(d, "\t")
	f.store_string(txt)
	f.close()
	# 讀回驗證：內容不完整（磁碟滿、被中斷）就不覆蓋正式檔
	if FileAccess.get_file_as_string(tmp) != txt:
		return false
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + ".bak")
	return DirAccess.rename_absolute(tmp, path) == OK

static func save_settings() -> bool:
	return _write(_sp(), settings)

static func save_data() -> bool:
	return _write(_dp(), data)

static func s(key: String):
	return settings.get(key, DEFAULT_SETTINGS.get(key))

static func set_setting(key: String, v) -> void:
	settings[key] = v
	save_settings()


## 試玩紀錄（優化方案 F5、N3）：只在設定開啟時寫在本機 user://playtest_log.jsonl，不上傳。
static func playtest_log(entry: Dictionary) -> void:
	if not bool(s("playtest")):
		return
	var path := "user://%splaytest_log.jsonl" % prefix
	var f := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	entry["time"] = Time.get_datetime_string_from_system()
	f.store_line(JSON.stringify(entry))
