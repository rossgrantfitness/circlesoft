class_name BattleSimPolicy
extends RefCounted
## The simulator's party command policy (tech plan): attack, heal when someone is under 40% HP,
## use the signature move when Juice allows. Revives a downed friend first when it can.
## It only reads the battle through the controller, the same information a player has.

var heal_below_pct: float = 40.0
## Also use the two basic skills when Juice is plentiful (off by default: the plan's policy).
var use_basic_skills: bool = false


func _init(sim_settings: Dictionary = {}) -> void:
	heal_below_pct = float(sim_settings.get("heal_below_pct", heal_below_pct))
	use_basic_skills = bool(sim_settings.get("use_basic_skills", use_basic_skills))


func choose_command(controller: BattleController, actor_id: String, options: Dictionary) -> Dictionary:
	var actor: BattleCombatant = controller.state.get_c(actor_id)
	var party: Array[BattleCombatant] = controller.state.side_members(BattleCombatant.SIDE_PARTY)
	var foes: Array[BattleCombatant] = controller.state.active_members(BattleCombatant.SIDE_ENEMY)
	var revive: Dictionary = _revive(actor, party, options)
	if not revive.is_empty():
		return revive
	var heal: Dictionary = _heal(actor, party, options)
	if not heal.is_empty():
		return heal
	var skill: Dictionary = _best_skill(controller, actor, foes, options)
	if not skill.is_empty():
		return skill
	return {"kind": "attack", "targets": [_weakest(foes).id]}


func _revive(actor: BattleCombatant, party: Array[BattleCombatant], options: Dictionary) -> Dictionary:
	if not _has_item(options, "smelling_salts"):
		return {}
	for c: BattleCombatant in party:
		if c.down:
			return {"kind": "item", "item_id": "smelling_salts", "targets": [c.id]}
	return {}


func _heal(actor: BattleCombatant, party: Array[BattleCombatant], options: Dictionary) -> Dictionary:
	var needy: BattleCombatant = null
	for c: BattleCombatant in party:
		if c.is_active() and c.hp_pct() < heal_below_pct and (needy == null or c.hp_pct() < needy.hp_pct()):
			needy = c
	if needy == null:
		return {}
	var missing: int = needy.hp_max - needy.hp
	if missing >= 60 and _has_item(options, "can_of_chili"):
		return {"kind": "item", "item_id": "can_of_chili", "targets": [needy.id]}
	if _has_item(options, "ration_bar"):
		return {"kind": "item", "item_id": "ration_bar", "targets": [needy.id]}
	if _has_item(options, "can_of_chili"):
		return {"kind": "item", "item_id": "can_of_chili", "targets": [needy.id]}
	for entry_variant: Variant in options["skills"]:
		var entry: Dictionary = entry_variant
		if str(entry["target"]) == "one_ally" and bool(entry["usable"]):
			return {"kind": "skill", "skill_id": str(entry["id"]), "targets": [needy.id]}
	return {}


func _best_skill(controller: BattleController, actor: BattleCombatant, foes: Array[BattleCombatant], options: Dictionary) -> Dictionary:
	var signature: String = str(controller.data.character(actor.id).get("signature_skill", ""))
	var wanted: Array[String] = [signature]
	if use_basic_skills:
		for entry_variant: Variant in options["skills"]:
			var other: String = str((entry_variant as Dictionary)["id"])
			if other != signature and str((entry_variant as Dictionary)["target"]) in ["one_enemy", "all_enemies"]:
				wanted.append(other)
	for skill_id: String in wanted:
		for entry_variant: Variant in options["skills"]:
			var entry: Dictionary = entry_variant
			if str(entry["id"]) == skill_id and bool(entry["usable"]):
				if str(entry["target"]) == "all_enemies":
					return {"kind": "skill", "skill_id": skill_id, "targets": _ids(foes)}
				return {"kind": "skill", "skill_id": skill_id, "targets": [_weakest(foes).id]}
	return {}


func _has_item(options: Dictionary, item_id: String) -> bool:
	for entry_variant: Variant in options["items"]:
		if str((entry_variant as Dictionary)["id"]) == item_id and int((entry_variant as Dictionary)["count"]) > 0:
			return true
	return false


func _weakest(list: Array[BattleCombatant]) -> BattleCombatant:
	var weakest: BattleCombatant = list[0]
	for c: BattleCombatant in list:
		if c.hp < weakest.hp:
			weakest = c
	return weakest


func _ids(list: Array[BattleCombatant]) -> Array[String]:
	var out: Array[String] = []
	for c: BattleCombatant in list:
		out.append(c.id)
	return out
