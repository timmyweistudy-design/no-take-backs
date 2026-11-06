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
const GA_EVENTS := ["rw_gold", "rw_cap", "rw_change", "rw_recruit", "rw_scout", "rw_ambush"]
const GA_EVENT_ICONS := ["coin", "people", "swap", "flag", "map", "ban"]
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
		return str(x["zh"] if L.lang == "zh_TW" else x["en"])
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
	var P := Rect2(90, 40, 1100, 720)
	_panel(P)
	_h1(Vector2(640, 50), L.t("trial_title"))
	_text(Vector2(640, 104), L.t("trial_rule"), tz("S"), Color(1, 1, 1, 0.8), true, false, 1000)
	var stars: Dictionary = Save.data.get("trial_stars", {})
	var pages: int = ceili(TRIALS.size() / float(TRIAL_PAGE))
	trial_page = clampi(trial_page, 0, pages - 1)
	# 第十三輪：30 關分 3 頁
	var tot := 0
	for k0 in TRIALS.size():
		tot += int(stars.get(str(k0), 0))
	_text(Vector2(184, 710), L.t("trial_page", [trial_page + 1, pages, tot, TRIALS.size() * 3]), tz("S"), Color(1, 1, 1, 0.75), false, false, 360)
	var cw := 524.0
	var ch := 98.0
	for k in TRIAL_PAGE:
		var i: int = trial_page * TRIAL_PAGE + k
		if i >= TRIALS.size():
			break
		var t: Array = TRIALS[i]
		var x := trial_x(i)
		var r := Rect2(116 + (k % 2) * (cw + 8), 164 + (k / 2) * (ch + 7), cw, ch)
		_btn(r, "", _start_trial.bind(i), not _demo() or i in Presets.DEMO_TRIALS, false, TH_WOOD)
		call("_map_thumb", Rect2(r.position + Vector2(8, 8), Vector2(136, 84)), int(t[0]), int(t[1]))
		_text(r.position + Vector2(154, 8), "%d. %s" % [i + 1, trial_name(i)], tz("B"), Color.WHITE, false, true, cw - 240)
		var sz := "%s %d×%d" % [L.t("map_size_%d" % int(t[1])), MapDefs.SIZES[t[1]][0], MapDefs.SIZES[t[1]][1]]
		var diff: String = L.t(["diff_easy", "diff_normal", "diff_hard"][int(t[3])])
		# 第十三輪新關：第二行放主題規則＋難度（地圖看縮圖就知道），第三行只放星數條件，150% 字級才排得下
		var line2: String = "%s・%s・%s" % [sz, L.t("ai_style_%d" % int(t[2])), diff]
		if x.has("tag_zh"):
			line2 = "%s・%s" % [str(x["tag_zh"] if L.lang == "zh_TW" else x["tag_en"]), diff]
		_text(r.position + Vector2(154, 8 + tz("B") * 1.4), line2, tz("C"), Color(1, 1, 1, 0.72), false, false, cw - 160)
		var tb: int = int(x["budget"]) if x.has("budget") else int(MapDefs.SIZE_SUGGEST[int(t[1])][0])
		# V1.1 C3：條件改成「圖示＋數字」（♥ 剩餘戰力、金幣 花費），不寫長句
		var cy0: float = r.position.y + 8 + tz("B") * 1.4 + tz("C") * 1.35
		var cx0: float = r.position.x + 154
		_icon("heart", Vector2(cx0 + 9, cy0 + tz("C") * 0.62), 16.0, ACCENT)
		var c1s := "≥%d%%" % trial_rem(i)
		_text(Vector2(cx0 + 22, cy0), c1s, tz("C"), ACCENT, false, true, 120)
		var cx1: float = cx0 + 34 + font_bold.get_string_size(c1s, HORIZONTAL_ALIGNMENT_LEFT, -1, tz("C")).x
		_icon("coin", Vector2(cx1 + 9, cy0 + tz("C") * 0.62), 16.0, ACCENT)
		_text(Vector2(cx1 + 22, cy0), "≤%d" % (tb * trial_spend_pct(i) / 100), tz("C"), ACCENT, false, true, 120)
		var got := int(stars.get(str(i), 0))
		for k2 in 3:
			_icon("star", r.position + Vector2(cw - 66 + k2 * 22, 20), 20.0, Color("#ffd166") if k2 < got else Color(1, 1, 1, 0.16))
	# 翻頁鈕放在關卡卡片後面：手把焦點先落在第一關（版面檢查 PADWALK）
	_btn(Rect2(116, 700, 52, 44), "◀", func(): trial_page -= 1, trial_page > 0 and not _demo())
	_btn(Rect2(1112, 700, 52, 44), "▶", func(): trial_page += 1, trial_page < pages - 1 and not _demo())
	_btn(Rect2(560, 700, 160, 44), L.t("back"), func(): overlay = "")

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

## ── V1.1 D2：每日挑戰 ──
func _start_daily() -> void:
	if _demo():
		_toast(L.t("demo_locked"), true)
		return
	var sp: Dictionary = Daily.spec(Daily.today())
	var r = Daily.make_rules(sp, RS.mask(false))
	if not r.validate().is_empty():
		_toast(L.t("ch_bad"), true)
		return
	rules = r
	challenge_army = Daily.enemy(sp, r)   # 同一天同一支敵軍（固定陣，走挑戰碼那條路）
	_start_mode(Mode.VS_AI)
	daily_spec = sp   # 突變說明畫在敵方迷霧區（Antigravity v110-impl：開場提示會壓住兵種說明列）

## 突變說明：數值一律從這組規則讀（不寫死在字串裡）。
func _daily_desc(sp: Dictionary, r) -> String:
	var mut := int(sp["mut"])
	var sk: Array = []
	for s in CmdD.list_of(int(r.cmd_mask[0])):
		sk.append(L.t("cmd_%d" % int(s)))
	var sks := "、".join(sk) if L.lang == "zh_TW" else ", ".join(sk)
	var args: Array = [[r.ticks / 20], [r.unit_cap, r.type_cap, r.budget_of(0)], [r.unit_cap], [L.t("map_" + str(MapDefs.MAPS[r.map_id]["key"]))],
		[r.type_cap, r.budget_of(0)], [r.ticks / 20, sks], [r.budget_of(0), r.type_cap], [r.budget_of(0), r.unit_cap, sks]][mut]
	return L.t("daily_mut_%d_d" % mut, args)

func _daily_finish(w: int) -> void:
	if daily_spec.is_empty() or w != 0:
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
func _gauntlet_reward() -> void:
	overlay = "reward"

static func ga_node(stage: int) -> String:
	return GA_NODES[clampi(stage - 1, 0, GA_NODES.size() - 1)]

## 這一站提供的 3 個事件（同一趟同一站永遠一樣，續局也一樣）。募兵沒有可換的就不出。
func _gauntlet_offers() -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = gauntlet_seed * 31 + gauntlet_stage * 977 + 5
	var ids: Array = [0, 1, 2, 3, 4, 5]
	if _recruit_pick().is_empty():
		ids.erase(3)
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

func _take_reward(k: int) -> void:
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
	call("_gauntlet_next")
	if k == 2:
		gauntlet_changes += 2
	call("_gauntlet_save")

func _ga_event_desc(k: int) -> String:
	if k == 3:
		var rp := _recruit_pick()
		return L.t("rw_recruit_d", [L.t("unit_%d" % int(rp[0])), L.t("unit_%d" % int(rp[1]))]) if not rp.is_empty() else ""
	return L.t(GA_EVENTS[k] + "_d")

func _draw_reward() -> void:
	draw_rect(Rect2(0, 0, 1280, 800), Color(0, 0, 0, 0.6))
	var P := Rect2(240, 150, 800, 480)
	_panel(P)
	_h1(Vector2(640, 162), L.t("rw_title"))
	_draw_route(Rect2(300, 222, 680, 56), gauntlet_stage + 1)
	var offers := _gauntlet_offers()
	for i in offers.size():
		var k: int = offers[i]
		var r := Rect2(268 + i * 252, 300, 240, 210)
		_btn(r, "", _take_reward.bind(k), true, false, TH_WOOD_L)
		_icon(GA_EVENT_ICONS[k], r.position + Vector2(120, 52), 56.0, ACCENT)
		_text(r.position + Vector2(120, 92), L.t(GA_EVENTS[k]), tz("B"), Color.WHITE, true, true, 220)
		_text(r.position + Vector2(120, 92 + tz("B") * 1.5), _ga_event_desc(k), tz("C"), Color(1, 1, 1, 0.75), true, false, 220)
	_text(Vector2(640, 530), L.t("rw_now", [gauntlet_gold, gauntlet_cap]), tz("S"), Color(1, 1, 1, 0.75), true, false, 740)
	_text(Vector2(640, 530 + tz("S") * 1.5), L.t("rw_next", [L.t("ga_node_" + ga_node(gauntlet_stage + 1))]), tz("S"), ACCENT, true, true, 740)

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
			_icon("star" if kind == "elite" else "swords", c, rad * 1.2, Color.WHITE)
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
	_h1(Vector2(640, 70), L.t("ban_title"))
	var who := L.t("blue") if ban_turn == 0 else L.t("red")
	_text(Vector2(640, 134), L.t("ban_turn", [who, ban_left[ban_turn]]), tz("H2"), Art.team_color(ban_turn, cbm()).lightened(0.2), true, true, 860)
	var ban_hot := -1
	for i in ts0.size():
		var t: int = ts0[i]
		var r: Rect2 = _ban_cell(i, ts0.size())
		var small: bool = ts0.size() > 10
		_btn(r, "", _ban.bind(t), true, false, TH_WOOD)
		if _brief_hot(r):
			ban_hot = t
		_unit_in(Rect2(r.position, Vector2(r.size.x, 74 if small else 112)), t, 0, 1.0, 0.72 if small else 1.05)
		_text(r.position + Vector2(r.size.x / 2, 76 if small else 116), L.t("unit_%d" % t), tz("C") if small else tz("B"), Color.WHITE, true, true, r.size.x - 8)
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
	_h1(Vector2(640, 34), L.t("pf_title"))
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
		_text(r.position + Vector2(56, 10), L.t(tiles[i][1]), tz("C"), Color(1, 1, 1, 0.72), false, false, tw - 62)
		_text(r.position + Vector2(56, 34), tiles[i][2], tz("H2"), Color.WHITE, false, true, tw - 62)
	# 兵種勝率
	_text(Vector2(80, 184), L.t("pf_units"), tz("B"), ACCENT, false, true, 600)
	var ug: Dictionary = Save.data.get("unit_games", {})
	var uw: Dictionary = Save.data.get("unit_wins", {})
	var um := RS.mask(_demo())
	var cw := 108.0
	for t in D.total():
		var r2 := Rect2(78 + (t % 10) * (cw + 4), 212 + (t / 10) * 116, cw, 110)
		_box(r2, Color(0, 0, 0, 0.2), Color(0, 0, 0, 0), 6.0)
		var open: bool = RuleSet.has(um, t)
		_unit_in(Rect2(r2.position, Vector2(cw, 70)), t, 0, 1.0 if open else 0.3, 0.62)
		var gg := int(ug.get(str(t), 0))
		if gg == 0:
			_text(r2.position + Vector2(cw / 2, 74), L.t("pf_none"), tz("C"), Color(1, 1, 1, 0.5), true, false, cw - 6)   # V1.1 C4：沒出戰不寫 0%
		else:
			_text(r2.position + Vector2(cw / 2, 68), "%d%%" % mini(100, int(uw.get(str(t), 0)) * 100 / gg), tz("B"), Color.WHITE, true, true, cw - 6)
		if gg > 0:
			pass
	# 成就
	var earned: Array = Save.data.get("achievements", [])
	var ach: Dictionary = SteamApi.ACHIEVEMENTS
	var keys := ach.keys()
	_text(Vector2(80, 448), L.t("pf_ach", [earned.size(), keys.size()]), tz("B"), ACCENT, false, true, 600)
	for i2 in keys.size():
		var k: String = keys[i2]
		var on: bool = k in earned
		var pos := Vector2(84 + (i2 % 3) * 372, 480 + (i2 / 3) * 30)
		if on:
			_box(Rect2(pos - Vector2(4, 1), Vector2(364, 26)), Color(1.0, 0.82, 0.4, 0.14), Color(1.0, 0.82, 0.4, 0.55), 4.0, 1.0)   # V1.1 C4：已解鎖加金框
		_icon("star" if on else "lock", pos + Vector2(10, 12), 20.0, Color("#ffd166") if on else Color(1, 1, 1, 0.3))
		_text(pos + Vector2(26, 0), str(ach[k][0 if L.lang == "zh_TW" else 1]), tz("C"), Color.WHITE if on else Color(1, 1, 1, 0.66), false, false, 340)
	_btn(Rect2(560, 722, 160, 44), L.t("back"), func(): overlay = "")

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
	draw_rect(Rect2(0, 0, 1280, 800), Color(0, 0, 0, 0.75))   # V1.1 C4：底下的兵與格線不干擾閱讀
	var pz := PZ.get_puzzle(puzzle_id)
	var R := Rect2(290, 150, 700, 500)
	_panel(R)
	_h1(Vector2(640, 156), L.t("menu_hint"))
	var y := 220.0
	var w := 620.0
	var x := 330.0
	# 第一層：這關的提示句＋對手主力
	_text(Vector2(x, y), L.t("ph_l1"), tz("S"), ACCENT, false, true, w)
	y += tz("S") * 1.5
	var h1: String = str(pz["hint_zh"] if L.lang == "zh_TW" else pz["hint_en"]) + "　" + _puzzle_hint_text()
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
		_text(Vector2(x, y), cond, tz("S"), Color(1, 1, 1, 0.8), false, false, w)
		y += text_h(cond, tz("S"), w) + 16
	else:
		_text(Vector2(x, y), L.t("ph_locked"), tz("S"), Color(1, 1, 1, 0.55), false, false, w)
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
