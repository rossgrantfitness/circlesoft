extends TestCase
## Runs right after the other save tests (file order): none of them may leave a save screen up, or it
## would hold the "busy" lock on the field for every test after it.


func test_no_save_screen_is_left_up_after_the_save_tests() -> void:
	var left: Array[Node] = []
	for node: Node in tree.get_nodes_in_group(UiStage.MODAL_GROUP):
		if node is SavePrompt or node is SaveLamp:
			left.append(node)
	assert_eq(left.size(), 0, "save screens left modal: %s" % str(left))
