extends Node
## Music + weather ambience + SFX, on separate Music / SFX buses. Autoload name: Audio

const CFG := "user://settings.cfg"
const A := "res://assets/audio/"
const CUES := A + "audio cues/"
const MUS := A + "music/"

const MUSIC := {
	"menu": MUS + "The Protagonist.wav",
	"alley": MUS + "Empty Streets.wav",
	"main_street": MUS + "Empty Streets.wav",
	"downtown": MUS + "Dystopian.wav",
	"subway": MUS + "Dark Atmosphere to Synth.wav",
	"cityhall": MUS + "Surveillance.wav",
	"bar": MUS + "The Nightclub.wav",
	"office": MUS + "Surveillance.wav",
	"apartment": MUS + "Dystopian.wav",
	"docks": MUS + "Dark Atmosphere to Synth.wav",
	"clinic": MUS + "Surveillance.wav",
	"rooftop": MUS + "Dystopian.wav",
	"archive": MUS + "Surveillance.wav",
	"tower_lobby": MUS + "Dark Atmosphere to Synth.wav",
	"penthouse": MUS + "Dark Atmosphere to Synth.wav",
	"ending": MUS + "The Story Continues.wav",
}

const RAIN_OUT := CUES + "WE Heavy Outside Rain 1.wav"
const RAIN_IN := CUES + "WE Light Inside Rain 1.wav"
const WIND := CUES + "WE Light Wind Whistle 1.wav"
const THUNDER := [
	CUES + "WE Thunder 1.wav",
	CUES + "WE Thunder 26.wav",
	CUES + "WE Thunder 29.wav",
]

const SFX := {
	"blip": A + "ui_blip.wav",
	"clue": A + "clue.wav",
	"select": A + "select.wav",
	"door": A + "door open with creak.wav",
}

const MUSIC_DB := -8.0

var music_vol := 0.8
var sfx_vol := 0.8
var text_speed := 45.0  # dialogue reveal, characters/second (shared setting)

var _mus_a: AudioStreamPlayer
var _mus_b: AudioStreamPlayer
var _mus_cur: AudioStreamPlayer
var _mus_stream: AudioStream
var _rain: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _thunder: AudioStreamPlayer
var _sfx: AudioStreamPlayer
var _foot: AudioStreamPlayer

var _music_key := ""
var _rain_path := ""
var _exterior := false
var _menu := false
var _thunder_t := 0.0
var _thunder_next := 12.0

func _ready() -> void:
	_ensure_bus("Music")
	_ensure_bus("SFX")
	_load_settings()
	_apply_volumes()
	_mus_a = _make(-60.0, "Music")
	_mus_b = _make(-60.0, "Music")
	_mus_cur = _mus_a
	_rain = _make(-4.0, "SFX")
	_wind = _make(-60.0, "SFX")
	_thunder = _make(-5.0, "SFX")
	_foot = _make(-22.0, "SFX")
	_sfx = _make(0.0, "SFX")

func _make(db: float, bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.volume_db = db
	p.bus = bus
	add_child(p)
	return p

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")

func _set_loop(s) -> void:
	if s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		var bps := 2 if w.format == AudioStreamWAV.FORMAT_16_BITS else 1
		var ch := 2 if w.stereo else 1
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.data.size() / (bps * ch))

# --- Music ---
func play_music(key: String) -> void:
	if key == _music_key:
		return
	var path: String = MUSIC.get(key, "")
	if path == "" or not ResourceLoader.exists(path):
		return
	_music_key = key
	var s = load(path)
	if s == null:
		return
	_mus_stream = s
	_crossfade_music(s, 1.0)

## Crossfade to `s` on the idle player (also used to loop seamlessly).
func _crossfade_music(s: AudioStream, dur: float) -> void:
	var from := _mus_cur
	var to := _mus_b if _mus_cur == _mus_a else _mus_a
	_mus_cur = to
	to.stream = s
	to.volume_db = -60.0
	to.play()
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(to, "volume_db", MUSIC_DB, dur)
	if from and from.playing:
		t.tween_property(from, "volume_db", -60.0, dur)
		t.chain().tween_callback(func() -> void:
			if from and from != _mus_cur:
				from.stop())

# --- Weather ---
func set_weather(interior: bool, on_menu: bool = false) -> void:
	_exterior = not interior
	_menu = on_menu
	# The two rain recordings are ~25 dB apart in level, so we compensate per file to land
	# both a few dB UNDER the music. (Indoor/light file is very quiet -> boost; outdoor/heavy
	# file is louder than the music -> pull well down.)
	var rain_db := 9.0   # indoors (light-rain file, quiet)
	if not interior:
		rain_db = -19.0 if on_menu else -15.0   # outdoors (heavy-rain file, loud)
	var path := RAIN_IN if interior else RAIN_OUT
	if path != _rain_path and ResourceLoader.exists(path):
		# Different rain recording: hard-swapping it while the player is loud pops/booms.
		# Start the new stream silent and fade it in to its target level instead.
		_rain_path = path
		var s = load(path)
		_set_loop(s)
		_rain.stream = s
		_rain.volume_db = -60.0
		_rain.play()
		create_tween().tween_property(_rain, "volume_db", rain_db, 0.6)
	else:
		# Same recording (e.g. outdoor -> outdoor): just glide the level.
		create_tween().tween_property(_rain, "volume_db", rain_db, 0.6)

	if _exterior and _wind.stream == null and ResourceLoader.exists(WIND):
		var w = load(WIND)
		_set_loop(w)
		_wind.stream = w
		_wind.play()
	var wind_db := -60.0
	if _exterior:
		wind_db = -16.0 if on_menu else -10.0
	var wind_t := create_tween()
	wind_t.tween_property(_wind, "volume_db", wind_db, 0.8)
	_thunder_t = 0.0
	_thunder_next = randf_range(8.0, 20.0)

func _process(delta: float) -> void:
	# Seamless music loop: crossfade to a fresh instance shortly before the track ends.
	if _mus_cur and _mus_cur.playing and _mus_stream:
		var L := _mus_stream.get_length()
		if L > 0.0 and _mus_cur.get_playback_position() >= L - 2.5:
			_crossfade_music(_mus_stream, 2.0)

	if _exterior:
		_thunder_t += delta
		if _thunder_t >= _thunder_next:
			_thunder_t = 0.0
			_thunder_next = randf_range(16.0, 42.0)
			var p: String = THUNDER[randi() % THUNDER.size()]
			if ResourceLoader.exists(p):
				_thunder.stream = load(p)
				_thunder.play()
				Atmosphere.lightning()

# --- SFX ---
func play_sfx(key: String) -> void:
	if SFX.has(key) and _sfx:
		_sfx.stream = load(SFX[key])
		_sfx.play()

func play_step() -> void:
	if _foot:
		if _foot.stream == null:
			_foot.stream = load(A + "step.wav")
		_foot.play()

# --- Volume settings (per-bus) ---
func set_music_volume(v: float) -> void:
	music_vol = clamp(v, 0.0, 1.0)
	_apply_volumes()
	_save_settings()

func set_sfx_volume(v: float) -> void:
	sfx_vol = clamp(v, 0.0, 1.0)
	_apply_volumes()
	_save_settings()

func get_music_volume() -> float:
	return music_vol

func get_sfx_volume() -> float:
	return sfx_vol

# --- Text speed (dialogue reveal) ---
const TEXT_SPEED_MIN := 20.0
const TEXT_SPEED_MAX := 120.0

func set_text_speed(cps: float) -> void:
	text_speed = clamp(cps, TEXT_SPEED_MIN, TEXT_SPEED_MAX)
	_save_settings()

func get_text_speed() -> float:
	return text_speed

func _apply_volumes() -> void:
	var mi := AudioServer.get_bus_index("Music")
	var si := AudioServer.get_bus_index("SFX")
	if mi != -1:
		AudioServer.set_bus_volume_db(mi, linear_to_db(max(music_vol, 0.0001)))
	if si != -1:
		AudioServer.set_bus_volume_db(si, linear_to_db(max(sfx_vol, 0.0001)))

func _load_settings() -> void:
	var c := ConfigFile.new()
	if c.load(CFG) == OK:
		music_vol = float(c.get_value("audio", "music", 0.8))
		sfx_vol = float(c.get_value("audio", "sfx", 0.8))
		text_speed = clamp(float(c.get_value("gameplay", "text_speed", 45.0)), TEXT_SPEED_MIN, TEXT_SPEED_MAX)

func _save_settings() -> void:
	var c := ConfigFile.new()
	c.set_value("audio", "music", music_vol)
	c.set_value("audio", "sfx", sfx_vol)
	c.set_value("gameplay", "text_speed", text_speed)
	c.save(CFG)
