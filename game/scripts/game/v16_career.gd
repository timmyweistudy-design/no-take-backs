extends RefCounted
## V1.6 #12 生涯：兵種熟練度（只看、不改數值）＋殘局實驗簿（同一題存多份命名方案與成績）。純函式（測試共用）。

## 熟練度：每場出場的兵種 +1，這種兵擊倒幾隻再加幾點。門檻故意低（不逼刷）：5 級。
const LV := [0, 5, 15, 35, 70, 120]

static func gain(units: Array) -> Dictionary:
	var out := {}
	for u in units:
		if u.team != 0 or u.summon:
			continue
		var k := str(int(u.type))
		if not out.has(k):
			out[k] = 1
		out[k] = int(out[k]) + int(u.kills)
	return out

static func add(m: Dictionary, g: Dictionary) -> Array:
	var ups: Array = []   # 升級的兵種
	for k in g:
		var before := level(int(m.get(k, 0)))
		m[k] = int(m.get(k, 0)) + int(g[k])
		if level(int(m[k])) > before:
			ups.append(int(k))
	return ups

static func level(xp: int) -> int:
	var lv := 0
	for i in LV.size():
		if xp >= int(LV[i]):
			lv = i
	return lv

static func next_at(xp: int) -> int:
	var lv := level(xp)
	return int(LV[lv + 1]) if lv + 1 < LV.size() else -1

## 實驗簿：每關最多 NB_MAX 份 {"n": 名稱, "u": [[兵種, 欄, 列]…], "r": [星, 剩%, 花費] 或 []}
const NB_MAX := 5

static func units_of(a) -> Array:
	var out: Array = []
	for u in a.units:
		out.append([int(u["type"]), int(u["col"]), int(u["row"])])
	out.sort()
	return out

static func nb_save(nb: Dictionary, pid: String, name: String, units: Array) -> bool:
	var lst: Array = nb.get(pid, [])
	for e in lst:
		if e["u"] == units:
			return false   # 一模一樣的已經存過
	if lst.size() >= NB_MAX:
		return false
	lst.append({"n": name, "u": units, "r": []})
	nb[pid] = lst
	return true

## 打完一場：和存過的方案一樣就把成績寫進去（留最好的）
static func nb_result(nb: Dictionary, pid: String, units: Array, stars: int, rem: int, spent: int) -> void:
	for e in nb.get(pid, []):
		if e["u"] == units:
			var r: Array = e["r"]
			if r.is_empty() or stars > int(r[0]) or (stars == int(r[0]) and rem > int(r[1])):
				e["r"] = [stars, rem, spent]
