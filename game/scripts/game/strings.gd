extends RefCounted
## 字串表（優化方案 I）：data/strings.csv，欄位 key,zh_TW,en。所有畫面文字都從這裡來，不寫死在程式裡。

static var _table := {}
static var lang := "zh_TW"
const LANGS := ["zh_TW", "en"]
## V1.2.1 G3：資料檔（殘局、章節、試煉、圖鑑）的語言欄位後綴。之後加簡中、日文：這裡加 "zh_CN": "sc"、"ja": "ja"，
## strings.csv 加一欄、資料檔加 *_sc／*_ja 欄位、字型子集加字，程式不用再到處改。
const SUFFIX := {"zh_TW": "zh", "en": "en"}

## 依目前語言取資料欄位：field(pz, "") → pz["zh"]／pz["en"]；field(pz, "hint") → pz["hint_zh"]／pz["hint_en"]。缺的退回英文、再退回中文。
static func field(d: Dictionary, base: String) -> String:
	var pre := base + "_" if base != "" else ""
	for suf in [SUFFIX.get(lang, "en"), "en", "zh"]:
		if d.has(pre + suf):
			return str(d[pre + suf])
	return ""

## 二選一的舊資料（[中文, 英文]）：之後加語言時改成字典。
static func pick(zh, en):
	return zh if lang == "zh_TW" else en

static func load_table() -> void:
	if not _table.is_empty():
		return
	var f := FileAccess.open("res://data/strings.csv", FileAccess.READ)
	if f == null:
		push_error("strings.csv 讀不到")
		return
	var header := f.get_csv_line()
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() < header.size() or row[0] == "":
			continue
		var d := {}
		for i in range(1, header.size()):
			d[header[i]] = row[i].replace("\\n", "\n")
		_table[row[0]] = d

static func t(key: String, args: Array = []) -> String:
	load_table()
	var d: Dictionary = _table.get(key, {})
	var s: String = d.get(lang, d.get("zh_TW", key))
	if s == "":
		s = key
	if args.is_empty():
		return s
	return s % args

static func has(key: String) -> bool:
	load_table()
	return _table.has(key)

static func keys() -> Array:
	load_table()
	return _table.keys()

## 給字型子集化用：所有語言的所有字。
static func all_text() -> String:
	load_table()
	var s := ""
	for k in _table:
		for l in LANGS:
			s += _table[k].get(l, "")
	return s
