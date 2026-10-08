extends SceneTree
## Font options, round 2 (Ross: "like Final Fantasy Tactics Advance: white font with a black drop shadow,
## a little bit stylized and offset, still video gamey"). Open-license pixel faces only, each set as the
## sandbox's menu bar, a HUD line and a line of dialogue in white with a solid black shadow one
## pixel down and right. No font here is a copy of any game's own font.
##   xvfb-run -a -s "-screen 0 1280x1080x24" godot --path game --rendering-driver opengl3 \
##       -s res://tests/visual/capture_ui_font_options_ffta.gd
## Writes docs/screenshots/ui_font_options_ffta.png. Names no game classes.

const OUT: String = "res://../docs/screenshots/ui_font_options_ffta.png"
const FONT_DIR: String = "res://art/final/ui/fonts/"
const SIZE: Vector2i = Vector2i(640, 540)
const CARDS: Array[Dictionary] = [
	{"name": "Pixelify Sans", "file": "PixelifySans-VariableFont_wght.ttf", "size": 16, "license": "SIL OFL 1.1", "note": "recommended; digits from Jersey 15", "skew": 0.0},
	{"name": "Jersey 15", "file": "Jersey15-Regular.ttf", "size": 16, "license": "SIL OFL 1.1", "note": "clean and tall; least stylized", "skew": 0.0},
	{"name": "Micro 5", "file": "Micro5-Regular.ttf", "size": 20, "license": "SIL OFL 1.1", "note": "light and rounded; small x-height", "skew": 0.0},
	{"name": "Jacquarda Bastarda 9", "file": "JacquardaBastarda9-Regular.ttf", "size": 18, "license": "SIL OFL 1.1", "note": "calligraphic fantasy; hard to read in menus", "skew": 0.0},
	{"name": "Handjet", "file": "Handjet-Variable.ttf", "size": 20, "license": "SIL OFL 1.1", "note": "hand-drawn flare; i-dots vanish at menu sizes", "skew": 0.0, "weight": 600},
	{"name": "Pixelify + slant (sample)", "file": "PixelifySans-VariableFont_wght.ttf", "size": 16, "license": "SIL OFL 1.1", "note": "slant sample, if 'offset' means leaning", "skew": 0.22, "weight": 500},
]

var _label_font: Font = null


class Sheet extends Control:
	var cards: Array[Dictionary] = []
	var label_font: Font = null
	var slant: float = 0.0

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#0B0A14"))
		for i: int in cards.size():
			_card(cards[i], Vector2(float(i % 2) * 320.0, float(i / 2) * 180.0))

	func _grad(rect: Rect2, top: Color, bottom: Color) -> void:
		draw_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]), PackedColorArray([top, top, bottom, bottom]))
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 1.0)), top.lerp(Color.WHITE, 0.3))
		draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - 1.0), Vector2(rect.size.x, 1.0)), bottom.lerp(Color.BLACK, 0.5))

	## White text, solid black shadow one pixel down and right.
	func _white(font: Font, px: int, at: Vector2, text: String, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
		if slant != 0.0:
			draw_set_transform_matrix(Transform2D(Vector2(1, 0), Vector2(-slant, 1), at))
			draw_string(font, Vector2(1, 1), text, align, width, px, Color.BLACK)
			draw_string(font, Vector2.ZERO, text, align, width, px, Color.WHITE)
			draw_set_transform_matrix(Transform2D.IDENTITY)
			return
		draw_string(font, at + Vector2(1, 1), text, align, width, px, Color.BLACK)
		draw_string(font, at, text, align, width, px, Color.WHITE)

	func _label(at: Vector2, text: String, tint: Color) -> void:
		draw_string(label_font, at + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.BLACK)
		draw_string(label_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, tint)

	func _triangle(at: Vector2) -> void:
		for i: int in 5:
			var rows: int = 9 - 2 * i
			draw_rect(Rect2(at.x + float(i), at.y + 4.0 - float(rows / 2), 1.0, float(rows)), Color("#FF9A2E"))

	func _card(card: Dictionary, origin: Vector2) -> void:
		var font: Font = card["font"]
		var px: int = int(card["size"])
		slant = float(card["skew"])
		var x: float = origin.x + 8.0
		var w: float = 304.0
		_label(Vector2(x, origin.y + 10.0), String(card["name"]).to_upper(), Color("#FFE08A"))
		_label(Vector2(x + w - 118.0, origin.y + 10.0), "LICENSE: " + String(card["license"]).to_upper(), Color("#8D97A5"))
		_grad(Rect2(x, origin.y + 15.0, w, 17.0), Color("#3FA08A"), Color("#1E6A5E"))
		_white(font, px, Vector2(x + 6.0, origin.y + 28.0), "ITEMS")
		_white(font, px, Vector2(x + w - 6.0 - 120.0, origin.y + 28.0), "MISC 11/64", HORIZONTAL_ALIGNMENT_RIGHT, 120.0)
		_grad(Rect2(x, origin.y + 35.0, w, 17.0), Color("#3A57B0"), Color("#1B2A6B"))
		_triangle(Vector2(x + 4.0, origin.y + 39.0))
		_white(font, px, Vector2(x + 16.0, origin.y + 48.0), "Cure Potion")
		_white(font, px, Vector2(x + w - 8.0 - 40.0, origin.y + 48.0), "5", HORIZONTAL_ALIGNMENT_RIGHT, 40.0)
		_grad(Rect2(x + 3.0, origin.y + 54.0, w - 3.0, 17.0), Color("#1C2658"), Color("#101839"))
		_white(font, px, Vector2(x + 19.0, origin.y + 67.0), "Antidote")
		_white(font, px, Vector2(x + w - 8.0 - 40.0, origin.y + 67.0), "12", HORIZONTAL_ALIGNMENT_RIGHT, 40.0)
		_label(Vector2(x + 2.0, origin.y + 82.0), "INFORMATION", Color("#6FD6EE"))
		_grad(Rect2(x, origin.y + 85.0, w, 17.0), Color("#1C2658"), Color("#101839"))
		_white(font, px, Vector2(x + 8.0, origin.y + 98.0), "Use an item.")
		_white(font, px, Vector2(x + 2.0, origin.y + 120.0), "HP 193/250")
		_grad(Rect2(x + 4.0, origin.y + 124.0, 110.0, 3.0), Color("#5FD0C0"), Color("#6C7A88"))
		_white(font, px, Vector2(x + 140.0, origin.y + 120.0), "MP 50/50")
		_grad(Rect2(x + 142.0, origin.y + 124.0, 80.0, 3.0), Color("#FF8AD0"), Color("#B0408A"))
		draw_rect(Rect2(x, origin.y + 132.0, w, 22.0), Color(0.04, 0.04, 0.09, 0.9))
		_white(font, px, Vector2(x + 8.0, origin.y + 148.0), "Here we go... stay behind me.")
		_label(Vector2(x, origin.y + 168.0), String(card["note"]).to_upper(), Color("#7C8AB0"))


func _initialize() -> void:
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	var sheet: Sheet = Sheet.new()
	sheet.size = Vector2(SIZE)
	sheet.label_font = _pixel("Silkscreen-Regular.ttf", 1, 0)
	for card: Dictionary in CARDS:
		var entry: Dictionary = card.duplicate()
		entry["font"] = _pixel(str(card["file"]), 0, int(card.get("weight", 0)))
		sheet.cards.append(entry)
	root.add_child(sheet)
	for i: int in 6:
		await process_frame
	var image: Image = root.get_texture().get_image()
	if image.get_size() != SIZE:
		image.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_NEAREST)
	image.resize(SIZE.x * 2, SIZE.y * 2, Image.INTERPOLATE_NEAREST)
	image.save_png(ProjectSettings.globalize_path(OUT))
	print("saved ", ProjectSettings.globalize_path(OUT))
	quit(0)


func _pixel(file: String, spacing: int, weight: int) -> Font:
	var base: FontFile = load(FONT_DIR + file) as FontFile
	base.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	base.hinting = TextServer.HINTING_NONE
	base.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	var variation: FontVariation = FontVariation.new()
	variation.base_font = base
	variation.spacing_glyph = spacing
	if weight > 0:
		variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): float(weight)}
	return variation
