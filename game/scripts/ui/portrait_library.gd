class_name PortraitLibrary
extends RefCounted
## Finds and draws dialogue portraits. Everything comes from data/ui/portraits.json: each named
## character has a path template (".../ptr_otis_{face}.png"), a default face and a list of faces.
## When the PNG for a face exists it is loaded by that path and drawn; when it does not, a
## placeholder "initials head" is drawn (a colored head with eyes, brows and a mouth that change
## with the expression, and the character's initial in the corner). Dropping real portraits into
## game/art/final/portraits/ needs no code change.

const DATA_ID: String = "ui/portraits"
const GRID: int = 16
const PLACEHOLDER_SHADE: float = 0.55

static var _cache: Dictionary[String, Texture2D] = {}


# ---- data queries ----

static func has_character(key: String) -> bool:
	return DataDB.get_value(DATA_ID, "characters.%s" % key, null) != null


static func character_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.assign((DataDB.get_value(DATA_ID, "characters", {}) as Dictionary).keys())
	return ids


static func faces_of(key: String) -> Array[String]:
	var list: Array[String] = []
	list.assign(DataDB.get_value(DATA_ID, "characters.%s.faces" % key, []))
	return list


static func default_face(key: String) -> String:
	var faces: Array[String] = faces_of(key)
	var fallback: String = faces[0] if not faces.is_empty() else ""
	return str(DataDB.get_value(DATA_ID, "characters.%s.default_face" % key, fallback))


static func is_known_face(key: String, face: String) -> bool:
	return faces_of(key).has(face)


## The file a face is loaded from, with {face} filled in ("" for an unknown character).
static func path_for(key: String, face: String) -> String:
	var template: String = str(DataDB.get_value(DATA_ID, "characters.%s.path" % key, ""))
	return template.replace("{face}", face)


static func initial_of(key: String) -> String:
	var fallback: String = key.substr(0, 1).to_upper()
	return str(DataDB.get_value(DATA_ID, "characters.%s.initial" % key, fallback))


static func color_of(key: String) -> Color:
	return Color.html(str(DataDB.get_value(DATA_ID, "characters.%s.color" % key, "#8D97A5")))


# ---- loading ----

## The portrait texture for a face, loaded by its data path, or null when there is no art yet.
## Works for imported res:// files and for plain PNG files anywhere else (user:// in tests).
static func load_texture(key: String, face: String) -> Texture2D:
	var path: String = path_for(key, face)
	if path.is_empty():
		return null
	if _cache.has(path):
		return _cache[path]
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	elif FileAccess.file_exists(path):
		var image: Image = Image.load_from_file(path)
		if image != null and not image.is_empty():
			texture = ImageTexture.create_from_image(image)
	_cache[path] = texture
	return texture


static func has_art(key: String, face: String) -> bool:
	return load_texture(key, face) != null


static func clear_cache() -> void:
	_cache.clear()


# ---- slot geometry ----

## The crop (in 96x96 source pixels) a slot shows: "bubble" or "box".
static func crop_for(kind: String) -> Rect2i:
	var raw: Array = DataDB.get_value(DATA_ID, "slot.%s_crop" % kind, [0, 0, 96, 96])
	return Rect2i(int(raw[0]), int(raw[1]), int(raw[2]), int(raw[3]))


static func slot_size(kind: String) -> int:
	return int(DataDB.get_value(DATA_ID, "slot.%s_size" % kind, 32))


# ---- drawing ----

## Draws the portrait (art if it exists, else the placeholder head) into `rect` on `canvas`.
## `kind` is "bubble" or "box" and picks the crop. `back` fills behind transparent art.
static func draw(canvas: CanvasItem, key: String, face: String, rect: Rect2i, kind: String, back: Color) -> void:
	canvas.draw_rect(Rect2(rect), back)
	var texture: Texture2D = load_texture(key, face)
	if texture != null:
		var scale: float = float(texture.get_width()) / float(DataDB.get_value(DATA_ID, "slot.source_size", 96))
		var crop: Rect2i = crop_for(kind)
		var region: Rect2 = Rect2(Vector2(crop.position) * scale, Vector2(crop.size) * scale)
		canvas.draw_texture_rect_region(texture, Rect2(rect), region)
		return
	_draw_placeholder(canvas, key, face, rect)


static func _draw_placeholder(canvas: CanvasItem, key: String, face: String, rect: Rect2i) -> void:
	var unit: int = maxi(1, rect.size.x / GRID)
	var origin: Vector2i = rect.position
	var accent: Color = color_of(key)
	var shade: Color = accent.darkened(PLACEHOLDER_SHADE)
	var ink: Color = Color.html("#14121F")
	var chalk: Color = Color.html("#EDEAD8")
	var look: Dictionary = DataDB.get_value(DATA_ID, "faces.%s" % face, {"eyes": "open", "brows": "none", "mouth": "flat"})
	# Head: a rounded block, with a darker band along the bottom for a bit of depth.
	_cells(canvas, origin, unit, Rect2i(3, 2, 10, 1), accent)
	_cells(canvas, origin, unit, Rect2i(2, 3, 12, 10), accent)
	_cells(canvas, origin, unit, Rect2i(3, 13, 10, 1), shade)
	_cells(canvas, origin, unit, Rect2i(2, 12, 12, 1), shade)
	_draw_eyes(canvas, origin, unit, str(look.get("eyes", "open")), ink, chalk)
	_draw_brows(canvas, origin, unit, str(look.get("brows", "none")), ink)
	_draw_mouth(canvas, origin, unit, str(look.get("mouth", "flat")), ink)
	# The initial in the bottom-right corner, so the placeholder says whose face it stands for.
	var font: Font = UiFonts.get_font("tag")
	var font_size: int = maxi(8, unit * 5)
	var at: Vector2 = Vector2(origin) + Vector2(rect.size.x - font_size * 0.8, rect.size.y - 1)
	canvas.draw_string(font, at + Vector2(1, 1), initial_of(key), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
	canvas.draw_string(font, at, initial_of(key), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, chalk)


static func _cells(canvas: CanvasItem, origin: Vector2i, unit: int, cells: Rect2i, color: Color) -> void:
	canvas.draw_rect(Rect2(origin + cells.position * unit, cells.size * unit), color)


static func _draw_eyes(canvas: CanvasItem, origin: Vector2i, unit: int, eyes: String, ink: Color, chalk: Color) -> void:
	for x: int in [5, 10]:
		match eyes:
			"wide":
				_cells(canvas, origin, unit, Rect2i(x - 1, 5, 3, 3), chalk)
				_cells(canvas, origin, unit, Rect2i(x, 6, 1, 1), ink)
			"half":
				_cells(canvas, origin, unit, Rect2i(x, 7, 2, 1), ink)
			"happy":
				_cells(canvas, origin, unit, Rect2i(x, 6, 2, 1), ink)
				_cells(canvas, origin, unit, Rect2i(x - 1 if x < 8 else x + 2, 7, 1, 1), ink)
			_:
				_cells(canvas, origin, unit, Rect2i(x, 6, 1, 2), ink)


static func _draw_brows(canvas: CanvasItem, origin: Vector2i, unit: int, brows: String, ink: Color) -> void:
	match brows:
		"angry":
			_cells(canvas, origin, unit, Rect2i(4, 4, 2, 1), ink)
			_cells(canvas, origin, unit, Rect2i(10, 4, 2, 1), ink)
			_cells(canvas, origin, unit, Rect2i(6, 5, 1, 1), ink)
			_cells(canvas, origin, unit, Rect2i(9, 5, 1, 1), ink)
		"worried":
			_cells(canvas, origin, unit, Rect2i(4, 5, 2, 1), ink)
			_cells(canvas, origin, unit, Rect2i(10, 5, 2, 1), ink)
			_cells(canvas, origin, unit, Rect2i(4, 4, 1, 1), ink)
			_cells(canvas, origin, unit, Rect2i(11, 4, 1, 1), ink)


static func _draw_mouth(canvas: CanvasItem, origin: Vector2i, unit: int, mouth: String, ink: Color) -> void:
	match mouth:
		"smile":
			_cells(canvas, origin, unit, Rect2i(6, 10, 4, 1), ink)
			_cells(canvas, origin, unit, Rect2i(5, 9, 1, 1), ink)
			_cells(canvas, origin, unit, Rect2i(10, 9, 1, 1), ink)
		"grin":
			_cells(canvas, origin, unit, Rect2i(5, 9, 6, 1), ink)
			_cells(canvas, origin, unit, Rect2i(6, 10, 4, 1), ink)
		"frown":
			_cells(canvas, origin, unit, Rect2i(6, 9, 4, 1), ink)
			_cells(canvas, origin, unit, Rect2i(5, 10, 1, 1), ink)
			_cells(canvas, origin, unit, Rect2i(10, 10, 1, 1), ink)
		"smirk":
			_cells(canvas, origin, unit, Rect2i(6, 10, 3, 1), ink)
			_cells(canvas, origin, unit, Rect2i(9, 9, 2, 1), ink)
		"o":
			_cells(canvas, origin, unit, Rect2i(7, 9, 2, 2), ink)
		"big_o":
			_cells(canvas, origin, unit, Rect2i(6, 9, 4, 3), ink)
		"wavy":
			_cells(canvas, origin, unit, Rect2i(5, 10, 2, 1), ink)
			_cells(canvas, origin, unit, Rect2i(7, 9, 2, 1), ink)
			_cells(canvas, origin, unit, Rect2i(9, 10, 2, 1), ink)
		_:
			_cells(canvas, origin, unit, Rect2i(6, 10, 4, 1), ink)
