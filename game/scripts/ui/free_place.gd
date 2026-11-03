extends "res://scripts/ui/lobby_view.gd"
## 第六輪：自由排兵的操作與畫面（docs/2026-11-03-free-placement-plan-v6.md §4）。格子模式完全不經過這裡。
##   滑鼠：點空地＝放一隻；在空地按住拖＝畫筆（放開才確定，右鍵／Esc 取消）；Shift＝直線；在兵上按住拖＝搬它；
##        Ctrl 拖＝框選，之後拖選取的任一隻＝整群剛體平移；右鍵點／拖＝刪除；Delete 刪選取、M 上下翻轉；G 對齊；Ctrl+Z／Y。
##   手把：左搖桿平滑游標、十字鍵 0.5 格、A 放（按住＝畫筆）、X 清除（按住連續）、Y 畫筆／直線、L3 對齊、R3 緊密／標準、B 取消。
##   觸控：Godot 會把觸控轉成滑鼠；觸控時預覽點畫在手指上方 40px（手指會遮住）。

const PICK_R := 350            # 點選既有兵的半徑（小於最小間距的一半，Antigravity 第二輪）
const TOUCH_LIFT := 40.0

var fp_tool := "brush"         # brush／line／select
var fp_snap := false           # 工具列的「對齊」常駐開關（按住 G＝暫時）
var fp_dense := true           # 畫筆間距：true＝最小間距、false＝1.0 格
var fp_stroke: Array = []      # 預覽中的點 [type, x, y]
var fp_stroking := false
var fp_line := false           # 這一筆是直線
var fp_start := Vector2i.ZERO  # 直線起點（世界座標）
var fp_last := Vector2i.ZERO   # 畫筆上一個取樣點
var fp_full := false           # 錢／人數／這一手用完（後面的點截斷）
var fp_probe = null            # 預覽用的軍隊副本
var fp_drag := -1              # 正在搬的那一隻
var fp_drag_from := Vector2i.ZERO
var fp_sel: Array = []         # 框選的索引
var fp_box := false
var fp_box_a := Vector2.ZERO
var fp_erasing := false
var fp_undo: Array = []
var fp_redo: Array = []
var fp_cur := Vector2(4000, 4500)   # 手把游標（世界座標）
var fp_touch := false
var fp_pad_a := false
var fp_pad_x := false
var fp_skip_seen := 0          # 已經提示過幾次跳手

# ───────── 座標 ─────────
func _is_free() -> bool:
	return rules != null and rules.is_free() and (mode == Mode.VS_AI or mode == Mode.DUEL) and state == St.PLACE

func _w_of(p: Vector2) -> Vector2i:
	var lift := Vector2(0, -TOUCH_LIFT) if fp_touch else Vector2.ZERO
	var q := (p + lift - ORIGIN) / CS * 1000.0
	return Vector2i(int(q.x), int(q.y))

## 世界座標 → 畫面上「腳底」的位置（和格子模式一樣：中心往下 0.32 格）。
func _s_of(w: Vector2i) -> Vector2:
	return ORIGIN + Vector2(w.x / 1000.0, w.y / 1000.0 + 0.32) * CS

func _snap_on() -> bool:
	return fp_snap or Input.is_key_pressed(KEY_G)

## 量化（對齊時吸到 0.5 格的點）。
func _q(w: Vector2i) -> Vector2i:
	if _snap_on():
		return Vector2i(int(round(w.x / 500.0)) * 500, int(round(w.y / 500.0)) * 500)
	return Vector2i(Army.quant(w.x), Army.quant(w.y))

func _fp_army():
	return call("_cur_army")

func _fp_step() -> int:
	var a = _fp_army()
	return int(a.spacing) if fp_dense else maxi(1000, int(a.spacing))

func _fp_in_field(p: Vector2) -> bool:
	return Rect2(ORIGIN, FIELD).has_point(p)

func _fp_duel_turns() -> bool:
	return mode == Mode.DUEL and tp != null

# ───────── 畫筆／直線 ─────────
func _fs_begin(w: Vector2i) -> void:
	fp_stroking = true
	fp_full = false
	fp_stroke = []
	fp_probe = _fp_army().copy()
	fp_line = fp_tool == "line" or Input.is_key_pressed(KEY_SHIFT)
	fp_start = _q(w)
	fp_last = fp_start
	_fs_try(fp_start)

## 這一點能不能加進預覽（和場上的兵、已預覽的點、錢、人數、這一手的金額都比）。
func _fs_try(w: Vector2i) -> bool:
	if fp_full:
		return false
	var t: int = selected
	var a = _fp_army()
	var cost := 0
	for it in fp_stroke:
		cost += D.cost(int(it[0]))
	if _fp_duel_turns():
		if D.cost(t) > tp.turn_left() - cost:
			fp_full = true
			return false
		var tw: String = tp.check_place_xy(t, w.x, w.y)
		if tw == "最後一手要擺戰鬥兵" or tw == "擺放已結束" or tw == "離敵兵太近":
			return false
	var why: String = fp_probe.check_place_xy(t, w.x, w.y)
	if why == "錢不夠" or why.begins_with("最多") or why.begins_with("這種兵最多"):
		fp_full = true   # 錢、人數用完：後面截斷（§3.8）
		return false
	if why != "":
		return false
	fp_probe.place_xy(t, w.x, w.y)
	fp_stroke.append([t, w.x, w.y])
	return true

## 畫筆：從上一個取樣點沿著線段，每隔間距取一個點（和滑鼠事件疏密、幀率無關）。
func _fs_extend(w: Vector2i) -> void:
	if not fp_stroking:
		return
	if fp_line:
		# 直線：每次重新算整條（起點到現在等距）
		fp_full = false
		fp_stroke = []
		fp_probe = _fp_army().copy()
		var e := _q(w)
		var d := Vector2(e - fp_start)
		var n := int(d.length() / _fp_step())
		for k in n + 1:
			var p := Vector2(fp_start) + (d.normalized() * _fp_step() * k if n > 0 else Vector2.ZERO)
			_fs_try(_q(Vector2i(p)))
		return
	var step := float(_fp_step())
	var from := Vector2(fp_last)
	var to := Vector2(w)
	var dist := from.distance_to(to)
	var guard := 0
	while dist >= step and guard < 200:
		guard += 1
		from = from + (to - from).normalized() * step
		var p := _q(Vector2i(from))
		_fs_try(p)
		fp_last = Vector2i(from)
		dist = from.distance_to(to)

func _fs_cancel() -> void:
	fp_stroking = false
	fp_stroke = []
	fp_probe = null

func _fs_commit() -> void:
	if not fp_stroking:
		return
	fp_stroking = false
	var items := fp_stroke.duplicate(true)
	fp_stroke = []
	fp_probe = null
	if items.is_empty():
		return
	if _fp_duel_turns():
		if not tp.place_batch(items):
			_toast(L.t("err_zone"), true)
			return
	else:
		_fp_push_undo()
		var a = _fp_army()
		for it in items:
			a.place_xy(int(it[0]), int(it[1]), int(it[2]))
	show_place_help = false
	_fp_sound(items.size())

## 畫筆連續落子的音效：一筆只響一次＋依隻數升高音高（避免一次 10 聲破音，Antigravity 第一輪）。
func _fp_sound(n: int) -> void:
	if sfx != null and sfx.has_method("play_pitched"):
		sfx.play_pitched("place_mid", 0.6, 1.0 + minf(0.25, n * 0.025))
	elif sfx != null:
		sfx.play("place_mid", 0.6)

# ───────── 搬移、框選、刪除、復原 ─────────
func _fp_push_undo() -> void:
	fp_undo.append(_fp_army().units.duplicate(true))
	if fp_undo.size() > 40:
		fp_undo.pop_front()
	fp_redo.clear()

func _fp_undo_do(redo := false) -> void:
	if _fp_duel_turns():
		_toast(L.t("err_notakeback"), true)
		return
	var src: Array = fp_redo if redo else fp_undo
	if src.is_empty():
		return
	var a = _fp_army()
	(fp_undo if redo else fp_redo).append(a.units.duplicate(true))
	a.units = src.pop_back()
	fp_sel = []

func _fp_erase_at(w: Vector2i) -> void:
	if _fp_duel_turns():
		return
	var a = _fp_army()
	var i: int = a.index_near(w.x, w.y, PICK_R)
	if i >= 0:
		if not fp_erasing:
			_fp_push_undo()
		a.units.remove_at(i)
		fp_sel = []
		fp_erasing = true

func _fp_delete_sel() -> void:
	if _fp_duel_turns() or fp_sel.is_empty():
		return
	_fp_push_undo()
	var a = _fp_army()
	var idx := fp_sel.duplicate()
	idx.sort()
	idx.reverse()
	for i in idx:
		a.units.remove_at(i)
	fp_sel = []

func _fp_flip_sel() -> void:
	if _fp_duel_turns() or fp_sel.is_empty():
		return
	_fp_push_undo()
	if not _fp_army().flip_group(fp_sel):
		fp_undo.pop_back()
		_toast(L.t("err_flip"), true)

# ───────── 滑鼠 ─────────
## 回傳 true＝這個事件自由模式處理掉了。
func _fp_mb(d: Dictionary) -> bool:
	if not _is_free() or overlay != "":
		return false
	var p: Vector2 = d["pos"]
	var w := _w_of(p)
	var a = _fp_army()
	var btn: int = d["i"]
	var pressed: bool = d["pressed"]
	if btn == MOUSE_BUTTON_RIGHT and pressed:
		if fp_stroking:
			_fs_cancel()   # 拖曳中按右鍵：取消整筆
			return true
		if _fp_in_field(p):
			fp_erasing = false
			_fp_erase_at(w)
			fp_erasing = true
			if _fp_duel_turns():
				_toast(L.t("err_notakeback"), true)
		return _fp_in_field(p)
	if btn == MOUSE_BUTTON_RIGHT and not pressed:
		fp_erasing = false
		return false
	if btn != MOUSE_BUTTON_LEFT:
		return false
	if pressed:
		if not _fp_in_field(p):
			return false
		var hit: int = a.index_near(w.x, w.y, PICK_R)
		if Input.is_key_pressed(KEY_CTRL) or (fp_tool == "select" and hit < 0):
			fp_box = true
			fp_box_a = p
			return true
		if hit >= 0 and not _fp_duel_turns():
			fp_drag = hit
			fp_drag_from = a.pos_of(a.units[hit])
			if not hit in fp_sel:
				fp_sel = []
			return true
		if hit >= 0:
			return true
		if not call("_allowed", selected):
			_toast(L.t("err_type"), true)
			return true
		_fs_begin(w)
		return true
	# 放開
	if fp_box:
		fp_box = false
		var r := Rect2(fp_box_a, Vector2.ZERO).expand(p)
		fp_sel = []
		for i in a.units.size():
			if r.has_point(_s_of(a.pos_of(a.units[i]))):
				fp_sel.append(i)
		return true
	if fp_drag >= 0:
		var i := fp_drag
		fp_drag = -1
		if not _fp_in_field(p):
			_fp_push_undo()
			a.units.remove_at(i)
			fp_sel = []
			return true
		var tgt := _q(w)
		if fp_sel.size() > 1 and i in fp_sel:
			_fp_push_undo()
			var mv: Vector2i = a.move_group(fp_sel, tgt.x - fp_drag_from.x, tgt.y - fp_drag_from.y)
			if mv.x == -99999:
				fp_undo.pop_back()
				_toast(L.t("err_group_move"), true)
			return true
		if tgt != fp_drag_from:
			_fp_push_undo()
			if not a.move_xy(i, tgt.x, tgt.y):
				fp_undo.pop_back()
				_toast(L.t("err_zone"), true)
		return true
	if fp_stroking:
		_fs_commit()
		return true
	return false

func _fp_motion(p: Vector2) -> void:
	if not _is_free():
		return
	var w := _w_of(p)
	if fp_stroking:
		_fs_extend(w)
	elif fp_erasing and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_fp_erase_at(w)

## 鍵盤：回傳 true＝處理掉了。
func _fp_key(k: int) -> bool:
	if not _is_free() or overlay != "":
		return false
	match k:
		KEY_ESCAPE:
			if fp_stroking:
				_fs_cancel()
				return true
			if not fp_sel.is_empty():
				fp_sel = []
				return true
		KEY_DELETE:
			_fp_delete_sel()
			return true
		KEY_M:
			_fp_flip_sel()
			return true
		KEY_Z:
			if Input.is_key_pressed(KEY_CTRL):
				_fp_undo_do(false)
				return true
		KEY_Y:
			if Input.is_key_pressed(KEY_CTRL):
				_fp_undo_do(true)
				return true
	return false

# ───────── 手把 ─────────
func _fp_pad_process(delta: float, stick: Vector2) -> void:
	if not _is_free() or not pad_mode:
		return
	if stick.length() > 0.2:
		# 平滑游標＋輕推時減速（微調）
		var sp := 5200.0 * pow(stick.length(), 2.0)
		fp_cur += stick.normalized() * sp * delta
		fp_cur.x = clampf(fp_cur.x, 200.0, 15800.0)
		fp_cur.y = clampf(fp_cur.y, 200.0, 8800.0)
		var w := Vector2i(fp_cur)
		if fp_stroking:
			_fs_extend(w)
		elif fp_pad_x:
			_fp_erase_at(w)

func _fp_pad_button(b: int, pressed: bool) -> bool:
	if not _is_free() or overlay != "":
		return false
	var w := Vector2i(fp_cur)
	match b:
		JOY_BUTTON_A:
			if pressed:
				fp_pad_a = true
				if call("_allowed", selected):
					_fs_begin(w)
			else:
				fp_pad_a = false
				_fs_commit()
			return true
		JOY_BUTTON_X:
			fp_pad_x = pressed
			if pressed:
				fp_erasing = false
				_fp_erase_at(w)
			else:
				fp_erasing = false
			return true
		JOY_BUTTON_B:
			if pressed and fp_stroking:
				_fs_cancel()
				return true
		JOY_BUTTON_Y:
			if pressed:
				fp_tool = "line" if fp_tool == "brush" else "brush"
				return true
		JOY_BUTTON_LEFT_STICK:
			if pressed:
				fp_snap = not fp_snap
				return true
		JOY_BUTTON_RIGHT_STICK:
			if pressed:
				fp_dense = not fp_dense
				return true
		JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT:
			if pressed:
				var dv := {JOY_BUTTON_DPAD_UP: Vector2(0, -500), JOY_BUTTON_DPAD_DOWN: Vector2(0, 500), JOY_BUTTON_DPAD_LEFT: Vector2(-500, 0), JOY_BUTTON_DPAD_RIGHT: Vector2(500, 0)}
				fp_cur = Vector2(round((fp_cur.x + dv[b].x) / 500.0) * 500.0, round((fp_cur.y + dv[b].y) / 500.0) * 500.0)
				fp_cur.x = clampf(fp_cur.x, 500.0, 15500.0)
				fp_cur.y = clampf(fp_cur.y, 500.0, 8500.0)
				return true
	return false

# ───────── 畫面 ─────────
## 部署區、中線對峙帶、（全場）敵兵禁區。
func _fp_draw_zones() -> void:
	var a = _fp_army()
	var dep: int = a.depth
	var tc := Art.team_color(a.team, cbm())
	if dep < 15000:
		var x0 := ORIGIN.x + (dep / 1000.0 if a.team == 0 else (16000 - dep) / 1000.0) * CS
		draw_dashed_line(Vector2(x0, ORIGIN.y), Vector2(x0, ORIGIN.y + FIELD.y), Color(tc, 0.8), 3.0, 8.0)
		# 對峙帶（中線兩側到兩邊部署區的邊）
		var other: int = rules.depth if rules != null else 6000
		var xa := ORIGIN.x + other / 1000.0 * CS
		var xb := ORIGIN.x + (16000 - other) / 1000.0 * CS
		if xb > xa:
			draw_rect(Rect2(xa, ORIGIN.y, xb - xa, FIELD.y), Color(0.85, 0.75, 0.55, 0.10))
			for k in 5:
				var fy := ORIGIN.y + FIELD.y * (k + 0.5) / 5.0
				var fx := (xa + xb) / 2.0
				draw_line(Vector2(fx, fy - 14), Vector2(fx, fy + 10), Color(0.4, 0.3, 0.2, 0.5), 2.0)
				draw_colored_polygon(PackedVector2Array([Vector2(fx, fy - 14), Vector2(fx + 12, fy - 9), Vector2(fx, fy - 4)]), Color(0.85, 0.75, 0.55, 0.55))
	# 全場：敵兵 1.5 格禁區融合成一片淡紅
	for e in a.enemy_pos:
		draw_circle(_s_of(e) - Vector2(0, 0.32 * CS), a.enemy_gap / 1000.0 * CS, Color(1, 0.25, 0.25, 0.10), true, -1.0, true)

## 自由模式的兵、預覽、占地圈、選取、框選、對齊點陣、工具列。
func _fp_draw() -> void:
	# 跳手提示（§3.10）：沒有合法位置或買不起的一方被自動跳過
	if tp != null and tp.skipped.size() > fp_skip_seen:
		var sk: Dictionary = tp.skipped[tp.skipped.size() - 1]
		fp_skip_seen = tp.skipped.size()
		_toast(L.t("fp_skipped", [L.t("blue") if int(sk["team"]) == 0 else L.t("red")]))
	var a = _fp_army()
	var drag_on := fp_stroking or fp_drag >= 0 or fp_box
	var lst: Array = []
	var hide_side := -1
	if mode == Mode.VS_AI and (rules == null or rules.fullfield != 2):
		hide_side = 1
	elif mode == Mode.DUEL and tp == null:
		hide_side = 1 if blind_phase == 0 else (0 if blind_phase == 1 else -1)
	for ar in armies:
		if ar.team == hide_side:
			continue
		for i in ar.units.size():
			if ar == a and i == fp_drag:
				continue
			var w: Vector2i = ar.pos_of(ar.units[i])
			lst.append([w.y, w.x, int(ar.units[i]["type"]), ar.team, ar == a and i in fp_sel])
	lst.sort()
	# 占地圈：只在拖曳或懸停時出現（Antigravity）
	var hover_w := _w_of(mouse)
	for it in lst:
		var w := Vector2i(it[1], it[0])
		if it[3] == a.team and (drag_on or Vector2(w - hover_w).length() < 2500):
			_fp_dashed_circle(_s_of(w) - Vector2(0, 0.32 * CS), a.spacing / 2000.0 * CS, Color(1, 1, 1, 0.35))
	for it in lst:
		var p := _s_of(Vector2i(it[1], it[0]))
		_ring(p, it[3], it[2])
		_unit(p, it[2], it[3], 1.0 if it[3] == 0 else -1.0, 0.0, 0.0, 0.0, 1.0, time + it[1] * 0.001, 1.0)
		if it[4]:
			draw_arc(p - Vector2(0, 2), 24, 0, TAU, 28, ACCENT, 2.5, true)
		# 全場：擺到敵方半場的兵畫開戰朝向箭頭（會先往敵方底線走）
		if rules != null and rules.fullfield != 0 and ((it[3] == 0 and it[1] > 8000) or (it[3] == 1 and it[1] < 8000)):
			var dir := 1.0 if it[3] == 0 else -1.0
			var b0 := p + Vector2(-10 * dir, 10)
			draw_line(b0, b0 + Vector2(22 * dir, 0), Color(1, 1, 1, 0.8), 2.0)
			draw_colored_polygon(PackedVector2Array([b0 + Vector2(22 * dir, -5), b0 + Vector2(30 * dir, 0), b0 + Vector2(22 * dir, 5)]), Color(1, 1, 1, 0.8))
	# 搬移中的那一隻
	if fp_drag >= 0 and fp_drag < a.units.size():
		var tgt := _q(_w_of(mouse))
		var ok_m: bool = a.check_place_xy(int(a.units[fp_drag]["type"]), tgt.x, tgt.y, fp_drag) == ""
		_unit(_s_of(tgt), int(a.units[fp_drag]["type"]), a.team, 1.0, 0.0, 0.0, 0.0, 0.6 if ok_m else 0.3, time, 1.0)
	# 畫筆預覽：腳底亮點＋半透明小人＋費用泡泡
	if fp_stroking:
		var cost := 0
		for it in fp_stroke:
			var p2 := _s_of(Vector2i(it[1], it[2]))
			draw_circle(p2, 5, Color(ACCENT, 0.9), true, -1.0, true)
			_unit(p2, int(it[0]), a.team, 1.0 if a.team == 0 else -1.0, 0.0, 0.0, 0.0, 0.5, time, 1.0)
			cost += D.cost(int(it[0]))
		var tip := L.t("fp_bubble", [cost, fp_stroke.size()])
		if fp_full:
			tip += "　" + L.t("fp_full")
		var bp := mouse + Vector2(18, -36)
		var bw := _width(tip, tz("S"), true) + 16
		draw_rect(Rect2(bp, Vector2(bw, tz("S") * 1.6)), Color(0.06, 0.07, 0.1, 0.9))
		_text(bp + Vector2(8, tz("S") * 0.25), tip, tz("S"), ACCENT if not fp_full else Color("#ff8a8a"), false, true)
	# 框選
	if fp_box:
		var r := Rect2(fp_box_a, Vector2.ZERO).expand(mouse)
		draw_rect(r, Color(ACCENT, 0.12))
		draw_rect(r, ACCENT, false, 1.5)
	# 對齊點陣：只在游標附近 3×3 格淡出
	if _snap_on() and _fp_in_field(mouse):
		var c := _q(_w_of(mouse))
		for gx in range(-3, 4):
			for gy in range(-3, 4):
				var w2 := c + Vector2i(gx * 500, gy * 500)
				if w2.x >= 200 and w2.x <= 15800 and w2.y >= 200 and w2.y <= 8800:
					draw_circle(_s_of(w2) - Vector2(0, 0.32 * CS), 2.0, Color(1, 1, 1, 0.35 - 0.04 * (absi(gx) + absi(gy))), true, -1.0, true)
	# 游標（滑鼠在兵上＝搬移游標；手把＝準星）
	if not fp_stroking and fp_drag < 0 and _fp_in_field(mouse) and not pad_mode:
		var hi: int = a.index_near(hover_w.x, hover_w.y, PICK_R)
		if hi >= 0 and not _fp_duel_turns():
			var hp := _s_of(a.pos_of(a.units[hi]))
			draw_arc(hp - Vector2(0, 2), 22, 0, TAU, 24, Color(1, 1, 1, 0.8), 2.0, true)
			_fp_move_icon(mouse + Vector2(14, 14))
		elif fp_touch:
			_fp_reticle(_s_of(_q(hover_w)))
	if pad_mode:
		_fp_reticle(_s_of(Vector2i(fp_cur)))
	# 精簡版戰術預覽（第六輪）：游標處選中兵種的射程／作用範圍；畫筆拖曳中不畫，免得擋住預覽
	if not drag_on and (_fp_in_field(mouse) or pad_mode):
		var cw: Vector2i = Vector2i(fp_cur) if pad_mode else _q(hover_w)
		var cp := _s_of(cw) - Vector2(0, 0.32 * CS)
		var rad := 0.0
		match selected:
			D.ARCHER:
				rad = 6.0
			D.PIKE:
				rad = D.STATS[D.PIKE]["reach"] / 1000.0
			D.MEDIC:
				rad = D.HEAL_RANGE / 1000.0
			D.DRUMMER:
				rad = D.DRUM_RANGE / 1000.0
		if rad > 0.0:
			call("_arc_clipped", cp, rad * CS, 0, TAU, Color(1, 0.9, 0.5, 0.45), 2.0)
	_fp_toolbar()

func _fp_dashed_circle(c: Vector2, r: float, col: Color) -> void:
	var n := 24
	for k in n:
		if k % 2 == 0:
			draw_arc(c, r, TAU * k / n, TAU * (k + 1) / n, 3, col, 1.5, true)

func _fp_move_icon(p: Vector2) -> void:
	for dv in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		draw_line(p, p + dv * 9, Color.WHITE, 2.0)
		draw_colored_polygon(PackedVector2Array([p + dv * 12, p + dv * 8 + Vector2(dv.y, dv.x) * 3, p + dv * 8 - Vector2(dv.y, dv.x) * 3]), Color.WHITE)

func _fp_reticle(p: Vector2) -> void:
	draw_arc(p - Vector2(0, 2), 14, 0, TAU, 20, ACCENT, 2.0, true)
	draw_line(p + Vector2(-20, -2), p + Vector2(-8, -2), ACCENT, 2.0)
	draw_line(p + Vector2(8, -2), p + Vector2(20, -2), ACCENT, 2.0)

## 工具列：戰場上緣的浮動膠囊列（Antigravity 第二輪：右下放不下）。點＝切換常駐；按住 Shift／Ctrl／G＝暫時。
func _fp_toolbar() -> void:
	var items: Array = [["brush", L.t("fp_t_brush")], ["line", L.t("fp_t_line")]]
	if not _fp_duel_turns():
		items.append(["select", L.t("fp_t_select")])
	items.append(["snap", L.t("fp_t_snap")])
	items.append(["dense", L.t("fp_t_dense") if fp_dense else L.t("fp_t_loose")])
	if not _fp_duel_turns():
		items.append(["undo", L.t("fp_t_undo")])
	# 直排在戰場左邊的空白（第六輪截圖：放在戰場裡會擋到全場模式的敵兵）
	var w := ORIGIN.x - 16
	var x := 8.0
	var y := ORIGIN.y
	draw_rect(Rect2(x - 4, y - 4, w + 8, items.size() * 46 + 4), Color(0.06, 0.07, 0.1, 0.8))
	for k in items.size():
		var id: String = items[k][0]
		var on: bool = (id == fp_tool) or (id == "snap" and fp_snap) or (id == "dense" and fp_dense)
		var cb := func(): _fp_tool_click(id)
		_btn(Rect2(x, y, w, 40), items[k][1], cb, true, false, Color(0.26, 0.33, 0.5) if on else Color(0.14, 0.15, 0.2, 0.9))
		y += 46

func _fp_tool_click(id: String) -> void:
	match id:
		"brush", "line", "select":
			fp_tool = id
		"snap":
			fp_snap = not fp_snap
		"dense":
			fp_dense = not fp_dense
		"undo":
			_fp_undo_do(false)

## 開始擺放時重設自由模式的狀態。
func _fp_reset() -> void:
	fp_skip_seen = 0
	_fs_cancel()
	fp_drag = -1
	fp_sel = []
	fp_box = false
	fp_erasing = false
	fp_undo = []
	fp_redo = []
	fp_cur = Vector2(3500, 4500)
