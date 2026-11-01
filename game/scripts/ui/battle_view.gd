extends "res://scripts/ui/ui_base.gd"
## 戰場、單位、特效、戰鬥 HUD、最後時刻鏡頭（演出層：不影響戰鬥結果）。


func _on_skip() -> void:
	while not sim.finished:
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
	while accum >= 0.05 and not sim.finished:
		accum -= 0.05
		_sim_step(true)
	_check_clutch()
	if slow_left > 0 and not sim.finished:
		_frame_alive(delta)
	else:
		zoom_target = 1.0
	zoom = lerpf(zoom, zoom_target, delta * 3)
	if sim.finished:
		result_delay += delta
		if result_delay > 1.4:
			_finish_battle()


## 最後時刻（優化方案 F1）：雙方剩餘戰力都 ≤30% 且差距 ≤15%；或雙方各剩 ≤3 隻且差距 ≤15%。
func _check_clutch() -> void:
	if slow_used or sim.finished:
		return
	var tot := float(sim.budget * 1000)
	var p0: float = sim.power(0) * 100.0 / tot
	var p1: float = sim.power(1) * 100.0 / tot
	var a0: int = sim.alive_count(0)
	var a1: int = sim.alive_count(1)
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
	for u in sim.units:
		if u.alive:
			var p := _upos(u)
			lo = lo.min(p - Vector2(30, 70))
			hi = hi.max(p + Vector2(30, 20))
	var size := (hi - lo) / 0.7
	zoom_target = clampf(minf(1280.0 / maxf(1, size.x), 620.0 / maxf(1, size.y)), 1.08, 1.5)
	zoom_center = zoom_center.lerp((lo + hi) / 2, minf(1.0, delta * 3))


func _sim_step(with_fx: bool) -> void:
	for u in sim.units:
		prev_pos[u.id] = Vector2(u.x, u.y)
	sim.step()
	if sim.frenzy and not frenzy_seen:
		frenzy_seen = true
		if with_fx:
			_fx_text(Vector2(640, 140), L.t("frenzy_banner"), Color.ORANGE_RED, 2.0, 30, true)
			sfx.play("frenzy")
			sfx.play_music("music_frenzy")
	var deaths := 0
	for ev in sim.events:
		var k: String = ev["kind"]
		if ev.has("src"):
			var s = sim.unit_by_id(ev["src"])
			var key := "%s%d" % [k, s.team]
			ev_count[key] = int(ev_count.get(key, 0)) + 1
		if k == "death":
			deaths += 1
		_on_event(ev, with_fx)
	# 碾壓局最後一擊（優化方案 F1）：0.2 秒頓格＋微震，直接進結算
	if sim.finished and not slow_used and deaths > 0 and with_fx:
		hitstop = 0.2
		if bool(Save.s("shake")):
			shake = 0.15


func _on_event(ev: Dictionary, with_fx: bool) -> void:
	var k: String = ev["kind"]
	if k == "death":
		var u = sim.unit_by_id(ev["id"])
		dying.append({"pos": _upos(u), "type": u.type, "team": u.team, "face": signf(u.fx) if u.fx != 0 else 1.0, "t": 0.0})
		if with_fx:
			sfx.play("death", 0.7)
		return
	if k == "attrition" or not with_fx:
		return
	var s = sim.unit_by_id(ev["src"])
	var t = sim.unit_by_id(ev["tgt"])
	atk_t[s.id] = time
	hurt_t[t.id] = time
	var sp := _upos(s)
	var tpos := _upos(t)
	if s.type == D.ARCHER:
		fx.append({"kind": "arrow", "a": sp + Vector2(10 * signf(tpos.x - sp.x), -24), "b": tpos + Vector2(0, -22), "t": 0.0, "dur": 0.28, "tc": Art.team_color(s.team, cbm())})
		sfx.play("arrow", 0.35)
	else:
		fx.append({"kind": "slash", "p": sp, "dir": signf(tpos.x - sp.x) if tpos.x != sp.x else 1.0, "t": 0.0, "dur": 0.18})
		sfx.play("hit" if k == "hit" else "slash", 0.4)
	var col := Color.WHITE
	var label := ""
	match k:
		"charge":
			label = L.t("ev_charge")
			col = ACCENT
			sfx.play("charge")
			if bool(Save.s("shake")):
				shake = 0.12
			fx.append({"kind": "dust", "p": tpos, "t": 0.0, "dur": 0.5})
		"backstab":
			label = L.t("ev_backstab")
			col = Color("#c77dff")
			sfx.play("backstab")
			fx.append({"kind": "flash", "p": tpos + Vector2(0, -26), "c": Color("#c77dff"), "t": 0.0, "dur": 0.25})
		"braced":
			label = L.t("ev_braced")
			col = Color("#9ad1ff")
			sfx.play("brace")
			fx.append({"kind": "ripple", "p": tpos + Vector2(10, -24), "c": ACCENT, "t": 0.0, "dur": 0.35})
		"anticav":
			label = L.t("ev_anticav")
			col = Color("#9ad1ff")
			sfx.play("brace", 0.6)
		"blocked":
			sfx.play("block", 0.5)
			fx.append({"kind": "ripple", "p": tpos + Vector2(14, -26), "c": ACCENT, "t": 0.0, "dur": 0.3})
		"counter":
			label = L.t("ev_counter")
			col = Color("#80ffdb")
		"breaker":
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
	if plants.size() >= 9:
		var deco := [[0, Vector2(52, 200)], [3, Vector2(70, 280)], [5, Vector2(30, 400)], [1, Vector2(60, 560)], [7, Vector2(90, 660)],
			[2, Vector2(1220, 190)], [6, Vector2(1240, 300)], [0, Vector2(1215, 470)], [4, Vector2(1245, 600)], [8, Vector2(1200, 676)]]
		for d in deco:
			var tex: Texture2D = plants[d[0]]
			var sz := tex.get_size() * (0.85 if d[0] <= 2 else 1.4)
			draw_texture_rect(tex, Rect2(d[1] - Vector2(sz.x / 2, sz.y), sz), false)


func _draw_units_of(s, dim: bool) -> void:
	var list: Array = []
	for u in s.units:
		if u.alive:
			list.append(u)
	var live: bool = s == sim
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
		if live and atk_t.has(u.id):
			at = clampf((time - atk_t[u.id]) / 0.25, 0, 1)
			if at >= 1:
				at = 0
		var hurt := 0.0
		if live and hurt_t.has(u.id) and bool(Save.s("flash")):
			hurt = clampf(1.0 - (time - hurt_t[u.id]) / 0.15, 0, 1)
		var alpha := 0.38 if u.stealth > 0 else 1.0
		if dim:
			alpha *= 0.6
		var face := signf(u.fx) if u.fx != 0 else (1.0 if u.team == 0 else -1.0)
		if u.stealth > 0:
			_unit(p + Vector2(-7 * face, 0), u.type, u.team, face, 0.0, 0.0, 0.0, 0.16, time, UNIT_SCALE)
		_unit(p, u.type, u.team, face, (time * 10.0 + u.id) if moving else 0.0, at, hurt, alpha, time, UNIT_SCALE)
	if dim:
		return
	# 第三層：小旗、血條、狀態（永遠畫在最上面）
	for u in list:
		var p: Vector2 = _upos(u) if live else ORIGIN + Vector2(u.x, u.y) * CS / 1000.0
		Art.flag(self, p + Vector2(-12, -50 if u.type != D.CAVALRY else -58), u.team, cbm())
		if u.stun > 0:
			_text(p + Vector2(0, -78), "✦", ts(16), Color.YELLOW, true)
		if live and s.rally[u.team]:
			draw_arc(p + Vector2(0, -24), 22.0, 0, TAU, 20, Color(1, 0.45, 0.2, 0.35 + 0.15 * sin(time * 8)), 2.5, true)
		if s.frenzy:
			draw_circle(p + Vector2(8, -58 - sin(time * 12 + u.id) * 2), 3.0, Color(1, 0.5, 0.1, 0.9), true, -1.0, true)
		if u.hp < u.max_hp:
			var w := 28.0
			var top := p + Vector2(-w / 2, -66 if u.type == D.CAVALRY else -58)
			draw_rect(Rect2(top - Vector2(1, 1), Vector2(w + 2, 6)), Art.OUT)
			draw_rect(Rect2(top, Vector2(w * u.hp / u.max_hp, 4)), Art.team_color(u.team, cbm()).lightened(0.25))
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
			for i in 4:
				var v := Vector2(cos(i * 1.7 + 0.5), sin(i * 1.7 + 0.5)) * k * 26
				draw_rect(Rect2(f["p"] + v + Vector2(0, k * k * 20), Vector2(5, 5)), Color(0.8, 0.85, 0.95, 1 - k))
		"text":
			var p3: Vector2 = f["p"] + Vector2(0, -k * 26)
			var col: Color = f["c"]
			col.a = 1.0 - k * k
			_text(p3, f["s"], ts(f["size"]), col, true, true)


# ── 戰鬥 HUD ──
func _draw_battle_hud() -> void:
	draw_rect(Rect2(0, 0, 1280, 86), UI_BG)
	_text(Vector2(20, 8), L.t("title"), ts(26), Color("#ffe8a3"), false, true)
	_text(Vector2(20, 52), _mode_label(), ts(14), Color(1, 1, 1, 0.6))
	var tot := float(sim.budget * 1000)
	var p0: int = sim.power(0)
	var p1: int = sim.power(1)
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
	_text(Vector2(bx - 70, 42), L.t("units_left", [sim.alive_count(0)]), ts(15), Art.team_color(0, cbm()))
	_text(Vector2(bx + bw + 12, 42), L.t("units_left", [sim.alive_count(1)]), ts(15), Art.team_color(1, cbm()))
	for tm in 2:
		if sim.rally[tm] and not sim.finished:
			var rx := bx - 70.0 if tm == 0 else bx + bw + 12.0
			_text(Vector2(rx, 66), L.t("rally"), ts(13), Color(1, 0.55 + 0.2 * sin(time * 8), 0.3), false, true)
	var secs := maxi(0, 90 - sim.tick / 20)
	_text(Vector2(640, 4), L.t("secs", [secs]) + ("　" + L.t("frenzy") if sim.frenzy else ""), ts(22), Color.ORANGE_RED if sim.frenzy else Color.WHITE, true, true)
	if mode == Mode.VS_AI and ai_name != "":
		_text(Vector2(bx + bw - 120, 68), "AI：%s" % ai_name, ts(11), Color(1, 1, 1, 0.55))
	if state == St.BATTLE and bool(Save.s("playtest")):
		if pt_call_tick < 0:
			_btn(Rect2(840, 8, 162, 34), L.t("pt_call"), func(): pt_call_tick = sim.tick; _toast(L.t("pt_called", [sim.tick / 20])))
	if state == St.BATTLE:
		_btn(Rect2(1010, 8, 120, 34), L.t("speed", [_fmt_num(speed)]), func(): speed = 2.0 if speed == 1.0 else (4.0 if speed == 2.0 else (0.5 if speed == 4.0 else 1.0)))
		_btn(Rect2(1138, 8, 132, 34), L.t("skip"), func(): _on_skip())
