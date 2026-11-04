extends "res://scripts/ui/units/kit.gd"
## 由 art.gd 拆出（V9 P1，行為不變）

## variant：0 一般招式、1 交替招式（劍士上挑；其他兵種同一般）。第三輪 R4。
## 第四輪：variant 2＝新兵的專屬動作（長槍兵拒騎頓槍、投彈兵被貼身拿點火棒敲、醫者舉杖施法、鼓手大力敲、狂戰士雙斧高舉）。
static func _infantry(ci: CanvasItem, type: int, tc: Color, walk: float, w: float, a: float, t: float, angry := false, variant := 0) -> void:
	# 腿（V9 P2）：腳踩地不動，上半身另外起伏；腿從腰連到腳，分隔不會斷開
	var ft: Array = Gait.feet(type, walk)
	var bx: Transform2D = Gait.body_xf(type, walk)
	var hip_y := -9.0 + bx.origin.y
	var legc := Color("#4a3b5c")
	_line(ci, Vector2(-3.5, hip_y), Vector2(-4 + ft[0], -4.0 - ft[1]), legc, 3.4, a)
	_c(ci, Vector2(-4 + ft[0], -3.0 - ft[1]), 3.6, legc, a)
	_line(ci, Vector2(3.5, hip_y), Vector2(4 + ft[2], -3.0 - ft[3]), legc, 3.4, a)
	_c(ci, Vector2(4 + ft[2], -2.0 - ft[3]), 3.6, legc, a)
	_push_body(ci, bx)
	var wk := Gait.ph(walk)
	var sway: float = Gait.swing(type, walk)
	var fl := sin(wk + 1.0) * 2.5 if wk != 0.0 else 0.0   # 披風延遲擺動
	# 第七輪 C2：小披風分隊，藍方圓角、紅方燕尾（除了圍巾已經很明顯的刺客與騎兵）
	if type != D.ASSASSIN:
		var cape := PackedVector2Array([Vector2(-6, -23), Vector2(-14 - fl * 0.4, -18), Vector2(-16 - fl, -8 + fl * 0.3), Vector2(-12 - fl, -6), Vector2(-7, -9)]) if _team_now == 0 else PackedVector2Array([Vector2(-6, -23), Vector2(-15 - fl * 0.4, -18), Vector2(-18 - fl, -6 + fl * 0.3), Vector2(-13 - fl * 0.8, -10), Vector2(-11 - fl, -5), Vector2(-7, -9)])
		_poly(ci, cape, tc.darkened(0.08), a)
	# 背後的東西（箭筒）
	if type == D.ARCHER:
		# 第七輪 C1-3：箭筒放大、露白羽
		_poly(ci, PackedVector2Array([Vector2(-14, -30), Vector2(-7, -33), Vector2(-3, -11), Vector2(-9, -9)]), WOOD, a)
		for fi in 3:
			var fx0 := Vector2(-12.0 + fi * 3.0, -32.0 - fi * 0.8)
			_line(ci, fx0, fx0 + Vector2(-3 - fl * 0.5, -7), Color.WHITE, 1.8, a)
	# 背後的東西（投彈兵的備用火罐包）
	if type == D.BOMBER:
		_c(ci, Vector2(-10, -20 + fl * 0.8), 7.5, Color("#3a3346"), a)   # 第七輪 C1-7：火罐包放大（V9：跟著跑步彈）
		_line(ci, Vector2(-11, -27 + fl * 0.8), Vector2(-14, -31 + fl * 0.8), Color("#c9a26b"), 1.3, a)
	# 身體（圓胖的上衣，隊伍色；狂戰士赤膊，隊伍色只留在獸皮披肩與褲頭；醫者白袍）
	var bw0 := 13.0 if type == D.SHIELD else 10.5   # 第七輪 C1-2：盾兵身體加寬
	var body := PackedVector2Array()
	for i in 13:
		var ang := PI + i * PI / 12.0
		body.append(Vector2(cos(ang) * bw0, -16 + sin(ang) * 9.0))
	if type == D.MEDIC:
		body.append(Vector2(13, -5)); body.append(Vector2(-13, -5))   # 第七輪 C1-8：A 字長袍
	else:
		body.append(Vector2(bw0 - 0.5, -5)); body.append(Vector2(-bw0 + 0.5, -5))
	_poly(ci, body, SKIN.darkened(0.06) if type == D.BERSERKER else (Color("#f4f1ea") if type == D.MEDIC else tc), a)
	if type == D.BERSERKER:
		# 第七輪 C1-10：披肩加寬＋交叉肩帶＋整條褲頭，隊伍色面積拉大
		_poly(ci, PackedVector2Array([Vector2(-12, -24), Vector2(-2, -27), Vector2(12, -15), Vector2(5, -8), Vector2(-3, -15), Vector2(-11, -13)]), tc, a, false)
		_poly(ci, PackedVector2Array([Vector2(8, -24), Vector2(11, -21), Vector2(-7, -7), Vector2(-10, -10)]), tc.darkened(0.15), a, false)
		_poly(ci, PackedVector2Array([Vector2(-10, -14), Vector2(10, -14), Vector2(10, -5), Vector2(-10, -5)]), tc, a, false)
	elif type == D.MEDIC:
		_poly(ci, PackedVector2Array([Vector2(-12, -11), Vector2(12, -11), Vector2(13, -5), Vector2(-13, -5)]), tc, a, false)   # 白袍下擺露出隊伍色
		_poly(ci, PackedVector2Array([Vector2(-10, -24), Vector2(-3, -26), Vector2(8, -22), Vector2(10, -16), Vector2(0, -19), Vector2(-11, -15)]), tc, a)   # 第七輪 C1-8：大面積隊伍色披肩
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
			var ang := -1.15 + (w * 0.61 if w < 0.0 else w * 1.5) + sway
			if variant == 1:
				# 上挑：前搖把劍壓低到身前下方，揮擊時往上撩過頭頂
				ang = 0.6 + (-w * 0.35 if w < 0.0 else -w * 2.6)
			# 第七輪 C1-1：隊伍色短領巾；劍身加寬、十字護手
			_poly(ci, PackedVector2Array([Vector2(-9, -24), Vector2(8, -24), Vector2(6, -20), Vector2(-3, -19), Vector2(-5, -14), Vector2(-9, -17)]), tc.lightened(0.15), a, true)
			var hand := Vector2(9, -17 + sway * 8.0)
			var dir := Vector2(cos(ang), sin(ang))
			var tip := hand + dir * 24.0
			var side := dir.orthogonal() * 3.6
			_poly(ci, PackedVector2Array([hand + side, tip + side * 0.3, tip + dir * 3.0, tip - side * 0.3, hand - side]), Color("#f4f7ff"), a)
			_line(ci, hand - dir.orthogonal() * 7.0, hand + dir.orthogonal() * 7.0, GOLD, 3.0, a)
			_c(ci, hand, 3.0, SKIN, a)
		D.SHIELD:
			# 圓頭盔＋面罩
			ci.draw_arc(Vector2(0, hy), 12.0, PI * 0.95, PI * 2.05, 20, Color(OUT, a), 7.0, true)
			ci.draw_arc(Vector2(0, hy), 12.0, PI * 0.95, PI * 2.05, 20, Color(STEEL_D, a), 4.5, true)
			_line(ci, Vector2(-9, hy - 3), Vector2(11, hy - 3), STEEL_D, 2.0, a)
			# 大方盾（佔身體一半寬，正面）
			var push := (w * 7.0 if w > 0.0 else w * 3.0) + sway * 14.0   # 盾擊：揮擊時整面盾往前推（第三輪 R4）；走路時盾微晃
			# 第七輪 C1-2：盾放大（遮身體六成）、上寬下尖、深鐵色外框，混戰時不會融進隊伍色塊
			var sh := PackedVector2Array([Vector2(1 + push, -43), Vector2(21 + push, -41), Vector2(21 + push, -14), Vector2(11 + push, -2), Vector2(1 + push, -14)])
			_poly(ci, sh, Color("#4a5468"), a)
			var shi := PackedVector2Array([Vector2(4 + push, -39), Vector2(18 + push, -38), Vector2(18 + push, -15), Vector2(11 + push, -6), Vector2(4 + push, -15)])
			_poly(ci, shi, STEEL, a, false)
			_poly(ci, PackedVector2Array([Vector2(7 + push, -33), Vector2(15 + push, -32), Vector2(15 + push, -17), Vector2(11 + push, -11), Vector2(7 + push, -17)]), tc, a, false)
		D.ARCHER:
			# 綠兜帽＋羽毛
			ci.draw_arc(Vector2(0, hy), 12.0, PI * 0.9, PI * 2.1, 20, Color(OUT, a), 7.0, true)
			ci.draw_arc(Vector2(0, hy), 12.0, PI * 0.9, PI * 2.1, 20, Color(Color("#5aa364"), a), 4.5, true)
			_poly(ci, PackedVector2Array([Vector2(-6, hy - 10), Vector2(-14, hy - 22), Vector2(-9, hy - 10)]), tc.lightened(0.3), a)
			# 長弓
			var pull := 2.0 + 7.0 * -w if w <= 0.0 else 2.0 * (1.0 - w)   # 前搖拉弦、揮擊放箭
			# 第七輪 C1-3：弓放大、淺樺木色，草地上看得到
			var bc := Vector2(12, -22 + sway * 18.0)
			ci.draw_arc(bc, 18.0, -1.3, 1.3, 18, Color(OUT, a), 6.0, true)
			ci.draw_arc(bc, 18.0, -1.3, 1.3, 18, Color(Color("#ecd9a8"), a), 3.4, true)
			var top := bc + Vector2(cos(-1.3), sin(-1.3)) * 18.0
			var bot := bc + Vector2(cos(1.3), sin(1.3)) * 18.0
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
			# 第七輪 C1-5：不再戴紫色尖帽（蓋掉隊伍色、又高又像法師）。貼頭的深色頭巾＋隊伍色長圍巾往後飄
			var flow := sin(t * 5.0 + walk) * 2.0
			_poly(ci, PackedVector2Array([Vector2(-8, hy + 7), Vector2(-24, hy + 3 + flow), Vector2(-29, hy + 9 + flow), Vector2(-21, hy + 12 + flow * 0.5), Vector2(-7, hy + 13)]), tc, a)
			var hood := PackedVector2Array([Vector2(-12, hy + 5), Vector2(-13, hy - 6), Vector2(-5, hy - 13), Vector2(6, hy - 13), Vector2(12, hy - 5), Vector2(12, hy + 5)])
			_poly(ci, hood, Color("#33304a"), a)
			_poly(ci, PackedVector2Array([Vector2(-12, hy - 7), Vector2(-5, hy - 12), Vector2(6, hy - 12), Vector2(11, hy - 7), Vector2(11, hy - 4), Vector2(-12, hy - 4)]), tc, a, false)
			_poly(ci, PackedVector2Array([Vector2(-5, hy - 3), Vector2(11, hy - 3), Vector2(11, hy + 6), Vector2(-5, hy + 6)]), Color("#2b2140"), a, false)
			_poly(ci, PackedVector2Array([Vector2(-11, hy + 5), Vector2(12, hy + 5), Vector2(12, hy + 11), Vector2(-11, hy + 11)]), tc, a)
			_c(ci, Vector2(3.0, hy - 0.5), 1.8, Color("#ffe066"), a, false)
			_c(ci, Vector2(8.0, hy - 0.5), 1.8, Color("#ffe066"), a, false)
			if angry:
				ci.draw_line(Vector2(1.0, hy - 3.6), Vector2(5.0, hy - 2.4), Color("#ffe066", a), 1.3, true)
				ci.draw_line(Vector2(10.0, hy - 3.6), Vector2(6.0, hy - 2.4), Color("#ffe066", a), 1.3, true)
			# 雙短刃
			var sw := w * 6.0 + sway * 10.0
			_line(ci, Vector2(10, -18 - sw), Vector2(21, -8 + sw), Color("#f0f0ff"), 2.8, a)   # 反手短刃：刃往前下，剪影露得出刀尖
			# 後手的刀：揮擊時往前交叉斬（第三輪 R4）
			var bw := maxf(0.0, w)
			_line(ci, Vector2(-8 + bw * 18, -16 - bw * 6), Vector2(-15 + bw * 44, -21 + bw * 16), Color("#f0f0ff"), 2.8, a)   # 加長加粗，看得出交叉
			_c(ci, Vector2(10, -18 - sw), 2.8, Color("#2b2140"), a)
		D.PIKE:
			# 暖銅色扁鍋盔（寬帽簷，避開劍士的銀盔）
			# 第七輪 C1-6：尖角錐笠，輪廓和圓頭盔分得開
			_poly(ci, PackedVector2Array([Vector2(-16, hy - 5), Vector2(0, hy - 18), Vector2(16, hy - 5)]), Color("#c7834a"), a)
			ci.draw_line(Vector2(-8, hy - 7), Vector2(0, hy - 15), Color(1.0, 0.86, 0.55, 0.9 * a), 1.8, true)
			# 長槍：平常斜前上方 45° 伸出頭頂；前搖收槍、揮擊放平直刺（第四輪）；專屬＝拒騎：槍幾乎直立、槍尾頓地
			var pang := -0.8 + (w * -0.25 if w < 0.0 else w * 0.75) + sway * 0.8
			var phand := Vector2(7 + (w * 6.0 if w < 0.0 else w * 9.0), -17)
			if variant == 2:
				pang = -1.2
				phand = Vector2(9, -14)
			var pdir := Vector2(cos(pang), sin(pang))
			var pbutt := phand - pdir * 14.0
			var ptip := phand + pdir * 40.0
			_line(ci, pbutt, ptip, WOOD, 2.4, a)
			_poly(ci, PackedVector2Array([ptip + pdir * 11.0, ptip + pdir.orthogonal() * 4.4, ptip - pdir.orthogonal() * 4.4]), STEEL, a)   # 第七輪 C1-6：槍尖放大
			var tas := ptip - pdir * 2.0
			_poly(ci, PackedVector2Array([tas, tas + Vector2(-4.6, 8.0), tas + Vector2(0, 6.0), tas + Vector2(3.2, 8.5)]), tc, a)   # 第七輪：槍纓改隊伍色
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
				var bp := Vector2(17 + w * 9.0, -24 + (-w) * 4.0 + sway * 12.0)   # 第七輪 C1-7：火罐托在身前、和頭拉開（縮小後不再像髮髻）
				_c(ci, bp, 7.5, Color("#2a2533"), a)
				ci.draw_circle(bp + Vector2(-2.5, -2.5), 2.0, Color(1, 1, 1, 0.35 * a), true, -1.0, true)
				_line(ci, bp + Vector2(2, -7), bp + Vector2(5, -11), Color("#c9a26b"), 1.3, a)
				var sp := 0.6 + 0.4 * sin(t * 22.0)
				_star(ci, bp + Vector2(5.5, -12), 3.2 * sp + 1.0, Color(1, 0.85, 0.3, a))
				_c(ci, Vector2(14 + w * 6.0, -17), 3.0, SKIN, a)
			else:
				# 甩臂：火罐出手後手臂往前下甩（Antigravity P2 #6）
				_line(ci, Vector2(7, -20), Vector2(12 + w * 12.0, -24 + w * 14.0), SKIN, 2.6, a)
				_c(ci, Vector2(12 + w * 12.0, -24 + w * 14.0), 3.0, SKIN, a)
		D.MEDIC:
			# 白色高方帽＋綠十字
			_poly(ci, PackedVector2Array([Vector2(-9, hy - 7), Vector2(-8, hy - 24), Vector2(8, hy - 24), Vector2(9, hy - 7)]), Color("#fbfbf7"), a)
			ci.draw_rect(Rect2(Vector2(-1.6, hy - 21), Vector2(3.2, 10)), Color("#2fbf71", a))
			ci.draw_rect(Rect2(Vector2(-5, hy - 17.6), Vector2(10, 3.2)), Color("#2fbf71", a))
			# 頂端發綠光的長杖：補血時舉高（w 往前＝舉杖）
			var lift := maxf(0.0, w) * 16.0 + (-w * 4.0 if w < 0.0 else 0.0) + sway * 14.0
			if variant == 2:
				lift = 18.0   # 專屬＝施法：雙手把杖高舉過頭
			var sbase := Vector2(15, -4 - lift)
			var stop := Vector2(21, -48 - lift)   # 第七輪：杖往外斜，剪影和方帽分開
			_line(ci, sbase, stop, WOOD, 2.2, a)
			var glow := 0.65 + 0.35 * sin(t * 4.0)
			ci.draw_circle(stop, 7.0 + lift * 0.5, Color(0.4, 1.0, 0.55, (0.28 + lift * 0.02) * glow * a), true, -1.0, true)
			# 第七輪 C1-8：杖頂大十字，遠看也知道是醫者
			_poly(ci, PackedVector2Array([stop + Vector2(-2, -6), stop + Vector2(2, -6), stop + Vector2(2, -2), stop + Vector2(6, -2), stop + Vector2(6, 2), stop + Vector2(2, 2), stop + Vector2(2, 6), stop + Vector2(-2, 6), stop + Vector2(-2, 2), stop + Vector2(-6, 2), stop + Vector2(-6, -2), stop + Vector2(-2, -2)]), Color("#7dffa0"), a)
			if variant == 2:
				_c(ci, Vector2(9.0, -24 - lift), 2.8, SKIN, a)   # 第二隻手也扶著杖
			_c(ci, Vector2(17.0, -20 - lift), 3.0, SKIN, a)
		D.DRUMMER:
			# 紅白羽毛高帽（全兵種最高）
			var hatc := tc.darkened(0.12)   # 第七輪 C1-9：帽子用隊伍色（原本藍方戴紅帽，一眼像紅軍）
			_poly(ci, PackedVector2Array([Vector2(-8, hy - 8), Vector2(-7, hy - 20), Vector2(7, hy - 20), Vector2(8, hy - 8)]), hatc, a)
			_line(ci, Vector2(-8, hy - 10), Vector2(8, hy - 10), GOLD, 1.8, a)
			_poly(ci, PackedVector2Array([Vector2(-2, hy - 20), Vector2(-6 - fl, hy - 36), Vector2(1 - fl * 0.6, hy - 30), Vector2(3, hy - 20)]), Color("#ffffff"), a)
			_poly(ci, PackedVector2Array([Vector2(1, hy - 20), Vector2(4, hy - 33), Vector2(6, hy - 20)]), tc.lightened(0.35), a, false)
			# 胸前大圓鼓
			var dc := Vector2(9, -15)   # 第七輪 C1-9：鼓放大、往前凸
			_c(ci, dc, 11.5, Color("#e9d8a6"), a)
			ci.draw_arc(dc, 11.5, 0.0, TAU, 28, Color(tc, a), 3.2, true)
			_line(ci, dc + Vector2(-6, -6), dc + Vector2(6, 6), Color("#b7814e"), 1.0, a)
			# 鼓棒：平常輕敲、揮擊時舉高大力敲兩下
			var beat := absf(sin(t * 6.0 + wk * 2.0)) * 4.0
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
			var aang := -0.35 + (w * 1.3 if w < 0.0 else w * 1.4) + sway
			if variant == 2:
				aang = -1.75   # 專屬＝破陣：雙斧高舉過頭
			for k2 in 2:
				var ah := Vector2(9, -15) if k2 == 0 else Vector2(-8, -16)
				var aa := aang if k2 == 0 else (PI - aang if w <= 0.0 else aang - 0.4)
				var adir := Vector2(cos(aa), sin(aa))
				var atip := ah + adir * 20.0
				_line(ci, ah, atip, WOOD, 2.4, a)
				var ao := adir.orthogonal()
				var blade := PackedVector2Array([atip - adir * 3.0 + ao * 1.5, atip - adir * 12.0 + ao * 11.0, atip + adir * 5.0 + ao * 10.5])   # 第七輪 C1-10：斧刃放大
				_poly(ci, blade, STEEL, a)
				ci.draw_line(blade[1], blade[2], Color(1, 1, 1, a), 1.6, true)   # 亮銀刃口
				_c(ci, ah, 3.0, SKIN, a)
	if type != D.ASSASSIN and type != D.ARCHER and type != D.SWORD and type != D.PIKE and type != D.BOMBER and type != D.MEDIC and type != D.BERSERKER:
		_c(ci, Vector2(-9, -17 - sway * 8.0), 3.0, SKIN, a)


static func _cavalry(ci: CanvasItem, tc: Color, walk: float, w: float, a: float, t: float, angry := false) -> void:
	var wk := Gait.ph(walk)
	var gallop := sin(wk) * 3.5 if wk != 0.0 else 0.0
	var pony := Color("#d9a066")
	# 腿（V9 P2）：前後腿成對的木馬步，腳踩地不滑
	var ft: Array = Gait.feet(D.CAVALRY, walk)
	var k_leg := 0
	for lx in [-11.0, -5.0, 6.0, 12.0]:
		var front: bool = lx > 0.0
		var fx: float = ft[0] if front else ft[2]
		var fy: float = ft[1] if front else ft[3]
		var lift := maxf(0.0, w) * 12.0 if front else 0.0   # 命中時馬前蹄抬起（第三輪 R4；Antigravity S4 加大）
		fx += 0.6 if k_leg % 2 == 0 else -0.6   # 同一對腿微微錯開（不縮步長，否則又會滑）
		_line(ci, Vector2(lx, -12), Vector2(lx + fx + lift * 0.6, -2 - lift - fy), Color("#9c6b3c"), 3.0, a)
		k_leg += 1
	_push_body(ci, Gait.body_xf(D.CAVALRY, walk))
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
	var tilt: float = (-0.55 + w * 0.3 if w < 0.0 else -0.55 * (1.0 - w)) + Gait.swing(D.CAVALRY, walk)   # 前搖舉高、揮擊放平前刺
	var base := Vector2(-6, -30)
	var dir := Vector2(cos(tilt), sin(tilt))
	var tip := base + dir * 50.0   # 第七輪 C1-4：騎槍加長
	_line(ci, base, tip, WOOD, 2.6, a)
	_poly(ci, PackedVector2Array([tip, tip - dir * 7.0 + dir.orthogonal() * 3.0, tip - dir * 7.0 - dir.orthogonal() * 3.0]), STEEL, a)
	var f0 := base + dir * 32.0
	_poly(ci, PackedVector2Array([f0, f0 + dir * 11.0, f0 + dir * 3.0 + dir.orthogonal() * 10.0]), tc.lightened(0.2), a)   # 隊伍色小旗放大
