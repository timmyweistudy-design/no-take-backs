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
	for pz in PZ.tutorials() + PZ.puzzles():
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
	var n_pz: int = (PZ.tutorials() + PZ.puzzles()).size()
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
	ok(n == 14 and bad.is_empty(), "14 個技能示範都觸發預期事件、說明數值都換好", str(bad))
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

## 畫面層真的消費事件（Codex R3 第 2 輪）：把真實戰鬥的每個 tick 交給戰鬥畫面的 _sim_step（含 _on_event、展示緩衝），
## 不能報錯、攻擊事件一定產生演出；圖鑑的 _codex_tick 每段示範都要真的跳字、跳在觸發者身上。
func test_ui_consumers() -> void:
	var GS = load("res://scripts/ui/game_screens.gd")
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
			for e in g.view.events:
				kinds[e["kind"]] = true
				if g.event_route(e) == "attack":
					n_att += 1
			attacks += n_att
			if n_att > 0:
				if g.fx.is_empty():
					bad.append("tick%d 有 %d 次攻擊卻沒有演出" % [g.view.tick, n_att])
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
			var at: float = g.atk_progress(g._disp_tick() - (g.atk_hit[u.id] - g.ViewBuffer.DELAY), u.type)
			if at > 0.0 and at < Art.ATK_WINDUP:
				pre_ok = true
				break
		g._sim_step(false)
	ok(pre_ok, "命中前一格畫面上已經在前搖")
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
