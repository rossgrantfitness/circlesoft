extends TestCase
## Speech bubble placement math: head point -> stage pixels, clamping to the screen, flipping the
## tail below the head, the tail staying on the body; plus the pixel-rounded-corner helper.

const STAGE: Vector2 = Vector2(384, 216)
const BOUNDS: Rect2 = Rect2(4, 4, 376, 208)
const BODY: Vector2 = Vector2(100, 40)
const TAIL_H: float = 7.0
const GAP: float = 2.0
const FLIP_GAP: float = 10.0
const INSET: float = 12.0


func _place(anchor: Vector2, body: Vector2 = BODY) -> BubblePlacement.Result:
	return BubblePlacement.place(anchor, body, BOUNDS, TAIL_H, GAP, FLIP_GAP, INSET)


func test_centered_above_the_head() -> void:
	var result: BubblePlacement.Result = _place(Vector2(192, 100))
	assert_false(result.flipped)
	assert_eq(result.rect, Rect2(142, 51, 100, 40))
	assert_almost_eq(result.tail_x, 192.0)
	assert_eq(result.tail_tip, Vector2(192, 98), "tip sits tail_gap above the head")
	assert_false(result.clamped_x)


func test_clamped_at_the_left_edge_with_the_tail_still_on_the_speaker() -> void:
	var result: BubblePlacement.Result = _place(Vector2(30, 100))
	assert_almost_eq(result.rect.position.x, 4.0, 0.001, "body pushed to the margin")
	assert_true(result.clamped_x)
	assert_almost_eq(result.tail_x, 30.0, 0.001, "tail still points at the speaker")
	assert_ge(result.tail_x, result.rect.position.x + INSET)


func test_tail_stays_on_the_body_when_the_speaker_is_off_the_edge() -> void:
	var result: BubblePlacement.Result = _place(Vector2(-50, 100))
	assert_almost_eq(result.tail_x, 4.0 + INSET, 0.001)
	var right: BubblePlacement.Result = _place(Vector2(500, 100))
	assert_almost_eq(right.rect.end.x, 380.0, 0.001)
	assert_almost_eq(right.tail_x, 380.0 - INSET, 0.001)


func test_flips_below_when_there_is_no_room_above() -> void:
	var result: BubblePlacement.Result = _place(Vector2(192, 30))
	assert_true(result.flipped)
	assert_almost_eq(result.rect.position.y, 30.0 + FLIP_GAP + TAIL_H, 0.001)
	assert_almost_eq(result.tail_tip.y, 30.0 + FLIP_GAP, 0.001, "the tail now points up at the speaker")
	assert_lt(result.tail_tip.y, result.rect.position.y)


func test_just_enough_room_does_not_flip() -> void:
	# The body top would land exactly on the margin.
	var anchor_y: float = BOUNDS.position.y + BODY.y + TAIL_H + GAP
	assert_false(_place(Vector2(192, anchor_y)).flipped)
	assert_true(_place(Vector2(192, anchor_y - 1.0)).flipped)


func test_flipped_bubble_stays_on_screen_at_the_bottom() -> void:
	var result: BubblePlacement.Result = _place(Vector2(192, 60), Vector2(100, 150))
	assert_true(result.flipped)
	assert_le(result.rect.end.y, BOUNDS.end.y + 0.001)


func test_a_bubble_wider_than_the_screen_pins_to_the_left_margin() -> void:
	var result: BubblePlacement.Result = _place(Vector2(192, 100), Vector2(400, 30))
	assert_almost_eq(result.rect.position.x, 4.0, 0.001)


func test_projection_puts_the_look_at_point_in_the_middle_of_the_stage() -> void:
	for view: Vector2i in [Vector2i(384, 216), Vector2i(768, 432)]:
		var viewport: SubViewport = SubViewport.new()
		viewport.size = view
		add_to_root(viewport)
		var camera: Camera3D = Camera3D.new()
		viewport.add_child(camera)
		camera.look_at_from_position(Vector3(0, 5, 5), Vector3.ZERO)
		var center: Vector2 = BubblePlacement.project_to_stage(camera, Vector3.ZERO, STAGE)
		assert_almost_eq(center.x, 192.0, 0.6, "x at view %s" % view)
		assert_almost_eq(center.y, 108.0, 0.6, "y at view %s" % view)
		var higher: Vector2 = BubblePlacement.project_to_stage(camera, Vector3(0, 1, 0), STAGE)
		assert_lt(higher.y, center.y, "a point above the floor projects higher on screen")
		var right: Vector2 = BubblePlacement.project_to_stage(camera, Vector3(1, 0, 0), STAGE)
		assert_gt(right.x, center.x, "a point to the right projects further right")


func test_points_behind_the_camera_are_detected() -> void:
	var viewport: SubViewport = SubViewport.new()
	add_to_root(viewport)
	var camera: Camera3D = Camera3D.new()
	viewport.add_child(camera)
	camera.look_at_from_position(Vector3(0, 5, 5), Vector3.ZERO)
	assert_false(BubblePlacement.is_behind(camera, Vector3.ZERO))
	assert_true(BubblePlacement.is_behind(camera, Vector3(0, 5, 20)))


func test_corner_insets_make_a_stepped_quarter_circle() -> void:
	var insets: Array[int] = []
	for row: int in 6:
		insets.append(PixelShape.corner_inset(4, row))
	assert_eq(insets, [4, 2, 1, 1, 0, 0])
	assert_eq(PixelShape.corner_inset(0, 0), 0)


func test_row_span_follows_the_rounded_corners() -> void:
	var rect: Rect2i = Rect2i(10, 10, 40, 20)
	assert_eq(PixelShape.row_span(rect, 4, 10), Vector2i(14, 46), "top row is pulled in")
	assert_eq(PixelShape.row_span(rect, 4, 20), Vector2i(10, 50), "middle rows are full width")
	assert_eq(PixelShape.row_span(rect, 4, 29), Vector2i(14, 46), "bottom row mirrors the top")
	assert_eq(PixelShape.row_span(rect, 4, 9), Vector2i.ZERO)
