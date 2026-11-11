extends "res://scripts/ui/battle/battle_fx.gd"
## 由 battle_view.gd 拆出（V9 P1，行為不變）

## 時間軸標記（首次衝鋒／背刺／頂住，每隊各一次）：正常播放與重播跳轉共用（Codex S5 #4）。
## 頂住的 src 是被頂住的騎兵，功勞算盾兵那一隊。
func _collect_mark(ev: Dictionary, lookup, tick: int) -> void:
	var k: String = ev["kind"]
	# V1.1 B1：逐 tick 累計「誰打了哪一隊多少血」（快轉、正常播放共用這裡）。只看相關，不宣稱因果
	if ev.has("dmg") and ev.has("src") and ev.has("tgt"):
		var su = lookup.unit_by_id(ev["src"])
		var tu = lookup.unit_by_id(ev["tgt"])
		if su != null and tu != null and su.team != tu.team:
			var dk := "dmgby%d_%d" % [tu.team, su.type]
			ev_count[dk] = int(ev_count.get(dk, 0)) + int(ev["dmg"])
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
	# V1.1 A3：大招前搖的地面預警圈（實際作用半徑），前搖 1 秒內由內往外長滿
	for u in s.units:
		if not u.alive or u.windup <= 0:
			continue
		var wk := clampf(1.0 - float(u.windup) / F8.WINDUP, 0.0, 1.0)
		var rad: int = {F8.GOLEM: F8.GOLEM_R, F8.CAT: F8.CAT_R, F8.SPRITE: F8.SPRITE_R}.get(u.type, 0)
		if rad <= 0:
			continue
		var tc: Color = {F8.GOLEM: Color("#ff8a3c"), F8.CAT: Color("#9ad1ff"), F8.SPRITE: Color("#ffe08a")}[u.type]
		var rp: float = float(rad) * CS / 1000.0
		draw_set_transform_matrix(_cam * Transform2D(0, Vector2(1, 0.55), 0, _upos(u)))
		draw_circle(Vector2.ZERO, rp * wk, Color(tc, 0.14 + 0.1 * wk), true, -1.0, true)
		_hand_ring(Vector2.ZERO, rp, Color(tc, 0.35 + 0.4 * wk), 2.5)
		if u.type == F8.CAT:
			for k3 in 6:   # 吸氣線：從外圈往貓身上收
				var an3 := k3 * TAU / 6.0 + time * 1.5
				var ph3 := fmod(time * 1.6 + k3 * 0.17, 1.0)
				var r0 := rp * (1.0 - ph3 * 0.7)
				draw_line(Vector2(cos(an3), sin(an3)) * r0, Vector2(cos(an3), sin(an3)) * (r0 - 14.0), Color(tc, 0.7 * (1.0 - ph3)), 2.0, true)
		draw_set_transform_matrix(_cam)
	for u in s.units:
		if u.alive and u.type == F8.SPORE:
			var c2 := _upos(u)
			var r2: float = float(F8.STATS[0]["reach"]) * CS / 1000.0
			draw_set_transform_matrix(_cam * Transform2D(0, Vector2(1, 0.55), 0, c2))
			draw_circle(Vector2.ZERO, r2, Color(Art.team_color(u.team, cbm()), 0.08), true, -1.0, true)
			_hand_ring(Vector2.ZERO, r2, Color(0.6, 0.95, 0.4, 0.35), 1.6)
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
		_chalk_line(p + Vector2(0, -26), q + Vector2(0, -26), Color(1.0, 0.7, 0.9, 0.3), 4.5, 7.0)
		_chalk_line(p + Vector2(0, -26), q + Vector2(0, -26), col, 2.0, 7.0)
	if u.windup > 0:
		var k := 1.0 - float(u.windup) / F8.WINDUP
		var rc := Color("#ffe08a") if u.type == F8.SPRITE else (Color("#c77dff") if u.type == F8.BONE else (Color("#9ad1ff") if u.type == F8.CAT else Color("#d9c9a3")))
		draw_arc(p + Vector2(0, -24), 26.0, -PI / 2, -PI / 2 + TAU * k, 28, Color(Art.OUT, 0.7), 5.0, true)
		draw_arc(p + Vector2(0, -24), 26.0, -PI / 2, -PI / 2 + TAU * k, 28, rc, 3.0, true)
	if u.guard > 0:
		_hand_ring(p + Vector2(0, -24), 20.0, Color(1.0, 0.88, 0.5, 0.65), 2.5)



## V1.1 C5：0.8 格密陣時下排的頭會蓋到上排的臉。被蓋到的那隻（正下方 30px 內有另一隻）在最上面補畫一層 35% 透明的自己。
## 純畫面；不改排序（y 排序照舊），所以前後關係還是對的，只是臉看得到。
func _draw_xray(items: Array) -> void:
	if items.size() < 2:
		return
	for i in items.size():
		var pa: Vector2 = items[i][0]
		var hid := false
		for j in items.size():
			if j == i:
				continue
			var pb: Vector2 = items[j][0]
			if pb.y > pa.y and pb.y - pa.y < 30.0 * UNIT_SCALE and absf(pb.x - pa.x) < 20.0 * UNIT_SCALE:
				hid = true
				break
		if hid:
			var a: Array = items[i][1]
			_unit(pa, int(a[0]), int(a[1]), float(a[2]), float(a[3]), float(a[4]), 0.0, float(a[5]) * 0.35, time, UNIT_SCALE, 0, float(a[6]), float(a[7]), int(a[8]))
			# 1.1.0 B4／A18：被蓋住的兵，只有游標停在它身上時才描一圈淡粉筆輪廓（常駐會在 800p 糊成雜訊；不移錨點、不改點擊判定）
			var mp: Vector2 = _cam.affine_inverse() * mouse   # 游標換成場地座標（和兵同一個座標系）
			if not bool(Save.s("reduce_fx")) and mp.distance_to(pa + Vector2(0, -22.0 * UNIT_SCALE)) < 18.0 * UNIT_SCALE:
				_hand_ring(pa + Vector2(0, -22.0 * UNIT_SCALE), 16.0 * UNIT_SCALE, Color(1.0, 0.97, 0.88, 0.75), 1.5)

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
	ring_shadow = float(fbi.get("shadow", 0.0))
	# 1.2.0 §5.1：盤外是桌面（不再畫場外樹叢、岩石）
	if not bool(Save.s("plain_ui")):
		var so := Rect2(ORIGIN, fld_size).grow(18)
		for k7 in 4:   # 1.2.0 §5.1：棋盤在桌上的落影（光源左上 → 影子往右下）
			draw_rect(Rect2(so.position + Vector2(6 + k7 * 2, 8 + k7 * 2), so.size), Color(0.08, 0.05, 0.03, 0.12))
	var fr_i := clampi(int(Art.paint[5]), 0, 3)   # V1.4 #15 棋盤框
	draw_rect(Rect2(ORIGIN - Vector2(10, 10), fld_size + Vector2(20, 20)), Color(fbi.get("frame", "#5b4632") if fr_i == 0 else Art.FRAMES[fr_i]))
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
		# 1.2.0 §5.1：格線是刻刀刻出的淺凹槽：暗線＋右／下方 1px 亮線（不是印上去的虛線）
		var carve := not bool(Save.s("plain_ui"))
		for i in 17:
			_wob_line(ORIGIN + Vector2(i * CS, 0), ORIGIN + Vector2(i * CS, fld_size.y), Color(0.12, 0.07, 0.03, 0.12 if carve else 0.07), 1.0)
			if carve:
				draw_line(ORIGIN + Vector2(i * CS + 1, 0), ORIGIN + Vector2(i * CS + 1, fld_size.y), Color(1, 0.95, 0.8, 0.07), 1.0)
		for i in 10:
			_wob_line(ORIGIN + Vector2(0, i * CS), ORIGIN + Vector2(fld_size.x, i * CS), Color(0.12, 0.07, 0.03, 0.12 if carve else 0.07), 1.0)
			if carve:
				draw_line(ORIGIN + Vector2(0, i * CS + 1), ORIGIN + Vector2(fld_size.x, i * CS + 1), Color(1, 0.95, 0.8, 0.07), 1.0)
		_chalk_line(ORIGIN + Vector2(6 * CS, 0), ORIGIN + Vector2(6 * CS, fld_size.y), Color(Art.team_color(0, cbm()), 0.75), 3.0, 8.0)
		_chalk_line(ORIGIN + Vector2(10 * CS, 0), ORIGIN + Vector2(10 * CS, fld_size.y), Color(Art.team_color(1, cbm()), 0.75), 3.0, 8.0)
	_draw_field_frame()
	# 戰場色調（R6）：一般晨曦、殘局黃昏、遠征月夜。純調色，畫在單位底下，不影響辨識
	var tone := _tone()
	if tone.a > 0.0:
		draw_rect(Rect2(ORIGIN, fld_size), tone)
	if false and plants.size() >= 9 and fld_sz == MapDefs.STD_SIZE:   # 1.2.0 §5.1：棋盤兩側的一圈樹拿掉（盤外是桌面）
		var deco := [[0, Vector2(52, 200)], [3, Vector2(70, 280)], [5, Vector2(30, 400)], [1, Vector2(60, 560)], [7, Vector2(90, 660)],
			[2, Vector2(1220, 190)], [6, Vector2(1240, 300)], [0, Vector2(1215, 470)], [4, Vector2(1245, 600)], [8, Vector2(1200, 676)]]
		for d in deco:
			var tex: Texture2D = plants[d[0]]
			var sz := tex.get_size() * (0.85 if d[0] <= 2 else 1.4)
			draw_texture_rect(tex, Rect2(d[1] - Vector2(sz.x / 2, sz.y), sz), false)



## 1.2.0 第 6 大類 E §5.4：雙橋河谷的雨（盤上 20 顆水珠反光，畫在單位之下，不遮單位）。只改畫面。
## 晨昏色調用原本的戰場色調（R6：一般晨曦、殘局黃昏、遠征月夜，`_tone()`），雪與落葉用原本的 `_draw_ambient()`，這裡不重複（Codex cat06 #1 #2）。
## 位置只由地圖決定（重播、跳轉一致，Codex cat06 #3）；閃爍用畫面時間。截圖、減少特效、簡化介面、色盲、4 倍速以上不畫。
func _draw_tod_weather() -> void:
	if shot_dir != "" or layout_probe or bool(Save.s("reduce_fx")) or bool(Save.s("plain_ui")) or cbm() or speed >= 4.0:
		return
	if MapDefs.MAPS.size() <= fld_map or str(MapDefs.MAPS[fld_map]["biome"]) != "river":
		return
	var fr := Rect2(ORIGIN, fld_size)
	for i in 20:
		var qx := fr.position.x + fr.size.x * float((i * 6151 + 17) % 1000) / 1000.0
		var qy := fr.position.y + fr.size.y * float((i * 3571 + 91) % 1000) / 1000.0
		var gl := 0.5 + 0.5 * sin(time * 2.0 + i * 1.7)
		draw_circle(Vector2(qx, qy), 1.6, Color(0.85, 0.95, 1.0, 0.25 + 0.35 * gl), true, -1.0, true)

## 木框內側陰影（第七輪 D2）。
func _draw_field_frame() -> void:
	# V1.2 D3：場地底紋（亞麻布紋，約 6%），跟著場地（在鏡頭座標裡畫），不是貼在螢幕上
	var gr := _ui_tex(TEX_PAPER)
	if gr != null and not bool(Save.s("plain_ui")) and (fld_map == 0 or _map_tex() == null):   # 地形圖的紙紋已烘進地塊（map_art._decor）
		# 一次平鋪（節點開了 texture_repeat），每幀一個繪製呼叫（Codex v120-impl2：原本每格一次）
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		draw_texture_rect(gr, Rect2(ORIGIN, fld_size), true, Color(0.5, 0.42, 0.32, 0.07))
	_draw_ambient()
	_draw_tod_weather()   # 1.2.0 第 6 大類：晨昏色調與天氣（盤面上、單位之下）
	# V1.2 C4：戰場外圍木製沙盤框（九宮格、四角銅釘），蓋在原本的平塗邊上
	var fx := _ui_tex(TEX_FRAME)
	if not bool(Save.s("plain_ui")) and _board_ring(Rect2(ORIGIN, fld_size)):
		fx = null   # 1.2.0 §5.1：實木厚框取代舊框圖
	if fx != null and not bool(Save.s("plain_ui")):
		var sb: StyleBoxTexture = _sb_cache.get("field_frame")
		if sb == null:
			sb = StyleBoxTexture.new()
			sb.texture = fx
			for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
				sb.set_texture_margin(side, 22.0)
			sb.draw_center = false
			_sb_cache["field_frame"] = sb
		draw_style_box(sb, Rect2(ORIGIN, fld_size).grow(14))
	for k6 in 4:   # V1.2：沙盤內緣落影加深（草地像陷在木框裡）
		var sh := Color(0, 0, 0, 0.2 - k6 * 0.045)
		var ii := float(k6 * 2)
		draw_rect(Rect2(ORIGIN + Vector2(ii, ii), Vector2(fld_size.x - ii * 2.0, 3.0)), sh)
		draw_rect(Rect2(ORIGIN + Vector2(ii, ii), Vector2(3.0, fld_size.y - ii * 2.0)), sh)
		draw_rect(Rect2(ORIGIN + Vector2(fld_size.x - ii - 3.0, ii), Vector2(3.0, fld_size.y - ii * 2.0)), sh)
		draw_rect(Rect2(ORIGIN + Vector2(ii, fld_size.y - ii - 3.0), Vector2(fld_size.x - ii * 2.0, 3.0)), sh)
	_draw_map_events()

## 1.2.0 §9.1 開場三段落子（只改畫面）：開戰提示那 1 秒裡，前、中、後排（離中線由近到遠）分三段從上方落下，觸盤時壓扁回彈。
## 重播、減少特效、截圖都沒有這 1 秒（start_hold＝0），所以不影響。
const DROP_AT := [0.0, 0.3, 0.6]
func _open_drop(u) -> Vector2:
	if start_hold <= 0.0 or play_kind != "official":
		return Vector2.ZERO
	var mid := fld_w / 2.0
	var d: float = absf(float(u.x) - mid) / maxf(1.0, mid)
	var stage := 0 if d < 0.25 else (1 if d < 0.5 else 2)
	var ph := 1.0 - clampf(start_hold, 0.0, 1.0)
	var k := clampf((ph - DROP_AT[stage]) / 0.25, 0.0, 1.0)
	return Vector2(0, -22.0 * (1.0 - k) * (1.0 - k))

## 1.2.0 第 5 大類 C §7.2 定格表演層：待機、歡呼的姿勢每 1/12 秒才換（24fps 一拍二）；移動、攻擊、命中照常 60Hz。
## 設定「平滑動作」開了就不量化。
static func _pose_t(t: float) -> float:
	if bool(Save.s("smooth_pose")):
		return t
	return floorf(t * 12.0) / 12.0

## 1.2.0 第 5 大類 A2：受擊後的不倒翁搖：hurt 從 1 掉到 0 的過程擺盪約 1.5 次、幅度隨 hurt 衰減；hurt＝0 時為 0（解析式，不存狀態）。
static func _tumbler(hurt: float) -> float:
	return 0.07 * sin((1.0 - hurt) * TAU * 1.5) * hurt

## 1.2.0 第 5 大類 A1：落子觸盤後 0.15 秒縱向壓扁再彈回（和那一段的「咚」同步）；回傳 crouch 乘數。
func _open_squash(u) -> float:
	if start_hold <= 0.0 or play_kind != "official":
		return 1.0
	var mid := fld_w / 2.0
	var d: float = absf(float(u.x) - mid) / maxf(1.0, mid)
	var stage := 0 if d < 0.25 else (1 if d < 0.5 else 2)
	var ph := 1.0 - clampf(start_hold, 0.0, 1.0)
	var land: float = ph - float(DROP_AT[stage]) - 0.25
	if land < 0.0 or land > 0.15:
		return 1.0
	return 1.0 - 0.18 * sin(land / 0.15 * PI)

## 1.2.0 §5.1 拼花棋盤：橡木厚框（只畫一圈，不蓋盤面）＋內緣刻線＋外緣亮邊＋盤面上漆光（左上亮、右下暗）。回傳有沒有畫。
func _board_ring(inner: Rect2) -> bool:
	var oak := _ui_tex(MAT_OAK)
	if oak == null:
		return false
	var outer := inner.grow(18)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	for strip in [Rect2(outer.position, Vector2(outer.size.x, 18)), Rect2(Vector2(outer.position.x, inner.end.y), Vector2(outer.size.x, 18)),
			Rect2(Vector2(outer.position.x, inner.position.y), Vector2(18, inner.size.y)), Rect2(Vector2(inner.end.x, inner.position.y), Vector2(18, inner.size.y))]:
		draw_texture_rect(oak, strip, true, Color(0.95, 0.88, 0.8))
	draw_rect(outer, Color("#2a1a10"), false, 2.0)                       # 外緣暗線
	draw_rect(outer.grow(-2), Color(1, 0.9, 0.7, 0.28), false, 1.0)      # 外緣亮邊（倒角）
	draw_rect(inner.grow(3), Color("#3a2414"), false, 3.0)               # 內緣刻線
	draw_rect(inner.grow(1), Color(1, 0.92, 0.75, 0.22), false, 1.0)
	# 盤面上漆光：左上亮、右下暗（大漸層，貼在盤面上）
	draw_polygon(PackedVector2Array([inner.position, Vector2(inner.end.x, inner.position.y), Vector2(inner.position.x, inner.end.y)]),
		PackedColorArray([Color(1, 0.95, 0.8, 0.10), Color(1, 0.95, 0.8, 0.0), Color(1, 0.95, 0.8, 0.0)]))
	draw_polygon(PackedVector2Array([inner.end, Vector2(inner.end.x, inner.position.y), Vector2(inner.position.x, inner.end.y)]),
		PackedColorArray([Color(0.1, 0.06, 0.03, 0.16), Color(0.1, 0.06, 0.03, 0.0), Color(0.1, 0.06, 0.03, 0.0)]))
	# 1.2.0 §5.1 盤緣刻字：下緣中央凹刻地圖名（暗字＋下方 1px 亮線）。純裝飾、不經探針（地圖名在大廳與 HUD 另有）；
	# 字級用表裡的 C，放不進 18px 木框（125%／150%）就不刻
	var fs := tz("C")
	if fs <= 16 and MapDefs.MAPS.size() > fld_map:
		var nm := L.t("map_" + str(MapDefs.MAPS[fld_map]["key"]))
		var fw := font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var bp := Vector2(inner.get_center().x - fw / 2.0, inner.end.y + 9 + fs * 0.36)
		draw_string(font, bp + Vector2(0, -1), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.1, 0.05, 0.02, 0.85))   # 凹槽上緣內陰影
		draw_string(font, bp, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#d4a843"))   # 填金（Antigravity cat06：原本暗字看不清）
	return true

const MAT_OAK := "res://art/mat/tile_oak.png"

## V1.4 #10 沙盤機關：畫在沙盤上。還沒發動＝虛線框＋倒數秒數；崩塌後＝碎石；火牆燒時＝火焰；推進板＝木板＋往中線的箭頭。
func _draw_map_events() -> void:
	var ev: Array = MapDefs.events(fld_map)
	if ev.is_empty():
		return
	var tk: float = _disp_tick() if (state == St.BATTLE or state == St.RESULT) else 0.0
	for e in ev:
		var rc: Array = e["r"]
		var t0 := int(e["t"])
		for side in 2:
			var x0: float = float(rc[0]) * fld_size.x / 2.0 / 1000.0
			var x1: float = float(rc[2]) * fld_size.x / 2.0 / 1000.0
			if side == 1:
				var a := fld_size.x - x1
				x1 = fld_size.x - x0
				x0 = a
			var R := Rect2(ORIGIN + Vector2(x0, float(rc[1]) * fld_size.y / 1000.0), Vector2(x1 - x0, float(rc[3] - rc[1]) * fld_size.y / 1000.0))
			match str(e["k"]):
				"collapse":
					if tk >= t0:
						# 碎石：深色底＋幾顆石頭（位置只看格子編號，固定）
						draw_rect(R, Color(0.24, 0.19, 0.15, 0.92))
						for k in 7:
							var sp := R.position + Vector2(fposmod(k * 37.0 + side * 11.0, maxf(1.0, R.size.x - 12.0)) + 6.0, fposmod(k * 23.0 + 5.0, maxf(1.0, R.size.y - 12.0)) + 6.0)
							draw_circle(sp, 5.0 + (k % 3) * 2.0, Color(0.42, 0.35, 0.28), true, -1.0, true)
							draw_circle(sp - Vector2(1.5, 1.5), 2.0, Color(0.6, 0.52, 0.42, 0.7), true, -1.0, true)
					else:
						_ev_warn(R, t0, tk, Color("#e0a030"))   # 機關預警統一琥珀色
				"fire":
					var t1 := t0 + int(e["d"])
					if tk >= t0 and tk <= t1:
						var fl := 0.55 + 0.25 * sin(time * 14.0 + side)
						draw_rect(R, Color(0.95, 0.42, 0.12, 0.38 * fl))
						for k in int(R.size.y / 18.0):
							var fp := R.position + Vector2(R.size.x * (0.2 + 0.6 * fposmod(k * 0.37, 1.0)), 10.0 + k * 18.0)
							draw_colored_polygon(PackedVector2Array([fp + Vector2(-6, 6), fp + Vector2(0, -10 - 4 * sin(time * 9.0 + k)), fp + Vector2(6, 6)]), Color(1.0, 0.7, 0.2, 0.75))
					elif tk < t1:
						_ev_warn(R, t0, tk, Color("#e0a030"))
				"push":
					var hot := tk >= t0 and tk < t0 + 12
					draw_rect(R.grow(-4), Color(0.55, 0.4, 0.24, 0.55 if not hot else 0.85))
					for k in 3:
						var ay := R.position.y + R.size.y * (0.25 + k * 0.25)
						var ax := R.get_center().x
						var d := 1.0 if side == 0 else -1.0
						draw_colored_polygon(PackedVector2Array([Vector2(ax - 8 * d, ay - 7), Vector2(ax + 8 * d, ay), Vector2(ax - 8 * d, ay + 7)]), Color(0.98, 0.9, 0.7, 0.8))
					if tk < t0:
						_ev_warn(R, t0, tk, Color("#6b4a2b"), false)

## 機關還沒發動：虛線框＋「第 N 秒」小牌（戰鬥中改成倒數）。
func _ev_warn(R: Rect2, t0: int, tk: float, col: Color, outline := true) -> void:
	if outline:
		var pts := [R.position, Vector2(R.end.x, R.position.y), R.end, Vector2(R.position.x, R.end.y), R.position]
		for k in 4:
			var a: Vector2 = pts[k]
			var b: Vector2 = pts[k + 1]
			var segs := int(a.distance_to(b) / 10.0)
			for s2 in segs:
				if s2 % 2 == 0:
					draw_line(a.lerp(b, float(s2) / segs), a.lerp(b, float(s2 + 1) / segs), Color(col, 0.85), 2.0, true)
	var left := (t0 - tk) / 20.0
	var lab := ("%ds" % int(ceil(left))) if tk > 0.0 else ("%ds" % (t0 / 20))
	var c := R.get_center()
	draw_circle(c, 15.0, Color(0.98, 0.94, 0.84, 0.92), true, -1.0, true)
	draw_arc(c, 15.0, 0, TAU, 24, col, 2.0, true)
	_text(c - Vector2(0, tz("C") * 0.68), lab, tz("C"), Color(0.25, 0.15, 0.08), true, true, 40)
## V1.2 F3：環境動態（確定性：只看時間與編號，不進模擬）。草地／林間落葉、冰原落雪、熔岩火星；簡化特效時不畫。
func _draw_ambient() -> void:
	if bool(Save.s("reduce_fx")) or bool(Save.s("plain_ui")):
		return
	var biome := str(MapDefs.MAPS[fld_map]["biome"]) if fld_map < MapDefs.MAPS.size() else "grass"
	var n := 14
	for i in n:
		var seed := float(i) * 12.9898
		var ph := fposmod(time * (0.05 + fposmod(seed, 0.04)) + fposmod(seed * 3.7, 1.0), 1.0)
		var x := fposmod(seed * 97.3 + sin(time * 0.6 + seed) * 18.0, fld_size.x)
		match biome:
			"ice":
				var p := ORIGIN + Vector2(x + ph * 40.0, ph * fld_size.y)
				draw_circle(p, 1.6 + fposmod(seed, 1.2), Color(1, 1, 1, 0.55 * sin(ph * PI)), true, -1.0, true)
			"lava":
				var p2 := ORIGIN + Vector2(x, fld_size.y * (1.0 - ph))
				draw_circle(p2, 1.4, Color(1.0, 0.55 + 0.3 * fposmod(seed, 1.0), 0.15, 0.7 * sin(ph * PI)), true, -1.0, true)
			_:
				if i % 2 == 0:
					var p3 := ORIGIN + Vector2(x + sin(time * 1.3 + seed) * 10.0, ph * fld_size.y)
					var rot := time * 2.0 + seed
					var d := Vector2(cos(rot), sin(rot)) * 3.0
					draw_line(p3 - d, p3 + d, Color(0.55, 0.62, 0.25, 0.5 * sin(ph * PI)), 2.4, true)

## 第十三輪：護送＝金色雙圈，斬首＝紅色準星。
func _goal_marker(p: Vector2, kind: String) -> void:
	var pulse := 0.5 + 0.5 * sin(time * 4.0)
	if kind == "protect":
		var c := Color(1.0, 0.82, 0.3, 0.75 + 0.25 * pulse)
		_hand_ring(p, 22.0 * UNIT_SCALE, c, 3.0)
		_hand_ring(p, 27.0 * UNIT_SCALE, Color(c, 0.45), 2.0)
	else:
		var c2 := Color(1.0, 0.3, 0.25, 0.8 + 0.2 * pulse)
		var r := 24.0 * UNIT_SCALE
		var q := p + Vector2(0, -22) * UNIT_SCALE
		_hand_ring(q, r, c2, 2.5)
		for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			draw_line(q + d * r * 0.55, q + d * r * 1.3, c2, 2.5, true)

func _draw_units_of(s, dim: bool) -> void:
	var list: Array = []
	for u in s.units:
		if u.alive:
			list.append(u)
	var live: bool = s == view
	var rfx := bool(Save.s("reduce_fx"))
	# V1.3.1 P2：大落後（戰力 <25%）的那一方，沒事做的兵表情沉下來（每幀每隊只算一次）
	var grim := [false, false]
	if live and not s.finished:
		# 展示快照沒有戰力函式（Codex v131-impl1）：用存活比例，而且要對方明顯比較多才算落後
		var cnt := [0, 0]
		var liv := [0, 0]
		for su in s.units:
			if su.summon:
				continue
			cnt[su.team] += 1
			if su.alive:
				liv[su.team] += 1
		for gt in 2:
			var mine := float(liv[gt]) / maxf(1.0, cnt[gt])
			var theirs := float(liv[1 - gt]) / maxf(1.0, cnt[1 - gt])
			grim[gt] = mine < 0.25 and theirs > mine * 2.0
	# V1.3 P0-1：這一幀的畫面位置只算一次（排序比較器原本每次比較都重算 _upos）
	var pc := {}
	if live:
		for u in list:
			pc[u.id] = _upos(u) + _open_drop(u)
		list.sort_custom(func(a, b): return pc[a.id].y < pc[b.id].y)
	else:
		list.sort_custom(func(a, b): return a.y < b.y)
	_draw_v8_ground(s, live)
	# 第一層：腳底標記與影子（全部先畫，不會被別人的身體整個蓋住時也看得到外圈）
	var a_now := clampf(accum / 0.05, 0.0, 1.0) if state == St.BATTLE else 1.0
	var gm: Array = _goal_mark()
	if live and tm_ghost != null and play_kind == "review":
		# V1.4 #1 時光機：原本那條時間線的兵畫成地上的淡圈（隊伍色點＋白圈），看得出兩條時間線從哪裡分開
		for gu in tm_ghost.units:
			if not gu.alive:
				continue
			var gq: Vector2 = ORIGIN + Vector2(gu.x, gu.y) * CS / 1000.0
			# 粉筆虛線圈（米白、45%），不是 RTS 選取框（Antigravity v140-i1）
			draw_set_transform_matrix(_cam * Transform2D(0, Vector2(1, 0.5), 0, gq))
			var rr := 15.0 * UNIT_SCALE
			for sgm in 8:
				var a0 := sgm * TAU / 8.0 + float(gu.id % 5) * 0.2
				draw_arc(Vector2.ZERO, rr, a0, a0 + TAU / 14.0, 4, Color("#e8dcc4", 0.45), 2.2, true)
			draw_set_transform_matrix(_cam)
			draw_circle(gq, 2.4, Color(Art.team_color(gu.team, cbm()), 0.5), true, -1.0, true)
	if live:
		# V1.3 C3：戰報墨圈畫在最底層（腳底三層之下）
		for f in fx:
			if f["kind"] == "inkring":
				var ik: float = f["t"] / f["dur"]
				draw_set_transform_matrix(_cam * Transform2D(0, Vector2(1, 0.5), 0, f["p"] + Vector2(0, 2)))   # 貼在地上（壓扁成橢圓）
				_hand_ring(Vector2.ZERO, (26.0 + ik * 8.0) * UNIT_SCALE, Color(0.12, 0.07, 0.04, 0.55 * (1.0 - ik)), 2.6, false, 1)
				draw_set_transform_matrix(_cam)
	for u in list:
		var p0: Vector2 = pc[u.id] if live else ORIGIN + Vector2(u.x, u.y) * CS / 1000.0
		var air0: float = Gait.air(u.type, _walk_of(u, a_now)) if live else 0.0
		var ar0 := clampf(air0 * 0.05, 0.0, 1.0)
		var bsc: float = UNIT_SCALE * (BossD.DRAW_SCALE if u.boss else 1.0)   # V1.4 #12 巨獸畫大
		_ring(p0, u.team, u.type, bsc, ar0 if ar0 > 0.15 else 0.0)   # 小跳步不分層（效能：合成格一次貼完；1.1.0 B14 族群底座部件也烘在合成格裡）   # V1.3 A3：木座和隊伍圈留在地上，只有影子跟著跳起縮
		if u.st > 0:
			_sticker_badge(p0, u.st, UNIT_SCALE, u.ward or u.st != 3)   # V1.4 #9：護符用掉就淡掉
		if u.shield > 0:       # 第十二輪：手動技能的護盾、戰吼
			_hand_ring(p0 + Vector2(0, -24) * UNIT_SCALE, 28.0 * UNIT_SCALE, Color(0.55, 0.85, 1.0, 0.75), 2.5)
		if u.haste_t > 0:
			_hand_ring(p0, 19.0 * UNIT_SCALE, Color(1.0, 0.75, 0.25, 0.85), 2.5)
		if u.id == int(gm[0]) or (int(gm[0]) == -2 and u.team == 0 and u.type == int(gm[2]) and not u.summon):
			_goal_marker(p0, "protect" if int(gm[0]) == -2 else str(gm[1]))   # 第十三輪：要護送／斬首的那一隻；V1.1：不能倒的那種兵每隻都標
			if u.team == 0 and u.hp * 100 <= u.max_hp * 30 and not rfx:
				# V1.6.1 A2：要保住的兵殘血時框閃紅（白黑雙邊，色盲也看得出）
				var fl := 0.55 + 0.45 * sin(time * 6.0)   # 約 1 Hz 呼吸（Antigravity v161-i1：原本約 2 Hz 太累）
				_hand_ring(p0 + Vector2(0, -20) * UNIT_SCALE, 31.0 * UNIT_SCALE, Color(0, 0, 0, 0.5 * fl), 4.0)
				_hand_ring(p0 + Vector2(0, -20) * UNIT_SCALE, 30.0 * UNIT_SCALE, Color(1.0, 0.25, 0.2, fl), 2.5)
		if live and s.rally[u.team] and not s.finished:
			for k in 2:
				var ph := fmod(time * 1.6 + k * 0.5, 1.0)
				_hand_ring(p0, (14.0 + ph * 10.0) * UNIT_SCALE, Color(1, 0.42, 0.0, 0.55 * (1.0 - ph)), 2.0)
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
		# V1.3 P0-1：40px 格子分桶，只比相鄰 9 格（判定與雙迴圈相同：距離平方 < 1600）
		var bk := {}
		for u in list:
			var q: Vector2 = pc[u.id]
			var key := Vector2i(floori(q.x / 40.0), floori(q.y / 40.0))
			if bk.has(key):
				bk[key].append(q)
			else:
				bk[key] = [q]
		for u in list:
			var q: Vector2 = pc[u.id]
			var cx := floori(q.x / 40.0)
			var cy := floori(q.y / 40.0)
			var n := -1   # 自己一定在同一格，先扣掉
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var cell = bk.get(Vector2i(cx + dx, cy + dy))
					if cell == null:
						continue
					for o in cell:
						if q.distance_squared_to(o) < 1600.0:
							n += 1
			crowd[u.id] = n
	# 第二層：身體（V9：地圖的前景物件依腳點 y 插進來，才有前後遮擋）
	var prop_i := 0
	var xray: Array = []   # V1.1 C5：[腳點, 參數]，給被下排蓋到臉的那隻補畫半透明
	for u in list:
		var p: Vector2 = pc[u.id] if live else ORIGIN + Vector2(u.x, u.y) * CS / 1000.0
		while prop_i < fld_props.size() and ORIGIN.y + float(fld_props[prop_i][0]) <= p.y:
			MapArt.draw_prop(self, ORIGIN, fld_props[prop_i], time)
			prop_i += 1
		var walk: float = _walk_of(u, a_now) if live else ((time * Gait.nominal_rate(u.type, float(D.stat(u.type)["speed"]), CS, UNIT_SCALE) + u.id) if (u.mx != 0 or u.my != 0) else 0.0)
		var moving: bool = walk > 0.0
		var at := 0.0
		var variant := 0
		var hit_now := -1
		if live and atk_hit.has(u.id):
			var dt0 := _disp_tick()
			# V1.5：遠程的「出手」提早 fly 個 tick（飛行物離手），命中 tick 不變；動作照出手時間演
			var ph := proj_phase(atk_hit[u.id], dt0, u.type, view.delay, proj_tgt.get(u.id, {}))
			var hr: int = ph[0]
			var h: int = ph[1]
			var fly: int = h - hr if hr >= 0 else 0
			hit_now = h
			if h >= 0:
				at = atk_progress(dt0 - float(ph[3]), u.type, float(ph[4]))   # V1.5.1：這一發自己的動作起點與前搖
				if float(ph[2]) >= 0.0 and proj_tgt.get(u.id, {}).has(h):
					var pt = view.unit_by_id(proj_tgt[u.id][h])
					if pt != null:
						var pk: float = ph[2]
						var psg: float = signf(_upos(pt).x - _upos(u).x) if _upos(pt).x != _upos(u).x else (signf(u.fx) if u.fx != 0 else 1.0)
						proj_draw.append([u.type, u.team, _upos(u) + proj_launch(u.type, psg) * UNIT_SCALE, _upos(pt) + Vector2(0, -22 if u.type != D.BOMBER else -10), pk])
				# V1.5：舊的「前搖 2 tick 火罐飛行」拿掉：火罐前搖時在手上，出手後由上面的飛行物畫（手動軍令局沒有餘裕就直接落點爆炸）
				if u.type == D.SWORD:
					variant = int(atk_seq.get(u.id, {}).get(h, 0)) % 2   # 劍士橫斬與上挑逐擊交替（第三輪 R4）
				elif u.type >= D.CLASSIC and alt_hit.get(u.id, {}).has(h):
					variant = 2
		var hurt := 0.0
		if live and hurt_t.has(u.id) and _fx_on("flash"):
			hurt = clampf(1.0 - (time - hurt_t[u.id]) / 0.15, 0, 1) * int(Save.s("flash_pct")) / 100.0   # V1.5：受擊閃白強度
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
			_hand_ring(p + Vector2(0, 2), 22.0, Color(ACCENT, 0.9), 3.0, true)   # 跟拍中的那隻
		# 擠在一起時，正在出手或受擊的那隻加隊伍色光圈（第三輪 V5）
		if live and (at > 0.0 or hurt > 0.0) and crowd.get(u.id, 0) >= 3:
			_hand_ring(p + Vector2(0, -24 if u.type != D.CAVALRY else -28), 19.0, Color(Art.team_color(u.team, cbm()), 0.75 * alpha), 2.0)
		# 表情與兵種專屬動作（R5）
		var mood := 0
		var lean := 0.0
		var crouch := 1.0
		if hurt > 0.3 or u.stun > 0:
			mood |= Art.M_HURT
		elif grim[u.team] and at == 0.0:
			mood |= Art.M_GRIM
		if hurt > 0.0:
			crouch *= 1.0 - 0.12 * hurt                 # V1.1 A2：受擊壓扁（縱 0.88），配合後退與閃白
			lean -= 0.06 * hurt * float(hurt_dir.get(u.id, 0.0)) * face
		# 1.2.0 第 5 大類 A2：不倒翁搖（衰減擺盪）：相位用受擊後經過的時間（0.45 秒），和閃白強度無關（Codex cat05 #2）；減少動態時不搖
		if live and hurt_t.has(u.id) and not bool(Save.s("reduce_motion")):
			var hk := clampf(1.0 - (time - float(hurt_t[u.id])) / 0.45, 0.0, 1.0)
			if hk > 0.0:
				lean += _tumbler(hk) * float(hurt_dir.get(u.id, 1.0)) * face
		crouch *= _open_squash(u)
		if live:
			# V1.3 A4：停步慣性。剛停下時身體往前多晃一下再回正（0.3 秒，解析式衰減，不存逐兵彈簧狀態）
			if moving:
				stop_t.erase(u.id)
				walking[u.id] = true
			elif walking.get(u.id, false):
				walking.erase(u.id)
				stop_t[u.id] = time
			if stop_t.has(u.id):
				var sk: float = (time - float(stop_t[u.id])) / 0.3
				if sk >= 1.0 or at > 0.0:
					stop_t.erase(u.id)
				else:
					lean += 0.13 * sin(sk * TAU * 0.75) * (1.0 - sk)   # 正＝往前（unit_xf 會乘朝向）
		if live and u.windup > 0 and at == 0.0:
			# V1.1 A3：大招前搖的身體預警。小石魔高舉拉長、吸塵貓吸氣鼓脹、沙漏精靈與骷髏法師浮起
			var wk := 1.0 - float(u.windup) / F8.WINDUP
			if u.type == F8.GOLEM:
				at = Art.ATK_WINDUP * minf(1.0, wk * 1.4) * 0.999
			elif u.type == F8.CAT:
				crouch *= 1.0 + 0.14 * sin(minf(1.0, wk) * PI * 0.5)
			else:
				p.y -= 4.0 * sin(minf(1.0, wk) * PI * 0.5)
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
			_hand_ring(p + Vector2(0, -22), 15.0 + pulse * 3.0, Color(1.0, 0.33, 0.2, (0.35 + 0.3 * pulse) * alpha), 2.0)
		if u.type == D.ASSASSIN and u.stealth > 0:
			mood |= Art.M_HOOD
			crouch = 0.9                     # 潛行蹲身
		if live and brace_t.has(u.id) and time - brace_t[u.id] < 0.35:
			mood |= Art.M_BRACE
		# 勝利：存活的勝方每 0.45 秒原地跳 10px、武器高舉
		var hop := 0.0
		var won: bool = live and sim != null and u.team == sim.winner and (state == St.RESULT or (state == St.BATTLE and view != null and view.finished))
		var frz := 0.2   # 定格 0.2 秒（Antigravity v131-impl3：0.4 像卡住）
		if won and u.id == int(last_kill[0]) and time - float(last_kill[1]) < frz and not bool(Save.s("reduce_fx")):
			# V1.3.1 P2：最後一擊定格：擊倒最後一隻的那隻停在揮擊到底的姿勢 0.4 秒，再一起歡呼
			won = false
			at = Art.ATK_STRIKE
			lean = 0.0
		if won:
			# V1.3.1 P2：歡呼像波浪：定格結束後從中線往後排，每格延遲 0.06 秒才起跳
			var w0: float = float(last_kill[1]) + frz
			var dly := absf(p.x - (ORIGIN.x + fld_size.x * 0.5)) / CS * 0.06
			var tw := _pose_t(time) - w0 - dly   # 1.2.0 第 5 大類 C：歡呼走定格（12fps 姿勢）
			hop = absf(sin(tw * PI / 0.45)) * 10.0 if tw > 0.0 else 0.0
			mood |= Art.M_HAPPY   # V1.3.1：歡呼 ^ ^ 眼
			at = Art.ATK_WINDUP
			lean = Art.windup_lean(u.type)      # 抵銷前搖的後仰（V1.1：依兵種）：站直、武器高舉（和前搖分得開，Antigravity S4）
			crouch = 1.06
			_star_above(p + Vector2(0, -hop - (74 if u.type == D.CAVALRY else 66)))
			# V1.1 A7：兵種專屬的勝利小動作（簡化特效時不畫）
			match -1 if bool(Save.s("reduce_fx")) else u.type:
				D.DRUMMER:   # 鼓手：頭邊冒音符
					var nk := fmod(time * 1.6 + u.id * 0.3, 1.0)
					_icon("sound", p + Vector2(18 + nk * 8, -48 - nk * 22 - hop), 14.0, Color(1.0, 0.85, 0.4, 1.0 - nk))
				D.BERSERKER:   # 狂戰士：雙斧互敲的火花圈
					var bk := absf(sin((time + u.id * 0.05) * PI / 0.45))
					_hand_ring(p + Vector2(0, -50 - hop), 8.0 + bk * 6.0, Color(1.0, 0.55, 0.2, 0.8 * bk), 2.5)
				D.MEDIC:   # 醫者：綠色小十字往上飄
					var mk := fmod(time * 1.2 + u.id * 0.4, 1.0)
					var mc := p + Vector2(-16, -44 - mk * 24 - hop)
					draw_line(mc - Vector2(4, 0), mc + Vector2(4, 0), Color(0.5, 1.0, 0.55, 1.0 - mk), 2.5)
					draw_line(mc - Vector2(0, 4), mc + Vector2(0, 4), Color(0.5, 1.0, 0.55, 1.0 - mk), 2.5)
		p.y -= hop
		if u.hidden:
			Art.mimic_closed(self, p, u.team, face, alpha, time, cbm(), UNIT_SCALE)   # 偽裝中的寶箱怪
			continue
		if u.type == F8.GHOST:
			alpha *= 0.9
			p.y -= 3.0 + 2.5 * sin(time * 2.2 + u.id * 0.9)   # V1.1 A4：幽靈上下漂
			if moving and live and not bool(Save.s("reduce_fx")):
				# V1.0.0 角色（剪影辨識）：移動時身後一串淡煙（貼著身體，0.3 格內），和史萊姆、盾兵的剪影分開
				for k5 in 3:
					var ph5 := fmod(time * 2.5 + k5 * 0.33 + u.id * 0.17, 1.0)
					draw_circle(p + Vector2(-face * (10.0 + ph5 * 12.0), -14.0 + ph5 * 4.0), 5.0 * (1.0 - ph5) * UNIT_SCALE, Color(0.85, 0.9, 1.0, 0.35 * (1.0 - ph5) * alpha), true, -1.0, true)
		# 待機小動作（V9 P2）：重心換腳、偶爾縮一下身子
		if live and walk == 0.0 and at == 0.0:
			var tq := _pose_t(time)   # 1.2.0 第 5 大類 C：待機小動作走定格
			lean += sin(tq * 1.1 + u.id * 1.7) * 0.018
			var idle_k := fmod(tq + u.id * 1.37, 7.3)
			if idle_k < 0.3:
				crouch *= 1.0 - sin(idle_k / 0.3 * PI) * 0.05
			# 1.2.0 第 5 大類 D 個性動作：王國＝偶爾上發條（左右扭 0.4 秒）；奇幻＝呼吸膨縮（各兵相位不同）
			if u.type < D.COUNT:
				var wk := fmod(tq + u.id * 2.71, 9.7)
				if wk < 0.4:
					lean += sin(wk / 0.4 * TAU * 2.0) * 0.05
			else:
				crouch *= 1.0 + 0.03 * sin(tq * 2.0 + u.id * 1.3)
		if live:
			face = _face_of(u)
			# V1.3.1 P0-2：出手前先轉完。前搖一開始就面向目標（不改命中時間），出手中途目標換邊也維持到收招
			if at > 0.0:
				# 鎖定的是「這一擊」：連擊換到下一擊時重新取方向（Codex v131-impl1）
				if not atk_face.has(u.id) or int(atk_face[u.id][0]) != hit_now:
					atk_face[u.id] = [hit_now, signf(u.fx) if u.fx != 0 else (1.0 if face >= 0.0 else -1.0), float(face_now.get(u.id, face)), _disp_tick()]
				# V1.5.1 A3：前搖時從原本朝向轉過去（2 個畫面 tick，跟著暫停與倍速走），轉身途中出手用轉身攻擊格，不再瞬間跳回側面
				var tgt_f: float = float(atk_face[u.id][1])
				var f0: float = float(atk_face[u.id][2]) if atk_face[u.id].size() > 2 else tgt_f
				var kf := clampf((_disp_tick() - float(atk_face[u.id][3] if atk_face[u.id].size() > 3 else _disp_tick())) / 2.0, 0.0, 1.0)
				if signf(f0) == tgt_f and absf(f0) >= 0.9:
					face = tgt_f
				else:
					# 經過正面轉過去：寬度不低於 0.45（不壓成一條線），過半就朝向目標（不背對目標揮空，Antigravity v151-i1 #4）
					var lf := lerpf(f0, tgt_f, kf)
					# 從第一格就朝目標（轉身格的方向），寬度從轉到一半慢慢回到側面（Codex v151-i2：前半不再朝舊方向蓄力）
					face = tgt_f * (maxf(absf(lf), 0.45) if (kf >= 0.5 or signf(f0) == tgt_f) else 0.45)   # 同方向只是轉完剩下的角度
				face_now[u.id] = face
			elif atk_face.has(u.id):
				atk_face.erase(u.id)
			var tdk := _turn_dust_k(u)
			if tdk > 0.0 and not rfx:
				# V1.3 A1a：翻面時腳下踩出一小團塵土（畫在身體下面）
				for i in 3:
					var dx := (float(i) - 1.0) * (6.0 + (1.0 - tdk) * 8.0)
					draw_circle(p + Vector2(dx, 1.0 - (1.0 - tdk) * 3.0) , (2.0 + (1.0 - tdk) * 2.5) * UNIT_SCALE, Color(0.85, 0.75, 0.55, 0.55 * tdk), true, -1.0, true)
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
		# V1.3.1 P1：待機小動作。站著沒事（沒走、沒出手、沒暈、還在打）時，每隻約 30～60 秒做一次、1.2 秒，依 id 錯開
		var fid := -1
		if live and not moving and at == 0.0 and u.stun <= 0 and not s.finished and mood == 0 and not bool(Save.s("reduce_fx")):
			var per := 30.0 + float((u.id * 7919) % 30)
			var tm := fmod(time + u.id * 3.7, per)
			if tm < 1.2:
				fid = mini(3, int(tm / 1.2 * 4.0))
		var ut := _pose_t(time) if (live and walk == 0.0 and at == 0.0) else time   # 1.2.0 第 5 大類 C：待機時整隻（含呼吸起伏）走定格時間（Codex cat05 #3）
		_unit(p, u.type, u.team, face, walk, at, hurt, alpha, ut, UNIT_SCALE * (BossD.DRAW_SCALE if u.boss else 1.0), mood, lean, crouch, variant, fid)
		if live and not u.hidden:
			xray.append([p, [u.type, u.team, face, walk, at, alpha, lean, crouch, variant]])
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
	_draw_xray(xray)
	while prop_i < fld_props.size():
		MapArt.draw_prop(self, ORIGIN, fld_props[prop_i], time)
		prop_i += 1
	for pp in pot_draw:
		draw_circle(pp, 6.5, Art.OUT, true, -1.0, true)
		draw_circle(pp, 5.0, Color("#2a2533"), true, -1.0, true)
		draw_circle(pp + Vector2(3, -5), 2.0, Color(1, 0.8, 0.3), true, -1.0, true)
	pot_draw.clear()
	# 施放者在飛行途中陣亡：已經離手的箭／炸彈照樣飛到（Antigravity v150-i1 #1）
	if live:
		var dtd := _disp_tick()
		for u in s.units:
			if u.alive or not proj_tgt.has(u.id) or not atk_hit.has(u.id):
				continue
			var phd := proj_phase(atk_hit[u.id], dtd, u.type, view.delay, proj_tgt[u.id])
			if float(phd[2]) >= 0.0 and proj_tgt[u.id].has(int(phd[1])):
				var ptd = view.unit_by_id(proj_tgt[u.id][int(phd[1])])
				if ptd != null:
					var sgd: float = signf(_upos(ptd).x - _upos(u).x) if _upos(ptd).x != _upos(u).x else 1.0
					proj_draw.append([u.type, u.team, _upos(u) + proj_launch(u.type, sgd) * UNIT_SCALE, _upos(ptd) + Vector2(0, -22 if u.type != D.BOMBER else -10), float(phd[2])])
	for pj in proj_draw:
		_draw_projectile(int(pj[0]), int(pj[1]), pj[2], pj[3], float(pj[4]))
	proj_draw.clear()
	if dim:
		return
	# 第三層：小旗、血條、狀態（永遠畫在最上面）
	for u in list:
		var p: Vector2 = pc[u.id] if live else ORIGIN + Vector2(u.x, u.y) * CS / 1000.0
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
			_hand_ring(p + Vector2(0, -24), 22.0, Color(1, 0.45, 0.2, 0.35 + 0.15 * sin(time * 8)), 2.5)
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
			_hand_ring(p, D.DRUM_RANGE * CS / 1000.0, Color(1, 0.85, 0.35, 0.35), 2.0)
		if s.frenzy:
			draw_circle(p + Vector2(8, -58 - sin(time * 12 + u.id) * 2), 3.0, Color(1, 0.5, 0.1, 0.9), true, -1.0, true)
		if u.boss:
			_boss_bars(p, u)   # V1.4 #12：巨獸一直顯示大血條＋前臂、背甲兩條部位血條
			continue
		# 第七輪 D1：血條只在需要看時才畫（受傷 3 秒內、跟拍、低血量）
		var hurt_recent: bool = hurt_t.has(u.id) and time - float(hurt_t[u.id]) < 3.0
		# V1.3 C：選中（跟拍）的那隻就算滿血也畫，不然點了會以為血條壞了
		var hb: String = str(Save.s("hp_bars"))   # V1.5：血條 受傷時／一直／只看選取的／關
		var show_hb: bool = (u.hp < u.max_hp and (not live or hurt_recent or u.hp * 100 <= u.max_hp * 35)) if hb == "hurt" else (hb == "all")
		if (show_hb and hb != "sel" and hb != "off") or (live and u.id == follow_id and hb != "off"):
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
	var relics := 0
	for g in dying:
		var k: float = g["t"] / 1.0
		_draw_death(g, k)
		if RELIC.has(int(g["type"])) and relics < 4:   # 遺物獨立於屍體透明度，同畫面最多 4 組（Antigravity v131-impl3）
			_draw_relic(int(g["type"]), g["pos"], float(g["face"]), k, int(g["team"]))
			relics += 1
		if k >= 1.0:
			continue   # 倒棋躺著的那段：靈魂、塵土都已經結束
		if k < 0.3:
			for i in 6:
				var ang := i * TAU / 6
				draw_circle(g["pos"] + Vector2(cos(ang), sin(ang) * 0.5) * (8 + k * 70) + Vector2(0, -16), 4 * (1 - k), Color(1, 1, 1, 0.35), true, -1.0, true)
		Art.soul(self, g["pos"] + Vector2(sin(k * 9) * 4, -24 - k * 70), 0.75 * (1.0 - k))

## V1.3 A5：倒棋的兵種與倒的方向（＋往前、−往後，弧度）。其他兵種保留專屬死法（化煙、化開、碎裂…）。
const TOPPLE := {D.CAVALRY: 1.5, D.SWORD: 1.5, D.SHIELD: 1.5, D.DRUMMER: 1.5, D.BERSERKER: -1.5, D.PIKE: -1.5, D.ARCHER: -1.5, D.BOMBER: -1.5, D.MEDIC: -1.5, 18: -1.5}
## 這一筆死亡演出要留多久（秒）：倒棋 1.7、有遺物的 1.1、其他 1.0。
const RELIC := {12: true, 15: true, 17: true, 21: true}
static func death_life(t: int) -> float:
	return 1.7 if TOPPLE.has(t) else (1.1 if RELIC.has(t) else 1.0)

## V9 P2：每種兵的死法。k＝0～1（1 秒）。只用轉換與粒子，不多烘影格。
func _draw_death(g: Dictionary, k: float) -> void:
	var t: int = g["type"]
	var p: Vector2 = g["pos"]
	var face: float = g["face"]
	var u := minf(k / 0.55, 1.0)         # 倒下的主要段落
	var e := 1.0 - (1.0 - u) * (1.0 - u)
	var al := 1.0 - maxf(0.0, (k - 0.45) / 0.3)
	var hurt := maxf(0.0, 0.8 - k * 3.0)
	if TOPPLE.has(t):
		# V1.3 A5 倒棋：像桌上的棋子被打倒。0.35 秒從腳點側倒到 90°（落地彈一下），躺在木座上，1.3 秒後淡出
		var ft := minf(k / 0.35, 1.0)
		var fe := ft * ft
		var bounce := 0.07 * sin(clampf((k - 0.35) / 0.18, 0.0, 1.0) * PI)
		var lal := 1.0 - clampf((k - 1.3) / 0.4, 0.0, 1.0)
		if lal <= 0.0:
			return
		var lift := 2.0 * sin(clampf(ft, 0.0, 1.0) * PI) if t < D.COUNT else 0.0   # 1.2.0 第 5 大類 A3：王國棋子翻倒時底座和身體一起離地一點（翻半圈的感覺；Codex cat05 #4）
		var bp := p - Vector2(0, lift) * UNIT_SCALE
		if sprites != null and sprites.is_ready(cbm()):
			sprites.draw_base(self, bp, UNIT_SCALE, 0.8 * lal)
		else:
			Art.ring_base(self, bp, UNIT_SCALE, 0.8 * lal)
		# 往下 5px：倒下後身體貼著木座面，不是浮在上面（Antigravity v130-impl2）
		_unit(p + Vector2(0, 5.0 * fe - lift) * UNIT_SCALE, t, g["team"], face, 0.0, 0.0, hurt, lal * (1.0 - 0.2 * ft), time, UNIT_SCALE, 1 if k < 0.4 else 0, float(TOPPLE[t]) * (fe - bounce * ft), 1.0 - 0.1 * ft)
		return
	if al <= 0.0:
		return
	var lean := 0.0
	var crouch := 1.0
	match t:
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

## V1.3.1 P2：奇幻兵倒下時的「遺物」掉到地上彈一下（純畫面）：娃娃的針、骷髏的頭骨滾半圈、寶箱噴出兩枚金幣。
func _draw_relic(t: int, p: Vector2, face: float, k: float, team: int) -> void:
	if bool(Save.s("reduce_fx")) or k >= 1.1:
		return
	var a := 1.0 - clampf((k - 0.6) / 0.5, 0.0, 1.0)   # 前 0.6 秒落地停穩（不透明），0.6～1.1 秒淡出
	var bounce := absf(sin(k * PI * 2.0)) * (1.0 - k) * 14.0
	match t:
		15:   # 巫毒娃娃：大頭針從頭上掉下來，落地彈兩下
			var fall := minf(k / 0.3, 1.0)
			var q := p + Vector2(-8.0 * face, lerpf(-54.0, -3.0, fall * fall) - (bounce if k > 0.3 else 0.0)) * UNIT_SCALE
			draw_line(q, q + Vector2(10.0 * face, 4.0) * UNIT_SCALE, Color(Art.STEEL, a), 1.8, true)
			draw_circle(q, 3.2 * UNIT_SCALE, Color(1.0, 0.3, 0.43, a), true, -1.0, true)
		17, 21:   # 骷髏：頭骨滾出去半圈才停
			var roll := minf(k / 0.6, 1.0)
			var q2 := p + Vector2(face * (6.0 + 16.0 * roll), -6.0 - bounce * 0.6) * UNIT_SCALE
			draw_circle(q2, 6.5 * UNIT_SCALE, Color(Art.OUT, a), true, -1.0, true)
			draw_circle(q2, 5.2 * UNIT_SCALE, Color(0.96, 0.94, 0.88, a), true, -1.0, true)
			var ang := roll * PI * face
			for s in [-1.0, 1.0]:
				draw_circle(q2 + Vector2(cos(ang + s * 0.6), sin(ang + s * 0.6)) * 2.4 * UNIT_SCALE, 1.2 * UNIT_SCALE, Color(Art.OUT, a), true, -1.0, true)
		12:   # 寶箱怪：噴出兩枚金幣，拋物線落地
			for c in 2:
				var dx := (-1.0 if c == 0 else 1.0) * (10.0 + k * 22.0)
				var up := sin(minf(k / 0.7, 1.0) * PI) * 26.0
				draw_circle(p + Vector2(dx, -18.0 - up + k * 14.0) * UNIT_SCALE, 3.2 * UNIT_SCALE, Color(Art.GOLD, a), true, -1.0, true)


## V1.4 #12 巨獸血條：上面一條大的（本體），下面兩條小的（前臂、背甲），部位斷了畫成灰色斷條。
func _boss_bars(p: Vector2, u) -> void:
	var w := 84.0
	var top := p + Vector2(-w / 2.0, -76.0 * BossD.DRAW_SCALE)
	draw_rect(Rect2(top - Vector2(2, 2), Vector2(w + 4, 9)), Art.OUT)
	draw_rect(Rect2(top, Vector2(w * maxf(0.0, float(u.hp)) / maxf(1.0, float(u.max_hp)), 5)), Color("#e05a3a"))
	var rows := [["sword", u.arm_hp, float(u.max_hp) * BossD.ARM_PCT / 100.0], ["shield", u.plate_hp, float(u.max_hp) * BossD.PART_PCT / 100.0]]
	for k in 2:
		var y := top.y + 10.0 + k * 9.0
		var x0 := top.x + 14.0
		_icon(str(rows[k][0]), Vector2(top.x + 5.0, y + 2.5), 9.0, Color(1, 1, 1, 0.9))
		draw_rect(Rect2(Vector2(x0 - 1, y - 1), Vector2(w - 13.0, 5)), Art.OUT)
		var hp_k := float(rows[k][1])
		if hp_k > 0.0:
			draw_rect(Rect2(Vector2(x0, y), Vector2((w - 15.0) * hp_k / maxf(1.0, float(rows[k][2])), 3)), Color("#d4a017"))
		else:
			draw_line(Vector2(x0, y + 1.5), Vector2(x0 + w - 15.0, y + 1.5), Color(0.5, 0.5, 0.5, 0.8), 1.5, true)


## ── V1.5 遠程飛行物（只動畫面）：從手上（出手點）飛到目標，命中 tick 剛好到 ──
var proj_draw: Array = []   # [兵種, 隊伍, 起點, 終點, 進度 0～1]

## 出手點（相對腳底，UNIT_SCALE 前）：弓弦、手上的火罐、書上的紫火、杖頂十字。
static func proj_launch(type: int, sg: float) -> Vector2:
	match type:
		D.ARCHER:
			return Vector2(sg * 14.0, -30.0)
		D.BOMBER:
			return Vector2(sg * 17.0, -24.0)
		17:
			return Vector2(sg * 20.0, -34.0)
		D.MEDIC:
			return Vector2(sg * 14.0, -52.0)
	return Vector2(0, -28)

func _draw_projectile(type: int, team: int, a: Vector2, b: Vector2, k: float) -> void:
	var d := b - a
	var len := maxf(1.0, d.length())
	if speed >= 4.0 and not bool(Save.s("reduce_fx")):
		# 1.1.0 B8：高倍速時飛行物一閃就過：落點畫一個小粉筆圈（只是畫面，傷害時機不動）
		draw_arc(b, 7.0 + 3.0 * k, 0.0, TAU, 16, Color(Art.team_color(team, cbm()), 0.55 * (1.0 - k * 0.5)), 1.6, true)
	match type:
		D.ARCHER:
			# 淺拋物線；箭身沿切線方向
			var arc := minf(26.0, len * 0.12)
			var p := a.lerp(b, k) + Vector2(0, -sin(k * PI) * arc)
			var tan := (d + Vector2(0, -cos(k * PI) * PI * arc)).normalized()
			var tail := p - tan * 16.0
			draw_line(tail, p, Art.OUT, 3.4, true)
			draw_line(tail, p, Color("#b98a52"), 2.0, true)
			var nrm := Vector2(-tan.y, tan.x)
			draw_colored_polygon(PackedVector2Array([p + tan * 5.0, p + nrm * 2.6, p - nrm * 2.6]), Color("#cfd6dc"))
			draw_line(tail, tail - tan * 3.0 + nrm * 3.0, Color(Art.team_color(team, cbm()), 0.95), 2.0, true)
			draw_line(tail, tail - tan * 3.0 - nrm * 3.0, Color(Art.team_color(team, cbm()), 0.95), 2.0, true)
		D.BOMBER:
			# 高拋物線＋旋轉＋引信火花
			var arc2 := minf(80.0, len * 0.35)
			var p2 := a.lerp(b, k) + Vector2(0, -sin(k * PI) * arc2)
			draw_circle(p2, 6.5, Art.OUT, true, -1.0, true)
			draw_circle(p2, 5.0, Color("#2a2533"), true, -1.0, true)
			var fz := p2 + Vector2.from_angle(time * 14.0) * 6.0
			draw_line(p2, fz, Color("#c9a26a"), 1.6, true)
			draw_circle(fz, 2.2, Color(1, 0.8, 0.3), true, -1.0, true)
		17:
			# 紫火球：低弧、拖尾
			var arc3 := minf(18.0, len * 0.08)
			for t in 4:
				var kk := clampf(k - t * 0.07, 0.0, 1.0)
				var q := a.lerp(b, kk) + Vector2(0, -sin(kk * PI) * arc3)
				draw_circle(q, 5.5 - t * 1.1, Color(0.66, 0.36, 0.95, 0.85 - t * 0.2), true, -1.0, true)
			var q0 := a.lerp(b, k) + Vector2(0, -sin(k * PI) * arc3)
			draw_circle(q0, 2.6, Color(1.0, 0.85, 1.0), true, -1.0, true)
		D.MEDIC:
			# 綠十字小光沿弧線飛到友軍
			var arc4 := minf(40.0, len * 0.25)
			var p4 := a.lerp(b, k) + Vector2(0, -sin(k * PI) * arc4)
			draw_circle(p4, 7.0, Color(0.5, 1.0, 0.6, 0.35), true, -1.0, true)
			_cross(p4, 4.5, Color("#7dff8a"))

