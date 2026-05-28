extends Node

const DIALOGUE_PATH = "res://dialogue.json"

var _scenes: Dictionary = {}
var _contacts: Array = []
# Clé : scene_id déclencheur → Array de scene_id à jouer après
var _triggers: Dictionary = {}

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

	# Contacts — optionnel pour la compatibilité descendante
	if data.has("contacts"):
		_contacts = data["contacts"]

	# Scènes
	for scene in data["scenes"]:
		# contact_id par défaut = premier contact (le principal)
		if not scene.has("contact_id"):
			scene["contact_id"] = _get_main_contact_id()
		_scenes[scene["id"]] = scene

		# Index des triggers
		var trigger = scene.get("trigger_after_scene", null)
		if trigger != null:
			if not _triggers.has(trigger):
				_triggers[trigger] = []
			_triggers[trigger].append(scene["id"])

	print("DialogueLoader: %d scènes, %d contacts chargés." % [_scenes.size(), _contacts.size()])

# --- Scènes ---

func get_scene(id: String) -> Dictionary:
	return _scenes.get(id, {})

func has_scene(id: String) -> bool:
	return _scenes.has(id)

# Retourne les scènes secondaires à déclencher après scene_id
func get_triggered_scenes(scene_id: String) -> Array:
	return _triggers.get(scene_id, [])

# --- Contacts ---

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

func _get_main_contact_id() -> String:
	var main = get_main_contact()
	return main.get("id", "maeve")
