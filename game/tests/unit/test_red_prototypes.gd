extends TestCase
## The Red style prototypes (docs/red_style_prototypes.md): every red_proto_<letter>.glb that exists
## must import, stay under the triangle caps (body 900, sword prop 150), use the shared 17-bone rig
## and keep its textures at 128 px or less. Works with however many prototypes are present.

const MODEL_DIR: String = "res://art/placeholder/characters/red_prototypes"
const MODEL_PREFIX: String = "red_proto_"
const BODY_TRI_CAP: int = 900
const SWORD_TRI_CAP: int = 150
const MAX_TEXTURE_PX: int = 128
const SWORD_MARKER: String = "sword"
const BONE_NAMES: PackedStringArray = [
	"root", "hips", "spine", "head", "ear_r", "ear_l", "tail", "upper_arm_r", "forearm_r", "upper_arm_l",
	"forearm_l", "thigh_r", "shin_r", "thigh_l", "shin_l", "weapon_socket", "prop_socket",
]


func _model_paths() -> Array[String]:
	var paths: Array[String] = []
	for file_name: String in DirAccess.get_files_at(MODEL_DIR):
		if file_name.begins_with(MODEL_PREFIX) and file_name.get_extension() == "glb":
			paths.append(MODEL_DIR.path_join(file_name))
	paths.sort()
	return paths


static func triangles_of(mesh: Mesh) -> int:
	var total: int = 0
	for surface: int in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(surface)
		var indices: Variant = arrays[Mesh.ARRAY_INDEX]
		if indices != null and (indices as PackedInt32Array).size() > 0:
			total += (indices as PackedInt32Array).size() / 3
		else:
			total += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return total


func test_at_least_three_prototypes_exist() -> void:
	assert_ge(_model_paths().size(), 3, "A, B and C should be present")


func test_each_prototype_imports_and_is_under_the_triangle_caps() -> void:
	for path: String in _model_paths():
		var scene: PackedScene = load(path) as PackedScene
		assert_not_null(scene, path + " should import")
		if scene == null:
			continue
		var root: Node = scene.instantiate()
		var body: int = 0
		var sword: int = 0
		for node: Node in root.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance: MeshInstance3D = node as MeshInstance3D
			if mesh_instance.mesh == null:
				continue
			if String(mesh_instance.name).to_lower().contains(SWORD_MARKER):
				sword += triangles_of(mesh_instance.mesh)
			else:
				body += triangles_of(mesh_instance.mesh)
		root.free()
		assert_gt(body, 0, path + " has a body mesh")
		assert_le(body, BODY_TRI_CAP, path + " body is over the triangle cap")
		assert_le(sword, SWORD_TRI_CAP, path + " sword is over the triangle cap")


func test_each_prototype_uses_the_shared_17_bone_rig() -> void:
	for path: String in _model_paths():
		var scene: PackedScene = load(path) as PackedScene
		if scene == null:
			continue
		var root: Node = scene.instantiate()
		var skeletons: Array[Node] = root.find_children("*", "Skeleton3D", true, false)
		assert_eq(skeletons.size(), 1, path + " should have one skeleton")
		if skeletons.size() == 1:
			var skeleton: Skeleton3D = skeletons[0] as Skeleton3D
			assert_eq(skeleton.get_bone_count(), BONE_NAMES.size(), path + " bone count")
			for bone_name: String in BONE_NAMES:
				assert_ge(skeleton.find_bone(bone_name), 0, path + " is missing bone " + bone_name)
		root.free()


func test_prototype_textures_are_128_px_or_less() -> void:
	for file_name: String in DirAccess.get_files_at(MODEL_DIR):
		if file_name.begins_with(MODEL_PREFIX) and file_name.get_extension() == "png":
			var texture: Texture2D = load(MODEL_DIR.path_join(file_name)) as Texture2D
			assert_not_null(texture, file_name)
			if texture != null:
				assert_le(texture.get_width(), MAX_TEXTURE_PX, file_name + " width")
				assert_le(texture.get_height(), MAX_TEXTURE_PX, file_name + " height")
