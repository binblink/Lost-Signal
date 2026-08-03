extends Node

const SafeFile = preload("res://scripts/lib/safe_file.gd")
const SETTINGS_PATH = "user://settings.json"
var settings_path: String = SETTINGS_PATH

var SUPPORTED_LANGUAGES: Array[String] = ["fr", "en"]

const RESOLUTIONS := [
	{"label": "DISPLAY_480P",  "size": Vector2i(854,  480)},
	{"label": "DISPLAY_720P",  "size": Vector2i(1280, 720)},
	{"label": "DISPLAY_900P",  "size": Vector2i(1600, 900)},
	{"label": "DISPLAY_1080P", "size": Vector2i(1920, 1080)},
	{"label": "DISPLAY_1440P", "size": Vector2i(2560, 1440)},
	{"label": "DISPLAY_4K",    "size": Vector2i(3840, 2160)},
]
const WINDOW_MODES := ["DISPLAY_WINDOWED", "DISPLAY_BORDERLESS", "DISPLAY_FULLSCREEN"]

var language:      String = "en"
var volume:        float  = 1.0
var music_volume:  float  = 1.0
var resolution:    int    = 3  # 1080p
var window_mode:   int    = 0  # windowed

const UI_CSV_PATH = "res://translations/ui.csv"
var ui_csv_path: String = UI_CSV_PATH


func _ready() -> void:
	_discover_supported_languages()
	_load_translations()
	_load()
	_apply()


func _load_translations() -> void:
	for locale: String in SUPPORTED_LANGUAGES:
		var path := "res://translations/ui.%s.translation" % locale
		if ResourceLoader.exists(path):
			var translation := load(path) as Translation
			if translation != null:
				TranslationServer.add_translation(translation)
		else:
			push_warning("SettingsManager: translation file not found — " + path)


func _discover_supported_languages() -> void:
	var result := SafeFile.read_csv(ui_csv_path)
	var rows: Array = result.get("rows", [])
	if not result.get("ok", false) or rows.is_empty():
		return
	var header: PackedStringArray = rows[0]
	var discovered: Array[String] = []
	for column_index: int in range(1, header.size()):
		var locale := header[column_index].strip_edges()
		if not locale.is_empty() and locale not in discovered:
			discovered.append(locale)
	if not discovered.is_empty():
		SUPPORTED_LANGUAGES = discovered


func get_supported_languages() -> Array[String]:
	return SUPPORTED_LANGUAGES.duplicate()


func _fallback_language() -> String:
	for preferred: String in ["en", "fr"]:
		if preferred in SUPPORTED_LANGUAGES:
			return preferred
	return SUPPORTED_LANGUAGES[0] if not SUPPORTED_LANGUAGES.is_empty() else "en"


func apply_and_save() -> void:
	_apply()
	AudioManager.apply_music_volume()
	_save()


func _apply() -> void:
	TranslationServer.set_locale(language)
	var bus := AudioServer.get_bus_index("Master")
	if volume <= 0.0:
		AudioServer.set_bus_mute(bus, true)
	else:
		AudioServer.set_bus_mute(bus, false)
		AudioServer.set_bus_volume_db(bus, linear_to_db(volume))
	match window_mode:
		0:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(RESOLUTIONS[resolution]["size"])
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)


func _save() -> bool:
	var result := SafeFile.write_json(settings_path, {
		"language":     language,
		"volume":       volume,
		"music_volume": music_volume,
		"resolution":   resolution,
		"window_mode":  window_mode,
	})
	if not result.get("ok", false):
		push_error("SettingsManager: " + result.get("error", "Unknown settings write error."))
	return result.get("ok", false)


func _load(log_errors: bool = true) -> void:
	var result := SafeFile.read_json(settings_path)
	if not result.get("ok", false) and not result.get("found_invalid", false):
		var system_language := OS.get_locale_language()
		language = system_language if system_language in SUPPORTED_LANGUAGES else _fallback_language()
		return
	if not result.get("ok", false):
		if log_errors:
			push_error("SettingsManager: " + result.get("error", "Invalid settings file."))
		return
	if log_errors and result.get("recovered", false):
		push_warning("SettingsManager: recovered settings from %s." % result.get("recovery_source", "backup"))
	var data: Dictionary = result.get("data", {})
	language     = str(data.get("language", "fr"))
	volume       = float(data.get("volume", 1.0))
	music_volume = float(data.get("music_volume", 1.0))
	resolution   = int(data.get("resolution", 3))
	window_mode  = int(data.get("window_mode", 0))
	# Migrate from display_mode (1280/1920/fullscreen).
	if data.has("display_mode") and not data.has("resolution"):
		var display_mode := int(data["display_mode"])
		resolution  = 1 if display_mode == 0 else 3
		window_mode = 1 if display_mode == 2 else 0
	# Migrate from fullscreen: bool.
	if data.has("fullscreen") and not data.has("window_mode"):
		window_mode = 1 if data["fullscreen"] else 0
	# Migrate old AudioManager format: {"muted": bool}.
	if data.has("muted") and not data.has("volume"):
		volume = 0.0 if data["muted"] else 1.0
	# Settings are user-editable: syntactically valid JSON can still be unsafe.
	if language not in SUPPORTED_LANGUAGES:
		language = _fallback_language()
	volume = clampf(volume, 0.0, 1.0)
	music_volume = clampf(music_volume, 0.0, 1.0)
	resolution = clampi(resolution, 0, RESOLUTIONS.size() - 1)
	window_mode = clampi(window_mode, 0, WINDOW_MODES.size() - 1)
