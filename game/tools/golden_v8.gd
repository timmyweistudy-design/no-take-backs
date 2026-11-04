extends SceneTree
## 第八輪金標準：鎖住有奇幻兵的戰鬥（舊金標準不會碰到 v8 分支）。案例存成對戰代碼 NTB4，所以同時鎖住代碼格式。
## 產生：godot --headless --path game --script res://tools/golden_v8.gd -- --make（刻意改規則才重產，commit 要說明）
## 檢查：godot --headless --path game --script res://tools/golden_v8.gd
## 四組各 15 場：純奇幻（AI）、新舊混編（AI）、全場部署、召喚物密集。
const Sim = preload("res://scripts/core/battle_sim.gd")
const Army = preload("res://scripts/core/army.gd")
const D = preload("res://scripts/core/unit_defs.gd")
const F8 = preload("res://scripts/core/fantasy_defs.gd")
const AI = preload("res://scripts/core/ai_army.gd")
const RSET = preload("res://scripts/core/ruleset.gd")
const BC = preload("res://scripts/game/battle_code.gd")
const GOLD = preload("res://tools/golden.gd")
const PATH := "res://tests/golden/golden_v8.json"
const LOCK := "res://tests/golden/golden_v8.lock"
const PER_GROUP := 15
# 每邊一場最多 10 種：兩份名單合起來碰到全部 20 種
const POOL_A := 1 + 2 + 4 + 128 + 512 + (1 << 11) + (1 << 13) + (1 << 15) + (1 << 17) + (1 << 19)
const POOL_B := 4 + 8 + 16 + 32 + 256 + (1 << 10) + (1 << 12) + (1 << 14) + (1 << 16) + (1 << 18)
const GROUPS := ["fantasy", "mixed", "full", "summon"]

static func rules_of(group: String):
	var r = RSET.standard()
	r.deploy = "free"
	r.spacing = 800
	r.depth = 6000
	var fp: int = RSET.full_pool() >> 10 << 10
	match group:
		"fantasy":
			r.pool = [fp, fp]
		"mixed":
			r.ai_pool_same = false
			r.pool = [POOL_A, POOL_B]
		"full":
			r.depth = 7000
			r.fullfield = RSET.FULL_DUEL
			r.ai_pool_same = false
			r.pool = [POOL_B, POOL_A]
		"summon":
			r.unit_cap = 40
			r.budget = [200, 200]
			r.pool = [fp, fp]
	return r

## 用固定種子隨機擺滿預算；放不下的略過。AI 模板另外有 fantasy_eval 量，這裡要的是什麼組合都碰得到。
static func make_army(team: int, r, rng: RandomNumberGenerator, group: String) -> Army:
	var a := Army.new(team, r.budget_of(team))
	a.apply_rules(r, team)
	var kinds: Array = []
	if group == "summon":
		kinds = [13, 17, 13, 17, 15, 19]
	else:
		var pool: int = int(r.pool[team])
		for k in 20:
			if pool & (1 << k):
				kinds.append(k)
	var depth: int = int(r.depth) - 400
	for i in 40:
		var t: int = int(kinds[rng.randi_range(0, kinds.size() - 1)])
		var ox: int = rng.randi_range(4, depth / 100) * 100
		var y: int = rng.randi_range(4, (Sim.H - 400) / 100) * 100
		a.place_xy(t, ox if team == 0 else Sim.W - ox, y)
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
	else:
		var res := check()
		print("GOLDENV8 %s" % JSON.stringify(res))
		quit(0 if res["ok"] else 1)

func _make() -> void:
	var cases: Array = []
	var seen := {}
	for group in GROUPS:
		var r = rules_of(group)
		var why: Array = r.validate()
		if not why.is_empty():
			push_error("%s 規則不合法：%s" % [group, str(why)])
			quit(1)
			return
		var rng := RandomNumberGenerator.new()
		rng.seed = 880000 + GROUPS.find(group)
		var made := 0
		var tries := 0
		while made < PER_GROUP and tries < PER_GROUP * 20:
			tries += 1
			var a0 := make_army(0, r, rng, group)
			var a1 := make_army(1, r, rng, group)
			if a0.units.size() < 5 or a1.units.size() < 5 or not a0.has_combat() or not a1.has_combat():
				continue
			var code: String = BC.encode(a0, a1, r)
			var res := run_code(code)
			if res.has("error"):
				continue
			res["c"] = code
			res["g"] = group
			cases.append(res)
			for ar in [a0, a1]:
				for u in ar.units:
					seen[int(u["type"])] = true
			made += 1
		print("%s：%d 場（試 %d 次）" % [group, made, tries])
		if made < PER_GROUP:
			quit(1)
			return
	for t in range(10, 20):
		if not seen.has(t):
			push_error("案例沒碰到兵種 %d" % t)
			quit(1)
			return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"digest": D.digest_v8(), "cases": cases}))
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
	if str(g["digest"]) != D.digest_v8():
		return {"ok": false, "why": "第八輪數值變了：刻意改規則才能重產"}
	var cases: Array = g["cases"]
	if cases.size() != int(lk.get("cases", 0)) or cases.size() != GROUPS.size() * PER_GROUP:
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
			return {"ok": false, "why": "第 %d 場（%s）分歧" % [i, c["g"]]}
	return {"ok": true, "n": cases.size()}

## 第九輪 P0：--shard=k/m 只跑編號 i % m == k 的案例（tools/check.py 分片平行用）
static func _shard_args() -> Array:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shard="):
			var p := a.substr(8).split("/")
			return [int(p[0]), int(p[1])]
	return [0, 1]
