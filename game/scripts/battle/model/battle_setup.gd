class_name BattleSetup
extends RefCounted
## Everything a battle needs to start. Plain data: build one, hand it to BattleController.create().

const FIRST_TURN_NORMAL: String = "normal"
const RANDOM_SEED: int = -1

var encounter_id: String = ""
## Field party, in slot order. Each: {id, level, xp?, hp?, juice?, statuses?, bonus?}. Missing hp/juice = full.
var party: Array[Dictionary] = []
## Benched members (only earn XP when the bench-XP rule is on). Same shape as party.
var bench: Array[Dictionary] = []
## Bag for this fight: item id -> count. The controller works on a copy.
var bag: Dictionary = {}
var clock: BattleClock = null
var press_source: PressSource = null
## null = wait for submit_command. Otherwise an object with
## choose_command(controller: BattleController, actor_id: String, options: Dictionary) -> Dictionary.
var command_source: RefCounted = null
var auto_timing: bool = false
var wide_windows: bool = false
var timing_offset_ms: int = 0
var rng_seed: int = 0
## "normal", "party" (free first turn) or "enemies" (ambushed): from EncounterRules.first_turn().
var first_turn: String = FIRST_TURN_NORMAL
## Optional: when set, a win or escape writes party hp/juice/level/xp, bag and credits back into it.
var game_state: Node = null
## Defaults to BattleData.shared(). Tests can pass their own.
var data: BattleData = null


## Builds a setup from the GameState autoload (or any object shaped like it) and Config.
## Real clock and a human press source unless Config says Auto-Timing.
static func from_game_state(state: Node, p_encounter_id: String, config: Node = null, p_first_turn: String = FIRST_TURN_NORMAL) -> BattleSetup:
	var setup: BattleSetup = BattleSetup.new()
	setup.encounter_id = p_encounter_id
	setup.first_turn = p_first_turn
	for member: Dictionary in state.call("get_party"):
		setup.party.append(member.duplicate(true))
	var bag: Dictionary = {}
	for item_id: String in state.call("get_item_ids"):
		bag[item_id] = int(state.call("item_count", item_id))
	setup.bag = bag
	setup.game_state = state
	setup.clock = RealClock.new()
	setup.rng_seed = RANDOM_SEED
	if config != null:
		setup.auto_timing = bool(config.get("auto_timing"))
		setup.wide_windows = bool(config.get("wide_windows"))
		setup.timing_offset_ms = int(config.get("timing_offset_ms"))
	setup.press_source = HumanPressSource.new()
	return setup
