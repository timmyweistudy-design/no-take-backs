extends RefCounted
## 兵種圖鑑（第二輪方案 R3）：讀 data/codex.json，驗證 ID 與示範，技能說明裡的 {常數名} 換成 unit_defs 的數值。
## 數值只有一個來源（unit_defs.gd）：改平衡時圖鑑的說明自動跟著變，不會說謊。

const D = preload("res://scripts/core/unit_defs.gd")
const Sim = preload("res://scripts/core/battle_sim.gd")
const Army = preload("res://scripts/core/army.gd")

const NOTE_WINS := 5          # 派這個兵種贏幾場解鎖「老兵觀察筆記」

static var _data := {}

static func data() -> Dictionary:
	if _data.is_empty():
		var txt := FileAccess.get_file_as_string("res://data/codex.json")
		var v = JSON.parse_string(txt)
		if v is Dictionary:
			_data = v
		else:
			push_error("codex.json 讀不到或格式錯")
	return _data

static func unit(t: int) -> Dictionary:
	for u in data().get("units", []):
		if int(u["id"]) == t:
			return u
	return {}

static func skill(id: String) -> Dictionary:
	return data().get("skills", {}).get(id, {})

## 取一個欄位的當前語言版本（xxx_zh／xxx_en；技能名稱是 zh／en）。
static func text(d: Dictionary, field: String, lang: String) -> String:
	var suf := "zh" if lang == "zh_TW" else "en"
	var k := suf if field == "" else "%s_%s" % [field, suf]
	return str(d.get(k, d.get("zh" if field == "" else field + "_zh", "")))

## 技能說明：把 {常數名} 換成 unit_defs 的值。找不到的常數原樣保留（validate 會抓出來）。
static func skill_desc(id: String, lang: String) -> String:
	return fill(text(skill(id), "desc", lang))

## {NAME} 換成 unit_defs 的常數；{REACH_n} 是兵種 n 的攻擊距離；前面加 C: 表示換算成格（÷1000，例如 {C:TAUNT_RANGE}→2）。
static func fill(s: String) -> String:
	return _pretty_ratio(_fill_raw(s))

## ×5/2 → ×2.5、×2/1 → ×2（手感輪 R3：分數讀起來像程式）
static func _pretty_ratio(s: String) -> String:
	var re := RegEx.create_from_string("×(\\d+)/(\\d+)")
	var out := s
	for m in re.search_all(s):
		var v := float(m.get_string(1)) / float(m.get_string(2))
		var t := str(int(v)) if is_equal_approx(v, roundf(v)) else str(snappedf(v, 0.01))
		out = out.replace(m.get_string(0), "×" + t)
	return out

static func _fill_raw(s: String) -> String:
	var out := s
	for m in _re().search_all(s):
		var v = value(m.get_string(2))
		if v == null:
			continue
		var shown := str(v)
		if m.get_string(1) != "":
			var cells := float(v) / 1000.0
			shown = str(int(cells)) if is_equal_approx(cells, roundf(cells)) else "%.1f" % cells
		out = out.replace(m.get_string(0), shown)
	return out

static func _re() -> RegEx:
	return RegEx.create_from_string("\\{(C:)?([A-Z_0-9]+)\\}")

## 常數值；找不到回 null。
static func value(name: String):
	if name.begins_with("REACH_"):
		var t := int(name.substr(6))
		return int(D.STATS[t]["reach"]) if t >= 0 and t < D.COUNT else null
	var consts: Dictionary = (D as Script).get_script_constant_map()
	return consts.get(name)

## 老兵筆記解鎖進度：派這個兵種贏了幾場。
static func wins_with(save_data: Dictionary, t: int) -> int:
	var uw = save_data.get("unit_wins", {})
	if uw is Dictionary:
		return int(uw.get(str(t), 0))
	return 0

static func note_unlocked(save_data: Dictionary, t: int) -> bool:
	return wins_with(save_data, t) >= NOTE_WINS

## 一場贏了：每個有派上場的兵種 +1（同一場同兵種只算一次）。
static func record_win(save_data: Dictionary, types: Array) -> Array:
	var uw = save_data.get("unit_wins", {})
	if not uw is Dictionary:
		uw = {}
	var newly: Array = []
	var seen := {}
	for t in types:
		var k := str(int(t))
		if seen.has(k):
			continue
		seen[k] = true
		var before := int(uw.get(k, 0))
		uw[k] = before + 1
		if before + 1 == NOTE_WINS:
			newly.append(int(t))
	save_data["unit_wins"] = uw
	return newly

## 示範戰鬥：用真的模擬跑技能的小劇場。blue／red 都寫藍方視角（欄 0～5，5 是前排），紅方自動鏡像。
static func demo_sim(id: String):
	var dm: Dictionary = skill(id).get("demo", {})
	var a0 := Army.new(0, 1000)
	var a1 := Army.new(0, 1000)   # 紅方先用藍方視角擺，再鏡像成紅方
	for e in dm.get("blue", []):
		a0.place(int(e[0]), int(e[1]), int(e[2]))
	for e in dm.get("red", []):
		a1.place(int(e[0]), int(e[1]), int(e[2]))
	var s = Sim.new(a0, a1.mirrored())
	s.fast = true
	return s

## 這一 tick 觸發預期技能的位置（給小劇場跳字用）。事件裡的 src／tgt 是單位 id，不是 units 陣列的索引，要用 unit_by_id 查。
static func expect_hits(s, expect: String) -> Array:
	var out: Array = []
	for e in s.events:
		if not e.get("tags", []).has(expect):
			continue
		var who: int = int(e.get("src", e.get("tgt", -1)))
		if who < 0:
			continue
		var u = s.unit_by_id(who)
		if u != null:
			out.append(Vector2(u.x, u.y))
	return out

## 跑完整段示範，回傳出現過的事件標籤（測試與驗證用）。
static func demo_tags(id: String) -> Dictionary:
	var s = demo_sim(id)
	var n := int(skill(id).get("demo", {}).get("ticks", 120))
	var tags := {}
	for i in n:
		if s.finished:
			break
		s.step()
		for e in s.events:
			for tg in e.get("tags", []):
				tags[tg] = tags.get(tg, 0) + 1
	return tags

## 資料自我檢查：回傳錯誤字串清單（空＝沒問題）。
static func validate() -> Array:
	var errs: Array = []
	var d := data()
	if int(d.get("schema_version", 0)) != 1:
		errs.append("schema_version 不是 1")
	var units: Array = d.get("units", [])
	if units.size() != D.COUNT:
		errs.append("兵種數 %d ≠ %d" % [units.size(), D.COUNT])
	var ids := {}
	var used_skills := {}
	for u in units:
		ids[int(u["id"])] = true
		for f in ["role", "story", "tagline", "good", "bad", "veteran"]:
			for suf in ["zh", "en"]:
				if str(u.get("%s_%s" % [f, suf], "")) == "":
					errs.append("兵種 %d 缺 %s_%s" % [int(u["id"]), f, suf])
		for sk in u.get("skills", []):
			used_skills[sk] = true
			if skill(sk).is_empty():
				errs.append("兵種 %d 的技能 %s 不存在" % [int(u["id"]), sk])
	for t in D.COUNT:
		if not ids.has(t):
			errs.append("缺兵種 %d" % t)
	for sk in d.get("skills", {}):
		if not used_skills.has(sk):
			errs.append("技能 %s 沒有兵種使用" % sk)
		var s: Dictionary = d["skills"][sk]
		for f in ["zh", "en", "desc_zh", "desc_en"]:
			if str(s.get(f, "")) == "":
				errs.append("技能 %s 缺 %s" % [sk, f])
		for f in ["desc_zh", "desc_en"]:
			for m in _re().search_all(str(s.get(f, ""))):
				if value(m.get_string(2)) == null:
					errs.append("技能 %s 的 %s 引用不存在的常數 %s" % [sk, f, m.get_string(2)])
		var dm: Dictionary = s.get("demo", {})
		if dm.is_empty() or str(dm.get("expect", "")) == "":
			errs.append("技能 %s 沒有示範或沒有 expect" % sk)
	return errs
