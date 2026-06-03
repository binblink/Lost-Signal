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

func save(state: Dictionary) -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(state))
	file.close()

func load_save() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var text = file.get_as_text()
	file.close()
	var json = JSON.new()
	if json.parse(text) != OK:
		push_error("SaveManager: sauvegarde corrompue (ligne %d) — ignorée." % json.get_error_line())
		return {}
	var data = json.get_data()
	if not data is Dictionary:
		push_error("SaveManager: format de sauvegarde invalide — ignoré.")
		return {}
	return data

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
