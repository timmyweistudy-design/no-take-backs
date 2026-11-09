extends "res://scripts/ui/units/kingdom.gd"
## 由 art.gd 拆出（V9 P1，行為不變）

# ───────────────────────── 第八輪奇幻軍 ─────────────────────────
## 隊伍色放上半身、面積要夠（§6）。全部 Q 版二頭身、粗黑框、白眼黑瞳。
static func _fantasy(ci: CanvasItem, type: int, tc: Color, walk: float, w: float, a: float, t: float, angry := false, variant := 0) -> void:
	match type:
		10: _f_spore(ci, tc, walk, w, a, t, angry)
		11: _f_sheep(ci, tc, walk, w, a, t, angry)
		12: _f_mimic(ci, tc, walk, w, a, t, angry)
		13: _f_slime(ci, tc, walk, w, a, t, angry, 1.0)
		14: _f_ghost(ci, tc, walk, w, a, t, angry)
		15: _f_doll(ci, tc, walk, w, a, t, angry)
		16: _f_sprite(ci, tc, walk, w, a, t, angry)
		17: _f_bone(ci, tc, walk, w, a, t, angry, variant)
		18: _f_cat(ci, tc, walk, w, a, t, angry, variant)
		19: _f_golem(ci, tc, walk, w, a, t, angry, variant)
		20: _f_slime(ci, tc, walk, w, a, t, angry, 0.66)
		21: _f_skeleton(ci, tc, walk, w, a, t, angry)


static func _f_spore(ci: CanvasItem, tc: Color, walk: float, w: float, a: float, t: float, angry: bool) -> void:
	_push_body(ci, _atk_xf(Gait.body_xf(10, walk), maxf(w, 0.0), 0.3, 0.0, true))
	# 短胖的柄＋超大菇傘；攻擊（噴毒）時整朵壓扁再彈起，底下兩朵小芽
	var sq := 1.0 + maxf(0.0, w) * 0.22 - minf(0.0, w) * 0.1
	var low := 1.0 - maxf(0.0, w) * 0.2
	for s in [[-14.0, 4.0], [14.0, 3.2]]:
		_poly(ci, PackedVector2Array([Vector2(s[0] - 1.6, -2), Vector2(s[0] - 1.2, -6), Vector2(s[0] + 1.2, -6), Vector2(s[0] + 1.6, -2)]), Color("#f2e6cf"), a, false)
		ci.draw_circle(Vector2(s[0], -7), s[1], Color(OUT, a), true, -1.0, true)
		ci.draw_circle(Vector2(s[0], -7), s[1] - 1.4, Color(tc, a), true, -1.0, true)
	_poly(ci, PackedVector2Array([Vector2(-10, -3), Vector2(-8, -22 * low), Vector2(8, -22 * low), Vector2(10, -3)]), Color("#f2e6cf"), a)
	ci.draw_line(Vector2(-6, -8), Vector2(6, -8), Color("#d9c6a3", a), 1.4, true)
	_eyes(ci, Vector2(1.5, -13 * low), a, t, angry)
	var cy := -22.0 * low
	var cap := _ell(Vector2(0, cy), 22.0 * sq, 19.0 * low, PI, TAU, 16)
	cap.append(Vector2(15 * sq, cy + 5)); cap.append(Vector2(-15 * sq, cy + 5))
	_poly(ci, cap, tc, a)
	ci.draw_arc(Vector2(0, cy), 16.0 * sq, PI * 1.33, PI * 1.67, 8, Color(1, 1, 1, 0.4 * a), 2.6, true)   # V1.3.1：高光改在正上方，翻面不跳邊
	for d in [[-11, -8, 3.6], [3, -14, 4.4], [13, -6, 3.0], [-3, -4, 2.6]]:
		_c(ci, Vector2(d[0] * sq, cy + d[1] * low), d[2], Color("#fff7e6"), a, false)
	if w > 0.0:
		for k in 5:
			var an := -PI + k * PI / 4.0
			ci.draw_circle(Vector2(cos(an) * (24 + w * 8), cy + sin(an) * (17 + w * 8)), 2.6, Color(0.7, 1.0, 0.45, 0.85 * a), true, -1.0, true)


static func _f_sheep(ci: CanvasItem, tc: Color, walk: float, w: float, a: float, t: float, angry: bool) -> void:
	var wk := Gait.ph(walk)
	var ft: Array = Gait.feet(11, walk)
	for lx in [-11.0, -4.0, 5.0, 12.0]:
		var front: bool = lx > 0.0
		var sw: float = (ft[0] if front else ft[2])
		var up: float = (ft[1] if front else ft[3])
		_line(ci, Vector2(lx, -10), Vector2(lx + sw, -3 - up), Color("#4a4258"), 3.0, a)
		_c(ci, Vector2(lx + sw, -2.5 - up), 2.4, Color("#1d1a2b"), a, false)   # 黑蹄
	_push_body(ci, Gait.body_xf(11, walk))
	# 羊毛染隊伍色（白毛會被特效洗掉）
	var wool := tc.lightened(0.14)
	var blobs := [[-11, -18, 9.5], [0, -23, 11.5], [11, -18, 9.0], [-5, -13, 8.5], [6, -13, 8.5], [-1, -30, 8.5], [-9, -26, 7.5], [8, -27, 7.5]]
	for b in blobs:
		_c(ci, Vector2(b[0], b[1]), b[2], wool, a)
	for b2 in blobs:
		ci.draw_circle(Vector2(b2[0], b2[1]), b2[2], Color(wool, a), true, -1.0, true)
	for h in [[-5, -28, 3.6], [6, -25, 2.8], [-9, -18, 2.4]]:
		ci.draw_circle(Vector2(h[0], h[1]), h[2], Color(1, 1, 1, 0.4 * a), true, -1.0, true)
	# 臉
	_part_at(ci, 16.0)   # V1.3.1：羊頭是圓的，轉身時移到中間、不壓扁
	_c(ci, Vector2(16, -22), 8.5, Color("#3a3346"), a)
	_poly(ci, PackedVector2Array([Vector2(9, -27), Vector2(4, -30), Vector2(7, -24)]), Color("#3a3346"), a)   # 耳朵
	for ex in [13.0, 19.0]:
		ci.draw_circle(Vector2(ex, -23), 2.9, Color(1, 1, 1, a), true, -1.0, true)
		ci.draw_circle(Vector2(ex + 0.7, -23), 1.4, Color(OUT, a), true, -1.0, true)
	ci.draw_arc(Vector2(16, -18), 2.6, 0.3, PI - 0.3, 6, Color(1, 1, 1, 0.8 * a), 1.2, true)
	_part_end(ci)
	# 頭上的引線（招牌）：越接近爆炸火花越大
	_line(ci, Vector2(-1, -37), Vector2(4, -47), Color("#c9a26b"), 1.8, a)
	var sp := 0.7 + 0.3 * sin(t * 18.0 + wk * 3.0) + maxf(0.0, w)
	_star(ci, Vector2(5, -49), 5.0 * sp + 1.0, Color(1, 0.8, 0.25, a))


static func _f_mimic(ci: CanvasItem, tc: Color, walk: float, w: float, a: float, t: float, angry: bool) -> void:
	# V9 P2：走路時閉蓋貼地跳（整隻離地在 Gait.air），只有箱蓋輕敲；接敵才張嘴
	var wk := Gait.ph(walk)
	_push_body(ci, Gait.body_xf(12, walk))
	var open := 0.45 + maxf(0.0, w) * 0.55 - minf(0.0, w) * 0.2
	if wk != 0.0 and w == 0.0:
		open = 0.04 + absf(sin(wk)) * 0.26   # 跳到最高才張嘴露一點舌（Antigravity P2 #1）
	var by := -3.0
	# V1.5：轉身時看得到箱子的側面（深色木板、斜上一點），是個有厚度的箱子，不是一張紙
	var dpt := 14.0 * turn_s
	if dpt > 0.5:
		_poly(ci, PackedVector2Array([Vector2(-16, by), Vector2(-16 - dpt, by - 3), Vector2(-16 - dpt, by - 18), Vector2(-16, by - 15)]), Color("#7a512c"), a)
		ci.draw_line(Vector2(-16, by - 7), Vector2(-16 - dpt, by - 10), Color(OUT, 0.45 * a), 1.4, true)
	_poly(ci, PackedVector2Array([Vector2(-16, by), Vector2(-16, by - 15), Vector2(16, by - 15), Vector2(16, by)]), Color("#9c6b3c"), a)
	ci.draw_line(Vector2(-16, by - 7), Vector2(16, by - 7), Color(OUT, 0.5 * a), 1.6, true)
	for rv in [[-14, by - 2], [14, by - 2], [-14, by - 13], [14, by - 13]]:
		ci.draw_circle(Vector2(rv[0], rv[1]), 1.5, Color(GOLD, a), true, -1.0, true)   # 鉚釘
	# 舌頭與牙
	var mouth := by - 15.0
	_poly(ci, PackedVector2Array([Vector2(-13, mouth), Vector2(13, mouth), Vector2(13, mouth - 4 - open * 10), Vector2(-13, mouth - 4 - open * 10)]), Color("#3b0f1e"), a, false)
	var lick := maxf(0.0, w) * 8.0
	if open > 0.2:
		_poly(ci, PackedVector2Array([Vector2(2, mouth), Vector2(19 + lick, mouth + 2), Vector2(23 + lick, mouth - 3), Vector2(19 + lick, mouth - 7), Vector2(4, mouth - 5)]), Color("#ff6b81"), a)
	for k in 4:
		var tx := -10.0 + k * 7.0
		ci.draw_colored_polygon(PackedVector2Array([Vector2(tx, mouth), Vector2(tx + 5, mouth), Vector2(tx + 2.5, mouth - 5)]), Color(1, 1, 1, a))
	# 箱蓋（隊伍色，面積最大）
	var ly := mouth - 4 - open * 12
	if dpt > 0.5:
		_poly(ci, PackedVector2Array([Vector2(-19, ly), Vector2(-19 - dpt, ly - 3), Vector2(-17 - dpt, ly - 20), Vector2(-17, ly - 17)]), tc.darkened(0.3), a)   # 箱蓋側面
	_poly(ci, PackedVector2Array([Vector2(-19, ly), Vector2(-17, ly - 17), Vector2(17, ly - 19), Vector2(19, ly)]), tc, a)
	_line(ci, Vector2(-17, ly - 1), Vector2(17, ly - 1), GOLD, 2.0, a)
	_poly(ci, PackedVector2Array([Vector2(-16, by - 15), Vector2(-9, by - 15), Vector2(-9, by), Vector2(-16, by)]), tc.darkened(0.1), a, false)
	_poly(ci, PackedVector2Array([Vector2(9, by - 15), Vector2(16, by - 15), Vector2(16, by), Vector2(9, by)]), tc.darkened(0.1), a, false)
	for k2 in 2:
		var ex := -6.0 + k2 * 12.0
		ci.draw_circle(Vector2(ex, ly - 9), 3.6, Color(1, 1, 1, a), true, -1.0, true)
		ci.draw_circle(Vector2(ex + 1, ly - 9), 1.8, Color(OUT, a), true, -1.0, true)
	if angry:
		ci.draw_line(Vector2(-10, ly - 14), Vector2(-3, ly - 12), Color(OUT, a), 1.6, true)
		ci.draw_line(Vector2(10, ly - 14), Vector2(3, ly - 12), Color(OUT, a), 1.6, true)


static func _f_slime(ci: CanvasItem, tc: Color, walk: float, w: float, a: float, t: float, angry: bool, k: float) -> void:
	# 果凍：底部微扁、頂上一小尖，走路和攻擊時壓扁彈起
	var wk := Gait.ph(walk)
	# 落地壓扁、騰空拉長（Antigravity P2 #2）：拉長時整隻離地（Gait.air）
	var sq := (1.14 - absf(sin(wk)) * 0.26 if wk != 0.0 else 1.0) + maxf(0.0, w) * 0.3 - minf(0.0, w) * 0.12
	if walk < -150.0:
		sq = 1.22
	var rx := 20.0 * k * sq
	var ry := 17.0 * k / sq
	var cy := -ry - 1.0
	var pts := _ell(Vector2(0, cy), rx, ry * 1.02, 0.08, PI - 0.08, 12)
	pts.append(Vector2(-rx * 0.9, cy - ry * 0.5))
	pts.append(Vector2(-rx * 0.45, cy - ry * 1.0))
	pts.append(Vector2(0.5 * k, cy - ry * 1.5))
	pts.append(Vector2(rx * 0.45, cy - ry * 1.0))
	pts.append(Vector2(rx * 0.9, cy - ry * 0.5))
	_poly(ci, pts, tc.lightened(0.05), a)
	ci.draw_arc(Vector2(0, cy - ry * 0.1), rx * 0.82, 0.55, PI - 0.55, 10, Color(tc.darkened(0.25), 0.55 * a), 2.6 * k, true)
	if not baking:   # V1.3.1：烘焙時不畫高光，貼圖後依世界方向（左上）補畫，翻面不跳邊
		ci.draw_circle(Vector2(-rx * 0.45, cy - ry * 0.4), 3.8 * k, Color(1, 1, 1, 0.6 * a), true, -1.0, true)
		ci.draw_circle(Vector2(-rx * 0.18, cy - ry * 0.85), 1.8 * k, Color(1, 1, 1, 0.6 * a), true, -1.0, true)
	for b in [[0.5, 0.45, 2.2], [-0.25, 0.65, 1.6], [0.62, -0.1, 1.5]]:
		ci.draw_arc(Vector2(rx * b[0], cy + ry * b[1]), b[2] * k, 0, TAU, 8, Color(1, 1, 1, 0.35 * a), 1.0, true)
	_eyes(ci, Vector2(3.0 * k, cy + 1.0), a, t, angry)
	if k >= 1.0:
		# V1.3.1 剪影：大史萊姆頭頂小王冠（會分裂的那種），和小史萊姆一眼分開
		var cr := Vector2(0.5, cy - ry * 1.42)
		_poly(ci, PackedVector2Array([cr + Vector2(-6, 2), cr + Vector2(-6, -5), cr + Vector2(-3, -1.5), cr + Vector2(0, -7), cr + Vector2(3, -1.5), cr + Vector2(6, -5), cr + Vector2(6, 2)]), GOLD, a)


static func _f_ghost(ci: CanvasItem, tc: Color, walk: float, w: float, a: float, t: float, angry: bool) -> void:
	# 無腳飄浮：飄逸的長裙擺，隊伍色披巾在肩上；攻擊時張大嘴
	var body := tc.lightened(0.3)
	var wk := Gait.ph(walk)
	var lean := w * 4.0 + (4.5 if wk != 0.0 else 0.0)   # 前進要看得出來（Antigravity P2 #7）
	var sway := sin(t * 2.0 + wk) * 2.6
	_push_body(ci, Gait.body_xf(14, walk))
	var top := -48.0
	var pts := _ell(Vector2(lean, top + 15), 16.0, 15.0, PI, TAU, 14)
	for s in [[16.0, -24.0], [17.0, -14.0], [11.0, -5.0 + sway], [7.0, -11.0], [2.0, -3.0 - sway], [-3.0, -11.0], [-8.0, -4.0 + sway], [-13.0, -11.0], [-18.0, -7.0 - sway], [-16.0, -24.0]]:
		pts.append(Vector2(s[0] + lean * (0.2 + (-s[1]) * 0.02), s[1]))
	_poly(ci, pts, Color(body, 0.94), a)
	_poly(ci, PackedVector2Array([Vector2(-16 + lean, -33), Vector2(16 + lean, -33), Vector2(17 + lean * 0.7, -24), Vector2(4 + lean * 0.5, -21), Vector2(-16 + lean * 0.7, -24)]), tc, a, false)
	ci.draw_line(Vector2(-16 + lean, -33), Vector2(16 + lean, -33), Color(tc.darkened(0.25), a), 1.6, true)
	var ey := -40.0
	_part_at(ci, 2.5 + lean)   # V1.3.1：臉轉向鏡頭時移到中間
	for ex in [-2.0 + lean, 7.0 + lean]:
		ci.draw_circle(Vector2(ex, ey), 3.3, Color(OUT, a), true, -1.0, true)
		ci.draw_circle(Vector2(ex + 0.9, ey - 1.0), 1.1, Color(1, 1, 1, a), true, -1.0, true)
		ci.draw_arc(Vector2(ex, ey), 4.8, 0.4, PI - 0.4, 6, Color(tc.darkened(0.2), 0.6 * a), 1.4, true)   # 黑眼圈
	if angry or w > 0.0:
		ci.draw_circle(Vector2(2.5 + lean, ey + 7), 3.2, Color(OUT, a), true, -1.0, true)
	else:
		ci.draw_arc(Vector2(2.5 + lean, ey + 5), 2.2, 0.3, PI - 0.3, 6, Color(OUT, a), 1.3, true)
	var hd := sin(wk + 0.9) * 2.0 if wk != 0.0 else 0.0   # 手延遲
	_part(ci, 4.0, 0.5)   # 遠側的手
	_c(ci, Vector2(-15 + lean + w * 5.0 - hd, -25 + hd), 3.6, body, a)
	_part(ci, -4.0, 0.5)  # 近側的手
	_c(ci, Vector2(16 + lean + maxf(0.0, w) * 10.0 - hd, -26 - hd), 3.6, body, a)
	_part_end(ci)


static func _f_doll(ci: CanvasItem, tc: Color, walk: float, w: float, a: float, t: float, angry: bool) -> void:
	var ft: Array = Gait.feet(15, walk)
	var bx: Transform2D = Gait.body_xf(15, walk)
	_line(ci, Vector2(-5, -11 + bx.origin.y), Vector2(-5 + ft[0], -2 - ft[1]), Color("#c9a26b"), 3.2, a)
	_line(ci, Vector2(5, -11 + bx.origin.y), Vector2(5 + ft[2], -2 - ft[3]), Color("#c9a26b"), 3.2, a)
	_push_body(ci, bx)
	var sway: float = Gait.swing(15, walk)
	# 隊伍色布身，粗縫線
	var body := PackedVector2Array([Vector2(-11, -8), Vector2(-13, -24), Vector2(13, -24), Vector2(11, -8)])
	_poly(ci, body, tc, a)
	for k in 3:
		var y := -21.0 + k * 5.0
		ci.draw_line(Vector2(-3, y), Vector2(3, y + 2.2), Color(OUT, 0.8 * a), 1.5, true)
		ci.draw_line(Vector2(3, y), Vector2(-3, y + 2.2), Color(OUT, 0.8 * a), 1.5, true)
	_part(ci, 4.0, 0.6)   # V1.3.1：遠側手
	_line(ci, Vector2(-12, -21), Vector2(-17 - sway * 12.0, -15 - w * 5.0 + sway * 6.0), tc.darkened(0.15), 3.2, a)
	_part(ci, -4.0, 0.6)  # 近側手
	_line(ci, Vector2(12, -21), Vector2(18 + sway * 12.0, -15 + w * -5.0 + sway * 6.0), tc.darkened(0.15), 3.2, a)
	# 麻布頭、一邊大鈕扣、一邊 X
	_part(ci, 0.0, 0.0)   # 圓頭不壓扁
	_c(ci, Vector2(0, -35), 12.5, Color("#e8d3a8"), a)
	_c(ci, Vector2(6, -35), 4.6, tc.lightened(0.3), a)
	ci.draw_circle(Vector2(5, -36), 1.1, Color(OUT, a), true, -1.0, true)
	ci.draw_circle(Vector2(7.5, -34), 1.1, Color(OUT, a), true, -1.0, true)
	ci.draw_line(Vector2(-8, -38), Vector2(-3, -33), Color(OUT, a), 2.0, true)
	ci.draw_line(Vector2(-3, -38), Vector2(-8, -33), Color(OUT, a), 2.0, true)
	ci.draw_line(Vector2(-4, -28), Vector2(5, -28), Color(OUT, a), 1.5, true)
	# 頭上插一根大針（招牌）
	var nd := sway * 14.0
	_part(ci, 3.0, 0.8)   # 頭上的針往後斜（遠側）
	_line(ci, Vector2(-3, -40), Vector2(-11 - nd, -54), STEEL, 1.8, a)
	_c(ci, Vector2(-12 - nd, -56), 3.4, Color("#ff4d6d"), a)
	_part_end(ci)


static func _f_sprite(ci: CanvasItem, tc: Color, walk: float, w: float, a: float, t: float, angry: bool) -> void:
	var wk := Gait.ph(walk)
	_push_body(ci, Gait.body_xf(16, walk))
	# 飄浮的大沙漏，不畫人形（免得和鼓手、醫者撞）；弧形翅膀、沙子往下流
	var flap := sin(t * 9.0 + wk * 3.0) * 4.5 - minf(w, 0.0) * 6.0
	for s in [-1.0, 1.0]:
		_part(ci, -4.0 * s, 0.6)   # V1.3.1：翅膀一遠一近，轉身時翼展壓窄
		var wing := PackedVector2Array([Vector2(s * 8, -32), Vector2(s * 18, -47 + flap), Vector2(s * 29, -48 + flap), Vector2(s * 33, -37 + flap), Vector2(s * 28, -26 + flap * 0.6), Vector2(s * 19, -19), Vector2(s * 9, -22)])
		_poly(ci, wing, Color(tc.lightened(0.42), 0.97), a)
		ci.draw_line(Vector2(s * 11, -30), Vector2(s * 27, -41 + flap), Color(tc, 0.7 * a), 1.6, true)
		ci.draw_line(Vector2(s * 11, -26), Vector2(s * 26, -31 + flap * 0.8), Color(tc, 0.7 * a), 1.6, true)
	_part_end(ci)
	var glass := Color("#e8f4ff")
	_poly(ci, PackedVector2Array([Vector2(-13, -47), Vector2(13, -47), Vector2(2, -27), Vector2(13, -8), Vector2(-13, -8), Vector2(-2, -27)]), glass, a)
	_poly(ci, PackedVector2Array([Vector2(-9, -41), Vector2(9, -41), Vector2(1, -29), Vector2(-1, -29)]), tc, a, false)
	_poly(ci, PackedVector2Array([Vector2(-11, -9), Vector2(11, -9), Vector2(6, -17), Vector2(0, -22), Vector2(-6, -17)]), tc, a, false)
	var flow := fmod(t * 2.0 + wk / TAU, 1.0)
	for k in 3:
		ci.draw_circle(Vector2(0, -28 + fmod(flow + k * 0.33, 1.0) * 8.0), 1.1, Color(tc, a), true, -1.0, true)
	ci.draw_line(Vector2(-2, -45), Vector2(2, -37), Color(1, 1, 1, 0.8 * a), 1.6, true)   # V1.3.1：玻璃反光移到中間，翻面不跳邊
	for fy in [-50.0, -7.0]:
		_line(ci, Vector2(-16, fy), Vector2(16, fy), GOLD, 4.0, a)
	# 臉畫在上半部玻璃裡（放頂框上面像多擺一顆頭，也會頂到圓框）
	_c(ci, Vector2(0, -38), 6.5, Color("#fff3d6"), a)
	_eyes(ci, Vector2(0.5, -38.0), a, t, angry)


static func _f_bone(ci: CanvasItem, tc: Color, walk: float, w: float, a: float, t: float, angry: bool, variant: int) -> void:
	# 駝背骷髏＋破斗篷，高舉攤開的魔法書（不拿杖，和醫者分開）；身旁飄一顆小骷髏燈
	var ft: Array = Gait.feet(17, walk)
	var wk := Gait.ph(walk)
	_c(ci, Vector2(-5 + ft[0], -3 - ft[1]), 3.2, Color("#ece6d6"), a)
	_c(ci, Vector2(4 + ft[2], -3 - ft[3]), 3.2, Color("#ece6d6"), a)
	_push_body(ci, _atk_xf(Gait.body_xf(17, walk), w, 0.1, 3.0))
	var hem := sin(wk + 1.0) * 2.5 if wk != 0.0 else 0.0   # 袍擺延遲
	var cape := PackedVector2Array([Vector2(-17 - hem, -4), Vector2(-19 - hem * 0.5, -26), Vector2(-9, -40), Vector2(9, -32), Vector2(13 - hem * 0.6, -7), Vector2(7 - hem * 0.6, -10), Vector2(2 - hem, -4), Vector2(-4 - hem, -10), Vector2(-11 - hem, -4)])
	_poly(ci, cape, tc, a)
	for x0 in [-14.0, -3.0]:
		ci.draw_line(Vector2(x0, -24), Vector2(x0 + 1, -9), Color(tc.darkened(0.25), a), 1.6, true)
	# 兜帽＋骷髏臉，頭往前探
	_poly(ci, PackedVector2Array([Vector2(-9, -50), Vector2(-21, -46), Vector2(-11, -40)]), tc.darkened(0.15), a)   # V1.3.1 剪影：兜帽尖往後翹
	_poly(ci, _ell(Vector2(2, -39), 15.0, 14.0, PI * 0.72, PI * 2.05, 14), tc.darkened(0.15), a)
	_part_at(ci, 6.0)   # V1.3.1：骷髏頭移到中間、不壓扁
	_c(ci, Vector2(6, -35), 10.5, Color("#f5f0e0"), a)
	for ex in [2.0, 10.0]:
		ci.draw_circle(Vector2(ex, -36), 3.2, Color(OUT, a), true, -1.0, true)
		ci.draw_circle(Vector2(ex + 0.4, -36), 1.1, Color("#c77dff", a), true, -1.0, true)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(6, -33), Vector2(4.5, -30), Vector2(7.5, -30)]), Color(OUT, a))
	for k in 4:
		ci.draw_line(Vector2(2.0 + k * 2.6, -28), Vector2(2.0 + k * 2.6, -25), Color(OUT, a), 1.2, true)
	# 高舉的書與紫火：專屬動作舉更高
	_part_end(ci)   # 臉到這裡
	var lift: float = 6.0 + maxf(0.0, -w) * 8.0 + maxf(0.0, w) * 3.0 + (10.0 if variant == 2 else 0.0) + Gait.swing(17, walk) * 12.0
	_part(ci, -5.0, 0.5)   # 書與紫火在近側、留在臉前
	var bk := Vector2(24, -22 - lift)   # V1.3.1 剪影：書與紫火往前探 4px
	_line(ci, Vector2(9, -20), bk + Vector2(-2, 4), Color("#ece6d6"), 2.4, a)
	_poly(ci, PackedVector2Array([bk + Vector2(-10, -2), bk + Vector2(0, 0), bk + Vector2(10, -2), bk + Vector2(10, 4), bk + Vector2(0, 6), bk + Vector2(-10, 4)]), Color("#6b4a2b"), a)
	ci.draw_line(bk + Vector2(0, 0), bk + Vector2(0, 6), Color(OUT, a), 1.2, true)
	# V1.5：前搖時紫火聚成火球（越來越大、越亮），出手那一刻火球離開書（飛行物在 battle_units 畫），書上只剩小火苗再慢慢長回來
	var gather := maxf(0.0, -w)
	var spent := maxf(0.0, w)
	var fl := 8.0 + gather * 9.0 - spent * 4.0 + sin(t * 12.0 + wk * 3.0) * 1.8
	_poly(ci, PackedVector2Array([bk + Vector2(-6, -1), bk + Vector2(6, -1), bk + Vector2(3, -2 - fl), bk + Vector2(0, -6 - fl), bk + Vector2(-3, -2 - fl)]), Color("#b14dff"), a)
	ci.draw_circle(bk + Vector2(0, -4 - fl * 0.3), 2.4 + gather * 2.6, Color(1, 0.85, 1, (0.9 + gather * 0.1) * a), true, -1.0, true)
	if gather > 0.3:
		ci.draw_arc(bk + Vector2(0, -4 - fl * 0.3), 6.0 + gather * 4.0, 0.0, TAU, 18, Color(0.8, 0.5, 1.0, 0.5 * gather * a), 1.6, true)
	_c(ci, bk + Vector2(-3, 5), 2.6, Color("#ece6d6"), a)   # V1.5：骨手托住書底
	_part_end(ci)


static func _f_cat(ci: CanvasItem, tc: Color, walk: float, w: float, a: float, t: float, angry: bool, variant: int) -> void:
	var ft: Array = Gait.feet(18, walk)
	var wk := Gait.ph(walk)
	var leg := sin(wk) * 4.0 if wk != 0.0 else 0.0
	# 腳先畫，上半身（尾巴、吸塵器、頭）跟著起伏
	_c(ci, Vector2(-4 + ft[0], -3 - ft[1]), 3.4, tc.darkened(0.2), a)
	_c(ci, Vector2(5 + ft[2], -3 - ft[3]), 3.4, tc.darkened(0.2), a)
	_push_body(ci, _atk_xf(Gait.body_xf(18, walk), w, 0.14, 5.0))
	# 尾巴、背上的吸塵器桶
	_line(ci, Vector2(-11, -8), Vector2(-20 - leg * 0.4, -18 + leg), tc.darkened(0.1), 3.0, a)
	_part(ci, 4.0, 0.6)   # V1.3.1：背上的集塵桶在遠側
	_poly(ci, PackedVector2Array([Vector2(-20, -32), Vector2(-7, -32), Vector2(-7, -8), Vector2(-20, -8)]), Color("#b7bfcc"), a)
	_poly(ci, PackedVector2Array([Vector2(-20, -24), Vector2(-7, -24), Vector2(-7, -17), Vector2(-20, -17)]), tc, a, false)
	_part_end(ci)
	_poly(ci, _ell(Vector2(0, -14), 11.0, 10.0, 0.0, TAU, 16), tc.lightened(0.15), a)
	# 大頭＋貓耳
	var hy := -33.0
	_part(ci, 0.0, 0.0)   # 頭與耳朵不壓扁
	for s in [-1.0, 1.0]:
		_poly(ci, PackedVector2Array([Vector2(s * 3.5, hy - 11), Vector2(s * 13, hy - 8), Vector2(s * 11, hy - 21)]), tc, a)
	_c(ci, Vector2(0, hy), 12.0, tc.lightened(0.3), a)
	_eyes(ci, Vector2(3.0, hy), a, t, angry)
	for s2 in ([] if back else [-1.0, 1.0]):   # V1.5 背面不畫鬍鬚
		ci.draw_line(Vector2(s2 * 9 + 2, hy + 4), Vector2(s2 * 16 + 2, hy + 3), Color(OUT, 0.7 * a), 1.0, true)
	# 吸管與吸頭
	var aim: float = -0.1 - w * 0.25 - (0.5 if variant == 2 else 0.0) + Gait.swing(18, walk)
	var nz := Vector2(10, -14) + Vector2(cos(aim), sin(aim)) * 13.0
	_part(ci, -4.0, 1.0)   # 吸嘴在近側，轉正時透視縮短
	_line(ci, Vector2(-6, -18), Vector2(8, -13), Color("#55606f"), 2.6, a)
	_line(ci, Vector2(8, -13), nz, Color("#9aa4b4"), 3.0, a)
	_poly(ci, PackedVector2Array([nz + Vector2(0, -3), nz + Vector2(9, -7), nz + Vector2(9, 7), nz + Vector2(0, 3)]), STEEL, a)
	_part_end(ci)


static func _f_golem(ci: CanvasItem, tc: Color, walk: float, w: float, a: float, t: float, angry: bool, variant: int) -> void:
	# 無頸寬扁巨岩，頭嵌在胸口（和盾兵的前排人形分開）；肩甲、胸口石紋都是隊伍色；攻擊雙臂高舉下砸
	var rock := Color("#8d8a80")
	var ft: Array = Gait.feet(19, walk)
	var lf: float = ft[0]
	var rf: float = ft[2]
	_poly(ci, PackedVector2Array([Vector2(-14 + lf, -2 - ft[1]), Vector2(-5 + lf, -2 - ft[1]), Vector2(-5, -14), Vector2(-14, -14)]), rock.darkened(0.2), a)
	_poly(ci, PackedVector2Array([Vector2(5 + rf, -2 - ft[3]), Vector2(14 + rf, -2 - ft[3]), Vector2(14, -14), Vector2(5, -14)]), rock.darkened(0.2), a)
	_push_body(ci, Gait.body_xf(19, walk))
	var lift: float = maxf(0.0, -w) * 24.0 - maxf(0.0, w) * 8.0 + (20.0 if variant == 2 else 0.0) - absf(Gait.swing(19, walk)) * 25.0   # 走路雙臂下沉
	# V1.3 A1b：轉身時遠側手臂往前、近側往後（左右手的位置交錯，才看得出是轉身）
	_part(ci, 6.0, 0.3)   # 遠側（左）手臂，和遠側肩甲同方向（Codex v131-impl2）
	_line(ci, Vector2(-20, -34), Vector2(-23, -22 - lift), rock.darkened(0.15), 7.0, a)
	_c(ci, Vector2(-23, -19 - lift), 8.0, rock.darkened(0.1), a)
	_part_end(ci)
	_poly(ci, PackedVector2Array([Vector2(-21, -10), Vector2(-24, -36), Vector2(-11, -47), Vector2(11, -47), Vector2(24, -36), Vector2(21, -10)]), rock, a)
	# V1.3.1：近側手臂畫在軀幹前面（Codex v131-impl1：原本被軀幹蓋住）
	_part(ci, -6.0, 0.3)   # 近側（右）手臂
	_line(ci, Vector2(20, -34), Vector2(23, -22 - lift), rock.darkened(0.15), 7.0, a)
	_c(ci, Vector2(23, -19 - lift), 8.0, rock.darkened(0.1), a)
	_part_end(ci)
	# 岩石裂紋
	ci.draw_polyline(PackedVector2Array([Vector2(-19, -28), Vector2(-14, -24), Vector2(-17, -18)]), Color(0.2, 0.18, 0.15, 0.7 * a), 1.6, true)
	ci.draw_polyline(PackedVector2Array([Vector2(17, -14), Vector2(13, -18), Vector2(17, -22)]), Color(0.2, 0.18, 0.15, 0.7 * a), 1.6, true)
	# 隊伍色肩甲（面積要大）與胸前帶子
	_part(ci, 6.0, 0.3)   # V1.3.1：遠側肩甲往後（原本兩片一起往內夾住臉）
	_poly(ci, PackedVector2Array([Vector2(-27, -28), Vector2(-26, -46), Vector2(-8, -52), Vector2(-4, -40), Vector2(-13, -28)]), tc, a)
	_part(ci, -6.0, 0.3)  # 近側肩甲往前
	_poly(ci, PackedVector2Array([Vector2(27, -28), Vector2(26, -46), Vector2(8, -52), Vector2(4, -40), Vector2(13, -28)]), tc, a)
	_part_end(ci)
	_poly(ci, PackedVector2Array([Vector2(-20, -18), Vector2(20, -18), Vector2(20, -11), Vector2(-20, -11)]), tc, a, false)
	for sx in [-20.0, 20.0]:
		ci.draw_circle(Vector2(sx * 0.82, -41), 2.2, Color(tc.lightened(0.5), a), true, -1.0, true)
	# 胸口的臉
	if not back:   # V1.5 背面：沒有臉的凹槽，只看到石背
		_poly(ci, PackedVector2Array([Vector2(-10, -38), Vector2(11, -38), Vector2(10, -21), Vector2(-9, -21)]), rock.darkened(0.3), a, false)
	else:
		for k3 in 3:
			ci.draw_line(Vector2(-8, -35 + k3 * 6), Vector2(8, -34 + k3 * 6), Color(rock.darkened(0.35), a), 1.4, true)   # 背上的石縫
	_eyes(ci, Vector2(1.0, -31.0), a, t, angry)


static func _f_skeleton(ci: CanvasItem, tc: Color, walk: float, w: float, a: float, t: float, angry: bool) -> void:
	var bone := Color("#ece6d6")
	var ft: Array = Gait.feet(21, walk)
	var bx: Transform2D = _atk_xf(Gait.body_xf(21, walk), w, 0.08, 4.0)
	_line(ci, Vector2(-4, -10 + bx.origin.y), Vector2(-4 + ft[0], -2 - ft[1]), bone, 2.2, a)
	_line(ci, Vector2(4, -10 + bx.origin.y), Vector2(4 + ft[2], -2 - ft[3]), bone, 2.2, a)
	_push_body(ci, bx)
	_poly(ci, PackedVector2Array([Vector2(-8, -24), Vector2(8, -24), Vector2(7, -11), Vector2(-7, -11)]), tc, a)
	for k in 2:
		ci.draw_line(Vector2(-5, -21 + k * 4.0), Vector2(5, -21 + k * 4.0), Color(bone, a), 1.6, true)
	_part_at(ci, 1.0)   # V1.3.1：頭骨不壓扁
	_c(ci, Vector2(1, -33), 9.5, Color("#f5f0e0"), a)
	for ex in [-2.5, 5.0]:
		ci.draw_circle(Vector2(ex, -33), 2.6, Color(OUT, a), true, -1.0, true)
	ci.draw_line(Vector2(-1, -27), Vector2(5, -27), Color(OUT, a), 1.2, true)
	var ang: float = -1.0 + (w * 0.5 if w < 0.0 else w * 1.4) + Gait.swing(21, walk) * 1.6
	var hand := Vector2(8, -18)
	_part(ci, -4.0, 1.0)   # 骨刀在近側
	var bdir := Vector2(cos(ang), sin(ang))
	_line(ci, hand - bdir * 3.5, hand + bdir * 16.0, bone, 2.6, a)   # V1.5：骨棒尾端露在手後
	_c(ci, hand - bdir * 4.2, 1.8, bone, a)
	_c(ci, hand + bdir * 17.0, 3.0, bone, a)
	_fist(ci, hand, bdir, a, Color("#d8d0bc"), 2.8)   # V1.5：骨手握住（原本骨棒浮在半空，Antigravity v150-i1 #10）
	_part_end(ci)
