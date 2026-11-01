extends RefCounted
## 程式繪製的 Q 版角色與戰場（優化方案 G：美術先用程式能做到的先做）。
## 全部是向量圖形＋抗鋸齒，沒有外部角色素材。辨識靠三層視覺錨點：腳底隊伍標記、上半身／武器剪影、動態特效。

const D = preload("res://scripts/core/unit_defs.gd")

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

const TEAM := [[Color("#3fa7ff"), Color("#ff5a5a")], [Color("#2f80ff"), Color("#ffb000")]]

static func team_color(team: int, cb := false) -> Color:
	return TEAM[1 if cb else 0][team]

# ── 三段式攻擊（第二輪方案 R5）──
# atk（0～1）＝一次攻擊動作的進度：0～ATK_WINDUP 前搖、ATK_WINDUP～ATK_STRIKE 揮擊（命中就在 ATK_WINDUP 那一刻）、之後後搖。
const ATK_WINDUP := 0.3125
const ATK_STRIKE := 0.53125
const LEAN_BACK := 0.2094     # 前搖身體後傾 12°
const LEAN_FWD := 0.3142      # 揮擊前撲 18°

# 臉部疊加（表情）：同一份畫法同時給直接繪製與精靈圖快取用，兩條路看起來一樣
const M_HURT := 1             # 受擊／暈眩：>< 眼
const M_SPARKLE := 2          # 騎兵衝鋒蓄滿：亮晶晶眼＋槍尖金光
const M_BROWS := 4            # 狂熱：眉毛內傾
const M_HOOD := 8             # 刺客潛行：帽簷壓低、黃眼每 0.4 秒眨一次
const M_BRACE := 16           # 盾兵頂住：盾放大 1.35 倍

static func _smooth(u: float) -> float:
	return u * u * (3.0 - 2.0 * u)

## 攻擊姿勢：[武器 w（−1 往後拉滿、0 平常、+1 揮到底）, 身體傾角（弧度，正＝往前）, 橫向縮放, 縱向縮放, 前撲位移]
static func pose(atk: float) -> Array:
	if atk <= 0.0:
		return [0.0, 0.0, 1.0, 1.0, 0.0]
	if atk < ATK_WINDUP:
		var e := _smooth(atk / ATK_WINDUP)
		return [-e, -LEAN_BACK * e, 1.0 - 0.10 * e, 1.0 + 0.08 * e, -2.0 * e]
	if atk < ATK_STRIKE:
		var u := (atk - ATK_WINDUP) / (ATK_STRIKE - ATK_WINDUP)
		var e2 := 1.0 - (1.0 - u) * (1.0 - u)
		return [lerpf(-1.0, 1.0, e2), lerpf(-LEAN_BACK, LEAN_FWD, e2), lerpf(0.90, 1.04, e2), lerpf(1.08, 0.96, e2), lerpf(-2.0, 6.0, e2)]
	var e3 := _smooth((atk - ATK_STRIKE) / (1.0 - ATK_STRIKE))
	return [lerpf(1.0, 0.0, e3), lerpf(LEAN_FWD, 0.0, e3), lerpf(1.04, 1.0, e3), lerpf(0.96, 1.0, e3), lerpf(6.0, 0.0, e3)]

## 角色的局部座標轉換（以腳底為原點、face＝+1 畫）：呼吸／走路起伏、前撲、傾身、壓扁拉長、翻面。
## lean＝額外傾角（騎兵衝鋒前傾）、crouch＝縱向縮放（刺客潛行蹲身）。
static func unit_xf(p: Vector2, face: float, walk: float, atk: float, t: float, scale := 1.0, lean := 0.0, crouch := 1.0) -> Transform2D:
	var ps := pose(atk)
	var bob := sin(t * 3.0 + p.x * 0.05) * 0.8 if walk == 0.0 else absf(sin(walk)) * -2.5
	var o := p + Vector2(ps[4] * face, bob) * scale
	return Transform2D((ps[1] + lean) * face, Vector2(scale * face * ps[2], scale * ps[3] * crouch), 0.0, o)

## 單位：p＝腳底；face＝±1；walk＝走路相位（0＝沒走）；atk＝攻擊動作進度 0～1（見上）；hurt＝受擊閃白 0～1；
## alpha＝透明度（潛行）；t＝時間（待機呼吸）；scale＝縮放；mood＝表情疊加（M_*）；lean／crouch 見 unit_xf。
static func unit(ci: CanvasItem, p: Vector2, type: int, team: int, face: float, walk: float, atk: float,
		hurt: float, alpha: float, t: float, scale := 1.0, cb := false, mood := 0, lean := 0.0, crouch := 1.0) -> void:
	var tc := team_color(team, cb)
	var w: float = pose(atk)[0]
	ci.draw_set_transform_matrix(base * unit_xf(p, face, walk, atk, t, scale, lean, crouch))
	# 以 face＝+1 畫（水平鏡像由 transform 處理）
	if type == D.CAVALRY:
		_cavalry(ci, tc, walk, w, alpha, t, atk > 0.0)
	else:
		_infantry(ci, type, tc, walk, w, alpha, t, atk > 0.0)
	if hurt > 0.0:
		# 受擊閃白：在身體位置疊一層白
		ci.draw_circle(Vector2(0, -26), 14.0, Color(1, 1, 1, hurt * 0.55 * alpha), true, -1.0, true)
	if mood != 0:
		overlay(ci, type, team, mood, alpha, t, cb)
	ci.draw_set_transform_matrix(base)

## 表情與狀態疊加：呼叫前畫布轉換要已經是這隻角色的局部座標（face＝+1 空間）。
static func overlay(ci: CanvasItem, type: int, team: int, mood: int, a: float, t: float, cb := false) -> void:
	var ec := Vector2(2.0, -43.0) if type == D.CAVALRY else (Vector2(5.5, -33.5) if type == D.ASSASSIN else Vector2(3.5, -32.0))
	var eyes := [ec + Vector2(-3.0 if type != D.ASSASSIN else -2.5, 0), ec + Vector2(4.0 if type != D.ASSASSIN else 2.5, 0)]
	var skin := Color("#2b2140") if type == D.ASSASSIN else SKIN
	if mood & M_HOOD:
		# 帽簷壓低：一條兜帽色的帽簷蓋到眼睛上緣；每 0.4 秒整個蓋住一下（眨眼）
		var shut := fmod(t, 0.4) < 0.07
		var drop := 4.6 if shut else 2.2
		ci.draw_rect(Rect2(ec + Vector2(-6.5, -4.8), Vector2(13.0, drop)), Color("#6b3fa0", a))
	if mood & M_HURT:
		for i in 2:
			var e: Vector2 = eyes[i]
			ci.draw_circle(e, 3.3, Color(skin, a), true, -1.0, true)
			var sx := 1.0 if i == 0 else -1.0     # 左眼 >、右眼 <
			var col := Color("#ffe066", a) if type == D.ASSASSIN else Color(OUT, a)
			ci.draw_polyline(PackedVector2Array([e + Vector2(-1.8 * sx, -2.0), e + Vector2(1.6 * sx, 0), e + Vector2(-1.8 * sx, 2.0)]), col, 1.4, true)
	if mood & M_SPARKLE:
		for e in eyes:
			ci.draw_circle(e, 2.9, Color(OUT, a), true, -1.0, true)
			_star(ci, e + Vector2(0.4, -0.6), 2.2, Color(1, 1, 1, a))
		# 槍尖金光（長槍放平時的槍尖位置）
		var tip := Vector2(-6, -30) + Vector2(cos(-0.55), sin(-0.55)) * 40.0
		var g := 0.6 + 0.4 * sin(t * 18.0)
		_star(ci, tip, 4.5 + g * 1.5, Color(1, 0.86, 0.3, a * g))
	if mood & M_BROWS:
		for i in 2:
			var e2: Vector2 = eyes[i]
			var inward := 1.0 if i == 0 else -1.0
			var bc := Color("#ffe066", a) if type == D.ASSASSIN else Color(OUT, a)
			ci.draw_line(e2 + Vector2(-2.2, -4.2 - inward * 0.9), e2 + Vector2(2.2, -4.2 + inward * 0.9), bc, 1.5, true)
	if mood & M_BRACE and type == D.SHIELD:
		# 頂住：盾放大 1.35 倍（以盾中心縮放）
		var cc := Vector2(12, -24)
		var k := 1.35
		var sh := PackedVector2Array()
		for q in [Vector2(5, -40), Vector2(19, -38), Vector2(19, -12), Vector2(12, -4), Vector2(5, -12)]:
			sh.append(cc + (q - cc) * k)
		_poly(ci, sh, STEEL, a)
		var inner := PackedVector2Array()
		for q2 in [Vector2(9, -33), Vector2(15, -32), Vector2(15, -16), Vector2(12, -12), Vector2(9, -16)]:
			inner.append(cc + (q2 - cc) * k)
		_poly(ci, inner, team_color(team, cb), a, false)

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

static func _infantry(ci: CanvasItem, type: int, tc: Color, walk: float, w: float, a: float, t: float, angry := false) -> void:
	var leg := sin(walk) * 3.0 if walk != 0.0 else 0.0
	# 腿
	_c(ci, Vector2(-4 + leg, -3), 3.6, Color("#4a3b5c"), a)
	_c(ci, Vector2(4 - leg, -3), 3.6, Color("#4a3b5c"), a)
	# 背後的東西（箭筒）
	if type == D.ARCHER:
		_poly(ci, PackedVector2Array([Vector2(-11, -28), Vector2(-6, -30), Vector2(-3, -12), Vector2(-8, -11)]), WOOD, a)
		_line(ci, Vector2(-9, -30), Vector2(-11, -35), Color.WHITE, 1.5, a)
	# 身體（圓胖的上衣，隊伍色）
	var body := PackedVector2Array()
	for i in 13:
		var ang := PI + i * PI / 12.0
		body.append(Vector2(cos(ang) * 10.5, -16 + sin(ang) * 9.0))
	body.append(Vector2(10, -5)); body.append(Vector2(-10, -5))
	_poly(ci, body, tc, a)
	ci.draw_line(Vector2(-9, -11), Vector2(9, -11), Color(OUT, 0.35 * a), 2.0, true)   # 腰帶
	# 頭
	var hy := -33.0
	_c(ci, Vector2(0, hy), 11.5, SKIN, a)
	# 臉（朝右）
	if type != D.ASSASSIN:
		_eyes(ci, Vector2(3.5, hy + 1), a, t, angry)
	# 兵種特徵
	match type:
		D.SWORD:
			# 頭盔＋羽飾
			ci.draw_arc(Vector2(0, hy), 12.0, PI * 1.05, PI * 1.95, 18, Color(OUT, a), 6.5, true)
			ci.draw_arc(Vector2(0, hy), 12.0, PI * 1.05, PI * 1.95, 18, Color(STEEL, a), 4.0, true)
			_poly(ci, PackedVector2Array([Vector2(-2, hy - 12), Vector2(4, hy - 21), Vector2(7, hy - 19), Vector2(3, hy - 11)]), tc.lightened(0.2), a)
			# 劍：斜舉的亮刃（攻擊時往前揮）
			# 前搖往後拉 35°、揮擊揮到 +60° 以上
			var ang := -1.15 + (w * 0.61 if w < 0.0 else w * 1.5)
			var hand := Vector2(9, -17)
			var dir := Vector2(cos(ang), sin(ang))
			var tip := hand + dir * 24.0
			var side := dir.orthogonal() * 2.6
			_poly(ci, PackedVector2Array([hand + side, tip + side * 0.3, tip + dir * 3.0, tip - side * 0.3, hand - side]), Color("#f4f7ff"), a)
			_line(ci, hand - dir.orthogonal() * 5.0, hand + dir.orthogonal() * 5.0, GOLD, 2.5, a)
			_c(ci, hand, 3.0, SKIN, a)
		D.SHIELD:
			# 圓頭盔＋面罩
			ci.draw_arc(Vector2(0, hy), 12.0, PI * 0.95, PI * 2.05, 20, Color(OUT, a), 7.0, true)
			ci.draw_arc(Vector2(0, hy), 12.0, PI * 0.95, PI * 2.05, 20, Color(STEEL_D, a), 4.5, true)
			_line(ci, Vector2(-9, hy - 3), Vector2(11, hy - 3), STEEL_D, 2.0, a)
			# 大方盾（佔身體一半寬，正面）
			var push := w * 4.0
			var sh := PackedVector2Array([Vector2(5 + push, -40), Vector2(19 + push, -38), Vector2(19 + push, -12), Vector2(12 + push, -4), Vector2(5 + push, -12)])
			_poly(ci, sh, STEEL, a)
			_poly(ci, PackedVector2Array([Vector2(9 + push, -33), Vector2(15 + push, -32), Vector2(15 + push, -16), Vector2(12 + push, -12), Vector2(9 + push, -16)]), tc, a, false)
		D.ARCHER:
			# 綠兜帽＋羽毛
			ci.draw_arc(Vector2(0, hy), 12.0, PI * 0.9, PI * 2.1, 20, Color(OUT, a), 7.0, true)
			ci.draw_arc(Vector2(0, hy), 12.0, PI * 0.9, PI * 2.1, 20, Color(Color("#5aa364"), a), 4.5, true)
			_poly(ci, PackedVector2Array([Vector2(-6, hy - 10), Vector2(-14, hy - 22), Vector2(-9, hy - 10)]), tc.lightened(0.3), a)
			# 長弓
			var pull := 2.0 + 7.0 * -w if w <= 0.0 else 2.0 * (1.0 - w)   # 前搖拉弦、揮擊放箭
			var bc := Vector2(13, -22)
			ci.draw_arc(bc, 15.0, -1.25, 1.25, 16, Color(OUT, a), 5.5, true)
			ci.draw_arc(bc, 15.0, -1.25, 1.25, 16, Color(WOOD, a), 3.0, true)
			var top := bc + Vector2(cos(-1.25), sin(-1.25)) * 15.0
			var bot := bc + Vector2(cos(1.25), sin(1.25)) * 15.0
			var mid := Vector2(bc.x - pull, bc.y)
			ci.draw_line(top, mid, Color(1, 1, 1, 0.9 * a), 1.2, true)
			ci.draw_line(mid, bot, Color(1, 1, 1, 0.9 * a), 1.2, true)
			_c(ci, Vector2(bc.x + 12, bc.y), 3.0, SKIN, a)
		D.ASSASSIN:
			# 尖兜帽＋面罩，只露發光的眼睛
			var hood := PackedVector2Array([Vector2(-12, hy + 5), Vector2(-12, hy - 6), Vector2(-4, hy - 15), Vector2(-9, hy - 24), Vector2(6, hy - 13), Vector2(12, hy - 4), Vector2(12, hy + 5)])
			_poly(ci, hood, Color("#6b3fa0"), a)
			_poly(ci, PackedVector2Array([Vector2(-5, hy - 3), Vector2(11, hy - 3), Vector2(11, hy + 6), Vector2(-5, hy + 6)]), Color("#2b2140"), a, false)
			_c(ci, Vector2(3.0, hy - 0.5), 1.8, Color("#ffe066"), a, false)
			_c(ci, Vector2(8.0, hy - 0.5), 1.8, Color("#ffe066"), a, false)
			if angry:
				ci.draw_line(Vector2(1.0, hy - 3.6), Vector2(5.0, hy - 2.4), Color("#ffe066", a), 1.3, true)
				ci.draw_line(Vector2(10.0, hy - 3.6), Vector2(6.0, hy - 2.4), Color("#ffe066", a), 1.3, true)
			# 雙短刃
			var sw := w * 6.0
			_line(ci, Vector2(10, -18 - sw), Vector2(19, -24 + sw), Color("#f0f0ff"), 2.2, a)
			_line(ci, Vector2(-8, -16), Vector2(-15, -21), Color("#f0f0ff"), 2.2, a)
			_c(ci, Vector2(10, -18 - sw), 2.8, Color("#2b2140"), a)
	if type != D.ASSASSIN and type != D.ARCHER and type != D.SWORD:
		_c(ci, Vector2(-9, -17), 3.0, SKIN, a)

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

static func _cavalry(ci: CanvasItem, tc: Color, walk: float, w: float, a: float, t: float, angry := false) -> void:
	var gallop := sin(walk) * 3.5 if walk != 0.0 else 0.0
	var pony := Color("#d9a066")
	# 腿
	for lx in [-11.0, -5.0, 6.0, 12.0]:
		var sw := gallop if (int(lx) % 2 == 0) else -gallop
		_line(ci, Vector2(lx, -12), Vector2(lx + sw, -2), Color("#9c6b3c"), 3.0, a)
	# 身體（圓滾滾）
	var body := PackedVector2Array()
	for i in 20:
		var ang := i * TAU / 20.0
		body.append(Vector2(cos(ang) * 16.0, -17 + sin(ang) * 8.5))
	_poly(ci, body, pony, a)
	# 尾巴（隊伍色）
	_poly(ci, PackedVector2Array([Vector2(-15, -20), Vector2(-24, -24 + gallop), Vector2(-22, -14), Vector2(-15, -15)]), tc, a)
	# 頭與鬃毛
	_poly(ci, PackedVector2Array([Vector2(10, -22), Vector2(17, -36), Vector2(27, -33), Vector2(28, -26), Vector2(17, -19)]), pony, a)
	_poly(ci, PackedVector2Array([Vector2(10, -24), Vector2(14, -37), Vector2(18, -36), Vector2(14, -23)]), tc, a, false)
	_c(ci, Vector2(23, -31), 1.8, OUT, a, false)
	ci.draw_circle(Vector2(23.6, -31.6), 0.7, Color(1, 1, 1, a), true, -1.0, true)
	# 鞍布
	_poly(ci, PackedVector2Array([Vector2(-7, -25), Vector2(6, -25), Vector2(7, -15), Vector2(-8, -15)]), tc, a)
	# 騎士（小一號）
	var hy := -44.0
	_c(ci, Vector2(-1, -30), 6.5, tc.darkened(0.15), a)
	_c(ci, Vector2(-1, hy), 9.0, SKIN, a)
	_eyes(ci, Vector2(2.0, hy + 1), a, t, angry)
	ci.draw_arc(Vector2(-1, hy), 9.5, PI * 1.0, PI * 2.0, 18, Color(OUT, a), 6.0, true)
	ci.draw_arc(Vector2(-1, hy), 9.5, PI * 1.0, PI * 2.0, 18, Color(GOLD, a), 3.5, true)
	# 長槍＋小旗（衝鋒時放平前刺）
	var tilt := -0.55 + w * 0.3 if w < 0.0 else -0.55 * (1.0 - w)   # 前搖舉高、揮擊放平前刺
	var base := Vector2(-6, -30)
	var dir := Vector2(cos(tilt), sin(tilt))
	var tip := base + dir * 40.0
	_line(ci, base, tip, WOOD, 2.6, a)
	_poly(ci, PackedVector2Array([tip, tip - dir * 7.0 + dir.orthogonal() * 3.0, tip - dir * 7.0 - dir.orthogonal() * 3.0]), STEEL, a)
	var f0 := base + dir * 26.0
	_poly(ci, PackedVector2Array([f0, f0 + dir * 7.0, f0 + dir * 3.0 + dir.orthogonal() * 7.0]), tc.lightened(0.2), a, false)

## 腳底隊伍標記：藍＝圓、紅＝菱形（色盲也分得出）；重兵（盾、騎）外框加粗。
static func ring(ci: CanvasItem, p: Vector2, team: int, type: int, cb := false, scale := 1.0) -> void:
	var tc := team_color(team, cb)
	var w := 3.0 if (type == D.SHIELD or type == D.CAVALRY) else 2.0
	ci.draw_circle(p + Vector2(0, 1), 13.0 * scale, Color(0, 0, 0, 0.22), true, -1.0, true)  # 影子
	var pts := PackedVector2Array()
	if team == 0:
		for i in 25:
			var ang := i * TAU / 24.0
			pts.append(p + Vector2(cos(ang) * 15.0, sin(ang) * 7.5) * scale)
	else:
		pts = PackedVector2Array([p + Vector2(-16, 0) * scale, p + Vector2(0, -8.5) * scale, p + Vector2(16, 0) * scale, p + Vector2(0, 8.5) * scale, p + Vector2(-16, 0) * scale])
	ci.draw_polyline(pts, OUT, w + 2.5, true)
	ci.draw_polyline(pts, tc, w, true)

## 頭頂小旗（8×10）。
static func flag(ci: CanvasItem, p: Vector2, team: int, cb := false) -> void:
	var tc := team_color(team, cb)
	ci.draw_line(p, p + Vector2(0, -12), OUT, 2.0, true)
	var pts := PackedVector2Array([p + Vector2(0, -12), p + Vector2(9, -9), p + Vector2(0, -5)])
	ci.draw_colored_polygon(pts, tc)

## 小靈魂（死亡演出）。
static func soul(ci: CanvasItem, p: Vector2, a: float) -> void:
	ci.draw_circle(p, 7.5, Color(0.86, 0.95, 1.0, a), true, -1.0, true)
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-7, 0), p + Vector2(7, 0), p + Vector2(3, 10), p + Vector2(0, 7), p + Vector2(-3, 10)]), Color(0.86, 0.95, 1.0, a))
	ci.draw_circle(p + Vector2(-2.5, -1), 1.3, Color(0.15, 0.15, 0.25, a), true, -1.0, true)
	ci.draw_circle(p + Vector2(2.5, -1), 1.3, Color(0.15, 0.15, 0.25, a), true, -1.0, true)
