extends TestCase
## Style guide: textures are 64-256 px on a side (face cells and UI pieces are the exceptions).
## No art file, placeholder or final, may be bigger than 256 px.

const ART_ROOT: String = "res://art"
const MAX_TEXTURE_PX: int = 256
const TEXTURE_EXTENSION: String = "png"


func _collect(dir_path: String, out: Array[String]) -> void:
	for file_name: String in DirAccess.get_files_at(dir_path):
		if file_name.get_extension() == TEXTURE_EXTENSION:
			out.append(dir_path.path_join(file_name))
	for sub_dir: String in DirAccess.get_directories_at(dir_path):
		_collect(dir_path.path_join(sub_dir), out)


func test_no_texture_over_256_px() -> void:
	var files: Array[String] = []
	_collect(ART_ROOT, files)
	assert_gt(files.size(), 0, "there should be some textures to check")
	for path: String in files:
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
