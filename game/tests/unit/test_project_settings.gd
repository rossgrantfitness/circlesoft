extends TestCase
## Milestone 1 step 1: the key project settings, input map, shader globals and autoloads.

const REQUIRED_ACTIONS: Array[String] = [
	"move_up", "move_down", "move_left", "move_right", "run", "confirm", "cancel", "menu", "start",
]
const DEBUG_ACTIONS: Array[String] = [
	"debug_overlay", "debug_jitter", "debug_warp", "debug_dither", "debug_color_depth", "debug_fog",
	"debug_vertex_lighting", "debug_resolution", "debug_camera_mode", "debug_free_camera",
]
const AUTOLOADS: Array[String] = ["DataDB", "GameState", "SaveManager", "Config", "SceneRouter", "AudioManager"]
const SHADER_GLOBALS: Dictionary[String, int] = {
	"psx_snap_res": RenderingServer.GLOBAL_VAR_TYPE_VEC2,
	"psx_jitter_strength": RenderingServer.GLOBAL_VAR_TYPE_FLOAT,
	"psx_affine_strength": RenderingServer.GLOBAL_VAR_TYPE_FLOAT,
	"psx_fog_color": RenderingServer.GLOBAL_VAR_TYPE_COLOR,
	"psx_fog_near": RenderingServer.GLOBAL_VAR_TYPE_FLOAT,
	"psx_fog_far": RenderingServer.GLOBAL_VAR_TYPE_FLOAT,
	"psx_fog_enabled": RenderingServer.GLOBAL_VAR_TYPE_FLOAT,
	"psx_vertex_lighting": RenderingServer.GLOBAL_VAR_TYPE_FLOAT,
	"psx_dither_enabled": RenderingServer.GLOBAL_VAR_TYPE_FLOAT,
	"psx_color_depth_enabled": RenderingServer.GLOBAL_VAR_TYPE_FLOAT,
}
const WARNING_LEVEL_ERROR: int = 2
const TEXTURE_FILTER_NEAREST: int = 0
const COMPRESS_MODE_LOSSLESS: int = 0
const EXPECTED_WINDOW: Vector2i = Vector2i(1280, 720)
const EXPECTED_INTERNAL_RES: Vector2 = Vector2(384, 216)


func _setting(path: String) -> Variant:
	return ProjectSettings.get_setting(path)


func test_application_identity() -> void:
	assert_eq(_setting("application/config/name"), "Lights Left On")
	assert_eq(_setting("application/config/use_custom_user_dir"), true)
	assert_eq(_setting("application/config/custom_user_dir_name"), "LightsLeftOn")


func test_renderer_is_compatibility() -> void:
	assert_eq(_setting("rendering/renderer/rendering_method"), "gl_compatibility")
	assert_eq(_setting("rendering/renderer/rendering_method.mobile"), "gl_compatibility")
	assert_has(_setting("application/config/features"), "GL Compatibility")


func test_nearest_filtering_and_mac_texture_support() -> void:
	assert_eq(_setting("rendering/textures/canvas_textures/default_texture_filter"), TEXTURE_FILTER_NEAREST)
	assert_eq(_setting("rendering/textures/vram_compression/import_etc2_astc"), true)


func test_untyped_declaration_is_an_error() -> void:
	assert_eq(_setting("debug/gdscript/warnings/untyped_declaration"), WARNING_LEVEL_ERROR)


func test_agile_input_flushing_is_on() -> void:
	assert_eq(_setting("input_devices/buffering/agile_event_flushing"), true)


func test_window_and_stretch() -> void:
	assert_eq(_setting("display/window/size/viewport_width"), EXPECTED_WINDOW.x)
	assert_eq(_setting("display/window/size/viewport_height"), EXPECTED_WINDOW.y)
	assert_eq(_setting("display/window/stretch/mode"), "canvas_items")


func test_importer_defaults_are_lossless_without_mipmaps() -> void:
	var texture_defaults: Dictionary = _setting("importer_defaults/texture")
	assert_eq(texture_defaults.get("compress/mode"), COMPRESS_MODE_LOSSLESS)
	assert_eq(texture_defaults.get("mipmaps/generate"), false)


func test_input_actions_exist_with_keyboard_and_gamepad() -> void:
	var all_actions: Array[String] = REQUIRED_ACTIONS.duplicate()
	all_actions.append_array(DEBUG_ACTIONS)
	for action: String in all_actions:
		assert_true(InputMap.has_action(action), "missing action " + action)
		var has_key: bool = false
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey:
				has_key = true
		assert_true(has_key, "no keyboard binding for " + action)
	for action: String in REQUIRED_ACTIONS:
		var has_pad: bool = false
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				has_pad = true
		assert_true(has_pad, "no gamepad binding for " + action)


func test_move_actions_have_both_wasd_and_arrows() -> void:
	var expected: Dictionary[String, Array] = {
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
	}
	for action: String in expected:
		var keys: Array[int] = []
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey:
				keys.append((event as InputEventKey).physical_keycode)
		for key: int in expected[action]:
			assert_has(keys, key, "%s should bind key %d" % [action, key])


func test_shader_globals_declared() -> void:
	for global_name: String in SHADER_GLOBALS:
		var setting: Dictionary = _setting("shader_globals/" + global_name)
		assert_eq(setting.get("type"), _type_name(SHADER_GLOBALS[global_name]), global_name)
	var snap: Dictionary = _setting("shader_globals/psx_snap_res")
	assert_eq(snap["value"], EXPECTED_INTERNAL_RES, "snap grid should match the 384x216 internal resolution")


func test_autoloads_registered_and_running() -> void:
	for autoload_name: String in AUTOLOADS:
		assert_true(ProjectSettings.has_setting("autoload/" + autoload_name), "autoload setting " + autoload_name)
		assert_not_null(tree.root.get_node_or_null(autoload_name), "autoload node " + autoload_name)


func test_main_scene_is_the_psx_screen_main() -> void:
	assert_eq(_setting("application/run/main_scene"), "res://scenes/core/main.tscn")


func test_models_import_through_the_psx_import_script() -> void:
	var scene_defaults: Dictionary = _setting("importer_defaults/scene")
	assert_eq(scene_defaults.get("import_script/path"), "res://scripts/tools/psx_post_import.gd")


func _type_name(global_type: int) -> String:
	match global_type:
		RenderingServer.GLOBAL_VAR_TYPE_VEC2:
			return "vec2"
		RenderingServer.GLOBAL_VAR_TYPE_COLOR:
			return "color"
		_:
			return "float"
