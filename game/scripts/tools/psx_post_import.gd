@tool
extends EditorScenePostImport
## Scene import script for 3D models (.glb). Runs every time a model is (re)imported:
##  - swaps each imported material for the PSX look: psx_lit, or psx_unlit when the material's
##    name ends in "_unlit". The texture and base color carry over; filtering is nearest.
##  - makes the locomotion clips (idle, walk, run, ...) loop.
##  - sets every animation track to snap between keys (no smoothing), the PSX stepped feel.
## Registered project-wide in project.godot ([importer_defaults] scene) and in the .import
## file of art/placeholder/characters/red/red_blockout.glb.
## Ross never touches import settings; he just drops a .glb in the folder.

const LIT_SHADER: Shader = preload("res://shaders/psx_lit.gdshader")
const UNLIT_SHADER: Shader = preload("res://shaders/psx_unlit.gdshader")
const UNLIT_SUFFIX: String = "_unlit"
const PARAM_TEXTURE: StringName = &"albedo_texture"
const PARAM_TINT: StringName = &"albedo_tint"
## Clips that repeat. Everything else plays once. (Names from the style guide's animation list.)
const LOOPING_CLIPS: PackedStringArray = ["idle", "walk", "run", "battle_ready", "climb"]


func _post_import(scene: Node) -> Object:
	print("PSXIMPORT start ", scene.get_class())
	_convert_node(scene)
	return scene


func _convert_node(node: Node) -> void:
	print("PSXIMPORT node ", node.name, " ", node.get_class())
	if node is ImporterMeshInstance3D:
		var importer_mesh: ImporterMesh = (node as ImporterMeshInstance3D).mesh
		if importer_mesh != null:
			_convert_mesh(importer_mesh)
	elif node is AnimationPlayer:
		_convert_animations(node as AnimationPlayer)
	for child: Node in node.get_children():
		_convert_node(child)


func _convert_mesh(mesh: ImporterMesh) -> void:
	for surface: int in mesh.get_surface_count():
		var source: Material = mesh.get_surface_material(surface)
		mesh.set_surface_material(surface, make_psx_material(source))


## Builds the PSX material that replaces an imported one. Public so tests can call it.
static func make_psx_material(source: Material) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	var source_name: String = ""
	if source != null:
		source_name = source.resource_name
	material.resource_name = source_name
	material.shader = UNLIT_SHADER if source_name.ends_with(UNLIT_SUFFIX) else LIT_SHADER
	var standard: BaseMaterial3D = source as BaseMaterial3D
	if standard != null:
		if standard.albedo_texture != null:
			material.set_shader_parameter(PARAM_TEXTURE, standard.albedo_texture)
		material.set_shader_parameter(PARAM_TINT, standard.albedo_color)
	return material


func _convert_animations(player: AnimationPlayer) -> void:
	for clip_name: StringName in player.get_animation_list():
		var animation: Animation = player.get_animation(clip_name)
		if LOOPING_CLIPS.has(String(clip_name)):
			animation.loop_mode = Animation.LOOP_LINEAR
		for track: int in animation.get_track_count():
			animation.track_set_interpolation_type(track, Animation.INTERPOLATION_NEAREST)
