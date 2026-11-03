extends "res://scripts/ui/replay_view.gd"
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
var lobby_sb_unit := 0         # 沙盒分頁正在調的兵種

const LOBBY_TABS := ["lb_tab_army", "lb_tab_pool", "lb_tab_match", "lb_tab_ai", "lb_tab_lab"]

func _lobby_unlocked() -> int:
	return RuleSet.prefix_pool(RS.unlocked_count(_unlock_games(), OS.has_feature("demo")))

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
	Presets.clamp_pool(lobby_r, lobby_kind, _lobby_unlocked(), OS.has_feature("demo"))

func _lobby_pick(id: String) -> void:
	var keep_level: int = lobby_r.ai_level
	var keep_place: String = lobby_r.place_rule
	lobby_r = Presets.make(id, lobby_kind, Presets.selectable(lobby_kind, _lobby_unlocked(), OS.has_feature("demo")))
	lobby_r.ai_level = keep_level
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
	var sel := Presets.selectable(lobby_kind, _lobby_unlocked(), OS.has_feature("demo"))
	var out: Array = []
	for tm in 2:
		for t in D.COUNT:
			if RuleSet.has(lobby_r.pool_of(tm), t) and not RuleSet.has(sel, t) and not t in out:
				out.append(t)
	return out

func _lobby_block() -> String:
	var bad: Array = lobby_r.validate()
	if not bad.is_empty():
		return L.t(bad[0])
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
	Save.data["last_rules"] = lr
	Save.save_data()
	rules = lobby_r.copy()
	call("_start_mode", Mode.VS_AI if lobby_kind == "ai" else Mode.DUEL)

func _lobby_copy_code() -> void:
	DisplayServer.clipboard_set(lobby_r.to_code())
	_toast(L.t("lb_code_copied"))

func _lobby_paste_code() -> void:
	var d: Dictionary = RuleSet.from_code(DisplayServer.clipboard_get())
	if not d["ok"]:
		_toast(L.t(d["why"]) if d["why"].begins_with("rr_") else L.t("lb_code_bad"), true)
		return
	lobby_r = d["rules"]
	if not _lobby_locked_units().is_empty():
		_toast(_lobby_block(), true)   # 照原樣保留，開戰鈕會灰掉並寫原因
	else:
		_toast(L.t("lb_code_loaded"))

func _lobby_save_preset() -> void:
	var ps: Array = Save.data.get("rule_presets", [])
	if ps.size() >= Save.MAX_PRESETS:
		ps.pop_front()
	var nm := L.t("lb_my_n", [ps.size() + 1])
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

func _lobby_adj(id: String, d: int) -> void:
	var r = lobby_r
	lobby_item = id
	match id:
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
			r.ai_level = clampi(r.ai_level + d, 0, 2)
		"keep":
			r.keep_formation = not r.keep_formation
		"ai_pool_same":
			r.ai_pool_same = not r.ai_pool_same
			if not r.ai_pool_same:
				r.pool[1] = r.pool[0]
	_lobby_touch()

func _lobby_toggle_unit(team: int, t: int) -> void:
	lobby_item = "pool"
	var sel := Presets.selectable(lobby_kind, _lobby_unlocked(), OS.has_feature("demo"))
	if not RuleSet.has(sel, t):
		_toast(L.t("lb_locked_unit"), true)
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
	_text(Vector2(640, 44), title, tz("H1"), Color.WHITE, true, true)
	_draw_lobby_presets(Vector2(80, 100))
	if lobby_open:
		_draw_lobby_detail(Rect2(80, 214, 1120, 470))
	else:
		_draw_lobby_compact(Rect2(80, 214, 1120, 470))
	# 底列
	var by := 700.0
	_btn(Rect2(80, by, 150, 48), L.t("back"), func(): overlay = "")
	_btn(Rect2(244, by, 220, 48), L.t("lb_collapse") if lobby_open else L.t("lb_expand"), func(): lobby_open = not lobby_open)
	if lobby_open:
		_btn(Rect2(478, by, 150, 48), L.t("lb_copy"), _lobby_copy_code)
		_btn(Rect2(640, by, 150, 48), L.t("lb_paste"), _lobby_paste_code)
		_btn(Rect2(802, by, 150, 48), L.t("lb_save"), _lobby_save_preset)
	var why := _lobby_block()
	_btn(Rect2(966, by, 234, 48), L.t("lb_start"), _lobby_start, why == "", true)
	if why != "":
		_text(Vector2(1083, by - tz("C") * 1.5), why, tz("C"), Color("#ff8a8a"), true, true, 460)
	if lobby_menu:
		_draw_lobby_menu(Vector2(1000, 186))

func _draw_lobby_presets(o: Vector2) -> void:
	var w := 154.0
	var h := 96.0
	for i in Presets.IDS.size():
		var id: String = Presets.IDS[i]
		var p = Presets.make(id, lobby_kind, _lobby_unlocked())
		Presets.clamp_pool(p, lobby_kind, _lobby_unlocked(), OS.has_feature("demo"))
		var r := Rect2(o + Vector2(i * (w + 10), 0), Vector2(w, h))
		var on: bool = lobby_r.preset == id
		_btn(r, "", _lobby_pick.bind(id), true, false, Color(0.26, 0.33, 0.5) if on else Color(0.17, 0.19, 0.27))
		if on:
			draw_rect(r, ACCENT, false, 3.0)
		_text(r.position + Vector2(w / 2, 8), L.t("lb_p_" + id), tz("B"), Color.WHITE, true, true, w - 12)
		var sub_y := 8 + text_h(L.t("lb_p_" + id), tz("B"), w - 12, true) + 2
		if sub_y + text_h(L.t("lb_pd_" + id), tz("C"), w - 12) <= h - 14:
			_text(r.position + Vector2(w / 2, sub_y), L.t("lb_pd_" + id), tz("C"), Color(1, 1, 1, 0.75), true, false, w - 12)   # 放不下（大字）就不畫副標，不壓到色條
		var b := Presets.badge(p, lobby_kind)
		var bc: Color = {"cert": Color("#3fbf6a"), "fun": Color("#e8b33a"), "lab": Color("#a46be0")}[b]
		draw_rect(Rect2(r.position + Vector2(8, h - 12), Vector2(w - 16, 4)), bc)
	var mr := Rect2(o + Vector2(6 * (w + 10), 0), Vector2(1120 - 6 * (w + 10), h))
	_btn(mr, L.t("lb_mine"), func(): lobby_menu = not lobby_menu, true, false, Color(0.26, 0.33, 0.5) if lobby_r.preset == "custom" else Color(0.17, 0.19, 0.27))

func _draw_lobby_menu(o: Vector2) -> void:
	var ps: Array = Save.data.get("rule_presets", [])
	var n: int = maxi(1, ps.size())
	var r := Rect2(o, Vector2(220, 12 + n * 50))
	draw_rect(r, PANEL)
	draw_rect(r, Color(1, 1, 1, 0.3), false, 1.5)
	if ps.is_empty():
		_text(r.position + Vector2(110, 18), L.t("lb_mine_empty"), tz("S"), Color(1, 1, 1, 0.7), true, false, 200)
		return
	for i in ps.size():
		_btn(Rect2(r.position + Vector2(6, 6 + i * 50), Vector2(160, 44)), str(ps[i]["name"]), _lobby_load_preset.bind(i))
		_btn(Rect2(r.position + Vector2(170, 6 + i * 50), Vector2(44, 44)), "×", _lobby_delete_preset.bind(i))

## 精簡模式：一張規則摘要卡＋卡池頭像＋一個最常調的選項＋提示。
func _draw_lobby_compact(R: Rect2) -> void:
	draw_rect(R, Color(0, 0, 0, 0.22))
	var y := R.position.y + 20
	_text(Vector2(R.position.x + 24, y), _summary(lobby_r), tz("H2"), Color.WHITE, false, true, 760)
	_badge_pill(Vector2(R.end.x - 230, y), Presets.badge(lobby_r, lobby_kind))
	y += 60
	_text(Vector2(R.position.x + 24, y), L.t("lb_pool_now"), tz("S"), Color(1, 1, 1, 0.7))
	_draw_pool_heads(Vector2(R.position.x + 24, y + 28), lobby_r.pool_of(0), 58.0)
	if lobby_kind == "ai" and not lobby_r.ai_pool_same:
		_text(Vector2(R.position.x + 24, y + 104), L.t("lb_ai_pool"), tz("S"), Color(1, 1, 1, 0.7))
		_draw_pool_heads(Vector2(R.position.x + 24, y + 132), lobby_r.pool_of(1), 58.0)
	# 右側：最常調的一個選項（對 AI＝難度；雙人＝落子方式）
	var ox := R.end.x - 420
	var oy := R.position.y + 110
	var sy := oy + tz("B") * 1.6
	if lobby_kind == "ai":
		_text(Vector2(ox, oy), L.t("lb_ai_level"), tz("B"), Color(1, 1, 1, 0.8))
		_stepper(Rect2(ox, sy, 380, 64), L.t(["diff_easy", "diff_normal", "diff_hard"][lobby_r.ai_level]), "ai_level")
	else:
		_text(Vector2(ox, oy), L.t("lb_place_rule"), tz("B"), Color(1, 1, 1, 0.8))
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
		_text(Vector2(R.position.x, y), L.t("lb_diff_n", [df.size()]), tz("S"), Color(1, 1, 1, 0.8), false, true, R.size.x)
		y += tz("S") * 1.4
		var fs := tz("S")
		var left := R.end.y - y - tz("S") * 0.6   # 留一點邊，最後一行不碰到下面的重置鈕
		var list_h := 0.0
		for d in df:
			list_h += text_h("・" + _diff_text(d), fs, R.size.x - 10)
		if list_h <= left:
			for d in df:
				var ln := "・" + _diff_text(d)
				_text(Vector2(R.position.x + 10, y), ln, fs, Color(1, 1, 1, 0.7), false, false, R.size.x - 10)
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
				_text(Vector2(R.position.x, y), para, fs, Color(1, 1, 1, 0.7), false, false, R.size.x)

func _diff_text(d: Array) -> String:
	var k: String = d[0]
	match k:
		"rr_pool", "rr_ai_pool":
			return L.t(k + "_d", [d[1], d[2]])
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
	for t in D.COUNT:
		var on := RuleSet.has(p, t)
		var c := o + Vector2(t * step + step / 2, step * 0.9)
		draw_circle(c - Vector2(0, step * 0.35), step * 0.42, Color(1, 1, 1, 0.10 if on else 0.03))
		Art.unit(self, c, t, 0, 1.0, 0.0, 0.0, 0.0, 1.0 if on else 0.22, time, 0.55, cbm())

## ◀ 值 ▶ 的調整列；點兩側箭頭，也可以點中間（往下一個）。
func _stepper(r: Rect2, value: String, id: String) -> void:
	_btn(Rect2(r.position, Vector2(52, r.size.y)), "◀", _lobby_adj.bind(id, -1))
	_btn(Rect2(r.position + Vector2(58, 0), Vector2(r.size.x - 116, r.size.y)), value, _lobby_adj.bind(id, 1), true, false, Color(0.13, 0.15, 0.22))
	_btn(Rect2(r.end.x - 52, r.position.y, 52, r.size.y), "▶", _lobby_adj.bind(id, 1))
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
			Color(0.26, 0.33, 0.5) if idx == lobby_tab else Color(0, 0, 0, 0))
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
			_draw_pool_tab(L0)
		2:
			var rows2: Array = [["ticks", L.t("lb_time"), L.t("lb_n_secs", [_secs(lobby_r.ticks)])], ["rounds", L.t("lb_rounds"), _rounds_text(lobby_r.rounds)]]
			if lobby_kind == "duel":
				rows2.append(["place_rule", L.t("lb_place_rule"), _place_text(lobby_r.place_rule)])
				if lobby_r.place_rule == "custom":
					rows2.append(["turns", L.t("lb_turns"), L.t("lb_n_turns", [lobby_r.turns])])
				if lobby_r.place_rule != "blind":
					rows2.append(["carry", L.t("lb_carry"), L.t("on") if lobby_r.carry else L.t("off")])
			rows2.append(["keep", L.t("lb_keep"), L.t("on") if lobby_r.keep_formation else L.t("off")])
			_rows(L0, rows2)
		3:
			_rows(L0, [["ai_level", L.t("lb_ai_level"), L.t(["diff_easy", "diff_normal", "diff_hard"][lobby_r.ai_level])],
				["ai_pool_same", L.t("lb_ai_pool_same"), L.t("on") if lobby_r.ai_pool_same else L.t("off")]])
		4:
			_draw_lab_tab(L0)
	_draw_lobby_desc(D0)

func _rows(R: Rect2, rows: Array) -> void:
	for i in rows.size():
		var y := R.position.y + i * 66
		_text(Vector2(R.position.x, y + 14), rows[i][1], tz("B"), Color.WHITE, false, false, 220)
		_stepper(Rect2(R.position.x + 230, y, 360, 52), rows[i][2], rows[i][0])

func _draw_pool_tab(R: Rect2) -> void:
	var teams := [0] if lobby_r.ai_pool_same else [0, 1]
	var y := R.position.y
	var sel := Presets.selectable(lobby_kind, _lobby_unlocked(), OS.has_feature("demo"))
	for tm in teams:
		if teams.size() > 1:
			var pl: String = (L.t("lb_your_pool") if tm == 0 else L.t("lb_ai_pool")) if lobby_kind == "ai" else (L.t("lb_blue_pool") if tm == 0 else L.t("lb_red_pool"))
			_text(Vector2(R.position.x, y), pl, tz("S"), Color(1, 1, 1, 0.7))
			y += tz("S") * 1.5
		# 戰鬥兵、支援兵分框（第五輪 §3.6）
		var groups := [[L.t("lb_combat"), [0, 1, 2, 3, 4, 5, 6, 9]], [L.t("lb_support"), [7, 8]]]
		var x := R.position.x
		for g in groups:
			var cw := 52.0
			var gw: float = g[1].size() * (cw + 4) + 12
			var box := Rect2(x, y, gw, 108)
			draw_rect(box, Color(1, 1, 1, 0.05))
			draw_rect(box, Color(1, 1, 1, 0.25), false, 1.0)
			_text(box.position + Vector2(8, 4), g[0], tz("C"), Color(1, 1, 1, 0.7))
			for j in g[1].size():
				var t: int = g[1][j]
				var cr := Rect2(box.position + Vector2(8 + j * (cw + 4), 26), Vector2(cw, 76))
				var on := RuleSet.has(int(lobby_r.pool[tm]), t)
				var can := RuleSet.has(sel, t)
				_btn(cr, "", _lobby_toggle_unit.bind(tm, t), true, false, Color(0.22, 0.38, 0.3) if on else Color(0.16, 0.16, 0.2))
				Art.unit(self, cr.position + Vector2(cw / 2, 66), t, 0, 1.0, 0.0, 0.0, 0.0, 1.0 if (on and can) else 0.3, time, 0.5, cbm())
				if not can:
					call("_lock_icon", cr.position + Vector2(cw - 12, 12))
				elif on:
					draw_rect(cr, Color("#7ddc8a"), false, 2.0)
			x += gw + 14
		y += 124
	if lobby_kind == "ai":
		_text(Vector2(R.position.x, y + 4), L.t("lb_unlock_hint"), tz("S"), Color(1, 1, 1, 0.6), false, false, R.size.x)

func _draw_lab_tab(R: Rect2) -> void:
	# 沙盒（第五輪 R3）：選兵種 → 調血量／攻擊／速度倍率；技能開關
	for t in D.COUNT:
		var cr := Rect2(R.position + Vector2(t * 60, 0), Vector2(56, 64))
		_btn(cr, "", func(): lobby_sb_unit = t, true, false, Color(0.26, 0.33, 0.5) if t == lobby_sb_unit else Color(0.16, 0.16, 0.2))
		Art.unit(self, cr.position + Vector2(28, 58), t, 0, 1.0, 0.0, 0.0, 0.0, 1.0, time, 0.5, cbm())
		if lobby_r.stat_pct.has(t):
			draw_circle(cr.position + Vector2(48, 8), 5, Color("#a46be0"))
	var cur: Array = lobby_r.stat_pct.get(lobby_sb_unit, [100, 100, 100])
	var y := R.position.y + 80
	for k in 3:
		_text(Vector2(R.position.x, y + 14), L.t(["lb_hp", "lb_atk", "lb_spd"][k]), tz("B"), Color.WHITE, false, false, 200)
		_btn(Rect2(R.position.x + 230, y, 52, 48), "◀", _lobby_sb_adj.bind(k, -1))
		_btn(Rect2(R.position.x + 288, y, 190, 48), "%d%%" % int(cur[k]), _lobby_sb_adj.bind(k, 1), true, false, Color(0.13, 0.15, 0.22))
		_btn(Rect2(R.position.x + 484, y, 52, 48), "▶", _lobby_sb_adj.bind(k, 1))
		y += 56
	_text(Vector2(R.position.x, y + 4), L.t("lb_skills"), tz("S"), Color(1, 1, 1, 0.7))
	y += 30
	for i in RuleSet.SKILLS.size():
		var s: String = RuleSet.SKILLS[i]
		var off: bool = s in lobby_r.skills_off
		_btn(Rect2(R.position.x + (i % 4) * 148, y + (i / 4) * 44, 140, 38), ("× " if off else "✓ ") + L.t("sk_" + s), _lobby_sb_skill.bind(s), true, false,
			Color(0.35, 0.18, 0.2) if off else Color(0.16, 0.26, 0.2))
	if mouse.y > R.position.y and mouse.y < R.end.y and mouse.x > R.position.x and mouse.x < R.end.x:
		lobby_item = "lab"

func _draw_lobby_desc(R: Rect2) -> void:
	var x := R.position.x + 16
	var w := R.size.x - 32
	var y := R.position.y + 14
	var id: String = lobby_item if lobby_item != "" else ["budget", "pool", "ticks", "ai_level", "lab"][lobby_tab]
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
