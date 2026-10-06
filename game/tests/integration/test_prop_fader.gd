extends TestCase
## Milestone 1 step 8: a prop between the camera and Red fades (via the fade_amount shader
## parameter) and returns to solid when the way is clear.

const DT: float = 1.0 / 60.0
const SETTLE_FRAMES: int = 120
const FADE_PARAM: String = "fade_amount"
const FADE_SHADER_CODE: String = "shader_type spatial;\nuniform float fade_amount = 0.0;\nvoid fragment() { ALPHA = 1.0 - fade_amount; }\n"

var _camera: Camera3D = null
var _target: Node3D = null
var _fader: PropFader = null
var _shared_material: ShaderMaterial = null


func _tuning() -> FieldTuning:
	return FieldTuning.from_db(tree.root.get_node("DataDB"))


func _make_scene(orthographic: bool = false) -> void:
	_camera = add_to_root(Camera3D.new()) as Camera3D
	_camera.global_transform = Transform3D(DioramaMath.orientation(42.0, 0.0), Vector3(0.0, 7.0, 7.5))
	if orthographic:
		_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		_camera.size = 10.0
	_target = add_to_root(Node3D.new()) as Node3D
	var shader: Shader = Shader.new()
	shader.code = FADE_SHADER_CODE
	_shared_material = ShaderMaterial.new()
	_shared_material.shader = shader
	_fader = PropFader.new()
	_fader.auto_update = false
	add_to_root(_fader)
	_fader.set_tuning(_tuning())
	_fader.set_target(_target)
	_fader.set_camera(_camera)


func _make_prop(at: Vector3) -> Node3D:
	var prop: Node3D = add_to_root(Node3D.new()) as Node3D
	prop.add_to_group(PropFader.OCCLUDER_GROUP)
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(1.0, 3.0, 1.0)
	mesh_instance.mesh = box
	mesh_instance.material_override = null
	box.material = _shared_material
	prop.add_child(mesh_instance)
	prop.global_position = at
	return prop


func _run(frames: int) -> void:
	for frame: int in frames:
		_fader.update_fades(DT)


func _applied(prop: Node3D) -> Variant:
	var mesh_instance: MeshInstance3D = prop.get_child(0) as MeshInstance3D
	var material: ShaderMaterial = mesh_instance.get_surface_override_material(0) as ShaderMaterial
	if material == null:
		return null
	return material.get_shader_parameter(FADE_PARAM)


func test_occluding_prop_fades_and_is_restored() -> void:
	_make_scene()
	var tuning: FieldTuning = _tuning()
	# Camera is up and toward +Z, so a pillar at +Z a bit in front of Red hides her.
	var pillar: Node3D = _make_prop(Vector3(0.0, 1.5, 2.5))
	_run(SETTLE_FRAMES)
	assert_almost_eq(_fader.get_fade(pillar), tuning.fade_max_amount, 0.0001, "pillar fades out")
	assert_almost_eq(float(_applied(pillar)), tuning.fade_max_amount, 0.0001, "fade_amount set on the material")
	# Red walks clear of it.
	_target.global_position = Vector3(-6.0, 0.0, 0.0)
	_run(SETTLE_FRAMES)
	assert_almost_eq(_fader.get_fade(pillar), 0.0, 0.0001, "pillar comes back")
	assert_almost_eq(float(_applied(pillar)), 0.0, 0.0001, "fade_amount restored on the material")


func test_fade_is_gradual() -> void:
	_make_scene()
	var pillar: Node3D = _make_prop(Vector3(0.0, 1.5, 2.5))
	_fader.update_fades(DT)
	var after_one: float = _fader.get_fade(pillar)
	assert_gt(after_one, 0.0)
	assert_lt(after_one, _tuning().fade_max_amount, "eases, does not pop")


func test_props_not_in_the_way_stay_solid() -> void:
	_make_scene()
	var beside: Node3D = _make_prop(Vector3(5.0, 1.5, 2.5))
	var behind: Node3D = _make_prop(Vector3(0.0, 1.5, -4.0))
	var blocking: Node3D = _make_prop(Vector3(0.0, 1.5, 2.5))
	_run(SETTLE_FRAMES)
	assert_almost_eq(_fader.get_fade(beside), 0.0, 0.0001, "beside")
	assert_almost_eq(_fader.get_fade(behind), 0.0, 0.0001, "behind Red")
	assert_gt(_fader.get_fade(blocking), 0.5)


func test_only_group_members_fade() -> void:
	_make_scene()
	var plain: Node3D = _make_prop(Vector3(0.0, 1.5, 2.5))
	plain.remove_from_group(PropFader.OCCLUDER_GROUP)
	_run(SETTLE_FRAMES)
	assert_almost_eq(_fader.get_fade(plain), 0.0, 0.0001)
	assert_null(_applied(plain), "untagged props are never touched")


func test_shared_material_is_not_modified() -> void:
	_make_scene()
	var pillar: Node3D = _make_prop(Vector3(0.0, 1.5, 2.5))
	var other: Node3D = _make_prop(Vector3(6.0, 1.5, 2.5))
	_run(SETTLE_FRAMES)
	assert_gt(float(_applied(pillar)), 0.5)
	var shared_value: Variant = _shared_material.get_shader_parameter(FADE_PARAM)
	assert_true(shared_value == null or is_zero_approx(float(shared_value)), "shared material untouched")
	assert_null(_applied(other), "a prop that never faded keeps its own material")


func test_works_with_an_orthographic_camera() -> void:
	_make_scene(true)
	var pillar: Node3D = _make_prop(Vector3(0.0, 1.5, 2.5))
	_run(SETTLE_FRAMES)
	assert_gt(_fader.get_fade(pillar), 0.5, "ortho: pillar in front fades")
	_target.global_position = Vector3(-6.0, 0.0, 0.0)
	_run(SETTLE_FRAMES)
	assert_almost_eq(_fader.get_fade(pillar), 0.0, 0.0001, "ortho: restored")


func test_pure_helpers() -> void:
	var box: AABB = AABB(Vector3(-0.5, 0.0, 1.0), Vector3(1.0, 3.0, 1.0))
	assert_true(PropFader.is_occluding(Vector3(0, 0.5, 0), Vector3(0, 7, 7.5), box, 0.0))
	assert_false(PropFader.is_occluding(Vector3(5, 0.5, 0), Vector3(5, 7, 7.5), box, 0.0), "clear")
	assert_true(PropFader.is_occluding(Vector3(0.7, 0.5, 0), Vector3(0.7, 7, 7.5), box, 0.4), "radius counts Red's width")
	assert_false(PropFader.is_occluding(Vector3.ZERO, Vector3(0, 0, 9), AABB(), 1.0), "empty box never occludes")
	assert_almost_eq(PropFader.step_fade(0.0, true, 0.1, 8.0, 4.0, 0.85), 0.8, 0.0001)
	assert_almost_eq(PropFader.step_fade(0.8, true, 0.1, 8.0, 4.0, 0.85), 0.85, 0.0001, "capped at max")
	assert_almost_eq(PropFader.step_fade(0.5, false, 0.1, 8.0, 4.0, 0.85), 0.1, 0.0001)
	assert_almost_eq(PropFader.step_fade(0.1, false, 0.5, 8.0, 4.0, 0.85), 0.0, 0.0001, "floored at solid")
