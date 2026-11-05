extends "res://tests/test_base.gd"

## 殘局標準解回歸（第二輪方案 §1.4）：每關存的標準解都必須打贏；改戰鬥規則後有任何一關變不能過就會紅。
func test_puzzle_solutions() -> void:
	var total := 0
	var bad: Array = []
	for pz in PZ.tutorials() + PZ.puzzles() + PZ.new_puzzles() + PZ.fantasy_puzzles():
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
	var n_pz: int = (PZ.tutorials() + PZ.puzzles() + PZ.new_puzzles() + PZ.fantasy_puzzles()).size()
	for pz in PZ.new_puzzles() + PZ.fantasy_puzzles():
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
	ok(n == 35 and bad.is_empty(), "35 個技能示範都觸發預期事件、說明數值都換好", str(bad))
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
	for i in 3:
		CX.record_win(sd, [D.CAVALRY, D.CAVALRY, D.SWORD])
	ok(CX.wins_with(sd, D.CAVALRY) == 3 and CX.wins_with(sd, D.SWORD) == 3 and CX.wins_with(sd, D.ARCHER) == 0, "勝場：同一場同種只算一次")


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
