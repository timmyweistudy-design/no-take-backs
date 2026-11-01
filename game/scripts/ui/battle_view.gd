extends "res://scripts/ui/ui_base.gd"
const EV = preload("res://scripts/core/events.gd")
## 戰場、單位、特效、戰鬥 HUD、最後時刻鏡頭（演出層：不影響戰鬥結果）。


func _on_skip() -> void:
	while not view.finished:
		_sim_step(false)
	result_delay = 9.0


func _battle_process(delta: float) -> void:
	if hitstop > 0:
		hitstop -= delta
		return
	var rate := speed
	if slow_left > 0:
		rate *= 0.5
		slow_left -= delta
	accum += delta * rate
	while accum >= 0.05 and not view.finished:
		accum -= 0.05
		_sim_step(true)
	# 播完之後展示時鐘繼續走（不再推進快照）：最後一格的位置插值與最後一擊的後搖要演完（Codex R5 #1）
	_check_clutch()
	sfx.set_muffled(slow_left > 0 and not view.finished)
	if slow_left > 0 and not view.finished:
		_frame_alive(delta)
	else:
		zoom_target = 1.0
	zoom = lerpf(zoom, zoom_target, delta * 3)
	if view.finished:
		result_delay += delta
		if result_delay > 1.4:
			_finish_battle()


## 最後時刻（優化方案 F1）：雙方剩餘戰力都 ≤30% 且差距 ≤15%；或雙方各剩 ≤3 隻且差距 ≤15%。
func _check_clutch() -> void:
	if slow_used or view.finished:
		return
	var tot := float(view.budget * 1000)
	var p0: float = view.power(0) * 100.0 / tot
	var p1: float = view.power(1) * 100.0 / tot
	var a0: int = view.alive_count(0)
	var a1: int = view.alive_count(1)
	if absf(p0 - p1) <= 15.0 and ((p0 <= 30.0 and p1 <= 30.0) or (a0 <= 3 and a1 <= 3)):
		slow_used = true
		if bool(Save.s("slowmo")):
			slow_left = 8.0
		_fx_text(Vector2(640, 92), L.t("clutch"), ACCENT, 1.4, 34, true)
		sfx.play("clutch")


## 鏡頭安全框（優化方案 F2）：把所有存活單位框進畫面，四周留 15%。
func _frame_alive(delta: float) -> void:
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for u in view.units:
		if u.alive:
			var p := _upos(u)
			lo = lo.min(p - Vector2(30, 70))
			hi = hi.max(p + Vector2(30, 20))
	var size := (hi - lo) / 0.7
	zoom_target = clampf(minf(1280.0 / maxf(1, size.x), 620.0 / maxf(1, size.y)), 1.08, 1.5)
	zoom_center = zoom_center.lerp((lo + hi) / 2, minf(1.0, delta * 3))


## 畫面前進一個 tick：模擬保持領先 DELAY 個 tick，畫面播最舊的那一份快照（R5 展示緩衝）。
func _sim_step(with_fx: bool) -> void:
	_pump_view()
	for u in view.units:
		prev_pos[u.id] = Vector2(u.x, u.y)
	if not view.advance():
		view.finished = true
		return
	_pump_view()
	if view.frenzy and not frenzy_seen:
		frenzy_seen = true
		if with_fx:
			_fx_text(Vector2(640, 140), L.t("frenzy_banner"), Color.ORANGE_RED, 2.0, 30, true)
			sfx.play("frenzy")
			sfx.play_music("music_frenzy")
	var deaths := 0
	for ev in view.events:
		var k: String = ev["kind"]
		if ev.has("src"):
			var s = view.unit_by_id(ev["src"])
			var key := "%s%d" % [k, s.team]
			ev_count[key] = int(ev_count.get(key, 0)) + 1
		if k == EV.DEATH:
			deaths += 1
		_on_event(ev, with_fx)
	# 碾壓局最後一擊（優化方案 F1）：0.2 秒頓格＋微震，直接進結算
	if view.finished and not slow_used and deaths > 0 and with_fx:
		hitstop = 0.2
		if bool(Save.s("shake")):
			shake = 0.15


## 模擬往前補到領先 DELAY 個 tick；新進緩衝的攻擊事件先記下命中 tick，畫面就能在命中前開始演前搖。
func _pump_view() -> void:
	for fr in view.pump(sim):
		for e in fr["events"]:
			if event_route(e) == "attack":
				var hs: Array = atk_hit.get(e["src"], [])
				hs.append(int(fr["tick"]))   # 存序列，不覆蓋還沒播到的命中（Codex R5 #2：連續反擊）
				if hs.size() > 4:
					hs.pop_front()
				atk_hit[e["src"]] = hs


## 畫面上現在播到第幾 tick（含小數，插值用）。
func _disp_tick() -> float:
	if view == null:
		return 0.0
	if state != St.BATTLE:
		return float(view.tick)
	return view.tick + clampf(accum / 0.05, 0.0, 8.0 if view.finished else 1.0)


## 這一刻要演哪一次命中（Codex R5 #2）：取前搖已開始的最近一次；但前一次的揮擊還沒做完就先讓它做完（揮擊優先、後搖可被截斷）。
static func pick_hit(hits: Array, disp: float, type: int) -> int:
	var w := float(ViewBuffer.DELAY)
	var tot := clampf(float(D.STATS[type]["cd"]) / 4.0, 4.0, 6.4)
	var strike_end := w + 0.22 * tot
	var cur := -1
	for h in hits:
		if float(h) - w <= disp:
			if cur >= 0 and disp - (float(cur) - w) < strike_end:
				break   # 前一次還在揮擊，不換
			cur = h
	return cur


## 三段式攻擊進度（R5）：前搖固定是命中前 DELAY 個 tick，揮擊與後搖依攻擊間隔壓縮（攻速快的兵動作也快，不會疊在一起）。
## 回傳 Art.unit 的 atk 參數：0＝沒在攻擊；0～0.3125 前搖、0.3125～0.53125 揮擊（命中在 0.3125）、之後後搖到 1。
static func atk_progress(dt: float, type: int) -> float:
	var period := float(D.STATS[type]["cd"]) / 4.0
	var tot := clampf(period, 4.0, 6.4)
	var w := float(ViewBuffer.DELAY)
	var st := 0.22 * tot
	var rc := tot - w - st
	if dt < 0.0 or dt >= tot:
		return 0.0
	var a: float
	if dt < w:
		a = Art.ATK_WINDUP * dt / w
	elif dt < w + st:
		a = Art.ATK_WINDUP + (Art.ATK_STRIKE - Art.ATK_WINDUP) * (dt - w) / st
	else:
		a = Art.ATK_STRIKE + (1.0 - Art.ATK_STRIKE) * (dt - w - st) / rc
	return maxf(a, 0.001)


func _star_above(c: Vector2) -> void:
	var r := 6.0 + sin(time * 6.0) * 1.0
	var pts := PackedVector2Array()
	for i in 10:
		var an := -PI / 2 + i * TAU / 10.0
		pts.append(c + Vector2(cos(an), sin(an)) * (r if i % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, Color(1, 0.88, 0.3))


## 事件分流（Codex R3 審查 #1）：只有帶 dmg 的才是攻擊；背水開關沒有 src；嘲諷、現形、繞翼只有演出。
## 回傳 "death"／"skip"／"taunt"／"reveal"／"attack"。測試會把真實戰鬥的每一種事件都丟進來檢查。
static func event_route(ev: Dictionary) -> String:
	var k: String = ev.get("kind", "")
	if k == EV.DEATH:
		return "death"
	if k == EV.TAUNT or k == EV.REVEAL:
		return k if ev.has("src") and ev.has("tgt") else "skip"
	if ev.has("dmg") and ev.has("src") and ev.has("tgt"):
		return "attack"
	return "skip"


func _on_event(ev: Dictionary, with_fx: bool) -> void:
	var k: String = ev["kind"]
	if k == EV.DEATH:
		var u = view.unit_by_id(ev["id"])
		dying.append({"pos": _upos(u), "type": u.type, "team": u.team, "face": signf(u.fx) if u.fx != 0 else 1.0, "t": 0.0})
		if with_fx:
			sfx.play("death", 0.7)
		return
	var route := event_route(ev)
	if route == "skip" or not with_fx:
		return
	match route:
		"taunt":
			var sh = view.unit_by_id(ev["src"])
			var vic = view.unit_by_id(ev["tgt"])
			fx.append({"kind": "taunt", "p": _upos(sh), "t": 0.0, "dur": 0.6})
			sfx.play("taunt", 0.5)
			fx.append({"kind": "bang", "p": _upos(vic) + Vector2(0, -64), "t": 0.0, "dur": 0.7})
			return
		"reveal":
			fx.append({"kind": "puff", "p": _upos(view.unit_by_id(ev["src"])) + Vector2(0, -20), "t": 0.0, "dur": 0.45})
			sfx.play("reveal", 0.6)
			return
	var s = view.unit_by_id(ev["src"])
	var t = view.unit_by_id(ev["tgt"])
	var tags: Array = ev.get("tags", [])
	atk_t[s.id] = time
	hurt_t[t.id] = time
	var sp := _upos(s)
	var tpos := _upos(t)
	if tags.has(EV.ALERT):
		sfx.play("alert", 0.5)
		fx.append({"kind": "aim", "a": sp + Vector2(0, -24), "b": tpos + Vector2(0, -22), "t": 0.0, "dur": 0.32})
	if tags.has(EV.HIDE):
		fx.append({"kind": "hide", "p": tpos + Vector2(0, -24), "dir": signf(sp.x - tpos.x) if sp.x != tpos.x else 1.0, "t": 0.0, "dur": 0.4})
	if tags.has(EV.TRIP):
		sfx.play("snap", 0.7)
		fx.append({"kind": "trip", "p": tpos + Vector2(0, -4), "t": 0.0, "dur": 0.5})
	if s.type == D.ARCHER:
		fx.append({"src": s.id, "kind": "arrow", "a": sp + Vector2(10 * signf(tpos.x - sp.x), -24), "b": tpos + Vector2(0, -22), "t": 0.0, "dur": 0.28, "tc": Art.team_color(s.team, cbm())})
		sfx.play("arrow", 0.35)
	else:
		fx.append({"src": s.id, "kind": "slash", "p": sp, "dir": signf(tpos.x - sp.x) if tpos.x != sp.x else 1.0, "t": 0.0, "dur": 0.18})
		sfx.play("hit" if k == EV.HIT else "slash", 0.4)
	var col := Color.WHITE
	var label := ""
	match k:
		EV.CHARGE:
			label = L.t("ev_charge")
			col = ACCENT
			sfx.play("charge")
			sfx.play("bugle", 0.6)
			if bool(Save.s("shake")):
				shake = 0.12
			fx.append({"kind": "dust", "p": tpos, "t": 0.0, "dur": 0.5})
		EV.BACKSTAB:
			label = L.t("ev_backstab")
			col = Color("#c77dff")
			sfx.play("backstab")
			sfx.play("aircut", 0.7)
			fx.append({"kind": "flash", "p": tpos + Vector2(0, -26), "c": Color("#c77dff"), "t": 0.0, "dur": 0.25})
			fx.append({"kind": "vslash", "p": tpos + Vector2(0, -26), "dir": signf(tpos.x - sp.x) if tpos.x != sp.x else 1.0, "t": 0.0, "dur": 0.3})
		EV.BRACED:
			label = L.t("ev_braced")
			col = Color("#9ad1ff")
			sfx.play("bell", 0.8)
			brace_t[t.id] = time
			fx.append({"kind": "hex", "p": tpos + Vector2(10 * signf(sp.x - tpos.x), -24), "t": 0.0, "dur": 0.45})
		EV.ANTICAV:
			label = L.t("ev_anticav")
			col = Color("#9ad1ff")
			sfx.play("brace", 0.6)
		EV.BLOCKED:
			sfx.play("block", 0.5)
			fx.append({"kind": "ripple", "p": tpos + Vector2(14 * signf(sp.x - tpos.x), -26), "c": Color("#cfe3ff"), "t": 0.0, "dur": 0.3})
		EV.COUNTER:
			label = L.t("ev_counter")
			col = Color("#80ffdb")
		EV.BREAKER:
			sfx.play("shatter", 0.45)
			fx.append({"kind": "shard", "p": tpos + Vector2(12, -26), "t": 0.0, "dur": 0.5})
	if label != "":
		_merge_text(t.id, k, label, int(ev["dmg"]), tpos + Vector2(0, -78), col)


## 跳字合併（優化方案 F3）：同一目標、同一種效果 0.25 秒內合併成「背刺 ×3 120」。
func _merge_text(tid: int, kind: String, label: String, dmg: int, p: Vector2, col: Color) -> void:
	for f in fx:
		if f["kind"] == "text" and f.get("tid", -1) == tid and f.get("ek", "") == kind and f["t"] < 0.25:
			f["n"] += 1
			f["sum"] += dmg
			f["s"] = "%s ×%d（%d）" % [label, f["n"], f["sum"]]
			f["t"] = 0.0
			return
	# 排斥：附近已有跳字就往上疊
	var q := p
	for f in fx:
		if f["kind"] == "text" and not f.get("screen", false) and f["p"].distance_to(q) < 22:
			q.y -= 20
	fx.append({"kind": "text", "p": q, "s": "%s %d" % [label, dmg], "c": col, "t": 0.0, "dur": 0.85, "size": 18,
		"tid": tid, "ek": kind, "n": 1, "sum": dmg, "screen": false})


func _fx_text(p: Vector2, s: String, c: Color, dur: float, size: int, screen := false) -> void:
	fx.append({"kind": "text", "p": p, "s": s, "c": c, "t": 0.0, "dur": dur, "size": size, "screen": screen})


func _upos(u) -> Vector2:
	var cur := Vector2(u.x, u.y)
	var a := clampf(accum / 0.05, 0.0, 1.0) if state == St.BATTLE else 1.0
	var p: Vector2 = prev_pos.get(u.id, cur).lerp(cur, a)
	# 純畫面錯開（手感輪 2）：依編號固定偏移 ±4px，讓疊在一起的兵不會完全重合；戰鬥計算不受影響
	var j := Vector2(float((u.id * 37) % 9 - 4), float((u.id * 53) % 7 - 3))
	return ORIGIN + p * CS / 1000.0 + j


func _draw_field() -> void:
	draw_rect(Rect2(ORIGIN - Vector2(10, 10), FIELD + Vector2(20, 20)), Color("#5b4632"))
	for r in 9:
		for c in 16:
			var cell := Rect2(ORIGIN + Vector2(c, r) * CS, Vector2(CS, CS))
			if grass:
				var h := absi((c * 73856093) ^ (r * 19349663))
				draw_texture_rect_region(grass, cell, Rect2((h % 8) * 32, ((h / 8) % 4) * 32, 32, 32))
			else:
				draw_rect(cell, Color("#7cb342") if (r + c) % 2 == 0 else Color("#73a83d"))
			if c < 6:
				draw_rect(cell, Color(Art.team_color(0, cbm()), 0.08))
			elif c >= 10:
				draw_rect(cell, Color(Art.team_color(1, cbm()), 0.06))
	draw_rect(Rect2(ORIGIN, FIELD), Color(0.06, 0.09, 0.16, 0.18))
	for i in 17:
		draw_line(ORIGIN + Vector2(i * CS, 0), ORIGIN + Vector2(i * CS, FIELD.y), Color(0, 0, 0, 0.07), 1)
	for i in 10:
		draw_line(ORIGIN + Vector2(0, i * CS), ORIGIN + Vector2(FIELD.x, i * CS), Color(0, 0, 0, 0.07), 1)
	draw_dashed_line(ORIGIN + Vector2(6 * CS, 0), ORIGIN + Vector2(6 * CS, FIELD.y), Color(Art.team_color(0, cbm()), 0.75), 3.0, 8.0)
	draw_dashed_line(ORIGIN + Vector2(10 * CS, 0), ORIGIN + Vector2(10 * CS, FIELD.y), Color(Art.team_color(1, cbm()), 0.75), 3.0, 8.0)
	# 戰場色調（R6）：一般晨曦、殘局黃昏、遠征月夜。純調色，畫在單位底下，不影響辨識
	var tone := _tone()
	if tone.a > 0.0:
		draw_rect(Rect2(ORIGIN, FIELD), tone)
	if plants.size() >= 9:
		var deco := [[0, Vector2(52, 200)], [3, Vector2(70, 280)], [5, Vector2(30, 400)], [1, Vector2(60, 560)], [7, Vector2(90, 660)],
			[2, Vector2(1220, 190)], [6, Vector2(1240, 300)], [0, Vector2(1215, 470)], [4, Vector2(1245, 600)], [8, Vector2(1200, 676)]]
		for d in deco:
			var tex: Texture2D = plants[d[0]]
			var sz := tex.get_size() * (0.85 if d[0] <= 2 else 1.4)
			draw_texture_rect(tex, Rect2(d[1] - Vector2(sz.x / 2, sz.y), sz), false)


## 戰場色調：依模式固定（使用者決定：一般晨曦、殘局黃昏、遠征月夜）。
func _tone() -> Color:
	if state == St.TITLE:
		return Color(1.0, 0.72, 0.45, 0.07)
	match mode:
		Mode.PUZZLE:
			return Color(0.95, 0.42, 0.3, 0.16)    # 黃昏
		Mode.GAUNTLET:
			return Color(0.12, 0.16, 0.42, 0.30)   # 月夜
	return Color(1.0, 0.72, 0.45, 0.07)            # 晨曦


## 圖示膠囊標籤（R6）：kind＝"coin"／"unit"／"team"。回傳寬度。
func _pill(p: Vector2, kind: String, label: String, col: Color, size := 16, cap := 99) -> float:
	var fsz := mini(ts(size), cap)
	var tw := font_bold.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
	var w := tw + 40.0
	var h := fsz + 10.0
	draw_rect(Rect2(p, Vector2(w, h)), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(p, Vector2(w, h)), Color(col, 0.6), false, 1.5)
	var ic := p + Vector2(15, h / 2)
	match kind:
		"coin":
			draw_circle(ic, 7.5, Color("#b8860b"), true, -1.0, true)
			draw_circle(ic, 5.5, ACCENT, true, -1.0, true)
			draw_line(ic + Vector2(0, -3), ic + Vector2(0, 3), Color("#b8860b"), 1.6, true)
		"unit":
			draw_circle(ic + Vector2(0, -3.5), 3.6, Color.WHITE, true, -1.0, true)
			draw_rect(Rect2(ic + Vector2(-5, 1), Vector2(10, 6)), Color.WHITE)
		_:
			draw_circle(ic, 6.5, col, true, -1.0, true)
	_text(p + Vector2(28, 5 - fsz * 0.05), label, fsz, Color.WHITE, false, true)
	return w


## 按鍵提示列（R6）：手把時顯示 [A]／[X] 等按鍵圖示，鍵盤時顯示鍵名。items＝[[鍵, 說明], ...]，置中於 cx。
func _key_hints(cx: float, y: float, items: Array, size := 15) -> void:
	# 擺放畫面上方列高度固定 86px：大字設定時這一列最多放大到 17px，寬度不夠再縮（Codex 收尾輪 #3）
	var fs := mini(ts(size), 17)
	var widths: Array = []
	var total := 0.0
	for it in items:
		var kw := font_bold.get_string_size(it[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 2).x + 14.0
		var lw := font.get_string_size(it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		widths.append([kw, lw])
		total += kw + 6 + lw + 18
	if total > 1260.0:
		_key_hints_scaled(cx, y, items, fs - 1)
		return
	var x := cx - total / 2.0
	for i in items.size():
		var kw: float = widths[i][0]
		var key: String = items[i][0]
		var kc: Color = {"A": Color("#3ccf6e"), "B": Color("#ef5350"), "X": Color("#42a5f5"), "Y": Color("#ffca28")}.get(key, Color(0.75, 0.78, 0.85))
		var r := Rect2(x, y, kw, fs + 6)
		if key.length() == 1 and pad_mode:
			draw_circle(r.get_center(), r.size.y / 2, kc, true, -1.0, true)
		else:
			draw_rect(r, Color(kc, 0.9))
		_text(Vector2(r.get_center().x, y + 1), key, fs - 2, Color(0.08, 0.08, 0.1), true, true)
		x += kw + 6
		_text(Vector2(x, y + 1), items[i][1], fs, Color(1, 1, 1, 0.85))
		x += widths[i][1] + 18



func _key_hints_scaled(cx: float, y: float, items: Array, fs: int) -> void:
	# 縮一號再排（以實際像素傳入，避免再乘一次字級）
	var widths: Array = []
	var total := 0.0
	for it in items:
		var kw := font_bold.get_string_size(it[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 2).x + 14.0
		var lw := font.get_string_size(it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		widths.append([kw, lw])
		total += kw + 6 + lw + 18
	if total > 1260.0 and fs > 10:
		_key_hints_scaled(cx, y, items, fs - 1)
		return
	var x := cx - total / 2.0
	for i in items.size():
		var kw: float = widths[i][0]
		var r := Rect2(x, y, kw, fs + 6)
		draw_rect(r, Color(0.75, 0.78, 0.85, 0.9))
		_text(Vector2(r.get_center().x, y + 1), items[i][0], fs - 2, Color(0.08, 0.08, 0.1), true, true)
		x += kw + 6
		_text(Vector2(x, y + 1), items[i][1], fs, Color(1, 1, 1, 0.85))
		x += widths[i][1] + 18

func _draw_units_of(s, dim: bool) -> void:
	var list: Array = []
	for u in s.units:
		if u.alive:
			list.append(u)
	var live: bool = s == view
	if live:
		list.sort_custom(func(a, b): return _upos(a).y < _upos(b).y)
	else:
		list.sort_custom(func(a, b): return a.y < b.y)
	# 第一層：腳底標記與影子（全部先畫，不會被別人的身體整個蓋住時也看得到外圈）
	for u in list:
		var p0: Vector2 = _upos(u) if live else ORIGIN + Vector2(u.x, u.y) * CS / 1000.0
		_ring(p0, u.team, u.type, UNIT_SCALE)
		if live and s.rally[u.team] and not s.finished:
			for k in 2:
				var ph := fmod(time * 1.6 + k * 0.5, 1.0)
				draw_arc(p0, (14.0 + ph * 10.0) * UNIT_SCALE, 0, TAU, 20, Color(1, 0.42, 0.0, 0.55 * (1.0 - ph)), 2.0, true)
	# 第二層：身體
	for u in list:
		var p: Vector2 = _upos(u) if live else ORIGIN + Vector2(u.x, u.y) * CS / 1000.0
		var moving: bool = u.mx != 0 or u.my != 0
		var at := 0.0
		if live and atk_hit.has(u.id):
			var dt0 := _disp_tick()
			var h := pick_hit(atk_hit[u.id], dt0, u.type)
			if h >= 0:
				at = atk_progress(dt0 - (h - ViewBuffer.DELAY), u.type)
		var hurt := 0.0
		if live and hurt_t.has(u.id) and bool(Save.s("flash")):
			hurt = clampf(1.0 - (time - hurt_t[u.id]) / 0.15, 0, 1)
		var alpha := 0.45 if u.stealth > 0 else 1.0
		if dim:
			alpha *= 0.6
		var face := signf(u.fx) if u.fx != 0 else (1.0 if u.team == 0 else -1.0)
		# 表情與兵種專屬動作（R5）
		var mood := 0
		var lean := 0.0
		var crouch := 1.0
		if hurt > 0.3 or u.stun > 0:
			mood |= Art.M_HURT
		if u.type == D.CAVALRY and moving and u.charge >= D.CHARGE_NEED:
			mood |= Art.M_SPARKLE
			lean = 0.26                      # 衝鋒蓄滿前傾 15°
			for k in 3:                      # 馬蹄噴土
				var ph := fmod(time * 4.0 + k * 0.33 + u.id * 0.1, 1.0)
				draw_circle(p + Vector2(-face * (14 + ph * 16), -2 - ph * 6), 3.2 * (1.0 - ph), Color(0.85, 0.75, 0.55, 0.7 * (1.0 - ph)), true, -1.0, true)
		if s.frenzy and at == 0.0 and not s.finished:
			mood |= Art.M_BROWS
		if u.type == D.ASSASSIN and u.stealth > 0:
			mood |= Art.M_HOOD
			crouch = 0.9                     # 潛行蹲身
		if live and brace_t.has(u.id) and time - brace_t[u.id] < 0.35:
			mood |= Art.M_BRACE
		# 勝利：存活的勝方每 0.45 秒原地跳 10px、武器高舉
		var hop := 0.0
		if state == St.RESULT and live and sim != null and u.team == sim.winner:
			hop = absf(sin((time + u.id * 0.05) * PI / 0.45)) * 10.0
			at = Art.ATK_WINDUP
			_star_above(p + Vector2(0, -hop - (74 if u.type == D.CAVALRY else 66)))
		p.y -= hop
		var run := 1.6 if u.type == D.CAVALRY else (1.4 if u.type == D.ASSASSIN else 1.0)   # 快的兵跑步節奏也快
		if u.stealth > 0:
			# 潛行：身後兩道暗紫殘影
			for g in 2:
				var gp := p + Vector2(-(8 + g * 8) * face, 0)
				draw_circle(gp + Vector2(0, -22), 11.0 - g * 2.0, Color(0.3, 0.15, 0.45, 0.22 - g * 0.08), true, -1.0, true)
				_unit(gp, u.type, u.team, face, 0.0, 0.0, 0.0, 0.14 - g * 0.06, time, UNIT_SCALE)
		_unit(p, u.type, u.team, face, (time * 10.0 * run + u.id) if moving else 0.0, at, hurt, alpha, time, UNIT_SCALE, mood, lean, crouch)
	if dim:
		return
	# 第三層：小旗、血條、狀態（永遠畫在最上面）
	for u in list:
		var p: Vector2 = _upos(u) if live else ORIGIN + Vector2(u.x, u.y) * CS / 1000.0
		Art.flag(self, p + Vector2(-12, -50 if u.type != D.CAVALRY else -58), u.team, cbm())
		if u.stun > 0:
			# 暈眩：三顆金色菱形繞著頭轉
			var hc := p + Vector2(0, -70 if u.type == D.CAVALRY else -62)
			for j in 3:
				var an := time * 5.0 + j * TAU / 3.0
				var dc := hc + Vector2(cos(an) * 13, sin(an) * 4)
				var sz := 4.0 + sin(an) * 1.0
				draw_colored_polygon(PackedVector2Array([dc + Vector2(0, -sz), dc + Vector2(sz * 0.7, 0), dc + Vector2(0, sz), dc + Vector2(-sz * 0.7, 0)]), Color(1, 0.85, 0.25))
		if live and s.rally[u.team]:
			draw_arc(p + Vector2(0, -24), 22.0, 0, TAU, 20, Color(1, 0.45, 0.2, 0.35 + 0.15 * sin(time * 8)), 2.5, true)
		if s.frenzy:
			draw_circle(p + Vector2(8, -58 - sin(time * 12 + u.id) * 2), 3.0, Color(1, 0.5, 0.1, 0.9), true, -1.0, true)
		if u.hp < u.max_hp:
			var w := 28.0
			var top := p + Vector2(-w / 2, -66 if u.type == D.CAVALRY else -58)
			draw_rect(Rect2(top - Vector2(1, 1), Vector2(w + 2, 6)), Art.OUT)
			draw_rect(Rect2(top, Vector2(w * u.hp / u.max_hp, 4)), Art.team_color(u.team, cbm()).lightened(0.25))
			if cbm():
				# 色盲模式：血條左邊加隊伍形狀（藍＝●、紅＝◆），不只靠顏色（R8）
				var mk := top + Vector2(-6, 2)
				if u.team == 0:
					draw_circle(mk, 3.6, Art.OUT, true, -1.0, true)
					draw_circle(mk, 2.6, Art.team_color(0, true), true, -1.0, true)
				else:
					draw_colored_polygon(PackedVector2Array([mk + Vector2(0, -4.5), mk + Vector2(4.5, 0), mk + Vector2(0, 4.5), mk + Vector2(-4.5, 0)]), Art.OUT)
					draw_colored_polygon(PackedVector2Array([mk + Vector2(0, -3.2), mk + Vector2(3.2, 0), mk + Vector2(0, 3.2), mk + Vector2(-3.2, 0)]), Art.team_color(1, true))
	if not live:
		return
	for g in dying:
		var k: float = g["t"] / 1.0
		if k < 0.3:
			_unit(g["pos"], g["type"], g["team"], g["face"], 0.0, 0.0, 0.8, 1.0 - k / 0.3, time)
			for i in 6:
				var ang := i * TAU / 6
				draw_circle(g["pos"] + Vector2(cos(ang), sin(ang) * 0.5) * (8 + k * 70) + Vector2(0, -16), 4 * (1 - k), Color(1, 1, 1, 0.35), true, -1.0, true)
		Art.soul(self, g["pos"] + Vector2(sin(k * 9) * 4, -24 - k * 70), 0.75 * (1.0 - k))


func _draw_fx(f: Dictionary) -> void:
	var k: float = f["t"] / f["dur"]
	match f["kind"]:
		"arrow":
			var a: Vector2 = f["a"]
			var b: Vector2 = f["b"]
			var h := minf(60.0, a.distance_to(b) * 0.18)
			var p := a.lerp(b, k) + Vector2(0, -sin(k * PI) * h)
			var k2 := maxf(0.0, k - 0.06)
			var p2 := a.lerp(b, k2) + Vector2(0, -sin(k2 * PI) * h)
			var dirv := (p - p2).normalized() if p != p2 else Vector2.RIGHT
			var tail := p - dirv * 16.0
			for j in 6:
				var kk := maxf(0.0, k - 0.03 * (j + 1))
				var pt := a.lerp(b, kk) + Vector2(0, -sin(kk * PI) * h)
				draw_circle(pt, 1.6, Color(1, 1, 1, 0.35 * (1.0 - j / 6.0)), true, -1.0, true)
			draw_line(tail, p, Art.OUT, 4.0, true)
			draw_line(tail, p, Color("#d97706"), 2.2, true)
			var nrm := dirv.orthogonal()
			draw_colored_polygon(PackedVector2Array([p + dirv * 5.0, p + nrm * 3.0, p - nrm * 3.0]), Color("#e5e7eb"))
			var fc: Color = f.get("tc", Color.WHITE)
			draw_colored_polygon(PackedVector2Array([tail, tail - dirv * 5.0 + nrm * 4.0, tail + dirv * 3.0]), fc)
			draw_colored_polygon(PackedVector2Array([tail, tail - dirv * 5.0 - nrm * 4.0, tail + dirv * 3.0]), fc)
		"slash":
			var c: Vector2 = f["p"] + Vector2(f["dir"] * 16, -24)
			var start := -1.3 if f["dir"] > 0 else PI - 1.1
			draw_arc(c, 16, start, start + 2.4 * k, 12, Color(1, 1, 1, 1 - k), 3.5, true)
		"dust":
			for i in 7:
				var ang := i * TAU / 7
				draw_circle(f["p"] + Vector2(cos(ang) * (10 + k * 30), sin(ang) * 6 + 2), 6 * (1 - k), Color(0.85, 0.75, 0.55, 0.6 * (1 - k)), true, -1.0, true)
		"flash":
			var c2: Color = f["c"]
			var p0: Vector2 = f["p"]
			draw_line(p0 + Vector2(-14, -14) * (1 + k), p0 + Vector2(14, 14) * (1 + k), Color(c2, 1 - k), 4, true)
			draw_line(p0 + Vector2(-14, 14) * (1 + k), p0 + Vector2(14, -14) * (1 + k), Color(c2, 1 - k), 4, true)
		"ripple":
			var c3: Color = f["c"]
			draw_arc(f["p"], 6 + k * 18, -1.2, 1.2, 12, Color(c3, 1 - k), 3, true)
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
				draw_colored_polygon(pts, Color(0.93, 0.97, 1.0, 1 - k))
				draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.2, 0.25, 0.35, 1 - k), 1.2, true)
		"aim":
			# 警覺：金色瞄準線先拉出來，再淡掉
			var a2: Vector2 = f["a"]
			var b2: Vector2 = f["b"]
			var e2 := a2.lerp(b2, minf(1.0, k * 2.5))
			draw_dashed_line(a2, e2, Color(1, 0.84, 0.3, 0.6 * (1 - k)), 1.6, 6.0, true)
			draw_arc(b2, 9 - k * 3, 0, TAU, 16, Color(1, 0.84, 0.3, 1 - k), 2.0, true)
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
			draw_line(c5 + Vector2(-24, 0), c5 + Vector2(-gap, drop), Color(1, 1, 1, 1 - k), 3.0, true)
			draw_line(c5 + Vector2(gap, drop), c5 + Vector2(24, 0), Color(1, 1, 1, 1 - k), 3.0, true)
			if k < 0.25:
				draw_circle(c5, 5.0 * (1.0 - k * 4.0), Color(1, 1, 1, 0.9), true, -1.0, true)   # 繃斷的閃白
		"vslash":
			# 背刺：一道粗的紫色斬痕
			var c6: Vector2 = f["p"]
			var dd: float = f["dir"]
			var a0 := Vector2(-18 * dd, -16)
			var a1 := Vector2(18 * dd, 16)
			var e3 := a0.lerp(a1, minf(1.0, k * 3.0))
			draw_line(c6 + a0, c6 + e3, Color(0.78, 0.49, 1.0, 1 - k), 6.0 * (1 - k * 0.6), true)
			draw_line(c6 + a0, c6 + e3, Color(1, 1, 1, 0.8 * (1 - k)), 1.6, true)
		"taunt":
			# 嘲諷：盾兵身邊擴散的橘色圈
			for j in 2:
				var kj := clampf(k * 1.4 - j * 0.3, 0.0, 1.0)
				draw_arc(f["p"], 10 + kj * 22, 0, TAU, 28, Color(1, 0.55, 0.15, 0.6 * (1 - kj)), 2.5, true)
		"bang":
			# 嘲諷：被吸過去的敵人頭上冒「!」
			var y4 := -sin(minf(1.0, k * 3.0) * PI * 0.5) * 8.0
			_text(f["p"] + Vector2(0, y4 - 10), "!", ts(22), Color(1, 0.6, 0.2, 1.0 - k * k), true, true)
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
		"text":
			var p3: Vector2 = f["p"] + Vector2(0, -k * 26)
			var col: Color = f["c"]
			col.a = 1.0 - k * k
			_text(p3, f["s"], ts(f["size"]), col, true, true)


# ── 戰鬥 HUD ──
func _draw_battle_hud() -> void:
	draw_rect(Rect2(0, 0, 1280, 86), UI_BG)
	_text(Vector2(20, 8), L.t("title"), ts(26), Color("#ffe8a3"), false, true, 250)
	_text(Vector2(20, 52), _mode_label(), ts(14), Color(1, 1, 1, 0.6), false, false, 250)
	var tot := float(view.budget * 1000)
	var p0: int = view.power(0)
	var p1: int = view.power(1)
	var bx := 330.0
	var bw := 620.0
	var split := bw * p0 / maxf(1.0, p0 + p1)
	draw_rect(Rect2(bx - 2, 40, bw + 4, 26), Art.OUT)
	draw_rect(Rect2(bx, 42, split, 22), Art.team_color(0, cbm()))
	draw_rect(Rect2(bx + split, 42, bw - split, 22), Art.team_color(1, cbm()))
	draw_line(Vector2(bx + bw / 2, 36), Vector2(bx + bw / 2, 70), Color(1, 1, 1, 0.7), 2)
	_text(Vector2(bx + 8, 42), "%d%%" % roundi(p0 * 100 / tot), ts(15), Color.WHITE, false, true)
	var rt := "%d%%" % roundi(p1 * 100 / tot)
	_text(Vector2(bx + bw - 8 - font_bold.get_string_size(rt, HORIZONTAL_ALIGNMENT_LEFT, -1, ts(15)).x, 42), rt, ts(15), Color.WHITE, false, true)
	_text(Vector2(bx - 70, 42), L.t("units_left", [view.alive_count(0)]), ts(15), Art.team_color(0, cbm()), false, false, 64)
	_text(Vector2(bx + bw + 12, 42), L.t("units_left", [view.alive_count(1)]), ts(15), Art.team_color(1, cbm()), false, false, 70)
	for tm in 2:
		if view.rally[tm] and not view.finished:
			var rx := bx - 70.0 if tm == 0 else bx + bw + 12.0
			_text(Vector2(rx, 66), L.t("rally"), ts(13), Color(1, 0.55 + 0.2 * sin(time * 8), 0.3), false, true)
	var secs := maxi(0, 90 - view.tick / 20)
	_text(Vector2(640, 4), L.t("secs", [secs]) + ("　" + L.t("frenzy") if view.frenzy else ""), ts(22), Color.ORANGE_RED if view.frenzy else Color.WHITE, true, true)
	if mode == Mode.VS_AI and ai_name != "":
		_text(Vector2(bx + bw - 120, 68), "AI：%s" % ai_name, ts(11), Color(1, 1, 1, 0.55))
	if state == St.BATTLE and bool(Save.s("playtest")):
		if pt_call_tick < 0:
			_btn(Rect2(840, 8, 162, 34), L.t("pt_call"), func(): pt_call_tick = view.tick; _toast(L.t("pt_called", [view.tick / 20])))
	if state == St.BATTLE:
		_btn(Rect2(1010, 8, 120, 34), L.t("speed", [_fmt_num(speed)]), func(): speed = 2.0 if speed == 1.0 else (4.0 if speed == 2.0 else (0.5 if speed == 4.0 else 1.0)))
		_btn(Rect2(1138, 8, 132, 34), L.t("skip"), func(): _on_skip())
