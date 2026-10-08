extends TestCase
## SwordTrail (scripts/combat/fx/sword_trail.gd): the ribbon behind a swing, on the fighter's combat clock.


func _sample(x: float, age: float) -> Dictionary:
	return {"base": Vector3(x, 0.0, 0.0), "tip": Vector3(x, 0.6, 0.0), "age": age}


func test_prune_drops_old_samples_and_caps_the_count() -> void:
	var samples: Array[Dictionary] = [_sample(0.0, 0.5), _sample(1.0, 0.3), _sample(2.0, 0.1), _sample(3.0, 0.0)]
	SwordTrail.prune(samples, 0.22, 24)
	assert_eq(samples.size(), 2, "the two older than 0.22 s are gone")
	var many: Array[Dictionary] = []
	for i: int in 40:
		many.append(_sample(float(i), 0.0))
	SwordTrail.prune(many, 0.22, 24)
	assert_eq(many.size(), 24)
	assert_eq((many[0]["base"] as Vector3).x, 16.0, "the oldest went first")


func test_ribbon_arrays_make_two_vertices_per_sample_and_fade_with_age() -> void:
	var samples: Array[Dictionary] = [_sample(0.0, 0.2), _sample(1.0, 0.1), _sample(2.0, 0.0)]
	var arrays: Array = SwordTrail.ribbon_arrays(samples, 0.2, Color(0.3, 0.8, 1.0, 1.0))
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	assert_eq(vertices.size(), 6)
	assert_eq(colors.size(), 6)
	assert_eq(vertices[0], Vector3(0.0, 0.0, 0.0), "base then tip")
	assert_eq(vertices[1], Vector3(0.0, 0.6, 0.0))
	assert_almost_eq(colors[0].a, 0.0, 0.001, "the oldest is gone")
	assert_gt(colors[2].a, colors[0].a)
	assert_almost_eq(colors[4].a, 1.0, 0.001, "the newest is full")
	assert_eq(uvs[0].x, 0.0, "base side")
	assert_eq(uvs[1].x, 1.0, "tip side")
	assert_almost_eq(colors[5].r, 0.3, 0.001, "tint kept")


func _trail_with_markers() -> Array:
	var holder: Node3D = Node3D.new()
	add_to_root(holder)
	var base: Node3D = Node3D.new()
	var tip: Node3D = Node3D.new()
	holder.add_child(base)
	holder.add_child(tip)
	var trail: SwordTrail = SwordTrail.new()
	holder.add_child(trail)
	trail.bind_blade({"base": base, "tip": tip})
	return [trail, base, tip]


func test_it_only_records_while_active_and_when_the_blade_moves() -> void:
	var parts: Array = _trail_with_markers()
	var trail: SwordTrail = parts[0]
	var tip: Node3D = parts[2]
	trail.step(0.016)
	assert_eq(trail.sample_count(), 0, "inactive records nothing")
	trail.set_active(true)
	trail.step(0.016)
	assert_eq(trail.sample_count(), 1)
	trail.step(0.016)
	assert_eq(trail.sample_count(), 1, "a still sword adds nothing")
	tip.position = Vector3(0.3, 0.5, 0.0)
	trail.step(0.016)
	assert_eq(trail.sample_count(), 2)
	trail.set_active(false)
	tip.position = Vector3(0.9, 0.5, 0.0)
	trail.step(0.016)
	assert_eq(trail.sample_count(), 2, "off: what is left only fades")
	for i: int in 20:
		trail.step(0.02)
	assert_eq(trail.sample_count(), 0, "and goes after max_age_s")


func test_a_frozen_clock_freezes_the_trail() -> void:
	var parts: Array = _trail_with_markers()
	var trail: SwordTrail = parts[0]
	var tip: Node3D = parts[2]
	trail.set_active(true)
	trail.step(0.016)
	tip.position = Vector3(0.4, 0.4, 0.0)
	trail.step(0.016)
	var count: int = trail.sample_count()
	trail.set_time_scale(0.0)
	trail._process(1.0)
	assert_eq(trail.sample_count(), count, "hit-stop: nothing ages, nothing is added")
	trail.set_time_scale(1.0)
	trail.set_active(false)
	trail._process(1.0)
	assert_eq(trail.sample_count(), 0, "a second of real time later it has all faded")


func test_the_trail_never_casts_a_shadow_and_uses_its_shader() -> void:
	var parts: Array = _trail_with_markers()
	var trail: SwordTrail = parts[0]
	var ribbon: MeshInstance3D = trail.get_node("Ribbon") as MeshInstance3D
	assert_eq(ribbon.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	assert_eq((ribbon.material_override as ShaderMaterial).shader.resource_path, SwordTrail.SHADER_PATH)
	assert_true(trail.top_level, "it hangs in the world, not on the sword")
