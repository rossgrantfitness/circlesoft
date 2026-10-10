class_name OrbitCamera
extends Node3D
## The sandbox camera (docs/pivot/combat_api.md 4.8). This node is the pivot; the Camera3D hangs off
## it on an "arm" whose length is shortened when the world is in the way.
##
##   ORBIT     the right stick or the mouse turns it; it eases back behind Red when she runs and the
##             look input is idle; with a lock target it frames Red and the target together.
##   DIORAMA   Ross's option C: the high camera that follows Red and never rotates. Movement stays
##             camera-relative, and lock-on still drives the reticle and attack magnetism.
##
## The switch (camera_toggle) blends smoothly. Numbers come from data/combat/camera.json; the knobs
## `cam_distance_m` and `cam_sensitivity` (feel panel) win over the file while `knobs` is set.
## `shake()` moves only the Camera3D, never the pivot, so aim and lock framing don't drift; it decays
## in real time. Nodes in the PSX SubViewport get no input events, so the mouse arrives through
## add_mouse_motion() (the sandbox's input relay calls it) and the stick is polled.
## All per-frame work is in tick(delta); _physics_process only calls it.

enum Mode { ORBIT, DIORAMA }

signal mode_changed(mode: Mode)

const DATA_ID: String = "combat/camera"
const ACTION_TOGGLE: StringName = &"camera_toggle"
const ACTION_LEFT: StringName = &"camera_left"
const ACTION_RIGHT: StringName = &"camera_right"
const ACTION_UP: StringName = &"camera_up"
const ACTION_DOWN: StringName = &"camera_down"
const KNOB_DISTANCE: String = "cam_distance_m"
const KNOB_SENSITIVITY: String = "cam_sensitivity"
const CAMERA_NAME: String = "Camera3D"
const STICK_IDLE: float = 0.05

## Poll the stick and the camera_toggle action in tick() (the game). Tests turn this off.
@export var read_engine_input: bool = true
## FeelKnobs (or null for the numbers in camera.json). Read every frame, so the panel works live.
var knobs: FeelKnobs = null

var _camera: Camera3D = null
var _target: Node3D = null
var _lock: LockOn = null
var _mode: Mode = Mode.ORBIT
var _orbit: Dictionary = {}
var _lock_cfg: Dictionary = {}
var _dio: Dictionary = {}
var _shake_profiles: Dictionary = {}

# What the player has asked the orbit camera to be.
var _yaw: float = 0.0
var _pitch: float = 0.0
# What is on screen (smoothed toward the above, or toward the diorama numbers).
var _view_yaw: float = 0.0
var _view_pitch: float = -0.3
var _view_distance: float = 4.5
var _view_fov: float = 62.0
var _focus: Vector3 = Vector3.ZERO
var _blend_left_s: float = 0.0
var _arm_length: float = 4.5

var _look_stick: Vector2 = Vector2.ZERO
var _mouse_accum: Vector2 = Vector2.ZERO
var _idle_look_s: float = 0.0
var _flick_armed: bool = true
var _flick_cooldown_s: float = 0.0
var _last_target_pos: Vector3 = Vector3.ZERO
var _travel: Vector3 = Vector3.ZERO

# Shake: a decaying smooth wobble on the camera only. Several shakes add up (largest amplitude wins the decay clock).
var _shake_amp: float = 0.0
var _shake_total_s: float = 0.0
var _shake_left_s: float = 0.0
var _shake_hz: float = 24.0
var _shake_time: float = 0.0

# Scale view (CS-21, the giant-robot scale test): a body size's camera numbers, blended in over a second or so.
# Distances are multiples of the numbers in camera.json / the feel panel, so Ross's own camera distance still counts.
var _sv_on: bool = false
var _sv_from: Dictionary = {}
var _sv_to: Dictionary = {}
var _sv_cur: Dictionary = {}
var _sv_t: float = 1.0
var _sv_len: float = 0.0


func _ready() -> void:
	top_level = true
	reload_data()
	_camera = get_node_or_null(CAMERA_NAME) as Camera3D
	if _camera == null:
		_camera = Camera3D.new()
		_camera.name = CAMERA_NAME
		add_child(_camera)
	_camera.fov = _view_fov
	_camera.near = _f(_orbit, "near", 0.1)
	_camera.far = _f(_orbit, "far", 120.0)
	_camera.current = true
	if _target != null:
		snap()


func reload_data() -> void:
	var db: Node = get_node_or_null("/root/DataDB")
	var doc: Dictionary = (db.call("get_dict", DATA_ID) as Dictionary) if db != null else {}
	_orbit = doc.get("orbit", {}) as Dictionary
	_lock_cfg = doc.get("lock", {}) as Dictionary
	_dio = doc.get("diorama", {}) as Dictionary
	_shake_profiles = doc.get("shake_fallback", {}) as Dictionary
	_pitch = deg_to_rad(_f(_orbit, "start_pitch_deg", -14.0))
	_view_pitch = _pitch
	_view_distance = _orbit_distance()
	_view_fov = _f(_orbit, "fov_deg", 62.0)


func _physics_process(delta: float) -> void:
	tick(delta)


# ---- the contract API ----

func follow(target: Node3D) -> void:
	_target = target
	if _lock != null:
		_lock.origin_node = target
	if target != null:
		_last_target_pos = target.global_position
		if is_inside_tree() and _camera != null:
			snap()


func set_lock_on(lock: LockOn) -> void:
	if _lock != null and is_instance_valid(_lock) and _lock.recenter_requested.is_connected(recenter):
		_lock.recenter_requested.disconnect(recenter)
	_lock = lock
	if _lock != null:
		_lock.camera_node = self
		_lock.origin_node = _target
		if not _lock.recenter_requested.is_connected(recenter):
			_lock.recenter_requested.connect(recenter)


func toggle_mode() -> Mode:
	return set_mode(Mode.DIORAMA if _mode == Mode.ORBIT else Mode.ORBIT)


func set_mode(mode: Mode) -> Mode:
	if mode == _mode:
		return _mode
	_mode = mode
	_blend_left_s = _f(_dio, "blend_s", 0.5)
	mode_changed.emit(_mode)
	return _mode


func get_mode() -> Mode:
	return _mode


func get_camera() -> Camera3D:
	return _camera


## Swing the orbit camera back behind Red (the way she faces).
func recenter() -> void:
	if _target == null:
		return
	var facing: Vector3 = _target.global_basis.z
	_yaw = atan2(-facing.x, -facing.z)
	_idle_look_s = 0.0


## A decaying smooth shake. `profile` is an id in fx.json's shake block when the fx data is there,
## else in camera.json "shake_fallback". Several shakes in a row take the larger.
## `scaled`: the current scale view's shake_mult applies too (hits do; the robot footsteps pass false and bring their own
## suggested_mult). The scale view's shake_cap_m caps the final amplitude: a far camera needs more than 0.25 m to feel a step.
func shake(profile: StringName, mult: float = 1.0, scaled: bool = true) -> void:
	var cfg: Dictionary = _shake_profile(profile)
	var scale: float = mult * _knob("shake_scale", 1.0)
	if scaled:
		scale *= _view_f("shake_mult", 1.0)
	var amp: float = minf(_f(cfg, "amplitude_m", 0.05) * scale, _view_f("shake_cap_m", INF))
	var seconds: float = _f(cfg, "duration_s", 0.15)
	if amp <= 0.0 or seconds <= 0.0:
		return
	var current: float = _shake_amplitude_now()
	if amp >= current:
		_shake_amp = amp
		_shake_total_s = seconds
		_shake_left_s = seconds
		_shake_hz = _f(cfg, "frequency_hz", 24.0)


# ---- the scale view (CS-21) ----

## Moves the camera to a body size's look: {distance_mult, pivot_mult, fov_mult, min_distance_m, pitch_offset_deg,
## yaw_offset_deg, near_m, far_m, shake_mult, shake_cap_m} (ScaleProfile.camera_view builds it). `blend_s` > 0 eases there over that many seconds
## (smooth in-out, from whatever is on screen now); 0 jumps.
func set_scale_view(view: Dictionary, blend_s: float = 0.0) -> void:
	var from_view: Dictionary = get_scale_view()
	_sv_on = true
	_sv_to = _filled_view(view)
	if blend_s <= 0.0:
		_sv_from = _sv_to
		_sv_t = 1.0
		_sv_len = 0.0
	else:
		_sv_from = from_view
		_sv_t = 0.0
		_sv_len = blend_s
	_sv_cur = ScaleProfile.blend(_sv_from, _sv_to, ScaleProfile.smooth(_sv_t))


## The view on screen right now (the neutral one, camera.json as is, when no scale view was ever set).
func get_scale_view() -> Dictionary:
	if not _sv_on:
		return _neutral_view()
	return _sv_cur.duplicate()


func has_scale_view() -> bool:
	return _sv_on


## True while a scale view is still easing in.
func is_scale_view_blending() -> bool:
	return _sv_on and _sv_t < 1.0


## 0 to 1: how far the scale view has eased (1 when still or never set).
func scale_view_progress() -> float:
	return _sv_t if _sv_on else 1.0


func _neutral_view() -> Dictionary:
	return {
		"distance_mult": 1.0, "pivot_mult": 1.0, "fov_mult": 1.0,
		"min_distance_m": _f(_orbit, "min_distance_m", 0.8), "pitch_offset_deg": 0.0, "yaw_offset_deg": 0.0,
		"near_m": _f(_orbit, "near", 0.1), "far_m": _f(_orbit, "far", 120.0),
		"shake_mult": 1.0, "shake_cap_m": 1.0e6,
	}


func _filled_view(view: Dictionary) -> Dictionary:
	var out: Dictionary = _neutral_view()
	for key: Variant in view.keys():
		out[key] = float(view[key])
	return out


func _advance_scale_view(delta: float) -> void:
	if not _sv_on or _sv_t >= 1.0:
		return
	_sv_t = 1.0 if _sv_len <= 0.0 else minf(_sv_t + delta / _sv_len, 1.0)
	_sv_cur = ScaleProfile.blend(_sv_from, _sv_to, ScaleProfile.smooth(_sv_t))


func _view_f(key: String, fallback: float) -> float:
	return float(_sv_cur.get(key, fallback)) if _sv_on else fallback


# ---- inputs from outside ----

## Look stick (x right, y down), as from Input.get_vector. Tests call this; the game polls it.
func set_look_stick(stick: Vector2) -> void:
	_look_stick = stick


## Mouse movement in pixels (the sandbox input relay forwards it while the mouse is captured).
func add_mouse_motion(relative: Vector2) -> void:
	_mouse_accum += relative


func get_yaw() -> float:
	return _yaw


func get_pitch() -> float:
	return _pitch


func set_orbit_angles(yaw: float, pitch: float) -> void:
	_yaw = yaw
	_pitch = clampf(pitch, deg_to_rad(_f(_orbit, "pitch_min_deg", -60.0)), deg_to_rad(_f(_orbit, "pitch_max_deg", 25.0)))


## The yaw on screen right now (radians), so the player can move relative to what Ross sees.
func get_view_yaw() -> float:
	return _view_yaw


func get_focus() -> Vector3:
	return _focus


## Where the shaken camera sits relative to its unshaken spot (zero when still).
func get_shake_offset() -> Vector3:
	return _camera.position - Vector3(0.0, 0.0, _arm_length) if _camera != null else Vector3.ZERO


## True while a shake is still running.
func is_shaking() -> bool:
	return _shake_left_s > 0.0



# ---- the per-frame step ----

func tick(delta: float) -> void:
	if _camera == null:
		return
	if read_engine_input:
		if Input.is_action_just_pressed(ACTION_TOGGLE):
			toggle_mode()
		_look_stick = Input.get_vector(ACTION_LEFT, ACTION_RIGHT, ACTION_UP, ACTION_DOWN)
	_track_travel(delta)
	_advance_scale_view(delta)
	_blend_left_s = maxf(_blend_left_s - delta, 0.0)
	_flick_cooldown_s = maxf(_flick_cooldown_s - delta, 0.0)
	var locked: Node3D = _lock.get_target() if _lock != null else null
	_apply_look_input(delta, locked)
	_update_view(delta, locked)
	_place_camera(delta)
	_mouse_accum = Vector2.ZERO


# ---- orbit input ----

func _apply_look_input(delta: float, locked: Node3D) -> void:
	var sensitivity: float = _knob(KNOB_SENSITIVITY, 1.0)
	var stick: Vector2 = _look_stick
	var mouse: Vector2 = _mouse_accum
	var any_look: bool = stick.length() > STICK_IDLE or mouse.length() > 0.5
	if locked != null:
		# Locked: the look input picks targets instead of turning the camera.
		_flick_targets(stick, mouse)
		_idle_look_s = 0.0
		return
	_flick_armed = true
	if _mode != Mode.ORBIT:
		return
	var curve: float = _f(_orbit, "stick_curve", 1.6)
	var stick_rate: float = _f(_orbit, "stick_deg_per_s", 190.0)
	var shaped: Vector2 = stick.normalized() * pow(stick.length(), curve) if stick.length() > STICK_IDLE else Vector2.ZERO
	var inv_x: float = -1.0 if bool(_orbit.get("invert_x", false)) else 1.0
	var inv_y: float = -1.0 if bool(_orbit.get("invert_y", false)) else 1.0
	var mouse_deg: float = _f(_orbit, "mouse_deg_per_px", 0.1)
	var yaw_deg: float = (-shaped.x * stick_rate * delta - mouse.x * mouse_deg) * sensitivity * inv_x
	var pitch_deg: float = (-shaped.y * stick_rate * delta - mouse.y * mouse_deg) * sensitivity * inv_y
	_yaw += deg_to_rad(yaw_deg)
	_pitch = clampf(_pitch + deg_to_rad(pitch_deg), deg_to_rad(_f(_orbit, "pitch_min_deg", -60.0)),
			deg_to_rad(_f(_orbit, "pitch_max_deg", 25.0)))
	if any_look:
		_idle_look_s = 0.0
	else:
		_idle_look_s += delta
		if _idle_look_s >= _f(_orbit, "recenter_delay_s", 1.4) and _travel.length() >= _f(_orbit, "recenter_min_speed_mps", 1.5):
			_yaw += LockOnMath.recenter_step(_yaw, _travel, _f(_orbit, "recenter_deg_per_s", 95.0), delta,
					_f(_orbit, "recenter_dead_deg", 35.0))


func _flick_targets(stick: Vector2, mouse: Vector2) -> void:
	if _lock == null or _flick_cooldown_s > 0.0:
		return
	var threshold: float = _f(_lock_cfg, "flick_threshold", 0.65)
	var flick: Vector2 = Vector2.ZERO
	if stick.length() >= threshold and _flick_armed:
		flick = stick
		_flick_armed = false
	elif stick.length() < threshold * 0.5:
		_flick_armed = true
	if mouse.length() >= _f(_lock_cfg, "mouse_flick_px", 45.0):
		flick = mouse
	if flick != Vector2.ZERO:
		_lock.switch(flick)
		_flick_cooldown_s = _f(_lock_cfg, "flick_cooldown_s", 0.3)


func _track_travel(delta: float) -> void:
	if _target == null or delta <= 0.0:
		return
	var pos: Vector3 = _target.global_position
	var velocity: Vector3 = (pos - _last_target_pos) / delta
	_last_target_pos = pos
	_travel = _travel.lerp(Vector3(velocity.x, 0.0, velocity.z), clampf(delta * 10.0, 0.0, 1.0))


# ---- the view ----

func _update_view(delta: float, locked: Node3D) -> void:
	var want_yaw: float = _yaw + deg_to_rad(_view_f("yaw_offset_deg", 0.0))
	var want_pitch: float = _pitch + deg_to_rad(_view_f("pitch_offset_deg", 0.0))
	var want_distance: float = _orbit_distance()
	var want_fov: float = _f(_orbit, "fov_deg", 62.0) * _view_f("fov_mult", 1.0)
	var feet: Vector3 = _target.global_position if _target != null else _focus
	var height: float = _f(_orbit, "pivot_height_m", 1.1) * _view_f("pivot_mult", 1.0)
	var want_focus: Vector3 = feet + Vector3.UP * height
	var lag: float = _f(_orbit, "follow_lag_s", 0.07)
	var rate: float = _f(_orbit, "look_rate", 45.0)
	if _mode == Mode.DIORAMA:
		want_yaw = deg_to_rad(_f(_dio, "yaw_deg", 0.0))
		want_pitch = deg_to_rad(_f(_dio, "pitch_deg", -42.0))
		want_distance = _f(_dio, "distance_m", 10.5) * _view_f("distance_mult", 1.0)
		want_fov = _f(_dio, "fov_deg", 32.0) * _view_f("fov_mult", 1.0)
		want_focus = feet + Vector3.UP * _f(_dio, "pivot_height_m", 0.5) * _view_f("pivot_mult", 1.0)
		lag = _f(_dio, "lag_s", 0.25)
		rate = 1.0 / maxf(_f(_dio, "blend_s", 0.5), 0.05) * 3.0
	elif locked != null:
		# Frame Red and the target: stand behind Red looking over her shoulder at it.
		var player_pos: Vector3 = feet
		var offset: Vector3 = LockOnMath.flat_offset(player_pos, locked.global_position)
		want_yaw = LockOnMath.camera_yaw_for(player_pos, locked.global_position)
		want_pitch = deg_to_rad(_f(_lock_cfg, "pitch_deg", -16.0) + _view_f("pitch_offset_deg", 0.0))
		var extra: float = minf(offset.length() * _f(_lock_cfg, "extra_distance_per_m", 0.25),
				_f(_lock_cfg, "max_extra_distance_m", 3.0))
		want_distance += extra
		var weight: float = _f(_lock_cfg, "frame_weight", 0.35)
		var aim_at: Vector3 = locked.global_position + Vector3.UP * (height * 0.8)
		want_focus = want_focus.lerp(aim_at, weight)
		rate = _f(_lock_cfg, "yaw_rate", 7.0)
		# Keep the yaw the player would return to when the lock lets go in step with the view.
		_yaw = _view_yaw
	if _blend_left_s > 0.0 and _mode == Mode.ORBIT:
		rate = minf(rate, 1.0 / maxf(_f(_dio, "blend_s", 0.5), 0.05) * 3.0)
	var k: float = 1.0 - exp(-rate * delta)
	_view_yaw += wrapf(want_yaw - _view_yaw, -PI, PI) * k
	_view_pitch = lerpf(_view_pitch, want_pitch, k)
	_view_distance = lerpf(_view_distance, want_distance, 1.0 - exp(-rate * delta))
	_view_fov = lerpf(_view_fov, want_fov, k)
	var follow_k: float = 1.0 if lag <= 0.0001 else 1.0 - exp(-delta / lag)
	_focus = _focus.lerp(want_focus, follow_k)


## Jump straight to the right place (a teleport, the first frame, a reset).
func snap() -> void:
	if _target == null or _camera == null:
		return
	_last_target_pos = _target.global_position
	_travel = Vector3.ZERO
	var facing: Vector3 = _target.global_basis.z
	if absf(_yaw) < 0.0001 and facing.length() > 0.001:
		_yaw = atan2(-facing.x, -facing.z)
	_view_yaw = _yaw if _mode == Mode.ORBIT else deg_to_rad(_f(_dio, "yaw_deg", 0.0))
	_view_pitch = _pitch if _mode == Mode.ORBIT else deg_to_rad(_f(_dio, "pitch_deg", -42.0))
	_view_distance = _orbit_distance() if _mode == Mode.ORBIT else _f(_dio, "distance_m", 10.5) * _view_f("distance_mult", 1.0)
	_view_fov = (_f(_orbit, "fov_deg", 62.0) if _mode == Mode.ORBIT else _f(_dio, "fov_deg", 32.0)) * _view_f("fov_mult", 1.0)
	var height: float = (_f(_orbit, "pivot_height_m", 1.1) if _mode == Mode.ORBIT else _f(_dio, "pivot_height_m", 0.5)) * _view_f("pivot_mult", 1.0)
	_focus = _target.global_position + Vector3.UP * height
	_place_camera(0.0)


func _place_camera(delta: float) -> void:
	global_transform = Transform3D(Basis.from_euler(Vector3(_view_pitch, _view_yaw, 0.0)), _focus)
	_arm_length = _clear_arm(_view_distance)
	var offset: Vector3 = _shake_step(delta)
	_camera.position = Vector3(0.0, 0.0, _arm_length) + offset
	_camera.fov = _view_fov
	if _sv_on:
		_camera.near = _view_f("near_m", _camera.near)
		_camera.far = _view_f("far_m", _camera.far)


## The arm length that stops short of any wall between the pivot and the wanted camera spot.
func _clear_arm(wanted: float) -> float:
	if not is_inside_tree():
		return wanted
	var world: World3D = get_world_3d()
	if world == null:
		return wanted
	var space: PhysicsDirectSpaceState3D = world.direct_space_state
	if space == null:
		return wanted
	var margin: float = _f(_orbit, "collision_margin_m", 0.3)
	var from: Vector3 = global_position
	var to: Vector3 = from + global_basis.z * (wanted + margin)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, int(_orbit.get("collision_mask", 1)))
	query.collide_with_areas = false
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return wanted
	var distance: float = from.distance_to(hit["position"] as Vector3) - margin
	return clampf(distance, minf(_view_f("min_distance_m", _f(_orbit, "min_distance_m", 0.8)), wanted), wanted)


# ---- shake ----

func _shake_profile(profile: StringName) -> Dictionary:
	var db: Node = get_node_or_null("/root/DataDB")
	if db != null:
		var from_fx: Variant = db.call("get_value", "combat/fx", "shake.%s" % profile, null)
		if from_fx is Dictionary and (from_fx as Dictionary).has("amplitude_m"):
			return from_fx as Dictionary
	return _shake_profiles.get(String(profile), _shake_profiles.get("light", {})) as Dictionary


func _shake_amplitude_now() -> float:
	if _shake_left_s <= 0.0 or _shake_total_s <= 0.0:
		return 0.0
	return _shake_amp * _shake_left_s / _shake_total_s


func _shake_step(delta: float) -> Vector3:
	if _shake_left_s <= 0.0:
		return Vector3.ZERO
	_shake_left_s = maxf(_shake_left_s - delta, 0.0)
	_shake_time += delta
	var amp: float = _shake_amplitude_now()
	var phase: float = _shake_time * _shake_hz * TAU
	# Smooth (sines, not stepped noise): two incommensurate waves per axis.
	return Vector3(sin(phase) + 0.5 * sin(phase * 1.7 + 1.3), cos(phase * 0.9 + 0.4) + 0.5 * sin(phase * 2.3), 0.0) * amp * 0.6


# ---- numbers ----

func _orbit_distance() -> float:
	return _knob(KNOB_DISTANCE, _f(_orbit, "distance_m", 4.5)) * _view_f("distance_mult", 1.0)


func _knob(id: String, fallback: float) -> float:
	if knobs != null and knobs.has(id):
		return knobs.get_f(id)
	return fallback


static func _f(source: Dictionary, key: String, fallback: float) -> float:
	return float(source.get(key, fallback))
