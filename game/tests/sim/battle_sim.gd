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
const ROUTE_FULL: String = "full"
const ROUTE_MUST_WIN: String = "must_win"

var data: BattleData
var progression: Progression
## Dress the simulated party in the gear from feel_targets.sim.gear (false = no gear at all).
var use_gear: bool = true


func _init(p_data: BattleData = null) -> void:
	data = p_data if p_data != null else BattleData.shared()
	progression = Progression.new(data)


# ---- gear ----

## {character: {weapon, armor, charm}} the simulated party wears at a party level, from
## feel_targets.sim.gear (the highest by_level row at or below the level). {} = no gear.
func gear_for_level(level: int) -> Dictionary:
	var gear: Dictionary = (data.feel.get("sim", {}) as Dictionary).get("gear", {})
	if not use_gear or gear.is_empty():
		return {}
	var picked: String = ""
	for row: Dictionary in gear.get("by_level", []):
		if int(row["level"]) <= level:
			picked = str(row["loadout"])
	return (gear.get("loadouts", {}) as Dictionary).get(picked, {})


## Changes a carried-over member into the gear that fits its level (new maximums; HP and Juice only clamped).
func refit(member: Dictionary) -> void:
	var loadouts: Dictionary = gear_for_level(int(member["level"]))
	var equipment: Dictionary = loadouts.get(str(member["id"]), {})
	if equipment.is_empty() or equipment == member.get("equipment", {}):
		return
	member["equipment"] = equipment.duplicate()
	var stats: Dictionary = StatCalc.stats_for_member(data, member)
	member["hp_max"] = stats["hp"]
	member["juice_max"] = stats["juice"]
	member["hp"] = mini(int(member["hp"]), int(stats["hp"]))
	member["juice"] = mini(int(member["juice"]), int(stats["juice"]))


# ---- one fight ----

## Who fights an encounter in the simulator: its `suggested_party` (for example Red alone on the
## train) or else the whole party.
func party_for(encounter_id: String) -> Array[String]:
	var out: Array[String] = []
	var wanted: Array = data.encounter(encounter_id).get("suggested_party", [])
	for id: Variant in wanted:
		out.append(str(id))
	if out.is_empty():
		out.append_array(data.character_order)
	return out


## Builds the setup for one simulated fight. `members` overrides the party (carry-over state).
## `party_ids` picks who fights when `members` is empty (default: the encounter's suggested_party).
func make_setup(encounter_id: String, player: String, seed: int, level: int, members: Array[Dictionary] = [],
		bag: Dictionary = {}, party_ids: Array[String] = []) -> BattleSetup:
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
		var loadouts: Dictionary = gear_for_level(level)
		var who: Array[String] = party_ids if not party_ids.is_empty() else party_for(encounter_id)
		for char_id: String in who:
			setup.party.append(progression.new_member(char_id, level, loadouts.get(char_id, {})))
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
		bag: Dictionary = {}, party_ids: Array[String] = []) -> Dictionary:
	var setup: BattleSetup = make_setup(encounter_id, player, seed, level, members, bag, party_ids)
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

## The steps of a route from feel_targets.walkthrough.routes: each {encounter, party: [ids],
## optional: bool}. Route "full" fights everything; "must_win" skips the optional fights.
func route_steps(route: String) -> Array[Dictionary]:
	var walk: Dictionary = data.feel.get("walkthrough", {})
	var out: Array[Dictionary] = []
	for step_variant: Variant in walk.get("route", []):
		var step: Dictionary = step_variant
		if route == ROUTE_MUST_WIN and bool(step.get("optional", false)):
			continue
		out.append(step)
	return out


## Fights a route in order with level-ups and loot carried over. Fighters join when their first
## step comes up, at the party's top level minus feel_targets.walkthrough.join_level_offset. The
## party is fully healed between fights (a save lamp or Camp Stove) when rest_between is true, and
## the bag is topped back up to the starting kit (shopping) when restock_between is true. Stops at
## the first lost fight. Returns {fights, wins, completed, level, credits, xp, steps, party, lost_at}.
func walkthrough(player: String, seed: int, rest_between: bool = true, restock_between: bool = true,
		route: String = ROUTE_FULL) -> Dictionary:
	var steps: Array[Dictionary] = route_steps(route)
	var walk_rules: Dictionary = data.feel.get("walkthrough", {})
	var join_offset: int = int(walk_rules.get("join_level_offset", 0))
	var members: Array[Dictionary] = []
	var start_bag: Dictionary = ((data.feel.get("sim", {}) as Dictionary).get("start_bag", {}) as Dictionary).duplicate()
	var bag: Dictionary = start_bag.duplicate()
	var credits: int = 0
	var wins: int = 0
	var fights: int = 0
	var lost_at: String = ""
	for i: int in steps.size():
		var step: Dictionary = steps[i]
		var ids: Array[String] = []
		for id: Variant in step.get("party", []):
			ids.append(str(id))
		var top_level: int = 1
		for member: Dictionary in members:
			top_level = maxi(top_level, int(member["level"]))
		for id: String in ids:
			if not _has_member(members, id):
				var join_level: int = maxi(top_level - join_offset, 1) if not members.is_empty() else 1
				members.append(progression.new_member(id, join_level, gear_for_level(join_level).get(id, {})))
		var fighting: Array[Dictionary] = []
		for id: String in ids:
			fighting.append(_member_of(members, id))
		var fight: Dictionary = await run_fight(str(step["encounter"]), player, seed + i, 1, fighting, bag)
		fights += 1
		if fight["result"] != BattleController.RESULT_WIN:
			lost_at = str(step["encounter"])
			break
		wins += 1
		credits += int(fight["credits"])
		bag = fight["bag"]
		if restock_between:
			bag = start_bag.duplicate()
		for after: Dictionary in fight["party"]:
			var index: int = _index_of(members, str(after["id"]))
			members[index] = after.duplicate()
		for kept: Dictionary in members:
			refit(kept)
			if rest_between:
				kept["hp"] = kept["hp_max"]
				kept["juice"] = kept["juice_max"]
	var top: int = 1
	var xp: int = 0
	for member: Dictionary in members:
		top = maxi(top, int(member["level"]))
		xp = maxi(xp, int(member["xp"]))
	return {"player": player, "route": route, "fights": fights, "wins": wins, "completed": wins == steps.size(),
		"level": top, "credits": credits, "xp": xp, "steps": steps.size(), "party": members, "lost_at": lost_at}


func _has_member(members: Array[Dictionary], id: String) -> bool:
	return _index_of(members, id) >= 0


func _index_of(members: Array[Dictionary], id: String) -> int:
	for i: int in members.size():
		if str(members[i]["id"]) == id:
			return i
	return -1


func _member_of(members: Array[Dictionary], id: String) -> Dictionary:
	return members[_index_of(members, id)]
