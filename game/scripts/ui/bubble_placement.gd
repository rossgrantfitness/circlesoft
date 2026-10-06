class_name BubblePlacement
extends RefCounted
## Where a speech bubble goes. Pure math (no nodes except the camera for projection), in stage
## pixels (384x216): project the speaker's head from the world camera, put the bubble above it,
## keep it inside the screen, and flip it below the head with the tail pointing up when there is
## no room above.

## A finished placement: `rect` is the body (without the tail), `tail_x` the tail's x, `tail_tip`
## the point the tail touches, and `flipped` is true when the bubble sits below the anchor.
class Result extends RefCounted:
	var rect: Rect2 = Rect2()
	var tail_x: float = 0.0
	var tail_tip: Vector2 = Vector2.ZERO
	var flipped: bool = false
	var clamped_x: bool = false


## Head point -> stage pixels. The world renders in a viewport of its own size (384x216 normally,
## other sizes when the debug overlay switches resolution); the stage is always `stage_size`.
static func project_to_stage(camera: Camera3D, world_point: Vector3, stage_size: Vector2) -> Vector2:
	var view_size: Vector2 = camera.get_viewport().get_visible_rect().size
	if view_size.x <= 0.0 or view_size.y <= 0.0:
		return Vector2.ZERO
	return camera.unproject_position(world_point) * stage_size / view_size


## True when the point is behind the camera (so its projection means nothing).
static func is_behind(camera: Camera3D, world_point: Vector3) -> bool:
	return camera.is_position_behind(world_point)


## Computes the placement. `body_size` is the bubble without its tail; `bounds` is the safe area
## (the stage inset by the screen margin). `tail_gap` leaves a little air between the tail tip and
## the head; `flip_gap` is how far below the anchor the tip lands when flipped.
static func place(anchor: Vector2, body_size: Vector2, bounds: Rect2, tail_height: float, tail_gap: float, flip_gap: float, tail_inset: float) -> Result:
	var result: Result = Result.new()
	var width: float = body_size.x
	var height: float = body_size.y
	var min_x: float = bounds.position.x
	var max_x: float = bounds.end.x - width
	var ideal_x: float = anchor.x - width / 2.0
	var x: float = min_x if max_x < min_x else clampf(ideal_x, min_x, max_x)
	result.clamped_x = not is_equal_approx(x, ideal_x)

	var top_above: float = anchor.y - tail_gap - tail_height - height
	result.flipped = top_above < bounds.position.y
	var y: float
	if result.flipped:
		y = anchor.y + flip_gap + tail_height
		var max_y: float = bounds.end.y - height
		y = minf(y, maxf(max_y, bounds.position.y))
	else:
		y = top_above
	result.rect = Rect2(x, y, width, height)

	var inset: float = minf(tail_inset, width / 2.0)
	result.tail_x = clampf(anchor.x, x + inset, x + width - inset)
	# The tail always hangs off the body edge, so it follows the body if it had to move to stay on screen.
	var tip_y: float = result.rect.position.y - tail_height if result.flipped else result.rect.end.y + tail_height
	result.tail_tip = Vector2(result.tail_x, tip_y)
	return result
