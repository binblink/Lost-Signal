extends PanelContainer

signal accepted(language_changed: bool)
signal cancelled

const LANGUAGES     = ["fr", "en"]
const LANG_LABELS   = ["Français", "English"]
const DISPLAY_MODES = ["DISPLAY_WINDOWED", "DISPLAY_FULLSCREEN"]

@onready var _lang_option    = $MarginContainer/VBoxContainer/Grid/LangOption
@onready var _vol_slider     = $MarginContainer/VBoxContainer/Grid/VolSlider
@onready var _display_option = $MarginContainer/VBoxContainer/Grid/DisplayOption
@onready var _btn_cancel     = $MarginContainer/VBoxContainer/Buttons/Cancel
@onready var _btn_accept     = $MarginContainer/VBoxContainer/Buttons/Accept

func _ready() -> void:
	for label in LANG_LABELS:
		_lang_option.add_item(label)
	for mode in DISPLAY_MODES:
		_display_option.add_item(tr(mode))
	_btn_cancel.pressed.connect(_on_cancel)
	_btn_accept.pressed.connect(_on_accept)

func open() -> void:
	var lang_idx := LANGUAGES.find(SettingsManager.language)
	_lang_option.selected    = max(0, lang_idx)
	_vol_slider.value        = SettingsManager.volume * 100.0
	_display_option.selected = 1 if SettingsManager.fullscreen else 0
	visible = true

func _on_cancel() -> void:
	visible = false
	cancelled.emit()

func _on_accept() -> void:
	var prev_lang := SettingsManager.language
	SettingsManager.language   = LANGUAGES[_lang_option.selected]
	SettingsManager.volume     = _vol_slider.value / 100.0
	SettingsManager.fullscreen = _display_option.selected == 1
	SettingsManager.apply_and_save()
	visible = false
	accepted.emit(SettingsManager.language != prev_lang)
