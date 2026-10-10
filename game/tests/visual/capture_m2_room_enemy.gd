extends SceneTree
## Screenshot of an enemy standing in the test room challenging Red: the speech bubble with the
## Fight? choice. Needs a real renderer (not --headless):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##       -s res://tests/visual/capture_m2_room_enemy.gd
## Writes docs/screenshots/m2_room_enemy_challenge.png (the whole 1280x720 window).
## Held as plain nodes: this script is compiled before the autoloads exist, so it cannot name the
## game classes (they use DataDB).

const MAIN_SCENE: String = "res://scenes/core/main.tscn"
const OUT_PATH: String = "res://../docs/screenshots/m2_room_enemy_challenge.png"
const ENEMY_NODE: String = "GruntEnemy"
const CHOOSING_STATE: int = 4
const SETTLE_FRAMES: int = 60

var _room: Node = null


func _initialize() -> void:
	await process_frame
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	main.set("show_title", false)
	main.set("debug_overlay_enabled", false)
	root.add_child(main)
	await _frames(10)
	_room = main.call("get_room")
	var enemy: Node3D = _room.get_node(ENEMY_NODE)
	var facing: Vector3 = enemy.global_transform.basis.z
	var spot: Vector3 = enemy.global_position + Vector3(facing.x, 0.0, facing.z).normalized() * 1.4
	var player: Node3D = _room.get("player")
	player.global_position = Vector3(spot.x, 0.02, spot.z)
	player.set("velocity", Vector3.ZERO)
	player.rotation.y = atan2(-facing.x, -facing.z)
	await _frames(SETTLE_FRAMES)
	_room.get("interactor").call("try_interact")
	await _seconds(0.5)
	var guard: int = 0
	while guard < 60:
		var bubble: Node = _room.get("runner").call("get_current_bubble")
		if bubble != null and int(bubble.call("get_state")) == CHOOSING_STATE:
			break
		_room.get("runner").call("confirm")
		await _seconds(0.3)
		guard += 1
	await _seconds(0.6)
	await _frames(4)
	var image: Image = root.get_texture().get_image()
	var err: Error = image.save_png(OUT_PATH)
	print("saved ", OUT_PATH, " ", image.get_size(), " error ", err)
	quit(0 if err == OK else 1)


func _frames(count: int) -> void:
	for i: int in count:
		await process_frame


func _seconds(seconds: float) -> void:
	await create_timer(seconds).timeout
