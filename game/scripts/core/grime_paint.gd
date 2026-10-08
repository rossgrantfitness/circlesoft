class_name GrimePaint
extends RefCounted
## Code-painted grime for the "grim" look profile: no texture files, every pixel comes from a seed, so the
## same call always paints the same picture. All textures are small (32 to 128 px), nearest-filtered by the
## shaders, and use 1-bit alpha (a pixel is there or it is not), as the style guide asks.
##
## Surfaces (floor, wall, panel) are painted fresh in a near-neutral grey, because the room's own material
## tint still multiplies them; the profile drains that tint separately. Decals (posters, warning stripes,
## fence, puddle) are small and shared by every room, so a prop costs one cached texture.

const FLOOR_PX: int = 64
const WALL_PX: int = 128
const BAYER: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

## Painted images by what they were made from, so each shows up once.
static var _cache: Dictionary[String, ImageTexture] = {}
static var _char_cache: Dictionary[String, ImageTexture] = {}


static func clear_cache() -> void:
	_cache.clear()
	_char_cache.clear()


static func cached_count() -> int:
	return _cache.size() + _char_cache.size()


# ---- small helpers ----

static func _hash(x: int, y: int, salt: int) -> float:
	return BattleTextures.noise(x, y, salt)


## Smooth value noise (0..1) with `cell` px between lattice points; wraps so tiles repeat seamlessly.
static func _value_noise(x: int, y: int, cell: int, size: int, salt: int) -> float:
	var cells: int = maxi(size / cell, 1)
	var fx: float = float(x) / float(cell)
	var fy: float = float(y) / float(cell)
	var x0: int = int(floorf(fx))
	var y0: int = int(floorf(fy))
	var tx: float = fx - float(x0)
	var ty: float = fy - float(y0)
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var a: float = _hash(posmod(x0, cells), posmod(y0, cells), salt)
	var b: float = _hash(posmod(x0 + 1, cells), posmod(y0, cells), salt)
	var c: float = _hash(posmod(x0, cells), posmod(y0 + 1, cells), salt)
	var d: float = _hash(posmod(x0 + 1, cells), posmod(y0 + 1, cells), salt)
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)


## Two octaves of wrapping noise: big blotches plus finer dirt.
static func _blotch(x: int, y: int, size: int, salt: int) -> float:
	return _value_noise(x, y, size / 4, size, salt) * 0.65 + _value_noise(x, y, size / 8, size, salt + 31) * 0.35


## Ordered-dither threshold (0..1) so a grime layer is a checker-like pattern, never a soft blend.
static func _bayer(x: int, y: int) -> float:
	return (float(BAYER[(y % 4) * 4 + (x % 4)]) + 0.5) / 16.0


## Lays `color` over the pixel where the dithered coverage says so.
static func _splat(img: Image, x: int, y: int, color: Color, coverage: float) -> void:
	if coverage <= 0.0:
		return
	if coverage >= 1.0 or _bayer(x, y) < coverage:
		img.set_pixel(x, y, Color(color.r, color.g, color.b, img.get_pixel(x, y).a))


static func _rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for yy: int in range(maxi(y, 0), mini(y + h, img.get_height())):
		for xx: int in range(maxi(x, 0), mini(x + w, img.get_width())):
			img.set_pixel(xx, yy, color)


static func _image(w: int, h: int, fill: Color) -> Image:
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(fill)
	return img


static func _texture(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)


static func _color(grime: Dictionary, key: String, fallback: String) -> Color:
	return Color.html(str(grime.get(key, fallback)))


# ---- room surfaces ----

## Which kind of grimed surface to paint for a placeholder texture path ("" = leave the texture alone).
static func kind_for_path(path: String) -> String:
	var file: String = path.get_file().get_basename()
	if file.begins_with("checker_64") or file.begins_with("checker_256"):
		return "floor"
	if file.begins_with("checker_128"):
		return "panel"
	if file.begins_with("wall"):
		return "wall"
	return ""


static func surface_texture(kind: String, grime: Dictionary) -> ImageTexture:
	var key: String = "surface:%s:%s" % [kind, str(grime)]
	if not _cache.has(key):
		_cache[key] = _texture(surface_image(kind, grime))
	return _cache[key]


## A dirty tileable surface. kind: "floor" (poured concrete plates, oil, puddle rings), "wall" (corrugated
## sheet metal, rust streaks, seams) or "panel" (flat welded plate with stains).
static func surface_image(kind: String, grime: Dictionary) -> Image:
	var size: int = FLOOR_PX if kind == "floor" else WALL_PX
	var base: Color = Color(0.52, 0.51, 0.48)
	var dirt: Color = _color(grime, "dirt_color", "#17140f")
	var rust: Color = _color(grime, "rust_color", "#6a3a1c")
	var oil: Color = _color(grime, "oil_color", "#161815")
	var dirt_amount: float = float(grime.get("dirt", 0.7))
	var rust_amount: float = float(grime.get("rust", 0.6))
	var stain_amount: float = float(grime.get("stain", 0.6))
	var salt: int = 3 if kind == "floor" else (5 if kind == "wall" else 9)
	var img: Image = _image(size, size, base)
	for y: int in size:
		for x: int in size:
			var c: Color = base
			var grain: float = _hash(x, y, salt)
			if grain > 0.82:
				c = base.darkened(0.16)
			elif grain < 0.07:
				c = base.lightened(0.1)
			if kind == "wall":
				var rib: int = x % 8
				if rib == 0:
					c = c.darkened(0.3)
				elif rib < 3:
					c = c.lightened(0.07)
			elif kind == "floor":
				var plate: int = 32
				if x % plate == 0 or y % plate == 0:
					c = c.darkened(0.4)
			else:
				if x % 32 == 0 or y % 32 == 0:
					c = c.darkened(0.4)
			img.set_pixel(x, y, c)
	# rivet rows on walls and panels
	if kind != "floor":
		for rx: int in range(4, size, 16):
			for ry: int in [3, size - 4]:
				_rect(img, rx, ry, 2, 2, base.darkened(0.5))
				img.set_pixel(rx, ry, base.lightened(0.18))
	# big dirty blotches in posterized tones (never a soft blend): light dirt, heavy dirt, oil, rust.
	# Only the border between two tones is dithered, so the stains stay readable at 384x216.
	for y: int in size:
		for x: int in size:
			var jitter: float = (_bayer(x, y) - 0.5) * 0.07
			var n: float = _blotch(x, y, size, salt + 100) + jitter
			var dirt_cut: float = 0.62 - 0.22 * dirt_amount
			var c: Color = img.get_pixel(x, y)
			if n > dirt_cut + 0.16:
				c = c.lerp(dirt, 0.5)
			elif n > dirt_cut:
				c = c.lerp(dirt, 0.24)
			var m: float = _blotch(x, y, size, salt + 200) + jitter
			if m > 0.86 - 0.2 * stain_amount:
				c = c.lerp(oil, 0.6)
			var r: float = _blotch(x, y, size, salt + 300) + jitter
			if r > 0.9 - 0.25 * rust_amount:
				c = c.lerp(rust, 0.75)
			elif r > 0.82 - 0.25 * rust_amount:
				c = c.lerp(rust, 0.4)
			img.set_pixel(x, y, c)
	# streaks: long vertical drips on walls and panels, scuff lines on floors
	for i: int in 9:
		var sx: int = int(_hash(i, 1, salt + 400) * float(size))
		var length: int = 18 + int(_hash(i, 2, salt + 400) * 70.0)
		var top: int = int(_hash(i, 3, salt + 400) * float(size))
		var is_rust: bool = _hash(i, 4, salt + 400) < 0.55
		var streak_color: Color = rust.darkened(0.15) if is_rust else oil
		for k: int in length:
			var yy: int = top + k
			if kind == "floor":
				var xx: int = (sx + k) % size
				if (k % 3) != 0:
					img.set_pixel(xx, yy % size, streak_color.lerp(base, 0.25))
			else:
				var wobble: int = int(sin(float(k) * 0.45 + float(i)) * 1.2)
				if (k + i) % 4 != 0 and yy < size:
					var xx2: int = (sx + wobble) % size
					img.set_pixel(xx2, yy, streak_color)
					if k < length / 2:
						_splat(img, (xx2 + 1) % size, yy, streak_color, 0.5)
	# edge dirt where tiles meet (the seams look filthy, which also hides the tiling)
	for y: int in size:
		for x: int in size:
			var edge: int = mini(mini(x, size - 1 - x), mini(y, size - 1 - y))
			if edge < 2:
				var c: Color = img.get_pixel(x, y)
				img.set_pixel(x, y, Color(c.r * 0.55 + dirt.r * 0.45, c.g * 0.55 + dirt.g * 0.45, c.b * 0.55 + dirt.b * 0.45, c.a))
			elif edge < 5:
				_splat(img, x, y, dirt, 0.3 * dirt_amount)
	return img


# ---- decals and little props ----

static func decal_texture(id: String, grime: Dictionary = {}) -> ImageTexture:
	var key: String = "decal:%s" % id
	if not _cache.has(key):
		var img: Image = null
		match id:
			"poster_mast":
				img = poster_image(0)
			"poster_eye":
				img = poster_image(1)
			"poster_ration":
				img = poster_image(2)
			"stripes":
				img = stripes_image()
			"fence":
				img = fence_image()
			"barbed":
				img = barbed_image()
			"puddle":
				img = puddle_image()
			"metal":
				img = metal_image(grime)
			"grate":
				img = grate_image()
			_:
				img = _image(8, 8, Color.MAGENTA)
		_cache[key] = _texture(img)
	return _cache[key]


## The Signals Corps mark: a mast with three signal arcs. Painted on a worn paper poster.
static func _paint_signals_mark(img: Image, cx: int, cy: int, scale: int, color: Color) -> void:
	_rect(img, cx - scale / 2, cy - scale * 3, scale, scale * 6, color)          # the mast
	_rect(img, cx - scale * 2, cy + scale * 3, scale * 4, scale, color)          # its foot
	for ring: int in 3:
		var radius: float = float(scale * (3 + ring * 3))
		for step: int in 80:
			var angle: float = -PI * 0.85 + PI * 0.7 * float(step) / 79.0
			for side: int in [-1, 1]:
				var px: int = cx + int(roundf(cos(angle) * radius)) * side
				var py: int = cy - scale * 3 + int(roundf(sin(angle) * radius))
				if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
					img.set_pixel(px, py, color)
					if scale > 1:
						img.set_pixel(px, mini(py + 1, img.get_height() - 1), color)


## A 32x48 propaganda poster. variant 0: the mast mark over a title bar; 1: a watching eye in a ring; 2: a
## ration-card slogan with a fist. Worn paper, torn corners, a water stain. No readable text: bars stand in.
static func poster_image(variant: int) -> Image:
	var w: int = 32
	var h: int = 48
	var paper: Color = Color("#8d8670") if variant != 2 else Color("#7d786a")
	var ink: Color = Color("#17151a")
	var signals: Color = Color("#4a5f78")
	var alarm: Color = Color("#8a2f33")
	var img: Image = _image(w, h, paper)
	for y: int in h:
		for x: int in w:
			var n: float = _hash(x, y, 40 + variant)
			if n > 0.9:
				img.set_pixel(x, y, paper.darkened(0.12))
	_rect(img, 0, 0, w, 2, ink)
	_rect(img, 0, h - 2, w, 2, ink)
	_rect(img, 0, 0, 2, h, ink)
	_rect(img, w - 2, 0, 2, h, ink)
	match variant:
		0:
			_rect(img, 3, 3, w - 6, 5, signals)
			_paint_signals_mark(img, 16, 24, 1, ink)
			_rect(img, 4, 39, w - 8, 2, ink)
			_rect(img, 7, 43, w - 14, 2, ink)
		1:
			_rect(img, 3, 3, w - 6, 6, alarm)
			for y: int in range(14, 34):
				for x: int in range(4, 28):
					var dx: float = float(x - 16) / 12.0
					var dy: float = float(y - 24) / 9.0
					var d: float = dx * dx + dy * dy
					if d < 1.0 and d > 0.78:
						img.set_pixel(x, y, ink)
					elif d <= 0.78 and d > 0.2:
						img.set_pixel(x, y, paper.lightened(0.15))
					if d <= 0.22:
						img.set_pixel(x, y, ink)
			_rect(img, 4, 38, w - 8, 3, ink)
			_rect(img, 8, 43, w - 16, 2, ink)
		_:
			_rect(img, 3, 3, w - 6, 5, ink)
			_rect(img, 5, 12, 22, 3, alarm)
			_rect(img, 5, 18, 22, 3, ink)
			_rect(img, 5, 24, 16, 3, ink)
			_rect(img, 11, 31, 10, 11, ink)
			_rect(img, 9, 31, 2, 6, ink)
			_rect(img, 21, 31, 2, 6, ink)
			_rect(img, 4, 44, w - 8, 2, alarm)
	# wear: water stain running from the top, torn bottom corner, peeled strip
	for y: int in h:
		for x: int in w:
			var stain: float = _value_noise(x, y, 8, 32, 77 + variant)
			if y < 26 and stain > 0.6 and (x + y) % 2 == 0:
				img.set_pixel(x, y, img.get_pixel(x, y).darkened(0.35))
	for k: int in 7:
		for j: int in (7 - k):
			if w - 1 - j >= 0 and h - 1 - k >= 0:
				img.set_pixel(w - 1 - j, h - 1 - k, Color(0, 0, 0, 0))
	for y: int in range(0, 12):
		img.set_pixel(0, y, Color(0, 0, 0, 0))
	return img


## Yellow and black diagonal hazard stripes (tileable, 32x32). Colors stay saturated: warning is an accent.
static func stripes_image() -> Image:
	var img: Image = _image(32, 32, Color("#b99a22"))
	var black: Color = Color("#1a1812")
	for y: int in 32:
		for x: int in 32:
			if ((x + y) / 8) % 2 == 0:
				img.set_pixel(x, y, black)
			elif _hash(x, y, 55) > 0.88:
				img.set_pixel(x, y, Color("#8a7218"))
			if _hash(x, y, 56) > 0.93:
				img.set_pixel(x, y, Color("#2a2a26"))
	return img


## Chain-link fence (32x32, 1-bit alpha): diamonds of thin wire.
static func fence_image() -> Image:
	var img: Image = _image(32, 32, Color(0, 0, 0, 0))
	var wire: Color = Color("#7b7d78")
	var dark: Color = Color("#2c2d29")
	for y: int in 32:
		for x: int in 32:
			var a: int = (x + y) % 16
			var b: int = (x - y + 64) % 16
			if a < 2 or b < 2:
				img.set_pixel(x, y, wire if _hash(x, y, 60) > 0.25 else dark)
	_rect(img, 0, 0, 32, 2, wire)
	_rect(img, 0, 0, 32, 1, dark)
	return img


## Barbed wire (32x8): a sagging strand with barbs.
static func barbed_image() -> Image:
	var img: Image = _image(32, 8, Color(0, 0, 0, 0))
	var wire: Color = Color("#6d6f69")
	for x: int in 32:
		var y: int = 3 + int(roundf(sin(float(x) * 0.4) * 1.0))
		img.set_pixel(x, y, wire)
		img.set_pixel(x, y + 1, wire.darkened(0.3))
	for x: int in range(2, 32, 8):
		img.set_pixel(x, 1, wire)
		img.set_pixel(x, 2, wire)
		img.set_pixel(x + 1, 6, wire)
		img.set_pixel(x + 1, 5, wire)
		img.set_pixel(x - 1, 1, wire)
		img.set_pixel(x + 2, 6, wire)
	return img


## A puddle (32x32): dark oily water, a pale reflected lamp, dithered edge, 1-bit alpha.
static func puddle_image() -> Image:
	var img: Image = _image(32, 32, Color(0, 0, 0, 0))
	for y: int in 32:
		for x: int in 32:
			var dx: float = (float(x) - 15.5) / 15.0
			var dy: float = (float(y) - 15.5) / 11.0
			var wobble: float = (_value_noise(x, y, 8, 32, 90) - 0.5) * 0.45
			var d: float = sqrt(dx * dx + dy * dy) + wobble
			if d < 0.78:
				var c: Color = Color("#0c1112")
				if d > 0.55 and (x + y) % 2 == 0:
					c = Color("#1a2224")
				if absf(float(x) - 21.0) < 3.0 and absf(float(y) - 12.0) < 1.5 and d < 0.6:
					c = Color("#77826f")
				if (d > 0.3 and d < 0.38) or (d > 0.1 and d < 0.14 and (x + y) % 2 == 0):
					c = Color("#222c2e")
				img.set_pixel(x, y, c)
			elif d < 1.0 and (x + y) % 2 == 0:
				img.set_pixel(x, y, Color("#14110d"))
	return img


## Dirty metal for loudspeakers, floodlights and posts (32x32): scuffed dark grey with rust at the edges.
static func metal_image(grime: Dictionary) -> Image:
	var rust: Color = _color(grime, "rust_color", "#6a3a1c")
	var img: Image = _image(32, 32, Color(0.5, 0.5, 0.48))
	for y: int in 32:
		for x: int in 32:
			var n: float = _hash(x, y, 70)
			if n > 0.85:
				img.set_pixel(x, y, Color(0.38, 0.38, 0.36))
			elif n < 0.06:
				img.set_pixel(x, y, Color(0.62, 0.62, 0.58))
			if y % 16 == 0:
				img.set_pixel(x, y, Color(0.3, 0.3, 0.29))
			_splat(img, x, y, rust, clampf((_value_noise(x, y, 8, 32, 71) - 0.5) * 3.0, 0.0, 1.0) * 0.8)
	return img


## A drain grate (32x32): dark slots in a grey plate.
static func grate_image() -> Image:
	var img: Image = _image(32, 32, Color("#4a4a46"))
	for y: int in range(3, 29):
		for x: int in range(3, 29):
			if x % 4 != 0:
				img.set_pixel(x, y, Color("#0b0b09"))
	return img


# ---- characters ----

## A dulled, scuffed, matte copy of a character texture: colors drained and darkened, bright gloss spots
## pulled down to the surrounding tone, then scuffs and grime flecks. Pure function of its inputs.
static func dull_character_image(src: Image, cfg: Dictionary, salt: int = 0) -> Image:
	var img: Image = src.duplicate() as Image
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var saturation: float = float(cfg.get("saturation", 0.5))
	var brightness: float = float(cfg.get("value", 0.8))
	var gloss_ceiling: float = float(cfg.get("gloss_ceiling", 0.62))
	var scuff: float = float(cfg.get("scuff", 0.2))
	var dirt: Color = Color.html(str(cfg.get("dirt_color", "#1b1812")))
	var warm: Color = Color.html(str(cfg.get("warm_cast", "#d8c9a8")))
	var cast: float = float(cfg.get("warm_cast_amount", 0.12))
	var w: int = img.get_width()
	var h: int = img.get_height()
	for y: int in h:
		for x: int in w:
			var c: Color = img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var luma: float = c.r * LookProfiles.LUMA.x + c.g * LookProfiles.LUMA.y + c.b * LookProfiles.LUMA.z
			if luma > gloss_ceiling and c.get_luminance() > 0.8:
				c = c.darkened(0.35)           # chalk gloss spots and catch-lights: no toy sheen
			c = LookProfiles.drain(c, saturation, brightness)
			c = c.lerp(Color(c.r * warm.r, c.g * warm.g, c.b * warm.b, c.a), cast)
			var n: float = _hash(x, y, 200 + salt)
			if n > 1.0 - scuff * 0.5:
				c = c.lerp(dirt, 0.55)
			elif n < scuff * 0.22:
				c = c.lightened(0.07)
			# grimy lower half: dirt creeps up from the bottom of each 16 px cell
			var blotch: float = _value_noise(x, y, 8, maxi(w, 8), 210 + salt)
			if blotch > 0.62 and ((x + y) & 1) == 0:
				c = c.lerp(dirt, 0.4)
			img.set_pixel(x, y, c)
	return img


static func dull_character_texture(src: Texture2D, cfg: Dictionary) -> Texture2D:
	if src == null:
		return null
	# Keyed by where the texture came from (a model's textures reload under a new instance id when its scene
	# was freed), so a battle that starts again does not repaint every character.
	var origin: String = src.resource_path if not src.resource_path.is_empty() else str(src.get_instance_id())
	var key: String = "char:%s:%dx%d:%s" % [origin, src.get_width(), src.get_height(), str(cfg)]
	if _char_cache.has(key):
		return _char_cache[key]
	var image: Image = src.get_image()
	if image == null or image.is_empty():
		return src
	var salt: int = int(src.get_width()) + int(src.get_height())
	_char_cache[key] = _texture(dull_character_image(image, cfg, salt))
	return _char_cache[key]


# ---- pixel text, neon and propaganda screens ----

## A 3x5 pixel font (rows top to bottom, 3 bits each, left bit first). Just enough for signs and slogans.
const FONT: Dictionary[String, PackedInt32Array] = {
	"A": [2, 5, 7, 5, 5], "B": [6, 5, 6, 5, 6], "C": [3, 4, 4, 4, 3], "D": [6, 5, 5, 5, 6],
	"E": [7, 4, 6, 4, 7], "F": [7, 4, 6, 4, 4], "G": [3, 4, 5, 5, 3], "H": [5, 5, 7, 5, 5],
	"I": [7, 2, 2, 2, 7], "J": [1, 1, 1, 5, 2], "K": [5, 5, 6, 5, 5], "L": [4, 4, 4, 4, 7],
	"M": [5, 7, 7, 5, 5], "N": [6, 5, 5, 5, 5], "O": [2, 5, 5, 5, 2], "P": [6, 5, 6, 4, 4],
	"Q": [2, 5, 5, 6, 3], "R": [6, 5, 6, 5, 5], "S": [3, 4, 2, 1, 6], "T": [7, 2, 2, 2, 2],
	"U": [5, 5, 5, 5, 7], "V": [5, 5, 5, 5, 2], "W": [5, 5, 7, 7, 5], "X": [5, 5, 2, 5, 5],
	"Y": [5, 5, 2, 2, 2], "Z": [7, 1, 2, 4, 7],
	"0": [7, 5, 5, 5, 7], "1": [2, 6, 2, 2, 7], "2": [6, 1, 2, 4, 7], "3": [6, 1, 2, 1, 6],
	"4": [5, 5, 7, 1, 1], "5": [7, 4, 6, 1, 6], "6": [3, 4, 7, 5, 7], "7": [7, 1, 2, 2, 2],
	"8": [7, 5, 7, 5, 7], "9": [7, 5, 7, 1, 6], ":": [0, 2, 0, 2, 0], "-": [0, 0, 7, 0, 0],
	"!": [2, 2, 2, 0, 2], " ": [0, 0, 0, 0, 0],
}
const FONT_ADVANCE: int = 4


static func text_width(text: String, scale: int = 1) -> int:
	return maxi(text.length() * FONT_ADVANCE - 1, 0) * scale


## Draws `text` with its top-left corner at (x, y). Unknown characters are blank.
static func draw_text(img: Image, text: String, x: int, y: int, color: Color, scale: int = 1) -> void:
	var cursor: int = x
	for i: int in text.length():
		var rows: PackedInt32Array = FONT.get(text.substr(i, 1).to_upper(), FONT[" "])
		for row: int in 5:
			for col: int in 3:
				if (rows[row] >> (2 - col)) & 1 == 1:
					_rect(img, cursor + col * scale, y + row * scale, scale, scale, color)
		cursor += FONT_ADVANCE * scale


## A neon sign: glowing tube letters on a dark backing with a tube frame. The backing is part of the
## picture (the unlit sign material just brightens it), so the sign reads as lit letters on a dark plate.
static func neon_image(text: String, color: Color, frame: bool = true) -> Image:
	var scale: int = 2
	var w: int = text_width(text, scale) + 10
	var h: int = 5 * scale + 8
	var back: Color = Color(color.r * 0.07, color.g * 0.07, color.b * 0.07, 1.0)
	var img: Image = _image(w, h, back)
	for y: int in h:
		for x: int in w:
			if _hash(x, y, 120) > 0.9:
				img.set_pixel(x, y, back.lightened(0.25))
	var dim: Color = Color(color.r * 0.45, color.g * 0.45, color.b * 0.45, 1.0)
	draw_text(img, text, 6, 5, dim, scale)
	draw_text(img, text, 5, 4, color, scale)
	if frame:
		_rect(img, 0, 0, w, 1, color)
		_rect(img, 0, h - 1, w, 1, dim)
		_rect(img, 0, 0, 1, h, color)
		_rect(img, w - 1, 0, 1, h, dim)
	return img


## One frame of a grimy propaganda screen (64x40). Kinds: "slogan" (a slogan over the Signals mark),
## "alert" (a flashing bar and a curfew line), "static" (noise). Scanlines and smudges on every frame.
static func screen_image(kind: String, frame: int, text: String) -> Image:
	var w: int = 64
	var h: int = 40
	var back: Color = Color("#10171a")
	var ink: Color = Color("#cfd8c4")
	var teal: Color = Color("#5fe0c8")
	var alarm: Color = Color("#e8456a")
	var img: Image = _image(w, h, back)
	match kind:
		"static":
			for y: int in h:
				for x: int in w:
					var n: float = _hash(x, y, 300 + frame)
					var v: float = 0.12 + n * 0.5
					img.set_pixel(x, y, Color(v * 0.8, v, v * 0.9, 1.0))
		"alert":
			var on: bool = frame % 2 == 0
			_rect(img, 0, 0, w, 8, alarm if on else alarm.darkened(0.6))
			draw_text(img, "ALERT", 20, 2, back, 1)
			draw_text(img, text, 4, 16, ink, 1)
			draw_text(img, "STAY IN", 4, 26, ink, 1)
		_:
			_paint_signals_mark(img, 12 + (frame % 2), 20, 1, teal)
			draw_text(img, text, 26, 12, ink, 1)
			_rect(img, 26, 21, 30, 1, teal)
			_rect(img, 26, 25, 20 + (frame % 3) * 5, 1, ink.darkened(0.3))
			_rect(img, 26, 29, 24, 1, ink.darkened(0.5))
	for y: int in range(0, h, 2):
		for x: int in w:
			img.set_pixel(x, y, img.get_pixel(x, y).darkened(0.25))
	for y: int in h:
		for x: int in w:
			if _value_noise(x, y, 8, 64, 310) > 0.78 and (x + y) % 2 == 0:
				img.set_pixel(x, y, img.get_pixel(x, y).darkened(0.5))
	return img


static func neon_texture(text: String, color: Color) -> ImageTexture:
	var key: String = "neon:%s:%s" % [text, color.to_html()]
	if not _cache.has(key):
		_cache[key] = _texture(neon_image(text, color))
	return _cache[key]


static func screen_texture(kind: String, frame: int, text: String) -> ImageTexture:
	var key: String = "screen:%s:%d:%s" % [kind, frame, text]
	if not _cache.has(key):
		_cache[key] = _texture(screen_image(kind, frame, text))
	return _cache[key]


## A puff of steam (32x32, 1-bit alpha): a dithered cloud. `phase` 0..2 grows it.
static func steam_texture(phase: int) -> ImageTexture:
	var key: String = "steam:%d" % phase
	if not _cache.has(key):
		var img: Image = _image(32, 32, Color(0, 0, 0, 0))
		var radius: float = 8.0 + float(phase) * 3.5
		for y: int in 32:
			for x: int in 32:
				var d: float = Vector2(float(x) - 15.5, float(y) - 15.5).length()
				var edge: float = (_value_noise(x, y, 8, 32, 400 + phase) - 0.5) * 7.0
				if d + edge < radius:
					var shade: float = 0.62 - d / 60.0
					var c: Color = Color(shade, shade * 1.02, shade * 0.98, 1.0)
					if d + edge > radius - 3.0 and (x + y) % 2 == 0:
						continue
					img.set_pixel(x, y, c)
		_cache[key] = _texture(img)
	return _cache[key]
