extends Node
## V9 地圖美術：每種 地圖＋大小 烘一張地面貼圖（全程式繪製，一張圖只畫一次，不佔每幀繪製）。
## 地形一眼要看懂：擋路＝深色有陰影、慢＝有顆粒的粗地面、快＝亮面加箭紋。樹、岩塊是前景，和角色依 y 排序。
const MD = preload("res://scripts/core/map_defs.gd")
const CS := 64.0

## 每種地貌的色：底、慢、快、擋、擋的高光、框。
const BIOME := {
	"river": {"base": "#6f9a4a", "base2": "#7da655", "slow": "#7a6a44", "fast": "#a9b07a", "block": "#2f7fb5", "edge": "#7cc4e8", "frame": "#5b4632", "sound": "water", "outer": "#22351f"},
	"forest": {"base": "#4e7a3c", "base2": "#578545", "slow": "#6b5233", "fast": "#8f9a5c", "block": "#2f4d29", "edge": "#6f9a4a", "frame": "#3e2f22", "sound": "forest", "outer": "#16261a"},
	"ice": {"base": "#9cadb9", "base2": "#a6b6c0", "slow": "#bccbd5", "shadow": 0.42, "fast": "#7fb6d3", "block": "#4a7796", "edge": "#e4f0f7", "frame": "#4f6475", "sound": "wind", "outer": "#2c3d4c"},
	"lava": {"base": "#3f3640", "base2": "#4a4049", "slow": "#7e7680", "fast": "#6a5d62", "block": "#d94a14", "edge": "#7a3322", "frame": "#2c2428", "sound": "lava", "outer": "#19131a"},
	"canyon": {"base": "#d9b37a", "base2": "#e2bf88", "slow": "#c79a5e", "fast": "#a89a86", "block": "#6d3a26", "edge": "#c47a4e", "frame": "#6e4a2c", "sound": "wind", "outer": "#3f2c1e"},
}

var _tex := {}       # 鍵 → Texture2D
var _busy := {}

static func key_of(map_id: int, size: int) -> int:
	return map_id * 10 + size

func texture(map_id: int, size: int) -> Texture2D:
	var k := key_of(map_id, size) * 2 + (1 if _plain() else 0)   # 簡化介面另存一張（不烘紙紋、不調色）
	if _tex.has(k):
		return _tex[k]
	if not _busy.has(k):
		_busy[k] = true
		_bake.call_deferred(map_id, size, _plain())   # 鍵與設定在排程當下固定（Codex v121：延後才讀會留下卡住的 busy）
	return null

func _bake(map_id: int, size: int, plain := false) -> void:
	var k := key_of(map_id, size) * 2 + (1 if plain else 0)
	var t = MD.terrain(map_id, size)
	if t == null:
		_busy.erase(k)   # 失敗也清掉，下次可以重試
		return
	var vp := SubViewport.new()
	vp.size = Vector2i(int(t.w / 1000.0 * CS), int(t.h / 1000.0 * CS))
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.disable_3d = true
	var p := _Painter.new()
	p.biome = BIOME[MD.MAPS[map_id]["biome"]]
	p.kind = MD.MAPS[map_id]["biome"]
	p.t = t
	p.plain = plain
	vp.add_child(p)
	add_child(vp)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	if not plain:
		img = await _grade(img)
	_busy.erase(k)
	if img == null or img.is_empty():
		return
	_tex[k] = ImageTexture.create_from_image(img)

static func _plain() -> bool:
	return bool(preload("res://scripts/game/save.gd").s("plain_ui"))

## V1.2 F2：地塊調色在烘焙時跑一次 shader（shaders/grade_bake.gdshader）；沒有檔就原樣。
func _grade(img: Image) -> Image:
	var sh := "res://shaders/grade_bake.gdshader"
	if not ResourceLoader.exists(sh):
		return img
	var tr := TextureRect.new()
	tr.texture = ImageTexture.create_from_image(img)
	var m := ShaderMaterial.new()
	m.shader = load(sh)
	tr.material = m
	var vp := SubViewport.new()
	vp.size = img.get_size()
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.disable_3d = true
	vp.add_child(tr)
	add_child(vp)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var out := vp.get_texture().get_image()
	vp.queue_free()
	return out

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
			# V1.3 B1：不再是三個正三角形。每層是下垂的枝條（尖端往下勾、底緣波浪、頂點略歪），雪蓋也不對稱
			var hj := int(absf(p.x * 7.3 + p.y * 3.1)) % 97
			for k in 3:
				var ky: float = -8.0 - k * 11.0
				var kw: float = 16.0 - k * 4.0 + float((hj >> k) % 3) - 1.0
				var ax: float = (1.2 if (hj + k) % 2 == 0 else -1.2)
				ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-kw, ky + 1.5) * s, p + Vector2(-kw * 0.55, ky - 4.0) * s, p + Vector2(-kw * 0.68, ky - 5.5) * s,
					p + Vector2(ax, ky - 17.0) * s, p + Vector2(kw * 0.66, ky - 5.0) * s, p + Vector2(kw * 0.52, ky - 3.5) * s, p + Vector2(kw, ky + 1.0) * s,
					p + Vector2(kw * 0.45, ky - 1.2) * s, p + Vector2(0, ky + 0.6) * s, p + Vector2(-kw * 0.48, ky - 1.0) * s]), Color("#2f5a55"))
				ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-kw * 0.5, ky - 8.0) * s, p + Vector2(ax, ky - 17.0) * s, p + Vector2(kw * 0.42, ky - 9.5) * s,
					p + Vector2(kw * 0.15, ky - 8.2) * s, p + Vector2(-kw * 0.1, ky - 9.6) * s]), Color("#e4f0f7"))
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
	var plain := false
	var biome: Dictionary
	var kind := ""
	var t
	func _h(c: int, r: int) -> int:
		return absi((c * 73856093) ^ (r * 19349663)) % 100000
	func _cell(c: int, r: int) -> int:
		if c < 0 or c >= t.n or r < 0 or r >= t.m:
			return -1
		return t.grid[c + r * t.n]
	## 沿一格的邊往外畫一條鋸齒帶；m＝邊的中點。
	func _jag(m: Vector2, out_dir: Vector2, col: Color, h: int, depth: float) -> void:
		var side := Vector2(out_dir.y, out_dir.x)
		var half := 16.5
		var pts := PackedVector2Array([m - side * half, m + side * half])
		for k in 5:
			var f: float = 1.0 - k * 0.5
			var bump: float = depth * (0.45 + float((h >> (k * 2)) % 4) * 0.2)
			pts.append(m + side * (f * half) + out_dir * bump)
		draw_colored_polygon(pts, col)

	## V1.3 B1：牆邊不再是尺規直線。先往外長一圈不規則的牆色小鼓包（只會讓牆看起來厚一點，不多出可走缺口），
	## 再沿著它畫一條粗細、位置都有微小起伏的描邊。全部烘進地塊，跑起來沒有成本。
	func _wob_edge(a0: Vector2, a1: Vector2, out_dir: Vector2, h: int) -> void:
		var m := (a0 + a1) / 2.0
		_jag(m, out_dir, Color(biome["block"]), h, 3.2)
		var pts := PackedVector2Array()
		for k in 7:
			var f := k / 6.0
			var off := (float((h >> (k * 2)) % 5) - 1.0) * 0.55 + 0.6
			if k == 0 or k == 6:
				off = 0.4
			pts.append(a0.lerp(a1, f) + out_dir * off)
		draw_polyline(pts, Color(biome["edge"]), 2.2 + float(h % 3) * 0.3, true)

	## 第十輪 V5、V6：牆邊往外（可走的那一側）長碎石或碎冰，牆只會看起來更厚，不會多出可走的缺口。
	func _rim(m: Vector2, out_dir: Vector2, h: int) -> void:
		if kind != "lava" and kind != "ice" and kind != "canyon":
			return
		var side := Vector2(out_dir.y, out_dir.x)
		if kind == "lava":
			_jag(m, out_dir, Color("#2d1a18"), h, 6.0)
			_jag(m, out_dir, Color("#55352c"), h >> 3, 2.5)
			return
		for k in 3:
			var hh := (h >> (k * 3)) % 64
			var pos: Vector2 = m + side * ((k - 1) * 10.0 + hh % 5) + out_dir * (hh % 3)
			var r := 2.5 + hh % 4
			match kind:
				"lava":
					pass      # 石岸在 _rim 開頭畫成連續折線
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
						draw_circle(o + d, 1.6, Color(1, 1, 1, 0.45) if kind == "ice" else Color(Color(biome["slow"]).darkened(0.25), 0.8), true, -1.0, true)   # 冰原：霜點，不是灰點（Antigravity impl4）
				elif v == t.FAST:
					draw_rect(Rect2(o, Vector2(Q, Q)), Color(biome["fast"]))
					if kind == "canyon":
						draw_rect(Rect2(o + Vector2(1, 1), Vector2(Q - 2, Q - 2)), Color(1, 1, 1, 0.08))
						draw_rect(Rect2(o, Vector2(Q, Q)), Color(0, 0, 0, 0.07), false, 1.0)   # 第十輪：線淡一點，石道才不像城牆
					elif h2 % 3 != 0:
						# V1.3 B1：亮紋長短、角度、位置都錯開，三格留一格空白，不再是規則排列的短斜線
						var y1 := float(h2 % 20) + 4.0
						var x1 := 2.0 + float((h2 >> 4) % 8)
						var ln := 9.0 + float((h2 >> 6) % 12)
						draw_line(o + Vector2(x1, y1), o + Vector2(x1 + ln, y1 + 2.0 + float((h2 >> 9) % 5)), Color(1, 1, 1, 0.32 + float((h2 >> 2) % 3) * 0.06), 1.3 + float(h2 % 2) * 0.5, true)
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
						_jag(e, Vector2(d2[0], d2[1]), col, _h(c2 * 3 + d2[0], r2 * 3 + d2[1]), 5.0)   # 第十輪：不規則折線，不外溢超過 6 px
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
						# 1.2.0 §5 B4 藍染絹：底色加深一階（靛），細織紋（經緯各 4 條、低透明）＋一道斜向絹光；仍是整格實色，判讀不變
						draw_rect(Rect2(o3, Vector2(Q, Q)), Color(0.11, 0.2, 0.36, 0.28))
						for kw in 4:
							var wy := (kw + 0.5) * Q / 4.0 + float((h3 >> kw) % 3) - 1.0
							draw_line(o3 + Vector2(0, wy), o3 + Vector2(Q, wy), Color(0.85, 0.92, 1.0, 0.09), 1.0)
							var wx := (kw + 0.5) * Q / 4.0
							draw_line(o3 + Vector2(wx, 0), o3 + Vector2(wx, Q), Color(0.05, 0.1, 0.22, 0.12), 1.0)
						if h3 % 3 == 0:
							draw_line(o3 + Vector2(2, Q * 0.75), o3 + Vector2(Q * 0.7, 3), Color(1, 1, 1, 0.16), 2.0, true)
						draw_arc(o3 + Vector2(Q / 2, (h3 % 20) + 6), 9.0, 0.3, 2.6, 8, Color(1, 1, 1, 0.22), 1.4, true)
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
						_wob_edge(o4 + d4[2], o4 + d4[3], Vector2(d4[0], d4[1]), _h(c4 * 5 + d4[0], r4 * 5 + d4[1]))
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
						# 1.2.0 §5 B4 小木片橋：三片直鋪木片（深淺交錯、片縫、上緣受光、兩端釘點），下方投影（光源左上）
						draw_rect(Rect2(o5 + Vector2(3, 3), Vector2(Q, Q)), Color(0.08, 0.05, 0.03, 0.3))
						var pw := Q / 3.0
						for k5 in 3:
							var hh := _h(c5 * 7 + k5, r5)
							var pc := Color("#9a6e40").darkened(float(hh % 4) * 0.05)
							var pr := Rect2(o5 + Vector2(k5 * pw + 0.5, -1.0 + float(hh % 3) * 0.5), Vector2(pw - 1.5, Q + 1.0))
							draw_rect(pr, pc)
							draw_line(pr.position, pr.position + Vector2(0, pr.size.y), Color(1, 0.92, 0.75, 0.35), 1.0)   # 左緣受光
							draw_line(pr.position + Vector2(pr.size.x, 0), pr.end, Color("#4a3018"), 1.5)   # 片縫
							draw_line(pr.position + Vector2(pw * 0.45, 4 + hh % 5), pr.position + Vector2(pw * 0.5, Q - 6 - hh % 4), Color(0.3, 0.18, 0.08, 0.25), 1.0)   # 木紋
							for ny in [4.0, Q - 4.0]:
								draw_circle(pr.position + Vector2(pw * 0.5 - 0.5, ny), 1.3, Color("#3a2a1c"))
		_decor(Q)

	## V1.2 D3：手繪筆觸（草簇、碎石、冰紋、裂紋）、場地邊緣裝飾（木柵欄、冰柱、焦岩）、紙紋 5%，全部烘進地塊。
	## 邊緣裝飾只在最外 7px 內，不擋到站在邊上的兵；只畫在可走的格子上，不改變地形判讀。
	func _decor(Q: float) -> void:
		var W: float = t.n * Q
		var H: float = t.m * Q
		var dark := Color(biome["base"]).darkened(0.32)
		var lite := Color(biome["base2"]).lightened(0.18)
		for i in 140:
			var h := _h(i * 31 + 7, i * 17 + 3)
			var p := Vector2(float(h % 1000) / 1000.0 * W, float((h / 1000) % 100) / 100.0 * H)
			if _cell(int(p.x / Q), int(p.y / Q)) != t.FREE:
				continue
			match kind:
				"river", "forest":   # 草簇：三筆往上撇
					for s in [-1.0, 0.0, 1.0]:
						draw_line(p, p + Vector2(s * 3.5, -6.0 - absf(s) * -1.5), Color(dark, 0.55), 1.4, true)
					draw_line(p + Vector2(-1, -1), p + Vector2(-2, -5), Color(lite, 0.45), 1.0, true)
				"ice":                # 冰面細紋
					var a := float(h % 628) / 100.0
					draw_line(p, p + Vector2.from_angle(a) * (5.0 + h % 5), Color(1, 1, 1, 0.16), 1.0, true)   # 淡而短，不要像除錯線
				"lava":               # 焦土裂紋
					var a2 := float(h % 628) / 100.0
					var q := p + Vector2.from_angle(a2) * 7.0
					draw_polyline(PackedVector2Array([p, q, q + Vector2.from_angle(a2 + 0.8) * 5.0]), Color(0.1, 0.06, 0.07, 0.45), 1.3, true)
				"canyon":             # 碎石
					draw_circle(p, 1.6 + h % 3, Color(0.45, 0.3, 0.2, 0.45), true, -1.0, true)
					draw_circle(p + Vector2(-0.6, -0.6), 0.8, Color(1, 0.92, 0.8, 0.35), true, -1.0, true)
		# 邊緣裝飾（上下兩條邊）
		var x := 6.0
		while x < W - 6.0:
			var hx := _h(int(x), 77)
			for edge in [0, 1]:
				var y0 := 0.0 if edge == 0 else H
				var dirv := 1.0 if edge == 0 else -1.0
				if _cell(int(x / Q), 0 if edge == 0 else t.m - 1) != t.FREE:
					continue
				match kind:
					"river", "forest":
						if int(x) % 48 < 16:   # 木柵欄：短木樁＋橫木
							draw_rect(Rect2(x - 1.5, y0 + (0.0 if edge == 0 else -7.0), 3.0, 7.0), Color("#6b4a2c"))
							draw_rect(Rect2(x - 1.5, y0 + (0.0 if edge == 0 else -7.0), 3.0, 1.5), Color("#a07a4e"))
					"ice":       # 冰柱（上緣往下）、雪堆（下緣）
						if edge == 0:
							var L := 3.0 + hx % 5
							draw_colored_polygon(PackedVector2Array([Vector2(x - 2.2, 0), Vector2(x + 2.2, 0), Vector2(x, L)]), Color(0.92, 0.97, 1.0, 0.85))
						else:
							draw_circle(Vector2(x, H), 4.0 + hx % 3, Color(0.95, 0.98, 1.0, 0.7), true, -1.0, true)
					"lava":      # 焦岩
						if hx % 3 == 0:
							draw_colored_polygon(PackedVector2Array([Vector2(x - 4, y0), Vector2(x - 1, y0 + dirv * (4.0 + hx % 3)), Vector2(x + 3, y0 + dirv * 2.0), Vector2(x + 5, y0)]), Color("#241a1d"))
					"canyon":
						if hx % 2 == 0:
							draw_circle(Vector2(x, y0 + dirv * 2.0), 2.5 + hx % 2, Color("#9a6a44"), true, -1.0, true)
			x += 8.0 if kind != "river" and kind != "forest" else 4.0
		# 紙紋 5%（烘進去，跑起來不用每幀再疊一次）
		var gr: Texture2D = load("res://art/ui/paper.png") if ResourceLoader.exists("res://art/ui/paper.png") and not plain else null
		if gr != null:
			texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			draw_texture_rect(gr, Rect2(0, 0, W, H), true, Color(0.5, 0.42, 0.32, 0.055))
