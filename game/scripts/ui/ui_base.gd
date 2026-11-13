extends Node2D
## 《落子無悔》UI 基底：共用常數、狀態、按鈕、文字、焦點、提示（第二輪方案 R2 從 main.gd 拆出）。
## 繼承鏈：ui_base → battle_view（戰場與演出）→ game_screens（狀態機與各畫面）→ main（宣傳工具：截圖、膠囊、影片）。
## 戰鬥結果完全由 scripts/core/battle_sim.gd 決定；這裡只負責演出（插值、特效、慢動作、鏡頭、聲音），不影響勝負。
## UI 是自繪的「即時模式按鈕」，同時支援滑鼠、鍵盤、手把（焦點導航）。

const D = preload("res://scripts/core/unit_defs.gd")
const BgPool = preload("res://scripts/game/bg_pool.gd")
var bg = BgPool.new()   # 1.1.0 N6：背景工作共用生命週期（覆盤、GIF、教練、三考、出題碼）
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
# V1.5.2 間距階（docs/ui-layout-rules.md）：4／8／12／16／24／32／48
const GAP_XS := 4.0
const GAP_S := 8.0
const GAP_M := 12.0
const GAP_L := 16.0
const GAP_XL := 24.0
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
const BossD = preload("res://scripts/core/boss_defs.gd")
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
	var top := 0.0
	if k > 1.0:
		# 1.1.0 H5：小地圖（12×7）放大後，第一排的兵頭頂會超出場地上緣壓到框。放大時上方留一點頭頂空間（只改畫面；
		# 點擊用同一個轉換的反矩陣，自動對齊）
		k = minf(FIELD.x / fld_size.x, (FIELD.y - HEAD_ROOM) / fld_size.y)
		top = HEAD_ROOM * 0.5
	return Transform2D(0.0, Vector2(k, k), 0.0, ORIGIN + (FIELD - fld_size * k) / 2.0 + Vector2(0, top) - ORIGIN * k)

const HEAD_ROOM := 36.0

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
const PAL = preload("res://scripts/ui/palette.gd")   # 1.3.0 §4 色票單一來源
const UI_BG := PAL.UI_BG
const PANEL := PAL.PANEL
const ACCENT := PAL.ACCENT
## V1.2.1 F5：次要字用不透明暖灰（原本是白色 50～80% 透明，疊在木紋上對比只有 2～3）
const TXT_DIM := PAL.TXT_DIM
# V9 P5 設計系統：胡桃木為底（白字才讀得清楚），羊皮紙只用在標題緞帶與重點卡片
const TH_WOOD := PAL.TH_WOOD
const TH_WOOD_L := PAL.TH_WOOD_L
const TH_WOOD_D := PAL.TH_WOOD_D
const TH_EDGE := PAL.TH_EDGE
const TH_ACTIVE := PAL.TH_ACTIVE
const TH_PARCH := PAL.TH_PARCH
const TH_INK := PAL.TH_INK
const TH_PRIMARY := PAL.TH_PRIMARY
const SP := 8.0        # 間距基準
const Icons = preload("res://scripts/ui/icons.gd")
var _sb_cache := {}
var last_btn_enabled := true   # 上一顆 _btn 實際是否可按（版面檢查的停用狀態會強制停用；卡片內文字要跟著變暗）
var last_btn_paper := false   # 上一顆 _btn 實際有沒有畫成紙面（呼叫端決定裡面的字要不要墨色）
var btn_paper := false   # V1.2.1 R1：下一顆 _btn 畫紙面（呼叫端設、用完還原）
var btn_ring_clip := Rect2(1, 1, 1278, 798)   # V1.5.2：加強焦點外圈只畫在這個範圍內（戰場頂列設成頂列那一條，不蓋到下面的剩餘隻數）
var btn_hit_min := 0.0   # V1.5.2：下一顆 _btn 的點擊區至少這麼高（可見面不變；大廳 36～40 高的小鈕擴到 44）
var probe_hits: Array = []   # V1.5.2：有擴點擊區的按鈕（版面檢查驗 ≥44）
var btn_deco := Callable()   # V1.5.2 L2：下一顆 _btn 在底面之後、焦點框之前呼叫 btn_deco.call(面框)（書籤這類依附裝飾；呼叫端設、用完還原）
var _probe_glyph := false
var _probe_anim := false   # V1.2.1：淡入淡出中的特效字（不檢查對比）
var _probe_dis := false   # V1.2.1：版面檢查：這段字屬於停用的按鈕（停用另報，WCAG 豁免）   # V1.2.1：鍵帽字母等符號，版面檢查不算字級
var probe_missing: Array = []   # V1.2.1：版面檢查期間找不到的材質
var probe_boxes: Array = []   # V1.2.1 F1：版面檢查用，九宮格方塊（字不能壓進外圈斜邊）
var btn_cloth := ""   # 1.2.0 §1.3：設了就畫布標（"tab_indigo" 選中、"tab_linen" 未選、"tab_madder" 警示）；畫完一顆呼叫端要清回 ""
var _ink_keep_a := false   # 1.2.0：戰場跳字轉墨色時保留原透明度（淡出要和紙條同步，Codex cat04 #2）
var _hand_mode := false   # 1.2.0：畫老闆便條時用手寫字
var _ink_mode := false   # V1.2 C1/C2：在羊皮紙頁上畫字時，淺色字自動換成墨色
var _hover_key := -1
var _trans_gen := -1
var _trans_t := -10.0
var _hover_now := -1
const UNIT_SCALE := 0.92
## V1.2 A2／B1：文字描邊與陰影的墨色（深焦茶，取代純黑）
const INK := PAL.INK
const INK_SHADOW := PAL.INK_SHADOW

var font: Font
var font_bold: Font
var font_display: Font = null   # 1.2.0：工藝字型時的 D／DX 展示大字（ThenKhung）
var font_craft := false          # 1.2.0：目前是不是工藝字型
var font_title: Font          # 第五輪：標題字 UoqMunThenKhung（只用在 ≥H2 的粗體、沒有數字的字串）

## 第五輪字級表（§4.2）：基準 1280×800。只允許表內的值；125%／150% 非線性（大字少放大、內文多放大）。
## 1.2.0 §3.1 字級表 2.0：整表放大一級（不縮字），新增 T「書名大字」（畫面主標，手寫字型）；D／DX 不變。
const TYPE_SCALE := {
	100: {"D": 64, "DX": 84, "T": 44, "H1": 34, "H2": 24, "B": 18, "S": 16, "C": 15},
	125: {"D": 70, "DX": 92, "T": 48, "H1": 38, "H2": 28, "B": 22, "S": 19, "C": 18},
	150: {"D": 70, "DX": 92, "T": 48, "H1": 38, "H2": 30, "B": 25, "S": 22, "C": 21},
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
const SPEEDS := [0.25, 0.5, 1.0, 2.0, 4.0, 8.0]   # V1.5.1：設定、戰鬥中速度鈕、重播速度列共用一張表

## 速度表上往快（d＝+1）或往慢（-1）一格；不在表上的值先對到最接近的那格
static func speed_step(cur: float, d: int) -> float:
	var i := 0
	for k in SPEEDS.size():
		if absf(float(SPEEDS[k]) - cur) < absf(float(SPEEDS[i]) - cur):
			i = k
	return float(SPEEDS[clampi(i + d, 0, SPEEDS.size() - 1)])
var toast_t := 0.0
var toast_born := 0.0   # V1.5：提示出現的時間（手動關：剛出現 0.3 秒內的點擊不算關掉）

## 提示設成「手動關」時，點滑鼠或按任何鍵收起（剛出現的不算，免得觸發它的那一下就把它關掉）
func _toast_dismiss() -> void:
	if toast_t > 1.0 and int(Save.s("toast_mult")) == 0 and time - toast_born > 0.3:
		toast_t = 0.4
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
	if bool(Save.s("reduce_motion")) and k in ["shake", "slowmo"]:
		return false   # V1.5：減少動態＝不震、不自動慢動作
	return bool(Save.s(k)) and not bool(Save.s("reduce_fx"))

var seek_target := -1      # 第七輪 M3：時間軸分批跳轉的目標
var replay_snap := {}      # 第七輪 A9：進重播前的結算畫面，返回時原樣還原（不重算、不寫存檔）
var replay_marks: Array = []   # 第七輪 A7：重播時間軸的關鍵時刻
var replay_bm: Array = []      # 1.2.0 §11.2 書籤：[{t, kind（death／break）, team}]（重播預跑時收）
const BM = preload("res://scripts/game/bookmarks.gd")
const TMC = preload("res://scripts/game/fork_compare.gd")
const Frags = preload("res://scripts/ui/battle/frags.gd")
var frags = Frags.new()   # 1.2.0 §8.2 材料碎片（和 FX_CAP 分開計數）
var present_debt := 0.0   # 1.2.0 §9.6：命中停頓欠展示時鐘多少秒（之後追回）
## 碎片開不開：減少特效、簡化畫面、4 倍速以上都不掉碎片（純裝飾）
func _frags_on() -> bool:
	return not bool(Save.s("reduce_fx")) and not bool(Save.s("plain_ui")) and speed < 4.0
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
var proj_tgt := {}       # V1.5：遠程（弓箭手、投彈兵、骷髏法師、醫者）id → {命中 tick: 目標 id}，畫面在命中前把飛行物飛完
var atk_hit := {}         # 單位 id → 命中 tick 的序列（最多留 4 筆）； 單位 id → 下一次（或最近一次）命中的模擬 tick，前搖從命中前 2 tick 開始
var prev_pos := {}
var accum := 0.0
var speed := 1.0
var slow_used := false
var final_used := false   # 第十輪 F1
var pinch_zoom := 1.0             # V1.4 #18：雙指縮放戰場（1＝不縮；戰鬥中蓋過自動全景）
var pinch_center := Vector2.ZERO
var tm_ghost_on := true       # 1.2.0 §11.3：G 切換原本時間線的白圈
var tm_ghost = null           # V1.4 #1 時光機：播放「如果」時，原本那條時間線同步跑的模擬（畫淡圈）
var last_kill := [-1, -10.0]   # V1.3.1 P2：最近一次擊倒 [擊倒者 id, 時間]
var last_hitter := {}          # 目標 id → 最後打到它的 id
var key_used := false     # V1.3 C4：這場的關鍵時刻（第一次破陣）用過了
var key_t := -10.0
var key_p := Vector2.ZERO
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
# V1.5.2 排版幾何探針（scripts/ui/layout_rules.gd 檢查）：_panel、_h1 自動登記；依附裝飾、同欄對齊、例外由畫面宣告
var probe_panels: Array = []
var probe_ribbons: Array = []
var probe_decos: Array = []
var probe_aligns: Array = []
var probe_need := {}   # 這一幀畫面宣告「至少要登記到幾個」的角色（漏登記守衛），例如大廳選了預設就要有 1 條書籤

func probe_reset_geom() -> void:
	probe_need = {}
	probe_hits.clear()
	probe_panels.clear()
	probe_ribbons.clear()
	probe_decos.clear()
	probe_aligns.clear()

## 依附裝飾（書籤、徽章…）：r＝裝飾本體、host＝它依附的元件框、edge＝貼齊的邊
func probe_deco(kind: String, r: Rect2, host: Rect2, edge := "top") -> void:
	probe_decos.append({"id": "%s#%d" % [kind, probe_decos.size()], "kind": kind, "r": r, "host_r": host, "edge": edge})

## 同一欄的元件共用中線（R10）
func probe_align(id: String, rects: Array, tol := 1.0) -> void:
	if layout_probe:
		probe_aligns.append({"id": id, "rects": rects, "tol": tol})

## V1.6 #4 R5：同列卡片，cards＝[[圖示框, 標題框, 正文框], …]，同一部件的上緣要對齊
func probe_cards(id: String, cards: Array, tol := 1.0) -> void:
	if layout_probe:
		probe_aligns.append({"id": id, "cards": cards, "tol": tol})

## 最近登記的面板：宣告例外（寫理由，報告會列出）或改用欄中線（三欄畫面的操作列）
func probe_skip(rule: String, why: String) -> void:
	if layout_probe and not probe_panels.is_empty():
		probe_panels[-1]["skip"][rule] = why

## 多欄畫面：宣告各欄內容區；按鈕不能跨進別欄（同層互蓋，例如設定頁撤回鈕被說明欄蓋）
func probe_columns(id: String, cols: Array) -> void:
	if layout_probe:
		probe_aligns.append({"id": id, "cols": cols})

func probe_axis(x: float) -> void:
	if layout_probe and not probe_panels.is_empty():
		probe_panels[-1]["axis"] = x
var _probe_btn_label := false
var wax_face_cut := 0.0      # 1.3.0：主按鈕左側蠟封蓋住的寬度（這一顆按鈕畫字前用完就歸零）
var _probe_cell_id := ""     # 1.3.0 R11：格子身分（同一格子的字才合併量；Codex cat01 #4）
var _probe_cell_seq := 0
var _probe_face := Rect2()   # 1.3.0 R11：這段字所在格子的「畫出來的面」（按鈕面扣厚度、圓鈕的圓、宣告的格子）；空＝不是格子
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


## V1.2 A1：英數字型疊在中文字型上（中文缺字落到後備）。沒有英數字型檔時直接用中文字型。
func _latin_over(path: String, cjk: Font) -> Font:
	if ResourceLoader.exists(path):
		var lf = load(path)
		if lf is FontFile:
			var f2: FontFile = lf.duplicate()
			f2.fallbacks = [cjk]
			return f2
	return _tnum(cjk)

## 第五輪：數字用等寬（tnum），金幣、秒數、百分比跳動時不會左右晃。
func _tnum(f: Font) -> Font:
	var fv := FontVariation.new()
	fv.base_font = f
	fv.opentype_features = {TextServerManager.get_primary_interface().name_to_tag("tnum"): 1}
	return fv

## 第五輪：載入三種字型角色。標題字缺的字由介面字型 Bold 補。
## V1.2 A1：介面字＝「NTB Latin（Fredoka，英數、數字等寬）為主字型＋NTB Rounded（源泉圓體 TW）為後備」：
## 主字型只有拉丁字，中文自動落到後備，所以同一行裡英數用 Fredoka、中文用源泉圓體，不用拆段。
func _load_fonts() -> void:
	font_craft = false
	if str(Save.s("ui_font")) == "craft" and ResourceLoader.exists("res://fonts/NTBSans-R-sub.otf"):
		_load_fonts_craft()
		return
	var reg := _load_font("res://fonts/NTBRounded-R-sub.otf")
	var bold := _load_font("res://fonts/NTBRounded-B-sub.otf")
	# V1.4 #17：簡中用 Resource Han Rounded CN、日文用源泉圓體 JP（都是 OFL 子集）；缺字再落到繁中字型
	var alt: String = {"zh_CN": "SC", "ja": "JP"}.get(L.lang, "")
	if alt != "" and ResourceLoader.exists("res://fonts/NTBRounded%s-R-sub.otf" % alt):
		var r2 = load("res://fonts/NTBRounded%s-R-sub.otf" % alt)
		var b2 = load("res://fonts/NTBRounded%s-B-sub.otf" % alt)
		if r2 is FontFile and b2 is FontFile:
			r2 = r2.duplicate()
			b2 = b2.duplicate()
			r2.fallbacks = [reg]
			b2.fallbacks = [bold]
			reg = r2
			bold = b2
	font = _latin_over("res://fonts/NTBLatin-M-sub.ttf", reg)
	font_bold = _latin_over("res://fonts/NTBLatin-B-sub.ttf", bold)
	if ResourceLoader.exists("res://fonts/ThenKhung-sub.ttf"):
		var tk = load("res://fonts/ThenKhung-sub.ttf")
		if tk is FontFile:
			tk = tk.duplicate()   # 切語言時不要改到共用的資源（Antigravity v140-i4）
			tk.fallbacks = [bold]
			font_title = tk if alt == "" else bold   # 標題字只有繁中字形，簡中、日文的標題用圓體粗體（字形才一致）


## 1.2.0 §3.2：工藝風字型：正文 NTB Sans（思源黑體系，依語言 TC／SC／JP）＋英數 NTB Sans Latin（Source Sans 3），
## 標題（H1 以上、印章、老闆便條）NTB Title（霞鶩文楷，四語都有字形）；缺字照舊落到正文 Bold。
func _load_fonts_craft() -> void:
	var alt: String = {"zh_CN": "SC", "ja": "JP"}.get(L.lang, "")
	var reg := _load_font("res://fonts/NTBSans%s-R-sub.otf" % alt)
	var bold := _load_font("res://fonts/NTBSans%s-B-sub.otf" % alt)
	if alt != "":
		var r0 := _load_font("res://fonts/NTBSans-R-sub.otf")
		var b0 := _load_font("res://fonts/NTBSans-B-sub.otf")
		if reg is FontFile and bold is FontFile:
			reg = reg.duplicate()
			bold = bold.duplicate()
			reg.fallbacks = [r0]
			bold.fallbacks = [b0]
	# 缺字（✗✦ 這類符號，Codex cat02 #5）再落到經典圓體（它的子集有這些符號）
	var rr := _load_font("res://fonts/NTBRounded-R-sub.otf")
	var rb := _load_font("res://fonts/NTBRounded-B-sub.otf")
	if reg is FontFile:
		reg = reg.duplicate()
		reg.fallbacks = reg.fallbacks + [rr]
	if bold is FontFile:
		bold = bold.duplicate()
		bold.fallbacks = bold.fallbacks + [rb]
	font = _latin_over("res://fonts/NTBSansLatin-R-sub.ttf", reg)
	font_bold = _latin_over("res://fonts/NTBSansLatin-B-sub.ttf", bold)
	font_title = font_bold
	font_craft = true
	font_display = null
	if ResourceLoader.exists("res://fonts/ThenKhung-sub.ttf"):
		var tk2 = load("res://fonts/ThenKhung-sub.ttf")
		if tk2 is FontFile:
			tk2 = tk2.duplicate()
			tk2.fallbacks = [bold]
			font_display = tk2
	if ResourceLoader.exists("res://fonts/NTBTitle-sub.ttf"):
		var tt = load("res://fonts/NTBTitle-sub.ttf")
		if tt is FontFile:
			tt = tt.duplicate()
			tt.fallbacks = [bold]
			font_title = tt


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
	var tm := int(Save.s("toast_mult"))
	toast_t = 2.0 * tm if tm > 0 else 600.0   # V1.5：提示停留 標準／加長／很長／手動關（點一下才收）
	toast_born = time
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
	if _hand_mode and font_title != null:
		return font_title   # 1.2.0：老闆便條、印章用手寫字（憲法 6：只放建議，不承載數值）
	if font_craft:
		# 1.2.0（Codex cat02 #3）工藝字型的分工：D／DX 展示大字＝ThenKhung（logo 氣質不變）；H1、T＝手寫楷體；H2 以下＝正文黑體
		if bold and not bool(Save.s("plain_titles")) and not _has_digit(s):
			if font_display != null and size >= tz("D"):
				return font_display
			if font_title != null and size >= tz("H1"):
				return font_title
		return font_bold if bold else font
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
const NO_LINE_HEAD := "。，、）」』！？；：%”’ぁぃぅぇぉっゃゅょゎァィゥェォッャュョヮヵヶーゝゞヽヾ・"

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
				# V1.4 #17：日文另加小假名、長音、中黑點不放行首；簡中的右引號也算
				if tok.length() == 1 and NO_LINE_HEAD.contains(tok) and cur.length() > 1 and cur.unicode_at(cur.length() - 1) >= 0x2E80:
					# 往回多帶幾個字，直到新的一行開頭不是禁則字（「ュー」這種連續的也處理，Codex v140-i4）；最多帶 4 個
					var n := 1
					while n < 4 and n < cur.length() - 1 and NO_LINE_HEAD.contains(cur[cur.length() - n]) and cur.unicode_at(cur.length() - n - 1) >= 0x2E80:
						n += 1
					out.append(cur.substr(0, cur.length() - n).strip_edges(false, true))
					cur = cur.substr(cur.length() - n) + tok
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


## V1.6.1 A8：焦點框平滑移動
const FOCUS_GLIDE := 0.08
var fg_from := Rect2()
var fg_to := Rect2()
var fg_at := -9.0
func _focus_glide(rd: Rect2) -> Rect2:
	if layout_probe or not bool(get("pad_mode")) or bool(Save.s("reduce_motion")):
		fg_to = rd
		fg_at = -9.0
		return rd
	if not rd.is_equal_approx(fg_to):
		var quick := time - fg_at < 0.15   # 連續撥動：直接跳，不黏
		fg_from = rd if (quick or fg_to.size == Vector2.ZERO) else _glide_now()
		fg_to = rd
		fg_at = time
	return _glide_now()

func _glide_now() -> Rect2:
	var k := clampf((time - fg_at) / FOCUS_GLIDE, 0.0, 1.0)
	k = 1.0 - (1.0 - k) * (1.0 - k)
	return Rect2(fg_from.position.lerp(fg_to.position, k), fg_from.size.lerp(fg_to.size, k))

var mag_focus := Vector2(-1, -1)   # V1.6.1 F4：手把模式時放大鏡跟著焦點按鈕（不用另外的鍵，不和 L3 提示衝突）
func mag_point() -> Vector2:
	return mag_focus if bool(get("pad_mode")) else get("mouse")

var mag_on := false      # V1.6 #7 文字放大鏡：這一幀游標指到的介面字
var mag_hit: Array = []
## 1.3.0 R11 光學置中：一行字的實際墨跡框（TextServer 的字形點陣框聯集，含後備字型），相對於基線左端。快取。
static var _ink_cache := {}
static func ink_line(fnt: Font, s: String, size: int) -> Rect2:
	var k := "%d|%d|%s" % [fnt.get_instance_id(), size, s]
	if _ink_cache.has(k):
		return _ink_cache[k]
	var tsv := TextServerManager.get_primary_interface()
	var rid := tsv.create_shaped_text()
	tsv.shaped_text_add_string(rid, s, fnt.get_rids(), size)
	var pen := 0.0
	var out := Rect2()
	var have := false
	for g in tsv.shaped_text_get_glyphs(rid):
		var frid: RID = g.get("font_rid", RID())
		var idx: int = int(g.get("index", 0))
		var fs := Vector2i(int(g.get("font_size", size)), 0)
		if frid.is_valid() and idx > 0:
			tsv.font_render_glyph(frid, fs, idx)
			var gsz: Vector2 = tsv.font_get_glyph_size(frid, fs, idx)
			if gsz.x > 0.0 and gsz.y > 0.0:
				var gr := Rect2(Vector2(pen, 0.0) + (g.get("offset", Vector2.ZERO) as Vector2) + tsv.font_get_glyph_offset(frid, fs, idx), gsz)
				out = gr if not have else out.merge(gr)
				have = true
		pen += float(g.get("advance", 0.0))
	tsv.free_rid(rid)
	if not have:
		out = Rect2(0.0, -size * 0.8, pen, size * 0.98)   # 沒有墨跡（空白）：退回名目字形框
	if _ink_cache.size() > 4000:
		_ink_cache.clear()
	_ink_cache[k] = out
	return out

## 整段（可多行，置中排）的墨跡框，相對於 _text(p, …, center=true) 的 p。
func label_ink(s: String, size: int, bold := false) -> Rect2:
	var lines := s.split("\n")
	var out := Rect2()
	var have := false
	for i in lines.size():
		if lines[i].strip_edges() == "":
			continue   # 空白行保留行距、但不算墨跡（Codex cat01 #3：不然 "\n開始" 會依空白框置中）
		var fnt := _font_for(lines[i], size, bold)
		var w := fnt.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var q := Vector2(-w / 2, i * size * line_h(lines.size()) + size * 0.85)
		var r := ink_line(fnt, lines[i], size)
		r.position += q
		out = r if not have else out.merge(r)
		have = true
	if not have:
		out = Rect2(0.0, size * 0.05, 0.0, size * 0.98)   # 整段空白：名目框（不影響任何格子）
	return out

## 讓一段置中字的墨跡中心落在格子面 face 的中心：回傳要傳給 _text 的 p。
func ink_center_p(face: Rect2, s: String, size: int, bold := false, pad := 5.0) -> Vector2:
	var p := face.get_center() - label_ink(s, size, bold).get_center()
	# 墨跡置中後，字的排版寬（含全形標點的留白）不能跑出格子面（日文 150%「（…）」右側留白大，墨跡中心偏左）
	var aw := 0.0
	for ln in s.split("\n"):
		aw = maxf(aw, _font_for(ln, size, bold).get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	if pad >= 0.0 and aw > 0.0:
		var lo := face.position.x + pad + aw / 2.0
		var hi := face.end.x - pad - aw / 2.0
		p.x = clampf(p.x, lo, hi) if lo <= hi else face.get_center().x
	return p

## 宣告「接下來畫的字在這個格子裡」（R11）：非按鈕的格子（價錢小方塊、徽章、分頁字）用。
func probe_cell_begin(face: Rect2) -> void:
	_probe_face = face
	_probe_cell_seq += 1
	_probe_cell_id = "cell%d" % _probe_cell_seq

func probe_cell_end() -> void:
	_probe_face = Rect2()
	_probe_cell_id = ""

func _text(p: Vector2, s: String, size: int, c: Color, center := false, bold := false, maxw := 0.0, outline := Color(0, 0, 0, -1)) -> void:
	if _ink_mode:
		c = Color(_ink(c), c.a) if _ink_keep_a else _ink(c)
	elif outline.a < 0.0 and not (size >= 24 or (bold and size >= 19)) and c.s >= 0.25 and not (c.get_luminance() < 0.35 and c.s < 0.8):   # 深色低彩度的浮雕字不動
		c = Color(_legible(Color(c, 1.0)), c.a)   # V1.2.1 F5：深描邊上的彩色小字自動提亮到 4.5:1
	if maxw > 0.0:
		size = fit(s, size, maxw, bold)
	var lines := wrap_lines(s, size, maxw, bold) if maxw > 0.0 else s.split("\n")
	for i in lines.size():
		var fnt := _font_for(lines[i], size, bold)
		var w := fnt.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x if center else 0.0
		var q := p + Vector2(-w / 2, i * size * line_h(lines.size()) + size * 0.85)
		if mag_on and _probe_ui and size < 26 and c.a > 0.3:
			var mw := w if center else fnt.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			if Rect2(q.x, q.y - size * 0.95, mw, size * 1.2).grow(4.0 if bool(get("pad_mode")) else 0.0).has_point(mag_point()):
				mag_hit = [lines[i], size, bold]
		var oc := Color(INK, c.a * 0.85) if outline.a < 0.0 else outline
		# V1.2：深色、低彩度的「墨色字」（印在紙或布條上）不描深邊，改淺色浮雕；先決定樣式再登記探針（Codex v120-impl2）
		var emboss := outline.a < 0.0 and (_ink_mode or (c.get_luminance() < 0.35 and c.s < 0.8))
		if emboss:
			oc = Color(0, 0, 0, 0)
		var ow := text_outline_w(size)
		var sh := text_shadow_dy(size)
		# 版面探針（第五輪補洞）：介面層與戰場層都量、低透明度（>0.05）也量；戰場字標 field
		# V1.2 A3：外框算進描邊外擴（左右上各半個描邊、下方再加陰影位移），換字與換框才不會靜靜爆框
		if layout_probe and c.a > 0.05 and lines[i].strip_edges() != "":
			var ww := fnt.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			var ex := ow * 0.5 if oc.a > 0.0 else 0.0
			# 直向：原本的框（1.1 倍字高）已經留了上下各約 0.05 字高的空，描邊與陰影只算超出的部分
			var ey := maxf(0.0, ex - size * 0.05)
			var eb := maxf(0.0, ey + (sh if oc.a > 0.0 else 0.0) - size * 0.05)
			probe_texts.append({"r": Rect2(q.x - ex, q.y - size * 0.85 - ey, ww + ex * 2.0, size * 1.1 + ey + eb), "size": size, "s": lines[i], "field": not _probe_ui, "a": c.a, "btn": _probe_btn_label, "own": _probe_btn_rect,
				"c": c, "oc": oc, "ow": ow if oc.a > 0.0 else 0.0, "bold": bold, "glyph": _probe_glyph, "anim": _probe_anim, "dis": _probe_dis,
				"gr": Rect2(q.x, q.y - size * 0.80, ww, size * 0.98),
				"face": _probe_face if _probe_face.size.x > 0.0 else null, "cell": _probe_cell_id, "ink": Rect2(q + ink_line(fnt, lines[i], size).position, ink_line(fnt, lines[i], size).size)})   # V1.2.1：字形框（不含描邊外擴、陰影與行距），九宮格內距用   # V1.2.1 F5：對比檢查要實際字色與描邊
		if emboss:
			draw_string(fnt, q + Vector2(0, 1), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1.0, 0.96, 0.86, 0.45 * c.a))
		if oc.a > 0.0:
			# V1.2 A3：先畫柔和的下方陰影，再畫深焦茶描邊（取代純黑），最後正文
			draw_string_outline(fnt, q + Vector2(0, sh), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size, ow, Color(INK_SHADOW, oc.a * 0.55))
			draw_string_outline(fnt, q, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size, ow, oc)
		draw_string(fnt, q, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)


## V1.2 A3：描邊依字級減薄（小字描太粗會糊）、陰影位移依字級（純函式，測試與探針共用）。
static func text_outline_w(size: int) -> int:
	return 3 if size <= 16 else (4 if size <= 22 else 5)

static func text_shadow_dy(size: int) -> float:
	return maxf(1.0, roundf(size / 12.0))


## 即時模式按鈕：每幀重新登記，滑鼠或焦點都能按。
## V9 P5 按鈕：圓角木牌、上緣高光、下緣陰影；按下縮一點回彈、懸停亮、焦點金框；主按鈕有流光。
## V1.2.1 F5：彩色小字對深焦茶描邊至少 4.5:1；不夠就一點點提亮（依顏色快取）。
static var _legible_cache := {}
static func _legible(c: Color) -> Color:
	var k := c.to_html()
	if _legible_cache.has(k):
		return _legible_cache[k]
	var out := c
	for i in 12:
		if _wcag(out, INK) >= 5.0:   # 目標 5:1（底色不一定是純描邊色，留餘裕）
			break
		out = out.lightened(0.08)
	_legible_cache[k] = out
	return out

## 對指定底色提亮到 5:1（黑底條上的隊色記號）。
static func _legible_on(c: Color, bg: Color) -> Color:
	var out := c
	for i in 14:
		if _wcag(out, bg) >= 5.0:
			break
		out = out.lightened(0.08)
	return out

static func _wcag(a: Color, b: Color) -> float:
	var f := func(v: float) -> float: return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
	var la: float = 0.2126 * f.call(a.r) + 0.7152 * f.call(a.g) + 0.0722 * f.call(a.b)
	var lb: float = 0.2126 * f.call(b.r) + 0.7152 * f.call(b.g) + 0.0722 * f.call(b.b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)

## V1.2：紙上墨色。灰白字→焦茶墨；亮彩字（金、綠、紅）壓暗成同色系的深色，透明度保留。
static func _ink(c: Color) -> Color:
	var lum := c.get_luminance()
	if lum < 0.45:
		return c
	var a := c.a if c.a < 0.45 else maxf(c.a, 0.85)   # V1.2.1 F5：紙上墨字至少 85%；很淡的裝飾（空星）保持淡
	if c.s < 0.25:
		return Color(INK, a)
	return Color(c.darkened(0.74), a)

func _btn(r: Rect2, label: String, action: Callable, enabled := true, primary := false, tint := Color(0, 0, 0, 0)) -> void:
	if layout_probe and get("shot_dir") != "" and (get("shot_state") as Dictionary).has("dis"):
		enabled = false   # V1.2.1：版面檢查的「停用」狀態：全部按鈕畫成停用，檢查停用樣式（手把流程不受影響）
	var idx := _btns.size()
	var hit := r
	if btn_hit_min > r.size.y:
		var dh := (btn_hit_min - r.size.y) * 0.5
		hit = r.grow_individual(0.0, dh, 0.0, dh)
		if layout_probe:
			probe_hits.append(hit)
	_btns.append({"r": hit, "cb": action, "en": enabled, "snd": "k_confirm" if primary else ("k_back" if label == L.t("back") or label == L.t("menu") else "k_click")})
	var hover := hit.has_point(mouse) and not pad_mode
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
	# V1.2 B3：按鈕下緣 3px 厚度（木牌的側面）；按下時往下沉、厚度消失
	var solid: bool = tint.a <= 0.0 or tint.a > 0.6
	if solid and r.size.y >= 20.0:
		# 厚度畫在按鈕框內（下緣 3px），命中框、探針與畫面一致（Codex v120-impl2）；按下時面板往下壓、厚度被蓋住
		_box(Rect2(rd.position, rd.size), Color(bg.darkened(0.55), 1.0), Color(0, 0, 0, 0), 7.0)
		rd = Rect2(rd.position + Vector2(0, 3.0 if pressed else 0.0), rd.size - Vector2(0, 3))
	var paper_face := btn_paper and enabled and not bool(Save.s("plain_ui"))
	# 1.2.0 §1.3：沒有自訂色的一般按鈕＝山毛櫸木牌（墨色字）；主要按鈕＝朱漆木牌＋左側紅蠟封；停用＝褪色木牌
	var cloth: bool = btn_cloth != "" and not paper_face and not bool(Save.s("plain_ui")) and _ui_tex(MAT[btn_cloth]) != null   # 1.2.0 §1.3 布標分頁
	# 1.2.0 第 4 大類 A10：「木色／選中」兩種標準色的按鈕也走木牌（原本是深色圓角塊，Antigravity cat03 #1）；選中＝暖一點的木牌＋朱砂框（不只靠顏色）。
	# 木色／選中但沒有自己標籤的按鈕（字由呼叫端另外畫白字：技能格、試煉卡、禁用卡、遠征獎勵卡）維持原本深色，避免白字落在淺木牌上（Codex cat04 #1）
	var sel_on: bool = tint == TH_ACTIVE
	var plaque: bool = not cloth and not paper_face and (tint.a <= 0.0 or ((sel_on or tint == TH_WOOD) and label != "")) and not bool(Save.s("plain_ui")) and r.size.y >= 26.0 and _ui_tex(MAT["plaque"]) != null
	last_btn_paper = paper_face or (plaque and not primary and enabled) or (cloth and btn_cloth == "tab_linen" and enabled)
	last_btn_enabled = enabled
	if cloth:
		var ct := Color.WHITE if enabled else Color(0.6, 0.6, 0.6, 0.8)
		if enabled and (hover or focus):
			ct = Color(1.12, 1.12, 1.12)
		_mat_box(rd, btn_cloth, ct)
		# 縫線：布標內緣一圈虛線（裝飾，不登記探針）
		var sc := Color(1, 1, 1, 0.35) if btn_cloth != "tab_linen" else Color(0.35, 0.25, 0.15, 0.4)
		var sr := rd.grow(-5)
		if layout_probe:
			probe_deco("stitch", sr, rd, "inside")   # 1.2.0 元件契約：縫線登記成宿主內的裝飾
		var dash := 6.0
		var xx := sr.position.x
		while xx < sr.end.x - dash:
			draw_line(Vector2(xx, sr.position.y), Vector2(xx + dash * 0.6, sr.position.y), sc, 1.0)
			draw_line(Vector2(xx, sr.end.y), Vector2(xx + dash * 0.6, sr.end.y), sc, 1.0)
			xx += dash
	elif plaque:
		var pt := Color(0.86, 0.36, 0.2) if primary else Color.WHITE
		if not enabled:
			pt = Color(0.78, 0.75, 0.7, 0.85)   # 停用＝褪色淺灰木牌（字照樣讀得到，不是一塊深色髒塊）
		elif sel_on and not primary:
			pt = Color(1.0, 0.84, 0.66)
		if enabled and (hover or focus):
			pt = Color(minf(pt.r * 1.1, 1.3), minf(pt.g * 1.1, 1.3), minf(pt.b * 1.1, 1.3))
		_mat_box(rd, "plaque", pt)
		if sel_on and enabled and tint.a > 0.0:
			draw_rect(rd.grow(-4 if rd.size.y >= 40.0 else -2), Color(Color("#9b281b"), 0.9), false, 2.5 if rd.size.y >= 40.0 else 1.5)   # 選中：朱砂框（矮按鈕框往外、變細，不壓到 150% 的字）
		if primary and enabled and rd.size.x >= 120.0:
			var wx := _ui_tex(MAT["wax_red"])
			var ws := minf(rd.size.y + 8.0, 46.0)
			# 長標籤時讓位（Antigravity cat02 #1）：字寬＋蠟封露出的部分放不下就不畫蠟封
			var lab_w := _width(label, ts(18), true)
			if wx != null and lab_w + ws * 0.9 <= rd.size.x - 12.0:
				var wr := Rect2(rd.position + Vector2(-ws * 0.35, (rd.size.y - ws) * 0.5), Vector2(ws, ws))
				wax_face_cut = maxf(0.0, wr.end.x - rd.position.x)   # 1.3.0 R11：蠟封蓋住的左邊不算字的格子面（字在看得到的木牌上置中；Antigravity cat01）
				# 深赤火漆＋金邊：和朱漆底拉開明度（Antigravity cat02 #1：紅疊紅看不清）
				draw_circle(wr.get_center() + Vector2(1.5, 2.0), ws * 0.44, Color(DIM_INK, 0.45), true, -1.0, true)
				draw_texture_rect(wx, wr, false, Color(0.62, 0.42, 0.42))
				draw_arc(wr.get_center(), ws * 0.4, 0.0, TAU, 28, Color("#d9b25a"), 1.6, true)
				if layout_probe:
					probe_deco("wax", wr, rd, "left")
	elif paper_face:
		# V1.2.1 R1：紙面卡片（例如已過關的殘局）；懸停時紙變亮
		_tex_box(rd, "paper", Color(1.12, 1.1, 1.04) if (hover or focus) else Color.WHITE)
		_box(rd, Color(0, 0, 0, 0), TH_EDGE.darkened(0.25), 7.0, 1.5)
	else:
		_box(rd, bg, TH_EDGE.darkened(0.25) if solid else Color(0, 0, 0, 0), 7.0, 1.5)
	if (tint.a <= 0.0 or tint.a > 0.6) and not paper_face and not plaque and not cloth:
		draw_line(rd.position + Vector2(6, 1.5), rd.position + Vector2(rd.size.x - 6, 1.5), Color(1, 1, 1, 0.16), 1.5)
		draw_line(rd.position + Vector2(6, rd.size.y - 1.5), rd.end - Vector2(6, 1.5), Color(0, 0, 0, 0.3), 2.0)
	if pressed:
		for k in 3:   # V1.2.1 R2：按下時上緣內陰影（像被壓進去）
			draw_rect(Rect2(rd.position + Vector2(3, 2 + k * 2.0), Vector2(rd.size.x - 6, 2.0)), Color(0, 0, 0, 0.22 - k * 0.07))
	if primary and enabled:
		_btn_shine(rd)
	if btn_deco.is_valid():
		btn_deco.call(rd)
	if focus:
		rd = _focus_glide(rd)   # V1.6.1 A8：手把焦點框滑過去（0.08 秒；連續撥動、減少動態、版面檢查時直接跳）
		mag_focus = r.get_center()
	if (focus or hover) and enabled and not plain_ui_now():
		# V1.2.1 R2：滑鼠懸停與手把焦點同一種樣式：深邊＋金亮邊（深邊讓金框在紙上也看得到，Codex v121-r2）
		_box(rd.grow(2.5), Color(0, 0, 0, 0), Color(INK, 0.7), 9.0, 1.5)
		_box(rd.grow(1), Color(0, 0, 0, 0), Color(ACCENT, 0.95 if focus else 0.75), 8.0, 2.5)
	elif focus:
		_box(rd.grow(1), Color(0, 0, 0, 0), ACCENT, 8.0, 3.0)
	if focus and enabled and bool(Save.s("focus_strong")):
		# V1.5.2：貼畫面邊的按鈕（戰場頂列）外圈往內收，整圈都看得到（不被畫面邊切掉）
		var scr := btn_ring_clip
		_box(rd.grow(5).intersection(scr), Color(0, 0, 0, 0), Color("#ffffff"), 10.0, 3.0)   # V1.5：加強焦點框（白色外圈）
		_box(rd.grow(8).intersection(scr), Color(0, 0, 0, 0), Color(INK, 0.9), 12.0, 2.0)
	if layout_probe:
		probe_btns.append(r)
		if label == "":
			probe_ctrls.append(r)   # 空白標籤的按鈕（卡片、頁籤）：裡面自己畫的字算按鈕內容
	# 1.2.0：按鈕字級看實際面高（扣下緣厚度與木牌毛邊）：放得下正文字就用正文字，不然用小一級（都在字級表內，比 1.1.0 同層大）
	var face_h: float = r.size.y - 3.0 - 6.0
	var sz := fit(label, ts(18) if r.size.y >= 40 and face_h >= ts(18) * 1.3 else ts(15), r.size.x - 10, primary)
	var lines := wrap_lines(label, sz, r.size.x - 10, primary)
	_probe_btn_label = true   # 版面檢查：這段是按鈕自己的標籤（不用位置猜，Antigravity 實作第 2 輪抓到猜錯的情況）
	_probe_btn_rect = r
	if wax_face_cut > 0.0:
		rd = rd.grow_individual(-wax_face_cut, 0.0, 0.0, 0.0)
		wax_face_cut = 0.0
	_probe_face = rd
	_probe_cell_id = "btn%d" % idx
	_probe_dis = not enabled
	var ink0 := _ink_mode   # 按鈕是木頭，字維持白色（紙面按鈕用墨色）
	_ink_mode = paper_face or (plaque and not primary and enabled) or (cloth and btn_cloth == "tab_linen" and enabled)   # 1.2.0：淺色木牌、原胚布用墨色字
	var lab := "\n".join(lines)
	# 1.3.0 R11：字的墨跡中心對準按鈕面中心（扣掉下緣厚度；按下時字跟著下沉）——光學置中，不是名目行高置中
	_text(ink_center_p(rd, lab, sz, primary), lab, sz, Color.WHITE if enabled else (Color(0.16, 0.11, 0.07, 0.62) if plaque else Color(1, 1, 1, 0.4)), true, primary)
	_ink_mode = ink0
	_probe_btn_label = false
	_probe_face = Rect2()
	_probe_cell_id = ""
	_probe_dis = false

static func plain_ui_now() -> bool:
	return bool(Save.s("plain_ui"))

## 主按鈕的流光（可關）。
func _btn_shine(r: Rect2) -> void:
	if bool(Save.s("reduce_fx")):
		return
	var k := fposmod(time * 0.45, 1.0)
	if k > 0.5:
		return
	var x: float = r.position.x + (r.size.x + 60.0) * (k * 2.0) - 30.0
	# V1.2：斜的、窄的、淡的流光（直的半透明帶在截圖裡像破圖）
	var sk := r.size.y * 0.5
	var pts := PackedVector2Array([Vector2(x, r.end.y - 3), Vector2(x + 14, r.end.y - 3), Vector2(x + 14 + sk, r.position.y + 3), Vector2(x + sk, r.position.y + 3)])
	var clip := PackedVector2Array()
	for pp in pts:
		clip.append(Vector2(clampf(pp.x, r.position.x + 3, r.end.x - 3), pp.y))
	if clip[1].x > clip[0].x or clip[2].x > clip[3].x:
		draw_colored_polygon(clip, Color(1, 1, 1, 0.09))

## V1.2 B3：材質貼圖（tools/gen/gen_ui_tex.py 生成）。木紋是灰階，用原本的底色染，配色不變、多了木紋與上亮下暗的斜角。
const TEX_WOOD := "res://art/ui/wood.png"
## 1.2.0 §1.3 元件庫 2.0 的材質（tools/gen/materials.py 產生，manifest：art/mat/manifest.json）
const MAT := {"plaque": "res://art/mat/nine_plaque.png", "card1": "res://art/mat/nine_card1.png", "card2": "res://art/mat/nine_card2.png",
	"card3": "res://art/mat/nine_card3.png", "walnut": "res://art/mat/tile_walnut.png", "tab_indigo": "res://art/mat/nine_tab_indigo.png",
	"tab_madder": "res://art/mat/nine_tab_madder.png", "tab_linen": "res://art/mat/nine_tab_linen.png", "wax_red": "res://art/mat/wax_red.png"}
const MAT_INSET := {"plaque": 3.0, "tab_indigo": 3.0, "tab_madder": 3.0, "tab_linen": 3.0, "card1": 6.0, "card2": 6.0, "card3": 7.0}   # 1.2.0：內容內距＝毛邊寬（不是 9 宮格邊界）
const MAT_MARGIN := {"plaque": 14.0, "card1": 20.0, "card2": 20.0, "card3": 22.0, "tab_indigo": 13.0, "tab_madder": 13.0, "tab_linen": 13.0}
## 1.2.0 §1.1 桌面世界：整個畫面底下是一張老胡桃木桌（螢幕座標，鏡頭之前畫）。
## 光從左上來：左上一層暖光、右下一層暖暗；四角暖暗角；桌上固定 5 件低彩度小物（不搶焦點）。簡化介面時退回平塗。
func _draw_desk() -> void:
	if bool(Save.s("plain_ui")):
		draw_rect(Rect2(0, 0, 1280, 800), Color("#3a281c"))
		return
	var wt := _ui_tex(MAT["walnut"])
	if wt == null:
		draw_rect(Rect2(0, 0, 1280, 800), Color("#3a281c"))
		return
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	draw_texture_rect(wt, Rect2(0, 0, 1280, 800), true, Color(0.78, 0.74, 0.7))
	# 主光（左上暖）與右下暗：兩個大三角形的頂點色漸層
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(1280, 0), Vector2(0, 800)]),
		PackedColorArray([Color(1.0, 0.86, 0.6, 0.16), Color(1.0, 0.86, 0.6, 0.0), Color(1.0, 0.86, 0.6, 0.0)]))
	draw_polygon(PackedVector2Array([Vector2(1280, 800), Vector2(1280, 0), Vector2(0, 800)]),
		PackedColorArray([Color(DIM_INK, 0.42), Color(DIM_INK, 0.0), Color(DIM_INK, 0.0)]))
	var vg := _ui_tex(TEX_VIGNETTE)
	if vg != null:
		draw_texture_rect(vg, Rect2(0, 0, 1280, 800), false, Color(0.11, 0.075, 0.05, 0.85))
	_desk_props()

## 桌上小物（固定位置、低彩度、一律在畫面邊角，UI 蓋在上面也沒關係）
func _desk_props() -> void:
	# 墨水瓶（左下）：深色玻璃＋左上高光＋軟木塞
	var ink := Vector2(46, 742)
	draw_circle(ink + Vector2(5, 7), 26.0, Color(DIM_INK, 0.45), true, -1.0, true)
	draw_circle(ink, 24.0, Color("#1f2430"), true, -1.0, true)
	draw_circle(ink - Vector2(8, 8), 6.0, Color(1, 1, 1, 0.18), true, -1.0, true)
	draw_rect(Rect2(ink - Vector2(7, 34), Vector2(14, 12)), Color("#9c7a52"))
	# 量尺（下緣，部分在畫面外）
	var rr := Rect2(420, 786, 440, 28)
	draw_rect(rr, Color("#c9a674"))
	for i in 45:
		draw_line(Vector2(rr.position.x + 6 + i * 9.6, rr.position.y), Vector2(rr.position.x + 6 + i * 9.6, rr.position.y + (8 if i % 5 == 0 else 4)), Color("#5a3f22", 0.8), 1.0)
	# 棋罐（右上）：木碗＋碗口暗面
	var bowl := Vector2(1244, 30)
	draw_circle(bowl + Vector2(5, 7), 34.0, Color(DIM_INK, 0.45), true, -1.0, true)
	draw_circle(bowl, 32.0, Color("#7a5434"), true, -1.0, true)
	draw_circle(bowl, 22.0, Color("#3e2a1a"), true, -1.0, true)
	draw_circle(bowl - Vector2(10, 10), 7.0, Color(1, 0.9, 0.7, 0.16), true, -1.0, true)
	# 筆記本一角（左上）
	var nb := PackedVector2Array([Vector2(-10, -10), Vector2(120, -10), Vector2(96, 54), Vector2(-10, 70)])
	draw_colored_polygon(nb, Color("#d9c9a8"))
	draw_line(Vector2(-10, 30), Vector2(104, 22), Color("#8b7355", 0.5), 1.0)
	draw_line(Vector2(-10, 46), Vector2(100, 38), Color("#8b7355", 0.5), 1.0)
	# 沙漏（右下）
	var hg := Vector2(1240, 752)
	draw_rect(Rect2(hg - Vector2(16, 32), Vector2(32, 5)), Color("#7a5434"))
	draw_rect(Rect2(hg + Vector2(-16, 27), Vector2(32, 5)), Color("#7a5434"))
	draw_colored_polygon(PackedVector2Array([hg + Vector2(-12, -27), hg + Vector2(12, -27), hg, hg + Vector2(12, 27), hg + Vector2(-12, 27), hg]), Color(0.85, 0.9, 0.95, 0.22))
	draw_colored_polygon(PackedVector2Array([hg + Vector2(-8, 27), hg + Vector2(8, 27), hg + Vector2(0, 12)]), Color("#d9b874"))

## 1.2.0 §12 老闆的便條：第一次進大廳、擺陣、結果時，跳一張紙卡（手寫字，只放建議、不放數值）；按「知道了」就不再出現。
## 是一個小的模態疊層（overlay＝boss_note），不蓋在按鈕上；截圖、版面檢查平常不跳（乾淨存檔每張都會跳），另拍一張專拍。
var note_key := ""
var note_ret := ""   # 便條疊在哪個疊層上（大廳本身是疊層 "lobby"）；關掉時還原（Codex cat03 #2）
func _boss_note(key: String, host := "") -> void:
	if overlay != host or shot_dir != "" or layout_probe:
		return
	if not preload("res://scripts/game/guide.gd").is_new(Save.data, "note_" + key):
		return
	note_key = key
	note_ret = host
	overlay = "boss_note"
	_focus = 0

func _close_boss_note() -> void:
	preload("res://scripts/game/guide.gd").see(Save.data, "note_" + note_key)
	Save.save_data()
	overlay = note_ret
	note_ret = ""

func _draw_boss_note() -> void:
	var w := 600.0
	var txt := L.t("bn_" + note_key)
	var sign := "—— " + L.t("ps_name_0")
	var sz := tz("H2")   # 手寫字在小字級會糊成黑體的樣子（Antigravity cat03 #4）→ 用 H2，自己斷行（不走 fit 縮字）
	_hand_mode = true
	var lines := wrap_lines(txt, sz, w - 72)
	_hand_mode = false
	var lh := sz * line_h(lines.size())
	var bh := maxf(44.0, tz("B") * 1.9)
	var P := modal_rect(w, 32.0 + lines.size() * lh + 8.0 + tz("B") * 1.4 + GAP_L + bh + 24.0)
	probe_panel(P)
	draw_rect(Rect2(P.position + Vector2(6, 9), P.size), Color(DIM_INK, 0.45))   # 落影（光源左上）
	if bool(Save.s("plain_ui")) or not _mat_box(P, "card1"):
		draw_rect(P, Color("#f5efe6"))
	# 兩段斜貼的紙膠帶（左上、右上）
	for tx in [P.position.x + 20, P.end.x - 92]:
		draw_colored_polygon(PackedVector2Array([Vector2(tx, P.position.y - 6), Vector2(tx + 72, P.position.y - 12), Vector2(tx + 76, P.position.y + 8), Vector2(tx + 4, P.position.y + 14)]), Color(0.93, 0.88, 0.7, 0.82))
	_ink_mode = true
	_hand_mode = true
	var y := P.position.y + 32.0
	for ln in lines:
		_text(Vector2(P.position.x + 36, y), ln, sz, INK)
		y += lh
	y += 8.0
	_text(Vector2(P.end.x - 36 - _width(sign, tz("B")), y), sign, tz("B"), Color(INK, 0.85))
	_hand_mode = false
	_ink_mode = false
	_btn(Rect2(640 - 80, P.end.y - 24 - bh, 160, bh), L.t("bn_ok"), _close_boss_note)   # 單顆底部按鈕置中（R4）；木牌（不是朱漆主按鈕，便條不該喧賓奪主）

## 憲法 3（禁純黑）：選單打開時的暗幕用暖暗墨色，不用 #000。
const DIM_INK := PAL.DIM_INK
func _dim(a: float) -> void:
	draw_rect(Rect2(0, 0, 1280, 800), Color(DIM_INK, a))
const TEX_FRAME := "res://art/ui/frame.png"
const TEX_GROOVE := "res://art/ui/groove.png"
const TEX_PAPER := "res://art/ui/paper.png"
const TEX_VIGNETTE := "res://art/ui/vignette.png"
var _tex_cache := {}

func _ui_tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path) if ResourceLoader.exists(path) else null
	if _tex_cache[path] == null and layout_probe and not path in probe_missing:
		probe_missing.append(path)
	return _tex_cache[path]

## V1.2：頂部資訊列：深木紋＋下緣一條亮線與落影（沒有貼圖時照舊平塗）。
func _hud_bar(r: Rect2) -> void:
	if bool(Save.s("plain_ui")) or not _tex_box(r.grow_individual(8, 8, 8, 0), "wood", Color(0.3, 0.21, 0.15, 0.97)):
		draw_rect(r, UI_BG)
		return
	draw_rect(Rect2(r.position.x, r.end.y - 2, r.size.x, 2), Color(0.55, 0.42, 0.28, 0.9))
	draw_rect(Rect2(r.position.x, r.end.y, r.size.x, 4), Color(0, 0, 0, 0.25))

## V1.2：木製框（九宮格、四角銅釘、中間透明），面板、戰場、大廳沙盤預覽共用。grow＝往外擴多少。
func _wood_frame(r: Rect2, grow := 8.0, key := "frame") -> void:
	var fx := _ui_tex(TEX_FRAME)
	if fx == null or bool(Save.s("plain_ui")):
		return
	var sb: StyleBoxTexture = _sb_cache.get(key)
	if sb == null:
		sb = StyleBoxTexture.new()
		sb.texture = fx
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			sb.set_texture_margin(side, 22.0)
		sb.draw_center = false
		_sb_cache[key] = sb
	draw_style_box(sb, r.grow(grow))

## 材質方塊：kind＝wood（染色）／groove（染色）／paper（原色）。沒有貼圖時退回平塗。
func _tex_box(r: Rect2, kind: String, tint := Color.WHITE) -> bool:
	if bool(Save.s("plain_ui")):
		# 1.2.0（Codex cat02 #8）：簡化介面一律退回平塗（同位置、同內距探針），不貼材質
		var flat: Color = {"wood": TH_WOOD, "groove": Color(0.12, 0.09, 0.07), "paper": Color("#efe4cc")}[kind]
		draw_rect(r, Color(flat.r * tint.r, flat.g * tint.g, flat.b * tint.b, tint.a))
		if layout_probe and minf(r.size.x, r.size.y) >= 20.0:
			var ins0: Array = {"wood": [3.0, 3.0, 3.0, 4.0], "paper": [5.0, 5.0, 5.0, 5.0], "groove": [3.0, 3.0, 3.0, 3.0]}[kind]
			probe_boxes.append({"r": r, "inner": r.grow_individual(-ins0[0], -ins0[1], -ins0[2], -ins0[3])})
		return true
	var path: String = {"wood": TEX_WOOD, "groove": TEX_GROOVE, "paper": TEX_PAPER}[kind]
	var tx := _ui_tex(path)
	if tx == null:
		return false
	tint = qcol(tint)   # V1.2.1 F1：量化後當鍵，淡出時不會每幀多一個樣式
	var k := "t|%s|%s" % [kind, tint.to_html()]
	var sb: StyleBoxTexture = _sb_cache.get(k)
	if sb == null:
		_sb_room()
		sb = StyleBoxTexture.new()
		sb.texture = tx
		var m := 10.0 if kind != "paper" else 14.0
		sb.texture_margin_left = m
		sb.texture_margin_right = m
		sb.texture_margin_top = m
		sb.texture_margin_bottom = m
		# 羊皮紙整張拉伸（紋理不能無縫平鋪，平鋪會出現直條接縫）；木紋、凹槽平鋪保持紋理比例
		var mode := StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH if kind == "paper" else StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
		sb.axis_stretch_horizontal = mode
		sb.axis_stretch_vertical = mode
		sb.modulate_color = tint
		_sb_cache[k] = sb
	draw_style_box(sb, r)
	if layout_probe and minf(r.size.x, r.size.y) >= 20.0:
		# V1.2.1 F1：登記材質的內容內距（gen_ui_tex.py 的實際斜邊：木紋上 3／下 4／左右 3，紙 5，凹槽 3），字不能壓進去
		var ins: Array = {"wood": [3.0, 3.0, 3.0, 4.0], "paper": [5.0, 5.0, 5.0, 5.0], "groove": [3.0, 3.0, 3.0, 3.0]}[kind]
		probe_boxes.append({"r": r, "inner": r.grow_individual(-ins[0], -ins[1], -ins[2], -ins[3])})
	return true

## 1.2.0 §1.3：元件庫 2.0 的材質框（9 宮格或平鋪）。kind 見 MAT；回傳有沒有畫（缺圖就退回呼叫端的平塗）。
func _mat_box(r: Rect2, kind: String, tint := Color.WHITE) -> bool:
	var tx := _ui_tex(MAT[kind])
	if tx == null:
		return false
	tint = qcol(tint)
	var k := "m|%s|%s" % [kind, tint.to_html()]
	var sb: StyleBoxTexture = _sb_cache.get(k)
	if sb == null:
		_sb_room()
		sb = StyleBoxTexture.new()
		sb.texture = tx
		var m: float = MAT_MARGIN.get(kind, 0.0)
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			sb.set_texture_margin(side, m)
		var tile: bool = not MAT_MARGIN.has(kind)
		sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE if tile else StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
		sb.axis_stretch_vertical = sb.axis_stretch_horizontal
		sb.modulate_color = tint
		_sb_cache[k] = sb
	draw_style_box(sb, r)
	if layout_probe and MAT_MARGIN.has(kind) and minf(r.size.x, r.size.y) >= 20.0:
		var ins: float = MAT_INSET.get(kind, 4.0)   # 毛邊實際寬度（materials.py 的 edge 減 2px 透明）：字不能壓進去
		probe_boxes.append({"r": r, "inner": r.grow(-ins)})
	return true

## V1.2.1 F1：樣式快取的顏色量化（透明度 16 級、RGB 8 位元），鍵和實際樣式用同一個值。
static func qcol(c: Color) -> Color:
	return Color(roundf(c.r * 255.0) / 255.0, roundf(c.g * 255.0) / 255.0, roundf(c.b * 255.0) / 255.0, roundf(clampf(c.a, 0.0, 1.0) * 15.0) / 15.0)

const SB_CACHE_MAX := 512
## 快取滿了整個清掉（用到再建；每個樣式只是幾個欄位，重建很便宜）。
func _sb_room() -> void:
	if _sb_cache.size() >= SB_CACHE_MAX:
		_sb_cache.clear()

## 圓角方塊（StyleBox 快取，不每幀配新物件）。
## V1.2 B3：夠大、夠不透明的實心方塊改用木紋材質（用 bg 染色），外框線另外畫在上面；小東西與半透明的陰影維持平塗。
func _box(r: Rect2, bg: Color, border := Color(0, 0, 0, 0), radius := 6.0, bw := 0.0) -> void:
	if bg.a >= 0.6 and minf(r.size.x, r.size.y) >= 20.0 and not bool(Save.s("plain_ui")) and _tex_box(r, "wood", Color(bg.r * 1.28, bg.g * 1.28, bg.b * 1.28, bg.a)):
		if bw > 0.0 and border.a > 0.0:
			_box(r, Color(0, 0, 0, 0), border, radius, bw)
		return
	draw_style_box(_flat_sb(bg, border, radius, bw), r)

## 平塗方塊的樣式（量化後快取；測試可以直接呼叫，不必在繪製階段）。
func _flat_sb(bg: Color, border: Color, radius: float, bw: float) -> StyleBoxFlat:
	bg = qcol(bg)
	border = qcol(border)
	var k := "%s|%s|%d|%d" % [bg.to_html(), border.to_html(), int(radius), int(bw * 10)]
	var sb: StyleBoxFlat = _sb_cache.get(k)
	if sb == null:
		_sb_room()
		sb = StyleBoxFlat.new()
		sb.bg_color = bg
		sb.border_color = border
		sb.set_corner_radius_all(int(radius))
		sb.set_border_width_all(int(ceilf(bw)))
		sb.anti_aliasing = true
		_sb_cache[k] = sb
	return sb

## V1.2 C2：8 格刻印能力條（取代細長滑桿）：凹槽底＋一格一格填色，最後一格依比例部分填。
func _seg_bar(r: Rect2, frac: float, col: Color, segs := 8) -> void:
	var gap := 2.0
	var sw := (r.size.x - gap * (segs - 1)) / segs
	var filled := clampf(frac, 0.0, 1.0) * segs
	for i in segs:
		var sr := Rect2(r.position.x + i * (sw + gap), r.position.y, sw, r.size.y)
		draw_rect(sr, Color(0.06, 0.04, 0.03, 0.75))
		draw_rect(Rect2(sr.position, Vector2(sw, 1.0)), Color(0, 0, 0, 0.5))
		var f := clampf(filled - i, 0.0, 1.0)
		if f > 0.0:
			var fr := Rect2(sr.position + Vector2(1, 1), Vector2((sw - 2.0) * f, sr.size.y - 2.0))
			draw_rect(fr, col)
			draw_rect(Rect2(fr.position, Vector2(fr.size.x, maxf(1.0, fr.size.y * 0.35))), Color(1, 1, 1, 0.28))

const ICON_SOLID := ["people", "cards", "robot", "gear", "shield", "heart", "star", "lock", "trophy", "flag", "skull", "book", "puzzle", "tower", "dice", "save"]   # 有實心面、放得下高光點的圖示

func _icon(name: String, c: Vector2, s: float, col := Color.WHITE) -> void:
	# V1.2 B4：圖示加深焦茶落影（像印上去的刻印），不再是平貼的單色圖形
	if _ink_mode:
		col = _ink(col)
	if col.a > 0.3 and s >= 14.0 and not bool(Save.s("plain_ui")) and not _ink_mode:   # 紙上的墨色圖示不厚塗（會糊成一團，Antigravity impl4）
		# V1.2 B4：Q 版厚塗刻印 ── 深焦茶粗外框（8 方向剪影）＋落影＋右下深一階的厚度（雙色塊）＋實心圖示左上高光點
		var ow := maxf(1.2, s * 0.06)
		var off := maxf(1.0, s * 0.07)
		Icons.force = Color(INK, col.a * 0.7)
		Icons.draw(self, name, c + Vector2(off, off) * 1.4, s, Icons.force)
		Icons.force = Color(INK, col.a)
		for k in 4:   # 四個斜角就夠成粗框（8 方向每幀太貴）
			var d := Vector2.from_angle(PI / 4.0 + k * TAU / 4.0) * ow * 1.15
			Icons.draw(self, name, c + d, s, Icons.force)
		var dk := Color(col.darkened(0.35), col.a)
		Icons.force = dk
		Icons.draw(self, name, c + Vector2(ow, ow) * 0.6, s, dk)
		Icons.force = Color(0, 0, 0, 0)
		Icons.draw(self, name, c, s, col)
		if name in ICON_SOLID:
			draw_circle(c + Vector2(-s * 0.2, -s * 0.22), maxf(1.2, s * 0.06), Color(1, 0.98, 0.9, 0.55 * col.a), true, -1.0, true)
		return
	Icons.draw(self, name, c, s, col)

## V1.4 #9 木座貼紙：木座右前方一枚小圓貼（隊伍無關的顏色＋白圖示）。on＝false 時淡掉（護符用掉了）。
func _sticker_badge(p: Vector2, st: int, scale := 1.0, on := true) -> void:
	var STK = preload("res://scripts/core/sticker_defs.gd")
	if st < 1 or st > STK.COUNT:
		return
	var c := p + Vector2(15, 5) * scale
	var a := 1.0 if on else 0.35
	draw_circle(c + Vector2(0, 1.2) * scale, 7.5 * scale, Color(0.1, 0.06, 0.03, 0.5 * a), true, -1.0, true)
	draw_circle(c, 7.0 * scale, Color(0.98, 0.94, 0.84, a), true, -1.0, true)
	draw_circle(c, 5.6 * scale, Color(Color(STK.COLORS[st]), a), true, -1.0, true)
	Icons.draw(self, STK.ICONS[st], c, 8.0 * scale, Color(1, 1, 1, a))

## 羊皮紙標題緞帶：畫面標題統一用它。回傳緞帶含尾的完整下緣（V1.5.2 L3：下方內容從「下緣＋GAP_L」起排）。
func _h1(center: Vector2, s: String, maxw := 0.0) -> float:
	var sz := tz("H1")
	var w := minf(_width(s, sz, true) + 72.0, maxw if maxw > 0.0 else 900.0)
	var r := Rect2(center.x - w / 2, center.y - 2, w, sz * 1.45)
	var notch := 14.0
	for sgn in [-1.0, 1.0]:
		var ex: float = r.position.x if sgn < 0 else r.end.x
		draw_colored_polygon(PackedVector2Array([Vector2(ex - sgn * 4, r.position.y + 6), Vector2(ex + sgn * 20, r.position.y + 6), Vector2(ex + sgn * (20 - notch), r.get_center().y + 3), Vector2(ex + sgn * 20, r.end.y + 2), Vector2(ex - sgn * 4, r.end.y + 2)]), TH_PARCH.darkened(0.28))
	_box(r, TH_PARCH, TH_PARCH.darkened(0.45), 4.0, 2.0)
	_text(center + Vector2(0, sz * 0.07), s, sz, TH_INK, true, true, maxf(w - 20.0, 100.0))
	if layout_probe:
		var host := ""
		for k in range(probe_panels.size() - 1, -1, -1):
			var pk: Rect2 = probe_panels[k]["r"]
			# 緞帶可以跨在面板上緣（圖鑑、大廳、試煉）：中心 x 在面板內、緞帶本體碰到面板就算它的宿主
			if pk.grow(2.0).has_point(center + Vector2(0, 2)) or (center.x > pk.position.x and center.x < pk.end.x and r.intersects(pk.grow(2.0))):
				host = probe_panels[k]["id"]
				break
		probe_ribbons.append({"id": "H%d" % probe_ribbons.size(), "r": Rect2(r.position.x - 20, r.position.y, r.size.x + 40, r.size.y + 2), "body": r, "cx": center.x, "bottom": r.end.y + 2.0, "host": host})
	return r.end.y + 2.0

## 標題緞帶完整下緣（不畫，給排版先算位置用）
func h1_bottom(center_y: float) -> float:
	return center_y - 2.0 + tz("H1") * 1.45 + 2.0

## V1.5.2：緞帶＋下方置中說明。回傳下一個內容的起點（說明下緣＋GAP_L；沒說明時＝緞帶下緣＋GAP_L）。
func _h1_help(center: Vector2, title: String, help: String, sz: int, maxw: float) -> float:
	var y := _h1(center, title) + GAP_L
	if help == "":
		return y
	_text(Vector2(center.x, y), help, sz, TXT_DIM, true, false, maxw)
	return y + text_h(help, fit(help, sz, maxw), maxw) + GAP_L

## 同上的高度（不畫）：從緞帶中心 y 到下一個內容起點的距離，給面板先算高度
func h1_help_h(help: String, sz: int, maxw: float) -> float:
	return h1_bottom(0.0) + GAP_L + ((text_h(help, fit(help, sz, maxw), maxw) + GAP_L) if help != "" else 0.0)

## V1.5.2：短標籤要換兩行時，中日文從中間斷開（避免第二行只剩一個字）；含空白的英文照詞斷，不動
static func balance_two_lines(s: String) -> String:
	if "\n" in s or s.length() < 4:
		return s
	if " " in s:   # 英文：換在最靠近中間的空白
		var best := -1
		for i in s.length():
			if s[i] == " " and (best < 0 or absi(i - s.length() / 2) < absi(best - s.length() / 2)):
				best = i
		return s.substr(0, best) + "\n" + s.substr(best + 1)
	var k := ceili(s.length() / 2.0)
	return s.substr(0, k) + "\n" + s.substr(k)

## V1.5.2 R9：一行置中小標題（字級 sz）下方的控制項起點：字形下緣（約 1.03 字高）＋GAP_M
func below_head(sz: int) -> float:
	return ceilf(sz * 1.05) + GAP_M

## V1.5.2 R1／L7：模態面板水平置中、高度照內容（垂直置中，距畫面邊 ≥16）
func modal_rect(w: float, h: float) -> Rect2:
	var hh := minf(h, 800.0 - 32.0)
	return Rect2(roundf((1280.0 - w) * 0.5), roundf(maxf(16.0, (800.0 - hh) * 0.5)), w, hh)

## V1.5.2：可見面小於 44 的按鈕（大廳選牌、技能、篩選、陣營、沙盤技能）：點擊區擴到 44 高，可見面不變
func _btn_small(r: Rect2, label: String, action: Callable, enabled := true, primary := false, tint := Color(0, 0, 0, 0)) -> void:
	btn_hit_min = 44.0
	_btn(r, label, action, enabled, primary, tint)
	btn_hit_min = 0.0

## 安靜的小按鈕（第七輪 N6）：點擊框維持可點的大小，平常只畫一個小記號，滑過才亮。
func _btn_quiet(r: Rect2, label: String, action: Callable) -> void:
	var idx := _btns.size()
	_btns.append({"r": r, "cb": action, "en": true})
	var hot := (r.has_point(mouse) and not pad_mode) or (pad_mode and idx == _focus)
	var sz := ts(14)
	var rad := maxf(9.0, sz * 0.62)   # 1.3.0 R11：圓跟著字級長大（150% 時 21px 的「?」塞不進 9px 圓）
	var c := r.end - Vector2(rad + 3.0, rad + 3.0)
	draw_circle(c, rad, Color(ACCENT, 0.9) if hot else Color(0, 0, 0, 0.55), true, -1.0, true)
	if layout_probe:
		probe_btns.append(r)
		probe_ctrls.append(r)
	_probe_btn_label = true
	_probe_btn_rect = r
	_probe_face = Rect2(c - Vector2(rad, rad), Vector2(rad, rad) * 2.0)   # 1.3.0 R11：格子是畫出來的圓，不是 36×36 點擊區
	_probe_cell_id = "quiet%d" % idx
	_text(ink_center_p(_probe_face, label, sz, true), label, sz, Color.BLACK if hot else TXT_DIM, true, true)
	_probe_face = Rect2()
	_probe_cell_id = ""
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


## 自己畫框、不走 _panel 的模態面板也要登記（R1、漏登記守衛）
func probe_panel(r: Rect2) -> void:
	if layout_probe:
		probe_panels.append({"id": "P%d" % probe_panels.size(), "r": r, "skip": {}})

## 1.2.0 §1.2「一個畫面＝一個實物」：疊層 → 實物種類。只在面板外框一圈（框外 8px 到框內 10px）加裝飾、
## 面板內容區與文字底色不變（對比、版面探針不受影響）；簡化介面不畫。第 4 大類 A0。
const OBJ_OF := {"puzzles": "fold", "trials": "tube", "codex": "case", "settings": "box", "keys": "box", "profile": "trunk", "nemeses": "ebony",
	"codes": "letter", "wave_codes": "letter", "songbook": "fold", "playroom": "tin", "weekly": "tin", "ghosts": "tin", "confirm": "card", "leave": "card", "pause_menu": "clock"}
var panel_obj := ""
var obj_open_r := Rect2()     # 1.2.0 第 11 大類：這一幀畫的實物面板（開合動畫用）
var obj_open_kind := ""

## 1.2.0 第 11 大類 實物開合（第 4 大類記錄）：疊層打開的前 0.3 秒，在面板上蓋一層「還沒打開的那一面」再收走——
## 木盒類掀蓋往上收、經摺帖／畫筒往右攤開、信封三角封口往上翻。只疊畫、不縮放不位移（按鈕位置與滑鼠一致，Codex v120-impl2）；
## 截圖、版面檢查、減少特效、簡化介面不演（呼叫端判斷）。k＝0→1。
func _obj_open_anim(r: Rect2, kind: String, k: float) -> void:
	var e := 1.0 - (1.0 - k) * (1.0 - k) * (1.0 - k)   # ease out
	var wood := Color("#7a5232")
	var paper := Color("#efe3c8")
	match kind:
		"box", "case", "trunk", "tin", "clock", "ebony":
			var h := r.size.y * (1.0 - e)
			if h < 1.0:
				return
			var col := Color("#3a2416") if kind == "ebony" else (Color("#8a8f93") if kind == "tin" else (Color("#8b4f2a") if kind == "trunk" else wood))   # 牛皮偏紅褐，和木頭分開
			var lid := Rect2(r.position - Vector2(10, 10), Vector2(r.size.x + 20, h + 10))
			draw_rect(Rect2(lid.position + Vector2(0, lid.size.y), Vector2(lid.size.x, 14)), Color(DIM_INK, 0.35 * (1.0 - e)))   # 掀起的蓋子在下面落影
			draw_rect(lid, col)
			for i in int(lid.size.y / 18.0):
				draw_rect(Rect2(lid.position.x, lid.position.y + 9 + i * 18, lid.size.x, 1), Color(0, 0, 0, 0.12))   # 木紋／鐵皮壓紋
			draw_rect(Rect2(lid.position.x, lid.end.y - 4, lid.size.x, 4), Color(1, 0.9, 0.7, 0.25))   # 蓋緣受光
			var edge_h := minf(12.0, lid.size.y)
			draw_rect(Rect2(lid.position.x, lid.end.y - edge_h, lid.size.x, edge_h), col.darkened(0.35))   # 蓋子的端面（厚度）
			draw_rect(Rect2(lid.position.x, lid.end.y - edge_h, lid.size.x, 2), Color(1, 0.9, 0.7, 0.3))
			if kind == "trunk":
				draw_rect(Rect2(lid.position + Vector2(10, 8), lid.size - Vector2(20, 8 + edge_h + 4)), Color("#f0e2c0", 0.55), false, 1.5)   # 皮革縫線
				for cx in [lid.position.x, lid.end.x - 22.0]:
					draw_rect(Rect2(cx, lid.end.y - edge_h - 18, 22, 18 + edge_h), Color("#4a2c18"))   # 包角
			for hx in [lid.position.x + lid.size.x * 0.22, lid.position.x + lid.size.x * 0.78]:
				draw_rect(Rect2(hx - 14, lid.end.y - edge_h - 6, 28, edge_h + 10), Color("#a8873a"))   # 鉸鏈
				draw_rect(Rect2(hx - 2, lid.end.y - edge_h - 6, 4, edge_h + 10), Color("#6e5520"))
			draw_rect(Rect2(r.get_center().x - 16, lid.end.y - 14, 32, 10), Color("#c9a24a"))   # 鎖扣
		"fold", "tube":
			var w := r.size.x * (1.0 - e)
			if w < 1.0:
				return
			var pr := Rect2(Vector2(r.end.x - w, r.position.y - 6), Vector2(w + 6, r.size.y + 12))
			draw_rect(pr, paper)
			var nf := 5
			for i in range(1, nf):
				var x := pr.position.x + pr.size.x * i / nf
				draw_rect(Rect2(x - 3, pr.position.y, 3, pr.size.y), Color(DIM_INK, 0.12))
			draw_rect(Rect2(pr.position.x - 8, pr.position.y, 8, pr.size.y), Color(DIM_INK, 0.25 * (1.0 - e)))   # 還沒攤開那疊的厚度影
		"letter":
			var apex_y := r.position.y + r.size.y * 0.55 * (1.0 - e)
			if apex_y - r.position.y < 2.0:
				return
			draw_colored_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), Vector2(r.get_center().x, apex_y)]), paper.darkened(0.06))
			draw_polyline(PackedVector2Array([r.position, Vector2(r.get_center().x, apex_y), Vector2(r.end.x, r.position.y)]), Color(DIM_INK, 0.5), 2.0)
			draw_circle(Vector2(r.get_center().x, apex_y - 14), 14, Color("#8e1b14"))   # 蠟封跟著封口走

func _obj_deco(r: Rect2, kind: String) -> void:
	var brass := Color("#c9a24a")
	var brass_d := Color("#7a5a22")
	match kind:
		"fold":   # 經摺帖：整幅面板每 1/5 一道風琴摺（摺痕左暗右亮的窄漸層，低透明，不影響字的對比）＋上下緣摺口
			var nf := 5
			for i in range(1, nf):
				var x := r.position.x + r.size.x * i / nf
				for k in 6:
					draw_rect(Rect2(x - 6 + k, r.position.y, 1, r.size.y), Color(DIM_INK, 0.03 * (k + 1)))
				draw_rect(Rect2(x, r.position.y, 2, r.size.y), Color(1, 0.94, 0.8, 0.10))
				for yy in [r.position.y - 8.0, r.end.y - 4.0]:
					draw_rect(Rect2(x - 2, yy, 4, 12), Color(DIM_INK, 0.6))
		"tube":   # 畫筒短箋：左上角框上一顆蠟封，下面垂兩條紅絲帶尾（往左下垂，不橫切面板）
			var c0 := r.position + Vector2(34, 0)
			for tl in [[Vector2(-4, 4), Vector2(-14, 40)], [Vector2(4, 4), Vector2(8, 44)]]:
				var a0: Vector2 = c0 + tl[0]
				var a1: Vector2 = c0 + tl[1]
				draw_colored_polygon(PackedVector2Array([a0 + Vector2(-4, 0), a0 + Vector2(4, 0), a1 + Vector2(4, 0), a1 + Vector2(0, -6), a1 + Vector2(-4, 0)]), Color("#9e2a22"))
				draw_line(a0 + Vector2(-1, 0), a1 + Vector2(-1, -4), Color(1, 0.7, 0.6, 0.25), 1.0)
			draw_circle(c0, 12.0, Color("#6e1a14"), true, -1.0, true)
			draw_circle(c0, 9.0, Color("#8e231b"), true, -1.0, true)
			draw_arc(c0, 10.0, 0.0, TAU, 20, Color(brass, 0.8), 1.5, true)
		"case":   # 雙開珍玩箱：兩側各兩片大黃銅合頁（帶鉚釘）、上緣中央鎖扣、框內側一道門扇厚度陰影
			for side in [-1.0, 1.0]:
				var ex: float = r.position.x if side < 0 else r.end.x
				draw_rect(Rect2(ex - (10.0 if side < 0 else 0.0), r.position.y + 8, 10, r.size.y - 16), Color(DIM_INK, 0.35))
				for fy in [0.2, 0.8]:
					var hr := Rect2(ex - 10, r.position.y + r.size.y * fy - 24, 20, 48)
					draw_rect(Rect2(hr.position + Vector2(2, 3), hr.size), Color(DIM_INK, 0.5))
					draw_rect(hr, brass_d)
					draw_rect(hr.grow(-2), brass)
					draw_line(hr.position + Vector2(10, 3), hr.position + Vector2(10, 45), brass_d, 2.0)
					for ry in [8.0, 24.0, 40.0]:
						draw_circle(hr.position + Vector2(5, ry), 2.0, brass_d)
						draw_circle(hr.position + Vector2(15, ry), 2.0, brass_d)
			var lk := Rect2(r.get_center().x - 22, r.end.y - 6, 44, 22)
			draw_rect(Rect2(lk.position + Vector2(2, 3), lk.size), Color(DIM_INK, 0.5))
			draw_rect(lk, brass_d)
			draw_rect(lk.grow(-2), brass)
			draw_circle(lk.get_center(), 4.0, brass_d)
			draw_rect(Rect2(lk.get_center() + Vector2(-1, 0), Vector2(2, 7)), brass_d)
		"box":   # 木盒：四角大黃銅 L 形護角＋鉚釘
			for cc in [[r.position, Vector2(1, 1)], [Vector2(r.end.x, r.position.y), Vector2(-1, 1)], [Vector2(r.position.x, r.end.y), Vector2(1, -1)], [r.end, Vector2(-1, -1)]]:
				var o: Vector2 = cc[0] + Vector2(-8, -8) * cc[1]
				var d: Vector2 = cc[1]
				var poly := PackedVector2Array([o, o + Vector2(52 * d.x, 0), o + Vector2(52 * d.x, 14 * d.y), o + Vector2(14 * d.x, 14 * d.y), o + Vector2(14 * d.x, 52 * d.y), o + Vector2(0, 52 * d.y)])
				var sh := PackedVector2Array()
				for q in poly:
					sh.append(q + Vector2(2, 3))
				draw_colored_polygon(sh, Color(DIM_INK, 0.5))
				draw_colored_polygon(poly, brass)
				draw_polyline(poly + PackedVector2Array([poly[0]]), brass_d, 1.5, true)
				for rv in [Vector2(7, 7), Vector2(36, 7), Vector2(7, 36)]:
					draw_circle(o + rv * d, 2.4, brass_d)
					draw_circle(o + rv * d - Vector2(0.6, 0.6), 0.9, Color(1, 0.95, 0.75, 0.8))
		"trunk":   # 牛皮箱：框內側一圈米白粗縫線＋上緣兩條寬皮帶＋大黃銅扣＋四角皮革包角
			var st := r.grow(-5)
			var dash := 10.0
			var xx := st.position.x
			while xx < st.end.x - dash:
				draw_line(Vector2(xx, st.position.y), Vector2(xx + 6, st.position.y), Color(0.93, 0.86, 0.7, 0.55), 1.5)
				draw_line(Vector2(xx, st.end.y), Vector2(xx + 6, st.end.y), Color(0.93, 0.86, 0.7, 0.55), 1.5)
				xx += dash
			var yy2 := st.position.y
			while yy2 < st.end.y - dash:
				draw_line(Vector2(st.position.x, yy2), Vector2(st.position.x, yy2 + 6), Color(0.93, 0.86, 0.7, 0.55), 1.5)
				draw_line(Vector2(st.end.x, yy2), Vector2(st.end.x, yy2 + 6), Color(0.93, 0.86, 0.7, 0.55), 1.5)
				yy2 += dash
			for fx in [0.22, 0.78]:
				var sx: float = r.position.x + r.size.x * fx
				draw_rect(Rect2(sx - 20 + 2, r.position.y - 12 + 3, 40, 30), Color(DIM_INK, 0.5))
				draw_rect(Rect2(sx - 20, r.position.y - 12, 40, 30), Color("#5a3218"))
				draw_rect(Rect2(sx - 20, r.position.y - 12, 40, 3), Color(1, 0.85, 0.65, 0.25))
				var bk := Rect2(sx - 14, r.position.y - 4, 28, 16)
				draw_rect(bk, brass, false, 3.0)
				draw_line(bk.get_center() - Vector2(0, 6), bk.get_center() + Vector2(0, 6), brass, 2.5)
			for cc2 in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
				var dd := Vector2(1 if cc2.x < r.get_center().x else -1, 1 if cc2.y < r.get_center().y else -1)
				draw_colored_polygon(PackedVector2Array([cc2 - dd * 8, cc2 - dd * 8 + Vector2(40 * dd.x, 0), cc2 - dd * 8 + Vector2(0, 40 * dd.y)]), Color("#4a2a14"))
		"ebony":   # 黑檀插牌座：框一圈壓深＋上緣一道細金線
			draw_rect(r.grow(8), Color(0.05, 0.03, 0.02, 0.35), false, 8.0)
			draw_line(r.position + Vector2(12, -2), Vector2(r.end.x - 12, r.position.y - 2), Color(brass, 0.7), 1.5)
		"letter":   # 信封（背面）：四角往中心的摺線（框內 70px、淡墨）＋下緣三角封口線＋右下蠟封（標題緞帶在上緣中央，不畫在那）
			var cx := r.get_center().x
			for cc3 in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
				var dv: Vector2 = (r.get_center() - cc3).normalized()
				draw_line(cc3, cc3 + dv * 70.0, Color(0.85, 0.75, 0.55, 0.45), 2.0, true)
				draw_line(cc3 + Vector2(0, 2), cc3 + dv * 70.0 + Vector2(0, 2), Color(DIM_INK, 0.4), 1.0, true)
			draw_colored_polygon(PackedVector2Array([Vector2(r.position.x + 6, r.end.y + 6), Vector2(r.end.x - 6, r.end.y + 6), Vector2(cx, r.end.y + 22)]), Color("#d8c7a6"))
			draw_polyline(PackedVector2Array([Vector2(r.position.x + 6, r.end.y + 6), Vector2(cx, r.end.y + 22), Vector2(r.end.x - 6, r.end.y + 6)]), Color(DIM_INK, 0.6), 1.5, true)
			var sc := Vector2(r.end.x - 34, r.end.y - 30)
			draw_circle(sc + Vector2(2, 3), 15.0, Color(DIM_INK, 0.45), true, -1.0, true)
			draw_circle(sc, 15.0, Color("#7a1d16"), true, -1.0, true)
			draw_circle(sc, 11.0, Color("#9b281b"), true, -1.0, true)
			draw_arc(sc, 13.0, 0.0, TAU, 24, Color(brass, 0.85), 1.5, true)
		"tin":   # 老鐵盒：框外一圈鉚釘（藍灰金屬）
			var col := Color("#8a96a0")
			var n := int(r.size.x / 60.0)
			for i in n + 1:
				var x := r.position.x + r.size.x * i / maxf(1.0, n)
				for yy in [r.position.y - 3.0, r.end.y + 3.0]:
					draw_circle(Vector2(x, yy), 3.0, col, true, -1.0, true)
					draw_circle(Vector2(x - 0.8, yy - 0.8), 1.0, Color(1, 1, 1, 0.5), true, -1.0, true)
		"card":   # 立卡：底緣一道木腳架
			draw_rect(Rect2(r.position.x + r.size.x * 0.3, r.end.y + 4, r.size.x * 0.4, 6), Color("#6b4a2e"))
			draw_rect(Rect2(r.position.x + r.size.x * 0.3, r.end.y + 4, r.size.x * 0.4, 2), Color(1, 0.85, 0.6, 0.3))
		"clock":   # 暫停＝棋鐘：上緣兩顆黃銅按鈕
			for fx in [0.3, 0.7]:
				var bc := Vector2(r.position.x + r.size.x * fx, r.position.y - 4)
				draw_rect(Rect2(bc - Vector2(14, 6), Vector2(28, 10)), brass_d)
				draw_rect(Rect2(bc - Vector2(12, 5), Vector2(24, 6)), brass)

func _panel(r: Rect2) -> void:
	probe_panel(r)
	_dim(0.62)
	_box(Rect2(r.position + Vector2(5, 7), r.size).grow(4), Color(DIM_INK, 0.45), Color(0, 0, 0, 0), 14.0)      # 陰影（1.2.0：光源左上 → 影子往右下）
	_box(r, PANEL, Color(0, 0, 0, 0), 10.0)
	if not bool(Save.s("plain_ui")):
		_mat_box(r.grow(-6), "walnut", Color(0.62, 0.6, 0.58))   # 1.2.0 §2：面板底是胡桃木紋（壓暗，字照樣看得清）
	# V1.2 B3：深木外框＋四角銅釘（九宮格貼圖）；沒有貼圖時退回舊的細框
	var fx := _ui_tex(TEX_FRAME)
	if fx != null and not bool(Save.s("plain_ui")):
		var sb: StyleBoxTexture = _sb_cache.get("frame")
		if sb == null:
			sb = StyleBoxTexture.new()
			sb.texture = fx
			for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
				sb.set_texture_margin(side, 22.0)
			sb.draw_center = false
			_sb_cache["frame"] = sb
		draw_style_box(sb, r.grow(8))
	else:
		_box(r, Color(0, 0, 0, 0), TH_EDGE, 10.0, 3.0)
	if panel_obj != "" and not bool(Save.s("plain_ui")):
		_obj_deco(r, panel_obj)
		obj_open_r = r
		obj_open_kind = panel_obj


func _open(name: String) -> void:
	if overlay.begins_with("hub_"):
		nav_stack.append(overlay)   # 卡片面板開著時直接開下一頁（例如結果頁「試煉」）：記得回面板
	overlay = name
	_focus = 0

## V1.5.1 返回目的地：打開下一層之前記下「從哪來」，返回鈕、Esc、手把 B 都走 _nav_back（使用者回報：返回都跳回主畫面）。
## 卡片面板（hub）畫出來時清空堆疊；開戰也清空。nav_hub＝最後經過的卡片面板，打完回標題時重新打開它。
var nav_stack: Array = []
var nav_hub := ""

var nav_focus := {}   # V1.0.0：卡片面板 → 上次點的那張卡（返回時焦點回原卡）
func _nav_push(from: String) -> void:
	nav_stack.append(from)

func _nav_back(fallback := "") -> void:
	if overlay.begins_with("hub_") or overlay == "playroom":   # V1.0.0：遊戲間也是卡片面板
		nav_hub = ""   # 關掉卡片面板：之後打完不再自動打開它
	overlay = str(nav_stack.pop_back()) if not nav_stack.is_empty() else fallback
	_focus = int(nav_focus.get(overlay, 0))   # V1.0.0（Codex v100-i1 #8）：回到卡片面板時焦點回原卡


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
		mood := 0, lean := 0.0, crouch := 1.0, variant := 0, fid := -1) -> void:
	if scale > 1.4 and alpha > 0.5 and not bool(Save.s("plain_ui")):
		_unit_base(p, scale)
	if scale <= 1.4 and sprites != null and sprites.is_ready(cbm()) and sprites.has_type(type):   # V1.2：大圖（圖鑑、MVP）直接向量畫，放大圖集會糊
		sprites.draw_unit(self, p, type, team, face, walk, atk, hurt, alpha, t, scale, mood, lean, crouch, cbm(), variant, fid)
	else:
		Art.unit(self, p, type, team, face, walk, atk, hurt, alpha, t, scale, cbm(), mood, lean, crouch, variant)

## V1.2 D2：大圖（圖鑑、MVP）站在木製圓底座上，像桌上的棋偶公仔（V1.5.1 抽出來給圖鑑烘焙版大圖共用）
func _unit_base(p: Vector2, scale: float) -> void:
	if true:
		var bw := 30.0 * scale
		var bh := 9.0 * scale
		draw_set_transform(p + Vector2(0, 2 * scale), 0.0, Vector2(1, bh / bw))
		draw_circle(Vector2(0, 3 * scale * bw / bh), bw * 1.04, Color(0, 0, 0, 0.3), true, -1.0, true)
		draw_circle(Vector2.ZERO, bw, Color("#5a3b22"), true, -1.0, true)
		draw_circle(Vector2(0, -2.2 * scale * bw / bh), bw * 0.96, Color("#8a5f37"), true, -1.0, true)
		draw_arc(Vector2(0, -2.2 * scale * bw / bh), bw * 0.96, PI * 1.1, PI * 1.9, 24, Color(1, 0.9, 0.7, 0.35), 2.0, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## 在一個框（或圓）的正中間畫一隻兵（使用者回報：圖鑑頁籤的人物沒有在格子正中間）。
## 角色的腳在原點、頭頂約在 -50（騎兵含騎士約 -54），視覺中心在腳上方 24（騎兵 26）× 縮放。
static func unit_center_feet(center: Vector2, type: int, scale: float) -> Vector2:
	return center + Vector2(0, (26.0 if type == D.CAVALRY else 24.0) * scale)

func _unit_in(r: Rect2, type: int, team: int, alpha := 1.0, scale := 0.6) -> void:
	Art.unit(self, unit_center_feet(r.get_center(), type, scale), type, team, 1.0, 0.0, 0.0, 0.0, alpha, time, scale, cbm())

var ring_shadow := 0.0   # V1.1 C6：亮色地圖（冰原）額外加深腳底影子；0＝不加

## V1.3 B1：手繪圈（取代整圈的 draw_arc）。半徑有 ±3.5% 的起伏、尾端多畫 5% 疊過起點，像筆畫的圈。
## 三個版本預先算好（單位圓），只換縮放，不比 draw_arc 貴。boil＝焦點裝飾每秒換 6 次版本（線條微動），簡化特效時固定第一版。
static var _hr_pts: Array = []
var _hr_buf := PackedVector2Array()
static func _hr_build() -> void:
	for v in 3:
		var pts := PackedVector2Array()
		var a0 := -0.9 + v * 2.1
		for i in 35:
			var an := a0 + TAU * 1.05 * i / 34.0
			var k := 1.0 + 0.022 * sin(an * 3.0 + v * 1.7) + 0.013 * sin(an * 5.0 + v * 4.1)
			pts.append(Vector2(cos(an), sin(an)) * k)
		_hr_pts.append(pts)

## V1.3 B3：擺陣手感。拿起的棋子抬高 LIFT_PX、地上留一個變寬變淡的影子；放下後 0.18 秒沉降（先落下、再微微壓一下）。
## 只是畫面：落點在放開那一刻就已經提交。
const LIFT_PX := 12.0
var settle_t := {}   # 格子／世界座標 → 放下的時間
func _lift_shadow(p: Vector2) -> void:
	draw_colored_polygon(Art._ell(p + Vector2(0, 1), 17.0, 7.0), Color(0, 0, 0, 0.16))

func _settle_dy(key) -> float:
	if not settle_t.has(key):
		return 0.0
	var k: float = (time - float(settle_t[key])) / 0.18
	if k < 0.0:
		return -LIFT_PX
	if k >= 1.0:
		settle_t.erase(key)
		return 0.0
	if k < 0.7:
		var f := k / 0.7
		return -LIFT_PX * (1.0 - f) * (1.0 - f)
	return 1.5 * sin((k - 0.7) / 0.3 * PI)

## V1.3 B1：粉筆虛線（取代 draw_dashed_line）。每段長短、間隔、濃淡、粗細與左右偏移都不一樣，
## 但只看段號（不看位置），拖曳時花紋不會閃。
func _chalk_line(a: Vector2, b: Vector2, col: Color, w := 2.0, dash := 8.0, _aligned := true) -> void:
	var L := a.distance_to(b)
	if L < 1.0:
		return
	var d := (b - a) / L
	var n := d.orthogonal()
	col = Color(col.lerp(Color(0.96, 0.93, 0.86), 0.3), col.a * 0.8)   # 粉筆：彩度降一點、偏粉白（Antigravity v130-impl1）
	var x := 0.0
	var i := 0
	while x < L and i < 400:
		var hh := absi((i * 40503 + 17) * 2246822519) % 100000
		var seg := dash * (0.7 + float(hh % 60) / 100.0)
		var gap := dash * (0.55 + float((hh / 60) % 45) / 100.0)
		var e := minf(x + seg, L)
		var o1 := n * (float(hh % 7) - 3.0) * 0.22
		var o2 := n * (float((hh / 7) % 7) - 3.0) * 0.22
		draw_line(a + d * x + o1, a + d * e + o2, Color(col, col.a * (0.72 + float(hh % 29) / 100.0)), w * (0.8 + float((hh / 11) % 5) * 0.1), true)
		x = e + gap
		i += 1

## V1.3 B1：微微起伏的細線（格線用）：7 點折線，偏移固定（依起點），不會閃。
func _wob_line(a: Vector2, b: Vector2, col: Color, w := 1.0) -> void:
	var n := (b - a).normalized().orthogonal()
	var h := absi(int(a.x * 13.0 + a.y * 7.0 + 5.0) * 2654435761) % 100000
	var pts := PackedVector2Array()
	for k in 7:
		var off := 0.0 if k == 0 or k == 6 else (float((h >> (k * 2)) % 5) - 2.0) * 0.45
		pts.append(a.lerp(b, k / 6.0) + n * off)
	draw_polyline(pts, col, w, false)   # 格線很淡，不用抗鋸齒（省效能）

func _hand_ring(c: Vector2, r: float, col: Color, w: float, boil := false, seed := 0) -> void:
	if _hr_pts.is_empty():
		_hr_build()
	var v := seed % 3
	if boil and not bool(Save.s("reduce_fx")):
		v = (v + int(time * 6.0)) % 3
	var src: PackedVector2Array = _hr_pts[v]
	# V1.3.1 P2：重用同一個緩衝區（每次只覆寫數值，不重新配置）
	if _hr_buf.size() != src.size():
		_hr_buf.resize(src.size())
	for i in src.size():
		_hr_buf[i] = c + src[i] * r
	draw_polyline(_hr_buf, col, w, true)

func _ring(p: Vector2, team: int, type: int, scale := 1.0, air := 0.0) -> void:
	if ring_shadow > 0.0:
		var sh := PackedVector2Array()
		for i in 16:
			var an := i * TAU / 16.0
			sh.append(p + Vector2(cos(an) * 17.0, 3.0 + sin(an) * 7.0) * Vector2(scale, scale) + Vector2(0, 0))
		draw_colored_polygon(sh, Color(0.05, 0.08, 0.15, ring_shadow))
	if sprites != null and sprites.is_ready(cbm()):
		sprites.draw_ring(self, p, team, type, scale, air)
	else:
		Art.ring(self, p, team, type, cbm(), scale, air)

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
