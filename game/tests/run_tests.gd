extends SceneTree
## headless 測試：godot --headless --path game --script res://tests/run_tests.gd
## 印出每項 PASS/FAIL，最後一行是總結；有失敗就 exit 1。另外印出「指紋」給跨平台比對。

const D = preload("res://scripts/core/unit_defs.gd")
const Army = preload("res://scripts/core/army.gd")
const Sim = preload("res://scripts/core/battle_sim.gd")
const AI = preload("res://scripts/core/ai_army.gd")
const TP = preload("res://scripts/core/turn_placement.gd")
const MC = preload("res://scripts/core/mirror_check.gd")

var passed := 0
var failed := 0

func ok(cond: bool, name: String, extra := "") -> void:
	if cond:
		passed += 1
		print("PASS ", name)
	else:
		failed += 1
		print("FAIL ", name, "  ", extra)

func _init() -> void:
	var t0 := Time.get_ticks_msec()
	test_army_rules()
	test_turn_placement()
	test_determinism_and_mirror()
	test_termination()
	test_traits()
	test_rule_fixes()
	test_suspense()
	test_codes_and_snake()
	print("—— %d 通過 / %d 失敗（%d ms）" % [passed, failed, Time.get_ticks_msec() - t0])
	quit(1 if failed > 0 or passed == 0 else 0)

func army_from(team: int, spec: Array):
	var a = Army.new(team, 100)
	for s in spec:
		var col: int = s[1] if team == 0 else Army.COLS - 1 - s[1]
		a.units.append({"type": s[0], "col": col, "row": s[2]})
	return a

func test_army_rules() -> void:
	var a = Army.new(0, 100)
	ok(a.check_place(D.SWORD, 6, 0) != "", "部署區外不能放")
	ok(a.place(D.SWORD, 0, 0), "部署區內可以放")
	ok(not a.place(D.SHIELD, 0, 0), "同一格不能放兩隻")
	var b = Army.new(1, 100)
	ok(b.check_place(D.SWORD, 5, 0) != "" and b.check_place(D.SWORD, 10, 0) == "", "紅方部署區是 10～15 欄")
	a.clear()
	var n := 0
	for r in 9:
		for c in 6:
			if a.place(D.ARCHER, c, r):
				n += 1
	ok(n == 24 and a.spent() == 24 * D.cost(D.ARCHER), "最便宜的兵擺滿也只能放 24 隻（人數上限）", "n=%d" % n)
	a.clear()
	for i in 14:
		a.place(D.CAVALRY, i % 6, i / 6)
	ok(a.count() == 14 and a.left() == 2 and not a.can_afford_any(), "錢不夠就放不下", "count=%d left=%d" % [a.count(), a.left()])
	var m = army_from(0, [[D.SWORD, 0, 0], [D.ARCHER, 5, 8]]).mirrored()
	ok(m.team == 1 and m.units[0]["col"] == 15 and m.units[1]["col"] == 10, "鏡像換隊、欄位翻轉")

func test_turn_placement() -> void:
	var tp = TP.new(Army.new(0, 100), Army.new(1, 100), 0)
	ok(not tp.end_turn(), "沒擺兵又買得起不能結束這一手")
	ok(tp.place(D.SWORD, 0, 0), "第一手擺劍士")
	ok(tp.check_place(D.CAVALRY, 1, 0) != "", "一手最多 10 金（4＋7 超過）")
	ok(tp.current == 0 and tp.end_turn() and tp.current == 1, "結束後換紅方")
	ok(tp.place(D.CAVALRY, 15, 0) and tp.current == 0, "這一手剩 3 金買不起任何兵 → 自動換手")
	ok(tp.armies[0].count() == 1, "擺下的兵不會被收回")
	# 跑完整場：雙方輪流用最便宜的兵擺到停手
	var guard := 0
	while not tp.done() and guard < 500:
		guard += 1
		var a = tp.armies[tp.current]
		var placed := false
		for r in 9:
			for c in 16:
				if not placed and tp.place(D.SWORD, c, r):
					placed = true
		if not placed:
			tp.end_turn()
	ok(tp.done() and guard < 500, "輪流落子一定會結束", "guard=%d" % guard)
	ok(tp.armies[0].left() < D.cheapest() or tp.armies[0].count() == 24, "停手時藍方真的買不起或滿了")

func test_determinism_and_mirror() -> void:
	var rng := RandomNumberGenerator.new()
	var mirror_ok := 0
	var mirror_total := 0
	var det_ok := true
	var prints: Array = []
	var ms: Array = []
	for seed in 20:
		rng.seed = seed * 7919 + 1
		var a0 = AI.build(0, 100, rng)["army"]
		var a1 = AI.build(1, 100, rng)["army"]
		var t := Time.get_ticks_usec()
		var s1 = Sim.new(a0, a1)
		s1.run_to_end()
		ms.append((Time.get_ticks_usec() - t) / 1000)
		var s2 = Sim.new(a0.copy(), a1.copy())
		s2.run_to_end()
		if s1.fingerprint != s2.fingerprint or s1.winner != s2.winner:
			det_ok = false
		prints.append(s1.fingerprint)
		# 左右交換：逐 tick 比對完整鏡像
		mirror_total += 1
		var why: String = MC.check(a0, a1)
		if why == "":
			mirror_ok += 1
		else:
			print("  鏡像不一致 seed=%d：%s" % [seed, why])
	ok(det_ok, "同一場跑兩次指紋相同（20 場）")
	ok(mirror_ok == mirror_total, "左右交換逐 tick 完整鏡像（%d/%d）" % [mirror_ok, mirror_total])
	ms.sort()
	print("  每場耗時 ms：中位數 %d、最大 %d（48 隻上限、headless debug）" % [ms[ms.size() / 2], ms[-1]])
	print("FINGERPRINT ", "".join(prints).sha256_text().substr(0, 16), "  數值摘要 ", D.data_digest())

func test_termination() -> void:
	var a0 := []
	var a1 := []
	for r in 9:
		for c in 2:
			a0.append([D.SHIELD, 5 - c, r])
			a1.append([D.SHIELD, 5 - c, r])
	var s = Sim.new(army_from(0, a0), army_from(1, a1))
	s.run_to_end()
	ok(s.finished and s.tick <= Sim.MAX_TICKS, "全盾對全盾 90 秒內結束", "tick=%d" % s.tick)
	ok(s.winner == -1, "一模一樣的軍隊是平手", "winner=%d %s" % [s.winner, s.reason])
	# 全盾局會在耗損下同歸於盡（上面判平手）；這裡另外驗狂熱與耗損的時間點
	var f = Sim.new(army_from(0, a0), army_from(1, a1))
	var frenzy_at := -1
	while not f.finished and f.tick < Sim.FRENZY_TICK + 5:
		f.step()
		if frenzy_at == -1 and f.frenzy:
			frenzy_at = f.tick
	ok(frenzy_at == Sim.FRENZY_TICK, "第 1200 tick 起進入狂熱", "frenzy_at=%d" % frenzy_at)
	# 兩隻盾兵在對角、從第 1650 tick 開始跑（走不到對方，一定撐到 1800）：只在 1700 扣一次（k＝5），1800（k＝6）不扣
	var g = Sim.new(army_from(0, [[D.SHIELD, 0, 0]]), army_from(1, [[D.SHIELD, 0, 8]]))
	g.tick = 1650
	var hits := 0
	while not g.finished:
		g.step()
		for ev in g.events:
			if ev.get("kind") == "attrition":
				hits += 1
	ok(g.tick == Sim.MAX_TICKS and hits == 1 and g.units[0].hp == g.units[0].max_hp - g.units[0].max_hp * 6 * D.ATTRITION_STEP_PCT / 100, "耗損在 1700 扣 6×STEP%、1800 不扣", "tick=%d hits=%d" % [g.tick, hits])
	var e = Sim.new(Army.new(0, 100), army_from(1, [[D.SWORD, 5, 4]]))
	ok(e.finished and e.winner == -1, "空軍隊不能開打")

func test_traits() -> void:
	# 弓箭手射盾兵正面：傷害 ×1/4
	var s = Sim.new(army_from(0, [[D.ARCHER, 0, 4]]), army_from(1, [[D.SHIELD, 5, 4]]))
	var seen_block := false
	for i in 200:
		s.step()
		for ev in s.events:
			if ev.get("kind") == "blocked" and ev["dmg"] == D.STATS[D.ARCHER]["atk"] * D.BLOCK_NUM / D.BLOCK_DEN:
				seen_block = true
	ok(seen_block, "盾兵正面擋箭（傷害×BLOCK）")
	# 騎兵直衝 3 格以上的第一擊是衝鋒
	s = Sim.new(army_from(0, [[D.CAVALRY, 0, 4]]), army_from(1, [[D.SWORD, 0, 4]]))
	var seen_charge := false
	for i in 200:
		s.step()
		for ev in s.events:
			if ev.get("kind") == "charge" and ev["dmg"] == D.STATS[D.CAVALRY]["atk"] * D.CHARGE_NUM / D.CHARGE_DEN:
				seen_charge = true
	ok(seen_charge, "騎兵衝鋒傷害×CHARGE")
	# 騎兵正面衝盾兵：被頂住（暈）
	s = Sim.new(army_from(0, [[D.CAVALRY, 0, 4]]), army_from(1, [[D.SHIELD, 0, 4]]))
	var seen_brace := false
	var cav_stunned := false
	for i in 200:
		s.step()
		for ev in s.events:
			if ev.get("kind") == "braced":
				seen_brace = true
				cav_stunned = s.units[0].stun == D.STUN_TICKS and s.units[0].charge == 0
	ok(seen_brace and cav_stunned, "盾兵頂住衝鋒（騎兵被暈 20 tick、衝鋒歸零）")
	# 三條專屬倍率（平衡方案 F1）：拒馬、皮甲、射刺客加碼
	var exp_anticav: int = D.STATS[D.SHIELD]["atk"] * D.ANTICAV_NUM / D.ANTICAV_DEN
	var exp_hide: int = D.STATS[D.ARCHER]["atk"] * D.HIDE_ARROW_NUM / D.HIDE_ARROW_DEN
	var exp_alert: int = D.STATS[D.ARCHER]["atk"] * D.ALERT_NUM / D.ALERT_DEN
	var got := {}
	for pair in [[D.SHIELD, D.CAVALRY], [D.ARCHER, D.CAVALRY], [D.ARCHER, D.ASSASSIN]]:
		var q = Sim.new(army_from(0, [[pair[0], 5, 4]]), army_from(1, [[pair[1], 5, 4]]))
		for i in 400:
			q.step()
			for ev in q.events:
				if ev.has("src") and q.unit_by_id(ev["src"]).team == 0 and not got.has(pair):
					got[pair] = ev["dmg"]
	ok(got.get([D.SHIELD, D.CAVALRY], -1) == exp_anticav, "拒馬：盾兵打騎兵 %d" % exp_anticav, str(got.get([D.SHIELD, D.CAVALRY], -1)))
	ok(got.get([D.ARCHER, D.CAVALRY], -1) == exp_hide, "皮甲：弓箭射騎兵 %d" % exp_hide, str(got.get([D.ARCHER, D.CAVALRY], -1)))
	ok(got.get([D.ARCHER, D.ASSASSIN], -1) == exp_alert, "警覺：弓箭射刺客 %d" % exp_alert, str(got.get([D.ARCHER, D.ASSASSIN], -1)))
	# 刺客開場潛行，弓箭手打不到
	s = Sim.new(army_from(0, [[D.ARCHER, 0, 4]]), army_from(1, [[D.ASSASSIN, 5, 4]]))
	var first_seen := -1
	for i in 100:
		s.step()
		if first_seen == -1 and s.units[0].target != -1:
			first_seen = s.tick
	ok(first_seen == D.STEALTH_TICKS + 1, "刺客潛行 %d tick 內不能被指定" % D.STEALTH_TICKS, "first_seen=%d" % first_seen)
	# 劍士被刺客打會反擊
	s = Sim.new(army_from(0, [[D.SWORD, 5, 4]]), army_from(1, [[D.ASSASSIN, 5, 4]]))
	var counters := 0
	var bad := false
	for i in 300:
		s.step()
		var per_tick := 0
		for ev in s.events:
			if ev.get("kind") == "counter":
				per_tick += 1
				if ev["dmg"] != D.STATS[D.SWORD]["atk"] * D.COUNTER_PCT / 100:
					bad = true
		if per_tick > 1:
			bad = true
		counters += per_tick
	ok(counters > 0 and not bad, "劍士反擊刺客（傷害照 COUNTER_PCT、每 tick 最多一次）", "counters=%d" % counters)


func test_rule_fixes() -> void:
	# 面向鎖定：盾兵正面對著劍士交戰，刺客從背後過來推擠也不會讓盾兵轉身
	var s = Sim.new(army_from(0, [[D.SHIELD, 5, 4]]), army_from(1, [[D.SWORD, 5, 4]]))
	var locked_ticks := 0
	var changed := 0
	var last := Vector2i.ZERO
	for i in 300:
		s.step()
		var u = s.units[0]
		if u.face_lock != -1:
			var f := Vector2i(u.fx, u.fy)
			if locked_ticks > 0 and f != last:
				changed += 1
			last = f
			locked_ticks += 1
	ok(locked_ticks > 20 and changed == 0, "交戰中面向鎖定（不隨推擠改變）", "locked=%d changed=%d" % [locked_ticks, changed])
	# 衝鋒：騎兵往盾兵衝、被頂住後歸零；衝鋒距離只算沿起始方向的前進
	s = Sim.new(army_from(0, [[D.CAVALRY, 0, 4]]), army_from(1, [[D.SWORD, 0, 0]]))
	var max_charge := 0
	for i in 30:
		s.step()
		max_charge = maxi(max_charge, s.units[0].charge)
	var straight_cells: int = Sim.W   # 對角線路程上限
	ok(max_charge > 0 and max_charge <= straight_cells, "衝鋒累積只算實際前進", "max=%d" % max_charge)
	# 反擊：兩隻刺客同時打同一劍士 → 左右交換後被反擊的刺客位置要鏡像對應
	var a0 = army_from(0, [[D.SWORD, 5, 4]])
	var a1 = army_from(1, [[D.ASSASSIN, 5, 3], [D.ASSASSIN, 5, 5]])
	var s1 = Sim.new(a0, a1)
	var s2 = Sim.new(a1.mirrored(), a0.mirrored())
	var c1 := ""
	var c2 := ""
	for i in 400:
		s1.step()
		s2.step()
		for ev in s1.events:
			if ev.get("kind") == "counter" and c1 == "":
				var t = s1.unit_by_id(ev["tgt"])
				c1 = "%d,%d" % [t.x, t.y]
		for ev in s2.events:
			if ev.get("kind") == "counter" and c2 == "":
				var t = s2.unit_by_id(ev["tgt"])
				c2 = "%d,%d" % [Sim.W - t.x, t.y]
	ok(c1 != "" and c1 == c2, "反擊對象在左右交換後鏡像一致", "%s vs %s" % [c1, c2])
	ok(s1.fingerprint != "" and s1.fingerprint.length() == 64, "指紋是 SHA-256", s1.fingerprint)

func test_suspense() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var s = Sim.new(AI.build(0, 100, rng)["army"], AI.build(1, 100, rng)["army"])
	s.run_to_end()
	var m: Dictionary = s.suspense()
	ok(s.power_log.size() == s.tick and m.has("lead_changes") and m["lock_ratio_permille"] >= 0 and m["lock_ratio_permille"] <= 1000, "懸念指標可計算", str(m))


func test_codes_and_snake() -> void:
	var a = army_from(0, [[D.SWORD, 5, 4], [D.CAVALRY, 3, 0], [D.ARCHER, 0, 8]])
	var code: String = a.to_code()
	var b = Army.new(0, 100)
	ok(b.load_code(code) == "" and b.to_code() == code, "陣型代碼來回一致", code)
	var r = Army.new(1, 100)
	ok(r.load_code(code) == "" and r.units[0]["col"] == 10, "藍方代碼載入成紅方會鏡像到紅方部署區")
	ok(b.load_code(code.substr(0, code.length() - 1) + "x") != "", "校驗碼錯誤會被拒絕")
	ok(b.load_code("NTB1.AQE.zzzz") != "", "亂碼會被拒絕")
	var before: String = b.to_code()
	b.load_code("garbage")
	ok(b.to_code() == before, "載入失敗不會改動目前陣型")
	# 5 手蛇行：順序 A B B A A B B A A B，每人最多 5 手、每手最多 20 金
	var tp = TP.new(Army.new(0, 100), Army.new(1, 100), 0, "snake5")
	var order: Array = []
	var guard := 0
	while not tp.done() and guard < 50:
		guard += 1
		order.append(tp.current)
		var placed := false
		for row in 9:
			for col in 16:
				if not placed and tp.place(D.SWORD, col, row):
					placed = true
		if tp.current == order[-1] and not tp.done():
			tp.end_turn()
	ok(order.slice(0, 10) == [0, 1, 1, 0, 0, 1, 1, 0, 0, 1], "蛇行順序正確", str(order))
	ok(tp.handoffs == 5 and tp.hands_done == [5, 5], "每人 5 手、換人 5 次", "handoffs=%d hands=%s" % [tp.handoffs, str(tp.hands_done)])
	ok(tp.check_place(D.SWORD, 0, 0) != "", "蛇行結束後不能再擺")
