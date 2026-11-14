extends "res://scripts/ui/screens/game_v16.gd"
## 其他層在同資料夾（V9 P1 拆檔）

var boot_parts := {}   # V1.1 E6：啟動各階段的時間點（毫秒，從程式啟動算），--boot-check 印出來

var _ov_seen := ""   # V1.2 F1：覆蓋層動畫用
var _ov_t := -9.0
var obj_open_force := -1.0   # 開發用：固定實物開合的進度（<0＝照時間）

var shot_state := {}   # V1.2.1：版面檢查這一組的固定狀態（截圖程式切換後要還原成這裡的值）

## 1.1.0 Q1：手把長按「拿掉」鍵（預設 X）PAD_CLEAR_SEC 秒＝清空自己這邊的擺法（殘局失敗後重擺少按幾下）。只在擺陣、沒有覆蓋層時。
const PAD_CLEAR_SEC := 0.8
var pad_x_t := -1.0
func _pad_x_hold(pressed: bool) -> void:
	pad_x_t = time if pressed and state == St.PLACE and overlay == "" and bool(call("_can_edit_existing")) else -1.0

func _pad_clear_tick() -> void:
	if pad_x_t >= 0.0 and time - pad_x_t >= PAD_CLEAR_SEC:
		pad_x_t = -1.0
		if state == St.PLACE and overlay == "" and has_method("_clear_mine") and bool(call("_can_edit_existing")):   # 雙人輪流落子：已落子不能清（Codex v110-i1 #1）
			call("_clear_mine")
			_toast(L.t("pad_cleared"))

## 1.1.0 A12：拖著兵移動時，每移動約 70px 輕輕一聲木塊摩擦（低音量、至少隔 0.14 秒；簡化特效不影響聲音、音量跟介面音量）
var scrape_acc := 0.0
var scrape_t := -9.0
func _drag_scrape(d: float) -> void:
	if state != St.PLACE or sfx == null or not (int(get("fp_drag")) >= 0 or drag_from.x >= 0):
		scrape_acc = 0.0
		return
	scrape_acc += d
	if scrape_acc >= 70.0 and time - scrape_t >= 0.14:
		scrape_acc = 0.0
		scrape_t = time
		sfx.play_pitched("place_light", 0.18, 0.8)

func _ready() -> void:
	if not Input.joy_connection_changed.is_connected(_trans_joy_changed):
		Input.joy_connection_changed.connect(_trans_joy_changed)   # 1.4.0 第 8 大類
	boot_parts["ready_in"] = Time.get_ticks_msec()
	on_battle_finished = _finish_battle
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot=") or a.begins_with("--steam-test=") or a.begins_with("--perf=") or a == "--boot-check" or a.begins_with("--mem-check=") or a.begins_with("--sil="):
			Save.prefix = "shot_"   # 不讀、不寫玩家真正的存檔
		elif a == "--self-check":
			Save.prefix = "smoke_"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-prefix="):
			# 1.2.0：版面檢查平行跑時每組用自己的存檔前綴、從乾淨的存檔開始（原本共用 shot_ 會互搶寫入、也會帶到前一組的資料）
			# 防誤刪（Codex cat02 #1）：只在截圖模式、前綴一定是 shot_＋組合名（≥8 字、只有英數底線連字號），只刪這個前綴的存檔類檔名
			var px := a.substr(14)
			# 前綴一定以「__」結尾且只出現一次 → 各組前綴互不為前綴（shot_en_150__ 不會吃到 shot_en_150_plain__ 的檔，Codex cat03 #3）
			var safe := Save.prefix == "shot_" and px.begins_with("shot_") and px.length() >= 9 and px == px.validate_filename() and px.ends_with("__") and px.count("__") == 1
			if safe:
				Save.prefix = px
				var d := DirAccess.open("user://")
				if d != null:
					for f in d.get_files():
						if f.begins_with(px) and (f.ends_with(".json") or f.ends_with(".bak") or f.contains(".corrupt") or f.ends_with(".jsonl") or f.ends_with(".tmp")):
							d.remove(f)
	Save.load_all()
	Guide.seed_seen(Save.data)   # V1.6 #1
	Guide.seed_eff(Save.data)   # V1.6.1 N1
	if Save.prefix == "":
		Funnel.boot()   # V1.6 #2（截圖、自我檢查不算）
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
		elif a2.begins_with("--shot-state="):   # V1.2.1：版面檢查的狀態矩陣（plain、cb、pad）
			for st in a2.substr(13).split(","):
				shot_state[st] = true
			if shot_state.has("plain"):
				Save.settings["plain_ui"] = true
			if shot_state.has("cb"):
				Save.settings["colorblind"] = true
			if shot_state.has("craft"):
				Save.settings["ui_font"] = "craft"   # 1.2.0 §3.2：工藝字型的 A／B 截圖
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
	boot_parts["save"] = Time.get_ticks_msec()
	_load_fonts()
	boot_parts["fonts"] = Time.get_ticks_msec()
	# V1.2：自訂游標（小劍，tools/gen/gen_ui_tex.py 生成）；plain_ui 時用系統游標
	if not bool(Save.s("plain_ui")) and ResourceLoader.exists("res://art/ui/cursor.png"):
		Input.set_custom_mouse_cursor(load("res://art/ui/cursor.png"), Input.CURSOR_ARROW, Vector2(2, 2))
	sfx = SfxScript.new()
	add_child(sfx)
	if sfx.has_method("play_room") and DisplayServer.get_name() != "headless":
		sfx.call_deferred("play_room", true)   # 1.3.0 §10：棋館環境三層一直在（音量走環境音設定）
	boot_parts["sfx"] = Time.get_ticks_msec()
	call("_paint_apply")   # V1.4 #15：塗裝要在第一次烘圖集之前套上
	sprites = SpriteCache.new()
	add_child(sprites)
	if capsule_path == "":
		_rebuild_sprites.call_deferred()
	sfx.set_volumes(int(Save.s("sfx")), int(Save.s("music")), int(Save.s("ui_vol")), int(Save.s("amb_vol")))
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
	call("_apply_display")   # V1.5：幀率、垂直同步
	call("_apply_master")
	rng.seed = Time.get_ticks_usec() if (shot_dir == "" and not video_mode) else 12345
	if video_mode:
		Save.prefix = "shot_"
		Save.load_all()
	_go_title()   # 截圖、影片、效能量測由 main 接手（S8）
	if not bool(Save.s("first_done")) and shot_dir == "" and not video_mode and DisplayServer.get_name() != "headless":
		overlay = "first_run"   # V1.5：第一次啟動先問語言、字級、無障礙
	if not video_mode and overlay != "first_run":
		intro_begin()   # 1.3.0 §13 掌燈開門（第一次；有第一次設定時等設定完才播）
	boot_parts["title"] = Time.get_ticks_msec()



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
	if _trans_gate(ev):
		if is_inside_tree():
			get_viewport().set_input_as_handled()
		return
	if _keys_input(ev):
		return
	if nb_edit >= 0 and _nb_edit_input(ev):
		return   # V1.6.1 N3：實驗簿改名時，鍵盤輸入給名稱框
	if ev is InputEventScreenTouch or ev is InputEventScreenDrag:
		fp_touch = true   # 第六輪：觸控時預覽畫在手指上方
		_touch_input(ev)   # V1.4 #18：長按＝右鍵、雙指縮放
		return
	if ev is InputEventMagnifyGesture and (state == St.BATTLE or state == St.RESULT):
		_pinch_by(ev.factor, ev.position)   # 觸控板的捏合也一樣
		return
	if ev is InputEventMouseMotion:
		mouse = ev.position
		pad_mode = false
		if ev.device != InputEvent.DEVICE_ID_EMULATION:
			fp_touch = false
		hover_card = _card_at(mouse)
		if state == St.BATTLE and overlay == "" and (ev.button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0:
			_enqueue("pan", ev.relative)   # 1.3.0 §2：中鍵拖曳平移
		_enqueue("paint", mouse)   # 一律排入，由執行端判斷有沒有在塗兵（同一幀按下再拖過也不漏格，Codex S3）
		_drag_scrape(ev.relative.length())
		return
	if intro_t >= 0.0 and ((ev is InputEventKey and ev.pressed) or (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventJoypadButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed)):
		intro_end()   # 1.3.0 §13：任何按鍵、點擊跳過開場（這一下不再往下傳）
		intro_eat = true
		get_viewport().set_input_as_handled()
		return
	if intro_eat and ((ev is InputEventMouseButton and not ev.pressed) or (ev is InputEventScreenTouch and not ev.pressed) or (ev is InputEventJoypadButton and not ev.pressed) or (ev is InputEventKey and not ev.pressed)):
		intro_eat = false   # 跳過那一下的放開也吞掉（不然會點到底下的按鈕；Codex cat11 #2）
		get_viewport().set_input_as_handled()
		return
	if ev is InputEventMouseButton:
		mouse = ev.position
		if overlay == "codex" and ev.pressed and (ev.button_index == MOUSE_BUTTON_WHEEL_UP or ev.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			_scroll_at(mouse, -48.0 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else 48.0)   # 圖鑑捲動（第三輪 U1）
			return
		_enqueue("mb", {"i": ev.button_index, "pressed": ev.pressed, "pos": ev.position, "dbl": ev.double_click})
		return
	if state == St.BATTLE and ((ev is InputEventKey and ev.pressed) or (ev is InputEventJoypadButton and ev.pressed)):
		mag_hide = follow_id   # 1.3.0 §2：任何按鍵（含沒綁定的鍵、手把鍵）1 幀內收起放大鏡（只動畫面；Codex cat06 #6）
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
	if ev is InputEventJoypadButton:
		last_joy = ev.device     # 所有分流之前記（Codex v10-r1 #6）
		if ev.button_index == JOY_BUTTON_X:
			_pad_x_hold(ev.pressed)   # 1.1.0 Q1：長按拿掉鍵＝清空自己的陣
	if ev is InputEventJoypadButton and ev.pressed and _pad_tool(ev):
		return
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
			JOY_BUTTON_BACK: KEY_F1, JOY_BUTTON_LEFT_STICK: KEY_H, JOY_BUTTON_RIGHT_STICK: KEY_P}
		if map.has(ev.button_index):
			_enqueue("key", map[ev.button_index])
		return
	if ev is InputEventJoypadMotion and ev.axis == JOY_AXIS_RIGHT_Y and overlay == "codex" and absf(ev.axis_value) > maxf(0.1, int(Save.s("deadzone")) / 100.0):   # V1.5：死區照設定
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
	call("vol_motion", p)   # 1.3.0：音量木軌拖曳中（沒在拖就什麼都不做）
	if drag_from.x >= 0 and p.distance_to(drag_press_p) >= 10.0:
		drag_moved = true   # V1.5.1：拖出去過就不算「點一下」（拖回原點也一樣，Codex v151-i3）
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



var drag_press_p := Vector2.ZERO
var drag_moved := false

func _mb_release_cleanup() -> void:
	call("vol_release")   # 1.3.0：過期的放開也結束音量拖曳（並存檔）
	_fp_abort_drag()
	drag_new = false
	painting = false
	drag_from = Vector2i(-1, -1)



## 滑鼠按鍵（佇列命令，第三輪 A2）：按鈕點擊、擺放、拖曳、移除。
var dbl_eat := false
var intro_eat := false   # 1.3.0 §13

## 1.3.0 §2：雙擊回全景只認盤面範圍（按鈕列、HUD 不算）。
func _field_hit(p: Vector2) -> bool:
	if p.y <= 96.0 or p.y >= (640.0 if _replay_controls_active() else 760.0):
		return false
	for b in _btns:
		if (b["r"] as Rect2).has_point(p):
			return false   # 按鈕上雙擊不算（Codex cat06 #4）
	var lo: Vector2 = _cam * ORIGIN
	var hi: Vector2 = _cam * (ORIGIN + fld_size)
	return Rect2(lo, hi - lo).has_point(p)

func _mb_cmd(d: Dictionary) -> void:
	var mb := InputEventMouseButton.new()
	mb.button_index = d["i"]
	mb.pressed = d["pressed"]
	mb.position = d["pos"]
	mouse = d["pos"]
	var eat_dbl := false
	if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
		eat_dbl = dbl_eat   # 雙擊回全景那次的放開：不論走哪條路都要清掉（Codex cat06 #4）
		dbl_eat = false
	if state == St.BATTLE and overlay == "" and mb.pressed:
		mag_hide = follow_id   # 1.3.0 §2：任何按下都先收起放大鏡（點到兵會在放開時重新選）
		hl_reel.clear()        # 精華三連播放中動了就停在這裡（交還手動）
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_wheel(mb.button_index == MOUSE_BUTTON_WHEEL_UP, mouse)   # 滾輪縮放
			return
		if mb.button_index == MOUSE_BUTTON_LEFT and bool(d.get("dbl", false)) and _field_hit(mouse):
			cam_reset()   # 雙擊盤面回全景
			dbl_eat = true
			return
	if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and bool(call("vol_press", mouse)):
		return   # 1.3.0：在音量木軌上按下＝開始拖
	if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed and bool(call("vol_release")):
		_mb_release_cleanup()
		return   # 拖完放開：存檔，不再觸發數值鈕
	if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
		if _do_click(mouse) > 0:
			_mb_release_cleanup()
			return
	if state == St.PLACE and overlay == "" and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and _v16_place_click(mouse):
		return   # V1.6 #6：標記模式
	if state == St.PLACE and overlay == "" and _fp_mb(d):
		return   # 第六輪：自由排兵處理掉了
	if overlay != "" or state != St.PLACE:
		if not mb.pressed:   # 放開滑鼠一定要清掉拖曳／塗兵狀態，即使上面蓋著覆蓋層
			_mb_release_cleanup()
			if overlay == "" and state == St.BATTLE and mb.button_index == MOUSE_BUTTON_LEFT:
				if not eat_dbl:   # 雙擊回全景的那次放開不再選兵
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
				sfx.play("k_click", 0.7)
			else:
				_toast(L.t("err_type"), true)
			return
		if c.x < 0:
			return
		if _can_edit_existing() and _cur_army().index_at(c.x, c.y) != -1:
			if (mode == Mode.TUTORIAL or mode == Mode.PUZZLE) and PZ.is_fixed(PZ.get_puzzle(puzzle_id), c.x, c.y):
				_toast(L.t("err_locked"), true)
				return
			if mode == Mode.VS_AI and bool(call("wave_is_locked", c)):
				_toast(L.t("wv_locked"), true)   # V1.4 #11：車輪戰殘兵不能搬
				return
			drag_from = c
			drag_moved = false
			drag_press_p = mouse   # V1.5.1：記下按下的位置，放開時分辨「點一下」和「拖出去又拖回來」（Codex v151-i2 #2）
		else:
			painting = Save.s("place_mode") != "tap"   # V1.5.1 C3：點選擺放不連續塗
			paint_team = _cur_army().team
			_try_place(c)
	elif mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
		if drag_new and c.x >= 0:
			_try_place(c)
		elif drag_from.x >= 0:
			if c.x < 0:
				_try_remove(drag_from)
			elif c == drag_from and Save.s("place_mode") == "tap" and not drag_moved and mouse.distance_to(drag_press_p) < 10.0:
				_try_remove(drag_from)   # V1.5.1 C4：只點選模式點一下自己的兵＝拿掉（觸控不用長按）
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



## 1.2.0 第 11 大類：手把的部署工具＝按住 RT（右扳機，原本沒用到）＋Y 翻轉（自由：對齊）、＋十字 ←／→ 整軍後退／前進、＋LB 複製上一陣。
## 這裡的 Y、LB 是改鍵換算後的預設鍵（_input 先做 pad_to_default）：改了「暫停」「上一種」的綁定就跟著換，提示也照綁定顯示。
## 不能用的情況（工具不開放、不是擺陣）照原本的按鍵處理。
func _pad_tool(ev: InputEventJoypadButton) -> bool:
	if state != St.PLACE or overlay != "" or Input.get_joy_axis(ev.device, JOY_AXIS_TRIGGER_RIGHT) < 0.5:
		return false
	var id := ""
	match ev.button_index:
		JOY_BUTTON_Y:
			id = "align" if _is_free() else "flip"
		JOY_BUTTON_DPAD_RIGHT:
			id = "" if _is_free() else "fwd"
		JOY_BUTTON_DPAD_LEFT:
			id = "" if _is_free() else "back"
		JOY_BUTTON_LEFT_SHOULDER:
			id = "last"
	if id == "" or not bool(call("_deploy_tools_ok")):
		return false
	pad_mode = true
	_enqueue("tool", id)   # 和落子、放開、開戰同一個佇列（不然會插到前面還沒處理的拖曳之前；Codex cat11 #3）
	return true

## 1.2.0 §11.1 部署工具的鍵（格子 M、Shift＋←→；自由 A；兩種 L）
func _place_tool_key(k: int) -> bool:
	match k:
		KEY_M:
			return call("_deploy_tool", "flip")
		KEY_A:
			return call("_deploy_tool", "align")
		KEY_L:
			return call("_deploy_tool", "last")
		KEY_RIGHT, KEY_LEFT:
			if Input.is_key_pressed(KEY_SHIFT):
				return call("_deploy_tool", "fwd" if k == KEY_RIGHT else "back")
	return false

func _key(k: int) -> void:
	_toast_dismiss()
	if state == St.BATTLE:
		mag_hide = follow_id   # 1.3.0 §2：任何按鍵 1 幀內收起放大鏡
		hl_reel.clear()        # 精華三連：按鍵＝交還手動（Codex cat06 #6）
	if state == St.RESULT and _ink_active():
		result_t -= INK_DUR   # 1.2.0 §9.4：任何按鍵跳過宣紙戰報演出
		return
	if state == St.PLACE and overlay == "" and _v16_place_key(k):
		return
	if state == St.PLACE and overlay == "" and _place_tool_key(k):
		return
	if state == St.PLACE and _fp_key(k):
		return
	if state == St.BATTLE and overlay == "" and _cmd_key(k):
		return
	if state == St.BATTLE and overlay == "" and (k == KEY_BRACKETLEFT or k == KEY_BRACKETRIGHT) and _replay_controls_active():
		_bm_jump(-1 if k == KEY_BRACKETLEFT else 1)   # 1.2.0 §11.2 書籤
		return
	if state == St.BATTLE and overlay == "" and k == KEY_G and play_kind == "review" and tm_ghost != null:
		tm_ghost_on = not tm_ghost_on   # 1.2.0 §11.3
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
					sfx.play("k_click", 0.7)
					_btns[_focus]["cb"].call()
			KEY_F1:
				if state == St.BATTLE and overlay == "" and play_kind != "official":
					call("_breport_open")   # 1.1.0 B10：手把 View／Select＝戰報面板
				elif state == St.BATTLE and overlay == "":
					set("hud_info_until", time + 2.0)   # 1.2.0 §5.6：正式對戰按 View＝叫出 AI 名稱與性格 2 秒
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
				if overlay == "ai_busy":
					pass      # 第十輪 I4：AI 計算中不能取消
				elif overlay == "first_run":
					Save.set_setting("first_done", true)   # V1.5：跳過第一次啟動的問題
					overlay = ""
				elif overlay == "paint":
					call("_paint_close")   # V1.4 #15：Esc／手把 B 也要存塗裝（Codex、Antigravity v140-i4）
				elif overlay == "pause_menu":
					call("_pause_resume")
				elif overlay == "settings":
					call("_settings_close")
				elif overlay == "fs_confirm":
					call("_fs_revert")
				elif overlay == "confirm":
					overlay = str(get("confirm_ret"))
				elif overlay in ["keys", "restore", "clear_data"]:
					set("keys_capture", "")
					overlay = "settings"   # 設定的子頁：Esc 回設定（不是整個關掉，Antigravity v150-i2 #4）
				elif overlay == "codex" and bool(get("cx_zoom")) and int(get("cx_unit")) < D.total():
					set("cx_zoom", false)   # V1.5.1：近看模式先收合
				elif overlay == "breport":
					call("_breport_close")   # 1.1.0 B10：回到重播、焦點與暫停狀態還原
				elif overlay == "boss_note":
					call("_close_boss_note")   # 1.2.0：Esc／手把 B＝知道了（不然下一幀又跳出來，Codex cat03 #1）
				elif overlay == "trio_result":
					call("_trio_back")   # 1.1.0 H3：和結算頁返回鈕同一條路
				elif overlay == "leave" and state == St.BATTLE and paused:
					overlay = "pause_menu"   # 和「留下」一樣回暫停選單（Codex v151-i1 #3）
				elif overlay != "":
					# V1.5.1：Esc／手把 B 和返回鈕同一套目的地；沒登記來處的子頁用它返回鈕的目的地
					call("_nav_back", {"wager": "playroom", "draft": "playroom", "wave_codes": "codes", "ghosts": "playroom", "weekly": "playroom", "rift": "playroom", "nb_words": "notebook", "daily_past": "playroom", "wk_ghosts": "weekly"}.get(overlay, ""))
				elif state == St.BATTLE:
					if play_kind != "official":
						_replay_back()   # 第七輪 A9：重播時 Esc＝返回
					else:
						call("_open_pause_menu")   # V1.5：Esc 開暫停選單（原本直接看結果，移進選單第二項）
				elif state != St.TITLE:
					_request_leave()
		return
	pad_mode = true
	match k:
		KEY_UP: cursor.y = maxi(0, cursor.y - 1)
		KEY_DOWN: cursor.y = mini(8, cursor.y + 1)
		KEY_LEFT: cursor.x = maxi(0, cursor.x - 1)
		KEY_RIGHT: cursor.x = mini(15, cursor.x + 1)
		KEY_F1:
			_open_codex(selected)
		KEY_H:
			if mode == Mode.PUZZLE:
				call("_puzzle_hint")   # 第十三輪：手把 L3
		KEY_P:
			if mode == Mode.PUZZLE and PZ.get_puzzle(puzzle_id).has("cmd"):
				overlay = "puzzle_plan"   # 第十三輪：手把 R3
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
			_request_leave()



func _throttle_when_minimized() -> void:
	var mini: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED
	if mini != _was_minimized:
		_was_minimized = mini
		if mini:
			Engine.max_fps = 10
		else:
			call("_apply_display")   # V1.5：還原時回到玩家設定的幀率上限，不是無上限（Antigravity v150-i1 #4）



func _process(delta: float) -> void:
	_throttle_when_minimized()
	intro_tick(delta)   # 1.3.0 §13
	bg.reap()   # 1.1.0 N6：收掉已叫停、已停下的背景工作
	_rv_poll()
	_settings_hover()
	_v16_tick(delta)   # V1.6：漏斗里程碑、背景工作
	var _t0 := Time.get_ticks_usec()
	_process_inner(delta)
	perf_proc_us = Time.get_ticks_usec() - _t0


var rumble_seen := 0.0

## ── V1.4 #18 觸控：點＝左鍵（引擎把觸控模擬成滑鼠）、長按 0.5 秒＝右鍵（拿掉兵）、雙指捏合＝縮放戰場 ──
const LONG_PRESS := 0.5
var touches := {}            # 手指編號 → 位置
var lp_t := -1.0             # 長按計時（-1＝沒有在算）
var lp_pos := Vector2.ZERO

func _touch_input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		if ev.pressed:
			touches[ev.index] = ev.position
		else:
			touches.erase(ev.index)
		lp_t = 0.0 if (ev.pressed and touches.size() == 1 and overlay == "") else -1.0   # 覆蓋層（例如軍令時間軸）不用長按，免得拖曳變右鍵
		lp_pos = ev.position
		return
	if ev is InputEventScreenDrag:
		var old: Vector2 = touches.get(ev.index, ev.position)
		touches[ev.index] = ev.position
		if lp_t >= 0.0 and ev.position.distance_to(lp_pos) > 12.0:
			lp_t = -1.0   # 拖動了就不是長按
		if touches.size() == 2 and (state == St.BATTLE or state == St.RESULT):
			var ks := touches.keys()
			var other: Vector2 = touches[ks[0] if ks[1] == ev.index else ks[1]]
			var d0: float = old.distance_to(other)
			var d1: float = ev.position.distance_to(other)
			if d0 > 8.0:
				_pinch_by(d1 / d0, (ev.position + other) / 2.0)

func _pinch_by(f: float, at: Vector2) -> void:
	pinch_zoom = clampf(pinch_zoom * f, 1.0, 2.0)
	pinch_center = _fld_xf().affine_inverse() * at

func _touch_tick(delta: float) -> void:
	if lp_t < 0.0:
		return
	lp_t += delta
	if lp_t >= float(Save.s("long_press")):
		lp_t = -1.0
		# 長按：取消左鍵的拖曳，改送一次右鍵（擺陣時拿掉兵；其他畫面右鍵本來就是返回／取消）
		drag_new = false
		painting = false
		drag_from = Vector2i(-1, -1)
		if _is_free():
			_fp_abort_drag()
		_enqueue("mb", {"i": MOUSE_BUTTON_RIGHT, "pressed": true, "pos": lp_pos})
		_enqueue("mb", {"i": MOUSE_BUTTON_RIGHT, "pressed": false, "pos": lp_pos})
		Input.vibrate_handheld(30)

func _process_inner(delta: float) -> void:
	if shot_dir != "" and bool(get("shot_fixed")):
		delta = 1.0 / 60.0   # 1.2.0 §14.6：視覺回歸模式（--shot-fixed）用固定幀時間；一般版面檢查照真實時間（Codex cat01 #6）
	_touch_tick(delta)
	_pad_clear_tick()
	_stick_repeat(delta)
	_process_cmds()
	time += delta
	call("_gif_tick", delta)   # V1.4 #14
	if paused and key_t > 0.0:
		key_t += delta
	if paused and float(last_kill[1]) > 0.0:
		last_kill[1] = float(last_kill[1]) + delta   # 暫停時定格與歡呼波浪也凍結   # V1.3 C4：暫停時關鍵時刻的演出凍結（Codex v130-impl2）
	SteamApi.run_callbacks()
	if toast_t > 0:
		toast_t -= delta
	# V1.5：手把震動跟著鏡頭震動（強度可調、0 關掉；只在用手把時）
	if shake > rumble_seen + 0.05 and pad_mode and int(Save.s("rumble")) > 0:
		var rk: float = clampf(shake * 4.0, 0.2, 1.0) * int(Save.s("rumble")) / 100.0
		Input.start_joy_vibration(last_joy, 0.3 * rk, 0.6 * rk, 0.18)
	rumble_seen = shake
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
		if _frags_on():
			frags.step(delta)
		else:
			frags.clear()   # 戰鬥中切減少特效／簡化／4 倍速：舊碎片也收掉（Codex cat09 #3）
		clutch_t = maxf(0.0, clutch_t - delta)
	for g in dying:
		var t0: float = g["t"]
		g["t"] += delta
		if t0 < 1.0 and g["t"] >= 1.0:   # 只在跨過 1 秒那一幀插旗（倒棋留 1.7 秒，Codex v130-impl1）
			graves.append({"pos": g["pos"], "team": g["team"], "t": 0.0})
	dying = dying.filter(func(g): return g["t"] < death_life(int(g["type"])))   # V1.3 A5：倒棋留 1.7 秒
	for g in graves:
		g["t"] += delta
	graves = graves.filter(func(g): return g["t"] < 3.0)
	if overlay == "codex":
		_codex_tick(delta)
	if overlay == "ai_busy":
		_ai_poll()
	if not pre_old.is_empty():
		_pre_reap()
	if state == St.TITLE and demo != null and shot_dir == "" and Save.s("title_bg") == "demo" and not bool(Save.s("reduce_motion")):   # V1.5：主畫面背景可改靜態
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
	mag_on = bool(Save.s("magnify"))   # V1.6 #7；V1.6.1 F4：手把也能用（指焦點按鈕上的字）
	mag_hit = []
	var _t0 := Time.get_ticks_usec()
	_draw_inner()
	_draw_magnifier()   # V1.6 #7：最上層
	perf_draw_us = Time.get_ticks_usec() - _t0


func _draw_inner() -> void:
	_btns.clear()
	_probe_cell_seq = 0
	probe_texts.clear()
	probe_btns.clear()
	probe_ctrls.clear()
	probe_boxes.clear()
	probe_icons.clear()
	probe_reset_geom()
	_probe_ui = false
	_draw_desk()   # 1.2.0 §1.1 桌面世界：整個畫面是一張胡桃木桌（取代深綠底＋一圈樹）
	if (state == St.BATTLE or state == St.PLACE) and not bool(Save.s("plain_ui")):
		draw_rect(Rect2(0, 0, 1280, 800), Color(DIM_INK, 0.15))   # 1.2.0 第 6 大類 F §5.5 景深：對局時桌面退後（盤面不受影響，盤在之後畫）
	_sync_field()
	var fxf := _fld_xf()
	var cam := fxf
	if state == St.BATTLE or state == St.RESULT:
		var off := Vector2.ZERO
		if shake > 0 and _fx_on("shake"):
			off = Vector2(sin(time * 90) * 2, cos(time * 77) * 2) * int(Save.s("shake_pct")) / 100.0   # V1.5：鏡頭震動強度
		var w := clampf((zoom - 1.0) / 0.5, 0.0, 1.0)
		var c := (ORIGIN + FIELD / 2).lerp(fxf * zoom_center, w)
		var half := Vector2(640, 388) / zoom
		var anchor := Vector2(640, 388 + BATTLE_DY)
		var lo := ORIGIN + half - Vector2(60, 100)
		var hi := ORIGIN + FIELD - half + Vector2(60, 100)
		c = Vector2(clampf(c.x, minf(lo.x, hi.x), maxf(lo.x, hi.x)), clampf(c.y, minf(lo.y, hi.y), maxf(lo.y, hi.y)))
		cam = Transform2D(0, Vector2(zoom, zoom), 0, anchor - c * zoom + off) * fxf
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
		_v16_place_draw()   # V1.6 #6
	else:
		if state == St.BATTLE and _frags_on():
			frags.draw(self)   # 1.2.0 §8.2 材料碎片在地上、單位之下
		if state == St.BATTLE:
			_draw_contact_ao(view)   # 1.4.0 §3.2 接觸陰影
		_draw_units_of(view, false)
		if state == St.BATTLE:
			_draw_occluded_bases(view)   # 1.4.0 §3.1 被擋住的兵補虛線底座
			_draw_cues()   # 1.3.0 §7.1 技能預告（命中前）
			_v16_battle_draw()
	perf_parts["units"] = Time.get_ticks_usec() - _t
	_t = Time.get_ticks_usec()
	for f in fx:   # 先畫特效，跳字最後畫（Antigravity S2 #1：特效不能蓋住跳字）
		if not f.get("screen", false) and f["kind"] != "text":
			_draw_fx(f)
	for f in fx:
		if not f.get("screen", false) and f["kind"] == "text":
			_draw_fx(f)
	perf_parts["fx"] = Time.get_ticks_usec() - _t
	if state == St.RESULT and _ink_active():
		_draw_ink_report_field()
	draw_set_transform_matrix(Transform2D.IDENTITY)
	# V1.2 F2：畫面四周暈影（戰場與標題背景，壓在介面底下），讓視線集中在中間
	var vg := _ui_tex("res://art/ui/vignette.png")
	if vg != null and not bool(Save.s("plain_ui")):
		draw_texture_rect(vg, Rect2(0, 0, 1280, 800), false, Color(1, 1, 1, 0.5))
	_probe_ui = true
	Art.base = Transform2D.IDENTITY
	if state == St.BATTLE:
		_draw_seat()        # 1.3.0 §11 對手坐在盤外右側桌邊
		_draw_spotlight()   # 1.3.0 §2 交戰熱點聚光
		_draw_desat()       # 1.3.0 §2 最後一擊去飽和
	if state == St.BATTLE and slow_left > 0:
		_draw_vignette(clampf((8.0 - slow_left) / 0.3, 0.0, 1.0))   # 多層暗角（第三輪 V2）
	if state == St.BATTLE and time - key_t < 0.8 and not bool(Save.s("reduce_fx")):
		_draw_key_moment((time - key_t) / 0.8)
	if state != St.RESULT:
		for f in fx:
			if f.get("screen", false):
				_draw_fx(f)
	match state:
		St.TITLE: _draw_title()
		St.PLACE:
			_draw_place_hud()
			_v16_place_hud()   # V1.6
		St.BATTLE:
			_draw_battle_hud()
			_draw_owner_hand()  # 1.3.0 §11 開戰前老闆替棋鐘上發條（畫在 HUD 之上，不然被木條蓋住；Codex cat11 #4）
			_draw_replay_controls()
			if sim != null and sim.cmd_on:
				_draw_cmd_bar()
			_draw_frenzy_edge()
			_draw_start_cue()
			_draw_battle_report()
			_draw_unit_info()
			_draw_bmag()   # 1.3.0 §2 銅放大鏡小窗
			if pre_thread != null:
				_draw_busy(-1)
			elif skip_busy:
				_draw_busy(roundi(view.tick * 100.0 / maxf(1.0, view.max_ticks)))
			elif seek_target >= 0:
				_draw_busy(roundi(sim.tick * 100.0 / maxf(1.0, seek_target)))
		St.RESULT:
			if not _ink_active():
				_draw_battle_hud()   # 宣紙戰報演出時頂部 HUD 退場（Antigravity cat03 #3）
			if _ink_active():
				_draw_ink_report_screen()   # 1.2.0 §9.4 宣紙戰報：勝負章蓋下之前不出結果面板
			else:
				_draw_result()
	_draw_clutch_banner()
	# V1.2 F1：覆蓋層打開時 0.18 秒淡入（只疊一層漸淡的暗幕，不縮放：按鈕位置和滑鼠永遠一致，Codex v120-impl2）；截圖、版面檢查、簡化特效時不做
	if overlay != _ov_seen:
		_ov_seen = overlay
		_ov_t = time
		_trans_begin()
	var ok_anim: bool = overlay != "" and shot_dir == "" and not layout_probe and not bool(Save.s("reduce_fx"))
	var ok_k := clampf((time - _ov_t) / 0.18, 0.0, 1.0) if ok_anim else 1.0
	obj_open_kind = ""
	var slide := ov_slide_offset()   # 1.4.0 §2.2：器物從桌上的固定位置滑進來（大廳從左、圖鑑從下…）；只動畫面
	var m0 := mouse
	if slide != Vector2.ZERO:
		ui_xf = Transform2D(0.0, slide)   # 疊層裡自己切矩陣的地方都以 ui_xf 為底（不會把滑動蓋掉）
		Art.base = ui_xf
		draw_set_transform_matrix(ui_xf)
		mouse = Vector2(-9999, -9999)     # 滑入中不判 hover（命中框沒位移，高亮會錯位；Codex cat08 #6）
	_draw_overlay()
	var open_k := clampf((time - _ov_t) / 0.3, 0.0, 1.0) if ok_anim and not bool(Save.s("plain_ui")) and not bool(Save.s("reduce_motion")) else 1.0   # 1.4.0：減少動態＝器物也直接開好（和轉場一致，Codex cat08 r2 #4）
	if obj_open_force >= 0.0:
		open_k = obj_open_force   # 開發截圖：固定在開到一半
	if open_k < 1.0 and obj_open_kind != "":
		_obj_open_anim(obj_open_r, obj_open_kind, open_k)   # 1.2.0 第 11 大類：實物開合（只疊畫；和內容一起滑，Codex cat08 #1）
	if slide != Vector2.ZERO:
		mouse = m0
		ui_xf = Transform2D.IDENTITY
		Art.base = Transform2D.IDENTITY
		draw_set_transform_matrix(Transform2D.IDENTITY)
	_draw_intro()   # 1.3.0 §13 掌燈開門（最上層）
	if ok_k < 1.0:
		draw_rect(Rect2(0, 0, 1280, 800), Color(0.08, 0.05, 0.03, 0.55 * (1.0 - ok_k) * (1.0 - ok_k)))
	_draw_pad_footer()
	if toast_t > 0:
		var a := minf(1.0, toast_t * 2)
		var tw := font.get_string_size(toast, HORIZONTAL_ALIGNMENT_LEFT, -1, ts(20)).x + 40
		var ty := 40.0 if overlay != "" else 600.0   # 覆蓋層開著時放上面；平常放在兵種提示條（y 654）上面（第四輪 Antigravity）
		if overlay == "" and _is_free():
			ty = 50.0   # 第六輪：自由擺放整個戰場都可能有兵，提示改蓋在上方的兵種說明條（Codex 實作第 3 輪 #2）
		draw_rect(Rect2(640 - tw / 2, ty, tw, 44), Color(0, 0, 0, (0.94 if bool(Save.s("text_plate")) else 0.72) * a))   # V1.5：高對比文字底板
		_text(Vector2(640, ty + 6), toast, ts(20), Color(1, 0.88, 0.5, a), true)
	if _focus >= _btns.size():
		_focus = 0
	_btns_gen = _gen
	# V9：畫面切換 0.25 秒淡入（版面檢查、簡化特效時不做）
	if _gen != _trans_gen:
		_trans_gen = _gen
		_trans_t = time
	if not layout_probe and not bool(Save.s("reduce_fx")) and time - _trans_t < 0.25:
		draw_rect(Rect2(0, 0, 1280, 800), Color(TH_WOOD_D, 0.9 * (1.0 - (time - _trans_t) / 0.25)))
	# V9：懸停音（換了一顆才響）
	if _hover_now != _hover_key:
		_hover_key = _hover_now
		if _hover_now >= 0 and sfx != null:
			sfx.play("k_hover", 0.28)
	_hover_now = -1



func _pad_footer_items() -> Array:
	if overlay == "codex":
		return [[_pk("place"), L.t("pk_select")], [_pk("back"), L.t("back")], ["R", L.t("pk_scroll")]]
	if overlay != "":
		return [[_pk("place"), L.t("pk_select")], [_pk("back"), L.t("back")]]
	match state:
		St.TITLE:
			return [["＋", L.t("pk_move")], [_pk("place"), L.t("pk_select")]]
		St.BATTLE:
			if play_kind != "official":
				return [[_pk("place"), L.t("pk_select")], [_pk("back"), L.t("back")], [_pk("codex"), L.t("br_title")]]   # 1.1.0 B10
			return [[_pk("place"), L.t("pk_select")], [_pk("back"), L.t("skip")]]
		St.RESULT:
			return [["＋", L.t("pk_move")], [_pk("place"), L.t("pk_select")], [_pk("back"), L.t("menu")]]
	return []

## 手把按鍵提示列（第三輪 U7）：用手把時，每個畫面右下角顯示這個畫面能按的鍵（A／B／X／Y 圓形圖示）；
## 用鍵盤滑鼠時不顯示手把圖示（Steam Deck 規定兩者不能同時出現）。擺放畫面已經在上方列顯示，這裡略過。
func _draw_pad_footer() -> void:
	if not pad_mode or (state == St.PLACE and overlay == ""):
		return
	var items: Array = _pad_footer_items()
	if items.is_empty():
		return
	draw_rect(Rect2(0, 770, 1280, 30), Color(0, 0, 0, 0.45))
	if layout_probe:
		probe_boxes.append({"r": Rect2(0, 770, 1280, 30), "inner": Rect2(0, 766, 1280, 34)})   # 提示列是最上層的底（不是底下兵卡的字）
	_key_hints(640, 773, items, 14)



## 滑鼠停在哪一列：輸入狀態，每幀更新一次（第七輪 H7：原本在繪圖時改狀態）。
func _settings_hover() -> void:
	if overlay != "settings":
		return
	var rows := _settings_rows()
	for i in rows.size():
		if Rect2(340, _settings_row_y(i) - 5, 560, 56).has_point(mouse):
			settings_item = rows[i][0]
	# 手把／鍵盤移焦點時，說明欄跟著焦點那一列（Antigravity v150-i1 #3）
	if pad_mode and _btns_gen == _gen and _focus >= 0 and _focus < _btns.size():
		var fy: float = _btns[_focus]["r"].position.y
		for i in rows.size():
			if absf(fy - _settings_row_y(i)) < 2.0:
				settings_item = rows[i][0]







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
		elif c["kind"] == "pan":
			cam_pan(c["data"])
		elif c["kind"] == "tool":
			if state == St.PLACE and overlay == "":
				call("_deploy_tool", str(c["data"]))
			done += 1
		_update_gen()
	return done



## 點擊：只對這個畫面世代畫出來的按鈕有效。回傳執行了幾個。
## ── 1.2.0 §9.4 宣紙戰報（結果頁前 1.2 秒）──
## 盤面 0.3 秒淡成宣紙 → 陣亡點蓋 8px 朱砂小印、擊倒者到被擊倒者一道淡墨線（40%、最底層）→ 0.55 秒勝負大章蓋下 → 1.0 秒後才出結果面板。
## 點任意處／任何按鍵跳過；截圖、減少特效、重播與覆盤不播。
const INK_DUR := 1.0
func _ink_active() -> bool:
	return _ink_k() < INK_DUR and (shot_dir == "" or ink_force) and not bool(Save.s("reduce_fx")) and play_kind == "official" and not bool(Save.s("plain_ui"))

var ink_force := false   # 截圖流程專拍宣紙戰報時用
func _ink_k() -> float:
	return 0.8 if ink_force else time - result_t   # 截圖專拍時停在蓋章後的瞬間（截圖等幀的實際時間不固定）

func _draw_ink_report_field() -> void:
	var k := _ink_k()
	var pa := clampf(k / 0.3, 0.0, 1.0) * 0.82
	var pt := _ui_tex(MAT["card2"])
	var fr := Rect2(ORIGIN, fld_size)
	if pt != null:
		draw_texture_rect(pt, fr, false, Color(1, 1, 1, pa))
	else:
		draw_rect(fr, Color(Color("#e8d8c3"), pa))
	if k < 0.25 or view == null:
		return
	var a2 := clampf((k - 0.25) / 0.25, 0.0, 1.0)
	for u in view.units:
		if u.alive:
			continue
		var vp := _upos(u)
		var kid: int = int(last_hitter.get(u.id, -1))
		var ku = view.unit_by_id(kid) if kid >= 0 else null
		if ku != null:
			_brush_line(_upos(ku), vp, Color(Color("#261c14"), 0.4 * a2), int(u.id))   # 交戰墨線（最底層、40%）
	for u2 in view.units:
		if not u2.alive:
			var c := _upos(u2)
			# 朱砂小印：圓形印泥（直徑約 8px）＋偏一點的第二層＋中間留白一點（像沒壓滿的印），不是方塊（Antigravity cat03 #3）
			var off := Vector2(float(int(u2.id) * 37 % 5) - 2.0, float(int(u2.id) * 53 % 5) - 2.0) * 0.4
			draw_circle(c, 4.5, Color(Color("#9b281b"), 0.85 * a2), true, -1.0, true)
			draw_circle(c + off, 3.6, Color(Color("#b5361f"), 0.6 * a2), true, -1.0, true)
			draw_circle(c - off * 1.5, 1.2, Color(Color("#efe4cf"), 0.5 * a2), true, -1.0, true)

## 毛筆墨線：起筆細、中段粗、收筆帶飛白（固定種子斷幾小段），取代 1px 幾何直線（Antigravity cat03 #3）
func _brush_line(a: Vector2, b: Vector2, col: Color, seed_i: int) -> void:
	var n := 10
	var nrm := (b - a).orthogonal().normalized()
	for i in n:
		if i >= 6 and (seed_i * 7 + i * 13) % 5 == 0:
			continue   # 飛白：收筆段偶爾斷開
		var t0 := float(i) / n
		var t1 := float(i + 1) / n
		var wv := 1.2 + 3.6 * sin(PI * (t0 + t1) * 0.5) * (1.0 - 0.35 * t0)
		var wob := nrm * sin(t0 * 7.0 + seed_i) * 0.8
		draw_line(a.lerp(b, t0) + wob, a.lerp(b, t1) + wob, col, wv, true)

func _draw_ink_report_screen() -> void:
	var k := _ink_k()
	if k < 0.55 or sim == null:
		return
	var win: bool = sim.winner == 0 or (mode == Mode.DUEL and sim.winner == 1)
	var drop := clampf((k - 0.55) / 0.12, 0.0, 1.0)
	var sc := lerpf(1.6, 1.0, drop)
	var c := Vector2(640, 380)
	var sz := 120.0
	var col := Color("#9b281b") if sim.winner >= 0 else Color("#5a4630")
	var txt: String = L.t("ink_draw") if sim.winner < 0 else (L.t("ink_win") if win else L.t("ink_lose"))
	# 壓下動畫用繪圖變換縮放整個印章，字級固定 T（動畫中不產生表外字級、不換字型，Codex cat03 #4）；介面層本來就是單位變換，畫完還原
	draw_set_transform(c * (1.0 - sc), 0.0, Vector2(sc, sc))   # 以印章中心縮放；座標仍是螢幕座標（版面探針記到的是落定後的位置）
	draw_rect(Rect2(c - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), Color(col, 0.18 * drop))
	draw_rect(Rect2(c - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), Color(col, 0.95 * drop), false, 6.0)
	for kk in 14:   # 印泥沒壓滿的斑駁：框上幾處紙色小缺口（固定位置）
		var side := kk % 4
		var tt := float((kk * 37) % 100) / 100.0
		var pp := c + (Vector2(lerpf(-sz, sz, tt) * 0.5, -sz * 0.5) if side == 0 else (Vector2(lerpf(-sz, sz, tt) * 0.5, sz * 0.5) if side == 1 else (Vector2(-sz * 0.5, lerpf(-sz, sz, tt) * 0.5) if side == 2 else Vector2(sz * 0.5, lerpf(-sz, sz, tt) * 0.5))))
		draw_circle(pp, 1.5 + float(kk % 3), Color(Color("#efe4cf"), 0.7 * drop), true, -1.0, true)
	_text(c - Vector2(0, tz("T") * 0.62), txt, tz("T"), Color(col, drop), true, true)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if drop >= 1.0 and not ink_stamped:
		ink_stamped = true
		if sfx != null:
			sfx.play("place_heavy", 1.0)   # 蓋章聲

var ink_stamped := false

func _do_click(p: Vector2) -> int:
	_toast_dismiss()
	if state == St.RESULT and _ink_active():
		result_t -= INK_DUR   # 1.2.0 §9.4：點任意處跳過宣紙戰報演出
		return 1
	if _btns_gen != _gen:
		return 0
	for i in _btns.size():
		var b: Dictionary = _btns[i]
		if b["r"].has_point(p):
			if b["en"]:
				_focus = i
				if sfx != null:
					sfx.play(str(b.get("snd", "k_click")), 0.7)
				b["cb"].call()
				return 1
			return 0
	return 0


# ── 1.4.0 第 8 大類：桌面世界與轉場（方案 §2；切片 A）──
## 每個疊層在桌上的固定位置（從哪邊滑進來）；沒列的照舊淡入。
const SLIDE_FROM := {"lobby": Vector2(-80, 0), "codex": Vector2(0, 70), "settings": Vector2(80, 0), "keys": Vector2(80, 0),
	"profile": Vector2(0, -60), "puzzles": Vector2(-70, 0), "trials": Vector2(-70, 0), "codes": Vector2(70, 0)}
const SLIDE_SEC := 0.3    # 180～300ms；和 1.3.0 器物開合同長（同時到終態，Codex cat08 #1）
var trans_eat := {}            # 跳過轉場的輸入（來源＋鍵碼＋裝置／手指）→ 各自的放開才解鎖；可能同時好幾個（Codex cat08 r2 #1、r3 #1）
var trans_stick_eat := false   # 用搖桿跳過／轉場中推著搖桿：回中之前不送方向（方案 §2.5）

## 輸入的身分：同一顆鍵／同一個滑鼠鈕／同一根手指的按下與放開對得起來
static func trans_sig(ev: InputEvent) -> String:
	if ev is InputEventKey:
		return "k%d" % int(ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode)
	if ev is InputEventMouseButton:
		return "m%d" % int(ev.button_index)
	if ev is InputEventJoypadButton:
		return "j%d:%d" % [ev.device, int(ev.button_index)]
	if ev is InputEventScreenTouch:
		return "t%d" % int(ev.index)
	return ""

## 轉場的輸入閘門（在 _input 最前面）：轉場中任何按下＝跳到終態並吃掉，連同同一個輸入的放開（含按住的連發）；
## 拖曳、滾輪、捲動、hover 在轉場中都不生效（Codex cat08 #2～#5）。回傳 true＝這個事件吃掉。
func _trans_gate(ev: InputEvent) -> bool:
	var active := ov_trans_k() < 1.0
	if not active and trans_eat.is_empty():
		return false
	if ev is InputEventMouseMotion:
		mouse = ev.position
		return active
	if ev is InputEventJoypadMotion:
		if ev.axis == JOY_AXIS_LEFT_X or ev.axis == JOY_AXIS_LEFT_Y:
			stick[ev.axis] = ev.axis_value   # 狀態照記
			if active and absf(ev.axis_value) >= int(Save.s("deadzone")) / 100.0:
				_ov_t = time - 1.0       # 推搖桿本身也是跳過（Codex cat08 r5 #1）
				trans_stick_eat = true   # 轉場中收到有效軸輸入當下就鎖（不靠逐幀時轉場還在；同幀再按鍵跳過也鎖著，Codex cat08 r4 #1）
		return active
	var sig := trans_sig(ev)
	if sig == "":
		return active
	if ev is InputEventScreenTouch and not ev.pressed:
		touches.erase(ev.index)   # 吃掉放開也要清手指狀態（不留幽靈手指、長按計時；Codex cat08 r2 #3）
		lp_t = -1.0
	if ev.pressed:
		if active:
			_ov_t = time - 1.0
			trans_eat[sig] = true
			return true
		return trans_eat.has(sig)   # 同一顆鍵按住的連發（echo）也吃
	if trans_eat.has(sig):
		trans_eat.erase(sig)
		return true
	return active

## 疊層剛換（轉場開始）：取消進行中的長按（不從計時器繞過閘門）；開頁前就推著的搖桿鎖到回中（Codex cat08 r3 #2、#3）
func _trans_begin() -> void:
	if ov_trans_k() >= 1.0:
		return
	lp_t = -1.0
	var dz := int(Save.s("deadzone")) / 100.0
	if absf(float(stick.get(JOY_AXIS_LEFT_X, 0.0))) >= dz or absf(float(stick.get(JOY_AXIS_LEFT_Y, 0.0))) >= dz:
		trans_stick_eat = true

## 手把拔掉：引擎不補放開事件 → 清掉那支手把的跳過身分與搖桿狀態（Codex cat08 r3 #4）
func _trans_joy_changed(device: int, connected: bool) -> void:
	if connected:
		return
	for k in trans_eat.keys():
		if String(k).begins_with("j%d:" % device):
			trans_eat.erase(k)
	stick[JOY_AXIS_LEFT_X] = 0.0
	stick[JOY_AXIS_LEFT_Y] = 0.0
	trans_stick_eat = false

## 轉場進度（0→1；沒有轉場＝1）。截圖、版面檢查、減少特效、減少動態、簡化介面都沒有轉場。
func ov_trans_k() -> float:
	if overlay == "" or not SLIDE_FROM.has(overlay) or shot_dir != "" or layout_probe or bool(Save.s("reduce_fx")) or bool(Save.s("reduce_motion")) or bool(Save.s("plain_ui")):
		return 1.0
	return clampf((time - _ov_t) / SLIDE_SEC, 0.0, 1.0)

func ov_slide_offset() -> Vector2:
	var k := ov_trans_k()
	if k >= 1.0:
		return Vector2.ZERO
	var e := 1.0 - pow(1.0 - k, 3.0)
	return SLIDE_FROM[overlay] * (1.0 - e)
