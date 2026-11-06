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
const Keymap = preload("res://scripts/game/keymap.gd")
const HardAI = preload("res://scripts/core/hard_ai.gd")
const RuleSet = preload("res://scripts/core/ruleset.gd")
const Presets = preload("res://scripts/game/presets.gd")
const CmdD = preload("res://scripts/core/cmd_defs.gd")
const Charts = preload("res://scripts/ui/charts.gd")

enum St { TITLE, PLACE, BATTLE, RESULT }
enum Mode { VS_AI, DUEL, TUTORIAL, PUZZLE, GAUNTLET }

const ORIGIN := Vector2(128, 100)
const BATTLE_DY := 36.0   # 第十輪 B9：戰鬥鏡頭下移，貼上緣的兵頭不被頂列蓋住（只改畫面）
var force_demo := false   # 測試用：不必匯出就能走試玩版流程
func _demo() -> bool:
	return force_demo or OS.has_feature("demo")
var force_async := false  # 測試用：headless 也走背景計算
var last_joy := 0         # 最後操作的手把（提示要依它顯示）
func _async_ok() -> bool:
	return force_async or (DisplayServer.get_name() != "headless" and shot_dir == "")
func _pk(action: String) -> String:
	return load("res://scripts/game/keymap.gd").pad_glyph(Save.s("pad"), action, Input.get_joy_name(last_joy))
## 第十輪 I3：手把沒辦法貼上時開 Steam 鍵盤；沒有 Steam 就提示。有接手回傳 true。
func _ask_code(prompt: String, on_text: Callable) -> bool:
	if not pad_mode:
		return false
	var cb := func(submitted: bool, text: String, _app: int) -> void:
		if submitted:
			on_text.call(text)
	if not SteamApi.text_input(prompt, 8000, cb):
		_toast(L.t("bc_pad_hint"), true)
	return true
const CS := 64.0
const FIELD := Vector2(16 * 64, 9 * 64)
const MapArt = preload("res://scripts/ui/map_art.gd")
const MapDefs = preload("res://scripts/core/map_defs.gd")
# V9：這一場的場地（世界 px）。標準大小時 fld_size＝FIELD、_fld_xf＝單位矩陣，舊畫面完全不變
var fld_size := FIELD
var fld_w := 16000
var fld_h := 9000
var fld_map := 0
var fld_sz := 1
var fld_props: Array = []
var map_art = null

## 第十三輪：殘局自帶的規則（地形、撐住秒數、技能）；不是殘局或不用規則回 null。
func _puzzle_rules():
	if (mode == Mode.PUZZLE or mode == Mode.TUTORIAL) and puzzle_id != "":
		return PZ.rules_of(PZ.get_puzzle(puzzle_id))
	return null

## 場地用哪一組規則畫：自由部署的大廳規則，或格子放在地圖上的殘局。
func _field_rules():
	if rules != null and rules.is_free():
		return rules
	var pr = _puzzle_rules()
	if pr != null and pr.map_id != 0:
		return pr
	return null

## 這關要護送／斬首的單位：[模擬 id, "protect"／"kill"]，沒有回 [-1, ""]。
func _goal_mark() -> Array:
	if mode != Mode.PUZZLE or puzzle_id == "":
		return [-1, ""]
	var pz := PZ.get_puzzle(puzzle_id)
	var g := PZ.goal(pz)
	if g == "flawless":
		return [-2, "flawless", int(pz["goal_type"])]   # V1.1：-2＝標整個兵種（我方每一隻）
	if g != "protect" and g != "kill":
		return [-1, ""]
	var c: Array = pz["goal_unit"]
	var team := 0 if g == "protect" else 1
	return [team * 1000 + int(c[1]) * 16 + int(c[0]), g]

## 依這一場的規則同步場地。每幀畫面開頭呼叫。
func _sync_field() -> void:
	var r = _field_rules()
	var m: int = r.map_id if r != null else 0
	var z: int = r.map_size if r != null else MapDefs.STD_SIZE
	if m == fld_map and z == fld_sz:
		return
	fld_map = m
	fld_sz = z
	fld_w = MapDefs.width(z)
	fld_h = MapDefs.height(z)
	fld_size = Vector2(fld_w / 1000.0 * CS, fld_h / 1000.0 * CS)
	fld_props = MapArt.props(m, z)
	_map_tex()   # 一換圖就先烘，開場那幾格才看得到地形

## 把場地放進固定的戰場框：等比容納，置中留邊。
func _fld_xf() -> Transform2D:
	if fld_sz == MapDefs.STD_SIZE:
		return Transform2D.IDENTITY
	var k: float = minf(FIELD.x / fld_size.x, FIELD.y / fld_size.y)
	return Transform2D(0.0, Vector2(k, k), 0.0, ORIGIN + (FIELD - fld_size * k) / 2.0 - ORIGIN * k)

func _map_tex() -> Texture2D:
	if map_art == null:
		map_art = MapArt.new()
		add_child.call_deferred(map_art)
		return null
	if fld_map == 0:
		return null
	if not map_art.is_inside_tree():
		return null
	return map_art.texture(fld_map, fld_sz)
const CARD_Y := 694.0
const CARD_W := 80.0     # 第四輪：一排 10 張窄卡（方案 D），起點 x＝CARD_X0
const CARD_X0 := 12.0
const CARD_GAP := 6.0
const CARD_H := 96.0
const UI_BG := Color(0.11, 0.08, 0.06, 0.95)
const PANEL := Color(0.17, 0.125, 0.09, 0.98)
const ACCENT := Color("#ffd166")
# V9 P5 設計系統：胡桃木為底（白字才讀得清楚），羊皮紙只用在標題緞帶與重點卡片
const TH_WOOD := Color("#3a2a1f")
const TH_WOOD_L := Color("#55402d")
const TH_WOOD_D := Color("#231912")
const TH_EDGE := Color("#8d6c47")
const TH_ACTIVE := Color("#8a5a24")
const TH_PARCH := Color("#efdfbb")
const TH_INK := Color("#2c2016")
const TH_PRIMARY := Color("#e08a1e")
const SP := 8.0        # 間距基準
const Icons = preload("res://scripts/ui/icons.gd")
var _sb_cache := {}
var _hover_key := -1
var _trans_gen := -1
var _trans_t := -10.0
var _hover_now := -1
const UNIT_SCALE := 0.92

var font: Font
var font_bold: Font
var font_title: Font          # 第五輪：標題字 UoqMunThenKhung（只用在 ≥H2 的粗體、沒有數字的字串）

## 第五輪字級表（§4.2）：基準 1280×800。只允許表內的值；125%／150% 非線性（大字少放大、內文多放大）。
const TYPE_SCALE := {
	100: {"D": 64, "DX": 84, "H1": 32, "H2": 22, "B": 17, "S": 15, "C": 14},
	125: {"D": 70, "DX": 92, "H1": 35, "H2": 26, "B": 21, "S": 18, "C": 17},
	150: {"D": 70, "DX": 92, "H1": 35, "H2": 28, "B": 24, "S": 21, "C": 20},
}
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
var rules = null              # 第五輪：這個系列凍結的自訂規則（對 AI、雙人由大廳設定；其他模式 null＝標準）
var battle_rules = null
var settings_tab := 0        # 第五輪：設定分頁 0 畫面 1 聲音 2 操作 3 輔助
var settings_item := ""      # 設定說明欄目前說明的項目
var result_tab := 0           # 第五輪：結果頁 0＝摘要、1＝詳細數據
var result_metric := 0        # 詳細數據：0＝輸出、1＝承傷
var ai_prebuilt := false        # 第六輪：明牌全場時 AI 已經在擺放開始組好
var show_place_help := false   # 第五輪：擺放畫面的操作說明（「?」）
var pending_cell := Vector2i(-1, -1)   # 第五輪：雙人輪流落子「點兩下才落子」的預覽格
var removed_banner := ""       # 第五輪：規則變更移除了哪些兵（醒目橫幅）
var removed_banner_t := 0.0       # 第五輪：目前／上一場戰鬥用的規則（正式、重播、覆盤、跳轉、看代碼共用）
var view = null           # 展示緩衝（R5）：戰鬥畫面播的是比模擬晚 2 tick 的快照
var clutch_tick := -1      # 最後時刻在第幾 tick 觸發（重播跳轉時重建狀態用）
var watch_mode := false   # 正在看對戰代碼（結果頁不提供「下一局」）
var replay_total := 0     # 重播這一場總共幾 tick（時間軸比例用）
## 第七輪 K3：一鍵簡化特效。單項開關＋總開關都要開才算開。
func _fx_on(k: String) -> bool:
	return bool(Save.s(k)) and not bool(Save.s("reduce_fx"))

var seek_target := -1      # 第七輪 M3：時間軸分批跳轉的目標
var replay_snap := {}      # 第七輪 A9：進重播前的結算畫面，返回時原樣還原（不重算、不寫存檔）
var replay_marks: Array = []   # 第七輪 A7：重播時間軸的關鍵時刻
var paused := false        # 重播控制：暫停（第三輪 F2）
var follow_id := -1       # 重播控制：鏡頭跟著哪一隻
var graves: Array = []        # 陣亡處的小旗（第三輪 R5）：{pos, team, t}，3 秒淡出
var battle_marks: Array = []   # 結果頁時間軸的關鍵事件（第三輪 U5）：{tick, kind, team}
var hurt_dir := {}        # 受擊後退方向（第三輪 R2，只是演出）
var brace_t := {}         # 盾兵頂住的畫面時間（盾放大 1.35 倍 0.35 秒）
var atk_seq := {}         # 單位 id →｛命中 tick: 第幾次出手｝（交替招式用）
var pot_draw: Array = []  # 第四輪：這一幀要畫的火罐位置
var puzzle_tab := 0       # 第四輪：殘局選單分頁；第十三輪：第幾章（0 起算）
var puzzle_plan: Array = []   # 第十三輪：時序殘局，玩家設定的施放 tick
var puzzle_plan_id := ""      # puzzle_plan 是哪一關的（換關就重設，Codex v13-r1 #5）
var puzzle_only_open := false   # 第十三輪：殘局清單只看沒滿三星的
var puzzle_reveal := false      # 第十三輪：提示視窗裡「揭曉解答」的確認狀態
var alt_hit := {}        # 第四輪：單位 id → {命中 tick: true}，這一擊用專屬動作
var bomb_tgt := {}       # 第四輪：投彈兵 id → {命中 tick: 目標 id}（畫火罐飛行）
var atk_hit := {}         # 單位 id → 命中 tick 的序列（最多留 4 筆）； 單位 id → 下一次（或最近一次）命中的模擬 tick，前搖從命中前 2 tick 開始
var prev_pos := {}
var accum := 0.0
var speed := 1.0
var slow_used := false
var final_used := false   # 第十輪 F1
var final_left := 0.0
var result_t := -100.0    # 第十輪 F2：進結果頁的時間
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
var probe_texts: Array = []
var probe_btns: Array = []      # 第五輪：這一幀畫出來的按鈕外框（點擊框大小檢查）
var probe_ctrls: Array = []
var _probe_btn_label := false
var _probe_btn_rect := Rect2()     # 第五輪：其他控制項（兵卡）的外框；裡面的字不算段數     # 截圖用：特效停在當下的時刻不往前跑
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


## 第五輪：數字用等寬（tnum），金幣、秒數、百分比跳動時不會左右晃。
func _tnum(f: Font) -> Font:
	var fv := FontVariation.new()
	fv.base_font = f
	fv.opentype_features = {TextServerManager.get_primary_interface().name_to_tag("tnum"): 1}
	return fv

## 第五輪：載入三種字型角色。標題字缺的字由思源黑體 Bold 補。
func _load_fonts() -> void:
	var reg := _load_font("res://fonts/NotoSansTC-Regular-sub.otf")
	var bold := _load_font("res://fonts/NotoSansTC-Bold-sub.otf")
	font = _tnum(reg)
	font_bold = _tnum(bold)
	if ResourceLoader.exists("res://fonts/ThenKhung-sub.ttf"):
		var tk = load("res://fonts/ThenKhung-sub.ttf")
		if tk is FontFile:
			tk.fallbacks = [bold]
			font_title = tk


func _apply_fullscreen() -> void:
	if shot_dir != "":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if Save.s("fullscreen") else DisplayServer.WINDOW_MODE_WINDOWED)


## 舊介面寫的字級數字（11～84）吸附到字級表：11～14→註記、15→次要、16～18→內文、19～24→區塊標題、25～48→畫面標題、49 以上→展示。
## 這樣全遊戲不會再出現表外字級，也不會小於 14（第五輪 §4.2）。新程式請直接用 tz("B") 這類語意名稱。
static func role_of(px: int) -> String:
	if px <= 14:
		return "C"
	if px == 15:
		return "S"
	if px <= 18:
		return "B"
	if px <= 24:
		return "H2"
	if px <= 48:
		return "H1"
	return "D" if px < 80 else "DX"

func _scale_key() -> int:
	var sc := int(Save.s("text_scale"))
	return 150 if sc >= 150 else (125 if sc >= 125 else 100)

func tz(role: String) -> int:
	return int(TYPE_SCALE[_scale_key()][role])

func ts(px: int) -> int:
	return tz(role_of(px))

## 封頂（第五輪）：取字級表裡 ≤ 上限的最大值，但不低於「註記」。取代 tcap(ts(x), N)，避免封出表外字級。
func tcap(sz: int, maxpx: int) -> int:
	var best := tz("C")
	for v in TYPE_SCALE[_scale_key()].values():
		if v <= mini(sz, maxpx) and v > best:
			best = v
	return best

## 這個字級在不在字級表裡（版面檢查用）。
func size_ok(sz: int) -> bool:
	return sz in TYPE_SCALE[_scale_key()].values()


## 第五輪：解鎖用的累計場數（設定「全部解鎖」時視為全開；試玩版上限由 roster 管）。


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


## 字太寬就往下一級縮（第五輪：只在字級表內往下走，最小到「註記」，不再縮到 9px；還是太寬就由 _text 換行）。
func fit(s: String, size: int, maxw: float, bold := false) -> int:
	var sz := size
	var levels: Array = TYPE_SCALE[_scale_key()].values()
	levels.sort()
	while _width(s, sz, bold) > maxw:
		var nxt := -1
		for v in levels:
			if v < sz:
				nxt = v
		if nxt < 0:
			break
		sz = nxt
	return sz

func _font_for(s: String, size: int, bold: bool) -> Font:
	if bold and font_title != null and size >= tz("H2") and not bool(Save.s("plain_titles")) and not _has_digit(s):
		return font_title
	return font_bold if bold else font

static func _has_digit(s: String) -> bool:
	for i in s.length():
		var c := s.unicode_at(i)
		if (c >= 48 and c <= 57) or (c >= 0xFF10 and c <= 0xFF19):
			return true
	return false

func _width(s: String, size: int, bold := false) -> float:
	var w := 0.0
	for ln in s.split("\n"):
		w = maxf(w, _font_for(ln, size, bold).get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	return w

## 換行（第五輪）：中日韓逐字斷、英文逐詞斷；保留原本的 \n。回傳行陣列。
func wrap_lines(s: String, size: int, maxw: float, bold := false) -> PackedStringArray:
	var out := PackedStringArray()
	for para in s.split("\n"):
		if maxw <= 0.0 or _width(para, size, bold) <= maxw:
			out.append(para)
			continue
		var cur := ""
		var i := 0
		while i < para.length():
			var tok := para[i]
			if tok.unicode_at(0) < 0x2E80 and tok != " ":
				# 拉丁字：整個詞一起
				var j := i + 1
				while j < para.length() and para[j].unicode_at(0) < 0x2E80 and para[j] != " ":
					j += 1
				tok = para.substr(i, j - i)
				i = j
			else:
				i += 1
			if cur != "" and _width(cur + tok, size, bold) > maxw:
				# 避頭點（第六輪截圖）：句號、逗號、右括號不放行首——把上一行最後一個字一起帶到下一行（不掛出框外）
				if tok.length() == 1 and "。，、）」』！？；：%".contains(tok) and cur.length() > 1 and cur.unicode_at(cur.length() - 1) >= 0x2E80:
					out.append(cur.substr(0, cur.length() - 1).strip_edges(false, true))
					cur = cur.substr(cur.length() - 1) + tok
				else:
					out.append(cur.strip_edges(false, true))
					cur = tok.strip_edges(true, false) if tok == " " else tok
			else:
				cur += tok
		if cur != "":
			out.append(cur)
	return out

## 行距（第五輪 §4.2，XAG 101）：多行的段落 1.5 倍；單行照舊。
static func line_h(n: int) -> float:
	return 1.5 if n > 1 else 1.3

## 一段字換行後的高度（排版用）。
func text_h(s: String, size: int, maxw := 0.0, bold := false) -> float:
	var n := wrap_lines(s, size, maxw, bold).size()
	return n * size * line_h(n)


func _text(p: Vector2, s: String, size: int, c: Color, center := false, bold := false, maxw := 0.0, outline := Color(0, 0, 0, -1)) -> void:
	if maxw > 0.0:
		size = fit(s, size, maxw, bold)
	var lines := wrap_lines(s, size, maxw, bold) if maxw > 0.0 else s.split("\n")
	for i in lines.size():
		var fnt := _font_for(lines[i], size, bold)
		var w := fnt.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x if center else 0.0
		var q := p + Vector2(-w / 2, i * size * line_h(lines.size()) + size * 0.85)
		# 版面探針（第五輪補洞）：介面層與戰場層都量、低透明度（>0.05）也量；戰場字標 field
		if layout_probe and c.a > 0.05 and lines[i].strip_edges() != "":
			var ww := fnt.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			probe_texts.append({"r": Rect2(q.x, q.y - size * 0.85, ww, size * 1.1), "size": size, "s": lines[i], "field": not _probe_ui, "a": c.a, "btn": _probe_btn_label, "own": _probe_btn_rect})
		var oc := Color(0, 0, 0, c.a * 0.75) if outline.a < 0.0 else outline
		if oc.a > 0.0:
			draw_string_outline(fnt, q, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, oc)
		draw_string(fnt, q, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)


## 即時模式按鈕：每幀重新登記，滑鼠或焦點都能按。
## V9 P5 按鈕：圓角木牌、上緣高光、下緣陰影；按下縮一點回彈、懸停亮、焦點金框；主按鈕有流光。
func _btn(r: Rect2, label: String, action: Callable, enabled := true, primary := false, tint := Color(0, 0, 0, 0)) -> void:
	var idx := _btns.size()
	_btns.append({"r": r, "cb": action, "en": enabled, "snd": "k_confirm" if primary else ("k_back" if label == L.t("back") or label == L.t("menu") else "k_click")})
	var hover := r.has_point(mouse) and not pad_mode
	var focus := pad_mode and idx == _focus
	var bg := TH_WOOD_L if not primary else TH_PRIMARY
	if tint.a > 0:
		bg = tint
	if not enabled:
		bg = Color(0.2, 0.17, 0.15)
	elif hover or focus:
		bg = bg.lightened(0.16)
		if hover:
			_hover_now = idx
	var pressed := hover and enabled and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var rd := r.grow(-minf(r.size.x, r.size.y) * 0.025) if pressed else r
	_box(rd, bg, TH_EDGE.darkened(0.25) if tint.a <= 0.0 or tint.a > 0.6 else Color(0, 0, 0, 0), 7.0, 1.5)
	if tint.a <= 0.0 or tint.a > 0.6:
		draw_line(rd.position + Vector2(6, 1.5), rd.position + Vector2(rd.size.x - 6, 1.5), Color(1, 1, 1, 0.16), 1.5)
		draw_line(rd.position + Vector2(6, rd.size.y - 1.5), rd.end - Vector2(6, 1.5), Color(0, 0, 0, 0.3), 2.0)
	if primary and enabled:
		_btn_shine(rd)
	if focus:
		_box(rd.grow(1), Color(0, 0, 0, 0), ACCENT, 8.0, 3.0)
	if layout_probe:
		probe_btns.append(r)
		if label == "":
			probe_ctrls.append(r)   # 空白標籤的按鈕（卡片、頁籤）：裡面自己畫的字算按鈕內容
	var sz := fit(label, ts(18) if r.size.y >= 40 else ts(15), r.size.x - 10, primary)
	var lines := wrap_lines(label, sz, r.size.x - 10, primary)
	var h := lines.size() * sz * line_h(lines.size())
	_probe_btn_label = true   # 版面檢查：這段是按鈕自己的標籤（不用位置猜，Antigravity 實作第 2 輪抓到猜錯的情況）
	_probe_btn_rect = r
	_text(r.get_center() - Vector2(0, h / 2 - sz * 0.03), "\n".join(lines), sz, Color.WHITE if enabled else Color(1, 1, 1, 0.4), true, primary)
	_probe_btn_label = false

## 主按鈕的流光（可關）。
func _btn_shine(r: Rect2) -> void:
	if bool(Save.s("reduce_fx")):
		return
	var k := fposmod(time * 0.45, 1.0)
	if k > 0.5:
		return
	var x: float = r.position.x + (r.size.x + 40.0) * (k * 2.0) - 40.0
	var x0 := maxf(x, r.position.x + 3)
	var x1 := minf(x + 26.0, r.end.x - 3)
	if x1 > x0:
		draw_rect(Rect2(x0, r.position.y + 3, x1 - x0, r.size.y - 6), Color(1, 1, 1, 0.13))

## 圓角方塊（StyleBox 快取，不每幀配新物件）。
func _box(r: Rect2, bg: Color, border := Color(0, 0, 0, 0), radius := 6.0, bw := 0.0) -> void:
	var k := "%s|%s|%d|%d" % [bg.to_html(), border.to_html(), int(radius), int(bw * 10)]
	var sb: StyleBoxFlat = _sb_cache.get(k)
	if sb == null:
		sb = StyleBoxFlat.new()
		sb.bg_color = bg
		sb.border_color = border
		sb.set_corner_radius_all(int(radius))
		sb.set_border_width_all(int(ceilf(bw)))
		sb.anti_aliasing = true
		_sb_cache[k] = sb
	draw_style_box(sb, r)

func _icon(name: String, c: Vector2, s: float, col := Color.WHITE) -> void:
	Icons.draw(self, name, c, s, col)

## 羊皮紙標題緞帶：畫面標題統一用它。
func _h1(center: Vector2, s: String, maxw := 0.0) -> void:
	var sz := tz("H1")
	var w := minf(_width(s, sz, true) + 72.0, maxw if maxw > 0.0 else 900.0)
	var r := Rect2(center.x - w / 2, center.y - 2, w, sz * 1.45)
	var notch := 14.0
	for sgn in [-1.0, 1.0]:
		var ex: float = r.position.x if sgn < 0 else r.end.x
		draw_colored_polygon(PackedVector2Array([Vector2(ex - sgn * 4, r.position.y + 6), Vector2(ex + sgn * 20, r.position.y + 6), Vector2(ex + sgn * (20 - notch), r.get_center().y + 3), Vector2(ex + sgn * 20, r.end.y + 2), Vector2(ex - sgn * 4, r.end.y + 2)]), TH_PARCH.darkened(0.28))
	_box(r, TH_PARCH, TH_PARCH.darkened(0.45), 4.0, 2.0)
	_text(center + Vector2(0, sz * 0.07), s, sz, TH_INK, true, true, maxf(w - 20.0, 100.0))

## 安靜的小按鈕（第七輪 N6）：點擊框維持可點的大小，平常只畫一個小記號，滑過才亮。
func _btn_quiet(r: Rect2, label: String, action: Callable) -> void:
	var idx := _btns.size()
	_btns.append({"r": r, "cb": action, "en": true})
	var hot := (r.has_point(mouse) and not pad_mode) or (pad_mode and idx == _focus)
	var c := r.end - Vector2(12, 12)
	draw_circle(c, 9.0, Color(ACCENT, 0.9) if hot else Color(0, 0, 0, 0.55), true, -1.0, true)
	if layout_probe:
		probe_btns.append(r)
		probe_ctrls.append(r)
	var sz := ts(14)
	_probe_btn_label = true
	_probe_btn_rect = r
	_text(c - Vector2(0, sz * 0.62), label, sz, Color.BLACK if hot else Color(1, 1, 1, 0.8), true, true)
	_probe_btn_label = false


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
	draw_rect(Rect2(0, 0, 1280, 800), Color(0, 0, 0, 0.62))
	_box(r.grow(6), Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), 14.0)      # 陰影
	_box(r, PANEL, TH_EDGE, 10.0, 3.0)
	_box(r.grow(-5), Color(0, 0, 0, 0), Color(0, 0, 0, 0.35), 7.0, 1.0)
	# 木紋：固定幾條淡線
	var n := int(r.size.y / 46.0)
	for k in n:
		var y := r.position.y + 24.0 + k * 46.0 + float((k * 37) % 13)
		draw_line(Vector2(r.position.x + 12, y), Vector2(r.end.x - 12, y + float((k * 13) % 5) - 2.0), Color(1, 0.85, 0.6, 0.022), 2.0)
	for c in [r.position + Vector2(11, 11), Vector2(r.end.x - 11, r.position.y + 11), Vector2(r.position.x + 11, r.end.y - 11), r.end - Vector2(11, 11)]:
		draw_circle(c, 3.2, TH_EDGE, true, -1.0, true)
		draw_circle(c - Vector2(0.8, 0.8), 1.3, TH_PARCH, true, -1.0, true)


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
	if sprites != null and sprites.is_ready(cbm()) and sprites.has_type(type):
		sprites.draw_unit(self, p, type, team, face, walk, atk, hurt, alpha, t, scale, mood, lean, crouch, cbm(), variant)
	else:
		Art.unit(self, p, type, team, face, walk, atk, hurt, alpha, t, scale, cbm(), mood, lean, crouch, variant)

## 在一個框（或圓）的正中間畫一隻兵（使用者回報：圖鑑頁籤的人物沒有在格子正中間）。
## 角色的腳在原點、頭頂約在 -50（騎兵含騎士約 -54），視覺中心在腳上方 24（騎兵 26）× 縮放。
static func unit_center_feet(center: Vector2, type: int, scale: float) -> Vector2:
	return center + Vector2(0, (26.0 if type == D.CAVALRY else 24.0) * scale)

func _unit_in(r: Rect2, type: int, team: int, alpha := 1.0, scale := 0.6) -> void:
	Art.unit(self, unit_center_feet(r.get_center(), type, scale), type, team, 1.0, 0.0, 0.0, 0.0, alpha, time, scale, cbm())

var ring_shadow := 0.0   # V1.1 C6：亮色地圖（冰原）額外加深腳底影子；0＝不加

func _ring(p: Vector2, team: int, type: int, scale := 1.0) -> void:
	if ring_shadow > 0.0:
		var sh := PackedVector2Array()
		for i in 16:
			var an := i * TAU / 16.0
			sh.append(p + Vector2(cos(an) * 17.0, 3.0 + sin(an) * 7.0) * Vector2(scale, scale) + Vector2(0, 0))
		draw_colored_polygon(sh, Color(0.05, 0.08, 0.15, ring_shadow))
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
		Mode.VS_AI:
			var dsp = get("daily_spec")
			if dsp is Dictionary and not dsp.is_empty():
				return "%s・%s" % [L.t("menu_daily"), L.t("daily_mut_%d" % int(dsp["mut"]))]   # V1.1 D2
			return "%s・%s" % [L.t("menu_vs_ai"), L.t(["diff_easy", "diff_normal", "diff_hard"][difficulty])]
		Mode.DUEL: return "%s・%s" % [L.t("menu_duel"), L.t("rule_custom", [rules.turns]) if duel_rule == "custom" and rules != null else L.t("rule_" + duel_rule)]
		Mode.TUTORIAL: return L.t("menu_tutorial")
		Mode.PUZZLE: return L.t("menu_puzzle")
		Mode.GAUNTLET: return L.t("menu_gauntlet")
	return ""


## 戰鬥播完（含結算延遲）之後要做的事；由 game_screens 在 _ready 設定（S8：取代基底的空函式）
var on_battle_finished: Callable = func(): pass
