extends CanvasLayer

var _narrative: Node = null
var _scene_input: LineEdit = null
var _flags_container: VBoxContainer = null
var _vars_edit: TextEdit = null

func _init() -> void:
	layer = 128

func _ready() -> void:
	visible = false
	_build_ui()

func setup(narrative: Node) -> void:
	_narrative = narrative
	_populate_flags()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
		get_viewport().set_input_as_handled()
		if visible:
			_close()
		else:
			_open()

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(480, 560)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "DEBUG — Jump to Scene  [F9 pour fermer]"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	var row := HBoxContainer.new()
	vbox.add_child(row)
	var lbl_scene := Label.new()
	lbl_scene.text = "Scene ID :"
	lbl_scene.custom_minimum_size = Vector2(76, 0)
	row.add_child(lbl_scene)
	_scene_input = LineEdit.new()
	_scene_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scene_input.placeholder_text = "ex : scene_03"
	row.add_child(_scene_input)

	vbox.add_child(HSeparator.new())

	var lbl_flags := Label.new()
	lbl_flags.text = "Flags à activer :"
	vbox.add_child(lbl_flags)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 180)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_flags_container = VBoxContainer.new()
	_flags_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_flags_container)

	vbox.add_child(HSeparator.new())

	var lbl_vars := Label.new()
	lbl_vars.text = "Vars (clé=valeur, une par ligne) :"
	vbox.add_child(lbl_vars)

	_vars_edit = TextEdit.new()
	_vars_edit.custom_minimum_size = Vector2(0, 90)
	vbox.add_child(_vars_edit)

	vbox.add_child(HSeparator.new())

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)

	var btn_jump := Button.new()
	btn_jump.text = "Jump"
	btn_jump.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_jump.pressed.connect(_on_jump_pressed)
	btn_row.add_child(btn_jump)

	var btn_close := Button.new()
	btn_close.text = "Fermer"
	btn_close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_close.pressed.connect(_close)
	btn_row.add_child(btn_close)


func _populate_flags() -> void:
	for flag in DialogueLoader.get_all_flags():
		var cb := CheckBox.new()
		cb.text = flag
		_flags_container.add_child(cb)


func _open() -> void:
	visible = true
	_refresh_state()
	_scene_input.call_deferred("grab_focus")


func _close() -> void:
	visible = false


func _refresh_state() -> void:
	for cb in _flags_container.get_children():
		if cb is CheckBox:
			cb.button_pressed = _narrative.flags.get(cb.text, false)
	var lines: PackedStringArray = []
	for key in _narrative.vars:
		lines.append("%s=%s" % [key, _narrative.vars[key]])
	_vars_edit.text = "\n".join(lines)


func _on_jump_pressed() -> void:
	var scene_id := _scene_input.text.strip_edges()
	if scene_id.is_empty() or not DialogueLoader.has_scene(scene_id):
		_scene_input.modulate = Color(1.0, 0.3, 0.3)
		await get_tree().create_timer(0.5).timeout
		if is_instance_valid(_scene_input):
			_scene_input.modulate = Color.WHITE
		return

	for cb in _flags_container.get_children():
		if not cb is CheckBox:
			continue
		if cb.button_pressed:
			_narrative.flags[cb.text] = true
		else:
			_narrative.flags.erase(cb.text)

	var new_vars: Dictionary = {}
	for line in _vars_edit.text.split("\n"):
		line = line.strip_edges()
		if line.is_empty():
			continue
		var eq_pos := line.find("=")
		if eq_pos == -1:
			continue
		var key := line.substr(0, eq_pos).strip_edges()
		var val_str := line.substr(eq_pos + 1).strip_edges()
		if key.is_empty():
			continue
		if val_str.is_valid_int():
			new_vars[key] = int(val_str)
		elif val_str.is_valid_float():
			new_vars[key] = float(val_str)
		else:
			new_vars[key] = val_str
	_narrative.vars = new_vars

	_close()
	_narrative.abort_current()
	_narrative.message_display.clear_messages()
	_narrative.current_message_index = 0
	_narrative.play_scene(scene_id)
