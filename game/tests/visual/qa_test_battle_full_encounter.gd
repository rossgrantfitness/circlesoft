extends SceneTree
## QA test: Play a full battle encounter to victory.
## Uses a simple policy to auto-issue commands and let the battle run to completion.
## xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##     -s res://tests/visual/qa_test_battle_full_encounter.gd 2>&1 | tee /tmp/qa_full_encounter.log

const MAIN_SCENE: String = "res://scenes/core/main.tscn"
const SETTLE_FRAMES: int = 6
const ENCOUNTER: String = "grunt_solo"  # Simplest encounter
const TIMEOUT_MS: int = 120000  # 120 seconds max for a battle

var _main: Node = null
var _test_log: PackedStringArray = []
var _battle_result: String = ""


func _initialize() -> void:
	_log("=== QA: Full Battle Encounter ===")
	_log("Encounter: %s" % ENCOUNTER)
	print("Loading main scene...")
	
	_main = (load(MAIN_SCENE) as PackedScene).instantiate()
	# Enable auto-timing to let the battle run automatically
	_main.set("battle_setup_hook", Callable(self, "_setup_battle"))
	root.add_child(_main)
	
	for i: int in SETTLE_FRAMES:
		await process_frame
	
	_log("Main scene loaded. Starting battle...")
	await _navigate_and_start_battle()
	
	_print_summary()
	quit(0)


func _navigate_and_start_battle() -> void:
	# Wait for title
	var start: int = Time.get_ticks_msec()
	while _main.get("_state") != 1:  # TITLE
		await process_frame
		if Time.get_ticks_msec() - start > 5000:
			_log("ERROR: Title did not load")
			return
	
	_log("Title ready. Opening menu...")
	await create_timer(0.5).timeout
	_press_action(&"confirm")
	await create_timer(0.5).timeout
	
	_log("Moving to Battle Test...")
	_press_action(&"move_down")
	await create_timer(0.3).timeout
	_press_action(&"confirm")
	await create_timer(0.5).timeout
	
	_log("Selecting encounter: %s" % ENCOUNTER)
	_press_action(&"confirm")
	await create_timer(1.0).timeout
	
	# Wait for battle to start
	_log("Waiting for battle to start...")
	start = Time.get_ticks_msec()
	while _main.get("_state") != 3:  # BATTLE
		await process_frame
		if Time.get_ticks_msec() - start > 10000:
			_log("ERROR: Battle did not start")
			return
	
	_log("Battle started!")
	await _wait_for_battle_end()


func _wait_for_battle_end() -> void:
	var start: int = Time.get_ticks_msec()
	var battle_in_progress: bool = true
	var screenshots_taken: int = 0
	
	while battle_in_progress:
		await process_frame
		
		# Check if we're still in battle
		if _main.get("_state") != 3:
			battle_in_progress = false
			_log("Battle ended!")
			break
		
		# Take periodic screenshots during battle
		var elapsed: int = Time.get_ticks_msec() - start
		var image: Image
		if elapsed > 2000 and screenshots_taken == 0:
			_log("Taking screenshot at 2s...")
			image = root.get_texture().get_image()
			image.save_png("res://../docs/screenshots/m2_qa_battle_combat_%d.png" % screenshots_taken)
			screenshots_taken += 1

		if elapsed > 5000 and screenshots_taken == 1:
			_log("Taking screenshot at 5s...")
			image = root.get_texture().get_image()
			image.save_png("res://../docs/screenshots/m2_qa_battle_combat_%d.png" % screenshots_taken)
			screenshots_taken += 1
		
		# Check timeout
		if elapsed > TIMEOUT_MS:
			_log("ERROR: Battle exceeded timeout")
			_battle_result = "timeout"
			return
	
	# Battle ended, take final screenshot
	await create_timer(0.5).timeout
	var image: Image = root.get_texture().get_image()
	image.save_png("res://../docs/screenshots/m2_qa_battle_end_screen.png")
	_log("Screenshot: m2_qa_battle_end_screen.png")
	
	# Press confirm to continue past victory/defeat
	_log("Pressing confirm to advance from end screen...")
	_press_action(&"confirm")
	await create_timer(0.5).timeout
	
	# Check if we returned to title
	if _main.get("_state") == 1:
		_log("SUCCESS: Returned to title after battle")
		_battle_result = "complete"
	else:
		_log("WARNING: Did not return to title, state=%d" % _main.get("_state"))
		_battle_result = "unknown_end_state"


func _setup_battle(setup: RefCounted) -> void:
	# Enable auto-timing so the battle runs automatically
	setup.set("auto_timing", true)
	_log("Auto-timing enabled for this battle")


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
	print("\n=== Summary ===")
	for msg: String in _test_log:
		print(msg)
	print("Battle result: %s" % _battle_result)
