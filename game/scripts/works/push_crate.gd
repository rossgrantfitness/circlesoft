class_name PushCrate
extends RoomProp
## The Cable Mill's gray supply crate. Stand on its far side and press the button: it slides one metre
## along its line (a grid push, no diagonals) until it reaches the stop (x, z) and snaps there against the
## ledge. Then Red can hop on top of it and climb up onto the ledge for the chalk stash. Once placed it
## stays (flag `t1_crate_placed`); if the room reloads before that it starts over at its first spot.
## Data: data/world/works.json "push_crate" keyed by `placement_id`.
## Placeholder look: a 0.9 m gray crate with the ring-and-bar stencil (a white square on top).

signal pushed(at: Vector3)
signal placed

const SIZE: Vector3 = Vector3(0.9, 0.9, 0.9)
const SLIDE_S: float = 0.3

var _body: StaticBody3D = null
var _visual: Node3D = null
var _climb: TraversalSpot = null
var _slide_left: float = 0.0
var _slide_from: float = 0.0
var _is_placed: bool = false


func _ready() -> void:
	make_interactable(Interactable.Kind.OPEN, float(cfg().get("reach", 1.3)), use)
	_build()
	if WorldProgress.has_flag(flag_id(), game_state):
		var stop: Array = cfg().get("stop", [position.x, position.z])
		position = Vector3(float(stop[0]), position.y, float(stop[1]))
		_set_placed(false)


func _process(delta: float) -> void:
	if _slide_left > 0.0 and _visual != null:
		_slide_left = maxf(_slide_left - delta, 0.0)
		var along: Vector3 = _slide_offset()
		_visual.position = along * (_slide_left / SLIDE_S)


func cfg() -> Dictionary:
	return WorksData.section("push_crate").get(placement_id, {})


func flag_id() -> String:
	return str(cfg().get("flag", "t1_crate_placed"))


func is_placed() -> bool:
	return _is_placed


func direction() -> Vector3:
	var dir: Array = cfg().get("dir", [-1, 0])
	return Vector3(float(dir[0]), 0.0, float(dir[1])).normalized()


func get_climb_spot() -> TraversalSpot:
	return _climb


## Whether Red stands on the pushing side, lined up with the crate.
func red_can_push_from(point: Vector3) -> bool:
	var behind: Vector3 = point - global_position
	behind.y = 0.0
	var dir: Vector3 = direction()
	var along: float = behind.dot(-dir)
	var across: float = absf(behind.dot(Vector3.UP.cross(dir)))
	return along > 0.2 and across <= float(cfg().get("align", 0.6))


func use(player: CharacterBody3D, interactor: PlayerInteractor) -> bool:
	if _is_placed:
		return false
	if player != null and not red_can_push_from(player.global_position):
		say([str(cfg().get("wrong_side", ""))], interactor)
		return true
	push_once()
	if interactor != null:
		say([str(cfg().get("placed" if _is_placed else "pushed", ""))], interactor)
	return true


## One grid hop toward the stop. Snaps and locks when it arrives. Returns false once it is placed.
func push_once() -> bool:
	if _is_placed:
		return false
	var stop: Array = cfg().get("stop", [position.x, position.z])
	var goal: Vector3 = Vector3(float(stop[0]), position.y, float(stop[1]))
	var left: Vector3 = goal - position
	left.y = 0.0
	var hop: float = minf(float(cfg().get("step", 1.0)), left.length())
	var before: Vector3 = position
	position += direction() * hop
	_slide_from = hop
	_slide_left = SLIDE_S
	if _visual != null:
		_visual.position = before - position
	pushed.emit(global_position)
	if Vector3(position.x - goal.x, 0.0, position.z - goal.z).length() <= 0.01:
		position = goal
		WorldProgress.set_flag(flag_id(), game_state)
		_set_placed(true)
	return true


func _slide_offset() -> Vector3:
	return -direction() * _slide_from


func _set_placed(announce: bool) -> void:
	_is_placed = true
	set_usable(false)
	if _climb != null:
		_climb.set_usable(true)
	if announce:
		placed.emit()


func _build() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	var body: MeshInstance3D = PropLook.box(SIZE, PropLook.lit(Color(0.55, 0.58, 0.62)), "Body")
	body.position.y = SIZE.y * 0.5
	_visual.add_child(body)
	var stencil: MeshInstance3D = PropLook.box(Vector3(0.3, 0.02, 0.3), PropLook.glow(Color(0.95, 0.95, 0.9), 0.7), "Stencil")
	stencil.position.y = SIZE.y + 0.02
	_visual.add_child(stencil)
	add_child(PropLook.solid_box(SIZE, Vector3(0.0, SIZE.y * 0.5, 0.0), "Solid"))
	_climb = TraversalSpot.new()
	_climb.name = "LedgeClimb"
	_climb.mode = TraversalSpot.Mode.CLIMB
	var end: Array = cfg().get("climb_end", [-1.2, 0.9, 0.0])
	_climb.end_offset = Vector3(float(end[0]), float(end[1]), float(end[2]))
	_climb.position = Vector3(0.0, SIZE.y, 0.0)
	add_child(_climb)
	_climb.set_usable(false)
