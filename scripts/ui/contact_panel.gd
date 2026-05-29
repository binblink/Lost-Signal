extends PanelContainer

signal contact_selected(contact_id: String, unread_count: int)

const ContactItem = preload("res://scenes/ContactItem.tscn")
const PANEL_WIDTH = 320.0
const ANIM_DURATION = 0.25
const MAX_PREVIEW_LENGTH = 80

@onready var contact_list = $VBoxContainer/ContactList
@onready var close_button = $VBoxContainer/TopBar/MarginContainer/HBoxContainer/CloseButton

var _unread: Dictionary = {}
var _is_open: bool = false
var _last_messages: Dictionary = {}
var _display_names: Dictionary = {}
var _rebuilding: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(0, 0)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	clip_contents = true
	close_button.pressed.connect(hide_panel)

func show_panel() -> void:
	if _is_open:
		return
	_is_open = true
	_rebuild_list()
	$VBoxContainer.visible = true
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "custom_minimum_size:x", PANEL_WIDTH, ANIM_DURATION)

func hide_panel() -> void:
	if not _is_open:
		return
	_is_open = false
	# Cacher le contenu immédiatement avant l'animation
	$VBoxContainer.visible = false
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "custom_minimum_size:x", 0.0, ANIM_DURATION)

func mark_unread(contact_id: String) -> void:
	_unread[contact_id] = _unread.get(contact_id, 0) + 1
	if _is_open:
		_rebuild_list()

func clear_unread(contact_id: String) -> void:
	_unread.erase(contact_id)
	if _is_open:
		_rebuild_list()

func set_contact_name(contact_id: String, display_name: String) -> void:
	_display_names[contact_id] = display_name
	if _is_open:
		_rebuild_list()

func update_history(contact_id: String, history: Array) -> void:
	if history.size() > 0:
		_last_messages[contact_id] = history[history.size() - 1]
	if _is_open:
		_rebuild_list()

func _rebuild_list() -> void:
	if _rebuilding:
		return
	_rebuilding = true
	for child in contact_list.get_children():
		child.queue_free()
	await get_tree().process_frame
	for contact in DialogueLoader.get_contacts():
		var contact_id = contact.get("id", "")
		# Ne pas afficher les contacts sans historique
		if not _last_messages.has(contact_id):
			continue
		var item = ContactItem.instantiate()
		contact_list.add_child(item)
		var display_contact = contact.duplicate()
		if _display_names.has(contact_id):
			display_contact["name"] = _display_names[contact_id]
		item.setup(
			display_contact,
			_last_messages.get(contact_id, {}),
			_unread.get(contact_id, 0) > 0
		)
		item.pressed.connect(func():
			var count = _unread.get(contact_id, 0)
			clear_unread(contact_id)
			contact_selected.emit(contact_id, count)
		)
	_rebuilding = false
