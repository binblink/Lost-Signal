extends Node

const SAVE_PATH = "user://savegame.json"

# Structure de la sauvegarde :
# {
#   "current_scene_id": String,
#   "current_message_index": int,
#   "waiting_for_choice": bool,
#   "flags": Dictionary,
#   "messages": { contact_id: Array de { text, time, out } },
#   "secondary_histories": { contact_id: Array de { text, time } }
# }

func save(
	messages_data: Dictionary,
	current_scene_id: String,
	current_message_index: int,
	waiting_for_choice: bool,
	flags: Dictionary,
	vars: Dictionary,
	contact_names: Dictionary,
	contact_statuses: Dictionary,
	deferred_scenes: Dictionary,
	secondary_histories: Dictionary,
	played_secondary_scenes: Array = [],
	pending_choices: Dictionary = {}
) -> void:
	var save_data = {
		"current_scene_id": current_scene_id,
		"current_message_index": current_message_index,
		"waiting_for_choice": waiting_for_choice,
		"flags": flags,
		"vars": vars,
		"contact_names": contact_names,
		"contact_statuses": contact_statuses,
		"deferred_scenes": deferred_scenes,
		"messages": messages_data,
		"secondary_histories": secondary_histories,
		"played_secondary_scenes": played_secondary_scenes,
		"pending_choices": pending_choices
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(save_data))
	file.close()

func load_save() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var json = JSON.new()
	json.parse(file.get_as_text())
	file.close()
	return json.get_data()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
