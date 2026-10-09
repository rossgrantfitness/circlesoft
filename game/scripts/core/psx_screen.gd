class_name PsxScreen
extends Control
## The low-resolution PSX screen. The 3D world is drawn into a small SubViewport (384x216 by
## default), shown scaled up with nearest-neighbor filtering, with the dither / color-depth
## post shader on top. Menus and dialogue live on UILayer, which stays at full window sharpness.
##
## Scene layout (psx_screen.tscn):
##   Backdrop       black bars
##   WorldViewport  SubViewport at the internal resolution; the world goes in WorldViewport/World
##   Display        TextureRect showing the viewport, with psx_post.gdshader
##   UILayer        CanvasLayer for everything that must stay sharp
##
## Debug overlay API: get_resolutions(), set_resolution(), cycle_resolution(), set_integer_scaling().
## Resolutions and scaling rules come from data/world/psx_look.json.
##
## Note: nodes inside WorldViewport do not receive input events (only SubViewportContainer
## forwards them), so field scripts should poll Input or use autoloads / the UI layer for input.

signal resolution_changed(size: Vector2i)
signal layout_changed(display_rect: Rect2)

const LOOK_DATA_ID: String = "world/psx_look"
const GROUP_NAME: StringName = &"psx_screen"
const SNAP_SETTING: String = "shader_globals/psx_snap_res/value"

var _resolutions: Array[Vector2i] = []
var _resolution: Vector2i = Vector2i.ZERO
var _integer_scaling: bool = true
var _min_fill: float = 1.0
## Native: the world is drawn at the full window resolution (one picture pixel per screen pixel), so nothing is
## scaled and nothing is blurred. Switched by the look profile (Ps2Look); set_resolution() turns it off again.
var _native: bool = false

@onready var _viewport: SubViewport = $WorldViewport
@onready var _world: Node3D = $WorldViewport/World
@onready var _display: TextureRect = $Display
@onready var _ui_layer: CanvasLayer = $UILayer


func _ready() -> void:
	add_to_group(GROUP_NAME)
	_load_settings()
	LookProfiles.apply_grade(_display.material as ShaderMaterial, LookProfiles.active_id())
	resized.connect(_apply_layout)
	get_window().size_changed.connect(_apply_layout)
	set_resolution(_default_resolution())


# ---- public API ----

## The sharp UI layer: add menus, dialogue and portraits here.
func get_ui_layer() -> CanvasLayer:
	return _ui_layer


## The 3D world root inside the low-resolution viewport.
func get_world_root() -> Node3D:
	return _world


func get_world_viewport() -> SubViewport:
	return _viewport


## The TextureRect that shows the world (its material is the post shader).
func get_display() -> TextureRect:
	return _display


## Replaces whatever is in the world with a new instance of the scene. Returns the instance.
func load_world(scene: PackedScene) -> Node:
	clear_world()
	var instance: Node = scene.instantiate()
	_world.add_child(instance)
	return instance


## Takes everything out of the world WITHOUT freeing it, so a room can wait in memory while a battle
## uses the world (the technical plan's "detach and keep"). Hand the result to attach_world() later.
func detach_world() -> Array[Node]:
	var kept: Array[Node] = []
	for child: Node in _world.get_children():
		_world.remove_child(child)
		kept.append(child)
	return kept


## Puts nodes from detach_world() back into the world, in their old order.
func attach_world(nodes: Array[Node]) -> void:
	for node: Node in nodes:
		if is_instance_valid(node) and node.get_parent() == null:
			_world.add_child(node)


func clear_world() -> void:
	for child: Node in _world.get_children():
		_world.remove_child(child)
		child.queue_free()


func get_resolutions() -> Array[Vector2i]:
	return _resolutions.duplicate()


func get_resolution() -> Vector2i:
	return _resolution


## Switches the internal resolution. Only sizes in the list are accepted. Leaves native mode.
func set_resolution(size: Vector2i) -> bool:
	if not _resolutions.has(size):
		push_warning("PsxScreen: %s is not an allowed internal resolution" % size)
		return false
	_native = false
	_resolution = size
	_viewport.size = size
	PsxLook.set_internal_resolution(size)
	_apply_layout()
	resolution_changed.emit(size)
	return true


## Native mode: the world viewport is exactly the window's size in screen pixels and fills the whole window, and
## follows the window when it is resized. Returns the size in use.
func set_native(enabled: bool) -> Vector2i:
	if enabled == _native:
		return _resolution
	_native = enabled
	if _native:
		_apply_layout()
		resolution_changed.emit(_resolution)
	else:
		set_resolution(_default_resolution())
	return _resolution


func is_native() -> bool:
	return _native


## The window's size in screen pixels, which is what native mode renders at (at least 2x2).
func native_size() -> Vector2i:
	var device_scale: float = _device_scale()
	return Vector2i(maxi(2, roundi(size.x * device_scale)), maxi(2, roundi(size.y * device_scale)))


## Moves to the next resolution in the list (wraps around) and returns it.
func cycle_resolution() -> Vector2i:
	var index: int = _resolutions.find(_resolution)
	set_resolution(_resolutions[(index + 1) % _resolutions.size()])
	return _resolution


func set_integer_scaling(enabled: bool) -> void:
	_integer_scaling = enabled
	_apply_layout()


func is_integer_scaling() -> bool:
	return _integer_scaling


## How many screen pixels one internal pixel covers right now.
func get_display_scale() -> float:
	return _display.size.x * _device_scale() / float(_resolution.x)


## Where the picture sits, in this control's coordinates.
func get_display_rect() -> Rect2:
	return Rect2(_display.position, _display.size)


# ---- layout ----

## Pure layout rule. `available` and the result are in screen pixels. Picks a whole-number scale
## when that fills at least `min_fill` of the best possible fit, otherwise the best fit.
static func compute_display_rect(available: Vector2, internal: Vector2i, integer_scaling: bool, min_fill: float) -> Rect2:
	var fit: float = minf(available.x / float(internal.x), available.y / float(internal.y))
	var scale: float = fit
	if integer_scaling:
		var whole: float = floorf(fit)
		if whole >= 1.0 and whole >= fit * min_fill:
			scale = whole
	var picture: Vector2 = Vector2(internal) * scale
	var top_left: Vector2 = ((available - picture) * 0.5).floor()
	return Rect2(top_left, picture)


func _device_scale() -> float:
	var scale: float = get_viewport().get_final_transform().get_scale().x
	return scale if scale > 0.0 else 1.0


func _apply_layout() -> void:
	if not is_node_ready() or _resolution == Vector2i.ZERO:
		return
	var device_scale: float = _device_scale()
	var available: Vector2 = size * device_scale
	if _native:
		var wanted: Vector2i = native_size()
		if wanted != _resolution:
			_resolution = wanted
			_viewport.size = wanted
			PsxLook.set_internal_resolution(wanted)
			resolution_changed.emit(wanted)
		_display.position = Vector2.ZERO
		_display.size = Vector2(wanted) / device_scale
		layout_changed.emit(get_display_rect())
		return
	var rect: Rect2 = compute_display_rect(available, _resolution, _integer_scaling, _min_fill)
	_display.position = rect.position / device_scale
	_display.size = rect.size / device_scale
	layout_changed.emit(get_display_rect())


# ---- data ----

func _load_settings() -> void:
	_resolutions.clear()
	var entries: Variant = DataDB.get_value(LOOK_DATA_ID, "resolutions", [])
	for entry: Variant in entries:
		var dict: Dictionary = entry
		_resolutions.append(Vector2i(int(dict["width"]), int(dict["height"])))
	_integer_scaling = bool(DataDB.get_value(LOOK_DATA_ID, "integer_scaling", true))
	_min_fill = float(DataDB.get_value(LOOK_DATA_ID, "integer_scaling_min_fill", 1.0))
	if _resolutions.is_empty():
		# Data missing: fall back to the project's own snap grid so the game still runs.
		push_error("PsxScreen: no resolutions in data/world/psx_look.json")
		_resolutions.append(Vector2i(ProjectSettings.get_setting(SNAP_SETTING)))


func _default_resolution() -> Vector2i:
	var wanted: String = str(DataDB.get_value(LOOK_DATA_ID, "default_resolution", ""))
	var entries: Variant = DataDB.get_value(LOOK_DATA_ID, "resolutions", [])
	for entry: Variant in entries:
		var dict: Dictionary = entry
		if str(dict["id"]) == wanted:
			return Vector2i(int(dict["width"]), int(dict["height"]))
	return _resolutions[0]
