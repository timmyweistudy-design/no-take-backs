extends Node
## 角色精靈圖快取（第二輪方案 R2、H；第八輪改分頁）：實測 48 隻時每幀直接程式繪製要 34ms（約 15fps），
## 所以用同一份 Art.unit 畫法，把兵種×隊伍×動作影格畫進圖集，戰鬥中只貼圖。
## 第八輪：一張大圖放 22 種會到 3072×11712，Compatibility 渲染器超過 4096 有風險。改成每頁 ≤4096（7 種兵），
## 開場只烘舊 10 種，新兵上場才烘；還沒烘好時呼叫端直接畫，不會缺圖。頁數有上限，超過丟最舊的新兵頁。
## 用同一份畫法烘焙，但不是逐像素等價（Codex R1 審查 #3、#4，已知且接受的差異）：
##  - 走路量化成 6 格、攻擊 8 格；攻擊中不再疊走路相位；走路／攻擊格固定睜眼（只在待機眨眼）。
## 表情疊加（受擊、暈眩、衝鋒、狂熱、潛行、頂住）不烘焙，貼完圖再用 Art.overlay 在同一個局部座標畫上去。
##  - 透明度（潛行）是對整張合成好的角色乘 alpha，重疊的部位不會像逐圖元那樣透出底下的線條。
## 待機呼吸位移在貼圖時加（烘焙時抵銷為 0）；受擊閃白跟著攻擊前衝與走路起伏。
## 沒有畫面（headless）或還沒建好時，呼叫端退回 Art.unit。

const Art = preload("res://scripts/ui/art.gd")
const D = preload("res://scripts/core/unit_defs.gd")
const Gait = preload("res://scripts/ui/units/gait.gd")
const Save = preload("res://scripts/game/save.gd")

const CELL := 192          # 每格像素（以 RS 倍率畫）；比角色大一圈，避免相鄰格子滲色
const RS := 1.6            # 烘焙解析度倍率
const ORIGIN := Vector2(78, 160)   # 角色腳底在格子裡的位置（第七輪 C0：原本會超框被切掉）
const RING_ORIGIN := Vector2(96, 140)   # 腳底圈格子的中心（有影子，要留下方空間）
const WALK_FRAMES := 8     # V9 P2：6→8，另加拖行、暈眩
const POSE_FRAMES := 2
const ATK_FRAMES := 8      # 三段式攻擊（R5）要多幾格才看得出前搖／揮擊／後搖
# 每個兵種、隊伍的影格順序：0 待機、1 眨眼、2..7 走路、8..23 攻擊兩組（一般／交替或專屬）
const FRAMES_PER := 2 + WALK_FRAMES + POSE_FRAMES + ATK_FRAMES * 2
const COLS := 16
const TYPES_PER_PAGE := 6  # 6×2×28＝336 格＝21 列×192＝4032px，不超過 4096
const MAX_PAGES := 5
const TURN_TYPES := [0, 1, 3, 5, 13, 19]   # V1.3 A1b 試點：劍士、盾兵、騎兵、長槍兵、史萊姆、小石魔
const TURN_C := [0.8, 0.55, 0.3]

var pages: Array = []      # 每頁 {tex, types}
var loc := {}              # 兵種 → [頁, 這一種在頁裡的起始格]
var ring_tex: Texture2D = null
var turn_tex: Texture2D = null   # V1.3 A1b：轉身頁（6 種 × 2 隊 × 3 張）
var turn_loc := {}               # 兵種 → 轉身頁起始格
var ready_cb := -1         # 這份快取是用哪種配色（一般／色盲）烘焙的
var _busy := false
var _gen := 0   # V1.2：每次 build（換色）加一；烘到一半世代變了就作廢（Codex v120-impl2：連切色盲的競態）
var _queue: Array = []
var _baking: Array = []

func is_ready(cb: bool) -> bool:
	return ring_tex != null and ready_cb == (1 if cb else 0)

func has_type(t: int) -> bool:
	return loc.has(t)

func has_turn(t: int) -> bool:
	return turn_tex != null and turn_loc.has(t)

## 腳底在格子裡的位置：往前伸得很長的長槍兵靠左、很寬的小石魔靠右，其他都一樣。
static func origin_of(type: int) -> Vector2:
	return Vector2(70, 160) if type == 5 else (Vector2(90, 160) if type == 19 else Vector2(78, 160))

## 全部清掉，烘舊 10 種和腳底圈。
func build(cb: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	_gen += 1
	pages.clear()
	loc.clear()
	_queue.clear()
	_baking = []
	_busy = false
	ring_tex = null
	turn_tex = null
	turn_loc.clear()
	ready_cb = 1 if cb else 0
	var base: Array = []
	for t in D.COUNT:
		base.append(t)
	var g0 := _gen
	await _bake_ring(cb)
	if g0 != _gen:
		return   # 烘腳底圈時又重建了：交給新的那次
	await ensure(base)
	if g0 != _gen:
		return
	await _bake_turn(cb)

func _bake_turn(cb: bool) -> void:
	var g0 := _gen
	var painter := _TurnPainter.new()
	painter.cb = cb
	var n := TURN_TYPES.size() * 2 * TURN_C.size()
	var vp := _viewport(Vector2i(COLS * CELL, int(ceil(float(n) / COLS)) * CELL), painter)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	img = await _post(img, TURN_C.size())
	if g0 != _gen or (1 if cb else 0) != ready_cb:
		return
	turn_tex = ImageTexture.create_from_image(img)
	for k in TURN_TYPES.size():
		turn_loc[TURN_TYPES[k]] = k * 2 * TURN_C.size()

## 這場要用到的兵種。缺的才烘；烘的時候呼叫端先直接畫。
func ensure(types: Array) -> void:
	if DisplayServer.get_name() == "headless" or ready_cb < 0:
		return
	for t in types:
		if not loc.has(t) and not t in _queue and not t in _baking:
			_queue.append(t)
	if _busy or _queue.is_empty():
		return
	_busy = true
	var g0 := _gen   # 世代變了（build 清空並重設狀態）就不再碰共用狀態（Codex v120-final）
	while not _queue.is_empty():
		var chunk: Array = _queue.slice(0, TYPES_PER_PAGE)
		_queue = _queue.slice(chunk.size())
		_baking = chunk
		await _bake_page(chunk)
		if g0 != _gen:
			return
		_baking = []
	_busy = false

func _viewport(size: Vector2i, painter: Node) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.add_child(painter)
	add_child(vp)
	return vp

func _bake_page(types: Array) -> void:
	var gen0 := _gen
	var cb := ready_cb == 1
	var total := types.size() * 2 * FRAMES_PER
	var rows := int(ceil(float(total) / COLS))
	var painter := _Painter.new()
	painter.cb = cb
	painter.types = types
	var vp := _viewport(Vector2i(COLS * CELL, rows * CELL), painter)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	img = await _post(img)
	if (1 if cb else 0) != ready_cb or gen0 != _gen:
		return   # 烘的時候換了配色（或重建了）：這一批作廢
	# 新兵頁太多就丟最舊的（舊 10 種那兩頁不丟）
	if pages.size() >= MAX_PAGES:
		for i in pages.size():
			if pages[i] != null and int(pages[i]["types"][0]) >= D.COUNT:
				for t in pages[i]["types"]:
					if loc.has(t) and int(loc[t][0]) == i:
						loc.erase(t)
				pages[i] = null
				break
	var pn := pages.size()
	pages.append({"tex": ImageTexture.create_from_image(img), "types": types})
	for k in types.size():
		loc[types[k]] = [pn, k * 2 * FRAMES_PER]

## V1.2 D1：烘好的整頁再跑一次後處理 shader（外輪廓＋頂亮底暗）。沒有 shader 檔或 plain_ui 時原樣。
func _post(img: Image, per := FRAMES_PER) -> Image:
	var sh_path := "res://shaders/unit_bake.gdshader"
	if not ResourceLoader.exists(sh_path) or bool(Save.s("plain_ui")):
		return img
	var tr := TextureRect.new()
	tr.texture = ImageTexture.create_from_image(img)
	tr.size = Vector2(img.get_width(), img.get_height())
	var mat := ShaderMaterial.new()
	mat.shader = load(sh_path)
	mat.set_shader_parameter("cell", float(CELL))
	mat.set_shader_parameter("per", float(per))
	mat.set_shader_parameter("cols", float(COLS))
	tr.material = mat
	var vp := _viewport(Vector2i(img.get_width(), img.get_height()), tr)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var out := vp.get_texture().get_image()
	vp.queue_free()
	return out

func _bake_ring(cb: bool) -> void:
	var painter := _RingPainter.new()
	painter.cb = cb
	var vp := _viewport(Vector2i(10 * CELL, CELL), painter)   # V1.3 A3：4 種隊伍圈＋木座＋影子＋4 種合成（木座＋影子＋圈）
	var g0 := _gen
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if g0 == _gen:
		ring_tex = ImageTexture.create_from_image(vp.get_texture().get_image())
	vp.queue_free()

## variant 1（劍士交替招式）和 2（第四輪新兵的專屬動作）都用第二組攻擊格：新兵沒有交替招式，那一組烘的是專屬動作。
func frame_index(type: int, team: int, walk: float, atk: float, t: float, px: float, variant := 0) -> int:
	var base: int = int(loc[type][1]) + team * FRAMES_PER
	if atk > 0.0:
		return base + 2 + WALK_FRAMES + POSE_FRAMES + ATK_FRAMES * mini(variant, 1) + clampi(int(atk * ATK_FRAMES), 0, ATK_FRAMES - 1)
	if walk <= Gait.POSE_DAZE + 1.0:
		return base + 2 + WALK_FRAMES + 1
	if walk <= Gait.POSE_DRAG + 1.0:
		return base + 2 + WALK_FRAMES
	if walk != 0.0:
		return base + 2 + int(fposmod(walk, TAU) / TAU * WALK_FRAMES) % WALK_FRAMES
	var ex := 2.0 if type == D.CAVALRY else 3.5   # Art._eyes 的眼睛中心 x
	var blink := fmod(t + ex * 0.13 + fposmod(px * 0.731, 3.7), 3.7) <= 0.12   # V1.3 A2：依位置錯開，同種兵不再一起眨眼
	return base + (1 if blink else 0)

func draw_ring(ci: CanvasItem, p: Vector2, team: int, type: int, scale := 1.0, air := 0.0) -> void:
	var idx := team * 2 + (1 if (type == D.SHIELD or type == D.CAVALRY or type == 19) else 0)
	ci.draw_set_transform_matrix(Art.base * Transform2D(0.0, Vector2(scale / RS, scale / RS), 0.0, p))
	if air <= 0.0:
		# 站在地上（絕大多數）：一次貼好預先合成的三層（效能：每隻 1 次貼圖，不是 3 次）
		ci.draw_texture_rect_region(ring_tex, Rect2(-RING_ORIGIN, Vector2(CELL, CELL)), Rect2((6 + idx) * CELL, 0, CELL, CELL))
		ci.draw_set_transform_matrix(Art.base)
		return
	ci.draw_texture_rect_region(ring_tex, Rect2(-RING_ORIGIN, Vector2(CELL, CELL)), Rect2(4 * CELL, 0, CELL, CELL))   # 木座
	if air > 0.0:
		var ss := scale * (1.0 - air * 0.35)
		ci.draw_set_transform_matrix(Art.base * Transform2D(0.0, Vector2(ss / RS, ss / RS), 0.0, p))
	ci.draw_texture_rect_region(ring_tex, Rect2(-RING_ORIGIN, Vector2(CELL, CELL)), Rect2(5 * CELL, 0, CELL, CELL))   # 影子（跳起來縮）
	if air > 0.0:
		ci.draw_set_transform_matrix(Art.base * Transform2D(0.0, Vector2(scale / RS, scale / RS), 0.0, p))
	ci.draw_texture_rect_region(ring_tex, Rect2(-RING_ORIGIN, Vector2(CELL, CELL)), Rect2(idx * CELL, 0, CELL, CELL))
	ci.draw_set_transform_matrix(Art.base)

## 倒棋用：只貼木座（帶透明度）。
func draw_base(ci: CanvasItem, p: Vector2, scale := 1.0, a := 1.0) -> void:
	ci.draw_set_transform_matrix(Art.base * Transform2D(0.0, Vector2(scale / RS, scale / RS), 0.0, p))
	ci.draw_texture_rect_region(ring_tex, Rect2(-RING_ORIGIN, Vector2(CELL, CELL)), Rect2(4 * CELL, 0, CELL, CELL), Color(1, 1, 1, a))
	ci.draw_set_transform_matrix(Art.base)

func _rect(idx: int) -> Rect2:
	return Rect2((idx % COLS) * CELL, (idx / COLS) * CELL, CELL, CELL)

## 量化後實際烘焙的走路相位／攻擊進度（疊加表情時用，才會跟貼圖對齊）。
func quant_walk(walk: float) -> float:
	if walk == 0.0:
		return 0.0
	if walk < -50.0:
		return walk
	return 0.0001 + (int(fposmod(walk, TAU) / TAU * WALK_FRAMES) % WALK_FRAMES) * TAU / WALK_FRAMES

func quant_atk(atk: float) -> float:
	if atk <= 0.0:
		return 0.0
	return (clampi(int(atk * ATK_FRAMES), 0, ATK_FRAMES - 1) + 0.5) / ATK_FRAMES

## 貼一隻角色。參數與 Art.unit 相同；待機的呼吸位移在這裡加（烘焙時是 0）。
func draw_unit(ci: CanvasItem, p: Vector2, type: int, team: int, face: float, walk: float, atk: float,
		hurt: float, alpha: float, t: float, scale := 1.0, mood := 0, lean := 0.0, crouch := 1.0, cb := false, variant := 0) -> void:
	if absf(face) < 0.9 and has_turn(type):
		if atk <= 0.0:
			_draw_turn(ci, p, type, team, face, hurt, alpha, t, scale, lean, crouch, mood, cb)
			return
		face = (1.0 if face >= 0.0 else -1.0) * maxf(absf(face), 0.45)   # 轉到一半就出手：像厚木牌，不夾成 0.18（Codex v130-impl1）
	var idx := frame_index(type, team, walk, atk, t, p.x, variant)
	if atk > 0.0:
		walk = 0.0   # 攻擊影格烘焙時沒有走路相位：貼圖與疊加都當成沒在走（Codex 收尾輪 #4）
	var bob := Art.idle_bob(t, p) if walk == 0.0 else 0.0   # 與 Art.unit 相同：沒走路時（含攻擊）都有呼吸
	var xf := Art.base * Transform2D(lean * face, Vector2(scale * face / RS, scale * crouch / RS), 0.0, p + Vector2(0, bob * scale))
	ci.draw_set_transform_matrix(xf)
	ci.draw_texture_rect_region(pages[loc[type][0]]["tex"], Rect2(-origin_of(type), Vector2(CELL, CELL)), _rect(idx), Color(1, 1, 1, alpha))
	if hurt > 0.0:
		# V1.3 A6：受擊閃白改成整隻剪影變白（同一格再貼一次、顏色乘到飽和），不再是一顆白圓
		ci.draw_texture_rect_region(pages[loc[type][0]]["tex"], Rect2(-origin_of(type), Vector2(CELL, CELL)), _rect(idx), Color(4, 4, 4, hurt * 0.55 * alpha))
	if mood != 0:
		# 攻擊影格烘焙時沒有走路相位（Codex R5 #3）
		var qa := quant_atk(atk)
		var qw := 0.0 if qa > 0.0 else quant_walk(walk)
		ci.draw_set_transform_matrix(Art.base * Art.unit_xf(p, face, qw, qa, t, scale, lean, crouch, type) * Gait.body_xf(type, qw))
		if mood != 0:
			Art.overlay(ci, type, team, mood, alpha, t, cb)
	ci.draw_set_transform_matrix(Art.base)

## V1.3 A1b：轉身中（|face|＜0.9）貼轉身頁：影格本身已經是轉到一半的姿勢，貼圖只翻正負、不再等比夾扁。
func _draw_turn(ci: CanvasItem, p: Vector2, type: int, team: int, face: float, hurt: float, alpha: float, t: float, scale: float, lean: float, crouch: float, mood := 0, cb := false) -> void:
	var af := absf(face)
	var j := 0 if af >= 0.67 else (1 if af >= 0.42 else 2)
	var idx: int = int(turn_loc[type]) + team * TURN_C.size() + j
	var sg := -1.0 if face < 0.0 else 1.0
	var bob := Art.idle_bob(t, p)
	ci.draw_set_transform_matrix(Art.base * Transform2D(lean * sg, Vector2(scale * sg / RS, scale * crouch / RS), 0.0, p + Vector2(0, bob * scale)))
	ci.draw_texture_rect_region(turn_tex, Rect2(-origin_of(type), Vector2(CELL, CELL)), _rect(idx), Color(1, 1, 1, alpha))
	if hurt > 0.0:
		ci.draw_texture_rect_region(turn_tex, Rect2(-origin_of(type), Vector2(CELL, CELL)), _rect(idx), Color(4, 4, 4, hurt * 0.55 * alpha))
	if mood != 0 and j == 0:
		# 表情疊加（受擊、狂熱…）：轉身中也要有（Codex v130-impl1）；只在接近側面那一格畫，
		# 更窄的兩格臉已經往中間移，正側面的表情位置對不上（Codex v130-impl2），那 0.1 秒不畫
		ci.draw_set_transform_matrix(Art.base * Art.unit_xf(p, sg, 0.0, 0.0, t, scale, lean, crouch, type))
		Art.overlay(ci, type, team, mood, alpha, t, cb)
	ci.draw_set_transform_matrix(Art.base)

## 烘焙用的畫家：一格一格呼叫 Art.unit（face＝+1，翻面由貼圖時處理）。
class _Painter extends Node2D:
	var cb := false
	var types: Array = []
	func _draw() -> void:
		var Art2 = preload("res://scripts/ui/art.gd")
		var D2 = preload("res://scripts/core/unit_defs.gd")
		var saved: Transform2D = Art2.base
		Art2.base = Transform2D.IDENTITY
		var CELL2 := 192
		var RS2 := 1.6
		var W2 := 8
		var per := 2 + W2 + 2 + 8 + 8
		var cols := 16
		for k in types.size():
			var type: int = types[k]
			for team in 2:
				for f in per:
					var idx: int = (k * 2 + team) * per + f
					var cell_o := Vector2((idx % cols) * CELL2, (idx / cols) * CELL2)
					var walk := 0.0
					var atk := 0.0
					var vr := 0
					if f >= 2 and f < 2 + W2:
						walk = 0.0001 + (f - 2) * TAU / W2
					elif f == 2 + W2:
						walk = -100.0   # 拖行（Gait.POSE_DRAG）
					elif f == 3 + W2:
						walk = -200.0   # 暈眩（Gait.POSE_DAZE）
					elif f >= 4 + W2 + 8:
						atk = (f - (4 + W2 + 8) + 0.5) / 8.0
						vr = 1 if type < D2.CLASSIC else 2   # 第四輪新兵沒有交替招式，這一組放專屬動作（variant 2）
					elif f >= 4 + W2:
						atk = (f - (4 + W2) + 0.5) / 8.0
					var p := cell_o + (Vector2(70, 160) if type == 5 else (Vector2(90, 160) if type == 19 else Vector2(78, 160)))
					var ex := 2.0 if type == D2.CAVALRY else 3.5
					# 眨眼那一格落在眨眼區間中間；其他格取 1.0（不在眨眼區間）
					var tt: float = (3.7 - ex * 0.13 + 0.05) if f == 1 else 1.0
					# 沒走路的格子（待機、眨眼、攻擊）Art.unit 會加呼吸位移；這裡反向抵銷，貼圖時再依當下時間加
					Art2.bake_no_bob = true   # V1.3：烘焙時不加呼吸（原本是反向抵銷），貼圖時再依當下時間與位置加
					Art2.unit(self, p, type, team, 1.0, walk, atk, 0.0, 1.0, tt, RS2, cb, 0, 0.0, 1.0, vr)
					Art2.bake_no_bob = false
		Art2.base = saved

## V1.3 A1b：轉身頁。每種兵 × 兩隊 × 3 張中間姿勢（cos θ＝0.8、0.55、0.3），待機姿勢、face＝+1。
class _TurnPainter extends Node2D:
	var cb := false
	func _draw() -> void:
		var Art2 = preload("res://scripts/ui/art.gd")
		var SC = preload("res://scripts/ui/sprite_cache.gd")
		var saved: Transform2D = Art2.base
		Art2.base = Transform2D.IDENTITY
		Art2.bake_no_bob = true
		for k in SC.TURN_TYPES.size():
			var type: int = SC.TURN_TYPES[k]
			for team in 2:
				for j in SC.TURN_C.size():
					var idx: int = (k * 2 + team) * SC.TURN_C.size() + j
					var p := Vector2((idx % SC.COLS) * SC.CELL, (idx / SC.COLS) * SC.CELL) + SC.origin_of(type)
					var c: float = SC.TURN_C[j]
					Art2.turn_c = c
					Art2.turn_s = sqrt(1.0 - c * c)
					Art2.unit(self, p, type, team, 1.0, 0.0, 0.0, 0.0, 1.0, 1.0, SC.RS, cb)
		Art2.turn_c = 1.0
		Art2.turn_s = 0.0
		Art2.bake_no_bob = false
		Art2.base = saved

class _RingPainter extends Node2D:
	var cb := false
	func _draw() -> void:
		var Art2 = preload("res://scripts/ui/art.gd")
		var D2 = preload("res://scripts/core/unit_defs.gd")
		var saved: Transform2D = Art2.base
		Art2.base = Transform2D.IDENTITY
		for team in 2:
			for heavy in 2:
				var o := Vector2((team * 2 + heavy) * 192, 0) + Vector2(96, 140)
				Art2.ring_mark(self, o, team, D2.SHIELD if heavy == 1 else D2.SWORD, cb, 1.6)
		Art2.ring_base(self, Vector2(4 * 192, 0) + Vector2(96, 140), 1.6)
		Art2.ring_shadow(self, Vector2(5 * 192, 0) + Vector2(96, 140), 1.6)
		for team in 2:
			for heavy in 2:
				var o2 := Vector2((6 + team * 2 + heavy) * 192, 0) + Vector2(96, 140)
				Art2.ring(self, o2, team, D2.SHIELD if heavy == 1 else D2.SWORD, cb, 1.6)
		Art2.base = saved
