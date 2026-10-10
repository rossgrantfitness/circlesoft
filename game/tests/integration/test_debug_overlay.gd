extends TestCase
## Milestone 1 step 12: the F-key PSX options overlay drives PsxLook, the PSX screen and the camera.

const SCREEN_SCENE: String = "res://scenes/core/psx_screen.tscn"
const FKEYS: Dictionary[String, Key] = {
	"debug_overlay": KEY_F1, "debug_jitter": KEY_F2, "debug_warp": KEY_F3, "debug_dither": KEY_F4,
	"debug_color_depth": KEY_F5, "debug_fog": KEY_F6, "debug_vertex_lighting": KEY_F7,
	"debug_resolution": KEY_F8, "debug_camera_mode": KEY_F9,
}
const EFFECT_FOR_ACTION: Dictionary[String, PsxLook.Effect] = {
	"debug_jitter": PsxLook.Effect.JITTER, "debug_warp": PsxLook.Effect.WARP,
	"debug_dither": PsxLook.Effect.DITHER, "debug_color_depth": PsxLook.Effect.COLOR_DEPTH,
	"debug_fog": PsxLook.Effect.FOG, "debug_vertex_lighting": PsxLook.Effect.VERTEX_LIGHTING,
}


func after_each() -> void:
	PsxLook.reset_effects()


func _make_overlay() -> PsxDebugOverlay:
	var overlay: PsxDebugOverlay = PsxDebugOverlay.new()
	add_to_root(overlay)
	return overlay


func _press(overlay: PsxDebugOverlay, action: StringName) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	overlay._input(event)


func test_keys_are_f1_to_f9() -> void:
	for action: String in FKEYS:
		var found: bool = false
		for event: InputEvent in InputMap.action_get_events(action):
			var key: InputEventKey = event as InputEventKey
			if key != null and key.physical_keycode == FKEYS[action]:
				found = true
		assert_true(found, "%s is bound to its F-key" % action)


func test_hint_shows_when_hidden_and_panel_when_shown() -> void:
	var overlay: PsxDebugOverlay = _make_overlay()
	assert_false(overlay.is_panel_visible())
	var hint: Label = overlay.find_children("*", "Label", true, false).filter(
			func(node: Node) -> bool: return (node as Label).text == "F1: PSX options")[0] as Label
	assert_true(hint.visible, "hint line while hidden")
	_press(overlay, &"debug_overlay")
	assert_true(overlay.is_panel_visible())
	assert_false(hint.visible)
	_press(overlay, &"debug_overlay")
	assert_false(overlay.is_panel_visible())
	assert_true(hint.visible)


func test_each_effect_key_toggles_psx_look() -> void:
	var overlay: PsxDebugOverlay = _make_overlay()
	for action: String in EFFECT_FOR_ACTION:
		var effect: PsxLook.Effect = EFFECT_FOR_ACTION[action]
		assert_true(PsxLook.is_effect_on(effect), "%s starts on" % action)
		_press(overlay, StringName(action))
		assert_false(PsxLook.is_effect_on(effect), "%s toggled off" % action)
		_press(overlay, StringName(action))
		assert_true(PsxLook.is_effect_on(effect), "%s toggled back on" % action)


func test_text_shows_every_effect_state_and_the_dither_note() -> void:
	var overlay: PsxDebugOverlay = _make_overlay()
	overlay.toggle_effect(PsxLook.Effect.FOG)
	var text: String = overlay.build_text()
	for effect: PsxLook.Effect in PsxLook.Effect.values():
		assert_true(text.contains(PsxLook.EFFECT_NAMES[effect]), "lists %s" % PsxLook.EFFECT_NAMES[effect])
	assert_true(text.contains("Fog: off"))
	assert_true(text.contains("Vertex jitter: ON"))
	assert_true(text.contains("needs 15-bit color"), "dither note")


func test_resolution_key_cycles_and_text_shows_it() -> void:
	var screen: PsxScreen = (load(SCREEN_SCENE) as PackedScene).instantiate() as PsxScreen
	add_to_root(screen)
	var overlay: PsxDebugOverlay = _make_overlay()
	var before: Vector2i = screen.get_resolution()
	assert_true(overlay.build_text().contains("%dx%d" % [before.x, before.y]))
	_press(overlay, &"debug_resolution")
	var after: Vector2i = screen.get_resolution()
	assert_ne(after, before)
	assert_true(overlay.build_text().contains("%dx%d" % [after.x, after.y]))


func test_camera_key_cycles_perspective_fovs_then_orthographic() -> void:
	var rig: DioramaCamera = DioramaCamera.new()
	rig.auto_update = false
	add_to_root(rig)
	var overlay: PsxDebugOverlay = _make_overlay()
	var start_basis: Basis = rig.global_basis
	assert_true(rig.is_perspective())
	assert_almost_eq(rig.fov_deg, 30.0, 0.001)
	_press(overlay, &"debug_camera_mode")
	assert_true(rig.is_perspective())
	assert_almost_eq(rig.fov_deg, 45.0, 0.001)
	assert_true(overlay.build_text().contains("perspective, FOV 45"))
	_press(overlay, &"debug_camera_mode")
	assert_false(rig.is_perspective(), "third step is orthographic")
	assert_true(overlay.build_text().contains("orthographic"))
	assert_eq(rig.get_camera().projection, Camera3D.PROJECTION_ORTHOGONAL)
	_press(overlay, &"debug_camera_mode")
	assert_true(rig.is_perspective())
	assert_almost_eq(rig.fov_deg, 30.0, 0.001, "back to the narrow FOV")
	assert_true(rig.global_basis.is_equal_approx(start_basis), "the camera never rotated")


func test_keys_do_nothing_harmful_without_a_screen_or_camera() -> void:
	var overlay: PsxDebugOverlay = _make_overlay()
	_press(overlay, &"debug_resolution")
	_press(overlay, &"debug_camera_mode")
	assert_eq(overlay.cycle_resolution(), Vector2i.ZERO)
	assert_eq(overlay.cycle_camera_mode(), "")
