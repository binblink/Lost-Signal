extends Node

const NarrativeController = preload("res://scripts/narrative_controller.gd")
const Assert = preload("res://tools/tests/test_assertions.gd")


func run_tests() -> Array:
	var results: Array = []
	var nc: Node = NarrativeController.new()
	var renamed_events: Array = []
	var status_events: Array = []
	nc.contact_renamed.connect(func(cid: String, display_name: String) -> void: renamed_events.append([cid, display_name]))
	nc.contact_status_changed.connect(func(cid: String, status: String) -> void: status_events.append([cid, status]))

	nc._run_effects([{"op": "set", "var": "score", "value": 10}])
	Assert.equal(results, "effect: set variable", nc.vars.get("score"), 10)
	nc._run_effects([{"op": "add", "var": "score", "value": 5}])
	Assert.equal(results, "effect: add variable", nc.vars.get("score"), 15)
	nc._run_effects([{"op": "sub", "var": "score", "value": 3}])
	Assert.equal(results, "effect: subtract variable", nc.vars.get("score"), 12)
	nc._run_effects([{"op": "add", "var": "new_value", "value": 4}])
	Assert.equal(results, "effect: add defaults missing variable to zero", nc.vars.get("new_value"), 4)
	nc._run_effects([{"op": "sub", "var": "other_value", "value": 2}])
	Assert.equal(results, "effect: subtract defaults missing variable to zero", nc.vars.get("other_value"), -2)

	nc._run_effects([{"op": "rename", "contact": "maeve", "value": "Maeve"}])
	Assert.equal(results, "effect: rename with string", nc.contact_names.get("maeve"), "Maeve")
	Assert.equal(results, "effect: rename emits display name", renamed_events.back(), ["maeve", "Maeve"])
	nc._run_effects([{"op": "rename", "contact": "maeve", "value": {"fr": "Maeve FR", "en": "Maeve EN"}}])
	Assert.equal(results, "effect: rename with localized dictionary", nc.contact_names.get("maeve", {}).get("fr"), "Maeve FR")
	Assert.equal(results, "effect: empty rename is ignored", renamed_events.size(), 2)
	nc._run_effects([{"op": "rename", "contact": "", "value": "Nobody"}, {"op": "rename", "contact": "mom", "value": ""}])
	Assert.check(results, "effect: invalid rename does not create contacts", not nc.contact_names.has("") and not nc.contact_names.has("mom"))

	nc._run_effects([{"op": "set_status", "contact": "maeve", "value": "offline"}])
	Assert.equal(results, "effect: set contact status", nc.contact_statuses.get("maeve"), "offline")
	Assert.equal(results, "effect: status emits signal", status_events.back(), ["maeve", "offline"])
	nc._run_effects([{"op": "set_status", "contact": "mom"}])
	Assert.equal(results, "effect: missing status defaults online", nc.contact_statuses.get("mom"), "online")
	nc._run_effects([{"op": "set_status", "contact": "", "value": "offline"}])
	Assert.equal(results, "effect: empty status contact is ignored", status_events.size(), 2)

	nc.deferred_scenes = {"ready": "later"}
	nc._apply_effects({"flag": "ready", "effects": [{"op": "set", "var": "done", "value": true}]})
	Assert.equal(results, "choice effects: flag is set", nc.flags.get("ready"), true)
	Assert.equal(results, "choice effects: deferred scene is queued", nc._pending_resumes, ["later"])
	Assert.check(results, "choice effects: deferred entry is consumed", not nc.deferred_scenes.has("ready"))
	Assert.equal(results, "choice effects: regular effects also run", nc.vars.get("done"), true)

	nc.free()
	return results
