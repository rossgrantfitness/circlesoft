class_name PropFader
extends Node
## Fades tall props that stand between the camera and Red, and brings them back when clear.
##
## Props opt in by joining the group "fade_occluder". Each frame the fader checks the line from
## the target to the camera against every such prop's bounding box (grown by the occluder radius so
## Red's width counts), then eases each prop's `fade` shader instance parameter toward the faded or
## solid value. Works the same in perspective and orthographic.
##
## Shader contract (the psx_fade shader): `instance uniform float fade`, where 1 = solid and
## 0 = gone (dithered away). It is a per-instance parameter, so the fader sets it on each
## MeshInstance3D with set_instance_shader_parameter() and never touches the (shared) materials.
## Internally the fader thinks in "fade amount" (0 = solid .. 1 = gone) and writes fade = 1 - amount.

const OCCLUDER_GROUP: StringName = &"fade_occluder"
const FADE_PARAM: StringName = &"fade"
const SOLID: float = 0.0

@export var auto_update: bool = true

var target: Node3D = null
var camera: Camera3D = null
## Height above the target's feet that the line starts from (roughly Red's middle).
var target_anchor_height: float = 0.5

var _tuning: FieldTuning = FieldTuning.new()
## prop instance id -> current fade amount
var _fade: Dictionary[int, float] = {}
## prop instance id -> the MeshInstance3D nodes under it that get the instance parameter
var _meshes: Dictionary[int, Array] = {}


func _ready() -> void:
	_tuning = FieldTuning.from_db(get_node_or_null("/root/DataDB"))


func _physics_process(delta: float) -> void:
	if auto_update:
		update_fades(delta)


func set_tuning(tuning: FieldTuning) -> void:
	_tuning = tuning


func set_target(node: Node3D) -> void:
	target = node


func set_camera(cam: Camera3D) -> void:
	camera = cam


## The current fade of a prop (0 solid .. 1 gone). Props never faded read as solid.
func get_fade(prop: Node3D) -> float:
	return _fade.get(prop.get_instance_id(), SOLID)


## One step: work out which props are in the way and ease every prop's fade.
func update_fades(delta: float) -> void:
	if target == null or camera == null or not is_inside_tree():
		return
	var from: Vector3 = target.global_position + Vector3.UP * target_anchor_height
	var to: Vector3 = viewing_point(from, camera)
	for node: Node in get_tree().get_nodes_in_group(OCCLUDER_GROUP):
		var prop: Node3D = node as Node3D
		if prop == null:
			continue
		var blocked: bool = is_occluding(from, to, world_bounds(prop), _tuning.fade_occluder_radius)
		var id: int = prop.get_instance_id()
		var current: float = _fade.get(id, SOLID)
		if not _meshes.has(id):
			_meshes[id] = _find_meshes(prop)
		var next: float = step_fade(current, blocked, delta, _tuning.fade_out_per_s, _tuning.fade_in_per_s,
				_tuning.fade_max_amount)
		if not is_equal_approx(next, current) or not _fade.has(id):
			_fade[id] = next
			_apply(id, next)


# ---- pure helpers (static so tests can call them with no scene) ----

## Where the line from the target toward the viewer ends. A perspective camera is a point; an
## orthographic camera looks along its own axis, so the line runs straight back along it.
static func viewing_point(from: Vector3, cam: Camera3D) -> Vector3:
	var cam_pos: Vector3 = cam.global_position
	if cam.projection == Camera3D.PROJECTION_ORTHOGONAL:
		var back: Vector3 = cam.global_basis.z
		var reach: float = maxf((cam_pos - from).dot(back), 0.0)
		return from + back * reach
	return cam_pos


## True when the segment from `from` to `to` passes through the box grown by `radius`.
static func is_occluding(from: Vector3, to: Vector3, box: AABB, radius: float) -> bool:
	if box.size == Vector3.ZERO:
		return false
	var grown: AABB = box.grow(radius)
	return grown.has_point(from) or grown.intersects_segment(from, to) != null


## Moves a fade value toward faded (max_fade) or solid at the given per-second rates.
static func step_fade(current: float, occluded: bool, delta: float, out_per_s: float, in_per_s: float,
		max_fade: float) -> float:
	if occluded:
		return minf(current + out_per_s * delta, max_fade)
	return maxf(current - in_per_s * delta, SOLID)


## World-space bounding box of every mesh under `prop` (including the prop itself).
static func world_bounds(prop: Node3D) -> AABB:
	var found: bool = false
	var result: AABB = AABB()
	var stack: Array[Node] = [prop]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		var visual: VisualInstance3D = node as VisualInstance3D
		if visual == null:
			continue
		var box: AABB = visual.global_transform * visual.get_aabb()
		result = box if not found else result.merge(box)
		found = true
	return result


# ---- applying ----

## The solid-is-1 value the shader wants for a fade amount.
static func shader_value(amount: float) -> float:
	return 1.0 - amount


func _find_meshes(prop: Node3D) -> Array:
	var found: Array[MeshInstance3D] = []
	var stack: Array[Node] = [prop]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance != null:
			found.append(mesh_instance)
	return found


func _apply(id: int, amount: float) -> void:
	for entry: Variant in _meshes.get(id, []):
		var mesh_instance: MeshInstance3D = entry as MeshInstance3D
		if is_instance_valid(mesh_instance):
			mesh_instance.set_instance_shader_parameter(FADE_PARAM, shader_value(amount))
