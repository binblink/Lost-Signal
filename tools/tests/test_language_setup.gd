extends Node

const StorySettingsPanel = preload("res://addons/story_editor/StorySettingsPanel.gd")
const SafeFile = preload("res://scripts/lib/safe_file.gd")
const Assert = preload("res://tools/tests/test_assertions.gd")


func run_tests() -> Array:
	var results: Array = []
	var panel = StorySettingsPanel.new()

	Assert.equal(results, "language setup: regional locale is normalized", panel._normalize_language_locale("pt-br"), "pt_BR")
	Assert.check(results, "language setup: normalized regional locale is valid", panel._is_valid_language_locale("pt_BR"))
	Assert.check(results, "language setup: malformed locale is rejected", not panel._is_valid_language_locale("../fr"))
	Assert.equal(results, "language setup: overlong locale structure is rejected during normalization", panel._normalize_language_locale("zh_Hant_TW"), "")

	var rows: Array[PackedStringArray] = [
		PackedStringArray(["keys", "en", "fr"]),
		PackedStringArray(["HELLO", "Hello", "Bonjour"]),
		PackedStringArray(["EMPTY", "Value", ""]),
	]
	var csv_plan: Dictionary = panel._extend_language_csv_rows(rows, "es", "fr")
	Assert.check(results, "language setup: CSV extension succeeds", csv_plan.get("ok", false))
	var extended_rows: Array[PackedStringArray] = csv_plan.get("rows", [])
	Assert.equal(results, "language setup: UI text is copied from selected source", extended_rows[1][3], "Bonjour")
	Assert.equal(results, "language setup: missing source UI text is counted", csv_plan.get("missing_source_count", 0), 1)

	var file_plan: Dictionary = panel._build_dialogue_copy_plan(
		["act1.json", "act1.en.json", "act2.fr.json", "act2.es.json"],
		"es",
		"fr"
	)
	Assert.equal(results, "language setup: base dialogue is used as source fallback", file_plan["copies"], [
		{"source": "act1.json", "target": "act1.es.json"},
	])
	Assert.equal(results, "language setup: existing localized dialogue is preserved", file_plan["existing"], ["act2.es.json"])

	var story_plan: Dictionary = panel._copy_story_locale_fields({
		"contacts": [
			{
				"names": {"fr": "Maman", "en": "Mom"},
				"history": [{"text": {"fr": "Bonjour", "en": "Hello"}}],
			},
		],
		"end_screen": {"title": {"fr": "Fin", "en": "End"}},
	}, "es", "fr")
	Assert.equal(results, "language setup: localized story fields are counted", story_plan["copy_count"], 3)
	Assert.equal(results, "language setup: contact names are prepared", story_plan["data"]["contacts"][0]["names"]["es"], "Maman")
	Assert.equal(results, "language setup: contact history is prepared", story_plan["data"]["contacts"][0]["history"][0]["text"]["es"], "Bonjour")
	Assert.equal(results, "language setup: end screen is prepared", story_plan["data"]["end_screen"]["title"]["es"], "Fin")
	Assert.equal(results, "language removal: only exact locale dialogue files match", panel._find_locale_dialogue_files(
		["act1.es.json", "act1.json", "act1.es_MX.json", "act2.en.json"], "es"), ["act1.es.json"])
	var removal_story: Dictionary = panel._remove_story_locale_fields(story_plan["data"], "es")
	Assert.equal(results, "language removal: localized story values are counted", removal_story["removal_count"], 3)
	Assert.check(results, "language removal: contact locale is removed", not removal_story["data"]["contacts"][0]["names"].has("es"))
	Assert.check(results, "language removal: source contact locale is preserved", removal_story["data"]["contacts"][0]["names"].has("fr"))

	_run_isolated_write_test(panel, results)
	panel.free()
	return results


func _run_isolated_write_test(panel, results: Array) -> void:
	var token := str(Time.get_ticks_usec())
	var root := "user://language-setup-test-" + token
	var dialogues := root.path_join("dialogues")
	var translations := root.path_join("translations")
	var csv_path := root.path_join("ui.csv")
	var story_path := root.path_join("story.json")
	var chapter_one := dialogues.path_join("chapter1.json")
	var chapter_two := dialogues.path_join("chapter2.json")
	var protected_target := dialogues.path_join("chapter1.es.json")
	var created_target := dialogues.path_join("chapter2.es.json")
	var generated_translation := translations.path_join("ui.es.translation")
	var root_absolute := ProjectSettings.globalize_path(root)
	var dialogues_absolute := ProjectSettings.globalize_path(dialogues)
	var translations_absolute := ProjectSettings.globalize_path(translations)
	Assert.equal(results, "language setup: isolated directory is created", DirAccess.make_dir_recursive_absolute(dialogues_absolute), OK)
	Assert.equal(results, "language removal: isolated translations directory is created", DirAccess.make_dir_recursive_absolute(translations_absolute), OK)

	SafeFile.write_text(csv_path, "keys,en,fr\nHELLO,Hello,Bonjour\n", SafeFile.Validation.TRANSLATION_CSV)
	SafeFile.write_json(story_path, {
		"contacts": [{
			"id": "mom",
			"names": {"fr": "Maman", "en": "Mom"},
			"history": [{"text": {"fr": "Bonjour", "en": "Hello"}, "time": "00:00"}],
		}],
		"end_screen": {"title": {"fr": "Fin", "en": "End"}},
	}, "\t", true)
	SafeFile.write_json(chapter_one, {"scenes": [{"id": "one"}]}, "\t", true)
	SafeFile.write_json(chapter_two, {"scenes": [{"id": "two"}]}, "\t", true)

	panel.language_csv_path = csv_path
	panel.language_story_path = story_path
	panel.language_dialogues_dir = dialogues
	panel.language_translations_dir = translations
	var plan: Dictionary = panel._build_language_setup_plan("es", "fr", true, true)
	Assert.check(results, "language setup: isolated project plan succeeds", plan.get("ok", false), plan.get("error", ""))
	Assert.equal(results, "language setup: plan previews both dialogue copies", (plan.get("dialogue_copies", []) as Array).size(), 2)

	# Simulate a file created by the user after the preview. Applying the plan
	# must preserve it instead of overwriting it with the copied source.
	SafeFile.write_json(protected_target, {"scenes": [], "marker": "keep"}, "\t", true)
	var applied: Dictionary = panel._apply_language_setup_plan(plan)
	Assert.check(results, "language setup: isolated project is updated", applied.get("ok", false), applied.get("error", ""))
	Assert.equal(results, "language setup: only missing dialogue files are created", applied.get("created_dialogue_files", []), ["chapter2.es.json"])

	var protected_read := SafeFile.read_json(protected_target)
	Assert.equal(results, "language setup: file appearing after preview is never overwritten", protected_read.get("data", {}).get("marker", ""), "keep")
	var created_read := SafeFile.read_json(created_target)
	Assert.equal(results, "language setup: created dialogue copies source content", created_read.get("data", {}).get("scenes", [])[0].get("id", ""), "two")
	var csv_read := SafeFile.read_csv(csv_path)
	Assert.equal(results, "language setup: locale is added to CSV after preparation", csv_read.get("rows", [])[0], PackedStringArray(["keys", "en", "fr", "es"]))
	Assert.equal(results, "language setup: new UI locale starts from source text", csv_read.get("rows", [])[1][3], "Bonjour")
	var story_read := SafeFile.read_json(story_path)
	Assert.equal(results, "language setup: story fields are safely persisted", story_read.get("data", {})["contacts"][0]["names"]["es"], "Maman")

	var duplicate_plan: Dictionary = panel._build_language_setup_plan("es", "fr", true, true)
	Assert.check(results, "language setup: an existing locale cannot be added twice", not duplicate_plan.get("ok", false))

	var default_removal: Dictionary = panel._build_language_removal_plan("fr", true)
	Assert.check(results, "language removal: default locale is protected", not default_removal.get("ok", false))
	SafeFile.write_text(generated_translation, "generated translation")
	# Create a backup companion to ensure complete removal archives recovery
	# files as well as the primary localized file.
	SafeFile.write_json(protected_target, {"scenes": [], "marker": "keep-updated"}, "\t", true)
	Assert.check(results, "language removal: localized backup exists before removal", FileAccess.file_exists(protected_target + ".bak"))
	var removal_plan: Dictionary = panel._build_language_removal_plan("es", true)
	Assert.check(results, "language removal: complete removal plan succeeds", removal_plan.get("ok", false), removal_plan.get("error", ""))
	Assert.equal(results, "language removal: complete plan lists localized dialogues and generated translation", (removal_plan.get("files_to_archive", []) as Array).size(), 3)
	Assert.equal(results, "language removal: complete plan counts story values", removal_plan.get("story_removal_count", 0), 3)
	var removed: Dictionary = panel._apply_language_removal_plan(removal_plan)
	Assert.check(results, "language removal: complete removal succeeds", removed.get("ok", false), removed.get("error", ""))
	Assert.check(results, "language removal: localized dialogue primary is inactive", not FileAccess.file_exists(protected_target))
	Assert.check(results, "language removal: localized dialogue backup is archived too", not FileAccess.file_exists(protected_target + ".bak"))
	Assert.check(results, "language removal: generated translation is inactive", not FileAccess.file_exists(generated_translation))
	Assert.check(results, "language removal: archived files remain recoverable", (removed.get("archived_files", []) as Array).size() >= 4)
	var removed_csv := SafeFile.read_csv(csv_path)
	Assert.equal(results, "language removal: locale column is removed last", removed_csv.get("rows", [])[0], PackedStringArray(["keys", "en", "fr"]))
	var removed_story := SafeFile.read_json(story_path)
	Assert.check(results, "language removal: story locale is removed", not removed_story.get("data", {})["contacts"][0]["names"].has("es"))
	Assert.equal(results, "language removal: base dialogue remains untouched", SafeFile.read_json(chapter_one).get("data", {}).get("scenes", [])[0].get("id", ""), "one")
	SafeFile.write_text(csv_path, "keys,en\nHELLO,Hello\n", SafeFile.Validation.TRANSLATION_CSV)
	var last_language_plan: Dictionary = panel._build_language_removal_plan("en", false)
	Assert.check(results, "language removal: last remaining locale is protected", not last_language_plan.get("ok", false))

	for path: String in [csv_path, story_path, chapter_one, chapter_two, protected_target, created_target]:
		SafeFile.delete_with_recovery_files(path)
	for archived_path: String in removed.get("archived_files", []):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(archived_path))
	DirAccess.remove_absolute(dialogues_absolute)
	DirAccess.remove_absolute(translations_absolute)
	DirAccess.remove_absolute(root_absolute)
