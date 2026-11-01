extends RefCounted
## 確定性整數數學。GDScript 的 int/int 是「往 0 截斷」，左右鏡像時結果對稱，所以全部沿用。

## 整數平方根（無條件捨去）。先用浮點估計，再用整數修正到精確值，所以跨平台結果一定一樣。
static func isqrt(n: int) -> int:
	if n <= 0:
		return 0
	var x := int(sqrt(float(n)))
	while x * x > n:
		x -= 1
	while (x + 1) * (x + 1) <= n:
		x += 1
	return x

static func dist2(ax: int, ay: int, bx: int, by: int) -> int:
	var dx := bx - ax
	var dy := by - ay
	return dx * dx + dy * dy

## 把 (dx,dy) 縮放成長度約 1000 的整數向量；零向量回傳 (0,0)。
static func unit1000(dx: int, dy: int) -> Vector2i:
	var l := isqrt(dx * dx + dy * dy)
	if l == 0:
		return Vector2i.ZERO
	return Vector2i(dx * 1000 / l, dy * 1000 / l)
