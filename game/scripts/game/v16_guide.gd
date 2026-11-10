extends RefCounted
## V1.6 #1 新手到試玩結尾：首頁「建議下一步」、入口「新」標記、試玩版結尾。純函式（測試共用）。
const Save = preload("res://scripts/game/save.gd")

## 建議下一步：依進度挑最前面還沒做的一件。回傳鍵（""＝都做過了，不顯示）
## data＝存檔、daily_done＝今天每日打過了、demo＝試玩版
static func next_step(data: Dictionary, daily_done: bool, demo: bool) -> String:
	var f: Dictionary = data.get("funnel", {})
	if int(data.get("tutorial", 0)) == 0 and not f.has("tutorial_done"):
		return "tut"
	if ai_count(data, "games") == 0:
		return "ai"
	if not demo and not (data.get("gauntlet_run", {}) as Dictionary).is_empty():
		return "gauntlet_cont"   # V1.0.0 N6：有沒打完的遠征，先接著打
	if (data.get("puzzle_stars", {}) as Dictionary).is_empty():
		return "puzzle"
	if (data.get("puzzle_stars", {}) as Dictionary).size() < PUZZLE_FIRST and ai_count(data, "wins") == 0:
		return "puzzle_more"   # V1.0.0 N6：第一小時先把殘局第 1 章打熟（5 關或贏一場 AI 後才推別的）
	if demo:
		return ""
	if not daily_done:
		return "daily"
	if int(data.get("gauntlet_best", 0)) == 0 and (data.get("gauntlet_run", {}) as Dictionary).is_empty():
		return "gauntlet"
	if not f.has("playroom_open"):
		return "playroom"
	if (data.get("trial_stars", {}) as Dictionary).is_empty():
		return "trials"
	if games_of(data) >= NEW_AFTER:
		for k in V16_ENTRIES:
			if is_new(data, k):
				return "v16:" + k   # V1.6.1 N1：玩滿門檻後才推新玩法（一次一個）
	return ""

const PUZZLE_FIRST := 5

## 對 AI 的場數／勝場（V1.0.0 起另記 ai_games、ai_wins；老存檔沒有就用舊的 stats，估多了只是少推一步）
static func ai_count(data: Dictionary, k: String) -> int:
	if data.has("ai_" + k):
		return int(data["ai_" + k])
	return int(data.get("stats", {}).get(k, 0))

## 「繼續殘局」：照章節順序第一個還沒過的殘局 id（全過了回 ""）。
static func next_puzzle_id(data: Dictionary, all: Array) -> String:
	var st: Dictionary = data.get("puzzle_stars", {})
	for p in all:
		if not st.has(str(p["id"])):
			return str(p["id"])
	return ""

## V1.6.1 N1（三方 v161d §0-2）：V1.6 新玩法要先完成 NEW_AFTER 場有效對局（stats.games：正式對局，不含教學、觀戰、重播）
## 才標「新」、才進建議清單；入口照舊全開。
const V16_ENTRIES := ["rush_open", "trio_open", "rift_open", "fog_open", "ed_open", "coop_open"]
const NEW_AFTER := 3
## 有效對局：V1.6.1 起另外計 eff_games（正式對局，不含教學、觀戰、重播、沙盒，標準與自訂規則都算；Codex v161-i1 #11）。
## 升級的老玩家第一次開：用舊統計（標準＋自訂）當起點（seed_eff）。這是估計（舊統計分不出教學重打），
## 只影響「什麼時候開始推新玩法」，估多了最多早一點推，不擋任何東西（Codex v161-i2 #3 的裁決見 ledger）。
static func games_of(data: Dictionary) -> int:
	return int(data.get("eff_games", 0))

static func seed_eff(data: Dictionary) -> void:
	if data.has("eff_games"):
		return
	var n := 0
	for k in ["stats", "custom_stats"]:
		var st = data.get(k, {})
		if st is Dictionary:
			n += int(st.get("games", 0))
	data["eff_games"] = n

## V1.6.1 N2：老玩家（V1.6.1 之前就玩過）第一次開，跳一次新玩法導覽
static func tour_due(data: Dictionary, demo: bool) -> bool:
	return not demo and games_of(data) >= NEW_AFTER and not (data.get("seen", []) as Array).has("tour161")

## V1.6 之前就有的入口（老玩家升級時直接算看過；V1.6 新入口對每個人都標「新」）
const OLD_ENTRIES := ["menu_tutorial", "menu_vs_ai", "menu_duel", "menu_puzzle", "menu_trials", "menu_daily", "wk_open", "gh_open",
	"menu_codex", "paint_open", "menu_profile", "nem_open", "pr_wager", "pr_draft", "pr_waves", "pr_sealed"]

## 第一次用 V1.6 開遊戲：老玩家把舊入口記成看過（新玩家全部都是新的，但新玩家看到滿滿「新」沒意義 → 新玩家也只標 V1.6 新入口）
static func seed_seen(data: Dictionary) -> void:
	if not data.has("seen"):
		data["seen"] = OLD_ENTRIES.duplicate()

## V1.0.0：入口換位置後新出現的卡片鍵，但玩法是老的（單人遠征原本是主畫面木牌）：不標「新」
const NEVER_NEW := ["menu_gauntlet"]
static func is_new(data: Dictionary, key: String) -> bool:
	if key in NEVER_NEW:
		return false
	if key in V16_ENTRIES and games_of(data) < NEW_AFTER:
		return false   # 新手前幾場先不標（資訊量），玩滿門檻才標
	return not (data.get("seen", OLD_ENTRIES) as Array).has(key)

static func see(data: Dictionary, key: String) -> void:
	var s: Array = data.get("seen", OLD_ENTRIES.duplicate())
	if not s.has(key):
		s.append(key)
	data["seen"] = s

## 試玩版結尾：試玩版打滿 DEMO_END_GAMES 場（含教學、殘局）且這次還沒出現過
const DEMO_END_GAMES := 4
static func demo_end_due(data: Dictionary, demo: bool, shown_this_run: bool) -> bool:
	return demo and not shown_this_run and int(data.get("stats", {}).get("games", 0)) + int(data.get("tutorial", 0)) >= DEMO_END_GAMES
