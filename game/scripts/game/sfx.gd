extends Node
## 音效與音樂（優化方案 H）：同類音效 80ms 內最多 2 個、音高 ±10% 隨機；音樂與音效分軌。

const FILES := ["arrow", "backstab", "block", "brace", "charge", "clutch", "death", "frenzy", "hit", "lose",
	"place_heavy", "place_light", "place_mid", "slash", "start", "turn", "ui_click", "ui_deny", "win"]
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
	for p in players:
		if not p.playing:
			p.stream = streams[name]
			p.pitch_scale = 1.0 + rng.randf_range(-0.1, 0.1)
			p.volume_db = linear_to_db(maxf(0.0001, sfx_vol * vol))
			p.play()
			return

func play_music(name: String) -> void:
	if name == music_name:
		return
	music_name = name
	var st = load("res://audio/%s.wav" % name)
	if st == null:
		music.stop()
		return
	music.stream = st
	music.volume_db = linear_to_db(maxf(0.0001, music_vol * 0.6))
	music.play()
