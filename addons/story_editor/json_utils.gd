extends RefCounted


static func compact(value: Variant) -> String:
	if value is Dictionary:
		if (value as Dictionary).is_empty():
			return "{}"
		var parts: Array[String] = []
		for key: Variant in value:
			parts.append(JSON.stringify(str(key)) + ": " + compact(value[key]))
		return "{" + ", ".join(parts) + "}"
	if value is Array:
		if (value as Array).is_empty():
			return "[]"
		var parts: Array[String] = []
		for item: Variant in value:
			parts.append(compact(item))
		return "[" + ", ".join(parts) + "]"
	return JSON.stringify(value)


# Expands top-level structure for readability, then falls back to compact past depth 4.
static func expand(value: Variant, indent: String) -> String:
	if indent.length() >= 4:
		return compact(value)
	if value is Dictionary:
		if (value as Dictionary).is_empty():
			return "{}"
		var next_indent: String = indent + "\t"
		var parts: Array[String] = []
		for key: Variant in value:
			parts.append(next_indent + JSON.stringify(str(key)) + ": " + expand(value[key], next_indent))
		return "{\n" + ",\n".join(parts) + "\n" + indent + "}"
	if value is Array:
		if (value as Array).is_empty():
			return "[]"
		var next_indent: String = indent + "\t"
		var parts: Array[String] = []
		for item: Variant in value:
			parts.append(next_indent + expand(item, next_indent))
		return "[\n" + ",\n".join(parts) + "\n" + indent + "]"
	return JSON.stringify(value)
