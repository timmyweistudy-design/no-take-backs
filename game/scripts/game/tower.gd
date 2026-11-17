extends RefCounted
## 1.4.0 §11.1（1.3.0 延伸、stash 補完）：無盡塔——一路往上打，每層一種突變（沿用每日挑戰的 8 種）、地圖與 AI 性格輪換，
## 敵方預算每層多一點（上限 +60）；輸一場就結束，記最高層數（本機）。每層的規則與敵陣只由層數決定（固定種子、跨機器一樣）。
const Daily = preload("res://scripts/game/daily.gd")
const AI = preload("res://scripts/core/ai_army.gd")
const BONUS_STEP := 4     # 每層敵方多 4 金
const BONUS_MAX := 60

static func spec(floor_no: int) -> Dictionary:
	var f := maxi(1, floor_no)
	var mut := posmod(f - 1, Daily.MUTATORS)
	return {"floor": f, "mut": mut, "map": 3 if mut == 3 else posmod(f * 5 + 2, 6), "style": posmod(f * 3 + 1, 5),
		"level": clampi((f - 1) / 6, 0, 2), "seed": 70000 + posmod(f * 7919, 1000003), "bonus": mini(BONUS_MAX, (f - 1) * BONUS_STEP)}

## 這一層的規則：每日挑戰的規則（自由部署、單局、突變）再加敵方預算。
static func make_rules(sp: Dictionary, mask: int):
	var r = Daily.make_rules(sp, mask)
	var RS = load("res://scripts/core/ruleset.gd")
	r.budget = [int(r.budget_of(0)), mini(RS.BUDGET_MAX, int(r.budget_of(1)) + int(sp["bonus"]))]   # 大地圖本來就接近上限：加碼夾在合法範圍內
	if int(sp.get("route", 0)) != 0:
		# 1.6.0 B17：路線加減在封頂之後算（休整一定有效；契約到上限就沒有加碼，卡片照實寫；Codex B17 r1）
		r.budget[1] = clampi(int(r.budget[1]) + int(sp["route"]), RS.BUDGET_MIN, RS.BUDGET_MAX)
	r.handicap = int(r.budget[1]) != int(r.budget[0])   # 兩邊預算不同要開讓子，否則 budget_of 兩邊都取藍方（stash 原本漏了，測試抓到）
	return r

static func enemy(sp: Dictionary, r):
	return Daily.enemy(sp, r)

## 記最高層：過了第 f 層＝最高至少 f。回傳 [新最高, 是否刷新]。
static func record(best: int, cleared_floor: int) -> Array:
	return [maxi(best, cleared_floor), cleared_floor > best]

## 續局：下一次要打的層（0＝沒有進行中的塔）。贏了＝下一層、輸了＝清掉；壞資料＝0。
static func next_run(run: int, floor_no: int, won: bool) -> int:
	return floor_no + 1 if won else 0

static func sanitize_run(v) -> int:
	return clampi(int(v), 0, 100000) if (v is int or v is float) else 0

## ── 1.6.0 B17（P7.1、P7.2；S6）塔分岔＋完整續塔 ──
## 每過三層（打完第 3、6、9…層）要選一次路：契約（接下來三層敵方 +CONTRACT_BONUS 金，每過一層記一枚契約章）／休整（下一層敵方 −REST_CUT 金）。
## 路線狀態（存檔 tower_route）＝{v, floor（下一次要打的層，0＝沒有進行中）, path（每個岔口的選擇：c＝契約、r＝休整、-＝舊存檔沒有紀錄）, seals（契約章）, done（已結算到第幾層）}。
## 一切只由 path 與層數決定（沒有亂數）：兩台機器同一條路線雜湊一樣、重啟不重抽；結算記 done，同一層不重領。
## 舊存檔只有 tower_run（層數）：遷移成同一層、過去的岔口記 "-"（不猜當時選了什麼，也不補問）。
const FORK_EVERY := 3
const CONTRACT_BONUS := 8
const CONTRACT_SPAN := 3
const REST_CUT := 8
const ROUTE_V := 1
const FLOOR_MAX := 100000

static func new_route() -> Dictionary:
	return {"v": ROUTE_V, "floor": 1, "path": "", "seals": 0, "done": 0}

## 這一層開打前要先選路嗎（第 4、7、10…層開打前；這個岔口還沒選）
static func fork_due(st: Dictionary) -> bool:
	var f := int(st.get("floor", 0))
	return f > 1 and (f - 1) % FORK_EVERY == 0 and str(st.get("path", "")).length() < (f - 1) / FORK_EVERY

## 選路：只在該選的時候生效（重複點、晚到的點擊＝原樣回傳）
static func choose(st: Dictionary, c: String) -> Dictionary:
	if not fork_due(st) or not c in ["c", "r"]:
		return st
	var out := st.duplicate(true)
	out["path"] = str(st["path"]) + c
	return out

## 第 k 個岔口（0 起）之後的第一層＝k*3+4
static func _fork_floor(k: int) -> int:
	return (k + 1) * FORK_EVERY + 1

## 這一層吃到的路線加減：[敵方加減金, 是不是契約層]
static func route_adj(path: String, floor_no: int) -> Array:
	var adj := 0
	var contract := false
	for k in path.length():
		var f0 := _fork_floor(k)
		if path[k] == "c" and floor_no >= f0 and floor_no < f0 + CONTRACT_SPAN:
			adj += CONTRACT_BONUS
			contract = true
		elif path[k] == "r" and floor_no == f0:
			adj -= REST_CUT
	return [adj, contract]

## 帶路線的這一層：spec 的敵方加碼再加減（夾在 0 以上），附 contract
static func spec_route(st: Dictionary, floor_no: int) -> Dictionary:
	var sp := spec(floor_no)
	var ra := route_adj(str(st.get("path", "")), floor_no)
	sp["route"] = int(ra[0])   # make_rules 在封頂之後加減
	sp["contract"] = bool(ra[1])
	return sp

## 某一層實際的敵方預算加減（封頂後）：給岔路卡片照實寫（到上限＝0）
static func route_effect(floor_no: int, adj: int, mask: int) -> int:
	var sp := spec(floor_no)
	var base = make_rules(sp, mask)
	sp["route"] = adj
	return int(make_rules(sp, mask).budget_of(1)) - int(base.budget_of(1))

## 結算一層（只一次）：回 [新狀態, 有沒有變]。贏＝下一層、契約層加一枚章；輸＝路線結束（floor 0，章數照留在這次結果裡）。
static func settle(st: Dictionary, floor_no: int, won: bool) -> Array:
	if floor_no <= int(st.get("done", 0)) or floor_no != int(st.get("floor", 0)):
		return [st, false]
	var out := st.duplicate(true)
	out["done"] = floor_no
	if won:
		out["floor"] = floor_no + 1
		if bool(route_adj(str(st.get("path", "")), floor_no)[1]):
			out["seals"] = int(st.get("seals", 0)) + 1
	else:
		out["floor"] = 0
	return [out, true]

## 路線雜湊（S6：兩台機器同一條路線一樣）
static func route_hash(st: Dictionary) -> String:
	return ("%d|%s|%d" % [int(st.get("v", ROUTE_V)), str(st.get("path", "")), int(st.get("floor", 0))]).sha256_text().substr(0, 12)

## 舊存檔：只有 tower_run（下一次要打的層）。過去的岔口記 "-"（不猜歷史），done＝前一層（不能重領）。
static func migrate_old(run: int) -> Dictionary:
	if run <= 0:
		return {"v": ROUTE_V, "floor": 0, "path": "", "seals": 0, "done": 0}
	return {"v": ROUTE_V, "floor": run, "path": "-".repeat((run - 1) / FORK_EVERY), "seals": 0, "done": run - 1}

## 存檔的路線版本比遊戲新（§3.1：唯讀、不覆寫）
static func route_is_future(v) -> bool:
	return v is Dictionary and (v.get("v") is int or v.get("v") is float) and float(v["v"]) > ROUTE_V and float(v["v"]) < 1.0e6

static func _int_in(v, lo: float, hi: float) -> bool:
	return (v is int or (v is float and float(v) == floorf(float(v)))) and float(v) >= lo and float(v) <= hi

## 存檔讀回：逐欄驗型；壞了回 null（呼叫端用 tower_run 遷移）。路線長度不能超過層數允許的岔口數。
static func sanitize_route(v):
	if not v is Dictionary:
		return null
	if not _int_in(v.get("v"), 1, ROUTE_V) or not _int_in(v.get("floor"), 0, FLOOR_MAX) or not _int_in(v.get("seals"), 0, FLOOR_MAX) or not _int_in(v.get("done"), 0, FLOOR_MAX):
		return null
	var p = v.get("path")
	if not p is String or p.length() > FLOOR_MAX / FORK_EVERY:
		return null
	for ch in p:
		if not ch in ["c", "r", "-"]:
			return null
	var f := int(v["floor"])
	var dn := int(v["done"])
	if f > 0:
		# 狀態一致（Codex B17 r1）：下一次要打的層＝已結算的下一層；路線長度＝這一層之前該有的岔口數（岔口還沒選時少一個）
		if dn != f - 1:
			return null
		var need := (f - 1) / FORK_EVERY
		var pending := 1 if (f > 1 and (f - 1) % FORK_EVERY == 0) else 0
		if p.length() > need or p.length() < need - pending:
			return null
	elif p.length() > maxi(0, dn / FORK_EVERY):
		return null
	return {"v": int(v["v"]), "floor": f, "path": p, "seals": int(v["seals"]), "done": int(v["done"])}
