extends RefCounted
## 兵種開放（第四輪 §9 決定 1、2）：
## ・新兵依「正式場數」逐一解鎖：前 3 場只用經典 5 種，之後每 2 場多一種（長槍兵→投彈兵→醫者→鼓手→狂戰士）
## ・對 AI、遠征：開放數＝已解鎖數；AI 也只用這些兵種（不會拿你沒見過的兵打你）
## ・朋友對戰：不看個人進度，由「兵種：經典 5 種／全部」設定決定（同一台電腦兩人共用）
## ・對 AI 也可以選「經典 5 種」
## ・試玩版：最多開到第一批新兵（7 種）；之後的兵卡標「正式版解鎖」
## 純函式，進度存在 Save.data["stats"]["games"]，不另外存解鎖狀態（不用遷移存檔）。

const D = preload("res://scripts/core/unit_defs.gd")

const UNLOCK_GAMES := [3, 5, 7, 9, 11]   # 第 k 個新兵（編號 5＋k）需要的正式場數
const DEMO_MAX := 7

## 依場數算出已解鎖的兵種數（5～10）；demo＝試玩版上限。
static func unlocked_count(games: int, demo := false) -> int:
	var n := D.CLASSIC
	for g in UNLOCK_GAMES:
		if games >= g:
			n += 1
	return mini(n, DEMO_MAX) if demo else n

## 這一場開放幾種兵。mode_kind："duel"（朋友對戰）、"ai"（對 AI、遠征）、"all"（教學、殘局：由關卡自己限制）。
static func ntypes_for(mode_kind: String, games: int, classic: bool, demo := false) -> int:
	var cap := DEMO_MAX if demo else D.COUNT
	match mode_kind:
		"duel":
			return D.CLASSIC if classic else cap
		"ai":
			return D.CLASSIC if classic else unlocked_count(games, demo)
	return cap

## 第 t 種兵還要再打幾場才解鎖（已解鎖回 0；試玩版鎖住的回 -1）。
static func games_to_unlock(t: int, games: int, demo := false) -> int:
	if t < D.CLASSIC:
		return 0
	if demo and t >= DEMO_MAX:
		return -1
	return maxi(0, int(UNLOCK_GAMES[t - D.CLASSIC]) - games)

## 打完一場後新解鎖的兵種（給提示用）。
static func newly_unlocked(games_before: int, games_after: int, demo := false) -> Array:
	var out: Array = []
	for t in range(unlocked_count(games_before, demo), unlocked_count(games_after, demo)):
		out.append(t)
	return out
