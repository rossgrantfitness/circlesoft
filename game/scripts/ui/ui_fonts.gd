class_name UiFonts
extends RefCounted
## The UI fonts from data/ui/ui_theme.json ("fonts"). Every key (menu, body, dialogue, tag, title)
## is the same face (Nunito, variable weight) at its own size and weight, so this builds a
## FontVariation with the weight set and caches it. Sizes are whole pixels.

const THEME_ID: String = "ui/ui_theme"
const WEIGHT_AXIS: String = "wght"

static var _cache: Dictionary[String, Font] = {}


## The font for a key ("menu", "body", "dialogue", "tag", "title").
static func get_font(key: String) -> Font:
	if not _cache.has(key):
		_cache[key] = _build(key)
	return _cache[key]


static func get_size(key: String) -> int:
	return int(DataDB.get_value(THEME_ID, "fonts.%s.size" % key, 12))


## Pixel width of a string in a font key (shadow not included).
static func text_width(key: String, text: String) -> int:
	return int(ceil(get_font(key).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, get_size(key)).x))


## Forget cached fonts (tests that change the theme data).
static func clear_cache() -> void:
	_cache.clear()


static func _build(key: String) -> Font:
	var entry: Dictionary = DataDB.get_value(THEME_ID, "fonts.%s" % key, {})
	var base: Font = load(str(entry.get("path", ""))) as Font
	if base == null:
		push_error("UiFonts: no font file for key '%s'" % key)
		return ThemeDB.fallback_font
	var variation: FontVariation = FontVariation.new()
	variation.base_font = base
	var tag: int = TextServerManager.get_primary_interface().name_to_tag(WEIGHT_AXIS)
	variation.variation_opentype = {tag: float(entry.get("weight", 400))}
	return variation
