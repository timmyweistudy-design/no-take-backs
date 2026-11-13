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


## 第十輪 I4：重播的全長在背景算，算完才開始播。
func _pre_join() -> void:
	if pre_thread != null:
		var v = pre_thread.wait_to_finish()
		pre_thread = null
		if v is Array:
			replay_total = int(v[0])
			replay_bm = v[1]

## 不要等：還在算就留給 _pre_reap 收。
func _pre_drop() -> void:
	if pre_thread != null:
		pre_old.append(pre_thread)
		pre_thread = null

func _pre_reap() -> void:
	for i in range(pre_old.size() - 1, -1, -1):
		if not pre_old[i].is_alive():
			pre_old[i].wait_to_finish()
			pre_old.remove_at(i)

func _exit_tree() -> void:
	if has_method("_rv_exit"):
		call("_rv_exit")   # 1.1.0 H1：覆盤重算、GIF 先叫停再等
	bg.drain()   # 1.1.0 N6：覆盤、GIF、教練、三考、出題碼的背景工作：全部叫停再等（各自 64 tick／每格內會停）
	_pre_join()
	_pre_drop()
	for th in pre_old:
		th.wait_to_finish()
	pre_old.clear()
	if ai_thread != null:
		ai_thread.wait_to_finish()
		ai_thread = null

func _battle_process(delta: float) -> void:
	if pre_thread != null:
		if pre_thread.is_alive():
			return
		_pre_join()
	if view != null:
		_gait_frame(delta)   # 不能放在只有部分情況才跑的地方（Codex P2 #1）
	if start_hold > 0.0:
		var ph0 := 1.0 - start_hold
		start_hold -= delta
		var ph1 := 1.0 - start_hold
		for at in [0.25, 0.55, 0.85]:   # 1.2.0 §9.1：三段落子各一聲厚重落子聲（全場只有 3 聲）
			if ph0 < at and ph1 >= at and sfx != null:
				sfx.play("place_heavy", 0.75)
		return
	if call("_seek_pump"):
		return
	if _hl_reel_tick():
		return   # 1.3.0 §2 精華三連：換段開始跳轉，這一幀不再推進（Codex cat06 #1）
	if skip_busy:
		_skip_step()
		return
	if paused:
		return
	if hitstop > 0:
		# 1.2.0 §9.6 展示時鐘：停頓期間欠下的模擬 tick（只算真的停頓的那段、照停頓當下的倍速換算）
		var used := minf(delta, hitstop)
		present_debt += used * speed / 0.05
		freeze_t += used   # 1.4.0：配件等只看展示時間的動畫也一起停（Codex cat05 #8）
		hitstop -= delta
		if hitstop > 0:
			return
		hitstop = 0.0
		delta -= used      # 停頓在這一幀中間結束：剩下的時間照常推進（不丟掉，Codex cat05 #8）
	var rate := speed
	if present_debt > 0.0 and slow_left <= 0 and final_left <= 0:
		if present_debt > 20.0:
			# 落後超過 1 秒（20 tick）：不播演出直接追上（事件照常記進戰報與書籤；最後時刻只記狀態不演）
			var nskip := int(present_debt)
			for _i in nskip:
				if view.finished:
					break
				_sim_step(false)
			present_debt = 0.0
		else:
			var extra := minf(delta * speed * 0.5 / 0.05, present_debt)   # 追回：最多 1.5 倍速
			accum += extra * 0.05
			present_debt -= extra
	if slow_left > 0:
		rate *= 0.5
		slow_left -= delta
	if final_left > 0:
		rate *= 0.25      # 第十輪 F1：最後一擊
		final_left -= delta
		_update_action_focus()
	accum += delta * rate
	while accum >= 0.05 and not view.finished:
		accum -= 0.05
		var was_slow := slow_left > 0 or final_left > 0
		_sim_step(true)
		if (slow_left > 0 or final_left > 0) and not was_slow:
			break   # 這一 tick 觸發慢動作：剩下的累積留到下一幀用慢速消耗（Codex S8 #3）
		if hitstop > 0:
			break   # 1.4.0：這一 tick 觸發頓幀，剩下的累積等停完再消耗（Codex cat05 #8）
	# 播完之後展示時鐘繼續走（不再推進快照）：最後一格的位置插值與最後一擊的後搖要演完（Codex R5 #1）
	# 最後時刻只在 _sim_step 每個畫面 tick 判定（Codex S8 #1：每幀也判會讓觸發 tick 跟幀率有關）
	if slow_left > 0:
		_update_action_focus()
	# 1.3.0 §2 最後一擊的抽離感：環境低通壓到約 400Hz、畫面去飽和 25%，0.4 秒回彈（減少特效時慢動作本來就不開）
	sfx.set_muffled((slow_left > 0 or final_left > 0) and not view.finished, 400.0 if final_left > 0 else 900.0)
	desat_a = 0.25 if final_left > 0 else move_toward(desat_a, 0.0, delta * 0.25 / 0.4)
	_spot_update(delta)
	_pad_cam(delta)
	# 分軌音樂依戰況混音（第三輪 S1）
	var close := absf(view.power(0) * 100.0 / (view.budget_of(0) * 1000) - view.power(1) * 100.0 / (view.budget_of(1) * 1000)) <= 15.0
	sfx.set_layer_targets(sfx.layer_targets(close, slow_left > 0 and not view.finished))
	if sfx.has_method("set_room_tense"):
		sfx.set_room_tense(close or slow_left > 0)   # 1.3.0 §10：戰況緊時遠景低通
	# 鏡頭只有一個決策點（Codex S5 #6）：跟拍優先於最後時刻框選，兩者都沒有才回到全景
	if follow_id >= 0:
		pass   # 由 _follow_update 決定
	elif pinch_zoom > 1.01:
		zoom_target = pinch_zoom   # V1.4 #18：玩家用雙指放大，就停在那裡（1.3.0：手動優先於最後時刻框選，Codex cat06 #5）
		zoom_center = zoom_center.lerp(pinch_center, minf(1.0, delta * 6))
	elif _dir_on() and time < dir_hot_until and not view.finished:
		_director_cam(delta)   # 1.4.0 §2.5 仲裁：技能推近（只重播）> 最後時刻框選（Codex cat05 #7）
	elif slow_left > 0 and not view.finished and bool(Save.s("clutch_zoom")) and not bool(Save.s("reduce_motion")):   # V1.5：最後時刻自動放大可關
		_frame_alive(delta)
	elif _dir_on():
		_director_cam(delta)   # 1.3.0 §2 自動導播（重播、觀戰）
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



## 第十輪 F1：模擬領先畫面 DELAY 個 tick，已知全滅就在倒下前放慢。和局、逾時、同歸於盡都不演。
func _check_final(with_fx: bool) -> void:
	if final_used or not with_fx or not sim.finished or sim.winner < 0 or sim.reason != "全滅":
		return
	final_used = true
	if _fx_on("slowmo"):
		final_left = 0.6
	if _fx_on("shake"):
		shake = maxf(shake, 0.15)

## 畫面前進一個 tick：模擬保持領先 DELAY 個 tick，畫面播最舊的那一份快照（R5 展示緩衝）。
func _sim_step(with_fx: bool) -> void:
	_pump_view()
	_check_final(with_fx)
	for u in view.units:
		prev_pos[u.id] = Vector2(u.x, u.y)
	if not view.advance():
		view.finished = true
		return
	if tm_ghost != null:
		call("_tm_sync")
	_gait_tick(with_fx)
	_status_tags(with_fx)   # 1.3.0 §7.1 狀態竹籤
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
		var s = view.unit_by_id(ev["src"]) if ev.has("src") else null
		if s != null:   # V1.4 #10：沙盤機關的事件沒有來源單位（src＝-1）
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
			if e["kind"] == EV.CHARGE or e["kind"] == EV.BRACED:
				_cue_add(str(e["kind"]), int(e.get("src", -1)), int(e.get("tgt", -1)), int(fr["tick"]))   # 1.3.0 §7.1 預告
			if e.get("tags", []).has(EV.EXT_FIRE):
				continue   # 1.2.0 火矢的小火：不是射手出手，不排拉弓、飛箭（Codex cat09 #1）
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
				var su = view.unit_by_id(e["src"]) if not view.units.is_empty() else null
				var st_ty: int = int(su.type) if su != null else -1
				if e["kind"] == EV.BOMB or e["kind"] == EV.HEAL or (proj_fly(st_ty) > 0 and st_ty != D.MEDIC and event_route(e) == "attack" and e["kind"] != EV.SPLASH and e["kind"] != EV.BONK):
					# V1.5：遠程記下命中 tick → 目標；畫面在命中前把飛行物從手上飛到目標，命中那一刻剛好到（第四輪的火罐延伸到全部遠程）
					var bt: Dictionary = proj_tgt.get(e["src"], {})
					bt[int(fr["tick"])] = e["tgt"]
					if bt.size() > 6:
						bt.erase(bt.keys().min())
					proj_tgt[e["src"]] = bt
				# 每隻單位的第幾次出手（交替招式用，Codex S4 #2：原本用 tick 奇偶，連續反擊會同招）
				var sq: Dictionary = atk_seq.get(e["src"], {})
				sq[int(fr["tick"])] = sq.size()
				atk_seq[e["src"]] = sq   # 存序列，不覆蓋還沒播到的命中（Codex R5 #2：連續反擊）
				if hs.size() > 8:
					hs.pop_front()   # V1.5：緩衝拉長到 8 tick，留 8 筆才不會把還在飛的那發擠掉
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



## V1.1 B2：這一關「斬首」目標的單位 id（不是斬首關＝-1）。id 規則同 PZ.unit_alive。
func _goal_target_id() -> int:
	var pz := PZ.get_puzzle(puzzle_id)
	if pz.is_empty() or PZ.goal(pz) != "kill" or not pz.has("goal_unit"):
		return -1
	return 1000 + int(pz["goal_unit"][1]) * Sim.COLS + int(pz["goal_unit"][0])

## V1.1 A7：兵種專屬的倒下演出（骷髏散骨、寶箱怪吐金幣、史萊姆濺開、爆爆羊留焦痕、幽靈化煙）。
func _death_extra(u) -> void:
	var p := _upos(u)
	match u.type:
		17, 21:
			_add_fx({"kind": "bones", "p": p + Vector2(0, -16), "t": 0.0, "dur": 0.7})
		12:
			_add_fx({"kind": "coins", "p": p + Vector2(0, -20), "t": 0.0, "dur": 0.8})
		13, 20:
			_add_fx({"kind": "chips", "p": p + Vector2(0, -14), "t": 0.0, "dur": 0.5, "c": Color(0.45, 1.0, 0.55, 0.85), "drop": true})
		14:
			_add_fx({"kind": "puff", "p": p + Vector2(0, -24), "t": 0.0, "dur": 0.5})
		19:
			_add_fx({"kind": "chips", "p": p + Vector2(0, -20), "t": 0.0, "dur": 0.6, "c": Color("#a89a86")})

var last_blast_tick := -99   # V1.1 B2：連環爆偵測（用模擬 tick，8 tick＝0.4 秒；開戰與跳轉時重置）

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
			_report_add(s.team, s.type, k, L.t("ev_voodoo"), Color("#ff6bb0"), s)
		EV.BLAST:
			if s.id != t.id:
				hurt_t[t.id] = time
				hurt_dir[t.id] = signf(tp.x - sp.x) if tp.x != sp.x else 0.0
			else:
				var small: bool = ev.get("small", false)
				_add_fx({"kind": "boom", "src": s.id, "p": sp + Vector2(0, -8), "t": 0.0, "dur": 0.45, "big": not small})
				_add_fx({"kind": "wool", "p": sp + Vector2(0, -18), "t": 0.0, "dur": 0.6})
				_stain(sp, (F8.DEATH_BLAST_R if small else F8.BLAST_R) * CS / 1000.0, false, view.tick * 31 + s.id)
				sfx.play("boom", 0.8)
				sfx.play("baa", 0.6)
				if _fx_on("shake"):
					shake = 0.1
				# V1.1 B2：連環爆（0.4 秒內第二顆起）短頓格，看得出是一串連鎖
				if view.tick - last_blast_tick <= 8 and _fx_on("shake"):
					hitstop = maxf(hitstop, 0.06)
				last_blast_tick = view.tick
				_report_add(s.team, s.type, k, L.t("ev_blast"), Color("#ffb347"), s)
		EV.BITE:
			atk_t[s.id] = time
			hurt_t[t.id] = time
			hurt_dir[t.id] = signf(tp.x - sp.x) if tp.x != sp.x else 0.0
			_add_fx({"kind": "chomp", "p": tp + Vector2(0, -28), "t": 0.0, "dur": 0.35})
			sfx.play("chomp", 0.9)
			_report_add(s.team, s.type, k, L.t("ev_bite"), Color("#ffd166"), s)
		EV.MIMIC_OPEN:
			_add_fx({"kind": "puff", "p": sp + Vector2(0, -20), "t": 0.0, "dur": 0.4})
			_add_fx({"kind": "chips", "p": sp + Vector2(0, -14), "t": 0.0, "dur": 0.35, "c": Color("#ffd166"), "spark": true})   # 1.1.0 A7：開箱縫隙金光
			sfx.play("reveal", 0.7)
		EV.SPLIT:
			_add_fx({"kind": "puff", "p": sp + Vector2(0, -12), "t": 0.0, "dur": 0.3})
			_add_fx({"kind": "chips", "p": sp + Vector2(0, -8), "t": 0.0, "dur": 0.35, "c": Color(0.45, 1.0, 0.55, 0.85), "drop": true})   # 1.1.0 A7：小史萊姆落地濺點
			_add_fx({"kind": "slimehop", "p": sp, "dir": 1.0 if s.id % 2 == 0 else -1.0, "t": 0.0, "dur": 0.25})   # 1.1.0 A7：從母體彈出半圈、落地壓扁回彈（只畫殘影弧，出生座標照模擬）
			sfx.play("squish", 0.5)
			_report_add(s.team, 13, k, L.t("ev_split"), Color("#7dffa0"), s)
		EV.CAST:
			# V1.1 A6：大招前搖依技能配音（共用合成音，音量分層）
			sfx.play("charge_up", 0.5)
			match str(ev.get("skill", "")):
				EV.STOMP:
					sfx.play("stomp", 0.3)
				EV.VACUUM:
					sfx.play("vacuum", 0.35)
				EV.TIMESTOP:
					sfx.play("bell", 0.35)
				EV.RAISE:
					sfx.play("raise", 0.3)
					_add_fx({"kind": "pages", "p": sp + Vector2(10 * (1.0 if s.team == 0 else -1.0), -34), "t": 0.0, "dur": 0.4})   # 1.1.0 A7：骷髏法師施法翻書兩頁
		EV.TIMESTOP:
			_add_fx({"kind": "timebell", "p": sp + Vector2(0, -20), "t": 0.0, "dur": 0.8})
			sfx.play("bell", 1.0)
			sfx.play("timestop", 0.9)
			_report_add(s.team, s.type, k, L.t("ev_timestop"), Color("#ffe08a"), s)
		EV.RAISE:
			_add_fx({"kind": "soulrise", "p": sp + Vector2(0, -16), "t": 0.0, "dur": 0.6})
			_add_fx({"kind": "bonesup", "p": sp + Vector2(0, -20), "t": 0.0, "dur": 0.15})   # 1.1.0 A7：骷髏出生 0.15 秒骨頭往中間拼起來（實體照模擬，不延後）
			sfx.play("raise", 0.8)
			_report_add(s.team, 17, k, L.t("ev_raise"), Color("#c77dff"), s)
		EV.VACUUM:
			_add_fx({"kind": "swirl", "p": sp + Vector2(0, -14), "t": 0.0, "dur": 0.6})
			sfx.play("vacuum", 0.8)
			_report_add(s.team, s.type, k, L.t("ev_vacuum"), Color("#9ad1ff"), s)
		EV.STOMP:
			_add_fx({"kind": "stompring", "p": sp, "t": 0.0, "dur": 0.45})
			_stain(sp, F8.GOLEM_R * CS / 1000.0, true, view.tick * 31 + s.id)   # 踩地＝茶漬
			sfx.play("stomp", 0.9)
			if _fx_on("shake"):
				shake = 0.14
			_report_add(s.team, s.type, k, L.t("ev_stomp"), Color("#d9c9a3"), s)
		EV.ROCK:
			sfx.play("shatter", 0.7)
			_add_fx({"kind": "chips", "p": sp + Vector2(0, -10), "t": 0.0, "dur": 0.4, "c": Color("#8a8276")})   # 1.1.0 A7：碎石暗灰
	return true



# ── 第十二輪手動技能 ──
func _cmd_setup(s, kind: String) -> void:
	if not s.cmd_on:
		return
	if kind == "official" and mode == Mode.PUZZLE:
		s.cmd_play(PZ.cmd_log(PZ.get_puzzle(puzzle_id), puzzle_plan))   # 第十三輪：時序殘局照戰前設定的時間放
	elif kind == "official":
		s.cmd_auto = [false, mode == Mode.VS_AI]
	else:
		s.cmd_play(last_cmds)

## 按第 slot 格（這一隊帶的第幾招）。成功回 true。
func _cmd_press(team: int, slot: int) -> bool:
	if sim == null or not sim.cmd_on or play_kind != "official" or sim.finished or mode == Mode.PUZZLE:
		return false
	if team == 1 and mode != Mode.DUEL:
		return false
	var list: Array = CmdD.list_of(int(sim.cmd_mask[team]))
	if slot >= list.size():
		return false
	if sim.cast(team, int(list[slot])):
		sfx.play("k_confirm", 0.8)
		return true
	sfx.play("k_error", 0.7)
	return false

## 鍵盤：藍方 1 2 3（手把 LB、RB 送的是 Q、E），雙人紅方 8 9 0。是技能鍵就回 true。
func _cmd_key(k: int) -> bool:
	if sim == null or not sim.cmd_on or play_kind != "official":
		return false
	var slot: int = {KEY_1: 0, KEY_2: 1, KEY_3: 2, KEY_Q: 0, KEY_E: 1}.get(k, -1)
	if slot >= 0:
		_cmd_press(0, slot)
		return true
	if mode == Mode.DUEL:
		var red: int = {KEY_8: 0, KEY_9: 1, KEY_0: 2}.get(k, -1)
		if red >= 0:
			_cmd_press(1, red)
			return true
	return false

func _cmd_desc(i: int, power: int) -> String:
	return L.t("cmd_d_%d" % i, CmdD.desc_args(i, power))

func _cmd_event(ev: Dictionary, with_fx: bool) -> void:
	if ev["kind"] == EV.CMD_HIT:
		if with_fx:
			var u = view.unit_by_id(ev["tgt"])
			if u != null:
				_fx_text(_upos(u) - Vector2(0, 44), str(int(ev["dmg"])), Color("#ffb347"), 0.7, ts(16))
		return
	var tm := int(ev["team"])
	var sk := int(ev["skill"])
	var dup := false
	for m in battle_marks:
		if m["kind"] == "cmd" and int(m["tick"]) == view.tick and int(m["team"]) == tm and int(m.get("skill", -1)) == sk:
			dup = true   # 跳轉時快轉已經收過這一筆（同 tick 同隊兩招各算一筆）
	if not dup:
		battle_marks.append({"tick": view.tick, "kind": "cmd", "team": tm, "skill": sk})
	if not with_fx:
		return
	sfx.play(["brace", "bugle", "raise", "stomp", "timestop"][sk], 0.9)
	fx = fx.filter(func(f): return f.get("cmd_tm", -1) != tm)     # 一隊同時只留最新一條，不疊字
	_fx_text(Vector2(400.0 if tm == 0 else 880.0, 128), "%s　%s" % [L.t("blue") if tm == 0 else L.t("red"), L.t("cmd_%d" % sk)], Art.team_color(tm, cbm()).lightened(0.45), 1.3, tz("B"), true)   # V1.0.0：0.25 時紅方在動態戰場上對比偶爾 < 3；1.4.0 §6.3：大字橫幅降一級，主角是桌面朱印
	fx[-1]["cmd_tm"] = tm   # 標在橫幅上（要在朱印加進來之前；版面 75_cmd_cd 抓到標錯對象、舊橫幅沒清）
	if not bool(Save.s("plain_ui")):
		_add_fx({"kind": "cmdseal", "p": ORIGIN + fld_size * Vector2(0.25 if tm == 0 else 0.75, 0.5), "t": 0.0, "dur": 0.9, "c": Art.team_color(tm, cbm()).darkened(0.15)})
	if _fx_on("flash"):
		_add_fx({"kind": "cmd_flash", "t": 0.0, "dur": 0.35, "screen": true, "c": Color("#7fd3ff") if sk == CmdD.FREEZE else (Color("#fff0b0") if sk != CmdD.METEOR else Color("#ff8a3c"))})
	if sk != CmdD.METEOR:
		# V1.1 A3：手動技能地面法陣（護盾六角、戰吼紅紋、治療綠十字、冰封冰刺），畫在受影響那隊每隻腳下
		var side := tm if sk != CmdD.FREEZE else 1 - tm
		var pts: Array = []
		for u0 in view.units:
			if u0.alive and u0.team == side and not u0.hidden:
				pts.append(_upos(u0))
		_add_fx({"kind": "sigil", "pts": pts, "sk": sk, "t": 0.0, "dur": 0.9, "c": [Color("#7fd3ff"), Color("#ff6b5b"), Color("#7dff8a"), Color.WHITE, Color("#bfefff")][sk]})
	if sk == CmdD.METEOR and ev.has("x"):
		_add_fx({"kind": "meteor", "p": ORIGIN + Vector2(int(ev["x"]), int(ev["y"])) * CS / 1000.0, "t": 0.0, "dur": 0.6, "r": CmdD.METEOR_R * CS / 1000.0})
		if _fx_on("shake"):
			shake = maxf(shake, 0.2)

func _draw_cmd_bar() -> void:
	var live: bool = play_kind == "official"
	for tm in 2:
		var list: Array = CmdD.list_of(int(sim.cmd_mask[tm]))
		var mine: bool = live and (tm == 0 or mode == Mode.DUEL)
		for i in list.size():
			var s: int = list[i]
			var r := Rect2(8.0 if tm == 0 else 1168.0, 190.0 + i * 112.0, 104.0, 104.0)
			# V1.5.1 B1b：照紀錄施放的局讀畫面快照（長緩衝下 sim 領先 0.4 秒，不能提早跳）；手動局要即時可按，讀 sim
			var snap: bool = bool(sim.cmd_scripted) and not view.cmd_snap.is_empty()
			var c_left: int = int(view.cmd_snap[0][tm][s]) if snap else int(sim.cmd_left[tm][s])
			var c_ready: int = int(view.cmd_snap[1][tm][s]) if snap else int(sim.cmd_ready[tm][s])
			var c_tick: int = view.tick if snap else sim.tick
			var ready: bool = (c_left > 0 and c_tick >= c_ready and not view.finished) if snap else sim.cmd_can(tm, s)
			if mine:
				_btn(r, "", _cmd_press.bind(tm, i), ready, false, TH_WOOD if ready else TH_WOOD_D)
			else:
				_box(r, Color(TH_WOOD_D, 0.85), TH_EDGE, 6.0, 1.0)
			_probe_btn_label = mine
			_probe_btn_rect = r
			_icon(CmdD.ICONS[s], r.position + Vector2(52, 25), 26.0, ACCENT if ready else Color(1, 1, 1, 0.35))   # 1.4.0 R13：上緣留 ≥8px
			_text(r.position + Vector2(52, 40), L.t("cmd_%d" % s), tz("C"), Color.WHITE if ready else TXT_DIM, true, false, 98)   # 1.2.0：字級放大後兩行技能名要放得下（圖示上移、縮一點）
			var left_s := "×%d" % c_left
			_text(Vector2(r.end.x - _width(left_s, tz("C")) - 6, r.position.y + 4), left_s, tz("C"), Color.WHITE)
			if mine:
				var hk: String = ["1", "2", "3"][i] if tm == 0 else ["8", "9", "0"][i]
				if pad_mode and tm == 0 and i < 2:
					hk = _pk("prev" if i == 0 else "next")
				_text(r.position + Vector2(6, 4), hk, tz("C"), TXT_DIM)
			_probe_btn_label = false
			var wait: int = c_ready - c_tick
			if wait > 0 and c_left > 0:
				var phase_len: float = float(CmdD.START_TICKS) if c_ready <= CmdD.START_TICKS else float(sim.cmd_cd)   # 開戰準備期的總長是 START_TICKS，之後是冷卻（Codex v151-i2）
				var frac: float = clampf(float(wait) / maxf(1.0, phase_len), 0.0, 1.0)
				draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * frac)), Color(0, 0, 0, 0.5))

var hud_info_until := -1.0   # 1.2.0：手把 View 叫出情境資訊到這個時間

## V1.6.1 F4（Antigravity v161d r3）：擊倒時手把短震（只在用手把、震動設定開著；0.25 秒內只震一次，大混戰不會一直震）
var kill_rumble_t := -9.0
func _kill_rumble() -> void:
	if not pad_mode or int(Save.s("rumble")) <= 0 or time - kill_rumble_t < 0.25:
		return
	kill_rumble_t = time
	var rk := int(Save.s("rumble")) / 100.0
	Input.start_joy_vibration(last_joy, 0.12 * rk, 0.22 * rk, 0.06)

func _on_event(ev: Dictionary, with_fx: bool) -> void:
	var k: String = ev["kind"]
	if ev.has("src") and ev.has("tgt"):
		last_hitter[int(ev["tgt"])] = int(ev["src"])   # V1.3.1：死亡事件不帶擊倒者，記住每個目標最後被誰打（Codex v131-impl3）
	if k == EV.CMD or k == EV.CMD_HIT:
		_cmd_event(ev, with_fx)
		return
	if k in ["boss_arm", "boss_plate"]:
		if with_fx:
			_fx_text(Vector2(640, 150), L.t("ev_" + k), ACCENT, 1.2, tz("H2"), true)   # V1.4 #12 巨獸部位破壞
			sfx.play("bell", 0.8)
			if _fx_on("shake"):
				shake = maxf(shake, 0.25)
		return
	if k in ["collapse", "fire", "push"]:
		# V1.4 #10 沙盤機關發動：中間一句大字＋音效（不進模擬）
		if with_fx:
			_fx_text(Vector2(640, 150), L.t("ev_" + k), Color("#ffb347") if k != "push" else Color("#f3e3c0"), 1.0, tz("H2"), true)
			sfx.play("bell" if k == "collapse" else ("poison" if k == "fire" else "turn"), 0.6)
			if k == "collapse" and _fx_on("shake"):
				shake = maxf(shake, 0.2)
		return
	if _on_event_v8(ev, k, with_fx):
		return
	if k == EV.DEATH:
		var u = view.unit_by_id(ev["id"])
		if with_fx:
			last_kill = [int(last_hitter.get(int(ev["id"]), -1)), time]   # V1.3.1 P2：最後一擊定格用（誰、什麼時候）
		dying.append({"pos": _upos(u), "type": u.type, "team": u.team, "face": signf(u.fx) if u.fx != 0 else 1.0, "t": 0.0})
		if with_fx:
			sfx.play_unit("death", 0.7, u.type)   # V1.3.1：倒下的聲音依兵種音高
			sfx.play_unit("wood_topple", 0.45, u.type)   # V1.6 #14：木座倒地彈兩下
			_kill_rumble()
			_death_extra(u)
			# V1.1 B2：殘局「斬首」的目標倒下：頓格＋微震＋大字（只動播放，不進模擬）
			if mode == Mode.PUZZLE and _goal_target_id() == int(ev["id"]):
				if not bool(Save.s("reduce_fx")):
					hitstop = maxf(hitstop, 0.3)   # 簡化特效時不頓格（Codex v110-impl2）
				if _fx_on("shake"):
					shake = maxf(shake, 0.18)
				_fx_text(Vector2(640, 150), L.t("ev_behead"), ACCENT, 1.2, tz("H2"), true)
				sfx.play("bell", 0.9)
		return
	if k == EV.HEAL and with_fx:
		# 補血（第四輪 §4.4）：醫者到目標一條淡綠弧線＋綠色「+N」（不加黑底）
		var hs0 = view.unit_by_id(ev["src"])
		var ht0 = view.unit_by_id(ev["tgt"])
		if hs0 != null and ht0 != null:
			_merge_text(ht0.id, EV.HEAL, "+", int(ev["amt"]), _upos(ht0) + Vector2(0, -70), Color("#7dff8a"))
			_add_fx({"kind": "healring", "p": _upos(ht0) + Vector2(0, 2), "t": 0.0, "dur": 0.35})   # 1.1.0 A7：被補的友軍腳下淡綠藥膏環（≤0.3 格）
			_add_fx({"kind": "leaves", "p": _upos(ht0) + Vector2(0, -10), "t": 0.0, "dur": 0.6})   # 1.4.0 §6.2 草葉旋升
			sfx.play("heal", 0.35)
			if _frags_on():
				frags.spawn(_upos(ht0), "leaf", 2, view.tick * 4096 + ht0.id, 30.0)   # 1.2.0 §8.2 薄荷葉片
			if (ev.get("tags", []) as Array).has(EV.RESCUE):
				# 1.2.0 擴充「急救契約」：救起的人頭上一句、醫者停手的那 2 秒頭上有「停手」（觀戰時看得懂為什麼醫者不動）
				_fx_text(_upos(ht0) + Vector2(0, -92), L.t("ev_rescue"), Color("#7dff8a"), 1.0, tz("S"))
				_fx_text(_upos(hs0) + Vector2(0, -84), L.t("ev_rescue_rest"), Color(1, 1, 1, 0.8), 2.0, tz("C"))
				sfx.play("bell", 0.4)
		return
	if k == EV.DRUM and with_fx:
		var dr0 = view.unit_by_id(ev["src"])
		if dr0 != null:
			_add_fx({"kind": "note", "p": _upos(dr0) + Vector2(6, -78), "t": 0.0, "dur": 0.8})
			_add_fx({"kind": "woodwave", "p": _upos(dr0) + Vector2(0, 2), "t": 0.0, "dur": 0.45})   # 1.1.0 A7：鼓手腳下木紋同心波（不幫友軍染色）
		return
	if k == EV.EXT_RIDE:
		if with_fx:
			var rd0 = view.unit_by_id(ev["src"])
			if rd0 != null:
				_add_fx({"kind": "puff", "p": _upos(rd0) + Vector2(0, -6), "t": 0.0, "dur": 0.4})   # 1.2.0 擴充「迴馬」：撤一格揚起的小塵
		return
	var route := event_route(ev)
	if not with_fx and (k == EV.BREACH or ev.get("tags", []).has(EV.BREACH)):
		key_used = true   # V1.3 C4：跳播／直接看結果也要記得第一次破陣已發生（Codex v130-impl2）
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
	if tags.has(EV.EXT_FIRE):
		# 1.2.0 擴充「火矢」：地上的小火燒到（不是射手出手：不畫箭、不讓射手做攻擊動作）
		hurt_t[t.id] = time
		_merge_text(t.id, EV.HIT, "", int(ev["dmg"]), _upos(t) + Vector2(0, -62 * HK), Color("#ff9a5a"))
		_add_fx({"kind": "scorch", "p": _upos(t) + Vector2(0, 2), "t": 0.0, "dur": 0.4})
		if _frags_on():
			frags.spawn(_upos(t), "fire", 3, view.tick * 4096 + t.id, 6.0)
		return
	if tags.has(EV.EXT_GUARD):
		_fx_text(_upos(t) + Vector2(0, -92), L.t("ev_guard"), Color("#ffe08a"), 0.9, tz("S"))   # 1.2.0 擴充「架盾」：這一發被盾擋成 0
	if tags.has(EV.BEAT):
		_add_fx({"kind": "note", "p": _upos(s) + Vector2(0, -78), "t": 0.0, "dur": 0.5})   # 1.2.0 擴充「接拍」：吃到拍點的這一擊，頭上一個音符
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
		_add_fx({"kind": "scorch", "p": tpos + Vector2(0, 2), "t": 0.0, "dur": 0.25})   # V1.0.0 角色：落點焦痕
		_stain(tpos, D.SPLASH_R * CS / 1000.0, false, view.tick * 31 + s.id)   # 1.3.0 §7.1 波及範圍＝墨漬
		sfx.play("boom", 0.55)
	elif k == EV.SPLASH:
		pass   # 波及只靠爆炸圈和受擊閃白，不另外畫砍擊、不印字（Antigravity 第一輪 §6.2）
	elif s.type == D.ARCHER:
		# V1.5：長緩衝時箭已經在命中前飛到（battle_units 的飛行物），這裡只留「釘住抖一下」；短緩衝（手動軍令）照舊快飛
		# V1.5.1 B1：手動軍令局也有 1 tick 飛行段，箭在命中前就飛到；這裡一律只留「釘住抖一下」，不再命中後才補飛
		_add_fx({"src": s.id, "kind": "arrow", "a": sp + Vector2(10 * signf(tpos.x - sp.x), -24), "b": tpos + Vector2(0, -22), "t": 0.0, "fly": 0.001, "dur": 0.2, "tc": Art.team_color(s.team, cbm())})
		sfx.play_unit("arrow", 0.35, s.type)
	elif s.type == 17:
		# V1.5：骷髏法師的紫火打中目標（原本在法師自己身上揮擊）
		_add_fx({"src": s.id, "kind": "spark", "p": tpos + Vector2(0, -22), "c": Color(0.7, 0.4, 1.0), "t": 0.0, "dur": 0.3})
		sfx.play_unit("hit", 0.35, s.type)
		_hit_material(int(ev.get("tgt", -1)))
	else:
		_add_fx({"src": s.id, "kind": "slash", "p": sp, "dir": signf(tpos.x - sp.x) if tpos.x != sp.x else 1.0, "t": 0.0, "dur": 0.18})
		sfx.play_unit("hit" if k == EV.HIT else "slash", 0.4, s.type)   # V1.3.1：出手聲依兵種音高
		_hit_material(int(ev.get("tgt", -1)))
		if s.type == D.BERSERKER and _frags_on():
			frags.spawn(tpos, "wood", 4, view.tick * 4096 + s.id * 7 + 3, 22.0)   # 1.3.0 §6：狂戰士劈中帶起一圈木屑
	var col := Color.WHITE
	var label := ""
	match k:
		EV.CHARGE:
			label = L.t("ev_charge")
			col = ACCENT
			_add_fx({"kind": "windtrail", "p": sp, "dir": signf(tpos.x - sp.x) if tpos.x != sp.x else 1.0, "t": 0.0, "dur": 0.5})   # 1.4.0 §6.2 地面風痕
			_hitstop_weight(2)   # 1.4.0 §6.5 重擊頓一下
			_dir_hot(tpos)       # 1.4.0 §6.4 重播導播推近
			sfx.play("charge")
			sfx.play("bugle", 0.6)
			if _fx_on("shake"):
				shake = 0.12
			_add_fx({"kind": "dust", "p": tpos, "t": 0.0, "dur": 0.5})
			var dch := signf(tpos.x - sp.x) if tpos.x != sp.x else 1.0
			for kp in 2:   # 1.3.0 §6 招牌動作：木馬輪子空轉揚起的兩團塵（騎士身後）
				_add_fx({"kind": "dust", "p": sp + Vector2(-(18.0 + kp * 10.0) * dch * HK, -2.0 - kp * 3.0), "t": 0.0, "dur": 0.35 + kp * 0.08})   # 塵土（紫煙是潛行現形用的；Codex cat05 #7）
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
			_add_fx({"kind": "dust", "p": tpos + Vector2(8 * signf(sp.x - tpos.x), 2), "t": 0.0, "dur": 0.35})   # 1.3.0 §6：盾底砸進盤縫的塵圈
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
			_add_fx({"kind": "chips", "p": sp + Vector2(10 * signf(tpos.x - sp.x), -26), "t": 0.0, "dur": 0.3})   # 1.1.0 A7：劍士反擊時劍身迸出木屑
		EV.PIKE_BRACE:
			label = L.t("ev_pike_brace")
			col = Color("#ffd166")
			sfx.play("bell", 0.8)
			brace_t[t.id] = time   # 長槍兵頓槍（M_BRACE 疊加：槍尖銀光）
			_add_fx({"kind": "hex", "p": tpos + Vector2(10 * signf(sp.x - tpos.x), -24), "t": 0.0, "dur": 0.45})
		EV.BREACH:
			label = L.t("ev_breach")
			if not key_used:
				# V1.3 C4：每場第一次破陣是「關鍵時刻」：四周壓暗、向心墨圈，不動時間（預設開，簡化特效關）。
				# 跳播（with_fx＝false）時也記下「用過了」，跳過去之後的第二次破陣不會再演（Codex v130-impl1）
				key_used = true
				if with_fx:
					key_t = time
					key_p = tpos
			col = Color("#ff7a3d")
			if with_fx and s != null and s.type == D.BERSERKER:
				_add_fx({"kind": "axearc", "p": sp + Vector2(12 * signf(tpos.x - sp.x), -30), "dir": signf(tpos.x - sp.x), "t": 0.0, "dur": 0.25})   # 1.1.0 A7：狂戰士破陣赭橙短弧
			sfx.play("shatter", 0.6)
			_add_fx({"kind": "shard", "p": tpos + Vector2(12, -26), "t": 0.0, "dur": 0.5})
		EV.BREAKER:
			sfx.play("shatter", 0.45)
			_add_fx({"kind": "shard", "p": tpos + Vector2(12, -26), "t": 0.0, "dur": 0.5})
	if label != "":
		_report_add(s.team, s.type, k, label, col, s)
		# 第七輪 D1：混戰（附近 3 隻以上）不再往上疊跳字，技能都進底部戰報列；稀疏時才跳字
		if int(TEXT_TIER.get(k, 1)) < 2:
			# V1.1 A5：一般狀態（反騎、反擊、破陣）不出字，只在頭頂閃一個小菱形，字留在底部戰報列
			_add_fx({"kind": "badge", "p": tpos + Vector2(0, -64 * HK), "c": col, "t": 0.0, "dur": 0.4})
		elif _crowd_at(t) < 3:
			_merge_text(t.id, k, label, int(ev["dmg"]), tpos + Vector2(0, -78 * HK), col)
		elif int(TEXT_TIER.get(k, 1)) >= 2:
			text_key_in += 1
			text_key_shown += 1   # 關鍵技能仍然有顯示，只是在戰報列（測試對帳用）



# ── 戰鬥 HUD ──
func _draw_battle_hud() -> void:
	_hud_bar(Rect2(0, 0, 1280, 96))   # V1.2：頂部資訊列改深木紋（原本是平塗深底）；V1.2.1 加高，大字級的下排小字（AI 名）也在木條內
	draw_line(Vector2(0, 86), Vector2(1280, 86), TH_EDGE, 2.0)
	# 第五輪：左上和擺放畫面一樣——模式（粗）＋局數比分（小字），不再放遊戲標題（大字時會換行壓到棋盤）
	# 1.3.0 §9.4 資訊層級：戰鬥中 HUD 只留棋鐘、戰力尺、速度；模式與比分只在開場 3 秒、暫停、結果、滑鼠移到左上時出現
	if hud_meta_visible():
		_text(Vector2(16, 6), L.t("menu_duel") if mode == Mode.DUEL else _mode_label(), tz("S"), TXT_DIM, false, true, 300)
		if mode == Mode.VS_AI or mode == Mode.DUEL:
			_text(Vector2(16, 6 + tz("S") * 1.35), "%s　%s" % [L.t("round", [round_no]), L.t("score", [wins[0], wins[1]])], tz("C"), TXT_DIM, false, false, 300)
	var p0: int = view.power(0)
	var p1: int = view.power(1)
	var f0: float = float(p0) / view.budget_of(0)
	var f1: float = float(p1) / view.budget_of(1)
	var bx := 330.0
	var bw := 620.0
	var split := bw * f0 / maxf(0.001, f0 + f1)
	var craft_hud: bool = not bool(Save.s("plain_ui")) and _ui_tex(MAT["plaque"]) != null
	if craft_hud:
		# 1.2.0 §5.6：戰力條是一把山毛櫸木尺（刻度每 10%）＋黃銅滑塊；兩隊色條照舊（戰況資訊）
		_mat_box(Rect2(bx - 10, 32, bw + 20, 42), "plaque", Color(0.9, 0.82, 0.7))
		draw_rect(Rect2(bx - 2, 38, bw + 4, 30), Color("#2a1a10"))   # 尺上的凹槽
	else:
		_box(Rect2(bx - 4, 36, bw + 8, 34), Art.OUT, TH_EDGE, 6.0, 2.0)
	draw_rect(Rect2(bx, 40, split, 26), Art.team_color(0, cbm()))
	draw_rect(Rect2(bx + split, 40, bw - split, 26), Art.team_color(1, cbm()))
	draw_rect(Rect2(bx, 40, bw, 7), Color(1, 1, 1, 0.14))      # 上緣高光
	draw_line(Vector2(bx + split, 38), Vector2(bx + split, 68), Color.WHITE, 3.0)   # 交界線
	draw_line(Vector2(bx + bw / 2, 32), Vector2(bx + bw / 2, 74), Color(1, 1, 1, 0.55), 2)
	if craft_hud:
		for tk in range(1, 10):   # 木尺刻度（每 10%）
			var tx := bx + bw * tk / 10.0
			draw_line(Vector2(tx, 33), Vector2(tx, 37 if tk != 5 else 39), Color("#4a3018"), 1.5)
		# 黃銅滑塊：卡在交界線上，上下各露一截（左上高光）
		var sk := Rect2(bx + split - 6, 30, 12, 46)
		draw_rect(Rect2(sk.position + Vector2(2, 2), sk.size), Color(DIM_INK, 0.5))
		draw_rect(sk, Color("#8a6a2a"))
		draw_rect(sk.grow(-2), Color("#d4ae55"))
		draw_rect(Rect2(sk.position + Vector2(3, 3), Vector2(3, sk.size.y - 6)), Color(1, 0.96, 0.8, 0.6))
		for ry in [sk.position.y + 4.0, sk.end.y - 4.0]:
			draw_circle(Vector2(sk.get_center().x, ry), 2.2, Color("#5a4214"))   # 最後一輪（Codex 看圖 #6）：滑塊上下兩顆鉚釘＝卡在尺上的固定方式
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
	_text(Vector2(bx + 8, 42), L.t("hud_power", [roundi(p0 * 100.0 / (view.budget_of(0) * 1000))]), ts(15), lc, false, true)
	var rt: String = L.t("hud_power", [roundi(p1 * 100.0 / (view.budget_of(1) * 1000))])
	var rtw := font_bold.get_string_size(rt, HORIZONTAL_ALIGNMENT_LEFT, -1, ts(15)).x
	# V1.2.1 F5：深色字只在字底下真的是亮橘條時用；紅方戰力低、字底下是藍條或空槽時改白字描邊
	var on_orange: bool = cbm() and state == St.BATTLE and split <= bw - 8.0 - rtw - 4.0   # 結果頁有暗幕，深字不清楚
	var rc := Color("#141820") if on_orange else Color.WHITE
	_text(Vector2(bx + bw - 8 - rtw, 42), rt, ts(15), rc, false, true, 0.0, Color(1, 1, 1, 0.0) if on_orange else Color(0, 0, 0, -1))   # 深色字不加黑描邊（Antigravity S2 #1）
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
		_text(Vector2(bx - 22 - lb_w if tm0 == 0 else bx + bw + 22, 42), lb0, ts(15), _legible(Art.team_color(tm0, cbm())).lightened(0.06))   # 1.3.0：150% 時字 ≥19 粗體不會自動提亮，這裡手動過一次（4.48 → ≥4.5）
	for tm in 2:
		if view.rally[tm] and not view.finished:
			var rx := bx - 70.0 if tm == 0 else bx + bw + 12.0
			_text(Vector2(rx, 66), L.t("rally"), ts(13), Color(1, 0.55 + 0.2 * sin(time * 8), 0.3), false, true)
	var secs := maxi(0, (view.max_ticks - view.tick + 19) / 20)   # 第五輪：一局時間可調（原本寫死 90 秒）
	var clock_s: String = L.t("secs", [secs]) + ("　" + L.t("frenzy") if view.frenzy else "")
	if craft_hud and state == St.BATTLE:
		# 1.2.0 §5.6 棋鐘：淺色木盒＋頂上黃銅按鈕，字用深墨（狂熱時深紅）。木盒是平塗＋邊線（不是九宮格：大字級時字會壓到九宮格邊）；
		# 結果頁有暗幕，棋鐘回到原本的白字（深字在暗幕下看不清）
		var cw0 := maxf(170.0, _width(clock_s, ts(22), true) + 40.0)
		var cr := Rect2(640 - cw0 / 2, 1, cw0, maxf(32.0, ts(22) * 1.12))   # 第 11 大類：150% 時原本 ×1.3 的盒子蓋到戰力尺中央刻度，收緊到字高
		draw_rect(Rect2(cr.position + Vector2(3, 3), cr.size), Color(DIM_INK, 0.5))
		draw_rect(cr, Color("#e9d9b8"))
		draw_rect(Rect2(cr.position, Vector2(cr.size.x, 3)), Color(1, 0.97, 0.88, 0.7))
		draw_rect(cr, Color("#5a3a22"), false, 2.0)
		draw_rect(cr.grow(-4), Color("#8a6a48", 0.7), false, 1.0)   # 最後一輪（Codex 看圖 #6）：鐘面內框，像有厚度的木盒
		draw_rect(Rect2(cr.position.x, cr.end.y - 3, cr.size.x, 3), Color(DIM_INK, 0.35))
		draw_rect(Rect2(640 - 9, 0, 18, 3), Color("#c9a24a"))
		# 1.4.0 §7.2：數字是木活字；最後 10 秒每換一秒數字跳一下＋輕輕一聲（減少動態不跳）
		if secs != clock_last:
			# 只有正常播放、往下走一秒才跳／響（跳轉、暫停、倒帶不算；Codex v140 cat02 #1）
			var normal: bool = clock_last >= 0 and secs == clock_last - 1 and not paused and seek_target < 0
			if normal and secs <= 10 and secs > 0 and sfx != null and not view.finished:
				sfx.play_pitched("k_click", 0.22, 1.5)
			clock_flip_t = time if normal else -10.0
			clock_last = secs
		var jmp := 0.0
		if secs <= 10 and not bool(Save.s("reduce_motion")):
			jmp = clampf(1.0 - (time - clock_flip_t) / 0.15, 0.0, 1.0)
		_woodtype(Vector2(640, 4), clock_s, ts(22), Color("#8e1b14") if view.frenzy else Color("#2a1a10"), true, true, jmp)
	else:
		_text(Vector2(640, 4), clock_s, ts(22), Color.ORANGE_RED if view.frenzy else Color.WHITE, true, true)
	# 1.2.0 §5.6 情境資訊：AI 名稱只在開場 3 秒、滑鼠指到戰力尺、手把按 View 後 2 秒顯示（Codex／Antigravity：資訊都在，次要的不常駐）
	var ai_show: bool = view.tick < 60 or Rect2(bx - 10, 32, bw + 20, 52).has_point(mouse) or time < hud_info_until or shot_dir != ""
	if mode == Mode.VS_AI and ai_name != "" and ai_show:
		var ai_lb := "AI：%s" % ai_name
		_text(Vector2(bx + bw - _width(ai_lb, tz("C")), 69.0), ai_lb, tz("C"), Color(1, 1, 1, 0.9))   # V1.2.1：大字級也在木條內
	if state == St.BATTLE and bool(Save.s("playtest")):
		if pt_call_tick < 0:
			_btn(Rect2(780, 4, 162, 36), L.t("pt_call"), func(): pt_call_tick = view.tick; _toast(L.t("pt_called", [view.tick / 20])))
	btn_ring_clip = Rect2(1, 1, 1278, 40)   # V1.5.2：頂列的加強焦點外圈不往下蓋到 y=42 的剩餘隻數
	if state == St.BATTLE:
		if play_kind != "official":
			_btn(Rect2(1010, 4, 120, 36), L.t("back"), func(): call("_replay_back"))   # 第七輪 A9：立刻回上一個畫面
		else:   # 重播／覆盤用底部的控制列，不重複放倍速鈕（Antigravity S5）
			_btn(Rect2(950, 4, 52, 36), "▶" if paused else "Ⅱ", func(): call("_toggle_pause"))   # 第七輪 A6；V1.5.2：頂列一律 y=4、高 36、右緣留 14（原本暫停鈕 y=2 和同列不齊；下緣 40 不碰 y=42 的剩餘隻數；加強焦點框在 _btn 裡夾在畫面內）
			_btn(Rect2(1010, 4, 120, 36), L.t("speed", [_fmt_num(speed)]), func(): speed = speed_step(speed, 1) if speed < float(SPEEDS[SPEEDS.size() - 1]) else float(SPEEDS[0]))   # V1.5.1：照共用表往上一格、到頂回最慢
		_btn(Rect2(1134, 4, 132, 36), L.t("skip"), func(): _on_skip())
	btn_ring_clip = Rect2(1, 1, 1278, 798)



## 開一場戰鬥（S8 從 game_screens 移下來：重播、覆盤、截圖都會用到）
func _begin_battle(a0, a1, kind := "official") -> void:
	nav_stack.clear()   # V1.5.1：開戰後，之前的返回堆疊作廢
	_pre_drop()
	play_kind = kind
	tm_ghost = null   # V1.4 #1：時光機的原本時間線只在「如果」播放時存在（_rv_play 之後會再設）
	_ensure_sprites([a0, a1])
	if kind == "official":
		last_armies = [a0.copy(), a1.copy()]
		battle_rules = rules.copy() if rules != null else _puzzle_rules()   # 第十三輪：殘局自帶規則
	sim = Sim.new(a0, a1, battle_rules)
	_cmd_setup(sim, kind)
	view = ViewBuffer.new(sim)
	atk_seq.clear()
	clutch_tick = -1
	replay_total = 0
	if kind != "official":
		# 重播／覆盤：先用確定性模擬算出整場長度，時間軸以實際秒數為滿（Antigravity S5）
		var pa0 = a0.copy()
		var pa1 = a1.copy()
		var pr = battle_rules.copy() if battle_rules != null else null
		var plog: Array = last_cmds.duplicate(true)
		replay_bm = []
		var run_pre := func() -> Array:
			var pre = Sim.new(pa0, pa1, pr)
			if pre.cmd_on:
				pre.cmd_play(plog)
			pre.fast = true
			var bm: Array = []
			while not pre.finished:
				pre.step()
				BM.collect(pre, bm)   # 1.2.0 §11.2：預跑順手收書籤（不多跑一次模擬）
			return [pre.tick, bm]
		if _async_ok():
			pre_thread = Thread.new()
			pre_thread.start(run_pre)
		else:
			var pv: Array = run_pre.call()
			replay_total = int(pv[0])
			replay_bm = pv[1]
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
	proj_tgt.clear()
	brace_t.clear()
	state = St.BATTLE
	prev_pos.clear()
	_gait_reset()
	for u in view.units:
		prev_pos[u.id] = Vector2(u.x, u.y)
	_pump_view()   # 開場先預填 DELAY 個 tick
	accum = 0.0
	present_debt = 0.0   # 1.2.0 §9.6
	slow_used = false
	final_used = false
	cues.clear()        # 1.3.0 §7.1
	stat_prev.clear()
	key_used = false
	key_t = -10.0
	last_kill = [-1, -10.0]
	last_hitter.clear()
	final_left = 0.0
	slow_left = 0.0
	hitstop = 0.0
	dir_hot_until = -1.0   # 1.4.0：推近不帶到下一場／下一段（Codex cat05 #7）
	zoom = 1.0
	zoom_target = 1.0
	pinch_zoom = 1.0   # V1.4 #18：新的一場不沿用上一場的縮放
	dir_manual = false   # 1.3.0 §2：每一場（含重播、精華段）導播重新接手
	clock_last = -1      # 1.4.0 §7.2：棋鐘跳字重新算
	if sfx != null and sfx.has_method("reseed"):
		sfx.reseed(sfx.seed_at(round_no, 0))   # 1.3.0 §10：音效變體用固定種子
	spot_a = 0.0
	spot_n = 0
	desat_a = 0.0
	mag_hide = -1
	mag_corner_i = -1
	if kind == "official":
		hl_reel = []
	fx.clear()
	frags.clear()   # 1.2.0 §8.2
	dying.clear()
	atk_t.clear()
	hurt_t.clear()
	last_blast_tick = -99
	ev_count = {}
	frenzy_seen = false
	result_delay = 0.0
	pt_call_tick = -1
	pt_rated = false
	_focus = 0
	speed = float(Save.s("speed"))
	sfx.play("start")
	sfx.play("horn", 0.55)
	sfx.play_music("music_battle")



# ── 1.3.0 第 6 大類：戰場導演與觀戰（方案 §2）──
const DirR = preload("res://scripts/game/director_rules.gd")
var dir_manual := false     # 玩家動過鏡頭（滾輪、拖曳、雙擊、點兵、右搖桿、扳機）＝這一場交還手動
var spot_p := Vector2.ZERO  # 交戰熱點（盤面座標）
var spot_n := 0
var spot_a := 0.0           # 聚光強度（淡入淡出）
var desat_a := 0.0          # 最後一擊去飽和
var mag_hide := -1          # 按了任何鍵：這隻的放大鏡收起，直到換選
var mag_corner_i := -1
var hl_reel: Array = []     # 精華三連：各段的事件 tick
var hl_i := 0
var hl_end := -1
const MAG_R := 70.0
const MAG_CORNERS := [Vector2(100, 586), Vector2(1180, 586), Vector2(100, 214), Vector2(1180, 214)]   # 下緣停在 676：不壓重播控制列上方的提示字
static var _spot_img_tex: ImageTexture = null

## 交戰熱點：最近 0.8 秒有出手或受擊的單位裡，找鄰居最多的那一團（160px 內），取它們的中心。只看畫面，不進模擬。
func _spot_update(delta: float) -> void:
	var act: Array = []
	for u in view.units:
		if u.alive and ((hurt_t.has(u.id) and time - float(hurt_t[u.id]) < 0.8) or (atk_t.has(u.id) and time - float(atk_t[u.id]) < 0.8)):
			act.append(_upos(u))
	var best: Array = []
	for a in act:
		var grp: Array = []
		for b in act:
			if (a as Vector2).distance_to(b) < 160.0 * HK:
				grp.append(b)
		if grp.size() > best.size():
			best = grp
	spot_n = best.size()
	if spot_n >= 2:
		var c := Vector2.ZERO
		for b in best:
			c += b
		c /= float(spot_n)
		spot_p = c if spot_a <= 0.01 else spot_p.lerp(c, minf(1.0, delta * 2.0))
		spot_a = move_toward(spot_a, 1.0, delta * 2.0)
	else:
		spot_a = move_toward(spot_a, 0.0, delta * 1.2)

func _dir_on() -> bool:
	return play_kind != "official" and not dir_manual and view != null and bool(Save.s("auto_director")) and not bool(Save.s("reduce_motion"))

func _director_cam(delta: float) -> void:
	var fc := ORIGIN + fld_size / 2
	if time < dir_hot_until and not view.finished:
		zoom_target = 1.35
		zoom_center = zoom_center.lerp(dir_hot_p, minf(1.0, delta * 3.0))
		return
	var r: Array = DirR.director_target(view.tick, view.finished, spot_p, spot_n, fc, fld_size.x)
	zoom_target = float(r[0])
	zoom_center = zoom_center.lerp(r[1], minf(1.0, delta * (4.0 if view.tick < DirR.TOUR_TICKS else 1.5)))

## 手動鏡頭：右搖桿平移（放大時）、右扳機放大、左扳機縮小。動了就交還手動。
func _pad_cam(delta: float) -> void:
	if overlay != "" or Input.get_connected_joypads().is_empty():
		return
	var dz := maxf(0.15, int(Save.s("deadzone")) / 100.0)
	var zi := Input.get_joy_axis(last_joy, JOY_AXIS_TRIGGER_RIGHT) - Input.get_joy_axis(last_joy, JOY_AXIS_TRIGGER_LEFT)
	if absf(zi) > 0.3:
		if pinch_zoom <= 1.01:
			pinch_center = zoom_center
		pinch_zoom = clampf(pinch_zoom * (1.0 + zi * delta * 1.2), 1.0, 2.0)
		_take_manual()
	var v := Vector2(Input.get_joy_axis(last_joy, JOY_AXIS_RIGHT_X), Input.get_joy_axis(last_joy, JOY_AXIS_RIGHT_Y))
	if v.length() > dz and pinch_zoom > 1.01:
		pinch_center += v * delta * 420.0 / pinch_zoom
		_take_manual()

## 滑鼠：滾輪縮放（往游標方向）、中鍵拖曳平移、雙擊回全景（game_screens 的輸入佇列呼叫）。
func cam_wheel(up: bool, at: Vector2) -> void:
	_take_manual()
	if not up and pinch_zoom <= 1.01:
		return
	call("_pinch_by", 1.12 if up else 1.0 / 1.12, at)
	_cam_apply_paused()

func cam_pan(rel: Vector2) -> void:
	if pinch_zoom <= 1.01:
		return
	_take_manual()
	pinch_center -= rel / maxf(1.0, zoom)
	_cam_apply_paused()

func cam_reset() -> void:
	_take_manual()
	pinch_zoom = 1.0
	follow_id = -1
	if paused:
		zoom = 1.0
		zoom_target = 1.0
		zoom_center = ORIGIN + fld_size / 2

## 玩家動了鏡頭：導播交還、跟拍放掉（手動優先）、精華三連停在這裡。
func _take_manual() -> void:
	dir_manual = true
	hl_reel = []
	if follow_id >= 0 and play_kind != "official":
		follow_id = -1

## 暫停時 _battle_process 不跑鏡頭：滾輪、平移直接套上（Codex cat06 #5）。
func _cam_apply_paused() -> void:
	if paused and pinch_zoom > 1.01:
		zoom = pinch_zoom
		zoom_target = pinch_zoom
		zoom_center = pinch_center
	elif paused:
		zoom = 1.0
		zoom_target = 1.0

## 聚光：熱點外圍淡淡壓暗（只壓戰場與桌面，畫在介面之前）；簡化介面、減少特效、設定關時不畫。
func _draw_spotlight() -> void:
	if spot_a <= 0.01 or view == null or not bool(Save.s("spotlight")) or bool(Save.s("plain_ui")) or bool(Save.s("reduce_fx")):
		return
	var c: Vector2 = _cam * spot_p
	var sz := Vector2(2800, 2800) * clampf(zoom, 1.0, 1.6)
	draw_texture_rect(_spot_tex(), Rect2(c - sz / 2.0, sz), false, Color(1, 1, 1, 0.34 * spot_a))   # Hydrogen cat06 #4：原本 0.2 太淡

static func _spot_tex() -> ImageTexture:
	if _spot_img_tex == null:
		var n := 256
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var r := Vector2(x + 0.5 - n / 2.0, y + 0.5 - n / 2.0).length() / (n / 2.0)
				img.set_pixel(x, y, Color(DIM_INK, smoothstep(0.09, 0.22, r)))
		_spot_img_tex = ImageTexture.create_from_image(img)
	return _spot_img_tex

## 最後一擊去飽和：整個戰場蓋一層中灰（約等於彩度降 25%），0.4 秒回彈。
func _draw_desat() -> void:
	if desat_a <= 0.005 or bool(Save.s("reduce_fx")):
		return
	draw_rect(Rect2(0, 0, 1280, 800), Color(0.46, 0.44, 0.41, desat_a))

## 銅放大鏡小窗：被選的那隻 1.6 倍特寫（表情、血、冷卻）；固定安全角、離那隻最遠，換角有遲滯；
## 按任何鍵收起（mag_hide）、點背景取消選取；簡化介面、設定關時不畫；巨獸不畫（太大）。
func _draw_bmag() -> void:
	if follow_id < 0 or follow_id == mag_hide or view == null or mag_pose.size() < 3 or not bool(Save.s("battle_mag")) or bool(Save.s("plain_ui")):
		return
	var u = view.unit_by_id(follow_id)
	if u == null or not u.alive or u.boss or u.hidden or u.stealth > 0:
		return   # 偽裝、潛行中的不給特寫（不洩漏真身；Codex cat06 #3）
	var banned: Array = []
	if paused:
		banned.append(3)   # 暫停時右上是資料卡
	if call("_replay_controls_active"):
		banned.append(0)   # 重播時左下是時光機、GIF 鈕（Codex cat06 #7）
	mag_corner_i = DirR.mag_corner(MAG_CORNERS, _cam * _upos(u), mag_corner_i, banned, 260.0)
	if mag_corner_i < 0:
		return
	var c: Vector2 = MAG_CORNERS[mag_corner_i]
	var R := MAG_R
	draw_circle(c + Vector2(4, 6), R + 10, Color(0, 0, 0, 0.32), true, -1.0, true)
	draw_circle(c, R + 10, PAL.TRINKET_BRASS.darkened(0.25), true, -1.0, true)
	draw_circle(c, R + 7, PAL.TRINKET_BRASS, true, -1.0, true)
	draw_arc(c, R + 8.5, PI * 1.05, PI * 1.6, 24, PAL.TRINKET_BRASS.lightened(0.45), 1.5, true)   # 燈從左上來的亮邊
	_mag_glass_bg(c, R, _upos(u))
	_unit(c + Vector2(0, 34), u.type, u.team, float(mag_pose[0]), 0.0, 0.0, float(mag_pose[1]), 1.0, time, UNIT_SCALE * 1.6, int(mag_pose[2]))
	# 鏡片：色散細邊、三道刮痕、左上反光（Hydrogen cat06 #1：原本太淡看不出是玻璃）
	draw_arc(c + Vector2(-1.5, 0), R - 1, 0, TAU, 64, Color(1, 0.25, 0.2, 0.5), 2.0, true)
	draw_arc(c + Vector2(1.5, 0), R - 1, 0, TAU, 64, Color(0.2, 0.45, 1, 0.5), 2.0, true)
	for k in 3:
		var a0 := 0.6 + k * 1.9
		var p0 := c + Vector2(cos(a0), sin(a0)) * R * (0.35 + 0.15 * k)
		draw_line(p0, p0 + Vector2(cos(a0 + 1.2), sin(a0 + 1.2)) * (14.0 + 6.0 * k), Color(1, 1, 1, 0.32), 1.2, true)
	draw_arc(c, R * 0.84, PI * 1.08, PI * 1.42, 20, Color(1, 1, 1, 0.55), 4.0, true)
	draw_arc(c, R * 0.72, PI * 1.15, PI * 1.3, 12, Color(1, 1, 1, 0.35), 2.0, true)
	# 血（外圈，從 12 點順時針；四等分刻度）與冷卻（內圈金色，跑完＝可以出手）
	var hp := clampf(float(u.hp) / maxf(1.0, float(u.max_hp)), 0.0, 1.0)
	draw_arc(c, R + 4, 0, TAU, 64, Color(0, 0, 0, 0.6), 5.0, true)
	if hp > 0.0:
		draw_arc(c, R + 4, -PI / 2, -PI / 2 + TAU * hp, 64, Art.team_color(u.team, cbm()).lightened(0.25), 5.0, true)
	for q in 4:
		var aq := -PI / 2 + q * PI / 2
		draw_line(c + Vector2(cos(aq), sin(aq)) * (R + 1.5), c + Vector2(cos(aq), sin(aq)) * (R + 6.5), PAL.TRINKET_BRASS.darkened(0.45), 1.5, true)
	var cdb := float(D.stat(u.type).get("cd", 20))
	var cdf := clampf(float(u.cd) / maxf(1.0, cdb), 0.0, 1.0)
	if cdf > 0.0:
		draw_arc(c, R - 5, -PI / 2, -PI / 2 + TAU * cdf, 48, Color(PAL.TRINKET_GOLD, 0.9), 3.0, true)

## 精華三連：一段播完（或場次結束）就跳下一段；最後一段播完照常進結果。
func _hl_seg(i: int) -> void:
	hl_i = i
	var t := int(hl_reel[i])
	hl_end = t + DirR.SEG_LEN - DirR.SEG_PRE
	call("_seek_async", maxi(0, t - DirR.SEG_PRE))

func _hl_reel_tick() -> bool:
	if hl_reel.is_empty() or view == null or seek_target >= 0 or state != St.BATTLE:
		return false
	if view.tick >= hl_end or view.finished:
		if hl_i + 1 < hl_reel.size():
			_hl_seg(hl_i + 1)
			return true
		hl_reel = []
	return false

## 放大鏡鏡片底：盤面地塊放大 1.6 倍（地圖有地塊時用 UV 圓形多邊形貼；平原用草地底色）。
func _mag_glass_bg(c: Vector2, R: float, at: Vector2) -> void:
	var mt: Texture2D = call("_map_tex") if fld_map != 0 else null
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i in 40:
		var a := i * TAU / 40.0
		var d := Vector2(cos(a), sin(a))
		pts.append(c + d * R)
		uvs.append(((at - Vector2(0, 20)) + d * R / (1.6 * zoom) - ORIGIN) / fld_size)
	if mt != null:
		draw_polygon(pts, PackedColorArray([Color.WHITE]), uvs, mt)
	else:
		draw_colored_polygon(pts, Color(0.47, 0.6, 0.33))
	draw_colored_polygon(pts, Color(1, 0.97, 0.88, 0.12))   # 鏡片微暖



# ── 1.3.0 第 7 大類：技能演出三拍（方案 §7.1）──
var cues: Array = []          # 預告：[種類, 來源 id, 目標 id, 命中 tick]（只在命中前畫）
var stat_prev := {}           # 單位 id → [定身中, 破陣中]
const CUE_MAX := 24
const STAIN_MAX := 6          # 同時最多幾灘（同一技能連發不會鋪滿盤，視覺上限）
const TAG_BURST := 4          # 同一 tick 超過 4 隻同時被定身（時停）就不逐隻插竹籤（時停有自己的橫幅）

func _cue_add(kind: String, src: int, tgt: int, tick: int) -> void:
	for c in cues:
		if c[0] == kind and int(c[1]) == src and int(c[3]) == tick:
			return
	cues.append([kind, src, tgt, tick])
	while cues.size() > CUE_MAX:
		cues.pop_front()

## 預告層（盤面座標，單位之後、特效之前）：騎兵衝鋒前地上兩道木輪痕、盾兵架盾前腳下金色紙箔圈；淡入到命中那一刻，命中後就不畫。
func _draw_cues() -> void:
	if view == null or cues.is_empty():
		return
	var keep: Array = []
	for c in cues:
		var hit := int(c[3])
		if hit < view.tick:
			continue
		keep.append(c)
		var k := clampf(1.0 - float(hit - view.tick) / float(maxi(1, view.DELAY_LONG)), 0.15, 1.0)
		var s = view.unit_by_id(int(c[1]))
		var t = view.unit_by_id(int(c[2]))
		if s == null or t == null:
			continue
		var sp := _upos(s)
		var tp := _upos(t)
		if c[0] == EV.CHARGE:
			var d := tp - sp
			if d.length() < 4.0:
				continue
			var n := d.normalized()
			var side := Vector2(-n.y, n.x) * 6.0 * HK
			var steps := int(d.length() / 10.0)
			for i in steps:
				var a := sp + n * (i * 10.0) + Vector2(0, 2)
				for sd in [-1.0, 1.0]:
					draw_line(a + side * sd, a + side * sd + n * 5.0, Color(PAL.TRINKET_LEATHER.darkened(0.3), 0.45 * k), 2.0, true)
		elif c[0] == EV.BRACED:
			draw_set_transform_matrix(_cam * Transform2D(0, Vector2(1, 0.45), 0, tp + Vector2(0, 2)))
			draw_arc(Vector2.ZERO, 22.0 * HK, 0, TAU, 40, Color(PAL.TRINKET_GOLD, 0.75 * k), 2.5, true)
			draw_arc(Vector2.ZERO, 17.0 * HK, 0, TAU * k, 32, Color(PAL.TRINKET_GOLD.lightened(0.4), 0.6 * k), 1.5, true)
			draw_set_transform_matrix(_cam)
	cues = keep

## 狀態竹籤：定身、破陣「開始」的那一 tick，從底座彈出一根薄竹籤、自轉半圈、往盤外掉落淡出（跳字設定關時不出）。
func _status_tags(with_fx: bool) -> void:
	var fresh: Array = []
	for u in view.units:
		var now := [u.alive and u.stun > 0, u.alive and u.breach > 0]
		var was: Array = stat_prev.get(u.id, [false, false])
		if with_fx and u.alive:
			if now[0] and not was[0]:
				fresh.append([u, "tag_stun"])
			if now[1] and not was[1]:
				fresh.append([u, "tag_breach"])
		stat_prev[u.id] = now
	if fresh.is_empty() or fresh.size() > TAG_BURST or str(Save.s("dmg_nums")) == "off":
		return
	for f in fresh:
		var u = f[0]
		_add_fx({"kind": "tag", "p": _upos(u) + Vector2(0, -6), "s": L.t(f[1]), "dir": -1.0 if u.team == 0 else 1.0, "t": 0.0, "dur": 0.9})

## 範圍墨漬（茶漬）：擴散到真實範圍，停一下，最後 1.5 秒像被木頭吸乾地收縮淡出。
func _stain(p: Vector2, r: float, tea: bool, seed: int) -> void:
	if bool(Save.s("plain_ui")):
		return
	var n := 0
	for f in fx:
		if f["kind"] == "stain":
			n += 1
	if n >= STAIN_MAX:
		for i in fx.size():
			if fx[i]["kind"] == "stain":
				fx.remove_at(i)
				break
	_add_fx({"kind": "stain", "p": p, "r": r, "tea": tea, "seed": seed, "t": 0.0, "dur": 2.0})



# ── 1.3.0 第 9 大類：資訊層級（方案 §9.4）──
const HUD_META_TICKS := 60   # 開場 3 秒

## 戰鬥 HUD 左上的模式與比分要不要畫：開場 3 秒、暫停、結果頁、滑鼠移到左上（手把模式＝一直顯示，沒有懸停）、簡化介面一律顯示。
func hud_meta_visible() -> bool:
	if state != St.BATTLE or view == null or paused or pad_mode or bool(Save.s("plain_ui")):
		return true
	if view.tick < HUD_META_TICKS:
		return true
	return Rect2(0, 0, 330, 86).has_point(mouse)



# ── 1.3.0 第 13 大類：第一印象「掌燈開門」（方案 §13）──
## 第一次開遊戲：黑畫面裡劃火柴 → 油燈亮起、暖光從燈往外推開 → 光鋪滿桌面、標題浮出（5 秒）。
## 任何按鍵、點擊跳過；看過（或跳過）就記在存檔，之後直接到標題。截圖、版面檢查、headless、減少動態時不播。
const INTRO_SEC := 5.0
const LAMP_AT := Vector2(214, 610)
var intro_t := -1.0

static func intro_should_play(seen: bool, shots: bool, probe: bool, headless: bool, reduce_motion: bool) -> bool:
	return not seen and not shots and not probe and not headless and not reduce_motion

func intro_begin() -> void:
	if intro_should_play(bool(Save.data.get("intro_seen", false)), shot_dir != "", layout_probe, DisplayServer.get_name() == "headless", bool(Save.s("reduce_motion"))):
		intro_t = 0.0

func intro_end() -> void:
	if intro_t < 0.0:
		return
	intro_t = -1.0
	Save.data["intro_seen"] = true
	Save.save_data()

func intro_tick(delta: float) -> void:
	if intro_t < 0.0:
		return
	var was := intro_t
	intro_t += delta
	if was < 0.5 and intro_t >= 0.5 and sfx != null:
		sfx.play_pitched("place_light", 0.35, 1.6)   # 火柴擦一下（真錄音到位前先用輕木聲）
	if intro_t >= INTRO_SEC:
		intro_end()

func _draw_intro() -> void:
	if intro_t < 0.0:
		return
	var t := intro_t
	var fade := clampf((t - 4.2) / 0.8, 0.0, 1.0)   # 最後 0.8 秒整層淡出
	var a := 1.0 - fade
	var light := clampf((t - 0.9) / 2.3, 0.0, 1.0)
	light = 1.0 - pow(1.0 - light, 3.0)
	# 暗幕：中心透明、外圍全黑的徑向貼圖從燈往外撐開（沿用聚光的那張），貼圖外面補黑
	var sz := lerpf(60.0, 7000.0, light)
	var r := Rect2(LAMP_AT - Vector2(sz, sz) / 2.0, Vector2(sz, sz))
	var blk := Color(0.02, 0.015, 0.01, a)
	if t < 0.9:
		draw_rect(Rect2(0, 0, 1280, 800), blk)
	else:
		draw_texture_rect(_spot_tex(), r, false, Color(1, 1, 1, a))
		draw_rect(Rect2(0, 0, 1280, maxf(0.0, r.position.y)), blk)
		draw_rect(Rect2(0, r.end.y, 1280, maxf(0.0, 800.0 - r.end.y)), blk)
		draw_rect(Rect2(0, r.position.y, maxf(0.0, r.position.x), r.size.y), blk)
		draw_rect(Rect2(r.end.x, r.position.y, maxf(0.0, 1280.0 - r.end.x), r.size.y), blk)
		draw_circle(LAMP_AT + Vector2(0, -48), 90.0 + light * 140.0, Color(1.0, 0.72, 0.35, 0.10 * a * (1.0 - light * 0.6)), true, -1.0, true)   # 暖光
	# 火柴：0.45～0.9 秒一點火星＋幾顆飛散的火花
	if t >= 0.45 and t < 1.1:
		var sk := clampf((t - 0.45) / 0.65, 0.0, 1.0)
		var mp := LAMP_AT + Vector2(36, -40)
		for i in 6:
			var ang := i * 1.05 + 0.4
			draw_circle(mp + Vector2(cos(ang), sin(ang)) * sk * 26.0, 2.0 * (1.0 - sk), Color(1, 0.75, 0.3, 1.0 - sk), true, -1.0, true)
		draw_circle(mp, 5.0 * (1.0 - sk * 0.5), Color(1, 0.85, 0.5, a), true, -1.0, true)
	# 油燈（黃銅底座、玻璃燈罩、火焰）：0.8 秒起就在
	if t >= 0.8:
		var la := a
		var base := LAMP_AT
		draw_colored_polygon(PackedVector2Array([base + Vector2(-34, 0), base + Vector2(34, 0), base + Vector2(24, -16), base + Vector2(-24, -16)]), Color(PAL.TRINKET_BRASS.darkened(0.2), la))
		draw_rect(Rect2(base + Vector2(-14, -30), Vector2(28, 14)), Color(PAL.TRINKET_BRASS, la))
		draw_set_transform_matrix(Transform2D(0, Vector2(1, 1.5), 0, base + Vector2(0, -62)))
		draw_circle(Vector2.ZERO, 22.0, Color(1, 0.95, 0.85, 0.18 * la), true, -1.0, true)
		draw_arc(Vector2.ZERO, 22.0, 0, TAU, 32, Color(1, 1, 1, 0.35 * la), 1.5, true)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		var fl := clampf((t - 0.8) / 0.4, 0.0, 1.0)
		var flick := 1.0 + sin(t * 23.0) * 0.06 + sin(t * 37.0) * 0.04
		var fh := 26.0 * fl * flick
		draw_colored_polygon(PackedVector2Array([base + Vector2(-6, -36), base + Vector2(0, -36 - fh), base + Vector2(6, -36)]), Color(1, 0.7, 0.25, la))
		draw_colored_polygon(PackedVector2Array([base + Vector2(-3, -36), base + Vector2(0, -36 - fh * 0.6), base + Vector2(3, -36)]), Color(1, 0.95, 0.7, la))
	# 跳過提示（2 秒後）
	if t > 2.0 and fade < 0.5:
		_text(Vector2(1240, 760), L.t("intro_skip"), tz("C"), Color(1, 0.9, 0.75, 0.55 * a), false, false, 0.0)


# ── 1.4.0 第 2 大類：棋鐘木活字 ──
var clock_last := -1
var clock_flip_t := -10.0


# ── 1.4.0 第 7 大類：技能演出 3.0（方案 §6）──
## 頓幀依重量：固定呈現時間（輕 0、中 30ms、重 60ms），不是幀數；只停畫面時鐘（展示時鐘補回）。減少動態、截圖不頓。
const HITSTOP_W := [0.0, 0.03, 0.06]
func _hitstop_weight(w: int) -> void:
	if bool(Save.s("reduce_motion")) or shot_dir != "" or w <= 0:
		return
	hitstop = maxf(hitstop, HITSTOP_W[clampi(w, 0, 2)])

## 招牌推近：只在重播／觀戰的自動導播（實戰、玩家操作中的觀戰都不推）；0.6 秒。
var dir_hot_p := Vector2.ZERO
var dir_hot_until := -1.0
func _dir_hot(p: Vector2) -> void:
	if not _dir_on():
		return
	dir_hot_p = p
	dir_hot_until = time + 0.6
