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
	# 第五輪：自訂規則專屬（標準成就只看平衡認證的規則）
	"CUSTOM_LOWGOLD": ["精打細算", "Shoestring Army"],
	"CUSTOM_UNDERDOG": ["以寡擊眾", "Underdog"],
	"CUSTOM_BIG": ["大軍壓境", "Grand Army"],
}

static var _steam = null
static var init_result = null

## 商店頁網址（第三輪 F5：試玩版結尾的願望清單按鈕用）。拿到 AppID 後填進來；空字串時按鈕顯示「上架後開放」。
const STORE_URL := ""

## app_id：0＝由 Steam 啟動時決定（正式上架）；開發測試可給 480（Valve 公開測試 App「Spacewar」）。
## sync_local：初始化後把本機成就補送到 Steam。自我檢查一定傳 false（不寫入任何東西）。
## GodotSteam 4.23.2 的簽章是 steamInitEx(app_id: int = 0, embed_callbacks: bool = false)（用 ClassDB 查過）。
static func init(app_id := 0, sync_local := true) -> void:
	if Engine.has_singleton("Steam"):
		_steam = Engine.get_singleton("Steam")
		var r = _steam.steamInitEx(app_id) if app_id > 0 else _steam.steamInitEx()
		init_result = r
		if typeof(r) == TYPE_DICTIONARY and int(r.get("status", 1)) != 0:
			_steam = null
	if _steam != null and sync_local:
		# 離線時解鎖、只記在本機的成就，這裡補送到 Steam（沒有就不呼叫 storeStats）
		var got: Array = Save.data.get("achievements", [])
		if not got.is_empty():
			for id in got:
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

## 唯讀自我檢查（N8）：init 時不補送、只用讀取函式；不解鎖、不寫統計、不初始化輸入。
## 回傳每一項結果與總判定 ok（任何一項不符就是 false，呼叫端用它決定結束碼）。
static func self_test(expect_app_id: int) -> Dictionary:
	var out := {"has_singleton": Engine.has_singleton("Steam"), "init": str(init_result), "available": available(), "ok": false}
	if _steam == null:
		out["why"] = "沒有 GodotSteam 或初始化失敗"
		return out
	out["logged_on"] = _steam.loggedOn()
	out["app_id"] = _steam.getAppID()
	out["running"] = _steam.isSteamRunning()
	var known = _steam.getAchievement("ACH_WIN_ONE_GAME")    # Spacewar 真的有的成就：讀取應該成功
	var ours = _steam.getAchievement("FIRST_WIN")            # 我們的 ID 在 480 不存在：讀取應該失敗
	out["known_read_ok"] = typeof(known) == TYPE_DICTIONARY and bool(known.get("ret", false))
	out["our_id_missing"] = typeof(ours) == TYPE_DICTIONARY and not bool(ours.get("ret", true))
	out["ok"] = out["logged_on"] and int(out["app_id"]) == expect_app_id and out["known_read_ok"] and out["our_id_missing"]
	if not out["ok"]:
		out["why"] = "有檢查項不符"
	return out

static func run_callbacks() -> void:
	if _steam != null:
		_steam.run_callbacks()
