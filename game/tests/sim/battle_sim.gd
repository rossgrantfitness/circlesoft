class_name BattleSim
extends RefCounted
## The headless battle simulator: runs the real BattleController on a virtual clock with no view
## and a simulated player, thousands of times, and reports win rates and fight lengths against
## data/battle/feel_targets.json.
##
## Players: perfect (always on the cue), good (about 40 ms spread), miss (never presses) and
## auto (Auto-Timing: every press lands as Rad). Fight time = the virtual clock's timeline
## milliseconds plus feel_targets.menu_ms_per_command for every party command.

const PLAYERS: Array[String] = ["perfect", "good", "auto", "miss"]
const PLAYER_AUTO: String = "auto"

var data: BattleData
var progression: Progression


func _init(p_data: BattleData = null) -> void:
	data = p_data if p_data != null else BattleData.shared()
	progression = Progression.new(data)


# ---- one fight ----

## Builds the setup for one simulated fight. `members` overrides the party (carry-over state).
func make_setup(encounter_id: String, player: String, seed: int, level: int, members: Array[Dictionary] = [],
		bag: Dictionary = {}) -> BattleSetup:
	var setup: BattleSetup = BattleSetup.new()
	var sim: Dictionary = data.feel.get("sim", {})
	setup.data = data
	setup.encounter_id = encounter_id
	setup.rng_seed = seed
	setup.clock = VirtualClock.new()
	if player == PLAYER_AUTO:
		setup.auto_timing = true
	else:
		setup.press_source = SimPressSource.make(player, float(sim.get("good_sigma_ms", 40.0)), float(sim.get("hold_lead_ms", 450.0)), float(sim.get("good_lapse_chance", 0.0)))
	setup.command_source = BattleSimPolicy.new(sim)
	if members.is_empty():
		for char_id: String in data.character_order:
			setup.party.append(progression.new_member(char_id, level))
	else:
		setup.party = members
	if bag.is_empty():
		setup.bag = (sim.get("start_bag", {}) as Dictionary).duplicate()
	else:
		setup.bag = bag
	return setup


## Runs one fight. Returns {result, rounds, seconds, timeline_ms, menu_ms, commands, hp_left_pct,
## xp, credits, drops, level_ups, party, bag}.
func run_fight(encounter_id: String, player: String, seed: int, level: int, members: Array[Dictionary] = [],
		bag: Dictionary = {}) -> Dictionary:
	var setup: BattleSetup = make_setup(encounter_id, player, seed, level, members, bag)
	var controller: BattleController = BattleController.create(setup)
	await controller.start()
	var outcome: Dictionary = controller.get_result()
	var menu_ms: int = controller.party_commands * int(data.feel.get("menu_ms_per_command", 0))
	var timeline_ms: float = float(outcome["elapsed_usec"]) / 1000.0
	var hp_total: float = 0.0
	var hp_max: float = 0.0
	for member: Dictionary in outcome["party"]:
		hp_total += float(member["hp"])
		hp_max += float(member["hp_max"])
	var report: Dictionary = outcome["report"]
	return {"result": outcome["result"], "rounds": outcome["rounds"], "timeline_ms": timeline_ms,
		"menu_ms": menu_ms, "seconds": (timeline_ms + float(menu_ms)) / 1000.0, "commands": outcome["party_commands"],
		"hp_left_pct": 100.0 * hp_total / maxf(hp_max, 1.0), "xp": report["xp"], "credits": report["credits"],
		"drops": report["drops"], "level_ups": report["level_ups"], "party": outcome["party"], "bag": outcome["bag"]}


# ---- many fights ----

## Aggregate over `runs` fights (seeds seed..seed+runs-1).
## {runs, win_rate, lose_rate, ran_rate, mean_s, p10_s, p50_s, p90_s, mean_rounds, mean_hp_left_pct (wins), mean_credits, mean_xp}
func run_many(encounter_id: String, player: String, runs: int, seed: int, level: int = 0) -> Dictionary:
	var lvl: int = level if level > 0 else int(data.encounter(encounter_id).get("suggested_level", 1))
	var wins: int = 0
	var losses: int = 0
	var times: Array[float] = []
	var rounds_total: float = 0.0
	var hp_total: float = 0.0
	var credits_total: float = 0.0
	var xp_total: float = 0.0
	for i: int in runs:
		var fight: Dictionary = await run_fight(encounter_id, player, seed + i, lvl)
		times.append(float(fight["seconds"]))
		rounds_total += float(fight["rounds"])
		if fight["result"] == BattleController.RESULT_WIN:
			wins += 1
			hp_total += float(fight["hp_left_pct"])
			credits_total += float(fight["credits"])
			xp_total += float(fight["xp"])
		elif fight["result"] == BattleController.RESULT_LOSE:
			losses += 1
	times.sort()
	var n: float = float(maxi(runs, 1))
	return {"encounter": encounter_id, "player": player, "level": lvl, "runs": runs,
		"win_rate": float(wins) / n, "lose_rate": float(losses) / n,
		"mean_s": _mean(times), "p10_s": _percentile(times, 0.1), "p50_s": _percentile(times, 0.5),
		"p90_s": _percentile(times, 0.9), "mean_rounds": rounds_total / n,
		"mean_hp_left_pct": hp_total / maxf(float(wins), 1.0), "mean_credits": credits_total / maxf(float(wins), 1.0),
		"mean_xp": xp_total / maxf(float(wins), 1.0)}


func _mean(sorted_values: Array[float]) -> float:
	if sorted_values.is_empty():
		return 0.0
	var total: float = 0.0
	for v: float in sorted_values:
		total += v
	return total / float(sorted_values.size())


func _percentile(sorted_values: Array[float], fraction: float) -> float:
	if sorted_values.is_empty():
		return 0.0
	var index: int = clampi(int(round(fraction * float(sorted_values.size() - 1))), 0, sorted_values.size() - 1)
	return sorted_values[index]


# ---- checks against feel_targets.json ----

## Messages for every way `stats` (a run_many result) misses the feel targets. Empty = fine.
func check_against_targets(stats: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	var encounter: Dictionary = data.encounter(str(stats["encounter"]))
	var tier: String = str(encounter.get("tier", "regular"))
	var seconds: Dictionary = (data.feel.get("fight_seconds", {}) as Dictionary).get(tier, {})
	var tag: String = "%s/%s" % [stats["encounter"], stats["player"]]
	if not seconds.is_empty() and str(stats["player"]) != "miss":
		if float(stats["mean_s"]) < float(seconds["min"]) or float(stats["mean_s"]) > float(seconds["max"]):
			problems.append("%s: mean fight %.0fs is outside %s..%s" % [tag, float(stats["mean_s"]), seconds["min"], seconds["max"]])
	var rates: Dictionary = (data.feel.get("win_rate", {}) as Dictionary).get(tier, {})
	if rates.has(str(stats["player"])):
		var band: Array = rates[str(stats["player"])]
		var rate: float = float(stats["win_rate"])
		if rate < float(band[0]) or rate > float(band[1]):
			problems.append("%s: win rate %.2f is outside %s..%s" % [tag, rate, band[0], band[1]])
	return problems


## Perfect play should beat never pressing: more wins, or a clearly shorter fight
## (feel_targets.perfect_beats_miss_by). `all_stats` = run_many results.
static func check_clutch_matters(data: BattleData, all_stats: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	var margin: float = float(data.feel.get("perfect_beats_miss_by", 0.0))
	var perfect: Dictionary = {}
	var miss: Dictionary = {}
	for stats: Dictionary in all_stats:
		if str(stats["player"]) == "perfect":
			perfect[str(stats["encounter"])] = stats
		elif str(stats["player"]) == "miss":
			miss[str(stats["encounter"])] = stats
	for encounter_id: String in perfect:
		if not miss.has(encounter_id):
			continue
		var p: Dictionary = perfect[encounter_id]
		var m: Dictionary = miss[encounter_id]
		var wins_more: bool = float(p["win_rate"]) - float(m["win_rate"]) >= margin
		var faster: bool = float(p["mean_s"]) <= float(m["mean_s"]) * (1.0 - margin)
		if not wins_more and not faster:
			out.append("%s: perfect play is not clearly better than never pressing" % encounter_id)
	return out


# ---- walkthrough ----

## Fights the walkthrough sequence in order with level-ups and loot carried over. The party is
## fully healed between fights (a save lamp or Camp Stove) when rest_between is true, and the bag
## is topped back up to the starting kit (shopping with the credits earned) when restock_between is true.
## Returns {fights, wins, completed, level, credits, xp, items, party}.
func walkthrough(player: String, seed: int, rest_between: bool = true, restock_between: bool = true) -> Dictionary:
	var order: Array = (data.feel.get("walkthrough", {}) as Dictionary).get("order", data.encounter_order)
	var members: Array[Dictionary] = []
	for char_id: String in data.character_order:
		members.append(progression.new_member(char_id, 1))
	var bag: Dictionary = ((data.feel.get("sim", {}) as Dictionary).get("start_bag", {}) as Dictionary).duplicate()
	var credits: int = 0
	var wins: int = 0
	var fights: int = 0
	for i: int in order.size():
		var fight: Dictionary = await run_fight(str(order[i]), player, seed + i, 1, members, bag)
		fights += 1
		if fight["result"] != BattleController.RESULT_WIN:
			break
		wins += 1
		credits += int(fight["credits"])
		bag = fight["bag"]
		if restock_between:
			bag = ((data.feel.get("sim", {}) as Dictionary).get("start_bag", {}) as Dictionary).duplicate()
		members = []
		for member: Dictionary in fight["party"]:
			var kept: Dictionary = member.duplicate()
			if rest_between:
				kept["hp"] = kept["hp_max"]
				kept["juice"] = kept["juice_max"]
			members.append(kept)
	var top: int = 1
	var xp: int = 0
	for member: Dictionary in members:
		top = maxi(top, int(member["level"]))
		xp = maxi(xp, int(member["xp"]))
	return {"player": player, "fights": fights, "wins": wins, "completed": wins == order.size(), "level": top,
		"credits": credits, "xp": xp, "party": members}
