class_name OffsetStat
extends RefCounted
## The staggered number readout used for HP, the Noise score and "x / y" counts: a small label raised a
## little, the big current value sitting on the baseline, then a smaller slash and max value dropped
## lower, so the numbers deliberately do not line up ("Hp 78 /120"). Layout idea only, drawn from our
## own theme fonts. Sizes are the theme's stat_label / stat_big / stat_small font sizes; the raise, the
## drop and the gap are the theme constants stat_label_raise, stat_slash_drop and stat_gap, so it can be
## tuned (or flattened by setting both offsets to 0) without touching code.
##
## `at` is the left end of the BIG number's baseline when drawing left-aligned, or the right end of the
## whole readout when `align_right` is true. Returns the readout's width in pixels.

const SLASH: String = "/"


## Width of the whole readout. `max_text` empty means a plain number (no slash).
static func measure(label: String, current: String, max_text: String = "") -> float:
	var width: float = 0.0
	var gap: float = float(SandboxStyle.const_int("stat_gap"))
	if not label.is_empty():
		width += SandboxStyle.text_width("stat_label", label) + gap
	width += SandboxStyle.text_width("stat_big", current)
	if not max_text.is_empty():
		width += gap + SandboxStyle.text_width("stat_small", SLASH + max_text)
	return width


## Draws the readout. Returns its width.
static func draw(canvas: CanvasItem, at: Vector2, label: String, current: String, max_text: String, tint: Color, align_right: bool = false, label_tint: Color = Color(0, 0, 0, 0)) -> float:
	var width: float = measure(label, current, max_text)
	var x: float = at.x - width if align_right else at.x
	var gap: float = float(SandboxStyle.const_int("stat_gap"))
	if not label.is_empty():
		var raise: float = float(SandboxStyle.const_int("stat_label_raise"))
		SandboxStyle.text(canvas, "stat_label", Vector2(x, at.y - raise), label, label_tint if label_tint.a > 0.0 else tint)
		x += SandboxStyle.text_width("stat_label", label) + gap
	SandboxStyle.text(canvas, "stat_big", Vector2(x, at.y), current, tint)
	x += SandboxStyle.text_width("stat_big", current)
	if not max_text.is_empty():
		var drop: float = float(SandboxStyle.const_int("stat_slash_drop"))
		SandboxStyle.text(canvas, "stat_small", Vector2(x + gap, at.y + drop), SLASH + max_text, tint)
	return width
