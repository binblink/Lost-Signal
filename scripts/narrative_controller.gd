extends Node

signal choice_made
signal free_input_submitted(text: String)
signal free_input_activated
signal save_requested(notify_panel: bool)
signal secondary_scene_received(contact_id: String)
signal contact_renamed(contact_id: String, new_name: String)
signal contact_status_changed(contact_id: String, new_status: String)

var message_display: VBoxContainer = null
var choices_layer: Control = null
var input_bar: Control = null

var active_contact_id: String = ""
var current_scene: Dictionary = {}
var flags: Dictionary = {}
var vars: Dictionary = {}
var contact_names: Dictionary = {}
var contact_statuses: Dictionary = {}
var contact_histories: Dictionary = {}
var pending_choices: Dictionary = {}
var current_message_index: int = 0
var waiting_for_choice: bool = false
var secondary_histories: Dictionary = {}
var played_secondary_scenes: Array = []
var deferred_scenes: Dictionary = {}

var _is_receiving: bool = false
var _is_player_typing: bool = false
var _waiting_for_free_input: bool = false
var _pending_resumes: Array = []

var is_busy: bool:
	get: return _is_player_typing or _is_receiving


func play_scene(scene_id: String) -> void:
	if not DialogueLoader.has_scene(scene_id):
		return
	current_scene = DialogueLoader.get_scene(scene_id)
	var scene_contact = current_scene.get("contact_id", DialogueLoader.get_main_contact().get("id", "maeve"))

	if scene_contact != active_contact_id:
		_play_secondary_scene(current_scene)
		_trigger_next_scenes(scene_id)
		return

	var resume_flag = current_scene.get("resume_after_flag", null)
	if resume_flag != null and not flags.get(resume_flag, false):
		deferred_scenes[resume_flag] = scene_id
		return

	_is_receiving = true
	for i in range(current_message_index, current_scene["messages_in"].size()):
		var msg = current_scene["messages_in"][i]
		if _eval_condition(msg):
			var pause = msg.get("pause", null)
			if pause != null:
				await do_pause(pause)
			_run_effects(msg.get("effects", []))
			var media = msg.get("media", null)
			var text  = msg.get("text", null)
			if media != null:
				match media.get("type", ""):
					"image":
						await get_tree().create_timer(randf_range(0.3, 0.8)).timeout
						await message_display.receive_image_message(media["path"], msg.get("time", ""))
						await get_tree().create_timer(0.3).timeout
					"audio":
						await get_tree().create_timer(randf_range(0.5, 1.5)).timeout
						await message_display.receive_audio_message(media["path"], msg.get("time", ""))
						await get_tree().create_timer(0.3).timeout
			elif text != null:
				var display_text := _apply_templates(text)
				var typing_ok = await message_display.show_typing(display_text)
				if not typing_ok:
					_is_receiving = false
					return
				var bubble = await message_display.receive_message(display_text, msg.get("time", ""))
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
		save_requested.emit(true)
	_is_receiving = false

	if current_scene.has("free_input"):
		var var_name: String = current_scene["free_input"]
		_waiting_for_free_input = true
		free_input_activated.emit()
		save_requested.emit(false)
		var submitted_text: String = await free_input_submitted
		_waiting_for_free_input = false
		vars[var_name] = submitted_text
		_is_player_typing = true
		await message_display.type_message(submitted_text)
		_is_player_typing = false
		save_requested.emit(true)
		_trigger_next_scenes(scene_id)
		var fi_next = current_scene.get("next", null)
		if fi_next != null:
			await play_scene(fi_next)
		return

	waiting_for_choice = true
	save_requested.emit(false)

	if current_scene.has("choices"):
		await choices_layer.show_choices(
			current_scene["choices"].map(func(c): return c["text"])
		)
		await choice_made

	_trigger_next_scenes(scene_id)


func handle_choice(index: int) -> void:
	if not current_scene.has("choices"):
		return
	if index >= current_scene["choices"].size():
		return
	var choice = current_scene["choices"][index]
	waiting_for_choice = false
	current_message_index = 0
	_apply_effects(choice)
	choices_layer.hide_choices()
	input_bar.visible = true
	pending_choices.erase(active_contact_id)
	var message_data = choice.get("message", choice["text"])
	var messages: Array = message_data if message_data is Array else [message_data]
	_is_player_typing = true
	for msg in messages:
		await message_display.type_message(_apply_templates(msg))
	_is_player_typing = false
	var next_scene_id = choice.get("next", null)
	if next_scene_id != null and DialogueLoader.has_scene(next_scene_id):
		current_scene = DialogueLoader.get_scene(next_scene_id)
		current_scene["contact_id"] = active_contact_id
	save_requested.emit(true)
	choice_made.emit()
	if next_scene_id != null:
		await play_scene(next_scene_id)
	var resumes = _pending_resumes.duplicate()
	_pending_resumes.clear()
	for resume_id in resumes:
		await play_scene(resume_id)


func restore_pending_choice_for(contact_id: String) -> void:
	if pending_choices.has(contact_id):
		var pending_scene = DialogueLoader.get_scene(pending_choices[contact_id])
		if pending_scene.has("choices"):
			waiting_for_choice = true
			current_scene = pending_scene
			current_message_index = 0
			await choices_layer.show_choices(
				pending_scene["choices"].map(func(c): return c["text"])
			)
	else:
		choices_layer.visible = false


func do_pause(type: String) -> void:
	var duration: float
	match type:
		"short":  duration = randf_range(1.0, 4.0)
		"medium": duration = randf_range(5.0, 15.0)
		"long":   duration = randf_range(15.0, 40.0)
		_:        duration = 0.5
	await get_tree().create_timer(duration).timeout


func _play_secondary_scene(scene: Dictionary) -> void:
	var scene_id = scene.get("id", "")
	if scene_id in played_secondary_scenes:
		return
	played_secondary_scenes.append(scene_id)
	var contact_id = scene.get("contact_id", "")
	if not contact_histories.has(contact_id):
		contact_histories[contact_id] = []
	for msg in scene.get("messages_in", []):
		if not _eval_condition(msg):
			continue
		_run_effects(msg.get("effects", []))
		var media = msg.get("media", null)
		if media != null:
			contact_histories[contact_id].append({ "text": null, "time": msg.get("time", ""), "out": false, "media": media })
		elif msg.get("text", null) != null:
			contact_histories[contact_id].append({ "text": msg["text"], "time": msg.get("time", ""), "out": false })
	if scene.has("choices") and scene["choices"].size() > 0:
		pending_choices[contact_id] = scene["id"]
	secondary_scene_received.emit(contact_id)


func _trigger_next_scenes(scene_id: String) -> void:
	var triggered = DialogueLoader.get_triggered_scenes(scene_id)
	for triggered_id in triggered:
		await play_scene(triggered_id)


func _eval_condition(msg: Dictionary) -> bool:
	var req_flag = msg.get("requires_flag", null)
	if req_flag != null:
		if req_flag is Array:
			for f in req_flag:
				if not flags.get(f, false):
					return false
		elif not flags.get(req_flag, false):
			return false
	var cond = msg.get("condition", null)
	if cond != null and not _eval_cond_node(cond):
		return false
	return true


func _eval_cond_node(cond: Dictionary) -> bool:
	if cond.has("and"):
		for sub in cond["and"]:
			if not _eval_cond_node(sub):
				return false
		return true
	if cond.has("or"):
		for sub in cond["or"]:
			if _eval_cond_node(sub):
				return true
		return false
	if cond.has("flag"):
		return flags.get(cond["flag"], false)
	if cond.has("var"):
		var val = vars.get(cond["var"], 0)
		var target = cond["value"]
		match cond["op"]:
			"eq":  return val == target
			"neq": return val != target
			"gt":  return val > target
			"gte": return val >= target
			"lt":  return val < target
			"lte": return val <= target
	push_warning("NarrativeController: condition inconnue ignorée : %s" % str(cond))
	return false


func _apply_effects(choice: Dictionary) -> void:
	if choice.get("flag", null) != null:
		var flag_name: String = choice["flag"]
		flags[flag_name] = true
		if deferred_scenes.has(flag_name):
			_pending_resumes.append(deferred_scenes[flag_name])
			deferred_scenes.erase(flag_name)
	_run_effects(choice.get("effects", []))


func get_state() -> Dictionary:
	return {
		"current_scene_id":       current_scene.get("id", ""),
		"current_message_index":  current_message_index,
		"waiting_for_choice":     waiting_for_choice,
		"flags":                  flags,
		"vars":                   vars,
		"contact_names":          contact_names,
		"contact_statuses":       contact_statuses,
		"deferred_scenes":        deferred_scenes,
		"contact_histories":      contact_histories,
		"secondary_histories":    secondary_histories,
		"played_secondary_scenes": played_secondary_scenes,
		"pending_choices":        pending_choices,
	}

func set_state(data: Dictionary) -> void:
	flags                   = data.get("flags", {})
	vars                    = data.get("vars", {})
	contact_names           = data.get("contact_names", {})
	contact_statuses        = data.get("contact_statuses", {})
	deferred_scenes         = data.get("deferred_scenes", {})
	current_message_index   = data.get("current_message_index", 0)
	waiting_for_choice      = data.get("waiting_for_choice", false)
	secondary_histories     = data.get("secondary_histories", {})
	played_secondary_scenes = data.get("played_secondary_scenes", [])
	pending_choices         = data.get("pending_choices", {})
	# "messages" est l'ancienne clé — conservé pour compatibilité avec les sauvegardes existantes
	contact_histories       = data.get("contact_histories", data.get("messages", {}))


func submit_free_input(text: String) -> void:
	free_input_submitted.emit(text)


func _apply_templates(text: String) -> String:
	if vars.is_empty() or not "{" in text:
		return text
	return text.format(vars)


func _run_effects(effects: Array) -> void:
	for effect in effects:
		match effect["op"]:
			"set":    vars[effect["var"]] = effect["value"]
			"add":    vars[effect["var"]] = vars.get(effect["var"], 0) + effect["value"]
			"sub":    vars[effect["var"]] = vars.get(effect["var"], 0) - effect["value"]
			"rename":
				var cid: String = effect.get("contact", "")
				var new_name: String = str(effect.get("value", ""))
				if cid != "" and new_name != "":
					contact_names[cid] = new_name
					contact_renamed.emit(cid, new_name)
			"set_status":
				var cid: String = effect.get("contact", "")
				var new_status: String = str(effect.get("value", "online"))
				if cid != "":
					contact_statuses[cid] = new_status
					contact_status_changed.emit(cid, new_status)
