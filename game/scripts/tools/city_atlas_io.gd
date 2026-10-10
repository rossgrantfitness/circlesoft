class_name CityAtlasIo
extends RefCounted
## Reads and writes data/world/city_texture_atlas.json for the city texture tools (slicer, seamless copies).
## One tile per line group, rects inline, whole numbers written as integers, so the file stays readable.

const ATLAS_PATH: String = "res://data/world/city_texture_atlas.json"
const FIELD_ORDER: PackedStringArray = ["id", "rect", "kind", "tiles_seamlessly", "tiles_x", "tiles_y",
	"tiles_seamlessly_busted", "variants", "rect_override", "text", "text_busted", "notes", "busted_notes", "seam",
	"seamless_copy", "seam_method", "seamless_copy_size", "seamless_copy_busted", "seam_method_busted",
	"seamless_copy_size_busted", "seam_fix_rejected"]


static func write_atlas(atlas: Dictionary) -> void:
	var out: String = "{\n"
	var keys: Array = atlas.keys()
	for k: Variant in keys:
		if String(k) == "tiles":
			continue
		out += "\t%s: %s,\n" % [JSON.stringify(k), json_text(atlas[k])]
	out += "\t\"tiles\": [\n"
	var tiles: Array = atlas["tiles"]
	for i: int in tiles.size():
		var tile: Dictionary = tiles[i]
		var lines: PackedStringArray = []
		for field: String in FIELD_ORDER:
			if tile.has(field):
				lines.append("\t\t\t%s: %s" % [JSON.stringify(field), json_text(tile[field])])
		out += "\t\t{\n" + ",\n".join(lines) + "\n\t\t}" + ("," if i < tiles.size() - 1 else "") + "\n"
	out += "\t]\n}\n"
	var f: FileAccess = FileAccess.open(ProjectSettings.globalize_path(ATLAS_PATH), FileAccess.WRITE)
	f.store_string(out)
	f.close()


## JSON text with whole-number floats written as integers (Godot reads every number back as a float)
## and keys kept in the order they were written.
static func json_text(value: Variant) -> String:
	if value is float and is_equal_approx(float(value), roundf(float(value))):
		return str(int(value))
	if value is Array:
		var items: PackedStringArray = []
		for item: Variant in value:
			items.append(json_text(item))
		return "[" + ", ".join(items) + "]"
	if value is Dictionary:
		var pairs: PackedStringArray = []
		for key: Variant in value:
			pairs.append("%s: %s" % [JSON.stringify(key), json_text(value[key])])
		return "{" + ", ".join(pairs) + "}"
	return JSON.stringify(value, "", false)


static func read_atlas() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(ATLAS_PATH)) as Dictionary
