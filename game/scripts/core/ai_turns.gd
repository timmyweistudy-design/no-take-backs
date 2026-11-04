extends RefCounted
## 會「讀對方」的落子 AI（優化方案 A2、C）。用在：輪流落子模式、平衡工具的先後手測試、AI 難度。
## 只看已經公開的資訊（對方已擺下的兵），不偷看。全部啟發式評分，不跑模擬，每手幾毫秒。

const D = preload("res://scripts/core/unit_defs.gd")
const RS = preload("res://scripts/core/ruleset.gd")
const Army = preload("res://scripts/core/army.gd")

# 剋制表：BEATS[a] 是 a 剋的兩種（企劃 §3.1）
const BEATS := [
	[D.ASSASSIN, D.SHIELD, 14],     # 劍士
	[D.CAVALRY, D.ARCHER, 14],      # 盾兵
	[D.SWORD, D.ASSASSIN, D.BERSERKER, D.BOMBER, 10, 11, 15, 18],      # 弓箭手
	[D.ARCHER, D.SWORD, D.BOMBER, D.MEDIC, 17],            # 騎兵
	[D.SHIELD, D.CAVALRY, D.MEDIC, D.DRUMMER, 16, 17, 18, 19],         # 刺客
	[D.CAVALRY, 11],                # 長槍兵（第四輪 §2.6）
	[D.SHIELD, D.PIKE, D.DRUMMER, 10, 12, 13],   # 投彈兵
	[],                         # 醫者（支援，不列）
	[],                         # 鼓手（支援，不列）
	[D.SHIELD, D.PIKE, 19],         # 狂戰士（破陣）
	# 第八輪（10 孢子菇 … 19 小石魔）
	[D.SWORD, D.BERSERKER, 15],     # 孢子菇
	[D.SHIELD, D.PIKE],             # 爆爆羊：撞盾牆、密集陣
	[D.CAVALRY, D.ASSASSIN],        # 寶箱怪
	[D.SWORD, D.ASSASSIN],          # 史萊姆
	[D.ARCHER, D.BOMBER, 16],       # 幽靈
	[D.BERSERKER, D.CAVALRY],       # 巫毒娃娃
	[],                             # 沙漏精靈（支援）
	[10, 19],                       # 骷髏法師：打慢吞吞的
	[D.BOMBER, D.MEDIC],            # 吸塵貓
	[D.CAVALRY, D.SWORD],           # 小石魔
]
## 支援兵的協同對象（第四輪 §4.1：提示條「協同」顯示用）
const SYNERGY := {D.MEDIC: [D.SHIELD, D.SWORD], D.DRUMMER: [D.SWORD, D.PIKE], 16: [D.SHIELD, 19]}
const ROLE_COLS := [[5, 4, 3], [5, 4], [0, 1, 2], [3, 2, 4], [2, 3, 1], [4, 3], [0, 1], [1, 2], [3, 2], [5, 4], [4, 3, 5], [2, 3, 1], [5, 4], [5, 4], [3, 2], [5, 4], [2, 3], [0, 1], [3, 4], [5, 4]]

static func counter_score(a: int, b: int) -> int:
	if b in BEATS[a]:
		return 1
	if a in BEATS[b]:
		return -1
	return 0

## 選一個兵種。level：0 簡單（隨機性高、不太看對方）、1 普通、2 困難。
## pool：卡池遮罩（-1＝看 mine.pool）。第五輪：也遵守單種上限與防卡死（買不起戰鬥兵時不選支援兵）。
static func choose_type(mine: Army, enemy_units: Array, budget_left: int, rng: RandomNumberGenerator, level := 1, pool := -1) -> int:
	if pool < 0:
		pool = mine.pool
	var best := -1
	var best_s := -1.0e9
	var have := D.zeros()
	for u in mine.units:
		have[u["type"]] += 1
	var front: int = have[D.SWORD] + have[D.SHIELD] + have[D.PIKE] + have[D.BERSERKER] + have[13] + have[19]
	var fighters := 0
	for u in mine.units:
		if D.is_combat(u["type"]):
			fighters += 1
	for t in D.total():
		if not RS.has(pool, t) or D.cost(t) > budget_left:
			continue
		if mine.type_cap > 0 and have[t] >= mine.type_cap:
			continue
		if D.hard_cap(t) > 0 and have[t] >= D.hard_cap(t):
			continue
		if mine.guard_combat and not D.is_combat(t) and fighters == 0 and (mine.left() - D.cost(t) < mine.cheapest_combat() or mine.count() + 1 >= mine.unit_cap):
			continue
		var s := 0.0
		var react := 0.4 if level == 0 else (1.0 if level == 1 else 1.6)
		for e in enemy_units:
			s += counter_score(t, e["type"]) * react
			# 已經有的兵也要能應付對方
		for u in mine.units:
			s -= 0.15 * (1 if u["type"] == t else 0)   # 避免全押同一種
		if front < 3 and (t == D.SWORD or t == D.SHIELD):
			s += 1.2
		if t >= D.COUNT and not D.is_combat(t) and not D.is_support(t):
			s += 0.4 if fighters >= 3 and have[t] < 3 else -1.5   # 第八輪：奇襲兵要有主力才帶
		if D.is_support(t):
			# 支援兵：要有夠多戰鬥兵才值得帶，而且一種最多帶 2 隻
			s += 0.5 if fighters >= 5 and have[t] < 2 else -2.0
		s += float(D.cost(t)) * 0.05                       # 錢花得完
		var noise := 1.5 if level == 0 else (0.6 if level == 1 else 0.25)
		s += rng.randf() * noise
		if s > best_s:
			best_s = s
			best = t
	return best

## 選位置：依兵種角色欄位；騎兵往敵方弓手多、盾兵少的那一側；盾兵擋在敵方騎兵／弓手集中的列。
static func choose_cell(mine: Army, t: int, enemy_units: Array, rng: RandomNumberGenerator) -> Vector2i:
	var want_row := 4
	if not enemy_units.is_empty():
		var sum := 0
		var cnt := 0
		for e in enemy_units:
			var et: int = e["type"]
			if t == D.CAVALRY and et == D.ARCHER:
				sum += e["row"] * 3
				cnt += 3
			elif t == D.CAVALRY and et == D.SHIELD:
				sum += (8 - e["row"]) * 2
				cnt += 2
			elif t == D.SHIELD and (et == D.CAVALRY or et == D.ARCHER):
				sum += e["row"] * 2
				cnt += 2
			else:
				sum += e["row"]
				cnt += 1
		want_row = clampi(int(round(float(sum) / cnt)), 0, 8)
	elif t == D.CAVALRY:
		want_row = 0 if rng.randf() < 0.5 else 8
	var cols: Array = ROLE_COLS[t] + [5, 4, 3, 2, 1, 0]
	for c in cols:
		var col: int = c if mine.team == 0 else Army.COLS - 1 - c
		for dr in 9:
			for sgn in [1, -1]:
				var r: int = want_row + dr * sgn
				if r < 0 or r > 8:
					continue
				if mine.check_place(t, col, r) == "":
					return Vector2i(col, r)
	return Vector2i(-1, -1)

## 在輪流落子裡走一手（可能擺多隻直到這一手花不下）。回傳擺了幾隻。
static func play_turn(tp, rng: RandomNumberGenerator, level := 1) -> int:
	var me: int = tp.current
	var mine: Army = tp.armies[me]
	var enemy: Army = tp.armies[1 - me]
	var placed := 0
	var guard := 0
	while not tp.done() and tp.current == me and guard < 30:
		guard += 1
		var pl: int = tp.pool_of(me)
		if tp.rules != null and mine.guard_combat and not mine.has_combat() and tp.is_snake() and tp.hands_done[me] >= tp.hands_max() - 1:
			pl &= ~((1 << D.MEDIC) | (1 << D.DRUMMER))   # 最後一手還沒有戰鬥兵：只選戰鬥兵
		var t := choose_type(mine, enemy.units, tp.turn_left(), rng, level, pl)
		if t == -1:
			break
		var c := choose_cell(mine, t, enemy.units, rng)
		if c.x < 0 or not tp.place(t, c.x, c.y):
			break
		placed += 1
		# 困難 AI 在「沒花完的錢會累積」的規則（snake5c）才會花到 60% 就收手、保留後手。
		# 第三輪 S6 抓到：原本所有規則都這樣做，snake5／cap10 沒花完的錢會直接浪費（每方只花 70 金），先手勝率被扭曲成 86%。
		if tp.current == me and level == 2 and tp.rule == "snake5c" and tp.spent_this_turn * 10 >= tp.hand_cap() * 6 and tp.can_end_turn():
			tp.end_turn()
			break
	if tp.current == me and not tp.done():
		tp.end_turn()
	return placed

## 自由擺放（對 AI 模式）：知道對方「上一局」的陣型（困難才用），一次擺滿。
## pool：卡池遮罩（-1＝全部）；rules：第五輪 Ruleset（預算、人數、單種上限）。
static func build_full(team: int, rng: RandomNumberGenerator, level: int, known_enemy: Array, pool := -1, rules = null) -> Army:
	var a := Army.new(team, 100)
	if rules != null:
		a.apply_rules(rules, team)
	if pool >= 0:
		a.pool = pool
	if rules != null and rules.is_free():
		a.deploy = "grid"
		a.depth = 6000
		a.enemy_pos = []
		var g := fill_army(a, rng, level, _grid_known(known_enemy))
		return load("res://scripts/core/ai_army.gd").free_from_grid(g, rules)
	return fill_army(a, rng, level, known_enemy)

## 困難 AI 讀上一局（自由座標）時，換成最近的格子給格子邏輯用。
static func _grid_known(known: Array) -> Array:
	var out: Array = []
	for u in known:
		if u.has("col"):
			out.append(u)
		else:
			out.append({"type": u["type"], "col": clampi(int(u["x"]) / 1000, 0, 15), "row": clampi(int(u["y"]) / 1000, 0, 8)})
	return out

## 把一支軍隊擺到買不起為止（第五輪：不再寫死 100 金、40 次）。
static func fill_army(a: Army, rng: RandomNumberGenerator, level: int, known_enemy: Array) -> Army:
	var guard := 0
	var limit: int = (a.budget / 4 + 10) if a.guard_combat else 40   # 標準路徑維持 40 次（亂數呼叫次數不變）
	while a.can_afford_any() and guard < limit:
		guard += 1
		var t := choose_type(a, known_enemy if level == 2 else [], a.left(), rng, level)
		if t == -1:
			break
		var c := choose_cell(a, t, known_enemy if level >= 1 else [], rng)
		if c.x < 0:
			break
		a.place(t, c.x, c.y)
	return a
