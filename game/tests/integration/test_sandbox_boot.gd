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
	var material: StandardMaterial3D = (floor_body.get_child(0) as MeshInstance3D).material_override as StandardMaterial3D
	var tile_there: bool = ResourceLoader.exists("res://art/final/textures/city/tiles_busted/floor_diamond_plate_rust.png")
	if tile_there:
		assert_not_null(material.albedo_texture, "Ross's city tile is on the floor")
	else:
		assert_null(material.albedo_texture, "plain grey when the tile is not there")


func test_the_texture_filter_comes_from_data() -> void:
	var arena: CombatSandbox = _arena()
	var wanted: String = str((arena.get_data()["arena"] as Dictionary)["texture_filter"])
	var floor_body: StaticBody3D = arena.get_node("Level/Floor") as StaticBody3D
	var material: StandardMaterial3D = (floor_body.get_child(0) as MeshInstance3D).material_override as StandardMaterial3D
	if material.albedo_texture != null and wanted == "linear":
		assert_eq(material.texture_filter, BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS)
	assert_true(arena.get_data().has("look_profile"), "the look profile is data too")


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
