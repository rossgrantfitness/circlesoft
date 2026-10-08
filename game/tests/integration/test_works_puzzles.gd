extends TestCase
## The works' puzzles (M4-2): Kasp's card doors (counted, never used up), each card grunt dropping one
## card, the switch cage's card gate, the power lever, the freight lift and its shortcut, the Cable Mill
## crate push, the bell tune and its hatch chest, the old Zero's thermos and the sit-in scene.

var _state: Node = null


func before_each() -> void:
	_state = tree.root.get_node("GameState")
	_state.call("reset")


func after_each() -> void:
	_state.call("reset")


func _stub() -> ExplorationKit.RouterStub:
	return own(ExplorationKit.RouterStub.new()) as ExplorationKit.RouterStub


func _cards(count: int) -> void:
	_state.call("remove_item", WorksKit.CARD, int(_state.call("item_count", WorksKit.CARD)))
	if count > 0:
		_state.call("add_item", WorksKit.CARD, count)


# ---- card doors ----

func test_card_doors_open_by_count_and_say_how_many_you_hold() -> void:
	var cable: FieldRoom = WorksKit.load_room(self, "tower_cable_hall")
	var door1: Door = WorksKit.door(cable, "tc_card_door_1")
	var deck: FieldRoom = WorksKit.load_room(self, "tower_jammer_deck")
	var door3: Door = WorksKit.door(deck, "td_card_door_3")
	for held: int in [0, 1, 2, 3, 4]:
		_cards(held)
		assert_eq(door1.is_unlocked(), held >= 1, "door 1 with %d cards" % held)
		assert_eq(door3.is_unlocked(), held >= 3, "door 3 with %d cards" % held)
	_cards(2)
	assert_eq(door3.locked_message(), "SIGNALS ACCESS ONLY.\nCards: 2 of 3.")
	_cards(0)
	assert_eq(door1.locked_message(), "SIGNALS ACCESS ONLY.\nCards: 0 of 1.")


func test_a_locked_card_door_refuses_and_an_open_one_goes_through_without_using_the_card() -> void:
	var room: FieldRoom = WorksKit.load_room(self, "tower_cable_hall")
	var stub: ExplorationKit.RouterStub = _stub()
	var door1: Door = WorksKit.door(room, "tc_card_door_1")
	door1.router = stub
	_cards(0)
	assert_true(door1.use(room.player, room.interactor), "it says something")
	assert_eq(door1.last_messages, ["SIGNALS ACCESS ONLY.\nCards: 0 of 1."] as Array[String])
	assert_eq(stub.calls.size(), 0, "it stays shut")
	ExplorationKit.finish_conversation(room)
	_cards(1)
	door1.use(room.player, room.interactor)
	ExplorationKit.finish_conversation(room)
	await ExplorationKit.ticks(self, 4)
	assert_eq(stub.calls, [["tower_bell_gallery", "from_below"]])
	assert_eq(WorksKit.cards(_state), 1, "the card is still in the bag: counted, not used up")


func test_each_card_door_wants_its_own_number() -> void:
	assert_eq(int(Placements.door("tc_card_door_1")["requires"]["count"]), 1)
	assert_eq(int(Placements.door("td_card_door_3")["requires"]["count"]), 3)
	assert_eq(int(WorksData.section("gates")["tg_cage_gate"]["need"]), 2, "card door 2 is the switch cage's gate")
	for id: String in ["tc_card_door_1", "td_card_door_3"]:
		assert_false(bool(Placements.door(id)["requires"]["consume"]), id + " does not use the card up")


func test_the_card_grunts_each_drop_one_card_and_stay_beaten() -> void:
	var sump: FieldRoom = WorksKit.load_room(self, "tower_sump")
	assert_eq(WorksKit.cards(_state), 0)
	WorksKit.win_fight(sump, "ts_card_1")
	assert_eq(WorksKit.cards(_state), 1, "one grunt, one card")
	assert_true(bool(_state.call("get_flag", "card_grunt_1_beaten")))
	ExplorationKit.finish_conversation(sump)
	var bell: FieldRoom = WorksKit.load_room(self, "tower_bell_gallery")
	WorksKit.win_fight(bell, "tb_card_pair")
	assert_eq(WorksKit.cards(_state), 2)
	var deck: FieldRoom = WorksKit.load_room(self, "tower_jammer_deck")
	WorksKit.win_fight(deck, "td_squad")
	assert_eq(WorksKit.cards(_state), 3)
	# Back in the Sump the beaten grunt is gone and no second card is waiting.
	var again: FieldRoom = WorksKit.load_room(self, "tower_sump")
	for foe: MapEnemy in again.encounters.enemies():
		assert_ne(foe.placement_id, "ts_card_1", "no respawn once beaten")
	assert_eq(WorksKit.cards(_state), 3)


func test_running_from_a_card_grunt_gives_no_card() -> void:
	var sump: FieldRoom = WorksKit.load_room(self, "tower_sump")
	var grunt: MapEnemy = WorksKit.enemy(sump, "ts_card_1")
	sump.encounters.pending = grunt
	sump.encounters.battle_finished("ran")
	assert_eq(WorksKit.cards(_state), 0)
	assert_false(bool(_state.call("get_flag", "card_grunt_1_beaten")), "he stays put until you beat him")


func test_the_card_grunts_wear_a_lanyard_and_the_sump_one_only_sees_what_is_in_front_of_him() -> void:
	var sump: FieldRoom = WorksKit.load_room(self, "tower_sump")
	var grunt: MapEnemy = WorksKit.enemy(sump, "ts_card_1")
	assert_not_null(grunt.find_child("CardBadge", true, false), "a yellow box on the chest")
	grunt.target = sump.player
	var facing: Vector3 = grunt.get_facing()
	facing.y = 0.0
	facing = facing.normalized()
	assert_lt(facing.z, -0.9, "he faces north, away from the room")
	# Red behind him, close: not noticed. Red in front, inside 2 m: noticed. In front but far: not.
	sump.player.global_position = grunt.global_position - facing * 1.0
	assert_false(grunt._sees_target(1.0, -facing * 1.0), "behind him: nothing")
	sump.player.global_position = grunt.global_position + facing * 1.5
	assert_true(grunt._sees_target(1.5, facing * 1.5), "in front of him, close: he turns")
	sump.player.global_position = grunt.global_position + facing * 4.0
	assert_false(grunt._sees_target(4.0, facing * 4.0), "farther than 2 m: nothing")


func test_the_quota_ambush_is_three_guards_who_do_not_chase_and_go_down_together() -> void:
	var deck: FieldRoom = WorksKit.load_room(self, "tower_jammer_deck")
	var guards: Array[MapEnemy] = [WorksKit.enemy(deck, "td_quota_a"), WorksKit.enemy(deck, "td_quota_b"), WorksKit.enemy(deck, "td_quota_c")]
	for guard: MapEnemy in guards:
		assert_eq(guard.encounter_id, "ambush_no_exit")
		assert_eq(guard.sight_m, 0.0, "they never notice Red")
		guard.target = deck.player
		assert_false(guard._sees_target(1.0, Vector3(1, 0, 0)))
	WorksKit.win_fight(deck, "td_quota_b")
	assert_eq(deck.encounters.enemies().filter(func(e: MapEnemy) -> bool: return e.group_id == "quota_pen").size(), 0, "all three are gone")
	assert_not_null(WorksKit.enemy(deck, "td_squad"), "the squad is a separate fight")


# ---- the switch cage, lever and lift ----

func test_the_cage_gate_wants_two_cards_and_stays_open() -> void:
	var room: FieldRoom = WorksKit.load_room(self, "tower_generator")
	var gate: CardGate = room.get_node("CardGate") as CardGate
	await ExplorationKit.stand(self, room, Vector3(4.3, 0.0, 2.0), Vector3(3.5, 0.0, 2.0))
	_cards(1)
	assert_true(gate.use(room.player, room.interactor))
	assert_eq(gate.last_messages, ["SIGNALS ACCESS ONLY.\nCards: 1 of 2."] as Array[String])
	assert_false(gate.is_open())
	ExplorationKit.finish_conversation(room)
	_cards(2)
	assert_true(gate.use(room.player, room.interactor))
	assert_true(gate.is_open())
	assert_eq(WorksKit.cards(_state), 2, "not used up")
	ExplorationKit.finish_conversation(room)
	var solid: StaticBody3D = gate.get_node("Solid") as StaticBody3D
	assert_eq(solid.collision_layer, 0, "the way in is clear")
	assert_false(gate.use(room.player, room.interactor), "nothing more to do")
	var again: FieldRoom = WorksKit.load_room(self, "tower_generator")
	assert_true((again.get_node("CardGate") as CardGate).is_open(), "open for good")


func test_the_lever_wakes_the_lift_and_the_lights() -> void:
	var room: FieldRoom = WorksKit.load_room(self, "tower_generator")
	var lever: PowerSwitch = room.get_node("PowerLever") as PowerSwitch
	var lift: CageLift = room.get_node("CageLift") as CageLift
	assert_false(lever.is_thrown())
	assert_false(lift.is_powered())
	assert_true(lever.use(room.player, room.interactor))
	assert_true(lever.is_thrown())
	assert_true(bool(_state.call("get_flag", "lift_powered")))
	assert_true(lift.is_powered())
	assert_eq(lever.last_messages.size(), 2)
	ExplorationKit.finish_conversation(room)
	assert_true(lever.use(room.player, room.interactor))
	assert_eq(lever.last_messages, [str(WorksData.section("lever")["already"])] as Array[String], "it only goes down once")
	ExplorationKit.finish_conversation(room)
	var again: FieldRoom = WorksKit.load_room(self, "tower_generator")
	assert_true((again.get_node("PowerLever") as PowerSwitch).is_thrown(), "still thrown when you come back")


func test_the_lift_says_no_power_until_the_lever_is_thrown() -> void:
	var sump: FieldRoom = WorksKit.load_room(self, "tower_sump")
	var lift: CageLift = sump.get_node("CageLift") as CageLift
	assert_true(lift.use(sump.player, sump.interactor))
	assert_true(str(lift.last_messages[0]).contains("NO POWER"))
	assert_null(lift.prompt, "no menu while it is dead")
	assert_false(lift.ride_to("tower_generator"), "and it cannot be ridden")
	var gen: FieldRoom = WorksKit.load_room(self, "tower_generator")
	var deck: FieldRoom = WorksKit.load_room(self, "tower_jammer_deck")
	assert_true((gen.get_node("CageLift") as CageLift).use(gen.player, gen.interactor))
	assert_eq((gen.get_node("CageLift") as CageLift).last_messages, ["No power."] as Array[String])
	assert_false(deck.get_node("CageLift").call("is_powered"))


func test_the_lift_has_three_stops_and_offers_the_other_two() -> void:
	_state.call("set_flag", "lift_powered", true)
	var expected: Dictionary = {"tower_sump": ["tower_generator", "tower_jammer_deck"], "tower_generator": ["tower_sump", "tower_jammer_deck"],
			"tower_jammer_deck": ["tower_sump", "tower_generator"]}
	for room_id: String in expected:
		var room: FieldRoom = WorksKit.load_room(self, room_id)
		var lift: CageLift = room.get_node("CageLift") as CageLift
		var ids: Array[String] = []
		for stop: Dictionary in lift.destinations():
			ids.append(str(stop["id"]))
		assert_eq(ids, expected[room_id], room_id)
	# The meshed cages on the two floors between are scenery only.
	for room_id: String in ["tower_cable_hall", "tower_bell_gallery"]:
		assert_null(WorksKit.load_room(self, room_id).get_node_or_null("CageLift"), room_id + " has no lift door")


func test_the_lift_menu_rides_to_the_chosen_floor_and_the_shortcut_goes_down_to_the_first_save_lamp() -> void:
	_state.call("set_flag", "lift_powered", true)
	var deck: FieldRoom = WorksKit.load_room(self, "tower_jammer_deck")
	var lift: CageLift = deck.get_node("CageLift") as CageLift
	var stub: ExplorationKit.RouterStub = _stub()
	lift.router = stub
	assert_true(lift.use(deck.player, deck.interactor))
	var menu: LiftPrompt = lift.prompt
	assert_not_null(menu)
	assert_true(menu.is_in_group(UiStage.MODAL_GROUP))
	assert_eq(menu.get_list().get_count(), 3, "two floors and Stay here")
	assert_eq(menu.get_list().get_item_id(0), "tower_sump")
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(stub.calls, [["tower_sump", "from_lift"]], "the shortcut down to the Sump, where lamp 1 is")
	for i: int in 4:
		menu.tick()
	assert_false(menu.is_in_group(UiStage.MODAL_GROUP))
	# The Sump arrival spot is next to the lift and the lamp is on the same floor.
	var sump: FieldRoom = WorksKit.load_room(self, "tower_sump", "from_lift")
	assert_not_null(sump.find_spawn("from_lift"))
	assert_true(SaveLamp.is_near_any(tree, sump.find_spawn("from_lift").global_position, 20.0) and SaveLamp.is_near_any(tree, sump.find_spawn("lamp1").global_position, 2.0))


func test_the_lift_menu_can_be_backed_out_of() -> void:
	_state.call("set_flag", "lift_powered", true)
	var room: FieldRoom = WorksKit.load_room(self, "tower_generator")
	var lift: CageLift = room.get_node("CageLift") as CageLift
	var stub: ExplorationKit.RouterStub = _stub()
	lift.router = stub
	lift.use(room.player, room.interactor)
	var menu: LiftPrompt = lift.prompt
	menu.handle_command(MenuInput.Cmd.CANCEL)
	assert_eq(stub.calls.size(), 0)
	for i: int in 4:
		menu.tick()
	var again: LiftPrompt = LiftPrompt.open(tree, lift.destinations(), room.player)
	again.handle_command(MenuInput.Cmd.UP)
	again.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(stub.calls.size(), 0, "Stay here rides nowhere")
	for i: int in 4:
		again.tick()
	assert_false(room.player.frozen)


# ---- the crate push ----

func test_the_crate_pushes_a_metre_at_a_time_and_snaps_against_the_ledge() -> void:
	var room: FieldRoom = WorksKit.load_room(self, "tower_cable_hall")
	var crate: PushCrate = room.get_node("PushCrate") as PushCrate
	assert_almost_eq(crate.position.x, 7.0, 0.001)
	var xs: Array[float] = []
	for i: int in 6:
		if crate.push_once():
			xs.append(snappedf(crate.position.x, 0.01))
	assert_eq(xs, [6.0, 5.0, 4.0, 3.45] as Array[float], "four pushes, the last one short")
	assert_almost_eq(crate.position.z, 3.0, 0.001, "it only moves along its line")
	assert_true(crate.is_placed())
	assert_true(bool(_state.call("get_flag", "t1_crate_placed")))
	assert_false(crate.push_once(), "placed for good")


func test_red_pushes_it_from_the_east_side_through_the_button() -> void:
	var room: FieldRoom = WorksKit.load_room(self, "tower_cable_hall")
	var crate: PushCrate = room.get_node("PushCrate") as PushCrate
	await ExplorationKit.stand(self, room, Vector3(8.2, 0.0, 3.0), Vector3(7.0, 0.0, 3.0))
	assert_eq(room.interactor.get_target(), crate.interactable)
	assert_true(room.interactor.try_interact())
	assert_almost_eq(crate.position.x, 6.0, 0.001)
	ExplorationKit.finish_conversation(room)


func test_the_crate_will_not_budge_from_the_wrong_side() -> void:
	var room: FieldRoom = WorksKit.load_room(self, "tower_cable_hall")
	var crate: PushCrate = room.get_node("PushCrate") as PushCrate
	assert_false(crate.red_can_push_from(Vector3(5.8, 0.0, 3.0)), "west of it")
	assert_false(crate.red_can_push_from(Vector3(8.0, 0.0, 5.0)), "off the line")
	assert_true(crate.red_can_push_from(Vector3(8.0, 0.0, 3.2)))
	room.player.global_position = Vector3(5.8, 0.0, 3.0)
	assert_true(crate.use(room.player, room.interactor))
	assert_almost_eq(crate.position.x, 7.0, 0.001)
	assert_eq(crate.last_messages, [str(WorksData.section("push_crate")["tc_push_crate"]["wrong_side"])] as Array[String])


func test_once_placed_the_crate_is_a_step_up_to_the_ledge() -> void:
	var room: FieldRoom = WorksKit.load_room(self, "tower_cable_hall")
	var crate: PushCrate = room.get_node("PushCrate") as PushCrate
	var climb: TraversalSpot = crate.get_climb_spot()
	assert_false(climb.interactable.enabled, "no climb until it is in place")
	for i: int in 4:
		crate.push_once()
	assert_true(climb.interactable.enabled)
	var ledge_top: float = 1.8
	assert_almost_eq(climb.get_landing_point().y, ledge_top + TraversalSpot.LAND_LIFT, 0.05, "it lands on the ledge")
	assert_lt(climb.get_landing_point().x, 3.0, "west of the ledge's east face")
	assert_lt(climb.get_landing_point().x, 3.0)
	# It stays placed after a reload.
	var again: FieldRoom = WorksKit.load_room(self, "tower_cable_hall")
	var kept: PushCrate = again.get_node("PushCrate") as PushCrate
	assert_true(kept.is_placed())
	assert_almost_eq(kept.position.x, 3.45, 0.001)
	assert_true(kept.get_climb_spot().interactable.enabled)


func test_the_ledge_stash_is_a_chalk_crate_with_the_camp_stove_and_coffee() -> void:
	var stash: Dictionary = Placements.crate("tc_ledge_stash")
	assert_eq(stash["style"], "chalk")
	var ids: Array[String] = []
	for entry: Dictionary in stash["items"]:
		ids.append(str(entry["item"]))
	assert_eq(ids, ["camp_stove", "canned_coffee"] as Array[String])


# ---- the bells ----

func test_the_tune_rule_on_its_own() -> void:
	var tune: Array[String] = ["a", "b", "c"]
	assert_eq(BellRack.step_tune(tune, 0, "a", false), "next")
	assert_eq(BellRack.step_tune(tune, 1, "b", false), "next")
	assert_eq(BellRack.step_tune(tune, 2, "c", false), "solved")
	assert_eq(BellRack.step_tune(tune, 1, "c", false), "wrong")
	assert_eq(BellRack.step_tune(tune, 0, "b", false), "wrong")
	assert_eq(BellRack.step_tune(tune, 0, "x", true), "done")


func test_the_tune_is_five_notes_on_four_bells() -> void:
	var tune: Array = WorksData.section("bells")["tune"]
	assert_eq(tune.size(), 5)
	var sizes: Dictionary = WorksData.section("bells")["sizes"]
	assert_eq(sizes.keys().size(), 4)
	for note: Variant in tune:
		assert_has(sizes, str(note))
	var distinct: Dictionary = {}
	for note: Variant in tune:
		distinct[str(note)] = true
	assert_gt(distinct.size(), 2, "more than one bell is in the tune")


func test_a_wrong_bell_is_a_sour_clang_and_the_tune_starts_over_with_no_penalty() -> void:
	var room: FieldRoom = WorksKit.load_room(self, "tower_bell_gallery")
	var rack: BellRack = room.get_node("BellRack") as BellRack
	var tune: Array[String] = rack.tune()
	assert_eq(rack.ring(tune[0]), "next")
	assert_eq(rack.progress, 1)
	var wrong: String = "tiny" if tune[1] != "tiny" else "big"
	assert_eq(rack.ring(wrong), "wrong")
	assert_eq(rack.progress, 0, "back to the start")
	assert_false(rack.is_solved())
	assert_eq(rack.ring(tune[0]), "next", "and you can just start again")
	assert_eq(int(_state.call("get_credits")), 0)


func test_ringing_the_tune_opens_the_hatch_chest_with_the_bread_knife() -> void:
	var room: FieldRoom = WorksKit.load_room(self, "tower_bell_gallery")
	var rack: BellRack = room.get_node("BellRack") as BellRack
	var chest: Crate = room.get_node("HatchChest") as Crate
	assert_false(chest.visible, "hidden until the tune is rung")
	assert_eq((chest.get_node("Solid") as StaticBody3D).collision_layer, 0, "and not in the way")
	var tune: Array[String] = rack.tune()
	var solved: Array[bool] = [false]
	rack.solved.connect(func() -> void: solved[0] = true)
	for i: int in tune.size():
		var outcome: String = rack.ring(tune[i])
		assert_eq(outcome, "solved" if i == tune.size() - 1 else "next")
	assert_true(solved[0])
	assert_true(bool(_state.call("get_flag", "bells_solved")))
	assert_true(chest.visible)
	assert_eq((chest.get_node("Solid") as StaticBody3D).collision_layer, 1)
	assert_true(chest.use(room.player, room.interactor))
	assert_eq(int(_state.call("item_count", "bread_knife")), 1, "Bread Knife, Extremely Large")
	ExplorationKit.finish_conversation(room)
	assert_eq(rack.ring("big"), "done", "after that the bells just ring")


func test_the_bells_through_red_the_button_and_the_napkin_hint() -> void:
	var room: FieldRoom = WorksKit.load_room(self, "tower_bell_gallery")
	var rack: BellRack = room.get_node("BellRack") as BellRack
	var tune: Array[String] = rack.tune()
	var wrong: String = "tiny" if tune[0] != "tiny" else "big"
	var bell: Bell = room.get_node("BellRack/Bell_" + wrong) as Bell
	assert_eq(bell.bell_id, wrong)
	await ExplorationKit.stand(self, room, Vector3(1.6, 0.0, bell.position.z), bell.global_position)
	assert_true(room.interactor.try_interact())
	assert_eq(bell.last_messages.size(), 2, "the clang, and Mox: there must be a tune")
	assert_true(str(bell.last_messages[1]).begins_with("Mox:"))
	ExplorationKit.finish_conversation(room)
	_state.call("add_item", "bell_tune_napkin", 1)
	room.player.global_position = Vector3(1.6, 0.02, bell.position.z)
	bell.use(room.player, room.interactor)
	assert_eq(bell.last_messages.size(), 1, "with the napkin there is no hint")
	ExplorationKit.finish_conversation(room)


func test_the_four_bells_are_hung_big_to_tiny_along_the_west_wall() -> void:
	var room: FieldRoom = WorksKit.load_room(self, "tower_bell_gallery")
	var zs: Array[float] = []
	for bell_id: String in ["big", "middle", "little", "tiny"]:
		var bell: Bell = room.get_node("BellRack/Bell_" + bell_id) as Bell
		zs.append(bell.position.z)
		assert_almost_eq(bell.position.x, 0.8, 0.01)
		var sizes: Dictionary = WorksData.section("bells")["sizes"]
		assert_gt(float(sizes[bell_id]), 0.3)
	assert_eq(zs, [2.0, 4.0, 6.0, 8.0] as Array[float])


# ---- the old Zero, the sit-in and the crate scene ----

func test_the_old_zeros_thermos_heals_once() -> void:
	var room: FieldRoom = ExplorationKit.load_room_at(self, WorksKit.path("tower_landing"), "from_below")
	_state.call("update_member", "red", {"hp": 3, "juice": 0})
	_state.call("update_member", "otis", {"hp": 5})
	var zero: PlacedNpc = room.get_node("OldZero") as PlacedNpc
	assert_eq(zero.current_variant()["scene"], "works_tl_thermos")
	var driven: Dictionary = await ExplorationKit.drive_scene(self, room, "works_tl_thermos")
	assert_true(driven["ok"])
	for member: Dictionary in _state.call("get_party"):
		assert_eq(int(member["hp"]), int(member["hp_max"]), str(member["id"]))
		assert_eq(int(member["juice"]), int(member["juice_max"]), str(member["id"]))
	assert_true(bool(_state.call("get_flag", "thermos_used")))
	assert_eq(zero.current_variant()["conversation"], "works_tl_zero_luck", "after that she just wishes you luck")
	_state.call("update_member", "red", {"hp": 3})
	assert_ne(int(_state.call("get_member", "red")["hp"]), int(_state.call("get_member", "red")["hp_max"]))


func test_the_sit_in_opens_the_drain_grate_brings_mox_in_and_the_old_zero_hands_over_the_napkin() -> void:
	_state.call("set_story_beat", "b2_road")
	_state.call("set_flag", "otis_joined", true)
	var room: FieldRoom = ExplorationKit.load_room_at(self, WorksKit.path("road_mast_foot"), "from_road")
	var stub: ExplorationKit.RouterStub = _stub()
	var drain: Door = WorksKit.door(room, "fo_to_sump")
	drain.router = stub
	assert_false(drain.is_unlocked(), "the Zeroes are still arguing about whose turn it is")
	drain.use(room.player, room.interactor)
	assert_true(str(drain.last_messages[0]).contains("whose turn"))
	ExplorationKit.finish_conversation(room)
	var driven: Dictionary = await ExplorationKit.drive_scene(self, room, "works_fo_sitin")
	assert_true(driven["ok"])
	assert_true(bool(_state.call("get_flag", "zeroes_back_way")))
	assert_true(bool(_state.call("get_flag", "mox_joined")), "Mox is in")
	assert_true(drain.is_unlocked(), "the grate is open")
	var old_zero: PlacedNpc = room.get_node("OldZero") as PlacedNpc
	assert_eq(old_zero.current_variant()["conversation"], "works_fo_zero_napkin")
	assert_true(room.interactor.start_conversation("works_fo_zero_napkin"))
	ExplorationKit.finish_conversation(room)
	assert_eq(int(_state.call("item_count", "bell_tune_napkin")), 1, "the Bell Tune Napkin")
	assert_eq(old_zero.current_variant()["conversation"], "works_fo_zero_again")


func test_the_mox_crate_scene_in_the_spillway_runs_once_and_sets_the_beat() -> void:
	_state.call("set_story_beat", "b2_otis_joined")
	var room: FieldRoom = ExplorationKit.load_room_at(self, WorksKit.path("road_mast_road"), "from_harrow")
	var scene: Dictionary = Placements.scene("works_rd_crate")
	assert_eq(scene["once"], "mox_crate_scene")
	room.player.global_position = Vector3(5.0, 0.02, 4.0)
	assert_false(room.story.should_start("works_rd_crate"), "not before the trigger line (x=11)")
	room.player.global_position = Vector3(12.0, 0.02, 4.0)
	assert_true(room.story.should_start("works_rd_crate"))
	var driven: Dictionary = await ExplorationKit.drive_scene(self, room, "works_rd_crate")
	assert_true(driven["ok"])
	assert_eq(_state.call("get_story_beat"), "b2_road")
	assert_true(bool(_state.call("get_flag", "mox_crate_scene")))
	assert_false(room.story.should_start("works_rd_crate"), "once")
