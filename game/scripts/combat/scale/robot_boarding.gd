class_name RobotBoarding
extends Node
## Red getting into the loader, the loader docking into the colossus, and the way back out (task CS-21; Ross: "use robots docking
## into each other"). It owns the story of who is in control:
##
##   RED --walk into the ring--> BOARDING --> SMALL --walk to the glowing ring in front of the colossus--> DOCKING --> HUGE
##   RED <--------- DISEMBARKING <-------- SMALL (Q) <------------ UNDOCKING <------------ HUGE (Q)
##
## The same ActionPlayer is in control the whole time; only its body size changes (ScaleController). While a sequence runs, the
## sequence moves the actors: the parked robots (RobotDisplay) hop, open their hatch and doors, and the player node follows so the
## camera does. The timings are data (data/combat/scale_profiles.json "sequences", the Technical Artist's docking staging:
## approach, doors, hop, snap, lock, power-up). Control comes back before the very end of each sequence.
##
## Tests and bots: set read_engine_input = false, then request_disembark() / request_interact(), and call tick(delta).

enum Mode { RED, BOARDING, SMALL, DOCKING, HUGE, UNDOCKING, DISEMBARKING }

signal mode_changed(mode: Mode)
signal sequence_event(kind: StringName, event: StringName)

const TEXT_ID: String = "text/robot_test"
const ACTION_INTERACT: StringName = &"interact"
const RING_Y: float = 0.06

var yard: RobotYard = null
var controller: ScaleController = null
var player: ActionPlayer = null
var camera: OrbitCamera = null
var sandbox: Node3D = null
## Poll Input for interact and disembark (the game). Bots and tests turn it off and use the request_* calls.
var read_engine_input: bool = true
## False in headless tests: no audio calls, no dust or label nodes.
var effects_enabled: bool = true
## False while the loader sleeps (the slice's J4 until it is woken): the ring is off and walking in does nothing. board_now()
## ignores it, so a script can still start the boarding.
var boarding_enabled: bool = true
## What happened, newest last: {mode, event}. Tests read it.
var history: Array[StringName] = []

var _mode: Mode = Mode.RED
var _seq: RobotSequence = null
var _cfg: Dictionary = {}
var _texts: Dictionary = {}
var _interact_queued: bool = false
var _disembark_queued: bool = false
var _disembark_wait_s: float = 0.0
var _lockout: bool = false
var _dock_lockout: bool = false
var _ctx: Dictionary = {}
var _ring: MeshInstance3D = null
var _dock_ring: MeshInstance3D = null
var _prompt: Label = null
var _prompt_text: String = ""
var _pulse: float = 0.0


func bind(for_sandbox: Node3D, for_player: ActionPlayer, for_camera: OrbitCamera, for_controller: ScaleController, for_yard: RobotYard) -> void:
	sandbox = for_sandbox
	player = for_player
	camera = for_camera
	controller = for_controller
	yard = for_yard
	_cfg = ScaleProfile.boarding()
	var db: Node = get_node_or_null("/root/DataDB")
	_texts = (db.call("get_dict", TEXT_ID) as Dictionary) if db != null else {}
	if effects_enabled:
		_make_rings()
		_make_prompt()


func _physics_process(delta: float) -> void:
	tick(delta)


# ---- the bot and test API ----

func get_mode() -> Mode:
	return _mode


func mode_name() -> String:
	return Mode.keys()[_mode]


func get_sequence() -> RobotSequence:
	return _seq


func is_in_sequence() -> bool:
	return _seq != null


## The same as pressing interact (E).
func request_interact() -> void:
	_interact_queued = true


## The same as pressing the disembark button (Q).
func request_disembark() -> void:
	_disembark_queued = true


func prompt_text() -> String:
	return _prompt_text


## Starts the boarding sequence now, from wherever Red stands (a hack or a script woke the loader; the slice's RobotStage).
## She steps to the boarding point and climbs in as usual. False if she is not free to (mid-swing, in the air, already in a robot).
func board_now() -> bool:
	if player == null or yard == null or yard.small_display == null or not yard.small_display.is_active():
		return false
	if _mode != Mode.RED or _seq != null or not _free_to_act():
		return false
	_start_board()
	return _mode == Mode.BOARDING


## Starts the docking now (the loader walks to the colossus, hops into the bay): the boss transition's call. Needs the loader
## form and a colossus in this room.
func dock_now() -> bool:
	if player == null or yard == null or yard.huge_display == null or _mode != Mode.SMALL or _seq != null or not _free_to_act():
		return false
	_start_dock()
	return _mode == Mode.DOCKING


## Starts the room already inside a robot (`red`, `small` or `huge`), with no boarding sequence: the slice's J5 begins in the
## loader. The robot's model is hidden (she is wearing it), her body, camera and haze are the form's at once.
func place_in(form: StringName) -> bool:
	if player == null or controller == null or yard == null or ScaleProfile.get_form(form) == null:
		return false
	_seq = null
	_ctx.clear()
	_lockout = false
	_dock_lockout = false
	_interact_queued = false
	_disembark_queued = false
	_disembark_wait_s = 0.0
	player.input_locked = false
	player.set_control_mode(ActionPlayer.ControlMode.NORMAL)
	controller.set_form(form, 0.0)
	if yard.small_display != null:
		yard.small_display.set_active(form == &"red")
		yard.small_display.set_hatch_open(0.0)
	if yard.huge_display != null:
		yard.huge_display.set_active(form != &"huge")
		yard.huge_display.set_doors_open(0.0)
	_set_mode(Mode.HUGE if form == &"huge" else (Mode.SMALL if form == &"small" else Mode.RED))
	return true


## Back to Red standing by the parked loader (Reset arena).
func reset() -> void:
	_seq = null
	_ctx.clear()
	_lockout = false
	_dock_lockout = false
	_interact_queued = false
	_disembark_queued = false
	_disembark_wait_s = 0.0
	if player != null:
		player.input_locked = false
		player.set_control_mode(ActionPlayer.ControlMode.NORMAL)
	if controller != null:
		controller.reset()
	if yard != null:
		yard.reset()
	_set_mode(Mode.RED)


# ---- per frame ----

func tick(delta: float) -> void:
	if player == null or yard == null or yard.small_display == null:
		return
	var disembark: bool = _take_disembark(delta)
	var interact: bool = _take_interact()
	match _mode:
		Mode.RED:
			_tick_red(interact)
		Mode.SMALL:
			_tick_small(disembark)
		Mode.HUGE:
			_tick_huge(disembark)
		_:
			_tick_sequence(delta)
	_update_prompt()
	_update_rings(delta)


## The disembark button, remembered for a moment: a press while still moving climbs out as soon as she has stopped (the colossus
## takes a second and a half to slow down), but a press that nobody follows up does not go off a minute later.
func _take_disembark(delta: float) -> bool:
	var pressed: bool = _disembark_queued or (read_engine_input and Input.is_action_just_pressed(StringName(str(_cfg.get("disembark_action", "disembark")))))
	_disembark_queued = false
	if _mode != Mode.SMALL and _mode != Mode.HUGE:
		_disembark_wait_s = 0.0
		return false
	if pressed:
		_disembark_wait_s = float(_cfg.get("disembark_buffer_s", 2.0))
		return true
	if _disembark_wait_s > 0.0:
		_disembark_wait_s = maxf(_disembark_wait_s - delta, 0.0)
		return true
	return false


func _take_interact() -> bool:
	var pressed: bool = _interact_queued or (read_engine_input and Input.is_action_just_pressed(ACTION_INTERACT))
	_interact_queued = false
	return pressed


static func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _free_to_act() -> bool:
	return player.get_control_mode() == ActionPlayer.ControlMode.NORMAL and not player.input_locked \
			and player.get_state() == ActionPlayer.State.LOCOMOTION and player.is_on_floor()


func _tick_red(interact: bool) -> void:
	if not boarding_enabled:
		return
	var board_at: Vector3 = yard.small_display.boarding_point()
	var gap: float = flat_distance(player.global_position, board_at)
	var enter: float = float(_cfg.get("enter_radius_m", 1.15))
	if _lockout:
		if gap > enter + 0.6:
			_lockout = false
		return
	if not _free_to_act():
		return
	if gap <= enter or (interact and gap <= float(_cfg.get("interact_radius_m", 2.6))):
		_start_board()


func _tick_small(disembark: bool) -> void:
	if not _free_to_act():
		return
	var speed: float = Vector2(player.velocity.x, player.velocity.z).length()
	if disembark and speed <= float(_cfg.get("disembark_max_speed_mps", 1.5)):
		_start_disembark()
		return
	if yard.huge_display == null:
		return
	var to_ring: float = flat_distance(player.global_position, yard.huge_display.approach_point())
	var trigger: float = float(_cfg.get("dock_trigger_m", 3.5))
	if _dock_lockout:
		if to_ring > trigger + 1.5:
			_dock_lockout = false
		return
	if to_ring <= trigger:
		_start_dock()


func _tick_huge(disembark: bool) -> void:
	if not _free_to_act():
		return
	var speed: float = Vector2(player.velocity.x, player.velocity.z).length()
	if disembark and speed <= float(_cfg.get("disembark_max_speed_mps", 1.5)):
		_start_undock()


func _set_mode(mode: Mode) -> void:
	if mode == _mode:
		return
	_mode = mode
	mode_changed.emit(mode)


func _begin(kind: StringName, mode: Mode) -> bool:
	_seq = RobotSequence.from_data(kind)
	if _seq == null:
		return false
	_ctx = {}
	_set_mode(mode)
	player.set_move_input(Vector2.ZERO)
	return true


func _root_transform(pos: Vector3, yaw: float) -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(0.0, yaw, 0.0)), pos)


func _floor_of(pos: Vector3) -> Vector3:
	return Vector3(pos.x, 0.0, pos.z)


# ---- starting a sequence ----

func _start_board() -> void:
	if not _begin(&"board", Mode.BOARDING):
		return
	_ctx["from_pos"] = player.global_position
	_ctx["from_yaw"] = player.rotation.y
	player.set_control_mode(ActionPlayer.ControlMode.SCRIPTED)


func _start_disembark() -> void:
	_disembark_wait_s = 0.0
	var at: Vector3 = player.global_position
	var yaw: float = player.rotation.y
	if not _begin(&"disembark", Mode.DISEMBARKING):
		return
	_ctx["robot_pos"] = at
	_ctx["robot_yaw"] = yaw
	player.set_control_mode(ActionPlayer.ControlMode.GHOST)
	var small: RobotDisplay = yard.small_display
	small.global_transform = _root_transform(at, yaw)
	small.set_active(true)
	small.set_hatch_open(0.0)
	small.play(&"idle")
	controller.set_form(&"red")          # Red's body, and the camera starts coming in
	player.global_position = small.seat_point()


func _start_dock() -> void:
	var at: Vector3 = player.global_position
	var yaw: float = player.rotation.y
	if not _begin(&"dock", Mode.DOCKING):
		return
	_ctx["from_pos"] = at
	_ctx["from_yaw"] = yaw
	player.set_control_mode(ActionPlayer.ControlMode.GHOST)
	var small: RobotDisplay = yard.small_display
	small.global_transform = _root_transform(at, yaw)
	small.set_active(true)
	small.set_hatch_open(0.0)
	small.play(&"walk", 1.4)
	yard.huge_display.play(&"idle")


func _start_undock() -> void:
	_disembark_wait_s = 0.0
	var at: Vector3 = player.global_position
	var yaw: float = player.rotation.y
	if not _begin(&"undock", Mode.UNDOCKING):
		return
	player.set_control_mode(ActionPlayer.ControlMode.GHOST)
	var huge: RobotDisplay = yard.huge_display
	huge.global_transform = _root_transform(at, yaw)
	huge.set_active(true)
	huge.set_doors_open(0.0)
	huge.play(&"idle")
	var small: RobotDisplay = yard.small_display
	var bay: Vector3 = huge.dock_point()
	_ctx["bay_pos"] = bay
	_ctx["in_yaw"] = RobotDisplay.yaw_of(-huge.facing())
	small.global_transform = _root_transform(bay, float(_ctx["in_yaw"]))
	small.set_active(true)
	small.set_hatch_open(0.0)
	small.play(&"idle")
	controller.set_body(&"small")
	player.global_position = bay


# ---- running a sequence ----

func _tick_sequence(delta: float) -> void:
	if _seq == null:
		_set_mode(Mode.RED)
		return
	var kind: StringName = _seq.kind
	var events: Array[StringName] = _seq.tick(delta)
	for cue: Dictionary in _seq.take_cues():
		_apply_cue(cue)
	for event: StringName in events:
		history.append(StringName("%s:%s" % [kind, event]))
		sequence_event.emit(kind, event)
		_on_event(kind, event)
	if _seq == null:
		return
	match kind:
		&"board":
			_drive_board()
		&"disembark":
			_drive_disembark()
		&"dock":
			_drive_dock()
		&"undock":
			_drive_undock()
	if _seq != null and _seq.has_fired(&"done"):
		_finish()


func _finish() -> void:
	var kind: StringName = _seq.kind
	_seq = null
	_ctx.clear()
	player.input_locked = false
	match kind:
		&"board":
			_set_mode(Mode.SMALL)
		&"disembark":
			_lockout = true
			_set_mode(Mode.RED)
		&"dock":
			_set_mode(Mode.HUGE)
		&"undock":
			_dock_lockout = true
			_set_mode(Mode.SMALL)


func _apply_cue(cue: Dictionary) -> void:
	var view: StringName = StringName(str(cue.get("view", "")))
	var blend: float = float(cue.get("blend_s", 1.0))
	if view != &"" and controller != null:
		if ScaleProfile.get_form(view) != null:
			controller.blend_look(view, blend)
		else:
			controller.blend_camera_view(view, blend)
	if cue.has("world") and controller != null:
		controller.blend_world_to(StringName(str(cue["world"])), float(cue.get("world_blend_s", blend)))


func _on_event(kind: StringName, event: StringName) -> void:
	match kind:
		&"board":
			_event_board(event)
		&"disembark":
			_event_disembark(event)
		&"dock":
			_event_dock(event)
		&"undock":
			_event_undock(event)


# ---- boarding ----

func _event_board(event: StringName) -> void:
	var small: RobotDisplay = yard.small_display
	match event:
		&"begin:hatch_open":
			_play(&"hatch")
		&"begin:climb":
			_ctx["boarding_point"] = small.boarding_point()
			_ctx["seat"] = small.seat_point()
		&"end:climb":
			player.set_control_mode(ActionPlayer.ControlMode.GHOST)
			player.global_position = small.seat_point()
		&"begin:hatch_close":
			_play(&"hatch")
			controller.blend_look(&"small")             # the camera starts pulling back before the swap
		&"swap":
			small.set_hatch_open(0.0)
			player.input_locked = true
			var at: Vector3 = small.global_position
			var yaw: float = small.rotation.y
			small.set_active(false)
			player.global_transform = _root_transform(at, yaw)
			controller.set_body(&"small")
			player.set_control_mode(ActionPlayer.ControlMode.NORMAL)
			player.global_transform = _root_transform(at, yaw)
			_play(&"power_up")
			controller.play_shake(&"land_small")
		&"control":
			player.input_locked = false


func _drive_board() -> void:
	var small: RobotDisplay = yard.small_display
	var board_at: Vector3 = small.boarding_point()
	var seat: Vector3 = small.seat_point()
	var face: float = RobotDisplay.yaw_of(_floor_of(seat) - _floor_of(board_at))
	var step_p: float = _seq.progress(&"step")
	var climb_p: float = _seq.progress(&"climb")
	if not _seq.has_fired(&"end:climb") and player.get_control_mode() == ActionPlayer.ControlMode.SCRIPTED:
		var height: float = float(ScaleProfile.sequence(&"board").get("climb_height_m", 1.2))
		if climb_p <= 0.0:
			var from_pos: Vector3 = _ctx.get("from_pos", player.global_position) as Vector3
			player.global_position = from_pos.lerp(board_at, ScaleProfile.ease_out(step_p))
			player.rotation.y = lerp_angle(float(_ctx.get("from_yaw", 0.0)), face, ScaleProfile.smooth(step_p))
			player.play_scripted_clip(&"run" if step_p < 1.0 else &"idle", 1.0)
		else:
			var eased: float = ScaleProfile.smooth(climb_p)
			player.global_position = board_at.lerp(seat, eased) + Vector3.UP * (4.0 * height * climb_p * (1.0 - climb_p))
			player.rotation.y = face
			player.play_scripted_clip(&"jump_up" if climb_p < 0.5 else &"fall", 1.0)
	elif player.get_control_mode() == ActionPlayer.ControlMode.GHOST and not _seq.has_fired(&"swap"):
		player.global_position = seat
	small.set_hatch_open(_seq.progress(&"hatch_open") * (1.0 - _seq.progress(&"hatch_close")) if not _seq.has_fired(&"swap") else 0.0)


# ---- climbing out ----

func _event_disembark(event: StringName) -> void:
	var small: RobotDisplay = yard.small_display
	match event:
		&"begin:power_down":
			_play(&"power_up")
			controller.play_shake(&"step_small")
		&"begin:hatch_open":
			_play(&"hatch")
		&"begin:climb":
			player.set_control_mode(ActionPlayer.ControlMode.SCRIPTED)
			player.global_position = small.seat_point()
		&"end:climb":
			player.global_position = small.boarding_point()
			player.play_scripted_clip(&"idle", 1.0)
		&"begin:hatch_close":
			_play(&"hatch")
		&"control":
			var out: Vector3 = small.boarding_point()
			player.set_control_mode(ActionPlayer.ControlMode.NORMAL)
			player.global_position = Vector3(out.x, 0.02, out.z)
			player.input_locked = false
			_lockout = true


func _drive_disembark() -> void:
	var small: RobotDisplay = yard.small_display
	var seat: Vector3 = small.seat_point()
	var out: Vector3 = small.boarding_point()
	var climb_p: float = _seq.progress(&"climb")
	small.set_hatch_open(_seq.progress(&"hatch_open") * (1.0 - _seq.progress(&"hatch_close")))
	var facing_out: float = float(_ctx.get("robot_yaw", 0.0)) + PI
	if player.get_control_mode() == ActionPlayer.ControlMode.GHOST:
		player.global_position = seat
	elif player.get_control_mode() == ActionPlayer.ControlMode.SCRIPTED and not _seq.has_fired(&"control"):
		var height: float = float(ScaleProfile.sequence(&"disembark").get("climb_height_m", 1.2))
		player.global_position = seat.lerp(out, ScaleProfile.smooth(climb_p)) + Vector3.UP * (4.0 * height * climb_p * (1.0 - climb_p))
		player.rotation.y = facing_out
		player.play_scripted_clip(&"jump_up" if climb_p < 0.4 else &"fall", 1.0)


# ---- docking ----

func _event_dock(event: StringName) -> void:
	var small: RobotDisplay = yard.small_display
	var huge: RobotDisplay = yard.huge_display
	match event:
		&"end:approach":
			small.play(&"idle")
		&"begin:doors":
			_play(&"doors")
			controller.play_shake(&"step_small")
		&"begin:hop":
			small.play(&"jump_up")
			_play(&"hatch")
		&"end:hop":
			small.play(&"fall")
		&"end:snap":
			_seq.freeze(float(ScaleProfile.sequence(&"dock").get("hit_stop_s", 0.08)))
			_play(&"snap")
			controller.play_shake(&"land_small")
			_spark_burst(huge.dock_point())
			small.play(&"idle")
		&"begin:lock":
			_play(&"lock")
			controller.play_shake(&"step_huge")
		&"begin:power_up":
			_play(&"power_up")
		&"swap":
			huge.set_doors_open(0.0)
			var at: Vector3 = huge.global_position
			var yaw: float = huge.rotation.y
			small.set_active(false)
			huge.set_active(false)
			player.input_locked = true
			player.global_transform = _root_transform(at, yaw)
			controller.set_body(&"huge")
			controller.blend_look(&"huge")
			player.set_control_mode(ActionPlayer.ControlMode.NORMAL)
			player.global_transform = _root_transform(at, yaw)
			controller.play_shake(&"step_huge")
		&"control":
			player.input_locked = false


func _drive_dock() -> void:
	var small: RobotDisplay = yard.small_display
	var huge: RobotDisplay = yard.huge_display
	var swapped: bool = _seq.has_fired(&"swap")
	var bay: Vector3 = huge.dock_point()
	var approach: Vector3 = _floor_of(huge.approach_point())
	var facing_huge: float = RobotDisplay.yaw_of(-huge.facing())          # looks at the colossus
	var hop_h: float = float(ScaleProfile.sequence(&"dock").get("hop_height_m", 6.0))
	if not swapped:
		var pos: Vector3 = small.global_position
		var yaw: float = small.rotation.y
		var approach_p: float = _seq.progress(&"approach")
		var hop_p: float = _seq.progress(&"hop")
		var snap_p: float = _seq.progress(&"snap")
		if hop_p <= 0.0:
			var from_pos: Vector3 = _ctx.get("from_pos", approach) as Vector3
			pos = _floor_of(from_pos).lerp(approach, ScaleProfile.smooth(approach_p))
			pos.y = from_pos.y
			yaw = lerp_angle(float(_ctx.get("from_yaw", 0.0)), facing_huge, ScaleProfile.smooth(approach_p))
		elif snap_p <= 0.0:
			var top: Vector3 = bay + Vector3.UP * 0.6
			pos = approach.lerp(top, ScaleProfile.smooth(hop_p)) + Vector3.UP * (4.0 * hop_h * hop_p * (1.0 - hop_p))
			yaw = facing_huge
		else:
			var top_now: Vector3 = bay + Vector3.UP * 0.6
			pos = top_now.lerp(bay, snap_p * snap_p)
			yaw = facing_huge
		small.global_transform = _root_transform(pos, yaw)
		player.global_position = pos
		var doors: float = ScaleProfile.ease_out(_seq.progress(&"doors")) * (1.0 - ScaleProfile.smooth(_seq.progress(&"lock")))
		huge.set_doors_open(doors)


# ---- undocking ----

func _event_undock(event: StringName) -> void:
	var small: RobotDisplay = yard.small_display
	var huge: RobotDisplay = yard.huge_display
	match event:
		&"begin:power_down":
			_play(&"power_up")
			controller.play_shake(&"step_huge")
		&"begin:doors":
			_play(&"doors")
		&"begin:hop":
			small.play(&"jump_up")
		&"end:hop":
			small.play(&"idle")
			_play(&"snap")
			controller.play_shake(&"land_small")
			controller.spawn_dust(_floor_of(huge.approach_point()), &"land_small")
		&"begin:doors_close":
			_play(&"lock")
		&"swap":
			var out: Vector3 = _floor_of(huge.approach_point())
			small.set_active(false)
			player.input_locked = true
			player.global_transform = _root_transform(Vector3(out.x, 0.02, out.z), float(_ctx.get("in_yaw", 0.0)) + PI)
			player.set_control_mode(ActionPlayer.ControlMode.NORMAL)
			player.global_transform = _root_transform(Vector3(out.x, 0.02, out.z), float(_ctx.get("in_yaw", 0.0)) + PI)
		&"control":
			player.input_locked = false


func _drive_undock() -> void:
	var small: RobotDisplay = yard.small_display
	var huge: RobotDisplay = yard.huge_display
	var bay: Vector3 = _ctx.get("bay_pos", huge.dock_point()) as Vector3
	var out: Vector3 = _floor_of(huge.approach_point())
	var hop_h: float = float(ScaleProfile.sequence(&"undock").get("hop_height_m", 6.0))
	var hop_p: float = _seq.progress(&"hop")
	if not _seq.has_fired(&"swap"):
		var in_yaw: float = float(_ctx.get("in_yaw", 0.0))
		var pos: Vector3 = bay
		var yaw: float = in_yaw
		if hop_p > 0.0:
			pos = bay.lerp(out, ScaleProfile.smooth(hop_p)) + Vector3.UP * (4.0 * hop_h * hop_p * (1.0 - hop_p))
			yaw = lerp_angle(in_yaw, in_yaw + PI, ScaleProfile.smooth(hop_p))
		small.global_transform = _root_transform(pos, yaw)
		player.global_position = pos
	var open: float = ScaleProfile.ease_out(_seq.progress(&"doors")) * (1.0 - ScaleProfile.smooth(_seq.progress(&"doors_close")))
	huge.set_doors_open(open)


# ---- effects ----

func _play(key: StringName) -> void:
	if not effects_enabled:
		return
	var id: String = str(ScaleProfile.sounds().get(String(key), ""))
	if id.is_empty():
		return
	var audio: Node = get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.call("play_sfx", StringName(id))


## An orange burst where the loader locks into the bay.
func _spark_burst(at: Vector3) -> void:
	if not effects_enabled or yard == null or not yard.is_inside_tree():
		return
	var cfg: Dictionary = ScaleDust.profile(&"land_small").duplicate(true)
	if cfg.is_empty():
		return
	cfg["color"] = "#ffb347"
	cfg["count"] = 20
	cfg["ring_radius_m"] = 0.8
	cfg["speed_mps"] = [4.0, 10.0]
	cfg["size_m"] = [0.25, 0.6]
	cfg["life_s"] = 0.55
	cfg["alpha"] = 0.95
	cfg["rise_mps"] = 2.0
	cfg.erase("shock_ring")
	ScaleDust.spawn(yard, at, &"land_small", cfg)


func _make_rings() -> void:
	_ring = _ring_mesh("BoardingRing", float(_cfg.get("enter_radius_m", 1.15)), Color.html(str(_cfg.get("ring_color", "#4fd8ff"))))
	_dock_ring = _ring_mesh("DockRing", float(_cfg.get("dock_trigger_m", 3.5)), Color("#ffb347"))
	add_child(_ring)
	add_child(_dock_ring)
	_ring.top_level = true
	_dock_ring.top_level = true
	_ring.visible = false
	_dock_ring.visible = false


func _ring_mesh(node_name: String, radius: float, color: Color) -> MeshInstance3D:
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = radius * 0.9
	torus.outer_radius = radius
	torus.rings = 32
	torus.ring_segments = 4
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color.r, color.g, color.b, 0.7)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = node_name
	node.mesh = torus
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.scale = Vector3(1.0, 0.08, 1.0)
	return node


func _update_rings(delta: float) -> void:
	_pulse += delta
	if _ring == null:
		return
	var show_board: bool = _mode == Mode.RED and boarding_enabled and yard.small_display.is_active()
	_ring.visible = show_board
	if show_board:
		_ring.global_position = _floor_of(yard.small_display.boarding_point()) + Vector3.UP * RING_Y
		var k: float = 1.0 + 0.08 * sin(_pulse * 4.0)
		_ring.scale = Vector3(k, 0.08, k)
	var show_dock: bool = _mode == Mode.SMALL and yard.huge_display != null
	_dock_ring.visible = show_dock
	if show_dock:
		_dock_ring.global_position = _floor_of(yard.huge_display.approach_point()) + Vector3.UP * RING_Y
		var k2: float = 1.0 + 0.06 * sin(_pulse * 3.0)
		_dock_ring.scale = Vector3(k2, 0.2, k2)


func _make_prompt() -> void:
	if sandbox == null or not sandbox.has_method("get_ui_parent"):
		return
	var parent: Node = sandbox.call("get_ui_parent") as Node
	if parent == null:
		return
	_prompt = Label.new()
	_prompt.name = "RobotPrompt"
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_top = -110.0
	_prompt.offset_bottom = -70.0
	_prompt.offset_left = -480.0
	_prompt.offset_right = 480.0
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override(&"font_size", 24)
	_prompt.add_theme_color_override(&"font_color", Color("#f3e9d0"))
	_prompt.add_theme_color_override(&"font_outline_color", Color("#14121f"))
	_prompt.add_theme_constant_override(&"outline_size", 8)
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.visible = false
	parent.add_child(_prompt)


## What to tell the player right now (data/text/robot_test.json).
func compute_prompt() -> String:
	match _mode:
		Mode.RED:
			if yard != null and boarding_enabled and yard.small_display != null and yard.small_display.is_active() \
					and flat_distance(player.global_position, yard.small_display.boarding_point()) <= float(_cfg.get("prompt_range_m", 14.0)):
				return str(_texts.get("board", ""))
		Mode.SMALL:
			return str(_texts.get("small", ""))
		Mode.HUGE:
			return str(_texts.get("huge", ""))
		Mode.BOARDING, Mode.DISEMBARKING:
			return ""
		Mode.DOCKING:
			return str(_texts.get("docking", ""))
		Mode.UNDOCKING:
			return str(_texts.get("undocking", ""))
	return ""


func _update_prompt() -> void:
	var text: String = compute_prompt()
	if text == _prompt_text:
		return
	_prompt_text = text
	_show_prompt(text)


func _show_prompt(text: String) -> void:
	if _prompt != null and is_instance_valid(_prompt):
		_prompt.text = text
		_prompt.visible = not text.is_empty()


func _exit_tree() -> void:
	if _prompt != null and is_instance_valid(_prompt):
		_prompt.queue_free()
