extends PanelContainer

func _ready() -> void:
	custom_minimum_size.x = get_viewport_rect().size.x * 0.45
	var is_out := get_index() > 0
	ThemeManager.restyle_bubble(self, is_out)
	var msg_label  := get_node_or_null("MarginContainer/VBoxContainer/Message") as Label
	if msg_label:
		msg_label.add_theme_color_override("font_color", ThemeManager.text_color)
		msg_label.add_theme_font_size_override("font_size", ThemeManager.font_size)
	var time_label := get_node_or_null("MarginContainer/VBoxContainer/TimeAndStatus") as Label
	if time_label:
		var tc := ThemeManager.time_color
		time_label.add_theme_color_override("font_color", Color(tc.r, tc.g, tc.b, 0.75) if is_out else tc)
