extends TestCase
## Run-and-jump follow-up: the PSX test room has crates, a ledge and a raised platform to jump on.
## Everything is PSX-shaded (test_psx_materials covers that), solid on layer 1, and low enough that
## a ~1.2 unit jump gets Red onto it from the ground or from the piece below it.

const ROOM_PATH: String = "res://scenes/debug/psx_test_room.tscn"
const GROUP: StringName = &"jumpable"
const JUMP_HEIGHT: float = 1.2
## A comfortable step: a jump has to beat it by at least this much (no precision platforming).
const MIN_JUMP_MARGIN: float = 0.2
const CRATE_SIZE: float = 0.8
const EPSILON: float = 0.01


func _room() -> Node3D:
	var room: Node3D = (load(ROOM_PATH) as PackedScene).instantiate() as Node3D
	own(room)
	return room


func _top(mesh_instance: MeshInstance3D) -> float:
	return mesh_instance.position.y + mesh_instance.mesh.get_aabb().size.y * 0.5


func _bottom(mesh_instance: MeshInstance3D) -> float:
	return mesh_instance.position.y - mesh_instance.mesh.get_aabb().size.y * 0.5


func test_room_has_crates_ledge_platform_and_a_reward() -> void:
	var room: Node3D = _room()
	for piece: String in ["StackCrateA", "StackCrateB", "StackCrateC", "BackLedge", "WingPlatform", "RewardCrate"]:
		var mesh_instance: MeshInstance3D = room.get_node_or_null(piece) as MeshInstance3D
		assert_not_null(mesh_instance, piece + " exists")
		if mesh_instance != null:
			assert_true(mesh_instance.is_in_group(GROUP), piece + " is in the jumpable group")


func test_every_jumpable_has_solid_collision_on_layer_1() -> void:
	var room: Node3D = _room()
	var body: StaticBody3D = room.get_node("Collision") as StaticBody3D
	assert_eq(body.collision_layer & 1, 1, "world body is on layer 1")
	var pieces: Array[Node] = []
	for child: Node in room.get_children():
		if child.is_in_group(GROUP):
			pieces.append(child)
	assert_ge(pieces.size(), 6)
	for piece: Node in pieces:
		var mesh_instance: MeshInstance3D = piece as MeshInstance3D
		var shape_node: CollisionShape3D = body.get_node_or_null(String(piece.name) + "Shape") as CollisionShape3D
		assert_not_null(shape_node, "%s has a collision shape" % piece.name)
		if shape_node == null:
			continue
		assert_false(shape_node.disabled, "%s collision is on" % piece.name)
		assert_eq(shape_node.position, mesh_instance.position, "%s collision sits on its mesh" % piece.name)
		var box: BoxShape3D = shape_node.shape as BoxShape3D
		assert_not_null(box, "%s collision is a box" % piece.name)
		if box != null:
			assert_eq(box.size, mesh_instance.mesh.get_aabb().size, "%s collision matches its mesh" % piece.name)


func test_every_step_is_within_a_comfortable_jump() -> void:
	var room: Node3D = _room()
	var ground_pieces: Array[String] = ["StackCrateA", "StackCrateB", "BackLedge", "WingPlatform"]
	for piece: String in ground_pieces:
		var mesh_instance: MeshInstance3D = room.get_node(piece) as MeshInstance3D
		assert_almost_eq(_bottom(mesh_instance), 0.0, EPSILON, piece + " rests on the floor")
		assert_le(_top(mesh_instance), JUMP_HEIGHT - MIN_JUMP_MARGIN, piece + " is jumpable from the ground")
	var low: MeshInstance3D = room.get_node("StackCrateB") as MeshInstance3D
	var stacked: MeshInstance3D = room.get_node("StackCrateC") as MeshInstance3D
	assert_almost_eq(_bottom(stacked), _top(low), EPSILON, "crate C sits on crate B")
	assert_almost_eq(stacked.position.x, low.position.x, EPSILON)
	assert_almost_eq(stacked.position.z, low.position.z, EPSILON)
	assert_le(_top(stacked) - _top(low), JUMP_HEIGHT - MIN_JUMP_MARGIN, "the top crate is a jump from the one below")
	assert_almost_eq(low.mesh.get_aabb().size.y, CRATE_SIZE, EPSILON, "crates are 0.8 tall")


func test_reward_sits_on_top_of_the_platform() -> void:
	var room: Node3D = _room()
	var platform: MeshInstance3D = room.get_node("WingPlatform") as MeshInstance3D
	var reward: MeshInstance3D = room.get_node("RewardCrate") as MeshInstance3D
	assert_almost_eq(_bottom(reward), _top(platform), EPSILON, "reward rests on the platform")
	assert_gt(reward.position.x, 5.0, "the platform is in the wing")


func test_jumpables_do_not_block_the_pillar_fade_test() -> void:
	# The fade test stands Red behind the pillar from the camera, i.e. toward -x/-z of it.
	# Keep new pieces a clear distance from the pillar's footprint and the spawn.
	var room: Node3D = _room()
	var pillar: Node3D = room.get_node("Pillar") as Node3D
	var spawn: Node3D = room.get_node("PlayerSpawn") as Node3D
	for piece: Node in room.get_children():
		if not piece.is_in_group(GROUP):
			continue
		var at: Vector3 = (piece as Node3D).position
		var flat_to_pillar: float = Vector2(at.x - pillar.position.x, at.z - pillar.position.z).length()
		var flat_to_spawn: float = Vector2(at.x - spawn.position.x, at.z - spawn.position.z).length()
		assert_gt(flat_to_pillar, 1.5, "%s stays clear of the pillar" % piece.name)
		assert_gt(flat_to_spawn, 1.5, "%s stays clear of the spawn" % piece.name)
