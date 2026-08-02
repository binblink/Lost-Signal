extends Node

# Headless validation runner — prints DialogueLoader validation report
# Exits with code 1 if any errors found, 0 otherwise.

func _ready() -> void:
    var report: Dictionary = DialogueLoader.get_validation_report()
    var errors: Array = report.get("errors", [])
    var warnings: Array = report.get("warnings", [])

    print("Dialogue validation: %d error(s), %d warning(s)" % [errors.size(), warnings.size()])

    if errors.size() > 0:
        for e in errors:
            printerr("ERROR: %s" % e)
        # Non-zero exit to fail CI
        get_tree().quit(1)
        return

    # Print warnings but don't fail
    for w in warnings:
        print("WARNING: %s" % w)

    print("Validation OK — no errors.")
    get_tree().quit(0)
