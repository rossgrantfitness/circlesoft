class_name BattleTurnRow
extends Control
## The turn-order row along the top: this round's fighters still to act, a divider, then next
## round's order. The fighter who is up is framed in amber. Heads are placeholders (BattleHeads).
## Fighters who are down or fled drop out of the row. Fed by round_started / turn_started.

var roster: BattleRoster = BattleRoster.new()

var _now: Array[String] = []
var _next: Array[String] = []
var _current: String = ""
var _window: UiWindow = null
var _heads: Control = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	size = Vector2(UiStage.STAGE_SIZE)
	_window = UiWindow.new()
	_window.name = "Window"
	_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_window)
	_heads = Control.new()
	_heads.name = "Heads"
	_heads.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_heads.size = size
	_heads.draw.connect(_draw_heads)
	add_child(_heads)
	_relayout()


## A new round: who goes this round (in order) and who goes in the next one.
func set_round(order: Array, next_order: Array) -> void:
	_now.assign(order)
	_next.assign(next_order)
	_current = ""
	_relayout()


## Whose turn it is. Anyone listed before them has already acted and leaves the row.
func set_current(actor_id: String) -> void:
	_current = actor_id
	var at: int = _now.find(actor_id)
	if at > 0:
		_now.assign(_now.slice(at))
	_relayout()


## Redraw after the roster changed (someone went down).
func refresh() -> void:
	_relayout()


func get_now_ids() -> Array[String]:
	return _standing(_now)


func get_next_ids() -> Array[String]:
	return _standing(_next)


func get_current_id() -> String:
	return _current


func _standing(ids: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for id: String in ids:
		if roster.has(id) and not roster.is_out(id):
			out.append(id)
	return out


func _row_width() -> float:
	var head: float = BattleUiData.ui_float("layout.turn_row.head", 18.0)
	var gap: float = BattleUiData.ui_float("layout.turn_row.gap", 2.0)
	var pad: float = BattleUiData.ui_float("layout.turn_row.pad_x", 8.0)
	var count: int = get_now_ids().size() + get_next_ids().size()
	var width: float = pad * 2.0 + float(count) * (head + gap) - gap
	if not get_next_ids().is_empty():
		width += BattleUiData.ui_float("layout.turn_row.divider", 16.0) - gap
	return maxf(width, pad * 2.0)


func _relayout() -> void:
	if _window == null:
		return
	var width: float = _row_width()
	var head: float = BattleUiData.ui_float("layout.turn_row.head", 18.0)
	var pad_y: float = BattleUiData.ui_float("layout.turn_row.pad_y", 4.0)
	_window.size = Vector2(width, head + pad_y * 2.0 + 2.0)
	_window.position = Vector2(floorf((size.x - width) / 2.0), BattleUiData.ui_float("layout.turn_row.y", 3.0))
	_window.visible = not (get_now_ids().is_empty() and get_next_ids().is_empty())
	_heads.queue_redraw()


func _draw_heads() -> void:
	var head: float = BattleUiData.ui_float("layout.turn_row.head", 18.0)
	var gap: float = BattleUiData.ui_float("layout.turn_row.gap", 2.0)
	var pad: float = BattleUiData.ui_float("layout.turn_row.pad_x", 8.0)
	var divider: float = BattleUiData.ui_float("layout.turn_row.divider", 16.0)
	var next_alpha: float = BattleUiData.ui_float("layout.turn_row.next_alpha", 0.65)
	var x: float = _window.position.x + pad
	var y: float = _window.position.y + (_window.size.y - head) / 2.0
	var now_ids: Array[String] = get_now_ids()
	for i: int in now_ids.size():
		var lifted: bool = i == 0 and now_ids[i] == _current
		BattleHeads.draw_head(_heads, Rect2(x, y - (2.0 if lifted else 0.0), head, head), now_ids[i], roster, 1.0, lifted)
		x += head + gap
	var next_ids: Array[String] = get_next_ids()
	if next_ids.is_empty():
		return
	var mid: float = x - gap + floorf(divider / 2.0)
	var dash: Color = BattleUiData.palette("text_dim")
	for step: int in 3:
		_heads.draw_rect(Rect2(mid, y + 2.0 + float(step) * 5.0, 1.0, 3.0), dash)
	x += divider - gap
	for id: String in next_ids:
		BattleHeads.draw_head(_heads, Rect2(x, y, head, head), id, roster, next_alpha, false)
		x += head + gap
