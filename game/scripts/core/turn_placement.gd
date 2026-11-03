extends RefCounted
## 輪流落子（企劃 §4.1、優化方案 A2）。公開輪流擺，擺下不能移動或收回；買得起就不能跳過。
## 規則：
##   "cap10"   ＝每一手 1～10 金、至少 1 隻；輪流直到雙方都買不起（原型規則）。
##   "snake5"  ＝每人 5 手、每手最多 20 金，公平輪序 A‑B‑B‑A‑B‑A‑A‑B‑B‑A；沒花完的錢不累積。
##   "snake5c" ＝同上，但沒花完的錢累積到下一手（第 k 手最多花到累計 20×k）。
## 每一手都記成指令（commands），可以重播、序列化（為 v1.1 線上預留）。

const D = preload("res://scripts/core/unit_defs.gd")

## 輪序（第二輪方案 R1 後重測）：原本蛇行 A‑B‑B‑A‑A‑B‑B‑A‑A‑B 在騎兵修好後先手只剩 38%；
## 改用 Thue‑Morse 公平輪序 A‑B‑B‑A‑B‑A‑A‑B‑B‑A，先手 48%（200 組成對）。規則代號仍叫 snake5，舊設定可用。
const SNAKE := [0, 1, 1, 0, 1, 0, 0, 1, 1, 0]

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
var rules = null             # 第五輪：自訂規則（null＝1.3.0 行為：snake 每手 20 金、5 手）
var skipped: Array = []      # 第六輪：因為沒有位置或買不起而被跳過的 {team, turn}（畫面橫幅用）

## p_rules：第五輪 Ruleset。給了就用它的每手上限、手數、累積；卡池與人數上限由軍隊本身（Army.apply_rules）管。
func _init(a0, a1, p_first := 0, p_rule := "cap10", p_rules = null) -> void:
	armies = [a0, a1]
	first = p_first
	current = p_first
	rule = p_rule
	rules = p_rules
	if rules != null:
		rule = "snake5" if rules.place_rule == "custom" else rules.place_rule
	_skip_if_stuck()

func pool_of(team: int) -> int:
	return armies[team].pool

## 每人幾手（snake）。
func hands_max() -> int:
	return rules.turns_per_player() if rules != null else 5

## 第 i 手輪到誰（Thue‑Morse 公平輪序；前 10 手＝SNAKE）。
func _who(i: int) -> int:
	var b := 0
	var x := i
	while x > 0:
		b ^= x & 1
		x >>= 1
	return b if first == 0 else 1 - b

## 這一隊現在最便宜能買的兵（標準路徑＝全域最便宜 4 金，和 1.3.0 相同）。
func _min_cost() -> int:
	if rules == null:
		return D.cheapest()
	var a = armies[current]
	return a.cheapest_combat() if (a.guard_combat and not a.has_combat()) else a.cheapest_in_pool()

func is_snake() -> bool:
	return rule.begins_with("snake")

func _order() -> Array:
	return SNAKE

func done() -> bool:
	return stopped[0] and stopped[1]

func hand_cap() -> int:
	if rules != null:
		var cap: int = rules.turn_cap(current)
		if rules.carry and is_snake():
			return cap * (hands_done[current] + 1) - (armies[current].spent() - spent_this_turn)
		return cap
	if rule == "cap10":
		return 10
	if rule == "snake5c":
		# 第 k 手最多花到累計 20×k；以「這一手開始前」的花費計算，這一手的花費由 turn_left 扣
		return 20 * (hands_done[current] + 1) - (armies[current].spent() - spent_this_turn)
	return 20

func turn_left() -> int:
	return mini(hand_cap() - spent_this_turn, armies[current].left())

func check_place(t: int, col: int, row: int) -> String:
	if done():
		return "擺放已結束"
	if D.cost(t) > hand_cap() - spent_this_turn:
		return "這一手最多花 %d 金" % hand_cap()
	var a = armies[current]
	# 第五輪防卡死：輪流落子的最後一手還沒有戰鬥兵，就只能擺戰鬥兵
	if rules != null and is_snake() and a.guard_combat and not a.has_combat() and D.is_support(t) and hands_done[current] >= hands_max() - 1:
		return "最後一手要擺戰鬥兵"
	return a.check_place(t, col, row)

# ───────── 第六輪：自由部署的批次落子（§3.8） ─────────
## 全場時把對方目前的兵同步成自己的禁區。
func _sync_enemy() -> void:
	if rules == null or rules.fullfield != 1:
		return
	for tm in 2:
		var lst: Array = []
		for u in armies[1 - tm].units:
			lst.append(armies[1 - tm].pos_of(u))
		armies[tm].enemy_pos = lst

func check_place_xy(t: int, x: int, y: int) -> String:
	if done():
		return "擺放已結束"
	_sync_enemy()
	if D.cost(t) > hand_cap() - spent_this_turn:
		return "這一手最多花 %d 金" % hand_cap()
	var a = armies[current]
	if rules != null and is_snake() and a.guard_combat and not a.has_combat() and D.is_support(t) and hands_done[current] >= hands_max() - 1:
		return "最後一手要擺戰鬥兵"
	return a.check_place_xy(t, x, y)

## 一筆＝一個批次指令，原子提交：全部都合法才放，否則一隻都不放（呼叫端先用預覽把不合法的點濾掉）。
## 一筆不會自動結束這一手；這一手的金額用完（或沒有可以放的位置）才換手。
func place_batch(items: Array) -> bool:
	if done() or items.is_empty():
		return false
	var a = armies[current]
	var keep: Array = a.units.duplicate(true)
	var spent0 := spent_this_turn
	for it in items:
		var why := check_place_xy(int(it[0]), int(it[1]), int(it[2]))
		if why != "" or not a.place_xy(int(it[0]), int(it[1]), int(it[2])):
			a.units = keep
			spent_this_turn = spent0
			return false
		spent_this_turn += D.cost(int(it[0]))
	commands.append({"team": current, "batch": items.duplicate(true), "turn": turn_index})
	placed_this_turn += items.size()
	if turn_left() < _min_cost() or not _can_act(current):
		end_turn()
	return true

## 這一隊還能不能動：買得起，而且（自由部署）場上還有合法位置。
func _can_act(tm: int) -> bool:
	_sync_enemy()
	return armies[tm].can_afford_any() and armies[tm].has_room()

func place(t: int, col: int, row: int) -> bool:
	if check_place(t, col, row) != "":
		return false
	armies[current].place(t, col, row)
	commands.append({"team": current, "type": t, "col": col, "row": row, "turn": turn_index})
	spent_this_turn += D.cost(t)
	placed_this_turn += 1
	if turn_left() < _min_cost() or not armies[current].can_afford_any():
		end_turn()
	return true

func can_end_turn() -> bool:
	return placed_this_turn > 0 or turn_left() < _min_cost()

## 結束這一手。還沒擺任何兵、又買得起時不能結束（買得起就不能跳過）。
func end_turn() -> bool:
	if placed_this_turn == 0 and turn_left() >= _min_cost() and _can_act(current):
		return false
	var prev := current
	spent_this_turn = 0
	placed_this_turn = 0
	if is_snake():
		hands_done[current] += 1
		if hands_done[current] >= hands_max() or not _can_act(current):
			stopped[current] = true
		turn_index += 1
		if turn_index < hands_max() * 2:
			current = _who(turn_index)
		else:
			stopped[0] = true
			stopped[1] = true
	else:
		if not _can_act(current):
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
		if not _can_act(current):
			if not stopped[current] and armies[current].deploy == "free":
				skipped.append({"team": current, "turn": turn_index})   # 第六輪：跳手記錄（畫面要提示；格子規則不記，和舊版指令相同）
				commands.append({"team": current, "skip": true, "turn": turn_index})
			stopped[current] = true
		if not stopped[current]:
			return
		if is_snake():
			turn_index += 1
			if turn_index >= hands_max() * 2:
				stopped[0] = true
				stopped[1] = true
				return
			current = _who(turn_index)
		else:
			current = 1 - current
