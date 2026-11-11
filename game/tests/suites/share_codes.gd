extends "res://tests/test_base.gd"
## 1.1.0 A4：功能測試組「share_codes」：分享、各種代碼（出題碼、三考碼、車輪戰碼、相鄰碼）、招牌陣。
## 從原本依版本分的 v16、v161、v100 搬來，函式名不變（名字尾的 _v160／_v161／_v100／_v110 是做的版本）。會碰存檔的測試自己換前綴、結束還原。

func test_share_v160() -> void:
	var SH = load("res://scripts/game/share.gd")
	var Lx = load("res://scripts/game/strings.gd")
	ok(SH.bar(72) == "■■■■■■■□□□" and SH.bar(0) == "□□□□□□□□□□" and SH.bar(100) == "■■■■■■■■■■", "剩餘戰力 10 格條")
	var st: Dictionary = SH.streak_after({}, 100)
	st = SH.streak_after(st, 101)
	st = SH.streak_after(st, 101)
	ok(int(st["n"]) == 2 and int(st["best"]) == 2, "連續兩天＝2，同一天不重複加")
	st = SH.streak_after(st, 104)
	ok(int(st["n"]) == 1 and int(st["best"]) == 2, "中斷重算，最佳保留")
	var t: String = SH.daily_text(Lx, "2026-11-10", "X", 72, 84, 100, 38, 3)
	ok(t.contains("■■■■■■■□□□") and t.contains("84") and t.split("\n").size() == 5, "每日分享格：條、花費、連續天數、標籤")
	ok(not t.contains("unit_") and not t.contains("NTB"), "分享格不含陣型或代碼（不劇透）")

func test_adjacency_code_v160() -> void:
	var RSx = load("res://scripts/core/ruleset.gd")
	var BC = load("res://scripts/game/battle_code.gd")
	var Armyx = load("res://scripts/core/army.gd")
	var r = RSx.standard()
	r.adj = true
	var a = Armyx.new(0, 100)
	a.place(1, 5, 4)
	a.place(2, 4, 4)
	var e = Armyx.new(1, 100)
	e.place(0, 10, 4)
	var c: String = BC.encode(a, e, r)
	var d: Dictionary = BC.decode(c)
	ok(bool(d.get("ok", false)) and d["rules"] != null and d["rules"].adj, "對戰代碼帶著相鄰陣法")

func test_ntp4_v161() -> void:
	var WS = load("res://scripts/game/workshop.gd")
	var e := [[0, 10, 4], [3, 11, 4], [1, 12, 2]]
	var s := [[3, 4, 3], [3, 4, 5], [0, 5, 4], [2, 2, 4]]
	var c3: String = WS.encode4(e, s, "kill", Vector2i(-1, -1))
	ok(c3.begins_with("NTP3."), "沒指定目標照舊出 NTP3")
	var c4: String = WS.encode4(e, s, "kill", Vector2i(10, 4))
	if c4 != "":
		var d: Dictionary = WS.decode(c4)
		ok(c4.begins_with("NTP4.") and bool(d["ok"]) and d["pz"]["goal_unit"] == [10, 4], "指定斬首目標（不是最貴的那隻）", str(d.get("why")))
	ok(WS.encode4(e, s, "kill", Vector2i(4, 3)) == "", "斬首點到自己的兵不給碼")
	ok(WS.pick_fields("flawless", e, s, [2, 4]) == {"goal": "flawless", "goal_type": 2, "need_type": true}, "完美：點到哪隻就是那種兵")
	ok(WS.pick_fields("protect", e, s, [9, 9]).is_empty() and WS.pick_fields("protect", e, s, "x").is_empty(), "壞的目標欄位擋掉")
	# 竄改：NTP4 帶不在作者解的目標
	var j := JSON.stringify({"v": 4, "e": e, "s": s, "a": [0, 2, 3], "g": "protect", "t": [15, 8]})
	var b := Marshalls.utf8_to_base64(j).replace("+", "-").replace("/", "_").replace("=", "")
	ok(not bool(WS.decode("NTP4.%s.%s" % [b, b.sha256_text().substr(0, 6)])["ok"]), "目標不存在的 NTP4 拒收")
	ok(WS.decode("NTP3.x.y")["ok"] == false, "NTP3 舊路徑照舊驗")

func test_rules_equals_map_v161() -> void:
	var RS = load("res://scripts/core/ruleset.gd")
	var a = RS.standard()
	var b = RS.standard()
	ok(a.equals(b), "同樣規則相等")
	b.map_id = 3
	ok(not a.equals(b), "地圖不同就不相等（B1）")
	b.map_id = 0
	b.map_size = 2
	ok(not a.equals(b), "大小不同就不相等")

func test_signature_v161() -> void:
	var PS = load("res://scripts/game/persona.gd")
	var AI = load("res://scripts/core/ai_army.gd")
	var hits := 0
	for sd in 200:
		var t: int = PS.signature(2, sd, func(x): return true)
		if t >= 0:
			hits += 1
			ok(t in PS.SIG[2], "招牌陣只會是這個性格的兩套")
	ok(hits > 50 and hits < 110, "約 40% 用招牌陣（A11）", str(hits))
	ok(PS.signature(4, 3, func(x): return false) == -1, "卡池用不了就照舊")
	ok(PS.signature(1, 77, func(x): return true) == PS.signature(1, 77, func(x): return true), "同種子同結果（可重現）")
	for st in PS.SIG.size():
		for t in PS.SIG[st]:
			ok(int(t) < AI.TEMPLATES.size(), "招牌陣編號有效")

## M16：docs/codes.md 的前綴表和 code_kind 一致；亂碼不辨識。
func test_code_table_v100() -> void:
	var G = load("res://scripts/ui/screens/game_menus.gd")
	var want := {"NTB1": "army", "NTB5": "army", "NTB6": "army", "NTB2": "battle", "NTB3": "battle", "NTB4": "battle", "NTB7": "battle",
		"NTBR1": "rules", "NTBR6": "rules", "NTC1": "challenge", "NTP1": "workshop", "NTP2": "workshop", "NTP3": "workshop", "NTP4": "workshop",
		"NTS1": "settings", "NTW1": "waves", "NTQ1": "solution"}
	var bad: Array = []
	for p in want:
		if G.code_kind(p + ".abc.123456") != want[p]:
			bad.append(p)
	ok(bad.is_empty(), "每個前綴都認得", str(bad))
	for junk in ["", "hello", "NTX1.a.b", "ntb1.a.b", "NTB8.a.b"]:
		ok(G.code_kind(junk) == "", "不認得的不辨識：" + junk)
	var md := FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../docs/codes.md"))
	if md == "":
		print("SKIP docs/codes.md 不在（快照或匯出環境）")
	else:
		for p in want:
			ok(md.find(p) >= 0, "docs/codes.md 有寫 " + p)
	var WS = load("res://scripts/game/workshop.gd")
	for junk in ["NTP3.%%%.000000", "NTP4." + "A".repeat(7000) + ".x"]:
		ok(not bool(WS.decode(junk)["ok"]), "壞的出題碼不收")
