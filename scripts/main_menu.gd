extends Control

@onready var _background   = %Background
@onready var _title        = %GameTitle
@onready var _btn_continue = %BtnContinue
@onready var _btn_new_game = %BtnNewGame


func _ready() -> void:
	_background.color = ThemeManager.background_color
	_title.add_theme_color_override("font_color", ThemeManager.text_color)
	_title.add_theme_font_size_override("font_size", 32)

	_style_button(_btn_continue, ThemeManager.topbar_color)
	_style_button(_btn_new_game, ThemeManager.accent_color)
	for btn in [_btn_continue, _btn_new_game]:
		btn.add_theme_color_override("font_color", ThemeManager.text_color)
		btn.add_theme_font_size_override("font_size", ThemeManager.font_size)

	var has_save := SaveManager.has_save()
	_btn_continue.disabled = not has_save
	if not has_save:
		_btn_continue.modulate.a = 0.35

	_btn_continue.pressed.connect(_on_continue)
	_btn_new_game.pressed.connect(_on_new_game)


func _style_button(btn: Button, color: Color) -> void:
	var states := {
		"normal":        color,
		"focus":         color,
		"hover":         Color(min(1.0, color.r * 1.2), min(1.0, color.g * 1.2), min(1.0, color.b * 1.2)),
		"hover_pressed": Color(min(1.0, color.r * 1.2), min(1.0, color.g * 1.2), min(1.0, color.b * 1.2)),
		"pressed":       Color(color.r * 0.8, color.g * 0.8, color.b * 0.8),
	}
	for state in states:
		var s := StyleBoxFlat.new()
		s.bg_color = states[state]
		s.corner_radius_top_left     = 8
		s.corner_radius_top_right    = 8
		s.corner_radius_bottom_right = 8
		s.corner_radius_bottom_left  = 8
		s.content_margin_left   = 24.0
		s.content_margin_right  = 24.0
		s.content_margin_top    = 10.0
		s.content_margin_bottom = 10.0
		btn.add_theme_stylebox_override(state, s)


func _on_continue() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _on_new_game() -> void:
	SaveManager.delete_save()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
