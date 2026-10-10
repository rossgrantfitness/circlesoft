extends TestCase
## The pure parts of the combat FX (scripts/combat/fx/*, scripts/camera/camera_shake.gd) and the fx.json data.


# ---- CameraShake ----

func test_shake_is_smooth_bounded_and_dies_in_real_time() -> void:
	var shaker: CameraShake = CameraShake.new()
	assert_false(shaker.is_active())
	assert_eq(shaker.step(0.016), Vector3.ZERO)
	shaker.add({"amplitude_m": 0.1, "duration_s": 0.3, "frequency_hz": 20.0})
	assert_true(shaker.is_active())
	var previous: Vector3 = Vector3.ZERO
	var biggest_jump: float = 0.0
	var peak: float = 0.0
	for frame: int in 30:
		var offset: Vector3 = shaker.step(1.0 / 120.0)
		peak = maxf(peak, offset.length())
		biggest_jump = maxf(biggest_jump, offset.distance_to(previous))
		previous = offset
		assert_eq(offset.z, 0.0, "never toward or away from the scene")
	assert_le(peak, 0.1 * 0.6 * 2.1, "bounded by the amplitude")
	# a sine moves at most amp * w * dt per frame; random per-frame noise would jump by the full amplitude
	assert_lt(biggest_jump, 0.1 * 0.6 * 1.9 * TAU * 20.0 / 120.0 * 1.1, "smooth: no stepped jumps between frames")
	assert_lt(Vector3(shaker.step(0.0)).length(), 0.1, "still bounded")
	for frame: int in 60:
		shaker.step(1.0 / 120.0)
	assert_false(shaker.is_active(), "0.3 s later it is over")
	assert_eq(shaker.step(0.016), Vector3.ZERO)
	assert_eq(shaker.amplitude_now(), 0.0)


func test_shakes_add_up_but_are_capped_and_an_empty_profile_does_nothing() -> void:
	var shaker: CameraShake = CameraShake.new()
	shaker.add({})
	shaker.add({"amplitude_m": 0.0, "duration_s": 1.0})
	assert_false(shaker.is_active())
	shaker.add({"amplitude_m": 0.05, "duration_s": 0.2})
	var one: float = shaker.amplitude_now()
	shaker.add({"amplitude_m": 0.05, "duration_s": 0.2})
	assert_gt(shaker.amplitude_now(), one, "two shakes are stronger than one")
	for i: int in 20:
		shaker.add({"amplitude_m": 0.2, "duration_s": 0.5})
	assert_le(shaker.amplitude_now(), CameraShake.MAX_AMPLITUDE_M, "capped")
	shaker.clear()
	assert_false(shaker.is_active())
	shaker.add({"amplitude_m": 0.1, "duration_s": 0.3}, 2.0)
	assert_almost_eq(shaker.amplitude_now(), 0.2, 0.001, "mult scales it")


# ---- HitSpark ----

func test_a_burst_has_the_right_count_stays_in_its_cone_and_is_repeatable() -> void:
	var profile: Dictionary = DataDB.get_dict(CameraShake.DATA_ID)["sparks"]["heavy"]
	var rng_a: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_a.seed = 42
	var rng_b: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_b.seed = 42
	var direction: Vector3 = Vector3(0.0, 0.5, 1.0).normalized()
	var first: Array[Dictionary] = HitSpark.make_particles(profile, direction, rng_a)
	var second: Array[Dictionary] = HitSpark.make_particles(profile, direction, rng_b)
	assert_eq(first.size(), int(profile["count"]))
	var half_cone: float = deg_to_rad(float(profile["cone_deg"])) * 0.5
	for index: int in first.size():
		assert_eq(first[index]["vel"], second[index]["vel"], "same seed, same burst")
		var velocity: Vector3 = first[index]["vel"]
		assert_le(velocity.angle_to(direction), half_cone + 0.001, "inside the cone")
		assert_ge(velocity.length(), float(profile["speed"][0]) - 0.001)
		assert_le(velocity.length(), float(profile["speed"][1]) + 0.001)


func test_streaks_fall_slow_down_and_fade_to_nothing() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	var parts: Array[Dictionary] = HitSpark.make_particles({"count": 6, "speed": [4.0, 4.0], "life_s": 0.2, "cone_deg": 20.0}, Vector3.RIGHT, rng)
	var speed_before: float = (parts[0]["vel"] as Vector3).length()
	var height_before: float = (parts[0]["vel"] as Vector3).y
	HitSpark.step_particles(parts, 0.05, 9.0)
	assert_lt((parts[0]["vel"] as Vector3).length(), speed_before + 0.5, "drag")
	assert_lt((parts[0]["vel"] as Vector3).y, height_before, "gravity pulls it down")
	var arrays: Array = HitSpark.streak_arrays(parts, Vector3(0.0, 1.0, 5.0), 0.3, 0.04, 0.2, Color("#ffb347"), Color.WHITE, Vector3.ZERO)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert_eq(vertices.size(), 6 * 6, "two triangles per streak")
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	assert_lt(colors[0].a, 1.0, "fading")
	for i: int in 10:
		HitSpark.step_particles(parts, 0.05, 9.0)
	var gone: Array = HitSpark.streak_arrays(parts, Vector3(0.0, 1.0, 5.0), 0.3, 0.04, 0.2, Color.WHITE, Color.WHITE, Vector3.ZERO)
	assert_eq((gone[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), 0, "past their life they are not drawn")


# ---- DashStreak, TelegraphCue, FlareFx ----

func test_dash_lines_trail_behind_along_the_travel_direction() -> void:
	var config: Dictionary = DataDB.get_dict(CameraShake.DATA_ID)["dash"]
	var arrays: Array = DashStreak.line_arrays(Vector3.FORWARD, config, Color.WHITE, 0.0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert_eq(vertices.size(), int(config["count"]) * 6)
	var farthest: float = 0.0
	for vertex: Vector3 in vertices:
		farthest = maxf(farthest, vertex.z)
		assert_ge(vertex.y, 0.0, "above the floor")
	assert_almost_eq(farthest, float(config["length_m"]), 0.01, "they stretch back (+Z is behind a dash toward -Z)")
	var late: PackedVector3Array = DashStreak.line_arrays(Vector3.FORWARD, config, Color.WHITE, 1.0)[Mesh.ARRAY_VERTEX]
	var shortest: float = 0.0
	for vertex: Vector3 in late:
		shortest = maxf(shortest, vertex.z)
	assert_lt(shortest, farthest, "and are left behind as the effect ends")


func test_the_telegraph_ring_closes_on_the_impact_and_kinds_come_from_data() -> void:
	assert_almost_eq(TelegraphCue.ring_radius_at(0.0, 0.6, 1.5, 0.3), 1.5, 0.0001)
	assert_almost_eq(TelegraphCue.ring_radius_at(0.6, 0.6, 1.5, 0.3), 0.3, 0.0001, "arrives exactly at impact")
	assert_gt(TelegraphCue.ring_radius_at(0.3, 0.6, 1.5, 0.3), TelegraphCue.ring_radius_at(0.45, 0.6, 1.5, 0.3), "and keeps closing")
	var kinds: Dictionary = DataDB.get_dict(CameraShake.DATA_ID)["telegraph"]["kinds"]
	assert_eq(TelegraphCue.kind_for({"parryable": true}, kinds), "parryable")
	assert_eq(TelegraphCue.kind_for({"parryable": false}, kinds), "unparryable")
	assert_eq(TelegraphCue.kind_for({"parryable": true, "telegraph_kind": "dodge_only"}, kinds), "dodge_only", "a new kind from the designer needs no code")
	assert_eq(TelegraphCue.kind_for({"parryable": true, "telegraph_kind": "nonsense"}, kinds), "parryable", "an unknown kind falls back")
	assert_ne(str(kinds["parryable"]["color"]), str(kinds["unparryable"]["color"]), "the colour tells you which answer works")


func test_the_flare_lamp_bursts_settles_and_fades() -> void:
	var config: Dictionary = DataDB.get_dict(CameraShake.DATA_ID)["flare"]
	var peak: float = float(config["lamp"]["energy_peak"])
	var hold: float = float(config["lamp"]["energy_hold"])
	assert_eq(FlareFx.lamp_energy(0.0, 1.5, config), 0.0)
	assert_almost_eq(FlareFx.lamp_energy(float(config["burst_s"]), 1.5, config), peak, 0.001, "the burst reaches the peak")
	assert_almost_eq(FlareFx.lamp_energy(0.8, 1.5, config), hold, 0.001, "then holds")
	assert_lt(FlareFx.lamp_energy(1.4, 1.5, config), hold, "fades at the end")
	assert_eq(FlareFx.lamp_energy(1.5, 1.5, config), 0.0)
	assert_almost_eq(FlareFx.world_amount(0.8, 1.5, config), 1.0, 0.001, "the cool world is fully in mid-flare")
	assert_eq(FlareFx.world_amount(2.0, 1.5, config), 0.0)


# ---- the data and the sound rules ----

func test_every_shake_profile_has_what_the_camera_reads() -> void:
	var shakes: Dictionary = DataDB.get_dict(CameraShake.DATA_ID)["shake"]
	for id: String in shakes:
		for key: String in ["amplitude_m", "duration_s", "frequency_hz"]:
			assert_true((shakes[id] as Dictionary).has(key), "%s.%s" % [id, key])
		assert_lt(float(shakes[id]["amplitude_m"]), 0.2, id + " stays small")
		assert_lt(float(shakes[id]["duration_s"]), 0.6)


func test_every_shake_and_spark_a_move_asks_for_exists() -> void:
	var fx: Dictionary = DataDB.get_dict(CameraShake.DATA_ID)
	var sets: Dictionary = DataDB.get_dict("combat/moves")["sets"]
	for owner_id: String in sets:
		for move_id: String in (sets[owner_id]["moves"] as Dictionary):
			var hit: Dictionary = sets[owner_id]["moves"][move_id].get("hit", {})
			if hit.has("shake"):
				assert_true(fx["shake"].has(str(hit["shake"])), "%s.%s shake %s" % [owner_id, move_id, hit["shake"]])
			if hit.has("spark"):
				var spark: String = str(hit["spark"])
				assert_true(fx["sparks"].has(spark) or fx["spark_aliases"].has(spark), "%s.%s spark %s" % [owner_id, move_id, spark])


func test_every_sound_id_exists_and_the_hud_ones_are_not_ours() -> void:
	var sounds: Dictionary = DataDB.get_dict(CameraShake.DATA_ID)["sounds"]
	var sfx: Dictionary = DataDB.get_dict("audio/sfx")["sfx"]
	for key: String in sounds:
		if key.begins_with("_"):
			continue
		assert_true(sfx.has(str(sounds[key])), "sfx.json has %s" % sounds[key])
		assert_false(CombatFx.NOT_OURS.has(str(sounds[key])), "%s is the HUD's" % sounds[key])
	var covered: Dictionary = {}
	for key: String in sounds:
		covered[str(sounds[key])] = true
	for id: String in sfx:
		if id.begins_with("combat_") and not CombatFx.NOT_OURS.has(id) and id != "combat_brute_slam":
			assert_true(covered.has(id), "%s is played by CombatFx (or named by a move)" % id)


func test_spark_and_hit_sound_picks() -> void:
	var fx: Dictionary = DataDB.get_dict(CameraShake.DATA_ID)
	var sparks: Dictionary = fx["sparks"]
	var by_outcome: Dictionary = fx["spark_by_outcome"]
	var aliases: Dictionary = fx["spark_aliases"]
	assert_eq(CombatFx.spark_for({"outcome": "guarded", "spark": "slash"}, by_outcome, aliases, sparks), "guard")
	assert_eq(CombatFx.spark_for({"outcome": "hit", "spark": "launch"}, by_outcome, aliases, sparks), "launch")
	assert_eq(CombatFx.spark_for({"outcome": "hit", "spark": "slam"}, by_outcome, aliases, sparks), "heavy", "alias")
	assert_eq(CombatFx.spark_for({"outcome": "hit", "spark": "mystery", "airborne": true}, by_outcome, aliases, sparks), "air")
	assert_eq(CombatFx.spark_for({"outcome": "hit"}, by_outcome, aliases, sparks), "slash")
	assert_eq(CombatFx.hit_sound_key_for({"launch": true}), "launch")
	assert_eq(CombatFx.hit_sound_key_for({"airborne": true, "shake": "light"}), "hit_air")
	assert_eq(CombatFx.hit_sound_key_for({"shake": "heavy"}), "hit_heavy")
	assert_eq(CombatFx.hit_sound_key_for({"shake": "light"}), "hit_light")
