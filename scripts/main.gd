extends Control

signal choice_made

@onready var message_display = $VBoxContainer/Messages/MessagesList
@onready var input_bar = $VBoxContainer/InputBar
@onready var line_edit = $VBoxContainer/InputBar/MarginContainer/HBoxContainer/TextInput
@onready var choices_layer = $ChoicesLayer
@onready var confirm_dialog = $ConfirmDialog
@onready var overlay = $Overlay
@onready var new_game_button = $VBoxContainer/TopBar/MarginContainer/HBoxContainer/Button
@onready var btn_annuler = $ConfirmDialog/MarginContainer/VBoxContainer/HBoxContainer/Annuler
@onready var btn_recommencer = $ConfirmDialog/MarginContainer/VBoxContainer/HBoxContainer/Recommencer

var current_scene: Dictionary = {}
var flags: Dictionary = {}
var current_message_index: int = 0
var waiting_for_choice: bool = false

func _ready() -> void:
	# Câblage ChoicesManager
	choices_layer.message_display = message_display
	choices_layer.scroll_container = $VBoxContainer/Messages
	choices_layer.input_bar = input_bar
	choices_layer.choice_selected.connect(_on_choice_pressed)
	# Câblage MessageDisplay
	message_display.line_edit = line_edit
	# UI globale
	confirm_dialog.visible = false
	overlay.visible = false
	new_game_button.pressed.connect(_on_new_game_pressed)
	btn_annuler.pressed.connect(_on_annuler_pressed)
	btn_recommencer.pressed.connect(_on_recommencer_pressed)
	# Démarrage
	if SaveManager.has_save():
		await load_game()
	else:
		await play_scene("scene_01")

# ---------------------------------------------------------------------------
# Progression narrative
# ---------------------------------------------------------------------------

func play_scene(scene_id: String) -> void:
	if not DialogueLoader.has_scene(scene_id):
		return
	current_scene = DialogueLoader.get_scene(scene_id)
	for i in range(current_message_index, current_scene["messages_in"].size()):
		var msg = current_scene["messages_in"][i]
		var requires = msg.get("requires_flag", null)
		if requires == null or flags.get(requires, false):
			var pause = msg.get("pause", null)
			if pause != null:
				await do_pause(pause)
			var typing_ok = await message_display.show_typing(msg["text"])
			if not typing_ok:
				return
			var bubble = await message_display.receive_message(msg["text"], msg["time"])
			var edit = msg.get("edit", null)
			if edit != null:
				await get_tree().create_timer(edit.get("delay", 1.5)).timeout
				if is_instance_valid(bubble):
					if edit["type"] == "delete":
						bubble.queue_free()
					elif edit["type"] == "correct":
						bubble.get_node("HBoxContainer/Bubble/MarginContainer/VBoxContainer/Message").text = edit["corrected_text"]
			else:
				await get_tree().create_timer(0.5).timeout
		current_message_index = i + 1
		save_game()

	waiting_for_choice = true
	save_game()

	if current_scene.has("choices"):
		await choices_layer.show_choices(
			current_scene["choices"].map(func(c): return c["text"])
		)
		await choice_made

func _on_choice_pressed(index: int) -> void:
	if not current_scene.has("choices"):
		return
	var choice = current_scene["choices"][index]
	waiting_for_choice = false
	current_message_index = 0
	if choice.has("flag") and choice["flag"] != null:
		flags[choice["flag"]] = true
	choices_layer.hide_choices()
	input_bar.visible = true
	await message_display.type_message(choice["text"])
	var next_scene_id = choice.get("next", null)
	if next_scene_id != null and DialogueLoader.has_scene(next_scene_id):
		current_scene = DialogueLoader.get_scene(next_scene_id)
	save_game()
	choice_made.emit()
	if next_scene_id != null:
		await play_scene(next_scene_id)

func do_pause(type: String) -> void:
	var duration: float
	match type:
		"short":  duration = randf_range(1.0, 4.0)
		"medium": duration = randf_range(5.0, 15.0)
		"long":   duration = randf_range(15.0, 40.0)
		_:        duration = 0.5
	await get_tree().create_timer(duration).timeout

# ---------------------------------------------------------------------------
# Save / Load
# ---------------------------------------------------------------------------

func _collect_messages_data() -> Array:
	var messages_data = []
	for child in message_display.get_children():
		if child is MarginContainer:
			var hbox = child.get_node("HBoxContainer")
			var spacer_index = -1
			for i in range(hbox.get_child_count()):
				if hbox.get_child(i) is Control and not hbox.get_child(i) is PanelContainer:
					spacer_index = i
			var bubble_out = spacer_index == 0
			var text = child.get_node("HBoxContainer/Bubble/MarginContainer/VBoxContainer/Message").text
			var time = child.get_node("HBoxContainer/Bubble/MarginContainer/VBoxContainer/TimeAndStatus").text
			messages_data.append({"text": text, "time": time, "out": bubble_out})
	return messages_data

func save_game() -> void:
	SaveManager.save(
		_collect_messages_data(),
		current_scene.get("id", ""),
		current_message_index,
		waiting_for_choice,
		flags
	)

func load_game() -> void:
	var data = SaveManager.load_save()
	if data.is_empty():
		return
	flags = data.get("flags", {})
	current_message_index = data.get("current_message_index", 0)
	waiting_for_choice = data.get("waiting_for_choice", false)
	message_display.clear_messages()
	await get_tree().process_frame
	for msg in data.get("messages", []):
		if msg["out"]:
			await message_display.send_message(msg["text"])
		else:
			await message_display.receive_message(msg["text"], msg["time"])
	await message_display.scroll_to_bottom()
	var scene_id = data.get("current_scene_id", "")
	if scene_id == "" or not DialogueLoader.has_scene(scene_id):
		return
	current_scene = DialogueLoader.get_scene(scene_id)
	if waiting_for_choice:
		if current_scene.has("choices"):
			await choices_layer.show_choices(
				current_scene["choices"].map(func(c): return c["text"])
			)
			await choice_made
	else:
		await play_scene(scene_id)

# ---------------------------------------------------------------------------
# UI globale
# ---------------------------------------------------------------------------

func _on_new_game_pressed() -> void:
	confirm_dialog.visible = true
	overlay.visible = true

func _on_annuler_pressed() -> void:
	confirm_dialog.visible = false
	overlay.visible = false

func _on_recommencer_pressed() -> void:
	SaveManager.delete_save()
	await get_tree().process_frame
	get_tree().reload_current_scene()
