extends SceneTree
## headless 測試：godot --headless --path game --script res://tests/run_tests.gd
## 印出每項 PASS/FAIL，最後一行是總結；有失敗就 exit 1。另外印出「指紋」給跨平台比對。

const D = preload("res://scripts/core/unit_defs.gd")
const Army = preload("res://scripts/core/army.gd")
const Sim = preload("res://scripts/core/battle_sim.gd")
const AI = preload("res://scripts/core/ai_army.gd")
const TP = preload("res://scripts/core/turn_placement.gd")

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
			if a.place(D.SWORD, c, r):
				n += 1
	ok(n == 24 and a.spent() == 96, "100 金全劍士只能放 24 隻（人數上限）", "n=%d" % n)
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
		# 左右交換：a1 鏡像成藍方、a0 鏡像成紅方 → 勝方應該對調
		var s3 = Sim.new(a1.mirrored(), a0.mirrored())
		s3.run_to_end()
		mirror_total += 1
		var expect: int = s1.winner if s1.winner == -1 else 1 - s1.winner
		if s3.winner == expect and s3.tick == s1.tick:
			mirror_ok += 1
		else:
			print("  鏡像不一致 seed=%d 原本 %d@%d 鏡像 %d@%d" % [seed, s1.winner, s1.tick, s3.winner, s3.tick])
	ok(det_ok, "同一場跑兩次指紋相同（20 場）")
	ok(mirror_ok == mirror_total, "左右交換後勝方對調、tick 相同（%d/%d）" % [mirror_ok, mirror_total])
	ms.sort()
	print("  每場耗時 ms：中位數 %d、最大 %d（48 隻上限、headless debug）" % [ms[ms.size() / 2], ms[-1]])
	var h := 0
	for p in prints:
		h = posmod(h * 1000003 + p, Sim.HASH_MOD)
	print("FINGERPRINT ", h)

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
	var e = Sim.new(Army.new(0, 100), army_from(1, [[D.SWORD, 5, 4]]))
	ok(e.finished and e.winner == -1, "空軍隊不能開打")

func test_traits() -> void:
	# 弓箭手射盾兵正面：傷害 ×1/4
	var s = Sim.new(army_from(0, [[D.ARCHER, 0, 4]]), army_from(1, [[D.SHIELD, 5, 4]]))
	var seen_block := false
	for i in 200:
		s.step()
		for ev in s.events:
			if ev.get("kind") == "blocked" and ev["dmg"] == 2:
				seen_block = true
	ok(seen_block, "盾兵正面擋箭（10→2）")
	# 騎兵直衝 3 格以上的第一擊是衝鋒
	s = Sim.new(army_from(0, [[D.CAVALRY, 0, 4]]), army_from(1, [[D.SWORD, 0, 4]]))
	var seen_charge := false
	for i in 200:
		s.step()
		for ev in s.events:
			if ev.get("kind") == "charge" and ev["dmg"] == 35:
				seen_charge = true
	ok(seen_charge, "騎兵衝鋒 14×5/2＝35")
	# 騎兵正面衝盾兵：被頂住（暈）
	s = Sim.new(army_from(0, [[D.CAVALRY, 0, 4]]), army_from(1, [[D.SHIELD, 0, 4]]))
	var seen_brace := false
	for i in 200:
		s.step()
		for ev in s.events:
			if ev.get("kind") == "braced":
				seen_brace = true
	ok(seen_brace, "盾兵頂住衝鋒")
	# 刺客開場潛行，弓箭手打不到
	s = Sim.new(army_from(0, [[D.ARCHER, 0, 4]]), army_from(1, [[D.ASSASSIN, 5, 4]]))
	s.step()
	ok(s.units[0].target == -1, "潛行中的刺客不能被指定")
	# 劍士被刺客打會反擊
	s = Sim.new(army_from(0, [[D.SWORD, 5, 4]]), army_from(1, [[D.ASSASSIN, 5, 4]]))
	var seen_counter := false
	for i in 300:
		s.step()
		for ev in s.events:
			if ev.get("kind") == "counter":
				seen_counter = true
	ok(seen_counter, "劍士反擊刺客")
