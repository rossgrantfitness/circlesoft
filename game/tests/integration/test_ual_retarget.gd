extends TestCase
## The animation pipeline (scripts/tools/retarget_ual.py + sync_move_keys.py): the free Quaternius clips retargeted onto
## Red, the Cyberwolf Sentinel and the Brute blockout, baked onto OUR bone names. Checks every step's output: the settings and
## the license note exist, bones are the same as the rig they came from, every clip in the settings is in the file with
## the right name and loop flag, every clip has key data with a contact frame where a hit lands, the move data's pose
## keys put that contact on the data-timed hit, loops close, sockets follow the hands, and feet stay on the floor.

const RIGS: Dictionary = {
	"red": {
		"settings": "res://data/animation/retarget_red.json",
		"keys": "res://data/combat/red_clip_keys.json",
		"set": "red",
		"credits": "res://art/final/characters/red/ANIMATION_CREDITS_red_ross_v1_rigged_ual.glb.txt",
		"hand": "hand_r",
		"socket": "weapon_socket",
		"strikes": ["light_1", "light_2", "light_3", "heavy", "launcher"],
		"casts": ["hack_zap", "hack_emp", "hack_overclock", "hack_reboot"],
	},
	"wolf": {
		"settings": "res://data/animation/retarget_wolf.json",
		"keys": "res://data/combat/wolf_clip_keys.json",
		"set": "grunt",
		"credits": "res://art/final/enemies/ANIMATION_CREDITS_cyberwolf_sentinel_rigged_ual.glb.txt",
		"hand": "hand_r",
		"socket": "weapon_socket",
		"strikes": ["attack_swing"],
	},
	"brute": {
		"settings": "res://data/animation/retarget_brute.json",
		"keys": "res://data/combat/brute_clip_keys.json",
		"set": "brute",
		"credits": "res://art/placeholder/enemies/sandbox_brute/ANIMATION_CREDITS_enm_sandbox_brute_ual.glb.txt",
		"hand": "forearm_r",
		"socket": "weapon_socket",
		"strikes": ["attack_swing"],
	},
}
## Names the project's scene importer (scripts/tools/psx_post_import.gd) loops whatever the file says.
const IMPORTER_LOOPS: Array[String] = ["idle", "walk", "run", "fall", "battle_ready", "climb", "launched", "stagger"]
const FRAME_S: float = 1.0 / 30.0
const CLIPS_FROM_THE_FREE_PACK: String = "UAL"


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
	return model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer


func _skeleton(model: Node) -> Skeleton3D:
	return model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D


func _output(settings: Dictionary) -> String:
	return "res://" + str(settings["output"])


## Clip names the settings promise (the ones the game asks for), with their loop flags.
func _promised(settings: Dictionary, standins: Array) -> Dictionary:
	var out: Dictionary = {}
	for spec: Dictionary in settings["clips"]:
		out[str(spec["name"])] = bool(spec.get("loop", false)) or IMPORTER_LOOPS.has(str(spec["name"]))
	for clip: Variant in standins:
		out[str(clip)] = IMPORTER_LOOPS.has(str(clip))
	return out


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
		var path: String = "res://art/placeholder/animations/quaternius_ual/%s.glb" % key
		var library: Node3D = _model(path)
		sources[key.substr(0, 4)] = _player(library)
	assert_true(FileAccess.file_exists("res://art/placeholder/animations/quaternius_ual/LICENSE_UAL1.txt"), "the CC0 license of UAL 1 sits with the files")
	assert_true(FileAccess.file_exists("res://art/placeholder/animations/quaternius_ual/LICENSE_UAL2.txt"), "the CC0 license of UAL 2 sits with the files")
	for rig: String in RIGS:
		var spec: Dictionary = RIGS[rig]
		var settings: Dictionary = _json(str(spec["settings"]))
		assert_true(FileAccess.file_exists("res://" + str(settings["target"])), rig + ": the rigged copy it starts from")
		assert_true(FileAccess.file_exists(_output(settings)), rig + ": the retargeted file")
		assert_true(FileAccess.file_exists(str(spec["credits"])), rig + ": the credits note next to the output")
		if FileAccess.file_exists(str(spec["credits"])):
			assert_true(FileAccess.get_file_as_string(str(spec["credits"])).contains("CC0"), rig + ": the note records the license")
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
				# Godot's importer turns a trailing "_Loop" into a loop flag and drops the suffix from the clip name
				var library: AnimationPlayer = sources[pair[0]] as AnimationPlayer
				assert_true(library.has_animation(pair[1]) or library.has_animation(pair[1].trim_suffix("_Loop")), "%s: source clip %s exists in the library" % [rig, source])


func test_every_promised_clip_is_in_the_file_with_the_right_loop_flag() -> void:
	for rig: String in RIGS:
		var settings: Dictionary = _json(str(RIGS[rig]["settings"]))
		var player: AnimationPlayer = _player(_model(_output(settings)))
		var promised: Dictionary = _promised(settings, settings.get("keep_standins", []))
		for clip: String in promised:
			assert_true(player.has_animation(clip), "%s: clip %s" % [rig, clip])
			if player.has_animation(clip):
				var animation: Animation = player.get_animation(clip)
				assert_eq(animation.loop_mode == Animation.LOOP_LINEAR, bool(promised[clip]), "%s: %s loop flag" % [rig, clip])
				assert_gt(animation.length, 0.2, "%s: %s is not a single pose" % [rig, clip])
				assert_ge(animation.get_track_count(), 8, "%s: %s animates the body" % [rig, clip])
		for clip: String in player.get_animation_list():
			assert_true(promised.has(clip), "%s: no clip in the file that the settings do not name (%s)" % [rig, clip])


func test_bone_names_are_the_rigs_own_so_game_code_is_untouched() -> void:
	var originals: Dictionary = {
		"red": "res://art/final/characters/red/red_ross_v1_rigged.glb",
		"wolf": "res://art/final/enemies/cyberwolf_sentinel_rigged.glb",
		"brute": "res://art/placeholder/enemies/sandbox_brute/enm_sandbox_brute.glb",
	}
	for rig: String in RIGS:
		var settings: Dictionary = _json(str(RIGS[rig]["settings"]))
		var new_skeleton: Skeleton3D = _skeleton(_model(_output(settings)))
		var old_skeleton: Skeleton3D = _skeleton(_model(str(originals[rig])))
		assert_eq(new_skeleton.get_bone_count(), old_skeleton.get_bone_count(), rig + ": same bone count")
		for index: int in old_skeleton.get_bone_count():
			var name: String = old_skeleton.get_bone_name(index)
			assert_ge(new_skeleton.find_bone(name), 0, "%s: bone %s kept" % [rig, name])
			var new_parent: int = new_skeleton.get_bone_parent(new_skeleton.find_bone(name))
			var old_parent: int = old_skeleton.get_bone_parent(index)
			assert_eq(new_skeleton.get_bone_name(new_parent) if new_parent >= 0 else "", old_skeleton.get_bone_name(old_parent) if old_parent >= 0 else "", "%s: %s keeps its parent" % [rig, name])
		for bone: String in ["head", "upper_arm_r", "weapon_socket"]:
			assert_ge(new_skeleton.find_bone(bone), 0, "%s: the bone game code reads by name: %s" % [rig, bone])


func test_every_clip_has_key_data_and_the_striking_ones_have_a_contact_frame() -> void:
	for rig: String in RIGS:
		var spec: Dictionary = RIGS[rig]
		var settings: Dictionary = _json(str(spec["settings"]))
		var data: Dictionary = _json(str(spec["keys"]))
		var clips: Dictionary = data.get("clips", {})
		var player: AnimationPlayer = _player(_model(_output(settings)))
		for clip: String in player.get_animation_list():
			assert_true(clips.has(clip), "%s: key data for %s" % [rig, clip])
			if not clips.has(clip):
				continue
			var entry: Dictionary = clips[clip]
			assert_almost_eq(float(entry["length_s"]), player.get_animation(clip).length, 0.04, "%s: %s length matches the file" % [rig, clip])
			assert_eq(bool(entry["loop"]), player.get_animation(clip).loop_mode == Animation.LOOP_LINEAR, "%s: %s loop matches the file" % [rig, clip])
			var last: float = -1.0
			for key: Dictionary in entry["keys"]:
				assert_gt(float(key["clip_s"]), last - 0.0001, "%s: %s keys are in order" % [rig, clip])
				assert_le(float(key["clip_s"]), float(entry["length_s"]) + 0.001, "%s: %s keys stay inside the clip" % [rig, clip])
				last = float(key["clip_s"])
		for clip: String in spec["strikes"]:
			var entry: Dictionary = clips[clip]
			assert_true(entry.has("contact_s"), "%s: %s has a contact frame" % [rig, clip])
			assert_true(entry.has("contact_frame"), "%s: %s has a contact frame number" % [rig, clip])
			assert_gt(float(entry["contact_s"]), 0.05, "%s: %s has a wind-up before the contact" % [rig, clip])
			assert_lt(float(entry["contact_s"]), float(entry["length_s"]) - 0.1, "%s: %s has a follow-through after the contact" % [rig, clip])
			assert_true(str(entry["source"]).contains(CLIPS_FROM_THE_FREE_PACK), "%s: %s comes from the free pack" % [rig, clip])


func test_hack_casts_come_from_the_free_pack_with_a_release_frame_and_license() -> void:
	# VS-10: Red's four hack clips are existing CC0 clips (no new authoring); the release frame is the contact_s the cast move snaps to
	var spec: Dictionary = RIGS["red"]
	var settings: Dictionary = _json(str(spec["settings"]))
	var clips: Dictionary = _json(str(spec["keys"])).get("clips", {})
	var model: Node3D = _model(_output(settings))
	var player: AnimationPlayer = _player(model)
	var credits: String = FileAccess.get_file_as_string(str(spec["credits"]))
	for source: String in ["Spell_Simple_Enter", "NinjaJump_Land", "Consume", "LayToIdle"]:
		assert_true(credits.contains(source), "the credits file names the hack source clip " + source)
	var specs: Dictionary = {}
	for clip: Dictionary in settings["clips"]:
		specs[str(clip["name"])] = clip
	for cast: String in spec["casts"]:
		assert_true(specs.has(cast), cast + " is in the retarget settings")
		assert_true(player.has_animation(cast), cast + " is in the retargeted file")
		assert_true(clips.has(cast), cast + " has key data")
		assert_true(str(clips[cast]["source"]).contains(CLIPS_FROM_THE_FREE_PACK), cast + " comes from the free pack")
		assert_true(clips[cast].has("contact_s"), cast + " has a release frame")
		assert_false(bool(clips[cast]["loop"]), cast + " plays once")


func test_the_contact_frame_is_where_the_blade_is_fastest() -> void:
	# the contact times were found on the source clips by the peak speed of the blade tip; after retargeting the same moment must
	# still be the fastest one of the swing (so the hit lands on the real strike, not on the wind-up)
	for rig: String in ["red", "wolf"]:
		var spec: Dictionary = RIGS[rig]
		var settings: Dictionary = _json(str(spec["settings"]))
		var clips: Dictionary = _json(str(spec["keys"])).get("clips", {})
		var model: Node3D = _model(_output(settings))
		var player: AnimationPlayer = _player(model)
		var skeleton: Skeleton3D = _skeleton(model)
		var socket: int = skeleton.find_bone(str(spec["socket"]))
		for clip: String in spec["strikes"]:
			var contact: float = float(clips[clip]["contact_s"])
			var length: float = player.get_animation(clip).length
			var previous: Vector3 = Vector3.ZERO
			var best: float = 0.0
			var best_at: float = 0.0
			var time: float = 0.0
			var first: bool = true
			while time <= length + 0.0001:
				_set_pose(player, skeleton, clip, minf(time, length))
				var pose: Transform3D = skeleton.get_bone_global_pose(socket)
				var tip: Vector3 = pose.origin + pose.basis.y * 0.5
				if not first:
					var speed: float = tip.distance_to(previous) / FRAME_S
					if speed > best:
						best = speed
						best_at = time - FRAME_S * 0.5
				previous = tip
				first = false
				time += FRAME_S
			assert_almost_eq(best_at, contact, FRAME_S * 3.0, "%s: %s contact %.3f s is at the blade's fastest moment (%.3f s)" % [rig, clip, contact, best_at])


func test_move_data_pose_keys_put_the_contact_on_the_data_timed_hit() -> void:
	var moves: Dictionary = _json("res://data/combat/moves.json").get("sets", {})
	var checked: int = 0
	for rig: String in RIGS:
		var spec: Dictionary = RIGS[rig]
		var clips: Dictionary = _json(str(spec["keys"])).get("clips", {})
		var set_moves: Dictionary = (moves[str(spec["set"])] as Dictionary)["moves"]
		for move_id: String in set_moves:
			var move: Dictionary = set_moves[move_id]
			var anim: Dictionary = move.get("anim", {})
			var keys: Array = anim.get("keys", [])
			if keys.is_empty():
				continue
			# a move counts when the pose key at its hit time names a clip from the free pack with a contact frame
			var hit_ms: int = int(move.get("impact_ms", move["startup_ms"]))
			var hit_key: Dictionary = {}
			var last_ms: int = -1
			for key: Dictionary in keys:
				assert_gt(int(key["at_ms"]), last_ms, "%s.%s: keys in time order" % [rig, move_id])
				last_ms = int(key["at_ms"])
				if int(key["at_ms"]) == hit_ms:
					hit_key = key
			var clip_name: String = str(hit_key.get("clip", anim.get("clip", "")))
			var entry: Dictionary = clips.get(clip_name, {})
			if hit_key.is_empty() or not entry.has("contact_s") or not str(entry.get("source", "")).contains(CLIPS_FROM_THE_FREE_PACK):
				continue
			checked += 1
			assert_almost_eq(float(hit_key["clip_s"]), float(entry["contact_s"]), FRAME_S, "%s.%s: the key at the hit snaps %s to its contact frame" % [rig, move_id, clip_name])
			for key: Dictionary in keys:
				var key_clip: String = str(key.get("clip", anim.get("clip", "")))
				if clips.has(key_clip):
					assert_le(float(key["clip_s"]), float((clips[key_clip] as Dictionary)["length_s"]) + 0.001, "%s.%s: key %d ms stays inside %s" % [rig, move_id, int(key["at_ms"]), key_clip])
			assert_eq(int(keys[0]["at_ms"]), 0, "%s.%s: the first key is at 0" % [rig, move_id])
	assert_ge(checked, 12, "Red's six moves, her four hack casts and the Grunt's two swipes are timed from the real clips")


func test_playback_look_comes_from_the_data_file() -> void:
	# data/animation/import_look.json decides smooth or stepped for the retargeted clips (scripts/tools/ual_post_import.gd);
	# the hand-posed stand-ins kept in Red's file stay stepped
	var look: Dictionary = _json("res://data/animation/import_look.json")
	var wanted: int = Animation.INTERPOLATION_NEAREST if str(look.get("interpolation", "linear")) == "nearest" else Animation.INTERPOLATION_LINEAR
	for rig: String in RIGS:
		var settings: Dictionary = _json(str(RIGS[rig]["settings"]))
		var player: AnimationPlayer = _player(_model(_output(settings)))
		var standins: Array = settings.get("keep_standins", [])
		for clip: String in player.get_animation_list():
			var expected: int = Animation.INTERPOLATION_NEAREST if standins.has(clip) else wanted
			var animation: Animation = player.get_animation(clip)
			for track: int in animation.get_track_count():
				assert_eq(animation.track_get_interpolation_type(track), expected, "%s: %s track %d playback look" % [rig, clip, track])
				if animation.track_get_interpolation_type(track) != expected:
					break


func test_loops_close_on_their_first_pose() -> void:
	for rig: String in RIGS:
		var settings: Dictionary = _json(str(RIGS[rig]["settings"]))
		var player: AnimationPlayer = _player(_model(_output(settings)))
		for spec: Dictionary in settings["clips"]:
			if not bool(spec.get("loop", false)):
				continue
			var animation: Animation = player.get_animation(str(spec["name"]))
			assert_not_null(animation, "%s: %s" % [rig, spec["name"]])
			for track: int in animation.get_track_count():
				if animation.track_get_type(track) != Animation.TYPE_ROTATION_3D:
					continue
				var count: int = animation.track_get_key_count(track)
				var first: Quaternion = animation.track_get_key_value(track, 0) as Quaternion if count > 0 else Quaternion.IDENTITY
				var last: Quaternion = animation.track_get_key_value(track, count - 1) as Quaternion if count > 0 else Quaternion.IDENTITY
				assert_gt(absf(first.dot(last)), 0.9995, "%s: %s closes its loop (track %d)" % [rig, spec["name"], track])


func test_sockets_follow_the_hands_in_every_clip() -> void:
	for rig: String in RIGS:
		var spec: Dictionary = RIGS[rig]
		var settings: Dictionary = _json(str(spec["settings"]))
		var model: Node3D = _model(_output(settings))
		var player: AnimationPlayer = _player(model)
		var skeleton: Skeleton3D = _skeleton(model)
		var socket: int = skeleton.find_bone(str(spec["socket"]))
		assert_ge(socket, 0, rig + ": the weapon socket exists")
		assert_eq(skeleton.get_bone_name(skeleton.get_bone_parent(socket)), str(spec["hand"]), rig + ": the socket hangs from the hand")
		var rest_distance: float = skeleton.get_bone_global_rest(socket).origin.distance_to(skeleton.get_bone_global_rest(skeleton.find_bone(str(spec["hand"]))).origin)
		for clip: String in player.get_animation_list():
			var length: float = player.get_animation(clip).length
			for fraction: float in [0.0, 0.3, 0.6, 1.0]:
				_set_pose(player, skeleton, clip, length * fraction)
				var distance: float = _bone_origin(skeleton, str(spec["socket"])).distance_to(_bone_origin(skeleton, str(spec["hand"])))
				assert_almost_eq(distance, rest_distance, 0.01, "%s: %s at %.0f%%: the socket stays in the fist" % [rig, clip, fraction * 100.0])


func test_the_blade_points_where_the_source_grip_points() -> void:
	# retarget_ual.py aligns the right hand so weapon_socket +Y follows the Quaternius grip (the blade leaves the fist on
	# the index finger side). In Sword_Idle that is forward, outward (to her right, -X) and up.
	for rig: String in ["red", "wolf"]:
		var settings: Dictionary = _json(str(RIGS[rig]["settings"]))
		var model: Node3D = _model(_output(settings))
		var player: AnimationPlayer = _player(model)
		var skeleton: Skeleton3D = _skeleton(model)
		var clip: String = "idle" if rig == "red" else "notice"
		_set_pose(player, skeleton, clip, 0.5)
		var blade: Vector3 = skeleton.get_bone_global_pose(skeleton.find_bone("weapon_socket")).basis.y.normalized()
		assert_gt(blade.z, 0.3, "%s: the blade points forward in %s" % [rig, clip])
		assert_lt(blade.x, -0.3, "%s: and out to her right" % rig)
		assert_gt(blade.y, 0.0, "%s: and up" % rig)


func _lowest_sole(skeleton: Skeleton3D, soles: Array) -> float:
	# soles: [bone, rest-frame offset from the bone's joint] pairs; the offsets turn with the foot
	var lowest: float = INF
	for pair: Array in soles:
		var bone: int = skeleton.find_bone(str(pair[0]))
		var local: Vector3 = skeleton.get_bone_global_rest(bone).basis.inverse() * (pair[1] as Vector3)
		var pose: Transform3D = skeleton.get_bone_global_pose(bone)
		lowest = minf(lowest, (pose.origin + pose.basis * local).y)
	return lowest


func test_feet_stay_on_the_floor_in_standing_and_moving_clips() -> void:
	# ground lock (retarget_ual.py): the lowest sole point is put on the floor, scaled by the leg length, so a planted
	# foot stays planted and nothing sinks. The sole points are the ones in the settings (heel and toe of each foot).
	for rig: String in ["red", "wolf"]:
		var settings: Dictionary = _json(str(RIGS[rig]["settings"]))
		var soles: Array = []
		for point: Dictionary in (settings["ground"] as Dictionary)["target_points"]:
			if float(point.get("lift", 0.0)) == 0.0:
				var offset: Array = point["offset"]
				soles.append([point["bone"], Vector3(float(offset[0]), float(offset[1]), float(offset[2]))])
		assert_eq(soles.size(), 4, rig + ": heel and toe of both feet")
		var model: Node3D = _model(_output(settings))
		var player: AnimationPlayer = _player(model)
		var skeleton: Skeleton3D = _skeleton(model)
		var standing: Array[String] = ["idle", "walk"]
		var moving: Array[String] = ["run"]
		if rig == "wolf":
			standing.append_array(["strafe_l", "strafe_r", "stalk"])
			moving.append_array(["retreat", "flee"])
		for clip: String in standing:
			var length: float = player.get_animation(clip).length
			for step: int in 12:
				_set_pose(player, skeleton, clip, length * float(step) / 12.0)
				assert_almost_eq(_lowest_sole(skeleton, soles), 0.0, 0.02, "%s: %s frame %d: a foot is on the floor" % [rig, clip, step])
		for clip: String in moving:
			var length: float = player.get_animation(clip).length
			for step: int in 12:
				_set_pose(player, skeleton, clip, length * float(step) / 12.0)
				var low: float = _lowest_sole(skeleton, soles)
				assert_ge(low, -0.03, "%s: %s frame %d: nothing sinks into the floor (3 cm of slack: the rigs have no toe bone)" % [rig, clip, step])
				assert_le(low, 0.12, "%s: %s frame %d: the flight phase of a sprint stays low (scaled stride)" % [rig, clip, step])


func test_the_wolfs_extra_clips_named_in_the_enemy_data_all_exist() -> void:
	# the Combat Designer's catalog (enemies.json behaviour.clips) names the clips the AI will play
	var enemies: Dictionary = _json("res://data/combat/enemies.json").get("enemies", {})
	for enemy: String in ["grunt", "brute"]:
		var def: Dictionary = enemies[enemy]
		var player: AnimationPlayer = _player(_model(str(def["model"])))
		var behaviour: Dictionary = def.get("behaviour", {})
		for entry_name: String in (behaviour.get("clips", {}) as Dictionary):
			var clip: String = str(behaviour["clips"][entry_name]["clip"])
			assert_true(player.has_animation(clip), "%s: AI clip '%s' (%s) is in %s" % [enemy, clip, entry_name, str(def["model"]).get_file()])
		for move_id: String in ["attack_windup", "attack_swing"]:
			assert_true(player.has_animation(move_id), "%s: %s" % [enemy, move_id])


func _stride_extent(player: AnimationPlayer, skeleton: Skeleton3D, clip: String) -> Vector2:
	# how far apart the two feet get along X (sideways) and Z (forward) over one cycle
	var wide: float = 0.0
	var deep: float = 0.0
	var length: float = player.get_animation(clip).length
	for step: int in 16:
		_set_pose(player, skeleton, clip, length * float(step) / 16.0)
		var apart: Vector3 = _bone_origin(skeleton, "foot_l") - _bone_origin(skeleton, "foot_r")
		wide = maxf(wide, absf(apart.x - 0.25))
		deep = maxf(deep, absf(apart.z))
	return Vector2(wide, deep)


func test_side_steps_and_backwards_clips_are_the_walk_turned_not_new_motion() -> void:
	# strafe_l / strafe_r are the walk with the hips and legs turned 90 degrees; retreat is the jog backwards
	var settings: Dictionary = _json(str(RIGS["wolf"]["settings"]))
	var model: Node3D = _model(_output(settings))
	var player: AnimationPlayer = _player(model)
	var skeleton: Skeleton3D = _skeleton(model)
	for clip: String in ["strafe_l", "strafe_r", "retreat", "dodge_back"]:
		assert_true(player.has_animation(clip), clip)
	assert_almost_eq(player.get_animation("strafe_l").length, player.get_animation("walk").length, 0.001, "strafe_l runs on the walk's timing")
	assert_almost_eq(player.get_animation("retreat").length, player.get_animation("run").length, 0.001, "retreat is the jog's length (played backwards)")
	var walk: Vector2 = _stride_extent(player, skeleton, "walk")
	var left: Vector2 = _stride_extent(player, skeleton, "strafe_l")
	var right: Vector2 = _stride_extent(player, skeleton, "strafe_r")
	assert_gt(walk.y, walk.x, "walking: the feet swap along the way she faces")
	assert_gt(left.x, left.y, "strafe_l: the feet swap sideways")
	assert_gt(right.x, right.y, "strafe_r: the feet swap sideways")
	# the two sides step opposite ways: the feet are in different places at the same moment of the cycle
	var most_different: float = 0.0
	for step: int in 16:
		var time: float = player.get_animation("strafe_l").length * float(step) / 16.0
		_set_pose(player, skeleton, "strafe_l", time)
		var left_pose: float = _bone_origin(skeleton, "foot_l").x - _bone_origin(skeleton, "foot_r").x
		_set_pose(player, skeleton, "strafe_r", time)
		var right_pose: float = _bone_origin(skeleton, "foot_l").x - _bone_origin(skeleton, "foot_r").x
		most_different = maxf(most_different, absf(left_pose - right_pose))
	assert_gt(most_different, 0.03, "the two side-steps are different clips")
