extends "res://scripts/ui/lobby_view.gd"
## 第六輪：自由排兵的操作與畫面（docs/history/2026-11-03-free-placement-plan-v6.md §4）。格子模式完全不經過這裡。
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
var fp_press_p := Vector2.ZERO  # V1.5.1：按下的畫面位置（分辨點一下和拖曳）
var fp_moved := false            # 這次按下之後拖出去過（拖回原點也不算點一下）
var fp_start := Vector2i.ZERO  # 直線起點（世界座標）
var fp_last := Vector2i.ZERO   # 畫筆上一個取樣點
var fp_full := false           # 錢／人數／這一手用完（後面的點截斷）
var fp_full_why := ""
var fp_fine := false           # 畫筆上一點放不下，改小步找          # gold／cap／hand
var fp_zone_key := -1          # 敵兵禁區點陣的快取鍵
var fp_zone_rects: Array = []
var fp_gesture_at := -1.0      # 新手手勢開始的時間（−1＝不播）
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
var fp_skip_seen := 0
var free_intro := false        # 第七輪 A4：自由排兵入門關
var free_intro_moved := false
var fp_stroke_key: Array = []  # 這一筆屬於哪一隊、哪一手（換手就作廢，Codex 實作第 1 輪 #6）          # 已經提示過幾次跳手

# ───────── 座標 ─────────
func _is_free() -> bool:
	return rules != null and rules.is_free() and (mode == Mode.VS_AI or mode == Mode.DUEL) and state == St.PLACE

func _w_of(p: Vector2) -> Vector2i:
	var lift := Vector2(0, -TOUCH_LIFT) if fp_touch else Vector2.ZERO
	var q := (_fld_xf().affine_inverse() * (p + lift) - ORIGIN) / CS * 1000.0
	return Vector2i(int(q.x), int(q.y))

## 世界座標 → 畫面上「腳底」的位置（和格子模式一樣：中心往下 0.32 格）。
func _s_of(w: Vector2i) -> Vector2:
	return ORIGIN + Vector2(w.x / 1000.0, w.y / 1000.0 + 0.32) * CS

func _snap_on() -> bool:
	return fp_snap or Input.is_key_pressed(KEY_G)

## 量化（對齊時吸到 0.5 格的點）。
func _q(w: Vector2i) -> Vector2i:
	# 先轉成自己視角再量化（紅方鏡像後結果才和藍方一樣，Codex 實作第 1 輪 #11）
	var a = _fp_army()
	var ox: int = a.own_x(w.x)
	if _snap_on():
		return Vector2i(a.world_x(int(round(ox / 500.0)) * 500), int(round(w.y / 500.0)) * 500)
	return Vector2i(a.world_x(Army.quant(ox)), Army.quant(w.y))

## 這一筆的身分：隊伍＋手次＋暗擺階段。
func _fp_key_now() -> Array:
	return [_fp_army().team, tp.turn_index if tp != null else -1, blind_phase]

## 編輯鎖：暗擺雙方都確認後不能再動（沿用格子模式的 _locked／_can_edit_existing，Codex 實作第 1 輪 #2）。
func _fp_locked() -> bool:
	return bool(call("_locked"))

func _fp_can_edit() -> bool:
	return bool(call("_can_edit_existing"))

## 清空、載入、換手後，框選索引可能指到不存在的兵（Codex 實作第 1 輪 #8）。
func _fp_clean_sel() -> void:
	var n: int = _fp_army().units.size()
	fp_sel = fp_sel.filter(func(i): return i >= 0 and i < n)
	if fp_drag >= n:
		fp_drag = -1

func _fp_army():
	return call("_cur_army")

func _fp_step() -> int:
	var a = _fp_army()
	return int(a.spacing) if fp_dense else maxi(1000, int(a.spacing))

func _fp_in_field(p: Vector2) -> bool:
	return Rect2(ORIGIN, fld_size).has_point(_fld_xf().affine_inverse() * p)

func _fp_duel_turns() -> bool:
	return mode == Mode.DUEL and tp != null

# ───────── 畫筆／直線 ─────────
func _fs_begin(w: Vector2i) -> void:
	if _fp_locked():
		_toast(L.t("both_done"), true)
		return
	fp_stroke_key = _fp_key_now()
	fp_fine = false
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
			fp_full_why = "hand"
			return false
		var tw: String = tp.check_place_xy(t, w.x, w.y)
		if tw == "最後一手要擺戰鬥兵" or tw == "擺放已結束" or tw == Army.E_NEAR_ENEMY:
			return false
	var why: String = fp_probe.check_place_xy(t, w.x, w.y)
	if why == Army.E_GOLD or why.begins_with(Army.E_CAP_PREFIX) or why.begins_with(Army.E_TYPE_CAP_PREFIX):
		fp_full = true   # 錢、人數用完：後面截斷（§3.8）
		fp_full_why = "gold" if why == Army.E_GOLD else "cap"
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
	if Save.s("place_mode") == "tap" and not fp_line:
		return   # V1.5.1 C3：點選擺放：一下一隻，拖過去不連續擺（觸控友善）
	if fp_stroke_key != _fp_key_now():
		_fs_cancel()   # 拖曳中換手了：整筆作廢
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
	# 放不下（撞到兵或禁區）時改用 0.1 格小步往前找，放下後再恢復間距（Antigravity 實作第 1 輪 #8：不留兩倍空洞）
	# 小步狀態跨滑鼠事件保留（Codex 實作第 2 輪：慢慢拖也不能跳空位）
	var cur_step := 100.0 if fp_fine else step
	while dist >= cur_step and guard < 400:
		guard += 1
		from = from + (to - from).normalized() * cur_step
		var p := _q(Vector2i(from))
		fp_fine = not _fs_try(p)
		cur_step = 100.0 if fp_fine else step
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
	if fp_stroke_key != _fp_key_now() or _fp_locked():
		_toast(L.t("err_stroke_stale"), true)   # 換手後才放開：不能算到下一手（Codex 實作第 1 輪 #6）
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
	for k in items.size():
		settle_t[Vector2i(int(items[k][1]), int(items[k][2]))] = time + k * 0.03   # V1.3 B3：一隻接一隻落下
	show_place_help = false
	_fp_sound(items.size())

## 畫筆連續落子的音效：一筆只響一次＋依隻數升高音高（避免一次 10 聲破音，Antigravity 第一輪）。
func _fp_sound(n: int) -> void:
	if sfx != null and sfx.has_method("play_pitched"):
		sfx.play_pitched("place_mid", 0.6, 1.0 + minf(0.25, n * 0.025))
	elif sfx != null:
		sfx.play("place_mid", 0.6)
		sfx.play_wood(selected, 0.35)   # V1.6 #14

# ───────── 搬移、框選、刪除、復原 ─────────
func _fp_push_undo() -> void:
	fp_undo.append({"team": _fp_army().team, "units": _fp_army().units.duplicate(true)})
	if fp_undo.size() > 40:
		fp_undo.pop_front()
	fp_redo.clear()

func _fp_undo_do(redo := false) -> void:
	if _fp_duel_turns():
		_toast(L.t("err_notakeback"), true)
		return
	if _fp_locked():
		return
	var src: Array = fp_redo if redo else fp_undo
	var a = _fp_army()
	# 復原紀錄依隊伍分開：暗擺換方後，另一方的紀錄不能寫進這一方（Codex 實作第 1 輪 #1）
	while not src.is_empty() and int(src[src.size() - 1]["team"]) != a.team:
		src.pop_back()
	if src.is_empty():
		return
	(fp_undo if redo else fp_redo).append({"team": a.team, "units": a.units.duplicate(true)})
	var snap: Array = src.pop_back()["units"]
	# 還原前重新驗證（每一隻都在這一方的部署區、間距合法）
	var trial = a.copy()
	trial.units = []
	for u in snap:
		if not trial.place_xy(int(u["type"]), int(u["x"]), int(u["y"])):
			trial = null
			break
	if trial == null:
		_toast(L.t("err_zone"), true)
		return
	a.units = snap
	fp_sel = []

func _fp_erase_at(w: Vector2i) -> void:
	if _fp_duel_turns() or not _fp_can_edit():
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
	_fp_clean_sel()
	if _fp_duel_turns() or not _fp_can_edit() or fp_sel.is_empty():
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
	_fp_clean_sel()
	if _fp_duel_turns() or not _fp_can_edit() or fp_sel.is_empty():
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
	_fp_clean_sel()
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
		_fp_press(p, w, Input.is_key_pressed(KEY_CTRL))
		return true
	return _fp_release(p, w)

## 按下（滑鼠左鍵、手把 A 共用）：box＝強制框選（Ctrl、手把 LT）。
func _fp_press(p: Vector2, w: Vector2i, box: bool) -> void:
	var a = _fp_army()
	var hit: int = a.index_near(w.x, w.y, PICK_R)
	if box or (fp_tool == "select" and hit < 0):
		fp_box = true
		fp_box_a = p
		return
	if hit >= 0 and not _fp_duel_turns() and _fp_can_edit():
		fp_drag = hit
		fp_drag_from = a.pos_of(a.units[hit])
		fp_press_p = p
		fp_moved = false
		if not hit in fp_sel:
			fp_sel = []
		return
	if hit >= 0:
		return
	if not call("_allowed", selected):
		_toast(L.t("err_type"), true)
		return
	_fs_begin(w)

## 放開（滑鼠左鍵、手把 A 共用）。回傳 true＝自由模式處理掉了。
func _fp_release(p: Vector2, w: Vector2i) -> bool:
	var a = _fp_army()
	if fp_box:
		fp_box = false
		var r := Rect2(fp_box_a, Vector2.ZERO).expand(p)
		fp_sel = []
		for i in a.units.size():
			if r.has_point(_fld_xf() * _s_of(a.pos_of(a.units[i]))):
				fp_sel.append(i)
		return true
	if fp_drag >= 0:
		var i := fp_drag
		fp_drag = -1
		if _fp_locked() or not _fp_can_edit() or _fp_duel_turns():
			return true   # 拖曳途中被鎖住（暗擺雙方確認）：放開不生效（Codex 實作第 2 輪 #2）
		var group: bool = fp_sel.size() > 1 and i in fp_sel
		if not _fp_in_field(p):
			if group:
				return true   # 整群拖出戰場＝取消，不刪單隻（Antigravity 實作第 1 輪 #2）
			_fp_push_undo()
			a.units.remove_at(i)
			fp_sel = []
			return true
		if not group and Save.s("place_mode") == "tap" and not fp_moved and p.distance_to(fp_press_p) < 10.0:
			# V1.5.1 C4：只點選模式點一下自己的兵＝拿掉（可以復原；Codex v151-i2 #3）
			_fp_push_undo()
			a.units.remove_at(i)
			fp_sel = []
			return true
		var tgt := _q(w)
		if group:
			_fp_push_undo()
			var mv: Vector2i = a.move_group(fp_sel, tgt.x - fp_drag_from.x, tgt.y - fp_drag_from.y)
			if mv.x == -99999:
				fp_undo.pop_back()
				_toast(L.t("err_group_move"), true)
			else:
				free_intro_moved = true
			return true
		if tgt != fp_drag_from:
			_fp_push_undo()
			if not a.move_xy(i, tgt.x, tgt.y):
				fp_undo.pop_back()
				_toast(L.t("err_zone"), true)
			else:
				free_intro_moved = true
				settle_t[a.pos_of(a.units[i])] = time   # V1.3 B3：放下沉降＋落子聲（落點已經提交，只是畫面）
				if sfx != null:
					sfx.play("place_light", 0.55)
		return true
	if fp_stroking:
		_fs_commit()
		return true
	return false

## 拖曳中打開覆蓋層、失焦等，放開事件到不了：把所有拖曳狀態收掉（Antigravity 實作第 1 輪 #2）。
func _fp_abort_drag() -> void:
	_fs_cancel()
	fp_drag = -1
	fp_box = false
	fp_erasing = false
	fp_pad_a = false
	fp_pad_x = false

## 世界座標 → 畫面上的點（不加腳底偏移；手把游標當成滑鼠位置用）。
func _fp_scr(w: Vector2i) -> Vector2:
	return ORIGIN + Vector2(w) / 1000.0 * CS

func _fp_motion(p: Vector2) -> void:
	if not _is_free():
		return
	if fp_drag >= 0 and p.distance_to(fp_press_p) >= 10.0:
		fp_moved = true
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
		KEY_ENTER, KEY_KP_ENTER:
			if fp_stroking or fp_drag >= 0 or fp_box:
				return true   # 拖曳中按 Enter 不做事，免得蓋掉這一筆（Codex 實作第 2 輪新問題 1）
			# 自由模式：在鍵盤／手把游標處放一隻（格子查找不能用，Codex 實作第 1 輪 #9）
			var at: Vector2i = Vector2i(fp_cur) if (pad_mode or not _fp_in_field(mouse)) else _w_of(mouse)
			_fs_begin(at)
			_fs_commit()
			return true
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
	if stick.length() > maxf(0.05, int(Save.s("deadzone")) / 100.0):   # V1.5：死區照設定（預設 20%）
		# 平滑游標＋輕推時減速（微調）
		var sp := 5200.0 * pow(stick.length(), 2.0)
		fp_cur += stick.normalized() * sp * delta
		fp_cur.x = clampf(fp_cur.x, 200.0, fld_w - 200.0)
		fp_cur.y = clampf(fp_cur.y, 200.0, fld_h - 200.0)
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
			# 手把：A 和滑鼠左鍵同一套（點兵＝搬、按住 LT＝框選、其他＝畫筆）
			if pressed:
				fp_pad_a = true
				_fp_press(_fp_scr(w), w, Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT) > 0.5)
			else:
				fp_pad_a = false
				_fp_release(_fp_scr(w), w)
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
				fp_cur.x = clampf(fp_cur.x, 200.0, fld_w - 200.0)
				fp_cur.y = clampf(fp_cur.y, 200.0, fld_h - 200.0)
				if fp_stroking:
					_fs_extend(Vector2i(fp_cur))   # 按住 A＋十字鍵也能畫（Antigravity 實作第 1 輪 #4）
				elif fp_pad_x:
					_fp_erase_at(Vector2i(fp_cur))
				return true
	return false

# ───────── 畫面 ─────────
## 部署區、中線對峙帶、（全場）敵兵禁區。
func _fp_draw_zones() -> void:
	var a = _fp_army()
	var dep: int = a.depth
	var tc := Art.team_color(a.team, cbm())
	if dep < 15000:
		var x0: float = ORIGIN.x + (dep / 1000.0 if a.team == 0 else (a.fw - dep) / 1000.0) * CS
		_chalk_line(Vector2(x0, ORIGIN.y), Vector2(x0, ORIGIN.y + fld_size.y), Color(tc, 0.8), 3.0, 8.0)
		# 對峙帶（中線兩側到兩邊部署區的邊）
		var other: int = rules.depth_of() if rules != null and rules.fullfield == 0 else (rules.depth if rules != null else 6000)
		var xa: float = ORIGIN.x + other / 1000.0 * CS
		var xb: float = ORIGIN.x + (a.fw - other) / 1000.0 * CS
		if xb > xa:
			draw_rect(Rect2(xa, ORIGIN.y, xb - xa, fld_size.y), Color(0.85, 0.75, 0.55, 0.10))
	# 全場：敵兵 1.5 格禁區融合成一片均勻淡紅，只畫在戰場內（Antigravity 實作第 1 輪 #6）。
	# 0.125 格點陣，同一列連續的格子併成一個長方形；敵兵位置不變就用快取。
	if not a.enemy_pos.is_empty():
		var key: int = hash([a.enemy_pos, a.enemy_gap])
		if key != fp_zone_key:
			fp_zone_key = key
			fp_zone_rects = _fp_zone_raster(a.enemy_pos, a.enemy_gap)
		for r in fp_zone_rects:
			draw_rect(r, Color(1, 0.25, 0.25, 0.16))

func _fp_zone_raster(ep: Array, gap: int) -> Array:
	var out: Array = []
	var cell := 125
	var g2 := gap * gap
	for j in fld_h / cell:
		var cy := j * cell + cell / 2
		var run := -1
		for i in fld_w / cell + 1:
			var hit := false
			if i < fld_w / cell:
				var cx := i * cell + cell / 2
				for e in ep:
					var dx: int = e.x - cx
					var dy: int = e.y - cy
					if dx * dx + dy * dy < g2:
						hit = true
						break
			if hit and run < 0:
				run = i
			elif not hit and run >= 0:
				out.append(Rect2(ORIGIN + Vector2(run * cell, j * cell) / 1000.0 * CS, Vector2((i - run) * cell, cell) / 1000.0 * CS))
				run = -1
	return out

## 畫筆預覽時，頂部金幣條上預扣的那一段畫斜線（§4.3）。
func _fp_gold_preview(gb: Rect2, a) -> void:
	if not fp_stroking or fp_stroke.is_empty():
		return
	var cost := 0
	for it in fp_stroke:
		cost += D.cost(int(it[0]))
	var x0: float = gb.position.x + gb.size.x * float(a.spent()) / maxf(1.0, a.budget)
	var w: float = minf(gb.end.x - x0, gb.size.x * float(cost) / maxf(1.0, a.budget))
	draw_rect(Rect2(x0, gb.position.y, w, gb.size.y), Color(ACCENT, 0.35))
	var k := 0.0
	while k < w + gb.size.y:
		var p0 := Vector2(x0 + k, gb.end.y)
		var p1 := Vector2(x0 + k + gb.size.y, gb.position.y)
		if p0.x <= x0 + w:
			draw_line(Vector2(maxf(p0.x, x0), p0.y - maxf(0.0, x0 - p0.x)), Vector2(minf(p1.x, x0 + w), p1.y + maxf(0.0, p1.x - x0 - w)), ACCENT, 1.5)
		k += 5.0

## 自由模式的兵、預覽、占地圈、選取、框選、對齊點陣、工具列。
func _fp_draw() -> void:
	_fp_clean_sel()
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
			if ar == a and (i == fp_drag or (fp_drag >= 0 and fp_sel.size() > 1 and fp_drag in fp_sel and i in fp_sel)):
				continue   # 搬移中：原位置不畫（整群一起藏，Antigravity 實作第 2 輪）
			var w: Vector2i = ar.pos_of(ar.units[i])
			lst.append([w.y, w.x, int(ar.units[i]["type"]), ar.team, ar == a and i in fp_sel])
	lst.sort()
	# 占地圈：只在拖曳或懸停時出現（Antigravity）
	var hover_w: Vector2i = Vector2i(fp_cur) if pad_mode else _w_of(mouse)   # 手把＝準星（Antigravity 實作第 3 輪，未經複查）
	if hide_side >= 0:
		call("_draw_hide_fog", hide_side)   # 第七輪：自由模式也要有迷霧與「敵陣開戰才看得到」，原本右半場空著像沒做完
	for it in lst:
		var w := Vector2i(it[1], it[0])
		if it[3] == a.team and (drag_on or Vector2(w - hover_w).length() < 1500):   # 第七輪 D8：範圍縮小減噪
			_fp_dashed_circle(_s_of(w) - Vector2(0, 0.32 * CS), a.spacing / 2000.0 * CS, Color(1, 1, 1, 0.35))
	for it in lst:
		var p := _s_of(Vector2i(it[1], it[0]))
		_ring(p, it[3], it[2])
		var sd := _settle_dy(Vector2i(it[1], it[0]))
		_unit(p + Vector2(0, sd), it[2], it[3], 1.0 if it[3] == 0 else -1.0, 0.0, 0.0, 0.0, 1.0, time + it[1] * 0.001, 1.0)
		if it[4]:
			_hand_ring(p - Vector2(0, 2), 24, ACCENT, 2.5, true)
		# 全場：擺到敵方半場的兵畫開戰朝向箭頭（會先往敵方底線走）
		if rules != null and rules.fullfield != 0 and ((it[3] == 0 and it[1] > 8000) or (it[3] == 1 and it[1] < 8000)):
			var dir := 1.0 if it[3] == 0 else -1.0
			var b0 := p + Vector2(-10 * dir, 10)
			draw_line(b0, b0 + Vector2(22 * dir, 0), Color(1, 1, 1, 0.8), 2.0)
			draw_colored_polygon(PackedVector2Array([b0 + Vector2(22 * dir, -5), b0 + Vector2(30 * dir, 0), b0 + Vector2(22 * dir, 5)]), Color(1, 1, 1, 0.8))
	# V1.1 C5：密陣被下排蓋到臉的補畫半透明
	var xr: Array = []
	for it3 in lst:
		xr.append([_s_of(Vector2i(it3[1], it3[0])), [it3[2], it3[3], 1.0 if it3[3] == 0 else -1.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0]])
	_draw_xray(xr)
	# 密集處：游標附近每隻兵的腳底中心點透到最上層（§4.3，看得出誰站哪）
	if _fp_in_field(mouse) or pad_mode:
		var hw: Vector2i = Vector2i(fp_cur) if pad_mode else hover_w
		for it in lst:
			if Vector2(Vector2i(it[1], it[0]) - hw).length() < 1800:
				var fp := _s_of(Vector2i(it[1], it[0])) - Vector2(0, 0.32 * CS)
				draw_circle(fp, 3.0, Color(0, 0, 0, 0.7), true, -1.0, true)
				draw_circle(fp, 2.0, Art.team_color(it[3], cbm()), true, -1.0, true)
	# 搬移中的那一隻
	if fp_drag >= 0 and fp_drag < a.units.size():
		var tgt := _q(Vector2i(fp_cur) if pad_mode else _w_of(mouse))
		var face := 1.0 if a.team == 0 else -1.0
		if fp_sel.size() > 1 and fp_drag in fp_sel:
			# 整群：照位移畫全部的預覽（Antigravity 實作第 1 輪 #3）
			var dv: Vector2i = tgt - fp_drag_from
			var trial = a.copy()
			var mv: Vector2i = trial.move_group(fp_sel, dv.x, dv.y)
			var ok_g: bool = mv.x != -99999
			if ok_g:
				dv = mv   # 用實際（貼邊夾限後）的位移畫，預覽＝落點（Codex 實作第 2 輪新問題 2）
			for i in fp_sel:
				var np: Vector2i = a.pos_of(a.units[i]) + dv
				_lift_shadow(_s_of(np))
				_unit(_s_of(np) - Vector2(0, LIFT_PX), int(a.units[i]["type"]), a.team, face, 0.0, 0.0, 0.0, 0.55 if ok_g else 0.25, time, 1.0, Art.M_SURPRISE)
		else:
			var ok_m: bool = a.check_place_xy(int(a.units[fp_drag]["type"]), tgt.x, tgt.y, fp_drag) == ""
			_lift_shadow(_s_of(tgt))
			_unit(_s_of(tgt) - Vector2(0, LIFT_PX), int(a.units[fp_drag]["type"]), a.team, face, 0.0, 0.0, 0.0, 0.6 if ok_m else 0.3, time, 1.0, Art.M_SURPRISE)   # V1.3.1：被抓起來的驚訝臉
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
			# 分清楚是錢、人數還是這一手用完，並寫出剩多少（Antigravity 實作第 1 輪 #8）
			match fp_full_why:
				"cap":
					tip += "　" + L.t("fp_full_cap")
				"hand":
					tip += "　" + L.t("fp_full_hand")
				_:
					tip += "　" + L.t("fp_full_gold", [a.budget - a.spent() - cost])
		# 多隻預覽：只畫第一隻和最後一隻的射程（§4.3）
		var rr := _fp_range_of(selected)
		if rr > 0.0 and fp_stroke.size() > 0:
			for it in [fp_stroke[0], fp_stroke[fp_stroke.size() - 1]]:
				call("_arc_clipped", _s_of(Vector2i(it[1], it[2])) - Vector2(0, 0.32 * CS), rr * CS, 0, TAU, Color(1, 0.9, 0.5, 0.35), 1.5)
		var anchor := _fp_scr(Vector2i(fp_cur)) if pad_mode else mouse
		var bw := _width(tip, tz("S"), true) + 16
		var bp := Vector2(clampf(anchor.x + 18, ORIGIN.x, ORIGIN.x + fld_size.x - bw), clampf(anchor.y - 36, ORIGIN.y, ORIGIN.y + fld_size.y - tz("S") * 1.6))
		draw_rect(Rect2(bp, Vector2(bw, tz("S") * 1.6)), Color(0.06, 0.07, 0.1, 0.9))
		_text(bp + Vector2(8, tz("S") * 0.25), tip, tz("S"), ACCENT if not fp_full else Color("#ff8a8a"), false, true)
	# 框選
	if fp_box:
		var r := Rect2(fp_box_a, Vector2.ZERO).expand(_fp_scr(Vector2i(fp_cur)) if pad_mode else mouse)
		draw_rect(r, Color(ACCENT, 0.12))
		draw_rect(r, ACCENT, false, 1.5)
	# 對齊點陣：只在游標附近 3×3 格淡出
	if _snap_on() and (_fp_in_field(mouse) or pad_mode):
		var c := _q(hover_w)
		for gx in range(-3, 4):
			for gy in range(-3, 4):
				var w2 := c + Vector2i(gx * 500, gy * 500)
				if w2.x >= 200 and w2.x <= fld_w - 200 and w2.y >= 200 and w2.y <= fld_h - 200:
					draw_circle(_s_of(w2) - Vector2(0, 0.32 * CS), 2.0, Color(1, 1, 1, 0.35 - 0.04 * (absi(gx) + absi(gy))), true, -1.0, true)
	# 游標（滑鼠在兵上＝搬移游標；手把＝準星）
	if not fp_stroking and fp_drag < 0 and _fp_in_field(mouse) and not pad_mode:
		var hi: int = a.index_near(hover_w.x, hover_w.y, PICK_R)
		if hi >= 0 and not _fp_duel_turns():
			var hp := _s_of(a.pos_of(a.units[hi]))
			_hand_ring(hp - Vector2(0, 2), 22, Color(1, 1, 1, 0.8), 2.0)
			_fp_move_icon(mouse + Vector2(14, 14))
		elif fp_touch:
			_fp_reticle(_s_of(_q(hover_w)))
	if pad_mode:
		_fp_reticle(_s_of(_q(Vector2i(fp_cur))))   # 準星畫在量化後的落點
	# 精簡版戰術預覽（第六輪）：游標處選中兵種的射程／作用範圍；畫筆拖曳中不畫，免得擋住預覽
	if not drag_on and (_fp_in_field(mouse) or pad_mode):
		var cw: Vector2i = _q(hover_w)
		var cp := _s_of(cw) - Vector2(0, 0.32 * CS)
		var rad := _fp_range_of(selected)
		if rad > 0.0:
			call("_arc_clipped", cp, rad * CS, 0, TAU, Color(1, 0.9, 0.5, 0.45), 2.0)
			# 第七輪 N8：弧線要說得出是什麼
			var lbl: String = L.t("fp_range_tag", [_fmt_num(rad)])
			var lx := clampf(cp.x, ORIGIN.x + 40, ORIGIN.x + fld_size.x - 40)
			var ly := clampf(cp.y - rad * CS - tz("C") * 1.2, ORIGIN.y + 2, ORIGIN.y + fld_size.y - tz("C") * 1.3)
			_text(Vector2(lx, ly), lbl, tz("C"), Color(1, 0.93, 0.6, 0.95), true, true)
	if not drag_on and selected == 15 and (_fp_in_field(mouse) or pad_mode):
		_doll_lane(_s_of(_q(hover_w)) - Vector2(0, 0.32 * CS), a.team)   # 巫毒娃娃：瞄準線
	_fp_gesture()
	_fp_toolbar()
	_fp_intro_steps(a)

## 自由排兵入門（第七輪 A4）：一次只講一步，做到就換下一步。
func _fp_intro_steps(a) -> void:
	if not free_intro:
		return
	var step := "intro_s1"
	if a.units.size() >= 4:
		step = "intro_s3" if free_intro_moved else "intro_s2"
	var msg: String = L.t(step + "_pad", [_pk("start") if step == "intro_s3" else _pk("place")]) if pad_mode else L.t(step)
	var w := minf(_width(msg, tz("B"), true) + 40, 900.0)
	var r := Rect2(640 - w / 2, ORIGIN.y + 8, w, text_h(msg, tz("B"), w - 24, true) + 14)
	draw_rect(r, Color(TH_WOOD_D, 0.94))
	draw_rect(r, ACCENT, false, 2.0)
	_text(Vector2(640, r.position.y + 6), msg, tz("B"), ACCENT, true, true, w - 24)

## 巫毒娃娃的瞄準走廊：前方、同列 ±1.5 格。
func _doll_lane(p: Vector2, team: int) -> void:
	var dir := 1.0 if team == 0 else -1.0
	var end_x: float = ORIGIN.x + fld_size.x if team == 0 else ORIGIN.x
	var half := 1.5 * CS
	var top := maxf(p.y - half, ORIGIN.y)
	var bot := minf(p.y + half, ORIGIN.y + fld_size.y)
	var x0: float = minf(p.x, end_x)
	var w := absf(end_x - p.x)
	draw_rect(Rect2(x0, top, w, bot - top), Color(1.0, 0.42, 0.7, 0.08))
	_chalk_line(p, Vector2(end_x, p.y), Color(1.0, 0.42, 0.7, 0.75), 2.5, 9.0)
	draw_colored_polygon(PackedVector2Array([p + Vector2(40 * dir, -7), p + Vector2(40 * dir, 7), p + Vector2(54 * dir, 0)]), Color(1.0, 0.42, 0.7, 0.75))

## 新手手勢：前排從上往下一隻手拖過去，後面依間距冒出半透明小兵，1.5 秒。
func _fp_gesture() -> void:
	if fp_gesture_at < 0.0:
		return
	var k: float = (time - fp_gesture_at) / 1.5
	if k >= 1.0 or k < 0.0:
		fp_gesture_at = -1.0
		return
	var a = _fp_army()
	var ox: int = maxi(Army.EDGE, a.depth - 600)
	var y0 := 2500.0
	var y1 := 6500.0
	var yc := lerpf(y0, y1, k)
	var y := y0
	while y <= yc:
		_unit(_s_of(Vector2i(a.world_x(ox), int(y))), selected, a.team, 1.0 if a.team == 0 else -1.0, 0.0, 0.0, 0.0, 0.45, time, 1.0)
		y += a.spacing
	var hp := _s_of(Vector2i(a.world_x(ox), int(yc))) + Vector2(10, -10)
	draw_circle(hp, 14.0, Color(1, 1, 1, 0.25 * (1.0 - k) + 0.25), true, -1.0, true)
	_hand_ring(hp, 14.0, Color(1, 1, 1, 0.9), 2.0)
	_text(hp + Vector2(20, -tz("S") * 0.6), L.t("fp_gesture"), tz("S"), Color.WHITE, false, true)

func _fp_range_of(t: int) -> float:
	match t:
		D.ARCHER:
			return 6.0
		D.PIKE:
			return D.STATS[D.PIKE]["reach"] / 1000.0
		D.MEDIC:
			return D.HEAL_RANGE / 1000.0
		D.DRUMMER:
			return D.DRUM_RANGE / 1000.0
		10:
			return 2.2     # 孢子菇毒圈
		11:
			return 1.5     # 爆爆羊爆炸
		16:
			return 2.5     # 沙漏結界
		17:
			return 4.0     # 骷髏法師
		18:
			return 3.5     # 吸塵貓
		19:
			return 1.2     # 石魔拍地
	return 0.0

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
	_hand_ring(p - Vector2(0, 2), 14, ACCENT, 2.0)
	draw_line(p + Vector2(-20, -2), p + Vector2(-8, -2), ACCENT, 2.0)
	draw_line(p + Vector2(8, -2), p + Vector2(20, -2), ACCENT, 2.0)

## 工具列：戰場左邊的直排工具列（Antigravity 第二輪：右下放不下）。點＝切換常駐；按住 Shift／Ctrl／G＝暫時。
func _fp_toolbar() -> void:
	draw_set_transform_matrix(Transform2D.IDENTITY)   # V9：工具列不跟著地圖縮放
	_box(Rect2(4, 92, 120, 420), Color(TH_WOOD_D, 0.82), TH_EDGE.darkened(0.3), 8.0, 1.5)
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
	var y := ORIGIN.y + 48   # 讓開上方說明條（150% 時會換成兩行）
	# 第七輪 N7：三種性質分組，長得不一樣：模式（三選一，亮底）／開關（右邊有燈）／單次動作（暗底）
	var extra := 0
	var prev_g := -1
	for it in items:
		var g0: int = 0 if it[0] in ["brush", "line", "select"] else (1 if it[0] in ["snap", "dense"] else 2)
		if prev_g >= 0 and g0 != prev_g:
			extra += 10
		prev_g = g0
	draw_rect(Rect2(x - 4, y - 4, w + 8, items.size() * 46 + 4 + extra), Color(0.06, 0.07, 0.1, 0.8))
	prev_g = -1
	for k in items.size():
		var id: String = items[k][0]
		var g: int = 0 if id in ["brush", "line", "select"] else (1 if id in ["snap", "dense"] else 2)
		if prev_g >= 0 and g != prev_g:
			draw_line(Vector2(x, y + 2), Vector2(x + w, y + 2), Color(1, 1, 1, 0.25), 1.0)
			y += 10
		prev_g = g
		var on: bool = (id == fp_tool) or (id == "snap" and fp_snap) or (id == "dense" and fp_dense)
		var cb := func(): _fp_tool_click(id)
		var tint := TH_ACTIVE if (g == 0 and on) else (Color(0.1, 0.11, 0.15, 0.95) if g == 2 else Color(0.14, 0.15, 0.2, 0.9))
		_btn(Rect2(x, y, w, 40), items[k][1], cb, true, false, tint)
		if g == 0 and on:
			draw_rect(Rect2(x, y, 4, 40), ACCENT)
		elif g == 1:
			draw_circle(Vector2(x + w - 7, y + 7), 3.5, ACCENT if on else Color(1, 1, 1, 0.25), true, -1.0, true)
		y += 46
	draw_set_transform_matrix(_cam)

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
	fp_zone_key = -1
	_fs_cancel()
	fp_drag = -1
	fp_sel = []
	fp_box = false
	fp_erasing = false
	fp_undo = []
	fp_redo = []
	fp_cur = Vector2(3500, 4500)
	# 新手手勢（§4.4）：第一次進自由擺放，示範一次「按住拖一排」1.5 秒
	fp_gesture_at = -1.0
	if _is_free() and not bool(Save.data.get("seen_fp_gesture", false)) and shot_dir == "":
		Save.data["seen_fp_gesture"] = true
		fp_gesture_at = time
