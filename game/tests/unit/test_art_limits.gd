extends TestCase
## Texture size cap. Was 256 px (PSX); raised to 512 px with the early-PS2 look (D4, Ross 2026-10-08:
## hero 512 body, enemies/NPCs 256, environment 256-512 tiling; docs/pivot/buildability.md section 6).
## Ross's source sheets that get cut into tiles (file names with "_pack_") are exempt; their tiles are checked.

const ART_ROOT: String = "res://art"
const MAX_TEXTURE_PX: int = 512
const SOURCE_SHEET_TAG: String = "_pack_"
const TEXTURE_EXTENSION: String = "png"


func _collect(dir_path: String, out: Array[String]) -> void:
	for file_name: String in DirAccess.get_files_at(dir_path):
		if file_name.get_extension() == TEXTURE_EXTENSION:
			out.append(dir_path.path_join(file_name))
	for sub_dir: String in DirAccess.get_directories_at(dir_path):
		_collect(dir_path.path_join(sub_dir), out)


func test_no_texture_over_512_px() -> void:
	var files: Array[String] = []
	_collect(ART_ROOT, files)
	assert_gt(files.size(), 0, "there should be some textures to check")
	for path: String in files:
		if path.get_file().contains(SOURCE_SHEET_TAG):
			continue
		var texture: Texture2D = load(path) as Texture2D
		assert_not_null(texture, "could not load " + path)
		if texture != null:
			assert_le(texture.get_width(), MAX_TEXTURE_PX, path + " is too wide")
			assert_le(texture.get_height(), MAX_TEXTURE_PX, path + " is too tall")


func test_test_room_textures_come_in_64_128_and_256() -> void:
	var expected: Dictionary[String, int] = {"checker_64": 64, "checker_128": 128, "checker_256": 256}
	for texture_name: String in expected:
		var texture: Texture2D = load("res://art/placeholder/textures/%s.png" % texture_name) as Texture2D
		assert_not_null(texture, texture_name)
		if texture != null:
			assert_eq(texture.get_size(), Vector2(expected[texture_name], expected[texture_name]), texture_name)
