extends SceneTree
## Screenshots of the save lamp (M3-9): Red mid lamp check (the lamp lit, a tap on the glass) and the save screen with
## a few slots filled in. Needs a real renderer (not --headless):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##       -s res://tests/visual/capture_m3_save_lamp.gd
## Writes docs/screenshots/m3_save_lamp.png (the save screen) and m3_save_lamp_check.png (the check).
## Saves go to a temp folder under user:// that is removed afterwards. Held as plain nodes: this
## script is compiled before the autoloads exist, so it cannot name the game classes.

const MAIN_SCENE: String = "res://scenes/core/main.tscn"
const OUT_SCREEN: String = "res://../docs/screenshots/m3_save_lamp.png"
const OUT_CHECK: String = "res://../docs/screenshots/m3_save_lamp_check.png"
const TEMP_DIR: String = "user://capture_saves"
const SETTLE_FRAMES: int = 40

var _now: float = 1760000000.0


func _initialize() -> void:
	await process_frame
	var manager: Node = root.get_node("SaveManager")
	var state: Node = root.get_node("GameState")
	var old_dir: String = str(manager.get("save_dir"))
	manager.set("save_dir", TEMP_DIR)
	manager.set("clock", func() -> float: return _now)
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	main.set("show_title", false)
	main.set("debug_overlay_enabled", false)
	root.add_child(main)
	await _frames(10)
	# A few saved slots so the screen has something to show.
	state.call("reset")
	state.call("set_location", "test_room", "LampSpawn")
	state.call("tick_play_time", 1325.0)
	state.call("add_credits", 85)
	manager.call("save_slot", 1)
	_now += 3600.0
	state.call("tick_play_time", 4140.0)
	state.call("add_credits", 260)
	state.call("update_member", "red", {"level": 4})
	manager.call("save_slot", 2)
	_now += 600.0
	state.call("tick_play_time", 300.0)
	manager.call("auto_save")
	var room: Node = main.call("get_room")
	var lamp: Node3D = room.get_node("SaveLamp")
	var player: Node3D = room.get("player")
	# Red stands in front of the lamp.
	var offset: Vector3 = Vector3(0.45, 0.02, 0.5)
	player.global_position = lamp.global_position + offset
	player.rotation.y = atan2(offset.x, offset.z)
	await _frames(SETTLE_FRAMES)
	room.get("interactor").call("try_interact")
	await _seconds(1.15)
	await _frames(4)
	_save(OUT_CHECK)
	lamp.call("skip")
	await _seconds(1.0)
	await _frames(4)
	_save(OUT_SCREEN)
	manager.set("save_dir", old_dir)
	_clean(TEMP_DIR)
	quit(0)


func _save(path: String) -> void:
	var image: Image = root.get_texture().get_image()
	var err: Error = image.save_png(path)
	print("saved ", path, " ", image.get_size(), " error ", err)


func _clean(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for file_name: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
	DirAccess.remove_absolute(path)


func _frames(count: int) -> void:
	for i: int in count:
		await process_frame


func _seconds(seconds: float) -> void:
	await create_timer(seconds).timeout
