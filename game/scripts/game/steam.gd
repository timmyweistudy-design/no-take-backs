extends RefCounted
## Steam 介面封裝（優化方案 N）：有 GodotSteam（Engine 單例 "Steam"）就用，沒有就只記在本機存檔。
## 遊戲其他地方只呼叫這裡，換 SDK 版本只要改這個檔。

const Save = preload("res://scripts/game/save.gd")
const L = preload("res://scripts/game/strings.gd")

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
	# 第八輪：奇幻兵團
	"FANTASY_WIN": ["傭兵公會開張", "Monster Mercenaries"],
	"BOOM_5": ["羊到爆炸", "Sheep Go Boom"],
	"RAISE_3": ["大家起來", "Rise and Shine"],
	# 第十三輪：百關殘局、30 關試煉
	"PUZZLE_100": ["百局通關", "Hundred Puzzles"],
	"PUZZLE_ALL3": ["百局三星", "Hundred Perfect"],
	"TRIAL_ALL3": ["試煉滿星", "Trial Perfectionist"],
}

static var _steam = null
static var init_result = null
static var store_ok := true
static var _retry_tick := 0

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
	return str(L.pick_for(n[0], n[1], lang))

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
		store_ok = bool(_steam.storeStats())   # 第七輪 R7：送不出去就記著，run_callbacks 定期重試
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
	# 第七輪 S4：Spacewar 和正式 App 分開驗
	if expect_app_id == 480:
		var known = _steam.getAchievement("ACH_WIN_ONE_GAME")    # Spacewar 真的有的成就：讀取應該成功
		var ours = _steam.getAchievement("FIRST_WIN")            # 我們的 ID 在 480 不存在：讀取應該失敗
		out["known_read_ok"] = typeof(known) == TYPE_DICTIONARY and bool(known.get("ret", false))
		out["our_id_missing"] = typeof(ours) == TYPE_DICTIONARY and not bool(ours.get("ret", true))
		out["ok"] = out["logged_on"] and int(out["app_id"]) == expect_app_id and out["known_read_ok"] and out["our_id_missing"]
	else:
		# 正式 App：後台的成就清單要和程式一字不差
		var missing: Array = []
		for id in ACHIEVEMENTS:
			var r = _steam.getAchievement(id)
			if typeof(r) != TYPE_DICTIONARY or not bool(r.get("ret", false)):
				missing.append(id)
		out["missing_achievements"] = missing
		out["ok"] = out["logged_on"] and int(out["app_id"]) == expect_app_id and missing.is_empty()
	if not out["ok"]:
		out["why"] = "有檢查項不符"
	return out

## 手把貼不了剪貼簿（第七輪 N4）：Steam 的大字幕鍵盤。回傳 false＝沒有 Steam 或不支援，呼叫端要自己提示。
## 這段只有接上 Steam 才跑得到，還沒實機驗（ClassDB 查過簽章：input_mode、line_input_mode、description、max_text、preset_text）。
static func text_input(description: String, max_len: int, done: Callable) -> bool:
	if _steam == null or not _steam.has_method("showGamepadTextInput"):
		return false
	if not _steam.is_connected("gamepad_text_input_dismissed", done):
		_steam.connect("gamepad_text_input_dismissed", done, CONNECT_ONE_SHOT)
	var ok := bool(_steam.showGamepadTextInput(0, 0, description, max_len, ""))
	if not ok and _steam.is_connected("gamepad_text_input_dismissed", done):
		_steam.disconnect("gamepad_text_input_dismissed", done)   # V1.2.1 F3：鍵盤沒開成要解除，不然下次關閉會觸發舊動作
	return ok

static func run_callbacks() -> void:
	if _steam != null:
		_steam.run_callbacks()
		if not store_ok:
			_retry_tick += 1
			if _retry_tick >= 600:
				_retry_tick = 0
				store_ok = bool(_steam.storeStats())


## ── V1.4 #7 排行榜（每週棋盒＋幽靈陣）。沒有 Steam 時全部安靜略過。未在 Steam 後台建排行榜、未實測（不跑 --steam-test）。──
## 排行榜名稱 weekly_<週數>，分數＝花費（越少越好），附加資料（details，最多 64 個 int）放陣型：
## [版本 1, 兵數 n, 每隻 type*10000+col*100+row ...]。下載前幾名的 details 就能還原成「玩家幽靈陣」。
const LB_VER := 1

static func pack_army(units: Array) -> PackedInt32Array:
	var out := PackedInt32Array([LB_VER, mini(units.size(), 60)])
	for i in mini(units.size(), 60):
		var u: Dictionary = units[i]
		if not u.has("col"):
			return PackedInt32Array()   # 自由排兵的陣不上傳
		out.append(int(u["type"]) * 10000 + int(u["col"]) * 100 + int(u["row"]))
	return out

static func unpack_army(d: PackedInt32Array) -> Array:
	var out: Array = []
	if d.size() < 2 or d[0] != LB_VER or d[1] != d.size() - 2:
		return out
	for i in range(2, d.size()):
		var v := int(d[i])
		var t := v / 10000
		var c := (v / 100) % 100
		var r := v % 100
		if t < 0 or t >= 40 or c < 0 or c >= 32 or r < 0 or r >= 16:
			return []
		out.append({"type": t, "col": c, "row": r})
	return out

static var _lb_pending := {}   # 排行榜名稱 → 等找到 handle 後要送的 [分數, details]

static func weekly_upload(wk: int, score: int, army) -> void:
	if _steam == null or not _steam.has_method("findOrCreateLeaderboard"):
		return
	var det := pack_army(army.units)
	var name := "weekly_%d" % wk
	_lb_pending[name] = [score, det]
	if not _steam.is_connected("leaderboard_find_result", _on_lb_found):
		_steam.connect("leaderboard_find_result", _on_lb_found)
	_steam.findOrCreateLeaderboard(name, 1, 1)   # 1＝分數越小越前面、1＝顯示數字

static func _on_lb_found(handle: int, found: int) -> void:
	if found == 0 or _steam == null:
		return
	var name := str(_steam.getLeaderboardName(handle)) if _steam.has_method("getLeaderboardName") else ""
	if not _lb_pending.has(name):
		return
	var p: Array = _lb_pending[name]
	_lb_pending.erase(name)
	_steam.uploadLeaderboardScore(int(p[0]), true, p[1], handle)

## 抓這週排行榜前 20 名的陣（給遊戲間的「玩家幽靈」用）。done(armies: Array)；沒有 Steam 直接回空陣列。
static func ghost_fetch(wk: int, done: Callable) -> void:
	if _steam == null or not _steam.has_method("downloadLeaderboardEntries"):
		done.call([])
		return
	_steam.setLeaderboardDetailsMax(64)
	var name := "weekly_%d" % wk
	var on_found := func(handle: int, found: int) -> void:
		if found == 0:
			done.call([])
			return
		var on_dl := func(_msg, _h, result: Array) -> void:
			var out: Array = []
			for e in result:
				var units := unpack_army(PackedInt32Array(e.get("details", [])))
				if not units.is_empty():
					out.append({"name": str(e.get("steam_id", "")), "units": units})
			done.call(out)
		_steam.connect("leaderboard_scores_downloaded", on_dl, CONNECT_ONE_SHOT)
		_steam.downloadLeaderboardEntries(0, 19, 0, handle)
	_steam.connect("leaderboard_find_result", on_found, CONNECT_ONE_SHOT)
	_steam.findLeaderboard(name)

