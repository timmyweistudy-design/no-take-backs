extends RefCounted
const D_TOTAL := 20
## 教學與殘局關卡資料（data/puzzles.json）。

const Army = preload("res://scripts/core/army.gd")
const D = preload("res://scripts/core/unit_defs.gd")
const RS = preload("res://scripts/core/ruleset.gd")
const Sim = preload("res://scripts/core/battle_sim.gd")
const CMD = preload("res://scripts/core/cmd_defs.gd")
## 第十三輪：10 章，每章 10 關（V1.1 加第 11 章）。1＝經典 p、2＝新兵 n＋extra、3＝奇幻 f，其他都在 extra（"ch" 欄）。
const CHAPTERS := 11   # V1.1：第 11 章完美主義
const GOALS := ["win", "protect", "survive", "kill", "flawless", "margin"]   # V1.1 D5：後兩種只看戰後狀態
const MAP_SIZE := 1             # 地形殘局只用中尺寸（16×9＝格子殘局的場地）

static var _data := {}
static var _custom := {}   # V1.1 D3：工坊碼匯入的那一關（id "ws"），不進清單、不存星數

static func set_custom(pz: Dictionary) -> void:
	_custom = pz

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

## 奇幻軍試玩（第八輪）：每種一關。
static func fantasy_puzzles() -> Array:
	_load()
	return _data.get("fantasy_units", [])

## 第十三輪新增的關卡（每關有 "ch"）。
static func extra_puzzles() -> Array:
	_load()
	return _data.get("extra", [])

## 第 n 章（1 起算）的關卡，照資料順序。
static func chapter(n: int) -> Array:
	var out: Array = []
	match n:
		1:
			out = puzzles().duplicate()
		2:
			out = new_puzzles().duplicate()
		3:
			out = fantasy_puzzles().duplicate()
	for p in extra_puzzles():
		if int(p.get("ch", 0)) == n:
			out.append(p)
	return out

## 全部殘局（不含教學），依章節順序。
static func all_puzzles() -> Array:
	var out: Array = []
	for n in range(1, CHAPTERS + 1):
		out += chapter(n)
	return out

## 章節資訊（名稱、開場小故事）。
static func chapter_info(n: int) -> Dictionary:
	_load()
	var cs: Array = _data.get("chapters", [])
	return cs[n - 1] if n >= 1 and n <= cs.size() else {}

## 這關在第幾章（教學回 0）。
static func chapter_of(id: String) -> int:
	for n in range(1, CHAPTERS + 1):
		for p in chapter(n):
			if p["id"] == id:
				return n
	return 0

static func all_ids() -> Array:
	var out: Array = []
	for p in tutorials() + all_puzzles():
		out.append(p["id"])
	return out

static func get_puzzle(id: String) -> Dictionary:
	if id == "ws":
		return _custom
	for p in tutorials() + all_puzzles():
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
	a.pool = (1 << D_TOTAL) - 1
	for f in pz["fixed"]:
		a.units.append({"type": int(f[0]), "col": int(f[1]), "row": int(f[2])})
		fixed_cost += Army.D.cost(int(f[0]))
	a.budget = fixed_cost + int(pz["budget"])
	if pz.has("cap"):
		a.unit_cap = pz["fixed"].size() + int(pz["cap"])   # 限隻數：可再放 cap 隻
	if pz.has("map"):
		a.terrain = rules_of(pz).terrain()   # 牆內格子不能放
	return a

static func goal(pz: Dictionary) -> String:
	return str(pz.get("goal", "win"))

## 這關要不要用規則（地形、撐住秒數、技能）。不用就回 null，走舊模擬路徑。
static func rules_of(pz: Dictionary):
	if not pz.has("map") and goal(pz) != "survive" and not pz.has("cmd"):
		return null
	var r = RS.standard()
	r.preset = "custom"
	r.map_id = int(pz.get("map", 0))
	r.map_size = MAP_SIZE
	if goal(pz) == "survive":
		r.ticks = int(pz["goal_ticks"])
	if pz.has("cmd"):
		var c: Dictionary = pz["cmd"]
		var em := 0
		for e in c.get("enemy", []):
			em |= 1 << int(e[1])
		var mm := 0
		for sk in skills_of(pz):
			mm |= 1 << int(sk)
		r.cmd_mask = [mm, em]
		r.cmd_uses = int(c.get("uses", 1))
		r.cmd_cd = int(c.get("cd", CMD.CD_TICKS[0]))
		r.cmd_power = 100
	return r

## V1.4 #4 軍令連鎖：一關可以給多種技能（cmd.skills）。多技能關的 plan 每一筆是「tick × 8 ＋ 技能」，
## 單技能關照舊只存 tick（舊關卡、舊存檔、三星解都不變）。
static func multi(pz: Dictionary) -> bool:
	return pz.has("cmd") and pz["cmd"].has("skills")

static func skills_of(pz: Dictionary) -> Array:
	if not pz.has("cmd"):
		return []
	return pz["cmd"]["skills"] if multi(pz) else [int(pz["cmd"]["skill"])]

static func plan_tick(pz: Dictionary, e: int) -> int:
	return e / 8 if multi(pz) else e

static func plan_skill(pz: Dictionary, e: int) -> int:
	return e % 8 if multi(pz) else int(pz["cmd"]["skill"])

static func plan_make(pz: Dictionary, skill: int, tick: int) -> int:
	return tick * 8 + skill if multi(pz) else tick

## 多技能關：把第 i 筆往後挪 d tick，再讓同一種技能前後至少隔一個冷卻、不早於開場、不晚於局長。
## 遊戲面板與求解器共用（Codex v13-r1 #4 的同一套限制）。
static func plan_fix(pz: Dictionary, plan: Array, i: int, d: int) -> Array:
	var cd: int = rules_of(pz).cmd_cd
	var lim: int = int(pz.get("goal_ticks", 1800)) - 10
	var lo0: int = maxi(CMD.START_TICKS, int(pz.get("plan_min", 0)))
	var p2: Array = plan.duplicate()
	if i >= 0 and i < p2.size():
		p2[i] = plan_make(pz, plan_skill(pz, int(p2[i])), clampi(plan_tick(pz, int(p2[i])) + d, lo0, lim))
	for sk in skills_of(pz):
		var idx: Array = []
		for k in p2.size():
			if plan_skill(pz, int(p2[k])) == int(sk):
				idx.append(k)
		idx.sort_custom(func(a, b): return plan_tick(pz, int(p2[a])) < plan_tick(pz, int(p2[b])))
		var last := -100000
		for k in idx:
			var t := maxi(plan_tick(pz, int(p2[k])), maxi(lo0, last + cd))
			if t > lim:
				return plan
			p2[k] = plan_make(pz, int(sk), t)
			last = t
	return p2

## 技能關：玩家設定的施放 tick（plan）＋敵方寫死的時間 → 重播紀錄。
static func cmd_log(pz: Dictionary, plan: Array) -> Array:
	if not pz.has("cmd"):
		return []
	var log: Array = []
	for e in plan:
		log.append([plan_tick(pz, int(e)), 0, plan_skill(pz, int(e))])
	for e in pz["cmd"].get("enemy", []):
		log.append([int(e[0]), 1, int(e[1])])
	log.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	return log

## 預設施放時間（還沒調整時）：開場能放的最早時間起，每次隔一個冷卻。
static func default_plan(pz: Dictionary) -> Array:
	var out: Array = []
	if not pz.has("cmd"):
		return out
	var r = rules_of(pz)
	var sks := skills_of(pz)
	for k in sks.size():
		for i in int(pz["cmd"].get("uses", 1)):
			out.append(plan_make(pz, int(sks[k]), CMD.START_TICKS + i * r.cmd_cd + k * 40))   # 多技能：每種錯開 2 秒
	return out

## 格子座標的單位在模擬裡還活著嗎（team 0 用自己的欄，敵方用絕對欄）。
static func unit_alive(sim, team: int, cell: Array) -> bool:
	var id: int = team * 1000 + int(cell[1]) * Sim.COLS + int(cell[0])
	for u in sim.units:
		if u.id == id:
			return u.alive
	return false

## 我方某兵種倒了幾隻（召喚物不算我方擺的兵）。
static func lost_of_type(sim, t: int) -> int:
	var n := 0
	for u in sim.units:
		if u.team == 0 and u.type == t and not u.alive and not u.summon:
			n += 1
	return n

## 打完之後：這關算不算過、剩餘戰力、星數、各條件（遊戲、工具、測試共用）。
static func outcome(pz: Dictionary, sim, spent_extra: int) -> Dictionary:
	var g := goal(pz)
	var won: bool = sim.winner == 0
	var ok := won
	match g:
		"protect":
			ok = won and unit_alive(sim, 0, pz["goal_unit"])
		"kill":
			ok = won and not unit_alive(sim, 1, pz["goal_unit"])
		"survive":
			ok = sim.alive_count(0) > 0
		"flawless":
			ok = won and lost_of_type(sim, int(pz["goal_type"])) == 0   # V1.1 D5：這種兵一隻都不能倒
		"margin":
			ok = won and rem_pct(sim.power(0), sim.budget) >= int(pz["goal_rem"])   # V1.1 D5：贏得夠漂亮
	var rem: int = rem_pct(sim.power(0), sim.budget) if ok else 0
	return {"ok": ok, "won": won, "goal": g, "rem": rem, "spent": spent_extra, "stars": stars(pz, ok, rem, spent_extra)}

## 擺法合不合法（extra＝[[兵種, 欄, 列], ...]；還會檢查可用兵種）。合法回 ""。
static func check_extra(pz: Dictionary, extra: Array) -> String:
	var a0: Army = player_army(pz)
	var allowed: Array = []
	for v in pz.get("allowed", []):
		allowed.append(int(v))
	for e in extra:
		if not allowed.has(int(e[0])):
			return "兵種 %d 不能用" % int(e[0])
		var why: String = a0.check_place(int(e[0]), int(e[1]), int(e[2]))
		if why != "":
			return why
		a0.place(int(e[0]), int(e[1]), int(e[2]))
	return ""

## 直接打一場（工具、測試用；遊戲裡是畫面上的模擬，最後一樣呼叫 outcome）。不合法回 {"ok": false, "illegal": 原因}。
static func play(pz: Dictionary, extra: Array, plan: Array = [], check := true) -> Dictionary:
	if check:
		var why := check_extra(pz, extra)
		if why != "":
			return {"ok": false, "illegal": why, "stars": 0, "rem": 0, "spent": 0}
	var a0: Army = player_army(pz)
	var fixed_budget: int = a0.budget - int(pz["budget"])
	for e in extra:
		a0.units.append({"type": int(e[0]), "col": int(e[1]), "row": int(e[2])})
	var s = Sim.new(a0, enemy_army(pz), rules_of(pz))
	if s.cmd_on:
		s.cmd_play(cmd_log(pz, plan if not plan.is_empty() else default_plan(pz)))
	s.fast = true
	s.run_to_end()
	var out := outcome(pz, s, a0.spent() - fixed_budget)
	out["ticks"] = s.tick
	return out

## 三星編制提示：三星解用了哪些兵（不給位置）。回 [[兵種, 隻數], ...]，照兵種編號。
static func best_lineup(pz: Dictionary) -> Array:
	var cnt := {}
	for e in pz.get("best", {}).get("u", []):
		cnt[int(e[0])] = int(cnt.get(int(e[0]), 0)) + 1
	var ks: Array = cnt.keys()
	ks.sort()
	var out: Array = []
	for k in ks:
		out.append([k, cnt[k]])
	return out

static func is_fixed(pz: Dictionary, col: int, row: int) -> bool:
	for f in pz["fixed"]:
		if int(f[1]) == col and int(f[2]) == row:
			return true
	return false

## 剩餘戰力 %：和結果頁顯示同一個數字（四捨五入），畫面寫 25% 就算 25%。
static func rem_pct(power: int, budget: int) -> int:
	return (power * 200 + budget * 1000) / (budget * 2000)

## 星數：獲勝、剩 ≥star2%、花費 ≤star3，每達成一項一顆星（沒贏就是 0）。
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
	if pz.has("unit"):
		return int(pz["unit"])
	var cnt := D.zeros()
	for sol in pz.get("solutions", []):
		for e in sol:
			cnt[int(e[0])] += 1
	var best := int(pz["allowed"][0]) if not pz.get("allowed", []).is_empty() else 0
	for t in D.total():
		if cnt[t] > cnt[best]:
			best = t
	return best
