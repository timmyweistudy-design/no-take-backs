extends "res://tests/test_base.gd"
const F8 = preload("res://scripts/core/fantasy_defs.gd")
const BC = preload("res://scripts/game/battle_code.gd")
const CXF = preload("res://scripts/game/codex.gd")
const ROS = preload("res://scripts/game/roster.gd")
const M9 = preload("res://scripts/core/imath.gd")
const PRE = preload("res://scripts/game/presets.gd")
const SaveS = preload("res://scripts/game/save.gd")


## 擺一隊：spec＝[[type, x（自己視角）, y]]，team 0／1。座標單位 1000＝1 格。
const RS_ROSTER = preload("res://scripts/game/roster.gd")

func _army(team: int, spec: Array, r = null):
	var a = Army.new(team, 400)
	a.pool = RSET.full_pool()
	a.unit_cap = 60
	if r != null:
		a.deploy = "free"
		a.spacing = 800
		a.depth = 15800
	for s in spec:
		var x: int = s[1] if team == 0 else Army.W - int(s[1])
		a.units.append({"type": int(s[0]), "x": x, "y": int(s[2])})
	a.deploy = "free"
	return a


func _sim(b: Array, r: Array):
	return Sim.new(_army(0, b), _army(1, r))


func _run(s, ticks := 2000) -> Dictionary:
	var kinds := {}
	while not s.finished and s.tick < ticks:
		s.step()
		for e in s.events:
			kinds[str(e.get("kind", ""))] = int(kinds.get(str(e.get("kind", "")), 0)) + 1
	return kinds


func test_fantasy_legacy_v8() -> void:
	ok(D.COUNT == 10 and D.total() == 20, "F8：COUNT 維持 10、總數 20")
	ok(D.data_digest() == "288176c5c9af5a79", "F8：舊數值摘要沒變", D.data_digest())
	ok(D.digest_v8() != D.data_digest(), "F8：新兵場次用另一個摘要")
	ok(RSET.all_pool() == 1023 and RSET.full_pool() == 1048575, "F8：舊卡池遮罩沒變、新遮罩 20 種")
	var old_sim := Sim.new(army_from(0, [[D.SWORD, 5, 4]]), army_from(1, [[D.SWORD, 5, 4]]))
	ok(not old_sim.v8 and old_sim.units.size() == 2, "F8：只有舊兵不開新邏輯、不建預留單位")
	var new_sim = _sim([[F8.SLIME, 5000, 4000], [D.SWORD, 3000, 4000]], [[D.SWORD, 5000, 4000]])
	ok(new_sim.v8 and new_sim.units.size() == 5, "F8：史萊姆預留 2 隻", str(new_sim.units.size()))
	ok(D.is_combat(D.SWORD) and not D.is_combat(F8.SPORE) and not D.is_combat(F8.SHEEP) and not D.is_combat(F8.MIMIC) and not D.is_combat(F8.SPRITE) and D.is_combat(F8.SLIME), "F8：奇襲兵與支援兵不算戰鬥兵")


func test_fantasy_rules_v8() -> void:
	# 孢子菇
	var s = _sim([[F8.SPORE, 7000, 4000], [D.SWORD, 1000, 8000]], [[D.SWORD, 7000, 4000]])
	var k := _run(s, 300)
	ok(k.has("poison"), "孢子菇：走進圈內會中毒")
	ok(s.units[0].x == 7000 or s.units[1].x == 7000, "孢子菇：不會被推動")
	# 爆爆羊
	s = _sim([[F8.SHEEP, 6000, 4000], [D.SWORD, 1000, 1000]], [[D.SHIELD, 6000, 3500], [D.SHIELD, 6000, 4500]])
	k = _run(s, 400)
	ok(int(k.get("blast", 0)) >= 2, "爆爆羊：撞到就炸、範圍內都受傷", str(k))
	var sheep = null
	for u in s.units:
		if u.type == F8.SHEEP:
			sheep = u
	ok(sheep != null and not sheep.alive and sheep.exploded, "爆爆羊：炸完就沒了")
	# 羊爆次數有上限
	var many: Array = []
	for i in 8:
		many.append([F8.SHEEP, 7000, 3000 + i * 300])
	s = _sim(many + [[D.SWORD, 1000, 1000]], [[D.PIKE, 7500, 4000]])
	s.units.size()
	var most := 0
	while not s.finished and s.tick < 200:
		s.step()
		var n := 0
		for e in s.events:
			if str(e.get("kind", "")) == EVS.BLAST and e.has("dmg") and s.unit_by_id(int(e["tgt"])).type == D.PIKE:
				n += 1
		most = maxi(most, n)
	ok(most <= F8.BLAST_CAP, "爆爆羊：一隻一 tick 最多吃 %d 次" % F8.BLAST_CAP, str(most))
	# 半路被打死會連友軍一起炸
	s = _sim([[F8.SHEEP, 3000, 4000], [D.SWORD, 3000, 4600]], [[D.ARCHER, 8000, 4000], [D.ARCHER, 8000, 3000], [D.ARCHER, 8000, 5000], [D.ARCHER, 8000, 4500], [D.ARCHER, 8000, 3500]])
	for su in s.units:
		if su.type == F8.SHEEP:
			su.hp = 1
	var friend := false
	while not s.finished and s.tick < 500 and not friend:
		s.step()
		for e in s.events:
			if str(e.get("kind", "")) == EVS.BLAST and e.has("dmg"):
				if s.unit_by_id(int(e["tgt"])).team == 0:
					friend = true
	ok(friend, "爆爆羊：半路被打死會波及友軍")
	# 寶箱怪
	s = _sim([[F8.MIMIC, 6000, 4000], [D.SWORD, 1000, 1000]], [[D.ARCHER, 2000, 4000]])
	s.step()
	ok(s.units[1].hidden or s.units[0].hidden, "寶箱怪：開場偽裝")
	s = _sim([[F8.MIMIC, 6000, 4000], [D.SWORD, 1000, 1000]], [[D.CAVALRY, 9000, 4000]])
	k = _run(s, 600)
	ok(k.has("mimic_open") and k.has("bite"), "寶箱怪：敵人靠近就現身咬", str(k))
	s = _sim([[F8.MIMIC, 2000, 4000]], [[D.SWORD, 9000, 4000]])
	k = _run(s, 800)
	ok(k.has("mimic_open"), "寶箱怪：只剩自己會現身，不會僵局")
	# 史萊姆
	s = _sim([[F8.SLIME, 6000, 4000]], [[D.SWORD, 6000, 3000], [D.SWORD, 6000, 5000], [D.SWORD, 6000, 4000]])
	k = _run(s, 800)
	ok(int(k.get("split", 0)) == 2, "史萊姆：死了生 2 隻", str(k))
	ok(s.power(0) == 0, "史萊姆：小史萊姆戰力 0，時間到不灌水")
	# 幽靈
	s = _sim([[F8.GHOST, 4000, 4000]], [[D.SHIELD, 6000, 4000], [D.ARCHER, 2000, 4000]])
	var went_past := false
	while not s.finished and s.tick < 400:
		s.step()
		var g = s.units[0] if s.units[0].type == F8.GHOST else s.units[1]
		if g.target >= 0 and s.units[g.target].type == D.ARCHER:
			went_past = true
	ok(went_past, "幽靈：穿過盾兵去找弓箭手，不受嘲諷")
	s = _sim([[F8.GHOST, 7000, 4000], [D.SWORD, 1000, 1000]], [[D.ARCHER, 8000, 4000]])
	var ghost_hit := 0
	var gu = null
	for u2 in s.units:
		if u2.type == F8.GHOST:
			gu = u2
	while not s.finished and s.tick < 200:
		s.step()
		ghost_hit = gu.max_hp - gu.hp
	ok(ghost_hit == 0, "幽靈：箭打不到", str(ghost_hit))
	# 巫毒
	s = _sim([[F8.DOLL, 7000, 4000], [D.SWORD, 1000, 1000]], [[D.SWORD, 8000, 4000], [D.ARCHER, 2000, 7000]])
	k = _run(s, 300)
	ok(k.has("voodoo"), "巫毒：受的傷轉給綁定的敵人", str(k))
	var dl = null
	for u3 in s.units:
		if u3.type == F8.DOLL:
			dl = u3
	ok(dl.link == -1 or s.units[dl.link].type == D.SWORD, "巫毒：綁正前方，不是遠處的弓手")
	# 兩隻娃娃互綁不會遞迴
	s = _sim([[F8.DOLL, 7500, 4000], [D.SWORD, 7000, 3000]], [[F8.DOLL, 8000, 4000], [D.SWORD, 8000, 3000]])
	k = _run(s, 1800)
	ok(s.finished, "巫毒：兩隻互綁會正常結束", str(s.tick))
	# 沙漏
	s = _sim([[F8.SPRITE, 6000, 4000], [D.SWORD, 7000, 3500], [D.SWORD, 7000, 4500]], [[D.BERSERKER, 8000, 3500], [D.BERSERKER, 8000, 4500]])
	k = _run(s, 700)
	ok(int(k.get("timestop", 0)) == 1, "沙漏：殘血時放一次時停", str(k))
	# 骷髏法師
	s = _sim([[F8.BONE, 4000, 4000], [D.SWORD, 7000, 3500], [D.SWORD, 7000, 4500]], [[D.BERSERKER, 8000, 3500], [D.BERSERKER, 8000, 4500], [D.BERSERKER, 8000, 4000]])
	k = _run(s, 900)
	ok(k.has("raise"), "骷髏法師：把屍體變骷髏", str(k))
	var back := 0
	for u4 in s.units:
		if u4.type == F8.SKELETON and not u4.dormant:
			back += 1
	ok(back >= 1 and back <= F8.BONE_KIDS, "骷髏法師：最多 %d 隻" % F8.BONE_KIDS, str(back))
	# 吸塵貓
	s = _sim([[F8.CAT, 7000, 4000], [D.SWORD, 7000, 1000]], [[D.ARCHER, 2000, 4000]])
	var ar = null
	for u5 in s.units:
		if u5.type == D.ARCHER:
			ar = u5
	var toward := false
	while not s.finished and s.tick < 200:
		s.step()
		if ar.pull_t > 0 and ar.pull_x < 0:
			toward = true
	ok(toward, "吸塵貓：敵人被往貓這邊拉")
	# 小石魔
	s = _sim([[F8.GOLEM, 7000, 4000]], [[D.SWORD, 8000, 4000], [D.SWORD, 8000, 3000], [D.SWORD, 8000, 5000], [D.BERSERKER, 8000, 4500], [D.BERSERKER, 8000, 3500], [D.ASSASSIN, 8000, 4200]])
	var saw_zone := false
	k = {}
	while not s.finished and s.tick < 1800:
		s.step()
		saw_zone = saw_zone or not s.zones.is_empty()
		for e2 in s.events:
			k[str(e2.get("kind", ""))] = 1
	ok(k.has("stomp") and k.has("rock") and saw_zone, "小石魔：拍地、死後留碎石區", str(k.keys()))


func test_fantasy_regress_v8() -> void:
	# Codex r1：最後一隻羊被殺，要等它爆完才判勝負
	var s = _sim([[F8.SHEEP, 7000, 4000]], [[D.ARCHER, 8000, 4000]])
	for u in s.units:
		if u.type == F8.SHEEP:
			u.hp = 1
	var k := _run(s, 200)
	ok(int(k.get("blast", 0)) >= 1, "羊：最後一隻被殺仍然會爆", str(k))
	# 純奇襲卡池不合法；末手不能只留奇襲兵
	ok(not RSET.has_combat((1 << F8.SPORE) | (1 << F8.SHEEP) | (1 << F8.MIMIC)), "卡池：只有奇襲兵不算有戰鬥兵")
	var rr = free_rules(800, 6000, 0)
	rr.pool = [(1 << F8.SPORE) | (1 << F8.SHEEP), (1 << F8.SPORE) | (1 << F8.SHEEP)]
	ok("rr_no_combat" in rr.validate(), "規則：純奇襲卡池不能開戰", str(rr.validate()))
	# 關掉所有技能的規則代碼讀得回來
	var r3 = free_rules(800, 6000, 0)
	r3.pool = [RSET.full_pool() ^ 1023, RSET.full_pool() ^ 1023]
	r3.skills_off = RSET.SKILLS + F8.SKILLS
	ok(RSET.from_code(r3.to_code())["ok"], "規則代碼：關 22 個技能也讀得回來", str(RSET.from_code(r3.to_code()).get("why", "")))
	# 兩隻貓同時吸、兩隻寶箱同時觸發：鏡像對稱
	var why: String = MC.check_free(_army(0, [[F8.CAT, 6000, 3000], [F8.CAT, 6000, 5000], [F8.MIMIC, 7000, 4000], [F8.MIMIC, 7000, 4800], [D.SWORD, 1000, 1000]]), _army(1, [[F8.CAT, 6000, 3000], [F8.CAT, 6000, 5000], [F8.MIMIC, 7000, 4000], [F8.MIMIC, 7000, 4800], [D.SWORD, 1000, 1000]]), null)
	ok(why == "", "鏡像：多貓多箱同時放招", why)
	# 時停前搖被打斷，之後還能放
	var sp = _sim([[F8.SPRITE, 7000, 4000], [D.SWORD, 7500, 3500], [D.SWORD, 7500, 4500]], [[D.SWORD, 8000, 3500], [D.SWORD, 8000, 4500]])
	var spr = null
	for u2 in sp.units:
		if u2.type == F8.SPRITE:
			spr = u2
	spr.windup = 5
	spr.stun = 3
	sp.step()
	ok(not spr.used and spr.windup == 0, "時停：前搖被打斷不算用掉")


## 鏡像：隨機新舊混編，逐 tick 完全對稱（含生兵）。
func test_fantasy_mirror_v8() -> void:
	# 第 3 輪：兩隻石魔同 tick 把貼邊的敵人往兩邊推。格子場鏡像時兵的順序相反，逐筆夾邊的落點就不對稱
	var e0 = Sim.new(_army(0, [[F8.GOLEM, 500, 2000], [F8.GOLEM, 1500, 2000]]), _army(1, [[F8.GHOST, 15300, 2000]]), null)
	var e1 = Sim.new(_army(0, [[F8.GHOST, 15300, 2000]]), _army(1, [[F8.GOLEM, 1500, 2000], [F8.GOLEM, 500, 2000]]), null)
	var stomped := false
	var edge_ok := true
	var stomps := 0
	for _i in 300:
		# 固定位置等拍地，才測得到「同一 tick、同一位置」
		for sm in [[e0, false], [e1, true]]:
			var gs: Array = []
			for u in sm[0].units:
				if u.type == F8.GOLEM:
					gs.append(u)
				elif u.type == F8.GHOST:
					u.x = 15300 if sm[1] else 700
					u.y = 2000
			gs[0].x = 14500 if sm[1] else 500
			gs[1].x = 15500 if sm[1] else 1500
			gs[0].y = 2000
			gs[1].y = 2000
		e0.step()
		e1.step()
		var g0 = null
		var g1 = null
		for u in e0.units:
			if u.type == F8.GHOST:
				g0 = u
		for u in e1.units:
			if u.type == F8.GHOST:
				g1 = u
		stomps = 0
		for ev in e0.events:
			if ev["kind"] == "stomp":
				stomps += 1
		if stomps >= 2:
			stomped = true
			edge_ok = g0.x == Army.W - g1.x
			break
	ok(stomped and edge_ok, "鏡像：兩隻石魔同 tick 擊退貼邊敵人，順序不影響落點", "%s %s %d" % [stomped, edge_ok, stomps])
	var rng := RandomNumberGenerator.new()
	rng.seed = 880011
	var r = free_rules(800, 6000, 0)
	r.pool = [RSET.full_pool(), RSET.full_pool()]
	var bad := ""
	for n in 12:
		var a: Array = [_rand_side(rng), _rand_side(rng)]
		var why: String = MC.check_free(_army(0, a[0]), _army(1, a[1]), null)
		if why != "":
			bad = "第 %d 組：%s" % [n, why]
			break
	ok(bad == "", "鏡像：新舊混編 12 組逐 tick 對稱", bad)


func _rand_side(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var used := {}
	for i in 12:
		var x := rng.randi_range(1, 11) * 500
		var y := rng.randi_range(1, 16) * 500
		var k := x * 100000 + y
		if used.has(k):
			continue
		used[k] = true
		out.append([rng.randi_range(0, 19), x, y])
	if not used.has(500 * 100000 + 500):
		out.append([D.SWORD, 500, 500])
	return out


func test_fantasy_codes_v8() -> void:
	var a = Army.new(0, 100)
	a.pool = RSET.full_pool()
	ok(a.place(F8.SLIME, 3, 4) and a.place(F8.GOLEM, 2, 2) and a.place(D.SWORD, 5, 4), "代碼：格子可以擺新兵")
	var code: String = a.to_code()
	ok(code.begins_with("NTB6."), "代碼：用到新兵才用 NTB6", code.substr(0, 5))
	var b = Army.new(0, 100)
	b.pool = RSET.full_pool()
	ok(b.load_code(code) == "" and b.units.size() == 3 and int(b.units[1]["type"]) == F8.GOLEM, "代碼：NTB6 讀得回來")
	var old = Army.new(0, 100)
	old.place(D.SWORD, 5, 4)
	ok(old.to_code().begins_with("NTB1."), "代碼：只有舊兵維持 NTB1")
	var r = free_rules(800, 6000, 0)
	r.pool = [RSET.full_pool() >> 10 << 10, RSET.full_pool() >> 10 << 10]
	var c = Army.new(0, 100)
	c.apply_rules(r, 0)
	ok(c.place_xy(F8.SLIME, 2000, 2000) and c.place_xy(F8.GHOST, 3000, 3000), "代碼：自由模式可以擺新兵", str(c.units))
	var cc: String = c.to_code()
	var d = Army.new(0, 100)
	d.apply_rules(r, 0)
	ok(d.load_code(cc) == "" and d.units.size() == 2 and d.pos_of(d.units[0]) == c.pos_of(c.units[0]), "代碼：NTB6 自由座標讀得回來", cc)
	# 規則代碼
	var rc: String = r.to_code()
	ok(rc.begins_with("NTBR3."), "規則代碼：新兵卡池用 NTBR3", rc.substr(0, 6))
	var rd: Dictionary = RSET.from_code(rc)
	ok(rd["ok"] and rd["rules"].pool_of(0) == r.pool_of(0) and rd["rules"].is_free(), "規則代碼：NTBR3 讀得回來", str(rd.get("why", "")))
	var r2 = free_rules(800, 6000, 0)
	ok(RSET.from_code(r2.to_code())["ok"] and r2.to_code().begins_with("NTBR"), "規則代碼：舊規則不受影響")
	var over = free_rules(800, 6000, 0)
	over.pool = [RSET.full_pool(), RSET.full_pool()]
	ok("rr_roster_over" in over.validate(), "規則：一局最多 10 種")
	# 對戰代碼
	var e = Army.new(1, 100)
	e.apply_rules(r, 1)
	e.place_xy(F8.SLIME, 14000, 2000)
	var bc: String = BC.encode(c, e, r)
	ok(bc.begins_with("NTB4."), "對戰代碼：用到新兵是 NTB4", bc.substr(0, 5))
	var dec: Dictionary = BC.decode(bc)
	ok(dec["ok"] and not dec["mismatch"], "對戰代碼：NTB4 讀得回來、版本相符", str(dec.get("why", "")))
	var w1 = Sim.new(dec["a0"], dec["a1"], dec["rules"])
	w1.run_to_end()
	var w2 = Sim.new(c.copy(), e.copy(), r)
	w2.run_to_end()
	ok(w1.fingerprint == w2.fingerprint, "對戰代碼：重播同一場")


func test_fantasy_game_v8() -> void:
	# 第 3 輪：奇幻軍是娛樂變體也要能拿成就；爆炸次數只算演出那筆，不算逐目標傷害
	var GS = load("res://scripts/ui/game_screens.gd")
	var g = GS.new()
	var saved: Dictionary = SaveS.data.duplicate(true)
	var was_locked: bool = SaveS.data_locked
	SaveS.data_locked = true   # 測試不能寫到真的存檔
	SaveS.data["achievements"] = []
	g.mode = g.Mode.VS_AI
	g.rules = PRE.make("fantasy", "ai", ROS.mask())
	var fa = Army.new(0, 100)
	fa.pool = RSET.full_pool()
	fa.units.append({"type": F8.SHEEP, "x": 2000, "y": 2000})
	g.armies = [fa, fa]
	g.ev_count = {"blast0": 4, "blast_fx0": 4, "raise0": 2}
	g._v8_achievements(0)
	var a0: Array = SaveS.data["achievements"].duplicate()
	ok(a0 == ["FANTASY_WIN"], "成就：奇幻預設獲勝給傭兵公會；4 次爆炸不給 BOOM_5", str(a0))
	g.ev_count = {"blast0": 40, "blast_fx0": 5, "raise0": 3}
	g._v8_achievements(0)
	ok("BOOM_5" in SaveS.data["achievements"] and "RAISE_3" in SaveS.data["achievements"], "成就：爆炸 5 次、復活 3 次", str(SaveS.data["achievements"]))
	# 第 3 輪：遠征名單；存檔被改壞就退回
	SaveS.data["unlock_games"] = 99
	SaveS.data["gauntlet_pool"] = (1 << F8.SHEEP) | (1 << F8.SLIME)
	ok(g._gauntlet_pool() == (1 << F8.SHEEP) | (1 << F8.SLIME), "遠征：用開打前選的軍隊", str(g._gauntlet_pool()))
	SaveS.data["gauntlet_pool"] = "壞"
	ok(RSET.has_combat(g._gauntlet_pool()), "遠征：存檔壞掉退回能打的名單")
	SaveS.data["gauntlet_pool"] = (1 << 20) - 1
	ok(RSET.pool_count(g._gauntlet_pool()) <= RSET.ROSTER_MAX, "遠征：超過 10 種不採用")
	g.free()
	SaveS.data = saved
	SaveS.data_locked = was_locked
	ok(CXF.validate().is_empty(), "圖鑑：20 種資料完整", str(CXF.validate()))
	# 每個新技能的小劇場都真的會觸發
	for sk in ["spore_poison", "sheep_blast", "mimic_bite", "slime_split", "ghost_phase", "doll_voodoo", "sprite_stop", "bone_raise", "cat_vacuum", "golem_stomp"]:
		var s = CXF.demo_sim(sk)
		var want: String = CXF.skill(sk)["demo"]["expect"]
		var hit := false
		var lim: int = int(CXF.skill(sk)["demo"]["ticks"])
		while not s.finished and s.tick < lim and not hit:
			s.step()
			for e in s.events:
				if e.get("tags", []).has(want):
					hit = true
		ok(hit, "圖鑑小劇場 %s 會出現 %s" % [sk, want], "tick %d" % s.tick)
	var dm: int = ROS.mask(true)
	ok(RSET.pool_count(dm) == 8 and RSET.has(dm, F8.SHEEP) and not RSET.has(dm, 7), "試玩版：舊 7 種＋爆爆羊（非連號）")
	ok(not ROS.available(F8.SLIME, true) and ROS.available(F8.SHEEP, true), "試玩版：其他奇幻軍沒有")
	# 預設
	var std = PRE.make("standard", "ai", ROS.mask())
	ok(std.pool_of(0) == 1023, "標準規則仍是舊 10 種", str(std.pool_of(0)))
	var fan = PRE.make("fantasy", "ai", ROS.mask())
	ok(fan.pool_of(0) == RSET.full_pool() - 1023 and fan.validate().is_empty(), "奇幻兵團：全開時是 10 種奇幻軍", str(fan.validate()))
	var early = PRE.make("fantasy", "ai", 1023 | (1 << 10))
	ok(RSET.pool_count(early.pool_of(0)) == 10 and early.validate().is_empty(), "奇幻兵團：剛解鎖時由舊兵補", str(early.validate()))
	ok(PRE.badge(fan, "ai") == PRE.BADGE_FUN, "奇幻兵團：驗收前是娛樂變體")
	# AI 會用新兵、都守硬上限、一定有戰鬥兵
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var used := {}
	var bad := ""
	for n in 60:
		var a = AI.build(1, 100, rng, -1, fan.pool_of(1), fan)["army"]
		for t in D.total():
			var cnt: int = a.count_of(t)
			if D.hard_cap(t) > 0 and cnt > D.hard_cap(t):
				bad = "超過硬上限 %d" % t
		if not a.has_combat():
			bad = "沒有戰鬥兵：" + str(a.units)
		for u in a.units:
			used[int(u["type"])] = true
	ok(bad == "", "AI：奇幻軍守規則", bad)
	ok(used.size() >= 8, "AI：至少用到 8 種奇幻軍", str(used.keys()))
	# 硬上限
	var h = Army.new(0, 400)
	h.pool = RSET.full_pool()
	h.unit_cap = 40
	var placed := 0
	for r2 in 9:
		for c2 in 6:
			if h.place(F8.GOLEM, c2, r2):
				placed += 1
	ok(placed == F8.HARD_CAP[F8.GOLEM], "硬上限：石魔最多 3 隻", str(placed))
	var h2 = Army.new(0, 100)
	h2.pool = RSET.full_pool()
	h2.place(F8.SHEEP, 3, 3)
	ok(not h2.has_combat(), "只有奇襲兵不算有戰鬥兵")

## 總驗收查到：幽靈「×1.5」、骷髏法師「三成血」是調數值前的舊字，圖鑑手寫欄位不會自動跟著變
func test_fantasy_codex_text_matches_stats() -> void:
	var units: Dictionary = {}
	for u in CXF.data()["units"]:
		units[int(u["id"])] = u
	var bad: Array = []
	var times := RegEx.create_from_string("×\\d")
	for id in range(10, 20):
		for k in ["role", "good", "bad", "story", "veteran", "tagline"]:
			for lang in ["zh", "en"]:
				if times.search(str(units[id]["%s_%s" % [k, lang]])) != null:
					bad.append("%d %s_%s 手寫了倍率" % [id, k, lang])
	ok(bad.is_empty(), "新兵圖鑑手寫文字不寫死倍率（倍率只放會自動換值的技能說明）", str(bad))
	ok(F8.BONE_HP_PCT == 50 and str(units[17]["story_zh"]).contains("一半") and str(units[17]["story_en"]).contains("half"), "骷髏法師故事的血量和 BONE_HP_PCT 一致")
	ok(F8.SPRITE_STUN == 50 and str(units[16]["story_zh"]).contains("兩秒半") and str(units[16]["story_en"]).contains("two and a half"), "沙漏精靈故事的秒數和 SPRITE_STUN 一致")

## 第十二輪：吸塵貓把人拉向自己。貼身的不能被推開，貓自己不動。
func test_cat_pull() -> void:
	var dist := func(s, a, b) -> int:
		return M9.isqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y))
	# 貼身的敵人（在貓前面 0.8 格）：吸完不能比原本遠
	var s = _sim([[F8.CAT, 7000, 4500]], [[D.ARCHER, 6000, 4500], [D.SHIELD, 14000, 800]])   # 弓手站著射，距離 3 格
	var cat = null
	var e = null
	for u in s.units:
		if u.type == F8.CAT:
			cat = u
		elif e == null and u.type == D.ARCHER:
			e = u
	var max_d := 0
	var cat_x0: int = cat.x
	var pulled := false
	for i in 300:
		if s.finished:
			break
		var before: int = dist.call(s, cat, e)
		var pt0: int = e.pull_t
		s.step()
		if e.pull_t > 0 or pt0 > 0:
			pulled = true
			var after: int = dist.call(s, cat, e)
			max_d = maxi(max_d, after - before)
	ok(pulled, "貓有吸到人")
	ok(max_d <= 0, "被吸的時候只會靠近貓，不會被推開", str(max_d))
	# 已經貼身的不拉、不定身
	var adj = _sim([[F8.CAT, 7000, 4500]], [[D.SHIELD, 8300, 4500]])   # 距離 0.7 格
	var adj_pulled := false
	for i2 in 200:
		if adj.finished:
			break
		adj.step()
		for u6 in adj.units:
			if u6.team == 1 and u6.pull_t > 0:
				adj_pulled = true
	ok(not adj_pulled, "貼身的敵人不會被吸（也不會被推開）")
	# 遠處的人：一次拉得明顯，而且貓自己不被拉走
	var far = _sim([[F8.CAT, 3000, 4500], [D.SHIELD, 3000, 800]], [[D.SHIELD, 7000, 4500], [D.SHIELD, 7000, 2500], [D.SHIELD, 7000, 6500], [D.ARCHER, 7300, 8000]])
	var fc = null
	var ens: Array = []
	for u in far.units:
		if u.type == F8.CAT:
			fc = u
		elif u.team == 1:
			ens.append(u)
	var grabbed := {}
	var gain := 0
	var guard := 0
	while not far.finished and guard < 300:
		guard += 1
		var d0: Dictionary = {}
		for e2 in ens:
			d0[e2.id] = dist.call(far, fc, e2)
		far.step()
		for e2 in ens:
			if e2.pull_t > 0:
				grabbed[e2.id] = true
				gain = maxi(gain, d0[e2.id] - dist.call(far, fc, e2))
	ok(grabbed.size() >= 3, "一次吸得到多隻", str(grabbed.size()))
	ok(gain > 0, "吸的時候距離確實變近", str(gain))
	ok(F8.CAT_R >= 4500 and F8.CAT_PULL >= 2000, "範圍與拉力加大", "%d %d" % [F8.CAT_R, F8.CAT_PULL])
