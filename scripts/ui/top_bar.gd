extends Node

var name_label:    Label
var status_dot:    Node
var status_text:   Label
var status_warning: Node

var _blink_tween: Tween = null


func refresh(contact_id: String, contact_names: Dictionary, contact_statuses: Dictionary) -> void:
	name_label.text = _get_display_name(contact_id, contact_names)
	_apply_status(contact_id, contact_statuses)


func _get_display_name(contact_id: String, contact_names: Dictionary) -> String:
	if contact_names.has(contact_id):
		return contact_names[contact_id]
	var contact = DialogueLoader.get_contact(contact_id)
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
