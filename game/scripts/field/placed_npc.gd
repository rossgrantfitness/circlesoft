class_name PlacedNpc
extends Npc
## A townsperson whose look, lines and presence come from data/world/placements.json ("npcs"), so
## writing and story changes never touch a scene. The scene node only gives the position, the
## facing and the `placement_id`.
##
## Data keys: speaker (the dialogue speaker id; crowd townsfolk use "crowd_..." ids and get the plain
## box), look {body, head (hex colors), scale, extra ("welding_mask" / "wrap"), extra_color, model
## (a .glb to load by path instead of the capsule), radius, height, accessory {shape: sphere|box,
## color, size, pos}}, appear_if (a Conditions dictionary; not met = not in the room), hidden (starts
## out of the room until a scene shows them), reach, variants (the first whose "if" holds is what
## they say or do now: {if, conversation} plays a conversation, {if, scene} runs a story scene,
## optional move_to [x, z] stands them somewhere else).
## "Story beat" lines are just variants with {"if": {"beat": "b2_otis_joined"}, ...}.
##
## Placeholder look only: the capsule-and-sphere fallback in a tint, or an existing model.

const DEFAULT_REACH: float = 1.5

@export var placement_id: String = ""
## GameState to read conditions from. Null means the autoload.
var game_state: Node = null

var data: Dictionary = {}
var _present: bool = true
var _body_layer: int = 1
var _accessory: MeshInstance3D = null


func _ready() -> void:
	data = Placements.npc(placement_id)
	if data.is_empty():
		push_error("PlacedNpc %s: no npc '%s' in data/world/placements.json" % [name, placement_id])
	speaker_id = str(data.get("speaker", placement_id))
	var look: Dictionary = data.get("look", {})
	model_path = str(look.get("model", ""))
	if look.has("body"):
		body_color = Color.html(str(look["body"]))
	if look.has("head"):
		head_color = Color.html(str(look["head"]))
	height_scale = float(look.get("scale", 1.0))
	collision_radius = float(look.get("radius", 0.3))
	collision_height = float(look.get("height", 1.1))
	match str(look.get("extra", "none")):
		"welding_mask":
			extra = Extra.WELDING_MASK
		"wrap":
			extra = Extra.WRAP
	if look.has("extra_color"):
		extra_color = Color.html(str(look["extra_color"]))
	if not bool(look.get("compensation", true)):
		light_compensation = Color.WHITE
	kind = Interactable.Kind.TALK
	reach = float(data.get("reach", DEFAULT_REACH))
	super._ready()
	_body_layer = _body_collision_layer()
	if _interactable != null:
		_interactable.handler = _use
		_interactable.game_state = game_state
	_stand_on_the_floor()
	_build_accessory(look.get("accessory", {}))
	var moved: Dictionary = Conditions.pick(data.get("variants", []), game_state)
	if moved.has("move_to"):
		var spot: Array = moved["move_to"]
		global_position = Vector3(float(spot[0]), global_position.y, float(spot[1]))
	set_present(not bool(data.get("hidden", false)) and Conditions.met(data.get("appear_if", {}), game_state))


func is_present() -> bool:
	return _present


## In the room (visible, solid, can be talked to) or out of it. Out-of-room townsfolk stay known to
## the dialogue runner, so a scene can still bring them in.
func set_present(on: bool) -> void:
	_present = on
	visible = on
	if _interactable != null:
		_interactable.enabled = on
	var body: StaticBody3D = get_node_or_null("Body") as StaticBody3D
	if body != null:
		body.collision_layer = _body_layer if on else 0


## What they say or do now: the first variant whose condition holds.
func current_variant() -> Dictionary:
	return Conditions.pick(data.get("variants", []), game_state)


func _use(_player: CharacterBody3D, interactor: PlayerInteractor) -> bool:
	var variant: Dictionary = current_variant()
	if variant.is_empty():
		return false
	if variant.has("scene"):
		var room: FieldRoom = _find_room()
		return room != null and room.story != null and room.story.run_scene(str(variant["scene"]))
	var conversation_id: String = str(variant.get("conversation", ""))
	if conversation_id.is_empty():
		return false
	return interactor.start_conversation(conversation_id, _interactable)


func _find_room() -> FieldRoom:
	var node: Node = get_parent()
	while node != null and not node is FieldRoom:
		node = node.get_parent()
	return node as FieldRoom


func _body_collision_layer() -> int:
	var body: StaticBody3D = get_node_or_null("Body") as StaticBody3D
	return body.collision_layer if body != null else 1


func _build_accessory(spec: Dictionary) -> void:
	if spec.is_empty() or _visual == null:
		return
	var color: Color = Color.html(str(spec.get("color", "#cccccc")))
	var size: Array = spec.get("size", [0.3])
	if str(spec.get("shape", "sphere")) == "box":
		_accessory = _box_part(Vector3(float(size[0]), float(size[1]), float(size[2])), color)
	else:
		_accessory = _mesh_part(SphereMesh.new(), color)
		var sphere: SphereMesh = _accessory.mesh as SphereMesh
		sphere.radius = float(size[0])
		sphere.height = float(size[0]) * 2.0
		sphere.radial_segments = 8
		sphere.rings = 4
	_accessory.name = "Accessory"
	var at: Array = spec.get("pos", [0.0, 0.95, 0.0])
	_accessory.position = Vector3(float(at[0]), float(at[1]), float(at[2]))
	_visual.add_child(_accessory)


## A model that sits below its origin (the enemy blockouts) is lifted onto the floor.
func _stand_on_the_floor() -> void:
	var model: Node3D = get_model()
	if model == null or _visual == null:
		return
	var low: float = INF
	var to_visual: Transform3D = _visual.global_transform.affine_inverse()
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		low = minf(low, (to_visual * mesh_instance.global_transform * mesh_instance.get_aabb()).position.y)
	if low < 0.0 and low != INF:
		model.position.y += -low
