extends "res://tests/test_base.gd"
## 1.1.0 A4：功能測試組「share_codes」：分享、各種代碼（出題碼、三考碼、車輪戰碼、相鄰碼）、招牌陣。
## 從原本依版本分的 v16、v161、v100 搬來，函式名不變（名字尾的 _v160／_v161／_v100／_v110 是做的版本）。會碰存檔的測試自己換前綴、結束還原。

func test_share_v160() -> void:
	var SH = load("res://scripts/game/share.gd")
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

func test_ntp4_v161() -> void:
	var WS = load("res://scripts/game/workshop.gd")
	var e := [[0, 10, 4], [3, 11, 4], [1, 12, 2]]
	var s := [[3, 4, 3], [3, 4, 5], [0, 5, 4], [2, 2, 4]]
	var c3: String = WS.encode4(e, s, "kill", Vector2i(-1, -1))
	ok(c3.begins_with("NTP3."), "沒指定目標照舊出 NTP3")
	var c4: String = WS.encode4(e, s, "kill", Vector2i(10, 4))
	if c4 != "":
		var d: Dictionary = WS.decode(c4)
		ok(c4.begins_with("NTP4.") and bool(d["ok"]) and d["pz"]["goal_unit"] == [10, 4], "指定斬首目標（不是最貴的那隻）", str(d.get("why")))
	ok(WS.encode4(e, s, "kill", Vector2i(4, 3)) == "", "斬首點到自己的兵不給碼")
	ok(WS.pick_fields("flawless", e, s, [2, 4]) == {"goal": "flawless", "goal_type": 2, "need_type": true}, "完美：點到哪隻就是那種兵")
	ok(WS.pick_fields("protect", e, s, [9, 9]).is_empty() and WS.pick_fields("protect", e, s, "x").is_empty(), "壞的目標欄位擋掉")
	# 竄改：NTP4 帶不在作者解的目標
	var j := JSON.stringify({"v": 4, "e": e, "s": s, "a": [0, 2, 3], "g": "protect", "t": [15, 8]})
	var b := Marshalls.utf8_to_base64(j).replace("+", "-").replace("/", "_").replace("=", "")
	ok(not bool(WS.decode("NTP4.%s.%s" % [b, b.sha256_text().substr(0, 6)])["ok"]), "目標不存在的 NTP4 拒收")
	ok(WS.decode("NTP3.x.y")["ok"] == false, "NTP3 舊路徑照舊驗")

func test_rules_equals_map_v161() -> void:
	var RS = load("res://scripts/core/ruleset.gd")
	var a = RS.standard()
	var b = RS.standard()
	ok(a.equals(b), "同樣規則相等")
	b.map_id = 3
	ok(not a.equals(b), "地圖不同就不相等（B1）")
	b.map_id = 0
	b.map_size = 2
	ok(not a.equals(b), "大小不同就不相等")

func test_signature_v161() -> void:
	var PS = load("res://scripts/game/persona.gd")
	var AI = load("res://scripts/core/ai_army.gd")
	var hits := 0
	for sd in 200:
		var t: int = PS.signature(2, sd, func(x): return true)
		if t >= 0:
			hits += 1
			ok(t in PS.SIG[2], "招牌陣只會是這個性格的兩套")
	ok(hits > 50 and hits < 110, "約 40% 用招牌陣（A11）", str(hits))
	ok(PS.signature(4, 3, func(x): return false) == -1, "卡池用不了就照舊")
	ok(PS.signature(1, 77, func(x): return true) == PS.signature(1, 77, func(x): return true), "同種子同結果（可重現）")
	for st in PS.SIG.size():
		for t in PS.SIG[st]:
			ok(int(t) < AI.TEMPLATES.size(), "招牌陣編號有效")

## M16：docs/codes.md 的前綴表和 code_kind 一致；亂碼不辨識。
func test_code_table_v100() -> void:
	var G = load("res://scripts/ui/screens/game_menus.gd")
	var want := {"NTB1": "army", "NTB5": "army", "NTB6": "army", "NTB2": "battle", "NTB3": "battle", "NTB4": "battle", "NTB7": "battle",
		"NTBR1": "rules", "NTBR6": "rules", "NTC1": "challenge", "NTP1": "workshop", "NTP2": "workshop", "NTP3": "workshop", "NTP4": "workshop",
		"NTS1": "settings", "NTW1": "waves", "NTQ1": "solution"}
	var bad: Array = []
	for p in want:
		if G.code_kind(p + ".abc.123456") != want[p]:
			bad.append(p)
	ok(bad.is_empty(), "每個前綴都認得", str(bad))
	for junk in ["", "hello", "NTX1.a.b", "ntb1.a.b", "NTB8.a.b"]:
		ok(G.code_kind(junk) == "", "不認得的不辨識：" + junk)
	var md := FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../docs/codes.md"))
	if md == "":
		print("SKIP docs/codes.md 不在（快照或匯出環境）")
	else:
		for p in want:
			ok(md.find(p) >= 0, "docs/codes.md 有寫 " + p)
	var WS = load("res://scripts/game/workshop.gd")
	for junk in ["NTP3.%%%.000000", "NTP4." + "A".repeat(7000) + ".x"]:
		ok(not bool(WS.decode(junk)["ok"]), "壞的出題碼不收")

## 1.1.0 B2：雙人輪序紀錄碼 NTD1：真的打一局輪流落子（蛇行 5 手），編碼後逐手重放得到同樣兩軍；改一手、少一手、換先手都不收。
func _dc_play(first: int) -> Array:
	var Army = load("res://scripts/core/army.gd")
	var TPs = load("res://scripts/core/turn_placement.gd")
	var RSs = load("res://scripts/core/ruleset.gd")
	var a0 = Army.new(0, 100)
	var a1 = Army.new(1, 100)
	var tp = TPs.new(a0, a1, first, "snake5", null)
	var pool: int = RSs.prefix_pool(10)
	tp.armies[0].pool = pool
	tp.armies[1].pool = pool
	var guard := 0
	while not tp.done() and guard < 400:
		guard += 1
		var placed := false
		for t in [0, 2, 1, 5]:
			for col in 16:
				for row in 9:
					if not placed and tp.check_place(t, col, row) == "":
						placed = tp.place(t, col, row)
			if placed:
				break
		if not placed or tp.placed_this_turn >= 2:
			tp.end_turn()
	return [tp, pool]

func test_duel_code_v110() -> void:
	var DC = load("res://scripts/game/duel_code.gd")
	var r: Array = _dc_play(1)
	var tp = r[0]
	ok(tp.done() and tp.commands.size() > 4, "打完一局輪流落子", str(tp.commands.size()))
	var code: String = DC.encode(tp, null, [r[1], r[1]], [100, 100])
	var d: Dictionary = DC.decode(code)
	ok(bool(d["ok"]) and not bool(d["mismatch"]), "逐手重放合法", str(d))
	if bool(d["ok"]):
		ok(d["a0"].to_code() == tp.armies[0].to_code() and d["a1"].to_code() == tp.armies[1].to_code(), "重放出同樣兩軍")
	# 竄改：先手換掉 → 第一筆的隊伍對不上
	var body := code.split(".")[1].replace("-", "+").replace("_", "/")
	while body.length() % 4 != 0:
		body += "="
	var j: Dictionary = JSON.parse_string(Marshalls.base64_to_utf8(body))
	var mk := func(jj: Dictionary) -> String:
		var b := Marshalls.utf8_to_base64(JSON.stringify(jj)).replace("+", "-").replace("/", "_").replace("=", "")
		return "NTD1.%s.%s" % [b, b.sha256_text().substr(0, 6)]
	var j1 := j.duplicate(true)
	j1["f"] = 0
	ok(not bool(DC.decode(mk.call(j1))["ok"]), "換先手不收")
	var j2 := j.duplicate(true)
	for mv in j2["m"]:
		if mv[0] == "g" and int(mv[1]) == 0:
			mv[3] = 15   # 藍方擺到紅方半場
			break
	ok(not bool(DC.decode(mk.call(j2))["ok"]), "擺到對方半場不收")
	var j4 := j.duplicate(true)
	j4["m"] = [j["m"][0]]
	ok(not bool(DC.decode(mk.call(j4))["ok"]), "只有第一手（之後還買得起不能跳過）不收")
	var j3 := j.duplicate(true)
	for mv in j3["m"]:
		if mv[0] == "g":
			mv[2] = 99   # 不存在的兵種
			break
	ok(not bool(DC.decode(mk.call(j3))["ok"]), "改一手不收")
	ok(not bool(DC.decode(code + "x")["ok"]) and not bool(DC.decode("NTD1.abc.123456")["ok"]), "壞碼不收")
	var G = load("res://scripts/ui/screens/game_menus.gd")
	ok(G.code_kind(code) == "duel", "代碼頁認得 NTD1")
	var BC = load("res://scripts/game/battle_code.gd")
	ok(not bool(BC.decode(code)["ok"]), "對戰碼照舊不收輪序")

## 1.2.0 §8：擴充規則 v1 欄位預設關，預設值時規則碼與對戰碼的位元組不變（契約 docs/rules-ext-v1.md）。
func test_ext_rules_frozen_v120() -> void:
	var RS0 = load("res://scripts/core/ruleset.gd")
	var r = RS0.standard()
	ok(r.ext_skills == 0 and not r.synergy and not r.ext_on() and RS0.EXT_VERSION == 1, "預設關")
	var c0: String = r.to_code()
	var r2 = r.copy()
	ok(r2.to_code() == c0 and r2.ext_skills == 0, "複製後一樣")
	var rd: Dictionary = RS0.from_code(c0)
	ok(bool(rd["ok"]) and rd["rules"].to_code() == c0 and not rd["rules"].ext_on(), "來回不變、不會冒出擴充")

## 1.2.0 第 7 大類：擴充規則 v1（接拍、急救契約、火矢、協同技）：NTBR7 來回、互斥與唯一寫法、確定性、左右鏡像、各技能真的觸發、預設不變
func test_ext_skills_v120() -> void:
	var RS0 = load("res://scripts/core/ruleset.gd")
	var AIx = load("res://scripts/core/ai_army.gd")
	var Simx = load("res://scripts/core/battle_sim.gd")
	var MCx = load("res://scripts/core/mirror_check.gd")
	var r = RS0.standard()
	r.ext_skills = 2 | 4 | 8
	var c: String = r.to_code()
	ok(c.begins_with("NTBR7."), "擴充規則用 NTBR7")
	var rd: Dictionary = RS0.from_code(c)
	ok(bool(rd["ok"]) and int(rd["rules"].ext_skills) == 14 and rd["rules"].to_code() == c and rd["rules"].equals(r), "NTBR7 來回一致")
	var rs = RS0.standard()
	rs.synergy = true
	rs.adj = true
	var cs: String = rs.to_code()
	ok(not bool(RS0.from_code(cs)["ok"]), "協同技和相鄰陣法同時開的代碼不收（互斥）")
	ok(not r.equals(RS0.standard()), "擴充規則和標準規則不相等")
	var rng := RandomNumberGenerator.new()
	var fired := {"drum": 0, "heal": 0, "fire": 0}
	var mirror_bad := 0
	var det_bad := 0
	var base_same := 0
	for sd in 12:
		rng.seed = 4242 + sd * 7919
		var a0 = AIx.build(0, 100, rng)["army"]
		var a1 = AIx.build(1, 100, rng)["army"]
		var s1 = Simx.new(a0.copy(), a1.copy(), r)
		var hp_drum := false
		while not s1.finished:
			s1.step()
			for e in s1.events:
				if EV_has(e, "beat"):
					fired["drum"] += 1   # 接拍的專用標籤（不能被原本鼓手的 DRUM 事件滿足；Codex cat07 #7）
				if str(e.get("kind", "")) == "heal" and int(e.get("amt", 0)) > 0 and s1.units.any(func(u): return u.id == int(e["src"]) and u.ext_cd > 300):
					fired["heal"] += 1
		for u in s1.units:
			if u.arrows >= 3:
				fired["fire"] += 1
		var s2 = Simx.new(a0.copy(), a1.copy(), r)
		s2.run_to_end()
		if s1.fingerprint != s2.fingerprint or s1.winner != s2.winner:
			det_bad += 1
		if MCx.check_free(a0, a1, r) != "":
			mirror_bad += 1
		var s0 = Simx.new(a0.copy(), a1.copy())
		s0.run_to_end()
		var s0b = Simx.new(a0.copy(), a1.copy(), RS0.standard())
		s0b.run_to_end()
		if s0.fingerprint == s0b.fingerprint:
			base_same += 1
	ok(det_bad == 0, "擴充規則確定性（%d 場不一致）" % det_bad)
	ok(mirror_bad == 0, "擴充規則左右鏡像（%d 場不對稱）" % mirror_bad)
	ok(base_same == 12, "標準規則物件和 null 規則結果相同（擴充欄位預設不影響）")
	# 急救契約：AI 隨機陣很少帶醫者，另擺一個固定場面（藍：3 劍士＋1 醫者；紅：6 劍士）
	var Armyx = load("res://scripts/core/army.gd")
	var b0 = Armyx.new(0, 100)
	for rr in [3, 4, 5]:
		b0.place(0, 5, rr)
	b0.place(7, 3, 4)
	var b1 = Armyx.new(1, 100)
	for rr2 in [2, 3, 4, 5, 6, 7]:
		b1.place(0, 10, rr2)
	var sr = Simx.new(b0.copy(), b1.copy(), r)
	var rescued := 0
	while not sr.finished:
		sr.step()
		for u in sr.units:
			if u.type == 7 and u.ext_cd == 340:
				rescued += 1
	fired["heal"] = rescued
	ok(MCx.check_free(b0, b1, r) == "", "急救場面左右鏡像")
	ok(fired["drum"] > 0 and fired["heal"] > 0 and fired["fire"] > 0, "接拍、急救契約、火矢都有觸發 %s" % str(fired))

func EV_has(e: Dictionary, tag: String) -> bool:
	return (e.get("tags", []) as Array).has(tag)

## 1.2.0 第 7 大類：擴充規則 v1 金標準（tests/golden/ext_v1.json；舊金標準不動）
func test_ext_golden_v120() -> void:
	var RS0 = load("res://scripts/core/ruleset.gd")
	var AIx = load("res://scripts/core/ai_army.gd")
	var Simx = load("res://scripts/core/battle_sim.gd")
	var f := FileAccess.open("res://tests/golden/ext_v1.json", FileAccess.READ)
	ok(f != null, "擴充金標準檔存在")
	if f == null:
		return
	var g: Dictionary = JSON.parse_string(f.get_as_text())
	var bad := 0
	for c in g["cases"]:
		var r = RS0.standard()
		r.ext_skills = int(c["bits"])
		r.synergy = bool(c.get("synergy", false))
		var rng := RandomNumberGenerator.new()
		rng.seed = int(c["seed"])
		if r.synergy:
			var s0 = Simx.new(AIx.build(0, 100, rng)["army"], AIx.build(1, 100, rng)["army"], r)
			s0.run_to_end()
			bad += 0 if str(s0.fingerprint) == str(c["fp"]) else 1
	ok(g["cases"].size() == 29, "金標準 29 場（第 11 大類追加架盾、迴馬、全開各 4 場）")
	# 依產生時的順序重算（同一個 bits 共用一顆 rng 連續抽 4 場）
	var by_bits := {}
	for c2 in g["cases"]:
		if bool(c2.get("synergy", false)):
			continue
		if not by_bits.has(int(c2["bits"])):
			by_bits[int(c2["bits"])] = []
		by_bits[int(c2["bits"])].append(c2)
	for bits in by_bits:
		var r2 = RS0.standard()
		r2.ext_skills = int(bits)
		var rng2 := RandomNumberGenerator.new()
		for c3 in by_bits[bits]:
			rng2.seed = int(c3["seed"])
			var s = Simx.new(AIx.build(0, 100, rng2)["army"], AIx.build(1, 100, rng2)["army"], r2)
			s.run_to_end()
			if str(s.fingerprint) != str(c3["fp"]) or s.winner != int(c3["winner"]):
				bad += 1
	ok(bad == 0, "擴充規則重算和金標準一致（%d 場不同）" % bad)

## 1.2.0 第 7 大類（Codex cat07 #7）：逐條驗機制本身——接拍增傷與消耗、雙鼓手不疊、火矢 t+20／t+40 扣血與擊殺歸屬、
## 致命急救、暈眩一 tick 的醫者不能救、雙醫者分救、救過的 200 tick 內不再救、驗證入口擋互斥。
func _ext_unit(sm, team: int, type: int, nth: int = 0):
	var k := 0
	for u in sm.units:
		if u.team == team and u.type == type:
			if k == nth:
				return u
			k += 1
	return null

func _ext_idx(sm, u) -> int:
	return sm.units.find(u)

func test_ext_mechanics_v120() -> void:
	var RS0 = load("res://scripts/core/ruleset.gd")
	var Simx = load("res://scripts/core/battle_sim.gd")
	var Armyx = load("res://scripts/core/army.gd")
	var MCx = load("res://scripts/core/mirror_check.gd")
	# ── 接拍 ──
	var rb = RS0.standard()
	rb.ext_skills = 2
	var a0 = Armyx.new(0, 100)
	a0.place(8, 3, 4)
	a0.place(8, 3, 6)
	a0.place(0, 5, 5)
	var a1 = Armyx.new(1, 100)
	ok(a1.place(0, 10, 5), "接拍場面：紅方擺得下")
	var sb = Simx.new(a0.copy(), a1.copy(), rb)
	sb._ext_beat(sb.units.size())
	var sw = _ext_unit(sb, 0, 0)
	ok(sw != null and sw.beat, "兩個鼓手 3 格內的劍士拿到拍點加成")
	var hits: Array = [[0, 1, 100, "hit", ["hit"]], [0, 2, 7, "splash", ["splash"]]]
	sb._ext_beat_take(sw, 0, hits)
	ok(int(hits[0][2]) == 120 and int(hits[1][2]) == 8 and not sw.beat and (hits[0][4] as Array).has("beat"), "接拍：這次宣告的每筆 +20%（捨去、含濺射）並用掉 %s" % str(hits))
	sb._ext_beat_take(sw, 0, hits)
	ok(int(hits[0][2]) == 120, "雙鼓手不疊：加成用掉後第二次不再加")
	var far = _ext_unit(sb, 1, 0)
	ok(far != null and not far.beat, "敵方不拿拍點")
	# ── 火矢 ──
	var rf = RS0.standard()
	rf.ext_skills = 8
	var f0 = Armyx.new(0, 100)
	ok(f0.place(2, 0, 4) and f0.place(1, 0, 1), "火矢場面：藍方擺得下")
	var f1 = Armyx.new(1, 100)
	ok(f1.place(1, 15, 4) and f1.place(1, 15, 7), "火矢場面：紅方擺得下")
	var sf = Simx.new(f0.copy(), f1.copy(), rf)
	var ar = _ext_unit(sf, 0, 2)
	var en = _ext_unit(sf, 1, 1, 1)
	sf.ext_fires = [[en.x, en.y, 0, 0, _ext_idx(sf, ar)]]
	en.stun = 100   # 釘住目標（不然 20 tick 內就走出那一格）
	var fire_ticks: Array = []
	var fire_dmg := 0
	for _k in 60:
		sf.step()
		for e in sf.events:
			if EV_has(e, "ext_fire") and int(e.get("tgt", -1)) == en.id:
				fire_ticks.append(sf.tick)
				fire_dmg += int(e["dmg"])
	ok(fire_ticks.size() == 2 and int(fire_ticks[1]) - int(fire_ticks[0]) == 20 and fire_dmg == 10 and sf.ext_fires.is_empty(), "火矢：t+20、t+40 各 5 點，之後移除 %s" % str(fire_ticks))
	var sk = Simx.new(f0.copy(), f1.copy(), rf)
	var ar2 = _ext_unit(sk, 0, 2)
	var en2 = _ext_unit(sk, 1, 1, 1)
	sk.ext_fires = [[en2.x, en2.y, 0, 0, _ext_idx(sk, ar2)]]
	en2.hp = 5
	en2.stun = 100
	for _k2 in 25:
		sk.step()
	ok(not en2.alive and ar2.kills == 1, "火矢燒倒的算射手的擊殺（kills %d）" % ar2.kills)
	# ── 急救契約 ──
	var rr = RS0.standard()
	rr.ext_skills = 4
	var m0 = Armyx.new(0, 100)
	for row in [3, 4, 5]:
		m0.place(0, 5, row)
	m0.place(7, 3, 3)
	m0.place(7, 3, 5)
	var m1 = Armyx.new(1, 100)
	ok(m1.place(0, 13, 4), "急救場面：紅方擺得下")
	ok(MCx.check_free(m0, m1, rr) == "", "雙醫者場面左右鏡像")
	var sr = Simx.new(m0.copy(), m1.copy(), rr)
	var s_a = _ext_unit(sr, 0, 0, 0)
	var med_a = _ext_unit(sr, 0, 7, 0)
	var med_b = _ext_unit(sr, 0, 7, 1)
	s_a.hp = 0   # 致命：死亡判定前救起
	sr.step()
	var fired_n := int(med_a.ext_cd == 340) + int(med_b.ext_cd == 340)
	ok(s_a.alive and s_a.hp == s_a.max_hp * 30 / 100 and fired_n == 1, "致命傷被救回 30%，只有一個醫者出手（hp %d、出手 %d）" % [s_a.hp, fired_n])
	var saver = med_a if med_a.ext_cd == 340 else med_b
	ok(saver.stun == 40 or saver.stun == 39, "出手的醫者停手 40 tick（stun %d）" % saver.stun)
	s_a.hp = 0
	sr.step()
	ok(not s_a.alive, "救過的 200 tick 內不再救（另一個醫者也不救）")
	var sr2 = Simx.new(m0.copy(), m1.copy(), rr)
	var x_a = _ext_unit(sr2, 0, 0, 0)
	var x_b = _ext_unit(sr2, 0, 0, 2)
	x_a.hp = 1
	x_b.hp = 1
	sr2.step()
	var ma = _ext_unit(sr2, 0, 7, 0)
	var mb = _ext_unit(sr2, 0, 7, 1)
	ok(ma.ext_cd == 340 and mb.ext_cd == 340 and x_a.saved_at >= 0 and x_b.saved_at >= 0, "兩個醫者分別救兩個低血友軍")
	var sr3 = Simx.new(m0.copy(), m1.copy(), rr)
	var y_a = _ext_unit(sr3, 0, 0, 0)
	for mm in [_ext_unit(sr3, 0, 7, 0), _ext_unit(sr3, 0, 7, 1)]:
		mm.stun = 1
	y_a.hp = 1
	sr3.step()
	var none_yet: bool = y_a.saved_at < 0
	sr3.step()
	ok(none_yet and y_a.saved_at >= 0, "暈眩 1 tick 的醫者這一 tick 不能救、下一 tick 才救")
	# ── 驗證入口 ──
	var rv = RS0.standard()
	rv.synergy = true
	rv.adj = true
	ok(rv.validate().has("rr_code_body"), "validate 擋協同技＋相鄰陣法")
	var rv2 = RS0.standard()
	rv2.ext_skills = 32
	ok(rv2.validate().has("rr_code_body"), "validate 擋擴充位元超出範圍")
	var rd0 = RS0.standard()
	rd0.ext_skills = 8
	ok(rd0.sim_digest() != RS0.standard().sim_digest(), "模擬摘要含擴充規則")

## 1.2.0 第 11 大類：擴充 v1 位元 0「架盾」、位元 4「迴馬」（契約 §3）
func test_ext_guard_ride_v120() -> void:
	var RS0 = load("res://scripts/core/ruleset.gd")
	var Simx = load("res://scripts/core/battle_sim.gd")
	var Armyx = load("res://scripts/core/army.gd")
	var AIx = load("res://scripts/core/ai_army.gd")
	var MCx = load("res://scripts/core/mirror_check.gd")
	var rg = RS0.standard()
	rg.ext_skills = 1
	ok(rg.is_sandbox(), "擴充規則只在沙盒（不記紀錄）")
	var g0 = Armyx.new(0, 100)
	ok(g0.place(1, 5, 4), "架盾場面：藍盾兵")
	var g1 = Armyx.new(1, 100)
	ok(g1.place(2, 10, 4) and g1.place(2, 10, 6), "架盾場面：紅弓箭手兩隻")
	var sg = Simx.new(g0.copy(), g1.copy(), rg)
	var sh = _ext_unit(sg, 0, 1)
	var a0 = _ext_unit(sg, 1, 2, 0)
	var a1 = _ext_unit(sg, 1, 2, 1)
	var si := _ext_idx(sg, sh)
	sh.fx = 1000
	sh.fy = 0
	# 觸發：前方 2 格內有遠程瞄準 → 架 60；3 格外不架
	a0.x = sh.x + 1800; a0.y = sh.y; a0.target = si
	a1.x = sh.x + 5000; a1.y = sh.y; a1.target = si
	sg._ext_brace_arm(sg.units.size())
	ok(sh.brace_t == 60, "前方 2 格內的弓箭手瞄準 → 架盾 60 tick")
	sh.brace_t = 0
	a0.x = sh.x + 3000
	sg._ext_brace_arm(sg.units.size())
	ok(sh.brace_t == 0, "3 格外不架")
	a0.x = sh.x - 1800
	sg._ext_brace_arm(sg.units.size())
	ok(sh.brace_t == 0, "背後來的不架")
	# 擋：盾面 ±60° 內兩筆只擋一筆（鏡像不變鍵挑來源），擋完結束、冷卻 120
	a0.x = sh.x + 1800; a0.y = sh.y
	a1.x = sh.x + 1800; a1.y = sh.y + 600
	sh.brace_t = 40
	var hits: Array = [[_ext_idx(sg, a1), si, 30, "arrow", ["arrow"]], [_ext_idx(sg, a0), si, 30, "arrow", ["arrow"]]]
	sg._ext_brace_block(hits)
	var zeroed := 0
	for h in hits:
		if int(h[2]) == 0 and (h[4] as Array).has("ext_guard"):
			zeroed += 1
	ok(zeroed == 1 and int(hits[1][2]) == 0, "兩發只擋一發，挑列小的來源 %s" % str(hits))
	ok(sh.brace_t == 0 and sh.ext_cd == 120, "擋完結束、冷卻 120")
	sh.brace_t = 40
	sh.ext_cd = 0
	var side: Array = [[_ext_idx(sg, a0), si, 30, "arrow", ["arrow"]]]
	a0.x = sh.x + 300; a0.y = sh.y + 1800   # 側面約 80°
	sg._ext_brace_block(side)
	ok(int(side[0][2]) == 30 and sh.brace_t == 40, "盾面 ±60° 外不擋")
	var fire: Array = [[_ext_idx(sg, a0), si, 5, "hit", ["ext_fire"]]]
	a0.x = sh.x + 1800; a0.y = sh.y
	sg._ext_brace_block(fire)
	ok(int(fire[0][2]) == 5, "小火不算遠程一發")
	# 迴馬：退一格、給再衝；退路被佔不退
	var rr = RS0.standard()
	rr.ext_skills = 16
	var c0 = Armyx.new(0, 100)
	ok(c0.place(3, 6, 4) and c0.place(0, 5, 6) and c0.place(3, 6, 6), "迴馬場面：藍騎兵兩隻＋劍士")
	var c1 = Armyx.new(1, 100)
	ok(c1.place(0, 12, 4), "迴馬場面：紅劍士")
	var sc = Simx.new(c0.copy(), c1.copy(), rr)
	var cv = _ext_unit(sc, 0, 3, 0)
	var cv2 = _ext_unit(sc, 0, 3, 1)
	var x0: int = cv.x
	cv.ride = 1
	cv2.ride = 1   # 後面一格有劍士 → 被佔
	sc._ext_ride(sc.units.size())
	ok(cv.x == x0 - 1000 and cv.ride_t == 60 and cv.ride == 0, "衝鋒命中後退 1 格、60 tick 再衝")
	ok(cv2.x == 6500 and cv2.ride_t == 0 and cv2.ride == 0, "退路被佔不退 x=%d" % cv2.x)
	# 整場：確定性、鏡像、兩個都有觸發
	var both = RS0.standard()
	both.ext_skills = 1 | 16
	var rng := RandomNumberGenerator.new()
	var got := {"guard": 0, "ride": 0}
	var det_bad := 0
	var mir_bad := 0
	for sd in 16:
		rng.seed = 7070 + sd * 7919
		var b0 = AIx.build(0, 100, rng)["army"]
		var b1 = AIx.build(1, 100, rng)["army"]
		var s1 = Simx.new(b0.copy(), b1.copy(), both)
		while not s1.finished:
			s1.step()
			for e in s1.events:
				if EV_has(e, "ext_guard"):
					got["guard"] += 1
				if EV_has(e, "ext_ride"):
					got["ride"] += 1
		var s2 = Simx.new(b0.copy(), b1.copy(), both)
		s2.run_to_end()
		if s1.fingerprint != s2.fingerprint:
			det_bad += 1
		if MCx.check_free(b0, b1, both) != "":
			mir_bad += 1
	ok(det_bad == 0 and mir_bad == 0, "架盾＋迴馬：確定性 %d、鏡像 %d 場不符" % [det_bad, mir_bad])
	ok(int(got["guard"]) > 0 and int(got["ride"]) > 0, "整場有觸發 %s" % str(got))
