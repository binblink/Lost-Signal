extends Node

const DialogueLoaderScript = preload("res://scripts/autoloads/dialogue_loader.gd")
const Assert = preload("res://tools/tests/test_assertions.gd")


func run_tests() -> Array:
	var results: Array = []
	_test_message_normalization(results)
	_test_locale_selection(results)
	_test_validation_helpers(results)
	_test_full_validation(results)
	_test_json_loading_and_duplicates(results)
	return results


func _test_message_normalization(results: Array) -> void:
	var loader = DialogueLoaderScript.new()
	Assert.equal(results, "dialogue normalization: string becomes text message", loader._normalize_message("hello"), [{"text": "hello"}])
	Assert.equal(results, "dialogue normalization: unsupported value is discarded", loader._normalize_message(42), [])
	var condition: Dictionary = {"flag": "ready"}
	var effects: Array = [{"op": "set", "var": "score", "value": 1}]
	var normalized: Array = loader._normalize_message({
		"text": ["first", {"text": "second", "pause": "long"}, "last"],
		"pause": "short",
		"time": "12:00",
		"requires_flag": ["a", "b"],
		"condition": condition,
		"effects": effects,
		"edit": {"type": "delete"}
	}, false)
	Assert.equal(results, "dialogue normalization: text array expands", normalized.size(), 3)
	Assert.equal(results, "dialogue normalization: parent pause applies to first bubble", normalized[0].get("pause"), "short")
	Assert.equal(results, "dialogue normalization: nested pause overrides parent", normalized[1].get("pause"), "long")
	Assert.check(results, "dialogue normalization: intermediate bubble has no time", not normalized[1].has("time"))
	Assert.equal(results, "dialogue normalization: time applies to last bubble", normalized[2].get("time"), "12:00")
	Assert.equal(results, "dialogue normalization: effects apply to first bubble", normalized[0].get("effects"), effects)
	Assert.check(results, "dialogue normalization: effects do not repeat", not normalized[1].has("effects") and not normalized[2].has("effects"))
	Assert.equal(results, "dialogue normalization: required flags copied to every bubble", normalized[2].get("requires_flag"), ["a", "b"])
	Assert.equal(results, "dialogue normalization: condition copied to every bubble", normalized[1].get("condition"), condition)
	Assert.check(results, "dialogue normalization: unsupported multi-bubble edit is removed", not normalized[0].has("edit"))
	loader.free()


func _test_locale_selection(results: Array) -> void:
	var loader = DialogueLoaderScript.new()
	var files: Array[String] = ["acte1.json", "acte1.fr.json", "acte1.en.json", "acte2.json", "acte2.fr.json"]
	Assert.equal(results, "dialogue locale: localized file wins", loader._choose_dialogue_files(files, "en"), ["acte1.en.json", "acte2.json"])
	Assert.equal(results, "dialogue locale: base file is fallback", loader._choose_dialogue_files(files, "de"), ["acte1.json", "acte2.json"])
	var reversed: Array[String] = files.duplicate()
	reversed.reverse()
	Assert.equal(results, "dialogue locale: selection is independent of directory order", loader._choose_dialogue_files(reversed, "en"), ["acte1.en.json", "acte2.json"])
	loader.free()


func _test_validation_helpers(results: Array) -> void:
	var loader = DialogueLoaderScript.new()
	loader._scenes = {"next": {"id": "next", "messages_in": []}}
	var errors: Array = []
	var warnings: Array = []
	loader._check_message({"text": "ok", "requires_flag": ["a", "b"]}, "[scene]", 0, ["a", "b"], ["main"], errors, warnings)
	Assert.equal(results, "dialogue validation: required flag arrays are accepted", warnings, [])

	errors.clear()
	warnings.clear()
	loader._check_message({"media": {"type": "video"}, "pause": "forever"}, "[scene]", 0, [], ["main"], errors, warnings)
	Assert.check(results, "dialogue validation: invalid media type rejected", _contains(errors, "unknown media type"))
	Assert.check(results, "dialogue validation: missing media path rejected", _contains(errors, "media missing 'path'"))
	Assert.check(results, "dialogue validation: invalid pause warned", _contains(warnings, "unknown pause value"))

	errors.clear()
	warnings.clear()
	loader._check_choice({"message": 12, "next": "missing"}, "[scene]", 0, [], ["main"], errors, warnings)
	Assert.check(results, "dialogue validation: choice text is required", _contains(errors, "missing 'text'"))
	Assert.check(results, "dialogue validation: choice target must exist", _contains(errors, "next 'missing' not found"))
	Assert.check(results, "dialogue validation: choice message type checked", _contains(errors, "'message' must be"))

	errors.clear()
	warnings.clear()
	loader._check_condition({"var": "score", "op": "wat", "value": 1}, "condition", [], warnings, errors)
	loader._check_condition({}, "malformed", [], warnings, errors)
	loader._check_condition({"flag": "never"}, "flag", [], warnings, errors)
	Assert.check(results, "dialogue validation: unknown condition operator rejected", _contains(errors, "unknown condition op"))
	Assert.check(results, "dialogue validation: malformed condition rejected", _contains(errors, "malformed condition"))
	Assert.check(results, "dialogue validation: unset condition flag warned", _contains(warnings, "is never set"))

	errors.clear()
	warnings.clear()
	loader._check_effect({}, "effect", ["main"], errors, warnings)
	loader._check_effect({"op": "add", "var": "score"}, "effect", ["main"], errors, warnings)
	loader._check_effect({"op": "rename", "contact": "missing", "value": "Name"}, "effect", ["main"], errors, warnings)
	loader._check_effect({"op": "unknown"}, "effect", ["main"], errors, warnings)
	Assert.check(results, "dialogue validation: effect operation required", _contains(errors, "missing 'op'"))
	Assert.check(results, "dialogue validation: variable effect fields required", _contains(errors, "requires 'var' and 'value'"))
	Assert.check(results, "dialogue validation: effect contact must exist", _contains(errors, "contact 'missing' not found"))
	Assert.check(results, "dialogue validation: unknown effect warned", _contains(warnings, "unknown effect op"))
	loader.free()


func _test_full_validation(results: Array) -> void:
	var valid = DialogueLoaderScript.new()
	valid._contacts = [{"id": "main", "is_main": true}]
	valid._start_contact = "main"
	valid._start_scene = "start"
	valid._scenes = {"start": {"id": "start", "contact_id": "main", "messages_in": [{"text": "hello"}], "end": true}}
	valid._triggers = {}
	valid._validate(false)
	Assert.equal(results, "dialogue validation: minimal valid story has no errors", valid.validation_errors, [])
	Assert.equal(results, "dialogue validation: minimal valid story has no warnings", valid.validation_warnings, [])
	valid.free()

	var invalid = DialogueLoaderScript.new()
	invalid._contacts = [{"id": "main", "is_main": true, "pending_scene": "missing_pending"}]
	invalid._start_contact = "unknown_contact"
	invalid._start_scene = "missing_start"
	invalid._scenes = {
		"a": {"id": "a", "contact_id": "unknown_contact", "messages_in": [], "trigger_after_scene": "b", "resume_after_flag": "never"},
		"b": {"id": "b", "contact_id": "main", "messages_in": [], "trigger_after_scene": "a"}
	}
	invalid._triggers = {"a": ["b"], "b": ["a"]}
	invalid._validate(false)
	Assert.check(results, "dialogue validation: invalid start contact rejected", _contains(invalid.validation_errors, "start_contact"))
	Assert.check(results, "dialogue validation: missing pending scene rejected", _contains(invalid.validation_errors, "pending_scene"))
	Assert.check(results, "dialogue validation: missing start scene rejected", _contains(invalid.validation_errors, "start_scene"))
	Assert.check(results, "dialogue validation: unknown scene contact rejected", _contains(invalid.validation_errors, "contact_id"))
	Assert.check(results, "dialogue validation: deadlocked resume flag rejected", _contains(invalid.validation_errors, "will deadlock"))
	Assert.check(results, "dialogue validation: trigger cycle rejected", _contains(invalid.validation_errors, "Trigger cycle detected"))
	invalid.free()


func _test_json_loading_and_duplicates(results: Array) -> void:
	var loader = DialogueLoaderScript.new()
	loader._contacts = [{"id": "main", "is_main": true}]
	var unique: String = str(Time.get_ticks_usec())
	var valid_path: String = "user://dialogue-test-%s.json" % unique
	var duplicate_path: String = "user://dialogue-test-%s-duplicate.json" % unique
	var invalid_path: String = "user://dialogue-test-%s-invalid.json" % unique
	var array_path: String = "user://dialogue-test-%s-array.json" % unique
	_write_text(valid_path, JSON.stringify({"scenes": [{"id": "dup", "messages_in": ["first"]}]}))
	_write_text(duplicate_path, JSON.stringify({"scenes": [{"id": "dup", "messages_in": ["second"]}]}))
	_write_text(invalid_path, "{broken")
	_write_text(array_path, "[]")

	loader._load_scenes_from(valid_path, false)
	loader._load_scenes_from(duplicate_path, false)
	Assert.equal(results, "dialogue loading: message strings normalize while loading", loader._scenes["dup"]["messages_in"], [{"text": "first"}])
	Assert.equal(results, "dialogue loading: missing contact defaults to main", loader._scenes["dup"].get("contact_id"), "main")
	Assert.equal(results, "dialogue loading: duplicate keeps first scene", loader._scenes["dup"]["messages_in"][0].get("text"), "first")
	Assert.equal(results, "dialogue loading: duplicate is recorded as load error", loader._load_errors.size(), 1)
	Assert.equal(results, "dialogue JSON: malformed document rejected", loader._parse_json(invalid_path, false), {})
	Assert.equal(results, "dialogue JSON: non-object root rejected", loader._parse_json(array_path, false), {})
	Assert.equal(results, "dialogue JSON: missing file rejected", loader._parse_json("user://does-not-exist-%s.json" % unique, false), {})

	for path: String in [valid_path, duplicate_path, invalid_path, array_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	loader.free()


func _write_text(path: String, content: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()


func _contains(items: Array, needle: String) -> bool:
	for item: Variant in items:
		if needle in str(item):
			return true
	return false
