extends "res://tests/test_base.gd"
## 1.1.0 A4：功能測試組「modes_live」：極速賽、裂隙、每日、合作、迷霧、生涯、人設、新手導覽、工坊、章節印。
## 從原本依版本分的 v16、v161、v100 搬來，函式名不變（名字尾的 _v160／_v161／_v100／_v110 是做的版本）。會碰存檔的測試自己換前綴、結束還原。

func test_guide_v160() -> void:
	var G = load("res://scripts/game/guide.gd")
	var d := {"tutorial": 0, "stats": {"games": 0}, "eff_games": 0}
	ok(G.next_step(d, false, false) == "tut", "新玩家先教學")
	d["tutorial"] = 1
	ok(G.next_step(d, false, false) == "ai", "教學過了：打第一場")
	d["stats"] = {"games": 3}
	d["eff_games"] = 3
	ok(G.next_step(d, false, false) == "puzzle", "打過了：殘局")
	d["puzzle_stars"] = {"p1": 1}
	ok(G.next_step(d, false, false) == "puzzle_more", "V1.0.0 N6：前 5 關、還沒贏過 AI：繼續殘局")
	d["stats"] = {"games": 3, "wins": 1}
	d["ai_wins"] = 0
	ok(G.next_step(d, false, false) == "puzzle_more", "V1.0.0：stats 的勝場可能是教學、殘局；看的是對 AI 勝場")
	d["ai_wins"] = 1
	ok(G.next_step(d, false, false) == "daily" and G.next_step(d, false, true) == "", "完整版接每日；試玩版不推沒開的模式")
	d["gauntlet_run"] = {"stage": 3}
	ok(G.next_step(d, false, false) == "gauntlet_cont" and G.next_step(d, false, true) != "gauntlet_cont", "有沒打完的遠征：先接著打（試玩版不推）")
	d.erase("gauntlet_run")
	ok(G.next_puzzle_id({"puzzle_stars": {"a": 1}}, [{"id": "a"}, {"id": "b"}]) == "b" and G.next_puzzle_id({"puzzle_stars": {"a": 1}}, [{"id": "a"}]) == "", "下一個沒過的殘局")
	d["gauntlet_best"] = 2
	d["funnel"] = {"playroom_open": 1}
	d["trial_stars"] = {"0": 1}
	ok(G.next_step(d, true, false) == "v16:rush_open", "舊的都做過：推 V1.6 新玩法（V1.6.1 N1；原本是不顯示）")
	d["seen"] = G.V16_ENTRIES.duplicate()
	ok(G.next_step(d, true, false) == "", "全部做過、新玩法也開過就不顯示")
	var e := {"eff_games": 3}   # V1.6.1 N1：玩滿 3 場有效對局才標新
	G.seed_seen(e)
	ok(not G.is_new(e, "menu_vs_ai") and G.is_new(e, "rush_open"), "舊入口算看過、V1.6 新入口標新")
	G.see(e, "rush_open")
	ok(not G.is_new(e, "rush_open"), "打開過就不再標新")
	ok(G.demo_end_due({"stats": {"games": 4}}, true, false) and not G.demo_end_due({"stats": {"games": 4}}, true, true) and not G.demo_end_due({"stats": {"games": 9}}, false, false), "試玩版結尾只在試玩版、每次開遊戲一次")

func test_rush_v160() -> void:
	var RU = load("res://scripts/game/rush.gd")
	var PZx = load("res://scripts/game/puzzles.gd")
	var a: Array = RU.pool(7)
	var b: Array = RU.pool(7)
	ok(a.size() >= 30 and a == b, "題庫夠多（%d）、同種子同順序" % a.size())
	var bad := 0
	var last_ch := -1
	for id in a:
		var pz: Dictionary = PZx.get_puzzle(id)
		if not RU.eligible(pz):
			bad += 1
		var c: int = PZx.chapter_of(id)
		if c < last_ch:
			bad += 1
		last_ch = c
	ok(bad == 0, "只收打贏型、沒有地圖／軍令／上限；章節由淺到深")
	ok(RU.after(10.0, true) == 30.0 and RU.after(10.0, false) == -5.0, "解開 +20、失敗 −15")

func test_rift_v160() -> void:
	var RF = load("res://scripts/game/rift.gd")
	var RO = load("res://scripts/game/roster.gd")
	var mask: int = RO.mask(false)
	var bad := 0
	for wk in range(2900, 2960):
		var ps: Array = RF.picks(wk, mask)
		var tags := {}
		for k in ps:
			if tags.has(RF.ANOMS[k][1]):
				bad += 1
			tags[RF.ANOMS[k][1]] = true
		var r = RF.make_rules(ps, mask, wk)
		if ps.size() != 3 or not r.validate().is_empty():
			bad += 1
		if wk < 2904:
			var e = RF.enemy(r, wk)
			if e.units.is_empty() or JSON.stringify(e.units) != JSON.stringify(RF.enemy(r, wk).units):
				bad += 1
	ok(bad == 0, "60 週：每週 3 種、同類不重複、規則合法、敵陣固定")
	ok(RF.picks(2950, mask) == RF.picks(2950, mask) and RF.picks(2950, mask) != RF.picks(2951, mask), "同週同題、換週換題")

func test_persona_v160() -> void:
	var PS = load("res://scripts/game/persona.gd")
	var Lx = load("res://scripts/game/strings.gd")
	var miss := 0
	for st in 6:
		for m in ["open", "win", "lose"]:
			var k: String = PS.line_key(st, m)
			if Lx.t(k) == k or Lx.t(k) == "":
				miss += 1
		if Lx.t("ps_name_%d" % st) == "ps_name_%d" % st:
			miss += 1
	ok(miss == 0, "6 種性格都有名號與三句台詞")
	ok(PS.face(9) == PS.face(5) and PS.face(-1) == PS.face(0), "超出範圍的性格夾到合法值")

func test_career_v160() -> void:
	var CA = load("res://scripts/game/career.gd")
	var g: Dictionary = CA.gain([FakeU.new(0, 2, 3), FakeU.new(0, 2, 1), FakeU.new(1, 2, 5), FakeU.new(0, 20, 9, true), FakeU.new(0, 0, 0)])
	ok(g == {"2": 5, "0": 1}, "出場 +1、擊倒加點；敵方、召喚物不算")
	var m := {"2": 3}
	var ups: Array = CA.add(m, g)
	ok(int(m["2"]) == 8 and ups == [2] and CA.level(8) == 1 and CA.level(120) == 5 and CA.next_at(120) == -1, "累積、升級、滿級")
	var nb := {}
	ok(CA.nb_save(nb, "p1", "A", [[0, 1, 2]]) and not CA.nb_save(nb, "p1", "B", [[0, 1, 2]]), "同樣的擺法不重複存")
	for i in 4:
		CA.nb_save(nb, "p1", "x", [[0, 1, i + 3]])
	ok(not CA.nb_save(nb, "p1", "y", [[1, 1, 1]]) and nb["p1"].size() == 5, "每關最多 5 份")
	CA.nb_result(nb, "p1", [[0, 1, 2]], 2, 40, 30)
	CA.nb_result(nb, "p1", [[0, 1, 2]], 1, 90, 10)
	ok(nb["p1"][0]["r"] == [2, 40, 30], "成績留最好的（星數優先）")

func test_daily_board_v160() -> void:
	var ST = load("res://scripts/game/steam.gd")
	var us := [{"type": 2, "x": 1500, "y": 3500}, {"type": 13, "x": 5950, "y": 8500}]
	var d: PackedInt32Array = ST.pack_free(us, 16000)
	var back: Array = ST.unpack_free(d, 16000, 9000)
	ok(back.size() == 2 and back[0] == {"type": 2, "x": 14500, "y": 3500} and back[1]["x"] == 10050, "自由座標打包後是紅方鏡像")
	var bad := d.duplicate()
	bad[2] = (25 << 22) | (300 << 11) | 70
	ok(ST.unpack_free(bad, 16000, 9000).is_empty(), "兵種不合法整份不收")
	var dup := PackedInt32Array([2, 2, d[2], d[2]])
	ok(ST.unpack_free(dup, 16000, 9000).is_empty(), "重疊不收")
	ok(ST.pack_free([{"type": 0, "col": 1, "row": 1}], 16000).is_empty(), "格子陣不走這條")
	ok(ST.daily_score(72, 84) > ST.daily_score(72, 90) and ST.daily_score(73, 120) > ST.daily_score(72, 0), "分數：剩餘優先、再比花費")

func test_fog_v160() -> void:
	var G = load("res://scripts/ui/screens/game_v16.gd")
	var us := [{"type": 0, "col": 10, "row": 1}, {"type": 1, "col": 11, "row": 2}, {"type": 2, "col": 14, "row": 3}, {"type": 2, "col": 12, "row": 3}]
	var seen: Array = G.fog_seen(us)
	ok(seen.size() == 2 and int(seen[0]["col"]) == 10 and int(seen[1]["col"]) == 14, "迷霧推演：依欄列排序每 3 隻露 1 隻（4 隻露第 1、4 隻）")

func test_coop_v160() -> void:
	var G = load("res://scripts/ui/screens/game_v16.gd")
	ok(G.coop_player(1) == 1 and G.coop_player(2) == 2 and G.coop_player(7) == 1, "奇數站玩家 1、偶數站玩家 2")
	var SV = load("res://scripts/game/save.gd")
	var run := {"stage": 3, "seed": 1, "gold": 0, "cap": 0, "changes": 99, "pool": 1023, "prev": [], "coop": 1}
	ok(int(SV.sanitize_run(run)["coop"]) == 1, "續局記得是雙人")
	run.erase("coop")
	ok(int(SV.sanitize_run(run)["coop"]) == 0, "舊續局沒有這欄＝單人")
	run["coop"] = "x"
	ok(int(SV.sanitize_run(run)["coop"]) == 0, "型別不對＝單人")

func test_fog_free_v161() -> void:
	var G = load("res://scripts/ui/screens/game_v16.gd")
	var us := [{"type": 0, "x": 10500, "y": 1500}, {"type": 1, "x": 11500, "y": 2500}, {"type": 2, "x": 14500, "y": 3500}, {"type": 2, "x": 12500, "y": 3500}]
	var seen: Array = G.fog_seen(us)
	ok(seen.size() == 2 and int(seen[0]["x"]) == 10500 and int(seen[1]["x"]) == 14500, "自由座標也露（F3），和格子同樣的順序規則")

func test_new_after_v161() -> void:
	var G = load("res://scripts/game/guide.gd")
	var d := {"eff_games": 2}
	G.seed_seen(d)
	ok(not G.is_new(d, "rush_open"), "前 2 場不標新玩法（N1）")
	ok(not G.tour_due(d, false), "新手不跳導覽")
	d["eff_games"] = 3
	ok(G.is_new(d, "rush_open") and G.tour_due(d, false) and not G.tour_due(d, true), "玩滿 3 場：標新、跳一次導覽（試玩版不跳）")
	G.see(d, "tour161")
	ok(not G.tour_due(d, false), "導覽只跳一次")

func test_rift_history_v161() -> void:
	var RF = load("res://scripts/game/rift.gd")
	var b := {}
	for w in range(100, 112):
		b["%d-v1" % w] = [w, 50]
	var k: Dictionary = RF.keep_recent(b, 8)
	ok(k.size() == 8 and k.has("111-v1") and not k.has("103-v1"), "裂隙紀錄留最近 8 週（A12）")
	b["111-v2"] = [1, 1]
	var k2: Dictionary = RF.keep_recent(b, 8)
	ok(RF.weeks_of(k2).size() == 8 and k2.has("111-v1") and k2.has("111-v2") and k2.has("104-v1"), "同一週不同版本算同一週（Codex v161-i2 #4）")

func test_rush_daily_v161() -> void:
	var RU = load("res://scripts/game/rush.gd")
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

## M4：單人遠征的每站紀錄（玩家欄 0）存檔驗得過；接力的規則不變。
func test_solo_clog_v100() -> void:
	var S = load("res://scripts/game/save.gd")
	var run := {"stage": 3, "seed": 1, "gold": 0, "cap": 0, "changes": 3, "pool": 1023, "prev": [], "coop": 0, "clog": [1, 0, 1, 0, 2, 0, 1, 3]}
	ok(S.sanitize_run(run)["clog"] == [1, 0, 1, 0, 2, 0, 1, 3], "單人：玩家欄 0 留下")
	run["clog"] = [1, 1, 1, 0]
	ok(S.sanitize_run(run)["clog"] == [], "單人卻寫玩家 1：丟掉")
	run["coop"] = 1
	ok(S.sanitize_run(run)["clog"] == [1, 1, 1, 0], "接力照舊")

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

## 1.1.0 A10：章節全三星才蓋印。
func test_chapter_seal_v110() -> void:
	var G = load("res://scripts/ui/screens/game_menus.gd")
	var chap := [{"id": "a"}, {"id": "b"}]
	ok(not G.chapter_sealed(chap, {"a": 3, "b": 2}), "差一顆星不蓋")
	ok(G.chapter_sealed(chap, {"a": 3, "b": 3}), "全三星蓋印")
	ok(not G.chapter_sealed([], {}), "空章節不蓋")
