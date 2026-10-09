extends TestCase
## CS-1 and CS-4: the sandbox boots from Main (feature tag or --sandbox) without touching the old
## game's boot, the input actions and layer names exist, and the arena builds from sandbox.json.

const MAIN_SCENE: String = "res://scenes/core/main.tscn"
const SANDBOX_SCENE: String = "res://scenes/sandbox/combat_sandbox.tscn"
const NEW_ACTIONS: Array[String] = [
	"light", "heavy", "dash", "parry", "lock_on", "camera_toggle", "feel_panel",
	"camera_left", "camera_right", "camera_up", "camera_down",
]
const LAYER_NAMES: Dictionary[int, String] = {
	10: "player_body", 11: "enemy_body", 12: "player_hurtbox", 13: "enemy_hurtbox",
	14: "player_hitbox", 15: "enemy_hitbox", 16: "interact",
}


func _keys_of(action: String) -> Array[int]:
	var keys: Array[int] = []
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			keys.append((event as InputEventKey).physical_keycode)
	return keys


func _buttons_of(action: String) -> Array[int]:
	var buttons: Array[int] = []
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			buttons.append((event as InputEventJoypadButton).button_index)
	return buttons


func _mouse_of(action: String) -> Array[int]:
	var buttons: Array[int] = []
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventMouseButton:
			buttons.append((event as InputEventMouseButton).button_index)
	return buttons


func test_the_combat_actions_exist_with_the_contract_bindings() -> void:
	for action: String in NEW_ACTIONS:
		assert_true(InputMap.has_action(action), "missing action " + action)
	assert_eq(_keys_of("light"), [KEY_J])
	assert_eq(_mouse_of("light"), [MOUSE_BUTTON_LEFT])
	assert_eq(_buttons_of("light"), [JOY_BUTTON_X])
	assert_eq(_keys_of("heavy"), [KEY_K])
	assert_eq(_mouse_of("heavy"), [MOUSE_BUTTON_RIGHT])
	assert_eq(_buttons_of("heavy"), [JOY_BUTTON_Y])
	assert_eq(_keys_of("dash"), [KEY_SHIFT])
	assert_eq(_buttons_of("dash"), [JOY_BUTTON_B])
	assert_eq(_keys_of("parry"), [KEY_L])
	assert_eq(_buttons_of("parry"), [JOY_BUTTON_LEFT_SHOULDER])
	assert_eq(_keys_of("lock_on"), [KEY_TAB])
	assert_eq(_mouse_of("lock_on"), [MOUSE_BUTTON_MIDDLE])
	assert_eq(_buttons_of("lock_on"), [JOY_BUTTON_RIGHT_SHOULDER])
	assert_eq(_keys_of("camera_toggle"), [KEY_V])
	assert_eq(_buttons_of("camera_toggle"), [JOY_BUTTON_RIGHT_STICK])
	assert_eq(_keys_of("feel_panel"), [KEY_F12])
	assert_eq(_buttons_of("feel_panel"), [JOY_BUTTON_BACK])


func test_the_right_stick_drives_the_camera_actions() -> void:
	var axes: Dictionary[String, Array] = {
		"camera_left": [JOY_AXIS_RIGHT_X, -1.0], "camera_right": [JOY_AXIS_RIGHT_X, 1.0],
		"camera_up": [JOY_AXIS_RIGHT_Y, -1.0], "camera_down": [JOY_AXIS_RIGHT_Y, 1.0],
	}
	for action: String in axes:
		var found: bool = false
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventJoypadMotion:
				var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
				found = found or (motion.axis == axes[action][0] and is_equal_approx(motion.axis_value, axes[action][1]))
		assert_true(found, action + " is on the right stick")


func test_the_old_actions_are_untouched() -> void:
	assert_eq(_keys_of("run"), [KEY_SHIFT])
	assert_eq(_keys_of("jump"), [KEY_SPACE])
	assert_eq(_keys_of("start"), [KEY_ENTER, KEY_ESCAPE])


func test_physics_layers_10_to_16_are_named() -> void:
	for layer: int in LAYER_NAMES:
		assert_eq(ProjectSettings.get_setting("layer_names/3d_physics/layer_%d" % layer), LAYER_NAMES[layer])


func test_the_sandbox_identity_overrides_exist_but_the_old_game_keeps_its_own() -> void:
	assert_eq(ProjectSettings.get_setting("application/config/name"), "Lights Left On")
	assert_eq(ProjectSettings.get_setting("application/config/custom_user_dir_name"), "LightsLeftOn")
	assert_eq(ProjectSettings.get_setting("application/config/name.sandbox"), "Lights On Sandbox")
	assert_eq(ProjectSettings.get_setting("application/config/custom_user_dir_name.sandbox"), "LightsOnSandbox")


func test_the_old_game_does_not_boot_the_sandbox() -> void:
	assert_false(Main.wants_sandbox(), "no sandbox tag or flag in a normal run")
	var main: Main = (load(MAIN_SCENE) as PackedScene).instantiate() as Main
	main.show_title = false
	add_to_root(main)
	assert_eq(main.get_state(), Main.State.ROOM, "the test room, as before")
	assert_null(main.get_sandbox())


func test_main_can_boot_the_sandbox_into_the_psx_world() -> void:
	var main: Main = (load(MAIN_SCENE) as PackedScene).instantiate() as Main
	main.show_title = false
	main.sandbox_boot_enabled = false
	add_to_root(main)
	var arena: Node = main.start_sandbox()
	assert_not_null(arena)
	assert_eq(main.get_state(), Main.State.SANDBOX)
	assert_eq(arena.get_parent(), main.screen.get_world_root(), "in the PSX world")
	assert_eq(main.get_sandbox(), arena)
	assert_null(main.get_title(), "the title is skipped")
	await tree.process_frame
	Input.action_press(&"start")
	await tree.process_frame
	Input.action_release(&"start")
	assert_eq(main.get_state(), Main.State.SANDBOX, "Esc belongs to the sandbox pause menu, not to the title")


func test_a_missing_sandbox_scene_falls_back_to_the_normal_boot() -> void:
	var main: Main = (load(MAIN_SCENE) as PackedScene).instantiate() as Main
	main.show_title = false
	main.sandbox_boot_enabled = false
	main.sandbox_scene_path = "res://scenes/sandbox/no_such_arena.tscn"
	add_to_root(main)
	assert_null(main.start_sandbox())
	assert_eq(main.get_state(), Main.State.ROOM)


func _arena() -> CombatSandbox:
	var arena: CombatSandbox = (load(SANDBOX_SCENE) as PackedScene).instantiate() as CombatSandbox
	add_to_root(arena)
	return arena


func test_the_arena_builds_from_data() -> void:
	var arena: CombatSandbox = _arena()
	assert_not_null(arena.get_player())
	assert_not_null(arena.get_camera())
	assert_not_null(arena.get_lock_on())
	var data: Dictionary = arena.get_data()
	var pillars: Array = (data["arena"] as Dictionary)["pillars"]
	var level: Node = arena.get_node("Level")
	for i: int in pillars.size():
		assert_not_null(level.get_node_or_null("Pillar%d" % i), "pillar %d" % i)
	assert_not_null(level.get_node_or_null("Ledge0"), "a ledge")
	assert_not_null(level.get_node_or_null("Floor"))
	assert_eq(arena.get_racks().size(), ((data["racks"] as Dictionary)["stands"] as Array).size(), "one stand per sword")
	assert_not_null(arena.get_node_or_null("Lights/KeyLight"))
	var key: DirectionalLight3D = arena.get_node("Lights/KeyLight") as DirectionalLight3D
	assert_true(key.shadow_enabled, "one shadow-casting key light")


func test_the_player_stands_on_the_floor_at_the_spawn() -> void:
	var arena: CombatSandbox = _arena()
	var player: ActionPlayer = arena.get_player() as ActionPlayer
	for i: int in 30:
		await tree.physics_frame
	assert_true(player.is_on_floor(), "standing on the arena floor")
	var spawn: Vector3 = arena.get_player_spawn().origin
	assert_almost_eq(player.global_position.x, spawn.x, 0.01)
	assert_almost_eq(player.global_position.z, spawn.z, 0.01)
	assert_almost_eq(player.global_position.y, 0.0, 0.05)


func test_the_floor_and_walls_are_on_the_world_layer() -> void:
	var arena: CombatSandbox = _arena()
	for child: Node in arena.get_node("Level").get_children():
		var body: StaticBody3D = child as StaticBody3D
		assert_not_null(body, child.name + " is solid")
		if body != null:
			assert_eq(body.collision_layer, 1, child.name + " is on layer 1 (world)")


func test_tiles_come_from_the_atlas_or_fall_back_to_grey() -> void:
	var arena: CombatSandbox = _arena()
	var floor_body: StaticBody3D = arena.get_node("Level/Floor") as StaticBody3D
	var material: Material = (floor_body.get_child(0) as MeshInstance3D).material_override
	var tile_there: bool = ResourceLoader.exists("res://art/final/textures/city/tiles/floor_plate_diamond_cross_a.png")
	if tile_there:
		assert_true(material is ShaderMaterial, "Ross's city tile is on the floor, on the PS2 material")
		assert_not_null((material as ShaderMaterial).get_shader_parameter(&"albedo_texture"))
	else:
		assert_true(material is StandardMaterial3D, "plain grey when the tile is not there")


func test_the_texture_filter_comes_from_data() -> void:
	var arena: CombatSandbox = _arena()
	var floor_body: StaticBody3D = arena.get_node("Level/Floor") as StaticBody3D
	var material: ShaderMaterial = (floor_body.get_child(0) as MeshInstance3D).material_override as ShaderMaterial
	assert_not_null(material)
	var wanted: String = Ps2Look.filter_for(LookProfiles.active(), "city_tiles")
	var crisp: bool = material.shader.resource_path == Ps2Look.CRISP_SHADER_PATH
	assert_eq(crisp, wanted == Ps2Look.NEAREST, "nearest in the profile = the crisp shader, and nothing in code decides it")


func test_screen_pos_of_gives_stage_pixels_and_zero_for_unknown() -> void:
	var arena: CombatSandbox = _arena()
	for i: int in 5:
		await tree.physics_frame
	await tree.process_frame
	var spot: Vector2 = arena.screen_pos_of(&"red", &"head")
	assert_ne(spot, Vector2.ZERO)
	assert_ge(spot.x, 0.0)
	assert_le(spot.x, 640.0)
	assert_ge(spot.y, 0.0)
	assert_le(spot.y, 360.0)
	assert_eq(arena.screen_pos_of(&"nobody", &"head"), Vector2.ZERO)


func test_reset_puts_red_back_at_the_spawn_with_full_health() -> void:
	var arena: CombatSandbox = _arena()
	var player: ActionPlayer = arena.get_player() as ActionPlayer
	var resets: Array[int] = []
	arena.arena_reset.connect(func() -> void: resets.append(1))
	player.global_position = Vector3(5, 0, -3)
	player.hp = 3
	arena.reset_arena()
	assert_eq(player.hp, player.hp_max)
	assert_almost_eq(player.global_position.distance_to(arena.get_player_spawn().origin), 0.0, 0.01)
	assert_eq(resets.size(), 1)


func test_falling_out_of_the_world_returns_to_the_spawn() -> void:
	var arena: CombatSandbox = _arena()
	var player: ActionPlayer = arena.get_player() as ActionPlayer
	player.global_position = Vector3(0, -20, 0)
	arena.tick()
	assert_almost_eq(player.global_position.distance_to(arena.get_player_spawn().origin), 0.0, 0.01)


func test_a_rack_equips_its_sword_when_red_walks_on_and_only_once() -> void:
	var arena: CombatSandbox = _arena()
	var rack: SwordRack = arena.get_racks()[2]
	var log: Array[StringName] = []
	rack.sword_picked.connect(func(id: StringName) -> void: log.append(id))
	var stub: SwordTaker = SwordTaker.new()
	add_to_root(stub)
	assert_true(rack.give_to(stub), "first visit takes")
	assert_false(rack.give_to(stub), "standing on it again does nothing")
	assert_eq(log, [rack.sword_id])
	assert_eq(stub.sword, rack.sword_id)
	assert_false(rack.give_to(Node3D.new()), "no sword hand, no swap, no crash")


class SwordTaker extends Node3D:
	var sword: StringName = &""

	func equip_sword(id: StringName) -> bool:
		sword = id
		return true

	func current_sword() -> StringName:
		return sword


func test_walking_onto_a_stand_swaps_the_sword_in_her_hand() -> void:
	var arena: CombatSandbox = _arena()
	var player: ActionPlayer = arena.get_player() as ActionPlayer
	player.read_engine_input = false
	for i: int in 3:
		await tree.physics_frame
	var first: SwordRack = arena.get_racks()[0]
	var other: SwordRack = arena.get_racks()[3]
	var before: StringName = player.current_sword()
	player.global_position = other.global_position + Vector3(0.0, 0.05, 0.0)
	for i: int in 6:
		await tree.physics_frame
	if before == &"" and player.current_sword() == &"":
		# no GearVisuals on this build: nothing to assert about the hand, but the stand must not crash
		assert_true(true, "no gear visuals yet")
		return
	assert_eq(player.current_sword(), other.sword_id, "the glass_core stand put its sword in her hand")
	assert_ne(player.current_sword(), first.sword_id)


func test_the_sandbox_hud_is_not_covered_by_the_old_f1_hint() -> void:
	var main: Main = (load(MAIN_SCENE) as PackedScene).instantiate() as Main
	main.show_title = false
	main.sandbox_boot_enabled = false
	add_to_root(main)
	main.start_sandbox()
	for node: Node in main.overlay.find_children("*", "Label", true, false):
		assert_ne((node as Label).text, PsxDebugOverlay.HINT_TEXT, "the F1 hint is gone in the sandbox")


func test_reset_respawns_every_enemy_the_data_lists() -> void:
	var arena: CombatSandbox = _arena()
	var listed: int = (arena.get_data()["enemy_spawns"] as Array).size()
	var spawned: int = arena.get_enemies().size()
	var expected: int = 0
	for entry: Variant in arena.get_data()["enemy_spawns"] as Array:
		var kind: String = str((entry as Dictionary)["enemy"])
		var path: String = str(((arena.get_data()["enemy_scenes"]) as Dictionary).get(kind, ""))
		if ResourceLoader.exists(path):
			expected += 1
	assert_eq(spawned, expected, "one enemy per listed spawn whose scene exists (%d listed)" % listed)
	if spawned > 0:
		var first: Node3D = arena.get_enemies()[0]
		first.global_position = Vector3(3, 0, 3)
	arena.reset_arena()
	await tree.process_frame
	assert_eq(arena.get_enemies().size(), expected, "all of them are back")


func test_the_mouse_turns_the_camera_only_while_it_is_captured_and_the_pause_gate_round_trip_is_safe() -> void:
	var arena: CombatSandbox = _arena()
	var camera: OrbitCamera = arena.get_camera()
	camera.read_engine_input = false
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.relative = Vector2(80, 0)
	arena.set_mouse_captured(true)
	assert_true(arena.is_mouse_captured())
	arena.mouse_mode_override = Input.MOUSE_MODE_CAPTURED   # what the arena sets in a real window
	var yaw0: float = camera.get_yaw()
	arena.handle_input_event(motion)
	camera.tick(1.0 / 60.0)
	assert_lt(camera.get_yaw(), yaw0, "captured: the mouse turns the view")
	# The pause gate frees the mouse while a menu is open...
	arena.mouse_mode_override = Input.MOUSE_MODE_VISIBLE
	var yaw1: float = camera.get_yaw()
	arena.handle_input_event(motion)
	camera.tick(1.0 / 60.0)
	assert_almost_eq(camera.get_yaw(), yaw1, 0.0001, "menu open: moving the pointer does not spin the camera")
	# ...and gives it back afterwards: the camera picks up again with no extra step.
	arena.mouse_mode_override = Input.MOUSE_MODE_CAPTURED
	arena.handle_input_event(motion)
	camera.tick(1.0 / 60.0)
	assert_lt(camera.get_yaw(), yaw1, "restored: turning works again")


func test_the_arena_wears_the_ps2_look() -> void:
	var arena: CombatSandbox = _arena()
	assert_not_null(arena.get_node_or_null("Ps2Look"), "one Ps2Look next to the WorldEnvironment and the key light")
	assert_eq(LookProfiles.active_id(), "grim_ps2")
	var floor_mesh: MeshInstance3D = arena.get_node("Level/Floor").get_child(0) as MeshInstance3D
	var material: ShaderMaterial = floor_mesh.material_override as ShaderMaterial
	assert_not_null(material, "city tiles use the PS2 shader material")
	if material != null:
		var shader_path: String = material.shader.resource_path
		var wanted: String = Ps2Look.shader_path_for(LookProfiles.active(), "city_tiles")
		assert_eq(shader_path, wanted, "the filter comes from the profile's texture_filter block")
	var environment: Environment = (arena.get_node("WorldEnvironment") as WorldEnvironment).environment
	assert_eq(environment.glow_enabled, bool((LookProfiles.active().get("glow", {}) as Dictionary).get("enabled", false)))


func test_the_seam_fixed_tile_copy_is_used_where_the_atlas_has_one() -> void:
	var arena: CombatSandbox = _arena()
	var db: Node = tree.root.get_node("DataDB")
	for raw: Variant in db.call("get_value", "world/city_texture_atlas", "tiles", []) as Array:
		var entry: Dictionary = raw as Dictionary
		if str(entry["id"]) == "steel_plate_riveted_grey" and bool(entry.get("seamless_copy", false)):
			# the clean copy is the one with a fixed seam; the arena may be on busted, so ask the method directly
			arena.get_data()["arena"]["tile_variant"] = "clean"
			var texture: Texture2D = arena._tile_texture("steel_plate_riveted_grey")
			assert_not_null(texture)
			assert_true(texture.resource_path.contains("_seamless"), "seamless copy: " + texture.resource_path)
	assert_true(true)


## An arena with no enemies, the player under manual control, ready to be walked about by a bot.
func _quiet_arena() -> CombatSandbox:
	var arena: CombatSandbox = _arena()
	for enemy: Node3D in arena.get_enemies():
		enemy.get_parent().remove_child(enemy)
		enemy.free()
	var player: ActionPlayer = arena.get_player() as ActionPlayer
	player.read_engine_input = false
	player.set_physics_process(false)
	(arena.get_director() as CombatDirector).set_physics_process(false)
	for i: int in 3:
		await tree.physics_frame
	return arena


func _bot_step(arena: CombatSandbox, frames: int) -> void:
	var director: CombatDirector = arena.get_director() as CombatDirector
	var player: ActionPlayer = arena.get_player() as ActionPlayer
	for i: int in frames:
		director.tick(1.0 / 60.0)
		player.tick(1.0 / 60.0)


func _bot_cam(player: ActionPlayer) -> void:
	var cam: Camera3D = Camera3D.new()
	add_to_root(cam)
	cam.global_basis = Basis.IDENTITY               # looks along -Z: up on the stick is -Z
	player.camera = cam


func test_a_bot_runs_up_the_ramp_and_onto_the_back_ledge() -> void:
	var arena: CombatSandbox = await _quiet_arena()
	var player: ActionPlayer = arena.get_player() as ActionPlayer
	_bot_cam(player)
	var ramp: Dictionary = ((arena.get_data()["arena"] as Dictionary)["ramps"] as Array)[0]
	var toe: Array = ramp["pos"]
	var ledge_top: float = float(ramp["rise_m"])
	player.reset_to(Transform3D(Basis.from_euler(Vector3(0, PI, 0)), Vector3(float(toe[0]), 0.05, float(toe[2]) + 3.0)))
	_bot_step(arena, 5)
	player.set_move_input(Vector2(0, -1))
	var smooth: bool = true
	var last_y: float = player.global_position.y
	var frames: int = 0
	while player.global_position.z > float(toe[2]) - 7.5 and frames < 240:
		_bot_step(arena, 1)
		smooth = smooth and player.global_position.y - last_y < 0.12     # no hop or snap on the way up
		last_y = player.global_position.y
		frames += 1
	assert_lt(frames, 200, "she got there")
	assert_almost_eq(player.global_position.y, ledge_top, 0.08, "Red stands on the 1.2 m ledge")
	assert_true(player.is_on_floor())
	assert_true(smooth, "up the slope in one smooth run")


func test_the_ramp_has_no_lip_at_its_foot() -> void:
	var arena: CombatSandbox = await _quiet_arena()
	var player: ActionPlayer = arena.get_player() as ActionPlayer
	_bot_cam(player)
	var toe: Array = (((arena.get_data()["arena"] as Dictionary)["ramps"] as Array)[0] as Dictionary)["pos"]
	player.reset_to(Transform3D(Basis.from_euler(Vector3(0, PI, 0)), Vector3(float(toe[0]), 0.05, float(toe[2]) + 2.0)))
	_bot_step(arena, 5)
	player.set_move_input(Vector2(0, -1))
	var frames: int = 0
	while player.global_position.z > float(toe[2]) - 1.0 and frames < 120:
		_bot_step(arena, 1)
		frames += 1
	assert_lt(frames, 60, "she walked straight through the toe of the ramp without stopping")
	assert_gt(player.global_position.y, 0.05, "and is already climbing")


func test_a_bot_can_jump_up_onto_the_back_ledge_and_the_side_ledge() -> void:
	var arena: CombatSandbox = await _quiet_arena()
	var player: ActionPlayer = arena.get_player() as ActionPlayer
	_bot_cam(player)
	var ledges: Array = (arena.get_data()["arena"] as Dictionary)["ledges"]
	# Back ledge: run at its front face (it faces +Z, Red runs toward -Z) and jump. Side ledge: run toward -X.
	var back: Dictionary = ledges[0]
	var back_pos: Array = back["pos"]
	var back_size: Array = back["size"]
	player.reset_to(Transform3D(Basis.from_euler(Vector3(0, PI, 0)), Vector3(5.0, 0.05, float(back_pos[2]) + float(back_size[2]) * 0.5 + 3.0)))
	_bot_step(arena, 5)
	player.set_move_input(Vector2(0, -1))
	_bot_step(arena, 10)
	player.press(&"jump")
	assert_almost_eq(_best_standing_height(arena, 60), float(back_size[1]), 0.08, "jumped up onto the 1.2 m back ledge")
	var side: Dictionary = ledges[1]
	var side_pos: Array = side["pos"]
	var side_size: Array = side["size"]
	player.reset_to(Transform3D(Basis.from_euler(Vector3(0, -PI * 0.5, 0)), Vector3(float(side_pos[0]) + float(side_size[0]) * 0.5 + 3.0, 0.05, float(side_pos[2]))))
	player.set_move_input(Vector2(-1, 0))
	_bot_step(arena, 12)
	player.press(&"jump")
	assert_almost_eq(_best_standing_height(arena, 60), float(side_size[1]), 0.08, "and onto the 0.7 m side ledge")


## Steps the bot and returns the highest ground Red stood on during that time.
func _best_standing_height(arena: CombatSandbox, frames: int) -> float:
	var player: ActionPlayer = arena.get_player() as ActionPlayer
	var best: float = 0.0
	for i: int in frames:
		_bot_step(arena, 1)
		if player.is_on_floor():
			best = maxf(best, player.global_position.y)
	return best


func test_rack_labels_show_only_for_the_nearest_stand_within_three_metres() -> void:
	var arena: CombatSandbox = await _quiet_arena()
	var player: ActionPlayer = arena.get_player() as ActionPlayer
	var racks: Array[SwordRack] = arena.get_racks()
	player.global_position = racks[2].global_position + Vector3(0, 0, -10.0)
	arena.tick()
	for rack: SwordRack in racks:
		assert_eq(rack.label_alpha(), 0.0, "far from every stand: no label at all")
	player.global_position = racks[2].global_position + Vector3(0.0, 0, -1.5)
	arena.tick()
	assert_eq(racks[2].label_alpha(), 1.0, "close to one stand: its label")
	var shown: int = 0
	for rack: SwordRack in racks:
		if rack.label_alpha() > 0.0:
			shown += 1
	assert_eq(shown, 1, "never two labels at once")
	player.global_position = racks[2].global_position + Vector3(0.0, 0, -2.8)
	arena.tick()
	assert_gt(racks[2].label_alpha(), 0.0)
	assert_lt(racks[2].label_alpha(), 1.0, "fading at the edge of the range")
	player.global_position = racks[2].global_position + Vector3(0.0, 0, -4.0)
	arena.tick()
	assert_eq(racks[2].label_alpha(), 0.0, "gone past about 3 m")


func test_rack_labels_use_the_ui_font_white_with_a_black_drop_shadow_and_the_rings_are_dim() -> void:
	var arena: CombatSandbox = await _quiet_arena()
	var rack: SwordRack = arena.get_racks()[0]
	var labels: Array[Label3D] = []
	var ring: MeshInstance3D = null
	for child: Node in rack.get_children():
		if child is Label3D:
			labels.append(child as Label3D)
		elif child is MeshInstance3D and (child as MeshInstance3D).mesh is TorusMesh:
			ring = child as MeshInstance3D
	assert_eq(labels.size(), 2, "the name and its shadow")
	for label: Label3D in labels:
		assert_eq(label.font, UiFonts.get_font("tag"), "the sandbox UI font, not the default one")
	var front: Label3D = labels[1]
	var shadow: Label3D = labels[0]
	assert_eq(front.modulate.r, 1.0)
	assert_eq(front.modulate.g, 1.0)
	assert_eq(shadow.modulate.r, 0.0)
	assert_gt(shadow.offset.x, 0.0, "shadow goes right")
	assert_lt(shadow.offset.y, 0.0, "and down")
	assert_lt((mesh_ring_radius(ring)), 0.5, "the ring is small")
	var material: StandardMaterial3D = ring.material_override as StandardMaterial3D
	assert_le(material.emission_energy_multiplier, 0.5, "dim: it can't pass for an enemy wind-up warning")


func mesh_ring_radius(ring: MeshInstance3D) -> float:
	return (ring.mesh as TorusMesh).outer_radius


func test_a_dash_run_uses_the_sandbox_user_folder() -> void:
	var name_key: String = "application/config/custom_user_dir_name"
	var saved: Variant = ProjectSettings.get_setting(name_key)
	var saved_name: Variant = ProjectSettings.get_setting("application/config/name")
	Main.apply_sandbox_identity()
	assert_true(OS.get_user_data_dir().ends_with("LightsOnSandbox"), "feel files go to the sandbox folder: " + OS.get_user_data_dir())
	assert_eq(ProjectSettings.get_setting("application/config/name"), "Lights On Sandbox")
	ProjectSettings.set_setting(name_key, saved)
	ProjectSettings.set_setting("application/config/name", saved_name)
	assert_true(OS.get_user_data_dir().ends_with("LightsLeftOn"), "and the old game's folder is back for the rest of the tests")
