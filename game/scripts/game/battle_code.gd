extends RefCounted
## 對戰代碼（第三輪 F3）：把雙方陣型、規則版本、數值摘要編成一串，貼給朋友就能看同一場。
## 格式：NTB2.<base64url(JSON)>.<校驗 6 碼>。JSON：{a/b: 雙方陣型代碼, ba/bb: 雙方預算, r: 規則版本, d: 數值摘要}
## 規則或數值不同時仍可以播，但結果可能不同，所以解碼會回報 mismatch 讓畫面提示。

const Army = preload("res://scripts/core/army.gd")
const D = preload("res://scripts/core/unit_defs.gd")
const RSET = preload("res://scripts/core/ruleset.gd")
## 第五輪：自訂規則的對戰代碼用 NTB3（多一欄 rules＝規則代碼）。標準規則仍輸出 NTB2，位元組和 1.3.0 相同。

## 這組規則能不能用舊格式 NTB2 重播（模擬走舊路徑、陣型在舊的人數上限內）。
static func needs_v3(rules) -> bool:
	# Codex 實作第 1 輪：卡池、人數、單種上限有任何不標準就用 NTB3，分享後規則不會遺失
	return rules != null and (not rules.sim_is_legacy() or not load("res://scripts/game/presets.gd").deploy_standard(rules))

static func encode(a0, a1, rules = null) -> String:
	if needs_v3(rules):
		var j3 := JSON.stringify({"a": a0.to_code(), "b": a1.to_code(), "ba": a0.budget, "bb": a1.budget, "r": D.RULES_VERSION, "d": D.data_digest(), "rules": rules.to_code()})
		var body3 := Marshalls.utf8_to_base64(j3).replace("+", "-").replace("/", "_").replace("=", "")
		return "NTB3.%s.%s" % [body3, body3.sha256_text().substr(0, 6)]
	var j := JSON.stringify({"a": a0.to_code(), "b": a1.to_code(), "ba": a0.budget, "bb": a1.budget, "r": D.RULES_VERSION, "d": D.data_digest()})
	var body := Marshalls.utf8_to_base64(j).replace("+", "-").replace("/", "_").replace("=", "")
	return "NTB2.%s.%s" % [body, body.sha256_text().substr(0, 6)]

## 回傳 {ok, why, a0, a1, mismatch, rules}（NTB2 的 rules＝null＝用 1.3.0 舊判定重播）
static func decode(code: String) -> Dictionary:
	var c := code.strip_edges()
	if c.length() > 8000:
		return {"ok": false, "why": "format"}
	var parts := c.split(".")
	if parts.size() != 3 or (parts[0] != "NTB2" and parts[0] != "NTB3"):
		return {"ok": false, "why": "format"}
	if parts[1].sha256_text().substr(0, 6) != parts[2]:
		return {"ok": false, "why": "checksum"}
	var b64 := parts[1].replace("-", "+").replace("_", "/")
	while b64.length() % 4 != 0:
		b64 += "="
	var j = JSON.parse_string(Marshalls.base64_to_utf8(b64))
	if not j is Dictionary or not j.has("a") or not j.has("b"):
		return {"ok": false, "why": "body"}
	# 預算也編進去（Codex S5 #1：遠征敵軍超過 100 金、殘局低預算時，原本會被當成 100）
	var ba := int(j.get("ba", 100))
	var bb := int(j.get("bb", 100))
	if ba < 1 or ba > 400 or bb < 1 or bb > 400:
		return {"ok": false, "why": "budget"}
	var a0 := Army.new(0, ba)
	var a1 := Army.new(1, bb)
	var rules = null
	if parts[0] == "NTB3":
		var rd: Dictionary = RSET.from_code(str(j.get("rules", "")))
		if not rd["ok"]:
			return {"ok": false, "why": "rules"}
		rules = rd["rules"]
		if rules.budget_of(0) != ba or rules.budget_of(1) != bb:
			return {"ok": false, "why": "budget"}
		for pair in [[a0, 0], [a1, 1]]:
			pair[0].apply_rules(rules, pair[1])
	if a0.load_code(str(j["a"])) != "" or a1.load_code(str(j["b"])) != "":
		return {"ok": false, "why": "army"}
	var full_duel: bool = rules != null and rules.is_free() and rules.fullfield == RSET.FULL_DUEL
	if rules != null and not full_duel and (not a0.has_combat() or not a1.has_combat()):
		return {"ok": false, "why": "army"}   # NTB3（第五輪新格式）：雙方各至少 1 隻戰鬥兵；舊 NTB2 不加這條（相容）
	if rules != null and rules.is_free() and rules.fullfield != RSET.FULL_NONE:
		# 第六輪（Codex 實作第 1 輪 #3）：全場的跨隊條件——兩軍任兩隻至少隔 ENEMY_GAP；明牌全場的 AI（紅）只在自己半場
		var g2: int = RSET.ENEMY_GAP * RSET.ENEMY_GAP
		for u in a0.units:
			var p := Army.pos_of(u)
			for v in a1.units:
				var q := Army.pos_of(v)
				if (p.x - q.x) * (p.x - q.x) + (p.y - q.y) * (p.y - q.y) < g2:
					return {"ok": false, "why": "army"}
		if rules.fullfield == RSET.FULL_AI:
			for v in a1.units:
				if a1.own_x(Army.pos_of(v).x) > rules.depth:
					return {"ok": false, "why": "army"}
	# 輪流落子的指令紀錄（cmds）目前不支援：代碼只證明「最後陣型合法」，不證明輪序（Codex 實作第 1 輪 #10，見方案 §11 已知限制）
	if j.has("cmds"):
		return {"ok": false, "why": "body"}
	var mismatch: bool = str(j.get("r", "")) != D.RULES_VERSION or str(j.get("d", "")) != D.data_digest()
	return {"ok": true, "why": "", "a0": a0, "a1": a1, "mismatch": mismatch, "rules": rules}
