extends SceneTree
## City texture look test (2026-10-08): the graybox alley in Ross's clean and busted texture packs, at the
## PS2 step 1 settings, nearest vs smooth filtering. Needs a real renderer (not --headless):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##       -s res://tests/visual/capture_city_texture.gd -- --out=/abs/dir
## Writes city_tex_nearest.png, city_tex_smooth.png, city_tex_compare.png, city_tex_busted.png,
## city_tex_mixed.png, city_tex_nearest_nograde.png, city_tex_nearest_64.png and the face-on city_tex_detail_<right|left>_<clean|busted|mixed>.png into --out.
## Names no game classes: the alley is a scene that builds itself from the atlas JSON.
##
## PS2 step 1 settings (docs/pivot/buildability.md section 8): picture rendered at 640x360 and scaled up
## 2x with a smooth (bilinear) filter, per-pixel lighting, one shadow-casting key light, glow, smooth fog,
## full colour with only a faint dither, no vertex jitter or affine warp. The grim grade values are copied
## from the "grim" profile in data/world/look_profiles.json (the "ps2" profile did not exist yet).

const SCENE_PATH: String = "res://scenes/tests/city_texture_test.tscn"
const POST_SHADER: String = "res://shaders/psx_post.gdshader"
const INTERNAL_SIZE: Vector2i = Vector2i(640, 360)
const OUTPUT_SIZE: Vector2i = Vector2i(1280, 720)
const SETTLE_FRAMES: int = 10
const ZOOM_REGION: Rect2i = Rect2i(300, 150, 320, 180)
const ZOOM_FACTOR: int = 4

var _out_dir: String = "/tmp"


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	await process_frame
	RenderingServer.global_shader_parameter_set("psx_color_depth_enabled", 1.0)
	RenderingServer.global_shader_parameter_set("psx_dither_enabled", 1.0)
	var nearest: Image = await _shot("clean", "nearest", true, 128.0)
	var smooth: Image = await _shot("clean", "smooth", true, 128.0)
	var busted: Image = await _shot("busted", "smooth", true, 128.0)
	var mixed: Image = await _shot("mixed", "smooth", true, 128.0)
	var nearest_plain: Image = await _shot("clean", "nearest", false, 128.0)
	var smooth_plain: Image = await _shot("clean", "smooth", false, 128.0)
	var nearest_64: Image = await _shot("clean", "nearest", true, 64.0)
	for preset: String in ["right_wall", "left_wall"]:
		for variant: String in ["clean", "busted", "mixed"]:
			var detail: Image = await _shot(variant, "smooth", true, 128.0, preset)
			_save(detail, "city_tex_detail_%s_%s.png" % [preset.trim_suffix("_wall"), variant])
	_save(nearest, "city_tex_nearest.png")
	_save(smooth, "city_tex_smooth.png")
	_save(busted, "city_tex_busted.png")
	_save(mixed, "city_tex_mixed.png")
	_save(nearest_plain, "city_tex_nearest_nograde.png")
	_save(nearest_64, "city_tex_nearest_64.png")
	print("grade effect on teal and green pixels (nearest): ", _grade_report(nearest_plain, nearest))
	print("grade effect on teal and green pixels (smooth): ", _grade_report(smooth_plain, smooth))
	await _compare(nearest, smooth)
	quit(0)


func _save(image: Image, file_name: String) -> void:
	var path: String = _out_dir.path_join(file_name)
	print("saved ", path, " ", image.get_size(), " error ", image.save_png(path))


## One picture: 640x360 world in a SubViewport, scaled to 1280x720 through the grade shader.
func _shot(variant: String, filter: String, graded: bool, texels_per_m: float, preset: String = "alley") -> Image:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = INTERNAL_SIZE
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var scene: Node3D = (load(SCENE_PATH) as PackedScene).instantiate() as Node3D
	scene.set("variant_mode", variant)
	scene.set("filter_mode", filter)
	scene.set("texels_per_m", texels_per_m)
	scene.set("camera_preset", preset)
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
	if graded:
		material.set_shader_parameter("grade_amount", 1.0)
		material.set_shader_parameter("grade_desat", 0.75)
		material.set_shader_parameter("grade_accent_keep", 0.8)
		material.set_shader_parameter("grade_gain", 1.0)
		material.set_shader_parameter("grade_gamma", 1.1)
		material.set_shader_parameter("grade_crush", 0.03)
		material.set_shader_parameter("grade_shadow_tint", Color(0.55, 0.78, 0.74))
		material.set_shader_parameter("grade_highlight_tint", Color(0.96, 0.84, 0.66))
		material.set_shader_parameter("grade_tint_amount", 0.6)
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


## Side by side with labels, then a 4x zoom of the same region under each.
func _compare(nearest: Image, smooth: Image) -> void:
	var label_h: int = 56
	var width: int = OUTPUT_SIZE.x * 2
	var height: int = label_h + OUTPUT_SIZE.y + label_h + ZOOM_REGION.size.y * ZOOM_FACTOR
	var sheet: SubViewport = SubViewport.new()
	sheet.size = Vector2i(width, height)
	sheet.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color(0.08, 0.08, 0.08)
	backdrop.size = Vector2(width, height)
	sheet.add_child(backdrop)
	var images: Array[Image] = [nearest, smooth]
	var names: Array[String] = ["(a) NEAREST: crisp pixels, no mipmaps", "(b) SMOOTH: linear + mipmaps"]
	for i: int in 2:
		var x0: int = i * OUTPUT_SIZE.x
		_add_label(sheet, names[i] + "   |   full picture, PS2 step 1 (640x360 scaled 2x), grim grade", Vector2(x0 + 12, 12))
		_add_picture(sheet, images[i], Vector2(x0, label_h), 1)
		_add_label(sheet, "same area, zoomed 4x (nearest neighbour zoom)", Vector2(x0 + 12, label_h + OUTPUT_SIZE.y + 12))
		var crop: Image = images[i].get_region(ZOOM_REGION)
		_add_picture(sheet, crop, Vector2(x0, label_h + OUTPUT_SIZE.y + label_h), ZOOM_FACTOR)
	root.add_child(sheet)
	for i: int in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	_save(sheet.get_texture().get_image(), "city_tex_compare.png")
	sheet.queue_free()


func _add_label(parent: Node, text: String, position: Vector2) -> void:
	var label: Label = Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.8))
	parent.add_child(label)


func _add_picture(parent: Node, image: Image, position: Vector2, scale_factor: int) -> void:
	var rect: TextureRect = TextureRect.new()
	rect.texture = ImageTexture.create_from_image(image)
	rect.position = position
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.size = Vector2(image.get_size() * scale_factor)
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(rect)


## How much the grade drains the teal and green pixels: compares the same pixel before and after.
## Teal/green = hue 120 to 195 degrees, saturation over 0.35, value over 0.3 in the ungraded picture.
func _grade_report(plain: Image, graded: Image) -> String:
	var count: int = 0
	var sat_before: float = 0.0
	var sat_after: float = 0.0
	var val_before: float = 0.0
	var val_after: float = 0.0
	var total_sat_before: float = 0.0
	var total_sat_after: float = 0.0
	for y: int in range(0, plain.get_height(), 2):
		for x: int in range(0, plain.get_width(), 2):
			var a: Color = plain.get_pixel(x, y)
			var b: Color = graded.get_pixel(x, y)
			total_sat_before += a.s
			total_sat_after += b.s
			if a.h * 360.0 >= 120.0 and a.h * 360.0 <= 195.0 and a.s > 0.35 and a.v > 0.3:
				count += 1
				sat_before += a.s
				sat_after += b.s
				val_before += a.v
				val_after += b.v
	var pixels: float = float(plain.get_width() / 2 * plain.get_height() / 2)
	if count == 0:
		return "no teal/green pixels found"
	return "%d sampled teal/green px (%.1f%% of picture): saturation %.2f -> %.2f, brightness %.2f -> %.2f; whole picture mean saturation %.2f -> %.2f" % [
		count, 100.0 * count / pixels, sat_before / count, sat_after / count, val_before / count, val_after / count,
		total_sat_before / pixels, total_sat_after / pixels]
