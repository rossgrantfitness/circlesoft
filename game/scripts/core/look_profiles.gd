class_name LookProfiles
extends RefCounted
## The switchable "look profile": one named bundle of grading, lighting, fog, grime and character
## treatment, all read from data/world/look_profiles.json. "classic" is the bright toy-box look Ross
## approved first; "grim" is the greasy, desaturated, oppressive look he asked for on 2026-10-08.
##
## What a profile controls (see the data file for every number):
##   grade      the world grade in the PSX post shader (desaturate, crush blacks, sodium/teal tint, grain)
##   post       color levels and dither size of the final picture
##   lighting   ambient and light energy multipliers for a room (PsxRoomLook applies them)
##   fog        a dirtier fog color and distances
##   materials  how much the room's own material tints are drained and darkened (GrimDressing)
##   dressing   whether the grime props and painted grime show (GrimDressing)
##   characters the dull, scuffed, matte treatment for character textures (dress_model)
##   models     classic model path -> variant path (Red's taller, leaner grim shiba)
##   backdrop   color overrides for the battle set (BattleBackdrop)
##
## Which profile is active: a scene asks for its own (enter_scene), using "scene_defaults" in the data,
## unless the debug overlay forced one (F11: auto, classic, grim). Nodes that dress themselves join the
## group "look_aware" and answer apply_look(profile_id: String, profile: Dictionary).

const DATA_ID: String = "world/look_profiles"
const GROUP_AWARE: StringName = &"look_aware"
const GROUP_SCREEN: StringName = &"psx_screen"
const CLASSIC: String = "classic"
const AUTO: String = ""
const SCREEN_PARAMS: Dictionary[String, String] = {
	"desat": "grade_desat", "accent_keep": "grade_accent_keep", "gain": "grade_gain", "gamma": "grade_gamma",
	"crush": "grade_crush", "tint_amount": "grade_tint_amount", "grain": "grade_grain",
	"grain_fps": "grade_grain_fps", "vignette": "grade_vignette",
}
const SCREEN_COLOR_PARAMS: Dictionary[String, String] = {
	"shadow_tint": "grade_shadow_tint", "highlight_tint": "grade_highlight_tint",
}
const LUMA: Vector3 = Vector3(0.299, 0.587, 0.114)

## Test hook: when non-empty it replaces the data file.
static var _test_data: Dictionary = {}
static var _active: String = ""
static var _forced: String = AUTO
static var _scene_key: String = ""


# ---- reading the data ----

static func data() -> Dictionary:
	if not _test_data.is_empty():
		return _test_data
	var db: Node = _db()
	return db.call("get_dict", DATA_ID) if db != null else {}


static func use_data_for_tests(source: Dictionary) -> void:
	_test_data = source


## Back to the shipped data, nothing forced, nothing active (tests call this after themselves).
static func reset() -> void:
	_test_data = {}
	_active = ""
	_forced = AUTO
	_scene_key = ""


static func profile_ids() -> Array[String]:
	var ids: Array[String] = []
	var profiles: Dictionary = _dict(data().get("profiles", {}))
	for id: Variant in profiles:
		ids.append(str(id))
	return ids


static func has_profile(id: String) -> bool:
	return _dict(data().get("profiles", {})).has(id)


## One profile's settings. An unknown id reads as "classic" (a data typo is never a crash).
static func profile(id: String) -> Dictionary:
	var profiles: Dictionary = _dict(data().get("profiles", {}))
	if profiles.has(id):
		return _dict(profiles[id])
	return _dict(profiles.get(CLASSIC, {}))


static func default_id() -> String:
	var wanted: String = str(data().get("default", CLASSIC))
	return wanted if has_profile(wanted) else CLASSIC


## Which profile a scene key (a room id, or "battle") gets on its own. Unknown keys get the default.
static func scene_default(scene_key: String) -> String:
	var wanted: String = str(_dict(data().get("scene_defaults", {})).get(scene_key, ""))
	return wanted if has_profile(wanted) else default_id()


static func name_of(id: String) -> String:
	return str(profile(id).get("name", id))


## Dotted lookup inside a profile ("grade.desat"). Returns fallback when anything is missing.
static func value(id: String, path: String, fallback: Variant = null) -> Variant:
	var node: Variant = profile(id)
	for part: String in path.split(".", false):
		if node is Dictionary and (node as Dictionary).has(part):
			node = (node as Dictionary)[part]
		else:
			return fallback
	return node


static func number(id: String, path: String, fallback: float) -> float:
	var found: Variant = value(id, path, null)
	return float(found) if (found is float or found is int) else fallback


static func flag(id: String, path: String, fallback: bool) -> bool:
	var found: Variant = value(id, path, null)
	return bool(found) if found is bool else fallback


# ---- which profile is on ----

## The profile that is on right now ("" before any scene asked for one: that reads as the default).
static func active_id() -> String:
	return _active if not _active.is_empty() else default_id()


static func active() -> Dictionary:
	return profile(active_id())


static func is_grim() -> bool:
	return active_id() == "grim"


## "" (auto: each scene uses its own default) or the profile the overlay forced on every scene.
static func forced_id() -> String:
	return _forced


static func scene_key() -> String:
	return _scene_key


## A scene (room or battle) is starting: picks its profile (the forced one, else the scene's default),
## applies it, and returns the id. Rooms call this from PsxRoomLook, the battle from its backdrop.
static func enter_scene(key: String) -> String:
	_scene_key = key
	var id: String = _forced if (not _forced.is_empty() and has_profile(_forced)) else scene_default(key)
	apply(id)
	return id


## The overlay's switch: auto -> classic -> grim -> auto. Returns what is forced now ("" = auto).
static func cycle_forced() -> String:
	var order: Array[String] = [AUTO]
	for id: String in profile_ids():
		order.append(id)
	var at: int = order.find(_forced)
	_forced = order[(at + 1) % order.size()]
	apply(_forced if not _forced.is_empty() else scene_default(_scene_key))
	return _forced


static func set_forced(id: String) -> void:
	_forced = id if (id.is_empty() or has_profile(id)) else AUTO
	apply(_forced if not _forced.is_empty() else scene_default(_scene_key))


## Turns a profile on right now: the screen grade, then every look-aware node.
static func apply(id: String) -> void:
	_active = id if has_profile(id) else default_id()
	var tree: SceneTree = _tree()
	if tree == null:
		return
	for screen: Node in tree.get_nodes_in_group(GROUP_SCREEN):
		var display: Control = screen.call("get_display") as Control
		if display != null:
			apply_grade(display.material as ShaderMaterial, _active)
	for node: Node in tree.get_nodes_in_group(GROUP_AWARE):
		if node.has_method("apply_look"):
			node.call("apply_look", _active, profile(_active))


## Writes a profile's grade into the PSX post material (also used by PsxScreen when it starts).
static func apply_grade(material: ShaderMaterial, id: String) -> void:
	if material == null:
		return
	var all: Dictionary = grade_parameters(id)
	for param: String in all:
		material.set_shader_parameter(param, all[param])


## The post shader parameters (name -> value) for a profile. Classic gives amount 0 plus defaults.
static func grade_parameters(id: String) -> Dictionary:
	var grade: Dictionary = _dict(profile(id).get("grade", {}))
	var out: Dictionary = {}
	out["grade_amount"] = float(grade.get("amount", 0.0))
	for key: String in SCREEN_PARAMS:
		out[SCREEN_PARAMS[key]] = float(grade.get(key, _identity(key)))
	for key: String in SCREEN_COLOR_PARAMS:
		var channels: Variant = grade.get(key, [1.0, 1.0, 1.0])
		out[SCREEN_COLOR_PARAMS[key]] = _vec3(channels)
	var post: Dictionary = _dict(profile(id).get("post", {}))
	out["color_levels"] = float(post.get("color_levels", 32.0))
	out["dither_amount"] = float(post.get("dither_amount", 1.0))
	return out


# ---- colors ----

## A material or light color drained and darkened by the profile's "materials" block.
static func grade_color(color: Color, id: String) -> Color:
	var saturation: float = number(id, "materials.saturation", 1.0)
	var brightness: float = number(id, "materials.value", 1.0)
	return drain(color, saturation, brightness)


static func drain(color: Color, saturation: float, brightness: float) -> Color:
	var luma: float = color.r * LUMA.x + color.g * LUMA.y + color.b * LUMA.z
	var grey: Color = Color(luma, luma, luma, color.a)
	var out: Color = grey.lerp(color, saturation)
	return Color(out.r * brightness, out.g * brightness, out.b * brightness, color.a)


# ---- the battle set ----

## A battle backdrop's settings with the profile's "backdrop" block laid over them. Every key in the block
## replaces the same key of the backdrop (colors, ambient, key light, fog); "lamp_energy_mul" and
## "lamp_color" adjust the set's lamps. Classic has no block, so the backdrop comes back unchanged.
static func backdrop_look(base: Dictionary, id: String) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	var block: Dictionary = _dict(profile(id).get("backdrop", {}))
	for key: Variant in block:
		var name: String = str(key)
		if name.begins_with("_") or name == "lamp_energy_mul" or name == "lamp_color":
			continue
		out[name] = block[key]
	if block.has("lamp_energy_mul") or block.has("lamp_color"):
		var lamps: Array = []
		for entry: Variant in out.get("lamps", []):
			var lamp: Dictionary = (entry as Dictionary).duplicate()
			lamp["energy"] = float(lamp.get("energy", 1.0)) * float(block.get("lamp_energy_mul", 1.0))
			if block.has("lamp_color"):
				lamp["color"] = block["lamp_color"]
			lamps.append(lamp)
		out["lamps"] = lamps
	return out


# ---- models ----

## The path to actually load for a model: the profile's variant when it has one that exists.
static func resolve_model(path: String) -> String:
	return resolve_model_for(path, active_id())


static func resolve_model_for(path: String, id: String) -> String:
	var variants: Dictionary = _dict(profile(id).get("models", {}))
	if variants.has(path):
		var variant: String = str(variants[path])
		if ResourceLoader.exists(variant):
			return variant
	return path


## True when a model's textures are already painted for a look (the profile's characters.prepainted list), so
## the dull pass leaves them alone.
static func is_variant_path(path: String) -> bool:
	for id: String in profile_ids():
		var listed: Variant = _dict(profile(id).get("characters", {})).get("prepainted", [])
		if listed is Array and (listed as Array).has(path):
			return true
	return false


## Dresses a freshly loaded character model for the active profile (Ross, 2026-10-08: characters and enemies
## brighter than the world, with an edge light). Every textured surface gets its own copy of the material with
##   - a drained, darkened, scuffed, gloss-free texture (GrimePaint.dull_character_*), unless the model is
##     already painted dull (the profile's "prepainted" list: Red's grim shiba),
##   - the profile's tint lift (tint_value: how bright she reads against the set), and
##   - the edge light (rim_* in psx_lit.gdshader).
## `role` is "party", "enemy" or "npc": the profile's characters.roles.<role> block lays over the base block, so
## the Signals grunts can read as dark solid blue-grey figures while the crew stays warm and bright.
## Nothing shared is edited: the copies are surface overrides on this model's own meshes.
static func dress_model(model: Node, source_path: String = "", role: String = "") -> void:
	if model == null:
		return
	var cfg: Dictionary = character_config(active_id(), role, source_path)
	if not dresses_characters_for(active_id()):
		return
	var repaint: bool = bool(cfg.get("dull", false)) and not is_variant_path(source_path)
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface: int in mesh_instance.mesh.get_surface_count():
			var source: ShaderMaterial = mesh_instance.get_active_material(surface) as ShaderMaterial
			if source == null:
				continue
			var copy: ShaderMaterial = source.duplicate() as ShaderMaterial
			var texture: Texture2D = copy.get_shader_parameter("albedo_texture") as Texture2D
			if repaint and texture != null:
				copy.set_shader_parameter("albedo_texture", GrimePaint.dull_character_texture(texture, cfg))
			var tint: Variant = copy.get_shader_parameter("albedo_tint")
			if tint is Color:
				var lifted: Color = drain(tint, float(cfg.get("tint_saturation", 1.0)), float(cfg.get("tint_value", 1.0)))
				copy.set_shader_parameter("albedo_tint", lifted)
			apply_rim(copy, cfg)
			mesh_instance.set_surface_override_material(surface, copy)


## Writes the edge-light settings of a character config into a psx_lit material.
static func apply_rim(material: ShaderMaterial, cfg: Dictionary) -> void:
	material.set_shader_parameter("rim_strength", float(cfg.get("rim_strength", 0.0)))
	if float(cfg.get("rim_strength", 0.0)) <= 0.0:
		return
	var color_value: Variant = cfg.get("rim_color", "#c4e0e8")
	material.set_shader_parameter("rim_color", Color.html(str(color_value)) if color_value is String else Color(0.77, 0.88, 0.91))
	material.set_shader_parameter("rim_power", float(cfg.get("rim_power", 2.2)))
	material.set_shader_parameter("rim_top_bias", float(cfg.get("rim_top_bias", 0.3)))
	material.set_shader_parameter("rim_bands", float(cfg.get("rim_bands", 3.0)))


## The characters block of a profile with one role's block laid over it, then any "by_model" block whose key
## appears in the model's path (so a Signals grunt standing in a room as an NPC gets the enemy look, whoever
## loads it).
static func character_config(id: String, role: String = "", source_path: String = "") -> Dictionary:
	var base: Dictionary = _dict(profile(id).get("characters", {})).duplicate()
	var roles: Dictionary = _dict(base.get("roles", {}))
	var by_model: Dictionary = _dict(base.get("by_model", {}))
	if not role.is_empty() and roles.has(role):
		for key: Variant in _dict(roles[role]):
			base[key] = (roles[role] as Dictionary)[key]
	for fragment: Variant in by_model:
		if not source_path.is_empty() and source_path.contains(str(fragment)):
			for key: Variant in _dict(by_model[fragment]):
				base[key] = (by_model[fragment] as Dictionary)[key]
	base.erase("roles")
	base.erase("by_model")
	return base


static func dulls_characters() -> bool:
	return dulls_characters_for(active_id())


static func dulls_characters_for(id: String) -> bool:
	return bool(_dict(profile(id).get("characters", {})).get("dull", false))


## True when the profile changes character materials at all (dulling, a tint lift or an edge light).
static func dresses_characters_for(id: String) -> bool:
	var cfg: Dictionary = _dict(profile(id).get("characters", {}))
	return bool(cfg.get("dull", false)) or float(cfg.get("rim_strength", 0.0)) > 0.0 or float(cfg.get("tint_value", 1.0)) != 1.0 or cfg.has("roles") or cfg.has("by_model")


## A short key for "which look a model of this path gets right now": changes when the variant path or the
## dressing changes, so a model that is already right does not reload.
static func model_look_key(path: String) -> String:
	var resolved: String = resolve_model(path)
	return "%s|%s" % [resolved, "dressed" if dresses_characters_for(active_id()) else "plain"]


# ---- internals ----

static func _identity(key: String) -> float:
	match key:
		"gain", "gamma":
			return 1.0
		"grain_fps":
			return 12.0
	return 0.0


static func _vec3(channels: Variant) -> Vector3:
	if channels is Array and (channels as Array).size() >= 3:
		var list: Array = channels
		return Vector3(float(list[0]), float(list[1]), float(list[2]))
	return Vector3.ONE


static func _dict(value_in: Variant) -> Dictionary:
	return value_in if value_in is Dictionary else {}


static func _db() -> Node:
	var tree: SceneTree = _tree()
	return tree.root.get_node_or_null("DataDB") if tree != null else null


static func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree
