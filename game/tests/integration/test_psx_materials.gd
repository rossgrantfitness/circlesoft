extends TestCase
## Milestone 1 step 6: the PSX test room. Loads headless, uses only PSX shader materials, and has
## the nodes the camera and player scripts plug into.

const ROOM_PATH: String = "res://scenes/debug/psx_test_room.tscn"
const SHADER_PREFIX: String = "res://shaders/psx_"
const FADE_SHADER: String = "res://shaders/psx_fade.gdshader"
const OCCLUDER_GROUP: StringName = &"fade_occluder"
const WARM_LIGHT_MIN_RED_OVER_BLUE: float = 1.5
const TALL_PILLAR_MIN_HEIGHT: float = 3.0
const WING_MIN_EXTRA_WIDTH: float = 6.0
const FRAME_WIDTH_UNITS: float = 10.0
const WARP_QUAD_MIN_SIZE: float = 6.0
const MAX_ROOM_TRIANGLES: int = 3500   # style guide: interior hard cap


func _room() -> Node3D:
	var room: Node3D = (load(ROOM_PATH) as PackedScene).instantiate() as Node3D
	own(room)   # not added to the tree: these tests only look at the scene's contents
	return room


func _meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		_meshes(child, out)


func _material_of(mesh_instance: MeshInstance3D, surface: int) -> Material:
	var override: Material = mesh_instance.get_surface_override_material(surface)
	if override != null:
		return override
	if mesh_instance.material_override != null:
		return mesh_instance.material_override
	return mesh_instance.mesh.surface_get_material(surface)


func test_room_loads_and_has_meshes() -> void:
	var meshes: Array[MeshInstance3D] = []
	_meshes(_room(), meshes)
	assert_gt(meshes.size(), 5)


func test_every_mesh_uses_a_psx_shader_material() -> void:
	var meshes: Array[MeshInstance3D] = []
	_meshes(_room(), meshes)
	for mesh_instance: MeshInstance3D in meshes:
		for surface: int in mesh_instance.mesh.get_surface_count():
			var material: ShaderMaterial = _material_of(mesh_instance, surface) as ShaderMaterial
			assert_not_null(material, "%s surface %d needs a ShaderMaterial" % [mesh_instance.name, surface])
			if material != null:
				assert_true(material.shader.resource_path.begins_with(SHADER_PREFIX),
						"%s uses %s" % [mesh_instance.name, material.shader.resource_path])
				assert_not_null(material.get_shader_parameter("albedo_texture"), "%s needs a texture" % mesh_instance.name)


func test_room_has_the_plug_in_points() -> void:
	var room: Node3D = _room()
	assert_true(room.get_node_or_null("PlayerSpawn") is Marker3D, "PlayerSpawn marker")
	assert_true(room.get_node_or_null("CameraRig") is Node3D, "CameraRig node")
	assert_true(room.get_node_or_null("CameraRig") is DioramaCamera, "diorama camera rig (it makes its own Camera3D at runtime)")
	assert_true(room.get_node_or_null("WorldEnvironment") is WorldEnvironment)
	assert_true(room.get_node_or_null("RoomLook") is PsxRoomLook, "fog settings")


func test_textures_cover_64_128_and_256() -> void:
	var sizes: Dictionary[int, bool] = {}
	var meshes: Array[MeshInstance3D] = []
	_meshes(_room(), meshes)
	for mesh_instance: MeshInstance3D in meshes:
		for surface: int in mesh_instance.mesh.get_surface_count():
			var material: ShaderMaterial = _material_of(mesh_instance, surface) as ShaderMaterial
			var texture: Texture2D = material.get_shader_parameter("albedo_texture") as Texture2D
			assert_le(texture.get_width(), 256)
			assert_ge(texture.get_width(), 64)
			sizes[texture.get_width()] = true
	assert_has(sizes, 64)
	assert_has(sizes, 128)
	assert_has(sizes, 256)


func test_lamp_is_warm_amber_with_a_light() -> void:
	var lights: Array[Node] = _room().find_children("*", "OmniLight3D", true, false)
	assert_eq(lights.size(), 1, "one lamp light")
	var light: OmniLight3D = lights[0] as OmniLight3D
	assert_gt(light.light_color.r / maxf(light.light_color.b, 0.01), WARM_LIGHT_MIN_RED_OVER_BLUE, "amber, not white")


func test_fog_is_set_up() -> void:
	var look: PsxRoomLook = _room().get_node("RoomLook") as PsxRoomLook
	assert_gt(look.fog_far, look.fog_near)
	assert_gt(look.fog_near, 0.0)


func test_pillar_is_tall_fades_and_is_marked_as_an_occluder() -> void:
	var pillar: MeshInstance3D = _room().get_node("Pillar") as MeshInstance3D
	assert_true(pillar.is_in_group(OCCLUDER_GROUP))
	assert_gt(pillar.get_aabb().size.y, TALL_PILLAR_MIN_HEIGHT)
	var material: ShaderMaterial = _material_of(pillar, 0) as ShaderMaterial
	assert_eq(material.shader.resource_path, FADE_SHADER)


func test_wing_is_wide_enough_that_the_camera_must_slide() -> void:
	var room: Node3D = _room()
	var floor_mesh: MeshInstance3D = room.get_node("Floor") as MeshInstance3D
	var wing: MeshInstance3D = room.get_node("WarpTestFloor") as MeshInstance3D
	var total_width: float = floor_mesh.get_aabb().size.x + wing.get_aabb().size.x
	assert_gt(total_width, FRAME_WIDTH_UNITS + WING_MIN_EXTRA_WIDTH - 1.0, "room is wider than one screen")


func test_warp_test_floor_is_one_big_unsubdivided_quad() -> void:
	var wing: MeshInstance3D = _room().get_node("WarpTestFloor") as MeshInstance3D
	assert_gt(wing.get_aabb().size.x, WARP_QUAD_MIN_SIZE)
	var arrays: Array = wing.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert_eq(vertices.size(), 4, "four corners only")


func test_room_stays_inside_the_triangle_budget() -> void:
	var meshes: Array[MeshInstance3D] = []
	_meshes(_room(), meshes)
	var triangles: int = 0
	for mesh_instance: MeshInstance3D in meshes:
		for surface: int in mesh_instance.mesh.get_surface_count():
			var arrays: Array = mesh_instance.mesh.surface_get_arrays(surface)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			triangles += indices.size() / 3
	assert_le(triangles, MAX_ROOM_TRIANGLES)
