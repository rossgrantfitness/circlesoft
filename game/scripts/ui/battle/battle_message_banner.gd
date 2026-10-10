class_name BattleMessageBanner
extends Control
## Short battle messages ("Can't run from this one!", "Noise Ticket! No skills.") in a small
## window under the turn row. Messages queue; each opens from a thin line in a couple of steps,
## holds, then closes. When more are waiting, the hold is shorter so the queue never drags.

signal message_shown(text: String)

var _queue: Array[String] = []
var _current: String = ""
var _age: float = 0.0
var _hold_s: float = 1.4
var _window: UiWindow = null
var _label: Label = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	size = Vector2(UiStage.STAGE_SIZE)
	_window = UiWindow.new()
	_window.name = "Window"
	_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_window)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiText.style_label(_label, "menu", BattleUiData.palette("text"))
	_window.add_child(_label)
	_window.visible = false


## Queues a message (empty text is ignored).
func show_message(text: String) -> void:
	if text.is_empty():
		return
	_queue.append(text)
	if _current.is_empty():
		_next()


## True when this exact text is on screen or waiting its turn.
func has_message(text: String) -> bool:
	return _current == text or _queue.has(text)


func get_current_text() -> String:
	return _current


func get_queue_size() -> int:
	return _queue.size()


func is_showing() -> bool:
	return not _current.is_empty()


func clear() -> void:
	_queue.clear()
	_current = ""
	if _window != null:
		_window.visible = false


func tick(delta: float) -> void:
	if _current.is_empty():
		return
	_age += delta
	var step_s: float = BattleUiData.ui_float("timing.step_s", 0.0833)
	var steps: int = BattleUiData.ui_int("timing.message_open_steps", 2)
	var open_time: float = float(steps) * step_s
	if _age < open_time:
		_window.open_amount = float(int(_age / step_s) + 1) / float(steps + 1)
	elif _age < open_time + _hold_s:
		_window.open_amount = 1.0
		_label.visible = true
	else:
		var since: float = _age - open_time - _hold_s
		_window.open_amount = 1.0 - float(int(since / step_s) + 1) / float(steps + 1)
		_label.visible = false
		if since >= open_time:
			_next()


func _next() -> void:
	_age = 0.0
	if _queue.is_empty():
		_current = ""
		_window.visible = false
		return
	_current = _queue.pop_front()
	_hold_s = BattleUiData.ui_float("timing.message_s_queued" if not _queue.is_empty() else "timing.message_s", 1.4)
	var pad: float = BattleUiData.ui_float("layout.message.pad_x", 14.0)
	var height: float = BattleUiData.ui_float("layout.message.h", 22.0)
	var width: float = float(UiFonts.text_width("menu", _current)) + pad * 2.0
	_window.size = Vector2(width, height)
	_window.position = Vector2(floorf((size.x - width) / 2.0), BattleUiData.ui_float("layout.message.y", 34.0))
	_window.visible = true
	_window.open_amount = 0.0
	_label.text = _current
	_label.position = Vector2(pad, (height - float(UiFonts.get_size("menu"))) / 2.0 - 3.0)
	_label.visible = false
	message_shown.emit(_current)
