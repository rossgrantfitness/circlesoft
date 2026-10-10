class_name LocomotionSpeed
extends RefCounted
## Foot-slide fix for looping locomotion clips (walk, run, jog, flee, strafe, ...). The free Quaternius clips stride at a fixed
## ground speed (the clip's `stride_mps`, measured from the foot travel per loop cycle by scripts/tools/retarget_ual.py and stored
## per clip in data/combat/*_clip_keys.json). To keep the planted foot still on the floor, play the clip at
## ground speed / stride_mps. Attack, dodge and hurt clips are not locomotion and never go through this.
##
## For an enemy (action_enemy.gd): when it starts or updates a locomotion clip, set the animation player's speed_scale to
##   LocomotionSpeed.playback_scale(Vector2(velocity.x, velocity.z).length(), LocomotionSpeed.stride_for(strides, clip))
## where `strides = LocomotionSpeed.load_strides("res://data/combat/wolf_clip_keys.json")` (load once, keep it). It returns 1.0 for a
## clip with no stride, so non-locomotion clips are safe to pass through.

const DEFAULT_MIN: float = 0.6
const DEFAULT_MAX: float = 2.0


## The playback scale that makes a clip of natural ground speed `stride_mps` look planted at `ground_speed` (m/s), kept inside
## `limits` (x = lowest scale, y = highest). 1.0 when the stride is unknown (zero or less); the lowest scale when standing still.
static func playback_scale(ground_speed: float, stride_mps: float, limits: Vector2 = Vector2(DEFAULT_MIN, DEFAULT_MAX)) -> float:
	if stride_mps <= 0.0:
		return 1.0
	return clampf(maxf(ground_speed, 0.0) / stride_mps, limits.x, limits.y)


## The same ratio before the clamp (what the scale would be if the feet were to stay planted).
static func raw_scale(ground_speed: float, stride_mps: float) -> float:
	if stride_mps <= 0.0:
		return 1.0
	return maxf(ground_speed, 0.0) / stride_mps


## How far past the top of the range the wanted scale is, from 0 (inside the range) up to 1 (twice the top or more). A caller with a
## faster clip (a sprint) blends toward it by this much; with none, the clamp stands and the feet slide a little.
static func overspeed_blend(ground_speed: float, stride_mps: float, limits: Vector2 = Vector2(DEFAULT_MIN, DEFAULT_MAX)) -> float:
	if stride_mps <= 0.0 or limits.y <= 0.0:
		return 0.0
	return clampf(raw_scale(ground_speed, stride_mps) / limits.y - 1.0, 0.0, 1.0)


## {clip name: stride_mps} for every clip in a *_clip_keys.json that has one (the file is cached by CombatData).
static func load_strides(path: String) -> Dictionary:
	var out: Dictionary = {}
	var clips: Dictionary = CombatData.read_json(path).get("clips", {}) as Dictionary
	for clip: Variant in clips:
		var entry: Dictionary = clips[clip] as Dictionary
		if entry.has("stride_mps"):
			out[StringName(str(clip))] = float(entry["stride_mps"])
	return out


## One clip's stride from load_strides(), 0.0 if it has none (so playback_scale gives 1.0).
static func stride_for(strides: Dictionary, clip: StringName) -> float:
	return float(strides.get(clip, 0.0))
