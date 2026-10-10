extends SceneTree
## Screenshots of the Dynamic battle camera (Ross's storyboard). Needs a real renderer (not --headless):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##       -s res://tests/visual/capture_battle_camera.gd
## Writes docs/screenshots/:
##   m3_battle_cam_intro.png   the six intro shots (panels 1-6), start and end frame of each, 4 x 3
##   m3_battle_cam_action.png  a party attack shot (panel 3) and an enemy attack shot (panel 10), with the HUD
##   m3_battle_cam_boss.png    the boss low POV (panel 11): start, end, then the settle
##   m3_battle_cam_strip.png   one whole regular intro as a frame strip (a GIF-like sheet), then the settle and idle
## Names no game classes (this script compiles before the autoloads exist): everything is load() and call().

const MAIN_SCENE: String = "res://scenes/core/main.tscn"
const STAGE_SCENE: String = "res://scenes/battle/battle_scene.tscn"
const STUB: String = "res://tests/fixtures/battle_stage/stub_battle_controller.gd"
const OUT_DIR: String = "res://../docs/screenshots/"
const FRAME: Vector2i = Vector2i(384, 216)
const POOL: Array[String] = ["over_shoulder", "crane_down", "front_row", "foes_roll", "dutch_pan", "wide_depth"]

var _stage: Node = null
var _stub: RefCounted = null
var _director: Object = null


func _initialize() -> void:
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	main.set("show_title", false)
	main.set("debug_overlay_enabled", false)
	root.add_child(main)
	for i: int in 6:
		await process_frame
	await _intro_sheet(main, false)
	await _action_sheet(main)
	await _boss_sheet(main)
	await _strip(main)
	quit(0)


func _make_stage(main: Node, boss: bool, hud: bool) -> void:
	var screen: Node = main.get_node("PsxScreen")
	_stage = screen.call("load_world", load(STAGE_SCENE) as PackedScene)
	_stage.set("transitions_enabled", false)
	_stage.set("camera_seed", 11)
	_stage.set("audio", null)
	_stage.call("set_dynamic_camera", true)
	_stage.set_process(false)
	_stub = (load(STUB) as GDScript).new() as RefCounted
	if boss:
		_stub.set("boss_id", "e1")
		_stub.set("is_boss", true)
		_stub.set("enemy_count", 1)
	_stage.call("attach_controller", _stub)
	_stage.call("_on_battle_started", _stub.call("snapshot"))
	_stage.call("_set_hud_visible", hud)
	_director = _stage.get("camera_director") as Object
	for i: int in 8:
		await process_frame


func _show(pose: Object) -> void:
	(_stage.get("camera_rig") as Object).call("apply_pose", pose)
	for i: int in 3:
		await process_frame


func _grab() -> Image:
	var image: Image = root.get_texture().get_image()
	var scale: int = int(floor(minf(float(image.get_width()) / FRAME.x, float(image.get_height()) / FRAME.y)))
	var size: Vector2i = FRAME * scale
	var origin: Vector2i = (image.get_size() - size) / 2
	var crop: Image = image.get_region(Rect2i(origin, size))
	crop.resize(FRAME.x * 2, FRAME.y * 2, Image.INTERPOLATE_NEAREST)
	return crop


func _sheet(frames: Array[Image], cols: int, file: String) -> void:
	var rows: int = int(ceil(float(frames.size()) / float(cols)))
	var sheet: Image = Image.create(FRAME.x * 2 * cols, FRAME.y * 2 * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.08, 0.07, 0.12))
	for i: int in frames.size():
		sheet.blit_rect(frames[i], Rect2i(Vector2i.ZERO, frames[i].get_size()), Vector2i((i % cols) * FRAME.x * 2, (i / cols) * FRAME.y * 2))
	sheet.save_png(OUT_DIR + file)
	print("saved ", file, " (", frames.size(), " frames)")


func _clip_frame(shot: String, t: float) -> Image:
	var clip: Object = _director.call("build_clip", shot) as Object
	clip.set("elapsed", float(clip.get("duration_s")) * t)
	await _show(clip.call("pose") as Object)
	return _grab()


func _intro_sheet(main: Node, hud: bool) -> void:
	await _make_stage(main, false, hud)
	var frames: Array[Image] = []
	for shot: String in POOL:
		frames.append(await _clip_frame(shot, 0.02))
		frames.append(await _clip_frame(shot, 0.98))
	_sheet(frames, 4, "m3_battle_cam_intro.png")


func _action_sheet(main: Node) -> void:
	await _make_stage(main, false, true)
	var frames: Array[Image] = []
	# a party attack (panel 3): Red at the first grunt; an enemy attack (panel 10): the grunt at Red
	for info: Dictionary in [{"actor": "red", "targets": ["e1"], "side": "party"}, {"actor": "e1", "targets": ["red"], "side": "enemy"}, {"actor": "otis", "targets": ["e4"], "side": "party"}, {"actor": "e2", "targets": ["mox"], "side": "enemy"}]:
		info["lock_start_s"] = 0.4
		info["lock_end_s"] = 1.2
		_director.call("begin_action", info)
		for i: int in 60:
			_director.call("advance", 1.0 / 60.0)
		await _show(_director.call("pose") as Object)
		frames.append(_grab())
		_director.call("end_action")
		for i: int in 90:
			_director.call("advance", 1.0 / 60.0)
	_sheet(frames, 2, "m3_battle_cam_action.png")


func _boss_sheet(main: Node) -> void:
	await _make_stage(main, true, false)
	var frames: Array[Image] = []
	_stage.call("_start_camera_intro")
	await _show(_director.call("pose") as Object)
	frames.append(_grab())
	for i: int in 100:
		_director.call("advance", 1.0 / 60.0)
	await _show(_director.call("pose") as Object)
	frames.append(_grab())
	for i: int in 70:
		_director.call("advance", 1.0 / 60.0)
	await _show(_director.call("pose") as Object)
	frames.append(_grab())
	_stage.call("_on_settle_started")
	for i: int in 120:
		_director.call("advance", 1.0 / 60.0)
	_stage.call("_set_hud_visible", true)
	await _show(_director.call("pose") as Object)
	frames.append(_grab())
	_sheet(frames, 2, "m3_battle_cam_boss.png")


func _strip(main: Node) -> void:
	await _make_stage(main, false, false)
	var frames: Array[Image] = []
	_stage.call("_start_camera_intro")
	var length: float = float(_director.call("intro_length_s"))
	print("intro plan ", _director.call("intro_plan"), " length ", length)
	var step: float = length / 9.0
	for n: int in 10:
		await _show(_director.call("pose") as Object)
		frames.append(_grab())
		for i: int in int(step * 60.0):
			_director.call("advance", 1.0 / 60.0)
	_stage.call("_set_hud_visible", true)
	for n: int in 2:
		for i: int in 240:
			_director.call("advance", 1.0 / 60.0)
		await _show(_director.call("pose") as Object)
		frames.append(_grab())
	_sheet(frames, 4, "m3_battle_cam_strip.png")
