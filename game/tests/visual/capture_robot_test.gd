extends SceneTree
## Screenshots of the giant-robot scale test in the real sandbox (task CS-21), real renderer, grim_ps2 look:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##       -s res://tests/visual/capture_robot_test.gd -- --shot=small|huge|docking|red|all --out=docs/screenshots
## small:   Red inside the loader robot among crates and cars (robot_test_small.png)
## huge:    the colossus striding between buildings, camera pulled back (robot_test_huge.png)
## docking: the loader mid-hop into the colossus's chest (robot_test_docking.png)
## red:     Red at the arena's gate, for scale (robot_test_red.png)
## It plays the real game objects (the sandbox, the boarding sequence, the controller) and only teleports to save walking time.
## No game classes are named (this file compiles before the autoloads exist); everything goes through load() and call().

const SCREEN_SCENE: String = "res://scenes/core/psx_screen.tscn"
const SANDBOX_SCENE: String = "res://scenes/sandbox/combat_sandbox.tscn"

var _out: String = "/tmp"
var _shot: String = "all"
var _screen: Node = null
var _sandbox: Node = null
var _player: Node3D = null
var _boarding: Node = null
var _yard: Node = null
var _camera: Node = null


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--shot="):
			_shot = arg.trim_prefix("--shot=")
	await process_frame
	_screen = (load(SCREEN_SCENE) as PackedScene).instantiate()
	root.add_child(_screen)
	await _settle(2)
	_sandbox = _screen.call("load_world", load(SANDBOX_SCENE) as PackedScene) as Node
	await _settle(30)
	_player = _sandbox.call("get_player") as Node3D
	_boarding = _sandbox.call("get_robot_boarding") as Node
	_yard = _sandbox.call("get_robot_yard") as Node
	_camera = _sandbox.call("get_camera") as Node
	_player.set("read_engine_input", false)
	_boarding.set("read_engine_input", false)
	for enemy: Variant in _sandbox.call("get_enemies") as Array:
		(enemy as Node3D).set_physics_process(false)
		(enemy as Node3D).set_process(false)
		(enemy as Node3D).global_position = Vector3(0.0, -50.0, 0.0)
	var shots: Array[String] = []
	if _shot == "all":
		shots.append_array(["red", "small", "docking", "huge"])
	else:
		shots.append(_shot)
	for shot: String in shots:
		match shot:
			"red":
				await _shot_red()
			"small":
				await _shot_small()
			"docking":
				await _shot_docking()
			"huge":
				await _shot_huge()
	quit(0)


# ---- shots ----

func _shot_red() -> void:
	_teleport(Vector3(33.0, 0.02, 0.0), 90.0)
	await _settle(40)
	_save("robot_test_red")


func _shot_small() -> void:
	var small: Node3D = _yard.get("small_display") as Node3D
	var at: Vector3 = small.call("boarding_point") as Vector3
	_teleport(at + Vector3(-2.5, 0.02, 0.0), 90.0)
	await _settle(10)
	_player.call("set_move_input", Vector2(0.0, -1.0))      # walk into the ring
	await _until(func() -> bool: return int(_boarding.call("get_mode")) == 2, 900)    # Mode.SMALL
	_player.call("set_move_input", Vector2.ZERO)
	print("boarded: mode ", _boarding.call("mode_name"), " form ", _player.call("get_form_id"))
	# among the crates and cars of the loading yard, the camera behind and a little to the side
	_teleport_keep(Vector3(64.0, 0.02, 1.0), 90.0)
	_camera.call("set_orbit_angles", -PI * 0.5 + 0.35, -0.22)
	await _settle(60)
	_save("robot_test_small")


func _shot_docking() -> void:
	await _ensure_small()
	var huge: Node3D = _yard.get("huge_display") as Node3D
	var approach: Vector3 = huge.call("approach_point") as Vector3
	_teleport_keep(approach + Vector3(-14.0, 0.02, 0.0), 90.0)
	_player.call("set_move_input", Vector2(0.0, -1.0))
	await _until(func() -> bool: return int(_boarding.call("get_mode")) == 3, 900)    # Mode.DOCKING
	_player.call("set_move_input", Vector2.ZERO)
	await _until(func() -> bool: return _phase_progress("snap") >= 0.5, 900)
	await _settle(2)
	_save("robot_test_docking")
	await _until(func() -> bool: return int(_boarding.call("get_mode")) == 4, 1800)   # Mode.HUGE
	print("docked: mode ", _boarding.call("mode_name"), " form ", _player.call("get_form_id"))


func _shot_huge() -> void:
	if str(_player.call("get_form_id")) != "huge":
		await _ensure_small()
		var huge: Node3D = _yard.get("huge_display") as Node3D
		var approach: Vector3 = huge.call("approach_point") as Vector3
		_teleport_keep(approach + Vector3(-9.0, 0.02, 0.0), 90.0)
		_player.call("set_move_input", Vector2(0.0, -1.0))
		await _until(func() -> bool: return int(_boarding.call("get_mode")) == 3, 900)
		_player.call("set_move_input", Vector2.ZERO)
		await _until(func() -> bool: return int(_boarding.call("get_mode")) == 4, 3000)
	# out among the buildings: the avenue between the street rows, facing east, then a few real strides
	_teleport_keep(Vector3(205.0, 0.02, 0.0), 90.0)
	_camera.call("set_orbit_angles", -PI * 0.5 + 0.6, -0.08)
	await _settle(80)
	_player.call("set_move_input", Vector2(0.0, -1.0))
	await _settle(50)
	_camera.call("set_orbit_angles", -PI * 0.5 + 0.75, -0.06)       # swing round to a three-quarter view
	await _settle(14)
	_player.call("set_move_input", Vector2.ZERO)
	await _settle(10)
	var controller: Node = _sandbox.call("get_scale_controller") as Node
	print("huge: steps ", controller.get("steps_taken"), " stomped ", controller.get("stomps"), " fog ", controller.call("world_now"))
	_save("robot_test_huge")


# ---- helpers ----

func _ensure_small() -> void:
	if str(_player.call("get_form_id")) == "small":
		return
	var small: Node3D = _yard.get("small_display") as Node3D
	var at: Vector3 = small.call("boarding_point") as Vector3
	_teleport(at + Vector3(-2.5, 0.02, 0.0), 90.0)
	await _settle(10)
	_player.call("set_move_input", Vector2(0.0, -1.0))
	await _until(func() -> bool: return int(_boarding.call("get_mode")) == 2, 900)
	_player.call("set_move_input", Vector2.ZERO)


func _phase_progress(phase: String) -> float:
	var seq: Object = _boarding.call("get_sequence") as Object
	return float(seq.call("progress", StringName(phase))) if seq != null else 0.0


func _teleport(at: Vector3, yaw_deg: float) -> void:
	_player.global_position = at
	_player.rotation.y = deg_to_rad(yaw_deg)
	_player.set("velocity", Vector3.ZERO)
	_camera.call("recenter")
	_camera.call("snap")


## Moves her without resetting the camera's angle choices (a fresh snap keeps the current orbit yaw).
func _teleport_keep(at: Vector3, yaw_deg: float) -> void:
	_player.global_position = at
	_player.rotation.y = deg_to_rad(yaw_deg)
	_player.set("velocity", Vector3.ZERO)
	_camera.call("recenter")
	_camera.call("snap")


func _until(condition: Callable, max_frames: int) -> void:
	var frames: int = 0
	while not bool(condition.call()) and frames < max_frames:
		await process_frame
		frames += 1
	if frames >= max_frames:
		print("WARNING: timed out waiting (", max_frames, " frames), mode ", _boarding.call("mode_name"))


func _settle(frames: int) -> void:
	for i: int in frames:
		await process_frame


func _save(stem: String) -> void:
	var image: Image = root.get_viewport().get_texture().get_image()
	var path: String = "%s/%s.png" % [_out, stem]
	print("saved ", path, " ", image.get_size(), " error ", image.save_png(path))
