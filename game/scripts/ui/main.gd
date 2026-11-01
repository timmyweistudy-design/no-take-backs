extends "res://scripts/ui/game_screens.gd"
## 主場景腳本。這一層只放宣傳工具：自動截圖、商店膠囊圖、實機影片模式。


## 商店膠囊圖（N6）：用目前視窗大小構圖——先畫標題帶，再把兩軍放在標題下方對衝，中間有分界線與對射的箭。
## 只有遊戲標題文字（Steam 規定）。手感輪（收尾批）調整：標題帶不壓角色、中央不留白、小尺寸放大標題與角色、兩側留邊。
func _draw_capsule() -> void:
	var vs := get_viewport_rect().size
	var tile := 64.0 * vs.y / 800.0
	for yy in int(vs.y / tile) + 1:
		for xx in int(vs.x / tile) + 1:
			var h := absi((xx * 73856093) ^ (yy * 19349663))
			draw_texture_rect_region(grass, Rect2(xx * tile, yy * tile, tile, tile), Rect2((h % 8) * 32, ((h / 8) % 4) * 32, 32, 32))
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.06, 0.09, 0.16, 0.22))
	var tall := vs.y > vs.x
	var tiny := get_window().size.y < 300   # 畫布邏輯高度固定 800，要看實際視窗大小
	# 標題帶（先畫，角色畫在它下方的區域）
	var big := int(vs.y * (0.12 if tall else (0.30 if tiny else 0.21)))
	var band_h := big * 1.75
	var band_y := vs.y * (0.05 if tall else 0.03)
	draw_rect(Rect2(0, band_y, vs.x, band_h), Color(0.05, 0.06, 0.1, 0.55))
	_text(Vector2(vs.x / 2, band_y + big * 0.05), L.t("title"), big, Color("#ffe8a3"), true, true)
	_text(Vector2(vs.x / 2, band_y + big * 1.12), "No Take-Backs", int(big * (0.42 if tiny else 0.34)), Color(1, 1, 1, 0.97), true, true)
	# 戰場區
	var top := band_y + band_h + vs.y * 0.02
	var bottom := vs.y * 0.97
	var mid := vs.x / 2
	draw_dashed_line(Vector2(mid, top), Vector2(mid, bottom), Color(1, 1, 1, 0.45), maxf(3.0, vs.y * 0.006) * (2.5 if tiny else 1.0), vs.y * 0.02)
	var sc := (bottom - top) / (110.0 if tiny else 260.0)
	if tall:
		sc = minf(sc, vs.x / 380.0)   # 直式：依寬度限制大小，同排兩隻不會擠在一起
	var cols := 3 if tiny else (2 if tall else 3)
	var rows := 1 if tiny else 3
	var margin := maxf(20.0, vs.x * 0.05)
	# 每邊固定 cols×rows 的整齊陣型；弓兵固定在最靠中線的那一欄，箭從弓兵射出
	var layout := [D.SHIELD, D.SWORD, D.ARCHER, D.CAVALRY, D.ASSASSIN, D.ARCHER, D.SWORD, D.SHIELD, D.ARCHER]
	var items: Array = []
	var archers: Array = []
	for team in 2:
		for r in rows:
			for c in cols:
				var t: int = layout[(r * cols + c) % layout.size()]
				if c == cols - 1:
					t = D.ARCHER if r != 1 or tiny else D.CAVALRY
				var span := (mid - margin) * 0.62
				var x := margin + sc * 24.0 + c * span / maxf(1, cols - 1)
				if team == 1:
					x = vs.x - x
				var y := bottom - sc * 6.0 if tiny else top + sc * 62.0 + r * (bottom - top - sc * 72.0) / maxf(1, rows - 1)
				items.append([y, x, t, team])
				if t == D.ARCHER and c == cols - 1 and not tall:   # 只有最靠中線的弓兵放箭；直式太窄就不畫箭
					archers.append(Vector2(x, y))
	items.sort()
	for it in items:
		Art.ring(self, Vector2(it[1], it[0]), it[3], it[2], false, sc)
	for it in items:
		var face := 1.0 if it[3] == 0 else -1.0
		Art.unit(self, Vector2(it[1], it[0]), it[2], it[3], face, 2.0 + it[1] * 0.01, 0.45 if it[2] == D.SWORD else 0.0, 0.0, 1.0, 1.3, sc)
	# 箭：從每個弓兵的弓往中線飛
	for ap: Vector2 in archers:
		var dir := 1.0 if ap.x < mid else -1.0
		var start := ap + Vector2(dir * sc * 28.0, -sc * 22.0)
		var p := Vector2(mid - dir * sc * 18.0, start.y - sc * 8.0)
		var tail := p - (p - start).normalized() * sc * 26.0
		draw_line(start, tail, Color(1, 1, 1, 0.28), sc * 1.5, true)
		draw_line(tail, p, Art.OUT, sc * 3.5, true)
		draw_line(tail, p, Color("#d97706"), sc * 2.0, true)
		var dv := (p - tail).normalized()
		var nv := dv.orthogonal()
		draw_colored_polygon(PackedVector2Array([p + dv * sc * 6.0, p + nv * sc * 3.0, p - nv * sc * 3.0]), Color("#e5e7eb"))
		var tc := Art.team_color(0 if dir > 0 else 1, false)
		draw_colored_polygon(PackedVector2Array([tail, tail - dv * sc * 6.0 + nv * sc * 4.0, tail + dv * sc * 3.0]), tc)
		draw_colored_polygon(PackedVector2Array([tail, tail - dv * sc * 6.0 - nv * sc * 4.0, tail + dv * sc * 3.0]), tc)


func _capture_capsule() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var err := get_viewport().get_texture().get_image().save_png(capsule_path)
	if err != OK:
		printerr("CAPSULE 存檔失敗 ", capsule_path, " err=", err)
		get_tree().quit(1)
		return
	print("CAPSULE ", capsule_path)
	get_tree().quit()


# ───────────────────────── 截圖（驗證用） ─────────────────────────
func _snap(name: String) -> void:
	queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shot_dir.path_join(name))
	print("SHOT ", name)


## 實機影片（N6 預告素材）：用 Godot 錄影模式跑（--write-movie 絕對路徑 --fixed-fps 30），全程自動。
func _run_video() -> void:
	await get_tree().create_timer(2.5).timeout
	difficulty = 1
	_start_mode(Mode.VS_AI)
	var plan := [[D.SHIELD, 5, 3], [D.SHIELD, 5, 5], [D.SWORD, 4, 2], [D.SWORD, 4, 6], [D.SWORD, 4, 4],
		[D.ARCHER, 1, 3], [D.ARCHER, 1, 5], [D.ARCHER, 0, 4], [D.CAVALRY, 3, 0], [D.CAVALRY, 3, 8], [D.ASSASSIN, 2, 4],
			[D.ARCHER, 1, 2], [D.ARCHER, 1, 6], [D.SWORD, 4, 3], [D.SWORD, 4, 5], [D.CAVALRY, 3, 4], [D.ASSASSIN, 2, 2], [D.SHIELD, 5, 4]]
	for s2 in plan:
		selected = s2[0]
		mouse = ORIGIN + Vector2(s2[1] + 0.5, s2[2] + 0.5) * CS
		await get_tree().create_timer(0.35).timeout
		_try_place(Vector2i(s2[1], s2[2]))
	await get_tree().create_timer(1.0).timeout
	var red_pick = null
	for k in 120:
		var r := RandomNumberGenerator.new()
		r.seed = 777 + k
		var cand = AI.build(1, 100, r)["army"]
		if _would_clutch(armies[0], cand):
			red_pick = cand
			break
	last_player_formation = armies[0].units.duplicate(true)
	ai_name = L.t("diff_normal")
	_begin_battle(armies[0].copy(), (red_pick if red_pick != null else AI.build(1, 100, rng)["army"]).copy())
	while state != St.RESULT:
		await get_tree().process_frame
	await get_tree().create_timer(4.0).timeout
	get_tree().quit()


func _would_clutch(a0, a1) -> bool:
	var t = Sim.new(a0.copy(), a1.copy())
	t.fast = true
	var tot := float(t.budget * 1000)
	while not t.finished:
		t.step()
		var p0: float = t.power(0) * 100.0 / tot
		var p1: float = t.power(1) * 100.0 / tot
		if absf(p0 - p1) <= 15.0 and ((p0 <= 30.0 and p1 <= 30.0) or (t.alive_count(0) <= 3 and t.alive_count(1) <= 3)) and not t.finished:
			return true
	return false


func _run_screenshots() -> void:
	await get_tree().process_frame
	for i in 160:
		demo.step()
	await _snap("01_title.png")
	difficulty = 1
	_start_mode(Mode.VS_AI)
	for s in [[D.SHIELD, 5, 3], [D.SHIELD, 5, 5], [D.SWORD, 4, 2], [D.SWORD, 4, 6], [D.SWORD, 4, 4],
			[D.ARCHER, 1, 3], [D.ARCHER, 1, 5], [D.ARCHER, 0, 4], [D.CAVALRY, 3, 0], [D.CAVALRY, 3, 8], [D.ASSASSIN, 2, 4],
			[D.ARCHER, 1, 2], [D.ARCHER, 1, 6], [D.SWORD, 4, 3], [D.SWORD, 4, 5], [D.CAVALRY, 3, 4], [D.ASSASSIN, 2, 2], [D.SHIELD, 5, 4]]:
		armies[0].place(s[0], s[1], s[2])
	selected = D.ARCHER
	mouse = ORIGIN + Vector2(2.5, 6.5) * CS
	await _snap("02_place.png")
	# 找一個會出現「最後時刻」的對手，截圖才拍得到
	var red_pick = null
	for k in 120:
		var r := RandomNumberGenerator.new()
		r.seed = 777 + k
		var cand = AI.build(1, 100, r)["army"]
		if _would_clutch(armies[0], cand):
			red_pick = cand
			break
	if red_pick != null:
		last_player_formation = armies[0].units.duplicate(true)
		ai_name = L.t("diff_normal")
		_begin_battle(armies[0].copy(), red_pick.copy())
	else:
		_on_start()
	for i in 150:
		_sim_step(true)
	for f in fx:
		f["t"] = 0.0
	await _snap("03_battle.png")
	# 技能特效樣品（第二輪方案 R4）：在戰場上方一排，每種特效停在 35% 的時刻
	var saved_fx := fx.duplicate()
	fx.clear()
	var y0 := 150.0
	var kinds := [
		{"kind": "aim", "a": Vector2(170, y0), "b": Vector2(250, y0 + 6), "dur": 0.32},
		{"kind": "hide", "p": Vector2(320, y0), "dir": 1.0, "dur": 0.4},
		{"kind": "trip", "p": Vector2(420, y0 + 20), "dur": 0.5},
		{"kind": "shard", "p": Vector2(520, y0), "dur": 0.5},
		{"kind": "vslash", "p": Vector2(620, y0), "dir": 1.0, "dur": 0.3},
		{"kind": "flash", "p": Vector2(620, y0), "c": Color("#c77dff"), "dur": 0.25},
		{"kind": "taunt", "p": Vector2(730, y0 + 20), "dur": 0.6},
		{"kind": "bang", "p": Vector2(830, y0), "dur": 0.7},
		{"kind": "puff", "p": Vector2(930, y0), "dur": 0.45},
		{"kind": "ripple", "p": Vector2(1030, y0), "c": ACCENT, "dur": 0.35},
	]
	for f in kinds:
		f["t"] = f["dur"] * 0.35
		fx.append(f)
	var stunned = null
	for u in sim.units:
		if u.alive and u.type == D.CAVALRY and u.stun == 0:
			stunned = u
			u.stun = 10
			break
	freeze_fx = true
	await _snap("12_fx.png")
	freeze_fx = false
	if stunned != null:
		stunned.stun = 0   # 只是為了截圖，還原，不影響接下來的模擬
	fx = saved_fx
	while not view.finished and not slow_used:
		_sim_step(true)
		_check_clutch()
	if slow_used and not view.finished:
		for k in 120:
			_frame_alive(0.1)
			zoom = lerpf(zoom, zoom_target, 0.3)
		await _snap("04_clutch.png")
	while not view.finished:
		_sim_step(false)
	zoom = 1.0
	_finish_battle()
	await _snap("05_result.png")
	puzzle_id = "p1"
	_start_mode(Mode.PUZZLE)
	selected = D.CAVALRY
	mouse = ORIGIN + Vector2(3.5, 2.5) * CS
	await _snap("06_puzzle.png")
	duel_rule = "snake5"
	_start_mode(Mode.DUEL)
	tp.place(D.SHIELD, 5, 4)
	tp.place(D.SWORD, 5, 3)
	tp.place(D.SWORD, 5, 5)
	tp.end_turn()
	tp.place(D.CAVALRY, 12, 0)
	tp.place(D.ARCHER, 14, 4)
	selected = D.SHIELD
	mouse = ORIGIN + Vector2(4.5, 1.5) * CS
	await _snap("07_duel.png")
	_go_title()
	overlay = "settings"
	await _snap("08_settings.png")
	overlay = "puzzles"
	Save.data["tutorial"] = 3
	await _snap("09_puzzles.png")
	Save.data["unit_wins"] = {"3": 5}
	_open_codex(D.CAVALRY)
	cx_skill = 0
	_cx_restart()
	for i in 46:
		_codex_tick(0.05)
	await _snap("10_codex.png")
	_open_codex(D.ASSASSIN)
	_cx_pick_skill(1)
	for i in 70:
		_codex_tick(0.05)
	await _snap("11_codex_locked.png")
	get_tree().quit()


## 繪圖效能量測（第二輪方案 R2、H）：48 隻（24 對 24）跑約 6 秒，記錄每一幀的 _draw、_process 與 GPU 時間。
## 輸出 JSON：p50／p95／最大值（毫秒）。用法：<exe> --path game --resolution 1280x800 -- --perf=<輸出 json 絕對路徑>
func _run_perf() -> void:
	await get_tree().process_frame
	# 等精靈圖快取烘焙完才開始量，否則前幾幀是退回的直接繪製（Codex R1 審查 #6）
	var waited := 0
	while sprites != null and not sprites.is_ready(cbm()) and waited < 120:
		await get_tree().process_frame
		waited += 1
	var vp := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var a0 := Army.new(0, 100)
	var a1 := Army.new(1, 100)
	var spec := [D.SHIELD, D.SWORD, D.ARCHER, D.ARCHER, D.SWORD, D.ARCHER]
	for r in 9:
		for c in 6:
			if a0.count() < 24:
				var t: int = spec[(r + c) % spec.size()]
				if D.cost(t) <= a0.left():
					a0.place(t, 5 - c, r)
				elif a0.left() >= 4:
					a0.place(D.ARCHER, 5 - c, r)
	a1 = a0.mirrored()
	mode = Mode.VS_AI
	_begin_battle(a0, a1)
	var draw: Array = []
	var proc: Array = []
	var gpu: Array = []
	var frame: Array = []
	var units: Array = []
	var parts := {"field": [], "units": [], "fx": []}
	var last := Time.get_ticks_usec()
	for i in 360:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		frame.append((now - last) / 1000.0)
		last = now
		draw.append(perf_draw_us / 1000.0)
		proc.append(perf_proc_us / 1000.0)
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
		for k in parts:
			parts[k].append(perf_parts.get(k, 0) / 1000.0)
		units.append(sim.alive_count(0) + sim.alive_count(1) if sim != null else 0)
		if state != St.BATTLE:
			break
	var out := {"frames": draw.size(), "units_start": units[0] if units.size() > 0 else 0, "units_end": units[-1] if units.size() > 0 else 0,
		"draw_ms": _pstats(draw), "process_ms": _pstats(proc), "gpu_ms": _pstats(gpu), "frame_ms": _pstats(frame),
		"field_ms": _pstats(parts["field"]), "units_ms": _pstats(parts["units"]), "fx_ms": _pstats(parts["fx"]),
		"note": "frame_ms 受垂直同步限制（約 16.7）；看 draw＋process＋gpu 才是實際成本"}
	var f := FileAccess.open(perf_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "  "))
	f.close()
	print("PERF ", JSON.stringify(out))
	get_tree().quit()

func _pstats(a: Array) -> Dictionary:
	var b := a.duplicate()
	b.sort()
	if b.is_empty():
		return {}
	return {"p50": snappedf(b[b.size() / 2], 0.01), "p95": snappedf(b[int(b.size() * 0.95)], 0.01), "max": snappedf(b[-1], 0.01)}
