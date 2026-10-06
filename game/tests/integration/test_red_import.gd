extends TestCase
## Milestone 1 step 11: the placeholder Red goes through scripts/tools/psx_post_import.gd and
## comes out with PSX materials, nearest filtering, looping animations, and a size inside the
## style guide's budget. Needs the project imported once: godot --headless --path game --import

const RED_PATH: String = "res://art/placeholder/characters/red/red_blockout.glb"
const RED_IMPORT_FILE: String = RED_PATH + ".import"
const IMPORT_SCRIPT: String = "res://scripts/tools/psx_post_import.gd"
const LIT_SHADER: String = "res://shaders/psx_lit.gdshader"
const UNLIT_SHADER: String = "res://shaders/psx_unlit.gdshader"
# Style guide: Red is the unit, 1.0 tall (ears included). Party triangle target 700, hard cap 900.
const RED_HEIGHT: float = 1.0
const HEIGHT_TOLERANCE: float = 0.1
const PARTY_TRIANGLE_TARGET: int = 700
const PARTY_TRIANGLE_HARD_CAP: int = 900
const BLOCKOUT_TRIANGLES_MIN: int = 200
const BODY_TEXTURE_PX: int = 128
const SKELETON_BONES: int = 17
const REQUIRED_BONES: Array[String] = ["root", "hips", "spine", "head", "ear_l", "ear_r", "tail",
	"upper_arm_l", "upper_arm_r", "forearm_l", "forearm_r", "thigh_l", "thigh_r", "shin_l", "shin_r",
	"weapon_socket", "prop_socket"]
## Style guide clip lengths in seconds: idle about 1.5, walk 0.8, run 0.6.
const CLIPS: Dictionary[String, float] = {"idle": 1.5, "walk": 0.8, "run": 0.6, "fall": 0.53}
## One-shot clips: they play once and hold the last pose. jump 0.4 s (takeoff, holds rising),
## land 0.27 s (squash and recover).
const ONE_SHOT_CLIPS: Dictionary[String, float] = {"jump": 0.4, "land": 0.27}
const CLIP_TOLERANCE: float = 0.1


func _red() -> Node3D:
	var packed: PackedScene = load(RED_PATH) as PackedScene
	assert_not_null(packed, "red_blockout.glb should import (run godot --headless --path game --import)")
	var red: Node3D = packed.instantiate() as Node3D
	own(red)
	return red


func _first_mesh(red: Node) -> MeshInstance3D:
	var found: Array[Node] = red.find_children("*", "MeshInstance3D", true, false)
	assert_gt(found.size(), 0, "Red has a mesh")
	return found[0] as MeshInstance3D


func test_import_script_is_registered_for_red() -> void:
	var text: String = FileAccess.get_file_as_string(RED_IMPORT_FILE)
	assert_true(text.contains('import_script/path="%s"' % IMPORT_SCRIPT), "Red's .import file names the import script")


func test_materials_are_psx_lit_shader_materials() -> void:
	var mesh_instance: MeshInstance3D = _first_mesh(_red())
	for surface: int in mesh_instance.mesh.get_surface_count():
		var material: ShaderMaterial = mesh_instance.mesh.surface_get_material(surface) as ShaderMaterial
		assert_not_null(material, "surface %d should be a ShaderMaterial" % surface)
		if material != null:
			assert_eq(material.shader.resource_path, LIT_SHADER)
			assert_eq(material.resource_name, "mat_red_blockout", "keeps the artist's material name")


func test_texture_is_128_px_and_sampled_nearest() -> void:
	var mesh_instance: MeshInstance3D = _first_mesh(_red())
	var material: ShaderMaterial = mesh_instance.mesh.surface_get_material(0) as ShaderMaterial
	var texture: Texture2D = material.get_shader_parameter("albedo_texture") as Texture2D
	assert_not_null(texture, "texture carried over")
	assert_eq(texture.get_size(), Vector2(BODY_TEXTURE_PX, BODY_TEXTURE_PX))
	var code: String = FileAccess.get_file_as_string(LIT_SHADER) + FileAccess.get_file_as_string("res://shaders/psx_common.gdshaderinc")
	assert_true(code.contains("sampler2D albedo_texture : source_color, filter_nearest"), "the shader samples nearest")


func test_clips_exist_loop_and_step() -> void:
	var players: Array[Node] = _red().find_children("*", "AnimationPlayer", true, false)
	assert_eq(players.size(), 1)
	var player: AnimationPlayer = players[0] as AnimationPlayer
	for clip: String in CLIPS:
		assert_true(player.has_animation(clip), "has " + clip)
		var animation: Animation = player.get_animation(clip)
		assert_eq(animation.loop_mode, Animation.LOOP_LINEAR, clip + " loops")
		assert_almost_eq(animation.length, CLIPS[clip], CLIP_TOLERANCE, clip + " length")
		for track: int in animation.get_track_count():
			assert_eq(animation.track_get_interpolation_type(track), Animation.INTERPOLATION_NEAREST, "%s track %d is stepped" % [clip, track])


func test_jump_fall_land_clips_exist_and_behave() -> void:
	var players: Array[Node] = _red().find_children("*", "AnimationPlayer", true, false)
	var player: AnimationPlayer = players[0] as AnimationPlayer
	for clip: String in ONE_SHOT_CLIPS:
		assert_true(player.has_animation(clip), "has " + clip)
		var animation: Animation = player.get_animation(clip)
		assert_eq(animation.loop_mode, Animation.LOOP_NONE, clip + " plays once")
		assert_almost_eq(animation.length, ONE_SHOT_CLIPS[clip], CLIP_TOLERANCE, clip + " length")
		for track: int in animation.get_track_count():
			assert_eq(animation.track_get_interpolation_type(track), Animation.INTERPOLATION_NEAREST, "%s track %d is stepped" % [clip, track])


func test_run_reads_as_a_run_not_a_walk() -> void:
	# The run clip is shorter than the walk clip (a quicker cadence), and its legs swing wider.
	var players: Array[Node] = _red().find_children("*", "AnimationPlayer", true, false)
	var player: AnimationPlayer = players[0] as AnimationPlayer
	assert_lt(player.get_animation("run").length, player.get_animation("walk").length, "run cadence is quicker")
	assert_gt(_swing_degrees(player.get_animation("run"), "thigh_l"), _swing_degrees(player.get_animation("walk"), "thigh_l") * 1.5, "run stride is much bigger")


## Widest angle, in degrees, a bone's rotation track reaches away from its first key.
func _swing_degrees(animation: Animation, bone: String) -> float:
	var widest: float = 0.0
	for track: int in animation.get_track_count():
		if animation.track_get_type(track) != Animation.TYPE_ROTATION_3D:
			continue
		if not String(animation.track_get_path(track)).ends_with(":" + bone):
			continue
		var first: Quaternion = animation.rotation_track_interpolate(track, 0.0)
		for key: int in animation.track_get_key_count(track):
			var q: Quaternion = animation.track_get_key_value(track, key) as Quaternion
			widest = maxf(widest, rad_to_deg(first.angle_to(q)))
	return widest


func test_height_is_one_unit() -> void:
	var red: Node3D = _red()
	var mesh_instance: MeshInstance3D = _first_mesh(red)
	assert_almost_eq(mesh_instance.get_aabb().size.y, RED_HEIGHT, HEIGHT_TOLERANCE, "Red is about 1.0 unit tall")
	assert_almost_eq(mesh_instance.get_aabb().position.y, 0.0, HEIGHT_TOLERANCE, "feet at the origin")


func test_triangle_count_is_inside_the_style_guide_budget() -> void:
	var mesh_instance: MeshInstance3D = _first_mesh(_red())
	var triangles: int = 0
	for surface: int in mesh_instance.mesh.get_surface_count():
		var arrays: Array = mesh_instance.mesh.surface_get_arrays(surface)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		triangles += indices.size() / 3
	assert_le(triangles, PARTY_TRIANGLE_TARGET, "under the 700 target")
	assert_le(triangles, PARTY_TRIANGLE_HARD_CAP)
	assert_ge(triangles, BLOCKOUT_TRIANGLES_MIN, "it is the ~300 triangle blockout")


func test_skeleton_has_the_shared_17_bones() -> void:
	var skeletons: Array[Node] = _red().find_children("*", "Skeleton3D", true, false)
	assert_eq(skeletons.size(), 1)
	var skeleton: Skeleton3D = skeletons[0] as Skeleton3D
	assert_eq(skeleton.get_bone_count(), SKELETON_BONES)
	for bone: String in REQUIRED_BONES:
		assert_ge(skeleton.find_bone(bone), 0, "bone " + bone)


func test_import_script_names_unlit_materials_for_the_unlit_shader() -> void:
	var script: GDScript = load(IMPORT_SCRIPT) as GDScript
	assert_not_null(script, "import script compiles")
	var lit_source: StandardMaterial3D = StandardMaterial3D.new()
	lit_source.resource_name = "mat_wall"
	var lit: ShaderMaterial = script.make_psx_material(lit_source)
	assert_eq(lit.shader.resource_path, LIT_SHADER)
	var glow_source: StandardMaterial3D = StandardMaterial3D.new()
	glow_source.resource_name = "mat_lamp_unlit"
	var glow: ShaderMaterial = script.make_psx_material(glow_source)
	assert_eq(glow.shader.resource_path, UNLIT_SHADER)
	assert_eq(glow.resource_name, "mat_lamp_unlit")
	assert_not_null(script.make_psx_material(null), "a model with no material still gets one")
