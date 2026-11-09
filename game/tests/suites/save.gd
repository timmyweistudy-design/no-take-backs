extends "res://tests/test_base.gd"

## 存檔遷移（第二輪方案 R8）：v1 進度不掉、補上 unit_wins、改用 schema_version；不認得的欄位保留；新版存檔不降版。
func test_save_migration() -> void:
	var SV = load("res://scripts/game/save.gd")
	var v1 := {"version": 1, "tutorial": 3, "puzzle_stars": {"p1": 3}, "slots": ["NTB1.x", "", "", "", ""], "stats": {"wins": 7, "games": 9}, "future_key": 5}
	var m: Dictionary = SV.migrate(v1)
	ok(int(m["schema_version"]) == 3 and not m.has("version") and m["unit_wins"] is Dictionary, "存檔遷移：v1→v3 改欄位名、補 unit_wins")
	ok(int(m["unlock_games"]) == 9 and m["rule_presets"] == [] and m["custom_stats"] is Dictionary, "存檔遷移 v3：解鎖累計場數＝舊的正式場數（已解鎖的兵不會被收回）")
	var bad_ps := {"schema_version": 3, "rule_presets": [{"name": "a", "code": "NTBR1.x.y"}, {"name": 3, "code": "z"}, "junk", {"name": "b", "code": "x".repeat(3000)}] + [{"name": "c", "code": "q"}]}
	var m3: Dictionary = SV.migrate(bad_ps)
	ok(m3["rule_presets"].size() == 2 and str(m3["rule_presets"][0]["name"]) == "a", "存檔遷移：我的預設逐筆驗型、限長（壞的丟掉）", str(m3["rule_presets"]))
	ok(int(m["tutorial"]) == 3 and int(m["puzzle_stars"]["p1"]) == 3 and m["slots"][0] == "NTB1.x" and int(m["stats"]["wins"]) == 7 and int(m["future_key"]) == 5, "存檔遷移：舊進度與不認得的欄位都保留")
	var v2 := {"schema_version": 2, "unit_wins": {"3": 4}, "tutorial": 1}
	var m2: Dictionary = SV.migrate(v2)
	ok(int(m2["unit_wins"]["3"]) == 4 and m2.has("achievements"), "存檔遷移：v2 原樣保留、缺的欄位補預設")
	# 正式載入流程（Codex 收尾輪 #1）：寫一個 v1 檔，用 load_all 讀，舊鍵要被遷移掉
	var old_prefix: String = SV.prefix
	SV.prefix = "test_mig_"
	var f := FileAccess.open("user://test_mig_save.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "tutorial": 2, "unit_wins": 5}))
	f.close()
	SV.load_all()
	var ld: Dictionary = SV.data
	ok(int(ld["schema_version"]) == 3 and not ld.has("version") and ld["unit_wins"] is Dictionary and int(ld["tutorial"]) == 2 and ld.has("achievements"),
		"存檔遷移：正式 load_all 讀 v1 檔會遷移、壞掉的 unit_wins 修好、補預設", str(ld))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_mig_save.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_mig_settings.json"))
	SV.prefix = old_prefix
	var v9 := {"schema_version": 9, "x": 1}
	ok(SV.migrate(v9) == v9, "存檔遷移：比目前新的版本不降版")


## 第七輪 R4～R7、N1：存檔資料安全，全部用真檔案＋故障注入。
func test_save_v7() -> void:
	var SV = load("res://scripts/game/save.gd")
	var old_prefix: String = SV.prefix
	SV.prefix = "t7_"
	var P := "user://t7_save.json"
	var B := P + ".bak"
	# R4：語法對但型別全錯
	_sv_clear(SV)
	_sv_put(P, JSON.stringify({"schema_version": 3, "slots": "x", "tutorial": [], "stats": 3, "custom_stats": {"wins": "a"}, "puzzle_stars": {"p1": 99, "p2": []}, "unit_wins": [1], "achievements": {"a": 1}, "gauntlet_best": {}, "unlock_games": "9", "last_rules": 3, "rule_presets": 3, "future_field": 7}))
	_sv_put("user://t7_settings.json", JSON.stringify({"lang": 3, "text_scale": 999, "music": 500, "sfx": "x", "speed": [], "shake": "yes", "duel_rule": "nope", "roster": 1}))
	SV.load_all()
	var d: Dictionary = SV.data
	ok(d["slots"] is Array and d["slots"].size() == 5 and d["tutorial"] is int and d["stats"]["games"] == 0 and d["custom_stats"]["wins"] == 0, "R4：型別錯的進度欄位回到安全值", str(d))
	ok(d["puzzle_stars"]["p1"] == 3 and d["puzzle_stars"]["p2"] == 0 and d["unit_wins"] == {} and d["achievements"] == [] and d["last_rules"] == {} and d["rule_presets"] == [], "R4：星數夾 0～3，其餘壞欄位歸零", str(d))
	ok(d["future_field"] == 7, "R4：不認得的欄位保留")
	ok(SV.settings["lang"] == "zh_TW" and SV.settings["text_scale"] == 100 and SV.settings["music"] == 100 and SV.settings["sfx"] == 80 and SV.settings["speed"] == 1.0 and SV.settings["shake"] == true and SV.settings["duel_rule"] == "snake5" and SV.settings["roster"] == "all", "R4：設定逐欄驗型", str(SV.settings))
	# V1.2.1 F4：新的介面音、環境音欄位，舊檔沒有時承接舊音效值（含靜音），型別錯回合法值
	_sv_clear(SV)
	_sv_put("user://t7_settings.json", JSON.stringify({"sfx": 0, "music": 40}))
	SV.load_all()
	ok(SV.settings["ui_vol"] == 0 and SV.settings["amb_vol"] == 0, "F4：舊檔靜音音效 → 介面音、環境音也靜音", str(SV.settings))
	_sv_clear(SV)
	_sv_put("user://t7_settings.json", JSON.stringify({"sfx": 55}))
	SV.load_all()
	ok(SV.settings["ui_vol"] == 55 and SV.settings["amb_vol"] == 55, "F4：舊檔音效 55 → 新兩條承接 55", str(SV.settings))
	_sv_clear(SV)
	_sv_put("user://t7_settings.json", JSON.stringify({"sfx": 30, "ui_vol": "x", "amb_vol": 999}))
	SV.load_all()
	ok(SV.settings["ui_vol"] == 30 and SV.settings["amb_vol"] == 100, "F4：型別錯承接音效、超界夾到 100", str(SV.settings))
	var again: Dictionary = SV.sanitize_settings(SV.settings)
	ok(again["ui_vol"] == 30 and again["amb_vol"] == 100, "F4：重複遷移結果不變")
	# 版本欄位本身型別錯也不能當掉
	ok(SV.schema_of({"schema_version": []}) == 1, "R4：版本欄位型別錯當 v1")
	# R5：未來版
	_sv_clear(SV)
	var fut := JSON.stringify({"schema_version": 99, "tutorial": 5, "new_stuff": [1, 2]})
	_sv_put(P, fut)
	SV.load_all()
	ok(SV.data_locked and int(SV.data["schema_version"]) == SV.SAVE_VERSION and SV.data["tutorial"] == 0, "R5：未來版存檔鎖定，記憶體用新進度")
	SV.data["tutorial"] = 3
	SV.save_data()
	ok(FileAccess.get_file_as_string(P) == fut and not FileAccess.file_exists(B), "R5：未來版原檔一個位元組都沒變、沒產生備份")
	SV.data_locked = false
	# R6：主檔壞 → 讀備份 → 下次寫入失敗 → 好備份還在
	_sv_clear(SV)
	var good := JSON.stringify({"schema_version": 3, "tutorial": 2})
	_sv_put(P, "{壞掉的 json")
	_sv_put(B, good)
	SV.load_all()
	ok(SV.data_source == "bak" and SV.data["tutorial"] == 2, "R6：主檔壞讀備份", SV.data_source)
	ok(FileAccess.file_exists(P + ".corrupt1") and not FileAccess.file_exists(P), "R6：壞主檔被隔離")
	ok(FileAccess.get_file_as_string(B) == good, "R6：讀完備份還在")
	SV.fail_inject = {"tmp": 1}
	ok(not SV.save_data() and SV.has_unsaved(), "R7：寫入失敗要回報、記下未存")
	ok(FileAccess.get_file_as_string(B) == good, "R6：寫入失敗後好備份仍在")
	ok(SV.retry_pending() and not SV.has_unsaved() and FileAccess.file_exists(P), "R7：重試成功清掉未存")
	ok(FileAccess.get_file_as_string(B) == good, "R6：第一次寫入（主檔空著）不會動備份")
	# 下一次正常寫入才輪替驗證過的主檔
	SV.data["tutorial"] = 3
	ok(SV.save_data(), "R6：正常寫入")
	ok(JSON.parse_string(FileAccess.get_file_as_string(B))["tutorial"] == 2, "R6：輪替的是驗證過的上一版")
	# 遊戲開著時主檔被弄壞：不拿它蓋備份
	var keep := FileAccess.get_file_as_string(B)
	_sv_put(P, "壞")
	SV.data["tutorial"] = 4
	ok(SV.save_data(), "R6：壞主檔也能寫入新檔")
	ok(FileAccess.get_file_as_string(B) == keep and JSON.parse_string(FileAccess.get_file_as_string(P))["tutorial"] == 4, "R6：執行中壞掉的主檔不會蓋備份")
	# 輪替失敗：不覆蓋主檔
	var cur := FileAccess.get_file_as_string(P)
	SV.fail_inject = {"rotate": 1}
	SV.data["tutorial"] = 5
	ok(not SV.save_data() and FileAccess.get_file_as_string(P) == cur and not FileAccess.file_exists(P + ".tmp"), "R6：備份輪替失敗就不動主檔、不留暫存")
	ok(SV.retry_pending() and JSON.parse_string(FileAccess.get_file_as_string(P))["tutorial"] == 5, "R7：重試後進度沒丟")
	# 重啟恢復
	SV.load_all()
	ok(SV.data_source == "main" and SV.data["tutorial"] == 5, "R6：重啟後讀到最新進度")
	# R7：Steam 送不出去會重試
	var ST = load("res://scripts/game/steam.gd")
	var fake = FakeSteam.new()
	ST._steam = fake
	SV.data["achievements"] = []
	ST.unlock("FIRST_WIN")
	ok(ST.store_ok == false and fake.stores == 1, "R7：storeStats 失敗有記下")
	for i in 600:
		ST.run_callbacks()
	ok(ST.store_ok == true and fake.stores == 2, "R7：之後會自動重送", str(fake.stores))
	ST._steam = null
	# N1：試玩版與正式版不同檔
	SV.prefix = ""
	ok(SV.file_prefix(true) == "demo_" and SV.file_prefix(false) == "", "N1：試玩版存檔另一份")
	SV.prefix = "t7_"
	ok(SV.file_prefix(true) == "t7_demo_", "N1：測試前綴仍然有效")
	_sv_clear(SV)
	SV.prefix = old_prefix


## 第七輪 S4：成就離線達成、上線補送；正式 App 清單比對（假 Steam，實機仍由使用者跑）。
func test_steam_v7() -> void:
	var ST = load("res://scripts/game/steam.gd")
	var fake = FakeSteam2.new()
	ST._steam = fake
	for id in ST.ACHIEVEMENTS:
		fake.known[id] = true
	fake.app = 12345
	var r: Dictionary = ST.self_test(12345)
	ok(r["ok"] and r["missing_achievements"].is_empty(), "S4：正式 App 清單齊全才過", str(r))
	fake.known.erase("BACKSTAB_3")
	r = ST.self_test(12345)
	ok(not r["ok"] and r["missing_achievements"] == ["BACKSTAB_3"], "S4：後台少一個成就要抓得到", str(r))
	ST._steam = null
	ok(ST.ACHIEVEMENTS.size() == 31, "S4：程式 31 個成就（V1.5 加 7 個；docs/release/steam-setup.md 要同步）")
	# V1.2.1 F3：大字幕鍵盤開不起來時要解除訊號（不然下次關閉會觸發舊動作）
	var fk = FakeSteamKb.new()
	ST._steam = fk
	var hits := [0]
	var cb := func(_a = null, _b = null): hits[0] += 1
	ok(ST.text_input("x", 8, cb) == false and not fk.is_connected("gamepad_text_input_dismissed", cb), "F3：鍵盤開失敗會解除訊號")
	fk.open_ok = true
	ok(ST.text_input("x", 8, cb) == true and fk.is_connected("gamepad_text_input_dismissed", cb), "F3：開成功才保留訊號")
	fk.emit_signal("gamepad_text_input_dismissed", true, "abc")
	ok(hits[0] == 1, "F3：關閉只觸發一次", str(hits[0]))
	ST._steam = null
	fk.free()
	# V1.2.1 F2：地塊烘焙失敗（沒有地形資料）要清掉 busy，下次可以重試
	var MA = load("res://scripts/ui/map_art.gd")
	var ma = MA.new()
	var bk: int = MA.key_of(0, 0) * 2   # 平原沒有地形資料：走失敗路徑
	ma._busy[bk] = true
	ma._bake(0, 0, false)
	ok(not ma._busy.has(bk), "F2：烘焙失敗清掉 busy")
	ma.free()


class FakeSteamKb extends Node:
	signal gamepad_text_input_dismissed(submitted, text)
	var open_ok := false
	func showGamepadTextInput(_a, _b, _c, _d, _e): return open_ok


class FakeSteam2:
	var known := {}
	var app := 0
	func loggedOn(): return true
	func getAppID(): return app
	func isSteamRunning(): return true
	func getAchievement(id): return {"ret": known.has(id), "achieved": false}


## V1.1 F2：本機遊玩紀錄（嘗試次數、第一次過關花費）
func test_play_log_v11() -> void:
	var SV = load("res://scripts/game/save.gd")
	var keep: Dictionary = SV.data.duplicate(true)
	SV.data = {}
	SV.note_try("puzzle", "c1", false, 90)
	SV.note_try("puzzle", "c1", true, 84)
	SV.note_try("puzzle", "c1", true, 70)
	ok(int(SV.data["puzzle_tries"]["c1"]) == 3, "F2：每打一次 +1")
	ok(int(SV.data["puzzle_first"]["c1"]) == 84 and int(SV.data["puzzle_first"]["c1@"]) == 2, "F2：只記第一次過關的花費與第幾次")
	SV.note_try("trial", "12", false, 50)
	ok(int(SV.data["trial_tries"]["12"]) == 1 and not SV.data["trial_first"].has("12"), "F2：沒過關不記 first")
	var bad := {"puzzle_tries": {"c1": "x", "c2": -5}, "trial_first": "oops"}
	SV.sanitize_data(bad)
	ok(int(bad["puzzle_tries"]["c1"]) == 0 and int(bad["puzzle_tries"]["c2"]) == 0 and bad["trial_first"] is Dictionary, "F2：壞資料歸零、不當掉")
	SV.data = keep


## V1.4 #6 最小成本紀錄合併、#2 宿敵與紀錄的存檔清理。
func test_records_v140() -> void:
	var GC = load("res://scripts/ui/screens/game_core.gd")
	ok(GC.record_merge([], 30, 6, 900) == [30, 6, 900], "第一次＝本次成績")
	ok(GC.record_merge([30, 6, 900], 28, 7, 950) == [28, 6, 900], "三項各自取最小")
	var SV = load("res://scripts/game/save.gd")
	var d := {"pz_best": {"a1": [10, 3, 400], "bad": [1, 2], "neg": [-1, 2, 3]},
		"nemeses": [{"units": [{"type": 5, "col": 10, "row": 2}], "losses": 2, "revenged": true, "stage": 3},
			{"units": [{"type": 5, "col": 3, "row": 2}]}, "junk", {"units": []}]}
	SV.sanitize_data(d)
	ok(d["pz_best"].size() == 1 and d["pz_best"]["a1"] == [10, 3, 400], "紀錄：格式不對的丟掉", str(d["pz_best"]))
	ok(d["nemeses"].size() == 1 and d["nemeses"][0]["revenged"] == true, "宿敵：欄位不在敵方區、空陣、亂資料都丟掉", str(d["nemeses"]))


## V1.4 #15 塗裝：存檔清洗（長度、範圍）、鎖定條件、底漆換色（色盲時不換）。
func test_paint_v140() -> void:
	var SV = load("res://scripts/game/save.gd")
	var GM = load("res://scripts/ui/screens/game_modes.gd")
	var Art0 = load("res://scripts/ui/art.gd")
	var d := {"paint": [9, -2, 1, 2, 3.0, "x"]}
	SV.sanitize_data(d)
	ok(d["paint"] == [3, 0, 1, 2, 3, 0], "塗裝存檔夾在範圍內", str(d["paint"]))
	var d2 := {"paint": [1, 1]}
	SV.sanitize_data(d2)
	ok(d2["paint"] == [0, 0, 1, 1, 0, 0], "長度不對就用預設")
	ok(not GM.paint_locked(true, 1, 2) and GM.paint_locked(true, 3, 8) and not GM.paint_locked(false, 2, 0), "解鎖看成就數；漬洗乾掃不鎖")
	var keep: Array = Art0.paint.duplicate()
	Art0.paint[0] = 2
	ok(Art0.team_color(0) == Art0.PAINTS[0][2] and Art0.team_color(0, true) == Art0.TEAM[1][0], "換底漆；色盲配色維持原色")
	ok(Art0.paint_sig() != "001100", "換底漆後圖集要重烘（簽章不同）")
	for i in 6:
		Art0.paint[i] = keep[i]


## V1.5 設定七頁：列舉值清洗、舊開關轉強度、老玩家不問第一次啟動、設定代碼往返、預設可疊加可撤回。
func test_settings_v150() -> void:
	var SV = load("res://scripts/game/save.gd")
	var GM = load("res://scripts/ui/screens/game_menus.gd")
	var d: Dictionary = SV.sanitize_settings({"hp_bars": "zzz", "fps_cap": 77, "shake": false, "flash": true, "master": 300, "long_press": 9.0})
	ok(d["hp_bars"] == "hurt" and d["fps_cap"] == 60 and d["master"] == 100 and is_equal_approx(float(d["long_press"]), 1.0), "列舉值與範圍清洗", str([d["hp_bars"], d["fps_cap"], d["master"], d["long_press"]]))
	ok(d["shake_pct"] == 0 and d["flash_pct"] == 100 and d["shake"] == false, "舊的震動／閃白開關轉成強度")
	ok(d["first_done"] == true and SV.sanitize_settings({})["first_done"] == false, "有設定檔的老玩家不問第一次啟動；全新安裝要問")
	var code: String = GM.settings_code(d)
	var back = GM.settings_decode(code)
	ok(back is Dictionary and back["hp_bars"] == d["hp_bars"] and back["master"] == d["master"] and GM.settings_decode("亂碼") == null, "設定代碼往返、壞碼回 null", code.substr(0, 20))
	var GS = load("res://scripts/ui/game_screens.gd")
	var g = GS.new()
	g.sfx = FakeSfx.new()
	var keep_ts = SV.s("text_scale")
	var keep_rm = SV.s("reduce_motion")
	g._apply_preset(0)
	g._apply_preset(1)
	ok(int(SV.s("text_scale")) == 150 and bool(SV.s("reduce_motion")), "兩組預設可以疊加")
	g._undo_preset()
	ok(SV.s("text_scale") == keep_ts and SV.s("reduce_motion") == keep_rm, "撤回回到套用前")
	var bad: Array = []
	for t in g.SET_TABS:
		g.settings_tab = t
		var rows: Array = g._settings_rows()
		if rows.is_empty() or rows.size() > 7:
			bad.append(t)
	ok(bad.is_empty(), "七頁每頁 1～7 列（放得下不用捲）", str(bad))
	g.free()



## V1.5 我的預設 10 格：舊存檔 10 筆都保留、第 11 筆丟掉。
func test_presets_ten_v150() -> void:
	var SV = load("res://scripts/game/save.gd")
	var ps: Array = []
	for i in 12:
		ps.append({"name": "p%d" % i, "code": "NTBR1.x"})
	var m: Dictionary = SV.migrate({"schema_version": 3, "rule_presets": ps})
	ok(SV.MAX_PRESETS == 10 and m["rule_presets"].size() == 10, "我的預設最多 10 格", str(m["rule_presets"].size()))


## V1.5 還原驗證：只有版本欄的 JSON、版本是字串、未來版都不能拿來還原；正常存檔可以（Codex v150-i2 #2）。
func test_restorable_v150() -> void:
	var SV = load("res://scripts/game/save.gd")
	ok(not SV.restorable({"version": 1}), "只有版本欄不算")
	ok(not SV.restorable({"schema_version": "錯誤", "stats": {}, "achievements": []}), "版本是字串不算")
	ok(not SV.restorable({"schema_version": SV.SAVE_VERSION + 1, "stats": {}, "achievements": []}), "未來版不算")
	ok(SV.restorable(SV.DEFAULT_SAVE.duplicate(true)), "正常存檔可以還原")
