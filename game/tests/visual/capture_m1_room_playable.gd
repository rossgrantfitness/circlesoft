extends SceneTree
## Screenshot of the playable test room for sharing progress: Red standing behind the pillar (so it
## is dithered out), with the F1 PSX options overlay open. Needs a real renderer (not --headless):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##       -s res://tests/visual/capture_m1_room_playable.gd
## Writes docs/screenshots/m1_room_playable.png (path is relative to the game/ folder).

const MAIN_SCENE: String = "res://scenes/core/main.tscn"
const OUTPUT_PATH: String = "res://../docs/screenshots/m1_room_playable.png"
## Behind the pillar as seen from the camera, so the pillar sits between them.
const RED_SPOT: Vector3 = Vector3(1.3, 0.05, -0.3)
const SETTLE_FRAMES: int = 90
const OVERLAY_ACTION: StringName = &"debug_overlay"


func _initialize() -> void:
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	main.set("show_title", false)
	root.add_child(main)
	for i: int in 10:
		await process_frame
	var room: Node3D = main.get_node("PsxScreen/WorldViewport/World/PsxTestRoom")
	var player: Node3D = room.get("player")
	player.global_position = RED_SPOT
	for i: int in SETTLE_FRAMES:
		await process_frame
	var overlay: Node = main.get("overlay")
	var event: InputEventAction = InputEventAction.new()
	event.action = OVERLAY_ACTION
	event.pressed = true
	overlay.call("_input", event)
	for i: int in 10:
		await process_frame
	var image: Image = root.get_texture().get_image()
	var err: Error = image.save_png(OUTPUT_PATH)
	print("saved %s (%s), error %d" % [OUTPUT_PATH, image.get_size(), err])
	quit(0 if err == OK else 1)
