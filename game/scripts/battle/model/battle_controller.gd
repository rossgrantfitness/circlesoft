class_name BattleController
extends RefCounted
## The battle model. Pure logic: no nodes, no rendering, no audio. It runs identically on a
## RealClock (the game) and a VirtualClock (the simulator and tests). The contract it implements,
## including every signal, is docs/battle_api.md.
##
## Flow: create(setup) -> start() (a coroutine; awaitable) -> signals as the fight runs ->
## battle_ended. Party commands arrive through submit_command (or setup.command_source).
## Clutch presses arrive through press_down / press_up and are judged from their timestamps.

signal battle_started(snap: Dictionary)
signal round_started(round: int, order: Array, next_order: Array)
signal turn_started(actor_id: String)
signal command_needed(actor_id: String, options: Dictionary)
signal action_started(action: Dictionary)
signal press_judged(info: Dictionary)
signal hit(info: Dictionary)
signal stats_changed(id: String, hp: int, hp_max: int, juice: int, juice_max: int)
signal status_changed(id: String, status_id: String, added: bool)
signal combatant_down(id: String)
signal combatant_revived(id: String)
signal combatant_fled(id: String)
signal action_finished(action: Dictionary)
signal message(text: String)
signal battle_ended(result: String, report: Dictionary)
## Added after the contract (see "Changes" in battle_api.md): a gadget wheel landed on something.
signal skill_result(info: Dictionary)
signal _command_submitted

const KIND_ATTACK: String = "attack"
const KIND_SKILL: String = "skill"
const KIND_ITEM: String = "item"
const KIND_DEFEND: String = "defend"
const KIND_RUN: String = "run"
const SIDE_ATTACK: String = "attack"
const SIDE_BLOCK: String = "block"
const RESULT_WIN: String = "win"
const RESULT_LOSE: String = "lose"
const RESULT_RAN: String = "ran"
const RESULT_ABORTED: String = "aborted"
const MAX_INVALID_COMMANDS: int = 20
const MAX_ROUNDS: int = 300
const MIN_STEP_USEC: int = 1000
const PRESS_SEED_OFFSET: int = 7919
const MSG_CANT_RUN: String = "Can't run from this one!"
const MSG_NOISE_TICKET: String = "Noise Ticket! No skills."
const MSG_NO_JUICE: String = "Not enough Juice!"
const MSG_NO_TARGET: String = "Pick a target."
const MSG_RAN: String = "Got away safely!"
const MSG_NOT_RAN: String = "Couldn't get away!"
const MSG_STUNNED: String = "Stunned! Skips the turn."
const MSG_WOBBLY: String = "Wobbly! Swings at the wrong thing."
const MSG_WHITE_FLAG: String = "waves a white flag and leaves!"

var setup: BattleSetup = null
var data: BattleData = null
var state: BattleState = BattleState.new()
var clock: BattleClock = null
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var press_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var press_source: PressSource = null
var progression: Progression = null

var round_number: int = 0
var is_over: bool = false
var result: String = ""
var report: Dictionary = {}
## Party commands given (the simulator adds menu time per command).
var party_commands: int = 0
var start_usec: int = 0
var end_usec: int = 0

var _encounter: Dictionary = {}
var _can_run: bool = true
var _bag: Dictionary = {}
var _items_used: Dictionary = {}
var _bench: Array[Dictionary] = []
var _pending_command: Dictionary = {}
var _awaiting_actor: String = ""
var _downs: Array[int] = []
var _ups: Array[int] = []
var _last_ko_id: String = ""
var _skip: bool = false
var _final_party: Array[Dictionary] = []
var _final_bench: Array[Dictionary] = []


static func create(p_setup: BattleSetup) -> BattleController:
	var controller: BattleController = BattleController.new()
	controller._build(p_setup)
	return controller


# ---- public API ----

## Runs the whole fight. Awaitable: with a VirtualClock and a command source it finishes inside
## this call; with a real clock it returns control to the engine whenever it waits.
func start() -> void:
	start_usec = clock.now_usec()
	battle_started.emit(snapshot())
	while not is_over:
		var already: String = _outcome()
		if not already.is_empty():
			await _finish(already)
			break
		round_number += 1
		if round_number > MAX_ROUNDS:
			await _finish(RESULT_LOSE)
			break
		var first_turn: String = setup.first_turn if round_number == 1 else BattleSetup.FIRST_TURN_NORMAL
		var order: Array[BattleCombatant] = BattleTurnOrder.order(state.all_active(), first_turn)
		var order_ids: Array[String] = []
		for c: BattleCombatant in order:
			order_ids.append(c.id)
		round_started.emit(round_number, order_ids, BattleTurnOrder.ids(state.all_active()))
		for c: BattleCombatant in order:
			if is_over:
				break
			if c.is_active():
				await _take_turn(c)


## The player's answer to command_needed.
func submit_command(cmd: Dictionary) -> void:
	if _awaiting_actor.is_empty():
		return
	_pending_command = cmd
	_command_submitted.emit()


## Clutch button went down. t_usec is the input event's timestamp on the battle clock.
func press_down(t_usec: int) -> void:
	_insert_sorted(_downs, t_usec)


## Clutch button was released (hold-and-release presses are judged on this).
func press_up(t_usec: int) -> void:
	_insert_sorted(_ups, t_usec)


## Full current state: encounter info plus every combatant.
func snapshot() -> Dictionary:
	return {
		"encounter_id": setup.encounter_id if setup != null else "",
		"can_run": _can_run,
		"is_boss": bool(_encounter.get("is_boss", false)),
		"backdrop": str(_encounter.get("backdrop", "")),
		"music": str(_encounter.get("music", "")),
		"round": round_number,
		"combatants": state.snapshot_list(),
	}


## Stops the fight where it is (quit to title, tests). No battle_ended, no rewards.
func abort() -> void:
	if is_over:
		return
	is_over = true
	result = RESULT_ABORTED
	if not _awaiting_actor.is_empty():
		_pending_command = {"kind": KIND_DEFEND}
		_command_submitted.emit()


## Speed up an animation the player has seen: the end-of-action pauses shrink to nothing.
## Press windows are never shortened.
func skip_requested() -> void:
	_skip = true


## Final party, bag and report once the battle has ended (also written to GameState if setup.game_state is set).
func get_result() -> Dictionary:
	return {
		"result": result,
		"report": report,
		"party": _final_party,
		"bench": _final_bench,
		"bag": _bag.duplicate(),
		"items_used": _items_used.duplicate(),
		"rounds": round_number,
		"party_commands": party_commands,
		"elapsed_usec": end_usec - start_usec,
	}


# ---- setup ----

func _build(p_setup: BattleSetup) -> void:
	setup = p_setup
	data = setup.data if setup.data != null else BattleData.shared()
	progression = Progression.new(data)
	clock = setup.clock if setup.clock != null else RealClock.new()
	if setup.auto_timing:
		press_source = AutoTimingPressSource.new()
	elif setup.press_source != null:
		press_source = setup.press_source
	else:
		press_source = HumanPressSource.new()
	if setup.rng_seed == BattleSetup.RANDOM_SEED:
		rng.randomize()
		press_rng.randomize()
	else:
		rng.seed = setup.rng_seed
		press_rng.seed = setup.rng_seed + PRESS_SEED_OFFSET
	_encounter = data.encounter(setup.encounter_id)
	if _encounter.is_empty():
		push_error("BattleController: unknown encounter '%s'" % setup.encounter_id)
	_can_run = bool(_encounter.get("can_run", true)) and not bool(_encounter.get("is_boss", false))
	for item_id: String in setup.bag:
		_bag[item_id] = int(setup.bag[item_id])
	for member: Dictionary in setup.bench:
		_bench.append(member.duplicate(true))
	for i: int in setup.party.size():
		state.add(_make_party_member(setup.party[i], i))
	var enemy_ids: Array = _encounter.get("enemies", [])
	for i: int in enemy_ids.size():
		state.add(_make_enemy(str(enemy_ids[i]), i))


func _make_party_member(member: Dictionary, slot: int) -> BattleCombatant:
	var c: BattleCombatant = BattleCombatant.new()
	var char_id: String = str(member.get("id", ""))
	var def: Dictionary = data.character(char_id)
	c.id = char_id
	c.side = BattleCombatant.SIDE_PARTY
	c.slot = slot
	c.display_name = str(def.get("name", char_id))
	c.kind = char_id
	c.model = str(def.get("model", ""))
	c.level = clampi(int(member.get("level", 1)), 1, data.max_level)
	c.bonus = member.get("bonus", {})
	c.stats = progression.stats_at(char_id, c.level, c.bonus)
	c.hp_max = int(c.stats["hp"])
	c.hp = clampi(int(member.get("hp", c.hp_max)), 0, c.hp_max)
	c.juice_max = int(c.stats["juice"])
	c.juice = clampi(int(member.get("juice", c.juice_max)), 0, c.juice_max)
	c.xp = int(member.get("xp", progression.xp_for_level(c.level)))
	c.known_skills = progression.skills_known(char_id, c.level)
	c.attack_skill = str(def.get("attack_skill", ""))
	c.down = c.hp <= 0
	for status_id: Variant in member.get("statuses", []):
		if data.statuses.has(str(status_id)) and not c.down:
			c.statuses[str(status_id)] = int(data.status(str(status_id)).get("duration_turns", 1))
	return c


func _make_enemy(enemy_id: String, index: int) -> BattleCombatant:
	var def: Dictionary = data.enemy(enemy_id)
	var c: BattleCombatant = BattleCombatant.new()
	c.id = "e%d" % (index + 1)
	c.side = BattleCombatant.SIDE_ENEMY
	c.slot = index
	c.display_name = str(def.get("name", enemy_id))
	c.kind = enemy_id
	c.model = str(def.get("model", ""))
	c.level = int(def.get("level", 1))
	c.stats = (def.get("stats", {}) as Dictionary).duplicate()
	var scale: Dictionary = _encounter.get("enemy_scale", {})
	for key: String in scale:
		if c.stats.has(key):
			c.stats[key] = maxi(int(round(float(c.stats[key]) * float(scale[key]))), 1)
	c.hp_max = int(c.stats.get("hp", 1))
	c.hp = c.hp_max
	c.juice_max = int(c.stats.get("juice", 0))
	c.juice = c.juice_max
	c.is_boss = bool(def.get("is_boss", false))
	c.status_resist = def.get("status_resist", {})
	c.flee_at_hp_pct = float(def.get("flee_at_hp_pct", 0.0))
	c.enemy_data = def
	return c


# ---- turns ----

func _take_turn(c: BattleCombatant) -> void:
	turn_started.emit(c.id)
	c.defending = false
	if await _maybe_flee(c):
		await _after_action()
		return
	_tick_statuses(c)
	if not _outcome().is_empty():
		await _finish(_outcome())
		return
	if not c.is_active():
		return
	if BattleStatusRules.skips_turn(data, c):
		message.emit(MSG_STUNNED)
		await _wait_ms(int(data.f("pacing", "skip_turn_ms", 0.0)))
		_end_turn(c)
		return
	if c.is_party():
		var cmd: Dictionary = await _get_party_command(c)
		if is_over:
			return
		party_commands += 1
		await _execute_party(c, cmd)
	else:
		await _execute_enemy(c)
	if is_over:
		return
	_end_turn(c)
	await _after_action()


## Win/lose check, then the short gap between actions.
func _after_action() -> void:
	var outcome: String = _outcome()
	if not outcome.is_empty():
		await _finish(outcome)
		return
	await _wait_ms(int(data.f("pacing", "between_actions_ms", 0.0)))


func _outcome() -> String:
	if is_over:
		return result
	if state.enemies_cleared():
		return RESULT_WIN
	if state.party_wiped():
		return RESULT_LOSE
	return ""


## Counts down the fighter's statuses at the end of its own turn.
func _end_turn(c: BattleCombatant) -> void:
	for status_id: String in c.statuses.keys():
		var left: int = int(c.statuses[status_id]) - 1
		if left <= 0:
			c.statuses.erase(status_id)
			status_changed.emit(c.id, status_id, false)
		else:
			c.statuses[status_id] = left


## Burnt Toast and friends: HP lost at the start of the fighter's turn.
func _tick_statuses(c: BattleCombatant) -> void:
	var loss: int = BattleStatusRules.tick_damage(data, c)
	if loss <= 0:
		return
	var source_status: String = ""
	for status_id: String in c.statuses:
		if float(data.status(status_id).get("hp_loss_pct", 0.0)) > 0.0:
			source_status = status_id
	c.hp = maxi(c.hp - loss, 0)
	hit.emit({"source": "", "target": c.id, "amount": loss, "kind": "damage", "blocked": ClutchJudge.BLOCK_NONE,
		"payback": false, "status": source_status})
	_emit_stats(c)
	if c.hp <= 0:
		_down(c)


## A nearly beaten flee-capable enemy waves a white flag and leaves instead of acting.
func _maybe_flee(c: BattleCombatant) -> bool:
	if c.is_party() or c.is_boss or c.flee_at_hp_pct <= 0.0:
		return false
	if c.hp_pct() > c.flee_at_hp_pct:
		return false
	c.fled = true
	_last_ko_id = ""
	for status_id: String in c.statuses.keys():
		c.statuses.erase(status_id)
		status_changed.emit(c.id, status_id, false)
	message.emit("%s %s" % [c.display_name, MSG_WHITE_FLAG])
	combatant_fled.emit(c.id)
	await _wait_ms(int(data.f("pacing", "flee_ms", 0.0)))
	return true


# ---- commands ----

func _get_party_command(c: BattleCombatant) -> Dictionary:
	var invalid: int = 0
	while true:
		var options: Dictionary = _build_options(c)
		var cmd: Dictionary = {}
		if setup.command_source != null:
			cmd = setup.command_source.call("choose_command", self, c.id, options)
		else:
			_pending_command = {}
			_awaiting_actor = c.id
			command_needed.emit(c.id, options)
			if _pending_command.is_empty():
				await _command_submitted
			cmd = _pending_command
			_pending_command = {}
			_awaiting_actor = ""
			if is_over:
				return {"kind": KIND_DEFEND}
		var checked: Dictionary = _check_command(c, cmd)
		if str(checked.get("error", "")).is_empty():
			return checked["command"]
		message.emit(str(checked["error"]))
		invalid += 1
		if invalid >= MAX_INVALID_COMMANDS:
			return {"kind": KIND_DEFEND}
	return {"kind": KIND_DEFEND}


## The menu for a party member's turn (the command_needed payload).
func _build_options(c: BattleCombatant) -> Dictionary:
	var blocked: bool = BattleStatusRules.blocks_skills(data, c)
	var skill_list: Array[Dictionary] = []
	for skill_id: String in c.known_skills:
		var skill: Dictionary = data.skill(skill_id)
		skill_list.append({"id": skill_id, "name": str(skill.get("name", skill_id)),
			"juice_cost": int(skill["juice_cost"]),
			"usable": not blocked and c.juice >= int(skill["juice_cost"]),
			"target": str(skill.get("target", "one_enemy"))})
	var item_list: Array[Dictionary] = []
	for item_id: String in data.battle_items:
		var count: int = int(_bag.get(item_id, 0))
		if count <= 0:
			continue
		var item: Dictionary = data.battle_item(item_id)
		var escape: bool = bool((item.get("effect", {}) as Dictionary).get("escape", false))
		item_list.append({"id": item_id, "name": str(item.get("name", item_id)), "count": count,
			"target": str(item.get("target", "one_ally")), "usable": _can_run or not escape})
	return {"attack": true, "skills": skill_list, "items": item_list, "defend": true, "run": _can_run}


## Validates a submitted command and fills in automatic targets. {"command": cmd} or {"error": text}.
func _check_command(c: BattleCombatant, cmd: Dictionary) -> Dictionary:
	var kind: String = str(cmd.get("kind", ""))
	var fixed: Dictionary = {"kind": kind}
	match kind:
		KIND_DEFEND:
			return {"command": fixed}
		KIND_RUN:
			if not _can_run:
				return {"error": MSG_CANT_RUN}
			return {"command": fixed}
		KIND_ATTACK:
			var attack: Dictionary = data.skill(c.attack_skill)
			var attack_targets: Array[String] = _resolve_targets(c, str(attack.get("target", "one_enemy")), cmd)
			if attack_targets.is_empty():
				return {"error": MSG_NO_TARGET}
			fixed["skill_id"] = c.attack_skill
			fixed["targets"] = attack_targets
			return {"command": fixed}
		KIND_SKILL:
			var skill_id: String = str(cmd.get("skill_id", ""))
			if not c.known_skills.has(skill_id):
				return {"error": "%s doesn't know that." % c.display_name}
			if BattleStatusRules.blocks_skills(data, c):
				return {"error": MSG_NOISE_TICKET}
			var skill: Dictionary = data.skill(skill_id)
			if c.juice < int(skill["juice_cost"]):
				return {"error": MSG_NO_JUICE}
			var skill_targets: Array[String] = _resolve_targets(c, str(skill.get("target", "one_enemy")), cmd)
			if skill_targets.is_empty():
				return {"error": MSG_NO_TARGET}
			fixed["skill_id"] = skill_id
			fixed["targets"] = skill_targets
			return {"command": fixed}
		KIND_ITEM:
			var item_id: String = str(cmd.get("item_id", ""))
			var item: Dictionary = data.battle_item(item_id)
			if item.is_empty() or int(_bag.get(item_id, 0)) <= 0:
				return {"error": "None left."}
			var effect: Dictionary = item.get("effect", {})
			if bool(effect.get("escape", false)) and not _can_run:
				return {"error": MSG_CANT_RUN}
			var item_targets: Array[String] = _resolve_targets(c, str(item.get("target", "one_ally")), cmd)
			if item_targets.is_empty():
				return {"error": MSG_NO_TARGET}
			fixed["item_id"] = item_id
			fixed["targets"] = item_targets
			return {"command": fixed}
	return {"error": "Unknown command."}


## Turns the player's chosen targets into a valid list for a target type ([] = invalid).
func _resolve_targets(c: BattleCombatant, target_type: String, cmd: Dictionary) -> Array[String]:
	var wanted: Array[String] = []
	for id: Variant in cmd.get("targets", []):
		wanted.append(str(id))
	var out: Array[String] = []
	match target_type:
		"all_enemies":
			for t: BattleCombatant in state.opponents_of(c):
				out.append(t.id)
		"all_allies":
			for t: BattleCombatant in state.allies_of(c):
				out.append(t.id)
		"self":
			out.append(c.id)
		"one_enemy":
			if wanted.size() == 1:
				var foe: BattleCombatant = state.get_c(wanted[0])
				if foe != null and foe.is_active() and foe.side != c.side:
					out.append(foe.id)
		"one_ally":
			if wanted.size() == 1:
				var friend: BattleCombatant = state.get_c(wanted[0])
				if friend != null and friend.is_active() and friend.side == c.side:
					out.append(friend.id)
		"one_down_ally":
			if wanted.size() == 1:
				var fallen: BattleCombatant = state.get_c(wanted[0])
				if fallen != null and fallen.down and fallen.side == c.side:
					out.append(fallen.id)
	return out


func _execute_party(c: BattleCombatant, cmd: Dictionary) -> void:
	match str(cmd["kind"]):
		KIND_ATTACK, KIND_SKILL:
			var skill: Dictionary = data.skill(str(cmd["skill_id"]))
			await _run_skill_action(c, skill, cmd["targets"], str(cmd["kind"]))
		KIND_ITEM:
			await _run_item_action(c, str(cmd["item_id"]), cmd["targets"])
		KIND_DEFEND:
			await _do_defend(c)
		KIND_RUN:
			await _do_run(c, false)


func _execute_enemy(c: BattleCombatant) -> void:
	var choice: Dictionary = BattleEnemyAI.choose(data, c, state, round_number, rng)
	if choice.is_empty():
		await _wait_ms(int(data.f("pacing", "skip_turn_ms", 0.0)))
		return
	var targets: Array[String] = choice["targets"]
	await _run_skill_action(c, data.skill(str(choice["skill_id"])), targets, KIND_SKILL)


# ---- Defend and Run ----

func _do_defend(c: BattleCombatant) -> void:
	c.defending = true
	var gain: int = int(data.f("juice", "defend_gain", 0.0))
	c.juice = mini(c.juice + gain, c.juice_max)
	var timeline: Dictionary = _pacing_timeline("defend_timeline_ms")
	var t0: int = clock.now_usec()
	var action: Dictionary = {"actor": c.id, "kind": KIND_DEFEND, "skill_id": "", "name": "Defend",
		"targets": [c.id] as Array[String], "t0_usec": t0, "timeline_ms": timeline, "presses": [],
		"anim": "defend", "show_name": false}
	action_started.emit(action)
	await clock.wait_until_usec(t0 + int(timeline["impact"]) * 1000)
	_emit_stats(c)
	await _wait_tail(t0 + int(timeline["end"]) * 1000)
	action_finished.emit(action)


## Run: a roll from speeds, or a sure thing (Smoke Bomb). Never works when can_run is false.
func _do_run(c: BattleCombatant, guaranteed: bool) -> void:
	var timeline: Dictionary = _pacing_timeline("run_timeline_ms")
	var t0: int = clock.now_usec()
	var action: Dictionary = {"actor": c.id, "kind": KIND_RUN, "skill_id": "", "name": "Run",
		"targets": [] as Array[String], "t0_usec": t0, "timeline_ms": timeline, "presses": [],
		"anim": "run", "show_name": false}
	action_started.emit(action)
	var success: bool = guaranteed or rng.randf() < _run_chance()
	await clock.wait_until_usec(t0 + int(timeline["impact"]) * 1000)
	if success:
		message.emit(MSG_RAN)
		action_finished.emit(action)
		await _finish(RESULT_RAN)
		return
	message.emit(MSG_NOT_RAN)
	await _wait_tail(t0 + int(timeline["end"]) * 1000)
	action_finished.emit(action)


func _run_chance() -> float:
	var party_speed: float = _average_speed(state.active_members(BattleCombatant.SIDE_PARTY))
	var enemy_speed: float = _average_speed(state.active_members(BattleCombatant.SIDE_ENEMY))
	var chance: float = data.f("run", "base_chance", 0.5) + (party_speed - enemy_speed) * data.f("run", "per_speed_point", 0.0)
	return clampf(chance, data.f("run", "min_chance", 0.0), data.f("run", "max_chance", 1.0))


func _average_speed(list: Array[BattleCombatant]) -> float:
	if list.is_empty():
		return 0.0
	var total: float = 0.0
	for c: BattleCombatant in list:
		total += c.stat("speed")
	return total / float(list.size())


func _pacing_timeline(key: String) -> Dictionary:
	var raw: Dictionary = data.f_dict("pacing").get(key, {})
	return {"windup": int(raw.get("windup", 0)), "impact": int(raw.get("impact", 0)),
		"end": int(raw.get("end", 0)), "impacts": [int(raw.get("impact", 0))]}


# ---- skill actions ----

func _run_skill_action(actor: BattleCombatant, skill: Dictionary, target_ids: Array[String], kind: String) -> void:
	var primary: Array[String] = _maybe_wobble(actor, skill, target_ids)
	if _live_targets(primary).is_empty():
		return
	var t0: int = clock.now_usec()
	_downs.clear()
	_ups.clear()
	var slots: Array[Dictionary] = _build_slots(actor, skill, primary, t0)
	var cost: int = int(skill["juice_cost"])
	if cost > 0:
		actor.juice = maxi(actor.juice - cost, 0)
		_emit_stats(actor)
	var action: Dictionary = _skill_action_dict(actor, kind, skill, primary, t0, slots)
	action_started.emit(action)
	_plan_source_presses(slots)
	var timeline: Dictionary = skill["timeline_ms"]
	for fx_variant: Variant in skill["effects"]:
		var fx: Dictionary = fx_variant
		await clock.wait_until_usec(t0 + int(fx["at_ms"]) * 1000)
		await _apply_effect(actor, skill, fx, primary, slots)
		if not _outcome().is_empty():
			break
	if _outcome().is_empty():
		for slot: Dictionary in slots:
			if bool(slot["enabled"]) and not bool(slot["resolved"]):
				await _resolve_slot(slot)
		await _wait_tail(t0 + int(timeline["end"]) * 1000)
	action_finished.emit(action)


## Wobbly: a one-target hostile move may go to a random fighter instead, friends included.
func _maybe_wobble(actor: BattleCombatant, skill: Dictionary, target_ids: Array[String]) -> Array[String]:
	if str(skill.get("target", "")) != "one_enemy":
		return target_ids
	var chance: float = BattleStatusRules.random_target_chance(data, actor)
	if chance <= 0.0 or rng.randf() >= chance:
		return target_ids
	var pool: Array[BattleCombatant] = []
	for c: BattleCombatant in state.all_active():
		if c != actor:
			pool.append(c)
	if pool.is_empty():
		return target_ids
	message.emit(MSG_WOBBLY)
	var ids: Array[String] = [pool[rng.randi_range(0, pool.size() - 1)].id]
	return ids


func _live_targets(ids: Array[String]) -> Array[BattleCombatant]:
	var out: Array[BattleCombatant] = []
	for id: String in ids:
		var c: BattleCombatant = state.get_c(id)
		if c != null and c.is_active():
			out.append(c)
	return out


func _skill_action_dict(actor: BattleCombatant, kind: String, skill: Dictionary, targets: Array[String],
		t0: int, slots: Array[Dictionary]) -> Dictionary:
	var timeline: Dictionary = (skill["timeline_ms"] as Dictionary).duplicate()
	var impacts: Array[int] = []
	for fx_variant: Variant in skill["effects"]:
		var at_ms: int = int((fx_variant as Dictionary)["at_ms"])
		if not impacts.has(at_ms):
			impacts.append(at_ms)
	timeline["impacts"] = impacts
	var presses: Array[Dictionary] = []
	for slot: Dictionary in slots:
		if bool(slot["enabled"]):
			presses.append(_press_info(slot))
	return {"actor": actor.id, "kind": kind, "skill_id": str(skill["id"]), "name": str(skill.get("name", "")),
		"targets": targets, "t0_usec": t0, "timeline_ms": timeline, "presses": presses,
		"anim": str(skill.get("anim", "")), "show_name": bool(skill.get("show_name", false)),
		"tell": str(skill.get("tell", "")), "contact": str(skill.get("contact", "melee"))}


func _press_info(slot: Dictionary) -> Dictionary:
	var info: Dictionary = {"index": slot["index"], "type": slot["press_type"], "side": slot["side"],
		"cue_ms": slot["cue_ms"], "hold_by_ms": slot["hold_by_ms"], "owner_id": slot["owner_id"],
		"scrambled": slot["scrambled"], "window_ms": slot["window_ms"]}
	if bool(slot["scrambled"]):
		info["shown_cue_ms"] = slot["shown_cue_ms"]
	return info


## One slot per press of the skill. The press belongs to the actor (attack side) or to the
## party member being hit (block side). A block press with no party target is disabled.
func _build_slots(actor: BattleCombatant, skill: Dictionary, targets: Array[String], t0: int) -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	var presses: Array = skill["presses"]
	var offset_ms: int = setup.timing_offset_ms
	for i: int in presses.size():
		var press: Dictionary = presses[i]
		var side: String = SIDE_ATTACK if actor.is_party() else SIDE_BLOCK
		var owner: BattleCombatant = actor
		if side == SIDE_BLOCK:
			owner = null
			for target: BattleCombatant in _live_targets(targets):
				if target.is_party():
					owner = target
					break
		var press_type: String = str(press["type"])
		var cue_ms: int = int(press["cue_ms"])
		var hold_by_ms: int = int(press.get("hold_by_ms", 0))
		var mult: float = ClutchJudge.window_multiplier(data.windows_doc.get("modifiers", {}), setup.wide_windows, false)
		if owner != null:
			if side == SIDE_BLOCK and owner.defending:
				mult *= data.window_modifier("defending_block")
			mult *= BattleStatusRules.window_mult(data, owner)
		var window: Dictionary = data.window(str(press.get("window", "standard")))
		var hold_from: int = ClutchJudge.NO_PRESS
		if press.has("hold_from_ms"):
			hold_from = ClutchJudge.cue_usec(t0, int(press["hold_from_ms"]), offset_ms)
		var slot: Dictionary = ClutchJudge.make_slot(press_type, ClutchJudge.cue_usec(t0, cue_ms, offset_ms),
			ClutchJudge.cue_usec(t0, hold_by_ms, offset_ms), data.listen_before_ms(), window, mult, hold_from)
		slot["index"] = i
		slot["actor_id"] = actor.id
		slot["press_type"] = press_type
		slot["side"] = side
		slot["owner_id"] = owner.id if owner != null else ""
		slot["enabled"] = owner != null
		slot["resolved"] = false
		slot["result"] = {}
		slot["cue_ms"] = cue_ms
		slot["hold_by_ms"] = hold_by_ms if press_type == ClutchJudge.TYPE_HOLD else 0
		slot["scrambled"] = press.has("shown_cue_ms")
		slot["shown_cue_ms"] = int(press.get("shown_cue_ms", cue_ms))
		slot["window_ms"] = {"nice": float(window.get("nice_ms", 0.0)) * mult,
			"rad": float(window.get("rad_ms", 0.0)) * mult,
			"totally_rad": float(window.get("totally_rad_ms", 0.0)) * mult}
		slots.append(slot)
	return slots


## Simulator players plan their presses from the cue as soon as the action starts.
func _plan_source_presses(slots: Array[Dictionary]) -> void:
	if press_source.is_human() or not press_source.forced_rating().is_empty():
		return
	for slot: Dictionary in slots:
		if not bool(slot["enabled"]):
			continue
		var planned: Dictionary = press_source.plan(slot, press_rng)
		for t: int in (planned["downs"] as Array[int]):
			_insert_sorted(_downs, t)
		for t: int in (planned["ups"] as Array[int]):
			_insert_sorted(_ups, t)


## Waits (without ever blocking the loop) until a slot has an answer, then reports it.
func _resolve_slot(slot: Dictionary) -> Dictionary:
	if bool(slot["resolved"]):
		return slot["result"]
	var verdict: Dictionary = {}
	var forced: String = press_source.forced_rating()
	if not forced.is_empty():
		verdict = {"rating": forced, "delta_ms": 0.0, "pressed": true}
	else:
		while true:
			var now: int = clock.now_usec()
			verdict = ClutchJudge.decide(slot, _downs, _ups, now)
			if bool(verdict["decided"]):
				break
			var next_time: int = ClutchJudge.next_decision_usec(slot, _downs, _ups, now)
			var step: int = mini(next_time, now + clock.poll_usec())
			if step <= now:
				step = now + MIN_STEP_USEC
			await clock.wait_until_usec(step)
		if int(verdict["used_down"]) != ClutchJudge.NO_PRESS:
			_downs.erase(int(verdict["used_down"]))
		if int(verdict["used_up"]) != ClutchJudge.NO_PRESS:
			_ups.erase(int(verdict["used_up"]))
	slot["resolved"] = true
	slot["result"] = verdict
	_press_resolved(slot, verdict)
	return verdict


func _press_resolved(slot: Dictionary, verdict: Dictionary) -> void:
	var rating: String = str(verdict["rating"])
	var owner: BattleCombatant = state.get_c(str(slot["owner_id"]))
	if owner != null and owner.is_party() and ClutchJudge.is_rad_or_better(rating):
		var table_key: String = "juice_gain" if str(slot["side"]) == SIDE_ATTACK else "juice_gain_block"
		var gain: int = int((data.windows_doc.get(table_key, {}) as Dictionary).get(rating, 0))
		if gain > 0 and owner.is_active():
			owner.juice = mini(owner.juice + gain, owner.juice_max)
			_emit_stats(owner)
	press_judged.emit({"actor": slot["actor_id"], "index": slot["index"],
		"side": slot["side"], "rating": rating, "delta_ms": float(verdict["delta_ms"]),
		"owner_id": slot["owner_id"], "pressed": bool(verdict.get("pressed", false))})


# ---- effects ----

func _apply_effect(actor: BattleCombatant, skill: Dictionary, fx: Dictionary, primary: Array[String],
		slots: Array[Dictionary]) -> void:
	var rating: String = ClutchJudge.RATING_MISS
	var side: String = ""
	var owner_id: String = ""
	if fx.has("press") and int(fx["press"]) < slots.size():
		var slot: Dictionary = slots[int(fx["press"])]
		if bool(slot["enabled"]):
			var verdict: Dictionary = await _resolve_slot(slot)
			rating = str(verdict["rating"])
			side = str(slot["side"])
			owner_id = str(slot["owner_id"])
	_apply_one(actor, skill, fx, primary, rating, side, owner_id)


func _apply_one(actor: BattleCombatant, skill: Dictionary, fx: Dictionary, primary: Array[String],
		rating: String, side: String, owner_id: String) -> void:
	match str(fx["kind"]):
		"damage":
			_fx_damage(actor, skill, fx, primary, rating, side, owner_id)
		"heal":
			_fx_heal(actor, fx, primary, rating, side)
		"restore_juice":
			for t: BattleCombatant in _effect_targets(actor, str(fx.get("target", "primary")), primary):
				_add_juice(t, int(fx.get("amount", 0)))
		"status":
			for t: BattleCombatant in _effect_targets(actor, str(fx.get("target", "primary")), primary):
				_apply_status_list(actor, t, fx.get("statuses", []), ClutchJudge.BLOCK_NONE)
		"wheel":
			_fx_wheel(actor, skill, fx, primary, rating)


func _fx_damage(actor: BattleCombatant, skill: Dictionary, fx: Dictionary, primary: Array[String],
		rating: String, side: String, owner_id: String) -> void:
	var on_rating: Dictionary = (fx.get("on_rating", {}) as Dictionary).get(rating, {})
	var rating_mult: float = 1.0
	if side == SIDE_ATTACK:
		rating_mult = float(on_rating.get("power_mult", data.rating_power(rating)))
	var defend_mult: float = data.f("damage", "defend_mult", 1.0)
	var reductions: Dictionary = data.windows_doc.get("block_reduction", {})
	for target: BattleCombatant in _effect_targets(actor, str(fx.get("target", "primary")), primary):
		if not target.is_active():
			continue
		var reduction: float = 0.0
		var blocked: String = ClutchJudge.BLOCK_NONE
		if side == SIDE_BLOCK and target.id == owner_id:
			reduction = float(reductions.get(rating, 0.0))
			blocked = ClutchJudge.block_tier(rating)
		var amount: int = BattleDamage.hit_damage(data, actor.stat(str(fx.get("stat", "attack"))),
			float(fx.get("power", 1.0)), target.stat("defense"), rating_mult,
			defend_mult if target.defending else 1.0, reduction, rng)
		target.hp = maxi(target.hp - amount, 0)
		hit.emit({"source": actor.id, "target": target.id, "amount": amount, "kind": "damage",
			"blocked": blocked, "payback": false})
		_emit_stats(target)
		if target.hp <= 0:
			_down(target)
		else:
			var landing: Array = []
			landing.append_array(fx.get("statuses", []))
			landing.append_array(on_rating.get("statuses", []))
			if blocked != ClutchJudge.BLOCK_PERFECT:
				_apply_status_list(actor, target, landing, blocked)
		if blocked == ClutchJudge.BLOCK_PERFECT and str(skill.get("contact", "")) == "melee":
			_payback(target, actor)


## A perfect block of a close-up hit: the defender swings back for free.
func _payback(defender: BattleCombatant, attacker: BattleCombatant) -> void:
	if not defender.is_party() or not defender.is_active() or not attacker.is_active():
		return
	var amount: int = BattleDamage.hit_damage(data, defender.stat("attack"),
		float(data.windows_doc.get("payback_power", 0.0)), attacker.stat("defense"), 1.0, 1.0, 0.0, rng)
	attacker.hp = maxi(attacker.hp - amount, 0)
	hit.emit({"source": defender.id, "target": attacker.id, "amount": amount, "kind": "damage",
		"blocked": ClutchJudge.BLOCK_NONE, "payback": true})
	_emit_stats(attacker)
	if attacker.hp <= 0:
		_down(attacker)


func _fx_heal(actor: BattleCombatant, fx: Dictionary, primary: Array[String], rating: String, side: String) -> void:
	var on_rating: Dictionary = (fx.get("on_rating", {}) as Dictionary).get(rating, {})
	var rating_mult: float = 1.0
	if side == SIDE_ATTACK:
		rating_mult = float(on_rating.get("power_mult", data.rating_power(rating)))
	for target: BattleCombatant in _effect_targets(actor, str(fx.get("target", "primary")), primary):
		if not target.is_active():
			continue
		var amount: int = BattleDamage.heal_amount(data, actor.stat(str(fx.get("stat", "heart"))),
			float(fx.get("power", 0.0)), float(fx.get("flat", 0.0)), rating_mult, rng)
		_heal(actor, target, amount)


func _heal(source: BattleCombatant, target: BattleCombatant, amount: int) -> void:
	var healed: int = mini(amount, target.hp_max - target.hp)
	target.hp += healed
	if healed > 0:
		hit.emit({"source": source.id, "target": target.id, "amount": healed, "kind": "heal",
			"blocked": ClutchJudge.BLOCK_NONE, "payback": false})
		_emit_stats(target)


func _fx_wheel(actor: BattleCombatant, skill: Dictionary, fx: Dictionary, primary: Array[String], rating: String) -> void:
	var tiers: Dictionary = fx.get("tiers", {})
	var options: Array = tiers.get(rating, [])
	if options.is_empty():
		return
	var result_entry: Dictionary = _weighted_pick(options)
	skill_result.emit({"actor": actor.id, "skill_id": str(skill["id"]), "tier": rating,
		"result_id": str(result_entry.get("id", "")), "name": str(result_entry.get("name", ""))})
	message.emit("%s!" % str(result_entry.get("name", "")))
	for sub_variant: Variant in result_entry.get("effects", []):
		_apply_one(actor, skill, sub_variant as Dictionary, primary, ClutchJudge.RATING_MISS, "", "")


func _weighted_pick(options: Array) -> Dictionary:
	if options.size() == 1:
		return options[0]
	var total: float = 0.0
	for entry_variant: Variant in options:
		total += float((entry_variant as Dictionary).get("weight", 1.0))
	var roll: float = rng.randf() * total
	for entry_variant: Variant in options:
		roll -= float((entry_variant as Dictionary).get("weight", 1.0))
		if roll < 0.0:
			return entry_variant
	return options[options.size() - 1]


func _effect_targets(actor: BattleCombatant, target_type: String, primary: Array[String]) -> Array[BattleCombatant]:
	var out: Array[BattleCombatant] = []
	match target_type:
		"primary":
			for id: String in primary:
				var c: BattleCombatant = state.get_c(id)
				if c != null:
					out.append(c)
		"all_enemies":
			out = state.opponents_of(actor)
		"all_allies":
			out = state.allies_of(actor)
		"self":
			out.append(actor)
		"random_other_enemy":
			var pool: Array[BattleCombatant] = []
			for c: BattleCombatant in state.opponents_of(actor):
				if not primary.has(c.id):
					pool.append(c)
			if not pool.is_empty():
				out.append(pool[rng.randi_range(0, pool.size() - 1)])
	return out


# ---- items ----

func _run_item_action(actor: BattleCombatant, item_id: String, target_ids: Array[String]) -> void:
	var item: Dictionary = data.battle_item(item_id)
	var effect: Dictionary = item.get("effect", {})
	_bag[item_id] = int(_bag.get(item_id, 0)) - 1
	_items_used[item_id] = int(_items_used.get(item_id, 0)) + 1
	if bool(effect.get("escape", false)):
		await _do_run(actor, true)
		return
	var timeline: Dictionary = _pacing_timeline("item_timeline_ms")
	var t0: int = clock.now_usec()
	var action: Dictionary = {"actor": actor.id, "kind": KIND_ITEM, "skill_id": item_id,
		"name": str(item.get("name", item_id)), "targets": target_ids, "t0_usec": t0, "timeline_ms": timeline,
		"presses": [], "anim": "item", "show_name": true}
	action_started.emit(action)
	await clock.wait_until_usec(t0 + int(timeline["impact"]) * 1000)
	for id: String in target_ids:
		var target: BattleCombatant = state.get_c(id)
		if target != null:
			_apply_item_effect(actor, target, effect)
	if _outcome().is_empty():
		await _wait_tail(t0 + int(timeline["end"]) * 1000)
	action_finished.emit(action)


func _apply_item_effect(actor: BattleCombatant, target: BattleCombatant, effect: Dictionary) -> void:
	if effect.has("revive_hp_pct"):
		if target.down:
			target.down = false
			target.hp = maxi(int(round(float(target.hp_max) * float(effect["revive_hp_pct"]) / 100.0)), 1)
			combatant_revived.emit(target.id)
			hit.emit({"source": actor.id, "target": target.id, "amount": target.hp, "kind": "heal",
				"blocked": ClutchJudge.BLOCK_NONE, "payback": false})
			_emit_stats(target)
		return
	if not target.is_active():
		return
	if effect.has("heal_hp"):
		_heal(actor, target, int(effect["heal_hp"]))
	if effect.has("heal_hp_pct"):
		_heal(actor, target, int(round(float(target.hp_max) * float(effect["heal_hp_pct"]) / 100.0)))
	if effect.has("restore_juice"):
		_add_juice(target, int(effect["restore_juice"]))
	if effect.has("restore_juice_pct"):
		_add_juice(target, int(round(float(target.juice_max) * float(effect["restore_juice_pct"]) / 100.0)))
	for status_id: Variant in effect.get("cure", []):
		if target.statuses.erase(str(status_id)):
			status_changed.emit(target.id, str(status_id), false)
	if effect.has("damage"):
		var amount: int = int(effect["damage"])
		target.hp = maxi(target.hp - amount, 0)
		hit.emit({"source": actor.id, "target": target.id, "amount": amount, "kind": "damage",
			"blocked": ClutchJudge.BLOCK_NONE, "payback": false})
		_emit_stats(target)
		if target.hp <= 0:
			_down(target)
		else:
			_apply_status_list(actor, target, effect.get("statuses", []), ClutchJudge.BLOCK_NONE)


# ---- statuses, Juice, down ----

func _apply_status_list(source: BattleCombatant, target: BattleCombatant, list: Array, _blocked: String) -> void:
	for entry_variant: Variant in list:
		var entry: Dictionary = entry_variant
		_try_status(source, target, str(entry.get("id", "")), float(entry.get("chance", 1.0)))


func _try_status(source: BattleCombatant, target: BattleCombatant, status_id: String, base_chance: float) -> void:
	if not target.is_active() or not data.statuses.has(status_id):
		return
	var def: Dictionary = data.status(status_id)
	var resist: float = float(target.status_resist.get(status_id, 0.0))
	var chance: float = BattleStatusRules.landing_chance(data, base_chance, source.stat("luck"), target.stat("luck"), resist)
	if rng.randf() >= chance:
		return
	var already: bool = target.statuses.has(status_id)
	target.statuses[status_id] = int(def.get("duration_turns", 1))
	if not already:
		status_changed.emit(target.id, status_id, true)


func _add_juice(target: BattleCombatant, amount: int) -> void:
	if amount <= 0 or not target.is_active():
		return
	target.juice = mini(target.juice + amount, target.juice_max)
	_emit_stats(target)


func _down(c: BattleCombatant) -> void:
	c.hp = 0
	c.down = true
	c.defending = false
	for status_id: String in c.statuses.keys():
		c.statuses.erase(status_id)
		status_changed.emit(c.id, status_id, false)
	_last_ko_id = c.id
	combatant_down.emit(c.id)


func _emit_stats(c: BattleCombatant) -> void:
	stats_changed.emit(c.id, c.hp, c.hp_max, c.juice, c.juice_max)


# ---- ending ----

func _finish(res: String) -> void:
	if is_over:
		return
	is_over = true
	result = res
	if res != RESULT_RAN:
		await _wait_ms(int(data.f("pacing", "ko_beat_ms", 0.0)))
	end_usec = clock.now_usec()
	_build_report(res)
	if setup.game_state != null and res != RESULT_LOSE:
		BattleResults.apply(setup.game_state, get_result())
	battle_ended.emit(res, report)


func _build_report(res: String) -> void:
	report = {"xp": 0, "credits": 0, "drops": [] as Array[Dictionary], "level_ups": [] as Array[Dictionary],
		"final_ko_target": ""}
	var final_members: Array[Dictionary] = []
	for c: BattleCombatant in state.side_members(BattleCombatant.SIDE_PARTY):
		final_members.append(_member_from(c))
	var bench_members: Array[Dictionary] = []
	for member: Dictionary in _bench:
		bench_members.append(member.duplicate(true))
	if res == RESULT_WIN:
		var enemies: Array[BattleCombatant] = state.side_members(BattleCombatant.SIDE_ENEMY)
		var luck: float = _average_luck()
		var rewards: Dictionary = BattleRewards.compute(data, enemies, luck, rng)
		report["xp"] = rewards["xp"]
		report["credits"] = rewards["credits"]
		report["drops"] = rewards["drops"]
		var revive_pct: float = data.f("rewards", "after_win_revive_pct", 0.0)
		for member: Dictionary in final_members:
			if int(member["hp"]) <= 0 and revive_pct > 0.0:
				member["hp"] = maxi(int(round(float(member["hp_max"]) * revive_pct / 100.0)), 1)
		var party_ids: Array[String] = []
		for member: Dictionary in final_members:
			party_ids.append(str(member["id"]))
		var bench_ids: Array[String] = []
		for member: Dictionary in bench_members:
			bench_ids.append(str(member["id"]))
		var shares: Dictionary = progression.xp_shares(party_ids, bench_ids)
		var level_ups: Array[Dictionary] = []
		for member: Dictionary in final_members + bench_members:
			var share: float = float(shares.get(str(member["id"]), 0.0))
			if share <= 0.0:
				continue
			var record: Dictionary = progression.apply_xp(member, int(round(float(rewards["xp"]) * share)))
			if not record.is_empty():
				level_ups.append(record)
		report["level_ups"] = level_ups
		var last: BattleCombatant = state.get_c(_last_ko_id)
		if last != null and not last.is_party():
			report["final_ko_target"] = last.id
		for drop_variant: Variant in rewards["drops"]:
			var drop: Dictionary = drop_variant
			_bag[str(drop["item"])] = int(_bag.get(str(drop["item"]), 0)) + int(drop["count"])
	elif res == RESULT_LOSE:
		var last_down: BattleCombatant = state.get_c(_last_ko_id)
		if last_down != null:
			report["final_ko_target"] = last_down.id
	_final_party = final_members
	_final_bench = bench_members


func _member_from(c: BattleCombatant) -> Dictionary:
	var member: Dictionary = {"id": c.id, "level": c.level, "xp": c.xp, "hp": c.hp, "hp_max": c.hp_max,
		"juice": c.juice, "juice_max": c.juice_max}
	if not c.bonus.is_empty():
		member["bonus"] = c.bonus
	return member


func _average_luck() -> float:
	var members: Array[BattleCombatant] = state.side_members(BattleCombatant.SIDE_PARTY)
	if members.is_empty():
		return 0.0
	var total: float = 0.0
	for c: BattleCombatant in members:
		total += c.stat("luck")
	return total / float(members.size())


# ---- small helpers ----

func _wait_ms(ms: int) -> void:
	if ms <= 0:
		return
	await clock.wait_until_usec(clock.now_usec() + ms * 1000)


## The pause at the end of an action; shrinks to nothing once the player asked to skip.
func _wait_tail(t_usec: int) -> void:
	if _skip:
		return
	await clock.wait_until_usec(t_usec)


func _insert_sorted(list: Array[int], t: int) -> void:
	var index: int = list.size()
	while index > 0 and list[index - 1] > t:
		index -= 1
	list.insert(index, t)
