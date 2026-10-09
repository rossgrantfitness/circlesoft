extends TestCase
## VS-6: the feature switches in data/slice/features.json (Features). Each of lights_on, lamp_flare and noise_meter is proved
## ON and OFF: pure (the file, the knobs), in a stand-alone director with two fighters, and in the real sandbox with its FX and HUD
## attached (a flipped-off feature shows nothing and nothing crashes). Nothing is removed: every test ends by flipping back.

const SANDBOX: String = "res://scenes/sandbox/combat_sandbox.tscn"
const FRAME: float = 1.0 / 60.0

class Fighter extends CombatActor:
	var swing: int = 0

	func current_swing_id() -> int:
		return swing

var _director: CombatDirector = null
var _red: Fighter = null
var _foe: Fighter = null
var _sandbox: Node = null


func before_each() -> void:
	super.before_each()
	Features.clear_overrides()


func after_each() -> void:
	Features.clear_overrides()


func _fighter(id: StringName, team: StringName, move_set: StringName, pos: Vector3) -> Fighter:
	var fighter: Fighter = Fighter.new()
	fighter.actor_id = id
	fighter.team = team
	fighter.move_set_id = move_set
	fighter.hp = 100
	fighter.hp_max = 100
	fighter.height_m = 1.0
	fighter.radius_m = 0.35
	add_to_root(fighter)
	fighter.global_position = pos
	return fighter


func _arena() -> void:
	_director = CombatDirector.new()
	_director.feel = FeelKnobs.load_defaults()
	_director.feel.set_value("enemy_damage_scale", 1.0)
	_director.sync_to_wall_clock = false
	add_to_root(_director)
	_director.set_physics_process(false)
	_red = _fighter(&"red", &"player", &"red", Vector3.ZERO)
	_foe = _fighter(&"grunt_1", &"enemy", &"grunt", Vector3(0, 0, 1.2))
	_foe.rotation.y = PI
	_red.poise_max = 0.0
	_foe.poise_max = 30.0
	_foe.poise = 30.0
	await tree.physics_frame
	await tree.physics_frame


func _tick(frames: int = 1) -> void:
	for i: int in range(frames):
		_director.tick(FRAME)


func _collect(sig: Signal) -> Array[Dictionary]:
	var log: Array[Dictionary] = []
	sig.connect(func(info: Dictionary) -> void: log.append(info))
	return log


func _swipe() -> Dictionary:
	return {"damage": 10, "hitstun_ms": 350, "knockback_m": 1.2, "launch_mps": 0.0, "knockdown": false, "hit_stop_ms": 60,
		"poise_damage": 10, "style_points": 0, "move_id": &"swipe", "launcher": false, "swing_id": 1, "parryable": true,
		"dodge_flare": true, "shake": "medium", "spark": "slash", "sfx": "combat_hit_light"}


func _light() -> Dictionary:
	return {"damage": 8, "hitstun_ms": 320, "knockback_m": 0.5, "launch_mps": 0.0, "knockdown": false, "hit_stop_ms": 50,
		"poise_damage": 8, "style_points": 10, "move_id": &"light_1", "launcher": false, "swing_id": 1, "parryable": true,
		"shake": "light", "spark": "slash", "sfx": "combat_hit_light"}


func _swing(attacker: Fighter, hit: Dictionary, swing_id: int = 1) -> void:
	var shape: Dictionary = {"index": 0, "shape": "sphere", "radius": 1.0, "offset": [0.0, 0.5, 0.8], "rot_deg": [0, 0, 0]}
	attacker.get_hitbox().activate(shape, hit, swing_id)


## Red lands a light on the foe, then the director runs a frame.
func _red_hits_foe() -> void:
	_red.get_hitbox().activate({"index": 0, "shape": "sphere", "radius": 1.0, "offset": [0.0, 0.5, 0.8], "rot_deg": [0, 0, 0]}, _light(), 1)
	_red.get_hitbox().tick(FRAME)
	_tick(1)


# ---- the file and the pure switch ----

func test_the_shipped_file_has_every_switch_on() -> void:
	var doc: Dictionary = CombatData.read_json(Features.PATH)
	assert_false(doc.is_empty(), "data/slice/features.json loads")
	for id: StringName in Features.IDS:
		assert_true(doc.has(String(id)), "%s has a line" % id)
		assert_true(Features.is_on(id), "%s is on by default" % id)
	assert_eq(Features.IDS.size(), 3)


func test_flag_in_reads_a_document_and_defaults_to_on() -> void:
	assert_false(Features.flag_in({"lamp_flare": false}, Features.LAMP_FLARE))
	assert_true(Features.flag_in({"lamp_flare": false}, Features.LIGHTS_ON))
	assert_true(Features.flag_in({}, Features.NOISE_METER), "a missing line means on")
	assert_true(Features.flag_in({"noise_meter": "no"}, Features.NOISE_METER), "a non-boolean is ignored")
	assert_true(Features.is_on(&"no_such_feature"), "a typo never silently disables a system")


func test_set_on_overrides_and_counts_changes() -> void:
	var v0: int = Features.version()
	Features.set_on(Features.LIGHTS_ON, false)
	assert_false(Features.is_on(Features.LIGHTS_ON))
	assert_eq(Features.version(), v0 + 1)
	Features.set_on(Features.LIGHTS_ON, false)
	assert_eq(Features.version(), v0 + 1, "no change, no bump")
	assert_eq(Features.states()[Features.LIGHTS_ON], false)
	assert_eq(Features.states()[Features.LAMP_FLARE], true)
	Features.clear_overrides()
	assert_true(Features.is_on(Features.LIGHTS_ON))
	assert_eq(Features.version(), v0 + 2)


# ---- the feel panel's knobs ----

func test_feel_knobs_of_a_switched_off_feature_are_hidden_and_come_back() -> void:
	var knobs: FeelKnobs = FeelKnobs.load_defaults()
	var all_ids: Array[String] = knobs.ids()
	var shown: Array[String] = []
	for knob: Dictionary in knobs.knobs():
		shown.append(str(knob["id"]))
	assert_eq(shown, all_ids, "all on: the panel shows every knob")
	Features.set_on(Features.LAMP_FLARE, false)
	shown.clear()
	for knob: Dictionary in knobs.knobs():
		shown.append(str(knob["id"]))
	for id: String in ["flare_duration_s", "flare_enemy_speed", "flare_glare_radius_m", "flare_cooldown_s", "flare_on_parry"]:
		assert_false(shown.has(id), "%s hidden with lamp_flare off" % id)
		assert_true(knobs.is_hidden(id))
		assert_true(knobs.has(id), "but the knob still exists")
	assert_true(shown.has("lights_on_trigger"), "other features' knobs stay")
	Features.set_on(Features.LIGHTS_ON, false)
	shown.clear()
	for knob: Dictionary in knobs.knobs():
		shown.append(str(knob["id"]))
	assert_false(shown.has("lights_on_trigger"))
	assert_eq(knobs.all_knobs().size(), all_ids.size(), "all_knobs lists the hidden ones too")
	var saved: Dictionary = knobs.current_values()
	assert_true(saved.has("flare_duration_s"), "a hidden knob still saves its value")
	Features.clear_overrides()
	assert_eq(knobs.knobs().size(), all_ids.size())


# ---- lights_on ----

func test_lights_on_on_starts_when_noise_is_full() -> void:
	await _arena()
	var changes: Array[bool] = []
	_director.lights_on_changed.connect(func(active: bool, _s: float) -> void: changes.append(active))
	_director.style.set_points(100.0)
	_tick(2)
	assert_true(_director.lights_on.is_active())
	assert_eq(changes, [true] as Array[bool])
	assert_almost_eq(float(_director._lights_ctx()["damage_mult"]), 1.5)
	assert_true(bool(_director._lights_ctx()["super_armor"]))


func test_lights_on_off_never_starts_and_gives_no_buffs() -> void:
	await _arena()
	Features.set_on(Features.LIGHTS_ON, false)
	var changes: Array[bool] = []
	_director.lights_on_changed.connect(func(active: bool, _s: float) -> void: changes.append(active))
	_director.style.set_points(100.0)
	_tick(5)
	assert_false(_director.lights_on.is_active(), "auto never starts it")
	assert_false(_director.request_lights_on(), "the chord says no")
	assert_eq(changes.size(), 0, "no lights_on_changed, so no glow, sound or HUD part")
	var ctx: Dictionary = _director._lights_ctx()
	assert_false(bool(ctx["active"]))
	assert_almost_eq(float(ctx["damage_mult"]), 1.0, 0.0001, "damage multiplier 1")
	assert_false(bool(ctx["super_armor"]), "no super armour")
	assert_true(_director.style.is_full(), "Noise itself is untouched")


func test_flipping_lights_on_off_mid_run_ends_it_and_tells_the_listeners() -> void:
	await _arena()
	_director.style.set_points(100.0)
	_tick(2)
	assert_true(_director.lights_on.is_active())
	var changes: Array[bool] = []
	_director.lights_on_changed.connect(func(active: bool, _s: float) -> void: changes.append(active))
	var flips: Array[String] = []
	_director.feature_changed.connect(func(id: StringName, on: bool) -> void: flips.append("%s:%s" % [id, on]))
	Features.set_on(Features.LIGHTS_ON, false)
	_tick(1)
	assert_false(_director.lights_on.is_active())
	assert_eq(changes, [false] as Array[bool])
	assert_eq(flips, ["lights_on:false"] as Array[String])
	Features.set_on(Features.LIGHTS_ON, true)
	_tick(1)
	assert_eq(flips, ["lights_on:false", "lights_on:true"] as Array[String])


func test_lights_on_off_a_hit_does_no_bonus_damage() -> void:
	await _arena()
	_director.style.set_points(100.0)
	_tick(2)
	var start_hp: int = _foe.hp
	_red_hits_foe()
	var boosted: int = start_hp - _foe.hp
	assert_gt(boosted, 0)
	# Same hit with the feature off, fresh fighters.
	_director.queue_free()
	await tree.physics_frame
	Features.set_on(Features.LIGHTS_ON, false)
	await _arena_again()
	_director.style.set_points(100.0)
	_tick(2)
	var hp_before: int = _foe.hp
	_red_hits_foe()
	var plain: int = hp_before - _foe.hp
	assert_gt(plain, 0)
	assert_lt(plain, boosted, "x1.5 with Lights On, x1 without (%d vs %d)" % [boosted, plain])


func _arena_again() -> void:
	_red.queue_free()
	_foe.queue_free()
	await tree.physics_frame
	await _arena()


# ---- lamp_flare ----

func test_lamp_flare_on_a_perfect_dodge_flares_and_calls_out() -> void:
	await _arena()
	_tick(30)
	var dodges: Array[Dictionary] = _collect(_director.perfect_dodge)
	var detected: Array[Dictionary] = _collect(_director.perfect_dodge_detected)
	var flares: Array[Dictionary] = _collect(_director.flare_started)
	_foe.swing = 21
	_director.telegraph(_foe, &"swipe", _foe.clock.now_usec() + 500000)
	_tick(24)
	_director.report_dash(_director.stamp_usec())
	assert_eq(dodges.size(), 1)
	assert_eq(detected.size(), 1)
	assert_eq(flares.size(), 1)
	assert_true(_director.time.is_flaring())


func test_lamp_flare_off_a_perfect_dodge_is_seen_but_does_not_flare() -> void:
	await _arena()
	Features.set_on(Features.LAMP_FLARE, false)
	_tick(30)
	var dodges: Array[Dictionary] = _collect(_director.perfect_dodge)
	var detected: Array[Dictionary] = _collect(_director.perfect_dodge_detected)
	var flares: Array[Dictionary] = _collect(_director.flare_started)
	var noise_before: float = _director.style.points()
	_foe.swing = 22
	_director.telegraph(_foe, &"swipe", _foe.clock.now_usec() + 500000)
	_tick(24)
	_director.report_dash(_director.stamp_usec())
	assert_eq(detected.size(), 1, "the dodge is still detected")
	assert_eq(dodges.size(), 0, "but no call-out signal (and so no spark)")
	assert_eq(flares.size(), 0, "no slow-mo")
	assert_false(_director.time.is_flaring())
	assert_gt(_director.style.points(), noise_before, "the dodge still earns Noise")


func test_lamp_flare_off_a_perfect_parry_still_staggers_but_does_not_flare() -> void:
	await _arena()
	Features.set_on(Features.LAMP_FLARE, false)
	_tick(30)
	var staggers: Array[Dictionary] = _collect(_director.stagger)
	var flares: Array[Dictionary] = _collect(_director.flare_started)
	_director.report_parry_press(_director.stamp_usec() - 20000)
	_swing(_foe, _swipe())
	_foe.get_hitbox().tick(FRAME)
	assert_eq(_red.hp, 100, "the parry still works")
	assert_eq(staggers.size(), 1)
	assert_eq(flares.size(), 0)
	assert_false(_director.time.is_flaring())


func test_flipping_lamp_flare_off_mid_flare_ends_it() -> void:
	await _arena()
	_tick(30)
	_director.report_parry_press(_director.stamp_usec() - 10000)
	_swing(_foe, _swipe())
	_foe.get_hitbox().tick(FRAME)
	assert_true(_director.time.is_flaring())
	var ended: Array[int] = []
	_director.flare_ended.connect(func() -> void: ended.append(1))
	Features.set_on(Features.LAMP_FLARE, false)
	_tick(1)
	assert_false(_director.time.is_flaring())
	assert_eq(ended.size(), 1, "flare_ended tells FX and HUD to put the look away")


# ---- noise_meter ----

func test_noise_meter_on_hits_score() -> void:
	await _arena()
	_tick(2)
	var seen: Array[float] = []
	_director.noise_changed.connect(func(points: float, _f: float, _r: StringName, _n: String) -> void: seen.append(points))
	_red_hits_foe()
	assert_gt(_director.style.points(), 0.0)
	assert_gt(seen.size(), 0)


func test_noise_meter_off_stops_scoring_and_emits_nothing_more() -> void:
	await _arena()
	Features.set_on(Features.NOISE_METER, false)
	_tick(2)
	var seen: Array[float] = []
	_director.noise_changed.connect(func(points: float, _f: float, _r: StringName, _n: String) -> void: seen.append(points))
	var ranks: Array[int] = []
	_director.noise_rank_changed.connect(func(_i: StringName, _n: String, _up: bool) -> void: ranks.append(1))
	_red_hits_foe()
	_director.style.add_bonus(&"parry", 0.0)
	_director.style.add_hit(&"x", 50.0, 0.0)
	assert_almost_eq(_director.style.points(), 0.0, 0.0001, "nothing scores")
	assert_eq(seen.size(), 0, "so the HUD gets no noise_changed")
	assert_eq(ranks.size(), 0, "and no rank sound")
	assert_false(_director.request_lights_on(), "Lights On needs a full meter")


func test_flipping_noise_meter_off_mid_run_empties_the_meter_and_ends_lights_on() -> void:
	await _arena()
	_director.style.set_points(100.0)
	_tick(2)
	assert_true(_director.lights_on.is_active())
	var last_points: Array[float] = [99.0]
	_director.noise_changed.connect(func(points: float, _f: float, _r: StringName, _n: String) -> void: last_points[0] = points)
	var ended: Array[bool] = []
	_director.lights_on_changed.connect(func(active: bool, _s: float) -> void: ended.append(active))
	Features.set_on(Features.NOISE_METER, false)
	_tick(1)
	assert_false(_director.lights_on.is_active())
	assert_eq(ended, [false] as Array[bool])
	assert_almost_eq(last_points[0], 0.0, 0.0001, "the HUD is told Noise is 0")
	_tick(30)
	assert_almost_eq(_director.style.points(), 0.0, 0.0001)
	Features.set_on(Features.NOISE_METER, true)
	_tick(1)
	_red_hits_foe()
	assert_gt(_director.style.points(), 0.0, "scoring is back")


# ---- the real sandbox, FX and HUD attached ----

func _boot_sandbox() -> void:
	_sandbox = (load(SANDBOX) as PackedScene).instantiate()
	add_to_root(_sandbox)
	for i: int in range(3):
		await tree.physics_frame
	_director = _sandbox.call("get_director") as CombatDirector
	var red: Node = _sandbox.call("get_player")
	(red as ActionPlayer).read_engine_input = false


func _find_by_script(script_path: String) -> Node:
	for node: Node in _sandbox.get_tree().root.find_children("*", "", true, false):
		var script: Script = node.get_script() as Script
		if script != null and script.resource_path == script_path:
			return node
	return null


func _frames(count: int) -> void:
	for i: int in range(count):
		await tree.physics_frame


func test_sandbox_with_every_switch_on_shows_all_three() -> void:
	await _boot_sandbox()
	var hud: SandboxHud = _find_by_script("res://scripts/ui/sandbox/sandbox_hud.gd") as SandboxHud
	var fx: CombatFx = _find_by_script("res://scripts/combat/fx/combat_fx.gd") as CombatFx
	assert_not_null(hud)
	assert_not_null(fx)
	var red: ActionPlayer = _sandbox.call("get_player") as ActionPlayer
	var foe: CombatActor = _director.actors(&"enemy")[0] as CombatActor
	_director.style.set_points(100.0)
	await _frames(3)
	assert_true(_director.lights_on.is_active(), "Lights On starts")
	assert_true(hud.is_lights_on(), "the HUD shows it")
	_director._do_perfect_dodge(foe, &"swipe", {"key": "feat_on"}, red)
	await _frames(2)
	assert_true(_director.time.is_flaring(), "a perfect dodge flares")
	assert_true(hud.is_flaring())
	assert_true(fx.get_flare().is_flaring())
	assert_true(hud.get_callouts().size() > 0, "and calls it out")
	assert_gt(_director.style.points(), 0.0)


func test_sandbox_with_lights_on_off_shows_none_of_it() -> void:
	await _boot_sandbox()
	var hud: SandboxHud = _find_by_script("res://scripts/ui/sandbox/sandbox_hud.gd") as SandboxHud
	var fx: CombatFx = _find_by_script("res://scripts/combat/fx/combat_fx.gd") as CombatFx
	Features.set_on(Features.LIGHTS_ON, false)
	_director.style.set_points(100.0)
	await _frames(120)
	assert_false(_director.lights_on.is_active())
	assert_false(hud.is_lights_on())
	assert_false(fx.get_flare().is_lights_on(), "no glow")
	assert_true(_director.style.is_full(), "Noise still works")
	assert_eq(hud.get_noise()["fill"], 1.0)


func test_sandbox_flipping_lights_on_off_while_it_runs_puts_the_glow_away() -> void:
	await _boot_sandbox()
	var hud: SandboxHud = _find_by_script("res://scripts/ui/sandbox/sandbox_hud.gd") as SandboxHud
	var fx: CombatFx = _find_by_script("res://scripts/combat/fx/combat_fx.gd") as CombatFx
	_director.style.set_points(100.0)
	await _frames(3)
	assert_true(fx.get_flare().is_lights_on())
	Features.set_on(Features.LIGHTS_ON, false)
	await _frames(3)
	assert_false(fx.get_flare().is_lights_on())
	assert_false(hud.is_lights_on())


func test_sandbox_with_lamp_flare_off_shows_no_flare_or_call_out() -> void:
	await _boot_sandbox()
	var hud: SandboxHud = _find_by_script("res://scripts/ui/sandbox/sandbox_hud.gd") as SandboxHud
	var fx: CombatFx = _find_by_script("res://scripts/combat/fx/combat_fx.gd") as CombatFx
	Features.set_on(Features.LAMP_FLARE, false)
	var red: ActionPlayer = _sandbox.call("get_player") as ActionPlayer
	var foe: CombatActor = _director.actors(&"enemy")[0] as CombatActor
	await _frames(2)
	var sounds: Array[StringName] = []
	fx.sound_played.connect(func(id: StringName) -> void: sounds.append(id))
	_director._do_perfect_dodge(foe, &"swipe", {"key": "feat_off"}, red)
	_director._start_flare("parry", red)
	await _frames(30)
	assert_false(_director.time.is_flaring())
	assert_false(hud.is_flaring())
	assert_false(fx.get_flare().is_flaring())
	assert_eq(hud.get_callouts().size(), 0, "no Lamp Flare call-out")
	assert_eq(sounds.filter(func(id: StringName) -> bool: return String(id).contains("flare")).size(), 0, "no flare sound")


func test_sandbox_with_noise_meter_off_never_moves_the_meter() -> void:
	await _boot_sandbox()
	var hud: SandboxHud = _find_by_script("res://scripts/ui/sandbox/sandbox_hud.gd") as SandboxHud
	Features.set_on(Features.NOISE_METER, false)
	var red: ActionPlayer = _sandbox.call("get_player") as ActionPlayer
	var foe: CombatActor = _director.actors(&"enemy")[0] as CombatActor
	await _frames(2)
	_director.style.add_bonus(&"perfect_parry", 0.0)
	_director.style.add_hit(&"light_1", 30.0, 0.0)
	_director._do_perfect_dodge(foe, &"swipe", {"key": "noise_off"}, red)
	await _frames(60)
	assert_almost_eq(_director.style.points(), 0.0, 0.0001)
	assert_eq(float(hud.get_noise()["points"]), 0.0)
	assert_false(_director.lights_on.is_active())
