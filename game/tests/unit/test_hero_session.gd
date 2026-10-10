extends TestCase
## VS-5: HeroSession, what Red carries from room to room (health, battery, sword, form), as plain data.


func test_a_new_session_is_blank_and_means_full() -> void:
	var session: HeroSession = HeroSession.new()
	assert_true(session.is_blank())
	assert_eq(session.health_for(120), 120, "no health recorded: full")
	assert_almost_eq(session.battery_for(100.0), 100.0, 0.001, "no battery recorded: full")
	assert_eq(session.form, &"red")


func test_it_round_trips_through_a_dictionary() -> void:
	var session: HeroSession = HeroSession.new()
	session.hp = 71
	session.hp_max = 120
	session.battery = 34.5
	session.sword = &"scrap_blade"
	session.form = &"small"
	var back: HeroSession = HeroSession.from_dict(session.to_dict())
	assert_eq(back.hp, 71)
	assert_eq(back.hp_max, 120)
	assert_almost_eq(back.battery, 34.5, 0.001)
	assert_eq(back.sword, &"scrap_blade")
	assert_eq(back.form, &"small")
	assert_false(back.is_blank())


func test_old_or_partial_dictionaries_load_with_defaults() -> void:
	var session: HeroSession = HeroSession.from_dict({})
	assert_true(session.is_blank())
	assert_eq(HeroSession.from_dict({"form": ""}).form, &"red")


func test_health_stays_between_one_and_the_rooms_maximum() -> void:
	var session: HeroSession = HeroSession.new()
	session.hp = 70
	assert_eq(session.health_for(120), 70)
	assert_eq(session.health_for(50), 50, "a smaller body keeps what fits")
	session.hp = 0
	assert_eq(session.health_for(120), 120, "a knocked-out 0 never walks into a room")


func test_battery_is_kept_inside_the_capacity() -> void:
	var session: HeroSession = HeroSession.new()
	session.battery = 30.0
	assert_almost_eq(session.battery_for(100.0), 30.0, 0.001)
	assert_almost_eq(session.battery_for(20.0), 20.0, 0.001)
	session.battery = 0.0
	assert_almost_eq(session.battery_for(100.0), 0.0, 0.001, "an empty battery stays empty")


func test_a_duplicate_is_independent() -> void:
	var session: HeroSession = HeroSession.new()
	session.hp = 10
	var copy: HeroSession = session.duplicate_session()
	copy.hp = 99
	assert_eq(session.hp, 10)
