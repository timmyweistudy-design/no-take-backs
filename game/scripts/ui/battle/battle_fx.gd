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



func _report_add(team: int, type: int, kind: String, label: String, col: Color) -> void:
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
	var cw := 412.0
	var plain := bool(Save.s("plain_ui"))
	if not ctl:
		var bar := Rect2(0, y0 - 3, 1280, mini(ceili(report_log.size() / 3.0), rows) * rh + 6)
		if plain:
			draw_rect(bar, Color(0, 0, 0, 0.5))   # 第十輪 V10：底條
		else:
			# V1.2 C6：戰報條是一條深木槽（上緣一道亮邊），不是黑色半透明帶
			_tex_box(bar, "groove", Color(0.42, 0.31, 0.22, 0.92))
			draw_rect(Rect2(0, bar.position.y, 1280, 1.5), Color(1, 0.88, 0.62, 0.22))
	for i in mini(report_log.size(), rows * 3):
		var e: Dictionary = report_log[i]
		var age: float = time - float(e["t"])
		var a := clampf(1.6 - age * 0.4, 0.35, 1.0)
		var p := Vector2(14.0 + (i % 3) * cw, y0 + (i / 3) * rh)
		var mark := "●" if e["team"] == 0 else "◆"
		var line := "%s %s" % [L.t("unit_%d" % int(e["type"])), e["label"]]
		if int(e["n"]) > 1:
			line += " ×%d" % int(e["n"])
		if plain:
			_text(p, mark, tz("S"), Color(Art.team_color(int(e["team"]), cbm()), a), false, true)
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
		if not plain and lc.get_luminance() < 0.55:
			lc = lc.lightened(0.45)   # 深木槽上，深色技能字（刺客紫）提亮（Antigravity impl4）
		_text(p + Vector2(tz("S") + 6.0, 0), line, tz("S"), Color(lc, a), false, true, cw - tz("S") - 14.0)



func _merge_text(tid: int, kind: String, label: String, dmg: int, p: Vector2, col: Color) -> void:
	if int(TEXT_TIER.get(kind, 1)) >= 2:
		text_key_in += 1
	var cell := Vector2i(floori(p.x / TEXT_CELL.x), floori(p.y / TEXT_CELL.y))
	for f in fx:
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
func _layout_texts() -> void:
	var list: Array = []
	for f in fx:
		if f["kind"] == "text" and not f.get("screen", false):
			list.append(f)
	list.sort_custom(func(a, b): return a.get("tier", 1) > b.get("tier", 1) or (a.get("tier", 1) == b.get("tier", 1) and a["t"] < b["t"]))
	var placed: Array = []
	for f in list:
		var k: float = f["t"] / f["dur"]
		var at: Vector2 = f["p"] + Vector2(0, -k * 26)
		var r := _text_rect(f, at)
		if true:   # 淡出中的也排，但排在最後（新的、關鍵的先佔位），所以不會推動正在顯示的
			var moved := true
			var guard := 0
			while moved and guard < 24:
				moved = false
				guard += 1
				for q: Rect2 in placed:
					if q.intersects(r):
						r.position.y = q.position.y - r.size.y - 2.0
						moved = true
			placed.append(r)
		f["rp"] = Vector2(r.get_center().x, r.position.y + 3.0)
		f["rr"] = r



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
	return {"visible": vis.size(), "fading": fading.size(), "max_overlap": worst, "max_overlap_fading": worst_f}


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



func _add_fx(d: Dictionary) -> void:
	if bool(Save.s("reduce_fx")) and d["kind"] in ["dust", "puff", "shard", "chips", "tell", "bones", "coins", "ripple", "note", "hex", "aim", "trip", "spore", "wool", "soulrise"]:
		return   # 第七輪 K3：簡化特效少掉粒子與裝飾，保留攻擊本身與嘲諷
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
	var n := 0
	for f in fx:
		if f["kind"] != "text":
			n += 1
	if n >= FX_CAP:
		var victim := -1
		for k in fx.size():
			var f2: Dictionary = fx[k]
			if f2["kind"] == "text":
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
				if fx[k3]["kind"] != "text" and (oldest < 0 or fx[k3]["t"] > fx[oldest]["t"]):
					oldest = k3
			fx.remove_at(oldest)
			fx_dropped += 1
	fx.append(d)



## V1.2 C6：對話泡。r＝文字外框；尖角朝下指向角色。透明度跟著字淡出。
func _bubble(r: Rect2, a: float) -> void:
	var rr := r.grow_individual(4, 1, 4, 2)
	var fill := Color(0.10, 0.07, 0.05, 0.82 * a)
	var edge := Color(0.95, 0.86, 0.66, 0.55 * a)
	var mid := rr.position.x + rr.size.x * 0.5
	var tail := PackedVector2Array([Vector2(mid - 5, rr.end.y - 1), Vector2(mid + 5, rr.end.y - 1), Vector2(mid - 1, rr.end.y + 7)])
	_box(rr, fill, edge, minf(10.0, rr.size.y * 0.5), 1.5)
	draw_colored_polygon(tail, fill)
	draw_polyline(PackedVector2Array([tail[0], tail[2], tail[1]]), edge, 1.5, true)

func _fx_text(p: Vector2, s: String, c: Color, dur: float, size: int, screen := false) -> void:
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
	var r: float = g[1] * (0.7 + 0.3 * minf(1.0, k * 3.0))
	draw_texture_rect(_glow_tex, Rect2(gp - Vector2(r, r * 0.8), Vector2(r * 2.0, r * 1.6)), false, Color(g[0], 0.32 * (1.0 - k)))

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
				draw_circle(mp - Vector2(-120, 320) * drop, 8.0, Color("#fff0b0"))
				draw_arc(mp, mr, 0, TAU, 40, Color(1, 0.5, 0.2, 0.7), 2.0, true)
			else:
				var bk := (k - 0.3) / 0.7
				draw_circle(mp, mr * (0.4 + bk * 0.6), Color(1, 0.5, 0.15, 0.45 * (1.0 - bk)))
				draw_arc(mp, mr * (0.4 + bk * 0.6), 0, TAU, 40, Color(1, 0.9, 0.6, 1.0 - bk), 4.0, true)
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
			# 雙層描邊（第三輪 V4）：深色底 4px＋亮芯
			for pair in [[Vector2(-14, -14), Vector2(14, 14)], [Vector2(-14, 14), Vector2(14, -14)]]:
				draw_line(p0 + pair[0] * (1 + k), p0 + pair[1] * (1 + k), Color(Art.OUT, 0.8 * (1 - k)), 8, true)
				draw_line(p0 + pair[0] * (1 + k), p0 + pair[1] * (1 + k), Color(c2, 1 - k), 4, true)
				draw_line(p0 + pair[0] * (1 + k), p0 + pair[1] * (1 + k), Color(1, 1, 1, 0.7 * (1 - k)), 1.5, true)
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
				draw_line(c0 - d0, c0 + d0, Color(0.95, 0.93, 0.85, 1.0 - k), 3.0, true)
		"coins":
			# V1.1 A7：寶箱怪倒下吐出幾枚金幣
			for i in 6:
				var an2 := -PI * 0.5 + (i - 2.5) * 0.45
				var v2 := Vector2(cos(an2), sin(an2)) * k * 34.0 + Vector2(0, k * k * 40.0)
				var c1: Vector2 = f["p"] + v2
				draw_circle(c1, 4.5, Color(Art.OUT, 1.0 - k), true, -1.0, true)
				draw_circle(c1, 3.2, Color(1.0, 0.82, 0.3, 1.0 - k), true, -1.0, true)
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
					draw_rect(Rect2(c0 - Vector2(2.5, 2.5), Vector2(5, 5)), Color(cc, 1.0 - k))
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
				draw_polyline(pts + PackedVector2Array([pts[0]]), Color(Art.OUT, 1 - k), 2.0, true)
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
		"spore":
			draw_circle(f["p"] + Vector2(0, -k * 14.0), 3.0 + k * 3.0, Color(0.6, 1.0, 0.4, 0.75 * (1.0 - k)), true, -1.0, true)
		"pin":
			draw_line(f["a"], f["b"], Color(1.0, 0.42, 0.7, 0.85 * (1.0 - k)), 3.0, true)
		"wool":
			for i8 in 9:
				var an8 := i8 * TAU / 9.0
				draw_circle(f["p"] + Vector2(cos(an8), sin(an8) * 0.7) * (8.0 + k * 34.0) + Vector2(0, k * k * 16.0), 5.0 * (1.0 - k), Color(1, 1, 1, 0.9 * (1.0 - k)), true, -1.0, true)
		"chomp":
			var gap8 := 12.0 * (1.0 - minf(1.0, k * 3.0))
			for s8 in [-1.0, 1.0]:
				var base8: Vector2 = f["p"] + Vector2(0, s8 * gap8)
				var tri := PackedVector2Array()
				for i9 in 4:
					tri.append(base8 + Vector2(-15.0 + i9 * 10.0, 0))
					tri.append(base8 + Vector2(-10.0 + i9 * 10.0, s8 * -8.0))
				tri.append(base8 + Vector2(25.0, 0))
				draw_polyline(tri, Color(1, 1, 1, 1.0 - k), 3.0, true)
		"timebell":
			var bellr := 18.0 + k * float(F8.SPRITE_R) * CS / 1000.0
			draw_arc(f["p"], bellr, 0, TAU, 48, Color(Art.OUT, 0.5 * (1.0 - k)), 7.0, true)
			draw_arc(f["p"], bellr, 0, TAU, 48, Color(1.0, 0.88, 0.5, 0.9 * (1.0 - k)), 4.0, true)
			draw_circle(f["p"], bellr, Color(1.0, 0.88, 0.5, 0.08 * (1.0 - k)), true, -1.0, true)
		"soulrise":
			for i10 in 5:
				var an10 := i10 * TAU / 5.0 + k * 3.0
				draw_circle(f["p"] + Vector2(cos(an10) * (14.0 - k * 8.0), -k * 38.0 + sin(an10) * 6.0), 5.0 * (1.0 - k), Color(0.72, 0.42, 1.0, 0.55 * (1.0 - k)), true, -1.0, true)
		"swirl":
			var maxr := float(F8.CAT_R) * CS / 1000.0
			for i11 in 3:
				var ph11 := fmod(k * 1.5 + i11 * 0.33, 1.0)
				var r11 := maxr * (1.0 - ph11)
				draw_arc(f["p"], r11, ph11 * 6.0, ph11 * 6.0 + 4.2, 26, Color(0.6, 0.85, 1.0, 0.4 * ph11), 2.4, true)
		"stompring":
			draw_set_transform_matrix(_cam * Transform2D(0, Vector2(1, 0.55), 0, f["p"]))
			var sr := 14.0 + k * float(F8.GOLEM_R) * CS / 1000.0
			# Antigravity 第 2 輪：環蓋在兵上面，不描黑邊、調淡，才不會切過臉
			draw_arc(Vector2.ZERO, sr, 0, TAU, 36, Color(0.92, 0.86, 0.68, 0.5 * (1.0 - k)), 3.5, true)
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
				draw_line(c6 + a0, c6 + e3, Color(1, 1, 1, 0.75 * (1 - k)), 1.2, true)
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
			var br := 14.0 + _smoothstep01(k) * 26.0
			var spikes := PackedVector2Array()
			for i in 20:
				var an := i * TAU / 20.0 + 0.2
				var rr := br * (1.0 if i % 2 == 0 else 0.5)
				spikes.append(bp + Vector2(cos(an) * rr, sin(an) * rr * 0.8))
			var fa := 1.0 - k * k
			draw_colored_polygon(spikes, Color(1.0, 0.42, 0.12, 0.92 * fa))
			for i in 20:
				spikes[i] = bp + (spikes[i] - bp) * 0.55
			draw_colored_polygon(spikes, Color(1.0, 0.86, 0.35, 0.95 * fa))
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
			draw_polyline(pts, Color(0.5, 1.0, 0.6, 0.7 * (1.0 - k)), 2.5, true)
			_cross(hb + Vector2(0, -k * 14.0), 5.0, Color(0.5, 1.0, 0.6, 1.0 - k))
		"note":
			# 音符放大 1.6 倍＋深咖啡描邊（Antigravity：原本跟草地小花一樣大）
			var np: Vector2 = f["p"] + Vector2(sin(k * 6.0) * 4.0, -k * 22.0)
			var na := 1.0 - k
			var oc := Color(0.24, 0.14, 0.05, na)
			var nc := Color(1.0, 0.86, 0.3, na)
			draw_circle(np, 6.6, oc, true, -1.0, true)
			draw_line(np + Vector2(5, 1), np + Vector2(5, -16), oc, 4.6, true)
			draw_line(np + Vector2(5, -16), np + Vector2(11, -11), oc, 4.6, true)
			draw_circle(np, 5.0, nc, true, -1.0, true)
			draw_line(np + Vector2(5, 1), np + Vector2(5, -16), nc, 2.4, true)
			draw_line(np + Vector2(5, -16), np + Vector2(11, -11), nc, 2.4, true)
		"text":
			var col: Color = f["c"]
			col.a = 1.0 - k * k
			if f.get("screen", false):
				_text(f["p"] + Vector2(0, -k * 26), f["s"], ts(f["size"]), col, true, true)
			else:
				var p3: Vector2 = f.get("rp", f["p"] + Vector2(0, -k * 26))
				var r3: Rect2 = f.get("rr", Rect2(p3, Vector2.ZERO))
				var dim := _clutch_dim(p3)
				col.a *= dim
				if not f.get("plain", false):
					_bubble(r3, col.a)   # V1.2 C6：漫畫對話泡（羊皮紙色圓角＋墨線＋朝下的尖角），取代黑色膠囊
				var sz := int(ts(f["size"]) * (1.0 + float(f.get("pop", 0.0)) * 1.4))
				if f.get("plain", false):
					_text(p3, f["s"], sz, col, true, true, 0.0, Color(0.05, 0.2, 0.08, col.a))   # 補血綠字加深墨綠描邊
				else:
					_text(p3, f["s"], sz, col, true, true)   # 外框與實際畫的字同一份幾何
