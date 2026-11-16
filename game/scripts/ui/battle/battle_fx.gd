extends "res://scripts/ui/battle/battle_state.gd"
## 由 battle_view.gd 拆出（V9 P1，行為不變）

func _draw_busy(pct: int) -> void:
	var msg: String = L.t("busy_wait") if pct < 0 else L.t("busy_calc", [pct])
	var w := _width(msg, tz("B"), true) + 40
	draw_rect(Rect2(640 - w / 2, 360, w, tz("B") * 1.8), Color(TH_WOOD_D, 0.94))
	_text(Vector2(640, 360 + tz("B") * 0.35), msg, tz("B"), ACCENT, true, true)



## 小火焰圖示（背水）。
func _flame(c: Vector2, sc: float) -> void:
	var fl := sin(time * 14.0) * 1.5
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -11 - fl) * sc, c + Vector2(6, 2) * sc, c + Vector2(0, 7) * sc, c + Vector2(-6, 2) * sc]), Color(1, 0.4, 0.1))
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -5 - fl * 0.5) * sc, c + Vector2(3, 3) * sc, c + Vector2(0, 6) * sc, c + Vector2(-3, 3) * sc]), Color(1, 0.85, 0.3))



func _report_add(team: int, type: int, kind: String, label: String, col: Color, src = null) -> void:
	# V1.3 C3：戰報事件發生的地方，地上閃一個墨圈（0.6 秒，畫在影子與隊伍圈底下），視線不用一直往下看
	if src != null:
		_add_fx({"kind": "inkring", "p": _upos(src), "t": 0.0, "dur": 0.6})
	for i in report_log.size():
		var e: Dictionary = report_log[i]
		if e["team"] == team and e["type"] == type and e["kind"] == kind and time - float(e["t"]) < 2.0:
			e["n"] += 1
			e["t"] = time
			report_log.remove_at(i)
			report_log.push_front(e)
			return
	report_log.push_front({"team": team, "type": type, "kind": kind, "label": label, "col": col, "n": 1, "t": time})
	if report_log.size() > REPORT_CAP:
		report_log.resize(REPORT_CAP)


func _draw_start_cue() -> void:
	if start_hold <= 0.0:
		return
	var k := clampf(start_hold, 0.0, 1.0)
	var msg: String = L.t("start")
	var sz := tcap(tz("D"), 64)
	_text(Vector2(640, 340), msg, sz, Color(1, 0.85, 0.4, k), true, true)
	for tm in 2:
		var x: float = ORIGIN.x + (float(view.max_x(tm)) / 1000.0 if view.has_method("max_x") else (6.0 if tm == 0 else 10.0) * 1.0) * CS
		draw_line(Vector2(x, ORIGIN.y), Vector2(x, ORIGIN.y + fld_size.y), Color(Art.team_color(tm, cbm()), 0.9 * k), 5.0)



## 狂熱暖色暈影（第七輪 D5）：受簡化特效控制。
func _draw_frenzy_edge() -> void:
	if view == null or not view.frenzy or view.finished or bool(Save.s("reduce_fx")):
		return
	var a := 0.16 + 0.05 * sin(time * 5.0)
	for k in 4:
		var w := 22.0 - k * 5.0
		var col := Color(1.0, 0.42, 0.1, a * (0.35 + k * 0.2))
		draw_rect(Rect2(0, 86, 1280, w), col)
		draw_rect(Rect2(0, 800 - w, 1280, w), col)
		draw_rect(Rect2(0, 86, w, 714), col)
		draw_rect(Rect2(1280 - w, 86, w, 714), col)



func _draw_battle_report() -> void:
	if report_log.is_empty():
		return
	var ctl: bool = play_kind != "official"
	var rows := 1 if ctl else 2     # 重播時底部有控制列，只剩一排
	var rh: float = tz("S") * 1.32
	var y0: float = 800.0 - rows * rh - 4.0 if ctl else minf(720.0, 766.0 - rows * rh)
	if pad_mode:
		if ctl:
			return   # V1.2.1：重播／覆盤有控制列＋手把提示列，底部放不下戰報（事件看時間軸）
		y0 -= 32.0   # V1.2.1：手把模式底部有按鍵提示列（30px），戰報讓開
	var cw := 412.0
	var plain := bool(Save.s("plain_ui"))
	if not ctl:
		var bar := Rect2(0, y0 - 3, 1280, mini(ceili(report_log.size() / 3.0), rows) * rh + 6)
		if plain:
			draw_rect(bar, Color(0, 0, 0, 0.72))   # 第十輪 V10：底條（V1.2.1 加深，戰報字對比）
		else:
			# V1.2 C6：戰報條是一條深木槽（上緣一道亮邊），不是黑色半透明帶
			_tex_box(bar, "groove", Color(0.42, 0.31, 0.22, 0.92))
			draw_rect(Rect2(0, bar.position.y, 1280, 1.5), Color(1, 0.88, 0.62, 0.22))
	for i in mini(report_log.size(), rows * 3):
		var e: Dictionary = report_log[i]
		var age: float = time - float(e["t"])
		var a := clampf(1.6 - age * 0.4, 0.9, 1.0)   # V1.2.1 F5：舊條目最淡到 90%（35% 讀不到）
		var p := Vector2(14.0 + (i % 3) * cw, y0 + (i / 3) * rh)
		var mark := "●" if e["team"] == 0 else "◆"
		var line := "%s %s" % [L.t("unit_%d" % int(e["type"])), e["label"]]
		if int(e["n"]) > 1:
			line += " ×%d" % int(e["n"])
		if plain:
			_text(p, mark, tz("S"), Color(_legible_on(Art.team_color(int(e["team"]), cbm()), Color(0.14, 0.16, 0.1)), 1.0), false, true)   # V1.2.1：深色隊色記號在黑底條上提亮
		else:
			# V1.2 C6：隊色小章（藍圓、紅菱形，色盲也分得出）；頭像太小會糊（Antigravity impl4），不放
			var sz := float(tz("S"))
			var c := p + Vector2(sz * 0.5, sz * 0.62)
			var tc := Art.team_color(int(e["team"]), cbm())
			var rr := sz * 0.42
			if int(e["team"]) == 0:
				draw_circle(c, rr + 2.0, Color(INK, a), true, -1.0, true)
				draw_circle(c, rr, Color(tc, a), true, -1.0, true)
				draw_circle(c + Vector2(-rr * 0.35, -rr * 0.35), rr * 0.28, Color(1, 1, 1, 0.45 * a), true, -1.0, true)
			else:
				var dm := PackedVector2Array([c + Vector2(0, -rr - 3), c + Vector2(rr + 3, 0), c + Vector2(0, rr + 3), c + Vector2(-rr - 3, 0)])
				draw_colored_polygon(dm, Color(INK, a))
				var di := PackedVector2Array([c + Vector2(0, -rr), c + Vector2(rr, 0), c + Vector2(0, rr), c + Vector2(-rr, 0)])
				draw_colored_polygon(di, Color(tc, a))
				draw_circle(c + Vector2(-rr * 0.25, -rr * 0.3), rr * 0.22, Color(1, 1, 1, 0.45 * a), true, -1.0, true)
		var lc: Color = e["col"]
		lc = _legible_on(lc, Color(0.3, 0.22, 0.15) if not plain else Color(0.24, 0.26, 0.16))   # 對木槽（或黑底條）提亮到 5:1（刺客紫原本太暗）
		_text(p + Vector2(tz("S") + 6.0, 0), line, tz("S"), Color(lc, a), false, true, cw - tz("S") - 14.0)



func _merge_text(tid: int, kind: String, label: String, dmg: int, p: Vector2, col: Color) -> void:
	var dn: String = str(Save.s("dmg_nums"))
	if (dn == "off" or speed >= FAST_SPEED) and int(TEXT_TIER.get(kind, 1)) < 2:
		return   # V1.5：傷害與治療數字關掉（關鍵事件的字照樣出）；V1.0.0 P7：4 倍速以上一般跳字也不出
	if int(TEXT_TIER.get(kind, 1)) >= 2:
		text_key_in += 1
	var cell := Vector2i(floori(p.x / TEXT_CELL.x), floori(p.y / TEXT_CELL.y))
	for f in ([] if dn == "each" else fx):   # V1.5：「逐次」不合併
		if f["kind"] == "text" and not f.get("screen", false) and f.get("ek", "") == kind and f.get("cell", Vector2i(-99, -99)) == cell and f["t"] < 0.35:
			f["n"] += 1
			f["sum"] += dmg
			f["s"] = ("+%d" % f["sum"]) if kind == EV.HEAL else "%s ×%d（%d）" % [label, f["n"], f["sum"]]
			f["t"] = 0.0
			f["pop"] = 0.18
			if int(f.get("tier", 1)) >= 2:
				text_key_shown += 1
			return
	var tier: int = TEXT_TIER.get(kind, 1)
	var world := 0
	for f in fx:
		if f["kind"] == "text" and not f.get("screen", false):
			world += 1
	if world >= TEXT_CAP:
		# 丟最舊的一般跳字；全部都是關鍵的就照樣加（關鍵不能漏）
		var oldest := -1
		for k in fx.size():
			var f2: Dictionary = fx[k]
			if f2["kind"] == "text" and not f2.get("screen", false) and int(f2.get("tier", 1)) < 2:
				if oldest < 0 or f2["t"] > fx[oldest]["t"]:
					oldest = k
		if oldest >= 0:
			fx.remove_at(oldest)
			text_dropped += 1
		elif tier < 2:
			text_dropped += 1
			return
		else:
			# 全部都是關鍵跳字：併進最近的同種跳字（硬上限，Codex S1 #5），關鍵不漏、只是合併
			var near := -1
			for k2 in fx.size():
				var f3: Dictionary = fx[k2]
				if f3["kind"] == "text" and f3.get("ek", "") == kind and (near < 0 or f3["p"].distance_to(p) < fx[near]["p"].distance_to(p)):
					near = k2
			if near >= 0:
				var fn: Dictionary = fx[near]
				fn["n"] += 1
				fn["sum"] += dmg
				fn["s"] = "%s ×%d（%d）" % [label, fn["n"], fn["sum"]]
				fn["t"] = 0.0
				fn["pop"] = 0.18
				text_key_shown += 1
				return
			# 沒有同種的：取代最舊的關鍵跳字（它已經顯示過了），維持硬上限
			var old := -1
			for k4 in fx.size():
				var f4: Dictionary = fx[k4]
				if f4["kind"] == "text" and not f4.get("screen", false) and (old < 0 or f4["t"] > fx[old]["t"]):
					old = k4
			if old >= 0:
				fx.remove_at(old)
	if tier >= 2:
		text_key_shown += 1
	fx.append({"kind": "text", "p": p, "s": ("+%d" % dmg) if kind == EV.HEAL else "%s %d" % [label, dmg], "c": col, "t": 0.0, "dur": 0.85, "size": 18 if tier >= 2 else (14 if kind == EV.HEAL else 16),
		"tid": tid, "ek": kind, "n": 1, "sum": dmg, "screen": false, "cell": cell, "tier": tier, "pop": 0.0, "plain": kind == EV.HEAL})



## 每幀排版：關鍵在前、新的在前；和已放好的（不在淡出中的）重疊就往上推。結果存在 f["rp"]。
## 1.6.0 B08（P3.3、S4）：再避開兵偶頭胸框（face_rects）、夾在盤內 ≥TEXT_BOARD_PAD；找位置的順序＝原位往上推 → 左右換邊再往上推，
## 最遠 TEXT_MAX_MOVE。找不到：一般跳字丟掉（計 text_dropped），關鍵跳字放在蓋最少的位置（關鍵不能漏）。
## 面積：顯示中（不透明度 ≥0.35）的跳字總面積 ≤ 交戰區 × TEXT_AREA_MAX，超過就丟一般跳字（新的、關鍵的先佔）。
const TEXT_BOARD_PAD := 12.0
const TEXT_MAX_MOVE := 96.0   # 1.5 格：再遠就看不出是誰的字
const TEXT_AREA_MAX := 0.15
const TEXT_LEAD_MIN := 18.0   # 推離原位超過這麼遠就畫引線
## 1.6.0 B08（P3.4）：裝飾特效上限——單一特效面積 ≤ 交戰區 × FX_AREA_MAX（超過就等比縮）、最亮色相對亮度 ≤ FX_LUM_MAX（保持色相壓暗）；
## 畫在兵偶頭胸上的小特效（音符、閃光叉、治療十字）壓到 FX_FACE_ALPHA。表示範圍的（隕石落點圈、範圍預告）不縮——語意（P3.5）。
const FX_AREA_MAX := 0.04
const FX_LUM_MAX := 0.8
const FX_FACE_ALPHA := 0.5
var _fx_faces: Dictionary = {}
var _fx_eng_area := 0.0
var fx_stats := {"max_area": 0.0, "max_lum": 0.0}   # 量測：這一幀畫出的裝飾特效裡最大面積比、最亮相對亮度

static func fx_lum_cap(c: Color) -> Color:
	var l := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
	if l <= FX_LUM_MAX:
		return c
	var k := FX_LUM_MAX / maxf(l, 1e-4)
	return Color(c.r * k, c.g * k, c.b * k, c.a)

## 面積 area 的裝飾特效要縮多少（≤1）；同時記量測
func fx_area_scale(area: float) -> float:
	var eng := _fx_eng_area if _fx_eng_area > 0.0 else Rect2(ORIGIN, fld_size).get_area()
	var sc := minf(1.0, sqrt(eng * FX_AREA_MAX / maxf(1.0, area)))
	fx_stats["max_area"] = maxf(fx_stats["max_area"], area * sc * sc / eng)
	return sc

## 畫和量用同一支（測試不能在 _draw 外畫圖）
func glow_radius(f: Dictionary, k: float) -> float:
	var r: float = GLOW[f["kind"]][1] * (0.7 + 0.3 * minf(1.0, k * 3.0))
	return r * fx_area_scale(PI * r * r * 0.8)

func boom_radius(k: float) -> float:
	var br := 14.0 + _smoothstep01(k) * 26.0
	return br * fx_area_scale(PI * br * br * 0.8 * 0.75)   # 鋸齒星芒約 0.75 個橢圓

func fx_on_face(p: Vector2, rad: float) -> bool:
	var r := Rect2(p - Vector2(rad, rad), Vector2(rad, rad) * 2.0)
	for id in _fx_faces:
		if (_fx_faces[id] as Rect2).intersects(r):
			return true
	return false

func fx_col(c: Color) -> Color:   # 壓亮度並記量測（灰階＝畫面值的加權和）
	var cc := fx_lum_cap(c)
	fx_stats["max_lum"] = maxf(fx_stats["max_lum"], 0.2126 * cc.r + 0.7152 * cc.g + 0.0722 * cc.b)
	return cc

func face_rects() -> Dictionary:
	return {}   # battle_units 覆寫：{兵 id: 頭胸框}（要用到兵的畫面位置與縮放）

func engage_rect() -> Rect2:
	return Rect2(ORIGIN, fld_size)   # battle_units 覆寫

func _layout_texts() -> void:
	var t_us := Time.get_ticks_usec()
	_fx_faces = face_rects()   # 特效上限（P3.4）同一幀共用；{兵 id: 頭胸框}
	_fx_eng_area = engage_rect().get_area()
	fx_stats = {"max_area": 0.0, "max_lum": 0.0}
	var list: Array = []
	for f in fx:
		if f["kind"] == "text" and not f.get("screen", false):
			list.append(f)
	if list.is_empty():
		layout_us = Time.get_ticks_usec() - t_us
		return
	list.sort_custom(func(a, b): return a.get("tier", 1) > b.get("tier", 1) or (a.get("tier", 1) == b.get("tier", 1) and a["t"] < b["t"]))
	var board := Rect2(ORIGIN, fld_size).grow(-TEXT_BOARD_PAD)
	var budget := _fx_eng_area * TEXT_AREA_MAX
	var used := 0.0
	var placed: Array = []      # 已放好的完整畫出範圍（含紙條、出場壓下）
	var placed_key: Array = []  # 已放好的關鍵跳字（擠不下的關鍵字併進最近的一個）
	var drop: Array = []
	for f in list:
		var k: float = f["t"] / f["dur"]
		var slam := 1.0 - minf(float(f["t"]) / 0.1, 1.0)
		var at: Vector2 = f["p"] + Vector2(0, -k * 26 - 8.0 * slam * slam)   # 出場壓下的 8px 也算進排版（Codex B08 r1 #1）
		var r := _text_rect(f, at)
		var pad := _text_pad(f)
		var dr := r.grow_individual(pad[0], pad[1], pad[2], pad[3])
		var key := int(f.get("tier", 1)) >= 2
		var vis := _text_alpha(f) >= 0.35
		var own := int(f.get("tid", -1))
		var res: Array = [dr, true]
		if vis and used + dr.get_area() > budget:
			res = [dr, false]   # 超過面積：一般丟、關鍵併
		else:
			res = _text_slot(dr, placed, _fx_faces, board, key, own, f.get("off", Vector2.INF), f["p"] + Vector2(0, 10))
		if not res[1] and vis:
			if key:
				# 擠不下的關鍵字：併進最近的關鍵字；附近沒有就只留在底部戰報列（_report_add 已記；和第七輪 D1「混戰時關鍵技能進戰報列」同一條）
				if _relayout_in or not _merge_into(f, placed_key):   # 重排那一次不再合併（Codex B08 r3：合併會讓已排好的框過期）
					text_key_to_report += 1
				drop.append([f, false])
				continue
			drop.append([f, true])
			continue
		f["off"] = (res[0] as Rect2).position - dr.position   # 下一幀先試同樣的位移
		f["stuck"] = not res[1]
		dr = res[0]
		r.position = dr.position + Vector2(pad[0], pad[1])
		placed.append(dr)
		if key:
			placed_key.append(f)
		if vis:
			used += dr.get_area()
		f["rp"] = Vector2(r.get_center().x, r.position.y + 3.0)
		f["rr"] = r
		f["dr"] = dr
		var fr: Rect2 = own_face(_fx_faces, own, f["p"] + Vector2(0, 10))
		f["lead"] = Vector2(fr.get_center().x, fr.position.y - 2.0) if fr.size.x > 0.0 else f["p"] + Vector2(0, 10)
		f["seg"] = lead_seg(dr, f["lead"], _fx_faces, fr) if r.get_center().distance_to(f["p"] + Vector2(0, -k * 26.0)) > TEXT_LEAD_MIN else []
	for d in drop:
		fx.erase(d[0])
		if d[1]:
			text_dropped += 1
	if _relayout and not _relayout_in:
		_relayout = false
		_relayout_in = true
		_layout_texts()   # 重排（合併後的寬度、避讓、面積都重算；只遞迴一層）
		_relayout_in = false
		layout_us = Time.get_ticks_usec() - t_us   # 含重排
		return
	_relayout = false
	layout_us = Time.get_ticks_usec() - t_us

var layout_us := 0   # 量測：上一次排版耗時（µs）
var _relayout := false
var _relayout_in := false
var text_key_to_report := 0   # 量測：擠不下、附近也沒有可併的關鍵字，只留在戰報列的次數

## 紙條、出場、描邊實際畫出去的範圍（相對字框 _text_rect 的左、上、右、下外擴）：紙條 _bubble 外擴 4／1／4／2、
## 下緣細引線 9.5＋點、陰影往左上 1／2；純數字與補血字只有描邊。
func _text_pad(f: Dictionary) -> Array:
	if f.get("plain", false) or is_num_text(str(f["s"])):
		return [3.0, 3.0, 3.0, 3.0]
	return [5.0, 3.0, 4.0, 14.0]   # 紙條底 2＋引線 9.5＋圓點 1.6＝13.1，取 14（Codex B08 r2 #3）

## 擠不下的關鍵跳字：併進 2.5 格內最近的、已放好的關鍵跳字（「衝鋒！×2（70）」）。關鍵不漏、也不蓋臉。
func _merge_into(f: Dictionary, keys: Array) -> bool:
	var near = null
	for g in keys:
		if g.get("ek", "") != f.get("ek", ""):
			continue   # 只併同種（Codex B08 r2 #2：異種累加會混傷害語意）；異種擠不下就只留戰報列
		var d: float = (g["p"] as Vector2).distance_to(f["p"])
		if d <= TEXT_MAX_MOVE_KEY and (near == null or d < (near["p"] as Vector2).distance_to(f["p"])):
			near = g
	if near == null:
		return false
	near["n"] = int(near["n"]) + int(f.get("n", 1))
	near["sum"] = int(near["sum"]) + int(f.get("sum", 0))
	var lab := str(f["s"]).split(" ")[0]
	near["s"] = "%s ×%d（%d）" % [lab, near["n"], near["sum"]]
	_relayout = true   # 合併後字變寬：這一幀重排一次（Codex B08 r2 #1）
	return true

## 找一個不疊別的跳字、不蓋別隻兵的頭胸、在盤內的位置（r＝完整畫出範圍）。回傳 [Rect2, 找到乾淨位置?]。
## 候選：原位、左右各一／兩個字寬，各自往上推、往下（腳下）推；最終位移 ≤ 上限（一般 1.5 格、關鍵 2.5 格）；
## 推離原位要畫引線時，引線也不准穿過別隻的頭胸。取各方向第一個乾淨位置中離原位最近的；都不行回傳蓋得最少的。
const TEXT_MAX_MOVE_KEY := 160.0   # 2.5 格
func _text_slot(r: Rect2, placed: Array, faces: Dictionary, board: Rect2, far := false, own := -1, pref := Vector2.INF, anchor := Vector2.INF) -> Array:
	if anchor == Vector2.INF:
		anchor = Vector2(r.get_center().x, r.end.y + 10.0)
	var lim := TEXT_MAX_MOVE_KEY if far else TEXT_MAX_MOVE
	var near: Array = []
	var zone := r.grow_individual(r.size.x + 20.0, lim, r.size.x + 20.0, lim)
	for id in faces:
		var q: Rect2 = faces[id]
		if zone.intersects(q):
			near.append(q)
	var own_r: Rect2 = own_face(faces, own, anchor)
	var lead_to := Vector2(own_r.get_center().x, own_r.position.y - 2.0) if own_r.size.x > 0.0 else anchor
	# 黏著：上一幀的位移還乾淨就沿用（不每幀重找；跳字也不會左右跳）
	if pref != Vector2.INF:
		var pc := Rect2(r.position + pref, r.size)
		if board.encloses(pc) and pc.position.distance_to(r.position) <= lim and _cand_cost(pc, r, placed, near, own_r, lead_to)[0] == 0.0:
			return [pc, true]
	var best := r
	var best_cost := INF
	var clean := r
	var clean_d := INF
	var side := r.size.x * 0.5 + 10.0
	var dxs: Array = [0.0]
	if own_r.size.x > 0.0:
		dxs.append(own_r.end.x + 4.0 - r.position.x)    # 緊貼自己那隻的右側（引線最短、一看就知道是誰的）
		dxs.append(own_r.position.x - 4.0 - r.end.x)    # 緊貼左側
	dxs.append_array([-side, side, -side * 2.0, side * 2.0])
	for dir in [-1.0, 1.0]:
		for dx in dxs:
			var dy := 0.0 if dir < 0.0 else 4.0
			var last_y := INF
			while dy <= lim:
				var c := Rect2(r.position + Vector2(dx, dir * dy), r.size)
				c.position.x = clampf(c.position.x, board.position.x, maxf(board.position.x, board.end.x - c.size.x))
				c.position.y = clampf(c.position.y, board.position.y, maxf(board.position.y, board.end.y - c.size.y))
				if c.position.y == last_y:
					break   # 被盤邊夾住：再推也是同一個位置
				last_y = c.position.y
				var dist := c.position.distance_to(r.position)
				if dist > lim or dist >= clean_d:
					break   # clean_d 是分數（距離＋罰分）：比它遠的不可能更好   # 最終位移超過上限（Codex B08 r1 #4），或已經比找到的乾淨位置遠：這個方向不用再推
				var cj: Array = _cand_cost(c, r, placed, near, own_r, lead_to)
				if cj[0] == 0.0:
					# Hydrogen B08 r3：推離原位又拉不出完整引線＝看不出是誰的 → 重罰，優先選「不用推」或「推了有引線」的位置
					var score := dist
					if dist > TEXT_LEAD_MIN and not _lead_clear(c, lead_to, near, own_r):
						score += 1000.0
					if score < clean_d:
						clean_d = score
						clean = c
					break   # 這個方向第一個乾淨的位置就是它最近的
				if cj[0] < best_cost:
					best_cost = cj[0]
					best = c
				dy += maxf(4.0, float(cj[1]) + 2.0)   # 直接跳過擋路那個框
	if clean_d < INF:
		return [clean, true]   # Hydrogen B08 r1：推太遠會被看成別隻的字 → 取最近
	return [best, false]

## 這個跳字「自己那隻」的頭胸框：兵還在錨點附近（≤1.2 格）才算；兵已經走遠（或對不上），引線改指錨點、也不豁免任何框
func own_face(faces: Dictionary, own: int, anchor: Vector2) -> Rect2:
	var q: Rect2 = faces.get(own, Rect2())
	if q.size.x <= 0.0 or anchor == Vector2.INF:
		return q
	return q if Vector2(q.get_center().x, q.position.y).distance_to(anchor) <= CS * 1.2 else Rect2()

## 候選位置的代價：疊到已放的跳字、蓋到頭胸（×4）。回傳 [代價, 往前跳多少]。（引線不算：引線在碰到頭胸框前就停，見 lead_seg）
func _cand_cost(c: Rect2, r: Rect2, placed: Array, near: Array, own_r: Rect2, lead_to: Vector2) -> Array:
	var cost := 0.0
	var jump := 0.0
	var up := c.position.y <= r.position.y
	for q: Rect2 in placed:
		if q.intersects(c):
			cost += c.intersection(q).get_area() + 1.0
			jump = maxf(jump, (c.end.y - q.position.y) if up else (q.end.y - c.position.y))
	for q: Rect2 in near:
		if q.intersects(c):
			cost += c.intersection(q).get_area() * 4.0 + 1.0
			jump = maxf(jump, (c.end.y - q.position.y) if up else (q.end.y - c.position.y))
	return [cost, jump]

## 引線：從字框邊到「自己那隻的頭頂」（兵走遠了就到錨點）。整條不穿過別隻的頭胸框、終點在盤內才畫（引線本身不蓋臉）；
## 回傳 [起點, 終點]；不畫回傳空陣列。
func lead_seg(dr: Rect2, lead_to: Vector2, faces: Dictionary, own_r: Rect2) -> Array:
	var from := Vector2(clampf(lead_to.x, dr.position.x + 6.0, dr.end.x - 6.0), dr.end.y if lead_to.y > dr.get_center().y else dr.position.y)
	var t_end := 1.0
	for id in faces:
		var q: Rect2 = faces[id]
		if q == own_r:
			continue
		var te := seg_entry(from, lead_to, q)
		if te < t_end:
			t_end = te
	# Hydrogen B08 r2：停在半空的短引線反而看不出歸屬 → 整條通（不穿過別隻、終點在盤內）才畫，否則不畫
	if t_end < 1.0 or not Rect2(ORIGIN, fld_size).has_point(lead_to) or from.distance_to(lead_to) < 6.0:
		return []
	return [from, lead_to]

## 同 lead_seg 的判斷，只查附近的頭胸框（找位置時用；附近＝候選範圍外推，引線終點在範圍內）
func _lead_clear(c: Rect2, lead_to: Vector2, near: Array, own_r: Rect2) -> bool:
	if not Rect2(ORIGIN, fld_size).has_point(lead_to):
		return false
	var from := Vector2(clampf(lead_to.x, c.position.x + 6.0, c.end.x - 6.0), c.end.y if lead_to.y > c.get_center().y else c.position.y)
	if from.distance_to(lead_to) < 6.0:
		return false
	for q: Rect2 in near:
		if q != own_r and seg_entry(from, lead_to, q) < 1.0:
			return false
	return true

## 線段 a–b 進入矩形 q 的參數 t（0～1）；不相交回傳 2.0；起點就在裡面回傳 0
static func seg_entry(a: Vector2, b: Vector2, q: Rect2) -> float:
	var t0 := 0.0
	var t1 := 1.0
	var d := b - a
	for e in [[-d.x, a.x - q.position.x], [d.x, q.end.x - a.x], [-d.y, a.y - q.position.y], [d.y, q.end.y - a.y]]:
		var pp: float = e[0]
		var qq: float = e[1]
		if absf(pp) < 1e-9:
			if qq < 0.0:
				return 2.0
		else:
			var t := qq / pp
			if pp < 0.0:
				t0 = maxf(t0, t)
			else:
				t1 = minf(t1, t)
			if t0 > t1:
				return 2.0
	return t0

## 線段 a–b 是否穿過矩形 q（Liang–Barsky 裁切）
static func seg_hits_rect(a: Vector2, b: Vector2, q: Rect2) -> bool:
	var t0 := 0.0
	var t1 := 1.0
	var d := b - a
	for e in [[-d.x, a.x - q.position.x], [d.x, q.end.x - a.x], [-d.y, a.y - q.position.y], [d.y, q.end.y - a.y]]:
		var pp: float = e[0]
		var qq: float = e[1]
		if absf(pp) < 1e-9:
			if qq < 0.0:
				return false
		else:
			var t := qq / pp
			if pp < 0.0:
				t0 = maxf(t0, t)
			else:
				t1 = minf(t1, t)
			if t0 > t1:
				return false
	return true



## 量測（測試與手感輪用）：正常顯示的跳字兩兩最大重疊比例（交集÷較小框），以及淡出中與其他的最大重疊。
func text_overlap_stats() -> Dictionary:
	var vis: Array = []
	var fading: Array = []
	for f in fx:
		if f["kind"] == "text" and not f.get("screen", false) and f.has("rr"):
			(vis if _text_alpha(f) >= 0.35 else fading).append(f["rr"])
	var worst := 0.0
	for a in vis.size():
		for b in range(a + 1, vis.size()):
			worst = maxf(worst, _overlap(vis[a], vis[b]))
	var worst_f := 0.0
	for fr: Rect2 in fading:
		for o: Rect2 in vis + fading:
			if o != fr:
				worst_f = maxf(worst_f, _overlap(fr, o))
	# 1.6.0 B08（S4）：顯示中跳字（完整畫出範圍：紙條、出場、引線）蓋到別隻兵頭胸框的面積、出盤內 12px 的個數、總面積÷交戰區
	var face_px := 0.0
	var clipped := 0
	var area := 0.0
	var board := Rect2(ORIGIN, fld_size).grow(-TEXT_BOARD_PAD + 0.5)
	var faces: Dictionary = face_rects()
	for f in fx:
		if f["kind"] != "text" or f.get("screen", false) or not f.has("dr") or _text_alpha(f) < 0.35:
			continue
		var dr: Rect2 = f["dr"]
		area += dr.get_area()
		if not board.encloses(dr):
			clipped += 1
		var own_r: Rect2 = own_face(faces, int(f.get("tid", -1)), f["p"] + Vector2(0, 10))
		var sg: Array = f.get("seg", [])
		for id in faces:
			var q: Rect2 = faces[id]
			if q.intersects(dr):
				face_px += dr.intersection(q).get_area()
			if sg.size() == 2 and q != own_r and seg_hits_rect(sg[0], sg[1], q.grow(-0.5)):
				face_px += 1.0   # 引線（實際畫的那段）穿過別隻的頭胸
	return {"visible": vis.size(), "fading": fading.size(), "max_overlap": worst, "max_overlap_fading": worst_f,
		"face_px": int(face_px), "clipped": clipped, "area_ratio": area / maxf(1.0, engage_rect().get_area())}


## 最後時刻（第三輪 V2）：慢動作期間，螢幕上 y<165（橫幅下方那一帶）的戰場跳字淡到 0.2。
func _clutch_dim(world_p: Vector2) -> float:
	if slow_left <= 0.0 and clutch_t <= 0.0:
		return 1.0
	var sp: Vector2 = _cam * world_p
	return 0.2 if sp.y < 165.0 else 1.0



## 慢動作時離焦點遠的單位與特效降到 0.6。
func _focus_dim(world_p: Vector2) -> float:
	if slow_left <= 0.0 or state != St.BATTLE:
		return 1.0
	return 0.6 if world_p.distance_to(action_focus) > 200.0 else 1.0


## 最後時刻橫幅：全寬暗帶＋大字，畫在所有戰場東西上面（螢幕座標）。
func _draw_clutch_banner() -> void:
	if clutch_t <= 0.0 or state != St.BATTLE:
		return
	var a := clampf(clutch_t / 0.3, 0.0, 1.0) * clampf((1.6 - clutch_t) / 0.15, 0.0, 1.0)
	var y := 104.0
	for i in 6:
		draw_rect(Rect2(0, y + i * 6, 1280, 6), Color(0, 0, 0, 0.55 * a * (1.0 - absf(i - 2.5) / 3.5)))
	_text(Vector2(640, y - 2), L.t("clutch"), ts(34), Color(ACCENT, a), true, true, 900)



## 慢動作暗角：螢幕四周往內的多層橢圓暗帶（金色調）。
## V1.3 C4：關鍵時刻。焦點外圍壓暗 15%（中間 170px 留亮）、一圈手繪墨線往中心收，0.8 秒。只是畫面，不改播放速度。
func _draw_key_moment(k: float) -> void:
	var sp: Vector2 = _cam * key_p
	var st := sin(k * PI) * 0.15
	var r0 := 170.0
	var r1 := 1700.0
	for i in 28:
		var a0 := i * TAU / 28.0
		var a1 := (i + 1) * TAU / 28.0
		var d0 := Vector2(cos(a0), sin(a0))
		var d1 := Vector2(cos(a1), sin(a1))
		var ci := Color(0.08, 0.05, 0.02, 0.0)
		var co := Color(0.08, 0.05, 0.02, st)
		draw_primitive(PackedVector2Array([sp + d0 * r0, sp + d1 * r0, sp + d1 * (r0 + 60.0), sp + d0 * (r0 + 60.0)]), PackedColorArray([ci, ci, co, co]), PackedVector2Array())
		draw_primitive(PackedVector2Array([sp + d0 * (r0 + 60.0), sp + d1 * (r0 + 60.0), sp + d1 * r1, sp + d0 * r1]), PackedColorArray([co, co, co, co]), PackedVector2Array())
	_hand_ring(sp + Vector2(0, -16), lerpf(150.0, 34.0, k), Color(0.12, 0.07, 0.04, 0.7 * (1.0 - k)), 3.0, true, 2)

func _draw_vignette(strength: float) -> void:
	if strength <= 0.0:
		return
	var c := Vector2(640, 443)
	var rx := 640.0
	var ry := 357.0
	for ring in 6:
		var k0 := (0.70 + ring * 0.06) * 1.25
		var k1 := k0 + 0.06 * 1.25
		var c0 := Color(0.20, 0.12, 0.0, strength * 0.14 * ring)
		var c1 := Color(0.20, 0.12, 0.0, strength * 0.14 * (ring + 1))
		for i in 32:
			var a0 := i * TAU / 32.0
			var a1 := (i + 1) * TAU / 32.0
			var d0 := Vector2(cos(a0) * rx, sin(a0) * ry)
			var d1 := Vector2(cos(a1) * rx, sin(a1) * ry)
			draw_primitive(PackedVector2Array([c + d0 * k0, c + d1 * k0, c + d1 * k1, c + d0 * k1]), PackedColorArray([c0, c0, c1, c1]), PackedVector2Array())



## V1.0.0 P7：4 倍速以上的降噪（Gemini v100 r5：爆爆羊爆炸、史萊姆分裂、小石魔拍地不能省）
const FAST_SPEED := 4.0
const FAST_SKIP := ["pages", "bonesup", "woodwave", "axearc", "healring", "scorch", "inkring", "dust", "puff", "chips", "bones", "coins", "ripple", "note", "hex", "trip", "soulrise"]

func _add_fx(d: Dictionary) -> void:
	for ck in ["c", "tc"]:   # 1.6.0 B08（P3.4）：特效的顏色參數一進來就壓到亮度上限（畫的地方另有字面色的上限）
		if d.get(ck) is Color:
			d[ck] = fx_lum_cap(d[ck])
	if bool(Save.s("reduce_fx")) and d["kind"] in ["slimehop", "pages", "bonesup", "woodwave", "axearc", "healring", "scorch", "inkring", "dust", "puff", "shard", "chips", "tell", "bones", "coins", "ripple", "note", "hex", "aim", "trip", "spore", "wool", "soulrise"]:
		return   # 第七輪 K3：簡化特效少掉粒子與裝飾，保留攻擊本身與嘲諷
	if speed >= FAST_SPEED and d["kind"] in FAST_SKIP:
		return   # V1.0.0 P7：高倍速只略過裝飾碎屑；預警圈（tell）、爆炸、分裂、拍地這類決定戰局的照畫
	var pr: int = FX_PRIO.get(d["kind"], 1)
	# 同一處同種特效去重（Antigravity S2 #2）：24px 內、0.15 秒內最多 2 個
	var dp = d.get("p", d.get("b", null))
	if dp != null and not d.has("src"):   # 帶攻擊者的（砍擊、箭）不去重：每一次攻擊都要有演出
		var same := 0
		for f0 in fx:
			if f0["kind"] == d["kind"] and f0["t"] < 0.15:
				var fp = f0.get("p", f0.get("b", null))
				if fp != null and fp.distance_to(dp) < 24.0:
					same += 1
		if same >= 2:
			fx_deduped += 1
			return
	var cls: String = FX_CLASS.get(d["kind"], "")
	if cls != "":
		var same_cls: Array = []
		for i0 in fx.size():
			if FX_CLASS.get(fx[i0]["kind"], "") == cls:
				same_cls.append(i0)
		if same_cls.size() >= int(FX_CLASS_CAP[cls]):
			fx.remove_at(same_cls[0])   # 1.4.0 §6.1：同類超額，丟最舊的那個（固定順序、可重現）；放在去重之後＝新的確定會收才淘汰（Codex cat05 #2）
			fx_dropped += 1
	# V1.3 C：混戰降噪（先過去重再淘汰，Codex v130-impl2）。頭頂符號（鼓舞音符、嘲諷驚嘆號）同時最多幾個，多的不畫（舊的先留著，讀得到）
	if OVERHEAD_CAP.has(d["kind"]):
		var on := 0
		var old_i := -1
		for i1 in fx.size():
			if fx[i1]["kind"] == d["kind"]:
				on += 1
				if old_i < 0 or fx[i1]["t"] > fx[old_i]["t"]:
					old_i = i1
		if on >= int(OVERHEAD_CAP[d["kind"]]) and old_i >= 0:
			fx.remove_at(old_i)   # 滿了先砍最舊的，新的事件提示才看得到（Codex v130-impl1）
			fx_dropped += 1
	var n := 0
	for f in fx:
		if not f["kind"] in FX_CAP_EXEMPT:
			n += 1
	if n >= FX_CAP and d["kind"] != "stain":   # 跳字照舊走這條；茶漬範圍提示不被擋
		var victim := -1
		for k in fx.size():
			var f2: Dictionary = fx[k]
			if f2["kind"] in FX_CAP_EXEMPT:
				continue
			var p2: int = FX_PRIO.get(f2["kind"], 1)
			if p2 < 2 and (victim < 0 or p2 < FX_PRIO.get(fx[victim]["kind"], 1) or (p2 == FX_PRIO.get(fx[victim]["kind"], 1) and f2["t"] > fx[victim]["t"])):
				victim = k
		if victim >= 0 and FX_PRIO.get(fx[victim]["kind"], 1) <= pr:
			fx.remove_at(victim)
			fx_dropped += 1
		elif pr < 2:
			fx_dropped += 1
			return
		else:
			# 全部都是關鍵特效：取代最舊的那個（硬上限，Codex S1 #5）
			var oldest := -1
			for k3 in fx.size():
				if not fx[k3]["kind"] in FX_CAP_EXEMPT and (oldest < 0 or fx[k3]["t"] > fx[oldest]["t"]):
					oldest = k3
			fx.remove_at(oldest)
			fx_dropped += 1
	fx.append(d)



## V1.2 C6：對話泡。r＝文字外框；尖角朝下指向角色。透明度跟著字淡出。
## 吊牌外形：左邊兩角斜切（切 min(5, 高×0.3)）、右緣每 4px 一個 1px 小鋸齒；全部在 r 之內
static func tag_poly(r: Rect2) -> PackedVector2Array:
	var c := minf(5.0, r.size.y * 0.3)
	var pts := PackedVector2Array([Vector2(r.position.x + c, r.position.y), Vector2(r.end.x, r.position.y)])
	var y := r.position.y + 4.0
	var k := 0
	while y < r.end.y - 2.0:
		pts.append(Vector2(r.end.x - (1.0 if k % 2 == 0 else 0.0), y))
		y += 4.0
		k += 1
	pts.append(Vector2(r.end.x, r.end.y))
	pts.append(Vector2(r.position.x + c, r.end.y))
	pts.append(Vector2(r.position.x, r.end.y - c))
	pts.append(Vector2(r.position.x, r.position.y + c))
	return pts

func _bubble(r: Rect2, a: float) -> void:
	var rr := r.grow_individual(4, 1, 4, 2)
	# 1.2.0 第 4 大類 A11：跳字泡改成小紙條（米白紙底＋墨邊），字用墨色（保留色相）；簡化介面維持深色泡
	var paper := not bool(Save.s("plain_ui"))
	var mid := rr.position.x + rr.size.x * 0.5
	if paper:
		# 1.4.0 §3.1：牛皮紙短標籤（方角、底緣深一階）＋細短引線指向觸發點（取代白底圓角泡＋三角尾）
		# 1.5.0 §4：手裁吊牌——左邊兩角斜切、右緣細鋸齒（穿線孔試過：貼在第一個字前面像標點，拿掉）（原本直角素色框像介面；Hydrogen v150 cat07）。外框範圍不變（字的幾何不動）
		var kraft := Color(PAL.KRAFT, 0.95 * a)
		var tag := tag_poly(rr)
		draw_colored_polygon(tag * Transform2D(0.0, Vector2(-1, -2)), Color(DIM_INK, 0.35 * a))
		draw_colored_polygon(tag, kraft)
		draw_rect(Rect2(rr.position.x + 5.0, rr.end.y - 2.0, rr.size.x - 7.0, 2.0), Color(PAL.KRAFT_D, 0.8 * a))
		draw_polyline(tag + PackedVector2Array([tag[0]]), Color(PAL.KRAFT_D, 0.9 * a), 1.0, true)
		draw_line(Vector2(mid, rr.end.y), Vector2(mid, rr.end.y + 9.0), Color(PAL.KRAFT_D, 0.95 * a), 2.0, true)   # 引線加粗（Antigravity cat05 #3）
		draw_circle(Vector2(mid, rr.end.y + 9.5), 1.6, Color(PAL.KRAFT_D, 0.85 * a), true, -1.0, true)
		return
	var fill := Color(0.10, 0.07, 0.05, 0.82 * a)
	var edge := Color(0.95, 0.86, 0.66, 0.55 * a)
	var tail := PackedVector2Array([Vector2(mid - 5, rr.end.y - 1), Vector2(mid + 5, rr.end.y - 1), Vector2(mid - 1, rr.end.y + 7)])
	_box(rr, fill, edge, minf(10.0, rr.size.y * 0.5), 1.5)
	draw_colored_polygon(tail, fill)
	draw_polyline(PackedVector2Array([tail[0], tail[2], tail[1]]), edge, 1.5, true)

func _fx_text(p: Vector2, s: String, c: Color, dur: float, size: int, screen := false) -> void:
	# V1.3（Codex 第 3 輪）：跳字原本直接加、不受上限管。戰場上的跳字最多 TEXT_CAP 個，滿了丟最舊的那個
	if not screen:
		var n := 0
		var oldest := -1
		for i in fx.size():
			if fx[i]["kind"] == "text" and not fx[i].get("screen", false):
				n += 1
				var ti: int = fx[i].get("tier", 1)
				if oldest < 0 or ti < int(fx[oldest].get("tier", 1)) or (ti == int(fx[oldest].get("tier", 1)) and fx[i]["t"] > fx[oldest]["t"]):
					oldest = i   # 先丟不重要的（tier 低），同級丟最舊的
		if n >= FX_TEXT_CAP and oldest >= 0:
			fx.remove_at(oldest)
			fx_dropped += 1
	fx.append({"kind": "text", "p": p, "s": s, "c": c, "t": 0.0, "dur": dur, "size": size, "screen": screen})



# V1.2 F2：亮的特效底下墊一層柔光（放射漸層貼圖，執行時生成；不用全域 Glow）
const GLOW := {"boom": [Color(1.0, 0.55, 0.2), 70.0], "meteor": [Color(1.0, 0.5, 0.2), 90.0], "healarc": [Color(0.45, 1.0, 0.55), 40.0],
	"soulrise": [Color(0.7, 0.85, 1.0), 44.0], "timebell": [Color(1.0, 0.85, 0.4), 80.0], "sigil": [Color(1.0, 0.9, 0.55), 60.0]}
var _glow_tex: GradientTexture2D = null

func _draw_glow(f: Dictionary, k: float) -> void:
	if _glow_tex == null:
		var gr := Gradient.new()
		gr.set_color(0, Color(1, 1, 1, 1))
		gr.set_color(1, Color(1, 1, 1, 0))
		gr.add_point(0.45, Color(1, 1, 1, 0.35))
		_glow_tex = GradientTexture2D.new()
		_glow_tex.gradient = gr
		_glow_tex.fill = GradientTexture2D.FILL_RADIAL
		_glow_tex.fill_from = Vector2(0.5, 0.5)
		_glow_tex.fill_to = Vector2(1.0, 0.5)
		_glow_tex.width = 64
		_glow_tex.height = 64
	var g: Array = GLOW[f["kind"]]
	var gp = f.get("p", f.get("b", null))
	if gp == null:
		return
	var r := glow_radius(f, k)
	draw_texture_rect(_glow_tex, Rect2(gp - Vector2(r, r * 0.8), Vector2(r * 2.0, r * 1.6)), false, Color(fx_col(g[0]), 0.32 * (1.0 - k)))

func _draw_fx(f: Dictionary) -> void:
	var k: float = f["t"] / f["dur"]
	if GLOW.has(f["kind"]) and not bool(Save.s("plain_ui")) and not bool(Save.s("reduce_fx")):
		_draw_glow(f, k)
	match f["kind"]:
		"cmd_flash":
			draw_rect(Rect2(0, 0, 1280, 800), Color(f["c"], 0.28 * (1.0 - k)))
		"meteor":
			var mp: Vector2 = f["p"]
			var mr: float = f["r"]
			if k < 0.3:
				var drop := 1.0 - k / 0.3
				draw_circle(mp - Vector2(-120, 320) * drop, 15.0, Color("#ff8a3c"))
				draw_circle(mp - Vector2(-120, 320) * drop, 8.0, fx_col(Color(0.855, 0.805, 0.59)))
				draw_arc(mp, mr, 0, TAU, 40, Color(1, 0.5, 0.2, 0.7), 2.0, true)
			else:
				var bk := (k - 0.3) / 0.7
				draw_circle(mp, mr * (0.4 + bk * 0.6), Color(1, 0.5, 0.15, 0.45 * (1.0 - bk)))
				draw_arc(mp, mr * (0.4 + bk * 0.6), 0, TAU, 40, Color(0.889, 0.8, 0.534, 1.0 - bk), 4.0, true)
		"spark":
			# V1.5：法術命中的碎光（8 道放射短線＋中心光點）
			var sk: float = f["t"] / f["dur"]
			var sc: Color = fx_lum_cap(f.get("c", Color.WHITE))
			var sp0: Vector2 = f["p"]
			for i in 8:
				var dv := Vector2.from_angle(i * TAU / 8.0 + 0.3)
				draw_line(sp0 + dv * (4.0 + sk * 10.0), sp0 + dv * (8.0 + sk * 16.0), Color(sc, 1.0 - sk), 2.4, true)
			draw_circle(sp0, 6.0 * (1.0 - sk), Color(fx_lum_cap(sc.lightened(0.5)), 0.9 * (1.0 - sk)), true, -1.0, true)
		"arrow":
			var a: Vector2 = f["a"]
			var b: Vector2 = f["b"]
			var h := minf(60.0, a.distance_to(b) * 0.18)
			var fly: float = f.get("fly", f["dur"])
			if f["t"] >= fly:
				# V1.3 P1：命中後箭釘在目標上抖 0.18 秒（像箭插進木頭），再消失
				var q: float = (f["t"] - fly) / maxf(0.01, f["dur"] - fly)
				var d0 := (b - a).normalized() if b != a else Vector2.RIGHT
				var wob := sin(q * 38.0) * 0.32 * (1.0 - q)
				var dv := d0.rotated(wob)
				var tl := b - dv * 13.0
				draw_line(tl, b, Color(Art.OUT, 1.0 - q), 4.0, true)
				draw_line(tl, b, Color(Color("#d97706"), 1.0 - q), 2.2, true)
				var fc0: Color = fx_lum_cap(f.get("tc", Color.WHITE))
				draw_colored_polygon(PackedVector2Array([tl, tl - dv * 5.0 + dv.orthogonal() * 4.0, tl + dv * 3.0]), Color(fc0, 1.0 - q))
				draw_colored_polygon(PackedVector2Array([tl, tl - dv * 5.0 - dv.orthogonal() * 4.0, tl + dv * 3.0]), Color(fc0, 1.0 - q))
				return
			k = f["t"] / fly
			var p := a.lerp(b, k) + Vector2(0, -sin(k * PI) * h)
			var k2 := maxf(0.0, k - 0.06)
			var p2 := a.lerp(b, k2) + Vector2(0, -sin(k2 * PI) * h)
			var dirv := (p - p2).normalized() if p != p2 else Vector2.RIGHT
			var tail := p - dirv * 16.0
			for j in 6:
				var kk := maxf(0.0, k - 0.03 * (j + 1))
				var pt := a.lerp(b, kk) + Vector2(0, -sin(kk * PI) * h)
				draw_circle(pt, 1.6, Color(0.8, 0.8, 0.8, 0.35 * (1.0 - j / 6.0)), true, -1.0, true)
			draw_line(tail, p, Art.OUT, 4.0, true)
			draw_line(tail, p, Color("#d97706"), 2.2, true)
			var nrm := dirv.orthogonal()
			draw_colored_polygon(PackedVector2Array([p + dirv * 5.0, p + nrm * 3.0, p - nrm * 3.0]), Color(0.794, 0.8, 0.814))
			var fc: Color = fx_lum_cap(f.get("tc", Color.WHITE))
			draw_colored_polygon(PackedVector2Array([tail, tail - dirv * 5.0 + nrm * 4.0, tail + dirv * 3.0]), fc)
			draw_colored_polygon(PackedVector2Array([tail, tail - dirv * 5.0 - nrm * 4.0, tail + dirv * 3.0]), fc)
		"slash":
			var c: Vector2 = f["p"] + Vector2(f["dir"] * 16, -24)
			var start := -1.3 if f["dir"] > 0 else PI - 1.1
			draw_arc(c, 16, start, start + 2.4 * k, 12, Color(0.8, 0.8, 0.8, 1 - k), 3.5, true)
		"step":
			var bigs: float = 1.8 if f.get("big", false) else 1.0
			for i in 4:
				var angs := i * TAU / 4 + 0.6
				draw_circle(f["p"] + Vector2(cos(angs) * (6 + k * 14) * bigs, sin(angs) * 3 + 1), 2.6 * bigs * (1 - k), Color(0.85, 0.75, 0.55, 0.5 * (1 - k)), true, -1.0, true)
		"dust":
			for i in 7:
				var ang := i * TAU / 7
				draw_circle(f["p"] + Vector2(cos(ang) * (10 + k * 30), sin(ang) * 6 + 2), 6 * (1 - k), Color(0.85, 0.75, 0.55, 0.6 * (1 - k)), true, -1.0, true)
		"flash":
			var c2: Color = f["c"]
			var p0: Vector2 = f["p"]
			var fa2 := FX_FACE_ALPHA if fx_on_face(p0, 14.0 * (1 + k)) else 1.0   # 1.6.0 B08：蓋在頭胸上就壓淡
			c2 = fx_col(c2)
			# 雙層描邊（第三輪 V4）：深色底 4px＋亮芯
			for pair in [[Vector2(-14, -14), Vector2(14, 14)], [Vector2(-14, 14), Vector2(14, -14)]]:
				draw_line(p0 + pair[0] * (1 + k), p0 + pair[1] * (1 + k), Color(Art.OUT, 0.8 * (1 - k) * fa2), 8, true)
				draw_line(p0 + pair[0] * (1 + k), p0 + pair[1] * (1 + k), Color(c2, (1 - k) * fa2), 4, true)
				draw_line(p0 + pair[0] * (1 + k), p0 + pair[1] * (1 + k), Color(fx_col(Color(0.8, 0.8, 0.8)), 0.7 * (1 - k) * fa2), 1.5, true)
		"ripple":
			var c3: Color = f["c"]
			draw_arc(f["p"], 6 + k * 18, -1.2, 1.2, 12, Color(c3, 1 - k), 3, true)
		"bones":
			# V1.1 A7：骷髏散成幾根骨頭彈開、往下掉
			for i in 5:
				var an := -PI * 0.5 + (i - 2) * 0.55
				var v := Vector2(cos(an), sin(an)) * k * 30.0 + Vector2(0, k * k * 34.0)
				var c0: Vector2 = f["p"] + v
				var rot := k * 9.0 + i
				var d0 := Vector2(cos(rot), sin(rot)) * 6.0
				draw_line(c0 - d0, c0 + d0, Color(Art.OUT, 1.0 - k), 5.0, true)
				draw_line(c0 - d0, c0 + d0, Color(0.819, 0.801, 0.732, 1.0 - k), 3.0, true)
		"coins":
			# V1.1 A7：寶箱怪倒下吐出幾枚金幣
			for i in 6:
				var an2 := -PI * 0.5 + (i - 2.5) * 0.45
				var v2 := Vector2(cos(an2), sin(an2)) * k * 34.0 + Vector2(0, k * k * 40.0)
				var c1: Vector2 = f["p"] + v2
				draw_circle(c1, 4.5, Color(Art.OUT, 1.0 - k), true, -1.0, true)
				draw_circle(c1, 3.2, Color(0.975, 0.799, 0.292, 1.0 - k), true, -1.0, true)
		"badge":
			var bc: Color = f["c"]
			var bs := 7.0 * (1.0 + 0.4 * sin(minf(k * 2.0, 1.0) * PI))
			var bp: Vector2 = f["p"] - Vector2(0, k * 8.0)
			var dm := PackedVector2Array([bp + Vector2(0, -bs), bp + Vector2(bs * 0.8, 0), bp + Vector2(0, bs), bp + Vector2(-bs * 0.8, 0)])
			draw_colored_polygon(dm, Color(bc, 1.0 - k))
			draw_polyline(dm + PackedVector2Array([dm[0]]), Color(Art.OUT, 1.0 - k), 2.0, true)
		"sigil":
			var sc: Color = f["c"]
			var a0 := (1.0 - k) * (k * 6.0 if k < 0.15 else 1.0)
			for q in f["pts"]:
				draw_set_transform_matrix(_cam * Transform2D(0, Vector2(1, 0.5), 0, q))
				var rr := 15.0 + k * 6.0
				match int(f["sk"]):
					0:
						var hx := PackedVector2Array()
						for j in 7:
							hx.append(Vector2(cos(j * TAU / 6.0), sin(j * TAU / 6.0)) * rr)
						draw_polyline(hx, Color(sc, 0.8 * a0), 2.5, true)
					1:
						for j in 3:
							var an := j * TAU / 3.0 + k * 2.0
							draw_arc(Vector2.ZERO, rr, an, an + 1.4, 8, Color(sc, 0.85 * a0), 3.0, true)
					2:
						draw_arc(Vector2.ZERO, rr, 0, TAU, 20, Color(sc, 0.6 * a0), 2.0, true)
						draw_line(Vector2(-6, 0), Vector2(6, 0), Color(sc, 0.9 * a0), 3.0, true)
						draw_line(Vector2(0, -6), Vector2(0, 6), Color(sc, 0.9 * a0), 3.0, true)
					_:
						for j in 6:
							var an2 := j * TAU / 6.0
							draw_line(Vector2(cos(an2), sin(an2)) * rr * 0.5, Vector2(cos(an2), sin(an2)) * rr * 1.1, Color(sc, 0.9 * a0), 2.5, true)
			draw_set_transform_matrix(_cam)
		"chips":
			# V1.1 A2：受擊材質碎屑（盾火花、石屑、史萊姆滴），4 顆往外彈、往下掉
			var cc: Color = f["c"]
			for i in 4:
				var ang := -PI * 0.5 + (i - 1.5) * 0.7 + float(int(f["p"].x) % 7) * 0.05
				var v := Vector2(cos(ang), sin(ang)) * k * 22.0 + Vector2(0, k * k * 18.0)
				var c0: Vector2 = f["p"] + v
				if f.get("spark", false):
					draw_line(c0, c0 - v.normalized() * 6.0 * (1.0 - k), Color(cc, 1.0 - k), 2.0, true)
				elif f.get("drop", false):
					draw_circle(c0, 3.2 * (1.0 - k * 0.5), Color(cc, (1.0 - k) * cc.a), true, -1.0, true)
				else:
					# V1.3 P1：碎屑不再是正方形：不規則四邊形，邊飛邊翻滾
					var rot := k * (6.0 + i * 2.0) + i
					var sz0 := 2.4 + float(i % 2) * 0.9
					var q := PackedVector2Array()
					for j in 4:
						var aj := rot + j * TAU / 4.0 + (0.35 if j % 2 == 0 else -0.2)
						q.append(c0 + Vector2(cos(aj), sin(aj)) * sz0 * (1.15 if j == i % 4 else 0.85))
					draw_colored_polygon(q, Color(cc, 1.0 - k))
		"shard":
			# 破盾裂片：盾面的灰藍碎片往外飛、旋轉、往下掉
			for i in 6:
				var ang := i * 1.13 + 0.4
				var v := Vector2(cos(ang), sin(ang) * 0.7) * k * 34
				var c0: Vector2 = f["p"] + v + Vector2(0, k * k * 24)
				var r0 := 6.0 * (1.0 - k * 0.4)
				var rot := k * 7.0 + i
				var pts := PackedVector2Array()
				for j in 3:
					pts.append(c0 + Vector2(cos(rot + j * 2.1), sin(rot + j * 2.1)) * r0)
				draw_colored_polygon(pts, Color(0.772, 0.805, 0.83, 1 - k))
				draw_polyline(pts + PackedVector2Array([pts[0]]), Color(Art.OUT, 1 - k), 2.0, true)
		"aim":
			# 警覺：金色瞄準線先拉出來，再淡掉
			var a2: Vector2 = f["a"]
			var b2: Vector2 = f["b"]
			var e2 := a2.lerp(b2, minf(1.0, k * 2.5))
			draw_dashed_line(a2, e2, Color(0.958, 0.805, 0.287, 0.6 * (1 - k)), 1.6, 6.0, true)
			draw_arc(b2, 9 - k * 3, 0, TAU, 16, Color(0.958, 0.805, 0.287, 1 - k), 2.0, true)
		"hide":
			# 皮甲：琥珀色弧光擋在中箭的那一側
			var d3: float = f["dir"]
			var c4: Vector2 = f["p"]
			var st := -1.1 if d3 > 0 else PI - 1.1
			draw_arc(c4, 15 + k * 6, st, st + 2.2, 14, Color(1, 0.66, 0.2, 0.95 * (1 - k)), 4.0 - k * 2, true)
		"trip":
			# 絆馬：一條白繩在腳邊繃斷，兩段往外彈
			var c5: Vector2 = f["p"]
			var gap := 2.0 + k * 14.0
			var drop := k * k * 8.0
			draw_line(c5 + Vector2(-24, 0), c5 + Vector2(-gap, drop), Art.OUT, 4.6, true)
			draw_line(c5 + Vector2(gap, drop), c5 + Vector2(24, 0), Art.OUT, 4.6, true)
			draw_line(c5 + Vector2(-24, 0), c5 + Vector2(-gap, drop), Color(0.8, 0.8, 0.8, 1 - k), 3.0, true)
			draw_line(c5 + Vector2(gap, drop), c5 + Vector2(24, 0), Color(0.8, 0.8, 0.8, 1 - k), 3.0, true)
			if k < 0.25:
				draw_circle(c5, 5.0 * (1.0 - k * 4.0), Color(0.8, 0.8, 0.8, 0.9), true, -1.0, true)   # 繃斷的閃白
		"spore":
			# V1.0.0 角色：毒改濁紫（綠色留給補血），兩顆錯開的斑點
			draw_circle(f["p"] + Vector2(-3.0, -k * 14.0), 3.0 + k * 3.0, Color(0.62, 0.42, 0.78, 0.75 * (1.0 - k)), true, -1.0, true)
			draw_circle(f["p"] + Vector2(4.0, -k * 10.0 - 4.0), 2.0 + k * 2.0, Color(0.5, 0.32, 0.62, 0.6 * (1.0 - k)), true, -1.0, true)
		"windtrail":
			# 1.4.0 §6.2 騎兵衝鋒：身後地上三道刷毛風痕（往後拖、淡出）
			var wd: float = f["dir"]
			for k4 in 3:
				var y4: float = -2.0 + (k4 - 1) * 6.0
				var a4 := (1.0 - k) * (0.55 - k4 * 0.1)
				var pts4 := PackedVector2Array()
				for s4 in 6:
					var xx := -wd * (10.0 + s4 * 9.0 + k * 20.0)
					pts4.append(f["p"] + Vector2(xx, y4 + sin(s4 * 1.3 + k4) * 1.5))
				draw_polyline(pts4, Color(0.865, 0.799, 0.62, a4), 2.0 - k4 * 0.4, true)
		"leaves":
			# 1.4.0 §6.2 醫者治療：三片草葉微粒旋升（綠色只給治療語意）
			for k5 in 3:
				var ang5: float = k * TAU * 0.8 + k5 * TAU / 3.0
				var c5: Vector2 = f["p"] + Vector2(cos(ang5) * 10.0, -k * 26.0 - k5 * 4.0)
				var lv := Vector2(cos(ang5 * 1.7), sin(ang5 * 1.7)) * 3.5
				draw_line(c5 - lv, c5 + lv, Color(0.45, 0.82, 0.4, 0.85 * (1.0 - k)), 2.4, true)
		"cmdseal":
			# 1.4.0 §6.3 軍令＝桌面蓋下半透明朱印：一個方印從大縮到定位、留一圈波紋淡出
			var sc6 := 1.0 + 0.6 * maxf(0.0, 1.0 - k / 0.2)
			var r6 := 34.0 * sc6
			var a6 := 0.55 * (1.0 - maxf(0.0, (k - 0.5) / 0.5))
			var cc6: Color = f["c"]
			draw_rect(Rect2(f["p"] - Vector2(r6, r6), Vector2(r6, r6) * 2.0), Color(cc6, a6 * 0.35))
			draw_rect(Rect2(f["p"] - Vector2(r6, r6), Vector2(r6, r6) * 2.0), Color(cc6, a6), false, 3.0)
			draw_rect(Rect2(f["p"] - Vector2(r6, r6) * 0.62, Vector2(r6, r6) * 1.24), Color(cc6, a6 * 0.8), false, 1.5)
			if k > 0.2:
				var rk := (k - 0.2) / 0.8
				draw_arc(f["p"], 40.0 + rk * 60.0, 0, TAU, 48, Color(cc6, 0.3 * (1.0 - rk)), 2.0, true)
		"stain":
			# 1.3.0 §7.1 範圍指示：墨漬（爆炸）／茶漬（踩地）。前 0.15 秒擴散到真實半徑，最後 1.5 秒收縮到 6 成並淡出（被木盤吸乾）
			var st0: float = f["t"]
			var grow := clampf(st0 / 0.15, 0.0, 1.0)
			var dry := clampf((st0 - (float(f["dur"]) - 1.5)) / 1.5, 0.0, 1.0)
			var rr0: float = float(f["r"]) * (0.55 + 0.45 * grow) * (1.0 - 0.4 * dry)
			var sc0: Color = PAL.TEA if bool(f["tea"]) else PAL.DIM_INK
			var pts0 := PackedVector2Array()
			var sd0 := int(f["seed"])
			for i in 18:
				var ang := i * TAU / 18.0
				var wob := 0.86 + 0.14 * float(((sd0 * 7 + i * 13) % 11)) / 10.0
				pts0.append(Vector2(cos(ang), sin(ang) * 0.5) * rr0 * wob)
			draw_set_transform_matrix(_cam * Transform2D(0, Vector2.ONE, 0, f["p"]))
			draw_colored_polygon(pts0, Color(sc0, 0.11 * (1.0 - dry)))   # 1.4.0：茶漬不再被淘汰、常留在兵腳下 → 底色減半（範圍看邊線），不把棋子周圍壓暗（收尾量測：輪廓對比警告 5.9%→10%）
			draw_polyline(pts0 + PackedVector2Array([pts0[0]]), Color(sc0, 0.35 * (1.0 - dry)), 1.5, true)   # 1.5.0：茶漬改畫在兵之下（GROUND_FX），濃度照 1.4.0
			draw_set_transform_matrix(_cam)
		"tag":
			# 1.3.0 §7.1 狀態竹籤：0～0.3 從底座彈到頭頂並自轉半圈（橫向縮放＝翻面，翻到背面是空白竹皮）、0.3～0.6 停、0.6～1 往盤外掉落淡出
			var tq := float(f["t"]) / float(f["dur"])
			var up := clampf(tq / 0.3, 0.0, 1.0)
			var fall := clampf((tq - 0.6) / 0.4, 0.0, 1.0)
			var tp0: Vector2 = f["p"] + Vector2(0, -70.0 * HK * (1.0 - (1.0 - up) * (1.0 - up))) + Vector2(float(f["dir"]) * 30.0 * fall, 40.0 * fall * fall)
			var flip := cos(up * PI)
			var tsz := tz("S")   # Hydrogen cat06 #5：竹籤加大
			var tw0 := _width(str(f["s"]), tsz, true) + 20.0
			var th0 := float(tsz) * 1.5
			var a0 := 1.0 - fall
			draw_set_transform_matrix(_cam * Transform2D(fall * float(f["dir"]) * 0.6, Vector2(absf(flip), 1.0), 0, tp0))
			draw_rect(Rect2(Vector2(-tw0 / 2, -th0 / 2), Vector2(tw0, th0)), Color(PAL.BAMBOO, a0))
			draw_rect(Rect2(Vector2(-tw0 / 2, -th0 / 2), Vector2(tw0, th0)), Color(PAL.BAMBOO_D, a0), false, 1.5)
			draw_line(Vector2(-tw0 / 2 + 3, -th0 / 2 + 3), Vector2(tw0 / 2 - 3, -th0 / 2 + 3), Color(fx_lum_cap(PAL.BAMBOO.lightened(0.3)), a0 * 0.8), 1.0)
			draw_set_transform_matrix(_cam)
			if flip < -0.85:   # 翻回正面才寫字（字在盤面座標畫，不跟著縮放；版面檢查量得到真實位置）
				_text(tp0 + Vector2(0, -th0 / 2 + 1), str(f["s"]), tsz, Color(PAL.INK, a0), true, true)
		"scorch":
			# V1.0.0 角色：投彈兵火罐落點焦痕（0.25 秒、扁橢圓、貼地），讓投彈兵和弓手、醫者在混戰裡分得開
			draw_set_transform_matrix(_cam * Transform2D(0, Vector2(1, 0.45), 0, f["p"]))
			draw_circle(Vector2.ZERO, 16.0, Color(0.16, 0.1, 0.06, 0.35 * (1.0 - k)), true, -1.0, true)
			draw_set_transform_matrix(_cam)
		"pin":
			draw_line(f["a"], f["b"], Color(0.62, 0.12, 0.12, 0.85 * (1.0 - k)), 3.0, true)   # 1.1.0 A7：分傷＝受傷，暗紅（原本粉紫，和毒的紫撞）
		"pages":
			# 1.1.0 A7：骷髏法師翻書：兩頁米白紙以書脊為軸翻過去（≤0.3 格）
			for pg in 2:
				var kp := clampf(k * 1.6 - pg * 0.5, 0.0, 1.0)
				var w := 9.0 * cos(kp * PI)
				var q := PackedVector2Array([f["p"], f["p"] + Vector2(w, -2.0 - 3.0 * sin(kp * PI)), f["p"] + Vector2(w, 9.0 - 3.0 * sin(kp * PI)), f["p"] + Vector2(0, 9.0)])
				draw_colored_polygon(q, Color(0.835, 0.8, 0.696, 0.9 * (1.0 - k * 0.6)))
		"bonesup":
			# 1.1.0 A7：骷髏拼裝：5 根骨頭從外圈收進來（0.15 秒），收完就是本體
			for bi in 5:
				var ab := bi * TAU / 5.0 + 0.4
				var rr := 18.0 * (1.0 - k)
				var c0: Vector2 = f["p"] + Vector2(cos(ab), sin(ab) * 0.8) * rr
				var d0 := Vector2(cos(ab + 1.2), sin(ab + 1.2)) * 4.0
				draw_line(c0 - d0, c0 + d0, Color(0.826, 0.799, 0.728, 1.0 - k * 0.5), 2.2, true)
		"slimehop":
			# 1.1.0 A7：小史萊姆從母體彈出半圈：沿半圓弧的殘影＋落地壓扁回彈（弧在 0.3 格內）
			var dxh: float = f.get("dir", 1.0)
			var start: Vector2 = f["p"] + Vector2(-14.0 * dxh, 0)
			if k < 0.6:
				var kh := k / 0.6
				var pos := start.lerp(f["p"], kh) + Vector2(0, -14.0 * sin(kh * PI))
				draw_circle(pos + Vector2(0, -6), 4.5, Color(0.423, 0.941, 0.517, 0.7), true, -1.0, true)
			else:
				var ks := (k - 0.6) / 0.4
				var sq := 1.0 + 0.5 * sin(ks * PI)
				draw_set_transform_matrix(_cam * Transform2D(0, Vector2(sq, 1.0 / sq), 0, f["p"] + Vector2(0, -3)))
				draw_circle(Vector2.ZERO, 5.0, Color(0.423, 0.941, 0.517, 0.6 * (1.0 - ks)), true, -1.0, true)
				draw_set_transform_matrix(_cam)
		"woodwave":
			# 1.1.0 A7：鼓手敲擊，腳下兩圈淡木色同心波（貼地，外圈 ≤0.3 格）
			draw_set_transform_matrix(_cam * Transform2D(0, Vector2(1, 0.45), 0, f["p"]))
			for w in 2:
				var kw := clampf(k * 1.3 - w * 0.3, 0.0, 1.0)
				if kw > 0.0:
					draw_arc(Vector2.ZERO, 8.0 + kw * 14.0, 0.0, TAU, 24, Color(0.85, 0.72, 0.5, 0.55 * (1.0 - kw)), 2.0, true)
			draw_set_transform_matrix(_cam)
		"axearc":
			# 1.1.0 A7：狂戰士破陣揮斧，赭橙短弧（避開受傷紅、毒紫）
			var dx: float = f.get("dir", 1.0)
			var a0 := -PI * 0.5 if dx >= 0.0 else PI * 0.5
			draw_arc(f["p"], 16.0, a0 - 0.2 * dx, a0 + (1.6 * k + 0.2) * dx, 10, Color(0.85, 0.5, 0.18, 0.9 * (1.0 - k)), 3.0, true)
		"healring":
			# 1.1.0 A7：醫者補血，被補的友軍腳下淡綠扁環（貼地，≤0.3 格）
			draw_set_transform_matrix(_cam * Transform2D(0, Vector2(1, 0.45), 0, f["p"]))
			draw_arc(Vector2.ZERO, 10.0 + k * 9.0, 0.0, TAU, 24, Color(0.45, 0.9, 0.5, 0.7 * (1.0 - k)), 2.5, true)
			draw_set_transform_matrix(_cam)
		"wool":
			for i8 in 9:
				var an8 := i8 * TAU / 9.0
				draw_circle(f["p"] + Vector2(cos(an8), sin(an8) * 0.7) * (8.0 + k * 34.0) + Vector2(0, k * k * 16.0), 5.0 * (1.0 - k), Color(0.8, 0.8, 0.8, 0.9 * (1.0 - k)), true, -1.0, true)
		"chomp":
			var gap8 := 12.0 * (1.0 - minf(1.0, k * 3.0))
			for s8 in [-1.0, 1.0]:
				var base8: Vector2 = f["p"] + Vector2(0, s8 * gap8)
				var tri := PackedVector2Array()
				for i9 in 4:
					tri.append(base8 + Vector2(-15.0 + i9 * 10.0, 0))
					tri.append(base8 + Vector2(-10.0 + i9 * 10.0, s8 * -8.0))
				tri.append(base8 + Vector2(25.0, 0))
				draw_polyline(tri, Color(0.8, 0.8, 0.8, 1.0 - k), 3.0, true)
		"timebell":
			var bellr := 18.0 + k * float(F8.SPRITE_R) * CS / 1000.0
			draw_arc(f["p"], bellr, 0, TAU, 48, Color(Art.OUT, 0.5 * (1.0 - k)), 7.0, true)
			draw_arc(f["p"], bellr, 0, TAU, 48, Color(0.911, 0.802, 0.456, 0.9 * (1.0 - k)), 4.0, true)
			draw_circle(f["p"], bellr, Color(0.911, 0.802, 0.456, 0.08 * (1.0 - k)), true, -1.0, true)
		"soulrise":
			for i10 in 5:
				var an10 := i10 * TAU / 5.0 + k * 3.0
				draw_circle(f["p"] + Vector2(cos(an10) * (14.0 - k * 8.0), -k * 38.0 + sin(an10) * 6.0), 5.0 * (1.0 - k), Color(0.72, 0.42, 1.0, 0.55 * (1.0 - k)), true, -1.0, true)
		"swirl":
			var maxr := float(F8.CAT_R) * CS / 1000.0
			for i11 in 3:
				var ph11 := fmod(k * 1.5 + i11 * 0.33, 1.0)
				var r11 := maxr * (1.0 - ph11)
				draw_arc(f["p"], r11, ph11 * 6.0, ph11 * 6.0 + 4.2, 26, Color(0.594, 0.842, 0.99, 0.4 * ph11), 2.4, true)
		"stompring":
			draw_set_transform_matrix(_cam * Transform2D(0, Vector2(1, 0.55), 0, f["p"]))
			var sr := 14.0 + k * float(F8.GOLEM_R) * CS / 1000.0
			# Antigravity 第 2 輪：環蓋在兵上面，不描黑邊、調淡，才不會切過臉
			draw_arc(Vector2.ZERO, sr, 0, TAU, 36, Color(0.856, 0.8, 0.633, 0.5 * (1.0 - k)), 3.5, true)
			draw_set_transform_matrix(_cam)
		"vslash":
			# 背刺：一道粗的紫色斬痕
			var c6: Vector2 = f["p"]
			var dd: float = f["dir"]
			# 第七輪 D7：頭粗尾細、0.2 秒淡出，一眼看出從哪個方向砍
			var a0 := Vector2(-20 * dd, -17)
			var a1 := Vector2(20 * dd, 17)
			var e3 := a0.lerp(a1, minf(1.0, k * 3.0))
			var seg := a0.distance_to(e3)
			if seg > 2.0:
				var nrm := (a1 - a0).normalized().orthogonal()
				var wd := minf(seg * 0.14, 5.0) * (1 - k * 0.4)
				draw_colored_polygon(PackedVector2Array([c6 + a0, c6 + e3 + nrm * (wd + 1.6), c6 + e3 - nrm * (wd + 1.6)]), Color(Art.OUT, 0.6 * (1 - k)))
				draw_colored_polygon(PackedVector2Array([c6 + a0, c6 + e3 + nrm * wd, c6 + e3 - nrm * wd]), Color(0.78, 0.49, 1.0, 1 - k))
				draw_line(c6 + a0, c6 + e3, Color(0.8, 0.8, 0.8, 0.75 * (1 - k)), 1.2, true)
		"taunt":
			# 第七輪 D7：嘲諷改腳底橢圓，只畫下半弧，不擋臉
			var kj := clampf(k * 1.3, 0.0, 1.0)
			draw_set_transform_matrix(_cam * Transform2D(0, Vector2(1, 0.5), 0, f["p"]))
			draw_arc(Vector2.ZERO, 14 + kj * 20, 0.0, PI, 22, Color(Art.OUT, 0.45 * (1 - kj)), 5.0, true)
			draw_arc(Vector2.ZERO, 14 + kj * 20, 0.0, PI, 22, Color(1, 0.62, 0.2, 0.85 * (1 - kj)), 2.5, true)
			draw_set_transform_matrix(_cam)
		"bang":
			# 嘲諷：被吸過去的敵人頭上冒「!」
			var y4 := -sin(minf(1.0, k * 3.0) * PI * 0.5) * 8.0
			_text(f["p"] + Vector2(0, y4 - 10), "!", ts(20), Color(1, 0.65, 0.2, 1.0 - k * k), true, true)
		"hex":
			# 頂住：藍色六角波紋
			for j in 2:
				var kh := clampf(k * 1.3 - j * 0.25, 0.0, 1.0)
				var rr := 10.0 + kh * 22.0
				var hp := PackedVector2Array()
				for q in 7:
					var an := q * TAU / 6.0 + PI / 6.0
					hp.append(f["p"] + Vector2(cos(an), sin(an)) * rr)
				draw_polyline(hp, Color(0.55, 0.8, 1.0, 0.85 * (1 - kh)), 2.5, true)
		"puff":
			# 現形：一團暗紫色煙散開
			for i in 7:
				var ang2 := i * TAU / 7 + 0.3
				draw_circle(f["p"] + Vector2(cos(ang2), sin(ang2) * 0.7) * (6 + k * 22), 7 * (1 - k), Color(0.62, 0.45, 0.85, 0.7 * (1 - k)), true, -1.0, true)
		"boom":
			# 爆炸：橘紅鋸齒爆裂圈＋黑煙圈（和平滑同心圓區分，第四輪 §4.4）
			# 爆炸（Antigravity 實作審查：原本像同心圓標靶）：10 尖角的鋸齒星芒＋黃白核心＋4 團往外散的灰煙
			var bp: Vector2 = f["p"] + Vector2(0, -14)
			var br := boom_radius(k)
			var spikes := PackedVector2Array()
			for i in 20:
				var an := i * TAU / 20.0 + 0.2
				var rr := br * (1.0 if i % 2 == 0 else 0.5)
				spikes.append(bp + Vector2(cos(an) * rr, sin(an) * rr * 0.8))
			var fa := 1.0 - k * k
			draw_colored_polygon(spikes, Color(1.0, 0.42, 0.12, 0.92 * fa))
			for i in 20:
				spikes[i] = bp + (spikes[i] - bp) * 0.55
			draw_colored_polygon(spikes, Color(fx_col(Color(0.938, 0.807, 0.328)), 0.95 * fa))
			for i in 4:
				var pa := i * TAU / 4.0 + 0.6
				var pp := bp + Vector2(cos(pa) * (8.0 + k * 30.0), sin(pa) * (6.0 + k * 20.0) - k * 10.0)
				draw_circle(pp, 6.0 + k * 5.0, Color(0.25, 0.22, 0.27, 0.6 * (1.0 - k)), true, -1.0, true)
		"healarc":
			var ha: Vector2 = f["a"]
			var hb: Vector2 = f["b"]
			var pts := PackedVector2Array()
			for i in 9:
				var q := float(i) / 8.0
				pts.append(ha.lerp(hb, q) + Vector2(0, -sin(q * PI) * 18.0))
			draw_polyline(pts, Color(0.463, 0.925, 0.555, 0.7 * (1.0 - k)), 2.5, true)
			var hc := hb + Vector2(0, -k * 14.0)
			_cross(hc, 5.0, Color(fx_col(Color(0.463, 0.925, 0.555)), (1.0 - k) * (FX_FACE_ALPHA if fx_on_face(hc, 5.0) else 1.0)))
		"note":
			# 音符放大 1.6 倍＋深咖啡描邊（Antigravity：原本跟草地小花一樣大）
			var np: Vector2 = f["p"] + Vector2(sin(k * 6.0) * 4.0, -k * 22.0)
			var na := (1.0 - k) * (FX_FACE_ALPHA if fx_on_face(np, 11.0) else 1.0)   # 1.6.0 B08：蓋在頭胸上就壓淡
			var oc := Color(0.24, 0.14, 0.05, na)
			var nc := Color(fx_col(Color(0.942, 0.81, 0.283)), na)
			draw_circle(np, 6.6, oc, true, -1.0, true)
			draw_line(np + Vector2(5, 1), np + Vector2(5, -16), oc, 4.6, true)
			draw_line(np + Vector2(5, -16), np + Vector2(11, -11), oc, 4.6, true)
			draw_circle(np, 5.0, nc, true, -1.0, true)
			draw_line(np + Vector2(5, 1), np + Vector2(5, -16), nc, 2.4, true)
			draw_line(np + Vector2(5, -16), np + Vector2(11, -11), nc, 2.4, true)
		"text":
			var col: Color = f["c"]
			col.a = 1.0 - k * k
			# V1.6.1 A10：有標記兵時，其他兵的一般跳字淡化（擊倒、致命、剋制等關鍵字 tier ≥2 照舊不透明）
			var tvi = get("tv_ids")
			if tvi is Array and not (tvi as Array).is_empty() and int(f.get("tier", 2)) < 2 and not int(f.get("tid", -1)) in tvi:
				col.a *= 0.4
			if f.get("screen", false):
				if bool(Save.s("text_plate")):
					var tw4 := _width(str(f["s"]), ts(f["size"]), true) + 28.0
					draw_rect(Rect2(f["p"] + Vector2(-tw4 / 2, -k * 26 - 4), Vector2(tw4, ts(f["size"]) * 1.35)), Color(0, 0, 0, 0.7 * col.a))   # V1.5：高對比文字底板
				_text(f["p"] + Vector2(0, -k * 26), f["s"], ts(f["size"]), col, true, true)
			else:
				var p3: Vector2 = f.get("rp", f["p"] + Vector2(0, -k * 26))
				var r3: Rect2 = f.get("rr", Rect2(p3, Vector2.ZERO))
				# V1.3 P1：印章式出場：前 0.1 秒從上方 8px 壓下來就停住（泡泡和字一起移，字級與外框幾何不變）
				if not f.has("rr"):   # 還沒排版（第一幀之前）：照舊壓下
					var slam := 1.0 - minf(float(f["t"]) / 0.1, 1.0)
					p3.y -= 8.0 * slam * slam
					r3.position.y -= 8.0 * slam * slam
				var dim := _clutch_dim(p3)
				col.a *= dim
				var numeric := is_num_text(str(f["s"]))
				# 1.6.0 B08（Hydrogen r1）：避讓把字推離原位（>18px）時，畫一條細引線回到自己那隻兵的頭頂上方（不然會被看成旁邊那隻的字）
				var sg: Array = f.get("seg", [])
				if sg.size() == 2:
					draw_line(sg[0], sg[1], Color(0.16, 0.1, 0.05, 0.75 * col.a), 1.6, true)
					draw_circle(sg[1], 2.2, Color(0.16, 0.1, 0.05, 0.75 * col.a), true, -1.0, true)
				if not f.get("plain", false) and not numeric:
					_bubble(r3, col.a)   # V1.2 C6：漫畫對話泡（羊皮紙色圓角＋墨線＋朝下的尖角），取代黑色膠囊
				var sz := int(ts(f["size"]) * (1.0 + float(f.get("pop", 0.0)) * 1.4))
				if numeric and not f.get("plain", false):
					# 1.5.0 §7 戰況字降噪：純數字不包泡泡——奶白偏原色的字＋深褐粗外框（泡泡只留給擊倒、致命等關鍵短標）
					var fill := col.lerp(Color(1.0, 0.96, 0.88, col.a), 0.55)
					_text(p3, f["s"], sz, fill, true, true, 0.0, Color(0.24, 0.13, 0.06, col.a))
				elif f.get("plain", false):
					_text(p3, f["s"], sz, col, true, true, 0.0, Color(0.05, 0.2, 0.08, col.a))   # 補血綠字加深墨綠描邊
				else:
					var ink0 := _ink_mode
					_ink_mode = not bool(Save.s("plain_ui"))   # 紙條上用墨色字（_ink 保留色相、壓深）
					_ink_keep_a = true
					_text(p3, f["s"], sz, col, true, true)   # 外框與實際畫的字同一份幾何
					_ink_keep_a = false
					_ink_mode = ink0


## 1.3.0 §11 老闆的手：開戰前（正式對局的 1 秒開場）從右上伸進來替棋鐘上發條——棉麻布袖、骨雕扳指；
## 只在盤外（棋鐘在頂部 HUD），伸進 0～0.4、轉兩下 0.4～0.75、收袖 0.75～0.85、停 0.15。截圖、減少特效不演（開場本來就不播）。
func _draw_owner_hand() -> void:
	if start_hold <= 0.0 or bool(Save.s("plain_ui")):
		return
	var k := 1.0 - clampf(start_hold, 0.0, 1.0)
	var reach := 0.0
	if k < 0.4:
		reach = 1.0 - pow(1.0 - k / 0.4, 3.0)
	elif k < 0.75:
		reach = 1.0
	elif k < 0.85:
		reach = 1.0 - (k - 0.75) / 0.1
	if reach <= 0.0:
		return
	var tip := Vector2(724, 18)   # 棋鐘牌右側的發條鈕
	var from := Vector2(1320, -70)
	var p := from.lerp(tip, reach)
	var tw := sin(clampf((k - 0.4) / 0.35, 0.0, 1.0) * PI * 4.0) * 0.18 if k >= 0.4 and k < 0.75 else 0.0
	var dir := (tip - from).normalized()
	var side := Vector2(-dir.y, dir.x)
	var linen := Color(0.86, 0.8, 0.68)
	# 袖子（從畫面外到手腕，寬口）
	var w0 := 30.0
	var w1 := 20.0
	var cuff := p - dir * 26.0
	draw_colored_polygon(PackedVector2Array([from + side * w0, from - side * w0, cuff - side * w1, cuff + side * w1]), linen.darkened(0.1))
	draw_line(cuff + side * w1, cuff - side * w1, linen.darkened(0.35), 3.0, true)
	# 手（掌＋三指捏著發條）、骨雕扳指
	draw_set_transform_matrix(Transform2D(atan2(dir.y, dir.x) + tw, p - dir * 10.0))
	draw_colored_polygon(PackedVector2Array([Vector2(-18, -11), Vector2(4, -12), Vector2(12, -5), Vector2(12, 5), Vector2(4, 12), Vector2(-18, 11)]), Color(0.93, 0.78, 0.64))
	for fi in 3:
		draw_line(Vector2(8, -6 + fi * 6), Vector2(17, -5 + fi * 5), Color(0.9, 0.74, 0.6), 4.5, true)
	draw_rect(Rect2(Vector2(0, -12), Vector2(5, 7)), Color(0.95, 0.92, 0.82))   # 骨雕扳指
	draw_line(Vector2(-18, 0), Vector2(2, 0), Color(0.75, 0.6, 0.48, 0.5), 1.0, true)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## 1.4.0 §10.1 老闆依勝負的手勢（對 AI、播完到結算前）：玩家贏＝伸手在棋鐘旁放一枚紅泥小章；玩家輸＝在桌緣叩兩下。
## 純畫面；簡化介面、減少特效、截圖不畫（和開場上發條同一條規則）。
func owner_end_pose(winner: int, t: float) -> Array:
	# → [伸出程度 0～1, 叩桌位移 px, 章放下了沒]
	var k := clampf(t / 1.3, 0.0, 1.0)
	var reach := 0.0
	if k < 0.35:
		reach = 1.0 - pow(1.0 - k / 0.35, 3.0)
	elif k < 0.8:
		reach = 1.0
	elif k < 1.0:
		reach = 1.0 - (k - 0.8) / 0.2
	var knock := 0.0
	if winner == 1 and k >= 0.35 and k < 0.8:
		knock = absf(sin((k - 0.35) / 0.45 * PI * 2.0)) * 6.0
	return [reach, knock, winner == 0 and k >= 0.5]

var owner_end_force := false   # 開發截圖：固定拍謝幕那一刻
func _draw_owner_end() -> void:
	if view == null or not view.finished or mode != Mode.VS_AI or bool(Save.s("plain_ui")) or bool(Save.s("reduce_fx")) or (shot_dir != "" and not owner_end_force) or sim == null or sim.winner < 0:
		return
	if play_kind != "official" or not bool(call("seat_visible")):
		return   # 只在正式對 AI 局（重播、覆盤、看代碼、幽靈、週賽、天梯不畫；和對手坐席同一條，Codex cat10 #1）
	var ps: Array = owner_end_pose(sim.winner, result_delay)
	if float(ps[0]) <= 0.0:
		return
	# 右側桌面、茶杯下方（不蓋 HUD 與按鈕；對手坐席在上、茶杯在中）
	var tip := Vector2(1214, 600) if sim.winner == 0 else Vector2(1206, 650)
	var from := Vector2(1340, 560) if sim.winner == 0 else Vector2(1340, 720)
	var p := from.lerp(tip, float(ps[0])) + Vector2(0, float(ps[1]))
	if bool(ps[2]):
		# 放下的紅泥小章（手的左邊）：右下落影＋下緣厚度＋印面淺框，像一塊放在桌上的小方印（Antigravity cat10 #2）
		draw_rect(Rect2(tip + Vector2(-37, -6), Vector2(24, 22)), Color(DIM_INK, 0.45))
		draw_rect(Rect2(tip + Vector2(-40, -8), Vector2(22, 22)), PAL.TRINKET_RED.darkened(0.35))
		draw_rect(Rect2(tip + Vector2(-40, -12), Vector2(22, 20)), Color(PAL.TRINKET_RED, 0.95))
		draw_rect(Rect2(tip + Vector2(-36, -8), Vector2(14, 12)), Color(1, 0.9, 0.8, 0.35), false, 1.5)
	var dir := (tip - from).normalized()
	var side := Vector2(-dir.y, dir.x)
	var linen := Color(0.86, 0.8, 0.68)
	var cuff := p - dir * 26.0
	draw_circle(p + Vector2(4, 10), 14.0, Color(DIM_INK, 0.3), true, -1.0, true)   # 手在桌面上的落影
	draw_colored_polygon(PackedVector2Array([from + side * 30.0, from - side * 30.0, cuff - side * 20.0, cuff + side * 20.0]), linen.darkened(0.1))
	draw_line(cuff + side * 20.0, cuff - side * 20.0, linen.darkened(0.35), 3.0, true)
	draw_set_transform_matrix(Transform2D(atan2(dir.y, dir.x), p - dir * 10.0))
	draw_colored_polygon(PackedVector2Array([Vector2(-18, -11), Vector2(4, -12), Vector2(12, -5), Vector2(12, 5), Vector2(4, 12), Vector2(-18, 11)]), Color(0.93, 0.78, 0.64))
	for fi in 3:
		draw_line(Vector2(8, -6 + fi * 6), Vector2(14 if sim.winner == 1 else 17, -5 + fi * 5), Color(0.9, 0.74, 0.6), 4.5, true)   # 叩桌時握拳（指頭短）
	draw_rect(Rect2(Vector2(0, -12), Vector2(5, 7)), Color(0.95, 0.92, 0.82))
	draw_set_transform_matrix(Transform2D.IDENTITY)


## 1.5.0 §7：數字型跳字不包泡泡——只有數字、正負號、×、括號、百分比（含全形）；有字（衝鋒、擊倒…）的照舊泡泡。
## 合併跳字「×3（24）」也算數字型（Codex v150 cat07 #3）。英文字母 x 不算（避免把詞當數字）。
## 全形字用碼位組出來：原始碼裡不放字面（字型覆蓋檢查會把原始碼字面當成要顯示的字）
static func is_num_text(s: String) -> bool:
	var has_digit := false
	for ch in s.strip_edges():
		var c := ch.unicode_at(0)
		if (c >= 0x30 and c <= 0x39) or (c >= 0xFF10 and c <= 0xFF19):
			has_digit = true
		elif not (ch in "+-×()% " or c in [0xFF0B, 0x2212, 0xFF0D, 0xFF08, 0xFF09, 0xFF05, 0x3000]):
			return false
	return has_digit
