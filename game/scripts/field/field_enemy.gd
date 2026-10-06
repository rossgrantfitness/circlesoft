class_name FieldEnemy
extends Npc
## An enemy standing in a room, waiting to be challenged (placeholder: the enemy's blockout model).
## Red talks to it like anyone else; its conversation is a loud challenge that ends in a Fight?
## choice (data/world/room_fights.json says which conversations and which encounter). Same
## turning, bobbing and bubble head point as an Npc.

const IDLE_CLIP: StringName = &"idle"
const MODEL_LIFT_MARGIN: float = 0.0
const HEAD_ROOM: float = 0.15

## Which entry of data/world/room_fights.json this is ("grunt", "drone", "squad", "tough").
@export var fight_id: String = ""
## The enemy's placeholder model (a .glb with an idle clip).
@export_file("*.glb") var model_path: String = ""
@export var model_scale: float = 1.0

var _model_top: float = 1.5


func _ready() -> void:
	var fight: Dictionary = RoomFights.fight(fight_id)
	if fight.is_empty():
		push_error("FieldEnemy %s: no fight '%s' in data/world/room_fights.json" % [name, fight_id])
	conversation = str(fight.get("challenge", ""))
	kind = Interactable.Kind.TALK
	super._ready()


func get_fight_id() -> String:
	return fight_id


func get_encounter_id() -> String:
	return str(RoomFights.fight(fight_id).get("encounter", ""))


func get_head_height() -> float:
	return _model_top + HEAD_ROOM


## Takes the enemy out of the room for good (a win): no longer usable, hidden, freed.
func defeat() -> void:
	var spot: Interactable = get_interactable()
	if spot != null:
		spot.enabled = false
		spot.remove_from_group(Interactable.GROUP)
	remove_from_group(Npc.GROUP)
	visible = false
	var body: StaticBody3D = get_node_or_null("Body") as StaticBody3D
	if body != null:
		body.collision_layer = 0
	queue_free()


## The enemy's model instead of the capsule look. Stands on the floor (a model that sits below its
## origin is lifted); one that hovers keeps its hover.
func _build_look(root: Node3D) -> void:
	var packed: PackedScene = load(model_path) as PackedScene if ResourceLoader.exists(model_path) else null
	if packed == null:
		push_warning("FieldEnemy %s: model '%s' not found; using the capsule look" % [name, model_path])
		super._build_look(root)
		return
	var model: Node3D = packed.instantiate() as Node3D
	model.name = "Model"
	model.scale = Vector3.ONE * model_scale
	root.add_child(model)
	var low: float = INF
	var high: float = -INF
	for mesh_instance: Node in model.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = (mesh_instance as MeshInstance3D).get_aabb()
		var transform_to_model: Transform3D = model.global_transform.affine_inverse() * (mesh_instance as Node3D).global_transform if model.is_inside_tree() else (mesh_instance as Node3D).transform
		var moved: AABB = transform_to_model * box
		low = minf(low, moved.position.y)
		high = maxf(high, moved.end.y)
	if low == INF:
		low = 0.0
		high = 1.5
	if low < 0.0:
		model.position.y = -low * model_scale + MODEL_LIFT_MARGIN
	_model_top = (high * model_scale) + model.position.y
	var animations: AnimationPlayer = _find_animation_player(model)
	if animations != null and animations.has_animation(IDLE_CLIP):
		animations.play(IDLE_CLIP)


func _find_animation_player(root: Node) -> AnimationPlayer:
	for node: Node in root.find_children("*", "AnimationPlayer", true, false):
		return node as AnimationPlayer
	return null
