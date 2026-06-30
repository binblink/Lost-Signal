@tool
extends RefCounted

# Node ref — the VBoxContainer to populate into
var detail_content: VBoxContainer = null

# Callables injected by StoryEditorPanel via property assignment
var get_scenes:       Callable = Callable()  # () -> Dictionary
var get_flags:        Callable = Callable()  # () -> Array
var get_vars:         Callable = Callable()  # () -> Array
var get_scene_ids:    Callable = Callable()  # () -> Array
var get_contacts:     Callable = Callable()  # () -> Array
var get_dial_files:   Callable = Callable()  # () -> PackedStringArray
var patch_field:      Callable = Callable()  # (scene_id: String, setter: Callable, label: String) -> void
var get_main_contact: Callable = Callable()  # () -> String
var refresh_graph:    Callable = Callable()  # () -> void
var make_stripe:      Callable = Callable()  # (index: int) -> VBoxContainer
var translate:        Callable = Callable()  # (fr: String, en: String) -> String
var add_popup:        Callable = Callable()  # (node: Node) -> void


# Shorthand so moved functions don't need to change call syntax
func _t(fr: String, en: String) -> String:
	return translate.call(fr, en)


# Public entry point — formerly _populate_detail
func populate(scene_id: String) -> void:
	for child in detail_content.get_children():
		child.queue_free()
	var scene: Dictionary = get_scenes.call().get(scene_id, {})
	_add_header(scene_id)
	_populate_notes_section(scene_id, scene)
	_populate_contact_section(scene_id, scene)
	_populate_trigger_section(scene_id, scene)
	_populate_messages_section(scene_id, scene)
	_populate_choices_section(scene_id, scene)
	_populate_special_section(scene)


func _populate_notes_section(scene_id: String, scene: Dictionary) -> void:
	var notes_val: String = str(scene.get("_notes", ""))
	var edit := TextEdit.new()
	edit.text = notes_val
	edit.placeholder_text = _t("📝 Notes (ignorées par le moteur)…", "📝 Notes (ignored by the engine)…")
	edit.custom_minimum_size = Vector2(0, 48)
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	edit.scroll_fit_content_height = true
	edit.add_theme_color_override("font_color", Color(0.55, 0.65, 0.55))
	edit.add_theme_color_override("font_placeholder_color", Color(0.35, 0.42, 0.35))
	var last_saved: Array = [notes_val]
	edit.focus_exited.connect(func() -> void:
		var val := edit.text
		if val == last_saved[0]:
			return
		last_saved[0] = val
		patch_field.call(scene_id, func(s: Dictionary) -> void:
			if val.is_empty():
				s.erase("_notes")
			else:
				s["_notes"] = val))
	detail_content.add_child(edit)


func _populate_contact_section(scene_id: String, scene: Dictionary) -> void:
	var main_cid: String = get_main_contact.call()
	var current_contact_id: String = scene.get("contact_id", main_cid)
	var contact_id_list: Array = []
	var contact_opts := OptionButton.new()
	var contacts: Array = get_contacts.call()
	for ci in range(contacts.size()):
		var c: Dictionary = contacts[ci]
		contact_opts.add_item(c.get("id", "?"))
		var cid: String = c.get("id", "")
		contact_id_list.append(cid)
		if cid == current_contact_id:
			contact_opts.selected = ci
	detail_content.add_child(contact_opts)
	contact_opts.item_selected.connect(func(idx: int) -> void:
		var new_cid: String = contact_id_list[idx]
		patch_field.call(scene_id, func(s: Dictionary) -> void:
			if new_cid == get_main_contact.call():
				s.erase("contact_id")
			else:
				s["contact_id"] = new_cid)
		call_deferred("populate", scene_id)
		refresh_graph.call())


func _populate_trigger_section(scene_id: String, scene: Dictionary) -> void:
	_add_section(_t("Déclenchement", "Trigger"), Color(0.18, 0.13, 0.22))
	_add_scene_id_dropdown(detail_content,
		_t("↩ après", "↩ after"),
		str(scene.get("trigger_after_scene", "")),
		_t("(aucun)", "(none)"),
		_t("Cette scène se déclenche automatiquement quand la scène sélectionnée vient d'être jouée, sans intervention du joueur.",
			"This scene triggers automatically after the selected scene has played, with no player input."),
		func(val: String) -> void:
			patch_field.call(scene_id, func(s: Dictionary) -> void:
				if val.is_empty():
					s.erase("trigger_after_scene")
				else:
					s["trigger_after_scene"] = val))
	var resume_flag_val: String = str(scene.get("resume_after_flag", ""))
	var rf_all_flags: Array = get_flags.call().duplicate()
	if resume_flag_val and not rf_all_flags.has(resume_flag_val):
		rf_all_flags.append(resume_flag_val)
		rf_all_flags.sort()
	var rf_row := HBoxContainer.new()
	var rf_lbl := Label.new()
	rf_lbl.text = _t("🚩 si flag", "🚩 on flag")
	rf_lbl.custom_minimum_size = Vector2(56, 0)
	rf_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rf_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	rf_row.add_child(rf_lbl)
	var rf_opts := OptionButton.new()
	rf_opts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rf_opts.tooltip_text = _t(
		"Cette scène attend en coulisse jusqu'à ce que le flag choisi soit activé par un choix du joueur — puis elle se déclenche automatiquement.",
		"This scene waits in the background until the selected flag is set by a player choice — then it triggers automatically.")
	rf_opts.add_item(_t("(aucun)", "(none)"))
	var rf_sel := 0
	for fi in range(rf_all_flags.size()):
		rf_opts.add_item(rf_all_flags[fi])
		if rf_all_flags[fi] == resume_flag_val:
			rf_sel = fi + 1
	rf_opts.selected = rf_sel
	rf_opts.item_selected.connect(func(idx: int) -> void:
		patch_field.call(scene_id, func(s: Dictionary) -> void:
			if idx == 0:
				s.erase("resume_after_flag")
			else:
				s["resume_after_flag"] = rf_all_flags[idx - 1]))
	rf_row.add_child(rf_opts)
	detail_content.add_child(rf_row)
	_add_line_edit_row(detail_content,
		_t("⏱ délai", "⏱ delay"),
		str(scene.get("resume_after_delay", "")),
		_t("(ex: 5m, 1h, 300)", "(ex: 5m, 1h, 300)"),
		func(val: String) -> void:
			patch_field.call(scene_id, func(s: Dictionary) -> void:
				if val.is_empty():
					s.erase("resume_after_delay")
				elif val.is_valid_int():
					s["resume_after_delay"] = int(val)
				else:
					s["resume_after_delay"] = val),
		_t("Délai avant que cette scène continue automatiquement vers la suivante. Accepte 300 (secondes), \"5m\" ou \"1h\". Le délai reprend même après fermeture du jeu.",
			"Delay before this scene auto-continues. Accepts 300 (seconds), \"5m\" or \"1h\". The timer persists across game restarts."))


func _populate_messages_section(scene_id: String, scene: Dictionary) -> void:
	var msgs: Array = scene.get("messages_in", [])
	_add_section("%s (%d)" % [_t("Messages", "Messages"), msgs.size()], Color(0.10, 0.18, 0.30))
	for i in range(msgs.size()):
		_populate_message_row(make_stripe.call(i), scene_id, i, msgs[i])
	_populate_message_buttons(scene_id, scene)


func _populate_message_row(stripe: VBoxContainer, scene_id: String, msg_idx: int, msg: Dictionary) -> void:
	var text = msg.get("text", "")
	var media = msg.get("media", null)
	var req_flag: String = str(msg.get("requires_flag", ""))
	_add_req_flag_dropdown(stripe, req_flag, func(val: String) -> void:
		patch_field.call(scene_id, func(s: Dictionary) -> void:
			var m: Dictionary = (s["messages_in"] as Array)[msg_idx]
			if val.is_empty():
				m.erase("requires_flag")
			else:
				m["requires_flag"] = val),
		_t("Ce message ne s'affiche que si le flag sélectionné a été activé par un choix précédent du joueur.",
			"This message only appears if the selected flag was set by a previous player choice."))
	if text is Array:
		var del_row := HBoxContainer.new()
		var arr_lbl := Label.new()
		arr_lbl.text = _t("[tableau]", "[array]")
		arr_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		del_row.add_child(arr_lbl)
		var del_btn := Button.new()
		del_btn.text = "×"
		del_btn.custom_minimum_size = Vector2(28, 0)
		del_btn.tooltip_text = _t(
			"Supprime ce message entier — toutes ses bulles sont retirées de la scène.",
			"Removes this entire message — all its bubbles are deleted from the scene.")
		del_btn.pressed.connect(func() -> void:
			patch_field.call(scene_id, func(s: Dictionary) -> void:
				(s["messages_in"] as Array).remove_at(msg_idx))
			call_deferred("populate", scene_id))
		del_row.add_child(del_btn)
		stripe.add_child(del_row)
		for j in range((text as Array).size()):
			var elem = (text as Array)[j]
			if elem is String:
				var text_idx := j
				_add_text_edit_row(stripe, str(elem),
					func(val: String) -> void:
						patch_field.call(scene_id, func(s: Dictionary) -> void:
							((s["messages_in"] as Array)[msg_idx]["text"] as Array)[text_idx] = val),
					func() -> void:
						patch_field.call(scene_id, func(s: Dictionary) -> void:
							((s["messages_in"] as Array)[msg_idx]["text"] as Array).remove_at(text_idx))
						call_deferred("populate", scene_id),
					_t("✉ texte", "✉ text"))
			else:
				var d := elem as Dictionary
				var dict_idx := j
				_add_text_edit_row(stripe, str(d.get("text", "")),
					func(val: String) -> void:
						patch_field.call(scene_id, func(s: Dictionary) -> void:
							((s["messages_in"] as Array)[msg_idx]["text"] as Array)[dict_idx]["text"] = val),
					func() -> void:
						patch_field.call(scene_id, func(s: Dictionary) -> void:
							((s["messages_in"] as Array)[msg_idx]["text"] as Array).remove_at(dict_idx))
						call_deferred("populate", scene_id),
					_t("✉ texte", "✉ text"))
				_add_pause_dropdown(stripe, str(d.get("pause", "")), func(sel_idx: int) -> void:
					var pause_vals := ["", "short", "medium", "long"]
					patch_field.call(scene_id, func(s: Dictionary) -> void:
						var sub: Dictionary = ((s["messages_in"] as Array)[msg_idx]["text"] as Array)[dict_idx]
						if sel_idx == 0:
							sub.erase("pause")
						else:
							sub["pause"] = pause_vals[sel_idx])
					call_deferred("populate", scene_id))
		var add_sub_btn := Button.new()
		add_sub_btn.text = _t("+ bulle", "+ bubble")
		add_sub_btn.tooltip_text = _t(
			"Ajoute une bulle supplémentaire à ce message en tableau.",
			"Adds another bubble to this array message.")
		add_sub_btn.pressed.connect(func() -> void:
			patch_field.call(scene_id, func(s: Dictionary) -> void:
				((s["messages_in"] as Array)[msg_idx]["text"] as Array).append(""))
			call_deferred("populate", scene_id))
		stripe.add_child(add_sub_btn)
	elif media != null:
		var media_row := HBoxContainer.new()
		var media_lbl := Label.new()
		var mpath: String = str(media.get("path", "?")) if media is Dictionary else str(media)
		media_lbl.text = "📷 " + mpath.get_file()
		media_lbl.tooltip_text = mpath
		media_lbl.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
		media_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		media_row.add_child(media_lbl)
		var media_del := Button.new()
		media_del.text = "×"
		media_del.tooltip_text = _t(
			"Retire ce message de la scène.\nLe fichier image n'est pas supprimé.",
			"Removes this message from the scene.\nThe image file is not deleted.")
		media_del.custom_minimum_size = Vector2(28, 28)
		media_del.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		media_del.pressed.connect(func() -> void:
			patch_field.call(scene_id, func(s: Dictionary) -> void:
				(s["messages_in"] as Array).remove_at(msg_idx))
			call_deferred("populate", scene_id))
		media_row.add_child(media_del)
		stripe.add_child(media_row)
	else:
		_add_text_edit_row(stripe, str(text) if text != null else "",
			func(val: String) -> void:
				patch_field.call(scene_id, func(s: Dictionary) -> void:
					(s["messages_in"] as Array)[msg_idx]["text"] = val),
			func() -> void:
				patch_field.call(scene_id, func(s: Dictionary) -> void:
					(s["messages_in"] as Array).remove_at(msg_idx))
				call_deferred("populate", scene_id),
			_t("✉ texte", "✉ text"))
	for k in range(msg.get("edit", []).size()):
		var edit_op: Dictionary = msg["edit"][k]
		var edit_idx := k
		var op: String = edit_op.get("type", "")
		var delay: float = edit_op.get("delay", 0.0)
		match op:
			"correct":
				_add_item(stripe, _t("  ✎ corrigé en (+%.1fs) :" % delay, "  ✎ corrected to (+%.1fs):" % delay))
				_add_text_edit(stripe, str(edit_op.get("corrected_text", "")), func(val: String) -> void:
					patch_field.call(scene_id, func(s: Dictionary) -> void:
						((s["messages_in"] as Array)[msg_idx]["edit"] as Array)[edit_idx]["corrected_text"] = val))
			"delete":
				_add_item(stripe, _t("  ✗ supprimé (+%.1fs)" % delay, "  ✗ deleted (+%.1fs)" % delay))
	var current_pause: String = str(msg.get("pause", ""))
	_add_pause_dropdown(stripe, current_pause, func(sel_idx: int) -> void:
		var pause_vals := ["", "short", "medium", "long"]
		patch_field.call(scene_id, func(s: Dictionary) -> void:
			var m: Dictionary = (s["messages_in"] as Array)[msg_idx]
			if sel_idx == 0:
				m.erase("pause")
			else:
				m["pause"] = pause_vals[sel_idx])
		call_deferred("populate", scene_id))
	var get_msg_effs := func(s: Dictionary) -> Array:
		var m: Dictionary = (s["messages_in"] as Array)[msg_idx]
		if not m.has("effects"):
			m["effects"] = []
		return m["effects"] as Array
	_add_effects_editor(stripe, scene_id, msg.get("effects", []), get_msg_effs,
		func(s: Dictionary) -> void: (s["messages_in"] as Array)[msg_idx].erase("effects"))


func _populate_message_buttons(scene_id: String, scene: Dictionary) -> void:
	var msg_btns := HBoxContainer.new()
	var add_msg_btn := Button.new()
	add_msg_btn.text = _t("+ Message", "+ Message")
	add_msg_btn.tooltip_text = _t(
		"Ajoute une seule bulle de texte.",
		"Adds a single text bubble.")
	add_msg_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_msg_btn.pressed.connect(func() -> void:
		patch_field.call(scene_id, func(s: Dictionary) -> void:
			if not s.has("messages_in"):
				s["messages_in"] = []
			(s["messages_in"] as Array).append({"text": ""}))
		call_deferred("populate", scene_id))
	msg_btns.add_child(add_msg_btn)
	var add_arr_btn := Button.new()
	add_arr_btn.text = _t("+ Messages [...]", "+ Messages [...]")
	add_arr_btn.tooltip_text = _t(
		"Ajoute un message composé de plusieurs bulles successives.\nÀ utiliser quand un personnage envoie plusieurs courts messages à la suite.",
		"Adds a message made of several consecutive bubbles.\nUse this when a character sends multiple short messages in a row.")
	add_arr_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_arr_btn.pressed.connect(func() -> void:
		patch_field.call(scene_id, func(s: Dictionary) -> void:
			if not s.has("messages_in"):
				s["messages_in"] = []
			(s["messages_in"] as Array).append({"text": [""]}))
		call_deferred("populate", scene_id))
	msg_btns.add_child(add_arr_btn)
	var add_fi_btn := Button.new()
	add_fi_btn.text = _t("+ Saisie libre", "+ Free input")
	add_fi_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_fi_btn.tooltip_text = _t(
		"Ajoute un champ de saisie libre : le joueur tape une réponse au lieu de choisir parmi des options. La réponse est stockée dans une variable réutilisable dans les messages suivants.",
		"Adds a free text input: the player types a reply instead of picking a choice. The answer is stored in a variable you can reuse in later messages.")
	if scene.has("free_input"):
		add_fi_btn.disabled = true
	elif scene.get("choices", []).size() > 0:
		add_fi_btn.disabled = true
		add_fi_btn.tooltip_text = _t(
			"Incompatible avec les choix — un joueur ne peut pas à la fois choisir et taper du texte. Supprimez les choix d'abord.",
			"Incompatible with choices — a player can't both pick and type. Remove the choices first.")
	else:
		add_fi_btn.pressed.connect(func() -> void:
			patch_field.call(scene_id, func(s: Dictionary) -> void:
				s["free_input"] = "player_input")
			call_deferred("populate", scene_id))
	msg_btns.add_child(add_fi_btn)
	detail_content.add_child(msg_btns)
	if scene.has("free_input"):
		_populate_free_input(scene_id, scene)


func _populate_free_input(scene_id: String, scene: Dictionary) -> void:
	var fi_var_val: String = str(scene.get("free_input", ""))
	var fi_row := HBoxContainer.new()
	var fi_lbl := Label.new()
	fi_lbl.text = _t("📝 var", "📝 var")
	fi_lbl.custom_minimum_size = Vector2(56, 0)
	fi_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	fi_row.add_child(fi_lbl)
	var fi_edit := LineEdit.new()
	fi_edit.text = fi_var_val
	fi_edit.placeholder_text = "player_input"
	fi_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fi_edit.tooltip_text = _t(
		"Nom de la variable qui recevra le texte tapé par le joueur. Utilisez {nom} dans un message suivant pour l'afficher.",
		"Variable name that stores the player's typed text. Use {name} in a later message to display it.")
	fi_edit.focus_exited.connect(func() -> void:
		var val := fi_edit.text.strip_edges()
		if val == fi_var_val or val.is_empty():
			return
		patch_field.call(scene_id, func(s: Dictionary) -> void:
			s["free_input"] = val))
	fi_row.add_child(fi_edit)
	var fi_del := Button.new()
	fi_del.text = "×"
	fi_del.custom_minimum_size = Vector2(28, 28)
	fi_del.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fi_del.tooltip_text = _t("Supprime la saisie libre de cette scène.", "Removes free input from this scene.")
	fi_del.pressed.connect(func() -> void:
		patch_field.call(scene_id, func(s: Dictionary) -> void:
			s.erase("free_input")
			s.erase("free_input_placeholder"))
		call_deferred("populate", scene_id))
	fi_row.add_child(fi_del)
	detail_content.add_child(fi_row)
	_add_line_edit_row(detail_content,
		_t("💬 hint", "💬 hint"),
		str(scene.get("free_input_placeholder", "")),
		_t("(texte indicatif)", "(hint text)"),
		func(val: String) -> void:
			patch_field.call(scene_id, func(s: Dictionary) -> void:
				if val.is_empty():
					s.erase("free_input_placeholder")
				else:
					s["free_input_placeholder"] = val),
		_t("Texte affiché en grisé dans le champ de saisie pour guider le joueur.",
			"Greyed-out hint text shown in the input field to guide the player."))


func _populate_choices_section(scene_id: String, scene: Dictionary) -> void:
	var choices: Array = scene.get("choices", [])
	_add_section("%s (%d)" % [_t("Choix", "Choices"), choices.size()], Color(0.28, 0.16, 0.08))
	for i in range(choices.size()):
		_populate_choice_row(make_stripe.call(i), scene_id, i, choices[i])
	if choices.size() < 4:
		var add_choice_btn := Button.new()
		add_choice_btn.text = _t("+ Choix", "+ Choice")
		if scene.has("free_input"):
			add_choice_btn.disabled = true
			add_choice_btn.tooltip_text = _t(
				"Incompatible avec la saisie libre — un joueur ne peut pas à la fois choisir et taper du texte. Supprimez la saisie libre d'abord.",
				"Incompatible with free input — a player can't both pick and type. Remove the free input first.")
		else:
			add_choice_btn.tooltip_text = _t(
				"Ajoute un choix (max 4).\nLe lien vers la scène suivante se définit en tirant un port dans le graphe.",
				"Adds a choice (max 4).\nConnect it to the next scene by dragging a port in the graph.")
			add_choice_btn.pressed.connect(func() -> void:
				patch_field.call(scene_id, func(s: Dictionary) -> void:
					if not s.has("choices"):
						s["choices"] = []
					if (s["choices"] as Array).size() < 4:
						(s["choices"] as Array).append({"text": ""}))
				call_deferred("populate", scene_id)
				refresh_graph.call())
		detail_content.add_child(add_choice_btn)


func _populate_choice_row(stripe: VBoxContainer, scene_id: String, choice_idx: int, ch: Dictionary) -> void:
	_add_text_edit_row(stripe, str(ch.get("text", "")),
		func(val: String) -> void:
			patch_field.call(scene_id, func(s: Dictionary) -> void:
				(s["choices"] as Array)[choice_idx]["text"] = val),
		func() -> void:
			patch_field.call(scene_id, func(s: Dictionary) -> void:
				var chs: Array = s["choices"]
				chs.remove_at(choice_idx)
				if chs.is_empty():
					s.erase("choices"))
			call_deferred("populate", scene_id)
			refresh_graph.call(),
		_t("🔘 bouton", "🔘 button"))
	var raw_msg = ch.get("message", null)
	if raw_msg is Array:
		var arr_header := HBoxContainer.new()
		var arr_lbl := Label.new()
		arr_lbl.text = _t("💬 msgs [...]", "💬 msgs [...]")
		arr_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		arr_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
		arr_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		arr_header.add_child(arr_lbl)
		var arr_del := Button.new()
		arr_del.text = "×"
		arr_del.custom_minimum_size = Vector2(28, 0)
		arr_del.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		arr_del.tooltip_text = _t(
			"Supprime tout le tableau — toutes les bulles de ce choix sont retirées.",
			"Removes the entire array — all bubbles for this choice are deleted.")
		arr_del.pressed.connect(func() -> void:
			patch_field.call(scene_id, func(s: Dictionary) -> void:
				(s["choices"] as Array)[choice_idx].erase("message"))
			call_deferred("populate", scene_id))
		arr_header.add_child(arr_del)
		stripe.add_child(arr_header)
		for j in range((raw_msg as Array).size()):
			var bubble_idx := j
			_add_text_edit_row(stripe, str((raw_msg as Array)[j]),
				func(val: String) -> void:
					patch_field.call(scene_id, func(s: Dictionary) -> void:
						((s["choices"] as Array)[choice_idx]["message"] as Array)[bubble_idx] = val),
				func() -> void:
					patch_field.call(scene_id, func(s: Dictionary) -> void:
						((s["choices"] as Array)[choice_idx]["message"] as Array).remove_at(bubble_idx))
					call_deferred("populate", scene_id),
				_t("💬 bulle", "💬 bubble"))
		var add_bubble_btn := Button.new()
		add_bubble_btn.text = _t("+ bulle", "+ bubble")
		add_bubble_btn.tooltip_text = _t(
			"Ajoute une bulle supplémentaire au message envoyé quand le joueur clique ce choix.",
			"Adds another bubble to the message sent when the player picks this choice.")
		add_bubble_btn.pressed.connect(func() -> void:
			patch_field.call(scene_id, func(s: Dictionary) -> void:
				((s["choices"] as Array)[choice_idx]["message"] as Array).append(""))
			call_deferred("populate", scene_id))
		stripe.add_child(add_bubble_btn)
	elif raw_msg != null:
		var choice_msg: String = str(raw_msg)
		var msg_row := HBoxContainer.new()
		var msg_lbl := Label.new()
		msg_lbl.text = _t("💬 msg", "💬 msg")
		msg_lbl.custom_minimum_size = Vector2(56, 0)
		msg_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
		msg_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		msg_row.add_child(msg_lbl)
		var msg_edit := LineEdit.new()
		msg_edit.text = choice_msg
		msg_edit.placeholder_text = _t("(identique au texte du bouton)", "(same as button text)")
		msg_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		msg_edit.tooltip_text = _t(
			"Texte affiché dans la bulle du joueur quand il choisit cette option.\nSi vide, le texte du bouton est utilisé à la place.",
			"Text shown in the player's chat bubble when they pick this option.\nIf empty, the button text is used instead.")
		var last_saved_msg: Array = [choice_msg]
		msg_edit.focus_exited.connect(func() -> void:
			var val := msg_edit.text.strip_edges()
			if val == last_saved_msg[0]:
				return
			last_saved_msg[0] = val
			patch_field.call(scene_id, func(s: Dictionary) -> void:
				var cv: Dictionary = (s["choices"] as Array)[choice_idx]
				if val.is_empty():
					cv.erase("message")
				else:
					cv["message"] = val))
		msg_row.add_child(msg_edit)
		var msg_del := Button.new()
		msg_del.text = "×"
		msg_del.custom_minimum_size = Vector2(28, 0)
		msg_del.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		msg_del.tooltip_text = _t(
			"Supprime le message — le texte du bouton sera utilisé à la place dans la conversation.",
			"Removes the message — the button text will be used instead in the chat.")
		msg_del.pressed.connect(func() -> void:
			patch_field.call(scene_id, func(s: Dictionary) -> void:
				(s["choices"] as Array)[choice_idx].erase("message"))
			call_deferred("populate", scene_id))
		msg_row.add_child(msg_del)
		stripe.add_child(msg_row)
	else:
		var msg_btns := HBoxContainer.new()
		var add_msg_btn := Button.new()
		add_msg_btn.text = _t("+ msg", "+ msg")
		add_msg_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_msg_btn.tooltip_text = _t(
			"Ajoute une bulle simple affichée dans la conversation quand le joueur clique ce choix.\nSi absent, le texte du bouton est utilisé à la place.",
			"Adds a single bubble shown in the chat when the player picks this choice.\nIf absent, the button text is used instead.")
		add_msg_btn.pressed.connect(func() -> void:
			patch_field.call(scene_id, func(s: Dictionary) -> void:
				(s["choices"] as Array)[choice_idx]["message"] = "")
			call_deferred("populate", scene_id))
		msg_btns.add_child(add_msg_btn)
		var add_arr_btn := Button.new()
		add_arr_btn.text = _t("+ msgs [...]", "+ msgs [...]")
		add_arr_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_arr_btn.tooltip_text = _t(
			"Ajoute un message composé de plusieurs bulles successives envoyées quand le joueur clique ce choix.",
			"Adds a message made of several consecutive bubbles sent when the player picks this choice.")
		add_arr_btn.pressed.connect(func() -> void:
			patch_field.call(scene_id, func(s: Dictionary) -> void:
				(s["choices"] as Array)[choice_idx]["message"] = [""])
			call_deferred("populate", scene_id))
		msg_btns.add_child(add_arr_btn)
		stripe.add_child(msg_btns)
	var flag_val: String = str(ch.get("flag", ""))
	_add_line_edit_row(stripe, _t("🚩 flag", "🚩 flag"), flag_val,
		_t("(aucun flag)", "(no flag)"),
		func(val: String) -> void:
			patch_field.call(scene_id, func(s: Dictionary) -> void:
				var cv: Dictionary = (s["choices"] as Array)[choice_idx]
				if val.is_empty():
					cv.erase("flag")
				else:
					cv["flag"] = val),
		_t("Nom du flag activé quand le joueur choisit cette option. Utilisez-le dans \"? visible si\" d'autres messages ou choix pour les conditionner.",
			"Flag name set when the player picks this choice. Use it in \"? visible if\" on other messages or choices to make them conditional."))
	var req_val: String = str(ch.get("requires_flag", ""))
	_add_req_flag_dropdown(stripe, req_val, func(val: String) -> void:
		patch_field.call(scene_id, func(s: Dictionary) -> void:
			var cv: Dictionary = (s["choices"] as Array)[choice_idx]
			if val.is_empty():
				cv.erase("requires_flag")
			else:
				cv["requires_flag"] = val),
		_t("Ce choix n'est proposé au joueur que si le flag sélectionné a été activé par un choix précédent.",
			"This choice is only offered to the player if the selected flag was set by a previous choice."))
	var cnext: String = str(ch.get("next", ""))
	_add_scene_id_dropdown(stripe,
		_t("→ next", "→ next"),
		cnext,
		_t("(non lié)", "(not linked)"),
		_t("Scène jouée quand le joueur choisit cette option.", "Scene played when the player picks this choice."),
		func(val: String) -> void:
			patch_field.call(scene_id, func(s: Dictionary) -> void:
				var cv: Dictionary = (s["choices"] as Array)[choice_idx]
				if val.is_empty():
					cv.erase("next")
				else:
					cv["next"] = val)
			call_deferred("populate", scene_id)
			refresh_graph.call())
	var get_ch_effs := func(s: Dictionary) -> Array:
		var cv: Dictionary = (s["choices"] as Array)[choice_idx]
		if not cv.has("effects"):
			cv["effects"] = []
		return cv["effects"] as Array
	_add_effects_editor(stripe, scene_id, ch.get("effects", []), get_ch_effs,
		func(s: Dictionary) -> void: (s["choices"] as Array)[choice_idx].erase("effects"))


func _populate_special_section(scene: Dictionary) -> void:
	var specials: Array = []
	for key: String in ["next", "music"]:
		if scene.has(key):
			specials.append("%s: %s" % [key, str(scene[key])])
	if specials.size() > 0:
		_add_section(_t("JSON seulement", "JSON-only"))
		for s: String in specials:
			_add_item(detail_content, s)


func _add_text_edit(container: VBoxContainer, initial: String, on_commit: Callable) -> void:
	var edit := TextEdit.new()
	edit.text = initial
	edit.custom_minimum_size = Vector2(0, 52)
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	edit.scroll_fit_content_height = true
	edit.focus_exited.connect(func() -> void:
		var val := edit.text
		if val != initial:
			on_commit.call(val))
	container.add_child(edit)


func _add_line_edit_row(container: VBoxContainer, label: String, initial: String, placeholder: String, on_commit: Callable, tooltip: String = "") -> void:
	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size = Vector2(56, 0)
	lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	row.add_child(lbl)
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


func _add_pause_dropdown(container: VBoxContainer, current_pause: String, on_change: Callable) -> void:
	var opts := OptionButton.new()
	opts.add_item(_t("(aucune pause)", "(no pause)"))
	opts.add_item("short")
	opts.add_item("medium")
	opts.add_item("long")
	match current_pause:
		"short":  opts.selected = 1
		"medium": opts.selected = 2
		"long":   opts.selected = 3
		_:        opts.selected = 0
	opts.item_selected.connect(on_change)
	container.add_child(opts)


func _add_req_flag_dropdown(container: VBoxContainer, current: String, on_change: Callable, tooltip: String = "") -> void:
	var all_flags: Array = get_flags.call().duplicate()
	if current and not all_flags.has(current):
		all_flags.append(current)
		all_flags.sort()
	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = _t("? visible si", "? visible if")
	lbl.custom_minimum_size = Vector2(56, 0)
	lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	row.add_child(lbl)
	var opts := OptionButton.new()
	opts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if tooltip:
		opts.tooltip_text = tooltip
	opts.add_item(_t("(toujours affiché)", "(always shown)"))
	var selected := 0
	for fi in range(all_flags.size()):
		opts.add_item(all_flags[fi])
		if all_flags[fi] == current:
			selected = fi + 1
	opts.selected = selected
	opts.item_selected.connect(func(idx: int) -> void:
		if idx == 0:
			on_change.call("")
		else:
			on_change.call(all_flags[idx - 1]))
	row.add_child(opts)
	container.add_child(row)


func _add_scene_id_dropdown(container: VBoxContainer, label: String, current: String, none_label: String, tooltip: String, on_change: Callable) -> void:
	var all_ids: Array = get_scene_ids.call().duplicate()
	if current and not all_ids.has(current):
		all_ids.append(current)
		all_ids.sort()
	var row := HBoxContainer.new()
	if not label.is_empty():
		var lbl := Label.new()
		lbl.text = label
		lbl.custom_minimum_size = Vector2(56, 0)
		lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
		row.add_child(lbl)
	var opts := OptionButton.new()
	opts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opts.tooltip_text = tooltip
	opts.add_item(none_label)
	var selected := 0
	for si in range(all_ids.size()):
		opts.add_item(all_ids[si])
		if all_ids[si] == current:
			selected = si + 1
	opts.selected = selected
	opts.item_selected.connect(func(idx: int) -> void:
		if idx == 0:
			on_change.call("")
		else:
			on_change.call(all_ids[idx - 1]))
	row.add_child(opts)
	container.add_child(row)


func _add_text_edit_row(container: VBoxContainer, initial: String, on_commit: Callable, on_delete: Callable, label: String = "") -> void:
	var row := HBoxContainer.new()
	if label:
		var lbl := Label.new()
		lbl.text = label
		lbl.custom_minimum_size = Vector2(56, 0)
		lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
		row.add_child(lbl)
	var edit := TextEdit.new()
	edit.text = initial
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.custom_minimum_size = Vector2(0, 52)
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	edit.scroll_fit_content_height = true
	edit.focus_exited.connect(func() -> void:
		var val := edit.text
		if val != initial:
			on_commit.call(val))
	row.add_child(edit)
	var del_btn := Button.new()
	del_btn.text = "×"
	del_btn.custom_minimum_size = Vector2(28, 28)
	del_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	del_btn.pressed.connect(on_delete)
	row.add_child(del_btn)
	container.add_child(row)


func _add_header(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_content.add_child(lbl)


func _add_section(title: String, bg_color: Color = Color(0.15, 0.15, 0.18)) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	detail_content.add_child(spacer)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0))
	panel.add_child(lbl)
	detail_content.add_child(panel)


func _add_item(container: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = "  " + text
	lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(lbl)


func _add_effects_editor(container: VBoxContainer, scene_id: String, effects: Array, get_effs: Callable, on_empty: Callable) -> void:
	for ei in range(effects.size()):
		_add_effect_row(container, scene_id, ei, effects[ei], get_effs, on_empty)
	var add_eff_btn := Button.new()
	add_eff_btn.text = _t("+ Effet", "+ Effect")
	add_eff_btn.tooltip_text = _t(
		"Ajoute un effet déclenché à ce moment.\nset/add/sub : modifie une variable\nrename : renomme un contact\nset_status : change le statut d'un contact",
		"Adds an effect triggered at this point.\nset/add/sub: modify a variable\nrename: rename a contact\nset_status: change a contact's status")
	add_eff_btn.pressed.connect(func() -> void:
		patch_field.call(scene_id, func(s: Dictionary) -> void:
			var effs: Array = get_effs.call(s)
			effs.append({"op": "set", "var": "", "value": ""}))
		call_deferred("populate", scene_id))
	container.add_child(add_eff_btn)


func _add_effect_row(container: VBoxContainer, scene_id: String, eff_idx: int, eff: Dictionary, get_effs: Callable, on_empty: Callable) -> void:
	const OPS := ["set", "add", "sub", "rename", "set_status"]
	const STATUS_VALS := ["online", "away", "offline", "network_issue"]
	var op: String = str(eff.get("op", "set"))
	var is_contact_op := op in ["rename", "set_status"]
	var target_key := "contact" if is_contact_op else "var"
	var target_val: String = str(eff.get(target_key, ""))
	var value_val: String = str(eff.get("value", ""))

	var row := HBoxContainer.new()

	var op_opts := OptionButton.new()
	for o in OPS:
		op_opts.add_item(o)
	op_opts.selected = max(OPS.find(op), 0)
	op_opts.tooltip_text = _t(
		"set   : fixe une variable à une valeur précise\nadd  : ajoute une valeur à une variable (compteur, score…)\nsub   : soustrait une valeur à une variable\nrename     : change le nom affiché d'un contact\nset_status : change le statut d'un contact",
		"set   : sets a variable to a specific value\nadd  : adds a value to a variable (counter, score…)\nsub   : subtracts a value from a variable\nrename     : changes a contact's display name\nset_status : changes a contact's status")
	op_opts.item_selected.connect(func(idx: int) -> void:
		patch_field.call(scene_id, func(s: Dictionary) -> void:
			var effs: Array = get_effs.call(s)
			var e: Dictionary = effs[eff_idx]
			var new_op: String = OPS[idx]
			var new_contact: bool = new_op in ["rename", "set_status"]
			var old_contact: bool = str(e.get("op", "set")) in ["rename", "set_status"]
			e["op"] = new_op
			if new_contact != old_contact:
				if new_contact:
					var v: String = str(e.get("var", ""))
					e.erase("var")
					e["contact"] = v
				else:
					var c: String = str(e.get("contact", ""))
					e.erase("contact")
					e["var"] = c)
		call_deferred("populate", scene_id))
	row.add_child(op_opts)

	if is_contact_op:
		var contact_ids: Array = []
		for c: Dictionary in get_contacts.call():
			contact_ids.append(c.get("id", ""))
		if target_val and not contact_ids.has(target_val):
			contact_ids.append(target_val)
		var target_opts := OptionButton.new()
		target_opts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		target_opts.add_item(_t("(aucun)", "(none)"))
		var target_sel := 0
		for ci in range(contact_ids.size()):
			target_opts.add_item(contact_ids[ci])
			if contact_ids[ci] == target_val:
				target_sel = ci + 1
		target_opts.selected = target_sel
		target_opts.item_selected.connect(func(idx: int) -> void:
			patch_field.call(scene_id, func(s: Dictionary) -> void:
				if idx == 0:
					get_effs.call(s)[eff_idx].erase(target_key)
				else:
					get_effs.call(s)[eff_idx][target_key] = contact_ids[idx - 1]))
		row.add_child(target_opts)
	else:
		var all_vars: Array = get_vars.call().duplicate()
		if target_val and not all_vars.has(target_val):
			all_vars.append(target_val)
			all_vars.sort()
		var var_container := HBoxContainer.new()
		var_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var var_edit := LineEdit.new()
		var_edit.text = target_val
		var_edit.placeholder_text = _t("nom de variable", "variable name")
		var_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var_edit.focus_exited.connect(func() -> void:
			var val := var_edit.text.strip_edges()
			patch_field.call(scene_id, func(s: Dictionary) -> void:
				if val.is_empty():
					get_effs.call(s)[eff_idx].erase(target_key)
				else:
					get_effs.call(s)[eff_idx][target_key] = val))
		var_container.add_child(var_edit)
		if not all_vars.is_empty():
			var pick_btn := Button.new()
			pick_btn.text = "▾"
			pick_btn.flat = true
			pick_btn.custom_minimum_size = Vector2(28, 0)
			pick_btn.pressed.connect(func() -> void:
				var popup := PopupMenu.new()
				for v: String in all_vars:
					popup.add_item(v)
				add_popup.call(popup)
				popup.id_pressed.connect(func(idx: int) -> void:
					var chosen: String = all_vars[idx]
					var_edit.text = chosen
					patch_field.call(scene_id, func(s: Dictionary) -> void:
						get_effs.call(s)[eff_idx][target_key] = chosen)
					popup.queue_free())
				popup.popup_on_parent(Rect2(pick_btn.global_position + Vector2(0, pick_btn.size.y), Vector2.ZERO)))
			var_container.add_child(pick_btn)
		row.add_child(var_container)

	var eq_lbl := Label.new()
	eq_lbl.text = "="
	eq_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	eq_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	row.add_child(eq_lbl)

	if op == "set_status":
		var status_opts := OptionButton.new()
		for sv: String in STATUS_VALS:
			status_opts.add_item(sv)
		status_opts.selected = max(STATUS_VALS.find(value_val), 0)
		status_opts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		status_opts.item_selected.connect(func(idx: int) -> void:
			patch_field.call(scene_id, func(s: Dictionary) -> void:
				get_effs.call(s)[eff_idx]["value"] = STATUS_VALS[idx]))
		row.add_child(status_opts)
	elif op == "rename":
		_add_rename_value_editor(row, scene_id, eff_idx, eff.get("value", ""), get_effs)
	else:
		var value_edit := LineEdit.new()
		value_edit.text = value_val
		value_edit.placeholder_text = _t("valeur", "value")
		value_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value_edit.focus_exited.connect(func() -> void:
			var val := value_edit.text.strip_edges()
			if val == value_val:
				return
			patch_field.call(scene_id, func(s: Dictionary) -> void:
				var parsed = int(val) if val.is_valid_int() else (float(val) if val.is_valid_float() else val)
				get_effs.call(s)[eff_idx]["value"] = parsed))
		row.add_child(value_edit)

	var del_btn := Button.new()
	del_btn.text = "×"
	del_btn.custom_minimum_size = Vector2(28, 28)
	del_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	del_btn.pressed.connect(func() -> void:
		patch_field.call(scene_id, func(s: Dictionary) -> void:
			var effs: Array = get_effs.call(s)
			effs.remove_at(eff_idx)
			if effs.is_empty():
				on_empty.call(s))
		call_deferred("populate", scene_id))
	row.add_child(del_btn)
	container.add_child(row)


func _add_rename_value_editor(row: HBoxContainer, scene_id: String, eff_idx: int, raw_val: Variant, get_effs: Callable) -> void:
	var live_dict: Dictionary = {}
	if raw_val is Dictionary:
		live_dict = (raw_val as Dictionary).duplicate()
	elif str(raw_val) != "" and str(raw_val) != "null":
		live_dict[""] = str(raw_val)
	if live_dict.is_empty():
		live_dict[""] = ""

	var save_val: Callable = func() -> void:
		var without_default: Dictionary = {}
		for k in live_dict:
			if k != "":
				without_default[str(k)] = str(live_dict[k])
		if without_default.is_empty():
			var str_val: String = str(live_dict.get("", ""))
			patch_field.call(scene_id, func(s: Dictionary) -> void:
				get_effs.call(s)[eff_idx]["value"] = str_val)
		else:
			patch_field.call(scene_id, func(s: Dictionary) -> void:
				get_effs.call(s)[eff_idx]["value"] = without_default)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 2)

	for lk in live_dict.keys():
		var e_lang: String = str(lk)
		var e_name: String = str(live_dict[lk])
		var entry_row := HBoxContainer.new()
		entry_row.add_theme_constant_override("separation", 2)

		if e_lang == "":
			var def_lbl := Label.new()
			def_lbl.text = "—"
			def_lbl.custom_minimum_size = Vector2(36, 0)
			def_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			def_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			def_lbl.tooltip_text = _t(
				"Nom invariant (même dans toutes les langues). Cliquez + Langue pour localiser.",
				"Invariant name (same in all languages). Click + Language to localize.")
			entry_row.add_child(def_lbl)
		else:
			var lang_edit := LineEdit.new()
			lang_edit.text = e_lang
			lang_edit.placeholder_text = "fr"
			lang_edit.custom_minimum_size = Vector2(36, 0)
			_apply_rename_lang_color(lang_edit, e_lang)
			lang_edit.focus_exited.connect(func() -> void:
				var new_lang: String = lang_edit.text.strip_edges()
				_apply_rename_lang_color(lang_edit, new_lang)
				if new_lang == e_lang:
					return
				if new_lang.is_empty():
					lang_edit.text = e_lang
					return
				var cur_name: String = str(live_dict.get(e_lang, ""))
				live_dict.erase(e_lang)
				live_dict[new_lang] = cur_name
				save_val.call()
				call_deferred("populate", scene_id))
			entry_row.add_child(lang_edit)

		var name_edit := LineEdit.new()
		name_edit.text = e_name
		name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_edit.focus_exited.connect(func() -> void:
			var first_child := entry_row.get_child(0)
			var cur_lang: String = (first_child as LineEdit).text.strip_edges() if first_child is LineEdit else ""
			live_dict[cur_lang] = name_edit.text
			save_val.call())
		entry_row.add_child(name_edit)

		var rm_btn := Button.new()
		rm_btn.text = "×"
		rm_btn.custom_minimum_size = Vector2(22, 0)
		rm_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rm_btn.pressed.connect(func() -> void:
			live_dict.erase(e_lang)
			save_val.call()
			call_deferred("populate", scene_id))
		entry_row.add_child(rm_btn)
		vbox.add_child(entry_row)

	var add_lang_btn := Button.new()
	add_lang_btn.text = _t("+ Langue", "+ Language")
	add_lang_btn.tooltip_text = _t(
		"Si une seule entrée invariante : la convertit en première langue.\nSinon : ajoute une nouvelle entrée localisée.",
		"If only one invariant entry: converts it to the first language.\nOtherwise: adds a new localized entry.")
	add_lang_btn.pressed.connect(func() -> void:
		if live_dict.has("") and live_dict.size() == 1:
			live_dict.erase("")
		live_dict["??"] = ""
		save_val.call()
		call_deferred("populate", scene_id))
	vbox.add_child(add_lang_btn)
	row.add_child(vbox)


func _apply_rename_lang_color(field: LineEdit, code: String) -> void:
	if code.is_empty() or code.begins_with("??"):
		field.add_theme_color_override("font_color", Color(1.0, 0.65, 0.2))
		return
	for f: String in get_dial_files.call():
		if f.ends_with("." + code + ".json"):
			field.remove_theme_color_override("font_color")
			return
	field.add_theme_color_override("font_color", Color(1.0, 0.65, 0.2))
