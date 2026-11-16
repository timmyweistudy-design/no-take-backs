extends RefCounted
## 1.6.0 B15（P6.2；S5）配對棋課紀錄：覆盤裡「只改一隻」重算過的一組對照，存成一則棋課。
## 一則＝原局碼＋改局碼（同一個對手、同一份規則與軍令）＋改了什麼（四類：換兵、移位、新增、拿掉）＋兩邊的結果摘要＋分岔 tick。
## 只存「此條件下已驗證」的東西：重算完成、世代相符才存；讀回時用兩個碼各自重算，結果要和存的時候一樣才算還原。
## 純邏輯（不碰畫面、不碰存檔）：存檔欄位 Save.data["lessons"]，畫面在 replay_view.gd。
## 「第一次戰力不同」只是分岔點，不是因果——畫面上照 rv_note 說明。
const BattleCode = preload("res://scripts/game/battle_code.gd")
const Army = preload("res://scripts/core/army.gd")

const VERSION := 1
const CAP := 30                 # 容量：滿了不自動丟舊的（玩家自己刪）
const KINDS := ["swap", "move", "add", "remove"]
const CODE_MAX := 8000          # 和 BattleCode.decode 的上限一致

## 判斷改了哪一類（只改一隻時才有意義；改了不只一隻或沒改回 ""）。
static func kind_of(orig, now) -> String:
	if orig.deploy == "free":
		var ma := {}
		for u in orig.units:
			ma[int(u.get("eid", -1))] = u
		var seen := {}
		var out := ""
		var n := 0
		for u in now.units:
			var e := int(u.get("eid", -1))
			seen[e] = true
			if not ma.has(e):
				out = "add"
				n += 1
			elif int(ma[e]["type"]) != int(u["type"]):
				out = "swap"
				n += 1
			elif int(ma[e]["x"]) != int(u["x"]) or int(ma[e]["y"]) != int(u["y"]):
				out = "move"
				n += 1
		for e in ma:
			if not seen.has(e):
				out = "remove"
				n += 1
		return out if n == 1 else ""
	var a := {}
	var b := {}
	for u in orig.units:
		a[Vector2i(int(u["col"]), int(u["row"]))] = int(u["type"])
	for u in now.units:
		b[Vector2i(int(u["col"]), int(u["row"]))] = int(u["type"])
	var gone: Array = []
	var added: Array = []
	var swapped := 0
	for k in a:
		if not b.has(k):
			gone.append(k)
		elif b[k] != a[k]:
			swapped += 1
	for k in b:
		if not a.has(k):
			added.append(k)
	if swapped == 1 and gone.is_empty() and added.is_empty():
		return "swap"
	if swapped == 0 and gone.size() == 1 and added.size() == 1:
		return "move" if a[gone[0]] == b[added[0]] else "swap"
	if swapped == 0 and gone.size() == 1 and added.is_empty():
		return "remove"
	if swapped == 0 and gone.is_empty() and added.size() == 1:
		return "add"
	return ""

## 改了哪種兵：[原本的兵種, 改成的兵種]（-1＝沒有：新增的原本、拿掉的改成）。給棋課本列名字用。
static func types_of(orig, now) -> Array:
	var k := kind_of(orig, now)
	if k == "":
		return [-1, -1]
	var key := func(u) -> String:
		return ("%d" % int(u.get("eid", -1))) if orig.deploy == "free" else ("%d,%d" % [int(u["col"]), int(u["row"])])
	var a := {}
	var b := {}
	for u in orig.units:
		a[key.call(u)] = u
	for u in now.units:
		b[key.call(u)] = u
	var from := -1
	var to := -1
	for kk in a:
		if not b.has(kk) or int(b[kk]["type"]) != int(a[kk]["type"]) or (orig.deploy == "free" and (int(b[kk]["x"]) != int(a[kk]["x"]) or int(b[kk]["y"]) != int(a[kk]["y"]))):
			from = int(a[kk]["type"])
	for kk in b:
		if not a.has(kk) or int(b[kk]["type"]) != int(a[kk]["type"]) or (orig.deploy == "free" and (int(b[kk]["x"]) != int(a[kk]["x"]) or int(b[kk]["y"]) != int(a[kk]["y"]))):
			to = int(b[kk]["type"])
	if k == "move":
		to = from if to == -1 else to
	return [from, to]

## 結果摘要：[勝方, 剩餘%, 結束 tick]
static func outcome(res: Dictionary) -> Array:
	return [int(res.get("winner", -1)), int(res.get("rem", 0)), int(res.get("ticks", 0))]

## 做一則。base／alt＝review_run 的結果（重算完成的）。
static func make(orig, alt, enemy, rules, cmds: Array, base: Dictionary, res: Dictionary, div: int) -> Dictionary:
	var o := BattleCode.encode(orig, enemy, rules, cmds)
	var a := BattleCode.encode(alt, enemy, rules, cmds)
	return {"v": VERSION, "id": (o + "|" + a).sha256_text().substr(0, 16), "o": o, "a": a, "k": kind_of(orig, alt), "ro": outcome(base), "ra": outcome(res), "div": div, "u": types_of(orig, alt)}

## 加進清單：回 [新清單, 狀態]。狀態：ok／dup（同一組已存過，不重複）／full（滿了）／bad（這則不合格）。
## 不改傳進來的清單。
static func add(list: Array, e: Dictionary) -> Array:
	if not valid(e):
		return [list, "bad"]
	for x in list:
		if x is Dictionary and str(x.get("id", "")) == str(e["id"]):
			return [list, "dup"]
	if list.size() >= CAP:
		return [list, "full"]
	var out := list.duplicate(true)
	out.append(e.duplicate(true))
	return [out, "ok"]

static func remove(list: Array, id: String) -> Array:
	var out: Array = []
	for x in list:
		if not (x is Dictionary and str(x.get("id", "")) == id):
			out.append(x)
	return out

static func _is_int(x) -> bool:
	return x is int or (x is float and float(x) == floorf(float(x)))

static func _trio(v) -> bool:
	if not v is Array or v.size() != 3:
		return false
	for x in v:
		if not _is_int(x) or absf(float(x)) > 1.0e7:
			return false
	return int(v[0]) >= -1 and int(v[0]) <= 1 and int(v[1]) >= 0 and int(v[1]) <= 100 and int(v[2]) >= 0 and int(v[2]) < 1000000

static func valid(e) -> bool:
	if not e is Dictionary:
		return false
	for k in ["id", "o", "a", "k"]:
		if not e.get(k) is String:
			return false
	var vv = e.get("v")
	if not _is_int(vv) or float(vv) < 1.0 or float(vv) > 1000.0:
		return false   # 先限範圍再轉整數（超大浮點不能溢位繞過「版本比遊戲新」）
	if str(e["o"]).length() > CODE_MAX or str(e["a"]).length() > CODE_MAX or str(e["id"]).length() != 16:
		return false
	if not str(e["k"]) in KINDS:
		return false
	if (str(e["o"]) + "|" + str(e["a"])).sha256_text().substr(0, 16) != str(e["id"]):
		return false   # 碼被改過（壞筆）
	if not _trio(e.get("ro")) or not _trio(e.get("ra")):
		return false
	var d = e.get("div", -1)
	return _is_int(d) and float(d) >= -1.0 and float(d) < 1000000.0

## 存檔讀回：逐則驗型；壞的丟掉（回 [好的, 丟了幾則]）；JSON 讀回的整數是浮點，轉回整數。超過容量只留前 CAP 則。
static func sanitize(raw) -> Array:
	var out: Array = []
	var bad := 0
	if not raw is Array:
		return [out, 0 if raw == null else 1]
	var ids := {}
	for e in raw:
		if out.size() >= CAP or not valid(e) or ids.has(str(e["id"])):
			bad += 1
			continue
		ids[str(e["id"])] = true
		var uu = e.get("u", [-1, -1])
		var ut: Array = [-1, -1]
		if uu is Array and uu.size() == 2 and _is_int(uu[0]) and _is_int(uu[1]) and float(uu[0]) >= -1.0 and float(uu[0]) < 64.0 and float(uu[1]) >= -1.0 and float(uu[1]) < 64.0:   # 先比浮點範圍再轉整數（Codex B15 r2）
			ut = [int(uu[0]), int(uu[1])]   # 兵種名只是顯示用：壞了就不顯示，不丟整則
		out.append({"v": int(e["v"]), "id": str(e["id"]), "o": str(e["o"]), "a": str(e["a"]), "k": str(e["k"]),
			"ro": [int(e["ro"][0]), int(e["ro"][1]), int(e["ro"][2])], "ra": [int(e["ra"][0]), int(e["ra"][1]), int(e["ra"][2])], "div": int(e.get("div", -1)), "u": ut})
	return [out, bad]

## 讀回一則：解兩個碼。回 {ok, why, orig, alt, enemy, rules, cmds, stale}。
## why：ver（存的版本比遊戲新）／code（碼壞）／pair（兩個碼不是同一個對手、同一份規則）
## stale＝規則或資料版本和現在不同（BattleCode 的 mismatch）：照樣打開，但結果要重算，不拿存的結果當真。
static func restore(e: Dictionary) -> Dictionary:
	if int(e.get("v", 0)) > VERSION:
		return {"ok": false, "why": "ver"}
	var o := BattleCode.decode(str(e.get("o", "")))
	var a := BattleCode.decode(str(e.get("a", "")))
	if not o.get("ok", false) or not a.get("ok", false):
		return {"ok": false, "why": "code"}
	var ro = o.get("rules")
	var ra = a.get("rules")
	if o["a1"].to_code() != a["a1"].to_code() or int(o["a1"].budget) != int(a["a1"].budget) or int(o["a0"].budget) != int(a["a0"].budget) or (ro == null) != (ra == null) or (ro != null and ro.to_code() != ra.to_code()) or o.get("cmds", []) != a.get("cmds", []):
		return {"ok": false, "why": "pair"}
	var orig = o["a0"]
	var alt = a["a0"]
	if orig.deploy == "free":
		assign_eids(orig, alt)
	return {"ok": true, "why": "", "orig": orig, "alt": alt, "enemy": o["a1"], "rules": ro, "cmds": o.get("cmds", []), "stale": bool(o.get("mismatch", false)) or bool(a.get("mismatch", false))}

## 全場陣型讀回後重新配編輯識別：一模一樣的兩隊一一配對，剩下的（改了的那一隻）照順序配；改局多的那隻給新號。
static func assign_eids(orig, alt) -> void:
	for i in orig.units.size():
		orig.units[i]["eid"] = i
	var used := {}
	var left: Array = []
	for j in alt.units.size():
		var v: Dictionary = alt.units[j]
		var hit := -1
		for i in orig.units.size():
			var u: Dictionary = orig.units[i]
			if not used.has(i) and int(u["type"]) == int(v["type"]) and int(u["x"]) == int(v["x"]) and int(u["y"]) == int(v["y"]):
				hit = i
				break
		if hit >= 0:
			used[hit] = true
			v["eid"] = hit
		else:
			left.append(j)
	var free_i: Array = []
	for i in orig.units.size():
		if not used.has(i):
			free_i.append(i)
	var nxt: int = orig.units.size()
	for j in left:
		if not free_i.is_empty():
			alt.units[j]["eid"] = free_i.pop_front()
		else:
			alt.units[j]["eid"] = nxt
			nxt += 1

## 重算後和存的結果一樣嗎（20/20 還原的判準）
static func same_result(e: Dictionary, base: Dictionary, res: Dictionary) -> bool:
	return outcome(base) == Array(e.get("ro", [])) and outcome(res) == Array(e.get("ra", []))
