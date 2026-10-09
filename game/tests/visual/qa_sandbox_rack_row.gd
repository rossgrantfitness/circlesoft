extends SceneTree
## QA: Red placed at the back of the arena, by the sword-stand row, to see where the stand rings show on screen.
## Names no game classes. Writes docs/screenshots/qa_sandbox_rack_row_*.png.
## Run: xvfb-run -a -s "-screen 0 1920x1080x24" godot --path game --rendering-driver opengl3 --resolution 1920x1080 \
##          -s res://tests/visual/qa_sandbox_rack_row.gd -- --sandbox

const MAIN_SCENE: String = "res://scenes/core/main.tscn"
const SHOTS: String = "res://../docs/screenshots/"
const SPOTS: Array = [["back_centre", Vector3(0.0, 0.1, 15.0)], ["back_left", Vector3(-7.5, 0.1, 15.0)], ["back_right", Vector3(7.5, 0.1, 15.0)]]


func _initialize() -> void:
	_run()


func _run() -> void:
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	root.add_child(main)
	var sandbox: Node = null
	for i: int in 600:
		await process_frame
		sandbox = get_first_node_in_group(&"combat_sandbox")
		if sandbox != null and sandbox.call("get_player") != null:
			break
	var player: Node3D = sandbox.call("get_player") as Node3D
	var camera: Object = sandbox.call("get_camera") as Object
	for i: int in 60:
		await process_frame
	for spot: Array in SPOTS:
		player.call("reset_to", Transform3D(Basis.from_euler(Vector3(0.0, deg_to_rad(180.0), 0.0)), spot[1] as Vector3))
		camera.call("recenter")
		camera.call("snap")
		for i: int in 90:
			await process_frame
		root.get_texture().get_image().save_png(SHOTS + "qa_sandbox_rack_row_%s.png" % str(spot[0]))
		print("QA INFO  saved %s with Red at %s" % [str(spot[0]), str(player.global_position)])
	quit(0)
