extends "res://tests/test_base.gd"
## 1.1.0 A4：功能測試組「reports_platform」：回報、漏斗、Steam 平台與成就、存檔隔離與清理、試玩紀錄。
## 從原本依版本分的 v16、v161、v100 搬來，函式名不變（名字尾的 _v160／_v161／_v100／_v110 是做的版本）。會碰存檔的測試自己換前綴、結束還原。

func test_funnel_v160() -> void:
	var SV = load("res://scripts/game/save.gd")
	var FN = load("res://scripts/game/funnel.gd")
	var old: Dictionary = SV.data.duplicate(true)
	SV.data.erase("funnel")
	ok(FN.mark("boot", 1000), "第一次記里程碑")
	ok(not FN.mark("boot", 2000), "同一個里程碑只記第一次")
	FN.mark("first_battle", 1000 + 300)
	FN.mark("tutorial_done", 1000 + 120)
	var st: Array = FN.steps()
	ok(st.size() == 3 and st[1]["step"] == "tutorial_done" and int(st[1]["min"]) == 2 and st[2]["step"] == "first_battle", "漏斗依步驟順序、算分鐘")
	FN.leave("settings")
	var rep = JSON.parse_string(FN.report("1.6.0", "title"))
	ok(rep is Dictionary and rep["feedback"]["last_screen"] == "settings" and rep["feedback"]["funnel"].size() == 3 and rep["feedback"]["screen"] == "title", "回報含畫面、漏斗、最後離開的畫面")
	ok(not FN.report("1.6.0", "x").contains("player_name"), "回報沒有存檔欄位")
	SV.data = old

func test_save_v16_sanitize_v160() -> void:
	var SV = load("res://scripts/game/save.gd")
	var d := {"funnel": [], "mastery": {"2": 5, "x": 3, "99": 1, "4": "a"}, "notebook": {"p1": [{"n": "A", "u": [[0, 1, 2], [2, 1500, 3500, 1]], "r": [1, 2, 3]}, {"n": 3, "u": []}], "p2": "bad"},
		"daily_streak": {"last": 1}, "daily_pend": {"day": 1}, "rush_best": "x", "rift_best": {"k": [1, 2], "j": [1]}, "trio_clear": {"trio1": 50, "trio2": "x"}, "seen": [1, "a"]}
	SV.sanitize_extras(d)
	ok(d["funnel"] is Dictionary and d["funnel"].is_empty(), "funnel 型別錯→空")
	ok(d["mastery"] == {"2": 5}, "熟練度只留合法兵種與整數")
	ok(d["notebook"].size() == 1 and d["notebook"]["p1"].size() == 1 and d["notebook"]["p1"][0]["u"][1] == [2, 1500, 3500, 1], "實驗簿：壞的方案丟掉、自由兵保留")
	ok(d["daily_streak"].is_empty() and not d.has("daily_pend") and d["rush_best"] == 0, "缺欄位的連續天數、待送榜、極速賽紀錄回預設")
	ok(d["rift_best"] == {"k": [1, 2]} and d["trio_clear"] == {"trio1": 50} and d["seen"] == ["a"], "裂隙、三考、看過的入口逐項驗")
	var e := {}
	SV.sanitize_extras(e)
	ok(not e.has("seen"), "沒有 seen 就不建（老玩家第一次開 V1.6 才會補舊入口）")

func test_state_reset_v160() -> void:
	var SaveS = load("res://scripts/game/save.gd")
	var was: bool = SaveS.data_locked
	SaveS.data_locked = true
	var g = load("res://scripts/ui/game_screens.gd").new()
	g.sfx = FakeSfx.new()
	g.time = 1.0
	g.tv_mark_mode = true
	g.tv_marks = [Vector2i(1500, 1500)]
	g.ga_coop = true
	g.challenge_army = load("res://scripts/core/army.gd").new(1, 100)
	g._go_title()
	ok(not g.tv_mark_mode and g.tv_marks.is_empty() and not g.ga_coop and g.challenge_army == null, "回標題：標記模式、標記、接力、挑戰陣都清掉")
	var RSx = load("res://scripts/core/ruleset.gd")
	var a = RSx.standard()
	var b = RSx.standard()
	b.adj = true
	ok(not a.equals(b), "規則比較會看相鄰陣法")
	var d := {"seen": null}
	SaveS.sanitize_extras(d)
	ok(not d.has("seen"), "seen 是 null 就當沒有")
	g.free()
	SaveS.data_locked = was

func test_sanitize_truncate_v160() -> void:
	var SV = load("res://scripts/game/save.gd")
	var seen: Array = []
	for i in 250:
		seen.append("k%d" % i)
	var rb := {}
	for i in 60:
		rb["w%d" % i] = [1, 2]
	var d := {"seen": seen, "rift_best": rb}
	SV.sanitize_extras(d)
	ok(d["seen"].size() == 200 and d["rift_best"].size() == 50, "超量截斷，不整批清空")

## V1.0.0 W3：storeStats 回傳 true 只代表送出；user_stats_stored 回呼失敗要重送。
func test_ach_store_result_v100() -> void:
	var SV = load("res://scripts/game/save.gd")
	var ST = load("res://scripts/game/steam.gd")
	var keep: Dictionary = SV.data.duplicate(true)
	var old_prefix: String = SV.prefix
	SV.prefix = "t100ach_"
	var fk := FakeAch.new()
	ST._steam = fk
	ST._stats_wired = false
	SV.data = {"achievements": []}
	ST.unlock("FIRST_WIN")
	ok(fk.stores == 1 and not ST.store_ok and ST._ach_inflight, "送出：在途、還沒確認")
	ST.unlock("LONE_HERO")
	ok(fk.stores == 1, "在途時又解鎖：先不送")
	fk.emit_signal("user_stats_stored", 0, 1)
	ok(fk.stores == 2 and ST._ach_inflight, "回呼回來（但送出後又有新解鎖）：立刻再送一批", str(fk.stores))
	ok("LONE_HERO" in fk.set_ids, "新解鎖的也在這一批")
	fk.emit_signal("user_stats_stored", 0, 2)   # 結果不是 OK
	ok(not ST.store_ok and not ST._ach_inflight, "儲存回呼失敗要記下")
	for i in ST.ACH_RETRY_TICKS:
		ST.run_callbacks()
	ok(fk.stores == 3, "之後把本機成就重設再送", str(fk.stores))
	ST.now_ms = 100
	ST._ach_sent_at = 0
	ST.now_ms = ST.ACH_CONFIRM_MS + 10
	ST.run_callbacks()
	ok(not ST._ach_inflight and not ST.store_ok, "確認逾時：當失敗、之後重送")
	for i in ST.ACH_RETRY_TICKS:
		ST.run_callbacks()
	ok(fk.stores == 3, "逾時那批的回呼還沒回來：不送新批（Codex v100-i3）", str(fk.stores))
	fk.emit_signal("user_stats_stored", 0, 1)
	ok(not ST.store_ok, "逾時那批的遲到 OK 被吃掉，不算確認")
	for i in ST.ACH_RETRY_TICKS:
		ST.run_callbacks()
	ok(fk.stores == 4, "之後才送新批", str(fk.stores))
	fk.emit_signal("user_stats_stored", 0, 1)
	ok(ST.store_ok and not ST.ach_dirty, "新的一批自己的回呼 OK 才算確認")
	ST.now_ms = -1
	fk.fail_set = true
	ST.unlock("COMEBACK")
	ok(not ST.store_ok and fk.stores == 4, "setAchievement 失敗：這批不送", str(fk.stores))
	ST._steam = null
	ST._stats_wired = false
	ST._ach_inflight = false
	ST._ach_stale = false
	ST.ach_dirty = false
	ST.store_ok = true
	fk.free()
	for f in DirAccess.get_files_at("user://"):
		if f.begins_with("t100ach_"):
			DirAccess.remove_absolute("user://" + f)
	SV.prefix = old_prefix
	SV.data = keep

func test_medals_v161() -> void:
	var CA = load("res://scripts/game/career.gd")
	var FU = FakeU
	var md := {}
	for i in 20:
		CA.medal_add(md, [FU.new(0, 2, 3), FU.new(0, 2, 0), FU.new(1, 2, 9), FU.new(0, 20, 9, true)], 2 if i < 5 else -1)
	ok(md["2"] == [20, 60, 5] and not md.has("20"), "出場一場算一次、擊倒累加、MVP；敵方與召喚物不算", str(md))
	ok(CA.medals_of(md, 2) == [true, true, true] and CA.medals_of(md, 3) == [false, false, false], "三個戰功章")
	var S = load("res://scripts/game/save.gd")
	var bad := {"medals": {"2": [1, 2, 3], "x": [1, 1, 1], "3": [1, "a", 2]}}
	S.sanitize_extras(bad)
	ok(bad["medals"] == {"2": [1, 2, 3]}, "戰功驗型")

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

## D3（Codex v100-i1 #7）：執行中主檔壞了又隔離失敗：不覆蓋壞檔，這次記為未存。
func test_quarantine_fail_keeps_v100() -> void:
	var SV = load("res://scripts/game/save.gd")
	var keep: Dictionary = SV.data.duplicate(true)
	var old_prefix: String = SV.prefix
	SV.prefix = "t100qf_"
	var old_lock: bool = SV.data_locked
	SV.data_locked = false   # 前面的測試可能留著「未來版鎖定」
	SV.data = SV.DEFAULT_SAVE.duplicate(true)
	ok(SV.save_data(), "先存一次")
	var P: String = SV._dp()   # 統一檢查會再加 --prefix，路徑一律問存檔模組
	_put(P, "壞")
	SV.fail_inject = {"quarantine": 1}
	ok(not SV.save_data(), "隔離失敗：這次不存")
	ok(FileAccess.get_file_as_string(P) == "壞", "壞檔還在（證據沒被蓋掉）")
	SV.fail_inject = {}
	ok(SV.retry_pending(), "之後重試會成功")
	for f in DirAccess.get_files_at("user://"):
		if f.find("t100qf_") >= 0:
			DirAccess.remove_absolute("user://" + f)
	SV.data_locked = old_lock
	SV.prefix = old_prefix
	SV.data = keep

## Codex v100-i3：舊存檔沒有 ai_games／ai_wins 時用舊統計估；全新進度是 0。
func test_ai_count_migrate_v100() -> void:
	var SV = load("res://scripts/game/save.gd")
	var G = load("res://scripts/game/guide.gd")
	ok(int(SV.DEFAULT_SAVE["ai_games"]) == 0, "全新進度 0")
	var raw := {"schema_version": SV.SAVE_VERSION, "stats": {"games": 12, "wins": 7}, "tutorial": 3}
	var m: Dictionary = SV.migrate(raw) if SV.has_method("migrate") else {}
	if not m.is_empty():
		ok(int(m["ai_games"]) == 12 and int(m["ai_wins"]) == 7, "舊存檔用舊統計估", str(m.get("ai_games")))
		ok(G.next_step(m, true, false) != "ai", "老玩家不再推薦打第一場 AI")

## 1.1.0 N1／A24：回報帶類別與格式版本；第一次開戰秒數只在第一次開遊戲那次記。
func test_report_cat_firstbattle_v110() -> void:
	var SV = load("res://scripts/game/save.gd")
	var F = load("res://scripts/game/funnel.gd")
	var keep: Dictionary = SV.data.duplicate(true)
	SV.data = {"funnel": {"boots": 1, "boot": 1000}}
	F.first_battle_time(95000)
	ok(int(SV.data["funnel"]["first_battle_sec"]) == 95, "第一次開遊戲：記 95 秒")
	F.first_battle_time(200000)
	ok(int(SV.data["funnel"]["first_battle_sec"]) == 95, "只記第一次")
	SV.data = {"funnel": {"boots": 2, "boot": 1000}}
	F.first_battle_time(5000)
	ok(not SV.data["funnel"].has("first_battle_sec"), "第二次開遊戲才第一次開戰：不記")
	SV.data = {"funnel": {"boots": 1, "boot": 1000, "first_battle_sec": 42}}
	var d = JSON.parse_string(F.report("1.1.0", "title", "stuck"))
	var fb: Dictionary = d["feedback"]
	ok(int(fb["fmt"]) == 2 and fb["cat"] == "stuck" and int(fb["first_battle_sec"]) == 42 and int(fb["first_boot"]) == 1000, "回報帶類別、格式版本、秒數", str(fb))
	SV.data = keep

## 1.1.0 E2：Steam 平台唯讀報告（雲端檔案多了不該同步的要列出來）。
func test_platform_report_v110() -> void:
	var ST = load("res://scripts/game/steam.gd")
	var fk := FakePlat.new()
	var r: Dictionary = ST.platform_report(fk)
	ok(r["cloud_account"] and r["cloud_app"] and r["cloud_files"].size() == 3, "雲端開關與檔案清單", str(r))
	ok(r["cloud_unexpected"] == ["settings.json"], "多同步了設定檔要列出來", str(r["cloud_unexpected"]))
	ok(r["beta"] == "beta" and r["leaderboard_api"] == false, "分支名稱、排行榜 API 偵測")
	ok(ST.platform_report(null).is_empty(), "沒有 Steam 回空")

## 1.1.0 A15：每個成就都有類別。
func test_ach_cat_v110() -> void:
	var ST = load("res://scripts/game/steam.gd")
	var miss: Array = []
	for k in ST.ACHIEVEMENTS:
		if not ST.ACH_CAT.has(k) or not ST.ACH_CAT_COL.has(ST.ACH_CAT[k]):
			miss.append(k)
	ok(miss.is_empty() and ST.ACH_CAT.size() == ST.ACHIEVEMENTS.size(), "37 個成就都有類別", str(miss))
