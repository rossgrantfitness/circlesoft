extends SceneTree
## One screenshot of the playable room with the shiba Red standing near Otis, for sharing progress
## with Ross. Needs a real renderer (not --headless):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##       -s res://tests/visual/capture_red_shiba_in_room.gd
## Writes docs/screenshots/red_shiba_in_room.png (the whole 1280x720 window). No game classes are
## named here (this script compiles before the autoloads exist); everything goes through the nodes.

const MAIN_SCENE: String = "res://scenes/core/main.tscn"
const OUTPUT_PATH: String = "res://../docs/screenshots/red_shiba_in_room.png"
const RED_SPOT: Vector3 = Vector3(3.9, 0.0, 2.0)
## Turned toward the room camera (three-quarter view), Otis beside her.
const RED_YAW_DEGREES: float = 40.0
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
	var player: Node3D = _room.get("player")
	player.global_position = RED_SPOT + Vector3(0.0, 0.02, 0.0)
	player.set("velocity", Vector3.ZERO)
	player.rotation_degrees.y = RED_YAW_DEGREES
	await _frames(SETTLE_FRAMES)
	var image: Image = root.get_texture().get_image()
	var err: Error = image.save_png(OUTPUT_PATH)
	print("saved %s (%s) error %d" % [OUTPUT_PATH, image.get_size(), err])
	quit(0 if err == OK else 1)


func _frames(count: int) -> void:
	for i: int in count:
		await process_frame
