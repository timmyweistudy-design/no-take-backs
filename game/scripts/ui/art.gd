extends "res://scripts/ui/units/fantasy.gd"
## 其他層在同資料夾（V9 P1 拆檔）

## 攻擊姿勢：[武器 w（−1 往後拉滿、0 平常、+1 揮到底）, 身體傾角（弧度，正＝往前）, 橫向縮放, 縱向縮放, 前撲位移]
static func idle_bob(t: float, px: float) -> float:
	return sin(t * 3.0 + px * 0.05) * 0.8

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
static func unit_xf(p: Vector2, face: float, walk: float, atk: float, t: float, scale := 1.0, lean := 0.0, crouch := 1.0, gtype := 0) -> Transform2D:
	# 外層（位置、起伏、翻面、縮放、額外傾身／蹲身）× 內層（攻擊姿勢，face＝+1 空間）。
	# 精靈圖快取烘焙的是內層，貼圖時套外層，所以兩條路的順序完全一樣（Codex R5 #3）。
	var ps := pose(atk)
	var bob := idle_bob(t, p.x) if walk == 0.0 else -Gait.air(gtype, walk)
	var outer := Transform2D(lean * face, Vector2(scale * face, scale * crouch), 0.0, p + Vector2(0, bob * scale))
	return outer * Transform2D(ps[1], Vector2(ps[2], ps[3]), 0.0, Vector2(ps[4], 0))


## 單位：p＝腳底；face＝±1；walk＝走路相位（0＝沒走）；atk＝攻擊動作進度 0～1（見上）；hurt＝受擊閃白 0～1；
## alpha＝透明度（潛行）；t＝時間（待機呼吸）；scale＝縮放；mood＝表情疊加（M_*）；lean／crouch 見 unit_xf。
static func unit(ci: CanvasItem, p: Vector2, type: int, team: int, face: float, walk: float, atk: float,
		hurt: float, alpha: float, t: float, scale := 1.0, cb := false, mood := 0, lean := 0.0, crouch := 1.0, variant := 0) -> void:
	var tc := team_color(team, cb)
	_team_now = team
	var w: float = pose(atk)[0]
	if atk > 0.0:
		walk = 0.0   # 和精靈圖一致：攻擊格沒有走路相位
	_xf = base * unit_xf(p, face, walk, atk, t, scale, lean, crouch, type)
	ci.draw_set_transform_matrix(_xf)
	# 以 face＝+1 畫（水平鏡像由 transform 處理）
	if type == D.CAVALRY:
		_cavalry(ci, tc, walk, w, alpha, t, atk > 0.0)
	elif type >= D.COUNT:
		_fantasy(ci, type, tc, walk, w, alpha, t, atk > 0.0, variant)
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
	if type >= D.COUNT:
		if not FEATURE_EYES.has(type):
			return   # 寶箱怪、羊、沙漏等臉在別處，不疊通用表情
		ec = FEATURE_EYES[type]
	var eyes := [ec + Vector2(-3.0 if type != D.ASSASSIN else -2.5, 0), ec + Vector2(4.0 if type != D.ASSASSIN else 2.5, 0)]
	var skin := Color("#2b2140") if type == D.ASSASSIN else SKIN
	if mood & M_HOOD:
		# 帽簷壓低：一條兜帽色的帽簷蓋到眼睛上緣；每 0.4 秒整個蓋住一下（眨眼）
		var shut := fmod(t, 0.4) < 0.07
		var drop := 4.6 if shut else 2.2
		ci.draw_rect(Rect2(ec + Vector2(-6.5, -4.8), Vector2(13.0, drop)), Color("#33304a", a))
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
		var cc := Vector2(11, -24)
		var k := 1.25
		var sh := PackedVector2Array()
		for q in [Vector2(1, -43), Vector2(21, -41), Vector2(21, -14), Vector2(11, -2), Vector2(1, -14)]:
			sh.append(cc + (q - cc) * k)
		_poly(ci, sh, STEEL, a)
		var inner := PackedVector2Array()
		for q2 in [Vector2(7, -33), Vector2(15, -32), Vector2(15, -17), Vector2(11, -11), Vector2(7, -17)]:
			inner.append(cc + (q2 - cc) * k)
		_poly(ci, inner, team_color(team, cb), a, false)


## 腳底隊伍標記：藍＝圓、紅＝菱形（色盲也分得出）；重兵（盾、騎）外框加粗。
static func ring(ci: CanvasItem, p: Vector2, team: int, type: int, cb := false, scale := 1.0) -> void:
	var tc := team_color(team, cb)
	var w := 4.0 if (type == D.SHIELD or type == D.CAVALRY or type == 19) else 3.0   # 第七輪 C2：腳底圈加粗
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


## 偽裝中的寶箱：闔上，只有偶爾睜一隻眼。不烘焙，直接畫。
static func mimic_closed(ci: CanvasItem, p: Vector2, team: int, face: float, a: float, t: float, cb := false, scale := 1.0) -> void:
	var tc := team_color(team, cb)
	ci.draw_set_transform_matrix(base * Transform2D(0.0, Vector2(scale * face, scale), 0.0, p))
	_poly(ci, PackedVector2Array([Vector2(-16, -3), Vector2(-16, -18), Vector2(16, -18), Vector2(16, -3)]), Color("#9c6b3c"), a)
	_poly(ci, PackedVector2Array([Vector2(-17, -17), Vector2(-15, -31), Vector2(15, -31), Vector2(17, -17)]), tc, a)
	_line(ci, Vector2(-16, -17), Vector2(16, -17), GOLD, 2.4, a)
	_poly(ci, PackedVector2Array([Vector2(-3, -21), Vector2(3, -21), Vector2(3, -13), Vector2(-3, -13)]), GOLD, a)
	if fmod(t, 3.1) < 0.35:
		ci.draw_circle(Vector2(8, -25), 2.6, Color(1, 1, 1, a), true, -1.0, true)
		ci.draw_circle(Vector2(8.6, -25), 1.3, Color(OUT, a), true, -1.0, true)
	ci.draw_set_transform_matrix(base)
