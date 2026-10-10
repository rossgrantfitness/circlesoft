class_name ScaleProfile
extends RefCounted
## One body size's numbers (task CS-21, data/combat/scale_profiles.json): Red, the 3.5 m loader robot or the 50 m colossus.
## The same ActionPlayer drives all three; a profile only says how the controller, the camera, the world's haze and the sound
## should be set for that size. Nothing here touches a node, so the tests can check every number and every pure rule.
##
## A missing key means "leave Red's own number alone" (the feel panel's), so the red form is nearly empty.

const DATA_ID: String = "combat/scale_profiles"
const FORM_RED: StringName = &"red"
const FORM_SMALL: StringName = &"small"
const FORM_HUGE: StringName = &"huge"
## Test hook: replaces the shipped file.
static var doc_override: Dictionary = {}

var id: StringName = &""
var data: Dictionary = {}


# ---- loading ----

static func doc() -> Dictionary:
	if not doc_override.is_empty():
		return doc_override
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var db: Node = tree.root.get_node_or_null("DataDB") if tree != null else null
	return (db.call("get_dict", DATA_ID) as Dictionary) if db != null else {}


static func form_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for key: Variant in (doc().get("forms", {}) as Dictionary).keys():
		out.append(StringName(str(key)))
	return out


## The profile for a form id, or null if the data has no such form.
static func get_form(form_id: StringName) -> ScaleProfile:
	var forms: Dictionary = doc().get("forms", {}) as Dictionary
	if not forms.has(String(form_id)):
		return null
	var profile: ScaleProfile = ScaleProfile.new()
	profile.id = form_id
	profile.data = forms[String(form_id)] as Dictionary
	return profile


static func start_form() -> StringName:
	return StringName(str(doc().get("start_form", "red")))


static func sequence(kind: StringName) -> Dictionary:
	return (doc().get("sequences", {}) as Dictionary).get(String(kind), {}) as Dictionary


## A number from the sequences block that is not inside one sequence.
static func sequence_value(key: String, fallback: float) -> float:
	return float((doc().get("sequences", {}) as Dictionary).get(key, fallback))


static func boarding() -> Dictionary:
	return doc().get("boarding", {}) as Dictionary


static func steps() -> Dictionary:
	return doc().get("steps", {}) as Dictionary


static func sounds() -> Dictionary:
	return doc().get("audio", {}) as Dictionary


# ---- reading a form ----

func f(key: String, fallback: float) -> float:
	return float(data.get(key, fallback))


func block(key: String) -> Dictionary:
	return data.get(key, {}) as Dictionary


func s(key: String, fallback: String = "") -> String:
	return str(data.get(key, fallback))


func b(key: String, fallback: bool = false) -> bool:
	return bool(data.get(key, fallback))


func label() -> String:
	return s("label", String(id))


func height_m() -> float:
	return f("height_m", 1.0)


## The model file the form wears ("" = Red's own).
func model_path() -> String:
	return s("model", "")


func is_armored() -> bool:
	return b("armored", false)


func ignores_bodies() -> bool:
	return b("ignore_bodies", false)


func stomp_radius_m() -> float:
	return f("stomp_radius_m", 0.0)


## Numbers that replace feel knobs of the same name ("run_speed_mps", "jump_height_m" ...). Empty for Red.
func knob_overrides() -> Dictionary:
	return block("knobs")


func has_knob(knob_id: String) -> bool:
	return knob_overrides().has(knob_id)


func knob(knob_id: String, fallback: float) -> float:
	return float(knob_overrides().get(knob_id, fallback))


func attack_value(key: String, fallback: float) -> float:
	return float(block("attack").get(key, fallback))


## Hit shapes, lunges and magnets scale by these (1.0 for Red).
func hitbox_scale() -> float:
	return attack_value("hitbox_scale", 1.0)


## How much the swing's height off the floor grows (the shapes grow by hitbox_scale). Defaults to the same.
func hitbox_lift_scale() -> float:
	return attack_value("hitbox_lift_scale", hitbox_scale())


## How much the swing's distance in front of the body grows. Defaults to the same.
func hitbox_reach_scale() -> float:
	return attack_value("hitbox_reach_scale", hitbox_scale())


func attack_time_scale() -> float:
	return clampf(attack_value("time_scale", 1.0), 0.05, 4.0)


func idle_speed() -> float:
	return f("idle_speed", 1.0)


func enter_blend_s() -> float:
	return f("enter_blend_s", 1.2)


func lock_range_mult() -> float:
	return f("lock_range_mult", 1.0)


func world() -> Dictionary:
	return block("world")


func audio() -> Dictionary:
	return block("audio")


func sound_pitch() -> float:
	return float(audio().get("pitch", 1.0))


## The fx.json scale set ("small", "huge") this form's steps and slams use, or "" for none.
func fx_set() -> String:
	return s("fx_set", "")


## `base` (Red's player_action.json) with this form's blocks laid over it: body, move, jump, anim, and hp_max.
## Returns a fresh dictionary; `base` is not changed.
func merged_player_data(base: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	for key: String in ["body", "move", "jump", "anim", "dash"]:
		var over: Dictionary = block(key)
		if over.is_empty():
			continue
		var mine: Dictionary = (out.get(key, {}) as Dictionary).duplicate(true)
		for k: Variant in over.keys():
			mine[k] = over[k]
		out[key] = mine
	var attack_block: Dictionary = (out.get("attack", {}) as Dictionary).duplicate(true)
	if block("attack").has("stop_short_m"):
		attack_block["stop_short_m"] = block("attack")["stop_short_m"]
		out["attack"] = attack_block
	if data.has("hp_max"):
		out["hp_max"] = int(data["hp_max"])
	return out


## What the OrbitCamera is told (distances relative to Red's, so the feel panel's camera distance still counts):
## {distance_mult, pivot_mult, fov_mult, min_distance_m, pitch_offset_deg, yaw_offset_deg, near_m, far_m, shake_mult, shake_cap_m}.
static func camera_view(camera: Dictionary, red_camera: Dictionary) -> Dictionary:
	var red_distance: float = maxf(float(red_camera.get("distance_m", 4.5)), 0.01)
	var red_pivot: float = maxf(float(red_camera.get("pivot_height_m", 0.8)), 0.01)
	var red_fov: float = maxf(float(red_camera.get("fov_deg", 62.0)), 1.0)
	return {
		"distance_mult": float(camera.get("distance_m", red_distance)) / red_distance,
		"pivot_mult": float(camera.get("pivot_height_m", red_pivot)) / red_pivot,
		"fov_mult": float(camera.get("fov_deg", red_fov)) / red_fov,
		"min_distance_m": float(camera.get("min_distance_m", 0.8)),
		"pitch_offset_deg": float(camera.get("pitch_offset_deg", 0.0)),
		"yaw_offset_deg": float(camera.get("yaw_offset_deg", 0.0)),
		"near_m": float(camera.get("near_m", 0.1)),
		"far_m": float(camera.get("far_m", 400.0)),
		"shake_mult": float(camera.get("shake_mult", 1.0)),
		"shake_cap_m": float(camera.get("shake_cap_m", 0.25)),
	}


## The camera block of a form or of a named view (data "views"); empty if neither exists.
static func camera_block(view_id: StringName) -> Dictionary:
	var form: ScaleProfile = get_form(view_id)
	if form != null:
		return form.block("camera")
	return (doc().get("views", {}) as Dictionary).get(String(view_id), {}) as Dictionary


# ---- pure rules ----

## Smooth in-out 0..1.
static func smooth(t: float) -> float:
	var k: float = clampf(t, 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)


static func ease_out(t: float) -> float:
	var k: float = clampf(t, 0.0, 1.0)
	return 1.0 - (1.0 - k) * (1.0 - k)


## Every number of two views (or two world looks) blended: `t` 0 = a, 1 = b. Keys only in one side keep that side's value.
static func blend(a: Dictionary, bb: Dictionary, t: float) -> Dictionary:
	var out: Dictionary = {}
	var keys: Dictionary = {}
	for k: Variant in a.keys():
		keys[k] = true
	for k: Variant in bb.keys():
		keys[k] = true
	for k: Variant in keys.keys():
		var from_v: float = float(a.get(k, bb.get(k, 0.0)))
		var to_v: float = float(bb.get(k, a.get(k, 0.0)))
		out[k] = lerpf(from_v, to_v, clampf(t, 0.0, 1.0))
	return out


## One hit shape (a hitbox slice of moves.json) scaled up with the body: size, radius and height by `k`; the offset from the feet
## by `lift` (its height) and `reach` (forward and sideways), each -1 = the same as `k`. A robot's sword has to sweep the floor
## where the wolves and props are and start at its own feet, so the robots lift and reach by less than they grow.
static func scale_box(box: Dictionary, k: float, lift: float = -1.0, reach: float = -1.0) -> Dictionary:
	var up: float = k if lift < 0.0 else lift
	var out_k: float = k if reach < 0.0 else reach
	if is_equal_approx(k, 1.0) and is_equal_approx(up, 1.0) and is_equal_approx(out_k, 1.0):
		return box
	var out: Dictionary = box.duplicate(true)
	for key: String in ["radius", "height"]:
		if out.has(key):
			out[key] = float(out[key]) * k
	if out.has("size") and out["size"] is Array:
		var scaled_size: Array = []
		for value: Variant in out["size"] as Array:
			scaled_size.append(float(value) * k)
		out["size"] = scaled_size
	if out.has("offset") and out["offset"] is Array:
		var offset: Array = out["offset"] as Array
		var scaled_offset: Array = []
		for i: int in offset.size():
			scaled_offset.append(float(offset[i]) * (up if i == 1 else out_k))
		out["offset"] = scaled_offset
	return out


## A move's hit numbers for this body: damage, knockback and hit-stop scaled (at least 1 damage if it had any).
func scale_attack(attack: Dictionary) -> Dictionary:
	var damage_mult: float = attack_value("damage_mult", 1.0)
	var knock_mult: float = attack_value("knockback_mult", 1.0)
	var stop_mult: float = attack_value("hit_stop_mult", 1.0)
	if is_equal_approx(damage_mult, 1.0) and is_equal_approx(knock_mult, 1.0) and is_equal_approx(stop_mult, 1.0):
		return attack
	var out: Dictionary = attack.duplicate(true)
	var damage: float = float(out.get("damage", 0.0))
	if damage > 0.0:
		out["damage"] = maxi(int(roundf(damage * damage_mult)), 1)
	if out.has("knockback_m"):
		out["knockback_m"] = float(out["knockback_m"]) * knock_mult
	if out.has("hit_stop_ms"):
		out["hit_stop_ms"] = float(out["hit_stop_ms"]) * stop_mult
	return out
