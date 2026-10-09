extends SceneTree
## VS-33 renderer smoke test for the slice graybox (QA). Needs a real renderer, not --headless:
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path game --rendering-driver opengl3 -s res://tests/visual/qa_slice_smoke.gd -- --out=/abs/dir
## Boots the slice from New Game (the hideout), then loads each main-path room in turn through the SceneRouter, lets it run for
## a while, and saves one PNG per main area: slice_graybox_qa_<area>.png. Prints "QA smoke: ..." lines and a frame-time summary.
## Script errors and missing resources show up in the console output (grep it for SCRIPT ERROR / ERROR / Missing).
## The hero is put in the loader where the area needs it (J4 and the Heap round); nothing else is scripted.

const MAIN_SCENE: String = "res://scenes/core/main.tscn"
const SETTLE_FRAMES: int = 90
const ROOM_LIMIT_FRAMES: int = 900

var _out_dir: String = "/home/user/circlesoft/docs/screenshots"
var _main: Main = null
var _router: Node = null
var _frame_ms: Array[float] = []
var _failures: int = 0


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	await process_frame
	_router = root.get_node("SceneRouter")
	_main = (load(MAIN_SCENE) as PackedScene).instantiate() as Main
	_main.show_title = false
	_main.debug_overlay_enabled = false
	_main.sandbox_boot_enabled = false
	root.add_child(_main)
	_main.apply_mode(GameMode.Mode.SLICE)
	_router.set("main", _main)
	_router.set("instant", true)
	_main.start_new_game()
	if not await _until("market_hideout", "hideout"):
		_finish()
		return
	await _shot("market_hideout", "market_hideout")
	await _go("market_square", "from_hideout", "market_square", Vector3(11.0, 0.1, 7.6))
	await _go("market_gate", "from_square", "market_gate", Vector3(7.5, 0.1, 5.0))
	await _go("junk_j1", "from_market", "junk_j1", Vector3(0, 0, 0))
	await _go("junk_j2", "from_j1", "junk_j2", Vector3(0, 0, 0))
	await _go("junk_j3", "from_j2", "junk_j3", Vector3(36.0, 0.1, 30.0))
	await _go("junk_j4", "from_j3", "junk_j4", Vector3(0, 0, 0))
	await _loader_on("junk_j4")
	await _go("junk_j5", "from_j4", "junk_j5", Vector3(0, 0, 0))
	await _go("kasp_arena", "from_j5", "kasp_arena", Vector3(0.0, 0.2, 44.0))
	await _wait_form("kasp_arena", &"red")
	await _shot("kasp_arena", "kasp_arena_on_foot")
	await _go("kasp_arena", "retry_phase2", "kasp_arena_heap", Vector3.ZERO)
	_finish()


func _room() -> ActionRoom:
	return _main.get_room() as ActionRoom


func _until(room_id: String, label: String) -> bool:
	for i: int in ROOM_LIMIT_FRAMES:
		await physics_frame
		var room: ActionRoom = _room()
		if room != null and room.room_id == room_id and not bool(_router.call("is_busy")) and room.hero != null:
			print("QA smoke: reached %s (%s)" % [room_id, label])
			return true
	_failures += 1
	print("QA smoke FAIL: never reached %s (now in %s)" % [room_id, str(_room().room_id) if _room() != null else "none"])
	return false


func _go(room_id: String, spawn: String, label: String, stand: Vector3) -> void:
	_router.call("go_to", room_id, spawn)
	if not await _until(room_id, label):
		return
	var room: ActionRoom = _room()
	for i: int in SETTLE_FRAMES:
		await process_frame
		_sample()
	if stand != Vector3.ZERO and room.hero != null:
		room.hero.global_position = stand
	for i: int in 30:
		await process_frame
		_sample()
	await _shot(room_id, label)


func _loader_on(room_id: String) -> void:
	var room: ActionRoom = _room()
	if room == null or room.room_id != room_id or room.get_robot_stage() == null:
		_failures += 1
		print("QA smoke FAIL: %s has no robot stage to board" % room_id)
		return
	room.get_robot_stage().wake_and_board()
	for i: int in 240:
		await process_frame
		_sample()
	print("QA smoke: loader boarded in %s, form %s" % [room_id, str(room.get_robot_stage().form())])


func _wait_form(room_id: String, form: StringName) -> void:
	for i: int in ROOM_LIMIT_FRAMES:
		await process_frame
		_sample()
		var room: ActionRoom = _room()
		if room != null and room.room_id == room_id and room.get_robot_stage() != null and room.get_robot_stage().form() == form:
			break
	for i: int in SETTLE_FRAMES:
		await process_frame
		_sample()


func _shot(room_id: String, label: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = "%s/slice_graybox_qa_%s.png" % [_out_dir, label]
	var err: int = image.save_png(path)
	print("QA smoke: %s -> %s (%s)" % [room_id, path, "saved" if err == OK else "save error %d" % err])


var _last_usec: int = 0


func _sample() -> void:
	var now: int = Time.get_ticks_usec()
	if _last_usec > 0:
		_frame_ms.append(float(now - _last_usec) / 1000.0)
	_last_usec = now


func _finish() -> void:
	var total: float = 0.0
	var worst: float = 0.0
	for ms: float in _frame_ms:
		total += ms
		worst = maxf(worst, ms)
	var avg: float = total / maxf(float(_frame_ms.size()), 1.0)
	print("QA smoke: frames sampled %d, average %.1f ms, worst %.1f ms, failures %d" % [_frame_ms.size(), avg, worst, _failures])
	quit(0 if _failures == 0 else 1)
