extends SceneTree
## Font options for the sandbox UI (Ross's Vagrant Story reference): open-license pixel fonts set
## as a menu bar and a HUD line, with the same two-tone fill and drop shadow the sandbox UI uses.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##       -s res://tests/visual/capture_ui_font_options.gd
## Writes docs/screenshots/ui_font_options.png. Names no game classes.

const OUT: String = "res://../docs/screenshots/ui_font_options.png"
const FONT_DIR: String = "res://art/final/ui/fonts/"
const LABEL_FONT: String = "Silkscreen-Regular.ttf"
const CARDS: Array[Dictionary] = [
	{"name": "Jersey 15", "file": "Jersey15-Regular.ttf", "size": 20, "license": "SIL OFL 1.1 (Google Fonts)", "note": "chunky, tall; shown at 20 px"},
	{"name": "DotGothic16", "file": "DotGothic16-Regular.ttf", "size": 16, "license": "SIL OFL 1.1 (Google Fonts)", "note": "crisp, even, clean; shown at 16 px (best match)"},
	{"name": "VT323", "file": "VT323-Regular.ttf", "size": 20, "license": "SIL OFL 1.1 (Google Fonts)", "note": "thin, tall terminal look; shown at 20 px"},
	{"name": "Pixelify Sans", "file": "PixelifySans-VariableFont_wght.ttf", "size": 16, "license": "SIL OFL 1.1 (already in the project)", "note": "round and friendly; shown at 16 px"},
]
const SIZE: Vector2i = Vector2i(640, 360)

var _label_font: Font = null


class Sheet extends Control:
	var cards: Array[Dictionary] = []
	var label_font: Font = null

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#0B0A14"))
		for i: int in cards.size():
			_card(cards[i], Vector2(float(i % 2) * 320.0, float(i / 2) * 180.0))

	func _grad(rect: Rect2, top: Color, bottom: Color) -> void:
		for y: int in int(rect.size.y):
			draw_rect(Rect2(rect.position.x, rect.position.y + float(y), rect.size.x, 1.0), top.lerp(bottom, float(y) / maxf(1.0, rect.size.y - 1.0)))
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 1.0)), top.lerp(Color.WHITE, 0.35))
		draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - 1.0), Vector2(rect.size.x, 1.0)), bottom.lerp(Color.BLACK, 0.5))

	func _text(font: Font, px: int, at: Vector2, text: String, light: Color, body: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
		draw_string(font, at + Vector2(1, 1), text, align, width, px, Color("#05040C"))
		draw_string(font, at, text, align, width, px, body)

	func _text_r(font: Font, px: int, right_x: float, y: float, text: String, light: Color, body: Color, width: float = 140.0) -> void:
		_text(font, px, Vector2(right_x - width, y), text, light, body, HORIZONTAL_ALIGNMENT_RIGHT, width)

	func _triangle(at: Vector2, color: Color, pointing_right: bool = true) -> void:
		for i: int in 5:
			var x: float = at.x + (float(i) if pointing_right else float(4 - i))
			draw_rect(Rect2(x, at.y + float(i) * 0.0 + float(i) * -0.0, 1.0, 1.0), color)
		for i: int in 5:
			var half: int = 4 - i
			var x2: float = at.x + (float(i) if pointing_right else float(4 - i))
			draw_rect(Rect2(x2, at.y + 4.0 - float(half), 1.0, float(half * 2 + 1)), color)

	func _card(card: Dictionary, origin: Vector2) -> void:
		var font: Font = card["font"]
		var px: int = int(card["size"])
		var x: float = origin.x + 10.0
		var w: float = 300.0
		# card title
		_text(label_font, 8, Vector2(x, origin.y + 12.0), String(card["name"]).to_upper(), Color("#FFE08A"), Color("#FFB347"))
		_text_r(label_font, 8, origin.x + 310.0, origin.y + 12.0, String(card["license"]).to_upper(), Color("#8D97A5"), Color("#5B6573"), 200.0)
		# header bar (teal-green)
		_grad(Rect2(x, origin.y + 18.0, w, 16.0), Color("#3FA08A"), Color("#1E6A5E"))
		_text(label_font, 8, Vector2(x + 6.0, origin.y + 29.0), "ITEMS", Color("#E8FFF6"), Color("#C9F2E4"))
		_text_r(font, px, x + w - 6.0, origin.y + 31.0, "MISC 11/64", Color("#E8FFF6"), Color("#C9F2E4"), 120.0)
		# list bars (navy to blue), stacked with a small offset
		var rows: Array[Array] = [["Cure Potion", "5", true], ["Antidote", "12", false], ["Bread Knife", "1", false]]
		for r: int in rows.size():
			var y: float = origin.y + 37.0 + float(r) * 19.0
			var row_x: float = x + float(r) * 3.0
			var selected: bool = bool(rows[r][2])
			_grad(Rect2(row_x, y, w - float(r) * 3.0, 17.0), Color("#3A57B0") if selected else Color("#1C2658"), Color("#1B2A6B") if selected else Color("#101839"))
			var light: Color = Color("#F4FFB0") if selected else Color("#FFFFFF")
			var body: Color = Color("#C8E85A") if selected else Color("#C9CCD6")
			if selected:
				_triangle(Vector2(row_x + 4.0, y + 6.0), Color("#FF9A2E"))
			_text(font, px, Vector2(row_x + 14.0, y + 14.0), String(rows[r][0]), light, body)
			_text_r(font, px, row_x + w - float(r) * 3.0 - 8.0, y + 14.0, String(rows[r][1]), light, body, 40.0)
		# info bar
		_text(label_font, 8, Vector2(x + 2.0, origin.y + 107.0), "INFORMATION", Color("#7FE0FF"), Color("#4DB8D8"))
		_grad(Rect2(x, origin.y + 110.0, w, 17.0), Color("#1C2658"), Color("#101839"))
		_text(font, px, Vector2(x + 8.0, origin.y + 124.0), "Use an item.", Color("#FFFFFF"), Color("#C9CCD6"))
		# HUD line
		_text(font, px, Vector2(x + 2.0, origin.y + 148.0), "HP 193/250", Color("#FFFFFF"), Color("#C9CCD6"))
		_grad(Rect2(x + 4.0, origin.y + 152.0, 110.0, 3.0), Color("#5FD0C0"), Color("#6C7A88"))
		_text(font, px, Vector2(x + 140.0, origin.y + 148.0), "MP 50/50", Color("#FFFFFF"), Color("#C9CCD6"))
		_grad(Rect2(x + 142.0, origin.y + 152.0, 80.0, 3.0), Color("#FF8AD0"), Color("#B0408A"))
		_text(label_font, 8, Vector2(x + 2.0, origin.y + 170.0), String(card["note"]).to_upper(), Color("#8D97A5"), Color("#5B6573"))


func _initialize() -> void:
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	var sheet: Sheet = Sheet.new()
	sheet.size = Vector2(SIZE)
	sheet.label_font = _pixel(LABEL_FONT, 0)
	for card: Dictionary in CARDS:
		var entry: Dictionary = card.duplicate()
		entry["font"] = _pixel(str(card["file"]), 1)
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


func _pixel(file: String, spacing: int) -> Font:
	var base: FontFile = load(FONT_DIR + file) as FontFile
	base.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	base.hinting = TextServer.HINTING_NONE
	base.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	var variation: FontVariation = FontVariation.new()
	variation.base_font = base
	variation.spacing_glyph = spacing
	return variation
