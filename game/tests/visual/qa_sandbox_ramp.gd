extends SceneTree
## QA: a look at the back ramp and ledge from the arena floor, and from behind the ledge, with Red placed by hand.
## Names no game classes. Writes docs/screenshots/qa_sandbox_ramp_*.png.
## Run: xvfb-run -a -s "-screen 0 1920x1080x24" godot --path game --rendering-driver opengl3 \
##          -s res://tests/visual/qa_sandbox_ramp.gd -- --sandbox

const MAIN_SCENE: String = "res://scenes/core/main.tscn"
const SHOTS: String = "res://../docs/screenshots/"


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
	var camera: Object = (sandbox.call("get_camera") as Object)
	for i: int in 60:
		await process_frame
	# Freeze the other fighters out of the way: Red alone, on the arena floor, facing the ramp.
	for enemy: Variant in sandbox.call("get_enemies") as Array:
		(enemy as Node3D).visible = false
	player.call("reset_to", Transform3D(Basis.from_euler(Vector3(0.0, deg_to_rad(0.0), 0.0)), Vector3(-9.0, 0.1, -6.0)))
	for i: int in 30:
		await process_frame
	camera.call("recenter")
	for i: int in 40:
		await process_frame
	root.get_texture().get_image().save_png(SHOTS + "qa_sandbox_ramp_floor.png")
	player.call("reset_to", Transform3D(Basis.from_euler(Vector3(0.0, deg_to_rad(180.0), 0.0)), Vector3(-9.0, 0.1, -19.0)))
	for i: int in 60:
		await process_frame
	root.get_texture().get_image().save_png(SHOTS + "qa_sandbox_ramp_behind.png")
	print("QA INFO  ramp shots saved; Red at %s" % str(player.global_position))
	quit(0)
