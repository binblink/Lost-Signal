extends Control

@onready var _background      = %Background
@onready var _title           = %GameTitle
@onready var _btn_continue    = %BtnContinue
@onready var _btn_new_game    = %BtnNewGame
@onready var _btn_settings    = %BtnSettings
@onready var _overlay         = %Overlay
@onready var _settings_dialog = %SettingsDialog

var TITLE_TEXT: String
const GLITCH_CHARS := "!@#$%&*?|▓█░▒╔╗╚╝║═▌▐▀▄01~^;:"


func _ready() -> void:
	TITLE_TEXT = DialogueLoader.get_title()
	_background.color = ThemeManager.background_color.lerp(ThemeManager.accent_color, 0.04)
	var _bg_fx := preload("res://scripts/ui/main_menu_background.gd").new()
	add_child(_bg_fx)
	move_child(_bg_fx, 1)
	_title.add_theme_color_override("font_color", ThemeManager.text_color)
	_title.add_theme_font_size_override("font_size", 36)
	_title.add_theme_constant_override("outline_size", 0)
	_title.add_theme_constant_override("spacing_glyph", 3)
	var title_font := SystemFont.new()
	title_font.font_names = PackedStringArray([
		"Consolas", "Lucida Console", "Courier New",  # Windows
		"Menlo", "Monaco",                             # macOS
		"DejaVu Sans Mono", "Liberation Mono",         # Linux
	])
	title_font.font_weight = 700
	title_font.allow_system_fallback = true
	_title.add_theme_font_override("font", title_font)

	ThemeManager.restyle_button(_btn_continue, ThemeManager.topbar_color)
	ThemeManager.restyle_button(_btn_new_game, ThemeManager.accent_color)
	ThemeManager.restyle_button(_btn_settings, ThemeManager.topbar_color)
	for btn in [_btn_continue, _btn_new_game, _btn_settings]:
		btn.add_theme_color_override("font_color", ThemeManager.text_color)
		btn.add_theme_font_size_override("font_size", ThemeManager.font_size)

	var has_save := SaveManager.has_save()
	_btn_continue.disabled = not has_save
	if not has_save:
		_btn_continue.modulate.a = 0.35

	_btn_continue.pressed.connect(_on_continue)
	_btn_new_game.pressed.connect(_on_new_game)
	_btn_settings.pressed.connect(_on_settings_pressed)
	_settings_dialog.accepted.connect(_on_settings_accepted)
	_settings_dialog.cancelled.connect(func(): _overlay.visible = false)

	_title.text = TITLE_TEXT
	if ThemeManager.title_glitch:
		_run_glitch_loop()


func _run_glitch_loop() -> void:
	await _reveal_title()
	while is_inside_tree():
		await get_tree().create_timer(randf_range(2.0, 7.0)).timeout
		if not is_inside_tree():
			return
		var count := randi_range(1, 5)
		for i in range(count):
			var roll := randf()
			if roll < 0.45:
				await _scatter(randi_range(1, 6))
			elif roll < 0.80:
				await _flood(randf_range(0.40, 0.80))
			else:
				await _stutter()
			if not is_inside_tree():
				return
			if i < count - 1:
				await get_tree().create_timer(randf_range(0.01, 0.12)).timeout
				if not is_inside_tree():
					return


func _reveal_title() -> void:
	# Fill with solid blocks in accent color
	var block_str := ""
	for c in TITLE_TEXT:
		block_str += "█" if c != " " else " "
	_title.text = block_str
	_title.add_theme_color_override("font_color", ThemeManager.accent_color)
	await get_tree().create_timer(0.35).timeout
	if not is_inside_tree():
		return

	# Switch to normal color and start character decode
	_title.add_theme_color_override("font_color", ThemeManager.text_color)
	var chars := []
	for c in block_str:
		chars.append(c)

	var disruption_done := false
	for i in range(TITLE_TEXT.length()):
		chars[i] = TITLE_TEXT[i]

		# Random jitter: re-corrupt a recently revealed char
		if i > 2 and randf() < 0.30:
			var j := randi_range(0, i - 1)
			if TITLE_TEXT[j] != " ":
				var saved: String = chars[j]
				chars[j] = _rand_glitch_char()
				_title.text = "".join(chars)
				await get_tree().create_timer(0.03).timeout
				if not is_inside_tree():
					return
				chars[j] = saved

		_title.text = "".join(chars)

		# One big disruption mid-decode (~55%)
		if not disruption_done and i >= int(TITLE_TEXT.length() * 0.55):
			disruption_done = true
			await get_tree().create_timer(randf_range(0.02, 0.05)).timeout
			if not is_inside_tree():
				return
			await _flood(randf_range(0.65, 0.95))
			if not is_inside_tree():
				return
			# After the flood restore, re-apply the partial decode state
			_title.text = "".join(chars)
		else:
			await get_tree().create_timer(randf_range(0.025, 0.065)).timeout
			if not is_inside_tree():
				return

	_title.text = TITLE_TEXT
	await get_tree().create_timer(0.08).timeout
	if not is_inside_tree():
		return
	await _stutter()


func _scatter(count: int) -> void:
	_title.add_theme_color_override("font_color", ThemeManager.accent_color)
	var chars := []
	for c in TITLE_TEXT:
		chars.append(c)
	var positions := range(TITLE_TEXT.length())
	positions.shuffle()
	var replaced := 0
	for pos in positions:
		if replaced >= count:
			break
		if TITLE_TEXT[pos] != " ":
			chars[pos] = _rand_glitch_char()
			replaced += 1
	_title.text = "".join(chars)
	await get_tree().create_timer(randf_range(0.04, 0.10)).timeout
	if not is_inside_tree():
		return
	_title.text = TITLE_TEXT
	_title.add_theme_color_override("font_color", ThemeManager.text_color)


func _flood(intensity: float) -> void:
	_title.add_theme_color_override("font_color", ThemeManager.accent_color)
	var steps := randi_range(1, 3)
	for _s in range(steps):
		var chars := []
		for c in TITLE_TEXT:
			if c == " " or randf() > intensity:
				chars.append(c)
			else:
				chars.append(_rand_glitch_char())
		_title.text = "".join(chars)
		await get_tree().create_timer(randf_range(0.07, 0.18)).timeout
		if not is_inside_tree():
			return
	_title.text = TITLE_TEXT
	_title.add_theme_color_override("font_color", ThemeManager.text_color)


func _stutter() -> void:
	_title.add_theme_color_override("font_color", ThemeManager.accent_color)
	var flickers := randi_range(4, 9)
	for i in range(flickers):
		if i % 2 == 0:
			var chars := []
			for c in TITLE_TEXT:
				if c == " ":
					chars.append(c)
				elif randf() < 0.65:
					chars.append(_rand_glitch_char())
				else:
					chars.append(c)
			_title.text = "".join(chars)
		else:
			_title.text = TITLE_TEXT
		await get_tree().create_timer(randf_range(0.022, 0.042)).timeout
		if not is_inside_tree():
			return
	_title.text = TITLE_TEXT
	_title.add_theme_color_override("font_color", ThemeManager.text_color)


func _rand_glitch_char() -> String:
	return GLITCH_CHARS[randi_range(0, GLITCH_CHARS.length() - 1)]


func _on_continue() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _on_new_game() -> void:
	SaveManager.delete_save()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_settings_pressed() -> void:
	_overlay.visible = true
	_settings_dialog.open()

func _on_settings_accepted(language_changed: bool) -> void:
	_overlay.visible = false
	if language_changed:
		DialogueLoader.reload_for_locale()
		get_tree().reload_current_scene()
