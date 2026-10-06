class_name FieldEnemy
extends Npc
## An enemy standing in a room, waiting to be challenged (placeholder: the enemy's blockout model,
## set with `model_path`). Red talks to it like anyone else; its conversation is a loud challenge that
## ends in a Fight? choice (data/world/room_fights.json says which conversations and which
## encounter). Everything else (turning to face Red, bobbing, the bubble head point) is an Npc's.

const HEAD_ROOM: float = 0.1

## Which entry of data/world/room_fights.json this is ("grunt", "drone", "squad", "tough").
@export var fight_id: String = ""

var _lift: float = 0.0


func _ready() -> void:
	var fight: Dictionary = RoomFights.fight(fight_id)
	if fight.is_empty():
		push_error("FieldEnemy %s: no fight '%s' in data/world/room_fights.json" % [name, fight_id])
	conversation = str(fight.get("challenge", ""))
	kind = Interactable.Kind.TALK
	super._ready()
	_stand_on_the_floor()


func get_fight_id() -> String:
	return fight_id


func get_encounter_id() -> String:
	return str(RoomFights.fight(fight_id).get("encounter", ""))


func get_head_height() -> float:
	return super.get_head_height() + _lift


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


## A model that sits below its origin is lifted onto the floor; one that hovers keeps its hover.
func _stand_on_the_floor() -> void:
	var model: Node3D = get_model()
	if model == null:
		return
	var low: float = INF
	var to_visual: Transform3D = model.get_parent().global_transform.affine_inverse()
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var box: AABB = to_visual * mesh_instance.global_transform * mesh_instance.get_aabb()
		low = minf(low, box.position.y)
	if low < 0.0 and low != INF:
		_lift = -low * height_scale
		model.position.y += -low
