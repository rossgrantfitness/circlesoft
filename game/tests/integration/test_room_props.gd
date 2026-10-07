extends TestCase
## Pickups, crates and doors in the two-room graybox test area (data/world/placements.json): the
## one-button icons, what you get, that it is only once (and stays that way after a save and load),
## a locked door that says what it needs and opens with its key, and walking into a door.

const RATION_SPOT: Vector3 = Vector3(-2.5, 0.0, 2.4)
const KEY_CRATE_SPOT: Vector3 = Vector3(-4.8, 0.0, -2.9)
const VAULT_DOOR_SPOT: Vector3 = Vector3(-1.5, 0.0, -4.0)
const DOOR_TO_B_SPOT: Vector3 = Vector3(8.0, 0.0, -4.0)

var _state: Node = null
var _room: FieldRoom = null


func before_each() -> void:
	_state = tree.root.get_node("GameState")
	_state.call("reset")


func after_each() -> void:
	_state.call("reset")
	for action: StringName in [&"interact", &"jump", &"menu"]:
		Input.action_release(action)


func _load_a() -> FieldRoom:
	_room = ExplorationKit.load_room(self, ExplorationKit.TEST_A)
	return _room


func _in_front(door_spot: Vector3, distance: float = 0.9) -> Vector3:
	return door_spot + Vector3(0.0, 0.0, distance)


# ---- pickups ----

func test_a_pickup_glints_shows_the_hand_and_is_taken_once() -> void:
	_load_a()
	var pickup: Pickup = _room.get_node("RationPickup") as Pickup
	assert_false(pickup.is_taken())
	assert_true(pickup.get_node("Glint").visible, "it glints")
	var before: int = int(_state.call("item_count", "ration_bar"))
	await ExplorationKit.stand(self, _room, RATION_SPOT + Vector3(0.7, 0.0, 0.0), RATION_SPOT)
	assert_eq(_room.interactor.get_target(), pickup.interactable)
	assert_eq(_room.prompt.current_icon, "take", "the hand")
	assert_true(_room.interactor.try_interact())
	assert_eq(int(_state.call("item_count", "ration_bar")), before + 1)
	assert_true(pickup.is_taken())
	assert_false(pickup.get_node("Glint").visible, "gone from the floor")
	assert_eq(pickup.last_messages, ["Got Ration Bar!"] as Array[String])
	assert_true(_room.runner.is_running(), "a box says what she got")
	ExplorationKit.finish_conversation(_room)
	await ExplorationKit.ticks(self, 3)
	assert_null(_room.interactor.get_target(), "nothing left to take")
	assert_false(_room.interactor.try_interact())
	assert_eq(int(_state.call("item_count", "ration_bar")), before + 1, "only once")
	assert_true(bool(_state.call("is_opened", "test_a_ration")), "remembered by id in GameState")


func test_a_taken_pickup_stays_taken_after_leaving_and_after_a_save_and_load() -> void:
	_load_a()
	await ExplorationKit.stand(self, _room, RATION_SPOT + Vector3(0.7, 0.0, 0.0), RATION_SPOT)
	assert_true(_room.interactor.try_interact())
	ExplorationKit.finish_conversation(_room)
	var saved: Dictionary = _state.call("to_dict")
	var count: int = int(_state.call("item_count", "ration_bar"))
	# Leave and come back: a new room instance.
	_room.free()
	_load_a()
	assert_true((_room.get_node("RationPickup") as Pickup).is_taken(), "still gone on re-entry")
	# A fresh game would have it again; the saved game does not.
	_state.call("reset")
	_room.free()
	_load_a()
	assert_false((_room.get_node("RationPickup") as Pickup).is_taken(), "a new game has it back")
	_state.call("from_dict", saved)
	_room.free()
	_load_a()
	assert_true((_room.get_node("RationPickup") as Pickup).is_taken(), "a loaded save keeps it taken")
	assert_eq(int(_state.call("item_count", "ration_bar")), count)


func test_a_credits_pickup_pays_out() -> void:
	_load_a()
	var ledge: Pickup = _room.get_node("LedgePickup") as Pickup
	var before: int = int(_state.call("get_credits"))
	ledge.use(_room.player, _room.interactor)
	assert_eq(int(_state.call("get_credits")), before + 25)
	assert_eq(ledge.last_messages, ["Found 25 credits!"] as Array[String])
	assert_true(ledge.is_taken())


func test_a_full_bag_leaves_the_pickup_where_it_is() -> void:
	_load_a()
	_state.call("add_item", "ration_bar", 99)
	var pickup: Pickup = _room.get_node("RationPickup") as Pickup
	assert_true(pickup.use(_room.player, _room.interactor), "she reads the message")
	assert_false(pickup.is_taken(), "but it stays")
	assert_false(bool(_state.call("is_opened", "test_a_ration")))
	assert_eq(pickup.last_messages, ["You can't carry any more Ration Bar."] as Array[String])


# ---- crates ----

func test_a_crate_opens_once_and_hands_over_what_data_says() -> void:
	_load_a()
	var crate: Crate = _room.get_node("KeyCrate") as Crate
	assert_false(crate.is_open())
	assert_false(bool(_state.call("has_item", ExplorationKit.KEY_ITEM)))
	await ExplorationKit.stand(self, _room, KEY_CRATE_SPOT + Vector3(0.0, 0.0, 1.1), KEY_CRATE_SPOT)
	assert_eq(_room.interactor.get_target(), crate.interactable)
	assert_eq(_room.prompt.current_icon, "open")
	assert_true(_room.interactor.try_interact())
	assert_true(crate.is_open())
	assert_true(bool(_state.call("has_item", ExplorationKit.KEY_ITEM)), "the key is in the bag")
	assert_true(crate.last_messages[0].begins_with("The crate creaks open."))
	var key_name: String = str((_state.call("get_item_info", ExplorationKit.KEY_ITEM) as Dictionary)["name"])
	assert_true(crate.last_messages[0].contains("Got %s!" % key_name))
	ExplorationKit.finish_conversation(_room)
	await ExplorationKit.ticks(self, 3)
	assert_false(_room.interactor.try_interact(), "an opened crate is just a crate")
	assert_eq(int(_state.call("item_count", ExplorationKit.KEY_ITEM)), 1, "no second helping")
	assert_true(bool(_state.call("is_opened", "test_a_key_crate")))


func test_a_crate_can_hold_several_things_and_remembers_it_was_opened() -> void:
	var room_b: FieldRoom = ExplorationKit.load_room(self, ExplorationKit.TEST_B)
	var crate: Crate = room_b.get_node("FenceCrate") as Crate
	var credits: int = int(_state.call("get_credits"))
	crate.use(room_b.player, room_b.interactor)
	assert_eq(int(_state.call("item_count", "juice_box")), 1)
	assert_eq(int(_state.call("get_credits")), credits + 15)
	assert_eq(crate.last_messages.size(), 2, "one box per thing she got")
	var saved: Dictionary = _state.call("to_dict")
	room_b.free()
	_state.call("reset")
	_state.call("from_dict", saved)
	room_b = ExplorationKit.load_room(self, ExplorationKit.TEST_B)
	assert_true((room_b.get_node("FenceCrate") as Crate).is_open(), "open after a save and load")
	assert_almost_eq((room_b.get_node("FenceCrate/LidHinge") as Node3D).rotation.x, deg_to_rad(-70.0), 0.001, "lid ajar")


func test_an_empty_crate_says_so_and_a_full_bag_keeps_the_crate_shut() -> void:
	var room_b: FieldRoom = ExplorationKit.load_room(self, ExplorationKit.TEST_B)
	var empty: Crate = room_b.get_node("EmptyCrate") as Crate
	empty.use(room_b.player, room_b.interactor)
	assert_true(empty.is_open())
	assert_true(empty.last_messages[0].contains("Nothing inside"))
	var fence: Crate = room_b.get_node("FenceCrate") as Crate
	_state.call("add_item", "juice_box", 99)
	_state.call("add_credits", 0)
	var credits: int = int(_state.call("get_credits"))
	ExplorationKit.finish_conversation(room_b)
	fence.use(room_b.player, room_b.interactor)
	# The credits still fit, so this crate opens (a full stack of one item does not block the rest).
	assert_true(fence.is_open())
	assert_eq(int(_state.call("get_credits")), credits + 15)


# ---- doors ----

func test_an_open_door_takes_red_to_its_room_and_spawn_from_data() -> void:
	_load_a()
	var door: Door = _room.get_node("DoorToB") as Door
	var stub: ExplorationKit.RouterStub = add_to_root(ExplorationKit.RouterStub.new()) as ExplorationKit.RouterStub
	door.router = stub
	assert_true(door.is_unlocked())
	await ExplorationKit.stand(self, _room, _in_front(DOOR_TO_B_SPOT), DOOR_TO_B_SPOT)
	assert_eq(_room.interactor.get_target(), door.interactable)
	assert_eq(_room.prompt.current_icon, "open")
	assert_true(_room.interactor.try_interact())
	assert_eq(stub.calls, [["test_b", "from_a"]])


func test_a_locked_door_says_what_it_needs_and_stays_shut_without_the_key() -> void:
	_load_a()
	var door: Door = _room.get_node("VaultDoor") as Door
	var stub: ExplorationKit.RouterStub = add_to_root(ExplorationKit.RouterStub.new()) as ExplorationKit.RouterStub
	door.router = stub
	assert_false(door.is_unlocked())
	await ExplorationKit.stand(self, _room, _in_front(VAULT_DOOR_SPOT), VAULT_DOOR_SPOT)
	assert_true(_room.interactor.try_interact(), "she reads the lock")
	assert_true(stub.calls.is_empty(), "and nothing happens")
	assert_true(door.last_messages[0].begins_with("Signals access only."), "the locked message comes from data")
	assert_true(_room.runner.is_running())
	ExplorationKit.finish_conversation(_room)
	assert_false(bool(_state.call("is_opened", "door_test_a_vault")), "still locked")


func test_the_key_opens_the_locked_door_once_and_it_stays_open() -> void:
	_load_a()
	var door: Door = _room.get_node("VaultDoor") as Door
	var stub: ExplorationKit.RouterStub = add_to_root(ExplorationKit.RouterStub.new()) as ExplorationKit.RouterStub
	door.router = stub
	_state.call("add_item", ExplorationKit.KEY_ITEM, 1)
	assert_true(door.is_unlocked())
	await ExplorationKit.stand(self, _room, _in_front(VAULT_DOOR_SPOT), VAULT_DOOR_SPOT)
	assert_true(_room.interactor.try_interact())
	assert_true(stub.calls.is_empty(), "first the reader's message...")
	assert_true(door.last_messages[0].contains("reader blinks green"))
	ExplorationKit.finish_conversation(_room)
	assert_eq(stub.calls, [["test_b", "vault"]], "...then she goes through")
	assert_true(bool(_state.call("is_opened", "door_test_a_vault")), "remembered as unlocked")
	assert_true(bool(_state.call("has_item", ExplorationKit.KEY_ITEM)), "a card that is not 'consume' stays in the bag")
	# Without the card it is still open, and no message the second time.
	_state.call("remove_item", ExplorationKit.KEY_ITEM, 1)
	stub.calls.clear()
	assert_true(door.is_unlocked())
	door.use(_room.player, _room.interactor)
	assert_eq(stub.calls, [["test_b", "vault"]], "straight through")


func test_a_door_can_need_a_flag_and_can_eat_its_key() -> void:
	_load_a()
	var doors: Dictionary = Placements.section(Placements.SECTION_DOORS)
	doors["flag_test_door"] = {"room": "test_a", "to_room": "test_b", "to_spawn": "vault",
			"requires": {"item": "delivery_crate", "consume": true, "flag": "power_on"}, "locked_message": "Dead panel."}
	var door: Door = Door.new()
	door.placement_id = "flag_test_door"
	_room.add_child(door)
	var stub: ExplorationKit.RouterStub = add_to_root(ExplorationKit.RouterStub.new()) as ExplorationKit.RouterStub
	door.router = stub
	assert_false(door.is_unlocked())
	_state.call("add_item", "delivery_crate", 1)
	assert_false(door.is_unlocked(), "the item alone is not enough")
	_state.call("set_flag", "power_on", true)
	assert_true(door.is_unlocked())
	door.use(_room.player, _room.interactor)
	assert_false(bool(_state.call("has_item", "delivery_crate")), "consumed")
	assert_eq(stub.calls, [["test_b", "vault"]])
	assert_true(door.is_unlocked(), "and open for good")
	doors.erase("flag_test_door")


func test_a_door_does_nothing_while_the_router_is_busy() -> void:
	_load_a()
	var door: Door = _room.get_node("DoorToB") as Door
	var stub: ExplorationKit.RouterStub = add_to_root(ExplorationKit.RouterStub.new()) as ExplorationKit.RouterStub
	stub.busy = true
	door.router = stub
	assert_false(door.use(_room.player, _room.interactor))
	assert_true(stub.calls.is_empty())


func test_walking_into_a_door_goes_through_but_arriving_in_front_of_one_does_not() -> void:
	_load_a()
	var door: Door = _room.get_node("DoorToB") as Door
	var stub: ExplorationKit.RouterStub = add_to_root(ExplorationKit.RouterStub.new()) as ExplorationKit.RouterStub
	door.router = stub
	# She arrives right in the door's zone, pushing at it: nothing yet (not armed).
	await ExplorationKit.stand(self, _room, Vector3(8.0, 0.0, -3.5), Vector3(8.0, 0.0, -4.0))
	_room.player.stick = ExplorationKit.stick_toward(_room, DOOR_TO_B_SPOT)
	await ExplorationKit.ticks(self, 6)
	assert_true(stub.calls.is_empty(), "arriving next to a door never sends her back through it")
	# Step away, then walk into it.
	_room.player.stick = Vector2.ZERO
	assert_true(await ExplorationKit.walk_to(self, _room, Vector3(8.0, 0.0, -2.0)))
	await ExplorationKit.ticks(self, 3)
	_room.player.stick = ExplorationKit.stick_toward(_room, DOOR_TO_B_SPOT)
	var tries: int = 0
	while stub.calls.is_empty() and tries < 120:
		await tree.physics_frame
		tries += 1
	assert_eq(stub.calls, [["test_b", "from_a"]], "walking into the door opens it")
	_room.player.stick = Vector2.ZERO


func test_bumping_a_locked_door_reads_the_message_once_until_she_steps_back() -> void:
	_load_a()
	var door: Door = _room.get_node("VaultDoor") as Door
	var stub: ExplorationKit.RouterStub = add_to_root(ExplorationKit.RouterStub.new()) as ExplorationKit.RouterStub
	door.router = stub
	var bumps: Array = []
	door.bumped_locked.connect(func() -> void: bumps.append(1))
	assert_true(await ExplorationKit.walk_to(self, _room, Vector3(-1.5, 0.0, -2.0)))
	await ExplorationKit.ticks(self, 3)
	_room.player.stick = ExplorationKit.stick_toward(_room, VAULT_DOOR_SPOT)
	await ExplorationKit.ticks(self, 90)
	_room.player.stick = Vector2.ZERO
	assert_eq(bumps.size(), 1, "one message, not one per frame")
	assert_true(stub.calls.is_empty())


func test_every_prop_kind_has_its_own_icon_in_the_prompt() -> void:
	_load_a()
	var spots: Dictionary = {
		"DoorToB": [_in_front(DOOR_TO_B_SPOT), "open"],
		"RationPickup": [RATION_SPOT + Vector3(0.6, 0.0, 0.0), "take"],
		"ClimbSpot": [Vector3(3.5, 0.0, -0.7), "climb"],
	}
	for node_name: String in spots:
		var entry: Array = spots[node_name]
		var target: Node3D = _room.get_node(node_name) as Node3D
		await ExplorationKit.stand(self, _room, entry[0], Vector3(target.global_position.x, 0.0, target.global_position.z))
		assert_eq(_room.prompt.current_icon, entry[1], node_name)
	var room_b: FieldRoom = ExplorationKit.load_room(self, ExplorationKit.TEST_B)
	_room = room_b
	await ExplorationKit.stand(self, _room, Vector3(-0.8, 0.0, 0.0), Vector3(-0.4, 0.0, 0.0))
	assert_eq(_room.prompt.current_icon, "hop")
