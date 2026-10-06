class_name GestureIcons
extends RefCounted
## Red's gesture icons (thumbs-up, head shake, "!", "?", "...", heart, sweat drop, shrug, ear perk),
## built from the pixel rows in data/ui/gestures.json (placeholder art; the final PNGs are in
## docs/art_requests.md). Names the Writer uses are mapped through the data's aliases, and an
## unknown name falls back to "..." with a warning so a typo never breaks a conversation.

const DATA_ID: String = "ui/gestures"
const EMPTY_PIXEL: String = "."

static var _cache: Dictionary[String, Array] = {}


## The canonical gesture id for a name ("thumbs-up" -> "thumbs_up"), or "" if it is unknown.
static func resolve(name: String) -> String:
	var key: String = name.strip_edges().to_lower()
	var gestures: Dictionary = DataDB.get_value(DATA_ID, "gestures", {})
	if gestures.has(key):
		return key
	var aliases: Dictionary = DataDB.get_value(DATA_ID, "aliases", {})
	var mapped: String = str(aliases.get(key, ""))
	return mapped if gestures.has(mapped) else ""


## Same as resolve(), but never empty: unknown names give the fallback gesture.
static func resolve_or_fallback(name: String) -> String:
	var id: String = resolve(name)
	if id.is_empty():
		push_warning("GestureIcons: unknown gesture '%s'" % name)
		return str(DataDB.get_value(DATA_ID, "fallback", "dots"))
	return id


static func ids() -> Array[String]:
	var list: Array[String] = []
	list.assign((DataDB.get_value(DATA_ID, "gestures", {}) as Dictionary).keys())
	return list


## "Thumbs-up: Grand tour" -> {"gesture": "thumbs_up", "label": "Grand tour"}. Choice labels
## without a known gesture prefix give {"gesture": "", "label": <whole text>}.
static func split_choice(text: String) -> Dictionary:
	var colon: int = text.find(":")
	if colon > 0:
		var prefix: String = text.substr(0, colon).strip_edges().to_lower()
		var prefixes: Dictionary = DataDB.get_value(DATA_ID, "choice_prefixes", {})
		if prefixes.has(prefix):
			return {"gesture": str(prefixes[prefix]), "label": text.substr(colon + 1).strip_edges()}
	return {"gesture": "", "label": text}


## The sound id for a gesture ("red_thumbs_up"), or "" when it has none.
static func sfx_for(gesture_id: String) -> String:
	return str(DataDB.get_value(DATA_ID, "sfx.%s" % gesture_id, ""))


## The animation frames of a gesture as 16x16 textures (cached).
static func get_frames(gesture_id: String) -> Array[ImageTexture]:
	if not _cache.has(gesture_id):
		_cache[gesture_id] = _build(gesture_id)
	var frames: Array[ImageTexture] = []
	frames.assign(_cache[gesture_id])
	return frames


static func get_icon_size() -> int:
	return int(DataDB.get_value(DATA_ID, "icon_size", 16))


static func _build(gesture_id: String) -> Array:
	var legend: Dictionary[String, Color] = {}
	var raw_legend: Dictionary = DataDB.get_value(DATA_ID, "legend", {})
	for key: String in raw_legend:
		legend[key] = Color.html(str(raw_legend[key]))
	var built: Array = []
	var frames: Array = DataDB.get_value(DATA_ID, "gestures.%s.frames" % gesture_id, [])
	var size: int = get_icon_size()
	for rows: Array in frames:
		var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
		for y: int in mini(rows.size(), size):
			var row: String = rows[y]
			for x: int in mini(row.length(), size):
				var pixel: String = row[x]
				if pixel != EMPTY_PIXEL and legend.has(pixel):
					image.set_pixel(x, y, legend[pixel])
		built.append(ImageTexture.create_from_image(image))
	return built
