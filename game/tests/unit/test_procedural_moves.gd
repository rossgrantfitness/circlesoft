extends TestCase
## ProceduralMoves (scripts/combat/fx/procedural_moves.gd): a missing clip never breaks the game.

const WOLF: String = "res://art/final/enemies/cyberwolf_sentinel_rigged.glb"
const RED: String = "res://art/final/characters/red/red_ross_v1_rigged.glb"


func _model(path: String) -> Node3D:
	var model: Node3D = (load(path) as PackedScene).instantiate() as Node3D
	add_to_root(model)
	return model


func _parts(model: Node3D) -> Array:
	return [model.find_children("*", "AnimationPlayer", true, false)[0], model.find_children("*", "Skeleton3D", true, false)[0]]


func test_data_covers_every_contract_clip_with_a_known_fallback() -> void:
	var data: Dictionary = DataDB.get_dict(ProceduralMoves.DATA_ID)
	assert_false(data.is_empty(), "data/combat/procedural_moves.json")
	for clip: String in ProceduralMoves.REQUIRED + ProceduralMoves.OPTIONAL:
		var entry: Dictionary = data["clips"][clip]
		assert_true(data["fallbacks"].has(entry["fallback"]), "%s -> %s" % [clip, entry["fallback"]])
		assert_gt(float(entry["length_s"]), 0.1)


func test_a_model_that_has_every_clip_is_left_alone() -> void:
	var parts: Array = _parts(_model(RED))
	var player: AnimationPlayer = parts[0]
	var before: int = player.get_animation_list().size()
	assert_eq(ProceduralMoves.fill_missing(player, parts[1]).size(), 0)
	assert_eq(player.get_animation_list().size(), before, "real clips always win and nothing is added")
	assert_eq(ProceduralMoves.missing_clips(player).size(), 0)


func test_missing_clips_get_a_playable_fallback_under_their_own_name() -> void:
	var parts: Array = _parts(_model(WOLF))
	var player: AnimationPlayer = parts[0]
	var skeleton: Skeleton3D = parts[1]
	var lacking: PackedStringArray = ProceduralMoves.missing_clips(player)
	assert_gt(lacking.size(), 8, "the wolf has no Red clips")
	var wolf_idle_length: float = player.get_animation("idle").length
	var faked: PackedStringArray = ProceduralMoves.fill_missing(player, skeleton)
	assert_eq(faked, lacking)
	assert_eq(player.get_animation("idle").length, wolf_idle_length, "its own idle is untouched")
	for clip: String in lacking:
		assert_true(player.has_animation(clip), clip)
		var animation: Animation = player.get_animation(clip)
		assert_gt(animation.get_track_count(), 1, clip + " moves bones")
		assert_gt(animation.length, 0.1)
	assert_eq(player.get_animation("run").loop_mode, Animation.LOOP_LINEAR, "run loops")
	assert_eq(player.get_animation("light_1").loop_mode, Animation.LOOP_NONE)
	# it really plays: the arm is somewhere else at the strike than at the start
	var arm: int = skeleton.find_bone("upper_arm_r")
	player.play("light_1")
	player.seek(0.0, true)
	player.pause()
	skeleton.force_update_all_bone_transforms()
	var start: Basis = skeleton.get_bone_pose(arm).basis
	player.seek(0.15, true)
	skeleton.force_update_all_bone_transforms()
	assert_false(start.is_equal_approx(skeleton.get_bone_pose(arm).basis), "the swing moves the right arm")
