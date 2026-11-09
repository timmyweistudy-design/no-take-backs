extends SceneTree
## V1.5 角色驗收包：每種兵一個 GIF（和圖鑑一樣 2 倍）：正側面→轉向鏡頭→朝左→轉回來（16 格）＋ 一次完整攻擊（14 格：前搖、出手、後搖）＋ 待機小動作（6 格）。
## 另外輸出一張拼表 units_sheet.png（每種兵一列：轉身 8 格＋攻擊 6 格）。要真的繪圖，不能 headless：
## "<exe>" --path <game> --resolution 1600x900 --script res://tools/unit_review.gd -- --out=<Windows 資料夾> [--only=0,2,6]
const Art = preload("res://scripts/ui/art.gd")
const F8 = preload("res://scripts/core/fantasy_defs.gd")
const GIF = preload("res://scripts/game/gif.gd")
const W := 240
const H := 220
var out := "."
var only: Array = []

class Painter extends Node2D:
	var ty := 0
	var face := 1.0
	var tc := 1.0
	var atk := 0.0
	var bk := false
	var t := 0.0
	var label := ""
	func _draw() -> void:
		draw_rect(Rect2(0, 0, W, H), Color("#c9b48a"))
		draw_rect(Rect2(0, 150, W, 70), Color("#7d9a58"))
		Art.turn_c = tc
		Art.turn_s = sqrt(maxf(0.0, 1.0 - tc * tc))
		Art.back = bk and ty in Art.BACK_OK
		var p := Vector2(W / 2, 190)
		Art.ring(self, p, 0, ty, false, 2.0)
		Art.unit(self, p, ty, 0, face, 0.0, atk, 0.0, 1.0, t, 2.0)
		Art.turn_c = 1.0
		Art.turn_s = 0.0
		Art.back = false

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--only="):
			for x in a.substr(7).split(","):
				only.append(int(x))
	_run.call_deferred()

## 一格的參數：[face, turn_c, atk, t]
func _frames() -> Array:
	var fr: Array = []
	for i in 16:
		var cf := cos(i / 16.0 * TAU)
		fr.append([1.0 if cf >= 0.0 else -1.0, maxf(absf(cf), 0.3) if absf(cf) < 0.95 else 1.0, 0.0, 0.5, sin(i / 16.0 * TAU) < -0.01])   # 後半圈看背面（人形兵）
	for i in 14:
		fr.append([1.0, 1.0, 0.001 + i / 13.0 * 0.999, 0.5, false])
	for i in 6:
		fr.append([1.0, 1.0, 0.0, 0.5 + i * 0.4, false])
	return fr

func _snap(vp: SubViewport, pn: Painter, f: Array) -> Image:
	pn.face = f[0]
	pn.tc = f[1]
	pn.atk = f[2]
	pn.t = f[3]
	pn.bk = f[4]
	pn.queue_redraw()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img

func _run() -> void:
	var N: int = F8.DRAW_TOTAL
	var types: Array = only if not only.is_empty() else range(N)
	var frs := _frames()
	var pick := [0, 2, 4, 6, 8, 10, 12, 14, 16, 19, 21, 23, 26, 29]   # 拼表取的 14 格
	var sheet := Image.create(W * pick.size(), H * types.size(), false, Image.FORMAT_RGBA8)
	var vp := SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var pn := Painter.new()
	vp.add_child(pn)
	root.add_child(vp)
	var row := 0
	for ty in types:
		pn.ty = int(ty)
		var imgs: Array = []
		for f in frs:
			imgs.append(await _snap(vp, pn, f))
		var gif := GIF.encode(imgs, 9)
		var fa := FileAccess.open(out.path_join("unit_%02d.gif" % int(ty)), FileAccess.WRITE)
		fa.store_buffer(gif)
		fa.close()
		for k in pick.size():
			sheet.blit_rect(imgs[pick[k]], Rect2i(0, 0, W, H), Vector2i(k * W, row * H))
		row += 1
	sheet.save_png(out.path_join("units_sheet.png"))
	print("REVIEW ", types.size(), " 種")
	quit()
