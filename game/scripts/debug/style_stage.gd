class_name StyleStage
extends Node
## The neutral turntable stage for the Red style prototypes (docs/red_style_prototypes.md).
## Everything is drawn through the real PsxScreen at 384x216, so what you see is what the game shows:
## vertex jitter, affine warp, 15-bit color with the 4x4 dither, vertex lighting and a blob shadow.
##
## The stage itself (floor disc, crate, lights, cameras) is scenes/debug/style_stage_world.tscn; this
## script loads one prototype at a time into it and moves the cameras. The lights ride on a rig that
## turns with the close-up camera, so every view of every prototype is lit the same way: a warm
## Lamp-amber key from front-left above and a dim cool fill from back-right.
##
## Run it by hand:   godot --path game res://scenes/debug/style_stage.tscn
##   Left / Right = previous / next prototype, Up / Down = turn, G = grin, S = silhouette,
##   C = toggle in-game camera. tests/visual/capture_red_prototypes.gd drives it for screenshots.

const WORLD_SCENE: PackedScene = preload("res://scenes/debug/style_stage_world.tscn")
const MODEL_DIR: String = "res://art/placeholder/characters/red_prototypes"
const MODEL_PREFIX: String = "red_proto_"
const MODEL_EXTENSION: String = "glb"

## Names from the brief. A letter that is not listed shows its letter only.
const PROTOTYPE_NAMES: Dictionary[String, String] = {
	"a": "Wind-Up Toy",
	"b": "Button Pup",
	"c": "Picture-Book",
	"d": "Ink Line",
	"e": "Rubber Bounce",
	"f": "Shiba (E + C)",
}

## Close views: how far the camera orbits (degrees) from straight in front of her.
## Negative = her right side (the sword side), the signature silhouette.
const VIEW_YAW_DEG: Dictionary[String, float] = {
	"front": 0.0,
	"34": -35.0,
	"side": -90.0,
	"back": 180.0,
}
const CLOSE_PITCH_DEG: float = 8.0
const CLOSE_FOV_DEG: float = 30.0
## Slack around the tallest prototype so nothing touches the frame edge.
const CLOSE_MARGIN: float = 1.14
## The room's real camera: pitch 42, yaw 35, fov 30, distance 11 (scenes/debug/psx_test_room.tscn).
const GAME_CAMERA_YAW_DEG: float = 35.0
## Red turned so the camera sees her right front (sword side) while she stands beside the crate.
const INGAME_RED_YAW_DEG: float = 70.0
## The face sheet is 4 x 2 cells of 32 px: cell 0 neutral, cell 1 grin.
const GRIN_UV_OFFSET: Vector2 = Vector2(0.25, 0.0)
## Prototypes E and F paint two 64 px expression cells (neutral left, grin right), so their grin
## cell is half a sheet over. Everything else uses the 32 px cells above.
const GRIN_UV_OFFSET_BY_LETTER: Dictionary[String, Vector2] = {"e": Vector2(0.5, 0.0), "f": Vector2(0.5, 0.0)}
## Face materials end in "_face" (or "_face_unlit" for D's eye decals).
const FACE_MATERIAL_MARK: String = "_face"
const INK: Color = Color(0.0784, 0.0706, 0.1216)
const SHADOW_TEXTURE_SIZE: int = 16
const TURN_SPEED_DEG: float = 60.0

var current_letter: String = ""

var _loaded_path: String = ""

var _world: Node3D = null
var _model: Node3D = null
var _light_rig: Node3D = null
var _close_camera: Camera3D = null
var _game_camera: DioramaCamera = null
var _pivot: Node3D = null
var _crate: MeshInstance3D = null
var _ink_material: ShaderMaterial = null
var _frame_center: Vector3 = Vector3(0.0, 0.6, 0.0)
var _frame_distance: float = 3.2
var _close_yaw_deg: float = 0.0
var _in_game_view: bool = false
var _grin: bool = false
var _silhouette: bool = false
var _letters: Array[String] = []

@onready var screen: PsxScreen = $PsxScreen


func _ready() -> void:
	_world = screen.load_world(WORLD_SCENE) as Node3D
	_light_rig = _world.get_node("LightRig")
	_close_camera = _world.get_node("CloseCamera")
	_game_camera = _world.get_node("GameCamera")
	_pivot = _world.get_node("ModelPivot")
	_crate = _world.get_node("Crate")
	_ink_material = ShaderMaterial.new()
	_ink_material.shader = preload("res://shaders/psx_unlit.gdshader")
	_ink_material.set_shader_parameter("albedo_tint", INK)
	_world.get_node("BlobShadow").get("surface_material_override/0").set_shader_parameter(
			"albedo_texture", _make_shadow_texture())
	_letters = available_prototypes()
	if not _letters.is_empty():
		load_prototype(_letters[0])
		frame_for(_letters)
	show_close("34")


func _process(delta: float) -> void:
	if Input.is_action_pressed("ui_up"):
		_close_yaw_deg += TURN_SPEED_DEG * delta
	if Input.is_action_pressed("ui_down"):
		_close_yaw_deg -= TURN_SPEED_DEG * delta
	if Input.is_action_pressed("ui_up") or Input.is_action_pressed("ui_down"):
		_place_close_camera()


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_RIGHT:
			_step_prototype(1)
		KEY_LEFT:
			_step_prototype(-1)
		KEY_G:
			set_expression(not _grin)
		KEY_S:
			set_silhouette(not _silhouette)
		KEY_C:
			if _in_game_view:
				show_close("34")
			else:
				show_ingame()


# ---- prototypes ----

## Letters of every red_proto_<letter>.glb that exists, sorted. 3 or 5 or any number works.
static func available_prototypes() -> Array[String]:
	var letters: Array[String] = []
	for file_name: String in DirAccess.get_files_at(MODEL_DIR):
		if file_name.get_extension() != MODEL_EXTENSION or not file_name.begins_with(MODEL_PREFIX):
			continue
		var stem: String = file_name.get_basename().trim_prefix(MODEL_PREFIX)
		if stem.length() == 1:
			letters.append(stem)
	letters.sort()
	return letters


static func prototype_name(letter: String) -> String:
	return PROTOTYPE_NAMES.get(letter, "")


static func model_path(letter: String) -> String:
	return "%s/%s%s.%s" % [MODEL_DIR, MODEL_PREFIX, letter, MODEL_EXTENSION]


## Puts one prototype on the stage (replacing the last one). Returns false if it will not load.
func load_prototype(letter: String) -> bool:
	return load_model_file(model_path(letter), letter)


## Puts any model .glb on the stage (replacing the last one); `label` becomes current_letter. The
## animated placeholder Red (art/placeholder/characters/red/red_shiba.glb) is shown this way.
func load_model_file(path: String, label: String) -> bool:
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		push_error("StyleStage: cannot load " + path)
		return false
	if _model != null:
		_pivot.remove_child(_model)
		_model.queue_free()
	_model = scene.instantiate() as Node3D
	_pivot.add_child(_model)
	_loaded_path = path
	current_letter = label
	set_expression(_grin)
	set_silhouette(_silhouette)
	return true


## Fits the close camera to the tallest of the given prototypes, so the same distance serves all of
## them (their sizes stay comparable) and nothing is cut off. Loads each one briefly to measure it.
func frame_for(letters: Array[String]) -> void:
	var keep: String = current_letter
	var box: AABB = AABB()
	var first: bool = true
	for letter: String in letters:
		if not load_prototype(letter):
			continue
		var b: AABB = model_bounds(_model)
		box = b if first else box.merge(b)
		first = false
	if keep != "":
		load_prototype(keep)
	if first:
		return
	_frame_center = box.get_center()
	_frame_center.x = 0.0
	_frame_center.z = 0.0
	var half_fov: float = deg_to_rad(CLOSE_FOV_DEG) * 0.5
	_frame_distance = (box.size.y * CLOSE_MARGIN * 0.5) / tan(half_fov)
	# Width: the widest silhouette over any turn is the model's horizontal diagonal.
	var reach: float = maxf(absf(box.position.x), absf(box.end.x))
	reach = maxf(reach, maxf(absf(box.position.z), absf(box.end.z)))
	var aspect: float = 16.0 / 9.0
	_frame_distance = maxf(_frame_distance, reach * CLOSE_MARGIN / (tan(half_fov) * aspect))


## Like frame_for, but for model files by path (the grim Red next to the classic one). Both are measured,
## and the close camera is fitted to the taller, so the two stay comparable.
func frame_for_models(paths: Array[String]) -> void:
	var keep: String = current_letter
	var keep_path: String = _loaded_path
	var box: AABB = AABB()
	var first: bool = true
	for path: String in paths:
		if not load_model_file(path, "measure"):
			continue
		var b: AABB = model_bounds(_model)
		box = b if first else box.merge(b)
		first = false
	if keep_path != "":
		load_model_file(keep_path, keep)
	if first:
		return
	_frame_center = box.get_center()
	_frame_center.x = 0.0
	_frame_center.z = 0.0
	var half_fov: float = deg_to_rad(CLOSE_FOV_DEG) * 0.5
	_frame_distance = (box.size.y * CLOSE_MARGIN * 0.5) / tan(half_fov)
	var reach: float = maxf(maxf(absf(box.position.x), absf(box.end.x)), maxf(absf(box.position.z), absf(box.end.z)))
	_frame_distance = maxf(_frame_distance, reach * CLOSE_MARGIN / (tan(half_fov) * (16.0 / 9.0)))


## Bounds of every mesh under a model, in world space (the model sits at the stage origin).
static func model_bounds(model: Node3D) -> AABB:
	var box: AABB = AABB()
	var first: bool = true
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var b: AABB = mesh_instance.global_transform * mesh_instance.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _step_prototype(direction: int) -> void:
	if _letters.is_empty():
		return
	var index: int = _letters.find(current_letter)
	load_prototype(_letters[posmod(index + direction, _letters.size())])


# ---- views ----

## One of "front", "34" (three-quarter), "side", "back". Close camera, Red alone on the disc.
func show_close(view: String) -> void:
	_in_game_view = false
	_crate.visible = false
	_pivot.rotation_degrees.y = 0.0
	_close_yaw_deg = VIEW_YAW_DEG.get(view, 0.0)
	_close_camera.make_current()
	_place_close_camera()


func _place_close_camera() -> void:
	var yaw: float = deg_to_rad(_close_yaw_deg)
	var pitch: float = deg_to_rad(CLOSE_PITCH_DEG)
	var offset: Vector3 = Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * _frame_distance
	_close_camera.fov = CLOSE_FOV_DEG
	_close_camera.global_position = _frame_center + offset
	_close_camera.look_at(_frame_center, Vector3.UP)
	_light_rig.rotation.y = yaw


## The true in-game shot: the room's own camera rig (pitch 42, yaw 35, fov 30, distance 11)
## with Red standing beside the 0.8 unit crate.
func show_ingame() -> void:
	_in_game_view = true
	_crate.visible = true
	_pivot.rotation_degrees.y = INGAME_RED_YAW_DEG
	_light_rig.rotation.y = deg_to_rad(GAME_CAMERA_YAW_DEG)
	_game_camera.set_target(_pivot)
	_game_camera.snap_to_target()
	_game_camera.get_camera().make_current()


## Freezes the model on one frame of one of its clips (for pose strips). False if there is no such clip.
func pose_clip(clip: String, seconds: float) -> bool:
	if _model == null:
		return false
	var players: Array[Node] = _model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty() or not (players[0] as AnimationPlayer).has_animation(clip):
		return false
	var player: AnimationPlayer = players[0] as AnimationPlayer
	player.play(clip)
	player.seek(seconds, true)
	player.pause()
	return true


## Neutral or grin cell of the face sheet (a UV shift on the face material).
func set_expression(grin: bool) -> void:
	_grin = grin
	if _model == null:
		return
	for node: Node in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		for surface: int in mesh_instance.get_surface_override_material_count():
			var source: Material = mesh_instance.mesh.surface_get_material(surface)
			if source == null or not source.resource_name.contains(FACE_MATERIAL_MARK):
				continue
			if not grin:
				mesh_instance.set_surface_override_material(surface, null)
				continue
			var shifted: ShaderMaterial = (source as ShaderMaterial).duplicate() as ShaderMaterial
			shifted.set_shader_parameter("uv_offset", GRIN_UV_OFFSET_BY_LETTER.get(current_letter, GRIN_UV_OFFSET))
			mesh_instance.set_surface_override_material(surface, shifted)


## Solid Ink fill for Red and the crate (the style guide's "who is it in black at 40 px" check).
func set_silhouette(enabled: bool) -> void:
	_silhouette = enabled
	var material: Material = _ink_material if enabled else null
	_crate.material_override = material
	if _model == null:
		return
	for node: Node in _model.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).material_override = material


func get_game_camera() -> DioramaCamera:
	return _game_camera


## The 384x216 picture exactly as the player sees it (post shader included), scaled up by the
## whole-number factor PsxScreen chose. Needs a real renderer.
func grab_picture() -> Image:
	var image: Image = get_viewport().get_texture().get_image()
	var device_scale: float = get_viewport().get_final_transform().get_scale().x
	if device_scale <= 0.0:
		device_scale = 1.0
	var rect: Rect2 = screen.get_display_rect()
	var region: Rect2i = Rect2i(Vector2i((rect.position * device_scale).round()), Vector2i((rect.size * device_scale).round()))
	return image.get_region(region.intersection(Rect2i(Vector2i.ZERO, image.get_size())))


# ---- blob shadow ----

## A dithered dark disc: a solid core with a checkerboard edge, 1-bit cut-out like everything else.
func _make_shadow_texture() -> ImageTexture:
	var size: int = SHADOW_TEXTURE_SIZE
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var centre: float = (size - 1) * 0.5
	for y: int in size:
		for x: int in size:
			var d: float = Vector2(x - centre, y - centre).length() / (size * 0.5)
			var on: bool = d < 0.62 or (d < 0.95 and (x + y) % 2 == 0)
			image.set_pixel(x, y, Color(1, 1, 1, 1.0 if on else 0.0))
	return ImageTexture.create_from_image(image)
