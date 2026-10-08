class_name GrimDressing
extends Node3D
## The "grim" dressing for one room or the battle set. Put one on a room's root (the Harrow generator does
## it for the look-test rooms) with `dressing_id` = the key in data/world/look_dressing.json.
##
## When the active look profile asks for dressing ("dressing": true), it
##   - builds the room's props once (posters, floodlights, cables, signs, steam, rain... GrimProps),
##   - grimes the room's own materials: floors and walls get painted grime textures, every lit material's
##     tint is drained and darkened (the profile's "materials" block),
##   - adds the profile's hard key light.
## When the profile does not (classic), the props hide and every material goes back exactly as it was.
## Characters are never touched here (they have their own dull pass, LookProfiles / CharacterLook).

const DATA_ID: String = "world/look_dressing"
const GROUP: StringName = &"grim_dressing"
const LIT_SHADER_PATH: String = "res://shaders/psx_lit.gdshader"
const PARAM_TEXTURE: StringName = &"albedo_texture"
const PARAM_TINT: StringName = &"albedo_tint"
const CHARACTER_CLASSES: PackedStringArray = ["PlayerController", "Npc", "PartyFollower", "FieldEnemy", "MapEnemy", "CombatantView"]

## The key in data/world/look_dressing.json "rooms".
@export var dressing_id: String = ""
## Grime the room's own materials too. The battle backdrop paints its own, so it turns this off.
@export var restyle_materials: bool = true

## What to build, when set by code (tests, the battle backdrop). Empty = read from the data file.
var config: Dictionary = {}
var props_root: Node3D = null
var key_light: DirectionalLight3D = null
var prop_count: int = 0
var is_on: bool = false

## What was on each restyled surface before the grime ({"mesh", "surface", "override"}), for putting it back.
var _records: Array[Dictionary] = []


func _ready() -> void:
	add_to_group(LookProfiles.GROUP_AWARE)
	add_to_group(GROUP)
	apply_look(LookProfiles.active_id(), LookProfiles.active())


## Called by LookProfiles when the profile changes (and once from _ready).
func apply_look(_id: String, profile: Dictionary) -> void:
	var wants: bool = bool(profile.get("dressing", false))
	if wants:
		_ensure_built()
		is_on = true
		props_root.visible = true
		props_root.process_mode = Node.PROCESS_MODE_INHERIT
		_apply_key_light(profile)
		if restyle_materials:
			_restyle(profile)
	else:
		is_on = false
		if props_root != null:
			props_root.visible = false
			props_root.process_mode = Node.PROCESS_MODE_DISABLED
		_restore()


## The room's dressing data: {"items": [...], "key_light": {...}}.
func dressing_data() -> Dictionary:
	if not config.is_empty():
		return config
	var db: Node = get_node_or_null("/root/DataDB")
	if db == null:
		return {}
	var found: Variant = db.call("get_value", DATA_ID, "rooms." + dressing_id, {})
	return found if found is Dictionary else {}


func _ensure_built() -> void:
	if props_root != null:
		return
	props_root = Node3D.new()
	props_root.name = "GrimProps"
	add_child(props_root)
	var data: Dictionary = dressing_data()
	var grime: Dictionary = _dict(LookProfiles.active().get("grime", {}))
	for entry: Variant in data.get("items", []):
		if entry is Dictionary:
			var prop: Node3D = GrimProps.build(entry, grime)
			if prop != null:
				props_root.add_child(prop)
				prop_count += 1
	key_light = null


func _apply_key_light(profile: Dictionary) -> void:
	var config_key: Variant = dressing_data().get("key_light", null)
	var rig: Dictionary = {}
	if config_key is Dictionary:
		rig = config_key
	var scale: float = float(_dict(profile.get("lighting", {})).get("dressing_key_scale", 1.0))
	if rig.is_empty():
		if key_light != null:
			key_light.visible = false
		return
	if key_light == null:
		key_light = DirectionalLight3D.new()
		key_light.name = "GrimKey"
		props_root.add_child(key_light)
	key_light.visible = true
	key_light.light_color = Color.html(str(rig.get("color", "#d6e4dc")))
	key_light.light_energy = float(rig.get("energy", 0.8)) * scale
	var angles: Array = rig.get("dir_deg", [-50.0, 35.0])
	key_light.rotation_degrees = Vector3(float(angles[0]), float(angles[1]), 0.0)
	key_light.shadow_enabled = false


# ---- the room's own materials ----
# The room's materials are shared resources (a scene file's sub-resources), so they are never edited:
# each mesh surface gets its own grimed COPY as a surface override, and the old override (usually none)
# is remembered and put back for classic.

func _restyle(profile: Dictionary) -> void:
	_restore()
	var grime: Dictionary = _dict(profile.get("grime", {}))
	var id: String = LookProfiles.active_id()
	var copies: Dictionary[ShaderMaterial, ShaderMaterial] = {}
	for entry: Dictionary in _room_surfaces():
		var source: ShaderMaterial = entry["source"]
		if not copies.has(source):
			var copy: ShaderMaterial = source.duplicate() as ShaderMaterial
			var texture: Texture2D = source.get_shader_parameter(PARAM_TEXTURE) as Texture2D
			var kind: String = GrimePaint.kind_for_path(texture.resource_path) if texture != null else ""
			if kind != "":
				copy.set_shader_parameter(PARAM_TEXTURE, GrimePaint.surface_texture(kind, grime))
			var tint: Variant = source.get_shader_parameter(PARAM_TINT)
			copy.set_shader_parameter(PARAM_TINT, LookProfiles.grade_color(tint if tint is Color else Color.WHITE, id))
			copies[source] = copy
		var mesh_instance: MeshInstance3D = entry["mesh"]
		_records.append({"mesh": mesh_instance, "surface": entry["surface"], "override": entry["override"]})
		mesh_instance.set_surface_override_material(entry["surface"], copies[source])


func _restore() -> void:
	for record: Dictionary in _records:
		var mesh_instance: MeshInstance3D = record["mesh"]
		if is_instance_valid(mesh_instance):
			mesh_instance.set_surface_override_material(record["surface"], record["override"])
	_records.clear()


## Every lit surface of the room's own geometry (not characters, not this node's props), as
## {"mesh", "surface", "override" (what was set before), "source" (the ShaderMaterial in use)}.
func _room_surfaces() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var host: Node = get_parent()
	if host == null:
		return found
	for node: Node in host.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh == null or _is_character_branch(mesh_instance) or (props_root != null and props_root.is_ancestor_of(mesh_instance)):
			continue
		for surface: int in mesh_instance.mesh.get_surface_count():
			var override: Material = mesh_instance.get_surface_override_material(surface)
			var material: ShaderMaterial = override as ShaderMaterial
			if material == null and override == null:
				material = mesh_instance.mesh.surface_get_material(surface) as ShaderMaterial
			if material != null and material.shader != null and material.shader.resource_path == LIT_SHADER_PATH:
				found.append({"mesh": mesh_instance, "surface": surface, "override": override, "source": material})
	return found


func _is_character_branch(node: Node) -> bool:
	var current: Node = node.get_parent()
	while current != null and current != get_parent():
		var script: Script = current.get_script() as Script
		if script != null and CHARACTER_CLASSES.has(script.get_global_name()):
			return true
		if current.is_in_group(&"npc") or current.is_in_group(&"player"):
			return true
		current = current.get_parent()
	return false


static func _dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}
