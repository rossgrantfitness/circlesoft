extends SceneTree
## Screenshot of the crew following Red through the first graybox test room (Otis and Mox on her
## trail, the pop-up icon over her head). Needs a real renderer (not --headless):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##       -s res://tests/visual/capture_m3_follow.gd
## Writes docs/screenshots/m3_follow.png (the whole 1280x720 window).
## Held as plain nodes: this script is compiled before the autoloads exist, so it cannot name the
## game classes (they use DataDB).

const MAIN_SCENE: String = "res://scenes/core/main.tscn"
const ROOM_SCENE: String = "res://scenes/rooms/test_a.tscn"
const OUT_PATH: String = "res://../docs/screenshots/m3_follow.png"
const START_SPOT: Vector3 = Vector3(3.4, 0.0, 2.3)
const WALK_TO: Vector3 = Vector3(-1.7, 0.0, 2.3)
const SETTLE_FRAMES: int = 60

var _room: Node = null


func _initialize() -> void:
	await process_frame
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	main.set("show_title", false)
	main.set("debug_overlay_enabled", false)
	main.set("start_scene", load(ROOM_SCENE))
	root.add_child(main)
	await _frames(10)
	_room = main.call("get_room")
	var player: Node3D = _room.get("player")
	# The patrolling grunt is in the room: keep it out of this shot.
	for enemy: Node in _room.get("encounters").call("enemies"):
		enemy.set("active", false)
		(enemy as Node3D).global_position = Vector3(8.0, 0.0, 3.0)
	player.set("read_engine_input", false)
	player.global_position = Vector3(START_SPOT.x, 0.02, START_SPOT.z)
	player.rotation.y = atan2(-1.0, 0.0)
	_room.get("party").call("seed_trail")
	await _frames(SETTLE_FRAMES)
	# Run west toward the ration pickup, so the crew trails out behind her.
	player.set("run_held", true)
	var guard: int = 0
	while guard < 600:
		var offset: Vector3 = WALK_TO - player.global_position
		offset.y = 0.0
		if offset.length() < 0.15:
			break
		player.set("stick", _stick_toward(offset.normalized()))
		await physics_frame
		guard += 1
	player.set("stick", Vector2.ZERO)
	player.set("run_held", false)
	await _seconds(0.9)
	_room.get("interactor").call("refresh")
	await _frames(12)
	var image: Image = root.get_texture().get_image()
	var err: Error = image.save_png(OUT_PATH)
	print("saved ", OUT_PATH, " ", image.get_size(), " error ", err)
	quit(0 if err == OK else 1)


func _stick_toward(direction: Vector3) -> Vector2:
	var cam: Camera3D = _room.get("camera_rig").call("get_camera")
	var forward: Vector3 = -cam.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right: Vector3 = cam.global_basis.x
	right.y = 0.0
	right = right.normalized()
	return Vector2(direction.dot(right), -direction.dot(forward))


func _frames(count: int) -> void:
	for i: int in count:
		await process_frame


func _seconds(seconds: float) -> void:
	await create_timer(seconds).timeout
