extends TestCase
## The battle HUD binds to a controller (here a stub that emits the documented signals), builds its
## parts on the UI stage and answers command_needed with submit_command.

const HUD_SCENE: String = "res://scenes/ui/battle/battle_hud.tscn"

var audio_fake: FakeAudio = null


func _make() -> Array:
	audio_fake = FakeAudio.new()
	var hud: BattleHud = (load(HUD_SCENE) as PackedScene).instantiate() as BattleHud
	hud.manual_ticks = true
	hud.animations_enabled = false
	hud.audio.target = audio_fake
	add_to_root(hud)
	var stub: BattleHudStub = BattleHudStub.new()
	hud.bind(stub)
	return [hud, stub]


func test_scene_loads_and_builds_its_parts() -> void:
	var pair: Array = _make()
	var hud: BattleHud = pair[0]
	assert_not_null(hud.get_menu())
	assert_not_null(hud.get_party_panel())
	assert_not_null(hud.get_turn_row())
	assert_not_null(hud.get_banner())
	assert_eq(hud.size, Vector2(384, 216))
	assert_eq(hud.get_mode(), BattleHud.Mode.IDLE)


func test_bind_connects_every_documented_signal() -> void:
	var pair: Array = _make()
	var hud: BattleHud = pair[0]
	var stub: BattleHudStub = pair[1]
	assert_true(hud.is_bound())
	var documented: PackedStringArray = ["battle_started", "round_started", "turn_started", "command_needed", "action_started",
			"press_judged", "hit", "stats_changed", "status_changed", "combatant_down", "combatant_revived", "combatant_fled",
			"action_finished", "message", "battle_ended"]
	for name: String in documented:
		assert_gt(stub.get_signal_connection_list(name).size(), 0, "%s is connected" % name)
	hud.unbind()
	assert_false(hud.is_bound())
	assert_eq(stub.get_signal_connection_list("hit").size(), 0)


func test_battle_started_fills_the_roster_and_party_panel() -> void:
	var pair: Array = _make()
	var hud: BattleHud = pair[0]
	var stub: BattleHudStub = pair[1]
	stub.start()
	assert_eq(hud.roster.ids("party"), ["red", "otis", "mox"])
	assert_eq(hud.roster.ids("enemy"), ["e1", "e2", "e3"])
	assert_eq(hud.get_party_panel().get_shown("otis")["hp"], 61.0)


func test_a_snapshot_taken_at_bind_time_is_used() -> void:
	var stub: BattleHudStub = BattleHudStub.new()
	stub.start()
	var hud: BattleHud = (load(HUD_SCENE) as PackedScene).instantiate() as BattleHud
	hud.manual_ticks = true
	add_to_root(hud)
	hud.bind(stub)
	assert_eq(hud.roster.ids("party").size(), 3)


func test_stats_and_status_signals_update_the_roster() -> void:
	var pair: Array = _make()
	var hud: BattleHud = pair[0]
	var stub: BattleHudStub = pair[1]
	stub.start()
	stub.stats_changed.emit("red", 10, 42, 3, 12)
	assert_eq(hud.roster.get_member("red")["hp"], 10)
	assert_eq(hud.roster.get_member("red")["juice"], 3)
	stub.status_changed.emit("red", "noise_ticket", true)
	assert_true(hud.roster.has_status("red", "noise_ticket"))
	stub.status_changed.emit("red", "noise_ticket", false)
	assert_false(hud.roster.has_status("red", "noise_ticket"))
	stub.combatant_down.emit("otis")
	assert_true(hud.roster.is_down("otis"))
	stub.combatant_revived.emit("otis")
	assert_false(hud.roster.is_down("otis"))
	stub.combatant_fled.emit("e1")
	assert_true(hud.roster.is_out("e1"))


func test_turn_order_row_follows_the_round_signals() -> void:
	var pair: Array = _make()
	var hud: BattleHud = pair[0]
	var stub: BattleHudStub = pair[1]
	stub.start()
	stub.round_started.emit(1, ["red", "e1", "otis", "e2", "mox", "e3"], ["red", "otis", "e1", "mox", "e2", "e3"])
	var row: BattleTurnRow = hud.get_turn_row()
	assert_eq(row.get_now_ids(), ["red", "e1", "otis", "e2", "mox", "e3"])
	assert_eq(row.get_next_ids().size(), 6)
	stub.turn_started.emit("otis")
	assert_eq(row.get_now_ids(), ["otis", "e2", "mox", "e3"], "those who acted leave the row")
	assert_eq(row.get_current_id(), "otis")
	assert_eq(hud.get_party_panel().get_active(), "otis")
	stub.combatant_down.emit("e2")
	assert_eq(row.get_now_ids(), ["otis", "mox", "e3"], "the fallen drop out")
	stub.turn_started.emit("e3")
	assert_eq(hud.get_party_panel().get_active(), "", "no party highlight on an enemy turn")


func test_messages_show_in_the_banner() -> void:
	var pair: Array = _make()
	var hud: BattleHud = pair[0]
	var stub: BattleHudStub = pair[1]
	stub.start()
	stub.message.emit("Can't run from this one!")
	assert_eq(hud.get_banner().get_current_text(), "Can't run from this one!")
	stub.message.emit("Noise Ticket! No skills.")
	assert_eq(hud.get_banner().get_queue_size(), 1)
	hud.get_banner().tick(3.0)
	assert_eq(hud.get_banner().get_current_text(), "Noise Ticket! No skills.")


func test_the_hud_is_modal_while_bound() -> void:
	var pair: Array = _make()
	var hud: BattleHud = pair[0]
	assert_true(hud.is_in_group(UiStage.MODAL_GROUP))
	hud.unbind()
	assert_false(hud.is_in_group(UiStage.MODAL_GROUP))
