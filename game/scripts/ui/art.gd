extends "res://scripts/ui/units/fantasy.gd"
## 其他層在同資料夾（V9 P1 拆檔）

## 攻擊姿勢：[武器 w（−1 往後拉滿、0 平常、+1 揮到底）, 身體傾角（弧度，正＝往前）, 橫向縮放, 縱向縮放, 前撲位移]
## V1.3 A2：呼吸依位置（x 與 y）錯開相位、頻率 ±10%，同一欄的兵不再一起起伏。p＝腳底。
static var bake_no_bob := false   # 烘焙時不加呼吸（貼圖時才加）
static func idle_bob(t: float, p: Vector2) -> float:
	if bake_no_bob:
		return 0.0
	var h := fposmod(p.x * 0.0731 + p.y * 0.1173, 1.0)
	return sin(t * 3.0 * (0.9 + 0.2 * h) + h * TAU) * 0.8

## V1.1 A1：兵種專屬三段式（前搖／命中／收招）。值＝[前搖橫縮, 前搖縱縮, 後仰, 前搖位移, 命中橫縮, 命中縱縮, 前撲角, 前撲位移, 收招停頓比例]。
## 命中時間點（ATK_WINDUP）所有兵種相同，只改形狀，不影響模擬與命中同步。沒列的兵種走舊曲線（位元不變）。
const POSE_PROFILE := {
	0: [1.14, 0.86, 0.36, -2.0, 0.86, 1.16, 0.50, 5.0, 0.25],    # 劍士：後仰扭腰劍舉過頭 → 前撲大弧 → 劍尖點地停頓
	6: [1.08, 0.90, 0.40, -2.0, 0.90, 1.12, 0.32, 3.0, 0.15],    # 投彈兵：反弓拉滿 → 甩臂墊步 → 甩腕
	19: [0.90, 1.18, 0.12, 0.0, 1.25, 0.75, 0.12, 1.5, 0.35],    # 小石魔：雙臂高舉身體拉長 → 砸地壓扁 25% → 拳頭卡地再拔起
	# A1b（試點驗收後擴充）
	1: [1.12, 0.88, 0.25, -3.0, 0.92, 1.08, 0.35, 5.0, 0.15],    # 盾兵：縮身頂盾 → 往前撞盾
	3: [1.06, 0.94, 0.20, -2.0, 0.88, 1.10, 0.45, 6.0, 0.10],    # 騎兵：收槍 → 長槍前刺
	4: [1.10, 0.82, 0.15, -1.0, 0.85, 1.20, 0.55, 6.0, 0.10],    # 刺客：伏低 → 竄出直刺
	5: [1.06, 0.94, 0.25, -3.0, 0.90, 1.10, 0.30, 7.0, 0.20],    # 長槍兵：後拉 → 長刺定住
	9: [1.16, 0.84, 0.55, -2.0, 0.84, 1.18, 0.55, 4.0, 0.20],    # 狂戰士：雙斧高舉大後仰 → 全身劈下
	2: [1.08, 0.92, 0.32, -3.0, 0.94, 1.08, 0.18, 1.5, 0.30],    # 弓箭手：拉弓 → 放箭、手停在弦上（V1.3.1：滿弓後仰加大）
	7: [1.10, 0.90, 0.36, -2.0, 0.92, 1.10, 0.34, 2.5, 0.20],    # 醫者：舉杖 → 點地（V1.3.1：高舉施法更明顯）
	8: [1.12, 0.88, 0.35, -2.0, 0.88, 1.14, 0.38, 2.0, 0.15],    # 鼓手：高舉鼓槌 → 重敲
	10: [1.15, 0.85, 0.00, 0.0, 0.88, 1.15, 0.00, 0.0, 0.20],    # 孢子菇：縮傘 → 噴孢子（不前撲，定點）
	11: [1.10, 0.90, 0.10, -2.0, 0.90, 1.10, 0.30, 4.0, 0.10],   # 爆爆羊：後蹲 → 衝撞
	12: [1.12, 0.86, 0.10, -1.0, 0.90, 1.14, 0.35, 5.0, 0.15],   # 寶箱怪：蓋子壓低 → 撲咬
	13: [1.20, 0.80, 0.00, 0.0, 0.85, 1.20, 0.20, 4.0, 0.20],    # 史萊姆：壓扁蓄力 → 彈出
	14: [1.00, 1.00, 0.20, -2.0, 0.92, 1.10, 0.40, 6.0, 0.10],   # 幽靈：後飄 → 穿刺
	15: [1.05, 0.95, 0.20, -1.0, 0.95, 1.06, 0.25, 2.0, 0.25],   # 巫毒娃娃：舉針 → 扎下
	16: [1.00, 1.05, 0.15, 0.0, 0.95, 1.08, 0.20, 2.0, 0.20],    # 沙漏精靈：上浮 → 點擊
	17: [0.98, 1.12, 0.32, 0.0, 0.94, 1.10, 0.30, 2.5, 0.25],    # 骷髏法師：舉書聚光 → 施放（V1.3.1：後仰拉高）
	18: [1.12, 0.88, 0.15, -2.0, 0.90, 1.12, 0.40, 5.0, 0.15],   # 吸塵貓：弓背 → 撲抓
	20: [1.20, 0.80, 0.00, 0.0, 0.85, 1.20, 0.20, 3.0, 0.20],    # 小史萊姆
	21: [1.14, 0.86, 0.30, -2.0, 0.86, 1.16, 0.40, 4.0, 0.20],   # 骷髏：舉骨刀 → 劈
}

static func pose(atk: float, type := -1) -> Array:
	if atk <= 0.0:
		return [0.0, 0.0, 1.0, 1.0, 0.0]
	if POSE_PROFILE.has(type):
		return _pose_prof(atk, POSE_PROFILE[type])
	if atk < ATK_WINDUP:
		var e := _smooth(atk / ATK_WINDUP)
		return [-e, -LEAN_BACK * e, 1.0 + 0.12 * e, 1.0 - 0.12 * e, -1.0 * e]   # 前搖壓扁蓄力 1.12／0.88
	if atk < ATK_STRIKE:
		var u := (atk - ATK_WINDUP) / (ATK_STRIKE - ATK_WINDUP)
		var e2 := 1.0 - (1.0 - u) * (1.0 - u)
		return [lerpf(-1.0, 1.0, e2), lerpf(-LEAN_BACK, LEAN_FWD, e2), lerpf(1.12, 0.88, e2), lerpf(0.88, 1.14, e2), lerpf(-1.0, 3.0, e2)]   # 揮擊拉長 0.88／1.14；前撲位移縮小，腳不滑出底圈（Antigravity S2 #3）
	var e3 := _smooth((atk - ATK_STRIKE) / (1.0 - ATK_STRIKE))
	return [lerpf(1.0, 0.0, e3), lerpf(LEAN_FWD, 0.0, e3), lerpf(0.88, 1.0, e3), lerpf(1.14, 1.0, e3), lerpf(3.0, 0.0, e3)]


## 前搖到底的後仰角（勝利姿勢用來抵銷，站直）。
static func windup_lean(type: int) -> float:
	return float(POSE_PROFILE[type][2]) if POSE_PROFILE.has(type) else LEAN_BACK

static func _pose_prof(atk: float, f: Array) -> Array:
	if atk < ATK_WINDUP:
		var e := _smooth(atk / ATK_WINDUP)
		return [-e, -f[2] * e, lerpf(1.0, f[0], e), lerpf(1.0, f[1], e), f[3] * e]
	if atk < ATK_STRIKE:
		var u := (atk - ATK_WINDUP) / (ATK_STRIKE - ATK_WINDUP)
		var e2 := 1.0 - (1.0 - u) * (1.0 - u)
		return [lerpf(-1.0, 1.0, e2), lerpf(-f[2], f[6], e2), lerpf(f[0], f[4], e2), lerpf(f[1], f[5], e2), lerpf(f[3], f[7], e2)]
	var r := (atk - ATK_STRIKE) / (1.0 - ATK_STRIKE)
	var e3 := _smooth(clampf((r - f[8]) / (1.0 - f[8]), 0.0, 1.0))   # 先停在命中姿勢 f[8]，再收回
	return [lerpf(1.0, 0.0, e3), lerpf(f[6], 0.0, e3), lerpf(f[4], 1.0, e3), lerpf(f[5], 1.0, e3), lerpf(f[7], 0.0, e3)]


## 角色的局部座標轉換（以腳底為原點、face＝+1 畫）：呼吸／走路起伏、前撲、傾身、壓扁拉長、翻面。
## lean＝額外傾角（騎兵衝鋒前傾）、crouch＝縱向縮放（刺客潛行蹲身）。
static func unit_xf(p: Vector2, face: float, walk: float, atk: float, t: float, scale := 1.0, lean := 0.0, crouch := 1.0, gtype := 0) -> Transform2D:
	# 外層（位置、起伏、翻面、縮放、額外傾身／蹲身）× 內層（攻擊姿勢，face＝+1 空間）。
	# 精靈圖快取烘焙的是內層，貼圖時套外層，所以兩條路的順序完全一樣（Codex R5 #3）。
	var ps := pose(atk, gtype)
	var bob := idle_bob(t, p) if walk == 0.0 else -Gait.air(gtype, walk)
	var outer := Transform2D(lean * face, Vector2(scale * face, scale * crouch), 0.0, p + Vector2(0, bob * scale))
	return outer * Transform2D(ps[1], Vector2(ps[2], ps[3]), 0.0, Vector2(ps[4], 0))


## 單位：p＝腳底；face＝±1；walk＝走路相位（0＝沒走）；atk＝攻擊動作進度 0～1（見上）；hurt＝受擊閃白 0～1；
## alpha＝透明度（潛行）；t＝時間（待機呼吸）；scale＝縮放；mood＝表情疊加（M_*）；lean／crouch 見 unit_xf。
static func unit(ci: CanvasItem, p: Vector2, type: int, team: int, face: float, walk: float, atk: float,
		hurt: float, alpha: float, t: float, scale := 1.0, cb := false, mood := 0, lean := 0.0, crouch := 1.0, variant := 0) -> void:
	var tc := team_color(team, cb)
	_team_now = team
	var w: float = pose(atk, type)[0]
	if atk > 0.0:
		walk = 0.0   # 和精靈圖一致：攻擊格沒有走路相位
	_xf = base * unit_xf(p, face, walk, atk, t, scale, lean, crouch, type)
	_b_now = Transform2D.IDENTITY
	if turn_c < 1.0:
		_xf0 = _xf
		# 史萊姆轉向鏡頭時微微拉高（Antigravity v130-impl1：只有眼睛動看不出在轉）
		var sy := 1.0 + 0.06 * (1.0 - turn_c) if type == 13 else 1.0
		_xf = _xf * Transform2D(0.0, Vector2(turn_body_w(type) * (0.97 if type == 13 else 1.0), sy), 0.0, Vector2.ZERO)
	_cur_xf = _xf
	ci.draw_set_transform_matrix(_xf)
	# 以 face＝+1 畫（水平鏡像由 transform 處理）
	if type == D.CAVALRY:
		_cavalry(ci, tc, walk, w, alpha, t, atk > 0.0 and not calm)
	elif type >= D.COUNT:
		_fantasy(ci, type, tc, walk, w, alpha, t, atk > 0.0 and not calm, variant)
	else:
		_infantry(ci, type, tc, walk, w, alpha, t, atk > 0.0 and not calm, variant)
	if hurt > 0.0:
		# 受擊閃白：在身體位置疊一層白
		ci.draw_circle(Vector2(0, -26), 14.0, Color(1, 1, 1, hurt * 0.55 * alpha), true, -1.0, true)
	if mood != 0:
		overlay(ci, type, team, mood, alpha, t, cb)
	ci.draw_set_transform_matrix(base)


## 表情與狀態疊加：呼叫前畫布轉換要已經是這隻角色的局部座標（face＝+1 空間）。
static func overlay(ci: CanvasItem, type: int, team: int, mood: int, a: float, t: float, cb := false) -> void:
	if mood & M_HAPPY:
		mood &= ~M_HURT   # V1.3.1：歡呼優先於受擊眼
	var ec := Vector2(2.0, -43.0) if type == D.CAVALRY else (Vector2(5.5, -33.5) if type == D.ASSASSIN else Vector2(3.5, -32.0))
	if type >= D.COUNT:
		if not FEATURE_EYES.has(type):
			return   # 寶箱怪、羊、沙漏等臉在別處，不疊通用表情
		ec = FEATURE_EYES[type]
	var eyes := [ec + Vector2(-3.0 if type != D.ASSASSIN else -2.5, 0), ec + Vector2(4.0 if type != D.ASSASSIN else 2.5, 0)]
	var skin := Color("#2b2140") if type == D.ASSASSIN else SKIN
	match type:   # V1.3.1：新加表情的兵種，蓋眼睛用自己臉的顏色（Codex v131-impl2：通用膚色會變異色圓斑）
		11:
			skin = Color("#3a3346")
		14:
			skin = team_color(team, cb).lightened(0.3)
		17, 21:
			skin = Color("#f5f0e0")
	if mood & (M_HAPPY | M_SURPRISE | M_GRIM):
		for e in eyes:
			ci.draw_circle(e, 3.4, Color(skin, a), true, -1.0, true)   # 先蓋掉原本的眼睛
			if mood & M_HAPPY:
				ci.draw_arc(e + Vector2(0, 1.2), 2.6, PI * 1.15, PI * 1.85, 6, Color(OUT, a), 1.7, true)
			elif mood & M_SURPRISE:
				ci.draw_circle(e, 3.0, Color(OUT, a), true, -1.0, true)
				ci.draw_circle(e + Vector2(0.6, -0.7), 1.2, Color(1, 1, 1, a), true, -1.0, true)
			else:
				ci.draw_circle(e + Vector2(0, 0.6), 2.2, Color(OUT, a), true, -1.0, true)
				ci.draw_line(e + Vector2(-2.6, -3.4), e + Vector2(2.6, -2.2), Color(OUT, a), 1.4, true)
		var mc: Vector2 = (eyes[0] + eyes[1]) * 0.5 + Vector2(0, 6.0)
		if mood & M_SURPRISE:
			ci.draw_circle(mc, 1.6, Color(OUT, a), true, -1.0, true)
		elif mood & M_GRIM:
			ci.draw_arc(mc + Vector2(0, 2.0), 2.4, PI * 1.2, PI * 1.8, 6, Color(OUT, a), 1.3, true)
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
## V1.3 A3：腳底三層，由下往上：厚木座（棋子底座，留在地上）→ 接觸影子（跳起來會縮）→ 隊伍圈。
## air＝離地程度 0～1（只縮影子）。
static func ring(ci: CanvasItem, p: Vector2, team: int, type: int, cb := false, scale := 1.0, air := 0.0) -> void:
	ring_base(ci, p, scale)
	ring_shadow(ci, p, scale * (1.0 - air * 0.35))
	ring_mark(ci, p, team, type, cb, scale)

## 厚木座：下緣 2.5px 深色厚度、頂面木色、上緣 1px 亮倒角（深色地面也看得出邊）。
static func ring_base(ci: CanvasItem, p: Vector2, scale := 1.0, a := 1.0) -> void:
	# 比隊伍圈寬一圈（rx 21），外露的木邊看得出是棋子底座（Antigravity v130-impl1：原本被隊伍圈蓋住）
	var wd: Array = WOODS[clampi(int(paint[4]), 0, 3)]   # V1.4 #15：木座木料
	ci.draw_colored_polygon(_ell(p + Vector2(0, 3.2) * scale, 21.0 * scale, 10.5 * scale), Color(wd[0], 0.85 * a))
	ci.draw_colored_polygon(_ell(p, 21.0 * scale, 10.5 * scale), Color(wd[1], 0.92 * a))
	ci.draw_colored_polygon(_ell(p + Vector2(0, 0.6) * scale, 15.5 * scale, 7.4 * scale), Color(wd[2], 0.6 * a))
	ci.draw_arc(p + Vector2(0, -0.2) * scale, 20.4 * scale, PI * 1.08, PI * 1.92, 14, Color(1.0, 0.9, 0.7, 0.5 * a), 1.1 * scale, true)

## 接觸影子（角色腳下）。
static func ring_shadow(ci: CanvasItem, p: Vector2, scale := 1.0) -> void:
	ci.draw_colored_polygon(_ell(p + Vector2(0, 0.5) * scale, 12.0 * scale, 5.6 * scale), Color(0.08, 0.05, 0.03, 0.34))

static func ring_mark(ci: CanvasItem, p: Vector2, team: int, type: int, cb := false, scale := 1.0) -> void:
	var tc := team_color(team, cb)
	var w := 4.0 if (type == D.SHIELD or type == D.CAVALRY or type == 19) else 3.0   # 第七輪 C2：腳底圈加粗
	var pts := PackedVector2Array()
	if team == 0:
		for i in 25:
			var ang := i * TAU / 24.0
			pts.append(p + Vector2(cos(ang) * 15.0, sin(ang) * 7.5) * scale)
	else:
		pts = PackedVector2Array([p + Vector2(-16, 0) * scale, p + Vector2(0, -8.5) * scale, p + Vector2(16, 0) * scale, p + Vector2(0, 8.5) * scale, p + Vector2(-16, 0) * scale])
	ci.draw_polyline(pts, OUT, w + (6.5 if cb else 2.5), true)   # 第十輪 V9：色盲配色黑邊加粗，黃底座在沙地、草地才分得開
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
