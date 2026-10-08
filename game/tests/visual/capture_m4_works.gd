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
		var image: Image = root.get_texture().get_image()
		var path: String = OUT_DIR + str(SHOTS[room_id]) + ".png"
		var err: Error = image.save_png(path)
		print("saved ", path, " error ", err)
		failed += 1 if err != OK else 0
	quit(failed)


func _frames(count: int) -> void:
	for i: int in count:
		await process_frame
