extends SceneTree
## Screenshots of the three boss cues (B10, B11, B12) in the real Kasp's Arena with the real HUD and the real Hushmaster.
## Needs a real renderer (not --headless):
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path game --rendering-driver opengl3 -s res://tests/visual/capture_slice_cues.gd
## Writes docs/screenshots/: slice_cue_pips.png (phase 1, one leg down, the pip still flashing), slice_cue_quiet_hours.png
## (the dish humming: edge fizz and "Jamming"), slice_cue_jack_in.png (the toppled walker and the "Jack in" prompt), plus a
## 1:1 corner crop of each (..._closeup.png). Names no cross-script types except Main (it boots like qa_slice_smoke.gd).

const MAIN_SCENE: String = "res://scenes/core/main.tscn"
const OUT_DIR: String = "res://../docs/screenshots/"
const ROOM_LIMIT_FRAMES: int = 900

var _main: Node = null
var _router: Node = null
var _room: Node = null
var _fight: Node = null
var _boss: Node = null
var _director: Object = null


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	await process_frame
	_router = root.get_node("SceneRouter")
	_main = (load(MAIN_SCENE) as PackedScene).instantiate()
	_main.set("show_title", false)
	_main.set("debug_overlay_enabled", false)
	_main.set("sandbox_boot_enabled", false)
	root.add_child(_main)
	_main.call("apply_mode", 1)
	_router.set("main", _main)
	_router.set("instant", true)
	_main.call("start_new_game")
	await _wait_room("market_hideout")
	_router.call("go_to", "kasp_arena", "from_j5")
	if not await _wait_room("kasp_arena"):
		quit(1)
		return
	for i: int in 120:
		await process_frame
	_room = _main.call("get_room")
	_room.get("hero").set("global_position", Vector3(0.0, 0.2, 44.0))
	_fight = get_first_node_in_group("boss_fight")
	if _fight == null:
		push_error("capture: no boss fight in the arena")
		quit(1)
		return
	_boss = _fight.get("hushmaster")
	_director = _room.call("get_director")
	for i: int in 60:
		await process_frame
	await _pips_shot()
	await _quiet_shot()
	await _jack_shot()
	quit(0)


func _wait_room(room_id: String) -> bool:
	for i: int in ROOM_LIMIT_FRAMES:
		await physics_frame
		var room: Node = _main.call("get_room")
		if room != null and str(room.get("room_id")) == room_id and not bool(_router.call("is_busy")) and room.get("hero") != null:
			return true
	push_error("capture: never reached %s" % room_id)
	return false


func _frames(count: int) -> void:
	for i: int in count:
		await process_frame


func _grab(file: String, crop: Rect2i) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUT_DIR + file + ".png"))
	image.get_region(crop).save_png(ProjectSettings.globalize_path(OUT_DIR + file + "_closeup.png"))
	print("saved ", file, " ", image.get_size())


func _pips_shot() -> void:
	# Phase 1: the walker stands, the hint waits under the pips; then one leg pair goes out and the pip blinks.
	_director.call("set_hack_prompt", {})
	_boss.call("relay_of", &"fl").call("apply_hit", {"damage": 9999, "source": "hack", "outcome": &"hit", "move_id": &"hack_zap"})
	await _frames(3)
	await _grab("slice_cue_pips", Rect2i(560, 0, 800, 200))


func _quiet_shot() -> void:
	# The walker may be mid-pattern: ask every frame until it takes Quiet Hours, then shoot while it hums.
	for i: int in 400:
		_director.call("heal_actor", &"red", 999) if _director.has_method("heal_actor") else null
		if bool(_boss.call("force_pattern", &"quiet_hours")):
			break
		await process_frame
	await _frames(2)
	print("humming: ", _boss.call("is_quiet_humming"))
	await _grab("slice_cue_quiet_hours", Rect2i(0, 0, 960, 540))
	# let it run out so the next cue starts clean
	for i: int in 400:
		await process_frame
		if not bool(_boss.call("is_quiet_humming")):
			break


func _jack_shot() -> void:
	_boss.call("_begin_topple")
	for i: int in 900:
		await process_frame
		if not (_director.get("hack_prompt") as Dictionary).is_empty():
			break
	await _frames(14)
	await _grab("slice_cue_jack_in", Rect2i(0, 540, 960, 540))
