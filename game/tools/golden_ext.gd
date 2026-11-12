extends SceneTree
## 1.2.0 擴充規則 v1 金標準產生器：寫 tests/golden/ext_v1.json（29 場：位元 2／4／8／14／1／16／31 各 4 場＋協同技 1 場；第 11 大類追加後 12 場）。
## 只在擴充規則還沒公開前重產（第 7 大類 Codex 審查修正後重產過一次）；公開後改數值要升 EXT_VERSION、另存新檔。
## 用法（game/ 下）：$GODOT --headless --path . -s tools/golden_ext.gd
const Sim = preload("res://scripts/core/battle_sim.gd")
const AI = preload("res://scripts/core/ai_army.gd")
const RS = preload("res://scripts/core/ruleset.gd")

func _run(r, seed: int, rng: RandomNumberGenerator, extra: Dictionary) -> Dictionary:
	rng.seed = seed
	var s = Sim.new(AI.build(0, 100, rng)["army"], AI.build(1, 100, rng)["army"], r)
	s.run_to_end()
	var c := {"bits": int(r.ext_skills), "seed": seed, "fp": str(s.fingerprint), "tick": s.tick, "winner": s.winner}
	c.merge(extra)
	return c

func _init() -> void:
	var cases: Array = []
	for bits in [2, 4, 8, 14, 1, 16, 31]:   # 第 11 大類追加 1（架盾）、16（迴馬）、31（全開）；前 17 場位元組不變（產生後比對）
		var r = RS.standard()
		r.ext_skills = bits
		var rng := RandomNumberGenerator.new()
		for k in 4:
			cases.append(_run(r, 9001 + k * 7919, rng, {}))
	var rs = RS.standard()
	rs.synergy = true
	cases.append(_run(rs, 31337, RandomNumberGenerator.new(), {"synergy": true}))
	var out := {"about": "1.2.0 擴充規則 v1 金標準（docs/rules-ext-v1.md）。改技能數值要升 EXT_VERSION 並另存新檔，不覆蓋這份。產生器 tools/golden_ext.gd。", "ext_version": RS.EXT_VERSION, "cases": cases}
	var f := FileAccess.open("res://tests/golden/ext_v1.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out, " ", true))
	f.close()
	print("golden_ext ok ", cases.size())
	quit(0)
