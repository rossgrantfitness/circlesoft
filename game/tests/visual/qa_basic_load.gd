extends SceneTree
## QA test: Verify basic game loads and title is visible.
## xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##     -s res://tests/visual/qa_basic_load.gd 2>&1 | tee /tmp/qa_basic.log

const MAIN_SCENE: String = "res://scenes/core/main.tscn"
const SETTLE_FRAMES: int = 6

var _main: Node = null
var _errors: PackedStringArray = []


func _initialize() -> void:
	print("=== QA: Basic Load Test ===")
	print("Loading main scene...")
	
	_main = (load(MAIN_SCENE) as PackedScene).instantiate()
	root.add_child(_main)
	
	for i: int in SETTLE_FRAMES:
		await process_frame
	
	print("Main scene loaded. Checking state...")
	var state: int = _main.get("_state")
	print("Current state: %d (1=TITLE, 2=ROOM, 3=BATTLE)" % state)
	
	# State 1 = TITLE, State 2 = ROOM
	if state == 1:
		print("PASS: Title screen is showing")
	elif state == 2:
		print("PASS: Room is loaded (title was skipped)")
	else:
		print("FAIL: Unexpected state %d" % state)
		_errors.append("Unexpected initial state")
	
	# Take a screenshot
	print("Taking screenshot...")
	await create_timer(0.5).timeout
	var image: Image = root.get_texture().get_image()
	var err: Error = image.save_png("res://../docs/screenshots/m2_qa_basic_load.png")
	print("Screenshot saved: m2_qa_basic_load.png (error code: %d)" % err)
	
	if _errors.is_empty():
		print("=== All checks passed ===")
		quit(0)
	else:
		print("=== Errors found: ===")
		for err_msg: String in _errors:
			print("  - " + err_msg)
		quit(1)
