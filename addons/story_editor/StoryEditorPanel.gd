@tool
extends Control

const SceneParser = preload("res://addons/story_editor/scene_parser.gd")

const COLOR_NORMAL  := Color(0.8, 0.8, 0.8)
const COLOR_TRIGGER := Color(1.0, 0.6, 0.0)
const COLOR_RESUME  := Color(0.7, 0.3, 1.0)

const H_SPACING := 480.0
const V_SPACING := 280.0

@onready var _status_label:   Label         = %StatusLabel
@onready var _refresh_button: Button        = %RefreshButton
@onready var _graph:          GraphEdit     = %GraphEdit
@onready var _detail_content: VBoxContainer = %DetailContent

var _parser  := SceneParser.new()
var _scenes:   Dictionary = {}
var _outgoing: Dictionary = {}


func _ready() -> void:
	_refresh_button.pressed.connect(_on_refresh_pressed)
	_graph.node_selected.connect(_on_node_selected)
	_graph.gui_input.connect(_on_graph_gui_input)
	_graph.connection_request.connect(_on_connection_request)
	_graph.disconnection_request.connect(_on_disconnection_request)
	_graph.delete_nodes_request.connect(_on_delete_nodes_request)


func _on_refresh_pressed() -> void:
	_scenes = _parser.parse_all()
	if _parser.error_message != "":
		_status_label.text = "Erreur : " + _parser.error_message
		return
	_status_label.text = "%d scènes chargées" % _scenes.size()
	await _rebuild_graph(_scenes)


func _rebuild_graph(scenes: Dictionary) -> void:
	# Ne supprimer que les GraphNode — le connection_layer de GraphEdit doit rester intact
	for child in _graph.get_children():
		if child is GraphNode:
			child.free()
	_graph.clear_connections()

	var outgoing := _build_outgoing(scenes)
	_outgoing = outgoing
	var positions := _compute_layout(scenes, outgoing)

	# Scènes qui ont au moins une connexion entrante
	var has_incoming: Dictionary = {}
	for sid in outgoing:
		for conn in outgoing[sid]:
			if scenes.has(conn.target):
				has_incoming[conn.target] = true

	for scene_id in scenes:
		var scene: Dictionary = scenes[scene_id]
		var is_start:    bool = scene_id == _parser.start_scene
		var is_dead_end: bool = outgoing.get(scene_id, []).is_empty() and not scene.has("free_input")
		var is_isolated: bool = not is_start and not has_incoming.has(scene_id)
		var node := _create_graph_node(scene_id, scene, outgoing.get(scene_id, []),
				is_start, is_dead_end, is_isolated)
		_graph.add_child(node)
		node.position_offset = positions.get(scene_id, Vector2.ZERO)

	for scene_id in outgoing:
		var conns: Array = outgoing[scene_id]
		for port_idx in range(conns.size()):
			var conn = conns[port_idx]
			if scenes.has(conn.target):
				_graph.connect_node(scene_id, port_idx, conn.target, 0)

	await get_tree().process_frame
	_fit_view(positions)


# ---------------------------------------------------------------------------
# Connexions sortantes

func _build_outgoing(scenes: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for scene_id in scenes:
		result[scene_id] = []

	for scene_id in scenes:
		var scene = scenes[scene_id]

		var next = scene.get("next", null)
		if next != null:
			var next_label := "→ next"
			if scene.has("free_input"):
				next_label = "→ après saisie"
			result[scene_id].append({type = "next", target = str(next), label = next_label})

		var choices: Array = scene.get("choices", [])
		for i in range(choices.size()):
			var choice = choices[i]
			var cnext = choice.get("next", null)
			var label: String = str(choice.get("text", "…"))
			var flag: String = str(choice.get("flag", ""))
			if flag != "":
				label += "  [%s]" % flag
			var req = choice.get("requires_flag", choice.get("condition", null))
			if req != null:
				label += "  ?"
			result[scene_id].append({
				type = "choice",
				target = str(cnext) if cnext != null else "",
				label = label,
				choice_index = i
			})

	for scene_id in scenes:
		var trigger_src = scenes[scene_id].get("trigger_after_scene", null)
		if trigger_src == null:
			continue
		var src := str(trigger_src)
		if not result.has(src):
			result[src] = []
		result[src].append({type = "trigger", target = scene_id, label = "⚡ depuis: %s" % scene_id})

	var flag_setters: Dictionary = {}
	for scene_id in scenes:
		for choice in scenes[scene_id].get("choices", []):
			var flag = choice.get("flag", null)
			if flag != null and not flag_setters.has(str(flag)):
				flag_setters[str(flag)] = scene_id

	for scene_id in scenes:
		var resume_flag = scenes[scene_id].get("resume_after_flag", null)
		if resume_flag == null:
			continue
		var setter: String = flag_setters.get(str(resume_flag), "")
		if setter != "":
			result[setter].append({type = "resume", target = scene_id, label = "⏱ " + str(resume_flag)})

	return result


# ---------------------------------------------------------------------------
# Layout

func _compute_layout(scenes: Dictionary, outgoing: Dictionary) -> Dictionary:
	var positions: Dictionary = {}
	if scenes.is_empty():
		return positions

	var start := _parser.start_scene
	if start.is_empty() or not scenes.has(start):
		start = scenes.keys()[0]

	var col_of: Dictionary = {}
	var queue: Array = [start]
	col_of[start] = 0
	while queue.size() > 0:
		var current: String = queue.pop_front()
		for conn in outgoing.get(current, []):
			var target: String = conn.target
			if scenes.has(target) and not col_of.has(target):
				col_of[target] = col_of[current] + 1
				queue.append(target)

	for scene_id in scenes:
		if not col_of.has(scene_id):
			col_of[scene_id] = -1

	var row_count: Dictionary = {}
	for scene_id in scenes:
		var col: int = col_of[scene_id]
		if not row_count.has(col):
			row_count[col] = 0
		positions[scene_id] = Vector2(col * H_SPACING, row_count[col] * V_SPACING)
		row_count[col] += 1

	return positions


func _fit_view(positions: Dictionary) -> void:
	if positions.is_empty() or _graph.size.x < 10:
		return
	var max_x := 0.0
	var max_y := 0.0
	for pos: Vector2 in positions.values():
		max_x = maxf(max_x, pos.x + 260.0)
		max_y = maxf(max_y, pos.y + 220.0)
	var new_zoom := clampf(
		minf(_graph.size.x / (max_x + 60.0), _graph.size.y / (max_y + 60.0)),
		_graph.zoom_min, _graph.zoom_max
	)
	_graph.zoom = new_zoom
	_graph.scroll_offset = Vector2.ZERO


# ---------------------------------------------------------------------------
# Nœuds du graphe

func _create_graph_node(scene_id: String, scene: Dictionary, conns: Array,
		is_start: bool = false, is_dead_end: bool = false, is_isolated: bool = false) -> GraphNode:
	var node := GraphNode.new()

	# Titre avec indicateurs
	var title := scene_id
	if is_start:
		title = "▶  " + title
	if scene.has("free_input"):
		title += "  ✎"
	node.title = title
	node.name  = scene_id
	node.custom_minimum_size = Vector2(220, 0)
	node.gui_input.connect(func(event: InputEvent) -> void:
		if not (event is InputEventMouseButton):
			return
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			node.get_viewport().set_input_as_handled()
			var popup := PopupMenu.new()
			popup.add_item(_t("Supprimer cette scène", "Delete this scene"), 0)
			var has_connected := false
			for i in range(conns.size()):
				if conns[i].get("target", "") != "":
					if not has_connected:
						popup.add_separator()
						has_connected = true
					var lbl: String = _t("Déconnecter : ", "Disconnect: ") + str(conns[i].label) + " → " + str(conns[i].target)
					popup.add_item(lbl, 100 + i)
			add_child(popup)
			popup.id_pressed.connect(func(id: int) -> void:
				if id == 0:
					_on_delete_nodes_request([StringName(scene_id)])
				elif id >= 100:
					_write_disconnection_to_file(scene_id, id - 100)
				popup.queue_free())
			popup.popup_on_parent(Rect2(node.global_position + mb.position, Vector2.ZERO)))

	# Slot 0 : contact — port d'entrée
	var contact_label := Label.new()
	contact_label.text = scene.get("contact_id", "—")
	contact_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	node.add_child(contact_label)
	node.set_slot(0, true, 0, Color.WHITE, false, 0, Color.WHITE)

	var slot_idx := 1

	if conns.is_empty():
		# Port "→ ?" : permet de tirer une connexion depuis une scène sans sortie
		var placeholder := Label.new()
		placeholder.text = "→ ?"
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		placeholder.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		node.add_child(placeholder)
		node.set_slot(slot_idx, false, 0, Color.WHITE, true, 0, COLOR_NORMAL)
		slot_idx += 1
	else:
		for i in range(conns.size()):
			var conn = conns[i]
			var lbl := Label.new()
			lbl.text = conn.label
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			node.add_child(lbl)
			node.set_slot(slot_idx, false, 0, Color.WHITE, true, 0, _port_color(conn.type))
			slot_idx += 1

	# Indicateur de statut (pas de port)
	if is_dead_end or is_isolated:
		var status := Label.new()
		if is_dead_end:
			status.text = _t("⛔ Fin de parcours", "⛔ Dead end")
			status.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		else:
			status.text = _t("⚠ Isolée", "⚠ Isolated")
			status.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		node.add_child(status)
		node.set_slot(slot_idx, false, 0, Color.WHITE, false, 0, Color.WHITE)

	return node


func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, _to_port: int) -> void:
	var from_id := str(from_node)
	var to_id   := str(to_node)
	if from_id == to_id:
		return
	_write_connection_to_file(from_id, from_port, to_id)


func _on_disconnection_request(from_node: StringName, from_port: int, _to_node: StringName, _to_port: int) -> void:
	_write_disconnection_to_file(str(from_node), from_port)


func _on_delete_nodes_request(nodes: Array[StringName]) -> void:
	if nodes.is_empty():
		return
	var ids: Array[String] = []
	for n in nodes:
		ids.append(str(n))
	var label := ", ".join(ids)
	var dialog := ConfirmationDialog.new()
	dialog.title = _t("Supprimer des scènes", "Delete scenes")
	dialog.dialog_text = _t(
		"Supprimer %s ?\nLes liens vers ces scènes seront effacés." % label,
		"Delete %s?\nLinks to these scenes will be removed." % label)
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		dialog.queue_free()
		_delete_scenes(ids))
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	dialog.popup_centered()


func _write_connection_to_file(from_id: String, from_port: int, to_id: String) -> void:
	var from_scene: Dictionary = _scenes.get(from_id, {})
	if from_scene.is_empty():
		return

	var file_name: String = from_scene.get("_editor_file", "")
	if file_name.is_empty():
		_status_label.text = _t("Erreur : fichier source introuvable", "Error: source file not found")
		return

	var conns: Array = _outgoing.get(from_id, [])

	var update_type  := ""
	var choice_index := -1

	if conns.is_empty():
		update_type = "next"
	elif from_port < conns.size():
		var conn = conns[from_port]
		match conn.type:
			"next":
				update_type = "next"
			"choice":
				update_type   = "choice"
				choice_index  = conn.get("choice_index", -1)
			_:
				_status_label.text = _t(
					"Connexion en lecture seule (trigger/resume)",
					"Read-only connection (trigger/resume)")
				return
	else:
		return

	var path := "res://dialogues/" + file_name
	var read_file := FileAccess.open(path, FileAccess.READ)
	if read_file == null:
		_status_label.text = _t("Erreur lecture : " + file_name, "Read error: " + file_name)
		return
	var content := read_file.get_as_text()
	read_file.close()

	var data = JSON.parse_string(content)
	if not data is Dictionary or not data.has("scenes"):
		return

	var modified := false
	for i in range((data["scenes"] as Array).size()):
		if (data["scenes"] as Array)[i].get("id", "") != from_id:
			continue
		if update_type == "next":
			(data["scenes"] as Array)[i]["next"] = to_id
			modified = true
		elif update_type == "choice" and choice_index >= 0:
			var choices: Array = (data["scenes"] as Array)[i].get("choices", [])
			if choice_index < choices.size():
				choices[choice_index]["next"] = to_id
				modified = true
		break

	if not modified:
		return

	if not _write_json(path, data):
		_status_label.text = _t("Erreur écriture : " + file_name, "Write error: " + file_name)
		return
	_on_refresh_pressed()


func _write_disconnection_to_file(from_id: String, from_port: int) -> void:
	var from_scene: Dictionary = _scenes.get(from_id, {})
	var file_name: String = from_scene.get("_editor_file", "")
	if file_name.is_empty():
		return

	var conns: Array = _outgoing.get(from_id, [])
	var update_type := ""
	var choice_index := -1
	if from_port < conns.size():
		var conn = conns[from_port]
		match conn.type:
			"next":
				update_type = "next"
			"choice":
				update_type  = "choice"
				choice_index = conn.get("choice_index", -1)
			_:
				return
	else:
		return

	var path := "res://dialogues/" + file_name
	var read_file := FileAccess.open(path, FileAccess.READ)
	if read_file == null:
		_status_label.text = _t("Erreur lecture : " + file_name, "Read error: " + file_name)
		return
	var content := read_file.get_as_text()
	read_file.close()

	var data = JSON.parse_string(content)
	if not data is Dictionary or not data.has("scenes"):
		return

	var modified := false
	for i in range((data["scenes"] as Array).size()):
		if (data["scenes"] as Array)[i].get("id", "") != from_id:
			continue
		if update_type == "next":
			(data["scenes"] as Array)[i].erase("next")
			modified = true
		elif update_type == "choice" and choice_index >= 0:
			var choices: Array = (data["scenes"] as Array)[i].get("choices", [])
			if choice_index < choices.size():
				choices[choice_index].erase("next")
				modified = true
		break

	if not modified:
		return
	if not _write_json(path, data):
		_status_label.text = _t("Erreur écriture : " + file_name, "Write error: " + file_name)
		return
	_on_refresh_pressed()


func _delete_scenes(ids: Array[String]) -> void:
	var id_set := {}
	for id in ids:
		id_set[id] = true

	var files_data: Dictionary = {}
	for fname in _parser.chosen_files.values():
		var path: String = "res://dialogues/" + str(fname)
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		var data = JSON.parse_string(f.get_as_text())
		f.close()
		if data is Dictionary and data.has("scenes"):
			files_data[fname] = data

	for file_name in files_data:
		var data: Dictionary = files_data[file_name]
		var new_scenes: Array = []
		var modified := false
		for scene in (data["scenes"] as Array):
			var sid: String = scene.get("id", "")
			if id_set.has(sid):
				modified = true
				continue
			if scene.has("next") and id_set.has(str(scene["next"])):
				scene.erase("next")
				modified = true
			if scene.has("trigger_after_scene") and id_set.has(str(scene["trigger_after_scene"])):
				scene.erase("trigger_after_scene")
				modified = true
			if scene.has("choices"):
				for choice in (scene["choices"] as Array):
					if choice.has("next") and id_set.has(str(choice["next"])):
						choice.erase("next")
						modified = true
			new_scenes.append(scene)
		if modified:
			data["scenes"] = new_scenes
			if not _write_json("res://dialogues/" + file_name, data):
				_status_label.text = _t("Erreur écriture : " + file_name, "Write error: " + file_name)
				return

	_on_refresh_pressed()


func _on_graph_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_show_create_scene_dialog()


func _show_create_scene_dialog() -> void:
	if _parser.chosen_files.is_empty():
		_status_label.text = _t("Cliquez d'abord sur Refresh", "Click Refresh first")
		return

	var dialog := ConfirmationDialog.new()
	dialog.title = _t("Nouvelle scène", "New scene")
	dialog.min_size = Vector2(320, 10)
	add_child(dialog)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	dialog.add_child(vbox)

	# Champ ID
	var id_label := Label.new()
	id_label.text = "ID"
	vbox.add_child(id_label)
	var id_field := LineEdit.new()
	id_field.placeholder_text = _t("ex : scene_10", "e.g. scene_10")
	vbox.add_child(id_field)

	# Liste déroulante contact
	var contact_label := Label.new()
	contact_label.text = _t("Contact", "Contact")
	vbox.add_child(contact_label)
	var contact_option := OptionButton.new()
	var contact_ids: Array = []
	for c in _parser.contacts:
		contact_option.add_item(c.get("name", c.get("id", "?")))
		contact_ids.append(c.get("id", ""))
	vbox.add_child(contact_option)

	# Liste déroulante fichier (seulement si plusieurs fichiers)
	var file_option: OptionButton = null
	var file_names: Array = []
	for fname in _parser.chosen_files.values():
		file_names.append(fname)
	if file_names.size() > 1:
		var file_label := Label.new()
		file_label.text = _t("Fichier", "File")
		vbox.add_child(file_label)
		file_option = OptionButton.new()
		for fname in file_names:
			file_option.add_item(fname)
		vbox.add_child(file_option)

	dialog.popup_centered()
	id_field.grab_focus()

	dialog.confirmed.connect(func() -> void:
		var scene_id: String = id_field.text.strip_edges()
		if scene_id.is_empty():
			_status_label.text = _t("Erreur : ID vide", "Error: empty ID")
			dialog.queue_free()
			return
		if _scenes.has(scene_id):
			_status_label.text = _t(
				"Erreur : ID \"%s\" déjà utilisé" % scene_id,
				"Error: ID \"%s\" already exists" % scene_id)
			dialog.queue_free()
			return
		var contact_id: String = contact_ids[contact_option.selected] if contact_ids.size() > 0 else ""
		var file_name: String = file_names[file_option.selected] if file_option != null else file_names[0]
		dialog.queue_free()
		_write_scene_to_file(scene_id, contact_id, file_name)
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())


func _write_scene_to_file(scene_id: String, contact_id: String, file_name: String) -> void:
	var path := "res://dialogues/" + file_name

	var read_file := FileAccess.open(path, FileAccess.READ)
	if read_file == null:
		_status_label.text = _t("Erreur lecture : " + file_name, "Read error: " + file_name)
		return
	var content := read_file.get_as_text()
	read_file.close()

	var data = JSON.parse_string(content)
	if not data is Dictionary or not data.has("scenes"):
		_status_label.text = _t("JSON invalide dans " + file_name, "Invalid JSON in " + file_name)
		return

	var main_contact_id := ""
	for c in _parser.contacts:
		if c.get("is_main", false):
			main_contact_id = c.get("id", "")
			break

	var new_scene: Dictionary = { "id": scene_id, "messages_in": [{ "text": "" }] }
	if contact_id != main_contact_id:
		new_scene["contact_id"] = contact_id
	data["scenes"].append(new_scene)

	if not _write_json(path, data):
		_status_label.text = _t("Erreur écriture : " + file_name, "Write error: " + file_name)
		return
	_on_refresh_pressed()


func _write_json(path: String, data: Dictionary) -> bool:
	var ordered_scenes: Array = []
	for s in (data["scenes"] as Array):
		ordered_scenes.append(_ordered_scene(s))
	data["scenes"] = ordered_scenes
	var write_file := FileAccess.open(path, FileAccess.WRITE)
	if write_file == null:
		return false
	write_file.store_string(_json_stringify_file(data))
	write_file.close()
	return true


func _json_stringify_file(data: Dictionary) -> String:
	return _json_expand(data, "") + "\n"


func _json_expand(value, indent: String) -> String:
	if indent.length() >= 4:
		return JSON.stringify(value)
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


func _ordered_scene(scene: Dictionary) -> Dictionary:
	const SCENE_KEYS := ["_notes", "id", "contact_id", "trigger_after_scene",
		"resume_after_flag", "resume_after_delay", "messages_in",
		"free_input", "free_input_placeholder", "music", "next", "choices"]
	var result := {}
	for key in SCENE_KEYS:
		if scene.has(key):
			result[key] = scene[key]
	for key in scene:
		if key != "_editor_file" and not result.has(key):
			result[key] = scene[key]
	return result


func _t(fr: String, en: String) -> String:
	return fr if OS.get_locale_language() == "fr" else en


func _port_color(conn_type: String) -> Color:
	match conn_type:
		"trigger": return COLOR_TRIGGER
		"resume":  return COLOR_RESUME
		_:         return COLOR_NORMAL


# ---------------------------------------------------------------------------
# Panneau de détail

func _on_node_selected(node: Node) -> void:
	if not (node is GraphNode):
		return
	var scene_id: String = node.name
	_populate_detail(scene_id, _scenes.get(scene_id, {}))


func _populate_detail(scene_id: String, scene: Dictionary) -> void:
	for child in _detail_content.get_children():
		child.free()

	_add_header(scene_id)
	var contact_id: String = scene.get("contact_id", "")
	var contact_name := contact_id
	for c in _parser.contacts:
		if c.get("id", "") == contact_id:
			contact_name = c.get("name", contact_id)
			break
	_add_row(_t("Contact", "Contact"), contact_name if contact_name else "—")

	var msgs: Array = scene.get("messages_in", [])
	if msgs.size() > 0:
		_add_section("%s (%d)" % [_t("Messages", "Messages"), msgs.size()])
		for msg in msgs:
			var text = msg.get("text", "")
			if text is Array:
				text = " / ".join(text)
			var line := str(text)
			var pause = msg.get("pause", "")
			if pause:
				line += "  [pause : %s]" % pause
			if msg.get("requires_flag", "") != "":
				line += "  (%s %s)" % [_t("si", "if"), msg["requires_flag"]]
			_add_item(line)
			for effect in msg.get("effects", []):
				_add_effect(effect)

	var choices: Array = scene.get("choices", [])
	if choices.size() > 0:
		_add_section("%s (%d)" % [_t("Choix", "Choices"), choices.size()])
		for c in choices:
			var line := str(c.get("text", "?"))
			var cnext = c.get("next", "")
			if cnext:
				line += " → " + cnext
			var cflag = c.get("flag", "")
			if cflag:
				line += "  [%s]" % cflag
			_add_item(line)
			for effect in c.get("effects", []):
				_add_effect(effect)

	var specials: Array = []
	for key in ["free_input", "next", "trigger_after_scene", "resume_after_flag", "music"]:
		if scene.has(key):
			specials.append("%s: %s" % [key, str(scene[key])])
	if specials.size() > 0:
		_add_section(_t("Spécial", "Special"))
		for s in specials:
			_add_item(s)


func _add_header(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_content.add_child(lbl)


func _add_row(key: String, value: String) -> void:
	var lbl := Label.new()
	lbl.text = "%s: %s" % [key, value]
	lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_content.add_child(lbl)


func _add_section(title: String) -> void:
	_detail_content.add_child(HSeparator.new())
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_color_override("font_color", Color(0.55, 0.85, 0.55))
	_detail_content.add_child(lbl)


func _add_item(text: String) -> void:
	var lbl := Label.new()
	lbl.text = "  " + text
	lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_content.add_child(lbl)


func _add_effect(effect: Dictionary) -> void:
	var lbl := Label.new()
	lbl.text = "    " + _effect_label(effect)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_content.add_child(lbl)


func _effect_label(effect: Dictionary) -> String:
	var op: String = effect.get("op", "")
	match op:
		"rename":
			return _t(
				'⟳ "%s" renommé en "%s"' % [effect.get("contact", "?"), effect.get("value", "?")],
				'⟳ "%s" renamed to "%s"' % [effect.get("contact", "?"), effect.get("value", "?")]
			)
		"set_status":
			return _t(
				'● %s — status : %s' % [effect.get("contact", "?"), effect.get("value", "?")],
				'● %s — status: %s'  % [effect.get("contact", "?"), effect.get("value", "?")]
			)
		"set":
			return '= %s := %s' % [effect.get("var", "?"), effect.get("value", "?")]
		"add":
			return '+ %s += %s' % [effect.get("var", "?"), effect.get("value", "?")]
		"sub":
			return '- %s -= %s' % [effect.get("var", "?"), effect.get("value", "?")]
		_:
			return op
