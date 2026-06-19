extends Node

const NOTIFICATION_VOL_DB = -8.0
const TYPING_VOL_DB       = -20.0
const MUSIC_VOL_DB        = 0.0
const MUSIC_DUCK_DB       = -18.0
const MUSIC_FADE_DURATION = 0.8
const MUSIC_DUCK_DURATION = 0.4

var _notif_player:  AudioStreamPlayer
var _typing_player: AudioStreamPlayer
var _music_player:  AudioStreamPlayer
var _current_music_path: String = ""
var _music_tween: Tween = null

const _SAMPLE_RATE: int = 22050


func _ready() -> void:
	_notif_player = AudioStreamPlayer.new()
	_notif_player.volume_db = NOTIFICATION_VOL_DB
	add_child(_notif_player)

	_typing_player = AudioStreamPlayer.new()
	_typing_player.volume_db = TYPING_VOL_DB
	add_child(_typing_player)

	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = MUSIC_VOL_DB
	_music_player.finished.connect(_on_music_finished)
	add_child(_music_player)

	_notif_player.stream = _make_notification_beep()
	_typing_player.stream = _make_typing_click()


func play_notification() -> void:
	_notif_player.play()


func play_typing_click() -> void:
	_typing_player.pitch_scale = randf_range(0.92, 1.08)
	_typing_player.play()


func play_music(path: String) -> void:
	if path == _current_music_path and _music_player.playing:
		return
	_current_music_path = path
	var stream = load(path)
	if stream == null:
		push_warning("AudioManager: music file not found — %s" % path)
		return
	_kill_tween()
	_music_player.stream = stream
	_music_player.volume_db = MUSIC_VOL_DB
	_music_player.play()


func stop_music() -> void:
	_current_music_path = ""
	_fade_music_to(-80.0, MUSIC_FADE_DURATION, true)


func duck_music() -> void:
	_fade_music_to(MUSIC_DUCK_DB, MUSIC_DUCK_DURATION, false)


func unduck_music() -> void:
	_fade_music_to(MUSIC_VOL_DB, MUSIC_DUCK_DURATION, false)


func _on_music_finished() -> void:
	if _current_music_path != "":
		_music_player.play()


func _fade_music_to(target_db: float, duration: float, stop_after: bool) -> void:
	if not _music_player.playing and not stop_after:
		return
	_kill_tween()
	_music_tween = create_tween()
	_music_tween.tween_property(_music_player, "volume_db", target_db, duration)
	if stop_after:
		_music_tween.tween_callback(_music_player.stop)


func _kill_tween() -> void:
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = null

# Two-tone ping: 880 Hz then 1320 Hz (pleasing minor sixth).
func _make_notification_beep() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.mix_rate = _SAMPLE_RATE
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo = false

	var t1 := 0.12
	var t2 := 0.18
	var total := t1 + t2
	var n := int(total * _SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)

	for i in range(n):
		var t := float(i) / _SAMPLE_RATE
		var freq := 880.0 if t < t1 else 1320.0
		var env: float
		if t < t1:
			env = sin(PI * (t / t1)) * 0.5
		else:
			env = sin(PI * ((t - t1) / t2)) * 0.65
		var s := int(clamp(sin(TAU * freq * t) * env * 0.7, -1.0, 1.0) * 32767)
		var u := s if s >= 0 else s + 65536
		data[i * 2]     = u & 0xFF
		data[i * 2 + 1] = (u >> 8) & 0xFF

	stream.data = data
	return stream

# Short noise-burst click, like a soft keyboard key.
func _make_typing_click() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.mix_rate = _SAMPLE_RATE
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo = false

	var duration := 0.028
	var n := int(duration * _SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)

	for i in range(n):
		var t := float(i) / _SAMPLE_RATE
		var env := exp(-t / (duration * 0.28))
		var sample_f := (sin(TAU * 1400.0 * t) * 0.35 + randf_range(-1.0, 1.0) * 0.65) * env * 0.22
		var s := int(clamp(sample_f, -1.0, 1.0) * 32767)
		var u := s if s >= 0 else s + 65536
		data[i * 2]     = u & 0xFF
		data[i * 2 + 1] = (u >> 8) & 0xFF

	stream.data = data
	return stream
