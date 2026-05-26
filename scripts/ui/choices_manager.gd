extends Control

signal choice_selected(index: int)

# Références passées par main.gd au _ready
var message_display: VBoxContainer = null
var scroll_container: ScrollContainer = null
var input_bar: Control = null

var _choice_buttons: Array = []
var _spacer: Control = null

func _ready() -> void:
	visible = false
	var buttons = get_child(0).get_child(0).get_children()
	for i in range(buttons.size()):
		_choice_buttons.append(buttons[i])
		buttons[i].pressed.connect(_on_button_pressed.bind(i))
	gui_input.connect(_on_gui_input)

func show_choices(options: Array) -> void:
	for i in range(_choice_buttons.size()):
		if i < options.size():
			_choice_buttons[i].text = options[i]
			_choice_buttons[i].visible = true
		else:
			_choice_buttons[i].visible = false
	visible = true
	if input_bar:
		input_bar.visible = false
	await get_tree().process_frame
	await get_tree().process_frame
	var buttons_container = get_child(0).get_child(0)
	_spacer = Control.new()
	_spacer.custom_minimum_size.y = buttons_container.size.y
	if message_display:
		message_display.add_child(_spacer)
		await message_display.scroll_to_bottom()

func hide_choices() -> void:
	visible = false
	for btn in _choice_buttons:
		btn.visible = true
	if _spacer:
		_spacer.queue_free()
		_spacer = null

func _on_button_pressed(index: int) -> void:
	choice_selected.emit(index)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if scroll_container:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				scroll_container.scroll_vertical -= 60
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				scroll_container.scroll_vertical += 60
