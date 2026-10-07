class_name MapEnemy
extends CharacterBody3D
## An enemy walking around a room where Red can see it. It patrols its route, chases Red when she
## comes into view, and gives up (stands out of breath, then goes back to patrolling) when it has
## not seen her for a while. Touching Red starts the fight (`touched`); a FieldEncounters node in
## the room turns that into a battle. No random battles.
##
## States: PATROL walks the route (walk_speed, pausing at each point), CHASE runs at the last place
## it saw Red (chase_speed), GIVE_UP stands out of breath (rest_s) and then ignores Red a moment
## (reaggro_cooldown_s) before patrolling again. Red can outrun a chase by running (5.2 vs about 3.5).
## While Red blinks (just after a fight) or is frozen (talking, menu) it does not hunt her.
##
## Data: the node's `placement_id` keys data/world/placements.json (enemy type, encounter, kind,
## patrol offsets); the enemy type's speeds are its `field` block in data/battle/enemies.json and
## its look is that entry's placeholder model. Behavior numbers: data/world/map_enemies.json.
## kind "regular" comes back whenever the room is entered; "story" and "boss" stay beaten (a flag).
##
## Collision: layer 3 (value 4), collides with the world only, so it never blocks Red and walls stop it.

enum State { PATROL, CHASE, GIVE_UP }

signal touched(enemy: MapEnemy)
signal state_changed(new_state: State)

const GROUP: StringName = &"map_enemy"
const DATA_ID: String = "world/map_enemies"
const ENEMIES_ID: String = "battle/enemies"
const KIND_REGULAR: String = "regular"
const LAYER_ENEMY: int = 4
const MASK_WORLD: int = 1
const NODE_VISUAL: NodePath = ^"Visual"
const DEFEATED_PREFIX: String = "defeated_"
const ALERT_S: float = 0.25
const ALERT_POP: float = 0.25
const WINDED_LEAN_DEG: float = 18.0
const BOB_HEIGHT: float = 0.04
const BOB_HZ_WALK: float = 2.0
const BOB_HZ_CHASE: float = 3.4
const FLOOR_STICK: float = -0.1
const LIGHT_COMPENSATION: Color = Color(1.28, 1.1, 0.86)

@export var placement_id: String = ""
## Overrides the model from battle/enemies.json (a .glb or .tscn).
@export_file("*.glb", "*.tscn") var model_path: String = ""

## Red, set by the room. Without a target the enemy just stands.
var target: PlayerController = null
## False: it holds still (a room waiting in a battle, a cutscene).
var active: bool = true
## Moves itself every physics frame. Tests turn this off and call step().
var auto_step: bool = true

var enemy_id: String = ""
var encounter_id: String = ""
var kind: String = KIND_REGULAR
var defeat_flag: String = ""
var walk_speed: float = 0.0
var chase_speed: float = 0.0
var sight_m: float = 0.0
var give_up_s: float = 0.0

var _cfg: Dictionary = {}
var _state: State = State.PATROL
var _home: Vector3 = Vector3.ZERO
var _route: Array[Vector3] = []
var _next_point: int = 0
var _linger_left: float = 0.0
var _rest_left: float = 0.0
var _cooldown_left: float = 0.0
var _unseen_s: float = 0.0
var _last_seen_at: Vector3 = Vector3.ZERO
var _touch_sent: bool = false
var _stuck_s: float = 0.0
var _alert_left: float = 0.0
var _clock: float = 0.0
var _lift: float = 0.0
var _visual: Node3D = null
var _model: Node3D = null
var _gone: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = LAYER_ENEMY
	collision_mask = MASK_WORLD
	_cfg = DataDB.get_dict(DATA_ID)
	var placement: Dictionary = Placements.enemy(placement_id)
	if placement.is_empty():
		push_error("MapEnemy %s: no enemy '%s' in data/world/placements.json" % [name, placement_id])
	enemy_id = str(placement.get("enemy", ""))
	encounter_id = str(placement.get("encounter", ""))
	kind = str(placement.get("kind", KIND_REGULAR))
	defeat_flag = str(placement.get("defeat_flag", DEFEATED_PREFIX + placement_id))
	_home = global_position
	_route.clear()
	for offset: Variant in placement.get("patrol", []):
		var o: Array = offset
		_route.append(_home + Vector3(float(o[0]), float(o[1]), float(o[2])))
	var enemy_def: Dictionary = enemy_definition(enemy_id)
	var field: Dictionary = enemy_def.get("field", _cfg.get("default_field", {}))
	walk_speed = float(field.get("walk_speed", 2.0))
	chase_speed = float(field.get("chase_speed", 3.2))
	sight_m = float(field.get("sight_m", 6.0))
	give_up_s = float(field.get("give_up_s", 4.0))
	_visual = get_node_or_null(NODE_VISUAL) as Node3D
	var path: String = model_path if not model_path.is_empty() else str(enemy_def.get("model", ""))
	_load_model(path)
	_clock = float(placement_id.hash() % 1000) * 0.01


static func enemy_definition(wanted_enemy_id: String) -> Dictionary:
	for entry: Variant in DataDB.get_dict(ENEMIES_ID).get("enemies", []):
		if entry is Dictionary and str((entry as Dictionary).get("id", "")) == wanted_enemy_id:
			return entry
	return {}


func _physics_process(delta: float) -> void:
	if auto_step:
		step(delta)


func get_state() -> State:
	return _state


func get_home() -> Vector3:
	return _home


func get_route() -> Array[Vector3]:
	return _route.duplicate()


func get_facing() -> Vector3:
	return global_basis.z


## Stays beaten after a win (story fights and bosses); regular enemies come back with the room.
func is_persistent() -> bool:
	return kind != KIND_REGULAR


func is_defeated() -> bool:
	return _gone


## Takes the enemy out of the room (a win, or a story fight already won).
func defeat() -> void:
	_gone = true
	active = false
	remove_from_group(GROUP)
	collision_layer = 0
	visible = false
	set_physics_process(false)
	queue_free()


## The fight was run from: it stands there out of breath and leaves Red alone for a moment.
func on_battle_over() -> void:
	_touch_sent = false
	_enter(State.GIVE_UP)


## Lets it catch Red again (used when the room declined a touch).
func reset_touch() -> void:
	_touch_sent = false


## One step of behavior and movement. Public so tests can drive it.
func step(delta: float) -> void:
	_clock += delta
	_alert_left = maxf(_alert_left - delta, 0.0)
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	var moving: bool = false
	if active and target != null and is_instance_valid(target) and not target.frozen:
		moving = _think(delta)
	else:
		_halt(delta)
	_animate(moving)


# ---- behavior ----

func _think(delta: float) -> bool:
	var offset: Vector3 = _flat(target.global_position - global_position)
	var distance: float = offset.length()
	var catchable: bool = target.is_catchable()
	if catchable:
		_check_touch(distance, target.global_position.y - global_position.y)
	match _state:
		State.PATROL:
			if _cooldown_left <= 0.0 and catchable and _sees_target(distance, offset):
				_last_seen_at = target.global_position
				_enter(State.CHASE)
				return _chase(delta, distance)
			return _patrol(delta)
		State.CHASE:
			if not catchable:
				_enter(State.GIVE_UP)
				_halt(delta)
				return false
			return _chase(delta, distance)
		_:
			_rest_left -= delta
			_halt(delta)
			if _rest_left <= 0.0:
				_enter(State.PATROL)
			return false
	return false


func _chase(delta: float, distance: float) -> bool:
	var lose: float = sight_m * float(_cfg.get("lose_sight_mult", 1.4))
	if distance <= lose:
		_last_seen_at = target.global_position
		_unseen_s = 0.0
	else:
		_unseen_s += delta
		if _unseen_s >= give_up_s:
			_enter(State.GIVE_UP)
			_halt(delta)
			return false
	var moved: bool = _walk_toward(_last_seen_at, chase_speed, delta)
	if _blocked_for(delta, moved):
		_enter(State.GIVE_UP)
	return moved


func _patrol(delta: float) -> bool:
	if _linger_left > 0.0:
		_linger_left -= delta
		_halt(delta)
		return false
	var goal: Vector3 = _route[_next_point] if not _route.is_empty() else _home
	if _flat(goal - global_position).length() <= float(_cfg.get("waypoint_reach", 0.25)):
		if not _route.is_empty():
			_next_point = (_next_point + 1) % _route.size()
		_linger_left = float(_cfg.get("linger_s", 1.0))
		_halt(delta)
		return false
	var moved: bool = _walk_toward(goal, walk_speed, delta)
	if _blocked_for(delta, moved) and not _route.is_empty():
		_next_point = (_next_point + 1) % _route.size()
	return moved


func _enter(new_state: State) -> void:
	if new_state == _state:
		return
	_state = new_state
	match new_state:
		State.CHASE:
			_unseen_s = 0.0
			_stuck_s = 0.0
			_alert_left = ALERT_S
		State.GIVE_UP:
			_rest_left = float(_cfg.get("rest_s", 1.4))
			_cooldown_left = _rest_left + float(_cfg.get("reaggro_cooldown_s", 2.5))
		State.PATROL:
			_stuck_s = 0.0
			_linger_left = 0.0
	state_changed.emit(new_state)


func _check_touch(distance: float, height_diff: float) -> void:
	if _touch_sent:
		return
	if distance <= float(_cfg.get("touch_radius", 0.75)) and absf(height_diff) <= float(_cfg.get("touch_height", 1.2)):
		_touch_sent = true
		touched.emit(self)


## Whether the enemy notices Red from where it stands: within sight, in front of it (or very close),
## with nothing solid between.
func _sees_target(distance: float, offset: Vector3) -> bool:
	if distance > sight_m or absf(target.global_position.y - global_position.y) > 2.0:
		return false
	if distance > float(_cfg.get("close_notice_m", 1.6)):
		var half_cone: float = deg_to_rad(float(_cfg.get("sight_cone_deg", 130.0)) * 0.5)
		if _flat(get_facing()).normalized().dot(offset.normalized()) < cos(half_cone):
			return false
	return not _wall_between(target.global_position)


func _wall_between(point: Vector3) -> bool:
	if not is_inside_tree():
		return false
	var lift: Vector3 = Vector3.UP * float(_cfg.get("los_height", 0.5))
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(global_position + lift, point + lift, MASK_WORLD)
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


# ---- movement ----

func _walk_toward(goal: Vector3, speed: float, delta: float) -> bool:
	var offset: Vector3 = _flat(goal - global_position)
	if offset.length() <= 0.05:
		_halt(delta)
		return false
	var direction: Vector3 = offset.normalized()
	rotation.y = PlayerMotion.turn_toward(rotation.y, PlayerMotion.yaw_for_direction(direction),
			float(_cfg.get("turn_rate_deg_per_s", 400.0)), delta)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	_apply_gravity(delta)
	move_and_slide()
	return true


func _halt(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_apply_gravity(delta)
	move_and_slide()


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = FLOOR_STICK
	else:
		velocity.y -= float(_cfg.get("gravity", 24.0)) * delta


## True once it has been pushing against something for stuck_s.
func _blocked_for(delta: float, tried_to_move: bool) -> bool:
	if not tried_to_move:
		_stuck_s = 0.0
		return false
	if Vector2(velocity.x, velocity.z).length() < 0.2:
		_stuck_s += delta
	else:
		_stuck_s = 0.0
	if _stuck_s >= float(_cfg.get("stuck_s", 1.2)):
		_stuck_s = 0.0
		return true
	return false


# ---- look ----

func _animate(moving: bool) -> void:
	if _visual == null:
		return
	var hz: float = BOB_HZ_CHASE if _state == State.CHASE else BOB_HZ_WALK
	var bob: float = BOB_HEIGHT * absf(sin(_clock * hz * PI)) if moving else 0.0
	_visual.position.y = bob
	_visual.rotation.x = deg_to_rad(WINDED_LEAN_DEG) if _state == State.GIVE_UP else 0.0
	var pop: float = 1.0
	if _alert_left > 0.0:
		pop += ALERT_POP * sin(PI * (1.0 - _alert_left / ALERT_S))
	_visual.scale = Vector3.ONE * pop


func _load_model(path: String) -> void:
	if _visual == null or path.is_empty() or not ResourceLoader.exists(path):
		return
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		return
	_model = packed.instantiate() as Node3D
	if _model == null:
		return
	_visual.add_child(_model)
	Npc.apply_light_compensation(_model, LIGHT_COMPENSATION)
	for node: Node in _model.find_children("*", "AnimationPlayer", true, false):
		var clips: AnimationPlayer = node as AnimationPlayer
		if clips.has_animation(&"idle"):
			clips.play(&"idle")
		break
	_stand_on_the_floor()


## A model that sits below its origin is lifted onto the floor; one that hovers keeps its hover.
func _stand_on_the_floor() -> void:
	var low: float = INF
	var to_visual: Transform3D = _visual.global_transform.affine_inverse()
	for node: Node in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var box: AABB = to_visual * mesh_instance.global_transform * mesh_instance.get_aabb()
		low = minf(low, box.position.y)
	if low < 0.0 and low != INF:
		_lift = -low
		_model.position.y += _lift


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
