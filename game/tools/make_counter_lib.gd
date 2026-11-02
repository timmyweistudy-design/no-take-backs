extends SceneTree
## 困難 AI 的離線反制庫（第三輪 A3）。
## 原本只有 6 筆、沒有版本：改了平衡，反制庫會悄悄失效。現在：
## ・原型陣＝AI 的 6 種模板 × 4 個種子＝24 種（不同主力兵種、不同排法）
## ・每個原型在訓練池 200 套裡找「交換左右各打一場」勝最多的當反制；兩邊都要贏才收（勝率 ≥0.75）
## ・檔案記下規則版本、數值摘要、產生參數；遊戲讀到版本不符就不用它（退回啟發式），不會用到過期的反制
## ・另外量：困難 AI（scripts/core/hard_ai.gd：反制庫＋模板＋落子 AI 候選，和上一局模擬後挑最好的）對驗證池 100 套的勝率，要高於普通 AI
## 用法：godot --headless --path game --script res://tools/make_counter_lib.gd
const Sim = preload("res://scripts/core/battle_sim.gd")
const Army = preload("res://scripts/core/army.gd")
const AI = preload("res://scripts/core/ai_army.gd")
const AIT = preload("res://scripts/core/ai_turns.gd")
const F = preload("res://scripts/core/formations.gd")
const D = preload("res://scripts/core/unit_defs.gd")
const HardAI = preload("res://scripts/core/hard_ai.gd")
const PATH := "res://data/counter_lib.json"
const SEEDS := 4
const MIN_FIT := 0.75

## a、b 都是藍方（team 0）表示。交換左右各打一場，回傳 a 的得分 0～1（平手算半場）。
static func duel(a: Army, b: Army) -> float:
	var s1 = Sim.new(a.copy(), b.mirrored())
	s1.fast = true
	s1.run_to_end()
	var s2 = Sim.new(b.copy(), a.mirrored())
	s2.fast = true
	s2.run_to_end()
	var sc := (1.0 if s1.winner == 0 else (0.5 if s1.winner < 0 else 0.0)) + (1.0 if s2.winner == 1 else (0.5 if s2.winner < 0 else 0.0))
	return sc / 2.0

func _init() -> void:
	var train := F.training_pool(0)
	var entries: Array = []
	var rng := RandomNumberGenerator.new()
	for ti in AI.TEMPLATES.size():
		for sd in SEEDS:
			rng.seed = 5150 + ti * 101 + sd * 7919
			var proto: Army = AI.build(0, 100, rng, ti)["army"]
			var best := -1
			var best_f := -1.0
			for j in range(0, train.size(), 2):   # 隔一套取一套（100 套候選），全部 200 套要跑 25 分鐘以上
				var f := duel(train[j], proto)
				if f > best_f:
					best_f = f
					best = j
			if best_f >= MIN_FIT:
				entries.append({"template": ti, "seed": sd, "name": AI.TEMPLATES[ti]["name"], "proto_comp": F.composition(proto),
					"code": train[best].to_code(), "fit": best_f})
	# 驗證：困難（反制庫）對普通，面對驗證池 100 套玩家陣型
	var val := F.validation_pool(0)
	var hard_w := 0.0
	var norm_w := 0.0
	var n := 0
	for i in 100:
		var player: Army = val[i]
		rng.seed = 777 + i
		var normal: Army = AI.build(1, 100, rng)["army"]
		rng.seed = 777 + i
		var hard: Army = HardAI.build(player.units, entries, rng)   # 和遊戲同一個函式（第四輪）
		hard_w += 1.0 - duel(player, hard.mirrored())
		norm_w += 1.0 - duel(player, normal.mirrored())
		n += 1
	var out := {"rules": D.RULES_VERSION, "digest": D.data_digest(), "seeds": SEEDS, "min_fit": MIN_FIT, "pool": "training_pool(0) 偶數套",
		"entries": entries, "check": {"vs_validation": n, "hard_winrate": snappedf(hard_w / n, 0.001), "normal_winrate": snappedf(norm_w / n, 0.001)}}
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(out, " "))
	f.close()
	var types := {}
	for e in entries:
		var c: Array = e["proto_comp"]
		var mx := 0
		for k in c.size():
			if c[k] > c[mx]:
				mx = k
		types[mx] = true
	print("COUNTERLIB %d 筆（原型 %d 種、主力兵種涵蓋 %d 種）；困難 AI 對驗證池勝率 %.1f%%、普通 %.1f%%" % [entries.size(), AI.TEMPLATES.size() * SEEDS, types.size(), hard_w / n * 100.0, norm_w / n * 100.0])
	quit(0 if entries.size() >= 12 and hard_w > norm_w else 1)

## 依玩家的組成挑最接近的原型的反制（和遊戲裡的規則一樣：距離 ≤40 才用）。
static func pick(entries: Array, mine: Array) -> Army:
	var best = null
	var bd := 1 << 30
	for e in entries:
		var d := 0
		var pc: Array = e["proto_comp"]
		for k in mine.size():
			d += absi((int(pc[k]) if k < pc.size() else 0) - int(mine[k]))
		if d < bd:
			bd = d
			best = e
	if best != null and bd <= 40:
		var a := Army.new(1, 100)
		if a.load_code(best["code"]) == "":
			return a
	return null
