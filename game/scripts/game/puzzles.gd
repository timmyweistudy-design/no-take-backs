extends RefCounted
## 教學與殘局關卡資料（data/puzzles.json）。

const Army = preload("res://scripts/core/army.gd")
const D = preload("res://scripts/core/unit_defs.gd")

static var _data := {}

static func _load() -> void:
	if not _data.is_empty():
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/puzzles.json"))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("puzzles.json 讀不到")
		return
	_data = parsed
	for p in _data["tutorial"]:
		p["tutorial"] = true

static func tutorials() -> Array:
	_load()
	return _data["tutorial"]

static func puzzles() -> Array:
	_load()
	return _data["puzzles"]

## 新兵試玩（第四輪 §4.8）：每種新兵一關，unit＝主角兵種；兵種解鎖後才能玩。
static func new_puzzles() -> Array:
	_load()
	return _data.get("new_units", [])

static func all_ids() -> Array:
	var out: Array = []
	for p in tutorials() + puzzles() + new_puzzles():
		out.append(p["id"])
	return out

static func get_puzzle(id: String) -> Dictionary:
	for p in tutorials() + puzzles() + new_puzzles():
		if p["id"] == id:
			return p
	return {}

static func enemy_army(pz: Dictionary) -> Army:
	var a := Army.new(1, 200)
	for e in pz["enemy"]:
		a.units.append({"type": int(e[0]), "col": int(e[1]), "row": int(e[2])})
	return a

## 玩家陣：固定兵已經擺好；預算＝固定兵花費＋可再花的錢，所以「剩餘戰力」照總投入算。
static func player_army(pz: Dictionary) -> Army:
	var fixed_cost := 0
	var a := Army.new(0, 100)
	for f in pz["fixed"]:
		a.units.append({"type": int(f[0]), "col": int(f[1]), "row": int(f[2])})
		fixed_cost += Army.D.cost(int(f[0]))
	a.budget = fixed_cost + int(pz["budget"])
	return a

static func is_fixed(pz: Dictionary, col: int, row: int) -> bool:
	for f in pz["fixed"]:
		if int(f[1]) == col and int(f[2]) == row:
			return true
	return false

## 星數：1 勝；2 勝方剩 ≥star2%；3 花費 ≤star3。
static func stars(pz: Dictionary, won: bool, rem_pct: int, spent_extra: int) -> int:
	if not won:
		return 0
	var s := 1
	if rem_pct >= int(pz["star2"]):
		s += 1
	if spent_extra <= int(pz["star3"]):
		s += 1
	return s


## 這關的「主角」兵種（殘局選單小頭像用）：標準解裡最常出現的兵種；同數取編號小的。
static func hero_type(pz: Dictionary) -> int:
	var cnt := D.zeros()
	for sol in pz.get("solutions", []):
		for e in sol:
			cnt[int(e[0])] += 1
	var best := int(pz["allowed"][0]) if not pz.get("allowed", []).is_empty() else 0
	for t in D.COUNT:
		if cnt[t] > cnt[best]:
			best = t
	return best
