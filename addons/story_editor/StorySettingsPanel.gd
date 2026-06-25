@tool
extends "res://addons/story_editor/StoryPanelBase.gd"


func refresh() -> void:
	if _content == null:
		return
	for child in _content.get_children():
		child.free()
	var data := _read_story()
	_build_global(data)
	_build_languages()
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
# UI — language management

func _build_languages() -> void:
	_section(_content, _t("Langues", "Languages"), Color(0.10, 0.18, 0.14))

	var locales := _get_supported_locales()

	var chips_row := HBoxContainer.new()
	chips_row.add_theme_constant_override("separation", 6)
	for locale: String in locales:
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 2)
		var lbl := Label.new()
		lbl.text = locale
		lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 0.75))
		chip.add_child(lbl)
		var rm := Button.new()
		rm.text = "×"
		rm.flat = true
		rm.disabled = locales.size() <= 1
		rm.tooltip_text = _t(
			"Supprimer cette langue de ui.csv (irréversible).\nImpossible de supprimer la dernière langue.",
			"Remove this language from ui.csv (irreversible).\nCannot remove the last language.")
		var captured: String = locale
		rm.pressed.connect(func() -> void:
			_remove_language_from_csv(captured)
			call_deferred("refresh"))
		chip.add_child(rm)
		chips_row.add_child(chip)
	_content.add_child(chips_row)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var locale_edit := LineEdit.new()
	locale_edit.placeholder_text = _t("Code (ex : de, ja…)", "Code (e.g. de, ja…)")
	locale_edit.custom_minimum_size = Vector2(160, 0)
	locale_edit.tooltip_text = _t(
		"Code ISO 639-1 de la nouvelle langue.\nDoit correspondre au suffixe de votre fichier de dialogue (ex : acte1.de.json).",
		"ISO 639-1 code for the new language.\nMust match the suffix of your dialogue file (e.g. act1.de.json).")
	row.add_child(locale_edit)

	var add_btn := Button.new()
	add_btn.text = _t("+ Ajouter", "+ Add")
	add_btn.tooltip_text = _t(
		"Ajoute une colonne vide pour cette langue dans ui.csv.\nGodot régénère automatiquement le fichier .translation.",
		"Adds an empty column for this language in ui.csv.\nGodot automatically regenerates the .translation file.")
	add_btn.pressed.connect(func() -> void:
		var code := locale_edit.text.strip_edges().to_lower()
		if code.is_empty() or code in locales:
			return
		_add_language_to_csv(code)
		locale_edit.text = ""
		call_deferred("refresh"))
	row.add_child(add_btn)
	_content.add_child(row)


func _add_language_to_csv(locale: String) -> void:
	if not FileAccess.file_exists(CSV_PATH):
		push_error("StorySettingsPanel: CSV not found — " + CSV_PATH)
		return
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		return
	var rows: Array[PackedStringArray] = []
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() == 1 and row[0].is_empty():
			continue
		rows.append(row)
	file.close()
	if rows.is_empty() or locale in rows[0]:
		return
	var out := FileAccess.open(CSV_PATH, FileAccess.WRITE)
	if out == null:
		return
	for row: PackedStringArray in rows:
		var extended := PackedStringArray(row)
		extended.append("")
		out.store_csv_line(extended)
	out.close()
	EditorInterface.get_resource_filesystem().reimport_files(
		PackedStringArray(["res://translations/ui.csv"]))


func _remove_language_from_csv(locale: String) -> void:
	if not FileAccess.file_exists(CSV_PATH):
		return
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		return
	var rows: Array[PackedStringArray] = []
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() == 1 and row[0].is_empty():
			continue
		rows.append(row)
	file.close()
	if rows.is_empty():
		return
	var col_index: int = -1
	for i: int in range(rows[0].size()):
		if rows[0][i] == locale:
			col_index = i
			break
	if col_index < 0:
		return
	var out := FileAccess.open(CSV_PATH, FileAccess.WRITE)
	if out == null:
		return
	for row: PackedStringArray in rows:
		var trimmed := PackedStringArray()
		for i: int in range(row.size()):
			if i != col_index:
				trimmed.append(row[i])
		out.store_csv_line(trimmed)
	out.close()
	EditorInterface.get_resource_filesystem().reimport_files(
		PackedStringArray(["res://translations/ui.csv"]))


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
