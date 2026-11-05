extends "res://scripts/ui/battle/battle_fx.gd"
## 由 battle_view.gd 拆出（V9 P1，行為不變）

## 時間軸標記（首次衝鋒／背刺／頂住，每隊各一次）：正常播放與重播跳轉共用（Codex S5 #4）。
## 頂住的 src 是被頂住的騎兵，功勞算盾兵那一隊。
func _collect_mark(ev: Dictionary, lookup, tick: int) -> void:
	var k: String = ev["kind"]
	# 第七輪 A7：加首殺、破陣、背水
	if k != EV.CHARGE and k != EV.BACKSTAB and k != EV.BRACED and k != EV.DEATH and k != EV.BREACH and k != EV.RALLY_ON:
		return
	var team := -1
	if k == EV.DEATH:
		team = lookup.unit_by_id(ev["id"]).team
		for m0 in battle_marks:
			if m0["kind"] == k:
				return   # 首殺只記一次（不分隊）
	elif k == EV.RALLY_ON:
		team = int(ev["team"])
	else:
		team = lookup.unit_by_id(ev["tgt"] if k == EV.BRACED else ev["src"]).team
	for m in battle_marks:
		if m["kind"] == k and m["team"] == team:
			return
	battle_marks.append({"tick": tick, "kind": k, "team": team})



## 揮擊殘影（Antigravity S4：五兵種不能共用同一個圓弧）：
## 劍士＝月牙（上挑時從下往上）；刺客＝兩道交叉的短斬痕（X）；盾兵＝往前推的三道衝擊線；
## 騎兵＝水平突刺的槍芒；弓手＝沒有（箭本身就是演出）。sk＝0～1 的進度，sc＝縮放（樣品圖用）。
func _draw_smear(p: Vector2, type: int, team: int, face: float, sk: float, alpha: float, variant: int, sc: float) -> void:
	var sa := (1.0 - sk) * alpha
	var tc := Art.team_color(team, cbm())
	match type:
		D.SWORD:
			var c := p + Vector2(face * 12.0, -26) * sc
			var a0 := (-1.2 if face > 0 else PI - 1.2) if variant == 0 else (0.2 if face > 0 else PI - 2.6)
			var span := deg_to_rad(140.0) * minf(1.0, sk * 2.0)
			var start := a0 if face > 0 else a0 + deg_to_rad(140.0) - span
			draw_arc(c, 20.0 * sc, start, start + span, 18, Color(tc, 0.85 * sa), 6.0 * sc, true)
			draw_arc(c, 20.0 * sc, start, start + span, 18, Color(1, 1, 1, 0.9 * sa), 3.0 * sc, true)
		D.ASSASSIN:
			var c2 := p + Vector2(face * 16.0, -26) * sc
			var e := minf(1.0, sk * 2.5)
			for k in 2:
				var d := Vector2(10, -10 if k == 0 else 10) * sc
				var a := c2 - Vector2(d.x * face, d.y)
				var b := a.lerp(c2 + Vector2(d.x * face, d.y), e)
				draw_line(a, b, Color(0.78, 0.49, 1.0, 0.9 * sa), 4.0 * sc, true)
				draw_line(a, b, Color(1, 1, 1, 0.9 * sa), 1.6 * sc, true)
		D.SHIELD:
			var c3 := p + Vector2(face * 24.0, -24) * sc
			for k in 3:
				var off := Vector2(face * (4.0 + sk * 10.0 + k * 3.0), (k - 1) * 9.0) * sc
				draw_line(c3 + off, c3 + off + Vector2(face * 10.0, 0) * sc, Color(0.75, 0.88, 1.0, 0.9 * sa), 3.0 * sc, true)
		D.PIKE:
			# 長槍直刺：一道細長的突刺線（第四輪）
			var ptip := p + Vector2(face * 52.0, -24) * sc
			var plen := 40.0 * minf(1.0, sk * 2.0) * sc
			draw_line(ptip - Vector2(face * plen, 0), ptip, Color(tc, 0.8 * sa), 5.0 * sc, true)
			draw_line(ptip - Vector2(face * plen, 0), ptip, Color(1, 0.95, 0.85, 0.95 * sa), 2.0 * sc, true)
		D.BERSERKER:
			# 雙斧往下劈：兩道交叉的橘紅弧光（和刺客的紫 X 區分）
			var bc := p + Vector2(face * 12.0, -24) * sc
			var bspan := deg_to_rad(110.0) * minf(1.0, sk * 2.0)
			for k in 2:
				var b0 := (-1.0 + k * 0.5) if face > 0 else (PI + 1.0 - k * 0.5 - bspan)
				draw_arc(bc + Vector2(face * k * 6.0, 0) * sc, 18.0 * sc, b0, b0 + bspan, 14, Color(1.0, 0.45, 0.15, 0.85 * sa), 5.0 * sc, true)
				draw_arc(bc + Vector2(face * k * 6.0, 0) * sc, 18.0 * sc, b0, b0 + bspan, 14, Color(1, 0.95, 0.8, 0.9 * sa), 2.0 * sc, true)
		D.CAVALRY:
			var tip := p + Vector2(face * 34.0, -34) * sc
			var len := 34.0 * minf(1.0, sk * 2.0) * sc
			draw_line(tip - Vector2(face * len, 0), tip, Color(tc, 0.85 * sa), 6.0 * sc, true)
			draw_line(tip - Vector2(face * len, 0), tip, Color(1, 1, 1, 0.95 * sa), 2.5 * sc, true)
			draw_circle(tip, 4.0 * sc * (1.0 - sk), Color(1, 1, 1, sa), true, -1.0, true)



func _star_above(c: Vector2) -> void:
	var r := 6.0 + sin(time * 6.0) * 1.0
	var pts := PackedVector2Array()
	for i in 10:
		var an := -PI / 2 + i * TAU / 10.0
		pts.append(c + Vector2(cos(an), sin(an)) * (r if i % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, Color(1, 0.88, 0.3))



## 第八輪地面層：毒圈、碎石區。淡色，畫在單位底下。
func _draw_v8_ground(s, live: bool) -> void:
	if not live:
		return
	for z in s.zones:
		var c := ORIGIN + Vector2(int(z[0]), int(z[1])) * CS / 1000.0
		var rr: float = float(F8.ROCK_R) * CS / 1000.0
		draw_set_transform_matrix(_cam * Transform2D(0, Vector2(1, 0.55), 0, c))
		draw_circle(Vector2.ZERO, rr, Color(0.55, 0.45, 0.3, 0.22), true, -1.0, true)
		for k in 7:
			var an := k * TAU / 7.0 + 0.4
			var a0 := Vector2(cos(an), sin(an)) * rr * 0.2
			var a1 := Vector2(cos(an + 0.3), sin(an + 0.3)) * rr * 0.62
			var a2 := Vector2(cos(an - 0.1), sin(an - 0.1)) * rr * 0.95
			draw_polyline(PackedVector2Array([a0, a1, a2]), Color(0.42, 0.33, 0.22, 0.8), 2.5, true)
		draw_set_transform_matrix(_cam)
	for u in s.units:
		if u.alive and u.type == F8.SPORE:
			var c2 := _upos(u)
			var r2: float = float(F8.STATS[0]["reach"]) * CS / 1000.0
			draw_set_transform_matrix(_cam * Transform2D(0, Vector2(1, 0.55), 0, c2))
			draw_circle(Vector2.ZERO, r2, Color(Art.team_color(u.team, cbm()), 0.08), true, -1.0, true)
			draw_arc(Vector2.ZERO, r2, 0, TAU, 40, Color(0.6, 0.95, 0.4, 0.35), 1.6, true)
			draw_set_transform_matrix(_cam)
			if not bool(Save.s("reduce_fx")):
				for k2 in 3:
					var ph := fmod(time * 0.5 + k2 * 0.33 + u.id * 0.07, 1.0)
					var an2 := k2 * TAU / 3.0 + time * 0.4
					draw_circle(c2 + Vector2(cos(an2) * r2 * 0.55, sin(an2) * r2 * 0.3 - ph * 26.0), 3.0, Color(0.7, 1.0, 0.45, 0.45 * (1.0 - ph)), true, -1.0, true)


## 第八輪上層：巫毒連線、大招前搖、時停減傷。
func _draw_v8_top(s, u, p: Vector2) -> void:
	if u.type == F8.DOLL and u.link >= 0 and u.link < s.units.size() and s.units[u.link].alive:
		var q := _upos(s.units[u.link])
		var col := Color(1.0, 0.42, 0.7, 0.55 + 0.2 * sin(time * 6.0))
		draw_dashed_line(p + Vector2(0, -26), q + Vector2(0, -26), Color(1.0, 0.7, 0.9, 0.3), 4.5, 7.0)
		draw_dashed_line(p + Vector2(0, -26), q + Vector2(0, -26), col, 2.0, 7.0)
	if u.windup > 0:
		var k := 1.0 - float(u.windup) / F8.WINDUP
		var rc := Color("#ffe08a") if u.type == F8.SPRITE else (Color("#c77dff") if u.type == F8.BONE else (Color("#9ad1ff") if u.type == F8.CAT else Color("#d9c9a3")))
		draw_arc(p + Vector2(0, -24), 26.0, -PI / 2, -PI / 2 + TAU * k, 28, Color(Art.OUT, 0.7), 5.0, true)
		draw_arc(p + Vector2(0, -24), 26.0, -PI / 2, -PI / 2 + TAU * k, 28, rc, 3.0, true)
	if u.guard > 0:
		draw_arc(p + Vector2(0, -24), 20.0, 0, TAU, 24, Color(1.0, 0.88, 0.5, 0.65), 2.5, true)



## 這隻兵附近（60px 內）有幾隻活著的兵，不算自己。
func _crowd_at(u) -> int:
	var n := 0
	var p := _upos(u)
	for v in view.units:
		if v.alive and v.id != u.id and _upos(v).distance_squared_to(p) < 3600.0:
			n += 1
	return n



## 暫停時點一隻兵看狀態（第七輪 A6）。
func _draw_unit_info() -> void:
	if not paused or follow_id < 0 or view == null:
		return
	var u = view.unit_by_id(follow_id)
	if u == null:
		return
	var tname := L.t("ui_none")
	if u.target >= 0 and u.target < view.units.size() and view.units[u.target].alive:
		tname = L.t("unit_%d" % view.units[u.target].type)
	var lines: Array = [
		"%s（%s）" % [L.t("unit_%d" % u.type), L.t("blue") if u.team == 0 else L.t("red")],
		L.t("ui_hp", [u.hp, u.max_hp]),
		L.t("ui_target", [tname]),
		L.t("ui_cd", ["%.1f" % (u.cd / 80.0)]),
		L.t("ui_stats", [u.dmg_dealt, u.kills]),
	]
	var R := Rect2(980, 96, 286, 16 + lines.size() * tz("S") * 1.4)
	draw_rect(R, Color(TH_WOOD_D, 0.94))
	draw_rect(R, Color(Art.team_color(u.team, cbm()), 0.9), false, 2.0)
	for i in lines.size():
		_text(R.position + Vector2(10, 8 + i * tz("S") * 1.4), lines[i], tz("S"), Color.WHITE, false, i == 0, 266)



func _update_action_focus() -> void:
	var sum := Vector2.ZERO
	var n := 0
	for u in view.units:
		if u.alive and ((hurt_t.has(u.id) and time - hurt_t[u.id] < 0.8) or (atk_t.has(u.id) and time - atk_t[u.id] < 0.8)):
			sum += _upos(u)
			n += 1
	action_focus = sum / n if n > 0 else zoom_center



func _draw_field() -> void:
	var free_f: bool = rules != null and rules.is_free() and (mode == Mode.VS_AI or mode == Mode.DUEL)   # 第六輪：自由排兵不畫格子
	var fbi: Dictionary = MapArt.BIOME.get(MapDefs.MAPS[fld_map]["biome"], {})
	if fld_map != 0:
		MapArt.draw_outfield(self, Rect2(ORIGIN, FIELD), str(MapDefs.MAPS[fld_map]["biome"]))
	draw_rect(Rect2(ORIGIN - Vector2(10, 10), fld_size + Vector2(20, 20)), Color(fbi.get("frame", "#5b4632")))
	if fld_map != 0:
		var mt := _map_tex()
		if mt != null:
			draw_texture_rect(mt, Rect2(ORIGIN, fld_size), false)
		else:
			draw_rect(Rect2(ORIGIN, fld_size), Color(fbi.get("base", "#6f9a4a")))
		if rules != null and rules.time_of != 0:
			draw_rect(Rect2(ORIGIN, fld_size), _tone())
		_draw_field_frame()
		return
	var f_rows: int = fld_h / 1000
	var f_cols: int = fld_w / 1000
	for r in f_rows:
		for c in f_cols:
			var cell := Rect2(ORIGIN + Vector2(c, r) * CS, Vector2(CS, CS))
			if grass:
				var h := absi((c * 73856093) ^ (r * 19349663))
				draw_texture_rect_region(grass, cell, Rect2((h % 8) * 32, ((h / 8) % 4) * 32, 32, 32))
			else:
				draw_rect(cell, Color("#7cb342") if (r + c) % 2 == 0 else Color("#73a83d"))
			if free_f:
				pass
			elif c < 6:
				draw_rect(cell, Color(Art.team_color(0, cbm()), 0.08))
			elif c >= 10:
				draw_rect(cell, Color(Art.team_color(1, cbm()), 0.06))
	draw_rect(Rect2(ORIGIN, fld_size), Color(0.06, 0.09, 0.16, 0.18))
	# 地面層次（第三輪 M2）：固定位置的明暗草塊與小花，畫在格線與單位底下
	for i in 22:
		var h := absi((i * 2654435761) ^ 0x5bd1e995) % 100000
		var pc := ORIGIN + Vector2(float(h % 1000) / 1000.0 * fld_size.x, float((h / 1000) % 100) / 100.0 * fld_size.y)
		var rr := 40.0 + float(h % 37) * 2.0
		draw_set_transform_matrix(_cam * Transform2D(0, Vector2(1.0, 0.55), 0, pc))
		draw_circle(Vector2.ZERO, rr, Color(1, 1, 0.8, 0.045) if i % 2 == 0 else Color(0, 0.08, 0, 0.07), true, -1.0, true)
	draw_set_transform_matrix(_cam)
	var fl := [Color("#fff3b0"), Color("#ffb3c6"), Color("#cdb4ff"), Color("#ffffff")]
	# 第七輪 D2：一條踩出來的小路＋石頭群；小花少一點，免得和兵搶眼
	var path_pts := PackedVector2Array()
	for k5 in f_cols + 1:
		path_pts.append(ORIGIN + Vector2(k5 * CS, fld_size.y * 0.5 + sin(k5 * 0.7) * 34.0))
	draw_polyline(path_pts, Color(0.55, 0.42, 0.24, 0.13), 40.0, true)
	draw_polyline(path_pts, Color(0.62, 0.5, 0.3, 0.10), 22.0, true)
	for i3 in 7:
		var h3 := absi((i3 * 92821 + 13) * 689287499) % 1000003
		var rp := ORIGIN + Vector2(float(h3 % 991) / 991.0 * fld_size.x, float((h3 / 991) % 977) / 977.0 * fld_size.y)
		for q2 in 3:
			var rr2 := Vector2(q2 * 7.0 - 7.0, (q2 % 2) * 3.0)
			draw_circle(rp + rr2 + Vector2(0, 1.5), 5.0 - q2 * 0.7, Color(0, 0, 0, 0.18), true, -1.0, true)
			draw_circle(rp + rr2, 5.0 - q2 * 0.7, Color(0.62, 0.62, 0.58, 0.55), true, -1.0, true)
	for i in 20:
		var h2 := absi((i * 40503 + 7) * 2246822519) % 1000003
		var fp := ORIGIN + Vector2(float(h2 % 997) / 997.0 * fld_size.x, float((h2 / 997) % 991) / 991.0 * fld_size.y)
		var fc: Color = fl[i % fl.size()]
		for k in 4:
			var an := k * PI / 2.0 + i
			draw_circle(fp + Vector2(cos(an), sin(an)) * 2.2, 1.8, Color(fc, 0.75), true, -1.0, true)
		draw_circle(fp, 1.3, Color("#f4a300"), true, -1.0, true)
	if not free_f:
		for i in 17:
			draw_line(ORIGIN + Vector2(i * CS, 0), ORIGIN + Vector2(i * CS, fld_size.y), Color(0, 0, 0, 0.07), 1)
		for i in 10:
			draw_line(ORIGIN + Vector2(0, i * CS), ORIGIN + Vector2(fld_size.x, i * CS), Color(0, 0, 0, 0.07), 1)
		draw_dashed_line(ORIGIN + Vector2(6 * CS, 0), ORIGIN + Vector2(6 * CS, fld_size.y), Color(Art.team_color(0, cbm()), 0.75), 3.0, 8.0)
		draw_dashed_line(ORIGIN + Vector2(10 * CS, 0), ORIGIN + Vector2(10 * CS, fld_size.y), Color(Art.team_color(1, cbm()), 0.75), 3.0, 8.0)
	_draw_field_frame()
	# 戰場色調（R6）：一般晨曦、殘局黃昏、遠征月夜。純調色，畫在單位底下，不影響辨識
	var tone := _tone()
	if tone.a > 0.0:
		draw_rect(Rect2(ORIGIN, fld_size), tone)
	if plants.size() >= 9 and fld_sz == MapDefs.STD_SIZE:
		var deco := [[0, Vector2(52, 200)], [3, Vector2(70, 280)], [5, Vector2(30, 400)], [1, Vector2(60, 560)], [7, Vector2(90, 660)],
			[2, Vector2(1220, 190)], [6, Vector2(1240, 300)], [0, Vector2(1215, 470)], [4, Vector2(1245, 600)], [8, Vector2(1200, 676)]]
		for d in deco:
			var tex: Texture2D = plants[d[0]]
			var sz := tex.get_size() * (0.85 if d[0] <= 2 else 1.4)
			draw_texture_rect(tex, Rect2(d[1] - Vector2(sz.x / 2, sz.y), sz), false)



## 木框內側陰影（第七輪 D2）。
func _draw_field_frame() -> void:
	for k6 in 3:
		var sh := Color(0, 0, 0, 0.12 - k6 * 0.035)
		var ii := float(k6 * 3)
		draw_rect(Rect2(ORIGIN + Vector2(ii, ii), Vector2(fld_size.x - ii * 2.0, 3.0)), sh)
		draw_rect(Rect2(ORIGIN + Vector2(ii, ii), Vector2(3.0, fld_size.y - ii * 2.0)), sh)
		draw_rect(Rect2(ORIGIN + Vector2(fld_size.x - ii - 3.0, ii), Vector2(3.0, fld_size.y - ii * 2.0)), sh)
		draw_rect(Rect2(ORIGIN + Vector2(ii, fld_size.y - ii - 3.0), Vector2(fld_size.x - ii * 2.0, 3.0)), sh)

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
	_draw_v8_ground(s, live)
	# 第一層：腳底標記與影子（全部先畫，不會被別人的身體整個蓋住時也看得到外圈）
	var a_now := clampf(accum / 0.05, 0.0, 1.0) if state == St.BATTLE else 1.0
	for u in list:
		var p0: Vector2 = _upos(u) if live else ORIGIN + Vector2(u.x, u.y) * CS / 1000.0
		var air0: float = Gait.air(u.type, _walk_of(u, a_now)) if live else 0.0
		_ring(p0, u.team, u.type, UNIT_SCALE * (1.0 - air0 * 0.018))   # 跳起來影子縮一點
		if live and s.rally[u.team] and not s.finished:
			for k in 2:
				var ph := fmod(time * 1.6 + k * 0.5, 1.0)
				draw_arc(p0, (14.0 + ph * 10.0) * UNIT_SCALE, 0, TAU, 20, Color(1, 0.42, 0.0, 0.55 * (1.0 - ph)), 2.0, true)
	# 陣亡痕跡：倒下處的小旗，3 秒淡出，畫在最底層（第三輪 R5）
	if live:
		for g in graves:
			var ga: float = 1.0 - g["t"] / 3.0
			var gp: Vector2 = g["pos"]
			draw_line(gp + Vector2(0, 2), gp + Vector2(0, -16), Color(0.35, 0.27, 0.2, 0.8 * ga), 2.0, true)
			draw_colored_polygon(PackedVector2Array([gp + Vector2(0, -16), gp + Vector2(10, -12), gp + Vector2(0, -8)]), Color(Art.team_color(g["team"], cbm()), 0.75 * ga))
			draw_set_transform_matrix(_cam * Transform2D(0, Vector2(1, 0.4), 0, gp + Vector2(0, 2)))   # 疊在鏡頭上（Codex S4 #5）
			draw_circle(Vector2.ZERO, 7, Color(0, 0, 0, 0.25 * ga), true, -1.0, true)
			draw_set_transform_matrix(_cam)
	# 擁擠度：40px 內有幾隻（第三輪 V5，只在戰鬥中算）
	var crowd := {}
	if live:
		var pos: Array = []
		for u in list:
			pos.append(_upos(u))
		for a in list.size():
			var n := 0
			for b in list.size():
				if a != b and pos[a].distance_squared_to(pos[b]) < 1600.0:
					n += 1
			crowd[list[a].id] = n
	# 第二層：身體（V9：地圖的前景物件依腳點 y 插進來，才有前後遮擋）
	var prop_i := 0
	for u in list:
		var p: Vector2 = _upos(u) if live else ORIGIN + Vector2(u.x, u.y) * CS / 1000.0
		while prop_i < fld_props.size() and ORIGIN.y + float(fld_props[prop_i][0]) <= p.y:
			MapArt.draw_prop(self, ORIGIN, fld_props[prop_i], time)
			prop_i += 1
		var walk: float = _walk_of(u, a_now) if live else ((time * Gait.nominal_rate(u.type, float(D.stat(u.type)["speed"]), CS, UNIT_SCALE) + u.id) if (u.mx != 0 or u.my != 0) else 0.0)
		var moving: bool = walk > 0.0
		var at := 0.0
		var variant := 0
		if live and atk_hit.has(u.id):
			var dt0 := _disp_tick()
			var h := pick_hit(atk_hit[u.id], dt0, u.type)
			if h >= 0:
				at = atk_progress(dt0 - (h - ViewBuffer.DELAY), u.type)
				# 火罐飛行（第四輪 §4.4）：前搖期間從手上飛向目標，命中那一刻落地（模擬不受影響）
				if u.type == D.BOMBER and at > 0.0 and at < Art.ATK_WINDUP and bomb_tgt.get(u.id, {}).has(h):
					var bt = view.unit_by_id(bomb_tgt[u.id][h])
					if bt != null:
						var fk := at / Art.ATK_WINDUP
						var src_p: Vector2 = _upos(u) + Vector2(0, -50)
						var dst_p: Vector2 = _upos(bt) + Vector2(0, -10)
						var pp := src_p.lerp(dst_p, fk) + Vector2(0, -sin(fk * PI) * minf(70.0, src_p.distance_to(dst_p) * 0.3))
						pot_draw.append(pp)
				if u.type == D.SWORD:
					variant = int(atk_seq.get(u.id, {}).get(h, 0)) % 2   # 劍士橫斬與上挑逐擊交替（第三輪 R4）
				elif u.type >= D.CLASSIC and alt_hit.get(u.id, {}).has(h):
					variant = 2
		var hurt := 0.0
		if live and hurt_t.has(u.id) and _fx_on("flash"):
			hurt = clampf(1.0 - (time - hurt_t[u.id]) / 0.15, 0, 1)
		var alpha := 0.45 if u.stealth > 0 else 1.0
		if dim:
			alpha *= 0.6
		if live:
			alpha *= _focus_dim(p)
		var face := signf(u.fx) if u.fx != 0 else (1.0 if u.team == 0 else -1.0)
		# 受擊後退 4px（第三輪 R2）：0.08 秒退、0.07 秒回，只是畫面
		if live and hurt_t.has(u.id):
			var hk: float = (time - float(hurt_t[u.id])) / 0.15
			if hk >= 0.0 and hk < 1.0:
				p.x += float(hurt_dir.get(u.id, 0.0)) * 4.0 * (sin(hk * PI) if hk < 1.0 else 0.0)
		if live and u.id == follow_id:
			draw_arc(p + Vector2(0, 2), 22.0, 0, TAU, 28, Color(ACCENT, 0.9), 3.0, true)   # 跟拍中的那隻
		# 擠在一起時，正在出手或受擊的那隻加隊伍色光圈（第三輪 V5）
		if live and (at > 0.0 or hurt > 0.0) and crowd.get(u.id, 0) >= 3:
			draw_arc(p + Vector2(0, -24 if u.type != D.CAVALRY else -28), 19.0, 0, TAU, 24, Color(Art.team_color(u.team, cbm()), 0.75 * alpha), 2.0, true)
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
			# 狂熱氣場（第三輪 R3）：身邊橘紅脈衝圈
			var pulse := 0.5 + 0.5 * sin(time * 7.0 + u.id)
			draw_arc(p + Vector2(0, -22), 15.0 + pulse * 3.0, 0, TAU, 20, Color(1.0, 0.33, 0.2, (0.35 + 0.3 * pulse) * alpha), 2.0, true)
		if u.type == D.ASSASSIN and u.stealth > 0:
			mood |= Art.M_HOOD
			crouch = 0.9                     # 潛行蹲身
		if live and brace_t.has(u.id) and time - brace_t[u.id] < 0.35:
			mood |= Art.M_BRACE
		# 勝利：存活的勝方每 0.45 秒原地跳 10px、武器高舉
		var hop := 0.0
		if live and sim != null and u.team == sim.winner and (state == St.RESULT or (state == St.BATTLE and view != null and view.finished)):
			hop = absf(sin((time + u.id * 0.05) * PI / 0.45)) * 10.0
			at = Art.ATK_WINDUP
			lean = Art.LEAN_BACK      # 抵銷前搖的後仰：站直、武器高舉（和前搖分得開，Antigravity S4）
			crouch = 1.06
			_star_above(p + Vector2(0, -hop - (74 if u.type == D.CAVALRY else 66)))
		p.y -= hop
		if u.hidden:
			Art.mimic_closed(self, p, u.team, face, alpha, time, cbm(), UNIT_SCALE)   # 偽裝中的寶箱怪
			continue
		if u.type == F8.GHOST:
			alpha *= 0.9
		# 待機小動作（V9 P2）：重心換腳、偶爾縮一下身子
		if live and walk == 0.0 and at == 0.0:
			lean += sin(time * 1.1 + u.id * 1.7) * 0.018
			var idle_k := fmod(time + u.id * 1.37, 7.3)
			if idle_k < 0.3:
				crouch *= 1.0 - sin(idle_k / 0.3 * PI) * 0.05
		if live:
			face = _face_of(u)
		if u.stealth > 0:
			# 潛行：身後兩道暗紫殘影
			for g in 2:
				var gp := p + Vector2(-(8 + g * 8) * face, 0)
				draw_circle(gp + Vector2(0, -22), 11.0 - g * 2.0, Color(0.3, 0.15, 0.45, 0.22 - g * 0.08), true, -1.0, true)
				_unit(gp, u.type, u.team, face, 0.0, 0.0, 0.0, 0.14 - g * 0.06, time, UNIT_SCALE)
		if live and walk <= Gait.POSE_DAZE + 1.0:
			# 暈眩：頭上轉圈的星星
			for sk0 in 3:
				var sa0 := time * 5.0 + sk0 * TAU / 3.0
				_icon("star", p + Vector2(cos(sa0) * 15.0, -60.0 + sin(sa0) * 5.0), 13.0, Color("#ffd166"))
		_unit(p, u.type, u.team, face, walk, at, hurt, alpha, time, UNIT_SCALE, mood, lean, crouch, variant)
		# 揮擊殘影（第三輪 R1、S4 依兵種分開）
		if live and at >= Art.ATK_WINDUP and at < Art.ATK_STRIKE + 0.12:
			var sk := clampf((at - Art.ATK_WINDUP) / (Art.ATK_STRIKE + 0.12 - Art.ATK_WINDUP), 0.0, 1.0)
			_draw_smear(p, u.type, u.team, face, sk, alpha, variant, 1.0)
		# 衝鋒就緒的金色拖尾（第三輪 R3）
		if u.type == D.CAVALRY and moving and u.charge >= D.CHARGE_NEED:
			var tip := p + Vector2(face * 26.0, -44.0)
			for k in 4:
				var q0 := tip - Vector2(face * k * 8.0, 0)
				var q1 := tip - Vector2(face * (k + 1) * 8.0, 0)
				draw_line(q0, q1, Color(1.0, 0.86, 0.3, (0.8 - k * 0.2) * alpha), 3.0 - k * 0.5, true)
	while prop_i < fld_props.size():
		MapArt.draw_prop(self, ORIGIN, fld_props[prop_i], time)
		prop_i += 1
	for pp in pot_draw:
		draw_circle(pp, 6.5, Art.OUT, true, -1.0, true)
		draw_circle(pp, 5.0, Color("#2a2533"), true, -1.0, true)
		draw_circle(pp + Vector2(3, -5), 2.0, Color(1, 0.8, 0.3), true, -1.0, true)
	pot_draw.clear()
	if dim:
		return
	# 第三層：小旗、血條、狀態（永遠畫在最上面）
	for u in list:
		var p: Vector2 = _upos(u) if live else ORIGIN + Vector2(u.x, u.y) * CS / 1000.0
		if live:
			_draw_v8_top(s, u, p)
		if u.hidden:
			continue   # 偽裝中的寶箱不插小旗、不畫血條
		var fh: int = -58 if u.type == D.CAVALRY else (-70 if u.type == F8.GOLEM or u.type == F8.SPRITE else (-62 if u.type == F8.DOLL else -50))
		Art.flag(self, p + Vector2(-12, fh), u.team, cbm())
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
		if live and "breach" in u and u.breach > 0:
			# 破陣（第四輪 §4.4）：盾面黑色 Z 字裂紋＋血條右邊一個帶黑邊的亮橘裂盾圖示，持續到破陣結束（Antigravity：原本太小看不到）
			var cp := p + Vector2(12 * (signf(u.fx) if u.fx != 0 else 1.0), -26)
			draw_polyline(PackedVector2Array([cp + Vector2(-4, -11), cp + Vector2(2, -4), cp + Vector2(-3, 2), cp + Vector2(3, 10)]), Color(0.08, 0.06, 0.1, 0.95), 3.0, true)
			var ic := p + Vector2(24, -60)
			var lh := PackedVector2Array([ic + Vector2(-8, -9), ic + Vector2(-1, -9), ic + Vector2(-3, 1), ic + Vector2(-1, 9), ic + Vector2(-8, 4)])
			var rh := PackedVector2Array([ic + Vector2(1, -9), ic + Vector2(8, -9), ic + Vector2(8, 4), ic + Vector2(1, 9), ic + Vector2(3, 1)])
			for hp in [lh, rh]:
				var cl: PackedVector2Array = hp.duplicate()
				cl.append(hp[0])
				draw_polyline(cl, Art.OUT, 3.0, true)
				draw_colored_polygon(hp, Color("#ff6a2a"))
		if live and "aura" in u and u.aura > 0 and u.type != D.DRUMMER:
			# 鼓舞：2 顆亮金小菱形沿腳底圈往上飄（不畫大圈，避免畫面太吵；Antigravity：原本的小金點看不到）
			for j in 2:
				var ph := fmod(time * 0.9 + j * 0.5 + u.id * 0.13, 1.0)
				var dp := p + Vector2((-1.0 if j == 0 else 1.0) * 14.0, 2.0 - ph * 22.0)
				var ds := 3.6
				var dpoly := PackedVector2Array([dp + Vector2(0, -ds), dp + Vector2(ds * 0.7, 0), dp + Vector2(0, ds), dp + Vector2(-ds * 0.7, 0)])
				draw_colored_polygon(dpoly, Color(1, 0.86, 0.3, 0.95 * (1.0 - ph)))
		if live and u.type == D.DRUMMER and s.tick < 60 and u.alive:
			# 開戰前 3 秒畫完整的戰鼓範圍
			draw_arc(p, D.DRUM_RANGE * CS / 1000.0, 0, TAU, 40, Color(1, 0.85, 0.35, 0.35), 2.0, true)
		if s.frenzy:
			draw_circle(p + Vector2(8, -58 - sin(time * 12 + u.id) * 2), 3.0, Color(1, 0.5, 0.1, 0.9), true, -1.0, true)
		# 第七輪 D1：血條只在需要看時才畫（受傷 3 秒內、跟拍、低血量）
		var hurt_recent: bool = hurt_t.has(u.id) and time - float(hurt_t[u.id]) < 3.0
		if u.hp < u.max_hp and (not live or hurt_recent or u.id == follow_id or u.hp * 100 <= u.max_hp * 35):
			var w := 28.0
			var top := p + Vector2(-w / 2, -66 if u.type == D.CAVALRY else (-76 if u.type == F8.GOLEM or u.type == F8.SPRITE else -58))
			draw_rect(Rect2(top - Vector2(1, 1), Vector2(w + 2, 6)), Art.OUT)
			draw_rect(Rect2(top, Vector2(w * u.hp / u.max_hp, 4)), Art.team_color(u.team, cbm()).lightened(0.25))
			if cbm():
				# 色盲模式：血條左邊加隊伍形狀（藍＝●、紅＝◆），不只靠顏色（R8）
				var mk := top + Vector2(-8, 2)   # 8px 標記＋黑邊（第三輪 V5）
				if u.team == 0:
					draw_circle(mk, 5.5, Art.OUT, true, -1.0, true)
					draw_circle(mk, 4.0, Art.team_color(0, true), true, -1.0, true)
				else:
					draw_colored_polygon(PackedVector2Array([mk + Vector2(0, -6.5), mk + Vector2(6.5, 0), mk + Vector2(0, 6.5), mk + Vector2(-6.5, 0)]), Art.OUT)
					draw_colored_polygon(PackedVector2Array([mk + Vector2(0, -4.5), mk + Vector2(4.5, 0), mk + Vector2(0, 4.5), mk + Vector2(-4.5, 0)]), Art.team_color(1, true))
	if not live:
		return
	for g in dying:
		var k: float = g["t"] / 1.0
		_draw_death(g, k)
		if k < 0.3:
			for i in 6:
				var ang := i * TAU / 6
				draw_circle(g["pos"] + Vector2(cos(ang), sin(ang) * 0.5) * (8 + k * 70) + Vector2(0, -16), 4 * (1 - k), Color(1, 1, 1, 0.35), true, -1.0, true)
		Art.soul(self, g["pos"] + Vector2(sin(k * 9) * 4, -24 - k * 70), 0.75 * (1.0 - k))

## V9 P2：每種兵的死法。k＝0～1（1 秒）。只用轉換與粒子，不多烘影格。
func _draw_death(g: Dictionary, k: float) -> void:
	var t: int = g["type"]
	var p: Vector2 = g["pos"]
	var face: float = g["face"]
	var u := minf(k / 0.55, 1.0)         # 倒下的主要段落
	var e := 1.0 - (1.0 - u) * (1.0 - u)
	var al := 1.0 - maxf(0.0, (k - 0.45) / 0.3)
	if al <= 0.0:
		return
	var lean := 0.0
	var crouch := 1.0
	var hurt := maxf(0.0, 0.8 - k * 3.0)
	match t:
		D.CAVALRY:
			lean = e * 1.45          # 連人帶馬往前翻
		D.BERSERKER, D.PIKE:
			lean = -e * 1.5          # 仰天倒下
		D.SHIELD, D.SWORD, D.DRUMMER:
			lean = e * 1.2           # 往前跪倒
			crouch = 1.0 - e * 0.25
		D.ARCHER, D.BOMBER, D.MEDIC:
			crouch = 1.0 - e * 0.45  # 坐倒
			lean = -e * 0.35
		D.ASSASSIN:
			al *= 1.0 - u * 0.8      # 化煙
			for i in 5:
				var a0 := i * TAU / 5.0 + k * 2.0
				draw_circle(p + Vector2(cos(a0) * (6 + k * 30), -20 - k * 24 + sin(a0) * 6), 7.0 * (1.0 - k), Color(0.25, 0.2, 0.35, 0.5 * (1.0 - k)), true, -1.0, true)
		10:
			crouch = 1.0 - e * 0.7   # 孢子菇癟掉
		11:
			al *= 1.0 - u            # 羊：羊毛飛散
			for i in 7:
				var a1 := i * TAU / 7.0
				draw_circle(p + Vector2(cos(a1), sin(a1) * 0.6 - 0.8) * (8 + k * 46), 6.0 * (1.0 - k), Color(Art.team_color(g["team"], cbm()).lightened(0.3), 0.8 * (1.0 - k)), true, -1.0, true)
		12:
			lean = e * 0.5           # 箱子翻倒，鉚釘掉落
			for i in 4:
				draw_circle(p + Vector2((i - 1.5) * (6 + k * 14), -14 + k * k * 14), 1.8, Color(Art.GOLD, 1.0 - k), true, -1.0, true)
		13, 20:
			crouch = 1.0 - e * 0.8   # 史萊姆化開成一灘
			draw_set_transform_matrix(_cam * Transform2D(0, Vector2(1, 0.4), 0, p))
			draw_circle(Vector2.ZERO, 8.0 + e * 16.0, Color(Art.team_color(g["team"], cbm()), 0.45 * (1.0 - k)), true, -1.0, true)
			draw_set_transform_matrix(_cam)
		14:
			p += Vector2(0, -e * 34.0)   # 幽靈往上消散
			al *= 1.0 - u * 0.7
		16, 17, 21, 15:
			crouch = 1.0 - e * 0.5   # 散開：骨頭、沙粒、布屑往外
			var col := Color("#ece6d6") if t != 16 and t != 15 else (Color("#ffd166") if t == 16 else Color("#e8d3a8"))
			for i in 6:
				var a2 := i * TAU / 6.0 + float(g.get("seed", 0.0))
				var r2 := 8.0 + e * 26.0
				draw_circle(p + Vector2(cos(a2) * r2, -18.0 + sin(a2) * r2 * 0.5 + k * k * 22.0), 3.0 * (1.0 - k * 0.6), Color(col, 1.0 - k), true, -1.0, true)
		18:
			lean = -e * 0.9          # 吸塵貓往後坐倒
		19:
			crouch = 1.0 - e * 0.55  # 石魔碎裂
			for i in 8:
				var a3 := i * TAU / 8.0
				var r3 := 10.0 + e * 34.0
				draw_circle(p + Vector2(cos(a3) * r3, -14.0 + sin(a3) * r3 * 0.45 + k * k * 24.0), 5.0 * (1.0 - k * 0.5), Color(Color("#8d8a80"), 1.0 - k), true, -1.0, true)
	_unit(p, t, g["team"], face, 0.0, 0.0, hurt, al, time, UNIT_SCALE, 1 if k < 0.4 else 0, lean, maxf(crouch, 0.15))

