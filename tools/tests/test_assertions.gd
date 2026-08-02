extends RefCounted


static func check(results: Array, name: String, ok: bool, details: String = "") -> void:
	results.append({"name": name, "ok": ok, "details": details})


static func equal(results: Array, name: String, actual: Variant, expected: Variant) -> void:
	check(
		results,
		name,
		actual == expected,
		"expected %s, got %s" % [str(expected), str(actual)]
	)
