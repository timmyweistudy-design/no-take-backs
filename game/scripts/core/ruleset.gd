extends RefCounted
## 自訂規則（第五輪 §3）。純資料，不碰畫面。三層：
##   模擬規則：兩邊預算、一局 tick 數、判定版本、（沙盒）數值倍率與技能開關 → 進模擬雜湊與對戰代碼
##   部署規則：人數上限、單種上限、雙方卡池 → 進對戰代碼（重播要驗陣型合法）
##   系列規則：局數、落子方式、手數、累積、保留陣型、AI 難度 → 只在大廳與系列流程用
## 標準規則下模擬器走原本的路徑（雜湊表頭位元組不變），所以這個檔案**不能**把常數放進 unit_defs.gd（會改數值摘要）。
## 開戰時用 copy() 凍結一份，之後大廳再怎麼改都不影響這一局。

const D = preload("res://scripts/core/unit_defs.gd")
const F8 = preload("res://scripts/core/fantasy_defs.gd")
const MapDefs = preload("res://scripts/core/map_defs.gd")

const AI_STYLES := 6
const ROSTER_MAX := 10         # 第八輪：一局每邊最多幾種兵
const CODE_PREFIX := "NTBR1"
const CODE_PREFIX3 := "NTBR3"   # 第八輪：卡池用到新兵（欄位和 NTBR2 相同，只差卡池遮罩放寬）
const CODE_PREFIX5 := "NTBR5"   # 第十二輪：有手動技能（NTBR4 的欄位再加 5 欄）
const CODE_PREFIX4 := "NTBR4"   # V9：有地圖或非標準大小（多 3 欄：地圖、大小、噴口）
const CODE_PREFIX6 := "NTBR6"   # V1.6 #22：相鄰陣法（NTBR5 的 29 欄＋1 欄 adj；技能可以是關的）
const CODE_PREFIX2 := "NTBR2"   # 第六輪：多 4 欄（部署版本、間距、縱深、全場模式）
# 第六輪：自由排兵（docs/2026-11-03-free-placement-plan-v6.md §3）
const DEPLOYS := ["grid", "free"]
const SPACING_MIN := 600
const SPACING_MAX := 1000
const DEPTH_GRID := 6000        # 格子部署：自己視角 x 上限（第 6 欄的右緣）
const DEPTH_MIN := 6000
const DEPTH_MAX := 7500
const DEPTH_FULL := 15800       # 全場：到對面邊界（中心離邊 0.2 格）
const FULL_NONE := 0
const FULL_DUEL := 1            # 雙人輪流落子・全場
const FULL_AI := 2              # 對 AI 明牌全場
const ENEMY_GAP := 1500         # 全場時離任何敵兵至少 1.5 格
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
# ── V9 地圖（進模擬）──
var map_id := 0                # MapDefs.MAPS 的索引；0＝平原
var map_size := 1              # 0 小、1 中（標準）、2 大
var vents := false             # 熔岩噴口（只有熔岩裂谷有；V1.0 不做，欄位保留）
var map_mode := 0              # 系列：0 固定、1 每局輪替、2 每局隨機（不進模擬，每局定下來才算）
var time_of := 0               # 外觀：0 白天、1 黃昏、2 夜晚（只有畫面）
var bans := 0                  # 雙人每人禁幾種（不進模擬，開打前就從卡池拿掉了）
var ai_style := 0              # AI 性格：0 均衡、1 鐵壁、2 遠程、3 奇襲、4 召喚、5 亂數（不進模擬）
# ── 第十二輪手動技能（進模擬）──
var cmd_mask := [0, 0]         # 雙方帶哪幾種；都 0＝關閉
var cmd_uses := 1              # 每種可用次數
var cmd_cd := 400              # 同一種的冷卻（tick）
var cmd_power := 100           # 效果強度 %
var adj := false               # V1.6 #22 相鄰陣法（娛樂）：開戰時相鄰的指定組合拿小加成；關＝舊路徑
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
# ── 部署（第六輪）──
var deploy := "grid"
var spacing := 1000            # 自由部署的最小中心距離（單位：1 格＝1000）
var depth := DEPTH_GRID        # 自己視角的 x 上限
var fullfield := FULL_NONE
# 只是顯示用，不參與相等判定
var preset := "standard"

# ───────── 卡池工具（static，給 AI／Army 用） ─────────
static func _not_combat(t: int) -> bool:
	return not D.is_combat(t)   # 第八輪：奇襲兵也不算戰鬥兵

static func all_pool() -> int:
	return (1 << D.COUNT) - 1      # 舊 10 種。標準、AI、舊規則都看這個，不能跟著新兵變大

## 第八輪：新舊 20 種全部（只給驗證與大廳用）。
static func full_pool() -> int:
	return (1 << D.total()) - 1

## 這個卡池有沒有用到新兵。
static func has_new(p: int) -> bool:
	return p > all_pool()

static func prefix_pool(n: int) -> int:
	return (1 << clampi(n, 0, D.COUNT)) - 1

static func has(p: int, t: int) -> bool:
	return (p >> t) & 1 == 1

static func types_of(p: int) -> Array:
	var out: Array = []
	for t in D.total():
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
		if not _not_combat(t):
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
	r.deploy = deploy
	r.spacing = spacing
	r.depth = depth
	r.fullfield = fullfield
	r.map_id = map_id
	r.map_size = map_size
	r.vents = vents
	r.map_mode = map_mode
	r.ai_style = ai_style
	r.bans = bans
	r.time_of = time_of
	r.skills_off = skills_off.duplicate()
	r.cmd_mask = cmd_mask.duplicate()
	r.cmd_uses = cmd_uses
	r.cmd_cd = cmd_cd
	r.cmd_power = cmd_power
	r.adj = adj
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
	return ticks == STD_TICKS and judge() == 1 and not is_sandbox() and deploy == "grid" and map_is_default() and not cmd_on() and not adj

func cmd_on() -> bool:
	return int(cmd_mask[0]) != 0 or int(cmd_mask[1]) != 0

## V9：平原＋標準大小走舊路徑，位元組完全不變。
func map_is_default() -> bool:
	return map_id == 0 and map_size == MapDefs.STD_SIZE and not vents

func field_w() -> int:
	return MapDefs.width(map_size)

func field_h() -> int:
	return MapDefs.height(map_size)

## 沒有地形回 null（平原），呼叫端可以直接略過。
func terrain():
	return MapDefs.terrain(map_id, map_size)

func is_free() -> bool:
	return deploy == "free"

## 這組規則的部署欄位是不是「舊的」（格子、6 欄、沒有全場）：規則代碼可以用 NTBR1。
func deploy_is_default() -> bool:
	return deploy == "grid" and spacing == 1000 and depth == DEPTH_GRID and fullfield == FULL_NONE

## 這一隊實際的 x 上限（自己視角）。全場時到對面。
## 自己半場的縱深（換算過地圖大小，不管全場）。
func half_depth() -> int:
	if map_size != MapDefs.STD_SIZE:
		return (depth * field_w() / 16000) / 50 * 50
	return depth

func depth_of() -> int:
	if map_size != MapDefs.STD_SIZE:
		# V9：縱深照比例；全場到對面邊界
		return field_w() - 200 if fullfield != FULL_NONE else (depth * field_w() / 16000) / 50 * 50
	return DEPTH_FULL if fullfield != FULL_NONE else depth

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
	if cmd_on():
		var CMD = load("res://scripts/core/cmd_defs.gd")
		for tm0 in 2:
			var m0 := int(cmd_mask[tm0])
			if m0 < 0 or m0 >= (1 << CMD.COUNT) or CMD.count_of(m0) < 1 or CMD.count_of(m0) > CMD.MAX_SLOTS:
				bad.append("rr_bad_cmd")
				break
		if not cmd_uses in CMD.USES or not cmd_cd in CMD.CD_TICKS or not cmd_power in CMD.POWERS:
			bad.append("rr_bad_cmd")
	if map_id < 0 or map_id >= MapDefs.MAPS.size() or map_size < 0 or map_size >= MapDefs.SIZES.size():
		bad.append("rr_bad_map")
	elif not map_is_default() and deploy != "free":
		bad.append("rr_map_free_only")
	elif vents and map_id != MapDefs.LAVA:
		bad.append("rr_bad_map")
	for tm in 2:
		var b := budget_of(tm)
		if b < BUDGET_MIN or b > BUDGET_MAX:
			bad.append("rr_bad_budget")
		var p := pool_of(tm)
		if p <= 0 or p > full_pool():
			bad.append("rr_bad_pool")
		elif pool_count(p) > 10:
			bad.append("rr_roster_over")   # 第八輪：一局每邊最多 10 種
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
		if int(t) < 0 or int(t) >= D.total() or not stat_pct[t] is Array or stat_pct[t].size() != 3:
			bad.append("rr_bad_sandbox")
			break
		for v in stat_pct[t]:
			if int(v) < PCT_MIN or int(v) > PCT_MAX:
				bad.append("rr_bad_sandbox")
				break
	for s in skills_off:
		if not s in SKILLS and not s in F8.SKILLS:
			bad.append("rr_bad_sandbox")
			break
	# 第六輪：部署欄位與非法組合（§3.8）
	if not deploy in DEPLOYS or spacing < SPACING_MIN or spacing > SPACING_MAX or spacing % 50 != 0 \
			or depth < DEPTH_MIN or depth > DEPTH_MAX or depth % 500 != 0 or fullfield < 0 or fullfield > 2:
		bad.append("rr_bad_deploy")
	elif deploy == "grid" and (spacing != 1000 or depth != DEPTH_GRID or fullfield != FULL_NONE):
		bad.append("rr_bad_deploy")
	elif fullfield != FULL_NONE and place_rule == "blind":
		bad.append("rr_full_blind")
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
	var out: Array = [budget_of(0), budget_of(1), 1 if handicap else 0, ticks, unit_cap, type_cap, pool_of(0), pool_of(1), 1 if ai_pool_same else 0,
		rounds, place_rule, turns, 1 if carry else 0, 1 if keep_formation else 0, ai_level, sp, so]
	if not deploy_is_default():
		out.append_array([DEPLOYS.find(deploy), spacing, depth, fullfield])   # 第六輪 NTBR2 的 4 欄
	return out

## 模擬那一層的摘要（非舊路徑時加進模擬雜湊）。
func sim_digest() -> String:
	var sp: Array = []
	var keys := stat_pct.keys()
	keys.sort()
	for t in keys:
		sp.append([int(t), stat_pct[t]])
	var so := skills_off.duplicate()
	so.sort()
	var base: Array = [budget_of(0), budget_of(1), ticks, judge(), sp, so]
	if not map_is_default():
		base.append_array(["map", map_id, map_size, 1 if vents else 0, MapDefs.digest(map_id, map_size)])
	if cmd_on():
		base.append_array(["cmd", cmd_mask[0], cmd_mask[1], cmd_uses, cmd_cd, cmd_power])
	if deploy == "free":
		base.append_array(["free", spacing, depth, fullfield])   # 第六輪：自由部署進模擬摘要（格子部署時摘要不變）
	if adj:
		base.append_array(["adj", 1])   # V1.6 #22（關的時候摘要不變）
	return JSON.stringify(base).sha256_text().substr(0, 16)

func equals(o) -> bool:
	return JSON.stringify(key_fields()) == JSON.stringify(o.key_fields()) and cmd_mask == o.cmd_mask and (not cmd_on() or (cmd_uses == o.cmd_uses and cmd_cd == o.cmd_cd and cmd_power == o.cmd_power))

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
	if deploy != std.deploy:
		out.append(["rr_deploy", std.deploy, deploy])
	if spacing != std.spacing and deploy == "free":
		out.append(["rr_spacing", std.spacing, spacing])
	if depth != std.depth and deploy == "free" and fullfield != FULL_DUEL:   # 雙人全場不用縱深
		out.append(["rr_depth", std.depth, depth])
	if fullfield != std.fullfield:
		out.append(["rr_full", std.fullfield, fullfield])
	if cmd_on():
		out.append(["rr_cmd", 0, 1])
	if adj:
		out.append(["rr_adj", 0, 1])
	return out

# ───────── 代碼 ─────────
## NTBR1.<base64url(JSON 陣列)>.<校驗 6 碼>；固定欄序、整數型別。
func to_code() -> String:
	var j := JSON.stringify(key_fields())
	var body := Marshalls.utf8_to_base64(j).replace("+", "-").replace("/", "_").replace("=", "")
	if adj:
		var j6 := JSON.stringify((key_fields() if not deploy_is_default() else key_fields() + [DEPLOYS.find(deploy), spacing, depth, fullfield]) + [map_id, map_size, 1 if vents else 0, int(cmd_mask[0]), int(cmd_mask[1]), cmd_uses, cmd_cd, cmd_power, 1])
		var b6 := Marshalls.utf8_to_base64(j6).replace("+", "-").replace("/", "_").replace("=", "")
		return "%s.%s.%s" % [CODE_PREFIX6, b6, b6.sha256_text().substr(0, 6)]
	if cmd_on():
		var j5 := JSON.stringify((key_fields() if not deploy_is_default() else key_fields() + [DEPLOYS.find(deploy), spacing, depth, fullfield]) + [map_id, map_size, 1 if vents else 0, int(cmd_mask[0]), int(cmd_mask[1]), cmd_uses, cmd_cd, cmd_power])
		var b5 := Marshalls.utf8_to_base64(j5).replace("+", "-").replace("/", "_").replace("=", "")
		return "%s.%s.%s" % [CODE_PREFIX5, b5, b5.sha256_text().substr(0, 6)]
	if not map_is_default():
		var j4 := JSON.stringify((key_fields() if not deploy_is_default() else key_fields() + [DEPLOYS.find(deploy), spacing, depth, fullfield]) + [map_id, map_size, 1 if vents else 0])
		var b4 := Marshalls.utf8_to_base64(j4).replace("+", "-").replace("/", "_").replace("=", "")
		return "%s.%s.%s" % [CODE_PREFIX4, b4, b4.sha256_text().substr(0, 6)]
	# 用到新兵一律 NTBR3（欄位同 NTBR2：21 欄）
	if has_new(int(pool[0])) or has_new(int(pool[1])) or _skills_new():
		var j3 := JSON.stringify(key_fields() if not deploy_is_default() else key_fields() + [DEPLOYS.find(deploy), spacing, depth, fullfield])
		var b3 := Marshalls.utf8_to_base64(j3).replace("+", "-").replace("/", "_").replace("=", "")
		return "%s.%s.%s" % [CODE_PREFIX3, b3, b3.sha256_text().substr(0, 6)]
	return "%s.%s.%s" % [CODE_PREFIX if deploy_is_default() else CODE_PREFIX2, body, body.sha256_text().substr(0, 6)]

func _skills_new() -> bool:
	for s in skills_off:
		if s in F8.SKILLS:
			return true
	for t in stat_pct:
		if int(t) >= D.COUNT:
			return true
	return false

## 回傳 {ok, why, rules}
static func from_code(code: String) -> Dictionary:
	var c := code.strip_edges()
	if c.length() > 2000:
		return {"ok": false, "why": "rr_code_long"}
	var parts := c.split(".")
	if parts.size() != 3 or (parts[0] != CODE_PREFIX and parts[0] != CODE_PREFIX2 and parts[0] != CODE_PREFIX5 and parts[0] != CODE_PREFIX3 and parts[0] != CODE_PREFIX4 and parts[0] != CODE_PREFIX6):
		return {"ok": false, "why": "rr_code_format"}
	var v6: bool = parts[0] == CODE_PREFIX6
	var v5: bool = parts[0] == CODE_PREFIX5 or v6
	var v4: bool = parts[0] == CODE_PREFIX4 or v5
	var v3: bool = parts[0] == CODE_PREFIX3 or v4
	var v2: bool = parts[0] == CODE_PREFIX2 or v3
	if parts[1].sha256_text().substr(0, 6) != parts[2]:
		return {"ok": false, "why": "rr_code_checksum"}
	var b64 := parts[1].replace("-", "+").replace("_", "/")
	while b64.length() % 4 != 0:
		b64 += "="
	var j = JSON.parse_string(Marshalls.base64_to_utf8(b64))
	if not j is Array or j.size() != (30 if v6 else (29 if v5 else (24 if v4 else (21 if v2 else 17)))):
		return {"ok": false, "why": "rr_code_body"}
	if v6:
		if not (j[29] is float or j[29] is int) or float(j[29]) != 1.0:
			return {"ok": false, "why": "rr_code_body"}   # NTBR6 一定是相鄰陣法開著
		j = j.slice(0, 29)
	var cmd_f: Array = []
	if v5:
		cmd_f = j.slice(24)
		j = j.slice(0, 24)
		for vc in cmd_f:
			if not (vc is float or vc is int) or float(vc) != floorf(float(vc)):
				return {"ok": false, "why": "rr_code_body"}
	if v4:
		for i4 in [21, 22, 23]:
			if not (j[i4] is float or j[i4] is int) or float(j[i4]) != floorf(float(j[i4])):
				return {"ok": false, "why": "rr_code_body"}
		if int(j[21]) < 0 or int(j[21]) >= MapDefs.MAPS.size() or int(j[22]) < 0 or int(j[22]) >= MapDefs.SIZES.size() or (int(j[23]) != 0 and int(j[23]) != 1):
			return {"ok": false, "why": "rr_bad_map"}
	if v2:
		for i in [17, 18, 19, 20]:
			if not (j[i] is float or j[i] is int) or float(j[i]) != floorf(float(j[i])) or absf(float(j[i])) > 100000:
				return {"ok": false, "why": "rr_code_body"}
		if int(j[17]) < 0 or int(j[17]) >= DEPLOYS.size():
			return {"ok": false, "why": "rr_bad_deploy"}
	# 逐欄驗型（Codex 實作第 1 輪）：整數欄必須是整數、布林欄只能 0／1、兩個卡池原值都要合法（即使 AI 卡池跟藍方一樣）
	for i in [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14]:
		if v3 and (i == 6 or i == 7):
			if not (j[i] is float or j[i] is int) or float(j[i]) != floorf(float(j[i])) or absf(float(j[i])) > float(full_pool()):
				return {"ok": false, "why": "rr_code_body"}
			continue   # 第八輪：卡池遮罩最大 1,048,575，只放寬這兩欄
		if not (j[i] is float or j[i] is int) or float(j[i]) != floorf(float(j[i])) or absf(float(j[i])) > 100000:
			return {"ok": false, "why": "rr_code_body"}
	for i in [2, 8, 12, 13]:
		if int(j[i]) != 0 and int(j[i]) != 1:
			return {"ok": false, "why": "rr_code_body"}
	for i in [6, 7]:
		if int(j[i]) < 1 or int(j[i]) > (full_pool() if v3 else all_pool()):
			return {"ok": false, "why": "rr_bad_pool"}
	if not j[10] is String or not j[15] is Array or not j[16] is Array or j[15].size() > D.total() or j[16].size() > SKILLS.size() + F8.SKILLS.size():
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
	if v2:
		r.deploy = DEPLOYS[int(j[17])]
		r.spacing = int(j[18])
		r.depth = int(j[19])
		r.fullfield = int(j[20])
		if v4:
			r.map_id = int(j[21])
			r.map_size = int(j[22])
			r.vents = int(j[23]) == 1
			if r.map_is_default() and not v5:
				return {"ok": false, "why": "rr_code_body"}   # 標準地圖不能用 NTBR4（一組規則只有一種寫法）
		if r.deploy_is_default() and not v3:
			return {"ok": false, "why": "rr_code_body"}   # 預設部署必須用 NTBR1（一組規則只有一種寫法）
	if v5:
		r.cmd_mask = [int(cmd_f[0]), int(cmd_f[1])]
		r.cmd_uses = int(cmd_f[2])
		r.cmd_cd = int(cmd_f[3])
		r.cmd_power = int(cmd_f[4])
		if not r.cmd_on() and not v6:
			return {"ok": false, "why": "rr_code_body"}   # 沒開技能不能用 NTBR5（一組規則只有一種寫法）
	r.adj = v6
	r.preset = "custom"
	var bad: Array = r.validate()
	if not bad.is_empty():
		return {"ok": false, "why": bad[0]}
	return {"ok": true, "why": "", "rules": r}
