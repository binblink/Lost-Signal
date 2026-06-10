extends Node

const THEME_PATH = "res://theme.json"

var background_color: Color = Color(0.043137256, 0.05490196, 0.06666667)
var topbar_color:     Color = Color(0.12156863,  0.17254902, 0.20392157)
var bubble_in_color:  Color = Color(0.13,        0.19,       0.24)
var bubble_out_color: Color = Color(0.0,         0.44,       0.36)
var accent_color:     Color = Color(0.0,         0.65882355, 0.5176471)
var text_color:       Color = Color(0.9137255,   0.92941177, 0.9372549)
var time_color:       Color = Color(0.5254902,   0.5882353,  0.627451)
var font_size:        int   = 15
var typing_speed:     float = 0.05


func _ready() -> void:
	_load()


func _load() -> void:
	if not FileAccess.file_exists(THEME_PATH):
		return
	var file = FileAccess.open(THEME_PATH, FileAccess.READ)
	if file == null:
		push_warning("ThemeManager: impossible d'ouvrir theme.json (code %d) — thème par défaut utilisé." % FileAccess.get_open_error())
		return
	var json = JSON.new()
	var err  = json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_warning("ThemeManager: theme.json invalide — thème par défaut utilisé.")
		return
	var data = json.get_data()
	if not data is Dictionary:
		return
	if data.has("background_color"): background_color = Color(data["background_color"])
	if data.has("topbar_color"):     topbar_color     = Color(data["topbar_color"])
	if data.has("bubble_in_color"):  bubble_in_color  = Color(data["bubble_in_color"])
	if data.has("bubble_out_color"): bubble_out_color = Color(data["bubble_out_color"])
	if data.has("accent_color"):     accent_color     = Color(data["accent_color"])
	if data.has("text_color"):       text_color       = Color(data["text_color"])
	if data.has("time_color"):       time_color       = Color(data["time_color"])
	if data.has("font_size"):        font_size        = int(data["font_size"])
	if data.has("typing_speed"):     typing_speed     = float(data["typing_speed"])


# Applique une couleur de fond à un PanelContainer ou ScrollContainer.
func restyle_panel(panel: Control, color: Color) -> void:
	var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style == null:
		return
	var s := style.duplicate() as StyleBoxFlat
	s.bg_color = color
	panel.add_theme_stylebox_override("panel", s)


# Applique bubble_in_color ou bubble_out_color + recalcule border et shadow.
func restyle_bubble(panel: Control, is_out: bool) -> void:
	var base  := bubble_out_color if is_out else bubble_in_color
	var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style == null:
		return
	var s := style.duplicate() as StyleBoxFlat
	s.bg_color     = base
	s.border_color = Color(min(1.0, base.r * 1.4), min(1.0, base.g * 1.4), min(1.0, base.b * 1.4),
	                       0.45 if is_out else 0.50)
	s.shadow_color = Color(base.r * 0.68, base.g * 0.68, base.b * 0.68, 0.25)
	panel.add_theme_stylebox_override("panel", s)


func restyle_button(btn: Button, base_color: Color) -> void:
	var states := {
		"normal":        base_color,
		"focus":         base_color,
		"hover":         Color(min(1.0, base_color.r * 1.2), min(1.0, base_color.g * 1.2), min(1.0, base_color.b * 1.2)),
		"hover_pressed": Color(min(1.0, base_color.r * 1.2), min(1.0, base_color.g * 1.2), min(1.0, base_color.b * 1.2)),
		"pressed":       Color(base_color.r * 0.8, base_color.g * 0.8, base_color.b * 0.8),
	}
	for state in states:
		var s := StyleBoxFlat.new()
		s.bg_color                   = states[state]
		s.corner_radius_top_left     = 8
		s.corner_radius_top_right    = 8
		s.corner_radius_bottom_right = 8
		s.corner_radius_bottom_left  = 8
		s.content_margin_left        = 24.0
		s.content_margin_right       = 24.0
		s.content_margin_top         = 10.0
		s.content_margin_bottom      = 10.0
		btn.add_theme_stylebox_override(state, s)


# Applique le thème complet sur un bouton de choix (normal / hover / pressed).
func restyle_choice_button(btn: Button) -> void:
	var tc := topbar_color
	var ac := accent_color
	var defs := {
		"normal":        [Color(tc.r * 0.74, tc.g * 0.81, tc.b * 0.88, 0.97),
		                  Color(tc.r,         ac.g * 0.58, ac.b * 0.89, 0.50)],
		"focus":         [Color(tc.r * 0.74, tc.g * 0.81, tc.b * 0.88, 0.97),
		                  Color(tc.r,         ac.g * 0.58, ac.b * 0.89, 0.50)],
		"hover":         [Color(ac.r * 0.76, ac.g * 0.76, ac.b * 0.76, 0.92),
		                  Color(ac.r,         min(1.0, ac.g * 1.10), min(1.0, ac.b * 1.10), 0.85)],
		"pressed":       [Color(ac.r * 0.545, ac.g * 0.545, ac.b * 0.545, 0.95),
		                  Color(ac.r * 0.842, ac.g * 0.842, ac.b * 0.842, 0.90)],
		"hover_pressed": [Color(ac.r * 0.545, ac.g * 0.545, ac.b * 0.545, 0.95),
		                  Color(ac.r * 0.842, ac.g * 0.842, ac.b * 0.842, 0.90)],
	}
	for state in defs:
		var style := btn.get_theme_stylebox(state) as StyleBoxFlat
		if style == null:
			continue
		var s := style.duplicate() as StyleBoxFlat
		s.bg_color     = defs[state][0]
		s.border_color = defs[state][1]
		btn.add_theme_stylebox_override(state, s)
	btn.add_theme_color_override("font_color", text_color)
	btn.add_theme_font_size_override("font_size", font_size)
