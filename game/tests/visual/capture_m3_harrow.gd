extends SceneTree
## Screenshots of Harrow Landing's graybox rooms (placeholder art): Lamp Square, the docks, the
## checkpoint, Red's home, the courier office with its job board, a line of dialogue, the bar.
## Needs a real renderer (not --headless):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##       -s res://tests/visual/capture_m3_harrow.gd
## Writes docs/screenshots/m3_harrow_*.png (the whole 1280x720 window).
## Held as plain nodes: this script is compiled before the autoloads exist, so it cannot name the
## game classes (they use DataDB).

const MAIN_SCENE: String = "res://scenes/core/main.tscn"
const DIR: String = "res://scenes/rooms/harrow/"
const OUT: String = "res://../docs/screenshots/m3_harrow_%s.png"
const SETTLE_FRAMES: int = 70
const CHOOSING_STATE: int = 4

# name, room, Red at (x, z), Red's yaw in degrees, story beat, flags, action
const SHOTS: Array = [
	["square", "harrow_square", Vector2(6.0, 2.6), 180.0, "b1_night", "", ""],
	["square_east", "harrow_square", Vector2(16.0, 2.6), 180.0, "b1_night", "", ""],
	["docks", "harrow_docks", Vector2(12.0, 2.0), 180.0, "b1_night", "", ""],
	["checkpoint", "harrow_checkpoint", Vector2(8.0, 4.4), 180.0, "b1_night", "", ""],
	["home", "harrow_home", Vector2(3.0, 2.6), 180.0, "b1_night", "", ""],
	["courier", "harrow_courier", Vector2(2.2, 2.6), 270.0, "b1_night", "", ""],
	["board", "harrow_courier", Vector2(1.9, 2.5), 270.0, "b1_night", "", "board"],
	["talk", "harrow_square", Vector2(12.4, 7.9), 180.0, "b1_night", "", "talk:Bettor"],
	["bar", "harrow_bar", Vector2(5.0, 4.4), 180.0, "b2_otis_joined", "otis_joined", ""],
	["store", "harrow_store", Vector2(3.5, 3.0), 180.0, "b1_night", "", ""],
]


func _initialize() -> void:
	await process_frame
	for shot: Array in SHOTS:
		await _take(shot)
	quit(0)


func _take(shot: Array) -> void:
	var state: Node = root.get_node("GameState")
	state.call("reset")
	state.call("set_story_beat", str(shot[4]))
	for flag: String in str(shot[5]).split(",", false):
		state.call("set_flag", flag, true)
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	main.set("show_title", false)
	main.set("debug_overlay_enabled", false)
	main.set("start_scene", load(DIR + str(shot[1]) + ".tscn"))
	root.add_child(main)
	await _frames(12)
	var room: Node = main.call("get_room")
	room.get("story").set("triggers_enabled", false)
	var player: Node3D = room.get("player")
	player.set("read_engine_input", false)
	var at: Vector2 = shot[2]
	player.global_position = Vector3(at.x, 0.02, at.y)
	player.rotation.y = deg_to_rad(float(shot[3]))
	if room.get("party") != null:
		room.get("party").call("seed_trail")
	await _frames(SETTLE_FRAMES)
	var action: String = str(shot[6])
	var interactor: Node = room.get("interactor")
	if action == "board":
		room.get_node("JobBoard").call("use", player, interactor)
		await _until_choosing(room)
	elif action.begins_with("talk:"):
		var npc: Node3D = room.get_node(action.substr(5))
		var facing: Vector3 = npc.global_transform.basis.z
		player.global_position = npc.global_position + Vector3(facing.x, 0.02, facing.z).normalized() * 1.0
		player.rotation.y = atan2(-facing.x, -facing.z)
		await _frames(8)
		interactor.call("refresh")
		interactor.call("try_interact")
		await _seconds(3.2)
	await _seconds(0.3)
	var image: Image = root.get_texture().get_image()
	var err: Error = image.save_png(OUT % str(shot[0]))
	print("saved ", OUT % str(shot[0]), " ", image.get_size(), " error ", err)
	main.queue_free()
	await _frames(4)


func _until_choosing(room: Node) -> void:
	for i: int in 80:
		var bubble: Node = room.get("runner").call("get_current_bubble")
		if bubble != null and int(bubble.call("get_state")) == CHOOSING_STATE:
			return
		room.get("runner").call("confirm")
		await _seconds(0.25)


func _frames(count: int) -> void:
	for i: int in count:
		await process_frame


func _seconds(seconds: float) -> void:
	await create_timer(seconds).timeout
