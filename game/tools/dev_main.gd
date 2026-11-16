extends "res://scripts/ui/game_screens.gd"
const LayoutRules = preload("res://scripts/ui/layout_rules.gd")
## V1.5.2：自己畫框、不用 _panel 的覆蓋層（漏登記守衛的已知例外）：AI 思考中只畫轉圈
const PANELLESS_OVERLAYS := ["ai_busy"]
## V1.5.2 漏登記守衛：每個覆蓋層必須登記到的角色（有標題緞帶的要有 1 條緞帶＋1 個面板；彈窗至少 1 個面板）。
## 由各覆蓋層的繪圖函式靜態整理；之後新增覆蓋層要加進來，否則守衛只會要求面板。
const DECK_CAP := 0.7
const DECK_MIN_PX := 9.0
const OVERLAY_RIBBON := ["trials", "puzzle_hint", "puzzle_plan", "profile", "nemeses", "paint", "hub_play", "hub_gauntlet", "hub_challenge", "hub_collect", "restore", "clear_data", "ghosts", "ga_info", "weekly", "relay", "playroom", "wager", "draft", "reward", "ban", "codes", "gauntlet_resume", "wave_codes", "tutorial", "puzzles", "lobby", "settings", "keys", "credits", "gauntlet_pick", "codex", "review", "demo_end", "share", "rush_end", "coach", "rift", "notebook", "daily_top", "editor", "trio", "trio_result", "coop_hand", "tour", "nb_cmp", "rift_lab", "rush_menu", "coop_sum", "fb_cat", "nb_words", "daily_past", "songbook", "campaign"]
const OVERLAY_PANEL := ["first_run", "postcard", "pause_menu", "confirm", "fs_confirm", "leave", "slots"]
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
static func text_bg(img: Image, r: Rect2, c: Color, oc: Color, sx: float, sy: float, q := 0.2, paper_only := false):
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
			if dc > 0.30 and do > 0.30 and not (paper_only and p.s >= 0.55):   # 紙紋暗斑：只取紙色（低彩度），不取印章紅圈、彩色框線
				bg.append(p)
			x += step
		y += step
	if all == 0 or float(bg.size()) / all < 0.15:
		if paper_only:
			return null   # 紙面暗斑模式不退回字框外圍（外圍可能出了紙面、也不限低彩度——Codex B06 r3 #2）：呼叫端記「紙面暗斑未量」
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
	return bg[int(bg.size() * q)]

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
		# 1.6.0 B02（P2.2）：淺紙面按鈕上的亮字（白、淺灰）靠細描邊「算過」對比，實際糊成一片（異變實驗室、新玩法導覽）。
		# 用畫的時候登記的紙面範圍判（取樣器刻意取最壞的背景點，會把字旁的亮邊當背景，誤報太多）
		if LayoutRules.paper_white(rel_lum(c), dis, bool(t.get("field", false)), (t.get("gr", t["r"]) as Rect2).get_center(), probe_faces, int(t.get("fz", probe_faces.size()))):
			bad.append({"type": "淺紙白字", "s": t["s"], "fg": c.to_html(false), "at": [int(t["r"].position.x), int(t["r"].position.y)]})
			continue
		if ratio >= need:
			# 1.6.0 B06（Codex B06 r1 #5、r2 #2）：桌燈紙比較暗、紙紋有斑——紙面上的字另驗「字底最接近字色那側的 2% 分位」（暗斑）。
			# 只驗沒描邊的紙面字（描邊字照 R8）；停用元件另報
			# 只取「字框 ∩ 紙面內縮 6px（材質毛邊與框線不算紙紋）」
			var pf: Rect2 = LayoutRules.paper_face((t.get("gr", t["r"]) as Rect2).get_center(), probe_faces, int(t.get("fz", probe_faces.size())))
			var tr2: Rect2 = (t["r"] as Rect2).intersection(pf.grow(-6.0)) if pf.size.x > 0.0 else Rect2()
			if not outlined and tr2.size.x >= 6.0 and tr2.size.y >= 6.0:
				var bg2 = text_bg(img, tr2, c, oc, sx, sy, 0.02, true)
				if bg2 == null:
					warn.append({"type": "紙面暗斑未量", "s": t["s"], "at": [int(t["r"].position.x), int(t["r"].position.y)]})   # 取樣不足：照實列出，dark_spot_diff 比開／關新增的
				else:
					var r2 := contrast(over.call(c, bg2), bg2)
					if r2 < need:
						warn.append({"type": "紙面暗斑對比", "s": t["s"], "ratio": snappedf(r2, 0.01), "need": need, "fg": c.to_html(false), "bg": (bg2 as Color).to_html(false), "at": [int(t["r"].position.x), int(t["r"].position.y)]})
			continue
		var item := {"type": "對比不足", "s": t["s"], "ratio": snappedf(ratio, 0.01), "need": need, "fg": c.to_html(false), "bg": (bgc as Color).to_html(false), "at": [int(t["r"].position.x), int(t["r"].position.y)]}   # 1.4.0：帶字色、取樣背景與位置（查錯用）
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
		"boxes": probe_boxes.map(func(b): return b["r"]), "overlay": overlay, "need": need, "icons": probe_icons,
		"panelless_ok": overlay in PANELLESS_OVERLAYS, "screen": probe_screen, "clicks": click_count()}


## 1.2.0 §14.7 美感自動檢查（第一批，先當報表、不擋）：
##  ・black_pct：近純黑像素（三通道都 ≤ 8）佔全畫面的百分比（憲法 3：禁純黑；桌面世界做完後改成違規）
##  ・units／low_units：戰鬥中每隻單位，框內（腳底往上 46px、寬 36px）最暗／最亮 10% 像素和框外一圈 6px 平均的 WCAG 對比都 < 3:1 的隻數（第 4 大類 B2 改量法）
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
	# 1.2.0 第 6 大類 G：疊層、暫停、慢動作壓暗時不量（那時盤面被壓暗是刻意的，原本把暫停選單、元件展示頁都算進低對比）
	if state == St.BATTLE and view != null and overlay == "" and not paused and clutch_t <= 0.0 and float(get("slow_left")) <= 0.0:
		# 1.2.0 第 4 大類 B2：改量「輪廓」：框內最暗 10% 與最亮 10% 的像素（棋子的描邊與高光）各自和外圈平均算 WCAG 對比，取大者；
		# < 3:1 才算看不清（Antigravity cat01：邊緣對比 ≥3:1）。原本比框內平均 vs 外圈平均，棋子色塊和草地平均明度接近就全判低。
		var rl := func(c: Color) -> float:
			var lc := c.srgb_to_linear()
			return 0.2126 * lc.r + 0.7152 * lc.g + 0.0722 * lc.b
		for u in view.units:
			if not u.alive:
				continue
			var sp: Vector2 = _cam * _upos(u)
			var inner := Rect2i(int(sp.x - 18.0 * UNIT_SCALE / 0.92), int(sp.y - 46.0 * UNIT_SCALE / 0.92), int(36.0 * UNIT_SCALE / 0.92), int(46.0 * UNIT_SCALE / 0.92))   # 1.3.0：量框跟著角色尺寸（原本寫死 0.92 倍時的 36×46）
			var outer := inner.grow(6)
			var vals: Array = []
			for yy in range(maxi(0, inner.position.y), mini(h, inner.end.y), 2):
				for xx in range(maxi(0, inner.position.x), mini(w, inner.end.x), 2):
					vals.append(rl.call(img.get_pixel(xx, yy)))
			if vals.is_empty():
				continue
			vals.sort()
			var nv := vals.size()
			var dark := 0.0
			var lite := 0.0
			var kq := maxi(1, nv / 10)
			for i in kq:
				dark += float(vals[i])
				lite += float(vals[nv - 1 - i])
			dark /= kq
			lite /= kq
			var ring := 0.0
			var rk := 0
			for r in [Rect2i(outer.position.x, outer.position.y, outer.size.x, 6), Rect2i(outer.position.x, outer.end.y - 6, outer.size.x, 6),
					Rect2i(outer.position.x, inner.position.y, 6, inner.size.y), Rect2i(inner.end.x, inner.position.y, 6, inner.size.y)]:
				for yy in range(maxi(0, r.position.y), mini(h, r.end.y), 2):
					for xx in range(maxi(0, r.position.x), mini(w, r.end.x), 2):
						ring += rl.call(img.get_pixel(xx, yy))
						rk += 1
			ring /= maxi(1, rk)
			var cr := func(a: float, b: float) -> float: return (maxf(a, b) + 0.05) / (minf(a, b) + 0.05)
			out["units"] += 1
			if maxf(cr.call(dark, ring), cr.call(lite, ring)) < 3.0:
				out["low_units"] += 1
				if not out.has("low"):
					out["low"] = []
				(out["low"] as Array).append([u.type, u.team, int(sp.x), int(sp.y)])   # 1.6.0 B10：哪幾隻（查變差的原因用）
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
	var art := _art_checks(img)
	if float(art["black_pct"]) > 1.0:
		bad.append({"type": "純黑像素超過 1%", "pct": art["black_pct"]})   # 1.3.0 §4：美感報表的第一條變門檻（憲法 3：禁純黑）
	var line := JSON.stringify({"shot": name, "lang": L.lang, "scale": int(Save.s("text_scale")), "texts": ui_n, "free_texts": free_n,
		"median_size": sizes[sizes.size() / 2] if not sizes.is_empty() else 0, "min_size": sizes[0] if not sizes.is_empty() else 0,
		"violations": bad, "warnings": cres["warn"], "geo_warn": geo_warn, "geo_exempt": geo["exempt"], "art": art, "shrink": probe_shrink.duplicate(),
		"r11_cells": probe_texts.filter(func(t): return t.get("face") is Rect2).size(),
		"cap": _cap_info()})   # 1.6.0 R0：固定拍攝契約——每張截圖的拍攝參數（重拍、前後對照要同鏡位同幀）   # 1.3.0：R11 實際量了幾段格子字（0＝沒接上，收尾核對）
	var f := FileAccess.open(shot_dir.path_join("layout.jsonl"), FileAccess.READ_WRITE if FileAccess.file_exists(shot_dir.path_join("layout.jsonl")) else FileAccess.WRITE)
	f.seek_end()
	f.store_line(line)
	f.close()
	if "--geom-dump" in OS.get_cmdline_user_args():
		# 1.3.0 方案盤點（第 10 點「格子裡的字要置中」）：每張截圖的字形框、所屬按鈕框、方塊框，給 tools/gen/center_audit.py 量偏移
		var tx: Array = []
		for t in probe_texts:
			var g: Rect2 = t["gr"]
			var o = t.get("own")
			var fc0 = t.get("face")
			var ik0 = t.get("ink")
			tx.append({"s": t["s"], "size": t["size"], "field": t.get("field", false), "g": [g.position.x, g.position.y, g.size.x, g.size.y],
				"face": [fc0.position.x, fc0.position.y, fc0.size.x, fc0.size.y] if fc0 is Rect2 else null, "ink": [ik0.position.x, ik0.position.y, ik0.size.x, ik0.size.y] if ik0 is Rect2 else null, "cell": str(t.get("cell", "")),   # 1.4.0：和版面規則同一份資料（Codex v140 cat01 #6）
				"btn": bool(t.get("btn", false)), "own": [o.position.x, o.position.y, o.size.x, o.size.y] if o is Rect2 and o.size.x > 0.0 and bool(t.get("btn", false)) else null})
		var bx: Array = probe_boxes.map(func(b): return [b["r"].position.x, b["r"].position.y, b["r"].size.x, b["r"].size.y])
		var gf := FileAccess.open(shot_dir.path_join("geom.jsonl"), FileAccess.READ_WRITE if FileAccess.file_exists(shot_dir.path_join("geom.jsonl")) else FileAccess.WRITE)
		gf.seek_end()
		var ic: Array = probe_icons.map(func(i): return {"n": i["n"], "r": [i["r"].position.x, i["r"].position.y, i["r"].size.x, i["r"].size.y]})
		var bt: Array = probe_btns.map(func(b): return [b.position.x, b.position.y, b.size.x, b.size.y] if b is Rect2 else [0, 0, 0, 0])
		gf.store_line(JSON.stringify({"shot": name, "texts": tx, "boxes": bx, "icons": ic, "btns": bt}))   # 1.4.0：加圖示框與按鈕框（量內距）
		gf.close()


var shot_only: Array = []
var shot_fixed := false   # 1.2.0：--shot-fixed＝視覺回歸模式（固定幀時間、固定亂數、橫幅拍穩定狀態）；一般版面檢查照真實時間跑（Codex cat01 #6）   # 1.2.0 §14.4：--shot-only=a.png,b.png 只存這些（流程照跑）
## 1.6.0 R0：這張截圖的拍攝參數（畫面狀態、地圖、模擬 tick、動畫時間、鏡頭、跟拍、場上數量）
func _cap_info() -> Dictionary:
	var alive := 0
	if view != null:
		for u in view.units:
			if u.alive and not u.hidden:
				alive += 1
	var texts := 0
	for f0 in fx:
		if f0["kind"] == "text":
			texts += 1
	return {"state": int(state), "overlay": overlay, "map": fld_map, "sim_tick": sim.tick if sim != null else -1,
		"view_tick": view.tick if view != null else -1, "anim_time": snappedf(time, 0.01), "zoom": snappedf(zoom, 0.001),
		"cam": [snappedf(zoom_center.x, 0.1), snappedf(zoom_center.y, 0.1)], "follow": follow_id, "alive": alive,
		"fx": fx.size(), "fx_text": texts, "paused": paused, "fixed_clock": bool(shot_fixed), "size": [1280, 800]}

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
	if shot_fixed and state == St.BATTLE:
		time = 600.0 + float(name.hash() & 1023) * 0.01   # 1.5.0 §12：固定模式下戰鬥截圖的動畫時間只由畫面名決定（不受前面拍了幾張影響；美感基線才比得了）
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
	if "--video-offscreen" in OS.get_cmdline_user_args():   # 1.2.0：驗收錄影不開可見視窗（和截圖一樣移到畫面外、不搶焦點）
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
		DisplayServer.window_set_position(Vector2i(-4000, -4000))
	for nk in ["lobby", "place", "result"]:   # 1.2.0：老闆便條不入鏡（影片用 shot_ 存檔，等於新玩家）
		preload("res://scripts/game/guide.gd").see(Save.data, "note_" + nk)
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
	if shot_dir != "":
		ach_queue.clear()   # 只在截圖模式（Codex cat02：不影響其他開發模式）

## 1.2.0 元件庫展示（只在截圖流程用）
## 1.2.0 第 5 大類：五種表情對照（待機、專注、生氣、受驚、得意）× 劍士、弓箭手、史萊姆，大尺寸（開發用截圖 v120_03_moods）
func _draw_mood_demo() -> void:
	var P := modal_rect(1000, 560)
	_panel(P)
	probe_skip("R6", "表情對照（開發用）：角色直接畫、不經版面探針，不是空白")
	var y := _h1(Vector2(640, P.position.y + 12), "Moods") + GAP_L
	var moods := [0, Art.M_GRIM, Art.M_BROWS, Art.M_SURPRISE, Art.M_HAPPY]
	var types := [0, 2, 13]
	for ri in types.size():
		for ci in moods.size():
			var fp := Vector2(P.position.x + 120 + ci * 190, y + 130 + ri * 140)
			Art.unit(self, fp, int(types[ri]), 0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 2.2, cbm(), int(moods[ci]))

func _draw_kit_demo() -> void:
	var P := modal_rect(900, 520)
	_panel(P)
	probe_skip("R6", "元件庫展示（開發用）：下半是材質樣本與黃銅開關，直接畫、不經版面探針，不是空白")
	var y := _h1(Vector2(640, P.position.y + 12), "Kit") + GAP_L
	var x0 := P.position.x + 40
	mouse = Vector2(x0 + 230 + 80, y + 22)   # 第二顆＝懸停
	_btn(Rect2(x0, y, 200, 44), L.t("back"), func(): pass)
	_btn(Rect2(x0 + 230, y, 200, 44), L.t("back"), func(): pass)
	_btn(Rect2(x0 + 460, y, 200, 44), L.t("back"), func(): pass)   # 焦點（_focus=2，手把狀態才畫）
	_btn(Rect2(x0 + 690, y, 160, 44), L.t("back"), func(): pass, false)
	y += 64
	_btn(Rect2(x0, y, 300, 50), L.t("start"), func(): pass, true, true)
	_btn(Rect2(x0 + 330, y, 300, 50), L.t("start"), func(): pass, false, true)
	y += 70
	for i in 3:
		btn_cloth = ["tab_indigo", "tab_linen", "tab_madder"][i]
		_btn(Rect2(x0 + i * 220, y, 200, 48), L.t("set_tab_%d" % i), func(): pass)
		btn_cloth = ""
	y += 70
	call("_brass_toggle", Vector2(x0 + 20, y + 20), true)
	call("_brass_toggle", Vector2(x0 + 80, y + 20), false)
	call("_brass_toggle", Vector2(x0 + 140, y + 20), true, false)
	mouse = Vector2(-100, -100)

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
	home_more = true   # 1.6.0 B05：「更多」抽屜打開（遊戲間、收藏）
	await _snap("v160_01m_title_more.png")
	home_more = false
	overlay = "hub_play"   # V1.5 主畫面第二層卡片
	await _snap("01b_hub_play.png")
	overlay = "hub_challenge"
	await _snap("01c_hub_challenge.png")
	overlay = "hub_collect"
	await _snap("01d_hub_collect.png")
	overlay = "hub_gauntlet"   # V1.0.0 H1
	await _snap("01e_hub_gauntlet.png")
	overlay = ""
	# 1.2.0 §11.11 最近玩的（三顆）＋ §11.8 棋譜本（空、兩筆）
	Save.data["recent"] = [{"h": "hub_play", "k": "menu_vs_ai"}, {"h": "hub_challenge", "k": "menu_puzzle"}, {"h": "playroom", "k": "rift_open"}]
	await _snap("v120_04_recent.png")
	Save.data["recent"] = []
	Save.data["songbook"] = []
	overlay = "songbook"
	await _snap("v120_05_songbook@empty.png")
	var ra := RandomNumberGenerator.new()
	ra.seed = 4242
	var sb_code := BattleCode.encode(AI.build(0, 100, ra)["army"], AI.build(1, 100, ra)["army"], null, [])
	Save.data["songbook"] = [{"c": sb_code, "n": "2026-11-12　" + L.t("sb_win"), "note": L.t("sb_note", [L.t("tl_lead") + " 23s"]), "t": 0},
		{"c": sb_code + "", "n": "2026-11-11　" + L.t("sb_lose"), "note": L.t("sb_note_none"), "t": 0}]
	await _snap("v120_05_songbook.png")
	Save.data["songbook"] = []
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
	foe_tag_open = true   # 1.5.0 §1.4：敵情翻牌展開
	await _snap("v150_02b_place_foe.png")
	foe_tag_open = false
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
	# 1.5.0 §7：跟拍一隻正在打的藍兵——腳下暈光、目標朱紅外緣、淡墨虛線（誰在打誰）；其他血條淡
	var fsel := -1
	for vu in view.units:
		if vu.alive and vu.team == 0 and vu.target >= 0 and vu.target < view.units.size() and view.units[vu.target].alive and view.units[vu.target].team == 1:
			fsel = vu.id
			break
	var keep_follow := follow_id
	follow_id = fsel
	await _snap("v150_03f_battle_focus.png")
	follow_id = keep_follow
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
	# 1.6.0 B14（P5.4）收盤：結束後倖存的兵點一下頭（點到最低那一刻）
	result_delay = 0.85
	await _snap("v160_14b_settle.png")
	result_delay = 0.0
	zoom = 1.0
	if mode == Mode.VS_AI:   # 1.4.0 §10.1 謝幕：對手木偶的反應＋老闆依勝負的手勢（播完 0.7 秒那一刻）
		result_delay = 0.7
		owner_end_force = true
		await _snap("v140_10_curtain_call.png")
		owner_end_force = false
	_finish_battle()
	await _snap("05_result.png")
	note_key = "result"   # 1.2.0 §12 老闆便條（截圖平常不跳，這張專拍）
	overlay = "boss_note"
	await _snap("v120_02_note.png")
	overlay = ""
	note_pin_force = true   # 1.6.0 B06（P1.5）：便條釘在結果紙外左下桌緣（收合）
	await _snap("v160_05g_note_pin.png")
	await _note_pin_walk()
	note_pin_force = false
	overlay = "mood_demo"   # 1.2.0 第 5 大類：表情對照
	await _snap("v120_03_moods.png")
	overlay = ""
	# 1.2.0 §9.4 宣紙戰報（截圖平常跳過演出；這一張強制拍蓋章後的瞬間）
	ink_force = true
	result_t = time - 0.8
	ink_stamped = true
	await _snap("v120_01_ink.png")
	ink_force = false
	result_t = time - 5.0
	result_tab = 1
	await _snap("v150_05e_result_flow.png")   # 1.5.0 §1.5：走勢與事件（原本首屏的曲線、事實）
	result_tab = 2
	await _snap("05b_result_details.png")
	result_tab = 0
	overlay = "res_more"   # 1.5.0 §1.5：底列「更多」
	await _snap("v150_05f_result_more.png")
	overlay = ""
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
	duel_rule = "blind"   # 1.5.0 §1.4：盲擺雙人照舊竹簾（紅方擺時藍方被遮）
	_start_mode(Mode.DUEL)
	for s7 in [[D.SHIELD, 4, 4], [D.SWORD, 4, 3], [D.ARCHER, 2, 4]]:
		armies[0].place(s7[0], s7[1], s7[2])
	blind_phase = 1
	selected = D.SWORD
	mouse = ORIGIN + Vector2(12.5, 4.5) * CS
	await _snap("v150_07c_duel_blind.png")
	_go_title()
	overlay = "settings"
	await _snap("08_settings.png")
	set_adv_open = true   # 1.5.0 §1.3：進階微調抽屜
	await _snap("v150_08z_settings_adv.png")
	set_adv_open = false
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
	rv_tab = 0
	await _snap("v160_16a_review_edit.png")   # 1.6.0 B07（P2.5）：覆盤「改動」頁（重算前）
	_rv_recalc()
	await _snap("16_review.png")   # 重算好了自動翻到「讀結果」頁
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
	# 1.3.0 §2：暫停中選一隻＝銅放大鏡小窗；交戰熱點聚光（截圖時強度固定 1）
	for u in view.units:
		if u.alive and not u.boss:
			follow_id = u.id
			break
	_spot_update(1.0)
	if spot_n < 2 and follow_id >= 0:
		spot_p = _upos(view.unit_by_id(follow_id))
	spot_a = 1.0
	await _snap("15c_replay_mag.png")
	follow_id = -1
	spot_a = 0.0
	_breport_open()   # 1.1.0 B10：手把重播戰報面板
	await _snap("v110_04_breport.png")
	_breport_close()
	# 1.2.0 §1.3 元件庫 2.0：七種狀態展示（正常、懸停、按下由實機看；焦點、停用、簡化／色盲由版面組合涵蓋）
	overlay = "kit_demo"
	_focus = 2
	await _snap("v120_00_components.png")
	overlay = ""
	paused = false
	await _shots_v4()
	await _shots_cmd()
	await _shots_v13()
	await _shots_v16()
	# 1.6.0 B04／B05：會真的開戰的走查放在所有截圖之後（開戰會動到全域亂數與時間，放在中間會讓後面固定時鐘的戰鬥截圖變樣；b04c 抓到 74_cmd_cast）
	await _shot_fatigue()   # 1.6.0 B14：另開一場長戰鬥，放在所有截圖之後（不動到前面截圖的戰鬥狀態）
	await _lobby_pad_walk()
	await _first_run_walk()
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
	Save.data["lobby_stamps"] = 2   # 1.4.0 §1.1：截圖看得到手帳上的印跡
	_go_title()
	_open_lobby("ai")
	mouse = Vector2(-100, -100)
	lobby_step = 2   # 1.5.0 §1.2：22_lobby＝第三步「開戰」（有上次設定時打開就在這裡）
	await _snap("22_lobby.png")
	lobby_step = 0
	await _snap("v150_22a_lobby_step1.png")   # 第一步：對手
	lobby_step = 1
	await _snap("v150_22b_lobby_step2.png")   # 第二步：地圖
	lobby_step = 2
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
	lobby_tab = 7   # 1.2.0 第 11 大類：新技能（實驗）分頁
	lobby_r.ext_skills = 1 | 8
	lobby_item = "xs_3"
	await _snap("v120_08_lobby_ext.png")
	lobby_r.ext_skills = 0
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
	set("pf_tab", 0)
	await _snap("59_profile.png")
	set("pf_tab", 1)   # 1.5.0 §1.6 戰績三頁籤
	await _snap("v150_59c_profile_units.png")
	set("pf_tab", 2)
	await _snap("v150_59d_profile_badges.png")
	set("pf_tab", 0)
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
	lobby_step = 1   # 1.5.0：地圖在第二步
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
	fp_more = true   # 1.5.0 §1.4：「工具 ▾」展開
	await _snap("v150_27b_free_tools.png")
	fp_more = false
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
	return {"peak_tex_mib": snappedf(peak, 0.1), "worst_bake_frame_ms": snappedf(worst_frame, 0.1), "max_pages": sprites.MAX_PAGES, "ta_max": sprites.TA_MAX, "rounds": rounds,
		"stages": sprites.stage_report()}   # 1.6.0 B01：讀回／上傳／畫格各段最大值（找出最長幀是哪一段）

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
		elif a.begins_with("--turn-strip="):
			_run_turn_strip.call_deferred(a.substr(13))
		elif a.begins_with("--bake-pack="):
			_run_bake_pack.call_deferred(a.substr(12))
		elif a.begins_with("--pack-bench="):
			_run_pack_bench.call_deferred(a.substr(13))
		elif a.begins_with("--pack-selftest="):
			_run_pack_selftest.call_deferred(a.substr(16))


## 1.6.0 B09（Codex r2 #3）實跑：①重建中途換色盲（競態）：最後是新配色、包讀到的頁＝包裡兵種條拼的頁、沒有誤停用；
## ②壞包：把一條換成別種（同尺寸）→ 驗檔擋下、整包停用、退回即時烘，而且即時烘的頁＝原包拼的頁（包和即時烘逐像素一樣）。
## 用法：<exe> --path game --resolution 1280x800 -- --pack-selftest=<json 絕對路徑>
func _run_pack_selftest(out_path: String) -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-4000, -4000))
	var AP = preload("res://scripts/ui/atlas_pack.gd")
	var rep := {}
	var wait_all := func(cb: bool) -> void:
		var g := 0
		while not (sprites.build_done and sprites.is_ready(cb) and not sprites._busy and not sprites._ta_busy) and g < 4000:
			g += 1
			await RenderingServer.frame_post_draw
	var page_eq := func(cbn: int, dir: String) -> bool:   # 目前第 0 頁（舊 10 種的第一頁）＝dir 裡的兵種條拼起來
		var pe: Dictionary = sprites.pages[0]
		var got: Image = (pe["tex"] as Texture2D).get_image()
		var strips: Array = []
		for t in pe["types"]:
			strips.append(load("%s/cb%d/type%d.res" % [dir, cbn, t]))
		var want: Image = sprites.page_from(strips, got.get_height() / sprites.CELL)
		return got.get_data() == want.get_data()
	await wait_all.call(false)
	# ① 競態
	AP.reset()
	sprites.pack_stats = {"hit": 0, "paint": 0}
	sprites.build(false)
	for i in 3:
		await RenderingServer.frame_post_draw
	sprites.build(true)
	await wait_all.call(true)
	rep["race_ready_cb"] = sprites.is_ready(true)
	rep["race_pack_still_on"] = AP.usable() and AP.misses == 0
	rep["race_hits"] = sprites.pack_stats["hit"]
	rep["race_paint"] = sprites.pack_stats["paint"]
	rep["race_page_eq"] = page_eq.call(1, AP.DIR)
	# ①b 戰場換色：擴充兵種在場時重建（Codex B09 r3 #2）——重建中舊圖集還能畫、好了以後新圖集也有這些兵種
	var UD = preload("res://scripts/core/unit_defs.gd")
	var ext := [UD.COUNT, UD.COUNT + 1]
	sprites.ensure(ext)
	await wait_all.call(true)
	rep["ext_before"] = ext.all(func(t): return sprites.has_type(t))
	sprites.build(false)
	await RenderingServer.frame_post_draw
	rep["ext_prev_during"] = ext.all(func(t): return sprites.prev_has(t))
	await wait_all.call(false)
	rep["ext_after"] = ext.all(func(t): return sprites.has_type(t)) and sprites.prev.is_empty()
	# ② 壞包：複製一份到 user://，把舊 10 種第一頁的一條換成同尺寸的別種
	var bad := "user://pack_selftest"
	for cbd in ["cb0", "cb1"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(bad + "/" + cbd))
		for f in DirAccess.get_files_at(AP.DIR + "/" + cbd):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(AP.DIR + "/" + cbd + "/" + f), ProjectSettings.globalize_path(bad + "/" + cbd + "/" + f))
	DirAccess.copy_absolute(ProjectSettings.globalize_path(AP.DIR + "/manifest.json"), ProjectSettings.globalize_path(bad + "/manifest.json"))
	var t0: int = sprites.pages[0]["types"][0]
	DirAccess.copy_absolute(ProjectSettings.globalize_path(bad + "/cb0/type%d.res" % (t0 + 1)), ProjectSettings.globalize_path(bad + "/cb0/type%d.res" % t0))
	AP.dir = bad
	AP.reset()
	sprites.pack_stats = {"hit": 0, "paint": 0}
	sprites.build(false)
	await wait_all.call(false)
	rep["bad_detected"] = AP.misses >= 1 and not AP.usable()
	rep["bad_why"] = AP.why
	rep["bad_fell_back_paint"] = sprites.pack_stats["paint"] > 0
	rep["bad_ready"] = sprites.is_ready(false)
	AP.dir = AP.DIR
	rep["paint_eq_pack"] = page_eq.call(0, AP.DIR)   # 退回即時烘的頁＝原包拼的頁
	rep["ok"] = bool(rep["race_ready_cb"]) and bool(rep["race_pack_still_on"]) and int(rep["race_hits"]) > 0 and bool(rep["race_page_eq"]) and bool(rep["ext_before"]) and bool(rep["ext_prev_during"]) and bool(rep["ext_after"]) and bool(rep["bad_detected"]) and bool(rep["bad_fell_back_paint"]) and bool(rep["bad_ready"]) and bool(rep["paint_eq_pack"])
	AP.reset()
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(rep, "  "))
	f.close()
	print("PACKSELFTEST ", "OK" if rep["ok"] else "FAIL", " ", JSON.stringify(rep))
	get_tree().quit(0 if rep["ok"] else 1)


## 1.6.0 B09（S7）冷熱量測：冷＝這個程序開機第一次烘（到「全部就緒」build_done 的時間、期間每幀）；熱＝同一程序切色盲重建 20 次。
## 屏障＝build_done（腳底圈、舊 10 種、轉身／待機／走路轉身全好）＋沒有在烘的新兵頁、轉身出手（Codex B09 r1 #4）。
## 每次記：最長幀（全部幀，含開機頭兩幀）、頭兩幀另列、暫存記憶體峰值（相對開始時）。--bench-blank＝畫面不畫（只量烘焙）；預設有畫面（玩家實際承受：含圖集沒好時的向量替代畫法）。
## 加 --no-pack＝即時烘焙對照。用法：<exe> --path game --resolution 1280x800 -- --pack-bench=<json 絕對路徑> [--no-pack] [--bench-blank]
func _bench_wait(cb: bool) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var last := Time.get_ticks_usec()
	var frames: Array = []
	var m0 := Performance.get_monitor(Performance.MEMORY_STATIC)
	var mpk := m0
	var t_0 := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
	var tpk := t_0
	var g := 0
	while sprites != null and not (sprites.build_done and sprites.is_ready(cb) and not sprites._busy and not sprites._ta_busy) and g < 3000:
		g += 1
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		frames.append(snappedf((now - last) / 1000.0, 0.1))
		last = now
		mpk = maxf(mpk, Performance.get_monitor(Performance.MEMORY_STATIC))
		tpk = maxf(tpk, Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))
	return {"tex_peak_over_mib": snappedf((tpk - t_0) / 1048576.0, 0.1), "tex_peak_mib": snappedf(tpk / 1048576.0, 0.1), "ms": Time.get_ticks_msec() - t0, "longest_frame_ms": frames.max() if not frames.is_empty() else 0.0, "first2": frames.slice(0, 2),
		"after2_max": frames.slice(2).max() if frames.size() > 2 else 0.0, "frames": frames.size(), "temp_peak_mib": snappedf((mpk - m0) / 1048576.0, 0.1)}

func _run_pack_bench(out_path: String) -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-4000, -4000))
	var blank := "--bench-blank" in OS.get_cmdline_user_args()
	if blank:
		visible = false   # 只量烘焙本身：畫面不畫
	var cold: Dictionary = await _bench_wait(false)
	var warm: Array = []
	for i in 20:
		var cb := i % 2 == 0
		sprites.build(cb)
		var w: Dictionary = await _bench_wait(cb)
		w["cb"] = cb
		warm.append(w)
	var AP = preload("res://scripts/ui/atlas_pack.gd")
	var rep := {"blank": blank, "pack": AP.usable(), "why": AP.why, "misses": AP.misses, "cold": cold, "warm": warm, "stats": sprites.pack_stats.duplicate(), "stages": sprites.stage_report(),
		"tex_mib": snappedf(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, 0.1), "static_mib": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1)}
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(rep, "  "))
	f.close()
	get_tree().quit()

## 1.6.0 B09（S7）烘離線圖集包：預設塗裝 × 一般／色盲，全部 22 種兵的頁條、轉身、待機、走路轉身、轉身出手、背面走路、腳底圈。
## 烘完自我核對（兵種條拼回整頁要逐像素一樣）、寫清冊（來源雜湊、引擎、渲染路徑）。視窗移到畫面外（不搶焦點）。
## 用法：<exe> --path game --resolution 1280x800 -- --bake-pack=<報告 json 絕對路徑>
func _run_bake_pack(report_path: String) -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-4000, -4000))
	var AP = preload("res://scripts/ui/atlas_pack.gd")
	var t0 := Time.get_ticks_msec()
	var rep := {"ok": false}
	var saved_paint: Array = Art.paint.duplicate()
	Art.paint = [0, 0, 1, 1, 0, 0]   # 只收預設塗裝
	sprites.pack_capture = true
	AP.saved_sha.clear()
	AP.saved_fsha.clear()
	var mism := 0
	var pages_checked := 0
	for cb in [false, true]:
		var g := 0
		while sprites._busy and g < 2000:   # 等開機那次烘完（避免兩次烘交錯）
			g += 1
			await get_tree().process_frame
		sprites.pack_pages.clear()
		await sprites.build(cb)
		sprites.ensure(range(D.COUNT, 22))
		sprites.ensure_turn_atk(range(0, 22))
		g = 0
		while (sprites._busy or sprites._ta_busy) and g < 20000:
			g += 1
			await get_tree().process_frame
		for pe in sprites.pack_pages:
			var types: Array = pe[0]
			var img: Image = pe[1]
			var strips: Array = []
			for t in types:
				strips.append(load(AP.path(1 if cb else 0, "type%d" % t)))
			var back: Image = sprites.page_from(strips, img.get_height() / sprites.CELL)
			pages_checked += 1
			if back.get_data() != img.get_data():
				mism += 1
	sprites.pack_capture = false
	Art.paint = saved_paint
	var bytes := 0
	var files := 0
	for cbd in ["cb0", "cb1"]:
		var d := DirAccess.open(AP.DIR + "/" + cbd)
		if d != null:
			for f in d.get_files():
				if f.ends_with(".res"):
					files += 1
					bytes += FileAccess.get_file_as_bytes(AP.DIR + "/" + cbd + "/" + f).size()
	var man: Dictionary = AP.env_key()
	man["src"] = AP.src_key()
	man["paint"] = AP.DEFAULT_PAINT
	man["files"] = files
	man["bytes"] = bytes
	man["selfcheck_pages"] = pages_checked
	man["selfcheck_mismatch"] = mism
	man["sha"] = AP.saved_sha.duplicate()
	man["fsha"] = AP.saved_fsha.duplicate()
	if mism == 0 and files > 0:
		var mf := FileAccess.open(AP.MANIFEST, FileAccess.WRITE)
		mf.store_string(JSON.stringify(man, "  "))
		mf.close()
	rep = man.duplicate()
	rep["ok"] = mism == 0 and files > 0
	rep["ms"] = Time.get_ticks_msec() - t0
	var rf := FileAccess.open(report_path, FileAccess.WRITE)
	rf.store_string(JSON.stringify(rep, "  "))
	rf.close()
	print("BAKEPACK ", "OK" if rep["ok"] else "FAIL", " files=", files, " MiB=", snappedf(bytes / 1048576.0, 0.1), " mismatch=", mism, " ms=", rep["ms"])
	get_tree().quit(0 if rep["ok"] else 1)


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

## 1.6.0 B11（P5.5、S3）轉身連拍：劍士、騎兵 × 兩隊 × 色盲開關 × 五方向（東、西＝側面；東南、西南＝往南走的 3/4 正面；北＝背面）
## 兩兩轉換 20 種＝160 組合，每組 8 格。每格記走哪條畫法（圖集／向量＝缺格）；原地轉身（東↔西）另量腳底接地點左右漂移（腳滑比）。
## 用法：<exe> --path game --resolution 1280x800 -- --turn-strip=<輸出資料夾（Windows 路徑）>   每頁存 PNG、最後存 turn_strip.json，印 TURNSTRIP
var ts_mode := false
var ts_types: Array = [[0, false], [3, false]]   # [兵種, 巨獸尺寸]；預設＝B11 的劍士、騎兵
var ts_page: Array = []   # 這一頁要畫的 [type, team, from, to, k, 格子左上]
var ts_routes: Array = []   # 這一頁每格實際走的畫法
const TS_DIRS := ["E", "W", "SE", "SW", "N"]
const TS_CELL := Vector2(78, 96)
func _ts_state(a: String, b: String, k: float) -> Dictionary:
	# 照戰鬥的實際行為模擬（Hydrogen B11 r2）：朝向 face 在 8 格之間連續變（face_now 的轉身插值），走路時 |face|<0.9 由
	# draw_unit 自動走 3/4 正面頁（正中過渡）；南北頁照 heading 前後半；方向切換中間插同一支 hd_blend_c 的轉身格（側↔背不插，見 hd_blend_c）
	var fa := 1.0 if a in ["E", "SE"] else (-1.0 if a in ["W", "SW"] else (1.0 if b in ["E", "SE"] else -1.0))
	var fb := 1.0 if b in ["E", "SE"] else (-1.0 if b in ["W", "SW"] else fa)
	var face := lerpf(fa, fb, k)
	if absf(face) < 0.18:
		face = 0.18 * (signf(fb) if k >= 0.5 else signf(fa))
	var walking := a in ["SE", "SW", "N"] or b in ["SE", "SW", "N"]
	var ha := 1 if a in ["SE", "SW"] else (-1 if a == "N" else 0)
	var hb := 1 if b in ["SE", "SW"] else (-1 if b == "N" else 0)
	var hd := ha if k < 0.5 else hb
	var c := hd_blend_c(ha, hb)
	if ha != hb and c < 1.0 and k > 0.36 and k < 0.64:
		return {"face": signf(face) * c, "hd": 0, "walk": 0.0}
	return {"face": face, "hd": hd, "walk": (0.3 + k * 4.0) if walking else 0.0}

func _ts_draw_one(p: Vector2, type: int, team: int, st: Dictionary) -> String:
	var face: float = st["face"]
	var walk: float = st["walk"]
	var hd: int = st["hd"]
	var dm := dir_draw_mode(type, hd, true)   # 和戰鬥同一支選畫法（Codex B11 r1 #4）
	if hd != 0 and dm == 0:
		Art.unit(self, p, type, team, face, walk, 0.0, 0.0, 1.0, 0.0, UNIT_SCALE, cbm())
		return "vector"   # 要南北頁卻沒有＝缺格
	if dm < 0:
		sprites.draw_back_walk(self, p, type, team, face, walk, 0.0, 1.0, 0.0, UNIT_SCALE, 0.0, 1.0, cbm())
		return "atlas"
	if dm > 0:
		sprites.draw_unit(self, p, type, team, signf(face) * HEAD_FRONT_C, walk, 0.0, 0.0, 1.0, 0.0, UNIT_SCALE, 0, 0.0, 1.0, cbm())
		return "atlas"
	if absf(face) < 0.9 and not sprites.has_turn(type):
		Art.unit(self, p, type, team, face, walk, 0.0, 0.0, 1.0, 0.0, UNIT_SCALE, cbm())
		return "vector"
	if not sprites.has_type(type):
		Art.unit(self, p, type, team, face, walk, 0.0, 0.0, 1.0, 0.0, UNIT_SCALE, cbm())
		return "vector"
	sprites.draw_unit(self, p, type, team, face, walk, 0.0, 0.0, 1.0, 0.0, UNIT_SCALE, 0, 0.0, 1.0, cbm())
	return "atlas"

func _run_turn_strip(out_dir: String) -> void:
	Save.prefix = "shot_"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--turn-strip-types="):
			ts_types = []
			for tk in a.substr(19).split(","):
				ts_types.append([int(tk.trim_suffix("b")), tk.ends_with("b")])
	var res := {"combos": 0, "missing": 0, "missing_list": [], "slide": [], "pages": 0}
	print("TS start")
	for cbv in [false, true]:
		Save.set_setting("colorblind", cbv)
		_rebuild_sprites()
		print("TS rebuild cb=", cbv)
		var guard := 0
		while not (sprites.is_ready(cbv) and sprites.build_done) and guard < 1200:
			guard += 1
			await get_tree().process_frame
		var ts_list: Array = []
		for spec in ts_types:
			ts_list.append(int(spec[0]))
		sprites.ensure(ts_list)
		sprites.ensure_turn_atk(ts_list)   # 和開戰時同一支：出場兵種補烘轉身出手格＋背面走路頁
		var all_bw := func() -> bool:
			for t in ts_list:
				if not sprites.bw_tex.has(t) or not sprites.has_type(t):
					return false
			return true
		while not all_bw.call() and guard < 2400:
			guard += 1
			await get_tree().process_frame
		print("TS ready cb=", cbv, " guard=", guard, " ready=", sprites.is_ready(cbv), " done=", sprites.build_done)
		var jobs: Array = []
		for spec in ts_types:   # 1.6.0 B12：可指定兵種（--turn-strip-types=19b,21；b＝巨獸尺寸）
			for team in 2:
				for a in TS_DIRS:
					for b in TS_DIRS:
						if a != b:
							jobs.append([int(spec[0]), team, a, b, bool(spec[1])])
		var big: bool = not jobs.is_empty() and bool(jobs[0][4])
		var per_page := 4 if big else 8   # 每頁 2 欄 × 4 列、列距 196（騎兵的槍伸很高，列距 98 會伸進上一列的腳底量測區）；巨獸一列一組
		for pg in range(0, jobs.size(), per_page):
			ts_page = []
			for ji in range(pg, mini(pg + per_page, jobs.size())):
				var j: Array = jobs[ji]
				var row := ji - pg
				for f in 8:
					if bool(j[4]):
						ts_page.append([j[0], j[1], j[2], j[3], f / 7.0, Vector2(6 + f * 158, 4 + row * 196), true])
					else:
						ts_page.append([j[0], j[1], j[2], j[3], f / 7.0, Vector2(6 + f * 78 + (640 if row >= 4 else 0), 100 + (row % 4) * 196), false])
			ts_mode = true
			queue_redraw()
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.save_png(out_dir.path_join("turn_strip_cb%d_%02d.png" % [int(cbv), pg / per_page]))
			res["pages"] += 1
			for ji in range(pg, mini(pg + per_page, jobs.size())):
				var j: Array = jobs[ji]
				res["combos"] += 1
				var miss := 0
				var xs: Array = []
				for f in 8:
					var idx := (ji - pg) * 8 + f
					if ts_routes[idx] != "atlas" and not bool(j[4]):   # 巨獸本來就是向量畫（放大超過 1.4 倍），不算缺格
						miss += 1
					if j[2] in ["E", "W"] and j[3] in ["E", "W"]:
						xs.append(_ts_feet_lr(img, ts_page[idx][5], bool(j[4])))
				if miss > 0:
					res["missing"] += miss
					res["missing_list"].append([j[0], j[1], int(cbv), j[2], j[3], miss])
				if not xs.is_empty():
					var lo := 1e9
					var hi := -1e9
					var lo2 := 1e9
					var hi2 := -1e9
					var bad := 0
					for x in xs:
						if x.x > -900.0:
							lo = minf(lo, x.x)
							hi = maxf(hi, x.x)
							lo2 = minf(lo2, x.y)
							hi2 = maxf(hi2, x.y)
						else:
							bad += 1
					hi = maxf(hi - lo, hi2 - lo2) + lo   # 左右腳各自的漂移取大者
					# 八格都要量得到腳（Codex B11 r1 #5：量不到不能當沒滑）；量不到＝ 9.9（必失敗）
					var bw: float = 36.0 * UNIT_SCALE / 0.92 * (BossD.DRAW_SCALE if bool(j[4]) else 1.0)
					res["slide"].append([j[0], j[1], int(cbv), j[2], j[3], snappedf((hi - lo) / bw, 0.001) if bad == 0 and hi >= lo else 9.9])
	ts_mode = false
	Save.set_setting("colorblind", false)
	var worst := 0.0
	for sl in res["slide"]:
		worst = maxf(worst, float(sl[5]))
	res["slide_max"] = worst
	var f := FileAccess.open(out_dir.path_join("turn_strip.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(res))
	f.close()
	var ok: bool = res["combos"] == 80 * ts_types.size() and res["missing"] == 0 and worst <= 0.1
	print("TURNSTRIP ", "OK" if ok else "FAIL", " combos=", res["combos"], " missing=", res["missing"], " slide_max=", worst)
	get_tree().quit(0 if ok else 1)

## 一格的腳底接地點：找到最低的前景列，取「最低 6 列」裡所有前景像素的平均 x（相對格子中心）——兩隻腳都算進去
## （只取最低一列會只抓到靠前那隻腳，轉身時換腳就像在滑；B11 第一版的量法錯誤）
func _ts_foot_x(img: Image, o: Vector2, big := false) -> float:
	var x0 := int(o.x)
	var y0 := int(o.y)
	var low := -1
	var cw := 154 if big else 74
	var cx := 79 if big else 39
	var ybot := 190 if big else 95
	for yy in range(y0 + ybot, y0 + 20, -1):
		for xx in range(x0 + 4, mini(x0 + cw, img.get_width())):   # 畫面外 get_pixel 會給黑色（被當成腳）
			var c := img.get_pixel(xx, yy)
			if absf(c.r - 0.5) + absf(c.g - 0.5) + absf(c.b - 0.5) > 0.12:
				low = yy
				break
		if low >= 0:
			break
	if low < 0:
		return -999.0
	var pts: Array = []
	for yy in range(low - (9 if big else 5), low + 1):
		for xx in range(x0 + 4, mini(x0 + cw, img.get_width())):
			var c := img.get_pixel(xx, yy)
			if absf(c.r - 0.5) + absf(c.g - 0.5) + absf(c.b - 0.5) > 0.12:
				pts.append(float(xx))
	if pts.is_empty():
		return -999.0
	return pts.reduce(func(acc, v): return acc + v, 0.0) / pts.size() - (x0 + cx)

## 左右腳分開追蹤（Codex B12 r1 #4：只看雙腳重心，對稱往內滑看不出來）：最低帶的前景像素以重心分左右兩群，各取平均 x
func _ts_feet_lr(img: Image, o: Vector2, big := false) -> Vector2:
	var x0 := int(o.x)
	var y0 := int(o.y)
	var cw := 154 if big else 74
	var cx := 79 if big else 39
	var c0: float = _ts_foot_x(img, o, big)
	if c0 < -900.0:
		return Vector2(-999.0, -999.0)
	var low := -1
	for yy in range((y0 + (190 if big else 95)), y0 + 20, -1):
		for xx in range(x0 + 4, mini(x0 + cw, img.get_width())):
			var c := img.get_pixel(xx, yy)
			if absf(c.r - 0.5) + absf(c.g - 0.5) + absf(c.b - 0.5) > 0.12:
				low = yy
				break
		if low >= 0:
			break
	var ls := 0.0
	var ln := 0
	var rs := 0.0
	var rn := 0
	for yy in range(low - (9 if big else 5), low + 1):
		for xx in range(x0 + 4, mini(x0 + cw, img.get_width())):
			var c := img.get_pixel(xx, yy)
			if absf(c.r - 0.5) + absf(c.g - 0.5) + absf(c.b - 0.5) > 0.12:
				if float(xx) - (x0 + cx) < c0:
					ls += xx
					ln += 1
				else:
					rs += xx
					rn += 1
	return Vector2(ls / maxi(1, ln) - (x0 + cx) if ln > 0 else c0, rs / maxi(1, rn) - (x0 + cx) if rn > 0 else c0)

func _draw() -> void:
	if ts_mode:
		draw_rect(Rect2(0, 0, 1280, 800), Color(0.5, 0.5, 0.5))
		ts_routes = []
		for e in ts_page:
			var o: Vector2 = e[5]
			var st := _ts_state(e[2], e[3], e[4])
			if bool(e[6]):
				# 巨獸：和戰鬥同一條路（放大 1.75 倍走向量畫，Art.unit）；不吃南北方向、不插方向過渡（Codex B12 r1 #3）；
				# 朝向照 _face_of（Codex B12 r1 #1：工具要和戰鬥同一條）
				var fa0 := 1.0 if e[2] in ["E", "SE"] else (-1.0 if e[2] in ["W", "SW"] else (1.0 if e[3] in ["E", "SE"] else -1.0))
				var fb0 := 1.0 if e[3] in ["E", "SE"] else (-1.0 if e[3] in ["W", "SW"] else fa0)
				var fl := lerpf(fa0, fb0, e[4])
				var fw := 1.0 if fl >= 0.0 else -1.0   # 和戰鬥 _face_of 同一條：巨獸直接換邊（B12）
				var wk: float = (0.3 + float(e[4]) * 4.0) if (e[2] in ["SE", "SW", "N"] or e[3] in ["SE", "SW", "N"]) else 0.0
				Art.unit(self, o + Vector2(79, 168), e[0], e[1], fw, wk, 0.0, 0.0, 1.0, 0.0, UNIT_SCALE * BossD.DRAW_SCALE, cbm())
				ts_routes.append("vector")
			else:
				ts_routes.append(_ts_draw_one(o + Vector2(39, 78), e[0], e[1], st))
		draw_set_transform_matrix(Transform2D.IDENTITY)
		return
	if not sil_mode:
		super._draw()
		return
	draw_rect(Rect2(0, 0, 1280, 800), Color(0.5, 0.5, 0.5))
	# 1.6.0 B10（Codex B10 r1 #6）：樣本可換——--sil-team=1（紅方）、--sil-atk=0.5（攻擊格）、--sil-cb（色盲）、--sil-turn=0.55（轉身角 cos）
	var ua := OS.get_cmdline_user_args()
	var st := 0
	var sa := 0.0
	var scb := false
	var stc := 1.0
	for a in ua:
		if a.begins_with("--sil-team="):
			st = int(a.substr(11))
		elif a.begins_with("--sil-atk="):
			sa = float(a.substr(10))
		elif a == "--sil-cb":
			scb = true
		elif a.begins_with("--sil-turn="):
			stc = float(a.substr(11))
	Art.turn_c = stc
	Art.turn_s = sqrt(maxf(0.0, 1.0 - stc * stc))
	for t in 22:
		var col := t % 11
		var row := t / 11
		var x := 58.0 + col * 116.0
		Art.unit(self, Vector2(x, 150.0 + row * 210.0), t, st, 1.0, 0.0, sa, 0.0, 1.0, 0.0, 1.6, scb)
		Art.unit(self, Vector2(x, 560.0 + row * 110.0), t, st, 1.0, 0.0, sa, 0.0, 1.0, 0.0, 0.8, scb)
	Art.turn_c = 1.0
	Art.turn_s = 0.0


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
	if ov_trans_k() < 1.0:
		_ov_t = time - 1.0   # 1.4.0 §2.2：轉場中的第一下會被吃掉（設計如此）；走訪時等轉場結束再按（等於玩家等 0.25 秒）
	_trans_reset_input()
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
	for nk in ["lobby", "place", "result"]:   # 1.2.0：老闆便條是第一次才跳的疊層，手把流程先當看過（便條本身另有截圖與測試）
		preload("res://scripts/game/guide.gd").see(Save.data, "note_" + nk)
	_go_title()
	await _pw_frames(3)
	await _pw_cycle("標題")
	# 1.6.0 B05：三主牌（0～2）＋「更多」（3，抽屜；打開後 4 遊戲間、5 收藏）＋系統列（抽屜關著時 4 設定、5 離開）
	for step in [[0, "hub_play", false], [1, "hub_gauntlet", false], [2, "hub_challenge", false], [4, "playroom", true], [5, "hub_collect", true], [4, "settings", false]]:
		_go_title()
		home_more = false
		if step[2]:
			await _pw_pick(3, "標題→更多")
			_pw_check(home_more, "標題→更多：抽屜沒打開")
		await _pw_pick(step[0], "標題→" + str(step[1]))
		_pw_check(overlay == step[1], "標題→%s：現在是 %s" % [step[1], overlay])
		await _pw_cycle(str(step[1]))
		await _pw_btn(JOY_BUTTON_B)
		_pw_check(overlay == "", "%s：B 關不掉" % step[1])
	_go_title()
	home_more = false
	await _pw_pick(3, "標題→更多")
	await _pw_btn(JOY_BUTTON_B)
	_pw_check(not home_more and overlay == "", "更多抽屜：B 收不起來")
	_go_title()
	await _pw_pick(3, "標題→更多")
	await _pw_pick(5, "更多→收藏")
	await _pw_pick(7, "收藏→代碼")   # 1.5.0：代碼在收藏第 8 張
	_pw_check(overlay == "codes", "收藏→代碼：現在是 %s" % overlay)
	await _pw_cycle("codes")
	_go_title()
	await _pw_pick(0, "標題→對戰")
	await _pw_pick(1, "對戰→對 AI 大廳")
	await _pw_cycle("大廳")
	# 1.5.0 §1.2 大廳三步：RB 下一步、LB 上一步、Y 進階折頁；換步後焦點在主鈕（Codex v150 cat03 #5）
	_go_title()
	_open_lobby("ai")   # 上面巡過每顆鈕之後畫面不在大廳了：重新打開
	lobby_step = 0
	lobby_open = false
	lobby_menu = false
	await _pw_frames(3)
	_ov_t = time - 1.0   # 等疊層開始畫、轉場直接到終態（第一下不要被轉場吃掉）
	for st in [1, 2]:
		await _pw_btn(JOY_BUTTON_RIGHT_SHOULDER)
		await _pw_frames(3)
		_pw_check(lobby_step == st, "大廳 RB：應該到第 %d 步，現在 %d（overlay=%s menu=%s open=%s state=%d cmds=%d）" % [st + 1, lobby_step + 1, overlay, str(lobby_menu), str(lobby_open), state, _cmds.size()])
		_pw_check(_focus >= 0 and _focus < _btns.size() and _btns[_focus]["r"].position.x >= 960.0, "大廳換步後焦點不在主鈕（第 %d 步）" % [st + 1])
		await _pw_cycle("大廳第 %d 步" % [st + 1])
	await _pw_btn(JOY_BUTTON_LEFT_SHOULDER)
	await _pw_frames(3)
	_pw_check(lobby_step == 1, "大廳 LB：應該回第 2 步")
	await _pw_btn(JOY_BUTTON_Y)
	await _pw_frames(3)
	_pw_check(lobby_open, "大廳 Y：應該打開進階折頁")
	await _pw_btn(JOY_BUTTON_Y)
	await _pw_frames(3)
	_pw_check(not lobby_open, "大廳 Y：應該收起進階折頁")
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
	wait = 0
	while call("_ink_active") and wait < 300:   # 1.2.0：宣紙戰報演完（約 1 秒）才出結果面板
		wait += 1
		await get_tree().process_frame
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
	lobby_step = 2   # 1.5.0：規則列（軍令快切）在第三步
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
	set("trial_page", 3)   # 1.5.0：每頁 8 關，30 關分 4 頁
	await _snap("v150_90b_trials_p4.png")
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
	preload("res://scripts/game/guide.gd").see(Save.data, "tour161")   # 1.6.0 R0：導覽已看過（不然存檔改了會跳出新玩法導覽，蓋住要拍的標題）
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
	_ed_set_map(1)   # 1.2.0 §11.10 出題台地形（雙橋河谷）
	await _snap("v120_07_editor_map.png")
	_ed_set_map(0)
	ed_tab = 1   # 1.6.0 B07（P2.5）：出題台驗證段
	await _snap("v160_13b_editor_verify.png")
	ed_tab = 0
	overlay = ""
	if "--shot-open" in OS.get_cmdline_user_args():
		# 1.2.0 第 11 大類 開發用：實物開合動畫開到一半（不在版面清冊：蓋子蓋住字是設計，不做對比檢查；只在 --shot-open 時拍）
		for ok in [["settings", "dev_open_box.png"], ["codes", "dev_open_letter.png"], ["puzzles", "dev_open_fold.png"], ["profile", "dev_open_trunk.png"]]:
			overlay = ok[0]
			set("obj_open_force", 0.45)
			await _snap(ok[1])
		set("obj_open_force", -1.0)
		overlay = ""
	# 1.2.0 §11.7 戰役面板（第 1 章：前兩關有星）
	Save.data["campaign"] = {"c1_1": 3, "c1_2": 1}
	camp_ch = 1
	overlay = "campaign"
	await _snap("v120_06_campaign.png")
	Save.data["campaign"] = {}
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
	overlay = "owner_daily"   # 1.3.0 §12.7 每日老闆出題
	Save.data["od_stamps"] = 13   # 1.4.0 §10.5 印章冊：第 2 頁蓋了 3 格
	await _snap("v130_od_owner_daily.png")
	nb_buf = ""
	overlay = ""
	coop_log = []
	Save.data = keep
	_go_title()


## 1.6.0 B06（Codex B06 r1 #4）：便條釘位的真實繪製＋手把——真的畫出來（按鈕由繪製登記）、十字鍵從結果頁按鈕走到「打開看」、A 打開、B 關掉。
## 結果印在 run.log：NOTEPIN OK／FAIL（驗收鏈數 24 組都要 OK）。存檔已是截圖前綴，B 關掉記住的「看過」不碰正式存檔。
## 1.6.0 B04（S1）：大廳手把 ≤3 步開戰——真的畫面、真的手把 A（走 _input），從打開大廳（第一步）按到進入擺陣，
## 印 LOBBYPAD OK／FAIL；走完回到大廳第三步、還原手把模式（之後的截圖照舊）。
## 1.6.0 B05（S9）：冷啟到開戰的點擊數——真畫面、真的滑鼠點擊（走 _input）：首開便條按「開第一局」→ 大廳確認步按「開戰」→ 擺陣。
## 印 FIRSTRUN OK／FAIL（點擊數、便條面積比、和示範戰場框相交否）；走完回到標題。
func _first_run_walk() -> void:
	var pad0: bool = pad_mode
	var had_dis: bool = shot_state.has("dis")
	shot_state.erase("dis")
	var fd0 = Save.s("first_done")
	var data0: Dictionary = Save.data.duplicate(true)
	var rng0: int = rng.state
	Save.set_setting("first_done", false)   # 真的冷啟：沒設定過＝開機那一支判斷打開首開（不是手動指定疊層）
	var frame := func() -> void:
		queue_redraw()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	var click := func(p: Vector2) -> void:
		for dn in [true, false]:
			var e := InputEventMouseButton.new()
			e.button_index = MOUSE_BUTTON_LEFT
			e.position = p
			e.pressed = dn
			_input(e)
			await get_tree().process_frame
	_go_title()
	_boot_first_run(true)   # 和開機同一支（截圖模式也照走）
	await frame.call()
	var booted: bool = overlay == "first_run"
	var R: Rect2 = first_run_rect()
	var area: float = R.get_area() / (1280.0 * 800.0)
	# 標題示範戰場在畫面上的框（game_screens 標題的鏡頭：縮 0.72、靠右；和 _draw 同一組數字）
	var fz := 0.72
	var off := Vector2(1270.0 - (ORIGIN.x + FIELD.x) * fz, 400.0 - (ORIGIN.y + FIELD.y / 2.0) * fz)
	var field := Rect2(ORIGIN * fz + off, FIELD * fz)
	var hits_field: bool = R.intersects(field)
	var clicks := 0
	var cw: float = R.size.x - 40.0
	var hw: float = (cw - 8.0) / 2.0
	await click.call(Rect2(R.position.x + 20.0 + hw + 8.0, R.end.y - 18.0 - 48.0, hw, 48.0).get_center())   # 開第一局
	clicks += 1
	await frame.call()
	var in_lobby: bool = overlay == "lobby" and lobby_step == 2
	await click.call(Rect2(966, 700, 234, 48).get_center())   # 大廳確認步「開戰」
	clicks += 1
	for i in 3:
		await get_tree().process_frame
	var ok: bool = booted and in_lobby and state == St.PLACE and clicks <= 3 and area <= 0.35 and not hits_field
	print("FIRSTRUN ", "OK" if ok else "FAIL", " ", JSON.stringify({"booted": booted, "clicks": clicks, "lobby_confirm": in_lobby, "place": state == St.PLACE, "note_area": snappedf(area, 0.001), "hits_field": hits_field}))
	Save.set_setting("first_done", fd0)
	Save.data = data0
	rng.state = rng0
	_go_title()
	overlay = ""
	pad_mode = pad0
	if had_dis:
		shot_state["dis"] = true

## 1.6.0 B14（P5.3）疲累：另開一場會打很久的（訓練陣 2 對 9，約 51 秒），推到 32 秒（tick 640）拍——殘血的兵往前垂。
## 用完把戰鬥狀態交回下一段截圖自己設定（後面的截圖都會重新開場）。
func _shot_fatigue() -> void:
	var FF = preload("res://scripts/core/formations.gd")
	var pool: Array = FF.training_pool(0)
	_begin_battle(pool[2].copy(), pool[9].mirrored(), "replay")
	start_hold = 0.0
	while not view.finished and view.tick < 640:
		_sim_step(false)
	for k in 30:
		_frame_alive(0.1)   # 讓受擊閃白、表情退掉（同 04_clutch 的做法）
	slow_left = 0.0
	clutch_t = 0.0
	zoom = 1.0
	# 拉近到血最少的疲累兵（亂戰裡看得到姿勢與汗滴；Hydrogen B14 r1）
	var tgt = null
	for u in view.units:
		if u.alive and fatigued(u) and (tgt == null or u.hp < tgt.hp):
			tgt = u
	if tgt != null:
		zoom = 2.0
		zoom_target = 2.0
		zoom_center = _upos(tgt) + Vector2(0, -30)
	await _snap("v160_14a_fatigue.png")
	zoom = 1.0
	zoom_target = 1.0

func _lobby_pad_walk() -> void:
	var pad0: bool = pad_mode
	# 走查真的開戰：會寫 last_rules、蓋章數、消耗亂數——全部存起來、走完還原（不然之後截圖的 AI 陣容、規則都變了；b04c 抓到 74_cmd_cast 0→423）
	var data0: Dictionary = Save.data.duplicate(true)
	var rng0: int = rng.state
	var had_dis: bool = shot_state.has("dis")   # 停用組合：全部按鈕畫成停用，A 按不下去；走的時候拿掉（同 _note_pin_walk）
	shot_state.erase("dis")
	var frame := func() -> void:
		queue_redraw()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	var press := func(b: int, same_frame := false) -> void:
		for dn in [true, false]:
			var e := InputEventJoypadButton.new()
			e.device = 0
			e.button_index = b
			e.pressed = dn
			_input(e)
			if not same_frame:
				await get_tree().process_frame
	var rep := {}
	# ①對 AI、②雙人：從打開大廳（第一步）連按 A，幾下進到擺陣（S1 ≤3）
	for kind in ["ai", "duel"]:
		_go_title()
		_open_lobby(kind)
		lobby_step = 0
		var steps := 0
		for i in 5:
			await frame.call()
			if state != St.TITLE or overlay != "lobby":
				break
			await press.call(JOY_BUTTON_A)
			steps += 1
		for i in 3:
			await get_tree().process_frame
		rep[kind] = {"steps": steps, "place": state == St.PLACE}
	# ③同一幀兩下 A：只走一步（不跳過第二步）
	_go_title()
	_open_lobby("ai")
	lobby_step = 0
	await frame.call()
	await press.call(JOY_BUTTON_A, true)
	await press.call(JOY_BUTTON_A, true)
	await get_tree().process_frame
	await frame.call()
	rep["same_frame"] = lobby_step
	# ④撥片：十字鍵往上走到玩法頁籤（lb_modes 組）、A 換玩法；⑤B 退一步／離開，重開焦點回主鈕
	var p0: String = str(lobby_r.preset)
	var moved := 0
	for i in 20:   # 十字鍵在大廳是照閱讀順序前後移（1.5.0 起），頁籤在最前面，最多走 20 下
		await frame.call()
		if _focus >= 0 and _focus < _btns.size() and str(_btns[_focus].get("group", "")) == "lb_modes":
			break
		await press.call(JOY_BUTTON_DPAD_UP)
		moved += 1
	var on_tab: bool = _focus >= 0 and _focus < _btns.size() and str(_btns[_focus].get("group", "")) == "lb_modes"
	if on_tab:
		await press.call(JOY_BUTTON_DPAD_LEFT)   # 換到隔壁那片撥片（往左一定還在玩法頁籤組裡；往右可能是「我的預設」下拉）
		await frame.call()
		on_tab = _focus >= 0 and _focus < _btns.size() and str(_btns[_focus].get("group", "")) == "lb_modes"
		await press.call(JOY_BUTTON_A)
		await frame.call()
	rep["tab"] = {"reached": on_tab, "moves": moved, "changed": str(lobby_r.preset) != p0}
	var st1: int = lobby_step
	await press.call(JOY_BUTTON_B)
	await frame.call()
	rep["back"] = {"from_step": st1, "overlay": overlay, "step": lobby_step}
	_go_title()
	_open_lobby("ai")
	await frame.call()
	var fm: int = _focus
	# 主鈕＝底列右邊那顆（下一步／開戰，Rect2(966, 700, 234, 48)；點擊區可能加高，比位置與寬）（Codex B04 r2）
	rep["reopen_main"] = fm >= 0 and fm < _btns.size() and is_equal_approx((_btns[fm]["r"] as Rect2).position.x, 966.0) and is_equal_approx((_btns[fm]["r"] as Rect2).size.x, 234.0)
	var ok: bool = rep["ai"]["place"] and rep["ai"]["steps"] <= 3 and rep["duel"]["place"] and rep["duel"]["steps"] <= 3 and rep["same_frame"] == 1 and rep["tab"]["reached"] and rep["tab"]["changed"] \
		and rep["back"]["overlay"] == "" and rep["reopen_main"]
	print("LOBBYPAD ", "OK" if ok else "FAIL", " ", JSON.stringify(rep))
	Save.data = data0
	rng.state = rng0
	_go_title()
	_open_lobby("ai")
	mouse = Vector2(-100, -100)
	pad_mode = pad0
	if had_dis:
		shot_state["dis"] = true

func _note_pin_walk() -> void:
	# 「停用」組合（:dis）會把所有按鈕畫成停用、A 按不下去；這段驗的是手把能走到並打開便條，走的時候暫時拿掉停用旗標
	var had_dis: bool = shot_state.has("dis")
	shot_state.erase("dis")
	var pad0: bool = pad_mode   # 走查送真的手把事件會切到手把模式：走完還原，不然之後的截圖都多了手把提示（1.6.0 B04 抓到）
	var lay: Dictionary = _note_pin_layout()
	var target: Vector2 = (lay["btn"] as Rect2).get_center()
	var find := func() -> int:
		for i in _btns.size():
			if (_btns[i]["r"] as Rect2).has_point(target):
				return i
		return -1
	queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var bi: int = find.call()
	var rep := {"registered": bi >= 0}
	var send := func(b: int) -> void:
		for dn in [true, false]:
			var e := InputEventJoypadButton.new()
			e.device = 0
			e.button_index = b
			e.pressed = dn
			_input(e)
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
	_focus = 0
	var steps := 0
	for dir in [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_LEFT]:
		if _focus == find.call():
			break
		await send.call(dir)
		steps += 1
	rep["reached"] = _focus == find.call() and _focus >= 0
	rep["steps"] = steps
	await send.call(JOY_BUTTON_A)
	rep["opened"] = overlay == "boss_note" and note_key == "result"
	await send.call(JOY_BUTTON_B)
	rep["closed"] = overlay == ""
	var ok: bool = rep["registered"] and rep["reached"] and rep["opened"] and rep["closed"]
	print("NOTEPIN ", "OK" if ok else "FAIL", " ", JSON.stringify(rep))
	overlay = ""
	if had_dis:
		shot_state["dis"] = true
	pad_mode = pad0
