extends "res://scripts/ui/game_screens.gd"
## 主場景腳本。這一層只放宣傳工具：自動截圖、商店膠囊圖、實機影片模式。


## 商店膠囊圖（N6）：用目前視窗大小構圖——先畫標題帶，再把兩軍放在標題下方對衝，中間有分界線與對射的箭。
## 只有遊戲標題文字（Steam 規定）。手感輪（收尾批）調整：標題帶不壓角色、中央不留白、小尺寸放大標題與角色、兩側留邊。
func _draw_capsule() -> void:
	# 膠囊圖（第三輪 M1）：左藍右紅 15° 斜切＋中央裂縫與對撞星芒、兩邊各 3 隻放大的角色、標題金邊立體投影。
	var vs := get_viewport_rect().size
	var tall := vs.y > vs.x
	var tiny := get_window().size.y < 300
	var blue := Color("#1b3b6f")
	var red := Color("#6f1d2b")
	var mid := vs.x / 2
	var slant := tan(deg_to_rad(15.0)) * vs.y / 2
	draw_rect(Rect2(Vector2.ZERO, vs), red)
	draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(mid + slant, 0), Vector2(mid - slant, vs.y), Vector2(0, vs.y)]), blue)
	# 速度線
	for k in 14:
		var yy := vs.y * (0.08 + k * 0.066)
		var ln := vs.x * (0.12 + 0.06 * (k % 3))
		draw_line(Vector2(vs.x * 0.02, yy), Vector2(vs.x * 0.02 + ln, yy), Color(1, 1, 1, 0.07), maxf(2.0, vs.y * 0.006), true)
		draw_line(Vector2(vs.x * 0.98 - ln, yy + vs.y * 0.03), Vector2(vs.x * 0.98, yy + vs.y * 0.03), Color(1, 1, 1, 0.07), maxf(2.0, vs.y * 0.006), true)
	# 中央裂縫（鋸齒）
	var crack := PackedVector2Array()
	for k in 9:
		var t := k / 8.0
		var x := lerpf(mid + slant, mid - slant, t) + (8.0 if k % 2 == 0 else -8.0) * vs.y / 430.0
		crack.append(Vector2(x, vs.y * t))
	draw_polyline(crack, Color(1, 0.95, 0.75, 0.9), maxf(3.0, vs.y * 0.012), true)
	# 標題帶
	var big := int(vs.y * (0.11 if tall else (0.30 if tiny else 0.19)))
	var band_y := vs.y * (0.04 if tall else 0.03)
	var tt: String = L.t("title")
	var tw := font_bold.get_string_size(tt, HORIZONTAL_ALIGNMENT_LEFT, -1, big).x
	var tp := Vector2(mid - tw / 2, band_y + big * 0.9)
	var dep := maxf(3.0, big * 0.06)
	for d in 4:
		draw_string(font_bold, tp + Vector2(1, 1) * dep * (d + 1) / 4.0, tt, HORIZONTAL_ALIGNMENT_LEFT, -1, big, Color(0.12, 0.05, 0.02, 0.95))
	draw_string_outline(font_bold, tp, tt, HORIZONTAL_ALIGNMENT_LEFT, -1, big, int(maxf(6.0, big * 0.12)), Color("#3a2205"))
	draw_string_outline(font_bold, tp, tt, HORIZONTAL_ALIGNMENT_LEFT, -1, big, int(maxf(3.0, big * 0.06)), Color("#d4a017"))
	draw_string(font_bold, tp, tt, HORIZONTAL_ALIGNMENT_LEFT, -1, big, Color("#ffe8a3"))
	var sub := int(big * (0.42 if tiny else 0.30))
	_text(Vector2(mid, band_y + big * 1.12), "No Take-Backs", sub, Color(1, 1, 1, 0.97), true, true)
	# 角色：兩邊各 3 隻，前排最大、最靠中線
	var top := band_y + big * 1.12 + sub * 1.4
	var bottom := vs.y * 0.97
	var sc := (bottom - top) / (70.0 if tiny else 95.0)
	if tall:
		sc = minf(sc, vs.x / 118.0)
	var left := [[D.ARCHER, 0.13, 0.80], [D.CAVALRY, 0.27, 0.92], [D.SWORD, 0.40, 1.0]]
	var right := [[D.ASSASSIN, 0.87, 0.80], [D.SHIELD, 0.73, 0.92], [D.SWORD, 0.60, 1.0]]
	if tall:
		# 直式：每邊兩隻、放大，後排的往上放，填滿中段
		left = [[D.CAVALRY, 0.17, 0.78], [D.SWORD, 0.31, 1.0]]
		right = [[D.ASSASSIN, 0.83, 0.78], [D.SWORD, 0.69, 1.0]]
	if tiny:
		left = [[D.CAVALRY, 0.22, 0.95], [D.SWORD, 0.40, 1.0]]
		right = [[D.SHIELD, 0.78, 0.95], [D.SWORD, 0.60, 1.0]]
	var items: Array = []
	for it in left:
		items.append([it, 0])
	for it in right:
		items.append([it, 1])
	for e in items:
		var it: Array = e[0]
		var team: int = e[1]
		var k: float = it[2]
		var s2 := sc * k
		var p := Vector2(vs.x * float(it[1]), bottom - (1.0 - k) * (bottom - top) * 0.55)
		var face := 1.0 if team == 0 else -1.0
		Art.ring(self, p, team, it[0], false, s2)
		var mood := Art.M_SPARKLE if it[0] == D.CAVALRY else Art.M_BROWS
		var at := 0.42 if k >= 0.99 else (0.25 if it[0] == D.ARCHER else 0.0)
		Art.unit(self, p, it[0], team, face, 0.0, at, 0.0, 1.0, 1.3, s2, false, mood, 0.2 if it[0] == D.CAVALRY else 0.0)
	# 中央對撞星芒
	var cc := Vector2(mid, bottom - (22.0 if tall else 30.0) * sc)   # 星芒在前排兩隻的武器交會處
	var r0 := minf(45.0 * vs.y / 430.0, (11.0 if tall else 16.0) * sc) * (0.7 if tiny else 1.0)
	for layer in 2:
		var pts := PackedVector2Array()
		var rr := r0 * (1.0 - layer * 0.45)
		for i in 24:
			var an := i * TAU / 24.0
			pts.append(cc + Vector2(cos(an), sin(an)) * (rr if i % 2 == 0 else rr * 0.42))
		draw_colored_polygon(pts, Color(1, 0.9, 0.5, 0.95) if layer == 0 else Color.WHITE)
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
## 版面檢查（第三輪 T4）：這張截圖的介面文字有沒有越界、小於 9px（Steam Deck 下限）、彼此重疊超過 15%。
func _layout_report(name: String) -> void:
	var bad: Array = []
	var sizes: Array = []
	for t in probe_texts:
		var r: Rect2 = t["r"]
		sizes.append(int(t["size"]))
		if r.position.x < -2 or r.end.x > 1282 or r.position.y < -2 or r.end.y > 802:
			bad.append({"type": "越界", "s": t["s"], "r": str(r)})
		if int(t["size"]) < 9:
			bad.append({"type": "太小", "s": t["s"], "size": t["size"]})
	for a in probe_texts.size():
		for b in range(a + 1, probe_texts.size()):
			var ra: Rect2 = probe_texts[a]["r"]
			var rb: Rect2 = probe_texts[b]["r"]
			var x := ra.intersection(rb)
			if x.has_area() and probe_texts[a]["s"] != probe_texts[b]["s"]:
				var ratio := x.get_area() / maxf(1.0, minf(ra.get_area(), rb.get_area()))
				if ratio > 0.15:
					bad.append({"type": "重疊", "a": probe_texts[a]["s"], "b": probe_texts[b]["s"], "ratio": snappedf(ratio, 0.01)})
	sizes.sort()
	var line := JSON.stringify({"shot": name, "lang": L.lang, "scale": int(Save.s("text_scale")), "texts": probe_texts.size(),
		"median_size": sizes[sizes.size() / 2] if not sizes.is_empty() else 0, "min_size": sizes[0] if not sizes.is_empty() else 0, "violations": bad})
	var f := FileAccess.open(shot_dir.path_join("layout.jsonl"), FileAccess.READ_WRITE if FileAccess.file_exists(shot_dir.path_join("layout.jsonl")) else FileAccess.WRITE)
	f.seek_end()
	f.store_line(line)
	f.close()


func _snap(name: String) -> void:
	queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shot_dir.path_join(name))
	print("SHOT ", name)
	if layout_probe:
		_layout_report(name)


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
	for u in view.units:   # 只改畫面快照，不碰模擬（Codex R3 第 2 輪建議）
		if u.alive and u.type == D.CAVALRY and u.stun == 0:
			stunned = u
			u.stun = 10
			break
	freeze_fx = true
	await _snap("12_fx.png")
	anim_gallery = true
	await _snap("13_poses.png")
	anim_gallery = false
	Save.settings["colorblind"] = true
	_rebuild_sprites()
	for i in 4:
		await get_tree().process_frame
	await _snap("14_colorblind.png")
	Save.settings["colorblind"] = false
	_rebuild_sprites()
	for i in 4:
		await get_tree().process_frame
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
	_scroll_by("left", 9999.0)   # 捲到底（第三輪 U1）
	await _snap("10b_codex_scrolled.png")
	_open_codex(D.ASSASSIN)
	_cx_pick_skill(1)
	for i in 70:
		_codex_tick(0.05)
	await _snap("11_codex_locked.png")
	overlay = ""
	# 覆盤與重播控制（第三輪 S5）：用 05 那一場
	mode = Mode.VS_AI
	_open_review()
	var u0: Dictionary = rv_army.units[0]
	rv_sel = Vector2i(int(u0["col"]), int(u0["row"]))
	_rv_set_type(D.SHIELD if int(u0["type"]) != D.SHIELD else D.SWORD)
	_rv_recalc()
	await _snap("16_review.png")
	overlay = ""
	_begin_battle(last_armies[0].copy(), last_armies[1].copy(), "replay")
	for i in 260:
		_sim_step(true)
	for f in fx:
		f["t"] = 0.0
	await _snap("15_replay.png")
	get_tree().quit()


## 繪圖效能量測（第二輪 R2、第三輪 T3）：
## ・啟動時間（引擎啟動到量測開始）、色盲切換的圖集重建時間
## ・48 隻（每邊 24，量測專用的 160 金預算，五兵種混合）打完整場，展示速度 4 倍（約 25 秒內走到狂熱與結束）
## ・每幀的 draw／process／GPU／整幀時間：全場、非狂熱、狂熱分開統計，含 p99；記錄硬體、引擎版本、commit（--perf-commit=）
## 用法：<exe> --path game --resolution 1280x800 -- --perf=<輸出 json 絕對路徑> [--perf-commit=<hash>]
func _run_perf() -> void:
	var boot_ms := Time.get_ticks_msec()
	await get_tree().process_frame
	var waited := 0
	while sprites != null and not sprites.is_ready(cbm()) and waited < 240:
		await get_tree().process_frame
		waited += 1
	var ready_ms := Time.get_ticks_msec()
	# 色盲切換：圖集重建要多久
	Save.settings["colorblind"] = true
	var t_cb := Time.get_ticks_msec()
	_rebuild_sprites()
	waited = 0
	while sprites != null and not sprites.is_ready(true) and waited < 240:
		await get_tree().process_frame
		waited += 1
	var cb_ms := Time.get_ticks_msec() - t_cb
	Save.settings["colorblind"] = false
	_rebuild_sprites()
	waited = 0
	while sprites != null and not sprites.is_ready(false) and waited < 240:
		await get_tree().process_frame
		waited += 1
	var vp := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var a0 := Army.new(0, 160)
	var spec := [D.SHIELD, D.SWORD, D.ARCHER, D.CAVALRY, D.ASSASSIN, D.ARCHER, D.SWORD, D.ARCHER]
	for r in 9:
		for c in 6:
			if a0.count() < 24:
				var t: int = spec[(r * 6 + c) % spec.size()]
				if D.cost(t) <= a0.left():
					a0.place(t, 5 - c, r)
	var a1 = a0.mirrored()
	mode = Mode.VS_AI
	_begin_battle(a0, a1, "replay")   # 量測不寫進度
	speed = 4.0
	var rows: Array = []   # [draw, proc, gpu, frame, frenzy]
	var units_start: int = view.alive_count(0) + view.alive_count(1)
	var last := Time.get_ticks_usec()
	var guard := 0
	while state == St.BATTLE and guard < 40000:
		guard += 1
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		rows.append([perf_draw_us / 1000.0, perf_proc_us / 1000.0, RenderingServer.viewport_get_measured_render_time_gpu(vp), (now - last) / 1000.0, view.frenzy])
		last = now
	var pick := func(col: int, which: int) -> Array:
		var o: Array = []
		for r2 in rows:
			if which == 0 or (which == 1 and not r2[4]) or (which == 2 and r2[4]):
				o.append(r2[col])
		return o
	var sect := func(which: int) -> Dictionary:
		return {"frames": pick.call(0, which).size(), "draw_ms": _pstats(pick.call(0, which)), "process_ms": _pstats(pick.call(1, which)),
			"gpu_ms": _pstats(pick.call(2, which)), "frame_ms": _pstats(pick.call(3, which))}
	var commit := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--perf-commit="):
			commit = a.substr(14)
	var out := {
		"hardware": {"cpu": OS.get_processor_name(), "cores": OS.get_processor_count(), "gpu": RenderingServer.get_video_adapter_name(),
			"os": OS.get_name(), "engine": Engine.get_version_info()["string"], "resolution": str(get_viewport().get_visible_rect().size)},
		"commit": commit, "boot_ms": ready_ms, "boot_to_measure_ms": boot_ms, "colorblind_rebuild_ms": cb_ms,
		"units_start": units_start, "display_speed": 4.0, "battle_ticks": sim.tick, "reached_frenzy": sim.tick >= Sim.FRENZY_TICK,
		"all": sect.call(0), "normal": sect.call(1), "frenzy": sect.call(2),
		"note": "frame_ms 受垂直同步限制（約 16.7）；實際成本看 draw＋process＋gpu。展示速度 4 倍時每幀處理的模擬 tick 比正常多，屬於偏嚴的量法"}
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
	return {"p50": snappedf(b[b.size() / 2], 0.01), "p95": snappedf(b[int(b.size() * 0.95)], 0.01), "p99": snappedf(b[mini(b.size() - 1, int(b.size() * 0.99))], 0.01), "max": snappedf(b[-1], 0.01)}


## 動作／表情樣品（R5 截圖驗證用）：每個兵種一列：待機、前搖、揮擊、後搖、受擊、狂熱、專屬（衝鋒／潛行／頂住）、勝利。
var anim_gallery := false

func _draw_inner() -> void:
	super._draw_inner()
	if not anim_gallery:
		return
	draw_rect(Rect2(60, 90, 1160, 640), Color(0.12, 0.16, 0.12, 0.97))
	var cols := ["待機", "前搖", "揮擊", "後搖", "受擊", "狂熱", "專屬", "勝利", "交替招式"]
	for c in cols.size():
		_text(Vector2(170 + c * 122, 100), cols[c], ts(16), Color.WHITE, true)
	for t in D.COUNT:
		var y := 220.0 + t * 112.0
		for c in cols.size():
			var p := Vector2(170 + c * 122, y)
			var at: float = [0.0, 0.25, 0.42, 0.75, 0.0, 0.0, 0.0, Art.ATK_WINDUP, 0.52][c]
			var mood: int = [0, 0, 0, 0, Art.M_HURT, Art.M_BROWS, 0, 0, 0][c]
			var lean := 0.0
			var crouch := 1.0
			var alpha := 1.0
			var walk := 0.0
			if c == 7:   # 勝利：站直、武器高舉（和前搖分開）
				lean = Art.LEAN_BACK
				crouch = 1.06
			if c == 6:
				match t:
					D.CAVALRY:
						mood = Art.M_SPARKLE; lean = 0.26; walk = 1.0
					D.ASSASSIN:
						mood = Art.M_HOOD; crouch = 0.9; alpha = 0.45
					D.SHIELD:
						mood = Art.M_BRACE
			if c == 5:   # 狂熱氣場
				draw_arc(p + Vector2(0, -36), 26.0, 0, TAU, 24, Color(1.0, 0.33, 0.2, 0.6), 3.0, true)
			_ring(p, 0, t, 1.6)
			_unit(p, t, 0, 1.0, walk, at, 0.0, alpha, 1.0, 1.6, mood, lean, crouch, 1 if c == 8 else 0)
			if c == 2 or c == 8:   # 揮擊殘影（依兵種，實際只有 0.12 秒）
				_draw_smear(p, t, 0, 1.0, 0.45, 1.0, 1 if c == 8 else 0, 1.6)
