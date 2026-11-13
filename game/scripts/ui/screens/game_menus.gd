extends "res://scripts/ui/screens/game_playroom.gd"
const Guide = preload("res://scripts/game/guide.gd")
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
	if RuleSet.has_new(RS.mask(_demo())):
		overlay = "gauntlet_pick"
	else:
		_start_gauntlet_with(0)



func _start_gauntlet_with(pool: int) -> void:
	Save.data["gauntlet_pool"] = pool
	overlay = ""
	_start_mode(Mode.GAUNTLET)



func _draw_gauntlet_pick() -> void:
	var mask: int = RS.mask(_demo())
	var opts: Array = [
		[L.t("lb_army_kingdom"), mask & RuleSet.all_pool()],
		[L.t("lb_army_fantasy"), Presets.fantasy_pool(mask)],
	]
	var last: int = _gauntlet_last_pool()
	if last > 0 and last != opts[0][1] and last != opts[1][1]:
		opts.append([L.t("gp_last"), last])
	# 第十輪 V7：面板依內容高度；V1.5.2 L3：說明從緞帶下緣＋16、選項從說明下緣＋16 起，面板置中
	var GP := modal_rect(800, 4.0 + h1_help_h(L.t("gp_note"), tz("S"), 700) + opts.size() * 128.0 - 12.0 + GAP_XL + 40.0 + GAP_L)
	_panel(GP)
	var oy := _h1_help(Vector2(640, GP.position.y + 4), L.t("gp_title"), L.t("gp_note"), tz("S"), 700)
	for i in opts.size():
		var r := Rect2(280, oy + i * 128, 720, 116)
		var pool: int = opts[i][1]
		_btn(r, "", _start_gauntlet_with.bind(pool), true, false, TH_WOOD)
		_text(r.position + Vector2(16, 6), opts[i][0], tz("B"), ACCENT, false, true)
		_draw_pool_heads(r.position + Vector2(16, 44), pool, 58.0)
	_btn(Rect2(560, GP.end.y - GAP_L - 40.0, 160, 40), L.t("back"), func(): overlay = "")



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
		if absf(v) > int(Save.s("deadzone")) / 100.0 + 0.25:   # V1.5.1：觸發門檻＝死區＋25%（原本 maxf(0.6, …) 讓 5～40% 的設定都被 0.6 吃掉）
			nv = 1 if v > 0 else -1
		elif absf(v) < int(Save.s("deadzone")) / 100.0:
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
	set("challenge_army", null)
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



const HOME_CX := 255.0   # V1.5.2 L5：主畫面左欄中線（木牌 70～440 的中線）

func _draw_title() -> void:
	draw_rect(Rect2(0, 0, 1280, 800), Color(0.05, 0.06, 0.1, 0.18))
	if overlay != "":
		return
	_draw_save_notice()
	# 第七輪 D4：右下角色群像
	if not bool(Save.s("plain_ui")):
		# V1.2.1 R4：兵站在一座木台上（上表面透視梯形＋前面側邊），不再浮在黑底上
		var top := PackedVector2Array([Vector2(512, 708), Vector2(1214, 708), Vector2(1236, 752), Vector2(490, 752)])
		draw_colored_polygon(top, Color("#6b4a2e"))
		for k in 5:
			var yk := 714.0 + k * 8.0
			draw_line(Vector2(512 - (yk - 708) * 0.5, yk), Vector2(1214 + (yk - 708) * 0.5, yk), Color(0.25, 0.15, 0.08, 0.35), 1.0)
		draw_line(Vector2(512, 708), Vector2(1214, 708), Color(1, 0.85, 0.6, 0.3), 1.5)
		_tex_box(Rect2(490, 752, 746, 22), "wood", Color(0.45, 0.3, 0.19))
		draw_rect(Rect2(490, 774, 746, 6), Color(0, 0, 0, 0.35))
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
	# V1.5.2 L5：標題、木牌列、系統鈕共用左欄中線 HOME_CX；標題限寬算完整包絡（字寬＋木牌左右 34＋雙劍光圈 26×2），左緣距畫面邊 ≥16
	var tmax := 2.0 * (HOME_CX - 16.0) - 68.0 - 52.0
	if tw > tmax:
		tsz = int(tsz * tmax / tw)   # 第七輪：英文 150% 標題原本超出畫面左邊
		tw = tf.get_string_size(tt, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz).x
	var tp := Vector2(HOME_CX - tw / 2, 40 + bob + tsz * 0.85)
	# V1.2 G：標題墊一塊木牌（木紋、銅釘框）＋兩側交叉雙劍，像掛在營帳前的招牌
	if not bool(Save.s("plain_ui")):
		var plq := Rect2(HOME_CX - tw / 2 - 34, tp.y - tsz * 0.92, tw + 68, tsz * 1.16)
		if _tex_box(plq, "wood", Color(0.62, 0.42, 0.26)):
			_wood_frame(plq, 6.0, "title_frame")
			for sx in [plq.position.x - 4, plq.end.x + 4]:
				draw_circle(Vector2(sx, plq.get_center().y), 22.0, Color(1.0, 0.86, 0.45, 0.18), true, -1.0, true)   # V1.2.1 R4：雙劍尺寸不變，墊一圈淡金光（縮圖也認得出）
				_icon("swords", Vector2(sx, plq.get_center().y), 34.0, Color("#f2cf73"))
	for d in 4:
		draw_string(tf, tp + Vector2(1, 1) * (d + 1) * 1.6, tt, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, Color(0.32, 0.17, 0.04, 0.9))
	draw_string_outline(tf, tp, tt, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, 9, Color("#3a2205"))
	draw_string_outline(tf, tp, tt, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, 5, Color("#b8860b"))
	draw_string(tf, tp, tt, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, Color("#ffe8a3"))
	var ty := 40.0 + tsz * 1.2
	_text(Vector2(HOME_CX, ty), L.t("title_alt"), tz("B"), Color(1, 1, 1, 0.85), true, false, 420)
	ty += tz("B") * 1.4
	_text(Vector2(HOME_CX, ty), L.t("subtitle"), tz("S"), TXT_DIM, true, false, 420)
	ty += text_h(L.t("subtitle"), tz("S"), 420) + 18
	var y0 := maxf(230.0, ty)
	# V1.5：主畫面整理成五塊大木牌（對戰、遠征、挑戰、遊戲間、收藏）＋一排系統小鈕；點木牌在右邊攤開第二層卡片
	var fresh: bool = _is_new_player() and Save.s("hints") == "full"   # 教學提示「完整」才閃框
	var plaques := home_plaques()
	# 木牌高度照字量算（150% 字級、日文副標兩行也放得下）；全部放不下時縮間距，不縮字
	var PW := 370.0
	var sw := PW - 66.0 - 12.0
	var ph := 60.0
	for pq0 in plaques:
		ph = maxf(ph, 8.0 + tz("B") * 1.3 + text_h(L.t(str(pq0[1])), tz("C"), sw) + 8.0)
	var room := 724.0 - 48.0 - y0
	var show_sub := ph * 5.0 + 20.0 <= room   # 放不下（150% 字級＋長副標）就只放名稱，不縮字
	if not show_sub:
		ph = maxf(48.0, 12.0 + tz("B") * 1.3)
	var gap := clampf((room - ph * 5.0) / 5.0, 4.0, 8.0)
	# 1.2.0 §1.1 A3 多寶盒籤牌：五支木籤插在左邊一個小木盒的槽裡（盒在籤後面，籤頭露出右邊）
	if not bool(Save.s("plain_ui")):
		var bxr := Rect2(50, y0 - 10, 30, 5 * (ph + gap) - gap + 20)
		draw_rect(Rect2(bxr.position + Vector2(4, 6), bxr.size), Color(DIM_INK, 0.5))
		if not _mat_box(bxr, "plaque", Color(0.55, 0.36, 0.22)):
			draw_rect(bxr, Color("#5a3a22"))
		draw_rect(bxr, Color("#2a1a0e"), false, 2.0)
		for kc in [bxr.position + Vector2(3, 3), Vector2(bxr.end.x - 3, bxr.position.y + 3), Vector2(bxr.position.x + 3, bxr.end.y - 3), bxr.end - Vector2(3, 3)]:
			draw_circle(kc, 2.5, Color("#c9a24a"))   # 黃銅包角釘
		for i in plaques.size():
			var sy := y0 + i * (ph + gap)
			draw_rect(Rect2(bxr.position.x + 6, sy + 4, 18, ph - 8), Color(0.1, 0.06, 0.03, 0.75))   # 籤槽
	for i in plaques.size():
		var pq: Array = plaques[i]
		var mr2 := Rect2(70, y0 + i * (ph + gap), PW, ph)
		var on := not _demo() or bool(pq[4])
		_btn(mr2, "", pq[3], on, i == 0 and fresh)
		draw_rect(Rect2(mr2.position, Vector2(4, mr2.size.y)), ACCENT if (i == 0 and fresh) else (Color(0.12, 0.07, 0.03, 0.55) if not bool(Save.s("plain_ui")) else Color(1, 1, 1, 0.35)))   # 1.2.0：籤插進盒的那一端壓暗
		# V1.5.2 L5：小人照木牌內容區定位（150% 只放名稱時木牌變矮，腳點不再寫死 y+54 而掉出木牌）
		var foot := minf(54.0, ph - 6.0)
		Art.unit(self, mr2.position + Vector2(34, foot), int(pq[2]), 0, 1.0, 0.0, 0.0, 0.0, 1.0 if on else 0.4, time, 0.72 * minf(1.0, foot / 54.0), cbm())
		var tcol: Color = Color.WHITE if on else TXT_DIM
		var tag := home_tag(i)
		var tw2 := (_width(tag, tz("C"), true) + 24.0) if tag != "" else 0.0
		var nw := minf(_width(L.t(str(pq[0])), tz("B"), true), sw - tw2 - 8.0)
		_text(mr2.position + Vector2(66, 6 if show_sub else (ph - tz("B") * 1.2) * 0.5), L.t(str(pq[0])), tz("B"), tcol, false, true, sw - tw2 - 8.0)
		if show_sub:
			_text(mr2.position + Vector2(66, 8 + tz("B") * 1.3), L.t(str(pq[1])), tz("C"), TXT_DIM, false, false, sw)
		if tag != "":
			# 狀態小牌：緊跟在名稱右邊（不蓋字），羊皮紙底＋墨字（不只靠顏色）
			var tr := Rect2(mr2.position.x + 66 + nw + 8, (mr2.position.y + 3 + (tz("B") * 1.3 - tz("C") * 1.5) * 0.5) if show_sub else (mr2.position.y + (ph - tz("C") * 1.5) * 0.5 - 3), tw2, tz("C") * 1.5 + 6)   # 九宮格四邊留內距
			_tex_box(tr, "paper")
			_ink_mode = true
			_text(tr.position + Vector2(12, 3 + tz("C") * 0.2), tag, tz("C"), INK, false, true, tw2)
			_ink_mode = false
	if fresh:
		var pulse := 0.5 + 0.5 * sin(time * 3.0)
		draw_rect(Rect2(68, y0 - 2, PW + 4, ph + 4), Color(ACCENT, 0.5 + 0.5 * pulse), false, 3.0)
	var y2 := y0 + 5 * (ph + gap) + 4
	var sys := [["menu_settings", func(): _open("settings")], ["menu_codes", func(): overlay = "codes"; _focus = 0], ["menu_quit", func(): call("_quit_mark"); get_tree().quit()]]
	for i in sys.size():
		_btn(Rect2(70 + i * 126, y2, 118, 40), L.t(sys[i][0]), sys[i][1], true, false, Color(TH_WOOD_D, 0.92))
	probe_align("home_col", [Rect2(HOME_CX - tw / 2 - 60, 40, tw + 120, tsz), Rect2(70, y0, PW, 5 * (ph + gap)), Rect2(70, y2, 2 * 126 + 118, 40)])
	call("_draw_next_step")   # V1.6 #1
	# 底部：最佳紀錄、版本
	_text(Vector2(70, 740), "%s　｜　v%s" % [L.t("gauntlet_best", [int(Save.data.get("gauntlet_best", 0))]), str(ProjectSettings.get_setting("application/config/version"))], tz("C"), TXT_DIM, false, false, 380)



func _pick_puzzle(id: String, tut: bool) -> void:
	puzzle_id = id
	_start_mode(Mode.TUTORIAL if tut else Mode.PUZZLE)
	if tut and id == "t1":
		_toast(tut_remove_text())   # V1.0.0 N6：教學第一關就講「擺錯可以拿掉重擺」
	elif tut and id == "t2":
		_toast(L.t("tut_counter"))   # V1.0.0 M1：剋制記號 ▲▼ 的互動說明（選一隻兵看敵兵頭上）

## 照現在的輸入方式講怎麼拿掉兵；並說清楚只有雙人輪流落子才不能收回（遊戲名叫落子無悔）。
func tut_remove_text() -> String:
	var how := L.t("tut_rm_mouse")
	if pad_mode:
		how = L.t("tut_rm_pad", [_pk("remove")])
	elif Save.s("place_mode") == "tap":
		how = L.t("tut_rm_tap")
	return L.t("tut_remove", [how])



# ── 覆蓋層 ──
func _draw_overlay() -> void:
	if overlay != "":
		_btns.clear()   # 覆蓋層底下畫面的按鈕不能被點到（例如擺放畫面的開戰、結果頁的按鈕）
		probe_texts.clear()   # 第五輪：底下畫面的字被遮罩蓋住，版面檢查只量覆蓋層本身
		probe_btns.clear()
		probe_ctrls.clear()
		probe_reset_geom()
		if state == St.TITLE:
			_dim(0.72)   # 第七輪：標題的示範戰場不透出來
	panel_obj = OBJ_OF.get(overlay, "")   # 1.2.0 §1.2：這個疊層的面板是桌上的哪一件實物（只換外框裝飾，內容版面不動）
	match overlay:
		"trials":
			_draw_trials()
		"puzzle_hint":
			_draw_puzzle_hint()
		"puzzle_plan":
			_draw_plan_overlay()
		"profile":
			_draw_profile()
		"nemeses":
			_draw_nemeses()
		"paint":
			_draw_paint()
		"hub_play", "hub_gauntlet", "hub_challenge", "hub_collect", "playroom":
			_draw_hub(overlay)
		"first_run":
			_draw_first_run()
		"restore":
			_draw_restore()
		"clear_data":
			_draw_clear_data()
		"ghosts":
			_draw_ghosts()
		"ga_info":
			_draw_ga_info()
		"weekly":
			_draw_weekly()
		"kit_demo":
			call("_draw_kit_demo")   # 1.2.0：開發用截圖（dev_main）
		"mood_demo":
			call("_draw_mood_demo")   # 1.2.0 第 5 大類：開發用截圖（dev_main）
		"boss_note":
			if note_ret != "":   # 疊在大廳上：先畫大廳（按鈕隨後清掉，點不到），再壓暗畫便條
				overlay = note_ret
				_draw_overlay()
				overlay = "boss_note"
				_btns.clear()
				probe_texts.clear()
				probe_btns.clear()
				probe_ctrls.clear()
				probe_reset_geom()
				_dim(0.55)
			_draw_boss_note()   # 1.2.0 §12
		"res_facts":
			call("_draw_res_facts")   # 1.2.0
		"wk_ghosts":
			call("_draw_wk_ghosts")   # 1.2.0 §15.4
		"relay":
			_draw_relay()
		"postcard":
			_draw_postcard()
		"wager":
			_draw_wager()
		"draft":
			_draw_draft()
		"reward":
			_draw_reward()
		"ban":
			_draw_ban()
		"ai_busy":
			_draw_busy(-1)
		"codes":
			# V1.5.2 L11：說明從緞帶下緣＋16、按鈕從說明實高＋16 起；面板照內容高
			var ch_h := h1_help_h(L.t("codes_hint"), tz("S"), 540)
			var CP := modal_rect(600, 4.0 + ch_h + 56.0 + GAP_M + 50.0 + GAP_S + 44.0 + GAP_XL + 44.0 + GAP_L)
			_panel(CP)
			var cy := _h1_help(Vector2(640, CP.position.y + 4), L.t("menu_codes"), L.t("codes_hint"), tz("S"), 540)
			# V1.5.1：一鍵貼上自動辨識（對戰、規則、挑戰、殘局、設定碼）；原本三顆分開的鈕留著
			_btn(Rect2(380, cy, 520, 56), L.t("code_auto"), func(): _auto_code(), true, true)
			_btn(Rect2(380, cy + 68, 250, 50), L.t("bc_watch"), func(): overlay = ""; _watch_battle_code())
			_btn(Rect2(650, cy + 68, 250, 50), L.t("ch_accept"), func(): overlay = ""; _accept_challenge())
			_btn(Rect2(380, cy + 126, 520, 44), L.t("ws_accept"), func(): overlay = ""; call("_accept_workshop"))   # V1.1 D3
			_btn(Rect2(560, CP.end.y - GAP_L - 44.0, 160, 44), L.t("back"), func(): overlay = "")
		"gauntlet_resume":
			var gb := L.t("gr_body", [int(Save.data["gauntlet_run"]["stage"])])
			var GP := modal_rect(600, 4.0 + h1_bottom(0.0) + GAP_L + text_h(gb, tz("B"), 540, true) + GAP_L + 52.0 + 10.0 + 44.0 + GAP_L)
			_panel(GP)
			var gy := _h1(Vector2(640, GP.position.y + 4), L.t("menu_gauntlet")) + GAP_L   # V1.5.2 L3
			_text(Vector2(640, gy), gb, tz("B"), Color.WHITE, true, true, 540)
			gy += text_h(gb, tz("B"), 540, true) + GAP_L
			_btn(Rect2(380, gy, 520, 52), L.t("gr_go"), func(): call("_gauntlet_resume"), true, true)
			_btn(Rect2(380, gy + 62, 250, 44), L.t("gr_new"), func(): _enter_gauntlet_new())
			_btn(Rect2(650, gy + 62, 250, 44), L.t("back"), func(): overlay = "")
		"pause_menu":
			_draw_pause_menu()
		"confirm":
			_draw_confirm()
		"fs_confirm":
			_draw_fs_confirm()
		"wave_codes":
			# V1.5.1 D1：車輪戰代碼：選看第幾波
			var wl: Array = get("wv_view")
			var WP := modal_rect(500, 4.0 + h1_bottom(0.0) + GAP_L + wl.size() * 60.0 - 10.0 + GAP_XL + 44.0 + GAP_L)
			_panel(WP)
			var wy := _h1(Vector2(640, WP.position.y + 4), L.t("wv_pick")) + GAP_L   # V1.5.2 L3
			for i in wl.size():
				var cw: String = wl[i]
				_btn(Rect2(440, wy + i * 60, 400, 50), L.t("wv_wave_n", [i + 1]), func(): overlay = ""; call("_watch_code_str", cw), true, i == 0)
			_btn(Rect2(560, WP.end.y - GAP_L - 44.0, 160, 44), L.t("back"), func(): overlay = "codes")
		"leave":
			_panel(Rect2(340, 270, 600, 260))
			_text(Vector2(640, 294), L.t("leave_title"), tz("H2"), Color.WHITE, true, true, 540)
			_text(Vector2(640, 354), L.t("leave_body_gauntlet") if mode == Mode.GAUNTLET else L.t("leave_body_series"), tz("B"), Color(1, 1, 1, 0.85), true, false, 540)
			_btn(Rect2(380, 450, 250, 52), L.t("leave_stay"), func(): overlay = "pause_menu" if (state == St.BATTLE and paused) else "", true, true)
			_btn(Rect2(650, 450, 250, 52), L.t("leave_go"), func(): _leave_confirm())
		"tutorial", "puzzles":
			var tut := overlay == "tutorial"
			puzzle_tab = clampi(puzzle_tab, 0, PZ.CHAPTERS - 1)
			var chap: Array = PZ.chapter(puzzle_tab + 1)
			var list: Array = PZ.tutorials() if tut else chap
			var stars: Dictionary = Save.data.get("puzzle_stars", {})
			# V1.5.2 L10：面板上移 20（底不變），章節切換列從緞帶完整下緣＋16 起排（150% 原本緞帶尾壓到切換鈕）
			_panel(Rect2(240, 56, 800, 672))   # 1.2.0 字級表放大：面板上移加高（英文 150% 兩行關名放得下）
			probe_skip("R4", "三段式底列：左＝總星數文字、中＝返回（置中）、右＝只看未滿星開關")
			var hb := _h1(Vector2(640, 56), L.t("menu_tutorial") if tut else L.t("puzzle_title"), 600)   # V1.2：和圖鑑、大廳同款標題緞帶（Antigravity impl3）
			var y0 := 210.0
			var cy := hb + GAP_L
			var idx: Array = []
			for i0 in list.size():
				idx.append(i0)
			if not tut:
				# 第十三輪：10 章，左右切換；章名旁寫這章的星數，下面一行是開場小故事
				var total := 0
				var all_total := 0
				for pz0 in chap:
					total += int(stars.get(pz0["id"], 0))
				for pz1 in PZ.all_puzzles():
					all_total += int(stars.get(pz1["id"], 0))
				var info := PZ.chapter_info(puzzle_tab + 1)
				var cname: String = L.field(info, "")
				_btn(Rect2(280, cy, 48, 40), "◀", func(): puzzle_tab = wrapi(puzzle_tab - 1, 0, PZ.CHAPTERS), puzzle_tab > 0 and not _demo())
				_btn(Rect2(952, cy, 48, 40), "▶", func(): puzzle_tab = wrapi(puzzle_tab + 1, 0, PZ.CHAPTERS), puzzle_tab < PZ.CHAPTERS - 1 and not _demo())
				_text(Vector2(640, cy + 4), L.t("chapter_head", [puzzle_tab + 1, cname, total, chap.size() * 3]), tz("B"), ACCENT, true, true, 600)
				var story: String = L.field(info, "story")
				_text(Vector2(640, cy + 4 + tz("B") * 1.5), story, tz("C"), TXT_DIM, true, false, 700)
				y0 = cy + 4 + tz("B") * 1.5 + text_h(story, tz("C"), 700) + GAP_M
				_text(Vector2(280, 690), L.t("puzzle_all_stars", [all_total, PZ.all_puzzles().size() * 3]), tz("C"), TXT_DIM, false, false, 260)
				if chapter_sealed(chap, stars):
					_wax_seal(Vector2(760, 700), 17.0)   # 1.1.0 A10：這章全部三星＝火漆印（只是裝飾，不改任何紀錄）
				_btn(Rect2(800, 682, 200, 36), ("✓ " if puzzle_only_open else "") + L.t("puzzle_only_open"), func(): puzzle_only_open = not puzzle_only_open)
				if puzzle_only_open:
					idx = idx.filter(func(k): return int(stars.get(list[k]["id"], 0)) < 3)
			var step: float = minf(82.0, (674.0 - y0) / 5.0)
			for k in idx.size():
				var i: int = idx[k]
				var pz: Dictionary = list[i]
				var r := Rect2(280 + (k % 2) * 370, y0 + (k / 2) * step, 350, step - 14)
				var name: String = L.field(pz, "")
				var st := int(stars.get(pz["id"], 0))
				var en: bool = not _demo() or tut or (puzzle_tab == 0 and i < Presets.DEMO_PUZZLES)   # 第十一輪：關卡全開，只有試玩版有範圍
				var line := "%s%d. %s" % ["✓ " if st > 0 else "", i + 1, name]   # V1.2：星數改畫圖示（不再用 ★☆ 字元，大字級不會擠出框）
				if pz.has("unit") and not RS.available(int(pz["unit"]), _demo()):
					en = false
					line = "%d. %s（%s）" % [i + 1, name, L.t("locked_demo")]
				# 第七輪：標籤靠左、讓開左邊的迷你敵陣（原本置中會被縮圖蓋住）
				btn_paper = st > 0   # V1.2.1 R1：已過關的卡片是紙面（未過關留木，進度一眼看得出）
				_btn(r, "", _pick_puzzle.bind(pz["id"], tut), en, false,
					Color(0.15, 0.32, 0.22) if st > 0 and plain_ui_now() else Color(0, 0, 0, 0))
				btn_paper = false
				_ink_mode = last_btn_paper
				_probe_dis = not last_btn_enabled
				_probe_btn_label = true
				_probe_btn_rect = r
				_text(r.position + Vector2(64, 8), line, tz("S"), Color.WHITE if en and last_btn_enabled else Color(1, 1, 1, 0.4), false, false, r.size.x - 72)
				_probe_btn_label = false
				if en:
					for ks in 3:   # 星數在右下角（和下方說明同一列，說明讓出寬度）
						_icon("star", Vector2(r.end.x - 52 + ks * 19, r.end.y - tz("C") * 0.75), 17.0, Color("#ffd166") if ks < st else Color(1, 1, 1, 0.2))
					var cde = Save.data.get("coached", {}).get(str(pz["id"]))
					if not tut and cde is Dictionary and (int(cde.get("lv", 0)) >= 2 or int(cde.get("ap", 0)) == 1) and int(cde.get("self", 0)) < st:   # 1.1.0：用朋友最佳解過關也算協力
						_icon("hint", Vector2(r.end.x - 74, r.end.y - tz("C") * 0.75), 15.0, Color("#7fd6c2"))   # V1.6.1 A4：教練協力（自力最佳比目前星數少）
				# 第七輪 E12：關卡鈕直接看得到預算、可用兵種、星級條件
				# 關卡名稱換行時（英文大字）就不再放預覽，避免互壓
				var note: String = L.t("puzzle_note", [int(pz["budget"]), int(pz["star3"])])
				var pbest: Array = Save.data.get("pz_best", {}).get(str(pz["id"]), [])
				if pbest.size() == 3:
					note = L.t("puzzle_note_best", [int(pbest[0]), int(pz["star3"])])   # V1.4 #6：破過就顯示自己的最低花費
				# V1.2.1：備註放得下一行才畫（中文 150% 原本換成兩行跑出卡片）
				var note_y: float = r.size.y - tz("C") * 1.4 - 3.0
				if not tut and en and text_h(line, tz("S"), r.size.x - 72) <= tz("S") * 1.6 and _width(note, tz("C")) <= r.size.x - 132 \
						and note_y >= 8.0 + tz("S") * 1.25:   # 標題下面放得下才畫（英文 150% 卡片矮，不畫備註）
					_probe_btn_label = true
					_probe_btn_rect = r
					_text(r.position + Vector2(62, note_y), note, tz("C"), Color("#6b3a12") if last_btn_paper else Color(1, 0.9, 0.6, 0.85), false, false, r.size.x - 132)   # 1.2.0：淺色木牌／紙面上用深棕
					_probe_btn_label = false
				# 主角兵種小頭像（R6）：這關第一個可用的兵種
				_mini_formation(Rect2(r.position + Vector2(6, 6), Vector2(52, 56)), pz, en)   # 迷你敵陣縮圖（第三輪 U4）
				_ink_mode = false
				_probe_dis = false
			if tut:
				# 第七輪 A4：自由排兵入門（畫筆、搬移、開戰），一步一步帶
				var fr := Rect2(280 + (list.size() % 2) * 370, 210 + (list.size() / 2) * 82, 350, 68)
				_btn(fr, ("✓ " if bool(Save.data.get("free_intro_done", false)) else "") + L.t("intro_btn"), func(): _start_free_intro(), true, false,
					Color(0.15, 0.32, 0.22) if bool(Save.data.get("free_intro_done", false)) else Color(0, 0, 0, 0))
			_btn(Rect2(560, 682, 160, 36), L.t("back"), func(): _nav_back())
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
			_btn(Rect2(560, 680, 160, 36), L.t("back"), func(): _nav_back())
		"slots":
			_draw_slots()
		"gauntlet_pick":
			_draw_gauntlet_pick()
		"codex":
			_draw_codex()
		"review":
			_draw_review()
		_:
			call("_draw_v16_overlay", overlay)   # V1.6 新覆蓋層（game_v16.gd）
	panel_obj = ""



## V1.2.1 E1：四條音量套用並試聽那一軌（sample＝""不試聽、"amb"＝放 1.5 秒森林環境音）。
func _apply_volumes(sample: String) -> void:
	_apply_master()
	if sfx == null:
		return
	sfx.set_volumes(int(Save.s("sfx")), int(Save.s("music")), int(Save.s("ui_vol")), int(Save.s("amb_vol")))
	if sample == "amb":
		if sfx.amb_name == "":
			sfx.play_ambience("forest")
			var token: int = sfx.amb_owner
			get_tree().create_timer(1.5).timeout.connect(func():
				if sfx != null and sfx.amb_owner == token:   # 這段環境音還是試聽那次（離開設定、進場換了環境音就不碰）
					sfx.play_ambience(""))
	elif sample != "":
		sfx.play(sample)

## 設定（第五輪 §4.4）：四組分頁＋右側說明欄；多選項用 ◀ ▶；遊戲規則已經搬到規則大廳。
## V1.5：設定七頁（畫面、介面、聲音、操作、戰場與觀戰、無障礙、資料）。每列 [名稱鍵, 顯示值, 切換函式(d)]；
## 顯示值是 "@" 開頭的列＝按鈕（打開或執行），不是左右切換。docs/history/2026-11-09-v1.5.0-plan.md §2。
const SET_TABS := 7
## V1.5.1 E1：試玩回報匯出：先告訴玩家有幾筆、只含哪些欄位，確認後寫成 user://playtest_report.json 並打開資料夾
func _playtest_export() -> void:
	var r: Dictionary = Save.playtest_report(str(ProjectSettings.get_setting("application/config/version")))
	if int(r["n"]) == 0:
		_toast(L.t("pt_export_none"), true)
		return
	_ask_confirm(L.t("pt_export_q", [int(r["n"])]), func():
		var f := FileAccess.open("user://playtest_report.json", FileAccess.WRITE)
		if f == null:
			_toast(L.t("save_failed"), true)
			return
		f.store_string(str(r["text"]))
		f.close()
		OS.shell_open(ProjectSettings.globalize_path("user://"))
		_toast(L.t("pt_export_done")), "settings")

## V1.5.1 C6：切換全螢幕後 10 秒內沒按「保留」就自動換回來（螢幕黑掉、看不到按鈕時不會卡住）
var fs_prev = null
var fs_deadline := 0.0
var fs_ret := "settings"   # 確認框關掉回哪一頁（設定、代碼、第一次啟動…）
func _fs_change() -> void:
	fs_ret = overlay if overlay != "" else "settings"
	fs_prev = Save.s("fullscreen")
	_cycle_setting("fullscreen", [false, true])
	_apply_fullscreen()
	fs_deadline = time + 10.0
	overlay = "fs_confirm"
	_focus = 0

func _fs_keep() -> void:
	fs_prev = null
	overlay = fs_ret

func _fs_revert() -> void:
	if fs_prev != null:
		Save.set_setting("fullscreen", fs_prev)
		_apply_fullscreen()
	fs_prev = null
	overlay = fs_ret

func _draw_fs_confirm() -> void:
	var left := fs_deadline - time
	if left <= 0.0:
		_fs_revert()
		return
	_dim(0.6)
	var P := Rect2(390, 280, 500, 240)
	_panel(P)
	_text(Vector2(640, P.position.y + 40), L.t("fs_keep_q", [ceili(left)]), tz("B"), Color.WHITE, true, false, 440)
	_btn(Rect2(420, P.end.y - 72, 210, 50), L.t("fs_keep"), func(): _fs_keep(), true, true)
	_btn(Rect2(650, P.end.y - 72, 210, 50), L.t("fs_revert"), func(): _fs_revert())

## V1.5.1 C1：每一列對應的存檔鍵（恢復預設、修改標記用）。語言不列入（恢復預設不該把語言改掉）
const SET_KEYS := {"set_smooth_pose": ["smooth_pose"], "set_fullscreen": ["fullscreen"], "set_title_bg": ["title_bg"], "set_fps": ["fps_cap"], "set_vsync": ["vsync"],
	"set_text": ["text_scale"], "set_hints": ["hints"], "set_plain_titles": ["plain_titles"], "set_ui_font": ["ui_font"], "set_plain_ui": ["plain_ui"], "set_toast": ["toast_mult"],
	"set_master": ["master"], "set_music": ["music"], "set_sfx": ["sfx"], "set_ui_vol": ["ui_vol"], "set_amb_vol": ["amb_vol"], "set_night": ["night"], "set_mono": ["mono"],
	"set_keys": ["keys", "pad"], "set_confirm": ["confirm_place"], "set_place_mode": ["place_mode"], "set_long_press": ["long_press"], "set_rumble": ["rumble"], "set_deadzone": ["deadzone"],
	"set_speed": ["speed"], "set_hp_bars": ["hp_bars"], "set_dmg_nums": ["dmg_nums"], "set_reduce_fx": ["reduce_fx"], "set_clutch_zoom": ["clutch_zoom"], "set_slowmo": ["slowmo"],
	"set_hold": ["hold_confirm"], "set_magnify": ["magnify"], "set_cb": ["colorblind"], "set_reduce_motion": ["reduce_motion"], "set_text_plate": ["text_plate"], "set_focus": ["focus_strong"],
	"set_shake": ["shake_pct", "shake"], "set_flash": ["flash_pct", "flash"], "set_playtest": ["playtest"]}

static func set_changed(row: String) -> bool:
	for k in SET_KEYS.get(row, []):
		if str(Save.s(k)) != str(Save.DEFAULT_SETTINGS.get(k)):
			return true
	return false

## V1.5.1：一次改很多項（匯入、恢復預設、預設組合）時，全螢幕有變也要走 10 秒確認（Codex v151-i1 #2）
func _guard_fs(prev) -> void:
	if str(prev) != str(Save.s("fullscreen")):
		fs_ret = overlay if overlay != "" and overlay != "fs_confirm" else "settings"
		fs_prev = prev
		fs_deadline = time + 10.0
		overlay = "fs_confirm"
		_focus = 0

func _reset_rows(rows: Array) -> void:
	var d := {}
	for row in rows:
		for k in SET_KEYS.get(row, []):
			var v = Save.DEFAULT_SETTINGS.get(k)
			d[k] = v.duplicate(true) if v is Dictionary or v is Array else v
	if d.is_empty():
		return
	var fp0 = Save.s("fullscreen")
	Save.set_settings(d)
	_apply_all_settings()
	_toast(L.t("set_reset_done"))
	_guard_fs(fp0)

## V1.5.1：戰鬥中改了要下一局才生效的設定（其餘立即生效）
const NEXT_GAME_KEYS := ["set_place_mode", "set_speed", "set_title_bg", "set_hints", "set_confirm", "set_long_press", "set_playtest"]
const VOL_STEPS := [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100]   # 音量每格 5%
const VOL_KEY := {"set_master": "master", "set_music": "music", "set_sfx": "sfx", "set_ui_vol": "ui_vol", "set_amb_vol": "amb_vol"}
const VOL_PREVIEW := {"master": "hit", "music": "", "sfx": "hit", "ui_vol": "k_confirm", "amb_vol": "amb"}
var vol_drag := ""            # 1.3.0：正在拖的音量（設定鍵）
var vol_rails := {}           # 這一幀畫出來的音量木軌（設定鍵 → 軌道框）

## 1.3.0 §15 第 4 項：音量木軌拖曳（走輸入佇列，和點擊同一順序；Codex cat01 #1 #2）。
## 按下在軌上＝開始拖（吃掉這次按下，不觸發底下的數值鈕）；移動＝即時試聽（只改記憶體）；放開＝存檔一次、吃掉放開（不再 +5%）。
## 離開設定、畫面換掉（佇列過期）都會結束並存檔。值照 VOL_STEPS（5% 一格）。
func vol_press(p: Vector2) -> bool:
	if overlay != "settings" or pad_mode:
		return false
	for k in vol_rails:
		if (vol_rails[k] as Rect2).grow(4.0).has_point(p):
			vol_drag = k
			_vol_preview(p.x)
			return true
	return false

func vol_motion(p: Vector2) -> void:
	if vol_drag != "":
		_vol_preview(p.x)

func vol_release() -> bool:
	if vol_drag == "":
		return false
	var k := vol_drag
	vol_drag = ""
	Save.set_setting(k, int(Save.s(k)))   # 拖曳中只改記憶體，放開才寫檔
	return true

func _vol_preview(x: float) -> void:
	if not vol_rails.has(vol_drag):
		return
	var v: int = vol_from_x(x, vol_rails[vol_drag])
	if v != int(Save.s(vol_drag)):
		Save.settings[vol_drag] = v
		_apply_volumes(str(VOL_PREVIEW[vol_drag]))

static func vol_from_x(x: float, rail: Rect2) -> int:
	var f := clampf((x - rail.position.x) / maxf(1.0, rail.size.x), 0.0, 1.0)
	return int(roundf(f * 20.0)) * 5

func _optv(k: String, vals: Array, keys: Array) -> String:
	var i := vals.find(Save.s(k))
	return L.t(keys[maxi(0, i)])

func _pct(k: String) -> String:
	return "%d%%" % int(Save.s(k))

## V1.5：要跟 _draw_settings 的列位置一致（無障礙分頁上面多一排預設組合）
func _settings_row_y(i: int) -> float:
	return 166.0 + (60.0 if settings_tab == 5 or settings_tab == 3 else 0.0) + i * 60.0

func _settings_rows() -> Array:
	match settings_tab:
		0:
			return [["set_fullscreen", L.t("v_borderless") if bool(Save.s("fullscreen")) else L.t("v_windowed"), func(d): _fs_change()],
				["set_title_bg", _optv("title_bg", ["demo", "static"], ["v_demo", "v_static"]), func(d): _cycle_setting("title_bg", ["demo", "static"])],
				["set_fps", L.t("v_unlimited") if int(Save.s("fps_cap")) == 0 else str(int(Save.s("fps_cap"))), func(d): _step_setting("fps_cap", [30, 60, 120, 0], d); _apply_display()],
				["set_vsync", _onoff("vsync"), func(d): _cycle_setting("vsync", [true, false]); _apply_display()],
				["set_smooth_pose", _onoff("smooth_pose"), func(d): _cycle_setting("smooth_pose", [false, true])],   # 1.2.0 §7.2 定格表演層
				["set_paint", "@" + L.t("open_it"), func(d): call("_paint_open")]]
		1:
			return [["set_lang", L.t("lang_name"), func(d): _cycle_setting("lang", L.LANGS); L.lang = Save.s("lang"); _load_fonts()],
				["set_ui_font", _optv("ui_font", ["classic", "craft"], ["v_font_classic", "v_font_craft"]), func(d): _cycle_setting("ui_font", ["classic", "craft"]); _load_fonts()],   # 1.2.0 §3.2
				["set_text", "%d%%" % int(Save.s("text_scale")), func(d): _step_setting("text_scale", [100, 125, 150], d)],
				["set_hints", _optv("hints", ["full", "key", "off"], ["v_full", "v_key", "v_off"]), func(d): _step_setting("hints", ["full", "key", "off"], d)],
				["set_plain_titles", _onoff("plain_titles"), func(d): _cycle_setting("plain_titles", [false, true])],
				["set_plain_ui", L.t("v_simple") if bool(Save.s("plain_ui")) else L.t("v_standard"), func(d): _cycle_setting("plain_ui", [false, true]); _rebuild_sprites()],
				["set_toast", _optv("toast_mult", [1, 2, 3, 0], ["v_std", "v_long", "v_xlong", "v_manual"]), func(d): _step_setting("toast_mult", [1, 2, 3, 0], d)],
				["set_magnify", _onoff("magnify"), func(d): _cycle_setting("magnify", [false, true])]]   # V1.6 #7
		2:
			return [["set_master", _pct("master"), func(d): _step_setting("master", VOL_STEPS, d); _apply_volumes("hit")],
				["set_music", _pct("music"), func(d): _step_setting("music", VOL_STEPS, d); _apply_volumes("")],
				["set_sfx", _pct("sfx"), func(d): _step_setting("sfx", VOL_STEPS, d); _apply_volumes("hit")],
				["set_ui_vol", _pct("ui_vol"), func(d): _step_setting("ui_vol", VOL_STEPS, d); _apply_volumes("k_confirm")],
				["set_amb_vol", _pct("amb_vol"), func(d): _step_setting("amb_vol", VOL_STEPS, d); _apply_volumes("amb")],
				["set_night", _onoff("night"), func(d): _cycle_setting("night", [false, true]); _apply_master()],
				["set_mono", _onoff("mono"), func(d): _cycle_setting("mono", [false, true]); _apply_master()]]
		3:
			return [["set_keys", "@" + L.t("open_it"), func(d): _open("keys")],
				["set_confirm", _onoff("confirm_place"), func(d): _cycle_setting("confirm_place", [true, false])],
				["set_hold", _onoff("hold_confirm"), func(d): _cycle_setting("hold_confirm", [false, true])],   # V1.6 #7
				["set_place_mode", _optv("place_mode", ["both", "tap"], ["v_place_both", "v_place_tap"]), func(d): _step_setting("place_mode", ["both", "tap"], d)],
				["set_long_press", L.t("sec_f", [_fmt_num(float(Save.s("long_press")))]), func(d): _step_setting("long_press", [0.3, 0.5, 0.8, 1.0], d)],
				["set_rumble", _pct("rumble"), func(d): _step_setting("rumble", [0, 25, 50, 100], d)],
				["set_deadzone", _pct("deadzone"), func(d): _step_setting("deadzone", Save.ENUMS["deadzone"], d)]]
		4:
			return [["set_speed", "%s×" % _fmt_num(float(Save.s("speed"))), func(d): _step_setting("speed", SPEEDS, d)],
				["set_hp_bars", _optv("hp_bars", ["hurt", "all", "sel", "off"], ["v_hurt", "v_all", "v_sel", "v_off"]), func(d): _step_setting("hp_bars", ["hurt", "all", "sel", "off"], d)],
				["set_dmg_nums", _optv("dmg_nums", ["merge", "each", "off"], ["v_merge", "v_each", "v_off"]), func(d): _step_setting("dmg_nums", ["merge", "each", "off"], d)],
				["set_reduce_fx", L.t("v_min") if bool(Save.s("reduce_fx")) else L.t("v_full"), func(d): _cycle_setting("reduce_fx", [false, true])],
				["set_clutch_zoom", _onoff("clutch_zoom"), func(d): _cycle_setting("clutch_zoom", [true, false])],
				["set_slowmo", _onoff("slowmo"), func(d): _cycle_setting("slowmo", [true, false])]]
		5:
			return [["set_cb", L.t("v_cb") if bool(Save.s("colorblind")) else L.t("v_standard"), func(d): _cycle_setting("colorblind", [false, true]); _rebuild_sprites()],
				["set_reduce_motion", _onoff("reduce_motion"), func(d): _cycle_setting("reduce_motion", [false, true])],
				["set_text_plate", L.t("v_high") if bool(Save.s("text_plate")) else L.t("v_standard"), func(d): _cycle_setting("text_plate", [false, true])],
				["set_focus", L.t("v_strong") if bool(Save.s("focus_strong")) else L.t("v_standard"), func(d): _cycle_setting("focus_strong", [false, true])],
				["set_shake", _pct("shake_pct"), func(d): _step_setting("shake_pct", [0, 25, 50, 100], d); Save.set_setting("shake", int(Save.s("shake_pct")) > 0)],
				["set_flash", _pct("flash_pct"), func(d): _step_setting("flash_pct", [0, 50, 100], d); Save.set_setting("flash", int(Save.s("flash_pct")) > 0)]]
		6:
			return [["set_playtest", _onoff("playtest"), func(d): _cycle_setting("playtest", [false, true])],
				["set_export", "@" + L.t("do_copy"), func(d): _settings_export()],
				["set_pt_export", "@" + L.t("do_copy"), func(d): call("_feedback")],   # V1.6 #2：回報＝版本、畫面、漏斗＋試玩紀錄
				["set_import", "@" + L.t("do_paste"), func(d): _settings_import()],
				["set_backup", "@" + L.t("do_backup"), func(d): _progress_backup()],
				["set_restore", "@" + L.t("do_restore"), func(d): _data_swap_open("restore")],
				["set_clear", "@" + L.t("do_choose"), func(d): clear_pick = {}; _data_swap_open("clear_data")],
				["set_folder", "@" + L.t("open_it"), func(d): OS.shell_open(ProjectSettings.globalize_path("user://"))]] + _ws_archive_row()
	return []

## 1.1.0 A10：章節全三星
static func chapter_sealed(chap: Array, stars: Dictionary) -> bool:
	if chap.is_empty():
		return false
	for pz in chap:
		if int(stars.get(pz["id"], 0)) < 3:
			return false
	return true

func _wax_seal(c: Vector2, r: float) -> void:
	draw_circle(c + Vector2(0, 2), r + 1.0, Color(0, 0, 0, 0.35), true, -1.0, true)
	draw_circle(c, r, Color("#a8231c"), true, -1.0, true)
	_hand_ring(c, r * 0.72, Color(1.0, 0.75, 0.62, 0.8), 1.6)
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r * (0.46 if i % 2 == 0 else 0.2)))
	draw_colored_polygon(pts, Color(1.0, 0.82, 0.62, 0.95))

## 1.1.0 A23：V1.6.1 之前存在舊 `ws` 鍵底下的實驗簿方案（認不出是哪一題，不顯示也不刪）：只有存檔裡真的有時才給「匯出」。
func _ws_archive_row() -> Array:
	var nb = Save.data.get("notebook", {})
	if not (nb is Dictionary and nb.has("ws") and nb["ws"] is Array and not (nb["ws"] as Array).is_empty()):
		return []
	return [["set_ws_archive", "@" + L.t("do_copy"), func(d): _ws_archive_export()]]

static func ws_archive_text(data: Dictionary) -> String:
	var nb = data.get("notebook", {})
	return JSON.stringify({"ws_archive": nb.get("ws", []) if nb is Dictionary else [], "note": "V1.6.1 以前的工坊／出題台實驗簿；原鍵與內容照存，未刪除"}, " ")

func _ws_archive_export() -> void:
	var txt := ws_archive_text(Save.data)
	var name := "user://%snotebook_ws_archive.json" % Save.file_prefix()
	var f := FileAccess.open(name, FileAccess.WRITE)
	var saved := false
	if f != null:
		f.store_string(txt)
		f.close()
		saved = FileAccess.get_file_as_string(name) == txt
	DisplayServer.clipboard_set(txt)
	_toast(L.t("ws_archive_done") if saved else L.t("fb_copied_only"), not saved)



## V1.5 暫停選單：戰鬥中按 Esc／手把 B 打開。「重開」不做：勝負在擺陣時就定了，重開＝看完結果再改陣（裁決見 v150 ledger）。
var settings_ret := ""   # 設定頁關掉後回哪個覆蓋層（暫停選單進來的要回暫停選單）

func _open_pause_menu() -> void:
	paused = true
	overlay = "pause_menu"
	_focus = 0

func _pause_resume() -> void:
	overlay = ""
	paused = false

func _settings_close() -> void:
	vol_release()
	overlay = settings_ret
	settings_ret = ""

func _draw_pause_menu() -> void:
	var items: Array = [[L.t("pm_resume"), func(): _pause_resume(), true]]
	if play_kind == "official":
		items.append([L.t("skip"), func(): overlay = ""; call("_on_skip"), false])
	items.append([L.t("pm_settings"), func(): settings_ret = "pause_menu"; overlay = "settings", false])
	items.append([L.t("fb_btn"), func(): call("_feedback"), false])   # V1.6 #2
	items.append([L.t("pm_leave"), func(): overlay = ""; _request_leave(), false])   # 確認框開著時戰鬥維持暫停（Antigravity v150-i2 #3）
	var ph := 96.0 + items.size() * 66.0 + 24.0   # 面板高度照項目數
	var P := Rect2(440, 400 - ph * 0.5, 400, ph)
	_panel(P)
	_text(Vector2(640, P.position.y + 26), L.t("pm_title"), tz("H2"), Color.WHITE, true, true, 340)
	var y := P.position.y + 96
	for it in items:
		_btn(Rect2(P.position.x + 50, y, 300, 52), it[0], it[1], true, it[2])
		y += 66

const SET_COL := Rect2(340, 150, 560, 560)    # 設定頁中央操作欄
const SET_DESC := Rect2(910, 166, 236, 470)   # 設定頁右側說明欄

func _draw_settings() -> void:
	vol_rails.clear()
	_panel(Rect2(110, 96, 1060, 628))
	# V1.5.2 L8／L9：三欄畫面。左＝分頁、中＝操作欄（340～900，中線 620）、右＝說明欄；底部按鈕以中欄中線置中，
	# 預設三鈕＋撤回整組放在中欄內（撤回原本 880～990 被說明欄蓋住 80px）
	probe_axis(SET_COL.get_center().x)
	probe_columns("settings", [Rect2(110, 150, 230, 560), SET_COL, SET_DESC])
	_h1(Vector2(640, 92), L.t("settings_title"))   # 1.2.0：H1 字級放大 3px，緞帶上移保持和第一列的間距（R2）
	for i in SET_TABS:
		btn_cloth = "tab_indigo" if i == settings_tab else "tab_linen"   # 1.2.0 §1.3：分頁是布標（選中靛藍、未選原胚布）
		_btn(Rect2(136, 166 + i * 56, 190, 48), L.t("set_tab_%d" % i), func(): settings_tab = i; settings_item = "", true, false,
			TH_ACTIVE if i == settings_tab else Color(0, 0, 0, 0))
		btn_cloth = ""
	# V1.5.1 C1：這一頁恢復預設（先確認）
	var page_keys: Array = []
	for rw in _settings_rows():
		page_keys.append(rw[0])
	var any_changed := false
	for pk0 in page_keys:
		any_changed = any_changed or set_changed(pk0)
	_btn(Rect2(136, 166 + SET_TABS * 56 + 8, 190, 44), L.t("set_reset_page"), func(): _ask_confirm(L.t("set_reset_page_q"), func(): _reset_rows(page_keys), "settings"), any_changed)
	var y0 := 166.0
	if settings_tab == 5:
		# 一鍵預設（可疊加；套用後可撤回）
		var pk := ["preset_vis", "preset_motion", "preset_load"]
		var pw := (SET_COL.size.x - 3 * 8.0 - 110.0) / 3.0
		for k in 3:
			_btn(Rect2(SET_COL.position.x + k * (pw + 8.0), y0, pw, 46), L.t(pk[k]), _apply_preset.bind(k), true, false, Color(0.2, 0.36, 0.5))
		if not preset_undo.is_empty():
			_btn(Rect2(SET_COL.end.x - 110.0, y0, 110, 46), L.t("undo"), func(): _undo_preset())
		y0 += 60.0
	elif settings_tab == 3:
		# 1.1.0 E3：掌機建議（一鍵、先預覽、可撤回）
		# 1.2.0 §15.3（Antigravity cat01 #4）：一顆「套用掌機配置」＋旁邊 30／60 二選一（不是兩顆一樣長的鈕）
		var sw := 104.0
		var aw := SET_COL.size.x - 118.0 - 2.0 * (sw + 8.0)
		_btn(Rect2(SET_COL.position.x, y0, aw, 46), L.t("preset_hh"), func(): _apply_preset(4 if hh_fps == 60 else 3), true, false, Color(0.2, 0.36, 0.5))
		_btn_small(Rect2(SET_COL.position.x + aw + 8.0, y0 + 4, sw, 38), L.t("preset_hh_30"), func(): hh_fps = 30, true, hh_fps == 30)
		_btn_small(Rect2(SET_COL.position.x + aw + 16.0 + sw, y0 + 4, sw, 38), L.t("preset_hh_60"), func(): hh_fps = 60, true, hh_fps == 60)
		if not preset_undo.is_empty():
			_btn(Rect2(SET_COL.end.x - 110.0, y0, 110, 46), L.t("undo"), func(): _undo_preset())
		y0 += 60.0
	var rows: Array = _settings_rows()
	for i in rows.size():
		var y := _settings_row_y(i)
		if i % 2 == 0:
			draw_rect(Rect2(340, y - 5, 560, 56), Color(1, 1, 1, 0.04))   # 第七輪 E11：斑馬底色
		if set_changed(rows[i][0]):
			draw_circle(Vector2(345, y + 22), 3.5, ACCENT, true, -1.0, true)   # V1.5.1 C1：和預設不同的列
		_text(Vector2(352, y + 12), L.t(rows[i][0]), tz("B"), Color.WHITE, false, false, 270)
		var val: String = rows[i][1]
		var cb: Callable = rows[i][2]
		var r := Rect2(632, y, 260, 48)
		if val.begins_with("@"):
			_btn(r, val.substr(1), cb.bind(1))
		else:
			_btn(Rect2(r.position, Vector2(46, r.size.y)), "◀", cb.bind(-1))
			var tint := Color(0.16, 0.5, 0.3) if val == L.t("on") else TH_WOOD_D
			var vr := Rect2(r.position + Vector2(52, 0), Vector2(r.size.x - 104, r.size.y))
			_btn(vr, val, cb.bind(1), true, false, tint)
			if (val == L.t("on") or val == L.t("off")) and not bool(Save.s("plain_ui")):
				_brass_toggle(Vector2(vr.position.x + 18, vr.get_center().y), val == L.t("on"), bool(_btns[_btns.size() - 1]["en"]))   # 1.2.0 §1.3：開關＝黃銅撥片（字照樣在）
			_btn(Rect2(r.end.x - 46, r.position.y, 46, r.size.y), "▶", cb.bind(1))
		if val.ends_with("%") and rows[i][0] in ["set_master", "set_music", "set_sfx", "set_ui_vol", "set_amb_vol"]:
			var rw := r.size.x - 116
			# 1.3.0 §15：木軌可以拖（輸入佇列處理：按下在軌上開始、拖到哪設到哪、放開才存檔；手把仍用 ◀ ▶ 逐級）
			vol_rails[VOL_KEY[rows[i][0]]] = Rect2(r.position.x + 58, y + 30, rw, 20)
			var fr := int(val.trim_suffix("%")) / 100.0
			if bool(Save.s("plain_ui")):
				draw_rect(Rect2(r.position.x + 58, y + 41, rw * fr, 4), ACCENT)
			else:   # 1.2.0 §1.4 木軌滑塊：凹槽全長＋已填的黃銅段＋黃銅滑塊（只是顯示，操作照舊用 ◀ ▶）
				draw_rect(Rect2(r.position.x + 58, y + 40, rw, 6), Color("#2a1a10"))
				draw_rect(Rect2(r.position.x + 58, y + 41, rw * fr, 4), Color("#b8913f"))
				var kx := r.position.x + 58 + rw * fr
				draw_rect(Rect2(kx - 4, y + 37, 8, 12), Color("#7a5a22"))
				draw_rect(Rect2(kx - 3, y + 38, 6, 10), Color("#d4ae55"))
				draw_rect(Rect2(kx - 2, y + 39, 2, 8), Color(1, 0.96, 0.8, 0.6))
	# 說明欄
	var D0 := SET_DESC
	draw_rect(D0, Color(0, 0, 0, 0.25))
	var key: String = settings_item if settings_item != "" else (rows[0][0] if not rows.is_empty() else "")
	if key != "":
		_text(D0.position + Vector2(14, 12), L.t(key), tz("B"), ACCENT, false, true, D0.size.x - 28)
		var dy := 18 + text_h(L.t(key), tz("B"), D0.size.x - 28, true)
		_text(D0.position + Vector2(14, dy), L.t("sd_" + key), tz("S"), Color(1, 1, 1, 0.85), false, false, D0.size.x - 28)   # 標題換行時說明往下排
		var kk: String = key
		# 一律畫出來（不適用就停用）：焦點換列時按鈕數不變，手把焦點才走得到每一顆
		_btn(Rect2(D0.position.x + 10, D0.end.y - 52, D0.size.x - 20, 44), L.t("set_reset_one"), func(): _reset_rows([kk]), SET_KEYS.has(kk) and set_changed(kk))
		if state == St.BATTLE and not key in ["set_keys", "set_paint", "set_export", "set_import", "set_backup", "set_restore", "set_clear", "set_folder"]:
			# V1.5.1：戰鬥中打開設定，標出這一項什麼時候生效
			var nxt: bool = key in NEXT_GAME_KEYS
			_text(D0.position + Vector2(14, dy + text_h(L.t("sd_" + key), tz("S"), D0.size.x - 28) + 10), L.t("set_when_next") if nxt else L.t("set_when_now"), tz("S"), ACCENT if nxt else Color("#7dff8a"), false, true, D0.size.x - 28)
	var cxm := SET_COL.get_center().x
	_btn(Rect2(cxm - 170, 662, 160, 44), L.t("menu_credits"), func(): _nav_push("settings"); _open("credits"))
	_btn(Rect2(cxm + 10, 662, 160, 44), L.t("back"), func(): _settings_close())


## 1.2.0 §1.3 黃銅撥片開關：開＝撥片朝上＋小綠點、關＝朝下（純裝飾，點擊照原本的值按鈕）
func _brass_toggle(c: Vector2, on: bool, enabled := true) -> void:
	# Antigravity cat02 #5：加大加厚、強化高光與開關明暗；停用時褪色（Codex cat02 #7：七種狀態）
	var k := 1.0 if enabled else 0.55
	var plate := Rect2(c - Vector2(11, 17), Vector2(22, 34))
	draw_rect(plate, Color(Color("#6e5220"), k))
	draw_rect(plate.grow(-2), Color(Color("#c9a24a"), k))
	draw_rect(Rect2(plate.position + Vector2(3, 3), Vector2(4, plate.size.y - 6)), Color(1, 0.95, 0.75, 0.55 * k))   # 左上受光的金屬高光
	draw_rect(Rect2(c - Vector2(3, 12), Vector2(6, 24)), Color(Color("#3a2a10"), k))   # 底槽（深）
	var tip := c + Vector2(0, -10 if on else 10)
	draw_line(c, tip, Color(Color("#f0dfa8"), k), 6.0, true)
	draw_circle(tip, 4.0, Color(Color("#fff2c8"), k))
	draw_circle(c, 2.5, Color(Color("#5a4418"), k))
	if on and enabled:
		draw_circle(c + Vector2(0, 12), 2.8, Color("#5fd16f"))

## ── V1.5 一鍵無障礙預設：直接改原本的設定（可疊加），存一份改之前的值讓「撤回」用 ──
var preset_undo := {}
var hh_fps := 30   # 1.2.0 §15.3：掌機配置要套 30 還是 60fps（二選一，預設省電）
const PRESETS := [
	{"text_scale": 150, "plain_titles": true, "text_plate": true, "focus_strong": true},
	{"reduce_motion": true, "shake_pct": 0, "shake": false, "flash_pct": 0, "flash": false, "slowmo": false, "title_bg": "static", "clutch_zoom": false},
	{"confirm_place": true, "toast_mult": 0, "long_press": 0.8, "hints": "full"},   # 低操作負擔：提示改成手動關
	{"fps_cap": 30, "text_scale": 125, "place_mode": "tap"},
	{"fps_cap": 60, "text_scale": 125, "place_mode": "tap"}]   # 1.2.0 §15.3：掌機建議 60fps 版（和 30fps 版只差 fps_cap；同樣未經實機驗證）   # 1.1.0 E3 掌機建議（Steam Deck 等 7 吋 800p）：只組合現有設定，可撤回；未經實機驗證，不宣稱 Deck 認證

## V1.5.1 C2：套用前先列出會改的項目（確認才套用；零差異直接提示）
func _apply_preset(k: int) -> void:
	var p: Dictionary = PRESETS[k]
	var names: Array = []
	var seen := {}
	for row in SET_KEYS:
		for kk in SET_KEYS[row]:
			if p.has(kk) and str(Save.s(kk)) != str(p[kk]) and not seen.has(row):
				seen[row] = true
				names.append("%s：%s → %s" % [L.t(row), _val_str(Save.s(kk)), _val_str(p[kk])])   # 舊值 → 新值（Codex v151-i1 #12）
	if names.is_empty():
		_toast(L.t("preset_done", [0]))
		return
	_ask_confirm(L.t("preset_q", [names.size()]), func(): _apply_preset_now(k), overlay if overlay != "" else "settings", names)   # V1.5.2 L4：傳完整清單，確認框依實高截   # 第一次啟動頁按的預設，確認後回第一次啟動頁（Antigravity v151-i2 #3）

static func _val_str(v) -> String:
	if v is bool:
		return L.t("on") if v else L.t("off")
	return str(v)

func _apply_preset_now(k: int) -> void:
	var p: Dictionary = PRESETS[k]
	var fp0 = Save.s("fullscreen")
	var n := 0
	for key in p:
		if not preset_undo.has(key):
			preset_undo[key] = Save.s(key)
		if Save.s(key) != p[key]:
			n += 1
	Save.set_settings(p)   # 一次寫檔
	_apply_all_settings()
	_toast(L.t("preset_done", [n]))
	_guard_fs(fp0)

func _undo_preset() -> void:
	Save.set_settings(preset_undo)
	preset_undo = {}
	_apply_all_settings()
	_toast(L.t("preset_undone"))

## 一次改很多項之後，把需要立刻套用的副作用都做一遍（語言字型、音量、幀率、全螢幕、色盲圖集）
func _apply_all_settings() -> void:
	L.lang = Save.s("lang")
	_load_fonts()
	_apply_volumes("")
	_apply_master()
	_apply_display()
	_apply_fullscreen()
	_rebuild_sprites()


## ── V1.5 資料：設定匯出／匯入（剪貼簿代碼 NTS1.）、進度備份／還原（user://backup/）、分項清除 ──
var clear_pick := {}

static func settings_code(d: Dictionary) -> String:
	var keep := d.duplicate(true)
	return "NTS1." + Marshalls.utf8_to_base64(JSON.stringify(keep))

static func settings_decode(code: String):
	var c := code.strip_edges()
	if not c.begins_with("NTS1."):
		return null
	var raw := Marshalls.base64_to_utf8(c.substr(5))
	var d = JSON.parse_string(raw)
	if not d is Dictionary:
		return null
	return Save.sanitize_settings(d)

func _settings_export() -> void:
	DisplayServer.clipboard_set(settings_code(Save.settings))
	_toast(L.t("set_exported"))

func _settings_import() -> void:
	var d = settings_decode(DisplayServer.clipboard_get())
	if d == null:
		_toast(L.t("set_import_bad"), true)
		return
	var ch := {}
	for k in d:
		if k in ["first_done"]:
			continue
		if str(Save.s(k)) != str(d[k]):
			ch[k] = d[k]
	if ch.is_empty():
		_toast(L.t("set_imported", [0]))
		return
	# 先預覽：會改幾項、哪幾項，確認才套用
	var names: Array = []
	for k in ch:
		if L.has("set_" + k):
			names.append(L.t("set_" + k))
	_ask_confirm(L.t("import_q", [ch.size()]), func():
		var fp0 = Save.s("fullscreen")
		Save.set_settings(ch)
		_apply_all_settings()
		_toast(L.t("set_imported", [ch.size()]))
		_guard_fs(fp0), overlay if overlay != "" else "settings", names, "、")   # 從「代碼」頁貼的設定碼，確認後回代碼頁

## V1.5 通用確認框：覆蓋存檔、匯入設定這類動作先問一次。
## V1.5.2 L4：msg＝動作、對象、風險（一定完整顯示）；items＝附加清單（放不下時截前 N 項＋「…等另外 M 項」）。
## 面板高＝文字實高＋間距＋按鈕＋內距，最高到畫面可用高；水平置中。
var confirm_msg := ""
var confirm_items: Array = []
var confirm_sep := "\n"
var confirm_cb := Callable()
var confirm_ret := ""
const CONFIRM_MAX_H := 600.0

func _ask_confirm(msg: String, cb: Callable, ret: String, items: Array = [], sep := "\n") -> void:
	confirm_msg = msg
	confirm_items = items.duplicate()
	confirm_sep = sep
	confirm_cb = cb
	confirm_ret = ret
	overlay = "confirm"
	_focus = 1

## 確認框實際要畫的字：清單從全部開始，放不下就一項一項減，最後補「…等另外 M 項」（純排版，測試用）
func confirm_text() -> String:
	var n := confirm_items.size()
	while true:
		var t := confirm_msg
		if n > 0:
			t += "\n" + confirm_sep.join(confirm_items.slice(0, n))
		if n < confirm_items.size():
			t += ("\n" if confirm_sep == "\n" else confirm_sep) + L.t("confirm_more", [confirm_items.size() - n])
		if n == 0 or 40.0 + text_h(t, fit(t, tz("B"), 540), 540) + GAP_XL + 50.0 + 22.0 <= CONFIRM_MAX_H:
			return t
		n -= 1
	return confirm_msg

func _draw_confirm() -> void:
	_dim(0.6)
	var t := confirm_text()
	var sz := fit(t, tz("B"), 540)   # _text 會先在字級表內縮到放得下最長一行，高度要用縮完的字級算
	var P := modal_rect(600, maxf(220.0, 40.0 + text_h(t, sz, 540) + GAP_XL + 50.0 + 22.0))
	_panel(P)
	_text(Vector2(640, P.position.y + 40), t, sz, Color.WHITE, true, false, 540)
	var okr := Rect2(380, P.end.y - 72, 250, 50)
	set("confirm_ok_r", okr)
	if bool(Save.s("hold_confirm")):
		# V1.6 #7 按住確認：點一下不算，按住 0.6 秒（滑鼠或手把 A）才執行；按鈕底色由左往右填滿
		_btn(okr, L.t("hold_go"), func(): pass, true, false, Color(0.55, 0.16, 0.12))
		draw_rect(Rect2(okr.position, Vector2(okr.size.x * clampf(float(get("hold_t")) / 0.6, 0.0, 1.0), 6)), ACCENT)
	else:
		_btn(okr, L.t("ok_go"), func(): _confirm_go(), true, false, Color(0.55, 0.16, 0.12))
	_btn(Rect2(650, P.end.y - 72, 250, 50), L.t("cancel"), func(): overlay = confirm_ret, true, true)

func _confirm_go() -> void:
	overlay = confirm_ret
	if confirm_cb.is_valid():
		confirm_cb.call()

## V1.5.2：備份資料夾跟著存檔前綴（截圖、測試模式用 shot_／smoke_，不碰玩家真正的備份）。
## 正式遊戲前綴是空的＝仍是 user://backup，舊備份照樣讀得到；不用 file_prefix()（含 demo_，試玩版舊備份會找不到）。
static func backup_dir() -> String:
	return "user://%sbackup" % Save.prefix

static func backup_list() -> Array:
	var out: Array = []
	var dir := DirAccess.open(backup_dir())
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".json"):
			out.append(f)
	out.sort()
	out.reverse()
	return out

func _progress_backup() -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(backup_dir()))
	var dt := Time.get_datetime_dict_from_system()
	var base := "progress_%04d%02d%02d_%02d%02d%02d" % [dt["year"], dt["month"], dt["day"], dt["hour"], dt["minute"], dt["second"]]
	var name := base + ".json"
	var k := 2
	while FileAccess.file_exists(backup_dir() + "/" + name):
		name = "%s_%02d.json" % [base, k]   # 兩位數流水號：字串排序＝時間順序（Codex v150-f3 #3）   # 同一秒連按：不蓋掉前一份（Codex v150-i2 #3）
		k += 1
	var f := FileAccess.open(backup_dir() + "/" + name, FileAccess.WRITE)
	if f == null:
		_toast(L.t("backup_fail"), true)
		return false
	f.store_string(JSON.stringify(Save.data))
	var werr := f.get_error()
	f.close()
	if werr != OK:
		_toast(L.t("backup_fail"), true)
		return false
	var lst := backup_list()
	while lst.size() > 10:   # 最多留 10 份
		DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_dir() + "/" + str(lst.pop_back())))
	_toast(L.t("backup_done", [name]))
	return true

func _progress_restore(name: String) -> void:
	var f := FileAccess.open(backup_dir() + "/" + name, FileAccess.READ)
	if f == null:
		_toast(L.t("backup_fail"), true)
		return
	var d = JSON.parse_string(f.get_as_text())
	if not Save.restorable(d):
		_toast(L.t("restore_bad"), true)   # 不是進度存檔、或是比這版新的格式：不還原
		return
	if Save.data_locked:
		_toast(L.t("restore_bad"), true)   # 目前讀到的是未來版存檔（唯讀）：還原了也存不進去
		return
	if not _progress_backup():   # 還原前先把現在的進度備份一份；備份失敗就不動現在的進度
		return
	var data: Dictionary = Save.migrate(d)
	Save.sanitize_data(data)
	Guide.seed_eff(data)   # V1.6.1：還原的舊備份沒有有效場數，照升級的規則補
	if not _commit_data(data):
		return
	overlay = "settings"   # 還原後留在設定頁（Codex v151-i2）
	_toast(L.t("restore_done"))

## V1.5.1：換整份進度時先寫檔，寫成功才換畫面狀態；寫不進去就還原記憶體裡的舊進度（記憶體與磁碟不會不一致）
func _commit_data(data: Dictionary) -> bool:
	var old: Dictionary = Save.data
	Save.data = data
	if not Save.save_data():
		Save.data = old
		_toast(L.t("save_failed"), true)
		return false
	_after_data_swap()
	return true

## 還原、清除只能在標題畫面做：對局中換掉進度，舊對局結算會寫進新進度（Codex v150-f3 #1）；唯讀（未來版）存檔不能動（#2）
func _data_swap_open(ov: String) -> void:
	if Save.data_locked:
		_toast(L.t("restore_bad"), true)
		return
	if state != St.TITLE:
		_toast(L.t("data_title_only"), true)
		return
	overlay = ov
	_focus = 0

## 整份進度換掉（還原、全部清除）之後：塗裝重新套用、圖集重烘（Codex v150-i2 #6）
func _after_data_swap() -> void:
	call("_paint_apply")
	_rebuild_sprites()

func _draw_restore() -> void:
	_dim(0.6)
	# V1.5.2 L3／L7：說明從緞帶下緣＋16 起、面板高度照內容（沒有備份時不留 500px 空白）、水平置中
	var lst := backup_list()
	var n := mini(10, lst.size())   # 留的 10 份都選得到
	var body := (n * 48.0 - 4.0) if n > 0 else text_h(L.t("restore_none"), tz("B"), 560)
	var P := modal_rect(620, 12.0 + h1_help_h(L.t("restore_help"), tz("S"), 560) + body + GAP_XL + 44.0 + GAP_L)
	_panel(P)
	var ry := _h1_help(Vector2(640, P.position.y + 12), L.t("set_restore"), L.t("restore_help"), tz("S"), 560)
	if lst.is_empty():
		_text(Vector2(640, ry), L.t("restore_none"), tz("B"), TXT_DIM, true, false, 560)
	for i in n:
		var nm: String = lst[i]
		_btn(Rect2(380, ry + i * 48, 520, 44), nm.trim_prefix("progress_").trim_suffix(".json"), func(): _ask_confirm(L.t("restore_q", [nm.trim_prefix("progress_").trim_suffix(".json")]), func(): _progress_restore(nm), "restore"))
	_btn(Rect2(560, P.end.y - GAP_L - 44.0, 160, 44), L.t("back"), func(): overlay = "settings")

const CLEAR_KEYS := [["clr_tutorial", ["tutorial"]], ["clr_puzzles", ["puzzle_stars", "pz_best", "pz_sol", "trial_stars", "coached", "trio_clear", "trio_stars", "notebook"]], ["clr_records", ["stats", "unit_wins", "unit_games", "unit_games_rec", "unit_wins_rec", "custom_stats", "streak", "best_streak", "gauntlet_best", "nemeses", "ghost_beat", "weekly", "eye", "wave_best", "daily_best", "medals", "rush_best", "rush_day", "rift_best", "daily_pend", "daily_streak", "eff_games", "ai_games", "ai_wins"]], ["clr_all", []]]

func _draw_clear_data() -> void:
	_dim(0.6)
	# V1.5.2 L3／L7／L8：說明從緞帶下緣＋16 起、面板照內容高、底部雙按鈕同寬置中
	var P := modal_rect(620, 12.0 + h1_help_h(L.t("clear_help"), tz("S"), 560) + CLEAR_KEYS.size() * 58.0 - 8.0 + GAP_XL + 44.0 + GAP_L)
	_panel(P)
	var cy := _h1_help(Vector2(640, P.position.y + 12), L.t("set_clear"), L.t("clear_help"), tz("S"), 560)
	for i in CLEAR_KEYS.size():
		var on := bool(clear_pick.get(i, false))
		var ii := i
		_btn(Rect2(380, cy + i * 58, 520, 50), ("✓ " if on else "") + L.t(CLEAR_KEYS[i][0]), func(): clear_pick[ii] = not bool(clear_pick.get(ii, false)), true, false, Color(0.5, 0.18, 0.15) if on else Color(0, 0, 0, 0))
	var any := false
	for k in clear_pick:
		any = any or bool(clear_pick[k])
	var by := P.end.y - GAP_L - 44.0
	_btn(Rect2(380, by, 250, 44), L.t("clear_go"), func(): _clear_data(), any, false, Color(0.55, 0.16, 0.12))
	_btn(Rect2(650, by, 250, 44), L.t("back"), func(): overlay = "settings")

func _clear_data() -> void:
	if Save.data_locked or state != St.TITLE:
		return
	if not _progress_backup():   # 清之前自動備份一份；備份失敗就不清
		return
	var nd: Dictionary
	if bool(clear_pick.get(3, false)):
		nd = Save.DEFAULT_SAVE.duplicate(true)
	else:
		nd = Save.data.duplicate(true)   # 先在複本上清，寫檔成功才換（V1.5.1）
		for i in 3:
			if bool(clear_pick.get(i, false)):
				for k in CLEAR_KEYS[i][1]:
					if Save.DEFAULT_SAVE.has(k):
						nd[k] = Save.DEFAULT_SAVE[k].duplicate(true) if Save.DEFAULT_SAVE[k] is Dictionary or Save.DEFAULT_SAVE[k] is Array else Save.DEFAULT_SAVE[k]
					else:
						nd.erase(k)
	Save.sanitize_data(nd)
	if not _commit_data(nd):
		return
	clear_pick = {}
	overlay = "settings"
	_toast(L.t("clear_done"))


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



## V1.5.1：代碼種類（看前綴）："battle" 對戰、"rules" 規則、"challenge" 挑戰、"workshop" 殘局、"settings" 設定、"army" 陣型、"" 認不得
static func code_kind(c: String) -> String:
	var p := c.strip_edges().get_slice(".", 0)
	if p.begins_with("NTBR"):
		return "rules"
	if p in ["NTB2", "NTB3", "NTB4", "NTB7"]:
		return "battle"
	if p in ["NTB1", "NTB5", "NTB6"]:
		return "army"
	if p == "NTC1":
		return "challenge"
	if p == "NTP1" or p == "NTP2" or p == "NTP3" or p == "NTP4" or p == "NTP5":   # 1.2.0 §11.10 NTP5（地形）   # V1.6 #16 出題台碼；V1.6.1 A2 NTP4
		return "workshop"
	if p == "NTS1":
		return "settings"
	if p == "NTW1":
		return "waves"
	if p == "NTQ1":
		return "solution"   # 1.1.0 N5 殘局最佳解碼
	if p == "NTD1":
		return "duel"   # 1.1.0 B2 雙人輪序紀錄碼
	return ""

func _auto_code() -> void:
	var c := DisplayServer.clipboard_get().strip_edges()
	match code_kind(c):
		"battle":
			overlay = ""
			call("_watch_code_str", c)
		"rules":
			overlay = ""
			call("_open_lobby", "ai")
			call("_lobby_paste_code", c)
		"challenge":
			overlay = ""
			call("_accept_challenge", c)
		"workshop":
			overlay = ""
			call("_accept_workshop", c)
		"settings":
			_settings_import()
		"waves":
			var w: Array = call("wave_decode", c)
			if w.is_empty():
				_toast(L.t("code_bad"), true)
			else:
				set("wv_view", w)
				overlay = "wave_codes"
		"solution":
			_accept_solution(c)
		"duel":
			_accept_duel(c)
		"army":
			_toast(L.t("code_army_here"), true)   # 陣型碼要在擺陣畫面貼
		_:
			_toast(L.t("code_bad"), true)

## 1.1.0 B2：輪序紀錄碼：逐手重放驗合法，過了就照對戰碼一樣播最後那兩軍
func _accept_duel(c: String) -> void:
	var d: Dictionary = load("res://scripts/game/duel_code.gd").decode(c)
	if not bool(d.get("ok", false)):
		_toast(L.t("dc_illegal", [int(d["at"]) + 1]) if str(d.get("why", "")) == "illegal" else L.t("code_bad"), true)
		return
	if _demo():
		for a in [d["a0"], d["a1"]]:
			for u in a.units:
				if not RS.available(int(u["type"]), true):
					_toast(L.t("bc_demo_locked"), true)
					return
	overlay = ""
	if bool(d["mismatch"]):
		_toast(L.t("bc_mismatch"))
	else:
		_toast(L.t("dc_ok", [int(d["moves"])]))
	call("watch_code", d["a0"], d["a1"], d["rules"])

## 1.1.0 N5：打開那一關，把朋友的解擺上去（照「重打保留擺法」那一套，固定兵不重複）
func _accept_solution(c: String) -> void:
	var d: Dictionary = load("res://scripts/game/solution_code.gd").decode(c)
	if not bool(d.get("ok", false)):
		_toast(L.t("code_bad"), true)
		return
	var all := PZ.all_puzzles()
	var idx := -1
	for i in all.size():
		if str(all[i]["id"]) == str(d["pid"]):
			idx = i
	if _demo() and (idx < 0 or idx >= Presets.DEMO_PUZZLES):
		_toast(L.t("demo_locked"), true)
		return
	overlay = ""
	set("retry_key", "pz:" + str(d["pid"]))
	var us: Array = []
	for e in d["u"]:
		us.append({"type": int(e[0]), "col": int(e[1]), "row": int(e[2])})
	set("retry_units", us)
	_pick_puzzle(str(d["pid"]), false)
	var pz := PZ.get_puzzle(str(d["pid"]))
	if pz.has("cmd") and not (d["plan"] as Array).is_empty():
		set("puzzle_plan", (d["plan"] as Array).duplicate())   # 時序關卡：連軍令時間一起擺好
		set("puzzle_plan_id", str(d["pid"]))
	call("mark_friend_assist")
	_toast(L.t("sol_loaded"))

func _paste_code() -> void:
	var why := _load_checked(DisplayServer.clipboard_get())
	_toast(L.t("code_loaded") if why == "" else (L.t("code_locked") if why == "locked" else L.t("code_bad")), why != "")
	if why == "":
		overlay = ""


## ── V1.5 主畫面五塊木牌：[名稱, 副標, 代表兵種, 動作, 試玩版也開] ──
func home_plaques() -> Array:
	return [["home_play", "home_play_d", 3, func(): overlay = "hub_play"; _focus = 0, true],
		["menu_gauntlet", "home_gauntlet_d", 1, func(): overlay = "hub_gauntlet"; _focus = 0, false],   # V1.0.0 H1：單人遠征＋雙人接力
		["home_challenge", "home_challenge_d", 2, func(): overlay = "hub_challenge"; _focus = 0, true],
		["menu_playroom", "home_playroom_d", 8, func(): overlay = "playroom"; _focus = 0, false],
		["home_collect", "home_collect_d", 13, func(): overlay = "hub_collect"; _focus = 0, true]]

## 木牌右上的狀態小字：新玩家「先從教學開始」、遠征續局「第 N 站」、每日挑戰今天還沒打。
func home_tag(i: int) -> String:
	match i:
		0:
			return L.t("home_st_tut") if _is_new_player() and Save.s("hints") != "off" else ""
		1:
			var g: Dictionary = Save.data.get("gauntlet_run", {})
			return L.t("home_st_run", [int(g.get("stage", 1))]) if not g.is_empty() and not _demo() else ""
		3:   # V1.0.0 H1：每日挑戰搬到遊戲間
			if _demo():
				return ""
			var sp: Dictionary = Daily.spec(Daily.today())
			return L.t("home_st_daily") if Save.data.get("daily_best", {}).get(sp["key"], []).is_empty() else ""
	return ""

## 第二層卡片：[名稱, 說明, 圖示, 動作, 能不能用]
func hub_items(kind: String) -> Array:
	match kind:
		"hub_play":
			return [["menu_tutorial", "hc_tutorial_d", "book", func(): overlay = ""; _open("tutorial"), true],
				["menu_vs_ai", "hc_vs_ai_d", "robot", func(): overlay = ""; _open_lobby("ai"), true],
				["menu_duel", "hc_duel_d", "people", func(): overlay = ""; _open_lobby("duel"), true],
				["fog_open", "hc_fog_d", "map", func(): overlay = ""; call("_fog_start"), true],   # V1.6 #20
				["sw_open", "hc_sw_d", "swap", func(): overlay = ""; call("_swap_start"), true],   # 1.2.0 §11.5 換邊雙局
				["cp_open", "hc_cp_d", "people", func(): overlay = ""; call("_cp_start"), true]]   # 1.2.0 §11.6 合作布陣
		"hub_gauntlet":   # V1.0.0 H1／M5：遠征牌＝單人遠征＋雙人接力遠征
			return [["menu_gauntlet", "hc_gauntlet_d", "flag", func(): overlay = ""; _enter_gauntlet(), not _demo()],
				["cmp_title", "hc_cmp_d", "book", func(): call("_camp_open"), not _demo()],   # 1.2.0 §11.7 戰役
				["coop_open", "hc_coop_d", "people", func(): overlay = ""; call("_coop_start"), not _demo()]]   # V1.6 #21
		"hub_challenge":   # V1.0.0 H1：「挑戰」拆掉，這張牌改成「殘局」：單人求解類
			return [["menu_puzzle", "hc_puzzle_d", "puzzle", func(): overlay = ""; _open("puzzles"), true],
				["menu_trials", "hc_trials_d", "trophy", func(): overlay = ""; _open("trials"), true],
				["rush_open", "hc_rush_d", "clock", func(): overlay = ""; call("_rush_start"), not _demo()],   # V1.6 #8（題庫是全部殘局：試玩版不開，Codex v160-i1 #7）
				["trio_open", "hc_trio_d", "people", func(): overlay = "trio"; _focus = 0, not _demo()]]   # V1.6 #17
		"playroom":   # V1.0.0 H1：遊戲間＝定期回來的（每日、每週、幽靈、裂隙）＋派對玩法（競猜、輪抽、車輪、雙封蠟）
			return [["menu_daily", "hc_daily_d", "dice", func(): overlay = ""; call("_daily_entry"), not _demo()],   # 1.1.0 N4：今天打過了就開最近 7 天
				["wk_open", "hc_weekly_d", "cards", func(): overlay = "weekly", not _demo()],
				["gh_open", "hc_ghosts_d", "skull", func(): overlay = "ghosts", not _demo()],
				["rift_open", "hc_rift_d", "swap", func(): overlay = "rift"; _focus = 0, not _demo()],   # V1.6 #10
				["pr_wager", "pr_wager_d", "dice", func(): call("_wager_new"), true],
				["pr_draft", "pr_draft_d", "cards", func(): call("_draft_new"), true],
				["pr_waves", "pr_waves_d", "swords", func(): call("_wave_start"), true],
				["pr_sealed", "pr_sealed_d", "book", func(): call("_sealed_start"), true]]
		"hub_collect":
			return [["menu_codex", "hc_codex_d", "book", func(): overlay = ""; _open_codex(0), true],
				["paint_open", "hc_paint_d", "star", func(): call("_paint_open"), true],
				["menu_profile", "hc_profile_d", "trophy", func(): overlay = ""; _open("profile"), true],
				["nem_open", "hc_nem_d", "flag", func(): overlay = "nemeses", not _demo()],
				["ed_open", "hc_ed_d", "puzzle", func(): overlay = "editor"; _focus = 0, not _demo()],   # V1.6 #16 出題台
				["tour_title", "hc_tour_d", "book", func(): overlay = "tour"; _focus = 0, true],   # V1.6.1 N2 新玩法導覽（常駐）
				["sb_title", "hc_sb_d", "book", func(): overlay = "songbook"; _focus = 0, true]]   # 1.2.0 §11.8 棋譜本
	return []

func _draw_hub(kind: String) -> void:
	_dim(0.55)
	nav_stack.clear()   # 回到卡片面板＝堆疊重來
	var items := hub_items(kind)
	var cols := 4 if items.size() > 6 or items.size() == 4 else 3   # V1.6：7 張以上兩列四欄（三列在 150% 放不下）；V1.0.0：剛好 4 張排一列
	var rows := ceili(items.size() / float(cols))
	# V1.5.2 L1：模態面板水平置中；卡片群在面板內置中；卡片從緞帶完整下緣＋GAP_L 起排
	var head := ceilf(h1_bottom(12.0) + GAP_L)
	var rec := hub_note(kind)   # V1.0.0：遊戲間底下的紀錄（眼力分、車輪戰最佳）
	var rec_h := (text_h(rec, tz("S"), 960.0) + GAP_M) if rec != "" else 0.0
	var cw := 236.0
	var pw := 800.0 if cols == 3 else 1040.0
	var ch := 160.0
	var ph := 0.0
	# 卡片高度照最長的說明算；1.2.0 字級表放大後兩列在 150% 會超出畫面 → 先試加寬卡片（說明換行變少）再算高度
	for cw_try in [236.0, 278.0]:
		cw = cw_try
		ch = 160.0
		for it0 in items:
			ch = maxf(ch, 82.0 + tz("B") * 1.6 + text_h(L.t(str(it0[1])), tz("C"), cw - 32) + 14.0)
		ph = head + rows * (ch + 14.0) - 14.0 + GAP_L + rec_h + 44.0 + GAP_L
		pw = (800.0 if cols == 3 else 1040.0) + (cw - 236.0) * cols
		if ph <= 768.0:
			break
	var P := Rect2((1280.0 - pw) * 0.5, clampf((800.0 - ph) * 0.5, 16.0, 120.0), pw, maxf(ph, 300.0))
	_panel(P)
	_h1(Vector2(P.get_center().x, P.position.y + 12), L.t({"hub_play": "home_play", "hub_gauntlet": "menu_gauntlet", "hub_challenge": "home_challenge", "hub_collect": "home_collect", "playroom": "menu_playroom"}.get(kind, "home_play")))
	var ncol := mini(cols, items.size())
	var gx := P.position.x + (P.size.x - (ncol * cw + (ncol - 1) * 14.0)) * 0.5
	var r5: Array = [[], []]   # V1.6 #4：R5 每一列卡片的圖示、標題、說明起點
	for i in items.size():
		var it: Array = items[i]
		var r := Rect2(gx + (i % cols) * (cw + 14), P.position.y + head + (i / cols) * (ch + 14), cw, ch)
		r5[mini(i / cols, 1)].append([Rect2(r.position + Vector2(cw / 2 - 20, 24), Vector2(40, 40)), Rect2(r.position + Vector2(10, 78), Vector2(cw - 20, tz("B"))), Rect2(r.position + Vector2(16, 82 + tz("B") * 1.6), Vector2(cw - 32, tz("C")))])
		btn_paper = true
		var cb: Callable = it[3]
		var ek := str(it[0])
		var ci := i
		_btn(r, "", func(): _nav_push(kind); nav_focus[kind] = ci; nav_hub = kind; Guide.see(Save.data, ek); Save.data["recent"] = Recent.push(Save.data.get("recent", []), kind, ek); cb.call(), bool(it[4]), i == 0)
		btn_paper = false
		var on_paper: bool = bool(_btns[_btns.size() - 1]["en"]) and not bool(Save.s("plain_ui"))
		_ink_mode = on_paper
		var tc2: Color = INK if on_paper else (Color.WHITE if bool(it[4]) else TXT_DIM)
		_icon(str(it[2]), r.position + Vector2(cw / 2, 44), 40.0, Color("#7a4a10") if on_paper else ACCENT)
		_text(r.position + Vector2(cw / 2, 78), L.t(str(it[0])), tz("B"), tc2, true, true, cw - 20)
		_text(r.position + Vector2(16, 82 + tz("B") * 1.6), L.t(str(it[1])), tz("C"), tc2, false, false, cw - 32)
		_ink_mode = false
		if bool(it[4]) and Guide.is_new(Save.data, ek):
			call("_new_tag", r)   # V1.6 #1：沒開過的新入口
	for ri in r5.size():
		if (r5[ri] as Array).size() >= 2:
			probe_cards("hub_cards_%d" % ri, r5[ri])
	if rec != "":
		_text(Vector2(P.get_center().x, P.end.y - GAP_L - 44.0 - rec_h), rec, tz("S"), ACCENT, true, true, 960.0)
	_btn(Rect2(P.get_center().x - 80, P.end.y - GAP_L - 44.0, 160, 44), L.t("back"), func(): overlay = ""; nav_hub = "")

const HUBS := ["hub_play", "hub_gauntlet", "hub_challenge", "playroom", "hub_collect"]
const Recent = preload("res://scripts/game/recent.gd")

## 1.2.0 §11.11 最近玩的：主畫面右上（建議下一步下方）最多 3 顆，點了等於點那張卡片。
func _draw_recent(y: float) -> void:
	if overlay != "":
		return
	var list: Array = Recent.valid(Save.data.get("recent", []), HUBS)
	var shown: Array = []
	for e in list:
		for it in hub_items(str(e["h"])):
			if str(it[0]) == str(e["k"]) and bool(it[4]):
				shown.append([str(e["h"]), it])
	if shown.is_empty():
		return
	_text(Vector2(840, y), L.t("recent_head"), tz("C"), Color(1, 1, 1, 0.85), false, false, 380)
	y += tz("C") * 1.4
	for s in shown:
		var kind: String = s[0]
		var it: Array = s[1]
		var ek := str(it[0])
		var cb: Callable = it[3]
		btn_paper = true   # Antigravity cat08 #1：紙籤（和主畫面卡片同一套），不是深色膠囊
		_btn(Rect2(830, y, 400, 40), "", func(): nav_hub = kind; Guide.see(Save.data, ek); Save.data["recent"] = Recent.push(Save.data.get("recent", []), kind, ek); cb.call(), true, false)
		btn_paper = false
		_ink_mode = not bool(Save.s("plain_ui"))
		_icon(str(it[2]), Vector2(852, y + 20), 22.0, Color("#7a4a10") if _ink_mode else ACCENT)
		_text(Vector2(874, y + (40.0 - tz("S") * 1.2) / 2.0), L.t(ek), tz("S"), INK if _ink_mode else Color.WHITE, false, true, 340)
		_ink_mode = false
		y += 46.0

func hub_note(kind: String) -> String:
	if kind != "playroom":
		return ""
	var rec: Array = []
	var eye: Dictionary = Save.data.get("eye", {})
	if not eye.is_empty():
		rec.append(L.t("pr_eye", [int(eye.get("pts", 0)), int(eye.get("n", 0)), int(eye.get("best", 0))]))
	if int(Save.data.get("wave_best", 0)) > 0:
		rec.append(L.t("pr_wave_best", [int(Save.data.get("wave_best", 0))]))   # Antigravity v140-i3：車輪戰紀錄要看得到
	return "　・　".join(rec)


## ── V1.5 設定套用：總音量、夜間模式（壓縮器）、單聲道（立體聲收成中間）；幀率、垂直同步 ──
func _apply_master() -> void:
	var bus := 0
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(0.0001, int(Save.s("master")) / 100.0)))
	for i in range(AudioServer.get_bus_effect_count(bus) - 1, -1, -1):
		var ef = AudioServer.get_bus_effect(bus, i)
		if ef is AudioEffectCompressor or ef is AudioEffectStereoEnhance:
			AudioServer.remove_bus_effect(bus, i)
	if bool(Save.s("night")):
		var cp := AudioEffectCompressor.new()
		cp.threshold = -18.0
		cp.ratio = 6.0
		cp.gain = 4.0
		AudioServer.add_bus_effect(bus, cp)
	if bool(Save.s("mono")):
		var st := AudioEffectStereoEnhance.new()
		st.pan_pullout = 0.0   # 0＝左右聲道合成中間（單聲道）
		AudioServer.add_bus_effect(bus, st)

func _apply_display() -> void:
	Engine.max_fps = int(Save.s("fps_cap"))
	if shot_dir == "" and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(Save.s("vsync")) else DisplayServer.VSYNC_DISABLED)


## ── V1.5 第一次啟動：主選單前先問語言、字級、無障礙預設（可跳過；XAG：先讓玩家能讀得懂再進遊戲）──
func _draw_first_run() -> void:
	draw_rect(Rect2(0, 0, 1280, 800), Color(0.06, 0.04, 0.03, 0.92))
	# V1.5.2 L3／L7：內容從緞帶下緣＋16 起；面板照內容高（說明到開始鈕不再空 190px）；三排按鈕各自置中
	var P := modal_rect(800, 12.0 + h1_bottom(0.0) + GAP_L + 3.0 * below_head(tz("B")) + 200.0 + text_h(L.t("fr_later"), tz("S"), 700) + GAP_XL + 48.0 + GAP_L)
	_panel(P)
	var y := _h1(Vector2(640, P.position.y + 12), L.t("fr_title")) + GAP_L
	_text(Vector2(640, y), L.t("fr_lang"), tz("B"), Color.WHITE, true, true, 700)
	y += below_head(tz("B"))
	for i in L.LANGS.size():
		var lg: String = L.LANGS[i]
		_btn(Rect2(640.0 - (L.LANGS.size() * 178.0 - 10.0) / 2.0 + i * 178, y, 168, 48), L.lang_name_of(lg), func(): Save.set_setting("lang", lg); L.lang = lg; _load_fonts(), true, false, TH_ACTIVE if L.lang == lg else Color(0, 0, 0, 0))
	y += 70.0
	_text(Vector2(640, y), L.t("fr_text"), tz("B"), Color.WHITE, true, true, 700)
	y += below_head(tz("B"))
	for i in 3:
		var ts0: int = [100, 125, 150][i]
		_btn(Rect2(339 + i * 206, y, 190, 48), "%d%%" % ts0, func(): Save.set_setting("text_scale", ts0), true, false, TH_ACTIVE if int(Save.s("text_scale")) == ts0 else Color(0, 0, 0, 0))
	y += 70.0
	_text(Vector2(640, y), L.t("fr_access"), tz("B"), Color.WHITE, true, true, 700)
	y += below_head(tz("B"))
	var pk := ["preset_vis", "preset_motion", "preset_load"]
	for k in 3:
		var kk := k
		_btn(Rect2(289 + k * 238, y, 226, 48), L.t(pk[k]), func(): _apply_preset(kk), true, false, Color(0.2, 0.36, 0.5))
	y += 60.0
	_text(Vector2(640, y), L.t("fr_later"), tz("S"), TXT_DIM, true, false, 700)
	_btn(Rect2(560, P.end.y - GAP_L - 48.0, 160, 48), L.t("fr_go"), func(): Save.set_setting("first_done", true); overlay = "", true, true)

