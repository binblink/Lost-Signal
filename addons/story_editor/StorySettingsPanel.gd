@tool
extends "res://addons/story_editor/StoryPanelBase.gd"

const LanguageSetupWizard = preload("res://addons/story_editor/LanguageSetupWizard.gd")
const LanguageRemovalWizard = preload("res://addons/story_editor/LanguageRemovalWizard.gd")
const RecoveryCleanupWizard = preload("res://addons/story_editor/RecoveryCleanupWizard.gd")
const SceneParser = preload("res://addons/story_editor/scene_parser.gd")

var language_csv_path: String = CSV_PATH
var language_story_path: String = STORY_PATH
var language_dialogues_dir: String = "res://dialogues"
var language_translations_dir: String = "res://translations"
var recovery_root_path: String = "res://"
var _language_wizard: Window = null
var _language_removal_wizard: Window = null
var _recovery_cleanup_wizard: Window = null


func refresh() -> void:
	if _content == null:
		return
	for child in _content.get_children():
		child.queue_free()
	var data := _read_story()
	_build_global(data)
	_build_timing()
	_build_languages()
	_build_recovery_cleanup()
	_build_end_screen(data)


# ---------------------------------------------------------------------------
# UI — global fields

func _build_global(data: Dictionary) -> void:
	_section(_content, _t("Paramètres globaux", "Global settings"), Color(0.10, 0.14, 0.22))

	_line_edit(_content, _t("Titre", "Title"),
		str(data.get("title", "")),
		_t("ex : Maeve // Lost Signal", "e.g. Maeve // Lost Signal"),
		func(val: String) -> void:
			var d := _read_story()
			if val.is_empty(): d.erase("title") else: d["title"] = val
			_write_story(d),
		_t("Titre affiché dans les menus et la barre de titre de la fenêtre.",
			"Title shown in menus and the window title bar."))

	var scene_ids: Array = get_scene_ids.call()
	scene_ids.sort()
	_dropdown(_content, _t("Scène de départ", "Start scene"),
		str(data.get("start_scene", "")), scene_ids, _t("(aucune)", "(none)"),
		func(val: String) -> void:
			var d := _read_story()
			if val.is_empty(): d.erase("start_scene") else: d["start_scene"] = val
			_write_story(d),
		_t("Première scène jouée au lancement d'une nouvelle partie.",
			"First scene played when starting a new game."))

	var music_row := HBoxContainer.new()
	_label(music_row, _t("Musique menu", "Menu music"), 110)
	var music_edit := LineEdit.new()
	music_edit.text = str(data.get("menu_music", ""))
	music_edit.placeholder_text = "res://assets/music/…"
	music_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_edit.tooltip_text = _t(
		"Chemin vers le fichier audio joué en boucle dans le menu principal.\nLaisser vide pour aucune musique.",
		"Path to the audio file looped in the main menu.\nLeave empty for no music.")
	var save_music: Callable = func(val: String) -> void:
		var d := _read_story()
		if val.is_empty(): d.erase("menu_music") else: d["menu_music"] = val
		_write_story(d)
	music_edit.focus_exited.connect(func() -> void:
		save_music.call(music_edit.text.strip_edges()))
	music_row.add_child(music_edit)
	var pick_music_btn := Button.new()
	pick_music_btn.text = "…"
	pick_music_btn.custom_minimum_size = Vector2(28, 28)
	pick_music_btn.tooltip_text = _t("Choisir un fichier audio…", "Browse for audio file…")
	pick_music_btn.pressed.connect(func() -> void:
		var dialog := EditorFileDialog.new()
		dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
		dialog.access = EditorFileDialog.ACCESS_RESOURCES
		dialog.filters = PackedStringArray(["*.ogg,*.mp3,*.wav ; Audio"])
		if DirAccess.dir_exists_absolute("res://assets/music"):
			dialog.current_dir = "res://assets/music"
		elif DirAccess.dir_exists_absolute("res://assets"):
			dialog.current_dir = "res://assets"
		get_tree().get_root().add_child(dialog)
		dialog.file_selected.connect(func(path: String) -> void:
			music_edit.text = path
			save_music.call(path)
			dialog.queue_free())
		dialog.canceled.connect(func() -> void: dialog.queue_free())
		dialog.popup_centered(Vector2i(900, 600)))
	music_row.add_child(pick_music_btn)
	_content.add_child(music_row)

	var cids: Array = []
	for c in data.get("contacts", []):
		cids.append(c.get("id", ""))
	_dropdown(_content, _t("Contact de départ", "Start contact"),
		str(data.get("start_contact", "")), cids, _t("(aucun)", "(none)"),
		func(val: String) -> void:
			var d := _read_story()
			if val.is_empty(): d.erase("start_contact") else: d["start_contact"] = val
			_write_story(d),
		_t("Contact affiché à l'écran après la scène de départ.\nSi vide, le contact principal est montré par défaut.",
			"Contact shown on screen after the start scene.\nIf empty, the main contact is shown by default."))


# ---------------------------------------------------------------------------
# UI — typing speed

func _build_timing() -> void:
	var theme_data := _read_theme()
	_section(_content, _t("Vitesse de frappe", "Typing speed"), Color(0.10, 0.16, 0.20))

	_spinbox(_content,
		_t("Contacts", "Contacts"),
		float(theme_data.get("contact_typing_speed", 0.08)),
		0.01, 0.50, 0.01,
		func(val: float) -> void:
			var d := _read_theme()
			d["contact_typing_speed"] = val
			_write_theme(d),
		_t("Délai par caractère pour l'indicateur '…' des contacts (secondes). Défaut : 0.08",
			"Per-character delay for the contact '…' indicator (seconds). Default: 0.08"))

	_spinbox(_content,
		_t("Joueur", "Player"),
		float(theme_data.get("player_typing_speed", 0.05)),
		0.01, 0.50, 0.01,
		func(val: float) -> void:
			var d := _read_theme()
			d["player_typing_speed"] = val
			_write_theme(d),
		_t("Délai par caractère lors de la frappe du joueur (secondes). Défaut : 0.05",
			"Per-character delay for player message typing (seconds). Default: 0.05"))


# ---------------------------------------------------------------------------
# UI — language management

func _build_languages() -> void:
	_section(_content, _t("Langues", "Languages"), Color(0.10, 0.18, 0.14))

	var locales := _get_language_locales()
	var default_locale := SceneParser._read_base_locale(language_story_path)

	var chips_row := HBoxContainer.new()
	chips_row.add_theme_constant_override("separation", 6)
	for locale: String in locales:
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 2)
		var lbl := Label.new()
		lbl.text = "%s (%s)" % [locale, _t("défaut", "default")] if locale == default_locale else locale
		lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 0.75))
		chip.add_child(lbl)
		var rm := Button.new()
		rm.text = "×"
		rm.flat = true
		rm.disabled = locales.size() <= 1 or locale == default_locale
		if locale == default_locale:
			rm.tooltip_text = _t(
				"Langue par défaut protégée. Choisissez d’abord une autre langue par défaut.",
				"Protected default language. Choose another default language first.")
		else:
			rm.tooltip_text = _t(
				"Choisir entre retirer la langue du jeu ou supprimer tous ses contenus localisés.",
				"Choose between removing the language from the game or deleting all localized content.")
		var captured: String = locale
		rm.pressed.connect(func() -> void: _open_language_removal_wizard(captured))
		chip.add_child(rm)
		chips_row.add_child(chip)
	_content.add_child(chips_row)

	var add_btn := Button.new()
	add_btn.name = "OpenLanguageWizardButton"
	add_btn.text = _t("+ Ajouter une langue…", "+ Add a language…")
	add_btn.tooltip_text = _t(
		"Ouvre un assistant qui prépare l’interface, les dialogues et les champs localisés.",
		"Opens a wizard that prepares the interface, dialogues, and localized fields.")
	add_btn.pressed.connect(func() -> void: _open_language_wizard(locales))
	_content.add_child(add_btn)


func _build_recovery_cleanup() -> void:
	_section(_content, _t("Maintenance des fichiers", "File maintenance"), Color(0.18, 0.13, 0.10))
	var explanation := Label.new()
	explanation.text = _t(
		"Supprime définitivement les anciennes sauvegardes et archives après vérification de leur liste exacte.",
		"Permanently deletes old backups and archives after reviewing their exact list."
	)
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(explanation)
	var cleanup := Button.new()
	cleanup.name = "OpenRecoveryCleanupButton"
	cleanup.text = _t("Nettoyer les fichiers de récupération…", "Clean recovery files…")
	cleanup.tooltip_text = _t(
		"Recherche les .bak et .removed.* dans le projet. Les sauvegardes de parties ne sont pas concernées.",
		"Finds .bak and .removed.* files in the project. Game-save backups are not affected."
	)
	cleanup.pressed.connect(_open_recovery_cleanup_wizard)
	_content.add_child(cleanup)


func _open_recovery_cleanup_wizard() -> void:
	if _recovery_cleanup_wizard != null and is_instance_valid(_recovery_cleanup_wizard):
		_recovery_cleanup_wizard.popup_centered()
		return
	var wizard := RecoveryCleanupWizard.new()
	_recovery_cleanup_wizard = wizard
	wizard.configure(_build_recovery_cleanup_plan, _apply_recovery_cleanup, ui_locale)
	wizard.finished.connect(func(_result: Dictionary) -> void: _recovery_cleanup_wizard = null)
	wizard.tree_exited.connect(func() -> void: _recovery_cleanup_wizard = null)
	add_child(wizard)
	wizard.popup_centered()


func _build_recovery_cleanup_plan(include_backups: bool, include_removed: bool) -> Dictionary:
	var entries: Array[Dictionary] = []
	var primary_validation_cache: Dictionary = {}
	_scan_recovery_directory(recovery_root_path, include_backups, include_removed, entries, primary_validation_cache)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["path"]) < str(b["path"]))
	return {"ok": true, "entries": entries}


func _scan_recovery_directory(
		path: String,
		include_backups: bool,
		include_removed: bool,
		entries: Array[Dictionary],
		primary_validation_cache: Dictionary
	) -> void:
	const EXCLUDED_DIRECTORIES := [".git", ".godot", ".agents", ".codex", ".vscode", "build", "dist", "export", "exports"]
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for directory_name: String in directory.get_directories():
		if directory_name in EXCLUDED_DIRECTORIES:
			continue
		_scan_recovery_directory(path.path_join(directory_name), include_backups, include_removed, entries, primary_validation_cache)
	for file_name: String in directory.get_files():
		var kind := _recovery_file_kind(file_name)
		if kind.is_empty() or (kind == "backup" and not include_backups) or (kind == "removed" and not include_removed):
			continue
		var file_path := path.path_join(file_name)
		var protected := false
		var reason := ""
		if kind == "backup":
			var primary_path := _primary_path_for_backup(file_path)
			if not primary_validation_cache.has(primary_path):
				primary_validation_cache[primary_path] = _is_primary_recovery_target_usable(primary_path)
			protected = primary_path.is_empty() or not bool(primary_validation_cache[primary_path])
			if protected:
				reason = _t(
					"Protégé : le fichier principal est absent ou invalide ; cette sauvegarde peut être la dernière copie récupérable.",
					"Protected: the primary file is missing or invalid; this backup may be the last recoverable copy."
				)
		var file := FileAccess.open(file_path, FileAccess.READ)
		var size := file.get_length() if file != null else 0
		entries.append({
			"path": file_path,
			"kind": kind,
			"size": size,
			"protected": protected,
			"reason": reason,
		})


func _recovery_file_kind(file_name: String) -> String:
	if file_name.contains(".removed."):
		return "removed"
	if file_name.ends_with(".bak"):
		return "backup"
	var marker := file_name.rfind(".bak.")
	if marker >= 0 and file_name.substr(marker + 5).is_valid_int():
		return "backup"
	return ""


func _primary_path_for_backup(backup_path: String) -> String:
	if backup_path.ends_with(".bak"):
		return backup_path.trim_suffix(".bak")
	var marker := backup_path.rfind(".bak.")
	if marker >= 0 and backup_path.substr(marker + 5).is_valid_int():
		return backup_path.substr(0, marker)
	return ""


func _is_primary_recovery_target_usable(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	if path.ends_with(".json"):
		var json := JSON.new()
		return json.parse(FileAccess.get_file_as_string(path)) == OK and json.data is Dictionary
	if path.ends_with(".csv"):
		var csv := FileAccess.open(path, FileAccess.READ)
		if csv == null:
			return false
		var header := csv.get_csv_line()
		return header.size() >= 2 and header[0] == "keys"
	return true


func _apply_recovery_cleanup(selected_paths: Array[String]) -> Dictionary:
	if selected_paths.is_empty():
		return {"ok": true, "deleted_paths": [], "deleted_size": 0, "error": ""}
	var current_plan := _build_recovery_cleanup_plan(true, true)
	var allowed: Dictionary = {}
	for entry: Dictionary in current_plan["entries"]:
		if not entry.get("protected", false):
			allowed[entry["path"]] = entry
	for path: String in selected_paths:
		if not allowed.has(path):
			return {
				"ok": false,
				"deleted_paths": [],
				"deleted_size": 0,
				"error": _t(
					"Nettoyage refusé : le fichier n’est plus autorisé ou est désormais protégé : %s" % path,
					"Cleanup refused: the file is no longer allowed or is now protected: %s" % path
				),
			}

	var deleted_paths: Array[String] = []
	var deleted_size := 0
	var failures: Array[String] = []
	for path: String in selected_paths:
		if not FileAccess.file_exists(path):
			continue
		var directory := DirAccess.open(path.get_base_dir())
		var error := ERR_CANT_OPEN
		if directory != null:
			error = directory.remove(path.get_file())
		if error == OK:
			deleted_paths.append(path)
			deleted_size += int((allowed[path] as Dictionary).get("size", 0))
		else:
			failures.append("%s (code %d)" % [path, error])
	return {
		"ok": failures.is_empty(),
		"deleted_paths": deleted_paths,
		"deleted_size": deleted_size,
		"error": "" if failures.is_empty() else _t(
			"Certains fichiers n’ont pas pu être supprimés :\n%s" % "\n".join(failures),
			"Some files could not be deleted:\n%s" % "\n".join(failures)
		),
	}


func _open_language_wizard(locales: Array[String]) -> void:
	if _language_wizard != null and is_instance_valid(_language_wizard):
		_language_wizard.popup_centered()
		return
	var source_locale := SceneParser._read_base_locale(language_story_path)
	if source_locale not in locales:
		source_locale = "en" if "en" in locales else (locales[0] if not locales.is_empty() else "")
	var wizard := LanguageSetupWizard.new()
	_language_wizard = wizard
	wizard.configure(
		locales,
		source_locale,
		_build_language_setup_plan,
		_apply_language_setup_plan,
		ui_locale
	)
	wizard.finished.connect(func(result: Dictionary) -> void:
		_language_wizard = null
		if result.get("ok", false):
			call_deferred("refresh"))
	wizard.tree_exited.connect(func() -> void: _language_wizard = null)
	add_child(wizard)
	wizard.popup_centered()


func _build_language_setup_plan(
		locale: String,
		source_locale: String,
		create_dialogues: bool,
		copy_story_fields: bool
	) -> Dictionary:
	locale = _normalize_language_locale(locale)
	if not _is_valid_language_locale(locale):
		return _language_plan_error(_t("Code de langue invalide.", "Invalid language code."))
	var rows := _read_csv_rows()
	if rows.is_empty():
		return _language_plan_error(_t("translations/ui.csv est vide ou illisible.", "translations/ui.csv is empty or unreadable."))
	var header: PackedStringArray = rows[0]
	if locale in header:
		return _language_plan_error(_t("Cette langue existe déjà.", "This language already exists."))
	var source_index := header.find(source_locale)
	if source_index < 1:
		return _language_plan_error(_t(
			"La langue source '%s' est absente de ui.csv." % source_locale,
			"Source language '%s' is missing from ui.csv." % source_locale
		))

	var csv_result := _extend_language_csv_rows(rows, locale, source_locale)
	if not csv_result.get("ok", false):
		return csv_result

	var dialogue_plan := {
		"copies": [] as Array[Dictionary],
		"existing": [] as Array[String],
	}
	if create_dialogues:
		var all_files := _all_language_dialogue_files()
		dialogue_plan = _build_dialogue_copy_plan(all_files, locale, source_locale)
		for copy: Dictionary in dialogue_plan["copies"]:
			var source_path := language_dialogues_dir.path_join(copy["source"])
			var read_result := SafeFile.read_text(source_path, SafeFile.Validation.JSON_DICTIONARY)
			if not read_result.get("ok", false):
				return _language_plan_error(_t(
					"Impossible de lire le fichier source %s." % copy["source"],
					"Could not read source file %s." % copy["source"]
				))
			copy["content"] = read_result.get("text", "")

	var story_data: Dictionary = {}
	var story_result := {
		"data": story_data,
		"copy_count": 0,
		"missing_source_count": 0,
		"changed": false,
	}
	if copy_story_fields:
		var story_read := SafeFile.read_json(language_story_path)
		if not story_read.get("ok", false):
			return _language_plan_error(_t("story.json est illisible.", "story.json is unreadable."))
		story_result = _copy_story_locale_fields(story_read.get("data", {}), locale, source_locale)

	return {
		"ok": true,
		"error": "",
		"locale": locale,
		"source_locale": source_locale,
		"csv_rows": csv_result["rows"],
		"ui_entry_count": maxi(0, rows.size() - 1),
		"ui_missing_source_count": csv_result.get("missing_source_count", 0),
		"create_dialogues": create_dialogues,
		"dialogue_copies": dialogue_plan["copies"],
		"existing_dialogue_files": dialogue_plan["existing"],
		"copy_story_fields": copy_story_fields,
		"story_data": story_result["data"],
		"story_changed": story_result["changed"],
		"story_copy_count": story_result["copy_count"],
		"story_missing_source_count": story_result["missing_source_count"],
	}


func _apply_language_setup_plan(plan: Dictionary) -> Dictionary:
	if not plan.get("ok", false):
		return plan
	var created_files: Array[String] = []
	for copy: Dictionary in plan.get("dialogue_copies", []):
		var target_name: String = copy["target"]
		var target_path := language_dialogues_dir.path_join(target_name)
		# A file created after the preview is preserved, never overwritten.
		if FileAccess.file_exists(target_path):
			continue
		var write_result := SafeFile.write_text(
			target_path,
			str(copy.get("content", "")),
			SafeFile.Validation.JSON_DICTIONARY
		)
		if not write_result.get("ok", false):
			return _language_apply_error(plan, created_files, _t(
				"Échec de création de %s. La langue n’a pas été ajoutée à ui.csv. Vous pouvez relancer l’assistant sans écraser les fichiers déjà créés.\n%s" % [target_name, write_result.get("error", "")],
				"Could not create %s. The language was not added to ui.csv. You can run the wizard again without overwriting files already created.\n%s" % [target_name, write_result.get("error", "")]
			))
		created_files.append(target_name)

	if plan.get("story_changed", false):
		var story_write := SafeFile.write_text(
			language_story_path,
			JsonUtils.expand(_ordered_story(plan["story_data"]), "") + "\n",
			SafeFile.Validation.JSON_DICTIONARY
		)
		if not story_write.get("ok", false):
			return _language_apply_error(plan, created_files, _t(
				"Échec de mise à jour de story.json. La langue n’a pas été ajoutée à ui.csv.\n%s" % story_write.get("error", ""),
				"Could not update story.json. The language was not added to ui.csv.\n%s" % story_write.get("error", "")
			))

	var csv_write := _write_csv_rows_result(plan["csv_rows"])
	if not csv_write.get("ok", false):
		return _language_apply_error(plan, created_files, _t(
			"Échec de mise à jour de ui.csv. Les fichiers préparés ont été conservés et l’assistant peut être relancé.\n%s" % csv_write.get("error", ""),
			"Could not update ui.csv. Prepared files were kept and the wizard can be run again.\n%s" % csv_write.get("error", "")
		))

	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()
	story_modified.emit()
	var result := plan.duplicate(true)
	result["ok"] = true
	result["created_dialogue_files"] = created_files
	return result


func _language_plan_error(message: String) -> Dictionary:
	return {"ok": false, "error": message}


func _language_apply_error(plan: Dictionary, created_files: Array[String], message: String) -> Dictionary:
	var result := plan.duplicate(true)
	result["ok"] = false
	result["error"] = message
	result["created_dialogue_files"] = created_files
	return result


func _extend_language_csv_rows(
		rows: Array[PackedStringArray],
		locale: String,
		source_locale: String
	) -> Dictionary:
	if rows.is_empty():
		return _language_plan_error("ui.csv is empty.")
	var source_index := rows[0].find(source_locale)
	if source_index < 1:
		return _language_plan_error("Source locale is missing from ui.csv.")
	var extended_rows: Array[PackedStringArray] = []
	var missing_source_count := 0
	for row_index: int in range(rows.size()):
		var row: PackedStringArray = rows[row_index]
		var extended := PackedStringArray(row)
		var initial_value := locale if row_index == 0 else ""
		if row_index > 0:
			if source_index < row.size():
				initial_value = row[source_index]
			if initial_value.is_empty():
				missing_source_count += 1
		extended.append(initial_value)
		extended_rows.append(extended)
	return {
		"ok": true,
		"rows": extended_rows,
		"missing_source_count": missing_source_count,
	}


func _build_dialogue_copy_plan(
		all_files: Array[String],
		locale: String,
		source_locale: String
	) -> Dictionary:
	var groups: Dictionary = {}
	for file_name: String in all_files:
		if not file_name.ends_with(".json"):
			continue
		var parts := file_name.get_basename().split(".")
		if parts.size() < 1 or parts.size() > 2:
			continue
		var basename := str(parts[0])
		if not groups.has(basename):
			groups[basename] = [] as Array[String]
		(groups[basename] as Array[String]).append(file_name)

	var copies: Array[Dictionary] = []
	var existing: Array[String] = []
	var basenames: Array = groups.keys()
	basenames.sort()
	for basename_variant: Variant in basenames:
		var basename := str(basename_variant)
		var files: Array[String] = groups[basename]
		var target := "%s.%s.json" % [basename, locale]
		if target in files:
			existing.append(target)
			continue
		var localized_source := "%s.%s.json" % [basename, source_locale]
		var base_source := "%s.json" % basename
		var source := localized_source if localized_source in files else base_source
		if source not in files:
			continue
		copies.append({"source": source, "target": target})
	return {"copies": copies, "existing": existing}


func _copy_story_locale_fields(data: Dictionary, locale: String, source_locale: String) -> Dictionary:
	var result_data := data.duplicate(true)
	var copy_count := 0
	var missing_source_count := 0

	var end_screen: Dictionary = result_data.get("end_screen", {})
	for key: String in ["title", "text"]:
		if not end_screen.has(key):
			continue
		var localized := _copy_localized_value(end_screen[key], locale, source_locale)
		end_screen[key] = localized["value"]
		copy_count += int(localized["copy_count"])
		missing_source_count += int(localized["missing_source_count"])
	if not end_screen.is_empty():
		result_data["end_screen"] = end_screen

	var contacts: Array = result_data.get("contacts", [])
	for contact_variant: Variant in contacts:
		if not contact_variant is Dictionary:
			continue
		var contact: Dictionary = contact_variant
		if contact.get("names", null) is Dictionary:
			var localized_name := _copy_localized_value(contact["names"], locale, source_locale)
			contact["names"] = localized_name["value"]
			copy_count += int(localized_name["copy_count"])
			missing_source_count += int(localized_name["missing_source_count"])
		var history: Array = contact.get("history", [])
		for entry_variant: Variant in history:
			if not entry_variant is Dictionary:
				continue
			var entry: Dictionary = entry_variant
			if not entry.has("text"):
				continue
			var localized_text := _copy_localized_value(entry["text"], locale, source_locale)
			entry["text"] = localized_text["value"]
			copy_count += int(localized_text["copy_count"])
			missing_source_count += int(localized_text["missing_source_count"])

	return {
		"data": result_data,
		"copy_count": copy_count,
		"missing_source_count": missing_source_count,
		"changed": copy_count > 0,
	}


func _copy_localized_value(value: Variant, locale: String, source_locale: String) -> Dictionary:
	if value is Dictionary:
		var localized: Dictionary = (value as Dictionary).duplicate(true)
		if localized.has(locale):
			return {"value": localized, "copy_count": 0, "missing_source_count": 0}
		if not localized.has(source_locale):
			return {"value": localized, "copy_count": 0, "missing_source_count": 1}
		localized[locale] = localized[source_locale]
		return {"value": localized, "copy_count": 1, "missing_source_count": 0}
	if value is String and not (value as String).is_empty():
		return {
			"value": {source_locale: value, locale: value},
			"copy_count": 1,
			"missing_source_count": 0,
		}
	return {"value": value, "copy_count": 0, "missing_source_count": 0}


func _normalize_language_locale(raw_locale: String) -> String:
	var parts := raw_locale.strip_edges().replace("-", "_").split("_", false)
	if parts.is_empty() or parts.size() > 2:
		return ""
	var result := parts[0].to_lower()
	if parts.size() == 2:
		result += "_" + parts[1].to_upper()
	return result


func _is_valid_language_locale(locale: String) -> bool:
	var regex := RegEx.new()
	regex.compile("^[a-z]{2,3}(_([A-Z]{2}|[0-9]{3}))?$")
	return regex.search(locale) != null


func _all_language_dialogue_files() -> Array[String]:
	var result: Array[String] = []
	var directory := DirAccess.open(language_dialogues_dir)
	if directory == null:
		return result
	for file_name: String in directory.get_files():
		if file_name.ends_with(".json"):
			result.append(file_name)
	result.sort()
	return result


func _get_language_locales() -> Array[String]:
	var result: Array[String] = []
	var csv := SafeFile.read_csv(language_csv_path)
	var rows: Array = csv.get("rows", [])
	if csv.get("ok", false) and not rows.is_empty():
		var header: PackedStringArray = rows[0]
		for column_index: int in range(1, header.size()):
			var locale := header[column_index].strip_edges()
			if not locale.is_empty() and locale not in result:
				result.append(locale)
	result.sort()
	return result if not result.is_empty() else _get_supported_locales()


func _open_language_removal_wizard(locale: String) -> void:
	if _language_removal_wizard != null and is_instance_valid(_language_removal_wizard):
		_language_removal_wizard.popup_centered()
		return
	var wizard := LanguageRemovalWizard.new()
	_language_removal_wizard = wizard
	wizard.configure(
		locale,
		_build_language_removal_plan,
		_apply_language_removal_plan,
		ui_locale
	)
	wizard.finished.connect(func(result: Dictionary) -> void:
		_language_removal_wizard = null
		if result.get("ok", false):
			call_deferred("refresh"))
	wizard.tree_exited.connect(func() -> void: _language_removal_wizard = null)
	add_child(wizard)
	wizard.popup_centered()


func _build_language_removal_plan(locale: String, full_delete: bool) -> Dictionary:
	var rows := _read_csv_rows()
	if rows.is_empty():
		return _language_plan_error(_t("translations/ui.csv est vide ou illisible.", "translations/ui.csv is empty or unreadable."))
	var header: PackedStringArray = rows[0]
	var locale_column := header.find(locale)
	if locale_column < 1:
		return _language_plan_error(_t("Cette langue n’existe pas dans ui.csv.", "This language does not exist in ui.csv."))
	if header.size() <= 2:
		return _language_plan_error(_t("Impossible de supprimer la dernière langue.", "The last language cannot be removed."))
	var default_locale := SceneParser._read_base_locale(language_story_path)
	if locale == default_locale:
		return _language_plan_error(_t(
			"La langue par défaut est protégée. Choisissez d’abord une autre langue par défaut.",
			"The default language is protected. Choose another default language first."
		))

	var trimmed_rows: Array[PackedStringArray] = []
	for row: PackedStringArray in rows:
		var trimmed := PackedStringArray()
		for index: int in range(row.size()):
			if index != locale_column:
				trimmed.append(row[index])
		trimmed_rows.append(trimmed)

	var files_to_archive: Array[String] = []
	var story_data: Dictionary = {}
	var story_removal_count := 0
	var story_changed := false
	if full_delete:
		for file_name: String in _find_locale_dialogue_files(_all_language_dialogue_files(), locale):
			files_to_archive.append(language_dialogues_dir.path_join(file_name))
		var translation_path := language_translations_dir.path_join("ui.%s.translation" % locale)
		if FileAccess.file_exists(translation_path):
			files_to_archive.append(translation_path)
		var story_read := SafeFile.read_json(language_story_path)
		if not story_read.get("ok", false):
			return _language_plan_error(_t("story.json est illisible.", "story.json is unreadable."))
		var story_result := _remove_story_locale_fields(story_read.get("data", {}), locale)
		story_data = story_result["data"]
		story_removal_count = story_result["removal_count"]
		story_changed = story_result["changed"]

	return {
		"ok": true,
		"error": "",
		"locale": locale,
		"full_delete": full_delete,
		"csv_rows": trimmed_rows,
		"files_to_archive": files_to_archive,
		"story_data": story_data,
		"story_removal_count": story_removal_count,
		"story_changed": story_changed,
	}


func _apply_language_removal_plan(plan: Dictionary) -> Dictionary:
	if not plan.get("ok", false):
		return plan
	var archived_files: Array[String] = []
	if plan.get("full_delete", false):
		var archive_token := "%d" % Time.get_unix_time_from_system()
		for path: String in plan.get("files_to_archive", []):
			# Rebuilds the plan at confirmation, but still tolerate a file removed
			# externally before this loop.
			if not FileAccess.file_exists(path):
				continue
			var archive_result := _archive_language_file_group(path, archive_token)
			if not archive_result.get("ok", false):
				return _language_removal_error(plan, archived_files, _t(
					"Impossible d’archiver %s. ui.csv n’a pas été modifié ; relancez l’assistant pour terminer.\n%s" % [path, archive_result.get("error", "")],
					"Could not archive %s. ui.csv was not changed; run the wizard again to finish.\n%s" % [path, archive_result.get("error", "")]
				))
			archived_files.append_array(archive_result.get("archived_paths", []))

		if plan.get("story_changed", false):
			var story_write := SafeFile.write_text(
				language_story_path,
				JsonUtils.expand(_ordered_story(plan["story_data"]), "") + "\n",
				SafeFile.Validation.JSON_DICTIONARY
			)
			if not story_write.get("ok", false):
				return _language_removal_error(plan, archived_files, _t(
					"Impossible de nettoyer story.json. ui.csv n’a pas été modifié ; les fichiers archivés restent récupérables.\n%s" % story_write.get("error", ""),
					"Could not clean story.json. ui.csv was not changed; archived files remain recoverable.\n%s" % story_write.get("error", "")
				))

	var csv_write := _write_csv_rows_result(plan["csv_rows"])
	if not csv_write.get("ok", false):
		return _language_removal_error(plan, archived_files, _t(
			"Impossible de mettre à jour ui.csv. Les éléments déjà archivés restent récupérables et l’assistant peut être relancé.\n%s" % csv_write.get("error", ""),
			"Could not update ui.csv. Items already archived remain recoverable and the wizard can be run again.\n%s" % csv_write.get("error", "")
		))

	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()
	story_modified.emit()
	var result := plan.duplicate(true)
	result["ok"] = true
	result["archived_files"] = archived_files
	return result


func _language_removal_error(plan: Dictionary, archived_files: Array[String], message: String) -> Dictionary:
	var result := plan.duplicate(true)
	result["ok"] = false
	result["error"] = message
	result["archived_files"] = archived_files
	return result


func _find_locale_dialogue_files(all_files: Array[String], locale: String) -> Array[String]:
	var result: Array[String] = []
	for file_name: String in all_files:
		var parts := file_name.get_basename().split(".")
		if parts.size() == 2 and parts[1] == locale:
			result.append(file_name)
	result.sort()
	return result


func _remove_story_locale_fields(data: Dictionary, locale: String) -> Dictionary:
	var result_data := data.duplicate(true)
	var removal_count := 0

	var end_screen: Dictionary = result_data.get("end_screen", {})
	for key: String in ["title", "text"]:
		if not end_screen.get(key, null) is Dictionary:
			continue
		var localized: Dictionary = (end_screen[key] as Dictionary).duplicate(true)
		if localized.erase(locale):
			removal_count += 1
			if localized.is_empty():
				end_screen.erase(key)
			else:
				end_screen[key] = localized
	if not end_screen.is_empty():
		result_data["end_screen"] = end_screen

	var contacts: Array = result_data.get("contacts", [])
	for contact_variant: Variant in contacts:
		if not contact_variant is Dictionary:
			continue
		var contact: Dictionary = contact_variant
		if contact.get("names", null) is Dictionary:
			var names: Dictionary = (contact["names"] as Dictionary).duplicate(true)
			if names.erase(locale):
				removal_count += 1
				if names.is_empty():
					contact.erase("names")
				else:
					contact["names"] = names
		var history: Array = contact.get("history", [])
		for entry_variant: Variant in history:
			if not entry_variant is Dictionary:
				continue
			var entry: Dictionary = entry_variant
			if not entry.get("text", null) is Dictionary:
				continue
			var texts: Dictionary = (entry["text"] as Dictionary).duplicate(true)
			if texts.erase(locale):
				removal_count += 1
				entry["text"] = "" if texts.is_empty() else texts

	return {
		"data": result_data,
		"removal_count": removal_count,
		"changed": removal_count > 0,
	}


func _archive_language_file_group(path: String, archive_token: String) -> Dictionary:
	var candidates: Array[String] = [path, path + SafeFile.TEMP_SUFFIX]
	for backup_index: int in range(1, SafeFile.MAX_BACKUPS + 1):
		candidates.append(path + SafeFile.BACKUP_SUFFIX + ("" if backup_index == 1 else ".%d" % backup_index))
	var moves: Array[Dictionary] = []
	for candidate: String in candidates:
		if not FileAccess.file_exists(candidate):
			continue
		var destination := candidate + ".removed." + archive_token
		var suffix := 2
		while FileAccess.file_exists(destination):
			destination = candidate + ".removed.%s.%d" % [archive_token, suffix]
			suffix += 1
		moves.append({"source": candidate, "destination": destination})

	var completed: Array[Dictionary] = []
	for move: Dictionary in moves:
		var directory := DirAccess.open(str(move["source"]).get_base_dir())
		var error := ERR_CANT_OPEN
		if directory != null:
			error = directory.rename(str(move["source"]).get_file(), str(move["destination"]).get_file())
		if error != OK:
			for rollback_index: int in range(completed.size() - 1, -1, -1):
				var rollback: Dictionary = completed[rollback_index]
				var rollback_dir := DirAccess.open(str(rollback["destination"]).get_base_dir())
				if rollback_dir != null:
					rollback_dir.rename(str(rollback["destination"]).get_file(), str(rollback["source"]).get_file())
			return {"ok": false, "error": "Archive rename failed with code %d." % error, "archived_paths": []}
		completed.append(move)

	var archived_paths: Array[String] = []
	for move: Dictionary in completed:
		archived_paths.append(move["destination"])
	return {"ok": true, "error": "", "archived_paths": archived_paths}


func _read_csv_rows() -> Array[PackedStringArray]:
	var recovery := SafeFile.read_csv(language_csv_path)
	if not recovery.get("ok", false):
		push_error("StorySettingsPanel: " + recovery.get("error", "Cannot read ui.csv."))
		return []
	if recovery.get("recovered", false):
		push_warning("StorySettingsPanel: recovered ui.csv from %s." % recovery.get("recovery_source", "backup"))
	var rows: Array[PackedStringArray] = []
	for row: PackedStringArray in recovery.get("rows", []):
		rows.append(row)
	return rows


func _write_csv_rows(rows: Array[PackedStringArray]) -> bool:
	var result := _write_csv_rows_result(rows)
	if not result.get("ok", false):
		var message := result.get("error", "Cannot write ui.csv.")
		push_error("StorySettingsPanel: " + message)
		error_occurred.emit(_t("Erreur écriture : ui.csv", "Write error: ui.csv") + "\n" + message)
	return result.get("ok", false)


func _write_csv_rows_result(rows: Array[PackedStringArray]) -> Dictionary:
	var lines: PackedStringArray = []
	for row: PackedStringArray in rows:
		var encoded: PackedStringArray = []
		for field: String in row:
			encoded.append(_escape_csv_field(field))
		lines.append(",".join(encoded))
	var result := SafeFile.write_text(language_csv_path, "\n".join(lines) + "\n", SafeFile.Validation.TRANSLATION_CSV)
	if result.get("ok", false) and Engine.is_editor_hint() and language_csv_path.begins_with("res://"):
		EditorInterface.get_resource_filesystem().reimport_files(PackedStringArray([language_csv_path]))
	return result


func _escape_csv_field(value: String) -> String:
	if value != value.strip_edges() or value.contains(",") or value.contains("\"") or value.contains("\n") or value.contains("\r"):
		return "\"%s\"" % value.replace("\"", "\"\"")
	return value


# ---------------------------------------------------------------------------
# [END SCREEN]

func _build_end_screen(data: Dictionary) -> void:
	var es: Dictionary = data.get("end_screen", {})
	_section(_content, _t("Écran de fin", "End screen"), Color(0.14, 0.10, 0.20))

	_es_localized_field("title", es.get("title", ""),
		_t("titre", "title"),
		"CONNECTION TERMINATED",
		_t("Texte principal affiché en grand (ex : CONNECTION TERMINATED).",
			"Main text shown large (e.g. CONNECTION TERMINATED)."))

	_es_localized_field("text", es.get("text", ""),
		_t("texte", "text"),
		_t("Message optionnel…", "Optional message…"),
		_t("Texte secondaire affiché sous le titre (accroche, suite à venir, etc.).",
			"Secondary text shown below the title (teaser, coming soon, etc.)."))

	_line_edit(_content,
		_t("lien URL", "link URL"),
		str(es.get("link_url", "")),
		"https://itch.io/…",
		func(val: String) -> void:
			var d := _read_story()
			var block: Dictionary = d.get("end_screen", {})
			if val.is_empty(): block.erase("link_url") else: block["link_url"] = val
			d["end_screen"] = block
			_write_story(d),
		_t("URL ouverte au clic (optionnel). Laisser vide pour ne pas afficher de lien.",
			"URL opened on click (optional). Leave empty to hide the link."))

	_line_edit(_content,
		_t("lien texte", "link label"),
		str(es.get("link_label", "")),
		_t("En savoir plus…", "Learn more…"),
		func(val: String) -> void:
			var d := _read_story()
			var block: Dictionary = d.get("end_screen", {})
			if val.is_empty(): block.erase("link_label") else: block["link_label"] = val
			d["end_screen"] = block
			_write_story(d),
		_t("Texte affiché sur le lien. Si vide, l'URL brute est affichée.",
			"Text shown on the link. If empty, the raw URL is shown."))

	_checkbox(_content,
		"glitch",
		es.get("glitch", false),
		func(val: bool) -> void:
			var d := _read_story()
			var block: Dictionary = d.get("end_screen", {})
			if not val: block.erase("glitch") else: block["glitch"] = true
			d["end_screen"] = block
			_write_story(d),
		_t("Active l'effet glitch sur le titre (scramble + scanlines + flicker).",
			"Enables the glitch effect on the title (scramble + scanlines + flicker)."))

	_checkbox(_content,
		"show_stats",
		es.get("show_stats", false),
		func(val: bool) -> void:
			var d := _read_story()
			var block: Dictionary = d.get("end_screen", {})
			if not val: block.erase("show_stats") else: block["show_stats"] = true
			d["end_screen"] = block
			_write_story(d),
		_t("Affiche le nombre de messages échangés pendant la session.",
			"Shows the number of messages exchanged during the session."))


func _es_localized_field(
		key: String, raw_val: Variant,
		label: String, placeholder: String, tooltip: String) -> void:
	var locales := _get_supported_locales()
	var lbl := Label.new()
	lbl.text = label
	lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_content.add_child(lbl)
	var lang_edits: Dictionary = {}
	for locale: String in locales:
		var row := HBoxContainer.new()
		var code_lbl := Label.new()
		code_lbl.text = locale
		code_lbl.custom_minimum_size = Vector2(24, 0)
		code_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		row.add_child(code_lbl)
		var edit := LineEdit.new()
		if raw_val is Dictionary:
			edit.text = (raw_val as Dictionary).get(locale, "")
		else:
			edit.text = raw_val as String if locale == locales[0] else ""
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit.placeholder_text = placeholder
		edit.tooltip_text = tooltip
		row.add_child(edit)
		_content.add_child(row)
		lang_edits[locale] = edit
	var save_fn: Callable = func() -> void:
		var result: Dictionary = {}
		for loc: String in lang_edits:
			result[loc] = (lang_edits[loc] as LineEdit).text
		var new_val: Variant = result if result.size() > 1 else result.values()[0]
		var d := _read_story()
		var block: Dictionary = d.get("end_screen", {})
		var all_empty: bool = (new_val is String and (new_val as String).is_empty()) \
			or (new_val is Dictionary and (new_val as Dictionary).values().all(
				func(v: Variant) -> bool: return (v as String).is_empty()))
		if all_empty: block.erase(key) else: block[key] = new_val
		d["end_screen"] = block
		_write_story(d)
	for loc: String in lang_edits:
		(lang_edits[loc] as LineEdit).focus_exited.connect(save_fn)
