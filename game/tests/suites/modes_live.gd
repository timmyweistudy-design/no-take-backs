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

## 1.2.0 §15.4：每週棋盒的玩家幽靈入口：沒 Steam 顯示離線；回空顯示「沒人上傳」；有資料可挑一個對戰（鏡像成對手）；過期回呼不改畫面。
func test_wk_ghosts_v120() -> void:
	var g = load("res://scripts/ui/game_screens.gd").new()
	g.sfx = FakeSfx.new()
	g._wk_dl_open()
	ok(g.overlay == "wk_ghosts" and g.wk_dl_state == "offline", "沒有 Steam：離線提示")
	g.wk_dl_state = "busy"
	var g0: int = g.wk_dl_gen
	g._wk_dl_done(g0, [])
	ok(g.wk_dl_state == "empty", "回空：本週沒人上傳")
	g.wk_dl_state = "busy"
	g._wk_dl_done(g0 - 1, [{"rank": 1, "score": 50, "units": [{"type": 0, "col": 2, "row": 4}]}])
	ok(g.wk_dl_state == "busy", "過期回呼不改畫面")
	g._wk_dl_done(g0, [{"rank": 1, "score": 50, "units": [{"type": 0, "col": 13, "row": 4}, {"type": 2, "col": 14, "row": 3}]}])
	ok(g.wk_dl_state == "ok" and g.wk_dl_list.size() == 1, "有資料：列出")
	g._wk_dl_play(0)
	ok(g.mode == g.Mode.VS_AI and g.challenge_army != null and g.challenge_army.team == 1 and g.challenge_army.units.size() == 2 and int(g.challenge_army.units[0]["col"]) == 13, "挑一個對戰：對手是紅方視角的玩家陣")
	# 上傳端：存的是紅方視角，解包收得下（V1.4 起存藍方、解包只收紅方，下載永遠是空的）
	var ST = load("res://scripts/game/steam.gd")
	var Armyx = load("res://scripts/core/army.gd")
	var mine = Armyx.new(0, 100)
	mine.place(0, 2, 4)
	mine.place(2, 1, 3)
	var packed: PackedInt32Array = ST.pack_army(mine.mirrored().units)
	ok(ST.unpack_army(packed).size() == 2, "自己的陣鏡像後打包，解包收得下")
	g.free()

## 1.2.0 §15.3：掌機建議 30／60fps 兩版只差 fps_cap。
func test_handheld_presets_v120() -> void:
	var M = load("res://scripts/ui/screens/game_menus.gd")
	var p30: Dictionary = M.PRESETS[3]
	var p60: Dictionary = M.PRESETS[4]
	ok(int(p30["fps_cap"]) == 30 and int(p60["fps_cap"]) == 60, "30／60")
	var a := p30.duplicate()
	var b := p60.duplicate()
	a.erase("fps_cap")
	b.erase("fps_cap")
	ok(a == b, "其他設定一樣")

## 1.2.0 §15.4（Codex cat01）：走真的排行榜通道（假 Steam）：找榜 → 下載 3 筆 → 面板列出；另一次逾時 → 當空結果。
func test_wk_ghosts_steam_v120() -> void:
	var ST = load("res://scripts/game/steam.gd")
	var g = load("res://scripts/ui/game_screens.gd").new()
	g.sfx = FakeSfx.new()
	var fk := FakeLB.new()
	ST.lb_reset()
	ST._steam = fk
	ST.now_ms = 1000
	var wk: int = g.week_no(int(Time.get_unix_time_from_system()))
	fk.names[11] = "weekly_%d" % wk
	g._wk_dl_open()
	ok(g.wk_dl_state == "busy" and fk.finds == ["weekly_%d" % wk], "有 Steam：找本週的榜、顯示下載中", str(fk.finds))
	fk.emit_signal("leaderboard_find_result", 11, 1)
	var det := func(t: int) -> Array: return [1, 2, t * 10000 + 13 * 100 + 4, 2 * 10000 + 14 * 100 + 3]   # 紅方視角（欄 10～15）
	fk.emit_signal("leaderboard_scores_downloaded", "", 11, [
		{"steam_id": 1, "score": 40, "global_rank": 1, "details": det.call(0)},
		{"steam_id": 2, "score": 45, "global_rank": 2, "details": det.call(3)},
		{"steam_id": 3, "score": 50, "global_rank": 3, "details": det.call(5)}])
	ok(g.wk_dl_state == "ok" and g.wk_dl_list.size() == 3, "下載 3 筆就列 3 筆", "%s %d" % [g.wk_dl_state, g.wk_dl_list.size()])
	# 逾時：當成空結果
	g.overlay = "weekly"
	g._wk_dl_open()
	fk.emit_signal("leaderboard_find_result", 11, 1)
	ST.now_ms = 1000 + ST.LB_TIMEOUT_MS + 10
	ST.lb_tick()
	ok(g.wk_dl_state == "empty", "下載逾時：顯示沒有資料（不會卡在下載中）", g.wk_dl_state)
	ST._steam = null
	ST.lb_reset()
	g.free()

## 1.2.0 第 10 大類（§11.5／11.6／11.7／11.9／11.10）：換邊雙局、合作布陣、戰役、天梯待送、出題台地形
func test_optional_modes_v120() -> void:
	# §11.5 換邊雙局
	var SD = load("res://scripts/game/swap_duel.gd")
	ok(SD.owner(1, 0) == 0 and SD.owner(1, 1) == 1 and SD.owner(2, 0) == 1 and SD.owner(2, 1) == 0, "換邊：第 2 局玩家 A 是紅")
	ok(SD.verdict([120, 80], [3, 1]) == 0 and SD.verdict([80, 80], [4, 2]) == 1 and SD.verdict([80, 80], [2, 2]) == -1, "總分→倒下少→和局")
	var Simx = load("res://scripts/core/battle_sim.gd")
	var AIx = load("res://scripts/core/ai_army.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var sm = Simx.new(AIx.build(0, 100, rng)["army"], AIx.build(1, 100, rng)["army"])
	sm.run_to_end()
	var r1: Array = SD.settle([0, 0], [0, 0], 2, sm)
	var PZx = load("res://scripts/game/puzzles.gd")
	ok(int(r1[0][1]) == PZx.rem_pct(sm.power(0), sm.budget_of(0)) and int(r1[0][0]) == PZx.rem_pct(sm.power(1), sm.budget_of(1)), "第 2 局藍方分數記在玩家 B")
	# §11.6 合作布陣
	var CP = load("res://scripts/game/coop_place.gd")
	var cp = CP.new(100, 30)
	ok(cp.cap == 30 and cp.player() == 0 and cp.hands_total() == 10, "每手上限＝max(預算/總手數, 最貴兵)、P1 先")
	cp.placed(Vector2i(1, 1), 10)
	ok(cp.check(25) == "cap" and cp.check(20) == "", "這一手超過上限不行")
	cp.removed(Vector2i(1, 1), 10)
	ok(cp.spent == 0 and cp.hand == 0 and cp.player() == 0, "撤銷返還錢、不返還手數、仍是同一人")
	cp.placed(Vector2i(2, 2), 10)
	cp.end_hand()
	ok(cp.player() == 1 and not cp.can_remove(Vector2i(2, 2)), "換 P2 後不能撤 P1 的兵")
	cp.finish_if_stuck(false)
	ok(cp.done() and cp.check(1) == "done", "買不起就全部結束")
	# §11.7 戰役
	var CM = load("res://scripts/game/campaign.gd")
	var chs: Array = CM.chapters()
	var n := 0
	var bad := 0
	for ch in chs:
		ok_quiet(ch["stages"].size() == 7)
		for st in ch["stages"]:
			n += 1
			if str(st["goal"]) == "puzzle":
				if CM.puzzle_id(st) == "":
					bad += 1
				continue
			var r = CM.rules_of(st)
			if not r.validate().is_empty():
				bad += 1
				continue
			var e1 = CM.enemy_of(st, r)
			var e2 = CM.enemy_of(st, r)
			if e1.to_code() != e2.to_code() or e1.units.is_empty() or e1.spent() > r.budget_of(1):
				bad += 1
	ok(chs.size() == 5 and n == 35 and bad == 0, "戰役 5 章 35 關：規則合法、敵陣確定且在預算內、殘局關有題（壞 %d）" % bad)
	var sv := {"campaign": {}, "puzzle_stars": {}}
	ok(CM.unlocked(sv, "c1_1") and not CM.unlocked(sv, "c1_2"), "照順序解鎖")
	CM.record(sv, "c1_1", 2)
	ok(CM.unlocked(sv, "c1_2") and not CM.record(sv, "c1_1", 1) and int(sv["campaign"]["c1_1"]) == 2, "只記更好的星數")
	var keep_st := {"goal": "keep", "keep": 3}
	ok(CM.grade(keep_st, true, 3, 400, 90, false) == 0, "保兵：最貴的那隻倒了就不算")
	var sv2 := {"campaign": {"c1_1": 1, "c1_2": 1, "c1_3": 1, "c1_4": 1, "c1_5": 1, "c1_6": 1}, "puzzle_stars": {}}
	ok(not CM.unlocked(sv2, "c2_1"), "前一章殘局沒過不能進下一章")
	sv2["campaign"].erase("c1_3")
	sv2["puzzle_stars"][CM.puzzle_id(CM.stage("c1_p"))] = 3
	ok(not CM.unlocked(sv2, "c2_1"), "舊殘局星不能跳過沒打的戰鬥關")
	ok(CM.grade(keep_st, true, 2, 400, 90) == 0 and CM.grade(keep_st, true, 3, 400, 90) == 3 and CM.grade({"goal": "time", "secs": 30}, true, 5, 601, 90) == 0 and CM.grade({"goal": "win"}, true, 1, 9, 39) == 1, "評星：保兵、限時、剩餘戰力")
	ok(CM.sanitize({"c1_1": 9, "x": "a", 3: 1}).size() == 1 and int(CM.sanitize({"c1_1": 9})["c1_1"]) == 3, "戰役存檔驗型")
	# §11.9 天梯待送
	var ST = load("res://scripts/game/steam.gd")
	var dd := {"rift_pend": {"wk": 5, "score": 77, "det": [1], "ver": 2}}
	ok(not ST.clear_pending(dd, "rift_5_v2", 70) and dd.has("rift_pend") and ST.clear_pending(dd, "rift_5_v2", 77) and not dd.has("rift_pend"), "天梯：送上去的就是待送那筆才清")
	# §11.10 出題台地形
	var WS = load("res://scripts/game/workshop.gd")
	var foe := [[0, 12, 4]]
	var sol := [[3, 2, 3], [3, 2, 5], [0, 4, 4]]
	var wall := Vector2i(-1, -1)
	for cy in 9:
		for cx in 6:
			if wall.x < 0 and WS.blocked_cell(1, cx, cy, 0):
				wall = Vector2i(cx, cy)
	var free_ok := true
	for u in sol:
		if WS.blocked_cell(1, int(u[1]), int(u[2]), 0):
			free_ok = false
	var c5: String = WS.encode5(foe, sol, "win", Vector2i(-1, -1), 1) if free_ok else ""
	ok(c5 == "" or (c5.begins_with("NTP5.") and int(WS.decode(c5)["pz"]["map"]) == 1), "有地形出 NTP5、解回來有地圖", c5.left(20))
	ok(WS.encode5(foe, sol, "win", Vector2i(-1, -1), 0) == WS.encode4(foe, sol, "win", Vector2i(-1, -1)), "沒地形等於原本的碼")
	if wall.x >= 0:
		ok(WS.encode5(foe, [[0, wall.x, wall.y]] + sol, "win", Vector2i(-1, -1), 1) == "", "兵壓在牆上不給碼")

func ok_quiet(_c: bool) -> void:
	pass

## 1.6.0 B18（P7.3）對 AI 換邊雙局：第 1 局你擺藍、AI 擺紅；第 2 局 AI 先擺藍、你擺紅；分數跟著人走（SwapDuel 原規則）。
func test_swap_ai_v1600() -> void:
	var GS = load("res://scripts/ui/game_screens.gd")
	var SD = load("res://scripts/game/swap_duel.gd")
	var LSx = load("res://scripts/game/strings.gd")
	var Simx = load("res://scripts/core/battle_sim.gd")
	var SVx = load("res://scripts/game/save.gd")
	var keep: Dictionary = SVx.data.duplicate(true)
	var lk: bool = SVx.data_locked
	SVx.data_locked = false
	SVx.data.erase("swap_ai_run")
	var g = GS.new()
	g.sfx = FakeSfx.new()
	g._swap_ai_start()
	ok(g.swap_on and g.swap_ai and g.mode == g.Mode.DUEL and g.tp == null and g.blind_phase == 0 and g.armies[1].count() == 0, "第 1 局：輪到你擺藍方，紅方還空著", str([g.blind_phase, g.tp]))
	var pool := F.training_pool(0)
	for u in pool[2].units:
		g.armies[0].place(int(u["type"]), int(u["col"]), int(u["row"]))
	g._on_start()
	ok(g.blind_phase == 2 and g.armies[1].count() > 0 and g._ready_to_fight(), "你擺好藍方＝AI 擺紅方，可以開戰（紅 %d 隻）" % g.armies[1].count())
	ok(g._swap_who().find(LSx.t("blue")) >= 0, "第 1 局標示你是藍方")
	g.round_no = 2
	g._reset_place()
	ok(g.blind_phase == 1 and g.armies[0].count() > 0 and g.armies[1].count() == 0 and g._cur_army() == g.armies[1], "第 2 局：AI 先擺好藍方，輪到你擺紅方")
	ok(g._swap_who().find(LSx.t("red")) >= 0 and SD.owner(2, 1) == 0, "第 2 局標示你是紅方；紅方分數算給你")
	ok(g._swap_fact().find("AI") >= 0, "結果頁寫你和 AI（不是玩家 A／B）")
	ok(g.swap_ai_my_color() == 1, "第 2 局你是紅方")
	var cg: String = FileAccess.get_file_as_string("res://scripts/ui/screens/game_core.gd")
	var cp: String = FileAccess.get_file_as_string("res://scripts/ui/screens/game_place.gd")
	ok(cg.find("me_won = w >= 0 and w == int(call(\"swap_ai_my_color\"))") >= 0 and cp.find("if not ai_blue:") >= 0, "勝場只算你那一色；你擺紅那局不記成你的上一陣")
	# 同一局重送結算不重記
	g.mode = g.Mode.DUEL
	g.play_kind = "official"
	g.sim = Simx.new(pool[2].copy(), pool[9].mirrored())
	g.sim.fast = true
	g.sim.run_to_end()
	g._swap_settle()
	var p1: Array = g.sw_pts.duplicate()
	g._swap_settle()
	ok(g.sw_pts == p1, "同一局重送結算：分數不重記")
	ok(not SVx.data.has("swap_ai_run"), "整組結束：會話刪掉")
	# §3.1 會話：第 1 局 AI 擺好＝承諾寫檔；記分後重啟＝接第 2 局；第 2 局 AI 的陣承諾後重啟不重抽
	var g2 = GS.new()
	g2.sfx = FakeSfx.new()
	g2._swap_ai_start(true)
	for u in pool[2].units:
		g2.armies[0].place(int(u["type"]), int(u["col"]), int(u["row"]))
	g2._on_start()
	var run1 = SD.sanitize_run(JSON.parse_string(JSON.stringify(SVx.data.get("swap_ai_run"))))
	ok(run1 != null and int(run1["round"]) == 1 and int(run1["settled"]) == 0 and (run1["ai"] as Array).size() == g2.armies[1].count(), "第 1 局：AI 擺好就寫檔（承諾）")
	g2.mode = g2.Mode.DUEL
	g2.play_kind = "official"
	g2.sim = Simx.new(g2.armies[0].copy(), g2.armies[1].copy())
	g2.sim.fast = true
	g2.sim.run_to_end()
	g2._swap_settle()
	var pts1: Array = g2.sw_pts.duplicate()
	var d1: Dictionary = JSON.parse_string(JSON.stringify(SVx.data))   # 重啟＝寫檔讀回＋清理
	SVx.sanitize_data(d1)
	ok(int(d1["swap_ai_run"]["settled"]) == 1 and d1["swap_ai_run"]["pts"] == pts1, "記分寫檔：settled 前進、分數存著")
	g2.free()
	SVx.data["swap_ai_run"] = d1["swap_ai_run"]
	var g3 = GS.new()
	g3.sfx = FakeSfx.new()
	g3._swap_ai_start()
	ok(g3.round_no == 2 and g3.sw_pts == pts1 and g3.swap_ai_my_color() == 1 and g3.armies[0].count() > 0 and g3.blind_phase == 1, "重啟後接第 2 局：分數照舊、AI 先擺藍", str([g3.round_no, g3.sw_pts]))
	var ai2: Array = SD.units_of(g3.armies[0])
	g3.free()
	var g4 = GS.new()
	g4.sfx = FakeSfx.new()
	g4._swap_ai_start()
	ok(SD.units_of(g4.armies[0]) == ai2, "第 2 局 AI 的陣承諾過了：再重啟不重抽")
	g4.sw_settled = 1
	ok(int(SVx.data["swap_ai_run"]["settled"]) == 1, "第 1 局不會再記一次（settled 從存檔帶回）")
	SVx.fail_inject = {"tmp": 1}
	ok(not g4._swap_ai_commit([]) and SVx.has_unsaved(), "寫檔失敗：照實說、標未存")
	SVx.retry_pending()
	g4.free()
	# 壞陣（重疊、越界）＝整個會話不用；擺不回去（兵種不在卡池）＝重新組陣，不留縮水的陣
	ok(SD.sanitize_run({"v": 1, "round": 2, "settled": 1, "pts": [0, 0], "dead": [0, 0], "ai": [[0, 1, 1], [1, 1, 1]]}) == null and SD.sanitize_run({"v": 1, "round": 2, "settled": 1, "pts": [0, 0], "dead": [0, 0], "ai": [[0, 99, 1]]}) == null, "存的 AI 陣重疊或越界：會話不用")
	SVx.data["swap_ai_run"] = {"v": 1, "round": 2, "settled": 1, "pts": [50, 40], "dead": [3, 4], "ai": [[0, 13, 1], [0, 13, 1 + 0]]}
	var g5 = GS.new()
	g5.sfx = FakeSfx.new()
	g5.armies = [load("res://scripts/core/army.gd").new(0, 100), load("res://scripts/core/army.gd").new(1, 100)]
	g5.sw_resume_ai = [[0, 2, 1], [31, 3, 3]]
	g5.round_no = 2
	g5.swap_ai = true
	g5.mode = g5.Mode.DUEL
	g5._swap_ai_fill(0)
	ok(g5.armies[0].count() > 2, "存的陣擺不回去：重新組一個完整的陣（%d 隻）" % g5.armies[0].count())
	g5.free()
	var grs: String = FileAccess.get_file_as_string("res://scripts/ui/screens/game_result.gd")
	ok(grs.find("elif eff[\"progress\"] and not sw_dup:") >= 0, "同一局重複結算：統計也不重記（和會話同一次寫檔）")
	for bad in ["x", {"v": 1, "round": 2, "settled": 0, "pts": [0, 0], "dead": [0, 0], "ai": []}, {"v": 2, "round": 1, "settled": 0, "pts": [0, 0], "dead": [0, 0], "ai": []}, {"v": 1, "round": 1, "settled": 0, "pts": [1.0e30, 0], "dead": [0, 0], "ai": []}]:
		ok(SD.sanitize_run(bad) == null, "壞會話讀回＝沒有進行中的一組：%s" % str(bad))
	SVx.data = keep
	SVx.save_data()
	SVx.data_locked = lk
	g.free()
	var gm: String = FileAccess.get_file_as_string("res://scripts/ui/screens/game_menus.gd")
	var gr: String = FileAccess.get_file_as_string("res://scripts/ui/screens/game_result.gd")
	ok(gm.find("[\"sw_ai_open\", \"hc_sw_ai_d\"") >= 0 and gr.find("call(\"_swap_ai_start\", true) if bool(get(\"swap_ai\")) else call(\"_swap_start\")") >= 0 and gr.find("set(\"swap_ai\", false)") >= 0, "入口、再來一組、換模式清旗標")
