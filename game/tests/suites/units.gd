extends "res://tests/test_base.gd"

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
