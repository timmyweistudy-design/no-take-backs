extends "res://scripts/ui/battle_view.gd"
## 兵種圖鑑（第二輪方案 R3）：五個兵種的故事、擅長／怕什麼、技能說明（數值取自 unit_defs），
## 每個技能有一段用「真的戰鬥模擬」跑的小劇場；派該兵種贏 5 場解鎖老兵觀察筆記。
## 入口：標題選單、擺放時兵種卡右上角的「?」（手把 Select）、結果頁右上角。

const CX = preload("res://scripts/game/codex.gd")

const CX_PANEL := Rect2(180, 96, 920, 628)
const CX_BOX := Rect2(596, 318, 474, 267)     # 小劇場畫面
const CX_VIEW := Rect2(2000, 1100, 12000, 6760)   # 小劇場看的戰場範圍（模擬座標，千分之一格）：中間 12×6.76 格，兵才夠大
const CX_PAUSE := 1.2                          # 一段示範結束後停多久再重播（秒）

var cx_unit := 0
var cx_skill := 0
var cx_sim = null
var cx_acc := 0.0
var cx_ticks := 0
var cx_wait := 0.0
var cx_prev := {}
var cx_atk := {}
var cx_hurt := {}
var cx_pops: Array = []        # 技能觸發時跳出的字：{p, s, t}
var cx_seen := false           # 這一輪示範有沒有出現預期的技能


func _open_codex(t: int) -> void:
	# 開圖鑑前取消擺放畫面的拖曳／塗兵狀態，不然關掉圖鑑後移動滑鼠會繼續放兵（Codex R3 審查 #3）
	painting = false
	drag_new = false
	drag_from = Vector2i(-1, -1)
	cx_unit = clampi(t, 0, D.COUNT - 1)
	_cx_pick_skill(0)
	_open("codex")


func _cx_skills() -> Array:
	return CX.unit(cx_unit).get("skills", [])


func _cx_pick_unit(t: int) -> void:
	cx_unit = t
	_cx_pick_skill(0)


func _cx_pick_skill(i: int) -> void:
	cx_skill = clampi(i, 0, maxi(0, _cx_skills().size() - 1))
	_cx_restart()


func _cx_restart() -> void:
	var sks := _cx_skills()
	cx_sim = CX.demo_sim(sks[cx_skill]) if not sks.is_empty() else null
	cx_acc = 0.0
	cx_ticks = 0
	cx_wait = 0.0
	cx_prev.clear()
	cx_atk.clear()
	cx_hurt.clear()
	cx_pops.clear()
	cx_seen = false


## 每幀推進小劇場（20 tick／秒，跟正式戰鬥同速）。
func _codex_tick(delta: float) -> void:
	for p in cx_pops:
		p["t"] += delta
	cx_pops = cx_pops.filter(func(p): return p["t"] < 1.1)
	if cx_sim == null:
		return
	var sk: String = _cx_skills()[cx_skill]
	var dm: Dictionary = CX.skill(sk).get("demo", {})
	var limit := int(dm.get("ticks", 120))
	if cx_sim.finished or cx_ticks >= limit:
		cx_wait += delta
		if cx_wait >= CX_PAUSE:
			_cx_restart()
		return
	cx_acc += delta
	while cx_acc >= 0.05 and not cx_sim.finished and cx_ticks < limit:
		cx_acc -= 0.05
		for u in cx_sim.units:
			cx_prev[u.id] = Vector2(u.x, u.y)
		cx_sim.step()
		cx_ticks += 1
		for e in cx_sim.events:
			if e.has("dmg"):
				cx_atk[e["src"]] = time
				cx_hurt[e["tgt"]] = time
		for hp in CX.expect_hits(cx_sim, str(dm.get("expect", ""))):
			cx_seen = true
			cx_pops.append({"p": hp, "s": CX.text(CX.skill(sk), "", L.lang) + "！", "t": 0.0})
			if cx_pops.size() > 4:
				cx_pops.pop_front()


func _cx_pos(u) -> Vector2:
	var cur := Vector2(u.x, u.y)
	var p: Vector2 = cx_prev.get(u.id, cur).lerp(cur, clampf(cx_acc / 0.05, 0.0, 1.0))
	return _cx_map(p)


func _cx_map(p: Vector2) -> Vector2:
	var q := CX_BOX.position + (p - CX_VIEW.position) * (CX_BOX.size.x / CX_VIEW.size.x)
	return q.clamp(CX_BOX.position + Vector2(10, 30), CX_BOX.end - Vector2(10, 4))


## 依寬度換行：中文一字一字量，英文以空白為界。
func _wrap(s: String, size: int, width: float) -> String:
	var out: PackedStringArray = []
	for para in s.split("\n"):
		var line := ""
		var tokens: Array = []
		var word := ""
		for ch in para:
			if ch == " ":
				tokens.append(word + " ")
				word = ""
			elif ch.unicode_at(0) > 0x2E80:
				if word != "":
					tokens.append(word)
					word = ""
				tokens.append(ch)
			else:
				word += ch
		if word != "":
			tokens.append(word)
		for tk in tokens:
			if line != "" and font.get_string_size(line + tk, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
				out.append(line.strip_edges(false, true))
				line = tk.strip_edges(true, false) if tk == " " else tk
			else:
				line += tk
		out.append(line)
	return "\n".join(out)


func _draw_codex() -> void:
	_panel(CX_PANEL)
	var u := CX.unit(cx_unit)
	var lang := L.lang
	_text(Vector2(640, 108), L.t("codex_title"), ts(26), Color.WHITE, true, true)
	# 兵種分頁
	for t in D.COUNT:
		var r := Rect2(204 + t * 176, 152, 168, 42)
		_btn(r, L.t("unit_%d" % t), _cx_pick_unit.bind(t), true, false, Color(0.26, 0.31, 0.45) if t == cx_unit else Color(0, 0, 0, 0))
	# 左欄：大頭照、名字、定位、口號、數值
	var pc := Vector2(282, 352)
	draw_circle(pc + Vector2(0, -30), 62, Color(1, 1, 1, 0.05), true, -1.0, true)
	_ring(pc, 0, cx_unit, 2.0)
	_unit(pc, cx_unit, 0, 1.0, 0.0, 0.0, 0.0, 1.0, time, 2.0)
	_text(Vector2(372, 212), L.t("unit_%d" % cx_unit), ts(26), Color.WHITE, false, true)
	_text(Vector2(372, 250), CX.text(u, "role", lang), ts(16), Color(1, 1, 1, 0.8))
	_text(Vector2(372, 276), "「%s」" % CX.text(u, "tagline", lang) if lang == "zh_TW" else "\"%s\"" % CX.text(u, "tagline", lang), ts(16), ACCENT)
	var st: Dictionary = D.STATS[cx_unit]
	_text(Vector2(372, 304), _wrap(L.t("codex_stats", [int(st["cost"]), int(st["hp"]), int(st["atk"]), float(st["reach"]) / 1000.0, float(st["speed"]) * 20.0 / 1000.0]), ts(14), 200), ts(14), Color(1, 1, 1, 0.7))
	var y := 392.0
	var story := _wrap(CX.text(u, "story", lang), ts(16), 368)
	_text(Vector2(204, y), story, ts(16), Color(1, 1, 1, 0.92))
	y += (story.count("\n") + 1) * ts(16) * 1.3 + 14
	var good := _wrap("✓ " + CX.text(u, "good", lang), ts(15), 368)
	_text(Vector2(204, y), good, ts(15), Color("#7dff8a"))
	y += (good.count("\n") + 1) * ts(15) * 1.3 + 8
	_text(Vector2(204, y), _wrap("✗ " + CX.text(u, "bad", lang), ts(15), 368), ts(15), Color("#ff9b9b"))
	# 右欄：技能分頁、說明、小劇場
	var sks := _cx_skills()
	var bw := (CX_BOX.size.x - (sks.size() - 1) * 8) / maxf(1.0, sks.size())
	for i in sks.size():
		var sd := CX.skill(sks[i])
		_btn(Rect2(CX_BOX.position.x + i * (bw + 8), 212, bw, 38), CX.text(sd, "", lang), _cx_pick_skill.bind(i), true, false,
			Color(0.45, 0.3, 0.12) if i == cx_skill else Color(0, 0, 0, 0))
	if not sks.is_empty():
		_text(Vector2(CX_BOX.position.x, 258), _wrap(CX.skill_desc(sks[cx_skill], lang), ts(15), CX_BOX.size.x), ts(15), Color(1, 1, 1, 0.92))
	_draw_codex_demo()
	# 老兵觀察筆記
	var nr := Rect2(204, 600, 866, 66)
	draw_rect(nr, Color(0.2, 0.17, 0.1, 0.85))
	draw_rect(nr, Color(ACCENT, 0.35), false, 1.5)
	_text(nr.position + Vector2(12, 6), L.t("codex_note"), ts(14), ACCENT, false, true)
	var unlocked := CX.note_unlocked(Save.data, cx_unit)
	var note := CX.text(u, "veteran", lang) if unlocked else L.t("codex_note_locked", [L.t("unit_%d" % cx_unit), CX.NOTE_WINS, mini(CX.wins_with(Save.data, cx_unit), CX.NOTE_WINS), CX.NOTE_WINS])
	_text(nr.position + Vector2(12, 30), _wrap(note, ts(14), nr.size.x - 24), ts(14), Color(1, 1, 1, 0.9 if unlocked else 0.55))
	_btn(Rect2(560, 676, 160, 38), L.t("back"), func(): overlay = "")


func _draw_codex_demo() -> void:
	var b := CX_BOX
	draw_rect(b, Color("#5f8f3a"))
	var k := b.size.x / CX_VIEW.size.x
	var cs := 1000.0 * k
	for c in range(2, 14):
		for r in range(1, 8):
			if (c + r) % 2 == 0:
				var cell := Rect2(b.position + (Vector2(c, r) * 1000.0 - CX_VIEW.position) * k, Vector2(cs, cs)).intersection(b)
				if cell.has_area():
					draw_rect(cell, Color(1, 1, 1, 0.05))
	for c in [6, 10]:
		var x: float = b.position.x + (c * 1000.0 - CX_VIEW.position.x) * k
		draw_dashed_line(Vector2(x, b.position.y), Vector2(x, b.end.y), Color(Art.team_color(0 if c == 6 else 1, cbm()), 0.6), 2.0, 6.0)
	if cx_sim != null:
		var list: Array = []
		for u in cx_sim.units:
			if u.alive:
				list.append(u)
		list.sort_custom(func(a, c): return a.y < c.y)
		var sc := 0.72
		for u in list:
			_ring(_cx_pos(u), u.team, u.type, sc)
		for u in list:
			var p := _cx_pos(u)
			var moving: bool = u.mx != 0 or u.my != 0
			var at := 0.0
			if cx_atk.has(u.id):
				at = clampf((time - cx_atk[u.id]) / 0.25, 0, 1)
				if at >= 1:
					at = 0
			var hurt := 0.0
			if cx_hurt.has(u.id) and bool(Save.s("flash")):
				hurt = clampf(1.0 - (time - cx_hurt[u.id]) / 0.15, 0, 1)
			var face := signf(u.fx) if u.fx != 0 else (1.0 if u.team == 0 else -1.0)
			_unit(p, u.type, u.team, face, (time * 10.0 + u.id) if moving else 0.0, at, hurt, 0.45 if u.stealth > 0 else 1.0, time, sc)
			if u.stun > 0:
				_text(p + Vector2(0, -60), "✦", ts(14), Color.YELLOW, true)
			if u.hp < u.max_hp:
				var w := 24.0
				var top := p + Vector2(-w / 2, -52 if u.type == D.CAVALRY else -46)
				draw_rect(Rect2(top - Vector2(1, 1), Vector2(w + 2, 5)), Art.OUT)
				draw_rect(Rect2(top, Vector2(w * u.hp / u.max_hp, 3)), Art.team_color(u.team, cbm()).lightened(0.25))
	for pp in cx_pops:
		var kk: float = pp["t"] / 1.1
		var q: Vector2 = _cx_map(pp["p"]) + Vector2(0, -66 - kk * 26)
		_text(q, pp["s"], ts(16), Color(ACCENT, 1.0 - kk * kk), true, true)
	draw_rect(b, Color(1, 1, 1, 0.25), false, 1.5)
	_text(b.position + Vector2(8, 4), L.t("codex_demo"), ts(13), Color(1, 1, 1, 0.75))
