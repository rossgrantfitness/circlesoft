extends TestCase
## Milestone 1 step 5: the low-resolution screen, scaled display and sharp UI layer.

const SCREEN_SCENE: String = "res://scenes/core/psx_screen.tscn"
const MAIN_SCENE: String = "res://scenes/core/main.tscn"
const TEST_ROOM: String = "res://scenes/debug/psx_test_room.tscn"
const EXPECTED_RESOLUTIONS: Array[Vector2i] = [Vector2i(384, 216), Vector2i(320, 240), Vector2i(426, 240), Vector2i(480, 270)]
const DEFAULT_RESOLUTION: Vector2i = Vector2i(384, 216)
const FULL_HD: Vector2 = Vector2(1920, 1080)
const BASE_WINDOW: Vector2 = Vector2(1280, 720)
const UHD: Vector2 = Vector2(3840, 2160)
const MIN_FILL: float = 0.8
const BOGUS_RESOLUTION: Vector2i = Vector2i(100, 100)


func _make_screen() -> PsxScreen:
	var screen: PsxScreen = (load(SCREEN_SCENE) as PackedScene).instantiate() as PsxScreen
	add_to_root(screen)
	return screen


func test_default_resolution_is_384_by_216() -> void:
	var screen: PsxScreen = _make_screen()
	assert_eq(screen.get_resolution(), DEFAULT_RESOLUTION)
	assert_eq(screen.get_world_viewport().size, DEFAULT_RESOLUTION)


func test_lists_the_four_approved_resolutions() -> void:
	var screen: PsxScreen = _make_screen()
	assert_eq(screen.get_resolutions(), EXPECTED_RESOLUTIONS)


func test_switches_between_every_resolution_at_runtime() -> void:
	var screen: PsxScreen = _make_screen()
	for size: Vector2i in EXPECTED_RESOLUTIONS:
		assert_true(screen.set_resolution(size), "accepts %s" % size)
		assert_eq(screen.get_resolution(), size)
		assert_eq(screen.get_world_viewport().size, size, "viewport follows")
		assert_almost_eq(screen.get_display().size.x / screen.get_display().size.y,
				float(size.x) / float(size.y), 0.001, "picture keeps its shape at %s" % size)


func test_resolution_change_signal_and_cycle() -> void:
	var screen: PsxScreen = _make_screen()
	var heard: Array[Vector2i] = []
	screen.resolution_changed.connect(func(size: Vector2i) -> void: heard.append(size))
	var next: Vector2i = screen.cycle_resolution()
	assert_eq(next, EXPECTED_RESOLUTIONS[1])
	assert_eq(heard, [EXPECTED_RESOLUTIONS[1]])
	for i: int in EXPECTED_RESOLUTIONS.size() - 1:
		screen.cycle_resolution()
	assert_eq(screen.get_resolution(), EXPECTED_RESOLUTIONS[0], "cycling wraps around")


func test_rejects_a_resolution_not_in_the_list() -> void:
	var screen: PsxScreen = _make_screen()
	assert_false(screen.set_resolution(BOGUS_RESOLUTION))
	assert_eq(screen.get_resolution(), DEFAULT_RESOLUTION, "unchanged")


func test_display_is_nearest_neighbor_with_the_post_shader() -> void:
	var screen: PsxScreen = _make_screen()
	var display: TextureRect = screen.get_display()
	assert_eq(display.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	var material: ShaderMaterial = display.material as ShaderMaterial
	assert_not_null(material)
	assert_eq(material.shader.resource_path, "res://shaders/psx_post.gdshader")
	assert_true(display.texture is ViewportTexture)


func test_ui_layer_is_a_separate_sharp_canvas_layer() -> void:
	var screen: PsxScreen = _make_screen()
	var layer: CanvasLayer = screen.get_ui_layer()
	assert_not_null(layer)
	assert_false(screen.get_world_viewport().is_ancestor_of(layer), "UI is outside the low-res viewport")
	assert_false(layer.get_parent() is SubViewport)
	assert_gt(layer.layer, 0, "UI draws above the picture")


func test_world_is_inside_the_low_res_viewport() -> void:
	var screen: PsxScreen = _make_screen()
	assert_true(screen.get_world_viewport().is_ancestor_of(screen.get_world_root()))
	var room: Node = screen.load_world(load(TEST_ROOM) as PackedScene)
	assert_eq(room.get_parent(), screen.get_world_root())


func test_layout_uses_whole_number_scales_when_it_fits() -> void:
	var at_hd: Rect2 = PsxScreen.compute_display_rect(FULL_HD, DEFAULT_RESOLUTION, true, MIN_FILL)
	assert_eq(at_hd.size, Vector2(1920, 1080), "5x on 1080p fills it exactly")
	assert_eq(at_hd.position, Vector2.ZERO)
	var at_uhd: Rect2 = PsxScreen.compute_display_rect(UHD, DEFAULT_RESOLUTION, true, MIN_FILL)
	assert_eq(at_uhd.size, Vector2(3840, 2160), "10x on 4K")
	var at_base: Rect2 = PsxScreen.compute_display_rect(BASE_WINDOW, DEFAULT_RESOLUTION, true, MIN_FILL)
	assert_eq(at_base.size, Vector2(1152, 648), "3x on 720p, centered with borders")
	assert_eq(at_base.position, Vector2(64, 36))
	var four_by_three: Rect2 = PsxScreen.compute_display_rect(BASE_WINDOW, Vector2i(320, 240), true, MIN_FILL)
	assert_eq(four_by_three.size, Vector2(960, 720), "320x240 at 3x, bars left and right")


func test_layout_falls_back_to_best_fit_when_whole_numbers_waste_too_much() -> void:
	var odd: Rect2 = PsxScreen.compute_display_rect(Vector2(1000, 700), DEFAULT_RESOLUTION, true, MIN_FILL)
	# fit = 2.604, whole = 2 -> 2/2.604 = 0.77 < 0.8, so best fit.
	assert_almost_eq(odd.size.x, 1000.0, 0.01)
	var forced: Rect2 = PsxScreen.compute_display_rect(Vector2(1000, 700), DEFAULT_RESOLUTION, false, MIN_FILL)
	assert_almost_eq(forced.size.x, 1000.0, 0.01, "integer scaling off always fits")
	var tiny: Rect2 = PsxScreen.compute_display_rect(Vector2(300, 200), DEFAULT_RESOLUTION, true, MIN_FILL)
	assert_lt(tiny.size.x, 384.0, "window smaller than the picture: shrink to fit")


func test_display_scale_matches_layout_in_the_scene() -> void:
	var screen: PsxScreen = _make_screen()
	await tree.process_frame
	var scale: float = screen.get_display_scale()
	assert_gt(scale, 0.0)
	assert_true(screen.is_integer_scaling())
	screen.set_integer_scaling(false)
	assert_false(screen.is_integer_scaling())


func test_main_scene_is_the_project_main_scene_and_loads_the_test_room() -> void:
	assert_eq(ProjectSettings.get_setting("application/run/main_scene"), MAIN_SCENE)
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	add_to_root(main)
	var screen: PsxScreen = main.get_node("PsxScreen") as PsxScreen
	assert_not_null(screen)
	assert_not_null(screen.get_world_root().get_node_or_null("PsxTestRoom"), "main loads the test room into the world")
