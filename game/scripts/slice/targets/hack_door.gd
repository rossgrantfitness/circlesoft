class_name HackDoor
extends HackTarget
## A fuse box (docs/slice/slice_tech_plan.md 5.2). A Zap opens the door it feeds, and the door stays open (sticky).
## The door is one of two things, both optional:
##   * the usual `Door` between rooms: leave the fuse box alone and give that Door's placement `requires: {flag: <this flag>}`
##     (data "flag", e.g. hack_j1_door_open); the Door already reads flags, so it opens the moment the fuse box sets it;
##   * a slab that blocks the way: data "slab": {"size": [w, h, d], "offset": [x, y, z]} (local to the fuse box) is built here and
##     slides up when the fuse box is zapped; or data "door_path" names an existing node (relative to this one) to slide up
##     and switch off instead.
## Data keys: accepts (default ["zap"]), flag, slab, door_path, open_s (the slide, 1.2 s), also_flags (more flags to set).

const OPEN_S: float = 1.2
const COLLIDE_OFF_AT: float = 0.6

var open_s: float = OPEN_S
var slab: Node3D = null
var also_flags: Array[String] = []

var _blocker: Node3D = null
var _blocker_home: Vector3 = Vector3.ZERO
var _blocker_height: float = 3.0
var _open_t: float = 0.0
var _opening: bool = false
var _collision_off: bool = false
var _slab_cfg: Dictionary = {}
var _door_path: String = ""


func _init() -> void:
	accepts = PackedStringArray(["zap"])


func _configure(info: Dictionary) -> void:
	open_s = float(info.get("open_s", OPEN_S))
	also_flags = _strings(info.get("also_flags", []))
	_slab_cfg = info.get("slab", {}) as Dictionary
	_door_path = str(info.get("door_path", ""))


func _ready() -> void:
	configure()
	_find_blocker()
	super._ready()          # also puts an already-open door straight to open (_restore_done)
	set_process(_opening)


func _process(delta: float) -> void:
	tick(delta)


## The slide, in real time.
func tick(delta: float) -> void:
	if not _opening:
		return
	_open_t = minf(_open_t + delta / maxf(open_s, 0.01), 1.0)
	_place_blocker()
	if _open_t >= COLLIDE_OFF_AT:
		_switch_collision(false)
	if _open_t >= 1.0:
		_opening = false
		set_process(false)


func is_open() -> bool:
	return is_done()


## How far the blocker has slid, 0 shut to 1 fully open.
func open_amount() -> float:
	return _open_t


func has_blocker() -> bool:
	return _blocker != null


func _apply(_hack_id: StringName, _info: Dictionary) -> bool:
	for extra: String in also_flags:
		WorldProgress.set_flag(extra, game_state)
	return true


func _apply_done(done: bool) -> void:
	super._apply_done(done)
	if done:
		if _blocker != null and not _opening and _open_t < 1.0:
			_opening = true
			set_process(true)
	else:
		_opening = false
		_open_t = 0.0
		_place_blocker()
		_switch_collision(true)


func _restore_done() -> void:
	super._restore_done()
	_set_open_instantly()


func _find_blocker() -> void:
	if not _door_path.is_empty():
		_blocker = get_node_or_null(NodePath(_door_path)) as Node3D
	elif not _slab_cfg.is_empty():
		_blocker = _build_slab()
	if _blocker != null:
		_blocker_home = _blocker.position
		if not _slab_cfg.is_empty():
			_blocker_height = vec3(_slab_cfg.get("size", [3.0, 3.0, 0.4]), Vector3(3.0, 3.0, 0.4)).y
		else:
			_blocker_height = maxf(_bounds_of(_blocker).size.y, 1.0)
	slab = _blocker


func _build_slab() -> Node3D:
	var size: Vector3 = vec3(_slab_cfg.get("size", [3.0, 3.0, 0.4]), Vector3(3.0, 3.0, 0.4))
	var at: Vector3 = vec3(_slab_cfg.get("offset", [0.0, 0.0, 0.0]))
	var body: StaticBody3D = PropLook.solid_box(size, Vector3(0.0, size.y * 0.5, 0.0), "Slab")
	body.add_child(PropLook.box(size, PropLook.lit(Color(0.5, 0.42, 0.3)), "SlabMesh"))
	(body.get_node("SlabMesh") as Node3D).position.y = size.y * 0.5
	body.position = at
	add_child(body)
	return body


func _set_open_instantly() -> void:
	if _blocker == null:
		return
	_opening = false
	_open_t = 1.0
	_place_blocker()
	_switch_collision(false)


func _place_blocker() -> void:
	if _blocker == null:
		return
	_blocker.position = _blocker_home + Vector3.UP * (_blocker_height * _open_t)
	_blocker.visible = _open_t < 1.0


## Solid bodies in the blocker on or off (set_deferred: this can run inside a physics callback).
func _switch_collision(on: bool) -> void:
	if _blocker == null or _collision_off == (not on):
		return
	_collision_off = not on
	var shapes: Array[Node] = _blocker.find_children("*", "CollisionShape3D", true, false)
	if _blocker is CollisionShape3D:
		shapes.append(_blocker)
	for shape: Node in shapes:
		(shape as CollisionShape3D).set_deferred("disabled", not on)


static func _bounds_of(node: Node3D) -> AABB:
	var box: AABB = AABB()
	var first: bool = true
	for mesh: Node in node.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mesh as MeshInstance3D
		var part: AABB = m.get_aabb()
		part.position += m.position
		box = part if first else box.merge(part)
		first = false
	return box
