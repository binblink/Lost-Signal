extends PanelContainer

func _ready() -> void:
	custom_minimum_size.x = get_viewport_rect().size.x * 0.45
