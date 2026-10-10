extends TestCase
## InputRemap: remap groups come from data, rebinding swaps with a group that must differ, only the
## differences from the defaults are stored, reserved keys are refused, and applying to the real
## InputMap always starts from the project's original bindings.


func after_each() -> void:
	InputRemap.reset()


func _first_key(action: String) -> int:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			return (event as InputEventKey).physical_keycode
	return -1


func _first_pad(action: String) -> int:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			return (event as InputEventJoypadButton).button_index
	return -1


func _keys(action: String) -> Array[int]:
	var codes: Array[int] = []
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			codes.append((event as InputEventKey).physical_keycode)
	return codes


func test_the_groups_come_from_data_and_are_real_actions() -> void:
	var groups: Array[String] = InputRemap.group_ids()
	assert_eq(groups, ["confirm", "cancel", "interact", "jump", "run", "menu", "clutch", "light", "heavy", "dash", "parry", "lock_on", "camera_toggle", "feel_panel"] as Array[String])
	for group: String in groups:
		for action: String in InputRemap.group_actions(group):
			assert_true(InputMap.has_action(action), "%s drives '%s'" % [group, action])


func test_defaults_read_the_projects_own_bindings() -> void:
	var defaults: Dictionary = InputRemap.defaults()
	assert_eq(defaults["jump"]["key"], KEY_SPACE)
	assert_eq(defaults["jump"]["pad"], JOY_BUTTON_A)
	assert_eq(defaults["confirm"]["key"], KEY_Z)
	assert_eq(defaults["cancel"]["pad"], JOY_BUTTON_B)
	assert_eq(defaults["run"]["key"], KEY_SHIFT)


func test_with_no_overrides_effective_equals_defaults() -> void:
	assert_eq(InputRemap.effective({}), InputRemap.defaults())


func test_rebind_changes_one_group() -> void:
	var current: Dictionary = InputRemap.defaults()
	var updated: Dictionary = InputRemap.rebind(current, "jump", "key", KEY_Q)
	assert_eq(updated["jump"]["key"], KEY_Q)
	assert_eq(updated["run"]["key"], current["run"]["key"], "others are untouched")
	assert_eq(current["jump"]["key"], KEY_SPACE, "the input was not changed in place")


func test_taking_a_key_a_partner_holds_swaps_the_two() -> void:
	var current: Dictionary = InputRemap.defaults()
	var updated: Dictionary = InputRemap.rebind(current, "jump", "key", KEY_SHIFT)
	assert_eq(updated["jump"]["key"], KEY_SHIFT)
	assert_eq(updated["run"]["key"], KEY_SPACE, "Run takes Jump's old key")
	assert_eq(InputRemap.holder_of(current, "key", KEY_SHIFT, "jump"), "run")


func test_confirm_and_cancel_swap_with_each_other_on_the_pad() -> void:
	var updated: Dictionary = InputRemap.rebind(InputRemap.defaults(), "confirm", "pad", JOY_BUTTON_B)
	assert_eq(updated["confirm"]["pad"], JOY_BUTTON_B)
	assert_eq(updated["cancel"]["pad"], JOY_BUTTON_A)


func test_clutch_shares_buttons_without_swapping_anyone() -> void:
	var current: Dictionary = InputRemap.defaults()
	assert_eq(InputRemap.swap_partners("clutch"), [] as Array[String])
	var updated: Dictionary = InputRemap.rebind(current, "clutch", "key", KEY_SHIFT)
	assert_eq(updated["clutch"]["key"], KEY_SHIFT)
	assert_eq(updated["run"]["key"], KEY_SHIFT, "Run keeps it too: the clutch press is battle-only")


func test_only_changes_are_stored_as_overrides() -> void:
	var updated: Dictionary = InputRemap.rebind(InputRemap.defaults(), "jump", "key", KEY_Q)
	var overrides: Dictionary = InputRemap.overrides_from(updated)
	assert_eq(overrides, {"jump": {"key": KEY_Q}})
	assert_eq(InputRemap.overrides_from(InputRemap.defaults()), {})
	assert_eq(InputRemap.effective(overrides)["jump"]["key"], KEY_Q)
	assert_eq(InputRemap.effective(overrides)["jump"]["pad"], JOY_BUTTON_A, "the pad half keeps its default")


func test_movement_escape_function_keys_and_the_dpad_cannot_be_bound() -> void:
	for code: int in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_ESCAPE, KEY_F1, KEY_F12]:
		assert_true(InputRemap.is_reserved("key", code), "key %d" % code)
	assert_false(InputRemap.is_reserved("key", KEY_Q))
	assert_false(InputRemap.is_reserved("key", KEY_ENTER), "Enter is a second Confirm, not reserved")
	assert_true(InputRemap.is_reserved("pad", JOY_BUTTON_DPAD_UP))
	assert_true(InputRemap.is_reserved("pad", JOY_BUTTON_START))
	assert_false(InputRemap.is_reserved("pad", JOY_BUTTON_Y))


func test_apply_writes_the_inputmap_and_reset_restores_it() -> void:
	var before_pad: int = _first_pad("jump")
	InputRemap.apply({"jump": {"key": KEY_Q, "pad": JOY_BUTTON_Y}})
	assert_eq(_first_key("jump"), KEY_Q)
	assert_eq(_first_pad("jump"), JOY_BUTTON_Y)
	InputRemap.apply({"jump": {"key": KEY_Q}})
	assert_eq(_first_pad("jump"), before_pad, "applying again starts from the originals, not the last remap")
	InputRemap.reset()
	assert_eq(_first_key("jump"), KEY_SPACE)
	assert_eq(_first_pad("jump"), before_pad)


func test_second_choice_keys_stay_unless_another_group_was_given_them() -> void:
	# Confirm has Enter as a second key. Remapping Confirm's main key keeps it.
	InputRemap.apply({"confirm": {"key": KEY_Q}})
	assert_has(_keys("confirm"), KEY_Q)
	assert_has(_keys("confirm"), KEY_ENTER)
	assert_does_not_have(_keys("confirm"), KEY_Z)
	# Giving Jump the E key (a second Confirm key) takes it away from Confirm.
	InputRemap.apply({"jump": {"key": KEY_E}})
	assert_does_not_have(_keys("confirm"), KEY_E)
	assert_eq(_first_key("jump"), KEY_E)


func test_names_for_keys_and_buttons_are_readable() -> void:
	assert_eq(InputRemap.key_name(KEY_Z), "Z")
	assert_eq(InputRemap.key_name(KEY_SPACE), "Space")
	assert_eq(InputRemap.pad_name(JOY_BUTTON_A), "A")
	assert_eq(InputRemap.pad_name(JOY_BUTTON_LEFT_SHOULDER), "LB")
	assert_eq(InputRemap.key_name(-1), "-")
