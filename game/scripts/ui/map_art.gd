extends Node
## V9 地圖美術：每種 地圖＋大小 烘一張地面貼圖（全程式繪製，一張圖只畫一次，不佔每幀繪製）。
## 地形一眼要看懂：擋路＝深色有陰影、慢＝有顆粒的粗地面、快＝亮面加箭紋。樹、岩塊是前景，和角色依 y 排序。
const MD = preload("res://scripts/core/map_defs.gd")
const CS := 64.0

## 每種地貌的色：底、慢、快、擋、擋的高光、框。
const BIOME := {
	"river": {"base": "#6f9a4a", "base2": "#7da655", "slow": "#7a6a44", "fast": "#a9b07a", "block": "#2f7fb5", "edge": "#7cc4e8", "frame": "#5b4632", "sound": "water", "outer": "#22351f"},
	"forest": {"base": "#4e7a3c", "base2": "#578545", "slow": "#6b5233", "fast": "#8f9a5c", "block": "#2f4d29", "edge": "#6f9a4a", "frame": "#3e2f22", "sound": "forest", "outer": "#16261a"},
	"ice": {"base": "#b7ccda", "base2": "#c3d6e2", "slow": "#d3e1ea", "fast": "#7fb6d3", "block": "#4a7796", "edge": "#e4f0f7", "frame": "#4f6475", "sound": "wind", "outer": "#2c3d4c"},
	"lava": {"base": "#3f3640", "base2": "#4a4049", "slow": "#7e7680", "fast": "#6a5d62", "block": "#d94a14", "edge": "#7a3322", "frame": "#2c2428", "sound": "lava", "outer": "#19131a"},
	"canyon": {"base": "#d9b37a", "base2": "#e2bf88", "slow": "#c79a5e", "fast": "#a89a86", "block": "#6d3a26", "edge": "#c47a4e", "frame": "#6e4a2c", "sound": "wind", "outer": "#3f2c1e"},
}

var _tex := {}       # 鍵 → Texture2D
var _busy := {}

static func key_of(map_id: int, size: int) -> int:
	return map_id * 10 + size

func texture(map_id: int, size: int) -> Texture2D:
	var k := key_of(map_id, size)
	if _tex.has(k):
		return _tex[k]
	if not _busy.has(k):
		_busy[k] = true
		_bake.call_deferred(map_id, size)
	return null

func _bake(map_id: int, size: int) -> void:
	var t = MD.terrain(map_id, size)
	if t == null:
		return
	var vp := SubViewport.new()
	vp.size = Vector2i(int(t.w / 1000.0 * CS), int(t.h / 1000.0 * CS))
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.disable_3d = true
	var p := _Painter.new()
	p.biome = BIOME[MD.MAPS[map_id]["biome"]]
	p.kind = MD.MAPS[map_id]["biome"]
	p.t = t
	vp.add_child(p)
	add_child(vp)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_tex[key_of(map_id, size)] = ImageTexture.create_from_image(vp.get_texture().get_image())
	vp.queue_free()

## 前景物件（世界 px，相對場地左上）：[y, 種類, x, 大小]，依 y 排好。
static func props(map_id: int, size: int) -> Array:
	var t = MD.terrain(map_id, size)
	if t == null:
		return []
	var biome: String = MD.MAPS[map_id]["biome"]
	if biome == "river" or biome == "canyon":
		return []    # 河與崖是平的，不用前景
	var out: Array = []
	var Q := 0.5 * CS
	for r in t.m:
		for c in t.n:
			if t.grid[c + r * t.n] != t.BLOCK:
				continue
			var h := absi((c * 73856093) ^ (r * 19349663)) % 1000
			if biome == "forest" or (c + r) % 2 == 0:
				var x: float = (c + 0.5) * Q + (h % 9 - 4)
				var y: float = (r + 0.85) * Q + (h / 10 % 7 - 3)
				out.append([y, biome, x, 0.85 + (h % 30) / 100.0])
	out.sort_custom(func(a, b): return a[0] < b[0])
	return out

## 第十輪 V4：場外裝飾，只放左右兩條空白；不碰場地，不會被誤認成障礙。
static func draw_outfield(ci: CanvasItem, field: Rect2, biome: String) -> void:
	var bi: Dictionary = BIOME.get(biome, {})
	ci.draw_rect(Rect2(-300, -300, 1900, 1400), Color(bi.get("outer", "#1b2a1f")))
	var kinds: Array = {"river": ["bush", "bush", "rock"], "forest": ["forest", "forest", "bush"], "ice": ["pine", "pine", "ice"], "lava": ["lava", "lava", "rock"], "canyon": ["deadtree", "rock", "rock"]}.get(biome, [])
	if kinds.is_empty():
		return
	for i in 18:
		var h := absi((i * 73856093) ^ ((i + 11) * 19349663)) % 100000
		var left := i % 2 == 0
		var span := field.position.x - 40.0
		var x: float = 16.0 + h % int(span) if left else field.end.x + 24.0 + h % int(span)
		var y: float = field.position.y + 10.0 + i * (field.size.y + 60.0) / 18.0 + h % 16
		draw_prop(ci, Vector2.ZERO, [y, kinds[h % 3], x, 1.0 + (h % 50) / 100.0], 0.0)

## 畫一個前景物件。ci 已經是場地座標（鏡頭已套用）。
static func draw_prop(ci: CanvasItem, origin: Vector2, pr: Array, time: float) -> void:
	var p := origin + Vector2(pr[2], pr[0])
	var s: float = pr[3]
	match pr[1]:
		"forest":
			ci.draw_circle(p + Vector2(0, 2), 13.0 * s, Color(0, 0, 0, 0.25), true, -1.0, true)
			ci.draw_rect(Rect2(p + Vector2(-3, -12) * s, Vector2(6, 13) * s), Color("#5a3f28"))
			ci.draw_circle(p + Vector2(0, -24) * s, 17.0 * s, Color("#1d3a22"), true, -1.0, true)
			ci.draw_circle(p + Vector2(0, -24) * s, 15.0 * s, Color("#2f6b37"), true, -1.0, true)
			ci.draw_circle(p + Vector2(-5, -29) * s, 8.0 * s, Color("#4c9150"), true, -1.0, true)
		"bush":
			ci.draw_circle(p + Vector2(0, -6) * s, 13.0 * s, Color("#1f3a1c"), true, -1.0, true)
			ci.draw_circle(p + Vector2(-5, -9) * s, 9.0 * s, Color("#3f6f33"), true, -1.0, true)
			ci.draw_circle(p + Vector2(6, -7) * s, 7.0 * s, Color("#4f8240"), true, -1.0, true)
		"rock":
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-13, 0) * s, p + Vector2(-8, -11) * s, p + Vector2(4, -15) * s, p + Vector2(13, -5) * s, p + Vector2(12, 0) * s]), Color(0.28, 0.26, 0.28))
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-8, -11) * s, p + Vector2(4, -15) * s, p + Vector2(1, -6) * s]), Color(0.42, 0.4, 0.42))
		"pine":
			ci.draw_rect(Rect2(p + Vector2(-3, -8) * s, Vector2(6, 9) * s), Color("#4a3a2c"))
			for k in 3:
				var ky: float = -8.0 - k * 11.0
				var kw: float = 16.0 - k * 4.0
				ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-kw, ky) * s, p + Vector2(0, ky - 17.0) * s, p + Vector2(kw, ky) * s]), Color("#2f5a55"))
				ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-kw * 0.45, ky - 9.0) * s, p + Vector2(0, ky - 17.0) * s, p + Vector2(kw * 0.45, ky - 9.0) * s]), Color("#e4f0f7"))
		"deadtree":
			ci.draw_line(p, p + Vector2(1, -28) * s, Color("#3a2a1c"), 5.0 * s, true)
			ci.draw_line(p + Vector2(1, -16) * s, p + Vector2(-11, -28) * s, Color("#3a2a1c"), 3.0 * s, true)
			ci.draw_line(p + Vector2(1, -22) * s, p + Vector2(11, -36) * s, Color("#3a2a1c"), 3.0 * s, true)
		"ice":
			ci.draw_circle(p + Vector2(0, 2), 11.0 * s, Color(0, 0.1, 0.3, 0.2), true, -1.0, true)
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-11, 0) * s, p + Vector2(-5, -20) * s, p + Vector2(2, -26) * s, p + Vector2(10, -12) * s, p + Vector2(11, 0) * s]), Color("#a9d8ee"))
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-5, -20) * s, p + Vector2(2, -26) * s, p + Vector2(1, -8) * s]), Color("#e8f7ff"))
		"lava":
			ci.draw_circle(p + Vector2(0, 2), 12.0 * s, Color(0, 0, 0, 0.3), true, -1.0, true)
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-12, 0) * s, p + Vector2(-7, -14) * s, p + Vector2(1, -22) * s, p + Vector2(9, -11) * s, p + Vector2(12, 0) * s]), Color("#2f282d"))
			var g := 0.65 + 0.35 * sin(time * 2.0 + p.x)
			ci.draw_line(p + Vector2(-3, -2) * s, p + Vector2(1, -14) * s, Color(1.0, 0.55, 0.15, g), 2.0, true)

class _Painter extends Node2D:
	var biome: Dictionary
	var kind := ""
	var t
	func _h(c: int, r: int) -> int:
		return absi((c * 73856093) ^ (r * 19349663)) % 100000
	func _cell(c: int, r: int) -> int:
		if c < 0 or c >= t.n or r < 0 or r >= t.m:
			return -1
		return t.grid[c + r * t.n]
	## 第十輪 V5、V6：牆邊往外（可走的那一側）長碎石或碎冰，牆只會看起來更厚，不會多出可走的缺口。
	func _rim(m: Vector2, out_dir: Vector2, h: int) -> void:
		if kind != "lava" and kind != "ice" and kind != "canyon":
			return
		var side := Vector2(out_dir.y, out_dir.x)
		for k in 3:
			var hh := (h >> (k * 3)) % 64
			var pos: Vector2 = m + side * ((k - 1) * 10.0 + hh % 5) + out_dir * (hh % 3)
			var r := 2.5 + hh % 4
			match kind:
				"lava":
					draw_circle(pos, r + 1.0, Color("#2d1a18"), true, -1.0, true)
					draw_circle(pos - Vector2(0.5, 0.8), r * 0.6, Color("#55352c"), true, -1.0, true)
				"ice":
					draw_colored_polygon(PackedVector2Array([pos + side * r * 1.4, pos + out_dir * r * 1.2, pos - side * r * 1.4, pos - out_dir * r * 0.5]), Color("#e4f0f7"))
				"canyon":
					draw_circle(pos, r, Color("#8d5a3a"), true, -1.0, true)

	func _draw() -> void:
		var Q := 32.0
		var base := Color(biome["base"])
		var base2 := Color(biome["base2"])
		draw_rect(Rect2(Vector2.ZERO, Vector2(t.n, t.m) * Q), base)
		# 底：大色塊，避免太平
		for i in 40:
			var h := _h(i * 7 + 3, i * 13 + 5)
			var p := Vector2(h % int(t.n * Q), (h / 7) % int(t.m * Q))
			draw_circle(p, 26.0 + h % 40, Color(base2, 0.5), true, -1.0, true)
		# 慢、快
		for r in t.m:
			for c in t.n:
				var v := _cell(c, r)
				var o := Vector2(c, r) * Q
				var h2 := _h(c, r)
				if v == t.SLOW:
					draw_rect(Rect2(o, Vector2(Q, Q)), Color(biome["slow"]))
					for k in 6:
						var d := Vector2((h2 >> k) % 30 + 1, (h2 >> (k + 3)) % 30 + 1)
						draw_circle(o + d, 1.6, Color(Color(biome["slow"]).darkened(0.25), 0.8), true, -1.0, true)
				elif v == t.FAST:
					draw_rect(Rect2(o, Vector2(Q, Q)), Color(biome["fast"]))
					if kind == "canyon":
						draw_rect(Rect2(o + Vector2(1, 1), Vector2(Q - 2, Q - 2)), Color(1, 1, 1, 0.08))
						draw_rect(Rect2(o, Vector2(Q, Q)), Color(0, 0, 0, 0.14), false, 1.5)
					else:
						draw_line(o + Vector2(4, (h2 % 20) + 4), o + Vector2(Q - 6, (h2 % 20) + 9), Color(1, 1, 1, 0.45), 1.6, true)
		# 慢、快的邊界柔化
		for r2 in t.m:
			for c2 in t.n:
				var v2 := _cell(c2, r2)
				if v2 == t.FREE or v2 == t.BLOCK:
					continue
				var col := Color(biome["slow"] if v2 == t.SLOW else biome["fast"])
				for d2 in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
					if _cell(c2 + d2[0], r2 + d2[1]) == t.FREE:
						var e := (Vector2(c2, r2) + Vector2(0.5, 0.5) + Vector2(d2[0], d2[1]) * 0.5) * Q
						draw_circle(e, 11.0, col, true, -1.0, true)
		# 擋路
		for r3 in t.m:
			for c3 in t.n:
				if _cell(c3, r3) != t.BLOCK:
					continue
				var o3 := Vector2(c3, r3) * Q
				var h3 := _h(c3, r3)
				draw_rect(Rect2(o3, Vector2(Q, Q)), Color(biome["block"]))
				match kind:
					"river":
						draw_arc(o3 + Vector2(Q / 2, (h3 % 20) + 6), 9.0, 0.3, 2.6, 8, Color(1, 1, 1, 0.3), 1.6, true)
					"lava":
						draw_rect(Rect2(o3, Vector2(Q, Q)), Color(1, 0.6, 0.1, 0.25 + (h3 % 30) / 100.0))
						# 硬殼與裂縫：暗塊之間透出亮岩漿
						for kl in 2:
							draw_circle(o3 + Vector2((h3 >> kl) % 30, (h3 >> (kl + 2)) % 30), 7.0 + kl * 2.0, Color("#3a2320"), true, -1.0, true)
						if h3 % 3 == 0:   # 第十輪 V6：裂縫不要每格一條，才不會像條紋
							draw_line(o3 + Vector2(h3 % 12, 4 + h3 % 8), o3 + Vector2(6 + h3 % 22, 18 + h3 % 12), Color("#ffb347"), 1.8, true)
					"canyon":
						# 山崖：上面亮、岩層橫紋不對齊，不要像磚牆
						draw_rect(Rect2(o3, Vector2(Q, Q)), Color("#6d3a26"))
						draw_rect(Rect2(o3, Vector2(Q, Q * 0.42)), Color(Color(biome["edge"]), 0.9))
						draw_circle(o3 + Vector2(h3 % 28 + 2, 6 + h3 % 6), 4.5, Color(1, 0.9, 0.75, 0.25), true, -1.0, true)
						draw_line(o3 + Vector2(0, 16 + h3 % 7), o3 + Vector2(Q, 14 + (h3 >> 3) % 9), Color(0, 0, 0, 0.22), 2.0, true)
						draw_line(o3 + Vector2(0, 25 + h3 % 5), o3 + Vector2(Q, 26 + (h3 >> 4) % 5), Color(0, 0, 0, 0.16), 1.5, true)
					"ice":
						draw_line(o3 + Vector2(2, h3 % 28), o3 + Vector2(Q - 3, (h3 / 5) % 28), Color(1, 1, 1, 0.55), 1.6, true)
		# 牆邊的陰影與描邊：看得出不能走
		for r4 in t.m:
			for c4 in t.n:
				if _cell(c4, r4) != t.BLOCK:
					continue
				var o4 := Vector2(c4, r4) * Q
				if _cell(c4, r4 + 1) != t.BLOCK and r4 + 1 < t.m:
					draw_rect(Rect2(o4 + Vector2(0, Q), Vector2(Q, 12 if kind == "canyon" else 7)), Color(0, 0, 0, 0.32))
				for d4 in [[1, 0, Vector2(Q, 0), Vector2(Q, Q)], [-1, 0, Vector2.ZERO, Vector2(0, Q)], [0, -1, Vector2.ZERO, Vector2(Q, 0)], [0, 1, Vector2(0, Q), Vector2(Q, Q)]]:
					var nb := _cell(c4 + d4[0], r4 + d4[1])
					if nb != t.BLOCK and nb != -1:
						draw_line(o4 + d4[2], o4 + d4[3], Color(biome["edge"]), 2.5, true)
						_rim(o4 + (d4[2] + d4[3]) / 2.0, Vector2(d4[0], d4[1]), _h(c4, r4))
		# 橋：河裡的空格鋪木板
		if kind == "river":
			for r5 in t.m:
				for c5 in t.n:
					if _cell(c5, r5) != t.FREE:
						continue
					var left := false
					var right := false
					for dx in range(1, 5):
						left = left or _cell(c5 - dx, r5 - 0) == t.BLOCK
						right = right or _cell(c5 + dx, r5) == t.BLOCK
					var above := false
					for dy in range(1, 8):
						above = above or _cell(c5, r5 - dy) == t.BLOCK or _cell(c5, r5 + dy) == t.BLOCK
					if above and not left and not right:
						var o5 := Vector2(c5, r5) * Q
						draw_rect(Rect2(o5, Vector2(Q, Q)), Color("#8a6238"))
						for k5 in 3:
							draw_line(o5 + Vector2(k5 * 11.0, 0), o5 + Vector2(k5 * 11.0, Q), Color("#5b3f23"), 2.0, true)
