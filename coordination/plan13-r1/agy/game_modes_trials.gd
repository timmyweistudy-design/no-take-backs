extends "res://scripts/ui/screens/game_result.gd"
## V9 P6 模式：主題試煉、挑戰碼、遠征獎勵、雙人禁選、戰績頁、牌組。

## 主題試煉：10 關固定地圖＋AI 性格，玩家自己組牌。[地圖, 大小, 性格, 難度]
const TRIALS := [[1, 1, 2, 1], [2, 1, 3, 1], [3, 1, 3, 1], [4, 1, 1, 1], [5, 1, 4, 1],
	[1, 0, 1, 2], [2, 2, 4, 2], [3, 2, 2, 2], [4, 0, 3, 2], [5, 2, 5, 2]]

var trial_id := -1
var challenge_army = null       # 挑戰碼的對手陣型
var gauntlet_gold := 0
var gauntlet_cap := 0
var ban_left := [0, 0]
var ban_turn := 0

## ── 主題試煉 ──
func _start_trial(i: int) -> void:
	if _demo() and not i in Presets.DEMO_TRIALS:
		_toast(L.t("demo_locked"), true)
		return
	var t: Array = TRIALS[i]
	var r = Presets.make("standard", "ai", RS.mask(_demo()))
	r.deploy = "free"
	r.spacing = 800
	r.depth = 6000
	r.fullfield = 0
	r.map_id = int(t[0])
	r.map_size = int(t[1])
	var s: Array = MapDefs.SIZE_SUGGEST[r.map_size]
	r.budget = [int(s[0]), int(s[0])]
	r.unit_cap = int(s[1])
	r.ticks = int(s[2])
	r.rounds = 1
	r.ai_level = int(t[3])
	r.ai_style = int(t[2])
	r.ai_pool_same = false
	var p := 0
	if AI.STYLE_TYPES.has(r.ai_style):
		for x in AI.STYLE_TYPES[r.ai_style]:
			p |= 1 << int(x)
	else:
		p = RuleSet.all_pool()
	if _demo():
		p &= RS.mask(true)
	r.pool[1] = p
	r.preset = "custom"
	rules = r
	challenge_army = null      # 上一場挑戰碼的敵陣不能留到試煉（Codex #5）
	rng.seed = 7000 + i        # 同一關每次是同一支隊伍
	_start_mode(Mode.VS_AI)
	trial_id = i

## 第十二輪：每達成一項一顆星，和殘局同一套。原本要花 ≤80% 預算還要剩「整個預算」的 50%，電腦都找不到解。
const TRIAL_REM := [0, 30, 20]     # 剩餘戰力門檻（依難度，索引同 AI 等級）
const TRIAL_SPEND_PCT := 80
const TRIAL_SPEND_OVERRIDE := {7: 85}   # 第 8 關：80% 搜尋 13 組種子都到不了，最好是 23% 剩餘花 81%

static func trial_spend_pct(id: int) -> int:
	return int(TRIAL_SPEND_OVERRIDE.get(id, TRIAL_SPEND_PCT))

static func trial_stars(level: int, rem: int, spent: int, budget: int, spend_pct: int = TRIAL_SPEND_PCT) -> int:
	var st := 1
	if rem >= int(TRIAL_REM[level]):
		st += 1
	if spent * 100 <= budget * spend_pct:
		st += 1
	return st

func _trial_finish(w: int) -> void:
	if trial_id < 0 or w != 0:
		return
	var lvl: int = int(TRIALS[trial_id][3])
	var rem: int = PZ.rem_pct(sim.power(0), sim.budget_of(0))
	var spent: int = armies[0].spent()
	var pct: int = trial_spend_pct(trial_id)
	var st: int = trial_stars(lvl, rem, spent, armies[0].budget, pct)
	report["trial_lines"] = call("_star_lines", true, rem, int(TRIAL_REM[lvl]), spent, armies[0].budget * pct / 100)
	var all: Dictionary = Save.data.get("trial_stars", {})
	all[str(trial_id)] = maxi(int(all.get(str(trial_id), 0)), st)
	Save.data["trial_stars"] = all
	report["trial_stars"] = st
