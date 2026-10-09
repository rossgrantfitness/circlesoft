extends SceneTree
## Screenshot of the dash charge pips (Ross 2026-10-09, dash on charges): Red dashes three times in the running sandbox, then a
## moment later the pips show two spent, one half refilled. Needs a real renderer (not --headless):
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path game --rendering-driver opengl3 -s res://tests/visual/capture_dash_charges.gd
## Writes docs/screenshots/dash_charges_hud.png. Names no game classes (it compiles before the autoloads exist).

const MAIN_SCENE: String = "res://scenes/core/main.tscn"
const OUT_FILE: String = "res://../docs/screenshots/dash_charges_hud.png"

var _main: Node = null


func _frames(count: int) -> void:
	for i: int in count:
		await process_frame


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	_main = (load(MAIN_SCENE) as PackedScene).instantiate()
	_main.set("debug_overlay_enabled", false)
	root.add_child(_main)
	await _frames(40)
	var sandbox: Node = _main.call("get_sandbox") as Node
	if sandbox == null:
		push_error("capture: the sandbox did not start")
		quit(1)
		return
	var player: Node = sandbox.call("get_player") as Node
	var huds: Array[Node] = root.find_children("SandboxHud", "Control", true, false)
	if player == null or huds.is_empty():
		push_error("capture: no player or HUD")
		quit(1)
		return
	huds[0].set("listen_input", false)
	player.set("input_locked", false)
	# Three dashes, chained (a press every 0.4 s of real time, whatever the frame rate).
	for i: int in 3:
		player.call("press", &"dash")
		var until: int = Time.get_ticks_msec() + 400
		while Time.get_ticks_msec() < until:
			await process_frame
		print("dash ", i + 1, " ", player.call("get_dash_charges"))
	# Let the refill run until the next pip is about half full.
	var charges: Dictionary = player.call("get_dash_charges") as Dictionary
	var deadline: int = Time.get_ticks_msec() + 6000
	while float(charges.get("fraction", 0.0)) < 0.5 and Time.get_ticks_msec() < deadline:
		await process_frame
		charges = player.call("get_dash_charges") as Dictionary
	print("charges: ", charges)
	await _frames(4)
	var image: Image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUT_FILE))
	print("saved ", OUT_FILE, " ", image.get_size())
	quit(0)
