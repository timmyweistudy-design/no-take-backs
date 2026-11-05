extends "res://scripts/ui/screens/game_result.gd"
## V9 P6 模式：主題試煉、挑戰碼、遠征獎勵、雙人禁選、戰績頁、牌組。

## 主題試煉：10 關固定地圖＋AI 性格，玩家自己組牌。[地圖, 大小, 性格, 難度]
const TRIALS := [[1, 1, 2, 1], [2, 1, 3, 1], [3, 1, 3, 1], [4, 1, 1, 1], [5, 1, 4, 1],
	[1, 0, 1, 2], [2, 2, 4, 2], [3, 2, 2, 2], [4, 0, 3, 2], [5, 2, 5, 2]]

var trial_id := -1
var challenge_army = null       # 挑戰碼的對手陣型
var gauntlet_gold := 0
var gauntlet_cap := 0
var ban_left := [0, 0]
var ban_turn := 0

## ── 主題試煉 ──
func _start_trial(i: int) -> void:
	var t: Array = TRIALS[i]
	var r = Presets.make("standard", "ai", RS.unlocked_mask(_unlock_games(), _demo()))
	r.deploy = "free"
	r.spacing = 800
	r.depth = 6000
	r.fullfield = 0
	r.map_id = int(t[0])
	r.map_size = int(t[1])
	var s: Array = MapDefs.SIZE_SUGGEST[r.map_size]
	r.budget = [int(s[0]), int(s[0])]
	r.unit_cap = int(s[1])
	r.ticks = int(s[2])
	r.rounds = 1
	r.ai_level = int(t[3])
	r.ai_style = int(t[2])
	r.ai_pool_same = false
	var p := 0
	if AI.STYLE_TYPES.has(r.ai_style):
		for x in AI.STYLE_TYPES[r.ai_style]:
			p |= 1 << int(x)
	else:
		p = RuleSet.all_pool()
	r.pool[1] = p
	r.preset = "custom"
	rules = r
	challenge_army = null      # 上一場挑戰碼的敵陣不能留到試煉（Codex #5）
	rng.seed = 7000 + i        # 同一關每次是同一支隊伍
	_start_mode(Mode.VS_AI)
	trial_id = i

## 結算星數：贏＝1；剩餘戰力 ≥50%＝2；只花 ≤80% 預算＝3。
func _trial_finish(w: int) -> void:
	if trial_id < 0 or w != 0:
		return
	var st := 1
	if sim.power(0) * 100 >= sim.budget_of(0) * 1000 * 50:
		st = 2
		if armies[0].spent() * 100 <= armies[0].budget * 80:
			st = 3
	var all: Dictionary = Save.data.get("trial_stars", {})
	all[str(trial_id)] = maxi(int(all.get(str(trial_id), 0)), st)
	Save.data["trial_stars"] = all
	report["trial_stars"] = st
	Save.save_data()

func _draw_trials() -> void:
	var P := Rect2(90, 40, 1100, 720)
	_panel(P)
	_h1(Vector2(640, 50), L.t("trial_title"))
	_text(Vector2(640, 104), L.t("trial_rule"), tz("S"), Color(1, 1, 1, 0.8), true, false, 1000)
	var stars: Dictionary = Save.data.get("trial_stars", {})
	var cw := 524.0
	var ch := 98.0
	for i in TRIALS.size():
		var t: Array = TRIALS[i]
		var r := Rect2(116 + (i % 2) * (cw + 8), 164 + (i / 2) * (ch + 7), cw, ch)
		_btn(r, "", _start_trial.bind(i), true, false, TH_WOOD)
		call("_map_thumb", Rect2(r.position + Vector2(8, 8), Vector2(136, 84)), int(t[0]), int(t[1]))
		_text(r.position + Vector2(154, 8), "%d. %s" % [i + 1, L.t("map_" + str(MapDefs.MAPS[t[0]]["key"]))], tz("B"), Color.WHITE, false, true, cw - 240)
		var sz := "%s %d×%d" % [L.t("map_size_%d" % int(t[1])), MapDefs.SIZES[t[1]][0], MapDefs.SIZES[t[1]][1]]
		_text(r.position + Vector2(154, 8 + tz("B") * 1.4), "%s・%s・%s" % [sz, L.t("ai_style_%d" % int(t[2])), L.t(["diff_easy", "diff_normal", "diff_hard"][int(t[3])])], tz("C"), Color(1, 1, 1, 0.72), false, false, cw - 165)
		var got := int(stars.get(str(i), 0))
		for k in 3:
			_icon("star", r.position + Vector2(cw - 66 + k * 22, 20), 20.0, Color("#ffd166") if k < got else Color(1, 1, 1, 0.16))
	_btn(Rect2(560, 700, 160, 44), L.t("back"), func(): overlay = "")

## ── 挑戰碼：把自己的陣型傳給朋友打（不需要伺服器）──
func _challenge_encode() -> String:
	var r = rules if rules != null else RuleSet.standard()
	var j := JSON.stringify({"a": last_armies[0].to_code(), "r": r.to_code()})
	var b := Marshalls.utf8_to_base64(j).replace("+", "-").replace("/", "_").replace("=", "")
	return "NTC1.%s.%s" % [b, b.sha256_text().substr(0, 6)]

func _copy_challenge() -> void:
	DisplayServer.clipboard_set(_challenge_encode())
	_toast(L.t("ch_copied"))

func _accept_challenge(c := "") -> void:
	var from_clip := c == ""
	if from_clip:
		c = DisplayServer.clipboard_get().strip_edges()
	var d := _challenge_decode(c.strip_edges())
	if not d["ok"]:
		if not (from_clip and _ask_code(L.t("ch_accept"), _accept_challenge)):
			_toast(L.t("ch_bad"), true)
		return
	rules = d["rules"]
	challenge_army = d["army"]
	rules.rounds = 1
	_start_mode(Mode.VS_AI)

## 回傳 {ok, rules, army}。陣型一定要照那組規則合法。
func _challenge_decode(c: String) -> Dictionary:
	var bad := {"ok": false}
	var parts := c.split(".")
	if c.length() > 6000 or parts.size() != 3 or parts[0] != "NTC1" or parts[1].sha256_text().substr(0, 6) != parts[2]:
		return bad
	var b64 := parts[1].replace("-", "+").replace("_", "/")
	while b64.length() % 4 != 0:
		b64 += "="
	var j = JSON.parse_string(Marshalls.base64_to_utf8(b64))
	if not j is Dictionary or not j.get("a") is String or not j.get("r") is String:
		return bad
	var rd: Dictionary = RuleSet.from_code(str(j["r"]))
	if not rd["ok"] or rd["rules"].fullfield != RuleSet.FULL_NONE:
		return bad      # 全場規則是雙方互相看得到才成立，不能當挑戰碼（Codex r2 #3）
	var r = rd["rules"]
	r.ai_pool_same = false
	# 碼是對方當藍軍排的，到這裡他變紅軍：兩邊的預算、卡池要對調（讓子局才有差，Codex #10）
	var b0: int = r.budget_of(0)
	var b1: int = r.budget_of(1)
	var p0: int = r.pool_of(0)
	var p1: int = r.pool_of(1)
	r.budget = [b1, b0]
	r.pool = [p1, p0]
	var a = Army.new(1, r.budget_of(1))
	a.apply_rules(r, 1)
	a.pool = RuleSet.full_pool()     # 朋友的牌不必在自己的解鎖範圍內
	if a.load_code(str(j["a"])) != "" or not a.has_combat():
		return bad
	if _demo() and not _demo_ok(r, a):
		return bad      # 第十輪 B7：試玩版不能靠挑戰碼帶進正式版內容
	return {"ok": true, "rules": r, "army": a}

## 第十輪 R1：試玩版的範圍集中在這裡。匯入的規則與陣型都走這條。
func _demo_ok(r, a = null) -> bool:
	var mask: int = RS.unlocked_mask(1 << 20, true)
	if r != null:
		if not r.map_id in Presets.DEMO_MAPS:
			return false
		if r.pool_of(0) & ~mask != 0 or r.pool_of(1) & ~mask != 0:
			return false
	if a != null:
		for u in a.units:
			if not RuleSet.has(mask, int(u["type"])):
				return false
	return true

## ── 遠征：每戰後三選一 ──
func _gauntlet_reward() -> void:
	overlay = "reward"

func _take_reward(k: int) -> void:
	overlay = ""
	match k:
		0:
			gauntlet_gold += 10
		1:
			gauntlet_cap += 2
	call("_gauntlet_next")
	if k == 2:
		gauntlet_changes += 2
	call("_gauntlet_save")

func _draw_reward() -> void:
	var P := Rect2(240, 200, 800, 380)
	_panel(P)
	_h1(Vector2(640, 212), L.t("rw_title"))
	var items := [["coin", "rw_gold"], ["people", "rw_cap"], ["swap", "rw_change"]]
	for i in 3:
		var r := Rect2(268 + i * 252, 290, 240, 200)
		_btn(r, "", _take_reward.bind(i), true, false, TH_WOOD_L)
		_icon(items[i][0], r.position + Vector2(120, 58), 64.0, ACCENT)
		_text(r.position + Vector2(120, 104), L.t(items[i][1]), tz("B"), Color.WHITE, true, true, 220)
		_text(r.position + Vector2(120, 104 + tz("B") * 1.5), L.t(items[i][1] + "_d"), tz("C"), Color(1, 1, 1, 0.75), true, false, 220)
	_text(Vector2(640, 512), L.t("rw_now", [gauntlet_gold, gauntlet_cap]), tz("S"), Color(1, 1, 1, 0.75), true, false, 740)

## ── 雙人：輪流禁選 ──
func _begin_bans(n: int) -> void:
	# 卡池太小時少禁幾張，至少留 3 種（Codex #6：5 種禁 2＋2 會卡死）
	n = mini(n, (mini(RuleSet.pool_count(rules.pool_of(0)), RuleSet.pool_count(rules.pool_of(1))) - 3) / 2)
	if n <= 0:
		_start_mode(Mode.DUEL)
		return
	ban_left = [n, n]
	ban_turn = 0
	overlay = "ban"

func _ban_skip() -> void:
	ban_left[ban_turn] -= 1
	_ban_next()

func _ban_next() -> void:
	ban_turn = 1 - ban_turn
	if ban_left[ban_turn] <= 0:
		ban_turn = 1 - ban_turn
	if ban_left[0] <= 0 and ban_left[1] <= 0:
		overlay = ""
		_start_mode(Mode.DUEL)

func _ban(t: int) -> void:
	# 兩邊卡池可能不同：各自拿掉（Codex r2 #2）
	var np := [rules.pool_of(0) & ~(1 << t), rules.pool_of(1) & ~(1 << t)]
	for tm in 2:
		var p: int = np[tm]
		if not RuleSet.has_combat(p) or RuleSet.pool_count(p) < 3 or RuleSet.cheapest_combat_in(p) > rules.budget_of(tm):
			_toast(L.t("ban_no"), true)
			return
	rules.pool = np
	ban_left[ban_turn] -= 1
	sfx.play("k_error")
	_ban_next()

## 第十輪 B2：雙方卡池不同時最多 20 張；超過 10 張改小格，全部留在面板內。
func _ban_cell(i: int, n: int) -> Rect2:
	if n <= 10:
		return Rect2(200 + (i % 5) * 178, 250 + (i / 5) * 190, 168, 178)
	return Rect2(188 + (i % 7) * 130, 236 + (i / 7) * 138, 124, 130)

func _draw_ban() -> void:
	var P := Rect2(170, 110, 940, 560)
	_panel(P)
	_box(P.grow(-3), Color(0, 0, 0, 0), Color("#b8393f"), 8.0, 3.0)   # 紅框：這裡是拿掉牌，不是選牌
	_h1(Vector2(640, 122), L.t("ban_title"))
	var who := L.t("blue") if ban_turn == 0 else L.t("red")
	_text(Vector2(640, 186), L.t("ban_turn", [who, ban_left[ban_turn]]), tz("H2"), Art.team_color(ban_turn, cbm()).lightened(0.2), true, true, 860)
	var ts0: Array = RuleSet.types_of(rules.pool_of(0) | rules.pool_of(1))
	for i in ts0.size():
		var t: int = ts0[i]
		var r: Rect2 = _ban_cell(i, ts0.size())
		var small: bool = ts0.size() > 10
		_btn(r, "", _ban.bind(t), true, false, TH_WOOD)
		_unit_in(Rect2(r.position, Vector2(r.size.x, 84 if small else 120)), t, 0, 1.0, 0.8 if small else 1.1)
		_text(r.position + Vector2(r.size.x / 2, 88 if small else 128), L.t("unit_%d" % t), tz("C") if small else tz("B"), Color.WHITE, true, true, r.size.x - 8)
		if r.has_point(mouse) and not pad_mode:
			_icon("ban", r.position + Vector2(r.size.x / 2, 42 if small else 62), 60.0 if small else 84.0)
	_btn(Rect2(1000, 124, 96, 40), L.t("ban_skip"), _ban_skip)

## ── 戰績 ──
func _record_match(w: int) -> void:
	if armies.is_empty() or armies[0] == null:
		return
	var ug: Dictionary = Save.data.get("unit_games", {})
	var seen := {}
	for u in armies[0].units:
		seen[str(int(u["type"]))] = true
	if mode == Mode.DUEL and armies.size() > 1 and armies[1] != null:   # 第十輪 B4：雙人兩邊贏了都算勝場，場數也要兩邊算
		for u2 in armies[1].units:
			seen[str(int(u2["type"]))] = true
	for k in seen:
		ug[k] = int(ug.get(k, 0)) + 1
	Save.data["unit_games"] = ug
	if mode == Mode.DUEL:
		return    # 連勝只算單人
	if w == 0:
		Save.data["streak"] = int(Save.data.get("streak", 0)) + 1
		Save.data["best_streak"] = maxi(int(Save.data.get("best_streak", 0)), int(Save.data["streak"]))
	else:
		Save.data["streak"] = 0

func _draw_profile() -> void:
	var P := Rect2(50, 24, 1180, 752)
	_panel(P)
	_h1(Vector2(640, 34), L.t("pf_title"))
	var st: Dictionary = Save.data.get("stats", {})
	var cs: Dictionary = Save.data.get("custom_stats", {})
	var g: int = int(st.get("games", 0)) + int(cs.get("games", 0))
	var wn: int = int(st.get("wins", 0)) + int(cs.get("wins", 0))
	var trial := 0
	for v in Save.data.get("trial_stars", {}).values():
		trial += int(v)
	var tiles := [["swords", "pf_games", str(g)], ["trophy", "pf_wins", "%d%%" % (wn * 100 / maxi(1, g))], ["repeat", "pf_streak", "%d / %d" % [int(Save.data.get("streak", 0)), int(Save.data.get("best_streak", 0))]],
		["tower", "pf_trials", "%d / %d" % [trial, TRIALS.size() * 3]], ["road", "pf_gauntlet", "%d / 7" % int(Save.data.get("gauntlet_best", 0))]]
	var tw := 212.0
	for i in tiles.size():
		var r := Rect2(78 + i * (tw + 8), 92, tw, 80)
		_box(r, Color(0, 0, 0, 0.24), Color(0, 0, 0, 0), 7.0)
		_icon(tiles[i][0], r.position + Vector2(30, 40), 34.0, ACCENT)
		_text(r.position + Vector2(56, 10), L.t(tiles[i][1]), tz("C"), Color(1, 1, 1, 0.72), false, false, tw - 62)
		_text(r.position + Vector2(56, 34), tiles[i][2], tz("H2"), Color.WHITE, false, true, tw - 62)
	# 兵種勝率
	_text(Vector2(80, 184), L.t("pf_units"), tz("B"), ACCENT, false, true, 600)
	var ug: Dictionary = Save.data.get("unit_games", {})
	var uw: Dictionary = Save.data.get("unit_wins", {})
	var um := RS.unlocked_mask(_unlock_games(), _demo())
	var cw := 108.0
	for t in D.total():
		var r2 := Rect2(78 + (t % 10) * (cw + 4), 212 + (t / 10) * 116, cw, 110)
		_box(r2, Color(0, 0, 0, 0.2), Color(0, 0, 0, 0), 6.0)
		var open: bool = RuleSet.has(um, t)
		_unit_in(Rect2(r2.position, Vector2(cw, 70)), t, 0, 1.0 if open else 0.3, 0.62)
		var gg := int(ug.get(str(t), 0))
		var line := "—" if gg == 0 else "%d%%" % mini(100, int(uw.get(str(t), 0)) * 100 / gg)
		_text(r2.position + Vector2(cw / 2, 68), line, tz("B"), Color.WHITE, true, true, cw - 6)
		if gg > 0:
			pass
	# 成就
	var earned: Array = Save.data.get("achievements", [])
	var ach: Dictionary = SteamApi.ACHIEVEMENTS
	var keys := ach.keys()
	_text(Vector2(80, 448), L.t("pf_ach", [earned.size(), keys.size()]), tz("B"), ACCENT, false, true, 600)
	for i2 in keys.size():
		var k: String = keys[i2]
		var on: bool = k in earned
		var pos := Vector2(84 + (i2 % 3) * 372, 480 + (i2 / 3) * 30)
		_icon("star" if on else "lock", pos + Vector2(10, 12), 20.0, Color("#ffd166") if on else Color(1, 1, 1, 0.3))
		_text(pos + Vector2(26, 0), str(ach[k][0 if L.lang == "zh_TW" else 1]), tz("C"), Color.WHITE if on else Color(1, 1, 1, 0.66), false, false, 340)
	_btn(Rect2(560, 722, 160, 44), L.t("back"), func(): overlay = "")

## ── 殘局提示：只給方向，不給解 ──
func _puzzle_hint() -> void:
	var cnt := {}
	for u in armies[1].units:
		var t := int(u["type"])
		cnt[t] = int(cnt.get(t, 0)) + D.cost(t)
	var top := -1
	for t2 in cnt:
		if top < 0 or int(cnt[t2]) > int(cnt[top]):
			top = t2
	if top < 0:
		return
	var who := ""
	for x in D.total():
		if top in AIT.BEATS[x] and _allowed(x):
			who = L.t("unit_%d" % x)
			break
	_toast(L.t("hint_main", [L.t("unit_%d" % top)]) if who == "" else L.t("hint_counter", [L.t("unit_%d" % top), who]))
