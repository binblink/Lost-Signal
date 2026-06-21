@tool
extends Control

signal story_modified
signal rename_contact_requested(old_id: String, new_id: String)
signal error_occurred(msg: String)

## Callable → Array of scene IDs; injected by StoryEditorPanel so we stay decoupled.
var get_scene_ids: Callable = func() -> Array: return []

const STRIPE_A    := Color(0.18, 0.18, 0.22)
const STRIPE_B    := Color(0.11, 0.11, 0.13)
const STATUS_VALS := ["online", "away", "offline", "network_issue"]
const STORY_PATH  := "res://story.json"

var _content: VBoxContainer


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 4)
	scroll.add_child(_content)
	refresh()


func refresh() -> void:
	if _content == null:
		return
	for child in _content.get_children():
		child.free()
	var data := _read_story()
	_build_global(data)
	_build_contacts(data)


# ---------------------------------------------------------------------------
# story.json read / write

func _read_story() -> Dictionary:
	var f := FileAccess.open(STORY_PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if parsed is Dictionary else {}


func _write_story(data: Dictionary) -> void:
	var f := FileAccess.open(STORY_PATH, FileAccess.WRITE)
	if f == null:
		error_occurred.emit(_t("Erreur écriture : story.json", "Write error: story.json"))
		return
	f.store_string(_json_expand(_ordered_story(data), "") + "\n")
	f.close()
	story_modified.emit()


func _ordered_story(data: Dictionary) -> Dictionary:
	const KEYS := ["title", "start_scene", "start_contact", "contacts"]
	var result := {}
	for k in KEYS:
		if data.has(k):
			result[k] = data[k]
	for k in data:
		if not result.has(k):
			result[k] = data[k]
	if result.has("contacts"):
		var arr: Array = []
		for c in (result["contacts"] as Array):
			arr.append(_ordered_contact(c))
		result["contacts"] = arr
	return result


func _ordered_contact(c: Dictionary) -> Dictionary:
	const KEYS := ["id", "name", "is_main", "avatar", "status", "pending_scene", "history"]
	var result := {}
	for k in KEYS:
		if c.has(k):
			result[k] = c[k]
	for k in c:
		if not result.has(k):
			result[k] = c[k]
	if result.has("history"):
		var arr: Array = []
		for entry in (result["history"] as Array):
			var e := {}
			for hk in ["text", "time", "out"]:
				if entry.has(hk):
					e[hk] = entry[hk]
			for hk in entry:
				if not e.has(hk):
					e[hk] = entry[hk]
			arr.append(e)
		result["history"] = arr
	return result


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
# UI — contacts list

func _build_contacts(data: Dictionary) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	_content.add_child(spacer)
	_section(_content, _t("Contacts", "Contacts"), Color(0.10, 0.16, 0.12))

	var contacts: Array = data.get("contacts", [])
	for i in range(contacts.size()):
		_contact_card(i, contacts[i])

	var add_btn := Button.new()
	add_btn.text = _t("+ Contact", "+ Contact")
	add_btn.tooltip_text = _t(
		"Ajoute un nouveau contact à story.json.\nModifiez son id, nom et statut dans la carte qui apparaît.",
		"Adds a new contact to story.json.\nEdit its id, name and status in the card that appears.")
	add_btn.pressed.connect(func() -> void:
		var d := _read_story()
		if not d.has("contacts"):
			d["contacts"] = []
		(d["contacts"] as Array).append({"id": "new_contact", "name": "New", "status": "online"})
		_write_story(d)
		call_deferred("refresh"))
	_content.add_child(add_btn)


func _contact_card(ci: int, c: Dictionary) -> void:
	var stripe := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = STRIPE_A if ci % 2 == 0 else STRIPE_B
	style.set_content_margin_all(8)
	stripe.add_theme_stylebox_override("panel", style)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	stripe.add_child(inner)
	_content.add_child(stripe)

	var cid:     String = c.get("id",      "")
	var cname:   String = c.get("name",    "")
	var cstatus: String = c.get("status",  "online")
	var is_main: bool   = c.get("is_main", false)
	var avatar          = c.get("avatar",  null)
	var pending: String = str(c.get("pending_scene", ""))

	# — id / name / delete
	var row1 := HBoxContainer.new()
	_label(row1, "id", 28)
	var id_edit := LineEdit.new()
	id_edit.text = cid
	id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	id_edit.tooltip_text = _t(
		"Identifiant unique. Le modifier met à jour contact_id dans tous les fichiers de dialogue.",
		"Unique ID. Changing it updates contact_id across all dialogue files.")
	id_edit.focus_exited.connect(func() -> void:
		var new_id := id_edit.text.strip_edges()
		if new_id == cid or new_id.is_empty():
			id_edit.text = cid
			return
		var d := _read_story()
		for i in range((d["contacts"] as Array).size()):
			if i != ci and (d["contacts"] as Array)[i].get("id", "") == new_id:
				error_occurred.emit(_t("ID déjà utilisé : " + new_id, "ID already in use: " + new_id))
				id_edit.text = cid
				return
		rename_contact_requested.emit(cid, new_id)
		(d["contacts"] as Array)[ci]["id"] = new_id
		if d.get("start_contact", "") == cid:
			d["start_contact"] = new_id
		_write_story(d)
		call_deferred("refresh"))
	row1.add_child(id_edit)
	_label(row1, _t(" nom", " name"), 0)
	var name_edit := LineEdit.new()
	name_edit.text = cname
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.tooltip_text = _t(
		"Nom affiché dans la liste de contacts et la barre de titre de la conversation.",
		"Name shown in the contact list and the conversation title bar.")
	name_edit.focus_exited.connect(func() -> void:
		var val := name_edit.text.strip_edges()
		if val != cname:
			var d := _read_story()
			(d["contacts"] as Array)[ci]["name"] = val
			_write_story(d))
	row1.add_child(name_edit)
	var del_btn := Button.new()
	del_btn.text = "×"
	del_btn.custom_minimum_size = Vector2(28, 28)
	del_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	del_btn.tooltip_text = _t("Supprimer ce contact.", "Delete this contact.")
	del_btn.pressed.connect(func() -> void:
		var dialog := ConfirmationDialog.new()
		dialog.title = _t("Supprimer le contact", "Delete contact")
		dialog.dialog_text = _t(
			"Supprimer « %s » ?\nLes contact_id dans les dialogues ne seront pas modifiés." % cid,
			"Delete « %s »?\ncontact_id in dialogues won't be changed." % cid)
		add_child(dialog)
		dialog.confirmed.connect(func() -> void:
			dialog.queue_free()
			var d := _read_story()
			(d["contacts"] as Array).remove_at(ci)
			_write_story(d)
			call_deferred("refresh"))
		dialog.canceled.connect(func() -> void: dialog.queue_free())
		dialog.popup_centered())
	row1.add_child(del_btn)
	inner.add_child(row1)

	# — status / is_main
	var row2 := HBoxContainer.new()
	_label(row2, "status", 50)
	var st_opts := OptionButton.new()
	st_opts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	st_opts.tooltip_text = _t(
		"Statut affiché dans la barre de titre quand ce contact est actif.\nonline : en ligne  |  away : absent  |  offline : hors ligne  |  network_issue : signal faible",
		"Status shown in the title bar when this contact is active.\nonline  |  away  |  offline  |  network_issue: weak signal")
	for sv in STATUS_VALS:
		st_opts.add_item(sv)
	st_opts.selected = max(STATUS_VALS.find(cstatus), 0)
	st_opts.item_selected.connect(func(idx: int) -> void:
		var d := _read_story()
		(d["contacts"] as Array)[ci]["status"] = STATUS_VALS[idx]
		_write_story(d))
	row2.add_child(st_opts)
	var is_main_cb := CheckBox.new()
	is_main_cb.text = "is_main"
	is_main_cb.button_pressed = is_main
	is_main_cb.tooltip_text = _t(
		"Contact principal : reçoit toutes les scènes sans contact_id explicite.",
		"Main contact: receives all scenes with no explicit contact_id.")
	is_main_cb.toggled.connect(func(pressed: bool) -> void:
		var d := _read_story()
		if pressed:
			for i in range((d["contacts"] as Array).size()):
				(d["contacts"] as Array)[i]["is_main"] = (i == ci)
		else:
			(d["contacts"] as Array)[ci]["is_main"] = false
		_write_story(d)
		call_deferred("refresh"))
	row2.add_child(is_main_cb)
	inner.add_child(row2)

	# — avatar
	_line_edit(inner, "avatar",
		str(avatar) if avatar != null else "",
		_t("(chemin image ou vide)", "(image path or empty)"),
		func(val: String) -> void:
			var d := _read_story()
			(d["contacts"] as Array)[ci]["avatar"] = null if val.is_empty() else val
			_write_story(d),
		_t("Chemin vers l'image d'avatar (ex : res://images/maeve.png).\nLaisser vide pour aucun avatar.",
			"Path to the avatar image (e.g. res://images/maeve.png).\nLeave empty for no avatar."))

	# — pending_scene
	var scene_ids: Array = get_scene_ids.call()
	scene_ids.sort()
	_dropdown(inner, "pending_scene", pending, scene_ids, _t("(aucune)", "(none)"),
		func(val: String) -> void:
			var d := _read_story()
			if val.is_empty():
				(d["contacts"] as Array)[ci].erase("pending_scene")
			else:
				(d["contacts"] as Array)[ci]["pending_scene"] = val
			_write_story(d),
		_t("Scène mise en attente pour ce contact au démarrage.\nLe joueur verra un choix en suspens dès qu'il ouvrira cette conversation, avant même d'avoir interagi.",
			"Scene queued for this contact at startup.\nThe player will see a pending choice as soon as they open this conversation, before any interaction."))

	# — history
	_history_rows(inner, ci, c.get("history", []))


# ---------------------------------------------------------------------------
# UI — history entries

func _history_rows(container: VBoxContainer, ci: int, history: Array) -> void:
	var header := HBoxContainer.new()
	var h_lbl := Label.new()
	h_lbl.text = "history (%d)" % history.size()
	h_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	h_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(h_lbl)
	var add_btn := Button.new()
	add_btn.text = "+ msg"
	add_btn.tooltip_text = _t(
		"Ajoute un message pré-rempli visible dès l'ouverture de la conversation,\navant même que la narration ne commence.\n→ coché = message envoyé par le joueur, décoché = reçu.",
		"Adds a pre-filled message visible when the conversation is first opened,\nbefore narration starts.\n→ checked = sent by player, unchecked = received.")
	add_btn.pressed.connect(func() -> void:
		var d := _read_story()
		var contact_data: Dictionary = (d["contacts"] as Array)[ci]
		if not contact_data.has("history"):
			contact_data["history"] = []
		(contact_data["history"] as Array).append({"text": "", "time": "00:00", "out": false})
		_write_story(d)
		call_deferred("refresh"))
	header.add_child(add_btn)
	container.add_child(header)

	for hi in range(history.size()):
		var entry: Dictionary = history[hi]
		var e_text: String = str(entry.get("text",  ""))
		var e_time: String = str(entry.get("time",  "00:00"))
		var e_out:  bool   =     entry.get("out",   false)
		var row := HBoxContainer.new()

		var out_cb := CheckBox.new()
		out_cb.text = "→"
		out_cb.button_pressed = e_out
		out_cb.tooltip_text = _t("Coché = envoyé par le joueur", "Checked = sent by player")
		out_cb.toggled.connect(func(pressed: bool) -> void:
			var d := _read_story()
			((d["contacts"] as Array)[ci]["history"] as Array)[hi]["out"] = pressed
			_write_story(d))
		row.add_child(out_cb)

		var time_edit := LineEdit.new()
		time_edit.text = e_time
		time_edit.placeholder_text = "HH:MM"
		time_edit.custom_minimum_size = Vector2(62, 0)
		time_edit.tooltip_text = _t("Heure affichée sous le message (format HH:MM).", "Time shown under the message (HH:MM format).")
		time_edit.focus_exited.connect(func() -> void:
			var val := time_edit.text.strip_edges()
			if val != e_time:
				var d := _read_story()
				((d["contacts"] as Array)[ci]["history"] as Array)[hi]["time"] = val
				_write_story(d))
		row.add_child(time_edit)

		var text_edit := LineEdit.new()
		text_edit.text = e_text
		text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_edit.tooltip_text = _t("Texte du message.", "Message text.")
		text_edit.focus_exited.connect(func() -> void:
			var val := text_edit.text
			if val != e_text:
				var d := _read_story()
				((d["contacts"] as Array)[ci]["history"] as Array)[hi]["text"] = val
				_write_story(d))
		row.add_child(text_edit)

		var del_btn := Button.new()
		del_btn.text = "×"
		del_btn.custom_minimum_size = Vector2(28, 28)
		del_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		del_btn.tooltip_text = _t("Supprimer ce message de l'historique.", "Remove this message from the history.")
		del_btn.pressed.connect(func() -> void:
			var d := _read_story()
			((d["contacts"] as Array)[ci]["history"] as Array).remove_at(hi)
			if ((d["contacts"] as Array)[ci]["history"] as Array).is_empty():
				(d["contacts"] as Array)[ci].erase("history")
			_write_story(d)
			call_deferred("refresh"))
		row.add_child(del_btn)
		container.add_child(row)


# ---------------------------------------------------------------------------
# Widget helpers

func _section(container: VBoxContainer, title: String, bg_color: Color = Color(0.15, 0.15, 0.18)) -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0))
	panel.add_child(lbl)
	container.add_child(panel)


func _line_edit(container: VBoxContainer, label: String, initial: String, placeholder: String, on_commit: Callable, tooltip: String = "") -> void:
	var row := HBoxContainer.new()
	_label(row, label, 110)
	var edit := LineEdit.new()
	edit.text = initial
	edit.placeholder_text = placeholder
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if tooltip:
		edit.tooltip_text = tooltip
	edit.focus_exited.connect(func() -> void:
		var val := edit.text.strip_edges()
		if val != initial:
			on_commit.call(val))
	row.add_child(edit)
	container.add_child(row)


func _dropdown(container: VBoxContainer, label: String, current: String, options: Array, none_label: String, on_change: Callable, tooltip: String = "") -> void:
	var opts_list := options.duplicate()
	if current and not opts_list.has(current):
		opts_list.append(current)
		opts_list.sort()
	var row := HBoxContainer.new()
	_label(row, label, 110)
	var opts := OptionButton.new()
	opts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if tooltip:
		opts.tooltip_text = tooltip
	opts.add_item(none_label)
	var selected := 0
	for i in range(opts_list.size()):
		opts.add_item(str(opts_list[i]))
		if str(opts_list[i]) == current:
			selected = i + 1
	opts.selected = selected
	opts.item_selected.connect(func(idx: int) -> void:
		if idx == 0:
			on_change.call("")
		else:
			on_change.call(str(opts_list[idx - 1])))
	row.add_child(opts)
	container.add_child(row)


func _label(parent: HBoxContainer, text: String, min_width: int) -> void:
	var lbl := Label.new()
	lbl.text = text
	if min_width > 0:
		lbl.custom_minimum_size = Vector2(min_width, 0)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	parent.add_child(lbl)


# ---------------------------------------------------------------------------
# Utilities — pure functions mirroring StoryEditorPanel (no shared state needed)

func _t(fr: String, en: String) -> String:
	return fr if OS.get_locale_language() == "fr" else en


func _json_compact(value) -> String:
	if value is Dictionary:
		if (value as Dictionary).is_empty():
			return "{}"
		var parts: Array[String] = []
		for key in value:
			parts.append(JSON.stringify(str(key)) + ": " + _json_compact(value[key]))
		return "{" + ", ".join(parts) + "}"
	if value is Array:
		if (value as Array).is_empty():
			return "[]"
		var parts: Array[String] = []
		for item in value:
			parts.append(_json_compact(item))
		return "[" + ", ".join(parts) + "]"
	return JSON.stringify(value)


func _json_expand(value, indent: String) -> String:
	if indent.length() >= 4:
		return _json_compact(value)
	if value is Dictionary:
		if (value as Dictionary).is_empty():
			return "{}"
		var next_indent := indent + "\t"
		var parts: Array[String] = []
		for key in value:
			parts.append(next_indent + JSON.stringify(str(key)) + ": " + _json_expand(value[key], next_indent))
		return "{\n" + ",\n".join(parts) + "\n" + indent + "}"
	if value is Array:
		if (value as Array).is_empty():
			return "[]"
		var next_indent := indent + "\t"
		var parts: Array[String] = []
		for item in value:
			parts.append(next_indent + _json_expand(item, next_indent))
		return "[\n" + ",\n".join(parts) + "\n" + indent + "]"
	return JSON.stringify(value)
