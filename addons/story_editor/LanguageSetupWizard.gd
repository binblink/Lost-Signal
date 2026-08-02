@tool
extends Window

signal finished(result: Dictionary)

var ui_locale: String = OS.get_locale_language()
var existing_locales: Array[String] = []
var default_source_locale: String = ""
var build_plan: Callable
var apply_plan: Callable

var _content: VBoxContainer
var _state := {
	"locale": "",
	"source_locale": "",
	"create_dialogues": true,
	"copy_story_fields": true,
}


func configure(
		locales: Array[String],
		source_locale: String,
		plan_builder: Callable,
		plan_applier: Callable,
		locale_for_ui: String
	) -> void:
	existing_locales = locales.duplicate()
	default_source_locale = source_locale
	build_plan = plan_builder
	apply_plan = plan_applier
	ui_locale = locale_for_ui
	_state["source_locale"] = source_locale


func _ready() -> void:
	name = "LanguageSetupWizard"
	title = _t("Ajouter une langue", "Add a language")
	size = Vector2i(620, 560)
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
	_show_configuration()


func _show_configuration() -> void:
	_clear_content()
	_heading(_t("1 / 2 — Configurer la langue", "1 / 2 — Configure the language"))

	var intro := Label.new()
	intro.text = _t(
		"L’assistant ajoute la langue à l’interface et peut préparer tous les contenus localisés à traduire.",
		"The wizard adds the language to the interface and can prepare all localized content for translation."
	)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(intro)

	var code_row := HBoxContainer.new()
	var code_label := Label.new()
	code_label.text = _t("Code langue", "Language code")
	code_label.custom_minimum_size = Vector2(150, 0)
	code_row.add_child(code_label)
	var code_edit := LineEdit.new()
	code_edit.name = "LanguageCodeEdit"
	code_edit.text = str(_state["locale"])
	code_edit.placeholder_text = _t("ex : es, de, pt_BR", "e.g. es, de, pt_BR")
	code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_row.add_child(code_edit)
	_content.add_child(code_row)

	var detected_name := Label.new()
	detected_name.add_theme_color_override("font_color", Color(0.62, 0.72, 0.76))
	detected_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(detected_name)

	var source_row := HBoxContainer.new()
	var source_label := Label.new()
	source_label.text = _t("Langue source", "Source language")
	source_label.custom_minimum_size = Vector2(150, 0)
	source_row.add_child(source_label)
	var source_option := OptionButton.new()
	source_option.name = "LanguageSourceOption"
	source_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var selected_source := 0
	for index: int in range(existing_locales.size()):
		var locale := existing_locales[index]
		source_option.add_item(_locale_label(locale))
		source_option.set_item_tooltip(index, locale)
		if locale == str(_state["source_locale"]):
			selected_source = index
	source_option.selected = selected_source
	if not existing_locales.is_empty():
		_state["source_locale"] = existing_locales[selected_source]
	source_option.item_selected.connect(func(index: int) -> void:
		_state["source_locale"] = existing_locales[index])
	source_row.add_child(source_option)
	_content.add_child(source_row)

	var source_help := Label.new()
	source_help.text = _t(
		"Les textes sont copiés depuis cette langue comme base de travail. Ils restent à traduire.",
		"Text is copied from this language as a working base. It still needs to be translated."
	)
	source_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	source_help.add_theme_color_override("font_color", Color(0.62, 0.72, 0.76))
	_content.add_child(source_help)

	var dialogue_check := CheckBox.new()
	dialogue_check.name = "CreateDialogueFilesCheck"
	dialogue_check.text = _t(
		"Créer les fichiers de dialogue localisés manquants",
		"Create missing localized dialogue files"
	)
	dialogue_check.button_pressed = bool(_state["create_dialogues"])
	dialogue_check.toggled.connect(func(pressed: bool) -> void: _state["create_dialogues"] = pressed)
	_content.add_child(dialogue_check)

	var story_check := CheckBox.new()
	story_check.name = "CopyStoryFieldsCheck"
	story_check.text = _t(
		"Préparer les noms, historiques et textes de fin localisés",
		"Prepare localized names, histories, and end-screen text"
	)
	story_check.button_pressed = bool(_state["copy_story_fields"])
	story_check.toggled.connect(func(pressed: bool) -> void: _state["copy_story_fields"] = pressed)
	_content.add_child(story_check)

	var fallback_note := Label.new()
	fallback_note.text = _t(
		"Si les fichiers de dialogue ne sont pas créés, le jeu continuera d’utiliser automatiquement la langue par défaut.",
		"If dialogue files are not created, the game will continue to use the default language automatically."
	)
	fallback_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fallback_note.add_theme_color_override("font_color", Color(1.0, 0.68, 0.25))
	_content.add_child(fallback_note)

	var error_label := Label.new()
	error_label.name = "LanguageWizardError"
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error_label.add_theme_color_override("font_color", Color(1.0, 0.42, 0.42))
	_content.add_child(error_label)

	var actions := _action_row()
	var cancel := Button.new()
	cancel.text = _t("Annuler", "Cancel")
	cancel.custom_minimum_size = Vector2(100, 36)
	cancel.pressed.connect(queue_free)
	actions.add_child(cancel)
	var next := Button.new()
	next.name = "LanguageWizardNextButton"
	next.text = _t("Continuer", "Continue")
	next.custom_minimum_size = Vector2(140, 36)
	next.disabled = true
	actions.add_child(next)
	_content.add_child(actions)

	var update_code: Callable = func(raw_code: String) -> void:
		var code := _normalize_locale(raw_code)
		var valid := _is_valid_locale(code) and code not in existing_locales
		next.disabled = not valid
		if code.is_empty():
			detected_name.text = _t("Saisissez un code de langue.", "Enter a language code.")
		elif not _is_valid_locale(code):
			detected_name.text = _t(
				"Format attendu : es, deu ou pt_BR.",
				"Expected format: es, deu, or pt_BR."
			)
		elif code in existing_locales:
			detected_name.text = _t("Cette langue existe déjà.", "This language already exists.")
		else:
			detected_name.text = _t("Langue détectée : ", "Detected language: ") + _locale_label(code)
	code_edit.text_changed.connect(update_code)
	update_code.call(code_edit.text)

	next.pressed.connect(func() -> void:
		var code := _normalize_locale(code_edit.text)
		var plan: Dictionary = build_plan.call(
			code,
			str(_state["source_locale"]),
			bool(_state["create_dialogues"]),
			bool(_state["copy_story_fields"])
		)
		if not plan.get("ok", false):
			error_label.text = str(plan.get("error", _t("Impossible de préparer cette langue.", "Could not prepare this language.")))
			return
		_state["locale"] = code
		_show_review(plan)
	)


func _show_review(plan: Dictionary) -> void:
	_clear_content()
	_heading(_t("2 / 2 — Vérifier les changements", "2 / 2 — Review changes"))

	var summary := Label.new()
	summary.text = _t(
		"Langue : %s\nSource : %s\nTextes d’interface à traduire : %d\nChamps de projet préparés : %d" % [
			_locale_label(plan["locale"]),
			_locale_label(plan["source_locale"]),
			int(plan.get("ui_entry_count", 0)),
			int(plan.get("story_copy_count", 0)),
		],
		"Language: %s\nSource: %s\nUI strings to translate: %d\nProject fields prepared: %d" % [
			_locale_label(plan["locale"]),
			_locale_label(plan["source_locale"]),
			int(plan.get("ui_entry_count", 0)),
			int(plan.get("story_copy_count", 0)),
		]
	)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(summary)
	var missing_source_count := int(plan.get("ui_missing_source_count", 0)) \
		+ int(plan.get("story_missing_source_count", 0))
	if missing_source_count > 0:
		var missing_warning := Label.new()
		missing_warning.text = _t(
			"Attention : %d valeur(s) sont absentes de la langue source et resteront vides." % missing_source_count,
			"Warning: %d value(s) are missing from the source language and will remain empty." % missing_source_count
		)
		missing_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		missing_warning.add_theme_color_override("font_color", Color(1.0, 0.68, 0.25))
		_content.add_child(missing_warning)

	var file_title := Label.new()
	file_title.text = _t(
		"Fichiers de dialogue à créer : %d" % (plan.get("dialogue_copies", []) as Array).size(),
		"Dialogue files to create: %d" % (plan.get("dialogue_copies", []) as Array).size()
	)
	file_title.add_theme_font_size_override("font_size", 14)
	_content.add_child(file_title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 180)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var files := VBoxContainer.new()
	files.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for copy: Dictionary in plan.get("dialogue_copies", []):
		var line := Label.new()
		line.text = "• %s  ←  %s" % [copy["target"], copy["source"]]
		line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		line.tooltip_text = "%s ← %s" % [copy["target"], copy["source"]]
		files.add_child(line)
	for existing: String in plan.get("existing_dialogue_files", []):
		var line := Label.new()
		line.text = _t("• Conservé : ", "• Kept: ") + existing
		line.add_theme_color_override("font_color", Color(0.62, 0.72, 0.76))
		files.add_child(line)
	if files.get_child_count() == 0:
		var none := Label.new()
		none.text = _t("Aucun fichier de dialogue ne sera créé.", "No dialogue file will be created.")
		files.add_child(none)
	scroll.add_child(files)
	_content.add_child(scroll)

	var safety := Label.new()
	safety.text = _t(
		"Les fichiers existants ne sont jamais écrasés. Toutes les écritures sont validées et récupérables.",
		"Existing files are never overwritten. Every write is validated and recoverable."
	)
	safety.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	safety.add_theme_color_override("font_color", Color(0.48, 0.78, 0.58))
	_content.add_child(safety)

	var actions := _action_row()
	var back := Button.new()
	back.text = _t("Retour", "Back")
	back.custom_minimum_size = Vector2(100, 36)
	back.pressed.connect(_show_configuration)
	actions.add_child(back)
	var confirm := Button.new()
	confirm.name = "LanguageWizardConfirmButton"
	confirm.text = _t("Ajouter la langue", "Add language")
	confirm.custom_minimum_size = Vector2(170, 36)
	confirm.pressed.connect(func() -> void:
		confirm.disabled = true
		var current_plan: Dictionary = build_plan.call(
			str(_state["locale"]),
			str(_state["source_locale"]),
			bool(_state["create_dialogues"]),
			bool(_state["copy_story_fields"])
		)
		var result: Dictionary = current_plan
		if current_plan.get("ok", false):
			result = apply_plan.call(current_plan)
		_show_result(result)
	)
	actions.add_child(confirm)
	_content.add_child(actions)


func _show_result(result: Dictionary) -> void:
	_clear_content()
	var ok := bool(result.get("ok", false))
	_heading(_t("Langue ajoutée", "Language added") if ok else _t("Ajout incomplet", "Setup incomplete"))
	var message := Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if ok:
		message.text = _t(
			"La langue %s est prête.\n\nCréés : %d fichier(s) de dialogue.\nPréparés : %d champ(s) localisé(s).\n\nÉtape suivante : traduisez les textes copiés dans ui.csv, les fichiers de dialogue et story.json." % [
				_locale_label(result["locale"]),
				(result.get("created_dialogue_files", []) as Array).size(),
				int(result.get("story_copy_count", 0)),
			],
			"%s is ready.\n\nCreated: %d dialogue file(s).\nPrepared: %d localized field(s).\n\nNext step: translate the copied text in ui.csv, the dialogue files, and story.json." % [
				_locale_label(result["locale"]),
				(result.get("created_dialogue_files", []) as Array).size(),
				int(result.get("story_copy_count", 0)),
			]
		)
		message.add_theme_color_override("font_color", Color(0.48, 0.84, 0.58))
	else:
		message.text = str(result.get("error", _t("L’ajout de la langue a échoué.", "Language setup failed.")))
		message.add_theme_color_override("font_color", Color(1.0, 0.42, 0.42))
	_content.add_child(message)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(spacer)
	var actions := _action_row()
	if not ok:
		var retry := Button.new()
		retry.text = _t("Retour", "Back")
		retry.custom_minimum_size = Vector2(100, 36)
		retry.pressed.connect(_show_configuration)
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


func _locale_label(locale: String) -> String:
	var display_name := TranslationServer.get_locale_name(locale)
	return "%s (%s)" % [display_name, locale] if not display_name.is_empty() else locale


func _normalize_locale(raw_locale: String) -> String:
	var parts := raw_locale.strip_edges().replace("-", "_").split("_", false)
	if parts.is_empty() or parts.size() > 2:
		return ""
	var normalized := parts[0].to_lower()
	if parts.size() == 2:
		normalized += "_" + parts[1].to_upper()
	return normalized


func _is_valid_locale(locale: String) -> bool:
	var regex := RegEx.new()
	regex.compile("^[a-z]{2,3}(_([A-Z]{2}|[0-9]{3}))?$")
	return regex.search(locale) != null


func _t(fr: String, en: String) -> String:
	return fr if ui_locale == "fr" else en
