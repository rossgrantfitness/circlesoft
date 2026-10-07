extends SceneTree
## Screenshot of a map enemy chasing Red in the first graybox test room: the grunt has spotted her
## and is coming (the crew stands behind her). Needs a real renderer (not --headless):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##       -s res://tests/visual/capture_m3_field_enemy.gd
## Writes docs/screenshots/m3_field_enemy.png (the whole 1280x720 window).
## Held as plain nodes: this script is compiled before the autoloads exist, so it cannot name the
## game classes (they use DataDB).

const MAIN_SCENE: String = "res://scenes/core/main.tscn"
const ROOM_SCENE: String = "res://scenes/rooms/test_a.tscn"
const OUT_PATH: String = "res://../docs/screenshots/m3_field_enemy.png"
const CHASE_STATE: int = 1
const RED_SPOT: Vector3 = Vector3(5.4, 0.0, 1.8)
const GRUNT_SPOT: Vector3 = Vector3(0.9, 0.0, 1.2)
const SETTLE_FRAMES: int = 45

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
	player.set("read_engine_input", false)
	player.global_position = Vector3(RED_SPOT.x, 0.02, RED_SPOT.z)
	player.rotation.y = atan2(-1.0, 0.0)  # looks west, toward the grunt
	_room.get("party").call("seed_trail")
	var grunt: Node3D = _room.get("encounters").call("enemies")[0]
	grunt.set("active", false)
	grunt.global_position = Vector3(GRUNT_SPOT.x, 0.02, GRUNT_SPOT.z)
	grunt.rotation.y = deg_to_rad(90.0)  # facing east, toward Red
	await _frames(SETTLE_FRAMES)
	grunt.set("active", true)
	var guard: int = 0
	while int(grunt.call("get_state")) != CHASE_STATE and guard < 120:
		await physics_frame
		guard += 1
	# Let it run a few steps toward her, then freeze the moment.
	await _seconds(0.4)
	var image: Image = root.get_texture().get_image()
	var err: Error = image.save_png(OUT_PATH)
	print("saved ", OUT_PATH, " ", image.get_size(), " chase state ", grunt.call("get_state"), " error ", err)
	quit(0 if err == OK else 1)


func _frames(count: int) -> void:
	for i: int in count:
		await process_frame


func _seconds(seconds: float) -> void:
	await create_timer(seconds).timeout
