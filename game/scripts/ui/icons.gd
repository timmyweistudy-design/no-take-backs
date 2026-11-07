extends RefCounted
## V9 P5 圖示：全部向量自繪，不靠字型（思源黑體沒有這些符號）。一律 24×24 概念，c＝中心、s＝邊長。
const OUT := Color("#1d1a2b")
## V1.2 B4：畫剪影（外框、厚度）時，所有固定色（金幣金、外框紫）都換成同一個顏色；平常是透明＝不換。
static var force := Color(0, 0, 0, 0)

static func _k(c: Color) -> Color:
	return Color(force, force.a * c.a) if force.a > 0.0 else c

static func draw(ci: CanvasItem, name: String, c: Vector2, s: float, col := Color.WHITE) -> void:
	var u := s / 24.0
	var P := func(x: float, y: float) -> Vector2: return c + Vector2(x, y) * u
	var w := maxf(1.6, 2.2 * u)
	match name:
		"coin":
			ci.draw_circle(c, 10.5 * u, _k(OUT), true, -1.0, true)
			ci.draw_circle(c, 9.0 * u, _k(Color("#ffd166")), true, -1.0, true)
			ci.draw_circle(c, 5.5 * u, _k(Color("#f4a300")), true, -1.0, true)
			ci.draw_circle(P.call(-1.5, -1.5), 2.2 * u, _k(Color("#ffe9a8")), true, -1.0, true)
		"people":
			for k in [[-5.5, 0.82], [5.5, 0.82], [0.0, 1.0]]:
				var f: float = k[1]
				ci.draw_circle(P.call(k[0], -4.5), 4.2 * u * f, col, true, -1.0, true)
				ci.draw_colored_polygon(PackedVector2Array([P.call(k[0] - 6.5 * f, 9.0), P.call(k[0] - 4.5 * f, 1.0), P.call(k[0] + 4.5 * f, 1.0), P.call(k[0] + 6.5 * f, 9.0)]), col)
		"clock":
			ci.draw_arc(c, 9.5 * u, 0, TAU, 28, col, w, true)
			ci.draw_line(c, P.call(0, -6), col, w, true)
			ci.draw_line(c, P.call(4.5, 2), col, w, true)
		"map":
			ci.draw_polyline(PackedVector2Array([P.call(-10, -7), P.call(-4, -10), P.call(4, -7), P.call(10, -10), P.call(10, 7), P.call(4, 10), P.call(-4, 7), P.call(-10, 10), P.call(-10, -7)]), col, w, true)
			ci.draw_line(P.call(-4, -10), P.call(-4, 7), col, w * 0.8, true)
			ci.draw_line(P.call(4, -7), P.call(4, 10), col, w * 0.8, true)
		"size":
			ci.draw_rect(Rect2(P.call(-10, -8), Vector2(20, 16) * u), col, false, w)
			ci.draw_polyline(PackedVector2Array([P.call(-3, 3), P.call(4, -4)]), col, w, true)
			ci.draw_colored_polygon(PackedVector2Array([P.call(6, -6), P.call(1, -5), P.call(5, -1)]), col)
		"cards":
			ci.draw_rect(Rect2(P.call(-9, -6), Vector2(11, 15) * u), Color(col, 0.55))
			ci.draw_rect(Rect2(P.call(-3, -9), Vector2(11, 15) * u), col)
			ci.draw_rect(Rect2(P.call(-3, -9), Vector2(11, 15) * u), _k(OUT), false, w * 0.6)
		"robot":
			ci.draw_rect(Rect2(P.call(-8, -6), Vector2(16, 13) * u), col)
			ci.draw_line(P.call(0, -6), P.call(0, -10), col, w, true)
			ci.draw_circle(P.call(0, -10.5), 1.8 * u, col, true, -1.0, true)
			ci.draw_circle(P.call(-3.5, -1), 2.0 * u, _k(OUT), true, -1.0, true)
			ci.draw_circle(P.call(3.5, -1), 2.0 * u, _k(OUT), true, -1.0, true)
			ci.draw_rect(Rect2(P.call(-4, 3.5), Vector2(8, 1.6) * u), _k(OUT))
		"gear":
			for k2 in 8:
				var a := k2 * TAU / 8.0
				ci.draw_line(c + Vector2(cos(a), sin(a)) * 6.5 * u, c + Vector2(cos(a), sin(a)) * 10.5 * u, col, w * 1.3, true)
			ci.draw_arc(c, 6.0 * u, 0, TAU, 20, col, w * 1.3, true)
		"dice":
			ci.draw_rect(Rect2(P.call(-9, -9), Vector2(18, 18) * u), col)
			for d in [[-4.5, -4.5], [4.5, -4.5], [0, 0], [-4.5, 4.5], [4.5, 4.5]]:
				ci.draw_circle(P.call(d[0], d[1]), 1.9 * u, _k(OUT), true, -1.0, true)
		"copy":
			ci.draw_rect(Rect2(P.call(-8, -4), Vector2(12, 13) * u), Color(col, 0.55), false, w)
			ci.draw_rect(Rect2(P.call(-4, -9), Vector2(12, 13) * u), col, false, w)
		"paste":
			ci.draw_rect(Rect2(P.call(-8, -7), Vector2(16, 17) * u), col, false, w)
			ci.draw_rect(Rect2(P.call(-4, -10), Vector2(8, 5) * u), col)
		"save":
			ci.draw_colored_polygon(PackedVector2Array([P.call(-9, -9), P.call(5, -9), P.call(9, -5), P.call(9, 9), P.call(-9, 9)]), col)
			ci.draw_rect(Rect2(P.call(-5, 2), Vector2(10, 7) * u), _k(OUT))
			ci.draw_rect(Rect2(P.call(-4, -9), Vector2(7, 5) * u), _k(OUT))
		"back":
			ci.draw_polyline(PackedVector2Array([P.call(3, -8), P.call(-5, 0), P.call(3, 8)]), col, w * 1.5, true)
		"next":
			ci.draw_polyline(PackedVector2Array([P.call(-3, -8), P.call(5, 0), P.call(-3, 8)]), col, w * 1.5, true)
		"play":
			ci.draw_colored_polygon(PackedVector2Array([P.call(-6, -9), P.call(9, 0), P.call(-6, 9)]), col)
		"pause":
			ci.draw_rect(Rect2(P.call(-7, -8), Vector2(5, 16) * u), col)
			ci.draw_rect(Rect2(P.call(2, -8), Vector2(5, 16) * u), col)
		"swords":
			ci.draw_line(P.call(-9, -9), P.call(8, 8), col, w * 1.3, true)
			ci.draw_line(P.call(9, -9), P.call(-8, 8), col, w * 1.3, true)
			ci.draw_line(P.call(-9, 4), P.call(-3, 10), col, w, true)
			ci.draw_line(P.call(9, 4), P.call(3, 10), col, w, true)
		"sword":
			ci.draw_line(P.call(8, -9), P.call(-5, 6), col, w * 1.5, true)
			ci.draw_line(P.call(-9, 1), P.call(-1, 9), col, w * 1.2, true)
			ci.draw_line(P.call(-5, 6), P.call(-9, 10), col, w * 1.2, true)
		"shield":
			ci.draw_colored_polygon(PackedVector2Array([P.call(-8, -9), P.call(8, -9), P.call(8, 2), P.call(0, 10), P.call(-8, 2)]), col)
		"heart":
			ci.draw_circle(P.call(-4, -3), 4.8 * u, _k(Color("#ff5d73")), true, -1.0, true)
			ci.draw_circle(P.call(4, -3), 4.8 * u, _k(Color("#ff5d73")), true, -1.0, true)
			ci.draw_colored_polygon(PackedVector2Array([P.call(-8.6, -1), P.call(8.6, -1), P.call(0, 10)]), _k(Color("#ff5d73")))
		"speed":
			ci.draw_polyline(PackedVector2Array([P.call(-9, -7), P.call(-2, 0), P.call(-9, 7)]), col, w * 1.3, true)
			ci.draw_polyline(PackedVector2Array([P.call(0, -7), P.call(7, 0), P.call(0, 7)]), col, w * 1.3, true)
		"range":
			ci.draw_arc(c, 9.5 * u, 0, TAU, 24, col, w * 0.8, true)
			ci.draw_arc(c, 5.0 * u, 0, TAU, 18, col, w * 0.8, true)
			ci.draw_circle(c, 1.8 * u, col, true, -1.0, true)
		"cooldown":
			ci.draw_arc(c, 8.5 * u, -PI / 2, PI, 22, col, w, true)
			ci.draw_colored_polygon(PackedVector2Array([P.call(-8.5, 0), P.call(-12, -4), P.call(-4.5, -4)]), col)
		"star":
			var st := PackedVector2Array()
			for i in 10:
				var r: float = (10.5 if i % 2 == 0 else 4.6) * u
				var an := -PI / 2 + i * PI / 5
				st.append(c + Vector2(cos(an), sin(an)) * r)
			ci.draw_colored_polygon(st, _k(Color("#ffd166")) if col == Color.WHITE else col)
		"lock":
			ci.draw_arc(P.call(0, -3), 5.0 * u, PI, TAU, 12, col, w, true)
			ci.draw_rect(Rect2(P.call(-7, -3), Vector2(14, 12) * u), col)
		"trophy":
			ci.draw_colored_polygon(PackedVector2Array([P.call(-6, -9), P.call(6, -9), P.call(4, 2), P.call(-4, 2)]), _k(Color("#ffd166")))
			ci.draw_arc(P.call(-7, -5), 3.2 * u, PI * 0.5, PI * 1.5, 8, _k(Color("#ffd166")), w * 0.8, true)
			ci.draw_arc(P.call(7, -5), 3.2 * u, -PI * 0.5, PI * 0.5, 8, _k(Color("#ffd166")), w * 0.8, true)
			ci.draw_rect(Rect2(P.call(-1.5, 2), Vector2(3, 5) * u), _k(Color("#ffd166")))
			ci.draw_rect(Rect2(P.call(-5.5, 7), Vector2(11, 2.6) * u), _k(Color("#ffd166")))
		"flag":
			ci.draw_line(P.call(-7, -10), P.call(-7, 10), col, w, true)
			ci.draw_colored_polygon(PackedVector2Array([P.call(-6, -10), P.call(9, -5.5), P.call(-6, -1)]), col)
		"skull":
			ci.draw_circle(P.call(0, -2), 8.0 * u, col, true, -1.0, true)
			ci.draw_rect(Rect2(P.call(-4.5, 4), Vector2(9, 5) * u), col)
			ci.draw_circle(P.call(-3, -2), 2.2 * u, _k(OUT), true, -1.0, true)
			ci.draw_circle(P.call(3, -2), 2.2 * u, _k(OUT), true, -1.0, true)
		"sound":
			ci.draw_colored_polygon(PackedVector2Array([P.call(-9, -3), P.call(-4, -3), P.call(2, -8), P.call(2, 8), P.call(-4, 3), P.call(-9, 3)]), col)
			ci.draw_arc(P.call(2, 0), 5.0 * u, -0.8, 0.8, 8, col, w * 0.8, true)
			ci.draw_arc(P.call(2, 0), 8.5 * u, -0.8, 0.8, 10, col, w * 0.8, true)
		"book":
			ci.draw_colored_polygon(PackedVector2Array([P.call(-10, -7), P.call(0, -5), P.call(0, 9), P.call(-10, 7)]), col)
			ci.draw_colored_polygon(PackedVector2Array([P.call(10, -7), P.call(0, -5), P.call(0, 9), P.call(10, 7)]), Color(col, 0.7))
		"puzzle":
			ci.draw_rect(Rect2(P.call(-8, -6), Vector2(16, 15) * u), col)
			ci.draw_circle(P.call(0, -7), 3.4 * u, col, true, -1.0, true)
			ci.draw_circle(P.call(8, 2), 3.2 * u, _k(OUT), true, -1.0, true)
		"tower":
			ci.draw_rect(Rect2(P.call(-6, -6), Vector2(12, 16) * u), col)
			for t in 3:
				ci.draw_rect(Rect2(P.call(-7.5 + t * 6.0, -10), Vector2(3.2, 4.2) * u), col)
			ci.draw_rect(Rect2(P.call(-2, 3), Vector2(4, 7) * u), _k(OUT))
		"road":
			ci.draw_colored_polygon(PackedVector2Array([P.call(-3, -10), P.call(3, -10), P.call(9, 10), P.call(-9, 10)]), col)
			for r2 in 3:
				ci.draw_rect(Rect2(P.call(-0.8, -8 + r2 * 6.5), Vector2(1.6, 3.6) * u), _k(OUT))
		"block":
			ci.draw_circle(c, 9.5 * u, col, true, -1.0, true)
			ci.draw_line(P.call(-6, -6), P.call(6, 6), _k(OUT), w * 1.3, true)
		"slow":
			ci.draw_arc(P.call(-2, 2), 7.0 * u, PI, TAU, 12, col, w * 1.4, true)
			ci.draw_circle(P.call(7, 2), 2.4 * u, col, true, -1.0, true)
			ci.draw_line(P.call(-9, 2), P.call(9, 2), col, w, true)
		"fast":
			ci.draw_colored_polygon(PackedVector2Array([P.call(3, -10), P.call(-6, 2), P.call(0, 2), P.call(-3, 10), P.call(7, -3), P.call(1, -3)]), col)
		"ban":
			ci.draw_arc(c, 9.0 * u, 0, TAU, 24, _k(Color("#ff6b6b")), w * 1.2, true)
			ci.draw_line(P.call(-6.4, -6.4), P.call(6.4, 6.4), _k(Color("#ff6b6b")), w * 1.2, true)
		"hint":
			ci.draw_arc(P.call(0, -2), 7.0 * u, PI * 0.8, PI * 2.2, 16, col, w, true)
			ci.draw_rect(Rect2(P.call(-3, 6), Vector2(6, 2.2) * u), col)
			ci.draw_rect(Rect2(P.call(-2, 9), Vector2(4, 1.6) * u), col)
		"repeat":
			ci.draw_arc(c, 8.0 * u, 0.3, PI + 0.3, 14, col, w * 1.1, true)
			ci.draw_arc(c, 8.0 * u, PI + 0.3, TAU + 0.3, 14, Color(col, 0.6), w * 1.1, true)
		"swap":
			ci.draw_line(P.call(-9, -4), P.call(8, -4), col, w, true)
			ci.draw_colored_polygon(PackedVector2Array([P.call(9, -4), P.call(4, -8), P.call(4, 0)]), col)
			ci.draw_line(P.call(9, 4), P.call(-8, 4), col, w, true)
			ci.draw_colored_polygon(PackedVector2Array([P.call(-9, 4), P.call(-4, 0), P.call(-4, 8)]), col)
		_:
			ci.draw_rect(Rect2(P.call(-8, -8), Vector2(16, 16) * u), col, false, w)

const NAMES := ["coin", "people", "clock", "map", "size", "cards", "robot", "gear", "dice", "copy", "paste", "save", "back", "next", "play", "pause", "swords", "sword", "shield", "heart", "speed", "range", "cooldown", "star", "lock", "trophy", "flag", "skull", "sound", "book", "puzzle", "tower", "road", "block", "slow", "fast", "ban", "hint", "repeat", "swap"]
