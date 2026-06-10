extends Node

const NOTIFICATION_VOL_DB = -8.0
const TYPING_VOL_DB       = -20.0
const SETTINGS_PATH       = "user://settings.json"

var is_muted: bool = false

var _notif_player: AudioStreamPlayer
var _typing_player: AudioStreamPlayer

const _SAMPLE_RATE: int = 22050

func _ready() -> void:
	_load_settings()

	_notif_player = AudioStreamPlayer.new()
	_notif_player.volume_db = NOTIFICATION_VOL_DB
	add_child(_notif_player)

	_typing_player = AudioStreamPlayer.new()
	_typing_player.volume_db = TYPING_VOL_DB
	add_child(_typing_player)

	_notif_player.stream = _make_notification_beep()
	_typing_player.stream = _make_typing_click()

func toggle_mute() -> void:
	is_muted = not is_muted
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), is_muted)
	_save_settings()

func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		push_error("AudioManager: impossible d'ouvrir les paramètres (code %d)." % FileAccess.get_open_error())
		return
	var json  = JSON.new()
	if json.parse(file.get_as_text()) == OK:
		is_muted = json.get_data().get("muted", false)
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), is_muted)
	file.close()

func _save_settings() -> void:
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		push_error("AudioManager: impossible d'écrire les paramètres (code %d)." % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify({ "muted": is_muted }))
	file.close()

func play_notification() -> void:
	_notif_player.play()

func play_typing_click() -> void:
	_typing_player.pitch_scale = randf_range(0.92, 1.08)
	_typing_player.play()

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
