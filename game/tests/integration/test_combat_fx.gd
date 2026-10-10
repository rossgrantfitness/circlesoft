extends TestCase
## CombatFx (scripts/combat/fx/combat_fx.gd): one listener on the director's signals. Uses a stand-in director with the same signals
## so each effect can be provoked by hand; the real director is covered by the sandbox smoke tests.


class FakeDirector extends Node:
	signal actor_registered(actor_id: StringName, team: StringName)
	signal actor_died(actor_id: StringName)
	signal move_started(info: Dictionary)
	signal hit_landed(info: Dictionary)
	signal launched(info: Dictionary)
	signal telegraphed(info: Dictionary)
	signal parry_judged(info: Dictionary)
	signal perfect_dodge(info: Dictionary)
	signal flare_started(info: Dictionary)
	signal flare_ended()
	signal lights_on_changed(active: bool, duration_s: float)
	var actors_by_id: Dictionary = {}
	var scale: float = 1.0

	func get_actor(id: StringName) -> Node3D:
		return actors_by_id.get(id) as Node3D

	func delta_for(_actor: Node3D, real_delta: float) -> float:
		return real_delta * scale

	func actors(_team: StringName = &"") -> Array:
		return actors_by_id.values()


class FakeActor extends Node3D:
	signal jumped(air: bool)
	signal landed
	signal dashed(air: bool)
	var actor_id: StringName = &"red"
	var team: StringName = &"player"
	var move_set_id: StringName = &"red"
	var model: Node3D = null

	func anchor(_point: StringName) -> Vector3:
		return global_position + Vector3(0.0, 0.6, 0.0)

	func get_facing() -> Vector3:
		return Vector3.BACK

	func get_model() -> Node3D:
		return model


class FakeGear extends Node:
	var tip: Node3D = Node3D.new()
	var base: Node3D = Node3D.new()

	func blade_points() -> Dictionary:
		return {"base": base, "tip": tip}

	func trail_color(_id: StringName) -> Color:
		return Color("#4fd8ff")

	func current_sword() -> StringName:
		return &"katana_cyan"


class FakeCamera extends Node:
	var shakes: Array[Array] = []

	func shake(profile: StringName, mult: float = 1.0) -> void:
		shakes.append([profile, mult])


var _director: FakeDirector = null
var _red: FakeActor = null
var _wolf: FakeActor = null
var _camera: FakeCamera = null
var _fx: CombatFx = null
var _sounds: Array[StringName] = []


func before_each() -> void:
	super.before_each()
	_sounds = []
	_director = FakeDirector.new()
	add_to_root(_director)
	_red = FakeActor.new()
	_red.name = "Red"
	add_to_root(_red)
	var gear: FakeGear = FakeGear.new()
	gear.name = "GearVisuals"
	_red.add_child(gear)
	gear.add_child(gear.tip)
	gear.add_child(gear.base)
	_wolf = FakeActor.new()
	_wolf.actor_id = &"grunt_1"
	_wolf.team = &"enemy"
	_wolf.move_set_id = &"grunt"
	add_to_root(_wolf)
	_wolf.global_position = Vector3(0.0, 0.0, -2.0)
	_director.actors_by_id = {&"red": _red, &"grunt_1": _wolf}
	_camera = FakeCamera.new()
	add_to_root(_camera)
	_fx = CombatFx.new()
	_fx.sound_sink = func(id: StringName) -> void: _sounds.append(id)
	add_to_root(_fx)
	_fx.cfg = DataDB.get_dict("combat/fx")
	_fx.bind_parts(_director, _red, _camera)


func _children_of(type_name: String) -> Array[Node]:
	var found: Array[Node] = []
	for child: Node in _fx.get_children():
		if child.get_class() == type_name or (child.get_script() != null and str(child.get_script().get_global_name()) == type_name):
			found.append(child)
	return found


func _hit(extra: Dictionary = {}) -> Dictionary:
	var info: Dictionary = {"attacker": &"red", "target": &"grunt_1", "move_id": &"light_1", "outcome": "hit", "damage": 8, "launch": false,
			"knockdown": false, "airborne": false, "hit_stop_ms": 50, "shake": "light", "spark": "slash", "sfx": "combat_hit_light", "position": Vector3(0.0, 0.8, -1.0)}
	info.merge(extra, true)
	return info


# ---- hits ----

func test_a_hit_makes_a_spark_shakes_the_camera_and_plays_the_moves_own_sound() -> void:
	_director.hit_landed.emit(_hit())
	assert_eq(_children_of("HitSpark").size(), 1, "one burst")
	assert_eq(_camera.shakes.size(), 1)
	assert_eq(_camera.shakes[0][0], &"light")
	assert_eq(_sounds, [&"combat_hit_light"])


func test_a_move_without_a_sound_gets_the_default_for_its_kind() -> void:
	_director.hit_landed.emit(_hit({"sfx": "", "shake": "heavy"}))
	assert_eq(_sounds, [&"combat_hit_heavy"])


func test_guards_and_armor_use_the_dull_spark_and_a_softer_shake() -> void:
	_director.hit_landed.emit(_hit({"outcome": "guarded"}))
	var spark: HitSpark = _children_of("HitSpark")[0] as HitSpark
	assert_eq(str(spark.profile["color"]), str(_fx.cfg["sparks"]["guard"]["color"]))
	assert_lt(float(_camera.shakes[0][1]), 1.0)


func test_one_sound_plays_once_per_frame_even_if_two_signals_ask() -> void:
	_director.hit_landed.emit(_hit({"sfx": "combat_hit_launch", "launch": true}))
	_director.launched.emit({"attacker": &"red", "target": &"grunt_1", "launch_mps": 7.0})
	assert_eq(_sounds, [&"combat_hit_launch"], "the same id is not played twice")


func test_the_huds_sounds_are_never_played_here() -> void:
	assert_false(_fx.play(&"combat_noise_rank_up"))
	assert_false(_fx.play(&"combat_lock_on"))
	assert_false(_fx.play(&""))
	assert_eq(_sounds.size(), 0)


# ---- parry, dodge, death ----

func test_parries_play_their_sound_and_a_perfect_one_is_bigger() -> void:
	_director.parry_judged.emit({"attacker": &"grunt_1", "rating": "nice", "outcome": "parried", "delta_ms": 120.0, "position": Vector3(0.0, 1.0, -1.0)})
	assert_eq(_sounds, [&"combat_parry"])
	_director.parry_judged.emit({"attacker": &"grunt_1", "rating": "totally_rad", "outcome": "perfect_parry", "delta_ms": 20.0, "position": Vector3(0.0, 1.0, -1.0)})
	assert_eq(_sounds, [&"combat_parry", &"combat_parry_perfect"], "a perfect parry has its own sound")
	assert_eq(_camera.shakes[1][0], &"perfect_parry")
	_director.parry_judged.emit({"attacker": &"grunt_1", "rating": "miss", "outcome": "", "delta_ms": 0.0, "position": Vector3.ZERO})
	assert_eq(_camera.shakes.size(), 2, "a missed press does nothing")


func test_a_death_pops_and_plays_for_enemies_only() -> void:
	_director.actor_died.emit(&"red")
	assert_eq(_sounds.size(), 0, "Red's own death is not this effect")
	_director.actor_died.emit(&"grunt_1")
	assert_eq(_sounds, [&"combat_enemy_death"])
	assert_eq(_children_of("HitSpark").size(), 1)


# ---- movement sounds and the dash streak ----

func test_jump_land_and_dash_sounds_and_the_dash_streak() -> void:
	_red.jumped.emit(false)
	_red.landed.emit()
	assert_eq(_sounds, [&"combat_jump", &"combat_land"])
	_sounds.clear()
	_fx._frame_plays.clear()
	_red.dashed.emit(false)
	assert_eq(_sounds, [&"combat_dash"])
	assert_eq(_children_of("DashStreak").size(), 1)
	_fx._frame_plays.clear()
	_red.dashed.emit(true)
	assert_eq(_sounds.back(), &"combat_air_dash")


# ---- trails ----

func test_a_swing_records_only_during_its_active_phase_on_its_own_clock() -> void:
	var gear: FakeGear = _red.get_node("GearVisuals") as FakeGear
	_director.move_started.emit({"actor": &"red", "move_id": &"light_1", "swing_sfx": "combat_swing_light", "trail": true})
	assert_eq(_sounds, [&"combat_swing_light"])
	var trail: SwordTrail = _fx.get_trail(&"red")
	assert_not_null(trail)
	assert_false(trail.is_active(), "not during the start-up")
	_fx.step(0.04)
	assert_false(_fx.trail_active(&"red"))
	var moved: float = 0.0
	for i: int in 6:
		_fx.step(0.016)
		moved += 0.1
		gear.tip.position = Vector3(moved, 0.5, 0.0)
		trail.step(0.016)
	assert_true(_fx.trail_active(&"red"), "recording once the swing is active (90 ms into light_1)")
	assert_gt(trail.sample_count(), 0)
	_director.scale = 0.0
	var before: int = trail.sample_count()
	_fx.step(0.5)
	assert_true(_fx.trail_active(&"red"), "hit-stop: the swing's clock is frozen, so nothing ends")
	_director.scale = 1.0
	_fx.step(0.5)
	assert_false(_fx.trail_active(&"red"), "and it ends once the active phase is over")
	assert_ge(before, 1)


func test_the_trails_on_knob_turns_trails_off() -> void:
	var feel: FeelKnobs = FeelKnobs.load_defaults()
	feel.set_value("trails_on", false)
	# a tiny director that carries the knobs
	var with_feel: FakeDirectorWithFeel = FakeDirectorWithFeel.new()
	with_feel.feel = feel
	with_feel.actors_by_id = {&"red": _red}
	add_to_root(with_feel)
	var fx: CombatFx = CombatFx.new()
	fx.sound_sink = func(_id: StringName) -> void: pass
	add_to_root(fx)
	fx.cfg = DataDB.get_dict("combat/fx")
	fx.bind_parts(with_feel, _red, null)
	with_feel.move_started.emit({"actor": &"red", "move_id": &"light_1", "swing_sfx": "", "trail": true})
	assert_null(fx.get_trail(&"red"), "trails off: no trail is even made")


class FakeDirectorWithFeel extends Node:
	signal move_started(info: Dictionary)
	var feel: FeelKnobs = null
	var actors_by_id: Dictionary = {}

	func get_actor(id: StringName) -> Node3D:
		return actors_by_id.get(id) as Node3D

	func delta_for(_actor: Node3D, real_delta: float) -> float:
		return real_delta


# ---- the wind-up cue ----

func test_a_telegraph_makes_a_cue_that_lands_on_the_impact_and_then_goes() -> void:
	_director.telegraphed.emit({"attacker": &"grunt_1", "move_id": &"swipe", "impact_in_ms": 560.0, "parryable": true})
	assert_eq(_sounds, [&"combat_enemy_telegraph"])
	var cues: Array[Node] = _children_of("TelegraphCue")
	assert_eq(cues.size(), 1)
	var cue: TelegraphCue = cues[0] as TelegraphCue
	assert_almost_eq(cue.impact_in_s, 0.56, 0.001)
	assert_eq(str(cue.kind_config["color"]), str(_fx.cfg["telegraph"]["kinds"]["parryable"]["color"]))
	_director.scale = 0.0
	_fx.step(0.3)
	assert_almost_eq(cue.elapsed(), 0.0, 0.0001, "frozen with its attacker")
	_director.scale = 1.0
	for i: int in 40:
		_fx.step(0.016)
	await tree.process_frame
	assert_eq(_children_of("TelegraphCue").size(), 0, "gone once the swing has landed")


func test_unparryable_attacks_get_the_other_colour() -> void:
	_director.telegraphed.emit({"attacker": &"grunt_1", "move_id": &"slam", "impact_in_ms": 900.0, "parryable": false})
	var cue: TelegraphCue = _children_of("TelegraphCue")[0] as TelegraphCue
	assert_eq(str(cue.kind_config["color"]), str(_fx.cfg["telegraph"]["kinds"]["unparryable"]["color"]))


# ---- the flare and Lights On ----

func test_the_lamp_flare_lights_up_and_puts_the_world_back() -> void:
	var world: WorldEnvironment = WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.adjustment_saturation = 1.0
	add_to_root(world)
	var flare: FlareFx = _fx.get_flare()
	flare.world_environment = world
	_director.flare_started.emit({"source": "dodge", "duration_s": 1.0, "enemy_scale": 0.3})
	assert_true(flare.is_flaring())
	assert_eq(_sounds, [&"combat_lamp_flare"])
	for i: int in 30:
		flare._process(0.02)
	assert_lt(world.environment.adjustment_saturation, 1.0, "a calmer, cooler world while it lasts")
	var lamp: OmniLight3D = flare.get_node("FlareLamp") as OmniLight3D
	assert_gt(lamp.light_energy, 1.0)
	_director.flare_ended.emit()
	assert_false(flare.is_flaring())
	assert_almost_eq(world.environment.adjustment_saturation, 1.0, 0.0001, "everything put back")


func test_lights_on_brightens_the_edge_light_and_gives_it_back() -> void:
	var model: Node3D = Node3D.new()
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.mesh = BoxMesh.new()
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load("res://shaders/ps2_lit.gdshader") as Shader
	material.set_shader_parameter(&"rim_strength", 0.5)
	mesh_instance.material_override = null
	mesh_instance.set_surface_override_material(0, material)
	model.add_child(mesh_instance)
	_red.model = model
	_red.add_child(model)
	_director.lights_on_changed.emit(true, 12.0)
	assert_true(_fx.get_flare().is_lights_on())
	assert_eq(_sounds, [&"combat_lights_on_activate"])
	assert_almost_eq(float(material.get_shader_parameter("rim_strength")), 0.5 * float(_fx.cfg["lights_on"]["rim_mult"]), 0.001)
	assert_gt(float(material.get_shader_parameter("emissive_pick")), 1.0, "the jacket strips glow")
	_director.lights_on_changed.emit(false, 0.0)
	assert_almost_eq(float(material.get_shader_parameter("rim_strength")), 0.5, 0.001, "put back")
	assert_almost_eq(float(material.get_shader_parameter("emissive_pick")), 0.0, 0.001)
