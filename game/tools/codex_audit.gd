extends SceneTree
## V1.5 規劃用的角色檢查表（不改遊戲）：每種兵放大 2 倍（圖鑑同倍率），一列 8 格：
## 正側面、轉身 0.8／0.55／0.3、前搖、揮擊、朝左、受擊。要真的繪圖，不能 headless。
## "<exe>" --path <game> --resolution 1600x900 --script res://tools/codex_audit.gd -- --out=<Windows 資料夾>
const Art = preload("res://scripts/ui/art.gd")
const F8 = preload("res://scripts/core/fantasy_defs.gd")
const CW := 260   # 每格寬（長武器不被格子裁掉）
var out := "."

class Painter extends Node2D:
	var ty := 0
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 8 * CW, 220), Color("#7d9a58"))
		var cols := [[1.0, 1.0, 0.0, 0.0], [1.0, 0.8, 0.0, 0.0], [1.0, 0.55, 0.0, 0.0], [1.0, 0.3, 0.0, 0.0],
			[1.0, 1.0, Art.ATK_WINDUP, 0.0], [1.0, 1.0, Art.ATK_STRIKE, 0.0], [-1.0, 1.0, 0.0, 0.0], [1.0, 1.0, 0.0, 0.8]]
		for k in cols.size():
			var c: Array = cols[k]
			Art.turn_c = float(c[1])
			Art.turn_s = sqrt(1.0 - Art.turn_c * Art.turn_c)
			var p := Vector2(CW / 2 + k * CW, 190)
			draw_line(Vector2(k * CW, 0), Vector2(k * CW, 220), Color(0, 0, 0, 0.3), 1.0)
			Art.ring(self, p, 0, ty, false, 2.0)
			Art.unit(self, p, ty, 0, float(c[0]), 0.0, float(c[2]), float(c[3]), 1.0, 0.5, 2.0)
		Art.turn_c = 1.0
		Art.turn_s = 0.0

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	_run.call_deferred()

func _run() -> void:
	var N: int = F8.DRAW_TOTAL
	var sheet := Image.create(8 * CW, 220 * N, false, Image.FORMAT_RGBA8)
	for ty in N:
		var vp := SubViewport.new()
		vp.size = Vector2i(8 * CW, 220)
		vp.transparent_bg = false
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var pn := Painter.new()
		pn.ty = ty
		vp.add_child(pn)
		root.add_child(vp)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(0, 0, 8 * CW, 220), Vector2i(0, ty * 220))
		vp.queue_free()
	sheet.save_png(out.path_join("codex_audit.png"))
	print("AUDIT ", N, " 種")
	quit()
