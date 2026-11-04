extends RefCounted
## 第五輪 §4.3 圖表元件。只用常見、一眼看得懂的圖；數字直接標在圖上，不用圖例。
## 每個函式第一個參數 ui＝畫面節點（用它的 draw_*、_text、tz、cbm）。
## 藍＝我方、紅＝敵方；色盲模式時填色改高對比（亮青藍／亮橘紅）並加斜線紋。

const D = preload("res://scripts/core/unit_defs.gd")

const BLUE := Color("#4aa3ff")
const RED := Color("#ff5a5a")
const BLUE_CB := Color("#33ddff")
const RED_CB := Color("#ff9a1f")
const GRID := Color(1, 1, 1, 0.12)
const MUTED := Color(1, 1, 1, 0.6)

## 兵種定位色系（金幣條分段用，4 色系，不做 10 種彩虹）：近戰／遠程／突擊／支援
const ROLE_OF := [0, 0, 1, 2, 2, 0, 1, 3, 3, 0, 4, 4, 4, 0, 2, 0, 3, 1, 2, 0]   # 劍盾弓騎刺槍彈醫鼓狂
const ROLE_COL := [Color("#5b8def"), Color("#3fb6a8"), Color("#a46be0"), Color("#79c46a"), Color("#e0a03c")]

static func team_col(team: int, cb: bool) -> Color:
	if cb:
		return BLUE_CB if team == 0 else RED_CB
	return BLUE if team == 0 else RED

## 斜線紋（色盲模式時讓紅方的面積多一個不靠顏色的差異）
static func hatch(ui: CanvasItem, r: Rect2, c: Color) -> void:
	var step := 7.0
	var x := r.position.x - r.size.y
	while x < r.end.x:
		var a := Vector2(maxf(x, r.position.x), r.position.y + maxf(0.0, r.position.x - x))
		var b := Vector2(minf(x + r.size.y, r.end.x), r.position.y + minf(r.size.y, r.end.x - x))
		if a.x < b.x:
			ui.draw_line(Vector2(a.x, r.end.y - (a.y - r.position.y)), Vector2(b.x, r.end.y - (b.y - r.position.y)), c, 1.5)
		x += step

## 中線對比長條：rows＝[{label, b, r}]；兵種名在中間，藍往左、紅往右，數字標在條尾。
static func diverging(ui, rect: Rect2, rows: Array, mid_w := 110.0) -> void:
	var cb: bool = ui.cbm()
	var maxv := 1
	for row in rows:
		maxv = maxi(maxv, maxi(int(row["b"]), int(row["r"])))
	var n := maxi(1, rows.size())
	var rh := rect.size.y / n
	var half := (rect.size.x - mid_w) / 2.0
	var cx := rect.position.x + half
	var fs: int = ui.tz("S")
	for i in rows.size():
		var row: Dictionary = rows[i]
		var y := rect.position.y + i * rh
		var bh := minf(rh * 0.62, 22.0)
		var by := y + (rh - bh) / 2
		ui._text(Vector2(cx + mid_w / 2, y + (rh - fs * 1.1) / 2), str(row["label"]), fs, Color.WHITE, true, false, mid_w - 6)
		var lb := half * float(row["b"]) / maxv
		var lr := half * float(row["r"]) / maxv
		ui.draw_rect(Rect2(cx - lb, by, lb, bh), team_col(0, cb))
		var rr := Rect2(cx + mid_w, by, lr, bh)
		ui.draw_rect(rr, team_col(1, cb))
		if cb:
			hatch(ui, rr, Color(0, 0, 0, 0.35))
		var vb := str(int(row["b"]))
		var vr := str(int(row["r"]))
		var wb: float = ui._width(vb, fs)
		ui._text(Vector2(maxf(rect.position.x, cx - lb - wb - 6), y + (rh - fs * 1.1) / 2), vb, fs, MUTED)
		ui._text(Vector2(minf(rect.end.x - ui._width(vr, fs), cx + mid_w + lr + 6), y + (rh - fs * 1.1) / 2), vr, fs, MUTED)

## 排名條：values＝這個指標在可比兵種裡的值（Dictionary type→值）；me＝這一種。
## 灰點＝其他兵種的位置，亮點＝這一種；右邊標「值・第 N 高」。只傳可比的兵種（第五輪 §4.3）。
static func rank_bar(ui, rect: Rect2, values: Dictionary, me: int, label: String, value_text: String, accent := Color("#ffd166")) -> void:
	var fs: int = ui.tz("S")
	ui._text(rect.position, label, fs, MUTED)
	var lx := maxf(rect.position.x + rect.size.x * 0.22, rect.position.x + ui._width(label, fs) + 10)   # 標籤長（英文、大字）就往右讓
	if values.size() <= 1:
		# 不排名的指標（價格、補血、光環）：只寫數值，不畫條（Antigravity：灰條看起來像最低分）
		ui._text(Vector2(lx, rect.position.y), value_text, fs, Color.WHITE, false, true, rect.end.x - lx)
		return
	# 數值文字放得下為優先：條的寬度＝剩下的空間（30%～最少 50px）
	var rank_guess := 1
	for t in values:
		if t != me and float(values[t]) > float(values.get(me, 0)):
			rank_guess += 1
	var rt0: String = value_text if values.size() <= 1 else load("res://scripts/game/strings.gd").t("rank_nth", [value_text, rank_guess])
	var lw := clampf(rect.end.x - lx - ui._width(rt0, fs, true) - 24, 40.0, rect.size.x * 0.30)
	var cy := rect.position.y + fs * 0.75
	ui.draw_line(Vector2(lx, cy), Vector2(lx + lw, cy), GRID, 4.0)
	var mx := 0.0
	var mn := 1e18
	for t in values:
		mx = maxf(mx, float(values[t]))
		mn = minf(mn, float(values[t]))
	var span := maxf(1e-6, mx - mn)
	var rank := 1
	for t in values:
		if t != me and float(values[t]) > float(values.get(me, 0)):
			rank += 1
		var px := lx + lw * (float(values[t]) - mn) / span
		if t != me:
			ui.draw_circle(Vector2(px, cy), 4.0, Color(1, 1, 1, 0.35))
	if values.has(me):
		var pm := lx + lw * (float(values[me]) - mn) / span
		ui.draw_line(Vector2(lx, cy), Vector2(pm, cy), accent, 4.0)
		ui.draw_circle(Vector2(pm, cy), 7.0, accent)
	var rt: String = value_text if values.size() <= 1 else load("res://scripts/game/strings.gd").t("rank_nth", [value_text, rank])
	ui._text(Vector2(lx + lw + 12, rect.position.y), rt, fs, Color.WHITE, false, true, rect.end.x - (lx + lw + 12))

## 戰力走勢：log2＝每 tick [藍戰力, 紅戰力] 交錯；b0／b1＝兩邊預算。
## 值＝藍比例 ÷（藍比例＋紅比例），以 50% 為界上藍下紅；雙方都 0 時沿用上一點；最後一段做平滑（第五輪 §4.3）。
## marks＝[{t, label}] 最多畫 3 個，標籤不重疊。回傳每個取樣點的 y（測試用）。
static func momentum(ui, rect: Rect2, log2: PackedInt64Array, b0: int, b1: int, marks: Array, total_ticks := 0) -> Array:
	var cb: bool = ui.cbm()
	var n := log2.size() / 2
	var mid := rect.position.y + rect.size.y / 2
	ui.draw_rect(rect, Color(0, 0, 0, 0.25))
	ui.draw_line(Vector2(rect.position.x, mid), Vector2(rect.end.x, mid), Color(1, 1, 1, 0.35), 1.0)
	if n <= 1:
		return []
	var span := maxi(n, total_ticks)
	var cols := int(minf(rect.size.x, 240.0))
	var ys: Array = []
	var last := 0.5
	for k in cols + 1:
		var t := mini(n - 1, int(float(k) / cols * (span - 1)))
		if float(k) / cols * (span - 1) > n - 1:
			break
		var p0 := float(log2[2 * t]) / maxf(1.0, b0)
		var p1 := float(log2[2 * t + 1]) / maxf(1.0, b1)
		var v := last
		if p0 + p1 > 0.0:
			v = p0 / (p0 + p1)
			# 雙方都快打光時分母很小，曲線會劇烈跳：剩不到 6% 時向上一點靠攏
			if p0 + p1 < 60.0:
				v = lerpf(last, v, 0.35)
		last = v
		ys.append(v)
	var dx := rect.size.x / cols
	for k in ys.size():
		var x := rect.position.x + k * dx
		var y: float = rect.end.y - rect.size.y * ys[k]
		if y < mid:
			ui.draw_rect(Rect2(x, y, dx + 0.5, mid - y), team_col(0, cb) * Color(1, 1, 1, 0.85))
		else:
			var rr := Rect2(x, mid, dx + 0.5, y - mid)
			ui.draw_rect(rr, team_col(1, cb) * Color(1, 1, 1, 0.85))
	if cb:
		# 色盲：紅方（中線以下）的面積加斜線紋，不只靠顏色分辨（Codex 實作第 1 輪：原本是空的）
		# 整個紅方面積都畫斜線：每條 45° 線從中線往下，只畫在該欄的紅色高度內
		var step := 7.0
		var x0 := rect.position.x - rect.size.y
		while x0 < rect.end.x:
			for k in ys.size():
				if ys[k] >= 0.5:
					continue
				var xc := rect.position.x + k * dx
				var yb: float = rect.end.y - rect.size.y * ys[k]
				# 這條斜線在 x＝xc 時的 y：y = mid + (xc - x0)
				var yl := mid + (xc - x0)
				if yl >= mid and yl <= yb:
					ui.draw_rect(Rect2(xc, yl, maxf(1.0, dx), 1.5), Color(0, 0, 0, 0.45))
			x0 += step
	# 標記：最多 3 個，依時間排，標籤往左右讓開
	var fs: int = ui.tz("C")
	var used: Array = []
	var shown := 0
	for m in marks:
		if shown >= 3:
			break
		var x := rect.position.x + rect.size.x * clampf(float(m["t"]) / maxf(1.0, span - 1), 0.0, 1.0)
		var lab := str(m["label"])
		var w: float = ui._width(lab, fs) + 8
		var lx := clampf(x - w / 2, rect.position.x, rect.end.x - w)
		var row := 0
		for u in used:
			if absf(u - lx) < w + 6:
				row += 1
		if row > 1:
			continue   # 最多兩排標籤（上方只留了兩排空間）
		used.append(lx)
		ui.draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), Color("#ffd166"), 1.5)
		ui._text(Vector2(lx, rect.position.y - fs * 1.35 * (row + 1)), lab, fs, Color("#ffd166"))
		shown += 1
	return ys

## 金幣條：連續條，已擺的兵依定位色系分段；右側大字「花了／上限 金」。star＝三星金額刻度（-1＝不畫）。
static func gold_bar(ui, rect: Rect2, units: Array, budget: int, star := -1) -> void:
	ui.draw_rect(rect, Color(1, 1, 1, 0.10))
	var x := rect.position.x
	var spent := 0
	for u in units:
		var c: int = D.cost(int(u["type"]))
		var w := rect.size.x * float(c) / maxf(1.0, budget)
		ui.draw_rect(Rect2(x, rect.position.y, maxf(1.0, w - 1.0), rect.size.y), ROLE_COL[ROLE_OF[int(u["type"])]])
		x += w
		spent += c
	if star >= 0 and star < budget:
		var sx := rect.position.x + rect.size.x * float(star) / budget
		var over := spent > star
		ui.draw_line(Vector2(sx, rect.position.y - 4), Vector2(sx, rect.end.y + 4), Color.RED if over else Color("#ffd166"), 2.5)
	ui.draw_rect(rect, Color(1, 1, 1, 0.35), false, 1.0)
