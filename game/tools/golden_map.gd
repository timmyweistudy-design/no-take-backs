extends SceneTree
## V9 金標準：鎖住有地圖或非標準大小的戰鬥。舊金標準不會走這些分支。
## 產生：godot --headless --path game --script res://tools/golden_map.gd -- --make（刻意改地形或尋路才重產，commit 要說明）
## 檢查：godot --headless --path game --script res://tools/golden_map.gd [-- --shard=k/m]
const Sim = preload("res://scripts/core/battle_sim.gd")
const Army = preload("res://scripts/core/army.gd")
const D = preload("res://scripts/core/unit_defs.gd")
const RSET = preload("res://scripts/core/ruleset.gd")
const MD = preload("res://scripts/core/map_defs.gd")
const BC = preload("res://scripts/game/battle_code.gd")
const GOLD = preload("res://tools/golden.gd")
const PATH := "res://tests/golden/golden_map.json"
const LOCK := "res://tests/golden/golden_map.lock"
const PER := 2
const POOL_A := 1 + 2 + 4 + 8 + 16 + (1 << 13) + (1 << 14) + (1 << 17) + (1 << 18) + (1 << 19)
const POOL_B := 4 + 32 + 64 + 128 + 256 + 512 + (1 << 10) + (1 << 11) + (1 << 12) + (1 << 15)

static func rules_of(map_id: int, size: int):
	var r = RSET.standard()
	r.deploy = "free"
	r.spacing = 800
	r.depth = 6000
	r.map_id = map_id
	r.map_size = size
	r.ai_pool_same = false
	r.pool = [POOL_A, POOL_B]
	return r

static func make_army(team: int, r, rng: RandomNumberGenerator) -> Army:
	var a := Army.new(team, r.budget_of(team))
	a.apply_rules(r, team)
	var kinds: Array = RSET.types_of(int(r.pool[team]))
	for i in 40:
		var t: int = int(kinds[rng.randi_range(0, kinds.size() - 1)])
		var ox: int = rng.randi_range(4, (a.depth - 100) / 100) * 100
		var y: int = rng.randi_range(4, (a.fh - 400) / 100) * 100
		a.place_xy(t, a.world_x(ox), y)
	return a

static func run_code(code: String) -> Dictionary:
	var d: Dictionary = BC.decode(code)
	if not d.get("ok", false):
		return {"error": str(d.get("why", "decode"))}
	var s = Sim.new(d["a0"], d["a1"], d["rules"])
	var cps: Array = []
	while not s.finished:
		s.step()
		if s.tick % 200 == 0:
			cps.append(GOLD.state_sig(s))
	cps.append(GOLD.state_sig(s))
	return {"w": s.winner, "t": s.tick, "cps": cps, "fp": s.fingerprint}

func _init() -> void:
	if "--make" in OS.get_cmdline_user_args():
		_make()
		return
	var res := check()
	print("GOLDENMAP %s" % JSON.stringify(res))
	quit(0 if res["ok"] else 1)

func _make() -> void:
	var cases: Array = []
	for id in MD.MAPS.size():
		for z in MD.SIZES.size():
			if id == 0 and z == MD.STD_SIZE:
				continue
			var r = rules_of(id, z)
			var why: Array = r.validate()
			if not why.is_empty():
				push_error("%d/%d 規則不合法：%s" % [id, z, str(why)])
				quit(1)
				return
			var rng := RandomNumberGenerator.new()
			rng.seed = 990000 + id * 10 + z
			var made := 0
			var tries := 0
			while made < PER and tries < 40:
				tries += 1
				var a0 := make_army(0, r, rng)
				var a1 := make_army(1, r, rng)
				if a0.units.size() < 5 or a1.units.size() < 5 or not a0.has_combat() or not a1.has_combat():
					continue
				var code: String = BC.encode(a0, a1, r)
				var res := run_code(code)
				if res.has("error"):
					continue
				res["c"] = code
				res["g"] = "%d/%d" % [id, z]
				cases.append(res)
				made += 1
			if made < PER:
				push_error("%d/%d 做不出案例（試 %d 次）" % [id, z, tries])
				quit(1)
				return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"digest": D.digest_v8(), "cases": cases}))
	f.close()
	var lk := FileAccess.open(LOCK, FileAccess.WRITE)
	lk.store_string(JSON.stringify({"sha256": FileAccess.get_file_as_string(PATH).sha256_text(), "cases": cases.size()}))
	lk.close()
	print("GOLDENMAP 已產生 %d 場" % cases.size())
	quit(0)

static func check() -> Dictionary:
	var raw := FileAccess.get_file_as_string(PATH)
	var lk = JSON.parse_string(FileAccess.get_file_as_string(LOCK))
	if not lk is Dictionary or str(lk.get("sha256", "")) != raw.sha256_text():
		return {"ok": false, "why": "基準檔和鎖檔不符"}
	var g: Dictionary = JSON.parse_string(raw)
	if str(g["digest"]) != D.digest_v8():
		return {"ok": false, "why": "數值變了：刻意改規則才能重產"}
	var cases: Array = g["cases"]
	var sh := _shard_args()
	for i in cases.size():
		if i % int(sh[1]) != int(sh[0]):
			continue
		var c: Dictionary = cases[i]
		var r := run_code(str(c["c"]))
		if r.has("error"):
			return {"ok": false, "why": "第 %d 場（%s）解不開：%s" % [i, c["g"], r["error"]]}
		if str(r["fp"]) != str(c["fp"]) or int(r["w"]) != int(c["w"]) or int(r["t"]) != int(c["t"]) or r["cps"] != c["cps"]:
			return {"ok": false, "why": "第 %d 場（%s）分歧" % [i, c["g"]]}
	return {"ok": true, "n": cases.size()}

static func _shard_args() -> Array:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shard="):
			var p := a.substr(8).split("/")
			return [int(p[0]), int(p[1])]
	return [0, 1]
