@tool
extends Window

signal finished(result: Dictionary)

var ui_locale: String = OS.get_locale_language()
var locale: String = ""
var build_plan: Callable
var apply_plan: Callable

var _content: VBoxContainer
var _full_delete := false


func configure(
		locale_to_remove: String,
		plan_builder: Callable,
		plan_applier: Callable,
		locale_for_ui: String
	) -> void:
	locale = locale_to_remove
	build_plan = plan_builder
	apply_plan = plan_applier
	ui_locale = locale_for_ui


func _ready() -> void:
	name = "LanguageRemovalWizard"
	title = _t("Supprimer une langue", "Remove a language")
	size = Vector2i(600, 500)
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
	_show_mode_selection()


func _show_mode_selection() -> void:
	_clear_content()
	_heading(_t("1 / 2 — Choisir la portée", "1 / 2 — Choose the scope"))

	var intro := Label.new()
	intro.text = _t(
		"Que faut-il supprimer pour %s ?" % _locale_label(locale),
		"What should be removed for %s?" % _locale_label(locale)
	)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(intro)

	var mode := OptionButton.new()
	mode.name = "LanguageRemovalMode"
	mode.add_item(_t("Retirer uniquement du jeu", "Remove from the game only"))
	mode.add_item(_t("Supprimer entièrement la langue", "Delete the entire language"))
	mode.selected = 1 if _full_delete else 0
	_content.add_child(mode)

	var explanation := Label.new()
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation.add_theme_color_override("font_color", Color(0.68, 0.74, 0.78))
	_content.add_child(explanation)

	var warning := Label.new()
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.add_theme_color_override("font_color", Color(1.0, 0.68, 0.25))
	_content.add_child(warning)

	var update_mode: Callable = func(index: int) -> void:
		_full_delete = index == 1
		if _full_delete:
			explanation.text = _t(
				"Supprime la colonne de ui.csv, les valeurs localisées de story.json et tous les fichiers de dialogue propres à cette langue.",
				"Removes the ui.csv column, localized story.json values, and every dialogue file specific to this language."
			)
			warning.text = _t(
				"Les fichiers seront archivés avec leurs sauvegardes afin de rester récupérables.",
				"Files will be archived with their backups so they remain recoverable."
			)
		else:
			explanation.text = _t(
				"Supprime seulement la colonne de ui.csv. Les dialogues et valeurs localisées restent sur le disque pour une restauration ultérieure.",
				"Only removes the ui.csv column. Dialogue files and localized values remain on disk for a later restore."
			)
			warning.text = ""
	mode.item_selected.connect(update_mode)
	update_mode.call(mode.selected)

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
	next.name = "LanguageRemovalNextButton"
	next.text = _t("Continuer", "Continue")
	next.custom_minimum_size = Vector2(140, 36)
	next.pressed.connect(func() -> void:
		var plan: Dictionary = build_plan.call(locale, _full_delete)
		if plan.get("ok", false):
			_show_review(plan)
		else:
			_show_result(plan))
	actions.add_child(next)
	_content.add_child(actions)


func _show_review(plan: Dictionary) -> void:
	_clear_content()
	_heading(_t("2 / 2 — Vérifier la suppression", "2 / 2 — Review removal"))

	var summary := Label.new()
	summary.text = _t(
		"Langue : %s\nMode : %s\nValeurs localisées supprimées : %d" % [
			_locale_label(locale),
			_t("suppression complète", "complete removal") if plan.get("full_delete", false) else _t("retrait du jeu", "game removal"),
			int(plan.get("story_removal_count", 0)),
		],
		"Language: %s\nMode: %s\nLocalized values removed: %d" % [
			_locale_label(locale),
			"complete removal" if plan.get("full_delete", false) else "game removal",
			int(plan.get("story_removal_count", 0)),
		]
	)
	_content.add_child(summary)

	var file_title := Label.new()
	file_title.text = _t(
		"Fichiers à retirer : %d" % (plan.get("files_to_archive", []) as Array).size(),
		"Files to remove: %d" % (plan.get("files_to_archive", []) as Array).size()
	)
	file_title.add_theme_font_size_override("font_size", 14)
	_content.add_child(file_title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 170)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var files := VBoxContainer.new()
	files.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for path: String in plan.get("files_to_archive", []):
		var line := Label.new()
		line.text = "• " + path
		line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		line.tooltip_text = path
		files.add_child(line)
	if files.get_child_count() == 0:
		var none := Label.new()
		none.text = _t("Aucun fichier ne sera retiré.", "No file will be removed.")
		files.add_child(none)
	scroll.add_child(files)
	_content.add_child(scroll)

	var safety := Label.new()
	safety.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	safety.text = _t(
		"La langue par défaut et la dernière langue sont protégées. Les fichiers supprimés complètement restent archivés localement.",
		"The default and last languages are protected. Completely removed files remain archived locally."
	)
	safety.add_theme_color_override("font_color", Color(0.72, 0.72, 0.76))
	_content.add_child(safety)

	var actions := _action_row()
	var back := Button.new()
	back.text = _t("Retour", "Back")
	back.custom_minimum_size = Vector2(100, 36)
	back.pressed.connect(_show_mode_selection)
	actions.add_child(back)
	var confirm := Button.new()
	confirm.name = "LanguageRemovalConfirmButton"
	confirm.text = _t("Supprimer entièrement", "Delete completely") if plan.get("full_delete", false) \
		else _t("Retirer du jeu", "Remove from game")
	confirm.custom_minimum_size = Vector2(180, 36)
	confirm.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	confirm.pressed.connect(func() -> void:
		confirm.disabled = true
		var current_plan: Dictionary = build_plan.call(locale, bool(plan.get("full_delete", false)))
		var result := current_plan
		if current_plan.get("ok", false):
			result = apply_plan.call(current_plan)
		_show_result(result))
	actions.add_child(confirm)
	_content.add_child(actions)


func _show_result(result: Dictionary) -> void:
	_clear_content()
	var ok := bool(result.get("ok", false))
	_heading(_t("Langue supprimée", "Language removed") if ok else _t("Suppression incomplète", "Removal incomplete"))
	var message := Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if ok:
		message.text = _t(
			"%s a été retirée.\n\nFichiers archivés : %d\nValeurs localisées supprimées : %d" % [
				_locale_label(locale),
				(result.get("archived_files", []) as Array).size(),
				int(result.get("story_removal_count", 0)),
			],
			"%s was removed.\n\nArchived files: %d\nLocalized values removed: %d" % [
				_locale_label(locale),
				(result.get("archived_files", []) as Array).size(),
				int(result.get("story_removal_count", 0)),
			]
		)
		message.add_theme_color_override("font_color", Color(0.48, 0.84, 0.58))
	else:
		message.text = str(result.get("error", _t("La suppression a échoué.", "Removal failed.")))
		message.add_theme_color_override("font_color", Color(1.0, 0.42, 0.42))
	_content.add_child(message)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(spacer)
	var actions := _action_row()
	if not ok:
		var retry := Button.new()
		retry.text = _t("Retour", "Back")
		retry.pressed.connect(_show_mode_selection)
		actions.add_child(retry)
	var close := Button.new()
	close.text = _t("Fermer", "Close")
	close.custom_minimum_size = Vector2(100, 36)
	close.pressed.connect(func() -> void:
		finished.emit(result)
		queue_free())
	actions.add_child(close)
	_content.add_child(actions)


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


func _locale_label(code: String) -> String:
	var display_name := TranslationServer.get_locale_name(code)
	return "%s (%s)" % [display_name, code] if not display_name.is_empty() else code


func _t(fr: String, en: String) -> String:
	return fr if ui_locale == "fr" else en
