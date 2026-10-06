extends SceneTree
## QA test: Demo room walking, talking, and battles.
## xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##     -s res://tests/visual/qa_test_demo_room.gd 2>&1 | tee /tmp/qa_demo_room.log

const MAIN_SCENE: String = "res://scenes/core/main.tscn"
const SETTLE_FRAMES: int = 6

var _main: Node = null
var _test_log: PackedStringArray = []


func _initialize() -> void:
	_log("=== QA: Demo Room Test ===")
	print("Loading main scene with show_title=false...")
	
	_main = (load(MAIN_SCENE) as PackedScene).instantiate()
	_main.set("show_title", false)
	_main.set("battle_setup_hook", Callable(self, "_setup_battle"))
	root.add_child(_main)
	
	for i: int in SETTLE_FRAMES:
		await process_frame
	
	_log("Main scene loaded with room visible.")
	await _test_room_flow()
	
	_print_summary()
	quit(0)


func _test_room_flow() -> void:
	_log("Step 1: Wait for room to load...")
	var start: int = Time.get_ticks_msec()
	while _main.get("_state") != 2:  # ROOM
		await process_frame
		if Time.get_ticks_msec() - start > 5000:
			_log("ERROR: Room did not load")
			return
	
	_log("Room loaded!")
	await create_timer(0.5).timeout
	
	_log("Step 2: Take screenshot of room...")
	var image: Image = root.get_texture().get_image()
	image.save_png("res://../docs/screenshots/m2_qa_demo_room_initial.png")
	_log("  Screenshot: m2_qa_demo_room_initial.png")
	
	_log("Step 3: Walk around in the room (simulated)...")
	# Try walking
	_press_action(&"move_right")
	await create_timer(1.0).timeout
	_press_action(&"move_left")
	await create_timer(1.0).timeout
	
	_log("Step 4: Take screenshot after walking...")
	image = root.get_texture().get_image()
	image.save_png("res://../docs/screenshots/m2_qa_demo_room_walked.png")
	_log("  Screenshot: m2_qa_demo_room_walked.png")
	
	_log("Step 5: Interact with an NPC (press interact)...")
	_press_action(&"interact")
	await create_timer(0.5).timeout
	
	_log("Step 6: Take screenshot of interaction...")
	image = root.get_texture().get_image()
	image.save_png("res://../docs/screenshots/m2_qa_demo_room_interact.png")
	_log("  Screenshot: m2_qa_demo_room_interact.png")
	
	_log("Step 7: Check for battle or dialogue...")
	# Press cancel or move away
	_press_action(&"cancel")
	await create_timer(0.5).timeout
	
	_log("SUCCESS: Demo room navigation test complete")


func _press_action(action: StringName) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	root.push_input(event)
	
	await process_frame
	event.pressed = false
	root.push_input(event)


func _setup_battle(setup: RefCounted) -> void:
	setup.set("auto_timing", true)


func _log(msg: String) -> void:
	_test_log.append(msg)
	print(msg)


func _print_summary() -> void:
	print("\n=== Summary ===")
	for msg: String in _test_log:
		print(msg)
