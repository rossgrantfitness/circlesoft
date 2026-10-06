class_name BattleFlowKit
extends RefCounted
## Helpers for the tests that play a real fight through Main: a Main with the test room, setups on a
## virtual clock (Auto-Timing and a command policy, or a hopeless party for a loss), a stage with
## shortened waits, and a "press the HUD's end-screen button" step.

const MAIN_SCENE: String = "res://scenes/core/main.tscn"
const WAIT_LIMIT_MS: int = 40000
const END_HOLD_S: float = 0.02
const KO_FREEZE_MS: int = 40


## A Main that starts straight in the test room with a tame (instant) battle stage.
static func make_main(test: TestCase) -> Main:
	var main: Main = (load(MAIN_SCENE) as PackedScene).instantiate() as Main
	main.show_title = false
	main.debug_overlay_enabled = false
	main.battle_transitions = false
	test.add_to_root(main)
	return main


static func shorten_stage(stage: BattleScene) -> void:
	var db: Node = stage.get_tree().root.get_node("DataDB")
	var data: Dictionary = (db.call("get_dict", "battle_stage/stage") as Dictionary).duplicate(true)
	data["end"]["hold_s"] = END_HOLD_S
	data["ko"]["freeze_ms"] = KO_FREEZE_MS
	stage.tuning = BattleStageTuning.from_dict(data)


## The party wins on a virtual clock: Auto-Timing and the simulator's command policy.
static func winning_hook(main: Main) -> Callable:
	return func(setup: BattleSetup) -> void:
		shorten_stage(main.get_battle() as BattleScene)
		setup.clock = VirtualClock.new()
		setup.auto_timing = true
		setup.press_source = AutoTimingPressSource.new()
		setup.command_source = BattleSimPolicy.new()
		setup.rng_seed = 7


## The party runs away on its first command.
static func running_hook(main: Main) -> Callable:
	return func(setup: BattleSetup) -> void:
		shorten_stage(main.get_battle() as BattleScene)
		setup.clock = VirtualClock.new()
		setup.auto_timing = true
		setup.press_source = AutoTimingPressSource.new()
		var commands: BattleTestKit.ScriptedCommands = BattleTestKit.ScriptedCommands.new()
		commands.fallback = {"kind": "run"}
		setup.command_source = commands
		setup.rng_seed = 7


## Everyone has 1 HP and only defends, so the enemies win.
static func losing_hook(main: Main) -> Callable:
	return func(setup: BattleSetup) -> void:
		shorten_stage(main.get_battle() as BattleScene)
		setup.clock = VirtualClock.new()
		setup.auto_timing = false
		setup.press_source = BattleTestKit.FixedPressSource.new(0.0, false)
		for member: Dictionary in setup.party:
			member["hp"] = 1
		setup.command_source = BattleTestKit.ScriptedCommands.new()
		setup.rng_seed = 7


## Waits until the fight has a result, presses the HUD's end-screen button (`choice`), and waits
## for Main to leave the BATTLE state. Returns false if it took too long.
static func finish_fight(tree: SceneTree, main: Main, choice: String) -> bool:
	var start: int = Time.get_ticks_msec()
	var pressed: bool = false
	while main.get_state() == Main.State.BATTLE:
		var stage: BattleScene = main.get_battle() as BattleScene
		if stage != null and not pressed and not stage.result.is_empty() and stage.hud != null:
			stage.hud.emit_signal("finished", stage.result, choice)
			pressed = true
		if Time.get_ticks_msec() - start > WAIT_LIMIT_MS:
			return false
		await tree.process_frame
	return true


## Waits (up to the limit) until `main` is in `wanted`.
static func wait_for_state(tree: SceneTree, main: Main, wanted: Main.State) -> bool:
	var start: int = Time.get_ticks_msec()
	while main.get_state() != wanted:
		if Time.get_ticks_msec() - start > WAIT_LIMIT_MS:
			return false
		await tree.process_frame
	return true


## Waits until `main` starts the retried fight: a stage that is not the one with `old_id`.
static func wait_for_new_stage(tree: SceneTree, main: Main, old_id: int) -> bool:
	var start: int = Time.get_ticks_msec()
	while main.get_battle() == null or main.get_battle().get_instance_id() == old_id:
		if Time.get_ticks_msec() - start > WAIT_LIMIT_MS:
			return false
		await tree.process_frame
	return true
