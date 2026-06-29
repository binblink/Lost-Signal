extends RefCounted


static func compact(value: Variant) -> String:
	if value is Dictionary:
		if (value as Dictionary).is_empty():
			return "{}"
		var parts: Array[String] = []
		for key: Variant in value:
			parts.append(JSON.stringify(str(key)) + ": " + compact(value[key]))
		return "{" + ", ".join(parts) + "}"
	if value is Array:
		if (value as Array).is_empty():
			return "[]"
		var parts: Array[String] = []
		for item: Variant in value:
			parts.append(compact(item))
		return "[" + ", ".join(parts) + "]"
	return JSON.stringify(value)


# Expands top-level structure for readability, then falls back to compact past depth 4.
static func expand(value: Variant, indent: String) -> String:
	if indent.length() >= 4:
		return compact(value)
	if value is Dictionary:
		if (value as Dictionary).is_empty():
			return "{}"
		var next_indent: String = indent + "\t"
		var parts: Array[String] = []
		for key: Variant in value:
			parts.append(next_indent + JSON.stringify(str(key)) + ": " + expand(value[key], next_indent))
		return "{\n" + ",\n".join(parts) + "\n" + indent + "}"
	if value is Array:
		if (value as Array).is_empty():
			return "[]"
		var next_indent: String = indent + "\t"
		var parts: Array[String] = []
		for item: Variant in value:
			parts.append(next_indent + expand(item, next_indent))
		return "[\n" + ",\n".join(parts) + "\n" + indent + "]"
	return JSON.stringify(value)


# Returns a copy of the scene dict with keys in canonical order, and strips the
# runtime-only _editor_file key. Stable order keeps git diffs readable when only
# one field changes.
static func ordered_scene(scene: Dictionary) -> Dictionary:
	const SCENE_KEYS := ["_notes", "id", "contact_id", "trigger_after_scene",
		"resume_after_flag", "resume_after_delay", "messages_in",
		"free_input", "free_input_placeholder", "music", "next", "choices"]
	var result := {}
	for key in SCENE_KEYS:
		if scene.has(key):
			result[key] = scene[key]
	for key in scene:
		if key != "_editor_file" and not result.has(key):
			result[key] = scene[key]
	if result.has("messages_in"):
		var ordered_msgs: Array = []
		for msg in (result["messages_in"] as Array):
			ordered_msgs.append(ordered_message(msg))
		result["messages_in"] = ordered_msgs
	if result.has("choices"):
		var ordered_choices: Array = []
		for choice in (result["choices"] as Array):
			ordered_choices.append(ordered_choice(choice))
		result["choices"] = ordered_choices
	return result


# Returns a copy of the message dict with keys in canonical order.
static func ordered_message(msg: Dictionary) -> Dictionary:
	const MSG_KEYS := ["text", "edit", "effects", "media", "pause",
		"requires_flag", "condition", "corrupted", "time"]
	var result := {}
	for key in MSG_KEYS:
		if msg.has(key):
			result[key] = msg[key]
	for key in msg:
		if not result.has(key):
			result[key] = msg[key]
	return result


# Returns a copy of the choice dict with keys in canonical order.
static func ordered_choice(choice: Dictionary) -> Dictionary:
	const CHOICE_KEYS := ["text", "message", "flag", "requires_flag", "condition", "next", "effects"]
	var result := {}
	for key in CHOICE_KEYS:
		if choice.has(key):
			result[key] = choice[key]
	for key in choice:
		if not result.has(key):
			result[key] = choice[key]
	return result
