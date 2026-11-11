extends RefCounted

## 測試共用（第七輪 I1）：斷言、常數、輔助函式。各主題的測試在 tests/suites/。



var runner = null   # run_tests.gd（框架測試要用）

const D = preload("res://scripts/core/unit_defs.gd")

const Army = preload("res://scripts/core/army.gd")

const Sim = preload("res://scripts/core/battle_sim.gd")

const AI = preload("res://scripts/core/ai_army.gd")

const TP = preload("res://scripts/core/turn_placement.gd")

const MC = preload("res://scripts/core/mirror_check.gd")

const PZ = preload("res://scripts/game/puzzles.gd")

const CX = preload("res://scripts/game/codex.gd")

const BV = preload("res://scripts/ui/battle_view.gd")

const F = preload("res://scripts/core/formations.gd")

const EVS = preload("res://scripts/core/events.gd")

const Art = preload("res://scripts/ui/art.gd")

var passed := 0

var failed := 0

func ok(cond: bool, name: String, extra := "") -> void:
	if cond:
		passed += 1
		print("PASS ", name)
	else:
		failed += 1
		print("FAIL ", name, "  ", extra)

func army_from(team: int, spec: Array):
	var a = Army.new(team, 100)
	for s in spec:
		var col: int = s[1] if team == 0 else Army.COLS - 1 - s[1]
		a.units.append({"type": s[0], "col": col, "row": s[2]})
	return a

## 不出聲的音效替身：讓畫面層可以在 headless 測試裡跑（只記錄播了什麼）。
class FakeSfx:
	func play_ambience(_n: String) -> void:
		pass
	var amb_name := ""
	var amb_owner := 0
	func set_volumes(_s: int, _m: int, _u: int, _a: int) -> void:   # V1.5：設定一次套用會呼叫
		pass
	func duck(_s: float) -> void:
		pass
	var played: Array = []
	func play_unit(n: String, v: float, _t: int) -> void:   # V1.3.1：依兵種音高的音效，紀錄照名稱
		play(n, v)
	func play_wood(_t: int, _v := 0.5) -> void:   # V1.6 #14 擬音（不記：舊測試數音效次數）
		pass
	func play(n: String, _v := 1.0, _p := 1.0) -> void:
		played.append(n)
	func play_music(_n: String) -> void:
		pass
	func set_muffled(_on: bool) -> void:
		pass
	func set_layer_targets(_g: Array) -> void:
		pass
	static func layer_targets(close: bool, clutch: bool) -> Array:
		return [1.0, 1.0 if close else 0.35, 1.0] if not clutch else [1.0, 0.0, 0.0]

static func _pad64(b: String) -> String:
	var x := b.replace("-", "+").replace("_", "/")
	while x.length() % 4 != 0:
		x += "="
	return x

static func _view_sig(v) -> String:
	var parts: Array = [v.tick]
	for u in v.units:
		parts.append([u.id, u.x, u.y, u.hp, u.alive])
	return JSON.stringify(parts)

## ───────── 第四輪：五種新兵（方案 v4 §3.3，每條都有「改壞會紅」的證明，紀錄在 coordination/n1-units/） ─────────
## 直接擺位置的小場景：spec＝[兵種, 隊, x, y]（絕對座標，1000＝1 格）。
func sim_at(spec: Array):
	var a0 = Army.new(0, 400)
	var a1 = Army.new(1, 400)
	for k in spec.size():
		var e: Array = spec[k]
		var a = a0 if e[1] == 0 else a1
		# 先放到不重複的格子，建好之後再搬到指定座標
		a.units.append({"type": e[0], "col": (k % 6) if e[1] == 0 else 15 - (k % 6), "row": k / 6})
	var s = Sim.new(a0, a1)
	var by_team := [0, 0]
	for e in spec:
		pass
	# Sim 依 id 排序；依「隊、列、欄」對回 spec 的順序
	var order: Array = []
	for k in spec.size():
		var e: Array = spec[k]
		var col: int = (k % 6) if e[1] == 0 else 15 - (k % 6)
		var id: int = e[1] * 1000 + (k / 6) * 16 + col
		for i in s.units.size():
			if s.units[i].id == id:
				order.append(i)
				s.units[i].x = e[2]
				s.units[i].y = e[3]
				s.units[i].fx = 1000 if e[1] == 0 else -1000
	return {"s": s, "idx": order}

func count_kind(s, kind: String, ticks: int, src := -1) -> Array:
	var out: Array = []
	for i in ticks:
		if s.finished:
			break
		s.step()
		for ev in s.events:
			if ev.get("kind") == kind and (src == -1 or ev.get("src") == src):
				out.append(ev)
	return out

const RSET = preload("res://scripts/core/ruleset.gd")

const AIT5 = preload("res://scripts/core/ai_turns.gd")

const HA5 = preload("res://scripts/core/hard_ai.gd")

## 獨立的陣型合法性判定（不呼叫 Army.check_place，避免用被測的程式驗自己）。
static func legal_army(a, r, team: int) -> String:
	var seen := {}
	var spent := 0
	var per := {}
	for u in a.units:
		var t := int(u["type"])
		var c := int(u["col"])
		var row := int(u["row"])
		var lc := c if team == 0 else 15 - c
		if lc < 0 or lc > 5 or row < 0 or row > 8:
			return "出界"
		if seen.has(Vector2i(c, row)):
			return "重複格"
		seen[Vector2i(c, row)] = true
		if (r.pool_of(team) >> t) & 1 == 0:
			return "不在卡池 %d" % t
		per[t] = int(per.get(t, 0)) + 1
		if r.type_cap > 0 and per[t] > r.type_cap:
			return "超過單種上限"
		spent += D.cost(t)
	if spent > r.budget_of(team):
		return "超過預算"
	if a.units.size() > r.unit_cap:
		return "超過人數"
	return ""

## 第五輪沙盒（R3 閘門）：每個技能開關、倍率、不互相污染、100％＝標準。
static func _sb_tags(armies: Array, r) -> Dictionary:
	var s = Sim.new(armies[0].copy(), armies[1].copy(), r)
	var seen := {}
	var fr := false
	while not s.finished:
		s.step()
		fr = fr or s.frenzy
		for e in s.events:
			seen[e["kind"]] = true
			for tg in e.get("tags", []):
				seen[tg] = true
	seen["_frenzy"] = fr
	return seen

## 獨立判定器（不呼叫 Army 的檢查函式）：型別、量化、部署區、己方間距、敵距、預算、人數、單種、卡池。
static func legal_free(a, r, team: int, enemy: Array = []) -> String:
	if a.units.is_empty():
		return "空的"
	var spent := 0
	var per := {}
	var pts: Array = []
	for u in a.units:
		if not u.has("x") or not u.has("y") or not (u["x"] is int) or not (u["y"] is int):
			return "不是自由座標"
		var x: int = u["x"]
		var y: int = u["y"]
		if x % 50 != 0 or y % 50 != 0:
			return "沒量化"
		var ox := x if team == 0 else 16000 - x
		var dmax: int = 15800 if r.fullfield != 0 and team == 0 or r.fullfield == 1 else r.depth
		if ox < 200 or ox > dmax or y < 200 or y > 8800:
			return "出界 (%d,%d)" % [x, y]
		for q in pts:
			if (q.x - x) * (q.x - x) + (q.y - y) * (q.y - y) < r.spacing * r.spacing:
				return "太近"
		for e in enemy:
			if (e.x - x) * (e.x - x) + (e.y - y) * (e.y - y) < 1500 * 1500:
				return "離敵太近"
		pts.append(Vector2i(x, y))
		var t: int = u["type"]
		if (r.pool_of(team) >> t) & 1 == 0:
			return "卡池"
		per[t] = int(per.get(t, 0)) + 1
		if r.type_cap > 0 and per[t] > r.type_cap:
			return "單種"
		spent += D.cost(t)
	if spent > r.budget_of(team) or a.units.size() > r.unit_cap:
		return "預算或人數"
	return ""

static func free_rules(spacing := 800, depth := 7500, full := 0):
	var r = RSET.standard()
	r.deploy = "free"
	r.spacing = spacing
	r.depth = depth
	r.fullfield = full
	return r

## 第七輪 N2：校驗碼正確、內容亂填的代碼一律回報失敗，不能中斷（中斷時回傳空字典）。
func _fuzz_code(prefix: String, body: Variant) -> String:
	var b64 := Marshalls.utf8_to_base64(JSON.stringify(body)).replace("+", "-").replace("/", "_").replace("=", "")
	return "%s.%s.%s" % [prefix, b64, b64.sha256_text().substr(0, 6)]

func _sv_clear(SV) -> void:
	for base in ["user://t7_save.json", "user://t7_settings.json"]:
		for suf in ["", ".bak", ".tmp", ".bak.tmp", ".corrupt1", ".corrupt2", ".corrupt3"]:
			if FileAccess.file_exists(base + suf):
				DirAccess.remove_absolute(base + suf)
	SV.fail_inject = {}
	SV.pending = {}

func _sv_put(path: String, txt: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(txt)
	f.close()

class FakeSteam:
	var stores := 0
	func setAchievement(_id): pass
	func run_callbacks(): pass
	func storeStats() -> bool:
		stores += 1
		return stores > 1

## 1.1.0 A4：原本在 v16／v161／v100 測試組裡的共用替身，拆成功能組後放這裡。
class FakeU:
	var team := 0
	var type := 0
	var kills := 0
	var summon := false
	func _init(t, ty, k, s := false):
		team = t
		type = ty
		kills = k
		summon = s

class FakeAch extends Node:
	signal user_stats_stored(game, result)
	var stores := 0
	var set_ids: Array = []
	var fail_set := false
	func setAchievement(id): set_ids.append(id); return not fail_set
	func storeStats(): stores += 1; return true
	func run_callbacks(): pass

class FakeLB extends Node:
	signal leaderboard_find_result(handle, found)
	signal leaderboard_scores_downloaded(msg, handle, result)
	signal leaderboard_score_uploaded(success, handle, this_score)
	var finds: Array = []
	var ups: Array = []
	var names := {7: "daily_100_v1", 8: "daily_100_v1", 9: "daily_100_v1", 11: "weekly_5"}
	func findOrCreateLeaderboard(n, _a, _b): finds.append(n)
	func findLeaderboard(n): finds.append(n)
	func getLeaderboardName(h): return names.get(h, "")
	func uploadLeaderboardScore(sc, _keep, det, h): ups.append([sc, det, h])
	func downloadLeaderboardEntries(_a, _b, _c, _h): pass
	func run_callbacks(): pass

func _put(path: String, txt: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(txt)
	f.close()

class FakePlat:
	func isCloudEnabledForAccount(): return true
	func isCloudEnabledForApp(): return true
	func getFileCount(): return 3
	func getFileNameAndSize(i): return {"name": ["save.json", "save.json.bak", "settings.json"][i], "size": 10}
	func getCurrentBetaName(): return {"ret": true, "name": "beta"}
