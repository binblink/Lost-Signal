@tool
extends Control

# Injected by StoryEditorPanel
var scenes:      Dictionary = {}
var start_scene: String     = ""
var ui_locale:   String     = "fr"
var focus_scene: Callable   = Callable()


func refresh() -> void:
	for child in get_children():
		child.queue_free()

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top",    12)
	margin.add_theme_constant_override("margin_left",   12)
	margin.add_theme_constant_override("margin_right",  12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(vbox)

	var data := _run_analysis()
	_build_ui(vbox, data)


# ---------------------------------------------------------------------------
# Analyse

func _run_analysis() -> Dictionary:
	var outgoing := _build_outgoing()
	var reachable := _bfs_reachable(outgoing)

	var dead_end_ids:   Array[String] = []
	var unreachable_ids: Array[String] = []
	var message_count  := 0
	var choice_count   := 0
	var word_count     := 0
	var contact_counts: Dictionary = {}

	for sid: String in scenes:
		var scene: Dictionary = scenes[sid]

		# Dead end: no outgoing edge leads anywhere
		var has_target := false
		for conn: Variant in outgoing.get(sid, []):
			if str((conn as Dictionary).get("target", "")) != "":
				has_target = true
				break
		if not has_target:
			dead_end_ids.append(sid)

		# Reachability
		if not reachable.has(sid):
			unreachable_ids.append(sid)

		# Message / word / contact counts
		var cid: String = str(scene.get("contact_id", ""))
		for msg: Variant in (scene.get("messages_in", []) as Array):
			message_count += 1
			word_count += _count_words((msg as Dictionary).get("text", ""))
			if not contact_counts.has(cid):
				contact_counts[cid] = 0
			contact_counts[cid] = int(contact_counts[cid]) + 1

		choice_count += (scene.get("choices", []) as Array).size()

	unreachable_ids.sort()

	# Flags: set by choices vs actually checked/waited
	var flags_set:  Dictionary = {}
	var flags_used: Dictionary = {}
	for sid: String in scenes:
		var scene: Dictionary = scenes[sid]
		for ch: Variant in (scene.get("choices", []) as Array):
			var f: String = str((ch as Dictionary).get("flag", ""))
			if not f.is_empty():
				flags_set[f] = true
		var raf: String = str(scene.get("resume_after_flag", ""))
		if not raf.is_empty():
			flags_used[raf] = true
		_collect_flag_uses(scene.get("requires_flag", null), flags_used)
		for msg: Variant in (scene.get("messages_in", []) as Array):
			var md := msg as Dictionary
			_collect_flag_uses(md.get("requires_flag", null), flags_used)
			_collect_flag_uses(md.get("condition",     null), flags_used)
		for ch: Variant in (scene.get("choices", []) as Array):
			var cd := ch as Dictionary
			_collect_flag_uses(cd.get("requires_flag", null), flags_used)
			_collect_flag_uses(cd.get("condition",     null), flags_used)

	var unused_flags: Array[String] = []
	for f: String in flags_set:
		if not flags_used.has(f):
			unused_flags.append(f)
	unused_flags.sort()

	return {
		"scene_count":     scenes.size(),
		"message_count":   message_count,
		"choice_count":    choice_count,
		"dead_end_ids":    dead_end_ids,
		"unreachable_ids": unreachable_ids,
		"reachable_count": reachable.size(),
		"unused_flags":    unused_flags,
		"cycles":          _detect_cycles(outgoing),
		"contact_counts":  contact_counts,
		"word_count":      word_count,
		"estimated_min":   word_count / 200.0,
	}


# Builds a simplified outgoing graph: scene_id → [{target}].
# Mirrors _build_outgoing in StoryEditorPanel but without UI labels.
func _build_outgoing() -> Dictionary:
	var result: Dictionary = {}
	for sid: String in scenes:
		result[sid] = []

	for sid: String in scenes:
		var scene: Dictionary = scenes[sid]
		var nxt: Variant = scene.get("next", null)
		if nxt != null and str(nxt) != "":
			(result[sid] as Array).append({"target": str(nxt)})
		for ch: Variant in (scene.get("choices", []) as Array):
			var cnxt: Variant = (ch as Dictionary).get("next", null)
			if cnxt != null and str(cnxt) != "":
				(result[sid] as Array).append({"target": str(cnxt)})

	# trigger_after_scene: scene B triggers after A → A has outgoing edge to B
	for sid: String in scenes:
		var src: Variant = scenes[sid].get("trigger_after_scene", null)
		if src == null:
			continue
		var src_id: String = str(src)
		if result.has(src_id):
			(result[src_id] as Array).append({"target": sid})

	# resume_after_flag: find which scene sets the flag, add edge setter → resume scene
	var flag_setters: Dictionary = {}
	for sid: String in scenes:
		for ch: Variant in (scenes[sid].get("choices", []) as Array):
			var f: Variant = (ch as Dictionary).get("flag", null)
			if f != null and not flag_setters.has(str(f)):
				flag_setters[str(f)] = sid
	for sid: String in scenes:
		var raf: Variant = scenes[sid].get("resume_after_flag", null)
		if raf == null:
			continue
		var setter: String = flag_setters.get(str(raf), "")
		if not setter.is_empty() and result.has(setter):
			(result[setter] as Array).append({"target": sid})

	return result


func _bfs_reachable(outgoing: Dictionary) -> Dictionary:
	var visited: Dictionary = {}
	if start_scene.is_empty() or not outgoing.has(start_scene):
		return visited
	var queue: Array[String] = [start_scene]
	while not queue.is_empty():
		var current: String = queue.pop_front()
		if visited.has(current):
			continue
		visited[current] = true
		for conn: Variant in outgoing.get(current, []):
			var target: String = str((conn as Dictionary).get("target", ""))
			if not target.is_empty() and not visited.has(target) and outgoing.has(target):
				queue.append(target)
	return visited


# DFS-based cycle detection. Returns an Array of cycles, each cycle being an Array[String] of scene IDs.
func _detect_cycles(outgoing: Dictionary) -> Array:
	var cycles:  Array      = []
	var visited: Dictionary = {}
	var on_stack: Dictionary = {}
	var path:    Array[String] = []
	for sid: String in outgoing:
		if not visited.has(sid):
			_dfs(sid, outgoing, visited, on_stack, path, cycles)
	return cycles


func _dfs(node: String, outgoing: Dictionary, visited: Dictionary, on_stack: Dictionary, path: Array[String], cycles: Array) -> void:
	visited[node]  = true
	on_stack[node] = true
	path.append(node)
	for conn: Variant in outgoing.get(node, []):
		var target: String = str((conn as Dictionary).get("target", ""))
		if target.is_empty() or not outgoing.has(target):
			continue
		if not visited.has(target):
			_dfs(target, outgoing, visited, on_stack, path, cycles)
		elif on_stack.has(target):
			var idx: int = path.find(target)
			if idx >= 0:
				var cycle: Array[String] = []
				for i in range(idx, path.size()):
					cycle.append(path[i])
				if not _cycle_already_found(cycles, cycle):
					cycles.append(cycle)
	path.pop_back()
	on_stack.erase(node)


func _cycle_already_found(cycles: Array, cycle: Array[String]) -> bool:
	for existing: Variant in cycles:
		var ex := existing as Array
		if ex.size() != cycle.size():
			continue
		var all_match := true
		for item: String in cycle:
			if not ex.has(item):
				all_match = false
				break
		if all_match:
			return true
	return false


func _count_words(text: Variant) -> int:
	if text is String:
		return (text as String).split(" ", false).size()
	if text is Array:
		var total := 0
		for elem: Variant in (text as Array):
			if elem is String:
				total += (elem as String).split(" ", false).size()
			elif elem is Dictionary:
				total += _count_words((elem as Dictionary).get("text", ""))
		return total
	return 0


func _collect_flag_uses(value: Variant, flags_used: Dictionary) -> void:
	if value == null:
		return
	if value is String:
		var s: String = value
		if not s.is_empty():
			flags_used[s] = true
	elif value is Array:
		for item: Variant in (value as Array):
			_collect_flag_uses(item, flags_used)
	elif value is Dictionary:
		var d: Dictionary = value
		if d.has("flag"):
			flags_used[str(d["flag"])] = true
		for op: String in ["and", "or"]:
			if d.has(op):
				_collect_flag_uses(d[op], flags_used)
		if d.has("not"):
			_collect_flag_uses(d["not"], flags_used)


# ---------------------------------------------------------------------------
# UI

func _build_ui(vbox: VBoxContainer, data: Dictionary) -> void:
	_add_overview_section(vbox, data)
	_add_accessibility_section(vbox, data)
	if not (data["unused_flags"] as Array).is_empty():
		_add_flags_section(vbox, data)
	if not (data["cycles"] as Array).is_empty():
		_add_cycles_section(vbox, data)
	_add_contacts_section(vbox, data)
	_add_duration_section(vbox, data)


func _make_section(parent: VBoxContainer, title: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.16, 0.20)
	style.corner_radius_top_left     = 4
	style.corner_radius_top_right    = 4
	style.corner_radius_bottom_left  = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left   = 10
	style.content_margin_right  = 10
	style.content_margin_top    = 6
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	panel.add_child(inner)

	var header := Label.new()
	header.text = title
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0))
	inner.add_child(header)

	return inner


func _add_stat(parent: VBoxContainer, label: String, value: String, value_color: Color = Color(0.9, 0.9, 0.9)) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = label
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	row.add_child(lbl)
	var val := Label.new()
	val.text = value
	val.add_theme_color_override("font_color", value_color)
	row.add_child(val)


func _add_scene_chips(parent: VBoxContainer, ids: Array) -> void:
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 4)
	flow.add_theme_constant_override("v_separation", 4)
	parent.add_child(flow)
	for sid: String in ids:
		var btn := Button.new()
		btn.text = sid
		btn.flat = true
		btn.add_theme_font_size_override("font_size", 11)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.tooltip_text = _t("Centrer sur cette scène", "Center on this scene")
		btn.pressed.connect(func() -> void:
			if focus_scene.is_valid():
				focus_scene.call(sid))
		flow.add_child(btn)


func _add_note(parent: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	parent.add_child(lbl)


func _add_overview_section(parent: VBoxContainer, data: Dictionary) -> void:
	var inner := _make_section(parent, _t("Vue d'ensemble", "Overview"))
	_add_stat(inner, _t("Scènes", "Scenes"),   str(data["scene_count"]))
	_add_stat(inner, _t("Messages", "Messages"), str(data["message_count"]))
	_add_stat(inner, _t("Choix", "Choices"),   str(data["choice_count"]))
	var dead_count: int = (data["dead_end_ids"] as Array).size()
	_add_stat(inner, _t("Fins", "Dead ends"),  str(dead_count))
	var unreach: int = (data["unreachable_ids"] as Array).size()
	var unreach_color: Color = Color(1.0, 0.65, 0.3) if unreach > 0 else Color(0.4, 0.9, 0.5)
	_add_stat(inner, _t("Scènes inaccessibles", "Unreachable scenes"), str(unreach), unreach_color)
	var cycle_count: int = (data["cycles"] as Array).size()
	if cycle_count > 0:
		_add_stat(inner, _t("Boucles détectées", "Loops detected"), str(cycle_count), Color(1.0, 0.65, 0.3))
	var unused_count: int = (data["unused_flags"] as Array).size()
	if unused_count > 0:
		_add_stat(inner, _t("Flags inutilisés", "Unused flags"), str(unused_count), Color(1.0, 0.65, 0.3))


func _add_accessibility_section(parent: VBoxContainer, data: Dictionary) -> void:
	var scene_count: int    = data["scene_count"]
	var reachable:   int    = data["reachable_count"]
	var pct:         int    = int(100.0 * reachable / max(scene_count, 1))
	var pct_color: Color    = Color(0.4, 0.9, 0.5) if pct >= 90 else (Color(1.0, 0.7, 0.3) if pct >= 70 else Color(1.0, 0.4, 0.4))
	var inner := _make_section(parent, _t("Accessibilité", "Accessibility"))
	_add_stat(inner,
		_t("Scènes accessibles depuis start_scene", "Scenes reachable from start_scene"),
		"%d / %d (%d %%)" % [reachable, scene_count, pct],
		pct_color)
	var unreachable: Array = data["unreachable_ids"]
	if unreachable.is_empty():
		return
	_add_note(inner, _t("Inaccessibles :", "Unreachable:"))
	_add_scene_chips(inner, unreachable)


func _add_flags_section(parent: VBoxContainer, data: Dictionary) -> void:
	var unused: Array = data["unused_flags"]
	var inner := _make_section(parent, "🚩 " + _t("Flags inutilisés (%d)" % unused.size(), "Unused flags (%d)" % unused.size()))
	_add_note(inner, _t(
		"Activés par des choix mais jamais vérifiés (requires_flag / condition / resume_after_flag).",
		"Set by choices but never checked (requires_flag / condition / resume_after_flag)."))
	for f: String in unused:
		var lbl := Label.new()
		lbl.text = "  " + f
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
		inner.add_child(lbl)


func _add_cycles_section(parent: VBoxContainer, data: Dictionary) -> void:
	var cycles: Array = data["cycles"]
	var inner := _make_section(parent, "⚠ " + _t("Boucles (%d)" % cycles.size(), "Loops (%d)" % cycles.size()))
	_add_note(inner, _t(
		"Ces scènes forment un circuit fermé — le joueur peut y rester indéfiniment si aucune condition n'en sort.",
		"These scenes form a closed loop — the player can stay there indefinitely if no condition breaks out."))
	for ci in range(cycles.size()):
		var cycle: Array = cycles[ci]
		var lbl := Label.new()
		lbl.text = _t("Boucle %d :" % (ci + 1), "Loop %d:" % (ci + 1))
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.65, 0.3))
		inner.add_child(lbl)
		_add_scene_chips(inner, cycle)


func _add_contacts_section(parent: VBoxContainer, data: Dictionary) -> void:
	var counts: Dictionary = data["contact_counts"]
	if counts.is_empty():
		return
	var inner  := _make_section(parent, _t("Personnages", "Characters"))
	var total: int = data["message_count"]
	var sorted: Array = counts.keys()
	sorted.sort_custom(func(a: Variant, b: Variant) -> bool:
		return int(counts[a]) > int(counts[b]))
	for cid: Variant in sorted:
		var count: int = counts[cid]
		var pct: int   = int(100.0 * count / max(total, 1))
		var name: String = str(cid) if str(cid) != "" else _t("(contact principal)", "(main contact)")
		_add_stat(inner, name, "%d msg  %d %%" % [count, pct])


func _add_duration_section(parent: VBoxContainer, data: Dictionary) -> void:
	var inner   := _make_section(parent, _t("Durée indicative", "Indicative duration"))
	var minutes: float = data["estimated_min"]
	var h: int  = int(minutes / 60)
	var m: int  = int(minutes) % 60
	var dur: String = "%dh%02d" % [h, m] if h > 0 else "%d min" % m
	_add_stat(inner, _t("Durée totale du contenu", "Total content duration"), "≈ " + dur)
	_add_stat(inner, _t("Mots (total)", "Words (total)"), str(data["word_count"]))
	_add_note(inner, _t(
		"Basé sur 200 mots/min — toutes les branches sont comptées, y compris celles jamais empruntées.",
		"Based on 200 words/min — all branches included, even those never taken."))


func _t(fr: String, en: String) -> String:
	return fr if ui_locale == "fr" else en
