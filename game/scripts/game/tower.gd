extends RefCounted
## 1.4.0 §11.1（1.3.0 延伸、stash 補完）：無盡塔——一路往上打，每層一種突變（沿用每日挑戰的 8 種）、地圖與 AI 性格輪換，
## 敵方預算每層多一點（上限 +60）；輸一場就結束，記最高層數（本機）。每層的規則與敵陣只由層數決定（固定種子、跨機器一樣）。
const Daily = preload("res://scripts/game/daily.gd")
const AI = preload("res://scripts/core/ai_army.gd")
const BONUS_STEP := 4     # 每層敵方多 4 金
const BONUS_MAX := 60

static func spec(floor_no: int) -> Dictionary:
	var f := maxi(1, floor_no)
	var mut := posmod(f - 1, Daily.MUTATORS)
	return {"floor": f, "mut": mut, "map": 3 if mut == 3 else posmod(f * 5 + 2, 6), "style": posmod(f * 3 + 1, 5),
		"level": clampi((f - 1) / 6, 0, 2), "seed": 70000 + posmod(f * 7919, 1000003), "bonus": mini(BONUS_MAX, (f - 1) * BONUS_STEP)}

## 這一層的規則：每日挑戰的規則（自由部署、單局、突變）再加敵方預算。
static func make_rules(sp: Dictionary, mask: int):
	var r = Daily.make_rules(sp, mask)
	var RS = load("res://scripts/core/ruleset.gd")
	r.budget = [int(r.budget_of(0)), mini(RS.BUDGET_MAX, int(r.budget_of(1)) + int(sp["bonus"]))]   # 大地圖本來就接近上限：加碼夾在合法範圍內
	r.handicap = int(r.budget[1]) != int(r.budget[0])   # 兩邊預算不同要開讓子，否則 budget_of 兩邊都取藍方（stash 原本漏了，測試抓到）
	return r

static func enemy(sp: Dictionary, r):
	return Daily.enemy(sp, r)

## 記最高層：過了第 f 層＝最高至少 f。回傳 [新最高, 是否刷新]。
static func record(best: int, cleared_floor: int) -> Array:
	return [maxi(best, cleared_floor), cleared_floor > best]

## 續局：下一次要打的層（0＝沒有進行中的塔）。贏了＝下一層、輸了＝清掉；壞資料＝0。
static func next_run(run: int, floor_no: int, won: bool) -> int:
	return floor_no + 1 if won else 0

static func sanitize_run(v) -> int:
	return clampi(int(v), 0, 100000) if (v is int or v is float) else 0
