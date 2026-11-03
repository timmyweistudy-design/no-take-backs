extends SceneTree
## headless 測試：godot --headless --path game --script res://tests/run_tests.gd
## 印出每項 PASS/FAIL，最後一行是總結；有失敗就 exit 1。另外印出「指紋」給跨平台比對。

const D = preload("res://scripts/core/unit_defs.gd")
const Army = preload("res://scripts/core/army.gd")
const Sim = preload("res://scripts/core/battle_sim.gd")
const AI = preload("res://scripts/core/ai_army.gd")
const TP = preload("res://scripts/core/turn_placement.gd")
const MC = preload("res://scripts/core/mirror_check.gd")
const PZ = preload("res://scripts/game/puzzles.gd")
const CX = preload("res://scripts/game/codex.gd")
const BV = preload("res://scripts/ui/battle_view.gd")
const F = preload("res://scripts/core/formations.gd")
const EVS = preload("res://scripts/core/events.gd")
const Art = preload("res://scripts/ui/art.gd")

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
	if "--only=ui" in OS.get_cmdline_user_args():
		test_ui_consumers()
		print("—— %d 通過 / %d 失敗" % [passed, failed])
		quit(0)
		return
	if "--only=rules" in OS.get_cmdline_user_args():
		test_rules_v5()
		test_sandbox_v5()
		test_battle_code_v5()
		test_rules_e2e_v5()
		print("—— %d 通過 / %d 失敗（%d ms）" % [passed, failed, Time.get_ticks_msec() - t0])
		quit(1 if failed > 0 or passed == 0 else 0)
		return
	if "--only=new" in OS.get_cmdline_user_args():
		test_new_units()
		print("—— %d 通過 / %d 失敗（%d ms）" % [passed, failed, Time.get_ticks_msec() - t0])
		quit(1 if failed > 0 or passed == 0 else 0)
		return
	test_army_rules()
	test_turn_placement()
	test_determinism_and_mirror()
	test_termination()
	test_traits()
	test_rule_fixes()
	test_suspense()
	test_codes_and_snake()
	test_rally()
	test_nav_r1()
	test_puzzle_solutions()
	test_codex()
	test_event_routes()
	test_ui_consumers()
	test_sfx_priority()
	test_save_migration()
	test_play_effects()
	test_input_queue()
	test_golden()
	test_crowd_readability()
	test_replay_tools()
	test_counter_lib()
	test_seek_clutch()
	test_clutch_effects()
	test_new_units()
	test_roster_ui()
	test_rules_v5()
	test_sandbox_v5()
	test_battle_code_v5()
	test_rules_e2e_v5()
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
	# 面向鎖定：藍盾兵正面跟紅劍士交戰，紅刺客從背後切過來推擠——鎖定中的盾兵面向一點都不能變
	var s = Sim.new(army_from(0, [[D.SHIELD, 5, 4]]), army_from(1, [[D.SWORD, 5, 4], [D.ASSASSIN, 4, 4]]))
	var locked_ticks := 0
	var changed := 0
	var last := Vector2i.ZERO
	var lock_target := -1
	var pushed := 0
	var lastpos := Vector2i.ZERO
	for i in 300:
		s.step()
		var u = s.units[0]
		if not u.alive:
			break
		if u.face_lock != -1 and u.face_lock == lock_target:
			var f := Vector2i(u.fx, u.fy)
			if f != last:
				changed += 1
			if Vector2i(u.x, u.y) != lastpos:
				pushed += 1
			locked_ticks += 1
		lock_target = u.face_lock
		last = Vector2i(u.fx, u.fy)
		lastpos = Vector2i(u.x, u.y)
	ok(locked_ticks > 20 and pushed > 0 and changed == 0, "交戰中面向鎖定（被推擠位置變了，面向不變）", "locked=%d pushed=%d changed=%d" % [locked_ticks, pushed, changed])
	# 直接側推：鎖定後把盾兵往旁邊挪 0.4 格，同一個目標還在交戰距離內 → 面向必須維持
	var s2 = Sim.new(army_from(0, [[D.SHIELD, 5, 4]]), army_from(1, [[D.SWORD, 5, 4]]))
	var guard := 0
	while s2.units[0].face_lock == -1 and guard < 200:
		s2.step()
		guard += 1
	var before := Vector2i(s2.units[0].fx, s2.units[0].fy)
	var tgt: int = s2.units[0].face_lock
	s2.units[0].y += 400
	s2.step()
	ok(tgt != -1 and s2.units[0].face_lock == tgt and Vector2i(s2.units[0].fx, s2.units[0].fy) == before, "被側推後面向仍鎖定在原本方向",
		"%s → %s" % [before, Vector2i(s2.units[0].fx, s2.units[0].fy)])
	# 衝鋒累積：直接驗 _update_charge
	var c = Sim.new(army_from(0, [[D.CAVALRY, 0, 4]]), army_from(1, [[D.SWORD, 0, 4]]))
	var cav = c.units[0]
	cav.charge = 0
	cav.mx = 120; cav.my = 0
	c._update_charge(cav, 120, 0)
	c._update_charge(cav, 120, 0)
	ok(cav.charge == 240, "直行累積衝鋒距離", str(cav.charge))
	c._update_charge(cav, 200, 0)
	ok(cav.charge == 360, "被往前推的位移不算（只算自己提出的 120）", str(cav.charge))
	c._update_charge(cav, 40, 0)
	ok(cav.charge == 0, "被擋住前進不到一半就歸零", str(cav.charge))
	# 逐步轉彎：每步轉 10 度，跟起始方向差超過約 25 度就重新開始
	cav.charge = 0
	var resets := 0
	var prev := 0
	for k in 6:
		var ang := deg_to_rad(10.0 * k)
		cav.mx = int(120 * cos(ang)); cav.my = int(120 * sin(ang))
		c._update_charge(cav, cav.mx, cav.my)
		if cav.charge < prev:
			resets += 1
		prev = cav.charge
	ok(resets >= 1 and cav.charge < 6 * 118, "逐步轉彎累積到一定角度會重新開始", "resets=%d charge=%d" % [resets, cav.charge])
	# 反擊選人：編號小的刺客比較遠 → 要選近的那隻（舊的依編號選人會選錯）
	var r = Sim.new(army_from(0, [[D.SWORD, 5, 4]]), army_from(1, [[D.ASSASSIN, 5, 2], [D.ASSASSIN, 5, 6]]))
	var sw_i := 0
	var a_far := 1
	var a_near := 2
	r.units[sw_i].x = 8000; r.units[sw_i].y = 4500
	r.units[a_far].x = 8600; r.units[a_far].y = 3900
	r.units[a_near].x = 8500; r.units[a_near].y = 5000
	ok(r.units[a_far].id < r.units[a_near].id and r.pick_counter(sw_i, [a_far, a_near]) == a_near and r.pick_counter(sw_i, [a_near, a_far]) == a_near, "反擊挑最近的刺客，不看編號與順序")
	r.units[a_far].y = 5000; r.units[a_far].x = 8500
	r.units[a_near].y = 4000; r.units[a_near].x = 8500
	ok(r.pick_counter(sw_i, [a_far, a_near]) == a_near, "距離相同時挑列小的")
	ok(s.fingerprint == "" or s.fingerprint.length() == 64, "指紋是 SHA-256")
	var f2 = Sim.new(army_from(0, [[D.SWORD, 5, 4]]), army_from(1, [[D.SWORD, 5, 4]]))
	f2.run_to_end()
	ok(f2.fingerprint.length() == 64, "結束後指紋是 64 碼 SHA-256", f2.fingerprint)

func test_rally() -> void:
	# 背水：紅方剩餘戰力 < 藍方的 RALLY_RATIO_PCT% 時，紅方冷卻每 tick 多扣 RALLY_CD_BONUS
	var s = Sim.new(army_from(0, [[D.SWORD, 0, 0], [D.SWORD, 0, 2], [D.SWORD, 0, 4]]), army_from(1, [[D.SWORD, 0, 8]]))
	var red = s.units[3]
	var blue = s.units[0]
	red.cd = 40
	blue.cd = 40
	s.step()
	ok(s.rally[1] and not s.rally[0], "戰力落後到門檻以下的那一隊進入背水", str(s.rally))
	ok(red.cd == 40 - 4 - D.RALLY_CD_BONUS and blue.cd == 36, "背水那一隊冷卻扣得比較快", "red=%d blue=%d" % [red.cd, blue.cd])

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
	ok(order.slice(0, 10) == [0, 1, 1, 0, 1, 0, 0, 1, 1, 0], "5 手公平輪序（Thue‑Morse）正確", str(order))
	ok(tp.handoffs == 6 and tp.hands_done == [5, 5], "每人 5 手、換人 6 次", "handoffs=%d hands=%s" % [tp.handoffs, str(tp.hands_done)])
	ok(tp.check_place(D.SWORD, 0, 0) != "", "蛇行結束後不能再擺")


## 第二輪方案 R1：騎兵打轉修正
func test_nav_r1() -> void:
	# 繞翼狀態機：直接操作位置，驗「到過就記住」（舊版用「現在距離」判斷，離開後會回頭）
	var s = Sim.new(army_from(0, [[D.CAVALRY, 3, 4]]), army_from(1, [[D.SHIELD, 5, 4], [D.SHIELD, 5, 5], [D.ARCHER, 0, 4]]))
	var cav = s.units[0]
	var ai := -1
	for k in s.units.size():
		if s.units[k].type == D.ARCHER:
			ai = k
	var wp: Vector2i = s._flank_waypoint(0, ai)
	ok(cav.nav == 1 and wp.x >= 0, "被盾兵擋路時會規劃繞翼", str(wp))
	ok(wp.y >= Sim.EDGE + D.FLANK_EDGE_MARGIN and wp.y <= Sim.H - Sim.EDGE - D.FLANK_EDGE_MARGIN, "途經點離上下邊界至少 EDGE＋FLANK_EDGE_MARGIN", str(wp))
	cav.x = wp.x + 100
	cav.y = wp.y
	var r1: Vector2i = s._flank_waypoint(0, ai)
	cav.x = wp.x - 1500   # 離開途經點
	var r2: Vector2i = s._flank_waypoint(0, ai)
	ok(r1.x == -1 and r2.x == -1 and cav.nav == 2, "到過途經點就不再回頭（同一目標）", "r1=%s r2=%s nav=%d" % [r1, r2, cav.nav])
	# 貼邊：騎兵和弓手都在最上列 → 往上沒有空間，只能往下繞或直接追，途經點不會貼在邊界
	var e = Sim.new(army_from(0, [[D.CAVALRY, 3, 0]]), army_from(1, [[D.SHIELD, 5, 0], [D.ARCHER, 0, 0]]))
	var ea := 2
	var ewp: Vector2i = e._flank_waypoint(0, ea)
	ok(ewp.x == -1 or ewp.y >= Sim.EDGE + D.FLANK_EDGE_MARGIN, "上邊緣不會產生貼牆的途經點", str(ewp))
	# 追擊遲滯：目標往外走時，騎兵不會每隔一 tick 停一次
	var c2 = Sim.new(army_from(0, [[D.CAVALRY, 5, 4]]), army_from(1, [[D.ARCHER, 5, 4]]))
	var stops := 0
	var moves := 0
	var prev_moving := false
	var flips := 0
	for i in 120:
		c2.step()
		if not c2.units[0].alive or not c2.units[1].alive:
			break
		var moving: bool = c2.units[0].mx != 0 or c2.units[0].my != 0
		if i > 0 and moving != prev_moving:
			flips += 1
		prev_moving = moving
	ok(flips <= 6, "追擊不會走一步停一步（狀態切換次數少）", "flips=%d" % flips)
	# 不能靠「完全不動」過關：騎兵一定要追上並打到弓手（Codex R1 審查 #5）
	ok(c2.units[1].dmg_taken > 0 or not c2.units[1].alive, "追擊遲滯下騎兵仍然追上並出手", "弓手受傷=%d" % c2.units[1].dmg_taken)
	# 遲滯的邊界：在攻擊距離內不追；超出 reach 才起步；追到 reach−CHASE_HYST 以內才停
	var R := 1000
	var sq := func(v: int) -> int: return v * v
	ok(not Sim.cav_chase(false, sq.call(R - 10), R), "遲滯：停著時在攻擊距離內不起步")
	ok(Sim.cav_chase(false, sq.call(R + 10), R), "遲滯：停著時超出攻擊距離就起步")
	ok(Sim.cav_chase(true, sq.call(R - D.CHASE_HYST + 10), R), "遲滯：追擊中、還沒追進 reach−HYST 就繼續追")
	ok(not Sim.cav_chase(true, sq.call(R - D.CHASE_HYST - 10), R), "遲滯：追進 reach−HYST 才停")


## 殘局標準解回歸（第二輪方案 §1.4）：每關存的標準解都必須打贏；改戰鬥規則後有任何一關變不能過就會紅。
func test_puzzle_solutions() -> void:
	var total := 0
	var bad: Array = []
	for pz in PZ.tutorials() + PZ.puzzles() + PZ.new_puzzles():
		var sols: Array = pz.get("solutions", [])
		if sols.is_empty():
			bad.append("%s 沒有標準解" % pz["id"])
		for sol in sols:
			var a0 = PZ.player_army(pz)
			var allowed: Array = []
			for v in pz.get("allowed", [0, 1, 2, 3, 4]):
				allowed.append(int(v))   # JSON 讀進來是 float，has(int) 會比不到
			for e in sol:
				# 用正式的擺放規則驗合法性：預算、格子在區內、沒有重疊、兵種允許（Codex R1 審查 #5）
				if not allowed.has(int(e[0])):
					bad.append("%s 標準解用了不允許的兵種 %d" % [pz["id"], int(e[0])])
				var why: String = a0.check_place(int(e[0]), int(e[1]), int(e[2]))
				if why != "":
					bad.append("%s 標準解不合法：%s" % [pz["id"], why])
				a0.place(int(e[0]), int(e[1]), int(e[2]))
			var sm = Sim.new(a0, PZ.enemy_army(pz))
			sm.fast = true
			sm.run_to_end()
			total += 1
			if sm.winner != 0:
				bad.append("%s 標準解輸了" % pz["id"])
	var n_pz: int = (PZ.tutorials() + PZ.puzzles() + PZ.new_puzzles()).size()
	for pz in PZ.new_puzzles():
		# 新兵試玩：主角兵種一定要在允許清單、每組標準解都要用到它（第四輪 §4.8）
		for sol in pz.get("solutions", []):
			if sol.filter(func(e): return int(e[0]) == int(pz["unit"])).is_empty():
				bad.append("%s 的標準解沒用到主角兵種" % pz["id"])
	for pz in PZ.puzzles():
		if pz.get("solutions", []).size() < 2:
			bad.append("%s 不到兩組解" % pz["id"])
	ok(total >= n_pz and bad.is_empty(), "%d 關殘局標準解合法且全部打贏、殘局每關 ≥2 解（%d 組）" % [n_pz, total], str(bad))


## 兵種圖鑑（第二輪方案 R3）：資料齊全、技能說明的數值都換得出來、每段示範用真模擬一定觸發預期的技能、老兵筆記贏 5 場解鎖。
func test_codex() -> void:
	ok(CX.validate().is_empty(), "圖鑑資料自我檢查通過", str(CX.validate()))
	var bad: Array = []
	var n := 0
	for sk in CX.data()["skills"]:
		n += 1
		var ex: String = CX.skill(sk)["demo"]["expect"]
		var tags := CX.demo_tags(sk)
		if not tags.has(ex):
			bad.append("%s 沒有觸發 %s（%s）" % [sk, ex, tags])
		for lang in ["zh_TW", "en"]:
			var d := CX.skill_desc(sk, lang)
			if d.contains("{") or d.contains("}"):
				bad.append("%s 說明有沒換掉的常數：%s" % [sk, d])
	ok(n == 25 and bad.is_empty(), "25 個技能示範都觸發預期事件、說明數值都換好", str(bad))
	# 小劇場跳字的位置要是觸發者本人（事件 id ≠ 陣列索引；Codex R3 審查 #2）
	var pop_bad: Array = []
	for sk in CX.data()["skills"]:
		var sm = CX.demo_sim(sk)
		var ex2: String = CX.skill(sk)["demo"]["expect"]
		var got := 0
		for i in int(CX.skill(sk)["demo"]["ticks"]):
			if sm.finished:
				break
			sm.step()
			var hits := CX.expect_hits(sm, ex2)
			var want: Array = []
			for e in sm.events:
				if e.get("tags", []).has(ex2):
					var u = sm.unit_by_id(int(e.get("src", e.get("tgt", -1))))
					want.append(Vector2(u.x, u.y))
			if hits != want:
				pop_bad.append("%s tick%d %s≠%s" % [sk, sm.tick, hits, want])
			got += hits.size()
		if got == 0:
			pop_bad.append("%s 小劇場沒有任何跳字" % sk)
	ok(pop_bad.is_empty(), "小劇場每段都會在觸發者位置跳字", str(pop_bad))
	# 說明的數值真的來自 unit_defs：改常數名就會在上面紅；這裡再對一個值
	ok(CX.skill_desc("shield_block", "zh_TW").contains("×%s" % str(snappedf(float(D.BLOCK_NUM) / D.BLOCK_DEN, 0.01))), "技能說明的數值取自 unit_defs")
	var sd := {}
	var newly: Array = []
	for i in CX.NOTE_WINS:
		if i == CX.NOTE_WINS - 1:
			ok(not CX.note_unlocked(sd, D.CAVALRY), "老兵筆記：贏 %d 場時還沒解鎖" % i)
		newly = CX.record_win(sd, [D.CAVALRY, D.CAVALRY, D.SWORD])
	ok(CX.note_unlocked(sd, D.CAVALRY) and CX.wins_with(sd, D.CAVALRY) == CX.NOTE_WINS, "老兵筆記：同一場同兵種只算一次、贏 5 場解鎖")
	ok(newly.has(D.CAVALRY) and newly.has(D.SWORD) and not CX.note_unlocked(sd, D.ARCHER), "老兵筆記：剛好第 5 場回報新解鎖、沒派的兵種不解鎖")


## 戰鬥畫面的事件分流（Codex R3 審查 #1）：真實戰鬥出現的每一種事件都要分到合法的路線，攻擊一定帶 src／tgt／dmg，
## 背水開關（沒有 src）不能被當成攻擊。純模擬測試抓不到畫面層讀不存在的欄位，所以直接測分流函式。
func test_event_routes() -> void:
	var pool := F.training_pool(0)
	var kinds := {}
	var bad: Array = []
	for i in 30:
		var sm = Sim.new(pool[i].copy(), pool[(i * 7 + 3) % pool.size()].mirrored())
		sm.fast = true
		while not sm.finished:
			sm.step()
			for e in sm.events:
				if not EVS.KINDS.has(e["kind"]):
					bad.append("未登記的事件種類 %s" % e["kind"])
				for tg in e.get("tags", []):
					if not EVS.TAGS.has(tg):
						bad.append("未登記的標籤 %s" % tg)
				var r := BV.event_route(e)
				kinds[e["kind"]] = r
				if r == "attack" and not (e.has("src") and e.has("tgt") and e.has("dmg")):
					bad.append(e)
				if (r == "taunt" or r == "reveal") and sm.unit_by_id(int(e["src"])) == null:
					bad.append(e)
	ok(kinds.get("rally_on", "") == "skip" and kinds.get("flank", "") == "skip" and kinds.get("taunt", "") == "taunt"
		and kinds.get("reveal", "") == "reveal" and kinds.get("hit", "") == "attack" and kinds.get("death", "") == "death" and bad.is_empty(),
		"戰鬥畫面事件分流：背水／繞翼不當攻擊、攻擊都帶完整欄位", "%s %s" % [kinds, bad.slice(0, 3)])


## 不出聲的音效替身：讓畫面層可以在 headless 測試裡跑（只記錄播了什麼）。
class FakeSfx:
	var played: Array = []
	func play(n: String, _v := 1.0) -> void:
		played.append(n)
	func play_music(_n: String) -> void:
		pass
	func set_muffled(_on: bool) -> void:
		pass
	func set_layer_targets(_g: Array) -> void:
		pass
	static func layer_targets(close: bool, clutch: bool) -> Array:
		return [1.0, 1.0 if close else 0.35, 1.0] if not clutch else [1.0, 0.0, 0.0]

## 畫面層真的消費事件（Codex R3 第 2 輪）：把真實戰鬥的每個 tick 交給戰鬥畫面的 _sim_step（含 _on_event、展示緩衝），
## 不能報錯、攻擊事件一定產生演出；圖鑑的 _codex_tick 每段示範都要真的跳字、跳在觸發者身上。
func test_ui_consumers() -> void:
	var GS = load("res://scripts/ui/game_screens.gd")
	# 畫面腳本有語法錯誤時要紅，不能靜靜跳過後面的檢查（收尾時抓到過一次：79 通過 0 失敗但其實沒跑）
	ok(GS != null and GS.can_instantiate(), "畫面腳本（game_screens 繼承鏈）能載入")
	if GS == null or not GS.can_instantiate():
		return
	var g = GS.new()
	g.sfx = FakeSfx.new()
	var pool := F.training_pool(0)
	var attacks := 0
	var fx_seen := 0
	var kinds := {}
	var bad: Array = []
	for i in 6:
		g.sim = Sim.new(pool[i].copy(), pool[(i * 11 + 5) % pool.size()].mirrored())
		g.view = g.ViewBuffer.new(g.sim)
		g.atk_hit.clear()
		g.state = g.St.BATTLE
		g._pump_view()
		var guard := 0
		while not g.view.finished and guard < 2000:
			guard += 1
			g.fx.clear()
			g._sim_step(true)
			var n_att := 0
			var srcs := {}
			for f in g.fx:
				if f.has("src"):
					srcs[f["src"]] = int(srcs.get(f["src"], 0)) + 1
			for e in g.view.events:
				kinds[e["kind"]] = true
				if g.event_route(e) == "attack" and e["kind"] != EVS.SPLASH:   # 波及跟著同一顆炸彈的爆炸演出，不另畫
					n_att += 1
					# 逐事件核對：每一次攻擊都要有一個屬於攻擊者的砍擊／箭（Codex 收尾輪 #5）
					if int(srcs.get(e["src"], 0)) <= 0:
						bad.append("tick%d 單位 %d 的攻擊（%s）沒有演出" % [g.view.tick, e["src"], e["kind"]])
					else:
						srcs[e["src"]] -= 1
			attacks += n_att
			if n_att > 0:
				fx_seen += 1
		if g.view.tick != g.sim.tick or not g.sim.finished:
			bad.append("第 %d 場畫面沒有播到最後（畫面 %d／模擬 %d）" % [i, g.view.tick, g.sim.tick])
	ok(bad.is_empty() and attacks > 100 and kinds.has("rally_on") and kinds.has("death"), "戰鬥畫面消費真實事件：不報錯、攻擊都有演出、緩衝會排空", "%s attacks=%d kinds=%s" % [bad.slice(0, 3), attacks, kinds.keys()])
	# 前搖：攻擊者在命中那一格之前就已經開始動作（展示緩衝的目的）
	g.sim = Sim.new(army_from(0, [[D.SWORD, 5, 4]]), army_from(1, [[D.SHIELD, 5, 4]]))
	g.view = g.ViewBuffer.new(g.sim)
	g.atk_hit.clear()
	g._pump_view()
	var pre_ok := false
	for i in 200:
		var before_hit := false
		for fr in g.view.queue:
			for e in fr["events"]:
				if g.event_route(e) == "attack" and int(fr["tick"]) == g.view.tick + 1:
					before_hit = true
		if before_hit:
			var u = g.view.units[0]
			var hh: int = g.pick_hit(g.atk_hit[u.id], g._disp_tick(), u.type)
			var at: float = g.atk_progress(g._disp_tick() - (hh - g.ViewBuffer.DELAY), u.type) if hh >= 0 else 0.0
			if at > 0.0 and at < Art.ATK_WINDUP:
				pre_ok = true
				break
		g._sim_step(false)
	ok(pre_ok, "命中前一格畫面上已經在前搖")
	# 連續反擊（Codex R5 #2）：H 的揮擊不會被 H+1／H+2 的前搖吃掉；揮擊做完才換下一次
	var sw_t := D.SWORD
	ok(g.pick_hit([10, 11, 12], 10.0, sw_t) == 10 and g.pick_hit([10, 11, 12], 10.9, sw_t) == 10, "連續命中：前一次揮擊做完前不換")
	# 揮擊結束時間和 atk_progress 共用：劍士 cd 20 tick → 總長 6.4、揮擊 1.408，所以 11.2 還在第一擊（Codex S4 #1）
	ok(g.pick_hit([10, 12], 11.2, sw_t) == 10 and g.atk_progress(11.2 - 8.0, sw_t) < Art.ATK_STRIKE, "連續命中：揮擊結束時間與動作進度一致")
	ok(g.pick_hit([10, 12], 11.5, sw_t) == 12 and g.pick_hit([10], 7.9, sw_t) == -1 and g.pick_hit([10], 8.0, sw_t) == 10, "連續命中：揮擊做完換下一次、前搖從命中前 2 tick 開始")
	# 播完之後（Codex R5 #1）：經過正式的 _battle_process，最後一格插值走完、展示時鐘繼續讓後搖演完、最後才進結果
	g.sim = Sim.new(army_from(0, [[D.SWORD, 5, 4], [D.SWORD, 5, 5]]), army_from(1, [[D.ARCHER, 5, 4]]))
	g.view = g.ViewBuffer.new(g.sim)
	g.atk_hit.clear()
	g.state = g.St.BATTLE
	g.speed = 1.0
	g.slow_used = true
	g.result_delay = 0.0
	g._pump_view()
	var steps := 0
	while not g.view.finished and steps < 4000:
		g._battle_process(0.05)
		steps += 1
	var tail_ok: bool = g.view.finished and g.state == g.St.BATTLE
	g._battle_process(0.1)
	var d1: float = g._disp_tick()
	g._battle_process(0.1)
	var d2: float = g._disp_tick()
	var pos_ok := true
	for u in g.view.units:
		var jit := Vector2(float((u.id * 37) % 9 - 4), float((u.id * 53) % 7 - 3))   # _upos 的固定錯開
		if u.alive and g._upos(u).distance_to(g.ORIGIN + Vector2(u.x, u.y) * g.CS / 1000.0 + jit) > 0.5:
			pos_ok = false
	ok(tail_ok and d2 > d1 and d1 > g.view.tick and pos_ok, "播完後展示時鐘繼續走、存活者插值到最後位置", "tail=%s d1=%.2f d2=%.2f tick=%d pos=%s" % [tail_ok, d1, d2, g.view.tick, pos_ok])
	# 直接造「最後一格確實有移動、最後一擊剛命中」的狀態（Codex 收尾輪 2 #5）：
	# 播完後經 _battle_process，位置要從上一格插值到最後一格，攻擊要經過後搖並完成（進度回到 0）。
	g.state = g.St.BATTLE
	g.accum = 0.0
	var mu = null
	for u in g.view.units:
		if u.alive:
			mu = u
			break
	var cur := Vector2(mu.x, mu.y)
	g.prev_pos[mu.id] = cur - Vector2(600, 0)          # 上一格在左邊 0.6 格
	g.atk_hit[mu.id] = [g.view.tick]                   # 最後一格剛命中
	var jit2 := Vector2(float((mu.id * 37) % 9 - 4), float((mu.id * 53) % 7 - 3))
	var start_dist: float = g._upos(mu).distance_to(g.ORIGIN + cur * g.CS / 1000.0 + jit2)
	var saw_recover := false
	var done := false
	for k in 12:
		g._battle_process(0.05)
		var hh2: int = g.pick_hit(g.atk_hit[mu.id], g._disp_tick(), mu.type)
		var at2: float = g.atk_progress(g._disp_tick() - (hh2 - g.ViewBuffer.DELAY), mu.type) if hh2 >= 0 else 0.0
		if at2 > Art.ATK_STRIKE:
			saw_recover = true
		if saw_recover and at2 == 0.0:
			done = true
	var end_dist: float = g._upos(mu).distance_to(g.ORIGIN + cur * g.CS / 1000.0 + jit2)
	ok(start_dist > 30.0 and end_dist < 0.5 and saw_recover and done, "播完後最後一格的移動插值走完、最後一擊演完後搖",
		"start=%.1f end=%.2f recover=%s done=%s" % [start_dist, end_dist, saw_recover, done])
	# 圖鑑小劇場真的跳字
	var pop_bad: Array = []
	for t in D.COUNT:
		g._open_codex(t)
		for k in g._cx_skills().size():
			g._cx_pick_skill(k)
			var seen := false
			for j in 400:
				g._codex_tick(0.05)
				if not g.cx_pops.is_empty():
					seen = true
					break
			if not seen:
				pop_bad.append(g._cx_skills()[k])
	ok(pop_bad.is_empty(), "圖鑑每段小劇場都真的跳字", str(pop_bad))
	g.free()


## 音效優先權（第二輪方案 R8）：聲道滿了，技能音搶走最低優先權裡最早開始的普通命中；普通命中搶不到技能音；有空位先用空位。
func test_sfx_priority() -> void:
	var SX = load("res://scripts/game/sfx.gd")
	var busy := [true, true, true, true]
	ok(SX.pick_channel([true, false, true, true], [0, 0, 0, 0], [0, 0, 0, 0], 0) == 1, "音效：有空聲道先用空的")
	ok(SX.pick_channel(busy, [2, 0, 0, 2], [0, 50, 10, 0], 2) == 2, "音效：滿了時技能音搶最低優先權裡最早開始的")
	ok(SX.pick_channel(busy, [2, 2, 3, 2], [0, 0, 0, 0], 0) == -1, "音效：普通命中搶不到技能音")
	ok(SX.pick_channel(busy, [2, 2, 2, 2], [0, 0, 0, 0], 2) == -1, "音效：同級不互搶")
	var missing: Array = []
	for n in SX.FILES:
		if not FileAccess.file_exists("res://audio/%s.wav" % n):
			missing.append(n)
	for n in SX.PRIO:
		if not SX.FILES.has(n):
			missing.append("PRIO 有但 FILES 沒有：" + n)
	for n in SX.LAYERS:
		if not FileAccess.file_exists("res://audio/%s.wav" % n):
			missing.append(n)
	ok(missing.is_empty(), "音效：清單裡的檔案都在（含三條戰鬥分軌）", str(missing))
	var looped := true
	for n in SX.LAYERS:
		var st = load("res://audio/%s.wav" % n)
		if not (st is AudioStreamWAV) or st.loop_mode != AudioStreamWAV.LOOP_FORWARD or absf(float(st.loop_end) / st.mix_rate - st.get_length()) > 0.1:
			looped = false
	ok(looped, "分軌音樂：三軌都整段循環（循環終點＝整首長度，Codex S7 #1）")
	ok(SX.layer_targets(true, false) == [1.0, 1.0, 1.0] and SX.layer_targets(false, false)[1] < 0.5 and SX.layer_targets(true, true) == [1.0, 0.0, 0.0],
		"分軌音樂：差距小鼓聲進來、最後時刻只留低音")


## 存檔遷移（第二輪方案 R8）：v1 進度不掉、補上 unit_wins、改用 schema_version；不認得的欄位保留；新版存檔不降版。
func test_save_migration() -> void:
	var SV = load("res://scripts/game/save.gd")
	var v1 := {"version": 1, "tutorial": 3, "puzzle_stars": {"p1": 3}, "slots": ["NTB1.x", "", "", "", ""], "stats": {"wins": 7, "games": 9}, "future_key": 5}
	var m: Dictionary = SV.migrate(v1)
	ok(int(m["schema_version"]) == 3 and not m.has("version") and m["unit_wins"] is Dictionary, "存檔遷移：v1→v3 改欄位名、補 unit_wins")
	ok(int(m["unlock_games"]) == 9 and m["rule_presets"] == [] and m["custom_stats"] is Dictionary, "存檔遷移 v3：解鎖累計場數＝舊的正式場數（已解鎖的兵不會被收回）")
	var bad_ps := {"schema_version": 3, "rule_presets": [{"name": "a", "code": "NTBR1.x.y"}, {"name": 3, "code": "z"}, "junk", {"name": "b", "code": "x".repeat(3000)}] + [{"name": "c", "code": "q"}]}
	var m3: Dictionary = SV.migrate(bad_ps)
	ok(m3["rule_presets"].size() == 2 and str(m3["rule_presets"][0]["name"]) == "a", "存檔遷移：我的預設逐筆驗型、限長（壞的丟掉）", str(m3["rule_presets"]))
	ok(int(m["tutorial"]) == 3 and int(m["puzzle_stars"]["p1"]) == 3 and m["slots"][0] == "NTB1.x" and int(m["stats"]["wins"]) == 7 and int(m["future_key"]) == 5, "存檔遷移：舊進度與不認得的欄位都保留")
	var v2 := {"schema_version": 2, "unit_wins": {"3": 4}, "tutorial": 1}
	var m2: Dictionary = SV.migrate(v2)
	ok(int(m2["unit_wins"]["3"]) == 4 and m2.has("achievements"), "存檔遷移：v2 原樣保留、缺的欄位補預設")
	# 正式載入流程（Codex 收尾輪 #1）：寫一個 v1 檔，用 load_all 讀，舊鍵要被遷移掉
	var old_prefix: String = SV.prefix
	SV.prefix = "test_mig_"
	var f := FileAccess.open("user://test_mig_save.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "tutorial": 2, "unit_wins": 5}))
	f.close()
	SV.load_all()
	var ld: Dictionary = SV.data
	ok(int(ld["schema_version"]) == 3 and not ld.has("version") and ld["unit_wins"] is Dictionary and int(ld["tutorial"]) == 2 and ld.has("achievements"),
		"存檔遷移：正式 load_all 讀 v1 檔會遷移、壞掉的 unit_wins 修好、補預設", str(ld))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_mig_save.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_mig_settings.json"))
	SV.prefix = old_prefix
	var v9 := {"schema_version": 9, "x": 1}
	ok(SV.migrate(v9) == v9, "存檔遷移：比目前新的版本不降版")


## 副作用矩陣（第三輪 A1）：正式對局才寫比分、進度、成就、試玩日誌；重播 3 次全部不變。
## 走正式畫面程式（_begin_battle → _sim_step → _finish_battle → _replay），存檔用測試前綴，不碰玩家存檔。
func test_play_effects() -> void:
	var SV = load("res://scripts/game/save.gd")
	var GS = load("res://scripts/ui/game_screens.gd")
	if GS == null or not GS.can_instantiate():
		ok(false, "副作用矩陣：畫面腳本載入失敗")
		return
	var old_prefix: String = SV.prefix
	SV.prefix = "test_fx_"
	for fn in ["user://test_fx_save.json", "user://test_fx_save.json.bak", "user://test_fx_settings.json"]:
		if FileAccess.file_exists(fn):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(fn))
	SV.load_all()
	var g = GS.new()
	g.sfx = FakeSfx.new()
	g.mode = g.Mode.VS_AI
	g.difficulty = 1
	var keys := ["official", "replay", "review"]
	var mx_ok := true
	for k in keys:
		mx_ok = mx_ok and g.PLAY_EFFECTS.has(k)
	ok(mx_ok and g.PLAY_EFFECTS["official"]["progress"] and not g.PLAY_EFFECTS["replay"]["progress"] and not g.PLAY_EFFECTS["review"]["series"], "副作用矩陣：三種播放都有定義、只有正式會寫")
	var a0 = army_from(0, [[D.SWORD, 5, 4], [D.CAVALRY, 4, 2], [D.ARCHER, 1, 4]])
	var a1 = army_from(1, [[D.SWORD, 5, 4]])
	var play := func(kind: String) -> void:
		if kind == "official":
			g._begin_battle(a0.copy(), a1.copy())
		else:
			g._replay()
		var guard := 0
		while not g.view.finished and guard < 3000:
			g._sim_step(false)
			guard += 1
		g._finish_battle()
	play.call("official")
	var snap := func() -> String:
		return JSON.stringify([SV.data.get("stats"), SV.data.get("unit_wins"), SV.data.get("achievements"), g.wins, g.series_over, SV.data.get("custom_stats"), SV.data.get("unlock_games")])
	var after_official: String = snap.call()
	var games_1 := int(SV.data["stats"]["games"])
	for i in 3:
		play.call("replay")
	ok(games_1 == 1 and snap.call() == after_official and g.play_kind == "replay", "重播 3 次：場次、勝場、兵種勝場、成就、系列比分都不變", "%s → %s" % [after_official, snap.call()])
	play.call("official")
	ok(int(SV.data["stats"]["games"]) == 2, "重播之後再打正式的一場，照常記錄")
	# 覆盤播放：只看不算（副作用矩陣 review）
	var snap2: String = snap.call()
	g._open_review()
	g.rv_sel = Vector2i(5, 4)
	g._rv_set_type(D.SHIELD)
	g._rv_recalc()
	g._rv_play()
	var guard2 := 0
	while not g.view.finished and guard2 < 3000:
		g._sim_step(false)
		guard2 += 1
	g._finish_battle()
	ok(g.play_kind == "review" and snap.call() == snap2, "覆盤播放：比分、進度、成就都不變")
	# 第五輪：自訂規則（單局）→ 記在自訂戰績、解鎖場數 +1，標準戰績與標準成就不動；沙盒什麼都不記
	var RS5 = load("res://scripts/core/ruleset.gd")
	var cr = RS5.standard()
	cr.rounds = 1
	g.rules = cr
	var st_before := JSON.stringify(SV.data.get("stats"))
	var ach_before := JSON.stringify(SV.data.get("achievements"))
	var cs_before := int(SV.data.get("custom_stats", {}).get("games", 0))
	var ug_before := int(SV.data.get("unlock_games", 0))
	play.call("official")
	ok(JSON.stringify(SV.data.get("stats")) == st_before and JSON.stringify(SV.data.get("achievements")) == ach_before
		and int(SV.data["custom_stats"]["games"]) == cs_before + 1 and int(SV.data["unlock_games"]) == ug_before + 1,
		"自訂規則（單局，雖然數值是標準）：記在自訂戰績、解鎖場數 +1，標準戰績與成就不變", "%s %s" % [SV.data.get("custom_stats"), SV.data.get("unlock_games")])
	var sb = RS5.standard()
	sb.stat_pct = {D.SWORD: [150, 100, 100]}
	g.rules = sb
	var snap3: String = snap.call()
	play.call("official")
	var after3: String = snap.call()
	ok(JSON.stringify(JSON.parse_string(after3).slice(0, 3) + JSON.parse_string(after3).slice(5, 7)) == JSON.stringify(JSON.parse_string(snap3).slice(0, 3) + JSON.parse_string(snap3).slice(5, 7)),
		"沙盒：戰績、自訂戰績、解鎖場數、成就都不記", "%s → %s" % [snap3, after3])
	g.rules = null
	g.free()
	for fn in ["user://test_fx_save.json", "user://test_fx_save.json.bak", "user://test_fx_settings.json"]:
		if FileAccess.file_exists(fn):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(fn))
	SV.prefix = old_prefix
	SV.load_all()


## 輸入命令佇列（第三輪 A2）：畫面一換，同一幀排進來的舊命令就丟掉；只對這個畫面畫出來的按鈕有效；停用的按鈕不執行。
func test_input_queue() -> void:
	var GS = load("res://scripts/ui/game_screens.gd")
	if GS == null or not GS.can_instantiate():
		ok(false, "輸入佇列：畫面腳本載入失敗")
		return
	var g = GS.new()
	g.sfx = FakeSfx.new()
	var hits := [0, 0]
	var setup := func(next_state) -> void:
		g._cmds.clear()
		g.state = g.St.TITLE
		g.overlay = ""
		g._update_gen()
		g._btns = [
			{"r": Rect2(0, 0, 100, 40), "cb": func(): hits[0] += 1; g.state = next_state, "en": true},
			{"r": Rect2(0, 50, 100, 40), "cb": func(): hits[1] += 1, "en": false},
		]
		g._btns_gen = g._gen
	var bad: Array = []
	# 1 正常點一下：執行一次
	hits[0] = 0; hits[1] = 0; setup.call(g.St.TITLE); g._enqueue("click", Vector2(10, 10)); g._process_cmds()
	if hits[0] != 1: bad.append("1 正常點擊 %s" % [hits])
	# 2 同一幀連點兩下，第一下換了畫面：第二下丟掉
	hits[0] = 0; hits[1] = 0; setup.call(g.St.PLACE); g._enqueue("click", Vector2(10, 10)); g._enqueue("click", Vector2(10, 10)); g._process_cmds()
	if hits[0] != 1: bad.append("2 連點換畫面 %s" % [hits])
	# 3 停用的按鈕不執行
	hits[0] = 0; hits[1] = 0; setup.call(g.St.TITLE); g._enqueue("click", Vector2(10, 60)); g._process_cmds()
	if hits[1] != 0: bad.append("3 停用按鈕 %s" % [hits])
	# 4 點擊排入後、處理前開了覆蓋層：丟掉
	hits[0] = 0; hits[1] = 0; setup.call(g.St.TITLE); g._enqueue("click", Vector2(10, 10)); g.overlay = "settings"; g._process_cmds()
	if hits[0] != 0: bad.append("4 開覆蓋層後的舊點擊 %s" % [hits])
	# 5 畫面換了但新畫面的按鈕還沒畫：新排入的點擊也不能點到舊按鈕
	hits[0] = 0; hits[1] = 0; setup.call(g.St.TITLE); g.state = g.St.RESULT; g._update_gen(); g._enqueue("click", Vector2(10, 10)); g._process_cmds()
	if hits[0] != 0: bad.append("5 舊按鈕清單 %s" % [hits])
	# 6 Esc 關掉覆蓋層，同一幀後面的點擊丟掉
	hits[0] = 0; hits[1] = 0; setup.call(g.St.TITLE); g.overlay = "settings"; g._update_gen(); g._btns_gen = g._gen
	g._enqueue("key", KEY_ESCAPE); g._enqueue("click", Vector2(10, 10)); g._process_cmds()
	if hits[0] != 0 or g.overlay != "": bad.append("6 Esc 後的點擊 %s overlay=%s" % [hits, g.overlay])
	# 7 Enter 按焦點按鈕；按鈕清單過期時不按
	hits[0] = 0; hits[1] = 0; setup.call(g.St.TITLE); g._focus = 0; g._enqueue("key", KEY_ENTER); g._process_cmds()
	if hits[0] != 1: bad.append("7a Enter %s" % [hits])
	hits[0] = 0; hits[1] = 0; setup.call(g.St.TITLE); g._btns_gen = -1; g._focus = 0; g._enqueue("key", KEY_ENTER); g._process_cmds()
	if hits[0] != 0: bad.append("7b 過期 Enter %s" % [hits])
	# 9 同一幀先按 2（選盾兵）再點格子：擺下的是盾兵（Codex S1 #2：滑鼠也進同一個佇列）
	g.mode = g.Mode.VS_AI
	g.armies = [Army.new(0, 100), Army.new(1, 100)]
	g.state = g.St.PLACE
	g.overlay = ""
	g.selected = D.SWORD
	g._cmds.clear()
	g._update_gen()
	g._btns = []
	g._btns_gen = g._gen
	var cellp: Vector2 = g.ORIGIN + Vector2(4.5, 4.5) * g.CS
	g._enqueue("key", KEY_2)
	g._enqueue("mb", {"i": MOUSE_BUTTON_LEFT, "pressed": true, "pos": cellp})
	g._enqueue("mb", {"i": MOUSE_BUTTON_LEFT, "pressed": false, "pos": cellp})
	g._process_cmds()
	var placed: Array = g.armies[0].units
	if placed.size() != 1 or int(placed[0]["type"]) != D.SHIELD:
		bad.append("9 先選兵再點格子 %s" % [placed])
	# 10 開了圖鑑之後同一幀的塗兵命令要丟掉
	g.painting = true
	g.paint_team = 0
	g._enqueue("key", KEY_F1)
	g._enqueue("paint", g.ORIGIN + Vector2(3.5, 3.5) * g.CS)
	g._process_cmds()
	if g.armies[0].units.size() != 1:
		bad.append("10 開圖鑑後的塗兵 %d" % g.armies[0].units.size())
	g.overlay = ""
	# 11 搖桿連發：推下立刻一次、0.35 秒後每 0.12 秒一次；0.35～0.6 之間的抖動維持原狀；放開就停（Codex S1 #6）
	g.overlay = "settings"
	g.state = g.St.TITLE
	g._update_gen()
	g._cmds.clear()
	g.stick[JOY_AXIS_LEFT_Y] = 0.8
	g._stick_repeat(0.0)
	var n1: int = g._cmds.size()
	g._stick_repeat(0.2)
	var n2: int = g._cmds.size()
	g.stick[JOY_AXIS_LEFT_Y] = 0.5          # 抖動但沒放開
	g._stick_repeat(0.2)
	var n3: int = g._cmds.size()
	for k in 5:
		g._stick_repeat(0.12)
	var n4: int = g._cmds.size()
	g.stick[JOY_AXIS_LEFT_Y] = 0.1
	g._stick_repeat(0.5)
	var n5: int = g._cmds.size()
	if n1 != 1 or n2 != 1 or n3 != 2 or n4 != 7 or n5 != 7:
		bad.append("11 搖桿連發 %s" % [[n1, n2, n3, n4, n5]])
	g._cmds.clear()
	g.overlay = ""
	# 8 點在按鈕外：什麼都不做
	hits[0] = 0; hits[1] = 0; setup.call(g.St.TITLE); g._enqueue("click", Vector2(500, 500)); g._process_cmds()
	if hits != [0, 0]: bad.append("8 點空白 %s" % [hits])
	ok(bad.is_empty(), "輸入佇列：11 組序列（連點、換畫面、停用、覆蓋層、過期清單、Esc、Enter、選兵後落子、開圖鑑後塗兵、搖桿連發、空白）誤觸與重複執行都是 0", str(bad))
	g.free()


## 確定性金標準（第三輪 T2；第四輪 N0a 改抽 100 場）：前 100 場對金標準檔（完整 1000 場在 tools/check_all.sh）；
## fast 模式與正式模式逐 tick 狀態、事件完全一樣；陣型清單順序打亂結果不變。
func test_golden() -> void:
	var GT = load("res://tools/golden.gd")
	var r: Dictionary = GT.check(100)
	ok(r["ok"], "金標準：前 100 場逐 100 tick 狀態、勝負、指紋都一致", str(r))
	var g = JSON.parse_string(FileAccess.get_file_as_string("res://tests/golden/golden.json"))
	var bad: Array = []
	for i in 30:
		var c: Dictionary = g["cases"][i]
		var a0 := Army.new(0, 100); a0.load_code(c["a"])
		var a1 := Army.new(1, 100); a1.load_code(c["b"])
		var s1 = Sim.new(a0.copy(), a1.copy())
		var s2 = Sim.new(a0.copy(), a1.copy())
		s2.fast = true
		while not s1.finished:
			s1.step()
			s2.step()
			if GT.state_sig(s1) != GT.state_sig(s2) or JSON.stringify(s1.events) != JSON.stringify(s2.events):
				bad.append("場 %d tick %d" % [i, s1.tick])
				break
		if not s2.finished:
			bad.append("場 %d fast 沒同時結束" % i)
	ok(bad.is_empty(), "fast 與正式模式逐 tick 狀態與事件一致（30 場）", str(bad.slice(0, 3)))
	# 陣型清單順序不影響結果
	var order_bad := 0
	var rng := RandomNumberGenerator.new()
	for i in 20:
		var c2: Dictionary = g["cases"][i]
		var b0 := Army.new(0, 100); b0.load_code(c2["a"])
		var b1 := Army.new(1, 100); b1.load_code(c2["b"])
		var x0 = b0.copy()
		var x1 = b1.copy()
		rng.seed = i + 99
		for k in range(x0.units.size() - 1, 0, -1):
			var j := rng.randi_range(0, k)
			var tmp = x0.units[k]; x0.units[k] = x0.units[j]; x0.units[j] = tmp
		x1.units.reverse()
		var sa = Sim.new(b0, b1); sa.run_to_end()
		var sb = Sim.new(x0, x1); sb.run_to_end()
		if sa.fingerprint != sb.fingerprint:
			order_bad += 1
	ok(order_bad == 0, "陣型清單順序打亂，指紋不變（20 場）", "不同 %d 場" % order_bad)


## 混戰可讀（第三輪 V1／V3）：用正式畫面程式逐幀播 6 場 48 隻左右的戰鬥（60fps），每幀量跳字外框：
## 正常顯示的兩兩重疊 0%、淡出中 ≤5%；關鍵跳字（衝鋒、背刺、頂住）一個都不漏；特效數不超過上限。
func test_crowd_readability() -> void:
	var GS = load("res://scripts/ui/game_screens.gd")
	if GS == null or not GS.can_instantiate():
		ok(false, "混戰可讀：畫面腳本載入失敗")
		return
	var g = GS.new()
	g.sfx = FakeSfx.new()
	g.font = load("res://fonts/NotoSansTC-Regular-sub.otf")
	g.font_bold = load("res://fonts/NotoSansTC-Bold-sub.otf")
	var pool := F.training_pool(0)
	var worst := 0.0
	var worst_f := 0.0
	var max_fx := 0
	var max_txt := 0
	var frames := 0
	var unplaced := 0
	for i in 6:
		g._begin_battle(pool[i * 3].copy(), pool[(i * 17 + 4) % pool.size()].mirrored(), "replay")
		g.speed = 1.0
		var guard := 0
		while g.state == g.St.BATTLE and not g.view.finished and guard < 9000:
			guard += 1
			g._process_inner(1.0 / 60.0)
			frames += 1
			for f in g.fx:
				if f["kind"] == "text" and not f.get("screen", false) and not f.has("rr"):
					unplaced += 1
			var st: Dictionary = g.text_overlap_stats()
			worst = maxf(worst, st["max_overlap"])
			worst_f = maxf(worst_f, st["max_overlap_fading"])
			max_txt = maxi(max_txt, st["visible"] + st["fading"])
			var nfx := 0
			for f in g.fx:
				if f["kind"] != "text":
					nfx += 1
			max_fx = maxi(max_fx, nfx)
	ok(unplaced == 0, "跳字：每一個要畫的跳字都已排版（沒排版的 %d 個）" % unplaced)
	ok(worst == 0.0 and worst_f <= 0.05, "跳字：正常顯示 0%% 重疊、淡出中 ≤5%%（%d 幀；最大 %.3f／%.3f）" % [frames, worst, worst_f])
	ok(g.text_key_in > 0 and g.text_key_in == g.text_key_shown, "關鍵跳字一個都不漏（%d／%d）" % [g.text_key_shown, g.text_key_in])
	# 壓力：一口氣塞 30 個不同種的關鍵跳字，上限仍是硬的（Codex S3）
	g.fx.clear()
	for k in 30:
		g._merge_text(k, ["charge", "backstab", "braced"][k % 3], "X", 1, Vector2(k * 37 % 500, k * 53 % 300), Color.WHITE)
	var nt := 0
	for f in g.fx:
		if f["kind"] == "text":
			nt += 1
	ok(nt <= g.TEXT_CAP, "關鍵跳字一口氣 30 個，畫面上仍 ≤%d 個（%d）" % [g.TEXT_CAP, nt])
	ok(max_txt <= g.TEXT_CAP and max_fx <= g.FX_CAP, "跳字與特效有上限（跳字最多 %d、特效最多 %d；丟掉一般跳字 %d、特效 %d）" % [max_txt, max_fx, g.text_dropped, g.fx_dropped])
	g.free()


## 回味（第三輪 S5）：對戰代碼來回、竄改要擋、版本不同要提示；覆盤一次只算改一隻、只看不算戰績；
## 重播跳轉：跳到第 t tick 再往下播，畫面狀態與結局要和從頭播一模一樣。
func test_replay_tools() -> void:
	var BC = load("res://scripts/game/battle_code.gd")
	var a0 = army_from(0, [[D.SWORD, 5, 4], [D.ARCHER, 1, 3], [D.CAVALRY, 3, 7]])
	var a1 = army_from(1, [[D.SHIELD, 5, 4], [D.ASSASSIN, 3, 2]])
	var code: String = BC.encode(a0, a1)
	var r: Dictionary = BC.decode(code)
	ok(r["ok"] and not r["mismatch"] and r["a0"].to_code() == a0.to_code() and r["a1"].to_code() == a1.to_code(), "對戰代碼：編碼再解碼，雙方陣型一樣")
	var tampered := code.substr(0, 10) + ("A" if code[10] != "A" else "B") + code.substr(11)
	ok(not BC.decode(tampered)["ok"] and not BC.decode("NTB1.xx.yy")["ok"], "對戰代碼：被改過或格式不對會擋下")
	var parts := code.split(".")
	var j = JSON.parse_string(Marshalls.base64_to_utf8(_pad64(parts[1])))
	j["r"] = "0.0.1"
	var body := Marshalls.utf8_to_base64(JSON.stringify(j)).replace("+", "-").replace("/", "_").replace("=", "")
	var old_ver := "NTB2.%s.%s" % [body, body.sha256_text().substr(0, 6)]
	var r2: Dictionary = BC.decode(old_ver)
	ok(r2["ok"] and r2["mismatch"], "對戰代碼：別的版本的代碼可以讀，但會標示版本不同")
	# 預算也要來回（Codex S5 #1）：遠征敵軍 160 金、殘局玩家 30 金
	var big := Army.new(1, 160)
	for k in 9:
		big.place(D.CAVALRY if k % 2 == 0 else D.SHIELD, 10 + k % 6, k)
	var small = army_from(0, [[D.SWORD, 5, 4]])
	small.budget = 30
	var r3: Dictionary = BC.decode(BC.encode(small, big))
	ok(r3["ok"] and r3["a1"].budget == 160 and r3["a0"].budget == 30 and r3["a1"].to_code() == big.to_code(), "對戰代碼：預算不是 100 的陣型也能來回", str(r3.get("why", "")))
	# 覆盤：改動計數
	var GS = load("res://scripts/ui/game_screens.gd")
	if GS == null or not GS.can_instantiate():
		ok(false, "回味：畫面腳本載入失敗")
		return
	var b0 = a0.copy()
	b0.remove_at(5, 4)
	b0.place(D.SHIELD, 5, 4)
	var b1 = a0.copy()
	b1.move(1, 3, 2, 3)
	var b2 = b1.copy()
	b2.remove_at(5, 4)
	ok(GS.review_changes(a0, a0) == 0 and GS.review_changes(a0, b0) == 1 and GS.review_changes(a0, b1) == 1 and GS.review_changes(a0, b2) == 2,
		"覆盤：換兵種、移一格各算一隻，兩處算兩隻")
	var rr: Dictionary = GS.review_run(b0, a1)
	var sm = Sim.new(b0.copy(), a1.copy()); sm.run_to_end()
	ok(int(rr["winner"]) == sm.winner and int(rr["ticks"]) == sm.tick, "覆盤：重算和正式模擬同一個結果")
	# 跳轉一致：從頭播到結束 vs 播到一半跳回第 60 tick 再播到結束
	var g = GS.new()
	g.sfx = FakeSfx.new()
	g.mode = g.Mode.VS_AI
	g.last_armies = [a0.copy(), a1.copy()]
	g._begin_battle(a0.copy(), a1.copy(), "replay")
	var straight := {}
	while not g.view.finished:
		g._sim_step(false)
		if g.view.tick == 60 or g.view.tick == 120:
			straight[g.view.tick] = _view_sig(g.view)
	var end_sig := _view_sig(g.view)
	var end_counts := JSON.stringify(g.ev_count)
	var end_marks := JSON.stringify(g.battle_marks.filter(func(m): return m["kind"] != "clutch"))
	g._begin_battle(a0.copy(), a1.copy(), "replay")
	for k in 150:
		g._sim_step(false)
	g._seek(60)
	ok(g.view.tick == 60 and straight.has(60) and _view_sig(g.view) == straight[60], "重播跳轉：畫面剛好停在第 60 tick，狀態和從頭播一樣", "tick=%d" % g.view.tick)
	var seek_ok := true
	while not g.view.finished:
		g._sim_step(false)
		if straight.has(g.view.tick) and straight[g.view.tick] != _view_sig(g.view):
			seek_ok = false
	ok(seek_ok and _view_sig(g.view) == end_sig and JSON.stringify(g.ev_count) == end_counts, "重播跳轉：跳回第 60 tick 再播，畫面狀態、結局、戰報次數都和從頭播一樣")
	ok(JSON.stringify(g.battle_marks.filter(func(m): return m["kind"] != "clutch")) == end_marks, "重播跳轉：時間軸標記（首次衝鋒等）也和從頭播一樣")
	# 跳到後段：跳過的標記要重建出來
	g._seek(int(g.replay_total) - 5)
	while not g.view.finished:
		g._sim_step(false)
	ok(JSON.stringify(g.battle_marks.filter(func(m): return m["kind"] != "clutch")) == end_marks, "重播跳轉：直接跳到結尾附近，前面的標記也會重建")
	# 看對戰代碼：當成新的一局（Codex S5 #2）
	g.wins = [1, 1]
	g.round_no = 3
	g.armies = []
	g.watch_code(a0, a1)
	ok(g.watch_mode and g.wins == [0, 0] and g.round_no == 1 and g.armies.size() == 2 and g.play_kind == "replay", "看對戰代碼：比分、局數、陣型都重新初始化")
	# 覆盤換兵買不起：保留原兵（Codex S5 #3）
	g.last_armies = [army_from(0, [[D.SWORD, 5, 4]]), a1.copy()]
	g.last_armies[0].budget = 6
	g._open_review()
	g.rv_sel = Vector2i(5, 4)
	g._rv_set_type(D.CAVALRY)
	ok(g.rv_army.units.size() == 1 and int(g.rv_army.units[0]["type"]) == D.SWORD, "覆盤：換成買不起的兵種時保留原兵")
	g.free()

static func _pad64(b: String) -> String:
	var x := b.replace("-", "+").replace("_", "/")
	while x.length() % 4 != 0:
		x += "="
	return x

static func _view_sig(v) -> String:
	var parts: Array = [v.tick]
	for u in v.units:
		parts.append([u.id, u.x, u.y, u.hp, u.alive])
	return JSON.stringify(parts)


## 困難 AI 反制庫（第三輪 A3）：版本要和現在的規則一致；版本不符就不用；每筆反制陣都合法。
func test_counter_lib() -> void:
	var GS = load("res://scripts/ui/game_screens.gd")
	var raw = JSON.parse_string(FileAccess.get_file_as_string("res://data/counter_lib.json"))
	var entries: Array = GS.counter_lib_entries(raw)
	ok(entries.size() >= 12, "反制庫：版本和目前規則一致、至少 12 筆（%d）" % entries.size())
	var old: Dictionary = raw.duplicate(true)
	old["digest"] = "0000000000000000"
	ok(GS.counter_lib_entries(old).is_empty() and GS.counter_lib_entries([{"code": "x"}]).is_empty(), "反制庫：數值摘要不同或舊格式就不用（退回啟發式）")
	var bad := 0
	for e in entries:
		var a := Army.new(1, 100)
		if a.load_code(str(e["code"])) != "" or a.spent() > 100:
			bad += 1
	ok(bad == 0, "反制庫：每一筆反制陣都合法（%d 筆不合法）" % bad)


## 重播跳轉與最後時刻（Codex S7 #2）：最後時刻是否已發生要依目標時間重算，不靠先前的播放紀錄。
## 找一場會觸發最後時刻的戰鬥，從頭播一次記下標記；再「跳到觸發後 → 跳回觸發前 → 再跳到觸發後」播完，標記（含最後時刻）要一樣。
func test_seek_clutch() -> void:
	var GS = load("res://scripts/ui/game_screens.gd")
	var BVs = load("res://scripts/ui/battle_view.gd")
	var g = JSON.parse_string(FileAccess.get_file_as_string("res://tests/golden/golden.json"))
	var pick := -1
	var ct := -1
	for i in 60:
		var c: Dictionary = g["cases"][i]
		var a0 := Army.new(0, 100); a0.load_code(c["a"])
		var a1 := Army.new(1, 100); a1.load_code(c["b"])
		var sm = Sim.new(a0, a1)
		sm.fast = true
		while not sm.finished:
			sm.step()
			if not sm.finished and BVs.clutch_cond(sm):
				ct = sm.tick
				break
		if ct > 40:
			pick = i
			break
		ct = -1
	if pick < 0:
		ok(false, "重播跳轉＋最後時刻：找不到會觸發最後時刻的測試場")
		return
	var c2: Dictionary = g["cases"][pick]
	var b0 := Army.new(0, 100); b0.load_code(c2["a"])
	var b1 := Army.new(1, 100); b1.load_code(c2["b"])
	var gg = GS.new()
	gg.sfx = FakeSfx.new()
	gg.mode = gg.Mode.VS_AI
	gg.last_armies = [b0.copy(), b1.copy()]
	gg._begin_battle(b0.copy(), b1.copy(), "replay")
	while not gg.view.finished:
		gg._sim_step(false)
	var want := JSON.stringify(gg.battle_marks)
	var want_ct: int = gg.clutch_tick
	gg._seek(ct + 20)
	gg._seek(maxi(0, ct - 20))
	var before_ok: bool = not gg.slow_used and gg.clutch_tick == -1
	gg._seek(ct + 20)
	while not gg.view.finished:
		gg._sim_step(false)
	ok(want_ct == ct and before_ok and gg.clutch_tick == want_ct and JSON.stringify(gg.battle_marks) == want,
		"重播跳轉：最後時刻在觸發點前後來回跳，狀態與標記都和從頭播一樣（觸發於 %d tick）" % ct, "%s vs %s" % [want, JSON.stringify(gg.battle_marks)])
	gg.free()


## 最後時刻的演出副作用（Codex S8 #2、#3）：直接看結果／跳轉補播不放慢動作、不播音效；
## 正常播放時同一幀觸發慢動作後，剩下的累積不再用原速消耗。
func test_clutch_effects() -> void:
	var GS = load("res://scripts/ui/game_screens.gd")
	var BVs = load("res://scripts/ui/battle_view.gd")
	var g = JSON.parse_string(FileAccess.get_file_as_string("res://tests/golden/golden.json"))
	var pick := -1
	for i in 60:
		var c: Dictionary = g["cases"][i]
		var a0 := Army.new(0, 100); a0.load_code(c["a"])
		var a1 := Army.new(1, 100); a1.load_code(c["b"])
		var sm = Sim.new(a0, a1)
		sm.fast = true
		var hit := false
		while not sm.finished:
			sm.step()
			if not sm.finished and BVs.clutch_cond(sm):
				hit = sm.tick > 40
				break
		if hit:
			pick = i
			break
	if pick < 0:
		ok(false, "最後時刻演出：找不到測試場")
		return
	var c2: Dictionary = g["cases"][pick]
	var b0 := Army.new(0, 100); b0.load_code(c2["a"])
	var b1 := Army.new(1, 100); b1.load_code(c2["b"])
	var gg = GS.new()
	var fs := FakeSfx.new()
	gg.sfx = fs
	gg.mode = gg.Mode.VS_AI
	gg._begin_battle(b0.copy(), b1.copy(), "replay")
	gg._on_skip()
	ok(gg.slow_used and gg.slow_left == 0.0 and not fs.played.has("clutch"), "直接看結果：最後時刻只記標記，不放慢動作、不播音效")
	# 正常播放：一次給很大的時間（一幀多個 tick），觸發慢動作的那一 tick 之後要停下來
	gg._begin_battle(b0.copy(), b1.copy(), "replay")
	var steps_before := -1
	var guard := 0
	while not gg.slow_used and guard < 400:
		guard += 1
		var t0: int = gg.view.tick
		gg._battle_process(0.5)   # 一幀 10 tick
		if gg.slow_used:
			steps_before = gg.view.tick - t0
	ok(gg.slow_used and gg.view.tick == gg.clutch_tick and gg.accum > 0.0, "同一幀觸發慢動作：停在觸發那一 tick，剩下的時間留給慢速（多走了 %d tick）" % (gg.view.tick - gg.clutch_tick))
	gg.free()


## ───────── 第四輪：五種新兵（方案 v4 §3.3，每條都有「改壞會紅」的證明，紀錄在 coordination/n1-units/） ─────────
## 直接擺位置的小場景：spec＝[兵種, 隊, x, y]（絕對座標，1000＝1 格）。
func sim_at(spec: Array):
	var a0 = Army.new(0, 400)
	var a1 = Army.new(1, 400)
	for k in spec.size():
		var e: Array = spec[k]
		var a = a0 if e[1] == 0 else a1
		# 先放到不重複的格子，建好之後再搬到指定座標
		a.units.append({"type": e[0], "col": (k % 6) if e[1] == 0 else 15 - (k % 6), "row": k / 6})
	var s = Sim.new(a0, a1)
	var by_team := [0, 0]
	for e in spec:
		pass
	# Sim 依 id 排序；依「隊、列、欄」對回 spec 的順序
	var order: Array = []
	for k in spec.size():
		var e: Array = spec[k]
		var col: int = (k % 6) if e[1] == 0 else 15 - (k % 6)
		var id: int = e[1] * 1000 + (k / 6) * 16 + col
		for i in s.units.size():
			if s.units[i].id == id:
				order.append(i)
				s.units[i].x = e[2]
				s.units[i].y = e[3]
				s.units[i].fx = 1000 if e[1] == 0 else -1000
	return {"s": s, "idx": order}

func count_kind(s, kind: String, ticks: int, src := -1) -> Array:
	var out: Array = []
	for i in ticks:
		if s.finished:
			break
		s.step()
		for ev in s.events:
			if ev.get("kind") == kind and (src == -1 or ev.get("src") == src):
				out.append(ev)
	return out

func test_new_units() -> void:
	# ── 長槍兵 ──
	# 第二排出手：盾兵前排＋長槍兵第二排對上劍士衝陣，長槍兵出手時「有自家前排比它更靠近目標」的比例 ≥80%
	var spec := []
	for r in [3, 4, 5]:
		spec.append([D.SHIELD, 0, 5 * 1000 + 500, r * 1000 + 500])
		spec.append([D.PIKE, 0, 4 * 1000 + 500, r * 1000 + 500])
	for r in [3, 4, 5]:   # 同寬正面衝陣（敵方較寬時會從兩翼包抄直接打長槍兵，那是正常戰況，不算在這條）
		spec.append([D.SWORD, 1, 10 * 1000 + 500, r * 1000 + 500])
	var sc = sim_at(spec)
	var s = sc["s"]
	var pk_hits := 0
	var pk_second := 0
	for i in 600:
		if s.finished:
			break
		s.step()
		for ev in s.events:
			if ev.get("dmg") == null:
				continue
			var a = s.unit_by_id(ev["src"])
			if a.type != D.PIKE:
				continue
			var tg = s.unit_by_id(ev["tgt"])
			pk_hits += 1
			var dp: int = (a.x - tg.x) * (a.x - tg.x) + (a.y - tg.y) * (a.y - tg.y)
			for o in s.units:
				if o.team == a.team and o.alive and o.type != D.PIKE and (o.x - tg.x) * (o.x - tg.x) + (o.y - tg.y) * (o.y - tg.y) < dp:
					pk_second += 1
					break
	ok(pk_hits > 0 and pk_second * 100 >= pk_hits * 80, "長槍兵站第二排出手（有自家前排更靠近目標的出手 ≥80%）", "%d/%d" % [pk_second, pk_hits])
	# 拒騎：騎兵正面衝長槍兵 → pike_brace、傷害＝騎兵原攻擊（沒有衝鋒倍率）、沒有擊退、衝鋒被消耗
	sc = sim_at([[D.CAVALRY, 0, 1500, 4500], [D.PIKE, 1, 9500, 4500]])
	s = sc["s"]
	var pk = s.units[sc["idx"][1]]
	var cav = s.units[sc["idx"][0]]
	var braces: Array = []
	var knocked := false
	var cav_charge_after := -1
	for i in 200:
		var bx: int = pk.x
		s.step()
		for ev in s.events:
			if ev.get("kind") == EVS.PIKE_BRACE:
				braces.append(ev)
				knocked = absi(pk.x - bx) > 300
				cav_charge_after = cav.charge
		if not braces.is_empty():
			break
	ok(braces.size() == 1 and braces[0]["dmg"] == D.STATS[D.CAVALRY]["atk"] and not knocked and cav_charge_after == 0,
		"長槍兵拒騎：正面衝鋒沒有倍率、沒有擊退、衝鋒被消耗", "%s knocked=%s charge=%d" % [braces, knocked, cav_charge_after])
	# 被破陣的長槍兵擋不住衝鋒
	sc = sim_at([[D.CAVALRY, 0, 1500, 4500], [D.PIKE, 1, 9500, 4500]])
	s = sc["s"]
	s.units[sc["idx"][1]].breach = 5000
	ok(count_kind(s, EVS.CHARGE, 200).size() >= 1, "長槍兵被破陣時，騎兵衝鋒照常")
	# 長槍兵打騎兵 ×3/2
	sc = sim_at([[D.PIKE, 0, 6000, 4500], [D.CAVALRY, 1, 7000, 4500]])
	s = sc["s"]
	var pa := count_kind(s, EVS.ANTICAV, 100, s.units[sc["idx"][0]].id)
	ok(not pa.is_empty() and pa[0]["dmg"] == D.STATS[D.PIKE]["atk"] * D.PIKE_ANTICAV_NUM / D.PIKE_ANTICAV_DEN, "長槍兵打騎兵 ×3/2", str(pa.slice(0, 1)))

	# ── 投彈兵 ──
	# 被貼身（1.5 格內有可見敵人）：改敲人，攻 BONK_ATK，沒有爆炸
	sc = sim_at([[D.BOMBER, 0, 3000, 4500], [D.SWORD, 1, 4000, 4500], [D.SWORD, 1, 4300, 3800]])
	s = sc["s"]
	var bonks: Array = []
	var bombs := 0
	for i in 80:
		s.step()
		for ev in s.events:
			if ev.get("kind") == EVS.BONK:
				bonks.append(ev)
			elif ev.get("kind") == EVS.BOMB or ev.get("kind") == EVS.SPLASH:
				bombs += 1
	ok(not bonks.is_empty() and bonks[0]["dmg"] == D.BONK_ATK and bombs == 0, "投彈兵被貼身改敲人、沒有爆炸", "bonks=%d bombs=%d" % [bonks.size(), bombs])
	# 丟彈：盾牆正面，主擊無視舉盾（全額）、每次最多波及 SPLASH_MAX 隻
	spec = [[D.BOMBER, 0, 2500, 4500]]
	for p in [[6500, 4500], [6500, 3900], [6500, 5100], [6900, 4500], [6100, 4500], [7000, 4000]]:
		spec.append([D.SHIELD, 1, p[0], p[1]])
	sc = sim_at(spec)
	s = sc["s"]
	var bomb_ev: Array = []
	var splash_per_tick := []
	for i in 60:
		s.step()
		var sp := 0
		for ev in s.events:
			if ev.get("kind") == EVS.BOMB:
				bomb_ev.append(ev)
			elif ev.get("kind") == EVS.SPLASH:
				sp += 1
				if ev["dmg"] != D.SPLASH_DMG * D.BOMB_SHIELD_NUM / D.BOMB_SHIELD_DEN and ev["dmg"] != D.SPLASH_DMG * D.BOMB_SHIELD_NUM / D.BOMB_SHIELD_DEN * D.BREACH_VULN_NUM / D.BREACH_VULN_DEN:   # 目標都是盾兵：打盾 ×BOMB_SHIELD
					sp += 100
		if sp > 0:
			splash_per_tick.append(sp)
	ok(not bomb_ev.is_empty() and bomb_ev[0]["dmg"] == D.STATS[D.BOMBER]["atk"] * D.BOMB_SHIELD_NUM / D.BOMB_SHIELD_DEN and not splash_per_tick.is_empty() and splash_per_tick.max() == D.SPLASH_MAX,
		"投彈兵：打盾兵主擊無視舉盾且 ×%d/%d、每次波及恰好最多 %d 隻、波及傷害固定" % [D.BOMB_SHIELD_NUM, D.BOMB_SHIELD_DEN, D.SPLASH_MAX], "bomb=%s splash=%s" % [bomb_ev.slice(0, 1), splash_per_tick])
	# 潛行中的刺客貼在旁邊不會讓投彈兵改敲人（看不見）
	sc = sim_at([[D.BOMBER, 0, 3000, 4500], [D.ASSASSIN, 1, 3900, 4500], [D.SWORD, 1, 7000, 4500]])
	s = sc["s"]
	var early_bomb := false
	for i in 30:
		s.step()
		for ev in s.events:
			if ev.get("kind") == EVS.BOMB:
				early_bomb = true
	var bm := 0
	for u in s.units:
		if u.type == D.BOMBER:
			bm = u.bmode
	ok(early_bomb, "潛行刺客不會讓投彈兵改敲人（只看可見敵人）", "bmode=%d" % bm)

	# ── 醫者 ──
	# 補血對象：3 格內沒滿血、血比例最低、不是自己；補 HEAL_AMT
	sc = sim_at([[D.MEDIC, 0, 2000, 4500], [D.SWORD, 0, 3000, 4500], [D.SWORD, 0, 3000, 3500], [D.SHIELD, 1, 15000, 8000]])
	s = sc["s"]
	var sw1 = s.units[sc["idx"][1]]
	var sw2 = s.units[sc["idx"][2]]
	var med = s.units[sc["idx"][0]]
	sw1.hp = 150
	sw2.hp = 100
	med.hp = 50
	var heals := count_kind(s, EVS.HEAL, 30)
	ok(not heals.is_empty() and heals[0]["tgt"] == sw2.id and heals[0]["amt"] == D.HEAL_AMT, "醫者補血比例最低的友軍、不補自己、量＝HEAL_AMT", str(heals.slice(0, 1)))
	# 不疊加：兩個醫者同時選中同一隻，只吃一筆；兩個醫者的冷卻都消耗
	sc = sim_at([[D.MEDIC, 0, 2000, 4500], [D.MEDIC, 0, 2000, 5500], [D.SWORD, 0, 3000, 5000], [D.SHIELD, 1, 15000, 8000]])
	s = sc["s"]
	var swd = s.units[sc["idx"][2]]
	swd.hp = 100
	var hp_before := 0
	var gain := -1
	var both_cd := false
	for i in 30:
		hp_before = swd.hp
		s.step()
		var hs := 0
		for ev in s.events:
			if ev.get("kind") == EVS.HEAL:
				hs += 1
		if hs > 0:
			gain = swd.hp - hp_before
			both_cd = s.units[sc["idx"][0]].hcd == D.HEAL_CD and s.units[sc["idx"][1]].hcd == D.HEAL_CD
			break
	ok(gain == D.HEAL_AMT and both_cd, "兩個醫者補同一隻不疊加（只補一筆、兩個冷卻都消耗）", "gain=%d cd=%s" % [gain, both_cd])
	# 當 tick 已經死的不救；補血不超過滿血（直接呼叫 ⑤ 的補血結算）
	sc = sim_at([[D.MEDIC, 0, 2000, 4500], [D.SWORD, 0, 3000, 4500], [D.SWORD, 0, 3000, 3500], [D.SHIELD, 1, 15000, 8000]])
	s = sc["s"]
	var dead_sw = s.units[sc["idx"][1]]
	var near_full = s.units[sc["idx"][2]]
	dead_sw.hp = -3
	near_full.hp = near_full.max_hp - 5
	s._apply_heals([[sc["idx"][0], sc["idx"][1], 18, 0, 0, 0, 0], [sc["idx"][0], sc["idx"][2], 18, 0, 0, 0, 0]])
	ok(dead_sw.hp == -3 and near_full.hp == near_full.max_hp and s.units[sc["idx"][0]].heal_done == 5, "當 tick 該死的不會被補回；補血不超過滿血、記實際補量", "dead=%d full=%d done=%d" % [dead_sw.hp, near_full.hp, s.units[sc["idx"][0]].heal_done])
	# 補血時間：第一次在第 HEAL_FIRST tick，之後每 HEAL_CD tick 一次（Codex 實作審查 #4：原本每次多等 1 tick）
	sc = sim_at([[D.MEDIC, 0, 2000, 4500], [D.SWORD, 0, 3000, 4500], [D.SHIELD, 1, 15000, 8000]])
	s = sc["s"]
	s.units[sc["idx"][1]].hp = 20
	var heal_ticks: Array = []
	for i in D.HEAL_FIRST + D.HEAL_CD * 2 + 2:
		s.step()
		for ev in s.events:
			if ev.get("kind") == EVS.HEAL:
				heal_ticks.append(s.tick)
	ok(heal_ticks.size() >= 3 and heal_ticks[0] == D.HEAL_FIRST and heal_ticks[1] - heal_ticks[0] == D.HEAL_CD and heal_ticks[2] - heal_ticks[1] == D.HEAL_CD,
		"補血時間：第一次在第 %d tick、之後每 %d tick" % [D.HEAL_FIRST, D.HEAL_CD], str(heal_ticks))
	# 被暈的醫者這一刻不補（冷卻已到 0，解暈後下一 tick 立刻補）；鼓手不會加快補血
	sc = sim_at([[D.MEDIC, 0, 2000, 4500], [D.SWORD, 0, 3000, 4500], [D.DRUMMER, 0, 2200, 4600], [D.SHIELD, 1, 15000, 8000]])
	s = sc["s"]
	s.units[sc["idx"][1]].hp = 20
	s.units[sc["idx"][0]].stun = D.HEAL_FIRST + 5
	var ht2: Array = []
	for i in D.HEAL_FIRST + D.HEAL_CD + 10:
		s.step()
		for ev in s.events:
			if ev.get("kind") == EVS.HEAL:
				ht2.append(s.tick)
	ok(ht2.size() >= 2 and ht2[0] == D.HEAL_FIRST + 6 and ht2[1] - ht2[0] == D.HEAL_CD and s.units[sc["idx"][0]].aura == 1,
		"被暈的醫者延後補血、解暈後立刻補；鼓手光環不加快補血", str(ht2))
	# 狂熱時補血減半
	sc = sim_at([[D.MEDIC, 0, 2000, 4500], [D.SWORD, 0, 3000, 4500], [D.SHIELD, 1, 15000, 8000]])
	s = sc["s"]
	s.units[sc["idx"][1]].hp = 100
	s.tick = D.FRENZY_TICK + 1
	heals = count_kind(s, EVS.HEAL, 30)
	ok(not heals.is_empty() and heals[0]["amt"] == D.HEAL_AMT / 2, "狂熱時補血減半", str(heals.slice(0, 1)))
	# 沒有可補的對象時不消耗冷卻（冷卻停在 0，等有人受傷就立刻補）
	sc = sim_at([[D.MEDIC, 0, 2000, 4500], [D.SWORD, 0, 3000, 4500], [D.SHIELD, 1, 15000, 8000]])
	s = sc["s"]
	for i in 40:
		s.step()
	var hcd0: int = s.units[sc["idx"][0]].hcd
	s.units[sc["idx"][1]].hp = 100
	heals = count_kind(s, EVS.HEAL, 1)
	ok(hcd0 == 0 and heals.size() == 1, "沒有可補對象時補血冷卻不消耗、有人受傷下一 tick 就補", "hcd=%d heals=%d" % [hcd0, heals.size()])
	# 可以補潛行中的友軍刺客
	sc = sim_at([[D.MEDIC, 0, 2000, 4500], [D.ASSASSIN, 0, 2500, 4500], [D.SHIELD, 1, 15000, 8000]])
	s = sc["s"]
	s.units[sc["idx"][1]].hp = 100
	heals = count_kind(s, EVS.HEAL, 30)
	ok(not heals.is_empty() and heals[0]["tgt"] == s.units[sc["idx"][1]].id and s.units[sc["idx"][1]].stealth > 0, "醫者可以補潛行中的友軍刺客")
	# 支援兵在隊上還有戰鬥兵時不攻擊；只剩支援兵時才自己打
	sc = sim_at([[D.MEDIC, 0, 6000, 4500], [D.DRUMMER, 0, 6000, 5500], [D.SWORD, 0, 1000, 500], [D.SWORD, 1, 6700, 4500]])
	s = sc["s"]
	var sup_ids := [s.units[sc["idx"][0]].id, s.units[sc["idx"][1]].id]
	var sup_hits := 0
	for i in 60:
		s.step()
		for ev in s.events:
			if ev.get("dmg") != null and ev.get("src") in sup_ids:
				sup_hits += 1
	s.units[sc["idx"][2]].alive = false
	s.units[sc["idx"][2]].hp = 0
	var sup_hits2 := 0
	for i in 80:
		if s.finished:
			break
		s.step()
		for ev in s.events:
			if ev.get("dmg") != null and ev.get("src") in sup_ids:
				sup_hits2 += 1
	ok(sup_hits == 0 and sup_hits2 > 0, "支援兵：有戰鬥兵友軍時不攻擊、只剩支援兵時才打", "%d / %d" % [sup_hits, sup_hits2])

	# ── 鼓手 ──
	# 光環內的友軍冷卻多扣 1；光環外照常；兩個鼓手不疊加；被暈的鼓手不打鼓
	sc = sim_at([[D.DRUMMER, 0, 2000, 4500], [D.DRUMMER, 0, 2000, 5000], [D.SWORD, 0, 3000, 4500], [D.SWORD, 0, 1000, 500], [D.SHIELD, 1, 15000, 8000]])
	s = sc["s"]
	var near_sw = s.units[sc["idx"][2]]
	var far_sw = s.units[sc["idx"][3]]
	near_sw.cd = 400
	far_sw.cd = 400
	s.step()
	var dn: int = 400 - near_sw.cd
	var df: int = 400 - far_sw.cd
	ok(dn == 4 + D.DRUM_BONUS and df == 4 and near_sw.aura == 1 and far_sw.aura == 0, "鼓手光環：範圍內冷卻每 tick 多扣 DRUM_BONUS、兩個鼓手不疊加、範圍外照常", "near=%d far=%d" % [dn, df])
	s.units[sc["idx"][0]].stun = 50
	s.units[sc["idx"][1]].stun = 50
	near_sw.cd = 400
	s.step()
	ok(400 - near_sw.cd == 4, "被暈的鼓手不打鼓", "dec=%d" % (400 - near_sw.cd))
	# 冷卻扣除上限：狂熱 5＋背水 2＋戰鼓 1 → 封頂 DEC_CAP
	sc = sim_at([[D.DRUMMER, 0, 2000, 4500], [D.SWORD, 0, 2500, 4500], [D.SHIELD, 1, 15000, 8000], [D.SHIELD, 1, 15000, 7000], [D.SHIELD, 1, 15000, 6000], [D.SHIELD, 1, 15000, 5000]])
	s = sc["s"]
	s.tick = D.FRENZY_TICK + 3
	var sw3 = s.units[sc["idx"][1]]
	sw3.cd = 400
	s.step()
	ok(s.rally[0] and 400 - sw3.cd == D.DEC_CAP, "冷卻扣除上限：狂熱＋背水＋戰鼓封頂 %d" % D.DEC_CAP, "rally=%s dec=%d" % [s.rally, 400 - sw3.cd])

	# ── 狂戰士 ──
	# 打中盾兵 → 破陣 BREACH_TICKS；破陣中弓箭打盾兵正面不再被擋、不再嘲諷近戰
	sc = sim_at([[D.BERSERKER, 0, 6000, 4500], [D.ARCHER, 0, 2000, 4500], [D.SHIELD, 1, 6700, 4500]])
	s = sc["s"]
	var shd = s.units[sc["idx"][2]]
	var got_breach: Array = []
	var breach_val := -1
	for i in 60:
		s.step()
		for ev in s.events:
			if ev.get("kind") == EVS.BREACH:
				got_breach.append(ev)
		if not got_breach.is_empty():
			breach_val = shd.breach
			break
	var arrows_after: Array = []
	var blocked_after := 0
	for i in 40:
		if s.finished:
			break
		s.step()
		for ev in s.events:
			if ev.get("kind") == EVS.BLOCKED:
				blocked_after += 1
			elif ev.get("kind") == EVS.ARROW and ev.get("tgt") == shd.id:
				arrows_after.append(ev)
	ok(not got_breach.is_empty() and breach_val == D.BREACH_TICKS and blocked_after == 0 and not arrows_after.is_empty(),
		"狂戰士破陣：盾兵 %d tick 內舉盾失效（弓箭全額）" % D.BREACH_TICKS, "breach=%d blocked=%d arrows=%d" % [breach_val, blocked_after, arrows_after.size()])
	# 破陣擴散：目標 1 格內的其他敵方盾兵／長槍兵一起破陣，遠一點的不會
	sc = sim_at([[D.BERSERKER, 0, 6000, 4500], [D.SHIELD, 1, 6700, 4500], [D.PIKE, 1, 6800, 5300], [D.SHIELD, 1, 6700, 6800], [D.ARCHER, 1, 14000, 4500]])
	s = sc["s"]
	var spread_ok := false
	for i in 80:
		s.step()
		var fresh := false
		for ev in s.events:
			if ev.get("kind") == EVS.BREACH:
				fresh = true
		if fresh:
			spread_ok = s.units[sc["idx"][1]].breach == D.BREACH_TICKS and s.units[sc["idx"][2]].breach == D.BREACH_TICKS and s.units[sc["idx"][3]].breach == 0
			break
	ok(spread_ok, "破陣擴散：1 格內的盾兵／長槍兵一起破陣、遠的不會")
	# 剛被破陣的那一 tick 不增傷（用 ④ 當下的狀態），下一次才吃加成；投彈兵打破陣的盾兵：×BOMB_SHIELD 再 ×BREACH_VULN（Codex 第 3 輪 #5）
	sc = sim_at([[D.BERSERKER, 0, 6000, 4500], [D.SHIELD, 1, 6700, 4500], [D.ARCHER, 1, 14000, 4500]])
	s = sc["s"]
	var first_dmg := -1
	for i in 60:
		s.step()
		for ev in s.events:
			if ev.get("kind") == EVS.BREACH:
				first_dmg = int(ev["dmg"])
		if first_dmg >= 0:
			break
	ok(first_dmg == D.STATS[D.BERSERKER]["atk"], "剛被破陣的那一擊不增傷", "dmg=%d" % first_dmg)
	sc = sim_at([[D.BOMBER, 0, 2500, 4500], [D.SHIELD, 1, 6500, 4500], [D.SHIELD, 1, 6500, 3900]])
	s = sc["s"]
	s.units[sc["idx"][1]].breach = 5000
	s.units[sc["idx"][2]].breach = 5000
	var bb := count_kind(s, EVS.BOMB, 60)
	var want := D.STATS[D.BOMBER]["atk"] * D.BOMB_SHIELD_NUM / D.BOMB_SHIELD_DEN * D.BREACH_VULN_NUM / D.BREACH_VULN_DEN
	ok(not bb.is_empty() and bb[0]["dmg"] == want, "投彈兵打破陣的盾兵：打盾倍率再乘破陣增傷", "%s want=%d" % [bb.slice(0, 1), want])
	# 擴散半徑剛好在邊界上算（≤），超過 1 單位不算
	sc = sim_at([[D.BERSERKER, 0, 6000, 4500], [D.SHIELD, 1, 6700, 4500], [D.SHIELD, 1, 6700, 4500 + D.BREACH_SPREAD], [D.SHIELD, 1, 6700, 4500 - D.BREACH_SPREAD - 1], [D.ARCHER, 1, 14000, 4500]])
	s = sc["s"]
	for k in [1, 2, 3]:
		s.units[sc["idx"][k]].stun = 5000   # 盾兵站著不動，距離才準
	var edge_ok := false
	for i in 60:
		s.step()
		var fresh2 := false
		for ev in s.events:
			if ev.get("kind") == EVS.BREACH:
				fresh2 = true
		if fresh2:
			edge_ok = s.units[sc["idx"][2]].breach == D.BREACH_TICKS and s.units[sc["idx"][3]].breach == 0
			break
	ok(edge_ok, "破陣擴散：剛好 BREACH_SPREAD 算、多 1 不算")
	# 破陣中受到的傷害 ×BREACH_VULN：同一把劍打破陣的盾兵比較痛
	var dm := []
	for br in [0, 5000]:
		sc = sim_at([[D.SWORD, 0, 6000, 4500], [D.SHIELD, 1, 6650, 4500]])
		s = sc["s"]
		s.units[sc["idx"][1]].breach = br
		var hs := count_kind(s, EVS.BREAKER, 40, s.units[sc["idx"][0]].id)
		dm.append(int(hs[0]["dmg"]) if not hs.is_empty() else -1)
	ok(dm[0] > 0 and dm[1] == dm[0] * D.BREACH_VULN_NUM / D.BREACH_VULN_DEN, "破陣中受到的傷害 ×%d/%d" % [D.BREACH_VULN_NUM, D.BREACH_VULN_DEN], str(dm))
	# 破陣的盾兵不嘲諷：劍士選目標時不會被它吸走
	# 對照組：沒破陣時，2 格內的盾兵會把劍士吸走（即使弓箭手更近）
	sc = sim_at([[D.SWORD, 0, 6000, 4500], [D.SHIELD, 1, 7200, 3400], [D.ARCHER, 1, 6900, 4500]])
	s = sc["s"]
	s.step()
	var ctrl: int = s.units[sc["idx"][0]].target
	sc = sim_at([[D.SWORD, 0, 6000, 4500], [D.SHIELD, 1, 7200, 3400], [D.ARCHER, 1, 6900, 4500]])
	s = sc["s"]
	s.units[sc["idx"][1]].breach = 500
	s.step()
	ok(ctrl == sc["idx"][1] and s.units[sc["idx"][0]].target == sc["idx"][2], "破陣的盾兵不嘲諷近戰（對照：沒破陣時會被吸走）", "ctrl=%d target=%d" % [ctrl, s.units[sc["idx"][0]].target])
	# 不被擊退：同樣的衝鋒打劍士會被擊退、打狂戰士不會
	var disp := []
	for tt in [D.SWORD, D.BERSERKER]:
		sc = sim_at([[D.CAVALRY, 0, 1500, 4500], [tt, 1, 9500, 4500]])
		s = sc["s"]
		var v = s.units[sc["idx"][1]]
		var moved := -1
		for i in 200:
			var bx: int = v.x
			s.step()
			var hit := false
			for ev in s.events:
				if ev.get("kind") == EVS.CHARGE:
					hit = true
			if hit:
				moved = absi(v.x - bx)
				break
		disp.append(moved)
	ok(disp[0] >= 400 and disp[1] >= 0 and disp[1] < 300, "狂戰士不被衝鋒擊退（劍士會）", str(disp))
	# 沒穿甲：箭傷 ×5/4
	sc = sim_at([[D.ARCHER, 0, 2000, 4500], [D.BERSERKER, 1, 7000, 4500]])
	s = sc["s"]
	var ar := count_kind(s, EVS.ARROW, 60)
	ok(not ar.is_empty() and ar[0]["dmg"] == D.STATS[D.ARCHER]["atk"] * D.BERSERK_ARROW_NUM / D.BERSERK_ARROW_DEN, "狂戰士被箭射 ×5/4", str(ar.slice(0, 1)))

	# ── 共通：新兵種混編的鏡像與輸入順序 ──
	var rng := RandomNumberGenerator.new()
	var mbad := 0
	var obad := 0
	for i in 12:
		rng.seed = 4040 + i
		var a0: Army = F.random_formation(0, rng, "mixed", "", D.COUNT)
		var a1: Army = F.random_formation(1, rng, "mixed", "", D.COUNT)
		if MC.check(a0, a1) != "":
			mbad += 1
		var r0: Army = a0.copy()
		r0.units.reverse()
		var r1: Army = a1.copy()
		r1.units.shuffle()
		var p = Sim.new(a0.copy(), a1.copy())
		p.run_to_end()
		var q = Sim.new(r0, r1)
		q.run_to_end()
		if p.fingerprint != q.fingerprint:
			obad += 1
	ok(mbad == 0 and obad == 0, "十種兵混編：左右鏡像逐 tick 一致、陣型清單順序打亂結果不變（12 組）", "mirror=%d order=%d" % [mbad, obad])


## 第四輪：兵種開放、結果頁兵種長條與技能徽章、存檔相容
func test_roster_ui() -> void:
	var RS = load("res://scripts/game/roster.gd")
	var GS = load("res://scripts/ui/game_screens.gd")
	var bad: Array = []
	if RS.unlocked_count(0) != 5 or RS.unlocked_count(2) != 5 or RS.unlocked_count(3) != 6 or RS.unlocked_count(11) != 10 or RS.unlocked_count(99) != 10:
		bad.append("解鎖場數")
	if RS.unlocked_count(99, true) != 7:
		bad.append("試玩版上限")
	if RS.ntypes_for("duel", 0, false) != 10 or RS.ntypes_for("duel", 0, true) != 5 or RS.ntypes_for("ai", 4, false) != 6 or RS.ntypes_for("ai", 99, true) != 5:
		bad.append("模式開放數")
	if RS.games_to_unlock(D.MEDIC, 6) != 1 or RS.games_to_unlock(D.SWORD, 0) != 0 or RS.games_to_unlock(D.BERSERKER, 99, true) != -1:
		bad.append("還要幾場")
	if RS.newly_unlocked(2, 3) != [D.PIKE] or not RS.newly_unlocked(3, 4).is_empty():
		bad.append("新解鎖提示")
	# AI 只用開放的兵種：經典 5 種時，所有模板與落子 AI 都不會拿出新兵
	var rng := RandomNumberGenerator.new()
	for i in 40:
		rng.seed = 900 + i
		var a = AI.build(1, 100, rng, -1, 31)["army"]
		var b = load("res://scripts/core/ai_turns.gd").build_full(1, rng, i % 3, [], 31)
		for u in a.units + b.units:
			if int(u["type"]) >= 5:
				bad.append("經典模式 AI 用了兵種 %d" % u["type"])
				break
	# 指定模板也不能繞過開放數（Codex 實作審查 #3）
	for ti in AI.TEMPLATES.size():
		rng.seed = 77 + ti
		var c = AI.build(1, 100, rng, ti, 31)["army"]
		for u in c.units:
			if int(u["type"]) >= 5:
				bad.append("指定模板 %d 用了兵種 %d" % [ti, u["type"]])
				break
	ok(bad.is_empty(), "兵種開放：場數解鎖、試玩版上限、經典模式、AI（含指定模板）不用未開放的兵種", str(bad))
	# 結果頁兵種長條：只列出場的、合計最多的 5 種
	var dealt := [D.zeros(), D.zeros()]
	var taken := [D.zeros(), D.zeros()]
	for t in [0, 2, 5, 6, 7, 9]:
		dealt[0][t] = 10 + t
	taken[1][3] = 1
	var rows: Array = GS.report_rows(dealt, taken)
	ok(rows == [9, 7, 6, 5, 2], "結果頁兵種長條：出場的兵種依合計排序、最多 5 種", str(rows))
	var cnt := {"heal0": 9, "breach1": 3, "charge0": 1}
	var bg: Array = GS.report_badges(cnt)
	ok(bg.size() == 6 and bg[0] == "heal" and bg[1] == "breach" and bg[2] == "charge" and bg.has("breaker"), "結果頁技能徽章：有發生的依次數排前面，支援兵的補血也算", str(bg))


# ═══════════════════ 第五輪：自訂規則 ═══════════════════
const RSET = preload("res://scripts/core/ruleset.gd")
const AIT5 = preload("res://scripts/core/ai_turns.gd")
const HA5 = preload("res://scripts/core/hard_ai.gd")

## 獨立的陣型合法性判定（不呼叫 Army.check_place，避免用被測的程式驗自己）。
static func legal_army(a, r, team: int) -> String:
	var seen := {}
	var spent := 0
	var per := {}
	for u in a.units:
		var t := int(u["type"])
		var c := int(u["col"])
		var row := int(u["row"])
		var lc := c if team == 0 else 15 - c
		if lc < 0 or lc > 5 or row < 0 or row > 8:
			return "出界"
		if seen.has(Vector2i(c, row)):
			return "重複格"
		seen[Vector2i(c, row)] = true
		if (r.pool_of(team) >> t) & 1 == 0:
			return "不在卡池 %d" % t
		per[t] = int(per.get(t, 0)) + 1
		if r.type_cap > 0 and per[t] > r.type_cap:
			return "超過單種上限"
		spent += D.cost(t)
	if spent > r.budget_of(team):
		return "超過預算"
	if a.units.size() > r.unit_cap:
		return "超過人數"
	return ""

func test_rules_v5() -> void:
	# 標準規則：模擬走舊路徑
	var std = RSET.standard()
	ok(std.validate().is_empty() and std.sim_is_legacy() and std.judge() == 1, "標準規則合法、走 1.3.0 舊路徑", str(std.validate()))
	ok(std.frenzy_tick() == 1200 and std.attrition_step() == 100 and std.turn_cap(0) == 20, "標準規則的狂熱 1200／間隔 100／每手 20 金和 1.3.0 相同")
	# 狂熱時間表：四種時間都符合公式，6 次耗損都在一局之內
	var tbad: Array = []
	for T in RSET.TICK_CHOICES:
		var r = RSET.standard()
		r.ticks = T
		if r.frenzy_tick() != T * 2 / 3 or r.attrition_step() != T / 18 or r.frenzy_tick() + 5 * r.attrition_step() >= T:
			tbad.append(T)
	ok(tbad.is_empty(), "狂熱時間表：起點 T×2÷3、間隔 T÷18，6 次耗損都在時間內", str(tbad))
	# 規則代碼來回
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	var cbad: Array = []
	var made := 0
	for i in 300:
		var r = RSET.standard()
		r.budget = [rng.randi_range(3, 20) * 10, rng.randi_range(3, 20) * 10]
		r.handicap = rng.randf() < 0.4
		r.ticks = RSET.TICK_CHOICES[rng.randi_range(0, 3)]
		r.unit_cap = rng.randi_range(4, 40)
		r.type_cap = rng.randi_range(0, 10)
		r.pool = [rng.randi_range(1, 1023), rng.randi_range(1, 1023)]
		r.ai_pool_same = rng.randf() < 0.5
		r.rounds = RSET.ROUND_CHOICES[rng.randi_range(0, 3)]
		r.place_rule = RSET.PLACE_RULES[rng.randi_range(0, 3)]
		r.turns = rng.randi_range(1, 10)
		r.carry = rng.randf() < 0.5
		r.ai_level = rng.randi_range(0, 2)
		if not r.validate().is_empty():
			continue
		made += 1
		var d: Dictionary = RSET.from_code(r.to_code())
		if not d["ok"] or not d["rules"].equals(r):
			cbad.append([r.to_code(), d["why"]])
	ok(made > 50 and cbad.is_empty(), "規則代碼：%d 組合法規則來回相同" % made, str(cbad.slice(0, 2)))
	# 不合法匯入被拒
	var good: String = std.to_code()
	var parts := good.split(".")
	var rej := [RSET.from_code("NTBR9." + parts[1] + "." + parts[2]), RSET.from_code(parts[0] + "." + parts[1] + ".abcdef"),
		RSET.from_code(good + good), RSET.from_code("x".repeat(3000))]
	var r0 = RSET.standard()
	r0.pool = [0b1110000000 & 0b0110000000, 0b0110000000]   # 只有醫者＋鼓手
	rej.append(RSET.from_code(r0.to_code()))
	var r1 = RSET.standard()
	r1.budget = [20, 20]
	rej.append(RSET.from_code(r1.to_code()))
	var allrej := true
	for d in rej:
		allrej = allrej and not d["ok"]
	ok(allrej, "規則代碼：錯前綴、錯校驗、超長、只有支援兵、預算超出範圍都被拒")
	# 逐欄位改壞會紅
	var mut: Array = []
	for f in ["budget", "ticks", "unit_cap", "type_cap", "rounds", "place_rule", "turns", "ai_level"]:
		var r = RSET.standard()
		match f:
			"budget": r.budget = [10, 10]
			"ticks": r.ticks = 1234
			"unit_cap": r.unit_cap = 99
			"type_cap": r.type_cap = -1
			"rounds": r.rounds = 2
			"place_rule": r.place_rule = "x"
			"turns": r.turns = 0
			"ai_level": r.ai_level = 5
		if r.validate().is_empty():
			mut.append(f)
	ok(mut.is_empty(), "規則驗證：每個欄位改成非法值都會被擋", str(mut))
	# 讓子判定：預算相同時和舊判定一致；剛好 3% 的邊界
	var jbad: Array = []
	for i in 2000:
		var b := rng.randi_range(30, 200)
		var p0 := rng.randi_range(0, b * 1000)
		var p1 := rng.randi_range(0, b * 1000)
		if rng.randf() < 0.2:
			p1 = p0 + (b * 30 if rng.randf() < 0.5 else -b * 30) + rng.randi_range(-1, 1)
		var old := -1 if absi(p0 - p1) < b * 30 else (0 if p0 > p1 else 1)
		var dl := p0 * b - p1 * b
		var nw := -1 if 100 * absi(dl) < 3 * 1000 * b * b else (0 if dl > 0 else 1)
		if old != nw:
			jbad.append([b, p0, p1])
	ok(jbad.is_empty(), "讓子判定（整數交叉相乘）在兩邊預算相同時和舊判定完全一致，含剛好 3% 的邊界", str(jbad.slice(0, 3)))
	# 讓子：實際跑一場，鏡像（交換兩邊＋預算）結果對稱
	var hr = RSET.standard()
	hr.handicap = true
	hr.budget = [80, 140]
	var hb: Array = []
	for i in 6:
		rng.seed = 610 + i
		var a0 = AI.build(0, 80, rng)["army"]
		var a1 = AI.build(1, 140, rng)["army"]
		var s1 = Sim.new(a0.copy(), a1.copy(), hr)
		s1.fast = true
		s1.run_to_end()
		var hr2 = RSET.standard()
		hr2.handicap = true
		hr2.budget = [140, 80]
		var m0 = a1.mirrored()
		var m1 = a0.mirrored()
		var s2 = Sim.new(m0, m1, hr2)
		s2.fast = true
		s2.run_to_end()
		var w2: int = s2.winner if s2.winner < 0 else 1 - s2.winner
		if s1.judge != 2 or s1.winner != w2 or s1.tick != s2.tick:
			hb.append([i, s1.winner, s2.winner, s1.tick, s2.tick])
	ok(hb.is_empty(), "讓子：用比例判定（judge 2），交換兩邊＋預算後結果對稱", str(hb))
	# 非標準規則一定改指紋（規則進雜湊），標準規則物件和不給規則指紋相同
	rng.seed = 42
	var ba = AI.build(0, 100, rng)["army"]
	var bb = AI.build(1, 100, rng)["army"]
	var sa = Sim.new(ba.copy(), bb.copy())
	sa.run_to_end()
	var sb = Sim.new(ba.copy(), bb.copy(), RSET.standard())
	sb.run_to_end()
	var tr = RSET.standard()
	tr.ticks = 2400
	var sc = Sim.new(ba.copy(), bb.copy(), tr)
	sc.run_to_end()
	ok(sa.fingerprint == sb.fingerprint and sc.fingerprint != sa.fingerprint, "標準規則物件＝不給規則（指紋相同）；改一局時間會改指紋")
	# 短局：60 秒一定在 1200 tick 內結束，狂熱在 800 開始
	var sr = RSET.standard()
	sr.ticks = 1200
	var ss = Sim.new(ba.copy(), bb.copy(), sr)
	var fz := -1
	while not ss.finished:
		ss.step()
		if ss.frenzy and fz < 0:
			fz = ss.tick
	ok(ss.tick <= 1200 and (fz == 800 or ss.tick < 800), "60 秒局：最多 1200 tick、狂熱從 800 開始", "tick=%d frenzy=%d" % [ss.tick, fz])
	# 系列局數
	var sbad: Array = []
	for pair in [[1, 1, 1], [3, 2, 5], [5, 3, 7], [7, 4, 9]]:
		var r = RSET.standard()
		r.rounds = pair[0]
		if r.wins_needed() != pair[1] or r.max_rounds() != pair[2]:
			sbad.append(pair)
	ok(sbad.is_empty(), "系列：單局只打 1 局；三戰兩勝要 2 勝、最多 5 局（＝1.3.0）；五戰三勝 7 局；七戰四勝 9 局", str(sbad))
	# 卡池窮舉：1024 個遮罩
	var mbad: Array = []
	var rejected := 0
	for m in 1024:
		var r = RSET.standard(m)
		var v: Array = r.validate()
		var support_only: bool = m != 0 and (m & ~(0b0110000000)) == 0
		if m == 0 or support_only:
			if v.is_empty():
				mbad.append("遮罩 %d 應被拒" % m)
			else:
				rejected += 1
			continue
		if not v.is_empty():
			mbad.append("遮罩 %d 被誤拒 %s" % [m, v])
			continue
		rng.seed = 3000 + m
		var lv := m % 3
		var a
		if lv == 0:
			a = AIT5.build_full(1, rng, 0, [], m, r)
		elif lv == 1:
			a = AI.build(1, 100, rng, -1, m, r)["army"]
		else:
			a = HA5.build([], [], rng, m, r)
		var why := legal_army(a, r, 1)
		if why != "" or not a.has_combat() or a.can_afford_any():
			mbad.append("遮罩 %d：%s combat=%s 還買得起=%s" % [m, why, a.has_combat(), a.can_afford_any()])
	ok(rejected == 4 and mbad.is_empty(), "卡池窮舉 1024：0 與 3 個純支援遮罩被拒；其餘 1020 個 AI 都組得出合法、含戰鬥兵、花到買不起的陣", str(mbad.slice(0, 4)))
	# 預算／人數／單種上限邊界
	var ebad: Array = []
	for cfg in [[30, 4, 0], [30, 40, 1], [200, 40, 0], [200, 4, 1], [200, 40, 1], [50, 12, 2], [120, 24, 3]]:
		for m in [1023, 31, 0b1000010001, 0b0000010000, 0b0100001000]:
			var r = RSET.standard(m)
			r.budget = [cfg[0], cfg[0]]
			r.unit_cap = cfg[1]
			r.type_cap = cfg[2]
			if not r.validate().is_empty():
				continue
			rng.seed = cfg[0] * 7 + cfg[1] * 13 + m
			var a = AI.build(1, cfg[0], rng, -1, m, r)["army"]
			var why := legal_army(a, r, 1)
			if why != "" or not a.has_combat() or a.can_afford_any():
				ebad.append([cfg, m, why, a.can_afford_any()])
	ok(ebad.is_empty(), "邊界：金幣 30／200、人數 4／40、單種上限 1～3，AI 陣型都合法且花到買不起", str(ebad.slice(0, 3)))
	# 防卡死：沒有戰鬥兵時，玩家不能把錢或名額花到買不起戰鬥兵
	var gr = RSET.standard(0b0010000001)   # 劍士＋醫者
	gr.budget = [30, 30]
	var ga := Army.new(0, 30)
	ga.apply_rules(gr, 0)
	var g1 := ga.place(D.MEDIC, 0, 0)          # 6 金，剩 24
	var g2 := ga.place(D.MEDIC, 0, 1)          # 剩 18
	var g3 := ga.place(D.MEDIC, 0, 2)          # 剩 12
	var g4 := ga.place(D.MEDIC, 0, 3)          # 剩 6 ≥ 5（劍士）→ 可以
	var g5 := ga.place(D.MEDIC, 0, 4)          # 剩 0 < 5 → 要擋
	ok(g1 and g2 and g3 and g4 and not g5 and ga.place(D.SWORD, 1, 0), "防卡死：還沒擺戰鬥兵時，擺支援兵不能讓剩下的錢買不起戰鬥兵")
	# 自訂手數：輪序是 Thue‑Morse、每手上限依預算
	var tr2 = RSET.standard()
	tr2.place_rule = "custom"
	tr2.turns = 3
	tr2.budget = [60, 60]
	var ta := Army.new(0, 60)
	var tb := Army.new(1, 60)
	ta.apply_rules(tr2, 0)
	tb.apply_rules(tr2, 1)
	var tp = TP.new(ta, tb, 0, "snake5", tr2)
	var guard := 0
	while not tp.done() and guard < 50:
		guard += 1
		AIT5.play_turn(tp, rng, 1)
	var order: Array = []
	var last_turn := -1
	for c in tp.commands:
		if int(c["turn"]) != last_turn:
			last_turn = int(c["turn"])
			order.append(int(c["team"]))
	ok(tp.hand_cap() == 20 and order.slice(0, 6) == [0, 1, 1, 0, 1, 0] and tp.hands_done[0] <= 3 and tp.hands_done[1] <= 3,
		"自訂 3 手：輪序 A‑B‑B‑A‑B‑A、每手上限 ⌈60÷3⌉＝20、每人最多 3 手", str(order))
	# 30 金、cap10：每手上限至少等於卡池最貴兵價（不會出現 3 金一手買不起）
	var cr = RSET.standard()
	cr.place_rule = "cap10"
	cr.budget = [30, 30]
	ok(cr.turn_cap(0) >= 7 and cr.validate().is_empty(), "30 金 cap10：每手上限 ≥ 最貴兵價，規則合法", str(cr.turn_cap(0)))
	# 花不完的錢提示
	var mr = RSET.standard(0b0000000111)   # 劍、盾、弓
	mr.budget = [150, 150]
	mr.type_cap = 1
	var ms: Dictionary = mr.max_spend(0)
	ok(ms["units"] == 3 and ms["spend"] == 14 and ms["unused"] == 136, "大廳提示：150 金、3 種兵各限 1 隻 → 最多 3 隻 14 金、136 金用不到", str(ms))

## 第五輪沙盒（R3 閘門）：每個技能開關、倍率、不互相污染、100％＝標準。
static func _sb_tags(armies: Array, r) -> Dictionary:
	var s = Sim.new(armies[0].copy(), armies[1].copy(), r)
	var seen := {}
	var fr := false
	while not s.finished:
		s.step()
		fr = fr or s.frenzy
		for e in s.events:
			seen[e["kind"]] = true
			for tg in e.get("tags", []):
				seen[tg] = true
	seen["_frenzy"] = fr
	return seen

func test_sandbox_v5() -> void:
	var rng := RandomNumberGenerator.new()
	# 找一組十種兵都有、標準規則下所有技能事件都會出現的對戰（固定種子）
	var pairs: Array = []
	for k in 8:
		rng.seed = 8800 + k
		var a0 = F.random_formation(0, rng, "mixed", "", D.COUNT)
		var a1 = F.random_formation(0, rng, "mixed", "", D.COUNT).mirrored()
		pairs.append([a0, a1])
	# 刻意的對戰：騎兵正面衝長槍兵（拒騎）；盾兵牆對盾兵牆打到狂熱
	pairs.append([army_from(0, [[D.CAVALRY, 2, 3], [D.CAVALRY, 2, 4], [D.CAVALRY, 2, 5]]), army_from(1, [[D.PIKE, 3, 3], [D.PIKE, 3, 4], [D.PIKE, 3, 5]])])
	var wall0: Array = []
	var wall1: Array = []
	for rr in 9:
		wall0.append([D.SHIELD, 5, rr])
		wall1.append([D.SHIELD, 5, rr])
	pairs.append([army_from(0, wall0), army_from(1, wall1)])
	var std = RSET.standard()
	var want := {"charge": EVS.CHARGE, "taunt": EVS.TAUNT, "backstab": EVS.BACKSTAB, "counter": EVS.COUNTER, "stealth": EVS.REVEAL,
		"brace": EVS.PIKE_BRACE, "splash": EVS.SPLASH, "heal": EVS.HEAL, "drum": EVS.DRUM, "breach": EVS.BREACH, "frenzy": "_frenzy", "rally": EVS.RALLY_ON}
	var bad: Array = []
	for sk in want:
		var ev: String = want[sk]
		var on_any := false
		var off_any := false
		var r = RSET.standard()
		r.skills_off = [sk]
		for pr in pairs:
			var a: Dictionary = _sb_tags(pr, std)
			var b: Dictionary = _sb_tags(pr, r)
			on_any = on_any or bool(a.get(ev, false))
			off_any = off_any or bool(b.get(ev, false))
		if not on_any or off_any:
			bad.append("%s 開=%s 關=%s" % [sk, on_any, off_any])
	ok(bad.is_empty(), "沙盒技能開關：12 個技能在標準下會出現、關掉後完全不出現", str(bad))
	# 倍率
	var pr0: Array = pairs[0]
	var r2 = RSET.standard()
	r2.stat_pct = {D.SWORD: [200, 50, 150]}
	var s2 = Sim.new(pr0[0].copy(), pr0[1].copy(), r2)
	var sw = null
	for u in s2.units:
		if u.type == D.SWORD:
			sw = u
			break
	ok(sw != null and sw.max_hp == D.STATS[D.SWORD]["hp"] * 2 and sw.atk == D.STATS[D.SWORD]["atk"] / 2 and sw.speed == D.STATS[D.SWORD]["speed"] * 3 / 2,
		"沙盒倍率：劍士血 200%、攻 50%、速 150% 生效", str([sw.max_hp, sw.atk, sw.speed] if sw else null))
	# 100％、全開＝標準（不是沙盒、走舊路徑、指紋相同）
	var r3 = RSET.standard()
	r3.stat_pct = {D.SWORD: [100, 100, 100]}
	var sa = Sim.new(pr0[0].copy(), pr0[1].copy())
	sa.run_to_end()
	var sb = Sim.new(pr0[0].copy(), pr0[1].copy(), r3)
	sb.run_to_end()
	ok(not r3.is_sandbox() and sa.fingerprint == sb.fingerprint, "沙盒 100％、技能全開＝標準規則（指紋相同）")
	# 交錯跑兩場不同規則：標準那場和單獨跑的指紋相同（沒有共用狀態被污染）
	var r4 = RSET.standard()
	r4.stat_pct = {D.ARCHER: [50, 200, 120], D.CAVALRY: [150, 150, 80]}
	r4.skills_off = ["taunt", "frenzy"]
	var x = Sim.new(pr0[0].copy(), pr0[1].copy(), r4)
	var y = Sim.new(pr0[0].copy(), pr0[1].copy())
	while not (x.finished and y.finished):
		x.step()
		y.step()
	ok(y.fingerprint == sa.fingerprint and x.fingerprint != sa.fingerprint, "沙盒與標準交錯跑：標準那場指紋和單獨跑相同")

func test_battle_code_v5() -> void:
	var BC = load("res://scripts/game/battle_code.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 31337
	var a0 = AI.build(0, 100, rng)["army"]
	var a1 = AI.build(1, 100, rng)["army"]
	ok(BC.encode(a0, a1, RSET.standard()) == BC.encode(a0, a1), "標準規則的對戰代碼仍是 NTB2、和不給規則時位元組相同")
	var r = RSET.standard()
	r.budget = [180, 180]
	r.unit_cap = 40
	r.ticks = 2400
	r.stat_pct = {D.ARCHER: [120, 100, 100]}
	var b0 := Army.new(0, 180)
	var b1 := Army.new(1, 180)
	b0.apply_rules(r, 0)
	b1.apply_rules(r, 1)
	b0 = AI.build(0, 180, rng, -1, r.pool_of(0), r)["army"]
	b1 = AI.build(1, 180, rng, -1, r.pool_of(1), r)["army"]
	var code: String = BC.encode(b0, b1, r)
	var d: Dictionary = BC.decode(code)
	var s1 = Sim.new(b0.copy(), b1.copy(), r)
	s1.run_to_end()
	var ok_dec: bool = d["ok"] and d["rules"] != null and d["rules"].equals(r)
	var same := false
	if ok_dec:
		var s2 = Sim.new(d["a0"], d["a1"], d["rules"])
		s2.run_to_end()
		same = s2.fingerprint == s1.fingerprint
	ok(code.begins_with("NTB3.") and b0.count() > 24 and ok_dec and same, "自訂規則（180 金、40 隻、120 秒、沙盒）對戰代碼 NTB3：解碼後規則相同、播出同一場", "units=%d %s" % [b0.count(), d.get("why", "")])
	var broken := code.substr(0, code.length() - 3) + "abc"
	ok(not BC.decode(broken)["ok"], "NTB3 校驗碼壞掉會被拒")


## 第五輪（Codex 實作第 1 輪）：判定、系列、輪流落子終止都用真的程式驗，不是只驗測試裡自己寫的公式。
func test_rules_e2e_v5() -> void:
	var GS = load("res://scripts/ui/game_screens.gd")
	var rng := RandomNumberGenerator.new()
	# 讓子判定：真的跑到時間到，模擬器判的勝負＝用最終戰力獨立算的結果
	var jb: Array = []
	var timeouts := 0
	for k in 40:
		rng.seed = 7100 + k
		var r = RSET.standard()
		r.handicap = true
		r.budget = [rng.randi_range(5, 18) * 10, rng.randi_range(5, 18) * 10]
		if r.budget[0] == r.budget[1]:
			r.budget[1] += 10
		r.ticks = 1200
		var wall0: Array = []
		var wall1: Array = []
		for rr in 9:
			if rng.randf() < 0.85:
				wall0.append([D.SHIELD, 5, rr])
			if rng.randf() < 0.85:
				wall1.append([D.SHIELD, 5, rr])
		var a0 = army_from(0, wall0)
		var a1 = army_from(1, wall1)
		a0.budget = r.budget[0]
		a1.budget = r.budget[1]
		var s = Sim.new(a0, a1, r)
		s.fast = true
		s.run_to_end()
		if s.tick < 1200 or s.alive_count(0) == 0 or s.alive_count(1) == 0:
			continue
		timeouts += 1
		var b0: int = r.budget[0]
		var b1: int = r.budget[1]
		var dl: int = s.power(0) * b1 - s.power(1) * b0
		var want := -1 if 100 * absi(dl) < 3 * 1000 * b0 * b1 else (0 if dl > 0 else 1)
		if s.winner != want or s.judge != 2:
			jb.append([k, s.winner, want])
	ok(timeouts >= 10 and jb.is_empty(), "讓子判定（實際跑到時間到 %d 場）：模擬器的勝負＝依最終戰力與各自預算獨立算的結果" % timeouts, str(jb))
	# 系列：用遊戲裡實際判斷系列結束的函式
	var sb: Array = []
	var cases := [[1, [0, 0], 1, true], [1, [1, 0], 1, true], [3, [1, 0], 1, false], [3, [2, 0], 2, true], [3, [1, 1], 3, false], [3, [1, 1], 5, true],
		[5, [2, 2], 4, false], [5, [3, 1], 4, true], [5, [2, 2], 7, true], [7, [3, 3], 8, false], [7, [4, 3], 7, true], [7, [3, 3], 9, true]]
	for c in cases:
		var r = RSET.standard()
		r.rounds = c[0]
		if GS.series_done(c[1], c[2], r) != c[3]:
			sb.append(c)
	ok(sb.is_empty() and GS.series_done([1, 1], 5, null) and not GS.series_done([1, 1], 4, null), "系列結束判斷（遊戲實際用的函式）：單局、三戰兩勝含平手延長、五戰三勝、七戰四勝；沒有規則＝1.3.0", str(sb))
	# 輪流落子終止：每個合法卡池 × 三種落子方式，雙方都擺完、各有戰鬥兵、陣型合法、不會卡住
	var tb: Array = []
	var n := 0
	for m in range(1, 1024):
		var r = RSET.standard(m)
		if not r.validate().is_empty():
			continue
		var rule: String = ["snake5", "cap10", "custom"][m % 3]
		r.place_rule = rule
		r.turns = 1 + m % 7
		r.budget = [[30, 60, 100, 150, 200][m % 5], [30, 60, 100, 150, 200][m % 5]]
		r.unit_cap = [4, 12, 24, 40][m % 4]
		r.type_cap = [0, 1, 2, 0][(m / 4) % 4]
		r.carry = m % 2 == 0
		if not r.validate().is_empty():
			continue
		n += 1
		var ta := Army.new(0, 100)
		var tb2 := Army.new(1, 100)
		ta.apply_rules(r, 0)
		tb2.apply_rules(r, 1)
		var tp = TP.new(ta, tb2, m % 2, rule, r)
		rng.seed = 9000 + m
		var guard := 0
		while not tp.done() and guard < 200:
			guard += 1
			AIT5.play_turn(tp, rng, m % 3)
		var why0 := legal_army(ta, r, 0)
		var why1 := legal_army(tb2, r, 1)
		if not tp.done() or why0 != "" or why1 != "" or not ta.has_combat() or not tb2.has_combat():
			tb.append([m, rule, tp.done(), why0, why1, ta.has_combat(), tb2.has_combat()])
	ok(n > 500 and tb.is_empty(), "輪流落子窮舉 %d 組合法規則（卡池×落子方式×手數×預算×人數×單種上限×累積）：都會結束、陣型合法、雙方都有戰鬥兵" % n, str(tb.slice(0, 3)))
	# 雙方不同卡池（配對抽樣 200 組）：AI 各自只用自己的卡池
	var pb: Array = []
	for k in 200:
		rng.seed = 12000 + k
		var r = RSET.standard()
		r.ai_pool_same = false
		r.pool = [rng.randi_range(1, 1023), rng.randi_range(1, 1023)]
		if not r.validate().is_empty():
			continue
		var a = AI.build(1, 100, rng, -1, r.pool_of(1), r)["army"]
		var why := legal_army(a, r, 1)
		if why != "" or not a.has_combat():
			pb.append([k, why])
	ok(pb.is_empty(), "雙方不同卡池（配對抽樣）：AI 只用自己的卡池、陣型合法", str(pb.slice(0, 3)))
	# 規則代碼壞資料：型別錯誤要回傳拒絕，不是讓程式出錯
	var bad_bodies := [
		[100, 100, 0, 1800, 24, 0, 1023, 1023, 1, 3, "snake5", 5, 0, 1, 1, [[0, {}, 100, 100]], []],
		[100, 100, 2, 1800, 24, 0, 1023, 1023, 1, 3, "snake5", 5, 0, 1, 1, [], []],
		[100, 100, 0, 1800, 24, 0, 1023, 5000, 1, 3, "snake5", 5, 0, 1, 1, [], []],
		[100, 100, 0, 1800, 24, 0, 1023, 1023, 1, 3, 7, 5, 0, 1, 1, [], []],
		[100, 100, 0, 1800, 24, 0, 1023, 1023, 1, 3, "snake5", 5, 0, 1, 1, [], [3]],
		["x", 100, 0, 1800, 24, 0, 1023, 1023, 1, 3, "snake5", 5, 0, 1, 1, [], []]]
	var rej := 0
	for body in bad_bodies:
		var b64 := Marshalls.utf8_to_base64(JSON.stringify(body)).replace("+", "-").replace("/", "_").replace("=", "")
		var d: Dictionary = RSET.from_code("NTBR1.%s.%s" % [b64, b64.sha256_text().substr(0, 6)])
		if not d["ok"]:
			rej += 1
	ok(rej == bad_bodies.size(), "規則代碼壞資料（沙盒值是字典、布林欄是 2、隱藏的 AI 卡池非法、落子方式不是字串、技能不是字串、金幣是字串）全部被拒", "%d/%d" % [rej, bad_bodies.size()])
	# 對戰代碼保真：卡池或人數不是標準就輸出 NTB3
	var BC = load("res://scripts/game/battle_code.gd")
	var r2 = RSET.standard(0b0000000111)
	var x0 := Army.new(0, 100)
	var x1 := Army.new(1, 100)
	x0.apply_rules(r2, 0)
	x1.apply_rules(r2, 1)
	x0.place(D.SWORD, 5, 4)
	x1.place(D.SWORD, 10, 4)
	var r3 = RSET.standard()
	r3.unit_cap = 4
	ok(BC.encode(x0, x1, r2).begins_with("NTB3.") and BC.encode(x0, x1, r3).begins_with("NTB3.") and BC.encode(x0, x1, RSET.standard(31)).begins_with("NTB2."),
		"對戰代碼：卡池（3 種）或人數上限（4 隻）不標準就用 NTB3；經典 5 種仍是 NTB2")
