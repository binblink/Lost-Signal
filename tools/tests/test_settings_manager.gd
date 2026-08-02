extends Node

const SettingsManagerScript = preload("res://scripts/autoloads/settings_manager.gd")
const Assert = preload("res://tools/tests/test_assertions.gd")


func run_tests() -> Array:
	var results: Array = []
	var path: String = "user://settings-test-%s.json" % str(Time.get_ticks_usec())
	_cleanup(path)

	var manager = SettingsManagerScript.new()
	manager.settings_path = path
	_write_json(path, {"language": "fr", "volume": 0.4, "music_volume": 0.6, "resolution": 2, "window_mode": 1})
	manager._load()
	Assert.equal(results, "settings: language loads", manager.language, "fr")
	Assert.equal(results, "settings: master volume loads", manager.volume, 0.4)
	Assert.equal(results, "settings: music volume loads", manager.music_volume, 0.6)
	Assert.equal(results, "settings: resolution loads", manager.resolution, 2)
	Assert.equal(results, "settings: window mode loads", manager.window_mode, 1)

	manager.language = "en"
	manager.volume = 0.25
	manager.music_volume = 0.75
	manager.resolution = 4
	manager.window_mode = 2
	manager._save()
	var saved: Dictionary = _read_json(path)
	Assert.equal(results, "settings: save persists language", saved.get("language"), "en")
	Assert.equal(results, "settings: save persists volumes", [saved.get("volume"), saved.get("music_volume")], [0.25, 0.75])
	Assert.equal(results, "settings: save persists display selection", [saved.get("resolution"), saved.get("window_mode")], [4.0, 2.0])

	_write_json(path, {"display_mode": 2})
	manager._load()
	Assert.equal(results, "settings migration: legacy display mode maps resolution", manager.resolution, 3)
	Assert.equal(results, "settings migration: legacy display mode maps fullscreen", manager.window_mode, 1)

	_write_json(path, {"fullscreen": false})
	manager._load()
	Assert.equal(results, "settings migration: legacy fullscreen false maps windowed", manager.window_mode, 0)
	_write_json(path, {"fullscreen": true})
	manager._load()
	Assert.equal(results, "settings migration: legacy fullscreen true maps fullscreen", manager.window_mode, 1)

	_write_json(path, {"muted": true})
	manager._load()
	Assert.equal(results, "settings migration: legacy muted true maps zero volume", manager.volume, 0.0)
	_write_json(path, {"muted": false})
	manager._load()
	Assert.equal(results, "settings migration: legacy muted false maps full volume", manager.volume, 1.0)

	manager.language = "fr"
	_write_text(path, "{broken")
	manager._load()
	Assert.equal(results, "settings: malformed JSON does not overwrite current values", manager.language, "fr")

	_cleanup(path)
	manager._load()
	Assert.check(results, "settings: missing file selects a supported language", manager.language in manager.SUPPORTED_LANGUAGES)
	manager.free()
	_cleanup(path)
	return results


func _write_json(path: String, data: Dictionary) -> void:
	_write_text(path, JSON.stringify(data))


func _write_text(path: String, content: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()


func _read_json(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	file.close()
	return data


func _cleanup(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
