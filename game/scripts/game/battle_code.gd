extends RefCounted
## 對戰代碼（第三輪 F3）：把雙方陣型、規則版本、數值摘要編成一串，貼給朋友就能看同一場。
## 格式：NTB2.<base64url(JSON)>.<校驗 6 碼>。JSON：{a: 藍方陣型代碼, b: 紅方陣型代碼, r: 規則版本, d: 數值摘要}
## 規則或數值不同時仍可以播，但結果可能不同，所以解碼會回報 mismatch 讓畫面提示。

const Army = preload("res://scripts/core/army.gd")
const D = preload("res://scripts/core/unit_defs.gd")

static func encode(a0, a1) -> String:
	var j := JSON.stringify({"a": a0.to_code(), "b": a1.to_code(), "r": D.RULES_VERSION, "d": D.data_digest()})
	var body := Marshalls.utf8_to_base64(j).replace("+", "-").replace("/", "_").replace("=", "")
	return "NTB2.%s.%s" % [body, body.sha256_text().substr(0, 6)]

## 回傳 {ok, why, a0, a1, mismatch}
static func decode(code: String) -> Dictionary:
	var c := code.strip_edges()
	var parts := c.split(".")
	if parts.size() != 3 or parts[0] != "NTB2":
		return {"ok": false, "why": "format"}
	if parts[1].sha256_text().substr(0, 6) != parts[2]:
		return {"ok": false, "why": "checksum"}
	var b64 := parts[1].replace("-", "+").replace("_", "/")
	while b64.length() % 4 != 0:
		b64 += "="
	var j = JSON.parse_string(Marshalls.base64_to_utf8(b64))
	if not j is Dictionary or not j.has("a") or not j.has("b"):
		return {"ok": false, "why": "body"}
	var a0 := Army.new(0, 100)
	var a1 := Army.new(1, 100)
	if a0.load_code(str(j["a"])) != "" or a1.load_code(str(j["b"])) != "":
		return {"ok": false, "why": "army"}
	var mismatch: bool = str(j.get("r", "")) != D.RULES_VERSION or str(j.get("d", "")) != D.data_digest()
	return {"ok": true, "why": "", "a0": a0, "a1": a1, "mismatch": mismatch}
