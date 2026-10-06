extends TestCase
## UiStage: the 384x216 sharp layer. Finds or builds itself, lays out like the PSX picture,
## converts window points to stage pixels, forwards mouse input into the stage, and reports busy.

const PSX_SCREEN_SCENE: String = "res://scenes/core/psx_screen.tscn"


func _screen_and_stage() -> Array:
	var screen: PsxScreen = (load(PSX_SCREEN_SCENE) as PackedScene).instantiate() as PsxScreen
	add_to_root(screen)
	screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
	screen.size = Vector2(1280, 720)
	var stage: UiStage = UiStage.get_or_create(tree)
	return [screen, stage]


func test_get_or_create_builds_one_stage_and_reuses_it() -> void:
	var stage: UiStage = UiStage.get_or_create(tree)
	own(stage)
	assert_eq(UiStage.get_or_create(tree), stage)
	assert_eq(tree.get_nodes_in_group(UiStage.GROUP).size(), 1)
	assert_eq(stage.get_stage_size(), Vector2(384, 216))
	assert_eq(stage.get_stage_viewport().size, Vector2i(384, 216))


func test_with_a_psx_screen_it_goes_in_the_ui_layer_and_matches_the_picture() -> void:
	var pair: Array = _screen_and_stage()
	var screen: PsxScreen = pair[0]
	var stage: UiStage = pair[1]
	assert_eq(stage.get_parent(), screen.get_ui_layer())
	await tree.process_frame
	assert_eq(stage.get_display_rect(), screen.get_display_rect(), "same rectangle as the 3D picture")
	screen.size = Vector2(1920, 1080)
	await tree.process_frame
	assert_eq(stage.get_display_rect(), screen.get_display_rect(), "and it follows a resize")


func test_window_points_convert_to_stage_pixels() -> void:
	var pair: Array = _screen_and_stage()
	var stage: UiStage = pair[1]
	await tree.process_frame
	var rect: Rect2 = stage.get_display_rect()
	var scale: float = stage.get_display_scale()
	assert_gt(scale, 0.0)
	assert_almost_eq(stage.to_stage(rect.position).x, 0.0, 0.001)
	assert_almost_eq(stage.to_stage(rect.end).x, 384.0, 0.01)
	assert_almost_eq(stage.to_stage(rect.position + Vector2(192, 108) * scale).y, 108.0, 0.01)


func test_busy_reports_when_a_modal_node_is_in_the_group() -> void:
	assert_false(UiStage.is_busy(tree))
	var node: Node = Node.new()
	add_to_root(node)
	node.add_to_group(UiStage.MODAL_GROUP)
	assert_true(UiStage.is_busy(tree))
	node.remove_from_group(UiStage.MODAL_GROUP)
	assert_false(UiStage.is_busy(tree))


func test_input_reaches_controls_inside_the_stage_with_stage_coordinates() -> void:
	var pair: Array = _screen_and_stage()
	var stage: UiStage = pair[1]
	await tree.process_frame
	var seen: Array[Vector2] = []
	var probe: Control = Control.new()
	var script: GDScript = GDScript.new()
	script.source_code = "extends Control\nsignal got(position: Vector2)\nfunc _input(event: InputEvent) -> void:\n\tif event is InputEventMouseButton:\n\t\tgot.emit(event.position)\n"
	script.reload()
	probe.set_script(script)
	stage.get_stage_root().add_child(probe)
	probe.connect("got", func(position: Vector2) -> void: seen.append(position))
	var scale: float = stage.get_display_scale()
	var window_point: Vector2 = stage.get_display_rect().position + Vector2(100, 50) * scale
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = window_point
	click.global_position = window_point
	stage._input(click)
	assert_eq(seen.size(), 1)
	if seen.size() == 1:
		assert_almost_eq(seen[0].x, 100.0, 0.01)
		assert_almost_eq(seen[0].y, 50.0, 0.01)
