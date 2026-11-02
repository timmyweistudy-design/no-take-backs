extends SceneTree
## 舊兵種相容檢查（第四輪方案 §3.1～3.2）。
## 目的：加新兵種之後，「只用舊 5 種兵」的對戰行為必須一模一樣。
## 最終指紋包含規則版本和數值摘要，加兵後一定會變，所以這裡不比指紋，改比：
##   ・逐 tick 累積摘要：每 tick 把每隻兵的「舊欄位」（第三輪就有的 28 個狀態）寫進同一個 SHA-256
##   ・勝方、結束 tick、每隻兵的擊殺數、造成／承受傷害
## 基準檔 tests/golden/compat_v1.2.json 是在 N0a（規則 1.2.0、還沒加兵）時用同一套程式產生的，
## 之後不重產；陣型代碼存在檔案裡，不重新呼叫 AI 造陣（AI 之後會改）。
## 用法：godot --headless --path game --script res://tools/compat.gd -- [--make] [--n=1000]
const Sim = preload("res://scripts/core/battle_sim.gd")
const Army = preload("res://scripts/core/army.gd")
const D = preload("res://scripts/core/unit_defs.gd")
const PATH := "res://tests/golden/compat_v1.2.json"
const GOLDEN := "res://tests/golden/golden.json"

## 舊欄位（第三輪 _hash_state 的 28 個欄位）。新兵種加的狀態不放這裡，另外檢查它們在舊場次一直是初值。
static func old_fields(u) -> PackedInt64Array:
	return PackedInt64Array([u.x, u.y, u.hp, u.cd, u.target, u.fx, u.fy, u.face_lock, u.mx, u.my, u.cdx, u.cdy, u.stealth, u.charge, u.stun,
		u.slow, u.wp_x, u.wp_y, u.wp_for, 1 if u.alive else 0, u.dmg_dealt, u.dmg_taken, u.kills, u.id, u.team, u.type, u.nav, 1 if u.chasing else 0])

## 新狀態在舊場次必須一直是初值（加了新欄位就在這裡登記初值）。回傳空字串＝正常。
static func new_fields_untouched(s) -> String:
	for u in s.units:
		for k in NEW_FIELDS:
			if k in u and u.get(k) != NEW_FIELDS[k]:
				return "id %d 的 %s=%s（應為 %s）" % [u.id, k, u.get(k), NEW_FIELDS[k]]
	return ""

## 第四輪新增的單位狀態與它們的初值（舊 5 種兵永遠不會用到）
const NEW_FIELDS := {"hcd": 0, "aura": 0, "breach": 0, "bmode": 0, "heal_done": 0, "follow": -1}

static func run_case(c0: String, c1: String) -> Dictionary:
	var a0 := Army.new(0, 100)
	var a1 := Army.new(1, 100)
	a0.load_code(c0)
	a1.load_code(c1)
	var s = Sim.new(a0, a1)
	s.fast = true
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	var untouched := ""
	while not s.finished:
		s.step()
		var buf := PackedInt64Array([s.tick])
		for u in s.units:
			buf.append_array(old_fields(u))
		h.update(buf.to_byte_array())
		if untouched == "":
			untouched = new_fields_untouched(s)
	var per := PackedStringArray()
	for u in s.units:
		per.append("%d:%d:%d:%d" % [u.id, u.kills, u.dmg_dealt, u.dmg_taken])
	return {"w": s.winner, "t": s.tick, "roll": h.finish().hex_encode().substr(0, 24), "per": ";".join(per), "untouched": untouched}

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := 1000
	for a in args:
		if a.begins_with("--n="):
			n = int(a.substr(4))
	if "--make" in args:
		_make()
		return
	var res := check(n)
	print("COMPAT %s" % JSON.stringify(res))
	quit(0 if res["ok"] else 1)

func _make() -> void:
	if D.RULES_VERSION != "1.2.0":
		push_error("相容基準只能在規則 1.2.0（還沒加新兵）時產生")
		quit(1)
		return
	var g = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN))
	var cases: Array = []
	for c in g["cases"]:
		var r := run_case(c["a"], c["b"])
		cases.append({"a": c["a"], "b": c["b"], "w": r["w"], "t": r["t"], "roll": r["roll"], "per": r["per"]})
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"from_rules": D.RULES_VERSION, "from_digest": D.data_digest(), "cases": cases}))
	f.close()
	print("COMPAT 已產生 %d 場基準（規則 %s）" % [cases.size(), D.RULES_VERSION])
	quit(0)

## 比對前 n 場；回傳 {ok, n, first_case, why}
static func check(n: int) -> Dictionary:
	var g = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not g is Dictionary:
		return {"ok": false, "why": "讀不到相容基準檔"}
	var cases: Array = g["cases"]
	for i in mini(n, cases.size()):
		var c: Dictionary = cases[i]
		var r := run_case(c["a"], c["b"])
		if r["untouched"] != "":
			return {"ok": false, "n": i + 1, "first_case": i, "why": "新狀態在舊場次被動到：" + r["untouched"]}
		if int(r["w"]) != int(c["w"]) or int(r["t"]) != int(c["t"]):
			return {"ok": false, "n": i + 1, "first_case": i, "why": "勝負或結束 tick 不同"}
		if r["per"] != str(c["per"]):
			return {"ok": false, "n": i + 1, "first_case": i, "why": "擊殺或傷害統計不同"}
		if r["roll"] != c["roll"]:
			return {"ok": false, "n": i + 1, "first_case": i, "why": "逐 tick 狀態分歧"}
	return {"ok": true, "n": mini(n, cases.size())}
