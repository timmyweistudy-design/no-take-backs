extends "res://scripts/ui/battle/battle_units.gd"
## 其他層在同資料夾（V9 P1 拆檔）

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


func _battle_process(delta: float) -> void:
	if view != null:
		_gait_frame(delta)   # 不能放在只有部分情況才跑的地方（Codex P2 #1）
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
		zoom_center = zoom_center.lerp(ORIGIN + fld_size / 2, minf(1.0, delta * 3))
	zoom = lerpf(zoom, zoom_target, delta * 3)
	if view.finished:
		result_delay += delta
		if result_delay > 1.4:
			on_battle_finished.call()



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
	_gait_tick(with_fx)
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
			if k == EV.BLAST and not ev.has("dmg"):   # 第八輪：爆炸演出一筆一次；逐目標傷害不算次數（BOOM_5）
				ev_count["blast_fx%d" % s.team] = int(ev_count.get("blast_fx%d" % s.team, 0)) + 1
		if k == EV.DEATH:
			deaths += 1
		_collect_mark(ev, view, view.tick)
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
	# 第八輪：生兵戰力 0（時間到不灌水），隻數用「本隊＋召喚」講清楚
	var sn := [0, 0]
	for su in view.units:
		if su.alive and su.summon:
			sn[su.team] += 1
	for tm0 in 2:
		var cnt0: int = view.alive_count(tm0) - sn[tm0]
		var lb0: String = L.t("units_left", [cnt0]) if sn[tm0] == 0 else "%s＋%d" % [L.t("units_left", [cnt0]), sn[tm0]]
		# 左邊靠條尾對齊、右邊靠條頭對齊，留出火焰位置；不限寬（大字級「8 隻＋1」不換行）
		var lb_w: float = font_bold.get_string_size(lb0, HORIZONTAL_ALIGNMENT_LEFT, -1, ts(15)).x
		if tm0 == 0 and lb_w > bx - 22.0 - HUD_LEFT_END and sn[tm0] > 0:   # 英文大字級擠不下就只留數字，別撞到左上的比分
			lb0 = "%d＋%d" % [cnt0, sn[tm0]]
			lb_w = font_bold.get_string_size(lb0, HORIZONTAL_ALIGNMENT_LEFT, -1, ts(15)).x
		_text(Vector2(bx - 22 - lb_w if tm0 == 0 else bx + bw + 22, 42), lb0, ts(15), Art.team_color(tm0, cbm()))
	for tm in 2:
		if view.rally[tm] and not view.finished:
			var rx := bx - 70.0 if tm == 0 else bx + bw + 12.0
			_text(Vector2(rx, 66), L.t("rally"), ts(13), Color(1, 0.55 + 0.2 * sin(time * 8), 0.3), false, true)
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
	_gait_reset()
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
