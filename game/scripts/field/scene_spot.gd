class_name SceneSpot
extends RoomProp
## A spot Red uses with the one button whose text or action depends on the story: a sign to
## examine, a slot to drop a form in, the dark window. Everything is in data/world/placements.json
## ("spots"): kind (examine / take / open), reach, show_if (a Conditions dictionary; not met = not
## usable), and `variants`, the first whose "if" holds is what happens: {conversation} reads text,
## {scene} runs a story scene (data/world/story_scenes.json). The node's position is where Red
## stands to use it. No look of its own: the room scene draws the sign, slot or window.

var data: Dictionary = {}


func _ready() -> void:
	data = Placements.spot(placement_id)
	if data.is_empty():
		push_error("SceneSpot %s: no spot '%s' in data/world/placements.json" % [name, placement_id])
	var kind_name: String = str(data.get("kind", "examine"))
	var kind: Interactable.Kind = Interactable.KIND_NAMES.find_key(kind_name) as Interactable.Kind
	make_interactable(kind, float(data.get("reach", 1.4)), use)
	set_usable(Conditions.met(data.get("show_if", {}), game_state))


func current_variant() -> Dictionary:
	return Conditions.pick(data.get("variants", []), game_state)


## Re-checks show_if (a flag may have changed since the room loaded).
func refresh() -> void:
	set_usable(Conditions.met(data.get("show_if", {}), game_state))


func use(_player: PlayerController, interactor: PlayerInteractor) -> bool:
	var variant: Dictionary = current_variant()
	if variant.is_empty():
		return false
	if variant.has("scene"):
		var room: FieldRoom = get_room()
		return room != null and room.story != null and room.story.run_scene(str(variant["scene"]))
	return interactor.start_conversation(str(variant.get("conversation", "")), interactable)
