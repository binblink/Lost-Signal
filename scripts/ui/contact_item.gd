extends Button

const MAX_PREVIEW_LENGTH = 80

@onready var initial_label = $MarginContainer/HBoxContainer/Control/Panel/Label
@onready var contact_name = $MarginContainer/HBoxContainer/TextColumn/NameAndTimeLine/ContactName
@onready var contact_time = $MarginContainer/HBoxContainer/TextColumn/NameAndTimeLine/ContactTime
@onready var contact_preview = $MarginContainer/HBoxContainer/TextColumn/PreviewBadgeLine/ContactPreview
@onready var unread_badge = $MarginContainer/HBoxContainer/TextColumn/PreviewBadgeLine/UnreadBadge

func _ready() -> void:
	# Forcer les size flags par code car layout_mode 2 les expose différemment en 4.6
	$MarginContainer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	$MarginContainer/HBoxContainer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	$MarginContainer/HBoxContainer/TextColumn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	$MarginContainer/HBoxContainer/TextColumn/NameAndTimeLine.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	$MarginContainer/HBoxContainer/TextColumn/NameAndTimeLine/ContactName.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	$MarginContainer/HBoxContainer/TextColumn/NameAndTimeLine/ContactTime.size_flags_horizontal = Control.SIZE_SHRINK_END
	$MarginContainer/HBoxContainer/TextColumn/PreviewBadgeLine.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	$MarginContainer/HBoxContainer/TextColumn/PreviewBadgeLine/ContactPreview.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func setup(contact: Dictionary, last_message: Dictionary, unread: bool) -> void:
	var name = contact.get("name", "")
	contact_name.text = name
	initial_label.text = name[0].to_upper() if name.length() > 0 else "?"
	unread_badge.visible = unread

	if last_message.is_empty():
		contact_time.text = ""
		contact_preview.text = "Aucun message"
	else:
		contact_time.text = last_message.get("time", "")
		var prefix = "Vous : " if last_message.get("out", false) else ""
		var raw = last_message.get("text", null)
		var media = last_message.get("media", null)
		var text: String
		if raw != null:
			text = str(raw)
		elif media != null:
			text = "📷 Photo"
		else:
			text = ""
		if text.length() > MAX_PREVIEW_LENGTH:
			text = text.substr(0, MAX_PREVIEW_LENGTH) + "…"
		contact_preview.text = prefix + text

	# Avatar image si disponible
	var avatar_path = contact.get("avatar", null)
	if avatar_path != null and ResourceLoader.exists(avatar_path):
		var panel = $MarginContainer/HBoxContainer/Control/Panel
		var texture_rect = TextureRect.new()
		texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		texture_rect.texture = load(avatar_path)
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		texture_rect.clip_contents = true
		texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(texture_rect)
		initial_label.visible = false
