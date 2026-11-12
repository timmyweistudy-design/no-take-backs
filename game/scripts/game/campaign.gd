extends RefCounted
## 1.2.0 §11.7 戰役「老闆的棋館」：5 章 ×（6 戰＋1 殘局），資料 data/campaign.json（tools/gen/campaign_gen.py）。
## 進度存在 Save.data["campaign"]＝{關卡 id: 星數}；殘局關看 puzzle_stars。照順序解鎖；失敗可以無限重試。
## 獎勵只有外觀：每通一章，塗裝室的解鎖點數 +1（和成就數相加）。不解鎖兵種（不靠場數解鎖原則照舊）。純函式。
const PZ = preload("res://scripts/game/puzzles.gd")
const AI = preload("res://scripts/core/ai_army.gd")
const RuleSet = preload("res://scripts/core/ruleset.gd")
static var _data := {}

static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open("res://data/campaign.json", FileAccess.READ)
		_data = JSON.parse_string(f.get_as_text()) if f != null else {"chapters": []}
	return _data

static func chapters() -> Array:
	return data().get("chapters", [])

static func stage(id: String) -> Dictionary:
	for ch in chapters():
		for st in ch["stages"]:
			if str(st["id"]) == id:
				return st
	return {}

## 殘局關對應的殘局 id（那一個殘局章節的第一關）
static func puzzle_id(st: Dictionary) -> String:
	var lst: Array = PZ.chapter(int(st.get("puzzle_chapter", 1)))
	return str(lst[0]["id"]) if not lst.is_empty() else ""

static func stars_of(save: Dictionary, st: Dictionary) -> int:
	if str(st.get("goal", "")) == "puzzle":
		return int(save.get("puzzle_stars", {}).get(puzzle_id(st), 0))
	return int(save.get("campaign", {}).get(str(st["id"]), 0))

## 照順序：前一關（含跨章的前一章最後一關）有星才開
static func unlocked(save: Dictionary, id: String) -> bool:
	var prev := {}
	for ch in chapters():
		for st in ch["stages"]:
			if str(st["id"]) == id:
				return prev.is_empty() or stars_of(save, prev) > 0
			prev = st
	return false

static func chapter_cleared(save: Dictionary, ch: Dictionary) -> bool:
	for st in ch["stages"]:
		if stars_of(save, st) <= 0:
			return false
	return true

static func cleared(save: Dictionary) -> int:
	var n := 0
	for ch in chapters():
		if chapter_cleared(save, ch):
			n += 1
	return n

## 這一關的規則與敵陣（確定性）
static func rules_of(st: Dictionary):
	var r = RuleSet.standard()
	r.handicap = true
	r.budget = [RuleSet.STD_BUDGET, int(st["enemy_budget"])]
	r.ai_level = int(st.get("ai", 0))
	return r

static func enemy_of(st: Dictionary, r):
	var g := RandomNumberGenerator.new()
	g.seed = int(st["seed"])
	return AI.build(1, r.budget_of(1), g, -1, r.pool_of(1), r)["army"]

## 結算：目標達成給 1 星；剩餘戰力 ≥40% 再 1 星、≥70% 再 1 星。沒達成＝0。
## keep：贏且我方（不含召喚）至少 N 隻活著；time：贏且 tick ≤ 秒×20。
static func grade(st: Dictionary, won: bool, alive0: int, ticks: int, rem_pct: int) -> int:
	if not won:
		return 0
	match str(st.get("goal", "win")):
		"keep":
			if alive0 < int(st.get("keep", 1)):
				return 0
		"time":
			if ticks > int(st.get("secs", 60)) * 20:
				return 0
	return 1 + (1 if rem_pct >= 40 else 0) + (1 if rem_pct >= 70 else 0)

static func record(save: Dictionary, id: String, stars: int) -> bool:
	var c: Dictionary = save.get("campaign", {})
	if stars <= int(c.get(id, 0)):
		return false
	c[id] = stars
	save["campaign"] = c
	return true

static func sanitize(raw) -> Dictionary:
	var out := {}
	if raw is Dictionary:
		for k in raw:
			if k is String and k.length() <= 12 and (raw[k] is int or raw[k] is float):
				out[k] = clampi(int(raw[k]), 0, 3)
	return out
