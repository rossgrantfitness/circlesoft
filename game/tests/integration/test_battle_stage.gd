extends TestCase
## The battle stage (M2-8): the scene loads, the slots exist and read at 384x216, the camera never rotates, the
## cue (flash + ding + "!") fires from one moment, Clutch input is forwarded with a timestamp, hits shake and
## recoil, the K.O. beat freezes once, grunts leave with a white flag, and the stage hands back `finished`.
## It runs against a stub controller (tests/fixtures/battle_stage/stub_battle_controller.gd) so it works with or
## without the real BattleController. Needs the project imported once: godot --headless --path game --import

const SCENE: String = "res://scenes/battle/battle_scene.tscn"
const STUB: String = "res://tests/fixtures/battle_stage/stub_battle_controller.gd"
const VIEW_SCRIPT_DIR: String = "res://scripts/battle/view"
const STAGE_W: float = 384.0
const STAGE_H: float = 216.0
const HUD_BAND_TOP: float = 168.0          # the bottom of the screen is the HUD's (command list, party bars)
const RED_MIN_PIXELS: float = 36.0         # Red (1.0 tall) must stand at least this tall on the 384x216 picture
const MIN_SLOT_GAP_PX: float = 22.0
const WAIT_LIMIT_S: float = 6.0
const TUNING_DATA_ID: String = "battle_stage/stage"
const READ_PATTERN: String = "\\.(?:number|integer|flag|text|color|vec3|vec2|dict|list|vec3_list|string_list)\\(\"([a-z_.]+)\"\\)"

var _signal_hits: int = 0
var _last_payload: Array = []


func _stage() -> BattleScene:
	var stage: BattleScene = (load(SCENE) as PackedScene).instantiate() as BattleScene
	stage.transitions_enabled = false
	stage.audio = FakeAudio.new()
	add_to_root(stage)
	stage.set_dynamic_camera(false)        # these tests use the calm fixed framing; test_battle_stage_camera.gd covers Dynamic
	return stage


func _stub() -> RefCounted:
	var stub: RefCounted = (load(STUB) as GDScript).new() as RefCounted
	stub.set("instant", true)
	return stub


func _booted(stage: BattleScene, stub: RefCounted) -> void:
	stage.attach_controller(stub)
	stage._on_battle_started(stub.call("snapshot"))


## The real data with short times, so the waits in these tests stay short.
func _fast_tuning() -> BattleStageTuning:
	var db: Node = tree.root.get_node("DataDB")
	var data: Dictionary = (db.call("get_dict", TUNING_DATA_ID) as Dictionary).duplicate(true)
	data["ko"]["freeze_ms"] = 60
	data["end"]["hold_s"] = 0.02
	data["static"]["in_ms"] = 80
	data["static"]["out_ms"] = 60
	data["static"]["hold_ms"] = 20
	data["static"]["boss_in_ms"] = 160
	data["static"]["boss_out_ms"] = 120
	data["static"]["boss_hold_ms"] = 40
	data["motion"]["flag"]["raise_ms"] = 80
	data["motion"]["flag"]["wave_ms"] = 80
	data["motion"]["flag"]["walk_off_ms"] = 120
	data["motion"]["flag"]["zip_off_ms"] = 80
	data["motion"]["ko_fall"]["ms"] = 60
	data["motion"]["ko_fall"]["crash_ms"] = 60
	data["motion"]["ko_fall"]["blink_ms"] = 60
	data["camera"]["push_in"]["ko"]["hold_ms"] = 20
	data["camera"]["push_in"]["ko"]["out_ms"] = 30
	return BattleStageTuning.from_dict(data)


func _wait_until(condition: Callable, seconds: float = WAIT_LIMIT_S) -> bool:
	var start: int = Time.get_ticks_msec()
	while not condition.call():
		if float(Time.get_ticks_msec() - start) / 1000.0 > seconds:
			return false
		await tree.process_frame
	return true


## Waits for `done` to get something. A real HUD holds the end of the fight on its victory / game over screen
## until the player presses a button, so when one is bound the test plays that button press.
func _wait_for_finish(stage: BattleScene, done: Array, seconds: float = WAIT_LIMIT_S) -> bool:
	var start: int = Time.get_ticks_msec()
	while done.is_empty():
		if stage.hud != null and not stage.result.is_empty() and stage.hud.has_signal("finished"):
			stage.hud.emit_signal("finished", stage.result, "continue")
		if float(Time.get_ticks_msec() - start) / 1000.0 > seconds:
			return false
		await tree.process_frame
	return true


func _count(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	_signal_hits += 1
	_last_payload = [_a, _b, _c]


func _press(action: StringName, pressed: bool) -> InputEventAction:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = pressed
	return event


# ---- the scene and the data ----

func test_scene_loads_with_its_nodes_and_slots() -> void:
	var stage: BattleScene = _stage()
	assert_not_null(stage.backdrop, "Backdrop")
	assert_not_null(stage.camera_rig.get_camera(), "Camera3D")
	assert_not_null(stage.static_layer, "StaticLayer")
	assert_not_null(stage.combatants_root, "Combatants")
	for slot: int in 3:
		assert_not_null(stage.slot_marker("party", slot), "PartySlot%d" % slot)
	for slot: int in 4:
		assert_not_null(stage.slot_marker("enemy", slot), "EnemySlot%d" % slot)
	assert_null(stage.slot_marker("enemy", 4), "only four enemy slots")
	assert_true(stage.is_in_group(&"battle_stage"))


func test_slots_come_from_data_and_are_spread_out() -> void:
	var stage: BattleScene = _stage()
	var tuning: BattleStageTuning = stage.tuning
	var party: Array[Vector3] = tuning.vec3_list("formation.party")
	var enemy: Array[Vector3] = tuning.vec3_list("formation.enemy")
	assert_eq(party.size(), 3, "three party slots")
	assert_eq(enemy.size(), 4, "four enemy slots")
	for slot: int in party.size():
		assert_true(stage.slot_marker("party", slot).position.is_equal_approx(party[slot]), "party slot %d position" % slot)
	for slot: int in enemy.size():
		assert_true(stage.slot_marker("enemy", slot).position.is_equal_approx(enemy[slot]), "enemy slot %d position" % slot)
	for side: Array[Vector3] in [party, enemy]:
		for i: int in side.size():
			for j: int in range(i + 1, side.size()):
				assert_gt(side[i].distance_to(side[j]), 1.0, "slots %d and %d are not on top of each other" % [i, j])
	for a: Vector3 in party:
		for b: Vector3 in enemy:
			assert_gt(a.distance_to(b), 2.0, "the two sides keep apart")
	assert_gt(party[0].x, 0.0, "party on the right")
	assert_lt(enemy[0].x, 0.0, "enemies on the left")


func test_slots_read_at_384x216() -> void:
	var stage: BattleScene = _stage()
	var camera: Camera3D = stage.camera_rig.get_camera()
	var feet: Array[Vector2] = []
	for side: String in ["party", "enemy"]:
		var count: int = 3 if side == "party" else 4
		for slot: int in count:
			var floor_point: Vector3 = stage.slot_marker(side, slot).global_position
			var head_point: Vector3 = floor_point + Vector3.UP * 1.0
			var foot: Vector2 = BubblePlacement.project_to_stage(camera, floor_point, Vector2(STAGE_W, STAGE_H))
			var head: Vector2 = BubblePlacement.project_to_stage(camera, head_point, Vector2(STAGE_W, STAGE_H))
			assert_true(Rect2(8.0, 8.0, STAGE_W - 16.0, HUD_BAND_TOP - 8.0).has_point(foot), "%s slot %d feet are on screen above the HUD band (%s)" % [side, slot, foot])
			assert_gt(head.y, 4.0, "%s slot %d head is on screen" % [side, slot])
			assert_gt(foot.y - head.y, RED_MIN_PIXELS, "a 1.0 tall fighter in %s slot %d is at least %d px tall" % [side, slot, int(RED_MIN_PIXELS)])
			for other: Vector2 in feet:
				assert_gt(foot.distance_to(other), MIN_SLOT_GAP_PX, "slot markers do not pile up on screen")
			feet.append(foot)


func test_tuning_has_every_key_the_code_reads() -> void:
	var stage: BattleScene = _stage()
	var pattern: RegEx = RegEx.new()
	pattern.compile(READ_PATTERN)
	var checked: int = 0
	for file_name: String in DirAccess.get_files_at(VIEW_SCRIPT_DIR):
		if file_name.get_extension() != "gd":
			continue
		var source: String = FileAccess.get_file_as_string(VIEW_SCRIPT_DIR.path_join(file_name))
		for found: RegExMatch in pattern.search_all(source):
			var key: String = found.get_string(1)
			if key.contains("%"):
				continue
			var source_tuning: BattleStageTuning = stage.cam_tuning if key.begins_with("director.") else stage.tuning
			assert_true(source_tuning.has(key), "%s reads '%s' which is missing from the stage data" % [file_name, key])
			checked += 1
	assert_gt(checked, 30, "the scan should have found the tuning reads")


func test_every_backdrop_builds_within_the_room_budget() -> void:
	var stage: BattleScene = _stage()
	for id: String in ["default", "harrow", "road", "tower", "no_such_place"]:
		stage.backdrop.build(stage.tuning, id)
		assert_le(stage.backdrop.triangle_count(), 3500, "%s: interior hard cap from the style guide" % id)
		assert_ge(stage.backdrop.lamps.size(), 2, "%s has lamps in the dark" % id)
		assert_not_null(stage.backdrop.get_node_or_null("Floor"), "%s floor" % id)
		assert_not_null(stage.backdrop.get_node_or_null("WallBack"), "%s back wall" % id)
		assert_not_null(stage.backdrop.get_node_or_null("WallLeft"), "%s left wall" % id)
	stage.backdrop.build(stage.tuning, "harrow")
	var wall: MeshInstance3D = stage.backdrop.get_node("WallBack") as MeshInstance3D
	var material: ShaderMaterial = wall.get_surface_override_material(0) as ShaderMaterial
	assert_true(material.shader.resource_path.begins_with("res://shaders/psx_"), "the walls use the PSX shader")


func test_backdrop_textures_are_in_the_allowed_sizes() -> void:
	var stage: BattleScene = _stage()
	var look: Dictionary = stage.tuning.backdrop("default")
	for texture: Texture2D in [BattleTextures.floor_texture(look), BattleTextures.wall_texture(look), BattleTextures.crate_texture(look)]:
		assert_ge(texture.get_width(), 64)
		assert_le(texture.get_width(), 256)
		assert_ge(texture.get_height(), 64)
		assert_le(texture.get_height(), 256)
	var again: Image = BattleTextures._paint_floor_texture(look).get_image()
	var first: Image = BattleTextures._paint_floor_texture(look).get_image()
	assert_eq(again.get_data(), first.get_data(), "painted the same every time")


# ---- the camera ----

func test_camera_never_rotates_and_shake_and_push_move_it_only_sideways() -> void:
	var stage: BattleScene = _stage()
	var rig: BattleCamera = stage.camera_rig
	var basis_before: Basis = rig.fixed_basis()
	rig.shake(0.1, 200.0, 30.0)
	rig.step_shake(0.04)
	assert_gt(rig.shake_offset.length(), 0.0, "the shake moves the camera")
	assert_le(rig.shake_offset.length(), 0.1 + 0.0001, "never more than the amplitude")
	assert_true(rig.is_shaking())
	assert_true(rig.fixed_basis().is_equal_approx(basis_before), "shake does not rotate")
	rig.step_shake(0.5)
	assert_false(rig.is_shaking(), "the shake ends")
	assert_eq(rig.shake_offset, Vector2.ZERO)
	rig.push_in("big_hit")
	await tree.create_timer(0.2).timeout
	assert_gt(rig.push_amount, 0.0, "the push-in slides toward the look-at point")
	var closer: float = rig.position.distance_to(rig.look_at_point)
	assert_lt(closer, rig.base_position.distance_to(rig.look_at_point), "closer to the action")
	assert_true(rig.fixed_basis().is_equal_approx(basis_before), "push-in does not rotate")
	await _wait_until(func() -> bool: return not rig.is_pushing())
	assert_almost_eq(rig.push_amount, 0.0, 0.001, "and it eases back")


func test_stronger_shake_replaces_weaker_but_not_the_other_way() -> void:
	var stage: BattleScene = _stage()
	var rig: BattleCamera = stage.camera_rig
	rig.shake(0.2, 400.0, 30.0)
	rig.shake(0.01, 100.0, 30.0)
	rig.step_shake(0.001)
	assert_gt(rig.shake_offset.length(), 0.02, "the weak shake did not take over")


# ---- spawning ----

func test_battle_started_spawns_party_and_enemies_on_their_slots() -> void:
	var stage: BattleScene = _stage()
	var stub: RefCounted = _stub()
	_booted(stage, stub)
	assert_eq(stage.views.size(), 7, "3 party + 4 enemies")
	for id: String in ["red", "otis", "mox", "e1", "e2", "e3", "e4"]:
		assert_true(stage.has_combatant(id), id)
		var view: CombatantView = stage.get_view(id)
		assert_false(view.used_fallback, "%s loaded its model" % id)
		assert_true(view.has_idle_clip(), "%s has an idle clip" % id)
		assert_true(view.animation_player.is_playing(), "%s plays it" % id)
		var slot_point: Vector3 = stage.slot_marker(view.side, view.slot).position
		assert_true(view.home_position.is_equal_approx(slot_point), "%s stands on its slot" % id)
	assert_lt(stage.get_view("red").home_yaw, 0.0, "party turned toward the left")
	assert_gt(stage.get_view("e1").home_yaw, 0.0, "enemies turned toward the right")


func test_fighters_do_not_share_materials() -> void:
	var stage: BattleScene = _stage()
	var stub: RefCounted = _stub()
	stub.set("enemy_kinds", ["signals_grunt", "signals_grunt", "signals_grunt", "signals_grunt"])
	var grunt: String = "res://art/placeholder/enemies/signals_grunt/enm_signals_grunt.glb"
	stub.set("enemy_models", [grunt, grunt, grunt, grunt])
	_booted(stage, stub)
	var first: CombatantView = stage.get_view("e1")
	var second: CombatantView = stage.get_view("e2")
	first.flash(Color(3, 3, 3), 300.0)
	assert_true(first.is_flashing())
	assert_false(second.is_flashing(), "flashing one grunt leaves the others alone")
	assert_gt(first.current_tint_energy(), second.current_tint_energy() + 0.5, "only the first is bright")
	first.show_hurt_face(300.0)
	assert_eq(first.face_column(), 1, "ouch face")
	assert_eq(second.face_column(), 0, "the other grunt keeps its face")


func test_missing_model_path_falls_back_to_the_kind_then_a_stand_in() -> void:
	var stage: BattleScene = _stage()
	var stub: RefCounted = _stub()
	stub.set("enemy_models", ["res://nope/missing.glb", "res://nope/missing.glb", "res://nope/missing.glb", "res://nope/missing.glb"])
	_booted(stage, stub)
	assert_false(stage.get_view("e1").used_fallback, "a grunt kind finds the grunt model")
	assert_true(stage.get_view("e2").model_path.contains("signals_drone"), "a drone kind finds the drone")
	var snap: Dictionary = stub.call("snapshot")
	var odd: Dictionary = (snap["combatants"] as Array)[3]
	odd["model"] = "res://nope/x.glb"
	odd["side"] = "party"
	odd["kind"] = "stranger"
	odd["id"] = "stranger"
	odd["slot"] = 2
	var view: CombatantView = CombatantView.new()
	view.setup(odd, stage.tuning, stage._resolve_model(odd))
	own(view)
	assert_true(view.used_fallback, "an unknown character still gets a stand-in")
	assert_not_null(view.model)


func test_boss_flag_picks_the_longer_static() -> void:
	var stage: BattleScene = _stage()
	var normal: float = stage.transition_ms(true)
	var stub: RefCounted = _stub()
	stub.set("is_boss", true)
	_booted(stage, stub)
	assert_true(stage.is_boss)
	assert_gt(stage.transition_ms(true), normal * 1.5, "the boss static-in is longer")
	assert_gt(stage.transition_ms(false), 0.0)


# ---- screen_pos_of ----

func test_screen_pos_of_gives_stage_pixels_above_the_feet() -> void:
	var stage: BattleScene = _stage()
	var stub: RefCounted = _stub()
	_booted(stage, stub)
	var rect: Rect2 = Rect2(0.0, 0.0, STAGE_W, STAGE_H)
	for id: String in stage.views:
		var head: Vector2 = stage.screen_pos_of(id)
		var feet: Vector2 = stage.screen_pos_of(id, &"feet")
		var middle: Vector2 = stage.screen_pos_of(id, &"center")
		assert_true(rect.has_point(head), "%s head %s is on the stage" % [id, head])
		assert_lt(head.y, middle.y, "%s: head above the middle" % id)
		assert_lt(middle.y, feet.y + 0.5, "%s: middle above the feet" % id)
	assert_eq(stage.screen_pos_of("nobody"), Vector2.ZERO, "unknown id")
	var head_before: Vector2 = stage.screen_pos_of("red")
	stage.get_view("red").position += Vector3(1.0, 0.0, 0.0)
	assert_gt(stage.screen_pos_of("red").x, head_before.x, "it follows the fighter when it moves")
	assert_lt(stage.screen_pos_of("e1").x, stage.screen_pos_of("red").x, "enemies are left of the party")


# ---- the cue: flash + ding + "!" from one moment ----

func test_cue_flash_ding_and_marker_fire_together_at_t0_plus_cue() -> void:
	var stage: BattleScene = _stage()
	var stub: RefCounted = _stub()
	stub.set("use_virtual_clock", true)
	stub.set("virtual_usec", 1000000)
	_booted(stage, stub)
	var audio: FakeAudio = stage.audio as FakeAudio
	_signal_hits = 0
	stage.cue_fired.connect(_count)
	var action: Dictionary = stub.call("make_action", "red", "attack", ["e1"], 500)
	stage._on_action_started(action)
	var red: CombatantView = stage.get_view("red")
	assert_eq(stage.pending_cue_count(), 1, "one cue waiting")
	assert_false(audio.sfx_ids.has("battle_ding"), "no ding before its time")
	assert_false(red.is_flashing(), "no flash before its time")
	stub.set("virtual_usec", 1499999)
	stage._fire_due_cues()
	assert_eq(stage.pending_cue_count(), 1, "1 microsecond early: still waiting")
	assert_eq(_signal_hits, 0)
	stub.set("virtual_usec", 1500000)
	stage._fire_due_cues()
	assert_eq(stage.pending_cue_count(), 0)
	assert_eq(audio.sfx_ids.count("battle_ding"), 1, "one ding")
	assert_true(red.is_flashing(), "the flash")
	assert_eq(_signal_hits, 1, "cue_fired for the HUD")
	assert_eq(_last_payload[0], "red")
	var markers: int = 0
	for child: Node in red.get_children():
		if child is Sprite3D:
			markers += 1
	assert_eq(markers, 1, "the '!' is over her head")
	stage._fire_due_cues()
	assert_eq(audio.sfx_ids.count("battle_ding"), 1, "a cue fires once")


func test_block_cue_goes_to_the_defender_and_string_presses_fire_one_by_one() -> void:
	var stage: BattleScene = _stage()
	var stub: RefCounted = _stub()
	stub.set("use_virtual_clock", true)
	stub.set("virtual_usec", 5000000)
	_booted(stage, stub)
	var swing: Dictionary = stub.call("make_action", "e1", "attack", ["red"], 400, "red", "block")
	stage._on_action_started(swing)
	stub.set("virtual_usec", 5400000)
	stage._fire_due_cues()
	assert_true(stage.get_view("red").is_flashing(), "the defender flashes")
	assert_false(stage.get_view("e1").is_flashing(), "not the attacker")
	var string_action: Dictionary = stub.call("make_action", "mox", "skill", ["e2"], 300)
	var presses: Array = []
	for i: int in 3:
		presses.append({"index": i, "type": "string", "side": "attack", "cue_ms": 300 + 200 * i, "hold_by_ms": 0, "owner_id": "mox"})
	string_action["presses"] = presses
	string_action["t0_usec"] = 5400000
	stage._on_action_started(string_action)
	assert_eq(stage.pending_cue_count(), 3)
	var audio: FakeAudio = stage.audio as FakeAudio
	var dings_before: int = audio.sfx_ids.count("battle_ding")
	stub.set("virtual_usec", 5700000)
	stage._fire_due_cues()
	assert_eq(audio.sfx_ids.count("battle_ding") - dings_before, 1, "first stamp")
	stub.set("virtual_usec", 6100000)
	stage._fire_due_cues()
	assert_eq(audio.sfx_ids.count("battle_ding") - dings_before, 3, "the other two")
	assert_eq(stage.pending_cue_count(), 0)


func test_a_scrambled_cue_flashes_at_the_shown_time_not_the_real_one() -> void:
	var stage: BattleScene = _stage()
	var stub: RefCounted = _stub()
	stub.set("use_virtual_clock", true)
	stub.set("virtual_usec", 2000000)
	_booted(stage, stub)
	var action: Dictionary = stub.call("make_action", "e1", "attack", ["red"], 800, "red", "block")
	(action["presses"] as Array)[0]["scrambled"] = true
	(action["presses"] as Array)[0]["shown_cue_ms"] = 500
	stage._on_action_started(action)
	stub.set("virtual_usec", 2500000)
	stage._fire_due_cues()
	assert_true(stage.get_view("red").is_flashing(), "the fake cue shows at the shown time")
	assert_eq(stage.pending_cue_count(), 0)


func test_cue_marker_can_be_left_to_the_hud() -> void:
	var stage: BattleScene = _stage()
	stage.cue_marker_enabled = false
	var stub: RefCounted = _stub()
	stub.set("use_virtual_clock", true)
	stub.set("virtual_usec", 100)
	_booted(stage, stub)
	stage._on_action_started(stub.call("make_action", "red", "attack", ["e1"], 10))
	stub.set("virtual_usec", 20000)
	stage._fire_due_cues()
	var markers: int = 0
	for child: Node in stage.get_view("red").get_children():
		if child is Sprite3D:
			markers += 1
	assert_eq(markers, 0, "no '!' drawn by the stage")
	assert_true((stage.audio as FakeAudio).sfx_ids.has("battle_ding"), "the flash and ding still fire")


# ---- Clutch input ----

func test_clutch_input_is_forwarded_with_the_cue_clock() -> void:
	var stage: BattleScene = _stage()
	var stub: RefCounted = _stub()
	stub.set("use_virtual_clock", true)
	stub.set("virtual_usec", 777000)
	_booted(stage, stub)
	stage.handle_input_event(_press(&"clutch", true))
	stub.set("virtual_usec", 777350)
	stage.handle_input_event(_press(&"clutch", false))
	stage.handle_input_event(_press(&"confirm", true))
	assert_eq(stub.get("downs"), [777000], "press_down got the timestamp")
	assert_eq(stub.get("ups"), [777350], "press_up got the timestamp")


func test_clutch_in_a_sub_viewport_arrives_through_the_relay() -> void:
	var container: SubViewport = SubViewport.new()
	add_to_root(container)
	var stage: BattleScene = (load(SCENE) as PackedScene).instantiate() as BattleScene
	stage.transitions_enabled = false
	stage.audio = FakeAudio.new()
	container.add_child(stage)
	var stub: RefCounted = _stub()
	stage.attach_controller(stub)
	await tree.process_frame
	var relay: Node = tree.root.get_node_or_null("ClutchRelay")
	assert_not_null(relay, "the world viewport gets no input, so a relay listens in the root window")
	Input.parse_input_event(_press(&"clutch", true))
	await tree.process_frame
	await tree.process_frame
	assert_eq((stub.get("downs") as Array).size(), 1, "the press reached the controller")
	Input.parse_input_event(_press(&"clutch", false))
	await tree.process_frame
	await tree.process_frame
	assert_eq((stub.get("ups") as Array).size(), 1)
	container.remove_child(stage)
	stage.free()
	await tree.process_frame
	assert_null(tree.root.get_node_or_null("ClutchRelay"), "and it is gone with the stage")


# ---- hits, shake, block, heal ----

func test_totally_rad_hit_shakes_the_screen_and_recoils_the_target() -> void:
	var stage: BattleScene = _stage()
	var stub: RefCounted = _stub()
	_booted(stage, stub)
	var audio: FakeAudio = stage.audio as FakeAudio
	_signal_hits = 0
	stage.shook.connect(_count)
	stage._on_action_started(stub.call("make_action", "red", "attack", ["e1"]))
	stage._on_press_judged({"actor": "red", "index": 0, "side": "attack", "rating": "totally_rad", "delta_ms": 3})
	stage._on_hit({"source": "red", "target": "e1", "amount": 20, "kind": "damage", "blocked": "none", "payback": false})
	assert_eq(_signal_hits, 1, "TOTALLY RAD shakes")
	assert_true(stage.camera_rig.is_shaking())
	assert_true(audio.sfx_ids.has("battle_hit_big"))
	var target: CombatantView = stage.get_view("e1")
	assert_true(target.is_flashing(), "white hit flash")
	assert_eq(target.face_column(), 1, "the grunt makes its ouch face")
	await tree.create_timer(0.1).timeout
	assert_gt(target.position.distance_to(target.home_position), 0.05, "knocked back")
	await _wait_until(func() -> bool: return target.position.distance_to(target.home_position) < 0.02 and not stage.is_frozen())
	assert_lt(target.position.distance_to(target.home_position), 0.05, "and back on its spot")


func test_a_plain_hit_does_not_shake() -> void:
	var stage: BattleScene = _stage()
	var stub: RefCounted = _stub()
	_booted(stage, stub)
	stage._on_press_judged({"actor": "red", "index": 0, "side": "attack", "rating": "nice", "delta_ms": 60})
	stage._on_hit({"source": "red", "target": "e1", "amount": 4, "kind": "damage", "blocked": "none", "payback": false})
	assert_false(stage.camera_rig.is_shaking())
	assert_true((stage.audio as FakeAudio).sfx_ids.has("battle_hit"))
	assert_false((stage.audio as FakeAudio).sfx_ids.has("battle_hit_big"))


func test_block_perfect_block_payback_and_heal_sounds() -> void:
	var stage: BattleScene = _stage()
	var stub: RefCounted = _stub()
	_booted(stage, stub)
	var audio: FakeAudio = stage.audio as FakeAudio
	stage._on_hit({"source": "e1", "target": "red", "amount": 5, "kind": "damage", "blocked": "partial", "payback": false})
	assert_true(audio.sfx_ids.has("battle_block"))
	stage._on_hit({"source": "e1", "target": "red", "amount": 0, "kind": "damage", "blocked": "perfect", "payback": false})
	assert_true(audio.sfx_ids.has("battle_perfect_block"))
	assert_false(audio.sfx_ids.has("battle_payback"), "no payback yet")
	stage._on_hit({"source": "red", "target": "e1", "amount": 9, "kind": "damage", "blocked": "none", "payback": true})
	assert_true(audio.sfx_ids.has("battle_payback"), "the free counter after a perfect block")
	assert_true(stage.get_view("e1").is_flashing(), "and the grunt takes it")
	stage._on_hit({"source": "otis", "target": "red", "amount": 20, "kind": "heal", "blocked": "none", "payback": false})
	assert_true(audio.sfx_ids.has("battle_heal"))


func test_lunge_goes_to_the_target_and_comes_home() -> void:
	var stage: BattleScene = _stage()
	var stub: RefCounted = _stub()
	_booted(stage, stub)
	var red: CombatantView = stage.get_view("red")
	var e1: CombatantView = stage.get_view("e1")
	var action: Dictionary = stub.call("make_action", "red", "attack", ["e1"], 200, "red", "attack", 120, 300, 500)
	stage._on_action_started(action)
	await _wait_until(func() -> bool: return red.position.distance_to(e1.home_position) < 1.6)
	assert_lt(red.position.distance_to(e1.home_position), 1.6, "she dashed in on the first grunt")
	stage._on_action_finished(action)
	await _wait_until(func() -> bool: return red.position.distance_to(red.home_position) < 0.02)
	assert_lt(red.position.distance_to(red.home_position), 0.05, "and went home")
	assert_lt(absf(red.pivot.scale.x - 1.0), 0.05, "squash settles")


func test_action_styles_come_from_data() -> void:
	var stage: BattleScene = _stage()
	assert_eq(stage.style_for({"kind": "attack"}), "lunge")
	assert_eq(stage.style_for({"kind": "skill", "anim": "porch_light"}), "cast")
	assert_eq(stage.style_for({"kind": "defend"}), "defend")
	assert_eq(stage.style_for({"kind": "item"}), "item")
	assert_eq(stage.style_for({"kind": "run"}), "none")


func test_defend_pose_holds_until_the_next_turn() -> void:
	var stage: BattleScene = _stage()
	var stub: RefCounted = _stub()
	_booted(stage, stub)
	var mox: CombatantView = stage.get_view("mox")
	var action: Dictionary = stub.call("make_action", "mox", "defend", [])
	action["presses"] = []
	stage._on_action_started(action)
	await tree.create_timer(0.3).timeout
	assert_lt(mox.pivot.scale.y, 0.9, "crouched")
	stage._on_action_finished(action)
	await tree.create_timer(0.3).timeout
	assert_lt(mox.pivot.scale.y, 0.9, "still braced after the action ends")
	stage._on_turn_started("mox")
	await _wait_until(func() -> bool: return mox.pivot.scale.y > 0.95)
	assert_gt(mox.pivot.scale.y, 0.95, "back to normal on her next turn")


# ---- down, K.O. beat, white flag ----

func test_ko_beat_freezes_the_last_hit_once() -> void:
	var stage: BattleScene = _stage()
	stage.tuning = _fast_tuning()
	var stub: RefCounted = _stub()
	_booted(stage, stub)
	_signal_hits = 0
	stage.ko_beat_started.connect(_count)
	stage._on_combatant_down("e1")
	stage._on_combatant_down("e2")
	stage._on_combatant_down("e3")
	assert_eq(_signal_hits, 0, "not the last one")
	assert_false(stage.ko_beat_done)
	stage._on_combatant_down("e4")
	assert_eq(_signal_hits, 1, "the beat starts on the last one")
	assert_eq(_last_payload[0], "e4")
	assert_true(stage.is_frozen(), "everything is frozen")
	assert_true(stage.get_view("red").is_frozen())
	if stage.hud == null:
		assert_true((stage.audio as FakeAudio).sfx_ids.has("battle_ko"), "the stage plays the K.O. sound when there is no HUD to do it")
	else:
		assert_false((stage.audio as FakeAudio).sfx_ids.has("battle_ko"), "with a HUD, its K.O.! plays the sound (no double)")
	await _wait_until(func() -> bool: return not stage.is_frozen())
	assert_false(stage.is_frozen(), "and it lets go after a beat")
	await _wait_until(func() -> bool: return stage.get_view("e4").down)
	assert_true(stage.get_view("e4").down, "then the last enemy falls over")
	var done: Array = []
	stage.finished.connect(func(result: String, report: Dictionary) -> void: done.append(result))
	stage._on_battle_ended("win", {"final_ko_target": "e4", "xp": 1})
	assert_eq(_signal_hits, 1, "battle_ended does not repeat the beat")
	await _wait_for_finish(stage, done)


func test_battle_ended_plays_the_ko_beat_when_no_down_signal_came() -> void:
	var stage: BattleScene = _stage()
	stage.tuning = _fast_tuning()
	var stub: RefCounted = _stub()
	_booted(stage, stub)
	_signal_hits = 0
	stage.ko_beat_started.connect(_count)
	var done: Array = []
	stage.finished.connect(func(result: String, report: Dictionary) -> void: done.append(result))
	stage._on_battle_ended("win", {"final_ko_target": "e2", "xp": 1})
	assert_eq(_signal_hits, 1)
	assert_eq(_last_payload[0], "e2")
	await _wait_for_finish(stage, done)


func test_party_down_falls_over_and_revive_stands_up() -> void:
	var stage: BattleScene = _stage()
	stage.tuning = _fast_tuning()
	var stub: RefCounted = _stub()
	_booted(stage, stub)
	var mox: CombatantView = stage.get_view("mox")
	stage._on_combatant_down("mox")
	assert_false(stage.is_frozen(), "no K.O. beat for a party member")
	await _wait_until(func() -> bool: return absf(mox.pivot.rotation.x) > 1.2)
	assert_gt(absf(mox.pivot.rotation.x), 1.2, "lying down")
	assert_true(mox.down)
	stage._on_combatant_revived("mox")
	await _wait_until(func() -> bool: return absf(mox.pivot.rotation.x) < 0.05)
	assert_false(mox.down)
	assert_lt(absf(mox.pivot.rotation.x), 0.05, "standing again")


func test_grunt_raises_a_white_flag_and_walks_off() -> void:
	var stage: BattleScene = _stage()
	stage.tuning = _fast_tuning()
	var stub: RefCounted = _stub()
	_booted(stage, stub)
	var grunt: CombatantView = stage.get_view("e1")
	assert_true(grunt.has_flag, "the grunt carries a white flag")
	var flag: Node3D = grunt.model.find_children("*_prop_flag*", "Node3D", true, false)[0] as Node3D
	assert_false(flag.visible, "hidden until it gives up")
	var arm: int = grunt.skeleton.find_bone("upper_arm_r")
	var rest: Quaternion = grunt.skeleton.get_bone_pose_rotation(arm)
	stage._on_combatant_fled("e1")
	assert_true(flag.visible, "flag out")
	await _wait_until(func() -> bool: return grunt.skeleton.get_bone_pose_rotation(arm).angle_to(rest) > 1.5)
	assert_gt(grunt.skeleton.get_bone_pose_rotation(arm).angle_to(rest), 1.5, "the arm is up")
	assert_true((stage.audio as FakeAudio).sfx_ids.has("battle_flee"))
	await _wait_until(func() -> bool: return grunt.gone)
	assert_true(grunt.gone, "and it walked away")
	assert_false(grunt.visible)


func test_a_drone_without_a_flag_just_zips_away() -> void:
	var stage: BattleScene = _stage()
	stage.tuning = _fast_tuning()
	var stub: RefCounted = _stub()
	_booted(stage, stub)
	var drone: CombatantView = stage.get_view("e2")
	assert_false(drone.has_flag)
	assert_true(drone.is_flyer(), "the drone hovers")
	assert_false(stage.get_view("e1").is_flyer(), "the grunt does not")
	stage._on_combatant_fled("e2")
	await _wait_until(func() -> bool: return drone.gone)
	assert_true(drone.gone)


func test_flyer_ko_crashes_and_enemies_blink_out() -> void:
	var stage: BattleScene = _stage()
	stage.tuning = _fast_tuning()
	var stub: RefCounted = _stub()
	_booted(stage, stub)
	var drone: CombatantView = stage.get_view("e2")
	var start_y: float = drone.pivot.position.y
	stage._on_combatant_down("e2")
	await _wait_until(func() -> bool: return drone.pivot.position.y < start_y - 0.5)
	assert_lt(drone.pivot.position.y, start_y - 0.5, "it dropped to the floor")
	await _wait_until(func() -> bool: return drone.gone)
	assert_true(drone.gone, "then it blinks out")
	await tree.process_frame
	assert_false(stage.slot_marker("enemy", 1).get_node("Ring").visible, "and its ring goes with it")


# ---- start to finish ----

func test_start_battle_builds_the_controller_starts_it_and_finishes() -> void:
	var stage: BattleScene = _stage()
	stage.tuning = _fast_tuning()
	var stub_holder: Array[RefCounted] = []
	stage.controller_factory = func(_setup: RefCounted) -> Object:
		var made: RefCounted = _stub()
		stub_holder.append(made)
		return made
	_signal_hits = 0
	stage.intro_finished.connect(_count)
	var done: Array = []
	stage.finished.connect(func(result: String, report: Dictionary) -> void: done.append([result, report]))
	await stage.start_battle(RefCounted.new())
	assert_eq(stub_holder.size(), 1, "built through the factory")
	assert_true(stub_holder[0].get("started"), "the fight was started")
	assert_eq(_signal_hits, 1, "intro finished")
	assert_eq(stage.views.size(), 7)
	stub_holder[0].emit_signal("battle_ended", "win", {"xp": 12, "final_ko_target": "e4"})
	await _wait_for_finish(stage, done)
	assert_eq(done.size(), 1, "finished comes once")
	assert_eq(done[0][0], "win")
	assert_eq(done[0][1]["xp"], 12, "with the report")
	if stage.hud != null:
		assert_eq(done[0][1]["choice"], "continue", "and what the player picked on the HUD's end screen")


func test_static_transition_plays_in_and_out() -> void:
	var stage: BattleScene = _stage()
	stage.transitions_enabled = true
	stage.tuning = _fast_tuning()
	stage.static_layer.configure(stage.tuning)
	var audio: FakeAudio = stage.audio as FakeAudio
	stage.controller_factory = func(_setup: RefCounted) -> Object:
		return _stub()
	var done: Array = []
	stage.finished.connect(func(result: String, report: Dictionary) -> void: done.append(result))
	await stage.start_battle(RefCounted.new())
	assert_true(audio.sfx_ids.has("battle_static_in"))
	assert_almost_eq(stage.static_layer.progress, 0.0, 0.001, "the picture is clear after the static-in")
	stage.controller.emit_signal("battle_ended", "lose", {})
	await _wait_for_finish(stage, done)
	assert_eq(done, ["lose"])
	assert_almost_eq(stage.static_layer.progress, 1.0, 0.001, "the screen is covered when finished is emitted")
	assert_true(audio.sfx_ids.has("battle_static_out"))


func test_static_layer_covers_reveals_and_boss_runs_longer() -> void:
	var stage: BattleScene = _stage()
	stage.tuning = _fast_tuning()
	var layer: BattleStatic = stage.static_layer
	layer.configure(stage.tuning)
	var normal_in: float = layer.duration_ms(true)
	layer.set_boss(true)
	assert_gt(layer.duration_ms(true), normal_in, "boss in is longer")
	assert_gt(layer.hold_ms(), 0.0)
	layer.set_boss(false)
	layer.set_progress(0.0)
	assert_false(layer.get_child(0).visible, "clear: nothing drawn")
	layer.set_progress(1.0)
	assert_true(layer.get_child(0).visible)
	assert_eq(layer.get_static_material().shader.resource_path, "res://shaders/screen_static.gdshader")
	layer.set_progress(0.3)
	assert_almost_eq(layer.progress, 0.25, 0.0001, "progress snaps to stepped levels")
	await layer.cover(40.0)
	assert_almost_eq(layer.progress, 1.0, 0.0001)
	await layer.reveal(40.0)
	assert_almost_eq(layer.progress, 0.0, 0.0001)


func test_running_away_sends_the_party_off() -> void:
	var stage: BattleScene = _stage()
	stage.tuning = _fast_tuning()
	var stub: RefCounted = _stub()
	_booted(stage, stub)
	var done: Array = []
	stage.finished.connect(func(result: String, report: Dictionary) -> void: done.append(result))
	stage._on_battle_ended("ran", {})
	await _wait_until(func() -> bool: return stage.get_view("red").gone)
	assert_true(stage.get_view("red").gone, "Red ran off")
	assert_false(stage.get_view("e1").gone, "the enemies stay")
	await _wait_for_finish(stage, done)
	assert_eq(done, ["ran"])


func test_a_boss_telegraph_pushes_the_camera_in_and_the_boss_bubble_is_bigger() -> void:
	var stage: BattleScene = _stage()
	stage.tuning = _fast_tuning()
	var stub: RefCounted = _stub()
	stub.set("use_virtual_clock", true)
	stub.set("virtual_usec", 900000)
	stub.set("boss_id", "e1")
	_booted(stage, stub)
	assert_true(stage.get_view("e1").is_boss)
	var short: Dictionary = stub.call("make_action", "e1", "attack", ["red"], 200, "red", "block", 300, 500, 700)
	stage._on_action_started(short)
	assert_false(stage.camera_rig.is_pushing(), "a quick boss attack does not push in")
	var tell: Dictionary = stub.call("make_action", "e1", "attack", ["red"], 1200, "red", "block", 1000, 1300, 1600)
	stage._on_action_started(tell)
	assert_true(stage.camera_rig.is_pushing(), "a long boss wind-up pushes the camera in")
	stub.set("virtual_usec", 900000 + 1300000)
	stage._fire_due_cues()
	var bubble: Sprite3D = null
	for child: Node in stage.get_view("red").get_children():
		if child is Sprite3D:
			bubble = child as Sprite3D
	assert_not_null(bubble, "the cue still goes to the defender")


func test_stage_works_without_a_hud_scene() -> void:
	var stage: BattleScene = _stage()
	var stub: RefCounted = _stub()
	_booted(stage, stub)
	if not ResourceLoader.exists(BattleScene.HUD_PATH):
		assert_null(stage.hud, "no HUD scene yet: the stage just runs without it")
	else:
		assert_not_null(stage.hud, "the HUD scene exists, so it was instanced and bound")
	assert_eq(stage.views.size(), 7)


func test_full_demo_fight_runs_without_errors() -> void:
	var stage: BattleScene = _stage()
	stage.tuning = _fast_tuning()
	var stub: RefCounted = _stub()
	stub.set("instant", false)
	stub.set("tree", tree)
	stub.set("enemy_count", 2)
	stage.attach_controller(stub)
	var done: Array = []
	stage.finished.connect(func(result: String, report: Dictionary) -> void: done.append(result))
	stub.call("run_demo_fight")
	var finished_ok: bool = await _wait_for_finish(stage, done, 12.0)
	assert_true(finished_ok, "the demo fight reaches finished")
	assert_eq(done, ["win"])
	assert_true(stage.ko_beat_done)
