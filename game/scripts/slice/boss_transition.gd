class_name BossTransition
extends Node
## The boss phase change, Kasp's rig to the junk mech (task VS-30; docs/slice/boss_design.md "Transition", docs/maps/kasp_arena.md
## step 5; about 40 seconds). It runs the scripted half of the fight in the arena room, through the RobotStage (VS-21):
##
##   kasp_escape    Kasp is thrown from the seat, runs to the escape point and rides a crane cage up (about 4 s). Red has control.
##   mech_assemble  the three yard cranes pour scrap into the Heap (about 8 s); the stockade's east gate opens; Vela barks. Red
##                  has control and runs down the ramp.
##   board_loader   Red has control until she climbs into the loader (the normal boarding ring and sequence). No timer.
##   drive          the loader drives the ring road to the dock approach (scripted, skippable); the colossus wakes in its cradle
##                  and steps to its dock spot meanwhile.
##   dock_colossus  the CS-21 docking (4.5 s). The ScaleController eases camera, haze and sound to the colossus numbers at the
##                  swap, mid-scene; control returns in the colossus and `finished` is emitted.
## Red cannot be hurt from the first step to the last (iframes refreshed every tick).
##
## THE HOOK WITH BossFight (agreed in the plan's Changes): the BossFight adds this node to the arena, calls begin() when the
## rig phase ends, and starts phase 2 on `finished`. It sets the phase-2 retry point itself with
## ActionRoom.set_phase_checkpoint("retry_phase2", &"huge"); a reload at retry_phase2 calls start_docked() instead of begin().
## Optional refs it may set: `kasp` (the seat's Kasp, a Node3D) and `mech` (the junk mech; if it has set_assemble_progress(t)
## that is called 0..1 during mech_assemble). Without them the transition draws plain stand-ins. Nothing here knows the boss's
## health or patterns.
##
## Marker names (scene nodes, anywhere under the room) come from data/slice/boss_transition.json `markers`.

enum Step { IDLE, KASP_ESCAPE, MECH_ASSEMBLE, BOARD_LOADER, DRIVE, DOCK_COLOSSUS, DONE }

signal step_started(step: StringName)
signal step_finished(step: StringName)
signal crane_poured(crane_id: StringName)
signal radio_said(speaker: String, text: String)
signal finished

const DATA_ID: String = "slice/boss_transition"
const GROUP: StringName = &"boss_transition"
const STEP_NAMES: Dictionary = {
	Step.KASP_ESCAPE: &"kasp_escape", Step.MECH_ASSEMBLE: &"mech_assemble", Step.BOARD_LOADER: &"board_loader",
	Step.DRIVE: &"drive", Step.DOCK_COLOSSUS: &"dock_colossus",
}
const IFRAME_MS: float = 400.0
const APPROACH_AHEAD_M: float = 15.8       # robot_scale_test.md: dock_approach is 15.8 m in front of the colossus

var host: Node3D = null
var stage: RobotStage = null
var player: ActionPlayer = null
var cfg: Dictionary = {}
var kasp: Node3D = null
var mech: Node3D = null
## Off in tests that step it by hand with tick().
var run_on_physics: bool = true
var step: Step = Step.IDLE

var _t: float = 0.0
var _poured: Dictionary = {}
var _kasp_stand_in: Node3D = null
var _cage: Node3D = null
var _mech_stand_in: Node3D = null
var _road: Array[Vector3] = []
var _road_len: float = 0.0
var _road_dist: float = 0.0
var _colossus_from: Vector3 = Vector3.ZERO
var _colossus_to: Vector3 = Vector3.ZERO
var _colossus_t: float = 0.0
var _dock_wait_s: float = 0.0
var _dock_started: bool = false
var _kasp_a: Vector3 = Vector3.ZERO
var _kasp_b: Vector3 = Vector3.ZERO
var _kasp_c: Vector3 = Vector3.ZERO


## Adds itself to an ActionRoom's arena: the room's stage, hero and the data file.
func bind(room: Node) -> bool:
	var found: Node = room.call("get_robot_stage") as Node if room.has_method("get_robot_stage") else null
	return setup(room as Node3D, found as RobotStage, room.call("get_player") as ActionPlayer, DataDB.get_dict(DATA_ID))


func setup(for_host: Node3D, for_stage: RobotStage, for_player: ActionPlayer, for_cfg: Dictionary) -> bool:
	if for_host == null or for_stage == null or for_player == null or for_stage.yard == null:
		return false
	host = for_host
	stage = for_stage
	player = for_player
	cfg = for_cfg
	add_to_group(GROUP)
	set_physics_process(run_on_physics)
	return true


func _physics_process(delta: float) -> void:
	tick(delta)


# ---- the BossFight's calls ----

## Starts the sequence. False if it is already running, or Red is not on foot with a loader and a colossus in the room.
func begin() -> bool:
	if step != Step.IDLE and step != Step.DONE:
		return false
	if stage == null or stage.form() != &"red" or stage.yard.small_display == null or stage.yard.huge_display == null:
		push_warning("BossTransition: needs Red on foot and a loader and a colossus in the robot room")
		return false
	_poured.clear()
	_enter(Step.KASP_ESCAPE)
	return true


## A phase-2 retry: Red is already the colossus at its dock spot, the Heap stands, Kasp is in the cab, the gate is open. No
## sequence plays and `finished` is not emitted (the caller starts phase 2 itself). False if she is not in the colossus.
func start_docked() -> bool:
	if stage == null or stage.form() != &"huge":
		if stage == null or not stage.place_in(&"huge"):
			return false
	var huge: RobotDisplay = stage.yard.huge_display
	var dock_at: Node3D = _marker("dock_pos")
	if huge != null and dock_at != null:
		huge.global_position = dock_at.global_position
	_hide_kasp()
	_set_assemble(1.0)
	_open_gate()
	step = Step.DONE
	return true


func is_running() -> bool:
	return step != Step.IDLE and step != Step.DONE


func is_done() -> bool:
	return step == Step.DONE


func step_name() -> StringName:
	return STEP_NAMES.get(step, &"")


## Jumps the scripted ring-road drive to its end (a skip button).
func skip_drive() -> void:
	if step == Step.DRIVE:
		_road_dist = _road_len
		_colossus_t = 1.0


# ---- the clock ----

func tick(delta: float) -> void:
	if not is_running() or player == null or stage == null:
		return
	if bool(cfg.get("invulnerable", true)):
		player.grant_iframes(IFRAME_MS)
	_t += delta
	match step:
		Step.KASP_ESCAPE:
			_tick_kasp()
		Step.MECH_ASSEMBLE:
			_tick_assemble()
		Step.BOARD_LOADER:
			_tick_board()
		Step.DRIVE:
			_tick_drive(delta)
		Step.DOCK_COLOSSUS:
			_tick_dock(delta)


func _enter(next: Step) -> void:
	if step != Step.IDLE and step != Step.DONE and STEP_NAMES.has(step):
		step_finished.emit(STEP_NAMES[step])
	step = next
	_t = 0.0
	match next:
		Step.KASP_ESCAPE:
			_start_kasp()
		Step.MECH_ASSEMBLE:
			_start_assemble()
		Step.BOARD_LOADER:
			_start_board()
		Step.DRIVE:
			_start_drive()
		Step.DOCK_COLOSSUS:
			_start_dock()
		Step.DONE:
			return
	if STEP_NAMES.has(next):
		step_started.emit(STEP_NAMES[next])


func _finish() -> void:
	step_finished.emit(STEP_NAMES[Step.DOCK_COLOSSUS])
	step = Step.DONE
	finished.emit()


# ---- 1. Kasp escapes ----

func _kasp_cfg() -> Dictionary:
	return cfg.get("kasp_escape", {}) as Dictionary


func kasp_duration_s() -> float:
	var k: Dictionary = _kasp_cfg()
	return float(k.get("throw_s", 0.8)) + float(k.get("run_s", 1.7)) + float(k.get("lift_s", 1.5))


func _start_kasp() -> void:
	var k: Dictionary = _kasp_cfg()
	var rig: Node3D = _marker("rig_start")
	var base: Vector3 = rig.global_position if rig != null else Vector3.ZERO
	_kasp_a = base + HackTarget.vec3(k.get("seat_offset_m", null), Vector3(4.0, 2.5, -3.0))
	_kasp_b = Vector3(_kasp_a.x, base.y, _kasp_a.z) + HackTarget.vec3(k.get("throw_land_offset_m", null), Vector3(2.0, 0.0, -2.0))
	var escape: Node3D = _marker("kasp_target")
	_kasp_c = escape.global_position if escape != null else base + Vector3(0.0, 0.0, -19.0)
	if kasp == null:
		_kasp_stand_in = _stand_in_figure("KaspStandIn", Vector3(0.7, 1.6, 0.7), Color(0.9, 0.6, 0.2))
		kasp = _kasp_stand_in
	kasp.visible = true
	kasp.global_position = _kasp_a
	_cage = _stand_in_figure("CraneCage", Vector3(2.0, 0.2, 2.0), Color(0.4, 0.42, 0.45))
	_cage.visible = false
	_say(k.get("memo", {}) as Dictionary)


func _tick_kasp() -> void:
	var k: Dictionary = _kasp_cfg()
	var throw_s: float = maxf(float(k.get("throw_s", 0.8)), 0.01)
	var run_s: float = maxf(float(k.get("run_s", 1.7)), 0.01)
	var lift_s: float = maxf(float(k.get("lift_s", 1.5)), 0.01)
	var height: float = float(k.get("lift_height_m", 45.0))
	if _t < throw_s:
		var p: float = _t / throw_s
		var at: Vector3 = _kasp_a.lerp(_kasp_b, p)
		at.y = lerpf(_kasp_a.y, _kasp_b.y, p * p) + 4.0 * 1.2 * p * (1.0 - p)       # a short arc, then down
		kasp.global_position = at
	elif _t < throw_s + run_s:
		var p2: float = (_t - throw_s) / run_s
		kasp.global_position = _kasp_b.lerp(_kasp_c, ScaleProfile.smooth(p2))
		_cage.visible = true
		_cage.global_position = _kasp_c + Vector3.UP * (height * (1.0 - p2))             # the cage comes down to meet him
	elif _t < throw_s + run_s + lift_s:
		var p3: float = (_t - throw_s - run_s) / lift_s
		var up: float = height * ScaleProfile.smooth(p3)
		kasp.global_position = _kasp_c + Vector3.UP * up
		_cage.global_position = kasp.global_position
	else:
		_hide_kasp()
		_enter(Step.MECH_ASSEMBLE)


func _hide_kasp() -> void:
	if kasp != null and is_instance_valid(kasp):
		kasp.visible = false                   # he is in the Heap's cab now
	if _cage != null and is_instance_valid(_cage):
		_cage.visible = false


# ---- 2. the cranes pour, the Heap rises ----

func _assemble_cfg() -> Dictionary:
	return cfg.get("mech_assemble", {}) as Dictionary


func _start_assemble() -> void:
	_say(_assemble_cfg().get("bark", {}) as Dictionary)
	if mech == null and _mech_stand_in == null:
		var size: Vector3 = HackTarget.vec3(_assemble_cfg().get("placeholder_size_m", null), Vector3(26.0, 40.0, 18.0))
		_mech_stand_in = _stand_in_figure("HeapStandIn", Vector3.ONE, Color(0.45, 0.32, 0.22))
		_mech_stand_in.set_meta(&"full_size", size)
		var at: Node3D = _marker("mech_start")
		_mech_stand_in.global_position = at.global_position if at != null else Vector3(0.0, 0.0, -110.0)
	_set_assemble(0.0)


func _tick_assemble() -> void:
	var duration: float = maxf(float(_assemble_cfg().get("duration_s", 8.0)), 0.01)
	var pours: Array = _assemble_cfg().get("pours_at_s", []) as Array
	var cranes: Array = (cfg.get("markers", {}) as Dictionary).get("cranes", []) as Array
	for i: int in mini(pours.size(), cranes.size()):
		var id: StringName = StringName(str(cranes[i]))
		if _t >= float(pours[i]) and not _poured.has(id):
			_poured[id] = true
			crane_poured.emit(id)
			if i == 0 and stage.controller != null and stage.effects_enabled:
				stage.controller.play_shake(StringName(str(_assemble_cfg().get("shake", "land_small"))))
	var p: float = clampf(_t / duration, 0.0, 1.0)
	_set_assemble(p)
	if _t >= duration:
		_open_gate()
		_enter(Step.BOARD_LOADER)


func _set_assemble(p: float) -> void:
	if mech != null and is_instance_valid(mech) and mech.has_method(&"set_assemble_progress"):
		mech.call(&"set_assemble_progress", p)
	if _mech_stand_in != null and is_instance_valid(_mech_stand_in):
		var full: Vector3 = _mech_stand_in.get_meta(&"full_size", Vector3.ONE) as Vector3
		var shape: float = ScaleProfile.ease_out(p)
		_mech_stand_in.scale = Vector3(lerpf(0.2, 1.0, shape), maxf(shape, 0.02), lerpf(0.2, 1.0, shape)) * full
		_mech_stand_in.visible = p > 0.0


## Crane B lifts the stockade's east barricade away: the node vanishes and stops blocking.
func _open_gate() -> void:
	var gate: Node3D = _marker("gate")
	if gate == null:
		return
	if gate.has_method(&"open"):
		gate.call(&"open")
		return
	gate.visible = false
	for shape: Node in gate.find_children("*", "CollisionShape3D", true, false):
		(shape as CollisionShape3D).set_deferred("disabled", true)


# ---- 3. Red runs to the loader and boards ----

func _start_board() -> void:
	stage.wake()
	stage.boarding.boarding_enabled = true
	var loader: RobotDisplay = stage.yard.small_display
	var spot: Node3D = _marker("loader")
	var snap_m: float = float((cfg.get("board_loader", {}) as Dictionary).get("snap_loader_if_farther_m", 0.75))
	if spot != null:
		loader.set_active(true)
		if loader.global_position.distance_to(spot.global_position) > snap_m:
			loader.global_transform = Transform3D(Basis.from_euler(Vector3(0.0, spot.global_rotation.y, 0.0)), spot.global_position)


func _tick_board() -> void:
	if stage.form() == &"small" and stage.mode() == RobotBoarding.Mode.SMALL:
		_enter(Step.DRIVE)


# ---- 4. the ring road, the colossus wakes ----

func _start_drive() -> void:
	var approach: Vector3 = _approach_point()
	_road = [player.global_position]
	for point: Vector3 in _road_points():
		_road.append(point)
	_road.append(approach)
	_road_len = 0.0
	for i: int in range(1, _road.size()):
		_road_len += _road[i - 1].distance_to(_road[i])
	_road_dist = 0.0
	var huge: RobotDisplay = stage.yard.huge_display
	huge.set_active(true)
	_colossus_from = huge.global_position
	var dock_at: Node3D = _marker("dock_pos")
	_colossus_to = dock_at.global_position if dock_at != null else _colossus_from
	_colossus_t = 0.0
	huge.play(&"walk", 0.5)
	player.set_move_input(Vector2.ZERO)
	player.set_control_mode(ActionPlayer.ControlMode.SCRIPTED)


func _tick_drive(delta: float) -> void:
	var drive: Dictionary = cfg.get("drive", {}) as Dictionary
	var speed: float = float(drive.get("speed_mps", 11.0))
	var minimum_s: float = float(drive.get("min_s", 3.0))
	if _road_len > 0.0 and minimum_s > 0.0 and _road_len / maxf(speed, 0.01) < minimum_s:
		speed = _road_len / minimum_s                    # a short road is still driven, not teleported
	_road_dist = minf(_road_dist + speed * delta, _road_len)
	var at: Vector3 = _point_on_road(_road_dist)
	var ahead: Vector3 = _point_on_road(minf(_road_dist + 0.5, _road_len))
	var flat: Vector3 = Vector3(ahead.x - at.x, 0.0, ahead.z - at.z)
	player.global_position = at
	if flat.length() > 0.01:
		player.rotation.y = RobotDisplay.yaw_of(flat)
	player.play_scripted_clip(&"run", 1.0)
	var step_s: float = maxf(float(drive.get("colossus_step_s", 3.5)), 0.01)
	_colossus_t = minf(_colossus_t + delta / step_s, 1.0)
	var huge: RobotDisplay = stage.yard.huge_display
	huge.global_position = _colossus_from.lerp(_colossus_to, ScaleProfile.smooth(_colossus_t))
	if _colossus_t >= 1.0:
		huge.play(&"idle")
	if _road_dist >= _road_len and _colossus_t >= 1.0:
		_enter(Step.DOCK_COLOSSUS)


func _point_on_road(distance: float) -> Vector3:
	var left: float = distance
	for i: int in range(1, _road.size()):
		var leg: float = _road[i - 1].distance_to(_road[i])
		if left <= leg and leg > 0.0:
			return _road[i - 1].lerp(_road[i], left / leg)
		left -= leg
	return _road[_road.size() - 1] if not _road.is_empty() else player.global_position


## The ring road's waypoints: the children of the `ring_road` node in order, else markers ring_road_1, ring_road_2 ...
func _road_points() -> Array[Vector3]:
	var out: Array[Vector3] = []
	var road: Node3D = _marker("ring_road")
	if road != null:
		for child: Node in road.get_children():
			if child is Node3D:
				out.append((child as Node3D).global_position)
		if not out.is_empty():
			return out
	var name_base: String = str((cfg.get("markers", {}) as Dictionary).get("ring_road", "ring_road"))
	for i: int in range(1, 20):
		var point: Node3D = host.find_child("%s_%d" % [name_base, i], true, false) as Node3D
		if point == null:
			break
		out.append(point.global_position)
	return out


## Where the loader stops to dock: the scene's dock_approach marker, else 15.8 m in front of the colossus's dock spot.
func _approach_point() -> Vector3:
	var marker: Node3D = _marker("dock_approach")
	if marker != null:
		return Vector3(marker.global_position.x, 0.0, marker.global_position.z)
	var huge: RobotDisplay = stage.yard.huge_display
	var dock_at: Node3D = _marker("dock_pos")
	var at: Vector3 = dock_at.global_position if dock_at != null else huge.global_position
	return Vector3(at.x, 0.0, at.z) + huge.facing() * APPROACH_AHEAD_M


# ---- 5. the docking ----

func _start_dock() -> void:
	_dock_wait_s = 0.0
	_dock_started = false
	var approach: Vector3 = _approach_point()
	player.global_position = Vector3(approach.x, player.global_position.y, approach.z)
	player.set_control_mode(ActionPlayer.ControlMode.NORMAL)
	player.velocity = Vector3.ZERO


func _tick_dock(delta: float) -> void:
	if stage.mode() == RobotBoarding.Mode.HUGE and stage.form() == &"huge":
		_finish()
		return
	if _dock_started:
		return
	if stage.mode() == RobotBoarding.Mode.DOCKING:          # the boarding's own dock ring already started it
		_dock_started = true
		return
	if stage.dock():
		_dock_started = true
		return
	_dock_wait_s += delta
	var timeout: float = float((cfg.get("dock", {}) as Dictionary).get("start_timeout_s", 3.0))
	if _dock_wait_s >= timeout:
		# she never came to rest on the ground: do not strand the fight, put her in the colossus without the show
		push_warning("BossTransition: the docking would not start; placing Red in the colossus")
		stage.place_in(&"huge")
		_dock_started = true


# ---- helpers ----

## A node by its role in data/slice/boss_transition.json `markers`.
func _marker(role: String) -> Node3D:
	if host == null:
		return null
	var wanted: Variant = (cfg.get("markers", {}) as Dictionary).get(role, role)
	if wanted is Array:
		return null
	return host.find_child(str(wanted), true, false) as Node3D


func _stand_in_figure(node_name: String, size: Vector3, color: Color) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = node_name
	var mesh: MeshInstance3D = PropLook.box(size, PropLook.lit(color), "Body")
	mesh.position.y = size.y * 0.5
	root.add_child(mesh)
	host.add_child(root)
	return root


func _say(line: Dictionary) -> void:
	if line.is_empty():
		return
	var speaker: String = str(line.get("speaker", ""))
	var text: String = str(line.get("text", ""))
	radio_said.emit(speaker, text)
	var hud: Node = host.call("get_hud") as Node if host != null and host.has_method("get_hud") else null
	if hud != null and hud.has_method("radio_say"):
		hud.call("radio_say", speaker, text)
