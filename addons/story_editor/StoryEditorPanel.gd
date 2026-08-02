@tool
extends Control

signal files_written

const SceneParser      = preload("res://addons/story_editor/scene_parser.gd")
const JsonUtils        = preload("res://addons/story_editor/json_utils.gd")
const SceneDetailPanel = preload("res://addons/story_editor/SceneDetailPanel.gd")
const SafeFile         = preload("res://scripts/lib/safe_file.gd")

const COLOR_NORMAL  := Color(0.8, 0.8, 0.8)
const COLOR_TRIGGER := Color(1.0, 0.6, 0.0)
const COLOR_RESUME  := Color(0.7, 0.3, 1.0)

const H_SPACING := 480.0
const V_SPACING := 280.0

const POSITIONS_PATH := "res://addons/story_editor/.node_positions.json"

@onready var _status_label:    Label         = %StatusLabel
@onready var _refresh_button:  Button        = %RefreshButton
@onready var _reformat_button: Button        = %ReformatButton
@onready var _contacts_button: Button        = %ContactsButton
@onready var _settings_button: Button        = %SettingsButton
@onready var _undo_button:     Button        = %UndoButton
@onready var _redo_button:     Button        = %RedoButton
@onready var _graph:           GraphEdit     = %GraphEdit

var _locale_option:    OptionButton = null
var _contact_filter:   OptionButton = null
var _search_field:     LineEdit     = null
var _search_results:   Array[String] = []
var _search_index:     int           = 0
var _search_prev_btn:  Button        = null
var _search_next_btn:  Button        = null
var _ui_locale: String = OS.get_locale_language()
@onready var _detail_content:  VBoxContainer = %DetailContent

const STRIPE_A := Color(0.18, 0.18, 0.22)
const STRIPE_B := Color(0.11, 0.11, 0.13)

var _parser  := SceneParser.new()
var _scenes:   Dictionary = {}
var _selected_scene_id: String = ""

var _cached_flags:      Array            = []
var _cached_vars:       Array            = []
var _cached_scene_ids:  Array            = []
var _dialogue_files:    PackedStringArray = PackedStringArray()
var _contacts_win:  Window = null
var _settings_win:  Window = null
var _flags_win:     Window = null
var _analysis_win:  Window = null
var _analysis_btn:  Button = null

var _saved_positions: Dictionary = {}
var _pos_save_timer:  Timer      = null

var undo_redo_manager: EditorUndoRedoManager = null
var _in_mutation:       bool       = false
var _current_snapshot:  Dictionary = {}
var _current_label:     String     = ""
var _fit_on_next_refresh: bool = false
var _detached_win:      Window   = null
var _detached_refresh:  Callable = Callable()
var _detail_panel:      SceneDetailPanel = null


# ---------------------------------------------------------------------------
# Undo / Redo
# ---------------------------------------------------------------------------

func _begin_mutation(label: String) -> void:
	_current_snapshot = {}
	_current_label    = label
	_in_mutation      = true


func _end_mutation() -> void:
	_in_mutation = false
	if _current_snapshot.is_empty() or undo_redo_manager == null:
		_current_snapshot = {}
		_current_label    = ""
		return
	var before: Dictionary = _current_snapshot.duplicate()
	var after:  Dictionary = {}
	for path: String in before:
		var rf := FileAccess.open(path, FileAccess.READ)
		if rf != null:
			after[path] = rf.get_as_text()
			rf.close()
		else:
			after[path] = ""
	undo_redo_manager.create_action(_current_label, UndoRedo.MERGE_DISABLE)
	undo_redo_manager.add_do_method(self, "_restore_snapshot", after)
	undo_redo_manager.add_undo_method(self, "_restore_snapshot", before)
	undo_redo_manager.commit_action(false)
	_current_snapshot = {}
	_current_label    = ""
	files_written.emit()


func _snapshot_file(path: String) -> void:
	if _in_mutation and not _current_snapshot.has(path):
		var rf := FileAccess.open(path, FileAccess.READ)
		if rf != null:
			_current_snapshot[path] = rf.get_as_text()
			rf.close()
		else:
			_current_snapshot[path] = ""


func _restore_snapshot(files: Dictionary) -> void:
	for path: String in files:
		var content: String = files[path]
		if content.is_empty():
			continue
		var validation := SafeFile.Validation.JSON_DICTIONARY if path.ends_with(".json") else SafeFile.Validation.NONE
		var result := SafeFile.write_text(path, content, validation)
		if not result.get("ok", false):
			push_error("Story Editor undo/redo: " + result.get("error", "Write failed."))
	files_written.emit()
	_on_refresh_pressed()
	if not _selected_scene_id.is_empty():
		_detail_panel.populate(_selected_scene_id)
	if _contacts_win != null and is_instance_valid(_contacts_win):
		(_contacts_win.get_node("ContactsPanel") as Control).call("refresh")
	if _settings_win != null and is_instance_valid(_settings_win):
		(_settings_win.get_node("StorySettingsPanel") as Control).call("refresh")
	if _flags_win != null and is_instance_valid(_flags_win):
		var fp: Control = _flags_win.get_node("FlagsPanel")
		fp.set("scenes", _scenes)
		fp.call("refresh")


# ---------------------------------------------------------------------------
# Returns the inner VBoxContainer so callers add children directly without knowing about the PanelContainer wrapper.
func _make_stripe(index: int) -> VBoxContainer:
	var stripe := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = STRIPE_A if index % 2 == 0 else STRIPE_B
	style.set_content_margin_all(6)
	stripe.add_theme_stylebox_override("panel", style)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	stripe.add_child(inner)
	_detail_content.add_child(stripe)
	return inner


func _ready() -> void:
	_refresh_button.pressed.connect(func() -> void:
		_fit_on_next_refresh = true
		_on_refresh_pressed())
	_reformat_button.pressed.connect(_on_reformat_pressed)
	_contacts_button.pressed.connect(_on_contacts_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_undo_button.pressed.connect(_on_undo_pressed)
	_redo_button.pressed.connect(_on_redo_pressed)
	_reformat_button.text         = _t("Reformater…", "Reformat…")
	_reformat_button.tooltip_text = _t(
		"Choisir précisément les fichiers JSON à reformater.",
		"Choose exactly which JSON files to reformat.")
	_settings_button.text         = _t("Paramètres", "Settings")
	_undo_button.tooltip_text     = _t("Annuler  Ctrl+Z", "Undo  Ctrl+Z")
	_redo_button.tooltip_text     = _t("Rétablir  Ctrl+Y", "Redo  Ctrl+Y")
	_graph.node_selected.connect(_on_node_selected)
	_graph.gui_input.connect(_on_graph_gui_input)
	_graph.connection_request.connect(_on_connection_request)
	_graph.disconnection_request.connect(_on_disconnection_request)
	_graph.delete_nodes_request.connect(_on_delete_nodes_request)
	var flags_btn := Button.new()
	flags_btn.text = "🚩 " + _t("Flags", "Flags")
	flags_btn.tooltip_text = _t(
		"Liste tous les flags du projet avec les scènes qui les définissent ou les utilisent.",
		"Lists all project flags with the scenes that set or use them.")
	flags_btn.pressed.connect(_on_flags_pressed)
	_refresh_button.get_parent().add_child(flags_btn)

	_analysis_btn = Button.new()
	_analysis_btn.text = "📊 " + _t("Analyser", "Analyse")
	_analysis_btn.tooltip_text = _t(
		"Analyse le récit : accessibilité, flags inutilisés, boucles, personnages, durée indicative.",
		"Analyses the narrative: accessibility, unused flags, loops, characters, indicative duration.")
	_analysis_btn.pressed.connect(_on_analysis_pressed)
	_refresh_button.get_parent().add_child(_analysis_btn)

	var detach_btn := Button.new()
	detach_btn.text = "🗗"
	detach_btn.tooltip_text = _t(
		"Ouvrir dans une fenêtre séparée.\nLa fenêtre peut être mise en plein écran.",
		"Open in a separate window.\nThe window can be maximized.")
	detach_btn.pressed.connect(_on_detach_pressed)
	_refresh_button.get_parent().add_child(detach_btn)

	_locale_option = OptionButton.new()
	var detected: Array[String] = SceneParser.detect_locales()
	for loc: String in detected:
		_locale_option.add_item(loc)
	_locale_option.tooltip_text = _t("Langue d'édition du dialogue", "Dialogue editing language")
	_locale_option.item_selected.connect(func(idx: int) -> void:
		var loc: String = _locale_option.get_item_text(idx)
		_parser.locale_override = loc
		_ui_locale = loc
		_analysis_btn.text    = "📊 " + _t("Analyser", "Analyse")
		_reformat_button.text = _t("Reformater…", "Reformat…")
		_settings_button.text = _t("Paramètres", "Settings")
		_undo_button.tooltip_text = _t("Annuler  Ctrl+Z", "Undo  Ctrl+Z")
		_redo_button.tooltip_text = _t("Rétablir  Ctrl+Y", "Redo  Ctrl+Y")
		_on_refresh_pressed()
		if not _selected_scene_id.is_empty():
			_detail_panel.populate(_selected_scene_id)
	)
	_refresh_button.get_parent().add_child(_locale_option)

	_contact_filter = OptionButton.new()
	_contact_filter.tooltip_text = _t(
		"Filtre le graphe par contact — les autres scènes sont grisées.",
		"Filters the graph by contact — other scenes are dimmed.")
	_contact_filter.item_selected.connect(func(_idx: int) -> void: _apply_contact_filter())
	_refresh_button.get_parent().add_child(_contact_filter)

	_search_field = LineEdit.new()
	_search_field.placeholder_text = _t("Chercher ID ou texte…", "Find by ID or text…")
	_search_field.custom_minimum_size = Vector2(180, 0)
	_search_field.clear_button_enabled = true
	_search_field.tooltip_text = _t(
		"Entrée : cherche dans les IDs et le texte des messages/choix.\n← → : naviguer entre les résultats.\nEsc : efface le champ.",
		"Enter: searches scene IDs and message/choice text.\n← →: navigate between results.\nEsc: clears the field.")
	_search_field.text_submitted.connect(_on_search_submitted)
	_search_field.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventKey and (event as InputEventKey).keycode == KEY_ESCAPE:
			_search_field.text = ""
			_search_results = []
			_search_prev_btn.visible = false
			_search_next_btn.visible = false
			_status_label.text = ""
			_search_field.release_focus())
	# ← → : navigate between results when multiple results exist
	_search_field.gui_input.connect(func(event: InputEvent) -> void:
		if not (event is InputEventKey) or not (event as InputEventKey).pressed:
			return
		if _search_results.size() <= 1:
			return
		var ke := event as InputEventKey
		if ke.keycode == KEY_LEFT and not ke.ctrl_pressed:
			_navigate_search(-1)
			_search_field.get_viewport().set_input_as_handled()
		elif ke.keycode == KEY_RIGHT and not ke.ctrl_pressed:
			_navigate_search(1)
			_search_field.get_viewport().set_input_as_handled())
	_refresh_button.get_parent().add_child(_search_field)

	_search_prev_btn = Button.new()
	_search_prev_btn.text = "←"
	_search_prev_btn.flat = true
	_search_prev_btn.custom_minimum_size = Vector2(28, 0)
	_search_prev_btn.tooltip_text = _t("Résultat précédent", "Previous result")
	_search_prev_btn.visible = false
	_search_prev_btn.pressed.connect(func() -> void: _navigate_search(-1))
	_refresh_button.get_parent().add_child(_search_prev_btn)

	_search_next_btn = Button.new()
	_search_next_btn.text = "→"
	_search_next_btn.flat = true
	_search_next_btn.custom_minimum_size = Vector2(28, 0)
	_search_next_btn.tooltip_text = _t("Résultat suivant", "Next result")
	_search_next_btn.visible = false
	_search_next_btn.pressed.connect(func() -> void: _navigate_search(1))
	_refresh_button.get_parent().add_child(_search_next_btn)

	_detail_panel = SceneDetailPanel.new()
	_detail_panel.detail_content  = _detail_content
	_detail_panel.get_scenes       = func() -> Dictionary: return _scenes
	_detail_panel.get_flags        = func() -> Array: return _cached_flags
	_detail_panel.get_vars         = func() -> Array: return _cached_vars
	_detail_panel.get_scene_ids    = func() -> Array: return _cached_scene_ids
	_detail_panel.get_contacts     = func() -> Array: return _parser.contacts
	_detail_panel.get_dial_files   = func() -> PackedStringArray: return _dialogue_files
	_detail_panel.patch_field      = func(sid: String, setter: Callable, lbl: String = "") -> void: _patch_field(sid, setter, lbl)
	_detail_panel.get_main_contact = func() -> String: return _get_main_contact_id()
	_detail_panel.refresh_graph    = func() -> void: _on_refresh_pressed()
	_detail_panel.make_stripe      = func(i: int) -> VBoxContainer: return _make_stripe(i)
	_detail_panel.translate        = func(fr: String, en: String) -> String: return _t(fr, en)
	_detail_panel.add_popup        = func(n: Node) -> void: add_child(n)

	_graph.minimap_enabled = true
	_graph.minimap_size    = Vector2(200, 150)

	_load_saved_positions()

	_pos_save_timer = Timer.new()
	_pos_save_timer.one_shot    = true
	_pos_save_timer.wait_time   = 1.0
	_pos_save_timer.timeout.connect(_save_positions_now)
	add_child(_pos_save_timer)

	_fit_on_next_refresh = true
	_on_refresh_pressed()


func _on_contacts_pressed() -> void:
	if _contacts_win != null and is_instance_valid(_contacts_win):
		_contacts_win.show()
		var existing_contacts: Control = _contacts_win.get_node("ContactsPanel")
		existing_contacts.set("ui_locale", _ui_locale)
		existing_contacts.call("refresh")
		return
	_contacts_win = Window.new()
	_contacts_win.title = _t("Configuration des contacts", "Contact configuration")
	_contacts_win.size = Vector2i(868, 750)
	_contacts_win.min_size = Vector2i(868, 400)
	_contacts_win.max_size = Vector2i(868, 0)
	_contacts_win.wrap_controls = true
	_contacts_win.close_requested.connect(func() -> void: _contacts_win.hide())
	var panel := preload("res://addons/story_editor/ContactsPanel.gd").new()
	panel.name = "ContactsPanel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.get_scene_ids   = func() -> Array: return _scenes.keys()
	panel.begin_mutation  = func(label: String) -> void: _begin_mutation(label)
	panel.end_mutation    = func() -> void: _end_mutation()
	panel.snapshot_file   = func(path: String) -> void: _snapshot_file(path)
	panel.ui_locale       = _ui_locale
	panel.story_modified.connect(_on_refresh_pressed)
	panel.rename_contact_requested.connect(_rename_contact_in_dialogues)
	panel.error_occurred.connect(func(msg: String) -> void: _status_label.text = msg)
	_contacts_win.add_child(panel)
	get_tree().get_root().add_child(_contacts_win)
	_contacts_win.popup_centered()


func _on_settings_pressed() -> void:
	if _settings_win != null and is_instance_valid(_settings_win):
		_settings_win.show()
		var existing_settings: Control = _settings_win.get_node("StorySettingsPanel")
		existing_settings.set("ui_locale", _ui_locale)
		existing_settings.call("refresh")
		return
	_settings_win = Window.new()
	_settings_win.title = _t("Paramètres du projet", "Project settings")
	_settings_win.size = Vector2i(600, 700)
	_settings_win.min_size = Vector2i(500, 400)
	_settings_win.max_size = Vector2i(700, 0)
	_settings_win.wrap_controls = true
	_settings_win.close_requested.connect(func() -> void: _settings_win.hide())
	var panel := preload("res://addons/story_editor/StorySettingsPanel.gd").new()
	panel.name = "StorySettingsPanel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.get_scene_ids  = func() -> Array: return _scenes.keys()
	panel.begin_mutation = func(label: String) -> void: _begin_mutation(label)
	panel.end_mutation   = func() -> void: _end_mutation()
	panel.snapshot_file  = func(path: String) -> void: _snapshot_file(path)
	panel.ui_locale      = _ui_locale
	panel.story_modified.connect(_on_refresh_pressed)
	panel.error_occurred.connect(func(msg: String) -> void: _status_label.text = msg)
	_settings_win.add_child(panel)
	get_tree().get_root().add_child(_settings_win)
	_settings_win.popup_centered()


func _on_flags_pressed() -> void:
	if _flags_win != null and is_instance_valid(_flags_win):
		var panel: Control = _flags_win.get_node("FlagsPanel")
		panel.set("scenes",    _scenes)
		panel.set("ui_locale", _ui_locale)
		panel.call("refresh")
		_flags_win.show()
		return
	_flags_win = Window.new()
	_flags_win.title = _t("Flags du projet", "Project flags")
	_flags_win.size     = Vector2i(640, 600)
	_flags_win.min_size = Vector2i(480, 300)
	_flags_win.wrap_controls = true
	_flags_win.close_requested.connect(func() -> void: _flags_win.hide())
	var panel := preload("res://addons/story_editor/FlagsPanel.gd").new()
	panel.name        = "FlagsPanel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.scenes      = _scenes
	panel.ui_locale   = _ui_locale
	panel.focus_scene = func(sid: String) -> void: _focus_scene(sid)
	_flags_win.add_child(panel)
	get_tree().get_root().add_child(_flags_win)
	_flags_win.popup_centered()
	panel.call("refresh")


func _on_analysis_pressed() -> void:
	if _analysis_win != null and is_instance_valid(_analysis_win):
		var existing: Control = _analysis_win.get_node("AnalysisPanel")
		existing.set("scenes",      _scenes)
		existing.set("start_scene", _parser.start_scene)
		existing.set("ui_locale",   _ui_locale)
		existing.call("refresh")
		_analysis_win.show()
		return
	_analysis_win = Window.new()
	_analysis_win.title = _t("Analyse du récit", "Narrative analysis")
	_analysis_win.size     = Vector2i(580, 700)
	_analysis_win.min_size = Vector2i(420, 300)
	_analysis_win.wrap_controls = true
	_analysis_win.close_requested.connect(func() -> void: _analysis_win.hide())
	var panel_a := preload("res://addons/story_editor/AnalysisPanel.gd").new()
	panel_a.name        = "AnalysisPanel"
	panel_a.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel_a.scenes      = _scenes
	panel_a.start_scene = _parser.start_scene
	panel_a.ui_locale   = _ui_locale
	panel_a.focus_scene = func(sid: String) -> void: _focus_scene(sid)
	_analysis_win.add_child(panel_a)
	get_tree().get_root().add_child(_analysis_win)
	_analysis_win.popup_centered()
	panel_a.call("refresh")


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey):
		return
	var ke := event as InputEventKey
	if not ke.pressed:
		return

	# Ctrl+F — focus search (always, even when a text field is active)
	if ke.ctrl_pressed and not ke.shift_pressed and not ke.alt_pressed and ke.keycode == KEY_F:
		_search_field.grab_focus()
		_search_field.select_all()
		get_viewport().set_input_as_handled()
		return

	# Remaining shortcuts are suppressed when a text field has focus
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit:
		return

	# F — fit / recentrer la vue
	if not ke.ctrl_pressed and not ke.shift_pressed and not ke.alt_pressed and ke.keycode == KEY_F:
		_fit_graph_view()
		get_viewport().set_input_as_handled()
		return

	if _selected_scene_id.is_empty():
		return

	# Suppr — supprimer la scène sélectionnée
	if not ke.ctrl_pressed and not ke.shift_pressed and ke.keycode == KEY_DELETE:
		_on_delete_nodes_request([StringName(_selected_scene_id)])
		get_viewport().set_input_as_handled()
		return

	# Ctrl+D — dupliquer la scène sélectionnée
	if ke.ctrl_pressed and not ke.shift_pressed and not ke.alt_pressed and ke.keycode == KEY_D:
		_duplicate_scene(_selected_scene_id)
		get_viewport().set_input_as_handled()


func _fit_graph_view() -> void:
	var positions: Dictionary = {}
	for child in _graph.get_children():
		if child is GraphNode:
			positions[child.name] = (child as GraphNode).position_offset
	_fit_on_next_refresh = true
	_fit_view(positions)


func _load_saved_positions() -> void:
	var parsed := _read_json_document(POSITIONS_PATH)
	if not parsed.is_empty():
		_saved_positions = parsed


func _save_positions_now() -> void:
	var data: Dictionary = {}
	for child in _graph.get_children():
		if child is GraphNode:
			var gn := child as GraphNode
			var pos: Vector2 = gn.position_offset
			data[gn.name] = [pos.x, pos.y]
	_saved_positions = data
	var result := SafeFile.write_json(POSITIONS_PATH, data, "\t", true)
	if not result.get("ok", false):
		push_error("Story Editor positions: " + result.get("error", "Write failed."))


func _on_undo_pressed() -> void:
	if undo_redo_manager != null:
		undo_redo_manager.get_history_undo_redo(EditorUndoRedoManager.GLOBAL_HISTORY).undo()


func _on_redo_pressed() -> void:
	if undo_redo_manager != null:
		undo_redo_manager.get_history_undo_redo(EditorUndoRedoManager.GLOBAL_HISTORY).redo()


func _all_dialogue_json_files() -> Array[String]:
	var result: Array[String] = []
	for f: String in DirAccess.get_files_at("res://dialogues/"):
		if f.ends_with(".json"):
			result.append(f)
	result.sort()
	return result


func _rename_contact_in_dialogues(old_id: String, new_id: String) -> void:
	_begin_mutation(_t("Renommer contact %s → %s" % [old_id, new_id], "Rename contact %s → %s" % [old_id, new_id]))
	for fname: String in _all_dialogue_json_files():
		var path: String = "res://dialogues/" + fname
		var data := _read_json_document(path)
		if not data.has("scenes"):
			continue
		var modified := false
		for scene in (data["scenes"] as Array):
			if scene.get("contact_id", "") == old_id:
				scene["contact_id"] = new_id
				modified = true
		if modified:
			_write_json(path, data)
	_end_mutation()


func _on_detach_pressed() -> void:
	if _detached_win != null and is_instance_valid(_detached_win):
		_detached_win.show()
		return
	_detached_win = Window.new()
	_detached_win.title = "Story Editor"
	_detached_win.size = Vector2i(1400, 900)
	_detached_win.wrap_controls = true
	_detached_win.close_requested.connect(func() -> void:
		if _detached_refresh.is_valid() and files_written.is_connected(_detached_refresh):
			files_written.disconnect(_detached_refresh)
		_detached_refresh = Callable()
		_detached_win.queue_free()
		_detached_win = null
	)
	var new_panel: Node = preload("res://addons/story_editor/StoryEditorPanel.tscn").instantiate()
	new_panel.set("undo_redo_manager", undo_redo_manager)
	_detached_win.add_child(new_panel)
	get_tree().get_root().add_child(_detached_win)
	_detached_win.popup_centered()
	new_panel.set("_fit_on_next_refresh", true)
	new_panel.call("_on_refresh_pressed")
	new_panel.connect("files_written", func() -> void: _on_refresh_pressed())
	_detached_refresh = func() -> void: new_panel.call("_on_refresh_pressed")
	files_written.connect(_detached_refresh)


func _on_reformat_pressed() -> void:
	if _parser.chosen_files.is_empty():
		_status_label.text = _t("Cliquez d'abord sur Refresh", "Click Refresh first")
		return
	var active_locale := _parser.locale_override
	if active_locale.is_empty():
		active_locale = _parser._read_locale()
	var entries := _build_reformat_entries(
		_all_dialogue_json_files(),
		_parser.chosen_files,
		active_locale,
		SceneParser._read_base_locale()
	)
	_show_reformat_dialog(entries, active_locale)


func _build_reformat_entries(
		all_files: Array[String],
		chosen_files: Dictionary,
		active_locale: String,
		base_locale: String
	) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var chosen_names: Array = chosen_files.values()
	for file_name: String in all_files:
		var basename := file_name.get_basename()
		var parts := basename.split(".")
		var locale := str(parts[1]) if parts.size() == 2 else base_locale
		var selected := file_name in chosen_names
		var is_fallback := selected and parts.size() == 1 and active_locale != base_locale
		var role := _t("Langue %s" % locale, "Language %s" % locale)
		var detail := role
		if parts.size() == 1:
			role = _t("Défaut %s" % base_locale, "Default %s" % base_locale)
			detail = _t("Fichier de la langue par défaut", "Default-language file")
		if is_fallback:
			role = _t("Fallback %s" % active_locale, "Fallback %s" % active_locale)
			detail = _t(
				"Fallback — aucun %s.%s.json" % [basename, active_locale],
				"Fallback — no %s.%s.json" % [basename, active_locale]
			)
		entries.append({
			"file_name": file_name,
			"selected": selected,
			"fallback": is_fallback,
			"locale": locale,
			"role": role,
			"detail": detail,
		})
	return entries


func _show_reformat_dialog(entries: Array[Dictionary], active_locale: String) -> void:
	var metrics := _reformat_dialog_metrics(entries.size(), get_viewport_rect().size)
	var dialog := ConfirmationDialog.new()
	dialog.title = _t("Reformater les fichiers JSON", "Reformat JSON files")
	dialog.min_size = metrics["min_size"]
	dialog.max_size = metrics["popup_size"]
	dialog.unresizable = true
	add_child(dialog)
	# Native dialog buttons can end up outside the visible custom layout in the
	# editor dock. Actions live inside our content so they are always reachable.
	dialog.get_ok_button().hide()
	dialog.get_cancel_button().hide()

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	dialog.add_child(content)

	var description := Label.new()
	description.text = _t(
		"Langue active : %s\nSélectionnez les fichiers à reformater." % active_locale,
		"Active language: %s\nSelect the files to reformat." % active_locale
	)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(description)

	var selection_buttons := HBoxContainer.new()
	var select_current := Button.new()
	select_current.text = _t("Langue active", "Active language")
	selection_buttons.add_child(select_current)
	var select_all := Button.new()
	select_all.text = _t("Tous les fichiers", "All files")
	selection_buttons.add_child(select_all)
	content.add_child(selection_buttons)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, metrics["list_height"])
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var files_box := VBoxContainer.new()
	files_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	files_box.add_theme_constant_override("separation", 5)
	scroll.add_child(files_box)

	var checkboxes: Dictionary = {}
	for entry: Dictionary in entries:
		var file_name: String = entry["file_name"]
		var checkbox := CheckBox.new()
		checkbox.text = "%s  —  %s" % [file_name, entry["role"]]
		checkbox.button_pressed = entry["selected"]
		checkbox.clip_text = true
		checkbox.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		checkbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		checkbox.tooltip_text = "res://dialogues/%s\n%s" % [file_name, entry.get("detail", entry["role"])]
		if entry["fallback"]:
			checkbox.add_theme_color_override("font_color", Color(1.0, 0.68, 0.25))
		files_box.add_child(checkbox)
		checkboxes[file_name] = checkbox

	var safety_note := Label.new()
	safety_note.text = _t(
		"Seuls l'indentation et l'ordre des clés changent. Une copie de récupération est conservée.",
		"Only indentation and key order change. A recovery copy is kept."
	)
	safety_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	safety_note.add_theme_color_override("font_color", Color(0.65, 0.72, 0.76))
	content.add_child(safety_note)

	var separator := HSeparator.new()
	content.add_child(separator)
	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_END
	action_row.add_theme_constant_override("separation", 8)
	var cancel_button := Button.new()
	cancel_button.name = "CancelReformatButton"
	cancel_button.text = _t("Annuler", "Cancel")
	cancel_button.custom_minimum_size = Vector2(100, 36)
	action_row.add_child(cancel_button)
	var confirm_button := Button.new()
	confirm_button.name = "ConfirmReformatButton"
	confirm_button.custom_minimum_size = Vector2(190, 36)
	action_row.add_child(confirm_button)
	content.add_child(action_row)

	var update_confirmation: Callable = func() -> void:
		var count := 0
		for checkbox: CheckBox in checkboxes.values():
			if checkbox.button_pressed:
				count += 1
		confirm_button.disabled = count == 0
		confirm_button.text = _t(
			"Reformater %d fichier%s" % [count, "" if count == 1 else "s"],
			"Reformat %d file%s" % [count, "" if count == 1 else "s"]
		)

	for checkbox: CheckBox in checkboxes.values():
		checkbox.toggled.connect(func(_pressed: bool) -> void: update_confirmation.call())
	select_current.pressed.connect(func() -> void:
		for entry: Dictionary in entries:
			(checkboxes[entry["file_name"]] as CheckBox).button_pressed = entry["selected"]
		update_confirmation.call()
	)
	select_all.pressed.connect(func() -> void:
		for checkbox: CheckBox in checkboxes.values():
			checkbox.button_pressed = true
		update_confirmation.call()
	)
	var submit: Callable = func() -> void:
		var selected_files: Array[String] = []
		for file_name: String in checkboxes:
			if (checkboxes[file_name] as CheckBox).button_pressed:
				selected_files.append(file_name)
		selected_files.sort()
		dialog.queue_free()
		_reformat_files(selected_files)
	confirm_button.pressed.connect(submit)
	dialog.confirmed.connect(submit)
	cancel_button.pressed.connect(func() -> void: dialog.queue_free())
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	update_confirmation.call()
	dialog.popup_centered(metrics["popup_size"])


func _reformat_dialog_metrics(file_count: int, viewport_size: Vector2) -> Dictionary:
	var list_height := clampi(file_count * 32 + 8, 96, 220)
	var max_width := maxi(360, int(viewport_size.x * 0.85))
	var max_height := maxi(320, int(viewport_size.y * 0.82))
	var popup_size := Vector2i(
		mini(560, max_width),
		mini(300 + list_height, max_height)
	)
	return {
		"list_height": list_height,
		"popup_size": popup_size,
		"min_size": Vector2i(mini(420, popup_size.x), mini(320, popup_size.y)),
	}


func _reformat_files(file_names: Array[String]) -> void:
	if file_names.is_empty():
		return
	_begin_mutation(_t("Reformater %d fichier(s)" % file_names.size(), "Reformat %d file(s)" % file_names.size()))
	var reformatted: Array[String] = []
	var failed: Array[String] = []
	for file_name: String in file_names:
		var path: String = "res://dialogues/" + file_name
		var data := _read_json_document(path)
		if data.has("scenes") and _write_json(path, data):
			reformatted.append(file_name)
		else:
			failed.append(file_name)
	await _on_refresh_pressed()
	_end_mutation()
	if failed.is_empty():
		_status_label.text = _t(
			"%d fichier(s) reformaté(s)" % reformatted.size(),
			"%d file(s) reformatted" % reformatted.size()
		)
	else:
		_status_label.text = _t(
			"Échec du reformatage : %s" % ", ".join(failed),
			"Reformat failed: %s" % ", ".join(failed)
		)
	_status_label.tooltip_text = _t(
		"Reformatés : %s" % ", ".join(reformatted),
		"Reformatted: %s" % ", ".join(reformatted)
	)


func _on_refresh_pressed() -> void:
	_scenes = _parser.parse_all()
	if _parser.error_message != "":
		_status_label.text = _t("Erreur : ", "Error: ") + _parser.error_message
		return
	_status_label.text = _t("%d scènes chargées" % _scenes.size(), "%d scenes loaded" % _scenes.size())
	_cached_flags    = _collect_flags()
	_cached_vars     = _collect_vars()
	_cached_scene_ids = _scenes.keys()
	_cached_scene_ids.sort()
	_dialogue_files  = DirAccess.get_files_at("res://dialogues/")
	await _rebuild_graph(_scenes)


# Only GraphNode children are freed — GraphEdit has an internal connection_layer node that must not be touched.
func _rebuild_graph(scenes: Dictionary) -> void:
	# Ne supprimer que les GraphNode — le connection_layer de GraphEdit doit rester intact
	for child in _graph.get_children():
		if child is GraphNode:
			child.free()
	_graph.clear_connections()

	var outgoing := _build_outgoing(scenes)
	var bfs_positions := _compute_layout(scenes, outgoing)

	# Merge BFS layout with saved positions (saved wins when available)
	var positions: Dictionary = {}
	for sid: String in scenes:
		var saved: Variant = _saved_positions.get(sid, null)
		if saved is Array and (saved as Array).size() >= 2:
			positions[sid] = Vector2(float((saved as Array)[0]), float((saved as Array)[1]))
		else:
			positions[sid] = bfs_positions.get(sid, Vector2.ZERO)

	# Scènes qui ont au moins une connexion entrante
	var has_incoming: Dictionary = {}
	for sid in outgoing:
		for conn in outgoing[sid]:
			if scenes.has(conn.target):
				has_incoming[conn.target] = true

	for scene_id in scenes:
		var scene: Dictionary = scenes[scene_id]
		var is_start:    bool = scene_id == _parser.start_scene
		var is_dead_end: bool = outgoing.get(scene_id, []).is_empty() and not scene.has("free_input")
		var is_isolated: bool = not is_start and not has_incoming.has(scene_id)
		var node := _create_graph_node(scene_id, scene, outgoing.get(scene_id, []),
				is_start, is_dead_end, is_isolated)
		_graph.add_child(node)
		_apply_contact_color(node, str(scene.get("contact_id", "")))
		node.position_offset = positions.get(scene_id, Vector2.ZERO)
		# Connect after setting initial position so the initial placement doesn't trigger a save
		node.position_offset_changed.connect(func() -> void:
			if _pos_save_timer != null:
				_pos_save_timer.start())

	for scene_id in outgoing:
		var conns: Array = outgoing[scene_id]
		for port_idx in range(conns.size()):
			var conn = conns[port_idx]
			if scenes.has(conn.target):
				_graph.connect_node(scene_id, port_idx, conn.target, 0)

	await get_tree().process_frame
	_fit_view(positions)
	_refresh_contact_filter()
	_apply_contact_filter()


# ---------------------------------------------------------------------------
# Connexions sortantes

# Trigger and resume_after_flag edges don't live in the source scene's JSON — they're reverse-looked-up
# from the target and stored here as virtual outgoing connections so the graph can draw them.
func _build_outgoing(scenes: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for scene_id in scenes:
		result[scene_id] = []

	for scene_id in scenes:
		var scene = scenes[scene_id]

		var next = scene.get("next", null)
		if next != null:
			var next_label := "→ next"
			if scene.has("free_input"):
				next_label = "→ après saisie"
			result[scene_id].append({type = "next", target = str(next), label = next_label})

		var choices: Array = scene.get("choices", [])
		for i in range(choices.size()):
			var choice = choices[i]
			var cnext = choice.get("next", null)
			var label: String = str(choice.get("text", "…"))
			var flag: String = str(choice.get("flag", ""))
			if flag != "":
				label += "  [%s]" % flag
			var req = choice.get("requires_flag", choice.get("condition", null))
			if req != null:
				label += "  ?"
			result[scene_id].append({
				type = "choice",
				target = str(cnext) if cnext != null else "",
				label = label,
				choice_index = i
			})

	for scene_id in scenes:
		var trigger_src = scenes[scene_id].get("trigger_after_scene", null)
		if trigger_src == null:
			continue
		var src := str(trigger_src)
		if not result.has(src):
			result[src] = []
		result[src].append({type = "trigger", target = scene_id, label = "⚡ depuis: %s" % scene_id})

	var flag_setters: Dictionary = {}
	for scene_id in scenes:
		for choice in scenes[scene_id].get("choices", []):
			var flag = choice.get("flag", null)
			if flag != null and not flag_setters.has(str(flag)):
				flag_setters[str(flag)] = scene_id

	for scene_id in scenes:
		var resume_flag = scenes[scene_id].get("resume_after_flag", null)
		if resume_flag == null:
			continue
		var setter: String = flag_setters.get(str(resume_flag), "")
		if setter != "":
			result[setter].append({type = "resume", target = scene_id, label = "⏱ " + str(resume_flag)})

	return result


# ---------------------------------------------------------------------------
# Layout

func _compute_layout(scenes: Dictionary, outgoing: Dictionary) -> Dictionary:
	var positions: Dictionary = {}
	if scenes.is_empty():
		return positions

	var start := _parser.start_scene
	if start.is_empty() or not scenes.has(start):
		start = scenes.keys()[0]

	var col_of: Dictionary = {}
	var queue: Array = [start]
	col_of[start] = 0
	while queue.size() > 0:
		var current: String = queue.pop_front()
		for conn in outgoing.get(current, []):
			var target: String = conn.target
			if scenes.has(target) and not col_of.has(target):
				col_of[target] = col_of[current] + 1
				queue.append(target)

	for scene_id in scenes:
		if not col_of.has(scene_id):
			col_of[scene_id] = -1

	var row_count: Dictionary = {}
	for scene_id in scenes:
		var col: int = col_of[scene_id]
		if not row_count.has(col):
			row_count[col] = 0
		positions[scene_id] = Vector2(col * H_SPACING, row_count[col] * V_SPACING)
		row_count[col] += 1

	return positions


func _fit_view(positions: Dictionary) -> void:
	if not _fit_on_next_refresh:
		return
	_fit_on_next_refresh = false
	if positions.is_empty() or _graph.size.x < 10:
		return
	var max_x := 0.0
	var max_y := 0.0
	for pos: Vector2 in positions.values():
		max_x = maxf(max_x, pos.x + 260.0)
		max_y = maxf(max_y, pos.y + 220.0)
	var new_zoom := clampf(
		minf(_graph.size.x / (max_x + 60.0), _graph.size.y / (max_y + 60.0)),
		_graph.zoom_min, _graph.zoom_max
	)
	_graph.zoom = new_zoom
	_graph.scroll_offset = Vector2.ZERO


# ---------------------------------------------------------------------------
# Nœuds du graphe — helpers visuels

func _contact_color(contact_id: String) -> Color:
	if contact_id.is_empty():
		return Color(0.18, 0.20, 0.26)
	var h: float = float(contact_id.hash() & 0x7FFFFFFF) / float(0x7FFFFFFF)
	return Color.from_hsv(h, 0.55, 0.30)


func _contact_accent(contact_id: String) -> Color:
	if contact_id.is_empty():
		return Color(0.5, 0.8, 1.0)
	var h: float = float(contact_id.hash() & 0x7FFFFFFF) / float(0x7FFFFFFF)
	return Color.from_hsv(h, 0.40, 0.90)


func _apply_contact_color(node: GraphNode, contact_id: String) -> void:
	var base_sb: StyleBox = _graph.get_theme_stylebox("titlebar", "GraphNode")
	var style: StyleBoxFlat
	if base_sb is StyleBoxFlat:
		style = (base_sb as StyleBoxFlat).duplicate()
	else:
		style = StyleBoxFlat.new()
		style.corner_radius_top_left  = 4
		style.corner_radius_top_right = 4
		style.content_margin_left   = 12.0
		style.content_margin_right  = 12.0
		style.content_margin_top    = 6.0
		style.content_margin_bottom = 6.0
	style.bg_color = _contact_color(contact_id)
	node.add_theme_stylebox_override("titlebar", style)


func _first_message_preview(scene: Dictionary) -> String:
	var msgs: Array = scene.get("messages_in", [])
	if msgs.is_empty() or not msgs[0] is Dictionary:
		return ""
	var first: Dictionary = msgs[0]
	var raw: Variant = first.get("text", "")
	var text: String = ""
	if raw is Array:
		var arr: Array = raw
		if not arr.is_empty():
			var el: Variant = arr[0]
			text = str((el as Dictionary).get("text", "")) if el is Dictionary else str(el)
	elif raw is String:
		text = raw
	text = text.strip_edges()
	if text.is_empty():
		return ""
	return text.left(60) + ("…" if text.length() > 60 else "")


func _create_graph_node(scene_id: String, scene: Dictionary, conns: Array,
		is_start: bool = false, is_dead_end: bool = false, is_isolated: bool = false) -> GraphNode:
	var node := GraphNode.new()

	# Titre avec indicateurs
	var title := scene_id
	if is_start:
		title = "▶  " + title
	if scene.has("free_input"):
		title += "  ✎"
	if scene.has("_notes"):
		title += "  📝"
	node.title = title
	node.name  = scene_id
	node.custom_minimum_size = Vector2(220, 0)
	node.gui_input.connect(func(event: InputEvent) -> void:
		if not (event is InputEventMouseButton):
			return
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			node.get_viewport().set_input_as_handled()
			var popup := PopupMenu.new()
			popup.add_item(_t("Supprimer cette scène", "Delete this scene"), 0)
			popup.add_item(_t("Dupliquer cette scène", "Duplicate this scene"), 1)
			var has_connected := false
			for i in range(conns.size()):
				var conn_type: String = str(conns[i].get("type", ""))
				if conns[i].get("target", "") != "" and conn_type != "trigger" and conn_type != "resume":
					if not has_connected:
						popup.add_separator()
						has_connected = true
					var lbl: String = _t("Déconnecter : ", "Disconnect: ") + str(conns[i].label) + " → " + str(conns[i].target)
					popup.add_item(lbl, 100 + i)
			add_child(popup)
			popup.id_pressed.connect(func(id: int) -> void:
				if id == 0:
					_on_delete_nodes_request([StringName(scene_id)])
				elif id == 1:
					_duplicate_scene(scene_id)
				elif id >= 100:
					_write_disconnection_to_file(scene_id, id - 100)
				popup.queue_free())
			popup.popup_on_parent(Rect2(node.global_position + mb.position, Vector2.ZERO)))

	var contact_id: String = str(scene.get("contact_id", ""))
	var slot_idx := 0

	# Aperçu du premier message (pas de port)
	var first_text: String = _first_message_preview(scene)
	if not first_text.is_empty():
		var preview_lbl := Label.new()
		preview_lbl.text = first_text
		preview_lbl.add_theme_font_size_override("font_size", 10)
		preview_lbl.add_theme_color_override("font_color", Color(0.55, 0.58, 0.62))
		preview_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		preview_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		node.add_child(preview_lbl)
		node.set_slot(slot_idx, false, 0, Color.WHITE, false, 0, Color.WHITE)
		slot_idx += 1

	# Contact — port d'entrée
	var contact_label := Label.new()
	contact_label.text = contact_id if not contact_id.is_empty() else "—"
	contact_label.add_theme_color_override("font_color", _contact_accent(contact_id))
	node.add_child(contact_label)
	node.set_slot(slot_idx, true, 0, Color.WHITE, false, 0, Color.WHITE)
	slot_idx += 1

	if conns.is_empty():
		# Port "→ ?" : permet de tirer une connexion depuis une scène sans sortie
		var placeholder := Label.new()
		placeholder.text = "→ ?"
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		placeholder.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		node.add_child(placeholder)
		node.set_slot(slot_idx, false, 0, Color.WHITE, true, 0, COLOR_NORMAL)
		slot_idx += 1
	else:
		for i in range(conns.size()):
			var conn = conns[i]
			var lbl := Label.new()
			lbl.text = conn.label
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			node.add_child(lbl)
			node.set_slot(slot_idx, false, 0, Color.WHITE, true, 0, _port_color(conn.type))
			slot_idx += 1

	# Indicateur de statut (pas de port)
	if is_dead_end or is_isolated:
		var status := Label.new()
		if is_dead_end:
			status.text = _t("⛔ Fin de parcours", "⛔ Dead end")
			status.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		else:
			status.text = _t("⚠ Isolée", "⚠ Isolated")
			status.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		node.add_child(status)
		node.set_slot(slot_idx, false, 0, Color.WHITE, false, 0, Color.WHITE)

	return node


func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, _to_port: int) -> void:
	var from_id := str(from_node)
	var to_id   := str(to_node)
	if from_id == to_id:
		return
	_write_connection_to_file(from_id, from_port, to_id)


func _on_disconnection_request(from_node: StringName, from_port: int, _to_node: StringName, _to_port: int) -> void:
	_write_disconnection_to_file(str(from_node), from_port)


func _on_delete_nodes_request(nodes: Array[StringName]) -> void:
	if nodes.is_empty():
		return
	var ids: Array[String] = []
	for n in nodes:
		ids.append(str(n))
	var label := ", ".join(ids)
	var dialog := ConfirmationDialog.new()
	dialog.title = _t("Supprimer des scènes", "Delete scenes")
	dialog.dialog_text = _t(
		"Supprimer %s ?\nLes liens vers ces scènes seront effacés." % label,
		"Delete %s?\nLinks to these scenes will be removed." % label)
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		dialog.queue_free()
		_delete_scenes(ids))
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	dialog.popup_centered()


func _write_connection_to_file(from_id: String, from_port: int, to_id: String) -> void:
	_begin_mutation(_t("Connecter %s → %s" % [from_id, to_id], "Connect %s → %s" % [from_id, to_id]))
	_mutate_connection(from_id, from_port, func(scene: Dictionary, update_type: String, choice_index: int) -> void:
		if update_type == "next":
			scene["next"] = to_id
		elif update_type == "choice" and choice_index >= 0:
			var choices: Array = scene.get("choices", [])
			if choice_index < choices.size():
				choices[choice_index]["next"] = to_id)
	_end_mutation()


func _write_disconnection_to_file(from_id: String, from_port: int) -> void:
	_begin_mutation(_t("Déconnecter %s" % from_id, "Disconnect %s" % from_id))
	_mutate_connection(from_id, from_port, func(scene: Dictionary, update_type: String, choice_index: int) -> void:
		if update_type == "next":
			scene.erase("next")
		elif update_type == "choice" and choice_index >= 0:
			var choices: Array = scene.get("choices", [])
			if choice_index < choices.size():
				choices[choice_index].erase("next"))
	_end_mutation()


# Shared read-parse-mutate-write cycle for both connecting and disconnecting ports.
# Port index is resolved directly from _scenes: port 0 = next (if any), then choices in order.
func _mutate_connection(from_id: String, from_port: int, mutator: Callable) -> void:
	var from_scene: Dictionary = _scenes.get(from_id, {})
	if from_scene.is_empty():
		return
	var file_name: String = from_scene.get("_editor_file", "")
	if file_name.is_empty():
		_status_label.text = _t("Erreur : fichier source introuvable", "Error: source file not found")
		return
	var update_type := ""
	var choice_index := -1
	var has_real_next: bool = from_scene.has("next")
	var choices: Array = from_scene.get("choices", []) as Array
	if not has_real_next and choices.is_empty():
		update_type = "next"
	elif has_real_next and from_port == 0:
		update_type = "next"
	else:
		var ci: int = from_port - (1 if has_real_next else 0)
		if ci >= 0 and ci < choices.size():
			update_type = "choice"
			choice_index = ci
		else:
			_status_label.text = _t(
				"Connexion en lecture seule (trigger/resume)",
				"Read-only connection (trigger/resume)")
			return
	var path := "res://dialogues/" + file_name
	var data := _read_json_document(path)
	if not data.has("scenes"):
		_status_label.text = _t("Erreur lecture : " + file_name, "Read error: " + file_name)
		return
	for scene in (data["scenes"] as Array):
		if scene.get("id", "") != from_id:
			continue
		mutator.call(scene, update_type, choice_index)
		break
	if not _write_json(path, data):
		_status_label.text = _t("Erreur écriture : " + file_name, "Write error: " + file_name)
		return
	_on_refresh_pressed()


func _delete_scenes(ids: Array[String]) -> void:
	_begin_mutation(_t("Supprimer scène(s) : %s" % ", ".join(ids), "Delete scene(s): %s" % ", ".join(ids)))
	var id_set := {}
	for id in ids:
		id_set[id] = true

	var files_data: Dictionary = {}
	for fname: String in _all_dialogue_json_files():
		var path: String = "res://dialogues/" + fname
		var data := _read_json_document(path)
		if data.has("scenes"):
			files_data[fname] = data

	for file_name in files_data:
		var data: Dictionary = files_data[file_name]
		var new_scenes: Array = []
		var modified := false
		for scene in (data["scenes"] as Array):
			var sid: String = scene.get("id", "")
			if id_set.has(sid):
				modified = true
				continue
			if scene.has("next") and id_set.has(str(scene["next"])):
				scene.erase("next")
				modified = true
			if scene.has("trigger_after_scene") and id_set.has(str(scene["trigger_after_scene"])):
				scene.erase("trigger_after_scene")
				modified = true
			if scene.has("choices"):
				for choice in (scene["choices"] as Array):
					if choice.has("next") and id_set.has(str(choice["next"])):
						choice.erase("next")
						modified = true
			new_scenes.append(scene)
		if modified:
			data["scenes"] = new_scenes
			if not _write_json("res://dialogues/" + file_name, data):
				_status_label.text = _t("Erreur écriture : " + file_name, "Write error: " + file_name)
				_end_mutation()
				return

	_end_mutation()
	_on_refresh_pressed()


func _on_graph_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_show_create_scene_dialog()


func _show_create_scene_dialog() -> void:
	if _parser.chosen_files.is_empty():
		_status_label.text = _t("Cliquez d'abord sur Refresh", "Click Refresh first")
		return

	var dialog := ConfirmationDialog.new()
	dialog.title = _t("Nouvelle scène", "New scene")
	dialog.min_size = Vector2(320, 10)
	add_child(dialog)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	dialog.add_child(vbox)

	# Champ ID
	var id_label := Label.new()
	id_label.text = "ID"
	vbox.add_child(id_label)
	var id_field := LineEdit.new()
	id_field.placeholder_text = _t("ex : scene_10", "e.g. scene_10")
	vbox.add_child(id_field)

	# Liste déroulante contact
	var contact_label := Label.new()
	contact_label.text = _t("Contact", "Contact")
	vbox.add_child(contact_label)
	var contact_option := OptionButton.new()
	var contact_ids: Array = []
	for c in _parser.contacts:
		contact_option.add_item(c.get("id", "?"))
		contact_ids.append(c.get("id", ""))
	vbox.add_child(contact_option)

	# Liste déroulante fichier (seulement si plusieurs fichiers)
	var file_option: OptionButton = null
	var file_names: Array = []
	for fname in _parser.chosen_files.values():
		file_names.append(fname)
	if file_names.size() > 1:
		var file_label := Label.new()
		file_label.text = _t("Fichier", "File")
		vbox.add_child(file_label)
		file_option = OptionButton.new()
		for fname in file_names:
			file_option.add_item(fname)
		vbox.add_child(file_option)

	dialog.popup_centered()
	id_field.grab_focus()

	dialog.confirmed.connect(func() -> void:
		var scene_id: String = id_field.text.strip_edges()
		if scene_id.is_empty():
			_status_label.text = _t("Erreur : ID vide", "Error: empty ID")
			dialog.queue_free()
			return
		if _scenes.has(scene_id):
			_status_label.text = _t(
				"Erreur : ID \"%s\" déjà utilisé" % scene_id,
				"Error: ID \"%s\" already exists" % scene_id)
			dialog.queue_free()
			return
		var contact_id: String = contact_ids[contact_option.selected] if contact_ids.size() > 0 else ""
		var file_name: String = file_names[file_option.selected] if file_option != null else file_names[0]
		dialog.queue_free()
		_write_scene_to_file(scene_id, contact_id, file_name)
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())


func _write_scene_to_file(scene_id: String, contact_id: String, file_name: String) -> void:
	_begin_mutation(_t("Créer scène : %s" % scene_id, "Create scene: %s" % scene_id))
	var path := "res://dialogues/" + file_name
	var data := _read_json_document(path)
	if not data.has("scenes"):
		_status_label.text = _t("JSON invalide dans " + file_name, "Invalid JSON in " + file_name)
		_end_mutation()
		return

	var main_contact_id := ""
	for c in _parser.contacts:
		if c.get("is_main", false):
			main_contact_id = c.get("id", "")
			break

	var new_scene: Dictionary = { "id": scene_id, "messages_in": [{ "text": "" }] }
	if contact_id != main_contact_id:
		new_scene["contact_id"] = contact_id
	data["scenes"].append(new_scene)

	if not _write_json(path, data):
		_status_label.text = _t("Erreur écriture : " + file_name, "Write error: " + file_name)
		_end_mutation()
		return
	_end_mutation()
	_on_refresh_pressed()


func _duplicate_scene(source_id: String) -> void:
	var source: Dictionary = _scenes.get(source_id, {})
	var file_name: String = source.get("_editor_file", "")
	if file_name.is_empty():
		return
	var base_id := source_id + "_copy"
	var new_id := base_id
	var n := 2
	while _scenes.has(new_id):
		new_id = base_id + str(n)
		n += 1
	var path := "res://dialogues/" + file_name
	var data := _read_json_document(path)
	if not data.has("scenes"):
		_status_label.text = _t("Erreur lecture : " + file_name, "Read error: " + file_name)
		return
	_begin_mutation(_t("Dupliquer scène : %s" % source_id, "Duplicate scene: %s" % source_id))
	var new_scene: Dictionary = {}
	for key: String in source:
		if key != "_editor_file":
			new_scene[key] = source[key]
	new_scene["id"] = new_id
	new_scene.erase("next")
	new_scene.erase("trigger_after_scene")
	new_scene.erase("resume_after_flag")
	new_scene.erase("resume_after_delay")
	if new_scene.has("choices"):
		var new_choices: Array = []
		for ch: Dictionary in (new_scene["choices"] as Array):
			var c: Dictionary = ch.duplicate()
			c.erase("next")
			new_choices.append(c)
		new_scene["choices"] = new_choices
	(data["scenes"] as Array).append(new_scene)
	if not _write_json(path, data):
		_status_label.text = _t("Erreur écriture : " + file_name, "Write error: " + file_name)
		_end_mutation()
		return
	_end_mutation()
	_on_refresh_pressed()


# Always re-orders scenes before writing so git diffs stay readable regardless of edit order.
func _write_json(path: String, data: Dictionary) -> bool:
	_snapshot_file(path)
	var ordered_scenes: Array = []
	for s in (data["scenes"] as Array):
		ordered_scenes.append(_ordered_scene(s))
	data["scenes"] = ordered_scenes
	var result := SafeFile.write_text(path, _json_stringify_file(data), SafeFile.Validation.JSON_DICTIONARY)
	if not result.get("ok", false):
		push_error("Story Editor: " + result.get("error", "Write failed."))
	return result.get("ok", false)


func _read_json_document(path: String) -> Dictionary:
	var result := SafeFile.read_json(path)
	if not result.get("ok", false):
		return {}
	if result.get("recovered", false):
		push_warning("Story Editor: recovered %s from %s." % [path, result.get("recovery_source", "backup")])
	return result.get("data", {})


func _json_stringify_file(data: Dictionary) -> String:
	return JsonUtils.expand(data, "") + "\n"


# Enforces a stable key order so unrelated edits don't produce noisy diffs. _editor_file is stripped — it's runtime-only.
func _ordered_scene(scene: Dictionary) -> Dictionary:
	return JsonUtils.ordered_scene(scene)


# ---------------------------------------------------------------------------
# Filtre par contact

# Repeuple le dropdown en conservant la sélection courante si le contact existe encore.
func _refresh_contact_filter() -> void:
	if _contact_filter == null:
		return
	var prev_id: String = ""
	if _contact_filter.selected > 0:
		prev_id = str(_contact_filter.get_item_metadata(_contact_filter.selected))
	_contact_filter.clear()
	_contact_filter.add_item(_t("Tous", "All"))
	_contact_filter.set_item_metadata(0, "")
	for c: Dictionary in _parser.contacts:
		var cid: String  = str(c.get("id",   ""))
		_contact_filter.add_item(cid)
		_contact_filter.set_item_metadata(_contact_filter.item_count - 1, cid)
	# Restaure la sélection précédente si le contact est toujours présent
	if not prev_id.is_empty():
		for i in range(_contact_filter.item_count):
			if str(_contact_filter.get_item_metadata(i)) == prev_id:
				_contact_filter.select(i)
				break


# Règle le modulate de chaque nœud selon le filtre actif.
# Nœuds du contact sélectionné : opacité pleine. Autres : 20 %.
func _apply_contact_filter() -> void:
	if _contact_filter == null:
		return
	var filter_id: String = str(_contact_filter.get_item_metadata(_contact_filter.selected))
	var main_id:   String = _get_main_contact_id()
	for child in _graph.get_children():
		if not (child is GraphNode):
			continue
		var node    := child as GraphNode
		var scene: Dictionary = _scenes.get(str(node.name), {})
		var cid: String = str(scene.get("contact_id", main_id))
		if cid.is_empty():
			cid = main_id
		var match: bool = filter_id.is_empty() or cid == filter_id
		node.modulate = Color.WHITE if match else Color(1.0, 1.0, 1.0, 0.2)


# ---------------------------------------------------------------------------
# Recherche de scène

func _on_search_submitted(query: String) -> void:
	query = query.strip_edges()
	if query.is_empty():
		_search_results = []
		_search_index = 0
		_search_prev_btn.visible = false
		_search_next_btn.visible = false
		return
	_search_results = _search_scenes(query)
	_search_index = 0
	if _search_results.is_empty():
		_status_label.text = _t("Introuvable : " + query, "Not found: " + query)
		_search_prev_btn.visible = false
		_search_next_btn.visible = false
		return
	var show_nav: bool = _search_results.size() > 1
	_search_prev_btn.visible = show_nav
	_search_next_btn.visible = show_nav
	_focus_search_result()


func _navigate_search(delta: int) -> void:
	if _search_results.is_empty():
		return
	_search_index = (_search_index + delta + _search_results.size()) % _search_results.size()
	_focus_search_result()


func _focus_search_result() -> void:
	var scene_id: String = _search_results[_search_index]
	_status_label.text = "%d / %d : %s" % [_search_index + 1, _search_results.size(), scene_id]
	_focus_scene(scene_id)


# IDs first (exact → prefix → substring), then content matches. Results within each group are sorted.
func _search_scenes(query: String) -> Array[String]:
	var q := query.to_lower()
	var exact:     Array[String] = []
	var prefix:    Array[String] = []
	var substring: Array[String] = []
	var content:   Array[String] = []
	for sid: String in _scenes:
		var sl := sid.to_lower()
		if sl == q:
			exact.append(sid)
		elif sl.begins_with(q):
			prefix.append(sid)
		elif q in sl:
			substring.append(sid)
		elif q in _extract_scene_text(_scenes[sid]):
			content.append(sid)
	prefix.sort()
	substring.sort()
	content.sort()
	var result: Array[String] = []
	result.append_array(exact)
	result.append_array(prefix)
	result.append_array(substring)
	result.append_array(content)
	return result


# Extracts all searchable text from a scene into a single lowercase string.
func _extract_scene_text(scene: Dictionary) -> String:
	var parts: Array[String] = []
	for msg: Variant in (scene.get("messages_in", []) as Array):
		var text: Variant = (msg as Dictionary).get("text", "")
		if text is String:
			parts.append(text as String)
		elif text is Array:
			for elem: Variant in (text as Array):
				if elem is String:
					parts.append(elem as String)
				elif elem is Dictionary:
					parts.append(str((elem as Dictionary).get("text", "")))
	for ch: Variant in (scene.get("choices", []) as Array):
		var cd := ch as Dictionary
		parts.append(str(cd.get("text", "")))
		var msg: Variant = cd.get("message", null)
		if msg is String:
			parts.append(msg as String)
		elif msg is Array:
			for b: Variant in (msg as Array):
				if b is String:
					parts.append(b as String)
	return "\n".join(parts).to_lower()


# Centre le graphe sur le nœud correspondant à scene_id, le sélectionne et ouvre son panneau de détail.
func _focus_scene(scene_id: String) -> void:
	for child in _graph.get_children():
		if not (child is GraphNode):
			continue
		if child.name != StringName(scene_id):
			continue
		var node := child as GraphNode
		var node_size := node.size if node.size != Vector2.ZERO else Vector2(node.custom_minimum_size.x, 150.0)
		_graph.scroll_offset = (node.position_offset + node_size / 2.0) * _graph.zoom - _graph.size / 2.0
		for other in _graph.get_children():
			if other is GraphNode:
				(other as GraphNode).selected = false
		node.selected = true
		_selected_scene_id = scene_id
		_detail_panel.populate(scene_id)
		return
	_status_label.text = _t(
		"Nœud introuvable : %s (cliquez Refresh)" % scene_id,
		"Node not found: %s (click Refresh)" % scene_id)


func _t(fr: String, en: String) -> String:
	return fr if _ui_locale == "fr" else en


func _port_color(conn_type: String) -> Color:
	match conn_type:
		"trigger": return COLOR_TRIGGER
		"resume":  return COLOR_RESUME
		_:         return COLOR_NORMAL


# ---------------------------------------------------------------------------
# Panneau de détail

func _collect_vars() -> Array:
	var result: Array = []
	for sid in _scenes:
		var sc: Dictionary = _scenes[sid]
		var fi = sc.get("free_input", null)
		if fi != null and not result.has(str(fi)):
			result.append(str(fi))
		for msg in sc.get("messages_in", []):
			for eff in msg.get("effects", []):
				var v = eff.get("var", null)
				if v != null and str(v) and not result.has(str(v)):
					result.append(str(v))
		for ch in sc.get("choices", []):
			for eff in ch.get("effects", []):
				var v = eff.get("var", null)
				if v != null and str(v) and not result.has(str(v)):
					result.append(str(v))
	result.sort()
	return result


func _collect_flags() -> Array:
	var flags: Array = []
	for sid in _scenes:
		for ch in _scenes[sid].get("choices", []):
			var f = ch.get("flag", null)
			if f != null and not flags.has(str(f)):
				flags.append(str(f))
	flags.sort()
	return flags


func _get_main_contact_id() -> String:
	for c in _parser.contacts:
		if c.get("is_main", false):
			return c.get("id", "")
	return ""


func _on_node_selected(node: Node) -> void:
	if not (node is GraphNode):
		return
	_selected_scene_id = node.name
	_detail_panel.populate(_selected_scene_id)



# Opens the scene's source file, finds the scene by ID, runs setter on it, then writes back.
# Also syncs _scenes in memory so the detail panel stays consistent without a full graph refresh.
func _patch_field(scene_id: String, setter: Callable, label: String = "") -> void:
	var file_name: String = _scenes.get(scene_id, {}).get("_editor_file", "")
	if file_name.is_empty():
		return
	var path := "res://dialogues/" + file_name
	var data := _read_json_document(path)
	if not data.has("scenes"):
		return
	_begin_mutation(label if label != "" else _t("Modifier scène : %s" % scene_id, "Edit scene: %s" % scene_id))
	for scene in (data["scenes"] as Array):
		if scene.get("id", "") != scene_id:
			continue
		setter.call(scene)
		scene["_editor_file"] = file_name
		_scenes[scene_id] = scene
		break
	_write_json(path, data)
	_end_mutation()
