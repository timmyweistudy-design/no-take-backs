extends "res://tests/test_base.gd"

func test_free_v6() -> void:
	# 量化
	var qb: Array = []
	for c in [[225, 200], [226, 250], [275, 250], [274, 250], [276, 300], [0, 0], [24, 0], [25, 0], [26, 50]]:
		if Army.quant(c[0]) != c[1]:
			qb.append(c)
	ok(qb.is_empty(), "量化：floor((v+24)/50)×50，剛好一半往小（225→200、226→250、275→250）", str(qb))
	# 舊字串「解碼→編碼」完全相同：封存的 NTB2、AI 的 NTB1、標準 NTBR1
	var BC = load("res://scripts/game/battle_code.gd")
	var g = JSON.parse_string(FileAccess.get_file_as_string("res://tests/golden/battle_codes_v2.json"))
	var same2 := 0
	for row in g["rows"]:
		var d: Dictionary = BC.decode(str(row["code"]))
		if d["ok"] and BC.encode(d["a0"], d["a1"]) == str(row["code"]):
			same2 += 1
	var rng := RandomNumberGenerator.new()
	var same1 := 0
	for i in 50:
		rng.seed = 600 + i
		var a = AI.build(i % 2, 100, rng)["army"]
		var b := Army.new(i % 2, 100)
		if b.load_code(a.to_code()) == "" and b.to_code() == a.to_code():
			same1 += 1
	var sr: String = RSET.standard().to_code()
	ok(same2 == 40 and same1 == 50 and sr.begins_with("NTBR1.") and RSET.from_code(sr)["rules"].to_code() == sr, "舊字串解碼再編碼完全相同：封存 NTB2 40 筆、NTB1 50 筆、標準規則 NTBR1", "%d %d" % [same2, same1])
	# NTBR2：來回、非法組合被拒、預設部署不能用 NTBR2
	var fr = free_rules(800, 7000, 1)
	var c2: String = fr.to_code()
	var dd: Dictionary = RSET.from_code(c2)
	var bad_ok := true
	for mk in [["grid", 1000, 6000, 1], ["free", 550, 7000, 0], ["free", 800, 8000, 0], ["grid", 800, 6000, 0], ["free", 800, 6500, 3]]:
		var r = RSET.standard()
		r.deploy = mk[0]
		r.spacing = mk[1]
		r.depth = mk[2]
		r.fullfield = mk[3]
		bad_ok = bad_ok and not r.validate().is_empty()
	var fb = free_rules(800, 7000, 1)
	fb.place_rule = "blind"
	bad_ok = bad_ok and not fb.validate().is_empty()
	ok(c2.begins_with("NTBR2.") and dd["ok"] and dd["rules"].equals(fr) and bad_ok, "NTBR2：自由部署規則來回相同；格子＋全場、間距 550、縱深 8000、格子改間距、全場＋暗擺都被拒")
	# 自由陣型池：三種擺法 × 間距 × 縱深都合法、非空
	var pb: Array = []
	var n := 0
	for sp in [600, 800, 1000]:
		for dp in [6000, 7000, 7500]:
			var r = free_rules(sp, dp)
			var pl: Array = F.free_pool(0, 12, 4400 + sp + dp, r)
			for a in pl:
				n += 1
				var why := legal_free(a, r, 0)
				if why != "":
					pb.append([sp, dp, why])
	ok(n == 108 and pb.is_empty(), "自由陣型池（拉開／偏移／密集 × 間距 3 × 縱深 3）%d 套都合法、非空" % n, str(pb.slice(0, 3)))
	# 確定性：打亂輸入順序，指紋相同；自由陣型的指紋和格子陣型不同
	var r8 = free_rules(800, 7500)
	rng.seed = 77
	var fa = F.to_free(AI.build(0, 100, rng)["army"], r8, rng, "jitter")
	var fb2 = F.to_free(AI.build(1, 100, rng)["army"], r8, rng, "dense")
	var s1 = Sim.new(fa.copy(), fb2.copy(), r8)
	s1.run_to_end()
	var fa2 = fa.copy()
	fa2.units.reverse()
	var fb3 = fb2.copy()
	fb3.units.shuffle()
	var s2 = Sim.new(fa2, fb3, r8)
	s2.run_to_end()
	ok(s1.fingerprint == s2.fingerprint and s1.free, "自由陣型：打亂輸入順序指紋相同（編號依自己視角 (y,x) 排序）")
	# 獨立鏡像（不從 id 反推）：自由 40 組＋格子 10 組
	var mb: Array = []
	for i in 40:
		var r = free_rules([600, 800, 1000][i % 3], [6000, 7000, 7500][(i / 3) % 3])
		rng.seed = 9100 + i
		var x0 = F.to_free(F.random_formation(0, rng), r, rng, ["stretch", "jitter", "dense"][i % 3])
		var x1 = F.to_free(F.random_formation(0, rng), r, rng, ["dense", "stretch", "jitter"][i % 3]).mirrored()
		var why: String = MC.check_free(x0, x1, r)
		if why != "":
			mb.append([i, why])
	for i in 10:
		rng.seed = 9300 + i
		var why2: String = MC.check_free(AI.build(0, 100, rng)["army"], AI.build(1, 100, rng)["army"])
		if why2 != "":
			mb.append(["grid", i, why2])
	ok(mb.is_empty(), "獨立鏡像（tick 0 起始座標配對、比 slot、事件來源目標、完整狀態）：自由 40 組、格子 10 組都對稱", str(mb.slice(0, 2)))
	# 整群剛體搬移：碰邊貼齊、相對位置不變；撞到群外的兵就不動
	var ga := Army.new(0, 200)
	ga.apply_rules(free_rules(800, 7500), 0)
	ga.guard_combat = false
	ga.place_xy(D.SWORD, 3000, 3000)
	ga.place_xy(D.SWORD, 3800, 3000)
	ga.place_xy(D.ARCHER, 1000, 5000)
	var before: Array = [ga.pos_of(ga.units[0]), ga.pos_of(ga.units[1])]
	var mv: Vector2i = ga.move_group([0, 1], 9000, 0)
	var after: Array = [ga.pos_of(ga.units[0]), ga.pos_of(ga.units[1])]
	var rigid: bool = after[1] - after[0] == before[1] - before[0] and after[1].x == 7500
	var mv2: Vector2i = ga.move_group([0, 1], -after[0].x + 1000, 5000 - 3000)
	ok(rigid and mv2.x == -99999 and ga.pos_of(ga.units[0]) == after[0], "整群剛體搬移：拖過頭就貼著部署區邊停住、相對位置不變；撞到群外的兵整群不動", str([mv, after, mv2]))
	ok(ga.flip_group([0, 1]) and ga.pos_of(ga.units[0]).y == 6000, "上下翻轉一群（y → 9000−y）")
	# 輪流落子・全場：批次原子、敵距、會結束、擠滿會跳手並記錄
	var tb: Array = []
	var skips := 0
	for k in 30:
		var r = free_rules(800, 7500, 1)
		r.place_rule = "snake5"
		r.budget = [200, 200]
		r.unit_cap = 40
		var ta := Army.new(0, 200)
		var tb2 := Army.new(1, 200)
		ta.apply_rules(r, 0)
		tb2.apply_rules(r, 1)
		var tp = TP.new(ta, tb2, k % 2, "snake5", r)
		rng.seed = 1700 + k
		var guard := 0
		while not tp.done() and guard < 400:
			guard += 1
			var me: int = tp.current
			var items: Array = []
			var tries := 0
			while items.size() < 3 and tries < 60:
				tries += 1
				var t: int = [D.SWORD, D.ARCHER, D.SHIELD, D.MEDIC][rng.randi_range(0, 3)]
				var x := Army.quant(rng.randi_range(200, 15800))
				var y := Army.quant(rng.randi_range(200, 8800))
				var spent := 0
				for it in items:
					spent += D.cost(it[0])
				if spent + D.cost(t) > tp.turn_left():
					continue
				var probe = tp.armies[me].copy()
				for it in items:
					probe.units.append({"type": it[0], "x": it[1], "y": it[2]})
				if tp.check_place_xy(t, x, y) == "" and probe.check_place_xy(t, x, y) == "":
					items.append([t, x, y])
			if items.is_empty() or not tp.place_batch(items):
				tp.end_turn()
		skips += tp.skipped.size()
		var en0: Array = []
		for u in tb2.units:
			en0.append(tb2.pos_of(u))
		if not tp.done():
			tb.append([k, "沒結束"])
		else:
			for u in ta.units:
				for e in en0:
					var p := ta.pos_of(u)
					if (p.x - e.x) * (p.x - e.x) + (p.y - e.y) * (p.y - e.y) < 1500 * 1500:
						tb.append([k, "敵距"])
	ok(tb.is_empty(), "輪流落子・全場 30 局：批次落子、雙方離敵兵都 ≥1.5 格、都會結束（跳手 %d 次）" % skips, str(tb.slice(0, 3)))
	# 對戰代碼：自由部署 NTB3 往返、播出同一場
	var code: String = BC.encode(fa, fb2, r8)
	var d3: Dictionary = BC.decode(code)
	var same3 := false
	if d3["ok"]:
		var s3 = Sim.new(d3["a0"], d3["a1"], d3["rules"])
		s3.run_to_end()
		same3 = s3.fingerprint == s1.fingerprint
	ok(code.begins_with("NTB3.") and same3 and fa.to_code().begins_with("NTB5."), "自由部署對戰代碼 NTB3（內含 NTB5 陣型、NTBR2 規則）往返播出同一場", str(d3.get("why", "")))
	# NTB5：壞資料被拒（保留位不是 0、長度不對、超過格式上限）
	var raw := Marshalls.base64_to_raw(fa.to_code().split(".")[1].replace("-", "+").replace("_", "/") + "==".substr(0, (4 - fa.to_code().split(".")[1].length() % 4) % 4))
	var bad5: Array = []
	var r1 := raw.duplicate()
	r1[4] = r1[4] | 1
	bad5.append(r1)
	var r2 := raw.duplicate()
	r2[1] = r2[1] + 1
	bad5.append(r2)
	var rej5 := 0
	for bb in bad5:
		var body := Marshalls.raw_to_base64(bb).replace("+", "-").replace("/", "_").replace("=", "")
		var t5 := Army.new(0, 200)
		t5.apply_rules(r8, 0)
		if t5.load_code("NTB5.%s.%s" % [body, body.sha256_text().substr(0, 4)]) != "":
			rej5 += 1
	ok(rej5 == 2, "NTB5 壞資料（保留位不是 0、隻數和長度不符）被拒", str(rej5))
	# AI 自由擺法：各種規則都合法、在自己半場（全場明牌時 AI 也只擺自己這邊）
	var ab: Array = []
	for k in 60:
		var r = free_rules([600, 800, 1000][k % 3], [6000, 6500, 7000, 7500][k % 4], [0, 0, 2][k % 3])
		r.budget = [[60, 100, 180][k % 3], [60, 100, 180][k % 3]]
		r.unit_cap = [12, 24, 40][k % 3]
		rng.seed = 5600 + k
		var a
		match k % 3:
			0: a = AI.build(1, r.budget_of(1), rng, -1, -1, r)["army"]
			1: a = AIT5.build_full(1, rng, 1, [], -1, r)
			_: a = HA5.build([], [], rng, -1, r)
		var r_half = r.copy()
		r_half.fullfield = 0
		var why := legal_free(a, r_half, 1)
		if why != "" or not a.has_combat():
			ab.append([k, why])
	ok(ab.is_empty(), "AI 自由擺法 60 組規則（簡單／普通／困難、間距、縱深、明牌全場）：陣型合法、只在自己半場、有戰鬥兵", str(ab.slice(0, 3)))


## 第六輪（篩選抓到的）：格子陣型轉自由陣型，三種排法、全部間距×縱深都不能少兵、都要合法
func test_to_free_keeps_units_v6() -> void:
	var F = load("res://scripts/core/formations.gd")
	var bad: Array = []
	var n := 0
	for sp in [600, 650, 700, 750, 800, 850, 900, 950, 1000]:
		for dp in [6000, 6500, 7000, 7500]:
			var r = free_rules(sp, dp)
			var src: Array = F.pool(0, 30, 777, 10)
			var rng := RandomNumberGenerator.new()
			for i in src.size():
				for st in ["stretch", "jitter", "dense"]:
					rng.seed = i
					var a = F.to_free(src[i], r, rng, st)
					n += 1
					var why := legal_free(a, r, 0)
					if a.units.size() != src[i].units.size() or why != "":
						bad.append("%d/%d %s #%d：%d→%d %s" % [sp, dp, st, i, src[i].units.size(), a.units.size(), why])
	ok(bad.is_empty(), "格子轉自由 %d 套（9 種間距 × 4 種縱深 × 三種排法）都不少兵且合法" % n, str(bad.slice(0, 5)))


## Codex 實作第 1 輪 #7、#3、#10：has_room 要和 0.05 格完整窮舉一致；全場對戰代碼要驗跨隊距離；cmds 不接受
func test_free_review_fixes_v6() -> void:
	var rng := RandomNumberGenerator.new()
	var bad: Array = []
	var nfull := 0
	for k in 6:
		rng.seed = 5150 + k
		var r = free_rules([1000, 800, 600][k % 3], 6000)
		r.budget = [400, 400]
		r.unit_cap = 40
		var a = Army.new(0, 400)
		a.apply_rules(r, 0)
		for e in 14 + k * 2:
			a.enemy_pos.append(Vector2i(rng.randi_range(0, 6200), rng.randi_range(0, 9000)))
		for i in 4000:
			a.place_xy(D.SWORD, Army.quant(rng.randi_range(200, 6000)), Army.quant(rng.randi_range(200, 8800)))
			if a.units.size() >= 39:
				break
		var brute := false
		var x := 200
		while x <= 6000 and not brute:
			var y := 200
			while y <= 8800:
				if a.check_place_xy(D.SWORD, x, y) == "":
					brute = true
					break
				y += 50
			x += 50
		if not brute:
			nfull += 1
		if a.has_room() != brute:
			bad.append("#%d %d 隻：has_room=%s 窮舉=%s" % [k, a.units.size(), a.has_room(), brute])
	ok(bad.is_empty(), "has_room 和 0.05 格完整窮舉一致（6 種隨機擠滿＋敵兵禁區的陣，其中 %d 種真的沒位置）" % nfull, str(bad))
	# 全場對戰代碼：雙方疊在同一點 → 拒絕
	var BC = load("res://scripts/game/battle_code.gd")
	var fr = free_rules(800, 6000, 1)
	var b0 = Army.new(0, 100)
	b0.apply_rules(fr, 0)
	var b1 = Army.new(1, 100)
	b1.apply_rules(fr, 1)
	b0.place_xy(D.SWORD, 8000, 4500)
	b1.place_xy(D.SWORD, 8000, 4500)
	var dd: Dictionary = BC.decode(BC.encode(b0, b1, fr))
	ok(not dd["ok"], "全場對戰代碼：兩軍疊在一起（離敵兵不到 1.5 格）被拒")
	var c0 = Army.new(0, 100)
	c0.apply_rules(fr, 0)
	c0.place_xy(D.SWORD, 3000, 4500)
	var c1 = Army.new(1, 100)
	c1.apply_rules(fr, 1)
	c1.place_xy(D.SWORD, 13000, 4500)
	var good: String = BC.encode(c0, c1, fr)
	ok(BC.decode(good)["ok"], "全場對戰代碼：合法的仍然接受")
	# 加了 cmds 的偽造代碼（校驗碼重算）→ 拒絕
	var body: String = good.split(".")[1].replace("-", "+").replace("_", "/")
	while body.length() % 4 != 0:
		body += "="
	var j: Dictionary = JSON.parse_string(Marshalls.base64_to_utf8(body))
	j["cmds"] = [{"team": 1, "batch": []}]
	var b2 := Marshalls.utf8_to_base64(JSON.stringify(j)).replace("+", "-").replace("/", "_").replace("=", "")
	ok(not BC.decode("NTB3.%s.%s" % [b2, b2.sha256_text().substr(0, 6)])["ok"], "對戰代碼帶 cmds（輪序紀錄，尚不支援驗證）被拒，不會被當成已驗證")
	# §3.8：雙人全場擺完卻有一方沒有戰鬥兵 → 不開打，有戰鬥兵的一方勝；雙方都沒有＝和局（Codex 實作第 2 輪 #5）
	var Sim = load("res://scripts/core/battle_sim.gd")
	var m0 = Army.new(0, 100)
	m0.apply_rules(fr, 0)
	m0.place_xy(D.SWORD, 3000, 4500)
	var m1 = Army.new(1, 100)
	m1.apply_rules(fr, 1)
	m1.guard_combat = false
	m1.place_xy(D.MEDIC, 13000, 4500)
	var sm = Sim.new(m0.copy(), m1.copy(), fr)
	ok(sm.finished and sm.winner == 0 and sm.tick == 0, "雙人全場：紅方只有支援兵 → 第 0 tick 藍方勝", "%s %d %d" % [sm.finished, sm.winner, sm.tick])
	var m2 = Army.new(0, 100)
	m2.apply_rules(fr, 0)
	m2.guard_combat = false
	m2.place_xy(D.MEDIC, 3000, 4500)
	var sd = Sim.new(m2, m1.copy(), fr)
	ok(sd.finished and sd.winner == -1, "雙人全場：雙方都沒有戰鬥兵 → 和局")
	var nf = free_rules(800, 6000, 0)
	var n1 = m1.copy()
	n1.apply_rules(nf, 1)
	var sn = Sim.new(m0.copy(), n1, nf)
	ok(not sn.finished, "非全場的自由部署不套這條（照常開打）")


## 第六輪：自由陣型覆盤的改動計數依 eid（編輯識別），不依戰鬥編號
func test_review_free_v6() -> void:
	var RV = load("res://scripts/ui/replay_view.gd")
	var r = free_rules()
	var a = Army.new(0, 1000)
	a.apply_rules(r, 0)
	for p in [[0, 1000, 1000], [0, 2000, 3000], [1, 3000, 5000]]:
		a.place_xy(p[0], p[1], p[2])
	for i in a.units.size():
		a.units[i]["eid"] = i
	var b = a.copy()
	ok(RV.review_changes(a, b) == 0, "覆盤自由：沒改＝0")
	b.move_xy(0, 1500, 1000)
	ok(RV.review_changes(a, b) == 1, "覆盤自由：搬一隻＝1")
	var c = a.copy()
	c.units.remove_at(1)
	ok(RV.review_changes(a, c) == 1, "覆盤自由：拿掉一隻＝1")
	b.units.remove_at(2)
	ok(RV.review_changes(a, b) == 2, "覆盤自由：搬一隻又拿掉一隻＝2")
	# 搬到比別人前面（排序會變）也只算 1
	var d = a.copy()
	d.move_xy(2, 3000, 200)
	ok(RV.review_changes(a, d) == 1, "覆盤自由：排序改變仍只算 1")


func test_free_skip_v6() -> void:
	# 紅方先把全場每 2 格擺一隻（雙人全場、離敵 1.5 格）→ 藍方沒有任何合法位置 → 自動跳手並記錄
	var r = free_rules(1000, 7500, 1)
	r.place_rule = "custom"
	r.turns = 2
	r.budget = [200, 200]
	r.unit_cap = 40
	var ta := Army.new(0, 200)
	var tb := Army.new(1, 200)
	ta.apply_rules(r, 0)
	tb.apply_rules(r, 1)
	tb.guard_combat = false
	var x := 1000
	while x <= 15000:
		var y := 700
		while y <= 8800:
			tb.units.append({"type": D.ARCHER, "x": x, "y": y})
			y += 2000
		x += 2000
	var tp = TP.new(ta, tb, 0, "custom", r)
	ok(tp.done() or (tp.current == 1 and not tp.skipped.is_empty()), "全場擠滿：藍方沒有任何合法位置 → 自動跳手並記錄（畫面會提示）", str([tp.current, tp.skipped, tp.done()]))
