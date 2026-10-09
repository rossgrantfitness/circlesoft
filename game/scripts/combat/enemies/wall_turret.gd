class_name WallTurret
extends ActionEnemy
## The wall turret (docs/slice/enemy_roster.md, enemies.json `wall_turret`, moves.json set `wall_turret`): bolted to a ledge,
## it never moves. It turns slowly (60 degrees a second inside `mount.yaw_range_deg` of the way it was built facing) and
## tilts to Red's height, shows a thin red laser from the first frame of its burst, locks the aim `track_ms` in (350 ms
## before the first bolt) and then fires three bolts down that one line. One step sideways beats all three.
## Tags `turret` and `static`: two Zaps break its poise (2.5 s stun), EMP switches it off for 4 s, Overclock makes it fire
## `burst_ally` (a shorter wind-up, about every 1.4 s) at the nearest enemy for 10 s (in the boss arena at the relays first).

const LASER_LENGTH_M: float = 28.0
const LASER_THIN_M: float = 0.025

var _mount: Dictionary = {}
var _laser: MeshInstance3D = null
var _laser_material: StandardMaterial3D = null


func _ready() -> void:
	super._ready()
	_mount = data.get("mount", {}) as Dictionary
	_build_laser()


func tick(delta: float) -> void:
	super.tick(delta)
	_keep_to_mount(delta)
	_update_laser()


# ---- it never moves ----

func _apply_gravity(_dt: float) -> void:
	velocity = Vector3.ZERO


## Hits shake it but never shove it off its mount.
func _on_hit_reaction(result: Dictionary) -> void:
	super._on_hit_reaction(result)
	_knock = Vector3.ZERO
	velocity = Vector3.ZERO


## Overclock: the same bolts, fired the short way.
func _start_attack(move_id: StringName, intent: Dictionary, view: Dictionary, tokens: AttackTokens) -> void:
	var swap: StringName = StringName(str((data.get("hijack", {}) as Dictionary).get("attack_move", "")))
	if hijacked_by != null and swap != &"" and move_id != swap:
		move_id = swap
	super._start_attack(move_id, intent, view, tokens)


## Keeps the yaw inside the mount's arc and tilts the barrel to the target while the aim is still tracking.
func _keep_to_mount(delta: float) -> void:
	var half: float = deg_to_rad(float(_mount.get("yaw_range_deg", 160.0)) * 0.5)
	var offset: float = wrapf(rotation.y - spawn_yaw, -PI, PI)
	rotation.y = spawn_yaw + clampf(offset, -half, half)
	if body_state == ST_DEAD or body_state != ST_FREE:
		return
	var tracking: bool = runner == null or not runner.is_busy() or bool(last_intent.get("face_player", false))
	if not tracking:
		return                      # locked: the pitch stays where it was when the aim locked
	var target: CombatActor = _target()
	if target == null:
		return
	var muzzle: Vector3 = global_position + Vector3.UP * 0.2
	var aim: Vector3 = target.anchor(&"center") - muzzle
	var flat: float = Vector2(aim.x, aim.z).length()
	var pitch_range: Array = _mount.get("pitch_range_deg", [-55, 20]) as Array
	var wanted: float = -atan2(aim.y, maxf(flat, 0.01))
	var low: float = deg_to_rad(-float(pitch_range[1]))          # looking up is a negative x rotation
	var high: float = deg_to_rad(-float(pitch_range[0]))
	wanted = clampf(wanted, minf(low, high), maxf(low, high))
	var step: float = deg_to_rad(float(data.get("turn_rate_deg_per_s", 60.0))) * delta
	rotation.x = rotate_toward(rotation.x, wanted, step)


# ---- the laser ----

func _build_laser() -> void:
	_laser = MeshInstance3D.new()
	_laser.name = "Laser"
	var beam: BoxMesh = BoxMesh.new()
	beam.size = Vector3(LASER_THIN_M, LASER_THIN_M, LASER_LENGTH_M)
	_laser.mesh = beam
	_laser.position = Vector3(0.0, 0.2, LASER_LENGTH_M * 0.5)
	_laser_material = StandardMaterial3D.new()
	_laser_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_laser_material.emission_enabled = true
	_laser_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_laser.material_override = _laser_material
	_laser.visible = false
	_laser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_laser)


## True while the thin red line should show: the whole of a burst, from its first frame, until the last bolt.
func laser_visible() -> bool:
	return _laser != null and _laser.visible


## True once the aim has locked for this burst (the line goes bright and stops moving).
func aim_locked() -> bool:
	return runner != null and runner.is_busy() and body_state == ST_FREE and not bool(last_intent.get("face_player", true))


func _update_laser() -> void:
	if _laser == null:
		return
	var show: bool = false
	if runner != null and runner.is_busy() and body_state == ST_FREE and hijacked_by == null \
			and str(runner.current_move()) == "burst":
		var end_ms: float = float(runner.data().get("startup_ms", 0.0)) + float(runner.data().get("active_ms", 0.0))
		show = runner.elapsed_ms() < end_ms
	_laser.visible = show
	if not show:
		return
	var locked: bool = aim_locked()
	var colour: Color = Color(1.0, 0.22, 0.15)
	_laser_material.albedo_color = Color(colour.r, colour.g, colour.b, 1.0 if locked else 0.45)
	_laser_material.emission = colour
	_laser_material.emission_energy_multiplier = 3.0 if locked else 1.0
