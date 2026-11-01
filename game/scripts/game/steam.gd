extends RefCounted
## Steam 介面封裝（優化方案 N）：有 GodotSteam（Engine 單例 "Steam"）就用，沒有就只記在本機存檔。
## 遊戲其他地方只呼叫這裡，換 SDK 版本只要改這個檔。

const Save = preload("res://scripts/game/save.gd")

const ACHIEVEMENTS := {
	"FIRST_WIN": ["初陣告捷", "First Victory"],
	"LONE_HERO": ["孤勇者", "Lone Hero"],
	"COMEBACK": ["絕地翻盤", "Comeback"],
	"CLOSE_CALL": ["一線之隔", "By a Hair"],
	"NO_TAKEBACKS": ["落子無悔", "No Take-Backs"],
	"HARD_WIN": ["勝過困難 AI", "Beat Hard AI"],
	"SWEEP": ["二比零", "Clean Sweep"],
	"TUTORIAL": ["學會了", "Graduated"],
	"PUZZLE_ALL": ["殘局全破", "Puzzle Master"],
	"PUZZLE_3STAR": ["完美解", "Perfect Solution"],
	"GAUNTLET": ["七連勝", "Seven Straight"],
	"FRENZY_WIN": ["狂熱中取勝", "Won in the Frenzy"],
	"ALL_TYPES": ["五兵齊出", "Combined Arms"],
	"CHARGE_5": ["鐵騎突擊", "Cavalry Storm"],
	"BACKSTAB_3": ["暗影三連", "Shadow Trio"],
}

static var _steam = null
static var init_result = null

## app_id：0＝由 Steam 啟動時決定（正式上架）；開發測試可給 480（Valve 公開測試 App「Spacewar」）。
static func init(app_id := 0) -> void:
	if Engine.has_singleton("Steam"):
		_steam = Engine.get_singleton("Steam")
		var r = _steam.steamInitEx(false, app_id) if app_id > 0 else _steam.steamInitEx(false)
		init_result = r
		if typeof(r) == TYPE_DICTIONARY and int(r.get("status", 1)) != 0:
			_steam = null
	if _steam != null:
		# 離線時解鎖、只記在本機的成就，這裡補送到 Steam
		for id in Save.data.get("achievements", []):
			_steam.setAchievement(id)
		_steam.storeStats()

static func available() -> bool:
	return _steam != null

static func name_of(id: String, lang: String) -> String:
	var n: Array = ACHIEVEMENTS.get(id, [id, id])
	return n[0] if lang == "zh_TW" else n[1]

## 解鎖成就；回傳 true 表示這次是新解鎖（畫面要跳提示）。
static func unlock(id: String) -> bool:
	var got: Array = Save.data.get("achievements", [])
	if id in got:
		return false
	got.append(id)
	Save.data["achievements"] = got
	Save.save_data()
	if _steam != null:
		_steam.setAchievement(id)
		_steam.storeStats()
	return true

## 唯讀自我檢查（N8）：不解鎖任何 Spacewar 成就、不寫入統計。回傳每一項的結果。
static func self_test() -> Dictionary:
	var out := {"has_singleton": Engine.has_singleton("Steam"), "init": str(init_result), "available": available()}
	if _steam == null:
		return out
	out["logged_on"] = _steam.loggedOn()
	out["app_id"] = _steam.getAppID()
	out["running"] = _steam.isSteamRunning()
	out["spacewar_ach_read"] = str(_steam.getAchievement("ACH_WIN_ONE_GAME"))   # 唯讀
	out["our_id_rejected"] = str(_steam.getAchievement("FIRST_WIN"))            # 我們的 ID 在 480 不存在，應該回報不存在
	out["cloud_enabled"] = _steam.isCloudEnabledForApp() if _steam.has_method("isCloudEnabledForApp") else "n/a"
	out["input_init"] = _steam.inputInit() if _steam.has_method("inputInit") else "n/a"
	return out

static func run_callbacks() -> void:
	if _steam != null:
		_steam.run_callbacks()
