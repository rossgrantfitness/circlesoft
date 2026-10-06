extends TestCase
## The UI font (Nunito, SIL OFL 1.1) ships with its license, is set up for soft low-res rendering
## (grayscale antialiasing, no hinting, whole-pixel glyphs), every theme font entry resolves, and
## the drop shadow is defined in the theme data.

const FONT_DIR: String = "res://art/final/ui/fonts/"
const FONT_FILE: String = "Nunito-VariableFont_wght.ttf"
const LICENSE_FILE: String = "Nunito-OFL.txt"
const LICENSE_PHRASE: String = "SIL Open Font License"
const LICENSE_VERSION: String = "Version 1.1"
const THEME_ID: String = "ui/ui_theme"
const FONT_KEYS: PackedStringArray = ["menu", "body", "dialogue", "tag", "title"]


func test_font_file_and_license_ship_together() -> void:
	assert_true(FileAccess.file_exists(FONT_DIR + FONT_FILE))
	var path: String = FONT_DIR + LICENSE_FILE
	assert_true(FileAccess.file_exists(path))
	var text: String = FileAccess.get_file_as_string(path)
	assert_true(text.contains(LICENSE_PHRASE), "names the SIL Open Font License")
	assert_true(text.contains(LICENSE_VERSION), "version 1.1")
	assert_true(text.contains("Nunito"), "the license is Nunito's own")


func test_font_loads_as_a_variable_font() -> void:
	var font: FontFile = load(FONT_DIR + FONT_FILE) as FontFile
	assert_not_null(font)
	if font == null:
		return
	assert_true(font.get_supported_variation_list().size() > 0, "has a weight axis")


func test_font_is_set_up_for_soft_pixel_rendering() -> void:
	var font: FontFile = load(FONT_DIR + FONT_FILE) as FontFile
	assert_not_null(font)
	if font == null:
		return
	assert_eq(font.antialiasing, TextServer.FONT_ANTIALIASING_GRAY, "grayscale antialiasing: the soft low-res look")
	assert_eq(font.hinting, TextServer.HINTING_NONE)
	assert_eq(font.subpixel_positioning, TextServer.SUBPIXEL_POSITIONING_DISABLED, "glyphs land on whole pixels")
	assert_false(font.multichannel_signed_distance_field)


func test_every_theme_font_resolves_with_a_whole_pixel_size_and_weight() -> void:
	var fonts: Dictionary = DataDB.get_dict(THEME_ID)["fonts"]
	for key: String in FONT_KEYS:
		assert_has(fonts, key)
		var entry: Dictionary = fonts[key]
		assert_true(ResourceLoader.exists(str(entry["path"])), "%s font file exists" % key)
		assert_eq(float(entry["size"]), float(int(entry["size"])), "%s size is whole pixels" % key)
		assert_ge(float(entry["weight"]), 200.0, key)
		assert_le(float(entry["weight"]), 1000.0, key)
		assert_not_null(UiFonts.get_font(key), key)
		assert_eq(UiFonts.get_size(key), int(entry["size"]))


func test_ui_text_sizes_are_small_enough_for_the_stage() -> void:
	for key: String in ["menu", "body", "dialogue"]:
		var size: int = UiFonts.get_size(key)
		assert_ge(size, 10, key)
		assert_le(size, 13, key)
	assert_le(UiFonts.get_size("title"), 40)


func test_the_ui_font_is_wider_for_a_heavier_weight() -> void:
	var light: FontVariation = FontVariation.new()
	light.base_font = load(FONT_DIR + FONT_FILE) as Font
	var tag: int = TextServerManager.get_primary_interface().name_to_tag("wght")
	light.variation_opentype = {tag: 300.0}
	var light_width: float = light.get_string_size("Scrap Sword", HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var heavy_width: float = UiFonts.get_font("menu").get_string_size("Scrap Sword", HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	assert_gt(heavy_width, light_width, "weight 800 is applied (wider than 300)")


func test_drop_shadow_is_one_pixel_down_and_right_in_a_dark_color() -> void:
	var offset: Vector2i = UiText.shadow_offset()
	assert_eq(offset, Vector2i(1, 1))
	assert_lt(UiText.shadow_color().get_luminance(), 0.1, "near-black")
	assert_gt(UiText.shadow_color(true).get_luminance(), 0.5, "the on-light shadow is a soft tone for the chalk bubble")


func test_labels_get_font_size_color_and_shadow() -> void:
	var label: Label = Label.new()
	own(label)
	UiText.style_label(label, "menu", Color.WHITE)
	assert_eq(label.get_theme_font_size("font_size"), UiFonts.get_size("menu"))
	assert_eq(label.get_theme_constant("shadow_offset_x"), 1)
	assert_eq(label.get_theme_constant("shadow_offset_y"), 1)
	assert_eq(label.get_theme_color("font_shadow_color"), UiText.shadow_color())


func test_old_pixel_fonts_are_not_used_by_any_ui_data() -> void:
	var fonts: Dictionary = DataDB.get_dict(THEME_ID)["fonts"]
	for key: String in fonts:
		if fonts[key] is Dictionary:
			var path: String = str(fonts[key]["path"])
			assert_false(path.contains("PressStart2P"), key)
			assert_false(path.contains("Pixelify"), key)
