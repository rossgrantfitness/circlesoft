class_name BattleTestKit
extends RefCounted
## Shared helpers for the battle tests: a fresh BattleData per test (tests may edit it), setups on a
## virtual clock, scripted commands and presses, and a recorder for every controller signal.

const LEVEL_DEFAULT: int = 3


## A private copy of the real data (edit it freely).
static func fresh_data(tree: SceneTree) -> BattleData:
	return BattleData.load_from(tree.root.get_node("DataDB"))


## A setup on a VirtualClock with a seed. Party at `level`, full HP and Juice.
static func setup_for(data: BattleData, encounter_id: String, level: int = LEVEL_DEFAULT, seed: int = 1) -> BattleSetup:
	var setup: BattleSetup = BattleSetup.new()
	var progression: Progression = Progression.new(data)
	setup.data = data
	setup.encounter_id = encounter_id
	setup.rng_seed = seed
	setup.clock = VirtualClock.new()
	for char_id: String in data.character_order:
		setup.party.append(progression.new_member(char_id, level))
	setup.bag = {"ration_bar": 3, "smelling_salts": 1, "canned_coffee": 2, "burn_gel": 1, "smoke_bomb": 1}
	return setup


## Press source that plays every press at cue + delta_ms (holds start well before the cue).
class FixedPressSource:
	extends PressSource
	var delta_ms: float = 0.0
	var press: bool = true
	var per_index: Dictionary = {}
	## Only press for the party's own attacks (never block).
	var attack_only: bool = false

	func _init(p_delta_ms: float = 0.0, p_press: bool = true) -> void:
		delta_ms = p_delta_ms
		press = p_press

	func plan(slot: Dictionary, _rng: RandomNumberGenerator) -> Dictionary:
		var downs: Array[int] = []
		var ups: Array[int] = []
		if not press or (attack_only and str(slot["side"]) == "block"):
			return {"downs": downs, "ups": ups}
		var delta: float = float(per_index.get(int(slot["index"]), delta_ms))
		var cue: int = slot["cue"]
		if str(slot["type"]) == ClutchJudge.TYPE_HOLD:
			downs.append(maxi(mini(cue - 450000, int(slot["hold_by"]) - 20000), int(slot["open"])))
			ups.append(cue + int(delta * 1000.0))
		else:
			downs.append(cue + int(delta * 1000.0))
		return {"downs": downs, "ups": ups}


## Command source that plays a list of commands in order, then falls back to a policy command.
class ScriptedCommands:
	extends RefCounted
	var queue: Array[Dictionary] = []
	var fallback: Dictionary = {"kind": "defend"}
	var chooser: Callable = Callable()
	var asked: Array[String] = []
	## Stop the fight (abort) once this many commands were given. -1 = never.
	var limit: int = -1

	func choose_command(controller: BattleController, actor_id: String, options: Dictionary) -> Dictionary:
		if limit >= 0 and asked.size() >= limit:
			controller.abort()
			return fallback
		asked.append(actor_id)
		if chooser.is_valid():
			var picked: Dictionary = chooser.call(controller, actor_id, options)
			if not picked.is_empty():
				return picked
		if not queue.is_empty():
			return queue.pop_front()
		return fallback


## Records every signal of a controller as {name, args}.
class Recorder:
	extends RefCounted
	var events: Array[Dictionary] = []

	func _init(c: BattleController) -> void:
		c.battle_started.connect(func(snap: Dictionary) -> void: _add("battle_started", [snap]))
		c.round_started.connect(func(r: int, o: Array, n: Array) -> void: _add("round_started", [r, o, n]))
		c.turn_started.connect(func(a: String) -> void: _add("turn_started", [a]))
		c.command_needed.connect(func(a: String, o: Dictionary) -> void: _add("command_needed", [a, o]))
		c.action_started.connect(func(a: Dictionary) -> void: _add("action_started", [a]))
		c.press_judged.connect(func(i: Dictionary) -> void: _add("press_judged", [i]))
		c.hit.connect(func(i: Dictionary) -> void: _add("hit", [i]))
		c.stats_changed.connect(func(id: String, hp: int, hm: int, j: int, jm: int) -> void: _add("stats_changed", [id, hp, hm, j, jm]))
		c.status_changed.connect(func(id: String, s: String, added: bool) -> void: _add("status_changed", [id, s, added]))
		c.combatant_down.connect(func(id: String) -> void: _add("combatant_down", [id]))
		c.combatant_revived.connect(func(id: String) -> void: _add("combatant_revived", [id]))
		c.combatant_fled.connect(func(id: String) -> void: _add("combatant_fled", [id]))
		c.action_finished.connect(func(a: Dictionary) -> void: _add("action_finished", [a]))
		c.message.connect(func(t: String) -> void: _add("message", [t]))
		c.battle_ended.connect(func(r: String, rep: Dictionary) -> void: _add("battle_ended", [r, rep]))
		c.skill_result.connect(func(i: Dictionary) -> void: _add("skill_result", [i]))

	func _add(signal_name: String, args: Array) -> void:
		events.append({"name": signal_name, "args": args})

	func of(signal_name: String) -> Array[Dictionary]:
		var out: Array[Dictionary] = []
		for e: Dictionary in events:
			if e["name"] == signal_name:
				out.append(e)
		return out

	func count(signal_name: String) -> int:
		return of(signal_name).size()

	## The first argument of every event of that signal.
	func first_args(signal_name: String) -> Array:
		var out: Array = []
		for e: Dictionary in of(signal_name):
			out.append((e["args"] as Array)[0])
		return out

	func names() -> Array[String]:
		var out: Array[String] = []
		for e: Dictionary in events:
			out.append(str(e["name"]))
		return out

	func messages() -> Array:
		return first_args("message")

	func hits() -> Array:
		return first_args("hit")

	func presses() -> Array:
		return first_args("press_judged")


## Runs a whole fight with a scripted command source and a press source; returns the controller.
static func run(setup: BattleSetup, commands: Array[Dictionary], presses: PressSource, fallback: Dictionary = {"kind": "defend"},
		max_commands: int = -1) -> BattleController:
	var source: ScriptedCommands = ScriptedCommands.new()
	source.queue = commands
	source.fallback = fallback
	source.limit = max_commands
	setup.command_source = source
	setup.press_source = presses
	var controller: BattleController = BattleController.create(setup)
	await controller.start()
	return controller
