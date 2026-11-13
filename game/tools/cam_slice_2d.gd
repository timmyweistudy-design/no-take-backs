extends Node2D
## cam_slice.gd 的 2D 基準：同一個視窗畫一張 16×9 盤面＋牆塊立面＋三隻立牌（和遊戲裡的路線 B 同類的繪製量）。
func _process(_d: float) -> void:
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 800), Color(0.36, 0.24, 0.15))
	var o := Vector2(128, 160)
	draw_rect(Rect2(o - Vector2(10, 10), Vector2(1044, 596)), Color(0.45, 0.3, 0.18))
	draw_rect(Rect2(o, Vector2(1024, 576)), Color(0.45, 0.62, 0.3))
	for i in 14:
		var c := o + Vector2((6 + (i % 2) * 3) * 64.0, float(i / 2) * 64.0)
		draw_rect(Rect2(c + Vector2(6, 8), Vector2(64, 64)), Color(0, 0, 0, 0.2))
		draw_rect(Rect2(c - Vector2(0, 10), Vector2(64, 64)), Color(0.5, 0.32, 0.2))
		draw_rect(Rect2(c + Vector2(0, 54), Vector2(64, 10)), Color(0.32, 0.2, 0.12))
	var ic: Texture2D = load("res://icon.svg")
	for k in 3:
		draw_texture_rect(ic, Rect2(o + Vector2(160 + k * 256, 240), Vector2(64, 64)), false)
