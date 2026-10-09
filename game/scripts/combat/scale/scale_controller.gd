class_name ScaleController
extends Node
## Everything that has to change when Red gets a different body size (task CS-21), apart from the controller's own numbers (those
## are ActionPlayer.set_scale_profile). This node:
##   * sets the camera's look for the form and eases it over about 1.5 s (the pull-back that sells the scale),
##   * scales the world's haze with the form: the PS2 fog distances, the real fog density, the shadow range (the camera's own far
##     plane is part of its view). The arena haze made for 44 m hides a 50 m robot; the colossus gets 300 m to 1,500 m,
##   * sets the sound's pitch (and a low-pass) so a big body sounds big,
##   * puts footfalls on the walk and run clips (dust and a camera shake from fx.json scale_sets), a landing slam after a long
##     jump, and a dust puff on dashes,
##   * lets the colossus stomp whatever it walks into (smashable props of the yard).
## The sandbox adds one and calls bind(). Tests call set_form(), tick() and tick_steps() directly.

signal form_changed(form_id: StringName)
signal footstep(foot: int, position: Vector3)
signal slam(position: Vector3)

const FX_DATA_ID: String = "combat/fx"
const STOMP_INTERVAL_S: float = 0.1
const EVENT_LOG_MAX: int = 64

var player: ActionPlayer = null
var camera: OrbitCamera = null
var lock_on: LockOn = null
var yard: RobotYard = null
## Where dust goes (a world node). Defaults to the sandbox.
var world_parent: Node = null
## Tests turn these off to avoid spawning nodes or calling the audio manager.
var effects_enabled: bool = true
var audio_enabled: bool = true
## What happened, newest last (tests read it): {type, foot, position, ...}.
var events: Array[Dictionary] = []
var steps_taken: int = 0
var slams_taken: int = 0
var stomps: int = 0

var _form: ScaleProfile = null
var _look_form: StringName = &""
var _world_from: Dictionary = {}
var _world_to: Dictionary = {}
var _world_now: Dictionary = {}
var _world_t: float = 1.0
var _world_len: float = 0.0
var _room_look: PsxRoomLook = null
var _environment: Environment = null
var _key_light: DirectionalLight3D = null
var _prev_clip: StringName = &""
var _prev_pos: float = -1.0
var _air_s: float = 0.0
var _stomp_clock: float = 0.0
var _sandbox: Node3D = null


## Hooks the controller up to the sandbox's player, camera and look nodes. Starts as the start form (Red).
func bind(sandbox: Node3D, for_player: ActionPlayer, for_camera: OrbitCamera, for_lock: LockOn, for_yard: RobotYard) -> void:
	_sandbox = sandbox
	player = for_player
	camera = for_camera
	lock_on = for_lock
	yard = for_yard
	world_parent = for_yard if for_yard != null else sandbox
	_room_look = sandbox.get_node_or_null("RoomLook") as PsxRoomLook
	var world_env: WorldEnvironment = sandbox.get_node_or_null("WorldEnvironment") as WorldEnvironment
	_environment = world_env.environment if world_env != null else null
	_key_light = sandbox.get_node_or_null("Lights/KeyLight") as DirectionalLight3D
	if _key_light == null:         # a slice room: the level's own sun, wherever its scene put it
		var suns: Array[Node] = sandbox.find_children("*", "DirectionalLight3D", true, false)
		_key_light = suns[0] as DirectionalLight3D if not suns.is_empty() else null
	if player != null and not player.landed.is_connected(_on_landed):
		player.landed.connect(_on_landed)
		player.dashed.connect(_on_dashed)
	set_form(ScaleProfile.start_form(), 0.0)


func _exit_tree() -> void:
	# never leave the sound low and muffled for whatever runs after the sandbox
	var audio: Node = get_node_or_null("/root/AudioManager")
	if audio != null and audio.has_method("set_scale_feel"):
		audio.call("set_scale_feel", 1.0, 0.0)


func _physics_process(delta: float) -> void:
	tick(delta)


# ---- forms ----

func form_id() -> StringName:
	return _form.id if _form != null else &""


func get_form() -> ScaleProfile:
	return _form


## Becomes this body size now: the controller's numbers and model, the camera, the haze, the sound. `blend_s` is how long the
## camera and haze take (negative = the form's own enter_blend_s, 0 = at once).
func set_form(id: StringName, blend_s: float = -1.0) -> bool:
	var profile: ScaleProfile = ScaleProfile.get_form(id)
	if profile == null:
		return false
	set_body(id)
	blend_look(id, blend_s)
	return true


## Only the body: the controller's numbers, model and collision (ActionPlayer.set_scale_profile). The camera, haze and sound
## stay as they are; a sequence that is already easing them there calls this at the moment of the swap.
func set_body(id: StringName) -> bool:
	var profile: ScaleProfile = ScaleProfile.get_form(id)
	if profile == null:
		return false
	_form = profile
	if player != null:
		player.set_scale_profile(profile)
	form_changed.emit(id)
	return true


## Only the look of a form (camera, haze, sound, lock range) without changing the body: the boarding sequence starts the
## pull-back before the swap. Does nothing if that look is already in force or on its way.
func blend_look(id: StringName, blend_s: float = -1.0) -> void:
	var profile: ScaleProfile = ScaleProfile.get_form(id)
	if profile == null or _look_form == id:
		return
	_look_form = id
	var seconds: float = profile.enter_blend_s() if blend_s < 0.0 else blend_s
	_blend_camera(profile.block("camera"), seconds)
	_blend_world(profile.world(), seconds)
	if lock_on != null:
		lock_on.range_scale = profile.lock_range_mult()
	_apply_sound(profile)


## A named camera look (a form's, or one of data "views") eased in over `blend_s`.
func blend_camera_view(view_id: StringName, blend_s: float) -> void:
	_blend_camera(ScaleProfile.camera_block(view_id), blend_s)


## The haze (and shadow range) of a form eased in over `blend_s`, without touching the camera.
func blend_world_to(id: StringName, blend_s: float) -> void:
	var profile: ScaleProfile = ScaleProfile.get_form(id)
	if profile != null:
		_blend_world(profile.world(), blend_s)


func look_form_id() -> StringName:
	return _look_form


func _blend_camera(block: Dictionary, seconds: float) -> void:
	if camera == null or block.is_empty():
		return
	var red_block: Dictionary = ScaleProfile.camera_block(&"red")
	camera.set_scale_view(ScaleProfile.camera_view(block, red_block), seconds)


func _blend_world(world: Dictionary, seconds: float) -> void:
	if world.is_empty():
		return
	var target: Dictionary = {
		"fog_near_m": float(world.get("fog_near_m", 30.0)), "fog_far_m": float(world.get("fog_far_m", 150.0)),
		"env_fog_density": float(world.get("env_fog_density", 0.012)),
		"shadow_max_distance_m": float(world.get("shadow_max_distance_m", 30.0)),
	}
	if _world_now.is_empty() or seconds <= 0.0:
		_world_from = target
		_world_to = target
		_world_now = target.duplicate()
		_world_t = 1.0
		_world_len = 0.0
		_apply_world(_world_now)
		return
	_world_from = _world_now.duplicate()
	_world_to = target
	_world_t = 0.0
	_world_len = seconds


## The haze numbers in force right now (fog_near_m, fog_far_m, env_fog_density, shadow_max_distance_m).
func world_now() -> Dictionary:
	return _world_now.duplicate()


func is_blending() -> bool:
	return _world_t < 1.0 or (camera != null and camera.is_scale_view_blending())


func _apply_world(w: Dictionary) -> void:
	if _room_look != null:
		_room_look.set_fog_distances(float(w["fog_near_m"]), float(w["fog_far_m"]))
	if _environment != null:
		_environment.fog_density = float(w["env_fog_density"])
	if _key_light != null:
		_key_light.directional_shadow_max_distance = float(w["shadow_max_distance_m"])


func _apply_sound(profile: ScaleProfile) -> void:
	if not audio_enabled:
		return
	var audio: Node = get_node_or_null("/root/AudioManager")
	if audio != null and audio.has_method("set_scale_feel"):
		audio.call("set_scale_feel", profile.sound_pitch(), float(profile.audio().get("lowpass_hz", 0.0)))


# ---- per-frame ----

func tick(delta: float) -> void:
	_step_world(delta)
	if player == null or _form == null:
		return
	if player.get_control_mode() != ActionPlayer.ControlMode.NORMAL:
		_prev_pos = -1.0
		_air_s = 0.0
		return
	_air_s = _air_s + delta if player.is_airborne() else 0.0
	var progress: Vector2 = player.clip_progress()
	var flat_speed: float = Vector2(player.velocity.x, player.velocity.z).length()
	var stepping: bool = player.get_state() == ActionPlayer.State.LOCOMOTION and player.is_on_floor() \
			and flat_speed >= float(ScaleProfile.steps().get("min_speed_mps", 0.6))
	tick_steps(player.current_clip(), progress.x, progress.y, stepping)
	_stomp_clock += delta
	if _stomp_clock >= STOMP_INTERVAL_S:
		_stomp_clock = 0.0
		stomp_nearby()


func _step_world(delta: float) -> void:
	if _world_t >= 1.0:
		return
	_world_t = 1.0 if _world_len <= 0.0 else minf(_world_t + delta / _world_len, 1.0)
	_world_now = ScaleProfile.blend(_world_from, _world_to, ScaleProfile.smooth(_world_t))
	_apply_world(_world_now)


## One look at the walk or run clip: any footfall passed since the last look makes a step. `stepping` false (standing, in the air,
## mid-attack) forgets the playhead so the next step is clean. Returns the feet that came down (0 left, 1 right).
func tick_steps(clip: StringName, position_s: float, length_s: float, stepping: bool) -> Array[int]:
	var feet: Array[int] = []
	var set_cfg: Dictionary = fx_set()
	if not stepping or set_cfg.is_empty() or (clip != &"walk" and clip != &"run"):
		_prev_pos = -1.0
		_prev_clip = &""
		return feet
	if clip == _prev_clip and _prev_pos >= 0.0:
		var times: Array = (set_cfg.get("footfalls_s", {}) as Dictionary).get(String(clip), []) as Array
		feet = ScaleSteps.crossed(_prev_pos, position_s, length_s, times)
	_prev_clip = clip
	_prev_pos = position_s
	for foot: int in feet:
		_footstep(foot)
	return feet


## fx.json scale_sets entry for the current form ("small" or "huge"), empty for Red.
func fx_set() -> Dictionary:
	if _form == null or _form.fx_set().is_empty():
		return {}
	return (_fx().get("scale_sets", {}) as Dictionary).get(_form.fx_set(), {}) as Dictionary


func _fx() -> Dictionary:
	var db: Node = get_node_or_null("/root/DataDB")
	return (db.call("get_dict", FX_DATA_ID) as Dictionary) if db != null else {}


func _shake_cfg(id: String) -> Dictionary:
	return (_fx().get("shake", {}) as Dictionary).get(id, {}) as Dictionary


func _foot_position(foot: int) -> Vector3:
	var floor_y: float = player.global_position.y if player != null else 0.0
	if player != null:
		var spot: Vector3 = player.model_bone_position("foot_l" if foot == 0 else "foot_r")
		if spot != Vector3.INF:
			return Vector3(spot.x, floor_y, spot.z)
		return Vector3(player.global_position.x, floor_y, player.global_position.z)
	return Vector3.ZERO


func _footstep(foot: int) -> void:
	var set_cfg: Dictionary = fx_set()
	var at: Vector3 = _foot_position(foot)
	steps_taken += 1
	_log({"type": "step", "foot": foot, "position": at, "dust": str(set_cfg.get("step_dust", "")), "shake": str(set_cfg.get("step_shake", ""))})
	footstep.emit(foot, at)
	if not effects_enabled:
		return
	spawn_dust(at, StringName(str(set_cfg.get("step_dust", ""))))
	play_shake(StringName(str(set_cfg.get("step_shake", ""))))
	play_sound(StringName(_form.s("step_sound", "")))


func _on_landed() -> void:
	var long_jump: bool = _form != null and _air_s >= _form.f("land_min_air_s", 0.3)
	_air_s = 0.0
	if not long_jump or player == null or player.get_control_mode() != ActionPlayer.ControlMode.NORMAL:
		return
	var set_cfg: Dictionary = fx_set()
	if set_cfg.is_empty():
		return
	var at: Vector3 = Vector3(player.global_position.x, player.global_position.y, player.global_position.z)
	slams_taken += 1
	_log({"type": "slam", "position": at, "dust": str(set_cfg.get("land_dust", "")), "shake": str(set_cfg.get("land_shake", ""))})
	slam.emit(at)
	if effects_enabled:
		spawn_dust(at, StringName(str(set_cfg.get("land_dust", ""))))
		play_shake(StringName(str(set_cfg.get("land_shake", ""))))
		play_sound(StringName(_form.s("land_sound", "")))
	stomp_nearby(_form.f("slam_radius_mult", 2.0))


func _on_dashed(_air: bool) -> void:
	if _form == null or player == null or not bool(ScaleProfile.steps().get("dash_dust", true)):
		return
	var set_cfg: Dictionary = fx_set()
	if set_cfg.is_empty() or not effects_enabled:
		return
	spawn_dust(Vector3(player.global_position.x, player.global_position.y, player.global_position.z), StringName(str(set_cfg.get("step_dust", ""))))
	play_shake(StringName(str(set_cfg.get("step_shake", ""))))


## Flattens the props the colossus is standing on or walking through (only while it is on the ground). A landing slam passes
## a bigger `radius_mult`: the shock of a 50 m robot coming down flattens what is around its feet too.
func stomp_nearby(radius_mult: float = 1.0) -> int:
	if _form == null or yard == null or player == null or _form.stomp_radius_m() <= 0.0:
		return 0
	if player.get_control_mode() != ActionPlayer.ControlMode.NORMAL or (player.is_airborne() and _air_s > 0.05):
		return 0
	var count: int = 0
	for prop: SmashProp in yard.props_within(player.global_position, _form.stomp_radius_m() * radius_mult):
		prop.stomp()
		count += 1
	stomps += count
	if count > 0:
		_log({"type": "stomp", "count": count})
	return count


func spawn_dust(at: Vector3, id: StringName) -> void:
	if id == &"" or world_parent == null or not world_parent.is_inside_tree():
		return
	ScaleDust.spawn(world_parent, at, id)


## A shake that already knows how big it should be for a far camera (fx.json suggested_mult), not multiplied again by the view.
func play_shake(id: StringName) -> void:
	if id == &"" or camera == null:
		return
	var cfg: Dictionary = _shake_cfg(String(id))
	camera.shake(id, float(cfg.get("suggested_mult", 1.0)), false)


func play_sound(id: StringName) -> void:
	if id == &"" or not audio_enabled:
		return
	var audio: Node = get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.call("play_sfx", id)


func _log(entry: Dictionary) -> void:
	events.append(entry)
	while events.size() > EVENT_LOG_MAX:
		events.remove_at(0)


## Back to Red at once (Reset arena).
func reset() -> void:
	_look_form = &""
	set_form(&"red", 0.0)
	events.clear()
	steps_taken = 0
	slams_taken = 0
	stomps = 0
	_prev_pos = -1.0
	_air_s = 0.0
