class_name TraversalSpot
extends RoomProp
## A climb or hop spot. Red stands on it, faces the way across and presses the one button (the climb
## or hop icon); a short scripted move carries her from here to `end_offset` (local to this node)
## and hands control back. CLIMB goes straight up a wall and steps onto the ledge; HOP arcs over a
## low obstacle. Put one spot on each side of a hop. Timing and heights are in
## data/world/exploration.json ("traversal").
##
## Placeholder look: a flat amber pad on the floor where she should stand.

enum Mode { CLIMB, HOP }

signal started
signal finished

const LAND_LIFT: float = 0.02
const CLIP_CLIMB: StringName = &"walk"
const CLIP_HOP: StringName = &"jump"

@export var mode: Mode = Mode.CLIMB
## Where Red ends up, relative to this node (so the node's rotation turns it).
@export var end_offset: Vector3 = Vector3(0.0, 2.0, -1.2)

var _player: CharacterBody3D = null
var _active: bool = false
var _progress: float = 0.0
var _from: Vector3 = Vector3.ZERO
var _to: Vector3 = Vector3.ZERO


func _ready() -> void:
	var kind: Interactable.Kind = Interactable.Kind.CLIMB if mode == Mode.CLIMB else Interactable.Kind.HOP
	make_interactable(kind, tuning.traversal_reach, begin)
	if not has_custom_model():
		var pad: MeshInstance3D = PropLook.box(Vector3(tuning.traversal_pad.x, 0.03, tuning.traversal_pad.y),
				PropLook.glow(Color(1.0, 0.75, 0.25), 0.7), "Pad")
		pad.position.y = 0.02
		add_child(pad)


func _physics_process(delta: float) -> void:
	step(delta)


func is_active() -> bool:
	return _active


func get_duration() -> float:
	return tuning.climb_s if mode == Mode.CLIMB else tuning.hop_s


func get_landing_point() -> Vector3:
	return to_global(end_offset) + Vector3(0.0, LAND_LIFT, 0.0)


## Starts the move. Returns true when Red set off.
func begin(player: CharacterBody3D, _interactor: PlayerInteractor = null) -> bool:
	if _active or player == null:
		return false
	_player = player
	_from = player.global_position
	_to = get_landing_point()
	var across: Vector3 = _to - _from
	across.y = 0.0
	if across.length() > PlayerMotion.MIN_FLAT_LENGTH:
		player.rotation.y = PlayerMotion.yaw_for_direction(across.normalized())
	HeroLink.set_scripted(player, true, CLIP_CLIMB if mode == Mode.CLIMB else CLIP_HOP)
	_progress = 0.0
	_active = true
	set_usable(false)
	started.emit()
	return true


## One step of the move. Public so tests can drive it.
func step(delta: float) -> void:
	if not _active:
		return
	_progress = minf(_progress + delta / maxf(get_duration(), 0.01), 1.0)
	if _player == null or not is_instance_valid(_player):
		_active = false
		return
	_player.global_position = position_at(_progress)
	if _progress >= 1.0:
		_active = false
		_player.global_position = _to
		HeroLink.set_scripted(_player, false)
		set_usable(true)
		finished.emit()


## Where Red is `t` (0..1) of the way through the move.
func position_at(t: float) -> Vector3:
	if mode == Mode.HOP:
		var flat: Vector3 = _from.lerp(_to, t)
		flat.y += 4.0 * tuning.hop_height * t * (1.0 - t)
		return flat
	var hold: float = clampf(tuning.climb_forward_hold, 0.05, 0.95)
	if t < hold:
		var up: float = smoothstep(0.0, 1.0, t / hold)
		return Vector3(_from.x, lerpf(_from.y, _to.y, up), _from.z)
	var over: float = smoothstep(0.0, 1.0, (t - hold) / (1.0 - hold))
	return Vector3(lerpf(_from.x, _to.x, over), _to.y, lerpf(_from.z, _to.z, over))
