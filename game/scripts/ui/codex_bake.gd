extends Node
## V1.5.1 A6：圖鑑大圖也套戰場圖集的烘焙後處理（外框、漬洗、乾掃），轉身、背面、出手時畫風不突變。
## 兩段 SubViewport：① 用向量畫角色（任何角度、背面都畫得出來）② 套 unit_bake.gdshader。每幀更新，只在圖鑑開著時用。
## 用法：每幀 set_params(...)，再把 texture() 貼在腳底減 FEET 的位置（畫面落後一幀，看不出來）。

const SIZE := Vector2i(600, 400)   # V1.5.1：放大 3.4 倍時長槍槍尖伸到腳底右邊約 241px，左右各留 300（Codex v151-i1 #8）
const FEET := Vector2(300, 370)   # 角色腳底在貼圖裡的位置

var _vp1: SubViewport
var _vp2: SubViewport
var _painter: _P
var _rect: TextureRect
var _mat: ShaderMaterial

class _P extends Node2D:
	var prm := {}
	func _draw() -> void:
		if prm.is_empty():
			return
		var Art2 = preload("res://scripts/ui/art.gd")
		var saved: Transform2D = Art2.base
		Art2.base = Transform2D.IDENTITY
		Art2.turn_c = float(prm["turn_c"])
		Art2.turn_s = float(prm["turn_s"])
		Art2.back = bool(prm["back"])
		Art2.calm = bool(prm["calm"])
		Art2.look = float(prm["look"])
		Art2.unit(self, FEET_P, int(prm["type"]), 0, float(prm["face"]), 0.0, float(prm["atk"]), float(prm["hurt"]), 1.0, float(prm["t"]), float(prm["scale"]), bool(prm["cb"]), 0, 0.0, 1.0, int(prm["variant"]))
		Art2.turn_c = 1.0
		Art2.turn_s = 0.0
		Art2.back = false
		Art2.calm = false
		Art2.look = 0.0
		Art2.base = saved
	const FEET_P := Vector2(300, 370)

func _ready() -> void:
	_vp1 = SubViewport.new()
	_vp1.size = SIZE
	_vp1.transparent_bg = true
	_vp1.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_painter = _P.new()
	_vp1.add_child(_painter)
	add_child(_vp1)
	_vp2 = SubViewport.new()
	_vp2.size = SIZE
	_vp2.transparent_bg = true
	_vp2.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_rect = TextureRect.new()
	_rect.size = Vector2(SIZE)
	_rect.texture = _vp1.get_texture()
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/unit_bake.gdshader")
	# 腳底在格子高度的 0.83（和圖集 160／192 一樣），頂亮底暗的漸層位置才一致；per 很大＝整張都算隊伍 0（藍方墨色）
	_mat.set_shader_parameter("cell", FEET.y / (160.0 / 192.0))
	_mat.set_shader_parameter("per", 100000.0)
	_mat.set_shader_parameter("cols", 1.0)
	_rect.material = _mat
	_vp2.add_child(_rect)
	add_child(_vp2)

var _last_use := 0
## 圖鑑沒在畫就停掉兩個子視窗（不再每幀渲染，Codex v151-i1 #9）
func _process(_d: float) -> void:
	if _vp1 != null and _vp1.render_target_update_mode != SubViewport.UPDATE_DISABLED and Time.get_ticks_msec() - _last_use > 300:
		_vp1.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_vp2.render_target_update_mode = SubViewport.UPDATE_DISABLED

func set_params(p: Dictionary, wash: float, dry: float) -> void:
	_last_use = Time.get_ticks_msec()
	if _vp1.render_target_update_mode != SubViewport.UPDATE_ALWAYS:
		_vp1.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_vp2.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_painter.prm = p
	_painter.queue_redraw()
	_mat.set_shader_parameter("sh_amt", wash)
	_mat.set_shader_parameter("hi_amt", dry)
	# 外框粗細跟著縮放（圖集是 RS 1.6 倍烘、半徑 3）
	_mat.set_shader_parameter("radius", 3.0 * float(p.get("scale", 1.6)) / 1.6)

func texture() -> Texture2D:
	return _vp2.get_texture()
