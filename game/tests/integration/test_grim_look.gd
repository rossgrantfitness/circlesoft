extends TestCase
## The grim look test (2026-10-08): the code-painted grime, the reusable props, the room dressing that turns on
## and off with the look profile, the battle set, the character dulling and the F11 switch. Classic must always
## come back exactly as it was. Needs the project imported once: godot --headless --path game --import

const SQUARE: String = "res://scenes/rooms/harrow/harrow_square.tscn"
const CHECKPOINT: String = "res://scenes/rooms/harrow/harrow_checkpoint.tscn"
const BAR: String = "res://scenes/rooms/harrow/harrow_bar.tscn"
const HOME: String = "res://scenes/rooms/harrow/harrow_home.tscn"
const COURIER: String = "res://scenes/rooms/harrow/harrow_courier.tscn"
const STORE: String = "res://scenes/rooms/harrow/harrow_store.tscn"
const GEAR: String = "res://scenes/rooms/harrow/harrow_gear.tscn"
const OFFICE: String = "res://scenes/rooms/harrow/harrow_dock_office.tscn"
const DOCKS: String = "res://scenes/rooms/harrow/harrow_docks.tscn"
const ROAD: String = "res://scenes/rooms/road/road_mast_road.tscn"
const TEST_ROOM: String = "res://scenes/debug/psx_test_room.tscn"
const TEST_A: String = "res://scenes/rooms/test_a.tscn"
const TEST_B: String = "res://scenes/rooms/test_b.tscn"
const RED_CLASSIC: String = "res://art/placeholder/characters/red/red_shiba.glb"
const RED_GRIM: String = "res://art/placeholder/characters/red/red_shiba_grim.glb"
const BATTLE: String = "res://scenes/battle/battle_scene.tscn"
const DRESSING_DATA: String = "world/look_dressing"
const OTIS: String = "res://art/placeholder/characters/otis/chr_otis.glb"
const LIT_SHADER: String = "res://shaders/psx_lit.gdshader"
const CHECKER: String = "res://art/placeholder/textures/checker_64.png"
const MIN_TEXTURE_PX: int = 8
const MAX_TEXTURE_PX: int = 256
const PROP_TRIANGLE_CAP: int = 400
## The dressing a look-test scene adds on top of the room's own triangles (outdoor area target 4000, cap 6000).
const DRESSING_TRIANGLE_CAP: int = 3500
const TICK: float = 1.0 / 60.0

const MINIMAL_ITEMS: Dictionary = {
	"poster": {}, "stripes": {}, "barrier": {}, "floodlight": {}, "loudspeaker": {}, "fence": {}, "barbed": {},
	"puddle": {}, "smear": {}, "neon": {"text": "OPEN"}, "screen": {"text": "ALL CLEAR"}, "steam": {}, "cable": {},
	"pipe": {}, "shack": {"lights": ["#ffb347"]}, "skyline": {}, "rain": {}, "hang_lamp": {},
}


func after_each() -> void:
	LookProfiles.reset()


func _tris(node: Node) -> int:
	return GrimProps.triangle_count(node)


func _saturation_of(image: Image) -> float:
	var total: float = 0.0
	var counted: int = 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			var c: Color = image.get_pixel(x, y)
			if c.a > 0.5:
				total += c.s
				counted += 1
	return total / float(maxi(counted, 1))


func _brightness_of(image: Image) -> float:
	var total: float = 0.0
	var counted: int = 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			var c: Color = image.get_pixel(x, y)
			if c.a > 0.5:
				total += c.get_luminance()
				counted += 1
	return total / float(maxi(counted, 1))


# ---- the painting ----

func test_painting_is_deterministic_and_in_the_style_guide_sizes() -> void:
	var grime: Dictionary = LookProfiles.profile("grim")["grime"]
	for kind: String in ["floor", "wall", "panel"]:
		var a: Image = GrimePaint.surface_image(kind, grime)
		var b: Image = GrimePaint.surface_image(kind, grime)
		assert_eq(a.get_data(), b.get_data(), kind + ": same seed, same pixels")
		assert_ge(a.get_width(), 64, kind + " is at least 64 px")
		assert_le(a.get_width(), MAX_TEXTURE_PX)
		assert_eq(a.get_width(), a.get_height())
	for id: String in ["poster_mast", "poster_eye", "poster_ration", "stripes", "fence", "barbed", "puddle", "metal", "grate"]:
		var texture: ImageTexture = GrimePaint.decal_texture(id, grime)
		assert_ge(texture.get_width(), MIN_TEXTURE_PX, id)
		assert_le(texture.get_width(), MAX_TEXTURE_PX, id)
	for step: int in 3:
		assert_le(GrimePaint.steam_texture(step).get_width(), 32)


func test_decals_use_one_bit_alpha() -> void:
	for id: String in ["fence", "barbed", "puddle", "poster_mast"]:
		var image: Image = GrimePaint.decal_texture(id).get_image()
		for y: int in image.get_height():
			for x: int in image.get_width():
				var alpha: float = image.get_pixel(x, y).a
				assert_true(alpha == 0.0 or alpha == 1.0, "%s (%d,%d) alpha %f" % [id, x, y, alpha])


func test_grimed_surfaces_are_darker_and_dirtier_than_clean() -> void:
	var grime: Dictionary = LookProfiles.profile("grim")["grime"]
	var dirty: Image = GrimePaint.surface_image("floor", grime)
	var clean: Image = GrimePaint.surface_image("floor", {"dirt": 0.0, "rust": 0.0, "stain": 0.0})
	assert_lt(_brightness_of(dirty), _brightness_of(clean), "dirt, oil and rust darken the plate")
	assert_ne(dirty.get_data(), clean.get_data())


func test_the_character_dull_pass_drains_darkens_and_kills_gloss() -> void:
	var cfg: Dictionary = LookProfiles.profile("grim")["characters"]
	var source: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	source.fill(Color("#D6382E"))                       # a toy-bright jacket red
	source.set_pixel(3, 3, Color("#EDEAD8"))            # a Chalk gloss spot
	var dull: Image = GrimePaint.dull_character_image(source, cfg)
	assert_lt(_saturation_of(dull), _saturation_of(source) * 0.8, "much less colour")
	assert_lt(_brightness_of(dull), _brightness_of(source), "darker")
	assert_lt(dull.get_pixel(3, 3).get_luminance(), 0.6, "the gloss spot is pulled down: no toy sheen")
	assert_eq(source.get_pixel(3, 3), Color("#EDEAD8"), "the source image was not edited")
	assert_eq(GrimePaint.dull_character_image(source, cfg).get_data(), dull.get_data(), "deterministic")


func test_pixel_font_draws_and_neon_is_lit_text_on_a_dark_plate() -> void:
	var image: Image = Image.create(40, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.BLACK)
	GrimePaint.draw_text(image, "GEAR", 1, 1, Color.WHITE, 1)
	var lit: int = 0
	for y: int in 8:
		for x: int in 40:
			if image.get_pixel(x, y).r > 0.5:
				lit += 1
	assert_gt(lit, 20, "four letters put pixels on the image")
	var neon: Image = GrimePaint.neon_image("BAR", Color("#ff3e9a"))
	assert_gt(neon.get_pixel(5, 4).get_luminance() + neon.get_pixel(6, 5).get_luminance() + neon.get_pixel(7, 4).get_luminance() + neon.get_pixel(6, 6).get_luminance(), 0.0)
	assert_lt(neon.get_pixel(1, neon.get_height() - 2).get_luminance(), 0.2, "the plate behind the tubes is dark")


# ---- the props ----

func test_every_prop_type_builds_cheaply_and_has_no_collision() -> void:
	for type: String in GrimProps.TYPES:
		assert_true(MINIMAL_ITEMS.has(type), "the test knows " + type)
		var item: Dictionary = (MINIMAL_ITEMS[type] as Dictionary).duplicate()
		item["type"] = type
		var prop: Node3D = GrimProps.build(item, LookProfiles.profile("grim")["grime"])
		assert_not_null(prop, type + " builds")
		if prop == null:
			continue
		own(prop)
		assert_le(_tris(prop), PROP_TRIANGLE_CAP, "%s stays cheap (%d tris)" % [type, _tris(prop)])
		assert_eq(prop.find_children("*", "CollisionObject3D", true, false).size(), 0, type + " is visual only")
		assert_eq(prop.find_children("*", "CollisionShape3D", true, false).size(), 0)


func test_unknown_prop_types_are_skipped_not_crashed() -> void:
	assert_null(GrimProps.build({"type": "no_such_prop"}))


func test_prop_materials_use_the_psx_shaders_with_nearest_textures() -> void:
	var prop: Node3D = own(GrimProps.build({"type": "poster", "variant": 1})) as Node3D
	for node: Node in prop.find_children("*", "MeshInstance3D", true, false):
		var material: ShaderMaterial = (node as MeshInstance3D).get_surface_override_material(0) as ShaderMaterial
		assert_not_null(material)
		assert_eq(material.shader.resource_path, LIT_SHADER)
		assert_not_null(material.get_shader_parameter("albedo_texture"))


func test_neon_flickers_in_steps_and_the_screen_cycles_frames() -> void:
	var neon: Node3D = own(GrimProps.build({"type": "neon", "text": "BAR", "pattern": "1h0", "fps": 10.0})) as Node3D
	add_to_root(neon)
	var anim: GrimPropAnim = neon.get_node("Flicker") as GrimPropAnim
	var levels: Array[float] = []
	for i: int in 3:
		anim.advance(1)
		levels.append(anim.current_value())
	assert_eq(levels.size(), 3)
	assert_ne(levels[0], levels[1], "the sign changes between steps")
	assert_ne(levels[1], levels[2])
	assert_gt(levels.max(), levels.min() * 2.0, "on is much brighter than off")
	var screen: Node3D = own(GrimProps.build({"type": "screen", "text": "ALL CLEAR"})) as Node3D
	add_to_root(screen)
	var frames: GrimPropAnim = screen.get_node("Frames") as GrimPropAnim
	var seen: Dictionary = {}
	for i: int in 12:
		frames.advance(1)
		seen[frames.current_value()] = true
	assert_ge(seen.size(), 2, "the screen shows more than one frame")


func test_steam_puffs_rise_and_reset() -> void:
	var vent: Node3D = own(GrimProps.build({"type": "steam"})) as Node3D
	add_to_root(vent)
	var anim: GrimPropAnim = vent.get_node("Steam") as GrimPropAnim
	assert_eq(anim.puffs.size(), 3)
	var heights: Array[float] = []
	for i: int in 6:
		anim.advance(1)
		heights.append(anim.current_value())
	assert_gt(heights.max(), 0.3, "puffs climb above the vent")
	assert_lt(heights.min(), heights.max(), "and start again low")


func test_the_dressing_data_only_names_real_props_and_stays_inside_the_budget() -> void:
	var rooms: Dictionary = DataDB.get_dict(DRESSING_DATA)["rooms"]
	for id: String in ["harrow_square", "harrow_checkpoint", "battle"]:
		assert_true(rooms.has(id), id + " has dressing")
		var tris: int = 0
		var holder: Node3D = Node3D.new()
		own(holder)
		var types: Dictionary = {}
		for entry: Variant in (rooms[id] as Dictionary)["items"]:
			var item: Dictionary = entry
			assert_true(GrimProps.TYPES.has(str(item["type"])), "%s: %s is a known prop" % [id, item["type"]])
			types[str(item["type"])] = true
			var prop: Node3D = GrimProps.build(item, LookProfiles.profile("grim")["grime"])
			if prop != null:
				holder.add_child(prop)
		tris = _tris(holder)
		assert_le(tris, DRESSING_TRIANGLE_CAP, "%s dressing is %d triangles" % [id, tris])
		for needed: String in ["poster", "floodlight", "loudspeaker", "stripes", "puddle", "fence", "barbed", "neon", "screen", "steam", "cable", "pipe", "shack", "rain"]:
			assert_true(types.has(needed), "%s uses %s (cheap props reused across rooms)" % [id, needed])


# ---- a room's dressing ----

func _plain_room() -> Node3D:
	var host: Node3D = Node3D.new()
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	floor_mesh.name = "Floor"
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(4.0, 4.0)
	floor_mesh.mesh = plane
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load(LIT_SHADER) as Shader
	material.set_shader_parameter("albedo_texture", load(CHECKER))
	material.set_shader_parameter("albedo_tint", Color(0.9, 0.5, 0.2, 1.0))
	floor_mesh.set_surface_override_material(0, material)
	host.add_child(floor_mesh)
	var dressing: GrimDressing = GrimDressing.new()
	dressing.name = "GrimDressing"
	dressing.config = {"items": [{"type": "poster", "pos": [1.0, 1.0, 0.0]}, {"type": "puddle", "pos": [0.0, 0.0, 1.0]}]}
	host.add_child(dressing)
	return host


func test_dressing_turns_on_with_grim_and_restores_classic_exactly() -> void:
	LookProfiles.apply("classic")
	var host: Node3D = _plain_room()
	add_to_root(host)
	var dressing: GrimDressing = host.get_node("GrimDressing") as GrimDressing
	var floor_mesh: MeshInstance3D = host.get_node("Floor") as MeshInstance3D
	var original: ShaderMaterial = floor_mesh.get_surface_override_material(0) as ShaderMaterial
	var original_tint: Color = original.get_shader_parameter("albedo_tint")
	assert_false(dressing.is_on, "classic: no dressing")
	assert_null(dressing.props_root, "and nothing built")
	LookProfiles.apply("grim")
	assert_true(dressing.is_on)
	assert_eq(dressing.prop_count, 2)
	assert_true(dressing.props_root.visible)
	var grimed: ShaderMaterial = floor_mesh.get_surface_override_material(0) as ShaderMaterial
	assert_ne(grimed, original, "the floor got its own grimed copy")
	assert_ne(grimed.get_shader_parameter("albedo_texture"), original.get_shader_parameter("albedo_texture"), "painted grime instead of the checker")
	var grimed_tint: Color = grimed.get_shader_parameter("albedo_tint")
	assert_lt(grimed_tint.s, original_tint.s, "the tint is drained")
	assert_eq(original.get_shader_parameter("albedo_tint"), original_tint, "the shared original material was never edited")
	LookProfiles.apply("classic")
	assert_false(dressing.is_on)
	assert_false(dressing.props_root.visible, "props hidden")
	assert_eq(floor_mesh.get_surface_override_material(0), original, "the original material is back")
	LookProfiles.apply("grim")
	assert_true(dressing.props_root.visible, "and it can come back")
	assert_eq(dressing.prop_count, 2, "props are built once")


func test_dressing_leaves_characters_alone() -> void:
	var host: Node3D = _plain_room()
	var body: PlayerController = PlayerController.new()
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	var own_material: ShaderMaterial = ShaderMaterial.new()
	own_material.shader = load(LIT_SHADER) as Shader
	mesh.set_surface_override_material(0, own_material)
	body.add_child(mesh)
	host.add_child(body)
	add_to_root(host)
	LookProfiles.apply("grim")
	assert_eq(mesh.get_surface_override_material(0), own_material, "a character mesh keeps its material")


func test_every_room_is_grim_and_dressed_by_default() -> void:
	var rooms: Array[String] = [SQUARE, CHECKPOINT, BAR, HOME, COURIER, STORE, GEAR, OFFICE, DOCKS, ROAD, TEST_ROOM, TEST_A, TEST_B]
	for path: String in rooms:
		var room: Node = (load(path) as PackedScene).instantiate()
		add_to_root(room)
		var dressing: GrimDressing = room.get_node_or_null("GrimDressing") as GrimDressing
		assert_not_null(dressing, path + " carries a GrimDressing node")
		if dressing == null:
			continue
		assert_true(dressing.is_on, path + " starts grim")
		assert_gt(dressing.prop_count, 12, path + " has its props")
		assert_le(_tris(dressing.props_root), DRESSING_TRIANGLE_CAP, path + " dressing stays cheap (%d tris)" % _tris(dressing.props_root))
		assert_eq(LookProfiles.active_id(), "grim")
		var void_color: Color = (room.get_node("WorldEnvironment") as WorldEnvironment).environment.background_color
		assert_lt(void_color.b, 0.2, path + ": dirty olive fog, not the toy-box night blue")
		room.free()
		LookProfiles.reset()


func test_every_room_in_the_game_data_has_dressing_data() -> void:
	var dressing: Dictionary = DataDB.get_dict(DRESSING_DATA)["rooms"]
	for room_id: Variant in DataDB.get_dict("world/rooms")["rooms"]:
		assert_true(dressing.has(str(room_id)) or str(room_id).begins_with("_"), "%s has grim dressing data" % room_id)
	assert_true(dressing.has("battle"))
	assert_true(dressing.has("test_room"))


func test_f11_classic_strips_a_whole_room_back_to_the_toy_box_and_grim_returns() -> void:
	var room: Node = (load(DOCKS) as PackedScene).instantiate()
	add_to_root(room)
	var dressing: GrimDressing = room.get_node("GrimDressing") as GrimDressing
	assert_true(dressing.is_on)
	LookProfiles.set_forced("classic")
	assert_false(dressing.is_on)
	assert_false(dressing.props_root.visible)
	assert_eq((room.get_node("WorldEnvironment") as WorldEnvironment).environment.background_color, Color(0.12156863, 0.14509805, 0.2509804, 1), "classic night blue")
	LookProfiles.set_forced("grim")
	assert_true(dressing.is_on)
	assert_true(dressing.props_root.visible)


func test_the_room_lights_and_ambient_follow_the_profile_and_return_to_classic() -> void:
	var room: Node = (load(SQUARE) as PackedScene).instantiate()
	add_to_root(room)
	var environment: Environment = (room.get_node("WorldEnvironment") as WorldEnvironment).environment
	var lamp: OmniLight3D = room.get_node("LampLight") as OmniLight3D
	LookProfiles.set_forced("classic")
	var classic_ambient: Color = environment.ambient_light_color
	var classic_energy: float = environment.ambient_light_energy
	assert_eq(classic_energy, 1.0, "the room's own ambient")
	assert_eq(lamp.light_energy, 6.0, "the room's own lamp")
	assert_eq(environment.background_color, Color(0.12156863, 0.14509805, 0.2509804, 1), "night blue void")
	LookProfiles.set_forced("grim")
	assert_ne(environment.ambient_light_color, classic_ambient, "grim ambient is its own color")
	assert_ne(environment.ambient_light_energy, classic_energy)
	assert_ne(environment.background_color, Color(0.12156863, 0.14509805, 0.2509804, 1), "dirty fog color as the void")
	assert_almost_eq(lamp.light_energy, 6.0 * LookProfiles.number("grim", "lighting.point_energy_mul", 1.0), 0.0001)
	LookProfiles.set_forced("classic")
	assert_eq(environment.ambient_light_color, classic_ambient, "back exactly")
	assert_eq(lamp.light_energy, 6.0)
	assert_eq(environment.background_color, Color(0.12156863, 0.14509805, 0.2509804, 1))


func test_the_grim_room_adds_a_hard_key_light_and_classic_has_none_extra() -> void:
	var room: Node = (load(SQUARE) as PackedScene).instantiate()
	add_to_root(room)
	var dressing: GrimDressing = room.get_node("GrimDressing") as GrimDressing
	assert_not_null(dressing.key_light, "the square has a key light")
	assert_true(dressing.key_light.visible)
	assert_false(dressing.key_light.shadow_enabled, "no real-time shadows (style guide)")
	LookProfiles.set_forced("classic")
	assert_false(dressing.props_root.visible, "the key light goes with the props")


# ---- the F11 switch ----

func test_f11_cycles_auto_classic_grim_grim_ps2_and_the_panel_says_so() -> void:
	var event: InputEventKey = null
	var bound: bool = false
	for e: InputEvent in InputMap.action_get_events("debug_look_profile"):
		event = e as InputEventKey
		bound = bound or (event != null and event.physical_keycode == KEY_F11)
	assert_true(bound, "debug_look_profile is bound to F11")
	var overlay: PsxDebugOverlay = PsxDebugOverlay.new()
	add_to_root(overlay)
	var press: InputEventAction = InputEventAction.new()
	press.action = &"debug_look_profile"
	press.pressed = true
	overlay._input(press)
	assert_eq(LookProfiles.forced_id(), "classic")
	assert_has(overlay.build_text(), "F11 Look: Classic")
	overlay._input(press)
	assert_eq(LookProfiles.forced_id(), "grim")
	assert_has(overlay.build_text(), "Grim")
	assert_has(overlay.build_text(), "(forced)")
	overlay._input(press)
	assert_eq(LookProfiles.forced_id(), "grim_ps2", "the PS2 sandbox look is one more press (added 2026-10-08)")
	overlay._input(press)
	assert_eq(LookProfiles.forced_id(), "")
	assert_has(overlay.build_text(), "auto")


# ---- the battle set ----

func _backdrop() -> BattleBackdrop:
	var backdrop: BattleBackdrop = BattleBackdrop.new()
	add_to_root(backdrop)
	return backdrop


func test_battle_set_is_grim_by_default_and_classic_when_forced() -> void:
	var tuning: BattleStageTuning = BattleStageTuning.from_db(DataDB)
	var backdrop: BattleBackdrop = _backdrop()
	backdrop.build(tuning, "harrow")
	assert_eq(backdrop.built_profile, "grim", "a battle is a look-test scene")
	assert_not_null(backdrop.dressing, "with its dressing")
	assert_gt(backdrop.dressing.prop_count, 20)
	assert_eq(backdrop.look["floor_a"], LookProfiles.value("grim", "backdrop.floor_a", ""))
	LookProfiles.set_forced("classic")
	assert_eq(backdrop.built_profile, "classic", "forcing classic rebuilds the set")
	assert_null(backdrop.dressing)
	assert_eq(backdrop.look["floor_a"], "#4A3F46", "the classic floor color is back")
	assert_null(backdrop.get_node_or_null("GrimDressing"))
	LookProfiles.set_forced("grim")
	assert_eq(backdrop.built_profile, "grim")


func test_classic_battle_set_is_byte_for_byte_the_old_one() -> void:
	LookProfiles.set_forced("classic")
	var tuning: BattleStageTuning = BattleStageTuning.from_db(DataDB)
	var backdrop: BattleBackdrop = _backdrop()
	backdrop.build(tuning, "harrow")
	assert_eq(backdrop.look, tuning.backdrop("harrow"))
	var floor_mesh: MeshInstance3D = backdrop.get_node("Floor") as MeshInstance3D
	var material: ShaderMaterial = floor_mesh.get_surface_override_material(0) as ShaderMaterial
	assert_eq(material.get_shader_parameter("albedo_tint"), Color.WHITE)
	assert_eq(material.get_shader_parameter("albedo_texture"), BattleTextures.floor_texture(backdrop.look))


func test_the_battle_set_fits_the_room_triangle_budget_in_both_looks() -> void:
	var tuning: BattleStageTuning = BattleStageTuning.from_db(DataDB)
	var backdrop: BattleBackdrop = _backdrop()
	LookProfiles.set_forced("classic")
	backdrop.build(tuning, "harrow")
	var classic: int = backdrop.triangle_count()
	LookProfiles.set_forced("grim")
	var grim: int = backdrop.triangle_count()
	assert_gt(grim, classic, "grim adds props")
	assert_le(grim, 6000, "still under the outdoor cap (%d)" % grim)


# ---- characters ----

func _first_texture(model: Node) -> Texture2D:
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		var material: ShaderMaterial = mesh_instance.get_active_material(0) as ShaderMaterial
		if material != null and material.get_shader_parameter("albedo_texture") is Texture2D:
			return material.get_shader_parameter("albedo_texture") as Texture2D
	return null


func test_otis_gets_a_dull_matte_scuffed_texture_in_grim_without_remodeling() -> void:
	LookProfiles.apply("classic")
	var classic_model: Node3D = (load(OTIS) as PackedScene).instantiate() as Node3D
	own(classic_model)
	var before: Texture2D = _first_texture(classic_model)
	LookProfiles.dress_model(classic_model, OTIS, "party")
	assert_eq(_first_texture(classic_model), before, "classic: untouched")
	LookProfiles.apply("grim")
	var model: Node3D = (load(OTIS) as PackedScene).instantiate() as Node3D
	own(model)
	var source: Image = _first_texture(model).get_image()
	LookProfiles.dress_model(model, OTIS, "party")
	var after: Texture2D = _first_texture(model)
	assert_ne(after, before)
	assert_eq(after.get_size(), before.get_size(), "same texture size")
	assert_lt(_saturation_of(after.get_image()), _saturation_of(source) * 0.85, "duller")
	assert_lt(_brightness_of(after.get_image()), _brightness_of(source), "darker")
	assert_eq(_tris(model), _tris((load(OTIS) as PackedScene).instantiate()), "no remodeling: the mesh is the same")
	var pristine: Node3D = (load(OTIS) as PackedScene).instantiate() as Node3D
	own(pristine)
	assert_eq(_first_texture(pristine), before, "the shared model resource was not changed")


func test_red_in_the_field_is_the_grim_shiba_by_default_and_f11_swaps_her_live() -> void:
	var player: PlayerController = (load("res://scenes/actors/player.tscn") as PackedScene).instantiate() as PlayerController
	add_to_root(player)
	assert_eq(player.model_path, RED_GRIM, "player.tscn names the grim shiba")
	assert_eq(player.get_node("Visual/Model").scene_file_path, RED_GRIM)
	LookProfiles.set_forced("classic")
	assert_eq(player.get_node("Visual/Model").scene_file_path, RED_CLASSIC, "F11 swaps the classic shiba in")
	assert_eq(player.get_current_animation(), &"idle")
	assert_null(player.get_node_or_null("RedLamp"), "and her lamp light goes with the grim look")
	LookProfiles.set_forced("grim")
	assert_eq(player.get_node("Visual/Model").scene_file_path, RED_GRIM)
	assert_not_null(player.get_node_or_null("RedLamp"))


# ---- the readability pass: edge light and brightness on characters and enemies ----

func _rim_of(model: Node) -> Array[float]:
	var found: Array[float] = []
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		for surface: int in mesh_instance.mesh.get_surface_count():
			var material: ShaderMaterial = mesh_instance.get_active_material(surface) as ShaderMaterial
			if material != null:
				var strength: Variant = material.get_shader_parameter("rim_strength")
				found.append(float(strength) if strength != null else 0.0)
	return found


func test_the_grim_red_gets_the_edge_light_but_not_a_repaint() -> void:
	var packed: PackedScene = load(RED_GRIM) as PackedScene
	var plain: Node3D = packed.instantiate() as Node3D
	own(plain)
	var source: Texture2D = _first_texture(plain)
	var dressed: Node3D = packed.instantiate() as Node3D
	own(dressed)
	LookProfiles.dress_model(dressed, RED_GRIM, "party")
	assert_eq(_first_texture(dressed), source, "already painted dull: the texture is left alone")
	for strength: float in _rim_of(dressed):
		assert_gt(strength, 0.2, "every surface has the edge light")
	for strength: float in _rim_of(plain):
		assert_eq(strength, 0.0, "the shared model resource has none")
	var body: MeshInstance3D = dressed.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var tint: Color = (body.get_active_material(0) as ShaderMaterial).get_shader_parameter("albedo_tint")
	assert_gt(tint.r, 1.0, "lifted so she reads against the dark floor")
	assert_lt(tint.r, 1.6, "but not glowing")


func test_party_and_enemy_edge_lights_differ_and_classic_has_none() -> void:
	var packed: PackedScene = load(OTIS) as PackedScene
	var party: Node3D = packed.instantiate() as Node3D
	var enemy: Node3D = packed.instantiate() as Node3D
	var untouched: Node3D = packed.instantiate() as Node3D
	own(party)
	own(enemy)
	own(untouched)
	LookProfiles.dress_model(party, OTIS, "party")
	LookProfiles.dress_model(enemy, OTIS, "enemy")
	var party_rim: Color = ((party.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).get_active_material(0) as ShaderMaterial).get_shader_parameter("rim_color")
	var enemy_rim: Color = ((enemy.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).get_active_material(0) as ShaderMaterial).get_shader_parameter("rim_color")
	assert_gt(party_rim.r, party_rim.b, "the crew's edge light is warm")
	assert_gt(enemy_rim.b, enemy_rim.r, "the Signals' is cool")
	assert_gt(_brightness_of(_first_texture(enemy).get_image()), 0.0)
	LookProfiles.apply("classic")
	var classic: Node3D = packed.instantiate() as Node3D
	own(classic)
	LookProfiles.dress_model(classic, OTIS, "party")
	for strength: float in _rim_of(classic):
		assert_eq(strength, 0.0, "classic: no edge light")


func _under_a_character(node: Node, room: Node) -> bool:
	var current: Node = node.get_parent()
	while current != null and current != room:
		if current is PlayerController or current is Npc or current is PartyFollower or current is MapEnemy:
			return true
		current = current.get_parent()
	return false


func test_the_room_materials_never_get_the_edge_light() -> void:
	var room: Node = (load(SQUARE) as PackedScene).instantiate()
	add_to_root(room)
	var checked: int = 0
	for node: Node in room.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh == null or _under_a_character(mesh_instance, room):
			continue
		var material: ShaderMaterial = mesh_instance.get_surface_override_material(0) as ShaderMaterial
		if material != null and material.get_shader_parameter("rim_strength") != null:
			assert_eq(float(material.get_shader_parameter("rim_strength")), 0.0, str(mesh_instance.name))
		checked += 1
	assert_gt(checked, 10)


func test_battle_views_carry_the_edge_light_in_both_cameras() -> void:
	for dynamic: bool in [true, false]:
		var stage: BattleScene = (load(BATTLE) as PackedScene).instantiate() as BattleScene
		stage.transitions_enabled = false
		stage.audio = FakeAudio.new()
		add_to_root(stage)
		stage.set_dynamic_camera(dynamic)
		var stub: RefCounted = (load("res://tests/fixtures/battle_stage/stub_battle_controller.gd") as GDScript).new() as RefCounted
		stub.set("instant", true)
		stage.attach_controller(stub)
		stage._on_battle_started(stub.call("snapshot"))
		for id: String in ["red", "otis", "mox", "e1", "e2"]:
			var view: CombatantView = stage.get_view(id)
			assert_not_null(view, id)
			if view == null:
				continue
			var strengths: Array[float] = _rim_of(view.model)
			assert_gt(strengths.size(), 0)
			for strength: float in strengths:
				assert_gt(strength, 0.2, "%s has the edge light (dynamic camera %s)" % [id, dynamic])
		assert_eq(stage.get_view("red").model.scene_file_path, RED_GRIM, "the battle's Red is the grim shiba")


func test_no_placeholder_sign_words_remain_in_the_dressing_data() -> void:
	var banned: Array[String] = ["ALL CLEAR", "CURFEW 22", "HALT"]
	var seen: int = 0
	for room_id: Variant in DataDB.get_dict(DRESSING_DATA)["rooms"]:
		for entry: Variant in (DataDB.get_dict(DRESSING_DATA)["rooms"][room_id] as Dictionary)["items"]:
			var item: Dictionary = entry
			if item.has("text"):
				seen += 1
				assert_false(banned.has(str(item["text"]).to_upper()), "%s still has the placeholder word %s" % [room_id, item["text"]])
	assert_gt(seen, 20, "the signs and screens do have text")
