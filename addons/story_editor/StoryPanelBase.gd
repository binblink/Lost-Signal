@tool
extends Control

signal story_modified
signal error_occurred(msg: String)

## Undo/redo callables — injected by StoryEditorPanel. No-op defaults so panels work standalone.
var begin_mutation: Callable = func(_label: String) -> void: pass
var end_mutation:   Callable = func() -> void: pass
var snapshot_file:  Callable = func(_path: String) -> void: pass

## Callable → Array of scene IDs; injected by StoryEditorPanel.
var get_scene_ids: Callable = func() -> Array: return []

const STORY_PATH := "res://story.json"
const CSV_PATH   := "res://translations/ui.csv"

var _content: VBoxContainer


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   10)
	margin.add_theme_constant_override("margin_right",  10)
	margin.add_theme_constant_override("margin_top",     8)
	margin.add_theme_constant_override("margin_bottom",  8)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 4)
	scroll.add_child(_content)
	refresh()


func refresh() -> void:
	pass


# ---------------------------------------------------------------------------
# story.json read / write

func _read_story() -> Dictionary:
	var f := FileAccess.open(STORY_PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if parsed is Dictionary else {}


func _write_story(data: Dictionary, label: String = "") -> void:
	begin_mutation.call(label if label != "" else _t("Modifier story.json", "Edit story.json"))
	snapshot_file.call(STORY_PATH)
	var tmp_path: String = STORY_PATH + ".tmp"
	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		error_occurred.emit(_t("Erreur écriture : story.json", "Write error: story.json"))
		end_mutation.call()
		return
	f.store_string(_json_expand(_ordered_story(data), "") + "\n")
	f.close()
	if FileAccess.file_exists(STORY_PATH):
		DirAccess.remove_absolute(STORY_PATH)
	var dir := DirAccess.open("res://")
	if dir == null:
		error_occurred.emit(_t("Erreur écriture : story.json", "Write error: story.json"))
		end_mutation.call()
		return
	var err := dir.rename("story.json.tmp", "story.json")
	if err != OK:
		error_occurred.emit(_t("Erreur écriture : story.json", "Write error: story.json"))
		end_mutation.call()
		return
	end_mutation.call()
	story_modified.emit()


func _ordered_story(data: Dictionary) -> Dictionary:
	const KEYS := ["title", "start_scene", "start_contact", "contacts"]
	var result := {}
	for k in KEYS:
		if data.has(k):
			result[k] = data[k]
	for k in data:
		if not result.has(k):
			result[k] = data[k]
	if result.has("contacts"):
		var arr: Array = []
		for c in (result["contacts"] as Array):
			arr.append(_ordered_contact(c))
		result["contacts"] = arr
	return result


func _ordered_contact(c: Dictionary) -> Dictionary:
	const KEYS := ["id", "name", "names", "is_main", "avatar", "status", "pending_scene", "history"]
	var result := {}
	for k in KEYS:
		if c.has(k):
			result[k] = c[k]
	for k in c:
		if not result.has(k):
			result[k] = c[k]
	if result.has("history"):
		var arr: Array = []
		for entry in (result["history"] as Array):
			var e := {}
			for hk in ["text", "time", "out"]:
				if entry.has(hk):
					e[hk] = entry[hk]
			for hk in entry:
				if not e.has(hk):
					e[hk] = entry[hk]
			arr.append(e)
		result["history"] = arr
	return result


# ---------------------------------------------------------------------------
# Widget helpers

func _section(container: VBoxContainer, title: String, bg_color: Color = Color(0.15, 0.15, 0.18)) -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.content_margin_left   = 6
	style.content_margin_right  = 6
	style.content_margin_top    = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0))
	panel.add_child(lbl)
	container.add_child(panel)


func _line_edit(container: VBoxContainer, label: String, initial: String, placeholder: String, on_commit: Callable, tooltip: String = "") -> void:
	var row := HBoxContainer.new()
	_label(row, label, 110)
	var edit := LineEdit.new()
	edit.text = initial
	edit.placeholder_text = placeholder
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if tooltip:
		edit.tooltip_text = tooltip
	edit.focus_exited.connect(func() -> void:
		var val := edit.text.strip_edges()
		if val != initial:
			on_commit.call(val))
	row.add_child(edit)
	container.add_child(row)


func _dropdown(container: VBoxContainer, label: String, current: String, options: Array, none_label: String, on_change: Callable, tooltip: String = "") -> void:
	var opts_list := options.duplicate()
	if current and not opts_list.has(current):
		opts_list.append(current)
		opts_list.sort()
	var row := HBoxContainer.new()
	_label(row, label, 110)
	var opts := OptionButton.new()
	opts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if tooltip:
		opts.tooltip_text = tooltip
	opts.add_item(none_label)
	var selected := 0
	for i in range(opts_list.size()):
		opts.add_item(str(opts_list[i]))
		if str(opts_list[i]) == current:
			selected = i + 1
	opts.selected = selected
	opts.item_selected.connect(func(idx: int) -> void:
		if idx == 0:
			on_change.call("")
		else:
			on_change.call(str(opts_list[idx - 1])))
	row.add_child(opts)
	container.add_child(row)


func _label(parent: HBoxContainer, text: String, min_width: int) -> void:
	var lbl := Label.new()
	lbl.text = text
	if min_width > 0:
		lbl.custom_minimum_size = Vector2(min_width, 0)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	parent.add_child(lbl)


func _checkbox(container: VBoxContainer, label: String, initial: bool, on_change: Callable, tooltip: String = "") -> void:
	var row := HBoxContainer.new()
	_label(row, label, 110)
	var cb := CheckBox.new()
	cb.button_pressed = initial
	cb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not tooltip.is_empty():
		cb.tooltip_text = tooltip
	cb.toggled.connect(func(pressed: bool) -> void: on_change.call(pressed))
	row.add_child(cb)
	container.add_child(row)


# ---------------------------------------------------------------------------
# Utilities

func _get_supported_locales() -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open("res://translations/")
	if dir != null:
		dir.list_dir_begin()
		var f := dir.get_next()
		while f != "":
			if f.ends_with(".translation"):
				var parts := f.get_basename().split(".")
				if parts.size() == 2 and not parts[1].is_empty():
					result.append(parts[1])
			f = dir.get_next()
		dir.list_dir_end()
	result.sort()
	return result if not result.is_empty() else ["fr", "en"]


func _t(fr: String, en: String) -> String:
	return fr if OS.get_locale_language() == "fr" else en


func _json_compact(value: Variant) -> String:
	if value is Dictionary:
		if (value as Dictionary).is_empty():
			return "{}"
		var parts: Array[String] = []
		for key in value:
			parts.append(JSON.stringify(str(key)) + ": " + _json_compact(value[key]))
		return "{" + ", ".join(parts) + "}"
	if value is Array:
		if (value as Array).is_empty():
			return "[]"
		var parts: Array[String] = []
		for item in value:
			parts.append(_json_compact(item))
		return "[" + ", ".join(parts) + "]"
	return JSON.stringify(value)


func _json_expand(value: Variant, indent: String) -> String:
	if indent.length() >= 4:
		return _json_compact(value)
	if value is Dictionary:
		if (value as Dictionary).is_empty():
			return "{}"
		var next_indent := indent + "\t"
		var parts: Array[String] = []
		for key in value:
			parts.append(next_indent + JSON.stringify(str(key)) + ": " + _json_expand(value[key], next_indent))
		return "{\n" + ",\n".join(parts) + "\n" + indent + "}"
	if value is Array:
		if (value as Array).is_empty():
			return "[]"
		var next_indent := indent + "\t"
		var parts: Array[String] = []
		for item in value:
			parts.append(next_indent + _json_expand(item, next_indent))
		return "[\n" + ",\n".join(parts) + "\n" + indent + "]"
	return JSON.stringify(value)
