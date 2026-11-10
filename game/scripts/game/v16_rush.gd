extends RefCounted
## V1.6 #8 殘局極速賽：限時連解輕量殘局（Puzzle Rush）。純函式（測試共用）。
## 題庫＝目標是「打贏」、沒有自帶地圖、軍令、隻數上限的殘局；依章節由淺到深，同章內用種子洗牌。
const PZ = preload("res://scripts/game/puzzles.gd")

const START_SEC := 180.0
const BONUS_SEC := 20.0     # 解開 +20 秒
const PENALTY_SEC := 15.0   # 失敗 −15 秒（直接換下一題，不卡關）

## V1.6.1 N5：有求解器指標（_m）的關再篩：模擬太長（> MAX_TICKS）或太難（隨機擺法過關率 < MIN_RAND%）的不進題庫。
## 舊 25 關沒有 _m（都是短的入門題）照收。
const MAX_TICKS := 1400
const MIN_RAND := 3

static func eligible(pz: Dictionary) -> bool:
	if not (PZ.goal(pz) == "win" and not pz.has("map") and not pz.has("cmd") and not pz.has("cap") and not pz.has("rules")):
		return false
	var m = pz.get("_m")
	if m is Dictionary:
		return int(m.get("ticks", 0)) <= MAX_TICKS and int(m.get("rand_pct", 100)) >= MIN_RAND
	return true

static func pool(seed: int) -> Array:
	var by_ch := {}
	for pz in PZ.all_puzzles():
		if not eligible(pz):
			continue
		var c := PZ.chapter_of(str(pz["id"]))
		if not by_ch.has(c):
			by_ch[c] = []
		by_ch[c].append(str(pz["id"]))
	var chs: Array = by_ch.keys()
	chs.sort()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var out: Array = []
	for c in chs:
		var lst: Array = by_ch[c]
		lst.sort()
		for i in range(lst.size() - 1, 0, -1):   # Fisher–Yates（固定種子）
			var j := rng.randi_range(0, i)
			var t = lst[i]
			lst[i] = lst[j]
			lst[j] = t
		out.append_array(lst)
	return out

static func after(left: float, solved: bool) -> float:
	return left + (BONUS_SEC if solved else -PENALTY_SEC)

## V1.6.1 D1：今日題組的種子（UTC 日數；同一版本同一天大家同一套題）
static func day_seed(day: int) -> int:
	return day * 7919 + 13

## 分享格（不劇透題目）：日期、解開幾題、每題一格
static func share_text(L, date: String, solved: int, tried: int) -> String:
	var cells := "■".repeat(clampi(solved, 0, 30)) + "□".repeat(clampi(tried - solved, 0, 30))
	return "\n".join([L.t("sh_rush_head", [date]), cells, L.t("sh_rush_line", [solved, tried]), L.t("sh_tag")])
