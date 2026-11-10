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
	_rush_tick(_delta)
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
	_rift_settle()
	_persona_result()
	_career_settle()
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
		"rush_end":
			_draw_rush_end()
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
		KEY_N:
			if mode == Mode.PUZZLE:
				overlay = "notebook"
				_focus = 0
				return true
			return false
		KEY_T:
			if tv_toggle_at(_cur_army(), _tv_world_at(_fp_scr(Vector2i(fp_cur)) if pad_mode else mouse)):
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
	_fog_draw()

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
	if bool(rush.get("on", false)) and kind == "official":
		call("_on_skip")   # 極速賽：不看戰鬥，直接算結果
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
	var kp := layout_probe
	mag_on = false
	layout_probe = false   # 放大的那一份是暫時的疊圖，不算版面
	_text(at + Vector2(14, sz * 0.2), s, sz, Color.WHITE, false, bool(mag_hit[2]), 1180.0)
	mag_on = keep
	layout_probe = kp

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
	# #13 每日全球榜：贏了就準備上傳（有 Steam 才真的送；沒送成功留著，下次開每日時補送）
	var det: PackedInt32Array = SteamApi.pack_free(last_armies[0].units, 16000)
	if not det.is_empty():
		var prev: Dictionary = Save.data.get("daily_pend", {})
		var sc := SteamApi.daily_score(rem, armies[0].spent())
		if int(prev.get("day", -1)) != day or sc > int(prev.get("score", 0)):
			Save.data["daily_pend"] = {"day": day, "score": sc, "det": Array(det)}
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
	draw_rect(Rect2(0, 0, 1280, 800), Color(0, 0, 0, 0.6))
	var hl := _highlights()
	var rows := 1 + (1 if not (daily_spec as Dictionary).is_empty() else 0) + (1 if pc_shot != null else 0) + (1 if bool(call("_ws_ok", sim.winner if sim != null else -1)) else 0) + (1 if sh_text != "" else 0)
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
const Rush = preload("res://scripts/game/v16_rush.gd")
var rush := {}   # {"on", "left", "ids", "i", "solved", "tried"}

func _rush_start() -> void:
	var sd := int(Time.get_unix_time_from_system())
	rush = {"on": true, "left": Rush.START_SEC, "ids": Rush.pool(sd), "i": 0, "solved": 0, "tried": 0}
	_rush_load()

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
	if bool(rush.get("on", false)):
		var s := L.t("rush_hud", [ceili(maxf(0.0, float(rush["left"]))), int(rush["solved"])])
		var w := _width(s, tz("B"), true) + 32.0
		var r := Rect2(640 - w / 2, 96, w, tz("B") * 1.6)
		_tex_box(r, "wood", Color("#7a2a18") if float(rush["left"]) < 20.0 else Color(0.35, 0.24, 0.12))
		_text(Vector2(640, r.position.y + tz("B") * 0.25), s, tz("B"), Color.WHITE, true, true, w)

func _draw_rush_end() -> void:
	var body := L.t("rush_end_body", [int(rush.get("solved", 0)), int(rush.get("tried", 0)), int(Save.data.get("rush_best", 0))])
	var P := modal_rect(560, 12.0 + h1_bottom(0.0) + GAP_L + text_h(body, tz("B"), 480, true) + GAP_XL + 50.0 + GAP_L)
	_panel(P)
	var y := _h1(Vector2(640, P.position.y + 12), L.t("rush_title")) + GAP_L
	_text(Vector2(640, y), body, tz("B"), ACCENT if bool(rush.get("new_best", false)) else Color.WHITE, true, true, 480)
	y += text_h(body, tz("B"), 480, true) + GAP_XL
	_btn(Rect2(640 - 230, y, 220, 50), L.t("rush_again"), func(): overlay = ""; _rush_start(), true, true)
	_btn(Rect2(650, y, 220, 50), L.t("back"), func(): overlay = "")

## ── #9 差一子教練 ──
const Coach = preload("res://scripts/game/v16_coach.gd")
var co_thread: Thread = null
var co_res := {}       # 搜尋結果
var co_layer := 0      # 0 還沒看、1 哪一隻、2 往哪、3 直接擺
var co_key := ""       # 這一場的識別（換場就重算）

func _coach_pz() -> Dictionary:
	return PZ.get_puzzle(puzzle_id) if mode == Mode.PUZZLE else {}

func coach_ok() -> bool:
	if play_kind != "official" or watch_mode or sim == null or sim.winner == 0 or last_armies.size() != 2:
		return false
	if bool(rush.get("on", false)) or not (mode == Mode.PUZZLE or mode == Mode.VS_AI):
		return false
	if mode == Mode.PUZZLE and bool(report.get("goal_ok", false)):
		return false
	return Coach.supported(last_armies[0], battle_rules, _coach_pz())

func _coach_open() -> void:
	var key := "%d:%s:%d" % [mode, puzzle_id, last_armies[0].units.hash()]
	if key != co_key:
		co_key = key
		co_res = {}
		co_layer = 0
		var a0 = last_armies[0].copy()
		var a1 = last_armies[1].copy()
		var rr = battle_rules.copy() if battle_rules != null else null
		var pz := _coach_pz()
		if DisplayServer.get_name() == "headless" or shot_dir != "":
			co_res = Coach.search(a0, a1, rr, pz)
		else:
			co_thread = Thread.new()
			co_thread.start(func(): return Coach.search(a0, a1, rr, pz))
	overlay = "coach"
	_focus = 0

func _v16_jobs(_delta: float) -> void:
	if co_thread != null and not co_thread.is_alive():
		co_res = co_thread.wait_to_finish()
		co_thread = null

func _coach_apply() -> void:
	if not bool(co_res.get("found", false)):
		return
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
	if t.x > f.x:
		return L.t("co_fwd")
	if t.x < f.x:
		return L.t("co_back")
	return L.t("co_up") if t.y < f.y else L.t("co_down")

func _draw_coach() -> void:
	var busy := co_thread != null
	var found: bool = bool(co_res.get("found", false))
	var lines: Array = []
	if busy:
		lines.append(L.t("co_busy"))
	elif not found:
		lines.append(L.t("co_none", [int(co_res.get("tries", 0))]))
	else:
		var tn := L.t("unit_%d" % int(co_res["type"]))
		lines.append(L.t("co_l1", [tn]))
		if co_layer >= 2:
			lines.append(L.t("co_l2", [_dir_name(co_res["from"], co_res["to"])]))
	var body := "\n".join(lines)
	var P := modal_rect(620, 12.0 + h1_help_h(L.t("co_help"), tz("S"), 540) + GAP_L + text_h(body, tz("B"), 540) + GAP_XL + 50.0 + GAP_M + 44.0 + GAP_L)
	_panel(P)
	var y := _h1_help(Vector2(640, P.position.y + 12), L.t("co_title"), L.t("co_help"), tz("S"), 540)
	_text(Vector2(640, y), body, tz("B"), Color.WHITE, true, true, 540)
	y += text_h(body, tz("B"), 540) + GAP_XL
	if found and co_layer < 2:
		_btn(Rect2(640 - 160, y, 320, 50), L.t("co_more"), func(): co_layer = 2, true, true)
	elif found:
		_btn(Rect2(640 - 160, y, 320, 50), L.t("co_apply") if mode == Mode.PUZZLE else L.t("co_review"), func(): _coach_apply(), true, true)
	_btn(Rect2(560, P.end.y - GAP_L - 44.0, 160, 44), L.t("back"), func(): overlay = "")
	if found and co_layer < 1:
		co_layer = 1

## ── #10 裂隙模式 ──
const Rift = preload("res://scripts/game/v16_rift.gd")
var rift_on := false

func _rift_picks() -> Array:
	return Rift.picks(Rift.week(), RS.mask(_demo()))

func _rift_start() -> void:
	var wk := Rift.week()
	var r = Rift.make_rules(_rift_picks(), RS.mask(_demo()), wk)
	rules = r
	set("challenge_army", Rift.enemy(r, wk))
	_start_mode(Mode.VS_AI)
	rift_on = true

func _rift_settle() -> void:
	if not rift_on or sim == null or sim.winner != 0:
		return
	var best: Dictionary = Save.data.get("rift_best", {})
	var k := Rift.key(Rift.week())
	var rec := [PZ.rem_pct(sim.power(0), sim.budget_of(0)), armies[0].spent()]
	if Daily.better(rec, best.get(k, [])):
		best = {k: rec}   # 只留這一週
		Save.data["rift_best"] = best
		Save.save_data()
		_toast(L.t("rf_new", [int(rec[0])]))

func _draw_rift() -> void:
	var ps := _rift_picks()
	var lines: Array = []
	for k in ps:
		lines.append("・" + L.t(str(Rift.ANOMS[k][0])))
	var body := "\n".join(lines)
	var b: Array = Save.data.get("rift_best", {}).get(Rift.key(Rift.week()), [])
	var best := L.t("rf_best", [int(b[0]), int(b[1])]) if not b.is_empty() else L.t("rf_best_none")
	var P := modal_rect(680, 12.0 + h1_help_h(L.t("rf_help"), tz("S"), 600) + GAP_L + text_h(body, tz("B"), 560) + GAP_M + tz("S") * 1.6 + GAP_XL + 52.0 + GAP_M + 44.0 + GAP_L)
	_panel(P)
	var y := _h1_help(Vector2(640, P.position.y + 12), L.t("rift_open"), L.t("rf_help"), tz("S"), 600)
	_text(Vector2(360, y), body, tz("B"), Color.WHITE, false, true, 560)
	y += text_h(body, tz("B"), 560) + GAP_M
	_text(Vector2(640, y), best, tz("S"), ACCENT, true, false, 560)
	y += tz("S") * 1.6 + GAP_XL
	_btn(Rect2(640 - 160, y, 320, 52), L.t("rf_go"), func(): overlay = ""; _rift_start(), true, true)
	_btn(Rect2(560, P.end.y - GAP_L - 44.0, 160, 44), L.t("back"), func(): overlay = "")

func _start_mode(m: int) -> void:
	var keep_rift: bool = rift_on and m == Mode.VS_AI and rules != null and rules.preset == "custom"   # 裂隙「再來一局」照舊
	fog_on = false
	var keep_trio: bool = trio_on and m == Mode.PUZZLE and puzzle_id == "ws" and PZ.get_puzzle("ws").has("trio")   # 一陣三考「重試」照舊
	rift_on = false
	trio_on = false
	super._start_mode(m)
	rift_on = keep_rift
	trio_on = keep_trio

## ── #11 AI 對手人設 ──
const Persona = preload("res://scripts/game/v16_persona.gd")

func _ai_style() -> int:
	return int(rules.ai_style) if rules != null else 0

## 擺陣時敵方屏風上：頭像＋名號＋開場白（不洩漏陣型）
func _persona_fog(c: Vector2, w: float) -> void:
	if bool(get("ghost_id") != "") or bool(get("wk_active")) or rift_on:
		return
	var st := _ai_style()
	Art.unit(self, c + Vector2(0, 46), Persona.face(st), 1, -1.0, 0.0, 0.0, 0.0, 1.0, time, 1.0, cbm())
	_text(c + Vector2(0, 56), L.t("ps_name_%d" % st), ts(16), Color.WHITE, true, true, w)
	var q := "「" + L.t(Persona.line_key(st, "open")) + "」" if L.lang.begins_with("zh") or L.lang == "ja" else "\"" + L.t(Persona.line_key(st, "open")) + "\""
	_text(c + Vector2(0, 56 + ts(16) * 1.4), q, ts(15), Color(1, 0.9, 0.7, 0.9), true, false, w)

func _persona_result() -> void:
	if mode != Mode.VS_AI or sim == null or sim.winner < 0 or not (get("daily_spec") as Dictionary).is_empty() or rift_on or str(get("ghost_id")) != "" or bool(get("wk_active")) or watch_mode:
		return
	if str(report.get("gh_line", "")) != "":
		return
	var st := _ai_style()
	report["gh_line"] = L.t("ps_say", [L.t("ps_name_%d" % st), L.t(Persona.line_key(st, "lose" if sim.winner == 0 else "win"))])

## ── #12 生涯：熟練度＋實驗簿 ──
const Career = preload("res://scripts/game/v16_career.gd")

func _career_settle() -> void:
	if sim == null or mode == Mode.DUEL or watch_mode:
		return
	if rules != null and Presets.badge(rules, "ai") == Presets.BADGE_LAB:
		return
	var m: Dictionary = Save.data.get("mastery", {})
	var ups := Career.add(m, Career.gain(sim.units))
	Save.data["mastery"] = m
	if not ups.is_empty():
		var t: int = ups[0]
		_toast(L.t("ms_up", [L.t("unit_%d" % t), Career.level(int(m[str(t)]))]))
	if mode == Mode.PUZZLE and last_armies.size() == 2:
		var nb: Dictionary = Save.data.get("notebook", {})
		Career.nb_result(nb, puzzle_id, Career.units_of(last_armies[0]), int(report.get("stars", 0)), PZ.rem_pct(sim.power(0), sim.budget_of(0)) if sim.winner == 0 else 0, last_armies[0].spent())
		Save.data["notebook"] = nb

func mastery_line(t: int) -> String:
	var xp := int(Save.data.get("mastery", {}).get(str(t), 0))
	var nx := Career.next_at(xp)
	return L.t("ms_line", [Career.level(xp), xp, nx]) if nx > 0 else L.t("ms_max", [Career.level(xp)])

func _draw_notebook() -> void:
	var lst: Array = Save.data.get("notebook", {}).get(puzzle_id, [])
	var rows := maxi(1, lst.size())
	var P := modal_rect(760, 12.0 + h1_help_h(L.t("nb_help"), tz("S"), 680) + GAP_L + rows * 56.0 + GAP_L + 48.0 + GAP_M + 44.0 + GAP_L)
	_panel(P)
	var y := _h1_help(Vector2(640, P.position.y + 12), L.t("nb_title"), L.t("nb_help"), tz("S"), 680)
	if lst.is_empty():
		_text(Vector2(640, y + 12), L.t("nb_empty"), tz("S"), TXT_DIM, true, false, 680)
	for i in lst.size():
		var e: Dictionary = lst[i]
		var r: Array = e["r"]
		var res := L.t("nb_res", [int(r[0]), int(r[1]), int(r[2])]) if not r.is_empty() else L.t("nb_untried")
		_text(Vector2(P.position.x + 40, y + 10), "%s　%s" % [str(e["n"]), res], tz("S"), Color.WHITE, false, true, 420)
		var ii := i
		_btn_small(Rect2(P.end.x - 250, y + 4, 110, 40), L.t("nb_load"), func(): _nb_load(ii))
		_btn_small(Rect2(P.end.x - 130, y + 4, 90, 40), L.t("nb_del"), func(): _nb_del(ii))
		y += 56.0
	y += GAP_L
	_btn(Rect2(640 - 160, y, 320, 48), L.t("nb_save"), func(): _nb_save(), lst.size() < Career.NB_MAX, true)
	_btn(Rect2(560, P.end.y - GAP_L - 44.0, 160, 44), L.t("back"), func(): overlay = "")

func _nb_save() -> void:
	var nb: Dictionary = Save.data.get("notebook", {})
	var n := (nb.get(puzzle_id, []) as Array).size() + 1
	if Career.nb_save(nb, puzzle_id, L.t("nb_name", [n]), Career.units_of(armies[0])):
		Save.data["notebook"] = nb
		Save.save_data()
		_toast(L.t("nb_saved"))
	else:
		_toast(L.t("nb_dup"), true)

func _nb_load(i: int) -> void:
	var e: Dictionary = Save.data.get("notebook", {}).get(puzzle_id, [])[i]
	armies[0] = PZ.player_army(PZ.get_puzzle(puzzle_id))
	var pz := PZ.get_puzzle(puzzle_id)
	for u in e["u"]:
		if not PZ.is_fixed(pz, int(u[1]), int(u[2])):
			armies[0].place(int(u[0]), int(u[1]), int(u[2]))
	overlay = ""

func _nb_del(i: int) -> void:
	var nb: Dictionary = Save.data.get("notebook", {})
	var lst: Array = nb.get(puzzle_id, [])
	if i < lst.size():
		lst.remove_at(i)
		nb[puzzle_id] = lst
		Save.data["notebook"] = nb
		Save.save_data()

## ── #13 每日全球榜＋挑戰高手陣 ──
var dt_list: Array = []
var dt_state := ""   # ""、"loading"、"done"、"off"

func _daily_sync() -> void:
	var p: Dictionary = Save.data.get("daily_pend", {})
	if not p.is_empty() and SteamApi.available():
		SteamApi.daily_upload(int(p["day"]), int(p["score"]), PackedInt32Array(p.get("det", [])))

func _daily_top_open() -> void:
	overlay = "daily_top"
	_focus = 0
	dt_list = []
	if not SteamApi.available():
		dt_state = "off"
		return
	dt_state = "loading"
	SteamApi.daily_fetch(int(Daily.today()), func(lst: Array):
		dt_list = lst.slice(0, 5)
		dt_state = "done")

func _daily_top_go(units: Array) -> void:
	var sp: Dictionary = Daily.spec(Daily.today())
	var r = Daily.make_rules(sp, RS.mask(false))
	var e = Army.new(1, r.budget_of(1))
	e.apply_rules(r, 1)
	e.units = units.duplicate(true)
	rules = r
	set("challenge_army", e)
	overlay = ""
	_start_mode(Mode.VS_AI)   # 不設 daily_spec：打高手陣不算今天的每日成績

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
const ED_CS := 36.0

func _ed_rect() -> Rect2:
	return Rect2(640 - 8 * ED_CS, 150, 16 * ED_CS, 9 * ED_CS)

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
	if ed_cells.get(c, -1) == ed_type:
		ed_cells.erase(c)
	else:
		ed_cells[c] = ed_type
	ed_msg = ""

func _ed_make() -> void:
	var l := ed_lists()
	var code := WS3.encode3(l[0], l[1], WS3.GOALS3[ed_goal])
	if code == "":
		ed_msg = L.t("ed_fail")
		return
	DisplayServer.clipboard_set(code)
	ed_msg = L.t("ed_ok")
	_toast(L.t("ws_copied"))

func _draw_editor() -> void:
	draw_rect(Rect2(0, 0, 1280, 800), Color(0, 0, 0, 0.7))
	var P := Rect2(80, 40, 1120, 720)
	_panel(P)
	var y := _h1_help(Vector2(640, P.position.y + 8), L.t("ed_title"), L.t("ed_help"), tz("S"), 1000)
	var G := _ed_rect()
	G.position.y = y
	draw_rect(G, Color(0.42, 0.5, 0.28))
	for cx in 16:
		for cy in 9:
			var r := Rect2(G.position + Vector2(cx, cy) * ED_CS, Vector2(ED_CS, ED_CS))
			if cx > 5 and cx < 10:
				draw_rect(r, Color(0, 0, 0, 0.35))
			draw_rect(r, Color(0, 0, 0, 0.2), false, 1.0)
			var k := Vector2i(cx, cy)
			if ed_cells.has(k):
				Art.unit(self, r.position + Vector2(ED_CS / 2, ED_CS * 0.82), int(ed_cells[k]), 0 if cx <= 5 else 1, 1.0 if cx <= 5 else -1.0, 0.0, 0.0, 0.0, 1.0, time, 0.42, cbm())
			if cx <= 5 or cx >= 10:
				_btns.append({"r": r, "cb": func(): ed_toggle(k), "en": true})
	_text(G.position + Vector2(3 * ED_CS, -tz("C") * 1.4), L.t("ed_you"), tz("C"), Color("#9fd0ff"), true, true, 6 * ED_CS)
	_text(G.position + Vector2(13 * ED_CS, -tz("C") * 1.4), L.t("ed_foe"), tz("C"), Color("#ffb0a0"), true, true, 6 * ED_CS)
	y = G.end.y + GAP_M
	# 兵種調色盤（20 種，兩排）
	for t in 20:
		var pr := Rect2(640 - 10 * 50.0 + (t % 10) * 100.0 + 4, y + (t / 10) * 52.0, 92, 48)
		_btn(pr, "", func(): ed_type = t, true, false, TH_ACTIVE if ed_type == t else Color(0, 0, 0, 0))
		Art.unit(self, pr.position + Vector2(24, 44), t, 0, 1.0, 0.0, 0.0, 0.0, 1.0, time, 0.42, cbm())
		_text(pr.position + Vector2(46, 14), "%dg" % D.cost(t), tz("C"), Color.WHITE, false, true, 44)
	y += 2 * 52.0 + GAP_S
	var l := ed_lists()
	var gold := [0, 0]
	for i in 2:
		for u in l[i]:
			gold[i] += D.cost(int(u[0]))
	var info := L.t("ed_info", [l[1].size(), gold[1], l[0].size(), gold[0]])
	_text(Vector2(640, y), info, tz("S"), Color.WHITE, true, false, 1000)
	y += tz("S") * 1.6
	_btn(Rect2(P.position.x + 60, y, 360, 48), L.t("ed_goal", [L.t("ed_g_" + WS3.GOALS3[ed_goal])]), func(): ed_goal = (ed_goal + 1) % WS3.GOALS3.size(); ed_msg = "")
	_btn(Rect2(P.position.x + 440, y, 300, 48), L.t("ed_make"), func(): _ed_make(), not l[0].is_empty() and not l[1].is_empty(), true)
	_btn(Rect2(P.position.x + 760, y, 140, 48), L.t("clear"), func(): ed_cells = {}; ed_msg = "")
	_btn(Rect2(P.position.x + 920, y, 140, 48), L.t("back"), func(): overlay = "")
	if ed_msg != "":
		_text(Vector2(640, y + 56), ed_msg, tz("S"), ACCENT, true, true, 1000)

## ── #17 一陣三考 ──
const Trio = preload("res://scripts/game/v16_trio.gd")
var trio_on := false
var trio_i := 0
var trio_res: Array = []

func _trio_start(i: int) -> void:
	trio_i = i
	PZ.set_custom(Trio.make_pz(Trio.sets()[i], 0))
	puzzle_id = "ws"
	overlay = ""
	_start_mode(Mode.PUZZLE)
	trio_on = true

func _trio_settle() -> void:
	var extra: Array = []
	for u in last_armies[0].units:
		extra.append([int(u["type"]), int(u["col"]), int(u["row"])])
	trio_res = Trio.check(Trio.sets()[trio_i], extra)
	if not false in trio_res:
		var cl: Dictionary = Save.data.get("trio_clear", {})
		var id := str(Trio.sets()[trio_i]["id"])
		var sp: int = last_armies[0].spent()
		if not cl.has(id) or sp < int(cl[id]):
			cl[id] = sp
			Save.data["trio_clear"] = cl
			Save.save_data()
	overlay = "trio_result"
	_focus = 0

func _draw_trio() -> void:
	var ss := Trio.sets()
	var cl: Dictionary = Save.data.get("trio_clear", {})
	var rows := ceili(ss.size() / 2.0)
	var P := modal_rect(760, 12.0 + h1_help_h(L.t("tr_help"), tz("S"), 680) + GAP_L + rows * 56.0 + GAP_L + 44.0 + GAP_L)
	_panel(P)
	var y := _h1_help(Vector2(640, P.position.y + 12), L.t("trio_open"), L.t("tr_help"), tz("S"), 680)
	for i in ss.size():
		var s: Dictionary = ss[i]
		var id := str(s["id"])
		var lbl := L.t("tr_row", [i + 1, int(s["budget"])]) + ("　✓ %dg" % int(cl[id]) if cl.has(id) else "")
		var ii := i
		_btn(Rect2(640 - 350 + (i % 2) * 360, y + (i / 2) * 56.0, 340, 48), lbl, func(): _trio_start(ii), true, i == 0)
	_btn(Rect2(560, P.end.y - GAP_L - 44.0, 160, 44), L.t("back"), func(): overlay = "")

func _draw_trio_result() -> void:
	var lines: Array = []
	for k in trio_res.size():
		lines.append(L.t("tr_line", [k + 1, "✓" if trio_res[k] else "×"]))
	var all_ok := not false in trio_res
	var body := "\n".join(lines) + "\n" + (L.t("tr_pass") if all_ok else L.t("tr_fail"))
	var P := modal_rect(560, 12.0 + h1_bottom(0.0) + GAP_L + text_h(body, tz("B"), 480, true) + GAP_XL + 50.0 + GAP_L)
	_panel(P)
	var y := _h1(Vector2(640, P.position.y + 12), L.t("trio_open")) + GAP_L
	_text(Vector2(640, y), body, tz("B"), ACCENT if all_ok else Color.WHITE, true, true, 480)
	y += text_h(body, tz("B"), 480, true) + GAP_XL
	_btn(Rect2(640 - 230, y, 220, 50), L.t("retry"), func(): overlay = ""; _trio_start(trio_i), true, true)
	_btn(Rect2(650, y, 220, 50), L.t("back"), func(): overlay = "")

## ── #20 迷霧推演：對 AI（普通）；開戰前斥候看得到敵方前兩排（10、11 欄），後排要猜。只動畫面，不動模擬 ──
var fog_on := false
const FOG_COLS := 2

func _fog_start() -> void:
	rules = null
	difficulty = 1
	set("challenge_army", null)
	_start_mode(Mode.VS_AI)
	fog_on = true
	call("_build_ai")   # 先組好（平常是開戰才組），前排才看得到
	ai_prebuilt = true

static func fog_seen(units: Array) -> Array:
	return units.filter(func(u): return u.has("col") and int(u["col"]) < 10 + FOG_COLS)

func _fog_draw() -> void:
	if not fog_on or state != St.PLACE or mode != Mode.VS_AI or armies.size() < 2 or armies[1] == null:
		return
	for u in fog_seen(armies[1].units):
		var p := ORIGIN + Vector2(int(u["col"]) + 0.5, int(u["row"]) + 0.82) * CS
		Art.ring(self, p, 1, int(u["type"]), cbm(), 1.0)
		Art.unit(self, p, int(u["type"]), 1, -1.0, 0.0, 0.0, 0.0, 1.0, time, 1.0, cbm())
	var lbl := L.t("fog_scout", [fog_seen(armies[1].units).size(), armies[1].units.size()])
	_text(ORIGIN + Vector2(13 * CS, 18), lbl, ts(15), Color(1, 0.9, 0.6), true, true, 5.5 * CS)
