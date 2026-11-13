extends "res://scripts/ui/ui_base.gd"
## 由 battle_view.gd 拆出（V9 P1，行為不變）
const F8 = preload("res://scripts/core/fantasy_defs.gd")
const EV = preload("res://scripts/core/events.gd")
## 戰場、單位、特效、戰鬥 HUD、最後時刻鏡頭（演出層：不影響戰鬥結果）。


## 第七輪 M3：跳到結果不再卡畫面。正常畫面分批算（每幀限時）；headless 與截圖走同步。
var skip_busy := false
var pre_thread: Thread = null   # 第十輪 I4：重播先算全長放背景
var ai_thread: Thread = null    # 第十輪 I4：困難 AI 放背景
var last_cmds: Array = []       # 第十二輪：上一場官方對局的技能施放紀錄（重播、覆盤、代碼用）
var pre_old: Array = []         # 返回時還沒算完的舊工作：不等它，算完再收（Codex v10-r1 #3）

const HUD_LEFT_END := 240.0     # 左上比分文字最寬到這裡

## 戰報列（第七輪 E1）：承接混戰時的技能跳字。同隊同兵種同技能 2 秒內合併。
var report_log: Array = []
const REPORT_CAP := 6

## 開戰號角（第七輪 A10）：正式對局開戰前留 1 秒，陣線亮一下。只是畫面緩衝，模擬還沒開始；簡化特效時略過。
var start_hold := 0.0

## 跳字（第三輪 V1）：
## ・合併：同一種技能、同一區（48×32px）0.35 秒內合併成「背刺 ×3（120）」，數字變大彈一下
## ・分級：TEXT_TIER 2＝關鍵（衝鋒、背刺、頂住），1＝一般技能；關鍵的不會因為上限被丟
## ・上限：戰場上同時最多 TEXT_CAP 個，超過時丟最舊的一般跳字
## ・避讓：每幀用「含描邊的實際外框」排版（_layout_texts）：關鍵、新的先佔位，其他重疊就往上推
const TEXT_CAP := 12
const TEXT_TIER := {"charge": 2, "backstab": 2, "braced": 2, "anticav": 1, "counter": 1, "pike_brace": 2, "breach": 1, "heal": 0}
const TEXT_CELL := Vector2(48, 32)
var text_dropped := 0          # 被上限丟掉的跳字數（測試對帳用）

var text_key_in := 0           # 進來的關鍵跳字事件數（合併也算）
var text_key_shown := 0        # 關鍵跳字實際顯示（新增或併進既有的）的次數

## 焦點＝最近 0.8 秒內出手或受擊的單位的中心（Antigravity S2 #2：原本用鏡頭中心，旁觀的弓兵不會淡化）
var action_focus := Vector2.ZERO
## 特效預算（第三輪 V3）：戰場特效（不含跳字）同時最多 FX_CAP 個。超過時先丟優先權低、最舊的；關鍵（2）不丟。
const FX_CAP := 40
const FX_PRIO := {"dust": 0, "slash": 1, "arrow": 1, "ripple": 1, "aim": 1, "hide": 1, "trip": 2, "shard": 2, "flash": 2, "vslash": 2,
	"taunt": 2, "bang": 2, "puff": 1, "hex": 2}
const OVERHEAD_CAP := {"note": 4, "bang": 6, "inkring": 4}
const FX_TEXT_CAP := 12   # V1.3：戰場跳字上限（_fx_text 直接加的那一路；TEXT_CAP 是合併跳字那一路）
var fx_dropped := 0

var fx_deduped := 0


## 最後時刻（優化方案 F1）：雙方剩餘戰力都 ≤30% 且差距 ≤15%；或雙方各剩 ≤3 隻且差距 ≤15%。
## 最後時刻的條件（view 與 sim 都有 budget／power／alive_count，重播跳轉時用同一個條件重算，Codex S7 #2）。
static func clutch_cond(s) -> bool:
	# 第五輪：各自用自己的預算算比例（舊判定時兩邊預算相同，和 1.3.0 一樣）
	var p0: float = s.power(0) * 100.0 / (s.budget_of(0) * 1000.0)
	var p1: float = s.power(1) * 100.0 / (s.budget_of(1) * 1000.0)
	return absf(p0 - p1) <= 15.0 and ((p0 <= 30.0 and p1 <= 30.0) or (s.alive_count(0) <= 3 and s.alive_count(1) <= 3))


## 畫面上現在播到第幾 tick（含小數，插值用）。
func _disp_tick() -> float:
	if view == null:
		return 0.0
	if state != St.BATTLE:
		return float(view.tick)
	return view.tick + clampf(accum / 0.05, 0.0, 8.0 if view.finished else 1.0)



## 這一刻要演哪一次命中（Codex R5 #2）：取前搖已開始的最近一次；但前一次的揮擊還沒做完就先讓它做完（揮擊優先、後搖可被截斷）。
static func pick_hit(hits: Array, disp: float, type: int, wind := -1.0) -> int:
	var tm := atk_timing(type, wind)
	var w: float = tm[1]
	var strike_end: float = w + tm[2]
	var cur := -1
	for h in hits:
		if float(h) - w <= disp:
			if cur >= 0 and disp - (float(cur) - w) < strike_end:
				break   # 前一次還在揮擊，不換
			cur = h
	return cur



## 三段式攻擊進度（R5）：前搖固定是命中前 DELAY 個 tick，揮擊與後搖依攻擊間隔壓縮（攻速快的兵動作也快，不會疊在一起）。
## 回傳 Art.unit 的 atk 參數：0＝沒在攻擊；0～0.3125 前搖、0.3125～0.53125 揮擊（命中在 0.3125）、之後後搖到 1。
## 一次攻擊動作的時長（tick）：前搖固定 DELAY，揮擊 0.22×總長；atk_progress 與 pick_hit 共用（Codex S4 #1）。
## V1.5：遠程的飛行時間（tick）。0＝近戰或不畫飛行物（孢子菇是毒圈、巫毒是連線，各自另外演）。
## 實際飛行還會被緩衝長度限制：飛行＋前搖不能超過展示緩衝（手動軍令局緩衝只有 2，就幾乎直接命中）。
const PROJ_FLY := {2: 5, 6: 6, 17: 5, 7: 3}   # 弓箭手、投彈兵、骷髏法師、醫者（補血）

static func proj_fly(type: int) -> int:
	return int(PROJ_FLY.get(type, 0))

## V1.5：這一刻該演哪一次攻擊。回傳 [出手 tick, 命中 tick, 飛行進度 -1／0～1]；沒有就 [-1, -1, -1]。
## 遠程的出手比命中早 fly 個 tick（fly＝飛行時間，受緩衝長度限制）；飛行進度在出手～命中之間由 0 走到 1。
## only：哪些命中 tick 是飛行物（null＝全部）。投彈兵貼身敲人這種近身命中不提早出手、不畫炸彈（Codex v150-i1 #3）。
static func proj_phase(hits: Array, disp: float, type: int, delay: int, only = null) -> Array:
	# 回傳 [出手 tick, 命中 tick, 飛行進度, 動作起點 tick, 前搖長度]
	# V1.5.1：每一發各自決定前搖——有飛行物的那發用局內前搖（手動軍令局 1 tick），近身的（投彈兵敲擊）照舊 2 tick（Codex v151-i1 #7）
	var wd := proj_wind(type, delay)
	var fly: int = maxi(0, mini(proj_fly(type), delay - wd))
	var tm := atk_timing(type)
	var st: float = tm[2]
	var es: Array = []   # [動作起點, 出手, 命中, 前搖]
	for x in hits:
		var shift: bool = fly > 0 and (only == null or (only as Dictionary).has(int(x)))
		if shift:
			es.append([int(x) - fly - wd, int(x) - fly, int(x), wd])
		else:
			es.append([int(x) - ViewBuffer.DELAY, int(x), int(x), ViewBuffer.DELAY])
	es.sort_custom(func(a, b): return a[0] < b[0])
	var cur: Array = []
	for e in es:
		if float(e[0]) <= disp:
			if not cur.is_empty() and disp - float(cur[0]) < float(cur[3]) + st:
				break   # 前一次還在揮擊，不換
			cur = e
	if cur.is_empty():
		return [-1, -1, -1.0, -1, ViewBuffer.DELAY]
	var hr: int = cur[1]
	var h: int = cur[2]
	var k := -1.0
	if h > hr and disp >= float(hr) and disp <= float(h):
		k = clampf((disp - float(hr)) / float(h - hr), 0.0, 1.0)
	return [hr, h, k, cur[0], cur[3]]

static func atk_timing(type: int, wind := -1.0) -> Array:
	var period := float(D.stat(type)["cd"])   # cd 的單位是 tick（模擬每次出手加 cd×4、每 tick 扣 4）
	var tot := clampf(period, 4.0, 6.4)
	return [tot, float(ViewBuffer.DELAY) if wind < 0.0 else wind, 0.22 * tot]

## V1.5.1 B1：這一局遠程的前搖 tick。手動軍令局緩衝只有 2 tick：有飛行物的遠程前搖縮成 1 tick、讓出 1 tick 給飛行（命中 tick 不變）。
static func proj_wind(type: int, delay: int) -> int:
	if proj_fly(type) > 0 and delay <= ViewBuffer.DELAY:
		return 1
	return ViewBuffer.DELAY


static func atk_progress(dt: float, type: int, wind := -1.0) -> float:
	var tm := atk_timing(type, wind)
	var tot: float = tm[0]
	var w: float = tm[1]
	var st: float = tm[2]
	var rc := tot - w - st
	if dt < 0.0 or dt >= tot:
		return 0.0
	var a: float
	if dt < w:
		a = Art.ATK_WINDUP * dt / w
	elif dt < w + st:
		a = Art.ATK_WINDUP + (Art.ATK_STRIKE - Art.ATK_WINDUP) * (dt - w) / st
	else:
		a = Art.ATK_STRIKE + (1.0 - Art.ATK_STRIKE) * (dt - w - st) / rc
	return maxf(a, 0.001)



static func _smoothstep01(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)



## 小十字（補血）。
func _cross(c: Vector2, r: float, col: Color) -> void:
	draw_rect(Rect2(c - Vector2(r * 0.32, r), Vector2(r * 0.64, r * 2.0)), col)
	draw_rect(Rect2(c - Vector2(r, r * 0.32), Vector2(r * 2.0, r * 0.64)), col)



## 跳字的外框（含描邊與底襯，戰場座標）。
func _text_rect(f: Dictionary, at: Vector2) -> Rect2:
	var sz := int(ts(int(f["size"])) * (1.0 + float(f.get("pop", 0.0)) * 1.4))   # 含合併時的彈跳放大（Codex S1 #4）
	var w := font_bold.get_string_size(f["s"], HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x + 14.0 if font_bold != null else float(f["s"].length() * sz)
	var h := sz * 1.3 + 6.0
	return Rect2(at.x - w / 2.0, at.y - 3.0, w, h)


static func _text_alpha(f: Dictionary) -> float:
	var k: float = f["t"] / f["dur"]
	return 1.0 - k * k


static func _overlap(a: Rect2, b: Rect2) -> float:
	var x := a.intersection(b)
	if not x.has_area():
		return 0.0
	return x.get_area() / maxf(1.0, minf(a.get_area(), b.get_area()))



func _upos(u) -> Vector2:
	var cur := Vector2(u.x, u.y)
	var a := clampf(accum / 0.05, 0.0, 1.0) if state == St.BATTLE else 1.0
	var p: Vector2 = prev_pos.get(u.id, cur).lerp(cur, a)
	# 純畫面錯開（手感輪 2）：依編號固定偏移 ±4px，讓疊在一起的兵不會完全重合；戰鬥計算不受影響
	var j := Vector2(float((u.id * 37) % 9 - 4), float((u.id * 53) % 7 - 3))
	return ORIGIN + p * CS / 1000.0 + j



## 戰場色調：依模式固定（使用者決定：一般晨曦、殘局黃昏、遠征月夜）。
func _tone() -> Color:
	if state == St.TITLE:
		return Color(1.0, 0.72, 0.45, 0.07)
	if rules != null and rules.time_of != 0:
		return Color(0.95, 0.42, 0.3, 0.16) if rules.time_of == 1 else Color(0.12, 0.16, 0.42, 0.30)
	var mt := _mode_tone()
	if mt.a > 0.0:
		return mt
	match mode:
		Mode.PUZZLE:
			return Color(0.95, 0.42, 0.3, 0.16)    # 黃昏
		Mode.GAUNTLET:
			return Color(0.12, 0.16, 0.42, 0.30)   # 月夜
	return Color(1.0, 0.72, 0.45, 0.07)            # 晨曦



## 1.3.0 §4：時刻由模式決定（不讀真實時鐘，截圖可重現）。只看「這一場」的正式對局上下文：
## 重播、看代碼、觀戰不套（Codex cat03 #1：同一個代碼不會因為前一場不同而變色）；戰役優先於每日（每日的規格可能殘留）。
func _mode_tone() -> Color:
	if mode != Mode.VS_AI or play_kind != "official":
		return Color(0, 0, 0, 0)
	var camp: String = str(get("camp_id")) if get("camp_id") != null else ""
	if camp != "":
		var ch := int(camp.substr(1, 1)) if camp.length() > 1 else 1   # 戰役依章：1 晨、2 午、3 黃昏、4 夜、5 燈下
		return [Color(1.0, 0.72, 0.45, 0.07), Color(1.0, 0.95, 0.85, 0.03), Color(0.95, 0.42, 0.3, 0.16), Color(0.12, 0.16, 0.42, 0.30), Color(1.0, 0.62, 0.25, 0.18)][clampi(ch - 1, 0, 4)]
	var dsp = get("daily_spec")
	if dsp is Dictionary and not (dsp as Dictionary).is_empty():
		return Color(0.7, 0.85, 1.0, 0.07)         # 每日挑戰：清晨（偏藍的淡光）
	return Color(0, 0, 0, 0)

## 圖示膠囊標籤（R6）：kind＝"coin"／"unit"／"team"。回傳寬度。
func _pill(p: Vector2, kind: String, label: String, col: Color, size := 16, cap := 99) -> float:
	var fsz := tcap(ts(size), cap)
	var tw := font_bold.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
	var w := tw + 40.0
	var h := fsz + 10.0
	draw_rect(Rect2(p, Vector2(w, h)), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(p, Vector2(w, h)), Color(col, 0.6), false, 1.5)
	var ic := p + Vector2(15, h / 2)
	match kind:
		"coin":
			draw_circle(ic, 7.5, Color("#b8860b"), true, -1.0, true)
			draw_circle(ic, 5.5, ACCENT, true, -1.0, true)
			draw_line(ic + Vector2(0, -3), ic + Vector2(0, 3), Color("#b8860b"), 1.6, true)
		"unit":
			draw_circle(ic + Vector2(0, -3.5), 3.6, Color.WHITE, true, -1.0, true)
			draw_rect(Rect2(ic + Vector2(-5, 1), Vector2(10, 6)), Color.WHITE)
		_:
			draw_circle(ic, 6.5, col, true, -1.0, true)
	_text(p + Vector2(28, 5 - fsz * 0.05), label, fsz, Color.WHITE, false, true)
	return w



## 按鍵提示列（R6）：手把時顯示 [A]／[X] 等按鍵圖示，鍵盤時顯示鍵名。items＝[[鍵, 說明], ...]，置中於 cx。
func _key_hints(cx: float, y: float, items: Array, size := 15) -> void:
	# 擺放畫面上方列高度固定 86px：大字設定時這一列最多放大到 17px，寬度不夠再縮（Codex 收尾輪 #3）
	var fs := tcap(ts(size), 17)
	var widths: Array = []
	var total := 0.0
	for it in items:
		var kw := font_bold.get_string_size(it[0], HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(fs - 2, KEY_MIN)).x + 14.0
		var lw := font.get_string_size(it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		widths.append([kw, lw])
		total += kw + 6 + lw + 18
	if total > 1260.0:
		_key_hints_scaled(cx, y, items, fs - 1)
		return
	var x := cx - total / 2.0
	for i in items.size():
		var kw: float = widths[i][0]
		var key: String = items[i][0]
		var kc: Color = {"×": Color("#42a5f5"), "O": Color("#ef5350"), "□": Color("#ec7fc1"), "▲": Color("#3ccf6e"), "A": Color("#3ccf6e"), "B": Color("#ff8a80"), "X": Color("#42a5f5"), "Y": Color("#ffca28")}.get(key, Color(0.75, 0.78, 0.85))
		var r := Rect2(x, y, kw, fs + 6)
		if key.length() == 1 and pad_mode:
			draw_circle(r.get_center(), r.size.y / 2, kc, true, -1.0, true)
		else:
			draw_rect(r, Color(kc, 0.9))
		if pad_mode and key in PS_SYMS:
			_ps_glyph(r.get_center(), fs * 0.62, key)   # V1.2.1 G2：PS 鍵用向量符號（字型裡沒有 ○△，原本用字母 O／▲ 代替）
		else:
			_probe_glyph = true   # V1.2.1：鍵帽上的字母是符號，不算內文字級
			_text(Vector2(r.get_center().x, y + 1), key, maxi(fs - 2, KEY_MIN), Color(0.08, 0.08, 0.1), true, true)
			_probe_glyph = false
		x += kw + 6
		_text(Vector2(x, y + 1), items[i][1], fs, Color(1, 1, 1, 0.85))
		x += widths[i][1] + 18




const PS_SYMS := ["×", "O", "□", "▲"]
const KEY_MIN := 13   # 1.1.0 B9：鍵帽字母最小 13（Deck 字形實高 ≥ 9px；100% 底列原本是 12）

## V1.2.1 G2：PS 按鍵符號（叉、圈、方塊、三角）畫成向量，深色線條。
func _ps_glyph(c: Vector2, s: float, key: String) -> void:
	var col := Color(0.08, 0.08, 0.1)
	var w := maxf(1.6, s * 0.2)
	var h := s * 0.5
	match key:
		"×":
			draw_line(c + Vector2(-h, -h), c + Vector2(h, h), col, w, true)
			draw_line(c + Vector2(-h, h), c + Vector2(h, -h), col, w, true)
		"O":
			draw_arc(c, h, 0.0, TAU, 20, col, w, true)
		"□":
			draw_rect(Rect2(c - Vector2(h, h) * 0.9, Vector2(h, h) * 1.8), col, false, w)
		"▲":
			draw_polyline(PackedVector2Array([c + Vector2(0, -h * 1.05), c + Vector2(h * 1.05, h * 0.8), c + Vector2(-h * 1.05, h * 0.8), c + Vector2(0, -h * 1.05)]), col, w, true)

func _key_hints_scaled(cx: float, y: float, items: Array, fs: int) -> void:
	# 縮一號再排（以實際像素傳入，避免再乘一次字級）
	var widths: Array = []
	var total := 0.0
	for it in items:
		var kw := font_bold.get_string_size(it[0], HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(fs - 2, KEY_MIN)).x + 14.0
		var lw := font.get_string_size(it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		widths.append([kw, lw])
		total += kw + 6 + lw + 18
	if total > 1260.0 and fs > 10:
		_key_hints_scaled(cx, y, items, fs - 1)
		return
	var x := cx - total / 2.0
	for i in items.size():
		var kw: float = widths[i][0]
		var r := Rect2(x, y, kw, fs + 6)
		draw_rect(r, Color(0.75, 0.78, 0.85, 0.9))
		if pad_mode and str(items[i][0]) in PS_SYMS:
			_ps_glyph(r.get_center(), fs * 0.62, str(items[i][0]))
		else:
			_probe_glyph = true
			_text(Vector2(r.get_center().x, y + 1), items[i][0], maxi(fs - 2, KEY_MIN), Color(0.08, 0.08, 0.1), true, true)
			_probe_glyph = false
		x += kw + 6
		_text(Vector2(x, y + 1), items[i][1], fs, Color(1, 1, 1, 0.85))
		x += widths[i][1] + 18


## 這場用到的新兵才烘圖（含生出來的兵）；舊 10 種開遊戲就有。
func _ensure_sprites(armies_: Array) -> void:
	if sprites == null:
		return
	var need := {}
	var all_t := {}   # V1.5.1：這場出場的兵種（轉身出手格只烘這些）
	for a in armies_:
		for u in a.units:
			var t: int = int(u["type"])
			all_t[t] = true
			if t == F8.SLIME:
				all_t[F8.MINI_SLIME] = true
			if t == F8.BONE:
				all_t[F8.SKELETON] = true
			if t >= D.COUNT:
				need[t] = true
				if t == F8.SLIME:
					need[F8.MINI_SLIME] = true
				if t == F8.BONE:
					need[F8.SKELETON] = true
	if not need.is_empty():
		sprites.ensure(need.keys())
	sprites.ensure_turn_atk(all_t.keys())

# ── V9 P2 步態驅動：相位由真實位移算，只影響畫面 ──
const Gait = preload("res://scripts/ui/units/gait.gd")
var gait_d := {}       # id → [前一 tick 累積距離, 這一 tick 累積距離]（世界單位）
var gait_on := {}      # id → 這一 tick 算在走路
var gait_land := {}    # id → 停步後還在收腳幾 tick
var drag_t := {}       # id → 被擊退、吸走的拖行姿勢還剩幾秒
var face_now := {}     # id → 目前朝向（轉身有過場）
var turn_t := {}       # id → 上次翻面的時間（V1.3 A1a）
var stop_t := {}       # id → 停步的時間（V1.3 A4）
var atk_face := {}     # id → 這一擊鎖定的朝向（V1.3.1 P0-2）
var idle_since := {}   # id → 開始站定的時間（V1.3.1：最後一隻張望）
var walking := {}      # id → 上一幀在走

func _gait_reset() -> void:
	if get("hd_state") != null:
		get("hd_state").clear()   # 1.3.0 §5.4 走向記錄（跳轉、新的一場清掉）
	gait_d.clear()
	gait_on.clear()
	gait_land.clear()
	drag_t.clear()
	face_now.clear()
	turn_t.clear()
	stop_t.clear()
	atk_face.clear()
	idle_since.clear()
	walking.clear()

## 每個畫面 tick 呼叫一次（prev_pos 是上一 tick、u 是這一 tick）。
func _gait_tick(with_fx := true) -> void:
	for u in view.units:
		if not u.alive:
			continue
		var was: Vector2 = prev_pos.get(u.id, Vector2(u.x, u.y))
		var delta := Vector2(u.x, u.y).distance_to(was)
		var d: Array = gait_d.get(u.id, [0.0, 0.0])
		d = [d[1], d[1]]
		var step: float = maxf(float(D.stat(u.type)["speed"]), 30.0)
		if delta > maxf(step * 3.0, 150.0) or (u.stun > 0 and delta > 1.0):
			# 被擊退、吸走：不是走路，切拖行姿勢
			drag_t[u.id] = 0.28
			gait_on[u.id] = false
		elif delta >= 3.0:
			d[1] = float(d[1]) + delta
			gait_on[u.id] = true
			gait_land[u.id] = 3
		elif gait_on.get(u.id, false):
			# 沒在動：把這一步踩完再站定，不懸空
			var left: int = gait_land.get(u.id, 0)
			var ph: float = Gait.phase_of(u.type, d[1], CS, UNIT_SCALE, u.id)
			if left <= 0 or absf(sin(ph)) < 0.35:
				gait_on[u.id] = false
			else:
				d[1] = float(d[1]) + Gait.stride(u.type) * UNIT_SCALE * 1000.0 / CS * 0.25
				gait_land[u.id] = left - 1
		gait_d[u.id] = d
		if with_fx and not bool(Save.s("reduce_fx")) and (u.type == 19 or u.type == D.CAVALRY or u.type == 11):
			_gait_step_fx(u, d)
		if with_fx and gait_on.get(u.id, false):
			_gait_step_snd(u, d)

## 腳步聲：全場一起走會變噪音，所以限量（約每 0.11 秒最多一聲）、音量很小；小石魔例外。
var _step_cool := 0
func _gait_step_snd(u, d: Array) -> void:
	var k: int = Gait.kind(u.type)
	if k == Gait.FLOAT or k == Gait.ROOT or k == Gait.HOP:
		return
	var a: float = Gait.phase_of(u.type, d[0], CS, UNIT_SCALE, u.id)
	var b: float = Gait.phase_of(u.type, d[1], CS, UNIT_SCALE, u.id)
	if int(a / PI) == int(b / PI):
		return
	if u.type == 19:
		sfx.play("step_heavy", 0.55)
		return
	if view.tick <= _step_cool:
		return
	_step_cool = view.tick + 2
	var snd := "step_grass"
	match MapDefs.MAPS[fld_map]["biome"]:
		"ice":
			snd = "step_snow"
		"lava", "canyon":
			snd = "step_stone"
		"river":
			if absi(int(u.x) - fld_w / 2) < fld_w / 10:
				snd = "step_wood"
	sfx.play(snd, 0.16)

## 小石魔、馬、羊落地揚塵。
func _gait_step_fx(u, d: Array) -> void:
	if not gait_on.get(u.id, false):
		return
	var a: float = Gait.phase_of(u.type, d[0], CS, UNIT_SCALE, u.id)
	var b: float = Gait.phase_of(u.type, d[1], CS, UNIT_SCALE, u.id)
	if int(a / PI) != int(b / PI):
		fx.append({"kind": "step", "p": _upos(u), "t": 0.0, "dur": 0.35, "big": u.type == 19})

## 這一幀要畫的走路相位。
func _walk_of(u, a: float) -> float:
	var k: int = Gait.kind(u.type)
	if u.stun > 0 or (drag_t.get(u.id, 0.0) > 0.0):
		if drag_t.get(u.id, 0.0) > 0.0:
			return Gait.POSE_DRAG
		return Gait.POSE_DAZE
	if k == Gait.ROOT:
		return 0.0
	if gait_on.get(u.id, false):
		var d: Array = gait_d.get(u.id, [0.0, 0.0])
		return Gait.phase_of(u.type, lerpf(d[0], d[1], a), CS, UNIT_SCALE, u.id)
	if k == Gait.FLOAT:
		return 0.0001 + time * 4.0 + u.id * 0.37      # 飄浮的就算停著也在飄
	return 0.0

func _gait_frame(delta: float) -> void:
	for id in drag_t.keys():
		drag_t[id] -= delta
		if drag_t[id] <= 0.0:
			drag_t.erase(id)
	# V1.3.1 P1：全場只剩最後一隻、而且沒在出手也沒在走時，左右張望（用轉身影格）
	var alive := [0, 0]
	for u0 in view.units:
		if u0.alive:
			alive[u0.team] += 1
	for u in view.units:
		var tgt: float = signf(u.fx) if u.fx != 0 else (1.0 if u.team == 0 else -1.0)
		if u.mx != 0 or u.my != 0 or u.stun > 0 or atk_face.has(u.id) or drag_t.has(u.id) or not idle_since.has(u.id):   # 出手、暈眩也不算站定
			idle_since[u.id] = time
		if u.alive and alive[u.team] == 1 and not view.finished and time - float(idle_since[u.id]) > 1.5 and not atk_face.has(u.id):
			tgt = 1.0 if sin(time * PI / 1.1 + u.id) >= 0.0 else -1.0   # 站定 1.5 秒後才開始張望
		var f0: float = float(face_now.get(u.id, tgt))
		var f1: float = move_toward(f0, tgt, delta * 11.0)
		face_now[u.id] = f1
		if f0 != 0.0 and signf(f1) != signf(f0):
			turn_t[u.id] = time   # V1.3 A1a：翻面那一刻（腳下揚塵、展開回彈從這裡算）

## 轉身過場（V1.3 A1a）：像厚木牌俐落翻面，不是紙片等比夾扁。
## 寬度不低於 TURN_MIN_W（窄位直接跳過去），展開段 X 微回彈 1.04；不做 Y 下壓（混戰時會像受擊）。
const TURN_MIN_W := 0.45
const TURN_BOUNCE := 0.04
func _face_of(u) -> float:
	var f: float = face_now.get(u.id, signf(u.fx) if u.fx != 0 else (1.0 if u.team == 0 else -1.0))
	var a := absf(f)
	if a < 0.9 and sprites != null and sprites.has_turn(u.type):
		# 有轉身影格的兵：傳原本的朝向，貼圖端選中間姿勢（不能是 0，退回直接繪製時才不會消失）
		return maxf(a, 0.18) * (1.0 if f >= 0.0 else -1.0)
	var w := TURN_MIN_W + (1.0 - TURN_MIN_W) * a
	if a < 1.0 and turn_t.has(u.id) and time - float(turn_t[u.id]) < 0.25:
		w *= 1.0 + TURN_BOUNCE * sin(clampf((a - 0.55) / 0.45, 0.0, 1.0) * PI)
	return w if f >= 0.0 else -w

## 剛翻面的兵腳下的小揚塵：0～1（1＝剛翻），超過 0.25 秒＝0。
func _turn_dust_k(u) -> float:
	if not turn_t.has(u.id):
		return 0.0
	var k: float = (time - float(turn_t[u.id])) / 0.25
	return 1.0 - k if k >= 0.0 and k < 1.0 else 0.0

## 打到不同東西聲音不同：盾與石魔是硬的、史萊姆是軟的。
func _hit_material(id: int) -> void:
	if id < 0 or view == null:
		return
	var u = view.unit_by_id(id)
	if u == null:
		return
	var cp: Vector2 = _upos(u) + Vector2(0, -26)
	if call("_frags_on") and u.type != D.SHIELD:
		var fk: int = view.tick * 4096 + u.id
		frags.spawn(_upos(u), "poison" if u.type in [13, 20] else ("ice" if u.type == 19 else "wood"), 2, fk, 26.0)   # 1.2.0 §8.2 命中＝木屑＋墨點（史萊姆＝水彩暈、石魔＝白瓷碎）
		frags.spawn(_upos(u), "ink", 1, fk + 1, 26.0)
	match u.type:
		D.SHIELD:
			sfx.play("hit_metal", 0.22)
			call("_add_fx", {"kind": "chips", "p": cp, "t": 0.0, "dur": 0.32, "c": Color("#e8f0ff"), "spark": true})   # V1.1 A2：盾面火花
		19, 12:
			sfx.play("hit_wood", 0.3)
			if u.type == 19:
				call("_add_fx", {"kind": "chips", "p": cp, "t": 0.0, "dur": 0.38, "c": Color("#a89a86")})   # 小石魔碎屑
		13, 20:
			sfx.play("hit_soft", 0.3)
			call("_add_fx", {"kind": "chips", "p": cp, "t": 0.0, "dur": 0.4, "c": Color(0.45, 1.0, 0.55, 0.85), "drop": true})   # 史萊姆綠滴
