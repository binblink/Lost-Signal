extends SceneTree

func _init() -> void:
    call_deferred("_run_tests")

func _run_tests() -> void:
    var all_ok: bool = true

    # DialogueLoader is initialized as an autoload before this script runs.
    # Include its validation result so this single command covers both the
    # story data and the unit tests.
    var dialogue_loader: Node = get_root().get_node_or_null("DialogueLoader")
    if dialogue_loader == null:
        printerr("[FAIL] dialogue validation: DialogueLoader autoload not found")
        all_ok = false
    else:
        var report: Dictionary = dialogue_loader.call("get_validation_report")
        var validation_errors: Array = report.get("errors", [])
        if validation_errors.is_empty():
            print("[OK] dialogue validation")
        else:
            for validation_error in validation_errors:
                printerr("[FAIL] dialogue validation: %s" % validation_error)
            all_ok = false

    var suites: Array = [
        load("res://tools/tests/test_condition_evaluator.gd"),
        load("res://tools/tests/test_effect_executor.gd"),
        load("res://tools/tests/test_narrative_controller.gd"),
        load("res://tools/tests/test_dialogue_loader.gd"),
        load("res://tools/tests/test_save_manager.gd"),
        load("res://tools/tests/test_settings_manager.gd"),
        load("res://tools/tests/test_json_utils.gd"),
        load("res://tools/tests/test_scene_parser.gd"),
        load("res://tools/tests/test_analysis_panel.gd"),
        load("res://tools/tests/test_ui_components.gd"),
    ]

    for s in suites:
        if s == null:
            printerr("[FAIL] test suite could not be loaded")
            all_ok = false
            continue
        var inst: Node = s.new() as Node
        get_root().add_child(inst)
        var results: Array = await inst.run_tests()
        for r in results:
            if r["ok"]:
                print("[OK] %s" % r["name"])
            else:
                var details: String = str(r.get("details", ""))
                var suffix: String = " — " + details if not details.is_empty() else ""
                printerr("[FAIL] %s%s" % [r["name"], suffix])
                all_ok = false
        inst.queue_free()

    if not all_ok:
        printerr("Some tests failed.")
        quit(1)
        return

    print("All tests passed.")
    quit(0)
