extends TestCase
## Ross's city texture packs (clean and busted, 2026-10-08): the atlas catalog must match the sheets and
## the sliced tile PNGs (data/world/city_texture_atlas.json, scripts/tools/slice_city_texture_atlas.gd).

const ATLAS_PATH: String = "res://data/world/city_texture_atlas.json"
const SHEET_SIZE: Vector2i = Vector2i(1024, 1024)
const KINDS: PackedStringArray = ["floor", "wall", "trim", "door", "prop_face", "sign", "decal"]
const KNOWN_VARIANTS: PackedStringArray = ["clean", "busted"]

var _atlas: Dictionary = {}


func before_each() -> void:
	super.before_each()
	_atlas = JSON.parse_string(FileAccess.get_file_as_string(ATLAS_PATH)) as Dictionary


func _variant_names() -> Array:
	return (_atlas["variants"] as Dictionary).keys()


func _rect_of(tile: Dictionary, variant: String) -> Rect2i:
	var overrides: Dictionary = tile.get("rect_override", {})
	var r: Array = overrides[variant] if overrides.has(variant) else tile["rect"]
	return Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3]))


func test_atlas_declares_both_variants_and_a_tile_list() -> void:
	assert_eq(Vector2i(int((_atlas["atlas_size"] as Array)[0]), int((_atlas["atlas_size"] as Array)[1])), SHEET_SIZE)
	for variant: String in KNOWN_VARIANTS:
		assert_has(_variant_names(), variant)
		var info: Dictionary = (_atlas["variants"] as Dictionary)[variant]
		assert_true(FileAccess.file_exists(String(info["source"])), "missing sheet " + String(info["source"]))
	assert_gt((_atlas["tiles"] as Array).size(), 60.0, "expected the full tile list")


func test_every_tile_has_clean_fields() -> void:
	var seen: Dictionary = {}
	var snake: RegEx = RegEx.create_from_string("^[a-z0-9]+(_[a-z0-9]+)*$")
	for tile_value: Variant in _atlas["tiles"]:
		var tile: Dictionary = tile_value
		var id: String = String(tile["id"])
		assert_not_null(snake.search(id), id + " should be snake_case")
		assert_false(seen.has(id), id + " is duplicated")
		seen[id] = true
		assert_has(KINDS, String(tile["kind"]), id + " has an unknown kind")
		assert_eq((tile["rect"] as Array).size(), 4, id + " rect needs 4 numbers")
		assert_true(tile["tiles_seamlessly"] is bool, id + " needs tiles_seamlessly")
		assert_true(tile["variants"] is Array and (tile["variants"] as Array).size() > 0, id + " needs variants")
		for variant: Variant in tile["variants"]:
			assert_has(KNOWN_VARIANTS, String(variant), id + " lists an unknown variant")


func test_every_rect_is_inside_the_sheet() -> void:
	var sheet: Rect2i = Rect2i(Vector2i.ZERO, SHEET_SIZE)
	for variant: String in _variant_names():
		for tile_value: Variant in _atlas["tiles"]:
			var tile: Dictionary = tile_value
			var rect: Rect2i = _rect_of(tile, variant)
			assert_gt(rect.size.x, 0.0, "%s/%s has no width" % [variant, tile["id"]])
			assert_gt(rect.size.y, 0.0, "%s/%s has no height" % [variant, tile["id"]])
			assert_true(sheet.encloses(rect), "%s/%s rect %s is outside the sheet" % [variant, tile["id"], rect])


func test_no_rects_overlap() -> void:
	for variant: String in _variant_names():
		var tiles: Array = _atlas["tiles"]
		for i: int in tiles.size():
			for j: int in range(i + 1, tiles.size()):
				var a: Rect2i = _rect_of(tiles[i], variant)
				var b: Rect2i = _rect_of(tiles[j], variant)
				assert_false(a.intersects(b), "%s: %s overlaps %s" % [variant, tiles[i]["id"], tiles[j]["id"]])


func test_every_tile_png_exists_with_the_matching_size() -> void:
	for variant: String in _variant_names():
		var tile_dir: String = String(((_atlas["variants"] as Dictionary)[variant] as Dictionary)["tile_dir"])
		for tile_value: Variant in _atlas["tiles"]:
			var tile: Dictionary = tile_value
			var path: String = tile_dir.path_join(String(tile["id"]) + ".png")
			assert_true(FileAccess.file_exists(path), "missing " + path)
			var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
			assert_not_null(image, "cannot read " + path)
			if image != null:
				assert_eq(image.get_size(), _rect_of(tile, variant).size, path + " has the wrong size")


## The tiles are mechanical crops: their pixels must equal the sheet region exactly.
func test_tiles_are_lossless_crops_of_the_sheets() -> void:
	for variant: String in _variant_names():
		var info: Dictionary = (_atlas["variants"] as Dictionary)[variant]
		var sheet: Image = Image.load_from_file(ProjectSettings.globalize_path(String(info["source"])))
		assert_not_null(sheet, "cannot read the " + variant + " sheet")
		if sheet == null:
			continue
		assert_eq(sheet.get_size(), SHEET_SIZE, variant + " sheet size")
		sheet.convert(Image.FORMAT_RGBA8)
		var tile_dir: String = String(info["tile_dir"])
		for tile_value: Variant in _atlas["tiles"]:
			var tile: Dictionary = tile_value
			var piece: Image = Image.load_from_file(ProjectSettings.globalize_path(
				tile_dir.path_join(String(tile["id"]) + ".png")))
			if piece == null:
				continue
			piece.convert(Image.FORMAT_RGBA8)
			var expected: Image = sheet.get_region(_rect_of(tile, variant))
			assert_true(piece.get_data() == expected.get_data(), "%s/%s differs from the sheet" % [variant, tile["id"]])
