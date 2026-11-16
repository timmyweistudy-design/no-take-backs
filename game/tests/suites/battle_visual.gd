extends "res://tests/test_base.gd"
## 1.1.0 A4：功能測試組「battle_visual」：戰場畫面與手感：標記、鎖定弧、擬音、相鄰、特效、背景工作、版面、手把。
## 從原本依版本分的 v16、v161、v100 搬來，函式名不變（名字尾的 _v160／_v161／_v100／_v110 是做的版本）。會碰存檔的測試自己換前綴、結束還原。

func test_layout_r5_v160() -> void:
	var LR = load("res://scripts/ui/layout_rules.gd")
	var card := func(x: float, ty: float) -> Array:
		return [Rect2(x + 40, 120, 40, 40), Rect2(x + 10, ty, 100, 20), Rect2(x + 10, 170, 100, 60)]
	var ok_res: Dictionary = LR.check({"aligns": [{"id": "cards", "cards": [card.call(100, 140), card.call(300, 140), card.call(500, 140.5)]}]})
	ok(ok_res["fail"].is_empty(), "R5 同列卡片標題基準線一致（容差 1）通過")
	var bad: Dictionary = LR.check({"aligns": [{"id": "cards", "cards": [card.call(100, 140), card.call(300, 146)]}]})
	ok(bad["fail"].size() == 1 and str(bad["fail"][0]["type"]) == "R5", "R5 標題差 6px 被抓")

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

func test_pz_names_l10n_v161() -> void:
	var TR = load("res://scripts/game/trio.gd")
	var L = load("res://scripts/game/strings.gd")
	var s: Dictionary = TR.sets()[0]
	var pz: Dictionary = TR.make_pz(s, 0)
	ok(pz.has("sc") and pz.has("ja") and pz.has("hint_ja") and str(pz["ja"]) != str(pz["en"]), "三考題名有簡中、日文（F6）")
	var WS = load("res://scripts/game/workshop.gd")
	var pz2 := {}
	L.fill(pz2, "", "rl_title", [3])
	ok(str(pz2.get("ja", "")).find("3") >= 0 and str(pz2.get("sc", "")).find("3") >= 0, "接力題名帶參數")

## V1.6.1 F2／N6、V1.0.0 W1／W2：每日、每週榜的假 Steam 替身：分版榜名、上傳失敗、送出後又換成更好的成績、
## 單一通道串行、找榜失敗（下載要回空清單）、逾時、遲到的舊回呼、上傳限額。
func test_board_double_v161() -> void:
	var SV = load("res://scripts/game/save.gd")
	var ST = load("res://scripts/game/steam.gd")
	var keep: Dictionary = SV.data.duplicate(true)
	var old_prefix: String = SV.prefix
	SV.prefix = "t161lb_"
	var fk := FakeLB.new()
	ST.lb_reset()
	ST._steam = fk
	ST.now_ms = 1000
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
	# 在途時又要送：排隊、不重複找榜；佇列裡同一個榜只留最新一筆
	SV.data["daily_pend"] = {"day": 100, "score": 70000, "det": [2, 1, 7], "ver": 1}
	ST.daily_upload(100, 65000, PackedInt32Array([2, 1, 7]), 1)
	ST.daily_upload(100, 68000, PackedInt32Array([2, 1, 7]), 1)
	ST.daily_upload(100, 70000, PackedInt32Array([2, 1, 7]), 1)
	var nf := fk.finds.size()
	fk.emit_signal("leaderboard_find_result", 9, 1)
	ok(fk.finds.size() == nf, "在途時不同時找第二個榜")
	fk.emit_signal("leaderboard_score_uploaded", true, 9, {})
	ok(SV.data.has("daily_pend") and fk.finds.size() == nf + 1, "低分那筆回來：不清，接著送排隊的")
	fk.emit_signal("leaderboard_find_result", 9, 1)
	ok(int(fk.ups[-1][0]) == 70000, "佇列只留最新的高分", str(fk.ups[-1][0]))
	fk.emit_signal("leaderboard_score_uploaded", true, 9, {})
	ok(not SV.data.has("daily_pend"), "高分那筆成功才清")
	# W1：下載的找榜失敗要回空清單（V1.6.1 會卡在讀取中），而且不影響排在後面的上傳
	var got := []
	ST.daily_fetch(100, func(l): got.append(l), 1)
	SV.data["weekly"] = {"wk": 5, "best": 40, "pend": 1, "det": [1, 1, 100510]}
	ST.weekly_upload(5, 40, PackedInt32Array([1, 1, 100510]))
	fk.emit_signal("leaderboard_find_result", 0, 0)
	ok(got.size() == 1 and (got[0] as Array).is_empty(), "找榜失敗：下載回空清單", str(got))
	ok(fk.finds[-1] == "weekly_5", "接著送每週上傳", str(fk.finds))
	fk.emit_signal("leaderboard_find_result", 11, 1)
	SV.data["weekly"]["best"] = 35   # 送出後又刷新最佳
	fk.emit_signal("leaderboard_score_uploaded", true, 11, {})
	ok(int(SV.data["weekly"]["pend"]) == 1, "每週：舊那筆成功不清新的待送")
	ok(ST.clear_pending(SV.data, "weekly_5", 35) and int(SV.data["weekly"]["pend"]) == 0, "每週：同一筆才清")
	# 同一個榜連抓兩次：兩個回呼都要回
	var g2 := []
	ST.daily_fetch(100, func(l): g2.append(1), 1)
	ST.daily_fetch(100, func(l): g2.append(2), 1)
	fk.emit_signal("leaderboard_find_result", 7, 1)
	fk.emit_signal("leaderboard_scores_downloaded", "", 7, [])
	fk.emit_signal("leaderboard_find_result", 7, 1)
	fk.emit_signal("leaderboard_scores_downloaded", "", 7, [])
	ok(g2 == [1, 2], "同榜連抓兩次，兩個回呼都回、不互蓋", str(g2))
	# 逾時：沒有回呼也要結束；之後等那個遲到回呼真的回來才送下一筆（Codex v100-i1 #1）
	var g3 := []
	ST.daily_fetch(100, func(l): g3.append(l), 1)
	fk.emit_signal("leaderboard_find_result", 7, 1)   # 下載送出、回呼不來
	ST.now_ms += ST.LB_TIMEOUT_MS + 1
	ST.lb_tick()
	ok(g3.size() == 1 and (g3[0] as Array).is_empty(), "逾時：下載回空清單")
	var g4 := []
	var nf2 := fk.finds.size()
	ST.daily_fetch(100, func(l): g4.append(l), 1)
	ST.now_ms += 5000
	ST.lb_tick()
	ok(fk.finds.size() == nf2 and g4.size() == 1, "逾時那筆的回呼還沒回來：通道不放，新的下載直接回空")
	fk.emit_signal("leaderboard_scores_downloaded", "", 3, [])   # 別的 handle
	var g5b := []
	ST.daily_fetch(100, func(l): g5b.append(l), 1)
	ok(fk.finds.size() == nf2, "對不上的回呼不算（還在隔離）")
	fk.emit_signal("leaderboard_scores_downloaded", "", 7, [])   # 遲到的那個
	var g4b := []
	ST.daily_fetch(100, func(l): g4b.append(l), 1)
	ok(fk.finds.size() == nf2 + 1 and g4b.is_empty(), "遲到回呼被吃掉，才送新的請求")
	fk.emit_signal("leaderboard_find_result", 7, 1)
	fk.emit_signal("leaderboard_scores_downloaded", "", 7, [])
	ok(g4b.size() == 1, "對得上才回")
	# 遲到回呼一直不來：通道不放；這段時間新的下載直接回空（畫面不卡），上傳留在佇列（Codex v100-i2 #1）
	var g6 := []
	ST.daily_fetch(100, func(l): g6.append(l), 1)
	ST.now_ms += ST.LB_TIMEOUT_MS + 1
	ST.lb_tick()
	ok(g6.size() == 1, "逾時回空")
	var g7 := []
	var nf3 := fk.finds.size()
	SV.data["weekly"] = {"wk": 5, "best": 30, "pend": 1, "det": [1, 1, 100510]}
	ST.weekly_upload(5, 30, PackedInt32Array([1, 1, 100510]))
	ST.daily_fetch(100, func(l): g7.append(l), 1)
	ST.now_ms += 600000
	ST.lb_tick()
	ok(g7.size() == 1 and (g7[0] as Array).is_empty() and fk.finds.size() == nf3, "隔離中：下載直接回空、不送新請求，時間過再久也不放")
	fk.emit_signal("leaderboard_find_result", 0, 0)   # 遲到的那個（找榜階段）終於回來
	ok(fk.finds.size() == nf3 + 1 and fk.finds[-1] == "weekly_5", "遲到回呼回來才放：排著的上傳接著送")
	fk.emit_signal("leaderboard_find_result", 11, 1)
	fk.emit_signal("leaderboard_score_uploaded", true, 11, {})
	ok(int(SV.data["weekly"]["pend"]) == 0, "上傳成功清待送")
	# W2：上傳限額 10 分鐘 10 次（下載不受限）
	ST.lb_reset()
	ST._steam = fk
	ST.now_ms = 5000
	for i in 10:
		SV.data["weekly"] = {"wk": 20 + i, "best": 10, "pend": 1, "det": [1, 1, 100510]}
		ST.weekly_upload(20 + i, 10, PackedInt32Array([1, 1, 100510]))
		fk.names[30 + i] = "weekly_%d" % (20 + i)
		fk.emit_signal("leaderboard_find_result", 30 + i, 1)
		fk.emit_signal("leaderboard_score_uploaded", true, 30 + i, {})
	var nup := fk.ups.size()
	ST.weekly_upload(99, 10, PackedInt32Array([1, 1, 100510]))
	var g5 := []
	ST.daily_fetch(100, func(l): g5.append(l), 1)
	ok(fk.finds[-1] == "daily_100_v1", "第 11 次上傳先等；下載照樣先送", str(fk.finds[-1]))
	fk.emit_signal("leaderboard_find_result", 0, 0)
	ok(fk.finds[-1] == "daily_100_v1" and fk.ups.size() == nup, "限額內不送上傳")
	ST.now_ms += ST.LB_WINDOW_MS
	ST.lb_tick()
	ok(fk.finds[-1] == "weekly_99", "過了 10 分鐘就送", str(fk.finds[-1]))
	ST._steam = null
	ST.lb_reset()
	fk.free()
	for f in DirAccess.get_files_at("user://"):
		if f.begins_with("t161lb_"):
			DirAccess.remove_absolute("user://" + f)
	SV.prefix = old_prefix
	SV.data = keep

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

## A2：同一音效同時最多 3 路。
func test_sfx_same_cap_v100() -> void:
	var S = load("res://scripts/game/sfx.gd")
	ok(S.same_playing([true, true, false, true], {0: "hit", 1: "hit", 2: "hit", 3: "boom"}, "hit") == 2, "只數正在播的同名聲道")
	ok(S.SAME_MAX == 3, "上限 3")

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

## 1.1.0 A7（P2）：新增的鼓手木紋波、狂戰士斧弧是裝飾：4 倍速以上不畫、減少特效時不出。
func test_a7_p2_fx_v110() -> void:
	var F = load("res://scripts/ui/battle/battle_fx.gd")
	for kd in ["woodwave", "axearc", "pages", "bonesup"]:
		ok(kd in F.FAST_SKIP, "%s 高倍速略過" % kd)
	ok(not "slimehop" in F.FAST_SKIP, "史萊姆分裂 4 倍速也要看得到（Gemini v100 r5）")
	var src := FileAccess.get_file_as_string("res://scripts/ui/battle/battle_fx.gd")
	ok(src.contains('d["kind"] in ["slimehop", "pages", "bonesup", "woodwave", "axearc",'), "減少特效時不出")
	for kd2 in ["woodwave", "axearc", "pages", "bonesup", "slimehop"]:
		ok(src.contains('"%s":' % kd2), "%s 有畫法" % kd2)

## 1.1.0 N6：背景工作共用生命週期（BgPool）：開工、叫停回收、取結果、結束全收、進度只在知道上限時有值。
func test_bg_pool_v110() -> void:
	var P = load("res://scripts/game/bg_pool.gd")
	var pool = P.new()
	var ctl: Dictionary = P.make_ctl(5000, {"total": 4})
	ok(P.progress(ctl) == 0.0 and P.progress(P.make_ctl(10)) == -1.0, "進度：有上限 0、沒上限 -1")
	var t: Thread = pool.start(func():
		var n := 0
		while not bool(ctl["stop"]) and Time.get_ticks_msec() < int(ctl["until"]) and n < 4:
			n += 1
			ctl["done"] = n
			OS.delay_msec(5)
		return n, ctl)
	ok(t != null and pool.busy() == 1, "開工")
	while t.is_alive():
		OS.delay_msec(2)
	ok(int(pool.take(t)) == 4 and pool.busy() == 0, "取結果後不再持有")
	var c2: Dictionary = P.make_ctl(60000)
	var t2: Thread = pool.start(func():
		while not bool(c2["stop"]):
			OS.delay_msec(2)
		return "stopped", c2)
	pool.retire(t2)
	ok(bool(c2["stop"]) and pool.old.size() == 1 and pool.live.is_empty(), "叫停後交給回收")
	var guard := 0
	while pool.old.size() > 0 and guard < 500:
		pool.reap()
		OS.delay_msec(2)
		guard += 1
	ok(pool.busy() == 0, "每幀回收收得掉")
	var c3: Dictionary = P.make_ctl(60000)
	pool.start(func():
		while not bool(c3["stop"]):
			OS.delay_msec(2)
		return 0, c3)
	pool.drain()
	ok(pool.busy() == 0 and bool(c3["stop"]), "結束時全部叫停並等完")
	var src := ""
	for f in ["res://scripts/ui/replay_view.gd", "res://scripts/ui/screens/game_v16.gd", "res://scripts/ui/screens/game_modes.gd"]:
		src += FileAccess.get_file_as_string(f)
	ok(not src.contains("Thread.new()") or src.count("Thread.new()") == 0, "五種背景工作不再自己開執行緒")

## 1.1.0 B10：手把重播看戰報：View／Select 開面板（暫停），返回／B 關掉，焦點與暫停狀態還原；正式對戰不開。
func test_breport_pad_v110() -> void:
	var g = load("res://scripts/ui/game_screens.gd").new()
	g.sfx = FakeSfx.new()
	g.state = g.St.BATTLE
	g.play_kind = "replay"
	g.paused = false
	g._focus = 2
	g._key(KEY_F1)
	ok(g.overlay == "breport" and g.paused, "重播按 View 開戰報、暫停")
	g._key(KEY_ESCAPE)
	ok(g.overlay == "" and not g.paused and g._focus == 2, "B 返回：暫停狀態與焦點還原")
	g.paused = true
	g._key(KEY_F1)
	g._breport_close()
	ok(g.paused, "原本就暫停的，關掉後仍暫停")
	g.play_kind = "official"
	g._key(KEY_F1)
	ok(g.overlay == "", "正式對戰不開（底部本來就有戰報列）")
	var items: Array = g._pad_footer_items()
	g.play_kind = "replay"
	g.pad_mode = true
	ok(g._pad_footer_items().size() == items.size() + 1, "重播的按鍵提示多一個戰報")
	g.free()

## 1.1.0 A22：搬出去的純邏輯和畫面腳本的同名函式結果一樣（包裝沒接錯參數）。
func test_pure_rules_v110() -> void:
	var PR = load("res://scripts/game/playroom_rules.gd")
	var SR = load("res://scripts/game/screen_rules.gd")
	var GP = load("res://scripts/ui/screens/game_playroom.gd")
	var G = load("res://scripts/ui/screens/game_v16.gd")
	for r in [0, 33, 34, 66, 67, 100]:
		ok(PR.wager_band(r) == GP.wager_band(r), "賭局區間 %d" % r)
	ok(PR.draft_mask([0, 3]) == 9 and GP.draft_mask([0, 3]) == 9, "輪抽遮罩")
	var wc: String = GP.wave_code(["NTB2.x.y"])
	ok(PR.wave_decode(wc) == ["NTB2.x.y"] and GP.wave_decode(wc) == ["NTB2.x.y"], "車輪戰碼來回")
	ok(PR.week_no(0) == GP.week_no(0) and PR.week_no(1800000000) == GP.week_no(1800000000), "週數")
	ok(G.NB_NAME_MAX == SR.NB_NAME_MAX and G.nb_words_add("a", "b") == "ab" and G.nb_edit_append("a", 66) == "aB", "改名")
	ok(G.coop_player(3) == SR.coop_player(3) and G.coop_rows([1, 2, 1, 4]) == [[1, 2, true, 4]], "合作紀錄")
	ok(G.lock_groups([[0, Vector2i(1, 1)]], 3)["draw"].size() == 1, "鎖定弧分組")
	for f in ["res://scripts/game/playroom_rules.gd", "res://scripts/game/screen_rules.gd"]:
		var src := FileAccess.get_file_as_string(f)
		ok(not src.contains("draw_") and not src.contains("Save.") and not src.contains("get_tree"), "%s 不碰畫面與存檔" % f)

## 1.1.0 B14：刺客遠側短刃平常畫在身體之前（被擋住）、交叉斬才在頭之後；族群底座部件是另一層，王國／奇幻分開。
func test_b14_layers_v110() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/ui/units/kingdom.gd")
	var i_back := src.find("static func _inf_back_items")
	var i_far := src.find("_assassin_far(ci, w, a)", i_back)
	var i_body := src.find("# 身體（圓胖的上衣")
	ok(i_back > 0 and i_far > i_back and src.find("_inf_back_items(ci, type, tc, fl, w, sway, variant, a)   # 背後的東西先畫") < i_body, "遠側短刃在背後物件那一層（身體之前）")
	ok(src.contains("if maxf(0.0, w) >= 0.5:\n\t\t\t\t_assassin_far(ci, w, a)"), "交叉斬時繞到前面")
	var art := FileAccess.get_file_as_string("res://scripts/ui/art.gd")
	ok(art.contains("static func base_trim") and art.contains("base_trim(ci, p, type, scale)"), "底座部件另一層")
	var sc := FileAccess.get_file_as_string("res://scripts/ui/sprite_cache.gd")
	ok(sc.contains("Vector2i(15 * CELL, CELL)") and sc.contains("var fan := 4 if type >= D.COUNT else 0"), "部件烘進合成格（每隻還是一次貼圖），王國／奇幻各一組")

## 1.2.0 §15.1：開覆盤時「原本那一場」的基準在背景算：打開立刻回來、算完才填、離開就叫停。
func test_review_base_async_v120() -> void:
	var g = load("res://scripts/ui/game_screens.gd").new()
	g.sfx = FakeSfx.new()
	g.force_async = true
	var Armyx = load("res://scripts/core/army.gd")
	var a = Armyx.new(0, 100)
	a.place(0, 4, 4)
	a.place(2, 3, 2)
	var e = Armyx.new(1, 100)
	e.place(0, 11, 4)
	g.last_armies = [a, e]
	g.battle_rules = null
	g.last_cmds = []
	g._open_review()
	ok(g.overlay == "review" and g.rv_base.is_empty() and g.rv_base_thread != null, "打開立刻回來，基準在背景算")
	var guard := 0
	while g.rv_base_thread != null and guard < 2000:
		OS.delay_msec(5)
		g._rv_poll()
		guard += 1
	ok(int(g.rv_base.get("ticks", 0)) > 0, "算完填入基準")
	g._open_review()
	g.overlay = ""
	g._rv_poll()
	ok(g.rv_base_thread == null, "離開覆盤就叫停交給回收")
	g.bg.drain()
	g.free()

## 1.2.0 第 3 大類：宣紙戰報什麼時候演、開場三段落子的分段、老闆便條看過就不再出現
func test_present_v120() -> void:
	var g = load("res://scripts/ui/game_screens.gd").new()
	g.sfx = FakeSfx.new()
	var Sv = load("res://scripts/game/save.gd")
	var Ls = load("res://scripts/game/strings.gd")
	var keep_fx = Sv.settings.get("reduce_fx", false)
	var keep_plain = Sv.settings.get("plain_ui", false)
	Sv.settings["reduce_fx"] = false
	Sv.settings["plain_ui"] = false
	g.shot_dir = ""
	g.play_kind = "official"
	g.time = 10.0
	g.result_t = 9.5
	ok(g._ink_active(), "正式對戰剛結束 0.5 秒：演宣紙戰報")
	g.result_t = 8.9
	ok(not g._ink_active(), "超過 1 秒就結束")
	g.result_t = 9.5
	g.play_kind = "replay"
	ok(not g._ink_active(), "重播不演")
	g.play_kind = "official"
	Sv.settings["reduce_fx"] = true
	ok(not g._ink_active(), "減少特效不演")
	Sv.settings["reduce_fx"] = false
	Sv.settings["plain_ui"] = true
	ok(not g._ink_active(), "簡化介面不演")
	Sv.settings["plain_ui"] = false
	g.shot_dir = "x"
	ok(not g._ink_active(), "截圖平常不演")
	g.ink_force = true
	ok(g._ink_active(), "截圖專拍時強制演")
	g.ink_force = false
	g.shot_dir = ""
	# 開場三段落子：離中線近的先落、遠的後落；沒有開場提示時不動
	g.fld_w = 600
	g.start_hold = 0.0
	ok(g._open_drop({"x": 300.0}) == Vector2.ZERO, "沒有開場提示：不位移")
	g.start_hold = 0.8   # 進度 0.2：第一段落到一半，二、三段還在上面
	var near: Vector2 = g._open_drop({"x": 320.0})
	var far: Vector2 = g._open_drop({"x": 20.0})
	ok(near.y > far.y and far.y <= -21.9, "前排先落（%s／%s）" % [near.y, far.y])
	g.start_hold = 0.05
	ok(g._open_drop({"x": 20.0}).y > -0.5, "最後一段在 1 秒內落定")
	g.play_kind = "replay"
	g.start_hold = 0.8
	ok(g._open_drop({"x": 20.0}) == Vector2.ZERO, "重播不演")
	# 老闆便條：知道了＝記進 seen，之後不再畫
	var G = load("res://scripts/game/guide.gd")
	var d := {"seen": []}
	ok(G.is_new(d, "note_lobby"), "第一次是新的")
	G.see(d, "note_lobby")
	ok(not G.is_new(d, "note_lobby") and "note_lobby" in d["seen"], "按知道了之後記住")
	var keep_seen = Sv.data.get("seen", null)
	Sv.data["seen"] = []
	g.overlay = ""
	g._boss_note("place")
	ok(g.overlay == "boss_note" and g.note_key == "place", "第一次擺陣：跳便條疊層")
	var keep_lock = Sv.data_locked
	Sv.data_locked = true   # 不寫真的存檔
	g._close_boss_note()
	Sv.data_locked = keep_lock
	ok(g.overlay == "" and "note_place" in Sv.data["seen"], "知道了：關掉並記住")
	g._boss_note("place")
	ok(g.overlay == "", "看過就不再跳")
	g.overlay = "lobby"   # 大廳本身是疊層：便條疊上去，關掉回大廳（Codex cat03 #2）
	g._boss_note("lobby", "lobby")
	ok(g.overlay == "boss_note" and g.note_ret == "lobby", "大廳便條疊在大廳上")
	Sv.data_locked = true
	g._close_boss_note()
	Sv.data_locked = keep_lock
	ok(g.overlay == "lobby" and g.note_ret == "", "關掉回到大廳")
	g.overlay = ""
	g._boss_note("lobby")
	ok(g.overlay == "", "大廳便條只在大廳疊層上跳")
	Sv.data["seen"] = []
	g._boss_note("result")
	Sv.data_locked = true
	g._key(KEY_ESCAPE)   # Esc／手把 B＝知道了（Codex cat03 #1）
	Sv.data_locked = keep_lock
	ok(g.overlay == "" and "note_result" in Sv.data["seen"], "Esc 關掉便條並記住")
	g.shot_dir = "x"
	g._boss_note("result")
	ok(g.overlay == "", "截圖流程不跳")
	g.shot_dir = ""
	if keep_seen == null:
		Sv.data.erase("seen")
	else:
		Sv.data["seen"] = keep_seen
	for k in ["bn_lobby", "bn_place", "bn_result", "bn_ok"]:
		ok(Ls.t(k) != k, "字串存在：" + k)
	Sv.settings["reduce_fx"] = keep_fx
	Sv.settings["plain_ui"] = keep_plain
	g.free()

## 1.2.0 第 5 大類：姿勢資料化試點（劍士資料＝原公式、命中事件＝模擬命中點）、落子壓扁、不倒翁搖、定格量化
func test_char2_v120() -> void:
	var Art = load("res://scripts/ui/art.gd")
	var PD = load("res://scripts/ui/pose_data.gd")
	var worst := 0.0
	var missing: Array = []
	var bad_hit: Array = []
	for ty in Art.POSE_PROFILE.keys():   # 第 11 大類：22 種全部走資料
		if not PD.has(ty):
			missing.append(ty)
			continue
		if absf(PD.event_t(ty, "hit") - Art.ATK_STRIKE) >= 1e-6:
			bad_hit.append(ty)
		for i in 101:
			var a := i / 100.0
			var got: Array = Art.pose(a, ty)
			var ref: Array = Art._pose_prof(a, Art.POSE_PROFILE[ty]) if a > 0.0 else [0.0, 0.0, 1.0, 1.0, 0.0]   # 原本的公式
			for j in 5:
				worst = maxf(worst, absf(float(got[j]) - float(ref[j])))
	ok(Art.POSE_PROFILE.size() == 22 and missing.is_empty(), "22 種兵都有姿勢資料（缺 %s）" % str(missing))
	ok(bad_hit.is_empty(), "命中事件時間＝模擬命中點（演出不延後；不符 %s）" % str(bad_hit))
	ok(worst < 1e-3, "資料版和原公式 22 種 × 101 點最大差 %.6f" % worst)
	var BU = load("res://scripts/ui/battle/battle_units.gd")
	ok(absf(BU._tumbler(0.0)) < 1e-9 and absf(BU._tumbler(1.0)) < 1e-9, "不倒翁搖：受擊開始與結束都是 0（不跳）")
	var mx := 0.0
	for i in 21:
		mx = maxf(mx, absf(BU._tumbler(i / 20.0)))
	ok(mx > 0.01 and mx <= 0.07, "不倒翁搖幅度 %.3f" % mx)
	var Sv = load("res://scripts/game/save.gd")
	var keep = Sv.settings.get("smooth_pose", false)
	Sv.settings["smooth_pose"] = false
	ok(absf(BU._pose_t(1.0 / 12.0 * 5.5) - 5.0 / 12.0) < 1e-6, "定格：姿勢時間量化到 1/12 秒")
	Sv.settings["smooth_pose"] = true
	ok(absf(BU._pose_t(0.4321) - 0.4321) < 1e-9, "平滑動作：不量化")
	Sv.settings["smooth_pose"] = keep
	var g = load("res://scripts/ui/game_screens.gd").new()
	g.sfx = FakeSfx.new()
	g.play_kind = "official"
	g.fld_w = 600
	g.start_hold = 1.0 - 0.3   # 進度 0.3：第一段（近中線）剛落地 0.05 秒 → 壓扁中
	var sq: float = g._open_squash({"x": 300.0})
	ok(sq < 0.99 and sq >= 0.82, "落子觸盤壓扁 %.3f" % sq)
	ok(g._open_squash({"x": 20.0}) == 1.0, "還沒落下的後排不壓扁")
	g.start_hold = 0.0
	ok(g._open_squash({"x": 300.0}) == 1.0, "開場提示結束後不壓扁")
	g.free()

## 1.2.0 第 9 大類 §8.2 材料碎片：一次最多 4 片、單格最多 2 片、總數 ≤ 30、落地停 0.25 秒＋0.1 秒淡出後消失、同種子同位置
func test_frags_v120() -> void:
	var FR = load("res://scripts/ui/battle/frags.gd")
	var f = FR.new()
	f.spawn(Vector2(160, 130), "wood", 9, 1)
	ok(f.list.size() <= FR.PER_CELL, "同一格最多 %d 片（一次 9 片也只留 %d）" % [FR.PER_CELL, f.list.size()])
	f.clear()
	for k in 40:
		f.spawn(Vector2(20 + k * 50, 200), "ink", 4, k)
	ok(f.list.size() <= FR.TOTAL, "總數 ≤ %d（%d）" % [FR.TOTAL, f.list.size()])
	var newest: int = f._seq - 1   # 最後一片的序號（不是從留下來的裡面取最大值；Codex cat09 #4）
	ok(f.list.any(func(e): return int(e["born"]) == newest), "超額丟最舊的，最後生成的一定留著")
	# 跨格聚集：兩格各 2 片往同一格飛，移動後同一格仍 ≤ 2
	var h = FR.new()
	for k in 2:
		h.list.append({"p": Vector2(140 + k, 110), "z": 0.0, "vx": 0.0, "vz": 0.0, "mat": "ink", "sz": 3.0, "rot": 0.0, "t": 0.0, "land": true, "born": k})
		h.list.append({"p": Vector2(200 + k, 110), "z": 0.0, "vx": -2400.0, "vz": 0.0, "mat": "ink", "sz": 3.0, "rot": 0.0, "t": 0.0, "land": false, "born": 10 + k})
	h.step(0.02)
	var cnt := {}
	for e in h.list:
		var c: Vector2i = h._cell(e["p"])
		cnt[c] = int(cnt.get(c, 0)) + 1
	ok(cnt.values().all(func(v): return v <= FR.PER_CELL), "碎片飛進別格後仍守單格上限", str(cnt))
	f.clear()
	f.spawn(Vector2(300, 300), "fire", 2, 7)
	var t := 0.0
	var landed_at := -1.0
	while not f.list.is_empty() and t < 5.0:
		f.step(1.0 / 60.0)
		t += 1.0 / 60.0
		if landed_at < 0.0 and f.list.all(func(e): return bool(e["land"])):
			landed_at = t
	ok(f.list.is_empty() and landed_at > 0.0 and t - landed_at <= FR.STAY + FR.FADE + 0.05, "落地後 %.2f 秒內消失" % (FR.STAY + FR.FADE))
	var g1 = FR.new()
	var g2 = FR.new()
	g1.spawn(Vector2(50, 50), "leaf", 2, 1234)
	g2.spawn(Vector2(50, 50), "leaf", 2, 1234)
	ok(str(g1.list) == str(g2.list), "同種子同位置（截圖可重現）")
	ok(not FR.MAT.has("glow"), "材料表沒有數位光暈")

## 1.2.0 第 9 大類（Codex cat09 #4）：擴充規則的新事件標籤（急救、接拍、火矢）都已登記、分流合法；
## 射手已經倒下時火矢照樣燒，而且畫面不替它排拉弓或飛箭。
func test_ext_event_routes_v120() -> void:
	var RS0 = load("res://scripts/core/ruleset.gd")
	var Simx = load("res://scripts/core/battle_sim.gd")
	var Armyx = load("res://scripts/core/army.gd")
	var EVS = load("res://scripts/core/events.gd")
	var r = RS0.standard()
	r.ext_skills = 2 | 4 | 8
	var a0 = Armyx.new(0, 100)
	a0.place(2, 0, 4)
	a0.place(7, 3, 3)
	a0.place(8, 3, 5)
	a0.place(0, 5, 4)
	var a1 = Armyx.new(1, 100)
	a1.place(1, 15, 7)
	a1.place(0, 11, 4)
	var g = load("res://scripts/ui/game_screens.gd").new()
	g.sfx = FakeSfx.new()
	var sm = Simx.new(a0.copy(), a1.copy(), r)
	var arch = null
	var foe = null
	var sw = null
	for u in sm.units:
		if u.team == 0 and u.type == 2:
			arch = u
		if u.team == 1 and u.type == 1:
			foe = u
		if u.team == 0 and u.type == 0:
			sw = u
	foe.stun = 200
	sm.ext_fires = [[foe.x, foe.y, 0, 0, sm.units.find(arch)]]
	arch.alive = false   # 射手已倒：火照樣燒
	arch.hp = 0
	sw.hp = 0            # 致命傷：急救契約在死亡判定前救起
	g.sim = sm
	g.view = g.ViewBuffer.new(sm)
	var tags := {}
	var bad: Array = []
	for _k in 60:
		g._pump_view()
	# 直接掃模擬事件（和畫面拿到的同一份）
	var sm2 = Simx.new(a0.copy(), a1.copy(), r)
	var f2 = null
	var ar2 = null
	var sw2 = null
	for u in sm2.units:
		if u.team == 1 and u.type == 1:
			f2 = u
		if u.team == 0 and u.type == 2:
			ar2 = u
		if u.team == 0 and u.type == 0:
			sw2 = u
	f2.stun = 200
	sm2.ext_fires = [[f2.x, f2.y, 0, 0, sm2.units.find(ar2)]]
	ar2.alive = false
	ar2.hp = 0
	sw2.hp = 0
	for _k2 in 60:
		sm2.step()
		for e in sm2.events:
			if not EVS.KINDS.has(e["kind"]):
				bad.append("kind " + str(e["kind"]))
			for tg in e.get("tags", []):
				tags[tg] = true
				if not EVS.TAGS.has(tg):
					bad.append("tag " + str(tg))
			if e.get("tags", []).has("ext_fire") and g.event_route(e) != "attack":
				bad.append("fire route")
	ok(tags.has("rescue") and tags.has("ext_fire") and bad.is_empty(), "急救、火矢標籤出現、都已登記、分流合法", "%s %s" % [tags.keys(), bad])
	ok(not g.proj_tgt.has(arch.id) and not g.atk_hit.has(arch.id), "倒下射手的火矢不排拉弓／飛箭")
	g.free()

## 1.3.0 第 2 大類：桌邊視角（路線 B）——預設開、簡化介面一律正上方；每種有牆的地貌都定了凸起或凹槽；凸起高度不蓋到北側格腳點（半格 16px）
func test_table_view_v130() -> void:
	var SV = load("res://scripts/game/save.gd")
	var keep: Dictionary = SV.settings.duplicate(true)
	var BU = load("res://scripts/ui/battle/battle_units.gd")
	var MD = load("res://scripts/core/map_defs.gd")
	var g = load("res://scripts/ui/game_screens.gd").new()
	SV.settings.erase("table_view")
	SV.settings["plain_ui"] = false
	ok(g.tilt_on(), "預設桌邊視角")
	SV.settings["plain_ui"] = true
	ok(not g.tilt_on(), "簡化介面一律正上方")
	SV.settings["plain_ui"] = false
	SV.settings["table_view"] = false
	ok(not g.tilt_on(), "設定正上方")
	var MA = load("res://scripts/ui/map_art.gd")
	var miss: Array = []
	for mp in MD.MAPS:
		var b := str(mp["biome"])
		if not b in ["grass", "forest"] and not MA._Painter.RELIEF.has(b):   # 平原沒牆；林間的樹本來就是立體物件（刻意不加）
			miss.append(b)
	ok(miss.is_empty(), "每種有牆的地貌都有高度定義（缺 %s）" % str(miss))
	ok(MA._Painter.FACE_H <= 16.0 and BU.BOARD_EDGE_H <= 14.0, "立面高度 ≤ 半格；立面畫在牆格自己裡面（不往北伸）")
	g.free()
	SV.settings = keep

## 1.3.0 第 3 大類：底座形狀雙重編碼（藍圓、紅八角，綁隊伍；色盲也一樣）、棉布拼貼、時刻由模式決定
func test_base_shapes_v130() -> void:
	var Art = load("res://scripts/ui/art.gd")
	ok(Art.base_poly(Vector2.ZERO, 0, 21.0, 10.5).size() == 20 and Art.base_poly(Vector2.ZERO, 1, 21.0, 10.5).size() == 8, "實際用的底座形狀：藍方圓（20 邊）、紅方八角（8 邊）")
	var art_src := FileAccess.get_file_as_string("res://scripts/ui/art.gd")
	var sc_src := FileAccess.get_file_as_string("res://scripts/ui/sprite_cache.gd")
	ok(art_src.contains("ring_base(ci, p, scale, 1.0, team)"), "合成格的底座照隊伍畫（ring 傳 team）")
	ok(sc_src.contains("Rect2((14 if team == 1 else 4) * CELL") and sc_src.count("(14 if team == 1 else 4)") == 2, "跳起來分層、倒下底座都照隊伍取格")
	var BU = load("res://scripts/ui/battle/battle_units.gd")
	var a: Texture2D = BU._cotton_tex(true)
	var b: Texture2D = BU._cotton_tex(false)
	ok(a != null and b != null and a.get_width() == 64 and a != b, "棉布拼貼：有格線／無格線兩張、一格 64px")
	var img: Image = a.get_image()
	ok(img.get_pixel(0, 10).a > 0.3 and img.get_pixel(3, 0).a < 0.2, "格線一針一針（每 4px 留縫）")

## 1.3.0 第 4 大類：角色 1.25 倍、跟拍 1.4 倍、頭頂資訊跟著縮放、掉漆貼花
func test_unit_scale_v130() -> void:
	var UB = load("res://scripts/ui/ui_base.gd")
	ok(absf(UB.UNIT_SCALE / 0.92 - 1.25) < 0.001 and absf(UB.HK - UB.UNIT_SCALE / 0.92) < 0.001, "戰場角色 1.25 倍；頭頂資訊倍率＝同一比例")
	var g = load("res://scripts/ui/game_screens.gd").new()
	g.follow_id = 7
	ok(absf(g.focus_scale(7) * 1.25 - 1.4) < 0.001 and g.focus_scale(3) == 1.0, "跟拍那隻 1.4 倍、其他照舊")
	g.follow_id = -1
	ok(g.focus_scale(7) == 1.0, "沒跟拍時都照舊")
	var ct: Texture2D = UB.chip_tex()
	ok(ct != null and ct.get_width() == 64 and ct.get_height() == 32, "掉漆貼花兩格（一塊／兩塊）")
	var img: Image = ct.get_image()
	ok(img.get_pixel(12, 14).a > 0.5 and img.get_pixel(44, 12).a > 0.5 and img.get_pixel(52, 21).a > 0.5, "兩格都有漆塊")
	ok(UB.CHIP_ANCHOR.has(3) and UB.CHIP_ANCHOR.has(19), "騎兵、小石魔的掉漆位置另外定")
	g.free()

## 1.3.0 第 5 大類：依移動方向選視角（往南＝3/4 正面、往北＝3/4 背面、東西＝側面；不走路一律側面；跳轉清掉）
func test_heading_view_v130() -> void:
	var g = load("res://scripts/ui/game_screens.gd").new()
	ok(g.heading_of(1, 1, 10, true) == 1, "模擬移動往南為主＝3/4 正面")
	ok(g.heading_of(2, -2, -10, true) == -1, "往北為主＝3/4 背面")
	ok(g.heading_of(3, 10, 4, true) == 0, "東西為主＝側面")
	ok(g.heading_of(4, 10, 12, true) == 0, "南北只略大（<×1.3）＝還是側面")
	ok(g.heading_of(1, 10, 11, true) == 1, "遲滯：已在往南，南北仍大於東西就不回側面")
	ok(g.heading_of(1, 10, 9, true) == 0, "南北小於東西才回側面")
	ok(g.heading_of(1, 0, 10, true) == 1 and g.heading_of(1, 0, -10, true) == -1, "掉頭直接換南北")
	ok(g.heading_of(1, 0, 10, false) == 0 and not g.hd_state.has(1), "不走路（出手、受擊、待機）一律側面並清掉")
	ok(g.heading_of(5, 0, 0, true) == 0, "這 tick 沒提出移動＝側面（擊退不算）")
	g.heading_of(6, 0, 10, true)
	g._gait_reset()
	ok(g.hd_state.is_empty(), "跳轉／新的一場清掉走向記錄")
	var src: String = FileAccess.get_file_as_string("res://scripts/ui/battle/battle_units.gd")
	ok(src.find("heading_of(u.id, u.mx, u.my") >= 0 and src.find("hurt <= 0.0") >= 0, "走向用模擬的 mx／my，受擊時不轉")
	ok(src.find("sprites.wt_loc.has(u.type)") >= 0, "沒有轉身頁時不硬轉（避免只橫縮）")
	var SC = load("res://scripts/ui/sprite_cache.gd")
	ok(SC.BW_C == 0.55 and g.HEAD_FRONT_C == 0.55, "南北都用 3/4 角度（和既有走路轉身頁同角度）")
	ok(SC.BW_MAX >= 22, "背面頁上限涵蓋一場所有兵種（不在場上被淘汰回側面）")
	g.free()

## 1.3.0 第 6 大類：導播（精華三連挑段、導播鏡頭目標、放大鏡角落、手動接管）
func test_director_v130() -> void:
	var DR = load("res://scripts/game/director_rules.gd")
	var marks := [{"t": 100}, {"t": 150}, {"t": 400}, {"t": 700}, {"t": 900}, {"t": 1210}]
	var r: Array = DR.pick_reel(marks, 1250)
	ok(r.size() == 3 and bool(r[2].get("final", false)) and int(r[2]["t"]) == 1250, "最多三段、終局排最後")
	var ts: Array = []
	for m in r:
		ts.append(int(m["t"]))
	var dedup := true
	for i in range(1, ts.size()):
		dedup = dedup and ts[i] - ts[i - 1] >= DR.SEG_LEN
	ok(dedup and not 150 in ts and not 1210 in ts, "相距不到一段的去重、和終局重疊的不要")
	ok(DR.reel_seconds(r) <= 15.0, "精華三連 ≤15 秒")
	ok(DR.pick_reel([{"t": 1200}], 1250).size() == 1, "不足兩個獨立事件只出一段（不硬湊）")
	ok(DR.pick_reel([], -1).is_empty() and DR.pick_reel([{"t": 50}], -1).size() == 1, "沒有終局也能挑")
	var fc := Vector2(500, 300)
	ok(float(DR.director_target(5, false, Vector2.ZERO, 0, fc, 1000.0)[0]) == 1.2, "開戰巡盤")
	var a: Vector2 = DR.director_target(0, false, Vector2.ZERO, 0, fc, 1000.0)[1]
	var b: Vector2 = DR.director_target(DR.TOUR_TICKS - 1, false, Vector2.ZERO, 0, fc, 1000.0)[1]
	ok(a.x < fc.x and b.x > fc.x, "巡盤從一軍到另一軍")
	var z: float = DR.director_target(100, false, Vector2(200, 200), 6, fc, 1000.0)[0]
	ok(z >= 1.2 and z <= 1.4, "交戰區推近 1.2～1.4 倍")
	ok(float(DR.director_target(100, false, Vector2.ZERO, 1, fc, 1000.0)[0]) == 1.0 and float(DR.director_target(100, true, Vector2(1, 1), 9, fc, 1000.0)[0]) == 1.0, "沒交戰、勝負已分＝全景")
	var cs := [Vector2(100, 600), Vector2(1180, 600), Vector2(100, 200), Vector2(1180, 200)]
	ok(DR.mag_corner(cs, Vector2(150, 580), -1, [], 260.0) == 3, "放大鏡放在離那隻最遠的角")
	ok(DR.mag_corner(cs, Vector2(1150, 220), -1, [3], 260.0) == 0, "被排除的角不用")
	ok(DR.mag_corner(cs, Vector2(700, 400), 1, [], 260.0) == 1, "遲滯：那隻沒靠近就不換角")
	var SV = load("res://scripts/game/save.gd")
	ok(bool(SV.DEFAULT_SETTINGS["spotlight"]) and bool(SV.DEFAULT_SETTINGS["battle_mag"]) and bool(SV.DEFAULT_SETTINGS["auto_director"]), "三個設定預設開")
	var g = load("res://scripts/ui/game_screens.gd").new()
	g.play_kind = "official"
	g.view = load("res://scripts/ui/view_buffer.gd").new()
	ok(not g._dir_on(), "正式對局不自動動鏡頭（只動小窗）")
	g.play_kind = "replay"
	ok(g._dir_on() == (bool(SV.s("auto_director")) and not bool(SV.s("reduce_motion"))), "重播時導播接手")
	g.cam_wheel(true, Vector2(640, 400))
	ok(g.dir_manual and g.pinch_zoom > 1.01, "滾輪放大＝交還手動")
	ok(not g._dir_on(), "交還手動後導播不再動")
	g.hl_reel = [100, 300]
	g.follow_id = 4
	g.cam_wheel(true, Vector2(640, 400))
	ok(g.hl_reel.is_empty() and g.follow_id == -1, "動鏡頭＝精華三連停在這裡、重播跟拍放掉（手動優先）")
	g._btns = [{"r": Rect2(600, 300, 100, 40), "cb": func(): pass, "en": true}]
	ok(not g._field_hit(Vector2(650, 320)), "按鈕上雙擊不算回全景")
	g._btns = []
	var bsrc: String = FileAccess.get_file_as_string("res://scripts/ui/battle_view.gd")
	ok(bsrc.find("u.hidden or u.stealth > 0") >= 0, "偽裝、潛行的不給放大鏡特寫")
	var rsrc: String = FileAccess.get_file_as_string("res://scripts/ui/replay_view.gd")
	ok(rsrc.find("cues.clear()") >= 0, "跳轉清掉技能預告")
	g.follow_id = 3
	g.cam_reset()
	ok(g.pinch_zoom == 1.0 and g.follow_id == -1, "雙擊回全景、取消選取")
	g.free()
	# 暫停資料卡與放大鏡讀的冷卻、戰績：展示單位原本沒帶（讀 cd 會出錯），現在跟快照一起帶
	var VB = load("res://scripts/ui/view_buffer.gd")
	var fr: Dictionary = {"tick": 5, "units": [[0, 0, 0, 100, 100, 50, 60, true, 0, 0, 1, 0, 0, 0, 0, -1, 0, 0, 0, 0, -1, 0, 0, false, 0, 0, 0, 0, 0, 0, 0]], "ux": [[7, 33, 2]],
		"events": [], "rally": [false, false], "frenzy": false, "finished": false, "power": [1, 1], "alive": [1, 0]}
	var vb = VB.new()
	vb.apply(fr)
	ok(vb.units[0].cd == 7 and vb.units[0].dmg_dealt == 33 and vb.units[0].kills == 2, "展示單位帶冷卻、輸出、擊倒")

## 1.3.0 第 7 大類：技能演出三拍（預告、狀態竹籤、範圍墨漬）
func test_skill_cues_v130() -> void:
	var g = load("res://scripts/ui/game_screens.gd").new()
	for i in 30:
		g._cue_add("charge", 1, 2, 100 + i)
	g._cue_add("charge", 1, 2, 129)
	ok(g.cues.size() == g.CUE_MAX, "預告有上限、同一筆不重複")
	var src: String = FileAccess.get_file_as_string("res://scripts/ui/battle_view.gd")
	ok(src.find("e[\"kind\"] == EV.CHARGE or e[\"kind\"] == EV.BRACED") >= 0, "衝鋒、架盾從展示緩衝拿命中 tick（不提前洩漏模擬）")
	ok(src.find("if hit < view.tick:") >= 0, "命中後不再畫預告")
	var V = load("res://scripts/ui/view_buffer.gd")
	g.view = V.new()
	for i in 2:
		var u = V.VUnit.new()
		u.id = i
		u.team = i
		u.alive = true
		u.x = 3000 + i * 1000
		u.y = 3000
		g.view.units.append(u)
	g._status_tags(true)
	ok(g.fx.is_empty(), "沒有狀態就沒有竹籤")
	g.view.units[0].stun = 10
	g._status_tags(true)
	var tags := 0
	for f in g.fx:
		if f["kind"] == "tag":
			tags += 1
	ok(tags == 1, "定身開始的那一 tick 出一根竹籤")
	g._status_tags(true)
	tags = 0
	for f in g.fx:
		if f["kind"] == "tag":
			tags += 1
	ok(tags == 1, "持續定身不再出")
	g.view.units[1].breach = 5
	g._status_tags(false)
	tags = 0
	for f in g.fx:
		if f["kind"] == "tag":
			tags += 1
	ok(tags == 1 and g.stat_prev[1][1], "跳轉補播（不演）只記狀態不出竹籤")
	g.fx.clear()
	for i in 8:
		g._stain(Vector2(100, 100), 40.0, i % 2 == 0, i)
	var n := 0
	for f in g.fx:
		if f["kind"] == "stain":
			n += 1
	ok(n <= g.STAIN_MAX, "墨漬同時最多 %d 灘" % g.STAIN_MAX)
	var PALx = load("res://scripts/ui/palette.gd")
	ok(PALx.BAMBOO != PALx.BAMBOO_D, "竹籤色在色票")
	var fxs: String = FileAccess.get_file_as_string("res://scripts/ui/battle/battle_fx.gd")
	ok(fxs.find("\"stain\":") >= 0 and fxs.find("\"tag\":") >= 0, "墨漬、竹籤有畫法")
	var csv: String = FileAccess.get_file_as_string("res://data/strings.csv")
	ok(csv.find("\ntag_stun,") >= 0 and csv.find("\ntag_breach,") >= 0, "竹籤字有四語")
	g.free()

## 1.4.0 第 5～7 大類：戰場可讀（接觸陰影、虛線底座、牛皮紙標籤、地圖名）、動作切片 B（壓縮拉長、即時配件）、技能演出（噪音預算、地面演出、軍令朱印、重量頓幀、重播推近）
func test_battle_v140() -> void:
	var GS = load("res://scripts/ui/game_screens.gd")
	ok(GS.spring_angle(0, 1.0, 0.0, 0.0, 0.0, 3) == GS.spring_angle(0, 1.0, 0.0, 0.0, 0.0, 3), "即時配件角度是純函式（同時刻同結果、不同幀率一樣）")
	ok(GS.spring_angle(0, 1.0, 0.0, 0.0, 0.0, 3) != GS.spring_angle(0, 1.0, 0.0, 0.0, 0.0, 4), "每隻相位不同（不會整軍齊震）")
	ok(GS.spring_angle(5, 1.0, 1.0, 0.2, 0.5, 1) == 0.0, "只有劍士、弓箭手、騎兵有即時配件")
	ok(absf(GS.spring_angle(3, 2.0, 0.0, 0.3, 0.0, 1) - GS.spring_angle(3, 2.0, 0.0, 0.0, 0.0, 1)) > 0.3, "往前衝時配件往後拖")
	var BS = load("res://scripts/ui/battle/battle_state.gd")
	ok(int(BS.FX_CLASS_CAP["high"]) == 6 and int(BS.FX_CLASS_CAP["low"]) == 24 and int(BS.FX_CLASS_CAP["scar"]) == 12, "噪音預算上限（方案 §6.1）")
	ok(not BS.FX_CLASS.has("tag") and not BS.FX_CLASS.has("stain") and "stain" in BS.FX_CAP_EXEMPT, "關鍵提示不在預算表（竹籤、茶漬範圍提示不吃額度、不被全域上限淘汰）")
	var lo := 99.0
	var hi := -99.0
	for k in 400:
		var wa: float = GS.spring_angle(2, 1.0, 1000.0 + k * 0.37, 0.0, 0.0, 1)
		lo = minf(lo, wa)
		hi = maxf(hi, wa)
	ok(hi - lo <= 2.0 * (0.16 + 0.22) + 0.001, "走路相位累積很大時擺幅仍有界（Codex cat05 #3）")
	ok(absf(GS.spring_angle(2, 1.0, -200.0, 0.0, 0.0, 1) - GS.spring_angle(2, 1.0, 0.0, 0.0, 0.0, 1)) < 0.0001, "暈眩／拖行姿勢碼不當走路相位")
	ok(GS.spring_angle(0, 3.3, 2.0, 0.2, 0.5, 7, true) == float(GS.SPRING[0][4]), "減少動態：配件靜止")
	var g = GS.new()
	g.speed = 1.0
	g.fx.clear()
	for i in 6:
		g._add_fx({"kind": "boom", "p": Vector2(100 + 100 * maxi(0, i - 1), 100), "t": 0.0, "dur": 1.0})   # 前兩個同處
	g._add_fx({"kind": "boom", "p": Vector2(100, 100), "t": 0.0, "dur": 1.0})   # 同處第 3 個：被去重拒收
	var nb := 0
	for f in g.fx:
		if f["kind"] == "boom":
			nb += 1
	ok(nb == 6 and g.fx[0]["p"] == Vector2(100, 100), "類別淘汰在去重之後：被拒收的不會先刪掉舊的（Codex cat05 #2）")
	g.fx.clear()
	for i in 45:
		g._add_fx({"kind": "slash", "p": Vector2(i * 30, 50), "t": 0.0, "dur": 1.0})
	g._stain(Vector2(300, 300), 40.0, true, 1)
	for i in 10:
		g._add_fx({"kind": "slash", "p": Vector2(i * 30, 90), "t": 0.0, "dur": 1.0})
	var ns := 0
	for f in g.fx:
		if f["kind"] == "stain":
			ns += 1
	ok(ns == 1, "茶漬範圍提示在特效滿載時也不被淘汰（Codex cat05 #1）")
	g.fx.clear()
	ok(g.HITSTOP_W[0] == 0.0 and g.HITSTOP_W[2] == 0.06, "頓幀用固定呈現時間（不是幀數）")
	g.play_kind = "official"
	g.view = load("res://scripts/ui/view_buffer.gd").new()
	g._dir_hot(Vector2(100, 100))
	ok(g.dir_hot_until < 0.0, "實戰不推近（招牌鏡頭只在重播）")
	g.free()
	var bvs: String = FileAccess.get_file_as_string("res://scripts/ui/battle_view.gd")
	var i_tag := bvs.find("fx[-1][\"cmd_tm\"] = tm")
	ok(i_tag >= 0 and i_tag < bvs.find("\"kind\": \"cmdseal\""), "軍令橫幅的隊別標記標在橫幅上（不是後加的朱印；舊橫幅才清得掉）")
	var bu: String = FileAccess.get_file_as_string("res://scripts/ui/battle/battle_units.gd")
	ok(bu.find("inner.position.x + 18.0, inner.position.y - 9") >= 0, "地圖名刻在盤框左上角（不被戰報條切到）")

func test_battle_read_v150() -> void:
	var GS = load("res://scripts/ui/game_screens.gd")
	ok(GS.is_num_text("12") and GS.is_num_text("-8") and GS.is_num_text("+30") and GS.is_num_text("×3" + String.chr(0xFF08) + "24" + String.chr(0xFF09)) and GS.is_num_text(String.chr(0xFF11) + String.chr(0xFF12)) and GS.is_num_text(String.chr(0x2212) + "5") and GS.is_num_text(String.chr(0xFF0B) + String.chr(0xFF13) + String.chr(0xFF10)), "數字型跳字（含合併「×3（24）」、全形、各種負號）不包泡泡")
	ok(not GS.is_num_text("擊倒") and not GS.is_num_text("x2") and not GS.is_num_text("") and not GS.is_num_text("×") and not GS.is_num_text("衝鋒！35"), "有字的、空的、只有符號的照舊")
	var VB = load("res://scripts/ui/view_buffer.gd")
	var us: Array = []
	for i in 4:
		var u = VB.VUnit.new()
		u.id = 10 + i
		u.team = 0 if i < 2 else 1
		u.alive = true
		u.target = -1
		us.append(u)
	us[0].target = 2
	ok(GS.pick_focus(us, 10) == [10, 12], "焦點＝跟拍的兵＋它的目標（快照的 target，逐 tick）", str(GS.pick_focus(us, 10)))
	ok(GS.pick_focus(us, -1).is_empty(), "沒跟拍：沒有焦點（不亂畫）")
	us[2].alive = false
	ok(GS.pick_focus(us, 10) == [10, -1], "目標倒了：只剩跟拍的兵")
	us[0].target = 1
	ok(GS.pick_focus(us, 10) == [10, -1], "目標是自己人（補血）：不畫成攻擊對象")
	us[0].alive = false
	ok(GS.pick_focus(us, 10).is_empty(), "跟拍的兵倒了：沒有焦點")
	us[0].alive = true
	us[0].target = 99
	ok(GS.pick_focus(us, 10) == [10, -1], "目標索引超出範圍：不當掉")
	ok(GS.hp_bar_alpha(10, [10, 12]) == 1.0 and GS.hp_bar_alpha(12, [10, 12]) == 1.0 and GS.hp_bar_alpha(11, [10, 12]) == 0.55 and GS.hp_bar_alpha(11, [10, 12], true) == 1.0, "血條：跟拍兵與目標、低血量不透明，其他淡")
	var bu: String = FileAccess.get_file_as_string("res://scripts/ui/battle/battle_units.gd")
	ok(bu.find("pick_focus(s.units, follow_id)") >= 0 and bu.find("time - float(hurt") < 0 or bu.find("static func pick_focus(units: Array, follow: int)") >= 0, "焦點不看動畫時鐘（暫停、跳轉、固定時鐘截圖一致）")

func test_tag_shape_v150() -> void:
	var GS = load("res://scripts/ui/game_screens.gd")
	var r := Rect2(100, 50, 80, 24)
	var pts: PackedVector2Array = GS.tag_poly(r)
	var inside := true
	for p in pts:
		inside = inside and r.grow(0.01).has_point(p)
	ok(inside and pts.size() >= 8, "短標吊牌外形全部在原本的框內（字的幾何不動）")
	ok(Geometry2D.triangulate_polygon(pts).size() > 0, "吊牌多邊形可以三角化（畫得出來）")

func test_clutch_frame_v150() -> void:
	var GS = load("res://scripts/ui/game_screens.gd")
	ok(GS.clutch_glow(0.0, 1.0, false) == 0.0, "沒有最後時刻：不發光")
	ok(GS.clutch_glow(8.0, 1.0, true) == 0.0 and GS.clutch_glow(7.6, 1.0, true) == 1.0, "最後時刻開始 0.3 秒內淡入")
	ok(GS.clutch_glow(5.0, 0.3, true) == 1.0 and GS.clutch_glow(5.0, 0.3, false) < 1.0, "減少動態：不呼吸（定值）")
	var bu: String = FileAccess.get_file_as_string("res://scripts/ui/battle/battle_units.gd")
	ok(bu.find("draw_rect(fr.grow(11.0 - k * 2.5)") >= 0, "暖光只畫在木框帶上（盤外），不碰盤面")

## 1.6.0 B09（S7；P10.2）預設外觀離線圖集包：兵種條拆拼逐像素一致、環境鍵、壞包整包停用、包讀回＝烘的時候的像素（解碼差 0）、過期包不用
func test_atlas_pack_v1600() -> void:
	var AP = load("res://scripts/ui/atlas_pack.gd")
	var SC = load("res://scripts/ui/sprite_cache.gd")
	# 兵種條：一頁拆成每種一條、再拼回來要逐像素一樣（包以兵種為單位，頁怎麼組都拼得回來）
	var per: int = 2 * SC.FRAMES_PER
	var rows := int(ceil(float(SC.TYPES_PER_PAGE * per) / SC.COLS))
	var page := Image.create(SC.COLS * SC.CELL, rows * SC.CELL, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1600
	for c in SC.TYPES_PER_PAGE * per:
		page.fill_rect(Rect2i((c % SC.COLS) * SC.CELL + rng.randi_range(0, 100), (c / SC.COLS) * SC.CELL + rng.randi_range(0, 100), 60, 60), Color(rng.randf(), rng.randf(), rng.randf(), 1))
	var strips: Array = []
	for k in SC.TYPES_PER_PAGE:
		strips.append(SC.strip_of(page, k))
	ok(SC.page_from(strips, rows).get_data() == page.get_data(), "兵種條拆開再拼回整頁逐像素一樣")
	ok(SC.TYPES_PER_PAGE * SC.MAX_PAGES >= 30, "頁變小後總容量不變（≥30 種）")
	# 環境鍵：JSON 數字讀回是 float 也算同；引擎不同＝不用
	var e: Dictionary = AP.env_key()
	var m: Dictionary = e.duplicate()
	m["format"] = float(e["format"])
	ok(AP.env_match(m, e) == "", "清冊數字是 float 也比得上")
	m["engine"] = "4.7.0-stable"
	ok(AP.env_match(m, e).begins_with("engine"), "引擎版本不同＝包不能用")
	# 壞包：讀失敗一次就整包停用、退回即時烘
	AP.reset()
	AP.fail("type3", "測試")
	ok(not AP.usable() and AP.misses == 1, "讀包失敗一次＝整包停用")
	AP.reset()
	var sc: String = FileAccess.get_file_as_string("res://scripts/ui/sprite_cache.gd")
	ok(sc.find("Art.paint_sig() == AtlasPack.DEFAULT_PAINT") >= 0, "只有預設塗裝讀包（特殊塗裝照舊即時烘）")
	ok(sc.find("if g0 != _gen:\n\t\t\treturn null") >= 0, "讀包回來世代變了＝作廢、不停用包（重建競態）")
	# 注入：user:// 的假包（Codex B09 r1 #6）——換錯檔（同尺寸）、檔案雜湊不符、清冊不完整、來源過期都要擋
	var real_dir: String = AP.dir
	AP.dir = "user://test_pack_v1600"
	AP.saved_sha.clear()
	AP.saved_fsha.clear()
	var ia := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	ia.fill(Color(1, 0, 0, 1))
	var ib := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	ib.fill(Color(0, 0, 1, 1))
	AP.save(0, "a", ia)
	AP.save(0, "b", ib)
	var fake: Dictionary = AP.env_key()
	fake["src"] = AP.src_key()
	fake["paint"] = AP.DEFAULT_PAINT
	fake["files"] = 2
	fake["selfcheck_mismatch"] = 0
	fake["selfcheck_pages"] = 1
	fake["sha"] = AP.saved_sha.duplicate()
	fake["fsha"] = AP.saved_fsha.duplicate()
	var wf := func(d: Dictionary):
		var f := FileAccess.open(AP.dir + "/manifest.json", FileAccess.WRITE)
		f.store_string(JSON.stringify(d))
		f.close()
		AP.reset()
	wf.call(fake)
	ok(AP.usable() and AP.verify_file(0, "a") and AP.verify_file(0, "b"), "假包：清冊完整、檔案雜湊對得上＝能用")
	ok(AP.verify_pixels(0, "a", load(AP.path(0, "a"))) and not AP.verify_pixels(0, "a", ib), "像素雜湊：讀回＝烘的；別張同尺寸的圖＝不符")
	DirAccess.copy_absolute(ProjectSettings.globalize_path(AP.path(0, "b")), ProjectSettings.globalize_path(AP.path(0, "a")))   # 換錯檔（同尺寸）
	ok(not AP.verify_file(0, "a"), "同尺寸換錯檔＝檔案雜湊不符、不讀")
	var f2 := fake.duplicate(true)
	f2["fsha"].erase("cb0/b")
	wf.call(f2)
	ok(not AP.usable() and AP.why.begins_with("清冊不完整"), "清冊少一筆檔案雜湊＝整包不用")
	var f3 := fake.duplicate(true)
	f3["src"] = "0000000000000000"
	wf.call(f3)
	ok(not AP.usable() and AP.why.begins_with("來源改過"), "來源雜湊不同（畫法改過）＝包過期不用")
	var f4 := fake.duplicate(true)
	f4["paint"] = "11220"
	wf.call(f4)
	ok(not AP.usable(), "清冊塗裝不是預設＝不用")
	for k in ["a", "b"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(AP.path(0, k)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(AP.dir + "/manifest.json"))
	AP.dir = real_dir
	AP.reset()
	var man: Dictionary = AP.manifest()
	if man.is_empty():
		ok(not AP.usable(), "沒有包（新複製的專案）＝照舊即時烘")
		return
	var stale: bool = str(man.get("src", "")) != AP.src_key()
	if stale:
		ok(not AP.usable() and AP.why.begins_with("來源改過"), "包過期（畫法改過）＝執行時不用、匯出前重烘")
		return
	ok(int(man.get("selfcheck_mismatch", -1)) == 0 and int(man.get("selfcheck_pages", 0)) > 0, "烘包自我核對：拼回的頁和畫出來的一樣")
	var sha: Dictionary = man.get("sha", {})
	ok(sha.size() == int(man.get("files", -1)) and sha.size() >= 100 and (man.get("fsha", {}) as Dictionary).size() == sha.size(), "清冊每張圖都有像素與檔案雜湊（%d 張）" % sha.size())
	ok(AP.usable(), "真包：這份程式＋這台環境能用")
	var bad := 0
	for k in sha:
		var parts: PackedStringArray = str(k).split("/")
		var cbn := int(parts[0].substr(2))
		var img = load(AP.path(cbn, parts[1]))
		if not (img is Image) or not AP.verify_pixels(cbn, parts[1], img) or not AP.verify_file(cbn, parts[1]):
			bad += 1
	ok(bad == 0, "包讀回的每張圖＝烘的時候的像素、檔案沒被換（解碼差 0；%d 張）" % sha.size())


## 1.6.0 B08（S4；P3.3～P3.5）：混戰看得懂——用正式畫面程式逐幀播 6 場（60fps），每幀量：
## 顯示中跳字蓋到兵偶頭胸框的面積 0、出盤內 12px 的 0、跳字總面積 ≤ 交戰區 15%；關鍵跳字不漏；
## 裝飾特效單一面積 ≤ 交戰區 4%、最亮 ≤0.8。另有人造擁擠例（頭胸框擋在原位）與找不到位置時的處理。
func test_melee_read_v1600() -> void:
	var GS = load("res://scripts/ui/game_screens.gd")
	var g = GS.new()
	g.sfx = FakeSfx.new()
	g._load_fonts()
	var pool := F.training_pool(0)
	var face := 0
	var clip := 0
	var area := 0.0
	var fx_a := 0.0
	var fx_l := 0.0
	var frames := 0
	var shown := 0
	var lay_us: Array = []
	# 情境（Codex B08 r1 #6）：0、1 一般 1×；2 倍速 2×；3 倍速 4×（一般跳字不出、關鍵照出）；4 跟拍放大（focus_scale）；
	# 5 中途暫停 120 幀再播、再跳轉回第 40 tick 重播一段
	for i in 6:
		var arm := [pool[i * 3].copy(), pool[(i * 17 + 4) % pool.size()].mirrored()]
		g._begin_battle(arm[0].copy(), arm[1].copy(), "replay")
		g.last_armies = arm   # 跳轉從這組陣型快轉
		g.speed = [1.0, 1.0, 2.0, 4.0, 1.0, 1.0][i]
		var guard := 0
		var paused_n := 0
		var seeked := false
		while g.state == g.St.BATTLE and not g.view.finished and guard < 9000:
			guard += 1
			if i == 4 and g.follow_id < 0:
				for u in g.view.units:
					if u.alive:
						g.follow_id = u.id
						break
			if i == 5 and guard == 600:
				g.paused = true
			if g.paused:
				paused_n += 1
				if paused_n >= 120:
					g.paused = false
			if i == 5 and guard == 900 and not seeked:
				seeked = true
				g._seek(40)
			g._process_inner(1.0 / 60.0)
			frames += 1
			lay_us.append(g.layout_us)   # 真正那一次排版的耗時（含丟字、併字）
			var st: Dictionary = g.text_overlap_stats()
			face = maxi(face, int(st["face_px"]))
			clip = maxi(clip, int(st["clipped"]))
			area = maxf(area, float(st["area_ratio"]))
			shown += int(st["visible"])
			for f in g.fx:   # 特效量測：和畫圖同一支算半徑（測試不能在 _draw 外畫）；亮度走 fx_col
				var fk: float = f["t"] / f["dur"]
				if g.GLOW.has(f["kind"]):
					g.glow_radius(f, fk)
					g.fx_col(g.GLOW[f["kind"]][0])
				elif f["kind"] == "boom":
					g.boom_radius(fk)
					g.fx_col(Color(1.0, 0.86, 0.35))
			fx_a = maxf(fx_a, float(g.fx_stats["max_area"]))
			fx_l = maxf(fx_l, float(g.fx_stats["max_lum"]))
	lay_us.sort()
	var p99: int = lay_us[int(lay_us.size() * 0.99)] if not lay_us.is_empty() else 0
	ok(p99 < 1500, "跳字排版耗時 p99 <1.5ms（p50 %d µs、p99 %d µs、最大 %d µs）" % [lay_us[lay_us.size() / 2], p99, lay_us[-1]])
	ok(shown > 100, "混戰量測有量到跳字（%d 幀、顯示中跳字累計 %d）" % [frames, shown])
	ok(face == 0, "S4：跳字蓋到頭胸框 0 像素（最大 %d）" % face)
	ok(clip == 0, "S4：跳字出盤內 12px 0 個（最大 %d）" % clip)
	ok(area <= 0.15, "S4：跳字總面積 ≤ 交戰區 15%%（最大 %.3f）" % area)
	ok(g.text_key_in > 0 and g.text_key_in == g.text_key_shown, "S4：關鍵跳字一個都不漏（%d／%d；擠不下只留戰報列 %d 次）" % [g.text_key_shown, g.text_key_in, g.text_key_to_report])
	ok(fx_a <= 0.04 + 1e-6 and fx_l <= 0.8 + 1e-6, "P3.4：裝飾特效單一面積 ≤4%%、最亮 ≤0.8（%.4f、%.3f）" % [fx_a, fx_l])
	# 人造：頭胸框正好擋在跳字原位 → 找到旁邊或上面的乾淨位置，離原位 ≤1.5 格
	var r := Rect2(500, 300, 80, 27)
	var faces := {1: Rect2(500, 290, 40, 50), 2: Rect2(560, 250, 40, 50)}
	var res: Array = g._text_slot(r, [], faces, Rect2(g.ORIGIN, g.fld_size).grow(-12), false, -1, Vector2.INF, Vector2(540, 282))   # 錨點在頭頂上方（遊戲裡是兵頭上）
	var hit := false
	for q: Rect2 in faces.values():
		hit = hit or q.intersects(res[0])
	ok(res[1] and not hit and (res[0] as Rect2).position.distance_to(r.position) <= g.TEXT_MAX_MOVE + r.size.x, "跳字避開頭胸框（%s）" % [res[0]])
	# 盤邊：原位出盤 → 夾回盤內 12px
	var edge: Array = g._text_slot(Rect2(g.ORIGIN + Vector2(-30, -20), Vector2(80, 27)), [], {}, Rect2(g.ORIGIN, g.fld_size).grow(-12))
	ok(Rect2(g.ORIGIN, g.fld_size).grow(-12).encloses(edge[0]), "盤邊跳字夾回盤內 12px（%s）" % [edge[0]])
	# 四面都是頭胸框：找不到乾淨位置 → 回報 false（一般跳字丟、關鍵放蓋最少處）
	var wall := {}
	for yy in range(0, 400, 20):
		for xx in range(300, 760, 30):
			wall[wall.size()] = Rect2(xx, yy, 30, 20)
	var none: Array = g._text_slot(Rect2(500, 300, 80, 27), [], wall, Rect2(g.ORIGIN, g.fld_size).grow(-12))
	ok(not none[1], "找不到乾淨位置時照實回報（一般跳字會丟、關鍵併進最近的關鍵字）")
	# 最終位移上限（含橫移、夾盤）：任何回報乾淨的位置離原位 ≤1.5 格（一般）／2.5 格（關鍵）
	var far_bad := 0
	for yy2 in range(120, 600, 37):
		for xx2 in range(140, 1100, 53):
			var rr0 := Rect2(xx2, yy2, 90, 30)
			for far in [false, true]:
				var rs: Array = g._text_slot(rr0, [], faces, Rect2(g.ORIGIN, g.fld_size).grow(-12), far)
				if rs[1] and (rs[0] as Rect2).position.distance_to(rr0.position) > (g.TEXT_MAX_MOVE_KEY if far else g.TEXT_MAX_MOVE) + 0.01:
					far_bad += 1
	ok(far_bad == 0, "乾淨位置的最終位移都在上限內（超過 %d 個）" % far_bad)
	# 引線：推離原位時，引線不准穿過別隻的頭胸（線段—矩形）
	ok(g.seg_hits_rect(Vector2(0, 0), Vector2(100, 100), Rect2(40, 40, 10, 10)) and not g.seg_hits_rect(Vector2(0, 0), Vector2(100, 0), Rect2(40, 40, 10, 10)), "線段穿過矩形判斷")
	# 擠不下的關鍵字併進最近的關鍵字（不丟、不蓋臉）
	var k1 := {"p": Vector2(300, 300), "n": 1, "sum": 35, "s": "衝鋒！ 35", "ek": "charge"}
	var k2 := {"p": Vector2(340, 300), "n": 1, "sum": 35, "s": "衝鋒！ 35", "ek": "charge"}
	ok(g._merge_into(k2, [k1]) and int(k1["n"]) == 2 and int(k1["sum"]) == 70, "擠不下的關鍵字併進最近的同種關鍵字（%s）" % k1["s"])
	# 特效亮度上限（P3.4；Codex B08 r1 #5）：_draw_fx 裡（跳字分支之前）每個字面顏色的加權亮度 ≤0.8，白色常數不直接用
	var src: String = FileAccess.get_file_as_string("res://scripts/ui/battle/battle_fx.gd")
	var a0 := src.find("func _draw_fx(f: Dictionary) -> void:")
	var body := src.substr(a0, src.find("\t\t\"text\":", a0) - a0)
	var re := RegEx.create_from_string("Color\\(\\s*([0-9.]+)\\s*,\\s*([0-9.]+)\\s*,\\s*([0-9.]+)")
	var over: Array = []
	var nlit := 0
	for m in re.search_all(body):
		var lr := float(m.get_string(1))
		var lg := float(m.get_string(2))
		var lb := float(m.get_string(3))
		if lr > 1.0 or lg > 1.0 or lb > 1.0:
			continue
		nlit += 1
		if 0.2126 * lr + 0.7152 * lg + 0.0722 * lb > 0.8005:
			over.append(m.get_string(0))
	var hexre := RegEx.create_from_string("Color\\(\"#([0-9a-fA-F]{6})\"")
	for m in hexre.search_all(body):
		var hc := Color("#" + m.get_string(1))
		nlit += 1
		if 0.2126 * hc.r + 0.7152 * hc.g + 0.0722 * hc.b > 0.8005:
			over.append(m.get_string(0))
	var white_raw := body.count("Color.WHITE") - body.count("fx_lum_cap(f.get(")
	ok(nlit > 40 and over.is_empty() and white_raw == 0, "特效字面色 %d 個全部亮度 ≤0.8（超過：%s；白色常數直接用 %d）" % [nlit, over, white_raw])
	# 特效亮度上限：純白壓到 0.8、暗色不動
	var cw: Color = g.fx_lum_cap(Color(1, 1, 1))
	ok(absf(0.2126 * cw.r + 0.7152 * cw.g + 0.0722 * cw.b - 0.8) < 1e-3 and g.fx_lum_cap(Color(0.3, 0.2, 0.1)) == Color(0.3, 0.2, 0.1), "特效亮度上限：白壓到 0.8、暗色不動")
	g.free()

## 1.6.0 B08（P3.5）語意保護：B06 的地形落影與 B03 的盤外壓暗不碰隊色與通行格。
## ①落影只落在可走格（牆格 0，B06 已驗）且每個可走格被影子蓋到的深度 ≤40%、影子不透明度 ≤0.35——格子大半保留原色，通行判讀不變；
## ②盤外壓暗畫在桌面那一層（盤面、兵、隊色圈都畫在它之後）；③影子、凹槽內影都畫在地圖烘焙層（兵與腳底隊色圈在其後）。
func test_semantic_guard_v1600() -> void:
	var MA = load("res://scripts/ui/map_art.gd")
	var MD = load("res://scripts/core/map_defs.gd")
	var worst := 0.0
	var n := 0
	for mid in range(1, MD.MAPS.size()):
		for sz in 3:
			var tt = MD.terrain(mid, sz)
			if tt == null:
				continue
			for tl in [false, true]:
				var pp = MA._Painter.new()
				pp.t = tt
				pp.kind = str(MD.MAPS[mid]["biome"])
				pp.tilt = tl
				var Q := 32.0
				var cover := {}
				for r in tt.m:
					for c in tt.n:
						for sh in [pp.shadow_south(c, r, Q), pp.shadow_east(c, r, Q)]:
							if sh.size.x <= 0.0:
								continue
							n += 1
							for r2 in range(maxi(0, r - 1), mini(tt.m, r + 3)):
								for c2 in range(maxi(0, c - 1), mini(tt.n, c + 3)):
									var cell := Rect2(Vector2(c2, r2) * Q, Vector2(Q, Q))
									if sh.intersects(cell):
										var k := Vector2i(c2, r2)
										cover[k] = float(cover.get(k, 0.0)) + sh.intersection(cell).get_area() / (Q * Q)
				for k in cover:
					worst = maxf(worst, cover[k])
				pp.free()
	ok(n > 200 and worst <= 0.40, "落影蓋到單一可走格的面積最多 %.0f%%（≤40%%；%d 塊影子）" % [worst * 100.0, n])
	var src: String = FileAccess.get_file_as_string("res://scripts/ui/map_art.gd")
	var alphas: Array = []
	for line in src.split("\n"):
		if line.find("draw_rect(ssh") >= 0 or line.find("draw_rect(esh") >= 0 or line.find("凹槽北緣內影") >= 0:
			var m := RegEx.create_from_string("Color\\(([0-9.]+), ([0-9.]+), ([0-9.]+), ([0-9.]+)\\)").search(line)
			if m != null:
				alphas.append(float(m.get_string(4)))
	ok(alphas.size() >= 3 and alphas.max() <= 0.35, "落影、東側影、凹槽內影不透明度 ≤0.35（%s）" % [alphas])
	var gs: String = FileAccess.get_file_as_string("res://scripts/ui/game_screens.gd")
	var i_desk := gs.find("_draw_desk()   #")
	var i_field := gs.find("\t_draw_field()\n")
	var i_units := gs.find("_draw_units_of(view, false)")
	ok(i_desk >= 0 and i_field > i_desk and i_units > i_field, "畫的順序：桌面（含盤外壓暗）→ 盤面與地形 → 兵與隊色圈")
	var ub: String = FileAccess.get_file_as_string("res://scripts/ui/ui_base.gd")
	var i_dim := ub.find("Color(DIM_INK, PAL.OFF_BOARD_DIM)")
	ok(i_dim > ub.find("func _draw_desk()") and i_dim < ub.find("func _desk_props()"), "盤外壓暗在 _draw_desk 裡（盤面畫在它之上，盤內隊色不變）")

## 1.6.0 B10（P4.1～P4.4）兩兵種剪影試作：色盲旗形、底座厚度與木紋、巨獸粗外框（剪影墊底一趟）、全兵種血條避讓。
## 剪影分離（劍士、騎兵和其他兵種最大 IoU）要真的繪圖，headless 量不了：用 dev_main --sil＋tools/gen/sil_report.py 量，數字記在 ledger。
func test_silhouette_v1600() -> void:
	var Art = load("res://scripts/ui/art.gd")
	# P4.2 色盲旗形：藍方圓旗（12 點同半徑）、紅方燕尾（右緣有往內的 V 口）
	var p := Vector2(100, 100)
	var blue: PackedVector2Array = Art.flag_shape(p, 0)
	var c := p + Vector2(5.0, -8.5)
	var round_ok := blue.size() >= 10
	for q in blue:
		round_ok = round_ok and absf(q.distance_to(c) - 4.6) < 0.01
	var red: PackedVector2Array = Art.flag_shape(p, 1)
	var right := -INF
	for q in red:
		right = maxf(right, q.x)
	var notch := false
	for k in range(1, red.size() - 1):
		notch = notch or (red[k].x < right - 3.0 and red[k - 1].x >= right - 0.01 and red[k + 1].x >= right - 0.01)
	ok(round_ok and notch, "色盲旗形：藍方圓旗、紅方燕尾（不靠顏色）")
	var asrc: String = FileAccess.get_file_as_string("res://scripts/ui/art.gd")
	ok(asrc.find("if cb:\n\t\tvar pts2: PackedVector2Array = flag_shape(p, team)") >= 0, "色盲模式才換旗形（一般模式三角小旗不變）")
	# P4.3 底座：斜邊加厚、鐵箍跟著新斜邊、頂面木紋
	ok(Art.BASE_EDGE >= 4.0 and asrc.find("var c0 := p + Vector2(0, BASE_EDGE) * scale") >= 0 and asrc.find("木紋：頂面上半圈的兩道淺弧") >= 0, "底座斜邊 %.1f、鐵箍跟著斜邊、頂面木紋" % Art.BASE_EDGE)
	# P4.4 巨獸粗外框：剪影那一趟只畫墨色、往外擴；畫完一定歸零（不然之後全部兵都變黑）
	var bu: String = FileAccess.get_file_as_string("res://scripts/ui/battle/battle_units.gd")
	var i0 := bu.find("Art.sil_w = BOSS_SIL_PX / usc")
	ok(i0 >= 0 and bu.find("Art.sil_w = 0.0", i0) > i0 and bu.find("Art.sil_w = 0.0", i0) - i0 < 260, "巨獸剪影墊底一趟後 sil_w 歸零")
	var kit: String = FileAccess.get_file_as_string("res://scripts/ui/units/kit.gd")
	ok(kit.count("if sil_w > 0.0:") == 3, "圓、多邊形、線三種基本筆畫都支援剪影墊底")
	ok(Art.sil_w == 0.0, "平常 sil_w＝0")
	# 全兵種血條避讓：頭頂血條框蓋到別隻的頭胸 → 改畫底座弧；自己的頭胸不算
	var BU = load("res://scripts/ui/battle/battle_units.gd")
	var faces := {1: Rect2(100, 100, 40, 50), 2: Rect2(200, 100, 40, 50)}
	var bu_src: String = FileAccess.get_file_as_string("res://scripts/ui/battle/battle_units.gd")
	ok(bu_src.find("if not hp_bar_blocks(hp_arc_rect(p), u.id, bar_faces):") >= 0 and bu_src.find("if u.id != follow_id:\n\t\t\t\t\tcontinue") >= 0, "底座弧也會蓋到前排頭胸就不畫（跟拍那隻照畫頭頂）")
	ok(bu_src.find("var bar_r := Rect2(top + Vector2(-14.5, -4.5), Vector2(w + 15.5, 13.0)) if cbm()") >= 0, "遮擋檢查含色盲標記的完整範圍")
	ok(bu_src.find("var ae := a1 - (a1 - a0) * frac") >= 0, "底座弧血量終點插值（低血量不會看起來空血）")
	ok(FileAccess.get_file_as_string("res://scripts/ui/ui_base.gd").find("var ed := 2.2 * Art.BASE_EDGE / 3.2") >= 0, "大圖底座同步加厚＋木紋")
	ok(BU.hp_bar_blocks(Rect2(110, 140, 30, 6), 2, faces) and not BU.hp_bar_blocks(Rect2(110, 140, 30, 6), 1, faces) and not BU.hp_bar_blocks(Rect2(150, 60, 30, 6), 3, faces), "血條避讓：蓋到別隻頭胸才改底座弧，自己的不算")
	# P4.1 劍士、騎兵剪影：劍刃 34、待機往前上方斜伸；馬頭抬高、槍 60
	var ks: String = FileAccess.get_file_as_string("res://scripts/ui/units/kingdom.gd")
	ok(ks.find("var tip := hand + dir * 34.0") >= 0 and ks.find("var ang := -0.7 + (w * 0.55 if w < 0.0 else w * 1.5)") >= 0, "劍士：劍刃 34、待機斜伸、揮到底角度 0.8 不變")
	ok(ks.find("var tip := base + dir * 60.0") >= 0 and ks.find("Vector2(17, -41), Vector2(31, -38)") >= 0, "騎兵：槍 60、馬頭抬高往前")
