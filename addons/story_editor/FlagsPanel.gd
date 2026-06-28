@tool
extends Control

# Propriétés injectées par StoryEditorPanel
var scenes:      Dictionary = {}
var focus_scene: Callable           # func(scene_id: String) -> void
var ui_locale:   String    = "fr"

const HEADER_COLOR := Color(0.10, 0.14, 0.18)
const ROW_COLOR    := Color(0.14, 0.19, 0.24)


func refresh() -> void:
	for child in get_children():
		child.free()

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top",    8)
	margin.add_theme_constant_override("margin_left",   8)
	margin.add_theme_constant_override("margin_right",  8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(vbox)

	var flags_data: Dictionary = _collect_all_flags()

	if flags_data.is_empty():
		var lbl := Label.new()
		lbl.text = _t("Aucun flag défini dans le projet.", "No flags defined in this project.")
		vbox.add_child(lbl)
		return

	for flag_name: String in flags_data:
		_add_flag_entry(vbox, flag_name, flags_data[flag_name])


# ---------------------------------------------------------------------------
# Collecte des flags

# Retourne un dictionnaire trié : flag_name → { set: [], waited: [], required: [] }
func _collect_all_flags() -> Dictionary:
	var result: Dictionary = {}

	for sid: String in scenes:
		var scene: Dictionary = scenes[sid]

		# Flags DÉFINIS par des choix (choice.flag)
		for ch: Dictionary in scene.get("choices", []):
			var f: String = str(ch.get("flag", ""))
			if f:
				_ensure_flag(result, f)
				var entry: Dictionary = result[f]
				var set_list: Array = entry["set"]
				if not set_list.has(sid):
					set_list.append(sid)

		# resume_after_flag — scène qui ATTEND ce flag pour se déclencher
		var raf: String = str(scene.get("resume_after_flag", ""))
		if raf:
			_ensure_flag(result, raf)
			var entry: Dictionary = result[raf]
			var waited_list: Array = entry["waited"]
			if not waited_list.has(sid):
				waited_list.append(sid)

		# requires_flag au niveau de la scène
		_collect_requires(scene.get("requires_flag", null), sid, result)
		# requires_flag / condition sur chaque message
		for msg: Dictionary in scene.get("messages_in", []):
			_collect_requires(msg.get("requires_flag", null), sid, result)
			_collect_requires(msg.get("condition", null),     sid, result)
		# requires_flag / condition sur chaque choix
		for ch: Dictionary in scene.get("choices", []):
			_collect_requires(ch.get("requires_flag", null), sid, result)
			_collect_requires(ch.get("condition", null),     sid, result)

	# Tri alphabétique
	var keys: Array = result.keys()
	keys.sort()
	var sorted: Dictionary = {}
	for k: String in keys:
		sorted[k] = result[k]
	return sorted


func _ensure_flag(result: Dictionary, name: String) -> void:
	if not result.has(name):
		result[name] = { "set": [], "waited": [], "required": [] }


# Extrait récursivement les noms de flags depuis requires_flag / condition.
func _collect_requires(value: Variant, sid: String, result: Dictionary) -> void:
	if value == null:
		return
	if value is String:
		var s: String = value
		if s:
			_ensure_flag(result, s)
			var entry: Dictionary = result[s]
			var req_list: Array = entry["required"]
			if not req_list.has(sid):
				req_list.append(sid)
	elif value is Array:
		for item: Variant in value:
			_collect_requires(item, sid, result)
	elif value is Dictionary:
		# { "flag": "name" } — feuille
		var val_dict: Dictionary = value
		if val_dict.has("flag"):
			_collect_requires(str(val_dict["flag"]), sid, result)
		# { "and": [...] } / { "or": [...] }
		for op: String in ["and", "or"]:
			if val_dict.has(op) and val_dict[op] is Array:
				for sub: Variant in val_dict[op]:
					_collect_requires(sub, sid, result)
		# { "not": {...} }
		if val_dict.has("not"):
			_collect_requires(val_dict["not"], sid, result)


# ---------------------------------------------------------------------------
# Construction de l'UI

func _add_flag_entry(parent: VBoxContainer, flag_name: String, data: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = HEADER_COLOR
	style.corner_radius_top_left     = 4
	style.corner_radius_top_right    = 4
	style.corner_radius_bottom_left  = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	# En-tête : nom du flag
	var header := MarginContainer.new()
	header.add_theme_constant_override("margin_left",  8)
	header.add_theme_constant_override("margin_top",   4)
	header.add_theme_constant_override("margin_bottom",4)
	vbox.add_child(header)
	var name_lbl := Label.new()
	name_lbl.text = "🚩 " + flag_name
	name_lbl.add_theme_font_size_override("font_size", 13)
	header.add_child(name_lbl)

	# Lignes de références
	var set_list:    Array = data["set"]
	var waited_list: Array = data["waited"]
	var req_list:    Array = data["required"]
	_add_scene_row(vbox, _t("Défini par", "Set by"),      set_list,    "✏️")
	_add_scene_row(vbox, _t("Attendu par", "Waited by"),  waited_list, "⏱")
	_add_scene_row(vbox, _t("Requis par", "Required by"), req_list,    "?")


func _add_scene_row(parent: VBoxContainer, label_text: String, scene_ids: Array, icon: String) -> void:
	if scene_ids.is_empty():
		return

	var row := MarginContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("margin_left",   8)
	row.add_theme_constant_override("margin_right",  8)
	row.add_theme_constant_override("margin_top",    2)
	row.add_theme_constant_override("margin_bottom", 2)
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = ROW_COLOR
	row.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	parent.add_child(row)

	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 6)
	row.add_child(hbox)

	var lbl := Label.new()
	lbl.text = icon + " " + label_text + " :"
	lbl.custom_minimum_size.x = 120
	lbl.add_theme_font_size_override("font_size", 11)
	hbox.add_child(lbl)

	for sid: String in scene_ids:
		var btn := Button.new()
		btn.text = sid
		btn.flat = true
		btn.add_theme_font_size_override("font_size", 11)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.tooltip_text = _t("Centrer le graphe sur cette scène", "Center graph on this scene")
		btn.pressed.connect(func() -> void:
			if focus_scene.is_valid():
				focus_scene.call(sid))
		hbox.add_child(btn)


func _t(fr: String, en: String) -> String:
	return fr if ui_locale == "fr" else en
