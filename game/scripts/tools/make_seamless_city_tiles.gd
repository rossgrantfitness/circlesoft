extends SceneTree
## Makes seam-fixed COPIES of Ross's floor and wall tiles that do not tile on their own (clean and busted sheets).
## Ross's sheets and the tiles in tiles/ and tiles_busted/ are never touched; the copies go to
## tiles_seamless/ and tiles_busted_seamless/ under the same ids. Re-runnable:
##   godot --headless --path game -s res://scripts/tools/make_seamless_city_tiles.gd
##   (then: godot --headless --path game --import)
##
## Pixel-art-safe methods (no alpha blend, so no new in-between colours; every output pixel is a pixel of the original):
##  1. shift_crop: look for a 1-3 px crop (any split between the two sides) that makes opposite edges line up.
##     Keeps the artwork exactly as drawn, only a few rows or columns shorter ("seamless_copy_size" says how big).
##  2. offset_dither: roll the tile by half its size so the old seam sits in the middle, then fill a 4-8 px band
##     across that seam from the untouched original (whose middle is continuous) using a dithered random pick,
##     most likely at the seam line and fading out to the band edge. The wrapped edges now match.
## Per failing axis, method 1 is tried first; method 2 is the fallback. A tile whose fix looked bad is listed in
## the atlas under "seam_fix_rejected" ({variant: reason}); this tool then makes no copy for it.
## Each tile gets seamless_copy, seam_method and seamless_copy_size (suffix _busted for the busted sheet).

const EDGE_RATIO_MAX: float = 2.0
const EDGE_ABS_MAX: float = 20.0
const FIXABLE_KINDS: PackedStringArray = ["floor", "wall"]
const MAX_CROP_PX: int = 3
const BAND_WIDTHS: Array[int] = [4, 6, 8]
const CITY_DIR: String = "res://art/final/textures/city/"
const VARIANT_DIRS: Dictionary = {"clean": "tiles_seamless", "busted": "tiles_busted_seamless"}


func _initialize() -> void:
	var atlas: Dictionary = CityAtlasIo.read_atlas()
	var variants: Dictionary = atlas["variants"]
	var made: int = 0
	var counts: Dictionary = {}
	for variant_name: String in variants:
		var source_dir: String = String((variants[variant_name] as Dictionary)["tile_dir"])
		var out_dir: String = CITY_DIR + String(VARIANT_DIRS[variant_name]) + "/"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
		var suffix: String = "" if variant_name == "clean" else "_" + variant_name
		for tile_value: Variant in atlas["tiles"]:
			var tile: Dictionary = tile_value
			if not FIXABLE_KINDS.has(String(tile["kind"])):
				continue
			var id: String = String(tile["id"])
			var out_path: String = ProjectSettings.globalize_path(out_dir + id + ".png")
			var rejected: Dictionary = tile.get("seam_fix_rejected", {})
			tile.erase("seamless_copy" + suffix)
			tile.erase("seam_method" + suffix)
			tile.erase("seamless_copy_size" + suffix)
			var seam: Dictionary = (tile["seam"] as Dictionary)[variant_name]
			if bool(seam["x_ok"]) and bool(seam["y_ok"]):
				_set(tile, suffix, false, "already_seamless", Vector2i.ZERO)
				_remove(out_path)
				_count(counts, variant_name, "already_seamless")
				continue
			if rejected.has(variant_name):
				_set(tile, suffix, false, "rejected", Vector2i.ZERO)
				_remove(out_path)
				_count(counts, variant_name, "rejected")
				continue
			var original: Image = Image.load_from_file(ProjectSettings.globalize_path(source_dir + id + ".png"))
			original.convert(Image.FORMAT_RGBA8)
			var result: Dictionary = _fix(original, not bool(seam["x_ok"]), not bool(seam["y_ok"]))
			if not bool(result["ok"]):
				_set(tile, suffix, false, "failed_measure", Vector2i.ZERO)
				_remove(out_path)
				_count(counts, variant_name, "failed_measure")
				continue
			var image: Image = result["image"]
			image.save_png(out_path)
			made += 1
			_set(tile, suffix, true, String(result["method"]), image.get_size())
			_count(counts, variant_name, String(result["method"]))
	CityAtlasIo.write_atlas(atlas)
	print("made %d seamless copies; by variant and method: %s" % [made, counts])
	quit(0)


func _set(tile: Dictionary, suffix: String, copy: bool, method: String, size: Vector2i) -> void:
	tile["seamless_copy" + suffix] = copy
	tile["seam_method" + suffix] = method
	if copy:
		tile["seamless_copy_size" + suffix] = [size.x, size.y]


func _count(counts: Dictionary, variant_name: String, method: String) -> void:
	var key: String = variant_name + ":" + method
	counts[key] = int(counts.get(key, 0)) + 1


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


# ---- fixing ----

func _fix(original: Image, fix_x: bool, fix_y: bool) -> Dictionary:
	var image: Image = original
	var methods: PackedStringArray = []
	for horizontal: bool in [true, false]:
		if (horizontal and not fix_x) or (not horizontal and not fix_y):
			continue
		var cropped: Image = _try_crop(image, horizontal)
		if cropped != null:
			image = cropped
			methods.append("shift_crop_" + ("x" if horizontal else "y"))
		else:
			image = _offset_dither(image, horizontal, not horizontal)
			methods.append("offset_dither_" + ("x" if horizontal else "y"))
	var ok: bool = bool(_axis(image, true)["ok"]) and bool(_axis(image, false)["ok"])
	var name: String = "+".join(methods)
	# tidy names: both axes by the same method read as one name
	if methods.size() == 2 and methods[0].trim_suffix("_x") == methods[1].trim_suffix("_y"):
		name = methods[0].trim_suffix("_x")
	return {"image": image, "ok": ok, "method": name}


## Looks for a crop of 1 to MAX_CROP_PX rows or columns (split any way between the two sides) with matching edges.
func _try_crop(image: Image, horizontal: bool) -> Image:
	var length: int = image.get_width() if horizontal else image.get_height()
	var best_wrap: float = INF
	var best: Vector2i = Vector2i(-1, -1)
	for cut: int in range(1, MAX_CROP_PX + 1):
		for from_start: int in range(0, cut + 1):
			var region: Rect2i = _crop_rect(image, horizontal, from_start, cut - from_start)
			var piece: Image = image.get_region(region)
			var result: Dictionary = _axis(piece, horizontal)
			if bool(result["ok"]) and float(result["wrap"]) < best_wrap:
				best_wrap = float(result["wrap"])
				best = Vector2i(from_start, cut - from_start)
	if best.x < 0:
		return null
	return image.get_region(_crop_rect(image, horizontal, best.x, best.y))


func _crop_rect(image: Image, horizontal: bool, from_start: int, from_end: int) -> Rect2i:
	if horizontal:
		return Rect2i(from_start, 0, image.get_width() - from_start - from_end, image.get_height())
	return Rect2i(0, from_start, image.get_width(), image.get_height() - from_start - from_end)


## Rolls the tile by half its size on the chosen axes, then patches the seam band from the original.
func _offset_dither(image: Image, along_x: bool, along_y: bool) -> Image:
	var best: Image = null
	var best_score: float = INF
	for band: int in BAND_WIDTHS:
		var candidate: Image = _offset_dither_band(image, along_x, along_y, band)
		var score: float = 0.0
		if along_x:
			score = maxf(score, _centre_ratio(candidate, true))
		if along_y:
			score = maxf(score, _centre_ratio(candidate, false))
		if score < best_score - 0.05:
			best_score = score
			best = candidate
	return best


func _offset_dither_band(image: Image, along_x: bool, along_y: bool, band: int) -> Image:
	var w: int = image.get_width()
	var h: int = image.get_height()
	var half: float = float(band) * 0.5
	var out: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y: int in h:
		for x: int in w:
			var rolled: Color = image.get_pixel((x + w / 2) % w if along_x else x, (y + h / 2) % h if along_y else y)
			# chance of taking the untouched original pixel: 1 on the old seam line, 0 at the band edge
			var chance: float = 0.0
			if along_x:
				chance = maxf(chance, 1.0 - absf(float(x) + 0.5 - float(w) * 0.5) / half)
			if along_y:
				chance = maxf(chance, 1.0 - absf(float(y) + 0.5 - float(h) * 0.5) / half)
			if chance > 0.0 and _random(x, y, band) < chance:
				out.set_pixel(x, y, image.get_pixel(x, y))
			else:
				out.set_pixel(x, y, rolled)
	return out


func _random(x: int, y: int, salt: int) -> float:
	var h: int = (x * 374761393 + y * 668265263 + salt * 144665) & 0xffffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0xffffffff
	h = h ^ (h >> 16)
	return float(h & 0xffff) / 65536.0


# ---- measuring (same test as scripts/tools/slice_city_texture_atlas.gd) ----

func _line_diff(image: Image, a: Vector2i, b: Vector2i, step: Vector2i, count: int) -> float:
	var total: float = 0.0
	for i: int in count:
		var ca: Color = image.get_pixelv(a + step * i)
		var cb: Color = image.get_pixelv(b + step * i)
		total += (absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)) * 255.0 / 3.0
	return total / float(count)


func _axis(image: Image, horizontal: bool) -> Dictionary:
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
	return {"wrap": wrap, "ratio": ratio, "ok": ratio <= EDGE_RATIO_MAX and wrap <= EDGE_ABS_MAX}


## How hard the middle line of the tile still jumps compared with ordinary neighbour columns.
func _centre_ratio(image: Image, horizontal: bool) -> float:
	var w: int = image.get_width()
	var h: int = image.get_height()
	var length: int = w if horizontal else h
	var count: int = h if horizontal else w
	var along: Vector2i = Vector2i(0, 1) if horizontal else Vector2i(1, 0)
	var across: Vector2i = Vector2i(1, 0) if horizontal else Vector2i(0, 1)
	var mid: int = length / 2
	var jump: float = _line_diff(image, across * (mid - 1), across * mid, along, count)
	var neighbour: float = 0.0
	for i: int in length - 1:
		neighbour += _line_diff(image, across * i, across * (i + 1), along, count)
	neighbour /= float(length - 1)
	return jump / maxf(neighbour, 1.0)
