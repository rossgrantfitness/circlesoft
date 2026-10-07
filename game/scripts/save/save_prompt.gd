class_name SavePrompt
extends Control
## The save screen a save spot opens once the lamp check is done: three manual slots and the
## auto-save, each showing the party's portraits (placeholder initials), Red's level, the place,
## play time and credits. Saving over a used slot asks first (thumbs-up or head shake). The
## auto-save row is shown but can't be picked: it belongs to the game.
##
## Built from the shared pieces: UiWindow for the windows and MenuList for both lists, on the
## 384x216 UiStage. Layout from data/world/save.json ("prompt"), strings from data/text/save.json,
## colors and fonts from ui_theme.json. Controller first (d-pad / stick, confirm, cancel), then
## keyboard and mouse (hover moves, click picks, right-click backs out).
##
## Public API: SavePrompt.open(tree, manager, rest, player) builds and opens one; handle_command()
## drives it by hand (tests); `closed` says which slot was saved (-1 for none) once it is gone.

signal slot_saved(slot: int)
signal closed(saved_slot: int)

enum State { CLOSED, OPENING, PICK, CONFIRM, DONE, CLOSING }

const THEME_ID: String = "ui/ui_theme"
const LAYOUT_ID: String = "world/save"
const TEXT_ID: String = "text/save"
const RELEASE_FRAMES: int = 2
const NONE_SAVED: int = -1
const ROW_AUTO_OFFSET: int = 0
const GESTURE_YES: String = "thumbs_up"
const GESTURE_NO: String = "head_shake"
const GESTURE_SIZE: int = 16
const CONFIRM_ROW_H: int = 18
const CONFIRM_FIRST_Y: int = 9
const CONFIRM_TEXT_X: int = 44
const CONFIRM_ICON_X: int = 22
const HINT_X: int = 10
const HINT_Y: int = 7
const DIM_STEPS: int = 8
const DIM_STEP: int = 3

## Off: the prompt does not run its own clock; call tick(delta) (tests).
var manual_ticks: bool = false
var animations_enabled: bool = true
var audio: UiAudio = UiAudio.new()
## Red, frozen while the screen is up (released two frames after it closes).
var player: Node = null
## The SaveManager to save through, and whether this spot also rests the party.
var manager: Node = null
var rest: bool = false

var _state: State = State.CLOSED
var _layout: Dictionary = {}
var _text: Dictionary = {}
var _c: Dictionary[String, Color] = {}
var _step_s: float = 0.0833
var _step_clock: float = 0.0
var _open_amount: float = 0.0
var _release_left: int = -1
var _arm_left: int = 0
var _frozen_by_us: bool = false
var _was_frozen: bool = false
var _saved_slot: int = NONE_SAVED
var _pending_slot: int = 0
var _hint_key: String = "hint_pick"
var _input_map: MenuInput = MenuInput.new()
var _summaries: Dictionary[int, Dictionary] = {}

var _dim: DitherFade = null
var _frame: Control = null
var _window: UiWindow = null
var _hint_window: UiWindow = null
var _confirm_window: UiWindow = null
var _list: MenuList = null
var _confirm_list: MenuList = null
var _detail: Control = null
var _confirm_art: Control = null
var _hint_label: Label = null


func _ready() -> void:
	var theme_data: Dictionary = DataDB.get_dict(THEME_ID)
	for key: String in theme_data["palette"]:
		_c[key] = Color.html(str(theme_data["palette"][key]))
	_step_s = float(theme_data["timing"]["ui_step_s"])
	_layout = DataDB.get_dict(LAYOUT_ID)["prompt"]
	_text = DataDB.get_dict(TEXT_ID)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(UiStage.STAGE_SIZE)
	visible = false
	set_process(not manual_ticks)
	_build()


func _process(delta: float) -> void:
	tick(delta)


## Builds a prompt on the UI stage, opens it and returns it. `manager` is the SaveManager.
static func open(tree: SceneTree, save_manager: Node, rest_party: bool = false, player_to_freeze: Node = null) -> SavePrompt:
	var prompt: SavePrompt = SavePrompt.new()
	prompt.name = "SavePrompt"
	prompt.manager = save_manager
	prompt.rest = rest_party
	prompt.player = player_to_freeze
	UiStage.get_or_create(tree).get_stage_root().add_child(prompt)
	prompt.open_screen()
	return prompt


# ---- build ----

func _build() -> void:
	_dim = DitherFade.new()
	_dim.name = "Dim"
	_dim.size = size
	add_child(_dim)
	_frame = Control.new()
	_frame.name = "Frame"
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.size = size
	add_child(_frame)
	_window = _make_window("SlotWindow", _layout["window"])
	_hint_window = _make_window("HintWindow", _layout["hint_window"])
	_confirm_window = _make_window("ConfirmWindow", _layout["confirm_window"])
	_confirm_window.visible = false

	_list = MenuList.new()
	_list.audio = audio
	_list.row_height = int(_layout["row_height"])
	_list.first_row_y = int(_layout["first_row_y"])
	_list.text_x = int(_layout["text_x"])
	_list.cursor_x = int(_layout["cursor_x"])
	_list.visible_rows = manager_slot_count() + 1
	_list.size = _window.size
	_window.add_child(_list)
	_list.activated.connect(_on_slot_activated)
	_detail = Control.new()
	_detail.name = "Details"
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.size = _window.size
	_detail.draw.connect(_draw_details)
	_window.add_child(_detail)

	_confirm_list = MenuList.new()
	_confirm_list.audio = audio
	_confirm_list.row_height = CONFIRM_ROW_H
	_confirm_list.first_row_y = CONFIRM_FIRST_Y
	_confirm_list.text_x = CONFIRM_TEXT_X
	_confirm_list.cursor_x = int(_layout["cursor_x"])
	_confirm_list.visible_rows = 2
	_confirm_list.size = _confirm_window.size
	_confirm_list.active = false
	_confirm_window.add_child(_confirm_list)
	_confirm_list.activated.connect(_on_confirm_activated)
	_confirm_list.set_items([
		{"id": "yes", "label": str(_text["overwrite_yes"])},
		{"id": "no", "label": str(_text["overwrite_no"])},
	] as Array[Dictionary])
	_confirm_art = Control.new()
	_confirm_art.name = "Gestures"
	_confirm_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm_art.size = _confirm_window.size
	_confirm_art.draw.connect(_draw_confirm_art)
	_confirm_window.add_child(_confirm_art)

	_hint_label = Label.new()
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiText.style_label(_hint_label, "dialogue", _c["text"])
	_hint_label.position = Vector2(HINT_X, HINT_Y)
	_hint_label.size = Vector2(_hint_window.size.x - HINT_X * 2, 20)
	_hint_window.add_child(_hint_label)


func _make_window(node_name: String, rect: Dictionary) -> UiWindow:
	var window: UiWindow = UiWindow.new()
	window.name = node_name
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.position = Vector2(float(rect["x"]), float(rect["y"]))
	window.size = Vector2(float(rect["w"]), float(rect["h"]))
	_frame.add_child(window)
	return window


func manager_slot_count() -> int:
	return int(DataDB.get_value(LAYOUT_ID, "slots", 3))


# ---- opening and closing ----

## Shows the screen. Rests the party first when `rest` is set. Returns false if it is already up.
func open_screen() -> bool:
	if _state != State.CLOSED:
		return false
	if not is_node_ready():
		push_error("SavePrompt: add it to the tree before open_screen()")
		return false
	visible = true
	add_to_group(UiStage.MODAL_GROUP)
	_release_left = -1
	_saved_slot = NONE_SAVED
	_arm_left = int(_layout["arm_frames"])
	if player != null and not _frozen_by_us:
		_was_frozen = bool(player.get("frozen"))
		player.set("frozen", true)
		_frozen_by_us = true
	_hint_key = "hint_pick"
	if rest:
		var state: Node = _game_state()
		if state != null:
			state.call("rest_party")
		_hint_key = "hint_rested"
	_dim.step_count = DIM_STEPS
	_dim.step = DIM_STEP
	audio.sfx("confirm")
	_refresh_rows(false)
	_set_open_amount(0.0 if animations_enabled else 1.0)
	_state = State.OPENING if animations_enabled else State.PICK
	return true


## Closes the screen (the windows shrink to a line). `closed` fires when it is gone.
func close() -> void:
	if _state == State.CLOSED or _state == State.CLOSING:
		return
	audio.sfx("back")
	_confirm_window.visible = false
	if animations_enabled:
		_state = State.CLOSING
		_list.visible = false
		_detail.visible = false
		_hint_label.visible = false
	else:
		_finish_close()


func _finish_close() -> void:
	_state = State.CLOSED
	visible = false
	_dim.step = 0
	_release_left = RELEASE_FRAMES
	closed.emit(_saved_slot)


func get_state() -> State:
	return _state


func is_open() -> bool:
	return _state != State.CLOSED and _state != State.CLOSING


func _set_open_amount(amount: float) -> void:
	_open_amount = amount
	var full: bool = amount >= 1.0
	_window.open_amount = amount
	_hint_window.open_amount = amount
	_list.visible = full
	_detail.visible = full
	_hint_label.visible = full


## Jumps the open / close animation to its end (tests).
func finish_animations() -> void:
	if _state == State.OPENING:
		_set_open_amount(1.0)
		_state = State.PICK
	elif _state == State.CLOSING:
		_set_open_amount(0.0)
		_finish_close()


# ---- time ----

func tick(delta: float) -> void:
	if _arm_left > 0:
		_arm_left -= 1
	if _release_left >= 0:
		_release_left -= 1
		if _release_left <= 0:
			_release_left = -1
			_release()
	if _state == State.CLOSED:
		return
	_step_clock += delta
	while _step_clock >= _step_s:
		_step_clock -= _step_s
		_advance_step()


func _advance_step() -> void:
	var step: float = 1.0 / float(int(_layout["open_steps"]))
	if _state == State.OPENING:
		_set_open_amount(minf(1.0, _open_amount + step))
		if _open_amount >= 1.0:
			_state = State.PICK
	elif _state == State.CLOSING:
		_set_open_amount(maxf(0.0, _open_amount - step))
		if _open_amount <= 0.0:
			_finish_close()


func _release() -> void:
	if _state != State.CLOSED:
		return
	remove_from_group(UiStage.MODAL_GROUP)
	if _frozen_by_us and player != null and is_instance_valid(player):
		player.set("frozen", _was_frozen)
	_frozen_by_us = false
	queue_free()


# ---- input ----

func _input(event: InputEvent) -> void:
	if _state == State.CLOSED or _state == State.CLOSING:
		return
	if event is InputEventMouse:
		if _arm_left <= 0 and _state != State.OPENING and _handle_mouse(event):
			get_viewport().set_input_as_handled()
		return
	var command: MenuInput.Cmd = _input_map.classify(event)
	if command == MenuInput.Cmd.NONE:
		return
	# The press that opened this screen (or ended the lamp check) must not also pick a slot.
	if _arm_left <= 0:
		handle_command(command)
	get_viewport().set_input_as_handled()


## One menu command. Public so tests and cutscenes can drive it.
func handle_command(command: MenuInput.Cmd) -> void:
	match _state:
		State.PICK:
			if command == MenuInput.Cmd.CANCEL or command == MenuInput.Cmd.MENU:
				close()
			else:
				_list.handle_command(command)
		State.CONFIRM:
			if command == MenuInput.Cmd.CANCEL or command == MenuInput.Cmd.MENU:
				_cancel_overwrite()
			else:
				_confirm_list.handle_command(command)
		State.DONE:
			if command == MenuInput.Cmd.CONFIRM or command == MenuInput.Cmd.CANCEL or command == MenuInput.Cmd.MENU:
				close()


func _handle_mouse(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.pressed and button.button_index == MOUSE_BUTTON_RIGHT:
			handle_command(MenuInput.Cmd.CANCEL)
			return true
	match _state:
		State.PICK:
			if _list.handle_mouse(event):
				return true
		State.CONFIRM:
			if _confirm_list.handle_mouse(event):
				return true
		State.DONE:
			if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
				handle_command(MenuInput.Cmd.CONFIRM)
				return true
	return event is InputEventMouseButton


# ---- slots ----

func _on_slot_activated(index: int) -> void:
	if _state != State.PICK:
		return
	var slot: int = index + 1
	if _summary(slot).is_empty():
		_save_to(slot)
		return
	_pending_slot = slot
	_state = State.CONFIRM
	_hint_key = "hint_overwrite"
	_list.active = false
	_confirm_list.active = true
	_confirm_list.set_index(1, false)
	_confirm_window.visible = true
	_refresh_hint()


func _on_confirm_activated(index: int) -> void:
	if _state != State.CONFIRM:
		return
	if index == 0:
		_confirm_window.visible = false
		_confirm_list.active = false
		_list.active = true
		_save_to(_pending_slot)
	else:
		_cancel_overwrite()


func _cancel_overwrite() -> void:
	audio.sfx("back")
	_state = State.PICK
	_hint_key = "hint_rested" if rest else "hint_pick"
	_confirm_window.visible = false
	_confirm_list.active = false
	_list.active = true
	_refresh_hint()


func _save_to(slot: int) -> void:
	if manager != null and bool(manager.call("save_slot", slot)):
		_saved_slot = slot
		_state = State.DONE
		_hint_key = "hint_saved"
		slot_saved.emit(slot)
	else:
		_state = State.PICK
		_hint_key = "hint_failed"
	_refresh_rows(true)


# ---- what the rows show ----

func _summary(slot: int) -> Dictionary:
	return _summaries.get(slot, {})


func _refresh_rows(keep_index: bool) -> void:
	_summaries.clear()
	var rows: Array[Dictionary] = []
	for slot: int in range(1, manager_slot_count() + 1):
		var summary: Dictionary = _fetch(slot)
		_summaries[slot] = summary
		rows.append({"id": "slot_%d" % slot, "label": _row_label(slot, summary), "value": _row_time(summary)})
	var auto_summary: Dictionary = _fetch(0)
	_summaries[0] = auto_summary
	rows.append({"id": "auto", "label": _row_label(0, auto_summary), "value": _row_time(auto_summary), "enabled": false})
	_list.set_items(rows, keep_index)
	_refresh_hint()
	_detail.queue_redraw()


func _fetch(slot: int) -> Dictionary:
	return manager.call("slot_summary", slot) as Dictionary if manager != null else {}


func _row_label(slot: int, summary: Dictionary) -> String:
	var head: String = str(_text["auto"]) if slot == 0 else str(_text["slot"]).format({"n": slot})
	if summary.is_empty():
		return "%s  %s" % [head, str(_text["empty"])]
	if bool(summary.get("corrupt", false)):
		return "%s  %s" % [head, str(_text["corrupt"])]
	return "%s  %s" % [head, str(summary.get("place", ""))]


func _row_time(summary: Dictionary) -> String:
	if summary.is_empty() or bool(summary.get("corrupt", false)):
		return ""
	return play_time_text(float(summary.get("play_time_s", 0.0)))


## 3725.0 -> "1:02:05".
static func play_time_text(seconds: float) -> String:
	var total: int = maxi(0, int(seconds))
	return "%d:%02d:%02d" % [total / 3600, (total / 60) % 60, total % 60]


func _refresh_hint() -> void:
	_hint_label.text = str(_text[_hint_key])


func get_hint() -> String:
	return _hint_label.text


func get_list() -> MenuList:
	return _list


func get_confirm_list() -> MenuList:
	return _confirm_list


func get_saved_slot() -> int:
	return _saved_slot


func _game_state() -> Node:
	if manager != null and manager.get("game_state") != null:
		return manager.get("game_state") as Node
	return get_node_or_null("/root/GameState")


# ---- drawing ----

func _draw_details() -> void:
	var tile: int = int(_layout["portrait_size"])
	var gap: int = int(_layout["portrait_gap"])
	var detail_dy: int = int(_layout["detail_dy"])
	var font_size: int = UiFonts.get_size("menu")
	for index: int in _list.get_count():
		var slot: int = index + 1 if index < manager_slot_count() else 0
		var summary: Dictionary = _summary(slot)
		if summary.is_empty() or bool(summary.get("corrupt", false)):
			continue
		var enabled: bool = slot != 0
		var row: int = index - _list.get_top()
		var baseline: float = float(_list.first_row_y + row * _list.row_height + font_size)
		var x: float = float(_layout["portrait_x"])
		var top: float = baseline + 4.0
		var party: Array = summary.get("party", [])
		for member_ref: Variant in party:
			var member: Dictionary = _member(str((member_ref as Dictionary).get("id", "")))
			_detail.draw_rect(Rect2(x, top, tile, tile), Color.html(str(member.get("accent", "#888888"))) if enabled else _c["slate"])
			UiText.draw(_detail, "tag", Vector2(x, top + tile - 3), str(member.get("initial", "?")), _c["ink"], HORIZONTAL_ALIGNMENT_CENTER, float(tile))
			x += tile + gap
		var color: Color = _c["text"] if enabled else _c["text_dim"]
		var red_level: int = int((party[0] as Dictionary).get("level", 1)) if not party.is_empty() else 1
		UiText.draw(_detail, "menu", Vector2(x + 6.0, baseline + detail_dy), str(_text["level"]).format({"level": red_level}), color)
		var credits_text: String = str(_text["credits"]).format({"credits": int(summary.get("credits", 0))})
		UiText.draw(_detail, "menu", Vector2(0.0, baseline + detail_dy), credits_text, color, HORIZONTAL_ALIGNMENT_RIGHT, _detail.size.x - 10.0)


func _member(member_id: String) -> Dictionary:
	var state: Node = _game_state()
	return state.call("get_member", member_id) as Dictionary if state != null else {}


func _draw_confirm_art() -> void:
	var gestures: Array[String] = [GESTURE_YES, GESTURE_NO]
	for row: int in 2:
		var frames: Array[ImageTexture] = GestureIcons.get_frames(gestures[row])
		if frames.is_empty():
			continue
		var y: float = float(CONFIRM_FIRST_Y + row * CONFIRM_ROW_H) - 2.0
		_confirm_art.draw_texture(frames[0], Vector2(CONFIRM_ICON_X, y))
