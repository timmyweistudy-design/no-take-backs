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
