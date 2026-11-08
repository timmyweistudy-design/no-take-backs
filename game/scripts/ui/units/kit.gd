extends RefCounted
## 由 art.gd 拆出（V9 P1，行為不變）
## 程式繪製的 Q 版角色與戰場（優化方案 G：美術先用程式能做到的先做）。
## 全部是向量圖形＋抗鋸齒，沒有外部角色素材。辨識靠三層視覺錨點：腳底隊伍標記、上半身／武器剪影、動態特效。

const D = preload("res://scripts/core/unit_defs.gd")
const Gait = preload("res://scripts/ui/units/gait.gd")

const OUT := Color("#2b2236")   # V1.2 D1：內線色（較淡）；外輪廓改在圖集烘焙時用隊伍墨色加粗（shaders/unit_bake.gdshader）
const INNER_W := 1.2              # V1.2 D1：部件內線寬（原 1.6／3.2／+3）
const SKIN := Color("#ffe1c4")
const BLUSH := Color(1.0, 0.55, 0.6, 0.55)
const STEEL := Color("#c9d3e3")
const STEEL_D := Color("#8c97ab")
const WOOD := Color("#b7814e")
const GOLD := Color("#ffd166")

# 隊伍色（一般／色盲高對比）
## 呼叫端目前的畫布轉換（鏡頭）。角色繪製要「疊加」在它上面，不能覆蓋掉（手感輪 2 抓到的錯位 bug）。
static var base := Transform2D.IDENTITY
static var _xf := Transform2D.IDENTITY   # 目前角色的畫布轉換（腳底座標），上半身另外疊 Gait.body_xf
static var _team_now := 0   # 目前在畫哪一隊（分隊小披風用）

# V1.3 A1b：轉身中間影格（只在烘焙轉身頁時用；平常 turn_c＝1，下面的函式都不動作，畫出來和以前一模一樣）。
# 不是整張等比夾扁：身體依兵種只縮一部分（圓的頭、史萊姆不縮），往前伸的武器跟著透視縮短，
# 近側（z＞0，畫在身體前面）的武器／盾往後移、遠側的往前移，前後遮擋關係就會改變，看起來是轉身不是紙片翻面。
static var turn_c := 1.0     # cos θ：1＝正側面，越小越轉向鏡頭
static var turn_s := 0.0     # sin θ
static var _xf0 := Transform2D.IDENTITY   # 轉身時沒縮過的角色轉換
static var _b_now := Transform2D.IDENTITY # 目前的上半身轉換（_push_body 設）
static var _cur_xf := Transform2D.IDENTITY # 目前畫布轉換（部件之間切換用；_eyes 畫完要還原成這個）
const TURN_FWD := {3: 0.45, 13: 0.0, 19: 0.3, 10: 0.0, 11: 0.3, 12: 0.45, 14: 0.2, 16: 0.0, 18: 0.3, 20: 0.0, 21: 0.3}   # 騎兵的馬最窄約 0.58；V1.3.1：羊長身、寶箱方體會縮，孢子菇、沙漏、小史萊姆不縮
static var baking := false
# V1.3.1 P1：待機小動作（眼睛往後看）、小動作中不擺怒臉、受擊帽子彈起
static var look := 0.0
static var calm := false
static var hat_pop := 0.0
static func _hat_on(ci: CanvasItem) -> void:
	if hat_pop > 0.0:
		ci.draw_set_transform_matrix(_cur_xf * Transform2D(0.0, Vector2.ONE, 0.0, Vector2(0.0, -5.0 * hat_pop)))   # 帽子騰空 5px（7px 會像禿頭高額頭，Antigravity v131-impl2）
static func _hat_off(ci: CanvasItem) -> void:
	if hat_pop > 0.0:
		ci.draw_set_transform_matrix(_cur_xf)
# V1.3.1 P0-6：錨點紀錄（只有工具 anim_sheet 打開）。烘轉身頁時記下臉中心與武器線段（格子像素座標），檢查武器有沒有穿過臉。
static var anchor_on := false
static var anchor_key := ""
static var anchor_log := {}
static var _cur_weapon := false
static func _anchor(kind: String, pts: Array) -> void:
	if anchor_key == "":
		return   # 只記轉身頁（其他頁不設鍵）
	if not anchor_log.has(anchor_key):
		anchor_log[anchor_key] = {"face": [], "weapon": []}
	var out: Array = []
	for q in pts:
		out.append(_cur_xf * q)
	anchor_log[anchor_key][kind].append(out)   # V1.3.1：烘焙中（史萊姆高光改在貼圖後依世界方向畫）   # 身體跟著縮的比例（沒列＝0.4）：騎兵的馬是長的、史萊姆是圓的

static func turn_body_w(type: int) -> float:
	return lerpf(1.0, turn_c, float(TURN_FWD.get(type, 0.4)))

## 接下來畫的部件：z＝側向深度（＋近側），fwd＝沿前後方向的長度比例（1＝整個跟著透視縮短，0＝不縮）。
static func _part(ci: CanvasItem, z: float, fwd: float) -> void:
	if turn_c >= 1.0:
		return
	# 往前伸的武器最多縮到一半（Antigravity v131-impl1：cos 0.3 時刀、吸嘴、手臂短到看不見）
	var sxp := lerpf(1.0, turn_c, fwd)
	if fwd >= 0.5:
		sxp = maxf(sxp, 0.5)
	_cur_xf = _xf0 * _b_now * Transform2D(0.0, Vector2(sxp, 1.0), 0.0, Vector2(-z * turn_s, 0.0))
	_cur_weapon = anchor_on and fwd >= 0.5 and z != 0.0
	ci.draw_set_transform_matrix(_cur_xf)

## V1.3.1：圓的部件（羊頭、幽靈臉、骷髏頭）只移到轉過去的位置，不壓扁。x0＝部件中心的 x。
static func _part_at(ci: CanvasItem, x0: float) -> void:
	if turn_c >= 1.0:
		return
	_cur_xf = _xf0 * _b_now * Transform2D(0.0, Vector2.ONE, 0.0, Vector2(x0 * (turn_c - 1.0), 0.0))
	_cur_weapon = false
	ci.draw_set_transform_matrix(_cur_xf)

## 回到身體的轉換。
static func _part_end(ci: CanvasItem) -> void:
	if turn_c >= 1.0:
		return
	_cur_xf = _xf * _b_now
	_cur_weapon = false
	ci.draw_set_transform_matrix(_cur_xf)

const TEAM := [[Color("#45acff"), Color("#d93a44")], [Color("#2f80ff"), Color("#ffb000")]]   # 第七輪：紅壓暗，灰階下敵我也分得開（小樣通過條件 ②）

# ── 三段式攻擊（第二輪方案 R5）──
# atk（0～1）＝一次攻擊動作的進度：0～ATK_WINDUP 前搖、ATK_WINDUP～ATK_STRIKE 揮擊（命中就在 ATK_WINDUP 那一刻）、之後後搖。
const ATK_WINDUP := 0.3125
const ATK_STRIKE := 0.53125
const LEAN_BACK := 0.2618     # 前搖身體後傾 15°（第三輪 R1，原 12°）
const LEAN_FWD := 0.3840      # 揮擊前撲 22°（第三輪 R1，原 18°）

# 臉部疊加（表情）：同一份畫法同時給直接繪製與精靈圖快取用，兩條路看起來一樣
const M_HURT := 1             # 受擊／暈眩：>< 眼
const M_SPARKLE := 2          # 騎兵衝鋒蓄滿：亮晶晶眼＋槍尖金光
const M_BROWS := 4            # 狂熱：眉毛內傾
const M_HOOD := 8             # 刺客潛行：帽簷壓低、黃眼每 0.4 秒眨一次
const M_BRACE := 16           # 盾兵頂住：盾放大 1.35 倍
const M_HAPPY := 32           # V1.3.1：勝利歡呼 ^ ^ 眼
const M_SURPRISE := 64        # V1.3.1：擺陣被抓起來，圓眼＋小 o 嘴
const M_GRIM := 128           # V1.3.1：大落後，眉頭下壓、嘴角往下（不抖、不畫汗，避免像暈眩）

# 第八輪：通用表情疊加用的眼睛位置（其他新兵的臉不適合疊）
const FEATURE_EYES := {10: Vector2(1.5, -13), 13: Vector2(3, -17), 18: Vector2(3, -33), 19: Vector2(1, -31), 20: Vector2(2, -11),
	11: Vector2(16.5, -23), 14: Vector2(2.0, -40), 17: Vector2(5.5, -36), 21: Vector2(0.5, -33)}   # V1.3.1：羊、幽靈、骷髏法師、骷髏也吃得到表情（Codex v131-impl1）


static func team_color(team: int, cb := false) -> Color:
	return TEAM[1 if cb else 0][team]


static func _smooth(u: float) -> float:
	return u * u * (3.0 - 2.0 * u)


static func _star(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.28, -r * 0.28), c + Vector2(r, 0), c + Vector2(r * 0.28, r * 0.28),
		c + Vector2(0, r), c + Vector2(-r * 0.28, r * 0.28), c + Vector2(-r, 0), c + Vector2(-r * 0.28, -r * 0.28)]), col)


static func _c(ci: CanvasItem, c: Vector2, r: float, col: Color, a: float, outline := true) -> void:
	if outline:
		ci.draw_circle(c, r + INNER_W, Color(OUT, a), true, -1.0, true)
	ci.draw_circle(c, r, Color(col, col.a * a), true, -1.0, true)


static func _poly(ci: CanvasItem, pts: PackedVector2Array, col: Color, a: float, outline := true) -> void:
	if _cur_weapon:
		var ar: Array = []
		for k in pts.size():
			ar.append(pts[k])
		ar.append(pts[0])
		_anchor("weapon", ar)
	if outline:
		var closed := pts.duplicate()
		closed.append(pts[0])
		ci.draw_polyline(closed, Color(OUT, a), INNER_W * 2.0, true)
	ci.draw_colored_polygon(pts, Color(col, col.a * a))


static func _line(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, w: float, al: float) -> void:
	if _cur_weapon:
		_anchor("weapon", [a, b])
	ci.draw_line(a, b, Color(OUT, al), w + INNER_W * 1.9, true)
	ci.draw_line(a, b, Color(col, col.a * al), w, true)


static func _eyes(ci: CanvasItem, c: Vector2, a: float, t: float, angry := false) -> void:
	var blink := 1.0 if fmod(t + c.x * 0.13, 3.7) > 0.12 else 0.15
	if look != 0.0:
		c.x -= look * 3.0   # V1.3.1：待機小動作回頭看
	if turn_c < 1.0:
		# V1.3 A1b：轉向鏡頭時臉往中間移，眼睛不跟著身體壓扁（保持圓的）
		ci.draw_set_transform_matrix(_xf0 * _b_now)
		c = Vector2(c.x * turn_c, c.y)
		if anchor_on:
			var keep := _cur_xf
			_cur_xf = _xf0 * _b_now
			_anchor("face", [c])
			_cur_xf = keep
		_eyes_draw(ci, c, a, blink, angry)
		ci.draw_set_transform_matrix(_cur_xf)   # 還原成呼叫前的部件轉換（頭盔接著畫，Codex v130-impl1）
		return
	_eyes_draw(ci, c, a, blink, angry)

static func _eyes_draw(ci: CanvasItem, c: Vector2, a: float, blink: float, angry: bool) -> void:
	for dx in [-3.0, 4.0]:
		var e := c + Vector2(dx, 0)
		ci.draw_circle(e, 2.6, Color(OUT, a), true, -1.0, true)
		if blink > 0.5:
			ci.draw_circle(e + Vector2(0.7, -0.8), 0.9, Color(1, 1, 1, a), true, -1.0, true)
		else:
			ci.draw_rect(Rect2(e - Vector2(2.6, 0.6), Vector2(5.2, 1.2)), Color(SKIN, a))
	ci.draw_circle(c + Vector2(-6.5, 4.0), 2.4, Color(BLUSH, BLUSH.a * a), true, -1.0, true)
	ci.draw_circle(c + Vector2(7.5, 4.0), 2.4, Color(BLUSH, BLUSH.a * a), true, -1.0, true)
	if angry:
		# 攻擊：眉毛內傾＋嘴巴張開
		ci.draw_line(c + Vector2(-5.2, -4.4), c + Vector2(-1.0, -3.2), Color(OUT, a), 1.5, true)
		ci.draw_line(c + Vector2(6.2, -4.4), c + Vector2(2.0, -3.2), Color(OUT, a), 1.5, true)
		ci.draw_circle(c + Vector2(0.5, 4.6), 1.7, Color(OUT, a), true, -1.0, true)
		ci.draw_circle(c + Vector2(0.5, 5.2), 0.9, Color("#e05a6a", a), true, -1.0, true)
	else:
		ci.draw_arc(c + Vector2(0.5, 4.2), 1.8, 0.2, PI - 0.2, 6, Color(OUT, a), 1.2, true)


static func _ell(c: Vector2, rx: float, ry: float, a0 := 0.0, a1 := TAU, n := 20) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var ang := a0 + (a1 - a0) * i / float(n - (0 if is_equal_approx(a1 - a0, TAU) else 1))
		pts.append(c + Vector2(cos(ang) * rx, sin(ang) * ry))
	return pts

## 上半身：腳畫完後呼叫，之後畫的東西跟著起伏與傾身。
## 第十輪 F3：攻擊時整隻壓扁、前衝。腳底為原點，所以不會和腿分離。up＝彈起（往上拉長）。
static func _atk_xf(b: Transform2D, w: float, sq: float, lunge := 0.0, up := false) -> Transform2D:
	if w == 0.0:
		return b
	var sx := 1.0
	var sy := 1.0
	var dx := 0.0
	if w < 0.0:
		sx = 1.0 - w * sq
		sy = 1.0 + w * sq
		dx = w * lunge * 0.3
	elif up:
		sx = 1.0 - w * sq * 0.4
		sy = 1.0 + w * sq * 0.6
	else:
		sx = 1.0 + w * sq * 0.6
		sy = 1.0 - w * sq * 0.3
		dx = w * lunge
	return Transform2D(0.0, Vector2(sx, sy), 0.0, Vector2(dx, 0.0)) * b

static func _push_body(ci: CanvasItem, b: Transform2D) -> void:
	_b_now = b
	_cur_xf = _xf * b
	ci.draw_set_transform_matrix(_xf * b)
