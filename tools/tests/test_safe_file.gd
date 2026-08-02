extends Node

const SafeFile = preload("res://scripts/lib/safe_file.gd")
const Assert = preload("res://tools/tests/test_assertions.gd")


func run_tests() -> Array:
	var results: Array = []
	var root := "user://safe-file-test-%d" % Time.get_ticks_usec()
	var path := root.path_join("state.json")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root))

	var first := SafeFile.write_json(path, {"version": 1})
	Assert.check(results, "safe file: initial transactional write succeeds", first.get("ok", false), first.get("error", ""))
	Assert.equal(results, "safe file: initial content is readable", _read_json_raw(path).get("version"), 1)

	SafeFile.write_json(path, {"version": 2})
	SafeFile.write_json(path, {"version": 3})
	Assert.equal(results, "safe file: newest content replaces target", _read_json_raw(path).get("version"), 3)
	Assert.equal(results, "safe file: immediate backup keeps previous version", _read_json_raw(path + ".bak").get("version"), 2)
	Assert.equal(results, "safe file: backup history keeps older version", _read_json_raw(path + ".bak.2").get("version"), 1)

	var rejected := SafeFile.write_text(path, "{broken", SafeFile.Validation.JSON_DICTIONARY)
	Assert.check(results, "safe file: invalid replacement is rejected", not rejected.get("ok", true))
	Assert.equal(results, "safe file: rejected replacement preserves target", _read_json_raw(path).get("version"), 3)

	_write_raw(path + ".tmp", JSON.stringify({"version": 4}))
	var interrupted := SafeFile.read_json(path)
	Assert.check(results, "safe file: interrupted valid temp is recovered", interrupted.get("recovered", false))
	Assert.check(results, "safe file: interrupted recovery repairs target", interrupted.get("repair_succeeded", false), interrupted.get("error", ""))
	Assert.equal(results, "safe file: recovered temp becomes current data", interrupted.get("data", {}).get("version"), 4)
	Assert.equal(results, "safe file: repaired target contains recovered temp", _read_json_raw(path).get("version"), 4)
	Assert.equal(results, "safe file: backup rotation is capped at three versions", _read_json_raw(path + ".bak.3").get("version"), 1)

	_write_raw(path, "not json")
	var backup_recovery := SafeFile.read_json(path)
	Assert.check(results, "safe file: corrupt target recovers from backup", backup_recovery.get("recovered", false))
	Assert.equal(results, "safe file: backup recovery returns last valid version", backup_recovery.get("data", {}).get("version"), 3)
	Assert.equal(results, "safe file: backup recovery repairs primary file", _read_json_raw(path).get("version"), 3)
	Assert.check(results, "safe file: corrupt primary is quarantined", _has_corrupt_file(root, "state.json.corrupt."))

	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var missing_recovery := SafeFile.read_json(path)
	Assert.check(results, "safe file: missing primary recovers from backup", missing_recovery.get("recovered", false))
	Assert.equal(results, "safe file: missing primary is recreated", _read_json_raw(path).get("version"), 3)

	_write_raw(path + ".tmp", "invalid temp")
	var invalid_temp := SafeFile.read_json(path)
	Assert.check(results, "safe file: invalid temp does not replace valid target", not invalid_temp.get("recovered", true))
	Assert.equal(results, "safe file: valid target survives invalid temp", invalid_temp.get("data", {}).get("version"), 3)

	var csv_path := root.path_join("ui.csv")
	var invalid_csv := SafeFile.write_text(csv_path, "bad,header\n", SafeFile.Validation.TRANSLATION_CSV)
	Assert.check(results, "safe file: invalid translation CSV is rejected", not invalid_csv.get("ok", true))
	var malformed_csv := SafeFile.write_text(csv_path, "keys,en\nHELLO\n", SafeFile.Validation.TRANSLATION_CSV)
	Assert.check(results, "safe file: inconsistent translation CSV is rejected", not malformed_csv.get("ok", true))
	var unclosed_csv := SafeFile.write_text(csv_path, "keys,en\nHELLO,\"Hello\n", SafeFile.Validation.TRANSLATION_CSV)
	Assert.check(results, "safe file: unclosed CSV field is rejected", not unclosed_csv.get("ok", true))
	var valid_csv := SafeFile.write_text(csv_path, "keys,en,fr\nHELLO,Hello,Bonjour\n", SafeFile.Validation.TRANSLATION_CSV)
	Assert.check(results, "safe file: valid translation CSV is accepted", valid_csv.get("ok", false), valid_csv.get("error", ""))
	var parsed_csv := SafeFile.read_csv(csv_path)
	var parsed_rows: Array = parsed_csv.get("rows", [])
	Assert.check(results, "safe file: translation CSV exposes parsed rows", parsed_rows.size() == 2)
	if parsed_rows.size() == 2:
		Assert.equal(results, "safe file: translation CSV rows are parsed", parsed_rows[1], PackedStringArray(["HELLO", "Hello", "Bonjour"]))
	var project_csv := SafeFile.read_text("res://translations/ui.csv", SafeFile.Validation.TRANSLATION_CSV)
	Assert.check(results, "safe file: project translation CSV passes structural validation", project_csv.get("ok", false), project_csv.get("error", ""))

	var deleted := SafeFile.delete_with_recovery_files(path)
	Assert.check(results, "safe file: delete removes primary and recovery files", deleted.get("ok", false), deleted.get("error", ""))
	Assert.check(results, "safe file: deleted family is not recoverable", not SafeFile.has_recoverable_file(path, SafeFile.Validation.JSON_DICTIONARY))
	Assert.check(results, "safe file: delete removes quarantined transaction files", not _has_file_prefix(root, "state.json"))

	var orphan_path := root.path_join("orphan.json")
	_write_raw(orphan_path, "{broken")
	var orphan := SafeFile.read_json(orphan_path)
	Assert.check(results, "safe file: unrecoverable corrupt primary is rejected", not orphan.get("ok", true))
	Assert.check(results, "safe file: unrecoverable corrupt primary is quarantined", not FileAccess.file_exists(orphan_path) and _has_corrupt_file(root, "orphan.json.corrupt."))

	_remove_tree(root)
	return results


func _write_raw(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null, "Unable to write test fixture: " + path)
	file.store_string(content)
	file.close()


func _read_json_raw(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


func _has_corrupt_file(root: String, prefix: String) -> bool:
	var dir := DirAccess.open(root)
	if dir == null:
		return false
	for file_name: String in dir.get_files():
		if file_name.begins_with(prefix):
			return true
	return false


func _has_file_prefix(root: String, prefix: String) -> bool:
	var dir := DirAccess.open(root)
	if dir == null:
		return false
	for file_name: String in dir.get_files():
		if file_name.begins_with(prefix):
			return true
	return false


func _remove_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path.path_join(file_name)))
	dir.list_dir_begin()
	var child := dir.get_next()
	while child != "":
		if dir.current_is_dir() and child != "." and child != "..":
			_remove_tree(path.path_join(child))
		child = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
