class_name BattleTextures
extends RefCounted
## Little placeholder textures the battle set paints in code (so the placeholder set needs no files): floor,
## wall, crate, blob shadow, formation ring, lamp halo and the "!" cue. All follow the style guide: 64 px or
## more for surfaces, nearest filtering, a dithered gradient never a smooth one, 1-bit cut-out alpha, and the
## master palette. Ross's real set replaces them. Pure functions: same inputs, same pixels.

const SURFACE_PX: int = 64
const WALL_W: int = 128
const WALL_H: int = 64
const DITHER_CHECKER: int = 2

## Painted textures by what they were made from, so each new battle stage reuses them instead of repainting.
static var _cache: Dictionary[String, ImageTexture] = {}


## Tiny deterministic hash in 0..1 for a pixel and a salt.
static func noise(x: int, y: int, salt: int) -> float:
	var h: int = (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFF) / 65535.0


static func _image(w: int, h: int) -> Image:
	return Image.create(w, h, false, Image.FORMAT_RGBA8)


static func _texture(image: Image) -> ImageTexture:
	return ImageTexture.create_from_image(image)


## Packed dust: speckles of a second tone, a lighter seam on two edges so the 1x1 tiles read as a grid.
static func floor_texture(look: Dictionary) -> ImageTexture:
	var key: String = "floor:" + str(look["floor_a"]) + str(look["floor_b"]) + str(look["floor_trim"])
	if not _cache.has(key):
		_cache[key] = _paint_floor_texture(look)
	return _cache[key]


static func _paint_floor_texture(look: Dictionary) -> ImageTexture:
	var base: Color = Color.html(str(look["floor_a"]))
	var alt: Color = Color.html(str(look["floor_b"]))
	var trim: Color = Color.html(str(look["floor_trim"]))
	var img: Image = _image(SURFACE_PX, SURFACE_PX)
	for y: int in SURFACE_PX:
		for x: int in SURFACE_PX:
			var c: Color = base
			var n: float = noise(x, y, 1)
			if n > 0.86:
				c = alt
			elif n < 0.05:
				c = trim.darkened(0.2)
			if (x % 32 == 0) or (y % 32 == 0):
				c = c.lerp(trim, 0.45)
			img.set_pixel(x, y, c)
	return _texture(img)


## Patched sheet-metal wall: corrugation stripes, rivets along the top and bottom, a rust streak, mismatched patches.
static func wall_texture(look: Dictionary) -> ImageTexture:
	var key: String = "wall:" + str(look["wall_a"]) + str(look["wall_b"]) + str(look["wall_rust"]) + str(look["wall_rivet"]) + str(look["patches"])
	if not _cache.has(key):
		_cache[key] = _paint_wall_texture(look)
	return _cache[key]


static func _paint_wall_texture(look: Dictionary) -> ImageTexture:
	var a: Color = Color.html(str(look["wall_a"]))
	var b: Color = Color.html(str(look["wall_b"]))
	var rust: Color = Color.html(str(look["wall_rust"]))
	var rivet: Color = Color.html(str(look["wall_rivet"]))
	var patches: Array = look["patches"]
	var img: Image = _image(WALL_W, WALL_H)
	for y: int in WALL_H:
		for x: int in WALL_W:
			var c: Color = a if (x % 8) < 5 else a.lerp(b, 0.6)
			if (x % 8) == 0:
				c = a.lerp(b, 0.9).darkened(0.1)
			if noise(x, y, 7) > 0.97:
				c = a.lightened(0.12)
			img.set_pixel(x, y, c)
	for rx: int in range(4, WALL_W, 16):
		for ry: int in [3, WALL_H - 4]:
			img.set_pixel(rx, ry, rivet)
			img.set_pixel(rx + 1, ry, rivet)
			img.set_pixel(rx, ry + 1, b.darkened(0.3))
	for streak: int in 3:
		var sx: int = 14 + streak * 41
		for sy: int in range(8, 8 + 22 + streak * 5):
			if ((sx + sy) % 2) == 0 or sy < 14:
				img.set_pixel(sx + (sy % 3), sy, rust.darkened(0.35))
	for i: int in mini(patches.size(), 2):
		var patch: Color = Color.html(str(patches[i]))
		var px: int = 10 + i * 40
		var py: int = 22 + (i % 2) * 14
		for y: int in 14:
			for x: int in 18:
				var edge: bool = x == 0 or y == 0 or x == 17 or y == 13
				var stitch: bool = (x % 3 == 0 and (y == 1 or y == 12)) or (y % 3 == 0 and (x == 1 or x == 16))
				var c: Color = patch.darkened(0.4) if edge else patch.darkened(0.22)
				if stitch:
					c = patch.lightened(0.15)
				img.set_pixel(px + x, py + y, c)
	return _texture(img)


## Painted wooden crate (planks, a cross brace, nails).
static func crate_texture(look: Dictionary) -> ImageTexture:
	var key: String = "crate:" + str(look["wall_rivet"])
	if not _cache.has(key):
		_cache[key] = _paint_crate_texture(look)
	return _cache[key]


static func _paint_crate_texture(look: Dictionary) -> ImageTexture:
	var wood: Color = Color.html("#B8844C")
	var dark: Color = Color.html("#8F5E34")
	var nail: Color = Color.html(str(look["wall_rivet"]))
	var img: Image = _image(SURFACE_PX, SURFACE_PX)
	for y: int in SURFACE_PX:
		for x: int in SURFACE_PX:
			var c: Color = wood if (y % 16) < 14 else dark
			if noise(x, y, 11) > 0.93:
				c = dark
			var edge: bool = x < 4 or x >= SURFACE_PX - 4 or y < 4 or y >= SURFACE_PX - 4
			if edge:
				c = dark
			var diag: bool = absi(x - y) < 3 or absi(x - (SURFACE_PX - 1 - y)) < 3
			if diag:
				c = dark
			img.set_pixel(x, y, c)
	for p: Vector2i in [Vector2i(2, 2), Vector2i(61, 2), Vector2i(2, 61), Vector2i(61, 61)]:
		img.set_pixel(p.x, p.y, nail)
	return _texture(img)


## A dithered dark disc for blob shadows: solid middle, checkerboard edge, 1-bit alpha.
static func shadow_texture(px: int, color: Color) -> ImageTexture:
	var img: Image = _image(px, px)
	var center: float = float(px - 1) / 2.0
	for y: int in px:
		for x: int in px:
			var d: float = Vector2(float(x) - center, float(y) - center).length() / (float(px) / 2.0)
			var alpha: float = 0.0
			if d < 0.62:
				alpha = 1.0
			elif d < 1.0 and ((x + y) % DITHER_CHECKER) == 0:
				alpha = 1.0
			img.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))
	return _texture(img)


## A formation ring: a thin ring, four tick marks, and a checkerboard-dithered fill.
static func ring_texture(px: int, color: Color) -> ImageTexture:
	var img: Image = _image(px, px)
	var center: float = float(px - 1) / 2.0
	var half: float = float(px) / 2.0
	for y: int in px:
		for x: int in px:
			var offset: Vector2 = Vector2(float(x) - center, float(y) - center)
			var d: float = offset.length() / half
			var alpha: float = 0.0
			if d > 0.78 and d <= 1.0:
				alpha = 1.0
			if d > 0.62 and d <= 0.78 and (absf(offset.x) < 1.2 or absf(offset.y) < 1.2):
				alpha = 1.0
			img.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))
	return _texture(img)


## Lamp halo for an additive sprite: stepped rings of falling brightness, dithered between steps.
static func halo_texture(px: int, color: Color) -> ImageTexture:
	var img: Image = _image(px, px)
	var center: float = float(px - 1) / 2.0
	var half: float = float(px) / 2.0
	for y: int in px:
		for x: int in px:
			var d: float = Vector2(float(x) - center, float(y) - center).length() / half
			var level: float = clampf(1.0 - d, 0.0, 1.0)
			var stepped: float = floorf(level * 4.0) / 4.0
			if ((x + y) % DITHER_CHECKER) == 0:
				stepped = floorf(level * 4.0 + 0.5) / 4.0
			var strength: float = stepped * 0.55
			img.set_pixel(x, y, Color(color.r * strength, color.g * strength, color.b * strength, 1.0))
	return _texture(img)


## The "!" cue: a round white-outlined bubble with a bold hot-orange "!" (style guide: 16x16 normal; bigger here
## so it survives scaling). `px` is the side length.
static func cue_texture(px: int, fill: Color, outline: Color, ink: Color) -> ImageTexture:
	var img: Image = _image(px, px)
	var center: float = float(px - 1) / 2.0
	var radius: float = float(px) / 2.0 - 1.0
	var unit: float = float(px) / 16.0
	for y: int in px:
		for x: int in px:
			var d: float = Vector2(float(x) - center, float(y) - center).length()
			var c: Color = Color(0, 0, 0, 0)
			if d <= radius:
				c = outline
				if d <= radius - maxf(unit * 1.4, 1.0):
					c = Color("#FFF2E0")
			img.set_pixel(x, y, c)
	# the exclamation mark: a bar and a dot, hot orange with an Ink edge
	var bar_x0: int = int(center - unit * 1.6)
	var bar_x1: int = int(center + unit * 1.6)
	for y: int in range(int(unit * 3.0), int(unit * 9.5)):
		for x: int in range(bar_x0 - 1, bar_x1 + 2):
			var inner: bool = x >= bar_x0 and x <= bar_x1 and y >= int(unit * 3.0) + 1 and y < int(unit * 9.5) - 1
			img.set_pixel(x, y, fill if inner else ink)
	for y: int in range(int(unit * 10.8), int(unit * 13.6)):
		for x: int in range(bar_x0 - 1, bar_x1 + 2):
			var inner_dot: bool = x >= bar_x0 and x <= bar_x1 and y >= int(unit * 10.8) + 1 and y < int(unit * 13.6) - 1
			img.set_pixel(x, y, fill if inner_dot else ink)
	return _texture(img)
