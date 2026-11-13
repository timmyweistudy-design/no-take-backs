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
	preload("res://scripts/ui/art.gd").anchor_on = true   # V1.3.1：烘轉身頁時記錄臉與武器
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
		# 武器線段不能進眼睛區（臉中心 ±6×±5 單位 × 烘焙倍率：兩眼外緣），用線段與方框相交判斷
		var Art3 = preload("res://scripts/ui/art.gd")
		var bad: Array = []
		for key in Art3.anchor_log.keys():
			var rec: Dictionary = Art3.anchor_log[key]
			for fc in rec["face"]:
				var box := Rect2(fc[0] - Vector2(6, 5) * SC.RS, Vector2(12, 10) * SC.RS)
				for wl in rec["weapon"]:
					for i in range(wl.size() - 1):
						if _seg_hits(wl[i], wl[i + 1], box):
							bad.append(key)
							break
		if OS.get_environment("ANCHOR_DEBUG") != "":
			for dk in ["0/0/0", "8/0/1", "9/0/0"]:
				if Art3.anchor_log.has(dk):
					print("DBG ", dk, " face=", Art3.anchor_log[dk]["face"], " weapon0=", Art3.anchor_log[dk]["weapon"].slice(0, 3))
		var uniq := {}
		for b in bad:
			uniq[b] = true
		print("ANCHOR 檢查 %d 格有臉，武器穿臉 %d：%s" % [Art3.anchor_log.size(), uniq.size(), str(uniq.keys())])
		# 出格檢查：轉身頁每一格最外 1px 不能有不透明像素（被格子切掉）
		var clip: Array = []
		for k3 in nt * 2 * nc:
			var r3: Rect2 = cache._rect(k3)
			var hit := false
			for e in int(r3.size.x):
				for yy in [0, int(r3.size.y) - 1]:
					if tim.get_pixel(int(r3.position.x) + e, int(r3.position.y) + yy).a > 0.1:
						hit = true
				for xx in [int(r3.position.x), int(r3.position.x) + int(r3.size.x) - 1]:
					if tim.get_pixel(xx, int(r3.position.y) + e).a > 0.1:
						hit = true
			if hit:
				clip.append(k3)
		print("CLIP 轉身頁出格 %d 格：%s" % [clip.size(), str(clip)])
	if cache.fid_tex != null:
		cache.fid_tex.get_image().save_png(out + "/fidget.png")   # V1.3.1：每種兵兩隊 × 小動作 4 格＋受擊帽子 1 格
	for wi in cache.wt_pages.size():
		cache.wt_pages[wi].get_image().save_png(out + "/walkturn%d.png" % wi)
	print("EXTRA fidget=%s walkturn=%d" % [str(cache.fid_tex != null), cache.wt_pages.size()])
	# 1.3.0 §5.4：背面走路頁（每種兵一列：藍 4 步相＋紅 4 步相），一次烘 TA_MAX 種、分批
	var bw := Image.create(SC.CELL * SC.WT_PH * 2, SC.CELL * F8.DRAW_TOTAL, false, Image.FORMAT_RGBA8)
	bw.fill(Color("#7d9a58"))
	var done := 0
	var ts: Array = range(F8.DRAW_TOTAL)
	while done < ts.size():
		var batch: Array = ts.slice(done, done + SC.TA_MAX)
		cache.ensure_turn_atk(batch)
		while cache._ta_busy:
			await process_frame
		for t9 in batch:
			if cache.bw_tex.has(t9):
				var bi: Image = cache.bw_tex[t9].get_image()
				bw.blend_rect(bi, Rect2i(0, 0, SC.CELL * SC.WT_PH * 2, SC.CELL), Vector2i(0, t9 * SC.CELL))
		done += batch.size()
	bw.save_png(out + "/backwalk.png")
	print("BACKWALK ok ", cache.bw_tex.size())
	quit()

static func _seg_hits(a: Vector2, b: Vector2, r: Rect2) -> bool:
	for k in 13:
		if r.has_point(a.lerp(b, k / 12.0)):
			return true
	return false
