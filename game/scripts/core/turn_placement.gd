extends RefCounted
## 輪流落子（企劃 §4.1、優化方案 A2）。公開輪流擺，擺下不能移動或收回；買得起就不能跳過。
## 規則：
##   "cap10"   ＝每一手 1～10 金、至少 1 隻；輪流直到雙方都買不起（原型規則）。
##   "snake5"  ＝每人 5 手、每手最多 20 金，蛇行 A‑B‑B‑A‑A‑B‑B‑A‑A‑B；沒花完的錢不累積。
##   "snake5c" ＝同上，但沒花完的錢累積到下一手（第 k 手最多花到累計 20×k）。
## 每一手都記成指令（commands），可以重播、序列化（為 v1.1 線上預留）。

const D = preload("res://scripts/core/unit_defs.gd")

const SNAKE := [0, 1, 1, 0, 0, 1, 1, 0, 0, 1]

var rule := "cap10"
var armies: Array            # [藍, 紅]
var first := 0
var current := 0
var spent_this_turn := 0
var placed_this_turn := 0
var stopped := [false, false]
var turn_index := 0          # 蛇行：第幾手（0～9）
var hands_done := [0, 0]
var commands: Array = []     # {"team","type","col","row","turn"}
var handoffs := 0            # 換人次數

func _init(a0, a1, p_first := 0, p_rule := "cap10") -> void:
	armies = [a0, a1]
	first = p_first
	current = p_first
	rule = p_rule
	_skip_if_stuck()

func is_snake() -> bool:
	return rule.begins_with("snake")

func done() -> bool:
	return stopped[0] and stopped[1]

func hand_cap() -> int:
	if rule == "cap10":
		return 10
	if rule == "snake5c":
		return 20 * (hands_done[current] + 1) - armies[current].spent()
	return 20

func turn_left() -> int:
	return mini(hand_cap() - spent_this_turn, armies[current].left())

func check_place(t: int, col: int, row: int) -> String:
	if done():
		return "擺放已結束"
	if D.cost(t) > hand_cap() - spent_this_turn:
		return "這一手最多花 %d 金" % hand_cap()
	return armies[current].check_place(t, col, row)

func place(t: int, col: int, row: int) -> bool:
	if check_place(t, col, row) != "":
		return false
	armies[current].place(t, col, row)
	commands.append({"team": current, "type": t, "col": col, "row": row, "turn": turn_index})
	spent_this_turn += D.cost(t)
	placed_this_turn += 1
	if turn_left() < D.cheapest() or not armies[current].can_afford_any():
		end_turn()
	return true

func can_end_turn() -> bool:
	return placed_this_turn > 0 or turn_left() < D.cheapest()

## 結束這一手。還沒擺任何兵、又買得起時不能結束（買得起就不能跳過）。
func end_turn() -> bool:
	if placed_this_turn == 0 and turn_left() >= D.cheapest() and armies[current].can_afford_any():
		return false
	var prev := current
	spent_this_turn = 0
	placed_this_turn = 0
	if is_snake():
		hands_done[current] += 1
		if hands_done[current] >= 5 or not armies[current].can_afford_any():
			stopped[current] = true
		turn_index += 1
		if turn_index < SNAKE.size():
			current = SNAKE[turn_index] if first == 0 else 1 - SNAKE[turn_index]
		else:
			stopped[0] = true
			stopped[1] = true
	else:
		if not armies[current].can_afford_any():
			stopped[current] = true
		current = 1 - current
	_skip_if_stuck()
	if current != prev:
		handoffs += 1
	return true

func _skip_if_stuck() -> void:
	for _i in 12:
		if done():
			return
		if not armies[current].can_afford_any():
			stopped[current] = true
		if not stopped[current]:
			return
		if is_snake():
			turn_index += 1
			if turn_index >= SNAKE.size():
				stopped[0] = true
				stopped[1] = true
				return
			current = SNAKE[turn_index] if first == 0 else 1 - SNAKE[turn_index]
		else:
			current = 1 - current
