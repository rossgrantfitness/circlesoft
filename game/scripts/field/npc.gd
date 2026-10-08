class_name Npc
extends Node3D
## A character standing in a room.
##
## The look is a model loaded BY PATH (model_path, a .glb or .tscn) under the Visual node. If a model
## has an AnimationPlayer with a clip named by idle_clip ("idle"), it plays on a loop; no other clip
## names are needed, and a model with no clips still works (it just stands and bobs). So an outsourced
## model can drop in by changing model_path (and head_height in data/ui/dialogue_ui.json), with no code
## changes. With no model_path (or one that fails to load) a placeholder stands in: a big round head on
## a small capsule body in the character's colors, little eyes so you can see which way they face.
##
## Gently bobs while idle (a slow whole-body bob in code, on top of the model's own idle clip),
## turns to face Red when she talks to them (or when they speak) and turns back afterwards, and offers
## a head point for speech bubbles. The head point is measured from the model itself (the top of the
## model's meshes, not counting held props and floating things whose mesh name contains "_prop_"), so
## it follows whatever model is loaded. The speaker id matches the dialogue data (otis, mox,
## zero_old). Its Interactable child gets the conversation settings from the exports below, so a room
## only has to set them on the NPC.
##
## Facing: the model looks along local +Z, like Red.

const GROUP: StringName = &"npc"
const SHADER_PATH: String = "res://shaders/psx_lit.gdshader"
const TEXTURE_PATH: String = "res://art/placeholder/textures/checker_128.png"
const NODE_VISUAL: NodePath = ^"Visual"
const NODE_INTERACTABLE: NodePath = ^"Interactable"
const NODE_COLLISION: NodePath = ^"Body/CollisionShape3D"
## Meshes whose name contains this are held or floating props (shield, wrench, drone): they do not count
## toward the head height.
const PROP_MARK: String = "_prop_"
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
## The character model (.glb or .tscn), loaded when the room starts. Empty = the capsule placeholder.
@export_file("*.glb", "*.tscn") var model_path: String = ""
## Which clip of the model's AnimationPlayer loops while the NPC stands around.
@export var idle_clip: StringName = &"idle"
## Multiplies every material of the loaded model. The test room's dim blue ambient light would grey a
## warm palette out (cream fur and ivory hats read lavender-gray), so the NPC materials are pushed warm
## and a touch bright to land back on the painted colors. Fix it here, per model, not in the room's
## lighting. White = off. An outsourced model that is already tuned for the room sets this to white.
@export var light_compensation: Color = Color(1.28, 1.1, 0.86)
## How wide and tall the solid body is (a cylinder standing on the floor), so Red bumps into the
## character and not into thin air or a long way off.
@export var collision_radius: float = 0.3
@export var collision_height: float = 1.1
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
var _model: Node3D = null
var _player: AnimationPlayer = null
var _model_head_top: float = 0.0
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
		if not _load_model(_visual):
			_build_look(_visual)
	_fit_collision()
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


## Makes the way they face now the way they go back to after a conversation (after being walked somewhere).
func settle_facing() -> void:
	_rest_yaw = _wanted_yaw


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
	if _model_head_top > 0.0:
		return _model_head_top * height_scale + BUBBLE_LIFT
	return HEAD_TOP_Y * height_scale + BUBBLE_LIFT


## Where a bubble points (world space).
func get_head_point() -> Vector3:
	return global_position + Vector3.UP * get_head_height()


## The loaded character model, or null when the capsule placeholder is standing in.
func get_model() -> Node3D:
	return _model


## The model's AnimationPlayer (null if it has none or there is no model).
func get_animation_player() -> AnimationPlayer:
	return _player


# ---- model ----

## Loads model_path under `root`, starts the idle clip and measures the head top. False = no model.
func _load_model(root: Node3D) -> bool:
	if model_path == "":
		return false
	var resolved_path: String = LookProfiles.resolve_model(model_path)
	var packed: PackedScene = load(resolved_path) as PackedScene
	if packed == null:
		push_warning("Npc %s: cannot load model %s, using the placeholder" % [speaker_id, model_path])
		return false
	_model = packed.instantiate() as Node3D
	if _model == null:
		return false
	root.scale = Vector3.ONE * height_scale
	root.add_child(_model)
	apply_light_compensation(_model, light_compensation)
	LookProfiles.dress_model(_model, resolved_path, "npc")
	_model_head_top = measure_head_top(root, _model)
	for node: Node in _model.find_children("*", "AnimationPlayer", true, false):
		_player = node as AnimationPlayer
		break
	if _player != null and _player.has_animation(idle_clip):
		_player.play(idle_clip)
		# Not everyone breathes in step.
		_player.seek(fposmod(_clock, 1.0) * _player.get_animation(idle_clip).length, true)
	return true


## Gives every mesh surface its own copy of the material with the tint multiplied by `tint_factor`
## (see light_compensation). Static so the crew and the map enemies share it.
static func apply_light_compensation(model: Node3D, tint_factor: Color) -> void:
	if tint_factor == Color.WHITE:
		return
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface: int in mesh_instance.mesh.get_surface_count():
			var source: ShaderMaterial = mesh_instance.mesh.surface_get_material(surface) as ShaderMaterial
			if source == null:
				continue
			var copy: ShaderMaterial = source.duplicate() as ShaderMaterial
			var tint: Variant = copy.get_shader_parameter("albedo_tint")
			var base: Color = tint if tint is Color else Color.WHITE
			copy.set_shader_parameter("albedo_tint", Color(base.r * tint_factor.r,
					base.g * tint_factor.g, base.b * tint_factor.b, base.a))
			mesh_instance.set_surface_override_material(surface, copy)


## Top of the model's body meshes (props excluded), in the Visual node's space at scale 1.
static func measure_head_top(root: Node3D, model: Node3D) -> float:
	var top: float = 0.0
	var to_visual: Transform3D = root.global_transform.affine_inverse()
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh == null or String(mesh_instance.name).contains(PROP_MARK):
			continue
		var box: AABB = to_visual * mesh_instance.global_transform * mesh_instance.get_aabb()
		top = maxf(top, box.end.y)
	return top


## Sizes the solid body from the exports. The scene's shape is shared by every instance, so each NPC
## gets its own.
func _fit_collision() -> void:
	var shape_node: CollisionShape3D = get_node_or_null(NODE_COLLISION) as CollisionShape3D
	if shape_node == null:
		return
	var cylinder: CylinderShape3D = CylinderShape3D.new()
	cylinder.radius = collision_radius
	cylinder.height = collision_height
	shape_node.shape = cylinder
	shape_node.position = Vector3(0.0, collision_height * 0.5, 0.0)


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
