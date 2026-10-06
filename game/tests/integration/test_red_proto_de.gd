extends TestCase
## Red style prototypes D (Ink Line), E (Rubber Bounce) and F (Shiba, Ross's pick): each imports through
## scripts/tools/psx_post_import.gd, stays under the 900 triangle cap (D counted WITH its outline
## hull), has the shared 17 bones, small nearest-filtered textures, and the right PSX shaders.
## Also covers the import script's `_cel` and `_outline` material name suffixes and the two new
## shaders. Needs the project imported once: godot --headless --path game --import

const FOLDER: String = "res://art/placeholder/characters/red_prototypes/"
const IMPORT_SCRIPT: String = "res://scripts/tools/psx_post_import.gd"
const LIT_SHADER: String = "res://shaders/psx_lit.gdshader"
const UNLIT_SHADER: String = "res://shaders/psx_unlit.gdshader"
const CEL_SHADER: String = "res://shaders/psx_cel.gdshader"
const OUTLINE_SHADER: String = "res://shaders/psx_outline.gdshader"
const COMMON_INCLUDE: String = "psx_common.gdshaderinc"
const PARTY_TRIANGLE_HARD_CAP: int = 900
const PROP_TRIANGLE_HARD_CAP: int = 150
const D_BASE_TRIANGLES_MAX: int = 460            # brief: base mesh about 400-440, so the hull fits
const MAX_TEXTURE_PX: int = 128
## Red is 1.0 tall to the top of her head; the up-ear adds the rest.
const HEAD_TOP: float = 1.0
const WITH_EAR_MAX: float = 1.35
const HEIGHT_TOLERANCE: float = 0.1
const REQUIRED_BONES: Array[String] = ["root", "hips", "spine", "head", "ear_l", "ear_r", "tail",
	"upper_arm_l", "upper_arm_r", "forearm_l", "forearm_r", "thigh_l", "thigh_r", "shin_l", "shin_r",
	"weapon_socket", "prop_socket"]


func _model(letter: String) -> Node3D:
	var packed: PackedScene = load(FOLDER + "red_proto_%s.glb" % letter) as PackedScene
	assert_not_null(packed, "red_proto_%s.glb should import (run godot --headless --path game --import)" % letter)
	var model: Node3D = packed.instantiate() as Node3D
	own(model)
	return model


func _mesh_named(model: Node, part: String) -> MeshInstance3D:
	for found: Node in model.find_children("*", "MeshInstance3D", true, false):
		if String(found.name).contains(part):
			return found as MeshInstance3D
	assert_true(false, "no mesh named *%s*" % part)
	return null


func _surface_triangles(mesh: Mesh, surface: int) -> int:
	var arrays: Array = mesh.surface_get_arrays(surface)
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	return indices.size() / 3


func _total_triangles(mesh_instance: MeshInstance3D) -> int:
	var total: int = 0
	for surface: int in mesh_instance.mesh.get_surface_count():
		total += _surface_triangles(mesh_instance.mesh, surface)
	return total


func _shader_path(mesh_instance: MeshInstance3D, surface: int) -> String:
	var material: ShaderMaterial = mesh_instance.mesh.surface_get_material(surface) as ShaderMaterial
	assert_not_null(material, "surface %d should be a ShaderMaterial" % surface)
	return "" if material == null else material.shader.resource_path


func _surface_with_shader(mesh_instance: MeshInstance3D, shader_path: String) -> int:
	for surface: int in mesh_instance.mesh.get_surface_count():
		if _shader_path(mesh_instance, surface) == shader_path:
			return surface
	return -1


# ---- both prototypes ----

func test_both_prototypes_import_with_a_body_and_a_sword() -> void:
	for letter: String in ["d", "e", "f"]:
		var model: Node3D = _model(letter)
		assert_not_null(_mesh_named(model, "_body"), letter + " body")
		assert_not_null(_mesh_named(model, "_sword"), letter + " sword")


func test_both_prototypes_are_under_the_triangle_cap() -> void:
	for letter: String in ["d", "e", "f"]:
		var model: Node3D = _model(letter)
		var body: int = _total_triangles(_mesh_named(model, "_body"))
		var sword: int = _total_triangles(_mesh_named(model, "_sword"))
		assert_le(body, PARTY_TRIANGLE_HARD_CAP, "%s body (all surfaces, outline included) is %d triangles" % [letter, body])
		assert_gt(body, 300, letter + " is not an empty model")
		assert_le(sword, PROP_TRIANGLE_HARD_CAP, "%s sword (with outline) is %d triangles" % [letter, sword])


func test_both_prototypes_are_one_unit_tall_without_the_ear() -> void:
	for letter: String in ["d", "e", "f"]:
		var box: AABB = _mesh_named(_model(letter), "_body").get_aabb()
		assert_almost_eq(box.position.y, 0.0, HEIGHT_TOLERANCE, letter + " feet at the origin")
		assert_gt(box.end.y, HEAD_TOP - HEIGHT_TOLERANCE, letter + " is at least head height")
		assert_lt(box.end.y, WITH_EAR_MAX, letter + " (head plus up-ear) is not taller than Red should be")


func test_both_prototypes_have_the_shared_17_bones() -> void:
	for letter: String in ["d", "e", "f"]:
		var skeletons: Array[Node] = _model(letter).find_children("*", "Skeleton3D", true, false)
		assert_eq(skeletons.size(), 1, letter + " has one skeleton")
		var skeleton: Skeleton3D = skeletons[0] as Skeleton3D
		assert_eq(skeleton.get_bone_count(), REQUIRED_BONES.size(), letter + " bone count")
		for bone: String in REQUIRED_BONES:
			assert_ge(skeleton.find_bone(bone), 0, "%s has bone %s" % [letter, bone])


func test_textures_are_small_and_the_face_sheet_is_128_by_64() -> void:
	var expected: Dictionary[String, Vector2] = {
		"red_proto_d_swatch.png": Vector2(64, 64), "red_proto_d_face.png": Vector2(128, 64),
		"red_proto_e_body.png": Vector2(128, 128), "red_proto_e_face.png": Vector2(128, 64),
		"red_proto_f_body.png": Vector2(128, 128), "red_proto_f_face.png": Vector2(128, 64)}
	for file_name: String in expected:
		var texture: Texture2D = load(FOLDER + file_name) as Texture2D
		assert_not_null(texture, file_name)
		if texture != null:
			assert_eq(texture.get_size(), expected[file_name], file_name)
			assert_le(int(texture.get_width()), MAX_TEXTURE_PX, file_name)


func test_prototypes_are_static_no_animation_clips() -> void:
	for letter: String in ["d", "e", "f"]:
		var players: Array[Node] = _model(letter).find_children("*", "AnimationPlayer", true, false)
		for player: Node in players:
			assert_eq((player as AnimationPlayer).get_animation_list().size(), 0, letter + " has no clips")


# ---- D: Ink Line ----

func test_d_has_a_cel_surface_an_outline_hull_and_unlit_face_decals() -> void:
	var body: MeshInstance3D = _mesh_named(_model("d"), "_body")
	var cel: int = _surface_with_shader(body, CEL_SHADER)
	var outline: int = _surface_with_shader(body, OUTLINE_SHADER)
	var face: int = _surface_with_shader(body, UNLIT_SHADER)
	assert_ge(cel, 0, "a surface uses psx_cel")
	assert_ge(outline, 0, "a surface uses psx_outline")
	assert_ge(face, 0, "the eye decals use psx_unlit (alpha cut)")
	var cel_material: ShaderMaterial = body.mesh.surface_get_material(cel) as ShaderMaterial
	assert_eq(cel_material.get_shader_parameter("albedo_texture").get_size(), Vector2(64, 64), "swatch strip is 64x64")
	assert_true(String(cel_material.resource_name).ends_with("_cel"))


func test_d_outline_hull_copies_the_body_so_the_pair_stays_under_the_cap() -> void:
	var body: MeshInstance3D = _mesh_named(_model("d"), "_body")
	var cel_triangles: int = _surface_triangles(body.mesh, _surface_with_shader(body, CEL_SHADER))
	var hull_triangles: int = _surface_triangles(body.mesh, _surface_with_shader(body, OUTLINE_SHADER))
	assert_le(cel_triangles, D_BASE_TRIANGLES_MAX + 10, "base mesh stays near 400-440 (plus a few decal triangles)")
	assert_ge(hull_triangles, int(cel_triangles * 0.8), "the hull is a copy of (nearly) the whole base mesh")
	assert_le(hull_triangles, cel_triangles, "the hull is never bigger than the base")
	assert_le(cel_triangles + hull_triangles + _surface_triangles(body.mesh, _surface_with_shader(body, UNLIT_SHADER)),
			PARTY_TRIANGLE_HARD_CAP)


func test_d_sword_is_cel_shaded_and_outlined_too() -> void:
	var sword: MeshInstance3D = _mesh_named(_model("d"), "_sword")
	assert_ge(_surface_with_shader(sword, CEL_SHADER), 0)
	assert_ge(_surface_with_shader(sword, OUTLINE_SHADER), 0)


# ---- E: Rubber Bounce ----

func test_e_uses_the_standard_lit_shader_with_a_body_sheet_and_a_face_sheet() -> void:
	var body: MeshInstance3D = _mesh_named(_model("e"), "_body")
	assert_eq(body.mesh.get_surface_count(), 2, "body sheet + face sheet")
	for surface: int in body.mesh.get_surface_count():
		assert_eq(_shader_path(body, surface), LIT_SHADER, "E needs no new shader")
	var face_material: ShaderMaterial = null
	for surface: int in body.mesh.get_surface_count():
		var material: ShaderMaterial = body.mesh.surface_get_material(surface) as ShaderMaterial
		if String(material.resource_name).ends_with("_face"):
			face_material = material
	assert_not_null(face_material, "a face material exists")
	assert_eq(face_material.get_shader_parameter("albedo_texture").get_size(), Vector2(128, 64))


# ---- F: Shiba (E style + E head + C body, short pointy ears) ----

func test_f_uses_the_standard_lit_shader_with_a_body_sheet_and_a_face_sheet() -> void:
	var body: MeshInstance3D = _mesh_named(_model("f"), "_body")
	assert_eq(body.mesh.get_surface_count(), 2, "body sheet + face sheet")
	var face_material: ShaderMaterial = null
	for surface: int in body.mesh.get_surface_count():
		assert_eq(_shader_path(body, surface), LIT_SHADER, "F needs no new shader")
		var material: ShaderMaterial = body.mesh.surface_get_material(surface) as ShaderMaterial
		if String(material.resource_name).ends_with("_face"):
			face_material = material
	assert_not_null(face_material, "a face material exists (uv_offset.x = 0.5 swaps to the grin cell)")


func test_f_ears_are_short_so_the_shiba_is_not_taller_than_the_bunny_eared_prototypes() -> void:
	var f_height: float = _mesh_named(_model("f"), "_body").get_aabb().end.y
	var e_height: float = _mesh_named(_model("e"), "_body").get_aabb().end.y
	assert_lt(f_height, e_height - 0.05, "F's short pointy ears top out lower than E's tall ear")
	assert_lt(f_height, 1.25, "head 1.0 plus a short ear")


func test_f_total_with_sword_fits_the_party_cap() -> void:
	var model: Node3D = _model("f")
	var total: int = _total_triangles(_mesh_named(model, "_body")) + _total_triangles(_mesh_named(model, "_sword"))
	assert_le(total, PARTY_TRIANGLE_HARD_CAP, "F body plus sword is %d triangles" % total)


# ---- import script suffixes ----

func test_import_script_picks_the_shader_by_material_name_suffix() -> void:
	var script: GDScript = load(IMPORT_SCRIPT) as GDScript
	assert_not_null(script, "import script compiles")
	var cases: Dictionary[String, String] = {
		"mat_red_proto_d_cel": CEL_SHADER,
		"mat_red_proto_d_outline": OUTLINE_SHADER,
		"mat_red_proto_d_face_unlit": UNLIT_SHADER,
		"mat_red_proto_e_body": LIT_SHADER,
		"mat_red_blockout": LIT_SHADER,
		"": LIT_SHADER,
		"cel_but_not_a_suffix_x": LIT_SHADER,
	}
	for material_name: String in cases:
		var source: StandardMaterial3D = StandardMaterial3D.new()
		source.resource_name = material_name
		var made: ShaderMaterial = script.make_psx_material(source)
		assert_eq(made.shader.resource_path, cases[material_name], "'%s' gets %s" % [material_name, cases[material_name]])
		assert_eq(made.resource_name, material_name, "keeps the artist's material name")


func test_red_blockout_still_gets_the_lit_shader() -> void:
	var packed: PackedScene = load("res://art/placeholder/characters/red/red_blockout.glb") as PackedScene
	var model: Node = packed.instantiate()
	own(model)
	for mesh_instance: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mesh_instance as MeshInstance3D).mesh
		for surface: int in mesh.get_surface_count():
			assert_eq((mesh.surface_get_material(surface) as ShaderMaterial).shader.resource_path, LIT_SHADER)


# ---- the two new shaders ----

func test_cel_shader_keeps_the_psx_pieces_and_cuts_two_bands() -> void:
	var shader: Shader = load(CEL_SHADER) as Shader
	assert_not_null(shader)
	assert_eq(shader.get_mode(), Shader.MODE_SPATIAL)
	var names: Array[String] = []
	for uniform: Dictionary in shader.get_shader_uniform_list():
		names.append(uniform["name"])
	for wanted: String in ["albedo_texture", "albedo_tint", "affine_amount", "fog_bands", "shade_uv_offset", "band_threshold", "band_dither"]:
		assert_has(names, wanted, "psx_cel exposes " + wanted + " (a parse error leaves the list empty)")
	var code: String = FileAccess.get_file_as_string(CEL_SHADER)
	assert_true(code.contains('#include "%s"' % COMMON_INCLUDE), "reuses psx_common")
	assert_true(code.contains("psx_snap("), "keeps the vertex snap")
	assert_true(code.contains("psx_fragment_uv()"), "keeps the affine warp")
	assert_true(code.contains("psx_fog_steps("), "keeps the stepped fog")
	assert_true(code.contains("psx_bayer4("), "dithers the band edge with the 4x4 Bayer pattern")
	assert_true(code.contains("void light()") and code.contains("step(band_threshold"), "two flat bands")


func test_outline_shader_pushes_a_snapped_hull_out_by_whole_pixels() -> void:
	var shader: Shader = load(OUTLINE_SHADER) as Shader
	assert_not_null(shader)
	var names: Array[String] = []
	for uniform: Dictionary in shader.get_shader_uniform_list():
		names.append(uniform["name"])
	assert_has(names, "outline_width_px")
	assert_has(names, "outline_color")
	var code: String = FileAccess.get_file_as_string(OUTLINE_SHADER)
	assert_true(code.contains("cull_front"), "draws the hull's back faces only")
	assert_true(code.contains('#include "%s"' % COMMON_INCLUDE))
	# Snap first, push out second: the line can never swim against the model.
	assert_lt(code.find("psx_snap("), code.find("outline_width_px /"), "snaps before pushing out")
