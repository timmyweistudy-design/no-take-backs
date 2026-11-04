extends Node
## 角色精靈圖快取（第二輪方案 R2、H）：實測 48 隻時每幀直接程式繪製要 34ms（約 15fps），
## 所以啟動時用同一份 Art.unit 畫法，把每個兵種×隊伍×動作影格一次畫進一張圖集，戰鬥中只貼圖。
## 用同一份畫法烘焙，但不是逐像素等價（Codex R1 審查 #3、#4，已知且接受的差異）：
##  - 走路量化成 6 格、攻擊 8 格；攻擊中不再疊走路相位；走路／攻擊格固定睜眼（只在待機眨眼）。
## 表情疊加（受擊、暈眩、衝鋒、狂熱、潛行、頂住）不烘焙，貼完圖再用 Art.overlay 在同一個局部座標畫上去。
##  - 透明度（潛行）是對整張合成好的角色乘 alpha，重疊的部位不會像逐圖元那樣透出底下的線條。
## 待機呼吸位移在貼圖時加（烘焙時抵銷為 0）；受擊閃白跟著攻擊前衝與走路起伏。
## 沒有畫面（headless）或還沒建好時，呼叫端退回 Art.unit。

const Art = preload("res://scripts/ui/art.gd")
const D = preload("res://scripts/core/unit_defs.gd")

const CELL := 192          # 每格像素（以 RS 倍率畫）；比角色大一圈，避免相鄰格子滲色
const RS := 1.6            # 烘焙解析度倍率
const ORIGIN := Vector2(74, 160)   # 角色腳底在格子裡的位置（第七輪 C0：原本 124，長槍、法杖、高帽超框被切掉）
const RING_ORIGIN := Vector2(96, 140)   # 腳底圈格子的中心（有影子，要留下方空間）
const WALK_FRAMES := 6
const ATK_FRAMES := 8      # 三段式攻擊（R5）要多幾格才看得出前搖／揮擊／後搖
# 每個兵種、隊伍的影格順序：0 待機、1 眨眼、2..7 走路、8..13 攻擊
const FRAMES_PER := 2 + WALK_FRAMES + ATK_FRAMES * 2   # 攻擊兩組：一般／交替招式（第三輪 R4）

var tex: Texture2D = null
var ring_tex: Texture2D = null
var ready_cb := -1         # 這份快取是用哪種配色（一般／色盲）烘焙的
var _cols := 16

func is_ready(cb: bool) -> bool:
	return tex != null and ready_cb == (1 if cb else 0)

## 烘焙：在 SubViewport 一次畫完所有影格，讀回成一張圖。
func build(cb: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var total := D.COUNT * 2 * FRAMES_PER
	var rows := int(ceil(float(total) / _cols)) + 1   # 最後一列放腳底圈
	var vp := SubViewport.new()
	vp.size = Vector2i(_cols * CELL, rows * CELL)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var painter := _Painter.new()
	painter.cb = cb
	painter.cols = _cols
	vp.add_child(painter)
	add_child(vp)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	tex = ImageTexture.create_from_image(img)
	ready_cb = 1 if cb else 0
	vp.queue_free()

## variant 1（劍士交替招式）和 2（第四輪新兵的專屬動作）都用第二組攻擊格：新兵沒有交替招式，那一組烘的是專屬動作。
func frame_index(type: int, team: int, walk: float, atk: float, t: float, px: float, variant := 0) -> int:
	var base := (type * 2 + team) * FRAMES_PER
	if atk > 0.0:
		return base + 2 + WALK_FRAMES + ATK_FRAMES * mini(variant, 1) + clampi(int(atk * ATK_FRAMES), 0, ATK_FRAMES - 1)
	if walk != 0.0:
		return base + 2 + int(fposmod(walk, TAU) / TAU * WALK_FRAMES) % WALK_FRAMES
	var ex := 2.0 if type == D.CAVALRY else 3.5   # Art._eyes 的眼睛中心 x
	var blink := fmod(t + ex * 0.13, 3.7) <= 0.12   # 與 Art._eyes 相同的眨眼節奏
	return base + (1 if blink else 0)

## 腳底圈：隊伍×（一般／重兵）共 4 格，放在所有角色影格之後。
func ring_index(team: int, heavy: bool) -> int:
	return D.COUNT * 2 * FRAMES_PER + team * 2 + (1 if heavy else 0)

func draw_ring(ci: CanvasItem, p: Vector2, team: int, type: int, scale := 1.0) -> void:
	var idx := ring_index(team, type == D.SHIELD or type == D.CAVALRY)
	ci.draw_set_transform_matrix(Art.base * Transform2D(0.0, Vector2(scale / RS, scale / RS), 0.0, p))
	ci.draw_texture_rect_region(tex, Rect2(-RING_ORIGIN, Vector2(CELL, CELL)), _rect(idx))
	ci.draw_set_transform_matrix(Art.base)

func _rect(idx: int) -> Rect2:
	return Rect2((idx % _cols) * CELL, (idx / _cols) * CELL, CELL, CELL)

## 量化後實際烘焙的走路相位／攻擊進度（疊加表情時用，才會跟貼圖對齊）。
func quant_walk(walk: float) -> float:
	if walk == 0.0:
		return 0.0
	return 0.0001 + (int(fposmod(walk, TAU) / TAU * WALK_FRAMES) % WALK_FRAMES) * TAU / WALK_FRAMES

func quant_atk(atk: float) -> float:
	if atk <= 0.0:
		return 0.0
	return (clampi(int(atk * ATK_FRAMES), 0, ATK_FRAMES - 1) + 0.5) / ATK_FRAMES

## 貼一隻角色。參數與 Art.unit 相同；待機的呼吸位移在這裡加（烘焙時是 0）。
func draw_unit(ci: CanvasItem, p: Vector2, type: int, team: int, face: float, walk: float, atk: float,
		hurt: float, alpha: float, t: float, scale := 1.0, mood := 0, lean := 0.0, crouch := 1.0, cb := false, variant := 0) -> void:
	var idx := frame_index(type, team, walk, atk, t, p.x, variant)
	if atk > 0.0:
		walk = 0.0   # 攻擊影格烘焙時沒有走路相位：貼圖與疊加都當成沒在走（Codex 收尾輪 #4）
	var bob := sin(t * 3.0 + p.x * 0.05) * 0.8 if walk == 0.0 else 0.0   # 與 Art.unit 相同：沒走路時（含攻擊）都有呼吸
	var xf := Art.base * Transform2D(lean * face, Vector2(scale * face / RS, scale * crouch / RS), 0.0, p + Vector2(0, bob * scale))
	ci.draw_set_transform_matrix(xf)
	ci.draw_texture_rect_region(tex, Rect2(-ORIGIN, Vector2(CELL, CELL)), _rect(idx), Color(1, 1, 1, alpha))
	if hurt > 0.0 or mood != 0:
		# 攻擊影格烘焙時沒有走路相位（Codex R5 #3）
		var qa := quant_atk(atk)
		ci.draw_set_transform_matrix(Art.base * Art.unit_xf(p, face, 0.0 if qa > 0.0 else quant_walk(walk), qa, t, scale, lean, crouch))
		if hurt > 0.0:
			ci.draw_circle(Vector2(0, -26), 14.0, Color(1, 1, 1, hurt * 0.55 * alpha), true, -1.0, false)
		if mood != 0:
			Art.overlay(ci, type, team, mood, alpha, t, cb)
	ci.draw_set_transform_matrix(Art.base)

## 烘焙用的畫家：一格一格呼叫 Art.unit（face＝+1，翻面由貼圖時處理）。
class _Painter extends Node2D:
	var cb := false
	var cols := 16
	func _draw() -> void:
		var Art2 = preload("res://scripts/ui/art.gd")
		var D2 = preload("res://scripts/core/unit_defs.gd")
		var saved: Transform2D = Art2.base
		Art2.base = Transform2D.IDENTITY
		var CELL2 := 192
		var RS2 := 1.6
		var org := Vector2(74, 160)
		var per := 2 + 6 + 8 + 8
		for type in D2.COUNT:
			for team in 2:
				for f in per:
					var idx: int = (type * 2 + team) * per + f
					var cell_o := Vector2((idx % cols) * CELL2, (idx / cols) * CELL2)
					var walk := 0.0
					var atk := 0.0
					var vr := 0
					if f >= 2 and f < 8:
						walk = 0.0001 + (f - 2) * TAU / 6.0
					elif f >= 16:
						atk = (f - 16 + 0.5) / 8.0
						vr = 1 if type < D2.CLASSIC else 2   # 第四輪新兵沒有交替招式，這一組放專屬動作（variant 2）
					elif f >= 8:
						atk = (f - 8 + 0.5) / 8.0
					var p := cell_o + org
					var ex := 2.0 if type == D2.CAVALRY else 3.5
					# 眨眼那一格落在眨眼區間中間；其他格取 1.0（不在眨眼區間）
					var tt: float = (3.7 - ex * 0.13 + 0.05) if f == 1 else 1.0
					# 沒走路的格子（待機、眨眼、攻擊）Art.unit 會加呼吸位移；這裡反向抵銷，貼圖時再依當下時間加
					var pb := p
					if walk == 0.0:
						pb.y -= sin(tt * 3.0 + p.x * 0.05) * 0.8 * RS2
					Art2.unit(self, pb, type, team, 1.0, walk, atk, 0.0, 1.0, tt, RS2, cb, 0, 0.0, 1.0, vr)
		# 腳底圈
		var start: int = D2.COUNT * 2 * per
		for team in 2:
			for heavy in 2:
				var idx2: int = start + team * 2 + heavy
				var o := Vector2((idx2 % cols) * CELL2, (idx2 / cols) * CELL2) + Vector2(96, 140)
				Art2.ring(self, o, team, D2.SHIELD if heavy == 1 else D2.SWORD, cb, RS2)
		Art2.base = saved
