extends TestCase
## BossPhases: the phase list of the Kasp fight (rig, transition, the Heap) and where a knock-out in each restarts.


func _phases() -> BossPhases:
	return BossPhases.load_file("hushmaster.json")


func test_the_fight_has_three_phases_in_order() -> void:
	var phases: BossPhases = _phases()
	assert_eq(phases.ids(), [&"rig", &"transition", &"mech"] as Array[StringName])
	assert_eq(phases.boss_id(), &"hushmaster")


func test_forms_follow_the_pitch() -> void:
	var phases: BossPhases = _phases()
	assert_eq(phases.form_of(&"rig"), &"red")
	assert_eq(phases.form_of(&"transition"), &"red")
	assert_eq(phases.form_of(&"mech"), &"huge")


func test_the_transition_is_scripted_and_the_others_are_fights() -> void:
	var phases: BossPhases = _phases()
	assert_true(phases.is_scripted(&"transition"))
	assert_false(phases.is_scripted(&"rig"))
	assert_false(phases.is_scripted(&"mech"))


func test_start_advance_and_the_end() -> void:
	var phases: BossPhases = _phases()
	assert_true(phases.start())
	assert_eq(phases.current(), &"rig")
	assert_eq(phases.advance(), &"transition")
	assert_eq(phases.advance(), &"mech")
	assert_true(phases.is_last())
	assert_eq(phases.advance(), &"", "nothing after the Heap")
	assert_eq(phases.current(), &"mech")


func test_start_can_jump_to_a_phase_for_a_retry() -> void:
	var phases: BossPhases = _phases()
	assert_true(phases.start(&"mech"))
	assert_eq(phases.current(), &"mech")
	assert_false(phases.start(&"nope"))


func test_a_knock_out_in_the_rig_restarts_at_the_gate_on_foot_with_the_health_she_had() -> void:
	var retry: Dictionary = _phases().retry_for(&"rig")
	assert_eq(retry["spawn"], "retry_phase1")
	assert_eq(retry["form"], &"red")
	assert_false(bool(retry["full_health"]))
	assert_eq(retry["restart_phase"], &"rig")


func test_a_knock_out_in_the_heap_restarts_already_docked_at_full_health() -> void:
	var retry: Dictionary = _phases().retry_for(&"mech")
	assert_eq(retry["spawn"], "retry_phase2")
	assert_eq(retry["form"], &"huge")
	assert_true(bool(retry["full_health"]))
	assert_eq(retry["restart_phase"], &"mech")


func test_the_transition_has_no_restart_it_skips_to_the_next_step() -> void:
	var retry: Dictionary = _phases().retry_for(&"transition")
	assert_eq(retry["rule"], BossPhases.RETRY_SKIP)
	assert_eq(retry["spawn"], "")
	assert_eq(retry["restart_phase"], &"mech")


func test_a_room_entered_at_a_retry_marker_resumes_that_phase() -> void:
	var phases: BossPhases = _phases()
	assert_eq(phases.phase_for_spawn("retry_phase1"), &"rig")
	assert_eq(phases.phase_for_spawn("retry_phase2"), &"mech")
	assert_eq(phases.phase_for_spawn("from_j5"), &"", "the front door is a fresh fight, not a retry")


func test_the_rig_tops_the_battery_up_to_60_when_it_starts() -> void:
	assert_eq(_phases().battery_floor(&"rig"), 60.0)
	assert_eq(_phases().battery_floor(&"mech"), 0.0)


func test_the_fight_numbers_name_the_markers() -> void:
	var phases: BossPhases = _phases()
	assert_eq(phases.fight_number(&"rig"), 1)
	assert_eq(phases.fight_number(&"mech"), 2)
	assert_eq(phases.fight_number(&"transition"), 0)


func test_the_ending_sets_the_slice_done_flag() -> void:
	assert_eq(_phases().ending()["sets_flag"], "slice_done")
