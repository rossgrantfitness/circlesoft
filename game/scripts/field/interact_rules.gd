class_name InteractRules
extends RefCounted
## Decision 3 (docs/slice/slice_tech_plan.md): how Red talks to people and uses things in the action game.
## Pure rules; the numbers and the switch are data (data/slice/slice.json "interact").
##
##   mode "attack_button" (option A, the recommended default): the attack button talks or uses the thing in front of
##       her when a prompt is showing and no living enemy is within `clear_m`. In town, where nothing fights, the attack
##       button only talks. Otherwise it attacks as always.
##   mode "own_button"    (option B): the attack button never talks; the separate `interact` button does.
##
## The `interact` button itself always works (when a prompt is showing) in both modes: it is the keyboard's E and, in
## option B, the pad's right trigger (data/slice/input_sorting.json decides the bindings).

const DATA_ID: String = "slice/slice"
const MODE_ATTACK_BUTTON: StringName = &"attack_button"
const MODE_OWN_BUTTON: StringName = &"own_button"
const DEFAULT_CLEAR_M: float = 5.0

## Which option is on.
var mode: StringName = MODE_ATTACK_BUTTON
## How far the nearest living enemy must be before the attack button may talk (metres).
var clear_m: float = DEFAULT_CLEAR_M
## The action that is "the attack button" (one button does the whole combo).
var attack_action: StringName = &"light"


static func from_data(data: Dictionary) -> InteractRules:
	var rules: InteractRules = InteractRules.new()
	var picked: StringName = StringName(str(data.get("mode", MODE_ATTACK_BUTTON)))
	rules.mode = picked if picked == MODE_ATTACK_BUTTON or picked == MODE_OWN_BUTTON else MODE_ATTACK_BUTTON
	rules.clear_m = maxf(float(data.get("clear_m", DEFAULT_CLEAR_M)), 0.0)
	rules.attack_action = StringName(str(data.get("attack_action", "light")))
	return rules


## The rules in data/slice/slice.json (defaults if the file is missing). Needs the DataDB autoload.
static func load_default() -> InteractRules:
	return from_data(DataDB.get_value(DATA_ID, "interact", {}) as Dictionary)


func uses_attack_button() -> bool:
	return mode == MODE_ATTACK_BUTTON


## Should an attack-button press be spent on the prompt instead of attacking?
## `prompt_showing`: something is in front of her. `nearest_enemy_m`: distance to the nearest living enemy (INF = none).
## `combat_room`: false in town.
func attack_press_interacts(prompt_showing: bool, nearest_enemy_m: float, combat_room: bool) -> bool:
	if not uses_attack_button() or not prompt_showing:
		return false
	if not combat_room:
		return true
	return nearest_enemy_m >= clear_m
