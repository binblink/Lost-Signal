extends Node

const DELAY_IMAGE_MIN  := 0.3
const DELAY_IMAGE_MAX  := 0.8
const DELAY_AUDIO_MIN  := 0.5
const DELAY_AUDIO_MAX  := 1.5
const DELAY_AFTER_MEDIA := 0.3
const DELAY_AFTER_TEXT  := 0.5
const DELAY_EDIT_DEFAULT := 1.5

const PAUSE_SHORT_MIN  := 1.0
const PAUSE_SHORT_MAX  := 4.0
const PAUSE_MEDIUM_MIN := 5.0
const PAUSE_MEDIUM_MAX := 15.0
const PAUSE_LONG_MIN   := 15.0
const PAUSE_LONG_MAX   := 40.0
const PAUSE_FALLBACK   := 0.5

signal choice_made
signal free_input_submitted(text: String)
signal free_input_activated(placeholder: String)
signal free_input_aborted
signal save_requested(notify_panel: bool)
signal secondary_scene_received(contact_id: String)
signal contact_renamed(contact_id: String, new_name: String)
signal contact_status_changed(contact_id: String, new_status: String)
# [END SCREEN] — remove this line to remove the end screen feature.
signal game_ended
# [/END SCREEN]

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
var played_secondary_scenes: Array = []
var deferred_scenes: Dictionary = {}
var scheduled_scenes: Dictionary = {}
var current_music_path: String = ""

var _is_receiving: bool = false
var _is_player_typing: bool = false
var _waiting_for_free_input: bool = false
var _pending_resumes: Array = []
var _visible_choices: Array = []
var _abort: bool = false
var _play_generation: int = 0

var is_busy: bool:
	get: return _is_player_typing or _is_receiving

var is_waiting_for_free_input: bool:
	get: return _waiting_for_free_input


func abort_current() -> void:
	_abort = true
	_is_receiving = false
	_is_player_typing = false
	_waiting_for_free_input = false
	waiting_for_choice = false
	choices_layer.hide_choices()
	input_bar.visible = true
	_play_generation += 1
	choice_made.emit()
	free_input_submitted.emit("")
	_abort = false
	free_input_aborted.emit()


func play_scene(scene_id: String, _skip_delay: bool = false) -> void:
	if _abort:
		return
	if not DialogueLoader.has_scene(scene_id):
		push_error("[play_scene] scene not found: " + scene_id)
		return
	if current_scene.get("id", "") != scene_id:
		current_message_index = 0
	current_scene = DialogueLoader.get_scene(scene_id)
	var scene_contact = current_scene.get("contact_id", DialogueLoader.get_main_contact().get("id", "maeve"))

	var resume_delay = current_scene.get("resume_after_delay", null)
	if resume_delay != null and not _skip_delay:
		if not scheduled_scenes.has(scene_id):
			var delay_secs := _parse_delay(resume_delay)
			scheduled_scenes[scene_id] = int(Time.get_unix_time_from_system()) + int(delay_secs)
			_schedule_timer(scene_id, delay_secs)
			save_requested.emit(false)
		return

	if scene_contact != active_contact_id:
		_play_secondary_scene(current_scene)
		_trigger_next_scenes(scene_id)
		return

	var resume_flag = current_scene.get("resume_after_flag", null)
	if resume_flag != null and not flags.get(resume_flag, false):
		deferred_scenes[resume_flag] = scene_id
		return

	_handle_music(current_scene)
	var _gen := _play_generation
	_is_receiving = true
	for i in range(current_message_index, current_scene["messages_in"].size()):
		var msg = current_scene["messages_in"][i]
		if _eval_condition(msg):
			var pause = msg.get("pause", null)
			if pause != null:
				await do_pause(pause)
				if _play_generation != _gen:
					return
			_run_effects(msg.get("effects", []))
			var media = msg.get("media", null)
			var text  = msg.get("text", null)
			if msg.get("corrupted", false):
				var typing_ok = await message_display.show_typing("...")
				if not typing_ok:
					_is_receiving = false
					return
				await message_display.receive_corrupted_message(msg.get("time", ""))
				if _play_generation != _gen:
					return
				await get_tree().create_timer(DELAY_AFTER_TEXT).timeout
			elif media != null:
				match media.get("type", ""):
					"image":
						await get_tree().create_timer(randf_range(DELAY_IMAGE_MIN, DELAY_IMAGE_MAX)).timeout
						if _play_generation != _gen:
							return
						await message_display.receive_image_message(media["path"], msg.get("time", ""))
						await get_tree().create_timer(DELAY_AFTER_MEDIA).timeout
					"audio":
						await get_tree().create_timer(randf_range(DELAY_AUDIO_MIN, DELAY_AUDIO_MAX)).timeout
						if _play_generation != _gen:
							return
						await message_display.receive_audio_message(media["path"], msg.get("time", ""))
						await get_tree().create_timer(DELAY_AFTER_MEDIA).timeout
			elif text != null:
				var display_text := _apply_templates(text)
				var typing_ok = await message_display.show_typing(display_text)
				if not typing_ok:
					_is_receiving = false
					return
				var bubble = await message_display.receive_message(display_text, msg.get("time", ""))
				var edit = msg.get("edit", null)
				if edit != null:
					var edits: Array = edit if edit is Array else [edit]
					for e in edits:
						await get_tree().create_timer(e.get("delay", DELAY_EDIT_DEFAULT)).timeout
						if not is_instance_valid(bubble):
							break
						var label = bubble.get_node("HBoxContainer/Bubble/MarginContainer/VBoxContainer/Message")
						match e.get("type", ""):
							"correct":
								label.text = e.get("corrected_text", "")
							"delete":
								label.text = tr("MSG_DELETED")
								label.add_theme_color_override("font_color", ThemeManager.time_color)
				else:
					await get_tree().create_timer(DELAY_AFTER_TEXT).timeout
		if _play_generation != _gen:
			return
		current_message_index = i + 1
		save_requested.emit(true)
	_is_receiving = false

	if current_scene.has("free_input"):
		var var_name: String = current_scene["free_input"]
		_waiting_for_free_input = true
		input_bar.visible = true
		free_input_activated.emit(current_scene.get("free_input_placeholder", ""))
		save_requested.emit(false)
		var submitted_text: String = await free_input_submitted
		if _abort:
			return
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
		_visible_choices = current_scene["choices"].filter(func(c): return _eval_condition(c))
		await choices_layer.show_choices(
			_visible_choices.map(func(c): return c["text"])
		)
		await choice_made
		if _abort:
			return

	_trigger_next_scenes(scene_id)


func handle_choice(index: int) -> void:
	if _visible_choices.is_empty():
		return
	if index >= _visible_choices.size():
		return
	var choice = _visible_choices[index]
	waiting_for_choice = false
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
	var next_scene_id: String = choice.get("next", "")
	if next_scene_id != "" and DialogueLoader.has_scene(next_scene_id):
		current_message_index = 0
		current_scene = DialogueLoader.get_scene(next_scene_id)
		current_scene["contact_id"] = active_contact_id
	else:
		# No next scene — clear current_scene so a save here records scene_id = ""
		# and reload won't replay the finished scene from scratch.
		current_scene = {}
	save_requested.emit(true)
	choice_made.emit()
	if next_scene_id != "":
		await play_scene(next_scene_id)
	var resumes = _pending_resumes.duplicate()
	_pending_resumes.clear()
	for resume_id in resumes:
		await play_scene(resume_id)


func restore_pending_choice_for(contact_id: String) -> void:
	if pending_choices.has(contact_id):
		var pending_scene: Dictionary = DialogueLoader.get_scene(pending_choices[contact_id])
		if pending_scene.has("choices"):
			waiting_for_choice = true
			current_scene = pending_scene
			current_message_index = 0
			_visible_choices = pending_scene["choices"].filter(func(c): return _eval_condition(c))
			await choices_layer.show_choices(
				_visible_choices.map(func(c): return c["text"])
			)
		else:
			push_warning("[NarrativeController] pending_choices[%s] points to missing or invalid scene '%s' — clearing." % [contact_id, pending_choices[contact_id]])
			pending_choices.erase(contact_id)
			choices_layer.visible = false
	else:
		choices_layer.visible = false


func do_pause(type: String) -> void:
	var duration: float
	match type:
		"short":  duration = randf_range(PAUSE_SHORT_MIN,  PAUSE_SHORT_MAX)
		"medium": duration = randf_range(PAUSE_MEDIUM_MIN, PAUSE_MEDIUM_MAX)
		"long":   duration = randf_range(PAUSE_LONG_MIN,   PAUSE_LONG_MAX)
		_:        duration = PAUSE_FALLBACK
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
		if msg.get("corrupted", false):
			contact_histories[contact_id].append({ "text": null, "time": msg.get("time", ""), "out": false, "corrupted": true })
		elif media != null:
			contact_histories[contact_id].append({ "text": null, "time": msg.get("time", ""), "out": false, "media": media })
		elif msg.get("text", null) != null:
			contact_histories[contact_id].append({ "text": msg["text"], "time": msg.get("time", ""), "out": false })
	if scene.has("choices") and scene["choices"].size() > 0:
		pending_choices[contact_id] = scene["id"]
	secondary_scene_received.emit(contact_id)


func _trigger_next_scenes(scene_id: String) -> void:
	# [END SCREEN] — remove this block (4 lines) to remove the end screen feature.
	if DialogueLoader.get_scene(scene_id).get("end", false):
		game_ended.emit()
		return
	# [/END SCREEN]
	var triggered: Array = DialogueLoader.get_triggered_scenes(scene_id)
	for triggered_id: String in triggered:
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
	if cond.has("not"):
		return not _eval_cond_node(cond["not"])
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
	push_warning("NarrativeController: unknown condition ignored: %s" % str(cond))
	return false


func _set_flag(flag_name: String) -> void:
	flags[flag_name] = true
	if deferred_scenes.has(flag_name):
		_pending_resumes.append(deferred_scenes[flag_name])
		deferred_scenes.erase(flag_name)


func _apply_effects(choice: Dictionary) -> void:
	if choice.get("flag", null) != null:
		_set_flag(choice["flag"])
	_run_effects(choice.get("effects", []))


func get_contact_display_name(cid: String) -> String:
	if not contact_names.has(cid):
		return DialogueLoader.get_contact(cid).get("name", "")
	if contact_names[cid] is Dictionary:
		var names_dict: Dictionary = contact_names[cid] as Dictionary
		var lang: String = SettingsManager.language
		var localized: String = names_dict.get(lang, "")
		if localized != "":
			return localized
		for v in names_dict.values():
			return str(v)
		return ""
	return str(contact_names[cid])


func get_state() -> Dictionary:
	return {
		"current_scene_id":        current_scene.get("id", ""),
		"current_message_index":   current_message_index,
		"waiting_for_choice":      waiting_for_choice,
		"flags":                   flags,
		"vars":                    vars,
		"contact_names":           contact_names,
		"contact_statuses":        contact_statuses,
		"deferred_scenes":         deferred_scenes,
		"contact_histories":       contact_histories,
		"played_secondary_scenes": played_secondary_scenes,
		"pending_choices":         pending_choices,
		"current_music_path":      current_music_path,
		"scheduled_scenes":        scheduled_scenes,
		"active_contact_id":       active_contact_id,
	}

func set_state(data: Dictionary) -> void:
	flags                   = data.get("flags", {})
	vars                    = data.get("vars", {})
	contact_names           = data.get("contact_names", {})
	contact_statuses        = data.get("contact_statuses", {})
	deferred_scenes         = data.get("deferred_scenes", {})
	current_message_index   = data.get("current_message_index", 0)
	waiting_for_choice      = data.get("waiting_for_choice", false)
	played_secondary_scenes = data.get("played_secondary_scenes", [])
	pending_choices         = data.get("pending_choices", {})
	# "messages" is the legacy key — kept for backward compatibility with existing saves
	contact_histories       = data.get("contact_histories", data.get("messages", {}))
	current_music_path      = data.get("current_music_path", "")
	if current_music_path != "":
		AudioManager.play_music(current_music_path)
	scheduled_scenes = data.get("scheduled_scenes", {})
	var now := int(Time.get_unix_time_from_system())
	for scene_id in scheduled_scenes.keys():
		var remaining := float(scheduled_scenes[scene_id] - now)
		if remaining > 0.0:
			_schedule_timer(scene_id, remaining)


func rebuild_choices() -> void:
	if not current_scene.has("choices"):
		return
	_visible_choices = current_scene["choices"].filter(func(c): return _eval_condition(c))
	await choices_layer.show_choices(_visible_choices.map(func(c): return c["text"]))
	await choice_made


func submit_free_input(text: String) -> void:
	free_input_submitted.emit(text)


func _apply_templates(text: String) -> String:
	if vars.is_empty() or not "{" in text:
		return text
	return text.format(vars)


func _handle_music(scene: Dictionary) -> void:
	if not scene.has("music"):
		return
	var music = scene.get("music", null)
	if music == null:
		AudioManager.stop_music()
		current_music_path = ""
	else:
		AudioManager.play_music(music)
		current_music_path = music


func _parse_delay(value) -> float:
	if value is float or value is int:
		return float(value)
	if value is String:
		if value.ends_with("h"):
			return float(value.trim_suffix("h")) * 3600.0
		if value.ends_with("m"):
			return float(value.trim_suffix("m")) * 60.0
		if value.ends_with("s"):
			return float(value.trim_suffix("s"))
		return float(value)
	return 0.0


func _schedule_timer(scene_id: String, delay_seconds: float) -> void:
	get_tree().create_timer(delay_seconds).timeout.connect(func():
		scheduled_scenes.erase(scene_id)
		save_requested.emit(false)
		play_scene(scene_id, true)
	)


func resume_overdue_scenes() -> void:
	var now := int(Time.get_unix_time_from_system())
	var overdue := scheduled_scenes.keys().filter(func(sid): return scheduled_scenes[sid] <= now)
	for scene_id in overdue:
		scheduled_scenes.erase(scene_id)
		await play_scene(scene_id, true)
	if not overdue.is_empty():
		save_requested.emit(false)


func _run_effects(effects: Array) -> void:
	for effect in effects:
		match effect["op"]:
			"set":    vars[effect["var"]] = effect["value"]
			"add":    vars[effect["var"]] = vars.get(effect["var"], 0) + effect["value"]
			"sub":    vars[effect["var"]] = vars.get(effect["var"], 0) - effect["value"]
			"rename":
				var cid: String = effect.get("contact", "")
				if cid != "" and effect.has("value"):
					if effect["value"] is Dictionary:
						contact_names[cid] = effect["value"] as Dictionary
					else:
						var name_str: String = str(effect["value"])
						if name_str != "":
							contact_names[cid] = name_str
					var display: String = get_contact_display_name(cid)
					if display != "":
						contact_renamed.emit(cid, display)
			"set_status":
				var cid: String = effect.get("contact", "")
				var new_status: String = str(effect.get("value", "online"))
				if cid != "":
					contact_statuses[cid] = new_status
					contact_status_changed.emit(cid, new_status)
