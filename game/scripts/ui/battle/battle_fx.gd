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
	# 1.2.0 第 4 大類 A11：跳字泡改成小紙條（米白紙底＋墨邊），字用墨色（保留色相）；簡化介面維持深色泡
	var paper := not bool(Save.s("plain_ui"))
	var fill := Color(0.96, 0.92, 0.83, 0.92 * a) if paper else Color(0.10, 0.07, 0.05, 0.82 * a)
	var edge := Color(0.26, 0.16, 0.08, 0.7 * a) if paper else Color(0.95, 0.86, 0.66, 0.55 * a)
	var mid := rr.position.x + rr.size.x * 0.5
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
		"spark":
			# V1.5：法術命中的碎光（8 道放射短線＋中心光點）
			var sk: float = f["t"] / f["dur"]
			var sc: Color = f.get("c", Color.WHITE)
			var sp0: Vector2 = f["p"]
			for i in 8:
				var dv := Vector2.from_angle(i * TAU / 8.0 + 0.3)
				draw_line(sp0 + dv * (4.0 + sk * 10.0), sp0 + dv * (8.0 + sk * 16.0), Color(sc, 1.0 - sk), 2.4, true)
			draw_circle(sp0, 6.0 * (1.0 - sk), Color(sc.lightened(0.5), 0.9 * (1.0 - sk)), true, -1.0, true)
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
				var fc0: Color = f.get("tc", Color.WHITE)
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
			# V1.0.0 角色：毒改濁紫（綠色留給補血），兩顆錯開的斑點
			draw_circle(f["p"] + Vector2(-3.0, -k * 14.0), 3.0 + k * 3.0, Color(0.62, 0.42, 0.78, 0.75 * (1.0 - k)), true, -1.0, true)
			draw_circle(f["p"] + Vector2(4.0, -k * 10.0 - 4.0), 2.0 + k * 2.0, Color(0.5, 0.32, 0.62, 0.6 * (1.0 - k)), true, -1.0, true)
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
				draw_colored_polygon(q, Color(0.96, 0.92, 0.8, 0.9 * (1.0 - k * 0.6)))
		"bonesup":
			# 1.1.0 A7：骷髏拼裝：5 根骨頭從外圈收進來（0.15 秒），收完就是本體
			for bi in 5:
				var ab := bi * TAU / 5.0 + 0.4
				var rr := 18.0 * (1.0 - k)
				var c0: Vector2 = f["p"] + Vector2(cos(ab), sin(ab) * 0.8) * rr
				var d0 := Vector2(cos(ab + 1.2), sin(ab + 1.2)) * 4.0
				draw_line(c0 - d0, c0 + d0, Color(0.93, 0.9, 0.82, 1.0 - k * 0.5), 2.2, true)
		"slimehop":
			# 1.1.0 A7：小史萊姆從母體彈出半圈：沿半圓弧的殘影＋落地壓扁回彈（弧在 0.3 格內）
			var dxh: float = f.get("dir", 1.0)
			var start: Vector2 = f["p"] + Vector2(-14.0 * dxh, 0)
			if k < 0.6:
				var kh := k / 0.6
				var pos := start.lerp(f["p"], kh) + Vector2(0, -14.0 * sin(kh * PI))
				draw_circle(pos + Vector2(0, -6), 4.5, Color(0.45, 1.0, 0.55, 0.7), true, -1.0, true)
			else:
				var ks := (k - 0.6) / 0.4
				var sq := 1.0 + 0.5 * sin(ks * PI)
				draw_set_transform_matrix(_cam * Transform2D(0, Vector2(sq, 1.0 / sq), 0, f["p"] + Vector2(0, -3)))
				draw_circle(Vector2.ZERO, 5.0, Color(0.45, 1.0, 0.55, 0.6 * (1.0 - ks)), true, -1.0, true)
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
				var slam := 1.0 - minf(float(f["t"]) / 0.1, 1.0)
				p3.y -= 8.0 * slam * slam
				r3.position.y -= 8.0 * slam * slam
				var dim := _clutch_dim(p3)
				col.a *= dim
				if not f.get("plain", false):
					_bubble(r3, col.a)   # V1.2 C6：漫畫對話泡（羊皮紙色圓角＋墨線＋朝下的尖角），取代黑色膠囊
				var sz := int(ts(f["size"]) * (1.0 + float(f.get("pop", 0.0)) * 1.4))
				if f.get("plain", false):
					_text(p3, f["s"], sz, col, true, true, 0.0, Color(0.05, 0.2, 0.08, col.a))   # 補血綠字加深墨綠描邊
				else:
					var ink0 := _ink_mode
					_ink_mode = not bool(Save.s("plain_ui"))   # 紙條上用墨色字（_ink 保留色相、壓深）
					_ink_keep_a = true
					_text(p3, f["s"], sz, col, true, true)   # 外框與實際畫的字同一份幾何
					_ink_keep_a = false
					_ink_mode = ink0
