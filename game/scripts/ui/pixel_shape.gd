class_name PixelShape
extends RefCounted
## Pixel-art rounded rectangles for the speech bubbles: a quarter-circle corner with stepped,
## whole-pixel edges, drawn as a few rectangles per shape (no antialiasing, no textures).


## How many pixels row `row` (0 = the top or bottom edge row) is pulled in on a corner of `radius`.
static func corner_inset(radius: int, row: int) -> int:
	if radius <= 0 or row >= radius:
		return 0
	var reach: float = sqrt(float(radius * radius - (radius - row) * (radius - row)))
	return radius - int(floor(reach))


## The x range [from, to) covered on row `y` of a rounded rect, or Vector2i.ZERO if y is outside it.
static func row_span(rect: Rect2i, radius: int, y: int) -> Vector2i:
	if y < rect.position.y or y >= rect.end.y:
		return Vector2i.ZERO
	var edge: int = mini(y - rect.position.y, rect.end.y - 1 - y)
	var inset: int = corner_inset(mini(radius, mini(rect.size.x, rect.size.y) / 2), edge)
	return Vector2i(rect.position.x + inset, rect.end.x - inset)


## Fills a rounded rectangle. The straight middle rows are drawn as one block.
static func fill(item: CanvasItem, rect: Rect2i, radius: int, color: Color) -> void:
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	var r: int = mini(radius, mini(rect.size.x, rect.size.y) / 2)
	for row: int in r:
		var inset: int = corner_inset(r, row)
		var width: int = rect.size.x - inset * 2
		if width <= 0:
			continue
		item.draw_rect(Rect2(rect.position.x + inset, rect.position.y + row, width, 1), color)
		item.draw_rect(Rect2(rect.position.x + inset, rect.end.y - 1 - row, width, 1), color)
	var middle: int = rect.size.y - r * 2
	if middle > 0:
		item.draw_rect(Rect2(rect.position.x, rect.position.y + r, rect.size.x, middle), color)


## Fills `rect` with `outline_color`, then the same shape pulled in by `outline` pixels with `fill_color`.
static func fill_outlined(item: CanvasItem, rect: Rect2i, radius: int, outline: int, outline_color: Color, fill_color: Color) -> void:
	fill(item, rect, radius, outline_color)
	fill(item, rect.grow(-outline), maxi(1, radius - outline), fill_color)
