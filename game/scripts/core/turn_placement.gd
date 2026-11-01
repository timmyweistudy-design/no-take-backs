extends RefCounted
## 輪流落子（企劃 §4.1）：公開輪流擺；每一手花 1～10 金、至少 1 隻；擺下不能移動或收回；
## 買得起就不能跳過；買不起或滿 24 隻就自動停手；雙方都停手就開打。

const D = preload("res://scripts/core/unit_defs.gd")

const TURN_CAP := 10

var armies: Array            # [藍, 紅]
var current := 0
var spent_this_turn := 0
var placed_this_turn := 0
var stopped := [false, false]

func _init(a0, a1, first := 0) -> void:
	armies = [a0, a1]
	current = first
	_skip_if_stuck()

func done() -> bool:
	return stopped[0] and stopped[1]

func turn_left() -> int:
	return mini(TURN_CAP - spent_this_turn, armies[current].left())

func check_place(t: int, col: int, row: int) -> String:
	if done():
		return "擺放已結束"
	if D.cost(t) > TURN_CAP - spent_this_turn:
		return "這一手最多花 %d 金" % TURN_CAP
	return armies[current].check_place(t, col, row)

func place(t: int, col: int, row: int) -> bool:
	if check_place(t, col, row) != "":
		return false
	armies[current].place(t, col, row)
	spent_this_turn += D.cost(t)
	placed_this_turn += 1
	if turn_left() < D.cheapest() or not armies[current].can_afford_any():
		end_turn()
	return true

func can_end_turn() -> bool:
	return placed_this_turn > 0

## 結束這一手。還沒擺任何兵、又買得起時不能結束（買得起就不能跳過）。
func end_turn() -> bool:
	if placed_this_turn == 0 and armies[current].can_afford_any():
		return false
	if not armies[current].can_afford_any():
		stopped[current] = true
	spent_this_turn = 0
	placed_this_turn = 0
	current = 1 - current
	_skip_if_stuck()
	return true

func _skip_if_stuck() -> void:
	for _i in 2:
		if not armies[current].can_afford_any():
			stopped[current] = true
		if stopped[current] and not done():
			current = 1 - current
