class_name UiWindow
extends Control
## The shared JRPG window from docs/style_guide.md ("UI window style"), drawn from code at the
## internal 384x216 pixel size: chamfered corners, a 2px amber outer line, a 1px chalk inner
## line, an Ink drop shadow on the bottom and right, a flat indigo fill with a faint diagonal
## hatch at ~90% opacity, and a rivet dot near each corner.
## Placeholder for the final nine-slice PNG (ui_window_9slice.png); sizes stay free either way.
##
## `open_amount` (0..1) shrinks the window toward a thin horizontal line, so the caller can
## step it through 4 frames to make the "grows from a line" open transition.

const THEME_ID: String = "ui/ui_theme"
const SHADOW_OFFSET: int = 1

## 0 = a thin line, 1 = full height. Set in stepped values for the open/close animation.
var open_amount: float = 1.0:
	set(value):
		open_amount = clampf(value, 0.0, 1.0)
		queue_redraw()

var _chamfer: int = 0
var _outer: int = 0
var _inner: int = 0
var _hatch_period: int = 1
var _rivet_inset: int = 0
var _rivet_size: int = 0
var _thin_height: int = 0
var _c_shadow: Color = Color.BLACK
var _c_outer: Color = Color.BLACK
var _c_inner: Color = Color.BLACK
var _c_fill: Color = Color.BLACK
var _c_hatch: Color = Color.BLACK
var _c_rivet: Color = Color.BLACK


func _ready() -> void:
	var theme_data: Dictionary = DataDB.get_dict(THEME_ID)
	var palette: Dictionary = theme_data["palette"]
	var win: Dictionary = theme_data["window"]
	_chamfer = int(win["chamfer"])
	_outer = int(win["border_outer"])
	_inner = int(win["border_inner"])
	_hatch_period = int(win["hatch_period"])
	_rivet_inset = int(win["rivet_inset"])
	_rivet_size = int(win["rivet_size"])
	_thin_height = int(win["open_thin_height"])
	_c_shadow = Color.html(str(palette["ink"]))
	_c_outer = Color.html(str(palette["lamp_amber"]))
	_c_inner = Color.html(str(palette["chalk"]))
	_c_fill = Color.html(str(palette["window_fill"]))
	_c_fill.a = float(win["fill_alpha"])
	_c_hatch = Color.html(str(palette["window_hatch"]))
	_c_hatch.a = _c_fill.a
	_c_rivet = Color.html(str(palette["brass"]))
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	var full: Vector2i = Vector2i(int(size.x), int(size.y))
	var height: int = full.y
	var top: int = 0
	if open_amount < 1.0:
		height = maxi(_thin_height, int(round(float(full.y) * open_amount)))
		top = (full.y - height) / 2
	var rect: Rect2i = Rect2i(0, top, full.x, height)
	# Drop shadow first (bottom and right), same shape pushed one pixel.
	_fill_shape(Rect2i(rect.position + Vector2i(SHADOW_OFFSET, SHADOW_OFFSET), rect.size), 0, _c_shadow, -1)
	_draw_ring(rect, 0, _outer, _c_outer)
	_draw_ring(rect, _outer, _outer + _inner, _c_inner)
	var fill_margin: int = _outer + _inner
	_fill_shape(rect, fill_margin, _c_fill, _hatch_period)
	if height >= full.y:
		var rivet: Vector2i = Vector2i(_rivet_size, _rivet_size)
		for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			var x: int = rect.position.x + _rivet_inset if corner.x == 0 else rect.end.x - _rivet_inset - _rivet_size
			var y: int = rect.position.y + _rivet_inset if corner.y == 0 else rect.end.y - _rivet_inset - _rivet_size
			draw_rect(Rect2(Vector2(x, y), Vector2(rivet)), _c_rivet)


## The chamfer leg for a shape pulled in by `margin` pixels (keeps the diagonal parallel).
func _cut_for(margin: int) -> int:
	return maxi(0, _chamfer - int(round(float(margin) * 0.6)))


## Horizontal extent [x0, x1) of the chamfered shape on row y of rect, or x1 <= x0 when the row is outside.
func _extent(rect: Rect2i, margin: int, y: int) -> Vector2i:
	var top: int = rect.position.y + margin
	var bottom: int = rect.end.y - margin
	if y < top or y >= bottom:
		return Vector2i(0, 0)
	var cut: int = _cut_for(margin)
	var from_top: int = y - top
	var from_bottom: int = bottom - 1 - y
	var edge: int = mini(from_top, from_bottom)
	var inset: int = margin + maxi(0, cut - edge)
	return Vector2i(rect.position.x + inset, rect.end.x - inset)


func _fill_shape(rect: Rect2i, margin: int, color: Color, hatch_period: int) -> void:
	for y: int in range(rect.position.y + margin, rect.end.y - margin):
		var span: Vector2i = _extent(rect, margin, y)
		if span.y <= span.x:
			continue
		draw_rect(Rect2(span.x, y, span.y - span.x, 1), color)
		if hatch_period > 0:
			var x: int = span.x + posmod(hatch_period - posmod(span.x + y, hatch_period), hatch_period)
			while x < span.y:
				draw_rect(Rect2(x, y, 1, 1), _c_hatch)
				x += hatch_period


## Draws the band between the shape pulled in by `from_margin` and the one pulled in by `to_margin`.
func _draw_ring(rect: Rect2i, from_margin: int, to_margin: int, color: Color) -> void:
	for y: int in range(rect.position.y + from_margin, rect.end.y - from_margin):
		var outer_span: Vector2i = _extent(rect, from_margin, y)
		var inner_span: Vector2i = _extent(rect, to_margin, y)
		if inner_span.y <= inner_span.x:
			draw_rect(Rect2(outer_span.x, y, outer_span.y - outer_span.x, 1), color)
			continue
		draw_rect(Rect2(outer_span.x, y, inner_span.x - outer_span.x, 1), color)
		draw_rect(Rect2(inner_span.y, y, outer_span.y - inner_span.y, 1), color)
