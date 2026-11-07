extends "res://scripts/ui/replay_view.gd"
## V1.1 E3：由 lobby_view.gd 拆出（行為不變）。選卡時的兵種簡介卡：大廳卡池、雙人禁牌共用。
## 指到哪張（滑鼠或手把焦點）就講哪隻：頭像、金幣、定位、一句話、剋與怕、四條比較條。

# ── 選卡時的兵種簡介：指到哪張（滑鼠或手把焦點）就講哪隻 ──
var lobby_brief := -1

## 四條比較條，0～1，以全部兵種的最大值為滿：血量、每秒攻擊、射程、速度。
func _brief_stats(t: int) -> Array:
	var mx := [1.0, 1.0, 1.0, 1.0]
	for i in D.total():
		var v: Array = _brief_raw(i)
		for k in 4:
			mx[k] = maxf(mx[k], v[k])
	var cur: Array = _brief_raw(t)
	var out: Array = []
	for k2 in 4:
		out.append(cur[k2] / mx[k2])
	return out

func _brief_raw(t: int) -> Array:
	var st: Dictionary = D.stat(t)
	return [float(st["hp"]), float(st["atk"]) * 20.0 / maxf(1.0, float(st["cd"])), float(st["reach"]), float(st["speed"])]

func _brief_role(t: int) -> String:
	return load("res://scripts/game/codex.gd").text(load("res://scripts/game/codex.gd").unit(t), "role", L.lang)

## 剋誰、怕誰（支援兵左邊改成協同）。試玩版不露正式版的兵。
func _brief_matchups(t: int) -> Dictionary:
	var mask: int = RS.mask(true) if _demo() else RuleSet.full_pool()
	var good: Array = []
	var bad: Array = []
	for o in D.total():
		if not RuleSet.has(mask, o) or o == t:
			continue
		var sc: int = AIT.counter_score(t, o)
		if sc > 0:
			good.append(o)
		elif sc < 0:
			bad.append(o)
	if D.is_support(t):
		good = AIT.SYNERGY.get(t, []).filter(func(o): return RuleSet.has(mask, o))
	return {"good": good, "bad": bad}

## 這一幀要講哪一隻：指到的 > 上一次指到的（還在清單裡）> 清單第一張。
func _brief_pick(list: Array, hot: int) -> int:
	if hot >= 0:
		return hot
	if lobby_brief in list:
		return lobby_brief
	return int(list[0]) if not list.is_empty() else -1

## 按鈕剛畫完時呼叫：這顆是否被滑鼠指到或手把焦點在上面。
func _brief_hot(r: Rect2) -> bool:
	return (r.has_point(mouse) and not pad_mode) or (pad_mode and _btns.size() - 1 == _focus)

func _unit_brief(r: Rect2, t: int, locked := false) -> void:
	if t < 0:
		return
	var pw := 92.0
	var x := r.position.x + pw + 8
	var w := r.size.x - pw - 18
	var name_s: String = L.t("unit_%d" % t)
	var x2 := x + minf(_width(name_s, tz("B"), true), w * 0.5) + 12
	var meta: String = L.t("gold", [D.cost(t)]) + "・" + (L.t("lb_locked_tag") if locked else _brief_role(t))
	var blurb: String = L.t("blurb_%d" % t)
	var head_h: float = maxf(tz("B") * 1.35, text_h(meta, tz("S"), r.end.x - x2 - 8) + 2)
	var blurb_h: float = text_h(blurb, tz("S"), w) + 6
	# 由上往下排，高度不夠時先拿掉比較條，再拿掉剋制（字級不縮）；框只包到內容
	var bar_h: float = tz("C") * 1.2 + 10
	var mu_h := 36.0
	var room: float = r.size.y - 12 - head_h - blurb_h
	var show_mu: bool = room >= mu_h
	var show_bar: bool = room >= mu_h + bar_h
	var h: float = 12 + head_h + blurb_h + (mu_h if show_mu else 0.0) + (bar_h if show_bar else 0.0)
	h = maxf(h, minf(r.size.y, 100.0))
	var box := Rect2(r.position, Vector2(r.size.x, h))
	_box(box, Color(0, 0, 0, 0.28), Color(1, 1, 1, 0.22), 8.0, 1.0)
	var cy: float = r.position.y + h / 2
	draw_circle(Vector2(r.position.x + pw / 2 + 2, cy), minf(40.0, h / 2 - 4), Color(1, 1, 1, 0.07))
	_unit_in(Rect2(r.position.x + 2, cy - 50, pw, 100), t, 0, 0.45 if locked else 1.0, 0.95)
	var y := r.position.y + 6
	_text(Vector2(x, y), name_s, tz("B"), ACCENT, false, true, w * 0.5)
	_text(Vector2(x2, y + (tz("B") - tz("S")) * 0.5), meta, tz("S"), TXT_DIM, false, false, r.end.x - x2 - 8)
	y += head_h
	_text(Vector2(x, y), blurb, tz("S"), Color.WHITE, false, false, w)
	y += blurb_h
	if show_mu:
		_brief_mu(Vector2(x, y), w, t)
		y += mu_h
	if show_bar:
		_brief_bars(Rect2(x, y, w, bar_h), t)

func _brief_bars(r: Rect2, t: int) -> void:
	var st: Array = _brief_stats(t)
	var cw: float = r.size.x / 4.0
	for k in 4:
		var cx: float = r.position.x + k * cw
		_text(Vector2(cx, r.position.y), L.t(["ub_hp", "ub_atk", "ub_range", "ub_spd"][k]), tz("C"), TXT_DIM, false, false, cw - 8)
		_seg_bar(Rect2(cx, r.end.y - 9, cw - 12, 8), float(st[k]), ACCENT)   # V1.2 C2：刻印格條

func _brief_mu(p: Vector2, w: float, t: int) -> void:
	var m: Dictionary = _brief_matchups(t)
	var x := p.x
	var groups := [[L.t("synergy") if D.is_support(t) else L.t("beats"), m["good"], Color("#4ade80")], [L.t("fears"), m["bad"], Color("#f87171")]]
	for g in groups:
		if g[1].is_empty():
			continue
		_text(Vector2(x, p.y + 6), g[0], tz("S"), g[2], false, true, 80)
		x += minf(_width(g[0], tz("S"), true), 80.0) + 6
		for o in g[1]:
			if x + 34 > p.x + w:
				break
			_unit_in(Rect2(x, p.y, 34, 34), o, 1, 1.0, 0.5)
			x += 34
		x += 24   # V1.2.1：兩組（剋／怕）之間拉開，英文 150% 不會看起來黏在一起
