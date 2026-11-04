extends RefCounted
## AI 陣型（原型＝企劃 §7 的「普通」：從原型陣型挑一套再隨機微調）。
## AI 只在擺放時用亂數；戰鬥本身沒有亂數。

const D = preload("res://scripts/core/unit_defs.gd")
const Army = preload("res://scripts/core/army.gd")
const RS = preload("res://scripts/core/ruleset.gd")

# 權重順序：劍、盾、弓、騎、刺、槍、彈、醫、鼓、狂（第四輪加後 5 種）。
# 模板只會在「用到的兵種都在卡池裡」時被選（第五輪：pool＝卡池遮罩；經典 5 種＝0b11111）。
const TEMPLATES := [
	{"name": "均衡軍", "w": [3, 2, 3, 1, 1, 0, 0, 0, 0, 0]},
	{"name": "鐵壁弓陣", "w": [1, 4, 5, 0, 0, 0, 0, 0, 0, 0]},
	{"name": "鐵騎突擊", "w": [2, 1, 0, 5, 0, 0, 0, 0, 0, 0]},
	{"name": "暗影刺殺", "w": [3, 0, 2, 0, 4, 0, 0, 0, 0, 0]},
	{"name": "劍海", "w": [5, 2, 2, 0, 0, 0, 0, 0, 0, 0]},
	{"name": "騎射混編", "w": [0, 2, 3, 3, 0, 0, 0, 0, 0, 0]},
	{"name": "槍盾方陣", "w": [1, 3, 2, 0, 0, 4, 0, 0, 0, 0]},
	{"name": "砲擊陣", "w": [2, 3, 1, 0, 0, 1, 4, 0, 0, 0]},
	{"name": "醫療鐵壁", "w": [2, 3, 2, 0, 0, 1, 0, 2, 0, 0]},
	{"name": "戰鼓衝陣", "w": [4, 1, 0, 2, 1, 0, 0, 0, 2, 0]},
	{"name": "破陣突擊", "w": [2, 0, 3, 0, 0, 1, 0, 0, 0, 4]},
	# 第八輪奇幻軍（編號 10 孢子菇、11 羊、12 寶箱、13 史萊姆、14 幽靈、15 娃娃、16 沙漏、17 骷髏法師、18 吸塵貓、19 石魔）
	{"name": "黏黏大軍", "w": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 5, 1, 1, 1, 1, 0, 0]},
	{"name": "幽靈奇襲", "w": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 1, 2, 5, 0, 0, 1, 1, 0]},
	{"name": "亡靈法陣", "w": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 3, 1, 1, 1, 3, 0, 1]},
	{"name": "吸塵爆破", "w": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 4, 0, 2, 1, 0, 0, 0, 3, 1]},
	{"name": "石魔要塞", "w": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 1, 1, 2, 0, 2, 1, 0, 0, 3]},
	{"name": "混編傭兵", "w": [2, 1, 2, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 2, 1, 0, 0, 0, 1, 0]},
	{"name": "陷阱弓陣", "w": [2, 2, 3, 0, 0, 0, 0, 0, 0, 0, 2, 0, 2, 0, 0, 1, 0, 0, 0, 0]},
	{"name": "羊群衝鋒", "w": [3, 0, 2, 2, 0, 0, 0, 0, 0, 0, 0, 3, 0, 0, 1, 0, 0, 0, 0, 0]},
]

# 每種兵偏好的欄（以藍方 0～5 表示，0＝最後排、5＝最前排；紅方自動鏡像）
const PREF_COLS := [
	[5, 4, 3],          # 劍士：前排
	[5, 4],             # 盾兵：最前排
	[0, 1, 2],          # 弓箭手：後排
	[3, 2, 4],          # 騎兵：中排兩翼
	[2, 3, 1],          # 刺客：中後排
	[4, 3],             # 長槍兵：第二排
	[0, 1],             # 投彈兵：最後排
	[1, 2],             # 醫者：後排
	[3, 2],             # 鼓手：中間
	[5, 4],             # 狂戰士：前排
	[4, 3, 5],          # 孢子菇：中前排封路
	[2, 3, 1],          # 爆爆羊：留距離，別貼著主力
	[5, 4],             # 寶箱怪：陣前陷阱
	[5, 4],             # 史萊姆：前排
	[3, 2],             # 幽靈：中間
	[5, 4],             # 巫毒娃娃：前排
	[2, 3],             # 沙漏精靈：主力中央
	[0, 1],             # 骷髏法師：後排
	[3, 4],             # 吸塵貓：中前
	[5, 4],             # 小石魔：前排
]
# 擺放順序：前排先佔中間（盾、槍、劍、狂），再騎、刺、鼓、醫、彈、弓
const PLACE_ORDER := [1, 5, 0, 9, 3, 4, 8, 7, 6, 2, 19, 13, 15, 12, 10, 18, 14, 16, 11, 17]
const ROW_CENTER := [4, 3, 5, 2, 6, 1, 7, 0, 8]
const ROW_EDGE := [0, 8, 1, 7, 2, 6, 3, 5, 4]

## 這個模板用到的兵種是否都在卡池裡。
static func template_ok(ti: int, pool: int) -> bool:
	var w: Array = TEMPLATES[ti]["w"]
	for t in w.size():
		if w[t] > 0 and not RS.has(pool, t):
			return false
	return true

static func eligible_templates(pool: int) -> Array:
	var out: Array = []
	for ti in TEMPLATES.size():
		if template_ok(ti, pool):
			out.append(ti)
	return out

## pool：卡池遮罩（-1＝全部）；rules：第五輪 Ruleset（套人數／單種上限）。
## 標準卡池時亂數呼叫次數與順序和 1.3.0 相同（金標準靠這個）。
static func build(team: int, budget: int, rng: RandomNumberGenerator, template := -1, pool := -1, rules = null):
	if pool < 0:
		pool = RS.all_pool()
	var a = Army.new(team, budget)
	if rules != null:
		a.apply_rules(rules, team)
		a.budget = budget
		a.pool = pool
		if rules.is_free():
			a.deploy = "grid"   # 先用格子擺，最後再拉開成自由座標（free_from_grid）
			a.depth = 6000
			a.enemy_pos = []
	var el := eligible_templates(pool)
	if template >= 0 and not template_ok(template, pool):
		template = -1   # 指定的模板用到未開放的兵種：改從可用的模板抽（Codex 實作審查 #3）
	if el.is_empty() and template < 0:
		# 第五輪：奇怪的卡池（例如只有刺客＋醫者）沒有合格模板 → 用落子 AI 的選兵邏輯在卡池內組陣
		var AIT = load("res://scripts/core/ai_turns.gd")
		return {"army": AIT.fill_army(a, rng, 1, []), "name": "—"}
	var ti := template if template >= 0 else int(el[rng.randi_range(0, el.size() - 1)])
	var w: Array = TEMPLATES[ti]["w"]
	var picks: Array = []
	var guard := 0
	while a.left() >= D.cheapest() and picks.size() < a.unit_cap and guard < 200:
		guard += 1
		var total := 0
		for t in D.total():
			if RS.has(pool, t) and D.cost(t) <= a.left() - _cost_sum(picks) and t < w.size() and w[t] > 0 and _cap_ok(a, picks, t):
				total += w[t]
		if total == 0:
			break
		var r := rng.randi_range(1, total)
		for t in D.total():
			if RS.has(pool, t) and D.cost(t) <= a.left() - _cost_sum(picks) and t < w.size() and w[t] > 0 and _cap_ok(a, picks, t):
				r -= w[t]
				if r <= 0:
					picks.append(t)
					break
		if _cost_sum(picks) > a.left():
			picks.pop_back()
			break
	# 先放盾兵、劍士，再放其他（讓前排先佔中間）
	picks.sort_custom(func(p, q): return PLACE_ORDER.find(p) < PLACE_ORDER.find(q))
	for t in picks:
		_place_pref(a, t)
	if rules != null and a.can_afford_any() and not load("res://scripts/game/presets.gd").deploy_standard(rules):
		# 自訂規則：模板比例填完還有錢（單種上限、小卡池）→ 落子 AI 補滿
		var AIT2 = load("res://scripts/core/ai_turns.gd")
		AIT2.fill_army(a, rng, 1, [])
	if rules != null and rules.is_free():
		a = free_from_grid(a, rules)
	return {"army": a, "name": TEMPLATES[ti]["name"]}

## 第六輪：AI 的自由擺法——先用格子邏輯擺（亂數路徑不變），再依縱深把欄位等比拉開（§5「AI」）。
static func free_from_grid(a, rules):
	var F = load("res://scripts/core/formations.gd")
	return F.to_free(a, rules, null, "stretch")

static func _cap_ok(a, picks: Array, t: int) -> bool:
	var hc := D.hard_cap(t)
	if hc > 0 and picks.count(t) >= hc:
		return false
	if a.type_cap <= 0:
		return true
	return picks.count(t) < a.type_cap

static func _cost_sum(picks: Array) -> int:
	var s := 0
	for t in picks:
		s += D.cost(t)
	return s

static func _place_pref(a, t: int) -> void:
	var rows: Array = ROW_EDGE if t == D.CAVALRY else ROW_CENTER
	var cols: Array = PREF_COLS[t] + [5, 4, 3, 2, 1, 0]
	for c in cols:
		var col: int = c if a.team == 0 else Army.COLS - 1 - c
		for r in rows:
			if a.place(t, col, r):
				return
