extends SceneTree
## Screenshots of every Red style prototype (docs/red_style_prototypes.md), in the real PSX look.
## Needs a real renderer (not --headless):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##       -s res://tests/visual/capture_red_prototypes.gd
## Works with however many red_proto_<letter>.glb files exist (3, 5, ...). Writes to
## docs/screenshots/red_prototypes/ (path is relative to the game/ folder):
##   <letter>_front.png, <letter>_34.png, <letter>_side.png, <letter>_back.png   close, Red alone
##   <letter>_grin.png                                                           close, grin face cell
##   <letter>_ingame.png          the room's real camera, Red beside the 0.8 crate
##   <letter>_ingame_gray.png     same, grayscale (does she separate without color?)
##   <letter>_silhouette.png      same, solid Ink (can you tell who she is?)
##   contact_sheet.png            all prototypes side by side: 3/4, in-game, silhouette, labeled
## Every picture is the 384x216 PSX screen scaled up 3x with nearest-neighbor.

const STAGE_SCENE: String = "res://scenes/debug/style_stage.tscn"
const OUTPUT_DIR: String = "res://../docs/screenshots/red_prototypes/"
const SETTLE_FRAMES: int = 5
const CLOSE_VIEWS: PackedStringArray = ["front", "34", "side", "back"]

# Contact sheet layout (pixels of the 3x pictures).
const COLUMN_WIDTH: int = 576
const ROW_LABEL_WIDTH: int = 170
const HEADER_HEIGHT: int = 64
const CLOSE_ROW_HEIGHT: int = 648
const INGAME_ROW_HEIGHT: int = 216
const GAP: int = 4
const SHEET_BACKGROUND: Color = Color(0.0784, 0.0706, 0.1216)
const SHEET_LINE: Color = Color(0.227, 0.208, 0.4)
const LABEL_COLOR: Color = Color(0.93, 0.92, 0.85)
const LABEL_FONT: String = "res://art/final/ui/fonts/PixelifySans-VariableFont_wght.ttf"
const HEADER_FONT_SIZE: int = 34
const ROW_FONT_SIZE: int = 22

## The stage is a plain Node here (calls go through call()) so this script compiles before the
## autoloads exist, like the other capture scripts.
var _stage: Node = null
var _failures: int = 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_stage = (load(STAGE_SCENE) as PackedScene).instantiate()
	root.add_child(_stage)
	await _settle()
	var letters: Array[String] = []
	letters.assign(_stage.call("available_prototypes"))
	if letters.is_empty():
		push_error("capture_red_prototypes: no red_proto_*.glb found")
		quit(1)
		return
	print("prototypes: ", letters)
	_stage.call("frame_for", letters)
	var sheet_close: Dictionary[String, Image] = {}
	var sheet_ingame: Dictionary[String, Image] = {}
	var sheet_silhouette: Dictionary[String, Image] = {}
	for letter: String in letters:
		if not _stage.call("load_prototype", letter):
			_failures += 1
			continue
		_stage.call("set_expression", false)
		_stage.call("set_silhouette", false)
		for view: String in CLOSE_VIEWS:
			_stage.call("show_close", view)
			var image: Image = await _grab()
			_save(image, "%s_%s" % [letter, view])
			if view == "34":
				sheet_close[letter] = image
		_stage.call("show_close", "front")
		_stage.call("set_expression", true)
		_save(await _grab(), "%s_grin" % letter)
		_stage.call("set_expression", false)
		_stage.call("show_ingame")
		var ingame: Image = await _grab()
		_save(ingame, "%s_ingame" % letter)
		sheet_ingame[letter] = ingame
		var gray: Image = ingame.duplicate()
		gray.convert(Image.FORMAT_L8)
		gray.convert(Image.FORMAT_RGB8)
		_save(gray, "%s_ingame_gray" % letter)
		_stage.call("set_silhouette", true)
		var silhouette: Image = await _grab()
		_save(silhouette, "%s_silhouette" % letter)
		sheet_silhouette[letter] = silhouette
		_stage.call("set_silhouette", false)
	await _contact_sheet(letters, sheet_close, sheet_ingame, sheet_silhouette)
	quit(0 if _failures == 0 else 1)


func _settle() -> void:
	for i: int in SETTLE_FRAMES:
		await process_frame


func _grab() -> Image:
	await _settle()
	return _stage.call("grab_picture")


func _save(image: Image, shot_name: String) -> void:
	var path: String = OUTPUT_DIR + shot_name + ".png"
	var err: Error = image.save_png(path)
	if err != OK:
		_failures += 1
	print("saved %s (%s), error %d" % [path, image.get_size(), err])


## Builds the sheet with ordinary 2D nodes in a SubViewport so labels use the project's pixel font.
func _contact_sheet(letters: Array[String], close: Dictionary[String, Image],
		ingame: Dictionary[String, Image], silhouette: Dictionary[String, Image]) -> void:
	var columns: int = letters.size()
	var width: int = ROW_LABEL_WIDTH + columns * COLUMN_WIDTH
	var height: int = HEADER_HEIGHT + CLOSE_ROW_HEIGHT + INGAME_ROW_HEIGHT * 2 + GAP * 3
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(width, height)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var canvas: Control = Control.new()
	viewport.add_child(canvas)
	var background: ColorRect = ColorRect.new()
	background.color = SHEET_BACKGROUND
	background.size = Vector2(width, height)
	canvas.add_child(background)
	var font: Font = load(LABEL_FONT) as Font
	var row_tops: Array[int] = [HEADER_HEIGHT, HEADER_HEIGHT + CLOSE_ROW_HEIGHT + GAP,
			HEADER_HEIGHT + CLOSE_ROW_HEIGHT + INGAME_ROW_HEIGHT + GAP * 2]
	var row_titles: PackedStringArray = ["3/4 view", "in-game scale", "silhouette\nin Ink"]
	for r: int in row_tops.size():
		_add_label(canvas, row_titles[r], Vector2(10, row_tops[r] + 10), ROW_FONT_SIZE, font)
	for c: int in columns:
		var letter: String = letters[c]
		var left: int = ROW_LABEL_WIDTH + c * COLUMN_WIDTH
		var title: String = letter.to_upper()
		var nice_name: String = _stage.call("prototype_name", letter)
		if nice_name != "":
			title += "  " + nice_name
		_add_label(canvas, title, Vector2(left + 12, 12), HEADER_FONT_SIZE, font)
		var crop_x: int = (1152 - COLUMN_WIDTH) / 2
		if close.has(letter):
			_add_picture(canvas, close[letter], Rect2i(crop_x, 0, COLUMN_WIDTH, CLOSE_ROW_HEIGHT), Vector2(left, row_tops[0]))
		if ingame.has(letter):
			_add_picture(canvas, ingame[letter], Rect2i(crop_x, 210, COLUMN_WIDTH, INGAME_ROW_HEIGHT), Vector2(left, row_tops[1]))
		if silhouette.has(letter):
			_add_picture(canvas, silhouette[letter], Rect2i(crop_x, 210, COLUMN_WIDTH, INGAME_ROW_HEIGHT), Vector2(left, row_tops[2]))
		var divider: ColorRect = ColorRect.new()
		divider.color = SHEET_LINE
		divider.position = Vector2(left - 2, 0)
		divider.size = Vector2(2, height)
		canvas.add_child(divider)
	root.add_child(viewport)
	await _settle()
	await RenderingServer.frame_post_draw
	var sheet: Image = viewport.get_texture().get_image()
	_save(sheet, "contact_sheet")
	viewport.queue_free()


func _add_label(parent: Control, text: String, at: Vector2, font_size: int, font: Font) -> void:
	var label: Label = Label.new()
	label.text = text
	label.position = at
	if font != null:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", LABEL_COLOR)
	parent.add_child(label)


func _add_picture(parent: Control, image: Image, crop: Rect2i, at: Vector2) -> void:
	var rect: TextureRect = TextureRect.new()
	rect.texture = ImageTexture.create_from_image(image.get_region(crop))
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.position = at
	parent.add_child(rect)
