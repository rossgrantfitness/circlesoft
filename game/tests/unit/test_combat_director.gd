extends TestCase
## CombatDirector, CombatActor, Hitbox and Hurtbox together on the real physics space: contact, once per
## swing, hit-stop on both sides, the parry, the perfect dodge and the Lamp Flare.

const FRAME: float = 1.0 / 60.0

class Fighter extends CombatActor:
	var reactions: Array[Dictionary] = []
	var landed: Array[Dictionary] = []
	var parried: Array[Dictionary] = []
	var invulnerable_now: bool = false
	var armored_now: bool = false
	var swing: int = 0
	var airborne_now: bool = false

	func _on_hit_reaction(result: Dictionary) -> void:
		reactions.append(result)

	func _on_hit_landed(result: Dictionary) -> void:
		landed.append(result)

	func _on_parried(result: Dictionary) -> void:
		parried.append(result)

	func is_invulnerable() -> bool:
		return invulnerable_now

	func is_armored() -> bool:
		return armored_now

	func is_airborne() -> bool:
		return airborne_now

	func current_swing_id() -> int:
		return swing


var _director: CombatDirector = null
var _red: Fighter = null
var _foe: Fighter = null


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


## A director and two fighters 1.2 m apart: Red at the origin facing +Z, the foe in front of her.
func _arena(foe_team: StringName = &"enemy") -> void:
	_director = CombatDirector.new()
	_director.feel = FeelKnobs.load_defaults()
	_director.feel.set_value("enemy_damage_scale", 1.0)       # these tests count raw damage, not the tuned default
	_director.sync_to_wall_clock = false
	add_to_root(_director)
	_director.set_physics_process(false)
	_red = _fighter(&"red", &"player", &"red", Vector3.ZERO)
	_foe = _fighter(&"grunt_1", foe_team, &"grunt", Vector3(0, 0, 1.2))
	_foe.rotation.y = PI        # the foe faces Red (-Z)
	_red.poise_max = 0.0
	_foe.poise_max = 30.0
	_foe.poise = 30.0
	await tree.physics_frame
	await tree.physics_frame


func _swing(attacker: Fighter, hit: Dictionary, swing_id: int = 1, box: Dictionary = {}) -> void:
	var shape: Dictionary = box if not box.is_empty() else {"index": 0, "shape": "sphere", "radius": 1.0, "offset": [0.0, 0.5, 0.8], "rot_deg": [0, 0, 0]}
	attacker.get_hitbox().activate(shape, hit, swing_id)


func _light() -> Dictionary:
	return {"damage": 8, "hitstun_ms": 320, "knockback_m": 0.5, "launch_mps": 0.0, "knockdown": false, "hit_stop_ms": 50,
		"poise_damage": 8, "style_points": 10, "move_id": &"light_1", "launcher": false, "swing_id": 1, "parryable": true,
		"shake": "light", "spark": "slash", "sfx": "combat_hit_light"}


func _swipe() -> Dictionary:
	return {"damage": 10, "hitstun_ms": 350, "knockback_m": 1.2, "launch_mps": 0.0, "knockdown": false, "hit_stop_ms": 60,
		"poise_damage": 10, "style_points": 0, "move_id": &"swipe", "launcher": false, "swing_id": 1, "parryable": true,
		"dodge_flare": true, "shake": "medium", "spark": "slash", "sfx": "combat_hit_light"}


func _collect(sig: Signal) -> Array[Dictionary]:
	var log: Array[Dictionary] = []
	sig.connect(func(info: Dictionary) -> void: log.append(info))
	return log


func _tick(frames: int = 1) -> void:
	for i: int in range(frames):
		_director.tick(FRAME)


# ---- registry ----

func test_fighters_register_and_the_director_announces_them() -> void:
	_director = CombatDirector.new()
	_director.feel = FeelKnobs.load_defaults()
	add_to_root(_director)
	_director.set_physics_process(false)
	var seen: Array[String] = []
	_director.actor_registered.connect(func(id: StringName, team: StringName) -> void: seen.append("%s:%s" % [id, team]))
	var hp_seen: Array[String] = []
	_director.hp_changed.connect(func(id: StringName, hp: int, hp_max: int) -> void: hp_seen.append("%s %d/%d" % [id, hp, hp_max]))
	_red = _fighter(&"red", &"player", &"red", Vector3.ZERO)
	_foe = _fighter(&"grunt_1", &"enemy", &"grunt", Vector3(0, 0, 3))
	assert_eq(seen, ["red:player", "grunt_1:enemy"] as Array[String])
	assert_eq(hp_seen, ["red 100/100", "grunt_1 100/100"] as Array[String])
	assert_eq(_director.actors().size(), 2)
	assert_eq(_director.actors(&"enemy").size(), 1)
	assert_eq(_director.player(), _red)
	assert_eq(_director.get_actor(&"grunt_1"), _foe)
	_director.unregister(_foe)
	assert_eq(_director.actors().size(), 1)


func test_the_director_is_in_its_group_and_steps_before_the_fighters() -> void:
	_director = CombatDirector.new()
	add_to_root(_director)
	assert_true(_director.is_in_group(CombatDirector.GROUP))
	assert_eq(_director.process_physics_priority, -100)


func test_actors_find_a_director_that_arrives_later() -> void:
	var lone: Fighter = _fighter(&"early", &"enemy", &"grunt", Vector3.ZERO)
	_director = CombatDirector.new()
	_director.feel = FeelKnobs.load_defaults()
	add_to_root(_director)
	_director.set_physics_process(false)
	assert_eq(_director.get_actor(&"early"), lone)
	assert_eq(lone.get_hitbox().director, _director)


# ---- contact ----

func test_a_hit_lands_once_per_swing_and_reaches_both_fighters() -> void:
	await _arena()
	var hits: Array[Dictionary] = _collect(_director.hit_landed)
	_swing(_red, _light())
	_red.get_hitbox().tick(FRAME)
	_red.get_hitbox().tick(FRAME)
	_red.get_hitbox().tick(FRAME)
	assert_eq(hits.size(), 1, "three ticks of overlap, one hit")
	assert_eq(_foe.hp, 92)
	assert_eq(_foe.reactions.size(), 1)
	assert_eq(_red.landed.size(), 1)
	assert_eq(hits[0]["attacker"], &"red")
	assert_eq(hits[0]["target"], &"grunt_1")
	assert_eq(hits[0]["outcome"], &"hit")
	assert_eq(hits[0]["damage"], 8)
	assert_eq(hits[0]["spark"], "slash")
	assert_eq(hits[0]["sfx"], "combat_hit_light")
	assert_eq(hits[0]["shake"], "light")
	assert_true(hits[0].has("position"))


func test_a_new_swing_hits_again() -> void:
	await _arena()
	var hits: Array[Dictionary] = _collect(_director.hit_landed)
	_swing(_red, _light(), 1)
	_red.get_hitbox().tick(FRAME)
	_red.get_hitbox().clear()
	_swing(_red, _light(), 2)
	_red.get_hitbox().tick(FRAME)
	assert_eq(hits.size(), 2)
	assert_eq(_foe.hp, 84)


func test_overlapping_slices_of_one_swing_do_not_double_hit() -> void:
	await _arena()
	var hits: Array[Dictionary] = _collect(_director.hit_landed)
	_swing(_red, _light(), 5, {"index": 0, "shape": "sphere", "radius": 1.0, "offset": [0.0, 0.5, 0.8], "rot_deg": [0, 0, 0]})
	_swing(_red, _light(), 5, {"index": 1, "shape": "sphere", "radius": 1.0, "offset": [0.0, 0.5, 0.9], "rot_deg": [0, 0, 0]})
	_red.get_hitbox().tick(FRAME)
	assert_eq(hits.size(), 1)


func test_a_shape_that_misses_hits_nothing_and_off_means_off() -> void:
	await _arena()
	var hits: Array[Dictionary] = _collect(_director.hit_landed)
	_swing(_red, _light(), 1, {"index": 0, "shape": "sphere", "radius": 0.3, "offset": [3.0, 0.5, 0.0], "rot_deg": [0, 0, 0]})
	_red.get_hitbox().tick(FRAME)
	assert_eq(hits.size(), 0)
	_red.get_hitbox().clear()
	_swing(_red, _light(), 2)
	_red.get_hitbox().deactivate(0)
	_red.get_hitbox().tick(FRAME)
	assert_eq(hits.size(), 0, "a deactivated slice does not hit")


func test_same_team_never_hit_each_other() -> void:
	await _arena(&"player")
	var hits: Array[Dictionary] = _collect(_director.hit_landed)
	_swing(_red, _light())
	_red.get_hitbox().tick(FRAME)
	assert_eq(hits.size(), 0)
	assert_eq(_foe.hp, 100)


func test_hit_stop_freezes_attacker_and_target_and_counts_down() -> void:
	await _arena()
	_swing(_red, _light())
	_red.get_hitbox().tick(FRAME)
	assert_true(_director.time.is_frozen(&"red"))
	assert_true(_director.time.is_frozen(&"grunt_1"))
	var red_before: int = _red.clock.now_usec()
	var foe_before: int = _foe.clock.now_usec()
	_tick(2)
	assert_eq(_red.clock.now_usec(), red_before, "the attacker's clock stands still")
	assert_eq(_foe.clock.now_usec(), foe_before, "so does the target's")
	_tick(2)
	assert_false(_director.time.is_frozen(&"red"), "50 ms is over after 4 frames at 60 fps")
	_tick(1)
	assert_gt(_red.clock.now_usec(), red_before)


func test_the_hit_stop_knob_is_live() -> void:
	await _arena()
	_director.feel.set_value("hit_stop_scale", 0.0)
	_swing(_red, _light())
	_red.get_hitbox().tick(FRAME)
	assert_false(_director.time.is_frozen(&"red"), "scale 0 = no freeze")


func test_dead_enemies_announce_themselves_once() -> void:
	await _arena()
	var deaths: Array[StringName] = []
	_director.actor_died.connect(func(id: StringName) -> void: deaths.append(id))
	_foe.hp = 5
	_swing(_red, _light())
	_red.get_hitbox().tick(FRAME)
	assert_eq(_foe.hp, 0)
	assert_true(_foe.dead)
	assert_eq(deaths, [&"grunt_1"] as Array[StringName])
	_red.get_hitbox().clear()
	_swing(_red, _light(), 9)
	_red.get_hitbox().tick(FRAME)
	assert_eq(deaths.size(), 1, "a dead target is ignored")


func test_launch_and_noise_reach_the_listeners() -> void:
	await _arena()
	var launches: Array[Dictionary] = _collect(_director.launched)
	var noise: Array[float] = []
	_director.noise_changed.connect(func(points: float, _fill: float, _id: StringName, _name: String) -> void: noise.append(points))
	var launcher: Dictionary = _light()
	launcher["launch_mps"] = 11.0
	launcher["launcher"] = true
	launcher["move_id"] = &"launcher"
	_swing(_red, launcher)
	_red.get_hitbox().tick(FRAME)
	assert_eq(launches.size(), 1)
	assert_almost_eq(float(launches[0]["launch_mps"]), 11.0)
	assert_eq(_foe.juggle_count, 1)
	assert_gt(noise.back(), 10.0, "hit points plus the launch bonus")


func test_noise_rank_signal_fires_when_a_rank_is_reached() -> void:
	await _arena()
	var ranks: Array[String] = []
	_director.noise_rank_changed.connect(func(id: StringName, _name: String, up: bool) -> void: ranks.append("%s %s" % [id, "up" if up else "down"]))
	_director.style.set_points(19.0)
	_swing(_red, _light())
	_red.get_hitbox().tick(FRAME)
	assert_eq(ranks, ["nice up"] as Array[String])


func test_taking_damage_drops_a_rank_and_hurts_hp() -> void:
	await _arena()
	_director.style.set_points(55.0)
	var hits: Array[Dictionary] = _collect(_director.hit_landed)
	_swing(_foe, _swipe())
	_foe.get_hitbox().tick(FRAME)
	assert_eq(hits.size(), 1)
	assert_eq(_red.hp, 90)
	assert_eq(_director.style.rank()["id"], &"nice")


# ---- parry ----

## Press times in the middle of each rating band, read from the data so retuning the windows does not break these.
func _rad_ms() -> float:
	var window: Dictionary = CombatData.parry_window()
	return (float(window["totally_rad_ms"]) + float(window["rad_ms"])) * 0.5


func _nice_ms() -> float:
	var window: Dictionary = CombatData.parry_window()
	return (float(window["rad_ms"]) + float(window["nice_ms"])) * 0.5


func _parry_at(ms_before_contact: float) -> void:
	# Red pressed `ms_before_contact` before the hit lands, on the (hand-stepped) real-time axis.
	_director.report_parry_press(_director.stamp_usec() - int(ms_before_contact * 1000.0))


func test_a_perfect_parry_staggers_the_attacker_and_does_no_damage() -> void:
	await _arena()
	_tick(30)
	var judged: Array[Dictionary] = _collect(_director.parry_judged)
	var staggers: Array[Dictionary] = _collect(_director.stagger)
	var flares: Array[Dictionary] = _collect(_director.flare_started)
	_parry_at(20.0)
	_swing(_foe, _swipe())
	_foe.get_hitbox().tick(FRAME)
	assert_eq(_red.hp, 100)
	assert_eq(judged.size(), 1)
	assert_eq(judged[0]["rating"], "totally_rad")
	assert_eq(judged[0]["outcome"], &"perfect_parry")
	assert_eq(_foe.parried.size(), 1)
	assert_eq(_foe.parried[0]["outcome"], &"perfect_parry")
	assert_eq(staggers.size(), 1)
	assert_eq(staggers[0]["by"], "parry")
	assert_eq(flares.size(), 1, "a perfect parry starts a Lamp Flare")
	assert_eq(flares[0]["source"], "parry")


func test_a_rad_parry_recoils_and_flares_but_a_nice_guard_does_not() -> void:
	await _arena()
	_tick(30)
	var flares: Array[Dictionary] = _collect(_director.flare_started)
	_parry_at(_rad_ms())
	_swing(_foe, _swipe())
	_foe.get_hitbox().tick(FRAME)
	assert_eq(_foe.parried[0]["outcome"], &"parried")
	assert_eq(flares.size(), 1)
	_foe.get_hitbox().clear()
	_director.time.end_flare()
	_director._flare_cooldown_s = 0.0
	_parry_at(_nice_ms())
	_swing(_foe, _swipe(), 2)
	_foe.get_hitbox().tick(FRAME)
	assert_eq(_red.hp, 100 - 4, "10 damage less the 60 percent Nice guard (parry.block_reduction in timing_windows.json)")
	assert_eq(flares.size(), 1, "Nice is a guard, not a flare")


func test_a_late_or_missing_press_gets_hit() -> void:
	await _arena()
	_tick(30)
	_swing(_foe, _swipe())
	_foe.get_hitbox().tick(FRAME)
	assert_eq(_red.hp, 90)
	_foe.get_hitbox().clear()
	_director.report_parry_press(_director.stamp_usec() + 30000)
	_swing(_foe, _swipe(), 2)
	_foe.get_hitbox().tick(FRAME)
	assert_eq(_red.hp, 80, "a press after contact does not count")


func test_one_press_covers_one_hit() -> void:
	await _arena()
	_tick(30)
	_parry_at(30.0)
	_swing(_foe, _swipe())
	_foe.get_hitbox().tick(FRAME)
	_foe.get_hitbox().clear()
	_swing(_foe, _swipe(), 2)
	_foe.get_hitbox().tick(FRAME)
	assert_eq(_red.hp, 90, "the second hit finds no fresh press")


func test_flare_on_parry_knob_choices() -> void:
	await _arena()
	_tick(30)
	var flares: Array[Dictionary] = _collect(_director.flare_started)
	_director.feel.set_value("flare_on_parry", "perfect_only")
	_parry_at(_rad_ms())
	_swing(_foe, _swipe())
	_foe.get_hitbox().tick(FRAME)
	assert_eq(flares.size(), 0, "a plain parry is not enough in perfect_only")
	_foe.get_hitbox().clear()
	_director.feel.set_value("flare_on_parry", "off")
	_parry_at(10.0)
	_swing(_foe, _swipe(), 2)
	_foe.get_hitbox().tick(FRAME)
	assert_eq(flares.size(), 0)
	assert_eq(_foe.parried.size(), 2, "the parry itself still works")


func test_the_parry_window_scale_knob_is_live() -> void:
	await _arena()
	_tick(30)
	_director.feel.set_value("parry_window_scale", 3.0)
	var judged: Array[Dictionary] = _collect(_director.parry_judged)
	_parry_at(180.0)      # 180 ms early is a miss at 1.0 (rad 130), but rad at 3x
	_swing(_foe, _swipe())
	_foe.get_hitbox().tick(FRAME)
	assert_eq(judged[0]["rating"], "totally_rad", "70 x 3 = 210 covers 180 ms")


func test_parry_is_judged_on_the_attackers_clock_through_a_hit_stop() -> void:
	await _arena()
	_tick(30)
	var judged: Array[Dictionary] = _collect(_director.parry_judged)
	_parry_at(0.0)
	_director.time.add_hit_stop([&"grunt_1"] as Array[StringName], 200.0)
	_tick(12)        # 200 ms of real time pass; the enemy's own clock does not move
	_swing(_foe, _swipe())
	_foe.get_hitbox().tick(FRAME)
	assert_eq(judged.size(), 1)
	assert_ne(judged[0]["rating"], "miss", "the freeze did not push the press out of the window")


# ---- Lamp Flare and perfect dodge ----

func test_a_flare_slows_enemies_and_not_red() -> void:
	await _arena()
	_tick(2)
	_director.feel.set_value("flare_glare_radius_m", 12.0)
	_parry_at(10.0)
	_swing(_foe, _swipe())
	_foe.get_hitbox().tick(FRAME)
	assert_true(_director.time.is_flaring())
	_tick(8)     # let the parry hit-stop pass
	var red_before: int = _red.clock.now_usec()
	var foe_before: int = _foe.clock.now_usec()
	_tick(10)
	var red_gain: int = _red.clock.now_usec() - red_before
	var foe_gain: int = _foe.clock.now_usec() - foe_before
	assert_almost_eq(float(foe_gain) / float(red_gain), 0.25, 0.01, "enemies at flare_enemy_speed, Red at full")


func test_enemies_outside_the_glare_are_not_slowed() -> void:
	await _arena()
	var far: Fighter = _fighter(&"grunt_far", &"enemy", &"grunt", Vector3(0, 0, 30))
	await tree.physics_frame
	_director.feel.set_value("flare_glare_radius_m", 12.0)
	_parry_at(10.0)
	_swing(_foe, _swipe())
	_foe.get_hitbox().tick(FRAME)
	assert_true(_director.time.is_slowed(&"grunt_1"))
	assert_false(_director.time.is_slowed(far.actor_id))


func test_a_perfect_dodge_by_dashing_into_a_telegraphed_attack_starts_a_flare() -> void:
	await _arena()
	_tick(30)
	var dodges: Array[Dictionary] = _collect(_director.perfect_dodge)
	var flares: Array[Dictionary] = _collect(_director.flare_started)
	var telegraphs: Array[Dictionary] = _collect(_director.telegraphed)
	_foe.swing = 11
	_director.telegraph(_foe, &"swipe", _foe.clock.now_usec() + 500000)
	assert_eq(telegraphs.size(), 1)
	assert_almost_eq(float(telegraphs[0]["impact_in_ms"]), 500.0, 0.5)
	assert_true(telegraphs[0]["parryable"])
	_tick(24)      # 400 ms later: 100 ms before impact, inside the 120 ms window
	_director.report_dash(_director.stamp_usec())
	assert_eq(dodges.size(), 1)
	assert_eq(flares.size(), 1)
	assert_eq(flares[0]["source"], "dodge")
	assert_true(_director.time.is_flaring())


func test_dashing_too_early_or_from_outside_the_zone_is_no_dodge() -> void:
	await _arena()
	_tick(30)
	var dodges: Array[Dictionary] = _collect(_director.perfect_dodge)
	_foe.swing = 12
	_director.telegraph(_foe, &"swipe", _foe.clock.now_usec() + 500000)
	_director.report_dash(_director.stamp_usec())            # 500 ms early
	assert_eq(dodges.size(), 0, "too early")
	_red.global_position = Vector3(10, 0, 0)
	_tick(24)
	_director.report_dash(_director.stamp_usec())
	assert_eq(dodges.size(), 0, "Red was not in the threat zone")


func test_one_flare_per_attack_and_a_cooldown_between_flares() -> void:
	await _arena()
	_tick(30)
	var flares: Array[Dictionary] = _collect(_director.flare_started)
	_foe.swing = 13
	_director.telegraph(_foe, &"swipe", _foe.clock.now_usec() + 500000)
	_tick(24)
	_director.report_dash(_director.stamp_usec())
	_director.report_dash(_director.stamp_usec())
	assert_eq(flares.size(), 1, "the same attack cannot flare twice")
	_director.time.end_flare()
	_foe.swing = 14
	_director.telegraph(_foe, &"swipe", _foe.clock.now_usec() + 500000)
	_tick(24)
	_director.report_dash(_director.stamp_usec())
	assert_eq(flares.size(), 1, "the cooldown holds the next flare back")
	_tick(200)       # more than flare_cooldown_s of real time
	_foe.swing = 15
	_director.telegraph(_foe, &"swipe", _foe.clock.now_usec() + 500000)
	_tick(24)
	_director.report_dash(_director.stamp_usec())
	assert_eq(flares.size(), 2)


func test_an_evaded_hit_right_after_a_dash_is_a_perfect_dodge() -> void:
	await _arena()
	_tick(30)
	var dodges: Array[Dictionary] = _collect(_director.perfect_dodge)
	var hits: Array[Dictionary] = _collect(_director.hit_landed)
	_director.report_dash(_director.stamp_usec())
	_red.invulnerable_now = true
	_tick(3)      # 50 ms later the swipe connects on a dashing Red
	_swing(_foe, _swipe())
	_foe.get_hitbox().tick(FRAME)
	assert_eq(_red.hp, 100)
	assert_eq(hits.size(), 0, "an evaded hit is not a hit")
	assert_eq(dodges.size(), 1)
	assert_true(_director.time.is_flaring())


func test_dodge_flare_false_opts_an_attack_out() -> void:
	await _arena()
	_tick(30)
	var dodges: Array[Dictionary] = _collect(_director.perfect_dodge)
	_director.report_dash(_director.stamp_usec())
	_red.invulnerable_now = true
	var swipe: Dictionary = _swipe()
	swipe["dodge_flare"] = false
	_swing(_foe, swipe)
	_foe.get_hitbox().tick(FRAME)
	assert_eq(dodges.size(), 0)


func test_the_flare_ends_and_announces_it() -> void:
	await _arena()
	var ended: Array[bool] = [false]
	_director.flare_ended.connect(func() -> void: ended[0] = true)
	_director.feel.set_value("flare_duration_s", 0.5)
	_parry_at(10.0)
	_swing(_foe, _swipe())
	_foe.get_hitbox().tick(FRAME)
	assert_true(_director.time.is_flaring())
	_tick(60)
	assert_true(ended[0])
	assert_false(_director.time.is_flaring())


# ---- Lights On, armor ----

func test_lights_on_starts_on_a_full_meter_in_auto_mode_and_ends() -> void:
	await _arena()
	var states: Array[bool] = []
	_director.lights_on_changed.connect(func(active: bool, _duration: float) -> void: states.append(active))
	_director.style.set_points(100.0)
	_tick(1)
	assert_eq(states, [true] as Array[bool])
	assert_true(_director.lights_on.is_active())
	_tick(60 * 13)
	assert_eq(states, [true, false] as Array[bool])


func test_chord_mode_waits_for_the_request() -> void:
	await _arena()
	_director.feel.set_value("lights_on_trigger", "chord")
	_director.style.set_points(100.0)
	_tick(2)
	assert_false(_director.lights_on.is_active())
	assert_true(_director.request_lights_on())
	assert_true(_director.lights_on.is_active())
	assert_false(_director.request_lights_on(), "already running")


func test_lights_on_buffs_reach_the_resolver() -> void:
	await _arena()
	_director.style.set_points(100.0)
	_tick(1)
	_swing(_red, _light())
	_red.get_hitbox().tick(FRAME)
	assert_eq(_foe.hp, 88, "8 x 1.5")
	_red.get_hitbox().clear()
	_swing(_foe, _swipe())
	_foe.get_hitbox().tick(FRAME)
	assert_eq(_red.reactions.back()["outcome"], &"armored", "super armor while Lights On runs")


func test_an_armored_enemy_soaks_hits_until_poise_breaks() -> void:
	await _arena()
	_foe.armored_now = true
	_foe.poise = 20.0
	var outcomes: Array[StringName] = []
	_director.hit_landed.connect(func(info: Dictionary) -> void: outcomes.append(info["outcome"]))
	var heavy: Dictionary = _light()
	heavy["poise_damage"] = 12
	_swing(_red, heavy, 1)
	_red.get_hitbox().tick(FRAME)
	_red.get_hitbox().clear()
	_swing(_red, heavy, 2)
	_red.get_hitbox().tick(FRAME)
	assert_eq(outcomes, [&"armored", &"stagger"] as Array[StringName])
	assert_almost_eq(_foe.poise, 30.0, 0.0001, "poise refilled after the break")


# ---- actor basics ----

func test_snapshot_has_what_the_resolver_needs() -> void:
	await _arena()
	var snap: Dictionary = _foe.snapshot()
	for key: String in ["id", "team", "airborne", "invulnerable", "poise", "poise_max", "armored", "juggle_count", "launchable", "hp", "position", "weight"]:
		assert_true(snap.has(key), key)
	assert_eq(snap["id"], &"grunt_1")


func test_anchors_are_in_world_space() -> void:
	await _arena()
	assert_almost_eq(_foe.anchor(&"feet").z, 1.2, 0.0001)
	assert_almost_eq(_foe.anchor(&"head").y, 1.0, 0.0001)
	assert_almost_eq(_foe.anchor(&"center").y, 0.5, 0.0001)
	assert_gt(_foe.anchor(&"lamp").y, 0.0)


func test_poise_comes_back_after_a_quiet_moment() -> void:
	await _arena()
	_foe.poise = 10.0
	_foe.apply_hit({"damage": 0, "poise_after": 10.0})
	_foe.poise_regen_delay_ms = 500.0
	_foe.poise_regen_per_s = 20.0
	_foe.clock.step(400000, 1.0)
	_foe.tick_poise(0.4)
	assert_almost_eq(_foe.poise, 10.0, 0.0001, "too soon")
	_foe.clock.step(200000, 1.0)
	_foe.tick_poise(0.5)
	assert_almost_eq(_foe.poise, 20.0, 0.0001)


func test_the_director_never_touches_engine_time_scale() -> void:
	await _arena()
	var before: float = Engine.time_scale
	_parry_at(10.0)
	_swing(_foe, _swipe())
	_foe.get_hitbox().tick(FRAME)
	_tick(30)
	assert_almost_eq(Engine.time_scale, before)
