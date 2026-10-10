@tool
extends EditorScenePostImport
## Scene import script for 3D models (.glb). Runs every time a model is (re)imported:
##  - swaps each imported material for the PSX look: psx_lit by default; psx_unlit when the
##    material's name ends in "_unlit"; psx_cel (two-band cel lighting) when it ends in "_cel";
##    psx_outline (inverted-hull ink line) when it ends in "_outline". The texture and base color
##    carry over; filtering is nearest. Materials without those suffixes are untouched in behavior.
##  - makes the locomotion clips (idle, walk, run, ...) loop.
##  - sets every animation track to snap between keys (no smoothing), the PSX stepped feel.
## Registered project-wide in project.godot ([importer_defaults] scene) and in the .import
## file of art/placeholder/characters/red/red_blockout.glb.
## Ross never touches import settings; he just drops a .glb in the folder.

const LIT_SHADER: Shader = preload("res://shaders/psx_lit.gdshader")
## Models under art/final/ (Ross's own art) get the PS2 per-pixel shader instead (smooth, mipmapped textures, the
## metallic-roughness map read); placeholders and the old game keep the PSX materials. Set per model in _post_import.
const PS2_SHADER: Shader = preload("res://shaders/ps2_lit.gdshader")
const FINAL_ART_PREFIX: String = "res://art/final/"
const PARAM_ORM: StringName = &"orm_texture"
const UNLIT_SHADER: Shader = preload("res://shaders/psx_unlit.gdshader")
const CEL_SHADER: Shader = preload("res://shaders/psx_cel.gdshader")
const OUTLINE_SHADER: Shader = preload("res://shaders/psx_outline.gdshader")
const UNLIT_SUFFIX: String = "_unlit"
const CEL_SUFFIX: String = "_cel"
const OUTLINE_SUFFIX: String = "_outline"
const PARAM_TEXTURE: StringName = &"albedo_texture"
const PARAM_TINT: StringName = &"albedo_tint"
## Clips that repeat. Everything else plays once and holds its last pose (jump holds the rising
## pose until the fall clip takes over; land plays once). Names from the style guide's list.
const LOOPING_CLIPS: PackedStringArray = ["idle", "walk", "run", "fall", "battle_ready", "climb", "launched", "stagger"]

var _ps2: bool = false


func _post_import(scene: Node) -> Object:
	_ps2 = get_source_file().begins_with(FINAL_ART_PREFIX)
	_convert_node(scene)
	return scene


func _convert_node(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh: Mesh = (node as MeshInstance3D).mesh
		if mesh != null:
			_convert_mesh(mesh)
	elif node is ImporterMeshInstance3D:
		var importer_mesh: ImporterMesh = (node as ImporterMeshInstance3D).mesh
		if importer_mesh != null:
			_convert_importer_mesh(importer_mesh)
	elif node is AnimationPlayer:
		_convert_animations(node as AnimationPlayer)
	for child: Node in node.get_children():
		_convert_node(child)


# Godot hands import scripts finished meshes (MeshInstance3D); older paths use ImporterMesh.
func _convert_mesh(mesh: Mesh) -> void:
	for surface: int in mesh.get_surface_count():
		var source: Material = mesh.surface_get_material(surface)
		if source is ShaderMaterial:
			continue   # already converted (a material shared by two meshes is visited twice)
		mesh.surface_set_material(surface, make_ps2_material(source) if _ps2 else make_psx_material(source))


func _convert_importer_mesh(mesh: ImporterMesh) -> void:
	for surface: int in mesh.get_surface_count():
		var source: Material = mesh.get_surface_material(surface)
		if source is ShaderMaterial:
			continue   # already converted (a material shared by two meshes is visited twice)
		mesh.set_surface_material(surface, make_ps2_material(source) if _ps2 else make_psx_material(source))


## Which PSX shader a material gets, chosen by the end of its name. Public so tests can call it.
static func shader_for_name(material_name: String) -> Shader:
	if material_name.ends_with(OUTLINE_SUFFIX):
		return OUTLINE_SHADER
	if material_name.ends_with(CEL_SUFFIX):
		return CEL_SHADER
	if material_name.ends_with(UNLIT_SUFFIX):
		return UNLIT_SHADER
	return LIT_SHADER


## Builds the PSX material that replaces an imported one. Public so tests can call it.
static func make_psx_material(source: Material) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	var source_name: String = ""
	if source != null:
		source_name = source.resource_name
	material.resource_name = source_name
	material.shader = shader_for_name(source_name)
	var standard: BaseMaterial3D = source as BaseMaterial3D
	if standard != null:
		if standard.albedo_texture != null:
			material.set_shader_parameter(PARAM_TEXTURE, standard.albedo_texture)
		material.set_shader_parameter(PARAM_TINT, standard.albedo_color)
	return material


## Builds the PS2 material for Ross's final art: the base-color texture (with mipmaps), the glTF metallic-roughness map
## and the tint. Public so tests can call it. The normal map stays in the .glb for the next rendering step.
static func make_ps2_material(source: Material) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.resource_name = source.resource_name if source != null else ""
	material.shader = PS2_SHADER
	var standard: BaseMaterial3D = source as BaseMaterial3D
	if standard != null:
		if standard.albedo_texture != null:
			material.set_shader_parameter(PARAM_TEXTURE, with_mipmaps(standard.albedo_texture))
		var packed: Texture2D = standard.roughness_texture if standard.roughness_texture != null else standard.metallic_texture
		if packed != null:
			material.set_shader_parameter(PARAM_ORM, with_mipmaps(packed))
			material.set_shader_parameter(&"use_orm", 1.0)
		else:
			material.set_shader_parameter(&"use_orm", 0.0)
		material.set_shader_parameter(PARAM_TINT, standard.albedo_color)
	return material


## The same texture with a full mip chain (so the smooth sampler does not shimmer in the distance).
static func with_mipmaps(texture: Texture2D) -> Texture2D:
	var image: Image = texture.get_image()
	if image == null or image.has_mipmaps():
		return texture
	image = image.duplicate()
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func _convert_animations(player: AnimationPlayer) -> void:
	for clip_name: StringName in player.get_animation_list():
		var animation: Animation = player.get_animation(clip_name)
		if LOOPING_CLIPS.has(String(clip_name)):
			animation.loop_mode = Animation.LOOP_LINEAR
		for track: int in animation.get_track_count():
			animation.track_set_interpolation_type(track, Animation.INTERPOLATION_NEAREST)
