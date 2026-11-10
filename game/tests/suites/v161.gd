extends "res://tests/test_base.gd"
## V1.6.1 測試（docs/2026-11-10-v1.6.1-plan.md）。會碰存檔的測試自己換前綴、結束還原。

func test_nb_key_v161() -> void:
	var CA = load("res://scripts/game/v16_career.gd")
	var pz1 := {"id": "ws", "zh": "工坊殘局", "en": "W", "enemy": [[0, 12, 3], [1, 11, 2]], "fixed": [], "budget": 10, "allowed": [0, 1], "star2": 40, "star3": 10}
	var pz2 := pz1.duplicate(true)
	pz2["enemy"] = [[1, 11, 2], [0, 12, 3]]   # 兵的順序不同
	pz2["ja"] = "x"
	var pz3 := pz1.duplicate(true)
	pz3["enemy"] = [[0, 12, 4], [1, 11, 2]]
	var k1: Array = CA.ws_key(pz1)
	ok(k1 == CA.ws_key(pz2), "同一題（順序、文字不同）同鍵")
	ok(k1[0] != CA.ws_key(pz3)[0], "不同題不同鍵")
	ok(str(k1[0]).length() <= 24 and str(k1[1]).length() <= 32, "鍵長合存檔驗型")
	ok(CA.ws_key({"trio": "t3"})[0] == "qt3", "一陣三考用題組 id")
	var nb := {}
	CA.nb_save(nb, "wabc", "A", [[0, 1, 2]], "h1")
	CA.nb_save(nb, "wabc", "B", [[0, 1, 3]], "h2")   # 撞短鍵的另一題
	ok(CA.nb_list(nb, "wabc", "h1").size() == 1 and CA.nb_list(nb, "wabc", "h2").size() == 1, "撞短鍵時用完整雜湊分開")
	ok(CA.nb_save(nb, "wabc", "C", [[0, 1, 3]], "h1"), "別題存過的擺法，這題還能存")

func test_nb_better_v161() -> void:
	var CA = load("res://scripts/game/v16_career.gd")
	var nb := {}
	CA.nb_save(nb, "p1", "A", [[0, 1, 2]])
	CA.nb_result(nb, "p1", [[0, 1, 2]], 2, 40, 30)
	CA.nb_result(nb, "p1", [[0, 1, 2]], 2, 40, 25)
	ok(nb["p1"][0]["r"] == [2, 40, 25], "同星同剩餘、花費更低要更新（F8）")
	CA.nb_result(nb, "p1", [[0, 1, 2]], 2, 40, 28)
	ok(nb["p1"][0]["r"] == [2, 40, 25], "花費較高不覆蓋")

func test_nb_sanitize_hash_v161() -> void:
	var S = load("res://scripts/game/save.gd")
	var d := {"notebook": {"wabc": [{"n": "A", "u": [[0, 1, 2]], "r": [], "h": "0123456789abcdef0123456789abcdef"}, {"n": "B", "u": [[0, 1, 3]], "r": [], "h": 5}]}}
	S.sanitize_v16(d)
	var l: Array = d["notebook"]["wabc"]
	ok(l.size() == 2 and str(l[0].get("h", "")) == "0123456789abcdef0123456789abcdef" and not l[1].has("h"), "雜湊欄保留、型別錯丟掉")

func test_pz_names_l10n_v161() -> void:
	var TR = load("res://scripts/game/v16_trio.gd")
	var L = load("res://scripts/game/strings.gd")
	var s: Dictionary = TR.sets()[0]
	var pz: Dictionary = TR.make_pz(s, 0)
	ok(pz.has("sc") and pz.has("ja") and pz.has("hint_ja") and str(pz["ja"]) != str(pz["en"]), "三考題名有簡中、日文（F6）")
	var WS = load("res://scripts/game/workshop.gd")
	var pz2 := {}
	L.fill(pz2, "", "rl_title", [3])
	ok(str(pz2.get("ja", "")).find("3") >= 0 and str(pz2.get("sc", "")).find("3") >= 0, "接力題名帶參數")

## V1.6.1 F2／N6：每日、每週榜的假 Steam 替身：分版榜名、上傳失敗、送出後又換成更好的成績（亂序）、重送。
func test_board_double_v161() -> void:
	var SV = load("res://scripts/game/save.gd")
	var ST = load("res://scripts/game/steam.gd")
	var keep: Dictionary = SV.data.duplicate(true)
	var old_prefix: String = SV.prefix
	SV.prefix = "t161lb_"
	var fk := FakeLB.new()
	ST._steam = fk
	ST._lb_wired = false
	SV.data = {"daily_pend": {"day": 100, "score": 50000, "det": [2, 1, 5], "ver": 1}}
	ST.daily_upload(100, 50000, PackedInt32Array([2, 1, 5]), 1)
	ok(fk.finds == ["daily_100_v1"], "榜名帶題目版本", str(fk.finds))
	fk.emit_signal("leaderboard_find_result", 7, 1)
	ok(fk.ups.size() == 1 and int(fk.ups[0][0]) == 50000, "找到榜就上傳")
	SV.data["daily_pend"] = {"day": 100, "score": 60000, "det": [2, 1, 6], "ver": 1}   # 回呼前又打出更好的
	fk.emit_signal("leaderboard_score_uploaded", true, 7, {})
	ok(int(SV.data.get("daily_pend", {}).get("score", 0)) == 60000, "舊那筆成功不會清掉新的待送")
	ST.daily_upload(100, 60000, PackedInt32Array([2, 1, 6]), 1)
	fk.emit_signal("leaderboard_find_result", 8, 1)
	fk.emit_signal("leaderboard_score_uploaded", false, 8, {})
	ok(SV.data.has("daily_pend"), "上傳失敗留著待送")
	ST.daily_upload(100, 60000, PackedInt32Array([2, 1, 6]), 1)
	fk.emit_signal("leaderboard_find_result", 9, 1)
	fk.emit_signal("leaderboard_score_uploaded", true, 9, {})
	ok(not SV.data.has("daily_pend"), "重送成功才清")
	ok(not ST.clear_pending({"daily_pend": {"day": 100, "score": 1, "ver": 2}}, "daily_100_v1", 1), "不同版本的榜不清")
	# 同一個榜（同 handle）連送兩次：低分的回呼先到，不能清掉高分的待送（Codex v161-i1 #1）
	SV.data["daily_pend"] = {"day": 100, "score": 70000, "det": [2, 1, 7], "ver": 1}
	ST.daily_upload(100, 65000, PackedInt32Array([2, 1, 7]), 1)
	fk.emit_signal("leaderboard_find_result", 9, 1)
	ST.daily_upload(100, 70000, PackedInt32Array([2, 1, 7]), 1)
	ok(fk.finds.size() == 4, "在途時又要送：先排隊、不重複找榜（Codex v161-i2 #1）", str(fk.finds))
	fk.emit_signal("leaderboard_score_uploaded", true, 9, {})
	ok(SV.data.has("daily_pend") and fk.finds.size() == 5, "低分那筆回來：不清，接著送排隊的高分")
	fk.emit_signal("leaderboard_find_result", 9, 1)
	fk.emit_signal("leaderboard_score_uploaded", false, 9, {})
	ok(SV.data.has("daily_pend"), "高分那筆失敗：留著")
	ST.daily_upload(100, 70000, PackedInt32Array([2, 1, 7]), 1)
	fk.emit_signal("leaderboard_find_result", 9, 1)
	fk.emit_signal("leaderboard_score_uploaded", true, 9, {})
	ok(not SV.data.has("daily_pend"), "高分那筆成功才清")
	# 每週
	SV.data["weekly"] = {"wk": 5, "best": 40, "pend": 1, "det": [1, 1, 100510]}
	ST.weekly_upload(5, 40, PackedInt32Array([1, 1, 100510]))
	fk.emit_signal("leaderboard_find_result", 11, 1)
	SV.data["weekly"]["best"] = 35   # 送出後又刷新最佳
	fk.emit_signal("leaderboard_score_uploaded", true, 11, {})
	ok(int(SV.data["weekly"]["pend"]) == 1, "每週：舊那筆成功不清新的待送")
	ok(ST.clear_pending(SV.data, "weekly_5", 35) and int(SV.data["weekly"]["pend"]) == 0, "每週：同一筆才清")
	ST._steam = null
	ST._lb_wired = false
	ST._lb_sent = {}
	ST._lb_busy = {}
	ST._lb_next = {}
	fk.free()
	for f in DirAccess.get_files_at("user://"):
		if f.begins_with("t161lb_"):
			DirAccess.remove_absolute("user://" + f)
	SV.prefix = old_prefix
	SV.data = keep


class FakeLB extends Node:
	signal leaderboard_find_result(handle, found)
	signal leaderboard_scores_downloaded(msg, handle, result)
	signal leaderboard_score_uploaded(success, handle, this_score)
	var finds: Array = []
	var ups: Array = []
	var names := {7: "daily_100_v1", 8: "daily_100_v1", 9: "daily_100_v1", 11: "weekly_5"}
	func findOrCreateLeaderboard(n, _a, _b): finds.append(n)
	func findLeaderboard(n): finds.append(n)
	func getLeaderboardName(h): return names.get(h, "")
	func uploadLeaderboardScore(sc, _keep, det, h): ups.append([sc, det, h])
	func downloadLeaderboardEntries(_a, _b, _c, _h): pass

func test_fog_free_v161() -> void:
	var G = load("res://scripts/ui/screens/game_v16.gd")
	var us := [{"type": 0, "x": 10500, "y": 1500}, {"type": 1, "x": 11500, "y": 2500}, {"type": 2, "x": 14500, "y": 3500}, {"type": 2, "x": 12500, "y": 3500}]
	var seen: Array = G.fog_seen(us)
	ok(seen.size() == 2 and int(seen[0]["x"]) == 10500 and int(seen[1]["x"]) == 14500, "自由座標也露（F3），和格子同樣的順序規則")

func test_hold_rebind_v161() -> void:
	var G = load("res://scripts/ui/screens/game_v16.gd")
	var ev := InputEventKey.new()
	ev.keycode = KEY_K
	ev.physical_keycode = KEY_K
	ev.pressed = true
	Input.use_accumulated_input = false
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	ok(G.hold_keys_down({"place": KEY_K}, {}), "按住確認認得改過的放置鍵（F4）")
	ok(not G.hold_keys_down({}, {}), "沒改鍵時 K 不算")
	ev.pressed = false
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	Input.use_accumulated_input = true
	ok(not G.hold_keys_down({"place": KEY_K}, {}), "放開就停")

func test_coach_search_v161() -> void:
	var CO = load("res://scripts/game/v16_coach.gd")
	var Army = load("res://scripts/core/army.gd")
	var weak = Army.new(0, 100)
	weak.place(0, 0, 4)
	var strong = Army.new(1, 100)
	for r in [1, 3, 5, 7]:
		strong.place(3, 10, r)
	var res: Dictionary = CO.search(weak, strong, null, {}, 32)
	ok(not bool(res["found"]) and str(res["status"]) in ["exhausted", "budget"], "沒找到要分清楚是全試過還是預算用完", str(res))
	var pl: Dictionary = CO.plan(weak, {}, 32)
	ok((pl["list"] as Array).size() <= 32 and int(pl["total"]) >= (pl["list"] as Array).size(), "候選不超過 32")
	var sw: Array = CO.swap_cands(weak)
	var D = load("res://scripts/core/unit_defs.gd")
	ok(not sw.is_empty() and sw.all(func(c): return D.cost(int(c[2])) == D.cost(0) and int(c[2]) != 0), "換兵只換同價、不同種（A5）")
	var ctl := {"stop": true}
	var r2: Dictionary = CO.search(weak, strong, null, {}, 32, ctl)
	ok(str(r2["status"]) == "cancel" and int(r2["tries"]) == 0, "取消立刻停（F5）")
	var r3: Dictionary = CO.search(weak, strong, null, {}, 32, {"until": 1})
	ok(str(r3["status"]) == "timeout", "期限過了算時間到，不說無解")
	# 自由部署
	var fa = Army.new(0, 100)
	fa.deploy = "free"
	fa.place_xy(3, 4000, 4500)
	var fm: Array = CO.move_cands(fa)
	ok(not fm.is_empty() and fm.all(func(c): return c[0] == "x" and (int(c[2]) - 4000) % 500 == 0), "自由部署也有移位候選（半格）")
	ok(CO.supported(fa, null, {}), "自由部署可以用教練")

func test_coach_record_v161() -> void:
	var G = load("res://scripts/ui/screens/game_v16.gd")
	var d := {"puzzle_stars": {"p5": 3}, "coached": {"p5": {"lv": 2, "ap": 0, "self": 1}}}
	ok(G.coach_badge(d, "p5"), "用過第 2 層、自力只有 1 星：顯示教練協力")
	d["coached"]["p5"]["self"] = 3
	ok(not G.coach_badge(d, "p5"), "自力也拿到 3 星：不顯示")
	var S = load("res://scripts/game/save.gd")
	var bad := {"coached": {"p1": {"lv": 9, "ap": 3, "self": -2}, "p2": "x"}}
	S.sanitize_v16(bad)
	ok(bad["coached"] == {"p1": {"lv": 3, "ap": 0, "self": 0}}, "教練紀錄驗型", str(bad["coached"]))

func test_ntp4_v161() -> void:
	var WS = load("res://scripts/game/workshop.gd")
	var e := [[0, 10, 4], [3, 11, 4], [1, 12, 2]]
	var s := [[3, 4, 3], [3, 4, 5], [0, 5, 4], [2, 2, 4]]
	var c3: String = WS.encode4(e, s, "kill", Vector2i(-1, -1))
	ok(c3.begins_with("NTP3."), "沒指定目標照舊出 NTP3")
	var c4: String = WS.encode4(e, s, "kill", Vector2i(10, 4))
	if c4 != "":
		var d: Dictionary = WS.decode(c4)
		ok(c4.begins_with("NTP4.") and bool(d["ok"]) and d["pz"]["goal_unit"] == [10, 4], "指定斬首目標（不是最貴的那隻）", str(d.get("why")))
	ok(WS.encode4(e, s, "kill", Vector2i(4, 3)) == "", "斬首點到自己的兵不給碼")
	ok(WS.pick_fields("flawless", e, s, [2, 4]) == {"goal": "flawless", "goal_type": 2, "need_type": true}, "完美：點到哪隻就是那種兵")
	ok(WS.pick_fields("protect", e, s, [9, 9]).is_empty() and WS.pick_fields("protect", e, s, "x").is_empty(), "壞的目標欄位擋掉")
	# 竄改：NTP4 帶不在作者解的目標
	var j := JSON.stringify({"v": 4, "e": e, "s": s, "a": [0, 2, 3], "g": "protect", "t": [15, 8]})
	var b := Marshalls.utf8_to_base64(j).replace("+", "-").replace("/", "_").replace("=", "")
	ok(not bool(WS.decode("NTP4.%s.%s" % [b, b.sha256_text().substr(0, 6)])["ok"]), "目標不存在的 NTP4 拒收")
	ok(WS.decode("NTP3.x.y")["ok"] == false, "NTP3 舊路徑照舊驗")

func test_rules_equals_map_v161() -> void:
	var RS = load("res://scripts/core/ruleset.gd")
	var a = RS.standard()
	var b = RS.standard()
	ok(a.equals(b), "同樣規則相等")
	b.map_id = 3
	ok(not a.equals(b), "地圖不同就不相等（B1）")
	b.map_id = 0
	b.map_size = 2
	ok(not a.equals(b), "大小不同就不相等")

func test_lock_targets_v161() -> void:
	var G = load("res://scripts/ui/screens/game_v16.gd")
	var Army = load("res://scripts/core/army.gd")
	var a = Army.new(0, 100)
	a.place(0, 4, 4)
	a.place(2, 2, 1)
	var e = Army.new(1, 100)
	e.place(0, 11, 4)
	e.place(1, 12, 8)
	var lk: Array = G.lock_targets(a, e, null)
	ok(lk.size() == 2 and lk.all(func(p): return p[1].x > 8000), "每隻我方兵都鎖定一隻敵兵（A9）", str(lk))

func test_new_after_v161() -> void:
	var G = load("res://scripts/game/v16_guide.gd")
	var d := {"eff_games": 2}
	G.seed_seen(d)
	ok(not G.is_new(d, "rush_open"), "前 2 場不標新玩法（N1）")
	ok(not G.tour_due(d, false), "新手不跳導覽")
	d["eff_games"] = 3
	ok(G.is_new(d, "rush_open") and G.tour_due(d, false) and not G.tour_due(d, true), "玩滿 3 場：標新、跳一次導覽（試玩版不跳）")
	G.see(d, "tour161")
	ok(not G.tour_due(d, false), "導覽只跳一次")

func test_medals_v161() -> void:
	var CA = load("res://scripts/game/v16_career.gd")
	var FU = load("res://tests/suites/v16.gd").FakeU
	var md := {}
	for i in 20:
		CA.medal_add(md, [FU.new(0, 2, 3), FU.new(0, 2, 0), FU.new(1, 2, 9), FU.new(0, 20, 9, true)], 2 if i < 5 else -1)
	ok(md["2"] == [20, 60, 5] and not md.has("20"), "出場一場算一次、擊倒累加、MVP；敵方與召喚物不算", str(md))
	ok(CA.medals_of(md, 2) == [true, true, true] and CA.medals_of(md, 3) == [false, false, false], "三個戰功章")
	var S = load("res://scripts/game/save.gd")
	var bad := {"medals": {"2": [1, 2, 3], "x": [1, 1, 1], "3": [1, "a", 2]}}
	S.sanitize_v16(bad)
	ok(bad["medals"] == {"2": [1, 2, 3]}, "戰功驗型")

func test_nb_name_input_v161() -> void:
	var G = load("res://scripts/ui/screens/game_v16.gd")
	ok(G.nb_edit_append("ab", 0x99AC) == "ab馬" and G.nb_edit_append("ab", 9) == "ab", "改名：收一般字（含中文），控制字元不收（N3）")
	ok(G.nb_edit_append("0123456789abcdef", 65).length() == 16, "最多 16 字")

func test_signature_v161() -> void:
	var PS = load("res://scripts/game/v16_persona.gd")
	var AI = load("res://scripts/core/ai_army.gd")
	var hits := 0
	for sd in 200:
		var t: int = PS.signature(2, sd, func(x): return true)
		if t >= 0:
			hits += 1
			ok(t in PS.SIG[2], "招牌陣只會是這個性格的兩套")
	ok(hits > 50 and hits < 110, "約 40% 用招牌陣（A11）", str(hits))
	ok(PS.signature(4, 3, func(x): return false) == -1, "卡池用不了就照舊")
	ok(PS.signature(1, 77, func(x): return true) == PS.signature(1, 77, func(x): return true), "同種子同結果（可重現）")
	for st in PS.SIG.size():
		for t in PS.SIG[st]:
			ok(int(t) < AI.TEMPLATES.size(), "招牌陣編號有效")

func test_rift_history_v161() -> void:
	var RF = load("res://scripts/game/v16_rift.gd")
	var b := {}
	for w in range(100, 112):
		b["%d-v1" % w] = [w, 50]
	var k: Dictionary = RF.keep_recent(b, 8)
	ok(k.size() == 8 and k.has("111-v1") and not k.has("103-v1"), "裂隙紀錄留最近 8 週（A12）")
	b["111-v2"] = [1, 1]
	var k2: Dictionary = RF.keep_recent(b, 8)
	ok(RF.weeks_of(k2).size() == 8 and k2.has("111-v1") and k2.has("111-v2") and k2.has("104-v1"), "同一週不同版本算同一週（Codex v161-i2 #4）")

func test_rush_daily_v161() -> void:
	var RU = load("res://scripts/game/v16_rush.gd")
	var L = load("res://scripts/game/strings.gd")
	ok(RU.pool(RU.day_seed(20000)) == RU.pool(RU.day_seed(20000)) and RU.pool(RU.day_seed(20000)) != RU.pool(RU.day_seed(20001)), "今日題組：同一天同一套、隔天換（D1）")
	var t: String = RU.share_text(L, "2026-11-10", 3, 5)
	ok(t.contains("■■■□□") and t.contains("2026-11-10"), "分享格：解開幾題、不劇透")
	var pool: Array = RU.pool(1)
	var PZ = load("res://scripts/game/puzzles.gd")
	ok(pool.size() >= 40 and pool.all(func(id): var m = PZ.get_puzzle(id).get("_m"); return not m is Dictionary or (int(m["ticks"]) <= RU.MAX_TICKS and int(m["rand_pct"]) >= RU.MIN_RAND)), "題庫篩掉太長、太難的（N5）", str(pool.size()))

func test_coop_log_v161() -> void:
	var G = load("res://scripts/ui/screens/game_v16.gd")
	var rows: Array = G.coop_rows([1, 1, 1, 0, 2, 2, 0, -1])
	ok(rows == [[1, 1, true, 0], [2, 2, false, -1]], "接力紀錄：每站 4 欄（D4）")
	var S = load("res://scripts/game/save.gd")
	var run := {"stage": 3, "seed": 1, "gold": 0, "cap": 0, "changes": 3, "pool": 1023, "prev": [], "coop": 1, "clog": [1, 1, 1, 0, 2, 2, 1]}
	ok(S.sanitize_run(run)["clog"] == [], "長度不是 4 的倍數就丟")
	run["clog"] = [1, 1, 1, 0]
	ok(S.sanitize_run(run)["clog"] == [1, 1, 1, 0], "正常的留下")
	run["clog"] = [1, 99, 1, 0]
	ok(S.sanitize_run(run)["clog"] == [], "玩家欄超出範圍丟掉（Codex v161-i1 #5）")
	run["clog"] = [1, 1, 1, 0, 2, 2, 0, 3, 3, 1, 1, 2]
	ok(S.sanitize_run(run)["clog"] == [], "紀錄站數不能超過目前站")

func test_trio_code_v161() -> void:
	var WS = load("res://scripts/game/workshop.gd")
	var TR = load("res://scripts/game/v16_trio.gd")
	var s: Dictionary = TR.sets()[0]
	var code: String = WS.encode_trio(s["foes"], s["sol"])
	ok(code.begins_with("NTP4."), "出題台出三考題（D2）")
	var d: Dictionary = WS.decode(code)
	ok(bool(d["ok"]) and d.has("trio") and (d["trio"]["foes"] as Array).size() == 3, "三考碼解得回來")
	ok(WS.encode_trio([s["foes"][0], s["foes"][1]], s["sol"]) == "", "少一支敵陣不給碼")
	ok(TR.sets().size() == 20, "題組 20 組")

func test_trio_sol3_v161() -> void:
	var TR = load("res://scripts/game/v16_trio.gd")
	for s in TR.sets():
		ok(s.has("sol3") and TR.stars(s, TR.results(s, s["sol3"])) == 3, "每組都有可重現的三星解（A3）：" + str(s["id"]))
		ok(TR.stars(s, TR.results(s, s["sol"])) >= 1, "作者解三場都贏：" + str(s["id"]))

func test_eff_games_seed_v161() -> void:
	var G = load("res://scripts/game/v16_guide.gd")
	var d := {"stats": {"games": 3}, "custom_stats": {"games": 2}, "tutorial": 3}
	G.seed_eff(d)
	ok(int(d["eff_games"]) == 5, "老玩家起點＝標準＋自訂（估計，見 ledger）")
	d["eff_games"] = 9
	G.seed_eff(d)
	ok(int(d["eff_games"]) == 9, "已經有就不動")
	var TR = load("res://scripts/game/v16_trio.gd")
	var s := {"budget": 99}
	var res := [{"ok": true, "rem": 45, "spent": 88}, {"ok": true, "rem": 45, "spent": 88}, {"ok": true, "rem": 44, "spent": 88}]
	ok(TR.stars(s, res) == 1, "剩餘平均 44.67% 不到 45%：不截斷（Codex v161-i1 #10）")
	res[2]["rem"] = 45
	ok(TR.stars(s, res) == 2, "88/99＝88.9% 超過 88%：沒有第三顆星")
