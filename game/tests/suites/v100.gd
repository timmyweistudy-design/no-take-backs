extends "res://tests/test_base.gd"
## V1.0.0 測試（docs/2026-11-10-v1.0.0-plan.md）。會碰存檔的測試自己換前綴、結束還原。

## D3：20 個編號用完不覆蓋舊證據，主檔要移開。
func test_quarantine_full_v100() -> void:
	var SV = load("res://scripts/game/save.gd")
	var p := "user://t100q_save.json"
	for n in range(1, 21):
		_put("%s.corrupt%d" % [p, n], "old%d" % n)
	_put(p, "壞")
	ok(SV._quarantine(p), "隔離成功")
	ok(not FileAccess.file_exists(p), "主檔移開了")
	ok(FileAccess.get_file_as_string(p + ".corrupt20") == "old20", "第 20 份證據沒被覆蓋")
	var extra := 0
	for f in DirAccess.get_files_at("user://"):
		if f.begins_with("t100q_save.json.corrupt_"):
			extra += 1
	ok(extra == 1, "多出一份時間戳記名的證據", str(extra))
	for f in DirAccess.get_files_at("user://"):
		if f.begins_with("t100q_"):
			DirAccess.remove_absolute("user://" + f)

func _put(path: String, txt: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(txt)
	f.close()

## D4：回報提示照實講。
func test_feedback_honest_v100() -> void:
	var G = load("res://scripts/ui/screens/game_v16.gd")
	ok(G.feedback_key(true, true) == "fb_done", "都成功")
	ok(G.feedback_key(true, false) == "fb_saved_only", "只存檔")
	ok(G.feedback_key(false, true) == "fb_copied_only", "只複製")
	ok(G.feedback_key(false, false) == "fb_fail", "都失敗")
	ok(not G._write_text("user://no_such_dir_t100/x.json", "a"), "寫不進去的路徑回 false")
	var L = load("res://scripts/game/strings.gd")
	for k in ["fb_saved_only", "fb_copied_only", "fb_fail", "tr_timeout", "ws_slow"]:
		ok(L.has(k), "字串 " + k)

## M13：三考背景運算可取消、逾時回空。
func test_trio_cancel_v100() -> void:
	var TR = load("res://scripts/game/v16_trio.gd")
	var s: Dictionary = TR.sets()[0]
	var sol: Array = s["sol"]
	var full: Array = TR.results(s, sol, 1)
	ok(full.size() == 2, "沒給 ctl 照常算兩場")
	ok(TR.results(s, sol, 1, {"stop": true}).is_empty(), "叫停就回空")
	ok(TR.results(s, sol, 1, {"stop": false, "until": 0}).is_empty(), "期限已過就回空")
	var ok2: Array = TR.results(s, sol, 1, {"stop": false, "until": Time.get_ticks_msec() + 600000})
	ok(ok2 == full, "期限夠：結果和不帶 ctl 一樣（位元相同）", str(ok2))

## M15：作者解跑太久不收。
func test_workshop_slow_v100() -> void:
	var PZ = load("res://scripts/game/puzzles.gd")
	var pz: Dictionary = PZ.puzzles()[0]
	ok(not pz.is_empty(), "拿得到一關")
	var sol: Array = pz.get("best", {}).get("u", [])
	var r: Dictionary = PZ.play(pz, sol, [], true, {"stop": true})
	ok(bool(r.get("cancel", false)), "叫停：回 cancel")
	var r2: Dictionary = PZ.play(pz, sol)
	var r3: Dictionary = PZ.play(pz, sol, [], true, {"stop": false, "until": Time.get_ticks_msec() + 600000})
	ok(int(r2["rem"]) == int(r3["rem"]) and bool(r2["ok"]) == bool(r3["ok"]) and int(r2["ticks"]) == int(r3["ticks"]), "逐 tick 看期限不改結果")
	var WS = load("res://scripts/game/workshop.gd")
	ok(WS.SOLVE_MS > 0, "有期限常數")

## R1：殘局「重打」保留上次擺法；換關不帶。
func test_retry_keep_v100() -> void:
	var g = load("res://scripts/ui/game_screens.gd").new()
	g.sfx = FakeSfx.new()
	var PZ = load("res://scripts/game/puzzles.gd")
	var pz: Dictionary = PZ.puzzles()[0]
	g._pick_puzzle(str(pz["id"]), false)
	var n0: int = g.armies[0].units.size()
	var sol: Array = pz.get("best", {}).get("u", [])
	for e in sol:
		g.armies[0].place(int(e[0]), int(e[1]), int(e[2]))
	var n1: int = g.armies[0].units.size()
	ok(n1 > n0, "擺上了解法", "%d %d" % [n0, n1])
	g.last_armies = [g.armies[0].copy(), g.armies[1].copy()]
	g._mark_retry()
	g._start_mode(g.Mode.PUZZLE)
	ok(g.armies[0].units.size() == n1, "重打：擺法還在", str(g.armies[0].units.size()))
	g._start_mode(g.Mode.PUZZLE)
	ok(g.armies[0].units.size() == n0, "再開一次（不是重打）：回到初始")
	g.last_armies = [g.armies[0].copy(), g.armies[1].copy()]
	g._mark_retry()
	g._pick_puzzle(str(PZ.puzzles()[1]["id"]), false)
	ok(g.retry_key == "" and g.retry_units.is_empty(), "換關不帶上一關的擺法")
	g.free()
