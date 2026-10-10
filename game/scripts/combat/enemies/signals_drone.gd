class_name SignalsDrone
extends ActionEnemy
## The flying Signals drone (docs/slice/enemy_roster.md, enemies.json `signals_drone`, moves.json set `signals_drone`).
## An ActionEnemy that floats: it hovers `flying.hover_height_m` above the floor (centre of its body) with a small bob, rears
## up while it winds up, drops to Red's height for the dive, then sinks low (`low_height_m`, sword height) for the 1.1 s of
## recovery. EMP or a broken poise drops it to the floor (`falls_when_stunned`). Everything else (notice, circle, tokens,
## hijack, hit reactions) is ActionEnemy's. Tags `drone` and `flying` make Zap do double and EMP stun it for 3 s.
## Overclock makes it a 10 s ally that dives at enemies.

const DIVE_HEIGHT_M: float = 0.55
const LOW_HEIGHT_M: float = 0.6
const RISE_M: float = 0.3
const ALTITUDE_GAIN: float = 12.0
const MAX_CLIMB_MPS: float = 12.0

var _fly: Dictionary = {}
var _bob_time: float = 0.0
var _ground_y: float = 0.0


func _ready() -> void:
	super._ready()
	_fly = data.get("flying", {}) as Dictionary
	_ground_y = global_position.y


## It flies: only a launched drone counts as "in the air" for juggles.
func is_airborne() -> bool:
	return body_state == ST_LAUNCHED


## How high the middle of its body wants to be above the floor right now.
func wanted_height_m() -> float:
	var hover: float = float(_fly.get("hover_height_m", 1.7))
	match body_state:
		ST_STAGGER:
			if bool(_fly.get("falls_when_stunned", true)):
				return height_m * 0.5
		ST_DOWN, ST_GETUP, ST_LAUNCHED, ST_DEAD:
			return height_m * 0.5
	var bob: float = sin(_bob_time * TAU * float(_fly.get("bob_hz", 0.8))) * float(_fly.get("bob_m", 0.12))
	if runner != null and runner.is_busy() and body_state == ST_FREE and runner.current_move() == &"dive":
		match runner.phase():
			MoveRunner.PHASE_STARTUP:
				var startup: float = maxf(float(runner.data().get("startup_ms", 1.0)), 1.0)
				return hover + RISE_M * clampf(runner.elapsed_ms() / startup * 1.6, 0.0, 1.0) + bob     # rears up
			MoveRunner.PHASE_ACTIVE:
				return DIVE_HEIGHT_M
			_:
				return LOW_HEIGHT_M                # sits low and slow: free hits
	return hover + bob


func _apply_gravity(dt: float) -> void:
	if body_state == ST_LAUNCHED or body_state == ST_DEAD or body_state == ST_DOWN or body_state == ST_GETUP:
		super._apply_gravity(dt)
		return
	_bob_time += dt
	_ground_y = _floor_height()
	var origin_y: float = _ground_y + maxf(wanted_height_m() - height_m * 0.5, 0.0)
	velocity.y = clampf((origin_y - global_position.y) * ALTITUDE_GAIN, -MAX_CLIMB_MPS, MAX_CLIMB_MPS)


## The floor under the drone (a downward ray on the world layer), else where it last found one.
func _floor_height() -> float:
	if not is_inside_tree():
		return _ground_y
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space == null:
		return _ground_y
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.5,
			global_position + Vector3.DOWN * 40.0, CombatLayers.bit(CombatLayers.WORLD))
	query.collide_with_areas = false
	var found: Dictionary = space.intersect_ray(query)
	return float((found["position"] as Vector3).y) if not found.is_empty() else _ground_y
