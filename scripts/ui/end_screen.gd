# =============================================================================
# END SCREEN FEATURE — scripts/ui/end_screen.gd
# =============================================================================
# Self-contained end screen shown when a scene with "end": true finishes.
# Instantiated and driven by main.gd via setup(data).
#
# TO REMOVE THIS FEATURE ENTIRELY:
#   1. Delete this file  (scripts/ui/end_screen.gd)
#   2. Delete            shaders/glitch_scanline.gdshader
#   3. narrative_controller.gd — remove the two blocks marked [END SCREEN]
#      (signal game_ended declaration + 4 lines in _trigger_next_scenes)
#   4. main.gd           — remove the two blocks marked [END SCREEN]
#      (signal connection + the _on_game_ended function)
#   5. dialogue_loader.gd — remove the three blocks marked [END SCREEN]
#      (_end_screen var + 1 line in _load_story + get_end_screen function)
#   6. ContactsPanel.gd  — remove the two blocks marked [END SCREEN]
#      (_build_end_screen call in refresh + the _build_end_screen function)
#   7. translations/ui.csv — remove BTN_QUIT and END_SCREEN_MSGS rows
#   8. story.json        — remove "end_screen" key and "end": true on scenes
#
# Nothing outside these marked blocks depends on this feature.
# =============================================================================

class_name EndScreen
extends CanvasLayer

signal new_game_requested
signal quit_requested

const GLITCH_CHARS := "!@#$%&*?|▓█░▒╔╗╚╝║═▌▐▀▄01~^;:"
const SEP          := "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

var _title_label:  Label     = null
var _title_text:   String    = ""
var _do_glitch:    bool      = false
# CanvasLayer has no modulate — we fade this Control child instead.
var _canvas:       Control   = null


func setup(data: Dictionary) -> void:
	_title_text = data.get("title", "CONNECTION TERMINATED")
	_do_glitch  = data.get("glitch", false)

	layer = 10

	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.modulate.a = 0.0
	add_child(_canvas)

	var mono_font := _make_mono_font()

	# ── Full-screen dark background ──────────────────────────────────────────
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = ThemeManager.background_color.lerp(Color.BLACK, 0.65)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.add_child(bg)

	# ── Scanline overlay (glitch only) ───────────────────────────────────────
	if _do_glitch and ResourceLoader.exists("res://shaders/glitch_scanline.gdshader"):
		var scanline := ColorRect.new()
		scanline.set_anchors_preset(Control.PRESET_FULL_RECT)
		scanline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/glitch_scanline.gdshader")
		scanline.material = mat
		_canvas.add_child(scanline)

	# ── Centered content ─────────────────────────────────────────────────────
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(500, 0)
	vbox.add_theme_constant_override("separation", 10)
	center.add_child(vbox)

	_add_sep(vbox, mono_font)

	_title_label = _make_label(_title_text, mono_font, 20, ThemeManager.accent_color)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	_add_sep(vbox, mono_font)
	_add_spacer(vbox, 6)

	# Stats (optional)
	if data.get("show_stats", false) and data.has("_stats_messages"):
		var msgs: int = data["_stats_messages"]
		var stats_lbl := _make_label(
			tr("END_SCREEN_MSGS") % msgs,
			mono_font, 13,
			ThemeManager.text_color.lerp(Color.BLACK, 0.25))
		stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(stats_lbl)
		_add_spacer(vbox, 4)

	# Custom text (optional)
	var custom_text: String = data.get("text", "")
	if not custom_text.is_empty():
		var text_lbl := _make_label(custom_text, mono_font, 15, ThemeManager.text_color)
		text_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		vbox.add_child(text_lbl)
		_add_spacer(vbox, 4)

	# Link (optional)
	var link_url: String = data.get("link_url", "")
	if not link_url.is_empty():
		var link := LinkButton.new()
		link.text = data.get("link_label", link_url)
		link.uri  = link_url
		link.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		link.add_theme_font_override("font", mono_font)
		link.add_theme_font_size_override("font_size", 13)
		link.add_theme_color_override("font_color", ThemeManager.accent_color)
		link.add_theme_color_override("font_hover_color", ThemeManager.accent_color.lightened(0.2))
		vbox.add_child(link)
		_add_spacer(vbox, 4)

	# Buttons
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)

	var btn_new := _make_button(tr("MENU_NEW_GAME"), mono_font)
	btn_new.pressed.connect(func() -> void: new_game_requested.emit())
	hbox.add_child(btn_new)

	var btn_quit := _make_button(tr("BTN_QUIT"), mono_font)
	btn_quit.pressed.connect(func() -> void: quit_requested.emit())
	hbox.add_child(btn_quit)

	_add_sep(vbox, mono_font)

	# ── Entrance fade-in ─────────────────────────────────────────────────────
	var tween := create_tween()
	tween.tween_property(_canvas, "modulate:a", 1.0, 5.0)

	# ── Start glitch loops ───────────────────────────────────────────────────
	if _do_glitch:
		_run_glitch_loop()
		_run_flicker_loop()


# ── Glitch loops ─────────────────────────────────────────────────────────────

func _run_glitch_loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(randf_range(3.0, 8.0)).timeout
		if not is_inside_tree():
			return
		var roll := randf()
		if roll < 0.50:
			await _scatter(randi_range(1, 4))
		elif roll < 0.80:
			await _flood(randf_range(0.40, 0.70))
		else:
			await _stutter()


func _run_flicker_loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(randf_range(4.0, 12.0)).timeout
		if not is_inside_tree():
			return
		var tween := create_tween()
		tween.tween_property(_canvas, "modulate:a", randf_range(0.60, 0.88), 0.04)
		tween.tween_property(_canvas, "modulate:a", 1.0, 0.05)
		if randf() < 0.35:
			tween.tween_property(_canvas, "modulate:a", randf_range(0.72, 0.92), 0.03)
			tween.tween_property(_canvas, "modulate:a", 1.0, 0.05)


func _scatter(count: int) -> void:
	_title_label.add_theme_color_override("font_color", ThemeManager.accent_color)
	var chars: Array[String] = []
	for c: String in _title_text:
		chars.append(c)
	var positions := range(_title_text.length())
	positions.shuffle()
	var replaced := 0
	for pos: int in positions:
		if replaced >= count:
			break
		if _title_text[pos] != " ":
			chars[pos] = _rand_glitch_char()
			replaced += 1
	_title_label.text = "".join(chars)
	await get_tree().create_timer(randf_range(0.05, 0.12)).timeout
	if not is_inside_tree():
		return
	_title_label.text = _title_text
	_title_label.add_theme_color_override("font_color", ThemeManager.accent_color)


func _flood(intensity: float) -> void:
	_title_label.add_theme_color_override("font_color", ThemeManager.accent_color)
	var chars: Array[String] = []
	for c: String in _title_text:
		chars.append(c if c == " " or randf() > intensity else _rand_glitch_char())
	_title_label.text = "".join(chars)
	await get_tree().create_timer(randf_range(0.08, 0.20)).timeout
	if not is_inside_tree():
		return
	_title_label.text = _title_text
	_title_label.add_theme_color_override("font_color", ThemeManager.accent_color)


func _stutter() -> void:
	_title_label.add_theme_color_override("font_color", ThemeManager.accent_color)
	for i: int in range(randi_range(3, 7)):
		if i % 2 == 0:
			var chars: Array[String] = []
			for c: String in _title_text:
				chars.append(c if c == " " or randf() > 0.60 else _rand_glitch_char())
			_title_label.text = "".join(chars)
		else:
			_title_label.text = _title_text
		await get_tree().create_timer(randf_range(0.022, 0.045)).timeout
		if not is_inside_tree():
			return
	_title_label.text = _title_text
	_title_label.add_theme_color_override("font_color", ThemeManager.accent_color)


func _rand_glitch_char() -> String:
	return GLITCH_CHARS[randi_range(0, GLITCH_CHARS.length() - 1)]


# ── UI helpers ────────────────────────────────────────────────────────────────

func _make_mono_font() -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray([
		"Consolas", "Lucida Console", "Courier New",
		"Menlo", "Monaco", "DejaVu Sans Mono", "Liberation Mono",
	])
	f.font_weight = 700
	f.allow_system_fallback = true
	return f


func _make_label(text: String, font: SystemFont, size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", font)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	return lbl


func _make_button(text: String, font: SystemFont) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(150, 42)
	btn.add_theme_font_override("font", font)
	btn.add_theme_font_size_override("font_size", 14)
	ThemeManager.restyle_button(btn, ThemeManager.topbar_color)
	btn.add_theme_color_override("font_color", ThemeManager.text_color)
	return btn


func _add_sep(parent: VBoxContainer, font: SystemFont) -> void:
	var lbl := _make_label(SEP, font, 11, ThemeManager.accent_color.lerp(Color.BLACK, 0.35))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(lbl)


func _add_spacer(parent: VBoxContainer, height: int) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, height)
	parent.add_child(s)
