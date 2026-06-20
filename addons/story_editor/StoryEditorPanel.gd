@tool
extends Control

const SceneParser = preload("res://addons/story_editor/scene_parser.gd")

const COLOR_NORMAL  := Color(0.8, 0.8, 0.8)
const COLOR_TRIGGER := Color(1.0, 0.6, 0.0)
const COLOR_RESUME  := Color(0.7, 0.3, 1.0)

const H_SPACING := 300.0
const V_SPACING := 180.0

@onready var _status_label:   Label         = %StatusLabel
@onready var _refresh_button: Button        = %RefreshButton
@onready var _graph:          GraphEdit     = %GraphEdit
@onready var _detail_content: VBoxContainer = %DetailContent

var _parser := SceneParser.new()
var _scenes: Dictionary = {}


func _ready() -> void:
	_refresh_button.pressed.connect(_on_refresh_pressed)
	_graph.node_selected.connect(_on_node_selected)


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
			result[scene_id].append({type = "next", target = str(next), label = "→ next"})

		for choice in scene.get("choices", []):
			var cnext = choice.get("next", null)
			if cnext == null:
				continue
			var label: String = str(choice.get("text", "…"))
			if label.length() > 22:
				label = label.substr(0, 22) + "…"
			result[scene_id].append({type = "choice", target = str(cnext), label = label})

	for scene_id in scenes:
		var trigger_src = scenes[scene_id].get("trigger_after_scene", null)
		if trigger_src == null:
			continue
		var src := str(trigger_src)
		if not result.has(src):
			result[src] = []
		result[src].append({type = "trigger", target = scene_id, label = "⚡ trigger"})

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

	# Slot 0 : contact — port d'entrée
	var contact_label := Label.new()
	contact_label.text = scene.get("contact_id", "—")
	contact_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	node.add_child(contact_label)
	node.set_slot(0, true, 0, Color.WHITE, false, 0, Color.WHITE)

	# Slots 1..N : connexions sortantes — ports de sortie
	for i in range(conns.size()):
		var conn = conns[i]
		var lbl := Label.new()
		lbl.text = conn.label
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		node.add_child(lbl)
		node.set_slot(1 + i, false, 0, Color.WHITE, true, 0, _port_color(conn.type))

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
		node.set_slot(1 + conns.size(), false, 0, Color.WHITE, false, 0, Color.WHITE)

	return node


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
