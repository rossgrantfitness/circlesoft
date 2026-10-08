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
				_record(tile, suffix, false, "already_seamless", Vector2i.ZERO)
				_remove(out_path)
				_count(counts, variant_name, "already_seamless")
				continue
			if rejected.has(variant_name):
				_record(tile, suffix, false, "rejected", Vector2i.ZERO)
				_remove(out_path)
				_count(counts, variant_name, "rejected")
				continue
			var original: Image = Image.load_from_file(ProjectSettings.globalize_path(source_dir + id + ".png"))
			original.convert(Image.FORMAT_RGBA8)
			var result: Dictionary = _fix(original, not bool(seam["x_ok"]), not bool(seam["y_ok"]))
			if not bool(result["ok"]):
				print("measure failed: ", variant_name, " ", id, " x ", result["x"], " y ", result["y"], " ", result["method"])
				_record(tile, suffix, false, "failed_measure", Vector2i.ZERO)
				_remove(out_path)
				_count(counts, variant_name, "failed_measure")
				continue
			var image: Image = result["image"]
			image.save_png(out_path)
			made += 1
			_record(tile, suffix, true, String(result["method"]), image.get_size())
			_count(counts, variant_name, String(result["method"]))
	CityAtlasIo.write_atlas(atlas)
	print("made %d seamless copies; by variant and method: %s" % [made, counts])
	quit(0)


func _record(tile: Dictionary, suffix: String, copy: bool, method: String, size: Vector2i) -> void:
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
	var ax: Dictionary = _axis(image, true)
	var ay: Dictionary = _axis(image, false)
	var ok: bool = bool(ax["ok"]) and bool(ay["ok"])
	var name: String = "+".join(methods)
	# tidy names: both axes by the same method read as one name
	if methods.size() == 2 and methods[0].trim_suffix("_x") == methods[1].trim_suffix("_y"):
		name = methods[0].trim_suffix("_x")
	return {"image": image, "ok": ok, "method": name, "x": ax, "y": ay}


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


## Rolls the tile so its new edge falls on the quietest column (or row) pair between a quarter and three
## quarters of the way across, then patches the old seam, now inside the tile, from the untouched original.
func _offset_dither(image: Image, along_x: bool, along_y: bool) -> Image:
	var cut_x: int = _quietest_cut(image, true) if along_x else 0
	var cut_y: int = _quietest_cut(image, false) if along_y else 0
	var best: Image = null
	var best_score: float = INF
	for band: int in BAND_WIDTHS:
		var candidate: Image = _offset_dither_band(image, along_x, along_y, band, cut_x, cut_y)
		var score: float = 0.0
		if along_x:
			score = maxf(score, _centre_ratio(candidate, true, image.get_width() - cut_x))
		if along_y:
			score = maxf(score, _centre_ratio(candidate, false, image.get_height() - cut_y))
		if score < best_score - 0.05:
			best_score = score
			best = candidate
	return best


## The column (or row) index k in the middle half of the tile where pixel line k-1 and line k differ least.
func _quietest_cut(image: Image, horizontal: bool) -> int:
	var length: int = image.get_width() if horizontal else image.get_height()
	var count: int = image.get_height() if horizontal else image.get_width()
	var along: Vector2i = Vector2i(0, 1) if horizontal else Vector2i(1, 0)
	var across: Vector2i = Vector2i(1, 0) if horizontal else Vector2i(0, 1)
	var best_k: int = length / 2
	var best_diff: float = INF
	for k: int in range(length / 4, length * 3 / 4 + 1):
		var diff: float = _line_diff(image, across * (k - 1), across * k, along, count)
		if diff < best_diff:
			best_diff = diff
			best_k = k
	return best_k


func _offset_dither_band(image: Image, along_x: bool, along_y: bool, band: int, cut_x: int, cut_y: int) -> Image:
	var w: int = image.get_width()
	var h: int = image.get_height()
	var half: float = float(band) * 0.5
	var seam_x: float = float(w - cut_x)
	var seam_y: float = float(h - cut_y)
	var out: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y: int in h:
		for x: int in w:
			var rolled: Color = image.get_pixel((x + cut_x) % w if along_x else x, (y + cut_y) % h if along_y else y)
			# chance of taking the untouched original pixel: 1 on the old seam line, 0 at the band edge
			var chance: float = 0.0
			if along_x:
				chance = maxf(chance, 1.0 - absf(float(x) + 0.5 - seam_x) / half)
			if along_y:
				chance = maxf(chance, 1.0 - absf(float(y) + 0.5 - seam_y) / half)
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


## How hard the line at the old seam position of the tile still jumps compared with ordinary neighbour columns.
func _centre_ratio(image: Image, horizontal: bool, seam: int) -> float:
	var w: int = image.get_width()
	var h: int = image.get_height()
	var length: int = w if horizontal else h
	var count: int = h if horizontal else w
	var along: Vector2i = Vector2i(0, 1) if horizontal else Vector2i(1, 0)
	var across: Vector2i = Vector2i(1, 0) if horizontal else Vector2i(0, 1)
	var mid: int = clampi(seam, 1, length - 1)
	var jump: float = _line_diff(image, across * (mid - 1), across * mid, along, count)
	var neighbour: float = 0.0
	for i: int in length - 1:
		neighbour += _line_diff(image, across * i, across * (i + 1), along, count)
	neighbour /= float(length - 1)
	return jump / maxf(neighbour, 1.0)
