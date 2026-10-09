extends TestCase
## The slice rigs' animation pipeline (task VS-25): the free Quaternius clips retargeted onto Kasp, the 40 m junk mech and the
## placeholder townsfolk body by scripts/tools/retarget_ual.py (settings in data/animation/retarget_kasp.json, retarget_junk_mech.json,
## retarget_townsfolk.json), the pose keys written into moves.json by scripts/tools/sync_move_keys.py. Checks every step's output:
## the settings and the license note exist, the originals are untouched (no clips, same bones), the bones and mesh nodes of the new
## files, every promised clip is in the file with the right name and loop flag, key data matches the file, the wind-up / strike pairs
## of the mech fit the move data's timing, the mirrored swing is a mirror, sockets follow the hands, and feet stay on the floor.
## The general retarget checks (blade grip, contact = fastest moment) are in test_ual_retarget.gd.

const RIGS: Dictionary = {
	"kasp": {
		"settings": "res://data/animation/retarget_kasp.json",
		"keys": "res://data/animation/kasp_clip_keys.json",
		"credits": "res://art/placeholder/bosses/ANIMATION_CREDITS_bosses.txt",
		"clips": ["idle", "run", "talk", "gesture", "stagger", "knockdown", "getup", "defeated"],
		"extra_bones": [],
		"meshes": ["kasp"],
		"standing": ["idle", "talk"],
		"moving": ["run"],
		"sockets": {"weapon_socket": "hand_r", "prop_socket": "hand_l"},
	},
	"junk_mech": {
		"settings": "res://data/animation/retarget_junk_mech.json",
		"keys": "res://data/animation/junk_mech_clip_keys.json",
		"credits": "res://art/placeholder/bosses/ANIMATION_CREDITS_bosses.txt",
		"clips": ["idle", "walk", "swing_r_windup", "swing_r_strike", "swing_l_windup", "swing_l_strike", "drop_windup", "drop_strike",
				"stomp_windup", "stomp_strike", "barrage_windup", "barrage_strike", "hurt", "stagger", "roar", "knockdown"],
		"extra_bones": ["plate_chest_front_mount", "plate_shoulder_l_mount", "plate_shoulder_r_mount", "plate_back_mount", "cockpit_core_mount", "kasp_seat"],
		"meshes": ["junk_mech_body", "floodlights", "plate_chest_front", "plate_shoulder_l", "plate_shoulder_r", "plate_back", "cockpit_core"],
		"standing": ["idle"],
		"moving": ["walk"],
		"sockets": {"weapon_socket": "hand_r", "prop_socket": "hand_l"},
	},
	"townsfolk": {
		"settings": "res://data/animation/retarget_townsfolk.json",
		"keys": "res://data/animation/townsfolk_clip_keys.json",
		"credits": "res://art/placeholder/characters/townsfolk/ANIMATION_CREDITS_townsfolk.txt",
		"clips": ["idle", "talk", "walk"],
		"extra_bones": [],
		"meshes": ["townsfolk_body", "townsfolk_face"],
		"standing": ["idle", "talk", "walk"],
		"moving": [],
		"sockets": {"weapon_socket": "hand_r", "prop_socket": "hand_l"},
	},
}
const LOOPING: Array[String] = ["idle", "walk", "run", "talk", "stagger"]
const FRAME_S: float = 1.0 / 30.0
const LEAD_IN_S: float = 0.1
const FREE_PACK: String = "UAL"


func _json(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, path + " should exist")
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	assert_true(parsed is Dictionary, path + " should be a JSON object")
	return parsed as Dictionary if parsed is Dictionary else {}


func _model(path: String) -> Node3D:
	var packed: PackedScene = load(path) as PackedScene
	assert_not_null(packed, path + " should import (godot --headless --path game --import)")
	var model: Node3D = packed.instantiate() as Node3D
	add_to_root(model)
	return model


func _player(model: Node) -> AnimationPlayer:
	var found: Array[Node] = model.find_children("*", "AnimationPlayer", true, false)
	return found[0] as AnimationPlayer if not found.is_empty() else null


func _skeleton(model: Node) -> Skeleton3D:
	return model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D


func _output(settings: Dictionary) -> String:
	return "res://" + str(settings["output"])


func _target(settings: Dictionary) -> String:
	return "res://" + str(settings["target"])


func _unit(settings: Dictionary) -> float:
	return float((settings["robot"] as Dictionary)["unit"])


func _set_pose(player: AnimationPlayer, skeleton: Skeleton3D, clip: String, seconds: float) -> void:
	player.play(clip)
	player.seek(seconds, true)
	player.pause()
	skeleton.force_update_all_bone_transforms()


func _bone_origin(skeleton: Skeleton3D, bone: String) -> Vector3:
	return skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin


func test_settings_license_and_source_clips_exist() -> void:
	var sources: Dictionary = {}
	for key: String in ["UAL1_Standard", "UAL2_Standard"]:
		sources[key.substr(0, 4)] = _player(_model("res://art/placeholder/animations/quaternius_ual/%s.glb" % key))
	assert_true(FileAccess.file_exists("res://art/placeholder/animations/quaternius_ual/LICENSE_UAL1.txt"), "the CC0 license of UAL 1 sits with the files")
	assert_true(FileAccess.file_exists("res://art/placeholder/animations/quaternius_ual/LICENSE_UAL2.txt"), "the CC0 license of UAL 2 sits with the files")
	for rig: String in RIGS:
		var spec: Dictionary = RIGS[rig]
		var settings: Dictionary = _json(str(spec["settings"]))
		assert_true(FileAccess.file_exists(_target(settings)), rig + ": the model it starts from")
		assert_true(FileAccess.file_exists(_output(settings)), rig + ": the retargeted file")
		assert_ne(_output(settings), _target(settings), rig + ": the original is never overwritten, the result is a new file beside it")
		assert_true(FileAccess.file_exists(str(spec["credits"])), rig + ": the credits note next to the output")
		if FileAccess.file_exists(str(spec["credits"])):
			var credits: String = FileAccess.get_file_as_string(str(spec["credits"]))
			assert_true(credits.contains("CC0"), rig + ": the note records the license")
			assert_true(credits.contains("Quaternius"), rig + ": the note names the author")
		var seen: Dictionary = {}
		for clip: Dictionary in settings["clips"]:
			var name: String = str(clip["name"])
			assert_false(seen.has(name), rig + ": clip name used once: " + name)
			seen[name] = true
			var used: Array = []
			if clip.has("parts"):
				for part: Dictionary in clip["parts"]:
					used.append(str(part["source"]))
			else:
				used.append(str(clip["source"]))
			for source: String in used:
				var pair: PackedStringArray = source.split(":")
				assert_true(source.begins_with("UAL"), "%s: %s is a clip of the free pack (nothing authored)" % [rig, name])
				var library: AnimationPlayer = sources[pair[0]] as AnimationPlayer
				assert_true(library.has_animation(pair[1]) or library.has_animation(pair[1].trim_suffix("_Loop")), "%s: source clip %s exists in the library" % [rig, source])


func test_the_originals_are_untouched_and_the_new_files_keep_their_bones_and_meshes() -> void:
	for rig: String in RIGS:
		var spec: Dictionary = RIGS[rig]
		var settings: Dictionary = _json(str(spec["settings"]))
		var original: Node3D = _model(_target(settings))
		var original_player: AnimationPlayer = _player(original)
		assert_true(original_player == null or original_player.get_animation_list().is_empty(), rig + ": the original file has no clips (they live in the new file)")
		var model: Node3D = _model(_output(settings))
		var old_skeleton: Skeleton3D = _skeleton(original)
		var new_skeleton: Skeleton3D = _skeleton(model)
		assert_eq(new_skeleton.get_bone_count(), old_skeleton.get_bone_count(), rig + ": same bone count")
		for index: int in old_skeleton.get_bone_count():
			var name: String = old_skeleton.get_bone_name(index)
			var found: int = new_skeleton.find_bone(name)
			assert_ge(found, 0, "%s: bone %s kept" % [rig, name])
			if found < 0:
				continue
			var new_parent: int = new_skeleton.get_bone_parent(found)
			var old_parent: int = old_skeleton.get_bone_parent(index)
			assert_eq(new_skeleton.get_bone_name(new_parent) if new_parent >= 0 else "", old_skeleton.get_bone_name(old_parent) if old_parent >= 0 else "", "%s: %s keeps its parent" % [rig, name])
		for bone: String in ["hips", "head", "upper_arm_r", "hand_l", "hand_r", "foot_l", "foot_r", "weapon_socket", "prop_socket"]:
			assert_ge(new_skeleton.find_bone(bone), 0, "%s: the bone game code reads by name: %s" % [rig, bone])
		for bone: String in spec["extra_bones"]:
			assert_ge(new_skeleton.find_bone(bone), 0, "%s: the extra bone %s is kept" % [rig, bone])
		for mesh_name: String in spec["meshes"]:
			var node: Node = model.find_child(mesh_name, true, false)
			assert_true(node is MeshInstance3D, "%s: mesh node %s is still its own node (separable parts)" % [rig, mesh_name])


func test_every_promised_clip_is_in_the_file_with_the_right_loop_flag() -> void:
	for rig: String in RIGS:
		var spec: Dictionary = RIGS[rig]
		var settings: Dictionary = _json(str(spec["settings"]))
		var player: AnimationPlayer = _player(_model(_output(settings)))
		assert_not_null(player, rig + ": the file has an AnimationPlayer")
		var promised: Array = spec["clips"]
		var in_settings: Array = []
		for clip: Dictionary in settings["clips"]:
			in_settings.append(str(clip["name"]))
			var expected: bool = bool(clip.get("loop", false)) or ["stagger"].has(str(clip["name"]))
			if player.has_animation(str(clip["name"])):
				assert_eq(player.get_animation(str(clip["name"])).loop_mode == Animation.LOOP_LINEAR, expected, "%s: %s loop flag" % [rig, clip["name"]])
		for clip: String in promised:
			assert_true(in_settings.has(clip), "%s: %s is in the settings" % [rig, clip])
			assert_true(player.has_animation(clip), "%s: clip %s is in the file" % [rig, clip])
			if player.has_animation(clip):
				var animation: Animation = player.get_animation(clip)
				assert_gt(animation.length, 0.2, "%s: %s is not a single pose" % [rig, clip])
				assert_ge(animation.get_track_count(), 8, "%s: %s animates the body" % [rig, clip])
		for clip: String in player.get_animation_list():
			assert_true(promised.has(clip), "%s: no clip in the file that the test does not name (%s)" % [rig, clip])
		for clip: String in LOOPING:
			if player.has_animation(clip):
				assert_eq(player.get_animation(clip).loop_mode, Animation.LOOP_LINEAR, "%s: %s loops" % [rig, clip])


func test_key_data_matches_the_file_and_the_pairs_are_linked() -> void:
	for rig: String in RIGS:
		var spec: Dictionary = RIGS[rig]
		var settings: Dictionary = _json(str(spec["settings"]))
		var clips: Dictionary = _json(str(spec["keys"])).get("clips", {})
		var player: AnimationPlayer = _player(_model(_output(settings)))
		for clip: String in player.get_animation_list():
			assert_true(clips.has(clip), "%s: key data for %s" % [rig, clip])
			if not clips.has(clip):
				continue
			var entry: Dictionary = clips[clip]
			assert_almost_eq(float(entry["length_s"]), player.get_animation(clip).length, 0.04, "%s: %s length matches the file" % [rig, clip])
			assert_eq(bool(entry["loop"]), player.get_animation(clip).loop_mode == Animation.LOOP_LINEAR, "%s: %s loop matches the file" % [rig, clip])
			assert_true(str(entry["source"]).contains(FREE_PACK), "%s: %s comes from the free pack" % [rig, clip])
			var last: float = -1.0
			for key: Dictionary in entry["keys"]:
				assert_gt(float(key["clip_s"]), last - 0.0001, "%s: %s keys are in order" % [rig, clip])
				assert_le(float(key["clip_s"]), float(entry["length_s"]) + 0.001, "%s: %s keys stay inside the clip" % [rig, clip])
				last = float(key["clip_s"])
			if entry.has("strike"):
				assert_true(clips.has(str(entry["strike"])), "%s: %s names a strike clip that exists" % [rig, clip])
				assert_true((clips[str(entry["strike"])] as Dictionary).has("contact_s"), "%s: the strike clip of %s has a contact frame" % [rig, clip])
			if entry.has("contact_s"):
				assert_gt(float(entry["contact_s"]), 0.05, "%s: %s has a lead-in before the contact" % [rig, clip])
				assert_lt(float(entry["contact_s"]), float(entry["length_s"]) - 0.1, "%s: %s has a follow-through after the contact" % [rig, clip])
		for clip: String in ["walk", "run"]:
			if clips.has(clip):
				assert_gt(float((clips[clip] as Dictionary).get("stride_mps", 0.0)), 0.0, "%s: %s has a stride (foot-slide fix, scripts/combat/locomotion_speed.gd)" % [rig, clip])


func test_playback_look_comes_from_the_data_file_and_loops_close() -> void:
	var look: Dictionary = _json("res://data/animation/import_look.json")
	var wanted: int = Animation.INTERPOLATION_NEAREST if str(look.get("interpolation", "linear")) == "nearest" else Animation.INTERPOLATION_LINEAR
	for rig: String in RIGS:
		var settings: Dictionary = _json(str(RIGS[rig]["settings"]))
		var player: AnimationPlayer = _player(_model(_output(settings)))
		for clip: String in player.get_animation_list():
			var animation: Animation = player.get_animation(clip)
			for track: int in animation.get_track_count():
				assert_eq(animation.track_get_interpolation_type(track), wanted, "%s: %s track %d playback look" % [rig, clip, track])
				if animation.track_get_interpolation_type(track) != wanted:
					break
		for spec: Dictionary in settings["clips"]:
			if not bool(spec.get("loop", false)):
				continue
			var animation: Animation = player.get_animation(str(spec["name"]))
			for track: int in animation.get_track_count():
				if animation.track_get_type(track) != Animation.TYPE_ROTATION_3D:
					continue
				var count: int = animation.track_get_key_count(track)
				var first: Quaternion = animation.track_get_key_value(track, 0) as Quaternion
				var last: Quaternion = animation.track_get_key_value(track, count - 1) as Quaternion
				assert_gt(absf(first.dot(last)), 0.9995, "%s: %s closes its loop (track %d)" % [rig, spec["name"], track])


func test_sockets_follow_the_hands_in_every_clip() -> void:
	for rig: String in RIGS:
		var spec: Dictionary = RIGS[rig]
		var settings: Dictionary = _json(str(spec["settings"]))
		var model: Node3D = _model(_output(settings))
		var player: AnimationPlayer = _player(model)
		var skeleton: Skeleton3D = _skeleton(model)
		var tolerance: float = 0.01 * _unit(settings)
		for socket: String in spec["sockets"]:
			var hand: String = str(spec["sockets"][socket])
			var index: int = skeleton.find_bone(socket)
			assert_ge(index, 0, "%s: the socket %s exists" % [rig, socket])
			assert_eq(skeleton.get_bone_name(skeleton.get_bone_parent(index)), hand, "%s: %s hangs from %s" % [rig, socket, hand])
			var rest_distance: float = skeleton.get_bone_global_rest(index).origin.distance_to(skeleton.get_bone_global_rest(skeleton.find_bone(hand)).origin)
			for clip: String in player.get_animation_list():
				var length: float = player.get_animation(clip).length
				for fraction: float in [0.0, 0.3, 0.6, 1.0]:
					_set_pose(player, skeleton, clip, length * fraction)
					assert_almost_eq(_bone_origin(skeleton, socket).distance_to(_bone_origin(skeleton, hand)), rest_distance, tolerance, "%s: %s at %.0f%%: %s stays on the hand" % [rig, clip, fraction * 100.0, socket])


func _lowest_sole(skeleton: Skeleton3D, soles: Array) -> float:
	var lowest: float = INF
	for pair: Array in soles:
		var bone: int = skeleton.find_bone(str(pair[0]))
		var local: Vector3 = skeleton.get_bone_global_rest(bone).basis.inverse() * (pair[1] as Vector3)
		var pose: Transform3D = skeleton.get_bone_global_pose(bone)
		lowest = minf(lowest, (pose.origin + pose.basis * local).y)
	return lowest


func test_feet_stay_on_the_floor_in_standing_and_moving_clips() -> void:
	for rig: String in RIGS:
		var spec: Dictionary = RIGS[rig]
		var settings: Dictionary = _json(str(spec["settings"]))
		var unit: float = _unit(settings)
		var soles: Array = []
		for point: Dictionary in (settings["ground"] as Dictionary)["target_points"]:
			if float(point.get("lift", 0.0)) == 0.0:
				var offset: Array = point["offset"]
				soles.append([point["bone"], Vector3(float(offset[0]), float(offset[1]), float(offset[2]))])
		assert_eq(soles.size(), 4, rig + ": heel and toe of both feet")
		var model: Node3D = _model(_output(settings))
		var player: AnimationPlayer = _player(model)
		var skeleton: Skeleton3D = _skeleton(model)
		for clip: String in spec["standing"]:
			var length: float = player.get_animation(clip).length
			for step: int in 12:
				_set_pose(player, skeleton, clip, length * float(step) / 12.0)
				assert_almost_eq(_lowest_sole(skeleton, soles), 0.0, 0.02 * unit, "%s: %s frame %d: a foot is on the floor" % [rig, clip, step])
		for clip: String in spec["moving"]:
			var length: float = player.get_animation(clip).length
			for step: int in 12:
				_set_pose(player, skeleton, clip, length * float(step) / 12.0)
				var low: float = _lowest_sole(skeleton, soles)
				assert_ge(low, -0.03 * unit, "%s: %s frame %d: nothing sinks into the floor" % [rig, clip, step])
				assert_le(low, 0.12 * unit, "%s: %s frame %d: the flight phase stays low" % [rig, clip, step])


func test_the_mech_never_goes_under_the_floor_when_it_falls_or_holds_a_stomp() -> void:
	var settings: Dictionary = _json(str(RIGS["junk_mech"]["settings"]))
	var unit: float = _unit(settings)
	var model: Node3D = _model(_output(settings))
	var player: AnimationPlayer = _player(model)
	var skeleton: Skeleton3D = _skeleton(model)
	var points: Array = (settings["ground"] as Dictionary)["target_points"]
	for clip: String in ["knockdown", "stomp_strike", "drop_strike", "barrage_strike"]:
		var length: float = player.get_animation(clip).length
		for fraction: float in [0.25, 0.5, 0.75, 1.0]:
			_set_pose(player, skeleton, clip, length * fraction)
			var lowest: float = INF
			for point: Dictionary in points:
				var bone: int = skeleton.find_bone(str(point["bone"]))
				var offset: Array = point["offset"]
				var local: Vector3 = skeleton.get_bone_global_rest(bone).basis.inverse() * Vector3(float(offset[0]), float(offset[1]), float(offset[2]))
				var pose: Transform3D = skeleton.get_bone_global_pose(bone)
				lowest = minf(lowest, (pose.origin + pose.basis * local).y - float(point.get("lift", 0.0)))
			assert_ge(lowest, -0.03 * unit, "%s at %.0f%%: no point of the body is under the floor" % [clip, fraction * 100.0])


func test_the_mirrored_swing_is_a_mirror_of_the_right_arm_swing() -> void:
	var settings: Dictionary = _json(str(RIGS["junk_mech"]["settings"]))
	var unit: float = _unit(settings)
	var model: Node3D = _model(_output(settings))
	var player: AnimationPlayer = _player(model)
	var skeleton: Skeleton3D = _skeleton(model)
	for pair: Array in [["swing_r_windup", "swing_l_windup"], ["swing_r_strike", "swing_l_strike"]]:
		var length: float = player.get_animation(str(pair[0])).length
		assert_almost_eq(player.get_animation(str(pair[1])).length, length, FRAME_S, "%s and %s are equally long" % pair)
		for fraction: float in [0.1, 0.3, 0.5, 0.7, 0.9]:
			_set_pose(player, skeleton, str(pair[0]), length * fraction)
			var right_hand: Vector3 = _bone_origin(skeleton, "hand_r")
			var left_foot: Vector3 = _bone_origin(skeleton, "foot_l")
			_set_pose(player, skeleton, str(pair[1]), length * fraction)
			var mirrored: Vector3 = _bone_origin(skeleton, "hand_l")
			assert_almost_eq(mirrored.x, -right_hand.x, 0.03 * unit, "%s at %.0f%%: the left hand is the right hand mirrored (x)" % [pair[1], fraction * 100.0])
			assert_almost_eq(mirrored.y, right_hand.y, 0.03 * unit, "%s at %.0f%%: same height" % [pair[1], fraction * 100.0])
			assert_almost_eq(mirrored.z, right_hand.z, 0.03 * unit, "%s at %.0f%%: same depth" % [pair[1], fraction * 100.0])
			assert_almost_eq(_bone_origin(skeleton, "foot_r").x, -left_foot.x, 0.03 * unit, "%s: the feet swap sides" % pair[1])
	# and the arms sweep the way the move data's hitboxes do: the right arm from its own side across to the left, the left arm back
	_set_pose(player, skeleton, "swing_r_strike", 0.1)
	var r_start: float = _bone_origin(skeleton, "hand_r").x
	_set_pose(player, skeleton, "swing_r_strike", 1.0)
	assert_gt(_bone_origin(skeleton, "hand_r").x - r_start, 0.15 * unit, "Scrap Swing (right arm) sweeps toward the left (+X) during the 0.9 s of the hitboxes")
	_set_pose(player, skeleton, "swing_l_strike", 0.1)
	var l_start: float = _bone_origin(skeleton, "hand_l").x
	_set_pose(player, skeleton, "swing_l_strike", 1.0)
	assert_gt(l_start - _bone_origin(skeleton, "hand_l").x, 0.15 * unit, "Scrap Swing (left arm) sweeps toward the right (-X)")


func test_the_mech_walk_strides_at_the_speed_the_move_data_gives_it() -> void:
	var moves: Dictionary = (_json("res://data/combat/moves.json").get("sets", {}) as Dictionary)["junk_mech"]["moves"]
	var clips: Dictionary = _json(str(RIGS["junk_mech"]["keys"])).get("clips", {})
	var speed: float = float((moves["walk"] as Dictionary)["speed_mps"])
	assert_almost_eq(float((clips["walk"] as Dictionary)["stride_mps"]), speed, 1.0, "the walk clip is baked to stride at the walk speed (no sliding at playback scale 1)")


func test_move_data_pose_keys_fit_the_mech_clips_and_the_strike_lands_on_the_data_timed_hit() -> void:
	var moves: Dictionary = (_json("res://data/combat/moves.json").get("sets", {}) as Dictionary)["junk_mech"]["moves"]
	var settings: Dictionary = _json(str(RIGS["junk_mech"]["settings"]))
	var clips: Dictionary = _json(str(RIGS["junk_mech"]["keys"])).get("clips", {})
	var player: AnimationPlayer = _player(_model(_output(settings)))
	var attacks: Array[String] = ["scrap_swing_l", "scrap_swing_r", "wrecking_drop", "stomp_march", "scrap_barrage"]
	for move_id: String in moves:
		var move: Dictionary = moves[move_id]
		var anim: Dictionary = move.get("anim", {})
		var clip: String = str(anim.get("clip", ""))
		assert_true(player.has_animation(clip), "%s: its clip %s is in the file" % [move_id, clip])
		var keys: Array = anim.get("keys", [])
		var last_ms: int = -1
		for key: Dictionary in keys:
			assert_gt(int(key["at_ms"]), last_ms, "%s: keys in time order" % move_id)
			last_ms = int(key["at_ms"])
			var key_clip: String = str(key.get("clip", clip))
			assert_true(player.has_animation(key_clip), "%s: key clip %s is in the file" % [move_id, key_clip])
			assert_le(float(key["clip_s"]), float((clips[key_clip] as Dictionary)["length_s"]) + 0.001, "%s: key at %d ms stays inside %s" % [move_id, int(key["at_ms"]), key_clip])
		if not attacks.has(move_id):
			# the reactions have no keys: the game stretches the clip over the move, so the clip is cut to the move's length
			if keys.is_empty() and str(move.get("kind", "")) == "reaction":
				var total_s: float = (float(move["startup_ms"]) + float(move["active_ms"]) + float(move["recovery_ms"])) / 1000.0
				var length: float = float((clips[clip] as Dictionary)["length_s"])
				assert_almost_eq(length / total_s, 1.0, 0.12, "%s: %s fits the move's %.1f s (stretch stays near 1)" % [move_id, clip, total_s])
			continue
		var wind: Dictionary = clips[clip]
		var strike_name: String = str(wind["strike"])
		var strike: Dictionary = clips[strike_name]
		var impact: int = int(move.get("impact_ms", move["startup_ms"]))
		var total: int = int(move["startup_ms"]) + int(move["active_ms"]) + int(move["recovery_ms"])
		assert_eq(int(keys[0]["at_ms"]), 0, "%s: the first key is at 0" % move_id)
		assert_eq(str(keys[0]["clip"]), clip, "%s: the wind-up plays first" % move_id)
		var hit_key: Dictionary = {}
		for key: Dictionary in keys:
			if int(key["at_ms"]) == impact:
				hit_key = key
		assert_false(hit_key.is_empty(), "%s: a key at the hit time" % move_id)
		assert_eq(str(hit_key.get("clip", "")), strike_name, "%s: the strike clip plays at the hit" % move_id)
		assert_almost_eq(float(hit_key.get("clip_s", -1.0)), float(strike["contact_s"]), FRAME_S, "%s: the key at the hit snaps %s to its contact frame" % [move_id, strike_name])
		# the wind-up clip covers the time before the strike takes over, the strike clip the rest of the move
		assert_ge(float(wind["length_s"]), float(impact) / 1000.0 - LEAD_IN_S - 0.05, "%s: %s is as long as the move's wind-up" % [move_id, clip])
		assert_ge(float(strike["length_s"]), float(strike["contact_s"]) + float(total - impact) / 1000.0 - 0.1, "%s: %s lasts the active frames and the recovery" % [move_id, strike_name])
	assert_eq(attacks.size(), 5, "the junk mech has five attack moves (Scrap Swing both arms, Wrecking Drop, Stomp March, Scrap Barrage)")


func test_the_second_and_third_strikes_of_a_clip_fall_where_the_hitboxes_do() -> void:
	var moves: Dictionary = (_json("res://data/combat/moves.json").get("sets", {}) as Dictionary)["junk_mech"]["moves"]
	var clips: Dictionary = _json(str(RIGS["junk_mech"]["keys"])).get("clips", {})
	# Stomp March: the left foot lands where the second box and ring start (2700 ms) = one second after the first stomp
	var stomp: Dictionary = moves["stomp_march"]
	var second_stomp: float = 0.0
	for box: Dictionary in stomp["hitboxes"]:
		if str(box.get("origin", "")) == "mech_foot_l" and str(box["shape"]) == "box":
			second_stomp = float(box["from_ms"]) / 1000.0
	var stomp_clip: Dictionary = clips["stomp_strike"]
	var offset: float = float((stomp_clip["extra_contacts_s"] as Array)[0]) - float(stomp_clip["contact_s"])
	assert_almost_eq(offset, second_stomp - float(stomp["impact_ms"]) / 1000.0, 0.1, "the left foot of the clip lands with the second stomp of the move")
	# Scrap Barrage: three lobs 0.6 s apart (the landing circles lock 0.6 s apart)
	var barrage: Dictionary = moves["scrap_barrage"]
	var locks: Array = []
	for target: Dictionary in barrage["targets"]:
		locks.append(float(target["lock_ms"]) / 1000.0)
	var extra: Array = (clips["barrage_strike"] as Dictionary)["extra_contacts_s"]
	assert_eq(extra.size(), 2, "the barrage clip has two more throws")
	for index: int in 2:
		assert_almost_eq(float(extra[index]) - float(clips["barrage_strike"]["contact_s"]), (index + 1) * (float(locks[1]) - float(locks[0])), 0.1, "throw %d is %.1f s after the first" % [index + 2, (index + 1) * 0.6])


func test_the_townsfolk_face_is_a_separate_plate_with_its_own_material() -> void:
	var model: Node3D = _model("res://art/placeholder/characters/townsfolk/townsfolk_blockout_ual.glb")
	var face: MeshInstance3D = model.find_child("townsfolk_face", true, false) as MeshInstance3D
	var body: MeshInstance3D = model.find_child("townsfolk_body", true, false) as MeshInstance3D
	assert_not_null(face, "the face plate is its own mesh node (swappable faces, later)")
	assert_not_null(body, "the body is its own mesh node")
	if face == null or body == null:
		return
	var face_materials: Array[String] = []
	for surface: int in face.mesh.get_surface_count():
		face_materials.append(face.mesh.surface_get_material(surface).resource_name)
	for surface: int in body.mesh.get_surface_count():
		assert_false(face_materials.has(body.mesh.surface_get_material(surface).resource_name), "the body does not share a material with the face plate")
	assert_eq(face.skin == null, false, "the face plate is skinned to the same skeleton, so it follows the head")
	var skeleton: Skeleton3D = _skeleton(model)
	var player: AnimationPlayer = _player(model)
	var head_before: Vector3 = Vector3.ZERO
	_set_pose(player, skeleton, "talk", 0.2)
	head_before = _bone_origin(skeleton, "head")
	_set_pose(player, skeleton, "talk", 1.4)
	assert_gt(_bone_origin(skeleton, "head").distance_to(head_before), 0.001, "the head moves while talking, and the face plate with it")
