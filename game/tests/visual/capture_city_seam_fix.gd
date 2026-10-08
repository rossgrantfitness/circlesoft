extends SceneTree
## Before/after of the seam-fixed city tiles (Ross asked, 2026-10-08). Needs a real renderer:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##       -s res://tests/visual/capture_city_seam_fix.gd -- --out=/abs/dir
## Writes city_tex_seam_fix.png: 3x3 repeats of typical tiles before and after, then the alley with the
## original tiles and with the seam-fixed copies (nearest filtering, light grade B: desat 0.35, half tint, gamma 1.0).
## Names no game classes.

const SCENE_PATH: String = "res://scenes/tests/city_texture_test.tscn"
const POST_SHADER: String = "res://shaders/psx_post.gdshader"
const CITY: String = "res://art/final/textures/city/"
const INTERNAL_SIZE: Vector2i = Vector2i(640, 360)
const OUTPUT_SIZE: Vector2i = Vector2i(1280, 720)
const SETTLE_FRAMES: int = 10
const SAMPLE_TILES: Array[String] = ["floor_concrete_cracked_dark", "floor_concrete_hazard_stripe_a",
	"floor_concrete_plain_trim_top", "steel_plate_riveted_grey", "rust_vent_louvers_wide", "teal_circuit_traces_green"]
const BLOCK: int = 400
const LABEL_H: int = 44

var _out_dir: String = "/tmp"


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	await process_frame
	RenderingServer.global_shader_parameter_set("psx_color_depth_enabled", 1.0)
	RenderingServer.global_shader_parameter_set("psx_dither_enabled", 1.0)
	var before: Image = await _shot(false)
	var after: Image = await _shot(true)
	await _sheet(before, after)
	quit(0)


func _shot(seamless: bool) -> Image:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = INTERNAL_SIZE
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var scene: Node3D = (load(SCENE_PATH) as PackedScene).instantiate() as Node3D
	scene.set("variant_mode", "clean")
	scene.set("filter_mode", "nearest")
	scene.set("seamless_copies", seamless)
	viewport.add_child(scene)
	root.add_child(viewport)
	var screen: TextureRect = TextureRect.new()
	screen.texture = viewport.get_texture()
	screen.size = Vector2(OUTPUT_SIZE)
	screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	screen.stretch_mode = TextureRect.STRETCH_SCALE
	screen.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load(POST_SHADER) as Shader
	material.set_shader_parameter("color_levels", 256.0)
	material.set_shader_parameter("dither_amount", 0.5)
	material.set_shader_parameter("grade_amount", 1.0)
	material.set_shader_parameter("grade_desat", 0.35)
	material.set_shader_parameter("grade_accent_keep", 0.8)
	material.set_shader_parameter("grade_gain", 1.0)
	material.set_shader_parameter("grade_gamma", 1.0)
	material.set_shader_parameter("grade_crush", 0.03)
	material.set_shader_parameter("grade_shadow_tint", Color(0.55, 0.78, 0.74))
	material.set_shader_parameter("grade_highlight_tint", Color(0.96, 0.84, 0.66))
	material.set_shader_parameter("grade_tint_amount", 0.3)
	material.set_shader_parameter("grade_grain", 0.065)
	material.set_shader_parameter("grade_vignette", 0.4)
	screen.material = material
	root.add_child(screen)
	for i: int in SETTLE_FRAMES:
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	screen.queue_free()
	viewport.queue_free()
	await process_frame
	return image


func _repeat_3x3(path: String) -> Image:
	var tile: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
	tile.convert(Image.FORMAT_RGBA8)
	var out: Image = Image.create(tile.get_width() * 3, tile.get_height() * 3, false, Image.FORMAT_RGBA8)
	for y: int in 3:
		for x: int in 3:
			out.blit_rect(tile, Rect2i(Vector2i.ZERO, tile.get_size()), Vector2i(x * tile.get_width(), y * tile.get_height()))
	return out


func _sheet(before: Image, after: Image) -> void:
	var atlas: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/city_texture_atlas.json"))
	var methods: Dictionary = {}
	for tile: Dictionary in atlas["tiles"]:
		methods[String(tile["id"])] = String(tile.get("seam_method", ""))
	var width: int = OUTPUT_SIZE.x * 2
	var rows_h: int = 3 * 128 + 4
	var height: int = LABEL_H + 2 * (LABEL_H + 3 * 128 + 12) + LABEL_H + OUTPUT_SIZE.y
	var sheet: SubViewport = SubViewport.new()
	sheet.size = Vector2i(width, height)
	sheet.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color(0.08, 0.08, 0.08)
	backdrop.size = Vector2(width, height)
	sheet.add_child(backdrop)
	var y: int = 0
	_label(sheet, "SEAM FIX (copies only, Ross's originals untouched). Each block is one tile repeated 3x3, nearest filtering, 1 texel = 1 pixel.", Vector2(12, y + 6))
	y += LABEL_H
	for pass_index: int in 2:
		_label(sheet, "BEFORE: the original tile" if pass_index == 0 else "AFTER: the seam-fixed copy", Vector2(12, y + 6))
		y += LABEL_H
		for i: int in SAMPLE_TILES.size():
			var id: String = SAMPLE_TILES[i]
			var folder: String = "tiles/" if pass_index == 0 else "tiles_seamless/"
			var block: Image = _repeat_3x3(CITY + folder + id + ".png")
			_picture(sheet, block, Vector2(12 + i * (3 * 128 + 28), y))
			if pass_index == 1:
				_label(sheet, String(methods[id]), Vector2(12 + i * (3 * 128 + 28), y + 3 * 128 + 2), 16)
			else:
				_label(sheet, id, Vector2(12 + i * (3 * 128 + 28), y + 3 * 128 + 2), 16)
		y += 3 * 128 + 12 + 6
	_label(sheet, "THE ALLEY, before (left, original tiles) and after (right, seam-fixed copies): light grade, nearest filtering, PS2 step 1", Vector2(12, y + 6))
	y += LABEL_H
	_picture(sheet, before, Vector2(0, y))
	_picture(sheet, after, Vector2(OUTPUT_SIZE.x, y))
	root.add_child(sheet)
	for i: int in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var path: String = _out_dir.path_join("city_tex_seam_fix.png")
	var image: Image = sheet.get_texture().get_image()
	print("saved ", path, " ", image.get_size(), " error ", image.save_png(path))
	sheet.queue_free()


func _label(parent: Node, text: String, position: Vector2, size: int = 24) -> void:
	var label: Label = Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.8))
	parent.add_child(label)


func _picture(parent: Node, image: Image, position: Vector2) -> void:
	var rect: TextureRect = TextureRect.new()
	rect.texture = ImageTexture.create_from_image(image)
	rect.position = position
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(rect)
