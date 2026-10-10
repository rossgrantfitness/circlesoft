class_name MenuList
extends Control
## The shared JRPG list widget: rows of text with the amber flame cursor, cursor memory, wrap-around
## movement, scrolling for long lists, an optional right-aligned value per row, controller /
## keyboard / mouse input, and menu tick sounds. Used by every field-menu page.
##
## The owner feeds it commands (handle_command) and mouse events (handle_mouse, positions in stage
## pixels); the widget itself reads no input, so which list is active is always decided in one place.
## Items: Array of {"label": String, "value": String (optional), "enabled": bool (optional), "id": String}.

signal cursor_moved(index: int)
signal activated(index: int)

const THEME_ID: String = "ui/ui_theme"
const ARROW_SIZE: int = 5

## Dimmed, still cursor and no input while false (the "last position" marker on inactive lists).
var active: bool = true:
	set(value):
		active = value
		if _cursor != null:
			_cursor.active = value
		queue_redraw()

var audio: UiAudio = UiAudio.new()
var visible_rows: int = 8
var row_height: int = 16
var first_row_y: int = 6
var text_x: int = 20
var cursor_x: int = 6
var value_pad: int = 10
var wrap_around: bool = true

var _items: Array[Dictionary] = []
var _index: int = 0
var _top: int = 0
var _font: Font = null
var _font_size: int = 8
var _c: Dictionary[String, Color] = {}
var _cursor: MenuCursor = null


func _ready() -> void:
	var theme_data: Dictionary = DataDB.get_dict(THEME_ID)
	var palette: Dictionary = theme_data["palette"]
	for key: String in palette:
		_c[key] = Color.html(str(palette[key]))
	_font = UiFonts.get_font("menu")
	_font_size = UiFonts.get_size("menu")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor = MenuCursor.new()
	_cursor.name = "Cursor"
	_cursor.active = active
	add_child(_cursor)
	_place_cursor()


# ---- items and cursor ----

## Replaces the rows. The cursor keeps its index (clamped) when `keep_index` is true.
func set_items(new_items: Array[Dictionary], keep_index: bool = false) -> void:
	_items = new_items
	if not keep_index:
		_index = 0
		_top = 0
	_index = clampi(_index, 0, maxi(0, _items.size() - 1))
	_scroll_to_cursor()
	_place_cursor()
	queue_redraw()


func get_items() -> Array[Dictionary]:
	return _items


func get_count() -> int:
	return _items.size()


func get_cursor_index() -> int:
	return _index


func get_top() -> int:
	return _top


func get_item_id(index: int) -> String:
	if index < 0 or index >= _items.size():
		return ""
	return str(_items[index].get("id", ""))


func set_index(index: int, with_sound: bool = true) -> void:
	if _items.is_empty():
		return
	var clamped: int = clampi(index, 0, _items.size() - 1)
	var changed: bool = clamped != _index
	_index = clamped
	_scroll_to_cursor()
	_place_cursor()
	if _cursor != null:
		_cursor.restart()
	queue_redraw()
	if changed:
		if with_sound:
			audio.sfx("tick")
		cursor_moved.emit(_index)


## Moves the cursor one row; wraps at the ends when wrap_around is on. Returns true when it moved.
func move(direction: int) -> bool:
	if _items.size() < 2:
		return false
	var target: int = _index + direction
	if wrap_around:
		target = posmod(target, _items.size())
	else:
		target = clampi(target, 0, _items.size() - 1)
	if target == _index:
		return false
	set_index(target)
	return true


## Picks the highlighted row (a confirm press or a click). Disabled rows only buzz the "back" tick.
func activate() -> void:
	if _items.is_empty():
		return
	if not bool(_items[_index].get("enabled", true)):
		audio.sfx("back")
		return
	audio.sfx("confirm")
	activated.emit(_index)


# ---- input (the owner forwards) ----

## Handles UP / DOWN / CONFIRM. Returns true when it used the command.
func handle_command(command: MenuInput.Cmd) -> bool:
	if not active:
		return false
	match command:
		MenuInput.Cmd.UP:
			move(-1)
			return true
		MenuInput.Cmd.DOWN:
			move(1)
			return true
		MenuInput.Cmd.CONFIRM:
			activate()
			return true
	return false


## Mouse hover moves the cursor, left click picks, the wheel scrolls. `event.position` must be in
## stage pixels. Returns true when the event was used.
func handle_mouse(event: InputEvent) -> bool:
	if not active or _items.is_empty():
		return false
	if event is InputEventMouseMotion:
		var hover: int = _item_at(_local((event as InputEventMouseMotion).position))
		if hover >= 0 and hover != _index:
			set_index(hover)
		return hover >= 0
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			var hit: int = _item_at(_local(button.position))
			if hit >= 0:
				set_index(hit, hit != _index)
				activate()
				return true
		elif button.button_index == MOUSE_BUTTON_WHEEL_UP:
			move(-1)
			return true
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			move(1)
			return true
	return false


func _local(stage_point: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * stage_point


## The row under a local point, or -1.
func _item_at(local: Vector2) -> int:
	for row: int in visible_rows:
		var index: int = _top + row
		if index >= _items.size():
			break
		if get_row_rect(index).has_point(local):
			return index
	return -1


## The clickable rectangle of an item in local coordinates (empty if scrolled out of view).
func get_row_rect(index: int) -> Rect2:
	var row: int = index - _top
	if row < 0 or row >= visible_rows:
		return Rect2()
	var top: float = float(first_row_y + row * row_height) - float(row_height - _font_size) / 2.0
	return Rect2(4.0, top, size.x - 8.0, float(row_height))


func _scroll_to_cursor() -> void:
	if _index < _top:
		_top = _index
	elif _index >= _top + visible_rows:
		_top = _index - visible_rows + 1
	_top = clampi(_top, 0, maxi(0, _items.size() - visible_rows))


func _place_cursor() -> void:
	if _cursor == null:
		return
	_cursor.visible = not _items.is_empty()
	var row: int = _index - _top
	var center: float = float(first_row_y + row * row_height) + float(_font_size) / 2.0
	_cursor.position = Vector2(cursor_x, center - _cursor.size.y / 2.0)


# ---- drawing ----

func _draw() -> void:
	if _font == null:
		return
	for row: int in visible_rows:
		var index: int = _top + row
		if index >= _items.size():
			break
		var item: Dictionary = _items[index]
		var enabled: bool = bool(item.get("enabled", true))
		var color: Color = _c["text"]
		if not enabled:
			color = _c["text_dim"]
		elif index == _index and active:
			color = _c["text_highlight"]
		var baseline: float = float(first_row_y + row * row_height + _font_size)
		UiText.draw(self, "menu", Vector2(text_x, baseline), str(item.get("label", "")), color)
		var value: String = str(item.get("value", ""))
		if not value.is_empty():
			var field_x: float = float(text_x)
			UiText.draw(self, "menu", Vector2(field_x, baseline), value, color, HORIZONTAL_ALIGNMENT_RIGHT, size.x - field_x - value_pad)
	_draw_scroll_arrows()


func _draw_scroll_arrows() -> void:
	var color: Color = _c["lamp_amber"]
	var x: int = int(size.x) - ARROW_SIZE - 4
	if _top > 0:
		for i: int in range(3):
			draw_rect(Rect2(x + 2 - i, 2 + i, 1 + i * 2, 1), color)
	if _top + visible_rows < _items.size():
		var y: int = int(size.y) - 6
		for i: int in range(3):
			draw_rect(Rect2(x + i, y + i, 5 - i * 2, 1), color)
