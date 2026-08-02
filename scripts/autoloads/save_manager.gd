extends Node

const SAVE_PATH = "user://savegame.json"
var save_path: String = SAVE_PATH

func save(state: Dictionary) -> void:
	var tmp_path: String = save_path + ".tmp"
	var file: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: cannot open temp save file for writing (code %d)." % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(state))
	file.close()
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	var dir: DirAccess = DirAccess.open(save_path.get_base_dir())
	if dir == null:
		push_error("SaveManager: cannot access user:// to finalize save.")
		return
	var err: Error = dir.rename(tmp_path.get_file(), save_path.get_file())
	if err != OK:
		push_error("SaveManager: failed to finalize save file (code %d)." % err)

func load_save(log_errors: bool = true) -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return {}
	var file = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		if log_errors:
			push_error("SaveManager: cannot open save file for reading (code %d)." % FileAccess.get_open_error())
		return {}
	var text = file.get_as_text()
	file.close()
	var json = JSON.new()
	if json.parse(text) != OK:
		if log_errors:
			push_error("SaveManager: corrupted save file (line %d) — ignored." % json.get_error_line())
		return {}
	var data = json.get_data()
	if not data is Dictionary:
		if log_errors:
			push_error("SaveManager: invalid save format — ignored.")
		return {}
	return data

func has_save() -> bool:
	return FileAccess.file_exists(save_path)

func delete_save() -> void:
	if FileAccess.file_exists(save_path):
		var err = DirAccess.remove_absolute(save_path)
		if err != OK:
			push_error("SaveManager: failed to delete save file (code %d)." % err)
