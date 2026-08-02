extends Node

const JsonUtils = preload("res://addons/story_editor/json_utils.gd")
const Assert = preload("res://tools/tests/test_assertions.gd")


func run_tests() -> Array:
	var results: Array = []
	Assert.equal(results, "json compact: empty dictionary", JsonUtils.compact({}), "{}")
	Assert.equal(results, "json compact: empty array", JsonUtils.compact([]), "[]")
	Assert.equal(results, "json compact: nested values", JsonUtils.compact({"name": "Maeve", "flags": [true, false]}), "{\"name\": \"Maeve\", \"flags\": [true, false]}")
	Assert.equal(results, "json compact: strings are escaped", JsonUtils.compact("a\nb\"c"), "\"a\\nb\\\"c\"")

	var expanded_source: Dictionary = {"scenes": [{"id": "one", "meta": {"deep": [true, false]}}]}
	var expanded: String = JsonUtils.expand(expanded_source, "")
	Assert.check(results, "json expand: top level is multiline", "{\n\t\"scenes\"" in expanded)
	Assert.check(results, "json expand: deeply nested arrays stay multiline", "\t\t\t\t\"deep\": [\n\t\t\t\t\ttrue,\n\t\t\t\t\tfalse\n\t\t\t\t]" in expanded)
	Assert.equal(results, "json expand: generated text remains valid JSON", JSON.parse_string(expanded), expanded_source)

	var narrative_source: Dictionary = {
		"scenes": [{
			"id": "scene_test",
			"messages_in": [{"text": ["First", "Second"], "requires_flag": "seen"}],
			"choices": [{"text": "Answer", "message": ["One", "Two"], "next": "scene_next"}],
		}]
	}
	var narrative_expanded := JsonUtils.expand(narrative_source, "")
	Assert.check(results, "json expand: message objects stay multiline", "\t\t\t\t{\n\t\t\t\t\t\"text\": [" in narrative_expanded)
	Assert.check(results, "json expand: every incoming text has its own line", "\t\t\t\t\t\t\"First\",\n\t\t\t\t\t\t\"Second\"" in narrative_expanded)
	Assert.check(results, "json expand: every choice message has its own line", "\t\t\t\t\t\t\"One\",\n\t\t\t\t\t\t\"Two\"" in narrative_expanded)

	var scene: Dictionary = {
		"custom": "kept",
		"choices": [{"effects": [], "next": "two", "text": "Go", "custom_choice": 1}],
		"_editor_file": "acte1.json",
		"messages_in": [{"time": "10:00", "pause": "short", "text": "Hello", "custom_message": true}],
		"contact_id": "maeve",
		"id": "one",
		"_notes": "note"
	}
	var ordered: Dictionary = JsonUtils.ordered_scene(scene)
	Assert.equal(results, "json order: scene keys are canonical", ordered.keys(), ["_notes", "id", "contact_id", "messages_in", "choices", "custom"])
	Assert.check(results, "json order: editor-only key is stripped", not ordered.has("_editor_file"))
	Assert.equal(results, "json order: unknown scene key is preserved", ordered.get("custom"), "kept")
	Assert.equal(results, "json order: message keys are canonical", (ordered["messages_in"][0] as Dictionary).keys(), ["text", "pause", "time", "custom_message"])
	Assert.equal(results, "json order: choice keys are canonical", (ordered["choices"][0] as Dictionary).keys(), ["text", "next", "effects", "custom_choice"])
	Assert.check(results, "json order: source scene is not stripped in place", scene.has("_editor_file"))

	var message: Dictionary = JsonUtils.ordered_message({"condition": {}, "media": {}, "text": "x", "extra": 2})
	Assert.equal(results, "json order: standalone message", message.keys(), ["text", "media", "condition", "extra"])
	var choice: Dictionary = JsonUtils.ordered_choice({"effects": [], "flag": "f", "text": "x", "message": "y", "extra": 2})
	Assert.equal(results, "json order: standalone choice", choice.keys(), ["text", "message", "flag", "effects", "extra"])
	return results
