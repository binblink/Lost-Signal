@tool
extends Control

const SceneParser = preload("res://addons/story_editor/scene_parser.gd")

const COLOR_NORMAL  := Color(0.8, 0.8, 0.8)
const COLOR_TRIGGER := Color(1.0, 0.6, 0.0)
const COLOR_RESUME  := Color(0.7, 0.3, 1.0)

const H_SPACING := 480.0
const V_SPACING := 280.0

@onready var _status_label:    Label         = %StatusLabel
@onready var _refresh_button:  Button        = %RefreshButton
@onready var _reformat_button: Button        = %ReformatButton
@onready var _graph:           GraphEdit     = %GraphEdit
@onready var _detail_content:  VBoxContainer = %DetailContent

const STRIPE_A := Color(0.18, 0.18, 0.22)
const STRIPE_B := Color(0.11, 0.11, 0.13)

var _parser  := SceneParser.new()
var _scenes:   Dictionary = {}
var _outgoing: Dictionary = {}
var _selected_scene_id: String = ""
var _target: VBoxContainer = null

func _s() -> VBoxContainer:
	return _target if _target != null else _detail_content

func _begin_stripe(index: int) -> void:
	var stripe := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = STRIPE_A if index % 2 == 0 else STRIPE_B
	style.set_content_margin_all(6)
	stripe.add_theme_stylebox_override("panel", style)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	stripe.add_child(inner)
	_detail_content.add_child(stripe)
	_target = inner

func _end_stripe() -> void:
	_target = null


func _ready() -> void:
	_refresh_button.pressed.connect(_on_refresh_pressed)
	_reformat_button.pressed.connect(_on_reformat_pressed)
	_graph.node_selected.connect(_on_node_selected)
	_graph.gui_input.connect(_on_graph_gui_input)
	_graph.connection_request.connect(_on_connection_request)
	_graph.disconnection_request.connect(_on_disconnection_request)
	_graph.delete_nodes_request.connect(_on_delete_nodes_request)
	var detach_btn := Button.new()
	detach_btn.text = "🗗"
	detach_btn.tooltip_text = _t(
		"Ouvrir dans une fenêtre séparée.\nLa fenêtre peut être mise en plein écran.",
		"Open in a separate window.\nThe window can be maximized.")
	detach_btn.pressed.connect(_on_detach_pressed)
	_refresh_button.get_parent().add_child(detach_btn)


func _on_detach_pressed() -> void:
	var win := Window.new()
	win.title = "Story Editor"
	win.size = Vector2i(1400, 900)
	win.wrap_controls = true
	win.close_requested.connect(func() -> void: win.queue_free())
	var new_panel = preload("res://addons/story_editor/StoryEditorPanel.tscn").instantiate()
	win.add_child(new_panel)
	get_tree().get_root().add_child(win)
	win.popup_centered()
	new_panel._on_refresh_pressed()


func _on_reformat_pressed() -> void:
	if _parser.chosen_files.is_empty():
		_status_label.text = _t("Cliquez d'abord sur Refresh", "Click Refresh first")
		return
	for fname in _parser.chosen_files.values():
		var path: String = "res://dialogues/" + str(fname)
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		var data = JSON.parse_string(f.get_as_text())
		f.close()
		if data is Dictionary and data.has("scenes"):
			_write_json(path, data)
	_on_refresh_pressed()


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
		contact_option.add_item(c.get("id", "?"))
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
	if result.has("messages_in"):
		var ordered_msgs: Array = []
		for msg in (result["messages_in"] as Array):
			ordered_msgs.append(_ordered_message(msg))
		result["messages_in"] = ordered_msgs
	if result.has("choices"):
		var ordered_choices: Array = []
		for choice in (result["choices"] as Array):
			ordered_choices.append(_ordered_choice(choice))
		result["choices"] = ordered_choices
	return result


func _ordered_message(msg: Dictionary) -> Dictionary:
	const MSG_KEYS := ["text", "edit", "effects", "media", "pause",
		"requires_flag", "condition", "corrupted", "time"]
	var result := {}
	for key in MSG_KEYS:
		if msg.has(key):
			result[key] = msg[key]
	for key in msg:
		if not result.has(key):
			result[key] = msg[key]
	return result


func _ordered_choice(choice: Dictionary) -> Dictionary:
	const CHOICE_KEYS := ["text", "message", "flag", "requires_flag", "condition", "next", "effects"]
	var result := {}
	for key in CHOICE_KEYS:
		if choice.has(key):
			result[key] = choice[key]
	for key in choice:
		if not result.has(key):
			result[key] = choice[key]
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

func _collect_vars() -> Array:
	var result: Array = []
	for sid in _scenes:
		var sc: Dictionary = _scenes[sid]
		var fi = sc.get("free_input", null)
		if fi != null and not result.has(str(fi)):
			result.append(str(fi))
		for msg in sc.get("messages_in", []):
			for eff in msg.get("effects", []):
				var v = eff.get("var", null)
				if v != null and str(v) and not result.has(str(v)):
					result.append(str(v))
		for ch in sc.get("choices", []):
			for eff in ch.get("effects", []):
				var v = eff.get("var", null)
				if v != null and str(v) and not result.has(str(v)):
					result.append(str(v))
	result.sort()
	return result


func _collect_flags() -> Array:
	var flags: Array = []
	for sid in _scenes:
		for ch in _scenes[sid].get("choices", []):
			var f = ch.get("flag", null)
			if f != null and not flags.has(str(f)):
				flags.append(str(f))
	flags.sort()
	return flags


func _get_main_contact_id() -> String:
	for c in _parser.contacts:
		if c.get("is_main", false):
			return c.get("id", "")
	return ""


func _on_node_selected(node: Node) -> void:
	if not (node is GraphNode):
		return
	_selected_scene_id = node.name
	_populate_detail(_selected_scene_id)


func _populate_detail(scene_id: String) -> void:
	for child in _detail_content.get_children():
		child.free()

	var scene: Dictionary = _scenes.get(scene_id, {})

	_add_header(scene_id)

	# Dropdown contact
	var main_cid := _get_main_contact_id()
	var current_contact_id: String = scene.get("contact_id", main_cid)
	var contact_id_list: Array = []
	var contact_opts := OptionButton.new()
	for ci in range(_parser.contacts.size()):
		var c = _parser.contacts[ci]
		contact_opts.add_item(c.get("id", "?"))
		var cid: String = c.get("id", "")
		contact_id_list.append(cid)
		if cid == current_contact_id:
			contact_opts.selected = ci
	_detail_content.add_child(contact_opts)
	contact_opts.item_selected.connect(func(idx: int) -> void:
		var new_cid: String = contact_id_list[idx]
		_patch_field(scene_id, func(s: Dictionary) -> void:
			if new_cid == _get_main_contact_id():
				s.erase("contact_id")
			else:
				s["contact_id"] = new_cid)
		call_deferred("_populate_detail", scene_id)
		_on_refresh_pressed())

	_add_section(_t("Déclenchement", "Trigger"), Color(0.18, 0.13, 0.22))
	_add_scene_id_dropdown(
		_t("↩ après", "↩ after"),
		str(scene.get("trigger_after_scene", "")),
		_t("(aucun)", "(none)"),
		_t("Cette scène se déclenche automatiquement quand la scène sélectionnée vient d'être jouée, sans intervention du joueur.",
			"This scene triggers automatically after the selected scene has played, with no player input."),
		func(val: String) -> void:
			_patch_field(scene_id, func(s: Dictionary) -> void:
				if val.is_empty():
					s.erase("trigger_after_scene")
				else:
					s["trigger_after_scene"] = val))
	var resume_flag_val: String = str(scene.get("resume_after_flag", ""))
	var rf_all_flags := _collect_flags()
	if resume_flag_val and not rf_all_flags.has(resume_flag_val):
		rf_all_flags.append(resume_flag_val)
		rf_all_flags.sort()
	var rf_row := HBoxContainer.new()
	var rf_lbl := Label.new()
	rf_lbl.text = _t("🚩 si flag", "🚩 on flag")
	rf_lbl.custom_minimum_size = Vector2(56, 0)
	rf_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rf_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	rf_row.add_child(rf_lbl)
	var rf_opts := OptionButton.new()
	rf_opts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rf_opts.tooltip_text = _t(
		"Cette scène attend en coulisse jusqu'à ce que le flag choisi soit activé par un choix du joueur — puis elle se déclenche automatiquement.",
		"This scene waits in the background until the selected flag is set by a player choice — then it triggers automatically.")
	rf_opts.add_item(_t("(aucun)", "(none)"))
	var rf_sel := 0
	for fi in range(rf_all_flags.size()):
		rf_opts.add_item(rf_all_flags[fi])
		if rf_all_flags[fi] == resume_flag_val:
			rf_sel = fi + 1
	rf_opts.selected = rf_sel
	rf_opts.item_selected.connect(func(idx: int) -> void:
		_patch_field(scene_id, func(s: Dictionary) -> void:
			if idx == 0:
				s.erase("resume_after_flag")
			else:
				s["resume_after_flag"] = rf_all_flags[idx - 1]))
	rf_row.add_child(rf_opts)
	_detail_content.add_child(rf_row)
	_add_line_edit_row(
		_t("⏱ délai", "⏱ delay"),
		str(scene.get("resume_after_delay", "")),
		_t("(ex: 5m, 1h, 300)", "(ex: 5m, 1h, 300)"),
		func(val: String) -> void:
			_patch_field(scene_id, func(s: Dictionary) -> void:
				if val.is_empty():
					s.erase("resume_after_delay")
				elif val.is_valid_int():
					s["resume_after_delay"] = int(val)
				else:
					s["resume_after_delay"] = val),
		_t("Délai avant que cette scène continue automatiquement vers la suivante. Accepte 300 (secondes), \"5m\" ou \"1h\". Le délai reprend même après fermeture du jeu.",
			"Delay before this scene auto-continues. Accepts 300 (seconds), \"5m\" or \"1h\". The timer persists across game restarts."))
	var msgs: Array = scene.get("messages_in", [])
	_add_section("%s (%d)" % [_t("Messages", "Messages"), msgs.size()], Color(0.10, 0.18, 0.30))
	for i in range(msgs.size()):
		var msg_idx := i
		var msg = msgs[i]
		var text = msg.get("text", "")
		_begin_stripe(i)
		var media = msg.get("media", null)
		var req_flag: String = str(msg.get("requires_flag", ""))
		_add_req_flag_dropdown(req_flag, func(val: String) -> void:
			_patch_field(scene_id, func(s: Dictionary) -> void:
				var m: Dictionary = (s["messages_in"] as Array)[msg_idx]
				if val.is_empty():
					m.erase("requires_flag")
				else:
					m["requires_flag"] = val),
			_t("Ce message ne s'affiche que si le flag sélectionné a été activé par un choix précédent du joueur.",
				"This message only appears if the selected flag was set by a previous player choice."))
		if text is Array:
			var del_row := HBoxContainer.new()
			var arr_lbl := Label.new()
			arr_lbl.text = _t("[tableau]", "[array]")
			arr_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			del_row.add_child(arr_lbl)
			var del_btn := Button.new()
			del_btn.text = "×"
			del_btn.custom_minimum_size = Vector2(28, 0)
			del_btn.pressed.connect(func() -> void:
				_patch_field(scene_id, func(s: Dictionary) -> void:
					(s["messages_in"] as Array).remove_at(msg_idx))
				call_deferred("_populate_detail", scene_id))
			del_row.add_child(del_btn)
			_s().add_child(del_row)
			for j in range((text as Array).size()):
				var elem = (text as Array)[j]
				if elem is String:
					var text_idx := j
					_add_text_edit(str(elem), func(val: String) -> void:
						_patch_field(scene_id, func(s: Dictionary) -> void:
							((s["messages_in"] as Array)[msg_idx]["text"] as Array)[text_idx] = val))
				else:
					var d := elem as Dictionary
					_add_item("  " + str(d.get("text", "?")))
			var add_sub_btn := Button.new()
			add_sub_btn.text = _t("+ bulle", "+ bubble")
			add_sub_btn.tooltip_text = _t(
				"Ajoute une bulle supplémentaire à ce message en tableau.",
				"Adds another bubble to this array message.")
			add_sub_btn.pressed.connect(func() -> void:
				_patch_field(scene_id, func(s: Dictionary) -> void:
					((s["messages_in"] as Array)[msg_idx]["text"] as Array).append(""))
				call_deferred("_populate_detail", scene_id))
			_s().add_child(add_sub_btn)
		elif media != null:
			var media_row := HBoxContainer.new()
			var media_lbl := Label.new()
			var mpath: String = str(media.get("path", "?")) if media is Dictionary else str(media)
			media_lbl.text = "📷 " + mpath.get_file()
			media_lbl.tooltip_text = mpath
			media_lbl.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
			media_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			media_row.add_child(media_lbl)
			var media_del := Button.new()
			media_del.text = "×"
			media_del.tooltip_text = _t(
				"Retire ce message de la scène.\nLe fichier image n'est pas supprimé.",
				"Removes this message from the scene.\nThe image file is not deleted.")
			media_del.custom_minimum_size = Vector2(28, 28)
			media_del.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			media_del.pressed.connect(func() -> void:
				_patch_field(scene_id, func(s: Dictionary) -> void:
					(s["messages_in"] as Array).remove_at(msg_idx))
				call_deferred("_populate_detail", scene_id))
			media_row.add_child(media_del)
			_s().add_child(media_row)
		else:
			_add_text_edit_row(str(text) if text != null else "",
				func(val: String) -> void:
					_patch_field(scene_id, func(s: Dictionary) -> void:
						(s["messages_in"] as Array)[msg_idx]["text"] = val),
				func() -> void:
					_patch_field(scene_id, func(s: Dictionary) -> void:
						(s["messages_in"] as Array).remove_at(msg_idx))
					call_deferred("_populate_detail", scene_id),
				_t("✉ texte", "✉ text"))
		for k in range(msg.get("edit", []).size()):
			var edit_op: Dictionary = msg["edit"][k]
			var edit_idx := k
			var op: String = edit_op.get("type", "")
			var delay: float = edit_op.get("delay", 0.0)
			match op:
				"correct":
					_add_item(_t("  ✎ corrigé en (+%.1fs) :" % delay, "  ✎ corrected to (+%.1fs):" % delay))
					_add_text_edit(str(edit_op.get("corrected_text", "")), func(val: String) -> void:
						_patch_field(scene_id, func(s: Dictionary) -> void:
							((s["messages_in"] as Array)[msg_idx]["edit"] as Array)[edit_idx]["corrected_text"] = val))
				"delete":
					_add_item(_t("  ✗ supprimé (+%.1fs)" % delay, "  ✗ deleted (+%.1fs)" % delay))
		var current_pause: String = str(msg.get("pause", ""))
		_add_pause_dropdown(current_pause, func(sel_idx: int) -> void:
			var pause_vals := ["", "short", "medium", "long"]
			_patch_field(scene_id, func(s: Dictionary) -> void:
				var m: Dictionary = (s["messages_in"] as Array)[msg_idx]
				if sel_idx == 0:
					m.erase("pause")
				else:
					m["pause"] = pause_vals[sel_idx])
			call_deferred("_populate_detail", scene_id))
		var get_msg_effs := func(s: Dictionary) -> Array:
			var m: Dictionary = (s["messages_in"] as Array)[msg_idx]
			if not m.has("effects"):
				m["effects"] = []
			return m["effects"] as Array
		_add_effects_editor(scene_id, msg.get("effects", []), get_msg_effs)
		_end_stripe()

	var msg_btns := HBoxContainer.new()
	var add_msg_btn := Button.new()
	add_msg_btn.text = _t("+ Message", "+ Message")
	add_msg_btn.tooltip_text = _t(
		"Ajoute une seule bulle de texte.",
		"Adds a single text bubble.")
	add_msg_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_msg_btn.pressed.connect(func() -> void:
		_patch_field(scene_id, func(s: Dictionary) -> void:
			if not s.has("messages_in"):
				s["messages_in"] = []
			(s["messages_in"] as Array).append({"text": ""}))
		call_deferred("_populate_detail", scene_id))
	msg_btns.add_child(add_msg_btn)
	var add_arr_btn := Button.new()
	add_arr_btn.text = _t("+ Message [...]", "+ Message [...]")
	add_arr_btn.tooltip_text = _t(
		"Ajoute un message composé de plusieurs bulles successives.\nÀ utiliser quand un personnage envoie plusieurs courts messages à la suite.",
		"Adds a message made of several consecutive bubbles.\nUse this when a character sends multiple short messages in a row.")
	add_arr_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_arr_btn.pressed.connect(func() -> void:
		_patch_field(scene_id, func(s: Dictionary) -> void:
			if not s.has("messages_in"):
				s["messages_in"] = []
			(s["messages_in"] as Array).append({"text": [""]}))
		call_deferred("_populate_detail", scene_id))
	msg_btns.add_child(add_arr_btn)
	var add_fi_btn := Button.new()
	add_fi_btn.text = _t("+ Saisie libre", "+ Free input")
	add_fi_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_fi_btn.tooltip_text = _t(
		"Ajoute un champ de saisie libre : le joueur tape une réponse au lieu de choisir parmi des options. La réponse est stockée dans une variable réutilisable dans les messages suivants.",
		"Adds a free text input: the player types a reply instead of picking a choice. The answer is stored in a variable you can reuse in later messages.")
	if scene.has("free_input"):
		add_fi_btn.disabled = true
	elif scene.get("choices", []).size() > 0:
		add_fi_btn.disabled = true
		add_fi_btn.tooltip_text = _t(
			"Incompatible avec les choix — un joueur ne peut pas à la fois choisir et taper du texte. Supprimez les choix d'abord.",
			"Incompatible with choices — a player can't both pick and type. Remove the choices first.")
	else:
		add_fi_btn.pressed.connect(func() -> void:
			_patch_field(scene_id, func(s: Dictionary) -> void:
				s["free_input"] = "player_input")
			call_deferred("_populate_detail", scene_id))
	msg_btns.add_child(add_fi_btn)
	_detail_content.add_child(msg_btns)
	if scene.has("free_input"):
		var fi_var_val: String = str(scene.get("free_input", ""))
		var fi_row := HBoxContainer.new()
		var fi_lbl := Label.new()
		fi_lbl.text = _t("📝 var", "📝 var")
		fi_lbl.custom_minimum_size = Vector2(56, 0)
		fi_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
		fi_row.add_child(fi_lbl)
		var fi_edit := LineEdit.new()
		fi_edit.text = fi_var_val
		fi_edit.placeholder_text = "player_input"
		fi_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fi_edit.tooltip_text = _t(
			"Nom de la variable qui recevra le texte tapé par le joueur. Utilisez {nom} dans un message suivant pour l'afficher.",
			"Variable name that stores the player's typed text. Use {name} in a later message to display it.")
		fi_edit.focus_exited.connect(func() -> void:
			var val := fi_edit.text.strip_edges()
			if val == fi_var_val or val.is_empty():
				return
			_patch_field(scene_id, func(s: Dictionary) -> void:
				s["free_input"] = val))
		fi_row.add_child(fi_edit)
		var fi_del := Button.new()
		fi_del.text = "×"
		fi_del.custom_minimum_size = Vector2(28, 28)
		fi_del.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		fi_del.tooltip_text = _t("Supprime la saisie libre de cette scène.", "Removes free input from this scene.")
		fi_del.pressed.connect(func() -> void:
			_patch_field(scene_id, func(s: Dictionary) -> void:
				s.erase("free_input")
				s.erase("free_input_placeholder"))
			call_deferred("_populate_detail", scene_id))
		fi_row.add_child(fi_del)
		_detail_content.add_child(fi_row)
		_add_line_edit_row(
			_t("💬 hint", "💬 hint"),
			str(scene.get("free_input_placeholder", "")),
			_t("(texte indicatif)", "(hint text)"),
			func(val: String) -> void:
				_patch_field(scene_id, func(s: Dictionary) -> void:
					if val.is_empty():
						s.erase("free_input_placeholder")
					else:
						s["free_input_placeholder"] = val),
			_t("Texte affiché en grisé dans le champ de saisie pour guider le joueur.",
				"Greyed-out hint text shown in the input field to guide the player."))

	var choices: Array = scene.get("choices", [])
	_add_section("%s (%d)" % [_t("Choix", "Choices"), choices.size()], Color(0.28, 0.16, 0.08))
	for i in range(choices.size()):
		var choice_idx := i
		var ch = choices[i]
		_begin_stripe(i)
		_add_text_edit_row(str(ch.get("text", "")),
			func(val: String) -> void:
				_patch_field(scene_id, func(s: Dictionary) -> void:
					(s["choices"] as Array)[choice_idx]["text"] = val),
			func() -> void:
				_patch_field(scene_id, func(s: Dictionary) -> void:
					var chs: Array = s["choices"]
					chs.remove_at(choice_idx)
					if chs.is_empty():
						s.erase("choices"))
				call_deferred("_populate_detail", scene_id)
				_on_refresh_pressed(),
			_t("🔘 bouton", "🔘 button"))
		var choice_msg: String = str(ch.get("message", ""))
		_add_line_edit_row(
			_t("💬 msg", "💬 msg"),
			choice_msg,
			_t("(identique au texte du bouton)", "(same as button text)"),
			func(val: String) -> void:
				_patch_field(scene_id, func(s: Dictionary) -> void:
					var cv: Dictionary = (s["choices"] as Array)[choice_idx]
					if val.is_empty():
						cv.erase("message")
					else:
						cv["message"] = val),
			_t(
				"Texte affiché dans la bulle du joueur quand il choisit cette option.\nSi vide, le texte du bouton est utilisé à la place.\n\nMessage simple : \"D'accord\"\nPlusieurs bulles successives, comme dans l'exemple suivant :\n[\"Hmm...\", \"Ouais, d'accord\"]",
				"Text shown in the player's chat bubble when they pick this option.\nIf empty, the button text is used instead.\n\nSimple message: \"Okay\"\nMultiple successive bubbles, as in the following example:\n[\"Hmm...\", \"Yeah, okay\"]"))
		var flag_val: String = str(ch.get("flag", ""))
		_add_line_edit_row(_t("🚩 flag", "🚩 flag"), flag_val,
			_t("(aucun flag)", "(no flag)"),
			func(val: String) -> void:
				_patch_field(scene_id, func(s: Dictionary) -> void:
					var cv: Dictionary = (s["choices"] as Array)[choice_idx]
					if val.is_empty():
						cv.erase("flag")
					else:
						cv["flag"] = val),
			_t("Nom du flag activé quand le joueur choisit cette option. Utilisez-le dans \"? visible si\" d'autres messages ou choix pour les conditionner.",
				"Flag name set when the player picks this choice. Use it in \"? visible if\" on other messages or choices to make them conditional."))
		var req_val: String = str(ch.get("requires_flag", ""))
		_add_req_flag_dropdown(req_val, func(val: String) -> void:
			_patch_field(scene_id, func(s: Dictionary) -> void:
				var cv: Dictionary = (s["choices"] as Array)[choice_idx]
				if val.is_empty():
					cv.erase("requires_flag")
				else:
					cv["requires_flag"] = val),
			_t("Ce choix n'est proposé au joueur que si le flag sélectionné a été activé par un choix précédent.",
				"This choice is only offered to the player if the selected flag was set by a previous choice."))
		var cnext: String = str(ch.get("next", ""))
		_add_scene_id_dropdown(
			_t("→ next", "→ next"),
			cnext,
			_t("(non lié)", "(not linked)"),
			_t("Scène jouée quand le joueur choisit cette option.", "Scene played when the player picks this choice."),
			func(val: String) -> void:
				_patch_field(scene_id, func(s: Dictionary) -> void:
					var cv: Dictionary = (s["choices"] as Array)[choice_idx]
					if val.is_empty():
						cv.erase("next")
					else:
						cv["next"] = val)
				call_deferred("_populate_detail", scene_id)
				_on_refresh_pressed())
		var get_ch_effs := func(s: Dictionary) -> Array:
			var cv: Dictionary = (s["choices"] as Array)[choice_idx]
			if not cv.has("effects"):
				cv["effects"] = []
			return cv["effects"] as Array
		_add_effects_editor(scene_id, ch.get("effects", []), get_ch_effs)
		_end_stripe()

	if choices.size() < 4:
		var add_choice_btn := Button.new()
		add_choice_btn.text = _t("+ Choix", "+ Choice")
		if scene.has("free_input"):
			add_choice_btn.disabled = true
			add_choice_btn.tooltip_text = _t(
				"Incompatible avec la saisie libre — un joueur ne peut pas à la fois choisir et taper du texte. Supprimez la saisie libre d'abord.",
				"Incompatible with free input — a player can't both pick and type. Remove the free input first.")
		else:
			add_choice_btn.tooltip_text = _t(
				"Ajoute un choix (max 4).\nLe lien vers la scène suivante se définit en tirant un port dans le graphe.",
				"Adds a choice (max 4).\nConnect it to the next scene by dragging a port in the graph.")
			add_choice_btn.pressed.connect(func() -> void:
				_patch_field(scene_id, func(s: Dictionary) -> void:
					if not s.has("choices"):
						s["choices"] = []
					if (s["choices"] as Array).size() < 4:
						(s["choices"] as Array).append({"text": ""}))
				call_deferred("_populate_detail", scene_id)
				_on_refresh_pressed())
		_detail_content.add_child(add_choice_btn)

	var specials: Array = []
	for key in ["free_input", "next", "trigger_after_scene", "resume_after_flag", "music"]:
		if scene.has(key):
			specials.append("%s: %s" % [key, str(scene[key])])
	if specials.size() > 0:
		_add_section(_t("Spécial", "Special"))
		for s in specials:
			_add_item(s)


func _add_text_edit(initial: String, on_commit: Callable) -> void:
	var edit := TextEdit.new()
	edit.text = initial
	edit.custom_minimum_size = Vector2(0, 52)
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	edit.scroll_fit_content_height = true
	edit.focus_exited.connect(func() -> void:
		var val := edit.text
		if val != initial:
			on_commit.call(val))
	_s().add_child(edit)


func _add_line_edit_row(label: String, initial: String, placeholder: String, on_commit: Callable, tooltip: String = "") -> void:
	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size = Vector2(56, 0)
	lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	row.add_child(lbl)
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
	_s().add_child(row)


func _add_pause_dropdown(current_pause: String, on_change: Callable) -> void:
	var opts := OptionButton.new()
	opts.add_item(_t("(aucune pause)", "(no pause)"))
	opts.add_item("short")
	opts.add_item("medium")
	opts.add_item("long")
	match current_pause:
		"short":  opts.selected = 1
		"medium": opts.selected = 2
		"long":   opts.selected = 3
		_:        opts.selected = 0
	opts.item_selected.connect(on_change)
	_s().add_child(opts)


func _add_req_flag_dropdown(current: String, on_change: Callable, tooltip: String = "") -> void:
	var all_flags := _collect_flags()
	if current and not all_flags.has(current):
		all_flags.append(current)
		all_flags.sort()
	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = _t("? visible si", "? visible if")
	lbl.custom_minimum_size = Vector2(56, 0)
	lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	row.add_child(lbl)
	var opts := OptionButton.new()
	opts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if tooltip:
		opts.tooltip_text = tooltip
	opts.add_item(_t("(toujours affiché)", "(always shown)"))
	var selected := 0
	for fi in range(all_flags.size()):
		opts.add_item(all_flags[fi])
		if all_flags[fi] == current:
			selected = fi + 1
	opts.selected = selected
	opts.item_selected.connect(func(idx: int) -> void:
		if idx == 0:
			on_change.call("")
		else:
			on_change.call(all_flags[idx - 1]))
	row.add_child(opts)
	_s().add_child(row)


func _add_scene_id_dropdown(label: String, current: String, none_label: String, tooltip: String, on_change: Callable) -> void:
	var all_ids: Array = _scenes.keys()
	all_ids.sort()
	if current and not all_ids.has(current):
		all_ids.append(current)
		all_ids.sort()
	var row := HBoxContainer.new()
	if not label.is_empty():
		var lbl := Label.new()
		lbl.text = label
		lbl.custom_minimum_size = Vector2(56, 0)
		lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
		row.add_child(lbl)
	var opts := OptionButton.new()
	opts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opts.tooltip_text = tooltip
	opts.add_item(none_label)
	var selected := 0
	for si in range(all_ids.size()):
		opts.add_item(all_ids[si])
		if all_ids[si] == current:
			selected = si + 1
	opts.selected = selected
	opts.item_selected.connect(func(idx: int) -> void:
		if idx == 0:
			on_change.call("")
		else:
			on_change.call(all_ids[idx - 1]))
	row.add_child(opts)
	_s().add_child(row)


func _add_text_edit_row(initial: String, on_commit: Callable, on_delete: Callable, label: String = "") -> void:
	var row := HBoxContainer.new()
	if label:
		var lbl := Label.new()
		lbl.text = label
		lbl.custom_minimum_size = Vector2(56, 0)
		lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
		row.add_child(lbl)
	var edit := TextEdit.new()
	edit.text = initial
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.custom_minimum_size = Vector2(0, 52)
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	edit.scroll_fit_content_height = true
	edit.focus_exited.connect(func() -> void:
		var val := edit.text
		if val != initial:
			on_commit.call(val))
	row.add_child(edit)
	var del_btn := Button.new()
	del_btn.text = "×"
	del_btn.custom_minimum_size = Vector2(28, 28)
	del_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	del_btn.pressed.connect(on_delete)
	row.add_child(del_btn)
	_s().add_child(row)


func _patch_field(scene_id: String, setter: Callable) -> void:
	var file_name: String = _scenes.get(scene_id, {}).get("_editor_file", "")
	if file_name.is_empty():
		return
	var path := "res://dialogues/" + file_name
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if not data is Dictionary or not data.has("scenes"):
		return
	for scene in (data["scenes"] as Array):
		if scene.get("id", "") != scene_id:
			continue
		setter.call(scene)
		scene["_editor_file"] = file_name
		_scenes[scene_id] = scene
		break
	_write_json(path, data)


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


func _add_section(title: String, bg_color: Color = Color(0.15, 0.15, 0.18)) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	_detail_content.add_child(spacer)
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
	_detail_content.add_child(panel)


func _add_item(text: String) -> void:
	var lbl := Label.new()
	lbl.text = "  " + text
	lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_s().add_child(lbl)


func _add_effect(effect: Dictionary) -> void:
	var lbl := Label.new()
	lbl.text = "    " + _effect_label(effect)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_s().add_child(lbl)


func _add_effects_editor(scene_id: String, effects: Array, get_effs: Callable) -> void:
	const OPS := ["set", "add", "sub", "rename", "set_status"]
	const STATUS_VALS := ["online", "away", "offline", "network_issue"]
	for ei in range(effects.size()):
		var eff: Dictionary = effects[ei]
		var eff_idx := ei
		var op: String = str(eff.get("op", "set"))
		var is_contact_op := op in ["rename", "set_status"]
		var target_key := "contact" if is_contact_op else "var"
		var target_val: String = str(eff.get(target_key, ""))
		var value_val: String = str(eff.get("value", ""))

		var row := HBoxContainer.new()

		var op_opts := OptionButton.new()
		for o in OPS:
			op_opts.add_item(o)
		op_opts.selected = max(OPS.find(op), 0)
		op_opts.tooltip_text = _t(
			"set   : fixe une variable à une valeur précise\nadd  : ajoute une valeur à une variable (compteur, score…)\nsub   : soustrait une valeur à une variable\nrename     : change le nom affiché d'un contact\nset_status : change le statut d'un contact",
			"set   : sets a variable to a specific value\nadd  : adds a value to a variable (counter, score…)\nsub   : subtracts a value from a variable\nrename     : changes a contact's display name\nset_status : changes a contact's status")
		op_opts.item_selected.connect(func(idx: int) -> void:
			_patch_field(scene_id, func(s: Dictionary) -> void:
				var effs: Array = get_effs.call(s)
				var e: Dictionary = effs[eff_idx]
				var new_op: String = OPS[idx]
				var new_contact: bool = new_op in ["rename", "set_status"]
				var old_contact: bool = str(e.get("op", "set")) in ["rename", "set_status"]
				e["op"] = new_op
				if new_contact != old_contact:
					if new_contact:
						var v: String = str(e.get("var", ""))
						e.erase("var")
						e["contact"] = v
					else:
						var c: String = str(e.get("contact", ""))
						e.erase("contact")
						e["var"] = c)
			call_deferred("_populate_detail", scene_id))
		row.add_child(op_opts)

		var target_opts := OptionButton.new()
		target_opts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if is_contact_op:
			var contact_ids: Array = []
			for c in _parser.contacts:
				contact_ids.append(c.get("id", ""))
			if target_val and not contact_ids.has(target_val):
				contact_ids.append(target_val)
			target_opts.add_item(_t("(aucun)", "(none)"))
			var target_sel := 0
			for ci in range(contact_ids.size()):
				target_opts.add_item(contact_ids[ci])
				if contact_ids[ci] == target_val:
					target_sel = ci + 1
			target_opts.selected = target_sel
			target_opts.item_selected.connect(func(idx: int) -> void:
				_patch_field(scene_id, func(s: Dictionary) -> void:
					if idx == 0:
						get_effs.call(s)[eff_idx].erase(target_key)
					else:
						get_effs.call(s)[eff_idx][target_key] = contact_ids[idx - 1]))
		else:
			var all_vars := _collect_vars()
			if target_val and not all_vars.has(target_val):
				all_vars.append(target_val)
				all_vars.sort()
			target_opts.add_item(_t("(aucune)", "(none)"))
			var target_sel := 0
			for vi in range(all_vars.size()):
				target_opts.add_item(all_vars[vi])
				if all_vars[vi] == target_val:
					target_sel = vi + 1
			target_opts.selected = target_sel
			target_opts.item_selected.connect(func(idx: int) -> void:
				_patch_field(scene_id, func(s: Dictionary) -> void:
					if idx == 0:
						get_effs.call(s)[eff_idx].erase(target_key)
					else:
						get_effs.call(s)[eff_idx][target_key] = all_vars[idx - 1]))
		row.add_child(target_opts)

		var eq_lbl := Label.new()
		eq_lbl.text = "="
		eq_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		eq_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		row.add_child(eq_lbl)

		if op == "set_status":
			var status_opts := OptionButton.new()
			for sv in STATUS_VALS:
				status_opts.add_item(sv)
			status_opts.selected = max(STATUS_VALS.find(value_val), 0)
			status_opts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			status_opts.item_selected.connect(func(idx: int) -> void:
				_patch_field(scene_id, func(s: Dictionary) -> void:
					get_effs.call(s)[eff_idx]["value"] = STATUS_VALS[idx]))
			row.add_child(status_opts)
		else:
			var value_edit := LineEdit.new()
			value_edit.text = value_val
			value_edit.placeholder_text = _t("valeur", "value")
			value_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			value_edit.focus_exited.connect(func() -> void:
				var val := value_edit.text.strip_edges()
				if val == value_val:
					return
				_patch_field(scene_id, func(s: Dictionary) -> void:
					var parsed = int(val) if val.is_valid_int() else (float(val) if val.is_valid_float() else val)
					get_effs.call(s)[eff_idx]["value"] = parsed))
			row.add_child(value_edit)

		var del_btn := Button.new()
		del_btn.text = "×"
		del_btn.custom_minimum_size = Vector2(28, 28)
		del_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		del_btn.pressed.connect(func() -> void:
			_patch_field(scene_id, func(s: Dictionary) -> void:
				get_effs.call(s).remove_at(eff_idx))
			call_deferred("_populate_detail", scene_id))
		row.add_child(del_btn)
		_s().add_child(row)

	var add_eff_btn := Button.new()
	add_eff_btn.text = _t("+ Effet", "+ Effect")
	add_eff_btn.tooltip_text = _t(
		"Ajoute un effet déclenché à ce moment.\nset/add/sub : modifie une variable\nrename : renomme un contact\nset_status : change le statut d'un contact",
		"Adds an effect triggered at this point.\nset/add/sub: modify a variable\nrename: rename a contact\nset_status: change a contact's status")
	add_eff_btn.pressed.connect(func() -> void:
		_patch_field(scene_id, func(s: Dictionary) -> void:
			var effs: Array = get_effs.call(s)
			effs.append({"op": "set", "var": "", "value": ""}))
		call_deferred("_populate_detail", scene_id))
	_s().add_child(add_eff_btn)


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
