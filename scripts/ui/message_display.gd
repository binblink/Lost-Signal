extends VBoxContainer

const BubbleIn = preload("res://scenes/MessageBubbleIn.tscn")
const BubbleOut = preload("res://scenes/MessageBubbleOut.tscn")
const TypingIndicator = preload("res://scenes/TypingIndicator.tscn")

# Référence passée par main.gd au _ready
var line_edit: LineEdit = null

var typing_speed: float = 0.05

func receive_message(text: String, _time: String) -> MarginContainer:
	var bubble = BubbleIn.instantiate()
	add_child(bubble)
	bubble.get_node("HBoxContainer/Bubble/MarginContainer/VBoxContainer/Message").text = text
	bubble.get_node("HBoxContainer/Bubble/MarginContainer/VBoxContainer/TimeAndStatus").text = get_current_time()
	await scroll_to_bottom()
	return bubble

func send_message(text: String) -> void:
	var bubble = BubbleOut.instantiate()
	add_child(bubble)
	bubble.get_node("HBoxContainer/Bubble/MarginContainer/VBoxContainer/Message").text = text
	bubble.get_node("HBoxContainer/Bubble/MarginContainer/VBoxContainer/TimeAndStatus").text = get_current_time()
	if line_edit:
		line_edit.text = ""
	await scroll_to_bottom()

func show_typing(text: String) -> bool:
	var indicator = TypingIndicator.instantiate()
	add_child(indicator)
	await scroll_to_bottom()
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
	# Retourne false si la scène a été rechargée entre temps
	return is_instance_valid(self)

func type_message(text: String) -> void:
	if line_edit:
		line_edit.text = ""
	for i in range(text.length()):
		if line_edit:
			line_edit.text = text.substr(0, i + 1)
		var delay = typing_speed
		if i > 0 and (text[i - 1] == "." or text[i - 1] == "!" or text[i - 1] == "?" or text[i - 1] == ","):
			delay += randf_range(0.1, 0.3)
		else:
			delay += randf_range(-0.02, 0.03)
		await get_tree().create_timer(max(delay, 0.02)).timeout
	await get_tree().create_timer(randf_range(0.2, 0.5)).timeout
	await send_message(text)

func scroll_to_bottom() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var scroll = get_parent() as ScrollContainer
	if scroll:
		scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value

func get_current_time() -> String:
	var time = Time.get_time_dict_from_system()
	return "%02d:%02d" % [time["hour"], time["minute"]]

func clear_messages() -> void:
	for child in get_children():
		child.queue_free()
