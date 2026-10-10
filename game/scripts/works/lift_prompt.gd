class_name LiftPrompt
extends Control
## The freight lift's little menu: a window with the stops you can ride to (and "Stay here"), built from
## UiWindow and MenuList on the UI stage like the save screen. Confirm rides, cancel stays. It joins the
## busy group while it is up and freezes Red (released two frames after it closes).
## Layout and labels: data/world/works.json "lift".

signal chosen(room_id: String)
signal cancelled

const RELEASE_FRAMES: int = 2
const STAY_ID: String = "stay"

var manual_ticks: bool = false
var audio: UiAudio = UiAudio.new()
var player: Node = null
## Rows: {id, label}. The last row is always "Stay here".
var options: Array[Dictionary] = []

var _window: UiWindow = null
var _list: MenuList = null
var _title: Label = null
var _input_map: MenuInput = MenuInput.new()
var _arm_left: int = 0
var _closed: bool = false
var _release_left: int = -1
var _frozen_by_us: bool = false
var _was_frozen: bool = false


## Builds the menu on the UI stage and opens it. `stops` are [{id, label}].
static func open(tree: SceneTree, stops: Array[Dictionary], red: Node = null) -> LiftPrompt:
	var prompt: LiftPrompt = LiftPrompt.new()
	prompt.name = "LiftPrompt"
	prompt.options = stops
	prompt.player = red
	UiStage.get_or_create(tree).get_stage_root().add_child(prompt)
	return prompt


func _ready() -> void:
	var cfg: Dictionary = WorksData.section("lift")
	var rect: Dictionary = cfg.get("window", {"x": 112, "y": 62, "w": 160, "h": 76})
	size = Vector2(UiStage.STAGE_SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_window = UiWindow.new()
	_window.name = "LiftWindow"
	_window.position = Vector2(float(rect["x"]), float(rect["y"]))
	_window.size = Vector2(float(rect["w"]), float(rect["h"]))
	add_child(_window)
	_title = Label.new()
	UiText.style_label(_title, "menu", Color.html("#7C7A8E"))
	_title.text = str(cfg.get("title", "Lift"))
	_title.position = Vector2(14, 1)
	_window.add_child(_title)
	_list = MenuList.new()
	_list.audio = audio
	_list.row_height = int(cfg.get("row_height", 16))
	_list.first_row_y = int(cfg.get("first_row_y", 18))
	_list.size = _window.size
	_list.visible_rows = options.size() + 1
	_window.add_child(_list)
	var rows: Array[Dictionary] = []
	for entry: Dictionary in options:
		rows.append({"id": str(entry["id"]), "label": str(entry["label"])})
	rows.append({"id": STAY_ID, "label": str(cfg.get("stay", "Stay here"))})
	_list.set_items(rows)
	_list.activated.connect(_on_activated)
	_arm_left = int(cfg.get("arm_frames", 3))
	add_to_group(UiStage.MODAL_GROUP)
	if player != null:
		_was_frozen = bool(player.get("frozen"))
		player.set("frozen", true)
		_frozen_by_us = true
	audio.sfx("confirm")
	set_process(not manual_ticks)


func _process(_delta: float) -> void:
	tick()


func tick() -> void:
	if _arm_left > 0:
		_arm_left -= 1
	if _release_left >= 0:
		_release_left -= 1
		if _release_left <= 0:
			_release_left = -1
			remove_from_group(UiStage.MODAL_GROUP)
			if _frozen_by_us and player != null and is_instance_valid(player):
				player.set("frozen", _was_frozen)
			_frozen_by_us = false
			queue_free()


func is_open() -> bool:
	return not _closed


func get_list() -> MenuList:
	return _list


func _input(event: InputEvent) -> void:
	if _closed:
		return
	if event is InputEventMouse:
		if _arm_left <= 0 and _list.handle_mouse(event):
			get_viewport().set_input_as_handled()
		return
	var command: MenuInput.Cmd = _input_map.classify(event)
	if command == MenuInput.Cmd.NONE:
		return
	if _arm_left <= 0:
		handle_command(command)
	get_viewport().set_input_as_handled()


## One menu command. Public so tests can drive it.
func handle_command(command: MenuInput.Cmd) -> void:
	if _closed:
		return
	if command == MenuInput.Cmd.CANCEL or command == MenuInput.Cmd.MENU:
		_close()
		cancelled.emit()
		return
	_list.handle_command(command)


func _on_activated(index: int) -> void:
	var id: String = _list.get_item_id(index)
	_close()
	if id == STAY_ID:
		cancelled.emit()
	else:
		chosen.emit(id)


func _close() -> void:
	_closed = true
	_release_left = RELEASE_FRAMES
	visible = false
