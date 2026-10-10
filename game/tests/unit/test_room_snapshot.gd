extends TestCase
## VS-16: RoomSnapshot, what a knock-out restart puts back, and which things stay (sticky).


func _run(bag: Dictionary, flags: Dictionary, opened: Array, credits: int) -> Dictionary:
	return {"bag": bag, "flags": flags, "opened": opened, "credits": credits}


func test_it_copies_what_it_was_given() -> void:
	var bag: Dictionary = {"scrap": 2}
	var snap: RoomSnapshot = RoomSnapshot.capture({"hp": 70}, _run(bag, {"a": true}, ["door_1"], 40))
	bag["scrap"] = 99
	assert_eq(snap.bag["scrap"], 2, "a later change to the bag does not reach the snapshot")
	assert_eq(snap.session["hp"], 70)
	assert_eq(snap.credits, 40)
	assert_eq(snap.opened, ["door_1"])


func test_restoring_rewinds_items_credits_flags_and_opened_ids() -> void:
	var snap: RoomSnapshot = RoomSnapshot.capture({}, _run({"scrap": 2}, {"met_otis": true}, ["door_1"], 40))
	var now: Dictionary = _run({"scrap": 5, "key": 1}, {"met_otis": true, "boss_seen": true}, ["door_1", "pickup_9"], 90)
	var back: Dictionary = snap.restored(now, [])
	assert_eq(back["bag"], {"scrap": 2}, "the key picked up since is gone")
	assert_eq(back["flags"], {"met_otis": true}, "a flag set since the entrance is cleared")
	assert_eq(back["opened"], ["door_1"], "the pickup is back on the floor")
	assert_eq(back["credits"], 40)


func test_sticky_flags_and_opened_ids_survive() -> void:
	var snap: RoomSnapshot = RoomSnapshot.capture({}, _run({}, {}, [], 0))
	var now: Dictionary = _run({}, {"fuse_door_open": true, "other": true}, ["door_fuse"], 0)
	var back: Dictionary = snap.restored(now, ["fuse_door_open", "door_fuse", "never_set"])
	assert_true(back["flags"].has("fuse_door_open"), "an opened fuse-box door stays open")
	assert_false(back["flags"].has("other"))
	assert_has(back["opened"], "door_fuse")
	assert_false(back["flags"].has("never_set"), "a sticky id that was never set stays unset")


func test_a_sticky_flag_that_was_set_off_is_not_forced_on() -> void:
	var snap: RoomSnapshot = RoomSnapshot.capture({}, _run({}, {"x": true}, [], 0))
	var back: Dictionary = snap.restored(_run({}, {"x": false}, [], 0), ["x"])
	assert_true(bool(back["flags"]["x"]), "the snapshot's own value stands when the flag is no longer set")


func test_the_credit_cost_comes_off_the_snapshot_and_never_goes_below_zero() -> void:
	var snap: RoomSnapshot = RoomSnapshot.capture({}, _run({}, {}, [], 30))
	assert_eq(snap.restored({}, [], 10)["credits"], 20)
	assert_eq(snap.restored({}, [], 500)["credits"], 0)
	assert_eq(snap.restored({}, [], -5)["credits"], 30, "a negative cost is ignored")


func test_it_round_trips_through_a_dictionary() -> void:
	var snap: RoomSnapshot = RoomSnapshot.capture({"hp": 12, "sword": "machete"}, _run({"a": 1}, {"f": true}, ["o"], 7))
	var back: RoomSnapshot = RoomSnapshot.from_dict(snap.to_dict())
	assert_eq(back.to_dict(), snap.to_dict())
