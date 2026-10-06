extends TestCase
## NPCs and interactables in the test room: Red picks the nearest thing in front of her, the prompt
## icon matches what it is, a flag swaps in the "again" conversation, gifts are given once, NPCs turn
## to face Red and back, and the field menu and bubbles lock out jumping and leaving the room.

const ROOM_PATH: String = "res://scenes/debug/psx_test_room.tscn"
const TICK: float = 1.0 / 60.0
const OTIS_SPOT: Vector3 = Vector3(4.4, 0.0, 0.8)
const MOX_SPOT: Vector3 = Vector3(5.8, 0.0, 1.4)
const ZERO_SPOT: Vector3 = Vector3(-2.4, 0.0, 2.0)

var _room: FieldRoom = null
var _tuning: InteractionTuning = null
var _state: Node = null


func before_each() -> void:
	_state = tree.root.get_node("GameState")
	_state.call("reset")
	_tuning = InteractionTuning.from_db(tree.root.get_node("DataDB"))


func after_each() -> void:
	_state.call("reset")
	for action: StringName in [&"jump", &"menu", &"interact", &"start"]:
		Input.action_release(action)


func _load_room() -> FieldRoom:
	_room = (load(ROOM_PATH) as PackedScene).instantiate() as FieldRoom
	add_to_root(_room)
	_room.player.read_engine_input = false
	_room.camera_rig.auto_update = true
	_room.interactor.read_engine_input = false
	_room.runner.manual_ticks = true
	_room.runner.chars_per_second_override = 100000.0
	return _room


## Puts Red on the floor at `spot`, facing `look_at`, and lets the physics settle.
func _stand(spot: Vector3, look_at: Vector3) -> void:
	var player: PlayerController = _room.player
	player.global_position = spot + Vector3(0.0, 0.02, 0.0)
	player.velocity = Vector3.ZERO
	var direction: Vector3 = look_at - spot
	direction.y = 0.0
	player.rotation.y = PlayerMotion.yaw_for_direction(direction.normalized())
	await _ticks(4)
	_room.interactor.refresh()


func _ticks(count: int) -> void:
	for i: int in count:
		await tree.physics_frame


func _finish_conversation() -> void:
	var guard: int = 0
	while _room.runner.is_running() and guard < 400:
		_room.runner.confirm()
		_room.runner.tick(0.5)
		guard += 1
	# Choices need a pick: take the first.
	assert_false(_room.runner.is_running(), "conversation finished")


func _make_spot(at: Vector3, conversation: String, kind: Interactable.Kind = Interactable.Kind.TALK) -> Interactable:
	var spot: Interactable = Interactable.new()
	spot.kind = kind
	spot.conversation = conversation
	spot.position = at
	add_to_root(spot)
	return spot


# ---- picking ----

func test_picks_the_nearest_interactable_in_front() -> void:
	var near: Interactable = _make_spot(Vector3(1.0, 0.0, 0.0), "near")
	var far: Interactable = _make_spot(Vector3(1.4, 0.0, 0.0), "far")
	var behind: Interactable = _make_spot(Vector3(-1.0, 0.0, 0.0), "behind")
	var list: Array[Interactable] = [far, behind, near]
	assert_eq(Interactable.pick(list, Vector3.ZERO, Vector3.RIGHT, _tuning), near)
	assert_eq(Interactable.pick(list, Vector3.ZERO, Vector3.LEFT, _tuning), behind, "facing the other way picks the one behind her")
	assert_eq(Interactable.pick(list, Vector3.ZERO, Vector3.BACK, _tuning), null, "nothing in front, nothing picked")


func test_out_of_reach_or_wrong_height_is_not_picked() -> void:
	var too_far: Interactable = _make_spot(Vector3(_tuning.reach + 0.3, 0.0, 0.0), "far")
	var too_high: Interactable = _make_spot(Vector3(1.0, _tuning.max_height_diff + 0.3, 0.0), "high")
	assert_eq(Interactable.pick([too_far, too_high] as Array[Interactable], Vector3.ZERO, Vector3.RIGHT, _tuning), null)
	var long_reach: Interactable = _make_spot(Vector3(_tuning.reach + 0.3, 0.0, 0.0), "far")
	long_reach.reach = _tuning.reach + 0.5
	assert_eq(Interactable.pick([long_reach] as Array[Interactable], Vector3.ZERO, Vector3.RIGHT, _tuning), long_reach, "per-thing reach")


func test_something_right_beside_her_counts_even_behind() -> void:
	var close: Interactable = _make_spot(Vector3(-_tuning.always_in_reach_distance * 0.5, 0.0, 0.0), "close")
	assert_eq(Interactable.pick([close] as Array[Interactable], Vector3.ZERO, Vector3.RIGHT, _tuning), close)


func test_disabled_or_empty_interactables_are_ignored() -> void:
	var off: Interactable = _make_spot(Vector3(1.0, 0.0, 0.0), "x")
	off.enabled = false
	var empty: Interactable = _make_spot(Vector3(1.0, 0.0, 0.0), "")
	assert_eq(Interactable.pick([off, empty] as Array[Interactable], Vector3.ZERO, Vector3.RIGHT, _tuning), null)


func test_in_the_room_red_picks_otis_when_facing_him() -> void:
	_load_room()
	await _stand(OTIS_SPOT + Vector3(-1.0, 0.0, 0.0), OTIS_SPOT)
	assert_eq(_room.interactor.get_target(), _room.get_node("Otis/Interactable"))
	await _stand(MOX_SPOT + Vector3(1.0, 0.0, 0.0), MOX_SPOT)
	assert_eq(_room.interactor.get_target(), _room.get_node("Mox/Interactable"))


func test_between_otis_and_mox_red_picks_the_one_she_faces() -> void:
	_load_room()
	var between: Vector3 = (OTIS_SPOT + MOX_SPOT) * 0.5
	await _stand(between + Vector3(0.0, 0.0, 0.8), OTIS_SPOT)
	assert_eq(_room.interactor.get_target(), _room.get_node("Otis/Interactable"))
	await _stand(between + Vector3(0.0, 0.0, 0.8), MOX_SPOT)
	assert_eq(_room.interactor.get_target(), _room.get_node("Mox/Interactable"))


func test_nothing_to_pick_in_the_open() -> void:
	_load_room()
	await _stand(Vector3(8.0, 0.0, 2.5), Vector3(9.0, 0.0, 2.5))
	assert_null(_room.interactor.get_target())
	assert_false(_room.prompt.is_showing())


# ---- prompt icons ----

func test_prompt_icon_matches_the_kind_of_thing() -> void:
	_load_room()
	await _stand(OTIS_SPOT + Vector3(-1.0, 0.0, 0.0), OTIS_SPOT)
	assert_eq(_room.prompt.current_icon, "talk", "people get the speech bubble")
	await _stand(Vector3(2.2, 0.0, 2.0), Vector3(2.2, 0.0, 0.9))
	assert_eq(_room.interactor.get_target(), _room.get_node("PillarSpot"))
	assert_eq(_room.prompt.current_icon, "examine", "things get the ?")
	assert_true(_room.prompt.is_showing())


func test_prize_crate_shows_the_hand_until_it_is_taken() -> void:
	_load_room()
	var prize: Interactable = _room.get_node("PrizeSpot") as Interactable
	assert_eq(prize.current_kind_name(), "take")
	_state.call("set_flag", "prize_crate_taken", true)
	assert_eq(prize.current_kind_name(), "examine", "an empty crate is just something to look at")


func test_icons_exist_and_are_never_an_exclamation_mark() -> void:
	var icons: Dictionary = tree.root.get_node("DataDB").call("get_dict", "ui/interact_icons")
	assert_has(icons["icons"], "talk")
	assert_has(icons["icons"], "examine")
	assert_has(icons["icons"], "take")
	assert_eq((icons["icons"] as Dictionary).size(), 3, "no '!': that is the battle cue")
	for kind: String in Interactable.KIND_NAMES.values():
		assert_has(icons["icons"], kind)


func test_prompt_floats_over_red_on_screen() -> void:
	_load_room()
	await _stand(OTIS_SPOT + Vector3(-1.0, 0.0, 0.0), OTIS_SPOT)
	_room.prompt.tick(0.5)
	var anchor: Vector2 = _room.prompt.get_anchor_point()
	assert_gt(anchor.x, 0.0)
	assert_lt(anchor.x, 384.0)
	assert_gt(anchor.y, 0.0)
	assert_lt(anchor.y, 216.0)
	var feet: Vector2 = BubblePlacement.project_to_stage(_room.camera_rig.get_camera(), _room.player.global_position, Vector2(384, 216))
	assert_lt(anchor.y, feet.y, "above her feet")


func test_prompt_hides_while_a_conversation_runs() -> void:
	_load_room()
	await _stand(OTIS_SPOT + Vector3(-1.0, 0.0, 0.0), OTIS_SPOT)
	assert_true(_room.interactor.try_interact())
	_room.interactor.refresh()
	assert_false(_room.prompt.is_showing(), "no icon while a bubble is up")
	assert_true(_room.player.frozen)


# ---- conversations, flags, items ----

func test_interact_starts_the_conversation_and_freezes_red() -> void:
	_load_room()
	await _stand(OTIS_SPOT + Vector3(-1.0, 0.0, 0.0), OTIS_SPOT)
	assert_true(_room.interactor.try_interact())
	assert_true(_room.runner.is_running())
	assert_eq(_room.runner.get_current_conversation(), "otis_talk")
	assert_false(_room.interactor.try_interact(), "can't start a second one on top")


func test_otis_repeats_as_the_again_conversation() -> void:
	_load_room()
	var otis: Interactable = _room.get_node("Otis/Interactable") as Interactable
	assert_eq(otis.current_conversation(), "otis_talk")
	assert_false(bool(_state.call("get_flag", "otis_met")))
	await _stand(OTIS_SPOT + Vector3(-1.0, 0.0, 0.0), OTIS_SPOT)
	_room.interactor.try_interact()
	assert_true(bool(_state.call("get_flag", "otis_met")), "talking sets otis_met")
	assert_eq(otis.current_conversation(), "otis_talk_again")


func test_flag_swap_on_a_plain_interactable() -> void:
	var spot: Interactable = _make_spot(Vector3.ZERO, "first")
	spot.after_flag = "seen_it"
	spot.after_conversation = "second"
	spot.game_state = _state
	assert_eq(spot.current_conversation(), "first")
	_state.call("set_flag", "seen_it", true)
	assert_eq(spot.current_conversation(), "second")
	spot.after_conversation = ""
	assert_eq(spot.current_conversation(), "first", "no 'after' conversation: it keeps playing the first")


func test_zero_gives_the_coffee_once() -> void:
	_load_room()
	var zero: Interactable = _room.get_node("OldZero/Interactable") as Interactable
	await _stand(ZERO_SPOT + Vector3(-0.2, 0.0, 1.0), ZERO_SPOT)
	var before: int = int(_state.call("item_count", "canned_coffee"))
	assert_eq(_room.interactor.get_target(), zero)
	_room.interactor.try_interact()
	assert_eq(_room.runner.get_current_conversation(), "zero_talk")
	_finish_conversation()
	assert_eq(int(_state.call("item_count", "canned_coffee")), before + 1, "got the coffee")
	assert_true(bool(_state.call("get_flag", "zero_gift")))
	assert_eq(zero.current_conversation(), "zero_talk_again")
	for i: int in 5:
		_room.runner.tick(0.5)
	await _ticks(4)
	_room.interactor.refresh()
	_room.interactor.try_interact()
	assert_eq(_room.runner.get_current_conversation(), "zero_talk_again")
	_finish_conversation()
	assert_eq(int(_state.call("item_count", "canned_coffee")), before + 1, "no second coffee")


func test_prize_crate_is_taken_once_from_the_platform() -> void:
	_load_room()
	var prize: Interactable = _room.get_node("PrizeSpot") as Interactable
	# From the ground beside the platform it is out of reach (a jump up is the point).
	await _stand(Vector3(9.4, 0.0, -1.0), Vector3(10.8, 0.0, -1.0))
	assert_ne(_room.interactor.get_target(), prize, "not from the ground")
	# On top of the platform she can take it.
	await _stand(Vector3(10.0, 0.9, -1.0), Vector3(10.8, 0.9, -1.0))
	assert_eq(_room.interactor.get_target(), prize)
	assert_eq(_room.prompt.current_icon, "take")
	var before: int = int(_state.call("item_count", "ration_bar"))
	_room.interactor.try_interact()
	_finish_conversation()
	assert_eq(int(_state.call("item_count", "ration_bar")), before + 1)
	assert_true(bool(_state.call("get_flag", "prize_crate_taken")))
	for i: int in 5:
		_room.runner.tick(0.5)
	await _ticks(4)
	_room.interactor.refresh()
	assert_eq(_room.prompt.current_icon, "examine", "the icon changes once it is taken")
	_room.interactor.try_interact()
	assert_eq(_room.runner.get_current_conversation(), "examine_prize_crate_again")
	_finish_conversation()
	assert_eq(int(_state.call("item_count", "ration_bar")), before + 1, "only one ration bar")


func test_every_room_conversation_exists_in_the_data() -> void:
	_load_room()
	var runner: DialogueRunner = _room.runner
	for node: Node in _room.find_children("*", "Node3D", true, false):
		var spot: Interactable = node as Interactable
		if spot == null:
			continue
		for id: String in [spot.conversation, spot.after_conversation]:
			if not id.is_empty():
				assert_true(runner.has_conversation(id), "%s: conversation '%s' exists" % [spot.get_path(), id])
	for id: String in ["otis_talk", "mox_talk", "zero_talk", "examine_pillar", "examine_lamp", "examine_crate",
			"examine_prize_crate", "examine_sign", "examine_window"]:
		var found: bool = false
		for node: Node in _room.find_children("*", "Node3D", true, false):
			if node is Interactable and (node as Interactable).conversation == id:
				found = true
		assert_true(found, "something in the room plays " + id)


func test_room_registers_the_npcs_as_speakers() -> void:
	_load_room()
	for id: String in ["otis", "mox", "zero_old", "red"]:
		assert_true(_room.runner.has_speaker(id), id + " is registered")


# ---- NPC behavior ----

func test_npc_turns_to_face_red_and_back() -> void:
	_load_room()
	var otis: Npc = _room.get_node("Otis") as Npc
	var rest: float = otis.get_rest_yaw()
	await _stand(OTIS_SPOT + Vector3(-1.0, 0.0, 0.0), OTIS_SPOT)
	var toward_red: Vector3 = (_room.player.global_position - otis.global_position)
	toward_red.y = 0.0
	toward_red = toward_red.normalized()
	assert_lt(otis.get_facing().dot(toward_red), 0.99, "not facing Red yet")
	_room.interactor.try_interact()
	for i: int in 60:
		otis.step(TICK)
	assert_gt(otis.get_facing().dot(toward_red), 0.99, "faces Red while talking")
	_finish_conversation()
	for i: int in 60:
		otis.step(TICK)
	assert_almost_eq(angle_difference(otis.rotation.y, rest), 0.0, 0.01, "turns back to where he stood")


func test_npc_turns_at_the_data_rate_and_bobs() -> void:
	_load_room()
	var otis: Npc = _room.get_node("Otis") as Npc
	var start: float = otis.rotation.y
	otis.face_point(otis.global_position + Vector3(0.0, 0.0, 5.0))
	otis.step(TICK)
	var turned: float = absf(angle_difference(otis.rotation.y, start))
	assert_le(turned, deg_to_rad(_tuning.npc_turn_rate_deg_per_s) * TICK + 0.0001)
	var visual: Node3D = otis.get_node("Visual") as Node3D
	var lowest: float = 10.0
	var highest: float = -10.0
	for i: int in 300:
		otis.step(TICK)
		lowest = minf(lowest, visual.position.y)
		highest = maxf(highest, visual.position.y)
	assert_almost_eq(highest - lowest, _tuning.npc_bob_height, 0.005, "idle bob")


func test_npc_head_point_matches_the_speaker_height_in_data() -> void:
	_load_room()
	var speakers: Dictionary = tree.root.get_node("DataDB").call("get_value", "ui/dialogue_ui", "speakers")
	for path: String in ["Otis", "Mox", "OldZero"]:
		var npc: Npc = _room.get_node(path) as Npc
		var wanted: float = float(speakers[npc.speaker_id]["head_height"])
		assert_almost_eq(npc.get_head_height(), wanted, 0.06, "%s bubble height" % path)
		assert_almost_eq(npc.get_head_point().y - npc.global_position.y, npc.get_head_height(), 0.0001)


func test_npcs_are_solid_and_placed_clear_of_the_spawn_and_pillar() -> void:
	_load_room()
	var spawn: Vector3 = (_room.get_node("PlayerSpawn") as Marker3D).global_position
	var pillar: Vector3 = (_room.get_node("Pillar") as Node3D).global_position
	for path: String in ["Otis", "Mox", "OldZero"]:
		var npc: Npc = _room.get_node(path) as Npc
		var flat: Vector3 = npc.global_position
		assert_gt(Vector2(flat.x - spawn.x, flat.z - spawn.z).length(), 1.5, path + " is not on the spawn")
		assert_gt(Vector2(flat.x - pillar.x, flat.z - pillar.z).length(), 1.5, path + " is not next to the pillar")
		var body: StaticBody3D = npc.get_node("Body") as StaticBody3D
		assert_eq(body.collision_layer & 1, 1, path + " is solid to Red")


func test_npc_placeholder_looks_differ_and_use_psx_materials() -> void:
	_load_room()
	var seen: Array[Color] = []
	for path: String in ["Otis", "Mox", "OldZero"]:
		var npc: Npc = _room.get_node(path) as Npc
		var body: MeshInstance3D = npc.get_node("Visual/Body") as MeshInstance3D
		var material: ShaderMaterial = body.material_override as ShaderMaterial
		assert_not_null(material)
		assert_true(material.shader.resource_path.begins_with("res://shaders/psx_"))
		var tint: Color = material.get_shader_parameter("albedo_tint")
		assert_does_not_have(seen, tint)
		seen.append(tint)
	assert_not_null(_room.get_node_or_null("Mox/Visual/WeldingMask"), "Mox has the welding mask block")
	assert_not_null(_room.get_node_or_null("OldZero/Visual/Wrap"))


# ---- menu and locks ----

func test_menu_opens_and_closes_in_the_room() -> void:
	_load_room()
	var menu: FieldMenu = _room.field_menu
	menu.manual_ticks = true
	menu.animations_enabled = false
	assert_true(menu.open())
	assert_true(menu.is_open())
	assert_true(_room.player.frozen, "Red is frozen while the menu is open")
	assert_true(UiStage.is_busy(tree))
	menu.close()
	menu.finish_animations()
	for i: int in 5:
		menu.tick(0.1)
	assert_false(menu.is_open())
	assert_false(_room.player.frozen, "Red is free again")
	assert_false(UiStage.is_busy(tree))


func test_cannot_interact_while_the_menu_is_open() -> void:
	_load_room()
	_room.field_menu.manual_ticks = true
	_room.field_menu.animations_enabled = false
	await _stand(OTIS_SPOT + Vector3(-1.0, 0.0, 0.0), OTIS_SPOT)
	_room.field_menu.open()
	assert_false(_room.interactor.try_interact())
	assert_false(_room.runner.is_running())
	assert_false(_room.prompt.is_showing())


func test_no_jump_on_the_frame_a_bubble_closes() -> void:
	_load_room()
	_room.player.read_engine_input = true
	await _stand(OTIS_SPOT + Vector3(-1.0, 0.0, 0.0), OTIS_SPOT)
	_room.player.read_engine_input = true
	_room.interactor.try_interact()
	# The press that closes the last bubble is also a jump press (A on a controller).
	_finish_conversation()
	Input.action_press(&"jump")
	await _ticks(3)
	assert_true(_room.player.is_on_floor(), "no jump while the bubble was closing")
	assert_almost_eq(_room.player.global_position.y, 0.0, 0.05)
	Input.action_release(&"jump")
	await _ticks(10)
	Input.action_press(&"jump")
	await _ticks(4)
	assert_gt(_room.player.global_position.y, 0.1, "she can jump again afterward")


func test_back_to_title_is_blocked_while_a_bubble_or_menu_is_up() -> void:
	var main: Node = (load("res://scenes/core/main.tscn") as PackedScene).instantiate()
	main.set("show_title", false)
	main.set("debug_overlay_enabled", false)
	main.set("start_scene", load(ROOM_PATH))
	add_to_root(main)
	await tree.process_frame
	await tree.process_frame
	assert_eq(main.call("get_state"), 2, "in the room")
	var room: FieldRoom = main.get_node("PsxScreen/WorldViewport/World/PsxTestRoom") as FieldRoom
	room.field_menu.animations_enabled = false
	room.field_menu.open()
	Input.action_press(&"start")
	await tree.process_frame
	await tree.process_frame
	assert_eq(main.call("get_state"), 2, "Start does not leave the room while the menu is open")
	Input.action_release(&"start")
	room.field_menu.close()
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	Input.action_press(&"start")
	await tree.process_frame
	await tree.process_frame
	assert_eq(main.call("get_state"), 1, "with nothing open it goes back to the title")
	Input.action_release(&"start")
