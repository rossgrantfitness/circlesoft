class_name SandboxStyle
extends RefCounted
## The one place that knows what the sandbox UI looks like. Everything visual (fonts, sizes, colors,
## bar and frame constants) comes from ONE Theme resource, art/placeholder/ui/sandbox_theme.tres (built
## by scripts/tools/make_sandbox_theme.gd; its path is "theme_path" in data/ui/sandbox_ui.json), so the
## look can be swapped after Ross reviews it by replacing that file. Layout and words are data.
##
## Direction (Ross, Vagrant Story menus and HUD): stacked horizontal navy-to-blue bars, teal-green
## header bars, yellow-green selected text, a solid orange triangle cursor, cyan triangle arrows, a tall
## wide-spaced pixel font with a dark drop shadow, thin gradient HUD bars, and (DMC1's idea, done in
## riveted grim metal) a framed gauge for Noise. Every helper draws onto a CanvasItem inside its
## _draw callback, at whole pixels.

const TYPE: StringName = &"SandboxUi"
const THEME_KEY: String = "theme_path"
const GRADIENT_STEPS_MIN: int = 2

static var _theme: Theme = null


## The Theme (loaded once; call reload() after changing the file in a test).
static func theme() -> Theme:
	if _theme == null:
		_theme = load(str(SandboxUiData.ui(THEME_KEY, "res://art/placeholder/ui/sandbox_theme.tres"))) as Theme
	return _theme


static func reload() -> void:
	_theme = null


static func set_theme(value: Theme) -> void:
	_theme = value


# ---- theme reads ----

static func font(role: String) -> Font:
	return theme().get_font(StringName(_role(role)), TYPE)


static func font_size(role: String) -> int:
	return theme().get_font_size(StringName(_role(role)), TYPE)


## True when the theme's whole-font fallback (Jersey 15, upright) is switched on.
static func uses_fallback_font() -> bool:
	return theme().get_constant(&"use_fallback_font", TYPE) != 0


## The role as asked, or its "_fallback" twin when the fallback switch is on (the label font never changes).
static func _role(role: String) -> String:
	if role != "label" and uses_fallback_font() and theme().has_font(StringName(role + "_fallback"), TYPE):
		return role + "_fallback"
	return role


## How far letters lean (0 = upright). The label font and the fallback font stay upright.
static func slant(role: String) -> float:
	if role == "label" or uses_fallback_font():
		return 0.0
	return float(theme().get_constant(&"slant_pct", TYPE)) / 100.0


static func color(name: String) -> Color:
	return theme().get_color(StringName(name), TYPE)


static func const_int(name: String) -> int:
	return theme().get_constant(StringName(name), TYPE)


## Pixel width of a string in a role's font.
static func text_width(role: String, text: String) -> float:
	return font(role).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size(role)).x


## Height of a line of that role (ascent + descent).
static func line_height(role: String) -> float:
	return font(role).get_height(font_size(role))


# ---- text ----

## A string with the drop shadow (and, when the theme asks for it, a light top row). `at` is the
## left end of the baseline; with an alignment and `width`, `at.x` is the left edge of the box.
static func text(canvas: CanvasItem, role: String, at: Vector2, text_value: String, tint: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	if text_value.is_empty():
		return
	var f: Font = font(role)
	var px: int = font_size(role)
	var shadow: Vector2 = Vector2(float(const_int("shadow_x")), float(const_int("shadow_y")))
	var lean: float = slant(role)
	if lean != 0.0:
		# Leaning letters: shear the canvas around the baseline's left end, then draw upright.
		canvas.draw_set_transform_matrix(Transform2D(Vector2(1, 0), Vector2(-lean, 1), at))
		canvas.draw_string(f, shadow, text_value, align, width, px, color("shadow"))
		canvas.draw_string(f, Vector2.ZERO, text_value, align, width, px, tint)
		canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
		return
	canvas.draw_string(f, at + shadow, text_value, align, width, px, color("shadow"))
	if const_int("top_light") > 0:
		canvas.draw_string(f, at, text_value, align, width, px, color("text_light"))
		canvas.draw_string(f, at + Vector2(0, 1), text_value, align, width, px, tint)
	else:
		canvas.draw_string(f, at, text_value, align, width, px, tint)


## Right-aligned text whose right end is at `right_x`.
static func text_right(canvas: CanvasItem, role: String, right_x: float, baseline_y: float, text_value: String, tint: Color, box_width: float = 160.0) -> void:
	text(canvas, role, Vector2(right_x - box_width, baseline_y), text_value, tint, HORIZONTAL_ALIGNMENT_RIGHT, box_width)


## Centered text in a box starting at `left_x`.
static func text_center(canvas: CanvasItem, role: String, left_x: float, baseline_y: float, text_value: String, tint: Color, box_width: float) -> void:
	text(canvas, role, Vector2(left_x, baseline_y), text_value, tint, HORIZONTAL_ALIGNMENT_CENTER, box_width)


## A caps label ("INFORMATION") in the small label font.
static func label(canvas: CanvasItem, at: Vector2, text_value: String, tint: Color = Color(0, 0, 0, 0)) -> void:
	text(canvas, "label", at, text_value.to_upper(), tint if tint.a > 0.0 else color("label"))


# ---- bars and plates ----

## A vertical gradient rectangle (top color to bottom color) with crisp whole-pixel edges.
static func gradient(canvas: CanvasItem, rect: Rect2, top: Color, bottom: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	var colors: PackedColorArray = PackedColorArray([top, top, bottom, bottom])
	canvas.draw_polygon(points, colors)


## One bar of a stack: a gradient with a light top edge and a dark bottom edge.
static func bar(canvas: CanvasItem, rect: Rect2, top: Color, bottom: Color) -> void:
	gradient(canvas, rect, top, bottom)
	canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 1.0)), top.lerp(Color.WHITE, float(const_int("edge_light_pct")) / 100.0))
	canvas.draw_rect(Rect2(rect.position + Vector2(0.0, rect.size.y - 1.0), Vector2(rect.size.x, 1.0)), bottom.lerp(Color.BLACK, float(const_int("edge_dark_pct")) / 100.0))


## A list bar. `selected` is the bright blue one with the cursor; `off` is a dimmed (inactive) bar.
static func list_bar(canvas: CanvasItem, rect: Rect2, selected: bool = false, off: bool = false) -> void:
	if selected:
		bar(canvas, rect, color("bar_sel_top"), color("bar_sel_bottom"))
	elif off:
		bar(canvas, rect, color("bar_off_top"), color("bar_off_bottom"))
	else:
		bar(canvas, rect, color("bar_top"), color("bar_bottom"))


## A teal-green header bar.
static func header_bar(canvas: CanvasItem, rect: Rect2) -> void:
	bar(canvas, rect, color("header_top"), color("header_bottom"))


## The text color for a list row.
static func row_color(selected: bool, enabled: bool = true) -> Color:
	if not enabled:
		return color("text_dim")
	return color("text_selected") if selected else color("text")


# ---- cursor and arrows ----

## The solid orange triangle cursor, pointing right; `center` is the middle of its left edge.
static func cursor(canvas: CanvasItem, center: Vector2) -> void:
	var w: int = const_int("cursor_w")
	var h: int = const_int("cursor_h")
	var edge: Color = color("cursor_edge")
	var fill: Color = color("cursor")
	for i: int in w:
		var rows: int = maxi(1, h - 2 * i)
		var top: float = center.y - float(rows / 2)
		canvas.draw_rect(Rect2(center.x + float(i), top - 1.0, 1.0, float(rows) + 2.0), edge)
	canvas.draw_rect(Rect2(center.x + float(w), center.y, 1.0, 1.0), edge)
	canvas.draw_rect(Rect2(center.x - 1.0, center.y - float(h / 2), 1.0, float(h)), edge)
	for i: int in w:
		var rows2: int = maxi(1, h - 2 * i)
		canvas.draw_rect(Rect2(center.x + float(i), center.y - float(rows2 / 2), 1.0, float(rows2)), fill)


## A small cyan triangle arrow. `direction`: Vector2i.UP / DOWN / LEFT / RIGHT. `center` is its middle.
static func arrow(canvas: CanvasItem, center: Vector2, direction: Vector2i, tint: Color = Color(0, 0, 0, 0)) -> void:
	var paint: Color = tint if tint.a > 0.0 else color("arrow")
	var n: int = const_int("arrow_size")
	for i: int in n:
		var span: float = float(i * 2 + 1)
		var along: float = float(i)
		if direction == Vector2i.DOWN:
			canvas.draw_rect(Rect2(center.x - float(i), center.y - float(n) / 2.0 + along, span, 1.0), paint)
		elif direction == Vector2i.UP:
			canvas.draw_rect(Rect2(center.x - float(i), center.y + float(n) / 2.0 - along - 1.0, span, 1.0), paint)
		elif direction == Vector2i.RIGHT:
			canvas.draw_rect(Rect2(center.x - float(n) / 2.0 + along, center.y - float(i), 1.0, span), paint)
		else:
			canvas.draw_rect(Rect2(center.x + float(n) / 2.0 - along - 1.0, center.y - float(i), 1.0, span), paint)


# ---- thin HUD bars ----

## The thin gradient bar under a HUD number. `chip` (> fill) draws a pale trailing chip behind the fill.
static func thin_bar(canvas: CanvasItem, rect: Rect2, fill: float, top: Color, bottom: Color, chip: float = -1.0) -> void:
	canvas.draw_rect(rect.grow(1.0), color("track_edge"))
	canvas.draw_rect(rect, color("track"))
	if chip > fill:
		canvas.draw_rect(Rect2(rect.position, Vector2(floorf(rect.size.x * clampf(chip, 0.0, 1.0)), rect.size.y)), color("hp_chip"))
	var fill_w: float = floorf(rect.size.x * clampf(fill, 0.0, 1.0))
	if fill_w > 0.0:
		gradient(canvas, Rect2(rect.position, Vector2(fill_w, rect.size.y)), top, bottom)


# ---- the riveted metal frame (the Noise gauge) ----

## A riveted metal frame around `inner`. Returns the inner rectangle it leaves for the gauge.
static func metal_frame(canvas: CanvasItem, outer: Rect2) -> Rect2:
	var border: float = float(const_int("frame_border"))
	canvas.draw_rect(outer.grow(1.0), color("shadow"))
	canvas.draw_rect(outer, color("metal_mid"))
	canvas.draw_rect(Rect2(outer.position, Vector2(outer.size.x, 1.0)), color("metal_light"))
	canvas.draw_rect(Rect2(outer.position, Vector2(1.0, outer.size.y)), color("metal_light"))
	canvas.draw_rect(Rect2(outer.position + Vector2(0.0, outer.size.y - 1.0), Vector2(outer.size.x, 1.0)), color("metal_dark"))
	canvas.draw_rect(Rect2(outer.position + Vector2(outer.size.x - 1.0, 0.0), Vector2(1.0, outer.size.y)), color("metal_dark"))
	var inner: Rect2 = outer.grow(-border)
	canvas.draw_rect(inner.grow(1.0), color("metal_dark"))
	var rivet: float = float(const_int("rivet_size"))
	var inset: float = 1.0
	for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var x: float = outer.position.x + inset if corner.x == 0.0 else outer.end.x - inset - rivet
		var y: float = outer.position.y + inset if corner.y == 0.0 else outer.end.y - inset - rivet
		canvas.draw_rect(Rect2(x, y, rivet, rivet), color("rivet"))
	return inner


# ---- a small lamp icon (Lights On, Lamp Flare) ----

const BULB_ROWS: Array[String] = [
	"..XXX..",
	".XXXXX.",
	"XXXXXXX",
	"XXXXXXX",
	".XXXXX.",
	"..XXX..",
	"..ooo..",
	"..ooo..",
]


static func bulb(canvas: CanvasItem, at: Vector2, lit: bool, glass_color: Color) -> void:
	var glass: Color = glass_color if lit else color("label_dim")
	for y: int in BULB_ROWS.size():
		var row: String = BULB_ROWS[y]
		for x: int in row.length():
			var cell: String = row[x]
			if cell == "X":
				canvas.draw_rect(Rect2(at + Vector2(float(x), float(y)), Vector2.ONE), glass)
			elif cell == "o":
				canvas.draw_rect(Rect2(at + Vector2(float(x), float(y)), Vector2.ONE), color("metal_mid"))
	if lit:
		canvas.draw_rect(Rect2(at + Vector2(-2.0, 2.0), Vector2(1.0, 2.0)), glass)
		canvas.draw_rect(Rect2(at + Vector2(8.0, 2.0), Vector2(1.0, 2.0)), glass)
