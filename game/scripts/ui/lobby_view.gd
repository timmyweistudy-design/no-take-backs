extends "res://scripts/ui/unit_brief.gd"
## 規則大廳（第五輪 §3.5、§3.6）。兩段式：
##   精簡模式：預設卡片＋規則摘要＋（AI 難度／落子方式）＋開戰。新手兩秒開戰。
##   自訂模式：按「自訂細項」展開分頁（軍隊、卡池、對局、AI、沙盒）＋右側說明欄（白話說明、和標準的差異、重置）。
## 改的是 lobby_r；按開戰才複製一份凍結成 rules（這個系列不再變）。


var lobby_kind := "ai"
var lobby_r = null
var lobby_open := false        # 自訂細項展開
var lobby_tab := 0             # 0 軍隊 1 卡池 2 對局 3 AI 4 沙盒
var lobby_item := ""           # 說明欄目前說明的項目
var lobby_menu := false        # 「我的預設」下拉
var lobby_pool_team := 0       # 第八輪：兩邊名單不同時正在看哪一邊
var lobby_filter := 0          # V9 卡池篩選：0 全部、1 近戰、2 遠程、3 支援、4 奇襲
var lobby_sb_unit := 0         # 沙盒分頁正在調的兵種

const LOBBY_TABS := ["lb_tab_army", "lb_tab_deploy", "lb_tab_pool", "lb_tab_match", "lb_tab_ai", "lb_tab_lab", "lb_tab_cmd"]

func _lobby_unlocked() -> int:
	return RS.mask(_demo())

func _lobby_std():
	return Presets.make("standard", lobby_kind, _lobby_unlocked())

## 打開大廳：沿用上次在這個模式用的規則（存檔裡的規則代碼）；沒有或不合法就用標準。
func _open_lobby(kind: String) -> void:
	lobby_kind = kind
	var code := str(Save.data.get("last_rules", {}).get(kind, ""))
	var r = null
	if code != "":
		var d: Dictionary = RuleSet.from_code(code)
		if d["ok"]:
			r = d["rules"]
			r.preset = str(Save.data.get("last_rules", {}).get(kind + "_preset", "custom"))
			if r.preset == "standard":
				r.pool = Presets.make("standard", kind, _lobby_unlocked()).pool.duplicate()   # 舊存檔的標準可能只存到解鎖的幾種
			var ex = Save.data.get("last_rules", {}).get(kind + "_extra", [])
			if ex is Array and ex.size() >= 3:
				if ex.size() >= 4:
					r.time_of = clampi(int(ex[3]), 0, 2)
				r.ai_style = clampi(int(ex[0]), 0, RuleSet.AI_STYLES - 1)
				r.map_mode = clampi(int(ex[1]), 0, 2)
				r.bans = clampi(int(ex[2]), 0, 2)
	if r == null:
		r = Presets.make("standard", kind, _lobby_unlocked())
		# 第四輪的舊設定當作第一次打開大廳的初始值（Codex 第一輪）
		if str(Save.s("roster")) == "classic":
			r.pool = [31, 31]
		if kind == "duel":
			r.place_rule = str(Save.s("duel_rule")) if str(Save.s("duel_rule")) in RuleSet.PLACE_RULES else "snake5"
	lobby_r = r
	# 存過的規則照原樣保留（Codex 實作第 3 輪：重開雙人大廳不能把兩邊不同的卡池改成一樣）；含未解鎖兵由開戰鈕擋
	lobby_open = false
	lobby_menu = false
	lobby_item = ""
	lobby_tab = 0
	_open("lobby")

func _lobby_clamp() -> void:
	Presets.clamp_pool(lobby_r, lobby_kind, _lobby_unlocked(), _demo())

func _lobby_pick(id: String) -> void:
	if id == "fantasy" and not RuleSet.has_new(Presets.selectable(lobby_kind, _lobby_unlocked(), _demo())):
		_toast(L.t("lb_fantasy_locked"), true)   # 第八輪：第 14 場才有第一種奇幻軍
		return
	var keep_level: int = lobby_r.ai_level
	var keep_place: String = lobby_r.place_rule
	var keep_map: Array = [lobby_r.map_id, lobby_r.map_size, lobby_r.ai_style, lobby_r.map_mode]
	lobby_r = Presets.make(id, lobby_kind, Presets.selectable(lobby_kind, _lobby_unlocked(), _demo()))
	lobby_r.ai_level = keep_level
	lobby_r.ai_style = keep_map[2]
	if lobby_r.deploy == "free":
		lobby_r.map_id = keep_map[0]    # 換玩法不動已經選好的地圖
		lobby_r.map_mode = keep_map[3]
	if lobby_kind == "duel" and id != "standard" and id != "classic5":
		lobby_r.place_rule = keep_place
	_lobby_clamp()
	lobby_menu = false

## 規則有改動就把預設名稱改成「自訂」（卡片上不再亮）。
func _lobby_touch() -> void:
	if lobby_r.preset in Presets.IDS:
		var p = Presets.make(lobby_r.preset, lobby_kind, _lobby_unlocked())
		p.ai_level = lobby_r.ai_level
		if not p.equals(lobby_r):
			lobby_r.preset = "custom"

## 卡池裡還沒解鎖（或試玩版不能用）的兵；有的話不能開戰（Codex 實作第 1 輪：匯入的規則照原樣保留，只是不能開戰）。
func _lobby_locked_units() -> Array:
	var sel := Presets.selectable(lobby_kind, _lobby_unlocked(), _demo())
	var out: Array = []
	for tm in 2:
		for t in D.total():
			if RuleSet.has(lobby_r.pool_of(tm), t) and not RuleSet.has(sel, t) and not t in out:
				out.append(t)
	return out

func _lobby_block() -> String:
	var bad: Array = lobby_r.validate()
	if not bad.is_empty():
		return L.t(bad[0])
	if _demo() and (not call("_demo_ok", lobby_r) or lobby_r.ai_level > 1):
		return L.t("demo_locked")     # 第十輪 R1：貼上的規則、舊的上次設定都走這裡
	# 第六輪（Codex 實作第 1 輪 #4）：明牌全場只給對 AI、輪流全場只給雙人（貼上的規則代碼也要擋）
	if (lobby_r.fullfield == RuleSet.FULL_DUEL and lobby_kind != "duel") or (lobby_r.fullfield == RuleSet.FULL_AI and lobby_kind != "ai"):
		return L.t("rr_full_kind")
	var lk := _lobby_locked_units()
	if not lk.is_empty():
		var names: Array = []
		for t in lk:
			names.append(L.t("unit_%d" % t))
		return L.t("lb_has_locked", ["、".join(names)])
	return ""

func _lobby_start() -> void:
	var why := _lobby_block()
	if why != "":
		_toast(why, true)
		return
	var lr: Dictionary = Save.data.get("last_rules", {})
	lr[lobby_kind] = lobby_r.to_code()
	lr[lobby_kind + "_preset"] = lobby_r.preset
	lr[lobby_kind + "_extra"] = [lobby_r.ai_style, lobby_r.map_mode, lobby_r.bans, lobby_r.time_of]   # 系列選項不進規則碼，另外記（Codex #8）
	Save.data["last_rules"] = lr
	Save.save_data()
	rules = lobby_r.copy()
	set("challenge_army", null)
	if lobby_kind == "duel" and rules.bans > 0:
		call("_begin_bans", rules.bans)
		return
	call("_start_mode", Mode.VS_AI if lobby_kind == "ai" else Mode.DUEL)

func _lobby_copy_code() -> void:
	DisplayServer.clipboard_set(lobby_r.to_code())
	_toast(L.t("lb_code_copied"))

func _lobby_paste_code(text := "") -> void:
	var from_clip := text == ""
	var d: Dictionary = RuleSet.from_code(DisplayServer.clipboard_get() if from_clip else text)
	if not d["ok"]:
		if from_clip and _ask_code(L.t("lb_paste"), _lobby_paste_code):
			return
		_toast(L.t(d["why"]) if d["why"].begins_with("rr_") else L.t("lb_code_bad"), true)
		return
	if _demo() and not call("_demo_ok", d["rules"]):
		_toast(L.t("bc_demo_locked"), true)
		return
	lobby_r = d["rules"]
	if not _lobby_locked_units().is_empty():
		_toast(_lobby_block(), true)   # 照原樣保留，開戰鈕會灰掉並寫原因
	else:
		_toast(L.t("lb_code_loaded"))

func _lobby_save_preset() -> void:
	var ps: Array = Save.data.get("rule_presets", [])
	if ps.size() >= Save.MAX_PRESETS:
		_toast(L.t("lb_full", [Save.MAX_PRESETS]), true)   # V1.5：滿了不偷偷蓋掉最舊的，請玩家先刪
		lobby_menu = true
		return
	var used := {}
	for e in ps:
		used[str(e["name"])] = true
	var k := 1
	while used.has(L.t("lb_my_n", [k])):
		k += 1   # 刪過中間那格也不會撞名
	var nm := L.t("lb_my_n", [k])
	ps.append({"name": nm, "code": lobby_r.to_code()})
	Save.data["rule_presets"] = ps
	Save.save_data()
	_toast(L.t("lb_saved", [nm]))

func _lobby_load_preset(i: int) -> void:
	var ps: Array = Save.data.get("rule_presets", [])
	if i >= ps.size():
		return
	var d: Dictionary = RuleSet.from_code(str(ps[i]["code"]))
	lobby_menu = false
	if not d["ok"]:
		_toast(L.t("lb_code_bad"), true)
		return
	lobby_r = d["rules"]
	lobby_r.preset = "custom"
	# 照原樣保留（Codex 實作第 2 輪）：含未解鎖的兵就由開戰鈕灰掉＋原因處理，不偷偷改規則

func _lobby_delete_preset(i: int) -> void:
	var ps: Array = Save.data.get("rule_presets", [])
	if i < ps.size():
		ps.remove_at(i)
		Save.data["rule_presets"] = ps
		Save.save_data()

# ───────── 數值調整 ─────────
static func _step_in(v: int, opts: Array, d: int) -> int:
	var i := opts.find(v)
	if i < 0:
		i = 0
	return opts[clampi(i + d, 0, opts.size() - 1)]

## 第十二輪：手動技能。卡片點一下帶或不帶，一邊 1～3 種。
func _cmd_toggle(team: int, s: int) -> void:
	lobby_item = "cmd_on"
	var m := int(lobby_r.cmd_mask[team])
	if (m >> s) & 1 == 1:
		if CmdD.count_of(m) <= 1:
			_toast(L.t("lb_cmd_min"), true)
			return
	elif CmdD.count_of(m) >= CmdD.MAX_SLOTS:
		_toast(L.t("lb_cmd_max", [CmdD.MAX_SLOTS]), true)
		return
	lobby_r.cmd_mask[team] = m ^ (1 << s)
	_lobby_touch()

## V1.4 #8 指揮官：六位將軍＝手動技能系統的具名套組（帶哪幾種軍令）＋開局多幾金。
## 不新增模擬或規則碼：就是 cmd_mask 與雙方預算（讓子），舊碼照舊。[名字鍵, 技能遮罩, 多幾金]
const COMMANDERS := [["cmdr_iron", 5, 0], ["cmdr_gale", 18, 0], ["cmdr_star", 8, 5], ["cmdr_bishop", 4, 5], ["cmdr_frost", 24, 0], ["cmdr_vet", 1, 10]]

var lobby_cmdr := [-1, -1]     # 兩邊選了哪位指揮官（-1＝自訂；不進規則碼，規則碼只存軍令與預算）
var lobby_cbase := [100, 100]  # 選指揮官前的預算（加成從這裡算，不會越加越多，Codex v140-i2）

func _cmdr_pick(team: int, k: int) -> void:
	lobby_item = "cmd_on"
	if int(lobby_cmdr[0]) < 0 and int(lobby_cmdr[1]) < 0:
		lobby_cbase = [lobby_r.budget_of(0), lobby_r.budget_of(1)]
	lobby_cmdr[team] = k
	lobby_r.cmd_mask[team] = int(COMMANDERS[k][1])
	var b: Array = [0, 0]
	for t in 2:
		var bonus: int = int(COMMANDERS[int(lobby_cmdr[t])][2]) if int(lobby_cmdr[t]) >= 0 else 0
		b[t] = clampi(int(lobby_cbase[t]) + bonus, RuleSet.BUDGET_MIN, RuleSet.BUDGET_MAX)
	lobby_r.budget = b
	lobby_r.handicap = int(b[0]) != int(b[1])
	_lobby_touch()

## 目前這一邊是哪一位指揮官；軍令被手動改過就算自訂。
func cmdr_of(team: int) -> int:
	var k := int(lobby_cmdr[team])
	if k >= 0 and int(lobby_r.cmd_mask[team]) != int(COMMANDERS[k][1]):
		lobby_cmdr[team] = -1
		return -1
	return k

func _draw_cmd_tab(R: Rect2) -> void:
	var on: bool = lobby_r.cmd_on()
	_rows(Rect2(R.position, Vector2(R.size.x, 66)), [["cmd_on", L.t("lb_cmd_enable"), L.t("on") if on else L.t("off")]])
	var y := R.position.y + 70
	if not on:
		_text(Vector2(R.position.x, y), L.t("lb_cmd_hint"), tz("S"), TXT_DIM, false, false, R.size.x)
		return
	for ti in 2:
		var pl: String = (L.t("lb_your_pool") if ti == 0 else L.t("lb_ai_pool")) if lobby_kind == "ai" else (L.t("lb_blue_pool") if ti == 0 else L.t("lb_red_pool"))
		_btn(Rect2(R.position.x + ti * 180, y, 170, 38), pl, func(): lobby_pool_team = ti, true, false, TH_ACTIVE if ti == lobby_pool_team else Color(0, 0, 0, 0))
	y += 44
	var tm: int = clampi(lobby_pool_team, 0, 1)
	# V1.4 #8 指揮官：一排羊皮紙名牌，點一位就套用他的軍令與開局金
	var cur := cmdr_of(tm)
	var chw: float = (R.size.x - 2 * 6) / 3.0   # 兩列三欄：英文 150% 也放得下（Antigravity v140-i2）
	for k in COMMANDERS.size():
		var crr := Rect2(R.position.x + (k % 3) * (chw + 6), y + (k / 3) * 48, chw, 42)
		btn_paper = k == cur
		_btn(crr, "", _cmdr_pick.bind(tm, k), true, false, Color(0, 0, 0, 0))
		btn_paper = false
		_ink_mode = last_btn_paper
		_probe_btn_label = true
		_probe_btn_rect = crr
		_text(crr.get_center() - Vector2(0, tz("C") * 0.62), L.t(str(COMMANDERS[k][0])), tz("C"), INK if _ink_mode else Color.WHITE, true, true, chw - 8)
		_probe_btn_label = false
		_ink_mode = false
	y += 98
	if cur >= 0:
		_text(Vector2(R.position.x, y), L.t(str(COMMANDERS[cur][0]) + "_d"), tz("C"), ACCENT, false, false, R.size.x)
		y += text_h(L.t(str(COMMANDERS[cur][0]) + "_d"), tz("C"), R.size.x) + 6
	var m := int(lobby_r.cmd_mask[tm])
	var hot := -1
	var cw := 114.0
	for s in CmdD.COUNT:
		var cr := Rect2(R.position.x + s * (cw + 6), y, cw, 100)
		var sel: bool = (m >> s) & 1 == 1
		_btn(cr, "", _cmd_toggle.bind(tm, s), true, false, Color(0.22, 0.38, 0.3) if sel else Color(0.16, 0.16, 0.2))
		if _brief_hot(cr):
			hot = s
		_probe_btn_label = true
		_probe_btn_rect = cr
		_icon(CmdD.ICONS[s], cr.position + Vector2(cw / 2, 22), 30.0, ACCENT if sel else Color(1, 1, 1, 0.4))
		_text(cr.position + Vector2(cw / 2, 40), L.t("cmd_%d" % s), tz("C"), Color.WHITE if sel else TXT_DIM, true, false, cw - 6)
		_probe_btn_label = false
		if sel:
			draw_rect(cr, Color("#7ddc8a"), false, 2.0)
	y += 106
	if hot >= 0:
		lobby_cmd_hot = hot
	elif (m >> lobby_cmd_hot) & 1 == 0:
		var lst: Array = CmdD.list_of(m)
		lobby_cmd_hot = int(lst[0]) if not lst.is_empty() else 0
	var ds: String = _cmd_desc(lobby_cmd_hot, lobby_r.cmd_power)
	_text(Vector2(R.position.x, y), L.t("cmd_%d" % lobby_cmd_hot), tz("B"), ACCENT, false, true, R.size.x)
	y += tz("B") * 1.35
	_text(Vector2(R.position.x, y), ds, tz("S"), Color.WHITE, false, false, R.size.x)
	y += text_h(ds, tz("S"), R.size.x) + 10
	var w3: float = (R.size.x - 16) / 3.0
	var items := [["cmd_uses", L.t("lb_cmd_uses"), L.t("lb_cmd_n", [lobby_r.cmd_uses])], ["cmd_cd", L.t("lb_cmd_cd"), L.t("lb_cmd_secs", [lobby_r.cmd_cd / 20])], ["cmd_power", L.t("lb_cmd_power"), "%d%%" % lobby_r.cmd_power]]
	for k in 3:
		var sx: float = R.position.x + k * (w3 + 8)
		_text(Vector2(sx, y), items[k][1], tz("S"), TXT_DIM, false, false, w3)
		_stepper(Rect2(sx, y + tz("S") * 1.35, w3, 52), items[k][2], items[k][0], 36.0)

func _lobby_adj(id: String, d: int) -> void:
	var r = lobby_r
	lobby_item = id
	match id:
		"cmd_on":
			r.cmd_mask = [0, 0] if r.cmd_on() else [CmdD.DEFAULT_MASK, CmdD.DEFAULT_MASK]
		"cmd_uses":
			r.cmd_uses = CmdD.USES[wrapi(CmdD.USES.find(r.cmd_uses) + d, 0, CmdD.USES.size())]
		"cmd_cd":
			r.cmd_cd = CmdD.CD_TICKS[wrapi(CmdD.CD_TICKS.find(r.cmd_cd) + d, 0, CmdD.CD_TICKS.size())]
		"cmd_power":
			r.cmd_power = CmdD.POWERS[wrapi(CmdD.POWERS.find(r.cmd_power) + d, 0, CmdD.POWERS.size())]
		"map":
			if _demo():
				var dm: Array = Presets.DEMO_MAPS
				r.map_id = dm[wrapi(dm.find(r.map_id) + d, 0, dm.size())]
			else:
				r.map_id = wrapi(r.map_id + d, 0, MapDefs.MAPS.size())
			if not r.map_is_default() and r.deploy != "free":
				r.deploy = "free"
				r.spacing = 800
				r.depth = 6000
				r.fullfield = 0
		"ai_style":
			r.ai_style = wrapi(r.ai_style + d, 0, RuleSet.AI_STYLES)
		"map_mode":
			r.map_mode = wrapi(r.map_mode + d, 0, 3)
		"bans":
			r.bans = wrapi(r.bans + d, 0, 3)
		"time_of":
			r.time_of = wrapi(r.time_of + d, 0, 3)
		"budget":
			r.budget[0] = clampi(int(r.budget[0]) + 10 * d, RuleSet.BUDGET_MIN, RuleSet.BUDGET_MAX)
			if not r.handicap:
				r.budget[1] = r.budget[0]
		"handicap":
			r.handicap = not r.handicap
			if not r.handicap:
				r.budget[1] = r.budget[0]
		"budget_red":
			r.budget[1] = clampi(int(r.budget[1]) + 10 * d, RuleSet.BUDGET_MIN, RuleSet.BUDGET_MAX)
		"unit_cap":
			r.unit_cap = clampi(r.unit_cap + 2 * d, RuleSet.UNIT_CAP_MIN, RuleSet.UNIT_CAP_MAX)
		"type_cap":
			r.type_cap = clampi(r.type_cap + d, 0, RuleSet.TYPE_CAP_MAX)
		"ticks":
			r.ticks = _step_in(r.ticks, RuleSet.TICK_CHOICES, d)
		"rounds":
			r.rounds = _step_in(r.rounds, RuleSet.ROUND_CHOICES, d)
		"place_rule":
			var opts := RuleSet.PLACE_RULES
			r.place_rule = opts[posmod(opts.find(r.place_rule) + d, opts.size())]
		"turns":
			r.turns = clampi(r.turns + d, RuleSet.TURNS_MIN, RuleSet.TURNS_MAX)
		"carry":
			r.carry = not r.carry
		"ai_level":
			r.ai_level = clampi(r.ai_level + d, 0, 1 if _demo() else 2)
		"keep":
			r.keep_formation = not r.keep_formation
		"deploy":
			# 第六輪：格子／自由；切到格子時部署欄位回到舊值（NTBR1）
			if r.deploy == "grid":
				r.deploy = "free"
				r.spacing = Presets.FREE_SPACING
				r.depth = Presets.FREE_DEPTH
			else:
				r.deploy = "grid"
				r.spacing = 1000
				r.depth = RuleSet.DEPTH_GRID
				r.fullfield = RuleSet.FULL_NONE
		"spacing":
			if r.deploy == "free":
				r.spacing = clampi(r.spacing + 50 * d, RuleSet.SPACING_MIN, RuleSet.SPACING_MAX)
		"depth":
			if r.deploy == "free":
				r.depth = clampi(r.depth + 500 * d, RuleSet.DEPTH_MIN, RuleSet.DEPTH_MAX)
		"fullfield":
			if r.deploy == "free":
				var want := RuleSet.FULL_AI if lobby_kind == "ai" else RuleSet.FULL_DUEL
				r.fullfield = RuleSet.FULL_NONE if r.fullfield != RuleSet.FULL_NONE else want
				if r.fullfield == RuleSet.FULL_DUEL and r.place_rule == "blind":
					r.place_rule = "snake5"
		"ai_pool_same":
			r.ai_pool_same = not r.ai_pool_same
			if not r.ai_pool_same:
				r.pool[1] = r.pool[0]
	_lobby_touch()

func _lobby_toggle_unit(team: int, t: int) -> void:
	lobby_item = "pool"
	lobby_brief = t      # 觸控沒有懸停：點一下也會講這隻
	var sel := Presets.selectable(lobby_kind, _lobby_unlocked(), _demo())
	if not RuleSet.has(sel, t):
		_toast(L.t("lb_locked_unit"), true)
		return
	# 第八輪：一局每邊最多 10 種
	if not RuleSet.has(int(lobby_r.pool[team]), t) and RuleSet.pool_count(int(lobby_r.pool[team])) >= RuleSet.ROSTER_MAX:
		_toast(L.t("lb_roster_full"), true)
		return
	lobby_r.pool[team] = int(lobby_r.pool[team]) ^ (1 << t)
	if lobby_r.ai_pool_same:
		lobby_r.pool[1] = lobby_r.pool[0]
	_lobby_touch()

func _lobby_sb_adj(k: int, d: int) -> void:
	lobby_item = "lab"
	var cur: Array = lobby_r.stat_pct.get(lobby_sb_unit, [100, 100, 100]).duplicate()
	cur[k] = clampi(int(cur[k]) + 10 * d, RuleSet.PCT_MIN, RuleSet.PCT_MAX)
	if cur == [100, 100, 100]:
		lobby_r.stat_pct.erase(lobby_sb_unit)
	else:
		lobby_r.stat_pct[lobby_sb_unit] = cur
	_lobby_touch()

func _lobby_sb_skill(s: String) -> void:
	lobby_item = "lab"
	if s in lobby_r.skills_off:
		lobby_r.skills_off.erase(s)
	else:
		lobby_r.skills_off.append(s)
	_lobby_touch()

# ───────── 文字 ─────────
func _secs(ticks: int) -> int:
	return ticks / 20

func _rounds_text(n: int) -> String:
	return L.t("lb_rounds_%d" % n)

func _place_text(p: String) -> String:
	return L.t("rule_short_" + p) if p != "custom" else L.t("rule_short_custom", [lobby_r.turns])

func _summary(r) -> String:
	var parts: Array = []
	if r.handicap:
		parts.append(L.t("lb_sum_gold_hc", [r.budget_of(0), r.budget_of(1)]))
	else:
		parts.append(L.t("lb_sum_gold", [r.budget_of(0)]))
	parts.append(L.t("lb_sum_cap", [r.unit_cap]))
	parts.append(L.t("lb_sum_secs", [_secs(r.ticks)]))
	parts.append(_rounds_text(r.rounds))
	if r.deploy == "free":
		parts.append(L.t("lb_sum_free") if r.fullfield == 0 else L.t("lb_sum_full"))
	if r.cmd_on():
		parts.append(L.t("lb_sum_cmd", [CmdD.count_of(int(r.cmd_mask[0]))]))
	return "・".join(parts)

func _badge_pill(p: Vector2, b: String) -> float:
	var col: Color = {"cert": Color("#3fbf6a"), "fun": Color("#e8b33a"), "lab": Color("#a46be0")}[b]
	var icon: String = {"cert": "◎", "fun": "★", "lab": "◇"}[b]
	var lab: String = icon + " " + L.t("lb_badge_" + b)
	var fs := tz("S")
	var w := _width(lab, fs, true) + 20
	var r := Rect2(p, Vector2(w, fs * 1.6))
	draw_rect(r, Color(col, 0.22))
	# 色盲也分得出：認證＝實線框、娛樂＝虛線框、沙盒＝雙線框
	match b:
		"cert":
			draw_rect(r, col, false, 2.0)
		"fun":
			var x := r.position.x
			while x < r.end.x:
				draw_line(Vector2(x, r.position.y), Vector2(minf(x + 6, r.end.x), r.position.y), col, 2.0)
				draw_line(Vector2(x, r.end.y), Vector2(minf(x + 6, r.end.x), r.end.y), col, 2.0)
				x += 10
			draw_line(r.position, Vector2(r.position.x, r.end.y), col, 2.0)
			draw_line(Vector2(r.end.x, r.position.y), r.end, col, 2.0)
		"lab":
			draw_rect(r, col, false, 1.5)
			draw_rect(r.grow(-4), col, false, 1.5)
	_text(r.position + Vector2(10, fs * 0.25), lab, fs, Color.WHITE, false, true)
	return w

# ───────── 繪製 ─────────
func _draw_lobby() -> void:
	var P := Rect2(50, 30, 1180, 740)
	_panel(P)
	var title := L.t("menu_vs_ai") if lobby_kind == "ai" else L.t("menu_duel")
	_h1(Vector2(640, 40), title)
	_draw_lobby_presets(Vector2(80, 96))
	if lobby_open:
		_draw_lobby_detail(Rect2(80, 176, 1120, 508))
	else:
		_draw_lobby_main(Rect2(80, 176, 1120, 508))
		_ink_mode = false   # 任何路徑結束都關掉紙上墨色
	# 底列
	var by := 700.0
	_btn(Rect2(80, by, 150, 48), L.t("back"), func(): _nav_back())
	_btn(Rect2(244, by, 200, 48), L.t("lb_collapse") if lobby_open else L.t("lb_expand"), func(): lobby_open = not lobby_open)
	if lobby_open:
		_btn(Rect2(458, by, 150, 48), L.t("lb_copy"), _lobby_copy_code)
		_btn(Rect2(620, by, 150, 48), L.t("lb_paste"), _lobby_paste_code)
		_btn(Rect2(782, by, 150, 48), L.t("lb_save"), _lobby_save_preset)
	else:
		_btn(Rect2(458, by, 200, 48), L.t("lb_random"), _lobby_random)
	var why := _lobby_block()
	_btn(Rect2(966, by, 234, 48), L.t("lb_start"), _lobby_start, why == "", true)
	if why != "":
		_text(Vector2(1083, by - tz("C") * 1.5), why, tz("C"), Color("#ff8a8a"), true, true, 460)
	if lobby_menu:
		_draw_lobby_menu(Vector2(1000, 186))

func _draw_lobby_presets(o: Vector2) -> void:
	var w := 154.0
	var h := 68.0
	for i in Presets.IDS.size():
		var id: String = Presets.IDS[i]
		var p = Presets.make(id, lobby_kind, _lobby_unlocked())
		Presets.clamp_pool(p, lobby_kind, _lobby_unlocked(), _demo())
		var r := Rect2(o + Vector2(i * (w + 10), 0), Vector2(w, h))
		var on: bool = lobby_r.preset == id
		_btn(r, "", _lobby_pick.bind(id), true, false, TH_ACTIVE if on else TH_WOOD)
		if on:
			draw_rect(r, ACCENT, false, 3.0)
		_text(r.position + Vector2(w / 2, 8), L.t("lb_p_" + id), tz("B"), Color.WHITE, true, true, w - 12)
		var sub_y := 8 + text_h(L.t("lb_p_" + id), tz("B"), w - 12, true) + 2
		if false and sub_y + text_h(L.t("lb_pd_" + id), tz("C"), w - 12) <= h - 14:
			_text(r.position + Vector2(w / 2, sub_y), L.t("lb_pd_" + id), tz("C"), TXT_DIM, true, false, w - 12)   # 放不下（大字）就不畫副標，不壓到色條
		var b := Presets.badge(p, lobby_kind)
		var bc: Color = {"cert": Color("#3fbf6a"), "fun": Color("#e8b33a"), "lab": Color("#a46be0")}[b]
		_box(Rect2(r.position + Vector2(8, h - 13), Vector2(w - 16, 5)), bc, Color(0, 0, 0, 0), 2.0)
	var mr := Rect2(o + Vector2(6 * (w + 10), 0), Vector2(1120 - 6 * (w + 10), h))
	_btn(mr, L.t("lb_mine"), func(): lobby_menu = not lobby_menu, true, false, TH_ACTIVE if lobby_r.preset == "custom" else TH_WOOD)

func _draw_lobby_menu(o: Vector2) -> void:
	var ps: Array = Save.data.get("rule_presets", [])
	var rows: int = clampi(ps.size(), 1, 5)
	var cols := 2 if ps.size() > 5 else 1
	o.x -= 240.0 * (cols - 1) + 30.0
	var r := Rect2(o, Vector2(12 + cols * 240, 12 + rows * 50))
	# 下拉選單蓋住的底層按鈕不能被點到（Antigravity v150-i2 #6）
	for bi in range(_btns.size() - 1, -1, -1):
		if r.intersects(_btns[bi]["r"]):
			_btns.remove_at(bi)
	draw_rect(r, PANEL)
	draw_rect(r, Color(1, 1, 1, 0.3), false, 1.5)
	if ps.is_empty():
		_text(r.position + Vector2(110, 18), L.t("lb_mine_empty"), tz("S"), TXT_DIM, true, false, 200)
		return
	for i in ps.size():
		var cp := r.position + Vector2(6 + (i / 5) * 240, 6 + (i % 5) * 50)
		_btn(Rect2(cp, Vector2(144, 44)), str(ps[i]["name"]), _lobby_load_preset.bind(i))
		_btn(Rect2(cp + Vector2(148, 0), Vector2(44, 44)), "", func(): DisplayServer.clipboard_set(str(ps[i]["code"])); _toast(L.t("lb_copied")))
		_icon("copy", cp + Vector2(170, 22), 18.0, Color.WHITE)
		_btn(Rect2(cp + Vector2(196, 0), Vector2(40, 44)), "×", _lobby_delete_preset.bind(i))

func _filter_hit(t: int) -> bool:
	match lobby_filter:
		1:
			return D.is_melee(t) and not D.is_support(t) and not t in Presets.F8.RAID
		2:
			return not D.is_melee(t) and not D.is_support(t) and not t in Presets.F8.RAID
		3:
			return D.is_support(t)
		4:
			return t in Presets.F8.RAID
	return true

## 部署分頁的陣型小圖：看得到間距和縱深實際長怎樣。
func _draw_deploy_preview(r: Rect2) -> void:
	var w: float = lobby_r.field_w()
	var h: float = lobby_r.field_h()
	var k: float = minf(r.size.x / w, r.size.y / h)
	var q := Rect2(r.position, Vector2(w, h) * k)
	draw_rect(q, Color("#5f8a45"))
	var free_d: bool = lobby_r.deploy == "free"
	var dep: float = lobby_r.half_depth() if free_d else 6000.0
	var sp: float = lobby_r.spacing if free_d else 1000.0
	draw_rect(Rect2(q.position, Vector2(dep * k, q.size.y)), Color(Art.team_color(0, cbm()), 0.28))
	draw_rect(Rect2(q.end.x - dep * k, q.position.y, dep * k, q.size.y), Color(Art.team_color(1, cbm()), 0.28))
	var yy := 500.0
	while yy < h:
		var xx := 500.0
		while xx < dep:
			draw_circle(q.position + Vector2(xx, yy) * k, 2.2, Color.WHITE, true, -1.0, true)
			xx += sp
		yy += sp
	draw_rect(q, Color(0, 0, 0, 0.5), false, 1.5)

func _deck_random() -> void:
	var sel: Array = RuleSet.types_of(Presets.selectable(lobby_kind, _lobby_unlocked(), _demo()))
	sel.shuffle()
	var p := 0
	for t in sel.slice(0, RuleSet.ROSTER_MAX):
		p |= 1 << int(t)
	if not RuleSet.has_combat(p):
		return
	lobby_r.pool[lobby_pool_team] = p
	if lobby_r.ai_pool_same:
		lobby_r.pool[1] = p
	_lobby_touch()

func _deck_save() -> void:
	var decks: Array = Save.data.get("decks", [])
	decks.append(int(lobby_r.pool[lobby_pool_team]))
	while decks.size() > 3:
		decks.pop_front()
	Save.data["decks"] = decks
	Save.save_data()
	_toast(L.t("lb_deck_saved"))

func _deck_load(i: int) -> void:
	var decks: Array = Save.data.get("decks", [])
	if i >= decks.size():
		return
	var sel: int = Presets.selectable(lobby_kind, _lobby_unlocked(), _demo())
	var p: int = int(decks[i]) & sel
	if p == 0 or not RuleSet.has_combat(p):
		_toast(L.t("lb_deck_locked"), true)
		return
	lobby_r.pool[lobby_pool_team] = p
	if lobby_r.ai_pool_same:
		lobby_r.pool[1] = p
	_lobby_touch()

## V9 P5 單頁大廳：左邊四件事（地圖、卡牌、對手、規則），右邊即時預覽；1 秒可開打，細項收在「進階」。
func _draw_lobby_main(R: Rect2) -> void:
	var r = lobby_r
	var x := R.position.x
	var lw := 600.0
	var rowh := 96.0
	var y := R.position.y
	# V1.2 C1：左欄是一頁羊皮紙（像攤開的戰役筆記），紙上的字用墨色
	if not bool(Save.s("plain_ui")):
		# V1.2 C1：攤開的戰術筆記：木書殼＋左右兩頁羊皮紙＋中間書脊陰影（上緣和頁籤留空，Antigravity impl3）
		var top := y - 8.0   # 紙頁上緣和預覽木框之間留白（Antigravity impl4）
		var bot := R.end.y + 6.0
		_tex_box(Rect2(x - 16, top - 4, R.size.x + 32, bot - top + 10), "wood", Color(0.42, 0.27, 0.16))
		_tex_box(Rect2(x - 10, top, lw + 18, bot - top), "paper")
		_tex_box(Rect2(x + lw + 8, top, R.size.x - lw + 2, bot - top), "paper")
		for k in 6:   # 書脊：中間往兩邊漸淡的陰影
			var a := 0.22 - k * 0.035
			draw_rect(Rect2(x + lw + 7 - k * 2.0, top, 2.0, bot - top), Color(0.2, 0.12, 0.05, a))
			draw_rect(Rect2(x + lw + 9 + k * 2.0, top, 2.0, bot - top), Color(0.2, 0.12, 0.05, a))
		_draw_bookmark()
		_ink_mode = true
	var label := func(ic: String, s: String, yy: float) -> void:
		_box(Rect2(x, yy, lw, rowh - 8.0), Color(0.36, 0.22, 0.1, 0.10) if _ink_mode else Color(0, 0, 0, 0.2), Color(0, 0, 0, 0), 7.0)
		_icon(ic, Vector2(x + 26, yy + 24), 26.0, ACCENT)
		_text(Vector2(x + 44, yy + 12), s, tz("B"), Color(1, 1, 1, 0.92), false, true, 112)
	var cx := x + 160
	var cw := lw - 170
	# 地圖
	label.call("map", L.t("lb_map"), y)
	_map_thumb(Rect2(cx, y + 8, 124, 72), r.map_id, r.map_size)
	var mk: String = MapDefs.MAPS[r.map_id]["key"]
	_text(Vector2(cx + 134, y + 26), L.t("map_" + mk), tz("B"), Color.WHITE, false, true, cw - 134 - 104)
	_btn(Rect2(x + lw - 104, y + 22, 44, 44), "‹", _lobby_adj.bind("map", -1))
	_btn(Rect2(x + lw - 54, y + 22, 44, 44), "›", _lobby_adj.bind("map", 1))
	y += rowh
	# 大小
	label.call("size", L.t("lb_size"), y)
	for i in 3:
		var sr := Rect2(cx + i * ((cw - 16) / 3.0 + 8), y + 18, (cw - 16) / 3.0, 52)
		var sz_txt := "%d×%d" % [MapDefs.SIZES[i][0], MapDefs.SIZES[i][1]]
		if L.cjk():
			sz_txt = L.t("map_size_%d" % i) + "  " + sz_txt
		_btn(sr, sz_txt, _lobby_set_size.bind(i), true, false, TH_ACTIVE if r.map_size == i else TH_WOOD)
	y += rowh
	# 卡牌
	label.call("cards", L.t("lb_cards"), y)
	var p0: int = r.pool_of(0)
	_draw_pool_heads(Vector2(cx, y + 6), p0, 44.0)
	_text(Vector2(cx, y + 64 - tz("C") * 0.55), L.t("lb_cards_n", [RuleSet.pool_count(p0)]), tz("C"), TXT_DIM, false, false, cw - 130)   # V1.2.1 B7：和「選牌」鈕同一條中線
	_btn(Rect2(x + lw - 124, y + 44, 114, 40), L.t("lb_pick_cards"), func():
		lobby_open = true
		lobby_tab = LOBBY_TABS.find("lb_tab_pool"))
	y += rowh
	# 對手
	if lobby_kind == "ai":
		label.call("robot", L.t("lb_opponent"), y)
		var w1 := (cw - 8) / 2.0
		_stepper(Rect2(cx, y + 18, w1, 52), L.t(["diff_easy", "diff_normal", "diff_hard"][r.ai_level]), "ai_level", 36.0)
		_stepper(Rect2(cx + w1 + 8, y + 18, w1, 52), L.t("ai_style_%d" % r.ai_style), "ai_style", 36.0)
	else:
		label.call("swords", L.t("lb_place_rule"), y)
		_stepper(Rect2(cx, y + 18, cw, 52), _place_text(r.place_rule), "place_rule")
	y += rowh
	# 規則
	label.call("gear", L.t("lb_rules"), y)
	_text(Vector2(cx, y + 8), _summary(r), tz("S"), Color.WHITE, false, false, cw)
	var by0: float = y + 12 + text_h(_summary(r), tz("S"), cw)
	_badge_pill(Vector2(cx, by0), Presets.badge(r, lobby_kind))
	_btn(Rect2(cx + cw - 124, by0 - 6, 124, 36), L.t("lb_cmd_quick", [L.t("on") if r.cmd_on() else L.t("off")]), func(): _lobby_adj("cmd_on", 1), true, false, TH_ACTIVE if r.cmd_on() else Color(0, 0, 0, 0))
	_ink_mode = false
	# 右：預覽
	var pv := Rect2(x + lw + 16, R.position.y, R.size.x - lw - 16, 288)
	_box(pv.grow(3), TH_WOOD_D, TH_EDGE, 6.0, 2.0)
	_map_thumb(pv, r.map_id, r.map_size, true)
	_wood_frame(pv, 9.0)   # V1.2 C1：沙盤預覽加木框
	var ly := pv.end.y + 12
	var lx := pv.position.x
	_ink_mode = not bool(Save.s("plain_ui"))   # 右頁也是紙：說明字用墨色
	if r.map_id != 0:
		for t in [["block", "terrain_block"], ["slow", "terrain_slow"], ["fast", "terrain_fast"]]:
			_icon(t[0], Vector2(lx + 12, ly + 12), 22.0, Color.WHITE)
			var tw := _width(L.t(t[1]), tz("C"))
			_text(Vector2(lx + 28, ly + 2), L.t(t[1]), tz("C"), Color(1, 1, 1, 0.85))
			lx += 40 + tw + 12
		ly += 34
	# 地圖是什麼樣的玩法（第一眼就要懂）
	var md := map_desc(r.map_id)
	_text(Vector2(pv.position.x, ly), md, tz("S"), Color(1, 1, 1, 0.88), false, false, pv.size.x)
	ly += text_h(md, tz("S"), pv.size.x) + 8
	if lobby_r.map_id != 0 and RuleSet.has_new(lobby_r.pool_of(0)):   # 第十輪 R7：講清楚沒認證，不動 AI 也不動數值
		_text(Vector2(pv.position.x, ly), L.t("lb_map_fantasy_note"), tz("C"), ACCENT, false, false, pv.size.x)
		ly += text_h(L.t("lb_map_fantasy_note"), tz("C"), pv.size.x) + 8
	var notes_h := _lobby_notes_h(pv.size.x)
	if notes_h > 0.0:
		_draw_lobby_notes(Rect2(pv.position.x, ly, pv.size.x, maxf(0.0, R.end.y - ly)))
		_ink_mode = false
	elif R.end.y - ly >= 96.0:
		# 空下來的地方放雙方陣容，填補留白也提醒「要打了」
		var my := minf(R.end.y - 10.0, ly + 104.0)
		var mine: Array = RuleSet.types_of(r.pool_of(0))
		var foes: Array = RuleSet.types_of(r.pool_of(1))
		for k in mini(3, mine.size()):
			Art.unit(self, Vector2(pv.position.x + 50 + k * 66, my), int(mine[(k * 3) % mine.size()]), 0, 1.0, 0.0, 0.0, 0.0, 1.0, time + k, 1.3, cbm())
		for k2 in mini(3, foes.size()):
			Art.unit(self, Vector2(pv.end.x - 50 - k2 * 66, my), int(foes[(k2 * 4 + 1) % foes.size()]), 1, -1.0, 0.0, 0.0, 0.0, 1.0, time + k2, 1.3, cbm())
		_icon("swords", Vector2(pv.get_center().x, my - 32), 44.0, ACCENT)
	_ink_mode = false

## 地圖縮圖：貼上烘好的地面，full 時標出雙方部署區。
func _map_thumb(r: Rect2, map_id: int, size: int, full := false) -> void:
	if map_art == null:
		_map_tex()
	var tex: Texture2D = null
	if map_id != 0 and map_art != null and map_art.is_inside_tree():
		tex = map_art.texture(map_id, size)
	var w := float(MapDefs.width(size))
	var h := float(MapDefs.height(size))
	var k := minf(r.size.x / w, r.size.y / h)
	var q := Rect2(r.get_center() - Vector2(w, h) * k / 2.0, Vector2(w, h) * k)
	if tex != null:
		draw_texture_rect(tex, q, false)
	else:
		draw_rect(q, Color("#6f9a4a"))
		if map_id == 0 and grass != null:
			draw_texture_rect_region(grass, q, Rect2(0, 0, 256, 128), Color(1, 1, 1, 0.8))
	if full:
		var dep: float = lobby_r.half_depth() * k
		draw_rect(Rect2(q.position, Vector2(dep, q.size.y)), Color(Art.team_color(0, cbm()), 0.2))
		draw_rect(Rect2(q.end.x - dep, q.position.y, dep, q.size.y), Color(Art.team_color(1, cbm()), 0.2))
		_icon("flag", q.position + Vector2(20, 22), 28.0, Art.team_color(0, cbm()).lightened(0.3))
		_icon("flag", Vector2(q.end.x - 20, q.position.y + 22), 28.0, Art.team_color(1, cbm()).lightened(0.3))
	draw_rect(q, Color(0, 0, 0, 0.5), false, 1.5)

func _lobby_set_size(z: int) -> void:
	var r = lobby_r
	lobby_item = "map_size"
	if r.map_size == z:
		return
	r.map_size = z
	var s: Array = MapDefs.SIZE_SUGGEST[z]
	r.budget = [int(s[0]), int(s[0])]
	r.unit_cap = int(s[1])
	r.ticks = int(s[2])
	if not r.map_is_default() and r.deploy != "free":
		r.deploy = "free"
		r.spacing = 800
		r.depth = 6000
		r.fullfield = 0
	_lobby_touch()

## 隨機一切：地圖、大小、難度、性格；兵種名單不動（玩家解鎖進度不同）。
func _lobby_random() -> void:
	var r = lobby_r
	r.map_id = Presets.DEMO_MAPS[randi() % Presets.DEMO_MAPS.size()] if _demo() else randi() % MapDefs.MAPS.size()
	_lobby_set_size(randi() % 3)
	if r.map_id != 0 and r.deploy != "free":
		r.deploy = "free"
		r.spacing = 800
		r.depth = 6000
	if lobby_kind == "ai":
		r.ai_style = randi() % RuleSet.AI_STYLES
		r.ai_level = randi() % (2 if _demo() else 3)
	_lobby_touch()

## 精簡模式：一張規則摘要卡＋卡池頭像＋一個最常調的選項＋提示。
func _draw_lobby_compact(R: Rect2) -> void:
	draw_rect(R, Color(0, 0, 0, 0.22))
	var y := R.position.y + 20
	_text(Vector2(R.position.x + 24, y), _summary(lobby_r), tz("H2"), Color.WHITE, false, true, 760)
	_badge_pill(Vector2(R.end.x - 230, y), Presets.badge(lobby_r, lobby_kind))
	# 第七輪 B4：雙人超過 5 種兵，先後手公平性沒驗證過，要講清楚
	if lobby_kind == "duel" and maxi(RuleSet.pool_count(lobby_r.pool_of(0)), RuleSet.pool_count(lobby_r.pool_of(1))) > D.CLASSIC:
		_text(Vector2(R.position.x, R.end.y - tz("C") * 1.3), L.t("lb_unverified"), tz("C"), Color("#ffb86b"), false, false, R.size.x)
	y += 60
	_text(Vector2(R.position.x + 24, y), L.t("lb_pool_now"), tz("S"), TXT_DIM)
	_draw_pool_heads(Vector2(R.position.x + 24, y + 28), lobby_r.pool_of(0), 58.0)
	if lobby_kind == "ai" and not lobby_r.ai_pool_same:
		_text(Vector2(R.position.x + 24, y + 104), L.t("lb_ai_pool"), tz("S"), TXT_DIM)
		_draw_pool_heads(Vector2(R.position.x + 24, y + 132), lobby_r.pool_of(1), 58.0)
	# 右側：最常調的一個選項（對 AI＝難度；雙人＝落子方式）
	var ox := R.end.x - 420
	var oy := R.position.y + 110
	var sy := oy + tz("B") * 1.6
	if lobby_kind == "ai":
		_text(Vector2(ox, oy), L.t("lb_ai_level"), tz("B"), TXT_DIM)
		_stepper(Rect2(ox, sy, 380, 64), L.t(["diff_easy", "diff_normal", "diff_hard"][lobby_r.ai_level]), "ai_level")
	else:
		_text(Vector2(ox, oy), L.t("lb_place_rule"), tz("B"), TXT_DIM)
		_stepper(Rect2(ox, sy, 380, 64), _place_text(lobby_r.place_rule), "place_rule")
	# 這個預設是做什麼的（一段白話）
	var pid: String = lobby_r.preset if lobby_r.preset in Presets.IDS else "custom"
	var info := L.t("lb_pinfo_" + pid)
	_text(Vector2(R.position.x + 24, R.position.y + 250), info, tz("B"), Color(1, 1, 1, 0.85), false, false, 640)
	_draw_lobby_notes(Rect2(R.end.x - 420, R.position.y + 210, 396, 230))

## 警告＋差異清單大約要多高（說明欄排版用）。
func _lobby_notes_h(w: float) -> float:
	var h := 0.0
	for k in lobby_r.validate():
		h += text_h("× " + L.t(k), tz("B"), w, true) + 4
	var two: bool = lobby_r.handicap or not lobby_r.ai_pool_same
	for tm in (2 if two else 1):
		var ms: Dictionary = lobby_r.max_spend(tm)
		if int(ms["unused"]) > 0:
			h += text_h("⚠ " + L.t("lb_unused", [ms["units"], ms["spend"], ms["unused"]]), tz("S"), w) + 4
	var df: Array = lobby_r.diff(_lobby_std())
	if not df.is_empty():
		h += tz("S") * 1.4
		for d in df:
			h += text_h("・" + _diff_text(d), tz("S"), w - 10)
	return h

## 驗證錯誤（紅）、花不完的錢（黃）、和標準不同的項目。
func _draw_lobby_notes(R: Rect2) -> void:
	var y := R.position.y
	for k in lobby_r.validate():
		_text(Vector2(R.position.x, y), "× " + L.t(k), tz("B"), Color("#ff7b7b"), false, true, R.size.x)
		y += tz("B") * 1.5
	var two: bool = lobby_r.handicap or not lobby_r.ai_pool_same
	for tm in (2 if two else 1):
		var ms: Dictionary = lobby_r.max_spend(tm)
		if int(ms["unused"]) > 0 and lobby_r.validate().is_empty():
			var who := (L.t("blue") if tm == 0 else L.t("red")) + "：" if two else ""
			var line := "⚠ " + who + L.t("lb_unused", [ms["units"], ms["spend"], ms["unused"]])
			_text(Vector2(R.position.x, y), line, tz("S"), Color("#ffd166"), false, false, R.size.x)
			y += text_h(line, tz("S"), R.size.x) + 4
	var df: Array = lobby_r.diff(_lobby_std())
	if not df.is_empty() and y + tz("S") * 1.4 <= R.end.y:
		_text(Vector2(R.position.x, y), L.t("lb_diff_n", [df.size()]), tz("S"), TXT_DIM, false, true, R.size.x)
		y += tz("S") * 1.4
		var fs := tz("S")
		var left := R.end.y - y - tz("S") * 0.6   # 留一點邊，最後一行不碰到下面的重置鈕
		var list_h := 0.0
		for d in df:
			list_h += text_h("・" + _diff_text(d), fs, R.size.x - 10)
		if list_h <= left:
			for d in df:
				var ln := "・" + _diff_text(d)
				_text(Vector2(R.position.x + 10, y), ln, fs, TXT_DIM, false, false, R.size.x - 10)
				y += text_h(ln, fs, R.size.x - 10)
		else:
			# 放不下（大字）：改成一段連續文字、用註記字級；還是放不下就截到放得下的項目數＋「…」（Antigravity 實作第 1 輪）
			fs = tz("C")
			var bits: Array = []
			for d in df:
				bits.append(_diff_text(d))
			var para := "・".join(bits)
			while bits.size() > 1 and text_h(para, fs, R.size.x) > left:
				bits.pop_back()
				para = "・".join(bits) + "…"
			if text_h(para, fs, R.size.x) <= left:
				_text(Vector2(R.position.x, y), para, fs, TXT_DIM, false, false, R.size.x)

func _diff_text(d: Array) -> String:
	var k: String = d[0]
	match k:
		"rr_deploy":
			return "%s %s→%s" % [L.t(k), L.t("lb_deploy_short_" + str(d[1])), L.t("lb_deploy_short_" + str(d[2]))]
		"rr_spacing", "rr_depth":
			return "%s %.2f→%.2f" % [L.t(k), int(d[1]) / 1000.0, int(d[2]) / 1000.0]
		"rr_full", "rr_cmd":
			return "%s %s" % [L.t(k), L.t("on") if int(d[2]) != 0 else L.t("off")]
		"rr_pool", "rr_ai_pool":
			# 第八輪：奇幻軍和標準一樣 10 種，寫「10→10」看不出差別
			return L.t(k + "_swap", [d[2]]) if d[1] == d[2] else L.t(k + "_d", [d[1], d[2]])
		"rr_rounds":
			return "%s %s→%s" % [L.t(k), _rounds_text(int(d[1])), _rounds_text(int(d[2]))]
		"rr_place":
			return "%s %s→%s" % [L.t(k), L.t("rule_" + str(d[1])) if str(d[1]) != "custom" else "—", _place_text(str(d[2]))]
		"rr_carry", "rr_sandbox", "rr_handicap":
			return L.t(k) + ("" if k != "rr_handicap" else " %d→%d" % [d[1], d[2]])
		"rr_type_cap":
			return "%s %s→%s" % [L.t(k), L.t("lb_nolimit") if int(d[1]) == 0 else str(d[1]), L.t("lb_nolimit") if int(d[2]) == 0 else str(d[2])]
	return "%s %s→%s" % [L.t(k), str(d[1]), str(d[2])]

func _draw_pool_heads(o: Vector2, p: int, step: float) -> void:
	# 第八輪：20 種全畫會超出面板，只畫這場名單裡的（一邊最多 10 種，步距 58 剛好在左欄內）
	var i := 0
	for t in D.total():
		if not RuleSet.has(p, t):
			continue
		var cc := o + Vector2(i * step + step / 2, step * 0.55)
		draw_circle(cc, step * 0.42, Color(1, 1, 1, 0.10))
		var hs := minf(0.5, step / 100.0)
		Art.unit(self, unit_center_feet(cc, t, hs), t, 0, 1.0, 0.0, 0.0, 0.0, 1.0, time, hs, cbm())
		i += 1

## ◀ 值 ▶ 的調整列；點兩側箭頭，也可以點中間（往下一個）。
func _stepper(r: Rect2, value: String, id: String, aw := 52.0) -> void:
	_btn(Rect2(r.position, Vector2(aw, r.size.y)), "◀", _lobby_adj.bind(id, -1))
	_btn(Rect2(r.position + Vector2(aw + 6, 0), Vector2(r.size.x - aw * 2 - 12, r.size.y)), value, _lobby_adj.bind(id, 1), true, false, TH_WOOD_D)
	_btn(Rect2(r.end.x - aw, r.position.y, aw, r.size.y), "▶", _lobby_adj.bind(id, 1))
	if r.grow(4).has_point(mouse):
		lobby_item = id

## 自訂模式：左邊分頁＋項目，右邊說明欄。
func _draw_lobby_detail(R: Rect2) -> void:
	var tabs: Array = LOBBY_TABS.duplicate()
	if lobby_kind == "duel":
		tabs.erase("lb_tab_ai")
	for i in tabs.size():
		var idx: int = LOBBY_TABS.find(tabs[i])
		_btn(Rect2(R.position + Vector2(0, i * 58), Vector2(150, 50)), L.t(tabs[i]), func(): lobby_tab = idx, true, false,
			TH_ACTIVE if idx == lobby_tab else Color(0, 0, 0, 0))
	var L0 := Rect2(R.position + Vector2(170, 0), Vector2(600, R.size.y))
	var D0 := Rect2(Vector2(L0.end.x + 20, R.position.y), Vector2(R.end.x - L0.end.x - 20, R.size.y))
	draw_rect(D0, Color(0, 0, 0, 0.25))
	match lobby_tab:
		0:
			var rows: Array = [["budget", L.t("lb_gold_blue") if lobby_r.handicap else L.t("lb_gold"), L.t("lb_n_gold", [lobby_r.budget_of(0)])],
				["handicap", L.t("lb_handicap"), L.t("on") if lobby_r.handicap else L.t("off")]]
			if lobby_r.handicap:
				rows.append(["budget_red", L.t("lb_gold_red"), L.t("lb_n_gold", [lobby_r.budget_of(1)])])
			rows.append(["unit_cap", L.t("lb_cap"), L.t("lb_n_units", [lobby_r.unit_cap])])
			rows.append(["type_cap", L.t("lb_type_cap"), L.t("lb_nolimit") if lobby_r.type_cap == 0 else L.t("lb_n_units", [lobby_r.type_cap])])
			_rows(L0, rows)
		1:
			var fr: bool = lobby_r.deploy == "free"
			var rowsd: Array = [["deploy", L.t("lb_deploy"), L.t("lb_deploy_free") if fr else L.t("lb_deploy_grid")]]
			if fr:
				rowsd.append(["spacing", L.t("lb_spacing"), L.t("lb_cells", [lobby_r.spacing / 1000.0])])
				# 全場：雙人沒有縱深（整個戰場）；對 AI 的縱深只管 AI 自己擺多深（Antigravity 實作第 1 輪 #7）
				if lobby_r.fullfield == RuleSet.FULL_NONE:
					rowsd.append(["depth", L.t("lb_depth"), L.t("lb_cells", [lobby_r.depth / 1000.0])])
				elif lobby_kind == "ai":
					rowsd.append(["depth", L.t("lb_depth_ai"), L.t("lb_cells", [lobby_r.depth / 1000.0])])
				rowsd.append(["fullfield", L.t("lb_full_ai") if lobby_kind == "ai" else L.t("lb_full_duel"), L.t("on") if lobby_r.fullfield != 0 else L.t("off")])
			_rows(L0, rowsd)
			var pv_y: float = L0.position.y + rowsd.size() * 66 + 8
			if L0.end.y - pv_y >= 110.0:
				_draw_deploy_preview(Rect2(L0.position.x + 230, pv_y, 360, L0.end.y - pv_y - 8))
				_text(Vector2(L0.position.x, pv_y + 4), L.t("lb_deploy_preview"), tz("S"), TXT_DIM, false, false, 220)
		2:
			_draw_pool_tab(L0)
		3:
			var rows2: Array = [["ticks", L.t("lb_time"), L.t("lb_n_secs", [_secs(lobby_r.ticks)])], ["rounds", L.t("lb_rounds"), _rounds_text(lobby_r.rounds)]]
			if lobby_kind == "duel":
				rows2.append(["place_rule", L.t("lb_place_rule"), _place_text(lobby_r.place_rule)])
				if lobby_r.place_rule == "custom":
					rows2.append(["turns", L.t("lb_turns"), L.t("lb_n_turns", [lobby_r.turns])])
				if lobby_r.place_rule != "blind":
					rows2.append(["carry", L.t("lb_carry"), L.t("on") if lobby_r.carry else L.t("off")])
				rows2.append(["bans", L.t("lb_bans"), L.t("lb_bans_n", [lobby_r.bans])])
			rows2.append(["keep", L.t("lb_keep"), L.t("on") if lobby_r.keep_formation else L.t("off")])
			if lobby_r.deploy == "free":
				rows2.append(["map_mode", L.t("lb_map_mode"), L.t("map_mode_%d" % lobby_r.map_mode)])
			rows2.append(["time_of", L.t("lb_time_of"), L.t("time_of_%d" % lobby_r.time_of)])
			_rows(L0, rows2)
		4:
			_rows(L0, [["ai_level", L.t("lb_ai_level"), L.t(["diff_easy", "diff_normal", "diff_hard"][lobby_r.ai_level])],
				["ai_pool_same", L.t("lb_ai_pool_same"), L.t("on") if lobby_r.ai_pool_same else L.t("off")]])
		5:
			_draw_lab_tab(L0)
		6:
			_draw_cmd_tab(L0)
	_draw_lobby_desc(D0)

func _rows(R: Rect2, rows: Array) -> void:
	for i in rows.size():
		var y := R.position.y + i * 66
		_text(Vector2(R.position.x, y + 14), rows[i][1], tz("B"), Color.WHITE, false, false, 220)
		_stepper(Rect2(R.position.x + 230, y, 360, 52), rows[i][2], rows[i][0])

var lobby_cmd_hot := 0

func _draw_pool_tab(R: Rect2) -> void:
	var brief_list: Array = []
	var brief_hot := -1
	# 第八輪：兩邊名單不同時一次只顯示一邊（兩排卡片放不下兩隊），用分頁切換
	var y := R.position.y
	var sel := Presets.selectable(lobby_kind, _lobby_unlocked(), _demo())
	var two: bool = not lobby_r.ai_pool_same
	if not two:
		lobby_pool_team = 0
	if two:
		for ti in 2:
			var pl: String = (L.t("lb_your_pool") if ti == 0 else L.t("lb_ai_pool")) if lobby_kind == "ai" else (L.t("lb_blue_pool") if ti == 0 else L.t("lb_red_pool"))
			_btn(Rect2(R.position.x + ti * 180, y, 170, 38), pl, func(): lobby_pool_team = ti, true, false, TH_ACTIVE if ti == lobby_pool_team else Color(0, 0, 0, 0))
		y += 44
	var teams := [lobby_pool_team]
	for tm in teams:
		# 戰鬥兵、支援兵分框（第五輪 §3.6）
		# 第八輪：出戰名單 2×10（上王國軍、下奇幻軍）；第一次有新兵解鎖前只有一排，不嚇新手
		var has_new_row: bool = RuleSet.has_new(sel)
		var title_r: String = L.t("lb_roster_title", [RuleSet.pool_count(int(lobby_r.pool[tm]))])
		_text(Vector2(R.position.x, y), title_r, tz("S"), ACCENT, false, true, 190)
		# 篩選膠囊：不符合的變暗，不會改到名單
		# V1.2.1：膠囊接在標題後面，寬度依最長標籤、但不超過剩下的空間（英文 150% 的 Support 原本比按鈕寬）
		var fx0: float = minf(196.0, _width(title_r, tz("S"), true) + 12.0)
		var fw := 76.0
		for fi0 in 5:
			fw = maxf(fw, _width(L.t("lb_filter_%d" % fi0), ts(15)) + 14.0)
		fw = minf(fw, (R.size.x - fx0) / 5.0 - 4.0)
		for fi in 5:
			_btn(Rect2(R.position.x + fx0 + fi * (fw + 4.0), y - 4, fw, 36), L.t("lb_filter_%d" % fi), func(): lobby_filter = fi, true, false, TH_ACTIVE if lobby_filter == fi else TH_WOOD)
		y += 38.0
		var groups := [[L.t("lb_army_kingdom"), [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]]]
		if has_new_row:
			groups.append([L.t("lb_army_fantasy"), [10, 11, 12, 13, 14, 15, 16, 17, 18, 19]])
		var x := R.position.x
		for g in groups:
			var cw := 54.0
			var gw: float = g[1].size() * (cw + 4) + 12
			var cardh: float = 62.0 if two else 76.0
			var box := Rect2(x, y, gw, cardh + 12.0 + tz("C") * 1.2)
			draw_rect(box, Color(1, 1, 1, 0.05))
			draw_rect(box, Color(1, 1, 1, 0.25), false, 1.0)
			_text(box.position + Vector2(8, 2), g[0], tz("C"), TXT_DIM)
			for j in g[1].size():
				var t: int = g[1][j]
				var cr := Rect2(box.position + Vector2(8 + j * (cw + 4), 4 + tz("C") * 1.2), Vector2(cw, cardh))
				var on := RuleSet.has(int(lobby_r.pool[tm]), t)
				var can := RuleSet.has(sel, t)
				_btn(cr, "", _lobby_toggle_unit.bind(tm, t), true, false, Color(0.22, 0.38, 0.3) if on else Color(0.16, 0.16, 0.2))
				if _brief_hot(cr):
					brief_hot = t
				if on:
					brief_list.append(t)
				var fit_f := _filter_hit(t)
				_unit_in(cr, t, 0, (1.0 if (on and can) else 0.3) * (1.0 if fit_f else 0.35), 0.6)
				if not can:
					call("_lock_icon", cr.position + Vector2(cw - 12, 12))
				elif on:
					draw_rect(cr, Color("#7ddc8a"), false, 2.0)
			y += box.size.y + 8
	# V9：牌組：隨機 10 張、存 3 組
	var by2: float = R.end.y - 52.0
	_btn(Rect2(R.position.x, by2, 130, 44), L.t("lb_deck_random"), _deck_random)
	_btn(Rect2(R.position.x + 138, by2, 130, 44), L.t("lb_deck_save"), _deck_save)
	var decks: Array = Save.data.get("decks", [])
	for di in 3:
		var has_d: bool = di < decks.size()
		_btn(Rect2(R.position.x + 276 + di * 104, by2, 96, 44), L.t("lb_deck_n", [di + 1]), _deck_load.bind(di), has_d)
	if brief_list.is_empty():
		brief_list = RuleSet.types_of(sel)
	lobby_brief = _brief_pick(brief_list, brief_hot)
	var brief_r := Rect2(R.position.x, y + 2, R.size.x, by2 - y - 10)
	if brief_r.size.y >= 60.0:
		_unit_brief(brief_r, lobby_brief, not RuleSet.has(sel, lobby_brief))

func _draw_lab_tab(R: Rect2) -> void:
	# 沙盒（第五輪 R3）：選兵種 → 調血量／攻擊／速度倍率；技能開關
	var lab_types: Array = RuleSet.types_of(int(lobby_r.pool[0]) | int(lobby_r.pool[1]))
	if not lobby_sb_unit in lab_types and not lab_types.is_empty():
		lobby_sb_unit = lab_types[0]
	var lab_cols := 10
	var lab_h := 68 if lab_types.size() <= lab_cols else 46
	for lj in lab_types.size():
		var t: int = lab_types[lj]
		# 第八輪：兩邊名單不同時聯集最多 20 種，一排放不下就換第二排
		var cr := Rect2(R.position + Vector2((lj % lab_cols) * 58, (lj / lab_cols) * lab_h), Vector2(54, lab_h - 4))
		_btn(cr, "", func(): lobby_sb_unit = t, true, false, TH_ACTIVE if t == lobby_sb_unit else Color(0.16, 0.16, 0.2))
		_unit_in(cr, t, 0, 1.0, 0.55)
		if lobby_r.stat_pct.has(t):
			draw_circle(cr.position + Vector2(48, 8), 5, Color("#a46be0"))
	var cur: Array = lobby_r.stat_pct.get(lobby_sb_unit, [100, 100, 100])
	var y := R.position.y + (80 if lab_types.size() <= lab_cols else 100)
	for k in 3:
		_text(Vector2(R.position.x, y + 14), L.t(["lb_hp", "lb_atk", "lb_spd"][k]), tz("B"), Color.WHITE, false, false, 200)
		_btn(Rect2(R.position.x + 230, y, 52, 48), "◀", _lobby_sb_adj.bind(k, -1))
		_btn(Rect2(R.position.x + 288, y, 190, 48), "%d%%" % int(cur[k]), _lobby_sb_adj.bind(k, 1), true, false, TH_WOOD_D)
		_btn(Rect2(R.position.x + 484, y, 52, 48), "▶", _lobby_sb_adj.bind(k, 1))
		y += 56
	_text(Vector2(R.position.x, y + 4), L.t("lb_skills"), tz("S"), TXT_DIM)
	y += 30
	# 第八輪：只列這局用得到的技能，不然 22 顆放不下
	var skill_list := _lab_skills(lab_types)
	for i in skill_list.size():
		var s: String = skill_list[i]
		var off: bool = s in lobby_r.skills_off
		_btn(Rect2(R.position.x + (i % 4) * 148, y + (i / 4) * 44, 140, 38), ("× " if off else "✓ ") + L.t("sk_" + s), _lobby_sb_skill.bind(s), true, false,
			Color(0.35, 0.18, 0.2) if off else Color(0.16, 0.26, 0.2))
	if mouse.y > R.position.y and mouse.y < R.end.y and mouse.x > R.position.x and mouse.x < R.end.x:
		lobby_item = "lab"

func _lab_skills(types: Array) -> Array:
	var owner := {"charge": [3], "taunt": [1], "backstab": [4], "counter": [0], "stealth": [4], "brace": [1, 5], "splash": [6], "heal": [7], "drum": [8], "breach": [9],
		"poison": [10], "blast": [11], "bite": [12], "split": [13], "ghost": [14], "voodoo": [15], "timestop": [16], "raise": [17], "vacuum": [18], "stomp": [19]}
	var out: Array = []
	for s in RuleSet.SKILLS + RuleSet.F8.SKILLS:
		if not owner.has(s):
			out.append(s)
			continue
		for t in owner[s]:
			if t in types:
				out.append(s)
				break
	return out

func _draw_lobby_desc(R: Rect2) -> void:
	var x := R.position.x + 16
	var w := R.size.x - 32
	var y := R.position.y + 14
	var id: String = lobby_item if lobby_item != "" else ["budget", "deploy", "pool", "ticks", "ai_level", "lab", "cmd_on"][lobby_tab]
	_text(Vector2(x, y), L.t("lbd_t_" + id), tz("H2"), ACCENT, false, true, w)
	y += tz("H2") * 1.6
	var body := L.t("lbd_" + id)
	var bfs := tz("S") if _scale_key() == 100 else tz("C")   # 大字時說明改用註記字級，讓下面的差異清單放得下
	# 先估警告＋差異清單要多高；說明＋清單放不下時省略說明，只留警告與差異（Antigravity 實作第 2 輪）
	var need_h := tz("S") * 2.4 + _lobby_notes_h(w)
	var avail := R.end.y - 60 - y
	if text_h(body, bfs, w) + 12 + need_h <= avail:
		_text(Vector2(x, y), body, bfs, Color(1, 1, 1, 0.88), false, false, w)
		y += text_h(body, bfs, w) + 12
	_badge_pill(Vector2(x, y), Presets.badge(lobby_r, lobby_kind))
	y += tz("S") * 2.4
	_draw_lobby_notes(Rect2(x, y, w, R.end.y - y - 60))
	_btn(Rect2(x, R.end.y - 54, 200, 44), L.t("lb_reset"), func(): _lobby_pick("standard"))


## V1.2 C1：選中的預設像夾在筆記本上的書籤，從分頁底下垂進紙頁（紙頁畫完才畫，才不會被蓋住）。
func _draw_bookmark() -> void:
	var i := Presets.IDS.find(lobby_r.preset)
	# V1.2.1 B7：沒選中的預設也有一小段書籤耳（較短、較暗），選中的那條長而亮
	for j in Presets.IDS.size():
		if j == i:
			continue
		var rj := Rect2(Vector2(80, 96) + Vector2(j * (154.0 + 10.0), 0), Vector2(154, 68))
		var ex := rj.end.x - 30.0
		draw_colored_polygon(PackedVector2Array([Vector2(ex, rj.end.y - 4), Vector2(ex + 14, rj.end.y - 4), Vector2(ex + 14, rj.end.y + 9), Vector2(ex + 7, rj.end.y + 5), Vector2(ex, rj.end.y + 9)]), Color("#6e3b25"))
	if i < 0:
		return
	var r := Rect2(Vector2(80, 96) + Vector2(i * (154.0 + 10.0), 0), Vector2(154, 68))   # 和 _draw_lobby_presets 同一套位置
	var bx := r.end.x - 34.0
	var by0 := r.end.y - 4.0
	var bl := 30.0
	draw_colored_polygon(PackedVector2Array([Vector2(bx + 2, by0 + 3), Vector2(bx + 22, by0 + 3), Vector2(bx + 22, by0 + bl + 3), Vector2(bx + 12, by0 + bl - 4), Vector2(bx + 2, by0 + bl + 3)]), Color(0, 0, 0, 0.3))
	draw_colored_polygon(PackedVector2Array([Vector2(bx, by0), Vector2(bx + 20, by0), Vector2(bx + 20, by0 + bl), Vector2(bx + 10, by0 + bl - 7), Vector2(bx, by0 + bl)]), Color("#b5441f"))
	draw_rect(Rect2(bx, by0, 20, 3), Color(0, 0, 0, 0.25))
	draw_line(Vector2(bx + 4, by0 + 3), Vector2(bx + 4, by0 + bl - 3), Color(1, 0.85, 0.6, 0.4), 1.5)


## V1.4 #10：地圖說明（有機關的地圖把秒數從地圖資料帶進去，不寫死）。
static func map_desc(map_id: int) -> String:
	var mk: String = str(MapDefs.MAPS[map_id]["key"])
	var ev: Array = MapDefs.events(map_id)
	if ev.is_empty():
		return L.t("map_d_" + mk)
	var secs: Array = []
	for e in ev:
		var sec := int(e["t"]) / 20
		if not secs.has(sec):
			secs.append(sec)
	match mk:
		"quarry":
			return L.t("map_d_quarry", [secs[0]])
		"beacon":
			return L.t("map_d_beacon", [secs[0], secs[1], int(ev[0]["d"]) / 20])
		"plates":
			return L.t("map_d_plates", [secs[0], secs[1]])
	return L.t("map_d_" + mk)

