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
@onready var _exit_button = %ExitButton
@onready var _clock_label = %ClockLabel

var _total_unread: int = 0
var _free_input_tween: Tween = null
var _top_bar: Node = null
var _free_input_indicator: Panel = null
var _narrative: Node = null
var _validation_dialog: Control = null
var _exit_dialog: Control = null


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
	_exit_button.pressed.connect(_on_exit_button_pressed)
	_exit_dialog = preload("res://scripts/ui/exit_dialog.gd").new()
	_exit_dialog.anchor_left   = 0.5
	_exit_dialog.anchor_right  = 0.5
	_exit_dialog.anchor_top    = 0.5
	_exit_dialog.anchor_bottom = 0.5
	_exit_dialog.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_exit_dialog.grow_vertical   = Control.GROW_DIRECTION_BOTH
	_exit_dialog.z_index = 10
	_exit_dialog.visible = false
	add_child(_exit_dialog)
	_exit_dialog.menu_requested.connect(_on_exit_to_menu)
	_exit_dialog.desktop_requested.connect(_on_exit_to_desktop)
	_exit_dialog.close_requested.connect(_on_exit_cancel)

	_contact_panel.contact_selected.connect(_on_contact_selected)
	_contact_panel.contacts = DialogueLoader.get_contacts()
	line_edit.text_submitted.connect(_on_free_input_submitted)
	_narrative.free_input_activated.connect(_start_free_input_visual)
	_narrative.free_input_aborted.connect(_stop_free_input_visual)

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

	_top_bar = preload("res://scripts/ui/top_bar.gd").new()
	_top_bar.name_label     = contact_name_label
	_top_bar.status_dot     = _status_dot
	_top_bar.status_text    = _status_text
	_top_bar.status_warning = _status_warning
	_top_bar.avatar_node    = $RootHBox/VBoxContainer/TopBar/MarginContainer/HBoxContainer/Avatar
	add_child(_top_bar)

	_top_bar.refresh(_narrative.active_contact_id, _narrative.contact_names, _narrative.contact_statuses)
	_contact_panel.show_panel()

	if DialogueLoader.has_validation_issues():
		overlay.visible = true
		_validation_dialog.open(DialogueLoader.get_validation_report())

	if OS.is_debug_build():
		var debug_overlay := preload("res://scripts/debug_overlay.gd").new()
		add_child(debug_overlay)
		debug_overlay.setup(_narrative)

	if SaveManager.has_save():
		await load_game()
	else:
		# Pre-load history and pending scenes from story.json for secondary contacts
		# so they appear populated before the main narrative even starts.
		for contact in DialogueLoader.get_contacts():
			var cid: String = contact.get("id", "")
			if contact.get("is_main", false):
				continue
			var history: Array = contact.get("history", [])
			var pending_scene: String = contact.get("pending_scene", "")
			var has_content := history.size() > 0 or pending_scene != ""
			if history.size() > 0:
				_narrative.contact_histories[cid] = history
				_contact_panel.update_history(cid, history)
			if pending_scene != "" and DialogueLoader.has_scene(pending_scene):
				_narrative.pending_choices[cid] = pending_scene
			if has_content:
				_contact_panel.mark_unread(cid)
				_total_unread += 1
		_update_panel_button()
		await _narrative.play_scene(DialogueLoader.get_start_scene())
		var start_cid: String = DialogueLoader.get_start_contact()
		if start_cid != "" and start_cid != _narrative.active_contact_id:
			_narrative.active_contact_id = start_cid
			_top_bar.refresh(start_cid, _narrative.contact_names, _narrative.contact_statuses)
			var start_contact_data := DialogueLoader.get_contact(start_cid)
			var is_main: bool = start_contact_data.get("is_main", false)
			line_edit.editable = is_main
			line_edit.mouse_filter = Control.MOUSE_FILTER_STOP if is_main else Control.MOUSE_FILTER_IGNORE
			var start_unread: int = _contact_panel.get_unread(start_cid)
			if start_unread > 0:
				_total_unread = max(0, _total_unread - start_unread)
				_contact_panel.clear_unread(start_cid)
				_update_panel_button()
			message_display.clear_messages()
			await get_tree().process_frame
			await message_display.render_history(_narrative.contact_histories.get(start_cid, []))
			await message_display.scroll_to_bottom()
			await _narrative.restore_pending_choice_for(start_cid)


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

# Snapshots the live UI back into contact_histories before switching — this is the only place that happens.
# Without it, messages typed or received in the current conversation would be lost on switch.
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
	_top_bar.refresh(contact_id, _narrative.contact_names, _narrative.contact_statuses)
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

# NarrativeController already wrote messages directly into contact_histories — nothing to render here.
# Just mark unread, update the panel preview, and save.
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
		_top_bar.refresh(contact_id, _narrative.contact_names, _narrative.contact_statuses)

func _on_contact_status_changed(contact_id: String, _new_status: String) -> void:
	if contact_id == _narrative.active_contact_id:
		_top_bar.refresh(contact_id, _narrative.contact_names, _narrative.contact_statuses)


# ---------------------------------------------------------------------------
# Save / Load
# ---------------------------------------------------------------------------

# Must snapshot the active contact before saving — contact_histories only updates on contact switch otherwise.
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
	var main_id: String = DialogueLoader.get_main_contact().get("id", "maeve")
	_narrative.active_contact_id = data.get("active_contact_id", main_id)
	_top_bar.refresh(_narrative.active_contact_id, _narrative.contact_names, _narrative.contact_statuses)
	var loaded_contact: Dictionary = DialogueLoader.get_contact(_narrative.active_contact_id)
	var loaded_is_main: bool = loaded_contact.get("is_main", false)
	line_edit.editable = loaded_is_main
	line_edit.mouse_filter = Control.MOUSE_FILTER_STOP if loaded_is_main else Control.MOUSE_FILTER_IGNORE
	message_display.clear_messages()
	await get_tree().process_frame
	await message_display.render_history(_narrative.contact_histories.get(_narrative.active_contact_id, []))
	await message_display.scroll_to_bottom()
	for cid in _narrative.contact_histories:
		_contact_panel.update_history(cid, _narrative.contact_histories.get(cid, []))
	for cid: String in _narrative.contact_names:
		_contact_panel.set_contact_name(cid, _narrative.get_contact_display_name(cid))
	var scene_id: String = data.get("current_scene_id", "")
	if scene_id == "" or not DialogueLoader.has_scene(scene_id):
		await _narrative.resume_overdue_scenes()
		return
	_narrative.current_scene = DialogueLoader.get_scene(scene_id)
	if _narrative.waiting_for_choice:
		await _narrative.rebuild_choices()
	else:
		await _narrative.play_scene(scene_id)
	await _narrative.resume_overdue_scenes()


# ---------------------------------------------------------------------------
# Global UI
# ---------------------------------------------------------------------------

# line_edit.clear() runs first to flush any stale text before setting placeholder_text.
# placeholder_text is set twice — the second time after the await because the frame process resets it on first layout.
func _start_free_input_visual(placeholder: String) -> void:
	line_edit.clear()
	var _ph := placeholder if placeholder != "" else tr("INPUT_PLACEHOLDER")
	line_edit.placeholder_text = _ph
	if not is_instance_valid(_free_input_indicator):
		_free_input_indicator = Panel.new()
		var style := StyleBoxFlat.new()
		style.draw_center = false
		style.border_color = ThemeManager.accent_color
		style.set_border_width_all(3)
		_free_input_indicator.add_theme_stylebox_override("panel", style)
		_free_input_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_free_input_indicator)
		await get_tree().process_frame
		line_edit.placeholder_text = _ph
	_free_input_indicator.global_position = input_bar.global_position
	_free_input_indicator.size = input_bar.size
	_free_input_indicator.visible = true
	_free_input_indicator.modulate.a = 1.0
	if _free_input_tween:
		_free_input_tween.kill()
	_free_input_tween = create_tween().set_loops()
	_free_input_tween.tween_property(_free_input_indicator, "modulate:a", 0.1, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
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


# ---------------------------------------------------------------------------
# Exit dialog
# ---------------------------------------------------------------------------

func _on_exit_button_pressed() -> void:
	overlay.visible = true
	_exit_dialog.visible = true


func _on_exit_cancel() -> void:
	overlay.visible = false
	_exit_dialog.visible = false


func _on_exit_to_menu() -> void:
	overlay.visible = false
	_exit_dialog.visible = false
	save_game(false)
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _on_exit_to_desktop() -> void:
	overlay.visible = false
	_exit_dialog.visible = false
	save_game(false)
	get_tree().quit()
