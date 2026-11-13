extends "res://scripts/ui/screens/game_result.gd"
## V9 P6 模式：主題試煉、挑戰碼、遠征獎勵、雙人禁選、戰績頁、牌組。

## 主題試煉：10 關固定地圖＋AI 性格，玩家自己組牌。[地圖, 大小, 性格, 難度]
## 第十三輪：再加 20 關（索引 10～29，只往後加、不重排，存檔用索引）：敵陣固定在 data/trials.json，
## 主題是限定卡池、單主題與混搭頭目、規則變形；性格欄填 0，卡片顯示主題名稱。
const TRIALS := [[1, 1, 2, 1], [2, 1, 3, 1], [3, 1, 3, 1], [4, 1, 1, 1], [5, 1, 4, 1],
	[1, 0, 1, 2], [2, 2, 4, 2], [3, 2, 2, 2], [4, 0, 3, 2], [5, 2, 5, 2],
	[1, 1, 0, 1], [2, 1, 0, 1], [3, 1, 0, 1], [4, 1, 0, 1], [1, 1, 0, 1],
	[2, 1, 0, 1], [3, 1, 0, 1], [4, 0, 0, 1], [5, 1, 0, 1], [1, 2, 0, 2],
	[2, 1, 0, 2], [3, 1, 0, 2], [4, 2, 0, 2], [5, 1, 0, 2], [1, 0, 0, 2],
	[2, 2, 0, 2], [3, 0, 0, 2], [4, 1, 0, 2], [5, 1, 0, 2], [1, 2, 0, 2]]
const TRIAL_PAGE := 10
const TD = preload("res://scripts/game/trial_data.gd")
const Daily = preload("res://scripts/game/daily.gd")
var daily_spec := {}      # V1.1 D2：這場是每日挑戰時的規格；其他模式是空的

## 第十三輪新增試煉的資料（索引 ≥10）：主題名稱、固定敵陣、規則變形、星數門檻。快取在 trial_data.gd。
static func trial_x(i: int) -> Dictionary:
	return TD.get_x(i)

var trial_id := -1
var challenge_army = null       # 挑戰碼的對手陣型
var gauntlet_gold := 0
var gauntlet_cap := 0
## V1.1 D1：遠征路線。7 戰的節點類型與戰間事件（只改戰前配置：預算、隻數、可換隻數、卡池、下一戰敵方預算／隻數）。
const GA_NODES := ["outpost", "fight", "fight", "elite", "fight", "elite", "boss"]
const GA_NODE_GOLD := {"outpost": 0, "fight": 0, "elite": 10, "boss": 20}
const GA_EVENTS := ["rw_gold", "rw_cap", "rw_change", "rw_recruit", "rw_scout", "rw_ambush", "rw_sticker"]
const STK = preload("res://scripts/core/sticker_defs.gd")
const GA_EVENT_ICONS := ["coin", "people", "swap", "flag", "map", "ban", "star"]
## V1.4 #3 戰利品契約：每一站抽 2 份可簽（或不簽）。判定只看戰前陣型與戰後狀態，模擬不動。
## [字串鍵, 獎勵金, 獎勵隻數, 本戰預算變動, 本戰隻數變動]
const CONTRACTS := [["ct_noranged", 10, 0, 0, 0], ["ct_three", 0, 2, 0, 0], ["ct_fast", 10, 0, 0, 0],
	["ct_clean", 15, 0, 0, 0], ["ct_few", 0, 3, 0, -4], ["ct_poor", 20, 0, -10, 0]]
const RANGED := [2, 6, 10, 17]   # 弓箭手、投彈兵、孢子菇、骷髏法師
var gauntlet_contract := -1      # 這一戰簽的契約（-1＝沒簽）
var ct_pick := -1                # 獎勵畫面上正在勾選的契約
var ct_last := ""                # 上一份契約的結果（獎勵畫面顯示）
## V1.4 #2 宿敵戰記：遠征裡打敗你的敵陣會被記住（最多 6 個），之後在菁英站再來攔路；打贏就是復仇。模擬不動，宿敵就是存下來的敵陣。
const NEM_MAX := 6
var gauntlet_nemesis := -1       # 這一戰的對手是哪個宿敵（-1＝一般 AI）
var gauntlet_foe_gold := 0     # 只影響下一戰
var gauntlet_foe_cap := 0
var ban_left := [0, 0]
var ban_turn := 0

## ── 主題試煉 ──
func _start_trial(i: int) -> void:
	if _demo() and not i in Presets.DEMO_TRIALS:
		_toast(L.t("demo_locked"), true)
		return
	rules = _trial_rules(i, trial_x(i))
	challenge_army = null      # 上一場挑戰碼的敵陣不能留到試煉（Codex #5）
	rng.seed = 7000 + i        # 同一關每次是同一支隊伍
	_start_mode(Mode.VS_AI)
	trial_id = i

## 試煉的規則（遊戲與工具共用）。x＝第十三輪的關卡資料（舊 10 關是空的）。
func _trial_rules(i: int, x: Dictionary):
	var t: Array = TRIALS[i]
	var r = Presets.make("standard", "ai", RS.mask(_demo()))
	r.deploy = "free"
	r.spacing = 800
	r.depth = 6000
	r.fullfield = 0
	r.map_id = int(t[0])
	r.map_size = int(t[1])
	var s: Array = MapDefs.SIZE_SUGGEST[r.map_size]
	r.budget = [int(s[0]), int(s[0])]
	r.unit_cap = int(s[1])
	r.ticks = int(s[2])
	r.rounds = 1
	r.ai_level = int(t[3])
	r.ai_style = int(t[2])
	r.ai_pool_same = false
	var p := 0
	if AI.STYLE_TYPES.has(r.ai_style):
		for st0 in AI.STYLE_TYPES[r.ai_style]:
			p |= 1 << int(st0)
	else:
		p = RuleSet.all_pool()
	if _demo():
		p &= RS.mask(true)
	r.pool[1] = p
	r.preset = "custom"
	if x.has("enemy"):
		# 第十三輪：敵方卡池＝固定敵陣實際用到的兵種（一邊最多 10 種），代碼才讀得回（Codex v13-r1 #2、v13-r2 #1）
		var pe := 0
		for u in x["enemy"]:
			pe |= 1 << int(u[0])
		r.pool[1] = pe
	if x.has("pool0"):
		var p0 := 0
		for t0 in x["pool0"]:
			p0 |= 1 << int(t0)
		r.pool[0] = p0 & RS.mask(_demo())
	if x.has("budget"):
		r.budget = [int(x["budget"]), int(x["budget"])]
	if x.has("depth"):
		r.depth = int(x["depth"])
	if x.has("type_cap"):
		r.type_cap = int(x["type_cap"])
	if x.has("cmd"):
		r.cmd_mask = [int(x["cmd"]), int(x["cmd"])]
	return r

## 第十三輪：固定敵陣（世界座標）。舊 10 關回 null，照舊由 AI 用固定種子生成。
func _trial_enemy():
	var x := trial_x(trial_id)
	if not x.has("enemy"):
		return null
	var e := Army.new(1, rules.budget_of(1))
	e.apply_rules(rules, 1)
	for u in x["enemy"]:
		e.units.append({"type": int(u[0]), "x": int(u[1]), "y": int(u[2])})
	return e

func trial_rem(i: int) -> int:
	var x := trial_x(i)
	return int(x["rem"]) if x.has("rem") else int(TRIAL_REM[int(TRIALS[i][3])])

func trial_name(i: int) -> String:
	var x := trial_x(i)
	if x.has("zh"):
		return L.field(x, "")
	return L.t("map_" + str(MapDefs.MAPS[TRIALS[i][0]]["key"]))

## 第十二輪：每達成一項一顆星，和殘局同一套。原本要花 ≤80% 預算還要剩「整個預算」的 50%，電腦都找不到解。
const TRIAL_REM := [0, 30, 20]     # 剩餘戰力門檻（依難度，索引同 AI 等級）
const TRIAL_SPEND_PCT := 80
const TRIAL_SPEND_OVERRIDE := {7: 85}   # 第 8 關：80% 搜尋 13 組種子都到不了，最好是 23% 剩餘花 81%

static func trial_spend_pct(id: int) -> int:
	var x := trial_x(id)
	if x.has("spend"):
		return int(x["spend"])
	return int(TRIAL_SPEND_OVERRIDE.get(id, TRIAL_SPEND_PCT))

static func trial_stars(level: int, rem: int, spent: int, budget: int, spend_pct: int = TRIAL_SPEND_PCT, need_rem: int = -1) -> int:
	var st := 1
	if rem >= (int(TRIAL_REM[level]) if need_rem < 0 else need_rem):
		st += 1
	if spent * 100 <= budget * spend_pct:
		st += 1
	return st

func _trial_finish(w: int) -> void:
	if trial_id >= 0:
		Save.note_try("trial", str(trial_id), w == 0, armies[0].spent())   # V1.1 F2
	if trial_id < 0 or w != 0:
		return
	var lvl: int = int(TRIALS[trial_id][3])
	var rem: int = PZ.rem_pct(sim.power(0), sim.budget_of(0))
	var spent: int = armies[0].spent()
	var pct: int = trial_spend_pct(trial_id)
	var st: int = trial_stars(lvl, rem, spent, armies[0].budget, pct, trial_rem(trial_id))
	report["trial_lines"] = call("_star_lines", true, rem, trial_rem(trial_id), spent, armies[0].budget * pct / 100)
	var all: Dictionary = Save.data.get("trial_stars", {})
	all[str(trial_id)] = maxi(int(all.get(str(trial_id), 0)), st)
	Save.data["trial_stars"] = all
	report["trial_stars"] = st
	var full := 0
	for k in TRIALS.size():
		full += 1 if int(all.get(str(k), 0)) >= 3 else 0
	if full >= TRIALS.size():
		call("_ach", "TRIAL_ALL3")   # 第十三輪
	Save.save_data()

var trial_page := 0

func _draw_trials() -> void:
	# V1.5.2 L3：面板上緣提到 24、緞帶跨在上緣（和圖鑑、大廳同款），說明從緞帶下緣＋16 起；卡片照說明實高往下
	var P := Rect2(90, 24, 1100, 736)
	_panel(P)
	var tdy := maxf(0.0, _h1_help(Vector2(640, 24), L.t("trial_title"), L.t("trial_rule"), tz("S"), 1000) - 164.0)
	var stars: Dictionary = Save.data.get("trial_stars", {})
	var pages: int = ceili(TRIALS.size() / float(TRIAL_PAGE))
	trial_page = clampi(trial_page, 0, pages - 1)
	# 第十三輪：30 關分 3 頁
	var tot := 0
	for k0 in TRIALS.size():
		tot += int(stars.get(str(k0), 0))
	_text(Vector2(184, 710), L.t("trial_page", [trial_page + 1, pages, tot, TRIALS.size() * 3]), tz("S"), TXT_DIM, false, false, 360)
	var cw := 524.0
	var ch := 98.0   # 1.2.0 §3.1 字級表放大後：卡片高度不能再加（5 列塞滿面板），改收行距（1.4→1.25、1.35→1.2）
	for k in TRIAL_PAGE:
		var i: int = trial_page * TRIAL_PAGE + k
		if i >= TRIALS.size():
			break
		var t: Array = TRIALS[i]
		var x := trial_x(i)
		var r := Rect2(116 + (k % 2) * (cw + 8), 164 + tdy + (k / 2) * (ch + 7), cw, ch)
		var got := int(stars.get(str(i), 0))
		btn_paper = got > 0   # V1.2.1 R1：過關的試煉卡是紙面
		_btn(r, "", _start_trial.bind(i), not _demo() or i in Presets.DEMO_TRIALS, false, TH_WOOD)
		btn_paper = false
		_ink_mode = last_btn_paper
		_probe_dis = not last_btn_enabled   # 停用的卡片：裡面的字也算停用（另報）
		call("_map_thumb", Rect2(r.position + Vector2(8, 8), Vector2(136, 84)), int(t[0]), int(t[1]))
		var tcol := Color.WHITE if last_btn_enabled else Color(1, 1, 1, 0.4)
		var acol := ACCENT if last_btn_enabled else Color(ACCENT, 0.4)
		_text(r.position + Vector2(154, 8), "%d. %s" % [i + 1, trial_name(i)], tz("B"), tcol, false, true, cw - 240)
		var sz := "%s %d×%d" % [L.t("map_size_%d" % int(t[1])), MapDefs.SIZES[t[1]][0], MapDefs.SIZES[t[1]][1]]
		var diff: String = L.t(["diff_easy", "diff_normal", "diff_hard"][int(t[3])])
		# 第十三輪新關：第二行放主題規則＋難度（地圖看縮圖就知道），第三行只放星數條件，150% 字級才排得下
		var line2: String = "%s・%s・%s" % [sz, L.t("ai_style_%d" % int(t[2])), diff]
		if x.has("tag_zh"):
			line2 = L.t("name_sep_fmt", [L.field(x, "tag"), diff])
			if _width(line2, tz("C")) > cw - 160:
				line2 = L.field(x, "tag")   # 1.2.0：放不下一行就只留主題（難度看星數條件與顏色），不換成兩行出框
		_text(r.position + Vector2(154, 8 + tz("B") * 1.25), line2, tz("C"), TXT_DIM if last_btn_enabled else Color(TXT_DIM, 0.4), false, false, cw - 160)
		var tb: int = int(x["budget"]) if x.has("budget") else int(MapDefs.SIZE_SUGGEST[int(t[1])][0])
		# V1.1 C3：條件改成「圖示＋數字」（♥ 剩餘戰力、金幣 花費），不寫長句
		var cy0: float = r.position.y + 8 + tz("B") * 1.25 + tz("C") * 1.2
		var cx0: float = r.position.x + 154
		_icon("heart", Vector2(cx0 + 9, cy0 + tz("C") * 0.62), 16.0, acol)
		var c1s := "≥%d%%" % trial_rem(i)
		_text(Vector2(cx0 + 22, cy0), c1s, tz("C"), acol, false, true, 120)
		var cx1: float = cx0 + 34 + font_bold.get_string_size(c1s, HORIZONTAL_ALIGNMENT_LEFT, -1, tz("C")).x
		_icon("coin", Vector2(cx1 + 9, cy0 + tz("C") * 0.62), 16.0, acol)
		_text(Vector2(cx1 + 22, cy0), "≤%d" % (tb * trial_spend_pct(i) / 100), tz("C"), acol, false, true, 120)
		for k2 in 3:
			_icon("star", r.position + Vector2(cw - 66 + k2 * 22, 20), 20.0, Color("#ffd166") if k2 < got else Color(1, 1, 1, 0.16))
		_ink_mode = false
		_probe_dis = false
	# 翻頁鈕放在關卡卡片後面：手把焦點先落在第一關（版面檢查 PADWALK）
	_btn(Rect2(116, 700, 52, 44), "◀", func(): trial_page -= 1, trial_page > 0 and not _demo())
	_btn(Rect2(1112, 700, 52, 44), "▶", func(): trial_page += 1, trial_page < pages - 1 and not _demo())
	_btn(Rect2(560, 700, 160, 44), L.t("back"), func(): _nav_back())

## ── 挑戰碼：把自己的陣型傳給朋友打（不需要伺服器）──
func _challenge_encode() -> String:
	var r = rules if rules != null else RuleSet.standard()
	var j := JSON.stringify({"a": last_armies[0].to_code(), "r": r.to_code()})
	var b := Marshalls.utf8_to_base64(j).replace("+", "-").replace("/", "_").replace("=", "")
	return "NTC1.%s.%s" % [b, b.sha256_text().substr(0, 6)]

func _copy_challenge() -> void:
	DisplayServer.clipboard_set(_challenge_encode())
	_toast(L.t("ch_copied"))

func _accept_challenge(c := "") -> void:
	var from_clip := c == ""
	if from_clip:
		c = DisplayServer.clipboard_get().strip_edges()
	var d := _challenge_decode(c.strip_edges())
	if not d["ok"]:
		if not (from_clip and _ask_code(L.t("ch_accept"), _accept_challenge)):
			_toast(L.t("ch_bad"), true)
		return
	rules = d["rules"]
	challenge_army = d["army"]
	daily_spec = {}
	rules.rounds = 1
	_start_mode(Mode.VS_AI)

## 回傳 {ok, rules, army}。陣型一定要照那組規則合法。
func _challenge_decode(c: String) -> Dictionary:
	var bad := {"ok": false}
	var parts := c.split(".")
	if c.length() > 6000 or parts.size() != 3 or parts[0] != "NTC1" or parts[1].sha256_text().substr(0, 6) != parts[2]:
		return bad
	var b64 := parts[1].replace("-", "+").replace("_", "/")
	while b64.length() % 4 != 0:
		b64 += "="
	var j = JSON.parse_string(Marshalls.base64_to_utf8(b64))
	if not j is Dictionary or not j.get("a") is String or not j.get("r") is String:
		return bad
	var rd: Dictionary = RuleSet.from_code(str(j["r"]))
	if not rd["ok"] or rd["rules"].fullfield != RuleSet.FULL_NONE:
		return bad      # 全場規則是雙方互相看得到才成立，不能當挑戰碼（Codex r2 #3）
	var r = rd["rules"]
	r.ai_pool_same = false
	# 碼是對方當藍軍排的，到這裡他變紅軍：兩邊的預算、卡池要對調（讓子局才有差，Codex #10）
	var b0: int = r.budget_of(0)
	var b1: int = r.budget_of(1)
	var p0: int = r.pool_of(0)
	var p1: int = r.pool_of(1)
	r.budget = [b1, b0]
	r.pool = [p1, p0]
	r.cmd_mask = [int(r.cmd_mask[1]), int(r.cmd_mask[0])]   # 第十二輪：手動技能也要對調
	var a = Army.new(1, r.budget_of(1))
	a.apply_rules(r, 1)
	a.pool = RuleSet.full_pool()     # 朋友的牌不必在自己的解鎖範圍內
	if a.load_code(str(j["a"])) != "" or not a.has_combat():
		return bad
	if _demo() and not _demo_ok(r, a):
		return bad      # 第十輪 B7：試玩版不能靠挑戰碼帶進正式版內容
	return {"ok": true, "rules": r, "army": a}

## 第十輪 R1：試玩版的範圍集中在這裡。匯入的規則與陣型都走這條。
func _demo_ok(r, a = null) -> bool:
	var mask: int = RS.mask(true)
	if r != null:
		if not r.map_id in Presets.DEMO_MAPS:
			return false
		if r.pool_of(0) & ~mask != 0 or r.pool_of(1) & ~mask != 0:
			return false
	if a != null:
		for u in a.units:
			if not RuleSet.has(mask, int(u["type"])):
				return false
	return true

## ── V1.1 D3：殘局工坊碼 ──
const WS = preload("res://scripts/game/workshop.gd")

func _ws_list(a) -> Array:
	var out: Array = []
	for u in a.units:
		out.append([int(u["type"]), int(u["col"]), int(u["row"])])
	return out

func _make_workshop() -> void:
	var code: String = WS.encode(_ws_list(last_armies[1]), _ws_list(last_armies[0]))
	if code == "":
		_toast(L.t("ws_cant"), true)
		return
	DisplayServer.clipboard_set(code)
	_toast(L.t("ws_copied"))

## V1.0.0（Codex v100-i1 #6）：重跑作者解放背景執行緒（可取消、有期限），畫面不卡；驗完在 _ws_jobs 接著做。
## 開別的模式、離開標題頁就取消；被取消的交給 bg（BgPool）回收。headless／截圖時同步做。
var ws_thread: Thread = null
var ws_ctl := {}
var ws_pending := {}
func _accept_workshop(c := "") -> void:
	var from_clip := c == ""
	if from_clip:
		c = DisplayServer.clipboard_get().strip_edges()
	if not _async_ok():
		_accept_workshop_done(WS.decode(c), from_clip)
		return
	_ws_cancel()
	var ctl: Dictionary = BgPool.make_ctl(WS.SOLVE_MS * 3)
	var code := c
	var t: Thread = bg.start(func(): return WS.decode(code, ctl), ctl)
	if t == null:
		_toast(L.t("ws_slow"), true)
		return
	ws_ctl = ctl
	ws_thread = t
	ws_pending = {"from_clip": from_clip, "overlay": overlay}
	_toast(L.t("ws_checking"))

func _ws_cancel() -> void:
	if ws_thread != null:
		bg.retire(ws_thread)
		ws_thread = null

func _ws_jobs() -> void:
	if ws_thread == null:
		return
	if state != St.TITLE or overlay != str(ws_pending.get("overlay", "")):
		_ws_cancel()   # 驗證中開了別的（換頁、開模式）：不接著做（Codex v100-i2 #3）
		return
	if not ws_thread.is_alive():
		var d: Dictionary = bg.take(ws_thread)
		ws_thread = null
		_accept_workshop_done(d, bool(ws_pending.get("from_clip", false)))

func _ws_exit() -> void:
	_ws_cancel()   # 等待在 bg.drain()

func _accept_workshop_done(d: Dictionary, from_clip: bool) -> void:
	if not bool(d["ok"]):
		if not (from_clip and _ask_code(L.t("ws_accept"), _accept_workshop)):
			_toast(L.t(str(d["why"])), true)
		return
	var pz: Dictionary = d["pz"]
	if _demo():
		var dm: int = RS.mask(true)
		var ts: Array = pz["allowed"].duplicate()   # Codex v110-impl2：可用兵種表也要在試玩版範圍內
		var all_e: Array = pz["enemy"] + d["sol"]
		if d.has("trio"):
			for f in d["trio"]["foes"]:
				all_e += f   # V1.6.1 D2：三考碼三支敵陣都要在試玩版範圍內
		for e in all_e:
			ts.append(int(e[0]))
		for t0 in ts:
			if not RuleSet.has(dm, int(t0)):
				_toast(L.t("demo_locked"), true)
				return
	if d.has("trio"):
		call("_trio_start_custom", d["trio"])   # V1.6.1 D2：朋友出的一陣三考
		return
	PZ.set_custom(pz)
	puzzle_id = "ws"
	_start_mode(Mode.PUZZLE)

## ── V1.4 #5 接力殘局：破了朋友的題，改最多兩隻敵兵再傳回去。你剛才的解要還打得贏改過的陣才給碼 ──
var rl_orig: Array = []      # 原本的敵陣 [兵種, 欄, 列]
var rl_enemy: Array = []     # 改過的敵陣
var rl_sel := Vector2i(-1, -1)
var rl_types: Array = []     # 可以換成的兵種（這一關可用的＋敵陣原有的）
var rl_code := ""

func _open_relay() -> void:
	var pz: Dictionary = PZ.get_puzzle("ws")
	rl_orig = []
	for e in pz.get("enemy", []):
		rl_orig.append([int(e[0]), int(e[1]), int(e[2])])
	rl_enemy = rl_orig.duplicate(true)
	rl_types = pz.get("allowed", []).duplicate()
	for e in rl_orig:
		if not int(e[0]) in rl_types:
			rl_types.append(int(e[0]))
	rl_types.sort()
	rl_sel = Vector2i(-1, -1)
	rl_code = ""
	overlay = "relay"

static func relay_at(list: Array, c: int, r: int) -> int:
	for i in list.size():
		if int(list[i][1]) == c and int(list[i][2]) == r:
			return i
	return -1

## 改了幾格（換兵種、拿掉、新增都算一格；搬移＝兩格）。
static func relay_changes(orig: Array, now: Array) -> int:
	var n := 0
	for c in range(10, 16):
		for r in 9:
			var a := relay_at(orig, c, r)
			var b := relay_at(now, c, r)
			if (a < 0) != (b < 0) or (a >= 0 and b >= 0 and int(orig[a][0]) != int(now[b][0])):
				n += 1
	return n

func _relay_set(t: int) -> void:
	if rl_sel.x < 0:
		return
	var trial: Array = rl_enemy.duplicate(true)
	var i := relay_at(trial, rl_sel.x, rl_sel.y)
	if t < 0:
		if i >= 0:
			trial.remove_at(i)
	elif i >= 0:
		trial[i][0] = t
	else:
		trial.append([t, rl_sel.x, rl_sel.y])
	if relay_changes(rl_orig, trial) > 2:
		_toast(L.t("rl_too_many"), true)
		return
	if trial.is_empty():
		return
	rl_enemy = trial
	rl_code = ""

func _relay_make() -> void:
	var n: int = int(PZ.get_puzzle("ws").get("relay", 0)) + 1
	var code: String = WS.encode(rl_enemy, _ws_list(last_armies[0]), n)
	if code == "":
		_toast(L.t("rl_unsolved"), true)
		return
	rl_code = code
	DisplayServer.clipboard_set(code)
	_toast(L.t("ws_copied"))

func _draw_relay() -> void:
	_dim(0.6)
	var P := Rect2(170, 40, 940, 700)   # V1.5.2：面板上緣提到 40、緞帶跨上緣，日文 150% 說明三行時不壓到右欄「已改 n／2 格」
	_panel(P)
	_h1_help(Vector2(640, 40), L.t("rl_title", [int(PZ.get_puzzle("ws").get("relay", 0)) + 1]), L.t("rl_help"), tz("S"), 860)   # V1.5.2 L3
	# 左：敵方部署區（羊皮紙棋盤，6 欄 × 9 列）；改過的格子淡金底
	# 左：你剛才過關的藍軍（半透明、鎖定），看著對位改（Antigravity v140-i2）
	var bs := 24.0
	var bg := Vector2(196, 186 + (9 * 40 - 9 * bs) / 2.0)
	_text(Vector2(bg.x, bg.y - tz("C") * 1.5), L.t("rl_yours"), tz("C"), Charts.team_col(0, cbm()), false, true, 160)
	_tex_box(Rect2(bg - Vector2(6, 6), Vector2(6 * bs + 10, 9 * bs + 10)), "paper")   # 收尾第 2 輪：深色科技網格改羊皮紙
	for r0 in 9:
		for c0 in 6:
			draw_rect(Rect2(bg + Vector2(c0, r0) * bs, Vector2(bs - 2, bs - 2)), Color(0.45, 0.35, 0.22, 0.12))
	if last_armies.size() >= 1:
		for u in last_armies[0].units:
			if not u.has("col"):
				continue   # 自由排兵的兵（x、y）不在格子上，不畫
			Art.unit(self, bg + Vector2(int(u["col"]) * bs + bs / 2, int(u["row"]) * bs + bs - 3), int(u["type"]), 0, 1.0, 0.0, 0.0, 0.0, 0.6, time, 0.3, cbm())
	var cs := 40.0
	var g0 := Vector2(372, 186)
	_tex_box(Rect2(g0 - Vector2(10, 10), Vector2(6 * cs + 20, 9 * cs + 20)), "paper")
	for r in 9:
		for c in 6:
			var col := 10 + c
			var cell := Rect2(g0 + Vector2(c, r) * cs, Vector2(cs - 3, cs - 3))
			var a := relay_at(rl_orig, col, r)
			var b := relay_at(rl_enemy, col, r)
			var changed := (a < 0) != (b < 0) or (a >= 0 and b >= 0 and int(rl_orig[a][0]) != int(rl_enemy[b][0]))
			draw_rect(cell, Color(0.83, 0.71, 0.45, 0.55) if changed else Color(0.42, 0.3, 0.18, 0.12))
			if rl_sel == Vector2i(col, r):
				_hand_ring(cell.get_center(), cs * 0.5, ACCENT, 2.6, true)
			if b >= 0:
				Art.unit(self, cell.position + Vector2(cs / 2 - 1, cs - 6), int(rl_enemy[b][0]), 1, -1.0, 0.0, 0.0, 0.0, 1.0, time, 0.6, cbm())
			var cc := Vector2i(col, r)
			_btns.append({"r": cell, "cb": func(): rl_sel = cc, "en": true})
	# 右：換成哪種兵、拿掉、還原
	var bx := 660.0
	_text(Vector2(bx, 186), L.t("rl_changes", [relay_changes(rl_orig, rl_enemy)]), tz("S"), Color.WHITE, false, true, 400)
	var by := 186.0 + tz("S") * 1.6
	for k in rl_types.size():
		var t: int = rl_types[k]
		var br := Rect2(bx + (k % 6) * 66, by + (k / 6) * 84, 62, 78)
		_btn(br, "", _relay_set.bind(t), rl_sel.x >= 0)
		var py := br.size.y - tz("C") * 1.15 - 7   # 和覆盤同一個算法：價錢在按鈕面板內
		Art.unit(self, br.position + Vector2(31, py - 2), t, 1, -1.0, 0.0, 0.0, 0.0, 1.0 if rl_sel.x >= 0 else 0.35, time, 0.5, cbm())
		var pcell := Rect2(br.position.x + 4, br.position.y + py - 3, br.size.x - 8, minf(tz("C") * 1.2 + 4, br.size.y - 3 - 4 - (py - 3)))   # 價錢那一條（不碰下緣厚度與九宮格邊）   # 1.3.0 R11：價錢子格
		probe_cell_begin(pcell)
		_text(ink_center_p(pcell, L.t("gold", [D.cost(t)]), tz("C"), true), L.t("gold", [D.cost(t)]), tz("C"), ACCENT if rl_sel.x >= 0 else Color(1, 1, 1, 0.3), true, true)
		probe_cell_end()
	by += (rl_types.size() + 5) / 6 * 84 + 8
	_btn(Rect2(bx, by, 190, 44), L.t("rv_remove"), _relay_set.bind(-1), rl_sel.x >= 0)
	_btn(Rect2(bx + 200, by, 190, 44), L.t("rv_reset"), func(): rl_enemy = rl_orig.duplicate(true); rl_code = "")
	by += 56
	_btn(Rect2(bx, by, 390, 52), L.t("rl_make"), func(): _relay_make(), relay_changes(rl_orig, rl_enemy) >= 1, true)
	by += 66
	if rl_code != "":
		_text(Vector2(bx, by), L.t("rl_done"), tz("S"), Color("#ffd166"), false, true, 390)
	_btn(Rect2(560, 676, 160, 44), L.t("back"), func(): overlay = "")

## ── V1.1 D2：每日挑戰 ──
func _start_daily() -> void:
	_start_daily_day(Daily.today(), false)

## 1.1.0 N4：任一天的每日題；practice＝練習（過去的題：不存最佳、不算連勝、不送排行榜）
var daily_practice := false
func _start_daily_day(day: int, practice: bool) -> void:
	if _demo():
		_toast(L.t("demo_locked"), true)
		return
	var sp: Dictionary = Daily.spec(day)
	var r = Daily.make_rules(sp, RS.mask(false))
	if not r.validate().is_empty():
		_toast(L.t("ch_bad"), true)
		return
	rules = r
	challenge_army = Daily.enemy(sp, r)   # 同一天同一支敵軍（固定陣，走挑戰碼那條路）
	_start_mode(Mode.VS_AI)
	daily_spec = sp   # 突變說明畫在敵方迷霧區（Antigravity v110-impl：開場提示會壓住兵種說明列）
	daily_practice = practice

## 突變說明：數值一律從這組規則讀（不寫死在字串裡）。
func _daily_desc(sp: Dictionary, r) -> String:
	var mut := int(sp["mut"])
	var sk: Array = []
	for s in CmdD.list_of(int(r.cmd_mask[0])):
		sk.append(L.t("cmd_%d" % int(s)))
	var sks := L.t("list_sep").join(sk)
	var args: Array = [[r.ticks / 20], [r.unit_cap, r.type_cap, r.budget_of(0)], [r.unit_cap], [L.t("map_" + str(MapDefs.MAPS[r.map_id]["key"]))],
		[r.type_cap, r.budget_of(0)], [r.ticks / 20, sks], [r.budget_of(0), r.type_cap], [r.budget_of(0), r.unit_cap, sks]][mut]
	return L.t("daily_mut_%d_d" % mut, args)

func _daily_finish(w: int) -> void:
	if daily_spec.is_empty() or w != 0:
		return
	if daily_practice:
		_toast(L.t("daily_practice_done", [PZ.rem_pct(sim.power(0), sim.budget_of(0)), armies[0].spent()]))   # 1.1.0 N4：練習不存紀錄
		return
	var rem: int = PZ.rem_pct(sim.power(0), sim.budget_of(0))
	var spent: int = armies[0].spent()
	var best: Dictionary = Save.data.get("daily_best", {})
	var nw := Daily.record(best, daily_spec, rem, spent)
	Save.data["daily_best"] = best
	_toast(L.t("daily_new" if nw else "daily_best", [rem, spent]))
	Save.save_data()

## 標題頁按鈕上的小字：今天的突變＋今天最佳。
func _daily_caption() -> String:
	var sp: Dictionary = Daily.spec(Daily.today())
	var b: Array = Save.data.get("daily_best", {}).get(sp["key"], [])
	var s: String = L.t("daily_mut_%d" % int(sp["mut"]))
	return s if b.is_empty() else "%s・%d%%" % [s, int(b[0])]

## ── 遠征：每戰後三選一（V1.1 D1：從 6 種事件用種子抽 3 種） ──
var ev_pick := -1   # V1.4 收尾第 1 輪：先選事件與契約，再按「前往下一站」才生效（Codex：點了獎勵就跳過契約）

func _gauntlet_reward() -> void:
	ct_pick = -1
	ev_pick = -1
	overlay = "reward"

## V1.4 #3：正式遠征每一戰結束就結算契約（贏、輸、最後一站都會結算；Codex v140-i1）。
func _settle_contract() -> void:
	ct_last = ""
	if gauntlet_contract >= 0 and gauntlet_contract < CONTRACTS.size():
		var c: Array = CONTRACTS[gauntlet_contract]
		if contract_ok(gauntlet_contract, last_armies[0], sim.winner == 0, sim.tick, PZ.rem_pct(sim.power(0), sim.budget_of(0))):
			gauntlet_gold += int(c[1])
			gauntlet_cap += int(c[2])
			ct_last = L.t("ct_done", [L.t(str(c[0])), _ct_reward(gauntlet_contract)])
		else:
			ct_last = L.t("ct_fail", [L.t(str(c[0]))])
		if sim.winner != 0 or gauntlet_stage >= 7:
			_toast(ct_last)
	gauntlet_contract = -1

## 契約達成了嗎（純函式，測試用）。army＝這一戰我方陣型；win＝我方贏；tick＝結束時間；rem＝我方剩餘戰力 %。
static func contract_ok(k: int, army, win: bool, tick: int, rem: int) -> bool:
	if not win:
		return false
	match k:
		0:
			for u in army.units:
				if int(u["type"]) in RANGED:
					return false
			return true
		1:
			var kinds := {}
			for u in army.units:
				kinds[int(u["type"])] = true
			return kinds.size() <= 3
		2:
			return tick <= 900
		3:
			return rem >= 60
		_:
			return true   # 少帶、窮兵：簽了就是條件，贏了就達成

func _ct_reward(k: int) -> String:
	var c: Array = CONTRACTS[k]
	return L.t("ct_gold", [int(c[1])]) if int(c[1]) > 0 else L.t("ct_cap", [int(c[2])])

## 這一站可簽的 2 份契約（同一趟同一站永遠一樣）。
func _contract_offers() -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = gauntlet_seed * 53 + gauntlet_stage * 389 + 11
	var ids: Array = range(CONTRACTS.size())
	var out: Array = []
	while out.size() < 2:
		var k: int = ids[r.randi() % ids.size()]
		ids.erase(k)
		out.append(k)
	out.sort()
	return out

## 簽了的契約這一戰的代價（預算、隻數），在 _gauntlet_next 之後套上。
func _apply_contract_cost() -> void:
	if gauntlet_contract < 0 or armies.is_empty():
		return
	var c: Array = CONTRACTS[gauntlet_contract]
	armies[0].budget += int(c[3])
	armies[0].unit_cap = maxi(4, armies[0].unit_cap + int(c[4]))
	# 沿用的陣型可能超出降低後的預算／隻數：從最後放的往回拿掉（代價不能被繞過，Codex v140-i1）
	while armies[0].units.size() > 1 and (armies[0].spent() > armies[0].budget or armies[0].units.size() > armies[0].unit_cap):
		# 先拿掉沒貼紙的（剛領的貼紙不要被契約代價吃掉，Antigravity 收尾第 1 輪）；全都貼了才拿最後一隻
		var drop: int = armies[0].units.size() - 1
		for k in range(armies[0].units.size() - 1, -1, -1):
			if int(armies[0].units[k].get("st", 0)) == 0:
				drop = k
				break
		armies[0].units.remove_at(drop)

static func ga_node(stage: int) -> String:
	return GA_NODES[clampi(stage - 1, 0, GA_NODES.size() - 1)]

## 這一站提供的 3 個事件（同一趟同一站永遠一樣，續局也一樣）。募兵沒有可換的就不出。
func _gauntlet_offers() -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = gauntlet_seed * 31 + gauntlet_stage * 977 + 5
	var ids: Array = [0, 1, 2, 3, 4, 5, 6]
	if _recruit_pick().is_empty():
		ids.erase(3)
	if _sticker_pick().is_empty():
		ids.erase(6)
	var out: Array = []
	while out.size() < 3 and not ids.is_empty():
		var k: int = ids[r.randi() % ids.size()]
		ids.erase(k)
		out.append(k)
	out.sort()
	return out

## 募兵：[加入的兵種, 離隊的兵種]。離隊的不能是上一戰陣型裡有的；換完還要有戰鬥兵。
func _recruit_pick() -> Array:
	var pool: int = int(call("_gauntlet_pool"))
	var used := {}
	# Codex v110-impl #1：離隊的不能是剛打完那一戰陣型裡的兵（下一戰會沿用那個陣型）
	var cur: Array = last_armies[0].units if last_armies.size() >= 1 and last_armies[0] != null else gauntlet_prev
	for u in cur:
		used[int(u["type"])] = true
	var ins: Array = []
	var outs: Array = []
	for ty in 20:
		if not RuleSet.has(RS.mask(_demo()), ty):
			continue
		if RuleSet.has(pool, ty):
			if not used.has(ty):
				outs.append(ty)
		else:
			ins.append(ty)
	if ins.is_empty() or outs.is_empty():
		return []
	var r := RandomNumberGenerator.new()
	r.seed = gauntlet_seed * 17 + gauntlet_stage * 131 + 3
	for _i in 8:
		var a: int = ins[r.randi() % ins.size()]
		var b: int = outs[r.randi() % outs.size()]
		var np: int = (pool | (1 << a)) & ~(1 << b)
		if RuleSet.has_combat(np):
			return [a, b]
	return []

## V1.4 #9 木座貼紙：[貼紙, 欄, 列]——這一站固定抽一種貼紙、貼在下一戰沿用陣型裡還沒貼的一隻（同一趟同一站永遠一樣）。
func _sticker_pick() -> Array:
	var cur: Array = last_armies[0].units if last_armies.size() >= 1 and last_armies[0] != null else gauntlet_prev
	var cand: Array = []
	for u in cur:
		if u.has("col") and int(u.get("st", 0)) == 0:
			cand.append(u)
	if cand.is_empty():
		return []
	var r := RandomNumberGenerator.new()
	r.seed = gauntlet_seed * 71 + gauntlet_stage * 293 + 9
	var st: int = 1 + r.randi() % STK.COUNT
	var u: Dictionary = cand[r.randi() % cand.size()]
	return [st, int(u["col"]), int(u["row"])]

## 貼紙說明（數值從常數換進去，不寫死）。英文語序不同，參數順序跟著語言。
static func sticker_desc(st: int) -> String:
	var en := L.lang == "en"
	match st:
		STK.CHARGE:
			return L.t("st_1_d", [STK.CHARGE_PCT - 100, STK.CHARGE_TICKS / 20] if en else [STK.CHARGE_TICKS / 20, STK.CHARGE_PCT - 100])
		STK.BLAST:
			var r := "%.1f" % (STK.BLAST_R / 1000.0)
			return L.t("st_2_d", [STK.BLAST_DMG, r] if en else [r, STK.BLAST_DMG])
		STK.TOUGH:
			return L.t("st_5_d", [STK.TOUGH_PCT - 100])
		STK.SWIFT:
			return L.t("st_6_d", [100 - STK.SWIFT_PCT])
	return L.t("st_%d_d" % st)

func _apply_sticker(sp: Array) -> void:
	for lst in [gauntlet_prev, armies[0].units]:
		for u in lst:
			if u.has("col") and int(u["col"]) == int(sp[1]) and int(u["row"]) == int(sp[2]):
				u["st"] = int(sp[0])

func _take_reward(k: int) -> void:
	var sp := _sticker_pick() if k == 6 else []
	overlay = ""
	gauntlet_foe_gold = 0
	gauntlet_foe_cap = 0
	match k:
		0:
			gauntlet_gold += 10
		1:
			gauntlet_cap += 2
		3:
			var rp := _recruit_pick()
			if not rp.is_empty():
				var pool: int = int(call("_gauntlet_pool"))
				Save.data["gauntlet_pool"] = (pool | (1 << int(rp[0]))) & ~(1 << int(rp[1]))
		4:
			gauntlet_foe_gold = -10
		5:
			gauntlet_foe_cap = -2
	gauntlet_contract = ct_pick   # V1.4 #3：選完事件才生效
	call("_gauntlet_next")
	if not sp.is_empty():
		_apply_sticker(sp)
	_apply_contract_cost()
	if k == 2:
		gauntlet_changes += 2
	call("_gauntlet_save")

func _ga_event_desc(k: int) -> String:
	if k == 6:
		var sp := _sticker_pick()
		if sp.is_empty():
			return ""
		var ty := -1
		var cur: Array = last_armies[0].units if last_armies.size() >= 1 and last_armies[0] != null else gauntlet_prev
		for u in cur:
			if u.has("col") and int(u["col"]) == int(sp[1]) and int(u["row"]) == int(sp[2]):
				ty = int(u["type"])
		return L.t("rw_sticker_d", [L.t("st_%d" % int(sp[0])), L.t("unit_%d" % ty), sticker_desc(int(sp[0]))])
	if k == 3:
		var rp := _recruit_pick()
		return L.t("rw_recruit_d", [L.t("unit_%d" % int(rp[0])), L.t("unit_%d" % int(rp[1]))]) if not rp.is_empty() else ""
	return L.t(GA_EVENTS[k] + "_d")

func _draw_reward() -> void:
	_dim(0.6)
	var P := Rect2(240, 96, 800, 624)
	_panel(P)
	_h1(Vector2(640, 108), L.t("rw_title"))
	_draw_route(Rect2(300, 164, 680, 56), gauntlet_stage + 1)
	var offers := _gauntlet_offers()
	for i in offers.size():
		var k: int = offers[i]
		var r := Rect2(268 + i * 252, 236, 240, 200)
		var kk0 := k
		_btn(r, "", func(): ev_pick = kk0, true, false, TH_ACTIVE if ev_pick == k else TH_WOOD_L)
		if ev_pick == k:
			_hand_ring(r.position + Vector2(r.size.x - 22, 22), 12.0, Color("#ffd166"), 2.6)
		_icon(GA_EVENT_ICONS[k], r.position + Vector2(120, 52), 56.0, ACCENT)
		_text(r.position + Vector2(120, 92), L.t(GA_EVENTS[k]), tz("B"), Color.WHITE, true, true, 220)
		_text(r.position + Vector2(120, 92 + tz("B") * 1.5), _ga_event_desc(k), tz("C"), TXT_DIM, true, false, 220)
	# V1.4 #3 戰利品契約：羊皮紙小卡，可簽一份或不簽（選完上面的事件才生效）
	var cy := 452.0
	_text(Vector2(640, cy), L.t("ct_title"), tz("B"), Color.WHITE, true, true, 740)
	cy += below_head(tz("B"))   # V1.5.2 R9：標題字到契約卡 ≥12
	var cts := _contract_offers()
	for i in 3:
		var cr := Rect2(268 + i * 252, cy, 240, 110)   # 1.2.0：字級放大，契約卡加高 10
		var kk: int = cts[i] if i < cts.size() else -1
		var on := ct_pick == kk
		# 契約是羊皮紙籤（不像上面的獎勵木牌）；「不簽」是次要的木色小鈕；選中的契約蓋紅色火漆章（Antigravity v140-i1）
		btn_paper = kk >= 0
		_btn(cr if kk >= 0 else Rect2(cr.position + Vector2(40, (cr.size.y - 48.0) * 0.5), Vector2(160, 48)), "", func(): ct_pick = kk, true, false, Color(0, 0, 0, 0) if kk >= 0 or not on else TH_ACTIVE)   # 1.2.0：「不簽」鈕在加高的卡裡垂直置中
		var paper := last_btn_paper
		btn_paper = false
		var en := last_btn_enabled
		_probe_dis = not en
		_ink_mode = paper
		var tc := (INK if paper else Color.WHITE) if en else TXT_DIM
		if on and kk >= 0 and en:
			var sc := cr.position + Vector2(cr.size.x - 22, cr.size.y - 20)
			draw_circle(sc, 14.0, Color("#7d1f1f"), true, -1.0, true)
			draw_circle(sc, 11.0, Color("#9e2a2b"), true, -1.0, true)
			_hand_ring(sc, 8.0, Color("#c9584f"), 1.6)
		if kk < 0:
			_text(cr.get_center() - Vector2(0, tz("S") * 0.62 + 1.5), L.t("ct_none"), tz("S"), tc, true, true, 150)   # 對按鈕面置中（扣下緣厚度）
		else:
			# 一行：名稱（左）＋報酬（右）；一行：條件（短）
			var rw := _ct_reward(kk)
			var rww := minf(96.0, _width(rw, tz("C"), true))
			_text(cr.position + Vector2(12, 10), L.t(str(CONTRACTS[kk][0])), tz("S"), tc, false, true, cr.size.x - rww - 34)
			_text(Vector2(cr.end.x - 12 - rww, cr.position.y + 10 + (tz("S") - tz("C")) * 0.5), rw, tz("C"), Color("#7a4a10") if paper else ACCENT, false, true, 96)
			_text(cr.position + Vector2(12, 12 + tz("S") * 1.25), L.t(str(CONTRACTS[kk][0]) + "_d"), tz("C"), tc, false, false, cr.size.x - 24)   # 1.2.0：說明用滿卡寬（字級放大後 190 寬會換成三行出框）
		_ink_mode = false
		_probe_dis = false
	cy += 122   # 1.2.0：契約卡加高 10
	if ct_last != "":
		_text(Vector2(640, cy), ct_last, tz("S"), ACCENT, true, true, 740)
		cy += tz("S") * 1.4
	_text(Vector2(640, cy), L.t("rw_now", [gauntlet_gold, gauntlet_cap]) + "　・　" + L.t("rw_next", [L.t("ga_node_" + ga_node(gauntlet_stage + 1))]), tz("S"), TXT_DIM, true, false, 740)
	_btn(Rect2(540, 668, 200, 44), L.t("rw_go"), func(): _take_reward(ev_pick), ev_pick >= 0, true)

## 遠征路線條：7 個節點，已打過的打勾、下一戰亮框；菁英、首領用不同圖示。
func _draw_route(R: Rect2, next_stage: int) -> void:
	var n := GA_NODES.size()
	var step := R.size.x / (n - 1)
	var cy := R.position.y + R.size.y * 0.5
	draw_line(Vector2(R.position.x, cy), Vector2(R.end.x, cy), Color(1, 1, 1, 0.25), 3.0)
	for i in n:
		var c := Vector2(R.position.x + i * step, cy)
		var kind: String = GA_NODES[i]
		var done := i + 1 < next_stage
		var rad := 20.0 if kind == "boss" else (16.0 if kind == "elite" else 12.0)
		var col := Color("#6b7f5a") if done else (Color("#c0392b") if kind == "boss" else (Color("#b07d2a") if kind == "elite" else Color("#5b4632")))
		draw_circle(c, rad + 3.0, Art.OUT)
		draw_circle(c, rad, col)
		if done:
			draw_polyline(PackedVector2Array([c + Vector2(-rad * 0.5, 0), c + Vector2(-rad * 0.1, rad * 0.4), c + Vector2(rad * 0.55, -rad * 0.45)]), Color.WHITE, 3.0, true)
		elif kind != "fight" and kind != "outpost":
			_icon("star" if kind == "elite" else ("tower" if kind == "boss" else "swords"), c, rad * 1.2, Color.WHITE)   # 終點畫城塔，不再像紅叉（收尾第 2 輪）
		if i + 1 == next_stage:
			draw_arc(c, rad + 7.0, 0, TAU, 28, Color(ACCENT, 0.6 + 0.4 * sin(time * 4.0)), 3.0, true)

## ── 雙人：輪流禁選 ──
func _begin_bans(n: int) -> void:
	# 卡池太小時少禁幾張，至少留 3 種（Codex #6：5 種禁 2＋2 會卡死）
	n = mini(n, (mini(RuleSet.pool_count(rules.pool_of(0)), RuleSet.pool_count(rules.pool_of(1))) - 3) / 2)
	if n <= 0:
		_start_mode(Mode.DUEL)
		return
	ban_left = [n, n]
	ban_turn = 0
	overlay = "ban"

func _ban_skip() -> void:
	ban_left[ban_turn] -= 1
	_ban_next()

func _ban_next() -> void:
	ban_turn = 1 - ban_turn
	if ban_left[ban_turn] <= 0:
		ban_turn = 1 - ban_turn
	if ban_left[0] <= 0 and ban_left[1] <= 0:
		overlay = ""
		_start_mode(Mode.DUEL)

func _ban(t: int) -> void:
	# 兩邊卡池可能不同：各自拿掉（Codex r2 #2）
	var np := [rules.pool_of(0) & ~(1 << t), rules.pool_of(1) & ~(1 << t)]
	for tm in 2:
		var p: int = np[tm]
		if not RuleSet.has_combat(p) or RuleSet.pool_count(p) < 3 or RuleSet.cheapest_combat_in(p) > rules.budget_of(tm):
			_toast(L.t("ban_no"), true)
			return
	rules.pool = np
	ban_left[ban_turn] -= 1
	sfx.play("k_error")
	_ban_next()

## 第十輪 B2：雙方卡池不同時最多 20 張；超過 10 張改小格，全部留在面板內。
func _ban_cell(i: int, n: int) -> Rect2:
	if n <= 10:
		return Rect2(200 + (i % 5) * 178, 196 + (i / 5) * 172, 168, 164)
	return Rect2(76 + (i % 7) * 162, 192 + (i / 7) * 136, 156, 130)

func _ban_panel(n: int) -> Rect2:
	return Rect2(170, 66, 940, 650) if n <= 10 else Rect2(60, 66, 1160, 700)    # 下方留給兵種簡介

func _draw_ban() -> void:
	var ts0: Array = RuleSet.types_of(rules.pool_of(0) | rules.pool_of(1))
	var P: Rect2 = _ban_panel(ts0.size())
	_panel(P)
	_box(P.grow(-3), Color(0, 0, 0, 0), Color("#b8393f"), 8.0, 3.0)   # 紅框：這裡是拿掉牌，不是選牌
	var bhb := _h1(Vector2(640, 70), L.t("ban_title"))
	var who := L.t("blue") if ban_turn == 0 else L.t("red")
	_text(Vector2(640, bhb + GAP_L), L.t("ban_turn", [who, ban_left[ban_turn]]), tz("H2"), Art.team_color(ban_turn, cbm()).lightened(0.2), true, true, 860)
	var ban_hot := -1
	for i in ts0.size():
		var t: int = ts0[i]
		var r: Rect2 = _ban_cell(i, ts0.size())
		var small: bool = ts0.size() > 10
		_btn(r, "", _ban.bind(t), true, false, TH_WOOD)
		if _brief_hot(r):
			ban_hot = t
		var nfs: int = tz("C") if small else tz("B")
		var nm: String = L.t("unit_%d" % t)
		var nh: float = text_h(nm, fit(nm, nfs, r.size.x - 16, true), r.size.x - 16, true)
		var ny: float = minf(76.0 if small else 116.0, r.size.y - nh - 8.0)   # V1.2.1：名字（含換行）從卡片底往上算（英文 150% 原本超出卡片）
		_unit_in(Rect2(r.position, Vector2(r.size.x, minf(74.0 if small else 112.0, ny - 2.0))), t, 0, 1.0, 0.72 if small else 1.05)
		_text(r.position + Vector2(r.size.x / 2, ny), L.t("unit_%d" % t), nfs, Color.WHITE, true, true, r.size.x - 16)
		if r.has_point(mouse) and not pad_mode:
			_icon("ban", r.position + Vector2(r.size.x / 2, 42 if small else 62), 60.0 if small else 84.0)
	_btn(Rect2(P.end.x - 110, 76, 96, 40), L.t("ban_skip"), _ban_skip)
	lobby_brief = _brief_pick(ts0, ban_hot)
	var last: Rect2 = _ban_cell(ts0.size() - 1, ts0.size())
	var by: float = last.end.y + 8
	_unit_brief(Rect2(P.position.x + 24, by, P.size.x - 48, P.end.y - by - 12), lobby_brief)

## ── 戰績 ──
func _record_match(w: int) -> void:
	if armies.is_empty() or armies[0] == null:
		return
	var ug: Dictionary = Save.data.get("unit_games", {})
	var seen := {}
	for u in armies[0].units:
		seen[str(int(u["type"]))] = true
	if mode == Mode.DUEL and armies.size() > 1 and armies[1] != null:   # 第十輪 B4：雙人兩邊贏了都算勝場，場數也要兩邊算
		for u2 in armies[1].units:
			seen[str(int(u2["type"]))] = true
	for k in seen:
		ug[k] = int(ug.get(k, 0)) + 1
	Save.data["unit_games"] = ug
	# V1.5.1：戰績頁的兵種勝率用同一組模式記場數與勝場（原本勝場在殘局、教學、試煉也加，勝率偏高；使用者回報）
	# 實驗室徽章（沙盒調數值）不記（Codex／Antigravity v151-i1）
	if rules != null and Presets.badge(rules, "duel" if mode == Mode.DUEL else "ai") == Presets.BADGE_LAB:
		return
	var gr: Dictionary = Save.data.get("unit_games_rec", {})
	var wr: Dictionary = Save.data.get("unit_wins_rec", {})
	for k in seen:
		gr[k] = int(gr.get(k, 0)) + 1
	if w >= 0 and (w == 0 or mode == Mode.DUEL):
		var won := {}
		var wa = armies[w] if w < armies.size() and armies[w] != null else armies[0]
		for u in wa.units:
			won[str(int(u["type"]))] = true
		for k in won:
			wr[k] = int(wr.get(k, 0)) + 1
	Save.data["unit_games_rec"] = gr
	Save.data["unit_wins_rec"] = wr
	if mode == Mode.DUEL:
		return    # 連勝只算單人
	if w == 0:
		Save.data["streak"] = int(Save.data.get("streak", 0)) + 1
		Save.data["best_streak"] = maxi(int(Save.data.get("best_streak", 0)), int(Save.data["streak"]))
	else:
		Save.data["streak"] = 0

func _draw_profile() -> void:
	var P := Rect2(50, 24, 1180, 752)
	_panel(P)
	_h1(Vector2(640, 30), L.t("pf_title"))   # 1.2.0：H1 放大，緞帶上移 4（R2）
	var st: Dictionary = Save.data.get("stats", {})
	var cs: Dictionary = Save.data.get("custom_stats", {})
	var g: int = int(st.get("games", 0)) + int(cs.get("games", 0))
	var wn: int = int(st.get("wins", 0)) + int(cs.get("wins", 0))
	var trial := 0
	for v in Save.data.get("trial_stars", {}).values():
		trial += int(v)
	var tiles := [["swords", "pf_games", str(g)], ["trophy", "pf_wins", "%d%%" % (wn * 100 / maxi(1, g))], ["repeat", "pf_streak", "%d / %d" % [int(Save.data.get("streak", 0)), int(Save.data.get("best_streak", 0))]],
		["tower", "pf_trials", "%d / %d" % [trial, TRIALS.size() * 3]], ["road", "pf_gauntlet", "%d / 7" % int(Save.data.get("gauntlet_best", 0))]]
	var tw := 212.0
	for i in tiles.size():
		var r := Rect2(78 + i * (tw + 8), 92, tw, 80)
		_box(r, Color(0, 0, 0, 0.24), Color(0, 0, 0, 0), 7.0)
		_icon(tiles[i][0], r.position + Vector2(30, 40), 34.0, ACCENT)
		_text(r.position + Vector2(56, 10), L.t(tiles[i][1]), tz("C"), TXT_DIM, false, false, tw - 62)
		_text(r.position + Vector2(56, 34), tiles[i][2], tz("H2"), Color.WHITE, false, true, tw - 62)
	# 兵種勝率
	_text(Vector2(80, 184), L.t("pf_units"), tz("B"), ACCENT, false, true, 600)
	var ug: Dictionary = Save.data.get("unit_games_rec", {})   # V1.5.1：場數、勝場同口徑（對 AI、遠征、雙人）
	var uw: Dictionary = Save.data.get("unit_wins_rec", {})
	var old_n := 0
	for v in Save.data.get("unit_games", {}).values():
		old_n += int(v)
	var rec_n := 0
	for v in ug.values():
		rec_n += int(v)
	if old_n > rec_n:
		_text(Vector2(80 + _width(L.t("pf_units"), tz("B"), true) + 16, 184 + (tz("B") - tz("C")) * 0.5), L.t("pf_units_since"), tz("C"), TXT_DIM, false, false, 600)   # 舊存檔：從這版起算
	var um := RS.mask(_demo())
	var cw := 108.0
	for t in D.total():
		var r2 := Rect2(78 + (t % 10) * (cw + 4), 212 + (t / 10) * 116, cw, 110)
		_box(r2, Color(0, 0, 0, 0.2), Color(0, 0, 0, 0), 6.0)
		var open: bool = RuleSet.has(um, t)
		_unit_in(Rect2(r2.position, Vector2(cw, 70)), t, 0, 1.0 if open else 0.3, 0.62)
		var gg := int(ug.get(str(t), 0))
		if gg == 0:
			_text(r2.position + Vector2(cw / 2, 74), L.t("pf_none"), tz("C"), TXT_DIM, true, false, cw - 6)   # V1.1 C4：沒出戰不寫 0%
		else:
			_text(r2.position + Vector2(cw / 2, 68), "%d%%" % mini(100, int(uw.get(str(t), 0)) * 100 / gg), tz("B"), Color.WHITE, true, true, cw - 6)
		if gg > 0:
			pass
	# 成就
	var earned: Array = Save.data.get("achievements", [])
	var ach: Dictionary = SteamApi.ACHIEVEMENTS
	var keys := ach.keys()
	var ach_pages := ceili(keys.size() / float(ACH_PAGE))
	pf_ach_page = clampi(pf_ach_page, 0, ach_pages - 1)
	_text(Vector2(80, 448), L.t("pf_ach", [earned.size(), keys.size()]), tz("B"), ACCENT, false, true, 330)
	var hover_k := ""
	if ach_pages > 1:
		# V1.6.1：37 個成就一頁放不下（四欄八列＝32），分頁；切換鈕在「成就」標題右邊
		var px := 80.0 + minf(330.0, _width(L.t("pf_ach", [earned.size(), keys.size()]), tz("B"), true)) + 16.0
		_btn_small(Rect2(px, 440, 44, 40), "◀", func(): pf_ach_page -= 1, pf_ach_page > 0)
		_text(Vector2(px + 84, 448 + (tz("B") - tz("S")) * 0.5), "%d／%d" % [pf_ach_page + 1, ach_pages], tz("S"), Color.WHITE, true, false, 70)
		_btn_small(Rect2(px + 124, 440, 44, 40), "▶", func(): pf_ach_page += 1, pf_ach_page < ach_pages - 1)
	for i2 in range(pf_ach_page * ACH_PAGE, mini(keys.size(), pf_ach_page * ACH_PAGE + ACH_PAGE)):
		var k: String = keys[i2]
		var on: bool = k in earned
		var j2 := i2 - pf_ach_page * ACH_PAGE
		var pos := Vector2(84 + (j2 % 4) * 279, 488 + (j2 / 4) * 28)   # V1.5：四欄；V1.6.1：一頁八列
		var ar := Rect2(pos - Vector2(4, 1), Vector2(271, 26))
		if on:
			_box(ar, Color(1.0, 0.82, 0.4, 0.14), Color(1.0, 0.82, 0.4, 0.55), 4.0, 1.0)   # V1.1 C4：已解鎖加金框
		else:
			_box(ar, Color(0, 0, 0, 0.16), Color(1, 1, 1, 0.10), 4.0, 1.0)   # V1.2.1：未解鎖也有框（三欄對稱）
		# 手把：成就是看不見的焦點目標（不畫按鈕），焦點移到哪一個就顯示它的條件（Codex v121-impl2：不能只輪播）
		var fi := _btns.size()
		_btns.append({"r": ar, "cb": func(): pass, "en": true, "snd": "k_click"})
		if (ar.has_point(mouse) and not pad_mode) or (pad_mode and fi == _focus):
			hover_k = k
			_box(ar.grow(1), Color(0, 0, 0, 0), Color(ACCENT, 0.7), 5.0, 1.5)
		draw_rect(Rect2(ar.position + Vector2(1, 3), Vector2(3, ar.size.y - 6)), SteamApi.ACH_CAT_COL.get(SteamApi.ACH_CAT.get(k, ""), Color(1, 1, 1, 0.2)))   # 1.1.0 A15：類別色條
		_icon("star" if on else "lock", Vector2(pos.x + 10, ar.get_center().y), 20.0, Color("#ffd166") if on else Color(1, 1, 1, 0.3))
		_text(Vector2(pos.x + 26, ar.get_center().y - text_h("Ag", tz("C"), 0.0) * 0.5), str(L.pick(ach[k][0], ach[k][1])), tz("C"), Color.WHITE if on else TXT_DIM, false, false, 242)   # V1.2.1 F5：未解鎖原本 66% 白只有 1.7:1
	# V1.2.1：滑過成就，標題列右邊顯示解鎖條件（未解鎖的也看得到怎麼拿）
	var cond: String = (L.t("pf_ach_hint") if not pad_mode else "") if hover_k == "" else str(L.pick(ACH_DESC.get(hover_k, ["", ""])[0], ACH_DESC.get(hover_k, ["", ""])[1]))
	var cw2 := 560.0
	_text(Vector2(1200 - minf(cw2, _width(cond, tz("S"))), 448 + (tz("B") - tz("S")) * 0.5), cond, tz("S"), TXT_DIM if hover_k == "" else Color.WHITE, false, false, cw2)
	_btn(Rect2(340, 722, 160, 44), L.t("back"), func(): _nav_back())
	_btn(Rect2(520, 722, 200, 44), L.t("nem_open"), func(): _nav_push("profile"); overlay = "nemeses")   # V1.4 #2 宿敵戰記
	_btn(Rect2(740, 722, 200, 44), L.t("paint_open"), func(): call("_paint_open"))   # V1.4 #15 塗裝室

const ACH_PAGE := 32
var pf_ach_page := 0

## ── 殘局提示（第十三輪三層）：方向 → 拿到 1 星後看三星編制 → 自己按才揭曉解答 ──
func _puzzle_hint() -> void:
	if mode == Mode.PUZZLE and not PZ.get_puzzle(puzzle_id).get("best", {}).is_empty():
		puzzle_reveal = false
		overlay = "puzzle_hint"
		return
	var tx := _puzzle_hint_text()
	if tx != "":
		_toast(tx)

func _puzzle_hint_text() -> String:
	var cnt := {}
	for u in armies[1].units:
		var t := int(u["type"])
		cnt[t] = int(cnt.get(t, 0)) + D.cost(t)
	var top := -1
	for t2 in cnt:
		if top < 0 or int(cnt[t2]) > int(cnt[top]):
			top = t2
	if top < 0:
		return ""
	var who := ""
	for x in D.total():
		if top in AIT.BEATS[x] and _allowed(x):
			who = L.t("unit_%d" % x)
			break
	return L.t("hint_main", [L.t("unit_%d" % top)]) if who == "" else L.t("hint_counter", [L.t("unit_%d" % top), who])

func _draw_puzzle_hint() -> void:
	_dim(0.75)   # V1.1 C4：底下的兵與格線不干擾閱讀
	var pz := PZ.get_puzzle(puzzle_id)
	var w := 620.0
	var x := 330.0
	# V1.5.2 L3／L7：內容從緞帶下緣＋16 起；面板照三層內容的實高算（未解鎖時不留一大片空白）
	var R := modal_rect(700, 6.0 + h1_bottom(0.0) + GAP_L + _hint_body_h(pz, w) + GAP_L)
	_panel(R)
	probe_skip("R4", "提示框底列跟內文同一條左線：揭曉／套用在左，返回靠右對齊內文右緣（不是置中按鈕群組）")
	var y := _h1(Vector2(640, R.position.y + 6), L.t("menu_hint")) + GAP_L
	# 第一層：這關的提示句＋對手主力
	_text(Vector2(x, y), L.t("ph_l1"), tz("S"), ACCENT, false, true, w)
	y += tz("S") * 1.5
	var h1: String = L.field(pz, "hint") + "　" + _puzzle_hint_text()
	_text(Vector2(x, y), h1, tz("S"), Color(1, 1, 1, 0.88), false, false, w)
	y += text_h(h1, tz("S"), w) + 16
	# 第二層：三星編制（兵種與隻數，不給位置）
	var got := int(Save.data.get("puzzle_stars", {}).get(puzzle_id, 0))
	_text(Vector2(x, y), L.t("ph_l2"), tz("S"), ACCENT, false, true, w)
	y += tz("S") * 1.5
	if got >= 1:
		var lx := x
		for it in PZ.best_lineup(pz):
			_unit(Vector2(lx + 22, y + 52), int(it[0]), 0, 1.0, 0.0, 0.0, 0.0, 1.0, time, 0.62)
			_text(Vector2(lx + 44, y + 30), "×%d" % int(it[1]), tz("B"), Color.WHITE, false, true)
			lx += 96
		y += 66
		var cond := L.t("ph_cond", [int(pz["star3"]), int(pz["star2"])])
		_text(Vector2(x, y), cond, tz("S"), TXT_DIM, false, false, w)
		y += text_h(cond, tz("S"), w) + 16
	else:
		_text(Vector2(x, y), L.t("ph_locked"), tz("S"), TXT_DIM, false, false, w)
		y += tz("S") * 1.6 + 16
	# 第三層：揭曉解答（要再按一次確認）
	_text(Vector2(x, y), L.t("ph_l3"), tz("S"), ACCENT, false, true, w)
	y += tz("S") * 1.5
	if not puzzle_reveal:
		_btn(Rect2(x, y, 260, 44), L.t("ph_reveal"), func(): puzzle_reveal = true)
	else:
		_text(Vector2(x, y), L.t("ph_reveal_q"), tz("S"), Color(1, 1, 1, 0.85), false, false, w)
		y += text_h(L.t("ph_reveal_q"), tz("S"), w) + 6
		_btn(Rect2(x, y, 220, 44), L.t("ph_apply"), func(): _apply_best(), true, true)
		_btn(Rect2(x + 236, y, 160, 44), L.t("ph_cancel"), func(): puzzle_reveal = false)
	# 返回和第三層按鈕同一列、靠右：大字級時內文變長也不會撞（版面檢查 86_hint_open en 150%）
	_btn(Rect2(x + w - 160, y, 160, 44), L.t("back"), func(): overlay = "")

## 提示框三層內容的高度（和 _draw_puzzle_hint 同一套遞增；面板照它算高）
func _hint_body_h(pz: Dictionary, w: float) -> float:
	var h := tz("S") * 1.5 + text_h(L.field(pz, "hint") + "　" + _puzzle_hint_text(), tz("S"), w) + 16
	h += tz("S") * 1.5
	if int(Save.data.get("puzzle_stars", {}).get(puzzle_id, 0)) >= 1:
		h += 66 + text_h(L.t("ph_cond", [int(pz["star3"]), int(pz["star2"])]), tz("S"), w) + 16
	else:
		h += tz("S") * 1.6 + 16
	h += tz("S") * 1.5
	if puzzle_reveal:
		h += text_h(L.t("ph_reveal_q"), tz("S"), w) + 6
	return h + 44.0

## 把三星解直接擺上去（固定兵留著），技能關連施放時間一起帶。
func _apply_best() -> void:
	var pz := PZ.get_puzzle(puzzle_id)
	var best: Dictionary = pz.get("best", {})
	armies[0] = PZ.player_army(pz)
	for e in best.get("u", []):
		armies[0].place(int(e[0]), int(e[1]), int(e[2]))
	if not best.get("p", []).is_empty():
		puzzle_plan = best["p"].duplicate()
	puzzle_reveal = false
	overlay = ""
	_toast(L.t("ph_applied"))


## V1.2.1：成就的解鎖條件（docs/release/steam-setup.md 同步；PUZZLE_ALL 是第 1 章的 10 關）。
const ACH_DESC := {
	"FIRST_WIN": ["第一次獲勝", "Win your first battle"],
	"LONE_HERO": ["只剩最後一隻兵時拿下勝利", "Win with only one unit left standing"],
	"COMEBACK": ["曾落後 15% 以上戰力後獲勝", "Win after trailing by 15% power or more"],
	"CLOSE_CALL": ["勝利時剩餘戰力 5% 以下", "Win with 5% power or less remaining"],
	"NO_TAKEBACKS": ["打完一場輪流落子的三戰兩勝", "Finish a best-of-3 with turn-by-turn placement"],
	"HARD_WIN": ["打贏困難 AI", "Beat the Hard AI"],
	"SWEEP": ["三戰兩勝以 2:0 拿下", "Win a best-of-3 2–0"],
	"TUTORIAL": ["完成 3 關教學", "Finish all 3 tutorials"],
	"PUZZLE_ALL": ["第 1 章 10 關殘局全部過關", "Clear all 10 Chapter 1 puzzles"],
	"PUZZLE_3STAR": ["任一關殘局拿到三星", "Get 3 stars on any puzzle"],
	"GAUNTLET": ["連勝遠征打到最後一關並獲勝", "Win the final battle of a Gauntlet run"],
	"FRENZY_WIN": ["打進狂熱時間後獲勝", "Win after the Frenzy begins"],
	"ALL_TYPES": ["用 5 種不同的兵獲勝", "Win using 5 different unit types"],
	"CHARGE_5": ["一場衝鋒 5 次以上並獲勝", "Win with 5+ cavalry charges in one battle"],
	"BACKSTAB_3": ["一場背刺 3 次以上並獲勝", "Win with 3+ backstabs in one battle"],
	"CUSTOM_LOWGOLD": ["自訂規則：用低金幣獲勝", "Custom rules: win on a low budget"],
	"CUSTOM_UNDERDOG": ["自訂規則：讓子時以少勝多", "Custom rules: win with the smaller budget"],
	"CUSTOM_BIG": ["自訂規則：大軍團獲勝", "Custom rules: win a grand-army battle"],
	"FANTASY_WIN": ["只用奇幻軍獲勝", "Win using only Monster units"],
	"BOOM_5": ["一場羊爆 5 次以上並獲勝", "Win with 5+ sheep explosions in one battle"],
	"RAISE_3": ["一場復活 3 隻以上並獲勝", "Win after raising 3+ units in one battle"],
	"PUZZLE_100": ["100 關殘局全部過關", "Clear all 100 puzzles"],
	"PUZZLE_ALL3": ["100 關殘局全部三星", "Get 3 stars on all 100 puzzles"],
	"TRIAL_ALL3": ["30 關主題試煉全部三星", "Get 3 stars on all 30 trials"],
	"GHOST_ALL": ["打敗全部幽靈名將的陣型", "Defeat every ghost formation"],
	"WEEKLY_WIN": ["打贏一次每週棋盒", "Win a Weekly Box"],
	"WAVE_3": ["車輪戰連贏三波", "Win all three waves in Waves"],
	"REVENGE": ["在遠征裡打敗宿敵", "Defeat a nemesis in the Gauntlet"],
	"PAINTER": ["在塗裝室換一次顏色", "Change your colors in the paint room"],
	"SHARP_EYE": ["競猜連續押中 5 場", "Call 5 Bets in a row"],
	"SEALED_DONE": ["打完一組雙封蠟三戰", "Finish a Sealed Orders match"],
	"RUSH_10": ["極速賽一次解開 10 題", "Solve 10 puzzles in one Puzzle Rush"],
	"TRIO_STAR3": ["一陣三考任一組拿到三星", "Get 3 stars on any One Army, Three Tests set"],
	"RIFT_WIN": ["打贏一次本週裂隙", "Win a weekly Rift"],
	"WORKBENCH": ["用出題台做出一個殘局碼", "Make a code in the Puzzle Workbench"],
	"MASTER_5": ["任一種兵熟練度到 5 級", "Reach mastery 5 with any unit"],
	"COOP_CLEAR": ["雙人接力遠征打完 7 站", "Clear all 7 stages of a Relay Expedition"],
}


## ── V1.4 #2 宿敵戰記 ──
## 宿敵的稱號：依陣型決定地名、主力兵種與稱呼（同一個陣永遠同一個名字）。
static func nemesis_title_parts(units: Array) -> Array:
	var cnt := {}
	var h := 7
	for u in units:
		var t := int(u["type"])
		cnt[t] = int(cnt.get(t, 0)) + 1
		h = (h * 31 + t * 7 + int(u.get("col", 0)) * 3 + int(u.get("row", 0))) % 100003
	var main := -1
	for t in cnt:
		if main < 0 or int(cnt[t]) > int(cnt[main]) or (int(cnt[t]) == int(cnt[main]) and int(t) < main):
			main = int(t)
	return [h % 6, maxi(0, main), (h / 6) % 4]

func nemesis_title(n: Dictionary) -> String:
	var p: Array = nemesis_title_parts(n.get("units", []))
	return L.t("nem_title", [L.t("nem_place_%d" % int(p[0])), L.t("unit_%d" % int(p[1])), L.t("nem_suf_%d" % int(p[2]))])

## 遠征輸了：記下打敗你的敵陣（同一個陣再輸一次就加次數）。
func _nemesis_record(enemy) -> void:
	var list: Array = Save.data.get("nemeses", [])
	if gauntlet_nemesis >= 0 and gauntlet_nemesis < list.size():
		# 宿敵又贏了：加在原本那筆（它帶著增援，陣型和存的不一樣，Codex v140-i1）
		list[gauntlet_nemesis]["losses"] = int(list[gauntlet_nemesis].get("losses", 1)) + 1
		Save.data["nemeses"] = list
		return
	var units: Array = []
	for u in enemy.units:
		units.append({"type": int(u["type"]), "col": int(u["col"]), "row": int(u["row"])})
	units.sort_custom(func(a, b): return a["col"] < b["col"] or (a["col"] == b["col"] and a["row"] < b["row"]))
	for n in list:
		if n.get("units", []) == units:
			n["losses"] = int(n.get("losses", 1)) + 1
			n["revenged"] = false
			Save.data["nemeses"] = list
			return
	list.append({"units": units, "losses": 1, "revenged": false, "stage": gauntlet_stage})
	while list.size() > NEM_MAX:
		var drop := 0
		for i in list.size():
			if bool(list[i].get("revenged", false)):
				drop = i
				break
		list.remove_at(drop)
	Save.data["nemeses"] = list

## 這一站要不要讓宿敵攔路：菁英站，有還沒復仇的宿敵，依種子 60%。回傳宿敵索引或 -1。
func _nemesis_for_stage() -> int:
	if ga_node(gauntlet_stage) != "elite":
		return -1
	var list: Array = Save.data.get("nemeses", [])
	var open: Array = []
	for i in list.size():
		if not bool(list[i].get("revenged", false)):
			open.append(i)
	if open.is_empty():
		return -1
	var r := RandomNumberGenerator.new()
	r.seed = gauntlet_seed * 97 + gauntlet_stage * 13 + 1
	if r.randf() >= 0.6:
		return -1
	return int(open[r.randi() % open.size()])

## 宿敵的陣：存下來的原陣，再多帶一隻它最貴的兵（宿敵變強了）。
func _nemesis_army(i: int):
	var n: Dictionary = Save.data["nemeses"][i]
	var e = Army.new(1, 9999)
	e.pool = (1 << D.total()) - 1
	for u in n.get("units", []):
		e.units.append({"type": int(u["type"]), "col": int(u["col"]), "row": int(u["row"])})
	var best := -1
	for u in e.units:
		if best < 0 or D.cost(int(u["type"])) > D.cost(best):
			best = int(u["type"])
	if best >= 0:
		for c in range(Army.COLS - 1, Army.COLS - 1 - Army.ZONE, -1):
			var done := false
			for rr in Army.ROWS:
				if e.index_at(c, rr) < 0:
					done = true
					if e.check_place(best, c, rr) == "":   # 守兵種上限（例如小石魔最多 2 隻，Codex v140-i1）
						e.units.append({"type": best, "col": c, "row": rr})
					break
			if done:
				break
	e.budget = e.spent()
	e.unit_cap = e.units.size()
	return e

func _draw_nemeses() -> void:
	_dim(0.6)
	# V1.5.2 L3／L7：清單從緞帶下緣＋16 起；面板照筆數算高（空時不留 500px 空白；滿 6 筆時長高到不碰返回鈕）
	var list: Array = Save.data.get("nemeses", [])
	var n_rows := mini(list.size(), NEM_MAX)
	var body := (n_rows * 98.0 - 10.0) if n_rows > 0 else text_h(L.t("nem_empty"), tz("S"), 760)
	var P := modal_rect(900, 12.0 + h1_help_h("", tz("S"), 760) + body + GAP_XL + 44.0 + GAP_L)
	_panel(P)
	var y := _h1(Vector2(640, P.position.y + 12), L.t("nem_head")) + GAP_L
	if list.is_empty():
		_text(Vector2(640, y), L.t("nem_empty"), tz("S"), TXT_DIM, true, false, 760)
	for i in n_rows:
		var n: Dictionary = list[i]
		var r := Rect2(220, y, 840, 88)
		_tex_box(r, "paper")
		_ink_mode = true
		var done := bool(n.get("revenged", false))
		_text(r.position + Vector2(18, 10), nemesis_title(n), tz("B"), INK, false, true, 520)
		_text(r.position + Vector2(18, 10 + tz("B") * 1.4), L.t("nem_line", [int(n.get("losses", 1)), int(n.get("stage", 1))]), tz("C"), INK, false, false, 520)
		_ink_mode = false
		# 狀態：已復仇＝朱紅「雪恥」印章；還沒＝墨色小字（Antigravity v140-i1）
		var sp := r.position + Vector2(r.size.x - 74, 44)   # 離紙邊夠遠，英文 150% 的 Unavenged 也放得下
		if done:
			draw_set_transform_matrix(Transform2D(-0.18, sp))
			_hand_ring(Vector2.ZERO, 30.0, Color("#8e1b14", 0.95), 3.0)
			_hand_ring(Vector2.ZERO, 25.0, Color("#8e1b14", 0.75), 1.4, false, 1)
			draw_set_transform_matrix(Transform2D.IDENTITY)
			_ink_mode = true
			var nd := L.t("nem_done")
			var nsz: int = tz("S") if _width(nd, tz("S"), true) <= 52.0 else tz("C")   # 英文印章字放得進圓圈（收尾第 2 輪）
			_text(sp - Vector2(0, nsz * 0.62), nd, nsz, Color("#7a140e"), true, true, 56)
			_ink_mode = false
		else:
			_ink_mode = true
			_text(sp - Vector2(0, tz("C") * 0.62), L.t("nem_open_state"), tz("C"), INK, true, false, 120)
			_ink_mode = false
		# 陣型縮影：最多 12 隻小兵頭像
		var us: Array = n.get("units", [])
		for k in mini(12, us.size()):
			Art.unit(self, r.position + Vector2(530 + k * 18, 74), int(us[k]["type"]), 1, -1.0, 0.0, 0.0, 0.0, 0.9, time, 0.36, cbm())
		y += 98
	_btn(Rect2(560, P.end.y - GAP_L - 44.0, 160, 44), L.t("back"), func(): _nav_back("profile"))


