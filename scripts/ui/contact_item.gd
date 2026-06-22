extends Button

const MAX_PREVIEW_LENGTH = 80

@onready var initial_label   = %InitialLabel
@onready var contact_name    = %ContactName
@onready var contact_time    = %ContactTime
@onready var contact_preview = %ContactPreview
@onready var unread_badge    = %UnreadBadge

func _ready() -> void:
	# layout_mode 2 exposes size flags differently in 4.6 — set them in code
	$MarginContainer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	$MarginContainer/HBoxContainer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	$MarginContainer/HBoxContainer/TextColumn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	$MarginContainer/HBoxContainer/TextColumn/NameAndTimeLine.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contact_name.size_flags_horizontal    = Control.SIZE_EXPAND_FILL
	contact_time.size_flags_horizontal    = Control.SIZE_SHRINK_END
	$MarginContainer/HBoxContainer/TextColumn/PreviewBadgeLine.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contact_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _format_time_display(raw: String) -> String:
	if raw.is_empty() or " " not in raw:
		return raw
	var parts := raw.split(" ", false, 1)
	if parts.size() != 2:
		return raw
	var date_parts := parts[0].split("-")
	if date_parts.size() != 3:
		return raw
	var today := Time.get_date_dict_from_system()
	if int(date_parts[0]) == today["year"] and int(date_parts[1]) == today["month"] and int(date_parts[2]) == today["day"]:
		return parts[1]
	if TranslationServer.get_locale().begins_with("fr"):
		return "%s-%s-%s %s" % [date_parts[2], date_parts[1], date_parts[0], parts[1]]
	return raw

func setup(contact: Dictionary, last_message: Dictionary, unread: bool) -> void:
	var contact_label = contact.get("name", "")
	contact_name.text = contact_label
	initial_label.text = contact_label[0].to_upper() if contact_label.length() > 0 else "?"
	unread_badge.visible = unread

	if last_message.is_empty():
		contact_time.text = ""
		contact_preview.text = "Aucun message"
	else:
		contact_time.text = _format_time_display(last_message.get("time", ""))
		var prefix: String = tr("MSG_YOU_PREFIX") if last_message.get("out", false) else ""
		var raw = last_message.get("text", null)
		var media = last_message.get("media", null)
		var preview: String
		if raw != null:
			preview = str(raw)
		elif media != null:
			preview = "📷 Photo"
		else:
			preview = ""
		if preview.length() > MAX_PREVIEW_LENGTH:
			preview = preview.substr(0, MAX_PREVIEW_LENGTH) + "…"
		contact_preview.text = prefix + preview

	var avatar_path = contact.get("avatar", null)
	if avatar_path != null and ResourceLoader.exists(avatar_path):
		var tex = load(avatar_path)
		if tex != null:
			var panel = initial_label.get_parent()
			var texture_rect = TextureRect.new()
			texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			texture_rect.texture = tex
			texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			texture_rect.clip_contents = true
			texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel.add_child(texture_rect)
			initial_label.visible = false
