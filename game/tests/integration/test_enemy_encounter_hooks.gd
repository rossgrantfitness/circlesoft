extends TestCase
## What the encounter runner hands each enemy (data/slice/encounters.json): `tune` numbers, a starting `state`, and the
## loader's damage scale against Red (rules.vs_form). Enemy side of the slice hookups.

var _kit: HackKit = null


func _setup(attack_enemies: bool = false) -> void:
	_kit = HackKit.new(self)
	await _kit.arena(attack_enemies)
	_kit.director.feel.set_value("enemy_damage_scale", 1.0)
	_kit.director.feel.set_value("enemy_windup_scale", 1.0)


func _first_hit_damage(enemy: ActionEnemy) -> int:
	var before: int = _kit.red.hp
	await _kit.until(func() -> bool: return _kit.red.hp < before, 600)
	return before - _kit.red.hp


# ---- tune ----

func test_tune_changes_the_brain_numbers() -> void:
	await _setup()
	var turret: ActionEnemy = _kit.spawn(HackKit.TURRET_SCENE, Vector3(0, 0, 8), PI)
	turret.apply_tune({"attack_interval_ms": [111, 222]})
	assert_eq(turret.tune["attack_interval_ms"], [111, 222])
	var numbers: Dictionary = turret.brain._brain
	assert_eq(numbers["attack_interval_ms"], [111, 222])


func test_tune_changes_how_it_defends() -> void:
	await _setup()
	var brute: ActionEnemy = _kit.spawn(HackKit.BRUTE_SCENE, Vector3(0, 0, 8), PI)
	var other: ActionEnemy = _kit.spawn(HackKit.BRUTE_SCENE, Vector3(4, 0, 8), PI)
	var before: float = float(brute.data["behaviour"]["defend"]["block_chance"])
	brute.apply_tune({"block_chance": 0.9})
	assert_almost_eq(float(brute.data["behaviour"]["defend"]["block_chance"]), 0.9, 0.0001)
	assert_almost_eq(float(other.data["behaviour"]["defend"]["block_chance"]), before, 0.0001, "only that one enemy changes")
	assert_almost_eq(float(CombatData.enemies()["enemies"]["brute"]["behaviour"]["defend"]["block_chance"]), before, 0.0001,
		"the shared data is never edited")


func test_an_unknown_tune_key_is_kept_and_does_not_crash() -> void:
	await _setup()
	var grunt: ActionEnemy = _kit.grunt(Vector3(0, 0, 20))
	grunt.apply_tune({"not_a_number": 3})
	assert_eq(grunt.tune["not_a_number"], 3)


func test_tune_given_before_the_enemy_is_in_the_tree_is_applied_when_it_is() -> void:
	await _setup()
	var enemy: ActionEnemy = (load(HackKit.BRUTE_SCENE) as PackedScene).instantiate() as ActionEnemy
	enemy.apply_tune({"block_chance": 0.77})
	enemy.apply_state(&"ambush")
	enemy.position = Vector3(0, 0, 30)
	add_to_root(enemy)
	enemy.set_physics_process(false)
	assert_almost_eq(float(enemy.data["behaviour"]["defend"]["block_chance"]), 0.77, 0.0001)
	assert_eq(enemy.behaviour_state, &"ambush")


# ---- state ----

func test_ambush_notices_only_when_red_is_close() -> void:
	await _setup()
	var normal: ActionEnemy = _kit.grunt(Vector3(0, 0, 10))
	var ambusher: ActionEnemy = _kit.grunt(Vector3(0, 0, -10))
	ambusher.apply_state(&"ambush")
	await _kit.frames(90)
	assert_eq(ambusher.brain.state(), EnemyBrain.IDLE, "10 m is outside half its notice range")
	assert_ne(normal.brain.state(), EnemyBrain.IDLE, "an ordinary grunt at 10 m has noticed her")
	_kit.red.global_position = Vector3(0, 0.02, -5)
	await _kit.frames(30)
	assert_ne(ambusher.brain.state(), EnemyBrain.IDLE, "close up it goes at once (150 ms)")


func test_idle_states_stand_still() -> void:
	await _setup()
	var guard: ActionEnemy = _kit.grunt(Vector3(0, 0, 40))
	guard.apply_state(&"idle_at_barrel")
	var start: Vector3 = guard.global_position
	await _kit.frames(120)
	assert_eq(guard.behaviour_state, &"idle_at_barrel")
	assert_lt(guard.global_position.distance_to(start), 0.05)


func test_patrol_walks_a_beat_and_stops_when_red_is_noticed() -> void:
	await _setup()
	var grunt: ActionEnemy = _kit.grunt(Vector3(0, 0, 40))
	grunt.rotation.y = 0.0
	grunt.apply_state(&"patrol")
	var start: Vector3 = grunt.global_position
	await _kit.frames(150)
	var walked: float = grunt.global_position.distance_to(start)
	assert_gt(walked, 1.0, "it walks its beat")
	assert_lt(walked, 6.0, "and stays near its post")
	_kit.red.global_position = Vector3(0, 0.02, grunt.global_position.z - 8.0)
	await _kit.frames(60)
	assert_ne(grunt.brain.state(), EnemyBrain.IDLE, "it noticed her")
	assert_gt(grunt.global_position.distance_to(_kit.red.global_position), 0.0)


# ---- the loader's damage scale ----

func _next_hit_on_red(limit: int = 900) -> int:
	_kit.red.hp = _kit.red.hp_max
	var before: int = _kit.red.hp
	await _kit.until(func() -> bool: return _kit.red.hp < before, limit)
	return before - _kit.red.hp


func test_the_loader_takes_scaled_damage_and_red_does_not() -> void:
	var table: Dictionary = (CombatData.read_json("res://data/slice/encounters.json")["rules"] as Dictionary)["vs_form"]
	var scale: float = float((table["small"] as Dictionary)["damage_mult"])
	assert_almost_eq(scale, 0.55, 0.0001)
	await _setup(true)
	var grunt: ActionEnemy = _kit.grunt(Vector3(0, 0, 1.6))
	await _kit.settle()
	var red_damage: int = await _next_hit_on_red()
	assert_gt(red_damage, 0, "a grunt swipe lands on Red")
	_kit.red.set_scale_profile(ScaleProfile.get_form(ScaleProfile.FORM_SMALL))
	_kit.red.global_position = Vector3(0, 0.02, 0)
	grunt.global_position = Vector3(0, 0, 1.0)
	var loader_damage: int = await _next_hit_on_red()
	assert_gt(loader_damage, 0, "and on the loader")
	assert_eq(loader_damage, int(roundf(float(red_damage) * scale)), "the loader takes 0.55 of it")
	_kit.red.set_scale_profile(ScaleProfile.get_form(ScaleProfile.FORM_RED))
	var again: int = await _next_hit_on_red()
	assert_eq(again, red_damage, "back in her own body the scale is gone")
