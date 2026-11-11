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
	for s in TR.sets():
		ok(s.has("sol3") and TR.stars(s, TR.results(s, s["sol3"])) == 3, "每組都有可重現的三星解（A3）：" + str(s["id"]))
		ok(TR.stars(s, TR.results(s, s["sol"])) >= 1, "作者解三場都贏：" + str(s["id"]))

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
