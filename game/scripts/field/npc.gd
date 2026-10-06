class_name Npc
extends Node3D
## A character standing in a room. PLACEHOLDER LOOK ONLY (a big round head on a small capsule body
## in the character's colors, little eyes so you can see which way they face); the real model
## replaces the Visual node when the art style is chosen.
##
## Gently bobs while idle, turns to face Red when she talks to them (or when they speak) and turns
## back afterwards, and offers a head point for speech bubbles. The speaker id matches the
## dialogue data (otis, mox, zero_old). Its Interactable child gets the conversation settings from
## the exports below, so a room only has to set them on the NPC.
##
## Facing: the model looks along local +Z, like Red.

const GROUP: StringName = &"npc"
const SHADER_PATH: String = "res://shaders/psx_lit.gdshader"
const TEXTURE_PATH: String = "res://art/placeholder/textures/checker_128.png"
const NODE_VISUAL: NodePath = ^"Visual"
const NODE_INTERACTABLE: NodePath = ^"Interactable"
const BODY_RADIUS: float = 0.2
const BODY_HEIGHT: float = 0.5
const HEAD_RADIUS: float = 0.3
const HEAD_CENTER_Y: float = 0.7
const HEAD_TOP_Y: float = 1.0
const BUBBLE_LIFT: float = 0.1
const EYE_COLOR: Color = Color(0.08, 0.07, 0.12)
const MASK_COLOR: Color = Color(0.3, 0.33, 0.38)

enum Extra { NONE, WELDING_MASK, WRAP }

@export var speaker_id: String = ""
@export var body_color: Color = Color(0.6, 0.5, 0.4)
@export var head_color: Color = Color(0.85, 0.7, 0.55)
@export var extra: Extra = Extra.NONE
@export var extra_color: Color = Color(0.3, 0.33, 0.38)
## Overall size of the placeholder (Otis is big, Zero is small and old).
@export var height_scale: float = 1.0
@export_group("Conversation")
@export var kind: Interactable.Kind = Interactable.Kind.TALK
@export var conversation: String = ""
@export var after_flag: String = ""
@export var after_conversation: String = ""
@export var set_flag_on_start: String = ""
@export var reach: float = 0.0

var tuning: InteractionTuning = InteractionTuning.new()

var _visual: Node3D = null
var _rest_yaw: float = 0.0
var _wanted_yaw: float = 0.0
var _clock: float = 0.0
var _interactable: Interactable = null


func _ready() -> void:
	add_to_group(GROUP)
	tuning = InteractionTuning.from_db(get_node_or_null("/root/DataDB"))
	_rest_yaw = rotation.y
	_wanted_yaw = _rest_yaw
	_clock = float(speaker_id.hash() % 1000) * 0.01
	_visual = get_node_or_null(NODE_VISUAL) as Node3D
	if _visual != null:
		_build_look(_visual)
	_interactable = get_node_or_null(NODE_INTERACTABLE) as Interactable
	if _interactable != null:
		_interactable.kind = kind
		_interactable.conversation = conversation
		_interactable.after_flag = after_flag
		_interactable.after_conversation = after_conversation
		_interactable.set_flag_on_start = set_flag_on_start
		_interactable.reach = reach
		_interactable.talk_started.connect(face_point)
		_interactable.talk_finished.connect(release_facing)


func _process(delta: float) -> void:
	step(delta)


## One animation step (turning and the idle bob). Public so tests can drive it.
func step(delta: float) -> void:
	_clock += delta
	rotation.y = PlayerMotion.turn_toward(rotation.y, _wanted_yaw, tuning.npc_turn_rate_deg_per_s, delta)
	if _visual != null and tuning.npc_bob_period_s > 0.0:
		_visual.position.y = tuning.npc_bob_height * (0.5 + 0.5 * sin(_clock * TAU / tuning.npc_bob_period_s))


## Turn to look at a point in the room (flat).
func face_point(point: Vector3) -> void:
	var offset: Vector3 = point - global_position
	offset.y = 0.0
	if offset.length() < PlayerMotion.MIN_FLAT_LENGTH:
		return
	_wanted_yaw = PlayerMotion.yaw_for_direction(offset.normalized())


## Turn back to the way they were standing.
func release_facing() -> void:
	_wanted_yaw = _rest_yaw


func get_rest_yaw() -> float:
	return _rest_yaw


func get_wanted_yaw() -> float:
	return _wanted_yaw


## The unit direction the character faces (flat).
func get_facing() -> Vector3:
	return global_basis.z


func get_interactable() -> Interactable:
	return _interactable


## How far above the node's origin a speech bubble's tail should point.
func get_head_height() -> float:
	return HEAD_TOP_Y * height_scale + BUBBLE_LIFT


## Where a bubble points (world space).
func get_head_point() -> Vector3:
	return global_position + Vector3.UP * get_head_height()


# ---- placeholder look ----

func _build_look(root: Node3D) -> void:
	root.scale = Vector3.ONE * height_scale
	var body: MeshInstance3D = _mesh_part(CapsuleMesh.new(), body_color)
	var capsule: CapsuleMesh = body.mesh as CapsuleMesh
	capsule.radius = BODY_RADIUS
	capsule.height = BODY_HEIGHT
	capsule.radial_segments = 8
	capsule.rings = 2
	body.name = "Body"
	body.position = Vector3(0.0, BODY_HEIGHT * 0.5, 0.0)
	root.add_child(body)
	var head: MeshInstance3D = _mesh_part(SphereMesh.new(), head_color)
	var sphere: SphereMesh = head.mesh as SphereMesh
	sphere.radius = HEAD_RADIUS
	sphere.height = HEAD_RADIUS * 2.0
	sphere.radial_segments = 10
	sphere.rings = 5
	head.name = "Head"
	head.position = Vector3(0.0, HEAD_CENTER_Y, 0.0)
	root.add_child(head)
	for side: float in [-1.0, 1.0]:
		var eye: MeshInstance3D = _box_part(Vector3(0.06, 0.08, 0.04), EYE_COLOR)
		eye.name = "EyeRight" if side > 0.0 else "EyeLeft"
		eye.position = Vector3(0.1 * side, HEAD_CENTER_Y + 0.02, HEAD_RADIUS - 0.02)
		root.add_child(eye)
	match extra:
		Extra.WELDING_MASK:
			var mask: MeshInstance3D = _box_part(Vector3(0.4, 0.14, 0.1), extra_color)
			mask.name = "WeldingMask"
			mask.position = Vector3(0.0, HEAD_CENTER_Y + 0.2, HEAD_RADIUS - 0.06)
			mask.rotation.x = deg_to_rad(-25.0)
			root.add_child(mask)
		Extra.WRAP:
			var wrap: MeshInstance3D = _mesh_part(CylinderMesh.new(), extra_color)
			var ring: CylinderMesh = wrap.mesh as CylinderMesh
			ring.top_radius = BODY_RADIUS + 0.06
			ring.bottom_radius = BODY_RADIUS + 0.06
			ring.height = 0.14
			ring.radial_segments = 8
			ring.rings = 1
			wrap.name = "Wrap"
			wrap.position = Vector3(0.0, BODY_HEIGHT - 0.02, 0.0)
			root.add_child(wrap)


func _box_part(size: Vector3, color: Color) -> MeshInstance3D:
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	return _mesh_part(box, color)


func _mesh_part(mesh: Mesh, color: Color) -> MeshInstance3D:
	var part: MeshInstance3D = MeshInstance3D.new()
	part.mesh = mesh
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load(SHADER_PATH) as Shader
	material.set_shader_parameter("albedo_texture", load(TEXTURE_PATH))
	material.set_shader_parameter("albedo_tint", color)
	part.material_override = material
	return part
