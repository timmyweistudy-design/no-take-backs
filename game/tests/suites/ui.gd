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
	if not FileAccess.file_exists("res://audio/music_battle.ogg"):
		missing.append("music_battle.ogg")
	ok(missing.is_empty(), "音效：清單裡的檔案都在（含錄音戰鬥曲）", str(missing))
	var mb = SX.load_audio("music_battle")
	ok(mb != null and "loop" in mb, "戰鬥曲：錄音單軌可設循環（V1.2 取代合成三分軌）")
	ok(SX.layer_targets(true, false) == [1.0, 1.0, 1.0] and SX.layer_targets(false, false)[1] < 0.5 and SX.layer_targets(true, true) == [1.0, 0.0, 0.0],
		"分軌音樂：差距小鼓聲進來、最後時刻只留低音")


## 副作用矩陣（第三輪 A1）：正式對局才寫比分、進度、成就、試玩日誌；重播 3 次全部不變。
## 走正式畫面程式（_begin_battle → _sim_step → _finish_battle → _replay），存檔用測試前綴，不碰玩家存檔。
## V1.2.1：普通 AI 的陣型名都有英文（英文介面原本顯示中文陣型名）
func test_ai_names_v121() -> void:
	var AI = load("res://scripts/core/ai_army.gd")
	var GC = load("res://scripts/ui/screens/game_core.gd")
	var miss: Array = []
	for tp in AI.TEMPLATES:
		if not GC.AI_TPL_EN.has(tp["name"]):
			miss.append(tp["name"])
	ok(miss.is_empty(), "AI 陣型名都有英文", str(miss))
	# V1.2.1：每個成就都有解鎖條件（中英）
	var GM = load("res://scripts/ui/screens/game_playroom.gd")
	var ST = load("res://scripts/game/steam.gd")
	var miss2: Array = []
	for k in ST.ACHIEVEMENTS:
		if not GM.ACH_DESC.has(k) or str(GM.ACH_DESC[k][0]) == "" or str(GM.ACH_DESC[k][1]) == "":
			miss2.append(k)
	ok(miss2.is_empty(), "成就都有解鎖條件", str(miss2))
	# V1.2.1 E2：響度修正表的檔名都存在、修正幅度有限（不硬拉成同一響度）
	var tj = JSON.parse_string(FileAccess.get_file_as_string("res://data/audio_trim.json"))
	var badt: Array = []
	for fn in tj["trim"]:
		var v := float(tj["trim"][fn])
		if not FileAccess.file_exists("res://audio/" + fn) or absf(v) > 6.0 or v > 2.5:
			badt.append("%s %s" % [fn, v])
	ok(tj is Dictionary and badt.is_empty(), "E2：響度修正檔名存在、幅度 ≤6 dB、拉大聲 ≤2.5 dB", str(badt))


## V1.2.1 F1：樣式快取量化與上限（淡出不會讓快取無限成長；相近透明度共用同一個樣式）
func test_style_cache_v121() -> void:
	var GS = load("res://scripts/ui/game_screens.gd")
	var g = GS.new()
	for i in 2000:
		g._flat_sb(Color(0.2, 0.1, 0.05, i / 2000.0), Color(0, 0, 0, 0), 6.0, 0.0)
	ok(g._sb_cache.size() <= 16, "F1：同色 2000 種透明度只產生 ≤16 個樣式", str(g._sb_cache.size()))
	ok(g._flat_sb(Color(0.2, 0.1, 0.05, 0.50), Color(0, 0, 0, 0), 6.0, 0.0) == g._flat_sb(Color(0.2, 0.1, 0.05, 0.51), Color(0, 0, 0, 0), 6.0, 0.0), "F1：相近透明度共用樣式")
	for i in 1200:
		g._flat_sb(Color(float(i % 256) / 255.0, float(i / 256) / 255.0, 0.3, 1.0), Color(0, 0, 0, 0), 6.0, 0.0)
	ok(g._sb_cache.size() <= g.SB_CACHE_MAX, "F1：快取有上限", str(g._sb_cache.size()))
	ok(g.qcol(Color(0.3, 0.3, 0.3, 0.5)).a == g._flat_sb(Color(0.3, 0.3, 0.3, 0.5), Color(0, 0, 0, 0), 6.0, 0.0).bg_color.a, "F1：樣式用的是量化後的顏色（鍵與實際一致）")
	g.free()


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
				if not f["kind"] in g.FX_CAP_EXEMPT:   # 1.4.0：茶漬範圍提示另有 STAIN_MAX（Codex cat05 #1）
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


class FakeTurnUnit:
	var id := 0
	var fx := 1
	var team := 0
	var type := 0
	func _init(i: int, t: int) -> void:
		id = i
		type = t

## V1.3：轉身寬度、呼吸錯開、倒棋時間、特效上限、擺陣沉降（只是畫面，不碰模擬）。
func test_feel_v130() -> void:
	var GS = load("res://scripts/ui/game_screens.gd")
	var Art = load("res://scripts/ui/art.gd")
	var D = load("res://scripts/core/unit_defs.gd")
	var g = GS.new()
	g.time = 10.0
	var u := FakeTurnUnit.new(7, D.ARCHER)
	for f in [0.0, 0.05, -0.05, 0.3, -0.3, 0.9, -1.0]:
		g.face_now[u.id] = f
		var w: float = g._face_of(u)
		ok(absf(w) >= g.TURN_MIN_W - 0.001 and absf(w) <= 1.0 + g.TURN_BOUNCE + 0.001, "A1a：轉身寬度不低於 %.2f（朝向 %.2f → %.3f）" % [g.TURN_MIN_W, f, w])
	g.face_now[u.id] = 0.5
	g.turn_t[u.id] = 9.9
	ok(g._turn_dust_k(u) > 0.0, "A1a：剛翻面有腳下揚塵")
	g.time = 11.0
	ok(g._turn_dust_k(u) == 0.0, "A1a：揚塵 0.25 秒後消失")
	# 呼吸：同一欄（x 相同）不同列，相位不同
	var b1: float = Art.idle_bob(3.0, Vector2(400, 300))
	var b2: float = Art.idle_bob(3.0, Vector2(400, 364))
	ok(absf(b1 - b2) > 0.05, "A2：同一欄上下兩隻呼吸不同步", "%.3f %.3f" % [b1, b2])
	Art.bake_no_bob = true
	ok(Art.idle_bob(3.0, Vector2(400, 300)) == 0.0, "A2：烘焙時不加呼吸")
	Art.bake_no_bob = false
	ok(Art.turn_c == 1.0 and Art.turn_s == 0.0, "A1b：平常 turn_c＝1（一般影格不受轉身影響）")
	# 倒棋
	ok(g.death_life(D.SWORD) > 1.5 and g.death_life(14) == 1.0, "A5：一般兵倒棋留 1.7 秒、幽靈等專屬死法 1 秒")
	# 頭頂符號上限：滿了丟最舊的，新的留著
	g.fx = []
	for i in 9:
		g._add_fx({"kind": "bang", "p": Vector2(100 + i * 60, 200), "t": 0.01 * (9 - i), "dur": 0.7, "tag": i})
	var n_bang := 0
	var has_last := false
	for f in g.fx:
		if f["kind"] == "bang":
			n_bang += 1
			if int(f.get("tag", -1)) == 8:
				has_last = true
	ok(n_bang <= int(g.OVERHEAD_CAP["bang"]) and has_last, "C：頭頂驚嘆號最多 %d 個、最新的一定在" % int(g.OVERHEAD_CAP["bang"]), str(n_bang))
	# 跳字上限
	g.fx = []
	for i in 30:
		g._fx_text(Vector2(100 + i * 20, 300), "-%d" % i, Color.WHITE, 1.0, 12)
	var n_txt := 0
	for f in g.fx:
		if f["kind"] == "text":
			n_txt += 1
	ok(n_txt <= g.FX_TEXT_CAP, "P1：_fx_text 有上限", str(n_txt))
	# 擺陣沉降
	g.time = 5.0
	g.settle_t[Vector2i(1000, 2000)] = 4.95
	ok(g._settle_dy(Vector2i(1000, 2000)) < 0.0, "B3：剛放下時還在空中")
	g.time = 5.5
	ok(g._settle_dy(Vector2i(1000, 2000)) == 0.0 and not g.settle_t.has(Vector2i(1000, 2000)), "B3：沉降結束歸位並清掉")
	g.free()


## V1.3.1：角色做完整（22 種轉身、待機小動作、表情），全是畫面，不碰模擬。
func test_characters_v131() -> void:
	var SC = load("res://scripts/ui/sprite_cache.gd")
	var Art = load("res://scripts/ui/art.gd")
	ok(SC.TURN_TYPES.size() == 22, "P0-1：22 種兵都有轉身影格", str(SC.TURN_TYPES.size()))
	var miss: Array = []
	for t in 22:
		if not SC.FIDGET.has(t):
			miss.append(t)
	ok(miss.is_empty(), "P1：22 種兵都有待機小動作設定", str(miss))
	ok(Art.turn_c == 1.0 and not Art.calm and Art.look == 0.0 and Art.hat_pop == 0.0 and not Art.baking and Art.anchor_key == "", "平常沒有殘留的烘焙狀態（轉身、小動作、帽子、錨點）")
	var ms := [Art.M_HURT, Art.M_SPARKLE, Art.M_BROWS, Art.M_HOOD, Art.M_BRACE, Art.M_HAPPY, Art.M_SURPRISE, Art.M_GRIM]
	var acc := 0
	var dup := false
	for m in ms:
		if acc & m:
			dup = true
		acc |= m
	ok(not dup, "表情位元不重疊")
	# 記憶體預算（方案 §0：常駐圖集增量 ≤104 MiB，相對 V1.3.0 的 6 種轉身頁）
	var cells_turn: int = 22 * 2 * SC.TURN_C.size()
	var cells_fid: int = 22 * 2 * SC.FID_PER
	var cells_wt: int = 22 * 2 * SC.WT_C.size() * SC.WT_PH
	var mib := func(cells: int) -> float: return ceilf(float(cells) / SC.COLS) * SC.CELL * SC.COLS * SC.CELL * 4.0 / 1048576.0
	var wt_pages := ceili(22.0 / SC.WT_TYPES_PER_PAGE)
	var total: float = mib.call(cells_turn) + mib.call(cells_fid) + wt_pages * mib.call(SC.WT_TYPES_PER_PAGE * 2 * SC.WT_C.size() * SC.WT_PH)
	var v130: float = mib.call(6 * 2 * 3)
	ok(total - v130 <= 104.0, "§0：轉身／小動作／走路轉身圖集增量 ≤104 MiB", "%.1f MiB" % (total - v130))
	ok(cells_wt > 0 and SC.WT_TYPES_PER_PAGE * 2 * SC.WT_C.size() * SC.WT_PH / SC.COLS * SC.CELL <= 4096, "走路轉身每頁不超過 4096px")
	# P2：每種兵的音高、最後一擊定格、遺物
	var SX = load("res://scripts/game/sfx.gd")
	ok(SX.UNIT_PITCH.size() == 22, "P2：22 種兵都有自己的音高", str(SX.UNIT_PITCH.size()))
	var GS = load("res://scripts/ui/game_screens.gd")
	var g = GS.new()
	ok(int(g.last_kill[0]) == -1 and g.has_method("_draw_relic"), "P2：最後一擊紀錄預設為空、遺物落地函式存在")
	g.free()


## V1.4 #1 時光機：分岔點計算、原本時間線同步（確定性：同一組陣型追到同一 tick 狀態一樣）。
func test_time_machine_v140() -> void:
	var RV = load("res://scripts/ui/replay_view.gd")
	var a := PackedInt64Array([5, 5, 6, 6, 7, 7])
	var b := PackedInt64Array([5, 5, 6, 6, 8, 7])
	ok(RV.diverge_tick(a, b) == 3, "分岔點＝第一個不一樣的 tick（紀錄第一筆是 tick 1）", str(RV.diverge_tick(a, b)))
	ok(RV.diverge_tick(a, a) == -1, "完全一樣回 -1")
	ok(RV.diverge_tick(a, a.slice(0, 4)) == 3, "一場比較早結束：分岔在較短那場結束後的那一 tick")
	var Sim = load("res://scripts/core/battle_sim.gd")
	var AI = load("res://scripts/core/ai_army.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 140
	var a0 = AI.build(0, 100, rng, 3)["army"]
	var a1 = AI.build(1, 100, rng, 4)["army"]
	var s1 = Sim.new(a0.copy(), a1.copy())
	s1.fast = true
	for i in 300:
		s1.step()
	var s2 = Sim.new(a0.copy(), a1.copy())
	s2.fast = true
	for i in 300:
		s2.step()
	var same: bool = s1.units.size() == s2.units.size()
	for i in mini(s1.units.size(), s2.units.size()):
		if s1.units[i].x != s2.units[i].x or s1.units[i].hp != s2.units[i].hp:
			same = false
	ok(same, "原本時間線重建後追到同一 tick，位置與血量完全一樣（淡圈才對得上）")


## V1.4 #3 戰利品契約：判定只看陣型與戰後狀態。
func test_contracts_v140() -> void:
	var GM = load("res://scripts/ui/screens/game_playroom.gd")
	var Army = load("res://scripts/core/army.gd")
	var a = Army.new(0, 100)
	a.units = [{"type": 0, "col": 0, "row": 0}, {"type": 1, "col": 1, "row": 0}, {"type": 0, "col": 2, "row": 0}]
	ok(GM.contract_ok(0, a, true, 800, 50), "輕裝：沒有遠程兵＋贏＝達成")
	a.units.append({"type": 2, "col": 3, "row": 0})
	ok(not GM.contract_ok(0, a, true, 800, 50), "輕裝：帶了弓箭手＝失敗")
	ok(GM.contract_ok(1, a, true, 800, 50), "精兵：3 種兵以內")
	a.units.append({"type": 5, "col": 4, "row": 0})
	ok(not GM.contract_ok(1, a, true, 800, 50), "精兵：4 種兵＝失敗")
	ok(GM.contract_ok(2, a, true, 900, 10) and not GM.contract_ok(2, a, true, 901, 10), "速戰：45 秒（900 tick）內")
	ok(GM.contract_ok(3, a, true, 2000, 60) and not GM.contract_ok(3, a, true, 2000, 59), "完勝：剩 60% 以上")
	ok(not GM.contract_ok(4, a, false, 100, 99), "輸了一律沒達成")
	ok(GM.CONTRACTS.size() == 6, "6 份契約")


## V1.4 #2 宿敵戰記：稱號固定、同陣再輸加次數、最多 6 個、宿敵陣多帶一隻最貴的兵。
func test_nemesis_v140() -> void:
	var GS = load("res://scripts/ui/game_screens.gd")
	var SV = load("res://scripts/game/save.gd")
	var Army = load("res://scripts/core/army.gd")
	var g = GS.new()
	var keep = SV.data.get("nemeses", [])
	SV.data["nemeses"] = []
	var e = Army.new(1, 100)
	e.units = [{"type": 5, "col": 10, "row": 2}, {"type": 0, "col": 11, "row": 3}]
	ok(g.nemesis_title_parts(e.units) == g.nemesis_title_parts(e.units.duplicate(true)), "同一個陣稱號一樣")
	g._nemesis_record(e)
	g._nemesis_record(e)
	ok(SV.data["nemeses"].size() == 1 and int(SV.data["nemeses"][0]["losses"]) == 2, "同一個陣再輸一次是加次數")
	for k in 8:
		var e2 = Army.new(1, 100)
		e2.units = [{"type": k % 10, "col": 10, "row": k % 9}]
		g._nemesis_record(e2)
	ok(SV.data["nemeses"].size() <= g.NEM_MAX, "最多 6 個宿敵")
	SV.data["nemeses"] = [{"units": [{"type": 5, "col": 10, "row": 2}, {"type": 0, "col": 11, "row": 3}], "losses": 1, "revenged": false}]
	var na = g._nemesis_army(0)
	ok(na.units.size() == 3 and int(na.units[2]["type"]) == 5, "宿敵多帶一隻最貴的兵（長槍兵）", str(na.units))
	SV.data["nemeses"] = keep
	g.free()


## V1.4 #17 簡中、日文：每個鍵都有字、參數一致；資料欄位、成就名、AI 陣型名都走得到；日文禁則。
func test_l10n_v140() -> void:
	var L0 = load("res://scripts/game/strings.gd")
	var ST = load("res://scripts/game/steam.gd")
	var CX = load("res://scripts/game/codex.gd")
	var keep: String = L0.lang
	ok(L0.LANGS.has("zh_CN") and L0.LANGS.has("ja"), "語言清單有簡中、日文")
	var empty: Array = []
	for l in ["zh_CN", "ja"]:
		L0.lang = l
		for k in L0.keys():
			if str(L0._table[k].get(l, "")) == "":
				empty.append(l + ":" + k)
	ok(empty.is_empty(), "簡中、日文每個鍵都有字", str(empty.slice(0, 5)))
	L0.lang = "zh_CN"
	ok(L0.t("menu_playroom") == "游戏间", "簡中是簡體字", L0.t("menu_playroom"))
	L0.lang = "ja"
	ok(ST.name_of("FIRST_WIN", "ja") != ST.ACHIEVEMENTS["FIRST_WIN"][1], "成就名有日文", ST.name_of("FIRST_WIN", "ja"))
	ok(L0.field({"zh": "甲", "en": "A", "ja": "あ"}, "") == "あ" and L0.field({"zh": "甲", "en": "A"}, "") == "A", "資料欄位：有日文用日文，沒有退回英文")
	ok(CX.text({"role_zh": "前排", "role_en": "Front", "role_ja": "前衛"}, "role", "ja") == "前衛", "圖鑑文字走語言後綴")
	L0.lang = keep


## V1.4 #18 觸控：長按 0.5 秒＝右鍵（擺陣時拿掉兵）；拖動就取消長按；雙指縮放有上下限。
func test_touch_v140() -> void:
	var GS = load("res://scripts/ui/game_screens.gd")
	var g = GS.new()
	g.sfx = FakeSfx.new()
	g.time = 1.0
	g._start_mode(g.Mode.VS_AI)
	g.armies[0].units = [{"type": 0, "col": 2, "row": 3}]
	var at := Vector2(-1, -1)
	for y in range(0, 800, 4):
		for x in range(0, 1280, 4):
			if g._cell_at(Vector2(x, y)) == Vector2i(2, 3):
				at = Vector2(x, y)
				break
		if at.x >= 0:
			break
	ok(at.x >= 0, "找得到格子的畫面位置")
	var t := InputEventScreenTouch.new()
	t.pressed = true
	t.position = at
	g._touch_input(t)
	var dr := InputEventScreenDrag.new()
	dr.position = at + Vector2(30, 0)
	g._touch_input(dr)
	g._touch_tick(0.7)
	g._process_cmds()
	ok(g.armies[0].units.size() == 1, "拖動了就不是長按")
	t.pressed = false
	g._touch_input(t)
	t.pressed = true
	g._touch_input(t)
	g._touch_tick(0.3)
	g._process_cmds()
	ok(g.armies[0].units.size() == 1, "0.3 秒還不算長按")
	g._touch_tick(0.3)
	g._process_cmds()
	ok(g.armies[0].units.is_empty(), "長按 0.5 秒拿掉兵")
	g._pinch_by(5.0, Vector2(640, 400))
	ok(is_equal_approx(g.pinch_zoom, 2.0), "放大上限 2 倍")
	g._pinch_by(0.01, Vector2(640, 400))
	ok(is_equal_approx(g.pinch_zoom, 1.0), "縮小回全景為止")
	g.free()


## V1.5 遠程時間同步：沒有手動軍令的對局緩衝 8 tick；弓箭手出手比命中早、飛行物在命中 tick 剛好到；近戰不受影響；手動軍令局維持 2 tick。
func test_projectile_timing_v150() -> void:
	var VB = load("res://scripts/ui/view_buffer.gd")
	var BS = load("res://scripts/ui/battle/battle_state.gd")
	var Sim0 = load("res://scripts/core/battle_sim.gd")
	var AI0 = load("res://scripts/core/ai_army.gd")
	var RS0 = load("res://scripts/core/ruleset.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 150
	var s = Sim0.new(AI0.build(0, 100, rng)["army"], AI0.build(1, 100, rng)["army"])
	ok(VB.new(s).delay == VB.DELAY_LONG, "沒有手動軍令：緩衝 8 tick")
	var r = RS0.standard()
	r.cmd_mask = [1, 1]
	var s2 = Sim0.new(AI0.build(0, 100, rng)["army"], AI0.build(1, 100, rng)["army"], r)
	ok(VB.new(s2).delay == VB.DELAY, "有手動軍令：維持 2 tick")
	var fly: int = BS.proj_fly(2)
	var h := 100
	var p0: Array = BS.proj_phase([h], float(h - fly), 2, VB.DELAY_LONG)
	var p1: Array = BS.proj_phase([h], float(h), 2, VB.DELAY_LONG)
	var pm: Array = BS.proj_phase([h], float(h - fly) - 1.0, 2, VB.DELAY_LONG)
	ok(int(p0[0]) == h - fly and int(p0[1]) == h and is_equal_approx(float(p0[2]), 0.0) and is_equal_approx(float(p1[2]), 1.0), "弓箭手：出手 tick 離手、命中 tick 剛好到", str([p0, p1]))
	ok(float(pm[2]) < 0.0 and int(pm[1]) == h, "離手前在前搖、還沒有飛行物")
	ok(fly + VB.DELAY <= VB.DELAY_LONG and BS.proj_fly(6) + VB.DELAY <= VB.DELAY_LONG, "前搖＋飛行放得進緩衝")
	var pmelee: Array = BS.proj_phase([h], float(h - 1), 0, VB.DELAY_LONG)
	ok(int(pmelee[0]) == h and float(pmelee[2]) < 0.0, "近戰不提早出手、沒有飛行物")
	# V1.5.1 B1：手動軍令局（緩衝 2）遠程前搖 1 tick＋飛行 1 tick，命中 tick 不變；近戰照舊前搖 2 tick
	var ps0: Array = BS.proj_phase([h], float(h - 1), 2, VB.DELAY)
	var ps1: Array = BS.proj_phase([h], float(h), 2, VB.DELAY)
	ok(int(ps0[0]) == h - 1 and int(ps0[1]) == h and is_equal_approx(float(ps0[2]), 0.0) and is_equal_approx(float(ps1[2]), 1.0), "手動軍令局：出手 h-1 離手、h 剛好到", str([ps0, ps1]))
	ok(BS.proj_wind(2, VB.DELAY) == 1 and BS.proj_wind(0, VB.DELAY) == VB.DELAY and BS.proj_wind(2, VB.DELAY_LONG) == VB.DELAY, "前搖：只有手動軍令局的遠程縮成 1 tick")
	var pm2: Array = BS.proj_phase([h], float(h - 2), 2, VB.DELAY)
	ok(float(pm2[2]) < 0.0, "手動軍令局：h-2 在前搖、還沒有飛行物")



## V1.5 圖鑑檢視控制：左右轉 16 格循環、手動角度時正面有轉身寬度、慢動作 0.25 倍、出手一次在 0.7 秒內演完。
func test_codex_controls_v150() -> void:
	var g = load("res://scripts/ui/game_screens.gd").new()
	g._open_codex(2)
	ok(g.cx_angle == -1, "預設自動")
	g._cx_turn(-1)
	ok(g.cx_angles() == 16 and g.cx_angle == 15, "弓箭手有背面：往左一格從 0 繞到 15")
	for i in 5:
		g._cx_turn(1)
	ok(g.cx_angle == 4, "再往右五格到正面（4）")
	g._open_codex(12)
	ok(g.cx_angles() == 16, "V1.5.1：22 種都有背面，奇幻兵也轉一整圈")
	g._open_codex(2)
	# 慢動作：時鐘照 0.25 倍走；中途切換不倒退
	g.cx_clock = 0.0; g.cx_last = 0.0; g.time = 0.0
	g.cx_slow = true
	g.time = 1.0; g.cx_clock += clampf(g.time - g.cx_last, 0.0, 0.1) * 0.25; g.cx_last = g.time
	var c1: float = g.cx_clock
	g.cx_slow = false
	g.time = 1.05; g.cx_clock += clampf(g.time - g.cx_last, 0.0, 0.1) * 1.0; g.cx_last = g.time
	ok(c1 <= 0.026 and g.cx_clock > c1, "慢動作時鐘走得慢、切回正常不倒退", str([c1, g.cx_clock]))
	g.free()


## V1.5 暫停選單：正式對局 Esc 開選單並暫停；Esc 再按＝繼續；從選單進設定，設定關掉回選單；重播的 Esc 仍是返回。
func test_pause_menu_v150() -> void:
	var g = load("res://scripts/ui/game_screens.gd").new()
	g.sfx = FakeSfx.new()
	g.mode = g.Mode.VS_AI
	g.difficulty = 1
	g._begin_battle(army_from(0, [[D.SWORD, 5, 4]]), army_from(1, [[D.SWORD, 5, 4]]))
	g.state = g.St.BATTLE
	g._key(KEY_ESCAPE)
	ok(g.overlay == "pause_menu" and g.paused, "Esc 開暫停選單並暫停", g.overlay)
	g._key(KEY_ESCAPE)
	ok(g.overlay == "" and not g.paused, "再按 Esc 繼續")
	g._open_pause_menu()
	g.settings_ret = "pause_menu"; g.overlay = "settings"
	g._key(KEY_ESCAPE)
	ok(g.overlay == "pause_menu" and g.paused, "設定關掉回暫停選單", g.overlay)
	g._settings_close()
	ok(g.overlay == "", "沒有來處的設定關掉就回原畫面")
	g.free()


## V1.5 第二輪：設定子頁 Esc 回設定；暫停選單按離開時戰鬥維持暫停；手動關提示剛出現不會被同一下關掉。
func test_overlay_returns_v150() -> void:
	var g = load("res://scripts/ui/game_screens.gd").new()
	g.sfx = FakeSfx.new()
	g.overlay = "restore"
	g._key(KEY_ESCAPE)
	ok(g.overlay == "settings", "還原子頁 Esc 回設定", g.overlay)
	g.mode = g.Mode.VS_AI
	g.difficulty = 1
	g._begin_battle(army_from(0, [[D.SWORD, 5, 4]]), army_from(1, [[D.SWORD, 5, 4]]))
	g.state = g.St.BATTLE
	g._open_pause_menu()
	g.wins = [1, 0]   # 系列賽打到一半：離開要確認
	g._request_leave()
	ok(g.overlay == "leave" and g.paused, "離開確認框開著時戰鬥維持暫停", str([g.overlay, g.paused]))
	var SV = load("res://scripts/game/save.gd")
	var old = SV.s("toast_mult")
	SV.settings["toast_mult"] = 0
	g._toast("x")
	g._toast_dismiss()
	ok(g.toast_t > 1.0, "手動關提示：剛出現不被同一下關掉")
	g.time += 1.0
	g._toast_dismiss()
	ok(g.toast_t < 1.0, "手動關提示：之後點一下就收起")
	SV.settings["toast_mult"] = old
	g.free()


## V1.5 收尾：還原、清除只能在標題畫面開（對局中換掉進度，舊局會寫進新進度）；圖鑑換兵種回到自動角度。
func test_data_swap_title_only_v150() -> void:
	var g = load("res://scripts/ui/game_screens.gd").new()
	g.sfx = FakeSfx.new()
	g.state = g.St.BATTLE
	g._data_swap_open("restore")
	ok(g.overlay != "restore", "對局中不能開還原")
	g.state = g.St.TITLE
	g._data_swap_open("clear_data")
	ok(g.overlay == "clear_data", "標題畫面可以開清除")
	g._open_codex(2)
	g.cx_angle = 12
	g._cx_pick_unit(12)
	ok(g.cx_angle == -1, "換兵種回到自動角度")
	ok(("progress_x_02.json" > "progress_x.json") and ("progress_x_10.json" > "progress_x_02.json"), "備份流水號字串排序＝時間順序")
	g.free()


## V1.5.1 返回目的地（使用者回報：返回都跳回主畫面）：每張卡片打開的頁，返回回到原卡片；收藏→戰績→宿敵→返回→返回；設定→製作名單→返回；開戰後打完回原卡片。
func test_nav_back_v151() -> void:
	var g = load("res://scripts/ui/game_screens.gd").new()
	g.sfx = FakeSfx.new()
	g.state = g.St.TITLE
	var bad: Array = []
	for kind in g.HUBS:
		var items: Array = g.hub_items(kind)
		for it in items:
			if not bool(it[4]):
				continue
			g.overlay = kind
			g.nav_stack.clear()
			g._nav_push(kind)
			g.nav_hub = kind
			it[3].call()
			var opened: String = g.overlay
			if g.state != g.St.TITLE or opened == "" or opened == "paint":
				g.state = g.St.TITLE
				continue   # 直接開戰（每日）或塗裝室（自己的返回）另外測
			g._nav_back()
			if g.overlay != kind:
				bad.append("%s→%s 返回到 %s" % [kind, opened, g.overlay])
	ok(bad.is_empty(), "卡片打開的頁返回回到原卡片", str(bad))
	g.overlay = "hub_collect"; g.nav_stack.clear()
	g._nav_push("hub_collect"); g._open("profile")
	g._nav_push("profile"); g.overlay = "nemeses"
	g._nav_back("profile")
	ok(g.overlay == "profile", "宿敵返回戰績", g.overlay)
	g._nav_back()
	ok(g.overlay == "hub_collect", "戰績返回收藏", g.overlay)
	g.overlay = "settings"; g.nav_stack.clear()
	g._nav_push("settings"); g._open("credits")
	g._key(KEY_ESCAPE)
	ok(g.overlay == "settings", "製作名單 Esc 回設定", g.overlay)
	g.nav_hub = "hub_challenge"
	g._go_title()
	ok(g.overlay == "hub_challenge", "打完回到原卡片面板", g.overlay)
	g._key(KEY_ESCAPE)
	ok(g.overlay == "" and g.nav_hub == "", "關掉面板後不再自動打開")
	# Codex v151-i1 #1：卡片面板→大廳→開戰進擺陣→F1 圖鑑→返回＝回擺陣（不是彈出卡片面板）
	g.nav_stack = ["hub_play"]
	g._start_mode(g.Mode.VS_AI)
	g._open_codex(0)
	g._nav_back()
	ok(g.overlay == "" and g.state == g.St.PLACE, "擺陣開的圖鑑返回回擺陣", g.overlay)
	g.overlay = "wave_codes"
	g.state = g.St.TITLE
	g._key(KEY_ESCAPE)
	ok(g.overlay == "codes", "選波頁 Esc 回代碼頁", g.overlay)
	g.free()


## V1.5.1 B1b：照紀錄施放的軍令局用長緩衝；手動軍令局維持短緩衝；快照帶軍令欄狀態。
func test_cmd_delay_v151() -> void:
	var VB = load("res://scripts/ui/view_buffer.gd")
	var Sim0 = load("res://scripts/core/battle_sim.gd")
	var AI0 = load("res://scripts/core/ai_army.gd")
	var RS0 = load("res://scripts/core/ruleset.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 151
	var r = RS0.standard()
	r.cmd_mask = [1, 1]
	var s = Sim0.new(AI0.build(0, 100, rng)["army"], AI0.build(1, 100, rng)["army"], r)
	ok(VB.new(s).delay == VB.DELAY, "手動軍令局：短緩衝")
	var s2 = Sim0.new(AI0.build(0, 100, rng)["army"], AI0.build(1, 100, rng)["army"], r)
	s2.cmd_play([])
	var v2 = VB.new(s2)
	ok(v2.delay == VB.DELAY_LONG, "照紀錄施放：長緩衝")
	ok(v2.cmd_snap.size() == 2, "快照帶軍令剩餘次數與冷卻")
	var BS = load("res://scripts/ui/battle/battle_state.gd")
	var pb: Array = BS.proj_phase([100], 98.0, 6, VB.DELAY, {})
	ok(int(pb[1]) == 100 and int(pb[3]) == 98 and int(pb[4]) == VB.DELAY and float(pb[2]) < 0.0, "手動軍令局投彈兵貼身敲擊：前搖照舊從命中前 2 tick 開始、沒有炸彈", str(pb))
	var pa: Array = BS.proj_phase([100], 98.0, 2, VB.DELAY)
	ok(int(pa[3]) == 98 and int(pa[4]) == 1 and int(pa[0]) == 99, "手動軍令局弓箭手：前搖 1 tick、99 離手", str(pa))


## V1.5.1 圖鑑召喚物頁：選小史萊姆、骷髏不會越界（沒有技能小劇場），近看模式自動打開。
func test_codex_summons_v151() -> void:
	var g = load("res://scripts/ui/game_screens.gd").new()
	g._open_codex(0)
	g._cx_pick_unit(20)
	for i in 10:
		g._codex_tick(0.05)
	ok(g.cx_unit == 20 and g.cx_zoom, "召喚物頁直接是近看模式")
	g._cx_pick_unit(0)
	g.cx_zoom = false
	ok(g.cx_unit == 0 and not g.cx_zoom, "回王國軍收合近看")
	ok(g.cxz_phase(0.1)[0] == 0 and g.cxz_phase(0.3)[0] == 1 and g.cxz_phase(0.6)[0] == 2 and g.cxz_phase(1.0)[0] == 3, "近看的階段：前搖、揮擊、後搖、停")
	g.free()


## V1.5.1：代碼一鍵辨識看前綴；速度共用表往上往下一格。
func test_code_kind_speed_v151() -> void:
	var GM = load("res://scripts/ui/screens/game_menus.gd")
	var UB = load("res://scripts/ui/ui_base.gd")
	ok(GM.code_kind("NTB7.x.y") == "battle" and GM.code_kind(" NTBR5.a.b ") == "rules" and GM.code_kind("NTC1.a.b") == "challenge", "對戰、規則、挑戰")
	ok(GM.code_kind("NTP2.a.b") == "workshop" and GM.code_kind("NTS1.abc") == "settings" and GM.code_kind("NTB6.a.b") == "army" and GM.code_kind("hello") == "", "殘局、設定、陣型、認不得")
	ok(UB.speed_step(1.0, 1) == 2.0 and UB.speed_step(8.0, 1) == 8.0 and UB.speed_step(0.25, -1) == 0.25 and UB.speed_step(3.0, -1) == 1.0, "速度表一格一格走")


## V1.5.1 C3／E3：「只點選」擺兵：按下擺一隻，拖過旁邊的格子不會多擺；「點選＋拖曳」會連續擺。
func test_place_mode_v151() -> void:
	var GS = load("res://scripts/ui/game_screens.gd")
	var SV = load("res://scripts/game/save.gd")
	var keep = SV.s("place_mode")
	var counts: Array = []
	for pm in ["tap", "both"]:
		SV.settings["place_mode"] = pm
		var g = GS.new()
		g.sfx = FakeSfx.new()
		g.time = 1.0
		g._start_mode(g.Mode.VS_AI)
		if g._is_free():
			g.free()
			continue
		g.armies[0].units = []
		g.selected = 0
		var cells: Array = []
		for y in range(0, 800, 4):
			for x in range(0, 1280, 4):
				var c: Vector2i = g._cell_at(Vector2(x, y))
				if c.y == 4 and (c.x == 1 or c.x == 2 or c.x == 3) and cells.size() < 3 and not cells.any(func(q): return g._cell_at(q) == c):
					cells.append(Vector2(x, y))
		g._mb_cmd({"i": MOUSE_BUTTON_LEFT, "pressed": true, "pos": cells[0]})
		g._paint_cmd(cells[1])
		g._paint_cmd(cells[2])
		g._mb_cmd({"i": MOUSE_BUTTON_LEFT, "pressed": false, "pos": cells[2]})
		counts.append(g.armies[0].units.size())
		if pm == "tap":
			# 點一下自己的兵＝拿掉
			g._mb_cmd({"i": MOUSE_BUTTON_LEFT, "pressed": true, "pos": cells[0]})
			g._mb_cmd({"i": MOUSE_BUTTON_LEFT, "pressed": false, "pos": cells[0]})
			ok(g.armies[0].units.size() == counts[0] - 1, "只點選：點一下自己的兵就拿掉", str(g.armies[0].units.size()))
		g.free()
	SV.settings["place_mode"] = keep
	if counts.size() == 2:
		ok(counts[0] == 1 and counts[1] > 1, "只點選擺一隻、點選＋拖曳連續擺", str(counts))
	else:
		ok(true, "這個預設是自由排兵（只測格子模式）")


## V1.5.1 C4（自由排兵）：「只點選」點一下自己的兵＝拿掉；拖出去又拖回來不拿掉。
func test_free_tap_remove_v151() -> void:
	var GS = load("res://scripts/ui/game_screens.gd")
	var SV = load("res://scripts/game/save.gd")
	var RS0 = load("res://scripts/core/ruleset.gd")
	var keep = SV.s("place_mode")
	SV.settings["place_mode"] = "tap"
	var g = GS.new()
	g.sfx = FakeSfx.new()
	g.time = 1.0
	g._start_mode(g.Mode.VS_AI)
	if g.rules == null:
		g.rules = RS0.standard()
	g.rules.deploy = "free"
	g.state = g.St.PLACE
	if not g._is_free():
		ok(true, "這個環境進不了自由排兵（略過）")
		SV.settings["place_mode"] = keep
		g.free()
		return
	var a = g._fp_army()
	a.units = []
	a.deploy = "free"
	var w := Vector2i(-1, -1)
	for xx in range(500, 9000, 250):
		if a.check_place_xy(0, xx, 4000) == "":
			w = Vector2i(xx, 4000)
			break
	a.place_xy(0, w.x, w.y)
	var p: Vector2 = g._fld_xf() * g._s_of(a.pos_of(a.units[0])) + Vector2(0, -20) if not a.units.is_empty() else Vector2.ZERO
	var hit0: int = a.index_near(g._w_of(p).x, g._w_of(p).y, g.PICK_R)
	g._fp_mb({"i": MOUSE_BUTTON_LEFT, "pressed": true, "pos": p})
	var drag0: int = g.fp_drag
	g._fp_mb({"i": MOUSE_BUTTON_LEFT, "pressed": false, "pos": p + Vector2(30, 0)})
	var n1: int = a.units.size()
	var info := "hit=%d drag=%d n1=%d infield=%s" % [hit0, drag0, n1, str(g._fp_in_field(p + Vector2(30, 0)))]
	if n1 == 1:
		# 拖遠再拖回按下的位置放開：不算點一下，兵還在
		var p1: Vector2 = g._fld_xf() * g._s_of(a.pos_of(a.units[0])) + Vector2(0, -20)
		g._fp_mb({"i": MOUSE_BUTTON_LEFT, "pressed": true, "pos": p1})
		g._paint_cmd(p1 + Vector2(80, 0))
		g._paint_cmd(p1)
		g._fp_mb({"i": MOUSE_BUTTON_LEFT, "pressed": false, "pos": p1})
		info += " 往返後=%d" % a.units.size()
		n1 = a.units.size()
	if n1 == 1:
		var p2: Vector2 = g._fld_xf() * g._s_of(a.pos_of(a.units[0])) + Vector2(0, -20)
		g._fp_mb({"i": MOUSE_BUTTON_LEFT, "pressed": true, "pos": p2})
		g._fp_mb({"i": MOUSE_BUTTON_LEFT, "pressed": false, "pos": p2})
	ok(n1 == 1 and a.units.size() == 0, "拖曳搬移不拿掉、點一下拿掉", info + " n2=%d" % a.units.size())
	SV.settings["place_mode"] = keep
	g.free()


## V1.5.1 A7：圖鑑小劇場的弓箭手：命中前有一段飛行（飛行進度 0～1 之間的畫面 tick 存在），受擊在命中那格之後才出。
func test_codex_demo_projectile_v151() -> void:
	var g = load("res://scripts/ui/game_screens.gd").new()
	g._open_codex(2)
	var saw_fly := false
	var info := ""
	for i in 200:
		g._codex_tick(0.05)
		if g.cx_view == null:
			continue
		for uid in g.cx_ptgt:
			if g.cx_hits.has(uid):
				var ph: Array = g.proj_phase(g.cx_hits[uid], g.cx_view.tick + 0.5, 2, g.cx_view.delay, g.cx_ptgt[uid])
				if float(ph[2]) > 0.0 and float(ph[2]) < 1.0:
					saw_fly = true
		if saw_fly:
			break
	info = "ptgt=%d hits=%d" % [g.cx_ptgt.size(), g.cx_hits.size()]
	ok(saw_fly, "小劇場弓箭手的箭有飛行段", info)
	g.free()


## V1.5.2 排版幾何規則反例（純矩形）：每條規則各有一個違規案例、一個合法邊界與一個合法例外，
## 避免「全部報錯也算成功」或「全部放過也算成功」。實際繪圖有沒有送資料，由版面檢查的漏登記守衛（G）擋。
func test_layout_rules_v152() -> void:
	var LR = load("res://scripts/ui/layout_rules.gd")
	var codes := func(res: Dictionary, lvl: String) -> Array:
		var a: Array = []
		for v in res[lvl]:
			a.append(str(v["type"]))
		return a
	var P := func(x: float, y := 100.0, w := 600.0, h := 500.0) -> Dictionary:
		return {"id": "P0", "r": Rect2(x, y, w, h), "skip": {}}
	# R1：偏心 2px 失敗、置中通過、宣告例外不報但列出
	ok("R1" in codes.call(LR.check({"panels": [P.call(342.0)]}), "fail"), "R1 面板偏 2px 被抓")
	ok(codes.call(LR.check({"panels": [P.call(340.0)]}), "fail").is_empty(), "R1 置中面板通過")
	ok(codes.call(LR.check({"panels": [P.call(341.0)]}), "fail").is_empty(), "R1 偏 1px 在容差內")
	var px: Dictionary = P.call(430.0)
	px["skip"]["R1"] = "側欄"
	var rx: Dictionary = LR.check({"panels": [px]})
	ok(not "R1" in codes.call(rx, "fail") and rx["exempt"].size() == 1 and rx["exempt"][0]["why"] == "側欄", "R1 宣告例外：不報、列出理由")
	# R1 實例：V1.5.1 卡片面板 Rect2(430,…,800) 偏 190px
	ok("R1" in codes.call(LR.check({"panels": [{"id": "hub", "r": Rect2(430, 60, 800, 600), "skip": {}}]}), "fail"), "R1 抓得到使用者回報的卡片面板偏心")
	# R2：緞帶下距 11 失敗、14 警告、16 通過；緞帶不置中失敗
	var rib := {"id": "H0", "r": Rect2(500, 112, 280, 46), "cx": 640.0, "bottom": 158.0, "host": "P0"}
	for c in [[11.0, "fail"], [14.0, "warn"], [16.0, ""]]:
		var t := {"r": Rect2(560, 158.0 + c[0], 160, 20), "s": "說明"}
		var res: Dictionary = LR.check({"panels": [P.call(340.0)], "ribbons": [rib], "texts": [t]})
		var fails: Array = codes.call(res, "fail")
		var warns: Array = codes.call(res, "warn")
		if c[1] == "fail":
			ok("R2" in fails, "R2 緞帶下距 11px 失敗")
		elif c[1] == "warn":
			ok(not "R2" in fails and "R2" in warns, "R2 緞帶下距 14px 只警告")
		else:
			ok(not "R2" in fails and not "R2" in warns, "R2 緞帶下距 16px 通過")
	var rib2 := rib.duplicate()
	rib2["cx"] = 650.0
	ok("R2" in codes.call(LR.check({"panels": [P.call(340.0)], "ribbons": [rib2]}), "fail"), "R2 緞帶偏離面板中線被抓")
	ok(not "R2" in codes.call(LR.check({"panels": [P.call(340.0)], "ribbons": [rib], "texts": [{"r": Rect2(560, 120, 160, 30), "s": "標題"}]}), "fail"), "R2 緞帶自己的標題字不算內容")
	# R3：書籤接縫 2px 失敗、貼齊通過、水平超出失敗
	var tab := Rect2(80, 96, 154, 68)
	ok("R3" in codes.call(LR.check({"decos": [{"id": "b", "kind": "bookmark", "r": Rect2(200, 98, 20, 30), "host_r": tab, "edge": "top"}]}), "fail"), "R3 書籤離上緣 2px 被抓")
	ok(codes.call(LR.check({"decos": [{"id": "b", "kind": "bookmark", "r": Rect2(200, 96, 20, 30), "host_r": tab, "edge": "top"}]}), "fail").is_empty(), "R3 A 案幾何通過")
	ok("R3" in codes.call(LR.check({"decos": [{"id": "b", "kind": "bookmark", "r": Rect2(200, 160, 20, 30), "host_r": tab, "edge": "top"}]}), "fail"), "R3 抓得到使用者回報的書籤懸空（y=160）")
	ok("R3" in codes.call(LR.check({"decos": [{"id": "b", "kind": "bookmark", "r": Rect2(225, 96, 20, 30), "host_r": tab, "edge": "top"}]}), "fail"), "R3 書籤超出分頁右緣被抓")
	# R4：群組偏心、間距差 3、雙按鈕不同寬
	var row := func(xs: Array, ws: Array) -> Array:
		var a: Array = []
		for i in xs.size():
			a.append(Rect2(xs[i], 540, ws[i], 48))
		return a
	ok(codes.call(LR.check({"panels": [P.call(340.0)], "btns": row.call([480.0, 650.0], [150.0, 150.0])}), "fail").is_empty(), "R4 雙按鈕置中同寬通過")
	ok("R4" in codes.call(LR.check({"panels": [P.call(340.0)], "btns": row.call([483.0, 653.0], [150.0, 150.0])}), "fail"), "R4 群組偏 3px 被抓")
	ok("R4" in codes.call(LR.check({"panels": [P.call(340.0)], "btns": row.call([480.0, 650.0], [150.0, 160.0])}), "fail"), "R4 雙按鈕不同寬被抓")
	ok("R4" in codes.call(LR.check({"panels": [P.call(340.0)], "btns": row.call([400.0, 560.0, 723.0], [150.0, 150.0, 150.0])}), "fail"), "R4 三按鈕間距差 3 被抓")
	ok(not "R4" in codes.call(LR.check({"panels": [P.call(340.0)], "btns": row.call([404.0, 564.0, 726.0], [150.0, 150.0, 150.0])}), "fail"), "R4 三按鈕間距差 2 在容差內")
	var pa: Dictionary = P.call(340.0)
	pa["axis"] = 620.0
	ok(codes.call(LR.check({"panels": [pa], "btns": row.call([460.0, 630.0], [150.0, 150.0])}), "fail").is_empty(), "R4 宣告欄中線時照欄中線算")
	# R8：面板距畫面邊 <16、按鈕超出面板
	ok("R8" in codes.call(LR.check({"panels": [{"id": "P0", "r": Rect2(10, 100, 1260, 500), "skip": {}}]}), "fail"), "R8 面板貼邊被抓")
	ok("R8" in codes.call(LR.check({"panels": [P.call(340.0)], "btns": [Rect2(880, 300, 100, 48)]}), "fail"), "R8 按鈕凸出面板被抓")
	# R9：換行壓鈕 9px 失敗、12px 通過、文字在按鈕旁不算
	ok("R9" in codes.call(LR.check({"panels": [P.call(340.0)], "texts": [{"r": Rect2(500, 300, 280, 20), "s": "說明"}], "btns": [Rect2(540, 329, 200, 48)]}), "fail"), "R9 說明壓鈕被抓")
	ok(not "R9" in codes.call(LR.check({"panels": [P.call(340.0)], "texts": [{"r": Rect2(500, 300, 280, 20), "s": "說明"}], "btns": [Rect2(540, 332, 200, 48)]}), "fail"), "R9 間距 12 通過")
	ok(not "R9" in codes.call(LR.check({"panels": [P.call(340.0)], "texts": [{"r": Rect2(360, 330, 100, 20), "s": "標籤"}], "btns": [Rect2(540, 320, 200, 48)]}), "fail"), "R9 按鈕左邊的標籤不算")
	# R10：同欄中線差 20 失敗、0 通過
	ok("R10" in codes.call(LR.check({"aligns": [{"id": "home", "rects": [Rect2(70, 60, 330, 80), Rect2(90, 200, 330, 60)]}]}), "fail"), "R10 主畫面左欄中線差 20 被抓")
	ok(codes.call(LR.check({"aligns": [{"id": "home", "rects": [Rect2(80, 60, 330, 80), Rect2(80, 200, 330, 60)]}]}), "fail").is_empty(), "R10 共用中線通過")
	# R6：留白過多只警告
	var res6: Dictionary = LR.check({"panels": [P.call(340.0, 100.0, 600.0, 600.0)], "texts": [{"r": Rect2(560, 130, 160, 20), "s": "空"}], "btns": [Rect2(560, 200, 160, 48)]})
	ok("R6" in codes.call(res6, "warn") and not "R6" in codes.call(res6, "fail"), "R6 內容只佔兩成：警告不失敗")
	var res6b: Dictionary = LR.check({"panels": [P.call(340.0, 100.0, 600.0, 300.0)], "texts": [{"r": Rect2(560, 120, 160, 20), "s": "a"}], "btns": [Rect2(560, 240, 160, 48), Rect2(560, 336, 160, 48)]})
	ok(not "R6" in codes.call(res6b, "warn"), "R6 內容填滿面板不報")
	# R7：緞帶下短字沒置中只警告
	ok("R7" in codes.call(LR.check({"panels": [P.call(340.0)], "ribbons": [rib], "texts": [{"r": Rect2(565, 180, 160, 20), "s": "短"}]}), "warn"), "R7 緞帶下短字偏 5px 警告")
	ok(not "R7" in codes.call(LR.check({"panels": [P.call(340.0)], "ribbons": [rib], "texts": [{"r": Rect2(560, 180, 160, 20), "s": "短"}]}), "warn"), "R7 緞帶下短字置中不報")
	ok(not "R7" in codes.call(LR.check({"panels": [P.call(340.0)], "ribbons": [rib], "texts": [{"r": Rect2(352, 180, 160, 20), "s": "欄位"}]}), "warn"), "R7 靠左的欄位標籤不算副標")
	# G 守衛：重複 ID、漏登記（零書籤）、覆蓋層沒面板、宣告的例外覆蓋層
	ok("G" in codes.call(LR.check({"panels": [P.call(340.0), P.call(340.0)]}), "fail"), "G 重複 ID 被抓")
	ok("G" in codes.call(LR.check({"need": {"bookmark": 1}}), "fail"), "G 大廳少了書籤（零登記）被抓")
	ok(not "G" in codes.call(LR.check({"need": {"bookmark": 1}, "decos": [{"id": "b", "kind": "bookmark", "r": Rect2(200, 96, 20, 30), "host_r": tab, "edge": "top"}]}), "fail"), "G 有書籤就通過")
	ok("G" in codes.call(LR.check({"overlay": "settings"}), "fail"), "G 覆蓋層沒登記面板被抓")
	ok(not "G" in codes.call(LR.check({"overlay": "pause", "panelless_ok": true}), "fail"), "G 宣告過的無面板覆蓋層不報")
	# R8 多欄：設定頁撤回鈕（880～990）跨進說明欄（910 起）被抓；移進中欄就通過
	var cols := [Rect2(340, 150, 560, 560), Rect2(910, 166, 236, 470)]
	ok("R8" in codes.call(LR.check({"aligns": [{"id": "settings", "cols": cols}], "btns": [Rect2(880, 166, 110, 46)]}), "fail"), "R8 撤回鈕跨進說明欄被抓")
	ok(not "R8" in codes.call(LR.check({"aligns": [{"id": "settings", "cols": cols}], "btns": [Rect2(790, 166, 110, 46)]}), "fail"), "R8 撤回鈕在中欄內通過")
	# R4 格狀排列：最後一排靠左不算群組偏心（禁用牌 20 格）；單獨一排偏心照抓
	var grid: Array = []
	for i in 20:
		grid.append(Rect2(76 + (i % 7) * 162, 192 + (i / 7) * 136, 156, 130))
	ok(not "R4" in codes.call(LR.check({"panels": [{"id": "P0", "r": Rect2(60, 66, 1160, 700), "skip": {}}], "btns": grid}), "fail"), "R4 格狀最後一排靠左不報")
	ok(not "R7" in codes.call(LR.check({"panels": [P.call(340.0)], "ribbons": [rib], "texts": [{"r": Rect2(565, 180, 160, 20), "s": "分頁字"}], "btns": [Rect2(540, 172, 200, 60)]}), "warn"), "R7 按鈕裡的字不算副標")
	# Codex 實作第 1 輪：格線豁免不能太寬——上面只有一顆同尺寸的按鈕時，底部雙按鈕偏心照抓
	var pr4: Dictionary = {"id": "P0", "r": Rect2(340, 100, 600, 500), "skip": {}}
	ok("R4" in codes.call(LR.check({"panels": [pr4], "btns": [Rect2(483, 400, 150, 48), Rect2(483, 540, 150, 48), Rect2(653, 540, 150, 48)]}), "fail"), "R4 上面只有一顆同尺寸鈕：不是格線，偏心照抓")
	# G：緞帶宿主無效
	ok("G" in codes.call(LR.check({"panels": [P.call(340.0)], "ribbons": [{"id": "H0", "r": Rect2(500, 112, 280, 46), "cx": 640.0, "bottom": 158.0, "host": ""}]}), "fail"), "G 緞帶沒有宿主被抓")
	ok("G" in codes.call(LR.check({"panels": [P.call(340.0)], "need": {"ribbon": 1}}), "fail"), "G 該有緞帶的畫面少了緞帶被抓")
	# R8：文字超出面板、焦點框超出畫面
	ok("R8" in codes.call(LR.check({"panels": [P.call(340.0)], "texts": [{"r": Rect2(880, 300, 100, 20), "s": "溢出"}]}), "fail"), "R8 文字超出面板被抓")
	ok("R8" in codes.call(LR.check({"btns": [Rect2(4, 300, 100, 44)], "focus_out": 8.0}), "fail"), "R8 加強焦點框超出畫面被抓")
	ok(not "R8" in codes.call(LR.check({"btns": [Rect2(8, 300, 100, 44)], "focus_out": 8.0}), "fail"), "R8 焦點框剛好在畫面內通過")
	# 分頁名稱兩行：中日文從中間斷，不留單字一行；英文換在最靠近中間的空白
	var UB = load("res://scripts/ui/ui_base.gd")
	ok(UB.balance_two_lines("単一兵種対決") == "単一兵\n種対決", "中日文兩行從中間斷", UB.balance_two_lines("単一兵種対決"))
	ok(UB.balance_two_lines("Monster Crew") == "Monster\nCrew", "英文換在最靠近中間的空白", UB.balance_two_lines("Monster Crew"))


## V1.5.2：版面檢查真的把 overlay、必要角色、九宮格交給排版規則（曾被行中間的 # 註解吃掉、守衛靜靜失效）。
## 空畫面（什麼都沒登記）開著「設定」覆蓋層，一定要被漏登記守衛擋下；宣告過的無面板覆蓋層不擋。
func test_layout_guard_wired_v152() -> void:
	var LR = load("res://scripts/ui/layout_rules.gd")
	var g = load("res://tools/dev_main.gd").new()
	g.sfx = FakeSfx.new()
	g.overlay = "settings"
	var d: Dictionary = g.layout_geom_input()
	ok(d.has("boxes") and d.has("overlay") and d.has("need") and d.has("panelless_ok"), "排版規則拿到 boxes／overlay／need", str(d.keys()))
	ok(int(d["need"].get("ribbon", 0)) == 1 and int(d["need"].get("panel", 0)) == 1, "設定頁必要角色：緞帶 1、面板 1", str(d["need"]))
	var fails: Array = LR.check(d)["fail"].map(func(v): return str(v["type"]))
	ok("G" in fails, "空的設定覆蓋層被漏登記守衛擋下", str(fails))
	g.overlay = "ai_busy"
	ok(not "G" in LR.check(g.layout_geom_input())["fail"].map(func(v): return str(v["type"])), "AI 思考中（宣告過的無面板覆蓋層）不擋")
	g.free()

## 1.3.0 R11（使用者第 10 點）：格子裡的字墨跡中心對格子面中心，每軸 ≤1px；字不能越出格子面；同一格子的多行合併量
func test_layout_r11_v130() -> void:
	var LR = load("res://scripts/ui/layout_rules.gd")
	var face := Rect2(100, 100, 120, 40)
	var T := func(ink: Rect2, s := "開始", f = face) -> Dictionary:
		return {"r": ink, "gr": ink, "s": s, "btn": true, "face": f, "ink": ink}
	var r11 := func(res: Dictionary) -> int:
		return res["fail"].filter(func(v): return str(v["type"]) == "R11").size()
	ok(r11.call(LR.check({"texts": [T.call(Rect2(140, 110, 40, 20))]})) == 0, "R11 墨跡置中通過")
	ok(r11.call(LR.check({"texts": [T.call(Rect2(141, 110, 40, 20))]})) == 0, "R11 偏 1px 在容差內")
	ok(r11.call(LR.check({"texts": [T.call(Rect2(142, 110, 40, 20))]})) == 1, "R11 水平偏 2px 被抓")
	ok(r11.call(LR.check({"texts": [T.call(Rect2(140, 108, 40, 20))]})) == 1, "R11 垂直偏 2px 被抓")
	ok(r11.call(LR.check({"texts": [T.call(Rect2(140, 98, 40, 44))]})) == 1, "R11 字越出格子面被抓")
	# 兩行合併成一個墨跡框量（各自不置中、合起來置中＝通過）
	ok(r11.call(LR.check({"texts": [T.call(Rect2(140, 102, 40, 16), "第一行"), T.call(Rect2(140, 122, 40, 16), "第二行")]})) == 0, "R11 多行合併後置中通過")
	# 沒有宣告格子面的字（一般說明文字）不量
	ok(r11.call(LR.check({"texts": [{"r": Rect2(0, 0, 10, 10), "gr": Rect2(0, 0, 10, 10), "s": "說明", "btn": false, "face": null, "ink": Rect2(0, 0, 10, 10)}]})) == 0, "R11 非格子的字不量")
	# 墨跡框：同一個字在不同字級的墨跡框高度隨字級長大、寬度 > 0（TextServer 字形框，不是名目框）
	var UB = load("res://scripts/ui/ui_base.gd")
	var fnt: Font = ThemeDB.fallback_font
	var a: Rect2 = UB.ink_line(fnt, "?", 16)
	var b: Rect2 = UB.ink_line(fnt, "?", 32)
	ok(a.size.x > 0.0 and b.size.y > a.size.y * 1.6, "墨跡框隨字級長大 %s／%s" % [str(a), str(b)])
	ok(a.position.y < 0.0 and a.end.y <= 1.0, "「?」的墨跡在基線以上 %s" % str(a))

## 1.3.0 §4 色票單一來源：同名常數都指到 palette.gd（值不變）；scripts/ui 的內嵌 Color("#…") 只能減少不能變多（棘輪）
const PALETTE_INLINE_MAX := 486
func test_palette_v130() -> void:
	var PAL = load("res://scripts/ui/palette.gd")
	var UB = load("res://scripts/ui/ui_base.gd")
	var K = load("res://scripts/ui/units/kit.gd")
	ok(UB.ACCENT == Color("#ffd166") and UB.TH_WOOD == Color("#3a2a1f") and UB.INK == Color("#24150B") and UB.DIM_INK == Color("#1c130d"), "介面色值和 1.2.0 相同")
	ok(K.TEAM == PAL.TEAM and K.TEAM[0][0] == Color("#45acff") and K.TEAM[1][1] == Color("#ffb000"), "隊色指到色票、值不變")
	var re := RegEx.new()
	re.compile("\"#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?\"")   # 色碼字串（含 Color("#…") 與表格裡的 "#…"；Codex cat01 #6）
	var n := 0
	var stack: Array = ["res://scripts/ui"]
	while not stack.is_empty():
		var dir: String = stack.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			stack.append(dir.path_join(sub))
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd") and f != "palette.gd":
				n += re.search_all(FileAccess.get_file_as_string(dir.path_join(f))).size()
	ok(n <= PALETTE_INLINE_MAX, "內嵌色碼 %d ≤ %d（新顏色請加到 palette.gd）" % [n, PALETTE_INLINE_MAX])

## 1.3.0 §15：音量木軌拖曳的換算（軌左端 0、右端 100、照 5% 一格、超出夾住）
func test_vol_drag_v130() -> void:
	var G = load("res://scripts/ui/screens/game_menus.gd")
	var rail := Rect2(100, 0, 200, 20)
	ok(G.vol_from_x(100.0, rail) == 0 and G.vol_from_x(300.0, rail) == 100, "兩端 0／100")
	ok(G.vol_from_x(200.0, rail) == 50 and G.vol_from_x(204.0, rail) == 50 and G.vol_from_x(206.0, rail) == 55, "照 5% 一格取最近")
	ok(G.vol_from_x(-50.0, rail) == 0 and G.vol_from_x(999.0, rail) == 100, "超出軌道夾住")
	# 按下在軌上開始拖、移動只改記憶體、放開才存檔且吃掉放開（不再觸發數值鈕 +5%）（Codex cat01 #1 #2）
	var SV = load("res://scripts/game/save.gd")
	var keep: Dictionary = SV.settings.duplicate(true)
	var old_prefix: String = SV.prefix
	SV.prefix = "t130vol_"   # 放開會寫設定檔：寫到測試前綴，不碰玩家的設定
	var g = load("res://scripts/ui/game_screens.gd").new()
	g.sfx = FakeSfx.new()
	g.overlay = "settings"
	g.vol_rails = {"music": rail}
	ok(not g.vol_press(Vector2(50, 10)), "軌道外按下不開始拖")
	ok(g.vol_press(Vector2(200, 10)) and g.vol_drag == "music" and int(SV.s("music")) == 50, "軌上按下：開始拖、設到 50")
	g.vol_motion(Vector2(260, 10))
	ok(int(SV.s("music")) == 80, "拖曳中即時改值")
	ok(g.vol_release() and g.vol_drag == "" and not g.vol_release(), "放開結束拖曳（第二次放開不算）")
	g.overlay = "settings"
	g.vol_rails = {"music": rail}
	g.vol_press(Vector2(150, 10))
	g._settings_close()
	ok(g.vol_drag == "", "拖曳中關掉設定也結束")
	g.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://t130vol_settings.json"))
	SV.prefix = old_prefix
	SV.settings = keep

## 1.3.0 第 8 大類：每個畫面一件器物（每個器物都有畫法、開合動畫有對應、竹簾取代屏風、三折宣紙）
func test_vessels_v130() -> void:
	var UB = load("res://scripts/ui/ui_base.gd")
	var src: String = FileAccess.get_file_as_string("res://scripts/ui/ui_base.gd")
	var deco: String = src.substr(src.find("func _obj_deco"), src.find("func _panel(") - src.find("func _obj_deco"))
	var anim_kinds := ["box", "case", "trunk", "tin", "clock", "ebony", "fold", "tube", "letter"]
	var all_ok := true
	var anim_ok := true
	for ov in UB.OBJ_OF:
		var k: String = UB.OBJ_OF[ov]
		if deco.find("\"%s\"" % k) < 0:
			all_ok = false
		if k != "card" and not (str(UB.OBJ_ANIM.get(k, k)) in anim_kinds):   # 立卡（確認框）1.2.0 起就不演開合
			anim_ok = false
	ok(all_ok, "每個器物都有畫法")
	ok(anim_ok, "每個器物都有開合動畫（借用既有的）")
	ok(UB.OBJ_OF["lobby"] == "notebook" and UB.OBJ_OF["puzzles"] == "book" and UB.OBJ_OF["codex"] == "specimen" and UB.OBJ_OF["settings"] == "toolbox"
		and UB.OBJ_OF["profile"] == "shelf" and UB.OBJ_OF["codes"] == "post" and UB.OBJ_OF["review"] == "annot", "方案 §8 的畫面對應")
	var gp: String = FileAccess.get_file_as_string("res://scripts/ui/screens/game_place.gd")
	ok(gp.find("_bamboo_blind(mr)") >= 0 and gp.find("屏風的扇面") < 0, "敵陣遮罩改竹簾")
	var gr: String = FileAccess.get_file_as_string("res://scripts/ui/screens/game_result.gd")
	ok(gr.find("三折宣紙") >= 0, "結果紙卡有三折摺痕")
	# Codex cat08 #1～#3：器物裝飾不出畫面（用實際面板：戰績 Rect2(50,24,1180,752)、大廳 Rect2(50,30,1180,740)）
	var scr := Rect2(0, 0, 1280, 800)
	ok(scr.encloses(UB.obj_extent(Rect2(50, 24, 1180, 752), "shelf")), "獎盃架收在畫面內")
	ok(scr.encloses(UB.obj_extent(Rect2(50, 30, 1180, 740), "notebook")), "手帳絲帶不出畫面")
	ok(UB.obj_extent(Rect2(50, 30, 1180, 740), "notebook").end.y <= 776.0, "手帳裝飾不碰下緣手把提示列")
	var LR = load("res://scripts/ui/layout_rules.gd")
	var rs: String = FileAccess.get_file_as_string("res://scripts/ui/layout_rules.gd")
	ok(rs.find("器物裝飾出畫面") >= 0, "版面檢查會擋器物出畫面")

## 1.3.0 第 9 大類：資訊層級（戰鬥 HUD 左上只在開場、暫停、懸停時出現；擺陣左上收進便籤）
func test_info_layers_v130() -> void:
	var g = load("res://scripts/ui/game_screens.gd").new()
	g.state = g.St.BATTLE
	g.view = load("res://scripts/ui/view_buffer.gd").new()
	g.view.tick = 10
	g.pad_mode = false
	g.mouse = Vector2(640, 400)
	var SV = load("res://scripts/game/save.gd")
	var plain := bool(SV.s("plain_ui"))
	ok(g.hud_meta_visible(), "開場 3 秒顯示模式與比分")
	g.view.tick = 200
	ok(g.hud_meta_visible() == plain, "戰鬥中收起（簡化介面一律顯示）")
	g.mouse = Vector2(100, 40)
	ok(g.hud_meta_visible(), "滑鼠移到左上就出現")
	g.mouse = Vector2(640, 400)
	g.paused = true
	ok(g.hud_meta_visible(), "暫停時出現")
	g.paused = false
	g.pad_mode = true
	ok(g.hud_meta_visible(), "手把（沒有懸停）一直顯示")
	var gp: String = FileAccess.get_file_as_string("res://scripts/ui/screens/game_place.gd")
	ok(gp.find("_pin_note(Rect2(") >= 0, "擺陣左上收進便籤")
	g.free()

## 1.3.0 第 10 大類：聲音 2.0 程式部分（落子音按重量分級、固定種子變體、棋館環境三層）
func test_sound_v130() -> void:
	var SX = load("res://scripts/game/sfx.gd")
	var ok22 := true
	for t in 22:
		var pp: Array = SX.place_of(t)
		if not (str(pp[0]) in ["place_light", "place_mid", "place_heavy"]):
			ok22 = false
	ok(ok22, "22 種都有落子音")
	ok(SX.place_of(4)[0] == "place_light" and float(SX.place_of(4)[1]) > 1.0, "刺客輕脆")
	ok(SX.place_of(2)[0] == "place_light", "弓手輕脆")
	ok(SX.place_of(1)[0] == "place_heavy" and float(SX.place_of(1)[1]) < 1.0, "盾兵低沉")
	var a = SX.new()
	var b = SX.new()
	a.streams = {"x": 0}
	b.streams = {"x": 0}
	a.variants = {"x": [1, 2, 3, 4]}
	b.variants = {"x": [1, 2, 3, 4]}
	a.reseed(777)
	b.reseed(777)
	var sa: Array = []
	var sb: Array = []
	for i in 12:
		sa.append(a._pick_variant("x"))
		sb.append(b._pick_variant("x"))
	ok(sa == sb, "同種子同變體序列（驗收可重現）")
	var rep := true
	for i in range(1, sa.size()):
		rep = rep and sa[i] != sa[i - 1]
	ok(rep, "變體不連續重複")
	a.free()
	b.free()
	ok(SX.room_gain(2, 1.0, 1.0) < SX.room_gain(2, 0.0, 1.0) and SX.room_gain(0, 1.0, 1.0) == SX.room_gain(0, 0.0, 1.0), "戰況緊只壓遠景")
	for n in ["near", "mid", "far"]:
		ok(ResourceLoader.exists("res://audio/amb_room_%s.wav" % n), "棋館環境 %s 層有檔" % n)
	ok(SX.seed_at(1, 200) == SX.seed_at(1, 200) and SX.seed_at(1, 200) != SX.seed_at(1, 201) and SX.seed_at(1, 0) != SX.seed_at(2, 0), "跳轉後的變體種子＝局數＋tick（跳回同一 tick 一樣）")
	var rp: String = FileAccess.get_file_as_string("res://scripts/ui/replay_view.gd")
	ok(rp.find("sfx.seed_at(round_no, view.tick") >= 0, "跳轉完成時重設音效種子")
	var c = SX.new()
	c.room_on = true
	c.set_room_tense(true)
	for i in 60:
		c.room_tick(0.05)
	ok(c.room_tense < 0.01, "離開戰鬥沒人刷新：緊張環境音自己放開")
	c.free()
	var UBx = load("res://scripts/ui/ui_base.gd")
	ok(UBx.obj_extent(Rect2(100, 100, 400, 300), "toolbox").position.x <= 100 - 31.5, "工具箱提環外伸算進邊界")

## 1.3.0 第 11 大類：棋館的人（對手坐在盤外、表情跟戰況、老闆的手只在開場）
func test_parlor_people_v130() -> void:
	var GS = load("res://scripts/ui/game_screens.gd")
	var A = load("res://scripts/ui/art.gd")
	ok(GS.seat_mood(0.3, 0.7) == A.M_HAPPY, "對手領先＝得意")
	ok(GS.seat_mood(0.7, 0.3) == A.M_HURT, "對手落後＝慌")
	ok(GS.seat_mood(0.5, 0.52) == A.M_GRIM, "膠著＝專注")
	var g = GS.new()
	g.mode = g.Mode.DUEL
	g.view = load("res://scripts/ui/view_buffer.gd").new()
	g.state = g.St.BATTLE
	ok(not g.seat_visible(), "雙人對戰沒有對手木偶")
	g.mode = g.Mode.VS_AI
	var plain := bool(load("res://scripts/game/save.gd").s("plain_ui"))
	ok(g.seat_visible() == (not plain), "對 AI 戰鬥時對手坐在桌邊（簡化介面不畫）")
	g.watch_mode = true
	ok(not g.seat_visible(), "看對戰代碼不畫")
	var seat: Vector2 = GS.SEAT_FOOT
	var field_right := 1170.0   # 盤框右緣（各尺寸地圖都縮放到這以內）
	ok(seat.x - 40.0 > field_right and seat.y - 70.0 > 96.0 and seat.y + 12.0 < 432.0 - 30.0, "人物在盤外右側桌面、不蓋 HUD 與茶杯")
	var fx: String = FileAccess.get_file_as_string("res://scripts/ui/battle/battle_fx.gd")
	ok(fx.find("func _draw_owner_hand") >= 0 and fx.find("if start_hold <= 0.0") >= 0, "老闆的手只在開場（截圖、減少特效時開場本來就不播）")
	g.free()

## 1.3.0 第 12 大類：每日老闆出題（挑題固定、只挑還沒三星的、一天一枚印、存檔驗型）
## 1.6.0 B08 驗收抓到：每日老闆題照真實日期抽，長題名那天英文 150% 按鈕字左右內距不夠（R12）。
## 全部殘局 × 四語 × 三字級 × 三種星數：od_label 的寬度都放得進按鈕（左右各留 R12 內距），而且至少留題名的頭與星數。
func test_od_label_fit_v1600() -> void:
	var GS = load("res://scripts/ui/game_screens.gd")
	var g = GS.new()
	g._load_fonts()
	var LS = load("res://scripts/game/strings.gd")
	var PZ = load("res://scripts/game/puzzles.gd")
	var LRx = load("res://scripts/ui/layout_rules.gd")
	var Sv = load("res://scripts/game/save.gd")
	var keep_lang = LS.lang
	var keep_ts = Sv.settings.get("text_scale", 100)
	var bad: Array = []
	var cut := 0
	var short := 0
	var n := 0
	var bw := 592.0
	var avail: float = bw - 2.0 * maxf(LRx.R12_H_MIN, LRx.R12_H_PCT * bw)
	for lg in ["zh_TW", "en", "zh_CN", "ja"]:
		LS.lang = lg
		for sc in [100, 125, 150]:
			Sv.settings["text_scale"] = sc
			for pz in PZ.all_puzzles():
				for st in [0, 3]:
					var name: String = LS.field(pz, "")
					var lab: String = g.od_label(name, st, LS.t("od_todo"), bw)
					n += 1
					if g._width(lab, g.ts(18), true) > avail:
						bad.append("%s %d%% %s" % [lg, sc, lab])
					if lab.find("…") >= 0:
						cut += 1
					if lab.find(LS.t("od_todo")) < 0:
						short += 1
	LS.lang = keep_lang
	Sv.settings["text_scale"] = keep_ts
	ok(n > 100 and bad.is_empty(), "每日老闆題按鈕字全部放得進（%d 組；拿掉狀態字 %d、題名截短 %d）" % [n, short, cut], str(bad.slice(0, 3)))
	g.free()

func test_owner_daily_v130() -> void:
	var OD = load("res://scripts/game/owner_daily.gd")
	var ids := ["a", "b", "c", "d", "e", "f", "g"]
	var p1: Array = OD.pick(20000, ids, {})
	ok(p1.size() == 3 and p1 == OD.pick(20000, ids, {}), "同一天挑同三題")
	var uniq := {}
	for x in p1:
		uniq[x] = true
	ok(uniq.size() == 3, "三題不重複")
	var diff_day := false
	for dd in range(20001, 20010):
		if OD.pick(dd, ids, {}) != p1:
			diff_day = true
	ok(diff_day, "題目每天換")
	var p2: Array = OD.pick(20000, ids, {"a": 3, "b": 3, "c": 3, "d": 3})
	ok(not "a" in p2 and not "b" in p2 and p2.size() == 3, "只挑還沒三星的")
	ok(OD.pick(1, ["x", "y"], {}).size() == 2, "題不夠就全給")
	var rec := {}
	var r: Array = OD.record(rec, 5, ["a", "b", "c"], "a", 1)
	ok(not r[1] and r[0]["done"] == ["a"], "過一題記下、還沒蓋印")
	r = OD.record(r[0], 5, ["a", "b", "c"], "x", 3)
	ok(r[0]["done"] == ["a"], "不是今天的題不算")
	r = OD.record(r[0], 5, ["a", "b", "c"], "b", 0)
	ok(r[0]["done"] == ["a"], "0 星不算")
	r = OD.record(r[0], 5, ["a", "b", "c"], "b", 2)
	r = OD.record(r[0], 5, ["a", "b", "c"], "c", 1)
	ok(r[1] and r[0]["stamped"], "三題都過蓋印")
	r = OD.record(r[0], 5, ["a", "b", "c"], "c", 3)
	ok(not r[1], "一天只蓋一枚")
	r = OD.record(r[0], 6, ["d", "e", "f"], "d", 1)
	ok(r[0]["day"] == 6 and r[0]["done"] == ["d"] and not r[0]["stamped"], "換日重來")
	var bad: Dictionary = OD.sanitize({"day": "x", "done": [1, "a", "b", "c", "d"], "stamped": "yes"})
	ok(bad["day"] == -1 and bad["done"] == ["a", "b", "c"], "壞資料拒收、限長")
	var p3: Array = OD.pick(20000, ids, {"a": 3, "b": 3, "c": 3, "d": 3, "e": 3, "f": 3})
	ok("g" in p3 and p3.size() == 3, "只剩一題沒三星：一定挑進來，再用三星的補滿（Codex cat11 #6）")
	var t1: Array = OD.today_picks({}, 30, ids, {})
	var t2: Array = OD.today_picks(t1[1], 30, ids, {t1[0][0]: 3, t1[0][1]: 3, t1[0][2]: 3})
	ok(t2[0] == t1[0], "當天拿到三星也不重抽（題單存在存檔，Codex cat11 #1）")
	var rec2: Dictionary = t1[1].duplicate(true)
	rec2["done"] = [t1[0][0]]
	var t3: Array = OD.today_picks(rec2, 30, ids.filter(func(x): return x != t1[0][0]), {})
	ok(not t1[0][0] in t3[0] and t3[1]["done"].is_empty(), "題庫移除的題：題單與完成紀錄一起拿掉")
	ok(OD.today_picks(t1[1], 31, ids, {})[1]["day"] == 31, "換日重抽")
	var gm: String = FileAccess.get_file_as_string("res://scripts/ui/screens/game_menus.gd")
	ok(gm.find("\"od_open\"") >= 0, "殘局卡片面板有入口")
	ok(gm.find("\"notebook\", \"od\"]") >= 0 and gm.find("\"od_stamps\"") >= 0 and gm.find("\"od_stamps\"") < gm.find("[\"clr_all\""), "清除殘局／戰績會一起清每日出題與印（Codex cat11 #7）")

## 1.3.0 第 13 大類：掌燈開門（只播第一次、截圖／版面檢查／headless／減少動態不播、任何鍵跳過並記下）
func test_intro_v130() -> void:
	var GS = load("res://scripts/ui/game_screens.gd")
	ok(GS.intro_should_play(false, false, false, false, false), "第一次播")
	ok(not GS.intro_should_play(true, false, false, false, false), "看過就不播")
	ok(not GS.intro_should_play(false, true, false, false, false) and not GS.intro_should_play(false, false, true, false, false), "截圖、版面檢查不播")
	ok(not GS.intro_should_play(false, false, false, true, false) and not GS.intro_should_play(false, false, false, false, true), "headless、減少動態不播")
	var SV = load("res://scripts/game/save.gd")
	var old_prefix: String = SV.prefix
	SV.prefix = "test_intro_"
	var g = GS.new()
	g.intro_t = 1.0
	g.intro_end()
	ok(g.intro_t < 0.0 and bool(SV.data.get("intro_seen", false)), "跳過或播完就記下")
	g.intro_t = 0.0
	g.intro_tick(GS.INTRO_SEC + 0.1)
	ok(g.intro_t < 0.0, "5 秒播完自動結束")
	g.free()
	SV.data.erase("intro_seen")
	SV.prefix = old_prefix
	var d := {"intro_seen": "yes"}
	SV.sanitize_data(d)
	ok(d["intro_seen"] is bool, "存檔欄位驗型")

## 1.4.0 第 1 大類：R12 格子內距、R13 圖示留白（使用者第 10 點）
func test_r12_r13_v140() -> void:
	var LR = load("res://scripts/ui/layout_rules.gd")
	var face := Rect2(100, 100, 120, 40)
	var ok_ink := Rect2(130, 110, 60, 20)       # 上下 10、左右 30
	var tight := Rect2(103, 102, 114, 36)       # 上下 2、左右 3
	var base := {"panels": [], "ribbons": [], "decos": [], "aligns": [], "btns": [Rect2(100, 100, 120, 40)], "boxes": [], "overlay": "", "need": {}}
	var d1: Dictionary = base.duplicate(true)
	d1["texts"] = [{"s": "ok", "r": ok_ink, "gr": ok_ink, "size": 18, "face": face, "ink": ok_ink, "cell": "c1"}]
	var o1: Dictionary = LR.check(d1)
	var r12a := 0
	for w in o1[LR.R12_LEVEL]:
		if w["type"] == "R12":
			r12a += 1
	ok(r12a == 0, "內距夠的格子不列")
	var d2: Dictionary = base.duplicate(true)
	d2["texts"] = [{"s": "tight", "r": tight, "gr": tight, "size": 18, "face": face, "ink": Rect2(face.get_center() - tight.size / 2, tight.size), "cell": "c2"}]
	var o2: Dictionary = LR.check(d2)
	var r12b := 0
	for w in o2[LR.R12_LEVEL]:
		if w["type"] == "R12":
			r12b += 1
	ok(r12b == 1, "太緊的格子列出（置中但上下只剩 2px）")
	var d3: Dictionary = base.duplicate(true)
	d3["texts"] = []
	d3["icons"] = [{"n": "star", "r": Rect2(200, 120, 30, 30), "face": null}, {"n": "flag", "r": Rect2(140, 108, 24, 24), "face": face}, {"n": "free", "r": Rect2(600, 600, 20, 20), "face": null}]
	var o3: Dictionary = LR.check(d3)
	var r13 := []
	for w in o3[LR.R12_LEVEL]:
		if w["type"] == "R13":
			r13.append(w["id"])
	ok("star" in r13 and not "flag" in r13, "圖示超出宿主列出；在宿主裡、上下留 8px 的不列")
	ok(int(o3.get("icons_free", -1)) == 1, "不在任何格子裡的圖示只計數、不猜宿主")
	ok(LR.R12_LEVEL == "fail", "先修清單清零後 R12／R13 是違規等級（發版前必須）")
	var ubs: String = FileAccess.get_file_as_string("res://scripts/ui/ui_base.gd")
	ok(ubs.find("maxf(ih + 8.0 + 1.0, (ih + 1.0) / 0.76)") >= 0, "價錢子格高度＝墨跡＋上下 max(4, 12%)")
	ok(ubs.find("r.size.x - 2.0 * (maxf(6.0, r.size.x * 0.06) + 1.0)") >= 0, "按鈕標籤左右各留 max(6, 6% 寬)")

## 1.4.0 第 2 大類：木活字數字（只換核准的數字符號、最後 10 秒才跳）
func test_woodtype_v140() -> void:
	var UB = load("res://scripts/ui/ui_base.gd")
	var okc := true
	for ch in "0123456789%":
		okc = okc and UB.is_wood_char(ch)
	ok(okc, "數字與百分號是木活字")
	ok(not UB.is_wood_char("金") and not UB.is_wood_char("s") and not UB.is_wood_char("秒"), "文字不換（勝負文字、單位走原字型）")
	var bv: String = FileAccess.get_file_as_string("res://scripts/ui/battle_view.gd")
	ok(bv.find("secs <= 10 and not bool(Save.s(\"reduce_motion\"))") >= 0, "倒數只在最後 10 秒跳、減少動態不跳")
	var P = load("res://scripts/ui/palette.gd")
	ok(P.WOOD_TYPE != P.WOOD_TYPE_D, "木活字色在色票")

## 1.4.0 第 3～4 大類：器物幾何、謝幕（方印、牌尺、抽屜、熱鍵木牌、三枚印章、棋鐘跳字只在正常播放）
func test_vessels_curtain_v140() -> void:
	var gr: String = FileAccess.get_file_as_string("res://scripts/ui/screens/game_result.gd")
	ok(gr.find("var tm: int = sim.winner if sim.winner >= 0 else 0") >= 0, "印章頒給勝方（雙人紅方勝就頒紅方）")
	ok(gr.find("seal_none") >= 0 and gr.find("idx == _focus and pad_mode") >= 0, "三枚一定都在（無得主＝灰章）、手把有焦點框")
	var bv: String = FileAccess.get_file_as_string("res://scripts/ui/battle_view.gd")
	ok(bv.find("secs == clock_last - 1 and not paused and seek_target < 0") >= 0, "棋鐘只在正常播放往下走一秒才跳、響")
	var cx: String = FileAccess.get_file_as_string("res://scripts/ui/codex_view.gd")
	ok(cx.find("probe_cell_begin(tg)") >= 0, "圖鑑熱鍵木牌宣告成格子（R11／R12）")
	var lv: String = FileAccess.get_file_as_string("res://scripts/ui/lobby_view.gd")
	ok(lv.find("btn_seal_square = true") >= 0 and lv.find("btn_seal_square = false") >= 0, "大廳方印只給開戰鈕（畫完重設）")
	var SV = load("res://scripts/game/save.gd")
	var d := {"lobby_stamps": "x"}
	SV.sanitize_data(d)
	ok(d["lobby_stamps"] == 0, "手帳印跡存檔驗型")


## 1.4.0 第 8 大類：器物從桌上的固定位置滑進來（方案 §2.2）
func test_transition_v140() -> void:
	var GS = load("res://scripts/ui/game_screens.gd")
	var g = GS.new()
	g.shot_dir = ""
	g.layout_probe = false
	g.overlay = "codex"
	g.time = 10.0
	g._ov_t = 10.0
	var Save = load("res://scripts/game/save.gd")
	var keep := {}
	for k in ["reduce_fx", "reduce_motion", "plain_ui"]:
		keep[k] = Save.s(k)
		Save.settings[k] = false
	ok(g.ov_trans_k() == 0.0 and g.ov_slide_offset() == GS.SLIDE_FROM["codex"], "剛打開：在桌上的起點（圖鑑從下面）")
	g.time = 10.0 + GS.SLIDE_SEC * 0.5
	ok(g.ov_trans_k() > 0.0 and g.ov_trans_k() < 1.0, "轉場中")
	# 走完整的 _input 路徑（閘門在最前面）：吃掉的事件不會進命令佇列
	var mbe := func(btn: int, down: bool) -> InputEventMouseButton:
		var e := InputEventMouseButton.new()
		e.button_index = btn
		e.pressed = down
		e.position = Vector2(640, 400)
		return e
	var nq: int = g._cmds.size()
	g._input(mbe.call(MOUSE_BUTTON_LEFT, true))
	ok(g.ov_trans_k() == 1.0 and g.ov_slide_offset() == Vector2.ZERO and g._cmds.size() == nq, "轉場中按下＝直接到終態，這一下吃掉（沒進佇列）")
	var kd := InputEventKey.new()
	kd.keycode = KEY_ESCAPE
	kd.pressed = true
	g._input(kd)
	var nq_k: int = g._cmds.size()
	var ku := InputEventKey.new()
	ku.keycode = KEY_ESCAPE
	ku.pressed = false
	g._input(ku)
	ok(g.trans_eat.has("m%d" % MOUSE_BUTTON_LEFT), "放開別的鍵不會解鎖（只認跳過的那一個輸入，Codex cat08 r2 #1）")
	g._input(mbe.call(MOUSE_BUTTON_LEFT, false))
	ok(g.trans_eat.is_empty() and g._cmds.size() == nq_k, "跳過的那一下放開也吃掉（多久之後放開都一樣）")
	g.time += 1.0 / 60.0   # 下一幀（1.5.0：跳過的那一幀的其他按下也吃掉）
	g._input(mbe.call(MOUSE_BUTTON_LEFT, true))
	ok(g._cmds.size() == nq_k + 1, "之後的點擊照常進佇列（不靠固定時間）")
	g._ov_t = g.time
	var ke := InputEventKey.new()
	ke.keycode = KEY_DOWN
	ke.pressed = true
	g._input(ke)
	var nq2: int = g._cmds.size()
	var ke2 := InputEventKey.new()
	ke2.keycode = KEY_DOWN
	ke2.pressed = true
	ke2.echo = true
	g._input(ke2)
	ok(g._cmds.size() == nq2, "同一顆鍵按住的連發也吃掉")
	ke2.pressed = false
	ke2.echo = false
	g._input(ke2)
	g._ov_t = g.time
	var nq3: int = g._cmds.size()
	g._input(mbe.call(MOUSE_BUTTON_WHEEL_DOWN, true))
	g._input(mbe.call(MOUSE_BUTTON_WHEEL_DOWN, false))
	ok(g._cmds.size() == nq3, "滾輪在轉場中不捲（Codex cat08 #4）")
	g._ov_t = g.time
	var mv2 := InputEventMouseMotion.new()
	mv2.position = Vector2(500, 500)
	ok(g._trans_gate(mv2), "轉場中的拖曳／移動不生效（音量木軌不會被拖，Codex cat08 #3）")
	var td := InputEventScreenTouch.new()
	td.index = 0
	td.pressed = true
	td.position = Vector2(100, 100)
	g._input(td)
	var tu := InputEventScreenTouch.new()
	tu.index = 0
	tu.pressed = false
	g._input(tu)
	ok(g.touches.is_empty() and g.lp_t < 0.0 and g.trans_eat.is_empty(), "觸控跳過：放開吃掉、手指狀態與長按計時清掉（Codex cat08 r2 #3）", "%s %s %s" % [str(g.touches), str(g.lp_t), str(g.trans_eat)])
	g._ov_t = g.time
	g.stick[JOY_AXIS_LEFT_Y] = 0.46
	var dz_keep = Save.s("deadzone")
	Save.settings["deadzone"] = 20
	g._stick_dir = Vector2i.ZERO
	var f0: int = g._focus
	g._stick_repeat(0.016)
	ok(g.ov_trans_k() == 1.0 and g.trans_stick_eat and g._focus == f0, "轉場中推搖桿（和移焦同門檻）＝跳過、不移焦（Codex cat08 r2 #2）")
	g._stick_repeat(0.5)
	ok(g._focus == f0, "推著不放也不送方向")
	g.stick[JOY_AXIS_LEFT_Y] = 0.0
	g._stick_repeat(0.016)
	ok(not g.trans_stick_eat, "搖桿回中才解鎖")
	# 兩個輸入各跳過一頁：兩個都記著，各自放開才解鎖（Codex cat08 r3 #1）
	g._ov_t = g.time
	g._input(mbe.call(MOUSE_BUTTON_LEFT, true))
	g._ov_t = g.time
	var kb := InputEventKey.new()
	kb.keycode = KEY_B
	kb.pressed = true
	g._input(kb)
	ok(g.trans_eat.size() == 2, "按住 A 跳過、再用 B 跳過：兩個都記")
	var nq4: int = g._cmds.size()
	var kb2 := InputEventKey.new()
	kb2.keycode = KEY_B
	kb2.pressed = true
	kb2.echo = true
	g._input(kb2)
	kb2.pressed = false
	kb2.echo = false
	g._input(kb2)
	g._input(mbe.call(MOUSE_BUTTON_LEFT, false))
	ok(g._cmds.size() == nq4 and g.trans_eat.is_empty(), "B 的連發與放開、A 的放開都吃掉")
	# 手把跳過後拔掉：身分清掉（Codex cat08 r3 #4）
	g._ov_t = g.time
	var jb := InputEventJoypadButton.new()
	jb.device = 3
	jb.button_index = JOY_BUTTON_A
	jb.pressed = true
	g._input(jb)
	ok(g.trans_eat.has("j3:%d" % JOY_BUTTON_A), "手把跳過記身分")
	g._trans_joy_changed(3, false)
	ok(g.trans_eat.is_empty() and not g.trans_stick_eat, "手把拔掉：身分與搖桿狀態清掉（引擎不補放開）")
	# 開頁前就推著搖桿、長按計時中：轉場開始時鎖搖桿、取消長按（Codex cat08 r3 #2、#3）
	g.stick[JOY_AXIS_LEFT_X] = 0.9
	g.lp_t = 0.2
	g._ov_t = g.time
	g._trans_begin()
	ok(g.trans_stick_eat and g.lp_t < 0.0, "轉場開始：推著的搖桿鎖到回中、長按取消")
	g._ov_t = g.time - 1.0
	var f1: int = g._focus
	g._stick_repeat(0.016)
	g._stick_repeat(0.5)
	ok(g._focus == f1 and g._stick_dir == Vector2i.ZERO, "轉場被別的鍵跳過之後，推著的搖桿仍不送方向")
	g.stick[JOY_AXIS_LEFT_X] = 0.0
	g._stick_repeat(0.016)
	ok(not g.trans_stick_eat, "回中解鎖")
	# 事件順序整合（Codex cat08 r4 #2）：照遊戲的順序——開頁（畫面那一幀偵測到疊層改變）→ 同一幀先來搖桿偏移、再來跳過鍵 → 逐幀跑 _stick_repeat，查方向命令有沒有進佇列
	var dir_cmds := func() -> int:
		var n := 0
		for c in g._cmds:
			if c["kind"] == "key" and int(c["data"]) in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
				n += 1
		return n
	g.stick[JOY_AXIS_LEFT_X] = 0.0
	g.stick[JOY_AXIS_LEFT_Y] = 0.0
	g._stick_dir = Vector2i.ZERO
	g.trans_stick_eat = false
	g.trans_eat.clear()
	g.overlay = "settings"
	g._ov_t = g.time
	g._trans_begin()
	var ax2 := InputEventJoypadMotion.new()
	ax2.axis = JOY_AXIS_LEFT_Y
	ax2.axis_value = 0.9
	g._input(ax2)
	var kx := InputEventKey.new()
	kx.keycode = KEY_X
	kx.pressed = true
	g._input(kx)
	var d0: int = dir_cmds.call()
	for fr in 60:
		g.time += 1.0 / 60.0
		g._stick_repeat(1.0 / 60.0)
	ok(dir_cmds.call() == d0, "轉場中先推搖桿、同幀按鍵跳過：推著一秒都不送方向")
	kx.pressed = false
	g._input(kx)
	ax2.axis_value = 0.0
	g._input(ax2)
	g._stick_repeat(1.0 / 60.0)
	ax2.axis_value = 0.9
	g._input(ax2)
	g._stick_repeat(1.0 / 60.0)
	ok(dir_cmds.call() == d0 + 1, "回中再推才恢復（送一次方向）")
	# 只推搖桿（不按鍵）：走 _input，推下去就到終態、推著不送方向、回中再推恢復（Codex cat08 r5 #1）
	ax2.axis_value = 0.0
	g._input(ax2)
	g._stick_repeat(1.0 / 60.0)
	g.overlay = "codex"
	g._ov_t = g.time
	g._trans_begin()
	ax2.axis_value = 0.9
	g._input(ax2)
	ok(g.ov_trans_k() == 1.0 and g.trans_stick_eat, "只推搖桿：立即到終態並鎖方向")
	var d1: int = dir_cmds.call()
	for fr in 60:
		g.time += 1.0 / 60.0
		g._stick_repeat(1.0 / 60.0)
	ok(dir_cmds.call() == d1, "推著一秒不送方向")
	ax2.axis_value = 0.0
	g._input(ax2)
	g._stick_repeat(1.0 / 60.0)
	ax2.axis_value = 0.9
	g._input(ax2)
	g._stick_repeat(1.0 / 60.0)
	ok(dir_cmds.call() == d1 + 1 and not g.trans_stick_eat, "回中再推恢復")
	Save.settings["deadzone"] = dz_keep
	for k2 in ["plain_ui", "reduce_fx"]:
		g._ov_t = g.time
		Save.settings[k2] = true
		ok(g.ov_trans_k() == 1.0, "%s：沒有轉場" % k2)
		Save.settings[k2] = false
	g._ov_t = g.time
	g.layout_probe = true
	ok(g.ov_trans_k() == 1.0, "版面探針拍終態")
	g.layout_probe = false
	ok(GS.SLIDE_SEC >= 0.18 and GS.SLIDE_SEC <= 0.3, "轉場 180～300ms")
	g._ov_t = g.time
	Save.settings["reduce_motion"] = true
	ok(g.ov_trans_k() == 1.0, "減少動態：沒有轉場")
	Save.settings["reduce_motion"] = false
	g.shot_dir = "x"
	ok(g.ov_trans_k() == 1.0, "截圖：沒有轉場（固定畫面重拍一致）")
	g.shot_dir = ""
	g.overlay = "result_x"
	ok(g.ov_trans_k() == 1.0, "沒列在表裡的疊層照舊淡入")
	for k in keep:
		Save.settings[k] = keep[k]
	g.free()
	for f in ["res://scripts/ui/lobby_view.gd", "res://scripts/ui/screens/game_modes.gd", "res://scripts/ui/ui_base.gd"]:
		var src: String = FileAccess.get_file_as_string(f)
		ok(src.find("draw_set_transform(Vector2.ZERO") < 0 and src.find("draw_set_transform_matrix(Transform2D.IDENTITY)") < 0, "%s 切矩陣都以 ui_xf 為底（滑動不會被蓋掉）" % f.get_file())


## 1.4.0 第 9 大類：聲音 3.0（空間化、嘟囔語）
func test_sound_v140() -> void:
	var SX = load("res://scripts/game/sfx.gd")
	ok(SX.pan_bus(-0.9, false) == SX.BUS_SFX_L and SX.pan_bus(0.9, false) == SX.BUS_SFX_R, "聲像跟著出手的兵分左右")
	ok(SX.pan_bus(0.1, false) == SX.BUS_SFX and SX.pan_bus(-0.9, true) == SX.BUS_SFX, "中間留正中；單聲道時不分")
	var GM = load("res://scripts/ui/screens/game_menus.gd")
	var Save = load("res://scripts/game/save.gd")
	ok(GM.VOL_KEY.get("set_voice_vol", "") == "voice_vol" and GM.VOL_PREVIEW.get("voice_vol", "") == "voice", "人聲獨立音量有設定列、調整時試聽")
	ok(int(Save.DEFAULT_SETTINGS.get("voice_vol", -1)) == 70, "人聲預設 70")
	for m in ["happy", "sad", "hmm"]:
		for i in 3:
			ok(FileAccess.file_exists("res://audio/voice_%s_%d.wav" % [m, i + 1]), "嘟囔語占位檔 %s %d" % [m, i + 1])
	var csv: String = FileAccess.get_file_as_string("res://data/strings.csv")
	ok(csv.find("\nset_voice_vol,") >= 0 and csv.find("\nsd_set_voice_vol,") >= 0, "人聲設定有四語")
	ok(int(Save.sanitize_settings({"voice_vol": 900})["voice_vol"]) == 100 and int(Save.sanitize_settings({"voice_vol": -5})["voice_vol"]) == 0, "人聲音量清理 0～100（Codex cat09 #3）")
	var sxs: String = FileAccess.get_file_as_string("res://scripts/game/sfx.gd")
	ok(sxs.find("func set_voice_vol") >= 0 and sxs.find("voice.stop()") >= 0, "人聲調到 0 正在說的立刻停（Codex cat09 #2）")
	var gms: String = FileAccess.get_file_as_string("res://scripts/ui/screens/game_menus.gd")
	var ia := gms.find("func _apply_master() -> void:")
	ok(ia >= 0 and gms.find("set_voice_vol(int(Save.s(\"voice_vol\"))", ia) > ia and gms.find("sfx.mono = bool(Save.s(\"mono\"))", ia) > ia, "人聲音量與單聲道在 _apply_master 同步（開機、切單聲道都會套，Codex cat09 #1）")
	var bvs: String = FileAccess.get_file_as_string("res://scripts/ui/battle_view.gd")
	ok(bvs.find("ev.get(\"src\", ev.get(\"id\"") >= 0, "死亡事件用死者位置算聲像（Codex cat09 #4）")


## 1.4.0 第 10 大類：棋館的人 2.0（謝幕反應、老闆手勢、印章冊）
func test_people_v140() -> void:
	var GS = load("res://scripts/ui/game_screens.gd")
	var A = load("res://scripts/ui/art.gd")
	ok(GS.seat_react(false, 1, 0.5, false)[0] == 0, "還在打：沒有謝幕反應")
	var win: Array = GS.seat_react(true, 1, 0.3, false)
	ok(int(win[0]) == A.M_HAPPY and float(win[1]) > 0.0 and float(win[3]) == 0.0, "對手贏：得意＋點頭、不推茶杯")
	var lose: Array = GS.seat_react(true, 0, 1.0, false)
	ok(int(lose[0]) == A.M_HURT and float(lose[3]) > 6.0, "對手輸：慌＋茶杯往前推")
	var still: Array = GS.seat_react(true, 0, 1.0, true)
	ok(int(still[0]) == A.M_HURT and float(still[1]) == 0.0 and float(still[2]) == 0.0 and float(still[3]) == 0.0, "減少動態：只換表情、不動")
	ok(GS.seat_react(true, -1, 0.5, false)[0] == A.M_GRIM, "平手：專注")
	ok(GS.seat_react(true, 1, 0.4, false) == GS.seat_react(true, 1, 0.4, false), "同一時刻同結果（純函式）")
	var g = GS.new()
	var pw: Array = g.owner_end_pose(0, 0.9)
	ok(float(pw[0]) == 1.0 and bool(pw[2]) and float(pw[1]) == 0.0, "玩家贏：老闆伸手放下紅泥小章")
	var pl: Array = g.owner_end_pose(1, 0.7)
	ok(float(pl[0]) == 1.0 and float(pl[1]) > 0.0 and not bool(pl[2]), "玩家輸：老闆叩桌")
	ok(float(g.owner_end_pose(0, 1.3)[0]) == 0.0, "結算前手收回")
	g.free()
	ok(GS.stamp_page(0) == [1, 0] and GS.stamp_page(1) == [1, 1] and GS.stamp_page(10) == [1, 10] and GS.stamp_page(11) == [2, 1], "印章冊一頁 10 格、蓋滿才翻頁")
	var csv: String = FileAccess.get_file_as_string("res://data/strings.csv")
	ok(csv.find("\nod_book,") >= 0, "印章冊頁碼有四語")


## 1.4.0 第 12 大類：標題主次（朱漆對戰主牌、牛皮紙建議便箋、底架錯落木偶）
func test_title_v140() -> void:
	var GM = load("res://scripts/ui/screens/game_menus.gd")
	ok(GM.TITLE_SHELF.size() >= 3 and GM.TITLE_SHELF.size() <= 5, "底架 3～5 隻代表木偶")
	var scs := {}
	var ys := {}
	for sh in GM.TITLE_SHELF:
		scs[float(sh[3])] = true
		ys[(sh[0] as Vector2).y] = true
		ok((sh[0] as Vector2).x > 520.0 and (sh[0] as Vector2).x < 1200.0 and (sh[0] as Vector2).y >= 708.0 and (sh[0] as Vector2).y <= 752.0, "木偶腳點在木台上")
	ok(scs.size() >= 3 and ys.size() >= 3, "大小、前後錯落（不是排排站）")
	var src: String = FileAccess.get_file_as_string("res://scripts/ui/screens/game_menus.gd")
	ok(src.find("btn_no_wax = i == 0\n") >= 0 and src.find("_btn(mr2, \"\", pq[3], on, i == 0)") >= 0 and src.find("btn_no_wax = false") >= 0, "對戰是朱漆木牌主牌（不畫火漆、畫完重設）")
	var v16: String = FileAccess.get_file_as_string("res://scripts/ui/screens/game_v16.gd")
	ok(v16.find("_btn(NS_RECT, \"\", _next_action(k), true, false, PAL.KRAFT)") >= 0 and v16.find("Color(0.16, 0.3, 0.42, 0.95)") < 0, "建議下一步改牛皮紙便箋（不再是深藍膠囊）")


## 1.5.0 §12／§17：輸入身分測試範本（100 組）——來源 6 × 時機 4 × 組合 4 ＝ 96 組＋4 組 1.4.0 回歸。
## 全部從真實 _input 進入；核對：轉場中的事件一律不進命令佇列、放開／回中之後鎖全部解開、最後一次正常點擊照常進佇列（不卡死）。
## 之後任何「吃輸入」的功能都要接這個範本（把 open_fn 換成自己的開啟方式）。
func _im_ev(src: String, down: bool, val := 1.0) -> InputEvent:
	match src:
		"mouse":
			var e := InputEventMouseButton.new()
			e.button_index = MOUSE_BUTTON_LEFT
			e.pressed = down
			e.position = Vector2(640, 400)
			return e
		"key":
			var k := InputEventKey.new()
			k.keycode = KEY_X
			k.physical_keycode = KEY_X
			k.pressed = down
			return k
		"key2":
			var k2 := InputEventKey.new()
			k2.keycode = KEY_B
			k2.physical_keycode = KEY_B
			k2.pressed = down
			return k2
		"joy":
			var j := InputEventJoypadButton.new()
			j.device = 0
			j.button_index = JOY_BUTTON_A
			j.pressed = down
			return j
		"lstick":
			var a := InputEventJoypadMotion.new()
			a.device = 0
			a.axis = JOY_AXIS_LEFT_Y
			a.axis_value = val if down else 0.0
			return a
		"rstick":
			var r := InputEventJoypadMotion.new()
			r.device = 0
			r.axis = JOY_AXIS_RIGHT_Y
			r.axis_value = val if down else 0.0
			return r
		_:
			var t := InputEventScreenTouch.new()
			t.index = 0
			t.pressed = down
			t.position = Vector2(640, 400)
			return t

func test_input_matrix_v150() -> void:
	var GS = load("res://scripts/ui/game_screens.gd")
	var Save = load("res://scripts/game/save.gd")
	var keep := {}
	for k in ["reduce_fx", "reduce_motion", "plain_ui", "deadzone"]:
		keep[k] = Save.s(k)
	Save.settings["reduce_fx"] = false
	Save.settings["reduce_motion"] = false
	Save.settings["plain_ui"] = false
	Save.settings["deadzone"] = 20
	var srcs := ["mouse", "key", "joy", "lstick", "rstick", "touch"]
	var timings := ["start", "mid", "last", "after"]
	var combos := ["single", "pair", "pairrev", "hold", "unplug"]   # pairrev＝同一幀先按別的鍵跳過、再操作這個來源（Codex v150 cat01 r3 #1）
	var bad: Array = []
	var n := 0
	# 副作用量測：命令佇列、圖鑑捲動、觸控手指——轉場中一個都不能變（Codex v150 cat01 #4：只看佇列會漏掉右搖桿直接捲動）
	var fx_of := func(g) -> Array:
		return [g._cmds.size(), float(g.cx_scroll.get("left", 0.0)), g.touches.size()]
	for src in srcs:
		for tm in timings:
			for cb in combos:
				n += 1
				var g = GS.new()
				g.shot_dir = ""
				g.layout_probe = false
				g.overlay = ""
				g.time = 10.0
				g.cx_regions["left"] = Rect2(0, 0, 100, 100)
				g.cx_content["left"] = 5000.0
				for ax in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
					g.stick[ax] = 0.0
				if cb == "hold":
					g._input(_im_ev(src, true))   # 按住跨轉場：轉場開始前就按下
				g.overlay = "codex"
				g._ov_t = g.time
				g._trans_begin()
				var during: bool = tm != "after"
				if tm == "mid":
					g.time += GS.SLIDE_SEC * 0.5
				elif tm == "last":
					g.time += GS.SLIDE_SEC - 1.0 / 60.0
				elif tm == "after":
					g.time += GS.SLIDE_SEC + 0.05
				var f0: Array = fx_of.call(g)
				if cb == "pairrev":
					g._input(_im_ev("key2", true))
				if cb != "hold":
					g._input(_im_ev(src, true))
				if cb == "pair":
					g._input(_im_ev("key2", true))
				var fp: Array = fx_of.call(g)   # 按下當下的副作用（觸控手指在放開時會清掉，要在這裡量）
				for fr in 30:   # 按住期間：鍵盤連發、搖桿持續推，逐幀 0.5 秒
					g.time += 1.0 / 60.0
					if src == "key":
						var ec: InputEventKey = _im_ev("key", true)
						ec.echo = true
						g._input(ec)
					if src == "rstick":
						g._input(_im_ev("rstick", true))
					g._stick_repeat(1.0 / 60.0)
				var unplugged: bool = cb == "unplug" and src in ["joy", "lstick", "rstick"]
				if cb == "unplug":
					g._trans_joy_changed(0, false)
				if cb == "pair" or cb == "pairrev":
					g._input(_im_ev("key2", false))
				if not unplugged:
					g._input(_im_ev(src, false))   # 拔掉的手把不會有放開事件（引擎不補）
				g._stick_repeat(1.0 / 60.0)
				var f1: Array = fx_of.call(g)
				if during:
					if f1[0] != f0[0]:
						bad.append("%s/%s/%s 轉場中有 %d 筆進佇列" % [src, tm, cb, f1[0] - f0[0]])
					if absf(float(f1[1]) - float(f0[1])) > 0.001:
						bad.append("%s/%s/%s 轉場中圖鑑被捲動" % [src, tm, cb])
					if int(fp[2]) != int(f0[2]):
						bad.append("%s/%s/%s 轉場中觸控手指被記下" % [src, tm, cb])
				else:
					# 轉場後：按下當下或之後要有實際副作用（不是全部吃掉的假通過）；只有「按住跨轉場」豁免（按下在開頁前，設計如此）
					var moved: bool = f1[0] > f0[0] or fp[0] > f0[0] or absf(float(f1[1]) - float(f0[1])) > 0.001 or int(fp[2]) > int(f0[2])
					if not moved and cb != "hold":
						bad.append("%s/%s/%s 轉場後的輸入沒有效果（被誤吃）" % [src, tm, cb])
				if not g.trans_eat.is_empty() or g.trans_stick_eat or g.trans_rstick_eat:
					bad.append("%s/%s/%s 放開／回中／拔掉後鎖沒解開（%s, %s, %s）" % [src, tm, cb, str(g.trans_eat.keys()), str(g.trans_stick_eat), str(g.trans_rstick_eat)])
				# 恢復：下一幀同一個來源再操作一次，一定有效果（每種來源都驗，不只滑鼠）
				g.time += 1.0 / 60.0
				var f2: Array = fx_of.call(g)
				if src in ["lstick"]:
					g._input(_im_ev("lstick", true))
					g._stick_repeat(1.0 / 60.0)
					g._input(_im_ev("lstick", false))
				elif src == "rstick":
					g._input(_im_ev("rstick", true))
					g._input(_im_ev("rstick", false))
				elif src == "touch":
					g._input(_im_ev("touch", true))
				else:
					g._input(_im_ev(src, true))
					g._input(_im_ev(src, false))
				var f3: Array = fx_of.call(g)
				var rec: bool = f3[0] > f2[0] or absf(float(f3[1]) - float(f2[1])) > 0.001 or f3[2] > f2[2]
				if not rec:
					bad.append("%s/%s/%s 之後同一來源再操作沒有效果（卡死）" % [src, tm, cb])
				g.free()
	# 4 組 1.4.0 回歸（Codex cat08 抓過的）：兩輸入各跳一頁、別的鍵放開不解鎖、只推搖桿跳過、手把跳過後拔掉
	var g2 = GS.new()
	g2.shot_dir = ""
	g2.time = 10.0
	for ax in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		g2.stick[ax] = 0.0
	g2.overlay = "codex"
	g2._ov_t = g2.time
	g2._input(_im_ev("mouse", true))
	g2.overlay = "settings"
	g2._ov_t = g2.time
	g2._input(_im_ev("key", true))
	n += 1
	if g2.trans_eat.size() != 2:
		bad.append("回歸 1：兩個輸入各跳一頁沒有都記")
	g2._input(_im_ev("key2", false))
	n += 1
	if g2.trans_eat.size() != 2:
		bad.append("回歸 2：別的鍵放開解了鎖")
	g2._input(_im_ev("mouse", false))
	g2._input(_im_ev("key", false))
	g2.overlay = "keys"
	g2._ov_t = g2.time
	g2._input(_im_ev("lstick", true, 0.9))
	n += 1
	if not (g2.ov_trans_k() == 1.0 and g2.trans_stick_eat):
		bad.append("回歸 3：只推搖桿沒有跳過")
	g2._input(_im_ev("lstick", false))
	g2._stick_repeat(1.0 / 60.0)
	g2.overlay = "profile"
	g2._ov_t = g2.time
	g2._input(_im_ev("joy", true))
	g2._trans_joy_changed(0, false)
	n += 1
	if not g2.trans_eat.is_empty():
		bad.append("回歸 4：手把拔掉身分沒清")
	g2.free()
	for k in keep:
		Save.settings[k] = keep[k]
	ok(n == 124, "輸入矩陣 124 組：來源 6 × 時機 4 × 組合 5＋回歸 4（%d）" % n)
	ok(bad.is_empty(), "輸入矩陣全過：轉場中零穿透、放開零卡鎖、之後正常點擊不被吃", "\n".join(bad.slice(0, 20)))


## 1.5.0 第 2 批：主動作登記＋R14、標題、結果首屏、兩步開戰
func test_r14_v150() -> void:
	var LR = load("res://scripts/ui/layout_rules.gd")
	var has := func(out: Dictionary, lvl: String) -> bool:
		for v in out[lvl]:
			if str(v["type"]) == "R14":
				return true
		return false
	ok(not has.call(LR.check({"screen": {"cls": "title", "main": "plaque_battle", "skip": ""}, "clicks": 9}), "fail"), "標題 9 個可點元件：通過")
	ok(has.call(LR.check({"screen": {"cls": "title", "main": "plaque_battle", "skip": ""}, "clicks": 10}), "fail"), "標題 10 個：失敗（已改造的類別）")
	var ex: Dictionary = LR.check({"screen": {"cls": "result", "main": "x", "skip": "測試理由"}, "clicks": 9})
	ok(not has.call(ex, "fail") and not (ex["exempt"] as Array).is_empty(), "登記豁免理由：不算失敗、列進宣告例外")
	ok(has.call(LR.check({"screen": {"cls": "codex", "main": "x", "skip": ""}, "clicks": 30}), "warn") and not has.call(LR.check({"screen": {"cls": "codex", "main": "x", "skip": ""}, "clicks": 30}), "fail"), "還沒改造的類別：超標只警告")
	ok(has.call(LR.check({"screen": {"cls": "title", "main": "", "skip": ""}, "clicks": 3}), "fail"), "登記了類別卻沒有主動作：失敗")
	ok(LR.check({"clicks": 99})["fail"].is_empty(), "沒登記的畫面不查 R14")
	var GS = load("res://scripts/ui/game_screens.gd")
	var g = GS.new()
	g._btns.append({"r": Rect2(), "cb": func(): pass, "en": true})
	g._btns.append({"r": Rect2(), "cb": func(): pass, "en": true, "grid": true})
	ok(g.click_count() == 1, "棋盤格這類 grid 不算可點元件")
	g.free()
	var gm: String = FileAccess.get_file_as_string("res://scripts/ui/screens/game_menus.gd")
	ok(gm.find("screen_register(\"title\", \"plaque_battle\")") >= 0 and gm.find("[\"menu_codes\", func(): overlay = \"codes\"") < 0, "標題登記主動作；代碼不在標題系統列")
	ok(gm.find("[\"menu_codes\", \"hc_codes_d\", \"copy\"") >= 0, "代碼移到收藏第二層")
	var gr: String = FileAccess.get_file_as_string("res://scripts/ui/screens/game_result.gd")
	ok(gr.find("screen_register(\"result\"") >= 0 and gr.find("while bs.size() > RES_MAIN_MAX:") >= 0, "結果登記主動作；主動作最多 2 顆，其他進「更多」")

func test_quick_rematch_v150() -> void:
	var GS = load("res://scripts/ui/game_screens.gd")
	var g = GS.new()
	var Save = load("res://scripts/game/save.gd")
	var keep = Save.data.get("last_rules", {})
	Save.data["last_rules"] = {}
	ok(not g.quick_rematch_ok(), "沒有上次的大廳設定：不走兩步開戰（照舊進大廳）")
	var keep_f = Save.data.get("last_form", "")
	Save.data["last_rules"] = {"ai": load("res://scripts/core/ruleset.gd").standard().to_code()}
	Save.data["last_form"] = ""
	ok(not g.quick_rematch_ok(), "有規則但沒有上次陣型：照舊進大廳（Codex v150 cat02 #4）")
	Save.data["last_form"] = "x"
	ok(g.quick_rematch_ok(), "有上次規則與陣型：最近玩的直接進擺陣")
	Save.data["last_rules"] = {"ai": "壞掉的碼"}
	ok(not g.quick_rematch_ok(), "上次規則讀不回來：照舊進大廳（不悄悄換成標準）")
	Save.data["last_rules"] = keep
	Save.data["last_form"] = keep_f
	g.free()
	var gm: String = FileAccess.get_file_as_string("res://scripts/ui/screens/game_menus.gd")
	ok(gm.find("if ek == \"menu_vs_ai\" and call(\"quick_rematch_ok\"):") >= 0, "最近玩的：對 AI 快速對戰走兩步開戰")


## 1.5.0 第 3 批：大廳三步頁
func test_lobby_steps_v150() -> void:
	var GS = load("res://scripts/ui/game_screens.gd")
	ok(GS.LB_STEP_ROWS.size() == 3 and "opp" in GS.LB_STEP_ROWS[0] and "map" in GS.LB_STEP_ROWS[1] and "rules" in GS.LB_STEP_ROWS[2], "三步：對手／地圖（含大小）／開戰（卡池＋規則）")
	var seen := {}
	for rows in GS.LB_STEP_ROWS:
		for r0 in rows:
			ok(not seen.has(r0), "每一列只在一步出現（%s）" % r0)
			seen[r0] = true
	ok(seen.size() == 5, "五列都有地方放（地圖、大小、卡池、對手、規則）")
	var g = GS.new()
	g.lobby_step = 0
	ok(g._lb_show("opp") and not g._lb_show("map"), "第一步只放對手")
	g.lobby_step = 2
	ok(g._lb_show("rules") and g._lb_show("cards") and not g._lb_show("opp"), "第三步放卡池與規則")
	g.btn_group = ""
	g._btns.clear()
	for k in 3:
		g._btns.append({"r": Rect2(), "cb": func(): pass, "en": true, "group": "st_x"})
	g._btns.append({"r": Rect2(), "cb": func(): pass, "en": true, "group": ""})
	ok(g.click_count() == 2, "同一組按鈕（步進器、分頁列）算一個控制")
	g.free()
	var g2 = GS.new()
	g2.overlay = "lobby"
	g2.lobby_open = false
	g2.lobby_menu = false
	g2.lobby_step = 0
	g2._key(KEY_E)
	ok(g2.lobby_step == 1 and g2._lb_focus_main, "大廳 RB（E）＝下一步，焦點交給主鈕", "step=%d state=%d" % [g2.lobby_step, g2.state])
	g2._key(KEY_Q)
	ok(g2.lobby_step == 0, "大廳 LB（Q）＝上一步")
	g2._key(KEY_TAB)
	ok(g2.lobby_open, "大廳 Y（Tab）＝打開進階折頁")
	# 同一幀 LB＋A：換步後舊按鈕失效，不會按到上一步畫面的「開戰」（Codex v150 cat03 r2）
	g2.lobby_open = false
	g2.lobby_step = 2
	var fired := [false]
	g2._btns.clear()
	g2._btns.append({"r": Rect2(966, 700, 234, 48), "cb": func(): fired[0] = true, "en": true})
	g2._btns_gen = g2._gen
	g2._focus = 0
	g2._key(KEY_Q)
	g2._key(KEY_ENTER)
	ok(g2.lobby_step == 1 and not fired[0], "同一幀先 LB 再 A：不會觸發舊畫面的開戰")
	fired[0] = false
	g2._btns.clear()
	g2._btns.append({"r": Rect2(966, 700, 234, 48), "cb": func(): fired[0] = true, "en": true})
	g2._btns_gen = g2._gen
	g2._focus = 0
	g2._key(KEY_TAB)
	g2._key(KEY_ENTER)
	ok(not fired[0], "同一幀先 Y 再 A：開合折頁後舊按鈕失效（Codex v150 cat03 r3）")
	g2.free()
	var lv: String = FileAccess.get_file_as_string("res://scripts/ui/lobby_view.gd")
	ok(lv.find("lobby_step = 2 if code != \"\" else 0") >= 0, "有上次設定時直接打開在第三步")
	var LR = load("res://scripts/ui/layout_rules.gd")
	ok("lobby" in LR.R14_ENFORCE, "大廳是已改造類別（R14 超標失敗）")

func test_place_tidy_v150() -> void:
	var LR = load("res://scripts/ui/layout_rules.gd")
	ok("place" in LR.R14_ENFORCE and int(LR.R14_LIMITS["place"]) == 12, "擺陣轉成已改造類別（上限 12，超標＝失敗）")
	var gp: String = FileAccess.get_file_as_string("res://scripts/ui/screens/game_place.gd")
	ok(gp.find("screen_register(\"place\"") >= 0, "擺陣登記主動作")
	ok(gp.find("if mode == Mode.VS_AI:\n\t\t_chalk_zone(mr)") >= 0, "對 AI：敵區改粉筆虛線框（不再整片竹簾）")
	ok(gp.find("_bamboo_blind(mr)") >= 0, "雙人對戰照舊竹簾")
	ok(gp.find("btn_group = \"cards\"") >= 0, "兵卡牌尺（含卡上的 ?）算一個選擇器")
	var GS = load("res://scripts/ui/game_screens.gd")
	var g = GS.new()
	ok(not g.foe_tag_open, "敵情翻牌預設收合")
	var gc: String = FileAccess.get_file_as_string("res://scripts/ui/screens/game_core.gd")
	ok(gc.find("foe_tag_open = false") >= 0, "新的一局擺陣：翻牌收回")
	ok(not g.fp_more, "自由部署「工具 ▾」預設收合（貼齊、密集收在裡面）")
	g._fp_tool_click("more")
	ok(g.fp_more, "點「工具」展開")
	g._fp_tool_click("more")
	ok(not g.fp_more, "再點收回")
	var snap0: bool = g.fp_snap
	g._fp_tool_click("snap")
	ok(g.fp_snap != snap0, "收進去的開關照樣能切")
	# 卡上的 ? 進同一組：10 個 ? ＝ 1 個控制
	g._btns.clear()
	g.btn_group = "cards"
	for k in 10:
		g._btns.append({"r": Rect2(), "cb": func(): pass, "en": true, "group": g.btn_group})
	g.btn_group = ""
	g._btns.append({"r": Rect2(), "cb": func(): pass, "en": true, "group": ""})
	ok(g.click_count() == 2, "兵卡牌尺＝一個控制")
	g.free()
	var fp: String = FileAccess.get_file_as_string("res://scripts/ui/free_place.gd")
	ok(fp.find("btn_group = \"fp_tool\"") >= 0, "畫筆／直線／框選三選一＝一組")
	# 從真的滑鼠路徑（_mb_cmd）點在展開的紙卡上：不點穿到底下的部署區（Codex v150 cat04 #4）
	var g2 = GS.new()
	g2.state = g2.St.PLACE
	g2.overlay = ""
	g2.mode = g2.Mode.VS_AI
	g2.foe_card_r = Rect2(700, 120, 400, 300)
	g2.painting = false
	g2.drag_new = false
	g2._mb_cmd({"i": MOUSE_BUTTON_LEFT, "pressed": true, "pos": Vector2(800, 200)})
	ok(not g2.painting and not g2.drag_new and g2.drag_from.x < 0, "按在紙卡上：不開始塗兵／拖曳")
	g2.foe_tag_open = false
	ok(g2._deploy_tool("foe") and g2.foe_tag_open, "RT＋View（部署工具 foe）＝開合翻牌")
	g2._deploy_tool("foe")
	ok(not g2.foe_tag_open, "再按一次收回")
	g2.free()
	var gs: String = FileAccess.get_file_as_string("res://scripts/ui/game_screens.gd")
	ok(gs.find("ev.button_index == JOY_BUTTON_BACK and mode == Mode.VS_AI") >= 0, "手把 RT＋View 接到翻牌")
	# 從真實 _input 進入（輸入契約）：滑鼠在紙卡上按下＋放開＝什麼都不發生；在翻牌上放開＝開合
	var g3 = GS.new()
	g3.state = g3.St.PLACE
	g3.overlay = ""
	g3.mode = g3.Mode.VS_AI
	g3.shot_dir = ""
	g3.time = 10.0
	g3.foe_card_r = Rect2(560, 300, 200, 200)
	g3.foe_tag_r = Rect2(900, 100, 200, 48)
	g3.foe_tag_open = true
	g3._btns.clear()
	g3._btns.append({"r": g3.foe_tag_r, "cb": func(): g3.foe_tag_open = not g3.foe_tag_open, "en": true})
	g3._btns_gen = g3._gen
	for dn in [true, false]:
		g3._input(_im_ev("mouse", dn))   # (640, 400) 在紙卡上
	g3._process_cmds()
	ok(g3.foe_tag_open and not g3.painting and g3.drag_from.x < 0, "真實輸入：點在紙卡上不點穿、不收合")
	g3._btns_gen = g3._gen   # 下一幀重畫按鈕
	for dn in [true, false]:
		var e: InputEventMouseButton = _im_ev("mouse", dn)
		e.position = Vector2(950, 120)
		g3._input(e)
	g3._process_cmds()
	ok(not g3.foe_tag_open, "真實輸入：點翻牌＝收合")
	g3.free()

func test_settings_drawer_v150() -> void:
	var GS = load("res://scripts/ui/game_screens.gd")
	var g = GS.new()
	var bad_core: Array = []
	var bad_cover: Array = []
	for t in g.SET_TABS:
		g.settings_tab = t
		g.set_adv_open = false
		var core: Array = g._settings_rows()
		g.set_adv_open = true
		var adv: Array = g._settings_rows()
		var all: Array = g._settings_rows_all()
		if core.size() > 5 or core.is_empty():
			bad_core.append(t)
		if core.size() + adv.size() != all.size():
			bad_cover.append(t)
		for a in adv:
			ok(a[0] in g.SET_ADV[t], "抽屜裡的列都登記在 SET_ADV（%s）" % a[0])
	ok(bad_core.is_empty(), "每頁常用 1～5 列（方案 §1.3）", str(bad_core))
	ok(bad_cover.is_empty(), "常用＋進階＝完整清單（沒有設定被藏丟）", str(bad_cover))
	g.settings_tab = 2
	g.set_adv_open = true
	g._settings_close()
	ok(not g.set_adv_open, "關掉設定：下次打開回到常用")
	# 真實按鍵路徑：焦點在抽屜鈕上按 Enter／A → 打開、焦點留在抽屜鈕（回到常用）上，不會落到「返回」（Codex v150 cat05 #1）
	var g4 = GS.new()
	g4.overlay = "settings"
	g4.settings_tab = 0
	g4.set_adv_open = false
	g4._btns.clear()
	g4._btns.append({"r": Rect2(346, 470, 548, 44), "cb": func(): g4._set_adv_toggle(), "en": true})
	g4._btns.append({"r": Rect2(630, 662, 160, 44), "cb": func(): g4.overlay = "", "en": true})
	g4._btns_gen = g4._gen
	g4._focus = 0
	g4._do_click(Vector2(600, 490))
	ok(g4.set_adv_open and g4.set_adv_focus and g4._btns.is_empty(), "按抽屜鈕：打開、舊按鈕失效、下一幀焦點回抽屜鈕")
	g4._do_click(Vector2(700, 680))
	ok(g4.overlay == "settings", "同一幀再點：不會按到舊的「返回」")
	g4._btns.append({"r": Rect2(136, 166, 190, 48), "cb": func(): pass, "en": true})   # 重畫：分頁布標先畫
	g4._take_adv_focus()
	ok(g4._focus == 1 and not g4.set_adv_focus, "重畫時焦點落在抽屜鈕（畫在分頁之後的那一顆），只做一次")
	g4.vol_rails["master"] = Rect2(690, 200, 140, 20)
	g4._set_adv_toggle()
	ok(g4.vol_rails.is_empty(), "開合抽屜：舊音量木軌失效")
	g4.settings_item = "set_mono"
	g4._settings_close()
	ok(g4.settings_item == "" and not g4.set_adv_open, "關掉設定：說明與抽屜都清掉")
	g4.free()
	var gm: String = FileAccess.get_file_as_string("res://scripts/ui/screens/game_menus.gd")
	ok(gm.find("settings_item = \"\"; set_adv_open = false") >= 0, "切分頁：抽屜收回")
	ok(gm.find("screen_register(\"settings\"") >= 0, "設定登記主動作")
	var LR = load("res://scripts/ui/layout_rules.gd")
	ok("settings" in LR.R14_ENFORCE, "設定轉成已改造類別（R14 上限 10，超標＝失敗）")
	# 抽屜裡改過的項目：抽屜鈕要能看出來
	var Save = load("res://scripts/game/save.gd")
	var keep = Save.s("mono")
	g.settings_tab = 2
	for v in [true, false]:
		Save.settings["mono"] = v
		if g.set_changed("set_mono"):
			ok(bool(g._settings_adv_info()[1]), "抽屜裡改過的項目會在抽屜鈕上亮點")
	Save.settings["mono"] = keep
	g.free()

func test_typography_v150() -> void:
	var GS = load("res://scripts/ui/game_screens.gd")
	ok(GS.backup_label("progress_20261110_120000.json") == "2026/11/10 12:00", "備份檔名顯示成日期時間（不像除錯字串）", GS.backup_label("progress_20261110_120000.json"))
	ok(GS.backup_label("user://x/shot_progress_20260102_090500.json") == "2026/01/02 09:05", "有前綴、有路徑也讀得出來")
	ok(GS.backup_label("progress_weird.json") == "progress_weird", "讀不出日期：照原檔名（不吞掉）")
	ok(GS.backup_label("progress_20261340_256199.json") == "progress_20261340_256199", "日期時間超出範圍：照原檔名（不顯示假日期）")
	ok(GS.backup_label("progress_20260230_120000.json") == "progress_20260230_120000" and GS.backup_label("progress_20260229_120000.json") == "progress_20260229_120000" and GS.backup_label("progress_20280229_120000.json") == "2028/02/29 12:00", "2 月依閏年檢查")
	var labs: Array = GS.backup_labels(["progress_20261110_120000.json", "progress_20261110_120045.json", "progress_20261109_080000.json"])
	ok(labs[0] == "2026/11/10 12:00:00" and labs[1] == "2026/11/10 12:00:45" and labs[2] == "2026/11/09 08:00", "同一分鐘兩份：都帶秒，分得出來", str(labs))
	var gp: String = FileAccess.get_file_as_string("res://scripts/ui/screens/game_place.gd")
	ok(gp.find("draw_rect(Rect2(x - 4, y - 2, bw + 8, bh + 6)") < 0 and gp.find("if _width(blurb, bsz) <= room:") >= 0, "擺陣資訊帶只有一行：定位放不下就不放（不再折行壓進棋盤）")
	var gr: String = FileAccess.get_file_as_string("res://scripts/ui/screens/game_result.gd")
	ok(gr.find("L.t(\"fingerprint\", [sim.fingerprint.substr(0, 12)])") < 0 and gr.find("DisplayServer.clipboard_set(fpc)") >= 0, "校驗碼收進「複製」小鈕（仍複製完整碼）")
	var gv: String = FileAccess.get_file_as_string("res://scripts/ui/screens/game_v16.gd")
	ok(gv.find("_ink(Color.WHITE) if last_btn_paper else Color.WHITE") >= 0, "異變實驗室：紙面鈕用墨字")

func test_polish_v150() -> void:
	var gv: String = FileAccess.get_file_as_string("res://scripts/ui/screens/game_v16.gd")
	ok(gv.find("_btn(br, label, func(): overlay = \"\"; _pick_puzzle(pid, false))") >= 0, "老闆出題三題都是次鈕（不再三條亮紅主鈕）")
	var bu: String = FileAccess.get_file_as_string("res://scripts/ui/battle/battle_units.gd")
	ok(bu.find("if R.grow(40).has_point(sp):") >= 0 and bu.find("draw_rect(R, Color(TH_WOOD_D, 0.94))") < 0, "暫停資料卡改米紙浮籤，所選兵在右上時移到左上")

func test_crowded_pages_v150() -> void:
	var GS = load("res://scripts/ui/game_screens.gd")
	ok(GS.TRIAL_PAGE == 8 and ceili(GS.TRIALS.size() / float(GS.TRIAL_PAGE)) == 4, "試煉每頁 8 關、30 關分 4 頁", str(GS.TRIAL_PAGE))
	ok(GS.ACH_PAGE <= 12, "徽章櫃每頁 ≤12 個（方案 §1.6：非按鈕格 ≤12）")
	var LR = load("res://scripts/ui/layout_rules.gd")
	ok("profile" in LR.R14_ENFORCE and int(LR.R14_LIMITS["profile"]) == 6, "戰績轉成已改造類別（上限 6）")
	var gm: String = FileAccess.get_file_as_string("res://scripts/ui/screens/game_modes.gd")
	ok(gm.find("0: _draw_pf_overview(") >= 0 and gm.find("1: _draw_pf_units(") >= 0 and gm.find("2: _draw_pf_badges(") >= 0, "戰績分三頁籤：總覽／兵種／成就")
	var gr: String = FileAccess.get_file_as_string("res://scripts/ui/screens/game_result.gd")
	ok(gr.find("set(\"trial_page\", tid / int(get(\"TRIAL_PAGE\")))") >= 0, "從結果返回試煉：停在這一關所在的頁")
	ok(gm.find("_btns.append({\"r\": ar, \"cb\": func(): pass") < 0, "成就不再是看不見的焦點目標（條件直接寫在牌子上）")
	var g = GS.new()
	g.pf_tab = 2
	g.pf_ach_page = 3
	ok(g.pf_tab == 2, "頁籤狀態可設")
	g.free()

func test_lobby_fold_v150() -> void:
	var GS = load("res://scripts/ui/game_screens.gd")
	var g = GS.new()
	var all := 0
	for t in g.D.total():
		all |= 1 << t
	var s0: String = g.pool_summary(all)
	ok(s0.find(str(g.D.total())) >= 0, "卡池唯讀摘要：總種數", s0)
	ok(g.pool_summary(0).find("0") >= 0, "空卡池也有摘要（不當掉）")
	g.free()
	var lv: String = FileAccess.get_file_as_string("res://scripts/ui/lobby_view.gd")
	for grp in ["pool_side", "pool_filter", "pool_cards", "pool_decks", "lb_subtabs"]:
		ok(lv.find("btn_group = \"%s\"" % grp) >= 0, "大廳折頁 R14 分組：%s" % grp)

func test_title_notes_v150() -> void:
	var gv: String = FileAccess.get_file_as_string("res://scripts/ui/screens/game_v16.gd")
	ok(gv.find("var NS_RECT := Rect2(830, 20,") >= 0 and gv.find("else 20.0)") >= 0, "標題的建議下一步、最近玩整組在示範戰場框之上（不壓框；§13）")

func test_lobby_fold_menu_v150() -> void:
	var lv: String = FileAccess.get_file_as_string("res://scripts/ui/lobby_view.gd")
	ok(lv.find("var acts := [[\"lb_copy\", _lobby_copy_code], [\"lb_save\", _lobby_save_preset], [\"lb_paste\", _lobby_paste_code]]") >= 0, "複製／存成預設／貼上規則搬進「我的預設」選單")
	ok(lv.find("_btn(Rect2(458, by, 150, 48), L.t(\"lb_copy\")") < 0, "折頁底列不再有代碼與存預設（只剩收起＋開戰）")
	for grp in ["cmdr_cards", "cmd_cards", "sb_units", "sb_skills", "cmd_side"]:
		ok(lv.find("btn_group = \"%s\"" % grp) >= 0, "折頁 R14 分組：%s" % grp)

func test_loss_jump_v150() -> void:
	var bv: String = FileAccess.get_file_as_string("res://scripts/ui/battle_view.gd")
	ok(bv.find("first_fall = [view.tick, int(ev[\"id\"])]") >= 0 and bv.find("first_fall = [-1, -1]") >= 0, "藍方第一隻倒下：逐 tick 事件記錄、每場重設")
	var rv: String = FileAccess.get_file_as_string("res://scripts/ui/replay_view.gd")
	ok(rv.find("first_fall = [-1, -1]") >= 0 and rv.find("first_fall = [sim.tick, int(ev[\"id\"])]") >= 0, "跳轉時重設、快轉時重建（順播與跳轉一致）")
	ok(rv.find("\"first_fall\": first_fall.duplicate()") >= 0 and rv.find("first_fall = replay_snap.get(\"first_fall\"") >= 0, "進重播前存、返回結果頁還原")
	var gr: String = FileAccess.get_file_as_string("res://scripts/ui/screens/game_result.gd")
	ok(gr.find("call(\"_replay_from\", maxi(0, int(ff[0]) - 40)); follow_id = int(ff[1])") >= 0, "敗因卡：跳到倒下前 2 秒、鏡頭跟著那一隻")
	var GS = load("res://scripts/ui/game_screens.gd")
	var g = GS.new()
	ok(g.first_fall == [-1, -1], "預設沒有倒下紀錄（敗因卡不畫按鈕）")
	g.free()

func test_paint_wells_v150() -> void:
	var gp: String = FileAccess.get_file_as_string("res://scripts/ui/screens/game_playroom.gd")
	ok(gp.find("func _paint_well(") >= 0 and gp.find("_paint_well(c, 15.0, Art.PAINTS[row][k])") >= 0, "塗裝室底漆色票＝水彩凹槽（§13）")

func test_lobby_fold_r14_v150() -> void:
	var lv: String = FileAccess.get_file_as_string("res://scripts/ui/lobby_view.gd")
	ok(lv.find("const FOLD_ROWS := 3") >= 0 and lv.find("btn_group = \"rows_pager\"") >= 0, "折頁規則列一頁 3 列、翻頁算一個控制")
	ok(lv.find("L.t(\"lb_reset\")") < 0, "「重置回標準」拿掉（和頂緣「標準」紙籤同一件事）")
	ok(lv.find("\"cmd_params\")") >= 0 and lv.find("btn_group = \"sb_params\"") >= 0, "所選物件的參數條＝一個控制")
	ok(lv.find("LOBBY_TABS[lobby_tab] == \"lb_tab_cmd\" and lobby_r.cmd_on") >= 0, "折頁豁免只剩軍令頁開啟時")

## 1.6.0 B02（P2.2）：紙面字色規則＋偵測——淺紙面按鈕上的亮字由版面檢查擋下（偵測器靠畫的時候登記的紙面範圍）
func test_paper_ink_v1600() -> void:
	var UB = load("res://scripts/ui/ui_base.gd")
	var PAL = load("res://scripts/ui/palette.gd")
	for c in [Color.WHITE, Color("#f0c040"), Color(1, 0.75, 0.7)]:
		ok(UB._ink(c).get_luminance() < 0.45, "紙上墨色：%s 壓成深色" % c.to_html(false))
	var ub: String = FileAccess.get_file_as_string("res://scripts/ui/ui_base.gd")
	ok(ub.find("probe_faces.append([rd, last_btn_paper])") >= 0 and ub.find("\"fz\": probe_faces.size()") >= 0, "按鈕面依繪製順序登記、字記下自己畫在第幾層之後")
	var gs: String = FileAccess.get_file_as_string("res://scripts/ui/game_screens.gd")
	ok(gs.find("probe_faces.clear()") >= 0, "每幀清空底面登記")
	var dm: String = FileAccess.get_file_as_string("res://tools/dev_main.gd")
	ok(dm.find("LayoutRules.paper_white(") >= 0 and dm.find("\"淺紙白字\"") >= 0, "版面檢查接上淺紙白字判定")
	ok(ub.find("probe_faces.append([r, kind == \"paper\"])") >= 0 and ub.find("probe_faces.append([r, false])") >= 0, "直接畫的紙面、木面、深色平塗框也登記")
	var LR = load("res://scripts/ui/layout_rules.gd")
	var faces := [[Rect2(100, 100, 200, 60), true], [Rect2(250, 100, 50, 30), false], [Rect2(110, 100, 60, 60), true]]
	ok(LR.paper_white(1.0, false, false, Vector2(150, 130), faces, 3), "反例：白字在紙面上＝違規")
	ok(not LR.paper_white(0.05, false, false, Vector2(150, 130), faces, 3), "墨字在紙面上不算")
	ok(not LR.paper_white(1.0, true, false, Vector2(150, 130), faces, 3), "停用字不算（停用樣式另有規則）")
	ok(not LR.paper_white(1.0, false, true, Vector2(150, 130), faces, 3), "輸入欄字不算（欄位底是深色）")
	ok(not LR.paper_white(1.0, false, false, Vector2(150, 200), faces, 3), "沒有任何底面登記的地方不算")
	ok(not LR.paper_white(1.0, false, false, Vector2(270, 110), faces, 3), "紙面上又蓋深色框：框裡的白字不算")
	ok(LR.paper_white(1.0, false, false, Vector2(240, 110), faces, 3), "深色框旁邊的紙面照查")
	ok(not LR.paper_white(1.0, false, false, Vector2(270, 110), [[Rect2(250, 100, 50, 30), false], [Rect2(100, 100, 200, 60), true]], 1), "字畫在紙面之前（紙面後來才蓋上）：照當時那一層（深色）判")
	ok(LR.paper_white(1.0, false, false, Vector2(270, 110), [[Rect2(250, 100, 50, 30), false], [Rect2(100, 100, 200, 60), true]], 2), "深色框在下、紙面在上：照最上層（紙面）判")
	var fixes := {
		"res://scripts/ui/screens/game_menus.gd": "(_ink(Color.WHITE) if pp else Color.WHITE) if on else TXT_DIM",
		"res://scripts/ui/replay_view.gd": "(_ink(ACCENT) if pp else ACCENT) if can",
		"res://scripts/ui/screens/game_modes.gd": "(_ink(ACCENT) if pp else ACCENT) if rl_sel.x >= 0",
		"res://scripts/ui/screens/game_place.gd": "probe_faces.append([tr, false])",
	}
	for f in fixes:
		ok(FileAccess.get_file_as_string(f).find(fixes[f]) >= 0, "%s：紙面字修正在位" % f.get_file())
	var gv: String = FileAccess.get_file_as_string("res://scripts/ui/screens/game_v16.gd")
	ok(gv.find("_ink_mode = last_btn_paper   # 1.6.0 B02") >= 0 and gv.find("var pp := last_btn_paper   # 1.6.0 B02") >= 0, "導覽列、一陣三考卡片用墨字")
	ok(PAL != null, "色票載入")

## 1.6.0 B03（S2；P1.1～P1.3）：桌位表單一來源、主材質、接觸影、結果 HUD 收合
func test_table_seats_v1600() -> void:
	var TS = load("res://scripts/ui/table_seats.gd")
	var PAL = load("res://scripts/ui/palette.gd")
	var UB = load("res://scripts/ui/ui_base.gd")
	ok(TS.BOARD.position == UB.ORIGIN and TS.BOARD.size == UB.FIELD, "桌位表的盤面＝ORIGIN、FIELD（同一個盤）")
	var sl: Dictionary = TS.right_slots()
	ok(sl.has("owner") and sl.has("cup") and sl.has("clock"), "右緣三槽：上老闆、中茶杯、下棋鐘")
	var fr: Rect2 = TS.frame_rect()
	for k in sl:
		var r: Rect2 = sl[k]
		ok(r.position.x - fr.end.x >= TS.SLOT_GAP and r.end.x <= TS.SCREEN.x and r.size.x >= TS.SLOT_W_MIN and r.size.x <= TS.SLOT_W, "槽 %s：距盤框 ≥16、不出螢幕、寬 88～104" % k)
	ok(not (sl["owner"] as Rect2).intersects(sl["cup"]) and not (sl["cup"] as Rect2).intersects(sl["clock"]), "三槽不重疊")
	ok(TS.right_slots(Rect2(100, 100, 1100, 576)).is_empty(), "盤太寬、桌緣放不下槽＝回空（呼叫端照 HIDE_ORDER 退）")
	var rep: Dictionary = TS.spec_report()
	ok(not bool(rep["board_ok"]) and float(rep["edge_r"]) == 112.0, "規格符合度如實回報（盤含框 1056 > 1040、右桌緣 112；B06 裁決不縮盤：盤面 1024＝16 格×64，縮盤要改格寬＝全部戰鬥座標）")
	var nr: Rect2 = TS.result_note_rect()
	ok(nr.end.x <= TS.RESULT_PAPER.position.x - TS.SLOT_GAP and nr.size.y <= TS.RESULT_NOTE_MAX.y, "局內便條在結果紙外左下、不壓紙")
	for m in [PAL.MAT_WALNUT, PAL.MAT_PAPER, PAL.MAT_WAX, PAL.MAT_CHALK, PAL.MAT_BRASS]:
		ok(m.size() == 3, "主材質三色（Base／Shadow／Highlight）")
	ok(PAL.CONTACT_OFF == Vector2(3, 4) and PAL.CONTACT_FEATHER == 6.0 and PAL.CONTACT_A >= 0.35 and PAL.CONTACT_A <= 0.45, "接觸影 (3,4)、羽化 6、α 0.35～0.45")
	var ub: String = FileAccess.get_file_as_string("res://scripts/ui/ui_base.gd")
	ok(ub.find("func _contact_shadow(") >= 0 and ub.find("Seats.right_slots()") >= 0 and ub.find("Vector2(1236, 432)") < 0, "接觸影共用函式；茶杯、沙漏照桌位表（不再寫死座標）")
	ok(ub.find("if int(get(\"state\")) != St.TITLE and str(get(\"overlay\")) == \"\":") >= 0, "有棋盤的頁、沒開疊層時盤外桌面壓暗")
	# 肖像鈕：從真實 _input 進入（輸入契約）——點鈕＝開合、點展開紙卡不點穿不收合（Codex B03 r1 #6）
	var GS = load("res://scripts/ui/game_screens.gd")
	var g = GS.new()
	g.state = g.St.PLACE
	g.overlay = ""
	g.mode = g.Mode.VS_AI
	g.shot_dir = ""
	g.time = 10.0
	var slot: Rect2 = sl["owner"]
	var cw := minf(384.0 - 24.0, 420.0)   # 敵區寬 384（16×64 的右 6 欄）
	g.foe_card_r = Rect2(slot.position.x - cw - 10.0, slot.position.y, cw, 300)
	ok(g.foe_card_r.position.x >= TS.BOARD.position.x and g.foe_card_r.end.x < slot.position.x, "展開紙卡浮在槽左邊、不出盤左緣、不蓋到槽")
	g.foe_tag_r = slot
	g.foe_tag_open = true
	g._btns.clear()
	g._btns.append({"r": slot, "cb": func(): g.foe_tag_open = not g.foe_tag_open, "en": true})
	g._btns_gen = g._gen
	for dn in [true, false]:
		var e0: InputEventMouseButton = _im_ev("mouse", dn)
		e0.position = g.foe_card_r.get_center()
		g._input(e0)
	g._process_cmds()
	ok(g.foe_tag_open and not g.painting and g.drag_from.x < 0, "真實輸入：點在展開紙卡上不點穿、不收合")
	g._btns_gen = g._gen
	for dn in [true, false]:
		var e1: InputEventMouseButton = _im_ev("mouse", dn)
		e1.position = slot.get_center()
		g._input(e1)
	g._process_cmds()
	ok(not g.foe_tag_open, "真實輸入：點右緣肖像鈕＝收合")
	# 手把 RT＋View：從真實 _input 進（扳機軸走 Input 狀態、View 鍵走 _input → 指令佇列 → _deploy_tool；Codex B03 r2 #3）
	g.foe_tag_open = false
	var rt := InputEventJoypadMotion.new()
	rt.device = 0
	rt.axis = JOY_AXIS_TRIGGER_RIGHT
	rt.axis_value = 1.0
	Input.parse_input_event(rt)
	Input.flush_buffered_events()
	var vb := InputEventJoypadButton.new()
	vb.device = 0
	vb.button_index = JOY_BUTTON_BACK
	vb.pressed = true
	g._input(vb)
	g._process_cmds()
	ok(g.foe_tag_open, "真實輸入：按住 RT＋View＝展開翻牌")
	vb.pressed = false
	g._input(vb)
	vb.pressed = true
	g._input(vb)
	g._process_cmds()
	ok(not g.foe_tag_open, "再按一次 RT＋View＝收合")
	rt.axis_value = 0.0
	Input.parse_input_event(rt)
	Input.flush_buffered_events()
	g.free()
	var gp: String = FileAccess.get_file_as_string("res://scripts/ui/screens/game_place.gd")
	ok(gp.find("_draw_foe_slot(slots[\"owner\"], zone)") >= 0 and gp.find("func _draw_foe_card(") >= 0, "敵情翻牌收合成右緣上槽肖像鈕、展開才浮出紙卡")
	var bv: String = FileAccess.get_file_as_string("res://scripts/ui/battle_view.gd")
	ok(bv.find("if state == St.RESULT:\n\t\treturn   # 1.6.0 B03") >= 0, "結果頁背後戰力尺、棋鐘收合")
	# 暗紙深墨：對結果紙最暗取樣點（#a69178）≥4.5:1；淺紙照舊（ink_deep 關）
	var DM = load("res://tools/dev_main.gd")
	var dark_paper := Color("#a69178")
	UB.ink_deep = true
	for c in [Color("#ffd166"), Color("#7ddc6a"), Color("#ff6b6b"), Color("#45acff"), Color("#2f80ff"), Color("#1c4566"), Color.WHITE]:
		ok(DM.contrast(UB._ink(c), dark_paper) >= 4.5, "深墨：%s 在暗紙上 ≥4.5:1" % c.to_html(false))
	UB.ink_deep = false
	ok(UB._ink(Color("#1c4566")) == Color("#1c4566"), "淺紙（一般）中間調的深隊色不動（深墨才壓）")
	var gsrc: String = FileAccess.get_file_as_string("res://scripts/ui/game_screens.gd")
	ok(gsrc.find("ink_deep = desk_paper") >= 0 and gsrc.find("_draw_inner()\n\tink_deep = false\n\tpaper_tone = Color.WHITE") >= 0, "深墨與桌燈紙：B06 起全站（每幀畫完關掉）")
	var gr: String = FileAccess.get_file_as_string("res://scripts/ui/screens/game_result.gd")
	ok(gr.find("_mat_box(r, \"card2\")") >= 0 and gr.find("_contact_shadow(r, 4.0, 0.45)") >= 0, "結果紙：桌燈色調（全站 paper_tone）＋共用接觸影")


## 1.6.0 B06：全站桌燈紙（P1.3）、結果頁便條釘位（P1.5）、地形微縮光向（P1.4）、地圖名刻字位置
func test_desk_table_v1600() -> void:
	var TS = load("res://scripts/ui/table_seats.gd")
	var PAL = load("res://scripts/ui/palette.gd")
	var Sv = load("res://scripts/game/save.gd")
	# 全站桌燈紙：紙與卡紙乘 paper_tone；標題頁本身（沒疊層）、簡化介面不乘
	var ub: String = FileAccess.get_file_as_string("res://scripts/ui/ui_base.gd")
	ok(ub.find("if kind == \"paper\":\n\t\ttint = tint * ((PAL.PAPER_BOOK_TONE_TEX if paper_book else PAL.PAPER_DESK_TONE_TEX) if paper_tone != Color.WHITE") >= 0 and ub.find("if kind.begins_with(\"card\"):\n\t\ttint = tint * paper_tone") >= 0, "羊皮紙、卡紙都乘桌燈色調（大廳簿紙再暗一階，B04）")
	var gsrc: String = FileAccess.get_file_as_string("res://scripts/ui/game_screens.gd")
	ok(gsrc.find("not bool(Save.s(\"plain_ui\")) and not (state == St.TITLE and overlay == \"\") and overlay != \"first_run\" and not no_desk_paper") >= 0, "桌燈紙的範圍：簡化介面、標題頁本身、首開便條（B05 新紙）除外（大廳 B04 起是簿紙）")
	var dark_paper: Color = Color("#efe4cc") * PAL.PAPER_DESK_TONE
	ok(load("res://tools/dev_main.gd").contrast(Color("#2a1e15"), dark_paper) >= 4.5, "深墨字對桌燈紙 ≥4.5:1")
	# 地形微縮：地塊烘焙的光向＝全站接觸影方向
	var MA = load("res://scripts/ui/map_art.gd")
	ok(MA._Painter.LIGHT_DX == PAL.CONTACT_OFF.x, "地形落影的光向＝CONTACT_OFF（同一盞左上主光）")
	# 地形語意遮罩（Codex B06 r1 #1）：全部真實地圖×三種大小×兩種視角，落影只落在可走格、不染任何牆格（通行判讀不變）
	var MD = load("res://scripts/core/map_defs.gd")
	var bad := 0
	var n_sh := 0
	for mid in range(1, MD.MAPS.size()):
		for sz in 3:
			var tt = MD.terrain(mid, sz)
			if tt == null:
				continue
			for tl in [false, true]:
				var pp = MA._Painter.new()
				pp.t = tt
				pp.kind = str(MD.MAPS[mid]["biome"])
				pp.tilt = tl
				var Q := 32.0
				for r in tt.m:
					for c in tt.n:
						for sh in [pp.shadow_south(c, r, Q), pp.shadow_east(c, r, Q)]:
							if sh.size.x <= 0.0:
								continue
							n_sh += 1
							for r2 in range(maxi(0, r - 1), mini(tt.m, r + 3)):
								for c2 in range(maxi(0, c - 1), mini(tt.n, c + 3)):
									if tt.grid[c2 + r2 * tt.n] == tt.BLOCK and sh.intersects(Rect2(Vector2(c2, r2) * Q, Vector2(Q, Q))):
										bad += 1
										if bad <= 3:
											print("  影子壓到牆格：map %d size %d (%d,%d)→(%d,%d) %s" % [mid, sz, c, r, c2, r2, sh])
				pp.free()
	ok(n_sh > 200 and bad == 0, "地形落影 %d 塊、壓到牆格 %d（要 0）" % [n_sh, bad])
	# 真實地圖沒有「南鄰空、東南是牆」的形狀：人造一個，驗往右偏的落影會裁掉偏進東南牆格的那段
	var t0 = MD.terrain(1, 1)
	var fake := {"n": 3, "m": 3, "BLOCK": t0.BLOCK, "FREE": t0.FREE, "grid": [t0.BLOCK, t0.FREE, t0.FREE, t0.FREE, t0.BLOCK, t0.FREE, t0.FREE, t0.FREE, t0.FREE]}
	var pf = MA._Painter.new()
	pf.t = fake
	pf.kind = "ice"
	var ss: Rect2 = pf.shadow_south(0, 0, 32.0)
	ok(ss.size.x > 0.0 and not ss.intersects(Rect2(32, 32, 32, 32)), "南影右偏遇到東南牆格＝裁掉（%s）" % ss)
	pf.free()
	var bu: String = FileAccess.get_file_as_string("res://scripts/ui/battle/battle_units.gd")
	ok(bu.find("\"canyon\":   # 小仙人掌") < 0 and bu.find("\"canyon\":   # 1.6.0 B06：小陶罐") >= 0, "峽谷桌緣的小仙人掌（像浮著的十字）換成有接觸影的小陶罐")
	ok(bu.find("fld_map and state != St.PLACE:") >= 0, "擺陣不刻地圖名（上框被資訊列蓋、下框只露 16px 會壓到卡列）")
	# 便條釘位：從真實 _input 進入
	var GS = load("res://scripts/ui/game_screens.gd")
	var g = GS.new()
	g.sfx = FakeSfx.new()
	g._load_fonts()
	g.time = 10.0
	g.mode = g.Mode.VS_AI
	g.state = g.St.RESULT
	g.result_t = 0.0   # 結果頁開了 10 秒：宣紙戰報早演完（不然點擊是「跳過演出」）
	g.overlay = ""
	g.shot_dir = ""
	g.layout_probe = false
	var keep_seen = Sv.data.get("seen", null)
	var keep_lock = Sv.data_locked
	var keep_ts = Sv.settings.get("text_scale", 100)
	Sv.data["seen"] = []
	for sc in [100, 150]:
		Sv.settings["text_scale"] = sc
		var lay: Dictionary = g._note_pin_layout()
		var R: Rect2 = lay["r"]
		ok(R.end.x <= TS.RESULT_PAPER.position.x - TS.SLOT_GAP and R.position.x >= TS.SLOT_GAP, "%d%%：便條在結果紙外左邊桌緣、不壓紙" % sc)
		ok(R.end.y == TS.RESULT_PAPER.end.y and R.position.y >= TS.RESULT_PAPER.position.y, "%d%%：下緣對齊紙下緣、往上撐不出桌" % sc)
		ok(R.encloses(lay["btn"]), "%d%%：打開鈕在便條裡" % sc)
		if sc == 100:
			ok(R.size.y <= TS.RESULT_NOTE_MAX.y, "100%：不超過 120 高（方案 §1）")
	Sv.settings["text_scale"] = keep_ts
	ok(g._note_pin_shown("result"), "第一次看結果：便條釘在桌緣（不再自動蓋在紙上）")
	ok(g.overlay == "", "沒有自動跳疊層")
	var lay2: Dictionary = g._note_pin_layout()
	g._btns.clear()
	g._btns.append({"r": lay2["btn"], "cb": g._note_pin_open.bind("result"), "en": true})
	g._update_gen()   # 畫面世代先對上結果頁（不然佇列裡的點擊會當成過期丟掉）
	g._btns_gen = g._gen
	for dn in [true, false]:
		var e0: InputEventMouseButton = _im_ev("mouse", dn)
		e0.position = (lay2["btn"] as Rect2).get_center()
		g._input(e0)
	g._process_cmds()
	ok(g.overlay == "boss_note" and g.note_key == "result", "真實輸入：點「打開看」＝展開全文便條")
	Sv.data_locked = true
	g._key(KEY_ESCAPE)
	Sv.data_locked = keep_lock
	ok(g.overlay == "" and "note_result" in Sv.data["seen"], "Esc＝知道了：關掉並記住")
	ok(not g._note_pin_shown("result"), "看過就不再釘")
	Sv.data["seen"] = []
	# 手把：焦點在「打開看」上按 A（真實 _input → 指令佇列 → Enter → 焦點按鈕）
	g._focus = 0
	g._update_gen()
	g._btns_gen = g._gen
	for dn in [true, false]:
		var ja := InputEventJoypadButton.new()
		ja.device = 0
		ja.button_index = JOY_BUTTON_A
		ja.pressed = dn
		g._input(ja)
	g._process_cmds()
	ok(g.overlay == "boss_note" and g.note_key == "result", "真實輸入：手把 A＝打開便條")
	g.overlay = ""
	g.shot_dir = "x"
	ok(not g._note_pin_shown("result"), "截圖流程不釘（專拍用 note_pin_force）")
	g.note_pin_force = true
	ok(g._note_pin_shown("result"), "專拍：強制釘")
	g.overlay = "pause"
	ok(not g._note_pin_shown("result"), "開著疊層時不釘")
	if keep_seen == null:
		Sv.data.erase("seen")
	else:
		Sv.data["seen"] = keep_seen
	g.free()


## 1.6.0 B04（S1；P2.4、P2.1、英文頁籤縮寫）挑戰簿：簿紙色調在 45～65、暗木框、木撥片、英文大字級頁籤縮寫、
## 打開大廳焦點就在主鈕（手把 ≤3 步開戰；真畫面走查是截圖流程的 LOBBYPAD）、IN-160-01（返回、重開焦點恢復、同幀第二輸入）。
func test_lobby_book_v1600() -> void:
	var PAL = load("res://scripts/ui/palette.gd")
	var lstar := func(c: Color) -> float:
		var lin := func(v: float) -> float:
			return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
		var y: float = 0.2126 * lin.call(c.r) + 0.7152 * lin.call(c.g) + 0.0722 * lin.call(c.b)
		return 116.0 * pow(y, 1.0 / 3.0) - 16.0 if y > 0.008856 else 903.3 * y
	var lf: float = lstar.call(PAL.BOOK_FLAT)
	ok(lf >= 45.0 and lf <= 65.0, "簿紙平塗色 L* %.1f 在 45～65（截圖實測中位 63.0）" % lf)
	ok(PAL.PAPER_BOOK_TONE_TEX.v < PAL.PAPER_DESK_TONE_TEX.v and PAL.BOOK_FLAT_A >= 0.5, "簿紙比桌燈紙暗一階、平塗層讓斑紋減半以上")
	ok(load("res://tools/dev_main.gd").contrast(Color("#2a1e15"), PAL.BOOK_FLAT) >= 4.5, "深墨字對簿紙 ≥4.5:1")
	ok(PAL.BOOK_FRAME_DIM > 0.0 and PAL.BOOK_FRAME_DIM <= 0.25, "暗木框壓暗 %.2f（截圖實測 L* 13.5）" % PAL.BOOK_FRAME_DIM)
	var gsrc: String = FileAccess.get_file_as_string("res://scripts/ui/game_screens.gd")
	ok(gsrc.find("paper_book = desk_paper and (overlay == \"lobby\" or note_ret == \"lobby\")") >= 0 and gsrc.find("paper_tone = Color.WHITE\n\tpaper_book = false") >= 0, "簿紙只在大廳、每幀畫完歸零")
	ok(gsrc.find("overlay != \"lobby\"") < 0, "大廳不再排除在桌燈紙之外（B06 留給本批的那條拿掉）")
	var lsrc: String = FileAccess.get_file_as_string("res://scripts/ui/lobby_view.gd")
	ok(lsrc.find("btn_cloth = \"tab_indigo\" if on else (\"\" if paper_book else \"tab_linen\")") >= 0, "未選中的頁籤是木撥片（選中仍是靛布＋書籤）")
	var GS = load("res://scripts/ui/game_screens.gd")
	var g = GS.new()
	g.sfx = FakeSfx.new()
	g._load_fonts()
	var LS = load("res://scripts/game/strings.gd")
	var Sv = load("res://scripts/game/save.gd")
	var keep_lang = LS.lang
	var keep_ts = Sv.settings.get("text_scale", 100)
	var tw_min: float = 154.0 - 6.0 - g.BM_SLOT
	var te: float = tw_min - 2.0 * (maxf(6.0, tw_min * 0.06) + 1.0)
	LS.lang = "en"
	Sv.settings["text_scale"] = 150
	var en_short: bool = g.tab_label("fantasy", te) == LS.t("lb_p_fantasy_short") and g.tab_label("single", te) == LS.t("lb_p_single_short")
	var one_line := true
	for id in ["standard", "classic5", "fantasy", "small", "big", "single"]:
		var lab: String = g.tab_label(id, te)
		one_line = one_line and g.wrap_lines(lab, g.fit(lab, g.tz("B"), te, true), te, true).size() == 1
	var dbg := []
	for id in ["standard", "classic5", "fantasy", "small", "big", "single"]:
		var lab2: String = g.tab_label(id, te)
		dbg.append("%s=%d" % [lab2, g.wrap_lines(lab2, g.fit(lab2, g.tz("B"), te, true), te, true).size()])
	ok(en_short and one_line and g.lobby_tab_h() == 68.0, "英文 150%：擠成兩行的頁籤改縮寫，六個頁籤都一行、頁籤不長高", "%s short=%s h=%s" % [dbg, en_short, g.lobby_tab_h()])
	Sv.settings["text_scale"] = 100
	ok(g.tab_label("fantasy", te) == LS.t("lb_p_fantasy"), "英文 100% 放得下就用全名")
	LS.lang = "zh_TW"
	Sv.settings["text_scale"] = 150
	ok(g.tab_label("single", te) == LS.t("lb_p_single"), "中文不縮寫")
	LS.lang = keep_lang
	Sv.settings["text_scale"] = keep_ts
	# 手把 ≤3 步：打開大廳焦點交給主鈕；第一步→第二步→開戰各一下 A
	g._open_lobby("ai")
	ok(g.overlay == "lobby" and g._lb_focus_main, "打開大廳焦點就在主鈕（下一步／開戰）")
	ok(3 - g.lobby_step <= 3, "從打開到開戰最多 3 下 A（第 %d 步起）" % g.lobby_step)
	# IN-160-01：返回後重開，焦點照樣回到主鈕（不留在舊索引）
	g._focus = 5
	g._key(KEY_ESCAPE)
	ok(g.overlay != "lobby", "大廳 B／Esc 返回")
	g._open_lobby("ai")
	ok(g._lb_focus_main, "重開大廳焦點恢復到主鈕")
	# 首次大廳便條關掉：焦點回到主鈕（Codex B04 r1 #1）
	g._lb_focus_main = false
	g.overlay = "boss_note"
	g.note_key = "lobby"
	g.note_ret = "lobby"
	g._close_boss_note()
	ok(g.overlay == "lobby" and g._lb_focus_main, "大廳便條關掉後焦點回主鈕")
	# 跨轉場（IN-160-01）：大廳滑入中按 A＝吃掉（跳過轉場），不會按到底下的按鈕、不換步
	g.time = 50.0
	g._go_title()
	g._open_lobby("ai")
	g.lobby_step = 0
	var fired := [false]
	g._btns.clear()
	g._btns.append({"r": Rect2(966, 700, 234, 48), "cb": func(): fired[0] = true, "en": true})
	g._btns_gen = g._gen
	g._focus = 0
	g.pad_mode = true
	g._ov_t = g.time   # 轉場起點（_process 偵測到疊層換了才設；這裡直接設成「剛打開」）
	var in_trans: bool = g.ov_trans_k() < 1.0
	for dn in [true, false]:
		var e := InputEventJoypadButton.new()
		e.button_index = JOY_BUTTON_A
		e.pressed = dn
		g._input(e)
	g._process_cmds()
	ok(in_trans and not fired[0] and g.lobby_step == 0, "大廳滑入轉場中按 A 不會落到按鈕（轉場中=%s）" % in_trans)
	ok(FileAccess.get_file_as_string("res://tools/dev_main.gd").find("print(\"LOBBYPAD \"") >= 0, "截圖流程有真畫面手把走查（對 AI、雙人 ≤3 步、同幀兩下只走一步、撥片切換、重開焦點）")
	g.free()


## 1.6.0 B05（S9；P8.1、P8.2）第一幕：首開入館便條 ≤35% 屏、不壓示範戰場；「開第一局」直達大廳確認步（冷啟到開戰 2 下，
## 真畫面點擊是截圖流程的 FIRSTRUN）；桌上三主牌＋「更多」抽屜（IN-160-02：停用、返回、手把）。
func test_first_act_v1600() -> void:
	var GS = load("res://scripts/ui/game_screens.gd")
	var g = GS.new()
	g.sfx = FakeSfx.new()
	g._load_fonts()
	var LS = load("res://scripts/game/strings.gd")
	var Sv = load("res://scripts/game/save.gd")
	var keep_lang = LS.lang
	var keep_ts = Sv.settings.get("text_scale", 100)
	var keep_fd = Sv.settings.get("first_done", false)
	var fz := 0.72
	var off := Vector2(1270.0 - (g.ORIGIN.x + g.FIELD.x) * fz, 400.0 - (g.ORIGIN.y + g.FIELD.y / 2.0) * fz)
	var field := Rect2(g.ORIGIN * fz + off, g.FIELD * fz)
	var worst := 0.0
	var hit := false
	for lg in ["zh_TW", "en", "zh_CN", "ja"]:
		LS.lang = lg
		for sc in [100, 125, 150]:
			Sv.settings["text_scale"] = sc
			var R: Rect2 = g.first_run_rect()
			worst = maxf(worst, R.get_area() / (1280.0 * 800.0))
			hit = hit or R.intersects(field) or R.end.y > 800.0 or R.position.y < 0.0
	LS.lang = keep_lang
	Sv.settings["text_scale"] = keep_ts
	ok(worst <= 0.35 and not hit, "首開便條四語三字級最大 %.1f%% 屏（≤35%%）、不壓示範戰場、不出畫面" % (worst * 100.0))
	g._first_battle()
	ok(g.overlay == "lobby" and g.lobby_step == 2 and bool(Sv.settings.get("first_done", false)), "開第一局：直接進對 AI 大廳的確認步（再按開戰＝冷啟 2 下）")
	Sv.settings["first_done"] = keep_fd
	g.overlay = ""
	g.home_more = false
	ok(g.home_plaques().size() == 4, "桌上三主牌＋更多（抽屜關著 4 塊）")
	(g.home_plaques()[3][3] as Callable).call()
	ok(g.home_more and g.home_plaques().size() == 6, "按更多＝抽屜打開，多出遊戲間、收藏")
	(g.home_plaques()[5][3] as Callable).call()
	ok(g.overlay == "hub_collect" and not g.home_more, "抽屜裡選收藏＝打開收藏、抽屜收起")
	g.overlay = ""
	g.state = g.St.TITLE
	g._home_more_set(true)
	var gen0: int = g._gen
	g._focus = 5
	g._key(KEY_ESCAPE)
	ok(not g.home_more and g.overlay == "", "返回（Esc／B）先收起抽屜")
	ok(g._gen != gen0 and g._focus == 3, "收抽屜換世代（舊按鈕作廢，同幀 B→A 點不到收起的項目）、焦點回到「更多」")
	var src0: String = FileAccess.get_file_as_string("res://scripts/ui/screens/game_menus.gd")
	ok(src0.find("btn_group = \"home_more\" if i >= 3 else \"\"") >= 0, "R14：更多＋抽屜兩塊算一個控制")
	var pq: Array = g.home_plaques()
	ok(not bool(pq[1][4]) and bool(pq[0][4]) and bool(pq[3][4]), "試玩版：遠征停用；對戰、更多照開（抽屜裡遊戲間停用照舊）")
	g.home_more = true
	ok(not bool(g.home_plaques()[4][4]), "試玩版：抽屜裡的遊戲間停用")
	g.home_more = false
	var src: String = FileAccess.get_file_as_string("res://tools/dev_main.gd")
	ok(src.find("print(\"FIRSTRUN \"") >= 0 and src.find("[4, \"playroom\", true], [5, \"hub_collect\", true]") >= 0, "截圖流程：冷啟點擊走查（FIRSTRUN）、手把走查涵蓋抽屜（PADWALK）")
	g.free()


## 1.6.0 B07（P2.3）英文 150% 重災頁改寫：圖鑑兵種定位最多兩行（頭像右邊 CX_TAG_W；原本最長的到三行）、標題副標、設定說明、
## 獎勵說明、出題台欄名在 150% 都一行；（母語未校對＝待驗，ledger 記）。P2.5 覆盤分「改動／讀結果」、出題分「編輯／驗證」。
func test_en150_rewrite_v1600() -> void:
	var GS = load("res://scripts/ui/game_screens.gd")
	var g = GS.new()
	g._load_fonts()
	var LS = load("res://scripts/game/strings.gd")
	var Sv = load("res://scripts/game/save.gd")
	var CX = load("res://scripts/game/codex_data.gd") if ResourceLoader.exists("res://scripts/game/codex_data.gd") else null
	var keep_lang = LS.lang
	var keep_ts = Sv.settings.get("text_scale", 100)
	LS.lang = "en"
	Sv.settings["text_scale"] = 150
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/codex.json"))
	var units: Array = raw.get("units", []) if raw.has("units") else []
	var bad: Array = []
	var n := 0
	for u in units:
		if u is Dictionary and u.has("role_en"):
			n += 1
			if g.wrap_lines(str(u["role_en"]), g.ts(15), g.CX_TAG_W).size() > 2:
				bad.append(str(u["role_en"]))
	ok(n >= 20 and bad.is_empty(), "圖鑑 %d 種兵的英文定位在 150%% 最多兩行（%d px；大字級時口號讓位）" % [n, int(g.CX_TAG_W)], str(bad))
	var one := func(k: String, size: int, w: float) -> bool:
		return g.wrap_lines(LS.t(k), size, w).size() == 1
	ok(one.call("subtitle", g.tz("S"), 420.0), "標題副標英文 150%% 一行（%s）" % LS.t("subtitle"))
	ok(one.call("set_hover_hint", g.tz("S"), 260.0) or g.wrap_lines(LS.t("set_hover_hint"), g.tz("S"), 260.0).size() <= 2, "設定說明欄提示短到兩行內")
	ok(LS.t("ed_you").length() <= 12 and LS.t("ed_foe").length() <= 14, "出題台欄名縮短（不再拆成兩行）")
	LS.lang = keep_lang
	Sv.settings["text_scale"] = keep_ts
	var rv: String = FileAccess.get_file_as_string("res://scripts/ui/replay_view.gd")
	ok(rv.find("var rv_tab := 0") >= 0 and rv.find("rv_tab = 1   # 1.6.0 B07：重算好了＝自動翻到「讀結果」") >= 0 and rv.find("rv_tab = 0   # 1.6.0 B07：打開覆盤在「改動」頁") >= 0, "覆盤分「改動／讀結果」：打開在改動、重算好翻到讀結果")
	var v16: String = FileAccess.get_file_as_string("res://scripts/ui/screens/game_v16.gd")
	ok(rv.count("if rv_tab != 0:\n\t\treturn   # 1.6.0 B07（Codex r1 #1）") == 4, "讀結果頁擋住四個改陣入口（格子、自由點擊、自由拖放、換兵種）")
	ok(rv.find("rv_focus_main = true   # 焦點交給讀結果頁") >= 0 and v16.find("ed_focus_main = true, ready, true)") >= 0, "翻頁／切段後焦點交給新頁主鈕（手把不落到停用棋盤）")
	ok(v16.find("var ed_tab := 0") >= 0 and v16.find("for t in (20 if ed_tab == 0 else 0):") >= 0 and v16.find("\"en\": ed_tab == 0, \"grid\": true") >= 0, "出題分「編輯／驗證」：驗證段收起兵種盤、棋盤只看不改")
	g.free()

## 1.6.0 B20（P12.3、P12.4）器物聲（翻紙、蓋印；合成佔位、真錄音同名替換）＋連勝桌況（盤外燈光收窄、木籌，盤內不動）。
func test_desk_sound_v1600() -> void:
	var UB = load("res://scripts/ui/ui_base.gd")
	var SF = load("res://scripts/game/sfx.gd")
	ok(UB.streak_table(1) == [0.0, 0] and UB.streak_table(7)[1] == 6 and float(UB.streak_table(7)[0]) > float(UB.streak_table(4)[0]) and UB.streak_table(99) == UB.streak_table(7), "連勝桌況：第 1 戰不變、一戰比一戰暗、木籌一戰多一枚（夾在 7 戰）")
	ok("obj_paper" in SF.FILES and "obj_stamp" in SF.FILES and FileAccess.file_exists("res://audio/obj_paper.wav") and FileAccess.file_exists("res://audio/obj_stamp.wav"), "器物聲兩個檔都在、都有登記")
	var gs: String = FileAccess.get_file_as_string("res://scripts/ui/game_screens.gd")
	var ub: String = FileAccess.get_file_as_string("res://scripts/ui/ui_base.gd")
	ok(gs.find("sfx.play(\"obj_stamp\", 1.0)") >= 0, "宣紙戰報蓋章用「蓋印」")
	ok(SF.is_ui("obj_paper") and SF.is_ui("obj_stamp"), "器物聲走介面音量")
	ok(gs.find("sfx.play(str(_btns[_focus].get(\"snd\", \"k_click\")), 0.7)") >= 0 and ub.find("streak_force") < 0, "鍵盤／手把確認也只播按鈕自己的一聲；沒有留測試鉤子")
	var fr := Rect2(UB.ORIGIN, UB.FIELD).grow(26.0)
	var hit := 0
	var nb := 0
	for st in range(1, 8):
		for b in UB.streak_bands(Rect2(UB.ORIGIN, UB.FIELD), float(UB.streak_table(st)[0])):
			nb += 1
			if (b[0] as Rect2).intersects(fr):
				hit += 1
	ok(hit == 0 and nb > 0, "連勝桌況的壓暗帶全部在棋盤框外（盤內不動；%d 條、相交 %d）" % [nb, hit])
	var chip_hit := false
	for i in 6:
		if Rect2(Vector2(1228, 560 - i * 5) - Vector2(11, 11), Vector2(22, 22)).intersects(fr):
			chip_hit = true
	ok(not chip_hit, "木籌也在棋盤框外")
	ok(ub.find("_desk_props()\n\t_streak_desk()") >= 0 and ub.find("if int(get(\"mode\")) != Mode.GAUNTLET") >= 0, "連勝桌況只在連勝遠征、畫在桌面層（盤面畫在上面＝盤內不動）")
