extends Node
## 音效與音樂（優化方案 H）：同類音效 80ms 內最多 2 個、音高 ±10% 隨機；音樂與音效分軌。
## 優先權（第二輪方案 R8）：12 個聲道滿的時候，關鍵音（技能、死亡、最後時刻）會搶走優先權最低、播最久的普通命中音，
## 不會被一堆砍擊聲擠掉。最後時刻慢動作時整體加低通濾波（悶住的心跳感）。

const FILES := ["arrow", "backstab", "block", "brace", "charge", "clutch", "death", "frenzy", "hit", "lose",
	"place_heavy", "place_light", "place_mid", "slash", "start", "turn", "ui_click", "ui_deny", "win",
	"shatter", "bell", "bugle", "aircut", "alert", "snap", "taunt", "reveal", "boom", "heal",
	"poison", "baa", "chomp", "squish", "charge_up", "timestop", "raise", "vacuum", "stomp"]
# 0 普通命中、1 防禦、2 技能／死亡、3 全場事件與介面
const PRIO := {"hit": 0, "slash": 0, "arrow": 0, "block": 1, "brace": 1, "alert": 1, "taunt": 1, "reveal": 1,
	"shatter": 2, "bell": 2, "bugle": 2, "aircut": 2, "snap": 2, "charge": 2, "backstab": 2, "death": 2,
	"poison": 0, "squish": 1, "charge_up": 1, "baa": 1, "chomp": 2, "timestop": 2, "raise": 2, "vacuum": 2, "stomp": 2, "clutch": 3, "frenzy": 3, "start": 3, "win": 3, "lose": 3, "turn": 3, "ui_click": 3, "ui_deny": 3}
var _prio_of := {}       # 聲道 → 正在播的優先權
var _started := {}       # 聲道 → 開始時間
var _lowpass_idx := -1
var streams := {}
var players: Array[AudioStreamPlayer] = []
var recent := {}   # 名稱 → [時間戳...]
var music: AudioStreamPlayer
var music_name := ""
var sfx_vol := 0.8
var music_vol := 0.7
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	for n in FILES:
		var st = load("res://audio/%s.wav" % n)
		if st:
			streams[n] = st
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	music = AudioStreamPlayer.new()
	add_child(music)
	music.finished.connect(func(): music.play())
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

func play(name: String, vol := 1.0) -> void:
	if not streams.has(name) or sfx_vol <= 0.0:
		return
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
	p.stream = streams[name]
	p.pitch_scale = 1.0 + rng.randf_range(-0.1, 0.1)
	p.volume_db = linear_to_db(maxf(0.0001, sfx_vol * vol))
	p.play()
	_prio_of[ch] = pr
	_started[ch] = now

# ── 分軌戰鬥音樂（第三輪 S1）：低音、鼓、旋律三軌同時播、各自調音量 ──
const LAYERS := ["music_battle_bass", "music_battle_drums", "music_battle_mel"]
var layers: Array[AudioStreamPlayer] = []
var layer_gain := [1.0, 0.35, 1.0]     # 目標
var layer_cur := [1.0, 0.35, 1.0]      # 目前（平滑）

func play_layers() -> void:
	music.stop()
	music_name = "layers"
	if layers.is_empty():
		for n in LAYERS:
			var p := AudioStreamPlayer.new()
			add_child(p)
			# 循環在匯入設定裡開（edit/loop_mode=2 整段循環）；檔案匯入時會壓縮，不能用位元組數自己算樣本數（Codex S7 #1）
			p.stream = load("res://audio/%s.wav" % n)
			layers.append(p)
	layer_cur = layer_gain.duplicate()
	for i in layers.size():
		layers[i].volume_db = linear_to_db(maxf(0.0001, music_vol * 0.6 * layer_cur[i]))
		layers[i].play(0.0)

func stop_layers() -> void:
	for p in layers:
		p.stop()

## 戰況 → 三軌目標音量：差距小（≤15%）鼓聲進來；最後時刻只留低音（心跳另外播）。
static func layer_targets(close: bool, clutch: bool) -> Array:
	if clutch:
		return [1.0, 0.0, 0.0]
	return [1.0, 1.0 if close else 0.35, 1.0]

func set_layer_targets(g: Array) -> void:
	layer_gain = g

func _process(delta: float) -> void:
	if music_name != "layers" or layers.is_empty():
		return
	for i in layers.size():
		layer_cur[i] = move_toward(layer_cur[i], layer_gain[i], delta * 1.5)
		layers[i].volume_db = linear_to_db(maxf(0.0001, music_vol * 0.6 * layer_cur[i]))

func play_music(name: String) -> void:
	if name == "music_battle":
		if music_name != "layers":
			play_layers()
		return
	if name == music_name:
		return
	stop_layers()
	music_name = name
	var st = load("res://audio/%s.wav" % name)
	if st == null:
		music.stop()
		return
	music.stream = st
	music.volume_db = linear_to_db(maxf(0.0001, music_vol * 0.6))
	music.play()
