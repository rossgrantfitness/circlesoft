class_name Crate
extends RoomProp
## A crate Red opens with the one button (the "open" icon). The contents come from
## data/world/placements.json ("crates"), the open state is remembered by id through GameState.
## It is solid (layer 1) and Red can jump onto it. An opened crate stays, lid ajar, empty.
##
## style: supply (gray Hegemony stencil), chalk (a Coldrunner stash) or wood. Placeholder boxes.

signal opened

const STYLE_TINTS: Dictionary[String, Color] = {
	"supply": Color(0.55, 0.58, 0.62), "chalk": Color(0.78, 0.7, 0.55), "wood": Color(0.8, 0.5, 0.35),
}
const LID_HEIGHT: float = 0.12
const OPENED_TINT_MULT: float = 0.7

var _lid: Node3D = null
var _is_open: bool = false


func _ready() -> void:
	var data: Dictionary = crate_data()
	if data.is_empty():
		push_error("Crate %s: no crate '%s' in data/world/placements.json" % [name, placement_id])
	make_interactable(Interactable.Kind.OPEN, tuning.crate_reach, use)
	var hidden: bool = not Conditions.met(data.get("show_if", {}), game_state)
	if hidden:
		visible = false
		set_usable(false)
	if not has_custom_model():
		_build(str(data.get("style", "wood")))
	if hidden:
		_set_solid(false)
	if WorldProgress.is_opened(placement_id, game_state):
		_set_open_look()


func crate_data() -> Dictionary:
	return Placements.crate(placement_id)


func is_open() -> bool:
	return _is_open


## A crate with a "show_if" that was hidden when the room loaded appears now (the bell chest once the
## tune is rung): visible, usable and solid.
func reveal() -> void:
	if _is_open:
		return
	visible = true
	set_usable(true)
	_set_solid(true)


func _set_solid(on: bool) -> void:
	var body: StaticBody3D = get_node_or_null("Solid") as StaticBody3D
	if body != null:
		body.collision_layer = 1 if on else 0


## Opens the crate and hands out what is inside. Returns true when Red did something.
func use(_player: CharacterBody3D, interactor: PlayerInteractor) -> bool:
	if _is_open:
		return false
	var contents: Dictionary = crate_data()
	var result: Dictionary = WorldProgress.grant(contents, game_state)
	var found: Array[String] = []
	found.assign(result["lines"])
	if not bool(result["ok"]):
		# Nothing fit in the bag: the crate stays shut, Red just reads the message.
		say(found, interactor)
		return true
	var lines: Array[String] = []
	if found.is_empty():
		lines.append(Placements.text("crate_empty"))
	else:
		lines.append(Placements.text("crate_open") + "\n" + found[0])
		for i: int in range(1, found.size()):
			lines.append(found[i])
	say(lines, interactor)
	WorldProgress.mark_opened(placement_id, game_state)
	var audio: Node = get_node_or_null("/root/AudioManager")
	if audio != null and not found.is_empty():
		audio.call("play_sfx", &"item_get")
	_set_open_look()
	opened.emit()
	return true


func _set_open_look() -> void:
	_is_open = true
	set_usable(false)
	if _lid != null:
		_lid.rotation.x = deg_to_rad(-tuning.crate_lid_open_deg)


func _build(style: String) -> void:
	var size: Vector3 = tuning.crate_size
	var tint: Color = STYLE_TINTS.get(style, STYLE_TINTS["wood"])
	var body_size: Vector3 = Vector3(size.x, size.y - LID_HEIGHT, size.z)
	var body: MeshInstance3D = PropLook.box(body_size, PropLook.lit(tint), "Body")
	body.position.y = body_size.y * 0.5
	add_child(body)
	_lid = Node3D.new()
	_lid.name = "LidHinge"
	_lid.position = Vector3(0.0, body_size.y, -size.z * 0.5)
	var lid_mesh: MeshInstance3D = PropLook.box(Vector3(size.x + 0.04, LID_HEIGHT, size.z + 0.04),
			PropLook.lit(tint * OPENED_TINT_MULT), "Lid")
	lid_mesh.position = Vector3(0.0, LID_HEIGHT * 0.5, size.z * 0.5)
	_lid.add_child(lid_mesh)
	add_child(_lid)
	if style == "chalk":
		var mark: MeshInstance3D = PropLook.box(Vector3(0.22, 0.02, 0.22), PropLook.glow(Color(1.0, 1.0, 0.9), 0.8), "ChalkMark")
		mark.position = Vector3(0.0, size.y + 0.03, 0.0)
		add_child(mark)
	add_child(PropLook.solid_box(size, Vector3(0.0, size.y * 0.5, 0.0), "Solid"))
