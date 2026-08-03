extends Node

const SafeFile = preload("res://scripts/lib/safe_file.gd")
const SAVE_PATH = "user://savegame.json"
var save_path: String = SAVE_PATH


func save(state: Dictionary) -> bool:
	var result := SafeFile.write_json(save_path, state)
	if not result.get("ok", false):
		push_error("SaveManager: " + result.get("error", "Unknown save error."))
	return result.get("ok", false)


func load_save(log_errors: bool = true) -> Dictionary:
	var result := SafeFile.read_json(save_path)
	if not result.get("ok", false):
		if log_errors and result.get("found_invalid", false):
			push_error("SaveManager: " + result.get("error", "Invalid save file."))
		return {}
	if log_errors and result.get("recovered", false):
		push_warning("SaveManager: recovered save from %s%s." % [
			result.get("recovery_source", "backup"),
			"" if result.get("repair_succeeded", false) else " (primary file could not be repaired)"
		])
	return result.get("data", {})


func has_save() -> bool:
	return SafeFile.has_recoverable_file(save_path, SafeFile.Validation.JSON_DICTIONARY)


func delete_save() -> void:
	var result := SafeFile.delete_with_recovery_files(save_path)
	if not result.get("ok", false):
		push_error("SaveManager: " + result.get("error", "Failed to delete save."))
