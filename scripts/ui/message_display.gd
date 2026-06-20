extends VBoxContainer

signal image_clicked(path: String)

const BubbleIn       = preload("res://scenes/MessageBubbleIn.tscn")
const BubbleOut      = preload("res://scenes/MessageBubbleOut.tscn")
const ImageBubbleIn  = preload("res://scenes/MessageBubbleImageIn.tscn")
const AudioBubbleIn  = preload("res://scenes/MessageBubbleAudioIn.tscn")
const TypingIndicator = preload("res://scenes/TypingIndicator.tscn")

var line_edit: LineEdit = null
var typing_speed: float = 0.05

func _ready() -> void:
	typing_speed = ThemeManager.typing_speed

func _apply_emoticons(text: String) -> String:
	return text \
		.replace(">:-(", "😠") \
		.replace(">:(", "😠") \
		.replace(":'(", "😭") \
		.replace(":'-(",  "😭") \
		.replace("O:-)", "😇") \
		.replace("O:)",  "😇") \
		.replace(">:-)", "😈") \
		.replace(">:)",  "😈") \
		.replace("B-)",  "😎") \
		.replace("B)",   "😎") \
		.replace(":-D",  "😄") \
		.replace(":D",   "😄") \
		.replace("=-D",  "😁") \
		.replace("=D",   "😁") \
		.replace(":-)",  "😊") \
		.replace(":)",   "😊") \
		.replace(":-(", "😢") \
		.replace(":(",  "😢") \
		.replace(";-)", "😉") \
		.replace(";)",  "😉") \
		.replace(":-P", "😛") \
		.replace(":P",  "😛") \
		.replace(":-p", "😛") \
		.replace(":p",  "😛") \
		.replace(":-O", "😮") \
		.replace(":O",  "😮") \
		.replace(":-o", "😮") \
		.replace(":o",  "😮") \
		.replace(":-*", "😘") \
		.replace(":*",  "😘") \
		.replace(":-/", "😕") \
		.replace(":/",  "😕") \
		.replace(":-|", "😐") \
		.replace(":|",  "😐") \
		.replace(":')", "🥲") \
		.replace("^_^", "😊") \
		.replace("^^",  "😄") \
		.replace("XD",  "😆") \
		.replace("xD",  "😆") \
		.replace(">_<", "😣") \
		.replace("-_-", "😑") \
		.replace("T_T", "😭") \
		.replace("T.T", "😭") \
		.replace("o.O", "🤨") \
		.replace("O.o", "🤨") \
		.replace("</3", "💔") \
		.replace("<3",  "❤️")

func receive_message(text: String, _time: String) -> MarginContainer:
	var bubble = BubbleIn.instantiate()
	add_child(bubble)
	var t = get_current_time()
	bubble.get_node("HBoxContainer/Bubble/MarginContainer/VBoxContainer/Message").text = _apply_emoticons(text)
	bubble.get_node("HBoxContainer/Bubble/MarginContainer/VBoxContainer/TimeAndStatus").text = t
	bubble.set_meta("msg_data", { "text": text, "time": t, "out": false })
	await scroll_to_bottom()
	return bubble

func receive_image_message(path: String, _time: String) -> MarginContainer:
	var bubble = ImageBubbleIn.instantiate()
	add_child(bubble)
	var t = get_current_time()
	var thumbnail = bubble.get_node("HBoxContainer/Bubble/MarginContainer/VBoxContainer/Thumbnail")
	bubble.get_node("HBoxContainer/Bubble/MarginContainer/VBoxContainer/TimeAndStatus").text = t
	if ResourceLoader.exists(path):
		thumbnail.texture = load(path)
		var tex_w := float(thumbnail.texture.get_width())
		var tex_h := float(thumbnail.texture.get_height())
		if tex_w > 0 and tex_h > 0:
			var img_scale := minf(240.0 / tex_w, 180.0 / tex_h)
			thumbnail.custom_minimum_size = Vector2(tex_w * img_scale, tex_h * img_scale)
	thumbnail.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			image_clicked.emit(path)
	)
	bubble.set_meta("msg_data", { "text": null, "time": t, "out": false, "media": { "type": "image", "path": path } })
	await scroll_to_bottom()
	return bubble

func receive_audio_message(path: String, _time: String) -> MarginContainer:
	var bubble = AudioBubbleIn.instantiate()
	add_child(bubble)
	var t = get_current_time()
	bubble.setup(path, t)
	bubble.set_meta("msg_data", { "text": null, "time": t, "out": false, "media": { "type": "audio", "path": path } })
	await scroll_to_bottom()
	return bubble

func send_message(text: String) -> void:
	var bubble = BubbleOut.instantiate()
	add_child(bubble)
	var t = get_current_time()
	bubble.get_node("HBoxContainer/Bubble/MarginContainer/VBoxContainer/Message").text = _apply_emoticons(text)
	bubble.get_node("HBoxContainer/Bubble/MarginContainer/VBoxContainer/TimeAndStatus").text = t
	bubble.set_meta("msg_data", { "text": text, "time": t, "out": true })
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
	return is_instance_valid(self)

func type_message(text: String) -> void:
	text = _apply_emoticons(text)
	if line_edit:
		line_edit.text = ""
	for i in range(text.length()):
		AudioManager.play_typing_click()
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

func receive_corrupted_message(time: String) -> MarginContainer:
	var bubble = BubbleIn.instantiate()
	add_child(bubble)
	var t = time if time != "" else get_current_time()
	var label = bubble.get_node("HBoxContainer/Bubble/MarginContainer/VBoxContainer/Message")
	label.text = "✗ " + tr("MSG_CORRUPTED")
	label.add_theme_color_override("font_color", Color(0.85, 0.2, 0.2))
	bubble.get_node("HBoxContainer/Bubble/MarginContainer/VBoxContainer/TimeAndStatus").text = t
	bubble.set_meta("msg_data", { "text": null, "time": t, "out": false, "corrupted": true })
	await scroll_to_bottom()
	return bubble

func scroll_to_bottom() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var scroll = get_parent() as ScrollContainer
	if scroll:
		scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value

func get_current_time() -> String:
	var time = Time.get_time_dict_from_system()
	return "%02d:%02d" % [time["hour"], time["minute"]]

func render_history(history: Array) -> void:
	for msg in history:
		if msg.get("out", false):
			await send_message(msg["text"])
		elif msg.get("corrupted", false):
			await receive_corrupted_message(msg.get("time", ""))
		elif msg.has("media"):
			match msg["media"].get("type", ""):
				"image": await receive_image_message(msg["media"]["path"], msg.get("time", ""))
				"audio": await receive_audio_message(msg["media"]["path"], msg.get("time", ""))
		else:
			await receive_message(msg["text"], msg.get("time", ""))

func clear_messages() -> void:
	for child in get_children():
		child.queue_free()

func collect_messages_data() -> Array:
	var messages_data = []
	for child in get_children():
		if not child is MarginContainer:
			continue
		if child.has_meta("msg_data"):
			messages_data.append(child.get_meta("msg_data"))
		else:
			var hbox = child.get_node_or_null("HBoxContainer")
			if hbox == null:
				continue
			var spacer_index = -1
			for i in range(hbox.get_child_count()):
				if hbox.get_child(i) is Control and not hbox.get_child(i) is PanelContainer:
					spacer_index = i
			var msg_node  = child.get_node_or_null("HBoxContainer/Bubble/MarginContainer/VBoxContainer/Message")
			var time_node = child.get_node_or_null("HBoxContainer/Bubble/MarginContainer/VBoxContainer/TimeAndStatus")
			if msg_node and time_node:
				messages_data.append({ "text": msg_node.text, "time": time_node.text, "out": spacer_index == 0 })
	return messages_data
