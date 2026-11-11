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

## V1.6.1 A1 戰功章：每種兵 3 個（出場 MEDAL[0] 場、擊倒 MEDAL[1] 隻、MVP MEDAL[2] 次）。只看、不改數值。
## medals[兵種] = [出場, 擊倒, MVP]
const MEDAL := [20, 50, 5]
static func medal_add(md: Dictionary, units: Array, mvp_type: int) -> void:
	var seen := {}
	for u in units:
		if u.team != 0 or u.summon:
			continue
		var k := str(int(u.type))
		var e: Array = md.get(k, [0, 0, 0])
		if not seen.has(k):
			e[0] = int(e[0]) + 1
			seen[k] = true
		e[1] = int(e[1]) + int(u.kills)
		md[k] = e
	if mvp_type >= 0 and md.has(str(mvp_type)):
		md[str(mvp_type)][2] = int(md[str(mvp_type)][2]) + 1

static func medals_of(md: Dictionary, t: int) -> Array:
	var e: Array = md.get(str(t), [0, 0, 0])
	var out: Array = []
	for i in 3:
		out.append(int(e[i]) >= int(MEDAL[i]))
	return out

## 實驗簿：每關最多 NB_MAX 份 {"n": 名稱, "u": [[兵種, 欄, 列]…], "r": [星, 剩%, 花費] 或 []}
const NB_MAX := 5

## 格子兵＝[兵種, 欄, 列]；自由兵（試煉）＝[兵種, x, y, 1]
static func units_of(a) -> Array:
	var out: Array = []
	for u in a.units:
		if u.has("x"):
			out.append([int(u["type"]), int(u["x"]), int(u["y"]), 1])
		else:
			out.append([int(u["type"]), int(u["col"]), int(u["row"])])
	out.sort()
	return out

## V1.6.1 F1：工坊、出題台、一陣三考的 puzzle_id 都是 "ws"，實驗簿要用題目內容當鍵。
## 回傳 [短鍵（存檔鍵長上限 24）, 完整雜湊（方案旁另存，讀取時比對，撞鍵就當不同題）]。一陣三考的題組是固定資料，用題組 id。
const TEXT_KEYS := ["id", "ch", "zh", "en", "sc", "ja", "hint_zh", "hint_en", "hint_sc", "hint_ja", "best", "star2", "star3"]
static func ws_key(pz: Dictionary) -> Array:
	if pz.has("trio"):
		var tk := "q" + str(pz["trio"]).substr(0, 20)
		return [tk, tk]
	var c := {}
	for k in pz:
		if str(k) in TEXT_KEYS:
			continue
		var v = pz[k]
		if v is Array:
			var a: Array = v.duplicate(true)
			a.sort()   # 同一題、兵的順序不同也算同一題
			v = a
		c[str(k)] = v
	var full := JSON.stringify(c, "", true).md5_text()
	return ["w" + full.substr(0, 12), full]

## 某題的方案清單（有 h 的要和這題的完整雜湊相同）
static func nb_list(nb: Dictionary, pid: String, h := "") -> Array:
	var out: Array = []
	for e in nb.get(pid, []):
		if h == "" or str(e.get("h", h)) == h:
			out.append(e)
	return out

static func nb_save(nb: Dictionary, pid: String, name: String, units: Array, h := "") -> bool:
	var lst: Array = nb.get(pid, [])
	for e in nb_list(nb, pid, h):
		if e["u"] == units:
			return false   # 一模一樣的已經存過
	if lst.size() >= NB_MAX:
		return false
	var e := {"n": name, "u": units, "r": []}
	if h != "":
		e["h"] = h
	lst.append(e)
	nb[pid] = lst
	return true

## V1.6.1 F8：成績比較：星多 → 剩餘多 → 花費少
static func better(a: Array, b: Array) -> bool:
	if b.size() != 3:
		return true
	if int(a[0]) != int(b[0]):
		return int(a[0]) > int(b[0])
	if int(a[1]) != int(b[1]):
		return int(a[1]) > int(b[1])
	return int(a[2]) < int(b[2])

## 打完一場：和存過的方案一樣就把成績寫進去（留最好的）
static func nb_result(nb: Dictionary, pid: String, units: Array, stars: int, rem: int, spent: int, h := "") -> void:
	for e in nb_list(nb, pid, h):
		if e["u"] == units:
			if better([stars, rem, spent], e["r"]):
				e["r"] = [stars, rem, spent]
