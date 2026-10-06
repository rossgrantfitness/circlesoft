extends SceneTree
## In-game screenshot of the three NPC blockouts (Otis, Mox, the old Zero) standing in the test room,
## with Red (whatever model player.tscn currently has) beside them, through the real PSX screen at the
## game camera. Needs a real renderer (not --headless):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##       -s res://tests/visual/capture_npcs_in_room.gd
## Writes docs/screenshots/npcs_in_room_v2.png (whole 1280x720 window), plus
## npcs_in_room_v2_talking.png (a speech bubble over Otis, to check the bubble sits at his head).
## Names no game classes: it is compiled before the autoloads exist.

const MAIN_SCENE: String = "res://scenes/core/main.tscn"
const OUT_DIR: String = "res://../docs/screenshots/"
const OTIS_SPOT: Vector3 = Vector3(4.4, 0.0, 0.8)
const SETTLE_FRAMES: int = 60

var _room: Node = null


func _initialize() -> void:
	await process_frame
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	main.set("show_title", false)
	main.set("debug_overlay_enabled", false)
	root.add_child(main)
	await _frames(10)
	_room = main.get_node("PsxScreen/WorldViewport/World/PsxTestRoom")
	await _stand(Vector3(3.3, 0.0, 0.8), OTIS_SPOT)
	await _save("npcs_in_room_v2.png")
	_room.get("interactor").call("try_interact")
	await _seconds(1.6)
	await _save("npcs_in_room_v2_talking.png")
	_room.get("runner").call("stop")
	quit(0)


func _frames(count: int) -> void:
	for i: int in count:
		await process_frame


func _seconds(seconds: float) -> void:
	await create_timer(seconds).timeout


func _stand(spot: Vector3, look_at: Vector3) -> void:
	var player: Node3D = _room.get("player")
	player.global_position = spot + Vector3(0.0, 0.02, 0.0)
	player.set("velocity", Vector3.ZERO)
	var direction: Vector3 = look_at - spot
	player.rotation.y = atan2(direction.x, direction.z)
	await _frames(SETTLE_FRAMES)


func _save(file_name: String) -> void:
	await _frames(4)
	var image: Image = root.get_texture().get_image()
	var err: Error = image.save_png(OUT_DIR + file_name)
	print("saved %s (%s) error %d" % [file_name, image.get_size(), err])
