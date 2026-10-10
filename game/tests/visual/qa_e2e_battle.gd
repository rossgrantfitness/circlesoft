extends SceneTree
## End-to-end QA playthrough with a real renderer and real (injected) button presses, the way Ross plays:
##   1. title -> Battle Test -> first encounter -> fight to the end (Auto-Timing on, mashing confirm) -> title
##   2. Start Demo -> walk up to the grunt challenger -> talk -> Fight! -> win -> back in the room, grunt gone,
##      then talk to Otis to prove input still works
##   3. Tough fight with the party at 1 HP and Auto-Timing off -> lose -> Retry -> the fight restarts
## Run: xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##          -s res://tests/visual/qa_e2e_battle.gd
## Prints QA PASS / QA FAIL lines and exits 1 on any failure. Names no game classes (autoloads load after compile).

const MAIN_SCENE: String = "res://scenes/core/main.tscn"
const SHOTS: String = "res://../docs/screenshots/"
const ST_TITLE: int = 1
const ST_ROOM: int = 2
const ST_BATTLE: int = 3

var _main: Node
var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	_main = (load(MAIN_SCENE) as PackedScene).instantiate()
	root.add_child(_main)
	var config: Node = root.get_node("Config")
	await _frames(30)
	_check(_state() == ST_TITLE, "boots to the title")

	# --- 1. Battle Test from the title -------------------------------------------------------------------------
	config.set("auto_timing", true)
	await _open_title_menu()
	await _press("move_down", 10)      # Battle Test
	_check(int(_main.call("get_title").call("get_cursor_index")) == 1, "cursor on Battle Test")
	await _press("confirm", 60)        # opens the picker
	_shot("m2_e2e_picker")
	await _press("confirm", 10)        # first encounter
	var entered: bool = await _wait_state(ST_BATTLE, 600)
	_check(entered, "Battle Test starts a fight")
	await _frames(120)
	_shot("m2_e2e_battle_menu")
	var back: bool = await _mash_until_state(ST_TITLE, 180.0, "m2_e2e_battle_mid")
	_check(back, "fight from Battle Test finishes and returns to the title")

	# --- 2. Fight from the room ---------------------------------------------------------------------------------
	await _frames(30)
	await _open_title_menu()
	await _press("confirm", 60)        # Start Demo
	var in_room: bool = await _wait_state(ST_ROOM, 600)
	_check(in_room, "Start Demo loads the room")
	await _frames(60)
	var room: Node = _main.call("get_room")
	var fights: Object = room.get("fights") if room != null else null
	var grunt: Node3D = fights.call("enemy_for", "grunt") if fights != null else null
	_check(grunt != null, "the grunt challenger is in the room")
	if grunt != null:
		var player: Node3D = room.get("player")
		var toward: Vector3 = Vector3(0.0, 0.0, 0.6)
		player.global_position = grunt.global_position + toward
		player.look_at(grunt.global_position, Vector3.UP, true)
		await _frames(20)
		var red_before: Vector3 = player.global_position
		await _press("interact", 20)
		_shot("m2_e2e_room_challenge")
		var fought: bool = false
		for i: int in 40:
			if _state() == ST_BATTLE:
				fought = true
				break
			await _press("confirm", 15)
		_check(fought, "talking to the grunt and picking Fight! starts the battle")
		var home: bool = await _mash_until_state(ST_ROOM, 240.0, "")
		_check(home, "the room fight finishes and returns to the room")
		await _frames(40)
		room = _main.call("get_room")
		var player_after: Node3D = room.get("player") if room != null else null
		_check(player_after != null and player_after.global_position.distance_to(red_before) < 0.3, "Red is back where she stood")
		var fights_after: Object = room.get("fights") if room != null else null
		var grunt_after: Node3D = fights_after.call("enemy_for", "grunt") if fights_after != null else null
		_check(grunt_after == null or not grunt_after.visible or not grunt_after.is_inside_tree(), "the beaten grunt is gone")
		_shot("m2_e2e_room_after_win")
		# Input still works: open and close the field menu.
		await _press("menu", 30)
		_check(_ui_busy(), "the field menu opens after a fight")
		await _press("cancel", 20)
		await _press("cancel", 20)
		await _frames(20)
		_check(not _ui_busy(), "the field menu closes again")

	# --- 3. Lose, then Retry --------------------------------------------------------------------------------------
	config.set("auto_timing", false)
	var gs: Node = root.get_node("GameState")
	for id: String in ["red", "otis", "mox"]:
		if gs.has_method("update_member"):
			gs.call("update_member", id, {"hp": 1})
	_main.call("start_battle", "ambush_no_exit", &"title")
	var started: bool = await _wait_state(ST_BATTLE, 600)
	_check(started, "tough fight starts")
	# Just pick Attack each turn (never press Clutch) until the game over screen offers Retry.
	var t0: int = Time.get_ticks_msec()
	var saw_retry_restart: bool = false
	var battle_node: Node = _main.get("_battle")
	while Time.get_ticks_msec() - t0 < 180000:
		await _press("confirm", 12)
		var now_battle: Node = _main.get("_battle")
		if now_battle != null and now_battle != battle_node and _state() == ST_BATTLE:
			saw_retry_restart = true
			break
		if _state() == ST_TITLE:
			break
	_check(saw_retry_restart, "losing offers Retry and Retry restarts the fight")
	_shot("m2_e2e_retry")

	print("QA SUMMARY: %d failure(s)" % _failures)
	quit(0 if _failures == 0 else 1)


func _open_title_menu() -> void:
	for i: int in 20:
		var title: Node = _main.call("get_title")
		if title != null and bool(title.call("is_menu_ready")):
			return
		await _press("start", 30)
	_check(false, "title menu opens")


func _state() -> int:
	return int(_main.call("get_state"))


func _ui_busy() -> bool:
	for node: Node in root.get_tree().get_nodes_in_group("ui_modal"):
		if node.is_inside_tree() and (node as CanvasItem == null or (node as CanvasItem).is_visible_in_tree()):
			return true
	return false


func _press(action: String, settle_frames: int) -> void:
	var down: InputEventAction = InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	await _frames(3)
	var up: InputEventAction = InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(settle_frames)


func _wait_state(target: int, max_frames: int) -> bool:
	for i: int in max_frames:
		if _state() == target:
			return true
		await process_frame
	return _state() == target


## Mashes confirm (menus, targets, victory screen) until Main reaches `target`.
func _mash_until_state(target: int, max_seconds: float, mid_shot: String) -> bool:
	var t0: int = Time.get_ticks_msec()
	var shot_taken: bool = mid_shot == ""
	while Time.get_ticks_msec() - t0 < int(max_seconds * 1000.0):
		if _state() == target:
			return true
		await _press("confirm", 10)
		if not shot_taken and Time.get_ticks_msec() - t0 > 6000:
			_shot(mid_shot)
			shot_taken = true
	print("  (timed out; state=%d)" % _state())
	return _state() == target


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _shot(shot_name: String) -> void:
	var image: Image = root.get_texture().get_image()
	image.save_png(SHOTS + shot_name + ".png")


func _check(ok: bool, what: String) -> void:
	print(("QA PASS  " if ok else "QA FAIL  ") + what)
	if not ok:
		_failures += 1
