extends TestCase
## Milestone 1 step 4: the PSX shader set exists, loads and has the pieces the look needs.
## (Headless runs use a dummy renderer that still parses shader code, so syntax errors show up
## as an empty uniform list. The real GPU compile is checked by tests/visual/check_psx_effects.gd.)

const SHADER_DIR: String = "res://shaders/"
const INCLUDE_FILE: String = "psx_common.gdshaderinc"
const SPATIAL_SHADERS: Array[String] = ["psx_lit.gdshader", "psx_unlit.gdshader", "psx_fade.gdshader"]
const POST_SHADER: String = "psx_post.gdshader"
const GLOBAL_UNIFORMS_IN_INCLUDE: Array[String] = [
	"psx_snap_res", "psx_jitter_strength", "psx_affine_strength", "psx_fog_color",
	"psx_fog_near", "psx_fog_far", "psx_fog_enabled", "psx_vertex_lighting",
]
const GLOBAL_UNIFORMS_IN_POST: Array[String] = ["psx_dither_enabled", "psx_color_depth_enabled"]
const MATERIAL_UNIFORMS: Array[String] = ["albedo_texture", "albedo_tint", "uv_scale", "uv_offset", "affine_amount", "fog_bands"]


func _code(file_name: String) -> String:
	return FileAccess.get_file_as_string(SHADER_DIR + file_name)


func test_all_shader_files_exist_and_load() -> void:
	var files: Array[String] = [INCLUDE_FILE, POST_SHADER]
	files.append_array(SPATIAL_SHADERS)
	for file_name: String in files:
		assert_true(FileAccess.file_exists(SHADER_DIR + file_name), "missing " + file_name)
	for file_name: String in SPATIAL_SHADERS + [POST_SHADER]:
		var shader: Shader = load(SHADER_DIR + file_name) as Shader
		assert_not_null(shader, "%s should load as a Shader" % file_name)


func test_spatial_shaders_have_the_material_parameters() -> void:
	for file_name: String in SPATIAL_SHADERS:
		var shader: Shader = load(SHADER_DIR + file_name) as Shader
		assert_eq(shader.get_mode(), Shader.MODE_SPATIAL, file_name)
		var names: Array[String] = []
		for uniform: Dictionary in shader.get_shader_uniform_list():
			names.append(uniform["name"])
		for wanted: String in MATERIAL_UNIFORMS:
			assert_has(names, wanted, "%s should expose %s (a parse error leaves the list empty)" % [file_name, wanted])


func test_post_shader_is_a_canvas_item_shader() -> void:
	var shader: Shader = load(SHADER_DIR + POST_SHADER) as Shader
	assert_eq(shader.get_mode(), Shader.MODE_CANVAS_ITEM)
	var names: Array[String] = []
	for uniform: Dictionary in shader.get_shader_uniform_list():
		names.append(uniform["name"])
	assert_has(names, "color_levels")
	assert_has(names, "dither_amount")


func test_spatial_shaders_share_the_common_include() -> void:
	for file_name: String in SPATIAL_SHADERS:
		var code: String = _code(file_name)
		assert_true(code.contains('#include "%s"' % INCLUDE_FILE), file_name + " should include " + INCLUDE_FILE)
		assert_true(code.contains("POSITION ="), file_name + " should write POSITION (vertex snap)")
		assert_true(code.contains("psx_snap("), file_name + " should snap vertices")
		assert_true(code.contains("psx_fragment_uv()"), file_name + " should use the affine UV")


func test_lit_shaders_use_vertex_lighting() -> void:
	for file_name: String in ["psx_lit.gdshader", "psx_fade.gdshader"]:
		assert_true(_code(file_name).contains("vertex_lighting"), file_name + " should use vertex lighting")
	assert_true(_code("psx_unlit.gdshader").contains("unshaded"))


func test_include_declares_every_global_switch_and_nearest_filtering() -> void:
	var code: String = _code(INCLUDE_FILE)
	for global_name: String in GLOBAL_UNIFORMS_IN_INCLUDE:
		assert_true(code.contains("global uniform") and code.contains(global_name), "include should read " + global_name)
	assert_true(code.contains("filter_nearest"), "albedo texture must be sampled nearest")
	assert_false(code.contains("filter_linear"), "no smooth filtering anywhere")


func test_post_shader_reads_its_switches() -> void:
	var code: String = _code(POST_SHADER)
	for global_name: String in GLOBAL_UNIFORMS_IN_POST:
		assert_true(code.contains(global_name), "post shader should read " + global_name)
	assert_true(code.contains("bayer4"), "post shader should dither with a 4x4 Bayer pattern")


func test_every_shader_global_is_declared_in_the_project() -> void:
	for global_name: String in GLOBAL_UNIFORMS_IN_INCLUDE + GLOBAL_UNIFORMS_IN_POST:
		assert_true(ProjectSettings.has_setting("shader_globals/" + global_name), "project.godot should declare " + global_name)


func test_fade_shader_has_a_per_prop_fade_amount() -> void:
	assert_true(_code("psx_fade.gdshader").contains("instance uniform float fade"))
