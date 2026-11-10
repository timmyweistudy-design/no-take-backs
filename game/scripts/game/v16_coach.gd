extends RefCounted
## V1.6 #9 差一子教練：輸了之後，只動一隻兵（往前、後、上、下一格）有沒有能翻盤的擺法。
## 有限候選（最多 LIMIT 次模擬），格子部署才做；殘局用同一個判定（puzzles.gd outcome）。純函式（可在背景執行緒跑）。
const Army = preload("res://scripts/core/army.gd")
const Sim = preload("res://scripts/core/battle_sim.gd")
const PZ = preload("res://scripts/game/puzzles.gd")

const LIMIT := 15
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(0, 1)]   # 自己視角：前、後、上、下

## 候選：[第幾隻, 新欄, 新列]；不動殘局的固定兵；照「往前優先、前排先」的固定順序
static func candidates(a: Army, pz := {}) -> Array:
	var idx: Array = range(a.units.size())
	var fwd := 1 if a.team == 0 else -1
	idx.sort_custom(func(p, q):
		var cp: int = int(a.units[p]["col"]) * fwd
		var cq: int = int(a.units[q]["col"]) * fwd
		return cp > cq if cp != cq else p < q)
	var out: Array = []
	for d in DIRS:
		for i in idx:
			var u: Dictionary = a.units[i]
			var c := int(u["col"])
			var r := int(u["row"])
			if not pz.is_empty() and PZ.is_fixed(pz, c, r):
				continue
			var nc: int = c + int(d.x) * fwd
			var nr: int = r + int(d.y)
			var b: Army = a.copy()
			b.units.remove_at(i)
			if b.check_place(int(u["type"]), nc, nr) == "":
				out.append([i, nc, nr])
	return out

static func moved(a: Army, cand: Array) -> Army:
	var b: Army = a.copy()
	var u: Dictionary = b.units[int(cand[0])].duplicate()
	b.units.remove_at(int(cand[0]))
	u["col"] = int(cand[1])
	u["row"] = int(cand[2])
	b.units.append(u)
	return b

static func wins(a0: Army, a1: Army, rules, pz: Dictionary) -> bool:
	var s = Sim.new(a0.copy(), a1.copy(), rules)
	s.fast = true
	s.run_to_end()
	if pz.is_empty():
		return s.winner == 0
	return bool(PZ.outcome(pz, s, 0)["ok"])

## 能不能給教練：格子部署、沒有軍令（殘局的定時技能、手動技能局都不做）
static func supported(a0: Army, rules, pz: Dictionary) -> bool:
	if a0.deploy == "free" or a0.units.is_empty():
		return false
	if not pz.is_empty() and pz.has("cmd"):
		return false
	return rules == null or int(rules.cmd_mask[0]) == 0

## 回傳 {"found": bool, "tries": n, "i", "type", "from": Vector2i, "to": Vector2i, "army": 改好的陣}
static func search(a0: Army, a1: Army, rules, pz := {}, limit := LIMIT) -> Dictionary:
	var tries := 0
	for cand in candidates(a0, pz):
		if tries >= limit:
			break
		tries += 1
		var b := moved(a0, cand)
		if wins(b, a1, rules, pz):
			var u: Dictionary = a0.units[int(cand[0])]
			return {"found": true, "tries": tries, "i": int(cand[0]), "type": int(u["type"]),
				"from": Vector2i(int(u["col"]), int(u["row"])), "to": Vector2i(int(cand[1]), int(cand[2])), "army": b}
	return {"found": false, "tries": tries}
