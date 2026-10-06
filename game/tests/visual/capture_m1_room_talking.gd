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

var _room: FieldRoom = null


func _initialize() -> void:
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	main.set("show_title", false)
	main.set("debug_overlay_enabled", false)
	root.add_child(main)
	await _frames(10)
	_room = main.get_node("PsxScreen/WorldViewport/World/PsxTestRoom") as FieldRoom
	await _stand(Vector3(3.2, 0.0, 0.8), OTIS_SPOT)
	await _save("m1_npcs_in_room.png")

	_room.interactor.try_interact()
	await _seconds(1.6)
	await _save("m1_room_talking.png")
	_room.runner.stop()
	await _seconds(0.5)

	await _stand(Vector3(6.9, 0.0, 1.4), MOX_SPOT)
	_room.interactor.try_interact()
	await _seconds(0.4)
	var guard: int = 0
	while guard < 30:
		var bubble: SpeechBubble = _room.runner.get_current_bubble()
		if bubble != null and not bubble.get_choices().is_empty():
			break
		_room.runner.confirm()
		await _seconds(0.25)
		_room.runner.confirm()   # finish typing, then move on at the next loop
		await _seconds(0.15)
		guard += 1
	await _seconds(0.8)
	await _save("m1_room_choice.png")
	_room.runner.stop()
	await _seconds(0.5)

	await _stand(Vector3(3.2, 0.0, 0.8), OTIS_SPOT)
	_room.field_menu.open()
	await _seconds(1.0)
	await _save("m1_room_menu.png")
	quit(0)


func _frames(count: int) -> void:
	for i: int in count:
		await process_frame


func _seconds(seconds: float) -> void:
	await create_timer(seconds).timeout


func _stand(spot: Vector3, look_at: Vector3) -> void:
	if _room.field_menu.is_open():
		_room.field_menu.close()
	var player: PlayerController = _room.player
	player.global_position = spot + Vector3(0.0, 0.02, 0.0)
	player.velocity = Vector3.ZERO
	var direction: Vector3 = look_at - spot
	player.rotation.y = PlayerMotion.yaw_for_direction(Vector3(direction.x, 0.0, direction.z).normalized())
	await _frames(SETTLE_FRAMES)


func _save(file_name: String) -> void:
	await _frames(4)
	var image: Image = root.get_texture().get_image()
	var err: Error = image.save_png(OUT_DIR + file_name)
	print("saved %s (%s) error %d" % [file_name, image.get_size(), err])
