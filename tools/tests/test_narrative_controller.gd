extends Node

const NarrativeController = preload("res://scripts/narrative_controller.gd")
const Assert = preload("res://tools/tests/test_assertions.gd")


func run_tests() -> Array:
	var results: Array = []
	_test_conditions_and_helpers(results)
	_test_state_round_trip(results)
	_test_secondary_scene(results)
	_test_choice_bounds(results)
	await _test_deferred_scheduled_and_end_transitions(results)
	return results


func _test_conditions_and_helpers(results: Array) -> void:
	var nc: Node = NarrativeController.new()
	nc.flags = {"seen": true}
	nc.vars = {"score": 7, "player": "Alex"}
	Assert.check(results, "narrative condition: flag and variable pass", nc._eval_condition({"requires_flag": "seen", "condition": {"var": "score", "op": "gte", "value": 7}}))
	Assert.check(results, "narrative condition: missing required flag fails", not nc._eval_condition({"requires_flag": ["seen", "missing"]}))
	var choices: Array = [
		{"text": "flag", "requires_flag": "seen"},
		{"text": "variable", "condition": {"var": "score", "op": "gt", "value": 5}},
		{"text": "hidden", "requires_flag": "missing"}
	]
	Assert.equal(results, "narrative choices: conditions filter visible choices", nc._filter_choices(choices).map(func(choice): return choice["text"]), ["flag", "variable"])
	Assert.equal(results, "narrative template: variables are substituted", nc._apply_templates("Hi {player}, score {score}"), "Hi Alex, score 7")
	nc.vars = {}
	Assert.equal(results, "narrative template: no variables leaves text untouched", nc._apply_templates("Hi {player}"), "Hi {player}")
	Assert.equal(results, "delay: integer seconds", nc._parse_delay(12), 12.0)
	Assert.equal(results, "delay: float seconds", nc._parse_delay(1.5), 1.5)
	Assert.equal(results, "delay: seconds suffix", nc._parse_delay("8s"), 8.0)
	Assert.equal(results, "delay: minutes suffix", nc._parse_delay("2m"), 120.0)
	Assert.equal(results, "delay: hours suffix", nc._parse_delay("1.5h"), 5400.0)
	Assert.equal(results, "delay: numeric string", nc._parse_delay("30"), 30.0)
	Assert.equal(results, "delay: unsupported type defaults zero", nc._parse_delay({}), 0.0)
	nc.free()


func _test_state_round_trip(results: Array) -> void:
	var source: Node = NarrativeController.new()
	source.current_scene = {"id": "scene_saved"}
	source.current_message_index = 4
	source.waiting_for_choice = true
	source.flags = {"seen": true}
	source.vars = {"score": 9}
	source.contact_names = {"maeve": {"fr": "Maeve", "en": "Maeve"}}
	source.contact_statuses = {"maeve": "offline"}
	source.deferred_scenes = {"ready": "scene_later"}
	source.contact_histories = {"maeve": [{"text": "hello", "out": false}]}
	source.played_secondary_scenes = ["secondary"]
	source.pending_choices = {"mom": "mom_choice"}
	source.current_music_path = ""
	source.scheduled_scenes = {}
	source.active_contact_id = "mom"
	var state: Dictionary = source.get_state()

	var restored: Node = NarrativeController.new()
	restored.set_state(state)
	Assert.equal(results, "state: message index round trip", restored.current_message_index, 4)
	Assert.equal(results, "state: waiting choice round trip", restored.waiting_for_choice, true)
	Assert.equal(results, "state: flags round trip", restored.flags, {"seen": true})
	Assert.equal(results, "state: variables round trip", restored.vars, {"score": 9})
	Assert.equal(results, "state: names round trip", restored.contact_names, source.contact_names)
	Assert.equal(results, "state: statuses round trip", restored.contact_statuses, source.contact_statuses)
	Assert.equal(results, "state: deferred scenes round trip", restored.deferred_scenes, source.deferred_scenes)
	Assert.equal(results, "state: histories round trip", restored.contact_histories, source.contact_histories)
	Assert.equal(results, "state: played secondary scenes round trip", restored.played_secondary_scenes, ["secondary"])
	Assert.equal(results, "state: pending choices round trip", restored.pending_choices, source.pending_choices)
	Assert.equal(results, "state: active contact round trip", restored.active_contact_id, "mom")
	Assert.equal(results, "state: serialized scene id", state.get("current_scene_id"), "scene_saved")

	var legacy: Node = NarrativeController.new()
	legacy.set_state({"messages": {"maeve": [{"text": "legacy"}]}})
	Assert.equal(results, "state: legacy messages key is migrated", legacy.contact_histories, {"maeve": [{"text": "legacy"}]})

	source.free()
	restored.free()
	legacy.free()


func _test_secondary_scene(results: Array) -> void:
	var nc: Node = NarrativeController.new()
	nc.active_contact_id = "maeve"
	nc.current_scene = {"id": "main_scene"}
	nc.flags = {"show": true}
	nc.vars = {"count": 0}
	var received_contacts: Array = []
	nc.secondary_scene_received.connect(func(cid: String) -> void: received_contacts.append(cid))
	var scene: Dictionary = {
		"id": "secondary_scene",
		"contact_id": "mom",
		"messages_in": [
			{"text": "visible", "time": "10:00", "effects": [{"op": "add", "var": "count", "value": 1}]},
			{"text": "hidden", "requires_flag": "missing"},
			{"corrupted": true, "time": "10:01"},
			{"media": {"type": "image", "path": "res://image.png"}, "time": "10:02"}
		],
		"choices": [{"text": "Reply"}]
	}
	nc._play_secondary_scene(scene)
	Assert.equal(results, "secondary scene: current main scene is preserved", nc.current_scene.get("id"), "main_scene")
	Assert.equal(results, "secondary scene: visible history entries only", nc.contact_histories.get("mom", []).size(), 3)
	Assert.equal(results, "secondary scene: text entry stored", nc.contact_histories["mom"][0].get("text"), "visible")
	Assert.equal(results, "secondary scene: corrupted entry stored", nc.contact_histories["mom"][1].get("corrupted"), true)
	Assert.equal(results, "secondary scene: media entry stored", nc.contact_histories["mom"][2].get("media", {}).get("type"), "image")
	Assert.equal(results, "secondary scene: message effects run", nc.vars.get("count"), 1)
	Assert.equal(results, "secondary scene: pending choice registered", nc.pending_choices.get("mom"), "secondary_scene")
	Assert.equal(results, "secondary scene: notification emitted", received_contacts, ["mom"])
	nc._play_secondary_scene(scene)
	Assert.equal(results, "secondary scene: replay is idempotent", nc.contact_histories["mom"].size(), 3)
	Assert.equal(results, "secondary scene: replay emits no duplicate notification", received_contacts, ["mom"])
	nc.free()


func _test_choice_bounds(results: Array) -> void:
	var nc: Node = NarrativeController.new()
	nc._visible_choices = [{"text": "Only choice", "flag": "selected"}]
	nc.handle_choice(-1)
	Assert.check(results, "choice: negative index is ignored", not nc.flags.has("selected"))
	nc.handle_choice(1)
	Assert.check(results, "choice: out-of-range index is ignored", not nc.flags.has("selected"))
	nc.free()


func _test_deferred_scheduled_and_end_transitions(results: Array) -> void:
	var loader: Node = get_tree().root.get_node("DialogueLoader")
	var original_scenes: Dictionary = loader.get("_scenes")
	var original_triggers: Dictionary = loader.get("_triggers")
	var original_contacts: Array = loader.get("_contacts")
	var now: int = int(Time.get_unix_time_from_system())
	var fixture_scenes: Dictionary = {
		"opened_scene": {"id": "opened_scene", "contact_id": "mom", "messages_in": [{"text": "opened"}]},
		"overdue_scene": {"id": "overdue_scene", "contact_id": "mom", "messages_in": [{"text": "overdue"}]},
		"timer_scene": {"id": "timer_scene", "contact_id": "mom", "messages_in": [{"text": "timer"}]},
		"end_scene": {"id": "end_scene", "contact_id": "main", "messages_in": [], "end": true}
	}
	loader.set("_scenes", fixture_scenes)
	loader.set("_triggers", {})
	loader.set("_contacts", [{"id": "main", "is_main": true}, {"id": "mom"}])

	var nc = NarrativeController.new()
	add_child(nc)
	nc.active_contact_id = "main"
	var save_events: Array = []
	var end_events: Array = []
	nc.save_requested.connect(func(notify_panel: bool) -> void: save_events.append(notify_panel))
	nc.game_ended.connect(func() -> void: end_events.append(true))

	nc.deferred_scenes = {"opened_mom": "opened_scene"}
	await nc.notify_contact_opened("mom")
	Assert.check(results, "deferred scene: opened flag consumes deferred scene", not nc.deferred_scenes.has("opened_mom"))
	Assert.check(results, "deferred scene: opened flag remains transient", not nc.flags.has("opened_mom"))
	Assert.equal(results, "deferred scene: opened scene is played", nc.contact_histories.get("mom", [])[0].get("text"), "opened")

	nc.scheduled_scenes = {"overdue_scene": now - 1}
	await nc.resume_overdue_scenes()
	Assert.check(results, "scheduled scene: overdue entry is consumed", not nc.scheduled_scenes.has("overdue_scene"))
	Assert.equal(results, "scheduled scene: overdue scene is played", nc.contact_histories.get("mom", [])[1].get("text"), "overdue")
	Assert.equal(results, "scheduled scene: overdue resume requests persistence", save_events.back(), false)

	nc.scheduled_scenes = {"timer_scene": now + 10}
	nc._schedule_timer("timer_scene", 0.01)
	await get_tree().create_timer(0.05).timeout
	Assert.check(results, "scheduled scene: timer entry is consumed", not nc.scheduled_scenes.has("timer_scene"))
	Assert.equal(results, "scheduled scene: timer plays scene", nc.contact_histories.get("mom", [])[2].get("text"), "timer")

	nc._trigger_next_scenes("end_scene")
	Assert.equal(results, "end scene: game end signal emitted", end_events, [true])

	nc.queue_free()
	loader.set("_scenes", original_scenes)
	loader.set("_triggers", original_triggers)
	loader.set("_contacts", original_contacts)
