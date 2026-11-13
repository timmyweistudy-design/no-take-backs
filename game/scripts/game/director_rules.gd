extends RefCounted
## 1.3.0 第 6 大類（方案 §2）：導播的純邏輯（不碰畫面，測試直接呼叫）。

const SEG_PRE := 20        # 每段從事件前 1 秒開始
const SEG_LEN := 100       # 每段 5 秒（三段 ≤15 秒）
const REEL_MAX := 3
const TOUR_TICKS := 24     # 開場沿盤緣巡兩軍 1.2 秒

## 精華三連：從候選標記（{"t": tick, ...}）挑最多三段；兩段的開頭相距不到一段就算同一個事件（去重）；
## 終局那段（final_t ≥ 0）永遠排最後、不重複；不足兩個獨立事件只出一段（不硬湊）。回傳依時間排好的標記。
static func pick_reel(marks: Array, final_t: int) -> Array:
	var c: Array = []
	for m in marks:
		if m is Dictionary and m.has("t"):
			c.append(m)
	c.sort_custom(func(a, b): return int(a["t"]) < int(b["t"]))
	var out: Array = []
	for m in c:
		var t := int(m["t"])
		if final_t >= 0 and absi(t - final_t) < SEG_LEN:
			continue   # 和終局重疊
		if not out.is_empty() and t - int(out[-1]["t"]) < SEG_LEN:
			continue   # 和上一段重疊＝同一個事件
		out.append(m)
	var room := REEL_MAX - (1 if final_t >= 0 else 0)
	if out.size() > room:
		# 太多：平均挑（開頭、中段、後段各一），不是只取前面
		var pick: Array = []
		for i in room:
			pick.append(out[int(round(float(i) * float(out.size() - 1) / float(maxi(1, room - 1))))])
		out = pick
	if final_t >= 0:
		out.append({"t": final_t, "final": true})
	if out.size() < 2:
		return out.slice(0, 1)
	return out

static func reel_seconds(reel: Array) -> float:
	return reel.size() * SEG_LEN * 0.05

## 自動導播：這個 tick 的鏡頭目標 [縮放, 盤面中心]。hot＝交戰熱點、n＝熱點裡在打的單位數；fc＝盤面中心、fw＝盤面寬。
static func director_target(tick: int, finished: bool, hot: Vector2, n: int, fc: Vector2, fw: float) -> Array:
	if finished:
		return [1.0, fc]   # 勝方歡呼：拉遠回全景
	if tick < TOUR_TICKS:
		var k := float(tick) / float(TOUR_TICKS)
		return [1.2, Vector2(fc.x + fw * lerpf(-0.2, 0.2, k), fc.y)]   # 開戰沿盤緣巡過兩軍
	if n >= 2:
		return [clampf(1.2 + 0.04 * float(n - 2), 1.2, 1.4), hot]   # 交戰區推近 1.2～1.4 倍
	return [1.0, fc]

## 放大鏡小窗的角落：離被選的那隻最遠、且不在排除名單裡；換角有遲滯（那隻離目前的角 >gap 就不換）。
static func mag_corner(corners: Array, unit_p: Vector2, cur: int, banned: Array, gap: float) -> int:
	if cur >= 0 and cur < corners.size() and not cur in banned and (corners[cur] as Vector2).distance_to(unit_p) > gap:
		return cur
	var best := -1
	var bd := -1.0
	for i in corners.size():
		if i in banned:
			continue
		var d: float = (corners[i] as Vector2).distance_to(unit_p)
		if d > bd:
			bd = d
			best = i
	return best
