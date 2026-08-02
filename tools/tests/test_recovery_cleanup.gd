extends Node

const StorySettingsPanel = preload("res://addons/story_editor/StorySettingsPanel.gd")
const SafeFile = preload("res://scripts/lib/safe_file.gd")
const Assert = preload("res://tools/tests/test_assertions.gd")


func run_tests() -> Array:
	var results: Array = []
	var panel = StorySettingsPanel.new()
	Assert.equal(results, "recovery cleanup: primary path is resolved from first backup", panel._primary_path_for_backup("res://story.json.bak"), "res://story.json")
	Assert.equal(results, "recovery cleanup: primary path is resolved from rotated backup", panel._primary_path_for_backup("res://story.json.bak.3"), "res://story.json")
	Assert.equal(results, "recovery cleanup: removed archive is classified before backup suffix", panel._recovery_file_kind("story.json.bak.removed.123"), "removed")
	Assert.equal(results, "recovery cleanup: interrupted temporary file is excluded", panel._recovery_file_kind("story.json.tmp"), "")
	Assert.equal(results, "recovery cleanup: corrupt quarantine is excluded", panel._recovery_file_kind("story.json.corrupt.123"), "")
	_run_isolated_cleanup_test(panel, results)
	panel.free()
	return results


func _run_isolated_cleanup_test(panel, results: Array) -> void:
	var token := str(Time.get_ticks_usec())
	var root := "user://recovery-cleanup-test-" + token
	var excluded_dir := root.path_join(".godot")
	var primary := root.path_join("story.json")
	var first_backup := primary + ".bak"
	var second_backup := primary + ".bak.2"
	var orphan_backup := root.path_join("missing.json.bak")
	var invalid_primary := root.path_join("broken.json")
	var invalid_backup := invalid_primary + ".bak"
	var removed_archive := root.path_join("dialogue.es.json.removed.123")
	var temp_file := root.path_join("story.json.tmp")
	var corrupt_file := root.path_join("story.json.corrupt.123")
	var excluded_backup := excluded_dir.path_join("ignored.json.bak")
	var root_absolute := ProjectSettings.globalize_path(root)
	var excluded_absolute := ProjectSettings.globalize_path(excluded_dir)
	Assert.equal(results, "recovery cleanup: isolated directory is created", DirAccess.make_dir_recursive_absolute(excluded_absolute), OK)

	SafeFile.write_json(primary, {"version": 1}, "\t", true)
	SafeFile.write_json(primary, {"version": 2}, "\t", true)
	SafeFile.write_json(primary, {"version": 3}, "\t", true)
	SafeFile.write_text(orphan_backup, "orphan")
	SafeFile.write_text(invalid_primary, "{broken")
	SafeFile.write_text(invalid_backup, "{\"recovered\":true}")
	SafeFile.write_text(removed_archive, "removed")
	SafeFile.write_text(temp_file, "temporary")
	SafeFile.write_text(corrupt_file, "corrupt")
	SafeFile.write_text(excluded_backup, "excluded")

	panel.recovery_root_path = root
	var plan: Dictionary = panel._build_recovery_cleanup_plan(true, true)
	var entries: Array = plan.get("entries", [])
	Assert.equal(results, "recovery cleanup: scan includes backups, archive, and protected recoveries", entries.size(), 5)
	var by_path: Dictionary = {}
	for entry: Dictionary in entries:
		by_path[entry["path"]] = entry
	Assert.check(results, "recovery cleanup: current primary makes first backup selectable", by_path.has(first_backup) and not by_path[first_backup]["protected"])
	Assert.check(results, "recovery cleanup: rotated backup is selectable", by_path.has(second_backup) and not by_path[second_backup]["protected"])
	Assert.check(results, "recovery cleanup: removed archive is selectable", by_path.has(removed_archive) and not by_path[removed_archive]["protected"])
	Assert.check(results, "recovery cleanup: orphan backup is protected", by_path.has(orphan_backup) and by_path[orphan_backup]["protected"])
	Assert.check(results, "recovery cleanup: backup of invalid primary is protected", by_path.has(invalid_backup) and by_path[invalid_backup]["protected"])
	Assert.check(results, "recovery cleanup: excluded directory is not scanned", not by_path.has(excluded_backup))
	Assert.check(results, "recovery cleanup: temporary transaction is not scanned", not by_path.has(temp_file))
	Assert.check(results, "recovery cleanup: corrupt quarantine is not scanned", not by_path.has(corrupt_file))

	var backups_only: Dictionary = panel._build_recovery_cleanup_plan(true, false)
	Assert.equal(results, "recovery cleanup: category filter excludes removed archives", (backups_only.get("entries", []) as Array).size(), 4)
	var removed_only: Dictionary = panel._build_recovery_cleanup_plan(false, true)
	Assert.equal(results, "recovery cleanup: category filter can target archives only", (removed_only.get("entries", []) as Array).size(), 1)

	var selected_paths: Array[String] = [first_backup, second_backup, removed_archive]
	var cleanup: Dictionary = panel._apply_recovery_cleanup(selected_paths)
	Assert.check(results, "recovery cleanup: selected recoveries are deleted", cleanup.get("ok", false), cleanup.get("error", ""))
	Assert.equal(results, "recovery cleanup: deleted file count is reported", (cleanup.get("deleted_paths", []) as Array).size(), 3)
	Assert.check(results, "recovery cleanup: primary file remains intact", FileAccess.file_exists(primary))
	Assert.check(results, "recovery cleanup: orphan backup remains intact", FileAccess.file_exists(orphan_backup))

	var refused_paths: Array[String] = [orphan_backup]
	var refused: Dictionary = panel._apply_recovery_cleanup(refused_paths)
	Assert.check(results, "recovery cleanup: protected orphan cannot be forced through API", not refused.get("ok", false))
	Assert.check(results, "recovery cleanup: refused orphan is not deleted", FileAccess.file_exists(orphan_backup))

	for path: String in [primary, orphan_backup, invalid_primary, invalid_backup, temp_file, corrupt_file, excluded_backup]:
		SafeFile.delete_with_recovery_files(path)
	DirAccess.remove_absolute(excluded_absolute)
	DirAccess.remove_absolute(root_absolute)
