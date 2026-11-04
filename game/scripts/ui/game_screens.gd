extends "res://scripts/ui/screens/game_menus.gd"
## 其他層在同資料夾（V9 P1 拆檔）

func _ready() -> void:
	on_battle_finished = _finish_battle
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot=") or a.begins_with("--steam-test=") or a.begins_with("--perf=") or a == "--boot-check" or a.begins_with("--mem-check="):
			Save.prefix = "shot_"   # 不讀、不寫玩家真正的存檔
		elif a == "--self-check":
			Save.prefix = "smoke_"
	Save.load_all()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--steam-test="):
			var aid := int(a.substr(13))
			SteamApi.init(aid, false)
			var res: Dictionary = SteamApi.self_test(aid)
			print("STEAMTEST ", JSON.stringify(res))
			get_tree().quit(0 if res["ok"] else 1)
			return
	for a2 in OS.get_cmdline_user_args():   # 截圖驗證用：--shot-lang=en、--shot-text=150（只改這次記憶體中的設定）
		if a2.begins_with("--shot-lang="):
			Save.settings["lang"] = a2.substr(12)
		elif a2.begins_with("--shot-text="):
			Save.settings["text_scale"] = int(a2.substr(12))
		elif a2 == "--layout-check":
			layout_probe = true
	L.lang = Save.s("lang")
	duel_rule = Save.s("duel_rule")
	speed = float(Save.s("speed"))
	var _ua := OS.get_cmdline_user_args()
	var _special := "--video" in _ua
	for x in _ua:
		if x.begins_with("--perf=") or x.begins_with("--mem-check="):
			_special = true
	for x in _ua:
		if x.begins_with("--capsule="):
			_special = true
	if Save.prefix == "" and not _special:   # 截圖／影片／膠囊模式完全不碰 Steam
		SteamApi.init()
	_load_fonts()
	sfx = SfxScript.new()
	add_child(sfx)
	sprites = SpriteCache.new()
	add_child(sprites)
	if capsule_path == "":
		_rebuild_sprites.call_deferred()
	sfx.set_volumes(int(Save.s("sfx")), int(Save.s("music")))
	grass = load("res://art/cainos/TX_Tileset_Grass.png")
	for i in 9:
		var tex = load("res://art/cainos/plant_%02d.png" % i)
		if tex:
			plants.append(tex)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot_dir = a.substr(7)
		elif a.begins_with("--capsule="):
			capsule_path = a.substr(10)
		elif a == "--video":
			video_mode = true
		elif a.begins_with("--perf="):
			perf_path = a.substr(7)
	if "--boot-check" in OS.get_cmdline_user_args():
		_boot_check.call_deferred()
	if "--self-check" in OS.get_cmdline_user_args():
		_self_check.call_deferred()
	if capsule_path != "":
		get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		return   # 膠囊圖由 main 接手
	_apply_fullscreen()
	rng.seed = Time.get_ticks_usec() if (shot_dir == "" and not video_mode) else 12345
	if video_mode:
		Save.prefix = "shot_"
		Save.load_all()
	_go_title()   # 截圖、影片、效能量測由 main 接手（S8）



## 反制庫的陣型只能用這場開放的兵種（第四輪：不會拿你還沒解鎖的兵打你）。
func _types_ok(a: Army) -> bool:
	for u in a.units:
		if int(u["type"]) >= _ntypes():
			return false
	return true



func _keys_input(ev: InputEvent) -> bool:
	if keys_capture == "":
		return false
	var part := keys_capture.split(":")
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.keycode != KEY_ESCAPE and part[0] == "kb":
			if not Keymap.can_bind_key(ev.keycode):
				_toast(L.t("keys_reserved"), true)
				return true
			Save.settings["keys"] = Keymap.rebind(Keymap.ACTIONS, Save.s("keys"), part[1], ev.keycode)
			Save.save_settings()
		keys_capture = ""
		return true
	if ev is InputEventJoypadButton and ev.pressed and part[0] == "pad":
		if not Keymap.can_bind_pad(ev.button_index):
			_toast(L.t("keys_reserved"), true)
			return true
		Save.settings["pad"] = Keymap.rebind(Keymap.PAD_ACTIONS, Save.s("pad"), part[1], ev.button_index)
		Save.save_settings()
		keys_capture = ""
		return true
	return ev is InputEventKey or ev is InputEventJoypadButton



func _input(ev: InputEvent) -> void:
	if _keys_input(ev):
		return
	if ev is InputEventScreenTouch or ev is InputEventScreenDrag:
		fp_touch = true   # 第六輪：觸控時預覽畫在手指上方
		return
	if ev is InputEventMouseMotion:
		mouse = ev.position
		pad_mode = false
		if ev.device != InputEvent.DEVICE_ID_EMULATION:
			fp_touch = false
		hover_card = _card_at(mouse)
		_enqueue("paint", mouse)   # 一律排入，由執行端判斷有沒有在塗兵（同一幀按下再拖過也不漏格，Codex S3）
		return
	if ev is InputEventMouseButton:
		mouse = ev.position
		if overlay == "codex" and ev.pressed and (ev.button_index == MOUSE_BUTTON_WHEEL_UP or ev.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			_scroll_at(mouse, -48.0 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else 48.0)   # 圖鑑捲動（第三輪 U1）
			return
		_enqueue("mb", {"i": ev.button_index, "pressed": ev.pressed, "pos": ev.position})
		return
	if ev is InputEventKey and ev.pressed:
		if not ev.echo or ev.keycode in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
			var dk: int = Keymap.key_to_default(Save.s("keys"), ev.keycode)
			if dk >= 0:
				_enqueue("key", dk)
		return
	if ev is InputEventJoypadButton:
		var db: int = Keymap.pad_to_default(Save.s("pad"), ev.button_index)
		if db < 0:
			return
		ev = ev.duplicate()
		ev.button_index = db
	if ev is InputEventJoypadButton and _is_free() and overlay != "" and not ev.pressed and ev.button_index in [JOY_BUTTON_A, JOY_BUTTON_X]:
		_fp_abort_drag()   # 覆蓋層開著時放開 A／X：清掉拖曳狀態（Antigravity 實作第 1 輪 #2）
	if ev is InputEventJoypadButton and _is_free() and overlay == "" and ev.button_index in [JOY_BUTTON_A, JOY_BUTTON_X, JOY_BUTTON_B, JOY_BUTTON_Y, JOY_BUTTON_LEFT_STICK, JOY_BUTTON_RIGHT_STICK, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
		pad_mode = true
		_enqueue("padbtn", {"b": ev.button_index, "pressed": ev.pressed})   # 第六輪：自由排兵要知道按下與放開
		return
	if ev is InputEventJoypadButton and ev.pressed:
		pad_mode = true
		var map := {JOY_BUTTON_DPAD_UP: KEY_UP, JOY_BUTTON_DPAD_DOWN: KEY_DOWN, JOY_BUTTON_DPAD_LEFT: KEY_LEFT,
			JOY_BUTTON_DPAD_RIGHT: KEY_RIGHT, JOY_BUTTON_A: KEY_ENTER, JOY_BUTTON_B: KEY_ESCAPE, JOY_BUTTON_X: KEY_BACKSPACE,
			JOY_BUTTON_START: KEY_SPACE, JOY_BUTTON_Y: KEY_TAB, JOY_BUTTON_LEFT_SHOULDER: KEY_Q, JOY_BUTTON_RIGHT_SHOULDER: KEY_E,
			JOY_BUTTON_BACK: KEY_F1}
		if map.has(ev.button_index):
			_enqueue("key", map[ev.button_index])
		return
	if ev is InputEventJoypadMotion and ev.axis == JOY_AXIS_RIGHT_Y and overlay == "codex" and absf(ev.axis_value) > 0.3:
		pad_mode = true
		_scroll_by("left", ev.axis_value * 24.0)   # 右搖桿捲圖鑑左欄
		return
	if ev is InputEventJoypadMotion and (ev.axis == JOY_AXIS_LEFT_X or ev.axis == JOY_AXIS_LEFT_Y):
		# 左搖桿：只記下狀態，由 _stick_repeat 依固定節奏送方向鍵（Codex S1 #6：原本每個抖動事件都會送一次）
		stick[ev.axis] = ev.axis_value
		if absf(ev.axis_value) > 0.6:
			pad_mode = true



## 塗兵（佇列命令）：按住拖過格子連續擺。
func _paint_cmd(p: Vector2) -> void:
	if _is_free():
		if overlay == "":
			_fp_motion(p)
		return
	if state != St.PLACE or overlay != "" or not painting:
		return
	if _cur_army().team != paint_team:
		painting = false
		return
	var c := _cell_at(p)
	if c.x >= 0 and _cur_army().index_at(c.x, c.y) == -1:
		_try_place(c)



func _mb_release_cleanup() -> void:
	_fp_abort_drag()
	drag_new = false
	painting = false
	drag_from = Vector2i(-1, -1)



## 滑鼠按鍵（佇列命令，第三輪 A2）：按鈕點擊、擺放、拖曳、移除。
func _mb_cmd(d: Dictionary) -> void:
	var mb := InputEventMouseButton.new()
	mb.button_index = d["i"]
	mb.pressed = d["pressed"]
	mb.position = d["pos"]
	mouse = d["pos"]
	if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
		if _do_click(mouse) > 0:
			_mb_release_cleanup()
			return
	if state == St.PLACE and overlay == "" and _fp_mb(d):
		return   # 第六輪：自由排兵處理掉了
	if overlay != "" or state != St.PLACE:
		if not mb.pressed:   # 放開滑鼠一定要清掉拖曳／塗兵狀態，即使上面蓋著覆蓋層
			_mb_release_cleanup()
			if overlay == "" and state == St.BATTLE and mb.button_index == MOUSE_BUTTON_LEFT:
				_battle_click(mouse)   # 重播時點兵讓鏡頭跟（第三輪 F2）
		return
	var c := _cell_at(mouse)
	if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		var k := _card_at(mouse)
		if k >= 0 and _card_help_rect(k).has_point(mouse):
			return   # 放開時由「?」按鈕處理
		if k >= 0:
			if _allowed(k):
				selected = k
				drag_new = true
				sfx.play("ui_click")
			else:
				_toast(L.t("err_type"), true)
			return
		if c.x < 0:
			return
		if _can_edit_existing() and _cur_army().index_at(c.x, c.y) != -1:
			if (mode == Mode.TUTORIAL or mode == Mode.PUZZLE) and PZ.is_fixed(PZ.get_puzzle(puzzle_id), c.x, c.y):
				_toast(L.t("err_locked"), true)
				return
			drag_from = c
		else:
			painting = true
			paint_team = _cur_army().team
			_try_place(c)
	elif mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
		if drag_new and c.x >= 0:
			_try_place(c)
		elif drag_from.x >= 0:
			if c.x < 0:
				_try_remove(drag_from)
			elif c != drag_from:
				if mode == Mode.GAUNTLET and gauntlet_stage > 1 and _gauntlet_diff() >= gauntlet_changes:
					_toast(L.t("err_changes"), true)
				elif not _cur_army().move(drag_from.x, drag_from.y, c.x, c.y):
					_toast(L.t("err_zone"), true)
				else:
					sfx.play("place_light")
		drag_new = false
		painting = false
		drag_from = Vector2i(-1, -1)
	elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and c.x >= 0:
		_try_remove(c)



func _key(k: int) -> void:
	if state == St.PLACE and _fp_key(k):
		return
	# 有按鈕焦點的畫面（標題、選單、結果、覆蓋層、戰鬥）：方向鍵移焦點、Enter 按下、Esc 返回
	if state != St.PLACE or overlay != "":
		match k:
			KEY_UP, KEY_LEFT:
				_move_focus(-1)
			KEY_DOWN, KEY_RIGHT:
				_move_focus(1)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if _btns_gen == _gen and _focus >= 0 and _focus < _btns.size() and _btns[_focus]["en"]:   # 按鈕清單要是這個畫面的
					sfx.play("ui_click")
					_btns[_focus]["cb"].call()
			KEY_PAGEUP, KEY_PAGEDOWN:
				if overlay == "codex":
					_scroll_by("left", -160.0 if k == KEY_PAGEUP else 160.0)
			KEY_P, KEY_TAB:
				# 手把 Y 送的是 Tab：戰鬥中＝暫停（第七輪 A6）
				if state == St.BATTLE and overlay == "":
					_toggle_pause()
				elif k == KEY_TAB:
					_move_focus(1)
			KEY_ESCAPE:
				if overlay != "":
					overlay = ""
				elif state == St.BATTLE:
					if play_kind != "official":
						_replay_back()   # 第七輪 A9：重播時 Esc＝返回
					else:
						_on_skip()
				elif state != St.TITLE:
					_go_title()
		return
	pad_mode = true
	match k:
		KEY_UP: cursor.y = maxi(0, cursor.y - 1)
		KEY_DOWN: cursor.y = mini(8, cursor.y + 1)
		KEY_LEFT: cursor.x = maxi(0, cursor.x - 1)
		KEY_RIGHT: cursor.x = mini(15, cursor.x + 1)
		KEY_F1:
			_open_codex(selected)
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0:
			# 第八輪：數字鍵對應這一排的第幾張卡，不是兵種編號
			var pos := 9 if k == KEY_0 else k - KEY_1
			var cards := _card_types()
			if pos < cards.size() and _allowed(cards[pos]):
				selected = cards[pos]
		KEY_Q, KEY_E:
			var cl := _card_types()
			if not cl.is_empty():
				var at := maxi(0, cl.find(selected))
				for _i in cl.size():
					at = (at + (cl.size() - 1 if k == KEY_Q else 1)) % cl.size()
					selected = cl[at]
					if _allowed(selected):
						break
		KEY_ENTER, KEY_KP_ENTER:
			if _cur_army().index_at(cursor.x, cursor.y) == -1:
				_try_place(cursor)
		KEY_BACKSPACE, KEY_DELETE:
			_try_remove(cursor)
		KEY_SPACE, KEY_TAB:
			_on_start()
		KEY_ESCAPE:
			_go_title()



func _throttle_when_minimized() -> void:
	var mini: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED
	if mini != _was_minimized:
		_was_minimized = mini
		Engine.max_fps = 10 if mini else 0



func _process(delta: float) -> void:
	_throttle_when_minimized()
	_rv_poll()
	_settings_hover()
	var _t0 := Time.get_ticks_usec()
	_process_inner(delta)
	perf_proc_us = Time.get_ticks_usec() - _t0


func _process_inner(delta: float) -> void:
	_stick_repeat(delta)
	_process_cmds()
	time += delta
	SteamApi.run_callbacks()
	if toast_t > 0:
		toast_t -= delta
	if removed_banner_t > 0.0:
		removed_banner_t -= delta
	if ach_t > 0:
		ach_t -= delta
	elif not ach_queue.is_empty():
		toast = ach_queue.pop_front()
		toast_t = 2.5
		ach_t = 2.6
	shake = maxf(0.0, shake - delta)
	if not freeze_fx:
		for f in fx:
			f["t"] += delta
			if f.has("pop"):
				f["pop"] = maxf(0.0, f["pop"] - delta)
		fx = fx.filter(func(f): return f["t"] < f["dur"])
		clutch_t = maxf(0.0, clutch_t - delta)
	for g in dying:
		g["t"] += delta
		if g["t"] >= 1.0:
			graves.append({"pos": g["pos"], "team": g["team"], "t": 0.0})
	dying = dying.filter(func(g): return g["t"] < 1.0)
	for g in graves:
		g["t"] += delta
	graves = graves.filter(func(g): return g["t"] < 3.0)
	if overlay == "codex":
		_codex_tick(delta)
	if state == St.TITLE and demo != null and shot_dir == "":
		demo_acc += delta
		while demo_acc >= 0.05:
			demo_acc -= 0.05
			demo.step()
		if demo.finished:
			_new_demo()
	if state == St.BATTLE and shot_dir == "":
		_battle_process(delta)
		_follow_update(delta)
	elif state == St.RESULT:
		zoom = lerpf(zoom, 1.0, delta * 4)
	if font_bold != null:
		_layout_texts()   # 戰鬥事件產生跳字之後才排版，新跳字第一幀就有位置（Codex S1 #3）
	queue_redraw()



# ───────────────────────── 繪圖 ─────────────────────────
func _draw() -> void:
	var _t0 := Time.get_ticks_usec()
	_draw_inner()
	perf_draw_us = Time.get_ticks_usec() - _t0


func _draw_inner() -> void:
	_btns.clear()
	probe_texts.clear()
	probe_btns.clear()
	probe_ctrls.clear()
	_probe_ui = false
	draw_rect(Rect2(0, 0, 1280, 800), Color("#1b2a1f"))
	var cam := Transform2D.IDENTITY
	if state == St.BATTLE or state == St.RESULT:
		var off := Vector2.ZERO
		if shake > 0 and _fx_on("shake"):
			off = Vector2(sin(time * 90) * 2, cos(time * 77) * 2)
		var w := clampf((zoom - 1.0) / 0.5, 0.0, 1.0)
		var c := (ORIGIN + FIELD / 2).lerp(zoom_center, w)
		var half := Vector2(640, 388) / zoom
		var lo := ORIGIN + half - Vector2(60, 100)
		var hi := ORIGIN + FIELD - half + Vector2(60, 100)
		c = Vector2(clampf(c.x, minf(lo.x, hi.x), maxf(lo.x, hi.x)), clampf(c.y, minf(lo.y, hi.y), maxf(lo.y, hi.y)))
		cam = Transform2D(0, Vector2(zoom, zoom), 0, Vector2(640, 388) - c * zoom + off)
	if state == St.TITLE:
		# 第七輪 D4：示範戰場縮小放右邊，不被左側面板壓到
		cam = Transform2D(0, Vector2(0.72, 0.72), 0, Vector2(1270.0 - (ORIGIN.x + FIELD.x) * 0.72, 400.0 - (ORIGIN.y + FIELD.y / 2.0) * 0.72))
	draw_set_transform_matrix(cam)
	_cam = cam
	Art.base = cam
	var _t := Time.get_ticks_usec()
	_draw_field()
	perf_parts["field"] = Time.get_ticks_usec() - _t
	_t = Time.get_ticks_usec()
	if state == St.TITLE:
		_draw_units_of(demo, true)
	elif state == St.PLACE:
		if _is_free():
			_fp_draw_zones()   # 第六輪：自由排兵
			_fp_draw()
		else:
			_draw_place_units()
			_draw_tactical()
	else:
		_draw_units_of(view, false)
	perf_parts["units"] = Time.get_ticks_usec() - _t
	_t = Time.get_ticks_usec()
	for f in fx:   # 先畫特效，跳字最後畫（Antigravity S2 #1：特效不能蓋住跳字）
		if not f.get("screen", false) and f["kind"] != "text":
			_draw_fx(f)
	for f in fx:
		if not f.get("screen", false) and f["kind"] == "text":
			_draw_fx(f)
	perf_parts["fx"] = Time.get_ticks_usec() - _t
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_probe_ui = true
	Art.base = Transform2D.IDENTITY
	if state == St.BATTLE and slow_left > 0:
		_draw_vignette(clampf((8.0 - slow_left) / 0.3, 0.0, 1.0))   # 多層暗角（第三輪 V2）
	if state != St.RESULT:
		for f in fx:
			if f.get("screen", false):
				_draw_fx(f)
	match state:
		St.TITLE: _draw_title()
		St.PLACE: _draw_place_hud()
		St.BATTLE:
			_draw_battle_hud()
			_draw_replay_controls()
			_draw_frenzy_edge()
			_draw_start_cue()
			_draw_battle_report()
			_draw_unit_info()
			if skip_busy:
				_draw_busy(roundi(view.tick * 100.0 / maxf(1.0, view.max_ticks)))
			elif seek_target >= 0:
				_draw_busy(roundi(sim.tick * 100.0 / maxf(1.0, seek_target)))
		St.RESULT:
			_draw_battle_hud()
			_draw_result()
	_draw_clutch_banner()
	_draw_overlay()
	_draw_pad_footer()
	if toast_t > 0:
		var a := minf(1.0, toast_t * 2)
		var tw := font.get_string_size(toast, HORIZONTAL_ALIGNMENT_LEFT, -1, ts(20)).x + 40
		var ty := 40.0 if overlay != "" else 600.0   # 覆蓋層開著時放上面；平常放在兵種提示條（y 654）上面（第四輪 Antigravity）
		if overlay == "" and _is_free():
			ty = 50.0   # 第六輪：自由擺放整個戰場都可能有兵，提示改蓋在上方的兵種說明條（Codex 實作第 3 輪 #2）
		draw_rect(Rect2(640 - tw / 2, ty, tw, 44), Color(0, 0, 0, 0.72 * a))
		_text(Vector2(640, ty + 6), toast, ts(20), Color(1, 0.88, 0.5, a), true)
	if _focus >= _btns.size():
		_focus = 0
	_btns_gen = _gen



## 手把按鍵提示列（第三輪 U7）：用手把時，每個畫面右下角顯示這個畫面能按的鍵（A／B／X／Y 圓形圖示）；
## 用鍵盤滑鼠時不顯示手把圖示（Steam Deck 規定兩者不能同時出現）。擺放畫面已經在上方列顯示，這裡略過。
func _draw_pad_footer() -> void:
	if not pad_mode or (state == St.PLACE and overlay == ""):
		return
	var items: Array = []
	if overlay == "codex":
		items = [["A", L.t("pk_select")], ["B", L.t("back")], ["R", L.t("pk_scroll")]]
	elif overlay != "":
		items = [["A", L.t("pk_select")], ["B", L.t("back")]]
	else:
		match state:
			St.TITLE:
				items = [["＋", L.t("pk_move")], ["A", L.t("pk_select")]]
			St.BATTLE:
				items = [["A", L.t("pk_select")], ["B", L.t("skip")]]
			St.RESULT:
				items = [["＋", L.t("pk_move")], ["A", L.t("pk_select")], ["B", L.t("menu")]]
	if items.is_empty():
		return
	draw_rect(Rect2(0, 770, 1280, 30), Color(0, 0, 0, 0.45))
	_key_hints(640, 773, items, 14)



## 滑鼠停在哪一列：輸入狀態，每幀更新一次（第七輪 H7：原本在繪圖時改狀態）。
func _settings_hover() -> void:
	if overlay != "settings":
		return
	var rows := _settings_rows()
	for i in rows.size():
		if Rect2(370, _settings_row_y(i), 520, 52).has_point(mouse):
			settings_item = rows[i][0]



func _settings_row_y(i: int) -> float:
	return 120.0 + i * 66.0



## ── 輸入命令佇列的執行端（第三輪 A2；S8 從 ui_base 移下來：基底不再用空函式呼叫上層）──
func _process_cmds() -> int:
	var done := 0
	_update_gen()
	var q := _cmds
	_cmds = []
	for c in q:
		if c["gen"] != _gen:
			# 畫面已經換了：丟掉。但「放開滑鼠」一定要清掉拖曳／塗兵狀態（Codex S1 #2）
			if c["kind"] == "mb" and not c["data"]["pressed"]:
				_mb_release_cleanup()
			elif c["kind"] == "padbtn" and not c["data"]["pressed"]:
				_fp_abort_drag()   # 手把放開 A／X 的事件過期：同樣清掉（Codex 實作第 3 輪 #1）
			continue
		if c["kind"] == "click":
			done += _do_click(c["data"])
		elif c["kind"] == "mb":
			# 滑鼠按鍵（擺放、拖曳、移除）也走同一個佇列，和鍵盤選兵的先後順序一致（Codex S1 #2）
			_mb_cmd(c["data"])
			done += 1
		elif c["kind"] == "paint":
			_paint_cmd(c["data"])
		elif c["kind"] == "padbtn":
			if not _fp_pad_button(int(c["data"]["b"]), bool(c["data"]["pressed"])) and c["data"]["pressed"]:
				var mp := {JOY_BUTTON_START: KEY_SPACE, JOY_BUTTON_B: KEY_ESCAPE}
				if mp.has(int(c["data"]["b"])):
					_key(mp[int(c["data"]["b"])])
			done += 1
		elif c["kind"] == "key":
			_key(int(c["data"]))
			done += 1
		_update_gen()
	return done



## 點擊：只對這個畫面世代畫出來的按鈕有效。回傳執行了幾個。
func _do_click(p: Vector2) -> int:
	if _btns_gen != _gen:
		return 0
	for i in _btns.size():
		var b: Dictionary = _btns[i]
		if b["r"].has_point(p):
			if b["en"]:
				_focus = i
				if sfx != null:
					sfx.play("ui_click")
				b["cb"].call()
				return 1
			return 0
	return 0
