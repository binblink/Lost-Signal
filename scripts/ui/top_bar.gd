extends Node

var name_label:    Label
var status_dot:    Node
var status_text:   Label
var status_warning: Node
var avatar_node:   Control = null

var _blink_tween: Tween = null
var _avatar_initial: Label = null
var _avatar_texture: TextureRect = null


func refresh(contact_id: String, contact_names: Dictionary, contact_statuses: Dictionary) -> void:
	name_label.text = _get_display_name(contact_id, contact_names)
	_apply_status(contact_id, contact_statuses)
	_apply_avatar(contact_id, contact_names)


func _apply_avatar(contact_id: String, contact_names: Dictionary) -> void:
	if avatar_node == null:
		return
	if _avatar_initial == null:
		avatar_node.clip_contents = true
		_avatar_initial = Label.new()
		_avatar_initial.set_anchors_preset(Control.PRESET_FULL_RECT)
		_avatar_initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_avatar_initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_avatar_initial.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_avatar_initial.add_theme_color_override("font_color", Color.WHITE)
		avatar_node.add_child(_avatar_initial)
	var display_name: String = _get_display_name(contact_id, contact_names)
	_avatar_initial.text = display_name[0].to_upper() if display_name.length() > 0 else "?"
	_avatar_initial.visible = true
	if is_instance_valid(_avatar_texture):
		_avatar_texture.queue_free()
		_avatar_texture = null
	var contact: Dictionary = DialogueLoader.get_contact(contact_id)
	var avatar_path: String = str(contact.get("avatar", ""))
	if avatar_path != "" and ResourceLoader.exists(avatar_path):
		var tex = load(avatar_path)
		if tex != null:
			_avatar_texture = TextureRect.new()
			_avatar_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
			_avatar_texture.texture = tex
			_avatar_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			_avatar_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			_avatar_texture.clip_contents = true
			_avatar_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
			avatar_node.add_child(_avatar_texture)
			_avatar_initial.visible = false


func _get_display_name(contact_id: String, contact_names: Dictionary) -> String:
	if contact_names.has(contact_id):
		if contact_names[contact_id] is Dictionary:
			var names_dict: Dictionary = contact_names[contact_id] as Dictionary
			var lang: String = SettingsManager.language
			var localized: String = names_dict.get(lang, "")
			if localized != "":
				return localized
			for v in names_dict.values():
				return str(v)
		else:
			return str(contact_names[contact_id])
	var contact: Dictionary = DialogueLoader.get_contact(contact_id)
	if contact.is_empty():
		contact = DialogueLoader.get_main_contact()
	return contact.get("name", "")


func _get_status(contact_id: String, contact_statuses: Dictionary) -> String:
	if contact_statuses.has(contact_id):
		return contact_statuses[contact_id]
	return DialogueLoader.get_contact(contact_id).get("status", "online")


func _apply_status(contact_id: String, contact_statuses: Dictionary) -> void:
	if _blink_tween:
		_blink_tween.kill()
		_blink_tween = null
	status_dot.modulate.a = 1.0
	match _get_status(contact_id, contact_statuses):
		"online":
			status_dot.add_theme_color_override("font_color", Color(0.2, 0.85, 0.4))
			status_text.text = tr("STATUS_ONLINE")
			status_warning.visible = false
		"away":
			status_dot.add_theme_color_override("font_color", Color(1.0, 0.80, 0.1))
			status_text.text = tr("STATUS_AWAY")
			status_warning.visible = false
		"offline":
			status_dot.add_theme_color_override("font_color", Color(0.9, 0.25, 0.25))
			status_text.text = tr("STATUS_OFFLINE")
			status_warning.visible = false
		"network_issue":
			status_dot.add_theme_color_override("font_color", Color(0.9, 0.25, 0.25))
			status_text.text = tr("STATUS_NETWORK_ISSUE")
			status_warning.visible = true
			_blink_tween = create_tween().set_loops()
			_blink_tween.tween_property(status_dot, "modulate:a", 0.1, 0.5)
			_blink_tween.tween_property(status_dot, "modulate:a", 1.0, 0.5)
