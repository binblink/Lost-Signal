extends MarginContainer

@onready var play_button    = %PlayButton
@onready var progress_bar   = %Progress
@onready var duration_label = %Duration
@onready var time_label     = %TimeAndStatus
@onready var player         = %AudioStreamPlayer

var _duration: float = 0.0


func _ready() -> void:
	player.finished.connect(_on_playback_finished)
	ThemeManager.restyle_panel(%Bubble, ThemeManager.bubble_in_color)
	duration_label.add_theme_color_override("font_color", ThemeManager.time_color)
	time_label.add_theme_color_override("font_color", ThemeManager.time_color)


func setup(path: String, time: String) -> void:
	time_label.text = time
	if ResourceLoader.exists(path):
		var stream = load(path)
		if stream == null:
			push_error("AudioBubble: failed to load %s." % path)
			play_button.disabled = true
		else:
			player.stream = stream
			_duration = player.stream.get_length()
			duration_label.text = _format_duration(_duration)
	play_button.pressed.connect(_on_play_pressed)


func _process(_delta: float) -> void:
	if not player.playing:
		return
	var pos = player.get_playback_position()
	progress_bar.value = pos / _duration if _duration > 0.0 else 0.0
	duration_label.text = _format_duration(_duration - pos)


func _on_play_pressed() -> void:
	if player.playing:
		player.stop()
		play_button.text = "▶"
		AudioManager.unduck_music()
	else:
		AudioManager.duck_music()
		player.play()
		play_button.text = "⏸"


func _on_playback_finished() -> void:
	play_button.text = "▶"
	progress_bar.value = 0.0
	duration_label.text = _format_duration(_duration)
	AudioManager.unduck_music()


func _format_duration(seconds: float) -> String:
	var s := int(seconds)
	return "%d:%02d" % [floori(s / 60.0), s % 60]
