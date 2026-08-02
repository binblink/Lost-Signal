extends Node
class_name ConditionEvaluator

# Static, pure evaluator for condition trees used by the narrative engine.
# Methods accept `flags` and `vars` dictionaries so they are fully testable.


static func evaluate_node(cond: Dictionary, flags: Dictionary, vars: Dictionary, log_warnings: bool = true) -> bool:
	if cond == null:
		return true
	if cond.has("and"):
		for sub in cond["and"]:
			if not evaluate_node(sub, flags, vars, log_warnings):
				return false
		return true
	if cond.has("or"):
		for sub in cond["or"]:
			if evaluate_node(sub, flags, vars, log_warnings):
				return true
		return false
	if cond.has("not"):
		return not evaluate_node(cond["not"], flags, vars, log_warnings)
	if cond.has("flag"):
		return flags.get(cond["flag"], false)
	if cond.has("var"):
		var val = vars.get(cond["var"], 0)
		var target = cond["value"]
		match cond.get("op", ""):
			"eq":  return val == target
			"neq": return val != target
			"gt":  return val > target
			"gte": return val >= target
			"lt":  return val < target
			"lte": return val <= target
		if log_warnings:
			push_warning("ConditionEvaluator: unknown op '%s'" % str(cond.get("op", "")))
		return false
	if log_warnings:
		push_warning("ConditionEvaluator: malformed condition: %s" % str(cond))
	return false


static func evaluate_message(msg: Dictionary, flags: Dictionary, vars: Dictionary, log_warnings: bool = true) -> bool:
	var req_flag = msg.get("requires_flag", null)
	if req_flag != null:
		if req_flag is Array:
			for f in req_flag:
				if not flags.get(f, false):
					return false
		elif not flags.get(req_flag, false):
			return false
	var cond = msg.get("condition", null)
	if cond != null and not evaluate_node(cond, flags, vars, log_warnings):
		return false
	return true
