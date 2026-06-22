extends Node

const SAVE_PATH = "user://savegame.json"

func save(state: Dictionary) -> void:
	var tmp_path: String = SAVE_PATH + ".tmp"
	var file: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: cannot open temp save file for writing (code %d)." % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(state))
	file.close()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		push_error("SaveManager: cannot access user:// to finalize save.")
		return
	var err: Error = dir.rename("savegame.json.tmp", "savegame.json")
	if err != OK:
		push_error("SaveManager: failed to finalize save file (code %d)." % err)

func load_save() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveManager: cannot open save file for reading (code %d)." % FileAccess.get_open_error())
		return {}
	var text = file.get_as_text()
	file.close()
	var json = JSON.new()
	if json.parse(text) != OK:
		push_error("SaveManager: corrupted save file (line %d) — ignored." % json.get_error_line())
		return {}
	var data = json.get_data()
	if not data is Dictionary:
		push_error("SaveManager: invalid save format — ignored.")
		return {}
	return data

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var err = DirAccess.remove_absolute(SAVE_PATH)
		if err != OK:
			push_error("SaveManager: failed to delete save file (code %d)." % err)
