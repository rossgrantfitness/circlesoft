extends SceneTree
## Screenshots of the night market graybox for Ross (VS-14). Needs a real renderer (not --headless):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##       -s res://tests/visual/capture_market.gd -- --out=/abs/dir [--rooms=market_square,market_hideout]
## Boots the slice (a New Game in Red's hideout), then walks the SceneRouter through the rooms and writes
## <out>/<room>.png for each. Default rooms: the hideout and the square (docs/screenshots/market_hideout.png, market_square.png).

const MAIN_SCENE: String = "res://scenes/core/main.tscn"
const SETTLE_FRAMES: int = 80
## Where Red stands for the shot (room coordinates), when the default spawn would show a corner.
const STAND: Dictionary = {"market_square": Vector3(11.0, 0.1, 7.6), "market_wharf": Vector3(14.0, 0.1, 6.5), "market_gate": Vector3(7.5, 0.1, 5.0)}
## Wide shots: the room seen whole (distance in metres, the camera's fov stays).
const WIDE: Dictionary = {"market_square": 34.0, "market_wharf": 36.0, "market_gate": 24.0}
## Overviews of the free-camera rooms (junkyard, arena): a loose camera [position, look-at, fov] so the whole layout reads.
const OVERVIEW: Dictionary = {
	"junk_j1": [Vector3(32.0, 70.0, 66.0), Vector3(32.0, 0.0, 20.0), 50.0],
	"junk_j2": [Vector3(75.0, 120.0, 85.0), Vector3(75.0, 0.0, 16.0), 50.0],
	"junk_j3": [Vector3(50.0, 120.0, 100.0), Vector3(50.0, 0.0, 36.0), 50.0],
	"junk_j4": [Vector3(45.0, 95.0, 85.0), Vector3(45.0, 0.0, 28.0), 50.0],
	"kasp_arena": [Vector3(0.0, 120.0, 110.0), Vector3(0.0, 0.0, 10.0), 55.0],
}

var _out_dir: String = "res://../docs/screenshots"
var _rooms: PackedStringArray = ["market_hideout", "market_square"]


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--rooms="):
			_rooms = arg.trim_prefix("--rooms=").split(",")
	await process_frame
	var main: Main = (load(MAIN_SCENE) as PackedScene).instantiate() as Main
	main.show_title = false
	main.debug_overlay_enabled = false
	main.sandbox_boot_enabled = false
	root.add_child(main)
	main.apply_mode(GameMode.Mode.SLICE)
	var router: Node = root.get_node("SceneRouter")
	router.set("main", main)
	router.set("instant", true)
	main.start_new_game()
	for i: int in 60:
		await process_frame
	while bool(router.call("is_busy")):
		await process_frame
	for room_id: String in _rooms:
		if str(router.get("current_room_id")) != room_id:
			router.call("go_to", room_id, "")
			for i: int in 20:
				await process_frame
			while bool(router.call("is_busy")):
				await process_frame
		for i: int in SETTLE_FRAMES:
			await process_frame
		var room: ActionRoom = main.get_room() as ActionRoom
		if STAND.has(room_id) and room != null:
			room.hero.global_position = STAND[room_id]
			room.camera_rig.snap_to_target()
			for i: int in 20:
				await process_frame
		_save(room_id + ".png")
		if OVERVIEW.has(room_id) and room != null:
			var cam: Camera3D = Camera3D.new()
			room.add_child(cam)
			var spec: Array = OVERVIEW[room_id]
			cam.fov = float(spec[2])
			cam.far = 2000.0
			cam.look_at_from_position(spec[0], spec[1], Vector3.UP)
			cam.current = true
			for i: int in 10:
				await process_frame
			_save(room_id + "_overview.png")
			cam.queue_free()
		if WIDE.has(room_id) and room != null:
			var rig: DioramaCamera = room.camera_rig
			var old: float = rig.distance
			rig.clear_bounds()
			rig.set_room_look(rig.pitch_deg, rig.yaw_deg, rig.fov_deg, float(WIDE[room_id]))
			rig.snap_to_target()
			for i: int in 10:
				await process_frame
			_save(room_id + "_wide.png")
			rig.set_room_look(rig.pitch_deg, rig.yaw_deg, rig.fov_deg, old)
	quit(0)


func _save(file_name: String) -> void:
	var image: Image = root.get_texture().get_image()
	var path: String = _out_dir.path_join(file_name)
	var err: Error = image.save_png(path)
	print("saved %s (%s), error %d" % [path, image.get_size(), err])
