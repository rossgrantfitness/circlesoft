extends TestCase
## The effect switches the debug overlay uses.

func after_each() -> void:
	PsxLook.reset_effects()


func test_every_effect_has_a_global_and_a_name() -> void:
	for effect: PsxLook.Effect in PsxLook.Effect.values():
		assert_true(PsxLook.EFFECT_GLOBALS.has(effect), "global for %s" % effect)
		assert_true(PsxLook.EFFECT_NAMES.has(effect), "name for %s" % effect)
		var global_name: StringName = PsxLook.EFFECT_GLOBALS[effect]
		assert_true(ProjectSettings.has_setting("shader_globals/" + String(global_name)), "declared: " + String(global_name))


func test_effects_start_on() -> void:
	for effect: PsxLook.Effect in PsxLook.Effect.values():
		assert_true(PsxLook.is_effect_on(effect), "default on: %s" % PsxLook.EFFECT_NAMES[effect])


func test_set_and_toggle() -> void:
	PsxLook.set_effect(PsxLook.Effect.FOG, false)
	assert_false(PsxLook.is_effect_on(PsxLook.Effect.FOG))
	assert_true(PsxLook.is_effect_on(PsxLook.Effect.DITHER), "other effects are untouched")
	assert_true(PsxLook.toggle_effect(PsxLook.Effect.FOG))
	assert_true(PsxLook.is_effect_on(PsxLook.Effect.FOG))
	assert_false(PsxLook.toggle_effect(PsxLook.Effect.FOG))


func test_reset_turns_everything_back_on() -> void:
	for effect: PsxLook.Effect in PsxLook.Effect.values():
		PsxLook.set_effect(effect, false)
	PsxLook.reset_effects()
	for effect: PsxLook.Effect in PsxLook.Effect.values():
		assert_true(PsxLook.is_effect_on(effect))
