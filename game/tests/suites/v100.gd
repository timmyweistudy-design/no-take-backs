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

## M16：docs/codes.md 的前綴表和 code_kind 一致；亂碼不辨識。
func test_code_table_v100() -> void:
	var G = load("res://scripts/ui/screens/game_menus.gd")
	var want := {"NTB1": "army", "NTB5": "army", "NTB6": "army", "NTB2": "battle", "NTB3": "battle", "NTB4": "battle", "NTB7": "battle",
		"NTBR1": "rules", "NTBR6": "rules", "NTC1": "challenge", "NTP1": "workshop", "NTP2": "workshop", "NTP3": "workshop", "NTP4": "workshop",
		"NTS1": "settings", "NTW1": "waves"}
	var bad: Array = []
	for p in want:
		if G.code_kind(p + ".abc.123456") != want[p]:
			bad.append(p)
	ok(bad.is_empty(), "每個前綴都認得", str(bad))
	for junk in ["", "hello", "NTX1.a.b", "ntb1.a.b", "NTB8.a.b"]:
		ok(G.code_kind(junk) == "", "不認得的不辨識：" + junk)
	var md := FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../docs/codes.md"))
	ok(md != "", "讀得到 docs/codes.md")
	if md != "":
		for p in want:
			ok(md.find(p) >= 0, "docs/codes.md 有寫 " + p)
	var WS = load("res://scripts/game/workshop.gd")
	for junk in ["NTP3.%%%.000000", "NTP4." + "A".repeat(7000) + ".x"]:
		ok(not bool(WS.decode(junk)["ok"]), "壞的出題碼不收")

## A2：同一音效同時最多 3 路。
func test_sfx_same_cap_v100() -> void:
	var S = load("res://scripts/game/sfx.gd")
	ok(S.same_playing([true, true, false, true], {0: "hit", 1: "hit", 2: "hit", 3: "boom"}, "hit") == 2, "只數正在播的同名聲道")
	ok(S.SAME_MAX == 3, "上限 3")

## M4：單人遠征的每站紀錄（玩家欄 0）存檔驗得過；接力的規則不變。
func test_solo_clog_v100() -> void:
	var S = load("res://scripts/game/save.gd")
	var run := {"stage": 3, "seed": 1, "gold": 0, "cap": 0, "changes": 3, "pool": 1023, "prev": [], "coop": 0, "clog": [1, 0, 1, 0, 2, 0, 1, 3]}
	ok(S.sanitize_run(run)["clog"] == [1, 0, 1, 0, 2, 0, 1, 3], "單人：玩家欄 0 留下")
	run["clog"] = [1, 1, 1, 0]
	ok(S.sanitize_run(run)["clog"] == [], "單人卻寫玩家 1：丟掉")
	run["coop"] = 1
	ok(S.sanitize_run(run)["clog"] == [1, 1, 1, 0], "接力照舊")

## M18：相鄰陣法四組（含「槍＋騎」「鼓＋狂戰士」這兩組 AI 很少帶的）左右交換後結果鏡像、加成筆數相同。
func test_adj_pairs_mirror_v100() -> void:
	var RSx = load("res://scripts/core/ruleset.gd")
	var Simx = load("res://scripts/core/battle_sim.gd")
	var Armyx = load("res://scripts/core/army.gd")
	var AD = load("res://scripts/core/adj_defs.gd")
	var foe := [[0, 11, 3], [0, 11, 5], [2, 13, 4], [1, 10, 4]]
	for p in AD.PAIRS:
		var mine := [[int(p[0]), 4, 4], [int(p[1]), 4, 5], [0, 5, 3], [2, 2, 4]]
		var r = RSx.standard()
		r.adj = true
		var a = Armyx.new(0, 100)
		var e = Armyx.new(1, 100)
		for u in mine:
			a.place(u[0], u[1], u[2])
		for u in foe:
			e.place(u[0], u[1], u[2])
		var a2 = Armyx.new(0, 100)
		var e2 = Armyx.new(1, 100)
		for u in foe:
			a2.place(u[0], 15 - u[1], u[2])
		for u in mine:
			e2.place(u[0], 15 - u[1], u[2])
		var s1 = Simx.new(a, e, r)
		var s2 = Simx.new(a2, e2, r)
		s1.run_to_end()
		s2.run_to_end()
		var w1: int = s1.winner
		var w2: int = s2.winner
		var mirrored: bool = (w1 == 0 and w2 == 1) or (w1 == 1 and w2 == 0) or (w1 == w2 and w1 != 0 and w1 != 1)
		ok(s1.adj_n == s2.adj_n and s1.adj_n >= 1, "相鄰 %d+%d：兩邊加成筆數相同（%d／%d）" % [p[0], p[1], s1.adj_n, s2.adj_n])
		ok(mirrored and s1.tick == s2.tick, "相鄰 %d+%d：交換左右結果鏡像" % [p[0], p[1]], "%d/%d %d/%d" % [w1, w2, s1.tick, s2.tick])

## D3（Codex v100-i1 #7）：執行中主檔壞了又隔離失敗：不覆蓋壞檔，這次記為未存。
func test_quarantine_fail_keeps_v100() -> void:
	var SV = load("res://scripts/game/save.gd")
	var keep: Dictionary = SV.data.duplicate(true)
	var old_prefix: String = SV.prefix
	SV.prefix = "t100qf_"
	SV.data = SV.DEFAULT_SAVE.duplicate(true)
	ok(SV.save_data(), "先存一次")
	var P := "user://t100qf_save.json"
	_put(P, "壞")
	SV.fail_inject = {"quarantine": 1}
	ok(not SV.save_data(), "隔離失敗：這次不存")
	ok(FileAccess.get_file_as_string(P) == "壞", "壞檔還在（證據沒被蓋掉）")
	SV.fail_inject = {}
	ok(SV.retry_pending(), "之後重試會成功")
	for f in DirAccess.get_files_at("user://"):
		if f.begins_with("t100qf_"):
			DirAccess.remove_absolute("user://" + f)
	SV.prefix = old_prefix
	SV.data = keep
