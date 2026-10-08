class_name ActionMotion
extends RefCounted
## Pure movement maths for Red's action controller (the parts of ActionPlayer that don't need nodes):
## ground and air acceleration, the jump numbers from a height, the fall, and the dash set-up.
## PlayerMotion (camera-relative direction, yaw, turning) is kept and used as is; this adds what the
## action game needs on top. All numbers come in through `p`, the "move" / "jump" / "dash" blocks of
## data/combat/player_action.json, and the knob values.

const MIN_LENGTH: float = 0.0001


## Flat velocity after one step toward `wanted` (a flat velocity, m/s). On the ground it is snappy
## (`ground_accel` speeding up, `ground_decel` slowing to a stop); in the air only `air_accel` pulls it.
static func flat_velocity(current: Vector2, wanted: Vector2, on_ground: bool, move: Dictionary, delta: float) -> Vector2:
	if on_ground:
		var rate: float = float(move.get("ground_accel_mps2", 90.0)) if wanted.length() > MIN_LENGTH \
				else float(move.get("ground_decel_mps2", 70.0))
		return current.move_toward(wanted, rate * delta)
	return current.move_toward(wanted, float(move.get("air_accel_mps2", 30.0)) * delta)


## Gravity (m/s^2, positive) for a jump that rises `height_m` in `rise_time_s`, times the gravity knob.
static func gravity_for(height_m: float, rise_time_s: float, gravity_scale: float) -> float:
	return PlayerMotion.jump_gravity(height_m, rise_time_s) * maxf(gravity_scale, 0.01)


## Launch speed that reaches exactly `height_m` under `gravity`.
static func launch_speed(height_m: float, gravity: float) -> float:
	return sqrt(2.0 * maxf(gravity, MIN_LENGTH) * maxf(height_m, 0.0))


## One step of vertical motion. Returns {"vy": speed after, "avg": average speed over the step}. The
## average is what to move by, so the jump reaches the data height at any frame rate. Falling is
## heavier by `fall_mult`; letting go of jump while rising cuts the speed to `cut_speed`.
static func vertical_step(vy: float, gravity: float, fall_mult: float, max_fall: float, delta: float,
		jump_held: bool, cut_speed: float) -> Dictionary:
	var g: float = gravity if vy > 0.0 else gravity * fall_mult
	var after: float = maxf(vy - g * delta, -max_fall)
	if not jump_held and after > cut_speed:
		after = cut_speed
	return {"vy": after, "avg": (vy + after) * 0.5}


## The direction a dash goes: the stick if it is held, else (by `no_stick`) her facing or backwards.
static func dash_direction(stick_dir: Vector3, facing: Vector3, no_stick: String) -> Vector3:
	if stick_dir.length() > MIN_LENGTH:
		return stick_dir.normalized()
	var flat: Vector3 = Vector3(facing.x, 0.0, facing.z)
	flat = flat.normalized() if flat.length() > MIN_LENGTH else Vector3.FORWARD
	return -flat if no_stick == "back" else flat


## Milliseconds left on a cooldown after `elapsed_ms`, never below zero.
static func cooldown_left_ms(cooldown_ms: float, elapsed_ms: float) -> float:
	return maxf(cooldown_ms - elapsed_ms, 0.0)
