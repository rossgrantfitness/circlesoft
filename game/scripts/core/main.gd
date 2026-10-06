class_name Main
extends Node
## The game's root scene. Holds the PSX screen and runs the demo flow:
##   title screen  --start_demo_requested-->  the test room (in the PSX world)
##   Esc / Start in the room  -->  back to the title screen
## The title screen is a scene at TITLE_SCENE_PATH whose root has a `start_demo_requested` signal.
## If that scene is not there yet (or show_title is off), the room loads straight away.
## The F-key PSX debug overlay is added to the sharp UI layer.

enum State { NONE, TITLE, ROOM }

const TITLE_SCENE_PATH: String = "res://scenes/ui/title_screen.tscn"
const START_SIGNAL: StringName = &"start_demo_requested"
const BACK_ACTION: StringName = &"start"

## The room the demo starts in.
@export var start_scene: PackedScene
## Where the title screen scene lives. Tests point this at a stand-in.
@export var title_scene_path: String = TITLE_SCENE_PATH
## Turn off to go straight into the room (visual capture scripts do this).
@export var show_title: bool = true
@export var debug_overlay_enabled: bool = true

var overlay: PsxDebugOverlay = null

var _state: State = State.NONE
var _title: Node = null
var _state_frame: int = -1

@onready var screen: PsxScreen = $PsxScreen


func _ready() -> void:
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


## Shows the title screen (or, with no title scene, reloads the room).
func go_to_title() -> void:
	screen.clear_world()
	_free_title()
	var scene: PackedScene = load(title_scene_path) as PackedScene if ResourceLoader.exists(title_scene_path) else null
	if scene == null:
		start_demo()
		return
	_title = scene.instantiate()
	screen.get_ui_layer().add_child(_title)
	if _title.has_signal(START_SIGNAL):
		_title.connect(START_SIGNAL, start_demo)
	else:
		push_error("Main: the title screen has no %s signal" % START_SIGNAL)
	_set_state(State.TITLE)


## Loads the room into the PSX world and removes the title.
func start_demo() -> void:
	_free_title()
	if start_scene != null:
		screen.load_world(start_scene)
	_set_state(State.ROOM)


func _free_title() -> void:
	if _title != null and is_instance_valid(_title):
		_title.get_parent().remove_child(_title)
		_title.queue_free()
	_title = null


func _set_state(new_state: State) -> void:
	_state = new_state
	_state_frame = Engine.get_process_frames()
