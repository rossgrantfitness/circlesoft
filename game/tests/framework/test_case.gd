class_name TestCase
extends RefCounted
## Base class for every test file. Put `test_*` methods in a subclass; run_all.gd finds and
## runs them. A test method may `await` (for scene tests). Assertions record a failure and
## carry on, so one test reports every problem it finds, not just the first.

const FLOAT_TOLERANCE: float = 0.0001
const STACK_CALLER_DEPTH: int = 2

## Set by the runner so scene tests can reach the tree (tree.root, await tree.physics_frame).
var tree: SceneTree = null

var _failures: Array[String] = []
var _assert_count: int = 0
var _owned_nodes: Array[Node] = []


## Called before each test method.
func before_each() -> void:
	pass


## Called after each test method, pass or fail.
func after_each() -> void:
	pass


# ---- runner API ----

func reset_results() -> void:
	_failures.clear()
	_assert_count = 0


func get_failures() -> Array[String]:
	return _failures.duplicate()


func get_assert_count() -> int:
	return _assert_count


## Frees every node added with add_to_root(). The runner calls this after each test.
func free_owned_nodes() -> void:
	for node: Node in _owned_nodes:
		if is_instance_valid(node):
			if node.get_parent() != null:
				node.get_parent().remove_child(node)
			node.free()
	_owned_nodes.clear()


# ---- helpers for scene tests ----

## Adds a node under the root window and frees it when the test ends.
func add_to_root(node: Node) -> Node:
	_owned_nodes.append(node)
	tree.root.add_child(node)
	return node


## Remembers a node for cleanup without adding it to the tree.
func own(node: Node) -> Node:
	_owned_nodes.append(node)
	return node


# ---- assertions ----

func fail(message: String) -> void:
	_assert_count += 1
	_record_failure(message)


func assert_true(condition: bool, message: String = "") -> void:
	_assert_count += 1
	if not condition:
		_record_failure(_with_note("expected true", message))


func assert_false(condition: bool, message: String = "") -> void:
	_assert_count += 1
	if condition:
		_record_failure(_with_note("expected false", message))


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	_assert_count += 1
	if not _same(actual, expected):
		_record_failure(_with_note("expected %s, got %s" % [_show(expected), _show(actual)], message))


func assert_ne(actual: Variant, unexpected: Variant, message: String = "") -> void:
	_assert_count += 1
	if _same(actual, unexpected):
		_record_failure(_with_note("expected anything but %s" % _show(unexpected), message))


func assert_almost_eq(actual: float, expected: float, tolerance: float = FLOAT_TOLERANCE, message: String = "") -> void:
	_assert_count += 1
	if absf(actual - expected) > tolerance:
		_record_failure(_with_note("expected %s +/- %s, got %s" % [expected, tolerance, actual], message))


func assert_gt(actual: float, limit: float, message: String = "") -> void:
	_assert_count += 1
	if not actual > limit:
		_record_failure(_with_note("expected %s > %s" % [actual, limit], message))


func assert_lt(actual: float, limit: float, message: String = "") -> void:
	_assert_count += 1
	if not actual < limit:
		_record_failure(_with_note("expected %s < %s" % [actual, limit], message))


func assert_ge(actual: float, limit: float, message: String = "") -> void:
	_assert_count += 1
	if not actual >= limit:
		_record_failure(_with_note("expected %s >= %s" % [actual, limit], message))


func assert_le(actual: float, limit: float, message: String = "") -> void:
	_assert_count += 1
	if not actual <= limit:
		_record_failure(_with_note("expected %s <= %s" % [actual, limit], message))


func assert_null(value: Variant, message: String = "") -> void:
	_assert_count += 1
	if value != null:
		_record_failure(_with_note("expected null, got %s" % _show(value), message))


func assert_not_null(value: Variant, message: String = "") -> void:
	_assert_count += 1
	if value == null:
		_record_failure(_with_note("expected a value, got null", message))


## Passes when `item` is in `collection` (Array, Dictionary keys, or substring of a String).
func assert_has(collection: Variant, item: Variant, message: String = "") -> void:
	_assert_count += 1
	if not (item in collection):
		_record_failure(_with_note("expected %s to contain %s" % [_show(collection), _show(item)], message))


func assert_does_not_have(collection: Variant, item: Variant, message: String = "") -> void:
	_assert_count += 1
	if item in collection:
		_record_failure(_with_note("expected %s not to contain %s" % [_show(collection), _show(item)], message))


# ---- internals ----

func _same(a: Variant, b: Variant) -> bool:
	if typeof(a) == typeof(b) or (_is_number(a) and _is_number(b)):
		return a == b
	return false


func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


func _show(value: Variant) -> String:
	if value is String:
		return '"%s"' % value
	return str(value)


func _with_note(what: String, note: String) -> String:
	if note.is_empty():
		return what
	return "%s (%s)" % [note, what]


func _record_failure(message: String) -> void:
	var stack: Array = get_stack()
	var where: String = ""
	if stack.size() > STACK_CALLER_DEPTH:
		var frame: Dictionary = stack[STACK_CALLER_DEPTH]
		where = "%s:%s: " % [str(frame.get("source", "")).get_file(), frame.get("line", 0)]
	_failures.append(where + message)
