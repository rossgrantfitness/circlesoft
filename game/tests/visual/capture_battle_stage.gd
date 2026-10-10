extends SceneTree
## Screenshots of the battle stage for sharing progress. Needs a real renderer (not --headless):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##       -s res://tests/visual/capture_battle_stage.gd
## Writes docs/screenshots/m2_battle_stage.png (the party against 4 enemies) and, when the HUD scene exists,
## m2_battle_stage_hud.png. Names no game classes (this script compiles before the autoloads exist); everything
## goes through load() and call(). Extra command-line words after "--" pick other shots:
##   --shot=moments writes m2_battle_moments.png (lunge, recoil, flag)  --shot=static writes m2_static_transition.png

const MAIN_SCENE: String = "res://scenes/core/main.tscn"
const STAGE_SCENE: String = "res://scenes/battle/battle_scene.tscn"
const STUB: String = "res://tests/fixtures/battle_stage/stub_battle_controller.gd"
const OUT_DIR: String = "res://../docs/screenshots/"
const SETTLE_FRAMES: int = 45


func _initialize() -> void:
	var shot: String = "stage"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			shot = arg.trim_prefix("--shot=")
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	main.set("show_title", false)
	main.set("debug_overlay_enabled", false)
	root.add_child(main)
	for i: int in 6:
		await process_frame
	var screen: Node = main.get_node("PsxScreen")
	var stage: Node = screen.call("load_world", load(STAGE_SCENE) as PackedScene)
	stage.set("transitions_enabled", false)
	var stub: RefCounted = (load(STUB) as GDScript).new() as RefCounted
	stub.set("tree", self)
	stage.call("attach_controller", stub)
	stage.call("_on_battle_started", stub.call("snapshot"))
	for i: int in SETTLE_FRAMES:
		await process_frame
	if shot == "stage":
		_save("m2_battle_stage.png")
	elif shot == "moments":
		await _moments(stage, stub)
	elif shot == "static":
		await _static(stage)
	quit(0)


func _save(file: String) -> void:
	var image: Image = root.get_texture().get_image()
	var err: Error = image.save_png(OUT_DIR + file)
	print("saved %s (%s), error %d" % [file, image.get_size(), err])


func _moments(stage: Node, stub: RefCounted) -> void:
	var action: Dictionary = stub.call("make_action", "red", "attack", ["e1"], 700, "red", "attack", 400, 800, 1200)
	stage.call("_on_action_started", action)
	for i: int in 30:
		await process_frame
	_save("m2_battle_moments_a.png")


func _static(stage: Node) -> void:
	var layer: Node = stage.get("static_layer")
	layer.call("set_progress", 0.6)
	for i: int in 12:
		await process_frame
	_save("m2_static_transition.png")
