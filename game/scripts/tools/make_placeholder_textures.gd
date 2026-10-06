extends SceneTree
## Makes the placeholder checker textures for the PSX test room (and nothing else).
##   godot --headless --path game -s res://scripts/tools/make_placeholder_textures.gd
## Writes game/art/placeholder/textures/checker_64.png, checker_128.png, checker_256.png and
## wall_128.png. Colors come from the approved master palette in docs/style_guide.md.
## Every texture is a checker of two palette colors, a 1-pixel Ink grid, and a lamp-amber corner
## mark so a flipped or rotated texture is obvious. Run again to regenerate identical files.

const OUTPUT_DIR: String = "res://art/placeholder/textures"

# Master palette (docs/style_guide.md).
const INK: Color = Color("14121F")
const NIGHT: Color = Color("1F2540")
const DUSK: Color = Color("3A3566")
const CHALK: Color = Color("EDEAD8")
const LAMP_AMBER: Color = Color("FFB347")
const BRASS: Color = Color("D9A441")
const SLATE: Color = Color("5B6573")
const SLATE_LIGHT: Color = Color("8D97A5")
const SIGNALS_BLUE: Color = Color("6F8BA8")
const DUST: Color = Color("4A3F46")
const PATCH_METAL: Color = Color("6A5B5B")

## name, size in pixels, cell size in pixels, color A, color B
const TEXTURES: Array[Dictionary] = [
	{"name": "checker_64", "size": 64, "cell": 8, "a": DUSK, "b": NIGHT},
	{"name": "checker_128", "size": 128, "cell": 16, "a": SLATE, "b": SLATE_LIGHT},
	{"name": "checker_256", "size": 256, "cell": 32, "a": DUST, "b": PATCH_METAL},
	{"name": "wall_128", "size": 128, "cell": 32, "a": SIGNALS_BLUE, "b": SLATE},
]
const GRID_LINE_PX: int = 1
const MARK_CELLS: int = 1


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var failed: bool = false
	for spec: Dictionary in TEXTURES:
		var image: Image = _make_checker(spec)
		var path: String = "%s/%s.png" % [OUTPUT_DIR, spec["name"]]
		var err: Error = image.save_png(path)
		if err != OK:
			printerr("could not write %s (error %d)" % [path, err])
			failed = true
		else:
			print("wrote %s (%dx%d)" % [path, image.get_width(), image.get_height()])
	quit(1 if failed else 0)


func _make_checker(spec: Dictionary) -> Image:
	var size: int = spec["size"]
	var cell: int = spec["cell"]
	var color_a: Color = spec["a"]
	var color_b: Color = spec["b"]
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGB8)
	for y: int in size:
		for x: int in size:
			var cx: int = x / cell
			var cy: int = y / cell
			var color: Color = color_a if (cx + cy) % 2 == 0 else color_b
			if x % cell < GRID_LINE_PX or y % cell < GRID_LINE_PX:
				color = INK
			# Top-left cell: amber mark (flip / rotation check). Center cell edge: chalk.
			if cx < MARK_CELLS and cy < MARK_CELLS and x % cell >= GRID_LINE_PX and y % cell >= GRID_LINE_PX:
				color = LAMP_AMBER if (x + y) % 2 == 0 else BRASS
			image.set_pixel(x, y, color)
	# Chalk border so tiling seams are visible when the texture repeats.
	for i: int in size:
		image.set_pixel(i, size - 1, CHALK)
		image.set_pixel(size - 1, i, CHALK)
	return image
