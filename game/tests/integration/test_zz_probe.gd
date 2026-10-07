extends TestCase
func test_zz_probe() -> void:
	print("PROBE modal=", tree.get_nodes_in_group(UiStage.MODAL_GROUP))
	assert_true(true)
