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
	var TR = load("res://scripts/game/trio.gd")
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
		"NTS1": "settings", "NTW1": "waves", "NTQ1": "solution"}
	var bad: Array = []
	for p in want:
		if G.code_kind(p + ".abc.123456") != want[p]:
			bad.append(p)
	ok(bad.is_empty(), "每個前綴都認得", str(bad))
	for junk in ["", "hello", "NTX1.a.b", "ntb1.a.b", "NTB8.a.b"]:
		ok(G.code_kind(junk) == "", "不認得的不辨識：" + junk)
	var md := FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../docs/codes.md"))
	if md == "":
		print("SKIP docs/codes.md 不在（快照或匯出環境）")
	else:
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

## R1（Codex v100-i2）：試煉（自由部署）重打保留擺法；殘局固定兵不重複。
func test_retry_trial_free_v100() -> void:
	var g = load("res://scripts/ui/game_screens.gd").new()
	g.sfx = FakeSfx.new()
	var PZ = load("res://scripts/game/puzzles.gd")
	var pz: Dictionary = PZ.puzzles()[0]
	ok(not (pz.get("fixed", []) as Array).is_empty(), "第一關有固定兵")
	g._pick_puzzle(str(pz["id"]), false)
	var nfix: int = g.armies[0].units.size()
	g.last_armies = [g.armies[0].copy(), g.armies[1].copy()]
	g._mark_retry()
	g._start_mode(g.Mode.PUZZLE)
	ok(g.armies[0].units.size() == nfix, "只有固定兵時重打不會多出一份", str(g.armies[0].units.size()))
	g._start_trial(0)
	var a = g.armies[0]
	ok(a.deploy == "free", "試煉是自由部署")
	var placed := 0
	for p in [[0, 3000, 3000], [1, 3000, 5000], [2, 1500, 4000]]:
		if a.place_xy(p[0], p[1], p[2]):
			placed += 1
	ok(placed >= 2, "擺得上去", str(placed))
	var n1: int = a.units.size()
	g.last_armies = [a.copy(), g.armies[1].copy()]
	g._mark_retry()
	ok(g.retry_key == "tr:0", "試煉的重打鍵", g.retry_key)
	g._start_trial(0)
	g._apply_retry()
	ok(g.armies[0].units.size() == n1, "試煉重打：擺法還在", "%d/%d" % [g.armies[0].units.size(), n1])
	g.free()

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

## 1.1.0 H1：覆盤重算、GIF 編碼可叫停。
func test_review_gif_cancel_v110() -> void:
	var RV = load("res://scripts/ui/replay_view.gd")
	var Armyx = load("res://scripts/core/army.gd")
	var a = Armyx.new(0, 100)
	a.place(0, 4, 4)
	var e = Armyx.new(1, 100)
	e.place(0, 11, 4)
	var full: Dictionary = RV.review_run(a, e)
	ok(int(full["ticks"]) > 0, "照常跑完")
	ok(bool(RV.review_run(a, e, null, [], {"stop": true}).get("cancel", false)), "叫停回 cancel")
	var r2: Dictionary = RV.review_run(a, e, null, [], {"stop": false, "until": Time.get_ticks_msec() + 600000})
	ok(int(r2["ticks"]) == int(full["ticks"]) and int(r2["winner"]) == int(full["winner"]), "帶 ctl 結果一樣")
	var G = load("res://scripts/game/gif.gd")
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	ok(G.encode([img], 10).size() > 0 and G.encode([img], 10, {"stop": true}).is_empty(), "GIF 叫停回空")

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


class FakePlat:
	func isCloudEnabledForAccount(): return true
	func isCloudEnabledForApp(): return true
	func getFileCount(): return 3
	func getFileNameAndSize(i): return {"name": ["save.json", "save.json.bak", "settings.json"][i], "size": 10}
	func getCurrentBetaName(): return {"ret": true, "name": "beta"}

## 1.1.0 A11：裂隙遍歷 520 週（約 10 年）× 正式／試玩卡池：三個異變、類別不重複、沒有排除組合、規則合法、敵陣有戰鬥兵。
func test_rift_seeds_v110() -> void:
	var RF = load("res://scripts/game/rift.gd")
	var RO = load("res://scripts/game/roster.gd")
	var bad: Array = []
	var seen := {}
	for demo in [false, true]:
		var mask: int = RO.mask(demo)
		for wk in range(2900, 3420):
			var ps: Array = RF.picks(wk, mask)
			var tags := {}
			var why := ""
			if ps.size() != RF.PICK:
				why = "數量"
			for k in ps:
				if tags.has(RF.ANOMS[k][1]):
					why = "同類"
				tags[RF.ANOMS[k][1]] = true
				seen[k] = true
			for i in ps.size():
				if RF.clash(ps.slice(0, i), ps[i]):
					why = "排除組合"
			var r = RF.make_rules(ps, mask, wk)
			if not r.validate().is_empty():
				why = "規則不合法"
			elif wk % 13 == 0:
				var e = RF.enemy(r, wk)
				if e == null or not e.has_combat():
					why = "敵陣沒有戰鬥兵"
			if why != "" and bad.size() < 5:
				bad.append("%s 週 %d：%s" % ["試玩" if demo else "正式", wk, why])
	ok(bad.is_empty(), "520 週 × 2 種卡池都合法", str(bad))
	ok(seen.size() == RF.ANOMS.size(), "每一種異變都抽得到", "%d/%d" % [seen.size(), RF.ANOMS.size()])

## 1.1.0 B13：詞彙格改名最多 16 字。
func test_nb_words_v110() -> void:
	var G = load("res://scripts/ui/screens/game_v16.gd")
	ok(G.nb_words_add("速攻", "側翼") == "速攻側翼", "接起來")
	ok(G.nb_words_add("一二三四五六七八九十一二三四", "側翼包夾") .length() == 16, "超過 16 字截斷")
	var L = load("res://scripts/game/strings.gd")
	for k in G.NB_WORDS + ["nb_words_hint", "nb_words_del"]:
		ok(L.has(k), "字串 " + k)

## 1.1.0 A23：舊 ws 實驗簿封存匯出（原內容照存）。
func test_ws_archive_v110() -> void:
	var G = load("res://scripts/ui/screens/game_menus.gd")
	var d := {"notebook": {"ws": [{"n": "A", "u": [[0, 1, 2]], "r": []}], "p1": []}}
	var j = JSON.parse_string(G.ws_archive_text(d))
	ok(j is Dictionary and (j["ws_archive"] as Array).size() == 1 and str(j["ws_archive"][0]["n"]) == "A", "舊方案原樣匯出")
	ok(d["notebook"].has("ws"), "不刪原資料")

## 1.1.0 A10：章節全三星才蓋印。
func test_chapter_seal_v110() -> void:
	var G = load("res://scripts/ui/screens/game_menus.gd")
	var chap := [{"id": "a"}, {"id": "b"}]
	ok(not G.chapter_sealed(chap, {"a": 3, "b": 2}), "差一顆星不蓋")
	ok(G.chapter_sealed(chap, {"a": 3, "b": 3}), "全三星蓋印")
	ok(not G.chapter_sealed([], {}), "空章節不蓋")

## 1.1.0 A13：同目標超過 3 條只畫 3 條、標總數。
func test_lock_groups_v110() -> void:
	var G = load("res://scripts/ui/screens/game_v16.gd")
	var t := Vector2i(12000, 4000)
	var t2 := Vector2i(13000, 2000)
	var prs: Array = []
	for i in 5:
		prs.append([Vector2i(1000 * i, 1000), t])
	prs.append([Vector2i(500, 500), t2])
	var g: Dictionary = G.lock_groups(prs, 3)
	ok((g["draw"] as Array).size() == 4, "目標 1 畫 3 條、目標 2 畫 1 條")
	ok(int(g["count"].get(t, 0)) == 5 and not g["count"].has(t2), "超過的標總數 5")
	ok((g["rest"] as Array).size() == 2, "第 4、5 條另外記（畫細線到 ×N）")

## 1.1.0 A15：每個成就都有類別。
func test_ach_cat_v110() -> void:
	var ST = load("res://scripts/game/steam.gd")
	var miss: Array = []
	for k in ST.ACHIEVEMENTS:
		if not ST.ACH_CAT.has(k) or not ST.ACH_CAT_COL.has(ST.ACH_CAT[k]):
			miss.append(k)
	ok(miss.is_empty() and ST.ACH_CAT.size() == ST.ACHIEVEMENTS.size(), "37 個成就都有類別", str(miss))

## 1.1.0 N5：最佳解碼來回、壞碼不收、最佳排序同實驗簿、存檔驗證。
func test_solution_code_v110() -> void:
	var SC = load("res://scripts/game/solution_code.gd")
	var PZ = load("res://scripts/game/puzzles.gd")
	var pz: Dictionary = PZ.puzzles()[0]
	var sol: Array = pz.get("best", {}).get("u", [])
	ok(not sol.is_empty(), "第一關有三星解")
	var code: String = SC.encode(str(pz["id"]), sol)
	var d: Dictionary = SC.decode(code)
	ok(bool(d["ok"]) and d["pid"] == str(pz["id"]) and (d["u"] as Array).size() == sol.size(), "來回")
	ok(not bool(SC.decode(code + "x")["ok"]) and not bool(SC.decode("NTQ1.abc.123456")["ok"]), "壞碼不收")
	ok(not bool(SC.decode(SC.encode("ws", sol))["ok"]) and not bool(SC.decode(SC.encode("no_such", sol))["ok"]), "工坊、不存在的關不收")
	var best := {}
	SC.merge(best, "p1", 2, 40, 30, [[0, 1, 2]])
	SC.merge(best, "p1", 2, 40, 35, [[0, 1, 3]])
	ok(best["p1"]["u"] == [[0, 1, 2]], "花費多的不換")
	SC.merge(best, "p1", 3, 10, 50, [[0, 1, 4]])
	ok(best["p1"]["u"] == [[0, 1, 4]] and best["p1"]["r"] == [3, 10, 50], "星數多優先")
	var S = load("res://scripts/game/save.gd")
	var dd := {"pz_sol": {"p1": {"r": [3, 10, 50], "u": [[0, 1, 4]]}, "bad": {"r": [1], "u": []}, "bad2": {"r": [1, 2, 3], "u": [["x", 1, 2]]}}}
	S.sanitize_extras(dd)
	ok(dd["pz_sol"].size() == 1 and dd["pz_sol"].has("p1"), "存檔驗證丟掉壞的", str(dd["pz_sol"]))
	var G = load("res://scripts/ui/screens/game_menus.gd")
	ok(G.code_kind(code) == "solution", "代碼頁認得 NTQ1")

## 1.1.0（Codex v110-i1）：回報檔名不撞、最佳解存檔驗證範圍、帶軍令的最佳解碼。
func test_review_fixes_v110() -> void:
	var G = load("res://scripts/ui/screens/game_v16.gd")
	var f0: String = G.report_name("t110r_", 123)
	var fa := FileAccess.open(f0, FileAccess.WRITE)
	fa.store_string("x")
	fa.close()
	ok(G.report_name("t110r_", 123) != f0, "同一秒第二份換檔名")
	DirAccess.remove_absolute(f0)
	var S = load("res://scripts/game/save.gd")
	ok(not S.sol_entry_ok({"r": [999, 10, 10], "u": [[0, 1, 2]]}), "星數 999 不收")
	ok(not S.sol_entry_ok({"r": [3, 10, 10], "u": []}), "空部署不收")
	ok(not S.sol_entry_ok({"r": [3, 10, 10], "u": [[0, 99, 2]]}), "座標出界不收")
	ok(S.sol_entry_ok({"r": [3, 10, 10], "u": [[0, 1, 2]], "c": [40, 80]}), "正常的收")
	var SC = load("res://scripts/game/solution_code.gd")
	var PZ = load("res://scripts/game/puzzles.gd")
	var cmdpz: Dictionary = {}
	for p in PZ.all_puzzles():
		if p.has("cmd") and not p.get("best", {}).get("u", []).is_empty():
			cmdpz = p
			break
	if not cmdpz.is_empty():
		var plan: Array = PZ.default_plan(cmdpz)
		var d: Dictionary = SC.decode(SC.encode(str(cmdpz["id"]), cmdpz["best"]["u"], plan))
		ok(bool(d["ok"]) and d["plan"] == plan, "時序關卡連軍令一起來回")
		ok(not bool(SC.decode(SC.encode(str(cmdpz["id"]), cmdpz["best"]["u"], [1]))["ok"]) or plan.size() == 1, "軍令數量不對不收")
		# Codex v110-i2 #1：軍令要合法（時間在開場～局長內、照冷卻），小數、負數不收
		ok(SC.plan_legal(cmdpz, plan), "預設軍令合法")
		var bad_t: Array = plan.duplicate()
		bad_t[0] = PZ.plan_make(cmdpz, PZ.plan_skill(cmdpz, int(plan[0])), 999999)
		ok(not SC.plan_legal(cmdpz, bad_t), "超過局長不收")
		var bad_n: Array = plan.duplicate()
		bad_n[0] = -1
		ok(not bool(SC.decode(SC.encode(str(cmdpz["id"]), cmdpz["best"]["u"], bad_n))["ok"]), "負數軍令不收")
	ok(not SC._int_like(1.9) and SC._int_like(2.0) and SC._int_like(3), "只收整數")
	ok(not S.sol_entry_ok({"r": [3, 10.5, 10], "u": [[0, 1, 2]]}), "存檔小數不收")
	ok(not S.sol_entry_ok({"r": [3, 10, 10], "u": [[0, 1.5, 2]]}), "存檔座標小數不收")
	# Codex v110-i3 #1：存檔裡不合法的舊紀錄（重疊部署）不能擋住合法新紀錄
	var p0: Dictionary = PZ.puzzles()[0]
	var good_u: Array = p0["best"]["u"]
	var dup: Array = [good_u[0], good_u[0]]
	var bk := {str(p0["id"]): {"r": [3, 100, 0], "u": dup, "c": []}}
	ok(not SC.entry_valid(str(p0["id"]), bk[str(p0["id"])]), "重疊部署判不合法")
	SC.merge(bk, str(p0["id"]), 1, 5, 99, good_u)
	ok(bk[str(p0["id"])]["u"] == good_u, "合法新紀錄換掉不合法舊紀錄")

## 1.1.0 A7（P2）：新增的鼓手木紋波、狂戰士斧弧是裝飾：4 倍速以上不畫、減少特效時不出。
func test_a7_p2_fx_v110() -> void:
	var F = load("res://scripts/ui/battle/battle_fx.gd")
	for kd in ["woodwave", "axearc"]:
		ok(kd in F.FAST_SKIP, "%s 高倍速略過" % kd)
	var src := FileAccess.get_file_as_string("res://scripts/ui/battle/battle_fx.gd")
	ok(src.contains('d["kind"] in ["woodwave", "axearc",'), "減少特效時不出")
	ok(src.contains('"woodwave":') and src.contains('"axearc":'), "有畫法")
