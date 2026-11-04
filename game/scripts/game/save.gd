extends RefCounted
## 設定與進度存檔（優化方案 L1、N）：JSON、原子寫入（先寫暫存檔再改名）＋保留上一版備份。
## 雲端：Steam Auto-Cloud 只同步 user://save.json（進度、陣型）；設定 user://settings.json 留在本機。

const SAVE_VERSION := 3   # 存檔格式版本（schema_version）。2：加 unit_wins（圖鑑老兵筆記，第二輪方案 R3／R8）；3：第五輪自訂規則
const MAX_PRESETS := 5
static var prefix := ""   # 截圖／測試模式用 "shot_"，不碰玩家真正的存檔

const DEFAULT_SETTINGS := {
	"lang": "zh_TW", "text_scale": 100, "shake": true, "slowmo": true, "flash": true, "colorblind": false, "plain_titles": false, "confirm_place": true,
	"speed": 1.0, "music": 70, "sfx": 80, "duel_rule": "snake5", "fullscreen": false, "playtest": false, "roster": "all", "unlock_all": false,
}
const DEFAULT_SAVE := {
	"schema_version": SAVE_VERSION, "slots": ["", "", "", "", ""], "tutorial": 0, "puzzle_stars": {},
	"gauntlet_best": 0, "achievements": [], "stats": {"wins": 0, "games": 0}, "unit_wins": {},
	# 第五輪：解鎖累計場數（標準＋自訂局都算，沙盒不算）、自訂規則戰績、我的預設、上次在大廳用的規則（代碼）
	"unlock_games": 0, "custom_stats": {"wins": 0, "games": 0}, "rule_presets": [], "last_rules": {},
}

static var settings := {}
static var data := {}
## 第七輪 R5：存檔來自比這一版新的遊戲。原檔不動、這次進度不寫入，畫面要告知玩家。
static var data_locked := false
## 第七輪 R6：這次讀到的來源："none"／"main"／"bak"（"bak"＝主檔壞了，已隔離）。
static var data_source := "none"
## 第七輪 R7：寫入失敗還沒補上的檔案（路徑）；retry_pending() 重試。
static var pending := {}
## 只給測試用：接下來幾次寫入要假裝失敗（"tmp"＝寫暫存失敗；"rotate"＝輪替備份失敗）。
static var fail_inject := {}

static func load_all() -> void:
	pending = {}
	settings = sanitize_settings(_read(_sp(), {}).get("value", {}))
	var r := _read(_dp(), {})
	data_source = r["source"]
	var raw: Dictionary = r["value"]
	data_locked = schema_of(raw) > SAVE_VERSION
	# 未來版存檔：記憶體用全新進度，檔案完全不碰（Codex plan7 R5）
	data = migrate({}) if data_locked else migrate(raw)   # 先讀原始內容再遷移（遷移裡才補預設值），不然舊檔會被當成新版（Codex 收尾輪 #1）

## 檔名前綴：測試／截圖的 prefix 在前；試玩版另外一份，進度不帶進正式版（N1、§18-4）。
static func file_prefix(demo := OS.has_feature("demo")) -> String:
	return prefix + ("demo_" if demo else "")

static func _sp() -> String:
	return "user://%ssettings.json" % file_prefix()

static func _dp() -> String:
	return "user://%ssave.json" % file_prefix()

## 讀一個 JSON 檔；內容不是物件就回傳 null。
static func _parse(path: String):
	var j := JSON.new()   # 不用 JSON.parse_string：壞檔是預期情況，不該在日誌印 ERROR
	if j.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	return j.data if typeof(j.data) == TYPE_DICTIONARY else null

## 壞掉的主檔移到旁邊留證據，主檔位置空出來，下一次寫入才不會拿它蓋掉好備份（R6）。
static func _quarantine(path: String) -> void:
	var n := 1
	while FileAccess.file_exists("%s.corrupt%d" % [path, n]) and n < 20:
		n += 1
	DirAccess.rename_absolute(path, "%s.corrupt%d" % [path, n])

## 回傳 {value, source}。主檔壞 → 隔離 → 讀備份。
static func _read(path: String, defaults: Dictionary) -> Dictionary:
	if FileAccess.file_exists(path):
		var m = _parse(path)
		if m != null:
			return {"value": m, "source": "main"}
		_quarantine(path)
	var bak := path + ".bak"
	if FileAccess.file_exists(bak):
		var b = _parse(bak)
		if b != null:
			return {"value": b, "source": "bak"}
	return {"value": defaults.duplicate(true), "source": "none"}

static func _num(v, fallback := 0.0) -> float:
	return float(v) if (v is int or v is float) else float(fallback)

static func _count(v, hi := 1000000000) -> int:
	return clampi(int(_num(v)), 0, hi)

static func schema_of(d: Dictionary) -> int:
	return int(_num(d.get("schema_version", d.get("version", 1)), 1))

## 設定逐欄驗型（R4）：型別不對用預設，數值夾在合法範圍；不認得的欄位保留。
static func sanitize_settings(d: Dictionary) -> Dictionary:
	var out := d.duplicate(true)
	for k in DEFAULT_SETTINGS:
		var dv = DEFAULT_SETTINGS[k]
		var v = out.get(k, dv)
		if dv is bool:
			out[k] = v if v is bool else dv
		elif dv is String:
			out[k] = v if v is String else dv
		elif dv is int:
			out[k] = int(v) if (v is int or v is float) else dv
		elif dv is float:
			out[k] = float(v) if (v is int or v is float) else dv
	if not str(out["lang"]) in ["zh_TW", "en"]:
		out["lang"] = DEFAULT_SETTINGS["lang"]
	if not int(out["text_scale"]) in [100, 125, 150]:
		out["text_scale"] = DEFAULT_SETTINGS["text_scale"]
	out["music"] = clampi(int(out["music"]), 0, 100)
	out["sfx"] = clampi(int(out["sfx"]), 0, 100)
	out["speed"] = clampf(float(out["speed"]), 0.25, 8.0)
	if not str(out["duel_rule"]) in ["snake5", "snake5c", "cap10", "blind", "custom"]:
		out["duel_rule"] = DEFAULT_SETTINGS["duel_rule"]
	if not str(out["roster"]) in ["all", "classic"]:
		out["roster"] = DEFAULT_SETTINGS["roster"]
	return out

## 進度逐欄驗型（R4）：語法對但型別錯的欄位不能讓遊戲當掉；壞欄位改預設，其他進度保留。
static func sanitize_data(out: Dictionary) -> void:
	var sl: Array = ["", "", "", "", ""]
	var raw_sl = out.get("slots", [])
	if raw_sl is Array:
		for i in mini(raw_sl.size(), sl.size()):
			if raw_sl[i] is String and str(raw_sl[i]).length() <= 8000:
				sl[i] = raw_sl[i]
	out["slots"] = sl
	for k in ["tutorial", "gauntlet_best", "unlock_games"]:
		out[k] = _count(out.get(k, 0))
	for k in ["stats", "custom_stats"]:
		var st = out.get(k, {})
		out[k] = {"wins": _count(st.get("wins", 0)), "games": _count(st.get("games", 0))} if st is Dictionary else {"wins": 0, "games": 0}
	var stars := {}
	var raw_st = out.get("puzzle_stars", {})
	if raw_st is Dictionary:
		for k in raw_st:
			stars[str(k)] = _count(raw_st[k], 3)
	out["puzzle_stars"] = stars
	var uw := {}
	var raw_uw = out.get("unit_wins", {})
	if raw_uw is Dictionary:
		for k in raw_uw:
			uw[str(k)] = _count(raw_uw[k])
	out["unit_wins"] = uw
	var ach: Array = []
	var raw_a = out.get("achievements", [])
	if raw_a is Array:
		for a in raw_a:
			if a is String and not a in ach:
				ach.append(a)
	out["achievements"] = ach
	var lr := {}
	var raw_lr = out.get("last_rules", {})
	if raw_lr is Dictionary:
		for k in raw_lr:
			if raw_lr[k] is String and str(raw_lr[k]).length() <= 2000:
				lr[str(k)] = raw_lr[k]
	out["last_rules"] = lr

## 逐版遷移（純函式，測試用）：舊進度一律保留；不認得的欄位也保留（新版遊戲寫的存檔被舊版讀到時不會被刪掉）。
## 比目前新的版本：原樣回傳，不降版。
static func migrate(d: Dictionary) -> Dictionary:
	var out := d.duplicate(true)
	var v := schema_of(out)
	if v > SAVE_VERSION:
		return out
	if v < 2:
		# 1 → 2：欄位名 version 改成 schema_version；加 unit_wins
		out.erase("version")
		v = 2
	if v < 3:
		# 2 → 3：解鎖改看獨立的累計場數，初值＝原本的正式場數（已解鎖的兵不會被收回）
		var st = out.get("stats", {})
		out["unlock_games"] = _count(st.get("games", 0)) if st is Dictionary else 0
		v = 3
	# 我的預設：逐筆驗型、限長、最多 5 組（Codex 第一輪）
	var ps: Array = []
	var raw = out.get("rule_presets", [])
	if raw is Array:
		for e in raw:
			if e is Dictionary and e.get("name") is String and e.get("code") is String and str(e["code"]).length() <= 2000 and ps.size() < MAX_PRESETS:
				ps.append({"name": str(e["name"]).substr(0, 24), "code": str(e["code"])})
	out["rule_presets"] = ps
	for k in DEFAULT_SAVE:
		if not out.has(k):
			out[k] = DEFAULT_SAVE[k].duplicate(true) if DEFAULT_SAVE[k] is Dictionary or DEFAULT_SAVE[k] is Array else DEFAULT_SAVE[k]
	sanitize_data(out)
	out["schema_version"] = v
	return out

## 原子寫入。R6：只有內容驗證過的主檔才輪替成備份；輪替失敗不覆蓋主檔。
static func _write(path: String, d: Dictionary) -> bool:
	var tmp := path + ".tmp"
	if fail_inject.get("tmp", 0) > 0:
		fail_inject["tmp"] -= 1
		return false
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	var txt := JSON.stringify(d, "\t")
	f.store_string(txt)
	f.close()
	# 讀回驗證：內容不完整（磁碟滿、被中斷）就不覆蓋正式檔
	if FileAccess.get_file_as_string(tmp) != txt:
		DirAccess.remove_absolute(tmp)
		return false
	if FileAccess.file_exists(path):
		if _parse(path) == null:
			_quarantine(path)   # 遊戲開著時主檔被弄壞：不能拿它蓋備份
		else:
			var rotated := false
			if fail_inject.get("rotate", 0) > 0:
				fail_inject["rotate"] -= 1
			else:
				var bt := path + ".bak.tmp"
				rotated = DirAccess.copy_absolute(path, bt) == OK and _parse(bt) != null and DirAccess.rename_absolute(bt, path + ".bak") == OK
				if not rotated:
					DirAccess.remove_absolute(bt)
			if not rotated:
				DirAccess.remove_absolute(tmp)
				return false
	return DirAccess.rename_absolute(tmp, path) == OK

static func _tracked_write(path: String, d: Dictionary) -> bool:
	var good := _write(path, d)
	if good:
		pending.erase(path)
	else:
		pending[path] = true
	return good

static func save_settings() -> bool:
	return _tracked_write(_sp(), settings)

## 未來版存檔（R5）一律不寫，回傳 true 是因為這不是「寫入失敗」，畫面已經常駐提示。
static func save_data() -> bool:
	if data_locked:
		return true
	return _tracked_write(_dp(), data)

static func has_unsaved() -> bool:
	return not pending.is_empty()

## R7：上次寫入失敗就再試一次（換畫面、回標題時呼叫）。回傳 true＝現在沒有未存內容。
static func retry_pending() -> bool:
	if pending.has(_sp()):
		save_settings()
	if pending.has(_dp()):
		save_data()
	return pending.is_empty()

static func s(key: String):
	return settings.get(key, DEFAULT_SETTINGS.get(key))

static func set_setting(key: String, v) -> void:
	settings[key] = v
	save_settings()


## 試玩紀錄（優化方案 F5、N3）：只在設定開啟時寫在本機 user://playtest_log.jsonl，不上傳。
static func playtest_log(entry: Dictionary) -> void:
	if not bool(s("playtest")):
		return
	var path := "user://%splaytest_log.jsonl" % file_prefix()
	var f := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	entry["time"] = Time.get_datetime_string_from_system()
	f.store_line(JSON.stringify(entry))
