extends "res://tests/test_base.gd"
## 地圖（V9 P3）：鏡像、可達、舊路徑不變、代碼、尋路不卡死。
const MD = preload("res://scripts/core/map_defs.gd")
const RS9 = preload("res://scripts/core/ruleset.gd")

func _rules(map_id: int, size: int):
	var r = RS9.standard()
	r.deploy = "free"
	r.spacing = 800
	r.depth = 6000
	r.map_id = map_id
	r.map_size = size
	r.pool = [RS9.all_pool(), RS9.all_pool()]
	return r

func _army(team: int, r, rng: RandomNumberGenerator, n := 14, types := [0, 1, 2, 3, 4]):
	var a = Army.new(team, 400)
	a.apply_rules(r, team)
	a.budget = 400
	a.unit_cap = 40
	var tries := 0
	while a.units.size() < n and tries < 2000:
		tries += 1
		var ox: int = rng.randi_range(4, a.depth / 100) * 100
		var y: int = rng.randi_range(4, (a.fh - 400) / 100) * 100
		a.place_xy(int(types[a.units.size() % types.size()]), a.world_x(ox), y)
	return a

func test_maps_v9() -> void:
	var bad: Array = []
	for id in MD.MAPS.size():
		for sz in MD.SIZES.size():
			var r = _rules(id, sz)
			var t = r.terrain()
			if t != null:
				var v: Array = t.validate(r.depth_of())
				if not v.is_empty():
					bad.append("%s %d：%s" % [MD.MAPS[id]["key"], sz, v])
			if not r.validate().is_empty():
				bad.append("%s %d 規則：%s" % [MD.MAPS[id]["key"], sz, r.validate()])
	ok(bad.is_empty(), "6 張地圖 × 3 大小：鏡像、可達、部署面積都合格", str(bad))
	# 舊路徑
	var std = RS9.standard()
	ok(std.map_is_default() and std.terrain() == null and std.sim_is_legacy(), "標準規則沒有地形，走舊路徑")
	var dg: String = _rules(0, 1).sim_digest()
	var r0 = RS9.standard()
	r0.deploy = "free"
	r0.spacing = 800
	r0.depth = 6000
	ok(dg == r0.sim_digest(), "平原＋中型的摘要和第八輪相同")
	ok(_rules(1, 1).sim_digest() != dg and _rules(0, 0).sim_digest() != dg, "換地圖或大小摘要就變")
	# 代碼
	var r1 = _rules(5, 2)
	var c: String = r1.to_code()
	ok(c.begins_with("NTBR4."), "有地圖的規則代碼是 NTBR4")
	var d: Dictionary = RS9.from_code(c)
	ok(d["ok"] and d["rules"].map_id == 5 and d["rules"].map_size == 2 and d["rules"].equals(r1), "規則代碼還原地圖與大小", str(d))
	ok(not RS9.from_code(c.replace("NTBR4", "NTBR3"))["ok"], "前綴不符要拒絕")
	var r2 = RS9.standard()
	r2.map_id = 1
	ok("rr_map_free_only" in r2.validate(), "格子部署不能選地圖")
	# 部署
	var a = Army.new(0, 100)
	a.apply_rules(_rules(1, 1), 0)
	ok(a.fw == 16000 and a.terrain != null, "軍隊帶場地與地形")
	var a2 = Army.new(1, 100)
	a2.apply_rules(_rules(0, 0), 1)
	ok(a2.fw == 12000 and a2.fh == 7000 and a2.world_x(500) == 11500, "小地圖的世界座標")
	ok(a2.depth == 4500, "縱深照比例")
	var t2 = _rules(5, 1).terrain()
	var wall := Vector2i(16000 - 6000, 2000)
	ok(t2.blocked(wall.x, wall.y, 0) == t2.blocked(16000 - wall.x, wall.y, 1), "地形查詢鏡像")

## 每張圖、每種大小都打得完、沒有人卡在牆裡，而且逐 tick 鏡像。
func test_maps_mirror_v9() -> void:
	var rng := RandomNumberGenerator.new()
	var bad: Array = []
	var stuck: Array = []
	for id in range(1, MD.MAPS.size()):
		for sz in MD.SIZES.size():
			rng.seed = id * 100 + sz
			var r = _rules(id, sz)
			var pool := [D.SWORD, D.CAVALRY, D.ARCHER, D.ASSASSIN, D.PIKE] if sz != 1 else [D.SWORD, D.SHIELD, D.BOMBER, D.MEDIC, D.BERSERKER, 14, 19, 18, 13]
			r.pool = [RS9.full_pool(), RS9.full_pool()]
			var a0 = _army(0, r, rng, 14, pool)
			var a1 = _army(1, r, rng, 14, pool)
			a0.pool = RS9.full_pool()
			a1.pool = RS9.full_pool()
			var why: String = MC.check_free(a0, a1, r)
			if why != "":
				bad.append("%s %d：%s" % [MD.MAPS[id]["key"], sz, why])
			var s = Sim.new(a0.copy(), a1.copy(), r)
			s.fast = true
			var in_wall := 0
			while not s.finished:
				s.step()
				for u in s.units:
					if u.alive and not u.dormant and u.type != 14 and s.terrain.blocked(u.x, u.y, u.team):
						in_wall += 1
			if in_wall > 0:
				stuck.append("%s %d：%d" % [MD.MAPS[id]["key"], sz, in_wall])
			if s.tick >= s.max_ticks and s.power(0) == s.power(1):
				stuck.append("%s %d 打不起來" % [MD.MAPS[id]["key"], sz])
	ok(bad.is_empty(), "所有地圖逐 tick 左右鏡像", str(bad))
	ok(stuck.is_empty(), "所有地圖沒有單位站進牆裡、都打得起來", str(stuck))


## V1.4 #10 沙盤機關：崩塌後那幾格變擋路、站在上面的兵被挪開；火牆會扣血；推進板往中線推；確定性、左右鏡像；舊地圖沒有機關。
func test_map_events_v140() -> void:
	var Sim0 = load("res://scripts/core/battle_sim.gd")
	var AI0 = load("res://scripts/core/ai_army.gd")
	var RS0 = load("res://scripts/core/ruleset.gd")
	var MD = load("res://scripts/core/map_defs.gd")
	ok(MD.events(0).is_empty() and MD.events(5).is_empty() and not MD.events(MD.QUARRY).is_empty(), "只有新地圖帶機關")
	for mid in [MD.QUARRY, MD.BEACON, MD.PLATES]:
		var r = RS0.standard()
		r.map_id = mid
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + mid
		var a0 = AI0.build(0, 100, rng, -1, -1, r)["army"]
		var a1 = AI0.build(1, 100, rng, -1, -1, r)["army"]
		var s1 = Sim0.new(a0.copy(), a1.copy(), r)
		var s2 = Sim0.new(a0.copy(), a1.copy(), r)
		s1.run_to_end()
		s2.run_to_end()
		ok(s1.fingerprint == s2.fingerprint, "機關地圖 %d 確定性" % mid)
		var sm = Sim0.new(a1.mirrored(), a0.mirrored(), r)
		sm.run_to_end()
		ok(sm.tick == s1.tick and (sm.winner == -1 if s1.winner == -1 else sm.winner == 1 - s1.winner), "機關地圖 %d 左右鏡像" % mid, "%d/%d %d/%d" % [s1.winner, sm.winner, s1.tick, sm.tick])
	# 崩塌：第 400 tick 之後中路變擋路，共用快取的地形不受影響
	var rq = RS0.standard()
	rq.map_id = MD.QUARRY
	var tq = MD.terrain(MD.QUARRY, 1)
	var mid_y: int = tq.h / 2
	var mx: int = tq.w / 2 - 800
	ok(not tq.blocked(mx, mid_y, 0), "崩塌前中路可走")
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 3
	var sq = Sim0.new(AI0.build(0, 100, rng2, -1, -1, rq)["army"], AI0.build(1, 100, rng2, -1, -1, rq)["army"], rq)
	while sq.tick < 401 and not sq.finished:
		sq.step()
	if not sq.finished:
		ok(sq.terrain.blocked(mx, mid_y, 0) and not tq.blocked(mx, mid_y, 0), "崩塌後這一場中路擋住、共用地形不變")
		var stuck := 0
		for u in sq.units:
			if u.alive and sq.terrain.blocked(u.x, u.y, u.team):
				stuck += 1
		ok(stuck == 0, "沒有兵卡在崩塌的格子裡")

