extends Node
## 音效與音樂（優化方案 H）：同類音效 80ms 內最多 2 個、音高 ±10% 隨機；音樂與音效分軌。
## 優先權（第二輪方案 R8）：12 個聲道滿的時候，關鍵音（技能、死亡、最後時刻）會搶走優先權最低、播最久的普通命中音，
## 不會被一堆砍擊聲擠掉。最後時刻慢動作時整體加低通濾波（悶住的心跳感）。

const FILES := ["arrow", "backstab", "block", "brace", "charge", "clutch", "death", "frenzy", "hit", "lose",
	"place_heavy", "place_light", "place_mid", "slash", "start", "turn", "ui_click", "ui_deny", "win",
	"shatter", "bell", "bugle", "aircut", "alert", "snap", "taunt", "reveal", "boom", "heal",
	"poison", "baa", "chomp", "squish", "charge_up", "timestop", "raise", "vacuum", "stomp",
	"k_hover", "k_click", "k_back", "k_confirm", "k_tab", "k_toggle", "k_error", "k_open", "k_close", "k_unlock", "k_star", "k_place",
	"step_grass", "step_snow", "step_wood", "step_stone", "step_heavy", "hit_metal", "hit_wood", "hit_soft", "horn"]
# 0 普通命中、1 防禦、2 技能／死亡、3 全場事件與介面
const PRIO := {"hit": 0, "slash": 0, "arrow": 0, "block": 1, "brace": 1, "alert": 1, "taunt": 1, "reveal": 1,
	"shatter": 2, "bell": 2, "bugle": 2, "aircut": 2, "snap": 2, "charge": 2, "backstab": 2, "death": 2,
	"step_grass": 0, "step_snow": 0, "step_wood": 0, "step_stone": 0, "step_heavy": 1, "hit_metal": 0, "hit_wood": 0, "hit_soft": 0, "horn": 3,
	"k_hover": 3, "k_click": 3, "k_back": 3, "k_confirm": 3, "k_tab": 3, "k_toggle": 3, "k_error": 3, "k_open": 3, "k_close": 3, "k_unlock": 3, "k_star": 3, "k_place": 3,
	"poison": 0, "squish": 1, "charge_up": 1, "baa": 1, "chomp": 2, "timestop": 2, "raise": 2, "vacuum": 2, "stomp": 2, "clutch": 3, "frenzy": 3, "start": 3, "win": 3, "lose": 3, "turn": 3, "ui_click": 3, "ui_deny": 3}
var _prio_of := {}       # 聲道 → 正在播的優先權
var _started := {}       # 聲道 → 開始時間
var _lowpass_idx := -1
var streams := {}
var players: Array[AudioStreamPlayer] = []
var recent := {}   # 名稱 → [時間戳...]
var music: AudioStreamPlayer
var music_name := ""
var amb: AudioStreamPlayer       # V9：地圖環境音
var amb_name := ""
var duck_t := 0.0                # V9：大招、號角時暫時壓低音樂
var sfx_vol := 0.8
var music_vol := 0.7
var rng := RandomNumberGenerator.new()

# V1.2 E4：具名匯流排（全部送進 Master；最後時刻低通仍掛在 Master，整體一起悶）
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"
const BUS_UI := "UI"
const BUS_AMB := "Ambience"
var music_old: AudioStreamPlayer   # 換曲時淡出的上一首
var fade_in := 1.0                 # 新曲淡入 0→1
var fade_out := 0.0                # 舊曲淡出 1→0
var fade_from := 1.0               # 交接當下舊曲的增益（淡入進度×戰況音量），從這裡往下淡
const FADE_SEC := 0.6

## 沒有就建立（同名不重複建；測試可以重複呼叫）。
static func _ensure_buses() -> void:
	for n in [BUS_MUSIC, BUS_SFX, BUS_UI, BUS_AMB]:
		if AudioServer.get_bus_index(n) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, n)
			AudioServer.set_bus_send(i, "Master")

## V1.2 E：優先讀 CC0 錄音轉的 .ogg（tools/gen/import_audio.py），沒有才用程式合成的 .wav。
## 同名變體（名稱__2、__3…）一起載入，播放時隨機挑、避免連續同一個。
static func load_audio(n: String):
	for ext in ["ogg", "wav"]:
		var path := "res://audio/%s.%s" % [n, ext]
		if ResourceLoader.exists(path):
			return load(path)
	return null

var variants := {}     # 名稱 → [stream...]（含本體）
var _last_var := {}    # 名稱 → 上次用的變體索引

func _ready() -> void:
	for n in FILES:
		var st = load_audio(n)
		if st:
			streams[n] = st
			var vs: Array = [st]
			for k in range(2, 9):
				var v = load_audio("%s__%d" % [n, k])
				if v == null:
					break
				vs.append(v)
			variants[n] = vs
	_ensure_buses()
	for i in 12:
		var p := AudioStreamPlayer.new()
		p.bus = BUS_SFX
		add_child(p)
		players.append(p)
	music = AudioStreamPlayer.new()
	music.bus = BUS_MUSIC
	add_child(music)
	music.finished.connect(func(): music.play())
	music_old = AudioStreamPlayer.new()
	music_old.bus = BUS_MUSIC
	add_child(music_old)
	amb = AudioStreamPlayer.new()
	amb.bus = BUS_AMB
	add_child(amb)
	amb.finished.connect(func(): amb.play())
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 900.0
	AudioServer.add_bus_effect(0, lp)
	_lowpass_idx = AudioServer.get_bus_effect_count(0) - 1
	AudioServer.set_bus_effect_enabled(0, _lowpass_idx, false)

## 最後時刻：整體低通（慢動作開始時開、結束時關）。
func set_muffled(on: bool) -> void:
	if _lowpass_idx >= 0 and AudioServer.is_bus_effect_enabled(0, _lowpass_idx) != on:
		AudioServer.set_bus_effect_enabled(0, _lowpass_idx, on)

## 聲道選擇（純函式，測試用）：先找空的；滿了就搶優先權最低（同級取最早開始）且低於新音效的。沒有可搶的回 -1。
static func pick_channel(busy: Array, prios: Array, starts: Array, prio: int) -> int:
	for i in busy.size():
		if not busy[i]:
			return i
	var best := -1
	for i in busy.size():
		if prios[i] < prio and (best < 0 or prios[i] < prios[best] or (prios[i] == prios[best] and starts[i] < starts[best])):
			best = i
	return best

func set_volumes(sfx_pct: int, music_pct: int) -> void:
	sfx_vol = sfx_pct / 100.0
	music_vol = music_pct / 100.0
	music.volume_db = linear_to_db(maxf(0.0001, music_vol * 0.6))
	if amb != null:
		amb.volume_db = linear_to_db(maxf(0.0001, sfx_vol * 0.22))   # 第十輪 B6：環境音跟音效音量

func play(name: String, vol := 1.0) -> void:
	if not streams.has(name) or sfx_vol <= 0.0:
		return
	if int(PRIO.get(name, 0)) >= 2 and not name.begins_with("k_"):
		duck(0.7)
	var now := Time.get_ticks_msec()
	var r: Array = recent.get(name, [])
	r = r.filter(func(t): return now - t < 80)
	if r.size() >= 2:
		return
	r.append(now)
	recent[name] = r
	var pr: int = PRIO.get(name, 1)
	var busy: Array = []
	var prios: Array = []
	var starts: Array = []
	for i in players.size():
		busy.append(players[i].playing)
		prios.append(_prio_of.get(i, 0))
		starts.append(_started.get(i, 0))
	var ch := pick_channel(busy, prios, starts, pr)
	if ch < 0:
		return
	var p := players[ch]
	p.stop()
	p.bus = BUS_UI if (name.begins_with("k_") or name.begins_with("ui_")) else BUS_SFX
	p.stream = _pick_variant(name)
	p.pitch_scale = 1.0 + rng.randf_range(-0.1, 0.1)
	p.volume_db = linear_to_db(maxf(0.0001, sfx_vol * vol))
	p.play()
	_prio_of[ch] = pr
	_started[ch] = now

## 變體：隨機挑一個，但不和上一次相同（只有一個就用它）。
func _pick_variant(name: String):
	var vs: Array = variants.get(name, [streams[name]])
	if vs.size() <= 1:
		return vs[0]
	var last := int(_last_var.get(name, -1))
	var k := rng.randi_range(0, vs.size() - 1) if last < 0 else rng.randi_range(0, vs.size() - 2)
	if last >= 0 and k >= last:
		k += 1
	_last_var[name] = k
	return vs[k]

# V1.2：戰鬥曲是錄音單軌（music_battle.ogg），舊的合成三分軌已移除；戰況只調整首大小聲。
var layer_gain := [1.0, 0.35, 1.0]     # 戰況目標（給 single_gain 換算）
## 戰況 → 三軌目標音量：差距小（≤15%）鼓聲進來；最後時刻只留低音（心跳另外播）。
static func layer_targets(close: bool, clutch: bool) -> Array:
	if clutch:
		return [1.0, 0.0, 0.0]
	return [1.0, 1.0 if close else 0.35, 1.0]

func set_layer_targets(g: Array) -> void:
	layer_gain = g
	# 單軌：差距小時全音量、拉開時略小聲、最後時刻壓低（心跳另外播）
	single_gain = 0.55 if float(g[2]) <= 0.0 else (1.0 if float(g[1]) >= 1.0 else 0.8)

var single_gain := 1.0
var single_cur := 1.0

func _process(delta: float) -> void:
	if duck_t > 0.0:
		duck_t -= delta
	# V1.2：單軌戰鬥曲用「緊張程度」調音量（分軌時的鼓聲進出改成整首大小聲），並套用大招壓低
	single_cur = move_toward(single_cur, single_gain, delta * 1.5)
	fade_in = move_toward(fade_in, 1.0, delta / FADE_SEC)
	if fade_out > 0.0:
		fade_out = move_toward(fade_out, 0.0, delta / FADE_SEC)
		music_old.volume_db = linear_to_db(maxf(0.0001, music_vol * 0.6 * fade_from * fade_out * (0.45 if duck_t > 0.0 else 1.0)))   # 從交接音量往下淡，也吃 duck（Codex v120-final2）
		if fade_out <= 0.0:
			music_old.stop()
	if music.playing:
		music.volume_db = linear_to_db(maxf(0.0001, music_vol * 0.6 * single_cur * fade_in * (0.45 if duck_t > 0.0 else 1.0)))

## V9：地圖環境音；空字串＝停。
func play_ambience(name: String) -> void:
	if name == amb_name:
		return
	amb_name = name
	if name == "":
		amb.stop()
		return
	var st = load("res://audio/amb_%s.wav" % name)
	if st == null:
		amb.stop()
		return
	amb.stream = st
	amb.volume_db = linear_to_db(maxf(0.0001, sfx_vol * 0.22))
	amb.play()

func duck(sec: float) -> void:
	duck_t = maxf(duck_t, sec)

func play_music(name: String) -> void:
	# V1.2 E：戰鬥曲是錄音單軌（music_battle.ogg）
	var src := name
	var pitch := 1.0
	if name == "music_frenzy":
		src = "music_battle"     # 狂熱：同一首加快一點，不換成合成音
		pitch = 1.08
	if name == music_name:
		return
	if src == "music_battle" and (music_name == "music_battle" or music_name == "music_frenzy") and music.playing:
		music_name = name     # 狂熱與一般戰鬥是同一首：只改音高、不從頭播（Codex v120-impl2）
		music.pitch_scale = pitch
		return
	# V1.2 E4：換曲交叉淡入淡出（上一首交給 music_old 淡出）
	if music.playing and music.stream != null:
		music_old.stream = music.stream
		music_old.pitch_scale = music.pitch_scale
		music_old.play(music.get_playback_position())
		fade_from = single_cur * fade_in
		fade_out = 1.0
		music_old.volume_db = music.volume_db
	fade_in = 0.0
	music_name = name
	var st = load_audio(src)
	if st == null:
		music.stop()
		return
	if "loop" in st:
		st.loop = true       # Ogg 的循環在這裡開（匯入預設不循環）
	music.stream = st
	music.pitch_scale = pitch
	single_gain = 1.0
	single_cur = 1.0
	music.volume_db = linear_to_db(maxf(0.0001, music_vol * 0.6 * fade_in))   # 從 0 淡入，_process 往上拉
	music.play()
