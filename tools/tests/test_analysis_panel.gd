extends Node

const AnalysisPanel = preload("res://addons/story_editor/AnalysisPanel.gd")
const Assert = preload("res://tools/tests/test_assertions.gd")


func run_tests() -> Array:
	var results: Array = []
	var panel = AnalysisPanel.new()
	panel.start_scene = "start"
	panel.scenes = {
		"start": {
			"id": "start",
			"contact_id": "main",
			"messages_in": [{"text": ["one two", {"text": "three four"}]}],
			"next": "branch",
			"choices": [
				{"text": "Loop", "next": "loop", "flag": "used_flag"},
				{"text": "Stay", "flag": "unused_flag"}
			]
		},
		"loop": {"id": "loop", "contact_id": "main", "messages_in": [{"text": "five"}], "next": "start"},
		"branch": {"id": "branch", "contact_id": "main", "messages_in": []},
		"triggered": {"id": "triggered", "contact_id": "other", "messages_in": [], "trigger_after_scene": "branch"},
		"resumed": {
			"id": "resumed",
			"contact_id": "main",
			"messages_in": [{"text": "six seven", "condition": {"and": [{"flag": "used_flag"}, {"not": {"flag": "other_flag"}}]}}],
			"resume_after_flag": "used_flag"
		},
		"orphan": {"id": "orphan", "contact_id": "other", "messages_in": [{"text": ""}]}
	}

	var outgoing: Dictionary = panel._build_outgoing()
	Assert.check(results, "analysis graph: direct next edge", _has_target(outgoing["start"], "branch"))
	Assert.check(results, "analysis graph: choice edge", _has_target(outgoing["start"], "loop"))
	Assert.check(results, "analysis graph: trigger edge", _has_target(outgoing["branch"], "triggered"))
	Assert.check(results, "analysis graph: resume flag edge", _has_target(outgoing["start"], "resumed"))

	var reachable: Dictionary = panel._bfs_reachable(outgoing)
	Assert.equal(results, "analysis reachability: all connected scenes visited", reachable.size(), 5)
	Assert.check(results, "analysis reachability: orphan excluded", not reachable.has("orphan"))
	Assert.equal(results, "analysis reachability: missing start visits nothing", panel._bfs_reachable({}), {})

	var cycles: Array = panel._detect_cycles(outgoing)
	Assert.equal(results, "analysis cycles: one cycle detected", cycles.size(), 1)
	Assert.check(results, "analysis cycles: cycle contains both nodes", (cycles[0] as Array).has("start") and (cycles[0] as Array).has("loop"))
	Assert.check(results, "analysis cycles: rotated duplicate recognized", panel._cycle_already_found([["start", "loop"]], ["loop", "start"]))

	Assert.equal(results, "analysis words: repeated spaces ignored", panel._count_words("  one   two  "), 2)
	Assert.equal(results, "analysis words: arrays and message dictionaries", panel._count_words(["one two", {"text": "three"}, 4]), 3)
	var used_flags: Dictionary = {}
	panel._collect_flag_uses({"or": [{"flag": "a"}, {"not": {"flag": "b"}}]}, used_flags)
	panel._collect_flag_uses(["c", ""], used_flags)
	Assert.equal(results, "analysis flags: nested uses collected", used_flags.keys(), ["a", "b", "c"])

	var data: Dictionary = panel._run_analysis()
	Assert.equal(results, "analysis summary: scene count", data.get("scene_count"), 6)
	Assert.equal(results, "analysis summary: message count", data.get("message_count"), 4)
	Assert.equal(results, "analysis summary: choice count", data.get("choice_count"), 2)
	Assert.equal(results, "analysis summary: word count", data.get("word_count"), 7)
	Assert.equal(results, "analysis summary: reachable count", data.get("reachable_count"), 5)
	Assert.equal(results, "analysis summary: unreachable scenes", data.get("unreachable_ids"), ["orphan"])
	Assert.equal(results, "analysis summary: unused flags", data.get("unused_flags"), ["unused_flag"])
	Assert.check(results, "analysis summary: dead ends identified", _same_members(data.get("dead_end_ids", []), ["triggered", "resumed", "orphan"]))
	Assert.equal(results, "analysis summary: messages counted per contact", data.get("contact_counts"), {"main": 3, "other": 1})
	Assert.equal(results, "analysis summary: reading time estimate", data.get("estimated_min"), 7 / 200.0)
	panel.free()
	return results


func _has_target(connections: Array, target: String) -> bool:
	for connection: Dictionary in connections:
		if connection.get("target") == target:
			return true
	return false


func _same_members(actual: Array, expected: Array) -> bool:
	if actual.size() != expected.size():
		return false
	for item: Variant in expected:
		if item not in actual:
			return false
	return true
