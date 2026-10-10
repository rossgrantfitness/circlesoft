class_name EnemyRules
extends RefCounted
## Small pure helpers for the enemy AI (docs/pivot/enemy_ai_design.md). Angles, the guard arc, the
## wind-up floors and "what kind of move is Red's swing". Numbers come from enemies.json
## (`telegraph_rules`, `player_read`, each enemy's `behaviour`), never from here.

const CLASS_LIGHT: StringName = &"light"
const CLASS_HEAVY: StringName = &"heavy"
const CLASS_LAUNCHER: StringName = &"launcher"
const CLASS_AIR: StringName = &"air"
const CLASS_NONE: StringName = &""


## Where an enemy stands round Red, in degrees: 0 = straight in front of her, +-180 = right behind her.
## A positive `move_dir.x` from the brain (sideways round the player) always RAISES this angle.
static func relative_angle_deg(red_pos: Vector3, red_forward: Vector3, enemy_pos: Vector3) -> float:
	var offset: Vector3 = enemy_pos - red_pos
	offset.y = 0.0
	if offset.length() < 0.0001:
		return 0.0
	var fwd: Vector3 = Vector3(red_forward.x, 0.0, red_forward.z)
	if fwd.length() < 0.0001:
		fwd = Vector3.BACK
	var around: float = atan2(offset.x, offset.z) - atan2(fwd.x, fwd.z)
	return wrapf(rad_to_deg(around), -180.0, 180.0)


## True when `angle_deg` (from relative_angle_deg) is inside the arc of `arc_deg` centred right behind Red.
static func in_rear_arc(angle_deg: float, arc_deg: float) -> bool:
	return absf(angle_deg) >= 180.0 - arc_deg * 0.5


## Is `attacker_pos` inside the front `arc_deg` of something standing at `target_pos` facing `target_forward`?
static func in_front_arc(target_pos: Vector3, target_forward: Vector3, attacker_pos: Vector3, arc_deg: float) -> bool:
	var to_attacker: Vector3 = attacker_pos - target_pos
	to_attacker.y = 0.0
	var fwd: Vector3 = Vector3(target_forward.x, 0.0, target_forward.z)
	if to_attacker.length() < 0.0001 or fwd.length() < 0.0001:
		return true
	var angle: float = rad_to_deg(fwd.normalized().angle_to(to_attacker.normalized()))
	return angle <= arc_deg * 0.5


## The shortest wind-up allowed from telegraph to impact: 500 ms, or 650 ms from behind Red.
static func min_windup_ms(rules: Dictionary, rear: bool) -> float:
	if rear:
		return float(rules.get("rear_min_windup_ms", 650.0))
	return float(rules.get("min_windup_ms", 500.0))


## The time scale to run a move's wind-up at: the feel knob, but never so small that the wind-up drops under the floor.
static func windup_scale(knob_scale: float, windup_ms: float, floor_ms: float) -> float:
	if windup_ms <= 0.0:
		return maxf(knob_scale, 1.0)
	return maxf(knob_scale, floor_ms / windup_ms)


## A move's wind-up: telegraph to impact, in ms (the telegraph defaults to the start of the move).
static func windup_ms(move: Dictionary) -> float:
	var tele: float = float(move.get("telegraph_ms", 0.0))
	return float(move.get("impact_ms", move.get("startup_ms", 0.0))) - maxf(tele, 0.0)


## Does an attack meet the telegraph rules? (enemy_ai_design 4.6.)
static func windup_ok(move: Dictionary, rules: Dictionary, rear: bool) -> bool:
	return windup_ms(move) >= min_windup_ms(rules, rear) - 0.001


## When the aim locks, in ms into the move, given the data's `track_ms`: never closer than
## `min_aim_lock_before_impact_ms` to the impact.
static func aim_lock_ms(track_ms: float, impact_ms: float, rules: Dictionary) -> float:
	var latest: float = impact_ms - float(rules.get("min_aim_lock_before_impact_ms", 150.0))
	return maxf(minf(track_ms, latest), 0.0)


## Red's move as a class the enemies read: light, heavy, launcher, air (or "" for a parry and the like).
## `table` is enemies.json player_read.move_class (move id -> class); without an entry the class is worked out
## from the move itself.
static func move_class(move_id: StringName, move: Dictionary, table: Dictionary) -> StringName:
	if table.has(String(move_id)):
		return StringName(str(table[String(move_id)]))
	if (move.get("hitboxes", []) as Array).is_empty():
		return CLASS_NONE
	if str(move.get("state", "ground")) == "air":
		return CLASS_AIR
	if bool(move.get("launcher", false)) or String(move_id).begins_with("launch"):
		return CLASS_LAUNCHER
	if String(move_id).begins_with("heavy"):
		return CLASS_HEAVY
	return CLASS_LIGHT


## A random number in [range[0], range[1]] (a one-number array is that number).
static func pick_range(rng: RandomNumberGenerator, range_ms: Variant, fallback: Array) -> float:
	var values: Array = range_ms if range_ms is Array else fallback
	if values.size() < 2:
		return float(values[0]) if values.size() == 1 else float(fallback[0])
	return rng.randf_range(float(values[0]), float(values[1]))
