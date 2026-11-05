extends "res://scripts/ui/screens/game_modes.gd"
## 由 game_screens.gd 拆出（V9 P1，行為不變）

## 第八輪成就：贏的那隊。沙盒不算（改過數值）。
## 標題選單進遠征：解鎖奇幻軍之後才要選，否則直接開打（新手不多一步）。
func _enter_gauntlet() -> void:
	if _demo():
		_toast(L.t("demo_locked"), true)
		return
	if not Save.data.get("gauntlet_run", {}).is_empty():
		overlay = "gauntlet_resume"
		_focus = 0
		return
	_enter_gauntlet_new()

func _enter_gauntlet_new() -> void:
	call("_gauntlet_clear")
	if RuleSet.has_new(RS.unlocked_mask(_unlock_games(), _demo())):
		overlay = "gauntlet_pick"
	else:
		_start_gauntlet_with(0)



func _start_gauntlet_with(pool: int) -> void:
	Save.data["gauntlet_pool"] = pool
	overlay = ""
	_start_mode(Mode.GAUNTLET)



func _draw_gauntlet_pick() -> void:
	var mask: int = RS.unlocked_mask(_unlock_games(), _demo())
	var opts: Array = [
		[L.t("lb_army_kingdom"), mask & RuleSet.all_pool()],
		[L.t("lb_army_fantasy"), Presets.fantasy_pool(mask)],
	]
	var last: int = _gauntlet_last_pool()
	if last > 0 and last != opts[0][1] and last != opts[1][1]:
		opts.append([L.t("gp_last"), last])
	var pick_h := 160.0 + opts.size() * 128.0 + 60.0     # 第十輪 V7：面板依內容高度
	_panel(Rect2(240, 120, 800, pick_h))
	_h1(Vector2(640, 124), L.t("gp_title"))
	_text(Vector2(640, 182), L.t("gp_note"), tz("S"), Color(1, 1, 1, 0.75), true)
	for i in opts.size():
		var r := Rect2(280, 226 + i * 128, 720, 116)
		var pool: int = opts[i][1]
		_btn(r, "", _start_gauntlet_with.bind(pool), true, false, Color(0.16, 0.18, 0.26))
		_text(r.position + Vector2(16, 6), opts[i][0], tz("B"), ACCENT, false, true)
		_draw_pool_heads(r.position + Vector2(16, 44), pool, 58.0)
	_btn(Rect2(560, 120 + pick_h - 54, 160, 40), L.t("back"), func(): overlay = "")



func _draw_keys() -> void:
	_panel(Rect2(190, 60, 900, 680))
	_h1(Vector2(640, 62), L.t("keys_title"))
	var y0 := 140.0
	_text(Vector2(240, y0), L.t("keys_kb"), tz("B"), ACCENT, false, true)
	_text(Vector2(690, y0), L.t("keys_pad"), tz("B"), ACCENT, false, true)
	y0 += tz("B") * 1.6
	var kt: Dictionary = Save.s("keys")
	var pt: Dictionary = Save.s("pad")
	for i in Keymap.ACTIONS.size():
		var act: String = Keymap.ACTIONS[i][0]
		var y := y0 + i * 50
		_text(Vector2(240, y + 8), L.t("key_" + act), tz("S"), Color.WHITE, false, false, 200)
		var cap := keys_capture == "kb:" + act
		_btn(Rect2(450, y, 170, 42), "…" if cap else Keymap.key_name(kt, act), func(): keys_capture = "kb:" + act)
	for i2 in Keymap.PAD_ACTIONS.size():
		var act2: String = Keymap.PAD_ACTIONS[i2][0]
		var y2 := y0 + i2 * 50
		_text(Vector2(690, y2 + 8), L.t("key_" + act2), tz("S"), Color.WHITE, false, false, 200)
		var cap2 := keys_capture == "pad:" + act2
		_btn(Rect2(900, y2, 150, 42), "…" if cap2 else _pk(act2), func(): keys_capture = "pad:" + act2)
	if keys_capture != "":
		_text(Vector2(640, 610), L.t("keys_press"), tz("B"), ACCENT, true, true, 800)
	_btn(Rect2(380, 672, 240, 44), L.t("keys_reset"), func(): Save.settings["keys"] = {}; Save.settings["pad"] = {}; Save.save_settings())
	_btn(Rect2(660, 672, 240, 44), L.t("back"), func(): keys_capture = ""; overlay = "settings")



func _stick_repeat(delta: float) -> void:
	if _is_free() and overlay == "":
		_fp_pad_process(delta, Vector2(stick[JOY_AXIS_LEFT_X], stick[JOY_AXIS_LEFT_Y]))   # 第六輪：平滑游標
		return
	var d := _stick_dir
	for ax in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		var v: float = stick[ax]
		var cur: int = d.x if ax == JOY_AXIS_LEFT_X else d.y
		var nv := cur
		if absf(v) > 0.6:
			nv = 1 if v > 0 else -1
		elif absf(v) < 0.35:
			nv = 0
		if ax == JOY_AXIS_LEFT_X:
			d.x = nv
		else:
			d.y = nv
	if d != _stick_dir:
		_stick_dir = d
		_stick_t = 0.35
		_stick_fire()
	elif d != Vector2i.ZERO:
		_stick_t -= delta
		if _stick_t <= 0.0:
			_stick_t += 0.12
			_stick_fire()


func _stick_fire() -> void:
	if _stick_dir.x != 0:
		_enqueue("key", KEY_RIGHT if _stick_dir.x > 0 else KEY_LEFT)
	if _stick_dir.y != 0:
		_enqueue("key", KEY_DOWN if _stick_dir.y > 0 else KEY_UP)



func _start_free_intro() -> void:
	overlay = ""
	lobby_kind = "ai"
	lobby_r = Presets.make("standard", "ai", _lobby_unlocked())
	lobby_r.rounds = 1
	lobby_r.ai_level = 0
	rules = lobby_r.copy()
	difficulty = 0
	_start_mode(Mode.VS_AI)
	free_intro = true
	free_intro_moved = false



func _draw_save_notice() -> void:
	var msg := ""
	if Save.data_locked:
		msg = L.t("save_locked")
	elif Save.data_source == "bak":
		msg = L.t("save_from_backup")
	elif Save.has_unsaved():
		msg = L.t("save_failed")
	if msg == "":
		return
	var h := text_h(msg, tz("S"), 760) + 14
	draw_rect(Rect2(490, 8, 780, h), Color(0.35, 0.12, 0.08, 0.92))
	_text(Vector2(500, 12 + tz("S")), msg, tz("S"), Color("#ffe8c8"), false, false, 760)



func _draw_title() -> void:
	draw_rect(Rect2(0, 0, 1280, 800), Color(0.05, 0.06, 0.1, 0.18))
	if overlay != "":
		return
	_draw_save_notice()
	# 第七輪 D4：右下角色群像
	for i in D.COUNT:
		var gp := Vector2(544.0 + i * 70.0, 720.0 + (i % 2) * 22.0)
		Art.unit(self, gp, i, i % 2, 1.0 if i % 2 == 0 else -1.0, 0.0, 0.0, 0.0, 1.0, time + i, 1.25, cbm())
	var bob := sin(time * 1.5) * 4
	# 第五輪 §4.4：主選單收成左側一塊面板，背景的自動對決露出來；標題用標題字
	var dk := Color(0.11, 0.075, 0.05, 0.86)
	var cl := Color(0.11, 0.075, 0.05, 0.0)
	var pr := Rect2(0, 0, 470, 800)
	draw_polygon(PackedVector2Array([pr.position, Vector2(pr.end.x, 0), Vector2(pr.end.x, 800), Vector2(0, 800)]), PackedColorArray([dk, dk, dk, dk]))
	draw_polygon(PackedVector2Array([Vector2(pr.end.x, 0), Vector2(pr.end.x + 120, 0), Vector2(pr.end.x + 120, 800), Vector2(pr.end.x, 800)]), PackedColorArray([dk, cl, cl, dk]))
	var tsz := tcap(tz("DX"), 92)
	var tt: String = L.t("title")
	var tf: Font = font_title if (font_title != null and not bool(Save.s("plain_titles"))) else font_bold
	var tw := tf.get_string_size(tt, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz).x
	if tw > 430.0:
		tsz = int(tsz * 430.0 / tw)   # 第七輪：英文 150% 標題原本超出畫面左邊
		tw = tf.get_string_size(tt, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz).x
	var tp := Vector2(235 - tw / 2, 40 + bob + tsz * 0.85)
	for d in 4:
		draw_string(tf, tp + Vector2(1, 1) * (d + 1) * 1.6, tt, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, Color(0.32, 0.17, 0.04, 0.9))
	draw_string_outline(tf, tp, tt, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, 9, Color("#3a2205"))
	draw_string_outline(tf, tp, tt, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, 5, Color("#b8860b"))
	draw_string(tf, tp, tt, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, Color("#ffe8a3"))
	var ty := 40.0 + tsz * 1.2
	_text(Vector2(235, ty), "No Take-Backs" if L.lang == "zh_TW" else "落子無悔", tz("B"), Color(1, 1, 1, 0.85), true, false, 420)
	ty += tz("B") * 1.4
	_text(Vector2(235, ty), L.t("subtitle"), tz("S"), Color(1, 1, 1, 0.8), true, false, 420)
	ty += text_h(L.t("subtitle"), tz("S"), 420) + 18
	var y0 := maxf(250.0, ty)
	# 第七輪 E7：四顆主玩法有兵種圖示與亮邊；其餘縮小。新手第一次進來，主推教學（A4）
	var fresh := _is_new_player()
	var main := [["menu_tutorial" if fresh else "menu_vs_ai", (func(): _open("tutorial")) if fresh else (func(): _open_lobby("ai")), 0],
		["menu_vs_ai" if fresh else "menu_duel", (func(): _open_lobby("ai")) if fresh else (func(): _open_lobby("duel")), 3],
		["menu_duel" if fresh else "menu_gauntlet", (func(): _open_lobby("duel")) if fresh else (func(): _enter_gauntlet()), 1],
		["menu_gauntlet" if fresh else "menu_tutorial", (func(): _enter_gauntlet()) if fresh else (func(): _open("tutorial")), 4 if fresh else 2]]
	for i in main.size():
		var mr2 := Rect2(70, y0 + i * 60, 330, 52)
		_btn(mr2, "　　" + L.t(main[i][0]), main[i][1], not (_demo() and main[i][0] == "menu_gauntlet"), i == 0)
		draw_rect(Rect2(mr2.position, Vector2(4, mr2.size.y)), ACCENT if i == 0 else Color(1, 1, 1, 0.35))
		Art.unit(self, mr2.position + Vector2(32, 48), int(main[i][2]), 0, 1.0, 0.0, 0.0, 0.0, 1.0, time, 0.72, cbm())
	if fresh:
		var pulse := 0.5 + 0.5 * sin(time * 3.0)
		draw_rect(Rect2(68, y0 - 2, 334, 56), Color(ACCENT, 0.5 + 0.5 * pulse), false, 3.0)
	var y1 := y0 + 4 * 60 + 8
	# 第十輪 V3：4 主＋4 次＋一列系統鈕；製作名單進設定，代碼類合成一顆
	_btn(Rect2(70, y1, 162, 44), L.t("menu_puzzle"), func(): _open("puzzles"))
	_btn(Rect2(238, y1, 162, 44), L.t("menu_codex"), func(): _open_codex(0))
	y1 += 50
	_btn(Rect2(70, y1, 162, 44), L.t("menu_trials"), func(): _open("trials"))
	_btn(Rect2(238, y1, 162, 44), L.t("menu_profile"), func(): _open("profile"))
	var y2 := y1 + 54
	var sys := [["menu_settings", func(): _open("settings")], ["menu_codes", func(): overlay = "codes"; _focus = 0], ["menu_quit", func(): get_tree().quit()]]
	for i in sys.size():
		_btn(Rect2(70 + i * 112, y2, 106, 38), L.t(sys[i][0]), sys[i][1], true, false, Color(TH_WOOD_D, 0.92))
	# 底部：解鎖進度＋最佳紀錄
	var demo_b := _demo()
	var um := RS.unlocked_mask(_unlock_games(), demo_b)
	var n := RuleSet.pool_count(um)
	var cap := RS.DEMO_MAX + 1 if demo_b else D.total()
	var prog := L.t("unlock_prog", [n, cap])
	if n < cap:
		var nx_t := -1
		var nx_g := 99999
		for ti in D.total():
			var g2: int = RS.games_to_unlock(ti, _unlock_games(), demo_b)
			if g2 > 0 and g2 < nx_g:
				nx_g = g2
				nx_t = ti
		if nx_t >= 0:
			prog += "　" + L.t("unlock_next", [nx_g, L.t("unit_%d" % nx_t)])
	_text(Vector2(70, 728), prog, tz("S"), Color(1, 1, 1, 0.8), false, false, 380)
	_text(Vector2(70, 728 + tz("S") * 1.4), "%s　｜　v%s" % [L.t("gauntlet_best", [int(Save.data.get("gauntlet_best", 0))]), str(ProjectSettings.get_setting("application/config/version"))], tz("C"), Color(1, 1, 1, 0.6), false, false, 380)



func _pick_puzzle(id: String, tut: bool) -> void:
	puzzle_id = id
	_start_mode(Mode.TUTORIAL if tut else Mode.PUZZLE)



# ── 覆蓋層 ──
func _draw_overlay() -> void:
	if overlay != "":
		_btns.clear()   # 覆蓋層底下畫面的按鈕不能被點到（例如擺放畫面的開戰、結果頁的按鈕）
		probe_texts.clear()   # 第五輪：底下畫面的字被遮罩蓋住，版面檢查只量覆蓋層本身
		probe_btns.clear()
		probe_ctrls.clear()
		if state == St.TITLE:
			draw_rect(Rect2(0, 0, 1280, 800), Color(0, 0, 0, 0.72))   # 第七輪：標題的示範戰場不透出來
	match overlay:
		"trials":
			_draw_trials()
		"profile":
			_draw_profile()
		"reward":
			_draw_reward()
		"ban":
			_draw_ban()
		"ai_busy":
			_draw_busy(-1)
		"codes":
			_panel(Rect2(340, 250, 600, 300))
			_h1(Vector2(640, 254), L.t("menu_codes"))
			_text(Vector2(640, 316), L.t("codes_hint"), tz("S"), Color(1, 1, 1, 0.8), true, false, 540)
			_btn(Rect2(380, 370, 250, 52), L.t("bc_watch"), func(): overlay = ""; _watch_battle_code())
			_btn(Rect2(650, 370, 250, 52), L.t("ch_accept"), func(): overlay = ""; _accept_challenge())
			_btn(Rect2(560, 480, 160, 44), L.t("back"), func(): overlay = "")
		"gauntlet_resume":
			_panel(Rect2(340, 250, 600, 300))
			_h1(Vector2(640, 254), L.t("menu_gauntlet"))
			_text(Vector2(640, 320), L.t("gr_body", [int(Save.data["gauntlet_run"]["stage"])]), tz("B"), Color.WHITE, true, true, 540)
			_btn(Rect2(380, 380, 520, 52), L.t("gr_go"), func(): call("_gauntlet_resume"), true, true)
			_btn(Rect2(380, 442, 250, 44), L.t("gr_new"), func(): _enter_gauntlet_new())
			_btn(Rect2(650, 442, 250, 44), L.t("back"), func(): overlay = "")
		"leave":
			_panel(Rect2(340, 270, 600, 260))
			_text(Vector2(640, 294), L.t("leave_title"), tz("H2"), Color.WHITE, true, true, 540)
			_text(Vector2(640, 354), L.t("leave_body_gauntlet") if mode == Mode.GAUNTLET else L.t("leave_body_series"), tz("B"), Color(1, 1, 1, 0.85), true, false, 540)
			_btn(Rect2(380, 450, 250, 52), L.t("leave_stay"), func(): overlay = "", true, true)
			_btn(Rect2(650, 450, 250, 52), L.t("leave_go"), func(): _leave_confirm())
		"tutorial", "puzzles":
			var tut := overlay == "tutorial"
			var tabs0 := [PZ.puzzles(), PZ.new_puzzles(), PZ.fantasy_puzzles()]
			var list: Array = PZ.tutorials() if tut else tabs0[puzzle_tab]
			var stars: Dictionary = Save.data.get("puzzle_stars", {})
			var tdone := int(Save.data.get("tutorial", 0))
			var unlocked := tut or tdone >= 1
			_panel(Rect2(240, 110, 800, 580))
			_text(Vector2(640, 114), L.t("menu_tutorial") if tut else L.t("puzzle_title"), ts(26), Color.WHITE, true, true)
			if not tut and unlocked:
				# 兩個分頁：經典殘局／新兵試玩（第四輪 §4.8）；頁籤上直接寫各自的總星數（第三輪 U4）
				var tabs := tabs0
				for ti in 3:
					var total := 0
					for pz0 in tabs[ti]:
						total += int(stars.get(pz0["id"], 0))
					var lbl := "%s　★ %d／%d" % [L.t("puzzle_tab_%d" % ti), total, tabs[ti].size() * 3]
					_btn(Rect2(280 + ti * 244, 160, 232, 36), lbl, func(): puzzle_tab = ti, true, false, TH_ACTIVE if ti == puzzle_tab else Color(0, 0, 0, 0))
			if not unlocked:
				_text(Vector2(640, 172), L.t("puzzle_locked"), ts(16), ACCENT, true)
			for i in list.size():
				var pz: Dictionary = list[i]
				var r := Rect2(280 + (i % 2) * 370, 210 + (i / 2) * 82, 350, 68)
				var name: String = pz["zh"] if L.lang == "zh_TW" else pz["en"]
				var st := int(stars.get(pz["id"], 0))
				var en: bool = unlocked and (not tut or i <= tdone) and (not _demo() or tut or (puzzle_tab == 0 and i < Presets.DEMO_PUZZLES))
				var line := "%s%d. %s　%s" % ["✓ " if st > 0 else "", i + 1, name, "★".repeat(st) + "☆".repeat(3 - st)]
				if pz.has("unit"):
					# 新兵試玩：那個兵種解鎖後才能玩
					var left := RS.games_to_unlock(int(pz["unit"]), _unlock_games(), _demo())
					if left != 0:
						en = false
						line = "%d. %s（%s）" % [i + 1, name, L.t("locked_demo") if left < 0 else L.t("locked_short", [left])]
				# 第七輪：標籤靠左、讓開左邊的迷你敵陣（原本置中會被縮圖蓋住）
				_btn(r, "", _pick_puzzle.bind(pz["id"], tut), en, false,
					Color(0.15, 0.32, 0.22) if st > 0 else Color(0, 0, 0, 0))
				_probe_btn_label = true
				_probe_btn_rect = r
				_text(r.position + Vector2(64, 8), line, tz("S"), Color.WHITE if en else Color(1, 1, 1, 0.4), false, false, r.size.x - 72)
				_probe_btn_label = false
				# 第七輪 E12：關卡鈕直接看得到預算、可用兵種、星級條件
				# 關卡名稱換行時（英文大字）就不再放預覽，避免互壓
				if not tut and en and text_h(line, tz("S"), r.size.x - 72) <= tz("S") * 1.6:
					var note: String = L.t("puzzle_note", [int(pz["budget"]), int(pz["star3"])])
					_probe_btn_label = true
					_probe_btn_rect = r
					_text(r.position + Vector2(62, r.size.y - tz("C") * 1.25), note, tz("C"), Color(1, 0.9, 0.6, 0.85), false, false, r.size.x - 70)
					_probe_btn_label = false
				# 主角兵種小頭像（R6）：這關第一個可用的兵種
				_mini_formation(Rect2(r.position + Vector2(6, 6), Vector2(52, 56)), pz, en)   # 迷你敵陣縮圖（第三輪 U4）
			if tut:
				# 第七輪 A4：自由排兵入門（畫筆、搬移、開戰），一步一步帶
				var fr := Rect2(280 + (list.size() % 2) * 370, 210 + (list.size() / 2) * 82, 350, 68)
				_btn(fr, ("✓ " if bool(Save.data.get("free_intro_done", false)) else "") + L.t("intro_btn"), func(): _start_free_intro(), true, false,
					Color(0.15, 0.32, 0.22) if bool(Save.data.get("free_intro_done", false)) else Color(0, 0, 0, 0))
			_btn(Rect2(560, 640, 160, 36), L.t("back"), func(): overlay = "")
		"lobby":
			_draw_lobby()
		"settings":
			_draw_settings()
		"keys":
			_draw_keys()
		"credits":
			_panel(Rect2(200, 70, 880, 660))
			_h1(Vector2(640, 76), L.t("credits_title"))
			_text(Vector2(240, 140), FileAccess.get_file_as_string("res://data/credits.txt"), ts(13), Color(1, 1, 1, 0.88))
			_btn(Rect2(560, 680, 160, 36), L.t("back"), func(): overlay = "")
		"slots":
			_draw_slots()
		"gauntlet_pick":
			_draw_gauntlet_pick()
		"codex":
			_draw_codex()
		"review":
			_draw_review()



## 設定（第五輪 §4.4）：四組分頁＋右側說明欄；多選項用 ◀ ▶；遊戲規則已經搬到規則大廳。
func _settings_rows() -> Array:
	var groups := {
		0: [["set_lang", L.t("lang_name"), func(d): _cycle_setting("lang", ["zh_TW", "en"]); L.lang = Save.s("lang")],
			["set_text", "%d%%" % int(Save.s("text_scale")), func(d): _step_setting("text_scale", [100, 125, 150], d)],
			["set_plain_titles", _onoff("plain_titles"), func(d): _cycle_setting("plain_titles", [false, true])],
			["set_fullscreen", _onoff("fullscreen"), func(d): _cycle_setting("fullscreen", [false, true]); _apply_fullscreen()]],
		1: [["set_music", "%d%%" % int(Save.s("music")), func(d): _step_setting("music", [0, 30, 50, 70, 100], d); sfx.set_volumes(int(Save.s("sfx")), int(Save.s("music")))],
			["set_sfx", "%d%%" % int(Save.s("sfx")), func(d): _step_setting("sfx", [0, 30, 50, 80, 100], d); sfx.set_volumes(int(Save.s("sfx")), int(Save.s("music")))]],
		2: [["set_speed", "%s×" % _fmt_num(float(Save.s("speed"))), func(d): _step_setting("speed", [0.5, 1.0, 2.0], d)],
			["set_confirm", _onoff("confirm_place"), func(d): _cycle_setting("confirm_place", [true, false])],
			["set_unlock_all", _onoff("unlock_all"), func(d): _cycle_setting("unlock_all", [false, true])],
			["set_playtest", _onoff("playtest"), func(d): _cycle_setting("playtest", [false, true])],
			["set_keys", L.t("open_it"), func(d): _open("keys")]],
		3: [["set_cb", _onoff("colorblind"), func(d): _cycle_setting("colorblind", [false, true]); _rebuild_sprites()],
			["set_shake", _onoff("shake"), func(d): _cycle_setting("shake", [true, false])],
			["set_slowmo", _onoff("slowmo"), func(d): _cycle_setting("slowmo", [true, false])],
			["set_flash", _onoff("flash"), func(d): _cycle_setting("flash", [true, false])],
			["set_reduce_fx", _onoff("reduce_fx"), func(d): _cycle_setting("reduce_fx", [false, true])]],
	}
	return groups[settings_tab]



func _draw_settings() -> void:
	_panel(Rect2(140, 130, 1000, 540))     # 第十輪 V7：最多 5 列，面板縮到內容
	_h1(Vector2(640, 134), L.t("settings_title"))
	for i in 4:
		_btn(Rect2(170, 196 + i * 60, 180, 50), L.t("set_tab_%d" % i), func(): settings_tab = i; settings_item = "", true, false,
			TH_ACTIVE if i == settings_tab else Color(0, 0, 0, 0))
	var rows: Array = _settings_rows()
	for i in rows.size():
		var y := 196 + i * 66
		if i % 2 == 0:
			draw_rect(Rect2(370, y - 6, 524, 64), Color(1, 1, 1, 0.04))   # 第七輪 E11：斑馬底色
		_text(Vector2(380, y + 13), L.t(rows[i][0]), tz("B"), Color.WHITE, false, false, 240)
		var val: String = rows[i][1]
		var cb: Callable = rows[i][2]
		var r := Rect2(620, y, 260, 52)
		_btn(Rect2(r.position, Vector2(48, r.size.y)), "◀", cb.bind(-1))
		var tint := Color(0.16, 0.5, 0.3) if val == L.t("on") else TH_WOOD_D
		_btn(Rect2(r.position + Vector2(54, 0), Vector2(r.size.x - 108, r.size.y)), val, cb.bind(1), true, false, tint)
		_btn(Rect2(r.end.x - 48, r.position.y, 48, r.size.y), "▶", cb.bind(1))
		if val.ends_with("%") and rows[i][0] in ["set_music", "set_sfx"]:
			draw_rect(Rect2(r.position.x + 60, y + 44, (r.size.x - 120) * int(val.trim_suffix("%")) / 100.0, 4), ACCENT)
	# 說明欄
	var D0 := Rect2(900, 196, 220, 400)
	draw_rect(D0, Color(0, 0, 0, 0.25))
	var key: String = settings_item if settings_item != "" else rows[0][0]
	_text(D0.position + Vector2(14, 12), L.t(key), tz("B"), ACCENT, false, true, D0.size.x - 28)
	_text(D0.position + Vector2(14, 12 + tz("B") * 1.6), L.t("sd_" + key), tz("S"), Color(1, 1, 1, 0.85), false, false, D0.size.x - 28)
	if bool(Save.s("playtest")) and settings_tab == 2:
		_btn(Rect2(380, 196 + rows.size() * 66, 240, 44), L.t("pt_folder"), func(): OS.shell_open(ProjectSettings.globalize_path("user://")))
	_btn(Rect2(560, 612, 160, 44), L.t("back"), func(): overlay = "")
	_btn(Rect2(380, 612, 160, 44), L.t("menu_credits"), func(): _open("credits"))



## ◀ ▶ 往前／往後切換設定值（第五輪）。
func _step_setting(k: String, opts: Array, d: int) -> void:
	var cur = Save.s(k)
	var i := 0
	for j in opts.size():
		if str(opts[j]) == str(cur):
			i = j
	Save.set_setting(k, opts[clampi(i + d, 0, opts.size() - 1)])



func _draw_slots() -> void:
	_panel(Rect2(330, 150, 620, 500))
	_text(Vector2(640, 166), L.t("code_title"), ts(24), Color.WHITE, true, true)
	var slots: Array = Save.data.get("slots", ["", "", "", "", ""])
	for i in 5:
		var y := 220 + i * 62
		var code: String = slots[i]
		var desc := L.t("empty")
		var can_load := code != ""
		var note := ""
		if code != "":
			var tmp = _decode_any(code)
			if not tmp is String:
				var cnt := D.zeros()
				for u in tmp.units:
					cnt[u["type"]] += 1
				desc = _comp_desc(cnt)
				if rules != null:
					# 第五輪：預先算這一局的規則下會拿掉幾隻（Codex 實作第 2 輪：載入前就告訴玩家）
					var n_ok := _slot_fit_count(tmp)
					if n_ok == 0:
						can_load = false
						note = L.t("slot_none_fit")
					elif n_ok < tmp.units.size():
						note = L.t("slot_will_drop", [tmp.units.size() - n_ok])
			else:
				can_load = false
		var tag := ""
		if code != "":
			tag = "［%s］" % L.t("lb_deploy_short_free" if code.begins_with("NTB5.") else "lb_deploy_short_grid")   # 存檔格標自由／格子
		var head := "%s　%s%s" % [L.t("slot", [i + 1]), tag, desc]
		_text(Vector2(360, y + 4), head, ts(16), Color.WHITE, false, false, 330)
		if note != "":
			_text(Vector2(360, y + 4 + text_h(head, ts(16), 330)), note, tz("C"), Color("#ffb4a0"), false, false, 330)   # 依組成實際換行後的高度往下排
		_btn(Rect2(700, y, 100, 42), L.t("save"), _slot_save.bind(i))
		_btn(Rect2(810, y, 100, 42), L.t("load"), _slot_load.bind(i), can_load)
	_btn(Rect2(370, 540, 260, 42), L.t("copy_code"), func(): DisplayServer.clipboard_set(armies[0].to_code()); _toast(L.t("code_copied")))
	_btn(Rect2(650, 540, 260, 42), L.t("paste_code"), func(): _paste_code())
	_btn(Rect2(560, 600, 160, 36), L.t("back"), func(): overlay = "")



## 這個陣型在這一局的規則下能放上去幾隻（跟 _load_checked 同一套：先戰鬥兵、保留戰鬥兵名額）。
func _slot_fit_count(raw) -> int:
	var keep = armies[0].copy()
	keep.units = []
	keep.guard_combat = true
	var ordered: Array = raw.units.duplicate()
	ordered.sort_custom(func(p, q): return (0 if not D.is_support(int(p["type"])) else 1) < (0 if not D.is_support(int(q["type"])) else 1))
	var n := 0
	for u in ordered:
		if _place_from(keep, u):
			n += 1
	return n



func _slot_save(i: int) -> void:
	var slots: Array = Save.data.get("slots", ["", "", "", "", ""])
	slots[i] = armies[0].to_code()
	Save.data["slots"] = slots
	if Save.save_data():
		_toast(L.t("slot", [i + 1]) + " ✓")
	else:
		_toast(L.t("save_failed"), true)



func _slot_load(i: int) -> void:
	var slots: Array = Save.data.get("slots", ["", "", "", "", ""])
	var why := _load_checked(str(slots[i]))
	_toast(L.t("code_loaded") if why == "" else (L.t("code_locked") if why == "locked" else L.t("code_bad")), why != "")
	overlay = ""



func _paste_code() -> void:
	var why := _load_checked(DisplayServer.clipboard_get())
	_toast(L.t("code_loaded") if why == "" else (L.t("code_locked") if why == "locked" else L.t("code_bad")), why != "")
	if why == "":
		overlay = ""
