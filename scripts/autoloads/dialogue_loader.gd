extends Node
 
const DIALOGUE_PATH = "res://dialogue.json"
 
var _scenes: Dictionary = {}
 
func _ready() -> void:
	_load()
 
func _load() -> void:
	if not FileAccess.file_exists(DIALOGUE_PATH):
		push_error("DialogueLoader: fichier introuvable → " + DIALOGUE_PATH)
		return
	var file = FileAccess.open(DIALOGUE_PATH, FileAccess.READ)
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_error("DialogueLoader: erreur de parsing JSON ligne %d : %s" % [json.get_error_line(), json.get_error_message()])
		return
	var data = json.get_data()
	for scene in data["scenes"]:
		_scenes[scene["id"]] = scene
	print("DialogueLoader: %d scènes chargées." % _scenes.size())
 
func get_scene(id: String) -> Dictionary:
	return _scenes.get(id, {})
 
func has_scene(id: String) -> bool:
	return _scenes.has(id)
 
