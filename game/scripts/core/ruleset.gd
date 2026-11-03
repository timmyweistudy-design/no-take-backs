extends RefCounted
## 自訂規則（第五輪 §3）。純資料，不碰畫面。三層：
##   模擬規則：兩邊預算、一局 tick 數、判定版本、（沙盒）數值倍率與技能開關 → 進模擬雜湊與對戰代碼
##   部署規則：人數上限、單種上限、雙方卡池 → 進對戰代碼（重播要驗陣型合法）
##   系列規則：局數、落子方式、手數、累積、保留陣型、AI 難度 → 只在大廳與系列流程用
## 標準規則下模擬器走原本的路徑（雜湊表頭位元組不變），所以這個檔案**不能**把常數放進 unit_defs.gd（會改數值摘要）。
## 開戰時用 copy() 凍結一份，之後大廳再怎麼改都不影響這一局。

const D = preload("res://scripts/core/unit_defs.gd")

const CODE_PREFIX := "NTBR1"
const STD_BUDGET := 100
const STD_TICKS := 1800
const STD_UNIT_CAP := 24
const TICK_CHOICES := [1200, 1800, 2400, 3000]     # 60／90／120／150 秒
const BUDGET_MIN := 30
const BUDGET_MAX := 200
const UNIT_CAP_MIN := 4
const UNIT_CAP_MAX := 40       # 效能探測（docs/perf/v5-probe.json）：40＋40 每 tick 約 1.3 ms，支援兵密集 2.6 ms
const TYPE_CAP_MAX := 10
const ROUND_CHOICES := [1, 3, 5, 7]
const PLACE_RULES := ["snake5", "cap10", "blind", "custom"]
const TURNS_MIN := 1
const TURNS_MAX := 10
const PCT_MIN := 50            # 沙盒倍率
const PCT_MAX := 200
const SKILLS := ["charge", "taunt", "backstab", "counter", "stealth", "brace", "splash", "heal", "drum", "breach", "frenzy", "rally"]

# ── 模擬 ──
var budget := [STD_BUDGET, STD_BUDGET]   # 讓子關閉時兩邊相同
var handicap := false
var ticks := STD_TICKS
# ── 部署 ──
var unit_cap := STD_UNIT_CAP
var type_cap := 0              # 0＝不限
var pool := [0, 0]             # 玩家（藍）／對手（紅）卡池遮罩；0 會被 validate 擋
var ai_pool_same := true       # 對手卡池跟藍方一樣
# ── 系列 ──
var rounds := 3
var place_rule := "snake5"
var turns := 5                 # place_rule＝custom 時每人幾手
var carry := false             # 沒花完的錢累積到下一手
var keep_formation := true
var ai_level := 1
# ── 沙盒（R3）──
var stat_pct := {}             # type → [hp%, atk%, speed%]；空＝全部 100%
var skills_off: Array = []     # SKILLS 裡關掉的
# 只是顯示用，不參與相等判定
var preset := "standard"

# ───────── 卡池工具（static，給 AI／Army 用） ─────────
static func all_pool() -> int:
	return (1 << D.COUNT) - 1

static func prefix_pool(n: int) -> int:
	return (1 << clampi(n, 0, D.COUNT)) - 1

static func has(p: int, t: int) -> bool:
	return (p >> t) & 1 == 1

static func types_of(p: int) -> Array:
	var out: Array = []
	for t in D.COUNT:
		if has(p, t):
			out.append(t)
	return out

static func pool_count(p: int) -> int:
	return types_of(p).size()

static func cheapest_in(p: int) -> int:
	var c := 1 << 30
	for t in types_of(p):
		c = mini(c, D.cost(t))
	return c

static func cheapest_combat_in(p: int) -> int:
	var c := 1 << 30
	for t in types_of(p):
		if not D.is_support(t):
			c = mini(c, D.cost(t))
	return c

static func priciest_in(p: int) -> int:
	var c := 0
	for t in types_of(p):
		c = maxi(c, D.cost(t))
	return c

static func has_combat(p: int) -> bool:
	return cheapest_combat_in(p) < (1 << 30)

# ───────── 建立 ─────────
static func standard(p: int = -1):
	var r = load("res://scripts/core/ruleset.gd").new()
	var pp: int = all_pool() if p < 0 else p
	r.pool = [pp, pp]
	return r

func copy():
	var r = load("res://scripts/core/ruleset.gd").new()
	r.budget = budget.duplicate()
	r.handicap = handicap
	r.ticks = ticks
	r.unit_cap = unit_cap
	r.type_cap = type_cap
	r.pool = pool.duplicate()
	r.ai_pool_same = ai_pool_same
	r.rounds = rounds
	r.place_rule = place_rule
	r.turns = turns
	r.carry = carry
	r.keep_formation = keep_formation
	r.ai_level = ai_level
	r.stat_pct = stat_pct.duplicate(true)
	r.skills_off = skills_off.duplicate()
	r.preset = preset
	return r

func budget_of(team: int) -> int:
	return int(budget[team]) if handicap else int(budget[0])

func pool_of(team: int) -> int:
	return int(pool[0]) if (team == 1 and ai_pool_same) else int(pool[team])

func is_sandbox() -> bool:
	if not skills_off.is_empty():
		return true
	for t in stat_pct:
		for v in stat_pct[t]:
			if int(v) != 100:
				return true
	return false

## 判定版本：兩邊預算不同（讓子）才用比例判定 2；其他都是舊判定 1（和 1.3.0 完全相同）。
func judge() -> int:
	return 2 if budget_of(0) != budget_of(1) else 1

## 模擬是否走舊路徑（雜湊位元組和 1.3.0 相同）。
func sim_is_legacy() -> bool:
	return ticks == STD_TICKS and judge() == 1 and not is_sandbox()

## 狂熱時間表（第五輪 §3.1，Codex 第二輪 ③）：起點 F＝T×2÷3、間隔 S＝T÷18，耗損在 F＋k×S（k＝0～5）。
## T＝1800 時精確是 1200、100（1.3.0 的值）。
func frenzy_tick() -> int:
	return ticks * 2 / 3

func attrition_step() -> int:
	return maxi(1, ticks / 18)

## 雙人每手上限（輪流落子）：max(預算÷手數（進位）, 卡池最貴兵價)。標準 snake5（100 金、5 手）＝20。
func turn_cap(team: int) -> int:
	var n := 5 if place_rule == "snake5" else (10 if place_rule == "cap10" else turns)
	var b := budget_of(team)
	return maxi((b + n - 1) / n, priciest_in(pool_of(team)))

func turns_per_player() -> int:
	return 5 if place_rule == "snake5" else (turns if place_rule == "custom" else 0)

func wins_needed() -> int:
	return (rounds + 1) / 2

## 最多打幾局：N＝1 只打 1 局；N≥3 最多 N＋2 局（平手不算勝場）。三戰兩勝最多 5 局＝1.3.0 現制。
func max_rounds() -> int:
	return 1 if rounds <= 1 else rounds + 2

# ───────── 驗證 ─────────
## 回傳不合法原因的字串鍵（空陣列＝合法）。給大廳顯示、代碼匯入、開戰前檢查共用。
func validate() -> Array:
	var bad: Array = []
	for tm in 2:
		var b := budget_of(tm)
		if b < BUDGET_MIN or b > BUDGET_MAX:
			bad.append("rr_bad_budget")
		var p := pool_of(tm)
		if p <= 0 or p > all_pool():
			bad.append("rr_bad_pool")
		elif not has_combat(p):
			bad.append("rr_no_combat")
		elif cheapest_combat_in(p) > b:
			bad.append("rr_cant_afford")
		elif place_rule != "blind" and turns_per_player() > 0 and cheapest_combat_in(p) > turn_cap(tm):
			bad.append("rr_turn_too_small")
	if not ticks in TICK_CHOICES:
		bad.append("rr_bad_ticks")
	if unit_cap < UNIT_CAP_MIN or unit_cap > UNIT_CAP_MAX:
		bad.append("rr_bad_cap")
	if type_cap < 0 or type_cap > TYPE_CAP_MAX:
		bad.append("rr_bad_type_cap")
	if not rounds in ROUND_CHOICES:
		bad.append("rr_bad_rounds")
	if not place_rule in PLACE_RULES:
		bad.append("rr_bad_place")
	if turns < TURNS_MIN or turns > TURNS_MAX:
		bad.append("rr_bad_turns")
	if ai_level < 0 or ai_level > 2:
		bad.append("rr_bad_ai")
	for t in stat_pct:
		if int(t) < 0 or int(t) >= D.COUNT or not stat_pct[t] is Array or stat_pct[t].size() != 3:
			bad.append("rr_bad_sandbox")
			break
		for v in stat_pct[t]:
			if int(v) < PCT_MIN or int(v) > PCT_MAX:
				bad.append("rr_bad_sandbox")
				break
	for s in skills_off:
		if not s in SKILLS:
			bad.append("rr_bad_sandbox")
			break
	var uniq: Array = []
	for b in bad:
		if not b in uniq:
			uniq.append(b)
	return uniq

## 最多能花多少錢（大廳「花不完的錢」提示用）：有界背包，在人數上限、單種上限內求最大花費；units＝達到這個花費最少要幾隻。
func max_spend(team: int) -> Dictionary:
	var b := budget_of(team)
	var inf := 1 << 20
	var dp: Array = []
	dp.resize(b + 1)
	dp.fill(inf)
	dp[0] = 0
	for t in types_of(pool_of(team)):
		var c := D.cost(t)
		var lim: int = b / c if type_cap == 0 else mini(type_cap, b / c)
		for _k in lim:
			for s in range(b, c - 1, -1):
				if dp[s - c] + 1 < dp[s]:
					dp[s] = dp[s - c] + 1
	var best := 0
	for s in range(b, -1, -1):
		if dp[s] <= unit_cap:
			best = s
			break
	return {"spend": best, "units": dp[best], "unused": b - best}

# ───────── 相等與差異 ─────────
## 和規則相等判定有關的欄位（預設名稱、AI 難度這類顯示用的不算）。固定順序。
func key_fields() -> Array:
	var sp: Array = []
	var keys := stat_pct.keys()
	keys.sort()
	for t in keys:
		sp.append([int(t), int(stat_pct[t][0]), int(stat_pct[t][1]), int(stat_pct[t][2])])
	var so := skills_off.duplicate()
	so.sort()
	return [budget_of(0), budget_of(1), 1 if handicap else 0, ticks, unit_cap, type_cap, pool_of(0), pool_of(1), 1 if ai_pool_same else 0,
		rounds, place_rule, turns, 1 if carry else 0, 1 if keep_formation else 0, ai_level, sp, so]

## 模擬那一層的摘要（非舊路徑時加進模擬雜湊）。
func sim_digest() -> String:
	var sp: Array = []
	var keys := stat_pct.keys()
	keys.sort()
	for t in keys:
		sp.append([int(t), stat_pct[t]])
	var so := skills_off.duplicate()
	so.sort()
	return JSON.stringify([budget_of(0), budget_of(1), ticks, judge(), sp, so]).sha256_text().substr(0, 16)

func equals(o) -> bool:
	return JSON.stringify(key_fields()) == JSON.stringify(o.key_fields())

## 和標準規則（同一個卡池基準）不同的項目：[[鍵, 標準值, 現在值], …]
func diff(std) -> Array:
	var out: Array = []
	if budget_of(0) != std.budget_of(0):
		out.append(["rr_budget", std.budget_of(0), budget_of(0)])
	if handicap:
		out.append(["rr_handicap", std.budget_of(1), budget_of(1)])
	if ticks != std.ticks:
		out.append(["rr_time", std.ticks / 20, ticks / 20])
	if unit_cap != std.unit_cap:
		out.append(["rr_cap", std.unit_cap, unit_cap])
	if type_cap != std.type_cap:
		out.append(["rr_type_cap", std.type_cap, type_cap])
	if pool_of(0) != std.pool_of(0):
		out.append(["rr_pool", pool_count(std.pool_of(0)), pool_count(pool_of(0))])
	if pool_of(1) != pool_of(0):
		out.append(["rr_ai_pool", pool_count(pool_of(0)), pool_count(pool_of(1))])
	if rounds != std.rounds:
		out.append(["rr_rounds", std.rounds, rounds])
	if place_rule != std.place_rule or (place_rule == "custom" and turns != std.turns):
		out.append(["rr_place", std.place_rule, place_rule])
	if carry != std.carry:
		out.append(["rr_carry", std.carry, carry])
	if is_sandbox():
		out.append(["rr_sandbox", 0, 1])
	return out

# ───────── 代碼 ─────────
## NTBR1.<base64url(JSON 陣列)>.<校驗 6 碼>；固定欄序、整數型別。
func to_code() -> String:
	var j := JSON.stringify(key_fields())
	var body := Marshalls.utf8_to_base64(j).replace("+", "-").replace("/", "_").replace("=", "")
	return "%s.%s.%s" % [CODE_PREFIX, body, body.sha256_text().substr(0, 6)]

## 回傳 {ok, why, rules}
static func from_code(code: String) -> Dictionary:
	var c := code.strip_edges()
	if c.length() > 2000:
		return {"ok": false, "why": "rr_code_long"}
	var parts := c.split(".")
	if parts.size() != 3 or parts[0] != CODE_PREFIX:
		return {"ok": false, "why": "rr_code_format"}
	if parts[1].sha256_text().substr(0, 6) != parts[2]:
		return {"ok": false, "why": "rr_code_checksum"}
	var b64 := parts[1].replace("-", "+").replace("_", "/")
	while b64.length() % 4 != 0:
		b64 += "="
	var j = JSON.parse_string(Marshalls.base64_to_utf8(b64))
	if not j is Array or j.size() != 17:
		return {"ok": false, "why": "rr_code_body"}
	# 逐欄驗型（Codex 實作第 1 輪）：整數欄必須是整數、布林欄只能 0／1、兩個卡池原值都要合法（即使 AI 卡池跟藍方一樣）
	for i in [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14]:
		if not (j[i] is float or j[i] is int) or float(j[i]) != floorf(float(j[i])) or absf(float(j[i])) > 100000:
			return {"ok": false, "why": "rr_code_body"}
	for i in [2, 8, 12, 13]:
		if int(j[i]) != 0 and int(j[i]) != 1:
			return {"ok": false, "why": "rr_code_body"}
	for i in [6, 7]:
		if int(j[i]) < 1 or int(j[i]) > all_pool():
			return {"ok": false, "why": "rr_bad_pool"}
	if not j[10] is String or not j[15] is Array or not j[16] is Array or j[15].size() > D.COUNT or j[16].size() > SKILLS.size():
		return {"ok": false, "why": "rr_code_body"}
	for e in j[15]:
		if not e is Array or e.size() != 4:
			return {"ok": false, "why": "rr_code_body"}
		for v in e:
			if not (v is float or v is int) or float(v) != floorf(float(v)):
				return {"ok": false, "why": "rr_code_body"}
	for sk in j[16]:
		if not sk is String:
			return {"ok": false, "why": "rr_code_body"}
	var r = load("res://scripts/core/ruleset.gd").new()
	r.handicap = int(j[2]) == 1
	r.budget = [int(j[0]), int(j[1])]
	r.ticks = int(j[3])
	r.unit_cap = int(j[4])
	r.type_cap = int(j[5])
	r.ai_pool_same = int(j[8]) == 1
	r.pool = [int(j[6]), int(j[7])]
	r.rounds = int(j[9])
	r.place_rule = str(j[10])
	r.turns = int(j[11])
	r.carry = int(j[12]) == 1
	r.keep_formation = int(j[13]) == 1
	r.ai_level = int(j[14])
	for e in j[15]:
		r.stat_pct[int(e[0])] = [int(e[1]), int(e[2]), int(e[3])]
	for sk in j[16]:
		r.skills_off.append(str(sk))
	r.preset = "custom"
	var bad: Array = r.validate()
	if not bad.is_empty():
		return {"ok": false, "why": bad[0]}
	return {"ok": true, "why": "", "rules": r}
