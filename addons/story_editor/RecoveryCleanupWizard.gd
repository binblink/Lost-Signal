@tool
extends Window

signal finished(result: Dictionary)

var ui_locale: String = OS.get_locale_language()
var build_plan: Callable
var apply_cleanup: Callable

var _content: VBoxContainer
var _include_backups := true
var _include_removed := true


func configure(plan_builder: Callable, cleanup_applier: Callable, locale_for_ui: String) -> void:
	build_plan = plan_builder
	apply_cleanup = cleanup_applier
	ui_locale = locale_for_ui


func _ready() -> void:
	name = "RecoveryCleanupWizard"
	title = _t("Nettoyer les fichiers de récupération", "Clean recovery files")
	size = Vector2i(640, 560)
	min_size = size
	max_size = size
	unresizable = true
	wrap_controls = true
	close_requested.connect(queue_free)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 12)
	margin.add_child(_content)
	_show_scope()


func _show_scope() -> void:
	_clear_content()
	_heading(_t("1 / 2 — Choisir les récupérations", "1 / 2 — Choose recovery files"))

	var intro := Label.new()
	intro.text = _t(
		"Cet outil recherche uniquement les sauvegardes créées par le moteur dans le projet. Aucune sauvegarde de partie dans user:// n’est concernée.",
		"This tool only searches for engine-created recovery files inside the project. Game saves under user:// are not affected."
	)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(intro)

	var backups := CheckBox.new()
	backups.name = "CleanupBackupsCheck"
	backups.text = _t("Sauvegardes rotatives : .bak, .bak.2, .bak.3", "Rotating backups: .bak, .bak.2, .bak.3")
	backups.button_pressed = _include_backups
	backups.toggled.connect(func(pressed: bool) -> void: _include_backups = pressed)
	_content.add_child(backups)

	var removed := CheckBox.new()
	removed.name = "CleanupRemovedCheck"
	removed.text = _t("Archives de langues supprimées : .removed.*", "Removed-language archives: .removed.*")
	removed.button_pressed = _include_removed
	removed.toggled.connect(func(pressed: bool) -> void: _include_removed = pressed)
	_content.add_child(removed)

	var exclusions := Label.new()
	exclusions.text = _t(
		"Exclus volontairement : .tmp (transaction interrompue), .corrupt.* (diagnostic), .git, .godot et les dossiers d’export.",
		"Intentionally excluded: .tmp (interrupted transaction), .corrupt.* (diagnostics), .git, .godot, and export directories."
	)
	exclusions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	exclusions.add_theme_color_override("font_color", Color(0.65, 0.72, 0.76))
	_content.add_child(exclusions)

	var warning := Label.new()
	warning.text = _t(
		"Le nettoyage confirmé est définitif. Une sauvegarde .bak dont le fichier principal est absent ou invalide sera automatiquement protégée.",
		"Confirmed cleanup is permanent. A .bak file whose primary file is missing or invalid is automatically protected."
	)
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.add_theme_color_override("font_color", Color(1.0, 0.68, 0.25))
	_content.add_child(warning)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(spacer)
	var actions := _action_row()
	var cancel := Button.new()
	cancel.text = _t("Annuler", "Cancel")
	cancel.custom_minimum_size = Vector2(100, 36)
	cancel.pressed.connect(queue_free)
	actions.add_child(cancel)
	var next := Button.new()
	next.name = "RecoveryCleanupNextButton"
	next.text = _t("Analyser", "Scan")
	next.custom_minimum_size = Vector2(140, 36)
	next.disabled = not (_include_backups or _include_removed)
	var update_next: Callable = func(_pressed: bool = false) -> void:
		next.disabled = not (_include_backups or _include_removed)
	backups.toggled.connect(update_next)
	removed.toggled.connect(update_next)
	next.pressed.connect(func() -> void:
		var plan: Dictionary = build_plan.call(_include_backups, _include_removed)
		_show_review(plan))
	actions.add_child(next)
	_content.add_child(actions)


func _show_review(plan: Dictionary) -> void:
	_clear_content()
	_heading(_t("2 / 2 — Vérifier le nettoyage", "2 / 2 — Review cleanup"))

	var entries: Array = plan.get("entries", [])
	var protected_count := 0
	for entry: Dictionary in entries:
		if entry.get("protected", false):
			protected_count += 1
	var summary := Label.new()
	summary.text = _t(
		"Trouvés : %d fichier(s) · Protégés : %d" % [entries.size(), protected_count],
		"Found: %d file(s) · Protected: %d" % [entries.size(), protected_count]
	)
	_content.add_child(summary)

	var selection_actions := HBoxContainer.new()
	selection_actions.add_theme_constant_override("separation", 8)
	var select_all := Button.new()
	select_all.text = _t("Tout sélectionner", "Select all")
	selection_actions.add_child(select_all)
	var select_none := Button.new()
	select_none.text = _t("Tout désélectionner", "Select none")
	selection_actions.add_child(select_none)
	_content.add_child(selection_actions)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var files := VBoxContainer.new()
	files.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	files.add_theme_constant_override("separation", 5)
	var checkboxes: Dictionary = {}
	for entry: Dictionary in entries:
		var path: String = entry["path"]
		var checkbox := CheckBox.new()
		checkbox.text = "%s  —  %s" % [path, _format_bytes(int(entry.get("size", 0)))]
		checkbox.clip_text = true
		checkbox.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		checkbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		checkbox.disabled = entry.get("protected", false)
		checkbox.button_pressed = not checkbox.disabled
		checkbox.tooltip_text = path
		if checkbox.disabled:
			checkbox.tooltip_text += "\n" + str(entry.get("reason", ""))
			checkbox.add_theme_color_override("font_color", Color(1.0, 0.68, 0.25))
		files.add_child(checkbox)
		checkboxes[path] = checkbox
	if entries.is_empty():
		var none := Label.new()
		none.text = _t("Aucun fichier de récupération correspondant.", "No matching recovery file.")
		files.add_child(none)
	scroll.add_child(files)
	_content.add_child(scroll)

	var actions := _action_row()
	var back := Button.new()
	back.text = _t("Retour", "Back")
	back.custom_minimum_size = Vector2(100, 36)
	back.pressed.connect(_show_scope)
	actions.add_child(back)
	var confirm := Button.new()
	confirm.name = "RecoveryCleanupConfirmButton"
	confirm.custom_minimum_size = Vector2(190, 36)
	confirm.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	actions.add_child(confirm)
	_content.add_child(actions)

	var update_confirmation: Callable = func() -> void:
		var count := 0
		var total_size := 0
		for entry: Dictionary in entries:
			var checkbox: CheckBox = checkboxes[entry["path"]]
			if checkbox.button_pressed and not checkbox.disabled:
				count += 1
				total_size += int(entry.get("size", 0))
		confirm.disabled = count == 0
		confirm.text = _t(
			"Supprimer %d fichier(s) — %s" % [count, _format_bytes(total_size)],
			"Delete %d file(s) — %s" % [count, _format_bytes(total_size)]
		)
	for checkbox: CheckBox in checkboxes.values():
		checkbox.toggled.connect(func(_pressed: bool) -> void: update_confirmation.call())
	select_all.pressed.connect(func() -> void:
		for checkbox: CheckBox in checkboxes.values():
			if not checkbox.disabled:
				checkbox.button_pressed = true
		update_confirmation.call())
	select_none.pressed.connect(func() -> void:
		for checkbox: CheckBox in checkboxes.values():
			checkbox.button_pressed = false
		update_confirmation.call())
	confirm.pressed.connect(func() -> void:
		confirm.disabled = true
		var selected_paths: Array[String] = []
		for path: String in checkboxes:
			var checkbox: CheckBox = checkboxes[path]
			if checkbox.button_pressed and not checkbox.disabled:
				selected_paths.append(path)
		selected_paths.sort()
		var result: Dictionary = apply_cleanup.call(selected_paths)
		_show_result(result))
	update_confirmation.call()


func _show_result(result: Dictionary) -> void:
	_clear_content()
	var ok := bool(result.get("ok", false))
	_heading(_t("Nettoyage terminé", "Cleanup complete") if ok else _t("Nettoyage incomplet", "Cleanup incomplete"))
	var message := Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if ok:
		message.text = _t(
			"%d fichier(s) supprimé(s) définitivement.\nEspace libéré : %s" % [
				(result.get("deleted_paths", []) as Array).size(),
				_format_bytes(int(result.get("deleted_size", 0))),
			],
			"%d file(s) permanently deleted.\nSpace freed: %s" % [
				(result.get("deleted_paths", []) as Array).size(),
				_format_bytes(int(result.get("deleted_size", 0))),
			]
		)
		message.add_theme_color_override("font_color", Color(0.48, 0.84, 0.58))
	else:
		message.text = str(result.get("error", _t("Le nettoyage a échoué.", "Cleanup failed.")))
		message.add_theme_color_override("font_color", Color(1.0, 0.42, 0.42))
	_content.add_child(message)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(spacer)
	var actions := _action_row()
	var close := Button.new()
	close.text = _t("Fermer", "Close")
	close.custom_minimum_size = Vector2(100, 36)
	close.pressed.connect(func() -> void:
		finished.emit(result)
		queue_free())
	actions.add_child(close)
	_content.add_child(actions)


func _format_bytes(bytes: int) -> String:
	if bytes < 1024:
		return "%d o" % bytes if ui_locale == "fr" else "%d B" % bytes
	if bytes < 1024 * 1024:
		return "%.1f Ko" % (bytes / 1024.0) if ui_locale == "fr" else "%.1f KB" % (bytes / 1024.0)
	return "%.1f Mo" % (bytes / (1024.0 * 1024.0)) if ui_locale == "fr" else "%.1f MB" % (bytes / (1024.0 * 1024.0))


func _clear_content() -> void:
	if _content == null:
		return
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()


func _heading(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0))
	_content.add_child(label)


func _action_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 8)
	return row


func _t(fr: String, en: String) -> String:
	return fr if ui_locale == "fr" else en
