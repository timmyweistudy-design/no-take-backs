extends SceneTree
## 角色全影格拼圖（V9 P2）：要真的繪圖，不能 headless。
## "<exe>" --path <game> --script res://tools/anim_sheet.gd -- --out=<Windows 路徑>
## 產出 frames.png：每列一種兵（藍方），每欄一格；anim_lint.py 用它檢查。
const SC = preload("res://scripts/ui/sprite_cache.gd")
const F8 = preload("res://scripts/core/fantasy_defs.gd")
var out := "."
var cache
func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	cache = SC.new()
	root.add_child(cache)
	_run.call_deferred()
func _run() -> void:
	await cache.build(false)
	var all: Array = []
	for t0 in F8.DRAW_TOTAL:
		all.append(t0)
	await cache.ensure(all)
	while cache._busy:
		await process_frame
	var per: int = SC.FRAMES_PER
	var N: int = F8.DRAW_TOTAL
	var sheet := Image.create(SC.CELL * per, SC.CELL * N, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#7d9a58"))
	var imgs := {}
	for ty in N:
		var pn: int = cache.loc[ty][0]
		if not imgs.has(pn):
			imgs[pn] = cache.pages[pn]["tex"].get_image()
		for f in per:
			var r: Rect2 = cache._rect(int(cache.loc[ty][1]) + f)
			sheet.blend_rect(imgs[pn], Rect2i(r), Vector2i(f * SC.CELL, ty * SC.CELL))
	sheet.save_png(out + "/frames.png")
	print("FRAMES ok ", per, " ", N)
	# V1.3 A1b：轉身逐格條。每列一種試點兵（藍方）：正側面、cos 0.8／0.55／0.3、鏡像 0.3／0.55／0.8、反面
	if cache.turn_tex != null:
		var tim: Image = cache.turn_tex.get_image()
		var nt: int = SC.TURN_TYPES.size()
		var nc: int = SC.TURN_C.size()
		var strip := Image.create(SC.CELL * (2 + nc * 2), SC.CELL * nt, false, Image.FORMAT_RGBA8)
		strip.fill(Color("#7d9a58"))
		for k in nt:
			var ty: int = SC.TURN_TYPES[k]
			var pn: int = cache.loc[ty][0]
			if not imgs.has(pn):
				imgs[pn] = cache.pages[pn]["tex"].get_image()
			var side := Image.create(SC.CELL, SC.CELL, false, Image.FORMAT_RGBA8)
			side.blit_rect(imgs[pn], Rect2i(cache._rect(int(cache.loc[ty][1]))), Vector2i.ZERO)
			strip.blend_rect(side, Rect2i(0, 0, SC.CELL, SC.CELL), Vector2i(0, k * SC.CELL))
			for j in nc:
				var cell := Image.create(SC.CELL, SC.CELL, false, Image.FORMAT_RGBA8)
				cell.blit_rect(tim, Rect2i(cache._rect(int(cache.turn_loc[ty]) + j)), Vector2i.ZERO)
				strip.blend_rect(cell, Rect2i(0, 0, SC.CELL, SC.CELL), Vector2i((1 + j) * SC.CELL, k * SC.CELL))
				var m := cell.duplicate()
				m.flip_x()
				strip.blend_rect(m, Rect2i(0, 0, SC.CELL, SC.CELL), Vector2i((nc * 2 - j) * SC.CELL, k * SC.CELL))
			var ms := side.duplicate()
			ms.flip_x()
			strip.blend_rect(ms, Rect2i(0, 0, SC.CELL, SC.CELL), Vector2i((1 + nc * 2) * SC.CELL, k * SC.CELL))
		strip.save_png(out + "/turn.png")
		print("TURN ok ", nt)
	quit()
