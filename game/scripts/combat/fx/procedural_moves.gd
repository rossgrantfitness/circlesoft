class_name ProceduralMoves
extends RefCounted
## Clip fallbacks (docs/pivot/combat_api.md section 5): "A missing clip never breaks the game."
##
## When a character model lacks one of the contract clips, `fill_missing()` builds a short Animation from the key
## poses in data/combat/procedural_moves.json and adds it to the model's AnimationPlayer under the clip's own name, so
## gameplay plays it exactly like a real clip. Real clips always win: nothing that exists is replaced. One warning per
## missing clip is pushed, and the list comes back so the debug overlay can show "missing clips".
##
## Bone values in the data are degrees about the model's axes (x positive = the bone's top tips forward), the same
## numbers the Blender clips are written in; they are turned into bone rotations here with the bone's rest pose as the
## starting point. Squash goes on the `root` bone's scale, lift on the `hips`.

const DATA_ID: String = "combat/procedural_moves"
const ROOT_BONE: String = "root"
const HIPS_BONE: String = "hips"
const SQUASH_KEY: String = "squash"
const LIFT_KEY: String = "lift"
const LIBRARY: StringName = &""

## The clips the contract asks for (loop clips first). Optional ones are only built if the model has none of them.
const REQUIRED: PackedStringArray = ["idle", "run", "jump_up", "fall", "land", "dash", "light_1", "light_2", "light_3", "heavy",
		"launcher", "air_1", "air_2", "air_3", "parry", "hurt", "knockdown"]
const OPTIONAL: PackedStringArray = ["walk", "air_dash", "parry_success", "getup"]


## The contract clips a player lacks (required only).
static func missing_clips(player: AnimationPlayer) -> PackedStringArray:
	var missing: PackedStringArray = PackedStringArray()
	for clip: String in REQUIRED:
		if not player.has_animation(clip):
			missing.append(clip)
	return missing


## Adds a fallback Animation for every missing clip (required and optional). Returns the required clips that had to
## be faked. `data` is the parsed procedural_moves.json (default: the shipped file through DataDB).
static func fill_missing(player: AnimationPlayer, skeleton: Skeleton3D, data: Dictionary = {}) -> PackedStringArray:
	var table: Dictionary = data if not data.is_empty() else _shipped()
	var faked: PackedStringArray = PackedStringArray()
	if player == null or skeleton == null or table.is_empty():
		return faked
	var library: AnimationLibrary = player.get_animation_library(LIBRARY)
	if library == null:
		library = AnimationLibrary.new()
		player.add_animation_library(LIBRARY, library)
	var skeleton_path: NodePath = player.get_node(player.root_node).get_path_to(skeleton)
	var wanted: PackedStringArray = REQUIRED + OPTIONAL
	for clip: String in wanted:
		if player.has_animation(clip):
			continue
		var animation: Animation = make_animation(clip, skeleton, skeleton_path, table)
		if animation == null:
			continue
		library.add_animation(clip, animation)
		if REQUIRED.has(clip):
			faked.append(clip)
			push_warning("ProceduralMoves: the model has no '%s' clip; playing a procedural fallback" % clip)
	return faked


## The fallback Animation for a contract clip name, or null if the data has none.
static func make_animation(clip: String, skeleton: Skeleton3D, skeleton_path: NodePath, data: Dictionary) -> Animation:
	var clips: Dictionary = data.get("clips", {})
	if not clips.has(clip):
		return null
	var entry: Dictionary = clips[clip]
	var fallback: Dictionary = (data.get("fallbacks", {}) as Dictionary).get(str(entry.get("fallback", "")), {})
	if fallback.is_empty():
		return null
	var length: float = float(entry.get("length_s", 0.5))
	var keys: Array = fallback.get("keys", [])
	if keys.is_empty():
		return null
	var animation: Animation = Animation.new()
	animation.length = length
	animation.loop_mode = Animation.LOOP_LINEAR if bool(fallback.get("loop", false)) else Animation.LOOP_NONE
	# every bone mentioned by any key gets a rotation track with a key at every key time
	var bones: Dictionary = {}
	for key: Variant in keys:
		for name: Variant in (key as Dictionary):
			if name != "t" and name != SQUASH_KEY and name != LIFT_KEY:
				bones[str(name)] = true
	for bone: String in bones:
		var index: int = skeleton.find_bone(bone)
		if index < 0:
			continue
		var track: int = animation.add_track(Animation.TYPE_ROTATION_3D)
		animation.track_set_path(track, NodePath("%s:%s" % [skeleton_path, bone]))
		for key: Variant in keys:
			var pose: Dictionary = key
			var degrees: Array = pose.get(bone, [0.0, 0.0, 0.0])
			animation.rotation_track_insert_key(track, float(pose["t"]) * length, bone_rotation(skeleton, index, degrees))
	_add_root_tracks(animation, skeleton, skeleton_path, keys, length)
	return animation


## The local bone rotation for a rotation of `degrees` ([x, y, z]) about the model's axes, starting from the bone's rest
## pose: conjugated by the parent's rest rotation so the numbers mean the same thing whatever the bone's orientation.
static func bone_rotation(skeleton: Skeleton3D, bone: int, degrees: Array) -> Quaternion:
	var delta: Basis = Basis.from_euler(Vector3(deg_to_rad(float(degrees[0])), deg_to_rad(float(degrees[1])), deg_to_rad(float(degrees[2]))))
	var rest: Transform3D = skeleton.get_bone_rest(bone)
	var parent: int = skeleton.get_bone_parent(bone)
	var parent_basis: Basis = Basis.IDENTITY
	if parent >= 0:
		parent_basis = skeleton.get_bone_global_rest(parent).basis
	var local_delta: Basis = parent_basis.inverse() * delta * parent_basis
	return (local_delta * rest.basis).get_rotation_quaternion()


static func _add_root_tracks(animation: Animation, skeleton: Skeleton3D, skeleton_path: NodePath, keys: Array, length: float) -> void:
	var root: int = skeleton.find_bone(ROOT_BONE)
	if root >= 0:
		var track: int = animation.add_track(Animation.TYPE_SCALE_3D)
		animation.track_set_path(track, NodePath("%s:%s" % [skeleton_path, ROOT_BONE]))
		for key: Variant in keys:
			var squash: float = float((key as Dictionary).get(SQUASH_KEY, 0.0))
			var tall: float = 1.0 + squash
			var wide: float = 1.0 / sqrt(maxf(tall, 0.1))
			animation.scale_track_insert_key(track, float((key as Dictionary)["t"]) * length, Vector3(wide, tall, wide))
	var hips: int = skeleton.find_bone(HIPS_BONE)
	if hips >= 0:
		var track: int = animation.add_track(Animation.TYPE_POSITION_3D)
		animation.track_set_path(track, NodePath("%s:%s" % [skeleton_path, HIPS_BONE]))
		var rest: Vector3 = skeleton.get_bone_rest(hips).origin
		for key: Variant in keys:
			var lift: float = float((key as Dictionary).get(LIFT_KEY, 0.0))
			animation.position_track_insert_key(track, float((key as Dictionary)["t"]) * length, rest + Vector3(0.0, lift, 0.0))


static func _shipped() -> Dictionary:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var db: Node = tree.root.get_node_or_null("DataDB") if tree != null else null
	return db.call("get_dict", DATA_ID) if db != null else {}
