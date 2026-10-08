extends SceneTree
## Slices Ross's city texture packs (clean and busted) into one PNG per tile. Mechanical crops only:
## the pixels are copied exactly, nothing is repainted, resampled or recolored.
##
##   godot --headless --path game -s res://scripts/tools/slice_city_texture_atlas.gd
##   godot --headless --path game -s res://scripts/tools/slice_city_texture_atlas.gd -- --measure
##
## Reads res://data/world/city_texture_atlas.json (tile ids, rects, kinds). For every variant listed in
## its "variants" block it loads that sheet and writes <tile_dir>/<id>.png. A tile can carry a
## "rect_override" {"busted": [x, y, w, h]} if a variant's cell ever shifts from the clean layout.
## --measure also re-tests every tile's edges for seamless tiling and rewrites the atlas file.
##
## Seamless test (edge pixel continuity): compare the first and last column (and row) of the tile, as
## the repeat would put them side by side. An axis tiles if that wrap difference is no bigger than
## EDGE_RATIO_MAX times the tile's own typical neighbour-pixel difference, and under EDGE_ABS_MAX
## (0..255 scale, mean of the RGB channels). "tiles_seamlessly" is true only for surface kinds
## (floor, wall, trim) that pass on both axes; props, doors, signs and decals are single-use pieces.
##
## Run `godot --headless --path game --import` afterwards so Godot imports the new PNG files.

const ATLAS_PATH: String = "res://data/world/city_texture_atlas.json"
const EDGE_RATIO_MAX: float = 2.0
const EDGE_ABS_MAX: float = 20.0
const SURFACE_KINDS: PackedStringArray = ["floor", "wall", "trim"]


func _initialize() -> void:
	var measure: bool = OS.get_cmdline_user_args().has("--measure")
	var text: String = FileAccess.get_file_as_string(ATLAS_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("could not read " + ATLAS_PATH)
		quit(1)
		return
	var atlas: Dictionary = parsed
	var variants: Dictionary = atlas["variants"]
	var tiles: Array = atlas["tiles"]
	var failures: int = 0
	var written: int = 0
	for variant_name: String in variants:
		var info: Dictionary = variants[variant_name]
		var sheet: Image = Image.load_from_file(ProjectSettings.globalize_path(String(info["source"])))
		if sheet == null:
			push_error("missing sheet for variant " + variant_name)
			failures += 1
			continue
		sheet.convert(Image.FORMAT_RGBA8)
		var tile_dir: String = String(info["tile_dir"])
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(tile_dir))
		for tile_value: Variant in tiles:
			var tile: Dictionary = tile_value
			var rect: Array = _rect_for(tile, variant_name)
			var piece: Image = sheet.get_region(Rect2i(int(rect[0]), int(rect[1]), int(rect[2]), int(rect[3])))
			var path: String = tile_dir.path_join(String(tile["id"]) + ".png")
			var err: Error = piece.save_png(ProjectSettings.globalize_path(path))
			if err != OK:
				push_error("could not write " + path)
				failures += 1
				continue
			written += 1
			if measure:
				_record_seams(tile, variant_name, piece)
	if measure:
		_write_atlas(atlas)
	print("sliced %d tile files, %d failures%s" % [written, failures, ", seam test rewritten" if measure else ""])
	quit(1 if failures > 0 else 0)


func _rect_for(tile: Dictionary, variant_name: String) -> Array:
	var overrides: Dictionary = tile.get("rect_override", {})
	if overrides.has(variant_name):
		return overrides[variant_name]
	return tile["rect"]


## Mean absolute difference per channel (0..255) between two pixel lines.
func _line_diff(image: Image, a: Vector2i, b: Vector2i, step: Vector2i, count: int) -> float:
	var total: float = 0.0
	for i: int in count:
		var ca: Color = image.get_pixelv(a + step * i)
		var cb: Color = image.get_pixelv(b + step * i)
		total += (absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)) * 255.0 / 3.0
	return total / float(count)


func _axis_error(image: Image, horizontal: bool) -> Dictionary:
	var w: int = image.get_width()
	var h: int = image.get_height()
	var count: int = h if horizontal else w
	var along: Vector2i = Vector2i(0, 1) if horizontal else Vector2i(1, 0)
	var across: Vector2i = Vector2i(1, 0) if horizontal else Vector2i(0, 1)
	var length: int = w if horizontal else h
	var wrap: float = _line_diff(image, Vector2i.ZERO, across * (length - 1), along, count)
	var neighbour: float = 0.0
	for i: int in length - 1:
		neighbour += _line_diff(image, across * i, across * (i + 1), along, count)
	neighbour /= float(length - 1)
	var ratio: float = wrap / maxf(neighbour, 1.0)
	return {"wrap": snappedf(wrap, 0.1), "ratio": snappedf(ratio, 0.1),
		"ok": ratio <= EDGE_RATIO_MAX and wrap <= EDGE_ABS_MAX}


func _record_seams(tile: Dictionary, variant_name: String, piece: Image) -> void:
	var x_result: Dictionary = _axis_error(piece, true)
	var y_result: Dictionary = _axis_error(piece, false)
	var seam: Dictionary = tile.get("seam", {})
	seam[variant_name] = {"x_ok": x_result["ok"], "y_ok": y_result["ok"],
		"x_ratio": x_result["ratio"], "y_ratio": y_result["ratio"],
		"x_wrap": x_result["wrap"], "y_wrap": y_result["wrap"]}
	tile["seam"] = seam
	var surface: bool = SURFACE_KINDS.has(String(tile["kind"]))
	var seamless: bool = surface and x_result["ok"] and y_result["ok"]
	if variant_name == "clean":
		tile["tiles_seamlessly"] = seamless
		tile["tiles_x"] = surface and x_result["ok"]
		tile["tiles_y"] = surface and y_result["ok"]
	else:
		tile["tiles_seamlessly_" + variant_name] = seamless


# ---- Writing: one tile per line group, rects inline, so the file stays readable and diffs small. ----

const FIELD_ORDER: PackedStringArray = ["id", "rect", "kind", "tiles_seamlessly", "tiles_x", "tiles_y",
	"tiles_seamlessly_busted", "variants", "rect_override", "text", "text_busted", "notes", "busted_notes", "seam"]


func _write_atlas(atlas: Dictionary) -> void:
	var out: String = "{\n"
	var keys: Array = atlas.keys()
	for k: Variant in keys:
		if String(k) == "tiles":
			continue
		out += "\t%s: %s,\n" % [JSON.stringify(k), _json(atlas[k])]
	out += "\t\"tiles\": [\n"
	var tiles: Array = atlas["tiles"]
	for i: int in tiles.size():
		var tile: Dictionary = tiles[i]
		var lines: PackedStringArray = []
		for field: String in FIELD_ORDER:
			if tile.has(field):
				lines.append("\t\t\t%s: %s" % [JSON.stringify(field), _json(tile[field])])
		out += "\t\t{\n" + ",\n".join(lines) + "\n\t\t}" + ("," if i < tiles.size() - 1 else "") + "\n"
	out += "\t]\n}\n"
	var f: FileAccess = FileAccess.open(ProjectSettings.globalize_path(ATLAS_PATH), FileAccess.WRITE)
	f.store_string(out)
	f.close()


## JSON text with whole-number floats written as integers (Godot reads every number back as a float)
## and keys kept in the order they were written.
func _json(value: Variant) -> String:
	if value is float and is_equal_approx(float(value), roundf(float(value))):
		return str(int(value))
	if value is Array:
		var items: PackedStringArray = []
		for item: Variant in value:
			items.append(_json(item))
		return "[" + ", ".join(items) + "]"
	if value is Dictionary:
		var pairs: PackedStringArray = []
		for key: Variant in value:
			pairs.append("%s: %s" % [JSON.stringify(key), _json(value[key])])
		return "{" + ", ".join(pairs) + "}"
	return JSON.stringify(value, "", false)
