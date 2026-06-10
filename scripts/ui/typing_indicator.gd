extends PanelContainer

@onready var dot1 = %Dot1
@onready var dot2 = %Dot2
@onready var dot3 = %Dot3

func _ready() -> void:
	dot1.modulate.a = 0.3
	dot2.modulate.a = 0.3
	dot3.modulate.a = 0.3
	animate()

func animate() -> void:
	while true:
		await pulse(dot1)
		await pulse(dot2)
		await pulse(dot3)

func pulse(dot: Label) -> void:
	var tween = create_tween()
	tween.tween_property(dot, "modulate:a", 1.0, 0.25)
	await tween.finished
	tween = create_tween()
	tween.tween_property(dot, "modulate:a", 0.3, 0.25)
	await tween.finished
