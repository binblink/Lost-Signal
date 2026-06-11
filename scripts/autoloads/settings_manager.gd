extends Node

const SETTINGS_PATH = "user://settings.json"

const SUPPORTED_LANGUAGES := ["fr", "en"]

var language:   String = "en"
var volume:     float  = 1.0
var fullscreen: bool   = false

const UI_CSV_PATH = "res://translations/ui.csv"

func _ready() -> void:
	_load_translations()
	_load()
	_apply()

func _load_translations() -> void:
	var file := FileAccess.open(UI_CSV_PATH, FileAccess.READ)
	if file == null:
		push_error("SettingsManager: cannot open translations CSV.")
		return
	var header := file.get_csv_line()   # ["keys", "en", "fr", ...]
	var locales := header.slice(1)
	var translations: Dictionary = {}
	for loc in locales:
		var t := Translation.new()
		t.locale = loc
		translations[loc] = t
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() < 2 or row[0].strip_edges().is_empty():
			continue
		var key: String = row[0]
		for i in range(locales.size()):
			if i + 1 < row.size():
				translations[locales[i]].add_message(key, row[i + 1])
	file.close()
	for t in translations.values():
		TranslationServer.add_translation(t)

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
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)

func _save() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SettingsManager: cannot write settings (code %d)." % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify({
		"language":   language,
		"volume":     volume,
		"fullscreen": fullscreen
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
		language   = d.get("language",   "fr")
		volume     = float(d.get("volume", 1.0))
		fullscreen = bool(d.get("fullscreen", false))
		# Migrate old AudioManager format ({"muted": bool})
		if d.has("muted") and not d.has("volume"):
			volume = 0.0 if d["muted"] else 1.0
	file.close()
