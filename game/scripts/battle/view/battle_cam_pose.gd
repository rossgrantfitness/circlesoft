class_name BattleCamPose
extends RefCounted
## One camera pose: where it is, what it looks at, how far it is rolled (degrees about the view axis) and its
## vertical field of view (degrees). The battle camera director blends and eases these.

var position: Vector3 = Vector3.ZERO
var look: Vector3 = Vector3.FORWARD
var roll: float = 0.0
var fov: float = 30.0


static func make(p: Vector3, target: Vector3, roll_deg: float, fov_deg: float) -> BattleCamPose:
	var pose: BattleCamPose = BattleCamPose.new()
	pose.position = p
	pose.look = target
	pose.roll = roll_deg
	pose.fov = fov_deg
	return pose


func copy() -> BattleCamPose:
	return BattleCamPose.make(position, look, roll, fov)


static func mix(a: BattleCamPose, b: BattleCamPose, t: float) -> BattleCamPose:
	return BattleCamPose.make(a.position.lerp(b.position, t), a.look.lerp(b.look, t), lerpf(a.roll, b.roll, t), lerpf(a.fov, b.fov, t))


func basis() -> Basis:
	return BattleCamMath.basis_for(position, look, roll)
