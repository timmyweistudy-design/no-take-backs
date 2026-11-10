extends "res://scripts/ui/screens/game_menus.gd"
## V1.6.0 介面層（docs/2026-11-10-v1.6.0-plan.md）：新手下一步、試玩回報、分享、教練、極速賽、裂隙、人設、熟練度、實驗簿、出題台、一陣三考、迷霧、接力遠征。
## 純邏輯放 scripts/game/v16_*.gd（可測），這裡只管畫面與流程。

const Funnel = preload("res://scripts/game/v16_funnel.gd")

## ── #2 真人試玩：所在畫面名稱、回報（存檔＋複製到剪貼簿）、離開時記最後的畫面 ──
func screen_id() -> String:
	if overlay != "":
		return overlay
	return ["title", "place", "battle", "result"][state] + ("" if state == St.TITLE else ":" + ["ai", "duel", "tutorial", "puzzle", "gauntlet"][mode])

func _feedback() -> void:
	var txt := Funnel.report(str(ProjectSettings.get_setting("application/config/version")), screen_id())
	var name := "user://%sreport_%d.json" % [Save.file_prefix(), int(Time.get_unix_time_from_system())]
	var f := FileAccess.open(name, FileAccess.WRITE)
	if f != null:
		f.store_string(txt)
		f.close()
	DisplayServer.clipboard_set(txt)
	_toast(L.t("fb_done"))

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
	_v16_jobs(_delta)

func _v16_jobs(_delta: float) -> void:
	pass

func _open_codex(t: int) -> void:
	Funnel.mark("codex_open")
	super._open_codex(t)

func _finish_battle() -> void:
	super._finish_battle()
	if play_kind != "official" or sim == null:
		return
	Funnel.mark("first_battle")
	if mode != Mode.DUEL:
		var won: bool = sim.winner == 0
		Funnel.mark("first_win" if won else "first_loss")
		if mode == Mode.TUTORIAL and won:
			Funnel.mark("tutorial_done")
		if mode == Mode.PUZZLE and (won or bool(report.get("goal_ok", false))):
			Funnel.mark("puzzle_clear")
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
		"gauntlet":
			return func(): _enter_gauntlet()
		"playroom":
			return func(): overlay = "playroom"; _focus = 0
		"trials":
			return func(): _open("trials")
	return func(): pass

func _draw_next_step() -> void:
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
	_text(NS_RECT.position + Vector2(56, 6 + tz("C") * 1.25), L.t("ns_" + k), tz("S"), Color.WHITE, false, true, NS_RECT.size.x - 70)

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

func _draw_v16_overlay(name: String) -> void:
	match name:
		"demo_end":
			_draw_demo_end()
		"share":
			_draw_share()

## ── #6 戰術可視化：擺陣時「射程覆蓋」（V 鍵或資訊帶按鈕），「標記」最多 3 隻（T 鍵或按鈕後點兵），觀戰時追蹤 ──
var tv_range := false
var tv_mark_mode := false
var tv_marks: Array = []      # 標記的兵：世界座標（Vector2i，開戰時對到模擬的兵）
var tv_ids: Array = []        # 這一場對到的模擬 id（順序＝標記號碼）
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

func _v16_place_key(k: int) -> bool:
	match k:
		KEY_V:
			tv_range = not tv_range
			return true
		KEY_T:
			if tv_toggle_at(_cur_army(), _tv_world_at(_fp_scr(Vector2i(fp_cur)) if pad_mode else mouse)):
				sfx.play("k_click", 0.7)
			return true
	return false

## 資訊帶右邊（「?」左邊）兩顆小鈕
func _tv_buttons(help: Rect2) -> void:
	var b1 := Rect2(help.position.x - 88, help.position.y, 40, 36)
	var b2 := Rect2(help.position.x - 44, help.position.y, 40, 36)
	_btn(b1, "", func(): tv_range = not tv_range, true, false, TH_ACTIVE if tv_range else Color(0, 0, 0, 0))
	_icon("range", b1.get_center(), 22.0, Color.WHITE)
	_btn(b2, "", func(): tv_mark_mode = not tv_mark_mode, true, false, TH_ACTIVE if tv_mark_mode else Color(0, 0, 0, 0))
	_icon("flag", b2.get_center(), 22.0, Color.WHITE)
	if b1.has_point(mouse) or b2.has_point(mouse):
		var tip := L.t("tv_range_tip") if b1.has_point(mouse) else L.t("tv_mark_tip")
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
				var best: Vector2i = foes[0]
				var bd := INF
				for f in foes:
					var d := Vector2(f - p).length()
					if d < bd:
						bd = d
						best = f
				var dir := Vector2(best - p).normalized()
				_chalk_arrow(sp, sp + dir * 0.7 * CS)
	_tv_draw_marks_place(a)

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
	tv_ids = []
	if sim == null or tv_marks.is_empty():
		return
	for m in tv_marks:
		for u in sim.units:
			if u.team == 0 and u.x == m.x and u.y == m.y:
				tv_ids.append(u.id)
				break

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

## ── #7 操作與無障礙：按住確認、文字放大鏡、軍令點選放置 ──
var hold_t := 0.0
var confirm_ok_r := Rect2()
const HOLD_SEC := 0.6

func _hold_tick(delta: float) -> void:
	if overlay != "confirm" or not bool(Save.s("hold_confirm")):
		hold_t = 0.0
		return
	var down: bool = (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and confirm_ok_r.has_point(mouse)) \
		or (_focus == 0 and (Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_SPACE) or Input.is_joy_button_pressed(0, JOY_BUTTON_A)))
	hold_t = hold_t + delta if down else 0.0
	if hold_t >= HOLD_SEC:
		hold_t = 0.0
		call("_confirm_go")

## 放大鏡：游標指到的介面字，在游標旁邊放大 1.8 倍畫一份（不改版面）
func _draw_magnifier() -> void:
	if mag_hit.is_empty():
		return
	var s: String = mag_hit[0]
	var sz := mini(44, int(int(mag_hit[1]) * 1.8))
	var w := minf(_width(s, sz, bool(mag_hit[2])), 1180.0) + 28.0
	var h := sz * 1.5
	var at := Vector2(clampf(mouse.x - w / 2, 8, 1272 - w), mouse.y + 28 if mouse.y < 600 else mouse.y - 28 - h)
	draw_rect(Rect2(at, Vector2(w, h)), Color(0.04, 0.05, 0.08, 0.96))
	draw_rect(Rect2(at, Vector2(w, h)), ACCENT, false, 2.0)
	var keep := mag_on
	mag_on = false
	_text(at + Vector2(14, sz * 0.2), s, sz, Color.WHITE, false, bool(mag_hit[2]), 1180.0)
	mag_on = keep

## ── #5 社群分享包＋B25 結果頁收合：明信片、出題碼、分享格、精華時刻收進一個「分享」面板 ──
const Share = preload("res://scripts/game/v16_share.gd")
var sh_text := ""   # 這一場的分享格（每日或每週才有）

func _share_ready() -> bool:
	return play_kind == "official" and not watch_mode and sim != null

## 每日挑戰贏了：更新連續天數、產生分享格
func _daily_finish(w: int) -> void:
	super._daily_finish(w)
	sh_text = ""
	if (daily_spec as Dictionary).is_empty() or w != 0:
		return
	var day := int(Daily.today())
	var st: Dictionary = Share.streak_after(Save.data.get("daily_streak", {}), day)
	Save.data["daily_streak"] = st
	Save.save_data()
	var rem: int = PZ.rem_pct(sim.power(0), sim.budget_of(0))
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
	draw_rect(Rect2(0, 0, 1280, 800), Color(0, 0, 0, 0.6))
	var hl := _highlights()
	var rows := 1 + (1 if bool(call("_ws_ok", sim.winner if sim != null else -1)) else 0) + (1 if sh_text != "" else 0)
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
	if pc_shot != null:
		_btn(Rect2(400, y, 480, 48), L.t("pc_btn"), func(): overlay = "postcard", true, true)
		y += 56.0
	if bool(call("_ws_ok", sim.winner)):
		_btn(Rect2(400, y, 480, 48), L.t("ws_make"), func(): overlay = ""; call("_make_workshop"))
		y += 56.0
	if sh_text != "":
		_btn(Rect2(400, y, 480, 48), L.t("sh_copy"), func(): DisplayServer.clipboard_set(sh_text); _toast(L.t("sh_copied")))
		y += 56.0
	_btn(Rect2(560, P.end.y - GAP_L - 44.0, 160, 44), L.t("back"), func(): overlay = "")

func _ghost_settle(w: int) -> void:
	sh_text = ""
	super._ghost_settle(w)
	if bool(get("wk_active")):
		var rec: Dictionary = Save.data.get("weekly", {})
		sh_text = Share.weekly_text(L, int(rec.get("wk", 0)), w == 0, last_armies[0].spent() if last_armies.size() > 0 else 0, int(rec.get("best", 0)), int(rec.get("tries", 0)))
