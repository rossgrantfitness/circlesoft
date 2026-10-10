class_name HitFlash
extends RefCounted
## The white impact flash (Tuning v1.3, Ross: chunky hits): for a split second after a hit lands, the struck model turns flat,
## fully opaque, unshaded white, then snaps back. It works by putting one flat white material on every mesh's `material_override`
## (which wins over the model's own materials, PS2 shader included) and clearing `material_overlay` (the enemy's wind-up and hijack
## tints); both are put back exactly as they were when the time is up.
##
## The clock is REAL time: CombatFx calls step() from _process with the real frame delta, so the flash is fully visible inside the
## hit-stop freeze (a fighter in hit-stop has combat time 0, but this never asks the combat clock).
##
## Safe to hit twice (the second hit only restarts the timer; the first originals are kept), safe if the model is freed or the enemy
## dies mid-flash (dead meshes are skipped), and polite to other code: if something else swapped a mesh's material while it was
## white, the flash leaves that new material alone.

const SKIP_META: StringName = &"no_hit_flash"                       ## set on a mesh (or any parent) to leave it out
const SKIP_NODE_NAMES: PackedStringArray = ["Fx", "Hurtbox", "Hitbox"]

## target instance id -> {"target": Node, "meshes": Array[Dictionary], "left_s": float, "material": StandardMaterial3D}
var _live: Dictionary = {}


## Starts (or restarts) the flash on `target`'s meshes. `roots` are the nodes whose MeshInstance3D descendants flash (see roots_for).
## Returns false when there is nothing to flash.
func start(target: Node, roots: Array[Node], duration_s: float, color: Color = Color.WHITE) -> bool:
	if target == null or duration_s <= 0.0:
		return false
	var key: int = target.get_instance_id()
	if _live.has(key):
		var running: Dictionary = _live[key]
		running["left_s"] = maxf(float(running["left_s"]), duration_s)
		((running["material"]) as StandardMaterial3D).albedo_color = color
		return true
	var meshes: Array[MeshInstance3D] = []
	for root: Node in roots:
		_collect(root, meshes)
	if meshes.is_empty():
		return false
	var material: StandardMaterial3D = make_material(color)
	var saved: Array[Dictionary] = []
	for mesh: MeshInstance3D in meshes:
		saved.append({"mesh": mesh, "override": mesh.material_override, "overlay": mesh.material_overlay})
		mesh.material_override = material
		mesh.material_overlay = null
	_live[key] = {"target": target, "meshes": saved, "left_s": duration_s, "material": material}
	return true


## One real frame. Anything that has run out is put back.
func step(real_delta_s: float) -> void:
	if _live.is_empty():
		return
	var done: Array[int] = []
	for key: int in _live.keys():
		var entry: Dictionary = _live[key]
		entry["left_s"] = float(entry["left_s"]) - maxf(real_delta_s, 0.0)
		if float(entry["left_s"]) <= 0.0:
			done.append(key)
	for key: int in done:
		_restore(key)


## Puts every flashing model back right now (the FX node is leaving, or a test is finished).
func clear() -> void:
	for key: int in _live.keys():
		_restore(key)


func is_flashing(target: Node) -> bool:
	return target != null and _live.has(target.get_instance_id())


func active_count() -> int:
	return _live.size()


## Seconds of flash left on `target` (0 when it is not flashing).
func time_left_s(target: Node) -> float:
	if target == null or not _live.has(target.get_instance_id()):
		return 0.0
	return float((_live[target.get_instance_id()] as Dictionary)["left_s"])


## The flat white material: unshaded, opaque, no fog, no shadows on it, both faces (a thin model shows no holes).
static func make_material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	material.albedo_color = Color(color.r, color.g, color.b, 1.0)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.disable_fog = true
	material.disable_receive_shadows = true
	material.resource_name = "hit_flash_white"
	return material


## The nodes whose meshes flash for `actor` (pure, tests use it):
##  1. an actor that wants a say implements `hit_flash_roots() -> Array` (a boss that knows its own armour mesh);
##  2. a boss PART flashes its own mesh in the boss model (relay_fl, dish, plate_chest_front ...), else nothing (its marker box already blinks);
##  3. a fighter with a `get_model()` or an instanced .glb flashes that model; else its "Model" child; else the whole actor.
static func roots_for(actor: Node) -> Array[Node]:
	var out: Array[Node] = []
	if actor == null:
		return out
	if actor.has_method("hit_flash_roots"):
		for item: Variant in actor.call("hit_flash_roots") as Array:
			if item is Node:
				out.append(item as Node)
		if not out.is_empty():
			return out
	if actor is BossPart:
		var found: Node = _part_mesh(actor as BossPart)
		if found != null:
			out.append(found)
			return out
		return out                                       # no mesh to show it by: the marker box already blinks on a hit
	if actor is Node3D:
		var model: Node3D = CombatFx.find_model(actor as Node3D)
		if model == null:
			model = actor.get_node_or_null("Model") as Node3D
		out.append(model if model != null else actor)
	return out


## The mesh node a boss part shows as (looked up by name in the boss's model), or null.
static func _part_mesh(part: BossPart) -> Node:
	var boss: Node = part.owner_boss
	if boss == null or not is_instance_valid(boss):
		return null
	var names: Array[String] = [String(part.part_id)]
	var map: Variant = _constant(boss, "PART_NODES")
	if map is Dictionary and (map as Dictionary).has(String(part.part_id)):
		var spec: Dictionary = (map as Dictionary)[String(part.part_id)] as Dictionary
		names.append(str(spec.get("mesh", "")))
		names.append(str(spec.get("bone", "")).trim_suffix("_mount"))
	var pair: String = str(part.on_break.get("drops_pair", ""))
	if not pair.is_empty():
		names.append("relay_%s" % pair)
	for wanted: String in names:
		if wanted.is_empty():
			continue
		var node: Node = boss.find_child(wanted, true, false)
		if node != null and node != part:
			return node
	return null


static func _constant(object: Object, name: String) -> Variant:
	var script: Script = object.get_script() as Script
	if script == null:
		return null
	return script.get_script_constant_map().get(name, null)


## Every visible, solid mesh at or under `node`, left out when it is an effect: shadow-only, transparent, marked, or under a node
## called Fx / Hurtbox / Hitbox.
static func _collect(node: Node, out: Array[MeshInstance3D]) -> void:
	if node == null or not is_instance_valid(node) or node.has_meta(SKIP_META) or SKIP_NODE_NAMES.has(String(node.name)):
		return
	if node is MeshInstance3D:
		var mesh: MeshInstance3D = node as MeshInstance3D
		if mesh.visible and mesh.mesh != null and mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY \
				and not _is_effect_material(mesh.material_override):
			out.append(mesh)
	for child: Node in node.get_children():
		_collect(child, out)


## A see-through, glowing or billboarded material is an effect (a sparkle, a lamp glow, a ring), not part of the body. An
## alpha-scissor or alpha-hash material with a solid colour is just a body with a cut-out texture, and flashes.
static func _is_effect_material(material: Material) -> bool:
	if material is BaseMaterial3D:
		var base: BaseMaterial3D = material as BaseMaterial3D
		if base.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED:
			return true
		if base.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
			return false
		return base.blend_mode != BaseMaterial3D.BLEND_MODE_MIX or base.albedo_color.a < 0.99
	return false


func _restore(key: int) -> void:
	var entry: Dictionary = _live.get(key, {})
	_live.erase(key)
	var flash_material: Material = entry.get("material", null) as Material
	for item: Variant in entry.get("meshes", []) as Array:
		var saved: Dictionary = item as Dictionary
		var mesh: Variant = saved["mesh"]
		if not is_instance_valid(mesh):
			continue                                     # freed while white (the enemy died and was cleared): nothing to put back
		var node: MeshInstance3D = mesh as MeshInstance3D
		if node.material_override == flash_material:
			node.material_override = saved["override"] as Material
		if node.material_overlay == null:
			node.material_overlay = saved["overlay"] as Material
