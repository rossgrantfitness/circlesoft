extends SceneTree
## Lineup picture of the cast blockouts: Red, Otis, Mox and the old Zero side by side at true scale,
## front and 3/4, drawn through the real PSX screen (384x216, scaled 3x, nearest-neighbor).
## Needs a real renderer (not --headless):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##       -s res://tests/visual/capture_npc_blockouts.gd
## Writes docs/screenshots/npc_blockouts_lineup.png (front on top, 3/4 below) plus the single
## npc_blockouts_front.png and npc_blockouts_34.png, and per-character closeups
## npc_close_<name>.png (3/4 view).
## It builds the stage itself from the PSX screen and the style stage's world scene, so it names no
## game classes (they need autoloads that are not there when this script compiles).

const SCREEN_SCENE: String = "res://scenes/core/psx_screen.tscn"
const WORLD_SCENE: String = "res://scenes/debug/style_stage_world.tscn"
const OUTPUT_DIR: String = "res://../docs/screenshots/"
const SETTLE_FRAMES: int = 6
## name, model path, x on the stage. Red is the shiba blockout prototype F (the locked look).
const CAST: Array[Array] = [
	["red", "res://art/placeholder/characters/red_prototypes/red_proto_f.glb", -2.55],
	["otis", "res://art/placeholder/characters/otis/chr_otis.glb", -0.95],
	["mox", "res://art/placeholder/characters/mox/chr_mox.glb", 0.65],
	["zero", "res://art/placeholder/characters/old_zero/npc_old_zero.glb", 2.15],
]
const FRONT_YAW_DEG: float = 0.0
const THREE_QUARTER_YAW_DEG: float = -35.0
const LINEUP_CENTER: Vector3 = Vector3(-0.2, 0.62, 0.0)
const LINEUP_DISTANCE: float = 6.4
const CLOSE_CENTER_Y: float = 0.65
const CLOSE_DISTANCE: float = 3.4
const CAMERA_PITCH_DEG: float = 8.0
const CAMERA_FOV_DEG: float = 30.0
const SCALE_UP: int = 3

var _screen: Node = null
var _world: Node3D = null
var _models: Dictionary[String, Node3D] = {}
var _failures: int = 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	await process_frame
	_screen = (load(SCREEN_SCENE) as PackedScene).instantiate()
	root.add_child(_screen)
	await process_frame
	_world = _screen.call("load_world", load(WORLD_SCENE)) as Node3D
	for hidden: String in ["Crate", "BlobShadow"]:
		(_world.get_node(hidden) as Node3D).visible = false
	for entry: Array in CAST:
		var packed: PackedScene = load(entry[1] as String) as PackedScene
		if packed == null:
			push_error("cannot load " + str(entry[1]))
			_failures += 1
			continue
		var model: Node3D = packed.instantiate() as Node3D
		_world.get_node("ModelPivot").add_child(model)
		_models[entry[0] as String] = model
		_play_idle(model)
	await _settle()
	var front: Image = await _lineup(FRONT_YAW_DEG)
	var three: Image = await _lineup(THREE_QUARTER_YAW_DEG)
	front.convert(Image.FORMAT_RGB8)
	three.convert(Image.FORMAT_RGB8)
	_save(front, "npc_blockouts_front")
	_save(three, "npc_blockouts_34")
	var both: Image = Image.create(front.get_width(), front.get_height() * 2 + 6, false, Image.FORMAT_RGB8)
	both.fill(Color(0.08, 0.07, 0.12))
	both.blit_rect(front, Rect2i(Vector2i.ZERO, front.get_size()), Vector2i.ZERO)
	both.blit_rect(three, Rect2i(Vector2i.ZERO, three.get_size()), Vector2i(0, front.get_height() + 6))
	_save(both, "npc_blockouts_lineup")
	for entry: Array in CAST:
		await _close_up(entry[0] as String)
	quit(0 if _failures == 0 else 1)


func _play_idle(model: Node3D) -> void:
	for node: Node in model.find_children("*", "AnimationPlayer", true, false):
		var player: AnimationPlayer = node as AnimationPlayer
		if player.has_animation("idle"):
			player.play("idle")


func _lineup(yaw_deg: float) -> Image:
	for entry: Array in CAST:
		var model: Node3D = _models.get(entry[0] as String)
		if model == null:
			continue
		model.position = Vector3(entry[2] as float, 0.0, 0.0)
		model.rotation_degrees.y = yaw_deg
	_place_camera(LINEUP_CENTER, LINEUP_DISTANCE)
	return await _grab()


func _close_up(who: String) -> void:
	var model: Node3D = _models.get(who)
	if model == null:
		return
	for other: String in _models:
		_models[other].visible = other == who
	model.position = Vector3.ZERO
	model.rotation_degrees.y = THREE_QUARTER_YAW_DEG
	_place_camera(Vector3(0.0, CLOSE_CENTER_Y, 0.0), CLOSE_DISTANCE)
	_save(await _grab(), "npc_close_" + who)
	for other: String in _models:
		_models[other].visible = true


func _place_camera(center: Vector3, distance: float) -> void:
	var camera: Camera3D = _world.get_node("CloseCamera") as Camera3D
	var pitch: float = deg_to_rad(CAMERA_PITCH_DEG)
	camera.fov = CAMERA_FOV_DEG
	camera.global_position = center + Vector3(0.0, sin(pitch), cos(pitch)) * distance
	camera.look_at(center, Vector3.UP)
	camera.make_current()
	(_world.get_node("LightRig") as Node3D).rotation.y = 0.0


func _settle() -> void:
	for i: int in SETTLE_FRAMES:
		await process_frame


## The 384x216 picture exactly as the player sees it (post shader included), scaled up.
func _grab() -> Image:
	await _settle()
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var device_scale: float = root.get_final_transform().get_scale().x
	if device_scale <= 0.0:
		device_scale = 1.0
	var rect: Rect2 = _screen.call("get_display_rect")
	var region: Rect2i = Rect2i(Vector2i((rect.position * device_scale).round()), Vector2i((rect.size * device_scale).round()))
	return image.get_region(region.intersection(Rect2i(Vector2i.ZERO, image.get_size())))


func _save(image: Image, shot_name: String) -> void:
	var path: String = OUTPUT_DIR + shot_name + ".png"
	var err: Error = image.save_png(path)
	if err != OK:
		_failures += 1
	print("saved %s (%s), error %d" % [path, image.get_size(), err])
