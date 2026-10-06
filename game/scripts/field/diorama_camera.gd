class_name DioramaCamera
extends Node3D
## The fixed diorama camera rig. One high angle per room that NEVER rotates: the rig keeps the
## same rotation (set from pitch/yaw below) for as long as the room is loaded and only slides.
##
## It follows `target` with smoothing, keeps the target inside a safe frame margin, and clamps the
## point it looks at to the room's camera bounds. Perspective (default, narrow FOV) and
## orthographic projection can be switched at runtime with set_projection_mode().
##
## Scene layout: this Node3D owns a child Camera3D (created if missing). Per-room look
## (pitch, yaw, FOV, distance) lives in the exported fields so each room sets its own.
## Tunables (smoothing, safe margin) come from data/world/field_tuning.json via DataDB.

enum ProjectionMode { PERSPECTIVE, ORTHOGRAPHIC }

## Every rig joins this group so the debug overlay can find the active one.
const GROUP_NAME: StringName = &"diorama_camera"

@export_group("Room look")
## Degrees looking down (style guide: about 40 to 45).
@export var pitch_deg: float = 42.0
## Degrees around the vertical axis. Fixed for the room; never changes while following.
@export var yaw_deg: float = 0.0
## Vertical field of view in perspective mode. Narrow, so it reads like a toy box.
@export var fov_deg: float = 30.0
## How far the camera sits from the point it looks at (about 10.5 frames ~10 x 5.6 units of floor).
@export var distance: float = 10.5
@export var near_clip: float = 0.5
@export var far_clip: float = 60.0
@export_group("Following")
## Height above the target's feet that is kept in frame (roughly Red's middle).
@export var target_anchor_height: float = 0.5
## Update every frame by itself. Cutscenes or tests can turn this off and call update_camera().
@export var auto_update: bool = true
## Force a screen aspect (width / height). 0 = use the viewport's.
@export var aspect_override: float = 0.0

var target: Node3D = null

var _camera: Camera3D = null
var _tuning: FieldTuning = FieldTuning.new()
var _mode: ProjectionMode = ProjectionMode.PERSPECTIVE
var _focus: Vector3 = Vector3.ZERO
var _fixed_basis: Basis = Basis.IDENTITY
var _has_bounds: bool = false
var _bounds: AABB = AABB()


func _ready() -> void:
	add_to_group(GROUP_NAME)
	top_level = true
	_camera = get_node_or_null("Camera3D") as Camera3D
	if _camera == null:
		_camera = Camera3D.new()
		_camera.name = "Camera3D"
		add_child(_camera)
	_tuning = FieldTuning.from_db(get_node_or_null("/root/DataDB"))
	_apply_look()
	if target != null:
		snap_to_target()


func _process(delta: float) -> void:
	if auto_update:
		update_camera(delta)


# ---- setup ----

func get_camera() -> Camera3D:
	return _camera


## Replace the tuning (tests, or a room that overrides it). Normal use reads DataDB in _ready().
func set_tuning(tuning: FieldTuning) -> void:
	_tuning = tuning


func set_target(node: Node3D) -> void:
	target = node


## The room's camera bounds. The point the camera looks at stays inside this box on X and Z.
func set_bounds(bounds: AABB) -> void:
	_bounds = bounds.abs()
	_has_bounds = true


## Same, from a flat rectangle on the floor (x, y of the Rect2 are world X and Z).
func set_bounds_rect(rect: Rect2) -> void:
	var flat: Rect2 = rect.abs()
	set_bounds(AABB(Vector3(flat.position.x, 0.0, flat.position.y), Vector3(flat.size.x, 0.0, flat.size.y)))


func clear_bounds() -> void:
	_has_bounds = false


func has_bounds() -> bool:
	return _has_bounds


func get_bounds() -> AABB:
	return _bounds


## Change the room's fixed look (a new room, or a debug toggle). Not used while following.
func set_room_look(new_pitch_deg: float, new_yaw_deg: float, new_fov_deg: float, new_distance: float) -> void:
	pitch_deg = new_pitch_deg
	yaw_deg = new_yaw_deg
	fov_deg = new_fov_deg
	distance = new_distance
	_apply_look()


# ---- projection ----

func set_projection_mode(mode: ProjectionMode) -> void:
	_mode = mode
	_apply_look()


func get_projection_mode() -> ProjectionMode:
	return _mode


func toggle_projection_mode() -> void:
	set_projection_mode(ProjectionMode.ORTHOGRAPHIC if _mode == ProjectionMode.PERSPECTIVE else ProjectionMode.PERSPECTIVE)


func is_perspective() -> bool:
	return _mode == ProjectionMode.PERSPECTIVE


## Changes the perspective FOV (the debug overlay flips between narrow options).
func set_fov_deg(new_fov_deg: float) -> void:
	fov_deg = new_fov_deg
	_apply_look()


## Orthographic height that frames the same area as the perspective shot.
func get_ortho_size() -> float:
	return DioramaMath.matching_ortho_size(fov_deg, distance)


# ---- following ----

func get_focus() -> Vector3:
	return _focus


## The fixed rotation of this room's camera.
func get_fixed_basis() -> Basis:
	return _fixed_basis


## Jumps straight onto the target (room load, teleport) with no smoothing.
func snap_to_target() -> void:
	if target == null:
		return
	_focus = _bounded(_anchor())
	_place()


## One camera step: smooth toward the target, slide to keep it in the safe frame, clamp to bounds.
func update_camera(delta: float) -> void:
	if target != null:
		var anchor: Vector3 = _anchor()
		var wanted: Vector3 = _bounded(anchor)
		_focus = _focus.lerp(wanted, DioramaMath.smooth_alpha(_tuning.camera_smoothing, delta))
		_focus = DioramaMath.slide_into_safe_frame(_focus, anchor, _fixed_basis, distance, is_perspective(),
				fov_deg, get_ortho_size(), _aspect(), _tuning.camera_safe_frame_margin)
		_focus = _bounded(_focus)
	_place()


## Where a world point lands on screen, 0..1 from the top left (like a 2D viewport position).
func world_to_screen(world: Vector3) -> Vector2:
	var ndc: Vector2 = DioramaMath.project(world, DioramaMath.camera_origin(_focus, _fixed_basis, distance),
			_fixed_basis, is_perspective(), fov_deg, get_ortho_size(), _aspect())
	return Vector2(ndc.x * 0.5 + 0.5, 0.5 - ndc.y * 0.5)


## True when the target's anchor point is inside the safe frame (margin from every edge).
func is_target_in_safe_frame() -> bool:
	if target == null:
		return true
	var screen: Vector2 = world_to_screen(_anchor())
	var margin: float = _tuning.camera_safe_frame_margin
	var slack: float = DioramaMath.SAFE_FRAME_EPSILON
	return screen.x >= margin - slack and screen.x <= 1.0 - margin + slack \
			and screen.y >= margin - slack and screen.y <= 1.0 - margin + slack


# ---- internals ----

func _anchor() -> Vector3:
	return target.global_position + Vector3.UP * target_anchor_height


func _bounded(point: Vector3) -> Vector3:
	if _has_bounds:
		return DioramaMath.clamp_to_bounds(point, _bounds)
	return point


func _aspect() -> float:
	if aspect_override > 0.0:
		return aspect_override
	if is_inside_tree():
		var size: Vector2 = get_viewport().get_visible_rect().size
		if size.y > 0.0:
			return size.x / size.y
	return 1.0


func _apply_look() -> void:
	_fixed_basis = DioramaMath.orientation(pitch_deg, yaw_deg)
	if _camera == null:
		return
	_camera.near = near_clip
	_camera.far = far_clip
	_camera.fov = fov_deg
	if _mode == ProjectionMode.ORTHOGRAPHIC:
		_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		_camera.size = get_ortho_size()
	else:
		_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_place()


## Writes the rig's transform: the fixed rotation, positioned from the focus point.
func _place() -> void:
	if not is_inside_tree():
		return
	global_transform = Transform3D(_fixed_basis, DioramaMath.camera_origin(_focus, _fixed_basis, distance))
