extends "res://scripts/ui/screens/game_menus.gd"
const ScreenRules = preload("res://scripts/game/screen_rules.gd")
## V1.6.0 介面層（docs/history/2026-11-10-v1.6.0-plan.md）：新手下一步、試玩回報、分享、教練、極速賽、裂隙、人設、熟練度、實驗簿、出題台、一陣三考、迷霧、接力遠征。
## 純邏輯放 scripts/game/v16_*.gd（可測），這裡只管畫面與流程。

const Funnel = preload("res://scripts/game/funnel.gd")

## ── #2 真人試玩：所在畫面名稱、回報（存檔＋複製到剪貼簿）、離開時記最後的畫面 ──
func screen_id() -> String:
	if overlay != "":
		return overlay
	return ["title", "place", "battle", "result"][state] + ("" if state == St.TITLE else ":" + ["ai", "duel", "tutorial", "puzzle", "gauntlet"][mode])

## 1.1.0 N1：按「回報問題」先選類別（卡關、看不懂、壞掉、建議；可略過），再存檔＋複製。回到原本的畫面。
const FB_CATS := ["stuck", "confusing", "broken", "idea"]
var fb_ret := ""
var fb_screen := ""
func _feedback() -> void:
	fb_screen = screen_id()
	fb_ret = overlay
	overlay = "fb_cat"
	_focus = 0

func _feedback_save(cat: String) -> void:
	overlay = fb_ret
	var txt := Funnel.report(str(ProjectSettings.get_setting("application/config/version")), fb_screen, cat)
	var name := report_name(Save.file_prefix(), int(Time.get_unix_time_from_system()))
	var k := feedback_key(_write_text(name, txt), _clip_set(txt))
	_toast(L.t(k), k == "fb_fail")

## 1.1.0（Codex v110-i1 #7）：同一秒回報兩次不能覆蓋：檔名加流水號，已經有就往後找
static func report_name(prefix: String, sec: int) -> String:
	var n := 0
	var name := "user://%sreport_%d.json" % [prefix, sec]
	while FileAccess.file_exists(name):
		n += 1   # 沒有上限（Codex v110-i2 #7）
		name = "user://%sreport_%d_%d.json" % [prefix, sec, n]
	return name

## 1.1.0 N5（Codex v110-i1 #3）：用朋友的最佳解碼打開的這一題，之後過關算「協力」（不進自力最佳），同一題重打照舊算
func mark_friend_assist() -> void:
	var k := _nb_key()
	if k == "":
		return
	var cd: Dictionary = Save.data.get("coached", {})
	var e: Dictionary = cd.get(k, {"lv": 0, "ap": 0, "self": int(Save.data.get("puzzle_stars", {}).get(k, 0))})
	e["ap"] = 1
	cd[k] = e
	Save.data["coached"] = cd
	co_assist = k

## V1.0.0 D4：寫檔、剪貼簿各自確認，提示照實講（寫檔失敗不能說「也存了一份」）。
static func feedback_key(saved: bool, copied: bool) -> String:
	if saved and copied:
		return "fb_done"
	if saved:
		return "fb_saved_only"
	if copied:
		return "fb_copied_only"
	return "fb_fail"

static func _write_text(path: String, txt: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(txt)
	f.flush()
	var ok := f.get_error() == OK
	f.close()
	return ok and FileAccess.get_file_as_string(path) == txt   # 讀回比對（Codex v100-i1）

static func _clip_set(txt: String) -> bool:
	if DisplayServer.get_name() == "headless" or not DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		return false
	DisplayServer.clipboard_set(txt)
	return DisplayServer.clipboard_get() == txt

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit_mark()

func _quit_mark() -> void:
	Funnel.leave(screen_id())
	Save.save_data()

## 每幀：打開過的畫面記一次里程碑（只有第一次會寫）
const FUNNEL_OVERLAYS := {"tutorial": "tutorial_open", "puzzles": "puzzle_open", "playroom": "playroom_open", "settings": "settings_open"}
var _fn_last := ""
func _v16_tick(_delta: float) -> void:
	var sid := overlay if overlay != "" else str(state)
	if sid != _fn_last:
		_fn_last = sid
		if FUNNEL_OVERLAYS.has(overlay):
			Funnel.mark(FUNNEL_OVERLAYS[overlay])
		if state == St.PLACE:
			match mode:
				Mode.GAUNTLET:
					Funnel.mark("gauntlet_open")
				Mode.VS_AI:
					if not (get("daily_spec") as Dictionary).is_empty():
						Funnel.mark("daily_open")
	_hold_tick(_delta)
	_rush_tick(_delta)
	_coop_tick()
	if fog_on and state == St.PLACE and mode == Mode.VS_AI and not ai_prebuilt:
		call("_build_ai")   # 迷霧推演的下一局：一樣先組好
		ai_prebuilt = true
	_v16_jobs(_delta)

func _open_codex(t: int) -> void:
	Funnel.mark("codex_open")
	super._open_codex(t)

func _finish_battle() -> void:
	super._finish_battle()
	if play_kind != "official" or sim == null:
		return
	if bool(rush.get("on", false)) and mode == Mode.PUZZLE:
		_rush_settle()
		return
	if trio_on and mode == Mode.PUZZLE:
		_trio_settle()
	_coop_settle()
	if mode == Mode.VS_AI and not watch_mode and not bool(get("daily_practice")):
		# V1.0.0（Codex v100-i1）：對 AI 的場數與勝場另記（stats 連教學、殘局都算，建議下一步不能用它判斷「打過 AI」）
		Save.data["ai_games"] = int(Save.data.get("ai_games", 0)) + 1
		if sim.winner == 0:
			Save.data["ai_wins"] = int(Save.data.get("ai_wins", 0)) + 1
	if mode != Mode.TUTORIAL and not watch_mode and not bool(get("daily_practice")) and not (rules != null and Presets.badge(rules, "duel" if mode == Mode.DUEL else "ai") == Presets.BADGE_LAB):
		Save.data["eff_games"] = int(Save.data.get("eff_games", 0)) + 1   # V1.6.1 N1：有效對局（1.1.0：每日練習不算）
	_rift_settle()
	_persona_result()
	if not bool(get("daily_practice")):
		_career_settle()   # 1.1.0（Codex v110-i1 #4）：每日練習不累積熟練度、戰功章
	Funnel.mark("first_battle")
	if mode != Mode.DUEL:
		var won: bool = sim.winner == 0
		Funnel.mark("first_win" if won else "first_loss")
		if mode == Mode.TUTORIAL and won:
			Funnel.mark("tutorial_done")
		if mode == Mode.PUZZLE and puzzle_id != "ws" and (won or bool(report.get("goal_ok", false))):
			Funnel.mark("puzzle_clear")   # 工坊、一陣三考不算（三考只打了第一場，Antigravity v160-i2 #4）
	if Guide.demo_end_due(Save.data, _demo(), demo_end_shown):
		demo_end_shown = true
		Funnel.mark("demo_end")
		overlay = "demo_end"   # 試玩版結尾：完整版有什麼＋願望單

## ── #1 新手：建議下一步、新入口標記、試玩版結尾 ──
func _daily_done_today() -> bool:
	if _demo():
		return true
	var sp: Dictionary = Daily.spec(Daily.today())
	return not (Save.data.get("daily_best", {}).get(sp["key"], []) as Array).is_empty()

func _next_action(k: String) -> Callable:
	match k:
		"tut":
			return func(): _open("tutorial")
		"ai":
			return func(): _open_lobby("ai")
		"puzzle":
			return func(): _open("puzzles")
		"daily":
			return func(): call("_start_daily")
		"gauntlet", "gauntlet_cont":
			return func(): _enter_gauntlet()
		"puzzle_more":
			var pid := Guide.next_puzzle_id(Save.data, PZ.all_puzzles())
			return func(): (_pick_puzzle(pid, false) if pid != "" else _open("puzzles"))
		"playroom":
			return func(): overlay = "playroom"; _focus = 0
		"trials":
			return func(): _open("trials")
	if k.begins_with("v16:"):
		return _entry_action(k.substr(4))
	return func(): pass

## V1.6.1 N1／N2：照卡片定義找某個入口的動作（建議下一步、新玩法導覽共用；點了算看過）
func _entry_action(key: String) -> Callable:
	for kind in HUBS:
		for it in hub_items(kind):
			if str(it[0]) == key:
				var cb: Callable = it[3]
				return func(): Guide.see(Save.data, key); cb.call()
	return func(): pass

const TOUR := [["rush_open", "hc_rush_d", "clock"], ["trio_open", "hc_trio_d", "people"], ["rift_open", "hc_rift_d", "swap"],
	["fog_open", "hc_fog_d", "map"], ["ed_open", "hc_ed_d", "puzzle"], ["coop_open", "hc_coop_d", "people"]]
func _tour_row_h(it: Array) -> float:
	return maxf(56.0, maxf(text_h(L.t(str(it[1])), tz("C"), 900.0 - 80.0 - 300.0), text_h(L.t(str(it[0])), tz("S"), 220.0, true)) + 18.0)

func _draw_tour() -> void:
	var rows := TOUR.size()
	var hsum := 0.0
	for it0 in TOUR:
		hsum += _tour_row_h(it0) + 8.0
	var P := modal_rect(900, 12.0 + h1_help_h(L.t("tour_help"), tz("S"), 740) + GAP_L + hsum + GAP_L + 44.0 + GAP_L)
	_panel(P)
	var y := _h1_help(Vector2(640, P.position.y + 12), L.t("tour_title"), L.t("tour_help"), tz("S"), 740)
	for i in rows:
		var it: Array = TOUR[i]
		var rh := _tour_row_h(it)
		var r := Rect2(P.position.x + 40, y, P.size.x - 80, rh)   # V1.6.1：列高照說明行數（英文長說明會換行）
		y += rh + 8.0
		var en: bool = not _demo() or str(it[0]) == "fog_open"
		_btn(r, "", _entry_action(str(it[0])), en, false)   # 不用主按鈕的橘底：說明字在橘底上對比不夠（接觸表看到）
		_icon(str(it[2]), r.position + Vector2(30, rh / 2.0), 26.0, ACCENT if en else TXT_DIM)
		_text(r.position + Vector2(60, 6), L.t(str(it[0])), tz("S"), Color.WHITE if en else TXT_DIM, false, true, 220)
		_text(r.position + Vector2(290, 8), L.t(str(it[1])), tz("C"), TXT_DIM, false, false, r.size.x - 300)
	_btn(Rect2(560, P.end.y - GAP_L - 44.0, 160, 44), L.t("back"), func(): _nav_back())   # V1.0.0（Codex v100-i1 #8）：和 Esc 同一條返回路徑

func _draw_next_step() -> void:
	if overlay == "" and Guide.tour_due(Save.data, _demo()):
		Guide.see(Save.data, "tour161")   # V1.6.1 N2：老玩家第一次開跳一次（之後在收藏卡片裡隨時可看）
		Save.save_data()
		overlay = "tour"
		_focus = 0
		return
	if Save.s("hints") == "off" or overlay != "":
		return
	var k := Guide.next_step(Save.data, _daily_done_today(), _demo())
	if k == "":
		return
	# 右上角（示範戰場上方的空白）；高度照字級算
	var NS_RECT := Rect2(830, 104, 400, ceilf(14.0 + tz("C") * 1.25 + tz("S") * 1.35))
	_btn(NS_RECT, "", _next_action(k), true, false, Color(0.16, 0.3, 0.42, 0.95))
	_icon("flag", NS_RECT.position + Vector2(30, NS_RECT.size.y / 2), 26.0, ACCENT)
	_text(NS_RECT.position + Vector2(56, 6), L.t("ns_head"), tz("C"), TXT_DIM, false, false, NS_RECT.size.x - 70)
	_text(NS_RECT.position + Vector2(56, 6 + tz("C") * 1.25), _ns_text(k), tz("S"), Color.WHITE, false, true, NS_RECT.size.x - 70)

func _ns_text(k: String) -> String:
	if k.begins_with("v16:"):
		return L.t("ns_new", [L.t(k.substr(4))])
	if k == "gauntlet_cont":
		return L.t("ns_gauntlet_cont", [int(Save.data.get("gauntlet_run", {}).get("stage", 1))])
	if k == "puzzle_more":
		var pid := Guide.next_puzzle_id(Save.data, PZ.all_puzzles())
		var all := PZ.all_puzzles()
		for i in all.size():
			if str(all[i]["id"]) == pid:
				return L.t("ns_puzzle_more", [_pz_label(i)])
		return L.t("ns_puzzle")
	return L.t("ns_" + k)

## 殘局在全部清單的第 i 個 → 「章-關」
func _pz_label(i: int) -> String:
	var n := 0
	for ch in range(1, PZ.CHAPTERS + 1):
		var c := PZ.chapter(ch).size()
		if i < n + c:
			return "%d-%d" % [ch, i - n + 1]
		n += c
	return str(i + 1)

## 「新」小牌：貼在卡片右上角內側（九宮格羊皮紙＋墨字，不只靠顏色）
func _new_tag(r: Rect2) -> void:
	var w := _width(L.t("new_tag"), tz("C"), true) + 20.0
	var tr := Rect2(r.end.x - w - 8.0, r.position.y + 8.0, w, tz("C") * 1.5 + 4.0)
	_tex_box(tr, "wood", Color("#b8322a"))
	_text(tr.position + Vector2(10, 2 + tz("C") * 0.2), L.t("new_tag"), tz("C"), Color.WHITE, false, true, w)

var demo_end_shown := false
func _draw_demo_end() -> void:
	var body := L.t("de_body", [20, 120, 30])
	var P := modal_rect(680, 12.0 + h1_bottom(0.0) + GAP_L + text_h(body, tz("S"), 600) + GAP_XL + 52.0 + GAP_M + 44.0 + GAP_L)
	_panel(P)
	var y := _h1(Vector2(640, P.position.y + 12), L.t("de_title")) + GAP_L
	_text(Vector2(P.position.x + 40, y), body, tz("S"), Color.WHITE, false, false, 600)
	y += text_h(body, tz("S"), 600) + GAP_XL
	var url: String = SteamApi.STORE_URL
	_btn(Rect2(640 - 200, y, 400, 52), L.t("demo_wish_btn") if url != "" else L.t("demo_wish_soon"), func(): OS.shell_open(url), url != "", true)
	_btn(Rect2(640 - 120, y + 52 + GAP_M, 240, 44), L.t("de_keep"), func(): overlay = "")

func _draw_fb_cat() -> void:
	var w := 680.0   # 1.2.0：按鈕加寬到 280 後面板跟著加寬
	var help := L.t("fb_cat_help")
	var P := modal_rect(w, 12.0 + h1_help_h(help, tz("S"), w - 80) + GAP_L + 2 * (50.0 + GAP_M) + 44.0 + GAP_L)
	_panel(P)
	var y := _h1_help(Vector2(640, P.position.y + 12), L.t("fb_btn"), help, tz("S"), w - 80) + GAP_L
	for i in FB_CATS.size():
		var c: String = FB_CATS[i]
		_btn(Rect2(640 - 290 + (i % 2) * 300, y + (i / 2) * (50.0 + GAP_M), 280, 50), L.t("fb_c_" + c), func(): _feedback_save(c), true, i == 0)   # 1.2.0：字級放大，按鈕加寬（220→280）
	_btn(Rect2(560, P.end.y - GAP_L - 44.0, 160, 44), L.t("fb_c_skip"), func(): _feedback_save(""))

## 1.1.0 N4：最近 7 天的每日題（今天照常計紀錄；過去的是練習）
const DAILY_PAST := 7
func _daily_entry() -> void:
	if _daily_done_today():
		overlay = "daily_past"
		_focus = 0
	else:
		call("_start_daily")

func _draw_daily_past() -> void:
	var rowh := 52.0
	var help := L.t("dp_help")
	var P := modal_rect(760, 12.0 + h1_help_h(help, tz("S"), 680) + GAP_L + DAILY_PAST * (rowh + GAP_S) + GAP_L + 44.0 + GAP_L)
	_panel(P)
	var y := _h1_help(Vector2(640, P.position.y + 12), L.t("menu_daily"), help, tz("S"), 680) + GAP_L
	var today: int = Daily.today()
	var best: Dictionary = Save.data.get("daily_best", {})
	for i in DAILY_PAST:
		var day := today - i
		var sp: Dictionary = Daily.spec(day)
		var b: Array = best.get(sp["key"], [])
		var date := Time.get_date_string_from_unix_time(day * 86400)
		var line := "%s　%s" % [date, L.t("daily_mut_%d" % int(sp["mut"]))] + (("　・%d%%" % int(b[0])) if not b.is_empty() else "")
		_text(Vector2(P.position.x + 40, y + 12), line, tz("S"), Color.WHITE if i == 0 else TXT_DIM, false, false, 460)
		var dd := day
		var prac := i > 0
		_btn(Rect2(P.end.x - 220, y + 4, 180, 44), L.t("dp_today") if i == 0 else L.t("dp_practice"), func(): overlay = ""; call("_start_daily_day", dd, prac), true, i == 0)
		y += rowh + GAP_S
	_btn(Rect2(560, P.end.y - GAP_L - 44.0, 160, 44), L.t("back"), func(): _nav_back())

## 1.1.0 B10：手把重播看戰報。重播時底部放不下戰報列（控制列＋按鍵提示），改成按 View／Select 開面板；
## 開著時暫停，返回時還原原本的暫停狀態與按鈕焦點。
var br_paused := false
var br_focus := 0
func _breport_open() -> void:
	br_paused = paused
	br_focus = _focus
	paused = true
	overlay = "breport"
	_focus = 0

func _breport_close() -> void:
	overlay = ""
	paused = br_paused
	_focus = br_focus

func _draw_breport() -> void:
	var help := L.t("br_help")
	var rowh := float(tz("B")) * 1.6
	var n := maxi(1, report_log.size())
	var P := modal_rect(720, 12.0 + h1_help_h(help, tz("S"), 640) + GAP_L + n * rowh + GAP_L + 44.0 + GAP_L)
	_panel(P)
	var y := _h1_help(Vector2(640, P.position.y + 12), L.t("br_title"), help, tz("S"), 640) + GAP_L
	if report_log.is_empty():
		_text(Vector2(640, y), L.t("br_empty"), tz("B"), TXT_DIM, true, false, 600)
	for e in report_log:
		var line := "%s　%s　%s" % ["●" if int(e["team"]) == 0 else "◆", L.t("unit_%d" % int(e["type"])), e["label"]]
		if int(e["n"]) > 1:
			line += " ×%d" % int(e["n"])
		_text(Vector2(P.position.x + 40, y), line, tz("B"), _legible_on(e["col"], TH_WOOD_D), false, false, 640)
		y += rowh
	_btn(Rect2(560, P.end.y - GAP_L - 44.0, 160, 44), L.t("back"), func(): _breport_close(), true, true)

func _draw_v16_overlay(name: String) -> void:
	match name:
		"breport":
			_draw_breport()
		"daily_past":
			_draw_daily_past()
		"nb_words":
			_draw_nb_words()
		"fb_cat":
			_draw_fb_cat()
		"demo_end":
			_draw_demo_end()
		"share":
			_draw_share()
		"rush_end":
			_draw_rush_end()
		"rush_menu":
			_draw_rush_menu()
		"coach":
			_draw_coach()
		"rift":
			_draw_rift()
		"notebook":
			_draw_notebook()
		"daily_top":
			_draw_daily_top()
		"editor":
			_draw_editor()
		"trio":
			_draw_trio()
		"trio_result":
			_draw_trio_result()
		"tour":
			_draw_tour()
		"nb_cmp":
			_draw_nb_cmp()
		"rift_lab":
			_draw_rift_lab()
		"coop_sum":
			_draw_coop_sum()
		"coop_hand":
			_draw_coop_hand()

## ── #6 戰術可視化：擺陣時「射程覆蓋」（V 鍵或資訊帶按鈕），「標記」最多 3 隻（T 鍵或按鈕後點兵），觀戰時追蹤 ──
var tv_range := false
var tv_mark_mode := false
var tv_marks: Array = []      # 標記的兵：世界座標（Vector2i，開戰時對到模擬的兵）
var tv_ids: Array = []
var tv_mode_key := ""        # 這一場對到的模擬 id（順序＝標記號碼）
const TV_MAX := 3

func _tv_pos_list(a) -> Array:
	var out: Array = []
	for u in a.units:
		out.append(a.pos_of(u))
	return out

## 標記：world 附近的我方兵（沒有就不動）；已標記就取消；滿 3 隻擠掉最早的
func tv_toggle_at(a, w: Vector2i) -> bool:
	var i: int = a.index_near(w.x, w.y, 600)
	if i < 0:
		return false
	var p: Vector2i = a.pos_of(a.units[i])
	var k := tv_marks.find(p)
	if k >= 0:
		tv_marks.remove_at(k)
	else:
		if tv_marks.size() >= TV_MAX:
			tv_marks.remove_at(0)
		tv_marks.append(p)
	return true

func _tv_world_at(p: Vector2) -> Vector2i:
	if _is_free():
		return _w_of(p)
	var c := _cell_at(p)
	return Vector2i(c.x * 1000 + 500, c.y * 1000 + 500)

func _v16_place_click(p: Vector2) -> bool:
	if not tv_mark_mode or not Rect2(ORIGIN, fld_size).has_point(p):
		return false
	tv_toggle_at(_cur_army(), _tv_world_at(p))
	sfx.play("k_click", 0.7)
	return true

## 手把：游標所在的世界座標（格子用 cursor，自由用 fp_cur）
func _tv_pad_world() -> Vector2i:
	if _is_free():
		return Vector2i(fp_cur)
	return Vector2i(cursor.x * 1000 + 500, cursor.y * 1000 + 500)

func _v16_place_key(k: int) -> bool:
	if tv_mark_mode and pad_mode and k == KEY_ENTER:
		if tv_toggle_at(_cur_army(), _tv_pad_world()):
			sfx.play("k_click", 0.7)
		return true   # 標記模式：手把 A＝標記（不擺兵）
	match k:
		KEY_V:
			tv_range = not tv_range
			return true
		KEY_N:
			if _nb_key() != "":
				overlay = "notebook"
				_focus = 0
				return true
			return false
		KEY_T:
			if tv_toggle_at(_cur_army(), _tv_pad_world() if pad_mode else _tv_world_at(mouse)):
				sfx.play("k_click", 0.7)
			return true
	return false

## 資訊帶右邊（「?」左邊）兩顆小鈕
func _tv_buttons(help: Rect2, notebook := false) -> void:
	var b1 := Rect2(help.position.x - 88, help.position.y, 40, 36)
	var b2 := Rect2(help.position.x - 44, help.position.y, 40, 36)
	if notebook:
		b1.position.x -= 44
		b2.position.x -= 44
		var b3 := Rect2(help.position.x - 44, help.position.y, 40, 36)
		_btn(b3, "", func(): overlay = "notebook"; _focus = 0)
		_icon("book", b3.get_center(), 22.0, Color.WHITE)
		if b3.has_point(mouse):
			_tv_tip(L.t("nb_tip"), help)
	_btn(b1, "", func(): tv_range = not tv_range, true, false, TH_ACTIVE if tv_range else Color(0, 0, 0, 0))
	_icon("range", b1.get_center(), 22.0, Color.WHITE)
	_btn(b2, "", func(): tv_mark_mode = not tv_mark_mode, true, false, TH_ACTIVE if tv_mark_mode else Color(0, 0, 0, 0))
	_icon("flag", b2.get_center(), 22.0, Color.WHITE)
	if b1.has_point(mouse) or b2.has_point(mouse):
		_tv_tip(L.t("tv_range_tip") if b1.has_point(mouse) else L.t("tv_mark_tip"), help)

func _tv_tip(tip: String, help: Rect2) -> void:
	if true:
		var tw := _width(tip, tz("S")) + 20.0
		var tr := Rect2(clampf(mouse.x - tw / 2, 8, 1272 - tw), help.end.y + 6, tw, tz("S") * 1.6)
		draw_rect(tr, Color(0.06, 0.07, 0.1, 0.92))
		_text(tr.position + Vector2(10, tz("S") * 0.25), tip, tz("S"), Color.WHITE, false, false, tw)

func _foot_of(w: Vector2i) -> Vector2:
	return ORIGIN + Vector2(w.x / 1000.0, w.y / 1000.0 + 0.32) * CS

## 擺陣畫面疊層：射程覆蓋（我方每隻有射程的兵畫淡圈；看得到敵兵時，每隻兵朝最近敵兵畫短箭頭）＋標記號碼
func _v16_place_draw() -> void:
	var a = _cur_army()
	if tv_range:
		var foes: Array = []
		if _enemy_visible() and armies.size() > 1 and mode != Mode.DUEL:
			foes = _tv_pos_list(armies[1])
		for u in a.units:
			var p: Vector2i = a.pos_of(u)
			var sp := _foot_of(p) - Vector2(0, 0.32 * CS)
			var rr: float = _fp_range_of(int(u["type"]))
			if rr > 0.0:
				draw_circle(sp, rr * CS, Color(1, 0.9, 0.5, 0.05))
				call("_arc_clipped", sp, rr * CS, 0, TAU, Color(1, 0.9, 0.5, 0.3), 1.2)
		if not foes.is_empty():
			# V1.6.1 A9：開場鎖定（用模擬跑 1 tick 的選目標結果，不是「最近的敵兵」）；虛線弧，白黑雙邊。不保證第一下打到它（之後會換目標）。
			# 1.1.0 A13：同一個目標第 4 條起不再各畫一條，目標旁標「×N」（N＝總條數；資訊不丟，也不在目標點疊成光團）
			var per := lock_groups(_lock_pairs(a, armies[1]), LOCK_MAX)
			for pr in per["draw"]:
				_lock_arc(_foot_of(pr[0]) - Vector2(0, 0.32 * CS), _foot_of(pr[1]) - Vector2(0, 0.32 * CS))
			for tg in per["count"]:
				var tp := _foot_of(tg) - Vector2(0, 0.32 * CS) + Vector2(10, -18)
				_text(tp, "×%d" % int(per["count"][tg]), tz("C"), Color(1, 0.95, 0.8), false, true, 60)
			for pr in per["rest"]:
				# 第 4 條起：從自己拉一條細淡線到目標旁的「×N」（看得出是哪幾隻鎖它，Codex v110-i1 #6）
				var src := _foot_of(pr[0]) - Vector2(0, 0.32 * CS)
				var dst := _foot_of(pr[1]) - Vector2(0, 0.32 * CS) + Vector2(8, -10)
				draw_line(src, src.lerp(dst, 0.85), Color(1, 0.95, 0.8, 0.28), 1.0, true)
	_tv_draw_marks_place(a)
	_fog_draw()
	_adj_draw(a)

## [[我方位置, 鎖定的敵兵位置], …]（雙方陣型沒變就用快取，不每幀重算）
var lock_key := 0
var lock_cache: Array = []
func _lock_pairs(a0, a1) -> Array:
	if a0 == null or a1 == null or a0.units.is_empty() or a1.units.is_empty():
		return []
	var rr = PZ.rules_of(PZ.get_puzzle(puzzle_id)) if mode == Mode.PUZZLE else rules
	var key := hash([a0.units, a1.units, rr.to_code() if rr != null else ""])
	if key == lock_key:
		return lock_cache
	lock_key = key
	lock_cache = lock_targets(a0, a1, rr)
	return lock_cache

const LOCK_MAX := 3
## 依目標分組：每個目標最多畫 n 條；超過的目標記總條數（畫「×N」）。純函式（測試用）。
static func lock_groups(pairs: Array, n: int) -> Dictionary:
	return ScreenRules.lock_groups(pairs, n)   # 1.1.0 A22：純邏輯搬到 scripts/game/screen_rules.gd

static func lock_targets(a0, a1, rr) -> Array:
	var s = Sim.new(a0.copy(), a1.copy(), rr)
	var start: Array = []
	for u in s.units:
		start.append(Vector2i(u.x, u.y))
	s.step()
	var out: Array = []
	for i in s.units.size():
		var u = s.units[i]
		if u.team == 0 and u.target >= 0 and u.target < start.size() and s.units[u.target].team == 1:
			out.append([start[i], start[u.target]])
	return out

func _lock_arc(a: Vector2, b: Vector2) -> void:
	var mid := (a + b) / 2.0 + (b - a).orthogonal().normalized() * minf(40.0, a.distance_to(b) * 0.18)
	var cb := bool(Save.s("colorblind"))
	var n := 14
	for k in n:
		if k % 2 == 1:
			continue   # 虛線
		var t0 := float(k) / n
		var t1 := float(k + 1) / n
		var p0 := a.lerp(mid, t0).lerp(mid.lerp(b, t0), t0)
		var p1 := a.lerp(mid, t1).lerp(mid.lerp(b, t1), t1)
		draw_line(p0, p1, Color(0, 0, 0, 0.45), 4.0 if cb else 3.0, true)
		draw_line(p0, p1, Color(1, 0.95, 0.8, 0.8 if cb else 0.5), 2.0 if cb else 1.4, true)   # 兵多時不搶戲（Antigravity v161-i1 #5）
	draw_circle(b, 4.0, Color(0, 0, 0, 0.6))
	draw_circle(b, 2.6, Color(1, 0.95, 0.8, 0.9))

func _chalk_arrow(a: Vector2, b: Vector2) -> void:
	draw_line(a, b, Color(1, 1, 1, 0.55), 2.0, true)
	var d := (b - a).normalized()
	draw_line(b, b - d.rotated(0.5) * 8.0, Color(1, 1, 1, 0.55), 2.0, true)
	draw_line(b, b - d.rotated(-0.5) * 8.0, Color(1, 1, 1, 0.55), 2.0, true)

func _tv_badge(at: Vector2, n: int, dead := false) -> void:
	var r := Rect2(at - Vector2(11, 11), Vector2(22, 22))
	draw_rect(r, Color(0.1, 0.1, 0.12, 0.9) if not dead else Color(0.3, 0.3, 0.3, 0.8))
	draw_rect(r, ACCENT if not dead else Color(0.7, 0.7, 0.7), false, 2.0)
	_text(r.position + Vector2(11, 1), str(n) if not dead else "×", tz("C"), Color.WHITE, true, true)

func _tv_draw_marks_place(a) -> void:
	var have := _tv_pos_list(a)
	tv_marks = tv_marks.filter(func(m): return have.has(m))   # 被拿掉的兵自動取消標記
	for i in tv_marks.size():
		_tv_badge(_foot_of(tv_marks[i]) - Vector2(0, 1.05 * CS), i + 1)

func _begin_battle(a0, a1, kind := "official") -> void:
	super._begin_battle(a0, a1, kind)
	if kind == "official":
		Funnel.first_battle_time()   # 1.1.0 A24
	if bool(rush.get("on", false)) and kind == "official":
		call("_on_skip")   # 極速賽：不看戰鬥，直接算結果
	tv_ids = []
	if sim == null or tv_marks.is_empty():
		return
	tv_ids = tv_ids_for(a0, tv_marks)

## 標記的位置 → 模擬的兵 id。開戰時展示緩衝已經讓模擬先跑幾格（位置變了），所以照模擬的編號規則從陣型算：
## 格子＝隊伍×1000＋列×16＋欄；自由＝同隊依 (y, 自己視角 x) 排序的第 k 隻（battle_sim.gd 開頭）。
static func tv_ids_for(a0, marks: Array) -> Array:
	var out: Array = []
	var free: bool = str(a0.deploy) == "free"
	var order: Array = []
	if free:
		for u in a0.units:
			var pp: Vector2i = a0.pos_of(u)
			order.append([pp.y * 100000 + pp.x, pp])
		order.sort_custom(func(p, q): return p[0] < q[0])
	for m in marks:
		if free:
			for k in order.size():
				if order[k][1] == m:
					out.append(k)
					break
		else:
			for u in a0.units:
				if a0.pos_of(u) == m:
					out.append(int(u["row"]) * 16 + int(u["col"]))
					break
	return out

## 戰鬥中：標記的兵頭上號碼；倒下就在最後位置畫灰色 ×
func _v16_battle_draw() -> void:
	if tv_ids.is_empty() or view == null:
		return
	for u in view.units:
		var k := tv_ids.find(u.id)
		if k < 0:
			continue
		var p := _upos(u)
		if u.alive:
			_tv_badge(p - Vector2(0, 1.15 * CS), k + 1)
			var mlv := mastery_lv(int(u.type)) if u.team == 0 else 0
			if mlv >= 3:
				_icon("star", p + Vector2(0, 6), 12.0, Color("#ffd166") if mlv >= 5 else Color("#d8dde6"))   # V1.6.1 A1：只有標記的兵在戰場上顯示熟練度（不常駐，不擋戰場）

## ── #7 操作與無障礙：按住確認、文字放大鏡、軍令點選放置 ──
var hold_t := 0.0
var confirm_ok_r := Rect2()
const HOLD_SEC := 0.6

func _hold_tick(delta: float) -> void:
	if overlay != "confirm" or not bool(Save.s("hold_confirm")):
		hold_t = 0.0
		return
	var down: bool = (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and confirm_ok_r.has_point(mouse)) \
		or (_focus == 0 and hold_keys_down(Save.s("keys"), Save.s("pad")))
	hold_t = hold_t + delta if down else 0.0
	if hold_t >= HOLD_SEC:
		hold_t = 0.0
		if pad_mode and int(Save.s("rumble")) > 0:
			Input.start_joy_vibration(last_joy, 0.2, 0.5 * int(Save.s("rumble")) / 100.0, 0.12)   # 確定的那一下輕震
		call("_confirm_go")

## V1.6.1 F4：按住確認看「改鍵後」的放置／開始鍵，任何一支手把的放置鈕（原本寫死 Enter、Space、0 號手把 A）
static func hold_keys_down(keys, pad) -> bool:
	var kt: Dictionary = keys if keys is Dictionary else {}
	var pt: Dictionary = pad if pad is Dictionary else {}
	for act in ["place", "start"]:
		if Input.is_key_pressed(Keymap.key_of(kt, act)):
			return true
	var pb := int(pt.get("place", JOY_BUTTON_A))
	for dev in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(dev, pb):
			return true
	return false

## 放大鏡：游標指到的介面字，在游標旁邊放大 1.8 倍畫一份（不改版面）
func _draw_magnifier() -> void:
	if mag_hit.is_empty():
		return
	var s: String = mag_hit[0]
	var sz := mini(44, int(int(mag_hit[1]) * 1.8))
	var w := minf(_width(s, sz, bool(mag_hit[2])), 1180.0) + 28.0
	var h := sz * 1.5
	var mp := mag_point()
	var at := Vector2(clampf(mp.x - w / 2, 8, 1272 - w), mp.y + 28 if mp.y < 600 else mp.y - 28 - h)
	draw_rect(Rect2(at, Vector2(w, h)), Color(0.04, 0.05, 0.08, 0.96))
	draw_rect(Rect2(at, Vector2(w, h)), ACCENT, false, 2.0)
	var keep := mag_on
	var kp := layout_probe
	mag_on = false
	layout_probe = false   # 放大的那一份是暫時的疊圖，不算版面
	_text(at + Vector2(14, sz * 0.2), s, sz, Color.WHITE, false, bool(mag_hit[2]), 1180.0)
	mag_on = keep
	layout_probe = kp

## ── #5 社群分享包＋B25 結果頁收合：明信片、出題碼、分享格、精華時刻收進一個「分享」面板 ──
const Share = preload("res://scripts/game/share.gd")
var sh_text := ""   # 這一場的分享格（每日或每週才有）

func _share_ready() -> bool:
	return play_kind == "official" and not watch_mode and sim != null

## 每日挑戰贏了：更新連續天數、產生分享格
func _daily_finish(w: int) -> void:
	super._daily_finish(w)
	sh_text = ""
	if (daily_spec as Dictionary).is_empty() or w != 0 or daily_practice:
		return   # 1.1.0 N4：練習不算連勝、不送排行榜、不產分享格
	var day := int(daily_spec.get("day", Daily.today()))   # 跨 UTC 午夜才打完：照開局那天的題（Codex v160-i1 #6）
	var st: Dictionary = Share.streak_after(Save.data.get("daily_streak", {}), day)
	Save.data["daily_streak"] = st
	Save.save_data()
	var rem: int = PZ.rem_pct(sim.power(0), sim.budget_of(0))
	# #13 每日全球榜：贏了就準備上傳（有 Steam 才真的送；沒送成功留著，下次開每日時補送）
	var det: PackedInt32Array = SteamApi.pack_free(last_armies[0].units, 16000)
	if not det.is_empty():
		var prev: Dictionary = Save.data.get("daily_pend", {})
		var sc := SteamApi.daily_score(rem, armies[0].spent())
		if int(prev.get("day", -1)) != day or int(prev.get("ver", 1)) != Daily.VER or sc > int(prev.get("score", 0)):
			Save.data["daily_pend"] = {"day": day, "score": sc, "det": Array(det), "ver": Daily.VER}
		_daily_sync()
	sh_text = Share.daily_text(L, Time.get_date_string_from_unix_time(day * 86400), L.t("daily_mut_%d" % int(daily_spec["mut"])), rem, armies[0].spent(), armies[0].budget, int(sim.tick / 20), int(st["n"]))

func _highlights() -> Array:
	var out: Array = _key_marks() if not report.is_empty() else []
	if sim != null and sim.winner >= 0:
		out.append({"t": maxi(0, int(sim.tick) - 30), "label": "%s %ds" % [L.t("sh_final"), int(sim.tick) / 20]})
	return out

func _hl_go(t: int) -> void:
	overlay = ""
	call("_replay")
	call("_seek_async", maxi(0, t - 20))

func _draw_share() -> void:
	_dim(0.6)
	var hl := _highlights()
	var sol_ok: bool = mode == Mode.PUZZLE and puzzle_id != "ws" and (Save.data.get("pz_sol", {}) as Dictionary).has(puzzle_id) \
		and load("res://scripts/game/solution_code.gd").entry_valid(puzzle_id, Save.data["pz_sol"][puzzle_id])   # 1.1.0 N5；不合法的舊紀錄不給分享（Codex v110-i3 #1）
	var rows := 1 + (1 if not (daily_spec as Dictionary).is_empty() else 0) + (1 if pc_shot != null else 0) + (1 if bool(call("_ws_ok", sim.winner if sim != null else -1)) else 0) + (1 if sh_text != "" else 0) + (1 if sol_ok else 0) + (1 if duel_code_ok() else 0)
	var P := modal_rect(640, 12.0 + h1_bottom(0.0) + GAP_L + below_head(tz("B")) + maxf(1.0, hl.size()) * 52.0 + GAP_L + rows * 56.0 + GAP_L + 44.0 + GAP_L)
	_panel(P)
	var y := _h1(Vector2(640, P.position.y + 12), L.t("sh_title")) + GAP_L
	_text(Vector2(640, y), L.t("sh_hl"), tz("B"), ACCENT, true, true, 560)
	y += below_head(tz("B"))
	if hl.is_empty():
		_text(Vector2(640, y + 10), L.t("sh_hl_none"), tz("S"), TXT_DIM, true, false, 560)
		y += 52.0
	for m in hl:
		var t := int(m["t"])
		_btn(Rect2(400, y, 480, 44), str(m["label"]), func(): _hl_go(t))
		y += 52.0
	y += GAP_L
	_btn(Rect2(400, y, 480, 48), L.t("replay"), func(): overlay = ""; call("_replay"))
	y += 56.0
	if pc_shot != null:
		_btn(Rect2(400, y, 480, 48), L.t("pc_btn"), func(): overlay = "postcard", true, true)
		y += 56.0
	if bool(call("_ws_ok", sim.winner)):
		_btn(Rect2(400, y, 480, 48), L.t("ws_make"), func(): overlay = ""; call("_make_workshop"))
		y += 56.0
	if sh_text != "":
		_btn(Rect2(400, y, 480, 48), L.t("sh_copy"), func(): DisplayServer.clipboard_set(sh_text); _toast(L.t("sh_copied")))
		y += 56.0
	if sol_ok:
		var sol: Dictionary = Save.data["pz_sol"][puzzle_id]
		var code: String = load("res://scripts/game/solution_code.gd").encode(puzzle_id, sol["u"], sol.get("c", []))
		_btn(Rect2(400, y, 480, 48), L.t("sol_copy", [int(sol["r"][0])]), func(): DisplayServer.clipboard_set(code); _toast(L.t("sol_copied")))
		y += 56.0
	if duel_code_ok():
		var dcode := duel_code_text()   # 1.1.0 B2：雙人輪序紀錄碼
		_btn(Rect2(400, y, 480, 48), L.t("dc_copy"), func(): DisplayServer.clipboard_set(dcode); _toast(L.t("dc_copied")))
		y += 56.0
	if not (daily_spec as Dictionary).is_empty():
		_btn(Rect2(400, y, 480, 48), L.t("dt_title"), func(): _daily_top_open())
		y += 56.0
	_btn(Rect2(560, P.end.y - GAP_L - 44.0, 160, 44), L.t("back"), func(): overlay = "")

func _ghost_settle(w: int) -> void:
	sh_text = ""
	super._ghost_settle(w)
	if bool(get("wk_active")):
		var rec: Dictionary = Save.data.get("weekly", {})
		sh_text = Share.weekly_text(L, int(rec.get("wk", 0)), w == 0, last_armies[0].spent() if last_armies.size() > 0 else 0, int(rec.get("best", 0)), int(rec.get("tries", 0)))

## ── #8 殘局極速賽 ──
const Rush = preload("res://scripts/game/rush.gd")
var rush := {}   # {"on", "left", "ids", "i", "solved", "tried"}

## V1.6.1 D1：入口先開選單——「今日題組」（UTC 日數當種子，大家同一天同一套題，可分享）或「隨機練習」
func _rush_start() -> void:
	overlay = "rush_menu"
	_focus = 0

func _rush_go(daily: bool) -> void:
	var day: int = int(Daily.today())
	var sd := Rush.day_seed(day) if daily else int(Time.get_unix_time_from_system())
	rush = {"on": true, "left": Rush.START_SEC, "ids": Rush.pool(sd), "i": 0, "solved": 0, "tried": 0, "daily": daily, "day": day}
	_rush_load()

func _draw_rush_menu() -> void:
	var rd: Dictionary = Save.data.get("rush_day", {})
	var today := int(Daily.today())
	var tb := int(rd.get("best", 0)) if int(rd.get("day", -1)) == today else -1
	var info := L.t("rush_menu_best", [int(Save.data.get("rush_best", 0))]) + "\n" + (L.t("rush_today_best", [tb]) if tb >= 0 else L.t("rush_today_none"))
	var P := modal_rect(640, 12.0 + h1_help_h(L.t("rush_help", [int(Rush.START_SEC), int(Rush.BONUS_SEC), int(Rush.PENALTY_SEC)]), tz("S"), 560) + GAP_L + text_h(info, tz("S"), 560) + GAP_XL + 52.0 + GAP_M + 44.0 + GAP_L)
	_panel(P)
	var y := _h1_help(Vector2(640, P.position.y + 12), L.t("rush_open"), L.t("rush_help", [int(Rush.START_SEC), int(Rush.BONUS_SEC), int(Rush.PENALTY_SEC)]), tz("S"), 560)
	_text(Vector2(640, y), info, tz("S"), ACCENT, true, false, 560)
	y += text_h(info, tz("S"), 560) + GAP_XL
	_btn(Rect2(640 - 290, y, 280, 52), L.t("rush_daily"), func(): overlay = ""; _rush_go(true), true, true)
	_btn(Rect2(650, y, 280 - GAP_S, 52), L.t("rush_free"), func(): overlay = ""; _rush_go(false))
	_btn(Rect2(560, P.end.y - GAP_L - 44.0, 160, 44), L.t("back"), func(): _nav_back())   # V1.0.0（Codex v100-i1 #8）：和 Esc 同一條返回路徑

func _rush_load() -> void:
	var ids: Array = rush["ids"]
	if int(rush["i"]) >= ids.size():
		_rush_end()
		return
	puzzle_id = str(ids[int(rush["i"])])
	_start_mode(Mode.PUZZLE)

func _rush_end() -> void:
	rush["on"] = false
	var best := int(Save.data.get("rush_best", 0))
	rush["new_best"] = int(rush["solved"]) > best
	if int(rush["solved"]) > best:
		Save.data["rush_best"] = int(rush["solved"])
	if int(rush["solved"]) >= 10:
		call("_ach", "RUSH_10")   # V1.6.1 D7
	if bool(rush.get("daily", false)):
		var rd: Dictionary = Save.data.get("rush_day", {})
		if int(rd.get("day", -1)) != int(rush["day"]) or int(rush["solved"]) > int(rd.get("best", 0)):
			Save.data["rush_day"] = {"day": int(rush["day"]), "best": int(rush["solved"])}   # 今日題組只留今天的最佳
		rush["share"] = Rush.share_text(L, Time.get_date_string_from_unix_time(int(rush["day"]) * 86400), int(rush["solved"]), int(rush["tried"]))
	Save.save_data()
	_go_title()
	overlay = "rush_end"
	_focus = 0

func _rush_tick(delta: float) -> void:
	if not bool(rush.get("on", false)):
		return
	if state == St.PLACE and overlay == "":
		rush["left"] = float(rush["left"]) - delta
		if float(rush["left"]) <= 0.0:
			_rush_end()

## 結算：解開 +20 秒、沒解開 −15 秒，直接換下一題（不進結果頁）
func _rush_settle() -> void:
	var solved: bool = sim.winner == 0 and bool(report.get("goal_ok", true))
	rush["tried"] = int(rush["tried"]) + 1
	if solved:
		rush["solved"] = int(rush["solved"]) + 1
	rush["left"] = Rush.after(float(rush["left"]), solved)
	_toast(L.t("rush_ok" if solved else "rush_bad", [int(Rush.BONUS_SEC if solved else Rush.PENALTY_SEC)]), not solved)
	rush["i"] = int(rush["i"]) + 1
	if float(rush["left"]) <= 0.0:
		_rush_end()
	else:
		_rush_load()

func _v16_place_hud() -> void:
	_coop_hud()
	if bool(rush.get("on", false)):
		var s := L.t("rush_hud", [ceili(maxf(0.0, float(rush["left"]))), int(rush["solved"])])
		var w := _width(s, tz("B"), true) + 32.0
		var r := Rect2(640 - w / 2, 96, w, tz("B") * 1.6)
		_tex_box(r, "wood", Color("#7a2a18") if float(rush["left"]) < 20.0 else Color(0.35, 0.24, 0.12))
		_text(Vector2(640, r.position.y + tz("B") * 0.25), s, tz("B"), Color.WHITE, true, true, w)

func _draw_rush_end() -> void:
	var body := L.t("rush_end_body", [int(rush.get("solved", 0)), int(rush.get("tried", 0)), int(Save.data.get("rush_best", 0))])
	var P := modal_rect(760, 12.0 + h1_bottom(0.0) + GAP_L + text_h(body, tz("B"), 480, true) + GAP_XL + 50.0 + GAP_L)   # 三顆按鈕 690 寬（Codex v161-i1 #12）
	_panel(P)
	var y := _h1(Vector2(640, P.position.y + 12), L.t("rush_title")) + GAP_L
	_text(Vector2(640, y), body, tz("B"), ACCENT if bool(rush.get("new_best", false)) else Color.WHITE, true, true, 480)
	y += text_h(body, tz("B"), 480, true) + GAP_XL
	_btn(Rect2(640 - 345, y, 220, 50), L.t("rush_again"), func(): overlay = ""; _rush_go(bool(rush.get("daily", false))), true, true)
	var sh := str(rush.get("share", ""))
	_btn(Rect2(640 - 110, y, 220, 50), L.t("sh_copy_short"), func(): DisplayServer.clipboard_set(sh); _toast(L.t("sh_copied")), sh != "")   # V1.6.1 D1：今日題組可以分享
	_btn(Rect2(640 + 125, y, 220, 50), L.t("back"), func(): overlay = "")

## ── #9 差一子教練 ──
const Coach = preload("res://scripts/game/coach.gd")
var co_thread: Thread = null
var co_res := {}       # 搜尋結果
var co_layer := 0      # 0 還沒看、1 哪一隻、2 往哪、3 直接擺
var co_key := ""       # 這一場的識別（換場就重算）
var co_ctl := {}       # V1.6.1 F5：和背景搜尋共用的 {"stop", "until", "done"}（取消、期限、進度）

func _coach_pz() -> Dictionary:
	return PZ.get_puzzle(puzzle_id) if mode == Mode.PUZZLE else {}

func coach_ok() -> bool:
	if play_kind != "official" or watch_mode or sim == null or sim.winner == 0 or last_armies.size() != 2:
		return false
	if bool(rush.get("on", false)) or not (mode == Mode.PUZZLE or mode == Mode.VS_AI):
		return false
	if not (get("daily_spec") as Dictionary).is_empty():
		return false   # V1.6.1 A4：每日挑戰不給教練（大家同一題、上排行榜）
	if mode == Mode.PUZZLE and bool(report.get("goal_ok", false)):
		return false
	return Coach.supported(last_armies[0], battle_rules, _coach_pz())

func _coach_open() -> void:
	var key := "%d:%s:%d:%d:%s:%d" % [mode, puzzle_id, last_armies[0].units.hash(), last_armies[1].units.hash(), battle_rules.to_code() if battle_rules != null else "", _coach_pz().hash()]
	if co_thread != null:
		if key != co_key:
			co_key = key   # 換場了：舊的答案算完不收（_v16_jobs 比對 co_thread_key），算完再重開會重算
			co_res = {}
			co_layer = 0
		overlay = "coach"
		_focus = 0
		return
	if key != co_key:
		co_key = key
		co_res = {}
		co_layer = 0
		var a0 = last_armies[0].copy()
		var a1 = last_armies[1].copy()
		var rr = battle_rules.copy() if battle_rules != null else null
		var pz := _coach_pz()
		var ctl := {"stop": false, "until": Time.get_ticks_msec() + Coach.TIME_MS, "done": 0}
		co_ctl = ctl
		if DisplayServer.get_name() == "headless" or shot_dir != "":
			co_res = Coach.search(a0, a1, rr, pz, Coach.LIMIT, ctl)
		else:
			co_thread = bg.start(func(): return Coach.search(a0, a1, rr, pz, Coach.LIMIT, ctl), ctl)
			co_thread_key = key
			if co_thread == null:
				co_key = ""
				_toast(L.t("rv_fail"), true)   # 1.1.0 N6：開不了執行緒就說，可以再按（原本沒看 start 回傳）
				return
	overlay = "coach"
	_focus = 0

var co_thread_key := ""
## V1.0.0 A1：標題頁開著圖鑑、大廳、收藏這類「慢慢看」的頁面時換成慢板（play_music 同一首不會重播）
const CALM_OVERLAYS := ["codex", "lobby", "hub_collect", "profile", "paint", "nemeses"]
func _v16_jobs(_delta: float) -> void:
	_ws_jobs()
	if trio_thread != null and overlay != "trio_result":
		trio_job += 1
		_trio_cancel()   # V1.0.0（Codex v100-i1 #5）：離開三考結算頁（返回、Esc、開別的）就取消背景計算，結果不寫
	if state == St.TITLE and sfx != null and sfx.has_method("play_music") and shot_dir == "":
		sfx.play_music("music_codex" if overlay in CALM_OVERLAYS else "music_title")
	_trio_jobs()
	if co_thread != null and overlay != "coach" and not bool(co_ctl.get("stop", false)):
		_coach_cancel_quiet()   # Esc／手把 B／任何離開教練面板的路徑都取消推演（Codex v161-i1 #3）
	if co_thread != null and not co_thread.is_alive():
		var res = bg.take(co_thread)
		co_thread = null
		if co_thread_key == co_key and str((res as Dictionary).get("status", "")) == "cancel" and overlay == "coach":
			co_key = ""
			_coach_open()   # 取消後又打開同一場：重算（不顯示「已取消」）
		elif co_thread_key == co_key:
			co_res = res   # 過期的結果（換場了）不收
		else:
			var want := co_key
			co_key = ""
			if overlay == "coach" and want != "":
				_coach_open()   # 面板開著、等的是新的這一場：接著算新的

func _exit_tree() -> void:
	SteamApi.lb_drop()   # 1.1.0 A21
	_ws_exit()
	_trio_cancel()
	if co_thread != null:
		bg.retire(co_thread)   # V1.6.1 F5：叫停（64 tick 內會停），等待在 bg.drain()
		co_thread = null
	super._exit_tree()   # battle_view._exit_tree → bg.drain()

## V1.6.1 F5：推演中按「取消」：叫背景停下、關面板；下次打開這一場會重算
func _coach_cancel() -> void:
	_coach_cancel_quiet()
	overlay = ""

func _coach_cancel_quiet() -> void:
	co_ctl["stop"] = true
	co_key = ""

## V1.6.1 A4：教練紀錄分層。鍵＝實驗簿同一套（殘局 id、試煉 t＋編號、工坊／三考依內容）；一般對 AI 不記。
## coached[鍵] = {"lv": 看過的最高提示層級 1～3, "ap": 有沒有套用, "self": 自力最佳星數（沒用教練過關時才更新）}
var co_assist := ""   # 這一題這次有用到第 2 層以上或套用：之後過關算「教練協力」
func _coach_note(lv: int, applied := false) -> void:
	var k := _nb_key()
	if k == "":
		return
	var cd: Dictionary = Save.data.get("coached", {})
	var e: Dictionary = cd.get(k, {"lv": 0, "ap": 0, "self": int(Save.data.get("puzzle_stars", {}).get(k, 0))})
	e["lv"] = maxi(int(e.get("lv", 0)), lv)
	if applied:
		e["ap"] = 1
	cd[k] = e
	Save.data["coached"] = cd
	if lv >= 2 or applied:
		co_assist = k

## 過關時（game_core 存星數之後呼叫）：沒用教練的成績才進「自力最佳」
func _coach_after_clear(stars: int) -> void:
	var k := _nb_key()
	if k == "":
		return
	var cd: Dictionary = Save.data.get("coached", {})
	if not cd.has(k):
		return
	if co_assist != k:
		cd[k]["self"] = maxi(int(cd[k].get("self", 0)), stars)
	Save.data["coached"] = cd

static func coach_badge(data: Dictionary, pid: String) -> bool:
	var e = data.get("coached", {}).get(pid)
	return e is Dictionary and int(e.get("lv", 0)) >= 2 and int(e.get("self", 0)) < int(data.get("puzzle_stars", {}).get(pid, 0))

func _coach_apply() -> void:
	if not bool(co_res.get("found", false)):
		return
	_coach_note(3, true)
	if mode == Mode.PUZZLE:
		var b = co_res["army"]
		armies[0] = b.copy()
		overlay = ""
		state = St.PLACE
		_start_mode(Mode.PUZZLE)
		armies[0] = b.copy()   # _start_mode 會重設陣型：重設之後再擺回教練的陣
		_toast(L.t("co_applied"))
	else:
		# 對 AI：敵陣會換，所以改在覆盤裡套用（同一支敵軍），直接看「如果」
		call("_open_review")
		set("rv_army", co_res["army"].copy())
		call("_rv_dirty")
		call("_rv_recalc")

func _dir_name(f: Vector2i, t: Vector2i) -> String:
	var parts: Array = []
	var dx := t.x - f.x
	if last_armies.size() > 0 and last_armies[0].team == 1:
		dx = -dx
	if dx > 0:
		parts.append(L.t("co_fwd"))
	elif dx < 0:
		parts.append(L.t("co_back"))
	if t.y < f.y:
		parts.append(L.t("co_up"))
	elif t.y > f.y:
		parts.append(L.t("co_down"))
	return L.t("co_and", parts) if parts.size() == 2 else (str(parts[0]) if parts.size() == 1 else "")

func _coach_hint2() -> String:
	if str(co_res.get("kind", "move")) == "swap":
		return L.t("co_l2s", [L.t("unit_%d" % int(co_res["to_type"]))])
	if bool(co_res.get("grid", true)):
		return L.t("co_l2", [_dir_name(co_res["from"], co_res["to"])])
	return L.t("co_l2h", [_dir_name(co_res["from"], co_res["to"])])

func _coach_status_line() -> String:
	var tr := int(co_res.get("tries", 0))
	match str(co_res.get("status", "exhausted")):
		"budget":
			return L.t("co_budget", [tr, int(co_res.get("total", 0)) - tr])
		"timeout":
			return L.t("co_timeout", [tr])
		"cancel":
			return L.t("co_cancelled")
	return L.t("co_none", [tr])

## 第 2 層殘影：小棋盤上原本的兵（實）→ 建議的位置或兵種（半透明）
func _coach_ghost(c: Vector2) -> void:
	var t0 := int(co_res["type"])
	var t1 := int(co_res.get("to_type", t0))
	var cs := 44.0
	var tm: int = last_armies[0].team
	var off := Vector2.ZERO
	if str(co_res.get("kind", "move")) == "swap":
		off = Vector2(cs * 1.6, 0)
	else:
		var f: Vector2i = co_res["from"]
		var t: Vector2i = co_res["to"]
		var k := 1.0 if bool(co_res.get("grid", true)) else 1.0 / Coach.FREE_STEP
		off = Vector2((t.x - f.x) * k, (t.y - f.y) * k).normalized() * cs * 1.6
	var a := c - off / 2.0
	var b := c + off / 2.0
	for gx in range(-2, 3):
		for gy in range(-1, 2):
			draw_rect(Rect2(c + Vector2(gx, gy) * cs - Vector2(cs, cs) / 2.0, Vector2(cs, cs)), Color(1, 1, 1, 0.05 if (gx + gy) % 2 == 0 else 0.02))
	Art.unit(self, a + Vector2(0, 14), t0, tm, 1.0, 0.0, 0.0, 0.0, 1.0, time, 0.62, cbm())
	_chalk_arrow(a + off.normalized() * 20.0, b - off.normalized() * 20.0)
	Art.unit(self, b + Vector2(0, 14), t1, tm, 1.0, 0.0, 0.0, 0.0, 0.42 + 0.12 * sin(time * 4.0), time, 0.62, cbm())

func _draw_coach() -> void:
	var busy := co_thread != null
	var found: bool = bool(co_res.get("found", false))
	var lines: Array = []
	if busy:
		lines.append(L.t("co_busy_n", [int(co_ctl.get("done", 0)), Coach.LIMIT]))
	elif not found:
		lines.append(_coach_status_line())
	else:
		var tn := L.t("unit_%d" % int(co_res["type"]))
		lines.append(L.t("co_l1", [tn]))
		if co_layer >= 2:
			lines.append(_coach_hint2())
	var body := "\n".join(lines)
	var gh := 150.0 if found and co_layer >= 2 else 0.0
	var P := modal_rect(620, 12.0 + h1_help_h(L.t("co_help", [Coach.LIMIT, Coach.TIME_MS / 1000]), tz("S"), 540) + GAP_L + text_h(body, tz("B"), 540) + gh + GAP_XL + 50.0 + GAP_M + 44.0 + GAP_L)
	_panel(P)
	var y := _h1_help(Vector2(640, P.position.y + 12), L.t("co_title"), L.t("co_help", [Coach.LIMIT, Coach.TIME_MS / 1000]), tz("S"), 540)
	_text(Vector2(640, y), body, tz("B"), Color.WHITE, true, true, 540)
	y += text_h(body, tz("B"), 540)
	if gh > 0.0:
		_coach_ghost(Vector2(640, y + gh / 2.0))
		y += gh
	y += GAP_XL
	if busy:
		_btn(Rect2(640 - 160, y, 320, 50), L.t("co_cancel"), func(): _coach_cancel(), true, true)   # 推演中：明顯的取消（手把 A；B＝返回也會取消）
	elif found and co_layer < 2:
		_btn(Rect2(640 - 160, y, 320, 50), L.t("co_more"), func(): co_layer = 2; _coach_note(2), true, true)
	elif found:
		_btn(Rect2(640 - 160, y, 320, 50), L.t("co_apply") if mode == Mode.PUZZLE else L.t("co_review"), func(): _coach_apply(), true, true)
	_btn(Rect2(560, P.end.y - GAP_L - 44.0, 160, 44), L.t("back"), func(): _coach_cancel() if co_thread != null else _close_overlay_plain())
	if found and co_layer < 1:
		co_layer = 1
		_coach_note(1)

func _close_overlay_plain() -> void:
	overlay = ""

## ── #10 裂隙模式 ──
const Rift = preload("res://scripts/game/rift.gd")
var rift_on := false
var rift_wk := 0
var rift_code := ""   # 這一場裂隙的規則碼：「再來一局」要同一組規則才算裂隙（Antigravity v160-i2 #2）   # 開局那一週（跨週才打完也記在那一週，Codex v160-i2 #1）

func _rift_picks() -> Array:
	return Rift.picks(Rift.week(), RS.mask(_demo()))

func _rift_start() -> void:
	var wk := Rift.week()
	rift_wk = wk
	var r = Rift.make_rules(_rift_picks(), RS.mask(_demo()), wk)
	rift_code = r.to_code()
	rules = r
	set("challenge_army", Rift.enemy(r, wk))
	_start_mode(Mode.VS_AI)
	daily_spec = {}   # 不是每日挑戰
	rift_on = true

func _rift_settle() -> void:
	if not rift_on or sim == null or sim.winner != 0:
		return
	var best: Dictionary = Save.data.get("rift_best", {})
	var k := Rift.key(rift_wk)
	if rift_wk != Rift.week():
		return   # 上一週的題：本週紀錄只留本週，跨週打完的不記
	call("_ach", "RIFT_WIN")   # V1.6.1 D7
	var rec := [PZ.rem_pct(sim.power(0), sim.budget_of(0)), armies[0].spent()]
	if Daily.better(rec, best.get(k, [])):
		best[k] = rec
		Save.data["rift_best"] = Rift.keep_recent(best, RIFT_KEEP)   # V1.6.1 A12：留最近 8 週
		Save.save_data()
		_toast(L.t("rf_new", [int(rec[0])]))

const RIFT_KEEP := 8

## ── V1.6.1 A12：異變練習場（自己挑異變；不記週紀錄，不算裂隙成績） ──
var rift_lab: Array = []   # 選了哪些異變（ANOMS 索引）
func rift_lab_toggle(k: int) -> void:
	if k in rift_lab:
		rift_lab.erase(k)
		return
	var tg: String = Rift.ANOMS[k][1]
	rift_lab = rift_lab.filter(func(j): return Rift.ANOMS[j][1] != tg)   # 同類別換掉
	rift_lab = rift_lab.filter(func(j): return not Rift.clash([j], k))   # 容易磨到時間到的組合也換掉（練習場同一套規則）
	var trial: Array = rift_lab + [k]
	if Rift.make_rules(trial, RS.mask(_demo()), Rift.week()).validate().is_empty():
		rift_lab = trial
	else:
		_toast(L.t("rf_lab_bad"), true)

func _rift_lab_start() -> void:
	var wk := Rift.week()
	var r = Rift.make_rules(rift_lab, RS.mask(_demo()), wk)
	rules = r
	set("challenge_army", Rift.enemy(r, wk))
	_start_mode(Mode.VS_AI)
	daily_spec = {}
	rift_on = false   # 練習：不記紀錄

func _draw_rift_lab() -> void:
	var n := Rift.ANOMS.size()
	var rows := ceili(n / 2.0)
	# V1.6.1：異變說明在英文會換兩、三行：每列高度照兩欄裡最長的那個（文字在按鈕裡自己排，不用按鈕標籤）
	var rh: Array = []
	var tot := 0.0
	for ri in rows:
		var h := 46.0
		for c in 2:
			var k0: int = ri * 2 + c
			if k0 < n:
				h = maxf(h, text_h("✓ " + L.t(str(Rift.ANOMS[k0][0])), tz("C"), 335.0) + 14.0)
		rh.append(h)
		tot += h + 6.0
	var P := modal_rect(820, 12.0 + h1_help_h(L.t("rf_lab_help"), tz("S"), 740) + GAP_L + tot + GAP_L + 52.0 + GAP_M + 44.0 + GAP_L)
	_panel(P)
	var y := _h1_help(Vector2(640, P.position.y + 12), L.t("rf_lab"), L.t("rf_lab_help"), tz("S"), 740)
	for ri in rows:
		for c in 2:
			var k: int = ri * 2 + c
			if k >= n:
				continue
			var kk := k
			var on: bool = k in rift_lab
			var br := Rect2(640 - 370 + c * 375, y, 365, float(rh[ri]))
			_btn(br, "", func(): rift_lab_toggle(kk), true, k == 0, TH_ACTIVE if on else Color(0, 0, 0, 0))
			_probe_btn_label = true
			_probe_btn_rect = br
			_text(br.position + Vector2(15, 7), ("✓ " if on else "") + L.t(str(Rift.ANOMS[k][0])), tz("C"), Color.WHITE, false, on, 335.0)
			_probe_btn_label = false
		y += float(rh[ri]) + 6.0
	y += GAP_L - 6.0
	_btn(Rect2(640 - 160, y, 320, 52), L.t("rf_lab_go"), func(): overlay = ""; _rift_lab_start(), not rift_lab.is_empty(), true)
	_btn(Rect2(560, P.end.y - GAP_L - 44.0, 160, 44), L.t("back"), func(): overlay = "rift")

func _draw_rift() -> void:
	var ps := _rift_picks()
	var lines: Array = []
	for k in ps:
		lines.append("・" + L.t(str(Rift.ANOMS[k][0])))
	var body := "\n".join(lines)
	var b: Array = Save.data.get("rift_best", {}).get(Rift.key(Rift.week()), [])
	var best := L.t("rf_best", [int(b[0]), int(b[1])]) if not b.is_empty() else L.t("rf_best_none")
	var hist: Dictionary = Save.data.get("rift_best", {})
	var nwk := Rift.weeks_of(hist).size()
	if nwk > 1 or (nwk == 1 and b.is_empty()):
		best += "\n" + L.t("rf_hist", [nwk, RIFT_KEEP])   # V1.6.1 A12：近 8 週打過幾週
	var P := modal_rect(720, 12.0 + h1_help_h(L.t("rf_help"), tz("S"), 600) + GAP_L + text_h(body, tz("B"), 560) + GAP_M + text_h(best, tz("S"), 560) + GAP_XL + 52.0 + GAP_M + 44.0 + GAP_L)
	_panel(P)
	var y := _h1_help(Vector2(640, P.position.y + 12), L.t("rift_open"), L.t("rf_help"), tz("S"), 600)
	_text(Vector2(360, y), body, tz("B"), Color.WHITE, false, true, 560)
	y += text_h(body, tz("B"), 560) + GAP_M
	_text(Vector2(640, y), best, tz("S"), ACCENT, true, false, 560)
	y += text_h(best, tz("S"), 560) + GAP_XL
	_btn(Rect2(640 - 330, y, 320, 52), L.t("rf_go"), func(): overlay = ""; _rift_start(), true, true)
	_btn(Rect2(650, y, 320 - GAP_S, 52), L.t("rf_lab"), func(): overlay = "rift_lab"; _focus = 0)
	_btn(Rect2(560, P.end.y - GAP_L - 44.0, 160, 44), L.t("back"), func(): _nav_back())

func _start_mode(m: int) -> void:
	var keep_rift: bool = rift_on and m == Mode.VS_AI and rules != null and rules.to_code() == rift_code   # 裂隙「再來一局」照舊（同一組規則才算）
	var mk := "%d:%s:%d:%d" % [m, puzzle_id, int(get("trial_id")), PZ.get_puzzle("ws").hash() if puzzle_id == "ws" else 0]   # 工坊、三考都叫 ws：再比題目內容（Codex v160-i3）
	if mk != tv_mode_key:
		tv_marks = []   # 換題、換模式：舊標記不帶過去（同一題重打保留）
		co_assist = ""   # V1.6.1 A4：換題就是新的嘗試（同一題重打照舊算教練協力）
	if mk != tv_mode_key or m != Mode.PUZZLE:
		trio_job += 1   # 換題、換模式：還在算的三考結果作廢
		_trio_cancel()
	tv_mode_key = mk
	fog_on = false
	tv_mark_mode = false
	var keep_trio: bool = trio_on and m == Mode.PUZZLE and puzzle_id == "ws" and PZ.get_puzzle("ws").has("trio")   # 一陣三考「重試」照舊
	rift_on = false
	trio_on = false
	super._start_mode(m)
	rift_on = keep_rift
	trio_on = keep_trio
	_prewarm_sprites()

## 1.2.0（Antigravity cat01 #1）：圖集烘焙原本在開戰那一刻才觸發，分段後最長一幀 78 ms 會出現在戰鬥開頭。
## 改成進擺陣就依兩邊卡池（含召喚物）預烘：擺陣時玩家在思考，分段烘焙藏在這段時間裡；開戰時 _ensure_sprites 只是確認（烘過的不重烘）。
func _prewarm_sprites() -> void:
	if sprites == null or armies.size() < 2:
		return
	var want := {}
	for a in armies:
		for t in D.total():
			if int(a.pool) & (1 << t):
				want[t] = true
		for u in a.units:
			want[int(u["type"])] = true
	if want.has(F8.SLIME):
		want[F8.MINI_SLIME] = true
	if want.has(F8.BONE):
		want[F8.SKELETON] = true
	var need: Array = want.keys().filter(func(t): return int(t) >= D.COUNT)
	if not need.is_empty():
		sprites.ensure(need)   # 兵種頁：卡池裡的都烘（最多 5 頁，上限照舊）
	var placed := {}
	for a in armies:
		for u in a.units:
			placed[int(u["type"])] = true
	if not placed.is_empty():
		sprites.ensure_turn_atk(placed.keys())   # 轉身出手頁只烘已經在場上的（上限 10 種，不拿整個卡池去洗）

## ── #11 AI 對手人設 ──
const Persona = preload("res://scripts/game/persona.gd")

func _ai_style() -> int:
	return int(rules.ai_style) if rules != null else 0

## V1.6.1（Codex v161-i2 #2）：回標題時，還在算的三考結果作廢（不再寫紀錄）
func _go_title() -> void:
	trio_job += 1
	_trio_cancel()
	super._go_title()

## V1.6.1 A4：從清單點進來＝全新的嘗試（Codex v161-i1 #4）
func _pick_puzzle(id: String, tut: bool) -> void:
	co_assist = ""
	super._pick_puzzle(id, tut)

## V1.6.1 A11：一般對 AI（普通）才用招牌陣
func _signature_tpl(seed: int, pool: int) -> int:
	if mode != Mode.VS_AI or not (get("daily_spec") as Dictionary).is_empty() or rift_on or int(get("trial_id")) >= 0 or get("challenge_army") != null or fog_on:
		return -1
	return Persona.signature(_ai_style(), seed, func(t): return AI.template_ok(t, pool))

## 擺陣時敵方屏風上：頭像＋名號＋開場白（不洩漏陣型）
func _persona_fog(c: Vector2, w: float) -> void:
	if bool(get("ghost_id") != "") or bool(get("wk_active")) or rift_on:
		return
	var st := _ai_style()
	Art.unit(self, c + Vector2(0, 46), Persona.face(st), 1, -1.0, 0.0, 0.0, 0.0, 1.0, time, 1.0, cbm())
	_text(c + Vector2(0, 56), L.t("ps_name_%d" % st), ts(16), Color.WHITE, true, true, w)
	var q := "「" + L.t(Persona.line_key(st, "open")) + "」" if L.lang.begins_with("zh") or L.lang == "ja" else "\"" + L.t(Persona.line_key(st, "open")) + "\""
	_text(c + Vector2(0, 56 + ts(16) * 1.4), q, ts(15), Color(1, 0.9, 0.7, 0.9), true, false, w)
	if difficulty == 1:
		var fv: String = ai_tpl_name(str(AI.TEMPLATES[Persona.fav(st)]["name"]))
		_text(c + Vector2(0, 56 + ts(16) * 1.4 + ts(15) * 1.5 + text_h(q, ts(15), w) - ts(15) * 1.3), L.t("ps_fav", [fv]), ts(14), Color(0.85, 0.9, 1.0, 0.8), true, false, w)   # 「最近愛用」：只說愛用哪套，不保證這場就是

func _persona_result() -> void:
	if mode != Mode.VS_AI or sim == null or sim.winner < 0 or not (get("daily_spec") as Dictionary).is_empty() or rift_on or str(get("ghost_id")) != "" or bool(get("wk_active")) or watch_mode:
		return
	var st := _ai_style()
	report["ps_line"] = L.t("ps_say", [L.t("ps_name_%d" % st), L.t(Persona.line_key(st, "lose" if sim.winner == 0 else "win"))])
	report["ps_hab"] = L.t("ps_hab", [L.t("ps_name_%d" % st), L.t("ps_hab_%d" % clampi(st, 0, 5))])   # 1.1.0 A8：這位對手的習慣（有空位才顯示）

## ── #12 生涯：熟練度＋實驗簿 ──
const Career = preload("res://scripts/game/career.gd")

func _career_settle() -> void:
	if sim == null or mode == Mode.DUEL or watch_mode:
		return
	if rules != null and Presets.badge(rules, "ai") == Presets.BADGE_LAB:
		return
	var m: Dictionary = Save.data.get("mastery", {})
	var ups := Career.add(m, Career.gain(sim.units))
	Save.data["mastery"] = m
	var md: Dictionary = Save.data.get("medals", {})
	var mvp = report.get("mvp")
	Career.medal_add(md, sim.units, int(mvp.type) if mvp != null and mvp.team == 0 and not mvp.summon else -1)
	Save.data["medals"] = md
	for t5 in ups:
		if Career.level(int(m[str(t5)])) >= 5:
			call("_ach", "MASTER_5")   # V1.6.1 D7：升到 5 級那一場才解（不是每場都檢查，避免截圖、老存檔每場跳）
			break
	if not ups.is_empty():
		var t: int = ups[0]
		report["ms_line"] = L.t("ms_up", [L.t("unit_%d" % t), Career.level(int(m[str(t)]))])   # 結果頁有空位才顯示（跳提示會壓到別的畫面）
	if _nb_key() != "" and last_armies.size() == 2:
		var nb: Dictionary = Save.data.get("notebook", {})
		var stv: int = int(report.get("stars", 0)) if mode == Mode.PUZZLE else (1 if sim.winner == 0 else 0)
		Career.nb_result(nb, _nb_key(), Career.units_of(last_armies[0]), stv, PZ.rem_pct(sim.power(0), sim.budget_of(0)) if sim.winner == 0 else 0, last_armies[0].spent(), _nb_hash())
		Save.data["notebook"] = nb

func mastery_line(t: int) -> String:
	var xp := int(Save.data.get("mastery", {}).get(str(t), 0))
	var nx := Career.next_at(xp)
	return L.t("ms_line", [Career.level(xp), xp, nx]) if nx > 0 else L.t("ms_max", [Career.level(xp)])

## 實驗簿的鍵：殘局＝關卡 id、試煉＝t＋編號（Codex v160-i1 #9：方案是殘局與試煉）
func _nb_key() -> String:
	if mode == Mode.PUZZLE:
		return Career.ws_key(PZ.get_puzzle("ws"))[0] if puzzle_id == "ws" else puzzle_id   # V1.6.1 F1：工坊／三考依題目內容
	if mode == Mode.VS_AI and int(get("trial_id")) >= 0:
		return "t%d" % int(get("trial_id"))
	return ""

func _nb_hash() -> String:
	return Career.ws_key(PZ.get_puzzle("ws"))[1] if mode == Mode.PUZZLE and puzzle_id == "ws" else ""

func _nb_items() -> Array:
	return Career.nb_list(Save.data.get("notebook", {}), _nb_key(), _nb_hash())

func _draw_notebook() -> void:
	var lst: Array = _nb_items()
	var rows := maxi(1, lst.size())
	var P := modal_rect(760, 12.0 + h1_help_h(L.t("nb_help"), tz("S"), 680) + GAP_L + rows * 56.0 + GAP_L + 48.0 + GAP_M + 44.0 + GAP_L)
	_panel(P)
	var y := _h1_help(Vector2(640, P.position.y + 12), L.t("nb_title"), L.t("nb_help"), tz("S"), 680)
	if lst.is_empty():
		_text(Vector2(640, y + 12), L.t("nb_empty"), tz("S"), TXT_DIM, true, false, 680)
	for i in lst.size():
		var e: Dictionary = lst[i]
		var r: Array = e["r"]
		var res := L.t("nb_res", [int(r[0]), int(r[1]), int(r[2])]) if r.size() == 3 else L.t("nb_untried")
		var ii := i
		if nb_edit == i:
			# 改名中：輸入框＋游標（Enter 確定、Esc 取消）
			var ir := Rect2(P.position.x + 32, y + 4, 300, 40)
			draw_rect(ir, Color(0.05, 0.06, 0.09, 0.95))
			draw_rect(ir, ACCENT, false, 2.0)
			_text(ir.position + Vector2(10, 6), nb_buf + ("|" if fmod(time, 1.0) < 0.55 else " "), tz("S"), Color.WHITE, false, true, 280)
		else:
			_text(Vector2(P.position.x + 40, y + 10), "%s　%s" % [str(e["n"]), res], tz("S"), Color.WHITE if nb_cmp_a != i else ACCENT, false, true, 300)
		var free_row: bool = nb_edit < 0   # 改名中鎖住其他操作
		_btn_small(Rect2(P.end.x - 370, y + 4, 110, 40), L.t("nb_ok") if nb_edit == i else L.t("nb_rename"), func(): _nb_rename(ii), free_row or nb_edit == i)
		_btn_small(Rect2(P.end.x - 250, y + 4, 110, 40), L.t("nb_load") if nb_cmp_a < 0 else (L.t("nb_pick") if nb_cmp_a != i else L.t("nb_picked")), func(): _nb_load(ii) if nb_cmp_a < 0 else _nb_cmp_pick(ii), nb_cmp_a != i and free_row)
		_btn_small(Rect2(P.end.x - 130, y + 4, 90, 40), L.t("nb_del"), func(): _nb_del(ii), nb_cmp_a < 0 and free_row)
		y += 56.0
	y += GAP_L
	if nb_cmp_a >= 0:
		_btn(Rect2(640 - 160, y, 320, 48), L.t("nb_cmp_cancel"), func(): nb_cmp_a = -1, true, true)
	else:
		_btn(Rect2(640 - 330, y, 320, 48), L.t("nb_save"), func(): _nb_save(), lst.size() < Career.NB_MAX, true)
		_btn(Rect2(650, y, 320 - GAP_S, 48), L.t("nb_cmp"), func(): nb_cmp_a = 0 if lst.size() >= 2 else -1, lst.size() >= 2)
	_btn(Rect2(560, P.end.y - GAP_L - 44.0, 160, 44), L.t("back"), func(): overlay = "")

## ── V1.6.1 N3：實驗簿改名（鍵盤直接打；Steam 手把開 Steam 螢幕鍵盤；都沒有就輪替預設名）＋兩份方案並排比較 ──
var nb_edit := -1
var nb_buf := ""
var nb_edit_obj = null   # 改名的那一份（照物件寫回，不靠索引；Codex v161-i1 #9）
var nb_cmp_a := -1    # 比較：先選的那一份（-1＝不在比較）
var nb_cmp_b := -1
const NB_NAME_MAX := ScreenRules.NB_NAME_MAX   # 1.1.0 A22：單一來源
const NB_PRESETS := ["nb_n_rush", "nb_n_wall", "nb_n_range", "nb_n_cheap", "nb_n_try"]

func _nb_rename(i: int) -> void:
	if nb_edit == i:
		_nb_commit()
		return
	var items := _nb_items()
	if i >= items.size():
		return
	if pad_mode:
		var it: Dictionary = items[i]
		if SteamApi.text_input(L.t("nb_rename"), NB_NAME_MAX, func(sub, txt = ""):
			if bool(sub) and str(txt).strip_edges() != "":
				it["n"] = str(txt).strip_edges().substr(0, NB_NAME_MAX)
				Save.save_data()):
			return
		_nb_words_open(it)   # 1.1.0 B13：沒有 Steam 螢幕鍵盤：詞彙格（原本只能輪替預設名）
		return
	if fp_touch and not DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		_nb_words_open(items[i])   # 觸控又沒有螢幕鍵盤（Windows 平板／Deck 桌面模式）：詞彙格（Codex v161-i1 #8）
		return
	nb_edit = i
	nb_edit_obj = items[i]
	nb_buf = str(items[i]["n"])
	DisplayServer.window_set_ime_active(true)   # 中文、日文輸入法
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_show(nb_buf, Rect2(), DisplayServer.KEYBOARD_TYPE_DEFAULT, NB_NAME_MAX)

## 1.1.0 B13：詞彙格改名（觸控、手把都按得到）：常用戰術詞＋數字拼成名字（最多 16 字），刪一個字、確定、取消。
const NB_WORDS := ["nb_w_0", "nb_w_1", "nb_w_2", "nb_w_3", "nb_w_4", "nb_w_5", "nb_w_6", "nb_w_7", "nb_w_8", "nb_w_9", "nb_w_10", "nb_w_11"]
var nb_words_obj = null
func _nb_words_open(it: Dictionary) -> void:
	nb_words_obj = it
	nb_buf = ""
	overlay = "nb_words"
	_focus = 0

func _nb_words_done(ok: bool) -> void:
	if ok and nb_words_obj is Dictionary and nb_buf.strip_edges() != "" and _nb_items().has(nb_words_obj):
		nb_words_obj["n"] = nb_buf.strip_edges().substr(0, NB_NAME_MAX)
		Save.save_data()
	nb_words_obj = null
	nb_buf = ""
	overlay = "notebook"

static func nb_words_add(buf: String, w: String) -> String:
	return ScreenRules.nb_words_add(buf, w)   # 1.1.0 A22：純邏輯搬到 scripts/game/screen_rules.gd

func _draw_nb_words() -> void:
	var cw := 160.0
	var P := modal_rect(4 * cw + 3 * GAP_M + 64, 12.0 + h1_bottom(0.0) + GAP_L + 48.0 + GAP_L + 3 * (48.0 + GAP_M) + 44.0 + GAP_L + 44.0 + GAP_L)
	_panel(P)
	var y := _h1(Vector2(640, P.position.y + 12), L.t("nb_rename")) + GAP_L
	var ir := Rect2(640 - 2 * cw - 1.5 * GAP_M, y, 4 * cw + 3 * GAP_M, 48)
	draw_rect(ir, Color(0.05, 0.06, 0.09, 0.95))
	draw_rect(ir, ACCENT, false, 2.0)
	_text(ir.position + Vector2(12, 10), nb_buf if nb_buf != "" else L.t("nb_words_hint"), tz("S"), Color.WHITE if nb_buf != "" else TXT_DIM, false, true, ir.size.x - 24)
	y += 48.0 + GAP_L
	for i in NB_WORDS.size():
		var w := L.t(NB_WORDS[i])
		_btn(Rect2(ir.position.x + (i % 4) * (cw + GAP_M), y + (i / 4) * (48.0 + GAP_M), cw, 48), w, func(): nb_buf = nb_words_add(nb_buf, w), nb_buf.length() < NB_NAME_MAX, i == 0)
	y += 3 * (48.0 + GAP_M)
	for d in 5:
		var ds := str(d + 1)
		_btn(Rect2(ir.position.x + d * 64.0, y, 56, 44), ds, func(): nb_buf = nb_words_add(nb_buf, ds), nb_buf.length() < NB_NAME_MAX)
	_btn(Rect2(ir.end.x - 120, y, 120, 44), L.t("nb_words_del"), func(): nb_buf = nb_buf.substr(0, maxi(0, nb_buf.length() - 1)), nb_buf != "")
	_btn(Rect2(640 - 170, P.end.y - GAP_L - 44.0, 160, 44), L.t("nb_ok"), func(): _nb_words_done(true), nb_buf.strip_edges() != "")
	_btn(Rect2(650, P.end.y - GAP_L - 44.0, 160, 44), L.t("cancel"), func(): _nb_words_done(false))

func _nb_cycle_name(it: Dictionary) -> void:
	var cur := str(it["n"])
	var k := 0
	for j in NB_PRESETS.size():
		if L.t(NB_PRESETS[j]) == cur:
			k = j + 1
	it["n"] = L.t(NB_PRESETS[k % NB_PRESETS.size()])
	Save.save_data()

func _nb_commit() -> void:
	if nb_edit_obj is Dictionary and nb_buf.strip_edges() != "" and _nb_items().has(nb_edit_obj):
		nb_edit_obj["n"] = nb_buf.strip_edges().substr(0, NB_NAME_MAX)
		Save.save_data()
	_nb_edit_end()

func _nb_edit_end() -> void:
	nb_edit = -1
	nb_edit_obj = null
	nb_buf = ""
	DisplayServer.window_set_ime_active(false)
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()

func _nb_edit_input(ev: InputEvent) -> bool:
	if overlay != "notebook":
		_nb_edit_end()
		return false
	if ev is InputEventKey and ev.pressed:
		match ev.keycode:
			KEY_ESCAPE:
				_nb_edit_end()
			KEY_ENTER, KEY_KP_ENTER:
				_nb_commit()
			KEY_BACKSPACE:
				nb_buf = nb_buf.substr(0, maxi(0, nb_buf.length() - 1))
			_:
				nb_buf = nb_edit_append(nb_buf, int(ev.unicode))
		return true
	return ev is InputEventKey

static func nb_edit_append(buf: String, uc: int) -> String:
	return ScreenRules.nb_edit_append(buf, uc)   # 1.1.0 A22：純邏輯搬到 scripts/game/screen_rules.gd

func _nb_cmp_pick(i: int) -> void:
	nb_cmp_b = i
	overlay = "nb_cmp"
	_focus = 0

## 兩份方案並排：成績、兵種組成（各幾隻）、花費
func _draw_nb_cmp() -> void:
	var items := _nb_items()
	if nb_cmp_a < 0 or nb_cmp_a >= items.size() or nb_cmp_b < 0 or nb_cmp_b >= items.size():
		overlay = "notebook"
		nb_cmp_a = -1
		return
	var pair: Array = [items[nb_cmp_a], items[nb_cmp_b]]
	var line_h := tz("S") * 1.5
	var P := modal_rect(900, 12.0 + h1_bottom(0.0) + GAP_L + line_h * 3 + 120.0 + GAP_L + 44.0 + GAP_L)
	_panel(P)
	var y := _h1(Vector2(640, P.position.y + 12), L.t("nb_cmp_title")) + GAP_L
	for c in 2:
		var e: Dictionary = pair[c]
		var cx := 640.0 + (c * 2 - 1) * 220.0
		var r: Array = e["r"]
		_text(Vector2(cx, y), str(e["n"]), tz("S"), ACCENT, true, true, 400)
		_text(Vector2(cx, y + line_h), L.t("nb_res", [int(r[0]), int(r[1]), int(r[2])]) if r.size() == 3 else L.t("nb_untried"), tz("S"), Color.WHITE, true, false, 400)
		var cnt := {}
		var gold := 0
		for u in e["u"]:
			cnt[int(u[0])] = int(cnt.get(int(u[0]), 0)) + 1
			gold += D.cost(int(u[0]))
		_text(Vector2(cx, y + line_h * 2), L.t("nb_cmp_gold", [(e["u"] as Array).size(), gold]), tz("S"), TXT_DIM, true, false, 400)
		var ks: Array = cnt.keys()
		ks.sort()
		var x0 := cx - ks.size() * 22.0
		for j in ks.size():
			var px := x0 + j * 44.0 + 22.0
			Art.unit(self, Vector2(px, y + line_h * 3 + 64), int(ks[j]), 0, 1.0, 0.0, 0.0, 0.0, 1.0, time, 0.5, cbm())
			_text(Vector2(px, y + line_h * 3 + 74), "×%d" % int(cnt[ks[j]]), tz("C"), Color.WHITE, true, true, 40)
	draw_line(Vector2(640, y), Vector2(640, y + line_h * 3 + 110), Color(1, 1, 1, 0.2), 1.0)
	_btn(Rect2(560, P.end.y - GAP_L - 44.0, 160, 44), L.t("back"), func(): overlay = "notebook"; nb_cmp_a = -1)

func _nb_save() -> void:
	var nb: Dictionary = Save.data.get("notebook", {})
	var n := _nb_items().size() + 1
	if Career.nb_save(nb, _nb_key(), L.t("nb_name", [n]), Career.units_of(armies[0]), _nb_hash()):
		Save.data["notebook"] = nb
		Save.save_data()
		_toast(L.t("nb_saved"))
	else:
		_toast(L.t("nb_dup"), true)

func _nb_load(i: int) -> void:
	var e: Dictionary = _nb_items()[i]
	if mode == Mode.PUZZLE:
		armies[0] = PZ.player_army(PZ.get_puzzle(puzzle_id))
		var pz := PZ.get_puzzle(puzzle_id)
		for u in e["u"]:
			if (u as Array).size() == 3 and not PZ.is_fixed(pz, int(u[1]), int(u[2])):
				armies[0].place(int(u[0]), int(u[1]), int(u[2]))
	else:
		armies[0].units = []
		for u in e["u"]:
			if (u as Array).size() == 4:
				armies[0].place_xy(int(u[0]), int(u[1]), int(u[2]))
			else:
				armies[0].place(int(u[0]), int(u[1]), int(u[2]))
	overlay = ""

func _nb_del(i: int) -> void:
	var nb: Dictionary = Save.data.get("notebook", {})
	var lst: Array = nb.get(_nb_key(), [])
	var items := _nb_items()
	if i < items.size():
		lst.erase(items[i])   # 清單只顯示同一題的方案（F1）：照物件刪
		nb[_nb_key()] = lst
		Save.data["notebook"] = nb
		Save.save_data()

## ── #13 每日全球榜＋挑戰高手陣 ──
var dt_list: Array = []
var dt_state := ""   # ""、"loading"、"done"、"off"、"fail"（V1.0.0：抓不到或逾時）
var dt_gen := 0

func _daily_sync() -> void:
	var p: Dictionary = Save.data.get("daily_pend", {})
	if not p.is_empty() and SteamApi.available():
		SteamApi.daily_upload(int(p["day"]), int(p["score"]), PackedInt32Array(p.get("det", [])), int(p.get("ver", 1)))

func _daily_top_open() -> void:
	overlay = "daily_top"
	_focus = 0
	dt_list = []
	if not SteamApi.available():
		dt_state = "off"
		return
	dt_state = "loading"
	dt_gen += 1
	var gen := dt_gen
	SteamApi.daily_fetch(int(Daily.today()), func(lst: Array):
		if gen != dt_gen or overlay != "daily_top":
			return   # V1.0.0 W1：離開或重開過，舊的下載結果作廢
		dt_list = lst.slice(0, 5)
		dt_state = "done" if not lst.is_empty() else "fail", Daily.VER)

func _daily_top_go(units: Array) -> void:
	var sp: Dictionary = Daily.spec(Daily.today())
	var r = Daily.make_rules(sp, RS.mask(false))
	var e = Army.new(1, r.budget_of(1))
	e.apply_rules(r, 1)
	for u in units:   # 網路來的陣：照今天的規則一隻一隻擺，有一隻不合法整陣不收（Codex v160-i1 #4）
		if not e.place_xy(int(u["type"]), int(u["x"]), int(u["y"])):
			_toast(L.t("dt_bad"), true)
			return
	if not e.has_combat():
		_toast(L.t("dt_bad"), true)
		return   # 先驗完才動規則與挑戰陣（Codex v160-i2 A7：拒收後重試不能沿用被拒的陣）
	rules = r
	set("challenge_army", e)
	overlay = ""
	_start_mode(Mode.VS_AI)
	daily_spec = {}   # 打高手陣不算今天的每日成績（_start_mode 有挑戰陣時不清，要自己清：Codex v160-i1 #2）
	rift_on = false   # 規則也是 custom：不能被當成裂隙「再來一局」（Antigravity v160-i1 #5）

func _draw_daily_top() -> void:
	var body := ""
	match dt_state:
		"off":
			body = L.t("dt_off")
		"loading":
			body = L.t("dt_loading")
		_:
			body = L.t("dt_none") if dt_list.is_empty() else ""
	var rows := dt_list.size()
	var P := modal_rect(640, 12.0 + h1_help_h(L.t("dt_help"), tz("S"), 560) + GAP_L + (text_h(body, tz("S"), 560) + GAP_L if body != "" else 0.0) + rows * 56.0 + GAP_L + 44.0 + GAP_L)
	_panel(P)
	var y := _h1_help(Vector2(640, P.position.y + 12), L.t("dt_title"), L.t("dt_help"), tz("S"), 560)
	if body != "":
		_text(Vector2(640, y), body, tz("S"), TXT_DIM, true, false, 560)
		y += text_h(body, tz("S"), 560) + GAP_L
	for e in dt_list:
		var sc := int(e.get("score", 0))
		var lbl := L.t("dt_row", [int(e.get("rank", 0)), sc / 1000, 999 - sc % 1000])
		var us: Array = e["units"]
		_btn(Rect2(400, y, 480, 48), lbl, func(): _daily_top_go(us))
		y += 56.0
	_btn(Rect2(560, P.end.y - GAP_L - 44.0, 160, 44), L.t("back"), func(): overlay = "")

## ── #16 殘局出題台：小棋盤擺雙方（左 0～5 欄＝你的解、右 10～15 欄＝敵陣），選目標，作者解要過關才給碼 ──
const WS3 = preload("res://scripts/game/workshop.gd")
var ed_cells := {}      # Vector2i(欄, 列) → 兵種
var ed_type := 0
var ed_goal := 0
var ed_msg := ""
var ed_target := Vector2i(-1, -1)   # V1.6.1 A2：作者指定的目標（斬首＝敵兵、護送／完美＝自己的兵）；-1＝自動
var ed_pick := false               # 正在點選目標
var ed_foe_i := 0                  # V1.6.1 D2：三考題正在編第幾支敵陣
var ed_foes: Array = [{}, {}, {}]  # 三支敵陣（右半邊的格子）
const ED_CS0 := 32.0
## 1.2.0 字級表放大：出題台在 125／150% 垂直放不下（目標列壓到底部按鈕）→ 棋盤格縮小（不縮字）
func ed_cs() -> float:
	return {100: 32.0, 125: 28.0, 150: 26.0}.get(int(Save.s("text_scale")), ED_CS0)

func _ed_rect() -> Rect2:
	return Rect2(640 - 8 * ed_cs(), 150, 16 * ed_cs(), 9 * ed_cs())

func ed_lists() -> Array:
	var e: Array = []
	var s: Array = []
	for k in ed_cells:
		var v := [int(ed_cells[k]), k.x, k.y]
		if k.x >= 10:
			e.append(v)
		elif k.x <= 5:
			s.append(v)
	e.sort()
	s.sort()
	return [e, s]

func ed_toggle(c: Vector2i) -> void:
	if c.x < 0 or c.x > 15 or c.y < 0 or c.y > 8 or (c.x > 5 and c.x < 10):
		return
	if ed_pick:
		var want_foe: bool = WS3.ED_GOALS[ed_goal] == "kill"
		if ed_cells.has(c) and (c.x >= 10) == want_foe:
			ed_target = c
			ed_pick = false
			ed_msg = ""
		else:
			ed_msg = L.t("ed_pick_foe" if want_foe else "ed_pick_own")
		return
	if c == ed_target:
		ed_target = Vector2i(-1, -1)   # 目標那隻被換掉或拿掉：回到自動
	if ed_cells.get(c, -1) == ed_type:
		ed_cells.erase(c)
	else:
		ed_cells[c] = ed_type
	ed_msg = ""

func _ed_make() -> void:
	var l := ed_lists()
	var code := ""
	if WS3.ED_GOALS[ed_goal] == "trio":
		_ed_sync_foe()
		var fl: Array = []
		for f in ed_foes:
			var e: Array = []
			for k in f:
				e.append([int(f[k]), k.x, k.y])
			e.sort()
			fl.append(e)
		code = WS3.encode_trio(fl, l[1])
	else:
		code = WS3.encode4(l[0], l[1], WS3.ED_GOALS[ed_goal], ed_target)
	if code == "":
		ed_msg = L.t("ed_fail")
		return
	DisplayServer.clipboard_set(code)
	call("_ach", "WORKBENCH")   # V1.6.1 D7
	ed_msg = L.t("ed_ok")
	_toast(L.t("ws_copied"))

## 三考題：右半邊的格子存回目前這一支敵陣
func _ed_sync_foe() -> void:
	var f := {}
	for k in ed_cells:
		if k.x >= 10:
			f[k] = ed_cells[k]
	ed_foes[ed_foe_i] = f

func _ed_switch_foe(i: int) -> void:
	_ed_sync_foe()
	for k in ed_cells.keys():
		if k.x >= 10:
			ed_cells.erase(k)
	ed_foe_i = i
	for k in ed_foes[i]:
		ed_cells[k] = ed_foes[i][k]
	ed_msg = ""

func _draw_editor() -> void:
	_dim(0.7)
	var P := Rect2(80, 40, 1120, 720)
	_panel(P)
	probe_skip("R6", "小棋盤是直接畫的格子（不經版面探針），看起來的空白其實是棋盤")
	var y := _h1_help(Vector2(640, P.position.y + 8), L.t("ed_title"), L.t("ed_help"), tz("S"), 1000)
	y += tz("C") * 1.5   # 棋盤上方的「你的解／敵陣」欄標（原本壓到說明，版面檢查 en 125%）
	var G := _ed_rect()
	G.position.y = y
	draw_rect(G, Color(0.42, 0.5, 0.28))
	for cx in 16:
		for cy in 9:
			var r := Rect2(G.position + Vector2(cx, cy) * ed_cs(), Vector2(ed_cs(), ed_cs()))
			if cx > 5 and cx < 10:
				draw_rect(r, Color(0, 0, 0, 0.35))
			draw_rect(r, Color(0, 0, 0, 0.2), false, 1.0)
			var k := Vector2i(cx, cy)
			if ed_cells.has(k):
				Art.unit(self, r.position + Vector2(ed_cs() / 2, ed_cs() * 0.82), int(ed_cells[k]), 0 if cx <= 5 else 1, 1.0 if cx <= 5 else -1.0, 0.0, 0.0, 0.0, 1.0, time, 0.42, cbm())
				if k == ed_target:
					draw_rect(r.grow(-1), Color(0, 0, 0, 0.8), false, 4.0)
					draw_rect(r.grow(-1), Color("#ff5a4a") if WS3.ED_GOALS[ed_goal] == "kill" else Color("#ffd166"), false, 2.5)
			if cx <= 5 or cx >= 10:
				_btns.append({"r": r, "cb": func(): ed_toggle(k), "en": true})
	_text(G.position + Vector2(3 * ed_cs(), -tz("C") * 1.4), L.t("ed_you"), tz("C"), Color("#9fd0ff"), true, true, 6 * ed_cs())
	if WS3.ED_GOALS[ed_goal] == "trio":
		# 三考：敵陣 1／2／3 分頁（欄標的位置）
		for fi in 3:
			var ffi := fi
			_btn_small(Rect2(G.position + Vector2(10 * ed_cs() + fi * 2 * ed_cs(), -tz("C") * 1.6 - 6), Vector2(2 * ed_cs() - 4, tz("C") * 1.5 + 4)), L.t("ed_foe_n", [fi + 1]), func(): _ed_switch_foe(ffi), true, false, TH_ACTIVE if ed_foe_i == fi else Color(0, 0, 0, 0))
	else:
		_text(G.position + Vector2(13 * ed_cs(), -tz("C") * 1.4), L.t("ed_foe"), tz("C"), Color("#ffb0a0"), true, true, 6 * ed_cs())
	y = G.end.y + GAP_M
	# 兵種調色盤（20 種，兩排）
	for t in 20:
		var pr := Rect2(640 - 10 * 50.0 + (t % 10) * 100.0 + 4, y + (t / 10) * 48.0, 92, 44)   # 1.2.0：列高 52→48（150% 放得下）
		_btn(pr, "", func(): ed_type = t, true, false, TH_ACTIVE if ed_type == t else Color(0, 0, 0, 0))
		Art.unit(self, pr.position + Vector2(24, 44), t, 0, 1.0, 0.0, 0.0, 0.0, 1.0, time, 0.42, cbm())
		_text(pr.position + Vector2(46, 14), "%dg" % D.cost(t), tz("C"), Color.WHITE, false, true, 44)
	y += 2 * 48.0 + GAP_S
	var l := ed_lists()
	var gold := [0, 0]
	for i in 2:
		for u in l[i]:
			gold[i] += D.cost(int(u[0]))
	var info := L.t("ed_info", [l[1].size(), gold[1], l[0].size(), gold[0]])
	_text(Vector2(640, y), info, tz("S"), Color.WHITE, true, false, 1000)
	y += tz("S") * 1.4 + GAP_M
	# 目標鈕獨立一排（英文長說明放得下）；下一排三顆同寬置中（R4）
	var gname: String = WS3.ED_GOALS[ed_goal]
	var cyc := func(): ed_goal = (ed_goal + 1) % WS3.ED_GOALS.size(); ed_msg = ""; ed_target = Vector2i(-1, -1); ed_pick = false
	if gname in WS3.PICK_GOALS:
		# V1.6.1 A2：可以自己點目標（同一排兩顆，整排置中）
		var tl: String = L.t("ed_tgt_pick") if ed_pick else (L.t("ed_tgt_auto") if ed_target.x < 0 else L.t("ed_tgt_set", [L.t("unit_%d" % int(ed_cells.get(ed_target, 0)))]))
		_btn(Rect2(640 - 380, y, 480, 44), L.t("ed_goal", [L.t("ed_g_" + gname)]), cyc)
		_btn(Rect2(640 + 100 + GAP_S, y, 280 - GAP_S, 44), tl, func(): ed_pick = not ed_pick; ed_msg = L.t("ed_pick_foe" if gname == "kill" else "ed_pick_own") if ed_pick else "", true, false, TH_ACTIVE if ed_pick else Color(0, 0, 0, 0))
	else:
		_btn(Rect2(640 - 380, y, 760, 44), L.t("ed_goal", [L.t("ed_g_" + gname)]), cyc)
	y += 44 + GAP_S
	if ed_msg != "":
		_text(Vector2(640, y), ed_msg, tz("S"), ACCENT, true, true, 1000)
	var by := P.end.y - GAP_L - 48.0
	_btn(Rect2(640 - 3 * 150 - 20, by, 300, 48), L.t("ed_make"), func(): _ed_make(), not l[0].is_empty() and not l[1].is_empty(), true)
	_btn(Rect2(640 - 150, by, 300, 48), L.t("clear"), func(): ed_cells = {}; ed_msg = ""; ed_target = Vector2i(-1, -1); ed_pick = false; ed_foes = [{}, {}, {}])
	_btn(Rect2(640 + 150 + 20, by, 300, 48), L.t("back"), func(): _nav_back())   # V1.0.0（Codex v100-i1 #8）：和 Esc 同一條返回路徑

## ── #17 一陣三考 ──
const Trio = preload("res://scripts/game/trio.gd")
var trio_on := false
var trio_i := 0
var trio_res: Array = []

var trio_custom := {}   # V1.6.1 D2：朋友用出題台出的三考題（不存紀錄）
func _trio_set() -> Dictionary:
	return trio_custom if not trio_custom.is_empty() else Trio.sets()[trio_i]

func _trio_start_custom(ts: Dictionary) -> void:
	trio_custom = ts
	PZ.set_custom(Trio.make_pz(ts, 0))
	puzzle_id = "ws"
	overlay = ""
	_start_mode(Mode.PUZZLE)
	trio_on = true

func _trio_start(i: int) -> void:
	trio_custom = {}
	trio_i = i
	PZ.set_custom(Trio.make_pz(Trio.sets()[i], 0))
	puzzle_id = "ws"
	overlay = ""
	_start_mode(Mode.PUZZLE)
	trio_on = true

## V1.6.1 F7：第一場就是剛打完的這場（不重算）；第 2、3 場在背景算（顯示「計算中」），算完才寫紀錄、開結算。
var trio_thread: Thread = null
var trio_extra: Array = []
var trio_busy := false
var trio_st := 0
var trio_job := 0          # 每次結算 +1；換題、離開也 +1，舊的背景結果就作廢（Codex v161-i1 #2）
var trio_snap := {}        # 結算當下的題組與花費（背景算完用它，不用當下的狀態）
func _trio_settle() -> void:
	var extra: Array = []
	for u in last_armies[0].units:
		extra.append([int(u["type"]), int(u["col"]), int(u["row"])])
	trio_extra = extra
	var s: Dictionary = _trio_set()
	trio_job += 1
	trio_snap = {"set": s, "spent": last_armies[0].spent(), "custom": not trio_custom.is_empty(), "job": trio_job}
	var oc: Dictionary = PZ.outcome(PZ.get_puzzle("ws"), sim, last_armies[0].spent())
	trio_res = [{"ok": bool(oc["ok"]), "rem": int(oc["rem"]), "spent": int(oc["spent"])}]
	trio_st = 0
	overlay = "trio_result"
	_focus = 0
	if DisplayServer.get_name() == "headless" or shot_dir != "":
		trio_res += Trio.results(s, extra, 1)
		_trio_done()
		return
	_trio_cancel()   # 上一組還在算（極少見）：叫它停，背景收（不在主執行緒等）
	trio_busy = true
	trio_err = false
	var ctl: Dictionary = BgPool.make_ctl(TRIO_LIMIT_MS, {"total": 2})   # 背景算第 2、3 場
	trio_ctl = ctl
	var job := trio_job
	var inp: Dictionary = s.duplicate(true)   # 背景只用自己的副本（V1.0.0 M13）
	var ex: Array = extra.duplicate(true)
	var t: Thread = bg.start(func(): return [job, Trio.results(inp, ex, 1, ctl)], ctl)
	if t == null:
		trio_busy = false
		trio_err = true   # 開不了執行緒：顯示失敗、可以重試（Codex v100-i1 #4：不退回主執行緒無期限重算）
		return
	trio_thread = t

## V1.0.0 M13：三考背景運算可取消、有期限（TRIO_LIMIT_MS），被取消的交給 bg（BgPool）回收，不阻塞畫面。
const TRIO_LIMIT_MS := 20000
var trio_ctl := {}
var trio_err := false   # 逾時：不寫星數，結算頁顯示「算太久」
func _trio_cancel() -> void:
	if trio_thread != null:
		bg.retire(trio_thread)
		trio_thread = null
		trio_busy = false

func _trio_jobs() -> void:
	if trio_thread != null and not trio_thread.is_alive():
		var got: Array = bg.take(trio_thread)
		trio_thread = null
		trio_busy = false
		if int(got[0]) == trio_job and trio_res.size() == 1:
			if (got[1] as Array).is_empty():
				trio_err = true   # 逾時被停：不寫紀錄
				return
			trio_res += got[1]
			_trio_done()

func _trio_done() -> void:
	var s: Dictionary = trio_snap.get("set", _trio_set())
	trio_st = Trio.stars(s, trio_res)
	var custom: bool = bool(trio_snap.get("custom", not trio_custom.is_empty()))
	if trio_st == 3 and not custom:
		call("_ach", "TRIO_STAR3")   # V1.6.1 D7
	if trio_st >= 1 and not custom:   # 朋友出的三考題不存紀錄
		var cl: Dictionary = Save.data.get("trio_clear", {})
		var id := str(s["id"])
		var sp: int = int(trio_snap.get("spent", last_armies[0].spent()))
		if not cl.has(id) or sp < int(cl[id]):
			cl[id] = sp
			Save.data["trio_clear"] = cl
		var ts: Dictionary = Save.data.get("trio_stars", {})
		if trio_st > int(ts.get(id, 0)):
			ts[id] = trio_st
			Save.data["trio_stars"] = ts
		Save.save_data()

## 看第 k 場（同一套陣對第 k 支敵軍；當成觀戰，不算紀錄）
func _trio_watch(k: int) -> void:
	var pz: Dictionary = Trio.make_pz(_trio_set(), k)
	var a0 = PZ.player_army(pz)
	for e in trio_extra:
		a0.units.append({"type": int(e[0]), "col": int(e[1]), "row": int(e[2])})
	trio_on = false
	call("watch_code", a0, PZ.enemy_army(pz), PZ.rules_of(pz))

const TRIO_PAGE := 10   # V1.6.1 D2：題組 20 組，一頁 10 組
var trio_page := 0
func _draw_trio() -> void:
	var ss := Trio.sets()
	var cl: Dictionary = Save.data.get("trio_clear", {})
	var pages := ceili(ss.size() / float(TRIO_PAGE))
	trio_page = clampi(trio_page, 0, pages - 1)
	var rows := ceili(mini(TRIO_PAGE, ss.size()) / 2.0)
	var P := modal_rect(760, 12.0 + h1_help_h(L.t("tr_help"), tz("S"), 680) + GAP_L + rows * 56.0 + GAP_S + tz("C") * 1.3 + GAP_M + 44.0 + GAP_L)
	_panel(P)
	var y := _h1_help(Vector2(640, P.position.y + 12), L.t("trio_open"), L.t("tr_help"), tz("S"), 680)
	if pages > 1:
		# 換頁鈕和返回鈕同一列、左右對稱（R4）；頁數寫在返回鈕上方
		_btn_small(Rect2(560 - GAP_M - 60, P.end.y - GAP_L - 44.0, 60, 44), "◀", func(): trio_page -= 1, trio_page > 0)
		_btn_small(Rect2(720 + GAP_M, P.end.y - GAP_L - 44.0, 60, 44), "▶", func(): trio_page += 1, trio_page < pages - 1)
		_text(Vector2(640, P.end.y - GAP_L - 44.0 - GAP_M - tz("C") * 1.3), L.t("lb_page", [trio_page + 1, pages]), tz("C"), TXT_DIM, true, false, 200)
	for i in range(trio_page * TRIO_PAGE, mini(ss.size(), trio_page * TRIO_PAGE + TRIO_PAGE)):
		var s: Dictionary = ss[i]
		var id := str(s["id"])
		var lbl := L.t("tr_row", [i + 1, int(s["budget"])]) + ("　✓ %dg" % int(cl[id]) if cl.has(id) else "")
		var ii := i
		var br := Rect2(640 - 350 + (i % 2) * 360, y + ((i % TRIO_PAGE) / 2) * 56.0, 340, 48)
		_btn(br, lbl, func(): _trio_start(ii), true, i == 0)
		var tst := int(Save.data.get("trio_stars", {}).get(id, 1 if cl.has(id) else 0))   # V1.6.1 A3：整組星數（舊紀錄只有過關＝1 星）
		for ks in 3:
			_icon("star", Vector2(br.end.x - 50 + ks * 16, br.end.y - 10), 13.0, Color("#ffd166") if ks < tst else Color(1, 1, 1, 0.18))
	_btn(Rect2(560, P.end.y - GAP_L - 44.0, 160, 44), L.t("back"), func(): _nav_back())   # V1.0.0（Codex v100-i1 #8）：和 Esc 同一條返回路徑

func _draw_trio_result() -> void:
	var s: Dictionary = _trio_set()
	var done := trio_res.size() == 3
	var all_ok := done and trio_st >= 1
	var busy_txt: String = L.t("tr_busy") + ("　%d／%d" % [int(trio_ctl.get("done", 0)), int(trio_ctl.get("total", 0))] if trio_busy and BgPool.progress(trio_ctl) >= 0.0 else "")   # 1.1.0 N6：已知上限才顯示
	var foot: String = L.t("tr_timeout") if trio_err else busy_txt if not done else (L.t("tr_pass_st", [Trio.rem_avg(trio_res), Trio.spent_pct(s, trio_res), Trio.s2_of(s), Trio.s3_of(s)]) if all_ok else L.t("tr_fail"))
	var cw := 220.0
	var ch := 196.0
	var P := modal_rect(760, 12.0 + h1_bottom(0.0) + GAP_L + ch + GAP_L + text_h(foot, tz("S"), 680) + GAP_L + 26.0 + GAP_L + 50.0 + GAP_L)
	_panel(P)
	var y := _h1(Vector2(640, P.position.y + 12), L.t("trio_open")) + GAP_L
	var r5: Array = []   # 三張同列卡片（R5 基準線：縮圖、標題）
	for k in 3:
		var r := Rect2(640 - (cw * 3 + 2 * GAP_L) / 2.0 + k * (cw + GAP_L), y, cw, ch)
		var has := k < trio_res.size()
		var kk := k
		_btn(r, "", func(): _trio_watch(kk), has, false)
		_mini_formation(Rect2(r.position + Vector2(cw / 2.0 - 40, 10), Vector2(80, 84)), Trio.make_pz(s, k), true)
		r5.append([Rect2(r.position + Vector2(cw / 2.0 - 40, 10), Vector2(80, 84)), Rect2(r.position + Vector2(8, 102), Vector2(cw - 16, tz("S")))])
		var head := L.t("tr_card", [k + 1])
		_text(Vector2(r.get_center().x, r.position.y + 102), head, tz("S"), Color.WHITE, true, true, cw - 16)
		var st_line := ("—" if trio_err else L.t("tr_calc")) if not has else ((L.t("tr_won", [int(trio_res[k]["rem"])])) if bool(trio_res[k]["ok"]) else L.t("tr_lost"))
		_text(Vector2(r.get_center().x, r.position.y + 102 + tz("S") * 1.5), st_line, tz("S"), (ACCENT if has and bool(trio_res[k]["ok"]) else Color(1, 0.75, 0.7)) if has else TXT_DIM, true, false, cw - 16)
		if has:
			_text(Vector2(r.get_center().x, r.end.y - tz("C") * 1.6), L.t("tr_watch"), tz("C"), TXT_DIM, true, false, cw - 16)
	probe_cards("trio_cards", r5)
	y += ch + GAP_L
	_text(Vector2(640, y), foot, tz("S"), ACCENT if all_ok else Color.WHITE, true, false, 680)
	y += text_h(foot, tz("S"), 680) + GAP_L
	for ks in 3:
		_icon("star", Vector2(640 - 30 + ks * 30, y + 13), 24.0, Color("#ffd166") if ks < trio_st else Color(1, 1, 1, 0.2))
	y += 26.0 + GAP_L
	_btn(Rect2(640 - 230, y, 220, 50), L.t("retry"), func(): overlay = ""; _trio_start_custom(trio_custom) if not trio_custom.is_empty() else _trio_start(trio_i), not trio_busy, true)
	_btn(Rect2(650, y, 220, 50), L.t("back"), func(): _trio_back())

## 1.1.0 H3：結算頁「返回」回到三考題組清單（朋友出的題回標題），不露出底下第一場的結果頁
func _trio_back() -> void:
	var custom := not trio_custom.is_empty()
	_go_title()
	if not custom:
		overlay = "trio"
		_focus = 0

## ── #20 迷霧推演：對 AI（普通）；開戰前斥候回報約三分之一的敵兵（依欄、列排序後每 3 隻露 1 隻，固定不隨機），其他要猜。
## 只動畫面，不動模擬。原本做「前兩排」：AI 多半把兵擺在前兩排，21 隻露 16 隻，等於沒藏（版面截圖看到）。
var fog_on := false
const FOG_EVERY := 3

func _fog_start() -> void:
	rules = null
	difficulty = 1
	set("challenge_army", null)
	_start_mode(Mode.VS_AI)
	fog_on = true
	call("_build_ai")   # 先組好（平常是開戰才組），前排才看得到
	ai_prebuilt = true

static func fog_seen(units: Array) -> Array:
	# V1.6.1 F3：自由座標（每日、自由排兵）也要露：依 x、再依 y 排序後同樣每 3 隻露 1 隻（不是探測半徑，畫面不畫範圍圈）
	var lst: Array = units.filter(func(u): return u.has("col") or u.has("x"))
	lst.sort_custom(func(a, b): return _fog_key(a) < _fog_key(b))
	var out: Array = []
	for i in lst.size():
		if i % FOG_EVERY == 0:
			out.append(lst[i])
	return out

static func _fog_key(u: Dictionary) -> int:
	if u.has("col"):
		return (int(u["col"]) * 1000 + 500) * 100000 + int(u["row"]) * 1000 + 500
	return int(u["x"]) * 100000 + int(u["y"])

func _fog_draw() -> void:
	if not fog_on or state != St.PLACE or mode != Mode.VS_AI or armies.size() < 2 or armies[1] == null:
		return
	var seen := fog_seen(armies[1].units)
	for u in seen:
		var p := ORIGIN + Vector2(int(u["col"]) + 0.5, int(u["row"]) + 0.82) * CS if u.has("col") else _foot_of(Vector2i(int(u["x"]), int(u["y"])))
		# 斥候照亮：腳下一圈暖光＋白黑雙色細框（色盲、高對比也分得出是「看到的」）
		draw_circle(p - Vector2(0, 0.2 * CS), 0.55 * CS, Color(1, 0.92, 0.6, 0.16))
		draw_arc(p - Vector2(0, 0.2 * CS), 0.55 * CS + 1.5, 0, TAU, 32, Color(0, 0, 0, 0.55), 2.5)
		draw_arc(p - Vector2(0, 0.2 * CS), 0.55 * CS, 0, TAU, 32, Color(1, 1, 1, 0.8 if bool(Save.s("colorblind")) else 0.55), 1.2)
		Art.ring(self, p, 1, int(u["type"]), cbm(), 1.0)
		Art.unit(self, p, int(u["type"]), 1, -1.0, 0.0, 0.0, 0.0, 1.0, time, 1.0, cbm())
	var lbl := L.t("fog_scout", [seen.size(), armies[1].units.size()])
	_text(ORIGIN + Vector2(13 * CS, 18), lbl, ts(15), Color(1, 0.9, 0.6), true, true, 5.5 * CS)

## ── #21 雙人接力遠征：同一台電腦，兩人輪流負責一站（奇數站玩家 1、偶數站玩家 2），事件也由剛打完的人選 ──
var ga_coop := false
var coop_seen := 0   # 已經出過交接畫面的站

static func coop_player(stage: int) -> int:
	return ScreenRules.coop_player(stage)   # 1.1.0 A22：純邏輯搬到 scripts/game/screen_rules.gd

func _enter_gauntlet() -> void:
	ga_coop = false
	super._enter_gauntlet()

func _coop_start() -> void:
	if not Save.data.get("gauntlet_run", {}).is_empty():
		_ask_confirm(L.t("coop_replace_q"), func(): _coop_go(), "")
		return
	_coop_go()

func _coop_go() -> void:
	call("_enter_gauntlet_new")
	ga_coop = true
	coop_seen = 0
	coop_log = []

## V1.6.1 D4：每站結束記 [站, 玩家, 勝?, MVP 兵種]；最後一站贏或中途輸了出總結
var coop_log: Array = []
## V1.0.0 M4：單人遠征也記每站（玩家欄＝0），最後一站贏或中途輸了一樣出總結（共用這個頁面）
func _coop_settle() -> void:
	if mode != Mode.GAUNTLET or sim == null or watch_mode:
		return
	if gauntlet_stage <= 1:
		coop_log = []   # 第 1 站＝新的一趟（續局會從存檔的 clog 還原）
	var mvp = report.get("mvp")
	var won: bool = sim.winner == 0
	coop_log.append_array([gauntlet_stage, coop_player(gauntlet_stage) if ga_coop else 0, 1 if won else 0, int(mvp.type) if mvp != null and mvp.team == 0 and not mvp.summon else -1])
	if won and gauntlet_stage >= 7 and ga_coop:
		call("_ach", "COOP_CLEAR")   # V1.6.1 D7
	if not won or gauntlet_stage >= 7:
		overlay = "coop_sum"
		_focus = 0

static func coop_rows(log: Array) -> Array:
	return ScreenRules.coop_rows(log)   # 1.1.0 A22：純邏輯搬到 scripts/game/screen_rules.gd

func _draw_coop_sum() -> void:
	var rows := coop_rows(coop_log)
	var wins := [0, 0]
	var solo := not ga_coop
	for r in rows:
		if bool(r[2]):
			wins[maxi(0, int(r[1]) - 1)] += 1
	var foot := L.t("ga_sum_foot", [wins[0], rows.size()]) if solo else L.t("coop_sum_foot", [wins[0], wins[1]])
	var rowh := maxf(44.0, text_h(L.t("coop_mvp", [L.t("unit_19")]), tz("C"), 200.0) + 12.0)   # MVP 字在英文 150% 會換行：列高照它
	var P := modal_rect(760, 12.0 + h1_bottom(0.0) + GAP_L + rows.size() * rowh + GAP_M + text_h(foot, tz("S"), 640) + GAP_L + 44.0 + GAP_L)
	_panel(P)
	var y := _h1(Vector2(640, P.position.y + 12), L.t("ga_sum") if solo else L.t("coop_sum")) + GAP_L
	for r in rows:
		var wl := L.t("coop_w") if bool(r[2]) else L.t("coop_l")
		var line := L.t("ga_sum_row", [int(r[0]), wl]) if solo else L.t("coop_sum_row", [int(r[0]), int(r[1]), wl])
		_text(Vector2(P.position.x + 40, y + 8), line, tz("S"), Color(0.75, 0.88, 1.0) if int(r[1]) <= 1 else Color(1, 0.8, 0.75), false, true, 380)
		if int(r[3]) >= 0:
			Art.unit(self, Vector2(P.end.x - 250, y + 40), int(r[3]), 0, 1.0, 0.0, 0.0, 0.0, 1.0, time, 0.42, cbm())
			_text(Vector2(P.end.x - 225, y + 8), L.t("coop_mvp", [L.t("unit_%d" % int(r[3]))]), tz("C"), ACCENT, false, false, 200)
		y += rowh
	y += GAP_M
	_text(Vector2(640, y), foot, tz("S"), Color.WHITE, true, false, 640)
	_btn(Rect2(560, P.end.y - GAP_L - 44.0, 160, 44), L.t("back"), func(): overlay = "")

func _coop_tick() -> void:
	if ga_coop and mode == Mode.GAUNTLET and state == St.PLACE and overlay == "" and coop_seen != gauntlet_stage:
		coop_seen = gauntlet_stage
		overlay = "coop_hand"
		_focus = 0

func _draw_coop_hand() -> void:
	var p := coop_player(gauntlet_stage)
	var body := L.t("coop_hand_body", [gauntlet_stage, p])
	var P := modal_rect(560, 12.0 + h1_bottom(0.0) + GAP_L + text_h(body, tz("B"), 480, true) + GAP_XL + 52.0 + GAP_L)
	_panel(P)
	var y := _h1(Vector2(640, P.position.y + 12), L.t("coop_hand", [p])) + GAP_L
	_text(Vector2(640, y), body, tz("B"), Color.WHITE, true, true, 480)
	y += text_h(body, tz("B"), 480, true) + GAP_XL
	_btn(Rect2(640 - 140, y, 280, 52), L.t("coop_ready", [p]), func(): overlay = "", true, true)

func _coop_hud() -> void:
	if ga_coop and mode == Mode.GAUNTLET:
		var s := L.t("coop_turn", [coop_player(gauntlet_stage)])
		var w := _width(s, tz("S"), true) + 24.0
		var r := Rect2(16, 96, w, tz("S") * 1.6)
		_tex_box(r, "wood", Color(0.2, 0.32, 0.5) if coop_player(gauntlet_stage) == 1 else Color(0.45, 0.22, 0.2))
		_text(r.position + Vector2(12, tz("S") * 0.25), s, tz("S"), Color.WHITE, false, true, w)

## ── #22 相鄰陣法：擺陣時把會拿到加成的相鄰組合用粉筆線連起來 ──
const Adj = preload("res://scripts/core/adj_defs.gd")

static func adj_links(units: Array, pos_of: Callable) -> Array:
	var out: Array = []
	for i in units.size():
		for p in Adj.PAIRS:
			if int(units[i]["type"]) != int(p[0]):
				continue
			var a: Vector2i = pos_of.call(units[i])
			for j in units.size():
				if i != j and int(units[j]["type"]) == int(p[1]):
					var b: Vector2i = pos_of.call(units[j])
					if (b - a).length_squared() <= Adj.RANGE * Adj.RANGE:
						out.append([a, b])
	return out

func _adj_draw(a) -> void:
	if rules == null or not rules.adj:
		return
	for l in adj_links(a.units, func(u): return a.pos_of(u)):
		_chalk_line(_foot_of(l[0]) - Vector2(0, 0.3 * CS), _foot_of(l[1]) - Vector2(0, 0.3 * CS), Color(1, 0.85, 0.3, 0.8), 2.5)

## 熟練度外觀小物：3 級起在兵卡上畫星章（3、4 級銀、5 級金），圖鑑也看得到等級
func _mastery_badge(r: Rect2, t: int) -> void:
	var lv := mastery_lv(t)
	if lv < 3:
		return
	_icon("star", r.position + Vector2(r.size.x / 2, 30), 16.0, Color("#ffd166") if lv >= 5 else Color("#d8dde6"))
	# V1.6.1 A1：兵卡外框（3、4 級銀、5 級金；深邊＋亮邊，紙上木上都看得到）
	var fc := Color("#ffd166") if lv >= 5 else Color("#c9d1dc")
	draw_rect(r.grow(-2), Color(0, 0, 0, 0.5), false, 3.0)
	draw_rect(r.grow(-2), fc, false, 1.6)

func mastery_lv(t: int) -> int:
	return Career.level(int(Save.data.get("mastery", {}).get(str(t), 0)))

## 圖鑑大圖腳下的木牌：刻熟練度等級＋戰功章（三顆，拿到的亮）
func codex_plaque(p: Vector2, t: int) -> void:
	if t >= D.total():
		return
	var lv := mastery_lv(t)
	var md := Career.medals_of(Save.data.get("medals", {}), t)
	var txt := L.t("ms_plaque", [lv])
	var w := _width(txt, tz("C"), true) + 20.0 + 3 * 18.0
	var r := Rect2(p.x - w / 2, p.y, w, tz("C") * 1.5 + 6)
	_tex_box(r, "wood", Color("#8a5a2b"))
	_text(r.position + Vector2(10, 3 + tz("C") * 0.1), txt, tz("C"), Color("#fff1d6"), false, true, w)
	for i in 3:
		_icon("star", Vector2(r.end.x - 54 + i * 18 + 9, r.get_center().y), 13.0, Color("#ffd166") if md[i] else Color(0, 0, 0, 0.35))
