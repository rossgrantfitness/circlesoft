class_name RobotStage
extends Node
## The robots of one slice room (docs/slice/slice_tech_plan.md 2.2, 2.3, 5.3; task VS-21). It reads
## data/slice/robot_rooms/<id>.json (the room's entry in rooms.json names the id in `robots`) and builds what the sandbox's robot
## zone builds, with the same CS-21 code and the same scale_profiles.json numbers: RobotYard (the loader and/or the colossus
## standing where the data says, plus smashable props), ScaleController (camera, haze, shadows, shake and sound per body size) and
## RobotBoarding (boarding, docking, climbing out). Nothing in those three is copied.
##
## What a level designer or a script can do with it:
##   * board()              start the boarding sequence now (a hack or a script woke the loader)
##   * wake()               a sleeping loader (robot data `wake_flag`) becomes boardable by walking into its ring
##   * wake_and_board()     both; the J4 wake button (HackLoader) calls this
##   * place_in(form)       start the room already inside a robot (`small` or `huge`), no sequence: J5 and the boss arena
##   * dock()               the loader walks to the colossus and docks (the boss transition)
##   * disembark()          climb out (the arena gate)
## The hero's hacks are off in robot forms (ActionPlayer, tech plan 5.3); the stage only reports the form (`form_changed`).
## Saving is blocked by ActionRoom in rooms that name robots. Robot rooms are not save points.
##
## robot_rooms/<id>.json: `ground` false (the level supplies the floor), `small_robot` {pos, yaw_deg, wake_flag}, `huge_robot`
## {pos, yaw_deg}, `props` [{kind, pos, yaw_deg}] (kinds come from combat/robot_yard.json unless the file has its own `kinds`),
## and `city` as in the test yard. Positions are in the level's own coordinates (a map's metres).

signal form_changed(form_id: StringName)
signal woke
signal boarding_started

const GROUP: StringName = &"robot_stage"
const DATA_PREFIX: String = "slice/robot_rooms/"

var host: Node3D = null
var player: ActionPlayer = null
var data: Dictionary = {}
var yard: RobotYard = null
var controller: ScaleController = null
var boarding: RobotBoarding = null
## GameState to keep the wake flag in. Null means the autoload.
var game_state: Node = null
## Tests turn these off before setup(): no audio, no dust nodes, no Input reads.
var effects_enabled: bool = true
var read_engine_input: bool = true
var wake_flag: String = ""

var _woke_local: bool = false


## Builds the stage for an ActionRoom (or anything with get_entry(), get_player(), get_camera(), get_lock_on()). False if the room
## names no robot data or the file is empty.
func bind(room: Node) -> bool:
	var entry: Dictionary = room.call("get_entry") as Dictionary if room.has_method("get_entry") else {}
	var id: String = str(entry.get("robots", ""))
	if id.is_empty():
		return false
	var doc: Dictionary = DataDB.get_dict(DATA_PREFIX + id)
	return setup(room as Node3D, room.call("get_player") as ActionPlayer, room.call("get_camera") as OrbitCamera,
			room.call("get_lock_on") as LockOn, doc)


## Builds the stage from a data dictionary (the same shape as a robot_rooms file). Tests call this with a plain Node3D host.
func setup(for_host: Node3D, for_player: ActionPlayer, for_camera: OrbitCamera, for_lock: LockOn, for_data: Dictionary) -> bool:
	if for_host == null or for_player == null or for_data.is_empty():
		return false
	host = for_host
	player = for_player
	data = for_data
	add_to_group(GROUP)
	yard = RobotYard.new()
	yard.name = "RobotYard"
	host.add_child(yard)
	yard.build(host, data)
	for entry: String in yard.missing:
		push_warning("RobotStage: %s" % entry)
	controller = ScaleController.new()
	controller.name = "ScaleController"
	controller.effects_enabled = effects_enabled
	controller.audio_enabled = effects_enabled
	add_child(controller)
	controller.bind(host, player, for_camera, for_lock, yard)
	controller.form_changed.connect(_on_form_changed)
	boarding = RobotBoarding.new()
	boarding.name = "RobotBoarding"
	boarding.effects_enabled = effects_enabled
	boarding.read_engine_input = read_engine_input
	add_child(boarding)
	boarding.bind(host, player, for_camera, controller, yard)
	boarding.mode_changed.connect(_on_mode_changed)
	wake_flag = str((data.get("small_robot", {}) as Dictionary).get("wake_flag", ""))
	boarding.boarding_enabled = is_awake()
	_refresh_hack_targets()
	return true


## Hack targets (the J4 loader's wake button) are built before the stage joins its group, and decided then that no stage exists.
## Tell them to look again now that it does (bug B9).
func _refresh_hack_targets() -> void:
	if not is_inside_tree():
		return
	for node: Node in get_tree().get_nodes_in_group(HackTarget.GROUP_TARGET_NODES):
		if node is HackTarget:
			(node as HackTarget).refresh()


# ---- the loader's sleep ----

## False while a loader with a `wake_flag` has not been woken (this run, or in a save).
func is_awake() -> bool:
	if wake_flag.is_empty() or _woke_local:
		return true
	return WorldProgress.has_flag(wake_flag, game_state)


## Wakes a sleeping loader: it can be boarded by walking into its ring, and the flag is saved. False if it was already awake.
func wake() -> bool:
	if is_awake():
		return false
	_woke_local = true
	WorldProgress.set_flag(wake_flag, game_state)
	if boarding != null:
		boarding.boarding_enabled = true
	woke.emit()
	return true


# ---- scripted starts ----

## Starts the boarding sequence now. Wakes the loader first if it sleeps. False if she is not free to climb in right now.
func board() -> bool:
	if boarding == null:
		return false
	wake()
	return boarding.board_now()


## The J4 wake button: wakes the loader and starts the boarding. True if it woke or boarding began; if she was mid-swing the
## loader is awake anyway and she can walk into the ring.
func wake_and_board() -> bool:
	if boarding == null:
		return false
	var woken: bool = wake()
	var started: bool = boarding.board_now()
	return woken or started


## The room starts with her already in a robot (`small` or `huge`; `red` puts her on foot). No sequence: her body, camera, haze and
## sound are the form's at once and the robot's display is hidden because she is wearing it.
func place_in(form: StringName) -> bool:
	if boarding == null:
		return false
	return boarding.place_in(form)


## The loader walks to the colossus and docks (the boss transition). Needs `huge_robot` in the data and her in the loader.
func dock() -> bool:
	return boarding != null and boarding.dock_now()


## Climbs out of the robot (needs her nearly still, like the button). The arena gate calls this.
func disembark() -> void:
	if boarding != null:
		boarding.request_disembark()


# ---- reading ----

## Red, small or huge: the body she has now.
func form() -> StringName:
	return controller.form_id() if controller != null else &"red"


func mode() -> RobotBoarding.Mode:
	return boarding.get_mode() if boarding != null else RobotBoarding.Mode.RED


func is_in_robot() -> bool:
	return form() != &"red"


## Everything back to the start of the room (the pause menu's reset): Red on foot, robots home, props standing.
func reset() -> void:
	if boarding != null:
		boarding.reset()


func _on_form_changed(form_id: StringName) -> void:
	form_changed.emit(form_id)


func _on_mode_changed(new_mode: RobotBoarding.Mode) -> void:
	if new_mode == RobotBoarding.Mode.BOARDING:
		boarding_started.emit()
