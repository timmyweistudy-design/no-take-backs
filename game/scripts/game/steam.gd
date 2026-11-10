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
	var name := daily_board(day, ver)
	_lb_up[name] = [score, det]
	_steam.findOrCreateLeaderboard(name, 2, 1)   # 2＝分數越大越前面

static func daily_fetch(day: int, done: Callable, ver := 1) -> void:
	if _steam == null or not _steam.has_method("downloadLeaderboardEntries"):
		done.call([])
		return
	_wire()
	if _steam.has_method("set_leaderboard_details_max"):
		_steam.set_leaderboard_details_max(64)
	var name := daily_board(day, ver)
	_lb_get[name] = done
	_steam.findLeaderboard(name)

## ── 請求管理：同一時間可能同時有「上傳每週成績」與「抓幽靈陣」，用排行榜名稱與 handle 對回自己的請求 ──
static var _lb_up := {}      # 名稱 → [分數, details]
static var _lb_get := {}     # 名稱 → done
static var _lb_dl := {}      # handle → done
static var _lb_sent := {}    # V1.6.1 F2：handle → [[榜名, 送出的分數], …]（同一個榜可能連送兩次：照送出順序排隊，回呼一次取一筆；Codex v161-i1 #1）
static var _lb_wired := false

static func _wire() -> void:
	if _lb_wired or _steam == null:
		return
	_lb_wired = true
	_steam.connect("leaderboard_find_result", _on_lb_found)
	_steam.connect("leaderboard_scores_downloaded", _on_lb_downloaded)
	_steam.connect("leaderboard_score_uploaded", _on_lb_uploaded)

static func weekly_upload(wk: int, score: int, det: PackedInt32Array) -> void:
	if _steam == null or not _steam.has_method("findOrCreateLeaderboard") or det.is_empty():
		return   # 沒有陣型資料（自由排兵）就不送，免得蓋掉原本帶陣型的紀錄
	_wire()
	var name := "weekly_%d" % wk
	_lb_up[name] = [score, det]
	_steam.findOrCreateLeaderboard(name, 1, 1)   # 1＝分數越小越前面、1＝顯示數字

static func ghost_fetch(wk: int, done: Callable) -> void:
	if _steam == null or not _steam.has_method("downloadLeaderboardEntries"):
		done.call([])
		return
	_wire()
	if _steam.has_method("set_leaderboard_details_max"):
		_steam.set_leaderboard_details_max(64)   # 隨附的 GodotSteam 是這個名字（Codex v140-i5 對過 .so）
	var name := "weekly_%d" % wk
	_lb_get[name] = done
	_steam.findLeaderboard(name)

static func _on_lb_found(handle: int, found: int) -> void:
	if _steam == null:
		return
	var name := str(_steam.getLeaderboardName(handle)) if found != 0 else ""
	if _lb_up.has(name):
		var p: Array = _lb_up[name]
		_lb_up.erase(name)
		var q: Array = _lb_sent.get(handle, [])
		q.append([name, int(p[0])])
		_lb_sent[handle] = q
		_steam.uploadLeaderboardScore(int(p[0]), true, p[1], handle)
	if _lb_get.has(name):
		_lb_dl[handle] = [_lb_get[name], name.begins_with("daily_")]
		_lb_get.erase(name)
		_steam.downloadLeaderboardEntries(1, 20, 0, handle)   # 全球前 20 名（名次從 1 開始）

static func _on_lb_downloaded(_msg, handle: int, result: Array) -> void:
	if not _lb_dl.has(handle):
		return
	var done: Callable = _lb_dl[handle][0]
	var free: bool = _lb_dl[handle][1]
	_lb_dl.erase(handle)
	var out: Array = []
	for e in result:
		var det := PackedInt32Array(e.get("details", []))
		var units := unpack_free(det, 16000, 9000) if free else unpack_army(det)
		if not units.is_empty():
			out.append({"name": str(e.get("steam_id", "")), "units": units, "score": int(e.get("score", 0)), "rank": int(e.get("global_rank", 0))})
	done.call(out)

static func _on_lb_uploaded(success: bool, handle: int, _this_score: Dictionary) -> void:
	var q: Array = _lb_sent.get(handle, [])
	if q.is_empty():
		return
	var sent: Array = q.pop_front()
	if q.is_empty():
		_lb_sent.erase(handle)
	if not success:
		return
	if clear_pending(Save.data, str(sent[0]), int(sent[1])):
		Save.save_data()

## V1.6.1 F2（Codex v161d r2）：送出到回呼之間可能又打出更好的成績（待送被換掉）。
## 只有待送的榜名與分數都和送出的那一筆相同才清；回傳有沒有清。純函式（測試用）。
static func clear_pending(data: Dictionary, name: String, score: int) -> bool:
	if name.begins_with("daily_"):
		var p: Dictionary = data.get("daily_pend", {})
		if not p.is_empty() and daily_board(int(p.get("day", -1)), int(p.get("ver", 1))) == name and int(p.get("score", -1)) == score:
			data.erase("daily_pend")
			return true
		return false
	if name.begins_with("weekly_") and data.get("weekly") is Dictionary:
		var w: Dictionary = data["weekly"]
		if int(w.get("pend", 0)) == 1 and "weekly_%d" % int(w.get("wk", -1)) == name and int(w.get("best", -1)) == score:
			w["pend"] = 0   # 送上去了：不用補送
			return true
	return false

