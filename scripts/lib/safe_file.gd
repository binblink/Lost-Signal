extends RefCounted

## Transactional file persistence shared by the game and the Story Editor.
##
## A successful write always follows this sequence:
##   1. write and flush `<path>.tmp`;
##   2. validate the temporary content;
##   3. move the previous valid target to `<path>.bak`;
##   4. promote the temporary file;
##   5. restore the previous file if promotion or final validation fails.
##
## Reads automatically finish an interrupted valid `.tmp` transaction, or
## recover a missing/corrupt target from `.bak`. Invalid files are quarantined
## next to the target instead of being silently destroyed.

enum Validation {
	NONE,
	JSON_DICTIONARY,
	TRANSLATION_CSV,
}

const TEMP_SUFFIX := ".tmp"
const BACKUP_SUFFIX := ".bak"
const MAX_BACKUPS := 3


static func write_json(path: String, data: Dictionary, indent: String = "", trailing_newline: bool = false) -> Dictionary:
	var content := JSON.stringify(data, indent)
	if trailing_newline:
		content += "\n"
	return write_text(path, content, Validation.JSON_DICTIONARY)


static func write_text(path: String, content: String, validation: Validation = Validation.NONE) -> Dictionary:
	if not _validate_content(content, validation):
		return _failure("Refusing to write invalid content to '%s'." % path)

	var dir := DirAccess.open(path.get_base_dir())
	if dir == null:
		return _failure("Cannot access directory for '%s' (code %d)." % [path, DirAccess.get_open_error()])

	var temp_path := path + TEMP_SUFFIX
	var temp_file := FileAccess.open(temp_path, FileAccess.WRITE)
	if temp_file == null:
		return _failure("Cannot open temporary file '%s' (code %d)." % [temp_path, FileAccess.get_open_error()])
	temp_file.store_string(content)
	temp_file.flush()
	var write_error := temp_file.get_error()
	temp_file.close()
	if write_error != OK or not _file_matches(temp_path, content, validation):
		_quarantine(temp_path)
		return _failure("Temporary file verification failed for '%s' (code %d)." % [path, write_error])

	var displaced_path := ""
	if FileAccess.file_exists(path):
		if _is_valid_file(path, validation):
			var rotation := _rotate_backups(path)
			if not rotation.get("ok", false):
				return rotation
			displaced_path = _backup_path(path, 1)
		else:
			displaced_path = _corrupt_path(path)
		var displace_error := _rename_file(path, displaced_path)
		if displace_error != OK:
			return _failure("Cannot preserve previous file '%s' (code %d)." % [path, displace_error])

	var promote_error := _rename_file(temp_path, path)
	if promote_error != OK:
		var rolled_back := _restore_displaced(path, displaced_path)
		return _failure(
			"Cannot finalize '%s' (code %d, rollback %s)." % [
				path, promote_error, "succeeded" if rolled_back else "failed"
			],
			rolled_back
		)

	if not _file_matches(path, content, validation):
		var invalid_final := _corrupt_path(path)
		_rename_file(path, invalid_final)
		var restored := _restore_displaced(path, displaced_path)
		return _failure(
			"Final validation failed for '%s' (rollback %s)." % [
				path, "succeeded" if restored else "failed"
			],
			restored
		)

	return {
		"ok": true,
		"error": "",
		"backup_path": _backup_path(path, 1) if FileAccess.file_exists(_backup_path(path, 1)) else "",
		"rollback_succeeded": true,
	}


static func read_json(path: String) -> Dictionary:
	var result := read_text(path, Validation.JSON_DICTIONARY)
	if not result.get("ok", false):
		result["data"] = {}
		return result
	var json := JSON.new()
	if json.parse(result.get("text", "")) != OK or not json.data is Dictionary:
		return {
			"ok": false,
			"data": {},
			"error": "Recovered content for '%s' could not be parsed." % path,
			"recovered": result.get("recovered", false),
			"repair_succeeded": result.get("repair_succeeded", false),
		}
	result["data"] = json.data
	return result


static func read_csv(path: String) -> Dictionary:
	var result := read_text(path, Validation.TRANSLATION_CSV)
	if not result.get("ok", false):
		result["rows"] = []
		return result
	var parsed := _parse_translation_csv(result.get("text", ""))
	if not parsed.get("ok", false):
		result["ok"] = false
		result["rows"] = []
		result["error"] = "Recovered CSV content for '%s' could not be parsed." % path
		return result
	result["rows"] = parsed.get("rows", [])
	return result


static func read_text(path: String, validation: Validation = Validation.NONE) -> Dictionary:
	var temp_path := path + TEMP_SUFFIX
	var found_invalid := false
	if _is_valid_file(temp_path, validation):
		return _recover_from(path, temp_path, validation)
	if FileAccess.file_exists(temp_path):
		found_invalid = true
		_quarantine(temp_path)

	if _is_valid_file(path, validation):
		var read_result := _read_file(path)
		if not read_result.get("ok", false):
			return read_result
		read_result["recovered"] = false
		read_result["recovery_source"] = ""
		read_result["repair_succeeded"] = true
		return read_result

	for backup_index in range(1, MAX_BACKUPS + 1):
		var backup_path := _backup_path(path, backup_index)
		if _is_valid_file(backup_path, validation):
			return _recover_from(path, backup_path, validation)
		found_invalid = found_invalid or FileAccess.file_exists(backup_path)

	var quarantined_path := ""
	if FileAccess.file_exists(path):
		found_invalid = true
		quarantined_path = _quarantine(path)

	return {
		"ok": false,
		"text": "",
		"error": "No valid primary, temporary, or backup file for '%s'." % path,
		"recovered": false,
		"recovery_source": "",
		"repair_succeeded": false,
		"found_invalid": found_invalid,
		"quarantined_path": quarantined_path,
	}


static func has_recoverable_file(path: String, validation: Validation = Validation.NONE) -> bool:
	if _is_valid_file(path + TEMP_SUFFIX, validation) or _is_valid_file(path, validation):
		return true
	for backup_index in range(1, MAX_BACKUPS + 1):
		if _is_valid_file(_backup_path(path, backup_index), validation):
			return true
	return false


static func delete_with_recovery_files(path: String) -> Dictionary:
	var errors: Array[String] = []
	var candidates: Array[String] = [path, path + TEMP_SUFFIX]
	for backup_index in range(1, MAX_BACKUPS + 1):
		candidates.append(_backup_path(path, backup_index))
	for candidate: String in candidates:
		var error := _remove_file(candidate)
		if error != OK:
			errors.append("%s (code %d)" % [candidate, error])

	var dir := DirAccess.open(path.get_base_dir())
	if dir != null:
		var corrupt_prefixes: Array[String] = [
			path.get_file() + ".corrupt.",
			path.get_file() + TEMP_SUFFIX + ".corrupt.",
		]
		for file_name: String in dir.get_files():
			if corrupt_prefixes.any(func(prefix: String) -> bool: return file_name.begins_with(prefix)):
				var error := dir.remove(file_name)
				if error != OK:
					errors.append("%s (code %d)" % [file_name, error])
	return {
		"ok": errors.is_empty(),
		"error": "" if errors.is_empty() else "Failed to delete: " + ", ".join(errors),
	}


static func _recover_from(path: String, source_path: String, validation: Validation) -> Dictionary:
	var source := _read_file(source_path)
	if not source.get("ok", false):
		return source
	var content: String = source.get("text", "")
	var repair := write_text(path, content, validation)
	return {
		"ok": true,
		"text": content,
		"error": "" if repair.get("ok", false) else repair.get("error", "Recovery repair failed."),
		"recovered": true,
		"recovery_source": source_path,
		"repair_succeeded": repair.get("ok", false),
	}


static func _read_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure("Cannot read '%s' (code %d)." % [path, FileAccess.get_open_error()])
	var content := file.get_as_text()
	file.close()
	return {"ok": true, "text": content, "error": ""}


static func _is_valid_file(path: String, validation: Validation) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var result := _read_file(path)
	return result.get("ok", false) and _validate_content(result.get("text", ""), validation)


static func _file_matches(path: String, expected_content: String, validation: Validation) -> bool:
	var result := _read_file(path)
	if not result.get("ok", false):
		return false
	var actual_content: String = result.get("text", "")
	return actual_content == expected_content and _validate_content(actual_content, validation)


static func _validate_content(content: String, validation: Validation) -> bool:
	match validation:
		Validation.NONE:
			return true
		Validation.JSON_DICTIONARY:
			var json := JSON.new()
			return json.parse(content) == OK and json.data is Dictionary
		Validation.TRANSLATION_CSV:
			return _parse_translation_csv(content).get("ok", false)
	return false


static func _parse_translation_csv(content: String) -> Dictionary:
	var text := content.trim_prefix("\ufeff")
	var rows: Array[PackedStringArray] = []
	var row := PackedStringArray()
	var field := ""
	var in_quotes := false
	var field_started := false
	var index := 0
	while index < text.length():
		var character := text[index]
		if character == "\"":
			if in_quotes and index + 1 < text.length() and text[index + 1] == "\"":
				field += "\""
				index += 2
				continue
			if field_started and not in_quotes:
				return {"ok": false, "rows": []}
			in_quotes = not in_quotes
			field_started = true
		elif not in_quotes and character == ",":
			row.append(field)
			field = ""
			field_started = false
		elif not in_quotes and (character == "\n" or character == "\r"):
			row.append(field)
			if not (row.size() == 1 and row[0].is_empty()):
				rows.append(row)
			row = PackedStringArray()
			field = ""
			field_started = false
			if character == "\r" and index + 1 < text.length() and text[index + 1] == "\n":
				index += 1
		else:
			field += character
			field_started = true
		index += 1
	if in_quotes:
		return {"ok": false, "rows": []}
	if field_started or not row.is_empty():
		row.append(field)
		rows.append(row)
	if rows.is_empty() or rows[0].is_empty() or rows[0][0] != "keys":
		return {"ok": false, "rows": []}
	var column_count := rows[0].size()
	for csv_row: PackedStringArray in rows:
		if csv_row.size() != column_count:
			return {"ok": false, "rows": []}
	return {"ok": true, "rows": rows}


static func _remove_file(path: String) -> Error:
	if not FileAccess.file_exists(path):
		return OK
	return DirAccess.remove_absolute(path)


static func _rotate_backups(path: String) -> Dictionary:
	var oldest_path := _backup_path(path, MAX_BACKUPS)
	var remove_error := _remove_file(oldest_path)
	if remove_error != OK:
		return _failure("Cannot remove oldest backup '%s' (code %d)." % [oldest_path, remove_error])
	for backup_index in range(MAX_BACKUPS - 1, 0, -1):
		var source := _backup_path(path, backup_index)
		if not FileAccess.file_exists(source):
			continue
		var destination := _backup_path(path, backup_index + 1)
		var rename_error := _rename_file(source, destination)
		if rename_error != OK:
			return _failure("Cannot rotate backup '%s' (code %d)." % [source, rename_error])
	return {"ok": true, "error": "", "rollback_succeeded": true}


static func _backup_path(path: String, index: int) -> String:
	return path + BACKUP_SUFFIX if index == 1 else "%s%s.%d" % [path, BACKUP_SUFFIX, index]


static func _rename_file(from_path: String, to_path: String) -> Error:
	var dir := DirAccess.open(from_path.get_base_dir())
	if dir == null or from_path.get_base_dir() != to_path.get_base_dir():
		return ERR_CANT_OPEN
	return dir.rename(from_path.get_file(), to_path.get_file())


static func _restore_displaced(path: String, displaced_path: String) -> bool:
	if displaced_path.is_empty() or FileAccess.file_exists(path) or not FileAccess.file_exists(displaced_path):
		return displaced_path.is_empty() or FileAccess.file_exists(path)
	return _rename_file(displaced_path, path) == OK


static func _quarantine(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var destination := _corrupt_path(path)
	return destination if _rename_file(path, destination) == OK else ""


static func _corrupt_path(path: String) -> String:
	var timestamp := int(Time.get_unix_time_from_system())
	var candidate := "%s.corrupt.%d" % [path, timestamp]
	var suffix := 2
	while FileAccess.file_exists(candidate):
		candidate = "%s.corrupt.%d.%d" % [path, timestamp, suffix]
		suffix += 1
	return candidate


static func _failure(error: String, rollback_succeeded: bool = false) -> Dictionary:
	return {
		"ok": false,
		"error": error,
		"rollback_succeeded": rollback_succeeded,
	}
