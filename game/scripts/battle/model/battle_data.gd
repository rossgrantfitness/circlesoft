class_name BattleData
extends RefCounted
## Every battle number and name, read from game/data/ (battle/*.json, party/characters.json,
## growth.csv, xp_curve.csv). Nothing here is a balance value: this is only the loader, light
## normalising (JSON numbers arrive as floats) and a validator the tests run.
##
## BattleData.shared() reads through the DataDB autoload (or, if that is missing, a throw-away
## DataDB). Tests can build a BattleData from any provider with get_dict(id) / get_table(id).

const ID_SKILLS: String = "battle/skills"
const ID_ENEMIES: String = "battle/enemies"
const ID_STATUSES: String = "battle/statuses"
const ID_WINDOWS: String = "battle/timing_windows"
const ID_ENCOUNTERS: String = "battle/encounters"
const ID_FORMULAS: String = "battle/formulas"
const ID_FEEL: String = "battle/feel_targets"
const ID_BATTLE_ITEMS: String = "battle/battle_items"
const ID_BOSS_LINES: String = "text/boss_lines"
const ID_CHARACTERS: String = "party/characters"
const ID_GROWTH: String = "party/growth"
const ID_XP_CURVE: String = "party/xp_curve"
const ID_FIELD_ITEMS: String = "items/items"
const DATA_DB_SCRIPT: String = "res://scripts/core/data_db.gd"
const DATA_DB_NODE: NodePath = ^"DataDB"

const STAT_KEYS: Array[String] = ["hp", "juice", "attack", "defense", "heart", "speed", "luck"]
const RATINGS: Array[String] = ["miss", "nice", "rad", "totally_rad"]
const PRESS_TYPES: Array[String] = ["tap", "hold_release", "string"]
const EFFECT_KINDS: Array[String] = ["damage", "heal", "restore_juice", "status", "wheel", "jam"]
const EFFECT_TARGETS: Array[String] = ["primary", "random_other_enemy", "all_enemies", "all_allies", "self"]
const SKILL_TARGETS: Array[String] = ["one_enemy", "all_enemies", "one_ally", "all_allies", "self", "one_down_ally"]
const MS_KEYS: Array[String] = ["windup", "impact", "end"]

static var _shared: BattleData = null

var skills: Dictionary = {}
var enemies: Dictionary = {}
var statuses: Dictionary = {}
var encounters: Dictionary = {}
var encounter_order: Array[String] = []
var windows_doc: Dictionary = {}
var formulas: Dictionary = {}
var feel: Dictionary = {}
var battle_items: Dictionary = {}
var field_item_ids: Array[String] = []
## Consumables, boosters, key items and gear (items/items.json and items/equipment.json).
var item_data: ItemData = null
## boss id -> {event: [lines]} from text/boss_lines.json (placeholder memo lines until M6-2).
var boss_lines: Dictionary = {}
var characters: Dictionary = {}
var character_order: Array[String] = []
var rules: Dictionary = {}
## character id -> {level (int) -> {stat: int}}
var growth: Dictionary = {}
## level (int) -> total xp (int)
var xp_total: Dictionary = {}
var max_level: int = 1


static func shared() -> BattleData:
	if _shared == null:
		_shared = _load_default()
	return _shared


## Forget the cached copy (tests that edit data call this).
static func clear_shared() -> void:
	_shared = null


static func _load_default() -> BattleData:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null:
		var autoload: Node = tree.root.get_node_or_null(DATA_DB_NODE)
		if autoload != null:
			return load_from(autoload)
	var script: GDScript = load(DATA_DB_SCRIPT) as GDScript
	var db: Node = script.new() as Node
	db.call("load_all")
	var data: BattleData = load_from(db)
	db.free()
	return data


## Builds a BattleData from anything with get_dict(id) and get_table(id) (DataDB, or a test double).
static func load_from(provider: Object) -> BattleData:
	var data: BattleData = BattleData.new()
	data._read(provider)
	return data


func _read(provider: Object) -> void:
	var skills_doc: Dictionary = _copy(provider, ID_SKILLS)
	for entry: Variant in skills_doc.get("skills", []):
		var skill: Dictionary = _normalize_skill(entry as Dictionary)
		skills[str(skill["id"])] = skill
	var enemies_doc: Dictionary = _copy(provider, ID_ENEMIES)
	for entry: Variant in enemies_doc.get("enemies", []):
		var enemy: Dictionary = entry as Dictionary
		enemies[str(enemy["id"])] = enemy
	var status_doc: Dictionary = _copy(provider, ID_STATUSES)
	for entry: Variant in status_doc.get("statuses", []):
		var status: Dictionary = entry as Dictionary
		statuses[str(status["id"])] = status
	var encounter_doc: Dictionary = _copy(provider, ID_ENCOUNTERS)
	for entry: Variant in encounter_doc.get("encounters", []):
		var encounter: Dictionary = entry as Dictionary
		encounters[str(encounter["id"])] = encounter
		encounter_order.append(str(encounter["id"]))
	windows_doc = _copy(provider, ID_WINDOWS)
	formulas = _copy(provider, ID_FORMULAS)
	feel = _copy(provider, ID_FEEL)
	# One source of truth: items/items.json. The old battle/battle_items.json is still read (it is
	# empty now) so a test or mod can add a battle-only item there.
	var item_doc: Dictionary = _copy(provider, ID_BATTLE_ITEMS)
	for entry: Variant in item_doc.get("items", []):
		var item: Dictionary = entry as Dictionary
		battle_items[str(item["id"])] = item
	item_data = ItemData.load_from(provider)
	for item_id: String in item_data.item_order:
		field_item_ids.append(item_id)
	for item_id: String in item_data.battle_item_ids():
		var entry: Dictionary = item_data.item(item_id)
		battle_items[item_id] = {"id": item_id, "name": str(entry.get("name", item_id)),
			"target": str(entry.get("target", "one_ally")), "effect": (entry.get("effect", {}) as Dictionary).duplicate(true)}
	var lines_doc: Dictionary = _copy(provider, ID_BOSS_LINES)
	for boss_id: String in lines_doc:
		if not boss_id.begins_with("_"):
			boss_lines[boss_id] = lines_doc[boss_id]
	var char_doc: Dictionary = _copy(provider, ID_CHARACTERS)
	rules = char_doc.get("rules", {})
	for entry: Variant in char_doc.get("characters", []):
		var character: Dictionary = entry as Dictionary
		characters[str(character["id"])] = character
		character_order.append(str(character["id"]))
	_read_growth(provider.call("get_table", ID_GROWTH))
	_read_xp(provider.call("get_table", ID_XP_CURVE))


## A private deep copy, so editing one BattleData (tests do) never touches the shared data.
func _copy(provider: Object, id: String) -> Dictionary:
	var doc: Dictionary = provider.call("get_dict", id)
	return doc.duplicate(true)


func _read_growth(rows: Array) -> void:
	for row_variant: Variant in rows:
		var row: Dictionary = row_variant
		var char_id: String = str(row.get("character", ""))
		if not growth.has(char_id):
			growth[char_id] = {}
		var stats: Dictionary = {}
		for key: String in STAT_KEYS:
			stats[key] = int(row.get(key, 0))
		(growth[char_id] as Dictionary)[int(row.get("level", 0))] = stats


func _read_xp(rows: Array) -> void:
	for row_variant: Variant in rows:
		var row: Dictionary = row_variant
		var level: int = int(row.get("level", 0))
		xp_total[level] = int(row.get("total_xp", 0))
		max_level = maxi(max_level, level)


## Skills may be written in the short form (formula + on_rating + one press); turn that into effects.
func _normalize_skill(raw: Dictionary) -> Dictionary:
	var skill: Dictionary = raw.duplicate(true)
	var timeline: Dictionary = skill.get("timeline_ms", {})
	for key: String in MS_KEYS:
		timeline[key] = int(timeline.get(key, 0))
	skill["timeline_ms"] = timeline
	var presses: Array = skill.get("presses", [])
	for press_variant: Variant in presses:
		var press: Dictionary = press_variant
		press["cue_ms"] = int(press.get("cue_ms", 0))
		if press.has("hold_by_ms"):
			press["hold_by_ms"] = int(press["hold_by_ms"])
		if press.has("hold_from_ms"):
			press["hold_from_ms"] = int(press["hold_from_ms"])
		if press.has("shown_cue_ms"):
			press["shown_cue_ms"] = int(press["shown_cue_ms"])
	skill["presses"] = presses
	if not skill.has("effects") and skill.has("formula"):
		var formula: Dictionary = skill["formula"]
		var effect: Dictionary = {"at_ms": int(timeline["impact"]), "kind": "damage", "target": "primary",
			"stat": str(formula.get("stat", "attack")), "power": float(formula.get("power", 1.0))}
		if not presses.is_empty():
			effect["press"] = 0
		if skill.has("on_rating"):
			effect["on_rating"] = skill["on_rating"]
		skill["effects"] = [effect]
	var effects: Array = skill.get("effects", [])
	for effect_variant: Variant in effects:
		var fx: Dictionary = effect_variant
		fx["at_ms"] = int(fx.get("at_ms", timeline["impact"]))
	skill["effects"] = effects
	skill["juice_cost"] = int(skill.get("juice_cost", 0))
	skill["learn_level"] = int(skill.get("learn_level", 1))
	return skill


# ---- lookups ----

func skill(id: String) -> Dictionary:
	return skills.get(id, {})


func enemy(id: String) -> Dictionary:
	return enemies.get(id, {})


func status(id: String) -> Dictionary:
	return statuses.get(id, {})


func encounter(id: String) -> Dictionary:
	return encounters.get(id, {})


func character(id: String) -> Dictionary:
	return characters.get(id, {})


func battle_item(id: String) -> Dictionary:
	return battle_items.get(id, {})


## Half-widths in ms for a window name: {nice_ms, rad_ms, totally_rad_ms} (floats).
func window(name: String) -> Dictionary:
	var all: Dictionary = windows_doc.get("windows", {})
	return all.get(name, all.get("standard", {}))


func window_modifier(key: String) -> float:
	return float((windows_doc.get("modifiers", {}) as Dictionary).get(key, 1.0))


func listen_before_ms() -> int:
	return int(windows_doc.get("listen_before_ms", 0))


## A number from formulas.json: f("damage", "variance_pct", 8.0).
func f(section: String, key: String, fallback: float = 0.0) -> float:
	var block: Dictionary = formulas.get(section, {})
	return float(block.get(key, fallback))


func f_dict(section: String) -> Dictionary:
	return formulas.get(section, {})


func rating_power(rating: String) -> float:
	return float((formulas.get("rating_power", {}) as Dictionary).get(rating, 1.0))


# ---- validation (the data tests call this) ----

## Cross-reference and range checks. Returns one message per problem; empty = clean.
func validate() -> Array[String]:
	var errs: Array[String] = []
	_validate_skills(errs)
	_validate_enemies(errs)
	_validate_encounters(errs)
	_validate_party(errs)
	_validate_items(errs)
	_validate_gear(errs)
	_validate_windows(errs)
	return errs


func _validate_skills(errs: Array[String]) -> void:
	for skill_id: String in skills:
		var skill: Dictionary = skills[skill_id]
		var tag: String = "skill %s" % skill_id
		if not SKILL_TARGETS.has(str(skill.get("target", ""))):
			errs.append("%s: bad target" % tag)
		var timeline: Dictionary = skill["timeline_ms"]
		if int(timeline["end"]) < int(timeline["impact"]) or int(timeline["impact"]) < int(timeline["windup"]):
			errs.append("%s: timeline must run windup <= impact <= end" % tag)
		var presses: Array = skill["presses"]
		for i: int in presses.size():
			var press: Dictionary = presses[i]
			if not PRESS_TYPES.has(str(press.get("type", ""))):
				errs.append("%s: press %d has bad type" % [tag, i])
			if windows_doc.get("windows", {}).has(str(press.get("window", ""))) == false:
				errs.append("%s: press %d has unknown window" % [tag, i])
			if int(press["cue_ms"]) > int(timeline["end"]):
				errs.append("%s: press %d cue is after the action ends" % [tag, i])
			if str(press.get("type", "")) == "hold_release":
				if not press.has("hold_by_ms") or int(press["hold_by_ms"]) >= int(press["cue_ms"]):
					errs.append("%s: hold press %d needs hold_by_ms before its cue" % [tag, i])
		var skill_kind: String = str(skill.get("kind", ""))
		if skill_kind == "skill" and int(skill["juice_cost"]) <= 0:
			errs.append("%s: skills cost Juice" % tag)
		var effects: Array = skill["effects"]
		if effects.is_empty():
			errs.append("%s: no effects" % tag)
		for fx_variant: Variant in effects:
			_validate_effect(errs, tag, fx_variant as Dictionary, presses.size(), int(timeline["end"]), true)
		if skill.has("part_mult") and float(skill["part_mult"]) <= 0.0:
			errs.append("%s: part_mult must be positive" % tag)
		if int(skill.get("cooldown_turns", 0)) < 0:
			errs.append("%s: cooldown_turns can't be negative" % tag)
		if skill.has("telegraph"):
			var telegraph: Dictionary = skill["telegraph"]
			if int(telegraph.get("bangs", 0)) < 1 or int(telegraph.get("bangs", 0)) > 3:
				errs.append("%s: telegraph bangs must be 1 to 3" % tag)
			if float(timeline["windup"]) < data_min_telegraph_windup():
				errs.append("%s: a telegraphed attack needs a longer wind-up (formulas.json boss.min_telegraph_windup_ms)" % tag)


func _validate_effect(errs: Array[String], tag: String, fx: Dictionary, press_count: int, end_ms: int, top_level: bool) -> void:
	var kind: String = str(fx.get("kind", ""))
	if not EFFECT_KINDS.has(kind):
		errs.append("%s: bad effect kind '%s'" % [tag, kind])
		return
	if top_level and int(fx["at_ms"]) > end_ms:
		errs.append("%s: effect happens after the action ends" % tag)
	if fx.has("press") and (int(fx["press"]) < 0 or int(fx["press"]) >= press_count):
		errs.append("%s: effect points at a press that does not exist" % tag)
	if fx.has("target") and not EFFECT_TARGETS.has(str(fx["target"])):
		errs.append("%s: bad effect target '%s'" % [tag, str(fx["target"])])
	if kind == "wheel":
		var tiers: Dictionary = fx.get("tiers", {})
		for rating: String in RATINGS:
			if not tiers.has(rating) or (tiers[rating] as Array).is_empty():
				errs.append("%s: wheel has no results for %s" % [tag, rating])
				continue
			for result_variant: Variant in tiers[rating]:
				var result: Dictionary = result_variant
				for sub_variant: Variant in result.get("effects", []):
					_validate_effect(errs, "%s/%s" % [tag, str(result.get("id", "?"))], sub_variant as Dictionary, 0, end_ms, false)
	_validate_status_refs(errs, tag, fx.get("statuses", []))
	var on_rating: Dictionary = fx.get("on_rating", {})
	for rating: String in on_rating:
		if not RATINGS.has(rating):
			errs.append("%s: on_rating has unknown rating '%s'" % [tag, rating])
		_validate_status_refs(errs, tag, (on_rating[rating] as Dictionary).get("statuses", []))


func _validate_status_refs(errs: Array[String], tag: String, list: Array) -> void:
	for entry_variant: Variant in list:
		var entry: Dictionary = entry_variant
		if not statuses.has(str(entry.get("id", ""))):
			errs.append("%s: unknown status '%s'" % [tag, str(entry.get("id", ""))])
		var chance: float = float(entry.get("chance", 1.0))
		if chance < 0.0 or chance > 1.0:
			errs.append("%s: status chance out of range" % tag)


func _validate_enemies(errs: Array[String]) -> void:
	for enemy_id: String in enemies:
		var enemy: Dictionary = enemies[enemy_id]
		var tag: String = "enemy %s" % enemy_id
		var stats: Dictionary = enemy.get("stats", {})
		for key: String in STAT_KEYS:
			if not stats.has(key):
				errs.append("%s: missing stat %s" % [tag, key])
		if float(stats.get("hp", 0)) <= 0.0:
			errs.append("%s: needs HP" % tag)
		if float(enemy.get("xp", -1)) < 0.0 or float(enemy.get("credits", -1)) < 0.0:
			errs.append("%s: xp and credits must be set" % tag)
		if (enemy.get("ai", []) as Array).is_empty():
			errs.append("%s: no AI actions" % tag)
		for entry_variant: Variant in enemy.get("ai", []):
			var entry: Dictionary = entry_variant
			var skill_id: String = str(entry.get("skill", ""))
			if not skills.has(skill_id):
				errs.append("%s: AI uses unknown skill %s" % [tag, skill_id])
				continue
			var skill: Dictionary = skills[skill_id]
			if str(skill.get("user", "")) != enemy_id:
				errs.append("%s: skill %s belongs to %s" % [tag, skill_id, str(skill.get("user", ""))])
			if (skill["presses"] as Array).is_empty() and not _has_effect_kind(skill, "jam"):
				errs.append("%s: attack %s has no block press" % [tag, skill_id])
			if float(entry.get("weight", 0)) <= 0.0:
				errs.append("%s: AI weight must be positive" % tag)
		for drop_variant: Variant in enemy.get("drops", []):
			var drop: Dictionary = drop_variant
			var item_id: String = str(drop.get("item", ""))
			if not field_item_ids.has(item_id):
				errs.append("%s: drop %s is not in items.json" % [tag, item_id])
			if not battle_items.has(item_id):
				errs.append("%s: drop %s has no battle item entry" % [tag, item_id])
			var chance: float = float(drop.get("chance", 0))
			if chance <= 0.0 or chance > 1.0:
				errs.append("%s: drop chance out of range" % tag)
		for status_id: String in enemy.get("status_resist", {}):
			if not statuses.has(status_id):
				errs.append("%s: resists unknown status %s" % [tag, status_id])
		_validate_boss(errs, enemy_id, enemy)
		if enemy.has("flee_at_hp_pct"):
			var flee: float = float(enemy["flee_at_hp_pct"])
			if flee <= 0.0 or flee >= 100.0:
				errs.append("%s: flee_at_hp_pct out of range" % tag)


func data_min_telegraph_windup() -> float:
	return f("boss", "min_telegraph_windup_ms", 0.0)


func _has_effect_kind(skill: Dictionary, kind: String) -> bool:
	for fx_variant: Variant in skill.get("effects", []):
		if str((fx_variant as Dictionary).get("kind", "")) == kind:
			return true
	return false


## Boss extras: parts, phases, the jam pulse table, lines and telegraphs (see BattleBoss).
func _validate_boss(errs: Array[String], enemy_id: String, enemy: Dictionary) -> void:
	var tag: String = "enemy %s" % enemy_id
	var has_any: bool = enemy.has("parts") or enemy.has("phases") or enemy.has("cue_scramble")
	if not has_any:
		return
	if not BattleBoss.is_multi_part(enemy):
		errs.append("%s: a boss needs parts and at least two phases" % tag)
		return
	var phase_ids: Array[String] = []
	for phase_variant: Variant in enemy["phases"]:
		phase_ids.append(str((phase_variant as Dictionary).get("id", "")))
	for part_variant: Variant in enemy["parts"]:
		var part: Dictionary = part_variant
		if str(part.get("id", "")).is_empty() or int(part.get("hp", 0)) <= 0:
			errs.append("%s: every part needs an id and HP" % tag)
	var rows: Array = (enemy.get("cue_scramble", {}) as Dictionary).get("by_pairs_broken", [])
	if rows.is_empty():
		errs.append("%s: cue_scramble needs by_pairs_broken rows" % tag)
	var last_strength: float = 99999.0
	for row_variant: Variant in rows:
		var row: Dictionary = row_variant
		var offsets: Array = row.get("offset_ms", [])
		if offsets.size() != 2 or float(offsets[0]) <= 0.0 or float(offsets[1]) < float(offsets[0]):
			errs.append("%s: cue_scramble offset_ms needs [min, max]" % tag)
			continue
		var strength: float = float(offsets[1]) * (1.0 + float(row.get("dropout_chance", 0.0)))
		if strength > last_strength:
			errs.append("%s: each broken pair must weaken the pulse, not strengthen it" % tag)
		last_strength = strength
		if float(row.get("dropout_chance", 0.0)) < 0.0 or float(row.get("dropout_chance", 0.0)) > 1.0:
			errs.append("%s: dropout_chance out of range" % tag)
	for entry_variant: Variant in enemy.get("ai", []):
		var cond: Dictionary = (entry_variant as Dictionary).get("if", {})
		if cond.has("phase_is") and not phase_ids.has(str(cond["phase_is"])):
			errs.append("%s: AI names unknown phase %s" % [tag, str(cond["phase_is"])])
	if not boss_lines.has(enemy_id):
		errs.append("%s: no lines in text/boss_lines.json" % tag)
	else:
		for key: String in ["start", "rig_turn", "pulse", "leg_break", "topple", "foot_turn", "defeat"]:
			if not (boss_lines[enemy_id] as Dictionary).has(key):
				errs.append("%s: boss lines missing '%s'" % [tag, key])


func _validate_encounters(errs: Array[String]) -> void:
	for encounter_id: String in encounters:
		var encounter: Dictionary = encounters[encounter_id]
		var tag: String = "encounter %s" % encounter_id
		var list: Array = encounter.get("enemies", [])
		if list.size() < 1 or list.size() > 4:
			errs.append("%s: needs 1 to 4 enemies" % tag)
		for enemy_id: Variant in list:
			if not enemies.has(str(enemy_id)):
				errs.append("%s: unknown enemy %s" % [tag, str(enemy_id)])
		for key: String in ["can_run", "is_boss", "backdrop", "tier"]:
			if not encounter.has(key):
				errs.append("%s: missing %s" % [tag, key])
		if not (feel.get("fight_seconds", {}) as Dictionary).has(str(encounter.get("tier", ""))):
			errs.append("%s: tier has no feel target" % tag)
		for who: Variant in encounter.get("suggested_party", []):
			if not characters.has(str(who)):
				errs.append("%s: suggested_party names unknown fighter %s" % [tag, str(who)])
		for drop_variant: Variant in encounter.get("drops", []):
			var drop: Dictionary = drop_variant
			if not item_data.knows(str(drop.get("item", ""))):
				errs.append("%s: drops unknown item %s" % [tag, str(drop.get("item", ""))])
			if float(drop.get("chance", 1.0)) <= 0.0 or float(drop.get("chance", 1.0)) > 1.0:
				errs.append("%s: drop chance out of range" % tag)
		for key: String in (encounter.get("reward_scale", {}) as Dictionary):
			if not ["xp", "credits"].has(key) or float(encounter["reward_scale"][key]) <= 0.0:
				errs.append("%s: bad reward_scale '%s'" % [tag, key])


func _validate_party(errs: Array[String]) -> void:
	for char_id: String in characters:
		var character: Dictionary = characters[char_id]
		var tag: String = "character %s" % char_id
		if not skills.has(str(character.get("attack_skill", ""))):
			errs.append("%s: unknown attack skill" % tag)
		if not skills.has(str(character.get("signature_skill", ""))):
			errs.append("%s: unknown signature skill" % tag)
		for entry_variant: Variant in character.get("skills_by_level", []):
			var entry: Dictionary = entry_variant
			var skill_id: String = str(entry.get("skill", ""))
			if not skills.has(skill_id):
				errs.append("%s: unknown skill %s" % [tag, skill_id])
			elif int((skills[skill_id] as Dictionary)["learn_level"]) != int(entry.get("level", 0)):
				errs.append("%s: %s learn_level disagrees with characters.json" % [tag, skill_id])
		if not growth.has(char_id):
			errs.append("%s: no growth rows" % tag)
			continue
		var previous: Dictionary = {}
		for level: int in range(1, max_level + 1):
			var row: Dictionary = (growth[char_id] as Dictionary).get(level, {})
			if row.is_empty():
				errs.append("%s: growth missing level %d" % [tag, level])
				continue
			for key: String in STAT_KEYS:
				if int(row[key]) < int(previous.get(key, 0)):
					errs.append("%s: %s goes down at level %d" % [tag, key, level])
				if int(row[key]) <= 0:
					errs.append("%s: %s must be positive at level %d" % [tag, key, level])
			previous = row
	var last_total: int = -1
	for level: int in range(1, max_level + 1):
		var total: int = int(xp_total.get(level, -1))
		if total <= last_total:
			errs.append("xp curve must rise at level %d" % level)
		last_total = total
	if int(xp_total.get(1, -1)) != 0:
		errs.append("xp curve must start at 0 for level 1")


func _validate_items(errs: Array[String]) -> void:
	for item_id: String in battle_items:
		var item: Dictionary = battle_items[item_id]
		var effect: Dictionary = item.get("effect", {})
		if effect.is_empty():
			errs.append("item %s: no effect" % item_id)
		for status_id: Variant in effect.get("cure", []):
			if not statuses.has(str(status_id)):
				errs.append("item %s: cures unknown status" % item_id)
		_validate_status_refs(errs, "item %s" % item_id, effect.get("statuses", []))


func _validate_gear(errs: Array[String]) -> void:
	var status_ids: Array[String] = []
	status_ids.assign(statuses.keys())
	errs.append_array(item_data.validate(status_ids, character_order))


func _validate_windows(errs: Array[String]) -> void:
	for name: String in windows_doc.get("windows", {}):
		var w: Dictionary = windows_doc["windows"][name]
		if not (float(w["totally_rad_ms"]) < float(w["rad_ms"]) and float(w["rad_ms"]) < float(w["nice_ms"])):
			errs.append("window %s: totally_rad < rad < nice must hold" % name)
