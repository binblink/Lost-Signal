extends PanelContainer

signal menu_requested
signal desktop_requested
signal close_requested


func _ready() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = ThemeManager.topbar_color
	panel_style.corner_radius_top_left     = 12
	panel_style.corner_radius_top_right    = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.corner_radius_bottom_left  = 12
	panel_style.shadow_color  = Color(0, 0, 0, 0.4)
	panel_style.shadow_size   = 8
	panel_style.shadow_offset = Vector2(0, 4)
	add_theme_stylebox_override("panel", panel_style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   28)
	margin.add_theme_constant_override("margin_top",    24)
	margin.add_theme_constant_override("margin_right",  28)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = tr("EXIT_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", ThemeManager.text_color)
	title.add_theme_font_size_override("font_size", 15)
	vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(spacer)

	var btn_menu := _make_button(tr("EXIT_MAIN_MENU"), ThemeManager.accent_color, ThemeManager.text_color)
	btn_menu.custom_minimum_size = Vector2(220, 40)
	btn_menu.pressed.connect(func() -> void: menu_requested.emit())
	vbox.add_child(btn_menu)

	var btn_desktop := _make_button(tr("EXIT_DESKTOP"), Color(0.55, 0.12, 0.12, 1), ThemeManager.text_color)
	btn_desktop.custom_minimum_size = Vector2(220, 40)
	btn_desktop.pressed.connect(func() -> void: desktop_requested.emit())
	vbox.add_child(btn_desktop)

	var btn_cancel := _make_button(tr("BTN_CANCEL"), ThemeManager.topbar_color.lightened(0.08), ThemeManager.time_color)
	btn_cancel.custom_minimum_size = Vector2(220, 40)
	btn_cancel.pressed.connect(func() -> void: close_requested.emit())
	vbox.add_child(btn_cancel)


func _make_button(label: String, bg: Color, fg: Color) -> Button:
	var btn := Button.new()
	btn.text = label
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.corner_radius_top_left     = 8
	style.corner_radius_top_right    = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left  = 8
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("focus",  style)
	var hover_style := style.duplicate() as StyleBoxFlat
	hover_style.bg_color = bg.lightened(0.12)
	btn.add_theme_stylebox_override("hover", hover_style)
	var pressed_style := style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = bg.darkened(0.15)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_color_override("font_color", fg)
	return btn
