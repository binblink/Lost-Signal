extends Node

const SETTINGS_PATH = "user://settings.json"

const SUPPORTED_LANGUAGES := ["fr", "en"]

const RESOLUTIONS := [
	{"label": "DISPLAY_480P",  "size": Vector2i(854,  480)},
	{"label": "DISPLAY_720P",  "size": Vector2i(1280, 720)},
	{"label": "DISPLAY_900P",  "size": Vector2i(1600, 900)},
	{"label": "DISPLAY_1080P", "size": Vector2i(1920, 1080)},
	{"label": "DISPLAY_1440P", "size": Vector2i(2560, 1440)},
	{"label": "DISPLAY_4K",    "size": Vector2i(3840, 2160)},
]
const WINDOW_MODES := ["DISPLAY_WINDOWED", "DISPLAY_BORDERLESS", "DISPLAY_FULLSCREEN"]

var language:     String = "en"
var volume:       float  = 1.0
var resolution:   int    = 3  # 1080p
var window_mode:  int    = 0  # windowed

const UI_CSV_PATH = "res://translations/ui.csv"

func _ready() -> void:
	_load_translations()
	_load()
	_apply()

func _load_translations() -> void:
	for locale: String in SUPPORTED_LANGUAGES:
		var path := "res://translations/ui.%s.translation" % locale
		if ResourceLoader.exists(path):
			var t := load(path) as Translation
			if t != null:
				TranslationServer.add_translation(t)
		else:
			push_warning("SettingsManager: translation file not found — " + path)

func apply_and_save() -> void:
	_apply()
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

func _save() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SettingsManager: cannot write settings (code %d)." % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify({
		"language":    language,
		"volume":      volume,
		"resolution":  resolution,
		"window_mode": window_mode,
	}))
	file.close()

func _load() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		var sys_lang := OS.get_locale_language()
		language = sys_lang if sys_lang in SUPPORTED_LANGUAGES else "en"
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK:
		var d = json.get_data()
		language    = d.get("language", "fr")
		volume      = float(d.get("volume", 1.0))
		resolution  = int(d.get("resolution", 3))
		window_mode = int(d.get("window_mode", 0))
		# Migrate from display_mode (1280/1920/fullscreen)
		if d.has("display_mode") and not d.has("resolution"):
			var dm := int(d["display_mode"])
			resolution  = 1 if dm == 0 else 3
			window_mode = 1 if dm == 2 else 0
		# Migrate from fullscreen: bool
		if d.has("fullscreen") and not d.has("window_mode"):
			window_mode = 1 if d["fullscreen"] else 0
		# Migrate old AudioManager format: {"muted": bool}
		if d.has("muted") and not d.has("volume"):
			volume = 0.0 if d["muted"] else 1.0
	file.close()
