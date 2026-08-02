extends Node

const CE = preload("res://scripts/lib/condition_evaluator.gd")
const Assert = preload("res://tools/tests/test_assertions.gd")


func run_tests() -> Array:
	var results: Array = []
	var flags: Dictionary = {"a": true, "b": false, "c": true}
	var vars: Dictionary = {"x": 5, "name": "Maeve"}

	Assert.check(results, "condition: true flag", CE.evaluate_node({"flag": "a"}, flags, vars))
	Assert.check(results, "condition: false flag", not CE.evaluate_node({"flag": "b"}, flags, vars))
	Assert.check(results, "condition: missing flag defaults false", not CE.evaluate_node({"flag": "missing"}, flags, vars))
	Assert.check(results, "condition: and true", CE.evaluate_node({"and": [{"flag": "a"}, {"flag": "c"}]}, flags, vars))
	Assert.check(results, "condition: and short-circuits false", not CE.evaluate_node({"and": [{"flag": "b"}, {"flag": "a"}]}, flags, vars))
	Assert.check(results, "condition: empty and is true", CE.evaluate_node({"and": []}, flags, vars))
	Assert.check(results, "condition: or true", CE.evaluate_node({"or": [{"flag": "b"}, {"flag": "a"}]}, flags, vars))
	Assert.check(results, "condition: or false", not CE.evaluate_node({"or": [{"flag": "b"}, {"flag": "missing"}]}, flags, vars))
	Assert.check(results, "condition: empty or is false", not CE.evaluate_node({"or": []}, flags, vars))
	Assert.check(results, "condition: nested not", CE.evaluate_node({"not": {"flag": "b"}}, flags, vars))

	Assert.check(results, "condition: eq true", CE.evaluate_node({"var": "x", "op": "eq", "value": 5}, flags, vars))
	Assert.check(results, "condition: neq true", CE.evaluate_node({"var": "x", "op": "neq", "value": 3}, flags, vars))
	Assert.check(results, "condition: gt true", CE.evaluate_node({"var": "x", "op": "gt", "value": 3}, flags, vars))
	Assert.check(results, "condition: gte boundary", CE.evaluate_node({"var": "x", "op": "gte", "value": 5}, flags, vars))
	Assert.check(results, "condition: lt true", CE.evaluate_node({"var": "x", "op": "lt", "value": 8}, flags, vars))
	Assert.check(results, "condition: lte boundary", CE.evaluate_node({"var": "x", "op": "lte", "value": 5}, flags, vars))
	Assert.check(results, "condition: comparison false", not CE.evaluate_node({"var": "x", "op": "gt", "value": 8}, flags, vars))
	Assert.check(results, "condition: string equality", CE.evaluate_node({"var": "name", "op": "eq", "value": "Maeve"}, flags, vars))
	Assert.check(results, "condition: missing variable defaults zero", CE.evaluate_node({"var": "missing", "op": "eq", "value": 0}, flags, vars))
	Assert.check(results, "condition: unknown operator rejected", not CE.evaluate_node({"var": "x", "op": "wat", "value": 5}, flags, vars, false))
	Assert.check(results, "condition: malformed node rejected", not CE.evaluate_node({}, flags, vars, false))

	Assert.check(results, "message condition: unrestricted", CE.evaluate_message({}, flags, vars))
	Assert.check(results, "message condition: required flag present", CE.evaluate_message({"requires_flag": "a"}, flags, vars))
	Assert.check(results, "message condition: required flag absent", not CE.evaluate_message({"requires_flag": "missing"}, flags, vars))
	Assert.check(results, "message condition: required flags array present", CE.evaluate_message({"requires_flag": ["a", "c"]}, flags, vars))
	Assert.check(results, "message condition: required flags array incomplete", not CE.evaluate_message({"requires_flag": ["a", "missing"]}, flags, vars))
	Assert.check(results, "message condition: structured condition", CE.evaluate_message({"condition": {"var": "x", "op": "gte", "value": 5}}, flags, vars))
	Assert.check(results, "message condition: requirements are combined", not CE.evaluate_message({"requires_flag": "b", "condition": {"flag": "a"}}, flags, vars))

	return results
