extends Control

signal choice_made

@onready var message_display = $RootHBox/VBoxContainer/Messages/MessagesList
@onready var input_bar = $RootHBox/VBoxContainer/InputBar
@onready var line_edit = $RootHBox/VBoxContainer/InputBar/MarginContainer/HBoxContainer/TextInput
@onready var choices_layer = $ChoicesLayer
@onready var confirm_dialog = $ConfirmDialog
@onready var overlay = $Overlay
@onready var reset_button = $RootHBox/VBoxContainer/TopBar/MarginContainer/HBoxContainer/Reset
@onready var panel_button = $RootHBox/VBoxContainer/TopBar/MarginContainer/HBoxContainer/PanelButton
var _total_unread: int = 0
@onready var contact_name_label = $RootHBox/VBoxContainer/TopBar/MarginContainer/HBoxContainer/VBoxContainer/ContactName
@onready var _contact_panel = $RootHBox/ContactPanel
@onready var btn_annuler = $ConfirmDialog/MarginContainer/VBoxContainer/HBoxContainer/Annuler
@onready var btn_recommencer = $ConfirmDialog/MarginContainer/VBoxContainer/HBoxContainer/Recommencer

var current_scene: Dictionary = {}
var flags: Dictionary = {}
var vars: Dictionary = {}
var contact_names: Dictionary = {}
var current_message_index: int = 0
var waiting_for_choice: bool = false
var _is_player_typing: bool = false
var secondary_histories: Dictionary = {}
var _played_secondary_scenes: Array = []

# Contact actif
var _active_contact_id: String = ""
# Historiques en mémoire { contact_id: Array[{text, time, out}] }
var _contact_histories: Dictionary = {}
# { contact_id: scene_id } — scènes en attente de choix par contact
var _pending_choices: Dictionary = {}


func _ready() -> void:
	# Câblage ChoicesManager
	choices_layer.message_display = message_display
	choices_layer.scroll_container = $RootHBox/VBoxContainer/Messages
	choices_layer.input_bar = input_bar
	choices_layer.choice_selected.connect(_on_choice_pressed)
	# Câblage MessageDisplay
	message_display.line_edit = line_edit
	# UI globale
	confirm_dialog.visible = false
	overlay.visible = false
	reset_button.pressed.connect(_on_new_game_pressed)
	panel_button.pressed.connect(_on_contacts_button_pressed)
	btn_annuler.pressed.connect(_on_annuler_pressed)
	btn_recommencer.pressed.connect(_on_recommencer_pressed)
	# Panneau contacts
	_contact_panel.contact_selected.connect(_on_contact_selected)
	# Contact principal par défaut
	_active_contact_id = DialogueLoader.get_main_contact().get("id", "maeve")
	_update_topbar(_active_contact_id)
	# Panneau ouvert par défaut
	_contact_panel.show_panel()
	# Démarrage
	if SaveManager.has_save():
		await load_game()
	else:
		await play_scene(DialogueLoader.get_start_scene())

# ---------------------------------------------------------------------------
# Topbar
# ---------------------------------------------------------------------------

func _get_display_name(contact_id: String) -> String:
	if contact_names.has(contact_id):
		return contact_names[contact_id]
	var contact = DialogueLoader.get_contact(contact_id)
	if contact.is_empty():
		contact = DialogueLoader.get_main_contact()
	return contact.get("name", "")

func _update_topbar(contact_id: String) -> void:
	contact_name_label.text = _get_display_name(contact_id)

# ---------------------------------------------------------------------------
# Panneau contacts
# ---------------------------------------------------------------------------

func _on_contacts_button_pressed() -> void:
	if _contact_panel._is_open:
		_contact_panel.hide_panel()
	else:
		_contact_panel.show_panel()

func _update_panel_button() -> void:
	if _total_unread > 0:
		panel_button.text = "☰●"
	else:
		panel_button.text = "☰"

func _on_contact_selected(contact_id: String, unread_count: int) -> void:
	if _is_player_typing:
		return
	if unread_count > 0:
		_total_unread = max(0, _total_unread - unread_count)
		_update_panel_button()
	if contact_id == _active_contact_id:
		return
	# Sauvegarder l'historique du contact actif avant de switcher
	_contact_histories[_active_contact_id] = _collect_messages_data()
	_active_contact_id = contact_id
	_update_topbar(contact_id)
	var contact_data = DialogueLoader.get_contact(contact_id)
	var is_main = contact_data.get("is_main", false)
	line_edit.editable = is_main
	line_edit.mouse_filter = Control.MOUSE_FILTER_STOP if is_main else Control.MOUSE_FILTER_IGNORE
	# Afficher l'historique du contact sélectionné
	message_display.clear_messages()
	await get_tree().process_frame
	var history = _contact_histories.get(contact_id, [])
	for msg in history:
		if msg["out"]:
			await message_display.send_message(msg["text"])
		else:
			await message_display.receive_message(msg["text"], msg["time"])
	await message_display.scroll_to_bottom()
	# Désactiver l'input pour les contacts secondaires, mais le laisser visible
	var contact = DialogueLoader.get_contact(contact_id)
	var contact_is_main = contact.get("is_main", false)
	input_bar.visible = true
	line_edit.editable = contact_is_main
	line_edit.mouse_filter = Control.MOUSE_FILTER_STOP if contact_is_main else Control.MOUSE_FILTER_IGNORE
	# Afficher les choix en attente si ce contact en a
	if _pending_choices.has(contact_id):
		var pending_scene = DialogueLoader.get_scene(_pending_choices[contact_id])
		if pending_scene.has("choices"):
			waiting_for_choice = true
			current_scene = pending_scene
			current_message_index = 0
			await choices_layer.show_choices(
				pending_scene["choices"].map(func(c): return c["text"])
			)
	else:
		choices_layer.visible = false

# ---------------------------------------------------------------------------
# Progression narrative
# ---------------------------------------------------------------------------

func play_scene(scene_id: String) -> void:
	if not DialogueLoader.has_scene(scene_id):
		return
	current_scene = DialogueLoader.get_scene(scene_id)
	var scene_contact = current_scene.get("contact_id", DialogueLoader.get_main_contact().get("id", "maeve"))

	# Si la scène appartient à un contact non affiché, l'ajouter à son historique silencieusement
	if scene_contact != _active_contact_id:
		_play_secondary_scene(current_scene)
		_trigger_next_scenes(scene_id)
		return

	for i in range(current_message_index, current_scene["messages_in"].size()):
		var msg = current_scene["messages_in"][i]
		if _eval_condition(msg):
			var pause = msg.get("pause", null)
			if pause != null:
				await do_pause(pause)
			var typing_ok = await message_display.show_typing(msg["text"])
			if not typing_ok:
				return
			var bubble = await message_display.receive_message(msg["text"], msg["time"])
			var edit = msg.get("edit", null)
			if edit != null:
				await get_tree().create_timer(edit.get("delay", 1.5)).timeout
				if is_instance_valid(bubble):
					if edit["type"] == "delete":
						bubble.queue_free()
					elif edit["type"] == "correct":
						bubble.get_node("HBoxContainer/Bubble/MarginContainer/VBoxContainer/Message").text = edit["corrected_text"]
			else:
				await get_tree().create_timer(0.5).timeout
		current_message_index = i + 1
		save_game()

	waiting_for_choice = true
	save_game(false)

	if current_scene.has("choices"):
		await choices_layer.show_choices(
			current_scene["choices"].map(func(c): return c["text"])
		)
		await choice_made

	_trigger_next_scenes(scene_id)

func _play_secondary_scene(scene: Dictionary) -> void:
	var scene_id = scene.get("id", "")
	# Ne pas rejouer une scène secondaire déjà jouée
	if scene_id in _played_secondary_scenes:
		return
	_played_secondary_scenes.append(scene_id)
	var contact_id = scene.get("contact_id", "")
	if not _contact_histories.has(contact_id):
		_contact_histories[contact_id] = []
	for msg in scene.get("messages_in", []):
		_contact_histories[contact_id].append({
			"text": msg["text"],
			"time": msg["time"],
			"out": false
		})
	# Si la scène a des choix, les mettre en attente
	if scene.has("choices") and scene["choices"].size() > 0:
		_pending_choices[contact_id] = scene["id"]
	# Notifier le panneau
	if _contact_panel:
		AudioManager.play_notification()
		_contact_panel.mark_unread(contact_id)
		_contact_panel.update_history(contact_id, _contact_histories.get(contact_id, []))
		_total_unread += 1
		_update_panel_button()
	save_game()

func _trigger_next_scenes(scene_id: String) -> void:
	var triggered = DialogueLoader.get_triggered_scenes(scene_id)
	for triggered_id in triggered:
		await play_scene(triggered_id)

func _on_choice_pressed(index: int) -> void:
	if not current_scene.has("choices"):
		return
	var choice = current_scene["choices"][index]
	waiting_for_choice = false
	current_message_index = 0
	_apply_effects(choice)
	choices_layer.hide_choices()
	input_bar.visible = true
	# Effacer le pending choice pour ce contact
	_pending_choices.erase(_active_contact_id)
	var message_text = choice.get("message", choice["text"])
	_is_player_typing = true
	await message_display.type_message(message_text)
	_is_player_typing = false
	var next_scene_id = choice.get("next", null)
	if next_scene_id != null and DialogueLoader.has_scene(next_scene_id):
		current_scene = DialogueLoader.get_scene(next_scene_id)
		# S'assurer que la prochaine scène est bien associée au contact actif
		current_scene["contact_id"] = _active_contact_id
	save_game()
	choice_made.emit()
	if next_scene_id != null:
		await play_scene(next_scene_id)

func do_pause(type: String) -> void:
	var duration: float
	match type:
		"short":  duration = randf_range(1.0, 4.0)
		"medium": duration = randf_range(5.0, 15.0)
		"long":   duration = randf_range(15.0, 40.0)
		_:        duration = 0.5
	await get_tree().create_timer(duration).timeout

# ---------------------------------------------------------------------------
# Save / Load
# ---------------------------------------------------------------------------

func _collect_messages_data() -> Array:
	var messages_data = []
	for child in message_display.get_children():
		if child is MarginContainer:
			var hbox = child.get_node("HBoxContainer")
			var spacer_index = -1
			for i in range(hbox.get_child_count()):
				if hbox.get_child(i) is Control and not hbox.get_child(i) is PanelContainer:
					spacer_index = i
			var bubble_out = spacer_index == 0
			var text = child.get_node("HBoxContainer/Bubble/MarginContainer/VBoxContainer/Message").text
			var time = child.get_node("HBoxContainer/Bubble/MarginContainer/VBoxContainer/TimeAndStatus").text
			messages_data.append({"text": text, "time": time, "out": bubble_out})
	return messages_data

func save_game(notify_panel: bool = true) -> void:
	_contact_histories[_active_contact_id] = _collect_messages_data()
	SaveManager.save(
		_contact_histories,
		current_scene.get("id", ""),
		current_message_index,
		waiting_for_choice,
		flags,
		vars,
		contact_names,
		secondary_histories,
		_played_secondary_scenes,
		_pending_choices
	)
	if notify_panel:
		_contact_panel.update_history(_active_contact_id, _contact_histories.get(_active_contact_id, []))


func load_game() -> void:
	var data = SaveManager.load_save()
	if data.is_empty():
		return
	flags = data.get("flags", {})
	vars = data.get("vars", {})
	contact_names = data.get("contact_names", {})
	for cid in contact_names:
		_contact_panel.set_contact_name(cid, contact_names[cid])
	current_message_index = data.get("current_message_index", 0)
	waiting_for_choice = data.get("waiting_for_choice", false)
	secondary_histories = data.get("secondary_histories", {})
	_played_secondary_scenes = data.get("played_secondary_scenes", [])
	_pending_choices = data.get("pending_choices", {})
	_contact_histories = data.get("messages", {})
	_active_contact_id = DialogueLoader.get_main_contact().get("id", "maeve")
	_update_topbar(_active_contact_id)
	message_display.clear_messages()
	await get_tree().process_frame
	for msg in _contact_histories.get(_active_contact_id, []):
		if msg["out"]:
			await message_display.send_message(msg["text"])
		else:
			await message_display.receive_message(msg["text"], msg["time"])
	await message_display.scroll_to_bottom()
	var scene_id = data.get("current_scene_id", "")
	if scene_id == "" or not DialogueLoader.has_scene(scene_id):
		return
	current_scene = DialogueLoader.get_scene(scene_id)
	# Mettre à jour les aperçus dans le panneau pour tous les contacts
	for cid in _contact_histories:
		_contact_panel.update_history(cid, _contact_histories.get(cid, []))
	if waiting_for_choice:
		if current_scene.has("choices"):
			await choices_layer.show_choices(
				current_scene["choices"].map(func(c): return c["text"])
			)
			await choice_made
	else:
		await play_scene(scene_id)

# ---------------------------------------------------------------------------
# UI globale
# ---------------------------------------------------------------------------

func _on_new_game_pressed() -> void:
	confirm_dialog.visible = true
	overlay.visible = true

func _on_annuler_pressed() -> void:
	confirm_dialog.visible = false
	overlay.visible = false

func _on_recommencer_pressed() -> void:
	SaveManager.delete_save()
	await get_tree().process_frame
	get_tree().reload_current_scene()

# ---------------------------------------------------------------------------
# État narratif
# ---------------------------------------------------------------------------

func _eval_condition(msg: Dictionary) -> bool:
	var req_flag = msg.get("requires_flag", null)
	if req_flag != null and not flags.get(req_flag, false):
		return false
	var cond = msg.get("condition", null)
	if cond != null:
		var val = vars.get(cond["var"], 0)
		var target = cond["value"]
		match cond["op"]:
			"eq":  if val != target: return false
			"neq": if val == target: return false
			"gt":  if not val > target: return false
			"gte": if not val >= target: return false
			"lt":  if not val < target: return false
			"lte": if not val <= target: return false
	return true

func _apply_effects(choice: Dictionary) -> void:
	if choice.get("flag", null) != null:
		flags[choice["flag"]] = true
	for effect in choice.get("effects", []):
		match effect["op"]:
			"set":    vars[effect["var"]] = effect["value"]
			"add":    vars[effect["var"]] = vars.get(effect["var"], 0) + effect["value"]
			"sub":    vars[effect["var"]] = vars.get(effect["var"], 0) - effect["value"]
			"rename":
				var cid: String = effect.get("contact", "")
				var new_name: String = str(effect.get("value", ""))
				if cid != "" and new_name != "":
					contact_names[cid] = new_name
					_contact_panel.set_contact_name(cid, new_name)
					if cid == _active_contact_id:
						_update_topbar(cid)
