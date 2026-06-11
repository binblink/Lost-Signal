extends Control

@onready var _background      = %Background
@onready var _title           = %GameTitle
@onready var _btn_continue    = %BtnContinue
@onready var _btn_new_game    = %BtnNewGame
@onready var _btn_settings    = %BtnSettings
@onready var _overlay         = %Overlay
@onready var _settings_dialog = %SettingsDialog


func _ready() -> void:
	_background.color = ThemeManager.background_color
	_title.add_theme_color_override("font_color", ThemeManager.text_color)
	_title.add_theme_font_size_override("font_size", 32)

	ThemeManager.restyle_button(_btn_continue, ThemeManager.topbar_color)
	ThemeManager.restyle_button(_btn_new_game, ThemeManager.accent_color)
	ThemeManager.restyle_button(_btn_settings, ThemeManager.topbar_color)
	for btn in [_btn_continue, _btn_new_game, _btn_settings]:
		btn.add_theme_color_override("font_color", ThemeManager.text_color)
		btn.add_theme_font_size_override("font_size", ThemeManager.font_size)

	var has_save := SaveManager.has_save()
	_btn_continue.disabled = not has_save
	if not has_save:
		_btn_continue.modulate.a = 0.35

	_btn_continue.pressed.connect(_on_continue)
	_btn_new_game.pressed.connect(_on_new_game)
	_btn_settings.pressed.connect(_on_settings_pressed)
	_settings_dialog.accepted.connect(_on_settings_accepted)
	_settings_dialog.cancelled.connect(func(): _overlay.visible = false)


func _on_continue() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _on_new_game() -> void:
	SaveManager.delete_save()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_settings_pressed() -> void:
	_overlay.visible = true
	_settings_dialog.open()

func _on_settings_accepted(language_changed: bool) -> void:
	_overlay.visible = false
	if language_changed:
		DialogueLoader.reload_for_locale()
		get_tree().reload_current_scene()
