extends "res://tests/test_base.gd"

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
	# 判定邊界直接驗正式的 _check_end()：用血量控制戰力（劍士 5 金 250 血→戰力＝20×血）
	var eb: Array = []
	var bcases := [
		# [藍預算, 紅預算, 藍血, 紅血, 期望勝方]：讓子 100 vs 150 剛好 3%（不算平手）、差一點（平手）、反方向
		[100, 150, 250, 150, 0], [100, 150, 250, 151, -1], [150, 100, 150, 250, 1], [150, 100, 151, 250, -1],
		# 同預算（舊判定 judge 1）：差剛好 3000＝不平手、2980＝平手、反方向
		[100, 100, 250, 100, 0], [100, 100, 250, 101, -1], [100, 100, 100, 250, 1], [100, 100, 101, 250, -1]]
	for c in bcases:
		var r = RSET.standard()
		r.handicap = c[0] != c[1]
		r.budget = [c[0], c[1]]
		var a0 = army_from(0, [[D.SWORD, 5, 4]])
		var a1 = army_from(1, [[D.SWORD, 5, 4]])
		a0.budget = c[0]
		a1.budget = c[1]
		var s = Sim.new(a0, a1, r if r.handicap else null)
		s.units[0].hp = c[2] if s.units[0].team == 0 else c[3]
		s.units[1].hp = c[3] if s.units[1].team == 1 else c[2]
		s.tick = s.max_ticks
		s._check_end()
		if s.winner != c[4]:
			eb.append([c, s.winner, s.judge])
	ok(eb.is_empty(), "判定邊界（直接呼叫正式的 _check_end）：讓子剛好 3% 不平手、差一點平手、正反方向；同預算走舊判定也一樣", str(eb))
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
		for rule in ["snake5", "cap10", "custom"]:
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
	ok(n > 1500 and tb.is_empty(), "輪流落子窮舉 %d 組合法規則（卡池×落子方式×手數×預算×人數×單種上限×累積）：都會結束、陣型合法、雙方都有戰鬥兵" % n, str(tb.slice(0, 3)))
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
	# 雙方不同卡池的輪流落子：三種方式都會結束、雙方只用自己的卡池、各有戰鬥兵
	var dp: Array = []
	var dn := 0
	for k in 120:
		rng.seed = 13000 + k
		var r = RSET.standard()
		r.ai_pool_same = false
		r.pool = [rng.randi_range(1, 1023), rng.randi_range(1, 1023)]
		r.place_rule = ["snake5", "cap10", "custom"][k % 3]
		r.turns = 1 + k % 6
		if not r.validate().is_empty():
			continue
		dn += 1
		var ta := Army.new(0, 100)
		var tb3 := Army.new(1, 100)
		ta.apply_rules(r, 0)
		tb3.apply_rules(r, 1)
		var tp = TP.new(ta, tb3, k % 2, r.place_rule, r)
		var guard := 0
		while not tp.done() and guard < 200:
			guard += 1
			AIT5.play_turn(tp, rng, k % 3)
		if not tp.done() or legal_army(ta, r, 0) != "" or legal_army(tb3, r, 1) != "" or not ta.has_combat() or not tb3.has_combat():
			dp.append([k, r.place_rule, tp.done()])
	ok(dn > 30 and dp.is_empty(), "雙方不同卡池的輪流落子（%d 組，三種方式）：都會結束、各用自己的卡池、各有戰鬥兵" % dn, str(dp.slice(0, 3)))
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
	var r4 = RSET.standard(31)
	r4.ai_pool_same = false
	r4.pool = [31, 1023]
	ok(BC.encode(x0, x1, r2).begins_with("NTB3.") and BC.encode(x0, x1, r3).begins_with("NTB3.") and BC.encode(x0, x1, r4).begins_with("NTB3.") and BC.encode(x0, x1, RSET.standard(31)).begins_with("NTB2."),
		"對戰代碼：卡池（3 種）、人數上限（4 隻）、兩邊卡池不同（前 5 種 vs 全部）就用 NTB3；經典 5 種仍是 NTB2")


## 第五輪（Codex 實作第 3 輪）：存過的雙人規則（兩邊卡池不同）重開大廳要原樣保留。
func test_lobby_reopen_v5() -> void:
	var SV = load("res://scripts/game/save.gd")
	var GS = load("res://scripts/ui/game_screens.gd")
	var old_prefix: String = SV.prefix
	SV.prefix = "test_lobby_"
	SV.load_all()
	var r = RSET.standard()
	r.ai_pool_same = false
	r.pool = [31, 0b1000011111]
	r.place_rule = "cap10"
	SV.data["last_rules"] = {"duel": r.to_code(), "duel_preset": "custom"}
	var g = GS.new()
	g.sfx = FakeSfx.new()
	g._open_lobby("duel")
	ok(g.lobby_r.equals(r) and g.lobby_r.pool_of(1) == 0b1000011111, "重開雙人大廳：存過的規則（兩邊卡池不同、每手 10 金）原樣保留", str([g.lobby_r.pool, g.lobby_r.ai_pool_same]))
	g.free()
	for fn in ["user://test_lobby_save.json", "user://test_lobby_save.json.bak", "user://test_lobby_settings.json"]:
		if FileAccess.file_exists(fn):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(fn))
	SV.prefix = old_prefix
	SV.load_all()

# ═══════════════════ 第六輪：自由排兵 ═══════════════════


func test_code_fuzz_v7() -> void:
	var BC = load("res://scripts/game/battle_code.gd")
	var junk: Array = [[], {}, "x", 1.5, -1, null, true, 1e300, [[1]], {"a": 1}]
	var bad := 0
	var total := 0
	var a := Army.new(0, 100)
	a.place(0, 0, 0)
	var ac: String = a.to_code()
	var b := Army.new(1, 100)
	b.place(0, 15, 0)
	var bc: String = b.to_code()
	for pre in ["NTB2", "NTB3"]:
		for k in ["a", "b", "ba", "bb", "rules", "r", "d", "cmds"]:
			for v in junk:
				var body := {"a": ac, "b": bc, "ba": 100, "bb": 100, "r": "x", "d": "y", "rules": ""}
				body[k] = v
				var r: Dictionary = BC.decode(_fuzz_code(pre, body))
				total += 1
				if not r.has("ok"):
					bad += 1
		for v in junk:
			var r2: Dictionary = BC.decode(_fuzz_code(pre, v))
			total += 1
			if not r2.has("ok"):
				bad += 1
	ok(bad == 0, "N2：%d 組亂填的對戰代碼都正常回報（沒有中斷）" % total, "中斷 %d 組" % bad)
	# 規則代碼：17／21 欄的每一欄都填垃圾
	var bad2 := 0
	var total2 := 0
	for n in [17, 21]:
		var base: Array = []
		base.resize(n)
		base.fill(1)
		for i in n:
			for v in junk:
				var c: Array = base.duplicate()
				c[i] = v
				var rr: Dictionary = RSET.from_code(_fuzz_code("NTBR2" if n == 21 else "NTBR1", c))
				total2 += 1
				if not rr.has("ok"):
					bad2 += 1
	ok(bad2 == 0, "N2：%d 組亂填的規則代碼都正常回報" % total2, "中斷 %d 組" % bad2)
	# 陣型代碼也不能中斷
	var a2 := Army.new(0, 100)
	ok(a2.load_code("NTB1.%s.%s" % ["AAAA", "AAAA".sha256_text().substr(0, 4)]) != "", "N2：亂填的陣型代碼回報錯誤")
