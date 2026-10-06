class_name FieldTuning
extends RefCounted
## Typed view of data/world/field_tuning.json for the field systems (camera, prop fader, player).
## Build one with FieldTuning.from_db(DataDB) in the game, or FieldTuning.from_dict(...) in tests.
## A missing key logs an error and reads as 0, so a data typo is loud instead of silently wrong.

const TUNING_ID: String = "world/field_tuning"
const PATH_SEPARATOR: String = "."

var walk_speed: float = 0.0
var run_speed: float = 0.0
var turn_rate_deg_per_s: float = 0.0
## Jump: peak height (units) and time to reach it (s) set the launch speed and rising gravity.
var jump_height: float = 0.0
var jump_rise_time_s: float = 0.0
## Falling gravity is the rising gravity times this (a slightly faster fall feels snappier).
var jump_fall_gravity_mult: float = 0.0
var jump_max_fall_speed: float = 0.0
## Grace after leaving a ledge in which a jump still works, and how long an early press is remembered.
var jump_coyote_time_s: float = 0.0
var jump_buffer_time_s: float = 0.0
## Letting go of jump while rising caps the upward speed at launch speed times this.
var jump_release_cut_mult: float = 0.0
## How fast (units/s squared) Red's flat velocity changes toward the stick while in the air.
var jump_air_accel: float = 0.0
## Seconds off the ground before the fall pose shows (so small steps do not flicker it).
var jump_air_anim_delay_s: float = 0.0
var camera_smoothing: float = 0.0
var camera_safe_frame_margin: float = 0.0
var fade_occluder_radius: float = 0.0
var fade_out_per_s: float = 0.0
var fade_in_per_s: float = 0.0
var fade_max_amount: float = 0.0


## `db` is the DataDB autoload (or any node with get_dict()).
static func from_db(db: Node) -> FieldTuning:
	if db == null:
		push_error("FieldTuning: no DataDB available")
		return FieldTuning.new()
	var data: Dictionary = db.call("get_dict", TUNING_ID)
	return from_dict(data)


static func from_dict(data: Dictionary) -> FieldTuning:
	var t: FieldTuning = FieldTuning.new()
	t.walk_speed = _number(data, "walk_speed")
	t.run_speed = _number(data, "run_speed")
	t.turn_rate_deg_per_s = _number(data, "turn_rate_deg_per_s")
	t.jump_height = _number(data, "jump.height")
	t.jump_rise_time_s = _number(data, "jump.rise_time_s")
	t.jump_fall_gravity_mult = _number(data, "jump.fall_gravity_mult")
	t.jump_max_fall_speed = _number(data, "jump.max_fall_speed")
	t.jump_coyote_time_s = _number(data, "jump.coyote_time_s")
	t.jump_buffer_time_s = _number(data, "jump.buffer_time_s")
	t.jump_release_cut_mult = _number(data, "jump.release_cut_mult")
	t.jump_air_accel = _number(data, "jump.air_accel")
	t.jump_air_anim_delay_s = _number(data, "jump.air_anim_delay_s")
	t.camera_smoothing = _number(data, "camera.smoothing")
	t.camera_safe_frame_margin = _number(data, "camera.safe_frame_margin")
	t.fade_occluder_radius = _number(data, "prop_fade.occluder_radius")
	t.fade_out_per_s = _number(data, "prop_fade.fade_out_per_s")
	t.fade_in_per_s = _number(data, "prop_fade.fade_in_per_s")
	t.fade_max_amount = _number(data, "prop_fade.max_fade")
	return t


static func _number(data: Dictionary, path: String) -> float:
	var node: Variant = data
	for part: String in path.split(PATH_SEPARATOR):
		if node is Dictionary and (node as Dictionary).has(part):
			node = (node as Dictionary)[part]
		else:
			push_error("FieldTuning: %s is missing '%s'" % [TUNING_ID, path])
			return 0.0
	if node is float or node is int:
		return float(node)
	push_error("FieldTuning: %s '%s' is not a number" % [TUNING_ID, path])
	return 0.0
