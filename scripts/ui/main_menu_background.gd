extends Control

# Animated background: scrolling CRT scanlines + occasional signal-noise bursts.

const LINE_SPACING  := 4      # px between scanlines
const LINE_ALPHA    := 0.14
const SCROLL_SPEED  := 28.0   # px/s

var _scroll: float = 0.0
var _noise_timer: float = randf_range(2.0, 5.0)
var _noise_ttl: float = 0.0   # > 0 while a noise burst is active


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_scroll = fmod(_scroll + SCROLL_SPEED * delta, float(LINE_SPACING))

	_noise_timer -= delta
	if _noise_timer <= 0.0:
		_noise_timer = randf_range(3.0, 8.0)
		_noise_ttl   = randf_range(0.06, 0.20)

	if _noise_ttl > 0.0:
		_noise_ttl -= delta

	queue_redraw()


func _draw() -> void:
	var s := get_viewport_rect().size

	# Scanlines
	var line_color := Color(0.0, 0.0, 0.0, LINE_ALPHA)
	var y := -_scroll
	while y < s.y:
		draw_line(Vector2(0.0, y), Vector2(s.x, y), line_color, 1.0)
		y += float(LINE_SPACING)

	# Signal-noise burst: thin horizontal glitch fragments in accent color
	if _noise_ttl > 0.0:
		var accent := ThemeManager.accent_color
		var count := randi_range(20, 80)
		for _i in range(count):
			var rx := randf() * s.x
			var ry := randf() * s.y
			var rw := randf_range(4.0, s.x * 0.18)
			draw_rect(
				Rect2(rx, ry, rw, 1.0),
				Color(accent.r, accent.g, accent.b, randf_range(0.04, 0.22))
			)
