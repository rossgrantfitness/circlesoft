extends SceneTree
## The grim look test (2026-10-08): one shot in one look profile. Needs a real renderer (not --headless):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##       -s res://tests/visual/capture_grim_look.gd -- --shot=square --profile=grim --out=/some/dir
## Optional: --at=x,z (where Red stands), --fov=45 (a wider camera, as F9 in the overlay does), --tag=_wide.
## Shots: square, square_east, checkpoint, battle, red (Red old vs grim is done by capture_grim_red.gd).
## Profiles: classic, grim. Writes <out>/<shot>_<profile>.png (the whole 1280x720 window). The two
## profiles of a shot are put side by side by scripts/tools/compose_grim_shots.py.
## Names no game classes (compiled before the autoloads exist): everything is load() and call().

const MAIN_SCENE: String = "res://scenes/core/main.tscn"
const DIR: String = "res://scenes/rooms/harrow/"
const STAGE_SCENE: String = "res://scenes/battle/battle_scene.tscn"
const STUB: String = "res://tests/fixtures/battle_stage/stub_battle_controller.gd"
const LOOK_SCRIPT: String = "res://scripts/core/look_profiles.gd"
const SETTLE_FRAMES: int = 70
const BATTLE_SETTLE_FRAMES: int = 60

# shot: room, Red at (x, z), Red's yaw in degrees
const ROOM_SHOTS: Dictionary = {
	"square": ["harrow_square", Vector2(4.4, 1.9), 200.0],
	"square_east": ["harrow_square", Vector2(17.0, 2.4), 200.0],
	"checkpoint": ["harrow_checkpoint", Vector2(8.0, 4.6), 200.0],
}

var _look: GDScript = null
var _at: String = ""
var _fov: float = 0.0


func _initialize() -> void:
	var shot: String = "square"
	var profile: String = "grim"
	var out_dir: String = "/tmp"
	var tag: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			shot = arg.trim_prefix("--shot=")
		elif arg.begins_with("--profile="):
			profile = arg.trim_prefix("--profile=")
		elif arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--at="):
			_at = arg.trim_prefix("--at=")
		elif arg.begins_with("--fov="):
			_fov = float(arg.trim_prefix("--fov="))
		elif arg.begins_with("--tag="):
			tag = arg.trim_prefix("--tag=")
	await process_frame
	_look = load(LOOK_SCRIPT) as GDScript
	_look.call("set_forced", profile)
	if shot == "battle":
		await _battle(out_dir, profile + tag)
	else:
		await _room(shot, out_dir, profile + tag)
	quit(0)


func _save(path: String) -> void:
	var image: Image = root.get_texture().get_image()
	var err: Error = image.save_png(path)
	print("saved ", path, " ", image.get_size(), " error ", err)


func _frames(count: int) -> void:
	for i: int in count:
		await process_frame


func _room(shot: String, out_dir: String, profile: String) -> void:
	var spec: Array = ROOM_SHOTS[shot]
	var state: Node = root.get_node("GameState")
	state.call("reset")
	state.call("set_story_beat", "b1_night")
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	main.set("show_title", false)
	main.set("debug_overlay_enabled", false)
	main.set("start_scene", load(DIR + str(spec[0]) + ".tscn"))
	root.add_child(main)
	await _frames(12)
	var room: Node = main.call("get_room")
	room.get("story").set("triggers_enabled", false)
	var player: Node3D = room.get("player")
	player.set("read_engine_input", false)
	var at: Vector2 = spec[1]
	if not _at.is_empty():
		var parts: PackedStringArray = _at.split(",")
		at = Vector2(float(parts[0]), float(parts[1]))
	if _fov > 0.0:
		(room.get("camera_rig") as Node).call("set_fov_deg", _fov)
	player.global_position = Vector3(at.x, 0.02, at.y)
	player.rotation.y = deg_to_rad(float(spec[2]))
	if room.get("party") != null:
		room.get("party").call("seed_trail")
	await _frames(SETTLE_FRAMES)
	_save("%s/%s_%s.png" % [out_dir, shot, profile])


func _battle(out_dir: String, profile: String) -> void:
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	main.set("show_title", false)
	main.set("debug_overlay_enabled", false)
	root.add_child(main)
	await _frames(6)
	var screen: Node = main.get_node("PsxScreen")
	var stage: Node = screen.call("load_world", load(STAGE_SCENE) as PackedScene)
	stage.set("transitions_enabled", false)
	stage.set("camera_intro_enabled", false)
	var stub: RefCounted = (load(STUB) as GDScript).new() as RefCounted
	stub.set("tree", self)
	stage.call("attach_controller", stub)
	stage.call("_on_battle_started", stub.call("snapshot"))
	await _frames(BATTLE_SETTLE_FRAMES)
	_save("%s/battle_%s.png" % [out_dir, profile])
