extends Node

const SaveManagerScript = preload("res://scripts/autoloads/save_manager.gd")
const Assert = preload("res://tools/tests/test_assertions.gd")
const SafeFile = preload("res://scripts/lib/safe_file.gd")


func run_tests() -> Array:
	var results: Array = []
	var manager = SaveManagerScript.new()
	manager.save_path = "user://save-test-%s.json" % str(Time.get_ticks_usec())
	_cleanup(manager.save_path)

	Assert.equal(results, "save: missing file loads empty state", manager.load_save(), {})
	Assert.check(results, "save: missing file is reported absent", not manager.has_save())

	var first_state: Dictionary = {
		"scene": "scene_4",
		"flags": {"seen": true},
		"history": [{"text": "hello", "out": false}],
		"score": 3
	}
	manager.save(first_state)
	Assert.check(results, "save: saved file exists", manager.has_save())
	var loaded_first: Dictionary = manager.load_save()
	Assert.equal(results, "save: nested scene round trip", loaded_first.get("scene"), "scene_4")
	Assert.equal(results, "save: nested flags round trip", loaded_first.get("flags"), {"seen": true})
	Assert.equal(results, "save: nested history round trip", loaded_first.get("history"), [{"text": "hello", "out": false}])
	Assert.equal(results, "save: numeric value survives JSON round trip", loaded_first.get("score"), 3.0)
	Assert.check(results, "save: temporary file is finalized", not FileAccess.file_exists(manager.save_path + ".tmp"))

	var replacement: Dictionary = {"scene": "scene_5", "score": 8}
	manager.save(replacement)
	var loaded_replacement: Dictionary = manager.load_save()
	Assert.equal(results, "save: existing save scene is replaced", loaded_replacement.get("scene"), "scene_5")
	Assert.equal(results, "save: existing save numeric value is replaced", loaded_replacement.get("score"), 8.0)

	_write_text(manager.save_path, "{broken")
	var recovered: Dictionary = manager.load_save(false)
	Assert.equal(results, "save recovery: corrupted primary restores previous scene", recovered.get("scene"), "scene_4")
	Assert.check(results, "save recovery: primary is repaired", SafeFile.read_json(manager.save_path).get("ok", false))

	_cleanup(manager.save_path)
	_write_text(manager.save_path, "{broken")
	Assert.equal(results, "save: corrupted JSON without backup is ignored", manager.load_save(false), {})
	_write_text(manager.save_path, "[]")
	Assert.equal(results, "save: non-object JSON without backup is ignored", manager.load_save(false), {})

	manager.delete_save()
	Assert.check(results, "save: delete removes save", not manager.has_save())
	Assert.equal(results, "save: delete is idempotent", manager.load_save(), {})
	_cleanup(manager.save_path)
	manager.free()
	return results


func _write_text(path: String, content: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()


func _cleanup(path: String) -> void:
	SafeFile.delete_with_recovery_files(path)
