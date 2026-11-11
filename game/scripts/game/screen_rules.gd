extends RefCounted
## 1.1.0 A22：game_v16.gd 裡的純邏輯（開場鎖定弧分組、實驗簿改名、合作模式紀錄），畫面腳本留同名包裝。

const NB_NAME_MAX := 16   # 實驗簿名字上限（和 game_v16.NB_NAME_MAX 同一個值）

static func lock_groups(pairs: Array, n: int) -> Dictionary:
	var by := {}
	for pr in pairs:
		var k: Vector2i = pr[1]
		if not by.has(k):
			by[k] = []
		by[k].append(pr)
	var draw: Array = []
	var rest: Array = []
	var count := {}
	for k in by:
		var lst: Array = by[k]
		draw += lst.slice(0, n)
		if lst.size() > n:
			count[k] = lst.size()
			rest += lst.slice(n)
	return {"draw": draw, "count": count, "rest": rest}

static func nb_words_add(buf: String, w: String) -> String:
	return (buf + w).substr(0, NB_NAME_MAX)

static func nb_edit_append(buf: String, uc: int) -> String:
	if uc < 32 or uc == 127 or buf.length() >= NB_NAME_MAX:
		return buf
	return buf + String.chr(uc)

static func coop_player(stage: int) -> int:
	return 1 + (stage - 1) % 2

static func coop_rows(log: Array) -> Array:
	var out: Array = []
	for i in range(0, log.size() - 3, 4):
		out.append([int(log[i]), int(log[i + 1]), int(log[i + 2]) == 1, int(log[i + 3])])
	return out

