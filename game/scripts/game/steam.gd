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
	# V1.5：只用既有事件與統計
	"GHOST_ALL": ["名將皆敗", "Ghostbuster"],
	"WEEKLY_WIN": ["本週破盒", "Box Breaker"],
	"WAVE_3": ["車輪不倒", "Last One Standing"],
	"REVENGE": ["雪恥", "Sweet Revenge"],
	"PAINTER": ["自己的顏色", "True Colors"],
	"SHARP_EYE": ["好眼力", "Sharp Eye"],
	"SEALED_DONE": ["封蠟三戰", "Sealed Fate"],
	# V1.6.1 D7：V1.6 玩法（極速賽、三考、裂隙、出題台、熟練度、接力遠征）
	"RUSH_10": ["極速十連", "Rush Ten"],
	"TRIO_STAR3": ["三考滿分", "Triple Threat"],
	"RIFT_WIN": ["裂隙行者", "Rift Walker"],
	"WORKBENCH": ["出題人", "Puzzle Setter"],
	"MASTER_5": ["熟能生巧", "Master Hand"],
	"COOP_CLEAR": ["接力到底", "Relay to the End"],
}

## 1.1.0 A15：成就分類（征戰 war、兵法 tac、收藏 col、遊戲間 room），和 docs/release/achievements 圖示的類別色一致（tools/gen/gen_ach_icons.py）
const ACH_CAT := {"FIRST_WIN": "war", "LONE_HERO": "tac", "COMEBACK": "war", "CLOSE_CALL": "war", "NO_TAKEBACKS": "tac", "HARD_WIN": "war", "SWEEP": "war", "TUTORIAL": "col", "PUZZLE_ALL": "col", "PUZZLE_3STAR": "col", "GAUNTLET": "war", "FRENZY_WIN": "war", "ALL_TYPES": "tac", "CHARGE_5": "tac", "BACKSTAB_3": "tac", "CUSTOM_LOWGOLD": "tac", "CUSTOM_UNDERDOG": "tac", "CUSTOM_BIG": "tac", "FANTASY_WIN": "war", "BOOM_5": "tac", "RAISE_3": "tac", "PUZZLE_100": "col", "PUZZLE_ALL3": "col", "TRIAL_ALL3": "col", "GHOST_ALL": "room", "WEEKLY_WIN": "room", "WAVE_3": "room", "REVENGE": "war", "PAINTER": "col", "SHARP_EYE": "room", "SEALED_DONE": "room", "RUSH_10": "room", "TRIO_STAR3": "room", "RIFT_WIN": "room", "WORKBENCH": "col", "MASTER_5": "col", "COOP_CLEAR": "room"}
const ACH_CAT_COL := {"war": Color(0.70, 0.23, 0.16), "tac": Color(0.17, 0.41, 0.66), "col": Color(0.20, 0.50, 0.28), "room": Color(0.47, 0.28, 0.63)}

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
		if not (Save.data.get("achievements", []) as Array).is_empty():
			ach_dirty = true
			_store()

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
		ach_dirty = true
		_store()
	return true

## V1.0.0 W3（Codex v100-i1 #2）：成就同步用「待送／在途／已確認」：
## - ach_dirty：本機有成就還沒確認存進 Steam（解鎖、啟動補送都會設）。
## - 送的時候把本機全部成就逐一 setAchievement（有一個回 false 就這次不送，等重試），再 storeStats → 在途。
## - 在途時又解鎖：只記 dirty，等這次回呼後再送一批。
## - user_stats_stored 結果 1（OK）且送出後沒有新的待送 → 確認（dirty 清掉）；不是 OK、或 ACH_CONFIRM_MS 內沒回呼 → 視為失敗，之後重送。
## - 沒有這個訊號的 SDK（測試替身）：storeStats 回 true 就當確認。
## store_ok＝目前沒有未確認的成就（給畫面與舊測試用）。
const ACH_CONFIRM_MS := 30000
const ACH_RETRY_TICKS := 600
static var ach_dirty := false
static var _ach_inflight := false
static var _ach_sent_at := 0
static var _ach_resend_after := false
static var _ach_stale := false   # 有一批確認逾時、回呼可能還會遲到（Codex v100-i2 #2）
static var _stats_wired := false
static func _store() -> void:
	if _steam == null:
		return
	if _ach_inflight:
		_ach_resend_after = true   # 在途：等回呼後再送
		return
	if _ach_stale:
		store_ok = false   # 有逾時那批的回呼還沒回來：不送新批（不然遲到的 OK 會確認新批）；等它回來，或下次開遊戲 init 補送（Codex v100-i3）
		return
	if not _stats_wired and _steam.has_signal("user_stats_stored"):
		_stats_wired = true
		_steam.connect("user_stats_stored", _on_stats_stored)
	var all_set := true
	for id in Save.data.get("achievements", []):
		if _steam.setAchievement(id) == false:
			all_set = false
	if not all_set:
		store_ok = false   # 設不進去（例如統計還沒收到）：整批等重試
		return
	var sent := bool(_steam.storeStats())
	if not sent:
		store_ok = false
		return
	if _stats_wired:
		_ach_inflight = true
		_ach_sent_at = _now()
		_ach_resend_after = false
		store_ok = false   # 等回呼確認
	else:
		ach_dirty = false
		store_ok = true

static func _on_stats_stored(_game, result) -> void:
	if _ach_stale:
		_ach_stale = false   # 逾時那一批的遲到回呼：吃掉（逾時後不送新批，所以這時不會有別批在途）
		return
	if not _ach_inflight:
		return
	_ach_inflight = false
	if int(result) == 1 and not _ach_resend_after:
		ach_dirty = false
		store_ok = true
	else:
		store_ok = false
		if _ach_resend_after:
			_ach_resend_after = false
			_store()

## 每幀：在途太久當失敗；有未確認的成就約每 10 秒重送一次。
static func ach_tick() -> void:
	if _ach_inflight and _now() - _ach_sent_at > ACH_CONFIRM_MS:
		_ach_inflight = false
		_ach_stale = true
		store_ok = false
	if not store_ok and not _ach_inflight:
		_retry_tick += 1
		if _retry_tick >= ACH_RETRY_TICKS:
			_retry_tick = 0
			_store()

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
	if expect_app_id != 480:
		out.merge(platform_report(_steam), true)   # 1.1.0 E2：雲端、分支、排行榜能力（唯讀，不影響 ok）
	if not out["ok"]:
		out["why"] = "有檢查項不符"
	return out

## 1.1.0 E2：上架後的唯讀證據（給 --steam-test 用）：雲端開關、雲端檔案清單（應只有 save.json、save.json.bak）、
## 目前分支（beta 測試時應是 beta 名稱）、排行榜 API 在不在。不寫入、不建榜。純函式吃 steam 物件（測試可給替身）。
const CLOUD_EXPECT := ["save.json", "save.json.bak"]
static func platform_report(st) -> Dictionary:
	var out := {}
	if st == null:
		return out
	if st.has_method("isCloudEnabledForAccount"):
		out["cloud_account"] = bool(st.isCloudEnabledForAccount())
	if st.has_method("isCloudEnabledForApp"):
		out["cloud_app"] = bool(st.isCloudEnabledForApp())
	if st.has_method("getFileCount") and st.has_method("getFileNameAndSize"):
		var files: Array = []
		for i in int(st.getFileCount()):
			var r = st.getFileNameAndSize(i)
			files.append(str(r.get("name", "")) if r is Dictionary else str(r))
		out["cloud_files"] = files
		out["cloud_unexpected"] = files.filter(func(n): return not str(n).get_file() in CLOUD_EXPECT)
	if st.has_method("getCurrentBetaName"):
		var b = st.getCurrentBetaName()
		out["beta"] = str(b.get("name", "")) if b is Dictionary else str(b)
	out["leaderboard_api"] = st.has_method("findOrCreateLeaderboard") and st.has_method("uploadLeaderboardScore") and st.has_method("downloadLeaderboardEntries")
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
		ach_tick()
		lb_tick()


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
	# 網路上來的資料不可信：版本、長度、兵種、格子範圍、重複格都要對（Codex、Antigravity v140-i5）
	var out: Array = []
	if d.size() < 3 or d.size() > 62 or d[0] != LB_VER or d[1] != d.size() - 2:
		return out
	var seen := {}
	for i in range(2, d.size()):
		var v := int(d[i])
		if v < 0:
			return []
		var t := v / 10000
		var c := (v / 100) % 100
		var r := v % 100
		if t >= 20 or c < 10 or c > 15 or r > 8 or seen.has(c * 100 + r):
			return []   # 幽靈陣一律是紅方（欄 10～15）
		seen[c * 100 + r] = true
		out.append({"type": t, "col": c, "row": r})
	return out

## ── V1.6 #13 每日全球榜：每日挑戰是自由座標，另一種打包。紅方視角（上傳前就鏡像好），
## 每隻＝type<<22 | (x/50)<<11 | (y/50)；版本 2。分數＝剩餘%×1000＋(999−花費)，越大越前面。
const LB_FREE_VER := 2
const FREE_MAX := 60

static func pack_free(units: Array, fw: int) -> PackedInt32Array:
	var out := PackedInt32Array([LB_FREE_VER, mini(units.size(), FREE_MAX)])
	for i in mini(units.size(), FREE_MAX):
		var u: Dictionary = units[i]
		if not u.has("x"):
			return PackedInt32Array()
		out.append((int(u["type"]) << 22) | (((fw - int(u["x"])) / 50) << 11) | (int(u["y"]) / 50))
	return out

static func unpack_free(d: PackedInt32Array, fw: int, fh: int) -> Array:
	var out: Array = []
	if d.size() < 3 or d.size() > FREE_MAX + 2 or d[0] != LB_FREE_VER or d[1] != d.size() - 2:
		return out
	var seen := {}
	for i in range(2, d.size()):
		var v := int(d[i])
		if v < 0:
			return []
		var t := v >> 22
		var x := ((v >> 11) & 2047) * 50
		var y := (v & 2047) * 50
		if t >= 20 or x <= fw / 2 or x >= fw or y <= 0 or y >= fh or seen.has(x * 100000 + y):
			return []   # 一律紅方半場、場內、不重疊
		seen[x * 100000 + y] = true
		out.append({"type": t, "x": x, "y": y})
	return out

static func daily_score(rem: int, spent: int) -> int:
	return clampi(rem, 0, 100) * 1000 + (999 - clampi(spent, 0, 999))

## V1.6.1 F2：榜名帶每日題目版本（`Daily.VER`）：AI 或題目產生器一改，新舊成績不混在同一個榜。
static func daily_board(day: int, ver: int) -> String:
	return "daily_%d_v%d" % [day, ver]

static func daily_upload(day: int, score: int, det: PackedInt32Array, ver := 1) -> void:
	if _steam == null or not _steam.has_method("findOrCreateLeaderboard") or det.is_empty():
		return
	_wire()
	_lb_put_up(daily_board(day, ver), [score, det, 2])   # 2＝分數越大越前面

static func daily_fetch(day: int, done: Callable, ver := 1) -> void:
	if _steam == null or not _steam.has_method("downloadLeaderboardEntries"):
		done.call([])
		return
	_wire()
	_lb_put_get(daily_board(day, ver), done, true)

static func weekly_upload(wk: int, score: int, det: PackedInt32Array) -> void:
	if _steam == null or not _steam.has_method("findOrCreateLeaderboard") or det.is_empty():
		return   # 沒有陣型資料（自由排兵）就不送，免得蓋掉原本帶陣型的紀錄
	_wire()
	_lb_put_up("weekly_%d" % wk, [score, det, 1])   # 1＝分數越小越前面

## 1.2.0 §11.9 每週天梯季：裂隙每週一套規則，本機最佳照舊，有 Steam 才送；榜名帶裂隙版本（規則產生器改了新舊不混）。
static func rift_board(wk: int, ver: int) -> String:
	return "rift_%d_v%d" % [wk, ver]

static func rift_upload(wk: int, score: int, det: PackedInt32Array, ver: int) -> void:
	if _steam == null or not _steam.has_method("findOrCreateLeaderboard") or det.is_empty():
		return
	_wire()
	_lb_put_up(rift_board(wk, ver), [score, det, 2])   # 2＝分數越大越前面

static func ghost_fetch(wk: int, done: Callable) -> void:
	if _steam == null or not _steam.has_method("downloadLeaderboardEntries"):
		done.call([])
		return
	_wire()
	_lb_put_get("weekly_%d" % wk, done, false)

## ── 排行榜請求（V1.0.0 W1／W2）：全部請求走同一條通道，同一時間只有一筆在途（Valve：上傳同時只能一筆）。
## 回呼一律對「現在在途的那一筆」：找榜用榜名對、上傳／下載用 handle 對，對不上的是逾時後才到的舊回呼，丟掉。
## 找榜失敗只結束在途那一筆：下載回空清單（畫面不會卡在讀取中），上傳的待送留在存檔、下次開模式補送。
## 逾時（LB_TIMEOUT_MS）一樣當失敗（下載回空），但通道不放：記成 _lb_stale，等那個遲到的回呼真的回來（找榜階段＝下一個找榜結果，
## 上傳／下載階段＝同一個 handle 的回呼）吃掉它，才送下一筆；一直沒來就一直不放（這段時間下載直接回空、上傳留著）。
## 上傳限額：任意 10 分鐘最多 10 次（Valve UploadLeaderboardScore 的限制），超過就留在佇列等。
## 同一個榜在佇列裡只留最新一筆上傳。
const LB_TIMEOUT_MS := 15000
const LB_WINDOW_MS := 600000
const LB_WINDOW_MAX := 10
static var _lb_q: Array = []        # 等著送的請求 {k:"up"/"get", name, p | done, free}
static var _lb_cur := {}            # 在途的那一筆（多 stage："find"／"up"／"dl"、handle、t0）
static var _lb_up_times: Array = [] # 真的送出上傳的時間（毫秒）
static var _lb_stale := {}         # 逾時的那一筆（stage、handle、name、score、until）
static var now_ms := -1             # 測試用：>= 0 時取代系統時間

static func _now() -> int:
	return now_ms if now_ms >= 0 else Time.get_ticks_msec()

static func _lb_put_up(name: String, p: Array) -> void:
	for r in _lb_q:
		if r["k"] == "up" and r["name"] == name:
			r["p"] = p   # 佇列裡同一個榜只留最新一筆
			_lb_pump()
			return
	_lb_q.append({"k": "up", "name": name, "p": p})
	_lb_pump()

static func _lb_put_get(name: String, done: Callable, free: bool) -> void:
	_lb_q.append({"k": "get", "name": name, "done": done, "free": free})
	_lb_pump()

static func _lb_window_ok() -> bool:
	var now := _now()
	_lb_up_times = _lb_up_times.filter(func(t): return now - int(t) < LB_WINDOW_MS)
	return _lb_up_times.size() < LB_WINDOW_MAX

static func _lb_pump() -> void:
	if _steam == null or not _lb_cur.is_empty():
		return
	if not _lb_stale.is_empty():
		# V1.0.0（Codex v100-i2 #1）：遲到回呼沒回來前通道一直不放（沒有請求身分，定時放行會配錯）。
		# 這段時間新的下載直接回空（畫面不卡在讀取中）；上傳留在佇列（待送本來就存在存檔，下次開遊戲也會補送）。
		var keep: Array = []
		for r0 in _lb_q:
			if r0["k"] == "get":
				(r0["done"] as Callable).call([])
			else:
				keep.append(r0)
		_lb_q = keep
		return
	var win := _lb_window_ok()
	for i in _lb_q.size():
		var r: Dictionary = _lb_q[i]
		if r["k"] == "up" and not win:
			continue   # 上傳超過限額：先送後面的下載
		_lb_q.remove_at(i)
		r["stage"] = "find"
		r["t0"] = _now()
		_lb_cur = r
		if r["k"] == "up":
			_steam.findOrCreateLeaderboard(r["name"], int(r["p"][2]), 1)
		else:
			if _steam.has_method("set_leaderboard_details_max"):
				_steam.set_leaderboard_details_max(64)   # 隨附的 GodotSteam 是這個名字（Codex v140-i5 對過 .so）
			_steam.findLeaderboard(r["name"])
		return

## 在途那一筆結束（ok＝false 時下載回空清單）。之後送下一筆。
static func _lb_finish(ok: bool) -> void:
	var r := _lb_cur
	_lb_cur = {}
	if not ok and r.get("k", "") == "get":
		(r["done"] as Callable).call([])
	_lb_pump()

## 每幀呼叫（run_callbacks 裡）：在途太久當失敗。
static func lb_tick() -> void:
	if _lb_cur.is_empty():
		if not _lb_q.is_empty():
			_lb_pump()   # 等限額或暫停結束
		return
	if _now() - int(_lb_cur["t0"]) > LB_TIMEOUT_MS:
		_lb_stale = {"stage": _lb_cur["stage"], "handle": int(_lb_cur.get("handle", -1)), "name": _lb_cur["name"],
			"score": int(_lb_cur["p"][0]) if _lb_cur["k"] == "up" else -1}
		_lb_finish(false)

## 遲到回呼（逾時那一筆的）：吃掉它、放開通道。上傳成功照樣清待送。回傳 true＝這個回呼是遲到的那個。
static func _lb_eat_stale(stage: String, handle: int, success := false) -> bool:
	if _lb_stale.is_empty() or _lb_stale["stage"] != stage or (stage != "find" and int(_lb_stale["handle"]) != handle):
		return false
	if stage == "up" and success and clear_pending(Save.data, _lb_stale["name"], int(_lb_stale["score"])):
		Save.save_data()
	_lb_stale = {}
	_lb_pump()
	return true

static var _lb_wired := false

static func _wire() -> void:
	if _lb_wired or _steam == null:
		return
	_lb_wired = true
	_steam.connect("leaderboard_find_result", _on_lb_found)
	_steam.connect("leaderboard_scores_downloaded", _on_lb_downloaded)
	_steam.connect("leaderboard_score_uploaded", _on_lb_uploaded)

static func _on_lb_found(handle: int, found: int) -> void:
	if _steam == null or _lb_eat_stale("find", handle):
		return
	if _lb_cur.is_empty() or _lb_cur["stage"] != "find":
		return
	if found == 0:
		_lb_finish(false)
		return
	if str(_steam.getLeaderboardName(handle)) != _lb_cur["name"]:
		return   # 逾時後才到的舊找榜結果
	_lb_cur["handle"] = handle
	_lb_cur["t0"] = _now()
	if _lb_cur["k"] == "up":
		_lb_cur["stage"] = "up"
		_lb_up_times.append(_now())
		_steam.uploadLeaderboardScore(int(_lb_cur["p"][0]), true, _lb_cur["p"][1], handle)
	else:
		_lb_cur["stage"] = "dl"
		_steam.downloadLeaderboardEntries(1, 20, 0, handle)   # 全球前 20 名（名次從 1 開始）

static func _on_lb_downloaded(_msg, handle: int, result: Array) -> void:
	if _lb_eat_stale("dl", handle):
		return
	if _lb_cur.is_empty() or _lb_cur["stage"] != "dl" or int(_lb_cur["handle"]) != handle:
		return
	var free: bool = _lb_cur["free"]
	var out: Array = []
	for e in result:
		var det := PackedInt32Array(e.get("details", []))
		var units := unpack_free(det, 16000, 9000) if free else unpack_army(det)
		if not units.is_empty():
			out.append({"name": str(e.get("steam_id", "")), "units": units, "score": int(e.get("score", 0)), "rank": int(e.get("global_rank", 0))})
	var done: Callable = _lb_cur["done"]
	_lb_cur = {}
	done.call(out)
	_lb_pump()

static func _on_lb_uploaded(success: bool, handle: int, _this_score: Dictionary) -> void:
	if _lb_eat_stale("up", handle, success):
		return
	if _lb_cur.is_empty() or _lb_cur["stage"] != "up" or int(_lb_cur["handle"]) != handle:
		return
	if success and clear_pending(Save.data, _lb_cur["name"], int(_lb_cur["p"][0])):
		Save.save_data()
	_lb_finish(true)

## 1.1.0 A21：遊戲結束時丟掉還在排隊／在途的請求（回呼會抓住畫面物件，留在 static 會變成結束時的洩漏）。不呼叫回呼。
static func lb_drop() -> void:
	_lb_q = []
	_lb_cur = {}

## 測試用：清掉排行榜狀態。
static func lb_reset() -> void:
	_lb_q = []
	_lb_cur = {}
	_lb_up_times = []
	_lb_stale = {}
	_lb_wired = false
	now_ms = -1

## V1.6.1 F2（Codex v161d r2）：送出到回呼之間可能又打出更好的成績（待送被換掉）。
## 只有待送的榜名與分數都和送出的那一筆相同才清；回傳有沒有清。純函式（測試用）。
static func clear_pending(data: Dictionary, name: String, score: int) -> bool:
	if name.begins_with("daily_"):
		var p: Dictionary = data.get("daily_pend", {})
		if not p.is_empty() and daily_board(int(p.get("day", -1)), int(p.get("ver", 1))) == name and int(p.get("score", -1)) == score:
			data.erase("daily_pend")
			return true
		return false
	if name.begins_with("rift_"):
		var rp: Dictionary = data.get("rift_pend", {})
		if not rp.is_empty() and rift_board(int(rp.get("wk", -1)), int(rp.get("ver", 0))) == name and int(rp.get("score", -1)) == score:
			data.erase("rift_pend")
			return true
		return false
	if name.begins_with("weekly_") and data.get("weekly") is Dictionary:
		var w: Dictionary = data["weekly"]
		if int(w.get("pend", 0)) == 1 and "weekly_%d" % int(w.get("wk", -1)) == name and int(w.get("best", -1)) == score:
			w["pend"] = 0   # 送上去了：不用補送
			return true
	return false

