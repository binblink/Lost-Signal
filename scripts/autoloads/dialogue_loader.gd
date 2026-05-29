extends Node

const STORY_PATH    = "res://story.json"
const DIALOGUES_DIR = "res://dialogues/"

var _scenes:      Dictionary = {}
var _contacts:    Array      = []
var _start_scene: String     = "scene_01"
var _triggers:    Dictionary = {}

func _ready() -> void:
	_load_story()
	_load_dialogues_dir()
	print("DialogueLoader: %d scènes, %d contacts chargés." % [_scenes.size(), _contacts.size()])

# ---------------------------------------------------------------------------

func _load_story() -> void:
	var data = _parse_json(STORY_PATH)
	if data.is_empty():
		return
	if data.has("start_scene"):
		_start_scene = data["start_scene"]
	if data.has("contacts"):
		_contacts = data["contacts"]

func _load_dialogues_dir() -> void:
	var dir = DirAccess.open(DIALOGUES_DIR)
	if dir == null:
		push_error("DialogueLoader: dossier introuvable → " + DIALOGUES_DIR)
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			_load_scenes_from(DIALOGUES_DIR + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

func _load_scenes_from(path: String) -> void:
	var data = _parse_json(path)
	if data.is_empty() or not data.has("scenes"):
		return
	for scene in data["scenes"]:
		if not scene.has("contact_id"):
			scene["contact_id"] = _get_main_contact_id()
		if _scenes.has(scene["id"]):
			push_warning("DialogueLoader: ID en double « %s » dans %s — ignoré." % [scene["id"], path])
			continue
		_scenes[scene["id"]] = scene
		var trigger = scene.get("trigger_after_scene", null)
		if trigger != null:
			if not _triggers.has(trigger):
				_triggers[trigger] = []
			_triggers[trigger].append(scene["id"])

func _parse_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("DialogueLoader: fichier introuvable → " + path)
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	var json  = JSON.new()
	var err   = json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_error("DialogueLoader: erreur JSON dans %s ligne %d : %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	return json.get_data()

# --- API publique ---

func get_start_scene() -> String:
	return _start_scene

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

func _get_main_contact_id() -> String:
	return get_main_contact().get("id", "")
