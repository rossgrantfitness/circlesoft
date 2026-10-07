class_name Main
extends Node
## The game's root scene. Holds the PSX screen and runs the demo flow:
##   title screen  --start_demo_requested-->  the test room (in the PSX world)
##   Esc / Start in the room  -->  back to the title screen
##   an enemy's Fight!  -->  start_battle(): the room waits in memory, the battle takes the world,
##   and a win or a run puts the room back exactly as it was (a loss offers Retry or the title)
## The title screen is a scene at TITLE_SCENE_PATH whose root has a `start_demo_requested` signal.
## If that scene is not there yet (or show_title is off), the room loads straight away.
## The F-key PSX debug overlay is added to the sharp UI layer.

enum State { NONE, TITLE, ROOM, BATTLE }

const TITLE_SCENE_PATH: String = "res://scenes/ui/title_screen.tscn"
const START_SIGNAL: StringName = &"start_demo_requested"
const BACK_ACTION: StringName = &"start"
const BATTLE_SCENE_PATH: String = "res://scenes/battle/battle_scene.tscn"
const BATTLE_TEST_SIGNAL: StringName = &"battle_test_requested"
## The title's Continue row emits this (UI-B adds it); Main loads the newest save.
const CONTINUE_SIGNAL: StringName = &"continue_requested"
const PATH_SAVE_MANAGER: NodePath = ^"/root/SaveManager"
const DEFAULT_SPAWN: String = "PlayerSpawn"
const ROOM_BATTLE_SIGNAL: StringName = &"battle_requested"
const FIELD_BATTLE_SIGNAL: StringName = &"field_battle_requested"
const ENTRY_SPAWN_PROPERTY: StringName = &"entry_spawn"
const RETURN_TO_ROOM: StringName = &"room"
const RETURN_TO_TITLE: StringName = &"title"
const FIRST_TURN_NORMAL: String = "normal"
const RESULT_WIN: String = "win"
const RESULT_RAN: String = "ran"
const RESULT_LOSE: String = "lose"
const CHOICE_RETRY: String = "retry"
const GROUP: StringName = &"main_flow"

## A battle is over and the game is back where it came from (the room or the title). `report` is the
## battle's report; for a retry this is not sent until the retried fight ends.
signal battle_finished(result: String, report: Dictionary)

## The room the demo starts in.
@export var start_scene: PackedScene
## Where the title screen scene lives. Tests point this at a stand-in.
@export var title_scene_path: String = TITLE_SCENE_PATH
## Turn off to go straight into the room (visual capture scripts do this).
@export var show_title: bool = true
@export var debug_overlay_enabled: bool = true

var overlay: PsxDebugOverlay = null
## GameState and Config to use. Null means the autoloads. Tests pass their own.
var game_state: Node = null
var config: Node = null
## Off in tests: skips the radio-static transitions of the battle stage.
var battle_transitions: bool = true
## Called with every BattleSetup just before the fight starts: func(setup: BattleSetup) -> void.
## Tests use it to switch to a virtual clock, Auto-Timing and a scripted command source.
var battle_setup_hook: Callable = Callable()

var _state: State = State.NONE
var _title: Node = null
var _state_frame: int = -1
var _room: Node = null
var _kept_world: Array[Node] = []
var _battle: Node = null
var _battle_snapshot: Dictionary = {}
var _battle_encounter: String = ""
var _battle_return: StringName = RETURN_TO_ROOM
var _battle_first_turn: String = FIRST_TURN_NORMAL

@onready var screen: PsxScreen = $PsxScreen


func _ready() -> void:
	add_to_group(GROUP)
	if debug_overlay_enabled:
		overlay = PsxDebugOverlay.new()
		overlay.name = "PsxDebugOverlay"
		screen.get_ui_layer().add_child(overlay)
	if show_title and ResourceLoader.exists(title_scene_path):
		go_to_title()
	else:
		start_demo()


func _process(_delta: float) -> void:
	# Ignore the frame a state began on, so the same Enter press that started the demo can't
	# also send us back. (Nodes in the SubViewport get no input events, so poll here.)
	if _state == State.ROOM and Engine.get_process_frames() > _state_frame \
			and not UiStage.is_busy(get_tree()) and Input.is_action_just_pressed(BACK_ACTION):
		go_to_title()


func get_state() -> State:
	return _state


func get_title() -> Node:
	return _title


## The room that is playing (or waiting in memory during a battle). Null on the title screen.
func get_room() -> Node:
	return _room


## The battle stage while a fight is on, else null.
func get_battle() -> Node:
	return _battle


## Shows the title screen (or, with no title scene, reloads the room).
func go_to_title() -> void:
	_set_playing(false)
	_free_battle()
	_free_kept_room()
	screen.clear_world()
	_room = null
	_free_title()
	var scene: PackedScene = load(title_scene_path) as PackedScene if ResourceLoader.exists(title_scene_path) else null
	if scene == null:
		start_demo()
		return
	_title = scene.instantiate()
	screen.get_ui_layer().add_child(_title)
	if _title.has_signal(START_SIGNAL):
		_title.connect(START_SIGNAL, start_new_game)
	else:
		push_error("Main: the title screen has no %s signal" % START_SIGNAL)
	if _title.has_signal(BATTLE_TEST_SIGNAL):
		_title.connect(BATTLE_TEST_SIGNAL, _on_battle_test_requested)
	if _title.has_signal(CONTINUE_SIGNAL):
		_title.connect(CONTINUE_SIGNAL, continue_game)
	_set_state(State.TITLE)


## New Game from the title: a fresh GameState, then the room.
func start_new_game() -> void:
	var state: Node = _game_state()
	if state != null:
		state.call("reset")
	start_demo()


## Continue from the title: loads the newest save (manual or auto) into GameState, starts the room
## and puts Red on the spawn marker the save names. False (and nothing changes) when there is no save.
func continue_game() -> bool:
	var manager: Node = _save_manager()
	if manager == null or not bool(manager.call("continue_game")):
		return false
	start_demo()
	_place_player_at_saved_spawn()
	return true


## True when the title may offer Continue.
func can_continue() -> bool:
	var manager: Node = _save_manager()
	return manager != null and bool(manager.call("has_any_save"))


func _place_player_at_saved_spawn() -> void:
	var state: Node = _game_state()
	if state == null or _room == null or not is_instance_valid(_room):
		return
	var spawn_name: String = str((state.call("get_location") as Dictionary).get("spawn", ""))
	if spawn_name.is_empty() or spawn_name == DEFAULT_SPAWN:
		return
	var spawn: Node3D = _room.get_node_or_null(spawn_name) as Node3D
	var red: Node3D = _room.get("player") as Node3D
	if spawn == null or red == null:
		return
	red.global_transform = Transform3D(red.global_transform.basis, spawn.global_position)
	if red.has_method("reset_ground_height"):
		red.call("reset_ground_height")
	var rig: Node = _room.get("camera_rig") as Node
	if rig != null and rig.has_method("snap_to_target"):
		rig.call("snap_to_target")


## Loads the room into the PSX world and removes the title.
func start_demo() -> void:
	_set_playing(true)
	_free_title()
	_free_battle()
	_free_kept_room()
	_room = null
	if start_scene != null:
		_room = screen.load_world(start_scene)
		_connect_room(_room)
	_set_state(State.ROOM)


## Swaps the room for another scene while the game is in the field (the SceneRouter calls this
## after its fade to black). `spawn_id` names the spawn marker Red starts on. The old room is freed;
## returns the new one. Does nothing during a battle.
func enter_room(scene: PackedScene, spawn_id: String = "") -> Node:
	if scene == null or _state == State.BATTLE:
		return null
	_free_title()
	_free_kept_room()
	var room: Node = scene.instantiate()
	if not spawn_id.is_empty() and ENTRY_SPAWN_PROPERTY in room:
		room.set(ENTRY_SPAWN_PROPERTY, spawn_id)
	screen.clear_world()
	screen.get_world_root().add_child(room)
	_room = room
	_connect_room(room)
	_set_state(State.ROOM)
	return room


func _connect_room(room: Node) -> void:
	if room == null:
		return
	if room.has_signal(ROOM_BATTLE_SIGNAL):
		room.connect(ROOM_BATTLE_SIGNAL, _on_room_battle_requested)
	if room.has_signal(FIELD_BATTLE_SIGNAL):
		room.connect(FIELD_BATTLE_SIGNAL, _on_field_battle_requested)


func _free_title() -> void:
	if _title != null and is_instance_valid(_title):
		_title.get_parent().remove_child(_title)
		_title.queue_free()
	_title = null


func _set_state(new_state: State) -> void:
	_state = new_state
	_state_frame = Engine.get_process_frames()
	var manager: Node = _save_manager()
	if manager != null:
		manager.set("battle_active", new_state == State.BATTLE)


## Play time ticks only while a run is on (not on the title).
func _set_playing(on: bool) -> void:
	var state: Node = _game_state()
	if state != null:
		state.set("playing", on)


# ---- battles ----

## Starts a fight. From the room, the room is detached and kept in memory and comes back when the
## fight is won or run from; from the title (return_to = &"title") the title comes back. The
## GameState is snapshotted first, so a lost fight can be retried from exactly this moment.
## first_turn: "normal", "party" (free first turn) or "enemies" (ambushed).
func start_battle(encounter_id: String, return_to: StringName = RETURN_TO_ROOM, first_turn: String = FIRST_TURN_NORMAL) -> void:
	if _state == State.BATTLE:
		return
	var state: Node = _game_state()
	_battle_snapshot = state.call("snapshot") as Dictionary if state != null else {}
	_battle_encounter = encounter_id
	_battle_first_turn = first_turn
	_battle_return = return_to
	if _state == State.ROOM and _room != null and is_instance_valid(_room):
		if _room.has_method("suspend"):
			_room.call("suspend")
		_kept_world = screen.detach_world()
	else:
		# Not in a room (the title's Battle Test): nothing to keep, and the title is where we go back to.
		_battle_return = RETURN_TO_TITLE
		_room = null
		_free_title()
		screen.clear_world()
	_launch_battle()


func _launch_battle() -> void:
	var scene: PackedScene = load(BATTLE_SCENE_PATH) as PackedScene
	if scene == null:
		push_error("Main: no battle scene at %s" % BATTLE_SCENE_PATH)
		_leave_battle(RESULT_RAN, {})
		return
	_battle = screen.load_world(scene)
	_battle.set("transitions_enabled", battle_transitions)
	_battle.connect("finished", _on_battle_scene_finished)
	var setup: BattleSetup = BattleSetup.from_game_state(_game_state(), _battle_encounter, _config(), _battle_first_turn)
	if battle_setup_hook.is_valid():
		battle_setup_hook.call(setup)
	_set_state(State.BATTLE)
	_battle.call("start_battle", setup)


func _on_battle_scene_finished(result: String, report: Dictionary) -> void:
	var choice: String = str(report.get("choice", ""))
	if choice.is_empty() and _battle != null:
		choice = str(_battle.get("hud_choice"))
	if result == RESULT_LOSE:
		if choice == CHOICE_RETRY:
			_retry_battle.call_deferred()
		else:
			_end_battle.call_deferred(result, report, RETURN_TO_TITLE)
		return
	_end_battle.call_deferred(result, report, _battle_return)


## Retry: the GameState goes back to the snapshot taken before the fight (play time keeps running
## forward) and the same encounter starts again. Nothing is written to a save slot.
func _retry_battle() -> void:
	var state: Node = _game_state()
	if state != null:
		state.call("restore_snapshot", _battle_snapshot)
	_launch_battle()


func _end_battle(result: String, report: Dictionary, go_to: StringName) -> void:
	if go_to == RETURN_TO_ROOM and not _kept_world.is_empty():
		_leave_battle(result, report)
	else:
		go_to_title()
		battle_finished.emit(result, report)


## Back to the room exactly as it was: the stage goes, the kept world comes back.
func _leave_battle(result: String, report: Dictionary) -> void:
	_battle = null
	screen.clear_world()
	screen.attach_world(_kept_world)
	_kept_world = []
	_set_state(State.ROOM)
	if _room != null and is_instance_valid(_room):
		if _room.has_method("resume"):
			_room.call("resume")
		if _room.has_method("battle_finished"):
			_room.call("battle_finished", result, report)
	battle_finished.emit(result, report)


func _on_room_battle_requested(encounter_id: String, _fight_id: String) -> void:
	start_battle.call_deferred(encounter_id, RETURN_TO_ROOM, FIRST_TURN_NORMAL)


## A map enemy caught Red: the fight starts with the first-turn rule worked out from who faced whom.
func _on_field_battle_requested(encounter_id: String, _enemy_id: String, first_turn: String) -> void:
	start_battle.call_deferred(encounter_id, RETURN_TO_ROOM, first_turn)


func _on_battle_test_requested(encounter_id: String) -> void:
	start_battle.call_deferred(encounter_id, RETURN_TO_TITLE, FIRST_TURN_NORMAL)


## Drops a battle stage that is still up (going to the title in the middle of one).
func _free_battle() -> void:
	_battle = null


## Frees a room that was waiting in memory: takes its UI down first (it is not in the tree, so
## its own cleanup did not run).
func _free_kept_room() -> void:
	for node: Node in _kept_world:
		if is_instance_valid(node):
			if node.has_method("teardown"):
				node.call("teardown")
			node.free()
	_kept_world = []


func _game_state() -> Node:
	return game_state if game_state != null else get_node_or_null("/root/GameState")


func _save_manager() -> Node:
	return get_node_or_null(PATH_SAVE_MANAGER)


func _config() -> Node:
	return config if config != null else get_node_or_null("/root/Config")
