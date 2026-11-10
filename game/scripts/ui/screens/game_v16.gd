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

const NS_RECT := Rect2(800, 676, 420, 56)
func _draw_next_step() -> void:
	if Save.s("hints") == "off" or overlay != "":
		return
	var k := Guide.next_step(Save.data, _daily_done_today(), _demo())
	if k == "":
		return
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
