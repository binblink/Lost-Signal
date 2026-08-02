extends Node

const MessageDisplay = preload("res://scripts/ui/message_display.gd")
const ChoicesManager = preload("res://scripts/ui/choices_manager.gd")
const NarrativeController = preload("res://scripts/narrative_controller.gd")
const AudioBubble = preload("res://scripts/ui/audio_bubble.gd")
const SettingsDialogScene = preload("res://scenes/SettingsDialog.tscn")
const StoryEditorPanelScene = preload("res://addons/story_editor/StoryEditorPanel.tscn")
const Assert = preload("res://tools/tests/test_assertions.gd")


func run_tests() -> Array:
	var results: Array = []
	var scroll := ScrollContainer.new()
	var display = MessageDisplay.new()
	scroll.add_child(display)
	add_child(scroll)
	await get_tree().process_frame

	_test_message_helpers(display, results)
	await _test_settings_language_options(results)
	await _test_reformat_dialog_actions(results)
	await _test_history_rendering(display, results)
	var choices = await _test_choices(display, results)
	await _test_pending_choice_restore(choices, results)

	choices.queue_free()
	scroll.queue_free()
	await get_tree().process_frame
	return results


func _test_reformat_dialog_actions(results: Array) -> void:
	var panel := StoryEditorPanelScene.instantiate()
	add_child(panel)
	await get_tree().process_frame
	var entries: Array[Dictionary] = [
		{
			"file_name": "acte1.json",
			"selected": true,
			"fallback": false,
			"locale": "fr",
			"role": "Default language",
		},
	]
	panel._show_reformat_dialog(entries, "fr")
	await get_tree().process_frame
	var dialog: ConfirmationDialog = null
	for child: Node in panel.get_children():
		if child is ConfirmationDialog:
			dialog = child
			break
	Assert.check(results, "json reformat dialog: confirmation window is created", dialog != null)
	if dialog != null:
		var confirm_button := dialog.find_child("ConfirmReformatButton", true, false) as Button
		var cancel_button := dialog.find_child("CancelReformatButton", true, false) as Button
		Assert.check(results, "json reformat dialog: confirm action is visible", confirm_button != null and confirm_button.is_visible_in_tree())
		Assert.check(results, "json reformat dialog: cancel action is visible", cancel_button != null and cancel_button.is_visible_in_tree())
		Assert.check(results, "json reformat dialog: window width stays compact", dialog.size.x <= 560, "width was %d px" % dialog.size.x)
		Assert.check(results, "json reformat dialog: window height stays compact", dialog.size.y <= 520, "height was %d px" % dialog.size.y)
		dialog.queue_free()
	panel.queue_free()
	await get_tree().process_frame


func _test_settings_language_options(results: Array) -> void:
	var original_languages: Array[String] = SettingsManager.get_supported_languages()
	var original_language: String = SettingsManager.language
	SettingsManager.SUPPORTED_LANGUAGES = ["en", "de"]
	SettingsManager.language = "de"
	var dialog := SettingsDialogScene.instantiate()
	add_child(dialog)
	await get_tree().process_frame
	dialog.open()
	var option: OptionButton = dialog.get_node("MarginContainer/VBoxContainer/Grid/LangOption")
	Assert.equal(results, "settings dialog: language options follow discovered locales", option.item_count, 2)
	Assert.equal(results, "settings dialog: current dynamic locale is selected", option.selected, 1)
	Assert.equal(results, "settings dialog: locale code remains visible as tooltip", option.get_item_tooltip(1), "de")
	dialog.queue_free()
	SettingsManager.SUPPORTED_LANGUAGES = original_languages
	SettingsManager.language = original_language
	await get_tree().process_frame


func _test_message_helpers(display, results: Array) -> void:
	Assert.equal(results, "messages: emoticons are expanded in display text", display._apply_emoticons("Hello :) (fire)"), "Hello 😊 🔥")
	Assert.equal(results, "messages: malformed timestamp is preserved", display._format_time_display("10:30"), "10:30")
	var today := Time.get_date_dict_from_system()
	var today_timestamp := "%04d-%02d-%02d 08:30" % [today["year"], today["month"], today["day"]]
	Assert.equal(results, "messages: today's timestamp only displays the time", display._format_time_display(today_timestamp), "08:30")

	var original_locale := TranslationServer.get_locale()
	TranslationServer.set_locale("fr")
	Assert.equal(results, "messages: old timestamp is localized in French", display._format_time_display("2000-01-02 03:04"), "02-01-2000 03:04")
	TranslationServer.set_locale("en")
	Assert.equal(results, "messages: old timestamp keeps ISO order outside French", display._format_time_display("2000-01-02 03:04"), "2000-01-02 03:04")
	TranslationServer.set_locale(original_locale)

	var audio_bubble = AudioBubble.new()
	Assert.equal(results, "audio bubble: duration is formatted as minutes and seconds", audio_bubble._format_duration(65.9), "1:05")
	audio_bubble.free()


func _test_history_rendering(display, results: Array) -> void:
	var line_edit := LineEdit.new()
	display.line_edit = line_edit
	line_edit.text = "stale input"
	var history: Array = [
		{"text": "Hello :) ", "time": "2000-01-02 03:04", "out": false},
		{"text": "Reply", "time": "2000-01-02 03:05", "out": true},
		{"text": null, "time": "2000-01-02 03:06", "out": false, "corrupted": true},
		{"text": null, "time": "2000-01-02 03:07", "out": false, "media": {"type": "image", "path": "res://assets/images/maeve_pic_1.jpg"}},
		{"text": null, "time": "2000-01-02 03:08", "out": false, "media": {"type": "audio", "path": "res://assets/sounds/Splorch.mp3"}}
	]
	var history_start_frame := Engine.get_process_frames()
	await display.render_history(history)
	var history_render_frames := Engine.get_process_frames() - history_start_frame
	Assert.equal(results, "messages: text, outgoing, corrupted, image and audio history render", display.get_child_count(), 5)
	Assert.check(results, "messages: history uses one batched final scroll", history_render_frames <= 3, "render took %d process frames" % history_render_frames)
	Assert.equal(results, "messages: history is visible after batched render", display.modulate.a, 1.0)
	Assert.equal(results, "messages: rendered history round trips without data loss", display.collect_messages_data(), history)
	Assert.equal(results, "messages: rendering an outgoing message clears stale input", line_edit.text, "")
	var incoming_label: Label = display.get_child(0).get_node("HBoxContainer/Bubble/MarginContainer/VBoxContainer/Message")
	Assert.equal(results, "messages: emoticons are expanded visually but raw history is retained", incoming_label.text, "Hello 😊 ")
	Assert.check(results, "messages: corrupted bubble retains its marker", display.get_child(2).get_meta("msg_data").get("corrupted", false))
	Assert.equal(results, "messages: image bubble retains media type", display.get_child(3).get_meta("msg_data").get("media", {}).get("type"), "image")
	Assert.equal(results, "messages: audio bubble retains media type", display.get_child(4).get_meta("msg_data").get("media", {}).get("type"), "audio")
	var live_start_frame := Engine.get_process_frames()
	await display.receive_message("Live message", "10:00")
	var live_render_frames := Engine.get_process_frames() - live_start_frame
	Assert.check(results, "messages: live messages keep automatic scrolling", live_render_frames >= 2)

	display.clear_messages()
	await get_tree().process_frame
	Assert.equal(results, "messages: clear removes every rendered bubble", display.get_child_count(), 0)
	display.line_edit = null
	line_edit.free()


func _test_choices(display, results: Array):
	var layer = ChoicesManager.new()
	var panel := MarginContainer.new()
	var buttons := VBoxContainer.new()
	panel.add_child(buttons)
	layer.add_child(panel)
	for index in range(4):
		var button := Button.new()
		button.name = "Choice%d" % index
		buttons.add_child(button)
	var input_bar := Control.new()
	layer.add_child(input_bar)
	layer.buttons_container = buttons
	layer.message_display = display
	layer.input_bar = input_bar
	add_child(layer)
	await get_tree().process_frame

	await layer.show_choices(["One", "Two", "Three", "Four", "Ignored"])
	Assert.equal(results, "choices: exactly four buttons are available", layer._choice_buttons.size(), 4)
	Assert.equal(results, "choices: first four options are displayed", layer._choice_buttons.map(func(button): return button.text), ["One", "Two", "Three", "Four"])
	Assert.check(results, "choices: options beyond the fourth are not rendered", layer._choice_buttons.all(func(button): return button.text != "Ignored"))
	Assert.check(results, "choices: input bar is hidden while choosing", not input_bar.visible)
	Assert.check(results, "choices: scroll spacer is added while options are visible", is_instance_valid(layer._spacer))

	var selected: Array = []
	layer.choice_selected.connect(func(index: int) -> void: selected.append(index))
	layer._on_button_pressed(2)
	Assert.equal(results, "choices: pressed button emits its stable index", selected, [2])

	layer.hide_choices()
	await get_tree().process_frame
	await layer.show_choices(["Only", "Second"])
	Assert.check(results, "choices: unused buttons are hidden", layer._choice_buttons[0].visible and layer._choice_buttons[1].visible and not layer._choice_buttons[2].visible and not layer._choice_buttons[3].visible)
	layer.hide_choices()
	await get_tree().process_frame
	return layer


func _test_pending_choice_restore(choices, results: Array) -> void:
	var loader: Node = get_tree().root.get_node("DialogueLoader")
	var original_scenes: Dictionary = loader.get("_scenes")
	var original_contacts: Array = loader.get("_contacts")
	loader.set("_scenes", {
		"pending": {
			"id": "pending",
			"contact_id": "mom",
			"messages_in": [],
			"choices": [
				{"text": "Visible", "requires_flag": "show"},
				{"text": "Always"},
				{"text": "Hidden", "requires_flag": "missing"}
			]
		},
		"all_hidden": {
			"id": "all_hidden",
			"contact_id": "mom",
			"messages_in": [],
			"choices": [{"text": "Hidden", "requires_flag": "missing"}]
		}
	})
	loader.set("_contacts", [{"id": "main", "is_main": true}, {"id": "mom"}])

	var nc = NarrativeController.new()
	add_child(nc)
	nc.flags = {"show": true}
	nc.active_contact_id = "mom"
	nc.pending_choices = {"mom": "pending"}
	nc.choices_layer = choices
	await nc.restore_pending_choice_for("mom")
	Assert.check(results, "pending choices: restore returns controller to waiting state", nc.waiting_for_choice)
	Assert.equal(results, "pending choices: restore selects saved scene", nc.current_scene.get("id"), "pending")
	Assert.equal(results, "pending choices: conditions are reapplied on restore", nc._visible_choices.map(func(choice): return choice["text"]), ["Visible", "Always"])
	Assert.equal(results, "pending choices: filtered options are rendered", [choices._choice_buttons[0].text, choices._choice_buttons[1].text], ["Visible", "Always"])

	choices.hide_choices()
	await get_tree().process_frame
	nc.pending_choices = {"mom": "all_hidden"}
	await nc.restore_pending_choice_for("mom")
	Assert.check(results, "pending choices: entry with no visible option is cleared", not nc.pending_choices.has("mom"))
	Assert.check(results, "pending choices: layer remains hidden when nothing is selectable", not choices.visible)

	nc.pending_choices = {"mom": "missing"}
	await nc.restore_pending_choice_for("mom")
	Assert.check(results, "pending choices: missing saved scene is cleared safely", not nc.pending_choices.has("mom"))

	nc.queue_free()
	loader.set("_scenes", original_scenes)
	loader.set("_contacts", original_contacts)
