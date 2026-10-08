extends SceneTree
## A strip of the digits 0-9 in the sandbox UI's candidate numeral fonts and sizes, white with the black
## 1-px down-right shadow, so a muddy digit (a counter filled by the shadow) shows up. Real renderer:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##       -s res://tests/visual/capture_ui_digits.gd
## Writes docs/screenshots/ui_digits_strip.png. Names no game classes.

const OUT: String = "res://../docs/screenshots/ui_digits_strip.png"
const DIR: String = "res://art/final/ui/fonts/"
const SIZE: Vector2i = Vector2i(320, 200)
const ROWS: Array[Array] = [
	["Jersey15-Regular.ttf", 20, 1], ["Jersey15-Regular.ttf", 30, 1],
	["DotGothic16-Regular.ttf", 16, 1], ["VT323-Regular.ttf", 16, 1], ["VT323-Regular.ttf", 18, 1], ["VT323-Regular.ttf", 20, 1], ["VT323-Regular.ttf", 22, 1], ["VT323-Regular.ttf", 24, 1], ["VT323-Regular.ttf", 32, 1],
	["Micro5-Regular.ttf", 20, 1],
]


class Strip extends Control:
	var rows: Array = []

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#1B2A6B"))
		var y: float = 2.0
		for row: Array in rows:
			var f: Font = row[0]
			var px: int = row[1]
			y += float(px) * 0.85 + 4.0
			var label: String = "%s %d" % [row[2], px]
			for pass_index: int in 2:
				var offset: Vector2 = Vector2(1, 1) if pass_index == 0 else Vector2.ZERO
				var color: Color = Color.BLACK if pass_index == 0 else Color.WHITE
				draw_string(f, Vector2(4, y) + offset, "0123456789  78 640 193/250", HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)
			draw_string(ThemeDB.fallback_font, Vector2(236, y), label.left(22), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("#9AA8D0"))


func _initialize() -> void:
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	var strip: Strip = Strip.new()
	strip.size = Vector2(SIZE)
	for row: Array in ROWS:
		var base: FontFile = load(DIR + str(row[0])) as FontFile
		base.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		base.hinting = TextServer.HINTING_NONE
		base.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		var variation: FontVariation = FontVariation.new()
		variation.base_font = base
		variation.spacing_glyph = int(row[2])
		strip.rows.append([variation, int(row[1]), str(row[0]).get_slice("-", 0)])
	root.add_child(strip)
	for i: int in 6:
		await process_frame
	var image: Image = root.get_texture().get_image()
	if image.get_size() != SIZE:
		image.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_NEAREST)
	image.resize(SIZE.x * 4, SIZE.y * 4, Image.INTERPOLATE_NEAREST)
	image.save_png(ProjectSettings.globalize_path(OUT))
	print("saved ", OUT)
	quit(0)
