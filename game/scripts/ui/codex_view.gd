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
var cx_angle := -1          # V1.5：手動角度（0～15，每格 22.5°；-1＝自動）
var cx_slow := false        # V1.5：慢動作 0.25 倍
var cx_atk_t := -10.0       # V1.5：按「出手」的時間（cx_clock 的時間軸）
var cx_clock := 0.0
## V1.5.1 A5 近看模式：整塊取代左右欄，角色對假人靶出手，可暫停、逐格、放大
var cx_zoom := false
var cx_zt := 0.0            # 出手循環裡的時間（秒，0～CXZ_CYCLE）
var cx_zplay := true
var cx_zalt := false        # 特殊／交替招式
var cx_zally := false       # 友軍靶（醫者補血）
var cx_zbig := false
const CXZ_ATK := 0.7        # 一次出手的長度（和大頭照的「出手」一樣）
const CXZ_CYCLE := 1.3      # 出手＋停一下
const CXZ_STEP := 0.05         # V1.5：圖鑑播放時鐘（慢動作時走 0.25 倍；切換慢動作不跳幀，Codex v150-i1 #8）
var cx_last := 0.0
const CX_ANGLES := 9        # 沒有背面的兵：右側面 → 正面 → 左側面，每格 22.5°

## 這種兵的角度盤有幾格：人形王國兵有背面（16 格一整圈），其他只轉正面半圈（9 格）
func cx_angles() -> int:
	return 16 if cx_unit in Art.BACK_OK else CX_ANGLES
var cx_spin_t := -10.0   # V1.3.1 P1：圖鑑角色播放器（點角色：轉身一圈＋待機小動作）
var cx_skill := 0
var cx_sim = null
var cx_acc := 0.0
var cx_ticks := 0
var cx_wait := 0.0
var cx_prev := {}
var cx_atk := {}
var cx_hurt := {}
var cx_pops: Array = []        # 技能觸發時跳出的字：{p, s, t}
## V1.5.1 A7：小劇場也走展示緩衝（和正式戰場同一套）：模擬領先 8 tick，遠程在命中前出手、飛行物命中那一刻剛好到
var cx_view = null
var cx_hits := {}       # id → 命中 tick 陣列
var cx_ptgt := {}       # id → {命中 tick: 目標 id}
var cx_pend_pops := {}  # 畫面 tick → [[位置, 字]]（跳字等畫面播到才出）
var cx_seen := false
var cx_scroll := {"left": 0.0, "desc": 0.0, "note": 0.0}   # 各捲動區的位移
var cx_content := {"left": 0.0, "desc": 0.0, "note": 0.0}  # 各捲動區的內容高度（上一幀量到的）
var cx_regions := {}                                         # 名稱 → 畫面上的矩形（滾輪判斷用）           # 這一輪示範有沒有出現預期的技能


func _open_codex(t: int) -> void:
	# 開圖鑑前取消擺放畫面的拖曳／塗兵狀態，不然關掉圖鑑後移動滑鼠會繼續放兵（Codex R3 審查 #3）
	painting = false
	drag_new = false
	drag_from = Vector2i(-1, -1)
	cx_unit = clampi(t, 0, D.total() - 1)
	cx_zoom = false   # V1.5.1：從擺陣開圖鑑一律回一般頁（召喚物頁的近看狀態不留，Antigravity v151-i1 #6）
	cx_angle = -1
	cx_atk_t = -10.0
	cx_scroll["left"] = 0.0   # 每次打開都從頂端開始（Antigravity：沿用上次捲到底的位置，看起來像數值條不見了）
	cx_scroll["note"] = 0.0
	_cx_pick_skill(0)
	_open("codex")


func _cx_skills() -> Array:
	return CX.unit(cx_unit).get("skills", [])


func _cx_pick_unit(t: int) -> void:
	cx_unit = t
	cx_angle = -1   # 換兵種回到自動（人形轉到背面後換成沒有背面的兵，不能留著背面角度）
	cx_spin_t = cx_clock   # 換角色先轉一圈給你看
	cx_zt = 0.0
	if t >= D.total():
		cx_zoom = true   # V1.5.1：召喚物（小史萊姆、小骷髏）沒有排名與數值條，只有近看頁
		return
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
	cx_view = null
	cx_hits.clear()
	cx_ptgt.clear()
	cx_pend_pops.clear()
	if cx_sim != null:
		cx_view = ViewBuffer.new(cx_sim)
		cx_view.delay = ViewBuffer.DELAY_LONG
		for i in cx_view.delay:
			_cx_sim_step()
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
	if cx_zoom and cx_zplay:
		cx_zt = fposmod(cx_zt + delta * (0.25 if cx_slow else 1.0), CXZ_CYCLE)
	for p in cx_pops:
		p["t"] += delta
	cx_pops = cx_pops.filter(func(p): return p["t"] < 1.1)
	if cx_sim == null or cx_unit >= D.total() or _cx_skills().is_empty():
		return   # V1.5.1：召喚物沒有技能小劇場
	var sk: String = _cx_skills()[cx_skill]
	var dm: Dictionary = CX.skill(sk).get("demo", {})
	var limit := int(dm.get("ticks", 120))
	if cx_view == null or cx_view.finished or cx_ticks >= limit:
		cx_wait += delta
		if cx_wait >= CX_PAUSE:
			_cx_restart()
		return
	cx_acc += delta
	while cx_acc >= 0.05 and not cx_view.finished and cx_ticks < limit:
		cx_acc -= 0.05
		if not cx_sim.finished:
			_cx_sim_step()
		for u in cx_view.units:
			cx_prev[u.id] = Vector2(u.x, u.y)
		if not cx_view.advance():
			break
		cx_ticks += 1
		for e in cx_view.events:
			if e.has("dmg") and e.has("tgt"):
				cx_hurt[e["tgt"]] = time   # 受擊閃白在畫面播到命中那一格才出
		for pp in cx_pend_pops.get(cx_view.tick, []):
			cx_seen = true
			var txt: String = pp[1]
			var dup := false
			for q in cx_pops:
				if q["s"] == txt and float(q["t"]) < 0.5:
					dup = true   # 同一個技能字 0.5 秒內只跳一次（第五輪版面檢查：同字重疊）
			if not dup:
				cx_pops.append({"p": pp[0], "s": txt, "t": 0.0})
			if cx_pops.size() > 4:
				cx_pops.pop_front()
		cx_pend_pops.erase(cx_view.tick)

## 小劇場的模擬往前一格：快照進緩衝、記下命中（遠程記目標）、技能字等畫面播到才跳
func _cx_sim_step() -> void:
	var sk: String = _cx_skills()[cx_skill]
	var dm: Dictionary = CX.skill(sk).get("demo", {})
	cx_sim.step()
	var fr: Dictionary = ViewBuffer.capture(cx_sim)
	cx_view.queue.append(fr)
	for e in cx_sim.events:
		if e.has("dmg") and e.has("src") and e.has("tgt") and event_route(e) == "attack" or e.get("kind", "") == EV.HEAL:
			var src: int = int(e["src"])
			var hs: Array = cx_hits.get(src, [])
			hs.append(cx_sim.tick)
			if hs.size() > 8:
				hs.pop_front()
			cx_hits[src] = hs
			var su = cx_sim.unit_by_id(src)
			if su != null and (e["kind"] == EV.BOMB or e["kind"] == EV.HEAL or (proj_fly(su.type) > 0 and su.type != D.MEDIC and e["kind"] != EV.SPLASH and e["kind"] != EV.BONK)):
				var bt: Dictionary = cx_ptgt.get(src, {})
				bt[cx_sim.tick] = int(e["tgt"])
				cx_ptgt[src] = bt
	var hits: Array = CX.expect_hits(cx_sim, str(dm.get("expect", "")))
	if not hits.is_empty():
		var txt: String = CX.text(CX.skill(sk), "", L.lang) + "！"
		var arr: Array = cx_pend_pops.get(cx_sim.tick, [])
		for hp in hits:
			arr.append([hp, txt])
		cx_pend_pops[cx_sim.tick] = arr


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
	if cx_zoom:
		probe_skip("R6", "圖鑑近看：中間是大圖（角色圖不經版面探針），不是空白")
	var u := CX.unit(cx_unit)
	var lang := L.lang
	_h1(Vector2(640, 78), L.t("codex_title"), 600)   # 1.2.0：H1 放大、再上移 4；V1.5.2 L3：緞帶上移，完整下緣到兵種分頁列 ≥16
	# 兵種分頁
	# 第四輪 §4.7：一排 10 個「頭像＋數字」頁籤；兵種全名在下面左欄的大標題
	# 第八輪：頁籤分兩頁（王國軍／奇幻軍），各 10 種
	var page_new: bool = cx_unit >= D.COUNT and cx_unit < D.total()
	var page_sum: bool = cx_unit >= D.total()
	_btn(Rect2(204, 104, 110, 38), L.t("lb_army_kingdom"), func(): _cx_pick_unit(0); cx_zoom = false, true, false, TH_ACTIVE if not page_new and not page_sum else Color(0, 0, 0, 0))
	_btn(Rect2(320, 104, 110, 38), L.t("lb_army_fantasy"), func(): _cx_pick_unit(D.COUNT); cx_zoom = false, true, false, TH_ACTIVE if page_new else Color(0, 0, 0, 0))
	var tw := (866.0 - (D.COUNT - 1) * 6.0) / D.COUNT
	var tab_types: Array = range(D.total(), D.total() + 2) if page_sum else range(D.COUNT if page_new else 0, (D.COUNT if page_new else 0) + D.COUNT)
	for t0 in tab_types.size():
		var t: int = tab_types[t0]
		var r := Rect2(204 + t0 * (tw + 6.0), 150, tw, 50)
		_btn(r, "", _cx_pick_unit.bind(t), true, false, TH_ACTIVE if t == cx_unit else Color(0, 0, 0, 0))
		if t == cx_unit:
			draw_rect(r.grow(1.0), ACCENT, false, 3.0)   # 第七輪 E9：選中的兵種金框
		_unit_in(r, t, 0, 1.0, 0.6 if t != D.CAVALRY else 0.55)   # 人物在頁籤正中間（原本腳畫到框外）
		_probe_glyph = true   # V1.2.1：頁籤角落的快捷鍵數字是符號
		_text(r.position + Vector2(4, 2), str((t0 + 1) % 10), tcap(tz("C"), 14), TXT_DIM, false, true)
		_probe_glyph = false
	_btn(Rect2(960, 104, 110, 38), L.t("cxz_summons"), func(): _cx_pick_unit(D.COUNT * 2), true, false, TH_ACTIVE if cx_unit >= D.COUNT * 2 else Color(0, 0, 0, 0))
	if cx_zoom or cx_unit >= D.total():
		_draw_cx_zoom()
		_btn(Rect2(560, 676, 160, 38), L.t("back"), func(): _nav_back())
		return
	# 左欄（第三輪 U1）：可捲動區，字級＝基準×設定（150% 時正文 24px），不再縮字
	# 大頭照＋名字固定在上面，只有下面的屬性與文字捲動（Antigravity S3：捲動時大頭照整張消失像破圖）
	var items := _cx_left_items(u, lang)
	# 固定區的高度依名字、定位、口號實際換行後的高度決定（Antigravity S3 第 2 輪：英文 150% 口號被切）
	var head_min: float = float(items[0]["h"])   # V1.5：大頭照＋檢視控制鈕要整塊放得下，不然整個大頭照不畫（收尾截圖抓到）
	var ty := 4.0
	for tx in items[0]["texts"]:
		ty += (_wrap(tx["s"], tx["size"], CX_LEFT.size.x - 168).count("\n") + 1) * tx["size"] * 1.3 + 3.0
	var head_h := clampf(maxf(head_min, ty + 8.0), head_min, 260.0)
	# V1.2 C2：左欄是一張羊皮紙卡，字用墨色
	if not bool(Save.s("plain_ui")):
		_tex_box(CX_LEFT.grow_individual(8, 0, 8, 8), "paper")   # 上緣和頁籤留空（Antigravity impl3）
		_ink_mode = true
	_scroll_draw("head", Rect2(CX_LEFT.position, Vector2(CX_LEFT.size.x, head_h)), [items[0]], false)
	draw_line(Vector2(CX_LEFT.position.x, CX_LEFT.position.y + head_h - 2), Vector2(CX_LEFT.end.x, CX_LEFT.position.y + head_h - 2), Color(INK, 0.25) if _ink_mode else Color(1, 1, 1, 0.12), 1.0)
	_scroll_draw("left", Rect2(CX_LEFT.position + Vector2(0, head_h + 4), CX_LEFT.size - Vector2(0, head_h + 4)), items.slice(1))
	_ink_mode = false
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
	var paper := not bool(Save.s("plain_ui"))
	if paper:
		_tex_box(nr.grow(3), "paper")   # V1.2.1 R1：老兵筆記是一張夾在木盒裡的紙條（墨色字）
		_ink_mode = true
	else:
		draw_rect(nr, Color(0.2, 0.17, 0.1, 0.85))
		draw_rect(nr, Color(ACCENT, 0.35), false, 1.5)
	var head: String = L.t("codex_note")
	if cx_unit < D.total() and has_method("mastery_line"):
		head += "　・　" + str(call("mastery_line", cx_unit))   # V1.6 #12 熟練度：和標題同一段（日文 100% 圖鑑段數到上限）
	_text(nr.position + Vector2(12, 4), head, ts(14), ACCENT, false, true, nr.size.x - 24)
	var note := CX.text(u, "veteran", lang)   # 第十一輪：筆記直接看得到
	_scroll_draw("note", Rect2(nr.position + Vector2(12, 4 + ts(14) * 1.4), Vector2(nr.size.x - 20, nr.size.y - 8 - ts(14) * 1.4)),
		[{"type": "text", "s": note, "size": ts(14), "c": Color(1, 1, 1, 0.9), "x": 0.0, "w": nr.size.x - 40}])
	_ink_mode = false
	_btn(Rect2(560, 676, 160, 38), L.t("back"), func(): _nav_back())


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

const CX_TAG_W := 196.0

## 中文口號差一點放不下時拿掉引號，不要讓結尾引號自己掉到下一行（Antigravity 第 2 輪；不縮字，字級表是底線）。
func _tag_text(raw: String, lang: String) -> String:
	if lang == "en":
		return "\"%s\"" % raw
	if lang == "zh_CN":
		return "“%s”" % raw
	var q := "「%s」" % raw
	return raw if _width(q, ts(15)) > CX_TAG_W and _width(raw, ts(15)) <= CX_TAG_W else q


## 左欄內容：大頭照＋名字、定位、口號；屬性條；故事、擅長、怕。
func _cx_left_items(u: Dictionary, lang: String) -> Array:
	var tag := _tag_text(CX.text(u, "tagline", lang), lang)
	var items: Array = [
		{"type": "portrait", "h": 188.0, "texts": [
			{"s": L.t("unit_%d" % cx_unit), "size": ts(26), "c": Color.WHITE, "bold": true},
			{"s": CX.text(u, "role", lang), "size": ts(15), "c": TXT_DIM},
			{"s": tag if _scale_key() == 100 else "", "size": ts(15), "c": ACCENT}]},   # 大字時省略口號，讓剋／怕不用捲動
		{"type": "ranks"},
		{"type": "rangegrid"},   # V1.0.0 H4：射程／技能範圍畫在小格網上
		{"type": "counters"},
		{"type": "text", "s": "✓ " + CX.text(u, "good", lang), "size": ts(15), "c": Color("#7dff8a"), "x": 0.0, "w": 356.0, "gap": 6.0},
		{"type": "text", "s": "× " + CX.text(u, "bad", lang), "size": ts(15), "c": Color("#ff9b9b"), "x": 0.0, "w": 356.0, "gap": 12.0},
		{"type": "text", "s": L.t("codex_story_h"), "size": ts(15), "c": TXT_DIM, "x": 0.0, "w": 356.0, "gap": 2.0},
		{"type": "text", "s": CX.text(u, "story", lang), "size": ts(16), "c": Color(1, 1, 1, 0.92), "x": 0.0, "w": 356.0, "gap": 12.0},
	]
	return items

## V1.0.0 H4：圖鑑範圍示意 [標籤, 半徑（格）, 顏色]。數值都從兵種常數取。
func cx_ranges(t: int) -> Array:
	var FD = load("res://scripts/core/fantasy_defs.gd")
	var out: Array = []
	if D.is_support(t):
		var sr := float(D.HEAL_RANGE if t == D.MEDIC else (FD.SPRITE_R if t == 16 else D.DRUM_RANGE)) / 1000.0
		out.append([L.t("bar_support_range"), sr, Color("#2f9e44")])
	else:
		out.append([L.t("bar_range"), float(D.stat(t)["reach"]) / 1000.0, Color("#c2410c")])
	var sk := {D.BOMBER: D.SPLASH_R, 11: FD.BLAST_R, 18: FD.CAT_R, 19: FD.GOLEM_R}   # 投彈兵＝落點波及半徑
	if sk.has(t):
		out.append([L.t("cx_skill_r"), float(sk[t]) / 1000.0, Color("#7c3aed")])
	return out

## 排名條（第五輪 §4.3）：只在可比的兵種之間排名。回傳 [標籤, {兵種: 值}, 數值文字]；值字典只有一筆＝不排名。
## 血量、速度：10 種一起比；每秒傷害：只比戰鬥兵；射程：戰鬥兵比射程、支援兵比支援範圍；醫者每秒補血、鼓手光環、價格不排名。
func _cx_ranks(t: int) -> Array:
	var hp := {}
	var dps := {}
	var rng := {}
	var spd := {}
	for k in D.total():
		var st: Dictionary = D.stat(k)
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
		var sr := float(D.HEAL_RANGE if t == D.MEDIC else (2500 if t == 16 else D.DRUM_RANGE)) / 1000.0
		out.append([L.t("bar_support_range"), {t: sr}, L.t("cells", [sr])])
	else:
		out.append([L.t("bar_range"), rng, L.t("cells", [rng[t]])])
	out.append([L.t("bar_speed"), spd, L.t("cells_s", [spd[t]])])
	out.append([L.t("bar_cost"), {t: float(D.stat(t)["cost"])}, L.t("gold", [int(D.stat(t)["cost"])])])
	return out

## 屬性條（第三輪 U2）：血、每秒傷害、射程、速度，對五兵種最大值正規化。回傳 [標籤, 0～1, 數值文字]。
func _cx_bars(t: int) -> Array:
	var mx := [0.0, 0.0, 0.0, 0.0]
	var vals: Array = []
	for k in D.total():
		var st: Dictionary = D.stat(k)
		# cd 已經是 tick（Codex S3：原本多除了 4，每秒傷害顯示成 4 倍）
		var v := [float(st["hp"]), float(st["atk"]) * 20.0 / float(st["cd"]), float(st["reach"]) / 1000.0, float(st["speed"]) * 20.0 / 1000.0]
		vals.append(v)
		for i in 4:
			mx[i] = maxf(mx[i], v[i])
	var me: Array = vals[t]
	var stc: Dictionary = D.stat(t)
	var dps_row := [L.t("bar_dps"), me[1] / mx[1], "%.0f" % me[1]]
	if t == D.MEDIC:
		var hps := float(D.HEAL_AMT) * 20.0 / float(D.HEAL_CD)
		dps_row = [L.t("bar_hps"), hps / mx[1], "%.0f" % hps]   # 醫者顯示每秒補血，不顯示 DPS 0（第四輪 §4.6）
	elif t == D.DRUMMER:
		dps_row = [L.t("bar_aura"), 0.5, L.t("aura_val", [D.DRUM_BONUS * 100 / 4])]
	var range_row := [L.t("bar_range"), sqrt(me[2] / mx[2]), L.t("cells", [me[2]])]
	if D.is_support(t):
		# 支援兵顯示支援半徑（補血／戰鼓），不顯示貼身的 0.7 格（Antigravity 第 2 輪）
		var sr := float(D.HEAL_RANGE if t == D.MEDIC else (2500 if t == 16 else D.DRUM_RANGE)) / 1000.0
		range_row = [L.t("bar_support_range"), sqrt(sr / mx[2]), L.t("cells", [sr])]
	return [[L.t("bar_hp"), me[0] / mx[0], str(int(me[0]))], dps_row,
		range_row, [L.t("bar_speed"), me[3] / mx[3], L.t("cells_s", [me[3]])],
		[L.t("bar_cost"), float(stc["cost"]) / 9.0, L.t("gold", [int(stc["cost"])])]]

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
					_ring(pc, 0, cx_unit, cx_fit(cx_unit))
					_cx_portrait(pc)
					_btns.append({"r": Rect2(pc - Vector2(56, 112), Vector2(112, 124)), "cb": func(): cx_spin_t = cx_clock; cx_angle = -1, "en": true})
					# V1.5：檢視控制：左右轉 22.5°、慢動作 0.25 倍、出手一次（手把也按得到）
					var cy0 := pc.y + 15.0
					var cx0 := r.position.x + 4.0   # 四顆 40×38（點擊框至少 36）
					_btn(Rect2(cx0, cy0, 40, 38), "◀", func(): _cx_turn(-1))
					_btn(Rect2(cx0 + 42, cy0, 40, 38), "▶", func(): _cx_turn(1))
					_btn(Rect2(cx0 + 84, cy0, 40, 38), "", func(): cx_slow = not cx_slow, true, false, TH_ACTIVE if cx_slow else Color(0, 0, 0, 0))
					_icon("slow", Vector2(cx0 + 104, cy0 + 19), 20.0, Color.WHITE)
					_btn(Rect2(cx0 + 126, cy0, 40, 38), "", func(): cx_atk_t = cx_clock; cx_spin_t = -10.0)
					_icon("swords", Vector2(cx0 + 146, cy0 + 19), 20.0, Color.WHITE)
					# V1.5.1：近看（大頭照右上角）
					_btn(Rect2(pc.x + 46, y + 8, 40, 38), "", func(): cx_zoom = true; cx_zt = 0.0; cx_zplay = true)
					_icon("size", Vector2(pc.x + 66, y + 27), 20.0, Color.WHITE)
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
				var lh2 := float(tz("S")) * 1.45
				for b in _cx_ranks(cx_unit):
					if inside.call(y, lh2):
						Charts.rank_bar(self, Rect2(r.position.x, y, r.size.x - 12, lh2), b[1], cx_unit, b[0], b[2])
					y += lh2
				y += 8.0
			"rangegrid":
				# V1.0.0 H4：以兵所在格為中心畫範圍圈（常數取自兵種表，不寫死），一格一個方格
				var rs := cx_ranges(cx_unit)
				var maxr := 0.0
				for rr0 in rs:
					maxr = maxf(maxr, float(rr0[1]))
				var cell := clampf(34.0 / maxf(1.0, maxr), 7.0, 16.0)
				var gh := ceilf(maxr) * 2.0 * cell + cell
				var lh3 := float(tz("C")) * 1.35
				var hh := maxf(gh, rs.size() * lh3) + 8.0
				if inside.call(y, hh):
					var c0 := Vector2(r.position.x + 8 + (ceilf(maxr) + 0.5) * cell, y + hh * 0.5)
					var n := int(ceilf(maxr))
					var gcol := Color(INK, 0.18) if _ink_mode else Color(1, 1, 1, 0.12)
					for gx in range(-n, n + 1):
						for gy in range(-n, n + 1):
							draw_rect(Rect2(c0 + Vector2(gx - 0.5, gy - 0.5) * cell, Vector2(cell, cell)), gcol, false, 1.0)
					var tx0 := c0.x + (n + 0.5) * cell + 10.0
					var ly := y + (hh - rs.size() * lh3) * 0.5
					for rr in rs:
						var col: Color = rr[2]
						draw_circle(c0, float(rr[1]) * cell, Color(col, 0.16), true, -1.0, true)
						_hand_ring(c0, float(rr[1]) * cell, Color(col, 0.9), 2.0)
						_text(Vector2(tx0, ly), "%s %s" % [rr[0], L.t("cells", [float(rr[1])])], tz("C"), col.darkened(0.35) if _ink_mode else col, false, true, r.position.x + r.size.x - tx0)
						ly += lh3
					draw_circle(c0, cell * 0.32, Color("#3b82f6"), true, -1.0, true)
				y += hh + 4.0
			"counters":
				# 剋／怕（第五輪：圖鑑也查得到，頭像 28px＋短名）
				var beats: Array = []
				var fears: Array = []
				for t2 in D.total():
					var sc: int = load("res://scripts/core/ai_turns.gd").counter_score(cx_unit, t2)
					if sc > 0:
						beats.append(t2)
					elif sc < 0:
						fears.append(t2)
				if D.is_support(cx_unit):
					beats = load("res://scripts/core/ai_turns.gd").SYNERGY.get(cx_unit, [])
				# 剋、怕並排在同一列（Antigravity 實作第 1 輪：100% 不用捲動就看得到兩邊）；名字放得下才寫
				var rowh := 34.0 + tz("C") * 1.3
				if inside.call(y, rowh):
					var half := (r.size.x - 12) / 2.0
					var gi := 0
					for grp in [[L.t("synergy") if D.is_support(cx_unit) else L.t("beats"), beats, Color("#4ade80")], [L.t("fears"), fears, Color("#f87171")]]:
						var gx := r.position.x + gi * half
						gi += 1
						_text(Vector2(gx, y + 8), grp[0], tz("S"), grp[2], false, true)
						var x := gx + _width(grp[0], tz("S"), true) + 6
						var cw := 44.0
						for t3 in grp[1]:
							if x + cw > gx + half - 4:
								break
							Art.unit(self, Vector2(x + cw / 2, y + 32), t3, 1, -1.0, 0.0, 0.0, 0.0, 1.0, time, 0.55, cbm())
							var nm: String = L.t("unit_%d" % t3)
							if _width(nm, tz("C")) <= cw + 2:
								_text(Vector2(x + cw / 2, y + 34), nm, tz("C"), TXT_DIM, true)
							x += cw
				y += rowh + 4.0
			"bars":
				var lh := float(ts(13)) * 1.3 + 4.0
				var bar_i := 0
				for b in _cx_bars(cx_unit):
					if inside.call(y, lh):
						_icon(["heart", "sword", "range", "speed", "coin"][mini(bar_i, 4)], Vector2(r.position.x + 9, y + lh * 0.5), 18.0, Color.WHITE)
						_text(Vector2(r.position.x + 22, y), b[0], ts(13), TXT_DIM, false, false, 72)
						var bx := r.position.x + 96
						_seg_bar(Rect2(bx, y + lh * 0.3, 150, 11), clampf(b[1], 0.04, 1.0), Color("#e8a33a"))   # V1.2 C2：8 格刻印條
						_text(Vector2(bx + 158, y), b[2], ts(13), Color(1, 1, 1, 0.85), false, false, r.size.x - 260)
					bar_i += 1
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
		draw_rect(bar, Color("#2a1d14"))   # V1.2.1：捲軸改木色（原藍灰像工程介面）
		var th := maxf(24.0, r.size.y * r.size.y / total)
		var ty2 := r.position.y + (r.size.y - th) * (off / maxf(1.0, total - r.size.y))
		draw_rect(Rect2(bar.position.x, ty2, 6, th), Color("#9a7650"))
		# V1.2.1 B3：還有內容的那一邊加淡陰影＋小箭頭（只在真的還有時出現），看得出可以捲
		var cw2 := r.size.x - 10.0
		if off > 1.0:
			for k in 4:
				draw_rect(Rect2(r.position.x, r.position.y + k * 3.0, cw2, 3.0), Color(0, 0, 0, 0.16 - k * 0.04))
			var up := Vector2(r.position.x + cw2 - 10, r.position.y + 8)
			draw_colored_polygon(PackedVector2Array([up + Vector2(-6, 4), up + Vector2(6, 4), up + Vector2(0, -3)]), Color(INK, 0.85) if _ink_mode else ACCENT)
		if off < maxs - 1.0:
			for k in 4:
				draw_rect(Rect2(r.position.x, r.end.y - (k + 1) * 3.0, cw2, 3.0), Color(0, 0, 0, 0.16 - k * 0.04))
			var ac := Color(INK, 0.85) if _ink_mode else ACCENT
			var ap := Vector2(r.position.x + cw2 - 10, r.end.y - 8)
			draw_colored_polygon(PackedVector2Array([ap + Vector2(-6, -4), ap + Vector2(6, -4), ap + Vector2(0, 3)]), ac)


func _draw_codex_demo() -> void:
	var b := CX_BOX
	draw_rect(b, Color("#5f8f3a"))
	var k := b.size.x / CX_VIEW.size.x
	var cs := 1000.0 * k
	# 第七輪 D3：小劇場用真戰場的草地，不再是棋盤格
	if grass != null:
		for c in range(2, 14):
			for r in range(1, 8):
				var cell := Rect2(b.position + (Vector2(c, r) * 1000.0 - CX_VIEW.position) * k, Vector2(cs, cs)).intersection(b)
				if cell.has_area():
					var h := absi((c * 73856093) ^ (r * 19349663))
					draw_texture_rect_region(grass, cell, Rect2((h % 8) * 32, ((h / 8) % 4) * 32, 32, 32))
		draw_rect(b, Color(0.06, 0.09, 0.16, 0.18))
	for c in [6, 10]:
		var x: float = b.position.x + (c * 1000.0 - CX_VIEW.position.x) * k
		draw_dashed_line(Vector2(x, b.position.y), Vector2(x, b.end.y), Color(Art.team_color(0 if c == 6 else 1, cbm()), 0.6), 2.0, 6.0)
	if cx_view != null:
		var list: Array = []
		for u in cx_view.units:
			if u.alive:
				list.append(u)
		var disp: float = cx_view.tick + clampf(cx_acc / 0.05, 0.0, 1.0)
		var pdraw: Array = []
		list.sort_custom(func(a, c): return a.y < c.y)
		var sc := 0.72
		for u in list:
			_ring(_cx_pos(u), u.team, u.type, sc)
		for u in list:
			var p := _cx_pos(u)
			var moving: bool = u.mx != 0 or u.my != 0
			var at := 0.0
			if cx_hits.has(u.id):
				# V1.5.1 A7：和戰場一樣，前搖在命中前開始，遠程出手後飛行物飛到目標
				var ph := proj_phase(cx_hits[u.id], disp, u.type, cx_view.delay, cx_ptgt.get(u.id, {}))
				if int(ph[1]) >= 0:
					at = atk_progress(disp - float(ph[3]), u.type, float(ph[4]))
					if float(ph[2]) >= 0.0 and cx_ptgt.get(u.id, {}).has(int(ph[1])):
						var tu = cx_view.unit_by_id(int(cx_ptgt[u.id][int(ph[1])]))
						if tu != null:
							var sgp: float = signf(_cx_pos(tu).x - p.x) if _cx_pos(tu).x != p.x else 1.0
							pdraw.append([u.type, u.team, p, _cx_pos(tu), float(ph[2]), sgp])
			var hurt := 0.0
			if cx_hurt.has(u.id) and _fx_on("flash"):
				hurt = clampf(1.0 - (time - cx_hurt[u.id]) / 0.15, 0, 1)
			var face := signf(u.fx) if u.fx != 0 else (1.0 if u.team == 0 else -1.0)
			_unit(p, u.type, u.team, face, (time * Gait.nominal_rate(u.type, float(D.stat(u.type)["speed"]), CS, sc) + u.id) if moving else 0.0, at, hurt, 0.45 if u.stealth > 0 else 1.0, time, sc)
			if u.stun > 0:
				_text(p + Vector2(0, -60), "◇", ts(14), Color.YELLOW, true)
			if u.hp < u.max_hp:
				var w := 24.0
				var top := p + Vector2(-w / 2, -52 if u.type == D.CAVALRY else -46)
				draw_rect(Rect2(top - Vector2(1, 1), Vector2(w + 2, 5)), Art.OUT)
				draw_rect(Rect2(top, Vector2(w * u.hp / u.max_hp, 3)), Art.team_color(u.team, cbm()).lightened(0.25))
		# 飛行物（縮到小劇場的比例：角色 0.72 倍，戰場是 UNIT_SCALE）
		var ps := sc / 0.92   # 戰場飛行物是照 0.92 倍角色調的固定尺寸；1.3.0 角色放大後小劇場比例不變（Codex cat04 #6）
		for pj in pdraw:
			var a0: Vector2 = pj[2] + proj_launch(int(pj[0]), float(pj[5])) * sc
			var b0: Vector2 = pj[3] + Vector2(0, -16.0 * ps)
			draw_set_transform_matrix(Art.base * Transform2D(0.0, Vector2(ps, ps), 0.0, a0))
			_draw_projectile(int(pj[0]), int(pj[1]), Vector2.ZERO, (b0 - a0) / ps, float(pj[4]))
			draw_set_transform_matrix(Art.base)
	var drawn: Array = []
	for pp in cx_pops:
		var kk: float = pp["t"] / 1.1
		var q: Vector2 = _cx_map(pp["p"]) + Vector2(0, -66 - kk * 26)
		for dq in drawn:
			if dq[0] == pp["s"] and dq[1].distance_to(q) < 60.0:
				q.y = dq[1].y - tz("B") * 1.3   # 同一個技能字靠太近：往上疊一層，不互相蓋住
		if q.y < b.position.y + tz("C") * 1.5 + 6:
			continue   # 疊到小劇場標題列就不畫這個重複的字
		drawn.append([pp["s"], q])
		_probe_anim = true   # 小劇場的技能跳字是淡出中的特效，不算介面文字
		_text(q, pp["s"], ts(16), Color(ACCENT, 1.0 - kk * kk), true, true)
		_probe_anim = false
	if bool(Save.s("plain_ui")):
		draw_rect(b, Color(1, 1, 1, 0.25), false, 1.5)
	else:
		# V1.2：小劇場像嵌在木盒裡的沙盤：深木邊＋四層內陰影（上方沒有空間放外框；Antigravity impl3）
		for kl in 4:
			draw_rect(b.grow(-2.0 - kl * 2.0), Color(0, 0, 0, 0.2 - kl * 0.045), false, 2.0)
		draw_rect(b, TH_WOOD_D, false, 3.0)
		draw_line(b.position + Vector2(0, b.size.y + 1.5), b.end + Vector2(0, 1.5), Color(1, 0.9, 0.7, 0.18), 1.0)
	_text(b.position + Vector2(8, 4), L.t("codex_demo"), ts(13), TXT_DIM)


## V1.3.1 P1：圖鑑大圖播放器。0～1.2 秒左右轉一圈（用轉身姿勢，不是 360°），1.2～2.2 秒做這種兵的待機小動作。
## 簡化特效時只畫靜止的正側面。
## V1.5：圖鑑大圖每種兵固定一個縮放（用 tools/codex_audit.gd 的檢查表量：正側面、轉身、前搖、朝左的聯集外框，
## 左右 74px、往上 116px 內），播放中不縮放；長武器（長槍、騎槍）不會再伸進名稱區。最小 1.41 倍（1.4 以下會改走圖集、外框畫法不同），最大 2 倍。
const CX_FIT := {0: 2.0, 1: 2.0, 2: 1.93, 3: 1.61, 4: 1.72, 5: 1.41, 6: 2.0, 7: 1.93, 8: 1.57, 9: 1.85, 10: 2.0, 11: 2.0,
	12: 2.0, 13: 2.0, 14: 2.0, 15: 1.9, 16: 1.85, 17: 1.73, 18: 1.95, 19: 1.81, 20: 2.0, 21: 2.0}

static func cx_fit(type: int) -> float:
	return float(CX_FIT.get(type, 2.0))

func _cx_turn(d: int) -> void:
	cx_angle = posmod((cx_angle if cx_angle >= 0 else 0) + d, cx_angles())
	cx_spin_t = -10.0
	cx_atk_t = -10.0

func _cx_portrait(pc: Vector2) -> void:
	var sp := 0.25 if cx_slow else 1.0
	cx_clock += clampf(time - cx_last, 0.0, 0.1) * sp
	cx_last = time
	var u := (cx_clock - cx_spin_t) if not bool(Save.s("reduce_fx")) and not bool(Save.s("reduce_motion")) and not layout_probe else 99.0   # 截圖／版面檢查時固定正側面
	var face := 1.0
	var atk := 0.0
	if cx_angle >= 0:
		# 手動角度：0＝朝右側面、4＝正面、8＝朝左、12＝背面（每格 22.5°）
		var th := cx_angle * PI / 8.0
		var cf := cos(th)
		Art.back = cx_unit in Art.BACK_OK and sin(th) < -0.01
		face = 1.0 if cf >= 0.0 else -1.0
		if absf(cf) < 0.95:
			Art.turn_c = maxf(absf(cf), 0.3)
			Art.turn_s = sqrt(1.0 - Art.turn_c * Art.turn_c)
	var ua := cx_clock - cx_atk_t
	if ua >= 0.0 and ua < 0.7:
		atk = 0.001 + ua / 0.7 * 0.999   # 出手一次：前搖→揮擊→後搖
	elif cx_angle < 0 and u >= 0.0 and u < 1.2:
		var cf2 := cos(u / 1.2 * TAU)
		face = 1.0 if cf2 >= 0.0 else -1.0
		Art.back = cx_unit in Art.BACK_OK and sin(u / 1.2 * TAU) < -0.01   # 人形兵自動轉一整圈（後半圈看背面）
		if absf(cf2) < 0.95:
			Art.turn_c = maxf(absf(cf2), 0.3)
			Art.turn_s = sqrt(1.0 - Art.turn_c * Art.turn_c)
	elif cx_angle < 0 and u >= 1.2 and u < 2.2:
		var spec: Array = preload("res://scripts/ui/sprite_cache.gd").FIDGET.get(cx_unit, [0.2, 0.0])
		var wgt := sin((u - 1.2) / 1.0 * PI)
		atk = Art.ATK_WINDUP * float(spec[0]) * wgt
		Art.calm = true
		Art.look = float(spec[1]) * wgt
	_cx_draw_unit(pc, face, atk, cx_fit(cx_unit), 0)
	if has_method("codex_plaque") and not layout_probe:
		call("codex_plaque", pc + Vector2(0, 10), cx_unit)   # V1.6.1 A1：腳下木牌刻熟練度＋戰功章
	# 出手的遠程：箭／炸彈／法球／補血從手上飛出去（圖鑑也看得到「射出東西」，Antigravity v150-i1 #9）
	if proj_fly(cx_unit) > 0 and ua >= 0.0 and ua < 0.7 and atk >= 0.3125:
		var pk := clampf((atk - 0.3125) / 0.4, 0.0, 1.0)
		var s := cx_fit(cx_unit)
		_draw_projectile(cx_unit, 0, pc + proj_launch(cx_unit, face) * s, pc + Vector2(face * 150.0, -30.0), pk)
	Art.turn_c = 1.0
	Art.turn_s = 0.0
	Art.back = false
	Art.calm = false
	Art.look = 0.0


## 1.2.0 第 5 大類 B：圖鑑大圖輪流示範 5 種表情（待機 → 專注 → 生氣 → 受驚 → 得意，各 1.6 秒）；出手中固定專注；截圖固定待機。
## 戰場維持原本的少數表情（小尺寸看不清）。
const CX_MOODS := [0, Art.M_GRIM, Art.M_BROWS, Art.M_SURPRISE, Art.M_HAPPY]
func cx_mood(atk: float) -> int:
	if shot_dir != "" or layout_probe or Art.back or absf(Art.turn_s) > 0.05:
		return 0   # 背面、轉身途中不疊表情（表情層沒有背面／轉向定位，Codex cat05 #1）
	if atk > 0.0:
		return Art.M_GRIM
	return int(CX_MOODS[int(time / 1.6) % CX_MOODS.size()])

## V1.5.1 A6：圖鑑大圖用烘焙後處理版（外框、漬洗、乾掃和戰場一致）；簡化介面、無視窗時照舊直接畫
var cx_bake = null
func _cx_draw_unit(p: Vector2, face: float, atk: float, sc: float, variant: int) -> void:
	var mood := cx_mood(atk)
	if bool(Save.s("plain_ui")) or DisplayServer.get_name() == "headless":
		_unit(p, cx_unit, 0, face, 0.0, atk, 0.0, 1.0, time, sc, mood, 0.0, 1.0, variant)
		return
	if cx_bake == null:
		cx_bake = load("res://scripts/ui/codex_bake.gd").new()
		add_child(cx_bake)
	_unit_base(p, sc)
	cx_bake.set_params({"type": cx_unit, "face": face, "atk": atk, "hurt": 0.0, "t": time, "scale": sc, "cb": cbm(), "variant": variant,
		"turn_c": Art.turn_c, "turn_s": Art.turn_s, "back": Art.back, "calm": Art.calm, "look": Art.look, "mood": mood},
		float(Art.WASH[clampi(int(Art.paint[2]), 0, 2)]), float(Art.DRY[clampi(int(Art.paint[3]), 0, 2)]))
	draw_set_transform_matrix(Art.base)
	draw_texture(cx_bake.texture(), p - cx_bake.FEET)

## ── V1.5.1 A5 近看模式 ──
## 示意播放器（不是真模擬）：角色對假人靶出手一次再停一下，循環；可暫停、逐格、轉角度、放大。
func cxz_phase(t: float) -> Array:
	# 回傳 [階段 0 前搖／1 揮擊／2 後搖／3 停, atk 0～1]
	if t >= CXZ_ATK:
		return [3, 0.0]
	var atk := 0.001 + t / CXZ_ATK * 0.999
	return [0 if atk < 0.3125 else (1 if atk < 0.53125 else 2), atk]

func _draw_cx_zoom() -> void:
	var R := Rect2(204, 204, 866, 462)
	if not bool(Save.s("plain_ui")):
		_tex_box(R.grow(4), "paper")
		_ink_mode = true
	var nm := L.t("unit_%d" % cx_unit)
	_text(R.position + Vector2(16, 10), nm, tz("H2"), Color.WHITE, false, true, 360)
	_text(R.position + Vector2(390, 10 + (tz("H2") - tz("C")) * 0.5), L.t("cxz_demo"), tz("C"), TXT_DIM, false, false, 330)
	if cx_unit < D.total():
		_btn(Rect2(R.end.x - 140, R.position.y + 6, 128, 38), L.t("cxz_close"), func(): cx_zoom = false)
	_ink_mode = false
	# 畫布
	var cv := Rect2(220, 258, 834, 266)
	draw_rect(cv, Color("#7d9a58"))
	draw_rect(Rect2(cv.position, Vector2(cv.size.x, cv.size.y * 0.45)), Color("#c9b48a"))
	draw_rect(cv, Color(0, 0, 0, 0.35), false, 2.0)
	var face := 1.0
	if cx_angle >= 0:
		var th := cx_angle * PI / 8.0
		face = 1.0 if cos(th) >= 0.0 else -1.0
		if absf(cos(th)) < 0.95:
			Art.turn_c = maxf(absf(cos(th)), 0.3)
			Art.turn_s = sqrt(1.0 - Art.turn_c * Art.turn_c)
		Art.back = cx_unit in Art.BACK_OK and sin(th) < -0.01
	var sc := (3.4 if cx_zbig else 2.5)
	var me := Vector2(cv.position.x + (180.0 if face > 0.0 else cv.size.x - 180.0), cv.end.y - 22)
	var dm := Vector2(cv.position.x + (cv.size.x - 180.0 if face > 0.0 else 180.0), cv.end.y - 22)
	var ph := cxz_phase(cx_zt)
	var atk: float = ph[1]
	# 命中時間：近戰在揮擊開始；遠程在飛行結束
	var fly := proj_fly(cx_unit) > 0 or cx_unit == 10 or cx_unit == 15
	var hit_at := 0.3125 if not fly else 0.62
	var hurt := clampf(1.0 - absf(atk - hit_at) / 0.06, 0.0, 1.0) if atk > 0.0 else 0.0
	_cx_dummy(dm, -face, hurt, cx_zally)
	Art.calm = false
	_cx_draw_unit(me, face, atk, sc, (1 if cx_unit < D.CLASSIC else 2) if cx_zalt else 0)   # 舊兵的交替招式是 variant 1、新兵的專屬動作是 2（和圖集一樣）
	if fly and atk >= 0.3125 and atk <= hit_at:
		var k := (atk - 0.3125) / (hit_at - 0.3125)
		var a0 := me + proj_launch(cx_unit, face) * sc
		var b0 := dm + Vector2(0, -26.0 * 2.2)
		if cx_unit == 10:
			draw_circle(a0.lerp(b0, k), 10.0 + 12.0 * k, Color(0.55, 0.85, 0.35, 0.55 * (1.0 - k * 0.4)))   # 孢子菇毒霧
		elif cx_unit == 15:
			draw_line(a0, a0.lerp(b0, k), Color(0.7, 0.35, 1.0, 0.85), 3.0, true)   # 巫毒娃娃紫線
		else:
			# 飛行物跟著角色放大（在 a0 為原點、放大 sc/1.6 的座標系裡畫）
			var ps := sc / 1.6
			draw_set_transform_matrix(Art.base * Transform2D(0.0, Vector2(ps, ps), 0.0, a0))
			_draw_projectile(cx_unit, 0, Vector2.ZERO, (b0 - a0) / ps, k)
			draw_set_transform_matrix(Art.base)
	Art.turn_c = 1.0
	Art.turn_s = 0.0
	Art.back = false
	# 階段與時間
	var lab := L.t("cxz_ph_%d" % int(ph[0])) + "  %.2f s" % minf(cx_zt, CXZ_ATK)
	_text(Vector2(cv.position.x + 12, cv.position.y + 8), lab, tz("B"), Color(0.15, 0.1, 0.05), false, true, 400)
	# 控制列（兩列）
	var y1 := cv.end.y + 8
	var bw := 64.0
	var row1: Array = [["◀", func(): _cx_turn(-1)], ["▶", func(): _cx_turn(1)], ["−", func(): cx_zplay = false; cx_zt = maxf(0.0, cx_zt - CXZ_STEP)],
		["", func(): cx_zplay = not cx_zplay], ["+", func(): cx_zplay = false; cx_zt = minf(CXZ_CYCLE - 0.001, cx_zt + CXZ_STEP)], ["", func(): cx_slow = not cx_slow]]
	for i in row1.size():
		var rr := Rect2(220 + i * (bw + 8), y1, bw, 40)
		var tint := TH_ACTIVE if (i == 5 and cx_slow) else Color(0, 0, 0, 0)
		_btn(rr, row1[i][0], row1[i][1], true, false, tint)
		if i == 3:
			_icon("pause" if cx_zplay else "play", rr.get_center() - Vector2(0, 1.5), 20.0, Color.WHITE)
		elif i == 5:
			_icon("slow", rr.get_center() - Vector2(0, 1.5), 20.0, Color.WHITE)
	var x2 := 220.0
	y1 += 48.0   # V1.5.1：文字鈕放第二列整排（英文 150% 一列放不下，版面檢查）
	var row2: Array = [[L.t("cxz_atk"), func(): cx_zalt = false; cx_zt = 0.0; cx_zplay = true, not cx_zalt], [L.t("cxz_alt"), func(): cx_zalt = true; cx_zt = 0.0; cx_zplay = true, cx_zalt],
		[L.t("cxz_ally") if cx_zally else L.t("cxz_foe"), func(): cx_zally = not cx_zally, false], [L.t("cxz_big") if not cx_zbig else L.t("cxz_small"), func(): cx_zbig = not cx_zbig, false]]
	var bw2 := (1054.0 - x2 - 3 * 8) / 4.0
	for i in row2.size():
		_btn(Rect2(x2 + i * (bw2 + 8), y1, bw2, 40), row2[i][0], row2[i][1], true, false, TH_ACTIVE if row2[i][2] else Color(0, 0, 0, 0))

## 假人靶：木樁＋草袋；受擊時閃白往後晃。ally＝友軍靶（藍色布條，給醫者補血看）
func _cx_dummy(p: Vector2, face: float, hurt: float, ally: bool) -> void:
	var sway := -face * hurt * 6.0
	draw_line(p, p + Vector2(sway, -110), Color("#6b4a2e"), 8.0, true)
	draw_line(p + Vector2(sway * 0.6 - 26, -70), p + Vector2(sway * 0.6 + 26, -70), Color("#6b4a2e"), 6.0, true)
	var hc := p + Vector2(sway, -112)
	draw_circle(hc + Vector2(0, 36), 30.0, Color("#d8c08a").lerp(Color.WHITE, hurt * 0.7), true, -1.0, true)
	draw_circle(hc, 20.0, Color("#d8c08a").lerp(Color.WHITE, hurt * 0.7), true, -1.0, true)
	draw_rect(Rect2(hc + Vector2(-26, 30), Vector2(52, 8)), Art.team_color(0 if ally else 1, cbm()))
	if hurt > 0.3:
		_text(hc + Vector2(0, -50), L.t("cxz_hit") if not ally else "+", tz("B"), Color("#ffe066"), true, true, 120)
