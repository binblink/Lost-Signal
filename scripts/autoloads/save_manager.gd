extends Node

const SAVE_PATH = "user://savegame.json"

# Sauvegarde l'état complet de la partie.
# messages_data : Array de dicts { text, time, out }
# current_scene_id : String
# current_message_index : int
# waiting_for_choice : bool
# flags : Dictionary
func save(
	messages_data: Array,
	current_scene_id: String,
	current_message_index: int,
	waiting_for_choice: bool,
	flags: Dictionary
) -> void:
	var save_data = {
		"current_scene_id": current_scene_id,
		"current_message_index": current_message_index,
		"waiting_for_choice": waiting_for_choice,
		"flags": flags,
		"messages": messages_data
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(save_data))
	file.close()
	print("Partie sauvegardée.")

# Retourne les données de sauvegarde sous forme de Dictionary,
# ou {} si aucune sauvegarde n'existe.
func load_save() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		print("Aucune sauvegarde trouvée.")
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
		print("Sauvegarde supprimée.")
