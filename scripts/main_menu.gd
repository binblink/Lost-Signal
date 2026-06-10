extends Control

@onready var _background   = %Background
@onready var _title        = %GameTitle
@onready var _btn_continue = %BtnContinue
@onready var _btn_new_game = %BtnNewGame


func _ready() -> void:
	_background.color = ThemeManager.background_color
	_title.add_theme_color_override("font_color", ThemeManager.text_color)
	_title.add_theme_font_size_override("font_size", 32)

	ThemeManager.restyle_button(_btn_continue, ThemeManager.topbar_color)
	ThemeManager.restyle_button(_btn_new_game, ThemeManager.accent_color)
	for btn in [_btn_continue, _btn_new_game]:
		btn.add_theme_color_override("font_color", ThemeManager.text_color)
		btn.add_theme_font_size_override("font_size", ThemeManager.font_size)

	var has_save := SaveManager.has_save()
	_btn_continue.disabled = not has_save
	if not has_save:
		_btn_continue.modulate.a = 0.35

	_btn_continue.pressed.connect(_on_continue)
	_btn_new_game.pressed.connect(_on_new_game)


func _on_continue() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _on_new_game() -> void:
	SaveManager.delete_save()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
