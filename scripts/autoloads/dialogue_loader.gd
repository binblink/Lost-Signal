extends Node

const STORY_PATH    = "res://story.json"
const DIALOGUES_DIR = "res://dialogues/"

var _scenes:         Dictionary = {}
var _contacts:       Array      = []
var _start_scene:    String     = "scene_01"
var _start_contact:  String     = ""
var _title:          String     = ""
var _triggers:       Dictionary = {}
var validation_errors:   Array = []
var validation_warnings: Array = []
var _load_errors:        Array = []
# [END SCREEN] — remove this line to remove the end screen feature.
var _end_screen: Dictionary = {}
# [/END SCREEN]

func _ready() -> void:
	_load_story()
	_load_dialogues_dir()
	print("DialogueLoader: %d scenes, %d contacts loaded." % [_scenes.size(), _contacts.size()])
	_validate()

func reload_for_locale() -> void:
	_scenes.clear()
	_contacts.clear()
	_triggers.clear()
	validation_errors.clear()
	validation_warnings.clear()
	_load_errors.clear()
	_load_story()
	_load_dialogues_dir()
	_validate()

func get_validation_report() -> Dictionary:
	return {
		"errors": validation_errors.duplicate(),
		"warnings": validation_warnings.duplicate()
	}

func has_validation_issues() -> bool:
	return validation_errors.size() > 0 or validation_warnings.size() > 0

# ---------------------------------------------------------------------------

func _load_story() -> void:
	var data = _parse_json(STORY_PATH)
	if data.is_empty():
		return
	if data.has("title"):         _title         = data["title"]
	if data.has("start_scene"):   _start_scene   = data["start_scene"]
	if data.has("start_contact"): _start_contact = data["start_contact"]
	if data.has("contacts"):
		_contacts = data["contacts"]
		_resolve_contact_names()
		_resolve_history_texts()
	# [END SCREEN] — remove this block to remove the end screen feature.
	if data.has("end_screen"):
		_end_screen = data["end_screen"]
		_resolve_end_screen_texts()
	# [/END SCREEN]

func _load_dialogues_dir() -> void:
	var dir = DirAccess.open(DIALOGUES_DIR)
	if dir == null:
		push_error("DialogueLoader: directory not found — " + DIALOGUES_DIR)
		return

	var locale := SettingsManager.language

	# Collect all .json files
	var all_files: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			all_files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	# For each base name, prefer the locale-specific file (base.locale.json)
	# and fall back to the unlocalized file (base.json).
	var chosen: Dictionary = {}  # base_name -> file_name
	for f: String in all_files:
		var base: String = f.get_basename()  # e.g. "acte1.en" or "acte1"
		var parts: PackedStringArray = base.split(".")
		if parts.size() == 2:
			var file_locale := parts[1]
			if file_locale == locale:
				chosen[parts[0]] = f   # locale match — highest priority
		elif parts.size() == 1:
			if not chosen.has(base):
				chosen[base] = f       # fallback if no locale file yet

	for f in chosen.values():
		_load_scenes_from(DIALOGUES_DIR + f)

func _load_scenes_from(path: String) -> void:
	var data = _parse_json(path)
	if data.is_empty() or not data.has("scenes"):
		return
	if data.has("start_scene"):
		_start_scene = data["start_scene"]
	for scene in data["scenes"]:
		if not scene.has("contact_id"):
			scene["contact_id"] = _get_main_contact_id()
		if scene.has("messages_in"):
			var expanded: Array = []
			for m in scene["messages_in"]:
				expanded.append_array(_normalize_message(m))
			scene["messages_in"] = expanded
		if _scenes.has(scene["id"]):
			var _dup_msg: String = "Duplicate scene ID '%s' found in %s — first occurrence kept." % [scene["id"], path]
			push_error("DialogueLoader: " + _dup_msg)
			_load_errors.append(_dup_msg)
			continue
		_scenes[scene["id"]] = scene
		var trigger = scene.get("trigger_after_scene", null)
		if trigger != null:
			if not _triggers.has(trigger):
				_triggers[trigger] = []
			_triggers[trigger].append(scene["id"])

func _normalize_message(m) -> Array:
	if m is String:
		return [{ "text": m }]
	if not m is Dictionary:
		return []
	if not m.get("text", null) is Array:
		return [m]
	if m.has("edit"):
		push_warning("DialogueLoader: 'edit' on a multi-bubble message (text array) is not supported and will be ignored.")
	var texts: Array = m["text"]
	var result: Array = []
	for i in range(texts.size()):
		var element = texts[i]
		var entry: Dictionary = {}
		if element is String:
			entry["text"] = element
		elif element is Dictionary:
			entry["text"] = element.get("text", "")
			if element.has("pause"): entry["pause"] = element["pause"]
		else:
			entry["text"] = str(element)
		if m.has("requires_flag"): entry["requires_flag"] = m["requires_flag"]
		if m.has("condition"):     entry["condition"]     = m["condition"]
		if i == 0:
			if not entry.has("pause") and m.has("pause"): entry["pause"] = m["pause"]
			if m.has("effects"): entry["effects"] = m["effects"]
		if i == texts.size() - 1:
			if m.has("time"): entry["time"] = m["time"]
		result.append(entry)
	return result


func _parse_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("DialogueLoader: file not found — " + path)
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("DialogueLoader: cannot open %s (code %d)." % [path, FileAccess.get_open_error()])
		return {}
	var json  = JSON.new()
	var err   = json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_error("DialogueLoader: JSON error in %s line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	return json.get_data()

# --- Public API ---

func get_title() -> String:
	return _title

func get_start_scene() -> String:
	return _start_scene

func get_start_contact() -> String:
	return _start_contact

func get_scene(id: String) -> Dictionary:
	return _scenes.get(id, {})

func has_scene(id: String) -> bool:
	return _scenes.has(id)

func get_triggered_scenes(scene_id: String) -> Array:
	return _triggers.get(scene_id, [])

func get_contacts() -> Array:
	return _contacts

func get_contact(id: String) -> Dictionary:
	for c in _contacts:
		if c["id"] == id:
			return c
	return {}

func get_main_contact() -> Dictionary:
	for c in _contacts:
		if c.get("is_main", false):
			return c
	return _contacts[0] if _contacts.size() > 0 else {}

# [END SCREEN] — remove this function to remove the end screen feature.
func get_end_screen() -> Dictionary:
	return _end_screen.duplicate()
# [/END SCREEN]

func _resolve_contact_names() -> void:
	var lang: String = SettingsManager.language
	for contact in _contacts:
		var names = contact.get("names", null)
		if names is Dictionary:
			var localized: String = (names as Dictionary).get(lang, "")
			if localized != "":
				contact["name"] = localized

# [END SCREEN]
func _resolve_end_screen_texts() -> void:
	var lang: String = SettingsManager.language
	for key: String in ["title", "text"]:
		var val = _end_screen.get(key, null)
		if val is Dictionary:
			var localized: String = (val as Dictionary).get(lang, "")
			if localized.is_empty():
				for v in (val as Dictionary).values():
					if v is String and not (v as String).is_empty():
						localized = v
						break
			_end_screen[key] = localized
# [/END SCREEN]

func _resolve_history_texts() -> void:
	var lang: String = SettingsManager.language
	for contact in _contacts:
		for entry in contact.get("history", []):
			var text = entry.get("text", "")
			if text is Dictionary:
				var localized: String = (text as Dictionary).get(lang, "")
				if localized.is_empty():
					for v in (text as Dictionary).values():
						if v is String and not (v as String).is_empty():
							localized = v
							break
				entry["text"] = localized

func _get_main_contact_id() -> String:
	return get_main_contact().get("id", "")

func get_all_flags() -> Array:
	var result: Array = []
	for scene in _scenes.values():
		for choice in scene.get("choices", []):
			var f = choice.get("flag", null)
			if f != null and f not in result:
				result.append(f)
	return result

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

func _validate() -> void:
	var errors:   Array = _load_errors.duplicate()
	var warnings: Array = []

	var contact_ids: Array = _contacts.map(func(c): return c.get("id", ""))

	# Collect all flags set by choices (the only possible source)
	var flags_set: Array = []
	for scene in _scenes.values():
		for choice in scene.get("choices", []):
			var f = choice.get("flag", null)
			if f != null and not f in flags_set:
				flags_set.append(f)
	# opened_{contact_id} flags are set by main.gd on contact switch — always valid
	for cid: String in contact_ids:
		flags_set.append("opened_" + cid)

	# start_contact
	if _start_contact != "" and not _start_contact in contact_ids:
		errors.append("start_contact '%s' not found in contacts." % _start_contact)

	# pending_scene in story.json contacts
	for contact in _contacts:
		var cid: String = contact.get("id", "?")
		var ps: String = contact.get("pending_scene", "")
		if ps != "" and not _scenes.has(ps):
			errors.append("Contact '%s': pending_scene '%s' not found." % [cid, ps])

	# start_scene
	if not _scenes.has(_start_scene):
		errors.append("start_scene '%s' not found in loaded scenes." % _start_scene)

	for scene_id in _scenes.keys():
		var scene: Dictionary = _scenes[scene_id]
		var ctx: String = "[%s]" % scene_id

		# contact_id
		var cid: String = scene.get("contact_id", "")
		if cid != "" and not cid in contact_ids:
			errors.append("%s contact_id '%s' not found in story.json." % [ctx, cid])

		# messages_in
		if not scene.has("messages_in"):
			errors.append("%s missing 'messages_in'." % ctx)
		else:
			var msgs: Array = scene["messages_in"]
			for i in range(msgs.size()):
				_check_message(msgs[i], ctx, i, flags_set, contact_ids, errors, warnings)

		# trigger_after_scene
		var trigger = scene.get("trigger_after_scene", null)
		if trigger != null and not _scenes.has(trigger):
			errors.append("%s trigger_after_scene '%s' not found." % [ctx, trigger])

		# resume_after_flag
		var resume_flag = scene.get("resume_after_flag", null)
		if resume_flag != null and not resume_flag in flags_set:
			errors.append("%s resume_after_flag '%s' is never set by any choice — scene will deadlock." % [ctx, resume_flag])

		# free_input
		var free_input = scene.get("free_input", null)
		if free_input != null:
			if not free_input is String or free_input.is_empty():
				errors.append("%s free_input must be a non-empty string (variable name)." % ctx)
			var fi_next = scene.get("next", null)
			if fi_next == null:
				warnings.append("%s free_input present but 'next' is missing — narration will stop after input." % ctx)
			elif not _scenes.has(fi_next):
				errors.append("%s next '%s' not found." % [ctx, fi_next])

		# choices
		var choices: Array = scene.get("choices", [])
		var is_end_scene: bool = scene.get("end", false)
		for j in range(choices.size()):
			_check_choice(choices[j], ctx, j, flags_set, contact_ids, errors, warnings, is_end_scene)

	_detect_trigger_cycles(errors)

	validation_errors = errors
	validation_warnings = warnings

	for e in errors:
		push_error("Validator: " + e)
	for w in warnings:
		push_warning("Validator: " + w)

	if errors.is_empty() and warnings.is_empty():
		print("Validator: %d scenes checked — no errors." % _scenes.size())
	else:
		print("Validator: %d error(s), %d warning(s)." % [errors.size(), warnings.size()])


func _check_message(msg: Dictionary, ctx: String, i: int, flags_set: Array, contact_ids: Array, errors: Array, warnings: Array) -> void:
	var label := "%s msg[%d]" % [ctx, i]
	var media = msg.get("media", null)
	var text  = msg.get("text",  null)

	if media != null:
		var mtype = media.get("type", null)
		if mtype == null:
			errors.append("%s media missing 'type'." % label)
		elif not mtype in ["image", "audio"]:
			errors.append("%s unknown media type '%s' (accepted: image, audio)." % [label, mtype])
		if not media.has("path") or str(media.get("path", "")) == "":
			errors.append("%s media missing 'path'." % label)
	elif text == null:
		var has_effects:   bool = msg.get("effects", []).size() > 0
		var has_pause:     bool = msg.get("pause", null) != null
		var is_corrupted:  bool = msg.get("corrupted", false)
		if not has_effects and not has_pause and not is_corrupted:
			warnings.append("%s silent message with no effects or pause (will be skipped)." % label)

	var req_flag = msg.get("requires_flag", null)
	if req_flag != null and not req_flag in flags_set:
		warnings.append("%s requires_flag '%s' is never set by any choice." % [label, req_flag])

	var cond = msg.get("condition", null)
	if cond != null:
		_check_condition(cond, label, flags_set, warnings, errors)

	var pause = msg.get("pause", null)
	if pause != null and not pause in ["short", "medium", "long"]:
		warnings.append("%s unknown pause value '%s' (accepted: short / medium / long)." % [label, pause])

	var efx: Array = msg.get("effects", [])
	for k in range(efx.size()):
		_check_effect(efx[k], "%s effect[%d]" % [label, k], contact_ids, errors, warnings)


func _check_choice(choice: Dictionary, ctx: String, j: int, flags_set: Array, contact_ids: Array, errors: Array, warnings: Array, is_end_scene: bool = false) -> void:
	var label := "%s choice[%d]" % [ctx, j]
	if not choice.has("text") or choice["text"] == null:
		errors.append("%s missing 'text'." % label)
	var req_flag = choice.get("requires_flag", null)
	if req_flag != null and not req_flag in flags_set:
		warnings.append("%s requires_flag '%s' is never set by any choice." % [label, req_flag])
	if not choice.has("next") and not is_end_scene:
		warnings.append("%s no 'next' (terminal choice)." % label)
	else:
		var next_id = choice.get("next", null)
		if next_id != null and not _scenes.has(next_id):
			errors.append("%s next '%s' not found." % [label, next_id])
	var msg_data = choice.get("message", null)
	if msg_data != null:
		if msg_data is Array:
			for k in range(msg_data.size()):
				if not msg_data[k] is String:
					errors.append("%s message[%d] must be a string." % [label, k])
		elif not msg_data is String:
			errors.append("%s 'message' must be a string or array of strings." % label)
	var efx: Array = choice.get("effects", [])
	for k in range(efx.size()):
		_check_effect(efx[k], "%s effect[%d]" % [label, k], contact_ids, errors, warnings)


func _check_condition(cond: Dictionary, label: String, flags_set: Array, warnings: Array, errors: Array) -> void:
	if cond.has("and"):
		for i in range(cond["and"].size()):
			_check_condition(cond["and"][i], "%s.and[%d]" % [label, i], flags_set, warnings, errors)
		return
	if cond.has("or"):
		for i in range(cond["or"].size()):
			_check_condition(cond["or"][i], "%s.or[%d]" % [label, i], flags_set, warnings, errors)
		return
	if cond.has("not"):
		_check_condition(cond["not"], "%s.not" % label, flags_set, warnings, errors)
		return
	if cond.has("flag"):
		if not cond["flag"] in flags_set:
			warnings.append("%s condition flag '%s' is never set by any choice." % [label, cond["flag"]])
		return
	if not cond.has("var") or not cond.has("op") or not cond.has("value"):
		errors.append("%s malformed condition (required fields: var, op, value or flag)." % label)
		return
	if not cond["op"] in ["eq", "neq", "gt", "gte", "lt", "lte"]:
		errors.append("%s unknown condition op '%s' (eq/neq/gt/gte/lt/lte)." % [label, cond["op"]])


func _detect_trigger_cycles(errors: Array) -> void:
	var color: Dictionary = {}
	for scene_id in _scenes.keys():
		if not color.has(scene_id):
			_dfs_trigger(scene_id, color, [], errors)

func _dfs_trigger(scene_id: String, color: Dictionary, stack: Array, errors: Array) -> void:
	color[scene_id] = 1
	stack.append(scene_id)
	for triggered_id in _triggers.get(scene_id, []):
		if not _scenes.has(triggered_id):
			continue
		if not color.has(triggered_id):
			_dfs_trigger(triggered_id, color, stack, errors)
		elif color[triggered_id] == 1:
			var cycle_start: int = stack.find(triggered_id)
			var cycle: Array = stack.slice(cycle_start) + [triggered_id]
			errors.append("Trigger cycle detected: %s" % " → ".join(cycle))
	stack.pop_back()
	color[scene_id] = 2


func _check_effect(effect: Dictionary, label: String, contact_ids: Array, errors: Array, warnings: Array) -> void:
	var op = effect.get("op", null)
	if op == null:
		errors.append("%s effect missing 'op'." % label)
		return
	match op:
		"set", "add", "sub":
			if not effect.has("var") or not effect.has("value"):
				errors.append("%s effect '%s' requires 'var' and 'value'." % [label, op])
		"rename", "set_status":
			if not effect.has("contact") or not effect.has("value"):
				errors.append("%s effect '%s' requires 'contact' and 'value'." % [label, op])
			elif not effect["contact"] in contact_ids:
				errors.append("%s effect '%s': contact '%s' not found in story.json." % [label, op, effect["contact"]])
		_:
			warnings.append("%s unknown effect op '%s'." % [label, op])
