extends SceneTree
## 自由模式跨版本金標準（第七輪 S1）。舊金標準 golden.gd 只鎖格子舊路徑，自由模式原本只有同版自比。
## 產生：godot --headless --path game --script res://tools/golden_free.gd -- --make（刻意改規則才重產，commit 要說明）
## 檢查：godot --headless --path game --script res://tools/golden_free.gd
## 五組規則各 24 場：標準自由、全場、讓子、沙盒、支援兵密集。案例存成對戰代碼 NTB3，所以同時鎖住代碼格式。
const Sim = preload("res://scripts/core/battle_sim.gd")
const Army = preload("res://scripts/core/army.gd")
const D = preload("res://scripts/core/unit_defs.gd")
const F = preload("res://scripts/core/formations.gd")
const RSET = preload("res://scripts/core/ruleset.gd")
const BC = preload("res://scripts/game/battle_code.gd")
const GOLD = preload("res://tools/golden.gd")
const PATH := "res://tests/golden/golden_free.json"
const LOCK := "res://tests/golden/golden_free.lock"
const PER_GROUP := 24

static func rules_of(group: String):
	var r = RSET.standard()
	r.deploy = "free"
	r.spacing = 800
	r.depth = 6000
	match group:
		"full":
			r.depth = 7000
			r.fullfield = RSET.FULL_DUEL
		"handicap":
			r.handicap = true
			r.budget = [80, 120]
		"sandbox":
			r.stat_pct = {0: [150, 100, 100], 4: [100, 150, 80]}
			r.skills_off = ["charge"]
		"support":
			r.unit_cap = 40
			r.budget = [200, 200]
	return r

static func make_army(team: int, r, rng: RandomNumberGenerator, group: String) -> Army:
	if group == "support":
		var a := Army.new(team, r.budget_of(team))
		a.apply_rules(r, team)
		var kinds := [7, 8, 0, 7, 8, 2, 1, 7, 8, 3]
		var i := 0
		for row in 5:
			for col in 6:
				if a.units.size() >= 36:
					break
				var ox := 800 + col * 800 + rng.randi_range(0, 2) * 50
				var y := 1000 + row * 1300 + rng.randi_range(0, 2) * 50
				a.place_xy(kinds[i % kinds.size()], ox if team == 0 else Sim.W - ox, y)
				i += 1
		return a
	var src: Army = F.random_formation(0, rng, "mixed", "", D.COUNT)
	var base = r
	if group == "handicap":
		base = rules_of("free")   # 陣型先用標準 100 金產生，再照讓子的預算放進去
	var out: Army = F.to_free(src, base, rng)
	if team == 1:
		out = out.mirrored()
	if group != "handicap":
		return out
	var a2 := Army.new(team, r.budget_of(team))
	a2.apply_rules(r, team)
	for u in out.units:
		var p := Army.pos_of(u)
		a2.place_xy(int(u["type"]), p.x, p.y)   # 超過預算的放不下就略過
	return a2

static func run_code(code: String) -> Dictionary:
	var d: Dictionary = BC.decode(code)
	if not d.get("ok", false):
		return {"error": str(d.get("why", "decode"))}
	var s = Sim.new(d["a0"], d["a1"], d["rules"])
	var cps: Array = []
	while not s.finished:
		s.step()
		if s.tick % 100 == 0:
			cps.append(GOLD.state_sig(s))
	cps.append(GOLD.state_sig(s))
	return {"w": s.winner, "t": s.tick, "cps": cps, "fp": s.fingerprint}

func _init() -> void:
	if "--make" in OS.get_cmdline_user_args():
		_make()
	else:
		var res := check()
		print("GOLDENFREE %s" % JSON.stringify(res))
		quit(0 if res["ok"] else 1)

func _make() -> void:
	var cases: Array = []
	for group in ["free", "full", "handicap", "sandbox", "support"]:
		var r = rules_of(group)
		var why: Array = r.validate()
		if not why.is_empty():
			push_error("%s 規則不合法：%s" % [group, str(why)])
			quit(1)
			return
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(group) & 0xffff
		var made := 0
		var tries := 0
		while made < PER_GROUP and tries < PER_GROUP * 20:
			tries += 1
			var code: String = BC.encode(make_army(0, r, rng, group), make_army(1, r, rng, group), r)
			var res := run_code(code)
			if res.has("error"):
				continue
			res["c"] = code
			res["g"] = group
			cases.append(res)
			made += 1
		print("%s：%d 場（試 %d 次）" % [group, made, tries])
		if made < PER_GROUP:
			quit(1)
			return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"rules": D.RULES_VERSION, "digest": D.data_digest(), "cases": cases}))
	f.close()
	var lk := FileAccess.open(LOCK, FileAccess.WRITE)
	lk.store_string(JSON.stringify({"sha256": FileAccess.get_file_as_string(PATH).sha256_text(), "cases": cases.size()}))
	lk.close()
	quit(0)

static func check() -> Dictionary:
	var raw := FileAccess.get_file_as_string(PATH)
	var lk = JSON.parse_string(FileAccess.get_file_as_string(LOCK))
	if not lk is Dictionary or str(lk.get("sha256", "")) != raw.sha256_text():
		return {"ok": false, "why": "基準檔和鎖檔不符"}
	var g: Dictionary = JSON.parse_string(raw)
	if str(g["rules"]) != D.RULES_VERSION or str(g["digest"]) != D.data_digest():
		return {"ok": false, "why": "規則或數值變了：刻意改規則才能重產"}
	var cases: Array = g["cases"]
	if cases.size() != int(lk.get("cases", 0)) or cases.size() != 5 * PER_GROUP:
		return {"ok": false, "why": "案例數不對"}
	var sh := _shard_args()
	for i in cases.size():
		if i % int(sh[1]) != int(sh[0]):
			continue
		var c: Dictionary = cases[i]
		var r := run_code(str(c["c"]))
		if r.has("error"):
			return {"ok": false, "why": "第 %d 場（%s）解不開：%s" % [i, c["g"], r["error"]]}
		if str(r["fp"]) != str(c["fp"]) or int(r["w"]) != int(c["w"]) or int(r["t"]) != int(c["t"]) or r["cps"] != c["cps"]:
			var at := -1
			for k in mini(r["cps"].size(), c["cps"].size()):
				if r["cps"][k] != c["cps"][k]:
					at = k * 100
					break
			return {"ok": false, "why": "第 %d 場（%s）分歧，約 tick %d" % [i, c["g"], at]}
	return {"ok": true, "n": cases.size()}

## 第九輪 P0：--shard=k/m 只跑編號 i % m == k 的案例（tools/check.py 分片平行用）
static func _shard_args() -> Array:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shard="):
			var p := a.substr(8).split("/")
			return [int(p[0]), int(p[1])]
	return [0, 1]
