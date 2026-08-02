extends Node

const SceneParser = preload("res://addons/story_editor/scene_parser.gd")
const Assert = preload("res://tools/tests/test_assertions.gd")
const SafeFile = preload("res://scripts/lib/safe_file.gd")

var _test_root: String
var _dialogues_dir: String
var _story_path: String
var _settings_path: String


func run_tests() -> Array:
	var results: Array = []
	_test_root = "user://scene-parser-test-%d" % Time.get_ticks_usec()
	_dialogues_dir = _test_root.path_join("dialogues")
	_story_path = _test_root.path_join("story.json")
	_settings_path = _test_root.path_join("settings.json")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dialogues_dir))

	_write_json(_story_path, {
		"start_scene": "localized",
		"settings": {"default_language": "es"},
		"contacts": [{"id": "main", "is_main": true}, {"id": "other"}]
	})
	_write_json(_dialogues_dir.path_join("acte1.json"), {
		"scenes": [{"id": "base", "messages_in": []}]
	})
	_write_json(_dialogues_dir.path_join("acte1.en.json"), {
		"scenes": [{"id": "localized", "messages_in": []}]
	})
	_write_json(_dialogues_dir.path_join("acte1.fr.json"), {
		"scenes": [{"id": "french", "messages_in": []}]
	})
	_write_json(_dialogues_dir.path_join("acte2.json"), {
		"scenes": [{"id": "fallback", "contact_id": "other", "messages_in": []}]
	})

	var locales: Array[String] = SceneParser.detect_locales(_dialogues_dir, _story_path)
	Assert.equal(results, "scene parser: locales include base language and translations", locales, ["es", "en", "fr"])

	var parser = _new_parser()
	parser.locale_override = "en"
	var scenes: Dictionary = parser.parse_all()
	Assert.equal(results, "scene parser: story start scene loaded", parser.start_scene, "localized")
	Assert.equal(results, "scene parser: contacts loaded", parser.contacts.size(), 2)
	Assert.equal(results, "scene parser: localized file preferred with base fallback", parser.chosen_files, {"acte1": "acte1.en.json", "acte2": "acte2.json"})
	Assert.check(results, "scene parser: selected localized and fallback scenes", scenes.has("localized") and scenes.has("fallback"))
	Assert.check(results, "scene parser: unselected locale and base are excluded", not scenes.has("base") and not scenes.has("french"))
	Assert.equal(results, "scene parser: missing contact defaults to main contact", scenes["localized"].get("contact_id"), "main")
	Assert.equal(results, "scene parser: source file metadata is attached", scenes["localized"].get("_editor_file"), "acte1.en.json")
	Assert.equal(results, "scene parser: explicit contact is preserved", scenes["fallback"].get("contact_id"), "other")
	Assert.equal(results, "scene parser: valid parse reports no error", parser.error_message, "")

	_write_json(_settings_path, {"language": "fr"})
	parser.locale_override = ""
	Assert.equal(results, "scene parser: locale read from injected settings", parser._read_locale(), "fr")
	var unordered_files: Array[String] = ["acte1.en.json", "acte1.json", "acte2.json"]
	Assert.equal(results, "scene parser: file selection is order independent", parser._choose_dialogue_files(unordered_files, "en"), {"acte1": "acte1.en.json", "acte2": "acte2.json"})

	SafeFile.write_json(_settings_path, {"language": "en"})
	_write_text(_settings_path, "{broken")
	Assert.equal(results, "scene parser recovery: corrupt settings restores backup", parser._read_locale(), "fr")
	Assert.check(results, "scene parser recovery: primary settings file is repaired", SafeFile.read_json(_settings_path).get("ok", false))

	var invalid_story = _new_parser()
	invalid_story.story_path = _test_root.path_join("missing.json")
	Assert.equal(results, "scene parser: missing story returns no scenes", invalid_story.parse_all(), {})
	Assert.check(results, "scene parser: missing story reports an error", not invalid_story.error_message.is_empty())

	_write_text(_dialogues_dir.path_join("acte1.en.json"), "{broken")
	var invalid_dialogue = _new_parser()
	invalid_dialogue.locale_override = "en"
	Assert.equal(results, "scene parser: invalid selected dialogue returns no partial scenes", invalid_dialogue.parse_all(), {})
	Assert.check(results, "scene parser: invalid dialogue names the source file", "acte1.en.json" in invalid_dialogue.error_message)

	_write_json(_dialogues_dir.path_join("acte1.en.json"), {
		"scenes": [{"id": "duplicate", "messages_in": [], "marker": "first"}]
	})
	_write_json(_dialogues_dir.path_join("acte2.json"), {
		"scenes": [{"id": "duplicate", "messages_in": [], "marker": "second"}]
	})
	var duplicate = _new_parser()
	duplicate.locale_override = "en"
	var duplicate_scenes: Dictionary = duplicate.parse_all()
	Assert.check(results, "scene parser: duplicate scene id is reported", "duplicate" in duplicate.error_message)
	Assert.equal(results, "scene parser: duplicate keeps first occurrence", duplicate_scenes["duplicate"].get("marker"), "first")

	_write_text(_test_root.path_join("array.json"), "[]")
	Assert.equal(results, "scene parser: non-object JSON root is rejected", parser._read_json(_test_root.path_join("array.json")), {})

	_remove_tree(_test_root)
	return results


func _new_parser():
	var parser = SceneParser.new()
	parser.story_path = _story_path
	parser.dialogues_dir = _dialogues_dir
	parser.settings_path = _settings_path
	return parser


func _write_json(path: String, value: Variant) -> void:
	_write_text(path, JSON.stringify(value))


func _write_text(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null, "Unable to create test fixture: " + path)
	file.store_string(value)
	file.close()


func _remove_tree(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var child := path.path_join(entry)
		if dir.current_is_dir():
			_remove_tree(child)
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(child))
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(absolute)
