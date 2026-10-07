extends SceneTree
## Milestone 3 end-to-end QA in a real renderer with injected button presses, the way Ross plays:
##   1. title -> Battle Test -> a fight to the end -> title
##   2. title -> New Game (default name) -> wakes in Red's home in Harrow Landing
##   3. save at the home lamp (slot 1)
##   4. Lamp Square -> general store: buy one item, leave, field menu still opens and closes
##   5. back to the title -> Continue -> back in Harrow where the save was made
## Saves go to a fresh user:// folder so real saves are never touched.
## Run: xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##          -s res://tests/visual/qa_e2e_m3.gd
## Prints QA PASS / QA FAIL lines; exits 1 on any failure. Names no game classes.

const MAIN_SCENE: String = "res://scenes/core/main.tscn"
const SHOTS: String = "res://../docs/screenshots/"
const ST_TITLE: int = 1
const ST_ROOM: int = 2
const ST_BATTLE: int = 3

var _main: Node
var _failures: int = 0
var _saved_slot: int = -1
var _saved_slots: Array[int] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	var saves: Node = root.get_node("SaveManager")
	saves.set("save_dir", "user://qa_saves_%d/" % Time.get_ticks_usec())
	saves.connect("saved", func(slot: int) -> void: _saved_slots.append(slot))
	_main = (load(MAIN_SCENE) as PackedScene).instantiate()
	root.add_child(_main)
	var config: Node = root.get_node("Config")
	var gs: Node = root.get_node("GameState")
	await _frames(30)
	_check(_state() == ST_TITLE, "boots to the title")

	# --- 1. Battle Test ---------------------------------------------------------------------------------------
	config.set("auto_timing", true)
	await _open_title_menu()
	await _pick_title_item("battle_test")
	await _press("confirm", 10)
	_check(await _wait_state(ST_BATTLE, 600), "Battle Test starts a fight")
	_check(await _mash_until_state(ST_TITLE, 180.0), "the fight ends and returns to the title")

	# --- 2. New Game ---------------------------------------------------------------------------------------------
	await _open_title_menu()
	await _pick_title_item("new_game")
	var entry: Node = _main.call("get_title").call("get_name_entry")
	var entry_open: bool = false
	for i: int in 120:
		if entry != null and bool(entry.call("is_open")):
			entry_open = true
			break
		await process_frame
	_check(entry_open, "New Game opens the name entry")
	if entry_open:
		await _press("ui_accept_name", 1)  # no-op action name; the entry is accepted below
		entry.call("submit")
	_check(await _wait_state(ST_ROOM, 900), "New Game loads a room")
	await _frames(60)
	_check(_room_id() == "harrow_home", "New Game starts in Red's home (got '%s')" % _room_id())
	_check(str(gs.call("get_hero_name")) == "Red", "default hero name is Red")
	await _settle_dialogue(20.0)
	_shot("m3_e2e_home")

	# --- 3. Save at the home lamp ----------------------------------------------------------------------------------
	var lamp: Node3D = _first_in_group("save_lamp")
	_check(lamp != null, "Red's home has a save lamp")
	if lamp != null:
		await _stand_by(lamp)
		await _press("interact", 30)
		for i: int in 60:
			if _saved_slots.has(1):
				break
			await _press("confirm", 12)
		_check(_saved_slots.has(1), "saving at the lamp writes slot 1 (saved: %s)" % str(_saved_slots))
		await _settle_dialogue(10.0)
		_check(bool(saves.call("has_any_save")), "the save is on disk")

	# --- 4. Lamp Square -> store: buy one thing ---------------------------------------------------------------------
	await _go("harrow_square")
	_check(_room_id() == "harrow_square", "Lamp Square loads")
	_shot("m3_e2e_square")
	await _go("harrow_store")
	_check(_room_id() == "harrow_store", "the general store loads")
	var counter: Node3D = _first_in_group("shop_counter")
	_check(counter != null, "the store has a counter")
	if counter != null:
		gs.call("add_credits", 300)  # pocket money, as if the first job had paid
		var credits_before: int = int(gs.call("get_credits"))
		var items_before: int = _bag_total(gs)
		await _stand_by(counter)
		await _press("interact", 40)
		_check(_ui_busy(), "the shop opens")
		_shot("m3_e2e_shop")
		await _press("confirm", 20)   # Buy
		await _press("confirm", 20)   # first item
		await _press("confirm", 20)   # quantity 1
		await _press("confirm", 20)   # any "buy it?" prompt
		var bought: bool = int(gs.call("get_credits")) < credits_before or _bag_total(gs) > items_before
		_check(bought, "buying an item spends credits (%d -> %d)" % [credits_before, int(gs.call("get_credits"))])
		for i: int in 6:
			if not _ui_busy():
				break
			await _press("cancel", 20)
		_check(not _ui_busy(), "leaving the shop frees Red")
	await _press("menu", 30)
	_check(_ui_busy(), "the field menu opens in town")
	for i: int in 4:
		if not _ui_busy():
			break
		await _press("cancel", 20)
	_check(not _ui_busy(), "the field menu closes")

	# --- 5. Title -> Continue ---------------------------------------------------------------------------------------
	_main.call("go_to_title")
	_check(await _wait_state(ST_TITLE, 300), "back to the title")
	await _open_title_menu()
	_check(bool(_main.call("get_title").call("is_item_enabled", "continue")), "Continue is lit after saving")
	await _pick_title_item("continue")
	_check(await _wait_state(ST_ROOM, 900), "Continue loads the game")
	await _frames(60)
	var newest: int = int(saves.call("newest_slot"))
	var newest_room: String = str((saves.call("read_file", newest) as Dictionary).get("game", {}).get("location", {}).get("room", ""))
	_check(newest_room != "" and _room_id() == newest_room, "Continue loads the newest save's room (slot %d: '%s', got '%s')" % [newest, newest_room, _room_id()])
	_shot("m3_e2e_continue")

	print("QA SUMMARY: %d failure(s)" % _failures)
	quit(0 if _failures == 0 else 1)


# --- helpers ---------------------------------------------------------------------------------------------------

func _state() -> int:
	return int(_main.call("get_state"))


func _room_id() -> String:
	var room: Node = _main.call("get_room")
	return str(room.get("room_id")) if room != null and is_instance_valid(room) else ""


func _first_in_group(group: String) -> Node3D:
	for node: Node in get_nodes_in_group(group):
		if node is Node3D and node.is_inside_tree():
			return node as Node3D
	return null


func _bag_total(gs: Node) -> int:
	var total: int = 0
	for id: Variant in gs.call("get_item_ids"):
		total += int(gs.call("item_count", str(id)))
	return total


func _stand_by(target: Node3D) -> void:
	var room: Node = _main.call("get_room")
	var player: Node3D = room.get("player")
	var offset: Vector3 = Vector3(0.0, 0.0, 0.7)
	player.global_position = Vector3(target.global_position.x, player.global_position.y, target.global_position.z) + offset
	player.look_at(Vector3(target.global_position.x, player.global_position.y, target.global_position.z), Vector3.UP, true)
	await _frames(20)


func _go(room_id: String) -> void:
	var router: Node = root.get_node("SceneRouter")
	var spawn: String = str(router.call("default_spawn", room_id))
	await router.call("go_to", room_id, spawn)
	await _frames(40)
	await _settle_dialogue(15.0)


## Presses confirm while a bubble or scene holds the UI, so story scenes on arrival play out.
func _settle_dialogue(max_seconds: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while _ui_busy() and Time.get_ticks_msec() - t0 < int(max_seconds * 1000.0):
		await _press("confirm", 10)
	await _frames(10)


func _ui_busy() -> bool:
	var stage: Variant = root.get_node_or_null("UiStage")
	for node: Node in get_nodes_in_group("ui_modal"):
		if node.is_inside_tree() and (not node is CanvasItem or (node as CanvasItem).is_visible_in_tree()):
			return true
	return false


func _open_title_menu() -> void:
	for i: int in 20:
		var title: Node = _main.call("get_title")
		if title != null and bool(title.call("is_menu_ready")):
			return
		await _press("start", 30)
	_check(false, "title menu opens")


func _pick_title_item(id: String) -> void:
	var title: Node = _main.call("get_title")
	var ids: Array = title.call("get_item_ids")
	var target: int = ids.find(id)
	_check(target >= 0, "title has '%s'" % id)
	for i: int in 12:
		if int(title.call("get_cursor_index")) == target:
			break
		await _press("move_down", 8)
	_check(int(title.call("get_cursor_index")) == target, "cursor on '%s'" % id)
	await _press("confirm", 60)


func _press(action: String, settle_frames: int) -> void:
	if not InputMap.has_action(action):
		await _frames(settle_frames)
		return
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


func _mash_until_state(target: int, max_seconds: float) -> bool:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(max_seconds * 1000.0):
		if _state() == target:
			return true
		await _press("confirm", 10)
	print("  (timed out; state=%d)" % _state())
	return _state() == target


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _shot(shot_name: String) -> void:
	root.get_texture().get_image().save_png(SHOTS + shot_name + ".png")


func _check(ok: bool, what: String) -> void:
	print(("QA PASS  " if ok else "QA FAIL  ") + what)
	if not ok:
		_failures += 1
