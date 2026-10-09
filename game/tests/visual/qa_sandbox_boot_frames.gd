extends SceneTree
## QA: the first frames after the sandbox boots, to see whether the teal corner shapes show before the camera settles.
## Names no game classes. Writes docs/screenshots/qa_sandbox_boot_f<N>.png for N in the list below.
## Run: xvfb-run -a -s "-screen 0 1920x1080x24" godot --path game --rendering-driver opengl3 \
##          -s res://tests/visual/qa_sandbox_boot_frames.gd -- --sandbox

const MAIN_SCENE: String = "res://scenes/core/main.tscn"
const SHOTS: String = "res://../docs/screenshots/"
const SHOT_FRAMES: Array[int] = [1, 2, 4, 8, 16, 40]


func _initialize() -> void:
	_run()


func _run() -> void:
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	root.add_child(main)
	var sandbox: Node = null
	var after_boot: int = 0
	for i: int in 600:
		await process_frame
		if sandbox == null:
			sandbox = get_first_node_in_group(&"combat_sandbox")
			continue
		after_boot += 1
		if SHOT_FRAMES.has(after_boot):
			var image: Image = root.get_texture().get_image()
			image.save_png(SHOTS + "qa_sandbox_boot_f%d.png" % after_boot)
			print("QA INFO  saved boot frame %d" % after_boot)
		if after_boot == SHOT_FRAMES[-1]:
			var full: Image = root.get_texture().get_image()
			print("QA INFO  window %s" % str(full.get_size()))
			full.get_region(Rect2i(0, 0, 640, 300)).save_png(SHOTS + "qa_sandbox_hud_crop_top_left.png")
			full.get_region(Rect2i(full.get_width() - 640, full.get_height() - 200, 640, 200)).save_png(SHOTS + "qa_sandbox_hud_crop_bottom_right.png")
		if after_boot >= SHOT_FRAMES[-1]:
			break
	quit(0)
