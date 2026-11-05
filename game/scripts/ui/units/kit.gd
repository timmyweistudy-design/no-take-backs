extends RefCounted
## 由 art.gd 拆出（V9 P1，行為不變）
## 程式繪製的 Q 版角色與戰場（優化方案 G：美術先用程式能做到的先做）。
## 全部是向量圖形＋抗鋸齒，沒有外部角色素材。辨識靠三層視覺錨點：腳底隊伍標記、上半身／武器剪影、動態特效。

const D = preload("res://scripts/core/unit_defs.gd")
const Gait = preload("res://scripts/ui/units/gait.gd")

const OUT := Color("#1d1a2b")
const SKIN := Color("#ffe1c4")
const BLUSH := Color(1.0, 0.55, 0.6, 0.55)
const STEEL := Color("#c9d3e3")
const STEEL_D := Color("#8c97ab")
const WOOD := Color("#b7814e")
const GOLD := Color("#ffd166")

# 隊伍色（一般／色盲高對比）
## 呼叫端目前的畫布轉換（鏡頭）。角色繪製要「疊加」在它上面，不能覆蓋掉（手感輪 2 抓到的錯位 bug）。
static var base := Transform2D.IDENTITY
static var _xf := Transform2D.IDENTITY   # 目前角色的畫布轉換（腳底座標），上半身另外疊 Gait.body_xf
static var _team_now := 0   # 目前在畫哪一隊（分隊小披風用）

const TEAM := [[Color("#45acff"), Color("#d93a44")], [Color("#2f80ff"), Color("#ffb000")]]   # 第七輪：紅壓暗，灰階下敵我也分得開（小樣通過條件 ②）

# ── 三段式攻擊（第二輪方案 R5）──
# atk（0～1）＝一次攻擊動作的進度：0～ATK_WINDUP 前搖、ATK_WINDUP～ATK_STRIKE 揮擊（命中就在 ATK_WINDUP 那一刻）、之後後搖。
const ATK_WINDUP := 0.3125
const ATK_STRIKE := 0.53125
const LEAN_BACK := 0.2618     # 前搖身體後傾 15°（第三輪 R1，原 12°）
const LEAN_FWD := 0.3840      # 揮擊前撲 22°（第三輪 R1，原 18°）

# 臉部疊加（表情）：同一份畫法同時給直接繪製與精靈圖快取用，兩條路看起來一樣
const M_HURT := 1             # 受擊／暈眩：>< 眼
const M_SPARKLE := 2          # 騎兵衝鋒蓄滿：亮晶晶眼＋槍尖金光
const M_BROWS := 4            # 狂熱：眉毛內傾
const M_HOOD := 8             # 刺客潛行：帽簷壓低、黃眼每 0.4 秒眨一次
const M_BRACE := 16           # 盾兵頂住：盾放大 1.35 倍

# 第八輪：通用表情疊加用的眼睛位置（其他新兵的臉不適合疊）
const FEATURE_EYES := {10: Vector2(1.5, -13), 13: Vector2(3, -17), 18: Vector2(3, -33), 19: Vector2(1, -31), 20: Vector2(2, -11)}


static func team_color(team: int, cb := false) -> Color:
	return TEAM[1 if cb else 0][team]


static func _smooth(u: float) -> float:
	return u * u * (3.0 - 2.0 * u)


static func _star(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.28, -r * 0.28), c + Vector2(r, 0), c + Vector2(r * 0.28, r * 0.28),
		c + Vector2(0, r), c + Vector2(-r * 0.28, r * 0.28), c + Vector2(-r, 0), c + Vector2(-r * 0.28, -r * 0.28)]), col)


static func _c(ci: CanvasItem, c: Vector2, r: float, col: Color, a: float, outline := true) -> void:
	if outline:
		ci.draw_circle(c, r + 1.6, Color(OUT, a), true, -1.0, true)
	ci.draw_circle(c, r, Color(col, col.a * a), true, -1.0, true)


static func _poly(ci: CanvasItem, pts: PackedVector2Array, col: Color, a: float, outline := true) -> void:
	if outline:
		var closed := pts.duplicate()
		closed.append(pts[0])
		ci.draw_polyline(closed, Color(OUT, a), 3.2, true)
	ci.draw_colored_polygon(pts, Color(col, col.a * a))


static func _line(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, w: float, al: float) -> void:
	ci.draw_line(a, b, Color(OUT, al), w + 3.0, true)
	ci.draw_line(a, b, Color(col, col.a * al), w, true)


static func _eyes(ci: CanvasItem, c: Vector2, a: float, t: float, angry := false) -> void:
	var blink := 1.0 if fmod(t + c.x * 0.13, 3.7) > 0.12 else 0.15
	for dx in [-3.0, 4.0]:
		var e := c + Vector2(dx, 0)
		ci.draw_circle(e, 2.6, Color(OUT, a), true, -1.0, true)
		if blink > 0.5:
			ci.draw_circle(e + Vector2(0.7, -0.8), 0.9, Color(1, 1, 1, a), true, -1.0, true)
		else:
			ci.draw_rect(Rect2(e - Vector2(2.6, 0.6), Vector2(5.2, 1.2)), Color(SKIN, a))
	ci.draw_circle(c + Vector2(-6.5, 4.0), 2.4, Color(BLUSH, BLUSH.a * a), true, -1.0, true)
	ci.draw_circle(c + Vector2(7.5, 4.0), 2.4, Color(BLUSH, BLUSH.a * a), true, -1.0, true)
	if angry:
		# 攻擊：眉毛內傾＋嘴巴張開
		ci.draw_line(c + Vector2(-5.2, -4.4), c + Vector2(-1.0, -3.2), Color(OUT, a), 1.5, true)
		ci.draw_line(c + Vector2(6.2, -4.4), c + Vector2(2.0, -3.2), Color(OUT, a), 1.5, true)
		ci.draw_circle(c + Vector2(0.5, 4.6), 1.7, Color(OUT, a), true, -1.0, true)
		ci.draw_circle(c + Vector2(0.5, 5.2), 0.9, Color("#e05a6a", a), true, -1.0, true)
	else:
		ci.draw_arc(c + Vector2(0.5, 4.2), 1.8, 0.2, PI - 0.2, 6, Color(OUT, a), 1.2, true)


static func _ell(c: Vector2, rx: float, ry: float, a0 := 0.0, a1 := TAU, n := 20) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var ang := a0 + (a1 - a0) * i / float(n - (0 if is_equal_approx(a1 - a0, TAU) else 1))
		pts.append(c + Vector2(cos(ang) * rx, sin(ang) * ry))
	return pts

## 上半身：腳畫完後呼叫，之後畫的東西跟著起伏與傾身。
## 第十輪 F3：攻擊時整隻壓扁、前衝。腳底為原點，所以不會和腿分離。up＝彈起（往上拉長）。
static func _atk_xf(b: Transform2D, w: float, sq: float, lunge := 0.0, up := false) -> Transform2D:
	if w == 0.0:
		return b
	var sx := 1.0
	var sy := 1.0
	var dx := 0.0
	if w < 0.0:
		sx = 1.0 - w * sq
		sy = 1.0 + w * sq
		dx = w * lunge * 0.3
	elif up:
		sx = 1.0 - w * sq * 0.4
		sy = 1.0 + w * sq * 0.6
	else:
		sx = 1.0 + w * sq * 0.6
		sy = 1.0 - w * sq * 0.3
		dx = w * lunge
	return Transform2D(0.0, Vector2(sx, sy), 0.0, Vector2(dx, 0.0)) * b

static func _push_body(ci: CanvasItem, b: Transform2D) -> void:
	ci.draw_set_transform_matrix(_xf * b)
