extends SceneTree
## 確定性金標準（第三輪 T2）。
## 產生：godot --headless --path game --script res://tools/golden.gd -- --make
##   用固定種子讓 AI 擺 1000 組陣，存成陣型代碼＋每 100 tick 的狀態雜湊＋最終指紋，寫到 tests/golden/golden.json，並記下規則版本與數值摘要。
##   只有「刻意改了戰鬥規則」才重產，而且要在 commit 裡說明。
## 檢查：godot --headless --path game --script res://tools/golden.gd [-- --n=1000]
##   逐場重算比對，回報第一個分歧的場次與 tick；任何分歧 exit 1。規則版本或數值摘要不同也 exit 1（提示要不要重產）。
const Sim = preload("res://scripts/core/battle_sim.gd")
const Army = preload("res://scripts/core/army.gd")
const AI = preload("res://scripts/core/ai_army.gd")
const D = preload("res://scripts/core/unit_defs.gd")
const F = preload("res://scripts/core/formations.gd")
const PATH := "res://tests/golden/golden.json"
const CHECK_EVERY := 100
const LOCK := "res://tests/golden/golden.lock"   # 第五輪 P0：基準檔的 sha256＋案例數，防止金標準被換成縮水或空的版本
const CASES := 1000

static func state_sig(s) -> String:
	var parts := PackedStringArray()
	parts.append(str(s.tick))
	for u in s.units:
		parts.append("%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d" % [u.id, u.x, u.y, u.hp, 1 if u.alive else 0, u.target, u.stun,
			u.stealth, u.charge, u.slow, u.cd, u.fx, u.fy, u.nav, 1 if u.chasing else 0, u.kills, u.dmg_dealt, u.dmg_taken,
			u.hcd, u.aura, u.breach, u.bmode, u.heal_done, u.follow])   # 第四輪 N0a：補擊殺與傷害統計；1.3.0：新兵種狀態   # 第四輪 N0a：補擊殺與傷害統計
	return ",".join(parts).sha256_text().substr(0, 16)

static func run_case(c0: String, c1: String, fast: bool) -> Dictionary:
	var a0 := Army.new(0, 100)
	var a1 := Army.new(1, 100)
	a0.load_code(c0)
	a1.load_code(c1)
	var s = Sim.new(a0, a1)
	s.fast = fast
	var cps: Array = []
	while not s.finished:
		s.step()
		if s.tick % CHECK_EVERY == 0:
			cps.append(state_sig(s))
	cps.append(state_sig(s))
	return {"winner": s.winner, "ticks": s.tick, "cps": cps, "fp": s.fingerprint}

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if "--make" in args:
		_make()
		return
	var n := 1000
	for a in args:
		if a.begins_with("--n="):
			n = int(a.substr(4))
	var res := check(n)
	print("GOLDEN %s" % JSON.stringify(res))
	quit(0 if res["ok"] else 1)

func _make() -> void:
	var rng := RandomNumberGenerator.new()
	var cases: Array = []
	for i in 1000:
		rng.seed = 20261102 + i * 7919
		# 第四輪：一半用 AI 模板（含新兵模板）、一半用十種兵的隨機混編，確保至少一半場次有新兵
		var a0: Army = AI.build(0, 100, rng)["army"] if i % 2 == 0 else F.random_formation(0, rng, "mixed", "", D.COUNT)
		var a1: Army = AI.build(1, 100, rng)["army"] if i % 2 == 0 else F.random_formation(0, rng, "mixed", "", D.COUNT).mirrored()
		var c0 := a0.to_code()
		var c1 := a1.to_code()
		var r := run_case(c0, c1, false)
		cases.append({"a": c0, "b": c1, "w": r["winner"], "t": r["ticks"], "cps": r["cps"], "fp": r["fp"]})
	var out := {"rules": D.RULES_VERSION, "digest": D.data_digest(), "check_every": CHECK_EVERY, "cases": cases}
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	var lk := FileAccess.open(LOCK, FileAccess.WRITE)
	lk.store_string(JSON.stringify({"sha256": FileAccess.get_file_as_string(PATH).sha256_text(), "cases": cases.size()}))
	lk.close()
	print("GOLDEN 已產生 %d 場（規則 %s、摘要 %s）" % [cases.size(), D.RULES_VERSION, D.data_digest()])
	quit(0)

## 比對前 n 場；回傳 {ok, n, first_case, first_tick, why}
static func check(n: int) -> Dictionary:
	var raw := FileAccess.get_file_as_string(PATH)
	var lk = JSON.parse_string(FileAccess.get_file_as_string(LOCK))
	if not lk is Dictionary or str(lk.get("sha256", "")) != raw.sha256_text() or int(lk.get("cases", 0)) != CASES:
		return {"ok": false, "why": "金標準檔和鎖檔不符（檔案被換過、縮水，或沒有用 --make 重產）"}
	var g = JSON.parse_string(raw)
	if not g is Dictionary or not g.get("cases") is Array or g["cases"].size() != CASES:
		return {"ok": false, "why": "讀不到金標準檔，或案例數不是 %d" % CASES}
	if n <= 0 or n > CASES:
		return {"ok": false, "why": "n 要在 1～%d" % CASES}
	if str(g["rules"]) != D.RULES_VERSION or str(g["digest"]) != D.data_digest():
		return {"ok": false, "why": "規則或數值變了（%s/%s → %s/%s）：若是刻意改規則，請重產金標準並在 commit 說明" % [g["rules"], g["digest"], D.RULES_VERSION, D.data_digest()]}
	var cases: Array = g["cases"]
	var every := int(g["check_every"])
	for i in mini(n, cases.size()):
		var c: Dictionary = cases[i]
		var r := run_case(c["a"], c["b"], false)
		var cps: Array = c["cps"]
		for k in mini(cps.size(), r["cps"].size()):
			if cps[k] != r["cps"][k]:
				return {"ok": false, "n": i + 1, "first_case": i, "first_tick": (k + 1) * every if k < cps.size() - 1 else int(c["t"]), "why": "狀態分歧"}
		if r["cps"].size() != cps.size() or int(r["winner"]) != int(c["w"]) or int(r["ticks"]) != int(c["t"]) or r["fp"] != c["fp"]:
			return {"ok": false, "n": i + 1, "first_case": i, "first_tick": int(c["t"]), "why": "結果或指紋不同"}
	var ran := mini(n, cases.size())
	return {"ok": ran == n, "n": ran}
