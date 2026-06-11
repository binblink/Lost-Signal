extends PanelContainer

signal accepted(language_changed: bool)
signal cancelled

const LANGUAGES     = ["fr", "en"]
const LANG_LABELS   = ["Français", "English"]

@onready var _lang_option       = $MarginContainer/VBoxContainer/Grid/LangOption
@onready var _vol_slider        = $MarginContainer/VBoxContainer/Grid/VolSlider
@onready var _resolution_option = $MarginContainer/VBoxContainer/Grid/ResolutionOption
@onready var _display_option    = $MarginContainer/VBoxContainer/Grid/DisplayOption
@onready var _btn_cancel        = $MarginContainer/VBoxContainer/Buttons/Cancel
@onready var _btn_accept        = $MarginContainer/VBoxContainer/Buttons/Accept

func _ready() -> void:
	for label in LANG_LABELS:
		_lang_option.add_item(label)
	for res in SettingsManager.RESOLUTIONS:
		_resolution_option.add_item(tr(res["label"]))
	for mode in SettingsManager.WINDOW_MODES:
		_display_option.add_item(tr(mode))
	_btn_cancel.pressed.connect(_on_cancel)
	_btn_accept.pressed.connect(_on_accept)
	_display_option.item_selected.connect(_on_display_mode_changed)

func _on_display_mode_changed(index: int) -> void:
	_resolution_option.disabled = index != 0
	_resolution_option.modulate.a = 0.35 if index != 0 else 1.0

func open() -> void:
	var lang_idx := LANGUAGES.find(SettingsManager.language)
	_lang_option.selected       = max(0, lang_idx)
	_vol_slider.value           = SettingsManager.volume * 100.0
	_resolution_option.selected = SettingsManager.resolution
	_display_option.selected    = SettingsManager.window_mode
	_on_display_mode_changed(SettingsManager.window_mode)
	visible = true

func _on_cancel() -> void:
	visible = false
	cancelled.emit()

func _on_accept() -> void:
	var prev_lang := SettingsManager.language
	SettingsManager.language    = LANGUAGES[_lang_option.selected]
	SettingsManager.volume      = _vol_slider.value / 100.0
	SettingsManager.resolution  = _resolution_option.selected
	SettingsManager.window_mode = _display_option.selected
	SettingsManager.apply_and_save()
	visible = false
	accepted.emit(SettingsManager.language != prev_lang)
