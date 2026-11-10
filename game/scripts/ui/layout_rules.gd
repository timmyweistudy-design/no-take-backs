## V1.5.2 排版幾何規則（docs/ui-layout-rules.md）：只吃矩形，不畫圖，所以能用純矩形反例測試。
## 輸入是一幀的探針資料（ui_base.gd 的 _panel、_h1、依附裝飾、對齊宣告、文字、按鈕），輸出 {fail: [], warn: [], exempt: []}。
## 每條違規都帶規則代碼（R1…R10、G 守衛）與元件 ID，報告才能逐條對到程式。
extends RefCounted

const SCREEN := Rect2(0, 0, 1280, 800)
const TOL_CENTER := 1.0    # R1、R4、R10：中線容差
const TOL_ATTACH := 1.0    # R3：依附邊容差
const GAP_FAIL := 12.0     # R2：緞帶下距 <12 失敗
const GAP_OK := 16.0       # R2：12～16 警告、≥16 通過
const BTN_TEXT_GAP := 12.0 # R9：置中說明文字到按鈕列
const LABEL_GAP := 2.0     # R9：靠左欄位標籤到它下面的控制項（不能貼住）
const EDGE_MIN := 16.0     # R8：面板距畫面邊
const GAP_EQ_TOL := 2.0    # R4：同組間距差
const FILL_WARN := 0.3     # R6：最大垂直空白 > 面板高 30%（且 >160px）警告
const GAP_EMPTY := 160.0

## d = {panels:[{id,r,skip:{R:理由}}], ribbons:[{id,r,body,cx,bottom,host}], decos:[{id,kind,r,host_r,edge}],
##      aligns:[{id,rects,tol}], texts:[{r,gr,s,btn,own}], btns:[Rect2], overlay:String, need:{role:min}}
static func check(d: Dictionary) -> Dictionary:
	var out := {"fail": [], "warn": [], "exempt": []}
	var panels: Array = d.get("panels", [])
	var ribbons: Array = d.get("ribbons", [])
	var texts: Array = d.get("texts", [])
	var btns: Array = d.get("btns", [])
	# ── G 守衛：ID 唯一、宿主有效、必要角色數量 ──
	var ids := {}
	for coll in [panels, ribbons, d.get("decos", []), d.get("aligns", [])]:
		for e in coll:
			var id := str(e.get("id", ""))
			if id == "":
				_add(out, "fail", "G", "?", "元件沒有 ID")
			elif ids.has(id):
				_add(out, "fail", "G", id, "ID 重複")
			ids[id] = true
	var need: Dictionary = d.get("need", {})
	var have := {"panel": panels.size(), "ribbon": ribbons.size(), "bookmark": 0}
	for dc in d.get("decos", []):
		have[str(dc["kind"])] = int(have.get(str(dc["kind"]), 0)) + 1
	for role in need:
		if int(have.get(role, 0)) < int(need[role]):
			_add(out, "fail", "G", role, "漏登記：%s 需要 ≥%d，實得 %d" % [role, int(need[role]), int(have.get(role, 0))])
	for rb in ribbons:
		if not panels.is_empty() and _panel_by_id(panels, str(rb.get("host", ""))) == null:
			_add(out, "fail", "G", rb["id"], "緞帶沒有有效的宿主面板（host=%s）" % str(rb.get("host", "")))
	if str(d.get("overlay", "")) != "" and panels.is_empty() and not bool(d.get("panelless_ok", false)):
		_add(out, "fail", "G", str(d["overlay"]), "漏登記：覆蓋層沒有面板")
	# ── R1 面板（_panel 一律有全螢幕遮罩＝模態）水平置中；R8 面板距畫面邊 ──
	for p in panels:
		var r: Rect2 = p["r"]
		if _skip(out, p, "R1"):
			pass
		elif absf(r.get_center().x - SCREEN.get_center().x) > TOL_CENTER:
			_add(out, "fail", "R1", p["id"], "模態面板沒有水平置中：中心 x=%.1f（應 640）" % r.get_center().x)
		if not _skip(out, p, "R8") and (r.position.x < EDGE_MIN - 0.5 or r.position.y < EDGE_MIN - 0.5 or r.end.x > SCREEN.end.x - EDGE_MIN + 0.5 or r.end.y > SCREEN.end.y - EDGE_MIN + 0.5):
			_add(out, "fail", "R8", p["id"], "面板距畫面邊 <16：%s" % str(r))
	# ── R2 緞帶置中於宿主面板；緞帶完整下緣到第一個內容 ──
	for rb in ribbons:
		var host = _panel_by_id(panels, str(rb.get("host", "")))
		var rr: Rect2 = rb["r"]
		if host != null and not _skip(out, host, "R2") and absf(float(rb["cx"]) - (host["r"] as Rect2).get_center().x) > TOL_CENTER:
			_add(out, "fail", "R2", rb["id"], "緞帶沒有置中於面板：緞帶 %.1f、面板 %.1f" % [float(rb["cx"]), (host["r"] as Rect2).get_center().x])
		var gap := INF
		var who := ""
		for c in _contents(texts, btns):
			var cr: Rect2 = c["r"]
			if rr.encloses(cr.grow(-1.0)) and c.get("kind") == "text":
				continue   # 緞帶自己的標題字
			if cr.end.x <= rr.position.x or cr.position.x >= rr.end.x:
				continue   # 水平沒有疊到緞帶（含尾）
			if cr.end.y <= rr.position.y:
				continue   # 在緞帶上方
			if host != null and not (host["r"] as Rect2).grow(1.0).has_point(cr.get_center()):
				continue
			var g: float = cr.position.y - float(rb["bottom"])
			if g < gap:
				gap = g
				who = str(c["s"])
		if gap < INF:
			var hs = host if host != null else {}
			if gap < GAP_FAIL:
				if not _skip(out, hs, "R2"):
					_add(out, "fail", "R2", rb["id"], "緞帶下緣到「%s」只有 %.1fpx（<12）" % [who, gap])
			elif gap < GAP_OK and not _skip(out, hs, "R2w"):
				_add(out, "warn", "R2", rb["id"], "緞帶下緣到「%s」%.1fpx（12～16）" % [who, gap])
	# ── R3 依附裝飾貼齊依附邊、不跑出宿主 ──
	for dc in d.get("decos", []):
		var r: Rect2 = dc["r"]
		var h: Rect2 = dc["host_r"]
		match str(dc.get("edge", "top")):
			"top":
				if absf(r.position.y - h.position.y) > TOL_ATTACH:
					_add(out, "fail", "R3", dc["id"], "%s 上緣 %.1f 沒貼齊宿主上緣 %.1f" % [dc["kind"], r.position.y, h.position.y])
			"bottom":
				if absf(r.position.y - h.end.y) > TOL_ATTACH:
					_add(out, "fail", "R3", dc["id"], "%s 上緣 %.1f 沒貼齊宿主下緣 %.1f" % [dc["kind"], r.position.y, h.end.y])
		if r.position.x < h.position.x - TOL_ATTACH or r.end.x > h.end.x + TOL_ATTACH:
			_add(out, "fail", "R3", dc["id"], "%s 水平超出宿主" % dc["kind"])
	# ── R4 面板最下面那排按鈕：群組置中於面板（或宣告的欄中線）、間距相等、雙按鈕同寬 ──
	for p in panels:
		if _skip(out, p, "R4"):
			continue
		var pr: Rect2 = p["r"]
		var row := _bottom_row(pr, btns)
		if row.is_empty() or _is_grid_row(row, pr, btns):
			continue   # 格狀排列（例如禁用牌 20 格）最後一排靠左是格線，不是按鈕群組
		var x0 := INF
		var x1 := -INF
		for b in row:
			x0 = minf(x0, b.position.x)
			x1 = maxf(x1, b.end.x)
		var axis: float = float(p.get("axis", pr.get_center().x))
		if absf((x0 + x1) * 0.5 - axis) > TOL_CENTER:
			_add(out, "fail", "R4", p["id"], "底部按鈕群組中心 %.1f 不在中線 %.1f" % [(x0 + x1) * 0.5, axis])
		if row.size() >= 3:
			var gs: Array = []
			for i in range(1, row.size()):
				gs.append(row[i].position.x - row[i - 1].end.x)
			if gs.max() - gs.min() > GAP_EQ_TOL:
				_add(out, "fail", "R4", p["id"], "底部按鈕間距不等：%s" % str(gs))
		if row.size() == 2 and absf(row[0].size.x - row[1].size.x) > TOL_CENTER:
			_add(out, "fail", "R4", p["id"], "雙按鈕不同寬：%.0f／%.0f" % [row[0].size.x, row[1].size.x])
	# ── R8 面板內的按鈕、文字不能超出面板；按鈕連焦點框外擴都要在畫面內 ──
	for p in panels:
		if _skip(out, p, "R8"):
			continue
		var pr: Rect2 = p["r"]
		for b in btns:
			if pr.has_point(b.get_center()) and not pr.grow(1.0).encloses(b):
				_add(out, "fail", "R8", p["id"], "按鈕超出面板：%s" % str(b))
		for t in texts:
			var tr: Rect2 = t.get("gr", t["r"])
			var on_ribbon := false   # 緞帶上的標題字跟著緞帶（緞帶可跨面板上緣）
			for rb in ribbons:
				if (rb["r"] as Rect2).grow(1.0).encloses(tr):
					on_ribbon = true
			if on_ribbon:
				continue
			if pr.has_point(tr.get_center()) and not pr.grow(1.0).encloses(tr):
				_add(out, "fail", "R8", p["id"], "「%s」超出面板" % str(t["s"]))
	var fo: float = float(d.get("focus_out", 0.0))
	if fo > 0.0:
		for b in btns:
			if not SCREEN.encloses((b as Rect2).grow(fo)):
				_add(out, "fail", "R8", "screen", "按鈕的焦點框（外擴 %dpx）超出畫面：%s" % [int(fo), str(b)])
	# ── R9 面板內：按鈕上方的文字最下緣到按鈕 ≥12（文字多就要長高，不能壓鈕）──
	for p in panels:
		var pr: Rect2 = p["r"]
		for t in texts:
			if bool(t.get("btn", false)):
				continue
			var tr: Rect2 = t.get("gr", t["r"])
			if not pr.has_point(tr.get_center()):
				continue
			for b in btns:
				if not pr.has_point(b.get_center()) or b.encloses(tr):
					continue
				if tr.end.x <= b.position.x or tr.position.x >= b.end.x:
					continue
				if tr.get_center().y >= b.position.y:
					continue   # 文字不在按鈕上方
				var g: float = b.position.y - tr.end.y
				# 置中的說明文字（彈窗正文）到按鈕 ≥12；靠左的欄位標籤（標籤—控制項一組）只要不貼住（≥2）
				var prose := absf(tr.get_center().x - pr.get_center().x) <= 2.0
				var need_gap := BTN_TEXT_GAP if prose else LABEL_GAP
				if g < need_gap and g > -b.size.y:
					if _skip(out, p, "R9"):
						break
					_add(out, "fail", "R9", p["id"], "「%s」到下方按鈕只有 %.1fpx" % [str(t["s"]), g])
	# ── R8 多欄：按鈕不能跨進別欄（中心所在的欄以外的欄）──
	for a in d.get("aligns", []):
		if not a.has("cols"):
			continue
		for b in btns:
			var home := -1
			for ci in a["cols"].size():
				if (a["cols"][ci] as Rect2).has_point(b.get_center()):
					home = ci
			if home < 0:
				continue
			for ci in a["cols"].size():
				if ci != home and (a["cols"][ci] as Rect2).intersection(b).get_area() > 4.0:
					_add(out, "fail", "R8", a["id"], "按鈕 %s 跨進別欄 %s" % [str(b), str(a["cols"][ci])])
	# ── R5（V1.6 #4）宣告的同列卡片：每張卡的同一部件（圖示、標題、正文起點）上緣在同一條基準線 ──
	for a in d.get("aligns", []):
		if not a.has("cards"):
			continue
		var cs: Array = a["cards"]
		if cs.size() < 2:
			continue
		for k in (cs[0] as Array).size():
			var y0: float = ((cs[0] as Array)[k] as Rect2).position.y
			for c in cs:
				if k < (c as Array).size() and absf(((c as Array)[k] as Rect2).position.y - y0) > float(a.get("tol", TOL_CENTER)):
					_add(out, "fail", "R5", a["id"], "同列卡片第 %d 部件基準線不一致：%.1f／%.1f" % [k, y0, ((c as Array)[k] as Rect2).position.y])
					break
	# ── R10 宣告同一欄的元件共用中線 ──
	for a in d.get("aligns", []):
		if not a.has("rects"):
			continue
		var rs: Array = a["rects"]
		if rs.size() < 2:
			continue
		var c0: float = (rs[0] as Rect2).get_center().x
		for r in rs:
			if absf((r as Rect2).get_center().x - c0) > float(a.get("tol", TOL_CENTER)):
				_add(out, "fail", "R10", a["id"], "同欄中線不一致：%.1f／%.1f" % [c0, (r as Rect2).get_center().x])
				break
	# ── R6 面板留白（警告）：面板內最大的一段垂直空白（內容、緞帶、九宮格方塊之間，含到面板底）超過面板高 30% 且 >160px ──
	for p in panels:
		if _skip(out, p, "R6"):
			continue
		var pr: Rect2 = p["r"]
		var iv: Array = []
		for c in _contents(texts, btns):
			var cr: Rect2 = c["r"]
			if pr.has_point(cr.get_center()):
				iv.append([cr.position.y, cr.end.y])
		for bx in d.get("boxes", []):
			var br: Rect2 = bx
			if pr.has_point(br.get_center()) and br.size.y < pr.size.y * 0.9:
				iv.append([br.position.y, br.end.y])
		for rb in ribbons:
			if str(rb.get("host", "")) == str(p["id"]):
				iv.append([(rb["r"] as Rect2).position.y, float(rb["bottom"])])
		if iv.is_empty():
			continue
		iv.sort_custom(func(a, b): return a[0] < b[0])
		var reach: float = maxf(pr.position.y, iv[0][0])
		var big := 0.0
		for it in iv:
			big = maxf(big, it[0] - reach)
			reach = maxf(reach, it[1])
		big = maxf(big, pr.end.y - reach)
		if big > maxf(GAP_EMPTY, pr.size.y * FILL_WARN):
			_add(out, "warn", "R6", p["id"], "面板裡有一段 %dpx 的空白（面板高 %d）" % [int(big), int(pr.size.y)])
	# ── R7 緞帶下的第一段短字要置中（警告）──
	for rb in ribbons:
		var host = _panel_by_id(panels, str(rb.get("host", "")))
		if host == null or _skip(out, host, "R7"):
			continue
		var first = null
		for t in texts:
			var tr: Rect2 = t.get("gr", t["r"])
			if bool(t.get("btn", false)) or tr.position.y < float(rb["bottom"]) or not (host["r"] as Rect2).has_point(tr.get_center()):
				continue
			var in_ctrl := false   # 按鈕、分頁裡的字不是副標
			for b in btns:
				if b.grow(1.0).encloses(tr):
					in_ctrl = true
					break
			if in_ctrl:
				continue
			var body: Rect2 = rb.get("body", rb["r"])
			if tr.end.x <= body.position.x or tr.position.x >= body.end.x:
				continue   # 多欄畫面左欄的標籤不在緞帶正下方，不算「緞帶下的副標」
			if first == null or tr.position.y < (first.get("gr", first["r"]) as Rect2).position.y:
				first = t
		if first != null:
			var fr: Rect2 = first.get("gr", first["r"])
			var section := false   # 區段標題靠左、下面的內容從同一條左線開始：合法（記憶 layout-subtext-alignment）
			for t2 in texts:
				var r2: Rect2 = t2.get("gr", t2["r"])
				if t2 != first and r2.position.y > fr.position.y and r2.position.y - fr.end.y < 60.0 and absf(r2.position.x - fr.position.x) <= 1.0:
					section = true
					break
			# 只抓「看起來想置中卻偏了」：中心偏 2～60px；靠左的欄位標籤、分頁字離中線很遠，不算副標
			var off := absf(fr.get_center().x - float(rb["cx"]))
			if not section and fr.position.y - float(rb["bottom"]) < 48.0 and fr.size.x < (host["r"] as Rect2).size.x * 0.7 and off > 2.0 and off < 60.0:
				_add(out, "warn", "R7", rb["id"], "緞帶下的短字「%s」沒置中" % str(first["s"]))
	return out


static func _contents(texts: Array, btns: Array) -> Array:
	var cs: Array = []
	for t in texts:
		cs.append({"r": t.get("gr", t["r"]), "s": t["s"], "kind": "text"})
	for b in btns:
		cs.append({"r": b, "s": "按鈕%s" % str(b), "kind": "btn"})
	return cs


## 面板內最下面一排（同 y、同高、完整在面板裡、在面板下半部）的按鈕，依 x 排序
static func _bottom_row(pr: Rect2, btns: Array) -> Array:
	var inside: Array = []
	for b in btns:
		if pr.grow(1.0).encloses(b) and b.get_center().y > pr.get_center().y:
			inside.append(b)
	if inside.is_empty():
		return []
	var ymax := -INF
	for b in inside:
		ymax = maxf(ymax, b.position.y)
	var row: Array = []
	for b in inside:
		if absf(b.position.y - ymax) <= 1.0:
			row.append(b)
	row.sort_custom(func(a, b): return a.position.x < b.position.x)
	return row


## 格狀排列的最後一排：正上方那一排（同尺寸按鈕）比這排多，而且這排每一顆都對得到上一排同 x、同尺寸的一格
static func _is_grid_row(row: Array, pr: Rect2, btns: Array) -> bool:
	var b0: Rect2 = row[0]
	var above_y := -INF
	for b in btns:
		if b.position.y < b0.position.y - 1.0 and pr.grow(1.0).encloses(b) and absf(b.size.x - b0.size.x) <= 0.5 and absf(b.size.y - b0.size.y) <= 0.5:
			above_y = maxf(above_y, b.position.y)
	if above_y == -INF:
		return false
	var above: Array = []
	for b in btns:
		if absf(b.position.y - above_y) <= 1.0 and pr.grow(1.0).encloses(b) and absf(b.size.x - b0.size.x) <= 0.5 and absf(b.size.y - b0.size.y) <= 0.5:
			above.append(b)
	if above.size() <= row.size():
		return false
	for r in row:
		var hit := false
		for a in above:
			if absf(a.position.x - r.position.x) <= 0.5 and absf(a.size.x - r.size.x) <= 0.5:
				hit = true
				break
		if not hit:
			return false
	return true


static func _panel_by_id(panels: Array, id: String):
	for p in panels:
		if str(p["id"]) == id:
			return p
	return null


static func _skip(out: Dictionary, p, rule: String) -> bool:
	if p is Dictionary and (p.get("skip", {}) as Dictionary).has(rule):
		var key := "%s:%s" % [rule, str(p.get("id", ""))]
		if not out.has("_ex_" + key):
			out["_ex_" + key] = true
			out["exempt"].append({"rule": rule, "id": str(p.get("id", "")), "why": str(p["skip"][rule])})
		return true
	return false


static func _add(out: Dictionary, lvl: String, rule: String, id, msg: String) -> void:
	out[lvl].append({"type": rule, "id": str(id), "s": msg})
