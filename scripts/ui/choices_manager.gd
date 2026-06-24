extends Control

signal choice_selected(index: int)

# References injected by main.gd before _ready
var message_display: VBoxContainer = null
var input_bar: Control = null

@onready var _buttons_container = %ButtonsContainer

var _choice_buttons: Array = []
var _spacer: Control = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_buttons_container.get_parent().mouse_filter = Control.MOUSE_FILTER_IGNORE
	_buttons_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	for i in range(_buttons_container.get_child_count()):
		var btn = _buttons_container.get_child(i)
		_choice_buttons.append(btn)
		btn.pressed.connect(_on_button_pressed.bind(i))
		ThemeManager.restyle_choice_button(btn)

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
	_spacer = Control.new()
	_spacer.custom_minimum_size.y = _buttons_container.get_parent().size.y
	if message_display:
		message_display.add_child(_spacer)
		await message_display.scroll_to_bottom()

func hide_choices() -> void:
	visible = false
	for btn in _choice_buttons:
		btn.visible = true
	if is_instance_valid(_spacer):
		_spacer.queue_free()
		_spacer = null

func _on_button_pressed(index: int) -> void:
	choice_selected.emit(index)
