extends Node2D
## 《落子無悔》UI 基底：共用常數、狀態、按鈕、文字、焦點、提示（第二輪方案 R2 從 main.gd 拆出）。
## 繼承鏈：ui_base → battle_view（戰場與演出）→ game_screens（狀態機與各畫面）→ main（宣傳工具：截圖、膠囊、影片）。
## 戰鬥結果完全由 scripts/core/battle_sim.gd 決定；這裡只負責演出（插值、特效、慢動作、鏡頭、聲音），不影響勝負。
## UI 是自繪的「即時模式按鈕」，同時支援滑鼠、鍵盤、手把（焦點導航）。

const D = preload("res://scripts/core/unit_defs.gd")
const Army = preload("res://scripts/core/army.gd")
const Sim = preload("res://scripts/core/battle_sim.gd")
const AI = preload("res://scripts/core/ai_army.gd")
const AIT = preload("res://scripts/core/ai_turns.gd")
const TP = preload("res://scripts/core/turn_placement.gd")
const Art = preload("res://scripts/ui/art.gd")
const L = preload("res://scripts/game/strings.gd")
const Save = preload("res://scripts/game/save.gd")
const SteamApi = preload("res://scripts/game/steam.gd")
const PZ = preload("res://scripts/game/puzzles.gd")
const SfxScript = preload("res://scripts/game/sfx.gd")
const SpriteCache = preload("res://scripts/ui/sprite_cache.gd")
const ViewBuffer = preload("res://scripts/ui/view_buffer.gd")
const RS = preload("res://scripts/game/roster.gd")
const HardAI = preload("res://scripts/core/hard_ai.gd")

enum St { TITLE, PLACE, BATTLE, RESULT }
enum Mode { VS_AI, DUEL, TUTORIAL, PUZZLE, GAUNTLET }

const ORIGIN := Vector2(128, 100)
const CS := 64.0
const FIELD := Vector2(16 * 64, 9 * 64)
const CARD_Y := 694.0
const CARD_W := 80.0     # 第四輪：一排 10 張窄卡（方案 D），起點 x＝CARD_X0
const CARD_X0 := 12.0
const CARD_GAP := 6.0
const CARD_H := 96.0
const UI_BG := Color(0.08, 0.09, 0.13, 0.94)
const PANEL := Color(0.12, 0.13, 0.19, 0.97)
const ACCENT := Color("#ffd166")
const UNIT_SCALE := 0.92

var font: Font
var font_bold: Font
var sfx
var state := St.TITLE
var mode := Mode.VS_AI
var overlay := ""
var difficulty := 1
var duel_rule := "snake5"
var armies: Array = []
var tp = null
var blind_phase := 0          # 盲擺：0 藍擺、1 紅擺、2 完成
var ai_name := ""
var rng := RandomNumberGenerator.new()
var selected := D.SWORD
var hover_card := -1
var drag_new := false
var drag_from := Vector2i(-1, -1)
var painting := false
var paint_team := 0
var mouse := Vector2.ZERO
var cursor := Vector2i(4, 4)
var pad_mode := false
var toast := ""
var toast_t := 0.0
var ach_queue: Array = []
var ach_t := 0.0
var wins := [0, 0]
var round_no := 1
var series_over := false
var last_armies: Array = []
var last_player_formation: Array = []
var puzzle_id := ""
var gauntlet_stage := 1
var gauntlet_prev: Array = []
var gauntlet_changes := 3
var gauntlet_seed := 0

# 戰鬥演出
var sim = null
## 副作用矩陣（第三輪 A1）：每種播放方式會寫入哪些東西。正式＝真的打了一場；重播＝同一場再看一次；覆盤＝改一隻兵看「如果」。
const PLAY_EFFECTS := {
	"official": {"series": true, "progress": true, "log": true},
	"replay": {"series": false, "progress": false, "log": false},
	"review": {"series": false, "progress": false, "log": false},
}
var play_kind := "official"   # 這一場是哪種播放
var view = null           # 展示緩衝（R5）：戰鬥畫面播的是比模擬晚 2 tick 的快照
var clutch_tick := -1      # 最後時刻在第幾 tick 觸發（重播跳轉時重建狀態用）
var watch_mode := false   # 正在看對戰代碼（結果頁不提供「下一局」）
var replay_total := 0     # 重播這一場總共幾 tick（時間軸比例用）
var paused := false        # 重播控制：暫停（第三輪 F2）
var follow_id := -1       # 重播控制：鏡頭跟著哪一隻
var graves: Array = []        # 陣亡處的小旗（第三輪 R5）：{pos, team, t}，3 秒淡出
var battle_marks: Array = []   # 結果頁時間軸的關鍵事件（第三輪 U5）：{tick, kind, team}
var hurt_dir := {}        # 受擊後退方向（第三輪 R2，只是演出）
var brace_t := {}         # 盾兵頂住的畫面時間（盾放大 1.35 倍 0.35 秒）
var atk_seq := {}         # 單位 id →｛命中 tick: 第幾次出手｝（交替招式用）
var pot_draw: Array = []  # 第四輪：這一幀要畫的火罐位置
var puzzle_tab := 0       # 第四輪：殘局選單分頁（0 經典、1 新兵試玩）
var alt_hit := {}        # 第四輪：單位 id → {命中 tick: true}，這一擊用專屬動作
var bomb_tgt := {}       # 第四輪：投彈兵 id → {命中 tick: 目標 id}（畫火罐飛行）
var atk_hit := {}         # 單位 id → 命中 tick 的序列（最多留 4 筆）； 單位 id → 下一次（或最近一次）命中的模擬 tick，前搖從命中前 2 tick 開始
var prev_pos := {}
var accum := 0.0
var speed := 1.0
var slow_used := false
var slow_left := 0.0
var hitstop := 0.0
var zoom := 1.0
var zoom_target := 1.0
var zoom_center := ORIGIN + FIELD / 2
var shake := 0.0
var fx: Array = []
var atk_t := {}
var hurt_t := {}
var dying: Array = []
var result_delay := 0.0
var time := 0.0
var shot_dir := ""
var ev_count := {}
var frenzy_seen := false
var report := {}
var _cam := Transform2D.IDENTITY   # 這一幀戰場的鏡頭轉換（最後時刻淡化跳字用）
var clutch_t := 0.0                # 最後時刻橫幅剩幾秒
var freeze_fx := false
## 版面檢查（第三輪 T4）：截圖模式記下每一段介面文字實際畫出的外框，拍照時檢查越界、太小、互相重疊。
var layout_probe := false
var _probe_ui := false        # 只量介面層（不量戰場上的跳字）
var probe_texts: Array = []     # 截圖用：特效停在當下的時刻不往前跑
var pt_call_tick := -1
var pt_rated := false

# 標題背景的展示戰
var demo = null
var demo_acc := 0.0

# 即時模式按鈕
var _btns: Array = []
var _focus := 0
var _cmds: Array = []        # 輸入命令佇列（A2）
var _gen := 0                # 畫面世代
var _gen_key := ""
var _btns_gen := -1          # _btns 是哪個世代畫出來的

var capsule_path := ""
var perf_draw_us := 0     # 這一幀 _draw 花的時間（效能量測用）
var perf_proc_us := 0     # 這一幀 _process 花的時間
var perf_path := ""
var perf_parts := {}      # 繪圖各部分耗時（微秒）
var sprites = null        # 角色精靈圖快取（沒有畫面時是 null，退回直接繪製）
var video_mode := false
var grass: Texture2D
var plants: Array = []


func _load_font(path: String) -> Font:
	if ResourceLoader.exists(path):
		var f = load(path)
		if f:
			return f
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Microsoft JhengHei UI", "Noto Sans CJK TC", "sans-serif"])
	return sf


func _apply_fullscreen() -> void:
	if shot_dir != "":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if Save.s("fullscreen") else DisplayServer.WINDOW_MODE_WINDOWED)


func ts(px: int) -> int:
	return int(px * int(Save.s("text_scale")) / 100)


func cbm() -> bool:
	return bool(Save.s("colorblind"))


func _toast(s: String, deny := false) -> void:
	toast = s
	toast_t = 2.0
	if deny:
		sfx.play("ui_deny")


func _move_focus(d: int) -> void:
	pad_mode = true
	if _btns.is_empty():
		return
	_focus = posmod(_focus + d, _btns.size())


## 字太寬就縮小（英文、大字設定時避免截字；最小 9px）。
func fit(s: String, size: int, maxw: float, bold := false) -> int:
	var fnt := font_bold if bold else font
	var sz := size
	var w := 0.0
	for ln in s.split("\n"):
		w = maxf(w, fnt.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x)
	while w > maxw and sz > 9:
		sz -= 1
		w = 0.0
		for ln in s.split("\n"):
			w = maxf(w, fnt.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x)
	return sz


func _text(p: Vector2, s: String, size: int, c: Color, center := false, bold := false, maxw := 0.0, outline := Color(0, 0, 0, -1)) -> void:
	var fnt := font_bold if bold else font
	if maxw > 0.0:
		size = fit(s, size, maxw, bold)
	var lines := s.split("\n")
	for i in lines.size():
		var w := fnt.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x if center else 0.0
		var q := p + Vector2(-w / 2, i * size * 1.3 + size * 0.85)
		if layout_probe and _probe_ui and c.a > 0.2 and lines[i].strip_edges() != "":
			var ww := fnt.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			probe_texts.append({"r": Rect2(q.x, q.y - size * 0.85, ww, size * 1.1), "size": size, "s": lines[i]})
		var oc := Color(0, 0, 0, c.a * 0.75) if outline.a < 0.0 else outline
		if oc.a > 0.0:
			draw_string_outline(fnt, q, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, oc)
		draw_string(fnt, q, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)


## 即時模式按鈕：每幀重新登記，滑鼠或焦點都能按。
func _btn(r: Rect2, label: String, action: Callable, enabled := true, primary := false, tint := Color(0, 0, 0, 0)) -> void:
	var idx := _btns.size()
	_btns.append({"r": r, "cb": action, "en": enabled})
	var hover := r.has_point(mouse) and not pad_mode
	var focus := pad_mode and idx == _focus
	var bg := Color(0.2, 0.22, 0.3) if not primary else Color(0.85, 0.52, 0.14)
	if tint.a > 0:
		bg = tint
	if not enabled:
		bg = Color(0.16, 0.16, 0.2)
	elif hover or focus:
		bg = bg.lightened(0.18)
	draw_rect(r, bg)
	draw_rect(r, ACCENT if focus else Color(1, 1, 1, 0.18), false, 3 if focus else 1.5)
	var sz := fit(label, ts(18) if r.size.y >= 40 else ts(15), r.size.x - 10, primary)
	sz = mini(sz, int(r.size.y * 0.8))
	_text(r.get_center() - Vector2(0, sz * 0.62), label, sz, Color.WHITE if enabled else Color(1, 1, 1, 0.4), true, primary)


## ── 輸入命令佇列（第三輪 A2）──
## 輸入事件不再直接執行，也不在 _draw 裡派發：先排進佇列，在 _process 開頭依序處理。
## 每個命令記下排入時的「畫面世代」；畫面（狀態、覆蓋層、模式）一換，舊命令就丟掉，避免點到下一個畫面的按鈕。
## 點擊只對「這個世代畫出來的按鈕」有效（_btns_gen）。
func _enqueue(kind: String, data) -> void:
	_cmds.append({"kind": kind, "data": data, "gen": _gen})

func _update_gen() -> void:
	var key := "%d|%s|%d" % [state, overlay, mode]
	if key != _gen_key:
		_gen_key = key
		_gen += 1


func _panel(r: Rect2) -> void:
	draw_rect(Rect2(0, 0, 1280, 800), Color(0, 0, 0, 0.68))
	draw_rect(r, PANEL)
	draw_rect(r, Color(1, 1, 1, 0.2), false, 2)


func _open(name: String) -> void:
	overlay = name
	_focus = 0


func _fmt_num(v: float) -> String:
	return str(int(v)) if v == floorf(v) else str(v)


func _onoff(k: String) -> String:
	return L.t("on") if bool(Save.s(k)) else L.t("off")


func _cycle_setting(k: String, opts: Array) -> void:
	var cur = Save.s(k)
	var i := 0
	for j in opts.size():
		if str(opts[j]) == str(cur):
			i = j
	Save.set_setting(k, opts[(i + 1) % opts.size()])

## 畫一隻角色：精靈圖快取好了就貼圖（快很多），否則直接用 Art 畫。畫面相同。
func _unit(p: Vector2, type: int, team: int, face: float, walk: float, atk: float, hurt: float, alpha: float, t: float, scale := 1.0,
		mood := 0, lean := 0.0, crouch := 1.0, variant := 0) -> void:
	if sprites != null and sprites.is_ready(cbm()):
		sprites.draw_unit(self, p, type, team, face, walk, atk, hurt, alpha, t, scale, mood, lean, crouch, cbm(), variant)
	else:
		Art.unit(self, p, type, team, face, walk, atk, hurt, alpha, t, scale, cbm(), mood, lean, crouch, variant)

func _ring(p: Vector2, team: int, type: int, scale := 1.0) -> void:
	if sprites != null and sprites.is_ready(cbm()):
		sprites.draw_ring(self, p, team, type, scale)
	else:
		Art.ring(self, p, team, type, cbm(), scale)

func _rebuild_sprites() -> void:
	if sprites != null:
		sprites.build(cbm())


## 目前模式的名稱（S8：只用到 ui_base 的狀態，從 game_screens 移下來）
func _mode_label() -> String:
	match mode:
		Mode.VS_AI: return "%s・%s" % [L.t("menu_vs_ai"), L.t(["diff_easy", "diff_normal", "diff_hard"][difficulty])]
		Mode.DUEL: return "%s・%s" % [L.t("menu_duel"), L.t("rule_" + duel_rule)]
		Mode.TUTORIAL: return L.t("menu_tutorial")
		Mode.PUZZLE: return L.t("menu_puzzle")
		Mode.GAUNTLET: return L.t("menu_gauntlet")
	return ""


## 戰鬥播完（含結算延遲）之後要做的事；由 game_screens 在 _ready 設定（S8：取代基底的空函式）
var on_battle_finished: Callable = func(): pass
