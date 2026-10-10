extends TestCase
## The three NPC blockouts (Otis, Mox, the old Zero) in the Red house style, and the way npc.gd loads them
## by path. Models load, stay under the triangle caps, use the shared 17-bone rig, carry an "idle" clip,
## are sized against Red, and each NPC's speech-bubble height matches data/ui/dialogue_ui.json.
## Needs the project imported once: godot --headless --path game --import

const DIR: String = "res://art/placeholder/characters/"
const RED_REFERENCE: String = "res://art/placeholder/characters/red_prototypes/red_proto_f.glb"
const NPC_SCENE: String = "res://scenes/actors/npc.tscn"
const ROOM_PATH: String = "res://scenes/debug/psx_test_room.tscn"
const PROP_MARK: String = "_prop_"
const BODY_MARK: String = "_body"
const PARTY_CAP: int = 900
const CROWD_CAP: int = 500
const PROP_CAP: int = 150
const MAX_TEXTURE_PX: int = 128
const RATIO_TOLERANCE: float = 0.07
const IDLE_SECONDS: float = 1.5
const HEIGHT_TOLERANCE: float = 0.06
const BUBBLE_LIFT: float = 0.1
const LIT_SHADER: String = "res://shaders/psx_lit.gdshader"
const REQUIRED_BONES: PackedStringArray = [
	"root", "hips", "spine", "head", "ear_r", "ear_l", "tail", "upper_arm_r", "forearm_r", "upper_arm_l",
	"forearm_l", "thigh_r", "shin_r", "thigh_l", "shin_l", "weapon_socket", "prop_socket",
]
## name -> {path, speaker id, tri cap, height vs Red (min, max), the room node}
const CAST: Dictionary[String, Dictionary] = {
	"otis": {"path": "otis/chr_otis.glb", "speaker": "otis", "cap": PARTY_CAP, "ratio": [1.18, 1.32], "node": "Otis"},
	"mox": {"path": "mox/chr_mox.glb", "speaker": "mox", "cap": PARTY_CAP, "ratio": [1.08, 1.22], "node": "Mox"},
	"zero": {"path": "old_zero/npc_old_zero.glb", "speaker": "zero_old", "cap": CROWD_CAP, "ratio": [0.85, 1.02], "node": "OldZero"},
}


func _model(path: String) -> Node3D:
	var packed: PackedScene = load(path) as PackedScene
	assert_not_null(packed, path + " should import (run godot --headless --path game --import)")
	var model: Node3D = packed.instantiate() as Node3D
	own(model)
	return model


func _meshes(model: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh != null:
			found.append(mesh_instance)
	return found


func _triangles(mesh_instance: MeshInstance3D) -> int:
	var total: int = 0
	for surface: int in mesh_instance.mesh.get_surface_count():
		var arrays: Array = mesh_instance.mesh.surface_get_arrays(surface)
		var indices: Variant = arrays[Mesh.ARRAY_INDEX]
		if indices != null and (indices as PackedInt32Array).size() > 0:
			total += (indices as PackedInt32Array).size() / 3
		else:
			total += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return total


## Top of the body mesh(es), props excluded, in the model's own space.
func _body_top(model: Node3D) -> float:
	var top: float = 0.0
	for mesh_instance: MeshInstance3D in _meshes(model):
		if String(mesh_instance.name).contains(PROP_MARK) or String(mesh_instance.name).contains("sword"):
			continue
		top = maxf(top, mesh_instance.get_aabb().end.y)
	return top


func _npc(model_path: String) -> Npc:
	var npc: Npc = (load(NPC_SCENE) as PackedScene).instantiate() as Npc
	npc.speaker_id = "test"
	npc.model_path = model_path
	add_to_root(npc)
	return npc


# ---- the model files ----

func test_each_model_imports_with_a_body_and_props_named_as_props() -> void:
	for who: String in CAST:
		var model: Node3D = _model(DIR + str(CAST[who]["path"]))
		var bodies: int = 0
		for mesh_instance: MeshInstance3D in _meshes(model):
			if String(mesh_instance.name).contains(BODY_MARK):
				bodies += 1
		assert_eq(bodies, 1, who + " has one body mesh")
	assert_eq(_meshes(_model(DIR + "otis/chr_otis.glb")).size(), 3, "Otis: body, door, hammer")
	assert_eq(_meshes(_model(DIR + "mox/chr_mox.glb")).size(), 3, "Mox: body, wrench, drone")
	assert_eq(_meshes(_model(DIR + "old_zero/npc_old_zero.glb")).size(), 2, "Zero: body, thermos")


func test_triangles_are_under_the_cap_in_total_and_props_under_150() -> void:
	for who: String in CAST:
		var model: Node3D = _model(DIR + str(CAST[who]["path"]))
		var total: int = 0
		for mesh_instance: MeshInstance3D in _meshes(model):
			var count: int = _triangles(mesh_instance)
			total += count
			if String(mesh_instance.name).contains(PROP_MARK):
				assert_le(count, PROP_CAP, "%s %s is %d triangles" % [who, mesh_instance.name, count])
		assert_le(total, int(CAST[who]["cap"]), "%s is %d triangles in all" % [who, total])
		assert_gt(total, 300, who + " is not an empty model")


func test_each_model_has_the_shared_17_bones() -> void:
	for who: String in CAST:
		var skeletons: Array[Node] = _model(DIR + str(CAST[who]["path"])).find_children("*", "Skeleton3D", true, false)
		assert_eq(skeletons.size(), 1, who + " has one skeleton")
		var skeleton: Skeleton3D = skeletons[0] as Skeleton3D
		assert_eq(skeleton.get_bone_count(), REQUIRED_BONES.size(), who + " bone count")
		for bone: String in REQUIRED_BONES:
			assert_ge(skeleton.find_bone(bone), 0, "%s has bone %s" % [who, bone])


func test_each_model_has_a_looping_stepped_idle_of_about_1_5_seconds() -> void:
	for who: String in CAST:
		var players: Array[Node] = _model(DIR + str(CAST[who]["path"])).find_children("*", "AnimationPlayer", true, false)
		assert_eq(players.size(), 1, who + " has one AnimationPlayer")
		var player: AnimationPlayer = players[0] as AnimationPlayer
		assert_true(player.has_animation("idle"), who + " has an idle clip")
		var clip: Animation = player.get_animation("idle")
		assert_eq(clip.loop_mode, Animation.LOOP_LINEAR, who + " idle loops")
		assert_almost_eq(clip.length, IDLE_SECONDS, 0.1, who + " idle length")
		assert_gt(clip.get_track_count(), 0, who + " idle has tracks")
		for track: int in clip.get_track_count():
			assert_eq(clip.track_get_interpolation_type(track), Animation.INTERPOLATION_NEAREST, "%s idle track %d is stepped" % [who, track])
		assert_eq(player.get_animation_list().size(), 1, who + " has only the idle (no talk clip yet, by Ross's call)")


func test_materials_are_psx_lit_with_small_textures() -> void:
	for who: String in CAST:
		var model: Node3D = _model(DIR + str(CAST[who]["path"]))
		var seen: int = 0
		for mesh_instance: MeshInstance3D in _meshes(model):
			for surface: int in mesh_instance.mesh.get_surface_count():
				var material: ShaderMaterial = mesh_instance.mesh.surface_get_material(surface) as ShaderMaterial
				assert_not_null(material, "%s %s surface %d is a ShaderMaterial" % [who, mesh_instance.name, surface])
				if material == null:
					continue
				assert_eq(material.shader.resource_path, LIT_SHADER, who + " uses psx_lit")
				assert_true(material.resource_name.begins_with("mat_"), "%s material is named mat_<model> (%s)" % [who, material.resource_name])
				var texture: Texture2D = material.get_shader_parameter("albedo_texture") as Texture2D
				assert_not_null(texture, who + " texture")
				if texture != null:
					assert_le(texture.get_width(), MAX_TEXTURE_PX, who + " texture width")
					assert_le(texture.get_height(), MAX_TEXTURE_PX, who + " texture height")
					seen += 1
		assert_gt(seen, 0, who + " has textured surfaces")


func test_heights_are_scaled_against_red() -> void:
	var red: float = _body_top(_model(RED_REFERENCE))
	assert_gt(red, 0.9, "Red's blockout is about one unit tall")
	for who: String in CAST:
		var ratio: float = _body_top(_model(DIR + str(CAST[who]["path"]))) / red
		var limits: Array = CAST[who]["ratio"]
		assert_ge(ratio, float(limits[0]), "%s is %.2f x Red" % [who, ratio])
		assert_le(ratio, float(limits[1]), "%s is %.2f x Red" % [who, ratio])
	var otis: float = _body_top(_model(DIR + "otis/chr_otis.glb"))
	var mox: float = _body_top(_model(DIR + "mox/chr_mox.glb"))
	var zero: float = _body_top(_model(DIR + "old_zero/npc_old_zero.glb"))
	assert_gt(otis, mox, "Otis is taller than Mox")
	assert_gt(mox, red, "Mox is taller than Red")
	assert_lt(zero, red, "the old Zero is shorter than Red")


func test_feet_are_on_the_floor() -> void:
	for who: String in CAST:
		var model: Node3D = _model(DIR + str(CAST[who]["path"]))
		for mesh_instance: MeshInstance3D in _meshes(model):
			if String(mesh_instance.name).contains(BODY_MARK):
				assert_almost_eq(mesh_instance.get_aabb().position.y, 0.0, 0.05, who + " feet at the origin")


# ---- npc.gd wiring ----

func test_npc_loads_the_model_by_path_and_plays_idle() -> void:
	for who: String in CAST:
		var npc: Npc = _npc(DIR + str(CAST[who]["path"]))
		assert_not_null(npc.get_model(), who + " model is loaded under Visual")
		assert_eq(npc.get_model().get_parent(), npc.get_node("Visual"))
		assert_null(npc.get_node_or_null("Visual/Body"), who + ": no capsule placeholder when a model is there")
		var player: AnimationPlayer = npc.get_animation_player()
		assert_not_null(player, who + " has an animation player")
		assert_eq(String(player.current_animation), "idle", who + " plays idle")
		assert_true(player.is_playing())


func test_npc_with_no_model_keeps_the_capsule_placeholder() -> void:
	var npc: Npc = _npc("")
	assert_null(npc.get_model())
	assert_not_null(npc.get_node_or_null("Visual/Body"))
	assert_almost_eq(npc.get_head_height(), Npc.HEAD_TOP_Y + Npc.BUBBLE_LIFT, 0.0001)


func test_a_model_with_other_clip_names_still_works() -> void:
	# An outsourced model may name its idle differently or have none: it must still stand there.
	var npc: Npc = (load(NPC_SCENE) as PackedScene).instantiate() as Npc
	npc.speaker_id = "test"
	npc.model_path = DIR + "otis/chr_otis.glb"
	npc.idle_clip = &"not_a_clip"
	add_to_root(npc)
	assert_not_null(npc.get_model())
	assert_false(npc.get_animation_player().is_playing(), "no such clip, so nothing plays")
	npc.step(0.1)


func test_head_height_is_the_models_head_top_plus_the_bubble_lift() -> void:
	for who: String in CAST:
		var path: String = DIR + str(CAST[who]["path"])
		var npc: Npc = _npc(path)
		var expected: float = _body_top(_model(path)) + BUBBLE_LIFT
		assert_almost_eq(npc.get_head_height(), expected, 0.02, who + " head height follows the model")


func test_materials_are_warmed_so_the_blue_room_does_not_grey_them() -> void:
	LookProfiles.set_forced("classic")          # the grim look dresses characters with its own material copies
	var npc: Npc = _npc(DIR + "mox/chr_mox.glb")
	var checked: int = 0
	for mesh_instance: MeshInstance3D in _meshes(npc.get_model()):
		for surface: int in mesh_instance.mesh.get_surface_count():
			var material: ShaderMaterial = mesh_instance.get_active_material(surface) as ShaderMaterial
			var tint: Color = material.get_shader_parameter("albedo_tint")
			assert_gt(tint.r, tint.b, "tint leans warm: red above blue")
			assert_gt(tint.r, 1.0, "and a touch bright, to beat the dim ambient")
			checked += 1
	assert_gt(checked, 0)
	var plain: Npc = (load(NPC_SCENE) as PackedScene).instantiate() as Npc
	plain.speaker_id = "test"
	plain.model_path = DIR + "mox/chr_mox.glb"
	plain.light_compensation = Color.WHITE
	add_to_root(plain)
	assert_null(_meshes(plain.get_model())[0].get_surface_override_material(0), "white compensation leaves the materials alone")


# ---- in the test room ----

func test_room_npcs_use_the_blockouts_and_their_bubble_height_matches_the_data() -> void:
	var room: Node = (load(ROOM_PATH) as PackedScene).instantiate()
	add_to_root(room)
	var speakers: Dictionary = tree.root.get_node("DataDB").call("get_value", "ui/dialogue_ui", "speakers")
	var seen: Array[String] = []
	for who: String in CAST:
		var npc: Npc = room.get_node(str(CAST[who]["node"])) as Npc
		assert_not_null(npc.get_model(), who + " has its model in the room")
		assert_eq(npc.model_path, DIR + str(CAST[who]["path"]))
		assert_does_not_have(seen, npc.model_path)
		seen.append(npc.model_path)
		assert_eq(npc.speaker_id, str(CAST[who]["speaker"]))
		var wanted: float = float(speakers[npc.speaker_id]["head_height"])
		assert_almost_eq(npc.get_head_height(), wanted, HEIGHT_TOLERANCE, "%s bubble height vs data/ui/dialogue_ui.json" % who)


func test_room_npc_collision_fits_the_model() -> void:
	var room: Node = (load(ROOM_PATH) as PackedScene).instantiate()
	add_to_root(room)
	var radii: Dictionary[String, float] = {}
	for who: String in CAST:
		var npc: Npc = room.get_node(str(CAST[who]["node"])) as Npc
		var shape_node: CollisionShape3D = npc.get_node("Body/CollisionShape3D") as CollisionShape3D
		var cylinder: CylinderShape3D = shape_node.shape as CylinderShape3D
		assert_not_null(cylinder, who + " has a cylinder body")
		assert_almost_eq(cylinder.radius, npc.collision_radius, 0.0001)
		assert_almost_eq(shape_node.position.y, cylinder.height * 0.5, 0.0001, who + " stands on the floor")
		# Never taller than the model plus a little, never wider than the model's body, never a sliver.
		assert_le(cylinder.height, npc.get_head_height(), who + " body is not taller than the bubble point")
		assert_ge(cylinder.height, (npc.get_head_height() - BUBBLE_LIFT) * 0.75, who + " body covers most of the model")
		assert_ge(cylinder.radius, 0.25, who + " body is not a sliver")
		assert_le(cylinder.radius, 0.6, who + " body does not wall off the room")
		radii[who] = cylinder.radius
	assert_gt(radii["otis"], radii["mox"], "Otis is the widest")
	# The scene's shape is shared by every instance; each NPC must have its own.
	var shapes: Array[Shape3D] = []
	for who: String in CAST:
		var npc: Npc = room.get_node(str(CAST[who]["node"])) as Npc
		var shape: Shape3D = (npc.get_node("Body/CollisionShape3D") as CollisionShape3D).shape
		assert_does_not_have(shapes, shape)
		shapes.append(shape)


func test_room_npcs_still_turn_to_face_red_with_a_model() -> void:
	var room: Node = (load(ROOM_PATH) as PackedScene).instantiate()
	add_to_root(room)
	var otis: Npc = room.get_node("Otis") as Npc
	var toward: Vector3 = Vector3(1.0, 0.0, 0.0)
	otis.face_point(otis.global_position + toward * 3.0)
	for i: int in 120:
		otis.step(1.0 / 60.0)
	assert_gt(otis.get_facing().dot(toward), 0.99, "turns to look at the point")
	otis.release_facing()
	for i: int in 120:
		otis.step(1.0 / 60.0)
	assert_almost_eq(angle_difference(otis.rotation.y, otis.get_rest_yaw()), 0.0, 0.01)
