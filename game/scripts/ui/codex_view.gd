extends "res://scripts/ui/battle_view.gd"
## 兵種圖鑑（第二輪方案 R3）：五個兵種的故事、擅長／怕什麼、技能說明（數值取自 unit_defs），
## 每個技能有一段用「真的戰鬥模擬」跑的小劇場；派該兵種贏 5 場解鎖老兵觀察筆記。
## 入口：標題選單、擺放時兵種卡右上角的「?」（手把 Select）、結果頁右上角。

const CX = preload("res://scripts/game/codex.gd")

const CX_PANEL := Rect2(180, 96, 920, 628)
const CX_BOX := Rect2(596, 318, 474, 267)     # 小劇場畫面
const CX_VIEW := Rect2(2000, 1100, 12000, 6760)   # 小劇場看的戰場範圍（模擬座標，千分之一格）：中間 12×6.76 格，兵才夠大
const CX_PAUSE := 1.2
const CX_LEFT := Rect2(204, 204, 376, 388)     # 左欄可捲動區
const CX_DESC := Rect2(596, 256, 474, 58)      # 技能說明可捲動區                          # 一段示範結束後停多久再重播（秒）

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
var cx_seen := false
var cx_scroll := {"left": 0.0, "desc": 0.0, "note": 0.0}   # 各捲動區的位移
var cx_content := {"left": 0.0, "desc": 0.0, "note": 0.0}  # 各捲動區的內容高度（上一幀量到的）
var cx_regions := {}                                         # 名稱 → 畫面上的矩形（滾輪判斷用）           # 這一輪示範有沒有出現預期的技能


func _open_codex(t: int) -> void:
	# 開圖鑑前取消擺放畫面的拖曳／塗兵狀態，不然關掉圖鑑後移動滑鼠會繼續放兵（Codex R3 審查 #3）
	painting = false
	drag_new = false
	drag_from = Vector2i(-1, -1)
	cx_unit = clampi(t, 0, D.COUNT - 1)
	cx_scroll["left"] = 0.0   # 每次打開都從頂端開始（Antigravity：沿用上次捲到底的位置，看起來像數值條不見了）
	cx_scroll["note"] = 0.0
	_cx_pick_skill(0)
	_open("codex")


func _cx_skills() -> Array:
	return CX.unit(cx_unit).get("skills", [])


func _cx_pick_unit(t: int) -> void:
	cx_unit = t
	cx_scroll["left"] = 0.0
	cx_scroll["note"] = 0.0
	_cx_pick_skill(0)


func _cx_pick_skill(i: int) -> void:
	cx_scroll["desc"] = 0.0
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


## 一組段落要放進 max_h 高度：從 size 開始縮，直到換行後的總高度放得下（段落間距 gap）。最小 10px。
func _fit_block(texts: Array, size: int, width: float, max_h: float, gap: float) -> int:
	var sz := size
	while sz > 10:
		var h := 0.0
		for tx in texts:
			h += (_wrap(tx, sz, width).count("\n") + 1) * sz * 1.3 + gap
		if h - gap <= max_h:
			return sz
		sz -= 1
	return sz


func _draw_codex() -> void:
	_panel(CX_PANEL)
	var u := CX.unit(cx_unit)
	var lang := L.lang
	_text(Vector2(640, 108), L.t("codex_title"), ts(26), Color.WHITE, true, true, 600)
	# 兵種分頁
	# 第四輪 §4.7：一排 10 個「頭像＋數字」頁籤；兵種全名在下面左欄的大標題
	var tw := (866.0 - (D.COUNT - 1) * 6.0) / D.COUNT
	for t in D.COUNT:
		var r := Rect2(204 + t * (tw + 6.0), 150, tw, 46)
		_btn(r, "", _cx_pick_unit.bind(t), true, false, Color(0.26, 0.31, 0.45) if t == cx_unit else Color(0, 0, 0, 0))
		Art.unit(self, r.position + Vector2(tw / 2.0 + 4, 60 if t != D.CAVALRY else 66), t, 0, 1.0, 0.0, 0.0, 0.0, 1.0, time, 0.72, cbm())
		_text(r.position + Vector2(4, 2), str((t + 1) % 10), tcap(ts(12), 14), Color(1, 1, 1, 0.7), false, true)
	# 左欄（第三輪 U1）：可捲動區，字級＝基準×設定（150% 時正文 24px），不再縮字
	# 大頭照＋名字固定在上面，只有下面的屬性與文字捲動（Antigravity S3：捲動時大頭照整張消失像破圖）
	var items := _cx_left_items(u, lang)
	# 固定區的高度依名字、定位、口號實際換行後的高度決定（Antigravity S3 第 2 輪：英文 150% 口號被切）
	var head_h := 160.0
	var ty := 4.0
	for tx in items[0]["texts"]:
		ty += (_wrap(tx["s"], tx["size"], CX_LEFT.size.x - 168).count("\n") + 1) * tx["size"] * 1.3 + 3.0
	head_h = clampf(maxf(head_h, ty + 8.0), 160.0, 260.0)
	_scroll_draw("head", Rect2(CX_LEFT.position, Vector2(CX_LEFT.size.x, head_h)), [items[0]], false)
	draw_line(Vector2(CX_LEFT.position.x, CX_LEFT.position.y + head_h - 2), Vector2(CX_LEFT.end.x, CX_LEFT.position.y + head_h - 2), Color(1, 1, 1, 0.12), 1.0)
	_scroll_draw("left", Rect2(CX_LEFT.position + Vector2(0, head_h + 4), CX_LEFT.size - Vector2(0, head_h + 4)), items.slice(1))
	# 右欄：技能分頁、說明、小劇場
	var sks := _cx_skills()
	var bw := (CX_BOX.size.x - (sks.size() - 1) * 8) / maxf(1.0, sks.size())
	for i in sks.size():
		var sd := CX.skill(sks[i])
		_btn(Rect2(CX_BOX.position.x + i * (bw + 8), 212, bw, 38), CX.text(sd, "", lang), _cx_pick_skill.bind(i), true, false,
			Color(0.45, 0.3, 0.12) if i == cx_skill else Color(0, 0, 0, 0))
	if not sks.is_empty():
		var desc := CX.skill_desc(sks[cx_skill], lang)
		_scroll_draw("desc", CX_DESC, [{"type": "text", "s": desc, "size": ts(15), "c": Color(1, 1, 1, 0.92), "x": 0.0, "w": CX_DESC.size.x - 12}])
	_draw_codex_demo()
	# 老兵觀察筆記
	var nr := Rect2(204, 600, 866, 66)
	draw_rect(nr, Color(0.2, 0.17, 0.1, 0.85))
	draw_rect(nr, Color(ACCENT, 0.35), false, 1.5)
	_text(nr.position + Vector2(12, 4), L.t("codex_note"), ts(14), ACCENT, false, true, 400)
	var unlocked := CX.note_unlocked(Save.data, cx_unit)
	var note := CX.text(u, "veteran", lang) if unlocked else L.t("codex_note_locked", [L.t("unit_%d" % cx_unit), CX.NOTE_WINS, mini(CX.wins_with(Save.data, cx_unit), CX.NOTE_WINS), CX.NOTE_WINS])
	_scroll_draw("note", Rect2(nr.position + Vector2(12, 4 + ts(14) * 1.4), Vector2(nr.size.x - 20, nr.size.y - 8 - ts(14) * 1.4)),
		[{"type": "text", "s": note, "size": ts(14), "c": Color(1, 1, 1, 0.9 if unlocked else 0.55), "x": 0.0, "w": nr.size.x - 40}])
	_btn(Rect2(560, 676, 160, 38), L.t("back"), func(): overlay = "")


## ── 捲動區（第三輪 U1）──
## 圖鑑全部是自繪，所以不用 ScrollContainer（混用 Control 會有焦點問題）：
## 內容依實際字高往下排；只畫「整行都在區域內」的行，所以不會有半個字；內容比區域高時右邊畫捲軸。
## 滾輪捲滑鼠所在的區域；手把右搖桿與 PageUp／PageDown 捲左欄。
func _scroll_by(name: String, dy: float) -> void:
	var r: Rect2 = cx_regions.get(name, Rect2())
	var maxs := maxf(0.0, float(cx_content.get(name, 0.0)) - r.size.y)
	cx_scroll[name] = clampf(float(cx_scroll.get(name, 0.0)) + dy, 0.0, maxs)

func _scroll_at(p: Vector2, dy: float) -> bool:
	for name in cx_regions:
		if cx_regions[name].has_point(p):
			_scroll_by(name, dy)
			return true
	return false

## 左欄內容：大頭照＋名字、定位、口號；屬性條；故事、擅長、怕。
func _cx_left_items(u: Dictionary, lang: String) -> Array:
	var tag := "「%s」" % CX.text(u, "tagline", lang) if lang == "zh_TW" else "\"%s\"" % CX.text(u, "tagline", lang)
	var items: Array = [
		{"type": "portrait", "h": 150.0, "texts": [
			{"s": L.t("unit_%d" % cx_unit), "size": ts(26), "c": Color.WHITE, "bold": true},
			{"s": CX.text(u, "role", lang), "size": ts(15), "c": Color(1, 1, 1, 0.8)},
			{"s": tag, "size": ts(15), "c": ACCENT}]},
		{"type": "ranks"},
		{"type": "counters"},
		{"type": "text", "s": "✓ " + CX.text(u, "good", lang), "size": ts(15), "c": Color("#7dff8a"), "x": 0.0, "w": 356.0, "gap": 6.0},
		{"type": "text", "s": "✗ " + CX.text(u, "bad", lang), "size": ts(15), "c": Color("#ff9b9b"), "x": 0.0, "w": 356.0, "gap": 12.0},
		{"type": "text", "s": L.t("codex_story_h"), "size": ts(15), "c": Color(1, 1, 1, 0.6), "x": 0.0, "w": 356.0, "gap": 2.0},
		{"type": "text", "s": CX.text(u, "story", lang), "size": ts(16), "c": Color(1, 1, 1, 0.92), "x": 0.0, "w": 356.0, "gap": 12.0},
	]
	return items

## 排名條（第五輪 §4.3）：只在可比的兵種之間排名。回傳 [標籤, {兵種: 值}, 數值文字]；值字典只有一筆＝不排名。
## 血量、速度：10 種一起比；每秒傷害：只比戰鬥兵；射程：戰鬥兵比射程、支援兵比支援範圍；醫者每秒補血、鼓手光環、價格不排名。
func _cx_ranks(t: int) -> Array:
	var hp := {}
	var dps := {}
	var rng := {}
	var spd := {}
	for k in D.COUNT:
		var st: Dictionary = D.STATS[k]
		hp[k] = float(st["hp"])
		spd[k] = float(st["speed"]) * 20.0 / 1000.0
		if not D.is_support(k):
			dps[k] = float(st["atk"]) * 20.0 / float(st["cd"])
			rng[k] = float(st["reach"]) / 1000.0
	var out: Array = [[L.t("bar_hp"), hp, str(int(hp[t]))]]
	if t == D.MEDIC:
		var hps := float(D.HEAL_AMT) * 20.0 / float(D.HEAL_CD)
		out.append([L.t("bar_hps"), {t: hps}, "%.0f" % hps])
	elif t == D.DRUMMER:
		out.append([L.t("bar_aura"), {t: 1.0}, L.t("aura_val", [D.DRUM_BONUS * 100 / 4])])
	else:
		out.append([L.t("bar_dps"), dps, "%.0f" % dps[t]])
	if D.is_support(t):
		var sr := float(D.HEAL_RANGE if t == D.MEDIC else D.DRUM_RANGE) / 1000.0
		out.append([L.t("bar_support_range"), {t: sr}, L.t("cells", [sr])])
	else:
		out.append([L.t("bar_range"), rng, L.t("cells", [rng[t]])])
	out.append([L.t("bar_speed"), spd, L.t("cells_s", [spd[t]])])
	out.append([L.t("bar_cost"), {t: float(D.STATS[t]["cost"])}, L.t("gold", [int(D.STATS[t]["cost"])])])
	return out

## 屬性條（第三輪 U2）：血、每秒傷害、射程、速度，對五兵種最大值正規化。回傳 [標籤, 0～1, 數值文字]。
func _cx_bars(t: int) -> Array:
	var mx := [0.0, 0.0, 0.0, 0.0]
	var vals: Array = []
	for k in D.COUNT:
		var st: Dictionary = D.STATS[k]
		# cd 已經是 tick（Codex S3：原本多除了 4，每秒傷害顯示成 4 倍）
		var v := [float(st["hp"]), float(st["atk"]) * 20.0 / float(st["cd"]), float(st["reach"]) / 1000.0, float(st["speed"]) * 20.0 / 1000.0]
		vals.append(v)
		for i in 4:
			mx[i] = maxf(mx[i], v[i])
	var me: Array = vals[t]
	var stc: Dictionary = D.STATS[t]
	var dps_row := [L.t("bar_dps"), me[1] / mx[1], "%.0f" % me[1]]
	if t == D.MEDIC:
		var hps := float(D.HEAL_AMT) * 20.0 / float(D.HEAL_CD)
		dps_row = [L.t("bar_hps"), hps / mx[1], "%.0f" % hps]   # 醫者顯示每秒補血，不顯示 DPS 0（第四輪 §4.6）
	elif t == D.DRUMMER:
		dps_row = [L.t("bar_aura"), 0.5, L.t("aura_val", [D.DRUM_BONUS * 100 / 4])]
	var range_row := [L.t("bar_range"), sqrt(me[2] / mx[2]), L.t("cells", [me[2]])]
	if D.is_support(t):
		# 支援兵顯示支援半徑（補血／戰鼓），不顯示貼身的 0.7 格（Antigravity 第 2 輪）
		var sr := float(D.HEAL_RANGE if t == D.MEDIC else D.DRUM_RANGE) / 1000.0
		range_row = [L.t("bar_support_range"), sqrt(sr / mx[2]), L.t("cells", [sr])]
	return [[L.t("bar_hp"), me[0] / mx[0], str(int(me[0]))], dps_row,
		range_row, [L.t("bar_speed"), me[3] / mx[3], L.t("cells_s", [me[3]])],
		[L.t("bar_cost"), float(stc["cost"]) / 7.0, L.t("gold", [int(stc["cost"])])]]

func _scroll_draw(name: String, r: Rect2, items: Array, scrollable := true) -> void:
	if scrollable:
		cx_regions[name] = r
	# 先用上一次量到的內容高度夾住位移再畫（Codex S4 #4）
	var off: float = clampf(float(cx_scroll.get(name, 0.0)), 0.0, maxf(0.0, float(cx_content.get(name, 0.0)) - r.size.y))
	cx_scroll[name] = off
	var y := r.position.y - off
	var top := r.position.y
	var bot := r.end.y
	var inside := func(y0: float, h: float) -> bool: return y0 >= top - 0.5 and y0 + h <= bot + 0.5
	for it in items:
		match it["type"]:
			"portrait":
				var h: float = it["h"]
				var pc := Vector2(r.position.x + 70, y + 132)
				if inside.call(y, h):
					draw_circle(pc + Vector2(0, -30), 62, Color(1, 1, 1, 0.05), true, -1.0, true)
					_ring(pc, 0, cx_unit, 2.0)
					_unit(pc, cx_unit, 0, 1.0, 0.0, 0.0, 0.0, 1.0, time, 2.0)
				var ty := y + 4.0
				for tx in it["texts"]:
					var wt := _wrap(tx["s"], tx["size"], r.size.x - 168)
					for ln in wt.split("\n"):
						if inside.call(ty, tx["size"] * 1.3):
							_text(Vector2(r.position.x + 160, ty), ln, tx["size"], tx["c"], false, tx.get("bold", false))
						ty += tx["size"] * 1.3
					ty += 3.0
				y += maxf(h, ty - y) + 8.0
			"ranks":
				var lh2 := float(tz("S")) * 1.7
				for b in _cx_ranks(cx_unit):
					if inside.call(y, lh2):
						Charts.rank_bar(self, Rect2(r.position.x, y, r.size.x - 12, lh2), b[1], cx_unit, b[0], b[2])
					y += lh2
				y += 8.0
			"counters":
				# 剋／怕（第五輪：圖鑑也查得到，頭像 28px＋短名）
				var beats: Array = []
				var fears: Array = []
				for t2 in D.COUNT:
					var sc: int = load("res://scripts/core/ai_turns.gd").counter_score(cx_unit, t2)
					if sc > 0:
						beats.append(t2)
					elif sc < 0:
						fears.append(t2)
				if D.is_support(cx_unit):
					beats = load("res://scripts/core/ai_turns.gd").SYNERGY.get(cx_unit, [])
				var rowh := 34.0 + tz("C") * 1.3
				for grp in [[L.t("synergy") if D.is_support(cx_unit) else L.t("beats"), beats, Color("#4ade80")], [L.t("fears"), fears, Color("#f87171")]]:
					if grp[1].is_empty():
						continue
					if inside.call(y, rowh):
						_text(Vector2(r.position.x, y + 8), grp[0], tz("S"), grp[2], false, true)
						var x := r.position.x + 40
						for t3 in grp[1]:
							if x > r.end.x - 60:
								break
							Art.unit(self, Vector2(x + 26, y + 32), t3, 1, -1.0, 0.0, 0.0, 0.0, 1.0, time, 0.6, cbm())
							_text(Vector2(x + 26, y + 34), L.t("unit_%d" % t3), tz("C"), Color(1, 1, 1, 0.8), true, false, 60)
							x += 64
					y += rowh
				y += 6.0
			"bars":
				var lh := float(ts(13)) * 1.3 + 4.0
				for b in _cx_bars(cx_unit):
					if inside.call(y, lh):
						_text(Vector2(r.position.x, y), b[0], ts(13), Color(1, 1, 1, 0.75), false, false, 90)
						var bx := r.position.x + 96
						draw_rect(Rect2(bx, y + lh * 0.38, 150, 7), Color("#2a3040"))
						draw_rect(Rect2(bx, y + lh * 0.38, 150.0 * clampf(b[1], 0.04, 1.0), 7), Color("#66b2ff"))
						_text(Vector2(bx + 158, y), b[2], ts(13), Color(1, 1, 1, 0.85), false, false, r.size.x - 260)
					y += lh
				y += 10.0
			"text":
				var size: int = it["size"]
				var wt2 := _wrap(it["s"], size, it["w"])
				for ln2 in wt2.split("\n"):
					if inside.call(y, size * 1.3):
						_text(Vector2(r.position.x + it["x"], y), ln2, size, it["c"])
					y += size * 1.3
				y += float(it.get("gap", 0.0))
	cx_content[name] = y + off - r.position.y
	# 內容變短（換兵種）時，位移要重新夾在範圍內（Codex S3）
	var maxs := maxf(0.0, float(cx_content[name]) - r.size.y)
	if off > maxs:
		cx_scroll[name] = maxs
	# 捲軸
	var total: float = cx_content[name]
	if scrollable and total > r.size.y + 1.0:
		var bar := Rect2(r.end.x - 6, r.position.y, 6, r.size.y)
		draw_rect(bar, Color("#2a3040"))
		var th := maxf(24.0, r.size.y * r.size.y / total)
		var ty2 := r.position.y + (r.size.y - th) * (off / maxf(1.0, total - r.size.y))
		draw_rect(Rect2(bar.position.x, ty2, 6, th), Color("#5a657d"))


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
