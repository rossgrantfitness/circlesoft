class_name MenuCursor
extends Control
## The amber flame-arrow cursor (style guide: about 12x12, points right, flickers between two
## frames, bobs one pixel, snaps instantly with no sliding). Frames are drawn from the text rows
## in data/ui/ui_theme.json (placeholder art), then shown with nearest-neighbor filtering.

const THEME_ID: String = "ui/ui_theme"
const PIXEL_AMBER: String = "#"
const PIXEL_GLOW: String = "o"
const SHADOW_OFFSET: Vector2 = Vector2(1, 1)

## When false the cursor is drawn dimmed and still (the "last position" marker on inactive lists).
var active: bool = true:
	set(value):
		active = value
		queue_redraw()

var _frames: Array[ImageTexture] = []
var _shadow_color: Color = Color.BLACK
var _flicker_s: float = 0.25
var _bob_s: float = 0.4
var _clock: float = 0.0
var _frame_index: int = 0
var _bob: int = 0


func _ready() -> void:
	var theme_data: Dictionary = DataDB.get_dict(THEME_ID)
	var palette: Dictionary = theme_data["palette"]
	var timing: Dictionary = theme_data["timing"]
	_flicker_s = float(timing["cursor_flicker_s"])
	_bob_s = float(timing["cursor_bob_s"])
	_shadow_color = Color.html(str(palette["ink"]))
	var amber: Color = Color.html(str(palette["lamp_amber"]))
	var glow: Color = Color.html(str(palette["lamp_glow"]))
	var cursor_data: Dictionary = theme_data["cursor"]
	for frame_rows: Array in cursor_data["frames"]:
		_frames.append(_build_frame(frame_rows, amber, glow))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	custom_minimum_size = Vector2(_frames[0].get_size())
	size = custom_minimum_size


func get_frame_count() -> int:
	return _frames.size()


func _process(delta: float) -> void:
	_clock += delta
	var frame: int = int(_clock / _flicker_s) % _frames.size()
	var bob: int = int(_clock / _bob_s) % 2
	if not active:
		frame = 0
		bob = 0
	if frame != _frame_index or bob != _bob:
		_frame_index = frame
		_bob = bob
		queue_redraw()


## Restarts the animation so a freshly moved cursor starts on its first frame.
func restart() -> void:
	_clock = 0.0
	_frame_index = 0
	_bob = 0
	queue_redraw()


func _draw() -> void:
	if _frames.is_empty():
		return
	var offset: Vector2 = Vector2(0, _bob)
	var tint: Color = Color.WHITE if active else Color(1, 1, 1, 0.45)
	draw_texture(_frames[_frame_index], offset + SHADOW_OFFSET, Color(_shadow_color, tint.a))
	draw_texture(_frames[_frame_index], offset, tint)


func _build_frame(rows: Array, amber: Color, glow: Color) -> ImageTexture:
	var height: int = rows.size()
	var width: int = 0
	for row: String in rows:
		width = maxi(width, row.length())
	var image: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y: int in height:
		var row: String = rows[y]
		for x: int in row.length():
			var pixel: String = row[x]
			if pixel == PIXEL_AMBER:
				image.set_pixel(x, y, amber)
			elif pixel == PIXEL_GLOW:
				image.set_pixel(x, y, glow)
	return ImageTexture.create_from_image(image)
