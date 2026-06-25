@tool
extends EditorPlugin

var _panel: Control


func _enter_tree() -> void:
	_panel = preload("res://addons/story_editor/StoryEditorPanel.tscn").instantiate()
	_panel.undo_redo_manager = get_undo_redo()
	add_control_to_bottom_panel(_panel, "Story Editor")


func _exit_tree() -> void:
	if _panel:
		remove_control_from_bottom_panel(_panel)
		_panel.queue_free()
		_panel = null
