extends RefCounted
## V1.6 #8 殘局極速賽：限時連解輕量殘局（Puzzle Rush）。純函式（測試共用）。
## 題庫＝目標是「打贏」、沒有自帶地圖、軍令、隻數上限的殘局；依章節由淺到深，同章內用種子洗牌。
const PZ = preload("res://scripts/game/puzzles.gd")

const START_SEC := 180.0
const BONUS_SEC := 20.0     # 解開 +20 秒
const PENALTY_SEC := 15.0   # 失敗 −15 秒（直接換下一題，不卡關）

static func eligible(pz: Dictionary) -> bool:
	return PZ.goal(pz) == "win" and not pz.has("map") and not pz.has("cmd") and not pz.has("cap") and not pz.has("rules")

static func pool(seed: int) -> Array:
	var by_ch := {}
	for pz in PZ.all_puzzles():
		if not eligible(pz):
			continue
		var c := PZ.chapter_of(str(pz["id"]))
		if not by_ch.has(c):
			by_ch[c] = []
		by_ch[c].append(str(pz["id"]))
	var chs: Array = by_ch.keys()
	chs.sort()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var out: Array = []
	for c in chs:
		var lst: Array = by_ch[c]
		lst.sort()
		for i in range(lst.size() - 1, 0, -1):   # Fisher–Yates（固定種子）
			var j := rng.randi_range(0, i)
			var t = lst[i]
			lst[i] = lst[j]
			lst[j] = t
		out.append_array(lst)
	return out

static func after(left: float, solved: bool) -> float:
	return left + (BONUS_SEC if solved else -PENALTY_SEC)
