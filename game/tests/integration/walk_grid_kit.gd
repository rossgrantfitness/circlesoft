extends RefCounted
## The walk check shared by the level tests (test_slice_rooms.gd, test_slice_yard_rooms.gd): a level scene's collision rasterised into a
## height grid (every box and cylinder under any StaticBody3D in the scene, tilted ramps included), then breadth-first from a spawn with
## the rules from docs/maps/junkyard.md: steps up of 1.0 m or less, jumps of 1.6 m across gaps of up to 1.0 m, drops up to 6 m. Shapes whose
## underside is 2 m or more above the ground do not block (a raised shutter, a roof). Nothing here runs the physics engine, so it works on a
## scene that is not in the tree.
##   var grid = WalkGridKit.new(level, max_x, max_z, min_x, min_z, extra_boxes)
##   var reached: Dictionary = grid.reach_from(x, z)        # Vector2i -> true
##   grid.reaches(reached, x, z, y, radius)

const GRID: float = 0.25
const STEP_UP_M: float = 1.0
const JUMP_M: float = 1.6
const JUMP_REACH_M: float = 1.0
const DROP_M: float = 6.0
const VOID: float = -99.0

var x0: float = -1.0
var z0: float = -1.0
var nx: int = 0
var nz: int = 0
var height: PackedFloat32Array = PackedFloat32Array()


## `extra_boxes`: [{"pos": Vector3 centre, "size": Vector3}] added to the world (a crane's bridge that exists only at run time).
func _init(level: Node3D, max_x: float, max_z: float, min_x: float = -1.0, min_z: float = -1.0, extra_boxes: Array = []) -> void:
	x0 = min_x
	z0 = min_z
	nx = int(ceil((max_x - x0) / GRID))
	nz = int(ceil((max_z - z0) / GRID))
	height.resize(nx * nz)
	height.fill(VOID)
	for node: Node in level.find_children("*", "CollisionShape3D", true, false):
		var shape_node: CollisionShape3D = node as CollisionShape3D
		if shape_node == null or shape_node.shape == null or shape_node.disabled or _inside_instance(shape_node, level):
			continue
		_add_shape(shape_node.shape, _global_of(shape_node, level))
	for extra: Variant in extra_boxes:
		var box: Dictionary = extra
		_add_shape(_box_of(box["size"] as Vector3), Transform3D(Basis.IDENTITY, box["pos"] as Vector3))


## True for a shape that belongs to an instanced prop scene (a person's body, a crate, a door): those are not the level's ground.
static func _inside_instance(node: Node, root: Node) -> bool:
	var at: Node = node.get_parent()
	while at != null and at != root:
		if not at.scene_file_path.is_empty() or at.name == &"Shutters":       # a raised shutter is open: it is not ground
			return true
		at = at.get_parent()
	return false


static func _box_of(size: Vector3) -> BoxShape3D:
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	return shape


## The transform of a node relative to the level root (the scene is not in the tree, so global_transform is not available).
static func _global_of(node: Node3D, root: Node) -> Transform3D:
	var result: Transform3D = Transform3D.IDENTITY
	var at: Node = node
	while at != null and at != root:
		if at is Node3D:
			result = (at as Node3D).transform * result
		at = at.get_parent()
	return result


func _add_shape(shape: Shape3D, xform: Transform3D) -> void:
	var inverse: Transform3D = xform.affine_inverse()
	var bounds: AABB
	if shape is BoxShape3D:
		var size: Vector3 = (shape as BoxShape3D).size
		bounds = xform * AABB(-size * 0.5, size)
	elif shape is CylinderShape3D:
		var cyl: CylinderShape3D = shape as CylinderShape3D
		var r: float = cyl.radius
		bounds = xform * AABB(Vector3(-r, -cyl.height * 0.5, -r), Vector3(r * 2.0, cyl.height, r * 2.0))
	else:
		return
	var ix0: int = maxi(int(floor((bounds.position.x - x0) / GRID)), 0)
	var ix1: int = mini(int(floor((bounds.position.x + bounds.size.x - x0) / GRID)), nx - 1)
	var iz0: int = maxi(int(floor((bounds.position.z - z0) / GRID)), 0)
	var iz1: int = mini(int(floor((bounds.position.z + bounds.size.z - z0) / GRID)), nz - 1)
	var up: Vector3 = inverse.basis * Vector3.UP
	for iz: int in range(iz0, iz1 + 1):
		for ix: int in range(ix0, ix1 + 1):
			var cx: float = x0 + (ix + 0.5) * GRID
			var cz: float = z0 + (iz + 0.5) * GRID
			var span: Vector2 = _y_span(shape, inverse, up, cx, cz)
			if span.x > span.y:
				continue
			var i: int = iz * nx + ix
			height[i] = maxf(height[i], span.y)


## The vertical interval [low, high] of a shape above the point (x, z), or (1, 0) if the line misses it.
static func _y_span(shape: Shape3D, inverse: Transform3D, up: Vector3, x: float, z: float) -> Vector2:
	var base: Vector3 = inverse * Vector3(x, 0.0, z)
	if shape is BoxShape3D:
		var half: Vector3 = (shape as BoxShape3D).size * 0.5
		var lo: float = -1.0e9
		var hi: float = 1.0e9
		for axis: int in 3:
			var a: float = base[axis]
			var b: float = up[axis]
			if absf(b) < 1.0e-6:
				if absf(a) > half[axis]:
					return Vector2(1.0, 0.0)
			else:
				var t0: float = (-half[axis] - a) / b
				var t1: float = (half[axis] - a) / b
				lo = maxf(lo, minf(t0, t1))
				hi = minf(hi, maxf(t0, t1))
		return Vector2(lo, hi)
	var cyl: CylinderShape3D = shape as CylinderShape3D
	if base.x * base.x + base.z * base.z > cyl.radius * cyl.radius:
		return Vector2(1.0, 0.0)
	var t_lo: float = (-cyl.height * 0.5 - base.y) / up.y if absf(up.y) > 1.0e-6 else 0.0
	var t_hi: float = (cyl.height * 0.5 - base.y) / up.y if absf(up.y) > 1.0e-6 else 0.0
	return Vector2(minf(t_lo, t_hi), maxf(t_lo, t_hi))


func cell_center(ix: int, iz: int) -> Vector2:
	return Vector2(x0 + (ix + 0.5) * GRID, z0 + (iz + 0.5) * GRID)


func cell_of(x: float, z: float) -> Vector2i:
	return Vector2i(clampi(int(floor((x - x0) / GRID)), 0, nx - 1), clampi(int(floor((z - z0) / GRID)), 0, nz - 1))


func h(ix: int, iz: int) -> float:
	if ix < 0 or iz < 0 or ix >= nx or iz >= nz:
		return VOID
	return height[iz * nx + ix]


func standable(ix: int, iz: int) -> bool:
	return h(ix, iz) > -50.0


func height_at(x: float, z: float) -> float:
	var c: Vector2i = cell_of(x, z)
	return h(c.x, c.y)


## All cells Red can reach from (x, z): Vector2i -> true.
func reach_from(x: float, z: float) -> Dictionary:
	var start: Vector2i = cell_of(x, z)
	var seen: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var jump_dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
	var jump_cells: int = int(JUMP_REACH_M / GRID)
	while not queue.is_empty():
		var at: Vector2i = queue.pop_back()
		var here: float = h(at.x, at.y)
		var near_edge: bool = false
		for d: Vector2i in dirs:
			var next: Vector2i = at + d
			var there: float = h(next.x, next.y)
			if there < -50.0 or absf(there - here) > 0.12:
				near_edge = true
			if seen.has(next) or there < -50.0:
				continue
			var rise: float = there - here
			if rise <= STEP_UP_M and rise >= -DROP_M:
				seen[next] = true
				queue.append(next)
		if not near_edge:
			continue
		for d: Vector2i in jump_dirs:
			for k: int in range(1, jump_cells + 1):
				var next: Vector2i = at + d * k
				if seen.has(next) or not standable(next.x, next.y):
					continue
				var rise: float = h(next.x, next.y) - here
				if rise > JUMP_M or rise < -DROP_M:
					continue
				var clear: bool = true
				for j: int in range(1, k):
					var mid: Vector2i = at + d * j
					if h(mid.x, mid.y) > maxf(here, h(next.x, next.y)) + 0.4:
						clear = false
				if clear:
					seen[next] = true
					queue.append(next)
	return seen


## True when a reached cell is within `radius` of (x, z) and about as high as `y`.
func reaches(reached: Dictionary, x: float, z: float, y: float, radius: float) -> bool:
	var span: int = int(ceil(radius / GRID))
	var centre: Vector2i = cell_of(x, z)
	for dz: int in range(-span, span + 1):
		for dx: int in range(-span, span + 1):
			var cell: Vector2i = centre + Vector2i(dx, dz)
			if not reached.has(cell):
				continue
			var c: Vector2 = cell_center(cell.x, cell.y)
			if c.distance_to(Vector2(x, z)) <= radius and absf(h(cell.x, cell.y) - y) <= STEP_UP_M + 0.2:
				return true
	return false
