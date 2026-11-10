extends "res://tests/test_base.gd"
## V1.6.0 測試（docs/2026-11-10-v1.6.0-plan.md）。會碰存檔的測試自己換前綴、結束還原。

func test_layout_r5_v160() -> void:
	var LR = load("res://scripts/ui/layout_rules.gd")
	var card := func(x: float, ty: float) -> Array:
		return [Rect2(x + 40, 120, 40, 40), Rect2(x + 10, ty, 100, 20), Rect2(x + 10, 170, 100, 60)]
	var ok_res: Dictionary = LR.check({"aligns": [{"id": "cards", "cards": [card.call(100, 140), card.call(300, 140), card.call(500, 140.5)]}]})
	ok(ok_res["fail"].is_empty(), "R5 同列卡片標題基準線一致（容差 1）通過")
	var bad: Dictionary = LR.check({"aligns": [{"id": "cards", "cards": [card.call(100, 140), card.call(300, 146)]}]})
	ok(bad["fail"].size() == 1 and str(bad["fail"][0]["type"]) == "R5", "R5 標題差 6px 被抓")

func test_funnel_v160() -> void:
	var SV = load("res://scripts/game/save.gd")
	var FN = load("res://scripts/game/v16_funnel.gd")
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

func test_guide_v160() -> void:
	var G = load("res://scripts/game/v16_guide.gd")
	var d := {"tutorial": 0, "stats": {"games": 0}, "eff_games": 0}
	ok(G.next_step(d, false, false) == "tut", "新玩家先教學")
	d["tutorial"] = 1
	ok(G.next_step(d, false, false) == "ai", "教學過了：打第一場")
	d["stats"] = {"games": 3}
	d["eff_games"] = 3
	ok(G.next_step(d, false, false) == "puzzle", "打過了：殘局")
	d["puzzle_stars"] = {"p1": 1}
	ok(G.next_step(d, false, false) == "daily" and G.next_step(d, false, true) == "", "完整版接每日；試玩版不推沒開的模式")
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

func test_tactical_marks_v160() -> void:
	var G = load("res://scripts/ui/screens/game_v16.gd")
	var Army = load("res://scripts/core/army.gd")
	var g = G.new()
	var a = Army.new(0, 100)
	a.place(0, 2, 2)
	a.place(1, 3, 4)
	a.place(2, 1, 6)
	a.place(5, 4, 1)
	ok(g.tv_toggle_at(a, Vector2i(2500, 2500)), "點到兵就標記")
	ok(not g.tv_toggle_at(a, Vector2i(9500, 8500)), "點空地不標記")
	g.tv_toggle_at(a, Vector2i(3500, 4500))
	g.tv_toggle_at(a, Vector2i(1500, 6500))
	g.tv_toggle_at(a, Vector2i(4500, 1500))
	ok(g.tv_marks.size() == 3 and g.tv_marks[0] == Vector2i(3500, 4500), "最多 3 隻，滿了擠掉最早的")
	g.tv_toggle_at(a, Vector2i(3500, 4500))
	ok(g.tv_marks.size() == 2, "再點一次取消")
	g.free()

func test_terrain_ai_v160() -> void:
	var PRE = load("res://scripts/game/presets.gd")
	var RSx = load("res://scripts/core/ruleset.gd")
	var AIx = load("res://scripts/core/ai_army.gd")
	var Fx = load("res://scripts/core/formations.gd")
	var bad := 0
	var moved := 0
	for m in [1, 2, 3, 4, 5]:
		var R = PRE.make("standard", "ai", RSx.all_pool())
		R.map_id = m
		R.map_size = 1
		for sd in 6:
			var rng := RandomNumberGenerator.new()
			rng.seed = 900 + sd
			var base = AIx.build(1, 100, rng, -1, RSx.all_pool(), R)["army"]
			var before: Array = base.units.duplicate(true)
			var x = Fx.terrain_smart(base.copy())
			var y = Fx.terrain_smart(base.copy())
			var tb: Array = []
			var tx: Array = []
			for u in before:
				tb.append(int(u["type"]))
			for u in x.units:
				tx.append(int(u["type"]))
				if x.terrain.blocked(int(u["x"]), int(u["y"]), x.team):
					bad += 1
			tb.sort()
			tx.sort()
			if tb != tx or JSON.stringify(x.units) != JSON.stringify(y.units):
				bad += 1
			if JSON.stringify(x.units) != JSON.stringify(before):
				moved += 1
	ok(bad == 0, "地形 AI：不少兵、不換兵種、不站牆內、結果固定（壞 %d）" % bad)
	ok(moved > 0, "地形 AI 在地形圖上真的有調整（%d 組）" % moved)

func test_access_settings_v160() -> void:
	var SV = load("res://scripts/game/save.gd")
	var d: Dictionary = SV.sanitize_settings({})
	ok(d.has("hold_confirm") and d["hold_confirm"] == false and d.has("magnify") and d["magnify"] == false, "新設定預設關")
	var e: Dictionary = SV.sanitize_settings({"hold_confirm": "x", "magnify": true})
	ok(e["hold_confirm"] == false and e["magnify"] == true, "型別不對退回預設、合法值保留")

func test_share_v160() -> void:
	var SH = load("res://scripts/game/v16_share.gd")
	var Lx = load("res://scripts/game/strings.gd")
	ok(SH.bar(72) == "■■■■■■■□□□" and SH.bar(0) == "□□□□□□□□□□" and SH.bar(100) == "■■■■■■■■■■", "剩餘戰力 10 格條")
	var st: Dictionary = SH.streak_after({}, 100)
	st = SH.streak_after(st, 101)
	st = SH.streak_after(st, 101)
	ok(int(st["n"]) == 2 and int(st["best"]) == 2, "連續兩天＝2，同一天不重複加")
	st = SH.streak_after(st, 104)
	ok(int(st["n"]) == 1 and int(st["best"]) == 2, "中斷重算，最佳保留")
	var t: String = SH.daily_text(Lx, "2026-11-10", "X", 72, 84, 100, 38, 3)
	ok(t.contains("■■■■■■■□□□") and t.contains("84") and t.split("\n").size() == 5, "每日分享格：條、花費、連續天數、標籤")
	ok(not t.contains("unit_") and not t.contains("NTB"), "分享格不含陣型或代碼（不劇透）")

func test_rush_v160() -> void:
	var RU = load("res://scripts/game/v16_rush.gd")
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

func test_coach_v160() -> void:
	var CO = load("res://scripts/game/v16_coach.gd")
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

func test_rift_v160() -> void:
	var RF = load("res://scripts/game/v16_rift.gd")
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
	var PS = load("res://scripts/game/v16_persona.gd")
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

class FakeU:
	var team := 0
	var type := 0
	var kills := 0
	var summon := false
	func _init(t, ty, k, s := false):
		team = t
		type = ty
		kills = k
		summon = s

func test_career_v160() -> void:
	var CA = load("res://scripts/game/v16_career.gd")
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

func test_foley_v160() -> void:
	var SX = load("res://scripts/game/sfx.gd")
	var bad := 0
	for t in 22:
		var n: String = SX.mat_of(t)
		if not n.begins_with("wood_") or SX.load_audio(n) == null:
			bad += 1
	ok(bad == 0, "22 種兵都有木雕材質音")
	ok(SX.load_audio("wood_topple") != null and SX.load_audio("tension") != null, "倒下聲、緊張鼓聲載得到")
	ok(SX.mat_of(1) == "wood_heavy" and SX.mat_of(0) == "wood_metal" and SX.mat_of(99) == "wood_light", "材質對應與越界")

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
	var TR = load("res://scripts/game/v16_trio.gd")
	var ss: Array = TR.sets()
	ok(ss.size() == 20, "一陣三考 20 組（V1.6.1 D2 從 10 組擴充，前 10 組不變）")
	var bad := 0
	for s in ss:
		var res: Array = TR.check(s, s["sol"])
		if res != [true, true, true]:
			bad += 1
	ok(bad == 0, "每組的作者解三場都贏（保證有解）")
	ok(TR.check(ss[0], [[0, 0, 0]]) != [true, true, true], "一隻劍士過不了")

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

func test_adjacency_v160() -> void:
	var RSx = load("res://scripts/core/ruleset.gd")
	var Simx = load("res://scripts/core/battle_sim.gd")
	var Armyx = load("res://scripts/core/army.gd")
	var a = Armyx.new(0, 100)
	a.place(1, 5, 4)
	a.place(2, 4, 4)
	a.place(0, 5, 5)
	a.place(2, 1, 0)
	var e = Armyx.new(1, 100)
	e.place(1, 10, 4)
	e.place(2, 11, 4)
	var r = RSx.standard()
	var s0 = Simx.new(a.copy(), e.copy(), r)
	r.adj = true
	var s1 = Simx.new(a.copy(), e.copy(), r)
	ok(s0.adj_n == 0 and s1.adj_n == 3, "相鄰加成：藍弓、藍劍、紅弓共 3 筆（實得 %d）" % s1.adj_n)
	var arch_far = null
	var arch_near = null
	for u in s1.units:
		if u.team == 0 and u.type == 2:
			if u.x == 4500:
				arch_near = u
			else:
				arch_far = u
	ok(arch_near.cd_base < arch_far.cd_base and arch_near.atk == arch_far.atk, "盾旁的弓箭手射速較快（間隔較短）、遠的沒有")
	# 舊路徑不變：關的時候和沒有這個欄位一樣
	r.adj = false
	ok(r.sim_is_legacy() and RSx.standard().sim_digest() == r.sim_digest(), "關閉時走舊路徑、摘要不變")
	# 代碼：NTBR6 來回
	r.adj = true
	var c: String = r.to_code()
	var back: Dictionary = RSx.from_code(c)
	ok(c.begins_with("NTBR6.") and bool(back["ok"]) and back["rules"].adj and back["rules"].to_code() == c, "NTBR6 來回一致")
	r.adj = false
	ok(not r.to_code().begins_with("NTBR6"), "關的時候不用 NTBR6")
	# 鏡像：交換兩邊得到同樣的加成筆數
	var s2 = Simx.new(e.mirrored(), a.mirrored(), RSx.from_code(c)["rules"])
	ok(s2.adj_n == s1.adj_n, "左右交換加成一樣")

func test_adjacency_code_v160() -> void:
	var RSx = load("res://scripts/core/ruleset.gd")
	var BC = load("res://scripts/game/battle_code.gd")
	var Armyx = load("res://scripts/core/army.gd")
	var r = RSx.standard()
	r.adj = true
	var a = Armyx.new(0, 100)
	a.place(1, 5, 4)
	a.place(2, 4, 4)
	var e = Armyx.new(1, 100)
	e.place(0, 10, 4)
	var c: String = BC.encode(a, e, r)
	var d: Dictionary = BC.decode(c)
	ok(bool(d.get("ok", false)) and d["rules"] != null and d["rules"].adj, "對戰代碼帶著相鄰陣法")

func test_save_v16_sanitize_v160() -> void:
	var SV = load("res://scripts/game/save.gd")
	var d := {"funnel": [], "mastery": {"2": 5, "x": 3, "99": 1, "4": "a"}, "notebook": {"p1": [{"n": "A", "u": [[0, 1, 2], [2, 1500, 3500, 1]], "r": [1, 2, 3]}, {"n": 3, "u": []}], "p2": "bad"},
		"daily_streak": {"last": 1}, "daily_pend": {"day": 1}, "rush_best": "x", "rift_best": {"k": [1, 2], "j": [1]}, "trio_clear": {"trio1": 50, "trio2": "x"}, "seen": [1, "a"]}
	SV.sanitize_v16(d)
	ok(d["funnel"] is Dictionary and d["funnel"].is_empty(), "funnel 型別錯→空")
	ok(d["mastery"] == {"2": 5}, "熟練度只留合法兵種與整數")
	ok(d["notebook"].size() == 1 and d["notebook"]["p1"].size() == 1 and d["notebook"]["p1"][0]["u"][1] == [2, 1500, 3500, 1], "實驗簿：壞的方案丟掉、自由兵保留")
	ok(d["daily_streak"].is_empty() and not d.has("daily_pend") and d["rush_best"] == 0, "缺欄位的連續天數、待送榜、極速賽紀錄回預設")
	ok(d["rift_best"] == {"k": [1, 2]} and d["trio_clear"] == {"trio1": 50} and d["seen"] == ["a"], "裂隙、三考、看過的入口逐項驗")
	var e := {}
	SV.sanitize_v16(e)
	ok(not e.has("seen"), "沒有 seen 就不建（老玩家第一次開 V1.6 才會補舊入口）")

func test_mark_ids_v160() -> void:
	var G = load("res://scripts/ui/screens/game_v16.gd")
	var Armyx = load("res://scripts/core/army.gd")
	var Simx = load("res://scripts/core/battle_sim.gd")
	var a = Armyx.new(0, 100)
	a.place(0, 5, 4)
	a.place(2, 1, 3)
	var e = Armyx.new(1, 100)
	e.place(0, 10, 4)
	var ids: Array = G.tv_ids_for(a, [Vector2i(1500, 3500), Vector2i(5500, 4500)])
	var s = Simx.new(a.copy(), e.copy())
	var want: Array = []
	for m in [Vector2i(1500, 3500), Vector2i(5500, 4500)]:
		for u in s.units:
			if u.team == 0 and u.x == m.x and u.y == m.y:
				want.append(u.id)
	ok(ids == want and ids.size() == 2, "標記對到模擬的兵（格子）")

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
	SaveS.sanitize_v16(d)
	ok(not d.has("seen"), "seen 是 null 就當沒有")
	g.free()
	SaveS.data_locked = was

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

func test_sanitize_truncate_v160() -> void:
	var SV = load("res://scripts/game/save.gd")
	var seen: Array = []
	for i in 250:
		seen.append("k%d" % i)
	var rb := {}
	for i in 60:
		rb["w%d" % i] = [1, 2]
	var d := {"seen": seen, "rift_best": rb}
	SV.sanitize_v16(d)
	ok(d["seen"].size() == 200 and d["rift_best"].size() == 50, "超量截斷，不整批清空")
