extends SceneTree
## 角色圖集檢查（第七輪 C0）：要真的繪圖，不能 headless。
## "<Godot win exe>" --path <game> --script res://tools/atlas_check.gd -- --out=<輸出資料夾（Windows 路徑）>
## 產出：contact.png（全部兵種、兩隊的待機＋攻擊姿勢）、silhouette.png（塗黑剪影）、gray.png（灰階）、atlas.json：
##  clipped：有幾格碰到格子邊界（超框）；team_ratio：隊伍色占不透明像素比例；iou_max：和其他兵種的剪影最大重疊；
##  繪圖基準 cell 160px。ok＝沒有超框。
const SC = preload("res://scripts/ui/sprite_cache.gd")
const Art = preload("res://scripts/ui/art.gd")
const D = preload("res://scripts/core/unit_defs.gd")
var out := "."
var cache
var cb_frames := 0

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	cache = SC.new()
	root.add_child(cache)
	_run.call_deferred()

func _rect(i: int) -> Rect2i:
	return Rect2i((i % 16) * SC.CELL, (i / 16) * SC.CELL, SC.CELL, SC.CELL)

func _run() -> void:
	await cache.build(false)
	var img: Image = cache.tex.get_image()
	var per: int = SC.FRAMES_PER
	var res := {"types": [], "ok": true}
	var masks := []
	var contact := Image.create(SC.CELL * 6, SC.CELL * D.COUNT, false, Image.FORMAT_RGBA8)
	var sil := Image.create(SC.CELL * D.COUNT, SC.CELL, false, Image.FORMAT_RGBA8)
	var gray := Image.create(SC.CELL * 2, SC.CELL * D.COUNT, false, Image.FORMAT_RGBA8)
	contact.fill(Color("#5c7a3a"))
	sil.fill(Color.WHITE)
	gray.fill(Color("#777777"))
	for ty in D.COUNT:
		var clipped := 0
		for tm in 2:
			for f in per:
				var r := _rect((ty * 2 + tm) * per + f)
				for k in SC.CELL:
					if img.get_pixelv(r.position + Vector2i(k, 0)).a > 0.2 or img.get_pixelv(r.position + Vector2i(k, SC.CELL - 1)).a > 0.2 or img.get_pixelv(r.position + Vector2i(0, k)).a > 0.2 or img.get_pixelv(r.position + Vector2i(SC.CELL - 1, k)).a > 0.2:
						clipped += 1
						break
		var ratio := []
		for tm2 in 2:
			var tc: Color = Art.team_color(tm2)
			var r2 := _rect((ty * 2 + tm2) * per)
			var opaque := 0
			var team := 0
			for y in SC.CELL:
				for x in SC.CELL:
					var c := img.get_pixelv(r2.position + Vector2i(x, y))
					if c.a < 0.5:
						continue
					opaque += 1
					var dh := absf(c.h - tc.h)
					dh = minf(dh, 1.0 - dh)
					if dh < 0.05 and c.s > 0.3 and c.v > 0.3:
						team += 1
			ratio.append(snappedf(float(team) / maxf(1.0, opaque), 0.001))
		var mask := PackedByteArray()
		mask.resize(SC.CELL * SC.CELL)
		var r3 := _rect(ty * 2 * per)
		for y2 in SC.CELL:
			for x2 in SC.CELL:
				var on: bool = img.get_pixelv(r3.position + Vector2i(x2, y2)).a > 0.5
				mask[y2 * SC.CELL + x2] = 1 if on else 0
				if on:
					sil.set_pixel(ty * SC.CELL + x2, y2, Color.BLACK)
		masks.append(mask)
		for col in 6:
			var tmc: int = col % 2
			var fr: int = [0, 0, 8 + 3, 8 + 3, 16 + 3, 16 + 3][col]
			contact.blend_rect(img, _rect((ty * 2 + tmc) * per + fr), Vector2i(col * SC.CELL, ty * SC.CELL))
		for tm3 in 2:
			var r4 := _rect((ty * 2 + tm3) * per)
			for y3 in SC.CELL:
				for x3 in SC.CELL:
					var c3 := img.get_pixelv(r4.position + Vector2i(x3, y3))
					if c3.a > 0.5:
						gray.set_pixel(tm3 * SC.CELL + x3, ty * SC.CELL + y3, Color(c3.get_luminance(), c3.get_luminance(), c3.get_luminance()))
		res["types"].append({"type": ty, "name": D.NAMES[ty], "clipped": clipped, "team_ratio": ratio})
		if clipped > 0:
			res["ok"] = false
	for a in D.COUNT:
		var best := 0.0
		var bi := -1
		for b in D.COUNT:
			if a == b:
				continue
			var i := 0
			var u := 0
			for k2 in masks[a].size():
				if masks[a][k2] == 1 and masks[b][k2] == 1:
					i += 1
				if masks[a][k2] == 1 or masks[b][k2] == 1:
					u += 1
			var v := float(i) / maxf(1.0, u)
			if v > best:
				best = v
				bi = b
		res["types"][a]["iou_max"] = snappedf(best, 0.001)
		res["types"][a]["iou_with"] = D.NAMES[bi]
	contact.save_png(out.path_join("contact.png"))
	sil.save_png(out.path_join("silhouette.png"))
	gray.save_png(out.path_join("gray.png"))
	var f2 := FileAccess.open(out.path_join("atlas.json"), FileAccess.WRITE)
	f2.store_string(JSON.stringify(res, " "))
	f2.close()
	print("ATLAS ", JSON.stringify({"ok": res["ok"]}))
	quit(0 if res["ok"] else 1)
