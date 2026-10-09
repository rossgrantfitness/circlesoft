extends Node3D
## A test stand-in for a boss that names its own flash nodes (HitFlash.roots_for asks `hit_flash_roots()`).

var roots: Array = []


func hit_flash_roots() -> Array:
	return roots
