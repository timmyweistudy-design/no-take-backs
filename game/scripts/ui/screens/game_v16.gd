extends "res://scripts/ui/screens/game_menus.gd"
## V1.6.0 介面層（docs/2026-11-10-v1.6.0-plan.md）：新手下一步、試玩回報、分享、教練、極速賽、裂隙、人設、熟練度、實驗簿、出題台、一陣三考、迷霧、接力遠征。
## 純邏輯放 scripts/game/v16_*.gd（可測），這裡只管畫面與流程。

const Funnel = preload("res://scripts/game/v16_funnel.gd")

## ── #2 真人試玩：所在畫面名稱、回報（存檔＋複製到剪貼簿）、離開時記最後的畫面 ──
func screen_id() -> String:
	if overlay != "":
		return overlay
	return ["title", "place", "battle", "result"][state] + ("" if state == St.TITLE else ":" + ["ai", "duel", "tutorial", "puzzle", "gauntlet"][mode])

func _feedback() -> void:
	var txt := Funnel.report(str(ProjectSettings.get_setting("application/config/version")), screen_id())
	var name := "user://%sreport_%d.json" % [Save.file_prefix(), int(Time.get_unix_time_from_system())]
	var f := FileAccess.open(name, FileAccess.WRITE)
	if f != null:
		f.store_string(txt)
		f.close()
	DisplayServer.clipboard_set(txt)
	_toast(L.t("fb_done"))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit_mark()

func _quit_mark() -> void:
	Funnel.leave(screen_id())
	Save.save_data()

## 每幀：打開過的畫面記一次里程碑（只有第一次會寫）
const FUNNEL_OVERLAYS := {"tutorial": "tutorial_open", "puzzles": "puzzle_open", "playroom": "playroom_open", "settings": "settings_open"}
var _fn_last := ""
func _v16_tick(_delta: float) -> void:
	var sid := overlay if overlay != "" else str(state)
	if sid != _fn_last:
		_fn_last = sid
		if FUNNEL_OVERLAYS.has(overlay):
			Funnel.mark(FUNNEL_OVERLAYS[overlay])
		if state == St.PLACE:
			match mode:
				Mode.GAUNTLET:
					Funnel.mark("gauntlet_open")
				Mode.VS_AI:
					if not (get("daily_spec") as Dictionary).is_empty():
						Funnel.mark("daily_open")
	_hold_tick(_delta)
	_rush_tick(_delta)
	_coop_tick()
	if fog_on and state == St.PLACE and mode == Mode.VS_AI and not ai_prebuilt:
		call("_build_ai")   # 迷霧推演的下一局：一樣先組好
		ai_prebuilt = true
	_v16_jobs(_delta)

func _open_codex(t: int) -> void:
	Funnel.mark("codex_open")
	super._open_codex(t)

func _finish_battle() -> void:
	super._finish_battle()
	if play_kind != "official" or sim == null:
		return
	if bool(rush.get("on", false)) and mode == Mode.PUZZLE:
		_rush_settle()
		return
	if trio_on and mode == Mode.PUZZLE:
		_trio_settle()
	_rift_settle()
	_persona_result()
	_career_settle()
	Funnel.mark("first_battle")
	if mode != Mode.DUEL:
		var won: bool = sim.winner == 0
		Funnel.mark("first_win" if won else "first_loss")
		if mode == Mode.TUTORIAL and won:
			Funnel.mark("tutorial_done")
		if mode == Mode.PUZZLE and puzzle_id != "ws" and (won or bool(report.get("goal_ok", false))):
			Funnel.mark("puzzle_clear")   # 工坊、一陣三考不算（三考只打了第一場，Antigravity v160-i2 #4）
	if Guide.demo_end_due(Save.data, _demo(), demo_end_shown):
		demo_end_shown = true
		Funnel.mark("demo_end")
		overlay = "demo_end"   # 試玩版結尾：完整版有什麼＋願望單

## ── #1 新手：建議下一步、新入口標記、試玩版結尾 ──
func _daily_done_today() -> bool:
	if _demo():
		return true
	var sp: Dictionary = Daily.spec(Daily.today())
	return not (Save.data.get("daily_best", {}).get(sp["key"], []) as Array).is_empty()

func _next_action(k: String) -> Callable:
	match k:
		"tut":
			return func(): _open("tutorial")
		"ai":
			return func(): _open_lobby("ai")
		"puzzle":
			return func(): _open("puzzles")
		"daily":
			return func(): call("_start_daily")
		"gauntlet":
			return func(): _enter_gauntlet()
		"playroom":
			return func(): overlay = "playroom"; _focus = 0
		"trials":
			return func(): _open("trials")
	return func(): pass

func _draw_next_step() -> void:
	if Save.s("hints") == "off" or overlay != "":
		return
	var k := Guide.next_step(Save.data, _daily_done_today(), _demo())
	if k == "":
		return
	# 右上角（示範戰場上方的空白）；高度照字級算
	var NS_RECT := Rect2(830, 104, 400, ceilf(14.0 + tz("C") * 1.25 + tz("S") * 1.35))
	_btn(NS_RECT, "", _next_action(k), true, false, Color(0.16, 0.3, 0.42, 0.95))
	_icon("flag", NS_RECT.position + Vector2(30, NS_RECT.size.y / 2), 26.0, ACCENT)
	_text(NS_RECT.position + Vector2(56, 6), L.t("ns_head"), tz("C"), TXT_DIM, false, false, NS_RECT.size.x - 70)
	_text(NS_RECT.position + Vector2(56, 6 + tz("C") * 1.25), L.t("ns_" + k), tz("S"), Color.WHITE, false, true, NS_RECT.size.x - 70)

## 「新」小牌：貼在卡片右上角內側（九宮格羊皮紙＋墨字，不只靠顏色）
func _new_tag(r: Rect2) -> void:
	var w := _width(L.t("new_tag"), tz("C"), true) + 20.0
	var tr := Rect2(r.end.x - w - 8.0, r.position.y + 8.0, w, tz("C") * 1.5 + 4.0)
	_tex_box(tr, "wood", Color("#b8322a"))
	_text(tr.position + Vector2(10, 2 + tz("C") * 0.2), L.t("new_tag"), tz("C"), Color.WHITE, false, true, w)

var demo_end_shown := false
func _draw_demo_end() -> void:
	var body := L.t("de_body", [20, 120, 30])
	var P := modal_rect(680, 12.0 + h1_bottom(0.0) + GAP_L + text_h(body, tz("S"), 600) + GAP_XL + 52.0 + GAP_M + 44.0 + GAP_L)
	_panel(P)
	var y := _h1(Vector2(640, P.position.y + 12), L.t("de_title")) + GAP_L
	_text(Vector2(P.position.x + 40, y), body, tz("S"), Color.WHITE, false, false, 600)
	y += text_h(body, tz("S"), 600) + GAP_XL
	var url: String = SteamApi.STORE_URL
	_btn(Rect2(640 - 200, y, 400, 52), L.t("demo_wish_btn") if url != "" else L.t("demo_wish_soon"), func(): OS.shell_open(url), url != "", true)
	_btn(Rect2(640 - 120, y + 52 + GAP_M, 240, 44), L.t("de_keep"), func(): overlay = "")

func _draw_v16_overlay(name: String) -> void:
	match name:
		"demo_end":
			_draw_demo_end()
		"share":
			_draw_share()
		"rush_end":
			_draw_rush_end()
		"coach":
			_draw_coach()
		"rift":
			_draw_rift()
		"notebook":
			_draw_notebook()
		"daily_top":
			_draw_daily_top()
		"editor":
			_draw_editor()
		"trio":
			_draw_trio()
		"trio_result":
			_draw_trio_result()
		"coop_hand":
			_draw_coop_hand()

## ── #6 戰術可視化：擺陣時「射程覆蓋」（V 鍵或資訊帶按鈕），「標記」最多 3 隻（T 鍵或按鈕後點兵），觀戰時追蹤 ──
var tv_range := false
var tv_mark_mode := false
var tv_marks: Array = []      # 標記的兵：世界座標（Vector2i，開戰時對到模擬的兵）
var tv_ids: Array = []
var tv_mode_key := ""        # 這一場對到的模擬 id（順序＝標記號碼）
const TV_MAX := 3

func _tv_pos_list(a) -> Array:
	var out: Array = []
	for u in a.units:
		out.append(a.pos_of(u))
	return out

## 標記：world 附近的我方兵（沒有就不動）；已標記就取消；滿 3 隻擠掉最早的
func tv_toggle_at(a, w: Vector2i) -> bool:
	var i: int = a.index_near(w.x, w.y, 600)
	if i < 0:
		return false
	var p: Vector2i = a.pos_of(a.units[i])
	var k := tv_marks.find(p)
	if k >= 0:
		tv_marks.remove_at(k)
	else:
		if tv_marks.size() >= TV_MAX:
			tv_marks.remove_at(0)
		tv_marks.append(p)
	return true

func _tv_world_at(p: Vector2) -> Vector2i:
	if _is_free():
		return _w_of(p)
	var c := _cell_at(p)
	return Vector2i(c.x * 1000 + 500, c.y * 1000 + 500)

func _v16_place_click(p: Vector2) -> bool:
	if not tv_mark_mode or not Rect2(ORIGIN, fld_size).has_point(p):
		return false
	tv_toggle_at(_cur_army(), _tv_world_at(p))
	sfx.play("k_click", 0.7)
	return true

## 手把：游標所在的世界座標（格子用 cursor，自由用 fp_cur）
func _tv_pad_world() -> Vector2i:
	if _is_free():
		return Vector2i(fp_cur)
	return Vector2i(cursor.x * 1000 + 500, cursor.y * 1000 + 500)

func _v16_place_key(k: int) -> bool:
	if tv_mark_mode and pad_mode and k == KEY_ENTER:
		if tv_toggle_at(_cur_army(), _tv_pad_world()):
			sfx.play("k_click", 0.7)
		return true   # 標記模式：手把 A＝標記（不擺兵）
	match k:
		KEY_V:
			tv_range = not tv_range
			return true
		KEY_N:
			if _nb_key() != "":
				overlay = "notebook"
				_focus = 0
				return true
			return false
		KEY_T:
			if tv_toggle_at(_cur_army(), _tv_pad_world() if pad_mode else _tv_world_at(mouse)):
				sfx.play("k_click", 0.7)
			return true
	return false

## 資訊帶右邊（「?」左邊）兩顆小鈕
func _tv_buttons(help: Rect2, notebook := false) -> void:
	var b1 := Rect2(help.position.x - 88, help.position.y, 40, 36)
	var b2 := Rect2(help.position.x - 44, help.position.y, 40, 36)
	if notebook:
		b1.position.x -= 44
		b2.position.x -= 44
		var b3 := Rect2(help.position.x - 44, help.position.y, 40, 36)
		_btn(b3, "", func(): overlay = "notebook"; _focus = 0)
		_icon("book", b3.get_center(), 22.0, Color.WHITE)
		if b3.has_point(mouse):
			_tv_tip(L.t("nb_tip"), help)
	_btn(b1, "", func(): tv_range = not tv_range, true, false, TH_ACTIVE if tv_range else Color(0, 0, 0, 0))
	_icon("range", b1.get_center(), 22.0, Color.WHITE)
	_btn(b2, "", func(): tv_mark_mode = not tv_mark_mode, true, false, TH_ACTIVE if tv_mark_mode else Color(0, 0, 0, 0))
	_icon("flag", b2.get_center(), 22.0, Color.WHITE)
	if b1.has_point(mouse) or b2.has_point(mouse):
		_tv_tip(L.t("tv_range_tip") if b1.has_point(mouse) else L.t("tv_mark_tip"), help)

func _tv_tip(tip: String, help: Rect2) -> void:
	if true:
		var tw := _width(tip, tz("S")) + 20.0
		var tr := Rect2(clampf(mouse.x - tw / 2, 8, 1272 - tw), help.end.y + 6, tw, tz("S") * 1.6)
		draw_rect(tr, Color(0.06, 0.07, 0.1, 0.92))
		_text(tr.position + Vector2(10, tz("S") * 0.25), tip, tz("S"), Color.WHITE, false, false, tw)

func _foot_of(w: Vector2i) -> Vector2:
	return ORIGIN + Vector2(w.x / 1000.0, w.y / 1000.0 + 0.32) * CS

## 擺陣畫面疊層：射程覆蓋（我方每隻有射程的兵畫淡圈；看得到敵兵時，每隻兵朝最近敵兵畫短箭頭）＋標記號碼
func _v16_place_draw() -> void:
	var a = _cur_army()
	if tv_range:
		var foes: Array = []
		if _enemy_visible() and armies.size() > 1 and mode != Mode.DUEL:
			foes = _tv_pos_list(armies[1])
		for u in a.units:
			var p: Vector2i = a.pos_of(u)
			var sp := _foot_of(p) - Vector2(0, 0.32 * CS)
			var rr: float = _fp_range_of(int(u["type"]))
			if rr > 0.0:
				draw_circle(sp, rr * CS, Color(1, 0.9, 0.5, 0.05))
				call("_arc_clipped", sp, rr * CS, 0, TAU, Color(1, 0.9, 0.5, 0.3), 1.2)
		if not foes.is_empty():
			# V1.6.1 A9：開場鎖定（用模擬跑 1 tick 的選目標結果，不是「最近的敵兵」）；虛線弧，白黑雙邊。不保證第一下打到它（之後會換目標）。
			for pr in _lock_pairs(a, armies[1]):
				_lock_arc(_foot_of(pr[0]) - Vector2(0, 0.32 * CS), _foot_of(pr[1]) - Vector2(0, 0.32 * CS))
	_tv_draw_marks_place(a)
	_fog_draw()
	_adj_draw(a)

## [[我方位置, 鎖定的敵兵位置], …]（雙方陣型沒變就用快取，不每幀重算）
var lock_key := 0
var lock_cache: Array = []
func _lock_pairs(a0, a1) -> Array:
	if a0 == null or a1 == null or a0.units.is_empty() or a1.units.is_empty():
		return []
	var rr = PZ.rules_of(PZ.get_puzzle(puzzle_id)) if mode == Mode.PUZZLE else rules
	var key := hash([a0.units, a1.units, rr.to_code() if rr != null else ""])
	if key == lock_key:
		return lock_cache
	lock_key = key
	lock_cache = lock_targets(a0, a1, rr)
	return lock_cache

static func lock_targets(a0, a1, rr) -> Array:
	var s = Sim.new(a0.copy(), a1.copy(), rr)
	var start: Array = []
	for u in s.units:
		start.append(Vector2i(u.x, u.y))
	s.step()
	var out: Array = []
	for i in s.units.size():
		var u = s.units[i]
		if u.team == 0 and u.target >= 0 and u.target < start.size() and s.units[u.target].team == 1:
			out.append([start[i], start[u.target]])
	return out

func _lock_arc(a: Vector2, b: Vector2) -> void:
	var mid := (a + b) / 2.0 + (b - a).orthogonal().normalized() * minf(40.0, a.distance_to(b) * 0.18)
	var cb := bool(Save.s("colorblind"))
	var n := 14
	for k in n:
		if k % 2 == 1:
			continue   # 虛線
		var t0 := float(k) / n
		var t1 := float(k + 1) / n
		var p0 := a.lerp(mid, t0).lerp(mid.lerp(b, t0), t0)
		var p1 := a.lerp(mid, t1).lerp(mid.lerp(b, t1), t1)
		draw_line(p0, p1, Color(0, 0, 0, 0.55), 4.0 if cb else 3.0, true)
		draw_line(p0, p1, Color(1, 0.95, 0.8, 0.85 if cb else 0.6), 2.0 if cb else 1.4, true)
	draw_circle(b, 4.0, Color(0, 0, 0, 0.6))
	draw_circle(b, 2.6, Color(1, 0.95, 0.8, 0.9))

func _chalk_arrow(a: Vector2, b: Vector2) -> void:
	draw_line(a, b, Color(1, 1, 1, 0.55), 2.0, true)
	var d := (b - a).normalized()
	draw_line(b, b - d.rotated(0.5) * 8.0, Color(1, 1, 1, 0.55), 2.0, true)
	draw_line(b, b - d.rotated(-0.5) * 8.0, Color(1, 1, 1, 0.55), 2.0, true)

func _tv_badge(at: Vector2, n: int, dead := false) -> void:
	var r := Rect2(at - Vector2(11, 11), Vector2(22, 22))
	draw_rect(r, Color(0.1, 0.1, 0.12, 0.9) if not dead else Color(0.3, 0.3, 0.3, 0.8))
	draw_rect(r, ACCENT if not dead else Color(0.7, 0.7, 0.7), false, 2.0)
	_text(r.position + Vector2(11, 1), str(n) if not dead else "×", tz("C"), Color.WHITE, true, true)

func _tv_draw_marks_place(a) -> void:
	var have := _tv_pos_list(a)
	tv_marks = tv_marks.filter(func(m): return have.has(m))   # 被拿掉的兵自動取消標記
	for i in tv_marks.size():
		_tv_badge(_foot_of(tv_marks[i]) - Vector2(0, 1.05 * CS), i + 1)

func _begin_battle(a0, a1, kind := "official") -> void:
	super._begin_battle(a0, a1, kind)
	if bool(rush.get("on", false)) and kind == "official":
		call("_on_skip")   # 極速賽：不看戰鬥，直接算結果
	tv_ids = []
	if sim == null or tv_marks.is_empty():
		return
	tv_ids = tv_ids_for(a0, tv_marks)

## 標記的位置 → 模擬的兵 id。開戰時展示緩衝已經讓模擬先跑幾格（位置變了），所以照模擬的編號規則從陣型算：
## 格子＝隊伍×1000＋列×16＋欄；自由＝同隊依 (y, 自己視角 x) 排序的第 k 隻（battle_sim.gd 開頭）。
static func tv_ids_for(a0, marks: Array) -> Array:
	var out: Array = []
	var free: bool = str(a0.deploy) == "free"
	var order: Array = []
	if free:
		for u in a0.units:
			var pp: Vector2i = a0.pos_of(u)
			order.append([pp.y * 100000 + pp.x, pp])
		order.sort_custom(func(p, q): return p[0] < q[0])
	for m in marks:
		if free:
			for k in order.size():
				if order[k][1] == m:
					out.append(k)
					break
		else:
			for u in a0.units:
				if a0.pos_of(u) == m:
					out.append(int(u["row"]) * 16 + int(u["col"]))
					break
	return out

## 戰鬥中：標記的兵頭上號碼；倒下就在最後位置畫灰色 ×
func _v16_battle_draw() -> void:
	if tv_ids.is_empty() or view == null:
		return
	for u in view.units:
		var k := tv_ids.find(u.id)
		if k < 0:
			continue
		var p := _upos(u)
		if u.alive:
			_tv_badge(p - Vector2(0, 1.15 * CS), k + 1)

## ── #7 操作與無障礙：按住確認、文字放大鏡、軍令點選放置 ──
var hold_t := 0.0
var confirm_ok_r := Rect2()
const HOLD_SEC := 0.6

func _hold_tick(delta: float) -> void:
	if overlay != "confirm" or not bool(Save.s("hold_confirm")):
		hold_t = 0.0
		return
	var down: bool = (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and confirm_ok_r.has_point(mouse)) \
		or (_focus == 0 and hold_keys_down(Save.s("keys"), Save.s("pad")))
	hold_t = hold_t + delta if down else 0.0
	if hold_t >= HOLD_SEC:
		hold_t = 0.0
		if pad_mode and int(Save.s("rumble")) > 0:
			Input.start_joy_vibration(last_joy, 0.2, 0.5 * int(Save.s("rumble")) / 100.0, 0.12)   # 確定的那一下輕震
		call("_confirm_go")

## V1.6.1 F4：按住確認看「改鍵後」的放置／開始鍵，任何一支手把的放置鈕（原本寫死 Enter、Space、0 號手把 A）
static func hold_keys_down(keys, pad) -> bool:
	var kt: Dictionary = keys if keys is Dictionary else {}
	var pt: Dictionary = pad if pad is Dictionary else {}
	for act in ["place", "start"]:
		if Input.is_key_pressed(Keymap.key_of(kt, act)):
			return true
	var pb := int(pt.get("place", JOY_BUTTON_A))
	for dev in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(dev, pb):
			return true
	return false

## 放大鏡：游標指到的介面字，在游標旁邊放大 1.8 倍畫一份（不改版面）
func _draw_magnifier() -> void:
	if mag_hit.is_empty():
		return
	var s: String = mag_hit[0]
	var sz := mini(44, int(int(mag_hit[1]) * 1.8))
	var w := minf(_width(s, sz, bool(mag_hit[2])), 1180.0) + 28.0
	var h := sz * 1.5
	var mp := mag_point()
	var at := Vector2(clampf(mp.x - w / 2, 8, 1272 - w), mp.y + 28 if mp.y < 600 else mp.y - 28 - h)
	draw_rect(Rect2(at, Vector2(w, h)), Color(0.04, 0.05, 0.08, 0.96))
	draw_rect(Rect2(at, Vector2(w, h)), ACCENT, false, 2.0)
	var keep := mag_on
	var kp := layout_probe
	mag_on = false
	layout_probe = false   # 放大的那一份是暫時的疊圖，不算版面
	_text(at + Vector2(14, sz * 0.2), s, sz, Color.WHITE, false, bool(mag_hit[2]), 1180.0)
	mag_on = keep
	layout_probe = kp

## ── #5 社群分享包＋B25 結果頁收合：明信片、出題碼、分享格、精華時刻收進一個「分享」面板 ──
const Share = preload("res://scripts/game/v16_share.gd")
var sh_text := ""   # 這一場的分享格（每日或每週才有）

func _share_ready() -> bool:
	return play_kind == "official" and not watch_mode and sim != null

## 每日挑戰贏了：更新連續天數、產生分享格
func _daily_finish(w: int) -> void:
	super._daily_finish(w)
	sh_text = ""
	if (daily_spec as Dictionary).is_empty() or w != 0:
		return
	var day := int(daily_spec.get("day", Daily.today()))   # 跨 UTC 午夜才打完：照開局那天的題（Codex v160-i1 #6）
	var st: Dictionary = Share.streak_after(Save.data.get("daily_streak", {}), day)
	Save.data["daily_streak"] = st
	Save.save_data()
	var rem: int = PZ.rem_pct(sim.power(0), sim.budget_of(0))
	# #13 每日全球榜：贏了就準備上傳（有 Steam 才真的送；沒送成功留著，下次開每日時補送）
	var det: PackedInt32Array = SteamApi.pack_free(last_armies[0].units, 16000)
	if not det.is_empty():
		var prev: Dictionary = Save.data.get("daily_pend", {})
		var sc := SteamApi.daily_score(rem, armies[0].spent())
		if int(prev.get("day", -1)) != day or int(prev.get("ver", 1)) != Daily.VER or sc > int(prev.get("score", 0)):
			Save.data["daily_pend"] = {"day": day, "score": sc, "det": Array(det), "ver": Daily.VER}
		_daily_sync()
	sh_text = Share.daily_text(L, Time.get_date_string_from_unix_time(day * 86400), L.t("daily_mut_%d" % int(daily_spec["mut"])), rem, armies[0].spent(), armies[0].budget, int(sim.tick / 20), int(st["n"]))

func _highlights() -> Array:
	var out: Array = _key_marks() if not report.is_empty() else []
	if sim != null and sim.winner >= 0:
		out.append({"t": maxi(0, int(sim.tick) - 30), "label": "%s %ds" % [L.t("sh_final"), int(sim.tick) / 20]})
	return out

func _hl_go(t: int) -> void:
	overlay = ""
	call("_replay")
	call("_seek_async", maxi(0, t - 20))

func _draw_share() -> void:
	draw_rect(Rect2(0, 0, 1280, 800), Color(0, 0, 0, 0.6))
	var hl := _highlights()
	var rows := 1 + (1 if not (daily_spec as Dictionary).is_empty() else 0) + (1 if pc_shot != null else 0) + (1 if bool(call("_ws_ok", sim.winner if sim != null else -1)) else 0) + (1 if sh_text != "" else 0)
	var P := modal_rect(640, 12.0 + h1_bottom(0.0) + GAP_L + below_head(tz("B")) + maxf(1.0, hl.size()) * 52.0 + GAP_L + rows * 56.0 + GAP_L + 44.0 + GAP_L)
	_panel(P)
	var y := _h1(Vector2(640, P.position.y + 12), L.t("sh_title")) + GAP_L
	_text(Vector2(640, y), L.t("sh_hl"), tz("B"), ACCENT, true, true, 560)
	y += below_head(tz("B"))
	if hl.is_empty():
		_text(Vector2(640, y + 10), L.t("sh_hl_none"), tz("S"), TXT_DIM, true, false, 560)
		y += 52.0
	for m in hl:
		var t := int(m["t"])
		_btn(Rect2(400, y, 480, 44), str(m["label"]), func(): _hl_go(t))
		y += 52.0
	y += GAP_L
	_btn(Rect2(400, y, 480, 48), L.t("replay"), func(): overlay = ""; call("_replay"))
	y += 56.0
	if pc_shot != null:
		_btn(Rect2(400, y, 480, 48), L.t("pc_btn"), func(): overlay = "postcard", true, true)
		y += 56.0
	if bool(call("_ws_ok", sim.winner)):
		_btn(Rect2(400, y, 480, 48), L.t("ws_make"), func(): overlay = ""; call("_make_workshop"))
		y += 56.0
	if sh_text != "":
		_btn(Rect2(400, y, 480, 48), L.t("sh_copy"), func(): DisplayServer.clipboard_set(sh_text); _toast(L.t("sh_copied")))
		y += 56.0
	if not (daily_spec as Dictionary).is_empty():
		_btn(Rect2(400, y, 480, 48), L.t("dt_title"), func(): _daily_top_open())
		y += 56.0
	_btn(Rect2(560, P.end.y - GAP_L - 44.0, 160, 44), L.t("back"), func(): overlay = "")

func _ghost_settle(w: int) -> void:
	sh_text = ""
	super._ghost_settle(w)
	if bool(get("wk_active")):
		var rec: Dictionary = Save.data.get("weekly", {})
		sh_text = Share.weekly_text(L, int(rec.get("wk", 0)), w == 0, last_armies[0].spent() if last_armies.size() > 0 else 0, int(rec.get("best", 0)), int(rec.get("tries", 0)))

## ── #8 殘局極速賽 ──
const Rush = preload("res://scripts/game/v16_rush.gd")
var rush := {}   # {"on", "left", "ids", "i", "solved", "tried"}

func _rush_start() -> void:
	var sd := int(Time.get_unix_time_from_system())
	rush = {"on": true, "left": Rush.START_SEC, "ids": Rush.pool(sd), "i": 0, "solved": 0, "tried": 0}
	_rush_load()

func _rush_load() -> void:
	var ids: Array = rush["ids"]
	if int(rush["i"]) >= ids.size():
		_rush_end()
		return
	puzzle_id = str(ids[int(rush["i"])])
	_start_mode(Mode.PUZZLE)

func _rush_end() -> void:
	rush["on"] = false
	var best := int(Save.data.get("rush_best", 0))
	rush["new_best"] = int(rush["solved"]) > best
	if int(rush["solved"]) > best:
		Save.data["rush_best"] = int(rush["solved"])
		Save.save_data()
	_go_title()
	overlay = "rush_end"
	_focus = 0

func _rush_tick(delta: float) -> void:
	if not bool(rush.get("on", false)):
		return
	if state == St.PLACE and overlay == "":
		rush["left"] = float(rush["left"]) - delta
		if float(rush["left"]) <= 0.0:
			_rush_end()

## 結算：解開 +20 秒、沒解開 −15 秒，直接換下一題（不進結果頁）
func _rush_settle() -> void:
	var solved: bool = sim.winner == 0 and bool(report.get("goal_ok", true))
	rush["tried"] = int(rush["tried"]) + 1
	if solved:
		rush["solved"] = int(rush["solved"]) + 1
	rush["left"] = Rush.after(float(rush["left"]), solved)
	_toast(L.t("rush_ok" if solved else "rush_bad", [int(Rush.BONUS_SEC if solved else Rush.PENALTY_SEC)]), not solved)
	rush["i"] = int(rush["i"]) + 1
	if float(rush["left"]) <= 0.0:
		_rush_end()
	else:
		_rush_load()

func _v16_place_hud() -> void:
	_coop_hud()
	if bool(rush.get("on", false)):
		var s := L.t("rush_hud", [ceili(maxf(0.0, float(rush["left"]))), int(rush["solved"])])
		var w := _width(s, tz("B"), true) + 32.0
		var r := Rect2(640 - w / 2, 96, w, tz("B") * 1.6)
		_tex_box(r, "wood", Color("#7a2a18") if float(rush["left"]) < 20.0 else Color(0.35, 0.24, 0.12))
		_text(Vector2(640, r.position.y + tz("B") * 0.25), s, tz("B"), Color.WHITE, true, true, w)

func _draw_rush_end() -> void:
	var body := L.t("rush_end_body", [int(rush.get("solved", 0)), int(rush.get("tried", 0)), int(Save.data.get("rush_best", 0))])
	var P := modal_rect(560, 12.0 + h1_bottom(0.0) + GAP_L + text_h(body, tz("B"), 480, true) + GAP_XL + 50.0 + GAP_L)
	_panel(P)
	var y := _h1(Vector2(640, P.position.y + 12), L.t("rush_title")) + GAP_L
	_text(Vector2(640, y), body, tz("B"), ACCENT if bool(rush.get("new_best", false)) else Color.WHITE, true, true, 480)
	y += text_h(body, tz("B"), 480, true) + GAP_XL
	_btn(Rect2(640 - 230, y, 220, 50), L.t("rush_again"), func(): overlay = ""; _rush_start(), true, true)
	_btn(Rect2(650, y, 220, 50), L.t("back"), func(): overlay = "")

## ── #9 差一子教練 ──
const Coach = preload("res://scripts/game/v16_coach.gd")
var co_thread: Thread = null
var co_res := {}       # 搜尋結果
var co_layer := 0      # 0 還沒看、1 哪一隻、2 往哪、3 直接擺
var co_key := ""       # 這一場的識別（換場就重算）
var co_ctl := {}       # V1.6.1 F5：和背景搜尋共用的 {"stop", "until", "done"}（取消、期限、進度）

func _coach_pz() -> Dictionary:
	return PZ.get_puzzle(puzzle_id) if mode == Mode.PUZZLE else {}

func coach_ok() -> bool:
	if play_kind != "official" or watch_mode or sim == null or sim.winner == 0 or last_armies.size() != 2:
		return false
	if bool(rush.get("on", false)) or not (mode == Mode.PUZZLE or mode == Mode.VS_AI):
		return false
	if not (get("daily_spec") as Dictionary).is_empty():
		return false   # V1.6.1 A4：每日挑戰不給教練（大家同一題、上排行榜）
	if mode == Mode.PUZZLE and bool(report.get("goal_ok", false)):
		return false
	return Coach.supported(last_armies[0], battle_rules, _coach_pz())

func _coach_open() -> void:
	var key := "%d:%s:%d:%d:%s:%d" % [mode, puzzle_id, last_armies[0].units.hash(), last_armies[1].units.hash(), battle_rules.to_code() if battle_rules != null else "", _coach_pz().hash()]
	if co_thread != null:
		if key != co_key:
			co_key = key   # 換場了：舊的答案算完不收（_v16_jobs 比對 co_thread_key），算完再重開會重算
			co_res = {}
			co_layer = 0
		overlay = "coach"
		_focus = 0
		return
	if key != co_key:
		co_key = key
		co_res = {}
		co_layer = 0
		var a0 = last_armies[0].copy()
		var a1 = last_armies[1].copy()
		var rr = battle_rules.copy() if battle_rules != null else null
		var pz := _coach_pz()
		var ctl := {"stop": false, "until": Time.get_ticks_msec() + Coach.TIME_MS, "done": 0}
		co_ctl = ctl
		if DisplayServer.get_name() == "headless" or shot_dir != "":
			co_res = Coach.search(a0, a1, rr, pz, Coach.LIMIT, ctl)
		else:
			co_thread = Thread.new()
			co_thread_key = key
			co_thread.start(func(): return Coach.search(a0, a1, rr, pz, Coach.LIMIT, ctl))
	overlay = "coach"
	_focus = 0

var co_thread_key := ""
func _v16_jobs(_delta: float) -> void:
	_trio_jobs()
	if co_thread != null and not co_thread.is_alive():
		var res = co_thread.wait_to_finish()
		co_thread = null
		if co_thread_key == co_key and str((res as Dictionary).get("status", "")) == "cancel" and overlay == "coach":
			co_key = ""
			_coach_open()   # 取消後又打開同一場：重算（不顯示「已取消」）
		elif co_thread_key == co_key:
			co_res = res   # 過期的結果（換場了）不收
		else:
			var want := co_key
			co_key = ""
			if overlay == "coach" and want != "":
				_coach_open()   # 面板開著、等的是新的這一場：接著算新的

func _exit_tree() -> void:
	if trio_thread != null:
		trio_thread.wait_to_finish()
		trio_thread = null
	if co_thread != null:
		co_ctl["stop"] = true   # V1.6.1 F5：先叫它停（64 tick 內會停），不用等整場跑完
		co_thread.wait_to_finish()   # 結束時收掉教練的背景工作（Codex v160-i1 #3）
		co_thread = null
	super._exit_tree()

## V1.6.1 F5：推演中按「取消」：叫背景停下、關面板；下次打開這一場會重算
func _coach_cancel() -> void:
	co_ctl["stop"] = true
	co_key = ""
	overlay = ""

## V1.6.1 A4：教練紀錄分層。鍵＝實驗簿同一套（殘局 id、試煉 t＋編號、工坊／三考依內容）；一般對 AI 不記。
## coached[鍵] = {"lv": 看過的最高提示層級 1～3, "ap": 有沒有套用, "self": 自力最佳星數（沒用教練過關時才更新）}
var co_assist := ""   # 這一題這次有用到第 2 層以上或套用：之後過關算「教練協力」
func _coach_note(lv: int, applied := false) -> void:
	var k := _nb_key()
	if k == "":
		return
	var cd: Dictionary = Save.data.get("coached", {})
	var e: Dictionary = cd.get(k, {"lv": 0, "ap": 0, "self": int(Save.data.get("puzzle_stars", {}).get(k, 0))})
	e["lv"] = maxi(int(e.get("lv", 0)), lv)
	if applied:
		e["ap"] = 1
	cd[k] = e
	Save.data["coached"] = cd
	if lv >= 2 or applied:
		co_assist = k

## 過關時（game_core 存星數之後呼叫）：沒用教練的成績才進「自力最佳」
func _coach_after_clear(stars: int) -> void:
	var k := _nb_key()
	if k == "":
		return
	var cd: Dictionary = Save.data.get("coached", {})
	if not cd.has(k):
		return
	if co_assist != k:
		cd[k]["self"] = maxi(int(cd[k].get("self", 0)), stars)
	Save.data["coached"] = cd

static func coach_badge(data: Dictionary, pid: String) -> bool:
	var e = data.get("coached", {}).get(pid)
	return e is Dictionary and int(e.get("lv", 0)) >= 2 and int(e.get("self", 0)) < int(data.get("puzzle_stars", {}).get(pid, 0))

func _coach_apply() -> void:
	if not bool(co_res.get("found", false)):
		return
	_coach_note(3, true)
	if mode == Mode.PUZZLE:
		var b = co_res["army"]
		armies[0] = b.copy()
		overlay = ""
		state = St.PLACE
		_start_mode(Mode.PUZZLE)
		armies[0] = b.copy()   # _start_mode 會重設陣型：重設之後再擺回教練的陣
		_toast(L.t("co_applied"))
	else:
		# 對 AI：敵陣會換，所以改在覆盤裡套用（同一支敵軍），直接看「如果」
		call("_open_review")
		set("rv_army", co_res["army"].copy())
		call("_rv_dirty")
		call("_rv_recalc")

func _dir_name(f: Vector2i, t: Vector2i) -> String:
	var parts: Array = []
	var dx := t.x - f.x
	if last_armies.size() > 0 and last_armies[0].team == 1:
		dx = -dx
	if dx > 0:
		parts.append(L.t("co_fwd"))
	elif dx < 0:
		parts.append(L.t("co_back"))
	if t.y < f.y:
		parts.append(L.t("co_up"))
	elif t.y > f.y:
		parts.append(L.t("co_down"))
	return L.t("co_and", parts) if parts.size() == 2 else (str(parts[0]) if parts.size() == 1 else "")

func _coach_hint2() -> String:
	if str(co_res.get("kind", "move")) == "swap":
		return L.t("co_l2s", [L.t("unit_%d" % int(co_res["to_type"]))])
	if bool(co_res.get("grid", true)):
		return L.t("co_l2", [_dir_name(co_res["from"], co_res["to"])])
	return L.t("co_l2h", [_dir_name(co_res["from"], co_res["to"])])

func _coach_status_line() -> String:
	var tr := int(co_res.get("tries", 0))
	match str(co_res.get("status", "exhausted")):
		"budget":
			return L.t("co_budget", [tr, int(co_res.get("total", 0)) - tr])
		"timeout":
			return L.t("co_timeout", [tr])
		"cancel":
			return L.t("co_cancelled")
	return L.t("co_none", [tr])

## 第 2 層殘影：小棋盤上原本的兵（實）→ 建議的位置或兵種（半透明）
func _coach_ghost(c: Vector2) -> void:
	var t0 := int(co_res["type"])
	var t1 := int(co_res.get("to_type", t0))
	var cs := 44.0
	var tm: int = last_armies[0].team
	var off := Vector2.ZERO
	if str(co_res.get("kind", "move")) == "swap":
		off = Vector2(cs * 1.6, 0)
	else:
		var f: Vector2i = co_res["from"]
		var t: Vector2i = co_res["to"]
		var k := 1.0 if bool(co_res.get("grid", true)) else 1.0 / Coach.FREE_STEP
		off = Vector2((t.x - f.x) * k, (t.y - f.y) * k).normalized() * cs * 1.6
	var a := c - off / 2.0
	var b := c + off / 2.0
	for gx in range(-2, 3):
		for gy in range(-1, 2):
			draw_rect(Rect2(c + Vector2(gx, gy) * cs - Vector2(cs, cs) / 2.0, Vector2(cs, cs)), Color(1, 1, 1, 0.05 if (gx + gy) % 2 == 0 else 0.02))
	Art.unit(self, a + Vector2(0, 14), t0, tm, 1.0, 0.0, 0.0, 0.0, 1.0, time, 0.62, cbm())
	_chalk_arrow(a + off.normalized() * 20.0, b - off.normalized() * 20.0)
	Art.unit(self, b + Vector2(0, 14), t1, tm, 1.0, 0.0, 0.0, 0.0, 0.42 + 0.12 * sin(time * 4.0), time, 0.62, cbm())

func _draw_coach() -> void:
	var busy := co_thread != null
	var found: bool = bool(co_res.get("found", false))
	var lines: Array = []
	if busy:
		lines.append(L.t("co_busy_n", [int(co_ctl.get("done", 0)), Coach.LIMIT]))
	elif not found:
		lines.append(_coach_status_line())
	else:
		var tn := L.t("unit_%d" % int(co_res["type"]))
		lines.append(L.t("co_l1", [tn]))
		if co_layer >= 2:
			lines.append(_coach_hint2())
	var body := "\n".join(lines)
	var gh := 150.0 if found and co_layer >= 2 else 0.0
	var P := modal_rect(620, 12.0 + h1_help_h(L.t("co_help", [Coach.LIMIT, Coach.TIME_MS / 1000]), tz("S"), 540) + GAP_L + text_h(body, tz("B"), 540) + gh + GAP_XL + 50.0 + GAP_M + 44.0 + GAP_L)
	_panel(P)
	var y := _h1_help(Vector2(640, P.position.y + 12), L.t("co_title"), L.t("co_help", [Coach.LIMIT, Coach.TIME_MS / 1000]), tz("S"), 540)
	_text(Vector2(640, y), body, tz("B"), Color.WHITE, true, true, 540)
	y += text_h(body, tz("B"), 540)
	if gh > 0.0:
		_coach_ghost(Vector2(640, y + gh / 2.0))
		y += gh
	y += GAP_XL
	if busy:
		_btn(Rect2(640 - 160, y, 320, 50), L.t("co_cancel"), func(): _coach_cancel(), true, true)   # 推演中：明顯的取消（手把 A；B＝返回也會取消）
	elif found and co_layer < 2:
		_btn(Rect2(640 - 160, y, 320, 50), L.t("co_more"), func(): co_layer = 2; _coach_note(2), true, true)
	elif found:
		_btn(Rect2(640 - 160, y, 320, 50), L.t("co_apply") if mode == Mode.PUZZLE else L.t("co_review"), func(): _coach_apply(), true, true)
	_btn(Rect2(560, P.end.y - GAP_L - 44.0, 160, 44), L.t("back"), func(): _coach_cancel() if co_thread != null else _close_overlay_plain())
	if found and co_layer < 1:
		co_layer = 1
		_coach_note(1)

func _close_overlay_plain() -> void:
	overlay = ""

## ── #10 裂隙模式 ──
const Rift = preload("res://scripts/game/v16_rift.gd")
var rift_on := false
var rift_wk := 0
var rift_code := ""   # 這一場裂隙的規則碼：「再來一局」要同一組規則才算裂隙（Antigravity v160-i2 #2）   # 開局那一週（跨週才打完也記在那一週，Codex v160-i2 #1）

func _rift_picks() -> Array:
	return Rift.picks(Rift.week(), RS.mask(_demo()))

func _rift_start() -> void:
	var wk := Rift.week()
	rift_wk = wk
	var r = Rift.make_rules(_rift_picks(), RS.mask(_demo()), wk)
	rift_code = r.to_code()
	rules = r
	set("challenge_army", Rift.enemy(r, wk))
	_start_mode(Mode.VS_AI)
	daily_spec = {}   # 不是每日挑戰
	rift_on = true

func _rift_settle() -> void:
	if not rift_on or sim == null or sim.winner != 0:
		return
	var best: Dictionary = Save.data.get("rift_best", {})
	var k := Rift.key(rift_wk)
	if rift_wk != Rift.week():
		return   # 上一週的題：本週紀錄只留本週，跨週打完的不記
	var rec := [PZ.rem_pct(sim.power(0), sim.budget_of(0)), armies[0].spent()]
	if Daily.better(rec, best.get(k, [])):
		best = {k: rec}   # 只留這一週
		Save.data["rift_best"] = best
		Save.save_data()
		_toast(L.t("rf_new", [int(rec[0])]))

func _draw_rift() -> void:
	var ps := _rift_picks()
	var lines: Array = []
	for k in ps:
		lines.append("・" + L.t(str(Rift.ANOMS[k][0])))
	var body := "\n".join(lines)
	var b: Array = Save.data.get("rift_best", {}).get(Rift.key(Rift.week()), [])
	var best := L.t("rf_best", [int(b[0]), int(b[1])]) if not b.is_empty() else L.t("rf_best_none")
	var P := modal_rect(680, 12.0 + h1_help_h(L.t("rf_help"), tz("S"), 600) + GAP_L + text_h(body, tz("B"), 560) + GAP_M + tz("S") * 1.6 + GAP_XL + 52.0 + GAP_M + 44.0 + GAP_L)
	_panel(P)
	var y := _h1_help(Vector2(640, P.position.y + 12), L.t("rift_open"), L.t("rf_help"), tz("S"), 600)
	_text(Vector2(360, y), body, tz("B"), Color.WHITE, false, true, 560)
	y += text_h(body, tz("B"), 560) + GAP_M
	_text(Vector2(640, y), best, tz("S"), ACCENT, true, false, 560)
	y += tz("S") * 1.6 + GAP_XL
	_btn(Rect2(640 - 160, y, 320, 52), L.t("rf_go"), func(): overlay = ""; _rift_start(), true, true)
	_btn(Rect2(560, P.end.y - GAP_L - 44.0, 160, 44), L.t("back"), func(): overlay = "")

func _start_mode(m: int) -> void:
	var keep_rift: bool = rift_on and m == Mode.VS_AI and rules != null and rules.to_code() == rift_code   # 裂隙「再來一局」照舊（同一組規則才算）
	var mk := "%d:%s:%d:%d" % [m, puzzle_id, int(get("trial_id")), PZ.get_puzzle("ws").hash() if puzzle_id == "ws" else 0]   # 工坊、三考都叫 ws：再比題目內容（Codex v160-i3）
	if mk != tv_mode_key:
		tv_marks = []   # 換題、換模式：舊標記不帶過去（同一題重打保留）
	tv_mode_key = mk
	fog_on = false
	tv_mark_mode = false
	var keep_trio: bool = trio_on and m == Mode.PUZZLE and puzzle_id == "ws" and PZ.get_puzzle("ws").has("trio")   # 一陣三考「重試」照舊
	rift_on = false
	trio_on = false
	super._start_mode(m)
	rift_on = keep_rift
	trio_on = keep_trio

## ── #11 AI 對手人設 ──
const Persona = preload("res://scripts/game/v16_persona.gd")

func _ai_style() -> int:
	return int(rules.ai_style) if rules != null else 0

## 擺陣時敵方屏風上：頭像＋名號＋開場白（不洩漏陣型）
func _persona_fog(c: Vector2, w: float) -> void:
	if bool(get("ghost_id") != "") or bool(get("wk_active")) or rift_on:
		return
	var st := _ai_style()
	Art.unit(self, c + Vector2(0, 46), Persona.face(st), 1, -1.0, 0.0, 0.0, 0.0, 1.0, time, 1.0, cbm())
	_text(c + Vector2(0, 56), L.t("ps_name_%d" % st), ts(16), Color.WHITE, true, true, w)
	var q := "「" + L.t(Persona.line_key(st, "open")) + "」" if L.lang.begins_with("zh") or L.lang == "ja" else "\"" + L.t(Persona.line_key(st, "open")) + "\""
	_text(c + Vector2(0, 56 + ts(16) * 1.4), q, ts(15), Color(1, 0.9, 0.7, 0.9), true, false, w)

func _persona_result() -> void:
	if mode != Mode.VS_AI or sim == null or sim.winner < 0 or not (get("daily_spec") as Dictionary).is_empty() or rift_on or str(get("ghost_id")) != "" or bool(get("wk_active")) or watch_mode:
		return
	var st := _ai_style()
	report["ps_line"] = L.t("ps_say", [L.t("ps_name_%d" % st), L.t(Persona.line_key(st, "lose" if sim.winner == 0 else "win"))])

## ── #12 生涯：熟練度＋實驗簿 ──
const Career = preload("res://scripts/game/v16_career.gd")

func _career_settle() -> void:
	if sim == null or mode == Mode.DUEL or watch_mode:
		return
	if rules != null and Presets.badge(rules, "ai") == Presets.BADGE_LAB:
		return
	var m: Dictionary = Save.data.get("mastery", {})
	var ups := Career.add(m, Career.gain(sim.units))
	Save.data["mastery"] = m
	if not ups.is_empty():
		var t: int = ups[0]
		report["ms_line"] = L.t("ms_up", [L.t("unit_%d" % t), Career.level(int(m[str(t)]))])   # 結果頁有空位才顯示（跳提示會壓到別的畫面）
	if _nb_key() != "" and last_armies.size() == 2:
		var nb: Dictionary = Save.data.get("notebook", {})
		var stv: int = int(report.get("stars", 0)) if mode == Mode.PUZZLE else (1 if sim.winner == 0 else 0)
		Career.nb_result(nb, _nb_key(), Career.units_of(last_armies[0]), stv, PZ.rem_pct(sim.power(0), sim.budget_of(0)) if sim.winner == 0 else 0, last_armies[0].spent(), _nb_hash())
		Save.data["notebook"] = nb

func mastery_line(t: int) -> String:
	var xp := int(Save.data.get("mastery", {}).get(str(t), 0))
	var nx := Career.next_at(xp)
	return L.t("ms_line", [Career.level(xp), xp, nx]) if nx > 0 else L.t("ms_max", [Career.level(xp)])

## 實驗簿的鍵：殘局＝關卡 id、試煉＝t＋編號（Codex v160-i1 #9：方案是殘局與試煉）
func _nb_key() -> String:
	if mode == Mode.PUZZLE:
		return Career.ws_key(PZ.get_puzzle("ws"))[0] if puzzle_id == "ws" else puzzle_id   # V1.6.1 F1：工坊／三考依題目內容
	if mode == Mode.VS_AI and int(get("trial_id")) >= 0:
		return "t%d" % int(get("trial_id"))
	return ""

func _nb_hash() -> String:
	return Career.ws_key(PZ.get_puzzle("ws"))[1] if mode == Mode.PUZZLE and puzzle_id == "ws" else ""

func _nb_items() -> Array:
	return Career.nb_list(Save.data.get("notebook", {}), _nb_key(), _nb_hash())

func _draw_notebook() -> void:
	var lst: Array = _nb_items()
	var rows := maxi(1, lst.size())
	var P := modal_rect(760, 12.0 + h1_help_h(L.t("nb_help"), tz("S"), 680) + GAP_L + rows * 56.0 + GAP_L + 48.0 + GAP_M + 44.0 + GAP_L)
	_panel(P)
	var y := _h1_help(Vector2(640, P.position.y + 12), L.t("nb_title"), L.t("nb_help"), tz("S"), 680)
	if lst.is_empty():
		_text(Vector2(640, y + 12), L.t("nb_empty"), tz("S"), TXT_DIM, true, false, 680)
	for i in lst.size():
		var e: Dictionary = lst[i]
		var r: Array = e["r"]
		var res := L.t("nb_res", [int(r[0]), int(r[1]), int(r[2])]) if r.size() == 3 else L.t("nb_untried")
		_text(Vector2(P.position.x + 40, y + 10), "%s　%s" % [str(e["n"]), res], tz("S"), Color.WHITE, false, true, 420)
		var ii := i
		_btn_small(Rect2(P.end.x - 250, y + 4, 110, 40), L.t("nb_load"), func(): _nb_load(ii))
		_btn_small(Rect2(P.end.x - 130, y + 4, 90, 40), L.t("nb_del"), func(): _nb_del(ii))
		y += 56.0
	y += GAP_L
	_btn(Rect2(640 - 160, y, 320, 48), L.t("nb_save"), func(): _nb_save(), lst.size() < Career.NB_MAX, true)
	_btn(Rect2(560, P.end.y - GAP_L - 44.0, 160, 44), L.t("back"), func(): overlay = "")

func _nb_save() -> void:
	var nb: Dictionary = Save.data.get("notebook", {})
	var n := _nb_items().size() + 1
	if Career.nb_save(nb, _nb_key(), L.t("nb_name", [n]), Career.units_of(armies[0]), _nb_hash()):
		Save.data["notebook"] = nb
		Save.save_data()
		_toast(L.t("nb_saved"))
	else:
		_toast(L.t("nb_dup"), true)

func _nb_load(i: int) -> void:
	var e: Dictionary = _nb_items()[i]
	if mode == Mode.PUZZLE:
		armies[0] = PZ.player_army(PZ.get_puzzle(puzzle_id))
		var pz := PZ.get_puzzle(puzzle_id)
		for u in e["u"]:
			if (u as Array).size() == 3 and not PZ.is_fixed(pz, int(u[1]), int(u[2])):
				armies[0].place(int(u[0]), int(u[1]), int(u[2]))
	else:
		armies[0].units = []
		for u in e["u"]:
			if (u as Array).size() == 4:
				armies[0].place_xy(int(u[0]), int(u[1]), int(u[2]))
			else:
				armies[0].place(int(u[0]), int(u[1]), int(u[2]))
	overlay = ""

func _nb_del(i: int) -> void:
	var nb: Dictionary = Save.data.get("notebook", {})
	var lst: Array = nb.get(_nb_key(), [])
	var items := _nb_items()
	if i < items.size():
		lst.erase(items[i])   # 清單只顯示同一題的方案（F1）：照物件刪
		nb[_nb_key()] = lst
		Save.data["notebook"] = nb
		Save.save_data()

## ── #13 每日全球榜＋挑戰高手陣 ──
var dt_list: Array = []
var dt_state := ""   # ""、"loading"、"done"、"off"

func _daily_sync() -> void:
	var p: Dictionary = Save.data.get("daily_pend", {})
	if not p.is_empty() and SteamApi.available():
		SteamApi.daily_upload(int(p["day"]), int(p["score"]), PackedInt32Array(p.get("det", [])), int(p.get("ver", 1)))

func _daily_top_open() -> void:
	overlay = "daily_top"
	_focus = 0
	dt_list = []
	if not SteamApi.available():
		dt_state = "off"
		return
	dt_state = "loading"
	SteamApi.daily_fetch(int(Daily.today()), func(lst: Array):
		dt_list = lst.slice(0, 5)
		dt_state = "done", Daily.VER)

func _daily_top_go(units: Array) -> void:
	var sp: Dictionary = Daily.spec(Daily.today())
	var r = Daily.make_rules(sp, RS.mask(false))
	var e = Army.new(1, r.budget_of(1))
	e.apply_rules(r, 1)
	for u in units:   # 網路來的陣：照今天的規則一隻一隻擺，有一隻不合法整陣不收（Codex v160-i1 #4）
		if not e.place_xy(int(u["type"]), int(u["x"]), int(u["y"])):
			_toast(L.t("dt_bad"), true)
			return
	if not e.has_combat():
		_toast(L.t("dt_bad"), true)
		return   # 先驗完才動規則與挑戰陣（Codex v160-i2 A7：拒收後重試不能沿用被拒的陣）
	rules = r
	set("challenge_army", e)
	overlay = ""
	_start_mode(Mode.VS_AI)
	daily_spec = {}   # 打高手陣不算今天的每日成績（_start_mode 有挑戰陣時不清，要自己清：Codex v160-i1 #2）
	rift_on = false   # 規則也是 custom：不能被當成裂隙「再來一局」（Antigravity v160-i1 #5）

func _draw_daily_top() -> void:
	var body := ""
	match dt_state:
		"off":
			body = L.t("dt_off")
		"loading":
			body = L.t("dt_loading")
		_:
			body = L.t("dt_none") if dt_list.is_empty() else ""
	var rows := dt_list.size()
	var P := modal_rect(640, 12.0 + h1_help_h(L.t("dt_help"), tz("S"), 560) + GAP_L + (text_h(body, tz("S"), 560) + GAP_L if body != "" else 0.0) + rows * 56.0 + GAP_L + 44.0 + GAP_L)
	_panel(P)
	var y := _h1_help(Vector2(640, P.position.y + 12), L.t("dt_title"), L.t("dt_help"), tz("S"), 560)
	if body != "":
		_text(Vector2(640, y), body, tz("S"), TXT_DIM, true, false, 560)
		y += text_h(body, tz("S"), 560) + GAP_L
	for e in dt_list:
		var sc := int(e.get("score", 0))
		var lbl := L.t("dt_row", [int(e.get("rank", 0)), sc / 1000, 999 - sc % 1000])
		var us: Array = e["units"]
		_btn(Rect2(400, y, 480, 48), lbl, func(): _daily_top_go(us))
		y += 56.0
	_btn(Rect2(560, P.end.y - GAP_L - 44.0, 160, 44), L.t("back"), func(): overlay = "")

## ── #16 殘局出題台：小棋盤擺雙方（左 0～5 欄＝你的解、右 10～15 欄＝敵陣），選目標，作者解要過關才給碼 ──
const WS3 = preload("res://scripts/game/workshop.gd")
var ed_cells := {}      # Vector2i(欄, 列) → 兵種
var ed_type := 0
var ed_goal := 0
var ed_msg := ""
var ed_target := Vector2i(-1, -1)   # V1.6.1 A2：作者指定的目標（斬首＝敵兵、護送／完美＝自己的兵）；-1＝自動
var ed_pick := false               # 正在點選目標
const ED_CS := 32.0

func _ed_rect() -> Rect2:
	return Rect2(640 - 8 * ED_CS, 150, 16 * ED_CS, 9 * ED_CS)

func ed_lists() -> Array:
	var e: Array = []
	var s: Array = []
	for k in ed_cells:
		var v := [int(ed_cells[k]), k.x, k.y]
		if k.x >= 10:
			e.append(v)
		elif k.x <= 5:
			s.append(v)
	e.sort()
	s.sort()
	return [e, s]

func ed_toggle(c: Vector2i) -> void:
	if c.x < 0 or c.x > 15 or c.y < 0 or c.y > 8 or (c.x > 5 and c.x < 10):
		return
	if ed_pick:
		var want_foe: bool = WS3.GOALS3[ed_goal] == "kill"
		if ed_cells.has(c) and (c.x >= 10) == want_foe:
			ed_target = c
			ed_pick = false
			ed_msg = ""
		else:
			ed_msg = L.t("ed_pick_foe" if want_foe else "ed_pick_own")
		return
	if c == ed_target:
		ed_target = Vector2i(-1, -1)   # 目標那隻被換掉或拿掉：回到自動
	if ed_cells.get(c, -1) == ed_type:
		ed_cells.erase(c)
	else:
		ed_cells[c] = ed_type
	ed_msg = ""

func _ed_make() -> void:
	var l := ed_lists()
	var code := WS3.encode4(l[0], l[1], WS3.GOALS3[ed_goal], ed_target)
	if code == "":
		ed_msg = L.t("ed_fail")
		return
	DisplayServer.clipboard_set(code)
	ed_msg = L.t("ed_ok")
	_toast(L.t("ws_copied"))

func _draw_editor() -> void:
	draw_rect(Rect2(0, 0, 1280, 800), Color(0, 0, 0, 0.7))
	var P := Rect2(80, 40, 1120, 720)
	_panel(P)
	probe_skip("R6", "小棋盤是直接畫的格子（不經版面探針），看起來的空白其實是棋盤")
	var y := _h1_help(Vector2(640, P.position.y + 8), L.t("ed_title"), L.t("ed_help"), tz("S"), 1000)
	y += tz("C") * 1.5   # 棋盤上方的「你的解／敵陣」欄標（原本壓到說明，版面檢查 en 125%）
	var G := _ed_rect()
	G.position.y = y
	draw_rect(G, Color(0.42, 0.5, 0.28))
	for cx in 16:
		for cy in 9:
			var r := Rect2(G.position + Vector2(cx, cy) * ED_CS, Vector2(ED_CS, ED_CS))
			if cx > 5 and cx < 10:
				draw_rect(r, Color(0, 0, 0, 0.35))
			draw_rect(r, Color(0, 0, 0, 0.2), false, 1.0)
			var k := Vector2i(cx, cy)
			if ed_cells.has(k):
				Art.unit(self, r.position + Vector2(ED_CS / 2, ED_CS * 0.82), int(ed_cells[k]), 0 if cx <= 5 else 1, 1.0 if cx <= 5 else -1.0, 0.0, 0.0, 0.0, 1.0, time, 0.42, cbm())
				if k == ed_target:
					draw_rect(r.grow(-1), Color(0, 0, 0, 0.8), false, 4.0)
					draw_rect(r.grow(-1), Color("#ff5a4a") if WS3.GOALS3[ed_goal] == "kill" else Color("#ffd166"), false, 2.5)
			if cx <= 5 or cx >= 10:
				_btns.append({"r": r, "cb": func(): ed_toggle(k), "en": true})
	_text(G.position + Vector2(3 * ED_CS, -tz("C") * 1.4), L.t("ed_you"), tz("C"), Color("#9fd0ff"), true, true, 6 * ED_CS)
	_text(G.position + Vector2(13 * ED_CS, -tz("C") * 1.4), L.t("ed_foe"), tz("C"), Color("#ffb0a0"), true, true, 6 * ED_CS)
	y = G.end.y + GAP_M
	# 兵種調色盤（20 種，兩排）
	for t in 20:
		var pr := Rect2(640 - 10 * 50.0 + (t % 10) * 100.0 + 4, y + (t / 10) * 52.0, 92, 48)
		_btn(pr, "", func(): ed_type = t, true, false, TH_ACTIVE if ed_type == t else Color(0, 0, 0, 0))
		Art.unit(self, pr.position + Vector2(24, 44), t, 0, 1.0, 0.0, 0.0, 0.0, 1.0, time, 0.42, cbm())
		_text(pr.position + Vector2(46, 14), "%dg" % D.cost(t), tz("C"), Color.WHITE, false, true, 44)
	y += 2 * 52.0 + GAP_S
	var l := ed_lists()
	var gold := [0, 0]
	for i in 2:
		for u in l[i]:
			gold[i] += D.cost(int(u[0]))
	var info := L.t("ed_info", [l[1].size(), gold[1], l[0].size(), gold[0]])
	_text(Vector2(640, y), info, tz("S"), Color.WHITE, true, false, 1000)
	y += tz("S") * 1.4 + GAP_M
	# 目標鈕獨立一排（英文長說明放得下）；下一排三顆同寬置中（R4）
	var gname: String = WS3.GOALS3[ed_goal]
	var cyc := func(): ed_goal = (ed_goal + 1) % WS3.GOALS3.size(); ed_msg = ""; ed_target = Vector2i(-1, -1); ed_pick = false
	if gname in WS3.PICK_GOALS:
		# V1.6.1 A2：可以自己點目標（同一排兩顆，整排置中）
		var tl: String = L.t("ed_tgt_pick") if ed_pick else (L.t("ed_tgt_auto") if ed_target.x < 0 else L.t("ed_tgt_set", [L.t("unit_%d" % int(ed_cells.get(ed_target, 0)))]))
		_btn(Rect2(640 - 380, y, 480, 44), L.t("ed_goal", [L.t("ed_g_" + gname)]), cyc)
		_btn(Rect2(640 + 100 + GAP_S, y, 280 - GAP_S, 44), tl, func(): ed_pick = not ed_pick; ed_msg = L.t("ed_pick_foe" if gname == "kill" else "ed_pick_own") if ed_pick else "", true, false, TH_ACTIVE if ed_pick else Color(0, 0, 0, 0))
	else:
		_btn(Rect2(640 - 380, y, 760, 44), L.t("ed_goal", [L.t("ed_g_" + gname)]), cyc)
	y += 44 + GAP_S
	if ed_msg != "":
		_text(Vector2(640, y), ed_msg, tz("S"), ACCENT, true, true, 1000)
	var by := P.end.y - GAP_L - 48.0
	_btn(Rect2(640 - 3 * 150 - 20, by, 300, 48), L.t("ed_make"), func(): _ed_make(), not l[0].is_empty() and not l[1].is_empty(), true)
	_btn(Rect2(640 - 150, by, 300, 48), L.t("clear"), func(): ed_cells = {}; ed_msg = ""; ed_target = Vector2i(-1, -1); ed_pick = false)
	_btn(Rect2(640 + 150 + 20, by, 300, 48), L.t("back"), func(): overlay = "")

## ── #17 一陣三考 ──
const Trio = preload("res://scripts/game/v16_trio.gd")
var trio_on := false
var trio_i := 0
var trio_res: Array = []

func _trio_start(i: int) -> void:
	trio_i = i
	PZ.set_custom(Trio.make_pz(Trio.sets()[i], 0))
	puzzle_id = "ws"
	overlay = ""
	_start_mode(Mode.PUZZLE)
	trio_on = true

## V1.6.1 F7：第一場就是剛打完的這場（不重算）；第 2、3 場在背景算（顯示「計算中」），算完才寫紀錄、開結算。
var trio_thread: Thread = null
var trio_extra: Array = []
var trio_busy := false
var trio_st := 0
func _trio_settle() -> void:
	var extra: Array = []
	for u in last_armies[0].units:
		extra.append([int(u["type"]), int(u["col"]), int(u["row"])])
	trio_extra = extra
	var s: Dictionary = Trio.sets()[trio_i]
	var oc: Dictionary = PZ.outcome(PZ.get_puzzle("ws"), sim, last_armies[0].spent())
	trio_res = [{"ok": bool(oc["ok"]), "rem": int(oc["rem"]), "spent": int(oc["spent"])}]
	trio_st = 0
	overlay = "trio_result"
	_focus = 0
	if DisplayServer.get_name() == "headless" or shot_dir != "":
		trio_res += Trio.results(s, extra, 1)
		_trio_done()
		return
	if trio_thread != null:
		trio_thread.wait_to_finish()   # 上一組還在算（極少見）：先收掉
	trio_busy = true
	trio_thread = Thread.new()
	trio_thread.start(func(): return Trio.results(s, extra, 1))

func _trio_jobs() -> void:
	if trio_thread != null and not trio_thread.is_alive():
		var rest: Array = trio_thread.wait_to_finish()
		trio_thread = null
		trio_busy = false
		if trio_res.size() == 1:
			trio_res += rest
			_trio_done()

func _trio_done() -> void:
	var s: Dictionary = Trio.sets()[trio_i]
	trio_st = Trio.stars(s, trio_res)
	if trio_st >= 1:
		var cl: Dictionary = Save.data.get("trio_clear", {})
		var id := str(s["id"])
		var sp: int = last_armies[0].spent()
		if not cl.has(id) or sp < int(cl[id]):
			cl[id] = sp
			Save.data["trio_clear"] = cl
		var ts: Dictionary = Save.data.get("trio_stars", {})
		if trio_st > int(ts.get(id, 0)):
			ts[id] = trio_st
			Save.data["trio_stars"] = ts
		Save.save_data()

## 看第 k 場（同一套陣對第 k 支敵軍；當成觀戰，不算紀錄）
func _trio_watch(k: int) -> void:
	var pz: Dictionary = Trio.make_pz(Trio.sets()[trio_i], k)
	var a0 = PZ.player_army(pz)
	for e in trio_extra:
		a0.units.append({"type": int(e[0]), "col": int(e[1]), "row": int(e[2])})
	trio_on = false
	call("watch_code", a0, PZ.enemy_army(pz), PZ.rules_of(pz))

func _draw_trio() -> void:
	var ss := Trio.sets()
	var cl: Dictionary = Save.data.get("trio_clear", {})
	var rows := ceili(ss.size() / 2.0)
	var P := modal_rect(760, 12.0 + h1_help_h(L.t("tr_help"), tz("S"), 680) + GAP_L + rows * 56.0 + GAP_L + 44.0 + GAP_L)
	_panel(P)
	var y := _h1_help(Vector2(640, P.position.y + 12), L.t("trio_open"), L.t("tr_help"), tz("S"), 680)
	for i in ss.size():
		var s: Dictionary = ss[i]
		var id := str(s["id"])
		var lbl := L.t("tr_row", [i + 1, int(s["budget"])]) + ("　✓ %dg" % int(cl[id]) if cl.has(id) else "")
		var ii := i
		var br := Rect2(640 - 350 + (i % 2) * 360, y + (i / 2) * 56.0, 340, 48)
		_btn(br, lbl, func(): _trio_start(ii), true, i == 0)
		var tst := int(Save.data.get("trio_stars", {}).get(id, 1 if cl.has(id) else 0))   # V1.6.1 A3：整組星數（舊紀錄只有過關＝1 星）
		for ks in 3:
			_icon("star", Vector2(br.end.x - 50 + ks * 16, br.end.y - 10), 13.0, Color("#ffd166") if ks < tst else Color(1, 1, 1, 0.18))
	_btn(Rect2(560, P.end.y - GAP_L - 44.0, 160, 44), L.t("back"), func(): overlay = "")

func _draw_trio_result() -> void:
	var s: Dictionary = Trio.sets()[trio_i]
	var done := trio_res.size() == 3
	var all_ok := done and trio_st >= 1
	var foot: String = L.t("tr_busy") if not done else (L.t("tr_pass_st", [Trio.rem_avg(trio_res), Trio.spent_pct(s, trio_res), Trio.s2_of(s), Trio.s3_of(s)]) if all_ok else L.t("tr_fail"))
	var cw := 220.0
	var ch := 196.0
	var P := modal_rect(760, 12.0 + h1_bottom(0.0) + GAP_L + ch + GAP_L + text_h(foot, tz("S"), 680) + GAP_L + 26.0 + GAP_L + 50.0 + GAP_L)
	_panel(P)
	var y := _h1(Vector2(640, P.position.y + 12), L.t("trio_open")) + GAP_L
	var r5: Array = []   # 三張同列卡片（R5 基準線：縮圖、標題）
	for k in 3:
		var r := Rect2(640 - (cw * 3 + 2 * GAP_L) / 2.0 + k * (cw + GAP_L), y, cw, ch)
		var has := k < trio_res.size()
		var kk := k
		_btn(r, "", func(): _trio_watch(kk), has, false)
		_mini_formation(Rect2(r.position + Vector2(cw / 2.0 - 40, 10), Vector2(80, 84)), Trio.make_pz(s, k), true)
		r5.append([Rect2(r.position + Vector2(cw / 2.0 - 40, 10), Vector2(80, 84)), Rect2(r.position + Vector2(8, 102), Vector2(cw - 16, tz("S")))])
		var head := L.t("tr_card", [k + 1])
		_text(Vector2(r.get_center().x, r.position.y + 102), head, tz("S"), Color.WHITE, true, true, cw - 16)
		var st_line := L.t("tr_calc") if not has else ((L.t("tr_won", [int(trio_res[k]["rem"])])) if bool(trio_res[k]["ok"]) else L.t("tr_lost"))
		_text(Vector2(r.get_center().x, r.position.y + 102 + tz("S") * 1.5), st_line, tz("S"), (ACCENT if has and bool(trio_res[k]["ok"]) else Color(1, 0.75, 0.7)) if has else TXT_DIM, true, false, cw - 16)
		if has:
			_text(Vector2(r.get_center().x, r.end.y - tz("C") * 1.6), L.t("tr_watch"), tz("C"), TXT_DIM, true, false, cw - 16)
	probe_cards("trio_cards", r5)
	y += ch + GAP_L
	_text(Vector2(640, y), foot, tz("S"), ACCENT if all_ok else Color.WHITE, true, false, 680)
	y += text_h(foot, tz("S"), 680) + GAP_L
	for ks in 3:
		_icon("star", Vector2(640 - 30 + ks * 30, y + 13), 24.0, Color("#ffd166") if ks < trio_st else Color(1, 1, 1, 0.2))
	y += 26.0 + GAP_L
	_btn(Rect2(640 - 230, y, 220, 50), L.t("retry"), func(): overlay = ""; _trio_start(trio_i), not trio_busy, true)
	_btn(Rect2(650, y, 220, 50), L.t("back"), func(): overlay = "")

## ── #20 迷霧推演：對 AI（普通）；開戰前斥候回報約三分之一的敵兵（依欄、列排序後每 3 隻露 1 隻，固定不隨機），其他要猜。
## 只動畫面，不動模擬。原本做「前兩排」：AI 多半把兵擺在前兩排，21 隻露 16 隻，等於沒藏（版面截圖看到）。
var fog_on := false
const FOG_EVERY := 3

func _fog_start() -> void:
	rules = null
	difficulty = 1
	set("challenge_army", null)
	_start_mode(Mode.VS_AI)
	fog_on = true
	call("_build_ai")   # 先組好（平常是開戰才組），前排才看得到
	ai_prebuilt = true

static func fog_seen(units: Array) -> Array:
	# V1.6.1 F3：自由座標（每日、自由排兵）也要露：依 x、再依 y 排序後同樣每 3 隻露 1 隻（不是探測半徑，畫面不畫範圍圈）
	var lst: Array = units.filter(func(u): return u.has("col") or u.has("x"))
	lst.sort_custom(func(a, b): return _fog_key(a) < _fog_key(b))
	var out: Array = []
	for i in lst.size():
		if i % FOG_EVERY == 0:
			out.append(lst[i])
	return out

static func _fog_key(u: Dictionary) -> int:
	if u.has("col"):
		return (int(u["col"]) * 1000 + 500) * 100000 + int(u["row"]) * 1000 + 500
	return int(u["x"]) * 100000 + int(u["y"])

func _fog_draw() -> void:
	if not fog_on or state != St.PLACE or mode != Mode.VS_AI or armies.size() < 2 or armies[1] == null:
		return
	var seen := fog_seen(armies[1].units)
	for u in seen:
		var p := ORIGIN + Vector2(int(u["col"]) + 0.5, int(u["row"]) + 0.82) * CS if u.has("col") else _foot_of(Vector2i(int(u["x"]), int(u["y"])))
		# 斥候照亮：腳下一圈暖光＋白黑雙色細框（色盲、高對比也分得出是「看到的」）
		draw_circle(p - Vector2(0, 0.2 * CS), 0.55 * CS, Color(1, 0.92, 0.6, 0.16))
		draw_arc(p - Vector2(0, 0.2 * CS), 0.55 * CS + 1.5, 0, TAU, 32, Color(0, 0, 0, 0.55), 2.5)
		draw_arc(p - Vector2(0, 0.2 * CS), 0.55 * CS, 0, TAU, 32, Color(1, 1, 1, 0.8 if bool(Save.s("colorblind")) else 0.55), 1.2)
		Art.ring(self, p, 1, int(u["type"]), cbm(), 1.0)
		Art.unit(self, p, int(u["type"]), 1, -1.0, 0.0, 0.0, 0.0, 1.0, time, 1.0, cbm())
	var lbl := L.t("fog_scout", [seen.size(), armies[1].units.size()])
	_text(ORIGIN + Vector2(13 * CS, 18), lbl, ts(15), Color(1, 0.9, 0.6), true, true, 5.5 * CS)

## ── #21 雙人接力遠征：同一台電腦，兩人輪流負責一站（奇數站玩家 1、偶數站玩家 2），事件也由剛打完的人選 ──
var ga_coop := false
var coop_seen := 0   # 已經出過交接畫面的站

static func coop_player(stage: int) -> int:
	return 1 + (stage - 1) % 2

func _enter_gauntlet() -> void:
	ga_coop = false
	super._enter_gauntlet()

func _coop_start() -> void:
	if not Save.data.get("gauntlet_run", {}).is_empty():
		_ask_confirm(L.t("coop_replace_q"), func(): _coop_go(), "")
		return
	_coop_go()

func _coop_go() -> void:
	call("_enter_gauntlet_new")
	ga_coop = true
	coop_seen = 0

func _coop_tick() -> void:
	if ga_coop and mode == Mode.GAUNTLET and state == St.PLACE and overlay == "" and coop_seen != gauntlet_stage:
		coop_seen = gauntlet_stage
		overlay = "coop_hand"
		_focus = 0

func _draw_coop_hand() -> void:
	var p := coop_player(gauntlet_stage)
	var body := L.t("coop_hand_body", [gauntlet_stage, p])
	var P := modal_rect(560, 12.0 + h1_bottom(0.0) + GAP_L + text_h(body, tz("B"), 480, true) + GAP_XL + 52.0 + GAP_L)
	_panel(P)
	var y := _h1(Vector2(640, P.position.y + 12), L.t("coop_hand", [p])) + GAP_L
	_text(Vector2(640, y), body, tz("B"), Color.WHITE, true, true, 480)
	y += text_h(body, tz("B"), 480, true) + GAP_XL
	_btn(Rect2(640 - 140, y, 280, 52), L.t("coop_ready", [p]), func(): overlay = "", true, true)

func _coop_hud() -> void:
	if ga_coop and mode == Mode.GAUNTLET:
		var s := L.t("coop_turn", [coop_player(gauntlet_stage)])
		var w := _width(s, tz("S"), true) + 24.0
		var r := Rect2(16, 96, w, tz("S") * 1.6)
		_tex_box(r, "wood", Color(0.2, 0.32, 0.5) if coop_player(gauntlet_stage) == 1 else Color(0.45, 0.22, 0.2))
		_text(r.position + Vector2(12, tz("S") * 0.25), s, tz("S"), Color.WHITE, false, true, w)

## ── #22 相鄰陣法：擺陣時把會拿到加成的相鄰組合用粉筆線連起來 ──
const Adj = preload("res://scripts/core/adj_defs.gd")

static func adj_links(units: Array, pos_of: Callable) -> Array:
	var out: Array = []
	for i in units.size():
		for p in Adj.PAIRS:
			if int(units[i]["type"]) != int(p[0]):
				continue
			var a: Vector2i = pos_of.call(units[i])
			for j in units.size():
				if i != j and int(units[j]["type"]) == int(p[1]):
					var b: Vector2i = pos_of.call(units[j])
					if (b - a).length_squared() <= Adj.RANGE * Adj.RANGE:
						out.append([a, b])
	return out

func _adj_draw(a) -> void:
	if rules == null or not rules.adj:
		return
	for l in adj_links(a.units, func(u): return a.pos_of(u)):
		_chalk_line(_foot_of(l[0]) - Vector2(0, 0.3 * CS), _foot_of(l[1]) - Vector2(0, 0.3 * CS), Color(1, 0.85, 0.3, 0.8), 2.5)

## 熟練度外觀小物：3 級起在兵卡上畫星章（3、4 級銀、5 級金），圖鑑也看得到等級
func _mastery_badge(r: Rect2, t: int) -> void:
	var lv := Career.level(int(Save.data.get("mastery", {}).get(str(t), 0)))
	if lv < 3:
		return
	_icon("star", r.position + Vector2(r.size.x / 2, 30), 16.0, Color("#ffd166") if lv >= 5 else Color("#d8dde6"))
