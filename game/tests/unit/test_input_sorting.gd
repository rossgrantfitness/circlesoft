extends TestCase
## VS-4, input sorting: no two actions that are live together in a room share a button by accident, in either option of
## Decision 3 (attack button talks / its own button), and the changes undo cleanly for the shelved game.

const ATTACK: StringName = InteractRules.MODE_ATTACK_BUTTON
const OWN: StringName = InteractRules.MODE_OWN_BUTTON


func after_each() -> void:
	InputSorting.revert()


func _describe(list: Array[Dictionary]) -> String:
	var parts: Array[String] = []
	for item: Dictionary in list:
		parts.append("%s/%s on %s" % [item["a"], item["b"], item["button"]])
	return ", ".join(parts)


func test_every_live_action_exists_in_the_input_map() -> void:
	for context: String in InputSorting.context_names():
		for action: String in InputSorting.live_actions(context):
			assert_true(InputMap.has_action(action), "%s: '%s' is not an input action" % [context, action])


func test_the_old_map_really_has_the_pad_b_clash() -> void:
	# The problem this task fixes: untouched, pad B is both the dash and the interact button.
	var clashes: Array[Dictionary] = InputSorting.conflicts("town")
	assert_true(_has_pair(clashes, "dash", "interact"), "if this fails the project bindings changed; re-check input_sorting.json")


func test_option_a_leaves_no_accidental_shared_button() -> void:
	InputSorting.apply(ATTACK)
	for context: String in InputSorting.context_names():
		var clashes: Array[Dictionary] = InputSorting.conflicts(context)
		assert_eq(clashes.size(), 0, "%s: %s" % [context, _describe(clashes)])


func test_option_b_leaves_no_accidental_shared_button() -> void:
	InputSorting.apply(OWN)
	for context: String in InputSorting.context_names():
		var clashes: Array[Dictionary] = InputSorting.conflicts(context)
		assert_eq(clashes.size(), 0, "%s: %s" % [context, _describe(clashes)])


func test_option_a_keeps_the_keyboard_key_and_drops_pad_b() -> void:
	InputSorting.apply(ATTACK)
	var sigs: Array[String] = InputSorting.signatures("interact")
	assert_true(sigs.has("key:%d" % KEY_E), "E still talks")
	assert_false(sigs.has("pad:1"), "pad B is the dash now")
	assert_false(_has_axis(sigs), "option A has no trigger button")


func test_option_b_puts_the_talk_button_on_the_right_trigger() -> void:
	InputSorting.apply(OWN)
	var sigs: Array[String] = InputSorting.signatures("interact")
	assert_true(sigs.has("axis:5:1"), "right trigger")
	assert_true(sigs.has("key:%d" % KEY_E))
	assert_false(sigs.has("pad:1"))


func test_applying_twice_changes_nothing_more() -> void:
	InputSorting.apply(OWN)
	var once: Array[String] = InputSorting.signatures("interact")
	InputSorting.apply(OWN)
	assert_eq(InputSorting.signatures("interact"), once)


func test_revert_gives_the_old_game_its_buttons_back() -> void:
	var before: Array[String] = InputSorting.signatures("interact")
	InputSorting.apply(OWN)
	assert_ne(InputSorting.signatures("interact"), before)
	InputSorting.revert()
	assert_eq(InputSorting.signatures("interact"), before, "the shelved game's interact is untouched")
	assert_true(InputSorting.signatures("interact").has("pad:1"))


func test_room_kinds_map_to_contexts() -> void:
	assert_eq(InputSorting.context_for_kind("town"), "town")
	assert_eq(InputSorting.context_for_kind("dungeon"), "dungeon")
	assert_eq(InputSorting.context_for_kind("arena"), "dungeon")
	assert_eq(InputSorting.context_for_kind("something_new"), "dungeon", "an unknown kind gets the busiest context")
	for kind: String in ["town", "dungeon", "arena"]:
		assert_has(InputSorting.context_names(), InputSorting.context_for_kind(kind))


func test_main_installs_and_removes_the_changes_with_the_mode() -> void:
	var main: Main = (load("res://scenes/core/main.tscn") as PackedScene).instantiate() as Main
	main.show_title = false
	main.sandbox_boot_enabled = false
	add_to_root(main)
	main.apply_mode(GameMode.Mode.SLICE)
	assert_false(InputSorting.signatures("interact").has("pad:1"), "the slice frees pad B")
	main.apply_mode(GameMode.Mode.CLASSIC)
	assert_true(InputSorting.signatures("interact").has("pad:1"), "the shelved game gets it back")


func test_a_config_remap_does_not_undo_the_sorting() -> void:
	var config: Node = tree.root.get_node("Config")
	InputSorting.install(config)
	assert_false(InputSorting.signatures("interact").has("pad:1"))
	InputRemap.apply({})                        # what a remap does: rebuild the actions from the project's bindings
	assert_true(InputSorting.signatures("interact").has("pad:1"), "the rebuild brought pad B back")
	config.emit_signal("setting_changed", "bindings")
	assert_false(InputSorting.signatures("interact").has("pad:1"), "and the sorting put things right again")


func _has_pair(list: Array[Dictionary], a: String, b: String) -> bool:
	for item: Dictionary in list:
		if (item["a"] == a and item["b"] == b) or (item["a"] == b and item["b"] == a):
			return true
	return false


func _has_axis(sigs: Array[String]) -> bool:
	for sig: String in sigs:
		if sig.begins_with("axis:"):
			return true
	return false
