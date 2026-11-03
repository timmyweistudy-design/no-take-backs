extends RefCounted
## 困難 AI（第四輪）：真的「讀你上一局」。
## 第 1 局沒有資訊 → 用原型模板組（和普通 AI 同一套，不會比普通弱）。
## 第 2 局起 → 準備幾個候選陣型（反制庫裡最接近的那筆、兩套模板陣、會讀對方的落子 AI 陣），
## 各拿去和你上一局的陣型模擬一場，挑打得最好的。只看你「上一局」公開過的陣型，不偷看這一局。
## 遊戲（game_screens._hard_ai）和反制庫驗證（tools/make_counter_lib.gd）共用這一個函式。
## 第三輪的做法（查不到反制就退回落子 AI）在第四輪新模板加入後，對驗證池反而比普通 AI 弱（73.0% vs 74.0%），所以改成這樣。

const D = preload("res://scripts/core/unit_defs.gd")
const Army = preload("res://scripts/core/army.gd")
const Sim = preload("res://scripts/core/battle_sim.gd")
const AI = preload("res://scripts/core/ai_army.gd")
const AIT = preload("res://scripts/core/ai_turns.gd")
const F = preload("res://scripts/core/formations.gd")
const RS = preload("res://scripts/core/ruleset.gd")

## known：玩家上一局的兵（藍方座標）；entries：反制庫；回傳紅方陣型。
## pool：紅方卡池遮罩（-1＝全部）；rules：第五輪 Ruleset（null＝標準）。
## 反制庫只在「規則和標準一樣」時用（第五輪 §3.2）；大軍或長局時少一個候選（效能探測：40＋40、150 秒一場可達數秒）。
static func build(known: Array, entries: Array, rng: RandomNumberGenerator, pool := -1, rules = null) -> Army:
	if pool < 0:
		pool = RS.all_pool()
	var bud: int = 100 if rules == null else rules.budget_of(1)
	var cands: Array = []
	cands.append(AI.build(1, bud, rng, -1, pool, rules)["army"])
	if known.is_empty():
		return cands[0]
	var heavy: bool = rules != null and (rules.unit_cap > 24 or rules.ticks > 1800)
	if not heavy:
		cands.append(AI.build(1, bud, rng, -1, pool, rules)["army"])
	var full := AIT.build_full(1, rng, 2, known, pool, rules)
	cands.append(full)
	if rules == null or _standard_like(rules):
		var lib := pick_counter(entries, known, pool)
		if lib != null:
			cands.append(lib)
	var me := Army.new(0, 100 if rules == null else rules.budget_of(0))
	for u in known:
		me.units.append({"type": int(u["type"]), "col": int(u["col"]), "row": int(u["row"])})
	var best: Army = cands[0]
	var bs := -(1 << 40)
	for c in cands:
		var s = Sim.new(me.copy(), c.copy(), rules)
		s.fast = true
		s.run_to_end()
		var sc: int = (1000000 + s.power(1)) if s.winner == 1 else (s.power(1) - s.power(0))
		if sc > bs:
			bs = sc
			best = c
	return best

## 反制庫：組成最接近玩家陣型的原型的反制（距離 ≤40）；用到未開放兵種的不算。
static func _standard_like(r) -> bool:
	return r.budget_of(0) == 100 and r.budget_of(1) == 100 and r.unit_cap == 24 and r.type_cap == 0 and r.sim_is_legacy()

static func pick_counter(entries: Array, known: Array, pool: int) -> Army:
	if entries.is_empty():
		return null
	var mine := D.zeros()
	for u in known:
		mine[int(u["type"])] += D.cost(int(u["type"]))
	var best = null
	var bd := 1 << 30
	for e in entries:
		var pc: Array = e["proto_comp"]
		var d := 0
		for k in mine.size():
			d += absi((int(pc[k]) if k < pc.size() else 0) - int(mine[k]))
		if d < bd:
			bd = d
			best = e
	if best == null or bd > 40:
		return null
	var a := Army.new(1, 100)
	if a.load_code(str(best["code"])) != "":
		return null
	for u in a.units:
		if not RS.has(pool, int(u["type"])):
			return null
	return a
