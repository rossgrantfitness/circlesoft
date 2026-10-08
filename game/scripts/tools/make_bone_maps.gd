extends SceneTree
## Writes the Godot humanoid BoneMaps for our rigged models, so the free Quaternius "Universal Animation Library" clips (CC0) can be
## retargeted onto them (Ross, 2026-10-08: "just find some basic prefab animations ... everything is placeholder").
##
##   godot --headless --path game -s res://scripts/tools/make_bone_maps.gd
##
## Our skeletons keep their own bone names (the game code reads weapon_socket, head, upper_arm_r ...). A BoneMap says which of our
## bones is which humanoid bone (Hips, Spine, Chest, Neck, Head, shoulders, arms, hands, legs, feet). Used by Godot's import
## "Retarget" step (Skeleton3D > Retarget > Bone Map) on a model import, or by tests to prove the mapping is clean. Our extra bones
## (ears, tail, sockets) are not in the profile, so they are left alone. The rest pose is an A-pose with the hips at 0.38 m; the
## importer's Rest Fixer squares that up against the library's T-pose.

const HUMANOID_TO_OURS: Dictionary = {
	"Root": "root", "Hips": "hips", "Spine": "spine", "Chest": "chest", "Neck": "neck", "Head": "head",
	"LeftShoulder": "shoulder_l", "LeftUpperArm": "upper_arm_l", "LeftLowerArm": "forearm_l", "LeftHand": "hand_l",
	"LeftUpperLeg": "thigh_l", "LeftLowerLeg": "shin_l", "LeftFoot": "foot_l",
	"RightShoulder": "shoulder_r", "RightUpperArm": "upper_arm_r", "RightLowerArm": "forearm_r", "RightHand": "hand_r",
	"RightUpperLeg": "thigh_r", "RightLowerLeg": "shin_r", "RightFoot": "foot_r",
}
const OUTPUTS: Dictionary = {
	"res://art/final/characters/red/red_ross_bone_map.tres": "res://art/final/characters/red/red_ross_v1_rigged.glb",
	"res://art/final/enemies/cyberwolf_sentinel_bone_map.tres": "res://art/final/enemies/cyberwolf_sentinel_rigged.glb",
}


func _initialize() -> void:
	for path: String in OUTPUTS:
		var map: BoneMap = BoneMap.new()
		map.profile = SkeletonProfileHumanoid.new()
		for humanoid: String in HUMANOID_TO_OURS:
			map.set_skeleton_bone_name(humanoid, HUMANOID_TO_OURS[humanoid])
		print("saved ", path, " error ", ResourceSaver.save(map, path))
	quit(0)
