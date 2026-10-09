class_name CardGate
extends RoomProp
## A card gate that is not a door: the wire cage around the old power lever. Press the button next to
## it: with enough of Kasp's cards it slides open for good (the cards stay in the bag: they are counted,
## not used up); without, Red reads "SIGNALS ACCESS ONLY. Cards: X of N.". `placement_id` is the key in
## data/world/works.json "gates" ({need, locked, unlocked}). The node's +Z faces the side Red uses it from.
## Placeholder look: a bar slab with a red / green reader light. It is solid until it opens.

signal opened_gate

const OPEN_PREFIX: String = "gate_"
const SLAB: Vector3 = Vector3(1.0, 2.0, 0.2)
const SLIDE_UP: float = 2.1
const SLIDE_S: float = 0.5

var _slab: Node3D = null
var _solid: StaticBody3D = null
var _reader: MeshInstance3D = null
var _is_open: bool = false
var _slide_left: float = 0.0


func _ready() -> void:
	make_interactable(Interactable.Kind.OPEN, tuning.door_reach, use)
	_build()
	if WorldProgress.is_opened(OPEN_PREFIX + placement_id, game_state):
		_set_open(false)


func _process(delta: float) -> void:
	if _slide_left > 0.0 and _slab != null:
		_slide_left = maxf(_slide_left - delta, 0.0)
		_slab.position.y = SLAB.y * 0.5 + SLIDE_UP * (1.0 - _slide_left / SLIDE_S)


func gate_data() -> Dictionary:
	return WorksData.section("gates").get(placement_id, {})


func cards_needed() -> int:
	return int(gate_data().get("need", 1))


func is_open() -> bool:
	return _is_open


func locked_message() -> String:
	return WorksData.fill(str(gate_data().get("locked", "")), {"have": WorksData.cards_held(game_state), "need": cards_needed()})


## Red uses it. Returns true when she did something.
func use(_player: CharacterBody3D, interactor: PlayerInteractor) -> bool:
	if _is_open:
		return false
	if WorksData.cards_held(game_state) < cards_needed():
		say([locked_message()], interactor)
		return true
	WorldProgress.mark_opened(OPEN_PREFIX + placement_id, game_state)
	_set_open(true)
	var message: String = str(gate_data().get("unlocked", ""))
	if not message.is_empty():
		say([message], interactor)
	opened_gate.emit()
	return true


func _set_open(animate: bool) -> void:
	_is_open = true
	set_usable(false)
	if _solid != null:
		_solid.collision_layer = 0
	if _reader != null:
		_reader.material_override = PropLook.glow(Color(0.35, 1.0, 0.45), 1.6)
	if _slab != null:
		if animate:
			_slide_left = SLIDE_S
		else:
			_slab.position.y = SLAB.y * 0.5 + SLIDE_UP


func _build() -> void:
	_slab = PropLook.box(SLAB, PropLook.lit(Color(0.4, 0.45, 0.55)), "Bars")
	_slab.position.y = SLAB.y * 0.5
	add_child(_slab)
	_reader = PropLook.box(Vector3(0.12, 0.12, 0.06), PropLook.glow(Color(1.0, 0.25, 0.2), 1.6), "Reader")
	_reader.position = Vector3(0.0, 1.1, 0.15)
	add_child(_reader)
	_solid = PropLook.solid_box(SLAB, Vector3(0.0, SLAB.y * 0.5, 0.0), "Solid")
	add_child(_solid)
