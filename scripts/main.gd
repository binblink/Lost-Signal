extends Control

@onready var message_display    = %MessagesList
@onready var input_bar          = %InputBar
@onready var line_edit          = %TextInput
@onready var choices_layer      = %ChoicesLayer
@onready var confirm_dialog     = %ConfirmDialog
@onready var overlay            = %Overlay
@onready var reset_button       = %Reset
@onready var panel_button       = %PanelButton
@onready var settings_button    = %SettingsButton
@onready var settings_dialog    = %SettingsDialog
@onready var photo_overlay      = %PhotoOverlay
@onready var photo_image        = %PhotoImage
@onready var contact_name_label = %ContactName
@onready var _status_dot        = %StatusDot
@onready var _status_text       = %StatusText
@onready var _status_warning    = %StatusWarning
@onready var _contact_panel     = %ContactPanel
@onready var btn_cancel  = %ConfirmDialog.get_node("MarginContainer/VBoxContainer/HBoxContainer/Cancel")
@onready var btn_restart = %ConfirmDialog.get_node("MarginContainer/VBoxContainer/HBoxContainer/Restart")
@onready var _clock_label = %ClockLabel

var _total_unread: int = 0
var _blink_tween: Tween = null
var _free_input_tween: Tween = null
var _free_input_indicator: ColorRect = null
var _narrative: Node = null
var _validation_dialog: Control = null


func _ready() -> void:
	_apply_theme()
	_narrative = preload("res://scripts/narrative_controller.gd").new()
	add_child(_narrative)
	_narrative.message_display = message_display
	_narrative.choices_layer   = choices_layer
	_narrative.input_bar       = input_bar
	_narrative.active_contact_id = DialogueLoader.get_main_contact().get("id", "maeve")

	choices_layer.message_display  = message_display
	choices_layer.scroll_container = $RootHBox/VBoxContainer/Messages
	choices_layer.input_bar        = input_bar
	choices_layer.choice_selected.connect(_narrative.handle_choice)

	message_display.line_edit = line_edit

	_narrative.save_requested.connect(_on_save_requested)
	_narrative.secondary_scene_received.connect(_on_secondary_scene_received)
	_narrative.contact_renamed.connect(_on_contact_renamed)
	_narrative.contact_status_changed.connect(_on_contact_status_changed)

	confirm_dialog.visible = false
	overlay.visible = false
	reset_button.pressed.connect(_on_new_game_pressed)
	panel_button.pressed.connect(_on_contacts_button_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	settings_dialog.accepted.connect(_on_settings_accepted)
	settings_dialog.cancelled.connect(func(): overlay.visible = false)
	message_display.image_clicked.connect(_on_image_clicked)
	photo_overlay.gui_input.connect(_on_photo_overlay_input)
	btn_cancel.pressed.connect(_on_cancel_pressed)
	btn_restart.pressed.connect(_on_startover_pressed)

	_contact_panel.contact_selected.connect(_on_contact_selected)
	_contact_panel.contacts = DialogueLoader.get_contacts()
	line_edit.text_submitted.connect(_on_free_input_submitted)
	_narrative.free_input_activated.connect(_start_free_input_visual)

	_update_clock()
	var clock_timer := Timer.new()
	clock_timer.wait_time = 30.0
	clock_timer.autostart = true
	clock_timer.timeout.connect(_update_clock)
	add_child(clock_timer)

	_validation_dialog = preload("res://scenes/ValidationDialog.tscn").instantiate()
	_validation_dialog.closed.connect(func(): overlay.visible = false)
	_validation_dialog.set_anchors_preset(Control.PRESET_CENTER)
	_validation_dialog.z_index = 10
	add_child(_validation_dialog)

	_update_topbar(_narrative.active_contact_id)
	_contact_panel.show_panel()

	if DialogueLoader.has_validation_issues():
		overlay.visible = true
		_validation_dialog.open(DialogueLoader.get_validation_report())

	if SaveManager.has_save():
		await load_game()
	else:
		await _narrative.play_scene(DialogueLoader.get_start_scene())


# ---------------------------------------------------------------------------
# Theme
# ---------------------------------------------------------------------------

func _apply_theme() -> void:
	$ColorRect.color = ThemeManager.background_color
	ThemeManager.restyle_panel($RootHBox/VBoxContainer/Messages,  ThemeManager.background_color)
	ThemeManager.restyle_panel($RootHBox/VBoxContainer/TopBar,    ThemeManager.topbar_color)
	ThemeManager.restyle_panel($RootHBox/VBoxContainer/InputBar,  ThemeManager.topbar_color)
	ThemeManager.restyle_panel($RootHBox/ContactPanel/VBoxContainer/TopBar, ThemeManager.topbar_color)
	var tc := ThemeManager.topbar_color
	ThemeManager.restyle_panel(_contact_panel, Color(tc.r * 0.657, tc.g * 0.657, tc.b * 0.657))
	ThemeManager.restyle_panel(
		$RootHBox/VBoxContainer/TopBar/MarginContainer/HBoxContainer/Avatar/ColorRect,
		ThemeManager.accent_color
	)
	contact_name_label.add_theme_color_override("font_color", ThemeManager.text_color)
	contact_name_label.add_theme_font_size_override("font_size", ThemeManager.font_size)
	_status_text.add_theme_color_override("font_color", ThemeManager.time_color)
	_clock_label.add_theme_color_override("font_color", ThemeManager.time_color)


# ---------------------------------------------------------------------------
# Topbar
# ---------------------------------------------------------------------------

func _get_display_name(contact_id: String) -> String:
	if _narrative.contact_names.has(contact_id):
		return _narrative.contact_names[contact_id]
	var contact = DialogueLoader.get_contact(contact_id)
	if contact.is_empty():
		contact = DialogueLoader.get_main_contact()
	return contact.get("name", "")

func _update_topbar(contact_id: String) -> void:
	contact_name_label.text = _get_display_name(contact_id)
	_apply_status_ui(contact_id)

func _get_status(contact_id: String) -> String:
	if _narrative.contact_statuses.has(contact_id):
		return _narrative.contact_statuses[contact_id]
	return DialogueLoader.get_contact(contact_id).get("status", "online")

func _apply_status_ui(contact_id: String) -> void:
	if _blink_tween:
		_blink_tween.kill()
		_blink_tween = null
	_status_dot.modulate.a = 1.0
	match _get_status(contact_id):
		"online":
			_status_dot.add_theme_color_override("font_color", Color(0.2, 0.85, 0.4))
			_status_text.text = tr("STATUS_ONLINE")
			_status_warning.visible = false
		"away":
			_status_dot.add_theme_color_override("font_color", Color(1.0, 0.80, 0.1))
			_status_text.text = tr("STATUS_AWAY")
			_status_warning.visible = false
		"offline":
			_status_dot.add_theme_color_override("font_color", Color(0.9, 0.25, 0.25))
			_status_text.text = tr("STATUS_OFFLINE")
			_status_warning.visible = false
		"network_issue":
			_status_dot.add_theme_color_override("font_color", Color(0.9, 0.25, 0.25))
			_status_text.text = tr("STATUS_NETWORK_ISSUE")
			_status_warning.visible = true
			_blink_tween = create_tween().set_loops()
			_blink_tween.tween_property(_status_dot, "modulate:a", 0.1, 0.5)
			_blink_tween.tween_property(_status_dot, "modulate:a", 1.0, 0.5)


# ---------------------------------------------------------------------------
# Contacts panel
# ---------------------------------------------------------------------------

func _on_image_clicked(path: String) -> void:
	if ResourceLoader.exists(path):
		photo_image.texture = load(path)
	photo_overlay.visible = true

func _on_photo_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		photo_overlay.visible = false

func _on_settings_pressed() -> void:
	overlay.visible = true
	settings_dialog.open()

func _on_settings_accepted(language_changed: bool) -> void:
	overlay.visible = false
	if language_changed:
		save_game(false)
		DialogueLoader.reload_for_locale()
		get_tree().reload_current_scene()

func _on_contacts_button_pressed() -> void:
	_contact_panel.toggle_panel()

func _update_panel_button() -> void:
	panel_button.text = "☰●" if _total_unread > 0 else "☰"

func _on_contact_selected(contact_id: String, unread_count: int) -> void:
	if _narrative.is_busy:
		return
	if unread_count > 0:
		_total_unread = max(0, _total_unread - unread_count)
		_update_panel_button()
	if contact_id == _narrative.active_contact_id:
		return
	_narrative.contact_histories[_narrative.active_contact_id] = message_display.collect_messages_data()
	_narrative.active_contact_id = contact_id
	_update_topbar(contact_id)
	var contact_data = DialogueLoader.get_contact(contact_id)
	var is_main = contact_data.get("is_main", false)
	line_edit.editable = is_main
	line_edit.mouse_filter = Control.MOUSE_FILTER_STOP if is_main else Control.MOUSE_FILTER_IGNORE
	message_display.clear_messages()
	await get_tree().process_frame
	await message_display.render_history(_narrative.contact_histories.get(contact_id, []))
	await message_display.scroll_to_bottom()
	input_bar.visible = true
	await _narrative.restore_pending_choice_for(contact_id)


# ---------------------------------------------------------------------------
# Narrative signals
# ---------------------------------------------------------------------------

func _on_save_requested(notify_panel: bool) -> void:
	save_game(notify_panel)

func _on_secondary_scene_received(contact_id: String) -> void:
	AudioManager.play_notification()
	_contact_panel.mark_unread(contact_id)
	_contact_panel.update_history(contact_id, _narrative.contact_histories.get(contact_id, []))
	_total_unread += 1
	_update_panel_button()
	save_game()

func _on_contact_renamed(contact_id: String, new_name: String) -> void:
	_contact_panel.set_contact_name(contact_id, new_name)
	if contact_id == _narrative.active_contact_id:
		_update_topbar(contact_id)

func _on_contact_status_changed(contact_id: String, _new_status: String) -> void:
	if contact_id == _narrative.active_contact_id:
		_apply_status_ui(contact_id)


# ---------------------------------------------------------------------------
# Save / Load
# ---------------------------------------------------------------------------

func save_game(notify_panel: bool = true) -> void:
	_narrative.contact_histories[_narrative.active_contact_id] = message_display.collect_messages_data()
	SaveManager.save(_narrative.get_state())
	if notify_panel:
		_contact_panel.update_history(_narrative.active_contact_id, _narrative.contact_histories.get(_narrative.active_contact_id, []))

func load_game() -> void:
	var data = SaveManager.load_save()
	if data.is_empty():
		return
	_narrative.set_state(data)
	for cid in _narrative.contact_names:
		_contact_panel.set_contact_name(cid, _narrative.contact_names[cid])
	_narrative.active_contact_id = DialogueLoader.get_main_contact().get("id", "maeve")
	_update_topbar(_narrative.active_contact_id)
	message_display.clear_messages()
	await get_tree().process_frame
	await message_display.render_history(_narrative.contact_histories.get(_narrative.active_contact_id, []))
	await message_display.scroll_to_bottom()
	var scene_id = data.get("current_scene_id", "")
	if scene_id == "" or not DialogueLoader.has_scene(scene_id):
		await _narrative.resume_overdue_scenes()
		return
	_narrative.current_scene = DialogueLoader.get_scene(scene_id)
	for cid in _narrative.contact_histories:
		_contact_panel.update_history(cid, _narrative.contact_histories.get(cid, []))
	if _narrative.waiting_for_choice:
		await _narrative.rebuild_choices()
	else:
		await _narrative.play_scene(scene_id)
	await _narrative.resume_overdue_scenes()


# ---------------------------------------------------------------------------
# Global UI
# ---------------------------------------------------------------------------

func _start_free_input_visual(placeholder: String) -> void:
	line_edit.placeholder_text = placeholder if placeholder != "" else tr("INPUT_PLACEHOLDER")
	if not is_instance_valid(_free_input_indicator):
		_free_input_indicator = ColorRect.new()
		_free_input_indicator.color = ThemeManager.accent_color
		_free_input_indicator.custom_minimum_size = Vector2(0, 2)
		var parent = input_bar.get_parent()
		parent.add_child(_free_input_indicator)
		parent.move_child(_free_input_indicator, input_bar.get_index())
	_free_input_indicator.visible = true
	_free_input_indicator.modulate.a = 1.0
	if _free_input_tween:
		_free_input_tween.kill()
	_free_input_tween = create_tween().set_loops()
	_free_input_tween.tween_property(_free_input_indicator, "modulate:a", 0.15, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_free_input_tween.tween_property(_free_input_indicator, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_free_input_visual() -> void:
	line_edit.placeholder_text = ""
	if _free_input_tween:
		_free_input_tween.kill()
		_free_input_tween = null
	if is_instance_valid(_free_input_indicator):
		_free_input_indicator.visible = false


func _on_free_input_submitted(text: String) -> void:
	if text.strip_edges().is_empty() or not _narrative.is_waiting_for_free_input:
		return
	_stop_free_input_visual()
	line_edit.clear()
	_narrative.submit_free_input(text.strip_edges())


func _update_clock() -> void:
	var t := Time.get_time_dict_from_system()
	_clock_label.text = "%02d:%02d" % [t["hour"], t["minute"]]


func _on_new_game_pressed() -> void:
	confirm_dialog.visible = true
	overlay.visible = true

func _on_cancel_pressed() -> void:
	confirm_dialog.visible = false
	overlay.visible = false

func _on_startover_pressed() -> void:
	SaveManager.delete_save()
	await get_tree().process_frame
	get_tree().reload_current_scene()
