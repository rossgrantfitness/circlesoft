extends SceneTree
## Battle simulator command line.
##   godot --headless --path game -s res://tests/sim/run_sim.gd -- --encounter=squad_four --player=good --runs=1000 --seed=1
##
## Options (all optional):
##   --encounter=ID|all   which fight(s); default all
##   --player=NAME|all    perfect, good, miss, auto; default all
##   --runs=N             fights per encounter and player; default 200 (the full milestone run is 5000)
##   --seed=N             first seed; fight i uses seed+i, so any result can be reproduced; default 1
##   --level=N            party level; default each encounter's suggested_level
##   --walkthrough        also fight the slice walkthrough in order with level-ups and loot
##   --check              compare against data/battle/feel_targets.json; exit code 1 on any miss
##   --markdown           print the tables as Markdown (for docs/battle_sim_report.md)
##   --no-gear            simulate the party without any weapons, armor or charms (the pre-M3 numbers)

const ARG_ENCOUNTER: String = "--encounter="
const ARG_PLAYER: String = "--player="
const ARG_RUNS: String = "--runs="
const ARG_SEED: String = "--seed="
const ARG_LEVEL: String = "--level="
const FLAG_WALK: String = "--walkthrough"
const FLAG_CHECK: String = "--check"
const FLAG_MARKDOWN: String = "--markdown"
const FLAG_NO_GEAR: String = "--no-gear"
const WALK_REPEATS: int = 100


func _initialize() -> void:
	await process_frame
	var encounter_arg: String = "all"
	var player_arg: String = "all"
	var runs: int = 200
	var seed_value: int = 1
	var level: int = 0
	var walk: bool = false
	var check: bool = false
	var markdown: bool = false
	var gear: bool = true
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(ARG_ENCOUNTER):
			encounter_arg = arg.trim_prefix(ARG_ENCOUNTER)
		elif arg.begins_with(ARG_PLAYER):
			player_arg = arg.trim_prefix(ARG_PLAYER)
		elif arg.begins_with(ARG_RUNS):
			runs = int(arg.trim_prefix(ARG_RUNS))
		elif arg.begins_with(ARG_SEED):
			seed_value = int(arg.trim_prefix(ARG_SEED))
		elif arg.begins_with(ARG_LEVEL):
			level = int(arg.trim_prefix(ARG_LEVEL))
		elif arg == FLAG_WALK:
			walk = true
		elif arg == FLAG_CHECK:
			check = true
		elif arg == FLAG_MARKDOWN:
			markdown = true
		elif arg == FLAG_NO_GEAR:
			gear = false
	var sim: BattleSim = BattleSim.new()
	sim.use_gear = gear
	var encounters: Array[String] = sim.data.encounter_order if encounter_arg == "all" else [encounter_arg] as Array[String]
	var players: Array[String] = BattleSim.PLAYERS if player_arg == "all" else [player_arg] as Array[String]
	var problems: Array[String] = []
	_print_header(markdown)
	var all_stats: Array[Dictionary] = []
	for encounter_id: String in encounters:
		if sim.data.encounter(encounter_id).is_empty():
			print("Unknown encounter '%s'. Known: %s" % [encounter_id, sim.data.encounter_order])
			quit(2)
			return
		for player: String in players:
			var stats: Dictionary = await sim.run_many(encounter_id, player, runs, seed_value, level)
			all_stats.append(stats)
			print(_row(stats, markdown))
			problems.append_array(sim.check_against_targets(stats))
	problems.append_array(_check_clutch_matters(sim, all_stats))
	if walk:
		print("")
		for player: String in players:
			var summary: Dictionary = await _walk_summary(sim, player, seed_value)
			print(_walk_row(summary, markdown))
			problems.append_array(_check_walk(sim, summary))
	if walk:
		var econ: Array[String] = _economy_problems(sim)
		print(_economy_line(sim))
		problems.append_array(econ)
	if check:
		print("")
		if problems.is_empty():
			print("CHECK OK: every result is inside the feel targets.")
		else:
			for problem: String in problems:
				print("CHECK FAIL: %s" % problem)
	quit(1 if (check and not problems.is_empty()) else 0)


## The price curve against the credits the player has by the Kasp fight (feel_targets.credits_at_kasp).
func _economy_line(sim: BattleSim) -> String:
	var items: ItemData = sim.data.item_data
	return "economy: three shop weapons %d credits, both shop vests %d, credits at Kasp %d, Ration Bar %d" % [
		_shop_weapons_cost(items), _shop_vests_cost(items), int(sim.data.feel.get("credits_at_kasp", 0)), items.price("ration_bar")]


func _shop_weapons_cost(items: ItemData) -> int:
	return items.price("rebar_blade") + items.price("rivet_hammer") + items.price("pipe_wrench")


func _shop_vests_cost(items: ItemData) -> int:
	return items.price("padded_work_vest") + items.price("hi_vis_vest")


## Design doc Economy: by Kasp the player can afford the three shop weapons plus a pocketful of
## Ration Bars, but not every vest as well.
func _economy_problems(sim: BattleSim) -> Array[String]:
	var out: Array[String] = []
	var items: ItemData = sim.data.item_data
	var budget: int = int(sim.data.feel.get("credits_at_kasp", 0))
	var weapons: int = _shop_weapons_cost(items)
	if weapons + 10 * items.price("ration_bar") > budget:
		out.append("economy: the three shop weapons plus ten Ration Bars (%d) cost more than the %d credits at Kasp" % [weapons + 10 * items.price("ration_bar"), budget])
	if weapons + _shop_vests_cost(items) <= budget:
		out.append("economy: the weapons and both vests (%d) fit in %d credits, so there is no choice to make" % [weapons + _shop_vests_cost(items), budget])
	return out


func _print_header(markdown: bool) -> void:
	if markdown:
		print("| Encounter | Level | Player | Win rate | Mean s | p10 s | p50 s | p90 s | Rounds | HP left (wins) | XP | Credits |")
		print("|---|---|---|---|---|---|---|---|---|---|---|---|")
	else:
		print("%-15s %-3s %-8s %7s %7s %6s %6s %6s %6s %7s %5s %5s" % ["encounter", "lvl", "player", "win", "mean_s", "p10", "p50", "p90", "rounds", "hp_left", "xp", "cred"])


func _row(s: Dictionary, markdown: bool) -> String:
	if markdown:
		return "| %s | %d | %s | %.1f%% | %.0f | %.0f | %.0f | %.0f | %.1f | %.0f%% | %.0f | %.0f |" % [s["encounter"], s["level"],
			s["player"], 100.0 * float(s["win_rate"]), s["mean_s"], s["p10_s"], s["p50_s"], s["p90_s"], s["mean_rounds"],
			s["mean_hp_left_pct"], s["mean_xp"], s["mean_credits"]]
	return "%-15s L%-2d %-8s %6.1f%% %7.0f %6.0f %6.0f %6.0f %6.1f %6.0f%% %5.0f %5.0f" % [s["encounter"], s["level"], s["player"],
		100.0 * float(s["win_rate"]), s["mean_s"], s["p10_s"], s["p50_s"], s["p90_s"], s["mean_rounds"],
		s["mean_hp_left_pct"], s["mean_xp"], s["mean_credits"]]


func _walk_summary(sim: BattleSim, player: String, seed_value: int) -> Dictionary:
	var completed: int = 0
	var level_total: float = 0.0
	var credit_total: float = 0.0
	var fights_total: float = 0.0
	for i: int in WALK_REPEATS:
		var walk: Dictionary = await sim.walkthrough(player, seed_value + i * 100)
		if bool(walk["completed"]):
			completed += 1
			level_total += float(walk["level"])
			credit_total += float(walk["credits"])
		fights_total += float(walk["fights"])
	var n: float = float(maxi(completed, 1))
	return {"player": player, "completed_rate": float(completed) / float(WALK_REPEATS), "level": level_total / n,
		"credits": credit_total / n, "fights": fights_total / float(WALK_REPEATS)}


func _walk_row(w: Dictionary, markdown: bool) -> String:
	if markdown:
		return "| walkthrough | %s | %.0f%% finish | level %.1f | %.0f credits | %.1f fights |" % [w["player"], 100.0 * float(w["completed_rate"]), w["level"], w["credits"], w["fights"]]
	return "walkthrough %-8s completed %5.1f%%  final level %.1f  battle credits %.0f  fights %.1f" % [w["player"], 100.0 * float(w["completed_rate"]), w["level"], w["credits"], w["fights"]]


func _check_walk(sim: BattleSim, w: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var targets: Dictionary = sim.data.feel.get("walkthrough", {})
	var need: float = float((targets.get("min_completed_rate", {}) as Dictionary).get(str(w["player"]), 0.0))
	if float(w["completed_rate"]) < need:
		out.append("walkthrough/%s: finished %.2f of runs, needs %.2f" % [w["player"], w["completed_rate"], need])
	if float(w["completed_rate"]) > 0.0 and str(w["player"]) != "miss":
		var levels: Array = targets.get("final_level", [1, 99])
		if float(w["level"]) < float(levels[0]) or float(w["level"]) > float(levels[1]):
			out.append("walkthrough/%s: final level %.1f outside %s" % [w["player"], w["level"], levels])
		var credits: Array = targets.get("battle_credits", [0, 999999])
		if float(w["credits"]) < float(credits[0]) or float(w["credits"]) > float(credits[1]):
			out.append("walkthrough/%s: battle credits %.0f outside %s" % [w["player"], w["credits"], credits])
	return out


## Perfect play must feel strong: per encounter it wins more often or finishes clearly faster than miss.
func _check_clutch_matters(sim: BattleSim, all_stats: Array[Dictionary]) -> Array[String]:
	return BattleSim.check_clutch_matters(sim.data, all_stats)
