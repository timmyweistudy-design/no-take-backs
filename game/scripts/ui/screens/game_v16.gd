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
