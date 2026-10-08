extends TestCase
## EnemyBrain: the state flow, tokens, attack choice, and repeatability from a seed.

const GRUNT: Dictionary = {
	"brain": {"notice_range_m": 14.0, "notice_ms": 450, "circle_range_m": 4.5, "min_range_m": 2.2, "circle_speed_mult": 0.55,
		"circle_flip_ms": [1500, 3200], "attack_interval_ms": [1400, 3000], "recover_ms": 450, "react_ms": 250, "land_react_ms": 300},
	"attacks": [
		{"move": "swipe", "weight": 1.0, "track_ms": 380, "when": {"max_dist_m": 2.1, "player_airborne": false}},
		{"move": "swipe", "weight": 0.5, "track_ms": 380, "when": {"max_dist_m": 2.1, "player_airborne": true}}],
}


func _view(dist: float, extra: Dictionary = {}) -> Dictionary:
	var view: Dictionary = {"dist_to_player": dist, "player_airborne": false, "player_attacking": false, "has_token": false,
		"state": &"free", "poise_frac": 1.0, "attacks_enabled": true}
	view.merge(extra, true)
	return view


func _brain(seed_value: int = 1) -> EnemyBrain:
	return EnemyBrain.create(GRUNT, seed_value)


## Run the brain in 16 ms steps until `predicate` says stop (or 20 s pass). Returns the time reached.
func _run_until(brain: EnemyBrain, view: Dictionary, start_ms: float, wanted: StringName) -> float:
	var now: float = start_ms
	while now < start_ms + 20000.0:
		brain.step(now, view)
		if brain.state() == wanted:
			return now
		now += 16.0
	return -1.0


func test_idle_until_the_player_is_in_range() -> void:
	var brain: EnemyBrain = _brain()
	var intent: Dictionary = brain.step(0.0, _view(30.0))
	assert_eq(brain.state(), &"idle")
	assert_eq(intent["move_dir"], Vector3.ZERO)
	assert_false(intent["face_player"])
	brain.step(16.0, _view(10.0))
	assert_eq(brain.state(), &"notice")


func test_notice_then_approach_then_circle() -> void:
	var brain: EnemyBrain = _brain()
	brain.step(0.0, _view(10.0))
	var intent: Dictionary = brain.step(100.0, _view(10.0))
	assert_eq(brain.state(), &"notice")
	assert_true(intent["face_player"], "it turns to look at you")
	assert_eq(intent["move_dir"], Vector3.ZERO)
	intent = brain.step(500.0, _view(10.0))
	assert_eq(brain.state(), &"approach")
	intent = brain.step(516.0, _view(10.0))
	assert_almost_eq((intent["move_dir"] as Vector3).z, 1.0, 0.0001)
	brain.step(532.0, _view(4.0))
	assert_eq(brain.state(), &"circle")


func test_circling_moves_sideways_and_keeps_its_distance() -> void:
	var brain: EnemyBrain = _brain()
	brain.step(0.0, _view(4.0))
	brain.step(500.0, _view(4.0))
	brain.step(520.0, _view(4.0))
	assert_eq(brain.state(), &"circle")
	var intent: Dictionary = brain.step(540.0, _view(4.0))
	var dir: Vector3 = intent["move_dir"]
	assert_gt(absf(dir.x), 0.1, "sideways")
	assert_almost_eq(dir.z, 0.0, 0.0001)
	intent = brain.step(560.0, _view(1.5))
	assert_lt((intent["move_dir"] as Vector3).z, 0.0, "too close: back off")
	intent = brain.step(580.0, _view(8.0))
	assert_gt((intent["move_dir"] as Vector3).z, 0.0, "too far: close in")


func test_it_asks_for_a_token_when_ready_and_only_attacks_with_one() -> void:
	var brain: EnemyBrain = _brain()
	var view: Dictionary = _view(2.0)
	var asked_at: float = -1.0
	var now: float = 0.0
	while now < 8000.0 and asked_at < 0.0:
		var intent: Dictionary = brain.step(now, view)
		assert_eq(intent["start_move"], &"", "no attack without a token")
		if intent["want_token"]:
			asked_at = now
		now += 16.0
	assert_gt(asked_at, 1000.0, "it waits its attack interval first")
	view["has_token"] = true
	var attacked: Dictionary = brain.step(now, view)
	assert_eq(attacked["start_move"], &"swipe")
	assert_eq(brain.state(), &"attack")


func test_no_attacks_when_the_knob_is_off() -> void:
	var brain: EnemyBrain = _brain()
	var view: Dictionary = _view(2.0, {"attacks_enabled": false, "has_token": true})
	var now: float = 0.0
	while now < 15000.0:
		var intent: Dictionary = brain.step(now, view)
		assert_eq(intent["start_move"], &"")
		assert_false(intent["want_token"])
		now += 16.0
	assert_ne(brain.state(), &"attack")


func test_a_token_holder_out_of_reach_closes_in_then_attacks() -> void:
	var brain: EnemyBrain = _brain()
	var view: Dictionary = _view(3.5)
	var now: float = 0.0
	while now < 8000.0 and not brain.step(now, view)["want_token"]:
		now += 16.0
	view["has_token"] = true
	var intent: Dictionary = brain.step(now, view)
	assert_eq(intent["start_move"], &"", "3.5 m is out of reach")
	assert_gt((intent["move_dir"] as Vector3).z, 0.0, "so it closes in")
	assert_true(intent["want_token"], "and keeps the token")
	view["dist_to_player"] = 1.9
	intent = brain.step(now + 16.0, view)
	assert_eq(intent["start_move"], &"swipe")


func test_the_attack_tracks_the_player_only_for_track_ms() -> void:
	var brain: EnemyBrain = _brain()
	var view: Dictionary = _view(2.0)
	var now: float = 0.0
	while now < 8000.0 and not brain.step(now, view)["want_token"]:
		now += 16.0
	view["has_token"] = true
	brain.step(now, view)
	assert_eq(brain.state(), &"attack")
	assert_true(brain.step(now + 100.0, view)["face_player"])
	assert_true(brain.step(now + 379.0, view)["face_player"])
	assert_false(brain.step(now + 381.0, view)["face_player"], "the aim locks so the wind-up can be read and dodged")


func test_move_finished_leads_to_recover_then_circle() -> void:
	var brain: EnemyBrain = _brain()
	var view: Dictionary = _view(2.0)
	var now: float = 0.0
	while now < 8000.0 and not brain.step(now, view)["want_token"]:
		now += 16.0
	view["has_token"] = true
	brain.step(now, view)
	brain.notify(&"move_finished")
	brain.step(now + 16.0, view)
	assert_eq(brain.state(), &"recover")
	brain.step(now + 600.0, view)
	assert_eq(brain.state(), &"circle")


func test_getting_hit_interrupts_the_attack_and_waits_for_the_body() -> void:
	var brain: EnemyBrain = _brain()
	var view: Dictionary = _view(2.0)
	var now: float = 0.0
	while now < 8000.0 and not brain.step(now, view)["want_token"]:
		now += 16.0
	view["has_token"] = true
	brain.step(now, view)
	assert_eq(brain.state(), &"attack")
	brain.notify(&"hit")
	view["state"] = &"busy"
	brain.step(now + 16.0, view)
	assert_eq(brain.state(), &"react")
	var intent: Dictionary = brain.step(now + 2000.0, view)
	assert_eq(brain.state(), &"react", "still busy: stays put however long")
	assert_eq(intent["move_dir"], Vector3.ZERO)
	view["state"] = &"free"
	view["has_token"] = false
	brain.step(now + 2016.0, view)
	assert_eq(brain.state(), &"react", "a short pause after it is free again")
	brain.step(now + 2300.0, view)
	assert_eq(brain.state(), &"circle")


func test_launch_parry_and_stagger_events_all_send_it_to_react() -> void:
	for event: StringName in [&"launched", &"parried", &"staggered", &"hit"]:
		var brain: EnemyBrain = _brain()
		brain.step(0.0, _view(4.0))
		brain.step(500.0, _view(4.0))
		brain.notify(event)
		brain.step(520.0, _view(4.0, {"state": &"busy"}))
		assert_eq(brain.state(), &"react", String(event))


func test_a_dead_body_ends_the_brain() -> void:
	var brain: EnemyBrain = _brain()
	brain.step(0.0, _view(4.0))
	var intent: Dictionary = brain.step(16.0, _view(4.0, {"state": &"dead"}))
	assert_eq(brain.state(), &"dead")
	assert_eq(intent["move_dir"], Vector3.ZERO)
	brain.notify(&"hit")
	assert_eq(brain.state(), &"dead", "events cannot revive it")


func test_the_same_seed_gives_the_same_fight() -> void:
	var log_a: Array[String] = _trace(_brain(42))
	var log_b: Array[String] = _trace(_brain(42))
	var log_c: Array[String] = _trace(_brain(43))
	assert_eq(log_a, log_b)
	assert_ne(log_a, log_c, "another seed behaves differently")


func _trace(brain: EnemyBrain) -> Array[String]:
	var out: Array[String] = []
	var view: Dictionary = _view(2.0, {"has_token": true})
	var now: float = 0.0
	while now < 12000.0:
		var intent: Dictionary = brain.step(now, view)
		if intent["start_move"] != &"":
			out.append("attack@%d" % int(now))
			brain.notify(&"move_finished")
		now += 16.0
	return out


func test_the_attack_choice_respects_the_when_block() -> void:
	var data: Dictionary = {"brain": GRUNT["brain"], "attacks": [
		{"move": "ground_only", "weight": 1.0, "when": {"max_dist_m": 2.0, "player_airborne": false}},
		{"move": "air_only", "weight": 1.0, "when": {"max_dist_m": 2.0, "player_airborne": true}}]}
	for airborne: bool in [false, true]:
		var brain: EnemyBrain = EnemyBrain.create(data, 5)
		var view: Dictionary = _view(1.5, {"has_token": true, "player_airborne": airborne})
		var picked: StringName = &""
		var now: float = 0.0
		while now < 8000.0 and picked == &"":
			picked = brain.step(now, view)["start_move"]
			now += 16.0
		assert_eq(picked, &"air_only" if airborne else &"ground_only")
