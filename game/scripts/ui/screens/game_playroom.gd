extends "res://scripts/ui/screens/game_modes.gd"
const PlayroomRules = preload("res://scripts/game/playroom_rules.gd")
## V1.6 #4：由 game_modes.gd 拆出（行為不變）：遊戲間（競猜、輪抽、車輪戰、雙封蠟）、塗裝室、幽靈軍團與每週棋盒。

## ── V1.4 #16 遊戲間：觀戰競猜、輪抽 ──
var wg_armies: Array = []      # 競猜：兩支 AI 軍
var wg_pick := [-1, -1]        # [押哪一隊, 剩餘戰力區間 0 險勝／1 普通／2 大勝]
var wg_active := false
var df_pool: Array = []        # 輪抽：公池 8 張
var df_mine: Array = []
var df_ai: Array = []

## 競猜：用 AI 組兩支軍隊（同樣 100 金），先看陣型再押注。
func _wager_new() -> void:
	var r := RandomNumberGenerator.new()
	r.randomize()
	if shot_dir != "" and bool(get("shot_fixed")):
		r.seed = 20261111   # 1.2.0 §14.6：視覺回歸模式固定（同一份程式重拍要一致）
	wg_armies = [AI.build(0, 100, r)["army"], AI.build(1, 100, r)["army"]]
	wg_pick = [-1, -1]
	overlay = "wager"

func _draw_wager() -> void:
	_dim(0.6)
	var P := Rect2(160, 70, 960, 660)
	_panel(P)
	# V1.5.2 L3：說明從緞帶下緣＋16 起；說明換行時下面整塊一起往下（dy）
	var dy := maxf(0.0, _h1_help(Vector2(640, 82), L.t("pr_wager"), L.t("wg_help"), tz("S"), 880) - 180.0)
	# 兩支軍隊的陣型縮影（羊皮紙棋盤），藍左紅右
	for side in 2:
		var a = wg_armies[side]
		var g := Rect2(200 + side * 450, 180 + dy, 430, 250)
		_tex_box(g, "paper")
		# 標題放在木條上（不是白底橫條，Antigravity v140-i2）
		var hb := Rect2(g.position + Vector2(8, 8), Vector2(g.size.x - 16, tz("B") * 1.5))
		_tex_box(hb, "wood", Charts.team_col(side, cbm()).darkened(0.45))
		_text(hb.position + Vector2(12, tz("B") * 0.18), L.t("blue") if side == 0 else L.t("red"), tz("B"), Color.WHITE, false, true, 160)
		_text(Vector2(hb.end.x - 12 - minf(170.0, _width(L.t("wg_units", [a.units.size(), a.spent()]), tz("C"))), hb.position.y + (tz("B") * 1.5 - tz("C")) * 0.42), L.t("wg_units", [a.units.size(), a.spent()]), tz("C"), Color.WHITE, false, false, 170)
		for u in a.units:
			var c: int = int(u["col"]) if side == 0 else int(u["col"]) - 10
			var q := g.position + Vector2(40 + c * 60, 64 + int(u["row"]) * 20)
			Art.unit(self, q, int(u["type"]), side, 1.0 if side == 0 else -1.0, 0.0, 0.0, 0.0, 1.0, time, 0.42, cbm())
	_text(Vector2(640, 290 + dy), "VS", tz("H1"), Color("#ffd166"), true, true, 60)
	# 押注：哪一隊贏、贏多少
	var y := 452.0 + dy
	_text(Vector2(200, y), L.t("wg_who"), tz("S"), Color.WHITE, false, true, 300)
	for side in 2:
		_btn(Rect2(480 + side * 220, y - 6, 200, 44), L.t("blue") if side == 0 else L.t("red"), func(): wg_pick[0] = side, true, false, Charts.team_col(side, cbm()).darkened(0.25) if wg_pick[0] == side else Color(0, 0, 0, 0))
	y += 60
	_text(Vector2(200, y), L.t("wg_how"), tz("S"), Color.WHITE, false, true, 300)
	for b in 3:
		_btn(Rect2(480 + b * 150, y - 6, 140, 44), L.t("wg_band_%d" % b), func(): wg_pick[1] = b, true, false, TH_ACTIVE if wg_pick[1] == b else Color(0, 0, 0, 0))
	# V1.5：「贏多少」看的是勝方剩下的戰力比例，區間門檻跟 wager_band 用同一組常數
	_text(Vector2(640, y + 48), L.t("wg_band_help", [WG_NARROW, WG_NARROW, WG_CRUSH - 1, WG_CRUSH]), tz("C"), TXT_DIM, true, false, 880)
	var by := maxf(640.0, y + 48 + text_h(L.t("wg_band_help", [WG_NARROW, WG_NARROW, WG_CRUSH - 1, WG_CRUSH]), tz("C"), 880) + GAP_M)
	# V1.5.2 L8：雙按鈕同寬、群組置中
	_btn(Rect2(425, by, 210, 50), L.t("wg_go"), func(): _wager_go(), wg_pick[0] >= 0 and wg_pick[1] >= 0, true)
	_btn(Rect2(645, by, 210, 50), L.t("back"), func(): overlay = "playroom")

func _wager_go() -> void:
	wg_active = true
	# 先把連中歸零存起來：觀戰中途離開＝這場沒押中，不能靠逃跑保連勝（Antigravity v150-i2 #7）
	var eye0: Dictionary = Save.data.get("eye", {})
	eye0["pend"] = int(eye0.get("streak", 0))
	eye0["streak"] = 0
	Save.data["eye"] = eye0
	Save.save_data()
	call("watch_code", wg_armies[0], wg_armies[1], null)

## 剩餘戰力落在哪一區：0 險勝（<34%）、1 普通、2 大勝（≥67%）。
const WG_NARROW := PlayroomRules.WG_NARROW
const WG_CRUSH := PlayroomRules.WG_CRUSH
static func wager_band(rem: int) -> int:
	return PlayroomRules.wager_band(rem)   # 1.1.0 A22：純邏輯搬到 scripts/game/playroom_rules.gd

## 結算：押對勝方 1 分、連區間也對再 1 分。存「眼力」：總分、場數、最高連對。
func _wager_settle() -> void:
	if not wg_active or sim == null:
		return
	wg_active = false
	var w: int = sim.winner
	var rem: int = PZ.rem_pct(sim.power(w), sim.budget_of(w)) if w >= 0 else 0
	var pts := 0
	if w == int(wg_pick[0]):
		pts += 1
		if wager_band(rem) == int(wg_pick[1]):
			pts += 1
	var eye: Dictionary = Save.data.get("eye", {})
	eye["n"] = int(eye.get("n", 0)) + 1
	eye["pts"] = int(eye.get("pts", 0)) + pts
	eye["streak"] = int(eye.get("pend", eye.get("streak", 0))) + 1 if pts > 0 else 0
	eye.erase("pend")
	eye["best"] = maxi(int(eye.get("best", 0)), int(eye["streak"]))
	if int(eye["streak"]) >= 5:
		call("_ach", "SHARP_EYE")
	Save.data["eye"] = eye
	Save.save_data()
	report["wager_line"] = L.t("wg_res_%d" % pts, [rem])

## 輪抽：公池 8 張（舊 10 種裡抽，至少 6 張戰鬥兵），你先抽、輪流各 4 張，抽到的就是這一場的卡池。
func _draft_new() -> void:
	var r := RandomNumberGenerator.new()
	r.randomize()
	if shot_dir != "" and bool(get("shot_fixed")):
		r.seed = 20261111   # 1.2.0 §14.6：視覺回歸模式固定（同一份程式重拍要一致）
	var ids: Array = range(10)
	df_pool = []
	while df_pool.size() < 8:
		var k: int = ids[r.randi() % ids.size()]
		ids.erase(k)
		df_pool.append(k)
	df_pool.sort()
	df_mine = []
	df_ai = []
	overlay = "draft"

func _draft_take(t: int) -> void:
	if t in df_mine or t in df_ai or df_mine.size() >= 4:
		return
	df_mine.append(t)
	# AI 抽：剩下的裡面最貴的戰鬥兵優先（簡單、可預期）
	var best := -1
	for x in df_pool:
		if x in df_mine or x in df_ai:
			continue
		if best < 0 or D.cost(int(x)) > D.cost(best):
			best = int(x)
	if best >= 0 and df_ai.size() < 4:
		df_ai.append(best)

static func draft_mask(list: Array) -> int:
	return PlayroomRules.draft_mask(list)   # 1.1.0 A22：純邏輯搬到 scripts/game/playroom_rules.gd

func _draft_go() -> void:
	var r = RuleSet.standard()
	var m0 := draft_mask(df_mine)
	var m1 := draft_mask(df_ai)
	if not RuleSet.has_combat(m0) or not RuleSet.has_combat(m1):
		_toast(L.t("df_no_combat"), true)
		return
	r.pool = [m0, m1]
	r.ai_pool_same = false   # 電腦用自己抽到的牌（Codex v140-i2）
	r.rounds = 1
	rules = r
	challenge_army = null
	overlay = ""
	_start_mode(Mode.VS_AI)

func _draw_draft() -> void:
	_dim(0.6)
	var P := Rect2(160, 80, 960, 640)
	_panel(P)
	var dy := maxf(0.0, _h1_help(Vector2(640, 92), L.t("pr_draft"), L.t("df_help"), tz("S"), 880) - 190.0)   # V1.5.2 L3
	for i in df_pool.size():
		var t: int = df_pool[i]
		var r := Rect2(210 + (i % 4) * 220, 190 + dy + (i / 4) * 190, 200, 172)
		var mine: bool = t in df_mine
		var ai: bool = t in df_ai
		btn_paper = not mine and not ai
		_btn(r, "", _draft_take.bind(t), not mine and not ai and df_mine.size() < 4)
		btn_paper = false
		if (mine or ai) and not bool(Save.s("plain_ui")):
			_tex_box(r.grow(-2), "paper")   # 抽走的卡也留紙底（只用隊伍色框標歸屬；收尾第 2 輪：深色像停用）
		Art.unit(self, r.position + Vector2(100, 98), t, 0 if not ai else 1, 1.0, 0.0, 0.0, 0.0, 1.0 if not (mine or ai) else 0.55, time, 0.9, cbm())
		var paper_on: bool = (bool(_btns[_btns.size() - 1]["en"]) or mine or ai) and not bool(Save.s("plain_ui"))
		_ink_mode = paper_on   # 停用或簡化介面時卡片是深色木牌：字用淺色（V1.4 版面檢查：對比不足）
		_text(r.position + Vector2(100, 106), L.t("unit_%d" % t), tz("S"), INK if _ink_mode else Color.WHITE, true, true, 190)
		_text(r.position + Vector2(100, 106 + tz("S") * 1.3), L.t("gold", [D.cost(t)]), tz("C"), Color("#7a4a10") if _ink_mode else ACCENT, true, false, 190)
		_ink_mode = false
		if mine or ai:
			# 抽走的卡：隊伍色邊框＋火漆印（Antigravity v140-i2）
			var tcol: Color = Charts.team_col(0 if mine else 1, cbm())
			draw_rect(r.grow(-3), tcol, false, 3.0)
			var sc := r.position + Vector2(r.size.x - 26, 26)
			draw_circle(sc, 17.0, tcol.darkened(0.35), true, -1.0, true)
			draw_circle(sc, 13.0, tcol, true, -1.0, true)
			_text(r.position + Vector2(100, 12), L.t("df_mine") if mine else L.t("df_ai"), tz("S"), Color.WHITE, true, true, 150)
	_text(Vector2(640, 582 + dy), L.t("df_count", [df_mine.size(), df_ai.size()]), tz("S"), Color.WHITE, true, true, 700)
	# V1.5.2 L8：雙按鈕同寬、群組置中
	var by := maxf(640.0, 582 + dy + tz("S") * 1.3 + GAP_M)
	_btn(Rect2(425, by, 210, 50), L.t("df_go"), func(): _draft_go(), df_mine.size() == 4, true)
	_btn(Rect2(645, by, 210, 50), L.t("back"), func(): overlay = "playroom")


## ── V1.4 #11 車輪戰：擺一次陣迎三波；贏了只帶活下來的兵（站在原本的格子），多 15 金重新整備，下一波敵人更多錢 ──
const WAVE_FOE := [70, 90, 110]
var wv_active := false   # 這一輪車輪戰還在打
var wv_mode := false     # 結果頁要顯示車輪戰的按鈕（離開才清）
var wv_no := 0

var wv_lock: Array = []   # 這一波帶進來的殘兵（不能撤、不能移）
var wv_surv: Array = []   # 上一波戰鬥結束當下的殘兵
var wv_codes: Array = []  # V1.5.1 D1：這一輪每一波的對戰代碼（整場三波一起分享）
var wv_view: Array = []   # 貼上車輪戰代碼後，等著選看第幾波

## V1.5.1 D1 車輪戰代碼 NTW1：包起每一波的既有對戰代碼（不重做模擬格式）。缺波＝提早輸掉，只有打過的那幾波。
static func wave_code(codes: Array) -> String:
	return PlayroomRules.wave_code(codes)   # 1.1.0 A22：純邏輯搬到 scripts/game/playroom_rules.gd

## 解開車輪戰代碼：回傳每一波的對戰代碼（1～3 筆，每筆都要是對戰代碼）；壞碼回傳空陣列
static func wave_decode(c: String) -> Array:
	return PlayroomRules.wave_decode(c)   # 1.1.0 A22：純邏輯搬到 scripts/game/playroom_rules.gd

static func wave_has_lock(units: Array, lock: Array) -> bool:
	return PlayroomRules.wave_has_lock(units, lock)   # 1.1.0 A22：純邏輯搬到 scripts/game/playroom_rules.gd

func wave_is_locked(c: Vector2i) -> bool:
	if not wv_active:
		return false
	for u in wv_lock:
		if int(u["col"]) == c.x and int(u["row"]) == c.y:
			return true
	return false

func _wave_start() -> void:
	wv_active = true
	wv_no = 1
	wv_codes = []
	_wave_setup([], 100)

func _wave_setup(surv: Array, budget: int) -> void:
	var r = RuleSet.standard()
	r.rounds = 1
	r.handicap = true
	r.budget = [clampi(budget, RuleSet.BUDGET_MIN, RuleSet.BUDGET_MAX), WAVE_FOE[clampi(wv_no - 1, 0, 2)]]
	rules = r
	challenge_army = null
	overlay = ""
	set("daily_spec", {})   # 從每日挑戰過來不能帶著每日的敵陣（Antigravity v140-i3）
	_start_mode(Mode.VS_AI)
	set("daily_spec", {})
	wv_active = true
	wv_mode = true
	wv_lock = surv.duplicate(true)
	if not surv.is_empty():
		armies[0].units = surv.duplicate(true)
	_toast(L.t("wv_toast", [wv_no, WAVE_FOE[clampi(wv_no - 1, 0, 2)]]))

## 這一波活下來的我方兵（原本的格子）與它們值多少錢。
static func wave_survivors(army, sim0) -> Array:
	var out: Array = []
	for u in army.units:
		if PZ.unit_alive(sim0, 0, [int(u["col"]), int(u["row"])]):
			out.append({"type": int(u["type"]), "col": int(u["col"]), "row": int(u["row"])})
	return out

func _wave_next() -> void:
	var surv: Array = wv_surv.duplicate(true)   # 戰鬥結束當下就算好（看完重播、時光機都不影響，Antigravity v140-i3）
	var cost := 0
	for u in surv:
		cost += D.cost(int(u["type"]))
	wv_no += 1
	_wave_setup(surv, cost + 15)

func _wave_end(won: bool) -> void:
	if not wv_active:
		return
	var reached := wv_no if won else wv_no - 1
	Save.data["wave_best"] = maxi(int(Save.data.get("wave_best", 0)), reached)
	Save.save_data()
	_toast(L.t("wv_all") if won else L.t("wv_over", [reached]))
	if won and reached >= 3:
		call("_ach", "WAVE_3")
	wv_active = false


## ── V1.4 #13 雙封蠟戰書：雙人，每人先封三個陣（暗擺），再依序兩兩揭曉交鋒，三戰兩勝 ──
var sealed_on := false
var sealed := [[], []]

func _sealed_start() -> void:
	var r = RuleSet.standard()
	r.place_rule = "blind"
	r.rounds = 3
	rules = r
	challenge_army = null
	overlay = ""
	_start_mode(Mode.DUEL)
	sealed_on = true
	sealed = [[], []]
	_toast(L.t("sealed_intro"))

## ── 1.2.0 §11.7 戰役「老闆的棋館」 ──
const Campaign = preload("res://scripts/game/campaign.gd")
var camp_id := ""      # 正在打的戰役關（""＝不是戰役）
var camp_ch := 1       # 戰役面板目前看第幾章

func _camp_open() -> void:
	overlay = "campaign"
	_focus = 0
	for ch in Campaign.chapters():   # 打開時停在第一個還沒通的章
		if not Campaign.chapter_cleared(Save.data, ch):
			camp_ch = int(ch["n"])
			break

func _camp_play(id: String) -> void:
	var st := Campaign.stage(id)
	if st.is_empty() or not Campaign.unlocked(Save.data, id):
		return
	overlay = ""
	if str(st["goal"]) == "puzzle":
		var pid := Campaign.puzzle_id(st)
		if pid != "":
			call("_pick_puzzle", pid, false)
		return
	var r = Campaign.rules_of(st)
	rules = r
	challenge_army = Campaign.enemy_of(st, r)
	_start_mode(Mode.VS_AI)
	camp_id = id
	_toast(_camp_goal(st))

func _camp_goal(st: Dictionary) -> String:
	match str(st["goal"]):
		"keep":
			return L.t("cmp_g_keep", [int(st["keep"])])
		"time":
			return L.t("cmp_g_time", [int(st["secs"])])
	return L.t("cmp_g_win")

## 正式打完（_finish_battle）：評星、存檔，結果頁第一條事實寫目標達成沒有
func _camp_settle() -> void:
	if camp_id == "" or mode != Mode.VS_AI or play_kind != "official" or sim == null:
		return
	var st := Campaign.stage(camp_id)
	var alive0 := 0
	for u in sim.units:
		if u.team == 0 and u.alive and not u.summon:
			alive0 += 1
	var gu = Campaign.guard_of(sim.units, func(t): return D.cost(t))
	var stars := Campaign.grade(st, sim.winner == 0, alive0, sim.tick, PZ.rem_pct(sim.power(0), sim.budget_of(0)), gu != null and gu.alive)
	camp_last = stars
	if Campaign.record(Save.data, camp_id, stars):
		Save.save_data()

var camp_last := 0

func _camp_fact() -> String:
	var st := Campaign.stage(camp_id)
	return (L.t("cmp_done", [camp_last]) if camp_last > 0 else L.t("cmp_fail")) + "　" + _camp_goal(st)

func _draw_campaign() -> void:
	_boss_note("campaign", "campaign")   # 1.2.0 §12.2：這個系統第一次出現時一張便條
	_dim(0.6)
	var chs: Array = Campaign.chapters()
	var cur: Array = []
	for ch0 in chs:
		if int(ch0["n"]) == camp_ch:
			cur = ch0["stages"]
	# 關卡卡片兩欄；卡片高度照那一列最長的目標說明算（150% 說明會換行，版面檢查 cat10）
	var pw := 1100.0
	var cw := (pw - 80.0 - 16.0) / 2.0
	var rows := ceili(cur.size() / 2.0)
	var row_h: Array = []
	for ri in rows:
		var h := 0.0
		for k in [ri * 2, ri * 2 + 1]:
			if k < cur.size():
				h = maxf(h, 10.0 + tz("B") * 1.3 + text_h(_camp_goal_of(cur[k]), tz("S"), cw - 28.0) + 12.0)
		row_h.append(h)
	var grid_h := 0.0
	for h2 in row_h:
		grid_h += h2 + 8.0
	var P := modal_rect(pw, 12.0 + h1_help_h(L.t("cmp_note_%d" % camp_ch), tz("S"), pw - 80.0) + GAP_L + 48.0 + GAP_M + grid_h + GAP_L + 44.0 + GAP_L)
	_panel(P)
	var y := _h1_help(Vector2(640, P.position.y + 12), L.t("cmp_title"), L.t("cmp_note_%d" % camp_ch), tz("S"), pw - 80.0) + GAP_L
	var tw := 150.0
	var tx := 640.0 - (chs.size() * (tw + 8.0) - 8.0) / 2.0
	for ch in chs:
		var n := int(ch["n"])
		var first: Dictionary = ch["stages"][0]
		var open := Campaign.unlocked(Save.data, str(first["id"]))
		var lab := L.t("cmp_ch", [n]) + ("　✓" if Campaign.chapter_cleared(Save.data, ch) else "")
		_btn(Rect2(tx, y, tw, 44), lab, func(): camp_ch = n, open, n == camp_ch)
		tx += tw + 8.0
	y += 48.0 + GAP_M
	var cards: Array = [[], []]
	for k2 in cur.size():
		var st: Dictionary = cur[k2]
		var sid := str(st["id"])
		var open2 := Campaign.unlocked(Save.data, sid)
		var ri2: int = k2 / 2
		var ry := y
		for q in ri2:
			ry += float(row_h[q]) + 8.0
		var r := Rect2(P.position.x + 40.0 + (k2 % 2) * (cw + 16.0), ry, cw, row_h[ri2])
		btn_paper = true
		_btn(r, "", func(): _camp_play(sid), open2)   # 整張卡片就是按鈕（和主畫面卡片同一套紙卡）
		btn_paper = false
		var on_paper: bool = open2 and last_btn_paper and last_btn_enabled and not bool(Save.s("plain_ui"))   # 照按鈕實際畫出來的面（停用狀態是褪色木牌，不是紙）
		_ink_mode = on_paper
		var tc: Color = INK if on_paper else (Color.WHITE if open2 else TXT_DIM)
		var nm := L.t("cmp_stage", [camp_ch, k2 + 1]) if str(st["goal"]) != "puzzle" else L.t("cmp_puzzle", [camp_ch])
		_text(r.position + Vector2(14, 10), nm, tz("B"), tc, false, true, cw - 140.0)
		var sn := Campaign.stars_of(Save.data, st)
		var stx := "★".repeat(sn) + "☆".repeat(3 - sn)
		_text(Vector2(r.end.x - 14.0 - _width(stx, tz("B"), true), r.position.y + 10), stx, tz("B"), Color("#6a3a06") if on_paper else ACCENT, false, true, 120)   # 紙上星改深琥珀（#9a5a10 對比只有 3.6）
		_text(r.position + Vector2(14, 10 + tz("B") * 1.3), _camp_goal_of(st), tz("S"), tc, false, false, cw - 28.0)
		_ink_mode = false
		cards[mini(ri2, 1)].append(r)
	_btn(Rect2(560, P.end.y - GAP_L - 44.0, 160, 44), L.t("back"), func(): overlay = "")

func _camp_goal_of(st: Dictionary) -> String:
	return _camp_goal(st) if str(st["goal"]) != "puzzle" else L.t("cmp_g_puzzle")

## ── 1.2.0 §11.5 換邊雙局 ──
const SwapDuel = preload("res://scripts/game/swap_duel.gd")
var swap_on := false
var sw_pts := [0, 0]    # 玩家 A、B 的分數（剩餘戰力百分比合計）
var sw_dead := [0, 0]   # 玩家 A、B 兩局合計倒下數

func _swap_start() -> void:
	var r = RuleSet.standard()
	var dm: int = RS.mask(_demo())
	r.pool = [int(r.pool_of(0)) & dm, int(r.pool_of(1)) & dm]   # 標準卡池再扣掉試玩版沒有的兵（Codex cat10 #5）
	r.rounds = 3   # 用三戰兩勝的局數上限，實際由換邊雙局在第 2 局結束
	rules = r
	challenge_army = null
	overlay = ""
	_start_mode(Mode.DUEL)
	swap_on = true
	sw_pts = [0, 0]
	sw_dead = [0, 0]
	_toast(L.t("sw_intro"))

## 每局正式打完（_finish_battle）：記分；第 2 局後系列結束
func _swap_settle() -> void:
	if not swap_on or mode != Mode.DUEL or play_kind != "official" or sim == null:
		return
	var r: Array = SwapDuel.settle(sw_pts, sw_dead, round_no, sim)
	sw_pts = r[0]
	sw_dead = r[1]
	series_over = round_no >= SwapDuel.ROUNDS

## 擺陣頂部：誰是哪一色（第 2 局換過來）
func _swap_who() -> String:
	return L.t("sw_who", [L.t("blue") if SwapDuel.owner(round_no, 0) == 0 else L.t("red"), L.t("red") if SwapDuel.owner(round_no, 0) == 0 else L.t("blue")])

## 結果頁第一條事實
func _swap_fact() -> String:
	if not series_over:
		return L.t("sw_round", [int(sw_pts[0]), int(sw_pts[1])])
	var v := SwapDuel.verdict(sw_pts, sw_dead)
	return L.t("sw_final", [int(sw_pts[0]), int(sw_pts[1]), L.t("sw_a") if v == 0 else (L.t("sw_b") if v == 1 else L.t("sw_tie"))])

## 揭封：第 k 封放回兩邊（鎖定，不能改），之後照一般「開戰」。
func _sealed_reveal(k: int) -> void:
	armies[0].units = sealed[0][k].duplicate(true)
	armies[1].units = sealed[1][k].duplicate(true)
	blind_phase = 2


## ── V1.4 #15 塗裝室：替兩軍的棋子上底漆、漬洗、乾掃，換木座木料與棋盤框。只改外觀，存檔記住。 ──
## 解鎖：每一列的第 2～4 個選項要成就數 PAINT_UNLOCK[k]（漬洗、乾掃不鎖）。
const PAINT_UNLOCK := [0, 2, 5, 9]
const PAINT_ROWS := [["paint_blue", 4, true], ["paint_red", 4, true], ["paint_wash", 3, false], ["paint_dry", 3, false], ["paint_wood", 4, true], ["paint_frame", 4, true]]
var pt_before := ""

const PAINT_HI := [3, 3, 2, 2, 3, 3]

func _paint_apply() -> void:
	var p = Save.data.get("paint", [0, 0, 1, 1, 0, 0])
	var ach_n: int = Save.data.get("achievements", []).size() + Campaign.cleared(Save.data)   # 1.2.0 §11.7：每通一章戰役＋1
	if p is Array and p.size() == 6:
		for i in 6:
			var v := clampi(int(p[i]), 0, int(PAINT_HI[i]))
			if paint_locked(bool(PAINT_ROWS[i][2]), v, ach_n):
				v = 0   # 存檔被改過、或成就被重置：鎖住的選項退回原色（Antigravity v140-i4）
			Art.paint[i] = v

static func paint_locked(row_locks: bool, k: int, ach_n: int) -> bool:
	return row_locks and ach_n < int(PAINT_UNLOCK[clampi(k, 0, 3)])

var pt_back := "profile"   # V1.5：從哪裡打開塗裝室就回哪裡（戰績頁或主畫面「收藏」）

func _paint_open() -> void:
	pt_before = str(Art.paint)
	pt_back = overlay if overlay != "" and overlay != "paint" else "profile"
	overlay = "paint"

func _paint_close() -> void:
	overlay = pt_back
	if str(Art.paint) != pt_before:
		Save.data["paint"] = Art.paint.duplicate()
		Save.save_data()
		call("_ach", "PAINTER")

## 每點一次就在背景重烘圖集（舊的那次會作廢），左邊預覽用圖集畫，漬洗、乾掃當下就看得到（Codex v140-i4）。
func _paint_pick(row: int, k: int) -> void:
	if int(Art.paint[row]) == k:
		return
	Art.paint[row] = k
	sfx.play("place")
	_rebuild_sprites()

func _draw_paint() -> void:
	_dim(0.6)
	var P := Rect2(150, 60, 980, 680)
	_panel(P)
	_h1(Vector2(640, 72), L.t("paint_head"))
	var ach_n: int = Save.data.get("achievements", []).size() + Campaign.cleared(Save.data)   # 1.2.0 §11.7：每通一章戰役＋1
	# 左：試塗棋盤（棋盤框＋氈布＋兩軍各三隻）。向量直接畫，改了馬上看得到
	var B := Rect2(184, 150, 320, 430)
	var fr_i := clampi(int(Art.paint[5]), 0, 3)
	draw_rect(B.grow(10), Color("#5b4632") if fr_i == 0 else Color(Art.FRAMES[fr_i]))
	draw_rect(B, Color("#6f9a4a"))
	for i in 4:
		draw_line(B.position + Vector2(0, 86 * (i + 1)), B.position + Vector2(B.size.x, 86 * (i + 1)), Color(0, 0, 0, 0.06), 1.0)
	var types := [0, 1, 2]
	for t in 2:
		for j in 3:
			var p := B.position + Vector2(80 + t * 160, 110 + j * 118)
			_ring(p, t, types[j], 1.4)
			_unit(p, types[j], t, 1.0 if t == 0 else -1.0, 0.0, 0.0, 0.0, 1.0, time, 1.4)   # 用烘好的圖集畫：漬洗、乾掃看得到
	_text(Vector2(B.get_center().x, B.end.y + 20), L.t("paint_note") if not cbm() else L.t("paint_cb"), tz("C"), TXT_DIM, true, false, 340)
	# 右：六列，每列「名稱｜四個色票」排一橫（V1.4 版面檢查：150% 時上下排會壓到完成鈕）
	var x0 := 540.0
	var lw := 186.0
	var rh := maxf(tz("B") * 1.5, 44.0) + 14.0
	var y := 150.0
	for row in PAINT_ROWS.size():
		var spec: Array = PAINT_ROWS[row]
		var by := y + (rh - 14.0 - 40.0) / 2.0
		_text(Vector2(x0, y + (rh - 14.0) / 2.0 - tz("B") * 0.68), L.t(spec[0]), tz("B"), Color.WHITE, false, true, lw)
		for k in int(spec[1]):
			var r := Rect2(x0 + lw + 10 + k * 98, by, 90, 40)
			var lock := paint_locked(bool(spec[2]), k, ach_n) or (row <= 1 and k > 0 and cbm())   # 色盲配色時底漆不能換（Antigravity v140-i4）
			var on := int(Art.paint[row]) == k
			var rr := row
			var kk := k
			_btn(r, "", func(): _paint_pick(rr, kk), not lock, on)
			_paint_swatch(row, k, r, lock, on)
		y += rh
	if ach_n < int(PAINT_UNLOCK[3]):
		_text(Vector2(x0, y + 4), L.t("paint_unlock", [ach_n]), tz("C"), TXT_DIM, false, false, 570)
	_btn(Rect2(560, 672, 160, 44), L.t("paint_done"), func(): _paint_close(), true, true)

## 色票：底漆＝色塊；漬洗／乾掃＝三格深淺；木座＝木料橢圓；棋盤框＝框色條。鎖住的畫鎖頭。
func _paint_swatch(row: int, k: int, r: Rect2, lock: bool, on: bool) -> void:
	var c := r.get_center()
	if lock:
		_icon("lock", c, 18.0, Color(1, 1, 1, 0.5))
		return
	match row:
		0, 1:
			draw_circle(c, 13.0, Art.OUT, true, -1.0, true)
			draw_circle(c, 11.0, Art.PAINTS[row][k], true, -1.0, true)
		2, 3:
			for i in 3:
				var a := 0.25 + 0.5 * float(i <= k)
				var col := Color(0.12, 0.08, 0.05, a) if row == 2 else Color(1.0, 0.95, 0.8, a)
				draw_rect(Rect2(c + Vector2(-27 + i * 19, -8), Vector2(16, 16)), col)
		4:
			var wd: Array = Art.WOODS[k]
			draw_colored_polygon(_ellipse_pts(c + Vector2(0, 3), 26.0, 9.0), wd[0])
			draw_colored_polygon(_ellipse_pts(c, 26.0, 9.0), wd[1])
		5:
			draw_rect(Rect2(c - Vector2(30, 10), Vector2(60, 20)), Color("#5b4632") if k == 0 else Color(Art.FRAMES[k]))
			draw_rect(Rect2(c - Vector2(22, 5), Vector2(44, 10)), Color("#6f9a4a"))
	if on:
		_hand_ring(c + Vector2(35, -10), 5.0, Color("#e8c46a"), 2.0)

func _ellipse_pts(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 20:
		var an := i * TAU / 20.0
		pts.append(c + Vector2(cos(an) * rx, sin(an) * ry))
	return pts


## ── V1.4 #7 幽靈軍團＋每週棋盒 ──
## 幽靈：30 個凍結的「名人陣」（data/ghosts.json，tools/balance/ghost_forge.gd 鍛造：每個 AI 模板對 40 支隨機軍的勝率挑最強）。
## 打贏記在 Save.data.ghost_beat。接上 Steam 後可以從排行榜抓玩家上傳的陣（SteamApi.ghost_*，未實測）。
## 每週棋盒：依週數固定 6 種兵的卡池、預算、對手（其中一個幽靈）；本地記最少花費破關，Steam 上同一題比排行榜。
var ghost_id := ""
var wk_active := false
var gh_page := 0
static func ghosts() -> Array:
	return load("res://scripts/game/ghost_data.gd").all()

static func ghost_army(g: Dictionary):
	var a = Army.new(1, 100)
	for u in g.get("units", []):
		a.units.append({"type": int(u["type"]), "col": int(u["col"]), "row": int(u["row"])})
	return a

## 週數：從 1970-01-05（週一）起算，每週一換題。
static func week_no(unix: int) -> int:
	return PlayroomRules.week_no(unix)   # 1.1.0 A22：純邏輯搬到 scripts/game/playroom_rules.gd

## 這週的題目：卡池（舊 10 種裡抽 6 種，一定有戰鬥兵）、預算、對手幽靈。同一週大家一樣。
static func weekly_spec(wk: int) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = 1400000 + wk
	var mask := 0
	for _try in 50:
		var types := range(D.COUNT)
		mask = 0
		for k in 6:
			var j := r.randi_range(0, types.size() - 1)
			mask |= 1 << int(types[j])
			types.remove_at(j)
		if RuleSet.has_combat(mask):
			break
	var gs := ghosts()
	return {"wk": wk, "pool": mask, "budget": [80, 90, 100, 110, 120][posmod(wk, 5)], "ghost": posmod(wk * 7, maxi(1, gs.size()))}

func _ghost_start(i: int) -> void:
	var gs := ghosts()
	if i < 0 or i >= gs.size():
		return
	var r = RuleSet.standard()
	r.rounds = 1
	rules = r
	challenge_army = ghost_army(gs[i])
	overlay = ""
	set("daily_spec", {})   # Codex v140-i5：不能沿用每日挑戰的狀態
	_start_mode(Mode.VS_AI)
	set("daily_spec", {})
	challenge_army = ghost_army(gs[i])
	ghost_id = str(gs[i]["id"])
	_toast(L.t("gh_toast", [L.field(gs[i], "")]))

var wk_spec := {}   # 開題當下的題目（跨週一才打完也算開題那一週，Codex、Antigravity v140-i5）

func _weekly_start() -> void:
	var sp := weekly_spec(week_no(int(Time.get_unix_time_from_system())))
	wk_spec = sp
	var gs := ghosts()
	if gs.is_empty():
		return
	var r = RuleSet.standard()
	r.rounds = 1
	r.pool = [int(sp["pool"]), RuleSet.all_pool()]
	r.ai_pool_same = false
	r.handicap = true
	r.budget = [int(sp["budget"]), 100]
	rules = r
	challenge_army = ghost_army(gs[int(sp["ghost"])])
	overlay = ""
	set("daily_spec", {})
	_start_mode(Mode.VS_AI)
	set("daily_spec", {})
	challenge_army = ghost_army(gs[int(sp["ghost"])])
	wk_active = true
	_toast(L.t("wk_toast", [int(sp["budget"])]))

## 戰鬥結束（正式局）呼叫一次：記幽靈戰果、每週最少花費。
func _ghost_settle(w: int) -> void:
	if mode != Mode.VS_AI or play_kind != "official":
		return
	if ghost_id != "" and w == 0:
		var beat: Array = Save.data.get("ghost_beat", [])
		if not ghost_id in beat:
			beat.append(ghost_id)
			Save.data["ghost_beat"] = beat
			Save.save_data()
			report["gh_line"] = L.t("gh_beat_new", [beat.size(), ghosts().size()])
		if beat.size() >= ghosts().size():
			call("_ach", "GHOST_ALL")   # 放在「第一次打敗」外面：更新前就全破的老玩家再贏一場也拿得到（Codex v150-i2 #4）
	if wk_active:
		var wk: int = int(wk_spec.get("wk", week_no(int(Time.get_unix_time_from_system()))))
		var rec: Dictionary = Save.data.get("weekly", {})
		if int(rec.get("wk", -1)) != wk:
			rec = {"wk": wk, "best": 0, "tries": 0}
		rec["tries"] = int(rec.get("tries", 0)) + 1
		if w == 0:
			call("_ach", "WEEKLY_WIN")
			var spent: int = last_armies[0].spent()
			if int(rec["best"]) <= 0 or spent < int(rec["best"]):
				rec["best"] = spent
				report["gh_line"] = L.t("wk_best_new", [spent])
				rec["det"] = Array(SteamApi.pack_army(last_armies[0].mirrored().units))   # 1.2.0：幽靈陣一律存紅方視角（解包只收欄 10～15；原本存藍方，下載下來全被當壞資料丟掉）
				rec["pend"] = 1   # 還沒送上排行榜（沒 Steam、或送失敗）：之後有 Steam 時補送（Codex v140-i5）
		Save.data["weekly"] = rec
		Save.save_data()
		_weekly_sync()

## 每週最佳還沒送上排行榜就送（有 Steam 才會真的送；成功的回呼會把 pend 清掉）。
func _weekly_sync() -> void:
	var rec: Dictionary = Save.data.get("weekly", {})
	if int(rec.get("pend", 0)) == 1 and SteamApi.available() and int(rec.get("best", 0)) > 0:
		SteamApi.weekly_upload(int(rec["wk"]), int(rec["best"]), PackedInt32Array(rec.get("det", [])))

func _draw_ghosts() -> void:
	_dim(0.6)
	var gs := ghosts()
	var beat: Array = Save.data.get("ghost_beat", [])
	var help := L.t("gh_help", [beat.size(), gs.size()])
	# V1.5.2 L3：說明從緞帶下緣＋16、卡片從說明下緣＋16 起；面板照內容算高（說明換行時整頁一起長高，不壓翻頁鈕）
	var per := 9   # 一頁 3×3（英文大字級名牌會折兩行，卡片要高一點；收尾第 2 輪截圖）
	var P := modal_rect(1020, 12.0 + h1_help_h(help, tz("S"), 900) + 3 * 152.0 - 12.0 + GAP_M + 44.0 + GAP_S + 44.0 + GAP_L)
	_panel(P)
	var gy := _h1_help(Vector2(640, P.position.y + 12), L.t("gh_head"), help, tz("S"), 900)
	# 一頁 12 張羊皮紙名牌（3 欄 × 4 列）；打贏的蓋朱紅「破」印
	var pages := maxi(1, int(ceil(gs.size() / float(per))))
	gh_page = clampi(gh_page, 0, pages - 1)
	for k in per:
		var i := gh_page * per + k
		if i >= gs.size():
			break
		var g: Dictionary = gs[i]
		var r := Rect2(160 + (k % 3) * 324, gy + (k / 3) * 152, 312, 140)
		var gi := i
		btn_paper = true
		_btn(r, "", func(): _ghost_start(gi))
		btn_paper = false
		var on_paper: bool = bool(_btns[_btns.size() - 1]["en"]) and not bool(Save.s("plain_ui"))
		_ink_mode = on_paper   # 停用／簡化時卡片是深色：字用淺色
		var gname := L.field(g, "")
		_text(r.position + Vector2(16, 12), gname, tz("B"), INK if _ink_mode else Color.WHITE, false, true, 200)
		_text(r.position + Vector2(16, 18 + text_h(gname, tz("B"), 200, true)), ai_tpl_name(str(g.get("tpl", ""))), tz("C"), Color("#4a3622") if _ink_mode else TXT_DIM, false, false, 200)
		# 難度星放右欄、陣型下面（只畫星，不佔左邊文字欄；收尾驗證：英文兩行名稱會擠到）
		var stars := "★".repeat(clampi(1 + int(g.get("wr", 0)) / 25, 1, 4))
		var sw := minf(_width(stars, tz("C"), true), 96.0)
		_text(Vector2(r.end.x - 20 - sw / 2.0, r.position.y + 96), stars, tz("C"), Color("#6b3e08") if on_paper else ACCENT, true, true, 96)   # 右緣留 20px 內距
		_ink_mode = false
		# 右側：迷你陣型（紅點）
		var mx := r.end.x - 64
		for u in g.get("units", []):
			draw_circle(Vector2(mx + (int(u["col"]) - 10) * 8.0, r.position.y + 16 + int(u["row"]) * 8.0), 3.0, Color("#9c4a3c", 0.85), true, -1.0, true)
		if str(g["id"]) in beat:
			var sp := Vector2(r.end.x - 44, r.position.y + 48)   # 「破」蓋在陣型上
			_hand_ring(sp, 18.0, Color("#8e1b14", 0.9), 2.6)
			_text(sp - Vector2(0, tz("C") * 0.68), L.t("gh_stamp"), tz("C"), Color("#8e1b14") if on_paper else Color("#ff8a7a"), true, true, 40)
	var py := P.end.y - GAP_L - 44.0 - GAP_S - 44.0
	if pages > 1:
		_btn(Rect2(470, py, 56, 44), "◀", func(): gh_page = posmod(gh_page - 1, pages))
		_text(Vector2(640, py + 10), "%d／%d" % [gh_page + 1, pages], tz("S"), Color.WHITE, true, true, 100)
		_btn(Rect2(754, py, 56, 44), "▶", func(): gh_page = posmod(gh_page + 1, pages))
	_btn(Rect2(560, P.end.y - GAP_L - 44.0, 160, 44), L.t("back"), func(): overlay = "playroom")

func _draw_weekly() -> void:
	_dim(0.6)
	# 1.2.0 字級表放大：底下說明在 150% 會換好幾行 → 按鈕列跟著說明實高往下、面板高度一起算（原本固定 540 會壓到按鈕）
	var note_h := text_h(L.t("wk_note"), tz("C"), 680)
	var by := maxf(604.0, 530.0 + 10.0 + note_h + GAP_M)
	var P := Rect2(260, 120, 760, by + 44.0 + GAP_L - 120.0)
	_panel(P)
	_h1(Vector2(640, 132), L.t("wk_head"))
	var wk := week_no(int(Time.get_unix_time_from_system()))
	var sp := weekly_spec(wk)
	var gs := ghosts()
	var rec: Dictionary = Save.data.get("weekly", {})
	if int(rec.get("wk", -1)) != wk:
		rec = {}
	var paper := Rect2(300, 200, 680, 330)
	_tex_box(paper, "paper")
	_ink_mode = true
	var y := paper.position.y + 18
	var d0 := Time.get_date_dict_from_unix_time((wk * 7 + 4) * 86400)
	var d1 := Time.get_date_dict_from_unix_time((wk * 7 + 10) * 86400)
	_text(Vector2(640, y), L.t("wk_sub", ["%d/%d" % [d0["month"], d0["day"]], "%d/%d" % [d1["month"], d1["day"]]]), tz("B"), INK, true, true, 640)   # 日期範圍，不寫內部週數（Codex 收尾第 1 輪）
	y += tz("B") * 1.8
	_text(Vector2(330, y), L.t("wk_pool"), tz("S"), INK, false, true, 200)
	var n := 0
	for t in D.COUNT:
		if int(sp["pool"]) & (1 << t):
			Art.unit(self, Vector2(520 + n * 74, y + 44), t, 0, 1.0, 0.0, 0.0, 0.0, 1.0, time, 0.9, cbm())
			n += 1
	y += 74
	_text(Vector2(330, y), L.t("wk_budget", [int(sp["budget"])]), tz("S"), INK, false, true, 600)
	y += tz("S") * 1.7
	if not gs.is_empty():
		_text(Vector2(330, y), L.t("wk_foe", [L.field(gs[int(sp["ghost"])], "")]), tz("S"), INK, false, true, 620)
	y += tz("S") * 1.7
	var best := int(rec.get("best", 0))
	_text(Vector2(330, y), L.t("wk_best", [best]) if best > 0 else L.t("wk_none"), tz("S"), Color("#8e1b14") if best > 0 else Color("#5a4630"), false, true, 620)
	_ink_mode = false
	_text(Vector2(640, paper.end.y + 10), L.t("wk_note"), tz("C"), TXT_DIM, true, false, 680)
	_btn(Rect2(360, by, 160, 44), L.t("back"), func(): overlay = "playroom")
	_btn(Rect2(560, by, 160, 44), L.t("wk_dl"), func(): _wk_dl_open())   # 1.2.0 §15.4：玩家幽靈入口
	_btn(Rect2(760, by, 160, 44), L.t("pr_go"), func(): _weekly_start(), true, true)

## 1.2.0 §15.4：下載本週玩家幽靈（排行榜前 20 名的陣型，SteamApi.ghost_fetch）。原本只有程式、沒有畫面入口。
## 狀態：offline（沒有 Steam）／busy（下載中）／empty（本週沒人上傳）／ok（列前幾名，可挑一個對戰）。回呼可能在離開後才到：只在頁面還開著時更新。
var wk_dl_state := ""
var wk_dl_list: Array = []
var wk_dl_gen := 0
func _wk_dl_open() -> void:
	overlay = "wk_ghosts"
	_focus = 0
	wk_dl_list = []
	if not SteamApi.available():
		wk_dl_state = "offline"
		return
	wk_dl_state = "busy"
	wk_dl_gen += 1
	var g0 := wk_dl_gen
	SteamApi.ghost_fetch(week_no(int(Time.get_unix_time_from_system())), func(list: Array): _wk_dl_done(g0, list))

func _wk_dl_done(g0: int, list: Array) -> void:
	if g0 != wk_dl_gen or overlay != "wk_ghosts":
		return   # 過期的回呼（已離開或重開過）
	wk_dl_list = list.slice(0, 5)
	wk_dl_state = "ok" if not wk_dl_list.is_empty() else "empty"

func _wk_dl_play(i: int) -> void:
	if i < 0 or i >= wk_dl_list.size():
		return
	var g := {"units": wk_dl_list[i]["units"]}   # 下載的已經是紅方視角（上傳前鏡像好）
	var r = RuleSet.standard()
	r.rounds = 1
	rules = r
	challenge_army = ghost_army(g)
	overlay = ""
	set("daily_spec", {})
	_start_mode(Mode.VS_AI)
	set("daily_spec", {})
	challenge_army = ghost_army(g)
	_toast(L.t("wk_dl_go", [int(wk_dl_list[i]["rank"])]))

func _draw_wk_ghosts() -> void:
	_dim(0.6)
	var rowh := 52.0
	var n := maxi(1, wk_dl_list.size())
	var P := modal_rect(640, 12.0 + h1_bottom(0.0) + GAP_L + n * (rowh + GAP_S) + GAP_L + 44.0 + GAP_L)
	_panel(P)
	var y := _h1(Vector2(640, P.position.y + 12), L.t("wk_dl")) + GAP_L
	if wk_dl_state != "ok":
		_text(Vector2(640, y + 12), L.t("wk_dl_" + wk_dl_state), tz("B"), TXT_DIM, true, false, 560)
	for i in wk_dl_list.size():
		var e: Dictionary = wk_dl_list[i]
		_text(Vector2(P.position.x + 40, y + 12), L.t("wk_dl_row", [int(e["rank"]), int(e["score"]), (e["units"] as Array).size()]), tz("S"), Color.WHITE, false, false, 300)
		# Antigravity cat01 #3：只看金幣與隻數像抽盲盒 → 畫這個陣型最多的 3 種兵（頭像）
		var cnt := {}
		for u in e["units"]:
			cnt[int(u["type"])] = int(cnt.get(int(u["type"]), 0)) + 1
		var top: Array = cnt.keys()
		top.sort_custom(func(p1, p2): return cnt[p1] > cnt[p2] or (cnt[p1] == cnt[p2] and p1 < p2))
		for k in mini(3, top.size()):
			_unit(Vector2(P.position.x + 360 + k * 40, y + 44), int(top[k]), 1, -1.0, 0.0, 0.0, 0.0, 1.0, time, 0.55)
		var ii := i
		_btn(Rect2(P.end.x - 200, y + 4, 160, 44), L.t("wk_dl_fight"), func(): _wk_dl_play(ii), true, i == 0)
		y += rowh + GAP_S
	_btn(Rect2(560, P.end.y - GAP_L - 44.0, 160, 44), L.t("back"), func(): wk_dl_gen += 1; overlay = "weekly")


## ── V1.4 #12 巨獸：遠征終點的敵陣中央放一隻（不佔預算、隻數）。格子被佔了就把那隻換掉。──
const BOSS_CELLS := [[12, 4], [11, 4], [12, 3], [12, 5], [13, 4], [11, 3], [11, 5]]

static func add_boss(a) -> void:
	for u in a.units:
		if int(u.get("boss", 0)) == 1:
			return
	var cell: Array = BOSS_CELLS[0]
	for c in BOSS_CELLS:
		if a.index_at(int(c[0]), int(c[1])) == -1:
			cell = c
			break
	var i: int = a.index_at(int(cell[0]), int(cell[1]))
	if i != -1:
		a.units.remove_at(i)
	a.units.append({"type": 19, "col": int(cell[0]), "row": int(cell[1]), "boss": 1})


## ── V1.4 收尾第 1 輪（Codex、Antigravity）：遠征擺陣頁的「本戰條件」。離開獎勵頁或讀檔後也查得到：
## 這一站是什麼、簽了什麼契約、累積加成、敵方特別之處（宿敵、巨獸、斥候／截斷），以及我方每張貼紙的效果。
func _ga_info_lines() -> Array:
	var out: Array = []
	out.append([L.t("gi_stage"), L.t("gauntlet_title", [gauntlet_stage]) + "・" + L.t("ga_node_" + ga_node(gauntlet_stage))])
	if gauntlet_contract >= 0 and gauntlet_contract < CONTRACTS.size():
		var c: Array = CONTRACTS[gauntlet_contract]
		out.append([L.t("gi_contract"), L.t(str(c[0])) + "：" + L.t(str(c[0]) + "_d") + "（" + _ct_reward(gauntlet_contract) + "）"])
	out.append([L.t("gi_bonus"), L.t("rw_now", [gauntlet_gold, gauntlet_cap])])
	var foe: Array = []
	if gauntlet_nemesis >= 0 and gauntlet_nemesis < Save.data.get("nemeses", []).size():
		foe.append(L.t("gi_nemesis", [nemesis_title(Save.data["nemeses"][gauntlet_nemesis])]))
	for u in armies[1].units:
		if int(u.get("boss", 0)) == 1:
			foe.append(L.t("boss_here"))
			break
	if gauntlet_foe_gold != 0:
		foe.append(L.t("rw_scout_d"))
	if gauntlet_foe_cap != 0:
		foe.append(L.t("rw_ambush_d"))
	if not foe.is_empty():
		out.append([L.t("gi_foe"), L.t("list_sep").join(foe)])
	for u in armies[0].units:
		var st := int(u.get("st", 0))
		if st > 0:
			out.append([L.t("gi_sticker"), "%s・%s：%s" % [L.t("unit_%d" % int(u["type"])), L.t("st_%d" % st), sticker_desc(st)]])
	return out

func _draw_ga_info() -> void:
	_dim(0.6)
	var P := Rect2(220, 110, 840, 560)
	_panel(P)
	_h1(Vector2(640, 122), L.t("ga_info"))
	var paper := Rect2(250, 190, 780, 400)
	_tex_box(paper, "paper")
	_ink_mode = not bool(Save.s("plain_ui"))
	var tc: Color = INK if _ink_mode else Color.WHITE
	var y := paper.position.y + 18
	var lw := 150.0
	for ln in _ga_info_lines():
		if y > paper.end.y - tz("S") * 1.5:
			break
		_text(Vector2(paper.position.x + 20, y), str(ln[0]), tz("S"), Color("#5a3008") if _ink_mode else ACCENT, false, true, lw)
		var body := str(ln[1])
		_text(Vector2(paper.position.x + 30 + lw, y), body, tz("S"), tc, false, false, paper.size.x - lw - 50)
		y += text_h(body, tz("S"), paper.size.x - lw - 50) + 10
	_ink_mode = false
	_btn(Rect2(560, 610, 160, 44), L.t("back"), func(): overlay = "")

