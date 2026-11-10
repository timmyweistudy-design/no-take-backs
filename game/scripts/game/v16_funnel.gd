extends RefCounted
## V1.6 #2 真人試玩流程：本機的「第一次」里程碑（不上傳、不含個人資料），回報時連同白名單試玩紀錄一起匯出。
## 存在 Save.data["funnel"]：{里程碑: 第一次發生的 Unix 秒}，另記開啟次數與最後離開的畫面。
const Save = preload("res://scripts/game/save.gd")

## 里程碑順序（回報依此排序，也是新手漏斗的步驟）
const STEPS := ["boot", "tutorial_open", "tutorial_done", "first_battle", "first_win", "first_loss",
	"puzzle_open", "puzzle_clear", "gauntlet_open", "daily_open", "playroom_open", "codex_open", "settings_open", "demo_end"]

static func mark(key: String, now := -1) -> bool:
	var f: Dictionary = Save.data.get("funnel", {})
	if f.has(key):
		return false
	f[key] = now if now >= 0 else int(Time.get_unix_time_from_system())
	Save.data["funnel"] = f
	return true

static func boot() -> void:
	var f: Dictionary = Save.data.get("funnel", {})
	f["boots"] = int(f.get("boots", 0)) + 1
	Save.data["funnel"] = f
	mark("boot")

static func leave(screen: String) -> void:
	var f: Dictionary = Save.data.get("funnel", {})
	f["last_screen"] = screen
	Save.data["funnel"] = f

## 漏斗：已達成的步驟與距離第一次開遊戲的分鐘數
static func steps() -> Array:
	var f: Dictionary = Save.data.get("funnel", {})
	var t0 := int(f.get("boot", 0))
	var out: Array = []
	for k in STEPS:
		if f.has(k):
			out.append({"step": k, "min": maxi(0, int(f[k]) - t0) / 60})
	return out

## 一份完整回報（純文字 JSON）：版本、系統、語言、字級、所在畫面、漏斗、白名單試玩紀錄
static func report(app: String, screen: String) -> String:
	var pt: Dictionary = Save.playtest_report(app)
	var rows = JSON.parse_string(str(pt["text"]))
	var f: Dictionary = Save.data.get("funnel", {})
	var d := {"app": app, "os": OS.get_name(), "lang": str(Save.s("lang")), "text_scale": int(Save.s("text_scale")),
		"screen": screen, "boots": int(f.get("boots", 0)), "last_screen": str(f.get("last_screen", "")),
		"funnel": steps(), "rows": (rows["rows"] if rows is Dictionary else [])}
	return JSON.stringify({"feedback": d}, " ")
