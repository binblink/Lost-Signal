extends RefCounted

var start_scene: String = ""
var contacts: Array = []
var chosen_files: Dictionary = {}   # base_name → file_name (relatif à dialogues/)
var error_message: String = ""
var locale_override: String = ""    # si non vide, utilisé à la place de settings.json


static func detect_locales() -> Array[String]:
	var dir := DirAccess.open("res://dialogues")
	if dir == null:
		return []
	var locales: Array[String] = []
	var has_base := false
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if not dir.current_is_dir() and f.ends_with(".json"):
			var base: String = f.get_basename()
			var parts := base.split(".")
			if parts.size() == 2:
				var loc: String = parts[1]
				if loc not in locales:
					locales.append(loc)
			elif parts.size() == 1:
				has_base = true
		f = dir.get_next()
	dir.list_dir_end()
	locales.sort()
	if has_base:
		var base_locale: String = _read_base_locale()
		if base_locale not in locales:
			locales.insert(0, base_locale)
	return locales


static func _read_base_locale() -> String:
	if not FileAccess.file_exists("res://story.json"):
		return "fr"
	var sf := FileAccess.open("res://story.json", FileAccess.READ)
	if sf == null:
		return "fr"
	var parsed: Variant = JSON.parse_string(sf.get_as_text())
	sf.close()
	if parsed is Dictionary:
		var settings: Dictionary = parsed.get("settings", {})
		var lang: String = settings.get("default_language", "fr")
		return lang
	return "fr"


func parse_all() -> Dictionary:
	error_message = ""
	start_scene = ""
	contacts = []
	var scenes := {}

	var story := _read_json("res://story.json")
	if story.is_empty():
		error_message = "story.json introuvable ou invalide"
		return scenes

	start_scene = story.get("start_scene", "")
	contacts = story.get("contacts", [])

	var dir := DirAccess.open("res://dialogues")
	if dir == null:
		error_message = "Dossier dialogues/ introuvable"
		return scenes

	var locale := _read_locale()

	# Même logique que dialogue_loader.gd :
	# pour chaque base (ex: "acte1"), préférer base.locale.json, fallback sur base.json
	var all_files: Array[String] = []
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if not dir.current_is_dir() and f.ends_with(".json"):
			all_files.append(f)
		f = dir.get_next()
	dir.list_dir_end()

	var chosen: Dictionary = {}
	for file_name in all_files:
		var base: String = file_name.get_basename()
		var parts: PackedStringArray = base.split(".")
		if parts.size() == 2:
			if parts[1] == locale:
				chosen[parts[0]] = file_name
		elif parts.size() == 1:
			if not chosen.has(base):
				chosen[base] = file_name
	chosen_files = chosen

	var main_contact_id := ""
	for c in contacts:
		if c.get("is_main", false):
			main_contact_id = c.get("id", "")
			break

	for file_name in chosen.values():
		var path: String = "res://dialogues/" + str(file_name)
		if not FileAccess.file_exists(path):
			continue
		var raw_file := FileAccess.open(path, FileAccess.READ)
		if raw_file == null:
			continue
		var raw_text: String = raw_file.get_as_text()
		raw_file.close()
		var parsed: Variant = JSON.parse_string(raw_text)
		if parsed == null:
			error_message = str(file_name) + " : JSON invalide"
			return scenes
		if not parsed is Dictionary or not (parsed as Dictionary).has("scenes"):
			continue
		for scene: Variant in ((parsed as Dictionary)["scenes"] as Array):
			var sd: Dictionary = scene as Dictionary
			if sd.has("id"):
				if not sd.has("contact_id"):
					sd["contact_id"] = main_contact_id
				sd["_editor_file"] = file_name
				scenes[sd["id"]] = sd

	return scenes


func _read_locale() -> String:
	if locale_override != "":
		return locale_override
	var settings := _read_json("user://settings.json")
	return settings.get("language", "fr")


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		return parsed
	return {}
