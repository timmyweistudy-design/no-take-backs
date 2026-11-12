extends RefCounted
## 1.2.0 §11.6 合作布陣（同機）：兩名玩家（P1、P2，用玩家編號不是顏色）共用預算擺同一支藍軍對 AI。
## 規則（方案第 5 輪）：總手數＝每人手數×2，P1 先、之後輪流；每一手有金額上限；每人只能撤銷自己這一手擺的兵，
## 撤銷返還那隻兵的錢、不返還手數（手數在「結束這一手」才扣）；撤銷後仍是同一人；買不起任何可用兵或手數用完就結束。純資料。
const HANDS_EACH := 5

var hands_each := HANDS_EACH
var cap := 10            # 每一手最多花多少
var hand := 0            # 第幾手（0 起）
var spent := 0           # 這一手已花
var mine: Array = []     # 這一手擺的格子（Vector2i）
var owner := {}          # 格子 → 玩家（0／1）

func _init(budget: int, priciest: int, p_hands := HANDS_EACH) -> void:
	hands_each = p_hands
	cap = maxi((budget + hands_each * 2 - 1) / (hands_each * 2), priciest)

func player() -> int:
	return hand % 2

func hands_total() -> int:
	return hands_each * 2

func done() -> bool:
	return hand >= hands_total()

## 回傳 ""＝可以；"done"＝手數用完；"cap"＝超過這一手的上限
func check(cost: int) -> String:
	if done():
		return "done"
	if spent + cost > cap:
		return "cap"
	return ""

func placed(c: Vector2i, cost: int) -> void:
	spent += cost
	mine.append(c)
	owner[c] = player()

func can_remove(c: Vector2i) -> bool:
	return not done() and c in mine

func removed(c: Vector2i, cost: int) -> void:
	if c in mine:
		mine.erase(c)
		owner.erase(c)
		spent = maxi(0, spent - cost)

func end_hand() -> void:
	if done():
		return
	hand += 1
	spent = 0
	mine = []

## 剩下的錢買不起任何可用兵（或人數滿）→ 直接結束全部手數
func finish_if_stuck(can_afford_any: bool) -> void:
	if not can_afford_any:
		hand = hands_total()
		spent = 0
		mine = []
