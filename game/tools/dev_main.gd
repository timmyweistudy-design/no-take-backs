extends "res://scripts/ui/game_screens.gd"
const LayoutRules = preload("res://scripts/ui/layout_rules.gd")
## V1.5.2：自己畫框、不用 _panel 的覆蓋層（漏登記守衛的已知例外）：AI 思考中只畫轉圈
const PANELLESS_OVERLAYS := ["ai_busy"]
## V1.5.2 漏登記守衛：每個覆蓋層必須登記到的角色（有標題緞帶的要有 1 條緞帶＋1 個面板；彈窗至少 1 個面板）。
## 由各覆蓋層的繪圖函式靜態整理；之後新增覆蓋層要加進來，否則守衛只會要求面板。
const DECK_CAP := 0.7
const DECK_MIN_PX := 9.0
const OVERLAY_RIBBON := ["trials", "puzzle_hint", "puzzle_plan", "profile", "nemeses", "paint", "hub_play", "hub_gauntlet", "hub_challenge", "hub_collect", "first_run", "restore", "clear_data", "ghosts", "ga_info", "weekly", "relay", "playroom", "wager", "draft", "reward", "ban", "codes", "gauntlet_resume", "wave_codes", "tutorial", "puzzles", "lobby", "settings", "keys", "credits", "gauntlet_pick", "codex", "review", "demo_end", "share", "rush_end", "coach", "rift", "notebook", "daily_top", "editor", "trio", "trio_result", "coop_hand", "tour", "nb_cmp", "rift_lab", "rush_menu", "coop_sum", "fb_cat", "nb_words", "daily_past"]
const OVERLAY_PANEL := ["postcard", "pause_menu", "confirm", "fs_confirm", "leave", "slots"]
## 開發工具入口（第七輪 H3，原 scripts/ui/main.gd）：自動截圖、版面報告、商店膠囊圖、實機影片、效能與記憶體量測。
## 匯出設定排除 tools/，所以出貨版沒有這些；從專案路徑帶對應參數啟動時由 scripts/ui/main.gd 換成這一支。


## 商店膠囊圖（N6）：用目前視窗大小構圖——先畫標題帶，再把兩軍放在標題下方對衝，中間有分界線與對射的箭。
## 只有遊戲標題文字（Steam 規定）。手感輪（收尾批）調整：標題帶不壓角色、中央不留白、小尺寸放大標題與角色、兩側留邊。
func _draw_capsule() -> void:
	# 膠囊圖（第三輪 M1）：左藍右紅 15° 斜切＋中央裂縫與對撞星芒、兩邊各 3 隻放大的角色、標題金邊立體投影。
	var vs := get_viewport_rect().size
	var tall := vs.y > vs.x
	var tiny := get_window().size.y < 300
	var blue := Color("#1b3b6f")
	var red := Color("#6f1d2b")
	var mid := vs.x / 2
	var slant := tan(deg_to_rad(15.0)) * vs.y / 2
	draw_rect(Rect2(Vector2.ZERO, vs), red)
	draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(mid + slant, 0), Vector2(mid - slant, vs.y), Vector2(0, vs.y)]), blue)
	# 速度線
	for k in 14:
		var yy := vs.y * (0.08 + k * 0.066)
		var ln := vs.x * (0.12 + 0.06 * (k % 3))
		draw_line(Vector2(vs.x * 0.02, yy), Vector2(vs.x * 0.02 + ln, yy), Color(1, 1, 1, 0.07), maxf(2.0, vs.y * 0.006), true)
		draw_line(Vector2(vs.x * 0.98 - ln, yy + vs.y * 0.03), Vector2(vs.x * 0.98, yy + vs.y * 0.03), Color(1, 1, 1, 0.07), maxf(2.0, vs.y * 0.006), true)
	# 標題帶
	var big := int(vs.y * (0.11 if tall else (0.30 if tiny else 0.19)))
	var band_y := vs.y * (0.04 if tall else 0.03)
	# 中央裂縫（鋸齒）：從標題帶下方開始，不穿過字（Antigravity S7）
	var crack := PackedVector2Array()
	var cy0 := band_y + big * 1.12 + int(big * 0.34) * 1.3
	for k in 9:
		var t := k / 8.0
		var yy2 := lerpf(cy0, vs.y, t)
		var x := lerpf(mid + slant, mid - slant, yy2 / vs.y) + (8.0 if k % 2 == 0 else -8.0) * vs.y / 430.0
		crack.append(Vector2(x, yy2))
	draw_polyline(crack, Color(1, 0.95, 0.75, 0.9), maxf(3.0, vs.y * 0.012), true)
	var tt: String = L.t("title")
	var tw := font_bold.get_string_size(tt, HORIZONTAL_ALIGNMENT_LEFT, -1, big).x
	var tp := Vector2(mid - tw / 2, band_y + big * 0.9)
	var dep := maxf(3.0, big * 0.06)
	for d in 4:
		draw_string(font_bold, tp + Vector2(1, 1) * dep * (d + 1) / 4.0, tt, HORIZONTAL_ALIGNMENT_LEFT, -1, big, Color(0.12, 0.05, 0.02, 0.95))
	draw_string_outline(font_bold, tp, tt, HORIZONTAL_ALIGNMENT_LEFT, -1, big, int(maxf(6.0, big * 0.12)), Color("#3a2205"))
	draw_string_outline(font_bold, tp, tt, HORIZONTAL_ALIGNMENT_LEFT, -1, big, int(maxf(3.0, big * 0.06)), Color("#d4a017"))
	draw_string(font_bold, tp, tt, HORIZONTAL_ALIGNMENT_LEFT, -1, big, Color("#ffe8a3"))
	var sub := int(big * (0.42 if tiny else 0.30))
	_text(Vector2(mid, band_y + big * 1.12), "No Take-Backs", sub, Color(1, 1, 1, 0.97), true, true)
	# 角色：兩邊各 3 隻，前排最大、最靠中線
	var top := band_y + big * 1.12 + sub * 1.4
	var bottom := vs.y * 0.97
	var sc := (bottom - top) / (70.0 if tiny else 95.0)
	if tall:
		sc = minf(sc, vs.x / 118.0)
	var left := [[D.ARCHER, 0.13, 0.80], [D.CAVALRY, 0.27, 0.92], [D.SWORD, 0.40, 1.0]]
	var right := [[D.ASSASSIN, 0.87, 0.80], [D.SHIELD, 0.73, 0.92], [D.SWORD, 0.60, 1.0]]
	if tall:
		# 直式：每邊兩隻、放大，後排的往上放，填滿中段
		left = [[D.CAVALRY, 0.14, 0.74], [D.SWORD, 0.29, 1.0]]
		right = [[D.ASSASSIN, 0.86, 0.74], [D.SWORD, 0.71, 1.0]]
	if tiny:
		left = [[D.CAVALRY, 0.22, 0.95], [D.SWORD, 0.40, 1.0]]
		right = [[D.SHIELD, 0.78, 0.95], [D.SWORD, 0.60, 1.0]]
	var items: Array = []
	for it in left:
		items.append([it, 0])
	for it in right:
		items.append([it, 1])
	for e in items:
		var it: Array = e[0]
		var team: int = e[1]
		var k: float = it[2]
		var s2 := sc * k
		var p := Vector2(vs.x * float(it[1]), bottom - (1.0 - k) * (bottom - top) * 0.55)
		var face := 1.0 if team == 0 else -1.0
		Art.ring(self, p, team, it[0], false, s2)
		var mood := Art.M_SPARKLE if it[0] == D.CAVALRY else Art.M_BROWS
		var at := 0.42 if k >= 0.99 else (0.25 if it[0] == D.ARCHER else 0.0)
		Art.unit(self, p, it[0], team, face, 0.0, at, 0.0, 1.0, 1.3, s2, false, mood, 0.2 if it[0] == D.CAVALRY else 0.0)
	# 中央對撞星芒
	var cc := Vector2(mid, bottom - (22.0 if tall else 30.0) * sc)   # 星芒在前排兩隻的武器交會處
	var r0 := minf(45.0 * vs.y / 430.0, (11.0 if tall else 16.0) * sc) * (0.7 if tiny else 1.0)
	for layer in 2:
		var pts := PackedVector2Array()
		var rr := r0 * (1.0 - layer * 0.45)
		for i in 24:
			var an := i * TAU / 24.0
			pts.append(cc + Vector2(cos(an), sin(an)) * (rr if i % 2 == 0 else rr * 0.42))
		draw_colored_polygon(pts, Color(1, 0.9, 0.5, 0.95) if layer == 0 else Color.WHITE)
func _capture_capsule() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var err := get_viewport().get_texture().get_image().save_png(capsule_path)
	if err != OK:
		printerr("CAPSULE 存檔失敗 ", capsule_path, " err=", err)
		get_tree().quit(1)
		return
	print("CAPSULE ", capsule_path)
	get_tree().quit()


# ───────────────────────── 截圖（驗證用） ─────────────────────────
## 版面檢查（第三輪 T4）：這張截圖的介面文字有沒有越界、小於 9px（Steam Deck 下限）、彼此重疊超過 15%。
## 第五輪 U4：新規則全部算違規——表外字級、小於字級表下限、戰場字小於 14、相同字串在不同位置重疊、點擊框小於 32px、
## 「要讀的文字」段數超過上限（控制項＝按鈕、兵卡裡的字不算）。
const TEXT_BUDGET := {"02_place.png": 30, "17_place_new.png": 30, "05_result.png": 20, "10_codex.png": 30, "19_codex_new.png": 30,
	"22_lobby.png": 25, "25_lobby_duel.png": 25, "08_settings.png": 25, "01_title.png": 12}

## V1.2.1 F5：WCAG 相對亮度（線性 sRGB）與對比。
static func rel_lum(c: Color) -> float:
	var f := func(v: float) -> float: return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * f.call(c.r) + 0.7152 * f.call(c.g) + 0.0722 * f.call(c.b)

static func contrast(a: Color, b: Color) -> float:
	var la := rel_lum(a)
	var lb := rel_lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)

## 從截圖取一段字的背景色：字框內取樣，去掉像字色、像描邊色的像素，剩下的取亮度中位數。
## 背景像素不到 15% 回傳 null（背景未知＝不能算通過）。
static func text_bg(img: Image, r: Rect2, c: Color, oc: Color, sx: float, sy: float):
	var x0 := clampi(int(r.position.x * sx), 0, img.get_width() - 1)
	var y0 := clampi(int(r.position.y * sy), 0, img.get_height() - 1)
	var x1 := clampi(int(r.end.x * sx), 0, img.get_width() - 1)
	var y1 := clampi(int(r.end.y * sy), 0, img.get_height() - 1)
	if x1 <= x0 or y1 <= y0:
		return null
	var step := maxi(1, int(sqrt(float((x1 - x0) * (y1 - y0)) / 500.0)))
	var all := 0
	var bg: Array = []
	var y := y0
	while y <= y1:
		var x := x0
		while x <= x1:
			var p := img.get_pixel(x, y)
			all += 1
			var dc := absf(p.r - c.r) + absf(p.g - c.g) + absf(p.b - c.b)
			var do := absf(p.r - oc.r) + absf(p.g - oc.g) + absf(p.b - oc.b) if oc.a > 0.0 else 9.0
			if dc > 0.30 and do > 0.30:
				bg.append(p)
			x += step
		y += step
	if all == 0 or float(bg.size()) / all < 0.15:
		# 小字（例如單一數字）字框裡幾乎都是字：改取字框外圍一圈當背景
		bg = []
		for k in 24:
			var a := k * TAU / 24.0
			var pp := r.get_center() + Vector2(cos(a) * (r.size.x / 2.0 + 3.0), sin(a) * (r.size.y / 2.0 + 3.0))
			var px := clampi(int(pp.x * sx), 0, img.get_width() - 1)
			var py := clampi(int(pp.y * sy), 0, img.get_height() - 1)
			var p2 := img.get_pixel(px, py)
			if absf(p2.r - c.r) + absf(p2.g - c.g) + absf(p2.b - c.b) > 0.30:
				bg.append(p2)
		if bg.size() < 8:
			return null
	# 反鋸齒的邊緣像素是字色和背景的混色，不是背景：先用中位數估主背景，排除落在混色線上的像素
	var tmp := bg.duplicate()
	tmp.sort_custom(func(a, b): return rel_lum(a) < rel_lum(b))
	var med: Color = tmp[tmp.size() / 2]
	var segs: Array = [[c, med]]
	if oc.a > 0.0:
		segs.append([oc, med])
		segs.append([c, oc])
	var keep: Array = []
	for p in bg:
		var on_blend := false
		for sg in segs:
			if seg_dist(p, sg[0], sg[1]) < 0.06:
				on_blend = true
				break
		if not on_blend or seg_dist(p, med, med) < 0.06:
			keep.append(p)
	if keep.size() >= 6:
		bg = keep
	# 取「最接近字色亮度」那一側的 20% 分位：紙紋、木紋上局部低對比的地方也算進去（Codex v121-impl1：中位數會漏）
	var lt := rel_lum(c)
	bg.sort_custom(func(a, b): return absf(rel_lum(a) - lt) < absf(rel_lum(b) - lt))
	return bg[int(bg.size() * 0.2)]

## 顏色 p 到線段 a–b（RGB 空間）的距離：判斷是不是兩色的混色（反鋸齒）。
static func seg_dist(p: Color, a: Color, b: Color) -> float:
	var pv := Vector3(p.r, p.g, p.b)
	var av := Vector3(a.r, a.g, a.b)
	var bv := Vector3(b.r, b.g, b.b)
	var ab := bv - av
	var t := 0.0 if ab.length_squared() < 1e-6 else clampf((pv - av).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return pv.distance_to(av + ab * t)

## 一段字是否算大字（WCAG：24px 以上，或粗體 18.66px 以上；以 1280×800 顯示尺寸算）。
static func large_text(size: int, bold: bool) -> bool:
	return size >= 24 or (bold and size >= 19)

## F5：截圖上的文字對比。有足夠描邊的字比「字對描邊」，其他比「字對背景」（半透明字先疊在背景上）。
func _contrast_issues(img: Image) -> Dictionary:
	var bad: Array = []
	var warn: Array = []
	if img == null:
		return {"bad": bad, "warn": warn}
	var sx := img.get_width() / 1280.0
	var sy := img.get_height() / 800.0
	for t in probe_texts:
		if t.get("field", false) or not t.has("c") or t.get("anim", false):   # 鍵帽字母等符號仍要檢查對比，只有淡出特效字不檢查
			continue
		var c: Color = t["c"]
		var oc: Color = t["oc"]
		var size := int(t["size"])
		var need := 3.0 if large_text(size, bool(t.get("bold", false))) else 4.5
		var outlined: bool = oc.a >= 0.6 and float(t["ow"]) >= float(text_outline_w(size)) * 0.9
		var bgc = text_bg(img, t["r"], c, oc, sx, sy)
		var dis: bool = bool(t.get("dis", false))
		if bgc == null:
			(warn if dis else bad).append({"type": "背景未知", "s": t["s"]})   # 背景不可靠一律不算通過
			continue
		var over := func(fg: Color, bk: Color) -> Color: return Color(fg.r * fg.a + bk.r * (1.0 - fg.a), fg.g * fg.a + bk.g * (1.0 - fg.a), fg.b * fg.a + bk.b * (1.0 - fg.a))
		var ceff: Color = over.call(c, bgc)
		var ratio := contrast(ceff, bgc)
		if outlined:
			# 描邊字（裁決 R8）：描邊先疊在背景上、字再疊在描邊上；「字對背景」「描邊對背景」「字對描邊」取最好的
			var oeff: Color = over.call(oc, bgc)
			ratio = maxf(ratio, maxf(contrast(oeff, bgc), contrast(over.call(c, oeff), oeff)))
		if ratio >= need:
			continue
		var item := {"type": "對比不足", "s": t["s"], "ratio": snappedf(ratio, 0.01), "need": need}
		if dis:
			warn.append(item)   # 只有登記為停用的元件另報（WCAG 豁免停用元件）
		else:
			bad.append(item)
	return {"bad": bad, "warn": warn}

## V1.5.2：這一幀交給排版規則的資料（獨立成函式，測試直接驗守衛有拿到 overlay／need／boxes；
## 曾經因為行中間的 # 註解把後面三個參數吃掉，守衛靜靜失效，Codex 實作第 3 輪抓到）。
## focus_out＝一般焦點框外擴（2.5，取 3）；加強焦點框在 _btn 裡夾在可用區內。
func layout_geom_input() -> Dictionary:
	var need: Dictionary = probe_need.duplicate()
	if overlay in OVERLAY_RIBBON:
		need["ribbon"] = maxi(1, int(need.get("ribbon", 0)))
		need["panel"] = maxi(1, int(need.get("panel", 0)))
	elif overlay in OVERLAY_PANEL:
		need["panel"] = maxi(1, int(need.get("panel", 0)))
	return {"panels": probe_panels, "ribbons": probe_ribbons, "decos": probe_decos, "aligns": probe_aligns,
		"texts": probe_texts.filter(func(t): return not t.get("field", false)), "btns": probe_btns, "focus_out": 3.0,
		"boxes": probe_boxes.map(func(b): return b["r"]), "overlay": overlay, "need": need,
		"panelless_ok": overlay in PANELLESS_OVERLAYS}


## 1.2.0 §14.7 美感自動檢查（第一批，先當報表、不擋）：
##  ・black_pct：近純黑像素（三通道都 ≤ 8）佔全畫面的百分比（憲法 3：禁純黑；桌面世界做完後改成違規）
##  ・units／low_units：戰鬥中每隻單位，框內（腳底往上 46px、寬 36px）與框外一圈 6px 的平均明度差 < 30%（＝0.3×255）的隻數（憲法 7）
func _art_checks(img: Image) -> Dictionary:
	var out := {"black_pct": 0.0, "units": 0, "low_units": 0}
	if img == null:
		return out
	var w := img.get_width()
	var h := img.get_height()
	var n := 0
	var blk := 0
	for y in range(0, h, 4):
		for x in range(0, w, 4):
			var c := img.get_pixel(x, y)
			n += 1
			if c.r8 <= 8 and c.g8 <= 8 and c.b8 <= 8:
				blk += 1
	out["black_pct"] = snappedf(100.0 * blk / maxi(1, n), 0.01)
	if state == St.BATTLE and view != null:
		var lum := func(c: Color) -> float: return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
		var mean := func(r: Rect2i) -> float:
			var s0 := 0.0
			var k := 0
			for yy in range(maxi(0, r.position.y), mini(h, r.end.y), 2):
				for xx in range(maxi(0, r.position.x), mini(w, r.end.x), 2):
					s0 += lum.call(img.get_pixel(xx, yy))
					k += 1
			return s0 / maxi(1, k)
		for u in view.units:
			if not u.alive:
				continue
			var sp: Vector2 = _cam * _upos(u)
			var inner := Rect2i(int(sp.x) - 18, int(sp.y) - 46, 36, 46)
			var outer := inner.grow(6)
			var li: float = mean.call(inner)
			# 外圈＝外框四條邊帶的平均（不含內框）
			var ring := 0.0
			for r in [Rect2i(outer.position.x, outer.position.y, outer.size.x, 6), Rect2i(outer.position.x, outer.end.y - 6, outer.size.x, 6),
					Rect2i(outer.position.x, inner.position.y, 6, inner.size.y), Rect2i(inner.end.x, inner.position.y, 6, inner.size.y)]:
				ring += mean.call(r)
			ring /= 4.0
			out["units"] += 1
			if absf(li - ring) < 0.3:
				out["low_units"] += 1
	return out

func _layout_report(name: String, img: Image = null) -> void:
	var bad: Array = []
	var cres := _contrast_issues(img)
	bad.append_array(cres["bad"])
	for mp in probe_missing:
		bad.append({"type": "缺圖", "s": mp})   # V1.2.1：材質缺檔不能默默退回平塗
	for b in _btns:     # 第十輪 T5：按鈕不能跑出畫面（手把焦點會走到看不見的地方）
		if not Rect2(0, 0, 1280, 800).encloses(b["r"]):
			bad.append({"type": "按鈕超出畫面", "s": name, "r": str(b["r"])})
	var sizes: Array = []
	var ui_n := 0
	var free_n := 0
	var ctrls: Array = probe_btns + probe_ctrls
	for t in probe_texts:
		var r: Rect2 = t["r"]
		var sz := int(t["size"])
		# V1.0.0 S2：Steam Deck（1280×800）最小字形實高 9px：拉丁大寫字高約 0.7 字級，所以字級 < 13 就不夠（符號、快捷鍵數字也算）
		if float(sz) * DECK_CAP < DECK_MIN_PX:
			bad.append({"type": "字形實高小於 9px（Deck）", "s": t["s"], "size": sz})
		if t.get("field", false):
			if sz < 14:
				bad.append({"type": "戰場字太小", "s": t["s"], "size": sz})
			if r.position.x < -2 or r.end.x > 1282 or r.position.y < -2 or r.end.y > 802:
				bad.append({"type": "戰場字越界", "s": t["s"], "r": str(r)})
			continue
		ui_n += 1
		sizes.append(sz)
		var in_ctrl: bool = t.get("btn", false)
		for c in probe_ctrls:
			if c.grow(1.0).encloses(r):
				in_ctrl = true   # 整段字都在卡片／空白標籤按鈕裡＝控制項內容
				break
		if not in_ctrl:
			free_n += 1
		if r.position.x < -2 or r.end.x > 1282 or r.position.y < -2 or r.end.y > 802:
			bad.append({"type": "越界", "s": t["s"], "r": str(r)})
		if sz < tz("C") and not t.get("glyph", false):
			bad.append({"type": "小於字級表下限", "s": t["s"], "size": sz})
		if not size_ok(sz) and not t.get("glyph", false):
			bad.append({"type": "表外字級", "s": t["s"], "size": sz})
	for a in probe_texts.size():
		if probe_texts[a].get("field", false):
			continue
		for b in range(a + 1, probe_texts.size()):
			if probe_texts[b].get("field", false):
				continue
			var ra: Rect2 = probe_texts[a]["r"]
			var rb: Rect2 = probe_texts[b]["r"]
			var x := ra.intersection(rb)
			if not x.has_area():
				continue
			var ratio := x.get_area() / maxf(1.0, minf(ra.get_area(), rb.get_area()))
			if ratio <= 0.15:
				continue
			if probe_texts[a]["s"] != probe_texts[b]["s"]:
				bad.append({"type": "重疊", "a": probe_texts[a]["s"], "b": probe_texts[b]["s"], "ratio": snappedf(ratio, 0.01)})
			elif ra.position.distance_to(rb.position) > 2.0:
				bad.append({"type": "相同字串重疊", "s": probe_texts[a]["s"], "ratio": snappedf(ratio, 0.01)})
	# V1.2.1 F1：字要完整在九宮格的內容區裡（材質登記的實際斜邊內距）；只看包住字中心的最上層方塊，按鈕標籤也算
	for t in probe_texts:
		if t.get("field", false) or t.get("glyph", false):
			continue
		var tr2: Rect2 = t.get("gr", t["r"])   # 字形框
		var cc := tr2.get_center()
		var best = null
		for bx in probe_boxes:
			if bx["inner"].has_point(cc):
				best = bx   # 最上層（最後畫）的方塊：疊在別的面板上的視窗算自己的框
		if best != null and not best["inner"].grow(0.5).encloses(tr2):
			bad.append({"type": "字壓到九宮格邊", "s": t["s"], "box": str(best["r"])})
	# 第七輪 I3：按鈕框互撞（重疊但不是一個包住另一個）
	for bi in probe_btns.size():
		for bj in range(bi + 1, probe_btns.size()):
			var r1: Rect2 = probe_btns[bi]
			var r2: Rect2 = probe_btns[bj]
			var inter := r1.intersection(r2)
			if inter.get_area() > 6.0 and not r1.encloses(r2) and not r2.encloses(r1):
				bad.append({"type": "按鈕互撞", "a": str(r1), "b": str(r2)})
	for hr in probe_hits:
		if hr.size.y < 44.0:   # V1.5.2：擴過點擊區的小鈕，點擊區要 ≥44
			bad.append({"type": "點擊區不足 44", "r": str(hr)})
		for b2 in _btns:   # 擴大的點擊區不能蓋到別顆按鈕的點擊區（先登記的會攔走點擊，Codex 實作第 2 輪）
			var r2: Rect2 = b2["r"]
			if r2 != hr and hr.intersection(r2).get_area() > 1.0 and not hr.encloses(r2) and not r2.encloses(hr):
				bad.append({"type": "點擊區互撞", "a": str(hr), "b": str(r2)})
	for r in probe_btns:
		if r.size.x < 36.0 or r.size.y < 36.0:   # 方案 §5.3：點擊框 ≥36px
			bad.append({"type": "點擊框太小", "r": str(r)})
	# 第五輪（Antigravity 實作第 1 輪抓到自動檢查漏的）：按鈕外的文字壓到按鈕上
	for t in probe_texts:
		if t.get("field", false):
			continue
		var tr: Rect2 = t["r"]
		if t.get("btn", false):
			# 按鈕標籤：只豁免它自己的按鈕；要完整落在自己的框內，也不能壓到別顆按鈕（Codex 實作第 2 輪）
			var own: Rect2 = t.get("own", Rect2())
			if own.has_area() and not own.grow(2.0).encloses(tr):
				bad.append({"type": "按鈕標籤超出按鈕", "s": t["s"], "btn": str(own)})
			for br2 in probe_btns:
				if br2 == own:
					continue
				var x3 := tr.intersection(br2)
				if x3.has_area() and x3.get_area() > tr.get_area() * 0.10:
					bad.append({"type": "按鈕標籤壓到別的按鈕", "s": t["s"], "btn": str(br2)})
					break
			continue
		var inside := false
		for c in probe_ctrls:
			if c.grow(1.0).encloses(tr):
				inside = true
				break
		if inside:
			continue
		for br in probe_btns:
			var x2 := tr.intersection(br)
			if x2.has_area() and x2.get_area() > tr.get_area() * 0.10:
				bad.append({"type": "文字壓到按鈕", "s": t["s"], "btn": str(br)})
				break
	# V1.5.2 排版幾何（置中、貼齊、間距；規則代碼見 docs/ui-layout-rules.md）
	var geo := LayoutRules.check(layout_geom_input())
	for v in geo["fail"]:
		bad.append({"type": "排版" + str(v["type"]), "id": v["id"], "s": v["s"]})
	var geo_warn: Array = []
	for v in geo["warn"]:
		geo_warn.append({"type": "排版" + str(v["type"]), "id": v["id"], "s": v["s"]})
	# 1.1.0 B9：手把模式底部多一列按鍵提示（鍵＋說明，最多 4 組＝8 段），不算畫面本身的字量
	var tb_max: int = int(TEXT_BUDGET.get(name, 0)) + (8 if pad_mode else 0)
	if TEXT_BUDGET.has(name) and int(Save.s("text_scale")) == 100 and free_n > tb_max:
		bad.append({"type": "文字段數超過上限", "n": free_n, "max": tb_max})
	sizes.sort()
	var line := JSON.stringify({"shot": name, "lang": L.lang, "scale": int(Save.s("text_scale")), "texts": ui_n, "free_texts": free_n,
		"median_size": sizes[sizes.size() / 2] if not sizes.is_empty() else 0, "min_size": sizes[0] if not sizes.is_empty() else 0,
		"violations": bad, "warnings": cres["warn"], "geo_warn": geo_warn, "geo_exempt": geo["exempt"], "art": _art_checks(img)})
	var f := FileAccess.open(shot_dir.path_join("layout.jsonl"), FileAccess.READ_WRITE if FileAccess.file_exists(shot_dir.path_join("layout.jsonl")) else FileAccess.WRITE)
	f.seek_end()
	f.store_line(line)
	f.close()


var shot_only: Array = []
var shot_fixed := false   # 1.2.0：--shot-fixed＝視覺回歸模式（固定幀時間、固定亂數、橫幅拍穩定狀態）；一般版面檢查照真實時間跑（Codex cat01 #6）   # 1.2.0 §14.4：--shot-only=a.png,b.png 只存這些（流程照跑）
func _snap(name: String) -> void:
	if shot_only.is_empty():
		for a0 in OS.get_cmdline_user_args():
			if a0.begins_with("--shot-only="):
				shot_only = Array(a0.substr(12).split(",", false))
				break
		if shot_only.is_empty():
			shot_only = ["*"]
	var skip_save: bool = not ("*" in shot_only) and not (name in shot_only)   # 跳過的畫面照樣等待（不改變後面畫面的時序；Codex cat01 #6）
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)   # 真的被縮下去就還原，否則永遠等不到繪製
	if shot_state.has("pad"):
		pad_mode = true   # V1.2.1：手把焦點狀態（焦點框畫在目前的按鈕上）
	if clutch_t > 0.0 and (clutch_t < 0.3 or clutch_t > 1.45):
		clutch_t = 0.8   # 1.2.0：「最後時刻」橫幅在淡入淡出途中（透明度 <1）做對比檢查沒有意義 → 截圖一律拍完全顯示的穩定狀態（真實時間模式也一樣）
	queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if skip_save:
		return
	var img := get_viewport().get_texture().get_image()
	var serr := img.save_png(shot_dir.path_join(name))
	if serr != OK:
		print("SHOTFAIL ", name, " ", serr)   # 1.2.0（Codex cat01 #5）：存檔失敗不能默默通過
	print("SHOT ", name)
	if layout_probe:
		_layout_report(name, img)


## 實機影片（N6 預告素材）：用 Godot 錄影模式跑（--write-movie 絕對路徑 --fixed-fps 30），全程自動。
func _run_video() -> void:
	await get_tree().create_timer(2.5).timeout
	difficulty = 1
	_start_mode(Mode.VS_AI)
	# 1.1.0 E6：分鏡場景（--video-scene=kingdom／fantasy），全程固定種子，同一個指令錄出同一段（trailer-30s.md）
	var scene := "kingdom"
	for a0 in OS.get_cmdline_user_args():
		if a0.begins_with("--video-scene="):
			scene = a0.substr(14)
	var plan := [[D.SHIELD, 5, 3], [D.SHIELD, 5, 5], [D.SWORD, 4, 2], [D.SWORD, 4, 6], [D.SWORD, 4, 4],
		[D.ARCHER, 1, 3], [D.ARCHER, 1, 5], [D.ARCHER, 0, 4], [D.CAVALRY, 3, 0], [D.CAVALRY, 3, 8], [D.ASSASSIN, 2, 4],
			[D.ARCHER, 1, 2], [D.ARCHER, 1, 6], [D.SWORD, 4, 3], [D.SWORD, 4, 5], [D.CAVALRY, 3, 4], [D.ASSASSIN, 2, 2], [D.SHIELD, 5, 4]]
	if scene == "fantasy":
		# 分鏡 15–18 秒：爆爆羊連環炸、史萊姆分裂、吸塵貓吸成一團
		plan = [[13, 5, 3], [13, 5, 5], [11, 5, 2], [11, 5, 6], [11, 4, 4], [18, 3, 4], [19, 2, 4], [13, 4, 2], [13, 4, 6]]
		rules = Presets.make("fantasy", "ai", RS.mask(false))
		rules.deploy = "grid"   # 錄影照格子擺（和王國場景同一套擺法）
		_start_mode(Mode.VS_AI)
	for s2 in plan:
		selected = s2[0]
		mouse = ORIGIN + Vector2(s2[1] + 0.5, s2[2] + 0.5) * CS
		await get_tree().create_timer(0.35).timeout
		_try_place(Vector2i(s2[1], s2[2]))
	await get_tree().create_timer(1.0).timeout
	var red_pick = null
	for k in 120:
		var r := RandomNumberGenerator.new()
		r.seed = 777 + k
		var cand = AI.build(1, 100, r)["army"]
		if _would_clutch(armies[0], cand):
			red_pick = cand
			break
	last_player_formation = armies[0].units.duplicate(true)
	ai_name = L.t("diff_normal")
	var r_fallback := RandomNumberGenerator.new()
	r_fallback.seed = 777   # 找不到接近的對手時也用固定種子（不然每次錄出不同的仗）
	_begin_battle(armies[0].copy(), (red_pick if red_pick != null else AI.build(1, 100, r_fallback)["army"]).copy())
	while state != St.RESULT:
		await get_tree().process_frame
	await get_tree().create_timer(4.0).timeout
	get_tree().quit()


func _would_clutch(a0, a1) -> bool:
	var t = Sim.new(a0.copy(), a1.copy())
	t.fast = true
	var tot := float(t.budget * 1000)
	while not t.finished:
		t.step()
		var p0: float = t.power(0) * 100.0 / tot
		var p1: float = t.power(1) * 100.0 / tot
		if absf(p0 - p1) <= 15.0 and ((p0 <= 30.0 and p1 <= 30.0) or (t.alive_count(0) <= 3 and t.alive_count(1) <= 3)) and not t.finished:
			return true
	return false


## 1.2.0：每組截圖從乾淨存檔開始後，流程裡第一次達成的成就會跳提示蓋到畫面（原本共用存檔時早就解鎖過）→ 截圖照樣解鎖、不排提示
func _ach(id: String) -> void:
	super._ach(id)
	ach_queue.clear()

func _run_screenshots() -> void:
	# 全套截圖要跑很久：視窗移到畫面外、不搶焦點，不打擾正在用電腦的人。
	# 最小化會讓 frame_post_draw 永遠不來（_snap 卡死），移到外面也就不會被按到。
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-4000, -4000))
	await get_tree().process_frame
	if "--shot-v9" in OS.get_cmdline_user_args():
		Save.data["unlock_games"] = 99
		await _shots_v9()
		get_tree().quit()
		return
	Save.data["stats"] = {"wins": 0, "games": 99}   # 截圖用暫存存檔：新兵全部解鎖（第四輪）
	Save.data["unlock_games"] = 99
	for i in 160:
		demo.step()
	await _snap("01_title.png")
	overlay = "hub_play"   # V1.5 主畫面第二層卡片
	await _snap("01b_hub_play.png")
	overlay = "hub_challenge"
	await _snap("01c_hub_challenge.png")
	overlay = "hub_collect"
	await _snap("01d_hub_collect.png")
	overlay = "hub_gauntlet"   # V1.0.0 H1
	await _snap("01e_hub_gauntlet.png")
	overlay = ""
	difficulty = 1
	_start_mode(Mode.VS_AI)
	for s in [[D.SHIELD, 5, 3], [D.SHIELD, 5, 5], [D.SWORD, 4, 2], [D.SWORD, 4, 6], [D.SWORD, 4, 4],
			[D.ARCHER, 1, 3], [D.ARCHER, 1, 5], [D.ARCHER, 0, 4], [D.CAVALRY, 3, 0], [D.CAVALRY, 3, 8], [D.ASSASSIN, 2, 4],
			[D.ARCHER, 1, 2], [D.ARCHER, 1, 6], [D.SWORD, 4, 3], [D.SWORD, 4, 5], [D.CAVALRY, 3, 4], [D.ASSASSIN, 2, 2], [D.SHIELD, 5, 4]]:
		armies[0].place(s[0], s[1], s[2])
	selected = D.ARCHER
	mouse = ORIGIN + Vector2(2.5, 6.5) * CS
	await _snap("02_place.png")
	# 找一個會出現「最後時刻」的對手，截圖才拍得到
	var red_pick = null
	for k in 120:
		var r := RandomNumberGenerator.new()
		r.seed = 777 + k
		var cand = AI.build(1, 100, r)["army"]
		if _would_clutch(armies[0], cand):
			red_pick = cand
			break
	if red_pick != null:
		last_player_formation = armies[0].units.duplicate(true)
		ai_name = L.t("diff_normal")
		_begin_battle(armies[0].copy(), red_pick.copy())
	else:
		_on_start()
	for i in 150:
		_sim_step(true)
	for f in fx:
		f["t"] = 0.0
	await _snap("03_battle.png")
	# V1.5：遠程飛行物（弓箭手、投彈兵、骷髏法師的紫火、醫者的十字光）在命中前飛在半空
	var pa := Army.new(0, 200)
	pa.units = [{"type": 2, "col": 3, "row": 2}, {"type": 2, "col": 3, "row": 4}, {"type": 6, "col": 2, "row": 3}, {"type": 6, "col": 2, "row": 6}, {"type": 17, "col": 1, "row": 4}, {"type": 7, "col": 3, "row": 5}, {"type": 1, "col": 5, "row": 3}, {"type": 1, "col": 5, "row": 5}]
	var pe := Army.new(1, 200)
	pe.units = [{"type": 0, "col": 10, "row": 2}, {"type": 0, "col": 10, "row": 4}, {"type": 0, "col": 10, "row": 6}, {"type": 9, "col": 11, "row": 3}, {"type": 9, "col": 11, "row": 5}]
	rules = null
	_start_mode(Mode.VS_AI)
	_begin_battle(pa, pe)
	# 一直跑到有兩個以上飛行物在半空（進度 0.25～0.75）才拍
	for i in 300:
		_sim_step(true)
		var mid := 0
		for u in view.units:
			if u.alive and atk_hit.has(u.id):
				var ph: Array = proj_phase(atk_hit[u.id], float(view.tick) + 0.5, u.type, view.delay)
				if float(ph[2]) > 0.25 and float(ph[2]) < 0.75:
					mid += 1
		if mid >= 2:
			break
	accum = 0.025
	await _snap("03c_projectiles.png")
	call("_open_pause_menu")   # V1.5 暫停選單
	await _snap("03d_pause_menu.png")
	call("_pause_resume")
	clutch_t = 0.0   # 這一場的「最後時刻」橫幅不要留到後面的截圖
	slow_left = 0.0
	fx.clear()
	# 技能特效樣品（第二輪方案 R4）：在戰場上方一排，每種特效停在 35% 的時刻
	var saved_fx := fx.duplicate()
	fx.clear()
	var y0 := 150.0
	var kinds := [
		{"kind": "aim", "a": Vector2(170, y0), "b": Vector2(250, y0 + 6), "dur": 0.32},
		{"kind": "hide", "p": Vector2(320, y0), "dir": 1.0, "dur": 0.4},
		{"kind": "trip", "p": Vector2(420, y0 + 20), "dur": 0.5},
		{"kind": "shard", "p": Vector2(520, y0), "dur": 0.5},
		{"kind": "vslash", "p": Vector2(620, y0), "dir": 1.0, "dur": 0.3},
		{"kind": "flash", "p": Vector2(620, y0), "c": Color("#c77dff"), "dur": 0.25},
		{"kind": "taunt", "p": Vector2(730, y0 + 20), "dur": 0.6},
		{"kind": "bang", "p": Vector2(830, y0), "dur": 0.7},
		{"kind": "puff", "p": Vector2(930, y0), "dur": 0.45},
		{"kind": "ripple", "p": Vector2(1030, y0), "c": ACCENT, "dur": 0.35},
		{"kind": "boom", "p": Vector2(220, y0 + 110), "dur": 0.45},
		{"kind": "healarc", "a": Vector2(330, y0 + 110), "b": Vector2(420, y0 + 100), "dur": 0.25},
		{"kind": "note", "p": Vector2(520, y0 + 100), "dur": 0.8},
	]
	for f in kinds:
		f["t"] = f["dur"] * 0.35
		fx.append(f)
	var stunned = null
	for u in view.units:   # 只改畫面快照，不碰模擬（Codex R3 第 2 輪建議）
		if u.alive and u.type == D.CAVALRY and u.stun == 0:
			stunned = u
			u.stun = 10
			break
	freeze_fx = true
	await _snap("12_fx.png")
	anim_gallery = true
	await _snap("13_poses.png")
	gallery_page = 1
	await _snap("13b_poses_new.png")
	gallery_page = 0
	anim_gallery = false
	Save.settings["colorblind"] = true
	_rebuild_sprites()
	for i in 4:
		await get_tree().process_frame
	await _snap("14_colorblind.png")
	Save.settings["colorblind"] = shot_state.has("cb")
	_rebuild_sprites()
	for i in 4:
		await get_tree().process_frame
	# V1.2：簡化介面（plain_ui）同一個戰鬥畫面，確認能回到平面介面
	Save.settings["plain_ui"] = true
	_rebuild_sprites()
	for i in 4:
		await get_tree().process_frame
	await _snap("14b_plain_ui.png")
	Save.settings["plain_ui"] = shot_state.has("plain")
	_rebuild_sprites()
	for i in 4:
		await get_tree().process_frame
	freeze_fx = false
	if stunned != null:
		stunned.stun = 0   # 只是為了截圖，還原，不影響接下來的模擬
	fx = saved_fx
	while not view.finished and not slow_used:
		_sim_step(true)
		_check_clutch()
	if slow_used and not view.finished:
		for k in 120:
			_frame_alive(0.1)
			zoom = lerpf(zoom, zoom_target, 0.3)
		await _snap("04_clutch.png")
	while not view.finished:
		_sim_step(false)
	zoom = 1.0
	_finish_battle()
	await _snap("05_result.png")
	result_tab = 1
	await _snap("05b_result_details.png")
	if pc_shot != null:   # V1.4 #14 戰報明信片
		overlay = "postcard"
		await _snap("05c_postcard.png")
		overlay = ""
	overlay = "share"   # V1.6 #5
	await _snap("05d_share.png")
	overlay = ""
	result_tab = 0
	puzzle_id = "p1"
	_start_mode(Mode.PUZZLE)
	selected = D.CAVALRY
	mouse = ORIGIN + Vector2(3.5, 2.5) * CS
	await _snap("06_puzzle.png")
	duel_rule = "snake5"
	_start_mode(Mode.DUEL)
	tp.place(D.SHIELD, 5, 4)
	tp.place(D.SWORD, 5, 3)
	tp.place(D.SWORD, 5, 5)
	tp.end_turn()
	tp.place(D.CAVALRY, 12, 0)
	tp.place(D.ARCHER, 14, 4)
	selected = D.SHIELD
	mouse = ORIGIN + Vector2(4.5, 1.5) * CS
	await _snap("07_duel.png")
	_go_title()
	overlay = "settings"
	await _snap("08_settings.png")
	settings_tab = 1   # V1.5 設定七頁：介面
	await _snap("08e_settings_ui.png")
	settings_tab = 2   # 聲音（總音量、四條、夜間、單聲道）
	await _snap("08d_settings_sound.png")
	settings_tab = 3   # 操作
	await _snap("08f_settings_controls.png")
	settings_tab = 4   # 戰場與觀戰
	await _snap("08g_settings_battle.png")
	settings_tab = 5   # 無障礙（三個一鍵預設）
	await _snap("08c_settings_visual.png")
	preset_undo = {"reduce_motion": false}   # V1.5.2 L9：套用預設後「撤回」鈕出現（原本被右側說明欄蓋住）
	await _snap("08l_settings_undo.png")
	preset_undo = {}
	settings_tab = 6   # 資料
	await _snap("08h_settings_data.png")
	settings_tab = 0
	overlay = "clear_data"
	clear_pick = {1: true}
	await _snap("08i_clear_data.png")
	clear_pick = {}
	overlay = "restore"
	await _snap("08j_restore.png")   # V1.5.2：截圖前綴的備份資料夾＝空資料
	# V1.5.2 滿資料：備份 10 份（假檔寫在截圖前綴的備份資料夾，截完刪掉；不碰玩家真正的備份）
	assert(Save.prefix != "")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(backup_dir()))
	for k in 10:
		var bf := FileAccess.open(backup_dir() + "/progress_202611%02d_120000.json" % (k + 1), FileAccess.WRITE)
		bf.store_string("{}")
		bf.close()
	await _snap("08j_restore@full.png")
	for k in 10:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_dir() + "/progress_202611%02d_120000.json" % (k + 1)))
	# V1.5.2 確認框最長文字：一鍵預設改很多項（清單放不下時截前幾項＋「…等另外 M 項」）
	var long_items: Array = []
	for k in 16:
		long_items.append("%s：%s → %s" % [L.t("set_text"), "100%", "150%"])
	_ask_confirm(L.t("preset_q", [long_items.size()]), Callable(), "settings", long_items)
	await _snap("08m_confirm@long.png")
	overlay = "first_run"
	await _snap("08k_first_run.png")
	overlay = ""
	overlay = "keys"
	await _snap("08b_keys.png")
	overlay = "puzzles"
	Save.data["tutorial"] = 3
	await _snap("09_puzzles.png")
	Save.data["unit_wins"] = {"3": 5}
	_open_codex(D.CAVALRY)
	cx_skill = 0
	_cx_restart()
	for i in 46:
		_codex_tick(0.05)
	await _snap("10_codex.png")
	_scroll_by("left", 9999.0)   # 捲到底（第三輪 U1）
	await _snap("10b_codex_scrolled.png")
	# V1.5.1 近看模式：弓箭手箭飛到一半、召喚物頁
	_open_codex(D.ARCHER)
	cx_zoom = true
	cx_zplay = false
	cx_zt = 0.33
	await _snap("10c_codex_zoom.png")
	_cx_pick_unit(D.total())
	cx_zplay = false
	cx_zt = 0.2
	await _snap("10d_codex_summon.png")
	cx_zoom = false
	cx_zplay = true
	# V1.5.1 A7：小劇場弓箭手：找一個箭在半空的時刻
	_open_codex(D.ARCHER)
	for i in 160:
		_codex_tick(0.05)
		var flying := false
		for uid in cx_ptgt:
			if cx_hits.has(uid):
				var phx := proj_phase(cx_hits[uid], cx_view.tick + 0.5, D.ARCHER, cx_view.delay, cx_ptgt[uid])
				if float(phx[2]) > 0.25 and float(phx[2]) < 0.75:
					flying = true
		if flying:
			cx_acc = 0.025
			break
	await _snap("10e_codex_archer_demo.png")
	_open_codex(D.ASSASSIN)
	_cx_pick_skill(1)
	for i in 70:
		_codex_tick(0.05)
	await _snap("11_codex_locked.png")
	overlay = ""
	# 覆盤與重播控制（第三輪 S5）：用 05 那一場
	mode = Mode.VS_AI
	_open_review()
	var u0: Dictionary = rv_army.units[0]
	rv_sel = Vector2i(int(u0["col"]), int(u0["row"]))
	_rv_set_type(D.SHIELD if int(u0["type"]) != D.SHIELD else D.SWORD)
	_rv_recalc()
	await _snap("16_review.png")
	# V1.4 #1 時光機：播放「如果」，原本時間線畫成地上的白圈
	_rv_play()
	while seek_target >= 0:
		_seek_pump()
		await get_tree().process_frame
	for i in 60:
		_sim_step(false)
	await _snap("16b_time_machine.png")
	overlay = ""
	_begin_battle(last_armies[0].copy(), last_armies[1].copy(), "replay")
	for i in 260:
		_sim_step(true)
	for f in fx:
		f["t"] = 0.0
	paused = true
	await _snap("15_replay.png")
	_breport_open()   # 1.1.0 B10：手把重播戰報面板
	await _snap("v110_04_breport.png")
	_breport_close()
	paused = false
	await _shots_v4()
	await _shots_cmd()
	await _shots_v13()
	await _shots_v16()
	await _pad_walk()
	get_tree().quit()


## 第四輪新兵種的截圖：新兵擺陣（投彈兵範圍預覽）、新兵混戰、圖鑑新兵、殘局新兵分頁、未解鎖卡。
func _shots_v4() -> void:
	_go_title()
	overlay = ""
	difficulty = 1
	_start_mode(Mode.VS_AI)
	for s in [[D.SHIELD, 5, 3], [D.SHIELD, 5, 4], [D.SHIELD, 5, 5], [D.PIKE, 4, 3], [D.PIKE, 4, 4], [D.PIKE, 4, 5],
			[D.BERSERKER, 5, 1], [D.BERSERKER, 5, 7], [D.DRUMMER, 3, 4], [D.MEDIC, 2, 4], [D.BOMBER, 0, 3], [D.BOMBER, 0, 5],
			[D.ARCHER, 1, 2], [D.ARCHER, 1, 6], [D.SWORD, 4, 2], [D.SWORD, 4, 6]]:
		armies[0].place(s[0], s[1], s[2])
	selected = D.BOMBER
	hover_card = -1
	mouse = ORIGIN + Vector2(1.5, 4.5) * CS
	await _snap("17_place_new.png")
	selected = D.DRUMMER
	mouse = ORIGIN + Vector2(3.5, 4.5) * CS
	await _snap("17b_place_drum.png")
	var r := RandomNumberGenerator.new()
	r.seed = 4242
	var red = AI.build(1, 100, r, 7)["army"]   # 砲擊陣
	last_player_formation = armies[0].units.duplicate(true)
	ai_name = L.t("diff_normal")
	_begin_battle(armies[0].copy(), red.copy())
	for i in 170:
		_sim_step(true)
	await _snap("18_battle_new.png")
	_go_title()
	Save.data["unit_wins"] = {"7": 5}
	_open_codex(D.MEDIC)
	cx_skill = 0
	_cx_restart()
	for i in 60:
		_codex_tick(0.05)
	await _snap("19_codex_new.png")
	overlay = "puzzles"
	puzzle_tab = 1
	Save.data["stats"] = {"wins": 0, "games": 6}   # 解鎖到投彈兵：醫者、鼓手、狂戰士的關卡是鎖住的
	Save.data["unlock_games"] = 6
	await _snap("20_puzzles_new.png")
	puzzle_tab = 0
	overlay = ""
	_start_mode(Mode.VS_AI)
	selected = D.SWORD
	hover_card = D.MEDIC
	await _snap("21_place_locked.png")
	hover_card = -1
	# 第五輪：規則大廳（精簡、卡池、讓子、雙人、沙盒）
	Save.data["last_rules"] = {}
	_go_title()
	_open_lobby("ai")
	mouse = Vector2(-100, -100)
	await _snap("22_lobby.png")
	# V1.5.2 空／滿資料：「我的預設」下拉 0 筆、10 筆（上限）
	var rp_keep = Save.data.get("rule_presets", [])
	Save.data["rule_presets"] = []
	lobby_menu = true
	await _snap("22c_lobby_menu@empty.png")
	var rp10: Array = []
	for k in Save.MAX_PRESETS:
		rp10.append({"name": L.t("lb_my_n", [k + 1]), "code": lobby_r.to_code()})
	Save.data["rule_presets"] = rp10
	await _snap("22c_lobby_menu@full.png")
	lobby_menu = false
	Save.data["rule_presets"] = rp_keep
	lobby_open = true
	lobby_tab = 2
	lobby_r.ai_pool_same = false
	lobby_r.pool[1] = 0b0000011111
	_lobby_touch()
	lobby_item = "pool"
	await _snap("23_lobby_pool.png")
	lobby_tab = 0
	lobby_r.ai_pool_same = true
	lobby_r.handicap = true
	lobby_r.budget = [80, 140]
	lobby_r.type_cap = 2
	_lobby_touch()
	lobby_item = "handicap"
	await _snap("24_lobby_army.png")
	lobby_tab = 5
	lobby_sb_unit = D.CAVALRY
	lobby_r.stat_pct[D.CAVALRY] = [120, 80, 150]
	lobby_r.skills_off = ["charge"]
	lobby_item = "lab"
	await _snap("26_lobby_lab.png")
	_open_lobby("duel")
	await _snap("25_lobby_duel.png")
	overlay = ""
	await _shots_v6()
	await _shots_v8()
	await _shots_v9()


## 第六輪：自由排兵（擺好的陣、畫筆預覽、框選、明牌全場、雙人全場、大廳部署分頁、覆盤）。
func _free_rules(full := 0):
	var r = RuleSet.standard()
	r.deploy = "free"
	r.spacing = Presets.FREE_SPACING
	r.depth = Presets.FREE_DEPTH
	r.fullfield = full
	return r

## 第八輪：奇幻軍。
## V9：每張地圖的部署與戰鬥；大小各拍一張。版面檢查靠這幾行數張數：
# _snap("50_map_river_place.png")
# _snap("50_map_river_battle.png")
# _snap("51_map_forest_place.png")
# _snap("51_map_forest_battle.png")
# _snap("52_map_ice_place.png")
# _snap("52_map_ice_battle.png")
# _snap("53_map_lava_place.png")
# _snap("53_map_lava_battle.png")
# _snap("54_map_canyon_place.png")
# _snap("54_map_canyon_battle.png")
# _snap("55_map_small_place.png")
# _snap("55_map_small_battle.png")
# _snap("56_map_large_place.png")
# _snap("56_map_large_battle.png")
func _shots_v9() -> void:
	_go_title()
	Save.data["trial_stars"] = {"0": 3, "1": 2, "2": 1}
	_open("trials")
	for k3 in 12:
		await get_tree().process_frame
	await _snap("58_trials.png")
	# V1.5.1：截圖存檔會累積場數，戰績頁用固定樣本（場數、勝場同口徑）
	Save.data["stats"] = {"wins": 18, "games": 40}
	Save.data["unit_games"] = {"0": 12, "2": 10, "3": 8, "13": 4}
	Save.data["unit_games_rec"] = {"0": 12, "2": 10, "3": 8, "13": 4}
	Save.data["unit_wins_rec"] = {"0": 7, "2": 4, "3": 5, "13": 1}
	overlay = ""
	_open("profile")
	await _snap("59_profile.png")
	# V1.4 #2 宿敵戰記（範例資料，截完還原）
	var nem_keep = Save.data.get("nemeses", [])
	Save.data["nemeses"] = [{"units": [{"type": 5, "col": 10, "row": 2}, {"type": 5, "col": 10, "row": 3}, {"type": 2, "col": 12, "row": 4}, {"type": 1, "col": 10, "row": 5}], "losses": 2, "revenged": false, "stage": 3},
		{"units": [{"type": 3, "col": 11, "row": 1}, {"type": 9, "col": 10, "row": 4}, {"type": 7, "col": 13, "row": 4}], "losses": 1, "revenged": true, "stage": 5}]
	overlay = "nemeses"
	await _snap("59b_nemeses.png")
	Save.data["nemeses"] = []   # V1.5.2 空資料：面板照內容縮高、不留 500px 空白
	await _snap("59b_nemeses@empty.png")
	var nem6: Array = []   # V1.5.2 滿資料：6 筆（上限）不碰返回鈕
	for k in 6:
		nem6.append({"units": [{"type": k, "col": 10, "row": 2}, {"type": 5, "col": 11, "row": 3}], "losses": k + 1, "revenged": k % 2 == 0, "stage": k + 1})
	Save.data["nemeses"] = nem6
	await _snap("59b_nemeses@full.png")
	Save.data["nemeses"] = nem_keep
	var pt_keep: Array = Art.paint.duplicate()   # V1.4 #15 塗裝室（藍改靛青、紅改赭橙、胡桃木座、朱漆框）
	Art.paint[0] = 1
	Art.paint[1] = 2
	Art.paint[4] = 1
	Art.paint[5] = 3
	overlay = "paint"
	await _snap("59h_paint.png")
	for i in 6:
		Art.paint[i] = pt_keep[i]
	overlay = ""
	# V1.4 #5 接力殘局：拿第一個能做成工坊碼的關卡當素材
	for p0 in PZ.all_puzzles():
		if PZ.goal(p0) == "win" and p0.get("fixed", []).is_empty() and not p0.has("map") and not p0.has("cmd") and p0.has("best"):
			var dws: Dictionary = WS.decode(WS.encode(p0["enemy"], p0["best"]["u"], 2))
			if bool(dws["ok"]):
				PZ.set_custom(dws["pz"])
				_open_relay()
				rl_sel = Vector2i(10, 4)
				_relay_set(int(rl_types[0]))
				await _snap("59c_relay.png")
				overlay = ""
			break
	# V1.4 #16 遊戲間
	overlay = "playroom"
	await _snap("59d_playroom.png")
	_wager_new()
	wg_pick = [0, 1]
	await _snap("59e_wager.png")
	_draft_new()
	_draft_take(int(df_pool[0]))
	await _snap("59f_draft.png")
	overlay = ""
	_sealed_start()   # V1.4 #13：雙封蠟擺陣頁（藍軍第 2 封）
	sealed[0].append([])
	await _snap("59g_sealed.png")
	toast_t = 0.0
	var gb_keep = Save.data.get("ghost_beat", [])   # V1.4 #7 幽靈軍團（破了兩個）、每週棋盒
	Save.data["ghost_beat"] = ["g01", "g04"]
	overlay = "ghosts"
	await _snap("59i_ghosts.png")
	Save.data["ghost_beat"] = gb_keep
	overlay = "weekly"
	await _snap("59j_weekly.png")
	overlay = ""
	_start_mode(Mode.VS_AI)
	overlay = ""
	_open("reward")
	await _snap("60_reward.png")
	ev_pick = 1   # V1.4 收尾：選了事件、還沒按「前往下一站」
	await _snap("60a_reward_picked.png")
	ev_pick = -1
	var gst_keep: int = gauntlet_stage
	gauntlet_stage = maxi(2, gauntlet_stage)
	gauntlet_contract = 0
	if not armies[0].units.is_empty():
		armies[0].units[0]["st"] = 3
	overlay = "ga_info"
	await _snap("60b_ga_info.png")
	gauntlet_contract = -1
	gauntlet_stage = gst_keep
	rules = RuleSet.standard()
	rules.pool = [RuleSet.all_pool(), RuleSet.all_pool()]
	ban_left = [1, 1]
	_open("ban")
	await _snap("61_ban.png")
	# 第十輪 T1：極端資料與新畫面
	rules.ai_pool_same = false
	rules.pool = [1023, ~1023 & ((1 << 20) - 1)]
	await _snap("62_ban_20.png")
	rules.pool = [RuleSet.all_pool(), RuleSet.all_pool()]
	mode = Mode.GAUNTLET
	overlay = "leave"
	await _snap("63_leave.png")
	mode = Mode.VS_AI
	overlay = "codes"
	await _snap("64_codes.png")
	Save.data["gauntlet_run"] = {"stage": 4, "seed": 1, "gold": 10, "cap": 2, "changes": 3, "pool": 0, "prev": []}
	overlay = "gauntlet_resume"
	await _snap("65_gauntlet_resume.png")
	Save.data["gauntlet_run"] = {}
	rules = null
	overlay = ""
	_go_title()
	_open_lobby("ai")
	_lobby_pick("standard")
	lobby_r.map_id = 1
	lobby_r.ai_style = 1
	for k1 in 12:
		await get_tree().process_frame
	await _snap("57_lobby_map.png")
	lobby_r.map_id = 0
	overlay = ""
	for spec in [[1, 1, "50_map_river"], [2, 1, "51_map_forest"], [3, 1, "52_map_ice"], [4, 1, "53_map_lava"], [5, 1, "54_map_canyon"], [1, 0, "55_map_small"], [5, 2, "56_map_large"]]:
		_go_title()
		overlay = ""
		toast_t = 0.0
		ach_queue.clear()
		difficulty = 1
		_open_lobby("ai")
		_lobby_pick("standard")
		lobby_open = false
		overlay = ""
		rules = lobby_r.copy()
		rules.map_id = spec[0]
		rules.map_size = spec[1]
		rules.deploy = "free"
		rules.spacing = 800
		rules.depth = 6000
		_start_mode(Mode.VS_AI)
		show_place_help = false
		var a = armies[0]
		var hh: int = a.fh
		for s in [[D.SWORD, 5000, 2000], [D.SWORD, 5000, 6000], [D.SHIELD, 5200, 4000], [D.ARCHER, 2500, 3000], [D.ARCHER, 2500, 5000], [D.CAVALRY, 3500, 1200], [D.ASSASSIN, 3000, 7000]]:
			var ox: int = mini(int(s[1]), a.depth - 100)
			a.place_xy(int(s[0]), a.world_x(Army.quant(ox)), Army.quant(int(s[2]) * hh / 9000))
		for k0 in 10:
			await get_tree().process_frame     # 等地圖烘好
		await _snap(str(spec[2]) + "_place.png")
		if spec[1] == 1 or spec[1] == 2 or spec[1] == 0:
			_on_start()
			for k in 60:
				await get_tree().process_frame
			await _snap(str(spec[2]) + "_battle.png")
	rules = null
	_go_title()

func _shots_v8() -> void:
	_go_title()
	overlay = ""
	toast_t = 0.0
	ach_queue.clear()
	difficulty = 1
	Save.data["unlock_games"] = 60
	Save.data["stats"] = {"wins": 0, "games": 60}
	_open_lobby("ai")
	_lobby_pick("fantasy")
	await _snap("32_lobby_fantasy.png")
	lobby_open = true
	lobby_tab = LOBBY_TABS.find("lb_tab_pool")
	await _snap("33_lobby_roster.png")
	lobby_r.ai_pool_same = false
	lobby_r.pool[1] = 0b1111111111
	lobby_pool_team = 1
	await _snap("39_lobby_roster_ai.png")
	lobby_pool_team = 0
	await _snap("40_lobby_roster_two.png")
	lobby_r.ai_pool_same = true
	lobby_r.pool[1] = lobby_r.pool[0]
	lobby_open = false
	overlay = ""
	rules = lobby_r.copy()
	_start_mode(Mode.VS_AI)
	var a = armies[0]
	for s in [[F8.GOLEM, 5400, 4400], [13, 5600, 2600], [13, 5600, 6200], [10, 4800, 3200], [12, 5800, 7600], [14, 3800, 4400], [15, 5600, 1200], [16, 3800, 2800], [17, 1800, 4400], [18, 3800, 6000], [11, 3000, 1400]]:
		a.place_xy(int(s[0]), Army.quant(s[1]), Army.quant(s[2]))
	selected = F8.DOLL
	show_place_help = false
	mouse = ORIGIN + Vector2(3.0, 3.0) * CS
	toast_t = 0.0
	await _snap("34_fantasy_place.png")
	var rr := RandomNumberGenerator.new()
	rr.seed = 919
	var red = AI.build(1, 100, rr, 12, rules.pool_of(1), rules)["army"]
	ai_name = L.t("diff_normal")
	sprites.ensure(RuleSet.types_of(RuleSet.full_pool() - RuleSet.all_pool()) + [20, 21])
	await get_tree().create_timer(0.3).timeout
	while sprites._busy:
		await get_tree().process_frame
	_begin_battle(a.copy(), red.copy())
	for i in 190:
		_sim_step(true)
	await _snap("35_fantasy_battle.png")
	for i in 220:
		_sim_step(true)
	await _snap("36_fantasy_late.png")
	_go_title()
	Save.data["unit_wins"] = {"13": 5}
	_open_codex(F8.SLIME)
	cx_skill = 0
	_cx_restart()
	for i in 60:
		_codex_tick(0.05)
	await _snap("37_codex_fantasy.png")
	overlay = "puzzles"
	puzzle_tab = 2
	await _snap("38_puzzles_fantasy.png")
	overlay = "gauntlet_pick"
	await _snap("41_gauntlet_pick.png")
	overlay = ""
	puzzle_tab = 0
	overlay = ""
	rules = null

func _shots_v6() -> void:
	_go_title()
	overlay = ""
	toast_t = 0.0
	ach_queue.clear()
	difficulty = 1
	rules = _free_rules()
	_start_mode(Mode.VS_AI)
	var a = armies[0]
	for s in [[D.SHIELD, 5600, 3000], [D.SHIELD, 5800, 3900], [D.SHIELD, 5800, 4800], [D.SHIELD, 5600, 5700],
			[D.PIKE, 4700, 3500], [D.PIKE, 4800, 4400], [D.PIKE, 4700, 5300], [D.SWORD, 5800, 1500], [D.SWORD, 5800, 7400],
			[D.ARCHER, 2900, 2800], [D.ARCHER, 2600, 4500], [D.ARCHER, 2900, 6200], [D.CAVALRY, 3900, 1000], [D.CAVALRY, 3900, 8000]]:
		a.place_xy(s[0], Army.quant(s[1]), Army.quant(s[2]))
	selected = D.ARCHER
	show_place_help = false
	mouse = ORIGIN + Vector2(2.0, 3.6) * CS
	toast_t = 0.0
	await _snap("27_free_place.png")
	# 畫筆預覽：從左上往下拖一條
	selected = D.SWORD
	_fs_begin(_w_of(ORIGIN + Vector2(1.2, 1.0) * CS))
	for k in 12:
		mouse = ORIGIN + Vector2(1.2 + k * 0.05, 1.0 + k * 0.6) * CS
		_fs_extend(_w_of(mouse))
	await _snap("27b_free_brush.png")
	_fs_cancel()
	# 框選：選前排四面盾
	fp_tool = "select"
	fp_sel = [0, 1, 2, 3]
	mouse = ORIGIN + Vector2(6.3, 4.5) * CS
	await _snap("27c_free_select.png")
	fp_sel = []
	fp_tool = "brush"
	# 打一場，留給覆盤
	var keep = armies[0].copy()
	_build_ai()
	last_player_formation = keep.units.duplicate(true)
	_begin_battle(keep.copy(), armies[1].copy())
	while not view.finished:
		_sim_step(false)
	_finish_battle()
	_open_review()
	toast_t = 0.0
	ach_queue.clear()
	rv_fsel = 1
	_rv_free_click(Vector2i(4600, 2000))
	_rv_recalc()
	await _snap("31_review_free.png")
	overlay = ""
	# 對 AI 明牌全場
	rules = _free_rules(2)
	_start_mode(Mode.VS_AI)
	for s in [[D.CAVALRY, 6500, 800], [D.CAVALRY, 6500, 8200], [D.SHIELD, 6500, 4500], [D.ARCHER, 3000, 4500]]:
		armies[0].place_xy(s[0], Army.quant(s[1]), Army.quant(s[2]))
	selected = D.ASSASSIN
	mouse = ORIGIN + Vector2(10.5, 4.5) * CS
	toast_t = 0.0
	await _snap("28_free_full_ai.png")
	# 雙人輪流全場
	rules = _free_rules(1)
	_start_mode(Mode.DUEL)
	tp.place_batch([[D.SHIELD, 6000, 4000], [D.SHIELD, 6000, 5000]])
	tp.end_turn()
	tp.place_batch([[D.CAVALRY, 9500, 4500], [D.ARCHER, 12500, 4500]])
	tp.end_turn()
	selected = D.PIKE
	mouse = ORIGIN + Vector2(5.0, 6.0) * CS
	toast_t = 0.0
	await _snap("29_free_duel_full.png")
	# 大廳：部署分頁
	rules = null
	_go_title()
	_open_lobby("ai")
	lobby_open = true
	lobby_tab = 1
	lobby_r.deploy = "free"
	lobby_r.spacing = Presets.FREE_SPACING
	lobby_r.depth = Presets.FREE_DEPTH
	lobby_r.fullfield = 2
	_lobby_touch()
	lobby_item = "fullfield"
	mouse = Vector2(-100, -100)
	toast_t = 0.0
	await _snap("30_lobby_deploy.png")
	overlay = ""


## 1.1.0 A19：圖集有界快取的量測。依序模擬「每場帶不同新兵」：每輪要求 3 種奇幻兵（含召喚物）＋轉身出手格，
## 記每輪後的貼圖記憶體與烘焙期間最長一幀；全部 12 種奇幻兵輪過兩次（第二次會丟舊頁），看峰值有沒有被頁數上限壓住。
func _perf_atlas_sweep() -> Dictionary:
	if sprites == null:
		return {}
	var fan: Array = range(D.COUNT, 22)
	var rounds: Array = []
	var peak := 0.0
	var worst_frame := 0.0
	for rep in 2:
		for i in range(0, fan.size(), 3):
			var want: Array = fan.slice(i, i + 3)
			var t0 := Time.get_ticks_msec()
			sprites.ensure(want)
			sprites.ensure_turn_atk(want)
			var last := Time.get_ticks_usec()
			var longest := 0.0
			var guard := 0
			while (sprites._busy or sprites._ta_busy) and guard < 600:
				guard += 1
				await RenderingServer.frame_post_draw
				var now := Time.get_ticks_usec()
				longest = maxf(longest, (now - last) / 1000.0)
				last = now
			var mem := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0
			peak = maxf(peak, mem)
			worst_frame = maxf(worst_frame, longest)
			rounds.append({"types": want, "ms": Time.get_ticks_msec() - t0, "tex_mib": snappedf(mem, 0.1), "longest_frame_ms": snappedf(longest, 0.1),
				"pages": sprites.pages.filter(func(p): return p != null).size(), "ta": sprites.ta_tex.size()})
	return {"peak_tex_mib": snappedf(peak, 0.1), "worst_bake_frame_ms": snappedf(worst_frame, 0.1), "max_pages": sprites.MAX_PAGES, "ta_max": sprites.TA_MAX, "rounds": rounds}

## 繪圖效能量測（第二輪 R2、第三輪 T3）：
## ・啟動時間（引擎啟動到量測開始）、色盲切換的圖集重建時間
## ・48 隻（每邊 24，量測專用的 160 金預算，五兵種混合）打完整場，展示速度 4 倍（約 25 秒內走到狂熱與結束）
## ・每幀的 draw／process／GPU／整幀時間：全場、非狂熱、狂熱分開統計，含 p99；記錄硬體、引擎版本、commit（--perf-commit=）
## 用法：<exe> --path game --resolution 1280x800 -- --perf=<輸出 json 絕對路徑> [--perf-commit=<hash>]
func _run_perf() -> void:
	var boot_ms := Time.get_ticks_msec()
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)   # V1.1：量效能時視窗移到畫面外（不打擾、也不是最小化，照常繪圖）
	DisplayServer.window_set_position(Vector2i(-4000, -4000))
	await get_tree().process_frame
	var waited := 0
	while sprites != null and not sprites.is_ready(cbm()) and waited < 240:
		await get_tree().process_frame
		waited += 1
	var ready_ms := Time.get_ticks_msec()
	# 色盲切換：圖集重建要多久
	Save.settings["colorblind"] = true
	var t_cb := Time.get_ticks_msec()
	_rebuild_sprites()
	waited = 0
	while sprites != null and not sprites.is_ready(true) and waited < 240:
		await get_tree().process_frame
		waited += 1
	var cb_ms := Time.get_ticks_msec() - t_cb
	Save.settings["colorblind"] = shot_state.has("cb")
	_rebuild_sprites()
	waited = 0
	while sprites != null and not sprites.is_ready(false) and waited < 240:
		await get_tree().process_frame
		waited += 1
	var vp := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var a0 := Army.new(0, 160)
	var spec := [D.SHIELD, D.SWORD, D.ARCHER, D.CAVALRY, D.ASSASSIN, D.ARCHER, D.SWORD, D.ARCHER]
	for r in 9:
		for c in 6:
			if a0.count() < 24:
				var t: int = spec[(r * 6 + c) % spec.size()]
				if D.cost(t) <= a0.left():
					a0.place(t, 5 - c, r)
	var a1 = a0.mirrored()
	mode = Mode.VS_AI
	_begin_battle(a0, a1, "replay")   # 量測不寫進度
	speed = 4.0
	var rows: Array = []   # [draw, proc, gpu, frame, frenzy]
	var units_start: int = view.alive_count(0) + view.alive_count(1)
	var last := Time.get_ticks_usec()
	var guard := 0
	while state == St.BATTLE and guard < 40000:
		guard += 1
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		rows.append([perf_draw_us / 1000.0, perf_proc_us / 1000.0, RenderingServer.viewport_get_measured_render_time_gpu(vp), (now - last) / 1000.0, view.frenzy])
		last = now
	var pick := func(col: int, which: int) -> Array:
		var o: Array = []
		for r2 in rows:
			if which == 0 or (which == 1 and not r2[4]) or (which == 2 and r2[4]):
				o.append(r2[col])
		return o
	var sect := func(which: int) -> Dictionary:
		return {"frames": pick.call(0, which).size(), "draw_ms": _pstats(pick.call(0, which)), "process_ms": _pstats(pick.call(1, which)),
			"gpu_ms": _pstats(pick.call(2, which)), "frame_ms": _pstats(pick.call(3, which))}
	var tex_battle := snappedf(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, 0.1)   # 對戰時（掃圖集之前）
	var atlas := await _perf_atlas_sweep()
	var commit := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--perf-commit="):
			commit = a.substr(14)
	var out := {
		"hardware": {"cpu": OS.get_processor_name(), "cores": OS.get_processor_count(), "gpu": RenderingServer.get_video_adapter_name(),
			"os": OS.get_name(), "engine": Engine.get_version_info()["string"], "resolution": str(get_viewport().get_visible_rect().size)},
		"mem_static_mib": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1), "mem_static_max_mib": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC_MAX) / 1048576.0, 0.1),
		"tex_mem_mib": tex_battle,   # V1.3.1：資源驗收（方案 §0）；1.1.0：取對戰時的值，圖集掃描的峰值另記在 atlas_sweep
		"commit": commit, "boot_ms": ready_ms, "boot_to_measure_ms": boot_ms, "colorblind_rebuild_ms": cb_ms,
		"units_start": units_start, "display_speed": 4.0, "battle_ticks": sim.tick, "reached_frenzy": sim.tick >= Sim.FRENZY_TICK,
		"all": sect.call(0), "normal": sect.call(1), "frenzy": sect.call(2), "atlas_sweep": atlas,
		"note": "frame_ms 受垂直同步限制（約 16.7）；實際成本看 draw＋process＋gpu。展示速度 4 倍時每幀處理的模擬 tick 比正常多，屬於偏嚴的量法"}
	var f := FileAccess.open(perf_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "  "))
	f.close()
	print("PERF ", JSON.stringify(out))
	get_tree().quit()

func _pstats(a: Array) -> Dictionary:
	var b := a.duplicate()
	b.sort()
	if b.is_empty():
		return {}
	return {"p50": snappedf(b[b.size() / 2], 0.01), "p95": snappedf(b[int(b.size() * 0.95)], 0.01), "p99": snappedf(b[mini(b.size() - 1, int(b.size() * 0.99))], 0.01), "max": snappedf(b[-1], 0.01)}


## 動作／表情樣品（R5 截圖驗證用）：每個兵種一列：待機、前搖、揮擊、後搖、受擊、狂熱、專屬（衝鋒／潛行／頂住）、勝利。
var anim_gallery := false
var gallery_page := 0

func _ready() -> void:
	super._ready()
	# 宣傳／驗證模式的分派（S8：原本在 game_screens 透過基底的空函式呼叫上來）
	if capsule_path != "":
		_capture_capsule.call_deferred()
	elif shot_dir != "":
		shot_fixed = "--shot-fixed" in OS.get_cmdline_user_args()
		if shot_fixed:
			seed(20261111)   # 1.2.0 §14.6：視覺回歸模式固定全域亂數（特效、待機錯開），同一份程式重拍要一致
		_run_screenshots.call_deferred()
	elif video_mode:
		_run_video.call_deferred()
	elif perf_path != "":
		_run_perf.call_deferred()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mem-check="):
			_run_mem_check.call_deferred(a.substr(12))
		elif a.begins_with("--sil="):
			_run_sil.call_deferred(a.substr(6))


## V1.0.0 角色：剪影辨識表。22 種兵（含召喚物）站成兩排：上排原尺寸、下排 50%；平塗背景，tools/gen/sil_report.py 轉灰階、
## 算輪廓相似度找出最難分的兵。用法：<exe> --path game --resolution 1280x800 -- --sil=<輸出 png 絕對路徑>
var sil_mode := false
func _run_sil(out_path: String) -> void:
	Save.prefix = "shot_"
	sil_mode = true
	for i in 6:
		await get_tree().process_frame
	queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var err := get_viewport().get_texture().get_image().save_png(out_path)
	print("SIL ", out_path, " ", err)
	get_tree().quit(0 if err == OK else 1)

func _draw() -> void:
	if not sil_mode:
		super._draw()
		return
	draw_rect(Rect2(0, 0, 1280, 800), Color(0.5, 0.5, 0.5))
	for t in 22:
		var col := t % 11
		var row := t / 11
		var x := 58.0 + col * 116.0
		Art.unit(self, Vector2(x, 150.0 + row * 210.0), t, 0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.6, false)
		Art.unit(self, Vector2(x, 560.0 + row * 110.0), t, 0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.8, false)


## 記憶體檢查（第三輪 P2）：連打 20 場（直接看結果）＋切 20 次色盲（每次重建角色圖集），
## 暖機（前 3 場）之後記錄靜態記憶體、物件數、貼圖記憶體；結束時不能持續成長。
## 用法：<exe> --path game --resolution 1280x800 -- --mem-check=<輸出 json 絕對路徑>
func _run_mem_check(out_path: String) -> void:
	Save.prefix = "shot_"
	await get_tree().process_frame
	var waited := 0
	while sprites != null and not sprites.is_ready(cbm()) and waited < 240:
		await get_tree().process_frame
		waited += 1
	var samples: Array = []
	var snap := func(tag: String) -> void:
		samples.append({"tag": tag, "static_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.01),
			"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)), "nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
			"tex_mb": snappedf(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, 0.01)})
	var rng2 := RandomNumberGenerator.new()
	mode = Mode.VS_AI
	for i in 20:
		rng2.seed = 4242 + i
		var a0: Army = AI.build(0, 100, rng2)["army"]
		var a1: Army = AI.build(1, 100, rng2)["army"]
		_begin_battle(a0, a1, "replay")
		for k in 20:
			await get_tree().process_frame
		_on_skip()
		_finish_battle()
		await get_tree().process_frame
		_go_title()
		await get_tree().process_frame
		if i == 2:
			snap.call("暖機後（第 3 場）")
	snap.call("20 場後")
	for i in 20:
		Save.settings["colorblind"] = i % 2 == 0
		_rebuild_sprites()
		waited = 0
		while sprites != null and not sprites.is_ready(cbm()) and waited < 240:
			await get_tree().process_frame
			waited += 1
		if i == 1:
			snap.call("色盲切換 2 次後")
	for k in 10:
		await get_tree().process_frame
	snap.call("色盲切換 20 次後")
	var base: Dictionary = samples[0]
	var end_b: Dictionary = samples[1]
	var cb0: Dictionary = samples[2]
	var cb1: Dictionary = samples[3]
	# 靜態記憶體、物件數、節點數、貼圖記憶體四項都要比（Codex S8 #4）
	var grew := func(a: Dictionary, b: Dictionary) -> bool:
		return b["static_mb"] > a["static_mb"] * 1.05 + 1.0 or b["objects"] > a["objects"] * 1.02 + 20 or b["nodes"] > a["nodes"] + 5 or b["tex_mb"] > a["tex_mb"] * 1.05 + 1.0
	var ok_b: bool = not grew.call(base, end_b)
	# V1.1：換色後圖集是非同步重烘（`is_ready` 只保證腳底圈好了），換色 2 次時取樣常在重烘途中、貼圖偏低，拿它當基準會誤判成長。
	# 「換色 20 次不持續增長」改跟暖機基準比（兩次取樣時用到的兵種頁相同）。
	var ok_c: bool = not grew.call(base, cb1)
	var out := {"samples": samples, "battles_ok": ok_b, "colorblind_ok": ok_c}
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "  "))
	f.close()
	print("MEMCHECK ", JSON.stringify(out))
	get_tree().quit(0 if ok_b and ok_c else 1)


func _draw_inner() -> void:
	if capsule_path != "":
		_btns.clear()
		_draw_capsule()
		return
	super._draw_inner()
	if not anim_gallery:
		return
	draw_rect(Rect2(60, 90, 1160, 640), Color(0.12, 0.16, 0.12, 0.97))
	var cols := ["待機", "前搖", "揮擊", "後搖", "受擊", "狂熱", "專屬", "勝利", "交替招式"]
	for c in cols.size():
		_text(Vector2(170 + c * 122, 100), cols[c], ts(16), Color.WHITE, true)
	for ri in 5:   # 第四輪：10 種兵分兩頁（gallery_page 0＝經典、1＝新兵）
		var t := gallery_page * 5 + ri
		var y := 220.0 + ri * 112.0
		for c in cols.size():
			var p := Vector2(170 + c * 122, y)
			var at: float = [0.0, 0.25, 0.42, 0.75, 0.0, 0.0, 0.0, Art.ATK_WINDUP, 0.52][c]
			var mood: int = [0, 0, 0, 0, Art.M_HURT, Art.M_BROWS, 0, 0, 0][c]
			var lean := 0.0
			var crouch := 1.0
			var alpha := 1.0
			var walk := 0.0
			if c == 7:   # 勝利：站直、武器高舉（和前搖分開）
				lean = Art.windup_lean(t)
				crouch = 1.06
			if c == 6 and t >= D.CLASSIC:
				at = 0.42   # 新兵的專屬動作在揮擊格（精靈圖快取把它烘在交替招式那組）
			if c == 6:
				match t:
					D.CAVALRY:
						mood = Art.M_SPARKLE; lean = 0.26; walk = 1.0
					D.ASSASSIN:
						mood = Art.M_HOOD; crouch = 0.9; alpha = 0.45
					D.SHIELD:
						mood = Art.M_BRACE
			if c == 5:   # 狂熱氣場
				draw_arc(p + Vector2(0, -36), 26.0, 0, TAU, 24, Color(1.0, 0.33, 0.2, 0.6), 3.0, true)
			_ring(p, 0, t, 1.6)
			_unit(p, t, 0, 1.0, walk, at, 0.0, alpha, 1.0, 1.6, mood, lean, crouch, (2 if t >= D.CLASSIC else 0) if c == 6 else (1 if c == 8 else 0))
			if c == 2 or c == 8:   # 揮擊殘影（依兵種，實際只有 0.12 秒）
				_draw_smear(p, t, 0, 1.0, 0.45, 1.0, 1 if c == 8 else 0, 1.6)

# ── 第十輪 T5：只用手把走主要流程。失敗印 PADWALK FAIL，版面檢查會擋 ──
var _pw_bad: Array = []

func _pw_check(cond: bool, what: String) -> void:
	if not cond:
		_pw_bad.append(what)

func _pw_btn(b: int) -> void:
	for pressed in [true, false]:
		var ev := InputEventJoypadButton.new()
		ev.button_index = b
		ev.pressed = pressed
		ev.device = 0
		_input(ev)
		await _pw_frames(2)

func _pw_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

## 方向鍵走到第 i 顆再按 A；同時確認焦點走得到。
func _pw_pick(i: int, what: String) -> void:
	await _pw_frames(2)
	_pw_check(i < _btns.size(), "%s：沒有第 %d 顆按鈕（共 %d）" % [what, i, _btns.size()])
	var guard := 0
	while _focus != i and guard < 60:
		guard += 1
		await _pw_btn(JOY_BUTTON_DPAD_DOWN)
	_pw_check(_focus == i, "%s：焦點走不到第 %d 顆" % [what, i])
	await _pw_btn(JOY_BUTTON_A)
	await _pw_frames(3)

## 這個畫面的每顆按鈕都走得到、都在畫面內。
func _pw_cycle(what: String) -> void:
	await _pw_frames(2)
	var n: int = _btns.size()
	_pw_check(n > 0, "%s：沒有按鈕" % what)
	for b in _btns:
		_pw_check(Rect2(0, 0, 1280, 800).encloses(b["r"]), "%s：按鈕超出畫面 %s" % [what, str(b["r"])])
	var seen := {}
	for k in n:
		seen[_focus] = true
		await _pw_btn(JOY_BUTTON_DPAD_DOWN)
	_pw_check(seen.size() == n, "%s：焦點只走到 %d／%d 顆" % [what, seen.size(), n])

func _pad_walk() -> void:
	_pw_bad = []
	layout_probe = false
	shot_dir = ""
	rules = null
	overlay = ""
	_go_title()
	await _pw_frames(3)
	await _pw_cycle("標題")
	for step in [[0, "hub_play"], [1, "hub_gauntlet"], [2, "hub_challenge"], [3, "playroom"], [4, "hub_collect"], [5, "settings"], [6, "codes"]]:   # V1.5：五塊木牌（0～4）＋系統列（5 設定、6 代碼、7 離開）
		_go_title()
		await _pw_pick(step[0], "標題→" + str(step[1]))
		_pw_check(overlay == step[1], "標題→%s：現在是 %s" % [step[1], overlay])
		await _pw_cycle(str(step[1]))
		await _pw_btn(JOY_BUTTON_B)
		_pw_check(overlay == "", "%s：B 關不掉" % step[1])
	_go_title()
	await _pw_pick(0, "標題→對戰")
	await _pw_pick(1, "對戰→對 AI 大廳")
	await _pw_cycle("大廳")
	_go_title()
	overlay = "reward"
	await _pw_cycle("獎勵")
	overlay = ""
	rules = RuleSet.standard()
	rules.ai_pool_same = false
	rules.pool = [1023, ~1023 & ((1 << 20) - 1)]
	ban_left = [1, 1]
	overlay = "ban"
	await _pw_cycle("禁牌 20 張")
	overlay = ""
	rules = null
	# 試煉從頭打到結果：擺一隻、開戰、跳過、看結果、回主選單
	_go_title()
	_open("trials")
	await _pw_pick(0, "試煉第 1 關")
	_pw_check(state == St.PLACE, "試煉沒有進擺放")
	await _pw_btn(JOY_BUTTON_LEFT_SHOULDER)
	var ev := InputEventJoypadButton.new()
	ev.button_index = JOY_BUTTON_A
	ev.pressed = true
	_input(ev)
	await _pw_frames(3)
	var ev2 := InputEventJoypadButton.new()
	ev2.button_index = JOY_BUTTON_A
	ev2.pressed = false
	_input(ev2)
	await _pw_frames(3)
	if armies[0].units.is_empty():
		_pw_bad.append("手把 A 擺不下兵")
		armies[0].place_xy(0, armies[0].world_x(3000), 3000)
	await _pw_btn(JOY_BUTTON_START)
	await _pw_frames(5)
	_pw_check(state == St.BATTLE, "Start 沒有開戰，現在 %d" % state)
	await _pw_btn(JOY_BUTTON_B)   # V1.5：B 打開暫停選單（第二項＝直接看結果）
	await _pw_frames(3)
	_pw_check(overlay == "pause_menu" and paused, "B 沒有打開暫停選單，現在 %s" % overlay)
	await _pw_btn(JOY_BUTTON_DPAD_DOWN)
	await _pw_frames(2)
	await _pw_btn(JOY_BUTTON_A)
	var wait := 0
	while state != St.RESULT and wait < 900:
		wait += 1
		await get_tree().process_frame
	_pw_check(state == St.RESULT, "B 跳過後沒進結果頁")
	await _pw_cycle("結果頁")
	await _pw_btn(JOY_BUTTON_B)
	await _pw_frames(3)
	if overlay == "leave":
		await _pw_pick(1, "離開確認")
	_pw_check(state == St.TITLE, "結果頁 B 沒回標題，現在 %d" % state)
	if _pw_bad.is_empty():
		print("PADWALK OK")
	else:
		print("PADWALK FAIL ", "；".join(_pw_bad))

# ── 第十二輪：手動技能的畫面 ──
func _shots_cmd() -> void:
	_go_title()
	_open_lobby("ai")
	_lobby_pick("standard")
	lobby_open = true
	lobby_tab = 6
	await _snap("70_lobby_cmd_off.png")
	_lobby_adj("cmd_on", 1)
	await _snap("71_lobby_cmd_on.png")
	lobby_open = false
	_lobby_pick("standard")
	_lobby_adj("cmd_on", 1)
	await _snap("72_lobby_cmd_quick.png")
	lobby_r.cmd_mask = [7, 24]
	lobby_r.cmd_uses = 2
	rules = lobby_r.copy()
	rules.deploy = "free"
	rules.spacing = 800
	rules.depth = 6000
	challenge_army = null
	_start_mode(Mode.VS_AI)
	var y := 1500
	for t in [D.SWORD, D.SWORD, D.SHIELD, D.ARCHER, D.CAVALRY, D.PIKE, D.SWORD]:
		armies[0].place_xy(t, armies[0].world_x(5500), y)
		y += 1000
	_build_ai()
	_begin_battle(armies[0].copy(), armies[1].copy())
	for i in 90:
		_sim_step(true)
	await _snap("73_cmd_ready.png")
	sim.cast(0, CmdD.AEGIS)
	for i in 8:
		_sim_step(true)
	await _snap("74_cmd_cast.png")
	sim.cast(0, CmdD.HEAL)
	for i in 30:
		_sim_step(true)
	await _snap("75_cmd_cd.png")
	# 雙人：兩邊都有按鈕
	var r2 = rules.copy()
	rules = r2
	rules.place_rule = "blind"
	_start_mode(Mode.DUEL)
	var y2 := 1500
	for t in [D.SWORD, D.SHIELD, D.ARCHER, D.CAVALRY]:
		armies[0].place_xy(t, armies[0].world_x(5000), y2)
		armies[1].place_xy(t, armies[1].world_x(5000), y2)
		y2 += 1500
	_begin_battle(armies[0].copy(), armies[1].copy())
	for i in 70:
		_sim_step(true)
	await _snap("76_cmd_duel.png")
	rules = null
	_go_title()

## 第十三輪：章節、地形殘局、護送標記、技能時間面板、三層提示、撐住結果、試煉分頁、固定敵陣試煉。
func _shots_v13() -> void:
	_go_title()
	Save.data["puzzle_stars"] = {"p1": 3, "p2": 1, "x1": 2}
	overlay = "puzzles"
	puzzle_tab = 3
	await _snap("80_chapter4.png")
	puzzle_tab = 6
	puzzle_only_open = true
	await _snap("81_chapter7_filter.png")
	puzzle_only_open = false
	puzzle_tab = 0
	overlay = ""
	# 每張都寫成字面的截圖呼叫：版面檢查從原始碼抓預期的畫面清單
	puzzle_id = "d1"
	_start_mode(Mode.PUZZLE)
	await _snap("82_place_terrain.png")
	puzzle_id = "g1"
	_start_mode(Mode.PUZZLE)
	await _snap("83_place_protect.png")
	puzzle_id = "s1"
	_start_mode(Mode.PUZZLE)
	await _snap("84_place_plan.png")
	puzzle_id = "c10"   # V1.4 #4：第 12 章軍令連鎖的時間軸（三道軍令、敵方隕石紅旗）
	_start_mode(Mode.PUZZLE)
	overlay = "puzzle_plan"
	await _snap("84b_plan_chain.png")
	overlay = ""
	puzzle_id = "x1"
	_start_mode(Mode.PUZZLE)
	Save.data["puzzle_stars"]["x1"] = 0
	_puzzle_hint()
	await _snap("85_hint_locked.png")
	Save.data["puzzle_stars"]["x1"] = 2
	puzzle_reveal = true
	await _snap("86_hint_open.png")
	_apply_best()
	await _snap("86b_hint_applied.png")
	puzzle_id = "d1"
	_start_mode(Mode.PUZZLE)
	_apply_best()
	_begin_battle(armies[0].copy(), armies[1].copy())
	for i in 140:
		_sim_step(true)
	await _snap("87_battle_terrain.png")
	# V1.4 #10 沙盤機關：崩塌礦坑擺陣頁（倒數牌）＋戰鬥到崩塌之後；#9 貼紙、#12 巨獸
	rules = RuleSet.standard()
	rules.map_id = MapDefs.QUARRY
	rules.deploy = "free"   # 地圖（含機關）只在自由排兵出現
	toast_t = 0.0
	challenge_army = null
	_start_mode(Mode.VS_AI)
	var qa: Dictionary = AI.build(0, 100, _shot_rng(41), -1, -1, rules)
	armies[0].units = qa["army"].units.duplicate(true)
	for k in mini(3, armies[0].units.size()):
		armies[0].units[k]["st"] = [1, 3, 5][k]
	_build_ai()
	toast_t = 0.0
	await _snap("87b_quarry_place.png")
	_begin_battle(armies[0].copy(), armies[1].copy())
	while view.tick < 430 and not sim.finished:
		_sim_step(true)
	toast_t = 0.0
	await _snap("87c_quarry_battle.png")
	rules = RuleSet.standard()
	var be = AI.build(1, 108, _shot_rng(42))["army"]
	add_boss(be)
	challenge_army = be
	_start_mode(Mode.VS_AI)
	challenge_army = be
	armies[0].units = AI.build(0, 100, _shot_rng(43))["army"].units.duplicate(true)
	_build_ai()
	_begin_battle(armies[0].copy(), armies[1].copy())
	for i in 260:
		_sim_step(true)
	toast_t = 0.0
	await _snap("87d_boss_battle.png")
	challenge_army = null
	rules = RuleSet.standard()
	puzzle_id = "g4"
	_start_mode(Mode.PUZZLE)
	_apply_best()
	_begin_battle(armies[0].copy(), armies[1].copy())
	while not sim.finished:
		_sim_step(true)
	_finish_battle()
	toast_t = 0.0   # 「已擺上三星解」是擺陣頁的提示，截圖瞬間打完不會留到結果頁
	await _snap("88_result_survive.png")
	_go_title()
	toast = ""      # 前面「已擺上三星解」的提示泡泡不要帶進後面的截圖
	toast_t = 0.0
	overlay = "trials"
	set("trial_page", 1)
	await _snap("89_trials_p2.png")
	set("trial_page", 2)
	await _snap("90_trials_p3.png")
	set("trial_page", 0)
	overlay = ""
	call("_start_trial", 14)
	_build_ai()
	await _snap("91_trial_fixed.png")
	# 試煉打贏的結果頁：按鈕最多 6 顆（下一關、再試、試煉、覆盤、重播、主選單），要整排在框內
	for u in call("trial_x", 14).get("best", []):
		armies[0].place_xy(int(u[0]), int(u[1]), int(u[2]))
	_begin_battle(armies[0].copy(), armies[1].copy())
	while not sim.finished:
		_sim_step(true)
	_finish_battle()
	await _snap("92_trial_win_result.png")
	# V1.1：每日挑戰的擺放畫面（標題列＝每日挑戰・突變名，提示說明突變數值）
	_go_title()
	call("_start_daily")
	for k5 in 6:
		await get_tree().process_frame
	toast_t = 0.0   # 突變說明是開場提示（幾秒就消失），截圖量版面時先清掉，跟試煉截圖一樣
	await _snap("93_daily_place.png")
	# V1.1 B1：輸掉的殘局結果頁，標題下那一行換成「多半傷害來自…→ 可以試試…」
	_go_title()
	puzzle_id = str(PZ.all_puzzles()[0]["id"])
	_start_mode(Mode.PUZZLE)
	var pz5 := PZ.get_puzzle(puzzle_id)
	armies[0].place(int(pz5["allowed"][0]), 0, 4)
	_begin_battle(armies[0].copy(), armies[1].copy())
	while not sim.finished:
		_sim_step(true)
	_finish_battle()
	await _snap("94_loss_result.png")
	# V1.1 D1：遠征路線（第 3 戰打贏後選事件，下一戰是菁英）
	_go_title()
	_start_mode(Mode.GAUNTLET)
	gauntlet_stage = 3
	_open("reward")
	await _snap("95_route_reward.png")
	overlay = ""
	# V1.1 D5：第 11 章清單與一關「不能倒」的擺放畫面
	_go_title()
	overlay = "puzzles"
	puzzle_tab = 10
	await _snap("96_chapter11.png")
	overlay = ""
	puzzle_id = "w1"
	_start_mode(Mode.PUZZLE)
	await _snap("97_place_flawless.png")
	_go_title()
	Save.data["puzzle_stars"] = {}


func _shot_rng(sd: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = sd
	return r



## V1.6.0 新畫面（docs/history/2026-11-10-v1.6.0-plan.md）
func _shots_v16() -> void:
	_go_title()
	overlay = ""
	var keep: Dictionary = Save.data.duplicate(true)
	Save.data["tutorial"] = 1
	Save.data["stats"] = {"wins": 0, "games": 0}
	await _snap("v16_01_title_next.png")
	overlay = "demo_end"
	await _snap("v16_02_demo_end.png")
	overlay = ""
	Save.data = keep
	# #6 射程覆蓋＋標記（殘局：看得到敵兵，畫最近敵兵方向）
	puzzle_id = "p1"
	_start_mode(Mode.PUZZLE)
	for s in [[D.SHIELD, 5, 3], [D.ARCHER, 1, 3], [D.ARCHER, 1, 5], [D.SWORD, 4, 4]]:
		armies[0].place(s[0], s[1], s[2])
	tv_range = true
	tv_marks = [Vector2i(1500, 3500), Vector2i(5500, 3500)]
	await _snap("v16_03_place_range.png")
	_begin_battle(armies[0].copy(), armies[1].copy(), "official")
	for i in 60:
		_sim_step(true)
	await _snap("v16_04_battle_marks.png")
	# #9 教練：殘局輸了（只擺一隻弓箭手）→ 結果頁 → 教練面板
	_start_mode(Mode.PUZZLE)
	armies[0].place(D.ARCHER, 0, 0)
	_begin_battle(armies[0].copy(), armies[1].copy(), "official")
	_on_skip()
	_finish_battle()
	_coach_open()
	co_layer = 2
	await _snap("v16_09_coach.png")
	overlay = ""
	_go_title()
	overlay = "rift"
	await _snap("v16_10_rift.png")
	overlay = ""
	_rift_start()
	await _snap("v16_11_rift_place.png")
	_go_title()
	overlay = "hub_challenge"
	await _snap("v16_12_hub_challenge.png")
	overlay = ""
	# #16 出題台
	ed_cells = {Vector2i(2, 3): D.CAVALRY, Vector2i(2, 5): D.CAVALRY, Vector2i(4, 4): D.SWORD, Vector2i(12, 4): D.SWORD, Vector2i(13, 2): D.ARCHER}
	ed_type = D.ARCHER
	ed_goal = 1
	overlay = "editor"
	await _snap("v16_13_editor.png")
	overlay = ""
	ed_cells = {}
	# #17 一陣三考：選題、打完的結果
	overlay = "trio"
	await _snap("v16_14_trio.png")
	_trio_start(0)
	await _snap("v16_15_trio_place.png")
	trio_res = [{"ok": true, "rem": 52, "spent": 60}, {"ok": false, "rem": 0, "spent": 60}, {"ok": true, "rem": 31, "spent": 60}]   # V1.6.1：三場各自的結果
	trio_st = 0
	overlay = "trio_result"
	await _snap("v16_16_trio_result.png")
	overlay = ""
	_go_title()
	# #20 迷霧推演
	_fog_start()
	await _snap("v16_17_fog_place.png")
	_go_title()
	overlay = "hub_play"
	await _snap("v16_18_hub_play.png")
	overlay = ""
	# #21 雙人接力遠征：交接畫面、擺陣標籤
	ga_coop = true
	_start_gauntlet_with(0)
	gauntlet_stage = 2
	coop_seen = 0
	_coop_tick()
	await _snap("v16_19_coop_hand.png")
	overlay = ""
	await _snap("v16_20_coop_place.png")
	ga_coop = false
	call("_gauntlet_clear")
	_go_title()
	tv_range = false
	tv_marks = []
	_go_title()
	# #7 按住確認（進度條一半）、文字放大鏡（指著主畫面木牌副標）
	Save.settings["hold_confirm"] = true
	_ask_confirm(L.t("set_reset_page_q"), func(): pass, "")
	hold_t = 0.3
	await _snap("v16_05_hold_confirm.png")
	overlay = ""
	hold_t = 0.0
	Save.settings["hold_confirm"] = false
	Save.settings["magnify"] = true
	mouse = Vector2(200, 268)
	await _snap("v16_06_magnifier.png")
	Save.settings["magnify"] = false
	# #8 極速賽：選單（V1.6.1 今日題組）、擺陣頂部計時、結束面板（含分享）
	_rush_start()
	await _snap("v161_01_rush_menu.png")
	overlay = ""
	_rush_go(true)
	await _snap("v16_07_rush_place.png")
	rush["solved"] = 7
	rush["tried"] = 9
	_rush_end()
	await _snap("v16_08_rush_end.png")
	overlay = ""
	await _shots_v161()

## V1.6.1 新畫面（docs/history/2026-11-10-v1.6.1-plan.md）
func _shots_v161() -> void:
	_go_title()
	var keep: Dictionary = Save.data.duplicate(true)
	# N2 新玩法導覽
	overlay = "tour"
	await _snap("v161_02_tour.png")
	# A3 三考：三張卡片＋星數（全勝）
	_trio_start(0)
	trio_extra = Trio.sets()[0]["sol"]
	trio_res = [{"ok": true, "rem": 52, "spent": 60}, {"ok": true, "rem": 48, "spent": 60}, {"ok": true, "rem": 41, "spent": 60}]
	trio_st = 2
	overlay = "trio_result"
	await _snap("v161_03_trio_cards.png")
	overlay = ""
	_go_title()
	# A12 異變練習場
	rift_lab = [0, 2]
	overlay = "rift_lab"
	await _snap("v161_04_rift_lab.png")
	rift_lab = []
	# A2 出題台：斬首指定目標
	ed_cells = {Vector2i(2, 3): D.CAVALRY, Vector2i(2, 5): D.CAVALRY, Vector2i(4, 4): D.SWORD, Vector2i(12, 4): D.SWORD, Vector2i(13, 2): D.ARCHER}
	ed_goal = 1
	ed_target = Vector2i(12, 4)
	overlay = "editor"
	await _snap("v161_05_editor_target.png")
	ed_cells = {}
	ed_target = Vector2i(-1, -1)
	overlay = ""
	# N3 實驗簿：改名中＋比較
	puzzle_id = "p1"
	_start_mode(Mode.PUZZLE)
	Save.data["notebook"] = {"p1": [{"n": "速攻", "u": [[0, 4, 4], [2, 1, 3]], "r": [2, 40, 30]}, {"n": "堅守", "u": [[1, 5, 3], [2, 1, 5]], "r": [3, 55, 25]}]}
	overlay = "notebook"
	nb_edit = 0
	nb_buf = "A 案"
	await _snap("v161_06_notebook_rename.png")
	_nb_edit_end()
	nb_cmp_a = 0
	nb_cmp_b = 1
	overlay = "nb_cmp"
	await _snap("v161_07_notebook_compare.png")
	nb_cmp_a = -1
	overlay = ""
	# A9 開場鎖定弧線
	for sp in [[D.SHIELD, 5, 3], [D.ARCHER, 1, 3], [D.ARCHER, 1, 5], [D.SWORD, 4, 4]]:
		armies[0].place(sp[0], sp[1], sp[2])
	tv_range = true
	await _snap("v161_08_lock_arcs.png")
	tv_range = false
	# D4 接力遠征總結
	coop_log = [1, 1, 1, 0, 2, 2, 1, 2, 3, 1, 0, 3]
	ga_coop = true
	overlay = "coop_sum"
	await _snap("v161_09_coop_sum.png")
	ga_coop = false   # V1.0.0 M4：單人遠征總結
	coop_log = [1, 0, 1, 0, 2, 0, 1, 2, 3, 0, 1, 5, 4, 0, 0, 3]
	await _snap("v100_01_ga_sum.png")
	overlay = "fb_cat"   # 1.1.0 N1 回報分類
	await _snap("v110_01_fb_cat.png")
	nb_buf = L.t("nb_w_0") + L.t("nb_w_5") + "2"   # 1.1.0 B13 詞彙格改名
	overlay = "nb_words"
	await _snap("v110_02_nb_words.png")
	overlay = "daily_past"   # 1.1.0 N4
	await _snap("v110_03_daily_past.png")
	nb_buf = ""
	overlay = ""
	coop_log = []
	Save.data = keep
	_go_title()
