class_name PropLook
extends RefCounted
## Placeholder look for the exploration props: PSX-shaded boxes in a tint, made in code so a prop
## scene needs no art. Real models replace these by putting a child named "Model" in the scene.

const SHADER_LIT: String = "res://shaders/psx_lit.gdshader"
const SHADER_UNLIT: String = "res://shaders/psx_unlit.gdshader"
const TEXTURE: String = "res://art/placeholder/textures/checker_128.png"
const UNLIT_UV_SCALE: Vector2 = Vector2(0.07, 0.07)
const UNLIT_UV_OFFSET: Vector2 = Vector2(0.02, 0.02)


static func lit(tint: Color) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load(SHADER_LIT) as Shader
	material.set_shader_parameter("albedo_texture", load(TEXTURE))
	material.set_shader_parameter("albedo_tint", tint)
	return material


## Full-bright and glowing (the pickup glint, door readers).
static func glow(tint: Color, energy: float = 1.4) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load(SHADER_UNLIT) as Shader
	material.set_shader_parameter("albedo_texture", load(TEXTURE))
	material.set_shader_parameter("uv_scale", UNLIT_UV_SCALE)
	material.set_shader_parameter("uv_offset", UNLIT_UV_OFFSET)
	material.set_shader_parameter("albedo_tint", tint)
	material.set_shader_parameter("emission_energy", energy)
	return material


static func box(size: Vector3, material: Material, node_name: String = "Box") -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	return instance


## A solid box on the world layer (layer 1) with its center at `center` (local).
static func solid_box(size: Vector3, center: Vector3, node_name: String = "Solid") -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.collision_mask = 0
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	shape_node.position = center
	body.add_child(shape_node)
	return body
