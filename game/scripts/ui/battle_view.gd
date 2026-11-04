extends "res://scripts/ui/ui_base.gd"
const F8 = preload("res://scripts/core/fantasy_defs.gd")
const EV = preload("res://scripts/core/events.gd")
## 戰場、單位、特效、戰鬥 HUD、最後時刻鏡頭（演出層：不影響戰鬥結果）。


## 第七輪 M3：跳到結果不再卡畫面。正常畫面分批算（每幀限時）；headless 與截圖走同步。
var skip_busy := false

func _on_skip() -> void:
	if skip_busy:
		return   # 防重入
	paused = false   # Codex r1：暫停中按直接看結果，算完要能進結算
	if DisplayServer.get_name() == "headless" or shot_dir != "":
		while not view.finished:
			_sim_step(false)
		result_delay = 9.0
		return
	skip_busy = true

func _skip_step() -> void:
	var t0 := Time.get_ticks_msec()
	while not view.finished and Time.get_ticks_msec() - t0 < 10:
		_sim_step(false)
	if view.finished:
		skip_busy = false
		result_delay = 9.0

func _draw_busy(pct: int) -> void:
	var msg: String = L.t("busy_calc", [pct])
	var w := _width(msg, tz("B"), true) + 40
	draw_rect(Rect2(640 - w / 2, 360, w, tz("B") * 1.8), Color(0.06, 0.07, 0.1, 0.92))
	_text(Vector2(640, 360 + tz("B") * 0.35), msg, tz("B"), ACCENT, true, true)


func _battle_process(delta: float) -> void:
	if start_hold > 0.0:
		start_hold -= delta
		return
	if call("_seek_pump"):
		return
	if skip_busy:
		_skip_step()
		return
	if paused:
		return
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
		var was_slow := slow_left > 0
		_sim_step(true)
		if slow_left > 0 and not was_slow:
			break   # 這一 tick 觸發慢動作：剩下的累積留到下一幀用慢速消耗（Codex S8 #3）
	# 播完之後展示時鐘繼續走（不再推進快照）：最後一格的位置插值與最後一擊的後搖要演完（Codex R5 #1）
	# 最後時刻只在 _sim_step 每個畫面 tick 判定（Codex S8 #1：每幀也判會讓觸發 tick 跟幀率有關）
	if slow_left > 0:
		_update_action_focus()
	sfx.set_muffled(slow_left > 0 and not view.finished)
	# 分軌音樂依戰況混音（第三輪 S1）
	var close := absf(view.power(0) * 100.0 / (view.budget_of(0) * 1000) - view.power(1) * 100.0 / (view.budget_of(1) * 1000)) <= 15.0
	sfx.set_layer_targets(sfx.layer_targets(close, slow_left > 0 and not view.finished))
	# 鏡頭只有一個決策點（Codex S5 #6）：跟拍優先於最後時刻框選，兩者都沒有才回到全景
	if follow_id >= 0:
		pass   # 由 _follow_update 決定
	elif slow_left > 0 and not view.finished:
		_frame_alive(delta)
	else:
		zoom_target = 1.0
		zoom_center = zoom_center.lerp(ORIGIN + FIELD / 2, minf(1.0, delta * 3))
	zoom = lerpf(zoom, zoom_target, delta * 3)
	if view.finished:
		result_delay += delta
		if result_delay > 1.4:
			on_battle_finished.call()


## 最後時刻（優化方案 F1）：雙方剩餘戰力都 ≤30% 且差距 ≤15%；或雙方各剩 ≤3 隻且差距 ≤15%。
## 最後時刻的條件（view 與 sim 都有 budget／power／alive_count，重播跳轉時用同一個條件重算，Codex S7 #2）。
static func clutch_cond(s) -> bool:
	# 第五輪：各自用自己的預算算比例（舊判定時兩邊預算相同，和 1.3.0 一樣）
	var p0: float = s.power(0) * 100.0 / (s.budget_of(0) * 1000.0)
	var p1: float = s.power(1) * 100.0 / (s.budget_of(1) * 1000.0)
	return absf(p0 - p1) <= 15.0 and ((p0 <= 30.0 and p1 <= 30.0) or (s.alive_count(0) <= 3 and s.alive_count(1) <= 3))

## with_fx＝false（直接看結果、重播跳轉補播）只記狀態與標記，不放慢動作、不播音效、不出橫幅（Codex S8 #2）。
func _check_clutch(with_fx := true) -> void:
	if slow_used or view.finished:
		return
	if clutch_cond(view):
		slow_used = true
		clutch_tick = view.tick
		battle_marks.append({"tick": view.tick, "kind": "clutch", "team": -1})
		if not with_fx:
			return
		if _fx_on("slowmo"):
			slow_left = 8.0
		clutch_t = 1.6   # 最後時刻橫幅（第三輪 V2）：獨立一層畫在 _draw_clutch_banner
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
	zoom_target = clampf(minf(1280.0 / maxf(1, size.x), 620.0 / maxf(1, size.y)) * 1.05, 1.08, 1.55)   # 再往勝負焦點收 5%（V2）
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
	_check_clutch(with_fx)   # 每一個畫面 tick 都判定（原本每一幀判一次，觸發的 tick 會跟幀率有關）
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
		_collect_mark(ev, view, view.tick)
		_on_event(ev, with_fx)
	# 碾壓局最後一擊（優化方案 F1）：0.2 秒頓格＋微震，直接進結算
	if view.finished and not slow_used and deaths > 0 and with_fx:
		hitstop = 0.2
		if bool(Save.s("shake")):
			shake = 0.15


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


## 模擬往前補到領先 DELAY 個 tick；新進緩衝的攻擊事件先記下命中 tick，畫面就能在命中前開始演前搖。
func _pump_view() -> void:
	for fr in view.pump(sim):
		for e in fr["events"]:
			# 第四輪：補血、戰鼓也走出手動畫；被貼身敲人、破陣、補血、戰鼓用專屬動作（variant 2）
			if e["kind"] == EV.HEAL or e["kind"] == EV.DRUM or e["kind"] == EV.BONK or e.get("tags", []).has(EV.BREACH):
				var ah: Dictionary = alt_hit.get(e["src"], {})
				ah[int(fr["tick"])] = true
				if ah.size() > 8:
					ah.erase(ah.keys().min())
				alt_hit[e["src"]] = ah
			if event_route(e) == "attack" or e["kind"] == EV.HEAL or e["kind"] == EV.DRUM:
				var hs: Array = atk_hit.get(e["src"], [])
				hs.append(int(fr["tick"]))
				if e["kind"] == EV.BOMB:
					# 投彈兵（第四輪 §4.4）：記下命中 tick → 目標，前搖期間畫火罐飛過去，命中那一刻剛好落地
					var bt: Dictionary = bomb_tgt.get(e["src"], {})
					bt[int(fr["tick"])] = e["tgt"]
					if bt.size() > 6:
						bt.erase(bt.keys().min())
					bomb_tgt[e["src"]] = bt
				# 每隻單位的第幾次出手（交替招式用，Codex S4 #2：原本用 tick 奇偶，連續反擊會同招）
				var sq: Dictionary = atk_seq.get(e["src"], {})
				sq[int(fr["tick"])] = sq.size()
				atk_seq[e["src"]] = sq   # 存序列，不覆蓋還沒播到的命中（Codex R5 #2：連續反擊）
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
	var tm := atk_timing(type)
	var w: float = tm[1]
	var strike_end: float = w + tm[2]
	var cur := -1
	for h in hits:
		if float(h) - w <= disp:
			if cur >= 0 and disp - (float(cur) - w) < strike_end:
				break   # 前一次還在揮擊，不換
			cur = h
	return cur


## 三段式攻擊進度（R5）：前搖固定是命中前 DELAY 個 tick，揮擊與後搖依攻擊間隔壓縮（攻速快的兵動作也快，不會疊在一起）。
## 回傳 Art.unit 的 atk 參數：0＝沒在攻擊；0～0.3125 前搖、0.3125～0.53125 揮擊（命中在 0.3125）、之後後搖到 1。
## 一次攻擊動作的時長（tick）：前搖固定 DELAY，揮擊 0.22×總長；atk_progress 與 pick_hit 共用（Codex S4 #1）。
static func atk_timing(type: int) -> Array:
	var period := float(D.stat(type)["cd"])   # cd 的單位是 tick（模擬每次出手加 cd×4、每 tick 扣 4）
	var tot := clampf(period, 4.0, 6.4)
	return [tot, float(ViewBuffer.DELAY), 0.22 * tot]

static func atk_progress(dt: float, type: int) -> float:
	var tm := atk_timing(type)
	var tot: float = tm[0]
	var w: float = tm[1]
	var st: float = tm[2]
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


## 小火焰圖示（背水）。
func _flame(c: Vector2, sc: float) -> void:
	var fl := sin(time * 14.0) * 1.5
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -11 - fl) * sc, c + Vector2(6, 2) * sc, c + Vector2(0, 7) * sc, c + Vector2(-6, 2) * sc]), Color(1, 0.4, 0.1))
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -5 - fl * 0.5) * sc, c + Vector2(3, 3) * sc, c + Vector2(0, 6) * sc, c + Vector2(-3, 3) * sc]), Color(1, 0.85, 0.3))


static func _smoothstep01(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


## 小十字（補血）。
func _cross(c: Vector2, r: float, col: Color) -> void:
	draw_rect(Rect2(c - Vector2(r * 0.32, r), Vector2(r * 0.64, r * 2.0)), col)
	draw_rect(Rect2(c - Vector2(r, r * 0.32), Vector2(r * 2.0, r * 0.64)), col)


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


## 第八輪的事件演出。回傳 true＝處理掉了。全部受簡化特效限制（_add_fx 會擋裝飾性的）。
func _on_event_v8(ev: Dictionary, k: String, with_fx: bool) -> bool:
	if not k in [EV.POISON, EV.BLAST, EV.VOODOO, EV.BITE, EV.MIMIC_OPEN, EV.SPLIT, EV.CAST, EV.TIMESTOP, EV.RAISE, EV.VACUUM, EV.STOMP, EV.ROCK]:
		return false
	if not with_fx:
		return true
	var s = view.unit_by_id(ev.get("src", -1))
	var t = view.unit_by_id(ev.get("tgt", -1))
	if s == null:
		return true
	var sp := _upos(s)
	var tp := _upos(t) if t != null else sp
	match k:
		EV.POISON:
			hurt_t[t.id] = time
			hurt_dir[t.id] = 0.0
			_add_fx({"kind": "spore", "p": tp + Vector2(0, -30), "t": 0.0, "dur": 0.5})
			sfx.play("poison", 0.25)
		EV.VOODOO:
			hurt_t[t.id] = time
			hurt_dir[t.id] = 0.0
			_add_fx({"kind": "pin", "a": sp + Vector2(0, -26), "b": tp + Vector2(0, -26), "t": 0.0, "dur": 0.3})
			_report_add(s.team, s.type, k, L.t("ev_voodoo"), Color("#ff6bb0"))
		EV.BLAST:
			if s.id != t.id:
				hurt_t[t.id] = time
				hurt_dir[t.id] = signf(tp.x - sp.x) if tp.x != sp.x else 0.0
			else:
				var small: bool = ev.get("small", false)
				_add_fx({"kind": "boom", "src": s.id, "p": sp + Vector2(0, -8), "t": 0.0, "dur": 0.45, "big": not small})
				_add_fx({"kind": "wool", "p": sp + Vector2(0, -18), "t": 0.0, "dur": 0.6})
				sfx.play("boom", 0.8)
				sfx.play("baa", 0.6)
				if _fx_on("shake"):
					shake = 0.1
				_report_add(s.team, s.type, k, L.t("ev_blast"), Color("#ffb347"))
		EV.BITE:
			atk_t[s.id] = time
			hurt_t[t.id] = time
			hurt_dir[t.id] = signf(tp.x - sp.x) if tp.x != sp.x else 0.0
			_add_fx({"kind": "chomp", "p": tp + Vector2(0, -28), "t": 0.0, "dur": 0.35})
			sfx.play("chomp", 0.9)
			_report_add(s.team, s.type, k, L.t("ev_bite"), Color("#ffd166"))
		EV.MIMIC_OPEN:
			_add_fx({"kind": "puff", "p": sp + Vector2(0, -20), "t": 0.0, "dur": 0.4})
			sfx.play("reveal", 0.7)
		EV.SPLIT:
			_add_fx({"kind": "puff", "p": sp + Vector2(0, -12), "t": 0.0, "dur": 0.3})
			sfx.play("squish", 0.5)
			_report_add(s.team, 13, k, L.t("ev_split"), Color("#7dffa0"))
		EV.CAST:
			sfx.play("charge_up", 0.5)
		EV.TIMESTOP:
			_add_fx({"kind": "timebell", "p": sp + Vector2(0, -20), "t": 0.0, "dur": 0.8})
			sfx.play("bell", 1.0)
			sfx.play("timestop", 0.9)
			_report_add(s.team, s.type, k, L.t("ev_timestop"), Color("#ffe08a"))
		EV.RAISE:
			_add_fx({"kind": "soulrise", "p": sp + Vector2(0, -16), "t": 0.0, "dur": 0.6})
			sfx.play("raise", 0.8)
			_report_add(s.team, 17, k, L.t("ev_raise"), Color("#c77dff"))
		EV.VACUUM:
			_add_fx({"kind": "swirl", "p": sp + Vector2(0, -14), "t": 0.0, "dur": 0.6})
			sfx.play("vacuum", 0.8)
			_report_add(s.team, s.type, k, L.t("ev_vacuum"), Color("#9ad1ff"))
		EV.STOMP:
			_add_fx({"kind": "stompring", "p": sp, "t": 0.0, "dur": 0.45})
			sfx.play("stomp", 0.9)
			if _fx_on("shake"):
				shake = 0.14
			_report_add(s.team, s.type, k, L.t("ev_stomp"), Color("#d9c9a3"))
		EV.ROCK:
			sfx.play("shatter", 0.7)
	return true


## 第八輪地面層：毒圈、碎石區。淡色，畫在單位底下。
func _draw_v8_ground(s, live: bool) -> void:
	if not live:
		return
	for z in s.zones:
		var c := ORIGIN + Vector2(int(z[0]), int(z[1])) * CS / 1000.0
		var rr: float = float(F8.ROCK_R) * CS / 1000.0
		draw_set_transform_matrix(_cam * Transform2D(0, Vector2(1, 0.55), 0, c))
		draw_circle(Vector2.ZERO, rr, Color(0.35, 0.3, 0.22, 0.28), true, -1.0, true)
		for k in 7:
			var an := k * TAU / 7.0 + 0.4
			var a0 := Vector2(cos(an), sin(an)) * rr * 0.2
			var a1 := Vector2(cos(an + 0.3), sin(an + 0.3)) * rr * 0.62
			var a2 := Vector2(cos(an - 0.1), sin(an - 0.1)) * rr * 0.95
			draw_polyline(PackedVector2Array([a0, a1, a2]), Color(0.12, 0.1, 0.08, 0.7), 2.5, true)
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
		draw_dashed_line(p + Vector2(0, -26), q + Vector2(0, -26), Color(Art.OUT, 0.5), 3.5, 7.0)
		draw_dashed_line(p + Vector2(0, -26), q + Vector2(0, -26), col, 2.0, 7.0)
	if u.windup > 0:
		var k := 1.0 - float(u.windup) / F8.WINDUP
		var rc := Color("#ffe08a") if u.type == F8.SPRITE else (Color("#c77dff") if u.type == F8.BONE else (Color("#9ad1ff") if u.type == F8.CAT else Color("#d9c9a3")))
		draw_arc(p + Vector2(0, -24), 26.0, -PI / 2, -PI / 2 + TAU * k, 28, Color(Art.OUT, 0.7), 5.0, true)
		draw_arc(p + Vector2(0, -24), 26.0, -PI / 2, -PI / 2 + TAU * k, 28, rc, 3.0, true)
	if u.guard > 0:
		draw_arc(p + Vector2(0, -24), 20.0, 0, TAU, 24, Color(1.0, 0.88, 0.5, 0.65), 2.5, true)


func _on_event(ev: Dictionary, with_fx: bool) -> void:
	var k: String = ev["kind"]
	if _on_event_v8(ev, k, with_fx):
		return
	if k == EV.DEATH:
		var u = view.unit_by_id(ev["id"])
		dying.append({"pos": _upos(u), "type": u.type, "team": u.team, "face": signf(u.fx) if u.fx != 0 else 1.0, "t": 0.0})
		if with_fx:
			sfx.play("death", 0.7)
		return
	if k == EV.HEAL and with_fx:
		# 補血（第四輪 §4.4）：醫者到目標一條淡綠弧線＋綠色「+N」（不加黑底）
		var hs0 = view.unit_by_id(ev["src"])
		var ht0 = view.unit_by_id(ev["tgt"])
		if hs0 != null and ht0 != null:
			_add_fx({"kind": "healarc", "a": _upos(hs0) + Vector2(0, -40), "b": _upos(ht0) + Vector2(0, -26), "t": 0.0, "dur": 0.25})
			_merge_text(ht0.id, EV.HEAL, "+", int(ev["amt"]), _upos(ht0) + Vector2(0, -70), Color("#7dff8a"))
			sfx.play("heal", 0.35)
		return
	if k == EV.DRUM and with_fx:
		var dr0 = view.unit_by_id(ev["src"])
		if dr0 != null:
			_add_fx({"kind": "note", "p": _upos(dr0) + Vector2(6, -78), "t": 0.0, "dur": 0.8})
		return
	var route := event_route(ev)
	if route == "skip" or not with_fx:
		return
	match route:
		"taunt":
			var sh = view.unit_by_id(ev["src"])
			var vic = view.unit_by_id(ev["tgt"])
			_add_fx({"kind": "taunt", "p": _upos(sh), "t": 0.0, "dur": 0.6})
			sfx.play("taunt", 0.5)
			_add_fx({"kind": "bang", "p": _upos(vic) + Vector2(20, -66), "t": 0.0, "dur": 0.7})   # 第七輪 D1：移到頭頂側上方，不擋臉
			return
		"reveal":
			_add_fx({"kind": "puff", "p": _upos(view.unit_by_id(ev["src"])) + Vector2(0, -20), "t": 0.0, "dur": 0.45})
			sfx.play("reveal", 0.6)
			return
	var s = view.unit_by_id(ev["src"])
	var t = view.unit_by_id(ev["tgt"])
	var tags: Array = ev.get("tags", [])
	atk_t[s.id] = time
	hurt_t[t.id] = time
	var sp := _upos(s)
	var tpos := _upos(t)
	hurt_dir[t.id] = signf(tpos.x - sp.x) if tpos.x != sp.x else (1.0 if t.team == 1 else -1.0)
	if tags.has(EV.ALERT):
		sfx.play("alert", 0.5)
		_add_fx({"kind": "aim", "a": sp + Vector2(0, -24), "b": tpos + Vector2(0, -22), "t": 0.0, "dur": 0.32})
	if tags.has(EV.HIDE):
		_add_fx({"kind": "hide", "p": tpos + Vector2(0, -24), "dir": signf(sp.x - tpos.x) if sp.x != tpos.x else 1.0, "t": 0.0, "dur": 0.4})
	if tags.has(EV.TRIP):
		sfx.play("snap", 0.7)
		_add_fx({"kind": "trip", "p": tpos + Vector2(0, -4), "t": 0.0, "dur": 0.5})
	if s.type == D.BOMBER and k == EV.BOMB:
		_add_fx({"src": s.id, "kind": "boom", "p": tpos + Vector2(0, -6), "t": 0.0, "dur": 0.45})   # 帶攻擊者：同點多顆炸彈不被去重吃掉
		sfx.play("boom", 0.55)
	elif k == EV.SPLASH:
		pass   # 波及只靠爆炸圈和受擊閃白，不另外畫砍擊、不印字（Antigravity 第一輪 §6.2）
	elif s.type == D.ARCHER:
		_add_fx({"src": s.id, "kind": "arrow", "a": sp + Vector2(10 * signf(tpos.x - sp.x), -24), "b": tpos + Vector2(0, -22), "t": 0.0, "dur": 0.28, "tc": Art.team_color(s.team, cbm())})
		sfx.play("arrow", 0.35)
	else:
		_add_fx({"src": s.id, "kind": "slash", "p": sp, "dir": signf(tpos.x - sp.x) if tpos.x != sp.x else 1.0, "t": 0.0, "dur": 0.18})
		sfx.play("hit" if k == EV.HIT else "slash", 0.4)
	var col := Color.WHITE
	var label := ""
	match k:
		EV.CHARGE:
			label = L.t("ev_charge")
			col = ACCENT
			sfx.play("charge")
			sfx.play("bugle", 0.6)
			if _fx_on("shake"):
				shake = 0.12
			_add_fx({"kind": "dust", "p": tpos, "t": 0.0, "dur": 0.5})
		EV.BACKSTAB:
			label = L.t("ev_backstab")
			col = Color("#c77dff")
			sfx.play("backstab")
			sfx.play("aircut", 0.7)
			# 第七輪 D7：拿掉閃光 X（混戰疊成一片），只留方向斬痕
			_add_fx({"kind": "vslash", "p": tpos + Vector2(0, -26), "dir": signf(tpos.x - sp.x) if tpos.x != sp.x else 1.0, "t": 0.0, "dur": 0.2})
		EV.BRACED:
			label = L.t("ev_braced")
			col = Color("#9ad1ff")
			sfx.play("bell", 0.8)
			brace_t[t.id] = time
			_add_fx({"kind": "hex", "p": tpos + Vector2(10 * signf(sp.x - tpos.x), -24), "t": 0.0, "dur": 0.45})
		EV.ANTICAV:
			label = L.t("ev_anticav")
			col = Color("#9ad1ff")
			sfx.play("brace", 0.6)
		EV.BLOCKED:
			sfx.play("block", 0.5)
			_add_fx({"kind": "ripple", "p": tpos + Vector2(14 * signf(sp.x - tpos.x), -26), "c": Color("#cfe3ff"), "t": 0.0, "dur": 0.3})
		EV.COUNTER:
			label = L.t("ev_counter")
			col = Color("#80ffdb")
		EV.PIKE_BRACE:
			label = L.t("ev_pike_brace")
			col = Color("#ffd166")
			sfx.play("bell", 0.8)
			brace_t[t.id] = time   # 長槍兵頓槍（M_BRACE 疊加：槍尖銀光）
			_add_fx({"kind": "hex", "p": tpos + Vector2(10 * signf(sp.x - tpos.x), -24), "t": 0.0, "dur": 0.45})
		EV.BREACH:
			label = L.t("ev_breach")
			col = Color("#ff7a3d")
			sfx.play("shatter", 0.6)
			_add_fx({"kind": "shard", "p": tpos + Vector2(12, -26), "t": 0.0, "dur": 0.5})
		EV.BREAKER:
			sfx.play("shatter", 0.45)
			_add_fx({"kind": "shard", "p": tpos + Vector2(12, -26), "t": 0.0, "dur": 0.5})
	if label != "":
		_report_add(s.team, s.type, k, label, col)
		# 第七輪 D1：混戰（附近 3 隻以上）不再往上疊跳字，技能都進底部戰報列；稀疏時才跳字
		if _crowd_at(t) < 3:
			_merge_text(t.id, k, label, int(ev["dmg"]), tpos + Vector2(0, -78), col)
		elif int(TEXT_TIER.get(k, 1)) >= 2:
			text_key_in += 1
			text_key_shown += 1   # 關鍵技能仍然有顯示，只是在戰報列（測試對帳用）


## 這隻兵附近（60px 內）有幾隻活著的兵，不算自己。
func _crowd_at(u) -> int:
	var n := 0
	var p := _upos(u)
	for v in view.units:
		if v.alive and v.id != u.id and _upos(v).distance_squared_to(p) < 3600.0:
			n += 1
	return n


## 戰報列（第七輪 E1）：承接混戰時的技能跳字。同隊同兵種同技能 2 秒內合併。
var report_log: Array = []
const REPORT_CAP := 6

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

## 開戰號角（第七輪 A10）：正式對局開戰前留 1 秒，陣線亮一下。只是畫面緩衝，模擬還沒開始；簡化特效時略過。
var start_hold := 0.0

func _draw_start_cue() -> void:
	if start_hold <= 0.0:
		return
	var k := clampf(start_hold, 0.0, 1.0)
	var msg: String = L.t("start")
	var sz := tcap(tz("D"), 64)
	_text(Vector2(640, 340), msg, sz, Color(1, 0.85, 0.4, k), true, true)
	for tm in 2:
		var x: float = ORIGIN.x + (float(view.max_x(tm)) / 1000.0 if view.has_method("max_x") else (6.0 if tm == 0 else 10.0) * 1.0) * CS
		draw_line(Vector2(x, ORIGIN.y), Vector2(x, ORIGIN.y + FIELD.y), Color(Art.team_color(tm, cbm()), 0.9 * k), 5.0)


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
	var y0: float = 800.0 - rows * rh - 4.0 if ctl else 692.0
	var cw := 412.0
	for i in mini(report_log.size(), rows * 3):
		var e: Dictionary = report_log[i]
		var age: float = time - float(e["t"])
		var a := clampf(1.6 - age * 0.4, 0.35, 1.0)
		var p := Vector2(14.0 + (i % 3) * cw, y0 + (i / 3) * rh)
		var mark := "●" if e["team"] == 0 else "◆"
		var line := "%s %s" % [L.t("unit_%d" % int(e["type"])), e["label"]]
		if int(e["n"]) > 1:
			line += " ×%d" % int(e["n"])
		_text(p, mark, tz("S"), Color(Art.team_color(int(e["team"]), cbm()), a), false, true)
		_text(p + Vector2(tz("S") + 6.0, 0), line, tz("S"), Color(e["col"], a), false, true, cw - tz("S") - 14.0)


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
	draw_rect(R, Color(0.06, 0.07, 0.1, 0.92))
	draw_rect(R, Color(Art.team_color(u.team, cbm()), 0.9), false, 2.0)
	for i in lines.size():
		_text(R.position + Vector2(10, 8 + i * tz("S") * 1.4), lines[i], tz("S"), Color.WHITE, false, i == 0, 266)


## 跳字（第三輪 V1）：
## ・合併：同一種技能、同一區（48×32px）0.35 秒內合併成「背刺 ×3（120）」，數字變大彈一下
## ・分級：TEXT_TIER 2＝關鍵（衝鋒、背刺、頂住），1＝一般技能；關鍵的不會因為上限被丟
## ・上限：戰場上同時最多 TEXT_CAP 個，超過時丟最舊的一般跳字
## ・避讓：每幀用「含描邊的實際外框」排版（_layout_texts）：關鍵、新的先佔位，其他重疊就往上推
const TEXT_CAP := 12
const TEXT_TIER := {"charge": 2, "backstab": 2, "braced": 2, "anticav": 1, "counter": 1, "pike_brace": 2, "breach": 1, "heal": 0}
const TEXT_CELL := Vector2(48, 32)
var text_dropped := 0          # 被上限丟掉的跳字數（測試對帳用）

var text_key_in := 0           # 進來的關鍵跳字事件數（合併也算）
var text_key_shown := 0        # 關鍵跳字實際顯示（新增或併進既有的）的次數

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


## 跳字的外框（含描邊與底襯，戰場座標）。
func _text_rect(f: Dictionary, at: Vector2) -> Rect2:
	var sz := int(ts(int(f["size"])) * (1.0 + float(f.get("pop", 0.0)) * 1.4))   # 含合併時的彈跳放大（Codex S1 #4）
	var w := font_bold.get_string_size(f["s"], HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x + 14.0 if font_bold != null else float(f["s"].length() * sz)
	var h := sz * 1.3 + 6.0
	return Rect2(at.x - w / 2.0, at.y - 3.0, w, h)

static func _text_alpha(f: Dictionary) -> float:
	var k: float = f["t"] / f["dur"]
	return 1.0 - k * k

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

static func _overlap(a: Rect2, b: Rect2) -> float:
	var x := a.intersection(b)
	if not x.has_area():
		return 0.0
	return x.get_area() / maxf(1.0, minf(a.get_area(), b.get_area()))


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

## 焦點＝最近 0.8 秒內出手或受擊的單位的中心（Antigravity S2 #2：原本用鏡頭中心，旁觀的弓兵不會淡化）
var action_focus := Vector2.ZERO
func _update_action_focus() -> void:
	var sum := Vector2.ZERO
	var n := 0
	for u in view.units:
		if u.alive and ((hurt_t.has(u.id) and time - hurt_t[u.id] < 0.8) or (atk_t.has(u.id) and time - atk_t[u.id] < 0.8)):
			sum += _upos(u)
			n += 1
	action_focus = sum / n if n > 0 else zoom_center


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


## 特效預算（第三輪 V3）：戰場特效（不含跳字）同時最多 FX_CAP 個。超過時先丟優先權低、最舊的；關鍵（2）不丟。
const FX_CAP := 40
const FX_PRIO := {"dust": 0, "slash": 1, "arrow": 1, "ripple": 1, "aim": 1, "hide": 1, "trip": 2, "shard": 2, "flash": 2, "vslash": 2,
	"taunt": 2, "bang": 2, "puff": 1, "hex": 2}
var fx_dropped := 0

var fx_deduped := 0

func _add_fx(d: Dictionary) -> void:
	if bool(Save.s("reduce_fx")) and d["kind"] in ["dust", "puff", "shard", "ripple", "note", "hex", "aim", "trip", "spore", "wool", "soulrise"]:
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
	var free_f: bool = rules != null and rules.is_free() and (mode == Mode.VS_AI or mode == Mode.DUEL)   # 第六輪：自由排兵不畫格子
	draw_rect(Rect2(ORIGIN - Vector2(10, 10), FIELD + Vector2(20, 20)), Color("#5b4632"))
	for r in 9:
		for c in 16:
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
	draw_rect(Rect2(ORIGIN, FIELD), Color(0.06, 0.09, 0.16, 0.18))
	# 地面層次（第三輪 M2）：固定位置的明暗草塊與小花，畫在格線與單位底下
	for i in 22:
		var h := absi((i * 2654435761) ^ 0x5bd1e995) % 100000
		var pc := ORIGIN + Vector2(float(h % 1000) / 1000.0 * FIELD.x, float((h / 1000) % 100) / 100.0 * FIELD.y)
		var rr := 40.0 + float(h % 37) * 2.0
		draw_set_transform_matrix(_cam * Transform2D(0, Vector2(1.0, 0.55), 0, pc))
		draw_circle(Vector2.ZERO, rr, Color(1, 1, 0.8, 0.045) if i % 2 == 0 else Color(0, 0.08, 0, 0.07), true, -1.0, true)
	draw_set_transform_matrix(_cam)
	var fl := [Color("#fff3b0"), Color("#ffb3c6"), Color("#cdb4ff"), Color("#ffffff")]
	# 第七輪 D2：一條踩出來的小路＋石頭群；小花少一點，免得和兵搶眼
	var path_pts := PackedVector2Array()
	for k5 in 17:
		path_pts.append(ORIGIN + Vector2(k5 * CS, FIELD.y * 0.5 + sin(k5 * 0.7) * 34.0))
	draw_polyline(path_pts, Color(0.55, 0.42, 0.24, 0.13), 40.0, true)
	draw_polyline(path_pts, Color(0.62, 0.5, 0.3, 0.10), 22.0, true)
	for i3 in 7:
		var h3 := absi((i3 * 92821 + 13) * 689287499) % 1000003
		var rp := ORIGIN + Vector2(float(h3 % 991) / 991.0 * FIELD.x, float((h3 / 991) % 977) / 977.0 * FIELD.y)
		for q2 in 3:
			var rr2 := Vector2(q2 * 7.0 - 7.0, (q2 % 2) * 3.0)
			draw_circle(rp + rr2 + Vector2(0, 1.5), 5.0 - q2 * 0.7, Color(0, 0, 0, 0.18), true, -1.0, true)
			draw_circle(rp + rr2, 5.0 - q2 * 0.7, Color(0.62, 0.62, 0.58, 0.55), true, -1.0, true)
	for i in 20:
		var h2 := absi((i * 40503 + 7) * 2246822519) % 1000003
		var fp := ORIGIN + Vector2(float(h2 % 997) / 997.0 * FIELD.x, float((h2 / 997) % 991) / 991.0 * FIELD.y)
		var fc: Color = fl[i % fl.size()]
		for k in 4:
			var an := k * PI / 2.0 + i
			draw_circle(fp + Vector2(cos(an), sin(an)) * 2.2, 1.8, Color(fc, 0.75), true, -1.0, true)
		draw_circle(fp, 1.3, Color("#f4a300"), true, -1.0, true)
	if not free_f:
		for i in 17:
			draw_line(ORIGIN + Vector2(i * CS, 0), ORIGIN + Vector2(i * CS, FIELD.y), Color(0, 0, 0, 0.07), 1)
		for i in 10:
			draw_line(ORIGIN + Vector2(0, i * CS), ORIGIN + Vector2(FIELD.x, i * CS), Color(0, 0, 0, 0.07), 1)
		draw_dashed_line(ORIGIN + Vector2(6 * CS, 0), ORIGIN + Vector2(6 * CS, FIELD.y), Color(Art.team_color(0, cbm()), 0.75), 3.0, 8.0)
		draw_dashed_line(ORIGIN + Vector2(10 * CS, 0), ORIGIN + Vector2(10 * CS, FIELD.y), Color(Art.team_color(1, cbm()), 0.75), 3.0, 8.0)
	# 第七輪 D2：木框內側陰影
	for k6 in 3:
		var sh := Color(0, 0, 0, 0.12 - k6 * 0.035)
		var ii := float(k6 * 3)
		draw_rect(Rect2(ORIGIN + Vector2(ii, ii), Vector2(FIELD.x - ii * 2.0, 3.0)), sh)
		draw_rect(Rect2(ORIGIN + Vector2(ii, ii), Vector2(3.0, FIELD.y - ii * 2.0)), sh)
		draw_rect(Rect2(ORIGIN + Vector2(FIELD.x - ii - 3.0, ii), Vector2(3.0, FIELD.y - ii * 2.0)), sh)
		draw_rect(Rect2(ORIGIN + Vector2(ii, FIELD.y - ii - 3.0), Vector2(FIELD.x - ii * 2.0, 3.0)), sh)
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
	var fsz := tcap(ts(size), cap)
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
	var fs := tcap(ts(size), 17)
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
	_draw_v8_ground(s, live)
	# 第一層：腳底標記與影子（全部先畫，不會被別人的身體整個蓋住時也看得到外圈）
	for u in list:
		var p0: Vector2 = _upos(u) if live else ORIGIN + Vector2(u.x, u.y) * CS / 1000.0
		_ring(p0, u.team, u.type, UNIT_SCALE)
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
	# 第二層：身體
	for u in list:
		var p: Vector2 = _upos(u) if live else ORIGIN + Vector2(u.x, u.y) * CS / 1000.0
		var moving: bool = u.mx != 0 or u.my != 0
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
		if state == St.RESULT and live and sim != null and u.team == sim.winner:
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
		var run := 1.6 if u.type == D.CAVALRY else (1.4 if u.type == D.ASSASSIN or u.type == F8.SHEEP else 1.0)   # 快的兵跑步節奏也快
		if u.stealth > 0:
			# 潛行：身後兩道暗紫殘影
			for g in 2:
				var gp := p + Vector2(-(8 + g * 8) * face, 0)
				draw_circle(gp + Vector2(0, -22), 11.0 - g * 2.0, Color(0.3, 0.15, 0.45, 0.22 - g * 0.08), true, -1.0, true)
				_unit(gp, u.type, u.team, face, 0.0, 0.0, 0.0, 0.14 - g * 0.06, time, UNIT_SCALE)
		_unit(p, u.type, u.team, face, (time * 10.0 * run + u.id) if moving else 0.0, at, hurt, alpha, time, UNIT_SCALE, mood, lean, crouch, variant)
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
			# 雙層描邊（第三輪 V4）：深色底 4px＋亮芯
			for pair in [[Vector2(-14, -14), Vector2(14, 14)], [Vector2(-14, 14), Vector2(14, -14)]]:
				draw_line(p0 + pair[0] * (1 + k), p0 + pair[1] * (1 + k), Color(Art.OUT, 0.8 * (1 - k)), 8, true)
				draw_line(p0 + pair[0] * (1 + k), p0 + pair[1] * (1 + k), Color(c2, 1 - k), 4, true)
				draw_line(p0 + pair[0] * (1 + k), p0 + pair[1] * (1 + k), Color(1, 1, 1, 0.7 * (1 - k)), 1.5, true)
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
				draw_circle(f["p"] + Vector2(cos(an10) * (14.0 - k * 8.0), -k * 38.0 + sin(an10) * 6.0), 5.0 * (1.0 - k), Color(0.72, 0.42, 1.0, 0.9 * (1.0 - k)), true, -1.0, true)
		"swirl":
			var maxr := float(F8.CAT_R) * CS / 1000.0
			for i11 in 3:
				var ph11 := fmod(k * 1.5 + i11 * 0.33, 1.0)
				var r11 := maxr * (1.0 - ph11)
				draw_arc(f["p"], r11, ph11 * 6.0, ph11 * 6.0 + 4.2, 26, Color(0.6, 0.85, 1.0, 0.7 * ph11), 3.0, true)
		"stompring":
			draw_set_transform_matrix(_cam * Transform2D(0, Vector2(1, 0.55), 0, f["p"]))
			var sr := 14.0 + k * float(F8.GOLEM_R) * CS / 1000.0
			draw_arc(Vector2.ZERO, sr, 0, TAU, 36, Color(Art.OUT, 0.6 * (1.0 - k)), 8.0, true)
			draw_arc(Vector2.ZERO, sr, 0, TAU, 36, Color(0.85, 0.78, 0.6, 1.0 - k), 5.0, true)
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
					draw_rect(r3, Color(0.047, 0.059, 0.086, 0.72 * col.a))   # 半透明黑膠囊底（補血的綠字不加底，第四輪）
				var sz := int(ts(f["size"]) * (1.0 + float(f.get("pop", 0.0)) * 1.4))
				if f.get("plain", false):
					_text(p3, f["s"], sz, col, true, true, 0.0, Color(0.05, 0.2, 0.08, col.a))   # 補血綠字加深墨綠描邊
				else:
					_text(p3, f["s"], sz, col, true, true)   # 外框與實際畫的字同一份幾何


# ── 戰鬥 HUD ──
func _draw_battle_hud() -> void:
	draw_rect(Rect2(0, 0, 1280, 86), UI_BG)
	# 第五輪：左上和擺放畫面一樣——模式（粗）＋局數比分（小字），不再放遊戲標題（大字時會換行壓到棋盤）
	_text(Vector2(16, 6), L.t("menu_duel") if mode == Mode.DUEL else _mode_label(), tz("S"), Color(1, 1, 1, 0.75), false, true, 300)
	if mode == Mode.VS_AI or mode == Mode.DUEL:
		_text(Vector2(16, 6 + tz("S") * 1.35), "%s　%s" % [L.t("round", [round_no]), L.t("score", [wins[0], wins[1]])], tz("C"), Color(1, 1, 1, 0.6), false, false, 300)
	var p0: int = view.power(0)
	var p1: int = view.power(1)
	var f0: float = float(p0) / view.budget_of(0)
	var f1: float = float(p1) / view.budget_of(1)
	var bx := 330.0
	var bw := 620.0
	var split := bw * f0 / maxf(0.001, f0 + f1)
	draw_rect(Rect2(bx - 2, 40, bw + 4, 26), Art.OUT)
	draw_rect(Rect2(bx, 42, split, 22), Art.team_color(0, cbm()))
	draw_rect(Rect2(bx + split, 42, bw - split, 22), Art.team_color(1, cbm()))
	draw_line(Vector2(bx + bw / 2, 36), Vector2(bx + bw / 2, 70), Color(1, 1, 1, 0.7), 2)
	# 戰力條狀態（第三輪 V6）：狂熱整條加橘框；背水那端加火焰圖示與脈衝框
	if view.frenzy and not view.finished:
		draw_rect(Rect2(bx - 4, 38, bw + 8, 30), Color(1, 0.45, 0.1, 0.7 + 0.3 * sin(time * 6)), false, 3)
	for tm2 in 2:
		if view.rally[tm2] and not view.finished:
			var ex := bx if tm2 == 0 else bx + bw - 40
			draw_rect(Rect2(ex, 42, 40, 22), Color(1, 0.5, 0.15, 0.35 + 0.25 * sin(time * 8)), false, 2.5)
			_flame(Vector2(ex + 20 + (-30 if tm2 == 0 else 30), 53), 1.0)
	# 色盲配色的亮橘底用深色字（對比 ≥7:1）
	var lc := Color.WHITE
	var rc := Color("#141820") if cbm() else Color.WHITE
	_text(Vector2(bx + 8, 42), "%d%%" % roundi(p0 * 100.0 / (view.budget_of(0) * 1000)), ts(15), lc, false, true)
	var rt := "%d%%" % roundi(p1 * 100.0 / (view.budget_of(1) * 1000))
	_text(Vector2(bx + bw - 8 - font_bold.get_string_size(rt, HORIZONTAL_ALIGNMENT_LEFT, -1, ts(15)).x, 42), rt, ts(15), rc, false, true, 0.0, Color(1, 1, 1, 0.0) if cbm() else Color(0, 0, 0, -1))   # 深色字不加黑描邊（Antigravity S2 #1）
	_text(Vector2(bx - 70, 42), L.t("units_left", [view.alive_count(0)]), ts(15), Art.team_color(0, cbm()), false, false, 64)
	_text(Vector2(bx + bw + 12, 42), L.t("units_left", [view.alive_count(1)]), ts(15), Art.team_color(1, cbm()), false, false, 70)
	for tm in 2:
		if view.rally[tm] and not view.finished:
			var rx := bx - 70.0 if tm == 0 else bx + bw + 12.0
			_text(Vector2(rx, 66), L.t("rally"), ts(13), Color(1, 0.55 + 0.2 * sin(time * 8), 0.3), false, true)
	# 第八輪：生兵戰力 0（時間到不灌水），畫面用副刻度講清楚
	for tm3 in 2:
		var sn := 0
		for su in view.units:
			if su.alive and su.summon and su.team == tm3:
				sn += 1
		if sn > 0:
			_text(Vector2(bx - 70.0 if tm3 == 0 else bx + bw + 12.0, 66), L.t("summon_n", [sn]), ts(13), Art.team_color(tm3, cbm()), false, false, 80)
	var secs := maxi(0, (view.max_ticks - view.tick + 19) / 20)   # 第五輪：一局時間可調（原本寫死 90 秒）
	_text(Vector2(640, 4), L.t("secs", [secs]) + ("　" + L.t("frenzy") if view.frenzy else ""), ts(22), Color.ORANGE_RED if view.frenzy else Color.WHITE, true, true)
	if mode == Mode.VS_AI and ai_name != "":
		_text(Vector2(bx + bw - 120, 68), "AI：%s" % ai_name, ts(11), Color(1, 1, 1, 0.55))
	if state == St.BATTLE and bool(Save.s("playtest")):
		if pt_call_tick < 0:
			_btn(Rect2(780, 2, 162, 36), L.t("pt_call"), func(): pt_call_tick = view.tick; _toast(L.t("pt_called", [view.tick / 20])))
	if state == St.BATTLE:
		if play_kind != "official":
			_btn(Rect2(1010, 6, 120, 38), L.t("back"), func(): call("_replay_back"))   # 第七輪 A9：立刻回上一個畫面
		else:   # 重播／覆盤用底部的控制列，不重複放倍速鈕（Antigravity S5）
			_btn(Rect2(950, 2, 52, 36), "▶" if paused else "Ⅱ", func(): call("_toggle_pause"))   # 第七輪 A6
			_btn(Rect2(1010, 6, 120, 38), L.t("speed", [_fmt_num(speed)]), func(): speed = 2.0 if speed == 1.0 else (4.0 if speed == 2.0 else (0.5 if speed == 4.0 else 1.0)))
		_btn(Rect2(1138, 6, 132, 38), L.t("skip"), func(): _on_skip())


## 這場用到的新兵才烘圖（含生出來的兵）；舊 10 種開遊戲就有。
func _ensure_sprites(armies_: Array) -> void:
	if sprites == null:
		return
	var need := {}
	for a in armies_:
		for u in a.units:
			var t: int = int(u["type"])
			if t >= D.COUNT:
				need[t] = true
				if t == F8.SLIME:
					need[F8.MINI_SLIME] = true
				if t == F8.BONE:
					need[F8.SKELETON] = true
	if not need.is_empty():
		sprites.ensure(need.keys())

## 開一場戰鬥（S8 從 game_screens 移下來：重播、覆盤、截圖都會用到）
func _begin_battle(a0, a1, kind := "official") -> void:
	play_kind = kind
	_ensure_sprites([a0, a1])
	if kind == "official":
		last_armies = [a0.copy(), a1.copy()]
		battle_rules = rules.copy() if rules != null else null
	sim = Sim.new(a0, a1, battle_rules)
	view = ViewBuffer.new(sim)
	atk_seq.clear()
	clutch_tick = -1
	replay_total = 0
	if kind != "official":
		# 重播／覆盤：先用確定性模擬算出整場長度，時間軸以實際秒數為滿（Antigravity S5）
		var pre = Sim.new(a0.copy(), a1.copy(), battle_rules)
		pre.fast = true
		pre.run_to_end()
		replay_total = pre.tick
	paused = false
	follow_id = -1
	battle_marks.clear()
	report_log.clear()
	skip_busy = false
	seek_target = -1
	if kind == "official":
		replay_snap = {}
	start_hold = 0.0
	if kind == "official" and shot_dir == "" and DisplayServer.get_name() != "headless" and not bool(Save.s("reduce_fx")):
		start_hold = 1.0
		if sfx != null:
			sfx.play("bugle", 0.8)
	graves.clear()
	clutch_t = 0.0
	atk_hit.clear()
	alt_hit.clear()
	bomb_tgt.clear()
	brace_t.clear()
	state = St.BATTLE
	prev_pos.clear()
	for u in view.units:
		prev_pos[u.id] = Vector2(u.x, u.y)
	_pump_view()   # 開場先預填 DELAY 個 tick
	accum = 0.0
	slow_used = false
	slow_left = 0.0
	hitstop = 0.0
	zoom = 1.0
	zoom_target = 1.0
	fx.clear()
	dying.clear()
	atk_t.clear()
	hurt_t.clear()
	ev_count = {}
	frenzy_seen = false
	result_delay = 0.0
	pt_call_tick = -1
	pt_rated = false
	_focus = 0
	speed = float(Save.s("speed"))
	sfx.play("start")
	sfx.play_music("music_battle")
