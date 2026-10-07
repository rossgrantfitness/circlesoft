class_name ExplorationKit
extends RefCounted
## Helpers for the exploration tests (doors, pickups, crates, climbs, the crew, map enemies): load a
## room with its input and text made manual, stand Red somewhere, steer her with the stick, finish
## a conversation, and a stand-in router that records the doors used.

const TEST_A: String = "res://scenes/rooms/test_a.tscn"
const TEST_B: String = "res://scenes/rooms/test_b.tscn"
const TEST_ROOM: String = "res://scenes/debug/psx_test_room.tscn"
const KEY_ITEM: String = "kasp_access_card"


## A stand-in for the SceneRouter: records go_to calls.
class RouterStub extends Node:
	var calls: Array = []
	var busy: bool = false

	func is_busy() -> bool:
		return busy

	func go_to(room_id: String, spawn_id: String = "") -> bool:
		calls.append([room_id, spawn_id])
		return true


## Takes the "busy" lock off any bubble or screen an earlier test left on the shared UI stage, so one
## test's leftovers cannot stop Red from using a door in the next. Call before building a room.
static func drop_stale_modals(test: TestCase) -> void:
	for node: Node in test.tree.get_nodes_in_group(UiStage.MODAL_GROUP):
		node.remove_from_group(UiStage.MODAL_GROUP)


## Loads a room into the root: Red's input off, text instant, camera live, followers on if the room has them.
static func load_room(test: TestCase, path: String) -> FieldRoom:
	drop_stale_modals(test)
	var room: FieldRoom = (load(path) as PackedScene).instantiate() as FieldRoom
	test.add_to_root(room)
	prepare(room)
	return room


## Switches a room's input to manual (use on a room that was added some other way).
static func prepare(room: FieldRoom) -> void:
	room.player.read_engine_input = false
	room.interactor.read_engine_input = false
	room.camera_rig.auto_update = true
	room.runner.manual_ticks = true
	room.runner.chars_per_second_override = 100000.0


## A Main that starts straight in `path` (no title) with an instant battle stage, plus a SceneRouter
## wired to it with no fade timing. Returns {main, router}.
static func make_main_and_router(test: TestCase, path: String) -> Dictionary:
	drop_stale_modals(test)
	var main: Main = (load(BattleFlowKit.MAIN_SCENE) as PackedScene).instantiate() as Main
	main.show_title = false
	main.debug_overlay_enabled = false
	main.battle_transitions = false
	main.start_scene = load(path) as PackedScene
	test.add_to_root(main)
	var router: Node = (load("res://scripts/core/scene_router.gd") as GDScript).new() as Node
	router.set("main", main)
	router.set("instant", true)
	test.add_to_root(router)
	return {"main": main, "router": router}


static func ticks(test: TestCase, count: int) -> void:
	for i: int in count:
		await test.tree.physics_frame


## Puts Red on the floor at `spot`, facing `look_at`, and lets the physics settle.
static func stand(test: TestCase, room: FieldRoom, spot: Vector3, look_at: Vector3) -> void:
	var player: PlayerController = room.player
	player.global_position = Vector3(spot.x, 0.02 + spot.y, spot.z)
	player.velocity = Vector3.ZERO
	var direction: Vector3 = look_at - spot
	direction.y = 0.0
	if direction.length() > 0.001:
		player.rotation.y = PlayerMotion.yaw_for_direction(direction.normalized())
	await ticks(test, 4)
	room.interactor.refresh()


## The stick value that pushes Red toward a point on the floor, through the room's camera.
static func stick_toward(room: FieldRoom, goal: Vector3) -> Vector2:
	var cam_basis: Basis = room.camera_rig.get_camera().global_basis
	var offset: Vector3 = goal - room.player.global_position
	offset.y = 0.0
	if offset.length() < 0.001:
		return Vector2.ZERO
	var direction: Vector3 = offset.normalized()
	return Vector2(direction.dot(PlayerMotion.flat_right(cam_basis)), -direction.dot(PlayerMotion.flat_forward(cam_basis)))


## Walks Red to a point with the stick; true if she got within `arrive` of it in time.
static func walk_to(test: TestCase, room: FieldRoom, goal: Vector3, run: bool = false, arrive: float = 0.3, max_ticks: int = 900) -> bool:
	room.player.run_held = run
	for i: int in max_ticks:
		var offset: Vector3 = goal - room.player.global_position
		offset.y = 0.0
		if offset.length() < arrive:
			room.player.stick = Vector2.ZERO
			return true
		room.player.stick = stick_toward(room, goal)
		await test.tree.physics_frame
	room.player.stick = Vector2.ZERO
	return false


## Clicks through whatever conversation is running.
static func finish_conversation(room: FieldRoom) -> void:
	var guard: int = 0
	while room.runner.is_running() and guard < 400:
		room.runner.confirm()
		room.runner.tick(0.5)
		guard += 1
	for i: int in 6:
		room.runner.tick(0.1)


## The text of every line the runner has shown for the last message (read from the prop).
static func joined(lines: Array[String]) -> String:
	return "\n".join(lines)


static func prop(room: FieldRoom, node_name: String) -> Node:
	return room.get_node(node_name)
