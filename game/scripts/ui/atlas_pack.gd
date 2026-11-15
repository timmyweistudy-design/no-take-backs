extends RefCounted
## 1.6.0 B09（S7；P10.2）預設外觀離線圖集包：開發時（或匯出前）用 `--bake-pack` 把預設塗裝的圖集烘好存成壓縮 Image 資源，
## 執行時預設外觀直接在背景執行緒讀進來（主執行緒只上傳），不再當場畫向量＋讀回；特殊塗裝、包失效、來源變了＝退回即時烘焙。
## 包本身不進 git（體積大、每次改畫法都要重烘）：`tools/export_check.sh` 匯出前一定重烘；開發機上沒包或過期就照舊即時烘。
## 鍵（任何一項不同＝包無效）：來源雜湊（畫法、姿勢、色票、後處理 shader、烘焙程式）、引擎版本、渲染路徑、塗裝（只收預設）、色盲（分兩個夾）。

const DIR := "res://art/pack"
const MANIFEST := "res://art/pack/manifest.json"
const DEFAULT_PAINT := "00110"
const FORMAT_V := 1
# 會改變烘出來像素的來源（雜湊這些檔；資料夾＝裡面所有 .gd／.json／.gdshader）
const SOURCES := ["res://scripts/ui/art.gd", "res://scripts/ui/units", "res://scripts/ui/pose_data.gd", "res://scripts/ui/pose_files.gd",
	"res://scripts/ui/palette.gd", "res://scripts/core/unit_defs.gd", "res://scripts/ui/sprite_cache.gd", "res://shaders/unit_bake.gdshader", "res://data/poses"]

static var dir := DIR      # 測試可指到 user:// 的假包（注入錯圖、過期）
static var _man := {}      # 清冊快取（第一次 usable() 讀）
static var _state := -1   # -1 還沒檢查｜0 不能用｜1 能用
static var why := ""      # 不能用的原因（量測、ledger 用）
static var misses := 0    # 執行時讀包失敗（壞檔、尺寸不對）次數：一次就整包停用、退回即時烘

static func _files(p: String, out: Array) -> void:
	if p.ends_with(".gd") or p.ends_with(".json") or p.ends_with(".gdshader"):
		out.append(p)
		return
	var d := DirAccess.open(p)
	if d == null:
		return
	var names: Array = Array(d.get_files())
	names.sort()
	for f in names:
		if f.ends_with(".gd") or f.ends_with(".json") or f.ends_with(".gdshader"):
			out.append(p + "/" + f)

## 來源雜湊。匯出版（template）回空字串＝不驗來源（.gd 是二進位讀不到原文；匯出前 export_check.sh 一定重烘、成品自我檢查回報 pack）；
## 開發環境一律算：缺檔也算進雜湊（缺了＝和包不同＝不用包；Codex B09 r1 #1）
static func src_key() -> String:
	if OS.has_feature("template"):
		return ""
	var files: Array = []
	for s in SOURCES:
		_files(s, files)
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	var n := 0
	for f in files:
		var txt := FileAccess.get_file_as_string(f) if FileAccess.file_exists(f) else "<缺檔>"
		ctx.update(("%s\n" % f).to_utf8_buffer())
		ctx.update(txt.to_utf8_buffer())
		n += 1
	if n == 0:
		return ""
	return ctx.finish().hex_encode().substr(0, 16)

static func env_key() -> Dictionary:
	return {"engine": str(Engine.get_version_info()["string"]), "renderer": RenderingServer.get_current_rendering_method(), "format": FORMAT_V}

static func manifest() -> Dictionary:
	var mp := dir + "/manifest.json"
	if not FileAccess.file_exists(mp):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(mp))
	return d if d is Dictionary else {}

## 讀包前驗檔：位元組雜湊要和清冊一樣（同尺寸的錯圖、換錯檔、壞檔都擋；Codex B09 r1 #2）。在背景執行緒呼叫。
## 解碼後的像素＝烘的時候的像素，由測試逐張比像素雜湊證明（test_atlas_pack_v1600）
static func verify_file(cb: int, key: String) -> bool:
	var want := str((_man.get("fsha", {}) as Dictionary).get("cb%d/%s" % [cb, key], ""))
	return want != "" and file_sha(path(cb, key)) == want

## 像素雜湊比對（測試與注入用）
static func verify_pixels(cb: int, key: String, img: Image) -> bool:
	if img == null:
		return false
	var want := str((_man.get("sha", {}) as Dictionary).get("cb%d/%s" % [cb, key], ""))
	return want != "" and img_sha(img) == want

## 這台機器、這份程式能不能用包（第一次問才檢查；開發環境多驗來源雜湊）
static func usable() -> bool:
	if _state >= 0:
		return _state == 1
	_state = 0
	if "--no-pack" in OS.get_cmdline_user_args():
		why = "停用（--no-pack，量測對照）"
		return false
	var m := manifest()
	_man = m
	if m.is_empty():
		why = "沒有包"
		return false
	if str(m.get("paint", "")) != DEFAULT_PAINT or (m.get("sha", {}) as Dictionary).size() != int(m.get("files", -1)) or (m.get("fsha", {}) as Dictionary).size() != int(m.get("files", -1)) or int(m.get("selfcheck_mismatch", -1)) != 0:
		why = "清冊不完整（塗裝、檔數、自我比對）"
		return false
	var em := env_match(m, env_key())
	if em != "":
		why = em
		return false
	var sk := src_key()
	if sk != "" and sk != str(m.get("src", "")):
		why = "來源改過（包 %s／現在 %s）：要重做包" % [m.get("src", ""), sk]
		return false
	_state = 1
	why = ""
	return true

static func reset() -> void:
	_state = -1
	_man = {}
	misses = 0

static func path(cb: int, key: String) -> String:
	return "%s/cb%d/%s.res" % [dir, cb, key]

static func has(cb: int, key: String) -> bool:
	return ResourceLoader.exists(path(cb, key))

static var saved_sha := {}   # 烘包時每張圖的像素雜湊（寫進清冊；測試讀回比對＝解碼差 0）

static func img_sha(img: Image) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(("%dx%d:%d|" % [img.get_width(), img.get_height(), img.get_format()]).to_utf8_buffer())
	ctx.update(img.get_data())
	return ctx.finish().hex_encode().substr(0, 24)

static func save(cb: int, key: String, img: Image) -> int:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/cb%d" % [dir, cb]))
	saved_sha["cb%d/%s" % [cb, key]] = img_sha(img)
	var e := ResourceSaver.save(img, path(cb, key), ResourceSaver.FLAG_COMPRESS)
	saved_fsha["cb%d/%s" % [cb, key]] = file_sha(path(cb, key))
	return e

static var saved_fsha := {}   # 烘包時每個檔的位元組雜湊（執行時讀包前比對：換錯檔、壞檔都擋；比解碼後的像素雜湊便宜很多）

static func file_sha(p: String) -> String:
	var b := FileAccess.get_file_as_bytes(p)
	if b.is_empty():
		return ""
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(b)
	return ctx.finish().hex_encode().substr(0, 24)

## 清冊的環境鍵和這台比（JSON 數字讀回來是 float）
static func env_match(m: Dictionary, e: Dictionary) -> String:
	for k in e:
		var mv = m.get(k, "")
		var same: bool = (float(mv) == float(e[k])) if (e[k] is int or e[k] is float) and (mv is int or mv is float) else str(mv) == str(e[k])
		if not same:
			return "%s 不同（包 %s／現在 %s）" % [k, mv, e[k]]
	return ""

static func fail(key: String, reason: String) -> void:
	misses += 1
	_state = 0
	why = "讀包失敗 %s：%s（整包停用、改回即時繪製）" % [key, reason]
	push_warning(why)
