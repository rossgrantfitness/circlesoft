class_name SaveTestKit
extends RefCounted
## Teardown for the save tests (bug B5): anything a test adds to the UI "busy" group (a save screen,
## a lamp, a conversation) must be gone when the test ends, or the next test's Red cannot interact.


## The nodes in the busy group right now (take this in before_each).
static func busy_now(tree: SceneTree) -> Array[Node]:
	var nodes: Array[Node] = []
	nodes.assign(tree.get_nodes_in_group(UiStage.MODAL_GROUP))
	return nodes


## Frees what the test owns, takes down any save screen or lamp it left on a shared stage, and then
## checks that nothing new is in the busy group compared with `baseline`. Call from after_each.
static func tear_down(test: TestCase, baseline: Array[Node]) -> void:
	test.free_owned_nodes()
	for node: Node in busy_now(test.tree):
		if baseline.has(node):
			continue
		if node is SavePrompt or node is SaveLamp:
			node.remove_from_group(UiStage.MODAL_GROUP)
			if node.get_parent() != null:
				node.get_parent().remove_child(node)
			node.free()
	var leaked: Array[String] = []
	for node: Node in busy_now(test.tree):
		if not baseline.has(node):
			leaked.append(str(node.get_path()) if node.is_inside_tree() else str(node))
	test.assert_eq(leaked, [] as Array[String], "this test left nodes in the busy group")
