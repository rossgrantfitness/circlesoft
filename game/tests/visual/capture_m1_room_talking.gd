extends SceneTree
## Screenshots of the playable room with NPCs, the interact prompt, speech bubbles, a choice and the
## field menu, for sharing progress with Ross. Needs a real renderer (not --headless):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##       -s res://tests/visual/capture_m1_room_talking.gd
## Writes docs/screenshots/m1_npcs_in_room.png, m1_room_talking.png, m1_room_choice.png and
## m1_room_menu.png (the whole 1280x720 window).

const MAIN_SCENE: String = "res://scenes/core/main.tscn"
const OUT_DIR: String = "res://../docs/screenshots/"
const OTIS_SPOT: Vector3 = Vector3(4.4, 0.0, 0.8)
const MOX_SPOT: Vector3 = Vector3(5.8, 0.0, 1.4)
const SETTLE_FRAMES: int = 60
const CHOOSING_STATE: int = 4

## Held as plain nodes: this script is compiled before the autoloads exist, so it cannot name the
## game classes (they use DataDB).
var _room: Node = null


func _initialize() -> void:
	await process_frame
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	main.set("show_title", false)
	main.set("debug_overlay_enabled", false)
	root.add_child(main)
	await _frames(10)
	_room = main.get_node("PsxScreen/WorldViewport/World/PsxTestRoom")
	await _stand(Vector3(3.2, 0.0, 0.8), OTIS_SPOT)
	await _save("m1_npcs_in_room.png")

	_room.get("interactor").call("try_interact")
	await _seconds(1.6)
	await _save("m1_room_talking.png")
	_room.get("runner").call("stop")
	await _seconds(0.5)

	await _stand(Vector3(6.9, 0.0, 1.4), MOX_SPOT)
	_room.get("interactor").call("try_interact")
	await _seconds(0.4)
	var guard: int = 0
	while guard < 60:
		var bubble: Node = _room.get("runner").call("get_current_bubble")
		if bubble != null and not (bubble.call("get_choices") as Array).is_empty():
			break
		_room.get("runner").call("confirm")   # finishes typing, or moves on
		await _seconds(0.3)
		guard += 1
	# The choice line types its question first; wait until the choices show (state 4 = CHOOSING).
	var waited: int = 0
	while waited < 100 and int(_room.get("runner").call("get_current_bubble").call("get_state")) != CHOOSING_STATE:
		await _seconds(0.3)
		waited += 1
	await _seconds(0.5)
	await _save("m1_room_choice.png")
	_room.get("runner").call("stop")
	await _seconds(0.5)

	await _stand(Vector3(3.2, 0.0, 0.8), OTIS_SPOT)
	_room.get("field_menu").call("open")
	await _seconds(1.0)
	await _save("m1_room_menu.png")
	quit(0)


func _frames(count: int) -> void:
	for i: int in count:
		await process_frame


func _seconds(seconds: float) -> void:
	await create_timer(seconds).timeout


func _stand(spot: Vector3, look_at: Vector3) -> void:
	var menu: Node = _room.get("field_menu")
	if menu.call("is_open"):
		menu.call("close")
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
