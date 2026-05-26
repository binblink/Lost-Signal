extends Control

signal choice_made

const BubbleIn = preload("res://scenes/MessageBubbleIn.tscn")
const BubbleOut = preload("res://scenes/MessageBubbleOut.tscn")
const TypingIndicator = preload("res://scenes/TypingIndicator.tscn")

@onready var messages_list = $VBoxContainer/Messages/MessagesList
@onready var input_bar = $VBoxContainer/InputBar
@onready var line_edit = $VBoxContainer/InputBar/MarginContainer/HBoxContainer/TextInput
@onready var choices_layer = $ChoicesLayer
@onready var confirm_dialog = $ConfirmDialog
@onready var overlay = $Overlay
@onready var new_game_button = $VBoxContainer/TopBar/MarginContainer/HBoxContainer/Button
@onready var btn_annuler = $ConfirmDialog/MarginContainer/VBoxContainer/HBoxContainer/Annuler
@onready var btn_recommencer = $ConfirmDialog/MarginContainer/VBoxContainer/HBoxContainer/Recommencer

var choice_buttons: Array = []
var _choices_spacer: Control = null
var typing_speed: float = 0.05
var current_scene: Dictionary = {}
var flags: Dictionary = {}
var is_restarting: bool = false
var current_message_index: int = 0
var waiting_for_choice: bool = false

func _ready() -> void:
	choices_layer.visible = false
	var buttons = choices_layer.get_child(0).get_child(0).get_children()
	for i in range(buttons.size()):
		choice_buttons.append(buttons[i])
		buttons[i].pressed.connect(_on_choice_pressed.bind(i))
	confirm_dialog.visible = false
	overlay.visible = false
	new_game_button.pressed.connect(_on_new_game_pressed)
	btn_annuler.pressed.connect(_on_annuler_pressed)
	btn_recommencer.pressed.connect(_on_recommencer_pressed)
	choices_layer.gui_input.connect(_on_choices_layer_gui_input)
	if SaveManager.has_save():
		await load_game()
	else:
		await play_scene("scene_01")

func play_scene(scene_id: String) -> void:
	if not DialogueLoader.has_scene(scene_id):
		return
	current_scene = DialogueLoader.get_scene(scene_id)
	for i in range(current_message_index, current_scene["messages_in"].size()):
		if is_restarting:
			return
		var msg = current_scene["messages_in"][i]
		var requires = msg.get("requires_flag", null)
		if requires == null or flags.get(requires, false):
			var pause = msg.get("pause", null)
			if pause != null:
				await do_pause(pause)
				if is_restarting:
					return
			var typing_ok = await show_typing(msg["text"])
			if not typing_ok:
				return
			var bubble = receive_message(msg["text"], msg["time"])
			var edit = msg.get("edit", null)
			if edit != null:
				await get_tree().create_timer(edit.get("delay", 1.5)).timeout
				if is_restarting:
					return
				if is_instance_valid(bubble):
					if edit["type"] == "delete":
						bubble.queue_free()
					elif edit["type"] == "correct":
						bubble.get_node("HBoxContainer/Bubble/MarginContainer/VBoxContainer/Message").text = edit["corrected_text"]
			else:
				await get_tree().create_timer(0.5).timeout
				if is_restarting:
					return

		current_message_index = i + 1
		save_game()

	waiting_for_choice = true
	save_game()

	if current_scene.has("choices"):
		await show_choices(
			current_scene["choices"].map(func(c): return c["text"])
		)
		if is_restarting:
			return
		await choice_made

func _on_choice_pressed(index: int) -> void:
	for btn in choice_buttons:
		btn.visible = true
	if _choices_spacer:
		_choices_spacer.queue_free()
		_choices_spacer = null
	if not current_scene.has("choices"):
		return
	var choice = current_scene["choices"][index]
	waiting_for_choice = false
	current_message_index = 0
	if choice.has("flag") and choice["flag"] != null:
		flags[choice["flag"]] = true
	var text = choice["text"]
	choices_layer.visible = false
	input_bar.visible = true

	await type_message(text)

	var next_scene_id = choice.get("next", null)
	if next_scene_id != null and DialogueLoader.has_scene(next_scene_id):
		current_scene = DialogueLoader.get_scene(next_scene_id)

	save_game()

	choice_made.emit()

	if next_scene_id != null:
		await play_scene(next_scene_id)

func receive_message(text: String, time: String) -> MarginContainer:
	var bubble = BubbleIn.instantiate()
	messages_list.add_child(bubble)
	bubble.get_node("HBoxContainer/Bubble/MarginContainer/VBoxContainer/Message").text = text
	bubble.get_node("HBoxContainer/Bubble/MarginContainer/VBoxContainer/TimeAndStatus").text = get_current_time()
	scroll_to_bottom()
	return bubble

func show_choices(options: Array) -> void:
	for i in range(choice_buttons.size()):
		if i < options.size():
			choice_buttons[i].text = options[i]
			choice_buttons[i].visible = true
		else:
			choice_buttons[i].visible = false
	choices_layer.visible = true
	input_bar.visible = false
	await get_tree().process_frame
	await get_tree().process_frame
	var buttons_container = choices_layer.get_child(0).get_child(0)
	_choices_spacer = Control.new()
	_choices_spacer.custom_minimum_size.y = buttons_container.size.y
	messages_list.add_child(_choices_spacer)
	scroll_to_bottom()

func type_message(text: String) -> void:
	line_edit.text = ""
	for i in range(text.length()):
		line_edit.text = text.substr(0, i + 1)
		var delay = typing_speed
		if i > 0 and (text[i - 1] == "." or text[i - 1] == "!" or text[i - 1] == "?" or text[i - 1] == ","):
			delay += randf_range(0.1, 0.3)
		else:
			delay += randf_range(-0.02, 0.03)
		await get_tree().create_timer(max(delay, 0.02)).timeout
	await get_tree().create_timer(randf_range(0.2, 0.5)).timeout
	send_message(text)

func send_message(text: String) -> void:
	var bubble = BubbleOut.instantiate()
	messages_list.add_child(bubble)
	bubble.get_node("HBoxContainer/Bubble/MarginContainer/VBoxContainer/Message").text = text
	bubble.get_node("HBoxContainer/Bubble/MarginContainer/VBoxContainer/TimeAndStatus").text = get_current_time()
	line_edit.text = ""
	scroll_to_bottom()

func scroll_to_bottom() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var scrollbar = $VBoxContainer/Messages.get_v_scroll_bar()
	$VBoxContainer/Messages.scroll_vertical = scrollbar.max_value

func show_typing(text: String) -> bool:
	var indicator = TypingIndicator.instantiate()
	messages_list.add_child(indicator)
	scroll_to_bottom()
	var base_duration = text.length() * 0.08
	for c in text:
		if c == "." or c == "!" or c == "?":
			base_duration += 0.3
		elif c == ",":
			base_duration += 0.15
	var variation = randf_range(0.8, 1.2)
	var duration = clamp(base_duration * variation, 1.5, 6.0)
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(indicator):
		indicator.queue_free()
	return not is_restarting

func get_current_time() -> String:
	var time = Time.get_time_dict_from_system()
	return "%02d:%02d" % [time["hour"], time["minute"]]

func _on_choices_layer_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			$VBoxContainer/Messages.scroll_vertical -= 60
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			$VBoxContainer/Messages.scroll_vertical += 60

# ---------------------------------------------------------------------------
# Save / Load — délèguent à SaveManager
# ---------------------------------------------------------------------------

func _collect_messages_data() -> Array:
	var messages_data = []
	for child in messages_list.get_children():
		if child is MarginContainer:
			var hbox = child.get_node("HBoxContainer")
			var spacer_index = -1
			for i in range(hbox.get_child_count()):
				if hbox.get_child(i) is Control and not hbox.get_child(i) is PanelContainer:
					spacer_index = i
			var bubble_out = spacer_index == 0
			var text = child.get_node(
				"HBoxContainer/Bubble/MarginContainer/VBoxContainer/Message"
			).text
			var time = child.get_node(
				"HBoxContainer/Bubble/MarginContainer/VBoxContainer/TimeAndStatus"
			).text
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

	for child in messages_list.get_children():
		child.queue_free()
	await get_tree().process_frame

	for msg in data.get("messages", []):
		if msg["out"]:
			var bubble = BubbleOut.instantiate()
			messages_list.add_child(bubble)
			bubble.get_node("HBoxContainer/Bubble/MarginContainer/VBoxContainer/Message").text = msg["text"]
			bubble.get_node("HBoxContainer/Bubble/MarginContainer/VBoxContainer/TimeAndStatus").text = msg["time"]
		else:
			var bubble = BubbleIn.instantiate()
			messages_list.add_child(bubble)
			bubble.get_node("HBoxContainer/Bubble/MarginContainer/VBoxContainer/Message").text = msg["text"]
			bubble.get_node("HBoxContainer/Bubble/MarginContainer/VBoxContainer/TimeAndStatus").text = msg["time"]
	await scroll_to_bottom()

	var scene_id = data.get("current_scene_id", "")
	if scene_id == "" or not DialogueLoader.has_scene(scene_id):
		return
	current_scene = DialogueLoader.get_scene(scene_id)

	if waiting_for_choice:
		if current_scene.has("choices"):
			await show_choices(
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
	is_restarting = true
	confirm_dialog.visible = false
	overlay.visible = false

	SaveManager.delete_save()

	for child in messages_list.get_children():
		child.queue_free()

	flags = {}
	current_scene = {}
	current_message_index = 0
	waiting_for_choice = false
	choices_layer.visible = false
	input_bar.visible = true
	await get_tree().process_frame
	is_restarting = false

	await play_scene("scene_01")

func do_pause(type: String) -> void:
	var duration: float
	match type:
		"short":
			duration = randf_range(1.0, 4.0)
		"medium":
			duration = randf_range(5.0, 15.0)
		"long":
			duration = randf_range(15.0, 40.0)
		_:
			duration = 0.5
	await get_tree().create_timer(duration).timeout
