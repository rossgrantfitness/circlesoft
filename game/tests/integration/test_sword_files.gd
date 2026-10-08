extends TestCase
## Ross's six swords, split from the sheet (scripts/tools/split_swords.py): each file's origin is the middle of the grip, the
## blade runs up +Y, textures are 512 px or smaller, and nothing was lost from the sheet (706 triangles in all).

const DIR: String = "res://art/final/weapons/"
const SWORDS: Dictionary = {
	"sword_katana_cyan": {"tris": 128, "blade": 0.6},
	"sword_heavy_duty": {"tris": 194, "blade": 0.6},
	"sword_hook_cyan": {"tris": 104, "blade": 0.55},
	"sword_glass_core": {"tris": 104, "blade": 0.5},
	"sword_machete": {"tris": 50, "blade": 0.45},
	"sword_twin_orange": {"tris": 126, "blade": 0.4}}
const SHEET_TRIANGLES: int = 706
const MAX_TEXTURE_PX: int = 512


func _sword(name: String) -> MeshInstance3D:
	var packed: PackedScene = load(DIR + name + ".glb") as PackedScene
	assert_not_null(packed, name + " should import")
	var model: Node = packed.instantiate()
	own(model)
	var meshes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
	assert_eq(meshes.size(), 1, name + " is one mesh")
	return meshes[0] as MeshInstance3D


func test_every_sword_has_its_grip_at_the_origin_and_its_blade_along_plus_y() -> void:
	for name: String in SWORDS:
		var mesh_instance: MeshInstance3D = _sword(name)
		var box: AABB = mesh_instance.mesh.get_aabb()
		assert_gt(box.end.y, float(SWORDS[name]["blade"]), name + ": the blade reaches up from the grip")
		assert_lt(box.end.y, 0.85, name + ": not longer than a sword")
		assert_lt(box.position.y, -0.05, name + ": the pommel sits behind the grip")
		assert_gt(box.position.y, -0.35, name + ": the grip is near the middle of the handle, not the tip")
		assert_gt(box.end.y, 1.8 * -box.position.y, name + ": more blade than handle")
		var centre: Vector3 = box.get_center()
		assert_lt(absf(centre.x), 0.12, name + ": the grip is on the sword's axis (x)")
		assert_lt(absf(centre.z), 0.05, name + ": and (z)")
		assert_lt(box.size.z, 0.12, name + ": blades are thin front to back")


func test_nothing_was_lost_from_the_sheet() -> void:
	var total: int = 0
	for name: String in SWORDS:
		var mesh: Mesh = _sword(name).mesh
		var tris: int = (mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		assert_eq(tris, int(SWORDS[name]["tris"]), name + " triangles")
		total += tris
	assert_eq(total, SHEET_TRIANGLES, "the six swords add up to Ross's 706")


func test_the_twin_orange_blade_keeps_its_two_floating_shards() -> void:
	# the shards float on its centre line, past the antennae (below the hilt once the blade points up)
	var box: AABB = _sword("sword_twin_orange").mesh.get_aabb()
	assert_lt(box.position.y, -0.2, "the shards hang 0.2 m or more below the grip")
	assert_lt(absf(box.get_center().x), 0.06, "on the sword's centre line")


func test_textures_are_512_or_smaller_and_keep_their_pbr_maps() -> void:
	for name: String in SWORDS:
		var material: ShaderMaterial = _sword(name).mesh.surface_get_material(0) as ShaderMaterial
		assert_not_null(material, name)
		var albedo: Texture2D = material.get_shader_parameter("albedo_texture") as Texture2D
		assert_not_null(albedo, name + " albedo")
		assert_le(albedo.get_width(), MAX_TEXTURE_PX)
		assert_le(albedo.get_height(), MAX_TEXTURE_PX)
		assert_ge(albedo.get_width(), 64)
		assert_not_null(material.get_shader_parameter("orm_texture") as Texture2D, name + " metallic-roughness")
