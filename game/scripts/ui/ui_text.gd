class_name UiText
extends RefCounted
## The reusable text style: the font for a key plus the 1px drop shadow from ui_theme.json
## ("text_shadow"). Use style_label() for Labels and draw() for strings drawn with a CanvasItem,
## so every piece of UI text has the same shadow.

const THEME_ID: String = "ui/ui_theme"


static func shadow_color(on_light: bool = false) -> Color:
	var key: String = "text_shadow.on_light" if on_light else "text_shadow.color"
	return Color.html(str(DataDB.get_value(THEME_ID, key, "#0B0A14")))


static func shadow_offset() -> Vector2i:
	return Vector2i(int(DataDB.get_value(THEME_ID, "text_shadow.offset_x", 1)), int(DataDB.get_value(THEME_ID, "text_shadow.offset_y", 1)))


## Font, size, color and drop shadow for a Label.
static func style_label(label: Label, font_key: String, color: Color, on_light: bool = false) -> void:
	label.add_theme_font_override("font", UiFonts.get_font(font_key))
	label.add_theme_font_size_override("font_size", UiFonts.get_size(font_key))
	label.add_theme_color_override("font_color", color)
	apply_shadow(label, on_light)
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Just the drop shadow (a Label that already has its font).
static func apply_shadow(label: Label, on_light: bool = false) -> void:
	var offset: Vector2i = shadow_offset()
	label.add_theme_color_override("font_shadow_color", shadow_color(on_light))
	label.add_theme_constant_override("shadow_offset_x", offset.x)
	label.add_theme_constant_override("shadow_offset_y", offset.y)


## Draws a string with its shadow. `position` is the baseline's left end (like draw_string).
static func draw(canvas: CanvasItem, font_key: String, position: Vector2, text: String, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0, on_light: bool = false) -> void:
	var font: Font = UiFonts.get_font(font_key)
	var size: int = UiFonts.get_size(font_key)
	var offset: Vector2i = shadow_offset()
	canvas.draw_string(font, position + Vector2(offset), text, align, width, size, shadow_color(on_light))
	canvas.draw_string(font, position, text, align, width, size, color)
