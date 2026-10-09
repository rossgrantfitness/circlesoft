class_name HeroLink
extends RefCounted
## The hero contract (docs/slice/slice_tech_plan.md 2.6). About twenty town and Works scripts (doors, pickups,
## NPCs, the job board, cage lifts, card gates, the dialogue runner, the shop and field menus) used to be written
## against the old `PlayerController`. They now take any `CharacterBody3D` and reach the hero only through the
## calls below, so both the old field Red (PlayerController) and the new action Red (ActionPlayer) work in them.
##
## What a hero must have is listed in METHODS and PROPERTIES; tests/integration/test_hero_contract.gd fails if
## either hero is missing one, so the two can't drift apart.
##
## Every call here is safe on a null or freed hero (it does nothing, or answers the "nobody there" value).

## Methods every hero implements.
const METHODS: PackedStringArray = [
	"set_scripted", "play_clip", "get_facing", "get_move_direction", "set_camera", "reset_ground_height",
	"block_jump_for_frames", "start_blink", "is_catchable", "has_animation", "is_on_floor",
]
## Properties every hero has.
const PROPERTIES: PackedStringArray = ["frozen", "scripted", "stick", "read_engine_input"]


## The names from METHODS and PROPERTIES that `hero` lacks (empty = a complete hero).
static func missing_members(hero: Variant) -> PackedStringArray:
	var out: PackedStringArray = []
	if hero == null:
		out.append_array(METHODS)
		out.append_array(PROPERTIES)
		return out
	for method_name: String in METHODS:
		if not hero.has_method(method_name):
			out.append(method_name)
	var names: Dictionary = {}
	for info: Dictionary in hero.get_property_list():
		names[str(info["name"])] = true
	for property_name: String in PROPERTIES:
		if not names.has(property_name):
			out.append(property_name)
	return out


static func is_hero(hero: Variant) -> bool:
	return hero != null and is_instance_valid(hero) and missing_members(hero).is_empty()


# ---- properties ----

## Frozen (dialogue, shops, menus): no walking, no attacking, idle pose.
static func is_frozen(hero: Variant) -> bool:
	return _ok(hero) and bool(hero.get("frozen"))


static func set_frozen(hero: Variant, on: bool) -> void:
	if _ok(hero):
		hero.set("frozen", on)


## A climb, hop or cutscene is moving her directly.
static func is_scripted(hero: Variant) -> bool:
	return _ok(hero) and bool(hero.get("scripted"))


## The stick (x right, y down).
static func get_stick(hero: Variant) -> Vector2:
	return hero.get("stick") as Vector2 if _ok(hero) else Vector2.ZERO


static func set_stick(hero: Variant, stick: Vector2) -> void:
	if _ok(hero):
		hero.set("stick", stick)


## True when the hero reads the keyboard and pad itself (false in bot and cutscene runs).
static func reads_engine_input(hero: Variant) -> bool:
	return _ok(hero) and bool(hero.get("read_engine_input"))


# ---- methods ----

static func set_scripted(hero: Variant, on: bool, clip: StringName = &"") -> void:
	if _ok(hero):
		hero.call("set_scripted", on, clip)


static func play_clip(hero: Variant, clip: StringName) -> void:
	if _ok(hero):
		hero.call("play_clip", clip)


static func get_facing(hero: Variant) -> Vector3:
	return hero.call("get_facing") as Vector3 if _ok(hero) else Vector3.BACK


static func get_move_direction(hero: Variant) -> Vector3:
	return hero.call("get_move_direction") as Vector3 if _ok(hero) else Vector3.ZERO


static func set_camera(hero: Variant, cam: Camera3D) -> void:
	if _ok(hero):
		hero.call("set_camera", cam)


static func reset_ground_height(hero: Variant) -> void:
	if _ok(hero):
		hero.call("reset_ground_height")


static func block_jump_for_frames(hero: Variant, frames: int) -> void:
	if _ok(hero):
		hero.call("block_jump_for_frames", frames)


static func start_blink(hero: Variant, seconds: float = -1.0) -> void:
	if _ok(hero):
		hero.call("start_blink", seconds)


## True when an enemy touching her can start a fight: not blinking and not being moved by a script.
static func is_catchable(hero: Variant) -> bool:
	return _ok(hero) and bool(hero.call("is_catchable"))


static func has_animation(hero: Variant, clip: StringName) -> bool:
	return _ok(hero) and bool(hero.call("has_animation", clip))


static func is_on_floor(hero: Variant) -> bool:
	return _ok(hero) and bool(hero.call("is_on_floor"))


static func _ok(hero: Variant) -> bool:
	return hero != null and is_instance_valid(hero)
