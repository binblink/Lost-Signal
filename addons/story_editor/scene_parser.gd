extends RefCounted

const SafeFile = preload("res://scripts/lib/safe_file.gd")

var start_scene: String = ""
var contacts: Array = []
var chosen_files: Dictionary = {}   # base_name -> file_name, relative to dialogues_dir
var error_message: String = ""
var locale_override: String = ""

# Injectable paths keep editor parsing isolated and testable.
var story_path: String = "res://story.json"
var dialogues_dir: String = "res://dialogues"
var settings_path: String = "user://settings.json"


static func detect_locales(dialogues_path: String = "res://dialogues", source_story_path: String = "res://story.json") -> Array[String]:
	var dir := DirAccess.open(dialogues_path)
	if dir == null:
		return []
	var locales: Array[String] = []
	var has_base := false
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var base: String = file_name.get_basename()
			var parts := base.split(".")
			if parts.size() == 2:
				var locale: String = parts[1]
				if locale not in locales:
					locales.append(locale)
			elif parts.size() == 1:
				has_base = true
		file_name = dir.get_next()
	dir.list_dir_end()
	locales.sort()
	if has_base:
		var base_locale: String = _read_base_locale(source_story_path)
		if base_locale not in locales:
			locales.insert(0, base_locale)
	return locales


static func _read_base_locale(source_story_path: String = "res://story.json") -> String:
	var result := SafeFile.read_json(source_story_path)
	if result.get("ok", false):
		var parsed: Dictionary = result.get("data", {})
		var settings: Dictionary = parsed.get("settings", {})
		var language: String = settings.get("default_language", "fr")
		return language
	return "fr"


func parse_all() -> Dictionary:
	error_message = ""
	start_scene = ""
	contacts = []
	chosen_files = {}
	var scenes: Dictionary = {}

	var story := _read_json(story_path)
	if story.is_empty():
		error_message = "story.json introuvable ou invalide"
		return scenes

	start_scene = story.get("start_scene", "")
	contacts = story.get("contacts", [])

	var dir := DirAccess.open(dialogues_dir)
	if dir == null:
		error_message = "Dossier dialogues/ introuvable"
		return scenes

	var all_files: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			all_files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	all_files.sort()
	chosen_files = _choose_dialogue_files(all_files, _read_locale())

	var main_contact_id := ""
	for contact in contacts:
		if contact.get("is_main", false):
			main_contact_id = contact.get("id", "")
			break

	for chosen_file: String in chosen_files.values():
		var path: String = dialogues_dir.path_join(chosen_file)
		var read_result := SafeFile.read_json(path)
		if not read_result.get("ok", false):
			error_message = chosen_file + " : JSON invalide"
			return scenes
		var parsed: Dictionary = read_result.get("data", {})
		if not parsed.get("scenes") is Array:
			continue
		for scene: Variant in (parsed["scenes"] as Array):
			if not scene is Dictionary:
				continue
			var scene_data: Dictionary = scene as Dictionary
			if not scene_data.has("id"):
				continue
			var scene_id: String = str(scene_data["id"])
			if scenes.has(scene_id):
				error_message = "%s : ID de scène dupliqué '%s'" % [chosen_file, scene_id]
				return scenes
			if not scene_data.has("contact_id"):
				scene_data["contact_id"] = main_contact_id
			scene_data["_editor_file"] = chosen_file
			scenes[scene_id] = scene_data

	return scenes


func _choose_dialogue_files(all_files: Array[String], locale: String) -> Dictionary:
	var chosen: Dictionary = {}
	for file_name: String in all_files:
		var base: String = file_name.get_basename()
		var parts: PackedStringArray = base.split(".")
		if parts.size() == 2:
			if parts[1] == locale:
				chosen[parts[0]] = file_name
		elif parts.size() == 1 and not chosen.has(base):
			chosen[base] = file_name
	return chosen


func _read_locale() -> String:
	if locale_override != "":
		return locale_override
	var settings := _read_json(settings_path)
	return settings.get("language", "fr")


func _read_json(path: String) -> Dictionary:
	var result := SafeFile.read_json(path)
	return result.get("data", {}) if result.get("ok", false) else {}
