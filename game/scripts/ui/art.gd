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
const TEAM := [[Color("#3fa7ff"), Color("#ff5a5a")], [Color("#2f80ff"), Color("#ffb000")]]

static func team_color(team: int, cb := false) -> Color:
	return TEAM[1 if cb else 0][team]

## 單位：p＝腳底；face＝±1；walk＝走路相位（0＝沒走）；atk＝攻擊動畫 0～1；hurt＝受擊閃白 0～1；
## alpha＝透明度（潛行）；t＝時間（待機呼吸）；scale＝縮放。
static func unit(ci: CanvasItem, p: Vector2, type: int, team: int, face: float, walk: float, atk: float,
		hurt: float, alpha: float, t: float, scale := 1.0, cb := false) -> void:
	var tc := team_color(team, cb)
	var bob := sin(t * 3.0 + p.x * 0.05) * 0.8 if walk == 0.0 else absf(sin(walk)) * -2.5
	var lunge := sin(atk * PI) * 5.0 * face
	var o := p + Vector2(lunge, bob) * scale
	ci.draw_set_transform(o, 0.0, Vector2(scale * face, scale))
	# 以 face＝+1 畫（水平鏡像由 transform 處理）
	if type == D.CAVALRY:
		_cavalry(ci, tc, walk, atk, alpha, t)
	else:
		_infantry(ci, type, tc, walk, atk, alpha, t)
	if hurt > 0.0:
		# 受擊閃白：在身體位置疊一層白
		ci.draw_circle(Vector2(0, -26), 14.0, Color(1, 1, 1, hurt * 0.55 * alpha), true, -1.0, true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

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

static func _infantry(ci: CanvasItem, type: int, tc: Color, walk: float, atk: float, a: float, t: float) -> void:
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
		_eyes(ci, Vector2(3.5, hy + 1), a, t)
	# 兵種特徵
	match type:
		D.SWORD:
			# 頭盔＋羽飾
			ci.draw_arc(Vector2(0, hy), 12.0, PI * 1.05, PI * 1.95, 18, Color(OUT, a), 6.5, true)
			ci.draw_arc(Vector2(0, hy), 12.0, PI * 1.05, PI * 1.95, 18, Color(STEEL, a), 4.0, true)
			_poly(ci, PackedVector2Array([Vector2(-2, hy - 12), Vector2(4, hy - 21), Vector2(7, hy - 19), Vector2(3, hy - 11)]), tc.lightened(0.2), a)
			# 劍：斜舉的亮刃（攻擊時往前揮）
			var ang := lerpf(-2.2, 0.35, atk) if atk > 0.0 else -1.15
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
			var push := atk * 4.0
			var sh := PackedVector2Array([Vector2(5 + push, -40), Vector2(19 + push, -38), Vector2(19 + push, -12), Vector2(12 + push, -4), Vector2(5 + push, -12)])
			_poly(ci, sh, STEEL, a)
			_poly(ci, PackedVector2Array([Vector2(9 + push, -33), Vector2(15 + push, -32), Vector2(15 + push, -16), Vector2(12 + push, -12), Vector2(9 + push, -16)]), tc, a, false)
		D.ARCHER:
			# 綠兜帽＋羽毛
			ci.draw_arc(Vector2(0, hy), 12.0, PI * 0.9, PI * 2.1, 20, Color(OUT, a), 7.0, true)
			ci.draw_arc(Vector2(0, hy), 12.0, PI * 0.9, PI * 2.1, 20, Color(Color("#5aa364"), a), 4.5, true)
			_poly(ci, PackedVector2Array([Vector2(-6, hy - 10), Vector2(-14, hy - 22), Vector2(-9, hy - 10)]), tc.lightened(0.3), a)
			# 長弓
			var pull := 7.0 * (1.0 - atk) if atk > 0.0 else 2.0
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
			# 雙短刃
			var sw := atk * 6.0
			_line(ci, Vector2(10, -18 - sw), Vector2(19, -24 + sw), Color("#f0f0ff"), 2.2, a)
			_line(ci, Vector2(-8, -16), Vector2(-15, -21), Color("#f0f0ff"), 2.2, a)
			_c(ci, Vector2(10, -18 - sw), 2.8, Color("#2b2140"), a)
	if type != D.ASSASSIN and type != D.ARCHER and type != D.SWORD:
		_c(ci, Vector2(-9, -17), 3.0, SKIN, a)

static func _eyes(ci: CanvasItem, c: Vector2, a: float, t: float) -> void:
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
	ci.draw_arc(c + Vector2(0.5, 4.2), 1.8, 0.2, PI - 0.2, 6, Color(OUT, a), 1.2, true)

static func _cavalry(ci: CanvasItem, tc: Color, walk: float, atk: float, a: float, t: float) -> void:
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
	_eyes(ci, Vector2(2.0, hy + 1), a, t)
	ci.draw_arc(Vector2(-1, hy), 9.5, PI * 1.0, PI * 2.0, 18, Color(OUT, a), 6.0, true)
	ci.draw_arc(Vector2(-1, hy), 9.5, PI * 1.0, PI * 2.0, 18, Color(GOLD, a), 3.5, true)
	# 長槍＋小旗（衝鋒時放平前刺）
	var tilt := lerpf(-0.55, 0.0, atk) if atk > 0.0 else -0.55
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
