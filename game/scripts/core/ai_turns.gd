extends RefCounted
## 會「讀對方」的落子 AI（優化方案 A2、C）。用在：輪流落子模式、平衡工具的先後手測試、AI 難度。
## 只看已經公開的資訊（對方已擺下的兵），不偷看。全部啟發式評分，不跑模擬，每手幾毫秒。

const D = preload("res://scripts/core/unit_defs.gd")
const Army = preload("res://scripts/core/army.gd")

# 剋制表：BEATS[a] 是 a 剋的兩種（企劃 §3.1）
const BEATS := [
	[D.ASSASSIN, D.SHIELD],     # 劍士
	[D.CAVALRY, D.ARCHER],      # 盾兵
	[D.SWORD, D.ASSASSIN],      # 弓箭手
	[D.ARCHER, D.SWORD],        # 騎兵
	[D.SHIELD, D.CAVALRY],      # 刺客
]
const ROLE_COLS := [[5, 4, 3], [5, 4], [0, 1, 2], [3, 2, 4], [2, 3, 1]]

static func counter_score(a: int, b: int) -> int:
	if b in BEATS[a]:
		return 1
	if a in BEATS[b]:
		return -1
	return 0

## 選一個兵種。level：0 簡單（隨機性高、不太看對方）、1 普通、2 困難。
static func choose_type(mine: Army, enemy_units: Array, budget_left: int, rng: RandomNumberGenerator, level := 1) -> int:
	var best := -1
	var best_s := -1.0e9
	var have := [0, 0, 0, 0, 0]
	for u in mine.units:
		have[u["type"]] += 1
	var front: int = have[D.SWORD] + have[D.SHIELD]
	for t in D.COUNT:
		if D.cost(t) > budget_left:
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
		var t := choose_type(mine, enemy.units, tp.turn_left(), rng, level)
		if t == -1:
			break
		var c := choose_cell(mine, t, enemy.units, rng)
		if c.x < 0 or not tp.place(t, c.x, c.y):
			break
		placed += 1
		# 每一手擺到花不下為止，但留一點讓節奏像真人：困難 AI 會在花超過 60% 後結束這一手，保留後手
		if tp.current == me and level == 2 and tp.spent_this_turn * 10 >= tp.hand_cap() * 6 and tp.can_end_turn():
			tp.end_turn()
			break
	if tp.current == me and not tp.done():
		tp.end_turn()
	return placed

## 自由擺放（對 AI 模式）：知道對方「上一局」的陣型（困難才用），一次擺滿。
static func build_full(team: int, rng: RandomNumberGenerator, level: int, known_enemy: Array) -> Army:
	var a := Army.new(team, 100)
	var guard := 0
	while a.can_afford_any() and guard < 40:
		guard += 1
		var t := choose_type(a, known_enemy if level == 2 else [], a.left(), rng, level)
		if t == -1:
			break
		var c := choose_cell(a, t, known_enemy if level >= 1 else [], rng)
		if c.x < 0:
			break
		a.place(t, c.x, c.y)
	return a
