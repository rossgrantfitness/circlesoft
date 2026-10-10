extends SceneTree
## QA test: Navigate title menu and battle test picker.
## xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##     -s res://tests/visual/qa_test_battle_test_menu.gd 2>&1 | tee /tmp/qa_menu_test.log

const MAIN_SCENE: String = "res://scenes/core/main.tscn"
const SETTLE_FRAMES: int = 6

var _main: Node = null
var _test_log: PackedStringArray = []


func _initialize() -> void:
	_log("=== QA: Battle Test Menu Navigation ===")
	print("Loading main scene...")
	
	_main = (load(MAIN_SCENE) as PackedScene).instantiate()
	root.add_child(_main)
	
	for i: int in SETTLE_FRAMES:
		await process_frame
	
	_log("Main scene loaded.")
	await _test_flow()
	
	_print_summary()
	quit(0)


func _test_flow() -> void:
	_log("Step 1: Take screenshot of initial title...")
	await create_timer(0.8).timeout
	var image: Image = root.get_texture().get_image()
	image.save_png("res://../docs/screenshots/m2_qa_title_initial.png")
	_log("  Screenshot: m2_qa_title_initial.png")
	
	_log("Step 2: Press confirm to open menu...")
	_press_action(&"confirm")
	await create_timer(0.6).timeout
	
	image = root.get_texture().get_image()
	image.save_png("res://../docs/screenshots/m2_qa_title_menu_open.png")
	_log("  Screenshot: m2_qa_title_menu_open.png")
	
	_log("Step 3: Move down to Battle Test...")
	_press_action(&"move_down")
	await create_timer(0.3).timeout
	
	_log("Step 4: Take screenshot with cursor on Battle Test...")
	image = root.get_texture().get_image()
	image.save_png("res://../docs/screenshots/m2_qa_title_battle_test_selected.png")
	_log("  Screenshot: m2_qa_title_battle_test_selected.png")
	
	_log("Step 5: Press confirm on Battle Test...")
	_press_action(&"confirm")
	await create_timer(0.6).timeout
	
	_log("Step 6: Verify battle test picker opened...")
	image = root.get_texture().get_image()
	image.save_png("res://../docs/screenshots/m2_qa_battle_picker.png")
	_log("  Screenshot: m2_qa_battle_picker.png")
	
	_log("Step 7: Press confirm to select first encounter (grunt_solo)...")
	_press_action(&"confirm")
	await create_timer(1.0).timeout
	
	_log("Step 8: Wait for battle to start...")
	var start_time: int = Time.get_ticks_msec()
	while _main.get("_state") != 3:  # State.BATTLE = 3
		await process_frame
		if Time.get_ticks_msec() - start_time > 10000:
			_log("ERROR: Battle did not start within 10 seconds")
			return
	
	_log("Step 9: Battle started! Taking screenshot...")
	await create_timer(1.0).timeout
	image = root.get_texture().get_image()
	image.save_png("res://../docs/screenshots/m2_qa_battle_scene.png")
	_log("  Screenshot: m2_qa_battle_scene.png")
	
	_log("Step 10: Let battle run for a bit, then close...")
	await create_timer(3.0).timeout
	
	_log("SUCCESS: Battle test menu navigation complete")


func _press_action(action: StringName) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	root.push_input(event)
	
	await process_frame
	event.pressed = false
	root.push_input(event)


func _log(msg: String) -> void:
	_test_log.append(msg)
	print(msg)


func _print_summary() -> void:
	print("\n=== Test Summary ===")
	for msg: String in _test_log:
		print(msg)
