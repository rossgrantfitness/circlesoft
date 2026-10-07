class_name MenuDraw
extends RefCounted
## Drawing helpers shared by the field menu pages and the shop: colors (the UI palette plus the few
## menu colors in data/ui/field_menu.json "colors"), the placeholder initial-head portrait, HP and
## Juice bars with numbers, stat-change arrows and small formatting helpers.
## Placeholder art only: the real 24x24 heads and 96x96 portraits are in docs/art_requests.md.

const THEME_ID: String = "ui/ui_theme"
const LAYOUT_ID: String = "ui/field_menu"
const ARROW_UP: int = 1
const ARROW_DOWN: int = -1
const ARROW_SAME: int = 0

static var _colors: Dictionary[String, Color] = {}


## A palette color (ui_theme.json) or a menu color (field_menu.json "colors"), by name.
static func color(key: String) -> Color:
	if _colors.is_empty():
		_load_colors()
	return _colors.get(key, Color.MAGENTA)


static func clear_cache() -> void:
	_colors.clear()


static func _load_colors() -> void:
	var palette: Dictionary = DataDB.get_value(THEME_ID, "palette", {})
	for key: String in palette:
		_colors[key] = Color.html(str(palette[key]))
	var extra: Dictionary = DataDB.get_value(LAYOUT_ID, "colors", {})
	for key: String in extra:
		_colors[key] = Color.html(str(extra[key]))


## Placeholder portrait: a framed tile in the member's accent color with their initial.
static func portrait(canvas: CanvasItem, member: Dictionary, at: Vector2i, tile: int, initial_size: int, dim: bool = false) -> void:
	var fade: Color = Color(1, 1, 1, 0.45 if dim else 1.0)
	canvas.draw_rect(Rect2(at.x + 1, at.y + 1, tile, tile), color("ink") * fade)
	canvas.draw_rect(Rect2(at.x - 1, at.y - 1, tile + 2, tile + 2), color("chalk") * fade)
	canvas.draw_rect(Rect2(at.x, at.y, tile, tile), Color.html(str(member.get("accent", "#888888"))) * fade)
	var font: Font = UiFonts.get_font("title")
	canvas.draw_string(font, Vector2(at.x, at.y + (tile + initial_size) / 2 - 3), str(member.get("initial", "?")),
			HORIZONTAL_ALIGNMENT_CENTER, tile, initial_size, color("ink") * fade)


## A label, a bar and "now/max". `at` is (left edge, text baseline); the bar sits just under the text
## when `bar_below` is true, else after the label.
static func bar_row(canvas: CanvasItem, at: Vector2i, label: String, value: int, maximum: int, fill: Color, thickness: int, width: int, bar_below: bool = false, label_w: int = 36) -> void:
	var bar_x: int = at.x if bar_below else at.x + label_w
	var bar_w: int = width if bar_below else width - label_w - 44
	var y: int = at.y + 3 if bar_below else at.y - 4 - thickness / 2
	UiText.draw(canvas, "menu", Vector2(at.x, at.y), label, color("text_dim"))
	UiText.draw(canvas, "menu", Vector2(0, at.y), "%d/%d" % [value, maximum], color("text"), HORIZONTAL_ALIGNMENT_RIGHT, at.x + width)
	canvas.draw_rect(Rect2(bar_x - 1, y - 1, bar_w + 2, thickness + 2), color("ink"))
	canvas.draw_rect(Rect2(bar_x, y, bar_w, thickness), color("dusk"))
	var filled: int = int(round(float(bar_w) * float(value) / float(maxi(1, maximum))))
	canvas.draw_rect(Rect2(bar_x, y, filled, thickness), fill)


## A solid triangle arrow: up (green) or down (coral) with an Ink shadow. `at` is the top-left of a
## 7x4 box.
static func arrow(canvas: CanvasItem, at: Vector2i, direction: int) -> void:
	if direction == ARROW_SAME:
		return
	var tint: Color = color("up") if direction == ARROW_UP else color("down")
	for pass_index: int in 2:
		var offset: int = 1 - pass_index
		var paint: Color = color("ink") if pass_index == 0 else tint
		for row: int in 4:
			var half: int = row if direction == ARROW_UP else 3 - row
			canvas.draw_rect(Rect2(at.x + 3 - half + offset, at.y + row + offset, half * 2 + 1, 1), paint)


## +1 / -1 / 0 for comparing a new stat value against the current one.
static func direction_of(now: int, then: int) -> int:
	return signi(now - then)


## 3725 -> "1:02:05" (hours:minutes:seconds), minutes padded.
static func format_time(seconds: int) -> String:
	var total: int = maxi(0, seconds)
	return "%d:%02d:%02d" % [total / 3600, (total / 60) % 60, total % 60]


## 1234567 -> "1,234,567".
static func format_number(value: int) -> String:
	var digits: String = str(absi(value))
	var out: String = ""
	var count: int = 0
	for i: int in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if value < 0 else "") + out
