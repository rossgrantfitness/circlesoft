extends SceneTree
## Screenshots of the Spillway and the jammer works rooms (M4-1). Needs a real renderer (not --headless):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##       -s res://tests/visual/capture_m4_works.gd [-- room_id room_id ...]
## Writes docs/screenshots/m4_<name>.png (the whole 1280x720 window), one per room. Visits each room through
## the SceneRouter with the one-time scenes marked as seen, so nothing talks over the picture. Held as plain
## nodes: this script is compiled before the autoloads exist, so it cannot name the game classes.

const MAIN_SCENE: String = "res://scenes/core/main.tscn"
const OUT_DIR: String = "res://../docs/screenshots/"
const SHOTS: Dictionary = {
	"road_mast_road": "m4_spillway", "road_mast_foot": "m4_works_gate", "tower_sump": "m4_sump", "tower_cable_hall": "m4_cable_mill",
	"tower_bell_gallery": "m4_bell_gallery", "tower_generator": "m4_power_room", "tower_jammer_deck": "m4_drone_line",
	"tower_landing": "m4_landing", "tower_roof": "m4_roof",
}
## Where Red stands for each picture (x, z), so the puzzle props are in frame. Missing = the arrival spot.
const STAND: Dictionary = {
	"tower_sump": Vector2(2.4, 4.6), "tower_cable_hall": Vector2(5.2, 4.8), "tower_bell_gallery": Vector2(2.6, 5.0),
	"tower_generator": Vector2(2.4, 2.0), "tower_jammer_deck": Vector2(6.0, 8.0), "road_mast_road": Vector2(21.0, 4.8),
	"road_mast_foot": Vector2(9.0, 8.5),
}
const SEEN_FLAGS: Array[String] = ["mox_crate_scene", "works_gate_scene", "works_sump_seen", "otis_joined", "mox_joined", "intro_seen"]
const SETTLE_FRAMES: int = 50


func _initialize() -> void:
	await process_frame
	var state: Node = root.get_node("GameState")
	state.call("reset")
	for flag: String in SEEN_FLAGS:
		state.call("set_flag", flag, true)
	state.call("set_story_beat", "b3_tower")
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	main.set("show_title", false)
	main.set("debug_overlay_enabled", false)
	root.add_child(main)
	await _frames(10)
	var router: Node = root.get_node("SceneRouter")
	router.set("instant", true)
	var wanted: Array[String] = []
	for arg: String in OS.get_cmdline_user_args():
		wanted.append(arg)
	var failed: int = 0
	for room_id: String in SHOTS:
		if not wanted.is_empty() and not wanted.has(room_id):
			continue
		await router.call("start_at", room_id, "")
		await _frames(SETTLE_FRAMES)
		var room: Node = root.get_node("Main").call("get_room")
		_stage_room(room, room_id)
		if STAND.has(room_id):
			var player: Node3D = room.get("player")
			player.global_position = Vector3(STAND[room_id].x, 0.02, STAND[room_id].y)
			room.get("camera_rig").call("snap_to_target")
			await _frames(30)
		var image: Image = root.get_texture().get_image()
		var path: String = OUT_DIR + str(SHOTS[room_id]) + ".png"
		var err: Error = image.save_png(path)
		print("saved ", path, " error ", err)
		failed += 1 if err != OK else 0
	quit(failed)


## Puzzle state for the pictures: the crate pushed home, the lever thrown, a few bells rung.
func _stage_room(room: Node, room_id: String) -> void:
	if room_id == "tower_cable_hall":
		for i: int in 4:
			room.get_node("PushCrate").call("push_once")
	elif room_id == "tower_generator":
		var state: Node = root.get_node("GameState")
		state.call("add_item", "kasp_access_card", 2)
		room.get_node("CardGate").call("use", room.get("player"), room.get("interactor"))
		room.get_node("PowerLever").call("use", room.get("player"), room.get("interactor"))
		state.call("remove_item", "kasp_access_card", 2)


func _frames(count: int) -> void:
	for i: int in count:
		await process_frame
