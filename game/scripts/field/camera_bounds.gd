class_name CameraBounds
extends Node3D
## A room's camera bounds: a box, centered on this node, that the diorama camera's look-at point
## stays inside (on X and Z). Put one named "CameraBounds" in each room and size it so the camera
## never shows past the room's edges. A zero-size box pins the camera, for rooms that fit one screen.

@export var size: Vector3 = Vector3(10.0, 0.0, 6.0)


## The box in world space.
func get_world_aabb() -> AABB:
	return AABB(global_position - size * 0.5, size)
