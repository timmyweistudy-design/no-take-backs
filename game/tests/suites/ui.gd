extends "res://tests/test_base.gd"

## 戰鬥畫面的事件分流（Codex R3 審查 #1）：真實戰鬥出現的每一種事件都要分到合法的路線，攻擊一定帶 src／tgt／dmg，
## 背水開關（沒有 src）不能被當成攻擊。純模擬測試抓不到畫面層讀不存在的欄位，所以直接測分流函式。
func test_event_routes() -> void:
	var pool := F.training_pool(0)
	var kinds := {}
	var bad: Array = []
	for i in 30:
		var sm = Sim.new(pool[i].copy(), pool[(i * 7 + 3) % pool.size()].mirrored())
		sm.fast = true
		while not sm.finished:
			sm.step()
			for e in sm.events:
				if not EVS.KINDS.has(e["kind"]):
					bad.append("未登記的事件種類 %s" % e["kind"])
				for tg in e.get("tags", []):
					if not EVS.TAGS.has(tg):
						bad.append("未登記的標籤 %s" % tg)
				var r := BV.event_route(e)
				kinds[e["kind"]] = r
				if r == "attack" and not (e.has("src") and e.has("tgt") and e.has("dmg")):
					bad.append(e)
				if (r == "taunt" or r == "reveal") and sm.unit_by_id(int(e["src"])) == null:
					bad.append(e)
	ok(kinds.get("rally_on", "") == "skip" and kinds.get("flank", "") == "skip" and kinds.get("taunt", "") == "taunt"
		and kinds.get("reveal", "") == "reveal" and kinds.get("hit", "") == "attack" and kinds.get("death", "") == "death" and bad.is_empty(),
		"戰鬥畫面事件分流：背水／繞翼不當攻擊、攻擊都帶完整欄位", "%s %s" % [kinds, bad.slice(0, 3)])


## 畫面層真的消費事件（Codex R3 第 2 輪）：把真實戰鬥的每個 tick 交給戰鬥畫面的 _sim_step（含 _on_event、展示緩衝），
## 不能報錯、攻擊事件一定產生演出；圖鑑的 _codex_tick 每段示範都要真的跳字、跳在觸發者身上。
func test_ui_consumers() -> void:
	var GS = load("res://scripts/ui/game_screens.gd")
	# 畫面腳本有語法錯誤時要紅，不能靜靜跳過後面的檢查（收尾時抓到過一次：79 通過 0 失敗但其實沒跑）
	ok(GS != null and GS.can_instantiate(), "畫面腳本（game_screens 繼承鏈）能載入")
	if GS == null or not GS.can_instantiate():
		return
	var g = GS.new()
	g.sfx = FakeSfx.new()
	var pool := F.training_pool(0)
	var attacks := 0
	var fx_seen := 0
	var kinds := {}
	var bad: Array = []
	for i in 6:
		g.sim = Sim.new(pool[i].copy(), pool[(i * 11 + 5) % pool.size()].mirrored())
		g.view = g.ViewBuffer.new(g.sim)
		g.atk_hit.clear()
		g.state = g.St.BATTLE
		g._pump_view()
		var guard := 0
		while not g.view.finished and guard < 2000:
			guard += 1
			g.fx.clear()
			g._sim_step(true)
			var n_att := 0
			var srcs := {}
			for f in g.fx:
				if f.has("src"):
					srcs[f["src"]] = int(srcs.get(f["src"], 0)) + 1
			for e in g.view.events:
				kinds[e["kind"]] = true
				if g.event_route(e) == "attack" and e["kind"] != EVS.SPLASH:   # 波及跟著同一顆炸彈的爆炸演出，不另畫
					n_att += 1
					# 逐事件核對：每一次攻擊都要有一個屬於攻擊者的砍擊／箭（Codex 收尾輪 #5）
					if int(srcs.get(e["src"], 0)) <= 0:
						bad.append("tick%d 單位 %d 的攻擊（%s）沒有演出" % [g.view.tick, e["src"], e["kind"]])
					else:
						srcs[e["src"]] -= 1
			attacks += n_att
			if n_att > 0:
				fx_seen += 1
		if g.view.tick != g.sim.tick or not g.sim.finished:
			bad.append("第 %d 場畫面沒有播到最後（畫面 %d／模擬 %d）" % [i, g.view.tick, g.sim.tick])
	ok(bad.is_empty() and attacks > 100 and kinds.has("rally_on") and kinds.has("death"), "戰鬥畫面消費真實事件：不報錯、攻擊都有演出、緩衝會排空", "%s attacks=%d kinds=%s" % [bad.slice(0, 3), attacks, kinds.keys()])
	# 前搖：攻擊者在命中那一格之前就已經開始動作（展示緩衝的目的）
	g.sim = Sim.new(army_from(0, [[D.SWORD, 5, 4]]), army_from(1, [[D.SHIELD, 5, 4]]))
	g.view = g.ViewBuffer.new(g.sim)
	g.atk_hit.clear()
	g._pump_view()
	var pre_ok := false
	for i in 200:
		var before_hit := false
		for fr in g.view.queue:
			for e in fr["events"]:
				if g.event_route(e) == "attack" and int(fr["tick"]) == g.view.tick + 1:
					before_hit = true
		if before_hit:
			var u = g.view.units[0]
			var hh: int = g.pick_hit(g.atk_hit[u.id], g._disp_tick(), u.type)
			var at: float = g.atk_progress(g._disp_tick() - (hh - g.ViewBuffer.DELAY), u.type) if hh >= 0 else 0.0
			if at > 0.0 and at < Art.ATK_WINDUP:
				pre_ok = true
				break
		g._sim_step(false)
	ok(pre_ok, "命中前一格畫面上已經在前搖")
	# 連續反擊（Codex R5 #2）：H 的揮擊不會被 H+1／H+2 的前搖吃掉；揮擊做完才換下一次
	var sw_t := D.SWORD
	ok(g.pick_hit([10, 11, 12], 10.0, sw_t) == 10 and g.pick_hit([10, 11, 12], 10.9, sw_t) == 10, "連續命中：前一次揮擊做完前不換")
	# 揮擊結束時間和 atk_progress 共用：劍士 cd 20 tick → 總長 6.4、揮擊 1.408，所以 11.2 還在第一擊（Codex S4 #1）
	ok(g.pick_hit([10, 12], 11.2, sw_t) == 10 and g.atk_progress(11.2 - 8.0, sw_t) < Art.ATK_STRIKE, "連續命中：揮擊結束時間與動作進度一致")
	ok(g.pick_hit([10, 12], 11.5, sw_t) == 12 and g.pick_hit([10], 7.9, sw_t) == -1 and g.pick_hit([10], 8.0, sw_t) == 10, "連續命中：揮擊做完換下一次、前搖從命中前 2 tick 開始")
	# 播完之後（Codex R5 #1）：經過正式的 _battle_process，最後一格插值走完、展示時鐘繼續讓後搖演完、最後才進結果
	g.sim = Sim.new(army_from(0, [[D.SWORD, 5, 4], [D.SWORD, 5, 5]]), army_from(1, [[D.ARCHER, 5, 4]]))
	g.view = g.ViewBuffer.new(g.sim)
	g.atk_hit.clear()
	g.state = g.St.BATTLE
	g.speed = 1.0
	g.slow_used = true
	g.result_delay = 0.0
	g._pump_view()
	var steps := 0
	while not g.view.finished and steps < 4000:
		g._battle_process(0.05)
		steps += 1
	var tail_ok: bool = g.view.finished and g.state == g.St.BATTLE
	g._battle_process(0.1)
	var d1: float = g._disp_tick()
	g._battle_process(0.1)
	var d2: float = g._disp_tick()
	var pos_ok := true
	for u in g.view.units:
		var jit := Vector2(float((u.id * 37) % 9 - 4), float((u.id * 53) % 7 - 3))   # _upos 的固定錯開
		if u.alive and g._upos(u).distance_to(g.ORIGIN + Vector2(u.x, u.y) * g.CS / 1000.0 + jit) > 0.5:
			pos_ok = false
	ok(tail_ok and d2 > d1 and d1 > g.view.tick and pos_ok, "播完後展示時鐘繼續走、存活者插值到最後位置", "tail=%s d1=%.2f d2=%.2f tick=%d pos=%s" % [tail_ok, d1, d2, g.view.tick, pos_ok])
	# 直接造「最後一格確實有移動、最後一擊剛命中」的狀態（Codex 收尾輪 2 #5）：
	# 播完後經 _battle_process，位置要從上一格插值到最後一格，攻擊要經過後搖並完成（進度回到 0）。
	g.state = g.St.BATTLE
	g.accum = 0.0
	var mu = null
	for u in g.view.units:
		if u.alive:
			mu = u
			break
	var cur := Vector2(mu.x, mu.y)
	g.prev_pos[mu.id] = cur - Vector2(600, 0)          # 上一格在左邊 0.6 格
	g.atk_hit[mu.id] = [g.view.tick]                   # 最後一格剛命中
	var jit2 := Vector2(float((mu.id * 37) % 9 - 4), float((mu.id * 53) % 7 - 3))
	var start_dist: float = g._upos(mu).distance_to(g.ORIGIN + cur * g.CS / 1000.0 + jit2)
	var saw_recover := false
	var done := false
	for k in 12:
		g._battle_process(0.05)
		var hh2: int = g.pick_hit(g.atk_hit[mu.id], g._disp_tick(), mu.type)
		var at2: float = g.atk_progress(g._disp_tick() - (hh2 - g.ViewBuffer.DELAY), mu.type) if hh2 >= 0 else 0.0
		if at2 > Art.ATK_STRIKE:
			saw_recover = true
		if saw_recover and at2 == 0.0:
			done = true
	var end_dist: float = g._upos(mu).distance_to(g.ORIGIN + cur * g.CS / 1000.0 + jit2)
	ok(start_dist > 30.0 and end_dist < 0.5 and saw_recover and done, "播完後最後一格的移動插值走完、最後一擊演完後搖",
		"start=%.1f end=%.2f recover=%s done=%s" % [start_dist, end_dist, saw_recover, done])
	# 圖鑑小劇場真的跳字
	var pop_bad: Array = []
	for t in D.COUNT:
		g._open_codex(t)
		for k in g._cx_skills().size():
			g._cx_pick_skill(k)
			var seen := false
			for j in 400:
				g._codex_tick(0.05)
				if not g.cx_pops.is_empty():
					seen = true
					break
			if not seen:
				pop_bad.append(g._cx_skills()[k])
	ok(pop_bad.is_empty(), "圖鑑每段小劇場都真的跳字", str(pop_bad))
	g.free()


## 音效優先權（第二輪方案 R8）：聲道滿了，技能音搶走最低優先權裡最早開始的普通命中；普通命中搶不到技能音；有空位先用空位。
func test_sfx_priority() -> void:
	var SX = load("res://scripts/game/sfx.gd")
	var busy := [true, true, true, true]
	ok(SX.pick_channel([true, false, true, true], [0, 0, 0, 0], [0, 0, 0, 0], 0) == 1, "音效：有空聲道先用空的")
	ok(SX.pick_channel(busy, [2, 0, 0, 2], [0, 50, 10, 0], 2) == 2, "音效：滿了時技能音搶最低優先權裡最早開始的")
	ok(SX.pick_channel(busy, [2, 2, 3, 2], [0, 0, 0, 0], 0) == -1, "音效：普通命中搶不到技能音")
	ok(SX.pick_channel(busy, [2, 2, 2, 2], [0, 0, 0, 0], 2) == -1, "音效：同級不互搶")
	# V1.2 E4：具名匯流排都送進 Master（低通掛在 Master，整體一起悶），重複建立不會變多
	SX._ensure_buses()
	var nb := AudioServer.bus_count
	SX._ensure_buses()
	ok(AudioServer.bus_count == nb, "音效：匯流排不重複建立")
	for bn in ["Music", "SFX", "UI", "Ambience"]:
		var bi := AudioServer.get_bus_index(bn)
		ok(bi > 0 and AudioServer.get_bus_send(bi) == &"Master", "音效：%s 匯流排存在且送進 Master" % bn)
	var missing: Array = []
	for n in SX.FILES:
		if not FileAccess.file_exists("res://audio/%s.wav" % n) and not FileAccess.file_exists("res://audio/%s.ogg" % n):   # V1.2：CC0 錄音轉 ogg
			missing.append(n)
	for n in SX.PRIO:
		if not SX.FILES.has(n):
			missing.append("PRIO 有但 FILES 沒有：" + n)
	for n in SX.LAYERS:
		if not FileAccess.file_exists("res://audio/%s.wav" % n):
			missing.append(n)
	ok(missing.is_empty(), "音效：清單裡的檔案都在（含三條戰鬥分軌）", str(missing))
	var looped := true
	for n in SX.LAYERS:
		var st = load("res://audio/%s.wav" % n)
		if not (st is AudioStreamWAV) or st.loop_mode != AudioStreamWAV.LOOP_FORWARD or absf(float(st.loop_end) / st.mix_rate - st.get_length()) > 0.1:
			looped = false
	ok(looped, "分軌音樂：三軌都整段循環（循環終點＝整首長度，Codex S7 #1）")
	ok(SX.layer_targets(true, false) == [1.0, 1.0, 1.0] and SX.layer_targets(false, false)[1] < 0.5 and SX.layer_targets(true, true) == [1.0, 0.0, 0.0],
		"分軌音樂：差距小鼓聲進來、最後時刻只留低音")


## 副作用矩陣（第三輪 A1）：正式對局才寫比分、進度、成就、試玩日誌；重播 3 次全部不變。
## 走正式畫面程式（_begin_battle → _sim_step → _finish_battle → _replay），存檔用測試前綴，不碰玩家存檔。
func test_play_effects() -> void:
	var SV = load("res://scripts/game/save.gd")
	var GS = load("res://scripts/ui/game_screens.gd")
	if GS == null or not GS.can_instantiate():
		ok(false, "副作用矩陣：畫面腳本載入失敗")
		return
	var old_prefix: String = SV.prefix
	SV.prefix = "test_fx_"
	for fn in ["user://test_fx_save.json", "user://test_fx_save.json.bak", "user://test_fx_settings.json"]:
		if FileAccess.file_exists(fn):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(fn))
	SV.load_all()
	var g = GS.new()
	g.sfx = FakeSfx.new()
	g.mode = g.Mode.VS_AI
	g.difficulty = 1
	var keys := ["official", "replay", "review"]
	var mx_ok := true
	for k in keys:
		mx_ok = mx_ok and g.PLAY_EFFECTS.has(k)
	ok(mx_ok and g.PLAY_EFFECTS["official"]["progress"] and not g.PLAY_EFFECTS["replay"]["progress"] and not g.PLAY_EFFECTS["review"]["series"], "副作用矩陣：三種播放都有定義、只有正式會寫")
	var a0 = army_from(0, [[D.SWORD, 5, 4], [D.CAVALRY, 4, 2], [D.ARCHER, 1, 4]])
	var a1 = army_from(1, [[D.SWORD, 5, 4]])
	var play := func(kind: String) -> void:
		if kind == "official":
			g._begin_battle(a0.copy(), a1.copy())
		else:
			g._replay()
		var guard := 0
		while not g.view.finished and guard < 3000:
			g._sim_step(false)
			guard += 1
		g._finish_battle()
	play.call("official")
	var snap := func() -> String:
		return JSON.stringify([SV.data.get("stats"), SV.data.get("unit_wins"), SV.data.get("achievements"), g.wins, g.series_over, SV.data.get("custom_stats"), SV.data.get("unlock_games")])
	var after_official: String = snap.call()
	var games_1 := int(SV.data["stats"]["games"])
	for i in 3:
		play.call("replay")
	ok(games_1 == 1 and snap.call() == after_official and g.play_kind == "replay", "重播 3 次：場次、勝場、兵種勝場、成就、系列比分都不變", "%s → %s" % [after_official, snap.call()])
	play.call("official")
	ok(int(SV.data["stats"]["games"]) == 2, "重播之後再打正式的一場，照常記錄")
	# 覆盤播放：只看不算（副作用矩陣 review）
	var snap2: String = snap.call()
	g._open_review()
	g.rv_sel = Vector2i(5, 4)
	g._rv_set_type(D.SHIELD)
	g._rv_recalc()
	g._rv_play()
	var guard2 := 0
	while not g.view.finished and guard2 < 3000:
		g._sim_step(false)
		guard2 += 1
	g._finish_battle()
	ok(g.play_kind == "review" and snap.call() == snap2, "覆盤播放：比分、進度、成就都不變")
	# 第五輪：自訂規則（單局）→ 記在自訂戰績、解鎖場數 +1，標準戰績與標準成就不動；沙盒什麼都不記
	var RS5 = load("res://scripts/core/ruleset.gd")
	var cr = RS5.standard()
	cr.rounds = 1
	g.rules = cr
	var st_before := JSON.stringify(SV.data.get("stats"))
	var ach_before := JSON.stringify(SV.data.get("achievements"))
	var cs_before := int(SV.data.get("custom_stats", {}).get("games", 0))
	var ug_before := int(SV.data.get("unlock_games", 0))
	play.call("official")
	ok(JSON.stringify(SV.data.get("stats")) == st_before and JSON.stringify(SV.data.get("achievements")) == ach_before
		and int(SV.data["custom_stats"]["games"]) == cs_before + 1 and int(SV.data["unlock_games"]) == ug_before + 1,
		"自訂規則（單局，雖然數值是標準）：記在自訂戰績、解鎖場數 +1，標準戰績與成就不變", "%s %s" % [SV.data.get("custom_stats"), SV.data.get("unlock_games")])
	var sb = RS5.standard()
	sb.stat_pct = {D.SWORD: [150, 100, 100]}
	g.rules = sb
	var snap3: String = snap.call()
	play.call("official")
	var after3: String = snap.call()
	ok(JSON.stringify(JSON.parse_string(after3).slice(0, 3) + JSON.parse_string(after3).slice(5, 7)) == JSON.stringify(JSON.parse_string(snap3).slice(0, 3) + JSON.parse_string(snap3).slice(5, 7)),
		"沙盒：戰績、自訂戰績、解鎖場數、成就都不記", "%s → %s" % [snap3, after3])
	g.rules = null
	g.free()
	for fn in ["user://test_fx_save.json", "user://test_fx_save.json.bak", "user://test_fx_settings.json"]:
		if FileAccess.file_exists(fn):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(fn))
	SV.prefix = old_prefix
	SV.load_all()


## 輸入命令佇列（第三輪 A2）：畫面一換，同一幀排進來的舊命令就丟掉；只對這個畫面畫出來的按鈕有效；停用的按鈕不執行。
func test_input_queue() -> void:
	var GS = load("res://scripts/ui/game_screens.gd")
	if GS == null or not GS.can_instantiate():
		ok(false, "輸入佇列：畫面腳本載入失敗")
		return
	var g = GS.new()
	g.sfx = FakeSfx.new()
	var hits := [0, 0]
	var setup := func(next_state) -> void:
		g._cmds.clear()
		g.state = g.St.TITLE
		g.overlay = ""
		g._update_gen()
		g._btns = [
			{"r": Rect2(0, 0, 100, 40), "cb": func(): hits[0] += 1; g.state = next_state, "en": true},
			{"r": Rect2(0, 50, 100, 40), "cb": func(): hits[1] += 1, "en": false},
		]
		g._btns_gen = g._gen
	var bad: Array = []
	# 1 正常點一下：執行一次
	hits[0] = 0; hits[1] = 0; setup.call(g.St.TITLE); g._enqueue("click", Vector2(10, 10)); g._process_cmds()
	if hits[0] != 1: bad.append("1 正常點擊 %s" % [hits])
	# 2 同一幀連點兩下，第一下換了畫面：第二下丟掉
	hits[0] = 0; hits[1] = 0; setup.call(g.St.PLACE); g._enqueue("click", Vector2(10, 10)); g._enqueue("click", Vector2(10, 10)); g._process_cmds()
	if hits[0] != 1: bad.append("2 連點換畫面 %s" % [hits])
	# 3 停用的按鈕不執行
	hits[0] = 0; hits[1] = 0; setup.call(g.St.TITLE); g._enqueue("click", Vector2(10, 60)); g._process_cmds()
	if hits[1] != 0: bad.append("3 停用按鈕 %s" % [hits])
	# 4 點擊排入後、處理前開了覆蓋層：丟掉
	hits[0] = 0; hits[1] = 0; setup.call(g.St.TITLE); g._enqueue("click", Vector2(10, 10)); g.overlay = "settings"; g._process_cmds()
	if hits[0] != 0: bad.append("4 開覆蓋層後的舊點擊 %s" % [hits])
	# 5 畫面換了但新畫面的按鈕還沒畫：新排入的點擊也不能點到舊按鈕
	hits[0] = 0; hits[1] = 0; setup.call(g.St.TITLE); g.state = g.St.RESULT; g._update_gen(); g._enqueue("click", Vector2(10, 10)); g._process_cmds()
	if hits[0] != 0: bad.append("5 舊按鈕清單 %s" % [hits])
	# 6 Esc 關掉覆蓋層，同一幀後面的點擊丟掉
	hits[0] = 0; hits[1] = 0; setup.call(g.St.TITLE); g.overlay = "settings"; g._update_gen(); g._btns_gen = g._gen
	g._enqueue("key", KEY_ESCAPE); g._enqueue("click", Vector2(10, 10)); g._process_cmds()
	if hits[0] != 0 or g.overlay != "": bad.append("6 Esc 後的點擊 %s overlay=%s" % [hits, g.overlay])
	# 7 Enter 按焦點按鈕；按鈕清單過期時不按
	hits[0] = 0; hits[1] = 0; setup.call(g.St.TITLE); g._focus = 0; g._enqueue("key", KEY_ENTER); g._process_cmds()
	if hits[0] != 1: bad.append("7a Enter %s" % [hits])
	hits[0] = 0; hits[1] = 0; setup.call(g.St.TITLE); g._btns_gen = -1; g._focus = 0; g._enqueue("key", KEY_ENTER); g._process_cmds()
	if hits[0] != 0: bad.append("7b 過期 Enter %s" % [hits])
	# 9 同一幀先按 2（選盾兵）再點格子：擺下的是盾兵（Codex S1 #2：滑鼠也進同一個佇列）
	g.mode = g.Mode.VS_AI
	g.armies = [Army.new(0, 100), Army.new(1, 100)]
	g.state = g.St.PLACE
	g.overlay = ""
	g.selected = D.SWORD
	g._cmds.clear()
	g._update_gen()
	g._btns = []
	g._btns_gen = g._gen
	var cellp: Vector2 = g.ORIGIN + Vector2(4.5, 4.5) * g.CS
	g._enqueue("key", KEY_2)
	g._enqueue("mb", {"i": MOUSE_BUTTON_LEFT, "pressed": true, "pos": cellp})
	g._enqueue("mb", {"i": MOUSE_BUTTON_LEFT, "pressed": false, "pos": cellp})
	g._process_cmds()
	var placed: Array = g.armies[0].units
	if placed.size() != 1 or int(placed[0]["type"]) != D.SHIELD:
		bad.append("9 先選兵再點格子 %s" % [placed])
	# 10 開了圖鑑之後同一幀的塗兵命令要丟掉
	g.painting = true
	g.paint_team = 0
	g._enqueue("key", KEY_F1)
	g._enqueue("paint", g.ORIGIN + Vector2(3.5, 3.5) * g.CS)
	g._process_cmds()
	if g.armies[0].units.size() != 1:
		bad.append("10 開圖鑑後的塗兵 %d" % g.armies[0].units.size())
	g.overlay = ""
	# 11 搖桿連發：推下立刻一次、0.35 秒後每 0.12 秒一次；0.35～0.6 之間的抖動維持原狀；放開就停（Codex S1 #6）
	g.overlay = "settings"
	g.state = g.St.TITLE
	g._update_gen()
	g._cmds.clear()
	g.stick[JOY_AXIS_LEFT_Y] = 0.8
	g._stick_repeat(0.0)
	var n1: int = g._cmds.size()
	g._stick_repeat(0.2)
	var n2: int = g._cmds.size()
	g.stick[JOY_AXIS_LEFT_Y] = 0.5          # 抖動但沒放開
	g._stick_repeat(0.2)
	var n3: int = g._cmds.size()
	for k in 5:
		g._stick_repeat(0.12)
	var n4: int = g._cmds.size()
	g.stick[JOY_AXIS_LEFT_Y] = 0.1
	g._stick_repeat(0.5)
	var n5: int = g._cmds.size()
	if n1 != 1 or n2 != 1 or n3 != 2 or n4 != 7 or n5 != 7:
		bad.append("11 搖桿連發 %s" % [[n1, n2, n3, n4, n5]])
	g._cmds.clear()
	g.overlay = ""
	# 8 點在按鈕外：什麼都不做
	hits[0] = 0; hits[1] = 0; setup.call(g.St.TITLE); g._enqueue("click", Vector2(500, 500)); g._process_cmds()
	if hits != [0, 0]: bad.append("8 點空白 %s" % [hits])
	ok(bad.is_empty(), "輸入佇列：11 組序列（連點、換畫面、停用、覆蓋層、過期清單、Esc、Enter、選兵後落子、開圖鑑後塗兵、搖桿連發、空白）誤觸與重複執行都是 0", str(bad))
	g.free()


## 混戰可讀（第三輪 V1／V3）：用正式畫面程式逐幀播 6 場 48 隻左右的戰鬥（60fps），每幀量跳字外框：
## 正常顯示的兩兩重疊 0%、淡出中 ≤5%；關鍵跳字（衝鋒、背刺、頂住）一個都不漏；特效數不超過上限。
func test_crowd_readability() -> void:
	var GS = load("res://scripts/ui/game_screens.gd")
	if GS == null or not GS.can_instantiate():
		ok(false, "混戰可讀：畫面腳本載入失敗")
		return
	var g = GS.new()
	g.sfx = FakeSfx.new()
	g._load_fonts()   # V1.2：和遊戲同一套字型組合
	var pool := F.training_pool(0)
	var worst := 0.0
	var worst_f := 0.0
	var max_fx := 0
	var max_txt := 0
	var frames := 0
	var unplaced := 0
	for i in 6:
		g._begin_battle(pool[i * 3].copy(), pool[(i * 17 + 4) % pool.size()].mirrored(), "replay")
		g.speed = 1.0
		var guard := 0
		while g.state == g.St.BATTLE and not g.view.finished and guard < 9000:
			guard += 1
			g._process_inner(1.0 / 60.0)
			frames += 1
			for f in g.fx:
				if f["kind"] == "text" and not f.get("screen", false) and not f.has("rr"):
					unplaced += 1
			var st: Dictionary = g.text_overlap_stats()
			worst = maxf(worst, st["max_overlap"])
			worst_f = maxf(worst_f, st["max_overlap_fading"])
			max_txt = maxi(max_txt, st["visible"] + st["fading"])
			var nfx := 0
			for f in g.fx:
				if f["kind"] != "text":
					nfx += 1
			max_fx = maxi(max_fx, nfx)
	ok(unplaced == 0, "跳字：每一個要畫的跳字都已排版（沒排版的 %d 個）" % unplaced)
	ok(worst == 0.0 and worst_f <= 0.05, "跳字：正常顯示 0%% 重疊、淡出中 ≤5%%（%d 幀；最大 %.3f／%.3f）" % [frames, worst, worst_f])
	ok(g.text_key_in > 0 and g.text_key_in == g.text_key_shown, "關鍵跳字一個都不漏（%d／%d）" % [g.text_key_shown, g.text_key_in])
	# 壓力：一口氣塞 30 個不同種的關鍵跳字，上限仍是硬的（Codex S3）
	g.fx.clear()
	for k in 30:
		g._merge_text(k, ["charge", "backstab", "braced"][k % 3], "X", 1, Vector2(k * 37 % 500, k * 53 % 300), Color.WHITE)
	var nt := 0
	for f in g.fx:
		if f["kind"] == "text":
			nt += 1
	ok(nt <= g.TEXT_CAP, "關鍵跳字一口氣 30 個，畫面上仍 ≤%d 個（%d）" % [g.TEXT_CAP, nt])
	ok(max_txt <= g.TEXT_CAP and max_fx <= g.FX_CAP, "跳字與特效有上限（跳字最多 %d、特效最多 %d；丟掉一般跳字 %d、特效 %d）" % [max_txt, max_fx, g.text_dropped, g.fx_dropped])
	g.free()


## 回味（第三輪 S5）：對戰代碼來回、竄改要擋、版本不同要提示；覆盤一次只算改一隻、只看不算戰績；
## 重播跳轉：跳到第 t tick 再往下播，畫面狀態與結局要和從頭播一模一樣。
func test_replay_tools() -> void:
	var BC = load("res://scripts/game/battle_code.gd")
	var a0 = army_from(0, [[D.SWORD, 5, 4], [D.ARCHER, 1, 3], [D.CAVALRY, 3, 7]])
	var a1 = army_from(1, [[D.SHIELD, 5, 4], [D.ASSASSIN, 3, 2]])
	var code: String = BC.encode(a0, a1)
	var r: Dictionary = BC.decode(code)
	ok(r["ok"] and not r["mismatch"] and r["a0"].to_code() == a0.to_code() and r["a1"].to_code() == a1.to_code(), "對戰代碼：編碼再解碼，雙方陣型一樣")
	var tampered := code.substr(0, 10) + ("A" if code[10] != "A" else "B") + code.substr(11)
	ok(not BC.decode(tampered)["ok"] and not BC.decode("NTB1.xx.yy")["ok"], "對戰代碼：被改過或格式不對會擋下")
	var parts := code.split(".")
	var j = JSON.parse_string(Marshalls.base64_to_utf8(_pad64(parts[1])))
	j["r"] = "0.0.1"
	var body := Marshalls.utf8_to_base64(JSON.stringify(j)).replace("+", "-").replace("/", "_").replace("=", "")
	var old_ver := "NTB2.%s.%s" % [body, body.sha256_text().substr(0, 6)]
	var r2: Dictionary = BC.decode(old_ver)
	ok(r2["ok"] and r2["mismatch"], "對戰代碼：別的版本的代碼可以讀，但會標示版本不同")
	# 預算也要來回（Codex S5 #1）：遠征敵軍 160 金、殘局玩家 30 金
	var big := Army.new(1, 160)
	for k in 9:
		big.place(D.CAVALRY if k % 2 == 0 else D.SHIELD, 10 + k % 6, k)
	var small = army_from(0, [[D.SWORD, 5, 4]])
	small.budget = 30
	var r3: Dictionary = BC.decode(BC.encode(small, big))
	ok(r3["ok"] and r3["a1"].budget == 160 and r3["a0"].budget == 30 and r3["a1"].to_code() == big.to_code(), "對戰代碼：預算不是 100 的陣型也能來回", str(r3.get("why", "")))
	# 覆盤：改動計數
	var GS = load("res://scripts/ui/game_screens.gd")
	if GS == null or not GS.can_instantiate():
		ok(false, "回味：畫面腳本載入失敗")
		return
	var b0 = a0.copy()
	b0.remove_at(5, 4)
	b0.place(D.SHIELD, 5, 4)
	var b1 = a0.copy()
	b1.move(1, 3, 2, 3)
	var b2 = b1.copy()
	b2.remove_at(5, 4)
	ok(GS.review_changes(a0, a0) == 0 and GS.review_changes(a0, b0) == 1 and GS.review_changes(a0, b1) == 1 and GS.review_changes(a0, b2) == 2,
		"覆盤：換兵種、移一格各算一隻，兩處算兩隻")
	var rr: Dictionary = GS.review_run(b0, a1)
	var sm = Sim.new(b0.copy(), a1.copy()); sm.run_to_end()
	ok(int(rr["winner"]) == sm.winner and int(rr["ticks"]) == sm.tick, "覆盤：重算和正式模擬同一個結果")
	# 跳轉一致：從頭播到結束 vs 播到一半跳回第 60 tick 再播到結束
	var g = GS.new()
	g.sfx = FakeSfx.new()
	g.mode = g.Mode.VS_AI
	g.last_armies = [a0.copy(), a1.copy()]
	g._begin_battle(a0.copy(), a1.copy(), "replay")
	var straight := {}
	while not g.view.finished:
		g._sim_step(false)
		if g.view.tick == 60 or g.view.tick == 120:
			straight[g.view.tick] = _view_sig(g.view)
	var end_sig := _view_sig(g.view)
	var end_counts := JSON.stringify(g.ev_count)
	var end_marks := JSON.stringify(g.battle_marks.filter(func(m): return m["kind"] != "clutch"))
	g._begin_battle(a0.copy(), a1.copy(), "replay")
	for k in 150:
		g._sim_step(false)
	g._seek(60)
	ok(g.view.tick == 60 and straight.has(60) and _view_sig(g.view) == straight[60], "重播跳轉：畫面剛好停在第 60 tick，狀態和從頭播一樣", "tick=%d" % g.view.tick)
	var seek_ok := true
	while not g.view.finished:
		g._sim_step(false)
		if straight.has(g.view.tick) and straight[g.view.tick] != _view_sig(g.view):
			seek_ok = false
	ok(seek_ok and _view_sig(g.view) == end_sig and JSON.stringify(g.ev_count) == end_counts, "重播跳轉：跳回第 60 tick 再播，畫面狀態、結局、戰報次數都和從頭播一樣")
	ok(JSON.stringify(g.battle_marks.filter(func(m): return m["kind"] != "clutch")) == end_marks, "重播跳轉：時間軸標記（首次衝鋒等）也和從頭播一樣")
	# 跳到後段：跳過的標記要重建出來
	g._seek(int(g.replay_total) - 5)
	while not g.view.finished:
		g._sim_step(false)
	ok(JSON.stringify(g.battle_marks.filter(func(m): return m["kind"] != "clutch")) == end_marks, "重播跳轉：直接跳到結尾附近，前面的標記也會重建")
	# 看對戰代碼：當成新的一局（Codex S5 #2）
	g.wins = [1, 1]
	g.round_no = 3
	g.armies = []
	g.watch_code(a0, a1)
	ok(g.watch_mode and g.wins == [0, 0] and g.round_no == 1 and g.armies.size() == 2 and g.play_kind == "replay", "看對戰代碼：比分、局數、陣型都重新初始化")
	# 覆盤換兵買不起：保留原兵（Codex S5 #3）
	g.last_armies = [army_from(0, [[D.SWORD, 5, 4]]), a1.copy()]
	g.last_armies[0].budget = 6
	g._open_review()
	g.rv_sel = Vector2i(5, 4)
	g._rv_set_type(D.CAVALRY)
	ok(g.rv_army.units.size() == 1 and int(g.rv_army.units[0]["type"]) == D.SWORD, "覆盤：換成買不起的兵種時保留原兵")
	g.free()


## 重播跳轉與最後時刻（Codex S7 #2）：最後時刻是否已發生要依目標時間重算，不靠先前的播放紀錄。
## 找一場會觸發最後時刻的戰鬥，從頭播一次記下標記；再「跳到觸發後 → 跳回觸發前 → 再跳到觸發後」播完，標記（含最後時刻）要一樣。
func test_seek_clutch() -> void:
	var GS = load("res://scripts/ui/game_screens.gd")
	var BVs = load("res://scripts/ui/battle_view.gd")
	var g = JSON.parse_string(FileAccess.get_file_as_string("res://tests/golden/golden.json"))
	var pick := -1
	var ct := -1
	for i in 60:
		var c: Dictionary = g["cases"][i]
		var a0 := Army.new(0, 100); a0.load_code(c["a"])
		var a1 := Army.new(1, 100); a1.load_code(c["b"])
		var sm = Sim.new(a0, a1)
		sm.fast = true
		while not sm.finished:
			sm.step()
			if not sm.finished and BVs.clutch_cond(sm):
				ct = sm.tick
				break
		if ct > 40:
			pick = i
			break
		ct = -1
	if pick < 0:
		ok(false, "重播跳轉＋最後時刻：找不到會觸發最後時刻的測試場")
		return
	var c2: Dictionary = g["cases"][pick]
	var b0 := Army.new(0, 100); b0.load_code(c2["a"])
	var b1 := Army.new(1, 100); b1.load_code(c2["b"])
	var gg = GS.new()
	gg.sfx = FakeSfx.new()
	gg.mode = gg.Mode.VS_AI
	gg.last_armies = [b0.copy(), b1.copy()]
	gg._begin_battle(b0.copy(), b1.copy(), "replay")
	while not gg.view.finished:
		gg._sim_step(false)
	var want := JSON.stringify(gg.battle_marks)
	var want_ct: int = gg.clutch_tick
	gg._seek(ct + 20)
	gg._seek(maxi(0, ct - 20))
	var before_ok: bool = not gg.slow_used and gg.clutch_tick == -1
	gg._seek(ct + 20)
	while not gg.view.finished:
		gg._sim_step(false)
	ok(want_ct == ct and before_ok and gg.clutch_tick == want_ct and JSON.stringify(gg.battle_marks) == want,
		"重播跳轉：最後時刻在觸發點前後來回跳，狀態與標記都和從頭播一樣（觸發於 %d tick）" % ct, "%s vs %s" % [want, JSON.stringify(gg.battle_marks)])
	gg.free()


## 最後時刻的演出副作用（Codex S8 #2、#3）：直接看結果／跳轉補播不放慢動作、不播音效；
## 正常播放時同一幀觸發慢動作後，剩下的累積不再用原速消耗。
func test_clutch_effects() -> void:
	var GS = load("res://scripts/ui/game_screens.gd")
	var BVs = load("res://scripts/ui/battle_view.gd")
	var g = JSON.parse_string(FileAccess.get_file_as_string("res://tests/golden/golden.json"))
	var pick := -1
	for i in 60:
		var c: Dictionary = g["cases"][i]
		var a0 := Army.new(0, 100); a0.load_code(c["a"])
		var a1 := Army.new(1, 100); a1.load_code(c["b"])
		var sm = Sim.new(a0, a1)
		sm.fast = true
		var hit := false
		while not sm.finished:
			sm.step()
			if not sm.finished and BVs.clutch_cond(sm):
				hit = sm.tick > 40
				break
		if hit:
			pick = i
			break
	if pick < 0:
		ok(false, "最後時刻演出：找不到測試場")
		return
	var c2: Dictionary = g["cases"][pick]
	var b0 := Army.new(0, 100); b0.load_code(c2["a"])
	var b1 := Army.new(1, 100); b1.load_code(c2["b"])
	var gg = GS.new()
	var fs := FakeSfx.new()
	gg.sfx = fs
	gg.mode = gg.Mode.VS_AI
	gg._begin_battle(b0.copy(), b1.copy(), "replay")
	gg._on_skip()
	ok(gg.slow_used and gg.slow_left == 0.0 and not fs.played.has("clutch"), "直接看結果：最後時刻只記標記，不放慢動作、不播音效")
	# 正常播放：一次給很大的時間（一幀多個 tick），觸發慢動作的那一 tick 之後要停下來
	gg._begin_battle(b0.copy(), b1.copy(), "replay")
	var steps_before := -1
	var guard := 0
	while not gg.slow_used and guard < 400:
		guard += 1
		var t0: int = gg.view.tick
		gg._battle_process(0.5)   # 一幀 10 tick
		if gg.slow_used:
			steps_before = gg.view.tick - t0
	ok(gg.slow_used and gg.view.tick == gg.clutch_tick and gg.accum > 0.0, "同一幀觸發慢動作：停在觸發那一 tick，剩下的時間留給慢速（多走了 %d tick）" % (gg.view.tick - gg.clutch_tick))
	gg.free()


## 第四輪：兵種開放、結果頁兵種長條與技能徽章、存檔相容
func test_roster_ui() -> void:
	var RS = load("res://scripts/game/roster.gd")
	var GS = load("res://scripts/ui/game_screens.gd")
	var bad: Array = []
	if RS.ntypes_for("duel", false) != 10 or RS.ntypes_for("duel", true) != 5 or RS.ntypes_for("ai", false) != 10 or RS.ntypes_for("ai", true) != 5 or RS.ntypes_for("ai", false, true) != 7:
		bad.append("模式開放數")
	# AI 只用開放的兵種：經典 5 種時，所有模板與落子 AI 都不會拿出新兵
	var rng := RandomNumberGenerator.new()
	for i in 40:
		rng.seed = 900 + i
		var a = AI.build(1, 100, rng, -1, 31)["army"]
		var b = load("res://scripts/core/ai_turns.gd").build_full(1, rng, i % 3, [], 31)
		for u in a.units + b.units:
			if int(u["type"]) >= 5:
				bad.append("經典模式 AI 用了兵種 %d" % u["type"])
				break
	# 指定模板也不能繞過開放數（Codex 實作審查 #3）
	for ti in AI.TEMPLATES.size():
		rng.seed = 77 + ti
		var c = AI.build(1, 100, rng, ti, 31)["army"]
		for u in c.units:
			if int(u["type"]) >= 5:
				bad.append("指定模板 %d 用了兵種 %d" % [ti, u["type"]])
				break
	ok(bad.is_empty(), "兵種開放：場數解鎖、試玩版上限、經典模式、AI（含指定模板）不用未開放的兵種", str(bad))
	# 結果頁兵種長條：只列出場的、合計最多的 5 種
	var dealt := [D.zeros(), D.zeros()]
	var taken := [D.zeros(), D.zeros()]
	for t in [0, 2, 5, 6, 7, 9]:
		dealt[0][t] = 10 + t
	taken[1][3] = 1
	var rows: Array = GS.report_rows(dealt, taken)
	ok(rows == [9, 7, 6, 5, 2], "結果頁兵種長條：出場的兵種依合計排序、最多 5 種", str(rows))
	var cnt := {"heal0": 9, "breach1": 3, "charge0": 1}
	var bg: Array = GS.report_badges(cnt)
	ok(bg.size() == 6 and bg[0] == "heal" and bg[1] == "breach" and bg[2] == "charge" and bg.has("breaker"), "結果頁技能徽章：有發生的依次數排前面，支援兵的補血也算", str(bg))


# ═══════════════════ 第五輪：自訂規則 ═══════════════════


## 第七輪 K1：按鍵重設。
func test_keymap_v7() -> void:
	var KM = load("res://scripts/game/keymap.gd")
	var t: Dictionary = {}
	ok(KM.key_to_default(t, KEY_SPACE) == KEY_SPACE and KM.key_to_default(t, KEY_A) == KEY_A, "K1：沒改過＝原樣")
	t = KM.rebind(KM.ACTIONS, t, "start", KEY_F)
	ok(KM.key_to_default(t, KEY_F) == KEY_SPACE, "K1：新鍵會換回預設動作")
	ok(KM.key_to_default(t, KEY_SPACE) == -1, "K1：舊鍵不再開戰")
	t = KM.rebind(KM.ACTIONS, t, "pause", KEY_F)
	ok(KM.key_of(t, "pause") == KEY_F and KM.key_of(t, "start") == KEY_P, "K1：撞鍵會互換", str(t))
	ok(KM.key_name(t, "pause") == "F", "K1：提示跟著按鍵走", KM.key_name(t, "pause"))
	ok(KM.sanitize(KM.ACTIONS, {"start": "x", "pause": 70.0, "nope": 1}) == {"pause": 70}, "K1：存檔裡的表逐項驗型")
	var pt: Dictionary = KM.rebind(KM.PAD_ACTIONS, {}, "start", JOY_BUTTON_Y)
	ok(KM.pad_to_default(pt, JOY_BUTTON_Y) == JOY_BUTTON_START and KM.pad_name(pt, "start") == "Y", "K1：手把也能改")
	ok(KM.pad_name(pt, "pause") == "Start", "K1：手把撞鍵也互換")
	ok(KM.rebind(KM.PAD_ACTIONS, {}, "start", JOY_BUTTON_DPAD_UP) == {} and KM.sanitize(KM.PAD_ACTIONS, {"start": JOY_BUTTON_DPAD_UP}) == {}, "K1：手把十字鍵不能綁")
	ok(KM.sanitize(KM.ACTIONS, {"start": KEY_LEFT}) == {}, "K1：舊設定裡的保留鍵讀檔時丟掉")
	ok(KM.rebind(KM.PAD_ACTIONS, {}, "codex", JOY_BUTTON_LEFT_STICK) == {} and KM.sanitize(KM.PAD_ACTIONS, {"pause": JOY_BUTTON_RIGHT_STICK}) == {}, "第十三輪：L3、R3 留給殘局提示與時間設定，不能綁（Codex v13-r2 #2）")
	ok(not KM.can_bind_key(KEY_LEFT) and not KM.can_bind_key(KEY_SHIFT) and KM.rebind(KM.ACTIONS, {}, "start", KEY_LEFT) == {}, "K1：方向鍵、修飾鍵不能綁")


## 第七輪 A9：重播返回只還原畫面，比分、進度、成就、試玩紀錄都不寫。
func test_replay_back_v7() -> void:
	var SV = load("res://scripts/game/save.gd")
	var GS = load("res://scripts/ui/game_screens.gd")
	var old_prefix: String = SV.prefix
	SV.prefix = "test_back_"
	for fn in ["user://test_back_save.json", "user://test_back_save.json.bak", "user://test_back_settings.json"]:
		if FileAccess.file_exists(fn):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(fn))
	SV.load_all()
	var g = GS.new()
	g.sfx = FakeSfx.new()
	g.mode = g.Mode.VS_AI
	g.difficulty = 1
	var a0 = army_from(0, [[D.SWORD, 5, 4], [D.CAVALRY, 4, 2], [D.ARCHER, 1, 4]])
	var a1 = army_from(1, [[D.SWORD, 5, 4]])
	g._begin_battle(a0.copy(), a1.copy())
	while not g.view.finished:
		g._sim_step(false)
	g._finish_battle()
	g.state = g.St.RESULT
	var snap := JSON.stringify([SV.data, g.wins, g.series_over])
	var original_sim = g.sim
	var fp: String = str(g.sim.fingerprint)
	g._replay()
	ok(g.state == g.St.BATTLE and g.play_kind == "replay", "A9：進了重播")
	for i in 30:
		g._sim_step(false)
	g._replay_back()
	ok(g.state == g.St.RESULT and g.sim == original_sim and str(g.sim.fingerprint) == fp and g.play_kind == "official", "A9：返回結算，還是原本那一場")
	ok(JSON.stringify([SV.data, g.wins, g.series_over]) == snap, "A9：返回不寫比分、進度、成就")
	# Codex r1 的回歸：評分與戰報還原、算到一半返回不留目標、暫停中直接看結果會結束
	g.pt_rated = true
	g.ev_count = {"charge0": 3}
	g._replay()
	ok(g.pt_rated == false, "A9：重播會重設評分狀態（前提）")
	g.seek_target = 100
	g._replay_back()
	ok(g.pt_rated == true and g.ev_count == {"charge0": 3} and g.seek_target == -1, "A9：返回還原評分與戰報、清掉未完成的跳轉")
	g._replay()
	g.paused = true
	g._on_skip()
	ok(g.view.finished and g.paused == false and g.result_delay == 9.0, "A6：暫停中直接看結果不會卡住")
	# Codex r2：重播結束再重播，返回還是回到正式結算
	g._replay()
	g._replay_back()
	ok(g.sim == original_sim and g.play_kind == "official", "A9：連續重播兩次，返回還是原本那一場")
	g._rv_dirty()
	var gen0: int = g.rv_gen
	g._rv_dirty()
	ok(g.rv_gen == gen0 + 1 and g.rv_result == {}, "M3：改陣型會讓算到一半的結果作廢")
	# 看對戰代碼：返回標題
	g.watch_code(a0.copy(), a1.copy(), null)
	g._replay_back()
	ok(g.state == g.St.TITLE, "A9：看代碼的返回目的地是標題", str(g.state))
	# A7：首殺等關鍵時刻有收
	ok(g.L.has("tl_death") and g.L.has("tl_breach") and g.L.has("tl_rally_on"), "A7：關鍵時刻都有文字")
	g.queue_free()
	for fn2 in ["user://test_back_save.json", "user://test_back_save.json.bak", "user://test_back_settings.json"]:
		if FileAccess.file_exists(fn2):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(fn2))
	SV.prefix = old_prefix
