extends RefCounted
## V1.6 #1 新手到試玩結尾：首頁「建議下一步」、入口「新」標記、試玩版結尾。純函式（測試共用）。
const Save = preload("res://scripts/game/save.gd")

## 建議下一步：依進度挑最前面還沒做的一件。回傳鍵（""＝都做過了，不顯示）
## data＝存檔、daily_done＝今天每日打過了、demo＝試玩版
static func next_step(data: Dictionary, daily_done: bool, demo: bool) -> String:
	var f: Dictionary = data.get("funnel", {})
	if int(data.get("tutorial", 0)) == 0 and not f.has("tutorial_done"):
		return "tut"
	if int(data.get("stats", {}).get("games", 0)) == 0:
		return "ai"
	if (data.get("puzzle_stars", {}) as Dictionary).is_empty():
		return "puzzle"
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
	return ""

## V1.6 之前就有的入口（老玩家升級時直接算看過；V1.6 新入口對每個人都標「新」）
const OLD_ENTRIES := ["menu_tutorial", "menu_vs_ai", "menu_duel", "menu_puzzle", "menu_trials", "menu_daily", "wk_open", "gh_open",
	"menu_codex", "paint_open", "menu_profile", "nem_open", "pr_wager", "pr_draft", "pr_waves", "pr_sealed"]

## 第一次用 V1.6 開遊戲：老玩家把舊入口記成看過（新玩家全部都是新的，但新玩家看到滿滿「新」沒意義 → 新玩家也只標 V1.6 新入口）
static func seed_seen(data: Dictionary) -> void:
	if not data.has("seen"):
		data["seen"] = OLD_ENTRIES.duplicate()

static func is_new(data: Dictionary, key: String) -> bool:
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
