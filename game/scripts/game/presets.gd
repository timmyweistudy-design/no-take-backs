extends RefCounted
## 規則大廳的預設組合與徽章（第五輪 §3.5）。純函式，不碰畫面。
## kind："ai"（對 AI 快速對戰）、"duel"（同機雙人）。
## unlocked：玩家已解鎖的卡池遮罩（對 AI 用；雙人不看個人進度，只受試玩版限制）。

const D = preload("res://scripts/core/unit_defs.gd")
const RSET = preload("res://scripts/core/ruleset.gd")

const IDS := ["standard", "classic5", "all10", "small", "big", "single"]
const BADGE_CERT := "cert"       # 平衡認證（綠）
const BADGE_FUN := "fun"         # 娛樂變體（黃）
const BADGE_LAB := "lab"         # 沙盒（紫）
# 第六輪：自由排兵的標準間距與縱深（§6.3 全因子實驗後決定）
const FREE_SPACING := 800
const FREE_DEPTH := 7500

static func make(id: String, kind: String, unlocked: int):
	var r = RSET.standard(unlocked)
	r.preset = id
	r.rounds = 3
	r.place_rule = "snake5"
	match id:
		"standard":
			if kind == "duel":
				r.pool = [31, 31]       # 雙人標準＝經典 5 種（唯一驗證過公平的組合）
		"classic5":
			r.pool = [31, 31]
		"all10":
			r.pool = [unlocked, unlocked]
		"small":
			r.budget = [50, 50]
			r.unit_cap = 12
			r.ticks = 1200
		"big":
			r.budget = [180, 180]
			r.unit_cap = 40
			r.ticks = 2400
		"single":
			# 單兵種對決：只開 1 種戰鬥兵（劍士）＋1 種支援兵（醫者）；卡池分頁可以換
			r.pool = [(1 << D.SWORD) | (1 << D.MEDIC), (1 << D.SWORD) | (1 << D.MEDIC)]
	if kind == "duel":
		r.ai_pool_same = true
	return r

## 卡池是不是「前 N 種、N≥5」（第四輪 AI 驗收只驗過經典 5 種到全部 10 種的前綴卡池）。
static func is_prefix(p: int) -> bool:
	return p >= 31 and (p & (p + 1)) == 0

## 徽章：動到沙盒＝沙盒；驗證過的組合＝平衡認證；其他＝娛樂變體。
## 對 AI：100 金、24 隻、不限單種、90 秒、前綴卡池（第四輪驗收的條件）。
## 雙人：再加上經典 5 種＋snake5（第四輪 snake5 三種 AI 強度都在 45～55%）。
static func badge(r, kind: String) -> String:
	if r.is_sandbox():
		return BADGE_LAB
	var base: bool = r.budget_of(0) == 100 and r.budget_of(1) == 100 and r.unit_cap == 24 and r.type_cap == 0 and r.ticks == 1800
	# 第六輪：部署也要是驗過的——格子，或自由＋預設的間距與縱深；全場一律算娛樂變體
	base = base and deploy_certified(r)
	if kind == "ai":
		return BADGE_CERT if base and is_prefix(r.pool_of(0)) and r.pool_of(1) == r.pool_of(0) else BADGE_FUN
	return BADGE_CERT if base and r.pool_of(0) == 31 and r.pool_of(1) == 31 and r.place_rule == "snake5" and not r.carry else BADGE_FUN

static func deploy_certified(r) -> bool:
	if r.fullfield != 0:
		return false
	return r.deploy == "grid" or (r.spacing == FREE_SPACING and r.depth == FREE_DEPTH)

## 算不算「標準紀錄」（標準戰績、標準成就；Codex 實作第 1 輪：和「平衡認證」分開判定）。
## 除了認證條件，系列也要是標準的：三戰兩勝、保留陣型、沒有讓子；對 AI 卡池兩邊相同；雙人 snake5、不累積。
static func is_standard_record(r, kind: String) -> bool:
	if badge(r, kind) != BADGE_CERT:
		return false
	if r.rounds != 3 or not r.keep_formation or r.handicap:
		return false
	if kind == "ai":
		return r.ai_pool_same
	return r.place_rule == "snake5" and not r.carry

## 部署限制是不是「標準」（前 N 種卡池、24 隻、不限單種、100 金）：對戰代碼可以用舊格式 NTB2、AI 不額外補兵。
static func deploy_standard(r) -> bool:
	return r.unit_cap == 24 and r.type_cap == 0 and r.budget_of(0) == 100 and r.budget_of(1) == 100 and is_prefix(r.pool_of(0)) and r.pool_of(1) == r.pool_of(0)

## 大廳卡池能選的兵：對 AI＝已解鎖的；雙人＝全部（試玩版＝前 7 種）。
static func selectable(kind: String, unlocked: int, demo: bool) -> int:
	var all_p: int = RSET.prefix_pool(7) if demo else RSET.all_pool()
	return (unlocked & all_p) if kind == "ai" else all_p

## 把規則裡不能選的兵拿掉（解鎖進度、試玩版）；拿掉後沒有戰鬥兵就退回可選的全部。回傳被拿掉的兵種。
static func clamp_pool(r, kind: String, unlocked: int, demo: bool) -> Array:
	var sel := selectable(kind, unlocked, demo)
	var removed: Array = []
	for tm in 2:
		var p := int(r.pool[tm])
		for t in D.COUNT:
			if RSET.has(p, t) and not RSET.has(sel, t) and not t in removed:
				removed.append(t)
		p &= sel
		if not RSET.has_combat(p):
			p = sel
		r.pool[tm] = p
	return removed
