extends TestCase
## The two approved candidate fonts ship with their SIL Open Font License text and are set up for
## crisp pixel rendering (no antialiasing, no hinting blur, no subpixel positioning).

const FONT_DIR: String = "res://art/final/ui/fonts/"
const FONTS: Dictionary[String, String] = {
	"PressStart2P-Regular.ttf": "PressStart2P-OFL.txt",
	"PixelifySans-VariableFont_wght.ttf": "PixelifySans-OFL.txt",
}
const LICENSE_PHRASE: String = "SIL Open Font License"
const LICENSE_VERSION: String = "Version 1.1"
const THEME_ID: String = "ui/ui_theme"


func test_font_files_exist() -> void:
	for font_file: String in FONTS:
		assert_true(FileAccess.file_exists(FONT_DIR + font_file), font_file)


func test_license_files_say_sil_open_font_license_1_1() -> void:
	for font_file: String in FONTS:
		var path: String = FONT_DIR + FONTS[font_file]
		assert_true(FileAccess.file_exists(path), "license present: %s" % path)
		var text: String = FileAccess.get_file_as_string(path)
		assert_true(text.contains(LICENSE_PHRASE), "%s names the SIL Open Font License" % path)
		assert_true(text.contains(LICENSE_VERSION), "%s is version 1.1" % path)


func test_fonts_load_as_fonts() -> void:
	for font_file: String in FONTS:
		var font: Font = load(FONT_DIR + font_file) as Font
		assert_not_null(font, "%s loads" % font_file)


func test_fonts_are_set_up_for_crisp_pixels() -> void:
	for font_file: String in FONTS:
		var font: FontFile = load(FONT_DIR + font_file) as FontFile
		assert_not_null(font)
		if font == null:
			continue
		assert_eq(font.antialiasing, TextServer.FONT_ANTIALIASING_NONE, "%s: no antialiasing" % font_file)
		assert_eq(font.hinting, TextServer.HINTING_NONE, "%s: no hinting blur" % font_file)
		assert_eq(font.subpixel_positioning, TextServer.SUBPIXEL_POSITIONING_DISABLED, "%s: whole-pixel glyphs" % font_file)
		assert_false(font.multichannel_signed_distance_field, "%s: no smooth SDF" % font_file)


func test_theme_fonts_point_at_real_files_and_sizes_are_whole_pixels() -> void:
	var fonts: Dictionary = DataDB.get_dict(THEME_ID)["fonts"]
	for key: String in fonts:
		var entry: Dictionary = fonts[key]
		assert_true(ResourceLoader.exists(str(entry["path"])), "%s font exists" % key)
		assert_gt(float(entry["size"]), 0.0)
	# Press Start 2P is drawn on an 8x8 grid, so it is only crisp at multiples of 8.
	for key: String in ["menu", "title"]:
		var entry: Dictionary = fonts[key]
		if str(entry["path"]).contains("PressStart2P"):
			assert_eq(int(entry["size"]) % 8, 0, "%s size is a multiple of 8" % key)


func test_press_start_advances_on_a_whole_pixel_grid() -> void:
	var font: Font = load(FONT_DIR + "PressStart2P-Regular.ttf") as Font
	assert_not_null(font)
	var glyph_size: Vector2 = font.get_string_size("LIGHTS", HORIZONTAL_ALIGNMENT_LEFT, -1, 8)
	assert_eq(glyph_size.x, 48.0, "6 letters x 8px: an exact pixel grid")
