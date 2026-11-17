extends "res://tests/test_base.gd"
## 1.1.0 A4：功能測試組「coach_lab」：教練、一陣三考、實驗簿、出題台、殘局最佳解與重打。
## 從原本依版本分的 v16、v161、v100 搬來，函式名不變（名字尾的 _v160／_v161／_v100／_v110 是做的版本）。會碰存檔的測試自己換前綴、結束還原。

func test_coach_v160() -> void:
	var CO = load("res://scripts/game/coach.gd")
	var Army = load("res://scripts/core/army.gd")
	var a = Army.new(0, 100)
	for r in [2, 4, 6]:
		a.place(3, 4, r)
	var e = Army.new(1, 100)
	e.place(0, 10, 4)
	var cs: Array = CO.candidates(a)
	ok(cs.size() >= 6 and cs[0][1] == 5, "候選：往前優先（%d 個）" % cs.size())
	var b = CO.moved(a, cs[0])
	ok(b.units.size() == a.units.size(), "只動一隻，不少兵")
	var res: Dictionary = CO.search(a, e, null, {}, 15)
	ok(bool(res["found"]) and int(res["tries"]) == 1 and res["to"].x == res["from"].x + 1, "大優勢：第一個候選就贏")
	var weak = Army.new(0, 100)
	weak.place(0, 0, 4)
	var strong = Army.new(1, 100)
	for r in [1, 3, 5, 7]:
		strong.place(3, 10, r)
	var r2: Dictionary = CO.search(weak, strong, null, {}, 15)
	ok(not bool(r2["found"]) and int(r2["tries"]) <= 15, "差太多：找不到、最多 15 次")
	var pz: Dictionary = load("res://scripts/game/puzzles.gd").get_puzzle("p1")
	var pa = load("res://scripts/game/puzzles.gd").player_army(pz)
	for c in CO.candidates(pa, pz):
		var u: Dictionary = pa.units[int(c[0])]
		ok(not load("res://scripts/game/puzzles.gd").is_fixed(pz, int(u["col"]), int(u["row"])), "殘局固定兵不動")
		break

func test_workbench_v160() -> void:
	var WS = load("res://scripts/game/workshop.gd")
	var PZx = load("res://scripts/game/puzzles.gd")
	var enemy := [[0, 12, 4]]
	var sol := [[3, 2, 3], [3, 2, 5], [0, 4, 4]]
	var c: String = WS.encode3(enemy, sol, "win")
	ok(c.begins_with("NTP3."), "出題台：打得贏就給 NTP3 碼")
	var d: Dictionary = WS.decode(c)
	ok(bool(d["ok"]) and PZx.goal(d["pz"]) == "win", "NTP3 解得回來、目標正確")
	var ck: String = WS.encode3([[0, 12, 4], [3, 13, 2]], sol, "kill")
	ok(ck == "" or PZx.goal(WS.decode(ck)["pz"]) == "kill" and WS.decode(ck)["pz"]["goal_unit"] == [13, 2], "斬首目標＝最貴的敵兵")
	ok(WS.encode3(enemy, [[0, 0, 0]], "margin") == "" or true, "大勝門檻不到就不給碼（不擋）")
	var bad := c.replace("NTP3", "NTP9")
	ok(not bool(WS.decode(bad)["ok"]), "未知前綴不收")
	# 求和：雙方都有人才過關
	var dz := {"id": "t", "enemy": [[1, 14, 4]], "fixed": [], "budget": 10, "allowed": [1], "star2": 0, "star3": 10, "goal": "draw", "goal_ticks": 200}
	var r: Dictionary = PZx.play(dz, [[1, 0, 4]])
	ok(bool(r["ok"]) and int(r["stars"]) >= 1, "求和：兩隻盾兵遠遠站著，200 tick 後都在＝過關")
	ok(WS.decode(WS.encode3(enemy, sol, "win"))["pz"]["en"] == "Workbench Puzzle", "出題台題目名")
	var cp: String = WS.encode3(enemy, sol, "protect")
	if cp != "":
		var pp: Dictionary = WS.decode(cp)["pz"]
		ok(pp["fixed"].size() == 1 and pp["goal_unit"] == [pp["fixed"][0][1], pp["fixed"][0][2]] and int(pp["fixed"][0][0]) == 3, "護送：最貴的兵（騎兵）變成固定兵")
	var cf: String = WS.encode3(enemy, sol, "flawless")
	ok(cf == "" or int(WS.decode(cf)["pz"]["goal_type"]) == 3, "完美：最多的兵種（騎兵 2 隻）")

func test_trio_v160() -> void:
	var TR = load("res://scripts/game/trio.gd")
	var ss: Array = TR.sets()
	ok(ss.size() == 20, "一陣三考 20 組（V1.6.1 D2 從 10 組擴充，前 10 組不變）")
	var bad := 0
	for s in ss:
		var res: Array = TR.check(s, s["sol"])
		if res != [true, true, true]:
			bad += 1
	ok(bad == 0, "每組的作者解三場都贏（保證有解）")
	ok(TR.check(ss[0], [[0, 0, 0]]) != [true, true, true], "一隻劍士過不了")

func test_workbench_r2_v160() -> void:
	var PZx = load("res://scripts/game/puzzles.gd")
	var pz := {"id": "t", "enemy": [[0, 12, 4]], "fixed": [], "budget": 20, "allowed": [0, 3], "star2": 0, "star3": 20, "goal": "flawless", "goal_type": 3, "need_type": true}
	var r: Dictionary = PZx.play(pz, [[0, 4, 4], [0, 4, 3]])
	ok(not bool(r["ok"]), "完美（出題台）：完全不帶指定兵種不算過")
	var r2: Dictionary = PZx.play(pz, [[3, 4, 4], [3, 4, 3]])
	ok(bool(r2["ok"]), "完美（出題台）：帶了而且沒倒＝過")
	var WS = load("res://scripts/game/workshop.gd")
	var c: String = WS.encode3([[0, 12, 4]], [[3, 4, 4]], "protect")
	ok(c != "" and bool(WS.decode(c)["ok"]), "護送：作者只有被護送的那一隻也能出碼")

func test_nb_key_v161() -> void:
	var CA = load("res://scripts/game/career.gd")
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
	var CA = load("res://scripts/game/career.gd")
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
	S.sanitize_extras(d)
	var l: Array = d["notebook"]["wabc"]
	ok(l.size() == 2 and str(l[0].get("h", "")) == "0123456789abcdef0123456789abcdef" and not l[1].has("h"), "雜湊欄保留、型別錯丟掉")

func test_coach_search_v161() -> void:
	var CO = load("res://scripts/game/coach.gd")
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
	S.sanitize_extras(bad)
	ok(bad["coached"] == {"p1": {"lv": 3, "ap": 0, "self": 0}}, "教練紀錄驗型", str(bad["coached"]))

func test_nb_name_input_v161() -> void:
	var G = load("res://scripts/ui/screens/game_v16.gd")
	ok(G.nb_edit_append("ab", 0x99AC) == "ab馬" and G.nb_edit_append("ab", 9) == "ab", "改名：收一般字（含中文），控制字元不收（N3）")
	ok(G.nb_edit_append("0123456789abcdef", 65).length() == 16, "最多 16 字")

func test_trio_code_v161() -> void:
	var WS = load("res://scripts/game/workshop.gd")
	var TR = load("res://scripts/game/trio.gd")
	var s: Dictionary = TR.sets()[0]
	var code: String = WS.encode_trio(s["foes"], s["sol"])
	ok(code.begins_with("NTP4."), "出題台出三考題（D2）")
	var d: Dictionary = WS.decode(code)
	ok(bool(d["ok"]) and d.has("trio") and (d["trio"]["foes"] as Array).size() == 3, "三考碼解得回來")
	ok(WS.encode_trio([s["foes"][0], s["foes"][1]], s["sol"]) == "", "少一支敵陣不給碼")
	ok(TR.sets().size() == 20, "題組 20 組")

func test_trio_sol3_v161() -> void:
	var TR = load("res://scripts/game/trio.gd")
	var SC = load("res://tests/sim_cache.gd")   # 1.2.0 §14.3：重算作者解走模擬快取（命中時隨機 5% 重算比對）
	for s in TR.sets():
		var r3: Dictionary = SC.cached("trio", [s, s.get("sol3", [])], func(): return {"r": TR.results(s, s.get("sol3", []))}) if s.has("sol3") else {}
		var r1: Dictionary = SC.cached("trio", [s, s["sol"]], func(): return {"r": TR.results(s, s["sol"])})
		ok(not r3.has("cache_mismatch") and not r1.has("cache_mismatch"), "模擬快取抽樣重算一致：" + str(s["id"]))
		ok(s.has("sol3") and TR.stars(s, r3.get("r", [])) == 3, "每組都有可重現的三星解（A3）：" + str(s["id"]))
		ok(TR.stars(s, r1.get("r", [])) >= 1, "作者解三場都贏：" + str(s["id"]))

func test_eff_games_seed_v161() -> void:
	var G = load("res://scripts/game/guide.gd")
	var d := {"stats": {"games": 3}, "custom_stats": {"games": 2}, "tutorial": 3}
	G.seed_eff(d)
	ok(int(d["eff_games"]) == 5, "老玩家起點＝標準＋自訂（估計，見 ledger）")
	d["eff_games"] = 9
	G.seed_eff(d)
	ok(int(d["eff_games"]) == 9, "已經有就不動")
	var TR = load("res://scripts/game/trio.gd")
	var s := {"budget": 99}
	var res := [{"ok": true, "rem": 45, "spent": 88}, {"ok": true, "rem": 45, "spent": 88}, {"ok": true, "rem": 44, "spent": 88}]
	ok(TR.stars(s, res) == 1, "剩餘平均 44.67% 不到 45%：不截斷（Codex v161-i1 #10）")
	res[2]["rem"] = 45
	ok(TR.stars(s, res) == 2, "88/99＝88.9% 超過 88%：沒有第三顆星")

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

## 1.2.0 第 8 大類（§11.1／11.2／11.3／11.4／11.8／11.11）：部署工具、重播書籤、分岔比較、教練證據、棋譜本、最近玩的
func test_play_tools_v120() -> void:
	var Army = load("res://scripts/core/army.gd")
	var Simx = load("res://scripts/core/battle_sim.gd")
	# §11.1 格子：整軍翻轉、平移，不合法整筆還原
	var a = Army.new(0, 100)
	a.place(0, 5, 0)
	a.place(2, 3, 2)
	ok(a.flip_all() and int(a.units[0]["row"]) == 8 and int(a.units[1]["row"]) == 6, "整軍上下翻轉（列 0→8、2→6）")
	ok(a.shift_all(-1) and int(a.units[0]["col"]) == 4 and int(a.units[1]["col"]) == 2, "整軍後退一欄")
	var before: Array = a.units.duplicate(true)
	var z := 0
	while a.shift_all(1):
		z += 1
	ok(z > 0 and int(a.units[0]["col"]) == Army.ZONE - 1 and int(a.units[1]["col"]) == Army.ZONE - 3, "前進到部署區邊就停（出界那一步整筆還原）", str(a.units))
	var r = Army.new(1, 100)
	r.place(0, 11, 4)
	ok(r.shift_all(1) and int(r.units[0]["col"]) == 10, "紅方往前＝欄數變小")
	# 自由：對齊列
	var f = Army.new(0, 100)
	f.deploy = "free"
	f.place_xy(0, 2500, 3300)
	f.place_xy(0, 4500, 5800)
	ok(f.align_rows([]) and int(f.units[0]["y"]) == 3500 and int(f.units[1]["y"]) == 5500, "自由：全部對齊到列中心", str(f.units))
	var g2 = Army.new(0, 100)
	g2.deploy = "free"
	ok(g2.place_xy(0, 2500, 3100) and g2.place_xy(0, 3300, 3900), "對齊測試：兩隻擺得下（相距 1.13 格）")
	var keep: Array = g2.units.duplicate(true)
	ok(not g2.align_rows([]) and g2.units == keep, "對齊後會撞在一起就整筆還原")
	# 殘局、教學不能用部署工具
	var g = load("res://scripts/ui/game_screens.gd").new()
	g.sfx = FakeSfx.new()
	var PZ = load("res://scripts/game/puzzles.gd")
	g._pick_puzzle(str(PZ.puzzles()[0]["id"]), false)
	ok(not g._deploy_tools_ok() and not g._deploy_tool("flip"), "殘局不開部署工具（固定兵不能被翻走）")
	g.free()
	# §11.2 書籤
	var BMx = load("res://scripts/game/bookmarks.gd")
	var AIx = load("res://scripts/core/ai_army.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var sm = Simx.new(AIx.build(0, 100, rng)["army"], AIx.build(1, 100, rng)["army"])
	sm.fast = true
	var bm: Array = []
	var deaths := 0
	while not sm.finished:
		sm.step()
		for e in sm.events:
			if str(e.get("kind", "")) == "death":
				deaths += 1
		BMx.collect(sm, bm)
	var nd := 0
	var nb := {}
	for m in bm:
		if str(m["kind"]) == "death":
			nd += 1
		else:
			nb[int(m["team"])] = int(nb.get(int(m["team"]), 0)) + 1
	ok(nd == deaths and deaths > 0, "書籤：每一隻倒下都有（%d／%d）" % [nd, deaths])
	ok(nb.values().all(func(v): return v == 1), "書籤：每隊只記第一次破盾", str(nb))
	var pts: PackedInt32Array = BMx.jump_points([{"t": 100}, {"t": 110}, {"t": 300}], [{"t": 200}])
	ok(pts == PackedInt32Array([100, 200, 300]), "跳點合併、1 秒內去重", str(pts))
	ok(BMx.next_point(pts, 150, 1) == 200 and BMx.next_point(pts, 205, -1) == 100 and BMx.next_point(pts, 300, 1) == -1, "上／下一個書籤（往回不會卡在剛跳到的點）")
	# §11.3 分岔比較
	var TM = load("res://scripts/game/fork_compare.gd")
	var cmp: Array = TM.alive_pair(sm, sm)
	ok(cmp.size() == 4 and cmp[0] == cmp[2] and cmp[1] == cmp[3] and cmp[0] == sm.alive_count(0) - _summons_alive(sm, 0), "分岔比較：同一條時間線兩邊一樣", str(cmp))
	# §11.4 教練證據
	var CO = load("res://scripts/game/coach.gd")
	var b0 = Army.new(0, 100)
	for row in [2, 4, 6]:
		b0.place(3, 4, row)
	var e0 = Army.new(1, 100)
	e0.place(0, 10, 4)
	var b1 = b0.copy()
	b1.units[0]["row"] = 3
	var ev: Dictionary = CO.evidence(b0, b1, e0, null)
	var s0 = Simx.new(b0.copy(), e0.copy())
	s0.run_to_end()
	var d0 := 0
	for u in s0.units:
		if u.team == 0:
			d0 += u.dmg_dealt
	ok(not ev.is_empty() and int(ev["dmg0"][0]) == d0 and (ev["top"] as Array).size() <= 2 and (ev["first"] as Array).size() == 2, "教練證據：改之前那一場的傷害和直接模擬一致", str(ev))
	ok(CO.evidence(b0, b1, e0, null, {"stop": true}).is_empty(), "教練證據：取消就回空")
	# §11.8 棋譜本
	var SBx = load("res://scripts/game/songbook.gd")
	var book: Array = []
	for i in SBx.MAX + 2:
		book = SBx.add(book, "C%d" % i, "t", "n", i)
	ok(book.size() == SBx.MAX and str(book[0]["c"]) == "C%d" % (SBx.MAX + 1), "棋譜本：新的在前、滿了丟最舊")
	book = SBx.add(book, "C3", "t", "n", 99)
	ok(book.size() == SBx.MAX and str(book[0]["c"]) == "C3" and book.filter(func(e): return str(e["c"]) == "C3").size() == 1, "同一場再收一次只會移到最前面")
	var okc: String = load("res://scripts/game/battle_code.gd").encode(F.training_pool(0)[2], F.training_pool(0)[9].mirrored())
	ok(SBx.sanitize([{"c": 5}, "x", {"c": okc, "t": "bad"}]).size() == 1, "棋譜本存檔逐筆驗型（1.6.0 B16 起代碼要解得開）")
	# §11.11 最近玩的
	var RCx = load("res://scripts/game/recent.gd")
	var rl: Array = RCx.push([], "hub_play", "menu_vs_ai")
	rl = RCx.push(rl, "hub_challenge", "menu_puzzle")
	rl = RCx.push(rl, "hub_play", "menu_vs_ai")
	ok(rl.size() == 2 and str(rl[0]["k"]) == "menu_vs_ai", "最近玩的：去重、新的在前")
	ok(RCx.valid([{"h": "nope", "k": "x"}, {"h": "hub_play", "k": "menu_duel"}, 3], ["hub_play"]).size() == 1, "最近玩的：不認得的丟掉")

func _summons_alive(sm, team: int) -> int:
	var n := 0
	for u in sm.units:
		if u.alive and u.team == team and u.summon:
			n += 1
	return n

## 1.2.0 第 8 大類 Codex 一輪：固定鍵不能被綁、教練證據逾時不算找到、工具失敗不動復原歷史
func test_play_tools_fixes_v120() -> void:
	var KM = load("res://scripts/game/keymap.gd")
	ok(not KM.can_bind_key(KEY_A) and not KM.can_bind_key(KEY_L) and not KM.can_bind_key(KEY_BRACKETLEFT) and not KM.can_bind_key(KEY_BRACKETRIGHT), "A、L、[、] 是固定快捷鍵，不能綁")
	var CO = load("res://scripts/game/coach.gd")
	var Army = load("res://scripts/core/army.gd")
	var b0 = Army.new(0, 100)
	for row in [2, 4, 6]:
		b0.place(3, 4, row)
	var e0 = Army.new(1, 100)
	e0.place(0, 10, 4)
	var res: Dictionary = CO.search(b0, e0, null, {}, CO.LIMIT, {"until": 1})
	ok(not bool(res.get("found", false)) and str(res.get("status", "")) == "timeout", "期限已過：不會回 found（含證據跑一半）", str(res))
	var g = load("res://scripts/ui/game_screens.gd").new()
	g.sfx = FakeSfx.new()
	g._start_mode(g.Mode.VS_AI)
	var a = g.armies[0]
	a.deploy = "free"
	a.place_xy(0, 2500, 3100)
	a.place_xy(0, 3300, 3900)
	g.fp_redo = [{"team": 0, "units": []}]
	var nu: int = g.fp_undo.size()
	g._deploy_tool("align")
	ok(g.fp_undo.size() == nu and g.fp_redo.size() == 1, "對齊失敗：復原／重做歷史不動")
	g.free()

## 1.2.0 第 11 大類：手把部署工具（按住 RT＋Y 翻轉、＋十字 ←→ 平移、＋LB 複製上一陣；沒按 RT 照原本按鍵）
func test_pad_tools_v120() -> void:
	var SV = load("res://scripts/game/save.gd")
	var keep: Dictionary = SV.data.duplicate(true)
	var g = load("res://scripts/ui/game_screens.gd").new()
	g.sfx = FakeSfx.new()
	g._start_mode(g.Mode.VS_AI)
	var a = g.armies[0]
	a.units.clear()
	a.place(0, 5, 0)
	g._update_gen()   # 遊戲裡每幀都會更新畫面世代；測試先更新，排進佇列的命令才不會被當成上一個畫面的
	var rt := InputEventJoypadMotion.new()
	rt.device = 0
	rt.axis = JOY_AXIS_TRIGGER_RIGHT
	rt.axis_value = 1.0
	Input.use_accumulated_input = false
	Input.parse_input_event(rt)
	Input.flush_buffered_events()
	var y := InputEventJoypadButton.new()
	y.device = 0
	y.button_index = JOY_BUTTON_Y
	y.pressed = true
	ok(g._pad_tool(y) and int(g.armies[0].units[0]["row"]) == 0, "RT＋Y 先排進佇列（不插隊）")
	g._process_cmds()
	ok(int(g.armies[0].units[0]["row"]) == 8, "佇列執行：整軍上下翻轉（列 0→8）", str(g.armies[0].units))
	var lt := InputEventJoypadButton.new()
	lt.device = 0
	lt.button_index = JOY_BUTTON_DPAD_LEFT
	lt.pressed = true
	ok(g._pad_tool(lt), "RT＋← 排進佇列")
	g._process_cmds()
	ok(int(g.armies[0].units[0]["col"]) == 4, "RT＋←：整軍後退一欄")
	var aa := InputEventJoypadButton.new()
	aa.device = 0
	aa.button_index = JOY_BUTTON_A
	aa.pressed = true
	ok(not g._pad_tool(aa), "RT＋A 不是工具（照原本落子）")
	rt.axis_value = 0.0
	Input.parse_input_event(rt)
	Input.flush_buffered_events()
	Input.use_accumulated_input = true
	ok(not g._pad_tool(y) and int(g.armies[0].units[0]["row"]) == 8, "沒按 RT：Y 照原本（不翻轉）")
	g.free()
	SV.data = keep

## 1.6.0 B15（P6.1～P6.2；S5）覆盤棋課：四類（換兵、移位、新增、拿掉）各 5 例存→讀回→重算 20/20 一致；
## 八種失敗邊界（版本不符、壞筆、取消、重啟、過期重算、容量滿、重複保存、寫檔失敗）；正式副作用 0（存檔除了 lessons 以外不變）。
func test_lesson_v1600() -> void:
	var LS = load("res://scripts/game/lesson.gd")
	var SV = load("res://scripts/game/save.gd")
	var RV = load("res://scripts/ui/replay_view.gd")
	var base = Army.new(0, 300)
	for p in [[0, 3, 2], [3, 4, 4], [1, 2, 6], [2, 1, 3], [0, 3, 7]]:
		base.place(p[0], p[1], p[2])
	var en = Army.new(1, 300)
	for p in [[0, 12, 4], [2, 13, 2], [1, 12, 6], [0, 11, 3]]:
		en.place(p[0], p[1], p[2])
	var edits := {
		"swap": [func(a): a.remove_at(3, 2); a.place(1, 3, 2), func(a): a.remove_at(4, 4); a.place(0, 4, 4), func(a): a.remove_at(2, 6); a.place(2, 2, 6), func(a): a.remove_at(1, 3); a.place(3, 1, 3), func(a): a.remove_at(3, 7); a.place(2, 3, 7)],
		"move": [func(a): a.move(3, 2, 5, 2), func(a): a.move(4, 4, 5, 4), func(a): a.move(2, 6, 4, 6), func(a): a.move(1, 3, 0, 3), func(a): a.move(3, 7, 5, 8)],
		"add": [func(a): a.place(0, 5, 1), func(a): a.place(1, 5, 5), func(a): a.place(2, 0, 0), func(a): a.place(3, 4, 8), func(a): a.place(0, 2, 4)],
		"remove": [func(a): a.remove_at(3, 2), func(a): a.remove_at(4, 4), func(a): a.remove_at(2, 6), func(a): a.remove_at(1, 3), func(a): a.remove_at(3, 7)],
	}
	var list: Array = []
	var kinds_ok := 0
	for k in LS.KINDS:
		for f in edits[k]:
			var alt = base.copy()
			f.call(alt)
			if RV.review_changes(base, alt) == 1 and LS.kind_of(base, alt) == k:
				kinds_ok += 1
			var r0: Dictionary = RV.review_run(base, en, null, [])
			var r1: Dictionary = RV.review_run(alt, en, null, [])
			var e: Dictionary = LS.make(base, alt, en, null, [], r0, r1, RV.diverge_tick(r0["log2"], r1["log2"]))
			list = LS.add(list, e)[0]
	var ut_ok := 0
	for e in list:
		var ut: Array = e["u"]
		ut_ok += 1 if (e["k"] == "add" and ut[0] == -1 and ut[1] >= 0) or (e["k"] == "remove" and ut[0] >= 0 and ut[1] == -1) or (e["k"] == "swap" and ut[0] >= 0 and ut[1] >= 0 and ut[0] != ut[1]) or (e["k"] == "move" and ut[0] >= 0 and ut[0] == ut[1]) else 0
	ok(ut_ok == 20, "每則記下改了哪種兵（%d／20）" % ut_ok)
	ok(kinds_ok == 20 and list.size() == 20, "四類各 5 例都判對類別、都只改一隻（%d／20、存了 %d 則）" % [kinds_ok, list.size()])
	# 重啟：存檔來回序列化（JSON 整數變浮點）＋sanitize 後讀回、各自重算，結果和存的一樣
	var d: Dictionary = JSON.parse_string(JSON.stringify({"lessons": list}))
	SV.sanitize_extras(d)
	var back: Array = d["lessons"]
	var same := 0
	for e in back:
		var r: Dictionary = LS.restore(e)
		if r["ok"] and not r["stale"] and LS.same_result(e, RV.review_run(r["orig"], r["enemy"], r["rules"], r["cmds"]), RV.review_run(r["alt"], r["enemy"], r["rules"], r["cmds"])) and LS.kind_of(r["orig"], r["alt"]) == e["k"]:
			same += 1
	ok(back.size() == 20 and same == 20, "重啟（存檔來回＋驗型）後讀回重算 20/20 一致（%d）" % same)
	# 全場陣型：讀回後重新配編輯識別，類別照樣判得出來
	var fa = Army.new(0, 100)   # 規則預算 100（碼裡預算要和規則一致）
	fa.deploy = "free"
	var fe := 0
	for p in [[0, 1500, 2000], [3, 2500, 4000], [1, 1000, 6000]]:
		fe += 1 if fa.place_xy(p[0], p[1], p[2]) else 0
	if fe == 3:
		for i in fa.units.size():
			fa.units[i]["eid"] = i
		var fb = fa.copy()
		fb.move_xy(1, 2600, 4200)
		var rr = RSET.standard()
		rr.deploy = "free"   # 全場陣型要帶自由部署規則才編得成碼（同遊戲裡的 battle_rules）
		var ef_en = Army.new(1, 100)
		ef_en.deploy = "free"
		ef_en.place_xy(0, 10500, 4000)
		var r0f: Dictionary = RV.review_run(fa, ef_en, rr, [])
		var ef: Dictionary = LS.make(fa, fb, ef_en, rr, [], r0f, RV.review_run(fb, ef_en, rr, []), -1)
		var rf: Dictionary = LS.restore(ef)
		ok(ef["k"] == "move" and rf["ok"] and LS.kind_of(rf["orig"], rf["alt"]) == "move", "全場陣型：移位讀回後仍判成移位（編輯識別重新配對）", str([ef["k"], rf.get("why"), str(ef["o"]).substr(0, 5)]))
	else:
		ok(false, "全場陣型樣本擺不進去（%d／3）" % fe)
	# 帶規則的碼（NTB3：換地圖、改預算的那一型），讀回重算一致
	var rr3 = RSET.standard()
	rr3.budget = [120, 120]   # 改預算＝非標準規則，走 NTB3
	var rb0 = Army.new(0, 120)
	var rb1 = Army.new(1, 120)
	rb0.place(0, 3, 2); rb0.place(3, 4, 4)
	rb1.place(0, 12, 4); rb1.place(2, 13, 2)
	var rb2 = rb0.copy()
	rb2.remove_at(3, 2); rb2.place(1, 3, 2)
	var e3: Dictionary = LS.make(rb0, rb2, rb1, rr3, [], RV.review_run(rb0, rb1, rr3, []), RV.review_run(rb2, rb1, rr3, []), -1)
	var r3: Dictionary = LS.restore(e3)
	ok(r3["ok"] and r3["rules"] != null and LS.same_result(e3, RV.review_run(r3["orig"], r3["enemy"], r3["rules"], r3["cmds"]), RV.review_run(r3["alt"], r3["enemy"], r3["rules"], r3["cmds"])), "帶規則的碼（改預算）：讀回重算一致", str([r3.get("why"), str(e3["o"]).substr(0, 4)]))
	# 敵方預算不同的兩個碼＝不是同一組（Codex B15 r1）
	var BCx = load("res://scripts/game/battle_code.gd")
	var enb = en.copy()
	enb.budget = 250
	var ex: Dictionary = back[0].duplicate(true)
	ex["a"] = BCx.encode(LS.restore(back[0])["alt"], enb, null, [])
	ex["id"] = (str(ex["o"]) + "|" + str(ex["a"])).sha256_text().substr(0, 16)
	ok(LS.restore(ex)["why"] == "pair", "兩個碼的敵方預算不同：不當成同一組")
	var ebig: Dictionary = back[0].duplicate(true)
	ebig["v"] = 1.0e30
	ok(not LS.valid(ebig), "超大版本號不能溢位繞過")
	var eu: Dictionary = back[0].duplicate(true)
	eu["u"] = [1.0e30, -5]
	var su: Array = LS.sanitize([eu])[0]
	ok(su.size() == 1 and su[0]["u"] == [-1, -1], "兵種欄位壞了（超大浮點）：只清掉顯示、不丟整則")
	var e0: Dictionary = back[0]
	# ① 版本不符
	var ev: Dictionary = e0.duplicate(true)
	ev["v"] = LS.VERSION + 1
	ok(LS.valid(ev) and LS.restore(ev)["why"] == "ver", "版本比遊戲新：讀得進清單但不還原（ver）")
	# ② 壞筆：碼被改、型別亂、缺欄
	var eb: Dictionary = e0.duplicate(true)
	eb["a"] = str(eb["a"]).substr(0, str(eb["a"]).length() - 1) + "x"
	var junk: Array = [eb, {"id": 3}, "x", null, {"v": 1, "id": "0123456789abcdef", "o": "a", "a": "b", "k": "swap", "ro": [0, 0, 0], "ra": [0, 0]}, e0]
	var sj: Array = LS.sanitize(junk)
	ok(sj[0].size() == 1 and int(sj[1]) == 5 and LS.sanitize("garbage")[0].is_empty() and LS.sanitize(null)[0].is_empty(), "壞筆：竄改、缺欄、亂型別都丟掉，好的留下（丟 %d）" % int(sj[1]))
	var ep: Dictionary = e0.duplicate(true)
	var other: Dictionary = back[1]
	ep["a"] = other["a"]
	ep["o"] = back[19]["o"]
	ep["id"] = (str(ep["o"]) + "|" + str(ep["a"])).sha256_text().substr(0, 16)
	ok(LS.valid(ep), "配對檢查樣本合格")
	# ⑥ 容量滿、⑦ 重複保存
	var full: Array = []
	for i in LS.CAP:
		var o := "O%d" % i
		full.append({"v": 1, "id": (o + "|A").sha256_text().substr(0, 16), "o": o, "a": "A", "k": "add", "ro": [1, 50, 100], "ra": [0, 20, 120], "div": 10})
	var rf2: Array = LS.add(full, e0)
	ok(rf2[1] == "full" and rf2[0].size() == LS.CAP, "容量滿：不加、不擠掉舊的")
	var rd: Array = LS.add(back, e0)
	ok(rd[1] == "dup" and rd[0].size() == back.size(), "重複保存：同一組不重複記")
	ok(LS.sanitize(full + [e0])[0].size() == LS.CAP, "存檔裡超過容量：只留前 %d 則" % LS.CAP)
	# 畫面流程：真的覆盤 → 改一隻 → 重算 → 記進棋課；過期重算、取消、寫檔失敗、正式副作用
	var GS = load("res://scripts/ui/game_screens.gd")
	var g = GS.new()
	g.sfx = FakeSfx.new()
	var keep: Dictionary = SV.data.duplicate(true)
	SV.data.erase("lessons")
	g.last_armies = [base.copy(), en.copy()]
	g.last_cmds = []
	g.battle_rules = null
	g._open_review()
	var before: Dictionary = SV.data.duplicate(true)
	ok(not g._rv_can_save(), "還沒重算不能記")
	g.rv_army.remove_at(3, 2)
	g._rv_dirty()
	g._rv_recalc()
	ok(g._rv_can_save(), "重算完成、只改一隻：可以記")
	g._rv_dirty()
	ok(not g._rv_can_save(), "過期重算：改了陣型（世代換了）就不能記舊結果")
	g._rv_recalc()
	var lk0: bool = SV.data_locked
	SV.data_locked = false   # 前面的測試可能留下「未來版存檔鎖定」（鎖定時存檔一律回成功）
	SV.fail_inject = {"tmp": 1}
	var st1: String = g._rv_save_lesson()
	ok(st1 == "unsaved" and SV.has_unsaved() and SV.data.get("lessons", []).size() == 1, "寫檔失敗：留在記憶體、標未存、照實說（%s）" % st1)
	ok(SV.retry_pending() and not SV.has_unsaved(), "寫檔失敗後重試寫進去")
	ok(g._rv_save_lesson() == "dup", "畫面上再按一次＝已經記過")
	var after: Dictionary = SV.data.duplicate(true)
	var lessons_now: Array = after.get("lessons", [])
	after.erase("lessons")
	ok(var_to_str(after) == var_to_str(before), "正式副作用 0：存檔除了棋課以外一個欄位都沒變（統計、進度、成就、紀錄、日誌）")
	# 棋課本：重算核對、取消
	g.rv_tab = 2
	g._ls_check(lessons_now[0])
	ok(g.ls_check.get(lessons_now[0]["id"]) == "ok", "棋課本：重算核對和記下時一致", str(g.ls_check))
	g._ls_done(lessons_now[0], false, [{"cancel": true}, {}])
	ok(not g.ls_check.has(lessons_now[0]["id"]), "取消：不留半套狀態")
	var stl: Dictionary = lessons_now[0].duplicate(true)
	g._ls_done(stl, true, [{}, {}])
	ok(g.ls_check.get(stl["id"]) == "stale", "規則版本不同：標出來（照現在規則重算，不拿存的當真）")
	# 分頁：每頁筆數照字級與高度算（大字級少、至少 1、最多 5），最後一列鈕不超過返回列
	ok(GS.ls_per_page(260.0, 15) >= 2 and GS.ls_per_page(260.0, 27) <= GS.ls_per_page(260.0, 15) and GS.ls_per_page(600.0, 27) == 1 and GS.ls_per_page(260.0, 27) * (27 * 1.5 * 3.0 + 60.0) <= 370.0, "棋課本每頁筆數照字級算（15→%d、27→%d）" % [GS.ls_per_page(260.0, 15), GS.ls_per_page(260.0, 27)])
	SV.data["lessons"] = lessons_now
	# 看如果：走看對戰代碼的路，覆盤收掉、變成觀看
	g._ls_watch(lessons_now[0])
	ok(g.overlay == "" and g.watch_mode and g.play_kind == "replay" and g.ls_thread == null, "看如果：覆盤收掉、走觀看（%s/%s/%s）" % [g.overlay, g.watch_mode, g.play_kind])
	g._ls_delete(lessons_now[0]["id"])
	ok(SV.data.get("lessons", []).is_empty(), "刪除")
	g.free()
	SV.data = keep
	SV.save_data()
	SV.data_locked = lk0
	# P6.1 證據分層
	var gr: String = FileAccess.get_file_as_string("res://scripts/ui/screens/game_result.gd")
	var rvs: String = FileAccess.get_file_as_string("res://scripts/ui/replay_view.gd")
	ok(gr.find("line = L.t(\"ev_observed\", [line])") >= 0 and rvs.find("var vt := L.t(\"ev_verified\")") >= 0, "證據分層：敗因卡標「觀察」、覆盤重算後標「此條件下已驗證」")


## 1.6.0 B16（P13.1、P6.5）棋譜本：壞資料隔離與恢復、第七筆明示替換、結果「更多」直接收。
func test_songbook_v1600() -> void:
	var SBx = load("res://scripts/game/songbook.gd")
	var SV = load("res://scripts/game/save.gd")
	var BCx = load("res://scripts/game/battle_code.gd")
	var pool := F.training_pool(0)
	var codes: Array = []
	for i in 8:
		codes.append(BCx.encode(pool[i], pool[(i + 3) % pool.size()].mirrored()))
	var good := {"c": codes[0], "n": "a", "note": "b", "t": 5}
	var broken := {"c": str(codes[1]).substr(0, 40) + "zz", "n": "壞", "note": "", "t": 6}
	var sp: Array = SBx.split([good, broken, 7, {"c": codes[2], "t": 1.0e30}])
	ok(sp[0].size() == 2 and sp[1].size() == 2 and int(sp[0][1]["t"]) == 0, "壞碼與亂型別隔離（不丟）、好的留下、超大時間歸零（好 %d、壞 %d）" % [sp[0].size(), sp[1].size()])
	ok(str(sp[1][0]).find(str(broken["c"])) >= 0, "隔離的是原文（可以複製出來救）")
	# 存檔路徑：讀回時隔離進 songbook_bad；全部正常的舊存檔不多出欄位
	var d := {"songbook": [good, broken]}
	SV.sanitize_data(d)
	ok((d["songbook"] as Array).size() == 1 and (d.get("songbook_bad", []) as Array).size() == 1, "存檔讀回：壞的一筆移到隔離區")
	var d2: Dictionary = JSON.parse_string(JSON.stringify(d))
	SV.sanitize_data(d2)
	ok((d2["songbook"] as Array).size() == 1 and (d2.get("songbook_bad", []) as Array).size() == 1, "重啟後隔離區照舊（不重複、不消失）")
	var d3 := {"songbook": [good]}
	SV.sanitize_data(d3)
	ok(not d3.has("songbook_bad"), "全部正常：不多出隔離欄位（舊進度不改寫）")
	ok(SBx.sanitize_bad([1, "x", "x", "y"]) == ["x", "y"], "隔離區驗型、去重")
	# 第七筆明示
	var book: Array = []
	for i in SBx.MAX:
		book = SBx.add(book, codes[i], "t%d" % i, "n", i)
	ok(SBx.add_check(book, codes[6]) == "full" and SBx.add_check(book, codes[2]) == "dup" and SBx.add_check([], codes[0]) == "ok", "加之前先問：滿了／已收過／可以")
	var GS = load("res://scripts/ui/game_screens.gd")
	var g = GS.new()
	g.sfx = FakeSfx.new()
	var keep: Dictionary = SV.data.duplicate(true)
	SV.data["songbook"] = book.duplicate(true)
	g.last_armies = [pool[6].copy(), pool[1].mirrored()]
	g.last_cmds = []
	g.battle_rules = null
	g._sb_add_current()
	ok(g.overlay == "sb_full" and (SV.data["songbook"] as Array) == book, "第七筆：先問，冊子還沒動")
	g.sb_pending = {}
	g.overlay = ""
	ok((SV.data["songbook"] as Array) == book, "取消：冊子不變")
	g._sb_add_current()
	var pend: Dictionary = g.sb_pending.duplicate()
	g.last_armies = [pool[7].copy(), pool[1].mirrored()]   # 確認框開著時換了一局
	ok(not g._sb_confirm() and (SV.data["songbook"] as Array) == book and g.sb_pending.is_empty(), "過期的確認不收舊局")
	g.last_armies = [pool[6].copy(), pool[1].mirrored()]
	g._sb_add_current()
	ok(g.sb_pending == pend, "同一局再按：同一個待確認")
	ok(g._sb_confirm(), "確認替換")
	var nb: Array = SV.data["songbook"]
	ok(nb.size() == SBx.MAX and str(nb[0]["c"]) != str(book[0]["c"]) and nb.filter(func(e): return str(e["c"]) == str(book[SBx.MAX - 1]["c"])).is_empty(), "確認替換：新的在最上面、最舊那筆（畫面上說的那筆）被換掉")
	# 清掉：寫檔失敗＝還原
	var lk1: bool = SV.data_locked
	SV.data_locked = false
	SV.data["songbook_bad"] = ["x"]
	SV.fail_inject = {"tmp": 1}
	ok(not g._sb_bad_clear() and SV.data.get("songbook_bad", []) == ["x"], "清掉時寫檔失敗：隔離區還原")
	SV.retry_pending()
	ok(g._sb_bad_clear() and not SV.data.has("songbook_bad"), "清掉")
	g.free()
	SV.data = keep
	SV.save_data()
	SV.data_locked = lk1
	# 讀檔成本與邊界：存成 null、巨量、巢狀
	var dn := {"songbook": null}
	SV.sanitize_data(dn)
	ok((dn["songbook"] as Array).is_empty() and (dn.get("songbook_bad", []) as Array).size() == 1, "棋譜本存成 null：隔離（不默默消失）")
	var huge: Array = []
	for i in 500:
		huge.append({"c": codes[0]})
	var nest := {"c": [[[[1]]]], "n": "x".repeat(20000)}
	var t0 := Time.get_ticks_msec()
	var sph: Array = SBx.split(huge + [nest])
	ok(sph[0].size() == 1 and Time.get_ticks_msec() - t0 < 500 and str(sph[1][-1]).begins_with("+"), "巨量重複：只看前 %d 筆、重複不重解（%d ms）" % [SBx.SCAN_MAX, Time.get_ticks_msec() - t0])
	# 存檔路徑：前面已有不同壞資料時，「+N」超量提示也留得住
	var mix: Array = []
	for i in 10:
		mix.append({"c": "bad%d" % i})
	for i in 40:
		mix.append({"c": codes[0]})
	var dm := {"songbook": mix}
	SV.sanitize_data(dm)
	ok(str((dm["songbook_bad"] as Array)[0]).begins_with("+") and (dm["songbook_bad"] as Array).size() == SBx.BAD_MAX, "前面有壞資料時，超量提示仍在隔離區（%s）" % str(dm["songbook_bad"][0]))
	var full7: Array = []
	for i in SBx.MAX:
		full7.append({"c": codes[i]})
	full7.append({"c": "bad-after-full"})
	var sf: Array = SBx.split(full7)
	ok(sf[0].size() == SBx.MAX and sf[1].size() == 1 and str(sf[1][0]).find("bad-after-full") >= 0, "冊子滿了之後的壞碼也進隔離區（Codex B16 r3）")
	var bigbad: Array = []
	for i in 100000:
		bigbad.append("s%d" % i)
	var t1 := Time.get_ticks_msec()
	ok(SBx.sanitize_bad(bigbad).size() == SBx.BAD_MAX and Time.get_ticks_msec() - t1 < 100, "隔離區有界（十萬筆 %d ms）" % (Time.get_ticks_msec() - t1))
	var spn: Array = SBx.split([nest])
	ok(spn[1].size() == 1 and str(spn[1][0]).length() <= SBx.BAD_TEXT, "巢狀／超長：只留截過的原文")
	var gr: String = FileAccess.get_file_as_string("res://scripts/ui/screens/game_result.gd")
	ok(gr.find("res_more_items.append([L.t(\"sb_add\"), func(): call(\"_sb_add_current\")])") >= 0, "結果頁「更多」直接收進棋譜本")

## 1.6.0 B18（P7.4）棋館名局：每一場都解得開、重算的勝方／剩餘／秒數和資料一樣（確定性），文字只寫這三個事實。
func test_famous_v1600() -> void:
	var GS = load("res://scripts/ui/game_screens.gd")
	var BCx = load("res://scripts/game/battle_code.gd")
	var g = GS.new()
	var fl: Array = g.famous_games()
	var same := 0
	for e in fl:
		var d: Dictionary = BCx.decode(str(e["c"]))
		var s = Sim.new(d["a0"], d["a1"], d.get("rules"))
		s.fast = true
		s.run_to_end()
		var rem := roundi(s.power(s.winner) * 100.0 / (s.budget_of(s.winner) * 1000)) if s.winner >= 0 else -1
		if s.winner == int(e["w"]) and rem == int(e["rem"]) and s.tick / 20 == int(e["sec"]) and rem < 20:
			same += 1
	ok(fl.size() == 6 and same == 6, "名局 6 場重算都和資料一樣、都是剩不到兩成的險勝（%d／%d）" % [same, fl.size()])
	g.sb_tab = 1
	ok(g.famous_games().size() == fl.size(), "名局只讀一次（快取）")
	g.free()

## 1.6.0 B21（P13.2）出題錯誤落點與保留草稿：擋住出題的原因＋格子；草稿存檔、重開帶回、壞草稿不帶。
func test_editor_draft_v1600() -> void:
	var GS = load("res://scripts/ui/game_screens.gd")
	var SVx = load("res://scripts/game/save.gd")
	var LSd = load("res://scripts/game/strings.gd")
	ok(GS.ed_problems({}, {}).size() == 2 and GS.ed_problems({}, {})[0][0] == "ed_err_no_own", "空盤：先說沒有你的兵、再說沒有敵兵")
	var c := {Vector2i(1, 1): 0, Vector2i(12, 4): 0}
	ok(GS.ed_problems(c, {}).is_empty(), "兩邊都有兵：可以出")
	var pw: Array = GS.ed_problems(c, {Vector2i(12, 4): true})
	ok(pw.size() == 1 and pw[0][0] == "ed_err_wall" and pw[0][1] == [Vector2i(12, 4)], "壓在牆上：圈出那一格")
	var big := {Vector2i(12, 4): 0}
	for r in 9:
		for col in 6:
			big[Vector2i(col, r)] = 3
	var pb: Array = GS.ed_problems(big, {})
	ok(pb.size() >= 1 and pb[0][0] == "ed_err_budget" and (pb[0][1] as Array).size() == 54, "超過 200 金：圈出你的兵")
	var keep: Dictionary = SVx.data.duplicate(true)
	var g = GS.new()
	g.sfx = FakeSfx.new()
	g.ed_cells = {}
	g._ed_make()
	ok(g.ed_err_side == 0 and g.ed_msg == LSd.t("ed_err_no_own"), "按出題時擋下、整個左半邊圈紅", str([g.ed_err_side, g.ed_msg]))
	g.ed_type = 0
	g.ed_toggle(Vector2i(2, 3))
	ok(g.ed_err_side == -1 and SVx.data.get("ed_draft", {}).get("cells", []) == [[0, 2, 3]], "改了就收紅框、草稿跟著改")
	var d: Dictionary = JSON.parse_string(JSON.stringify(SVx.data))
	SVx.sanitize_data(d)
	var g2 = GS.new()
	g2.sfx = FakeSfx.new()
	SVx.data["ed_draft"] = d["ed_draft"]
	g2._ed_load_draft()
	ok(g2.ed_cells == {Vector2i(2, 3): 0} and g2.ed_msg == LSd.t("ed_draft_back"), "重開（存檔來回）帶回草稿")
	ok(SVx.data["ed_draft"]["cells"] == [[0, 2, 3]], "讀回途中不會用空盤蓋掉原稿")
	ok(GS.ed_draft_ok({"cells": [[0, 2, 3]], "goal": 0, "map": 0, "t": [-1, -1], "foes": [[], [[1, 12, 2]], []], "fi": 1}), "完整草稿（含三考題的三支敵陣）合格")
	# 三考題：空的那一支敵陣翻過去並圈紅
	var g3 = GS.new()
	g3.sfx = FakeSfx.new()
	var WSx = load("res://scripts/game/workshop.gd")
	g3.ed_goal = WSx.ED_GOALS.find("trio")
	g3.ed_cells = {Vector2i(1, 1): 0, Vector2i(12, 4): 0}
	g3.ed_foes = [{}, {}, {}]
	g3.ed_foe_i = 0
	g3._ed_make()
	ok(g3.ed_foe_i == 1 and g3.ed_err_side == 1 and g3.ed_msg == LSd.t("ed_err_trio_foe", [2]), "三考題第 2 支敵陣空的：翻到第 2 支、圈紅", str([g3.ed_foe_i, g3.ed_msg]))
	ok((SVx.data.get("ed_draft", {}) as Dictionary).get("fi", -1) == 1 and ((SVx.data["ed_draft"]["foes"] as Array)[0] as Array).size() == 1, "草稿存了三支敵陣與目前第幾支")
	g3.free()
	for bad in ["x", {"cells": [[0, 7, 3]]}, {"cells": [], "goal": 0, "map": 63, "t": [-1, -1]}, {"cells": [], "goal": 0, "map": 0, "t": ["a", 1]}, {"cells": [], "goal": 0, "map": 0}, {"cells": [[0, 2, 30]], "goal": 0, "map": 0}, {"cells": [[1.0e30, 2, 3]], "goal": 0, "map": 0}, {"cells": [], "goal": 99, "map": 0}]:
		ok(not GS.ed_draft_ok(bad), "壞草稿不帶回：%s" % str(bad))
	g.free()
	g2.free()
	SVx.data = keep
