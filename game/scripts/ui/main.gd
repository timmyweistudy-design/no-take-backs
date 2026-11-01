extends Node2D
## 《落子無悔》火柴人原型：擺放 → 開戰 → 結果。全部用程式畫，沒有任何美術素材。
## 戰鬥結果完全由 scripts/core/battle_sim.gd 決定；這裡只負責演出（插值、特效、慢動作），不影響勝負。

const D = preload("res://scripts/core/unit_defs.gd")
const Army = preload("res://scripts/core/army.gd")
const Sim = preload("res://scripts/core/battle_sim.gd")
const AI = preload("res://scripts/core/ai_army.gd")
const TP = preload("res://scripts/core/turn_placement.gd")

enum St { PLACE, BATTLE, RESULT }
enum Mode { VS_AI, TURNS }

const ORIGIN := Vector2(128, 100)
const CS := 64.0
const FIELD := Vector2(16 * 64, 9 * 64)
const TEAM_COL := [Color("#38B6FF"), Color("#FF5252")]
const TEAM_NAME := ["藍方", "紅方"]
const OUTLINE := Color("#14141f")
const CARD_Y := 694.0
const CARD_W := 140.0
const CARD_H := 96.0

var font: Font
var state := St.PLACE
var mode := Mode.VS_AI
var armies: Array = []
var tp = null
var ai_name := ""
var rng := RandomNumberGenerator.new()
var selected := D.SWORD
var hover_card := -1
var drag_new := false
var drag_from := Vector2i(-1, -1)
var painting := false
var paint_team := 0
var series_over := false
var mouse := Vector2.ZERO
var toast := ""
var toast_t := 0.0
var wins := [0, 0]
var round_no := 1
var last_armies: Array = []

# 戰鬥演出
var sim = null
var prev_pos := {}
var accum := 0.0
var speed := 1.0
var slow_used := false
var slow_left := 0.0
var zoom := 1.0
var zoom_center := ORIGIN + FIELD / 2
var shake := 0.0
var fx: Array = []
var atk_t := {}
var dying: Array = []
var result_delay := 0.0
var time := 0.0
var shot_dir := ""

var buttons := {}
var ui: CanvasLayer

func _ready() -> void:
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Microsoft JhengHei UI", "Microsoft JhengHei", "Noto Sans CJK TC", "Noto Sans TC", "Noto Sans CJK SC", "sans-serif"])
	font = sf
	var theme := Theme.new()
	theme.default_font = sf
	theme.default_font_size = 18
	ui = CanvasLayer.new()
	add_child(ui)
	var root := Control.new()
	root.theme = theme
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.size = Vector2(1280, 800)
	ui.add_child(root)
	_btn(root, "start", "開戰！", Rect2(884, 690, 236, 50), _on_start)
	_btn(root, "clear", "清空", Rect2(1128, 690, 140, 50), _on_clear)
	_btn(root, "mode", "", Rect2(884, 746, 384, 44), _on_mode)
	_btn(root, "speed", "速度 1×", Rect2(884, 700, 180, 50), _on_speed)
	_btn(root, "skip", "直接看結果", Rect2(1076, 700, 192, 50), _on_skip)
	_btn(root, "again", "再來一局", Rect2(470, 520, 160, 50), _on_again)
	_btn(root, "replay", "重播", Rect2(650, 520, 160, 50), _on_replay)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot_dir = a.substr(7)
	rng.seed = Time.get_ticks_usec() if shot_dir == "" else 12345
	_reset_place()
	if shot_dir != "":
		_run_screenshots.call_deferred()

func _btn(root: Control, key: String, text: String, r: Rect2, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.position = r.position
	b.size = r.size
	b.pressed.connect(cb)
	b.focus_mode = Control.FOCUS_NONE
	root.add_child(b)
	buttons[key] = b

# ───────────────────────── 狀態切換 ─────────────────────────
func _reset_place(keep_blue := false) -> void:
	state = St.PLACE
	sim = null
	fx.clear()
	dying.clear()
	zoom = 1.0
	if not keep_blue or armies.is_empty():
		armies = [Army.new(0, 100), Army.new(1, 100)]
	else:
		armies[1] = Army.new(1, 100)
	tp = null
	if mode == Mode.TURNS:
		armies = [Army.new(0, 100), Army.new(1, 100)]
		tp = TP.new(armies[0], armies[1], (round_no + 1) % 2)
	_refresh_buttons()

func _refresh_buttons() -> void:
	var place := state == St.PLACE
	buttons["start"].visible = place
	buttons["clear"].visible = place and mode == Mode.VS_AI
	buttons["mode"].visible = place
	buttons["mode"].text = "模式：對 AI（點這裡換成兩人輪流落子）" if mode == Mode.VS_AI else "模式：兩人輪流落子（點這裡換成對 AI）"
	buttons["speed"].visible = state == St.BATTLE
	buttons["skip"].visible = state == St.BATTLE
	buttons["again"].visible = state == St.RESULT
	buttons["replay"].visible = state == St.RESULT
	if place and mode == Mode.TURNS:
		buttons["start"].text = "開戰！" if tp.done() else "結束這一手"
		buttons["start"].disabled = not (tp.done() or tp.can_end_turn())
	elif place:
		buttons["start"].text = "開戰！"
		buttons["start"].disabled = armies[0].count() == 0

func _on_start() -> void:
	if mode == Mode.TURNS and not tp.done():
		if not tp.end_turn():
			_toast("買得起就不能跳過，至少擺 1 隻")
		_refresh_buttons()
		return
	if armies[0].count() == 0:
		_toast("先擺兵！")
		return
	if mode == Mode.VS_AI:
		var r = AI.build(1, 100, rng)
		armies[1] = r["army"]
		ai_name = r["name"]
	_begin_battle(armies[0].copy(), armies[1].copy())

func _begin_battle(a0, a1) -> void:
	last_armies = [a0.copy(), a1.copy()]
	sim = Sim.new(a0, a1)
	state = St.BATTLE
	prev_pos.clear()
	for u in sim.units:
		prev_pos[u.id] = Vector2(u.x, u.y)
	accum = 0.0
	slow_used = false
	slow_left = 0.0
	zoom = 1.0
	fx.clear()
	dying.clear()
	atk_t.clear()
	result_delay = 0.0
	speed = 1.0
	buttons["speed"].text = "速度 1×"
	_refresh_buttons()

func _on_clear() -> void:
	armies[0].clear()
	_refresh_buttons()

func _on_mode() -> void:
	mode = Mode.TURNS if mode == Mode.VS_AI else Mode.VS_AI
	wins = [0, 0]
	round_no = 1
	_reset_place()

func _on_speed() -> void:
	speed = 2.0 if speed == 1.0 else (4.0 if speed == 2.0 else 1.0)
	buttons["speed"].text = "速度 %d×" % int(speed)

func _on_skip() -> void:
	while not sim.finished:
		_sim_step(false)
	result_delay = 0.0

func _on_again() -> void:
	if series_over:
		wins = [0, 0]
		round_no = 1
		series_over = false
		_reset_place(false)
		return
	round_no += 1
	_reset_place(true)

func _on_replay() -> void:
	var w: int = sim.winner
	if w >= 0:
		wins[w] -= 1   # 重播不重複計分
	series_over = false
	_begin_battle(last_armies[0].copy(), last_armies[1].copy())

func _toast(s: String) -> void:
	toast = s
	toast_t = 2.0

# ───────────────────────── 輸入 ─────────────────────────
func _cell_at(p: Vector2) -> Vector2i:
	var q := (p - ORIGIN) / CS
	if q.x < 0 or q.y < 0 or q.x >= 16 or q.y >= 9:
		return Vector2i(-1, -1)
	return Vector2i(int(q.x), int(q.y))

func _card_at(p: Vector2) -> int:
	for i in D.COUNT:
		if Rect2(128 + i * (CARD_W + 8), CARD_Y, CARD_W, CARD_H).has_point(p):
			return i
	return -1

func _cur_army():
	return tp.armies[tp.current] if mode == Mode.TURNS else armies[0]

func _try_place(c: Vector2i) -> void:
	var why: String
	if mode == Mode.TURNS:
		why = tp.check_place(selected, c.x, c.y)
		if why == "":
			tp.place(selected, c.x, c.y)
	else:
		why = armies[0].check_place(selected, c.x, c.y)
		if why == "":
			armies[0].place(selected, c.x, c.y)
	if why != "" and why != "這格已經有兵":
		_toast(why)
	_refresh_buttons()

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		mouse = ev.position
		hover_card = _card_at(mouse)
		if state == St.PLACE and painting and _cur_army().team != paint_team:
			painting = false   # 自動換手了，不能替對手落子
		if state == St.PLACE and painting:
			var c := _cell_at(mouse)
			if c.x >= 0 and _cur_army().index_at(c.x, c.y) == -1:
				_try_place(c)
	if state != St.PLACE or not (ev is InputEventMouseButton):
		return
	var mb := ev as InputEventMouseButton
	mouse = mb.position
	var c := _cell_at(mouse)
	if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		var k := _card_at(mouse)
		if k >= 0:
			selected = k
			drag_new = true
			return
		if c.x < 0:
			return
		if mode == Mode.VS_AI and armies[0].index_at(c.x, c.y) != -1:
			drag_from = c
		else:
			painting = true
			paint_team = _cur_army().team
			_try_place(c)
	elif mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
		if drag_new and c.x >= 0:
			_try_place(c)
		elif drag_from.x >= 0:
			if c.x < 0:
				armies[0].remove_at(drag_from.x, drag_from.y)
			elif c != drag_from and not armies[0].move(drag_from.x, drag_from.y, c.x, c.y):
				_toast("不能移到那裡")
		drag_new = false
		painting = false
		drag_from = Vector2i(-1, -1)
		_refresh_buttons()
	elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and c.x >= 0:
		if mode == Mode.VS_AI:
			armies[0].remove_at(c.x, c.y)
		else:
			_toast("落子無悔：擺下的兵不能收回")
		_refresh_buttons()

# ───────────────────────── 每幀 ─────────────────────────
func _process(delta: float) -> void:
	time += delta
	if toast_t > 0:
		toast_t -= delta
	shake = maxf(0.0, shake - delta)
	for f in fx:
		f["t"] += delta
	fx = fx.filter(func(f): return f["t"] < f["dur"])
	for g in dying:
		g["t"] += delta
	dying = dying.filter(func(g): return g["t"] < 1.4)
	if state == St.BATTLE and shot_dir == "":
		_battle_process(delta)
	queue_redraw()

func _battle_process(delta: float) -> void:
	var rate := speed
	if slow_left > 0:
		rate *= 0.5
		slow_left -= delta
	accum += delta * rate
	while accum >= 0.05 and not sim.finished:
		accum -= 0.05
		_sim_step(true)
	# 最後時刻：任一方剩 ≤3 隻 → 慢動作、鏡頭拉近（每局一次，最多多花 4 秒）
	var a0: int = sim.alive_count(0)
	var a1: int = sim.alive_count(1)
	if not slow_used and not sim.finished and (a0 <= 3 or a1 <= 3):
		slow_used = true
		slow_left = 8.0
		_fx_text(ORIGIN + FIELD / 2 - Vector2(0, 200), "最後時刻！", Color.GOLD, 1.6, 40)
	var target_zoom := 1.0
	if slow_left > 0 and not sim.finished:
		target_zoom = 1.3
		zoom_center = zoom_center.lerp(_alive_centroid(), delta * 3)
	zoom = lerpf(zoom, target_zoom, delta * 3)
	if sim.finished:
		result_delay += delta
		if result_delay > 1.2:
			_finish_battle()

func _sim_step(with_fx: bool) -> void:
	for u in sim.units:
		prev_pos[u.id] = Vector2(u.x, u.y)
	var was_frenzy: bool = sim.frenzy
	sim.step()
	if sim.frenzy and not was_frenzy and with_fx:
		_fx_text(ORIGIN + Vector2(FIELD.x / 2, 60), "狂熱！攻速提升、全場耗損", Color.ORANGE_RED, 2.0, 30)
	for ev in sim.events:
		_on_event(ev, with_fx)

func _on_event(ev: Dictionary, with_fx: bool) -> void:
	var k: String = ev["kind"]
	if k == "death":
		var u = sim.unit_by_id(ev["id"])
		dying.append({"pos": _upos(u), "type": u.type, "team": u.team, "face": signf(u.fx), "t": 0.0})
		return
	if k == "attrition" or not with_fx:
		return
	var s = sim.unit_by_id(ev["src"])
	var t = sim.unit_by_id(ev["tgt"])
	atk_t[s.id] = time
	var sp := _upos(s)
	var tpos := _upos(t)
	if k == "arrow" or k == "blocked":
		fx.append({"kind": "arrow", "a": sp + Vector2(0, -26), "b": tpos + Vector2(0, -22), "t": 0.0, "dur": 0.25})
	else:
		fx.append({"kind": "slash", "p": sp, "dir": signf(tpos.x - sp.x), "t": 0.0, "dur": 0.18, "team": s.team})
	var col := Color.WHITE
	var label := ""
	match k:
		"charge":
			label = "衝鋒！"
			col = Color.GOLD
			shake = 0.12
		"backstab":
			label = "背刺！"
			col = Color("#c77dff")
		"braced":
			label = "頂住！"
			col = Color("#9ad1ff")
		"breaker":
			label = "破盾"
			col = Color("#ffd166")
		"blocked":
			label = "擋"
			col = Color("#aaaaaa")
		"counter":
			label = "反擊"
			col = Color("#80ffdb")
	# 一般攻擊只有刀光，不跳數字（48 隻同時打會洗版）；特殊效果才跳字
	if label != "" and label != "破盾":
		_fx_text(tpos + Vector2(0, -52), "%s %d" % [label, ev["dmg"]], col, 0.8, 18)

func _fx_text(p: Vector2, s: String, c: Color, dur: float, size: int) -> void:
	fx.append({"kind": "text", "p": p, "s": s, "c": c, "t": 0.0, "dur": dur, "size": size})

func _finish_battle() -> void:
	state = St.RESULT
	if sim.winner >= 0:
		wins[sim.winner] += 1
	series_over = wins[0] >= 2 or wins[1] >= 2 or round_no >= 5
	buttons["again"].text = "新的一場" if series_over else "下一局"
	slow_left = 0
	_refresh_buttons()

func _alive_centroid() -> Vector2:
	var s := Vector2.ZERO
	var n := 0
	for u in sim.units:
		if u.alive:
			s += _upos(u)
			n += 1
	return s / n if n > 0 else ORIGIN + FIELD / 2

func _upos(u) -> Vector2:
	var cur := Vector2(u.x, u.y)
	var a := clampf(accum / 0.05, 0.0, 1.0) if state == St.BATTLE else 1.0
	var p: Vector2 = prev_pos.get(u.id, cur).lerp(cur, a)
	return ORIGIN + p * CS / 1000.0

# ───────────────────────── 繪圖 ─────────────────────────
func _draw() -> void:
	var cam := Transform2D.IDENTITY
	if state != St.PLACE:
		var off := Vector2.ZERO
		if shake > 0:
			off = Vector2(sin(time * 90) * 2, cos(time * 77) * 2)
		var c := zoom_center.lerp(ORIGIN + FIELD / 2, clampf((1.3 - zoom) / 0.3, 0, 1))
		# 鏡頭不能拉出戰場外
		var half := Vector2(640, 390) / zoom
		var lo := ORIGIN + half - Vector2(16, 16)
		var hi := ORIGIN + FIELD - half + Vector2(16, 16)
		c = Vector2(clampf(c.x, minf(lo.x, hi.x), maxf(lo.x, hi.x)), clampf(c.y, minf(lo.y, hi.y), maxf(lo.y, hi.y)))
		cam = Transform2D(0, Vector2(zoom, zoom), 0, Vector2(640, 390) - c * zoom + off)
	draw_set_transform_matrix(cam)
	_draw_field()
	if state == St.PLACE:
		_draw_place_units()
	else:
		_draw_battle_units()
	for f in fx:
		_draw_fx(f)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_draw_hud()

func _draw_field() -> void:
	draw_rect(Rect2(ORIGIN - Vector2(8, 8), FIELD + Vector2(16, 16)), Color("#3b2f24"))
	for r in 9:
		for c in 16:
			var base := Color("#7cb342") if (r + c) % 2 == 0 else Color("#73a83d")
			if c < 6:
				base = base.lerp(TEAM_COL[0], 0.10)
			elif c >= 10:
				base = base.lerp(TEAM_COL[1], 0.10)
			else:
				base = base.lightened(0.08)
			draw_rect(Rect2(ORIGIN + Vector2(c, r) * CS, Vector2(CS, CS)), base)
	draw_line(ORIGIN + Vector2(6 * CS, 0), ORIGIN + Vector2(6 * CS, FIELD.y), Color(1, 1, 1, 0.35), 2)
	draw_line(ORIGIN + Vector2(10 * CS, 0), ORIGIN + Vector2(10 * CS, FIELD.y), Color(1, 1, 1, 0.35), 2)
	if state == St.PLACE and mode == Mode.VS_AI:
		# AI 的陣型開戰前看不到
		draw_rect(Rect2(ORIGIN + Vector2(10 * CS, 0), Vector2(6 * CS, FIELD.y)), Color(0.1, 0.05, 0.05, 0.45))
		_text(ORIGIN + Vector2(13 * CS, FIELD.y / 2), "AI 的陣型\n開戰後揭曉", 22, Color(1, 1, 1, 0.8), true)

func _draw_place_units() -> void:
	var list: Array = []
	for a in armies:
		for u in a.units:
			if drag_from.x >= 0 and a.team == 0 and u["col"] == drag_from.x and u["row"] == drag_from.y:
				continue
			list.append([u["row"], u["col"], u["type"], a.team])
	list.sort()
	for it in list:
		var p := ORIGIN + Vector2(it[1] + 0.5, it[0] + 0.8) * CS
		_ring(p, it[3])
		_stick(p, it[2], it[3], 1.0 if it[3] == 0 else -1.0, time * 2 + it[1], 0.0, 1.0)
	# 拖曳預覽
	var c := _cell_at(mouse)
	var dragging_type := -1
	if drag_new:
		dragging_type = selected
	elif drag_from.x >= 0:
		dragging_type = armies[0].units[armies[0].index_at(drag_from.x, drag_from.y)]["type"]
	if dragging_type >= 0:
		_stick(mouse + Vector2(0, 20), dragging_type, _cur_army().team, 1.0, 0.0, 0.0, 0.7)
	if c.x >= 0:
		var okp: bool = _cur_army().check_place(selected, c.x, c.y) == ""
		draw_rect(Rect2(ORIGIN + Vector2(c) * CS, Vector2(CS, CS)), Color(1, 1, 1, 0.25) if okp else Color(1, 0.2, 0.2, 0.25))

func _draw_battle_units() -> void:
	var list: Array = []
	for u in sim.units:
		if u.alive:
			list.append([_upos(u).y, u])
	list.sort_custom(func(a, b): return a[0] < b[0])
	for it in list:
		var u = it[1]
		var p := _upos(u)
		var moving: bool = prev_pos.get(u.id, Vector2(u.x, u.y)).distance_to(Vector2(u.x, u.y)) > 1
		var at := 0.0
		if atk_t.has(u.id):
			at = clampf((time - atk_t[u.id]) / 0.25, 0, 1)
			if at >= 1:
				at = 0
		var alpha := 0.35 if u.stealth > 0 else 1.0
		_ring(p, u.team)
		var face := signf(u.fx) if u.fx != 0 else (1.0 if u.team == 0 else -1.0)
		_stick(p, u.type, u.team, face, (time * 10.0 + u.id) if moving else 0.0, at, alpha)
		if u.stun > 0:
			_text(p + Vector2(0, -58), "✦", 16, Color.YELLOW, true)
		if sim.frenzy:
			draw_circle(p + Vector2(0, -50 - sin(time * 12 + u.id) * 2), 3, Color(1, 0.5, 0.1, 0.9))
		if u.hp < u.max_hp:
			var w := 28.0
			var top := p + Vector2(-w / 2, -48)
			draw_rect(Rect2(top - Vector2(1, 1), Vector2(w + 2, 6)), OUTLINE)
			draw_rect(Rect2(top, Vector2(w * u.hp / u.max_hp, 4)), TEAM_COL[u.team].lightened(0.2))
	for g in dying:
		var k: float = g["t"] / 1.4
		if k < 0.3:
			_stick(g["pos"], g["type"], g["team"], g["face"], 0, 0, 1.0 - k / 0.3)
			for i in 5:
				var a := i * TAU / 5
				draw_circle(g["pos"] + Vector2(cos(a), sin(a) * 0.5) * (8 + k * 60) + Vector2(0, -14), 5 * (1 - k), Color(1, 1, 1, 0.6))
		var gp: Vector2 = g["pos"] + Vector2(sin(k * 9) * 4, -20 - k * 60)
		var ga := 0.7 * (1.0 - k)
		draw_circle(gp, 7, Color(0.85, 0.95, 1, ga))
		draw_circle(gp + Vector2(-2.5, -1), 1.2, Color(0.1, 0.1, 0.2, ga))
		draw_circle(gp + Vector2(2.5, -1), 1.2, Color(0.1, 0.1, 0.2, ga))

func _ring(p: Vector2, team: int) -> void:
	var pts := PackedVector2Array()
	if team == 0:
		for i in 17:
			var a := i * TAU / 16
			pts.append(p + Vector2(cos(a) * 14, sin(a) * 7))
	else:
		pts = PackedVector2Array([p + Vector2(-15, 0), p + Vector2(0, -8), p + Vector2(15, 0), p + Vector2(0, 8), p + Vector2(-15, 0)])
	draw_polyline(pts, OUTLINE, 4)
	draw_polyline(pts, TEAM_COL[team], 2)

func _ln(a: Vector2, b: Vector2, c: Color, w := 2.5) -> void:
	draw_line(a, b, Color(OUTLINE, c.a), w + 2.5, true)
	draw_line(a, b, c, w, true)

## 火柴人。p＝腳底；face＝±1；walk＝走路相位；atk＝攻擊動畫進度（0＝沒在攻擊）。
func _stick(p: Vector2, type: int, team: int, face: float, walk: float, atk: float, alpha: float) -> void:
	var col: Color = TEAM_COL[team]
	col.a = alpha
	var skin := Color(1, 0.93, 0.85, alpha)
	var dark := Color(0.2, 0.2, 0.25, alpha)
	var swing := sin(walk) * 5.0 if walk != 0.0 else 0.0
	var lunge := sin(atk * PI) * 4.0 * face
	var o := p + Vector2(lunge, 0)
	if type == D.CAVALRY:
		# 馬
		var hb := o + Vector2(0, -16)
		_ln(hb + Vector2(-12, 0), hb + Vector2(12, 0), dark, 6)
		for lx in [-9, -4, 5, 10]:
			_ln(hb + Vector2(lx, 2), o + Vector2(lx + swing * (1 if lx < 0 else -1) * 0.6, 0), dark, 2)
		_ln(hb + Vector2(12 * face, -1), hb + Vector2(17 * face, -10), dark, 3)
		draw_circle(hb + Vector2(19 * face, -11), 3.5, dark)
		_ln(hb + Vector2(-12 * face, -1), hb + Vector2(-17 * face, 4), dark, 2)
		# 騎士
		var hip := o + Vector2(0, -21)
		var neck := hip + Vector2(0, -12)
		_ln(hip, neck, col)
		_ln(hip, hip + Vector2(5 * face, 5), col)
		draw_circle(neck + Vector2(0, -6), 6, OUTLINE)
		draw_circle(neck + Vector2(0, -6), 5, skin)
		_ln(neck + Vector2(0, -12), neck + Vector2(0, -10), col, 4)
		var hand := neck + Vector2(6 * face, 4)
		_ln(neck + Vector2(0, 2), hand, col)
		var tip := hand + Vector2((22 + atk * 8) * face, -4 + atk * 4)
		_ln(hand - Vector2(6 * face, -1), tip, Color(0.75, 0.6, 0.4, alpha), 2)
		return
	var hip := o + Vector2(0, -14)
	var neck := o + Vector2(0, -28)
	var head := o + Vector2(0, -35)
	_ln(hip, o + Vector2(-5 + swing, 0), col)
	_ln(hip, o + Vector2(5 - swing, 0), col)
	_ln(hip, neck, col)
	draw_circle(head, 7.5, Color(OUTLINE, alpha))
	draw_circle(head, 6.2, skin)
	draw_circle(head + Vector2(2.5 * face, -0.5), 1.1, Color(0, 0, 0, alpha))
	var sh := neck + Vector2(0, 3)
	var back_hand := sh + Vector2(-6 * face, 9 - swing)
	_ln(sh, back_hand, col)
	match type:
		D.SWORD:
			var hand := sh + Vector2(8 * face, 6)
			_ln(sh, hand, col)
			var ang := lerpf(-1.9, 0.4, atk) if atk > 0 else -1.1
			var dir := Vector2(cos(ang) * face, sin(ang))
			_ln(hand, hand + dir * 18, Color(0.9, 0.92, 1, alpha), 2.5)
			_ln(hand - dir * 2 + dir.orthogonal() * 3, hand - dir * 2 - dir.orthogonal() * 3, Color(0.6, 0.45, 0.2, alpha), 2)
			# 頭盔
			draw_arc(head + Vector2(0, -1), 7.5, PI, TAU, 10, Color(0.65, 0.68, 0.75, alpha), 3)
		D.SHIELD:
			var hand := sh + Vector2(7 * face, 6)
			_ln(sh, hand, col)
			var r := Rect2(hand + Vector2(-3 + 3 * face, -12), Vector2(7, 22))
			r.position.x = hand.x + (2 if face > 0 else -9) + atk * 3 * face
			draw_rect(r.grow(1.5), Color(OUTLINE, alpha))
			draw_rect(r, Color(0.62, 0.66, 0.74, alpha))
			draw_line(r.get_center() + Vector2(0, -8), r.get_center() + Vector2(0, 8), col, 2)
			draw_arc(head + Vector2(0, -1), 7.5, PI, TAU, 10, Color(0.55, 0.58, 0.65, alpha), 4)
			_ln(head + Vector2(-5, 1), head + Vector2(5, 1), Color(0.55, 0.58, 0.65, alpha), 1.5)
		D.ARCHER:
			var hand := sh + Vector2(10 * face, 1)
			_ln(sh, hand, col)
			draw_arc(hand, 11, -1.2 if face > 0 else PI - 1.2, 1.2 if face > 0 else PI + 1.2, 12, Color(0.65, 0.45, 0.25, alpha), 2.5)
			var pull := 6.0 * (1.0 - atk) if atk > 0 else 2.0
			var top := hand + Vector2(cos(-1.2) * 11 * face, sin(-1.2) * 11)
			var bot := hand + Vector2(cos(1.2) * 11 * face, sin(1.2) * 11)
			var mid := hand - Vector2(pull * face, 0)
			draw_line(top, mid, Color(1, 1, 1, alpha * 0.8), 1)
			draw_line(mid, bot, Color(1, 1, 1, alpha * 0.8), 1)
			# 帽子
			draw_colored_polygon(PackedVector2Array([head + Vector2(-8, -3), head + Vector2(8, -3), head + Vector2(-2 * face, -14)]), Color(0.3, 0.55, 0.3, alpha))
		D.ASSASSIN:
			var hand := sh + Vector2(8 * face, 4 - atk * 4)
			_ln(sh, hand, col)
			_ln(hand, hand + Vector2(9 * face, -3 + atk * 6), Color(0.85, 0.85, 0.95, alpha), 2)
			# 兜帽
			draw_colored_polygon(PackedVector2Array([head + Vector2(-8.5, 3), head + Vector2(-7, -6), head + Vector2(-5 * face, -12), head + Vector2(7, -6), head + Vector2(8.5, 3), head + Vector2(5 * face, 0)]), Color(0.38, 0.15, 0.5, alpha))
			draw_circle(head + Vector2(3 * face, 0), 1.3, Color(1, 0.9, 0.2, alpha))

func _draw_fx(f: Dictionary) -> void:
	var k: float = f["t"] / f["dur"]
	match f["kind"]:
		"arrow":
			var a: Vector2 = f["a"]
			var b: Vector2 = f["b"]
			var p := a.lerp(b, k) + Vector2(0, -sin(k * PI) * 30)
			var p2 := a.lerp(b, maxf(0, k - 0.12)) + Vector2(0, -sin(maxf(0, k - 0.12) * PI) * 30)
			draw_line(p2, p, Color(0.95, 0.9, 0.7), 2)
		"slash":
			var c: Vector2 = f["p"] + Vector2(f["dir"] * 14, -22)
			var start := -1.2 if f["dir"] > 0 else PI - 1.2
			draw_arc(c, 14, start, start + 2.4 * k, 10, Color(1, 1, 1, 1 - k), 3)
		"text":
			var p: Vector2 = f["p"] + Vector2(0, -k * 24)
			var c: Color = f["c"]
			c.a = 1.0 - k * k
			_text(p, f["s"], f["size"], c, true)

func _text(p: Vector2, s: String, size: int, c: Color, center := false) -> void:
	var lines := s.split("\n")
	for i in lines.size():
		var w := font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x if center else 0.0
		var q := p + Vector2(-w / 2, i * size * 1.25 + size * 0.35)
		draw_string_outline(font, q, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, c.a * 0.8))
		draw_string(font, q, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)

func _draw_hud() -> void:
	draw_rect(Rect2(0, 0, 1280, 84), Color(0.08, 0.09, 0.12, 0.92))
	_text(Vector2(20, 20), "落子無悔", 28, Color("#ffe8a3"))
	_text(Vector2(20, 54), "No Take-Backs・火柴人原型", 14, Color(1, 1, 1, 0.6))
	_text(Vector2(1260 - 180, 22), "第 %d 局" % round_no, 18, Color.WHITE)
	_text(Vector2(1260 - 180, 50), "藍 %d : %d 紅" % [wins[0], wins[1]], 18, Color.WHITE)
	if state == St.PLACE:
		_draw_place_hud()
	else:
		_draw_battle_hud()
	if toast_t > 0:
		_text(Vector2(640, 640), toast, 22, Color(1, 0.85, 0.4, minf(1, toast_t * 2)), true)

func _draw_place_hud() -> void:
	var a = _cur_army()
	var tcol: Color = TEAM_COL[a.team]
	var head := "擺放你的軍隊" if mode == Mode.VS_AI else "%s 落子中　這一手還能花 %d 金" % [TEAM_NAME[tp.current], tp.turn_left()]
	if mode == Mode.TURNS and tp.done():
		head = "雙方都擺完了，按「開戰！」"
	_text(Vector2(640, 18), head, 22, tcol if mode == Mode.TURNS else Color.WHITE, true)
	# 預算條
	var bx := 400.0
	var bw := 480.0
	draw_rect(Rect2(bx, 48, bw, 16), Color(0.2, 0.2, 0.25))
	draw_rect(Rect2(bx, 48, bw * a.spent() / a.budget, 16), tcol)
	_text(Vector2(640, 46), "%s　已用 %d / %d 金　%d / %d 隻" % [TEAM_NAME[a.team], a.spent(), a.budget, a.count(), Army.MAX_UNITS], 14, Color.WHITE, true)
	var info := "%s：%s" % [D.NAMES[selected], D.BLURB[selected]]
	if mode == Mode.VS_AI:
		info += "　｜　按住拖過格子可連續擺・拖動可移位・右鍵移除"
	else:
		var o = tp.armies[1 - tp.current]
		info += "　｜　擺下不能收回　｜　%s 已用 %d 金・%d 隻" % [TEAM_NAME[o.team], o.spent(), o.count()]
	_text(Vector2(640, 70), info, 13, Color(1, 1, 1, 0.75), true)
	# 兵種卡
	for i in D.COUNT:
		var r := Rect2(128 + i * (CARD_W + 8), CARD_Y, CARD_W, CARD_H)
		var afford: bool = D.cost(i) <= a.left() and a.count() < Army.MAX_UNITS
		var bg := Color(0.17, 0.18, 0.23)
		if i == selected:
			bg = Color(0.25, 0.3, 0.42)
		elif i == hover_card:
			bg = Color(0.21, 0.23, 0.3)
		draw_rect(r, bg)
		draw_rect(r, tcol if i == selected else Color(1, 1, 1, 0.15), false, 2)
		_stick(r.position + Vector2(30, 80), i, a.team, 1.0, 0.0, 0.0, 1.0 if afford else 0.35)
		_text(r.position + Vector2(60, 12), D.NAMES[i], 18, Color.WHITE if afford else Color(1, 1, 1, 0.4))
		_text(r.position + Vector2(60, 40), "%d 金" % D.cost(i), 16, Color("#ffd166") if afford else Color(1, 0.5, 0.5, 0.6))
		_text(r.position + Vector2(60, 66), "×%d" % a.count_of(i), 14, Color(1, 1, 1, 0.7))

func _draw_battle_hud() -> void:
	var p0: int = sim.power(0)
	var p1: int = sim.power(1)
	var tot := maxf(1.0, p0 + p1)
	var bx := 340.0
	var bw := 600.0
	var split := bw * p0 / tot
	draw_rect(Rect2(bx - 2, 44, bw + 4, 22), OUTLINE)
	draw_rect(Rect2(bx, 46, split, 18), TEAM_COL[0])
	draw_rect(Rect2(bx + split, 46, bw - split, 18), TEAM_COL[1])
	draw_line(Vector2(bx + bw / 2, 40), Vector2(bx + bw / 2, 70), Color(1, 1, 1, 0.6), 2)
	_text(Vector2(bx - 10 - 60, 45), "%d 隻" % sim.alive_count(0), 16, TEAM_COL[0])
	_text(Vector2(bx + bw + 14, 45), "%d 隻" % sim.alive_count(1), 16, TEAM_COL[1])
	var secs := maxi(0, 90 - sim.tick / 20)
	var tc := Color.ORANGE_RED if sim.frenzy else Color.WHITE
	_text(Vector2(640, 16), "%d 秒%s" % [secs, "　🔥狂熱" if sim.frenzy else ""], 22, tc, true)
	if mode == Mode.VS_AI:
		_text(Vector2(bx + bw, 74), "AI：%s" % ai_name, 12, Color(1, 1, 1, 0.6))
	if state == St.RESULT:
		draw_rect(Rect2(0, 0, 1280, 800), Color(0, 0, 0, 0.45))
		draw_rect(Rect2(400, 250, 480, 340), Color(0.1, 0.11, 0.15, 0.96))
		draw_rect(Rect2(400, 250, 480, 340), Color(1, 1, 1, 0.2), false, 2)
		var title := "平手"
		var col := Color.WHITE
		if sim.winner >= 0:
			title = "%s勝利！" % TEAM_NAME[sim.winner]
			col = TEAM_COL[sim.winner]
		_text(Vector2(640, 280), title, 40, col, true)
		_text(Vector2(640, 336), "%s・%.1f 秒" % [sim.reason, sim.tick / 20.0], 16, Color(1, 1, 1, 0.8), true)
		var total := float(sim.budget * 1000)
		_text(Vector2(640, 370), "剩餘戰力　藍 %d%%　紅 %d%%" % [roundi(p0 * 100 / total), roundi(p1 * 100 / total)], 18, Color.WHITE, true)
		if sim.winner >= 0 and sim.alive_count(sim.winner) == 1:
			_text(Vector2(640, 404), "★ 孤勇者！最後一隻撐到勝利 ★", 20, Color.GOLD, true)
		var mvp = null
		for u in sim.units:
			if mvp == null or u.dmg_dealt > mvp.dmg_dealt:
				mvp = u
		if mvp != null:
			_text(Vector2(640, 440), "MVP：%s的%s　傷害 %d・擊殺 %d" % [TEAM_NAME[mvp.team], D.NAMES[mvp.type], mvp.dmg_dealt, mvp.kills], 16, Color(1, 1, 1, 0.85), true)
		if series_over:
			var sw := "整場平手" if wins[0] == wins[1] else "%s 拿下整場（%d : %d）" % [TEAM_NAME[0 if wins[0] > wins[1] else 1], wins[0], wins[1]]
			_text(Vector2(640, 462), "三戰兩勝結束：" + sw, 18, Color.GOLD, true)
		_text(Vector2(640, 492), "指紋 %d（同一場重播一定相同）" % sim.fingerprint, 12, Color(1, 1, 1, 0.45), true)

# ───────────────────────── 截圖（驗證用） ─────────────────────────
func _snap(name: String) -> void:
	queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shot_dir.path_join(name))
	print("SHOT ", name)

func _run_screenshots() -> void:
	# 1. 擺放畫面
	for s in [[D.SHIELD, 5, 3], [D.SHIELD, 5, 4], [D.SHIELD, 5, 5], [D.SWORD, 4, 2], [D.SWORD, 4, 6], [D.SWORD, 4, 4],
			[D.ARCHER, 1, 3], [D.ARCHER, 1, 4], [D.ARCHER, 1, 5], [D.ARCHER, 0, 4], [D.CAVALRY, 3, 0], [D.CAVALRY, 3, 8],
			[D.ASSASSIN, 2, 4], [D.SWORD, 4, 3], [D.SWORD, 4, 5]]:
		armies[0].place(s[0], s[1], s[2])
	selected = D.CAVALRY
	mouse = ORIGIN + Vector2(2.5, 6.5) * CS
	_refresh_buttons()
	await _snap("1_place.png")
	_on_start()
	# 2. 交戰中
	for i in 140:
		_sim_step(true)
	for f in fx:
		f["t"] = 0.0
	await _snap("2_battle.png")
	# 3. 殘局（剩 ≤3 隻）
	while not sim.finished and sim.alive_count(0) > 3 and sim.alive_count(1) > 3:
		_sim_step(true)
	slow_left = 8.0
	zoom = 1.3
	zoom_center = _alive_centroid()
	_fx_text(ORIGIN + FIELD / 2 - Vector2(0, 200), "最後時刻！", Color.GOLD, 1.6, 40)
	await _snap("3_endgame.png")
	# 4. 結果
	while not sim.finished:
		_sim_step(false)
	zoom = 1.0
	_finish_battle()
	await _snap("4_result.png")
	# 5. 輪流落子
	mode = Mode.TURNS
	_reset_place()
	tp.place(D.SHIELD, 5, 4)
	tp.place(D.SWORD, 5, 3)
	tp.end_turn()
	tp.place(D.CAVALRY, 12, 0)
	selected = D.ARCHER
	mouse = ORIGIN + Vector2(1.5, 4.5) * CS
	_refresh_buttons()
	await _snap("5_turns.png")
	get_tree().quit()
