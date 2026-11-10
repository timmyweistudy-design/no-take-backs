extends RefCounted
## 設定與進度存檔（優化方案 L1、N）：JSON、原子寫入（先寫暫存檔再改名）＋保留上一版備份。
## 雲端：Steam Auto-Cloud 只同步 user://save.json（進度、陣型）；設定 user://settings.json 留在本機。

const SAVE_VERSION := 3   # 存檔格式版本（schema_version）。2：加 unit_wins（圖鑑老兵筆記，第二輪方案 R3／R8）；3：第五輪自訂規則
const MAX_PRESETS := 10   # V1.5：5 → 10 格
static var prefix := ""   # 截圖／測試模式用 "shot_"，不碰玩家真正的存檔

const DEFAULT_SETTINGS := {
	"lang": "zh_TW", "text_scale": 100, "shake": true, "slowmo": true, "flash": true, "colorblind": false, "plain_titles": false, "plain_ui": false, "confirm_place": true,
	"speed": 1.0, "music": 70, "sfx": 80, "ui_vol": 80, "amb_vol": 80, "duel_rule": "snake5", "fullscreen": false, "playtest": false, "roster": "all", "reduce_fx": false, "keys": {}, "pad": {},
	# V1.5 設定七頁：畫面、介面、聲音、操作、戰場與觀戰、無障礙、資料（docs/2026-11-09-v1.5.0-plan.md §2）
	"title_bg": "demo", "fps_cap": 60, "vsync": true, "hints": "full", "toast_mult": 1, "master": 100, "night": false, "mono": false,
	"long_press": 0.5, "place_mode": "both", "rumble": 50, "deadzone": 20, "hp_bars": "hurt", "dmg_nums": "merge", "clutch_zoom": true,
	"reduce_motion": false, "text_plate": false, "focus_strong": false, "shake_pct": 25, "flash_pct": 50, "first_done": false,
	"hold_confirm": false, "magnify": false,   # V1.6 #7：按住確認、文字放大鏡   # V1.5.1：預設＝新安裝實際拿到的值（老玩家在 sanitize 照舊開關轉 100）
}
const ENUMS := {"place_mode": ["both", "tap"], "title_bg": ["demo", "static"], "hints": ["full", "key", "off"], "hp_bars": ["hurt", "all", "sel", "off"], "dmg_nums": ["merge", "each", "off"],
	"fps_cap": [30, 60, 120, 0], "toast_mult": [1, 2, 3, 0], "rumble": [0, 25, 50, 100], "deadzone": [5, 10, 15, 20, 25, 30, 35, 40], "shake_pct": [0, 25, 50, 100], "flash_pct": [0, 50, 100]}
const DEFAULT_SAVE := {
	"schema_version": SAVE_VERSION, "slots": ["", "", "", "", ""], "tutorial": 0, "puzzle_stars": {},
	"gauntlet_best": 0, "achievements": [], "stats": {"wins": 0, "games": 0}, "unit_wins": {},
	# 第五輪：解鎖累計場數（標準＋自訂局都算，沙盒不算）、自訂規則戰績、我的預設、上次在大廳用的規則（代碼）
	"unlock_games": 0, "custom_stats": {"wins": 0, "games": 0}, "rule_presets": [], "last_rules": {}, "gauntlet_pool": 0, "trial_stars": {}, "unit_games": {}, "streak": 0, "best_streak": 0, "decks": [], "free_intro_done": false, "gauntlet_run": {}, "puzzle_tries": {}, "puzzle_first": {}, "trial_tries": {}, "trial_first": {}, "daily_best": {},
}

static var settings := {}
static var data := {}
## 第七輪 R5：存檔來自比這一版新的遊戲。原檔不動、這次進度不寫入，畫面要告知玩家。
static var data_locked := false
## 第七輪 R6：這次讀到的來源："none"／"main"／"bak"（"bak"＝主檔壞了，已隔離）。
static var data_source := "none"
## 第七輪 R7：寫入失敗還沒補上的檔案（路徑）；retry_pending() 重試。
static var pending := {}
## 只給測試用：接下來幾次寫入要假裝失敗（"tmp"＝寫暫存失敗；"rotate"＝輪替備份失敗）。
static var fail_inject := {}

static func load_all() -> void:
	pending = {}
	settings = sanitize_settings(_read(_sp(), {}).get("value", {}))
	var r := _read(_dp(), {})
	data_source = r["source"]
	var raw: Dictionary = r["value"]
	data_locked = schema_of(raw) > SAVE_VERSION
	# 未來版存檔：記憶體用全新進度，檔案完全不碰（Codex plan7 R5）
	data = migrate({}) if data_locked else migrate(raw)   # 先讀原始內容再遷移（遷移裡才補預設值），不然舊檔會被當成新版（Codex 收尾輪 #1）

## 檔名前綴：測試／截圖的 prefix 在前；試玩版另外一份，進度不帶進正式版（N1、§18-4）。
static func file_prefix(demo := OS.has_feature("demo")) -> String:
	return prefix + ("demo_" if demo else "")

static func _sp() -> String:
	return "user://%ssettings.json" % file_prefix()

static func _dp() -> String:
	return "user://%ssave.json" % file_prefix()

## 讀一個 JSON 檔；內容不是物件就回傳 null。
static func _parse(path: String):
	var j := JSON.new()   # 不用 JSON.parse_string：壞檔是預期情況，不該在日誌印 ERROR
	if j.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	return j.data if typeof(j.data) == TYPE_DICTIONARY else null

## 壞掉的主檔移到旁邊留證據，主檔位置空出來，下一次寫入才不會拿它蓋掉好備份（R6）。
static func _quarantine(path: String) -> void:
	var n := 1
	while FileAccess.file_exists("%s.corrupt%d" % [path, n]) and n < 20:
		n += 1
	DirAccess.rename_absolute(path, "%s.corrupt%d" % [path, n])

## 回傳 {value, source}。主檔壞 → 隔離 → 讀備份。
static func _read(path: String, defaults: Dictionary) -> Dictionary:
	if FileAccess.file_exists(path):
		var m = _parse(path)
		if m != null:
			return {"value": m, "source": "main"}
		_quarantine(path)
	var bak := path + ".bak"
	if FileAccess.file_exists(bak):
		var b = _parse(bak)
		if b != null:
			return {"value": b, "source": "bak"}
	return {"value": defaults.duplicate(true), "source": "none"}

static func _num(v, fallback := 0.0) -> float:
	return float(v) if (v is int or v is float) else float(fallback)

static func _count(v, hi := 1000000000) -> int:
	return clampi(int(_num(v)), 0, hi)

static func schema_of(d: Dictionary) -> int:
	return int(_num(d.get("schema_version", d.get("version", 1)), 1))

## 設定逐欄驗型（R4）：型別不對用預設，數值夾在合法範圍；不認得的欄位保留。
static func sanitize_settings(d: Dictionary) -> Dictionary:
	var out := d.duplicate(true)
	# V1.2.1 F4：介面音、環境音是新欄位；舊檔沒有（或型別錯）時承接舊的音效值，舊靜音也保持靜音
	var old_sfx = out.get("sfx", DEFAULT_SETTINGS["sfx"])
	if not (old_sfx is int or old_sfx is float):
		old_sfx = DEFAULT_SETTINGS["sfx"]
	for nk in ["ui_vol", "amb_vol"]:
		if not (out.get(nk) is int or out.get(nk) is float):
			out[nk] = int(old_sfx)
	for k in DEFAULT_SETTINGS:
		var dv = DEFAULT_SETTINGS[k]
		var v = out.get(k, dv)
		if dv is bool:
			out[k] = v if v is bool else dv
		elif dv is String:
			out[k] = v if v is String else dv
		elif dv is int:
			out[k] = int(v) if (v is int or v is float) else dv
		elif dv is float:
			out[k] = float(v) if (v is int or v is float) else dv
	if not str(out["lang"]) in preload("res://scripts/game/strings.gd").LANGS:   # V1.2.1 G3：語言清單單一來源
		out["lang"] = DEFAULT_SETTINGS["lang"]
	if not int(out["text_scale"]) in [100, 125, 150]:
		out["text_scale"] = DEFAULT_SETTINGS["text_scale"]
	out["music"] = clampi(int(out["music"]), 0, 100)
	out["sfx"] = clampi(int(out["sfx"]), 0, 100)
	out["ui_vol"] = clampi(int(out["ui_vol"]), 0, 100)
	out["amb_vol"] = clampi(int(out["amb_vol"]), 0, 100)
	out["speed"] = clampf(float(out["speed"]), 0.25, 8.0)
	if not str(out["duel_rule"]) in ["snake5", "snake5c", "cap10", "blind", "custom"]:
		out["duel_rule"] = DEFAULT_SETTINGS["duel_rule"]
	var KM = load("res://scripts/game/keymap.gd")
	out["keys"] = KM.sanitize(KM.ACTIONS, out.get("keys"))
	out["pad"] = KM.sanitize(KM.PAD_ACTIONS, out.get("pad"))
	if not str(out["roster"]) in ["all", "classic"]:
		out["roster"] = DEFAULT_SETTINGS["roster"]
	# V1.5：已經有設定檔的老玩家不問第一次啟動的三個問題
	if not d.has("first_done") and d.size() > 0:
		out["first_done"] = true
	# V1.5：列舉值不在清單裡就回預設；舊存檔的震動、閃白開關轉成強度（關＝0）
	# 新安裝（沒有設定檔）照方案：震動 25%、閃白柔和（50%）；老玩家照原本開關（開＝100）不改手感
	if not d.has("shake_pct"):
		out["shake_pct"] = (100 if bool(out["shake"]) else 0) if d.size() > 0 else 25
	if not d.has("flash_pct"):
		out["flash_pct"] = (100 if bool(out["flash"]) else 0) if d.size() > 0 else 50
	for ek in ENUMS:
		if not out[ek] in ENUMS[ek]:
			out[ek] = DEFAULT_SETTINGS[ek]
	out["master"] = clampi(int(out["master"]), 0, 100)
	out["long_press"] = clampf(float(out["long_press"]), 0.3, 1.0)
	out["shake"] = int(out["shake_pct"]) > 0
	out["flash"] = int(out["flash_pct"]) > 0
	return out

## 進度逐欄驗型（R4）：語法對但型別錯的欄位不能讓遊戲當掉；壞欄位改預設，其他進度保留。
static func sanitize_data(out: Dictionary) -> void:
	var sl: Array = ["", "", "", "", ""]
	var raw_sl = out.get("slots", [])
	if raw_sl is Array:
		for i in mini(raw_sl.size(), sl.size()):
			if raw_sl[i] is String and str(raw_sl[i]).length() <= 8000:
				sl[i] = raw_sl[i]
	out["slots"] = sl
	for k in ["tutorial", "gauntlet_best", "unlock_games"]:
		out[k] = _count(out.get(k, 0))
	for k in ["stats", "custom_stats"]:
		var st = out.get(k, {})
		out[k] = {"wins": _count(st.get("wins", 0)), "games": _count(st.get("games", 0))} if st is Dictionary else {"wins": 0, "games": 0}
	var stars := {}
	var raw_st = out.get("puzzle_stars", {})
	if raw_st is Dictionary:
		for k in raw_st:
			stars[str(k)] = _count(raw_st[k], 3)
	out["puzzle_stars"] = stars
	var uw := {}
	var raw_uw = out.get("unit_wins", {})
	if raw_uw is Dictionary:
		for k in raw_uw:
			uw[str(k)] = _count(raw_uw[k])
	out["unit_wins"] = uw
	# V9：新欄位都是可有可無的統計，型別不對就歸零（不用升存檔版本：舊存檔沒有就用預設）
	for dk in ["trial_stars", "unit_games", "unit_games_rec", "unit_wins_rec", "puzzle_tries", "puzzle_first", "trial_tries", "trial_first"]:
		var dv = out.get(dk, {})
		var clean := {}
		if dv is Dictionary:
			for k9 in dv:
				clean[str(k9)] = _count(dv[k9])
		out[dk] = clean
	for nk in ["streak", "best_streak"]:
		out[nk] = _count(out.get(nk, 0))
	var dk2 = out.get("decks", [])
	var clean2: Array = []
	if dk2 is Array:
		for v9 in dk2:
			if v9 is float or v9 is int:
				clean2.append(int(v9))
	out["decks"] = clean2.slice(0, 3)
	var ach: Array = []
	var raw_a = out.get("achievements", [])
	if raw_a is Array:
		for a in raw_a:
			if a is String and not a in ach:
				ach.append(a)
	out["achievements"] = ach
	var lr := {}
	var raw_lr = out.get("last_rules", {})
	if raw_lr is Dictionary:
		for k in raw_lr:
			if raw_lr[k] is String and str(raw_lr[k]).length() <= 2000:
				lr[str(k)] = raw_lr[k]
			elif raw_lr[k] is Array and str(k).ends_with("_extra") and raw_lr[k].size() <= 4 and raw_lr[k].all(func(v): return v is int or v is float):
				lr[str(k)] = raw_lr[k].map(func(v): return int(v))   # 第十輪 B3：性格、輪替、禁牌、時段（JSON 讀回是浮點數）
	out["last_rules"] = lr
	out["gauntlet_run"] = sanitize_run(out.get("gauntlet_run", {}))
	# V1.1 D2：每日挑戰最佳紀錄 {"日數-vN": [剩餘%, 花費]}；壞的丟掉
	var db := {}
	var raw_db = out.get("daily_best", {})
	if raw_db is Dictionary:
		for k in raw_db:
			var v = raw_db[k]
			var dk3 := str(k)
			var okk := dk3.length() <= 24 and dk3.get_slice("-v", 0).is_valid_int() and dk3.get_slice("-v", 1).is_valid_int() and dk3.contains("-v") and int(dk3.get_slice("-v", 0)) <= int(Time.get_unix_time_from_system()) / 86400 + 2
			if okk and v is Array and v.size() == 2 and (v[0] is int or v[0] is float) and (v[1] is int or v[1] is float) and db.size() < 30:
				db[str(k)] = [clampi(int(v[0]), 0, 100), clampi(int(v[1]), 0, 1000)]
	out["daily_best"] = db
	# V1.4 #6 每關最佳 [花費, 兵數, tick]；#2 宿敵（最多 6 個）。型別不對就丟掉那一筆
	var pb = out.get("pz_best", {})
	var pb2 := {}
	if pb is Dictionary:
		for k in pb:
			var v = pb[k]
			if v is Array and v.size() == 3 and pb2.size() < 400:
				var okv := true
				for x in v:
					if not (x is int or x is float) or float(x) < 0 or float(x) > 100000:
						okv = false
				if okv:
					pb2[str(k)] = [int(v[0]), int(v[1]), int(v[2])]
	out["pz_best"] = pb2
	var nm = out.get("nemeses", [])
	var nm2: Array = []
	if nm is Array:
		for n in nm:
			if not n is Dictionary or not n.get("units") is Array or n["units"].is_empty() or n["units"].size() > 40 or nm2.size() >= 6:
				continue
			var us: Array = []
			var okn := true
			for u in n["units"]:
				if not u is Dictionary or not (u.get("type") is int or u.get("type") is float) or not (u.get("col") is int or u.get("col") is float) or not (u.get("row") is int or u.get("row") is float):
					okn = false
					break
				if int(u["type"]) < 0 or int(u["type"]) >= 22 or int(u["col"]) < 10 or int(u["col"]) > 15 or int(u["row"]) < 0 or int(u["row"]) > 8:
					okn = false
					break
				us.append({"type": int(u["type"]), "col": int(u["col"]), "row": int(u["row"])})
			if okn:
				var ls = n.get("losses", 1)
				var st = n.get("stage", 1)
				nm2.append({"units": us, "losses": clampi(int(ls) if (ls is int or ls is float) else 1, 1, 999), "revenged": n.get("revenged", false) == true, "stage": clampi(int(st) if (st is int or st is float) else 1, 1, 7)})
	out["nemeses"] = nm2
	var ey = out.get("eye", {})
	var ey2 := {}
	if ey is Dictionary:
		for k in ["n", "pts", "streak", "best"]:
			var v = ey.get(k, 0)
			ey2[k] = clampi(int(v), 0, 1000000) if (v is int or v is float) else 0
	out["eye"] = ey2   # V1.4 #16 競猜眼力
	var wb = out.get("wave_best", 0)
	out["wave_best"] = clampi(int(wb), 0, 3) if (wb is int or wb is float) else 0   # V1.4 #11 車輪戰最佳波數
	var pt = out.get("paint", [])
	var pt2 := [0, 0, 1, 1, 0, 0]   # V1.4 #15 塗裝：藍底漆、紅底漆、漬洗、乾掃、木座、棋盤框
	var hi := [3, 3, 2, 2, 3, 3]
	if pt is Array and pt.size() == 6:
		for i in 6:
			if pt[i] is int or pt[i] is float:
				pt2[i] = clampi(int(pt[i]), 0, hi[i])
	out["paint"] = pt2
	var gb = out.get("ghost_beat", [])   # V1.4 #7：打贏的幽靈（id 字串）
	var gb2: Array = []
	if gb is Array:
		for x in gb:
			if x is String and x.length() <= 8 and not x in gb2:
				gb2.append(x)
	out["ghost_beat"] = gb2
	var wr = out.get("weekly", {})
	var wr2 := {}
	if wr is Dictionary:
		for k in ["wk", "best", "tries", "pend"]:
			var v = wr.get(k, 0)
			wr2[k] = clampi(int(v), -1, 100000000) if (v is int or v is float) else 0
		var det = wr.get("det", [])
		var det2: Array = []
		if det is Array and det.size() <= 62:
			for v2 in det:
				if v2 is int or v2 is float:
					det2.append(int(v2))
		wr2["det"] = det2   # 每週最佳的陣型（補送排行榜用）
		wr2["pend"] = 1 if int(wr2["pend"]) == 1 else 0
	out["weekly"] = wr2
	sanitize_v16(out)

static func _is_num(v) -> bool:
	return v is int or v is float

static func _int_list(v, max_n: int) -> Array:
	var o: Array = []
	if v is Array and v.size() <= max_n:
		for x in v:
			if not _is_num(x):
				return []
			o.append(int(x))
	return o

## V1.6 新欄位逐欄驗型（Codex v160-i1 #1）：壞的回預設（拿掉），其他照留
static func sanitize_v16(out: Dictionary) -> void:
	var f = out.get("funnel", {})
	var f2 := {}
	if f is Dictionary:
		for k in f:
			if str(k) == "last_screen":
				if f[k] is String and str(f[k]).length() <= 40:
					f2["last_screen"] = f[k]
			elif str(k).length() <= 24 and _is_num(f[k]):
				f2[str(k)] = maxi(0, int(f[k]))
	out["funnel"] = f2
	var sn = out.get("seen", null)
	if out.has("seen") and not sn is Array:
		out.erase("seen")   # null 或型別錯：當作沒有（下次開遊戲補舊入口），Antigravity v160-i1 #4
	elif sn != null:
		var s2: Array = []
		if sn is Array:
			for x in sn:
				if x is String and str(x).length() <= 32 and s2.size() < 200:
					s2.append(x)
		out["seen"] = s2
	var ms = out.get("mastery", {})
	var m2 := {}
	if ms is Dictionary:
		for k in ms:
			if str(k).is_valid_int() and int(str(k)) >= 0 and int(str(k)) < 22 and _is_num(ms[k]):
				m2[str(int(str(k)))] = clampi(int(ms[k]), 0, 100000000)
	out["mastery"] = m2
	var nb = out.get("notebook", {})
	var nb2 := {}
	if nb is Dictionary:
		for pid in nb:
			if nb2.size() >= 400:
				break   # 超量就截斷，不整批清空（Antigravity v160-i2 #1）
			var lst = nb[pid]
			if not lst is Array or lst.size() > 5 or str(pid).length() > 24:
				continue
			var l2: Array = []
			for e in lst:
				if not e is Dictionary or not e.get("n") is String or not e.get("u") is Array or (e["u"] as Array).size() > 60:
					continue
				var us: Array = []
				var okk := true
				for u in e["u"]:
					var iu := _int_list(u, 4)
					if iu.size() < 3 or iu[0] < 0 or iu[0] >= 20:
						okk = false
						break
					us.append(iu)
				if okk:
					var rr := _int_list(e.get("r", []), 3)
					l2.append({"n": str(e["n"]).substr(0, 24), "u": us, "r": rr if rr.size() == 3 else []})   # 成績要剛好 3 個數（Codex v160-i2 C1）
			nb2[str(pid)] = l2
	out["notebook"] = nb2
	for k in ["daily_streak"]:
		var st = out.get(k, {})
		var st2 := {}
		if st is Dictionary:
			for kk in ["last", "n", "best"]:
				if _is_num(st.get(kk)):
					st2[kk] = int(st[kk])
		out[k] = st2 if st2.size() == 3 else {}
	var dp = out.get("daily_pend", {})
	if not (dp is Dictionary and _is_num(dp.get("day")) and _is_num(dp.get("score")) and dp.get("det") is Array):
		out.erase("daily_pend")
	else:
		out["daily_pend"] = {"day": int(dp["day"]), "score": int(dp["score"]), "det": _int_list(dp["det"], 62)}
	out["rush_best"] = clampi(int(out.get("rush_best", 0)) if _is_num(out.get("rush_best", 0)) else 0, 0, 100000)
	for k2 in ["rift_best", "trio_clear"]:
		var d = out.get(k2, {})
		var d2 := {}
		if d is Dictionary:
			for kk2 in d:
				if d2.size() >= 50:
					break
				var v = d[kk2]
				if k2 == "rift_best":
					var iv := _int_list(v, 2)
					if iv.size() == 2:
						d2[str(kk2)] = iv
				elif _is_num(v):
					d2[str(kk2)] = maxi(0, int(v))
		out[k2] = d2

## 第十輪 I5：遠征存點。少欄位或型別不對就當沒有。
static func sanitize_run(g) -> Dictionary:
	if not g is Dictionary:
		return {}
	var out := {}
	for k in ["stage", "seed", "gold", "cap", "changes", "pool"]:
		var v = g.get(k)
		if not (v is int or v is float):
			return {}
		out[k] = int(v)
	# V1.4 #3：契約獎勵可以疊在事件上（每站最多 +20 金或 +3 隻），上限放寬
	if out["pool"] <= 0 or out["stage"] < 2 or out["stage"] > 7 or out["gold"] < 0 or out["gold"] > 220 or out["cap"] < 0 or out["cap"] > 40:
		return {}
	var ctr = g.get("contract", -1)
	out["contract"] = clampi(int(ctr), -1, 5) if (ctr is int or ctr is float) else -1
	var cp = g.get("coop", 0)
	out["coop"] = 1 if (cp is int or cp is float) and int(cp) == 1 else 0   # V1.6 #21 雙人接力遠征
	var raw = g.get("prev")
	if not raw is Array or raw.size() > 80:
		return {}
	var prev: Array = []
	for u in raw:
		if not u is Dictionary or not u.has("type"):
			return {}
		# Codex v10-r1 #1：座標與兵種都要合法，少一項就整份不要（下一輪開場會直接讀）
		var free_u: bool = u.has("x") and u.has("y")
		var grid_u: bool = u.has("col") and u.has("row")
		if not (free_u or grid_u):
			return {}
		if int(u["type"]) < 0 or int(u["type"]) >= 20:
			return {}
		if free_u and (int(u["x"]) < 0 or int(u["x"]) > 18000 or int(u["y"]) < 0 or int(u["y"]) > 10000):
			return {}
		if grid_u and (int(u["col"]) < 0 or int(u["col"]) > 15 or int(u["row"]) < 0 or int(u["row"]) > 8):
			return {}
		var o := {}
		for k2 in u:
			var v2 = u[k2]
			if not (v2 is int or v2 is float):
				return {}
			o[str(k2)] = int(v2)
		if o.has("st") and (int(o["st"]) < 1 or int(o["st"]) > 6):
			o.erase("st")   # V1.4 #9 貼紙只收 1～6
		o.erase("boss")   # V1.4 #12：玩家陣型不會有巨獸（Codex v140-i5）
		prev.append(o)
	out["prev"] = prev
	# V1.1 D1：遠征路線的「下一戰敵方」事件。可有可無（舊續局沒有＝0），超出範圍歸 0
	for k3 in [["foe_gold", -10], ["foe_cap", -2]]:
		var fv = g.get(k3[0], 0)
		out[k3[0]] = int(fv) if (fv is int or fv is float) and int(fv) >= int(k3[1]) and int(fv) <= 0 else 0
	return out

## 逐版遷移（純函式，測試用）：舊進度一律保留；不認得的欄位也保留（新版遊戲寫的存檔被舊版讀到時不會被刪掉）。
## 比目前新的版本：原樣回傳，不降版。
static func migrate(d: Dictionary) -> Dictionary:
	var out := d.duplicate(true)
	var v := schema_of(out)
	if v > SAVE_VERSION:
		return out
	if v < 2:
		# 1 → 2：欄位名 version 改成 schema_version；加 unit_wins
		out.erase("version")
		v = 2
	if v < 3:
		# 2 → 3：解鎖改看獨立的累計場數，初值＝原本的正式場數（已解鎖的兵不會被收回）
		var st = out.get("stats", {})
		out["unlock_games"] = _count(st.get("games", 0)) if st is Dictionary else 0
		v = 3
	# 我的預設：逐筆驗型、限長、最多 5 組（Codex 第一輪）
	var ps: Array = []
	var raw = out.get("rule_presets", [])
	if raw is Array:
		for e in raw:
			if e is Dictionary and e.get("name") is String and e.get("code") is String and str(e["code"]).length() <= 2000 and ps.size() < MAX_PRESETS:
				ps.append({"name": str(e["name"]).substr(0, 24), "code": str(e["code"])})
	out["rule_presets"] = ps
	for k in DEFAULT_SAVE:
		if not out.has(k):
			out[k] = DEFAULT_SAVE[k].duplicate(true) if DEFAULT_SAVE[k] is Dictionary or DEFAULT_SAVE[k] is Array else DEFAULT_SAVE[k]
	sanitize_data(out)
	out["schema_version"] = v
	return out

## 原子寫入。R6：只有內容驗證過的主檔才輪替成備份；輪替失敗不覆蓋主檔。
static func _write(path: String, d: Dictionary) -> bool:
	var tmp := path + ".tmp"
	if fail_inject.get("tmp", 0) > 0:
		fail_inject["tmp"] -= 1
		return false
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	var txt := JSON.stringify(d, "\t")
	f.store_string(txt)
	f.close()
	# 讀回驗證：內容不完整（磁碟滿、被中斷）就不覆蓋正式檔
	if FileAccess.get_file_as_string(tmp) != txt:
		DirAccess.remove_absolute(tmp)
		return false
	if FileAccess.file_exists(path):
		if _parse(path) == null:
			_quarantine(path)   # 遊戲開著時主檔被弄壞：不能拿它蓋備份
		else:
			var rotated := false
			if fail_inject.get("rotate", 0) > 0:
				fail_inject["rotate"] -= 1
			else:
				var bt := path + ".bak.tmp"
				rotated = DirAccess.copy_absolute(path, bt) == OK and _parse(bt) != null and DirAccess.rename_absolute(bt, path + ".bak") == OK
				if not rotated:
					DirAccess.remove_absolute(bt)
			if not rotated:
				DirAccess.remove_absolute(tmp)
				return false
	return DirAccess.rename_absolute(tmp, path) == OK

static func _tracked_write(path: String, d: Dictionary) -> bool:
	var good := _write(path, d)
	if good:
		pending.erase(path)
	else:
		pending[path] = true
	return good

static func save_settings() -> bool:
	return _tracked_write(_sp(), settings)

## 未來版存檔（R5）一律不寫，回傳 true 是因為這不是「寫入失敗」，畫面已經常駐提示。
static func save_data() -> bool:
	if data_locked:
		return true
	return _tracked_write(_dp(), data)

static func has_unsaved() -> bool:
	return not pending.is_empty()

## R7：上次寫入失敗就再試一次（換畫面、回標題時呼叫）。回傳 true＝現在沒有未存內容。
static func retry_pending() -> bool:
	if pending.has(_sp()):
		save_settings()
	if pending.has(_dp()):
		save_data()
	return pending.is_empty()

static func s(key: String):
	return settings.get(key, DEFAULT_SETTINGS.get(key))

static func set_setting(key: String, v) -> void:
	settings[key] = v
	save_settings()

## V1.5：一次改很多項（預設組合、匯入設定碼）只寫一次檔。
static func set_settings(d: Dictionary) -> void:
	for k in d:
		settings[k] = d[k]
	save_settings()

## V1.5：備份檔能不能拿來還原：要是進度存檔（有版本欄），而且不是比這版新的格式。
static func restorable(d) -> bool:
	if not d is Dictionary:
		return false
	var v = d.get("schema_version", d.get("version"))
	if not (v is int or v is float) or int(v) < 1 or int(v) > SAVE_VERSION:
		return false
	# 要有進度存檔一定有的欄位（只有版本欄的 JSON 不算，Codex v150-i2 #2）
	return d.get("stats") is Dictionary and d.get("achievements") is Array


## V1.1 F2：本機遊玩紀錄（不上傳、不升存檔版本）。kind＝"puzzle"／"trial"：每打一次 +1；
## 第一次過關時記下當時的嘗試次數與花費（first＝花費、first_try＝第幾次）。之後重打不改，用來校準三星。
static func note_try(kind: String, id: String, cleared: bool, cost: int) -> void:
	var tries: Dictionary = data.get(kind + "_tries", {})
	tries[id] = int(tries.get(id, 0)) + 1
	data[kind + "_tries"] = tries
	var first: Dictionary = data.get(kind + "_first", {})
	if cleared and not first.has(id):
		first[id] = cost
		first[id + "@"] = int(tries[id])
	data[kind + "_first"] = first


## V1.5.1 E1：試玩回報只匯出這些欄位（白名單；沒有存檔、設定、帳號等任何個人資料）
const PT_FIELDS := ["v", "session", "game", "event", "mode", "round", "winner", "ticks", "reason", "power", "rating", "rules", "time", "code"]

## 把本機試玩紀錄整理成一份回報（只留白名單欄位）。回傳 {"n": 筆數, "text": 內容}
static func playtest_report(app_version: String) -> Dictionary:
	var path := "user://%splaytest_log.jsonl" % file_prefix()
	var rows: Array = []
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		while f != null and not f.eof_reached():
			var ln := f.get_line().strip_edges()
			if ln == "":
				continue
			var d = JSON.parse_string(ln)
			if not d is Dictionary:
				continue
			var keep := {}
			for k in PT_FIELDS:
				if d.has(k):
					keep[k] = d[k]
			rows.append(keep)
	var head := {"app": app_version, "os": OS.get_name(), "entries": rows.size()}
	return {"n": rows.size(), "text": JSON.stringify({"report": head, "rows": rows}, " ")}

## 試玩紀錄（優化方案 F5、N3）：只在設定開啟時寫在本機 user://playtest_log.jsonl，不上傳。
static func playtest_log(entry: Dictionary) -> void:
	if not bool(s("playtest")):
		return
	var path := "user://%splaytest_log.jsonl" % file_prefix()
	var f := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	entry["time"] = Time.get_datetime_string_from_system()
	f.store_line(JSON.stringify(entry))
