extends SceneTree
## Renders every font candidate in the same sample (a Status-like card and a speech-bubble line)
## at the real 3x display scale, and writes a labeled comparison sheet.
## Needs a real renderer (not --headless):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##       -s res://tests/visual/capture_font_candidates.gd -- --dir=/path/to/downloaded/fonts
## Writes docs/screenshots/font_candidates.png (AA on) and font_candidates_aa.png (AA on vs off).
## The candidate files are SIL OFL fonts from google/fonts; --dir points at where they were downloaded.

const OUT: String = "res://../docs/screenshots/"
const PANEL: Vector2i = Vector2i(384, 150)
const SCALE: int = 3
const CANDIDATES: Array = [
	{"label": "Nunito ExtraBold (800)", "file": "Nunito.ttf", "axes": {"wght": 800}, "size": 12},
	{"label": "M PLUS Rounded 1c ExtraBold", "file": "MPlusRounded1c-ExtraBold.ttf", "axes": {}, "size": 12},
	{"label": "Varela Round", "file": "VarelaRound-Regular.ttf", "axes": {}, "size": 13},
	{"label": "Fredoka SemiBold (600)", "file": "Fredoka.ttf", "axes": {"wght": 600, "wdth": 100}, "size": 12},
	{"label": "Zen Maru Gothic Bold", "file": "ZenMaruGothic-Bold.ttf", "axes": {}, "size": 12},
	{"label": "Baloo 2 Bold (700)", "file": "Baloo2.ttf", "axes": {"wght": 700}, "size": 12},
]
const C_INK: Color = Color("#14121F")
const C_SHADOW: Color = Color("#0B0A14")
const C_CHALK: Color = Color("#EDEAD8")
const C_DIM: Color = Color("#7C7A8E")
const C_AMBER: Color = Color("#FFB347")
const C_BUBBLE_SHADOW: Color = Color("#B9B39A")

var _dir: String = ""


func _make_font(file: String, axes: Dictionary, aa: bool) -> Font:
	var base: FontFile = FontFile.new()
	base.load_dynamic_font(_dir.path_join(file))
	base.antialiasing = TextServer.FONT_ANTIALIASING_GRAY if aa else TextServer.FONT_ANTIALIASING_NONE
	base.hinting = TextServer.HINTING_NONE if aa else TextServer.HINTING_LIGHT
	base.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	if axes.is_empty():
		return base
	var variation: FontVariation = FontVariation.new()
	variation.base_font = base
	var coords: Dictionary = {}
	for axis: String in axes:
		coords[TextServerManager.get_primary_interface().name_to_tag(axis)] = axes[axis]
	variation.variation_opentype = coords
	return variation


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--dir="):
			_dir = arg.trim_prefix("--dir=")
	var panels_aa: Array[Image] = []
	var panels_noaa: Array[Image] = []
	for candidate: Dictionary in CANDIDATES:
		panels_aa.append(await _render_panel(candidate, true))
		panels_noaa.append(await _render_panel(candidate, false))
	await _save_sheet(panels_aa, "font_candidates.png", 2)
	var pairs: Array[Image] = []
	for i: int in [0, 1, 3]:
		pairs.append(panels_aa[i])
		pairs.append(panels_noaa[i])
	await _save_sheet(pairs, "font_candidates_aa.png", 2, ["AA on", "AA off"])
	quit(0)


func _text(parent: Control, font: Font, size: int, at: Vector2, text: String, color: Color, shadow: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	var drawer: Control = parent
	parent.draw.connect(func() -> void:
		drawer.draw_string(font, at + Vector2(1, 1), text, align, width, size, shadow)
		drawer.draw_string(font, at, text, align, width, size, color))


func _render_panel(candidate: Dictionary, aa: bool) -> Image:
	var font: Font = _make_font(str(candidate["file"]), candidate["axes"], aa)
	var size: int = int(candidate["size"])
	var viewport: SubViewport = SubViewport.new()
	viewport.size = PANEL
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color("#2A2F4E")
	backdrop.size = Vector2(PANEL)
	viewport.add_child(backdrop)
	var window: Control = (load("res://scripts/ui/ui_window.gd") as GDScript).new() as Control
	window.position = Vector2(4, 4)
	window.size = Vector2(376, 88)
	viewport.add_child(window)
	var canvas: Control = Control.new()
	canvas.size = Vector2(PANEL)
	viewport.add_child(canvas)
	canvas.draw.connect(func() -> void:
		canvas.draw_rect(Rect2(15, 15, 30, 30), C_SHADOW)
		canvas.draw_rect(Rect2(13, 13, 30, 30), C_CHALK)
		canvas.draw_rect(Rect2(14, 14, 28, 28), Color("#E0782B"))
		canvas.draw_rect(Rect2(51, 52, 80, 6), C_INK)
		canvas.draw_rect(Rect2(52, 53, 78, 4), Color("#3A3566"))
		canvas.draw_rect(Rect2(52, 53, 70, 4), Color("#FF7A59"))
		canvas.draw_rect(Rect2(51, 69, 80, 4), C_INK)
		canvas.draw_rect(Rect2(52, 70, 78, 2), Color("#3A3566"))
		canvas.draw_rect(Rect2(52, 70, 40, 2), Color("#9BE35A")))
	_text(canvas, font, size, Vector2(52, 25), "Otis", C_CHALK, C_SHADOW)
	_text(canvas, font, size, Vector2(52, 25), "Lv 3", C_DIM, C_SHADOW, HORIZONTAL_ALIGNMENT_RIGHT, 80)
	_text(canvas, font, size, Vector2(14, 60), "HP", C_AMBER, C_SHADOW)
	_text(canvas, font, size, Vector2(136, 60), "61/66", C_CHALK, C_SHADOW)
	_text(canvas, font, size, Vector2(14, 76), "Juice", C_AMBER, C_SHADOW)
	_text(canvas, font, size, Vector2(136, 76), "5/10", C_CHALK, C_SHADOW)
	var stats: Array = [["Attack", "14"], ["Defense", "11"], ["Speed", "6"], ["Heart", "9"]]
	for i: int in stats.size():
		var y: float = 24.0 + float(i) * 15.0
		_text(canvas, font, size, Vector2(190, y), stats[i][0], C_CHALK, C_SHADOW)
		_text(canvas, font, size, Vector2(190, y), stats[i][1], C_CHALK, C_SHADOW, HORIZONTAL_ALIGNMENT_RIGHT, 66)
	_text(canvas, font, size, Vector2(274, 25), "Weapon", C_DIM, C_SHADOW)
	_text(canvas, font, size, Vector2(274, 40), "Scrap Sword", C_CHALK, C_SHADOW)
	_text(canvas, font, size, Vector2(274, 58), "Armor", C_DIM, C_SHADOW)
	_text(canvas, font, size, Vector2(274, 73), "Patched Jacket", C_CHALK, C_SHADOW)
	# A speech bubble line, drawn the way the real bubble is (chalk body, ink text).
	var bubble: Control = Control.new()
	bubble.size = Vector2(PANEL)
	viewport.add_child(bubble)
	bubble.draw.connect(func() -> void:
		var shape: GDScript = load("res://scripts/ui/pixel_shape.gd") as GDScript
		shape.call("fill_outlined", bubble, Rect2i(40, 100, 300, 34), 5, 2, C_INK, C_CHALK)
		bubble.draw_rect(Rect2(60, 134, 8, 1), C_INK))
	_text(bubble, font, size, Vector2(50, 123), "Red! There you are. Welcome to the test room.", C_INK, C_BUBBLE_SHADOW)
	for i: int in 4:
		await process_frame
	var image: Image = viewport.get_texture().get_image()
	viewport.queue_free()
	return image


func _save_sheet(panels: Array[Image], file: String, columns: int, captions: Array = []) -> void:
	var rows: int = ceili(float(panels.size()) / float(columns))
	var cell: Vector2i = Vector2i(PANEL.x * SCALE, PANEL.y * SCALE + 36)
	var sheet: Image = Image.create(cell.x * columns, cell.y * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#0B0A14"))
	var labeler: SubViewport = SubViewport.new()
	labeler.size = Vector2i(cell.x, 36)
	labeler.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(labeler)
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", 22)
	label.position = Vector2(8, 4)
	labeler.add_child(label)
	for i: int in panels.size():
		var big: Image = panels[i].duplicate() as Image
		big.resize(PANEL.x * SCALE, PANEL.y * SCALE, Image.INTERPOLATE_NEAREST)
		var origin: Vector2i = Vector2i((i % columns) * cell.x, (i / columns) * cell.y)
		sheet.blit_rect(big, Rect2i(Vector2i.ZERO, big.get_size()), origin + Vector2i(0, 36))
		var name_index: int = i / (2 if not captions.is_empty() else 1)
		var text: String = str(CANDIDATES[name_index if captions.is_empty() else [0, 1, 3][name_index]]["label"])
		if not captions.is_empty():
			text += "  (%s)" % captions[i % 2]
		label.text = text
		var header: Image = await _grab(labeler)
		sheet.blit_rect(header, Rect2i(Vector2i.ZERO, header.get_size()), origin)
	labeler.queue_free()
	print("saved %s (%s)" % [file, sheet.get_size()])
	sheet.save_png(OUT + file)


func _grab(viewport: SubViewport) -> Image:
	await process_frame
	await process_frame
	return viewport.get_texture().get_image()
