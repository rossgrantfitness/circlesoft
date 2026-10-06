extends SceneTree
## Lineup of the four enemy placeholders (and the three party models for scale) in the battle set, front on.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##       -s res://tests/visual/capture_battle_lineup.gd
## Writes docs/screenshots/m2_enemy_lineup.png. Names no game classes (compiled before the autoloads exist).

const MAIN_SCENE: String = "res://scenes/core/main.tscn"
const STAGE_SCENE: String = "res://scenes/battle/battle_scene.tscn"
const STUB: String = "res://tests/fixtures/battle_stage/stub_battle_controller.gd"
const OUT: String = "res://../docs/screenshots/m2_enemy_lineup.png"
const ORDER: Array[String] = ["e1", "e3", "e2", "e4", "red", "otis", "mox"]
const SPACING: float = 0.88
const ROW_Z: float = 0.6
const PUSH: float = 2.0


func _initialize() -> void:
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
	stage.call("attach_controller", stub)
	stage.call("_on_battle_started", stub.call("snapshot"))
	var start_x: float = -SPACING * float(ORDER.size() - 1) / 2.0
	for i: int in ORDER.size():
		var view: Node3D = stage.call("get_view", ORDER[i]) as Node3D
		view.call("set_home", Vector3(start_x + SPACING * float(i), 0.0, ROW_Z), 0.0)
	(stage.get("markers_root") as Node3D).visible = false
	var rig: Node = stage.get("camera_rig")
	rig.set("push_amount", PUSH)
	for i: int in 40:
		await process_frame
	var image: Image = root.get_texture().get_image()
	var err: Error = image.save_png(OUT)
	print("saved %s (%s), error %d" % [OUT, image.get_size(), err])
	quit(0)
