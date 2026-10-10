class_name NameEntry
extends Control
## "Name the hero": a small letter-grid window for the title screen's New Game. The name starts as
## the default ("Red"), up to 8 letters (docs/style_guide.md), picked with the pad or typed on a
## keyboard. All strings, the letter rows and the limits are in data/text/title.json ("name_entry").
##
## Controls: d-pad / stick / arrows move; Confirm on the pad picks the letter; Cancel deletes the last
## letter (or backs out when the name is empty); the OK cell, or Enter on a keyboard, finishes.
## Typing on a keyboard enters letters directly, Backspace deletes, Esc backs out. The mouse can hover,
## click cells, and right-click to delete.
##
## Driving it: the owner calls open(), forwards events to handle_event() (mouse positions in stage
## pixels) and ticks it; it emits `submitted(name)` or `cancelled`. An empty name falls back to the
## default, so the game always gets a name.

signal submitted(hero_name: String)
signal cancelled
signal name_changed(hero_name: String)

const TEXT_ID: String = "text/title"
const THEME_ID: String = "ui/ui_theme"
const ACTION_SPACE: String = "space"
const ACTION_DELETE: String = "delete"
const ACTION_DEFAULT: String = "default"
const ACTION_OK: String = "ok"

var audio: UiAudio = UiAudio.new()
## Off: ignores input.
var active: bool = true

var _data: Dictionary = {}
var _palette: Dictionary[String, Color] = {}
var _rows: Array[String] = []
var _actions: Array[Dictionary] = []
var _max_length: int = 8
var _default_name: String = "Red"
var _allowed: String = ""
var _name: String = ""
var _row: int = 0
var _col: int = 0
var _anim_clock: float = 0.0
var _window: UiWindow = null
var _canvas: Control = null
var _input_map: MenuInput = MenuInput.new()
var _is_open: bool = false


func _ready() -> void:
	_data = (DataDB.get_dict(TEXT_ID))["name_entry"]
	var palette: Dictionary = DataDB.get_dict(THEME_ID)["palette"]
	for key: String in palette:
		_palette[key] = Color.html(str(palette[key]))
	for row: Variant in _data["rows"]:
		_rows.append(str(row))
	for action: Variant in _data["actions"]:
		_actions.append(action as Dictionary)
	_max_length = int(_data["max_length"])
	_default_name = str(_data["default_name"])
	_allowed = str(_data["allowed"])
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rect: Dictionary = _data["window"]
	position = Vector2(float(rect["x"]), float(rect["y"]))
	size = Vector2(float(rect["w"]), float(rect["h"]))
	_window = UiWindow.new()
	_window.name = "Window"
	_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window.size = size
	add_child(_window)
	# The window is a child, so the letters are drawn by a second child above it.
	_canvas = Control.new()
	_canvas.name = "Canvas"
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.size = size
	_canvas.draw.connect(_draw_content)
	add_child(_canvas)
	visible = false


# ---- open / close ----

## Shows the window with `start_name` (empty = the default name) filled in.
func open(start_name: String = "") -> void:
	_name = (start_name if not start_name.is_empty() else _default_name).substr(0, _max_length)
	_row = 0
	_col = 0
	_is_open = true
	visible = true
	_redraw()
	name_changed.emit(_name)


func _redraw() -> void:
	if _canvas != null:
		_canvas.queue_redraw()


func close() -> void:
	_is_open = false
	visible = false


func is_open() -> bool:
	return _is_open


func tick(delta: float) -> void:
	if not _is_open:
		return
	_anim_clock += delta
	_redraw()


# ---- the name ----

func get_name_text() -> String:
	return _name


func get_default_name() -> String:
	return _default_name


func get_max_length() -> int:
	return _max_length


func get_title_text() -> String:
	return str(_data["title"])


func get_hint_text() -> String:
	return str(_data["hint"])


func set_name_text(value: String) -> void:
	_name = value.substr(0, _max_length)
	name_changed.emit(_name)
	_redraw()


## Adds one letter if it is allowed and there is room. Returns true when it was added.
func type_char(character: String) -> bool:
	if character.length() != 1 or not _allowed.contains(character):
		return false
	if _name.length() >= _max_length:
		return false
	if character == " " and _name.is_empty():
		return false
	_name += character
	audio.sfx("tick")
	name_changed.emit(_name)
	_redraw()
	return true


## Removes the last letter. Returns true when there was one to remove.
func delete_char() -> bool:
	if _name.is_empty():
		return false
	_name = _name.substr(0, _name.length() - 1)
	audio.sfx("back")
	name_changed.emit(_name)
	_redraw()
	return true


## Finishes: emits `submitted` with the trimmed name, or the default when it is empty.
func submit() -> void:
	var result: String = _name.strip_edges()
	if result.is_empty():
		result = _default_name
	audio.sfx("confirm")
	submitted.emit(result)


func cancel() -> void:
	audio.sfx("back")
	cancelled.emit()


# ---- the grid ----

func get_cursor() -> Vector2i:
	return Vector2i(_col, _row)


func get_grid_rows() -> Array[String]:
	return _rows


func get_action_ids() -> Array[String]:
	var ids: Array[String] = []
	for action: Dictionary in _actions:
		ids.append(str(action["id"]))
	return ids


## The text of the cell under the cursor (a letter, or an action id).
func get_cursor_cell() -> String:
	if _row < _rows.size():
		return _rows[_row][_col]
	return str(_actions[_col]["id"])


func _row_count() -> int:
	return _rows.size() + 1


func _cols_in(row: int) -> int:
	return _rows[row].length() if row < _rows.size() else _actions.size()


func move(dx: int, dy: int) -> void:
	var old_row: int = _row
	var old_cols: int = _cols_in(_row)
	if dy != 0:
		_row = posmod(_row + dy, _row_count())
		# Keep the column in the same relative place when the row length changes.
		_col = clampi(int(round(float(_col) / float(maxi(1, old_cols - 1)) * float(_cols_in(_row) - 1))), 0, _cols_in(_row) - 1)
	if dx != 0:
		_col = posmod(_col + dx, _cols_in(_row))
	if _row != old_row or dx != 0:
		audio.sfx("tick")
	_redraw()


func set_cursor(col: int, row: int) -> void:
	if row < 0 or row >= _row_count() or col < 0 or col >= _cols_in(row):
		return
	if row != _row or col != _col:
		audio.sfx("tick")
	_row = row
	_col = col
	_redraw()


## Picks the cell under the cursor (a letter is added; an action runs).
func pick() -> void:
	if _row < _rows.size():
		type_char(_rows[_row][_col])
		return
	match str(_actions[_col]["id"]):
		ACTION_SPACE:
			type_char(" ")
		ACTION_DELETE:
			delete_char()
		ACTION_DEFAULT:
			set_name_text(_default_name)
			audio.sfx("tick")
		ACTION_OK:
			submit()


# ---- input ----

## Gives the window one input event. Returns true when it used it.
func handle_event(event: InputEvent) -> bool:
	if not _is_open or not active:
		return false
	if event is InputEventMouse:
		return _event_mouse(event)
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if not key.pressed or key.echo:
			return false
		var typed: bool = _event_key(key)
		if typed:
			return true
	var command: MenuInput.Cmd = _input_map.classify(event)
	if command == MenuInput.Cmd.NONE:
		return false
	return handle_command(command)


func handle_command(command: MenuInput.Cmd) -> bool:
	if not _is_open or not active:
		return false
	match command:
		MenuInput.Cmd.LEFT:
			move(-1, 0)
		MenuInput.Cmd.RIGHT:
			move(1, 0)
		MenuInput.Cmd.UP:
			move(0, -1)
		MenuInput.Cmd.DOWN:
			move(0, 1)
		MenuInput.Cmd.CONFIRM:
			pick()
		MenuInput.Cmd.CANCEL:
			_back()
		_:
			return false
	return true


## Delete the last letter, or leave when there is nothing to delete.
func _back() -> void:
	if not delete_char():
		cancel()


## Keyboard typing, Backspace, Enter and Esc. Returns true when the key was used here.
func _event_key(key: InputEventKey) -> bool:
	var code: int = key.keycode if key.keycode != KEY_NONE else key.physical_keycode
	if code == KEY_BACKSPACE:
		_back()
		return true
	if code == KEY_ENTER or code == KEY_KP_ENTER:
		submit()
		return true
	if code == KEY_ESCAPE:
		cancel()
		return true
	if key.unicode >= 32 and key.unicode < 127:
		type_char(char(key.unicode))
		return true
	return false


func _event_mouse(event: InputEvent) -> bool:
	if event is InputEventMouseMotion:
		var hover: Vector2i = _cell_at(_to_local((event as InputEventMouseMotion).position))
		if hover.x >= 0:
			set_cursor(hover.x, hover.y)
			return true
		return false
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click.button_index == MOUSE_BUTTON_LEFT:
			var hit: Vector2i = _cell_at(_to_local(click.position))
			if hit.x >= 0:
				set_cursor(hit.x, hit.y)
				pick()
				return true
		elif click.button_index == MOUSE_BUTTON_RIGHT:
			_back()
			return true
	return false


func _to_local(stage_point: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * stage_point


# ---- layout and drawing ----

func _grid_origin() -> Vector2:
	var grid: Dictionary = _data["grid"]
	var widest: int = 0
	for row: String in _rows:
		widest = maxi(widest, row.length())
	var total_w: float = float(widest * int(grid["cell_w"]))
	return Vector2((size.x - total_w) / 2.0, float(grid["top"]))


## The rectangle of a cell in local coordinates.
func get_cell_rect(col: int, row: int) -> Rect2:
	var grid: Dictionary = _data["grid"]
	var origin: Vector2 = _grid_origin()
	var cell_w: float = float(grid["cell_w"])
	var cell_h: float = float(grid["cell_h"])
	if row < _rows.size():
		return Rect2(origin + Vector2(col * cell_w, row * cell_h), Vector2(cell_w, cell_h))
	var widest_w: float = size.x - origin.x * 2.0
	var action_w: float = widest_w / float(_actions.size())
	return Rect2(Vector2(origin.x + col * action_w, origin.y + _rows.size() * cell_h + float(grid["action_gap"])), Vector2(action_w, cell_h))


func _cell_at(local: Vector2) -> Vector2i:
	for row: int in _row_count():
		for col: int in _cols_in(row):
			if get_cell_rect(col, row).has_point(local):
				return Vector2i(col, row)
	return Vector2i(-1, -1)


func _draw_content() -> void:
	if not _is_open or _data.is_empty():
		return
	UiText.draw(_canvas, "menu", Vector2(0, 19), str(_data["title"]), _palette["text_highlight"], HORIZONTAL_ALIGNMENT_CENTER, size.x)
	_draw_name_slots()
	for row: int in _row_count():
		for col: int in _cols_in(row):
			_draw_cell(col, row)
	UiText.draw(_canvas, "body", Vector2(0, size.y - 8), str(_data["hint"]), _palette["slate_light"], HORIZONTAL_ALIGNMENT_CENTER, size.x)


func _draw_name_slots() -> void:
	var slots: Dictionary = _data["slots"]
	var slot_w: int = int(slots["w"])
	var total_w: int = slot_w * _max_length
	var x0: float = (size.x - float(total_w)) / 2.0
	var y: float = float(slots["y"])
	var blink_on: bool = int(_anim_clock / 0.4) % 2 == 0
	for i: int in _max_length:
		var x: float = x0 + float(i * slot_w)
		var color: Color = _palette["slate"]
		if i == _name.length() and blink_on:
			color = _palette["lamp_amber"]
		_canvas.draw_rect(Rect2(x + 2.0, y + float(slots["h"]) - 2.0, float(slot_w - 4), 2), color)
		if i < _name.length():
			UiText.draw(_canvas, "menu", Vector2(x, y + float(slots["h"]) - 5.0), _name[i], _palette["text"], HORIZONTAL_ALIGNMENT_CENTER, float(slot_w))


func _draw_cell(col: int, row: int) -> void:
	var rect: Rect2 = get_cell_rect(col, row)
	var selected: bool = row == _row and col == _col
	var label: String
	if row < _rows.size():
		label = _rows[row][col]
	else:
		label = str(_actions[col]["label"])
	if selected:
		PixelShape.fill(_canvas, Rect2i(rect.grow(-1)), 3, _palette["lamp_amber"])
		PixelShape.fill(_canvas, Rect2i(rect.grow(-2)), 2, _palette["dusk"])
	var color: Color = _palette["text_highlight"] if selected else _palette["text"]
	var baseline: float = rect.position.y + rect.size.y / 2.0 + float(UiFonts.get_size("menu")) * 0.36
	UiText.draw(_canvas, "menu", Vector2(rect.position.x, baseline), label, color, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
