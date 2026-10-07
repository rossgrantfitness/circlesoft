extends TestCase
## Climb and hop spots: Red stands on the pad, presses the one button and a short scripted move carries
## her over (up a 2-unit ledge, across a fence too tall to jump). Input and enemies are ignored meanwhile.

const CLIMB_SPOT: Vector3 = Vector3(3.5, 0.0, -1.0)
const HOP_WEST: Vector3 = Vector3(-0.4, 0.0, 0.0)
const HOP_EAST: Vector3 = Vector3(1.4, 0.0, 0.0)

var _room: FieldRoom = null
var _state: Node = null


func before_each() -> void:
	_state = tree.root.get_node("GameState")
	_state.call("reset")


func after_each() -> void:
	_state.call("reset")


func _wait_until_done(spot: TraversalSpot, max_ticks: int = 300) -> int:
	var ticks: int = 0
	while spot.is_active() and ticks < max_ticks:
		await tree.physics_frame
		ticks += 1
	return ticks


func test_climbing_carries_red_up_onto_the_ledge() -> void:
	_room = ExplorationKit.load_room(self, ExplorationKit.TEST_A)
	var spot: TraversalSpot = _room.get_node("ClimbSpot") as TraversalSpot
	await ExplorationKit.stand(self, _room, CLIMB_SPOT + Vector3(0.0, 0.0, 0.2), CLIMB_SPOT + Vector3(0.0, 0.0, -2.0))
	assert_eq(_room.prompt.current_icon, "climb")
	assert_eq(_room.interactor.get_target(), spot.interactable)
	var events: Array[String] = []
	spot.started.connect(func() -> void: events.append("started"))
	spot.finished.connect(func() -> void: events.append("finished"))
	assert_true(_room.interactor.try_interact())
	assert_true(_room.player.scripted, "the script has her")
	assert_true(spot.is_active())
	assert_false(spot.interactable.enabled, "no second start in the middle")
	var seconds: float = float(await _wait_until_done(spot)) / 60.0
	assert_almost_eq(seconds, _climb_seconds(), 0.15, "takes about climb_s")
	assert_eq(events, ["started", "finished"] as Array[String])
	assert_false(_room.player.scripted, "control comes back")
	assert_true(spot.interactable.enabled)
	await ExplorationKit.ticks(self, 10)
	assert_almost_eq(_room.player.global_position.y, 2.0, 0.08, "standing on the ledge")
	assert_almost_eq(_room.player.global_position.x, 3.5, 0.1)
	assert_almost_eq(_room.player.global_position.z, -2.5, 0.1)
	assert_true(_room.player.is_on_floor(), "and she stays up there")


func _climb_seconds() -> float:
	return ExplorationTuning.from_db().climb_s


func test_the_ledge_pickup_is_reachable_after_the_climb() -> void:
	_room = ExplorationKit.load_room(self, ExplorationKit.TEST_A)
	var spot: TraversalSpot = _room.get_node("ClimbSpot") as TraversalSpot
	await ExplorationKit.stand(self, _room, CLIMB_SPOT, CLIMB_SPOT + Vector3(0.0, 0.0, -2.0))
	spot.begin(_room.player)
	await _wait_until_done(spot)
	await ExplorationKit.ticks(self, 8)
	var pickup: Pickup = _room.get_node("LedgePickup") as Pickup
	await ExplorationKit.stand(self, _room, Vector3(3.5, 2.0, -1.9), Vector3(3.5, 2.0, -2.6))
	assert_eq(_room.interactor.get_target(), pickup.interactable, "she can take what is up there")
	assert_true(_room.interactor.try_interact())
	assert_eq(int(_state.call("get_credits")), 25)


func test_she_cannot_use_the_stick_or_be_caught_while_climbing() -> void:
	_room = ExplorationKit.load_room(self, ExplorationKit.TEST_A)
	var spot: TraversalSpot = _room.get_node("ClimbSpot") as TraversalSpot
	await ExplorationKit.stand(self, _room, CLIMB_SPOT, CLIMB_SPOT + Vector3(0.0, 0.0, -2.0))
	spot.begin(_room.player)
	_room.player.stick = Vector2(1.0, 0.0)
	assert_eq(_room.player.get_move_direction(), Vector3.ZERO, "the stick is ignored")
	assert_false(_room.player.is_catchable(), "enemies cannot catch her mid-climb")
	assert_false(_room.interactor.can_interact())
	var x_before: float = _room.player.global_position.x
	await ExplorationKit.ticks(self, 10)
	assert_almost_eq(_room.player.global_position.x, x_before, 0.01, "she goes where the climb takes her, not where the stick points")
	_room.player.stick = Vector2.ZERO
	await _wait_until_done(spot)
	assert_true(_room.player.is_catchable())


func test_hopping_carries_red_over_the_fence_both_ways() -> void:
	_room = ExplorationKit.load_room(self, ExplorationKit.TEST_B)
	var west: TraversalSpot = _room.get_node("HopSpotWest") as TraversalSpot
	var east: TraversalSpot = _room.get_node("HopSpotEast") as TraversalSpot
	await ExplorationKit.stand(self, _room, HOP_WEST + Vector3(-0.2, 0.0, 0.0), Vector3(0.5, 0.0, 0.0))
	assert_eq(_room.prompt.current_icon, "hop")
	assert_true(_room.interactor.try_interact())
	var apex: float = 0.0
	var ticks: int = 0
	while west.is_active() and ticks < 200:
		await tree.physics_frame
		apex = maxf(apex, _room.player.global_position.y)
		ticks += 1
	assert_gt(apex, 1.0, "she arcs over the 1.6 fence")
	assert_almost_eq(float(ticks) / 60.0, ExplorationTuning.from_db().hop_s, 0.15)
	await ExplorationKit.ticks(self, 8)
	assert_gt(_room.player.global_position.x, 0.9, "on the far side")
	assert_almost_eq(_room.player.global_position.y, 0.0, 0.08, "on the floor")
	await ExplorationKit.stand(self, _room, HOP_EAST + Vector3(0.2, 0.0, 0.0), Vector3(0.5, 0.0, 0.0))
	assert_true(_room.interactor.try_interact())
	await _wait_until_done(east)
	await ExplorationKit.ticks(self, 8)
	assert_lt(_room.player.global_position.x, 0.0, "and back again")


func test_the_fence_is_too_tall_to_jump_so_the_hop_is_needed() -> void:
	_room = ExplorationKit.load_room(self, ExplorationKit.TEST_B)
	await ExplorationKit.stand(self, _room, Vector3(-1.2, 0.0, 1.5), Vector3(0.5, 0.0, 1.5))
	_room.player.stick = ExplorationKit.stick_toward(_room, Vector3(2.0, 0.0, 1.5))
	for i: int in 120:
		if i % 40 == 5:
			_room.player.request_jump()
		await tree.physics_frame
	_room.player.stick = Vector2.ZERO
	assert_lt(_room.player.global_position.x, 0.4, "still on the west side of a fence she cannot jump")


func test_arc_and_climb_curves_hit_their_marks() -> void:
	_room = ExplorationKit.load_room(self, ExplorationKit.TEST_B)
	var hop: TraversalSpot = _room.get_node("HopSpotWest") as TraversalSpot
	await ExplorationKit.stand(self, _room, HOP_WEST, Vector3(1.0, 0.0, 0.0))
	hop.begin(_room.player)
	var tuning: ExplorationTuning = ExplorationTuning.from_db()
	assert_almost_eq(hop.position_at(0.0).x, HOP_WEST.x, 0.05)
	assert_almost_eq(hop.position_at(0.5).y - hop.position_at(0.0).y, tuning.hop_height, 0.05, "the apex is hop_height")
	assert_almost_eq(hop.position_at(1.0).x, hop.get_landing_point().x, 0.001)
	assert_almost_eq(hop.position_at(1.0).y, hop.get_landing_point().y, 0.001)
	await _wait_until_done(hop)
