extends PanelContainer

signal accepted(language_changed: bool)
signal cancelled

@onready var _lang_option        = $MarginContainer/VBoxContainer/Grid/LangOption
@onready var _vol_slider         = $MarginContainer/VBoxContainer/Grid/VolSlider
@onready var _music_vol_slider   = $MarginContainer/VBoxContainer/Grid/MusicVolSlider
@onready var _resolution_option  = $MarginContainer/VBoxContainer/Grid/ResolutionOption
@onready var _display_option     = $MarginContainer/VBoxContainer/Grid/DisplayOption
@onready var _btn_cancel        = $MarginContainer/VBoxContainer/Buttons/Cancel
@onready var _btn_accept        = $MarginContainer/VBoxContainer/Buttons/Accept

func _ready() -> void:
	_refresh_language_options()
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
	_refresh_language_options()
	var languages := SettingsManager.get_supported_languages()
	var lang_idx := languages.find(SettingsManager.language)
	_lang_option.selected        = max(0, lang_idx)
	_vol_slider.value            = SettingsManager.volume * 100.0
	_music_vol_slider.value      = SettingsManager.music_volume * 100.0
	_resolution_option.selected  = SettingsManager.resolution
	_display_option.selected    = SettingsManager.window_mode
	_on_display_mode_changed(SettingsManager.window_mode)
	visible = true

func _on_cancel() -> void:
	visible = false
	cancelled.emit()

func _on_accept() -> void:
	var prev_lang := SettingsManager.language
	var languages := SettingsManager.get_supported_languages()
	if _lang_option.selected >= 0 and _lang_option.selected < languages.size():
		SettingsManager.language = languages[_lang_option.selected]
	SettingsManager.volume       = _vol_slider.value / 100.0
	SettingsManager.music_volume = _music_vol_slider.value / 100.0
	SettingsManager.resolution   = _resolution_option.selected
	SettingsManager.window_mode  = _display_option.selected
	SettingsManager.apply_and_save()
	visible = false
	accepted.emit(SettingsManager.language != prev_lang)


func _refresh_language_options() -> void:
	_lang_option.clear()
	for locale: String in SettingsManager.get_supported_languages():
		var label := TranslationServer.get_locale_name(locale)
		_lang_option.add_item(label if not label.is_empty() else locale)
		_lang_option.set_item_tooltip(_lang_option.item_count - 1, locale)
