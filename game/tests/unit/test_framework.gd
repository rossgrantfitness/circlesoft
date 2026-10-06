extends TestCase
## Checks the assertion helpers themselves: they must pass when they should and record a
## failure when they should.


func _fresh() -> TestCase:
	var probe: TestCase = TestCase.new()
	probe.reset_results()
	return probe


func test_passing_assertions_record_nothing() -> void:
	var probe: TestCase = _fresh()
	probe.assert_true(true)
	probe.assert_false(false)
	probe.assert_eq(3, 3)
	probe.assert_eq(3, 3.0)
	probe.assert_eq("a", "a")
	probe.assert_eq([1, 2], [1, 2])
	probe.assert_ne(1, 2)
	probe.assert_almost_eq(0.1 + 0.2, 0.3)
	probe.assert_gt(2.0, 1.0)
	probe.assert_ge(2.0, 2.0)
	probe.assert_lt(1.0, 2.0)
	probe.assert_le(2.0, 2.0)
	probe.assert_null(null)
	probe.assert_not_null(1)
	probe.assert_has([1, 2, 3], 2)
	probe.assert_does_not_have([1, 2, 3], 9)
	assert_eq(probe.get_failures().size(), 0)
	assert_eq(probe.get_assert_count(), 16)


func test_failing_assertions_are_recorded() -> void:
	var probe: TestCase = _fresh()
	probe.assert_true(false)
	probe.assert_false(true)
	probe.assert_eq(1, 2)
	probe.assert_eq("1", 1, "types differ")
	probe.assert_ne(1, 1)
	probe.assert_almost_eq(1.0, 2.0)
	probe.assert_gt(1.0, 2.0)
	probe.assert_lt(2.0, 1.0)
	probe.assert_null(5)
	probe.assert_not_null(null)
	probe.assert_has([1], 2)
	probe.fail("manual")
	assert_eq(probe.get_failures().size(), 12)


func test_failure_message_names_values_and_note() -> void:
	var probe: TestCase = _fresh()
	probe.assert_eq(5, 7, "speed")
	var failures: Array[String] = probe.get_failures()
	assert_eq(failures.size(), 1)
	assert_true(failures[0].contains("speed"))
	assert_true(failures[0].contains("expected 7, got 5"))


func test_reset_clears_results() -> void:
	var probe: TestCase = _fresh()
	probe.assert_true(false)
	probe.reset_results()
	assert_eq(probe.get_failures().size(), 0)
	assert_eq(probe.get_assert_count(), 0)


func test_add_to_root_cleans_up() -> void:
	var node: Node = Node.new()
	add_to_root(node)
	assert_true(node.is_inside_tree())
	free_owned_nodes()
	assert_false(is_instance_valid(node))
