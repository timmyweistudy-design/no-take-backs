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
const LEAN_BACK := 0.2618     # 前搖身體後傾 15°（第三輪 R1，原 12°）
const LEAN_FWD := 0.3840      # 揮擊前撲 22°（第三輪 R1，原 18°）

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
		return [-e, -LEAN_BACK * e, 1.0 + 0.12 * e, 1.0 - 0.12 * e, -1.0 * e]   # 前搖壓扁蓄力 1.12／0.88
	if atk < ATK_STRIKE:
		var u := (atk - ATK_WINDUP) / (ATK_STRIKE - ATK_WINDUP)
		var e2 := 1.0 - (1.0 - u) * (1.0 - u)
		return [lerpf(-1.0, 1.0, e2), lerpf(-LEAN_BACK, LEAN_FWD, e2), lerpf(1.12, 0.88, e2), lerpf(0.88, 1.14, e2), lerpf(-1.0, 3.0, e2)]   # 揮擊拉長 0.88／1.14；前撲位移縮小，腳不滑出底圈（Antigravity S2 #3）
	var e3 := _smooth((atk - ATK_STRIKE) / (1.0 - ATK_STRIKE))
	return [lerpf(1.0, 0.0, e3), lerpf(LEAN_FWD, 0.0, e3), lerpf(0.88, 1.0, e3), lerpf(1.14, 1.0, e3), lerpf(3.0, 0.0, e3)]

## 角色的局部座標轉換（以腳底為原點、face＝+1 畫）：呼吸／走路起伏、前撲、傾身、壓扁拉長、翻面。
## lean＝額外傾角（騎兵衝鋒前傾）、crouch＝縱向縮放（刺客潛行蹲身）。
static func unit_xf(p: Vector2, face: float, walk: float, atk: float, t: float, scale := 1.0, lean := 0.0, crouch := 1.0) -> Transform2D:
	# 外層（位置、起伏、翻面、縮放、額外傾身／蹲身）× 內層（攻擊姿勢，face＝+1 空間）。
	# 精靈圖快取烘焙的是內層，貼圖時套外層，所以兩條路的順序完全一樣（Codex R5 #3）。
	var ps := pose(atk)
	var bob := sin(t * 3.0 + p.x * 0.05) * 0.8 if walk == 0.0 else absf(sin(walk)) * -2.5
	var outer := Transform2D(lean * face, Vector2(scale * face, scale * crouch), 0.0, p + Vector2(0, bob * scale))
	return outer * Transform2D(ps[1], Vector2(ps[2], ps[3]), 0.0, Vector2(ps[4], 0))

## 單位：p＝腳底；face＝±1；walk＝走路相位（0＝沒走）；atk＝攻擊動作進度 0～1（見上）；hurt＝受擊閃白 0～1；
## alpha＝透明度（潛行）；t＝時間（待機呼吸）；scale＝縮放；mood＝表情疊加（M_*）；lean／crouch 見 unit_xf。
static func unit(ci: CanvasItem, p: Vector2, type: int, team: int, face: float, walk: float, atk: float,
		hurt: float, alpha: float, t: float, scale := 1.0, cb := false, mood := 0, lean := 0.0, crouch := 1.0, variant := 0) -> void:
	var tc := team_color(team, cb)
	var w: float = pose(atk)[0]
	ci.draw_set_transform_matrix(base * unit_xf(p, face, walk, atk, t, scale, lean, crouch))
	# 以 face＝+1 畫（水平鏡像由 transform 處理）
	if type == D.CAVALRY:
		_cavalry(ci, tc, walk, w, alpha, t, atk > 0.0)
	else:
		_infantry(ci, type, tc, walk, w, alpha, t, atk > 0.0, variant)
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
		_star(ci, tip, 14.0 * (0.8 + 0.2 * g), Color(1, 0.86, 0.3, a * g))   # 14px 十字閃芒（第三輪 R3）
		_star(ci, tip, 6.0, Color("#fff8a0", a))
	if mood & M_BROWS:
		for i in 2:
			var e2: Vector2 = eyes[i]
			var inward := 1.0 if i == 0 else -1.0
			var bc := Color("#ffe066", a) if type == D.ASSASSIN else Color(OUT, a)
			ci.draw_line(e2 + Vector2(-2.2, -4.2 - inward * 0.9), e2 + Vector2(2.2, -4.2 + inward * 0.9), bc, 1.8, true)
			ci.draw_circle(e2 + Vector2(0.6, -0.4), 1.2, Color(1, 0.25, 0.2, a), true, -1.0, true)   # 紅眼光點（第三輪 R3）
	if mood & M_BRACE and type == D.PIKE:
		# 長槍兵拒騎：槍尖位置爆一圈銀色十字閃光（第四輪）
		var g2 := 0.6 + 0.4 * sin(t * 20.0)
		_star(ci, Vector2(7, -17) + Vector2(cos(-0.8), sin(-0.8)) * 48.0, 13.0 * g2 + 4.0, Color(0.92, 0.96, 1.0, a))
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

## variant：0 一般招式、1 交替招式（劍士上挑；其他兵種同一般）。第三輪 R4。
## 第四輪：variant 2＝新兵的專屬動作（長槍兵拒騎頓槍、投彈兵被貼身拿點火棒敲、醫者舉杖施法、鼓手大力敲、狂戰士雙斧高舉）。
static func _infantry(ci: CanvasItem, type: int, tc: Color, walk: float, w: float, a: float, t: float, angry := false, variant := 0) -> void:
	var leg := sin(walk) * 3.0 if walk != 0.0 else 0.0
	# 腿
	_c(ci, Vector2(-4 + leg, -3), 3.6, Color("#4a3b5c"), a)
	_c(ci, Vector2(4 - leg, -3), 3.6, Color("#4a3b5c"), a)
	# 背後的東西（箭筒）
	if type == D.ARCHER:
		_poly(ci, PackedVector2Array([Vector2(-11, -28), Vector2(-6, -30), Vector2(-3, -12), Vector2(-8, -11)]), WOOD, a)
		_line(ci, Vector2(-9, -30), Vector2(-11, -35), Color.WHITE, 1.5, a)
	# 背後的東西（投彈兵的備用火罐包）
	if type == D.BOMBER:
		_c(ci, Vector2(-9, -20), 5.0, Color("#3a3346"), a)
	# 身體（圓胖的上衣，隊伍色；狂戰士赤膊，隊伍色只留在獸皮披肩與褲頭；醫者白袍）
	var body := PackedVector2Array()
	for i in 13:
		var ang := PI + i * PI / 12.0
		body.append(Vector2(cos(ang) * 10.5, -16 + sin(ang) * 9.0))
	body.append(Vector2(10, -5)); body.append(Vector2(-10, -5))
	_poly(ci, body, SKIN.darkened(0.06) if type == D.BERSERKER else (Color("#f4f1ea") if type == D.MEDIC else tc), a)
	if type == D.BERSERKER:
		_poly(ci, PackedVector2Array([Vector2(-11, -21), Vector2(-3, -26), Vector2(8, -14), Vector2(3, -10), Vector2(-6, -18)]), tc, a, false)   # 獸皮披肩
		_poly(ci, PackedVector2Array([Vector2(-10, -9), Vector2(10, -9), Vector2(10, -5), Vector2(-10, -5)]), tc.darkened(0.2), a, false)
	elif type == D.MEDIC:
		_poly(ci, PackedVector2Array([Vector2(-10, -12), Vector2(10, -12), Vector2(10, -5), Vector2(-10, -5)]), tc, a, false)   # 白袍下擺露出隊伍色
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
			if variant == 1:
				# 上挑：前搖把劍壓低到身前下方，揮擊時往上撩過頭頂
				ang = 0.6 + (-w * 0.35 if w < 0.0 else -w * 2.6)
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
			var push := w * 7.0 if w > 0.0 else w * 3.0   # 盾擊：揮擊時整面盾往前推（第三輪 R4）
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
			if w < 0.0:
				# 拉弓時看得到搭在弦上的箭（第三輪 R4）
				_line(ci, mid, Vector2(bc.x + 16, bc.y), WOOD, 1.6, a)
				_poly(ci, PackedVector2Array([Vector2(bc.x + 20, bc.y), Vector2(bc.x + 15, bc.y - 2.5), Vector2(bc.x + 15, bc.y + 2.5)]), STEEL, a, false)
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
			# 後手的刀：揮擊時往前交叉斬（第三輪 R4）
			var bw := maxf(0.0, w)
			_line(ci, Vector2(-8 + bw * 18, -16 - bw * 6), Vector2(-15 + bw * 44, -21 + bw * 16), Color("#f0f0ff"), 2.8, a)   # 加長加粗，看得出交叉
			_c(ci, Vector2(10, -18 - sw), 2.8, Color("#2b2140"), a)
		D.PIKE:
			# 暖銅色扁鍋盔（寬帽簷，避開劍士的銀盔）
			ci.draw_arc(Vector2(0, hy), 11.5, PI * 1.08, PI * 1.92, 16, Color(OUT, a), 6.5, true)
			ci.draw_arc(Vector2(0, hy), 11.5, PI * 1.08, PI * 1.92, 16, Color("#c7834a", a), 4.0, true)
			_line(ci, Vector2(-15, hy - 6), Vector2(15, hy - 6), Color("#c7834a"), 2.6, a)
			ci.draw_arc(Vector2(0, hy), 9.5, PI * 1.25, PI * 1.6, 8, Color(1.0, 0.86, 0.55, 0.9 * a), 1.8, true)   # 鍋盔高光（混戰時頭頂對比）
			# 長槍：平常斜前上方 45° 伸出頭頂；前搖收槍、揮擊放平直刺（第四輪）；專屬＝拒騎：槍幾乎直立、槍尾頓地
			var pang := -0.8 + (w * -0.25 if w < 0.0 else w * 0.75)
			var phand := Vector2(7 + (w * 6.0 if w < 0.0 else w * 9.0), -17)
			if variant == 2:
				pang = -1.2
				phand = Vector2(9, -14)
			var pdir := Vector2(cos(pang), sin(pang))
			var pbutt := phand - pdir * 14.0
			var ptip := phand + pdir * 44.0
			_line(ci, pbutt, ptip, WOOD, 2.4, a)
			_poly(ci, PackedVector2Array([ptip + pdir * 8.0, ptip + pdir.orthogonal() * 3.2, ptip - pdir.orthogonal() * 3.2]), STEEL, a)
			var tas := ptip - pdir * 2.0
			_poly(ci, PackedVector2Array([tas, tas + Vector2(-4.6, 8.0), tas + Vector2(0, 6.0), tas + Vector2(3.2, 8.5)]), Color("#ff2a2a"), a)   # 紅纓（放大、加黑邊）
			if variant == 2:
				_star(ci, ptip + pdir * 6.0, 9.0, Color(0.92, 0.95, 1.0, a))   # 拒騎：槍尖銀色十字閃光
			_c(ci, phand, 3.0, SKIN, a)
		D.BOMBER:
			# 橘紅頭巾＋黃銅護目鏡（推在額頭上）
			ci.draw_arc(Vector2(0, hy), 12.0, PI * 1.0, PI * 2.0, 18, Color(OUT, a), 6.5, true)
			ci.draw_arc(Vector2(0, hy), 12.0, PI * 1.0, PI * 2.0, 18, Color("#ff7a3d", a), 4.0, true)
			_poly(ci, PackedVector2Array([Vector2(-11, hy - 2), Vector2(-17, hy + 4), Vector2(-12, hy + 5)]), Color("#ff7a3d"), a)
			_c(ci, Vector2(1.5, hy - 7.5), 3.4, Color("#d9a441"), a)
			_c(ci, Vector2(8.5, hy - 7.5), 3.4, Color("#d9a441"), a)
			ci.draw_circle(Vector2(1.5, hy - 7.5), 1.8, Color("#9fe3ff", a), true, -1.0, true)
			ci.draw_circle(Vector2(8.5, hy - 7.5), 1.8, Color("#9fe3ff", a), true, -1.0, true)
			# 肩上托一顆帶引線的黑色大圓火罐：前搖往後拉、揮擊時丟出去（手上就空了）；專屬＝被貼身：火罐收到背後、拿點火棒往前敲
			if variant == 2:
				var sa := -0.9 + maxf(0.0, w) * 1.6
				var sh0 := Vector2(10, -18)
				var sd := Vector2(cos(sa), sin(sa))
				_line(ci, sh0, sh0 + sd * 14.0, Color("#6b4a2b"), 2.4, a)
				_star(ci, sh0 + sd * 16.0, 3.6, Color(1, 0.7, 0.2, a))
				_c(ci, sh0, 3.0, SKIN, a)
			elif w <= 0.25:
				var bp := Vector2(9 + w * 9.0, hy - 13 + (-w) * 4.0)
				_c(ci, bp, 7.5, Color("#2a2533"), a)
				ci.draw_circle(bp + Vector2(-2.5, -2.5), 2.0, Color(1, 1, 1, 0.35 * a), true, -1.0, true)
				_line(ci, bp + Vector2(2, -7), bp + Vector2(5, -11), Color("#c9a26b"), 1.3, a)
				var sp := 0.6 + 0.4 * sin(t * 22.0)
				_star(ci, bp + Vector2(5.5, -12), 3.2 * sp + 1.0, Color(1, 0.85, 0.3, a))
				_c(ci, Vector2(11 + w * 6.0, -19), 3.0, SKIN, a)
			else:
				_c(ci, Vector2(12 + w * 4.0, -24 + w * 6.0), 3.0, SKIN, a)
		D.MEDIC:
			# 白色高方帽＋綠十字
			_poly(ci, PackedVector2Array([Vector2(-9, hy - 7), Vector2(-8, hy - 24), Vector2(8, hy - 24), Vector2(9, hy - 7)]), Color("#fbfbf7"), a)
			ci.draw_rect(Rect2(Vector2(-1.6, hy - 21), Vector2(3.2, 10)), Color("#2fbf71", a))
			ci.draw_rect(Rect2(Vector2(-5, hy - 17.6), Vector2(10, 3.2)), Color("#2fbf71", a))
			# 頂端發綠光的長杖：補血時舉高（w 往前＝舉杖）
			var lift := maxf(0.0, w) * 16.0 + (-w * 4.0 if w < 0.0 else 0.0)
			if variant == 2:
				lift = 18.0   # 專屬＝施法：雙手把杖高舉過頭
			var sbase := Vector2(12, -4 - lift)
			var stop := Vector2(14, -48 - lift)
			_line(ci, sbase, stop, WOOD, 2.2, a)
			var glow := 0.65 + 0.35 * sin(t * 4.0)
			ci.draw_circle(stop, 7.0 + lift * 0.5, Color(0.4, 1.0, 0.55, (0.28 + lift * 0.02) * glow * a), true, -1.0, true)
			_c(ci, stop, 3.4 + lift * 0.08, Color("#7dffa0"), a)
			if variant == 2:
				_c(ci, Vector2(9.0, -24 - lift), 2.8, SKIN, a)   # 第二隻手也扶著杖
			_c(ci, Vector2(12.5, -20 - lift), 3.0, SKIN, a)
		D.DRUMMER:
			# 紅白羽毛高帽（全兵種最高）
			var hatc := Color("#d8343d") if tc.b > tc.r else Color("#6e1f4a")   # 紅隊（或色盲的黃隊）帽身改深酒紅，不跟隊伍色混在一起
			_poly(ci, PackedVector2Array([Vector2(-8, hy - 8), Vector2(-7, hy - 20), Vector2(7, hy - 20), Vector2(8, hy - 8)]), hatc, a)
			_line(ci, Vector2(-8, hy - 10), Vector2(8, hy - 10), GOLD, 1.8, a)
			_poly(ci, PackedVector2Array([Vector2(-2, hy - 20), Vector2(-6, hy - 36), Vector2(1, hy - 30), Vector2(3, hy - 20)]), Color("#ffffff"), a)
			_poly(ci, PackedVector2Array([Vector2(1, hy - 20), Vector2(4, hy - 33), Vector2(6, hy - 20)]), Color("#ff6b6b"), a, false)
			# 胸前大圓鼓
			var dc := Vector2(7, -15)
			_c(ci, dc, 9.0, Color("#e9d8a6"), a)
			ci.draw_arc(dc, 9.0, 0.0, TAU, 24, Color(tc, a), 2.4, true)
			_line(ci, dc + Vector2(-6, -6), dc + Vector2(6, 6), Color("#b7814e"), 1.0, a)
			# 鼓棒：平常輕敲、揮擊時舉高大力敲兩下
			var beat := absf(sin(t * 6.0)) * 4.0
			var raise := maxf(0.0, -w) * 16.0 + (beat if w == 0.0 else 0.0) - maxf(0.0, w) * 4.0
			if variant == 2:
				raise = 18.0   # 專屬＝大力連敲：鼓棒舉高
			for k in 2:
				var hx := 2.0 + k * 9.0
				_line(ci, Vector2(hx, -20 - raise), Vector2(hx + 5, -26 - raise - k * 2), Color("#f4e3c1"), 1.8, a)
				_c(ci, Vector2(hx + 5, -26 - raise - k * 2), 2.0, Color("#f4e3c1"), a)
		D.BERSERKER:
			# 火紅刺蝟頭
			var hair := PackedVector2Array([Vector2(-12, hy - 1), Vector2(-15, hy - 10), Vector2(-9, hy - 9), Vector2(-10, hy - 19), Vector2(-3, hy - 13),
				Vector2(0, hy - 23), Vector2(4, hy - 13), Vector2(10, hy - 19), Vector2(9, hy - 9), Vector2(15, hy - 9), Vector2(12, hy - 1), Vector2(0, hy - 8)])
			_poly(ci, hair, Color("#ff5a2a"), a)
			# 左右手各一把闊斧：揮擊時雙斧往下劈（交叉）
			# 待機時雙斧垂在身體兩側往外（不擋臉）；前搖舉過頭、揮擊往前下劈
			var aang := -0.35 + (w * 1.3 if w < 0.0 else w * 1.4)
			if variant == 2:
				aang = -1.75   # 專屬＝破陣：雙斧高舉過頭
			for k2 in 2:
				var ah := Vector2(9, -15) if k2 == 0 else Vector2(-8, -16)
				var aa := aang if k2 == 0 else (PI - aang if w <= 0.0 else aang - 0.4)
				var adir := Vector2(cos(aa), sin(aa))
				var atip := ah + adir * 20.0
				_line(ci, ah, atip, WOOD, 2.4, a)
				var ao := adir.orthogonal()
				var blade := PackedVector2Array([atip - adir * 2.0 + ao * 1.5, atip - adir * 10.0 + ao * 10.0, atip + adir * 4.0 + ao * 9.0])
				_poly(ci, blade, STEEL, a)
				ci.draw_line(blade[1], blade[2], Color(1, 1, 1, a), 1.6, true)   # 亮銀刃口
				_c(ci, ah, 3.0, SKIN, a)
	if type != D.ASSASSIN and type != D.ARCHER and type != D.SWORD and type != D.PIKE and type != D.BOMBER and type != D.MEDIC and type != D.BERSERKER:
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
		var lift := maxf(0.0, w) * 12.0 if lx > 0.0 else 0.0   # 命中時馬前蹄抬起（第三輪 R4；Antigravity S4 加大）
		_line(ci, Vector2(lx, -12), Vector2(lx + sw + lift * 0.6, -2 - lift), Color("#9c6b3c"), 3.0, a)
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
