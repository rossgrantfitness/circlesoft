class_name GrimProps
extends RefCounted
## Cheap, reusable "grim" props built from code: propaganda posters, floodlights, loudspeakers, chain-link
## fence and barbed wire, warning stripes, puddles, steam vents, hanging cables, pipes, lean-to shacks, neon
## and holo signs, grimy propaganda screens and rain. One builder per type; the room or battle set lists the
## ones it wants in data/world/look_dressing.json (position, yaw, a few numbers), so every prop is reused
## across rooms and nothing is hard-coded into a scene.
##
## Every prop is placeholder art: boxes, cylinders and quads on the PSX materials, textures painted by
## GrimePaint. None of them has collision. `build(item, grime)` returns one Node3D (or null for an unknown
## type) whose children are the meshes, lights and animators.

const LIT_SHADER: String = "res://shaders/psx_lit.gdshader"
const UNLIT_SHADER: String = "res://shaders/psx_unlit.gdshader"
const DEFAULT_GRIME: Dictionary = {}
const TYPES: PackedStringArray = [
	"poster", "stripes", "floodlight", "loudspeaker", "fence", "barbed", "puddle", "neon", "screen", "steam",
	"cable", "pipe", "shack", "skyline", "rain", "hang_lamp", "smear", "barrier",
]

static var _materials: Dictionary[String, ShaderMaterial] = {}
static var _meshes: Dictionary[String, Mesh] = {}


static func clear_cache() -> void:
	_materials.clear()
	_meshes.clear()


## Builds one prop from a data item ({"type": "poster", "pos": [x, y, z], "yaw": 0, ...}).
static func build(item: Dictionary, grime: Dictionary = DEFAULT_GRIME) -> Node3D:
	var type: String = str(item.get("type", ""))
	var node: Node3D = null
	match type:
		"poster":
			node = _poster(item)
		"stripes":
			node = _stripes(item)
		"barrier":
			node = _barrier(item, grime)
		"floodlight":
			node = _floodlight(item, grime)
		"loudspeaker":
			node = _loudspeaker(item, grime)
		"fence":
			node = _fence(item, grime)
		"barbed":
			node = _barbed(item)
		"puddle":
			node = _puddle(item)
		"smear":
			node = _smear(item)
		"neon":
			node = _neon(item)
		"screen":
			node = _screen(item, grime)
		"steam":
			node = _steam(item, grime)
		"cable":
			node = _cable(item)
		"pipe":
			node = _pipe(item, grime)
		"shack":
			node = _shack(item, grime)
		"skyline":
			node = _skyline(item, grime)
		"rain":
			node = _rain(item)
		"hang_lamp":
			node = _hang_lamp(item)
		_:
			push_warning("GrimProps: unknown prop type '%s'" % type)
			return null
	if node == null:
		return null
	node.name = str(item.get("name", type.capitalize().replace(" ", "")))
	if not item.has("skip_place"):
		node.position = vec3(item.get("pos", [0.0, 0.0, 0.0]))
		node.rotation_degrees.y = float(item.get("yaw", 0.0))
	return node


## Triangles in a prop (tests and the budget note).
static func triangle_count(node: Node) -> int:
	var total: int = 0
	var nodes: Array[Node] = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		nodes.append(node)
	for found: Node in nodes:
		var mesh: Mesh = (found as MeshInstance3D).mesh
		if mesh == null:
			continue
		for surface: int in mesh.get_surface_count():
			var arrays: Array = mesh.surface_get_arrays(surface)
			var indices: Variant = arrays[Mesh.ARRAY_INDEX]
			if indices != null and (indices as PackedInt32Array).size() > 0:
				total += (indices as PackedInt32Array).size() / 3
			else:
				total += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return total


static func vec3(value: Variant) -> Vector3:
	if value is Array and (value as Array).size() >= 3:
		var list: Array = value
		return Vector3(float(list[0]), float(list[1]), float(list[2]))
	return Vector3.ZERO


static func vec2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Array and (value as Array).size() >= 2:
		var list: Array = value
		return Vector2(float(list[0]), float(list[1]))
	return fallback


static func color(value: Variant, fallback: String) -> Color:
	return Color.html(str(value if value != null else fallback))


# ---- materials and meshes ----

static func lit(texture: Texture2D, tint: Color = Color.WHITE, uv_scale: Vector2 = Vector2.ONE, affine: float = 0.3) -> ShaderMaterial:
	var key: String = "lit:%d:%s:%s:%s" % [texture.get_instance_id() if texture != null else 0, tint.to_html(), str(uv_scale), str(affine)]
	if not _materials.has(key):
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = load(LIT_SHADER) as Shader
		material.set_shader_parameter(&"albedo_texture", texture)
		material.set_shader_parameter(&"albedo_tint", tint)
		material.set_shader_parameter(&"uv_scale", uv_scale)
		material.set_shader_parameter(&"affine_amount", affine)
		_materials[key] = material
	return _materials[key]


## An unlit (glowing) material. Never shared: animated signs change their own copy.
static func unlit(texture: Texture2D, tint: Color = Color.WHITE, energy: float = 1.0, uv_scale: Vector2 = Vector2.ONE) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load(UNLIT_SHADER) as Shader
	material.set_shader_parameter(&"albedo_texture", texture)
	material.set_shader_parameter(&"albedo_tint", tint)
	material.set_shader_parameter(&"emission_energy", energy)
	material.set_shader_parameter(&"uv_scale", uv_scale)
	return material


static func _flat(tint: Color) -> ShaderMaterial:
	return lit(GrimePaint.decal_texture("metal"), tint, Vector2.ONE, 0.2)


static func _box_mesh(size: Vector3) -> BoxMesh:
	var key: String = "box:%s" % str(size)
	if not _meshes.has(key):
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = size
		_meshes[key] = mesh
	return _meshes[key] as BoxMesh


static func _mesh_node(label: String, mesh: Mesh, material: Material, at: Vector3 = Vector3.ZERO, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.set_surface_override_material(0, material)
	node.position = at
	node.rotation_degrees = rot_deg
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


static func _box(label: String, size: Vector3, material: Material, at: Vector3 = Vector3.ZERO, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return _mesh_node(label, _box_mesh(size), material, at, rot_deg)


static func _quad(label: String, size: Vector2, material: Material, at: Vector3 = Vector3.ZERO, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var key: String = "quad:%s" % str(size)
	if not _meshes.has(key):
		var mesh: QuadMesh = QuadMesh.new()
		mesh.size = size
		_meshes[key] = mesh
	return _mesh_node(label, _meshes[key], material, at, rot_deg)


static func _cylinder(label: String, radius_top: float, radius_bottom: float, height: float, sides: int, material: Material, at: Vector3 = Vector3.ZERO, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius_top
	mesh.bottom_radius = radius_bottom
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	return _mesh_node(label, mesh, material, at, rot_deg)


static func _basis_along(direction: Vector3) -> Basis:
	var dir: Vector3 = direction.normalized()
	if dir.is_equal_approx(Vector3.DOWN):
		return Basis(Vector3.RIGHT, PI)
	return Basis(Quaternion(Vector3.UP, dir))


# ---- the props ----

## size [w, h]; variant 0 mast mark, 1 watching eye, 2 ration slogan.
static func _poster(item: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	var size: Vector2 = vec2(item.get("size"), Vector2(0.9, 1.35))
	var names: Array[String] = ["poster_mast", "poster_eye", "poster_ration"]
	var texture: Texture2D = GrimePaint.decal_texture(names[int(item.get("variant", 0)) % 3])
	root.add_child(_box("Paper", Vector3(size.x, size.y, 0.03), lit(texture, Color(0.85, 0.85, 0.82), Vector2.ONE, 0.2)))
	return root


## Hazard stripes. size [x, y, z] of a thin slab; the long side tiles the stripes.
static func _stripes(item: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	var size: Vector3 = vec3(item.get("size", [2.0, 0.03, 0.4]))
	var longest: float = maxf(size.x, maxf(size.y, size.z))
	var tile: Vector2 = Vector2(longest / 0.5, 1.0)
	root.add_child(_box("Stripes", size, lit(GrimePaint.decal_texture("stripes"), Color(0.9, 0.9, 0.85), tile, 0.0)))
	return root


## A low concrete block with a hazard band: the checkpoint's road barrier.
static func _barrier(item: Dictionary, grime: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	var size: Vector3 = vec3(item.get("size", [1.6, 0.7, 0.45]))
	var concrete: Texture2D = GrimePaint.surface_texture("wall", grime)
	root.add_child(_box("Block", size, lit(concrete, Color(0.55, 0.55, 0.52), Vector2(maxf(size.x, 1.0) / 2.0, 0.5))))
	root.add_child(_box("Band", Vector3(size.x + 0.02, 0.18, size.z + 0.02), lit(GrimePaint.decal_texture("stripes"), Color(0.9, 0.9, 0.85), Vector2(size.x / 0.5, 1.0), 0.0), Vector3(0.0, size.y * 0.25, 0.0)))
	return root


## A pole with a lamp head and a hard cold light. aim_deg: yaw the head turns toward; pitch_deg tilts it down.
static func _floodlight(item: Dictionary, grime: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	var height: float = float(item.get("height", 3.2))
	var metal: ShaderMaterial = lit(GrimePaint.decal_texture("metal", grime), Color(0.5, 0.5, 0.48), Vector2.ONE, 0.2)
	root.add_child(_box("Pole", Vector3(0.1, height, 0.1), metal, Vector3(0.0, height / 2.0, 0.0)))
	var head: Node3D = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.0, height, 0.12)
	head.rotation_degrees = Vector3(float(item.get("pitch_deg", 28.0)), float(item.get("aim_deg", 0.0)), 0.0)
	head.add_child(_box("Housing", Vector3(0.62, 0.34, 0.26), metal, Vector3(0.0, 0.0, 0.0)))
	var lens_color: Color = color(item.get("color"), "#4fb8a4")
	head.add_child(_quad("Lens", Vector2(0.54, 0.26), unlit(null, lens_color, 1.25), Vector3(0.0, 0.0, 0.135), Vector3.ZERO))
	var light: OmniLight3D = OmniLight3D.new()
	light.name = "Light"
	light.light_color = lens_color
	light.light_energy = float(item.get("energy", 3.2))
	light.omni_range = float(item.get("range", 7.0))
	light.position = Vector3(0.0, -0.3, 0.7)
	root.add_child(head)
	head.add_child(light)
	root.add_child(_box("Foot", Vector3(0.3, 0.08, 0.3), metal, Vector3(0.0, 0.04, 0.0)))
	return root


## A horn loudspeaker on a short bracket with a cold red status light.
static func _loudspeaker(item: Dictionary, grime: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	var metal: ShaderMaterial = lit(GrimePaint.decal_texture("metal", grime), Color(0.34, 0.35, 0.34), Vector2.ONE, 0.2)
	root.add_child(_box("Bracket", Vector3(0.08, 0.08, 0.5), metal, Vector3(0.0, 0.0, -0.2)))
	root.add_child(_cylinder("Horn", 0.34, 0.1, 0.5, 8, metal, Vector3(0.0, 0.0, 0.2), Vector3(90.0, 0.0, 0.0)))
	root.add_child(_box("Driver", Vector3(0.26, 0.26, 0.22), metal, Vector3(0.0, 0.0, -0.08)))
	root.add_child(_box("Status", Vector3(0.07, 0.07, 0.07), unlit(null, color(item.get("status"), "#e8456a"), 1.8), Vector3(0.0, 0.22, -0.08)))
	return root


## Chain-link fence along a line from `from` to `to` (floor level), with posts and optional barbed wire on top.
static func _fence(item: Dictionary, grime: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	var a: Vector3 = vec3(item.get("from", [0.0, 0.0, 0.0]))
	var b: Vector3 = vec3(item.get("to", [2.0, 0.0, 0.0]))
	var height: float = float(item.get("height", 1.7))
	var length: float = a.distance_to(b)
	var mid: Vector3 = (a + b) / 2.0
	var yaw: float = rad_to_deg(atan2(b.x - a.x, b.z - a.z)) - 90.0
	var metal: ShaderMaterial = lit(GrimePaint.decal_texture("metal", grime), Color(0.4, 0.4, 0.38), Vector2.ONE, 0.2)
	var mesh_holder: Node3D = Node3D.new()
	mesh_holder.name = "Line"
	mesh_holder.position = mid
	mesh_holder.rotation_degrees.y = yaw
	root.add_child(mesh_holder)
	mesh_holder.add_child(_box("Mesh", Vector3(length, height, 0.02), lit(GrimePaint.decal_texture("fence"), Color(0.8, 0.8, 0.78), Vector2(length / 0.5, height / 0.5), 0.1), Vector3(0.0, height / 2.0, 0.0)))
	var posts: int = maxi(int(ceilf(length / 2.5)) + 1, 2)
	for i: int in posts:
		var along: float = -length / 2.0 + length * float(i) / float(posts - 1)
		mesh_holder.add_child(_box("Post%d" % i, Vector3(0.09, height + 0.25, 0.09), metal, Vector3(along, (height + 0.25) / 2.0, 0.0)))
	if bool(item.get("barbed", true)):
		mesh_holder.add_child(_box("Barbed", Vector3(length, 0.3, 0.02), lit(GrimePaint.decal_texture("barbed"), Color(0.85, 0.85, 0.82), Vector2(length / 1.0, 1.0), 0.1), Vector3(0.0, height + 0.38, 0.0)))
	return root


## A strip of barbed wire along a line.
static func _barbed(item: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	var a: Vector3 = vec3(item.get("from", [0.0, 3.0, 0.0]))
	var b: Vector3 = vec3(item.get("to", [2.0, 3.0, 0.0]))
	var length: float = a.distance_to(b)
	var holder: Node3D = Node3D.new()
	holder.position = (a + b) / 2.0
	holder.rotation_degrees.y = rad_to_deg(atan2(b.x - a.x, b.z - a.z)) - 90.0
	holder.add_child(_box("Wire", Vector3(length, 0.3, 0.02), lit(GrimePaint.decal_texture("barbed"), Color(0.85, 0.85, 0.82), Vector2(length, 1.0), 0.1)))
	root.add_child(holder)
	return root


## A flat puddle. size [w, d].
static func _puddle(item: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	var size: Vector2 = vec2(item.get("size"), Vector2(1.6, 1.0))
	var quad: MeshInstance3D = _quad("Water", size, unlit(GrimePaint.decal_texture("puddle"), color(item.get("tint"), "#d8e0dc"), 1.0), Vector3(0.0, 0.02, 0.0), Vector3(-90.0, 0.0, 0.0))
	root.add_child(quad)
	return root


## A streak of neon color on wet ground under a sign (a cheap reflection). size [w, d].
static func _smear(item: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	var size: Vector2 = vec2(item.get("size"), Vector2(0.8, 1.6))
	var tint: Color = color(item.get("color"), "#5fe0c8")
	var img: Image = Image.create(8, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y: int in 32:
		for x: int in 8:
			var fade: float = 1.0 - float(y) / 32.0
			var across: float = 1.0 - absf(float(x) - 3.5) / 4.5
			if across * fade > GrimePaint._bayer(x, y) * 0.9:
				img.set_pixel(x, y, Color(1, 1, 1, 1))
	var texture: ImageTexture = ImageTexture.create_from_image(img)
	root.add_child(_quad("Smear", size, unlit(texture, Color(tint.r, tint.g, tint.b, 1.0), float(item.get("energy", 0.35))), Vector3(0.0, 0.025, 0.0), Vector3(-90.0, 0.0, 0.0)))
	return root


## A neon sign: text, color, width. pattern is the flicker ("1110h1011"), fps the steps per second.
static func _neon(item: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	var text: String = str(item.get("text", "OPEN"))
	var tint: Color = color(item.get("color"), "#5fe0c8")
	var texture: ImageTexture = GrimePaint.neon_texture(text, tint)
	var aspect: float = float(texture.get_width()) / float(texture.get_height())
	var height: float = float(item.get("height", 0.5))
	var material: ShaderMaterial = unlit(texture, Color.WHITE, float(item.get("energy", 1.5)))
	root.add_child(_quad("Sign", Vector2(height * aspect, height), material, Vector3.ZERO))
	root.add_child(_box("Backing", Vector3(height * aspect + 0.08, height + 0.08, 0.04), lit(GrimePaint.decal_texture("metal"), Color(0.2, 0.2, 0.2), Vector2.ONE, 0.2), Vector3(0.0, 0.0, -0.03)))
	var anim: GrimPropAnim = GrimPropAnim.new()
	anim.name = "Flicker"
	anim.mode = GrimPropAnim.Mode.FLICKER
	anim.material = material
	anim.energy_on = float(item.get("energy", 1.5))
	anim.pattern = str(item.get("pattern", "1111111h11"))
	anim.fps = float(item.get("fps", 7.0))
	anim.step_index = int(item.get("phase", 0))
	root.add_child(anim)
	if bool(item.get("light", true)):
		var light: OmniLight3D = OmniLight3D.new()
		light.name = "Glow"
		light.light_color = tint
		light.light_energy = float(item.get("light_energy", 1.4))
		light.omni_range = float(item.get("light_range", 3.5))
		light.position = Vector3(0.0, 0.0, 0.6)
		root.add_child(light)
	return root


## A grimy propaganda screen on a bezel. text is the slogan; kind "slogan" or "alert" sets the frame set.
static func _screen(item: Dictionary, grime: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	var width: float = float(item.get("width", 1.4))
	var height: float = width * 40.0 / 64.0
	var text: String = str(item.get("text", "ALL CLEAR"))
	var kind: String = str(item.get("kind", "slogan"))
	var frames: Array[Texture2D] = []
	if kind == "alert":
		frames.append(GrimePaint.screen_texture("alert", 0, text))
		frames.append(GrimePaint.screen_texture("alert", 1, text))
		frames.append(GrimePaint.screen_texture("static", 0, text))
	else:
		frames.append(GrimePaint.screen_texture("slogan", 0, text))
		frames.append(GrimePaint.screen_texture("slogan", 1, text))
		frames.append(GrimePaint.screen_texture("static", 0, text))
		frames.append(GrimePaint.screen_texture("static", 1, text))
	var material: ShaderMaterial = unlit(frames[0], Color(0.85, 0.95, 0.9), 1.2)
	var metal: ShaderMaterial = lit(GrimePaint.decal_texture("metal", grime), Color(0.28, 0.28, 0.27), Vector2.ONE, 0.2)
	root.add_child(_box("Bezel", Vector3(width + 0.14, height + 0.14, 0.12), metal, Vector3(0.0, 0.0, -0.05)))
	root.add_child(_quad("Glass", Vector2(width, height), material, Vector3(0.0, 0.0, 0.012)))
	var anim: GrimPropAnim = GrimPropAnim.new()
	anim.name = "Frames"
	anim.mode = GrimPropAnim.Mode.FRAMES
	anim.material = material
	anim.frames = frames
	anim.fps = float(item.get("fps", 3.0))
	anim.sequence = PackedInt32Array([0, 0, 0, 1, 0, 0, 2, 0, 0, 1] if kind != "alert" else [0, 1, 0, 1, 2, 0, 1])
	root.add_child(anim)
	var light: OmniLight3D = OmniLight3D.new()
	light.name = "Glow"
	light.light_color = Color("#8fd8c4") if kind != "alert" else Color("#e8456a")
	light.light_energy = float(item.get("light_energy", 0.9))
	light.omni_range = 3.0
	light.position = Vector3(0.0, 0.0, 0.7)
	root.add_child(light)
	return root


## A floor vent with three rising steam puffs.
static func _steam(item: Dictionary, grime: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	root.add_child(_quad("Grate", Vector2(0.7, 0.7), lit(GrimePaint.decal_texture("grate"), Color.WHITE, Vector2.ONE, 0.0), Vector3(0.0, 0.025, 0.0), Vector3(-90.0, 0.0, 0.0)))
	var anim: GrimPropAnim = GrimPropAnim.new()
	anim.name = "Steam"
	anim.mode = GrimPropAnim.Mode.STEAM
	anim.fps = float(item.get("fps", 8.0))
	anim.rise = float(item.get("rise", 1.2))
	for i: int in 3:
		var material: ShaderMaterial = unlit(GrimePaint.steam_texture(i), Color(0.85, 0.9, 0.88), 1.0)
		var puff: MeshInstance3D = _quad("Puff%d" % i, Vector2(0.9, 0.9), material, Vector3(0.0, 0.3, 0.0))
		root.add_child(puff)
		anim.puffs.append(puff)
		puff.rotation_degrees.x = -20.0
	root.add_child(anim)
	return root


## A cable (or a few) between two points with a sag: thin dark tubes joined into one mesh.
static func _cable(item: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	var a: Vector3 = vec3(item.get("from", [0.0, 3.0, 0.0]))
	var b: Vector3 = vec3(item.get("to", [4.0, 3.0, 0.0]))
	var sag: float = float(item.get("sag", 0.4))
	var strands: int = int(item.get("strands", 2))
	var radius: float = float(item.get("radius", 0.016))
	var segments: int = int(item.get("segments", 6))
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for strand: int in strands:
		var offset: Vector3 = Vector3(0.0, 0.0, 0.0)
		if strand > 0:
			offset = Vector3(0.0, -0.06 * float(strand), 0.05 * float(strand % 2 * 2 - 1))
		var previous: Vector3 = a + offset
		for i: int in range(1, segments + 1):
			var t: float = float(i) / float(segments)
			var point: Vector3 = a.lerp(b, t) + offset + Vector3(0.0, -sag * 4.0 * t * (1.0 - t), 0.0)
			var cylinder: CylinderMesh = CylinderMesh.new()
			cylinder.top_radius = radius
			cylinder.bottom_radius = radius
			cylinder.height = previous.distance_to(point)
			cylinder.radial_segments = 4
			cylinder.rings = 1
			cylinder.cap_top = false
			cylinder.cap_bottom = false
			var xf: Transform3D = Transform3D(_basis_along(point - previous), (previous + point) / 2.0)
			tool.append_from(cylinder, 0, xf)
			previous = point
	var mesh: ArrayMesh = tool.commit()
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = "Cable"
	node.mesh = mesh
	node.set_surface_override_material(0, lit(GrimePaint.decal_texture("metal"), color(item.get("tint"), "#2a2a28"), Vector2.ONE, 0.0))
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(node)
	return root


## A pipe from `from` to `to` with flanges every `flange` units.
static func _pipe(item: Dictionary, grime: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	var a: Vector3 = vec3(item.get("from", [0.0, 3.0, 0.0]))
	var b: Vector3 = vec3(item.get("to", [4.0, 3.0, 0.0]))
	var radius: float = float(item.get("radius", 0.09))
	var tint: Color = color(item.get("tint"), "#4a4743")
	var material: ShaderMaterial = lit(GrimePaint.decal_texture("metal", grime), tint, Vector2.ONE, 0.2)
	var length: float = a.distance_to(b)
	var direction: Vector3 = (b - a).normalized()
	var basis: Basis = _basis_along(direction)
	var body: MeshInstance3D = _cylinder("Body", radius, radius, length, 6, material)
	body.transform = Transform3D(basis, (a + b) / 2.0)
	root.add_child(body)
	var flange: float = float(item.get("flange", 1.8))
	var count: int = int(length / flange)
	for i: int in count + 1:
		var ring: MeshInstance3D = _cylinder("Flange%d" % i, radius * 1.45, radius * 1.45, 0.07, 6, material)
		ring.transform = Transform3D(basis, a + direction * minf(flange * float(i), length))
		root.add_child(ring)
	return root


## A shack: a box with a lean-to roof and a few small lit windows on its +Z face. Dark rusted sheet metal.
static func _shack(item: Dictionary, grime: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	var size: Vector3 = vec3(item.get("size", [1.6, 1.4, 1.0]))
	var tint: Color = color(item.get("tint"), "#6a6258")
	var wall: Texture2D = GrimePaint.surface_texture("wall", grime)
	var material: ShaderMaterial = lit(wall, tint, Vector2(maxf(size.x, 1.0) / 2.0, maxf(size.y, 1.0) / 2.0), 0.3)
	root.add_child(_box("Body", size, material, Vector3(0.0, size.y / 2.0, 0.0)))
	if bool(item.get("lean", true)):
		var roof: MeshInstance3D = _box("Roof", Vector3(size.x + 0.3, 0.07, size.z + 0.5), lit(wall, tint.darkened(0.25), Vector2(size.x / 2.0, 1.0), 0.3), Vector3(0.0, size.y + 0.07, 0.0), Vector3(float(item.get("roof_tilt", 8.0)), 0.0, 0.0))
		root.add_child(roof)
	var lights: PackedStringArray = PackedStringArray(item.get("lights", []))
	var seed_value: int = int(item.get("seed", 1))
	for i: int in lights.size():
		var u: float = BattleTextures.noise(i, seed_value, 21)
		var v: float = BattleTextures.noise(i, seed_value, 22)
		var at: Vector3 = Vector3((u - 0.5) * (size.x - 0.5), 0.5 + v * maxf(size.y - 1.0, 0.1), size.z / 2.0 + 0.012)
		root.add_child(_quad("Window%d" % i, Vector2(0.24, 0.18), unlit(null, Color.html(lights[i]), 1.3), at))
	return root


## A row of stacked shacks standing behind a wall (a skyline): `count` boxes along `length`, random widths and
## heights from `seed`, a few lit windows each. The node is laid out along local X, front face toward +Z.
static func _skyline(item: Dictionary, grime: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	var length: float = float(item.get("length", 22.0))
	var count: int = int(item.get("count", 8))
	var seed_value: int = int(item.get("seed", 3))
	var base_y: float = float(item.get("base_y", 3.0))
	var max_height: float = float(item.get("max_height", 5.0))
	var tint: Color = color(item.get("tint"), "#4a443d")
	var palette: PackedStringArray = PackedStringArray(item.get("lights", ["#ffb347", "#ffb347", "#5fe0c8"]))
	var cursor: float = -length / 2.0
	var slot: float = length / float(count)
	for i: int in count:
		var w: float = slot * (0.8 + BattleTextures.noise(i, seed_value, 31) * 0.5)
		var h: float = 1.2 + BattleTextures.noise(i, seed_value, 32) * max_height
		var d: float = 1.6 + BattleTextures.noise(i, seed_value, 33) * 1.2
		var piece: Dictionary = {
			"size": [w, h, d], "tint": tint.darkened(BattleTextures.noise(i, seed_value, 34) * 0.35).to_html(), "lean": i % 2 == 0,
			"lights": [palette[i % palette.size()], palette[(i + 1) % palette.size()]], "seed": seed_value + i,
		}
		var shack: Node3D = _shack(piece, grime)
		shack.position = Vector3(cursor + w / 2.0, base_y, 0.0)
		root.add_child(shack)
		cursor += slot
	return root


## Rain: a box of falling streaks, stepped at 15 fps. `size` [w, d] is the area, `top` the spawn height.
static func _rain(item: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	var size: Vector2 = vec2(item.get("size"), Vector2(22.0, 12.0))
	var top: float = float(item.get("top", 7.0))
	var particles: CPUParticles3D = CPUParticles3D.new()
	particles.name = "Rain"
	particles.amount = int(item.get("amount", 120))
	particles.lifetime = float(item.get("lifetime", 0.7))
	particles.preprocess = 1.0
	particles.fixed_fps = 15
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(size.x / 2.0, 0.1, size.y / 2.0)
	particles.direction = Vector3(0.12, -1.0, 0.08)
	particles.spread = 3.0
	particles.initial_velocity_min = top * 1.3
	particles.initial_velocity_max = top * 1.5
	particles.gravity = Vector3.ZERO
	var origin: Vector2 = vec2(item.get("origin"), Vector2.ZERO)
	particles.position = Vector3(origin.x + size.x / 2.0, top, origin.y + size.y / 2.0)
	var streak: CylinderMesh = CylinderMesh.new()
	streak.top_radius = 0.006
	streak.bottom_radius = 0.006
	streak.height = 0.38
	streak.radial_segments = 3
	streak.rings = 1
	streak.cap_top = false
	streak.cap_bottom = false
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color(item.get("color"), "#56706e")
	material.disable_fog = true
	streak.material = material
	particles.mesh = streak
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(particles)
	return root


## A bare bulb on a cord: sodium glow, a small hard light.
static func _hang_lamp(item: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	var drop: float = float(item.get("drop", 0.6))
	var tint: Color = color(item.get("color"), "#ffb347")
	root.add_child(_box("Cord", Vector3(0.02, drop, 0.02), lit(GrimePaint.decal_texture("metal"), Color(0.1, 0.1, 0.1), Vector2.ONE, 0.0), Vector3(0.0, -drop / 2.0, 0.0)))
	root.add_child(_cylinder("Shade", 0.05, 0.22, 0.16, 6, lit(GrimePaint.decal_texture("metal"), Color(0.3, 0.3, 0.28), Vector2.ONE, 0.2), Vector3(0.0, -drop - 0.04, 0.0)))
	root.add_child(_box("Bulb", Vector3(0.1, 0.1, 0.1), unlit(null, tint, 1.8), Vector3(0.0, -drop - 0.15, 0.0)))
	var light: OmniLight3D = OmniLight3D.new()
	light.name = "Light"
	light.light_color = tint
	light.light_energy = float(item.get("energy", 2.2))
	light.omni_range = float(item.get("range", 5.0))
	light.position = Vector3(0.0, -drop - 0.3, 0.0)
	root.add_child(light)
	return root
