extends SceneTree
## Screenshots of the night market graybox for Ross (VS-14). Needs a real renderer (not --headless):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##       -s res://tests/visual/capture_market.gd -- --out=/abs/dir [--rooms=market_square,market_hideout]
## Boots the slice (a New Game in Red's hideout), then walks the SceneRouter through the rooms and writes
## <out>/<room>.png for each. Default rooms: the hideout and the square (docs/screenshots/market_hideout.png, market_square.png).

const MAIN_SCENE: String = "res://scenes/core/main.tscn"
const SETTLE_FRAMES: int = 80

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
	for room_id: String in _rooms:
		if str(router.get("current_room_id")) != room_id:
			router.call("go_to", room_id, "")
		for i: int in SETTLE_FRAMES:
			await process_frame
		var image: Image = root.get_texture().get_image()
		var path: String = _out_dir.path_join(room_id + ".png")
		var err: Error = image.save_png(path)
		print("saved %s (%s), error %d" % [path, image.get_size(), err])
	quit(0)
