class_name DitherFade
extends Control
## Fade to and from black in stepped, dithered levels (style guide: "fade to black in 8 dithered
## steps"), using a 4x4 ordered-dither tile so it never blurs. step 0 = clear, step_count = black.

const BAYER_SIZE: int = 4
const BAYER: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
const BAYER_CELLS: int = 16

var step_count: int = 8:
	set(value):
		step_count = maxi(1, value)
		_build_tiles()
		queue_redraw()

## 0 = fully clear, step_count = fully black.
var step: int = 0:
	set(value):
		var clamped: int = clampi(value, 0, step_count)
		if clamped != step:
			step = clamped
			queue_redraw()

var _tiles: Array[ImageTexture] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_build_tiles()


func _build_tiles() -> void:
	_tiles.clear()
	for level: int in range(step_count + 1):
		var covered: int = int(round(float(level) * float(BAYER_CELLS) / float(step_count)))
		var image: Image = Image.create(BAYER_SIZE, BAYER_SIZE, false, Image.FORMAT_RGBA8)
		for y: int in BAYER_SIZE:
			for x: int in BAYER_SIZE:
				var black: bool = BAYER[y * BAYER_SIZE + x] < covered
				image.set_pixel(x, y, Color.BLACK if black else Color(0, 0, 0, 0))
		_tiles.append(ImageTexture.create_from_image(image))


func _draw() -> void:
	if step <= 0 or _tiles.is_empty():
		return
	draw_texture_rect(_tiles[step], Rect2(Vector2.ZERO, size), true)
