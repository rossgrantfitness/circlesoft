class_name TitleBackdrop
extends Control
## The title-screen night view of Harrow, drawn from code at the internal 384x216 size:
## a dithered night sky, twinkling stars, drifting dust, a skyline, a relay mast, and the game's
## motif, one warm amber lamp in a window, glowing and gently flickering.
## Everything snaps to whole pixels and animates in steps (about 12 fps), like the rest of the UI.
##
## Look from docs/style_guide.md: "Lamps in the dark" (warm amber against cold night). Colors and
## counts come from data/ui/ui_theme.json; the shapes below are placeholder art.

const THEME_ID: String = "ui/ui_theme"
const BAYER_SIZE: int = 4
const BAYER: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
const BAYER_LEVELS: float = 16.0

## Sky gradient: color stops as [y, palette name].
const SKY_STOPS: Array[Array] = [[0, "ink"], [92, "night"], [170, "dusk"]]
const HORIZON_Y: int = 170
const FAR_BASE_Y: int = 178
const LAMP_LEVELS: int = 4
const STAR_REGION_BOTTOM: int = 150
const STAR_SPARKLE_PERCENT: int = 10
const STAR_BRIGHT_PERCENT: int = 35
const STAR_TWINKLE_PERIOD: int = 7
const DUST_SPEED_MIN: float = 2.0
const DUST_SPEED_MAX: float = 9.0
const DUST_BOB_PX: float = 3.0

# House with the lamp window (placeholder shapes).
const GROUND_Y: int = 198
const HOUSE_RECT: Rect2i = Rect2i(18, 124, 96, 74)
const ROOF_TOP_Y: int = 108
const WINDOW_RECT: Rect2i = Rect2i(46, 138, 28, 34)
const WINDOW_FRAME: int = 2
const HALO_RADIUS_BASE: int = 40
const HALO_RADIUS_PER_LEVEL: int = 7
const HALO_ALPHA_EDGE: float = 0.08
const HALO_ALPHA_CENTER: float = 0.22
const POOL_TOP_Y: int = 199
const MAST_X: int = 332

## 0..LAMP_LEVELS-1; the lamp's current brightness step. The title text reads it to pulse "ON".
var lamp_level: int = 2

var _c: Dictionary[String, Color] = {}
var _sky: ImageTexture
var _halos: Array[ImageTexture] = []
var _stars: Array[Dictionary] = []
var _dust: Array[Dictionary] = []
var _far_blocks: Array[Rect2i] = []
var _near_blocks: Array[Rect2i] = []
var _clock: float = 0.0
var _step_s: float = 0.0833
var _flicker_s: float = 0.0833
var _flicker_clock: float = 0.0
var _step: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	var theme_data: Dictionary = DataDB.get_dict(THEME_ID)
	var palette: Dictionary = theme_data["palette"]
	for key: String in palette:
		_c[key] = Color.html(str(palette[key]))
	var timing: Dictionary = theme_data["timing"]
	_step_s = float(timing["ui_step_s"])
	_flicker_s = float(timing["lamp_flicker_step_s"])
	var layout: Dictionary = theme_data["title_screen"]
	_rng.seed = int(layout["scene_seed"])
	_build_sky()
	_build_halos()
	_build_stars(int(layout["star_count"]))
	_build_dust(int(layout["dust_count"]))
	_build_skyline()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	lamp_level = 2
	queue_redraw()


func _process(delta: float) -> void:
	_clock += delta
	_flicker_clock += delta
	var changed: bool = false
	var new_step: int = int(_clock / _step_s)
	if new_step != _step:
		_step = new_step
		changed = true
	while _flicker_clock >= _flicker_s:
		_flicker_clock -= _flicker_s
		_flicker_lamp()
		changed = true
	if changed:
		queue_redraw()


## The lamp wanders up and down a step at a time, mostly staying bright (a candle, not a strobe).
func _flicker_lamp() -> void:
	var roll: float = _rng.randf()
	if roll < 0.18:
		lamp_level = maxi(0, lamp_level - 1)
	elif roll < 0.36:
		lamp_level = mini(LAMP_LEVELS - 1, lamp_level + 1)
	elif lamp_level == 0:
		lamp_level = 1


# ---- building the static pieces ----

func _build_sky() -> void:
	var image: Image = Image.create(int(size.x), int(size.y), false, Image.FORMAT_RGB8)
	var ground: Color = _c["ink"]
	for y: int in int(size.y):
		for x: int in int(size.x):
			var color: Color = ground
			if y < HORIZON_Y:
				color = _sky_pixel(x, y)
			image.set_pixel(x, y, color)
	_sky = ImageTexture.create_from_image(image)


func _sky_pixel(x: int, y: int) -> Color:
	var stop: int = 0
	for i: int in range(SKY_STOPS.size() - 1):
		if y >= int(SKY_STOPS[i][0]):
			stop = i
	var y0: int = SKY_STOPS[stop][0]
	var y1: int = SKY_STOPS[stop + 1][0]
	var from_color: Color = _c[str(SKY_STOPS[stop][1])]
	var to_color: Color = _c[str(SKY_STOPS[stop + 1][1])]
	var fraction: float = clampf(float(y - y0) / float(y1 - y0), 0.0, 1.0)
	var threshold: float = (float(BAYER[(y % BAYER_SIZE) * BAYER_SIZE + (x % BAYER_SIZE)]) + 0.5) / BAYER_LEVELS
	return to_color if fraction > threshold else from_color


## One pre-dithered amber halo per lamp level (1-bit on/off pixels, so it never blurs).
func _build_halos() -> void:
	for level: int in LAMP_LEVELS:
		var radius: int = HALO_RADIUS_BASE + HALO_RADIUS_PER_LEVEL * level
		var image: Image = Image.create(radius * 2, radius * 2, false, Image.FORMAT_RGBA8)
		for y: int in radius * 2:
			for x: int in radius * 2:
				var dx: float = float(x - radius) + 0.5
				var dy: float = float(y - radius) + 0.5
				var strength: float = 1.0 - sqrt(dx * dx + dy * dy) / float(radius)
				if strength <= 0.0:
					continue
				var threshold: float = (float(BAYER[(y % BAYER_SIZE) * BAYER_SIZE + (x % BAYER_SIZE)]) + 0.5) / BAYER_LEVELS
				if strength > threshold:
					var color: Color = _c["lamp_amber"]
					color.a = lerpf(HALO_ALPHA_EDGE, HALO_ALPHA_CENTER, strength)
					image.set_pixel(x, y, color)
		_halos.append(ImageTexture.create_from_image(image))


func _build_stars(count: int) -> void:
	for i: int in count:
		var roll: int = _rng.randi_range(0, 99)
		_stars.append({
			"pos": Vector2i(_rng.randi_range(2, int(size.x) - 3), _rng.randi_range(2, STAR_REGION_BOTTOM)),
			"sparkle": roll < STAR_SPARKLE_PERCENT,
			"bright": roll < STAR_BRIGHT_PERCENT,
			"phase": _rng.randi_range(0, STAR_TWINKLE_PERIOD - 1),
		})


func _build_dust(count: int) -> void:
	for i: int in count:
		_dust.append({
			"x": _rng.randf_range(0.0, size.x),
			"y": _rng.randf_range(20.0, size.y - 8.0),
			"speed": _rng.randf_range(DUST_SPEED_MIN, DUST_SPEED_MAX),
			"phase": _rng.randf_range(0.0, TAU),
		})


func _build_skyline() -> void:
	var x: int = 0
	while x < int(size.x):
		var width: int = _rng.randi_range(14, 30)
		var height: int = _rng.randi_range(14, 42)
		_far_blocks.append(Rect2i(x, FAR_BASE_Y - height, width, height + int(size.y)))
		x += width - _rng.randi_range(0, 4)
	x = HOUSE_RECT.end.x + 6
	while x < int(size.x):
		var width: int = _rng.randi_range(18, 40)
		var height: int = _rng.randi_range(10, 30)
		_near_blocks.append(Rect2i(x, GROUND_Y - height, width, height))
		x += width + _rng.randi_range(0, 6)


# ---- drawing ----

func _draw() -> void:
	draw_texture(_sky, Vector2.ZERO)
	_draw_stars()
	_draw_far_skyline()
	_draw_mast()
	_draw_near_skyline()
	_draw_house()
	_draw_ground()
	_draw_lamp_light()
	_draw_dust()


func _px(x: int, y: int, color: Color) -> void:
	draw_rect(Rect2(x, y, 1, 1), color)


func _draw_stars() -> void:
	for star: Dictionary in _stars:
		var pos: Vector2i = star["pos"]
		var on: bool = (_step / 2 + int(star["phase"])) % STAR_TWINKLE_PERIOD != 0
		var color: Color = _c["chalk"] if star["bright"] else _c["slate_light"]
		if not on:
			color = _c["slate"]
		_px(pos.x, pos.y, color)
		if star["sparkle"] and on:
			var arm: Color = _c["slate_light"]
			_px(pos.x - 1, pos.y, arm)
			_px(pos.x + 1, pos.y, arm)
			_px(pos.x, pos.y - 1, arm)
			_px(pos.x, pos.y + 1, arm)


func _draw_far_skyline() -> void:
	for block: Rect2i in _far_blocks:
		draw_rect(Rect2(block), _c["night"])
		draw_rect(Rect2(block.position.x, block.position.y, block.size.x, 1), _c["dusk"])
	# A few far windows, lit. Amber only for people (style guide), so they are dim brass.
	for i: int in range(0, _far_blocks.size(), 2):
		var block: Rect2i = _far_blocks[i]
		_px(block.position.x + 4, block.position.y + 6, _c["brass"])
		_px(block.position.x + block.size.x - 6, block.position.y + 12, _c["brass"])


func _draw_mast() -> void:
	var top: int = 92
	var base: int = int(size.y)
	draw_rect(Rect2(MAST_X, top, 2, base - top), _c["ink"])
	draw_rect(Rect2(MAST_X - 5, top + 14, 12, 1), _c["ink"])
	draw_rect(Rect2(MAST_X - 8, top + 30, 18, 1), _c["ink"])
	draw_rect(Rect2(MAST_X - 4, top, 10, 2), _c["ink"])
	draw_rect(Rect2(MAST_X - 1, top - 8, 1, 8), _c["ink"])
	for i: int in 6:
		var y: int = top + 36 + i * 14
		draw_line(Vector2(MAST_X - 6 + (i % 2) * 2, y + 14), Vector2(MAST_X + 1, y), _c["ink"])
		draw_line(Vector2(MAST_X + 7 - (i % 2) * 2, y + 14), Vector2(MAST_X + 1, y), _c["ink"])
	_px(MAST_X, top - 9, _c["slate_light"])


func _draw_near_skyline() -> void:
	for block: Rect2i in _near_blocks:
		draw_rect(Rect2(block), _c["ink"])
		draw_rect(Rect2(block.position.x, block.position.y, block.size.x, 1), _c["night"])
	for i: int in range(1, _near_blocks.size(), 2):
		var block: Rect2i = _near_blocks[i]
		draw_rect(Rect2(block.position.x + 5, block.position.y + 6, 3, 2), _c["brass"])


func _draw_house() -> void:
	var body: Rect2i = HOUSE_RECT
	# Stepped gable roof.
	var roof_height: int = body.position.y - ROOF_TOP_Y
	for i: int in roof_height:
		var inset: int = (roof_height - 1 - i) * 3
		draw_rect(Rect2(body.position.x - 2 + inset, ROOF_TOP_Y + i, body.size.x + 4 - inset * 2, 1), _c["ink"])
	draw_rect(Rect2(body), _c["ink"])
	# Patched sheet-metal seams and a couple of rivets in Night, so the wall is not a flat slab.
	for seam_y: int in range(body.position.y + 12, body.end.y, 22):
		draw_rect(Rect2(body.position.x, seam_y, body.size.x, 1), _c["night"])
	for seam_x: int in range(body.position.x + 76, body.end.x, 40):
		draw_rect(Rect2(seam_x, body.position.y, 1, body.size.y), _c["night"])
	for rivet_y: int in range(body.position.y + 13, body.end.y, 22):
		for rivet_x: int in range(body.position.x + 4, body.end.x, 12):
			_px(rivet_x, rivet_y, _c["dusk"])
	draw_rect(Rect2(body.position.x, body.position.y, body.size.x, 1), _c["dusk"])
	draw_rect(Rect2(body.position.x - 2, body.position.y - 1, 1, 1), _c["dusk"])
	# Door, dark.
	draw_rect(Rect2(body.end.x - 30, body.end.y - 30, 16, 30), _c["night"])
	draw_rect(Rect2(body.end.x - 30, body.end.y - 30, 16, 1), _c["dusk"])
	_draw_window()


func _draw_window() -> void:
	var win: Rect2i = WINDOW_RECT
	var frame: Rect2i = win.grow(WINDOW_FRAME)
	draw_rect(Rect2(frame), _c["dusk"])
	var level: int = lamp_level
	draw_rect(Rect2(win), _c["brass"])
	# Two dithered ellipses of light: warm amber wide, hot glow inside it.
	var cx: int = win.position.x + win.size.x / 2
	var shade_top: int = win.position.y + 14
	var center: Vector2 = Vector2(cx, shade_top + 8)
	for y: int in range(win.position.y, win.end.y):
		for x: int in range(win.position.x, win.end.x):
			var dx: float = float(x) - center.x
			var dy: float = float(y) - center.y
			var amber_d: float = (dx * dx) / (14.0 * 14.0) + (dy * dy) / (17.0 * 17.0)
			var hot_d: float = (dx * dx) / (float(7 + level) * float(7 + level)) + (dy * dy) / (float(8 + level) * float(8 + level))
			var checker: bool = (x + y) % 2 == 0
			if hot_d < 0.55 or (hot_d < 1.0 and checker):
				_px(x, y, _c["lamp_glow"])
			elif amber_d < 0.6 or (amber_d < 1.0 and checker):
				_px(x, y, _c["lamp_amber"])
	# The lamp itself, a dark silhouette against the glow: shade, stem, base.
	for row: int in 7:
		var half: int = 3 + row
		draw_rect(Rect2(cx - half, shade_top + row, half * 2, 1), _c["ink"])
	draw_rect(Rect2(cx - 3, shade_top, 6, 1), _c["brass"])
	draw_rect(Rect2(cx - 1, shade_top + 7, 2, 9), _c["ink"])
	draw_rect(Rect2(cx - 5, win.end.y - 5, 10, 3), _c["ink"])
	# Mullion splitting a short upper pane from the lamp pane, and the sill.
	draw_rect(Rect2(win.position.x, win.position.y + 7, win.size.x, 1), _c["ink"])
	draw_rect(Rect2(frame.position.x - 2, frame.end.y, frame.size.x + 4, 2), _c["slate"])
	draw_rect(Rect2(frame.position.x - 2, frame.end.y + 2, frame.size.x + 4, 1), _c["ink"])


func _draw_ground() -> void:
	draw_rect(Rect2(0, GROUND_Y, size.x, size.y - GROUND_Y), _c["ink"])
	draw_rect(Rect2(0, GROUND_Y, size.x, 1), _c["night"])


## Warm glow spilling out of the window and a dithered pool of light on the ground.
func _draw_lamp_light() -> void:
	var halo: ImageTexture = _halos[lamp_level]
	var center: Vector2 = Vector2(WINDOW_RECT.get_center())
	draw_texture(halo, (center - halo.get_size() / 2.0).floor())
	# Ground pool, wider with each row, in a checker so it dithers instead of blurring.
	var pool_color: Color = _c["lamp_amber"]
	pool_color.a = 0.22 + 0.04 * float(lamp_level)
	var center_x: int = WINDOW_RECT.position.x + WINDOW_RECT.size.x / 2
	for y: int in range(POOL_TOP_Y, int(size.y)):
		var half: int = 14 + (y - POOL_TOP_Y) * 3 + lamp_level * 2
		for x: int in range(center_x - half, center_x + half):
			if x >= 0 and (x + y) % 2 == 0:
				_px(x, y, pool_color)


func _draw_dust() -> void:
	var lamp_center: Vector2 = Vector2(WINDOW_RECT.get_center())
	for mote: Dictionary in _dust:
		var x: float = fposmod(float(mote["x"]) + _clock * float(mote["speed"]), size.x)
		var y: float = float(mote["y"]) + sin(_clock * 0.6 + float(mote["phase"])) * DUST_BOB_PX
		var pos: Vector2i = Vector2i(int(x), int(y))
		var color: Color = _c["slate_light"]
		color.a = 0.7
		if Vector2(pos).distance_to(lamp_center) < 70.0:
			color = _c["lamp_glow"]
			color.a = 0.8
		_px(pos.x, pos.y, color)
