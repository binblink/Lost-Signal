extends MarginContainer

@onready var play_button  = $HBoxContainer/Bubble/MarginContainer/VBoxContainer/PlayerRow/PlayButton
@onready var progress_bar = $HBoxContainer/Bubble/MarginContainer/VBoxContainer/PlayerRow/Progress
@onready var duration_label = $HBoxContainer/Bubble/MarginContainer/VBoxContainer/PlayerRow/Duration
@onready var time_label   = $HBoxContainer/Bubble/MarginContainer/VBoxContainer/TimeAndStatus
@onready var player       = $AudioStreamPlayer

var _duration: float = 0.0


func _ready() -> void:
	player.finished.connect(_on_playback_finished)


func setup(path: String, time: String) -> void:
	time_label.text = time
	if ResourceLoader.exists(path):
		player.stream = load(path)
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
	else:
		player.play()
		play_button.text = "⏸"


func _on_playback_finished() -> void:
	play_button.text = "▶"
	progress_bar.value = 0.0
	duration_label.text = _format_duration(_duration)


func _format_duration(seconds: float) -> String:
	var s := int(seconds)
	return "%d:%02d" % [s / 60, s % 60]
