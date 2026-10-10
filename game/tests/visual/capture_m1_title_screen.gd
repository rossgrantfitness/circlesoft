extends SceneTree
## One screenshot of the demo title screen with the menu open, for sharing progress with Ross.
## Needs a real renderer (not --headless):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##       -s res://tests/visual/capture_m1_title_screen.gd
## Writes docs/screenshots/m1_title_screen.png (the whole 1280x720 window).
## Pass `-- --press-start` to capture the PRESS START moment instead (menu closed).

const TITLE_SCENE: String = "res://scenes/ui/title_screen.tscn"
const OUTPUT_PATH: String = "res://../docs/screenshots/m1_title_screen.png"
const OUTPUT_PATH_PRESS_START: String = "res://../builds/screenshots/m1_title_press_start.png"
const PRESS_START_FLAG: String = "--press-start"
const INTRO_WAIT_S: float = 1.2
const MENU_WAIT_S: float = 0.8
const SETTLE_FRAMES: int = 6
const CONFIRM_ACTION: StringName = &"confirm"


func _initialize() -> void:
	var title: Node = (load(TITLE_SCENE) as PackedScene).instantiate()
	root.add_child(title)
	await create_timer(INTRO_WAIT_S).timeout
	var press_start_only: bool = PRESS_START_FLAG in OS.get_cmdline_user_args()
	if not press_start_only:
		var press: InputEventAction = InputEventAction.new()
		press.action = CONFIRM_ACTION
		press.pressed = true
		root.push_input(press)
		await create_timer(MENU_WAIT_S).timeout
	for i: int in SETTLE_FRAMES:
		await process_frame
	var path: String = OUTPUT_PATH_PRESS_START if press_start_only else OUTPUT_PATH
	var image: Image = root.get_texture().get_image()
	var err: Error = image.save_png(path)
	print("saved %s (%s), error %d" % [path, image.get_size(), err])
	quit(0 if err == OK else 1)
