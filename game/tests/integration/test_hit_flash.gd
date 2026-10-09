extends TestCase
## Tuning v1.3 (Ross: chunky hits): the white impact flash (scripts/combat/fx/hit_flash.gd, wired by combat_fx.gd, tuned in
## data/combat/fx.json `hit_flash`) and the landed-hit sound. Numbers are read from the data, never pinned here.


class FakeDirector extends Node:
	signal actor_registered(actor_id: StringName, team: StringName)
	signal actor_died(actor_id: StringName)
	signal move_started(info: Dictionary)
	signal hit_landed(info: Dictionary)
	signal launched(info: Dictionary)
	signal telegraphed(info: Dictionary)
	signal parry_judged(info: Dictionary)
	signal perfect_dodge(info: Dictionary)
	signal flare_started(info: Dictionary)
	signal flare_ended()
	signal lights_on_changed(active: bool, duration_s: float)
	var actors_by_id: Dictionary = {}
	var feel: FeelKnobs = FeelKnobs.load_defaults()
	var scale: float = 0.0       # hit-stop: every fighter's combat time is frozen

	func get_actor(id: StringName) -> Node3D:
		return actors_by_id.get(id) as Node3D

	func delta_for(_actor: Node3D, real_delta: float) -> float:
		return real_delta * scale

	func actors(_team: StringName = &"") -> Array:
		return actors_by_id.values()


class FakeActor extends Node3D:
	var actor_id: StringName = &"grunt_1"
	var team: StringName = &"enemy"
	var move_set_id: StringName = &"grunt"
	var model: Node3D = null

	func anchor(_point: StringName) -> Vector3:
		return global_position + Vector3(0.0, 0.6, 0.0)

	func get_model() -> Node3D:
		return model


var _director: FakeDirector = null
var _red: FakeActor = null
var _foe: FakeActor = null
var _fx: CombatFx = null
var _sounds: Array[StringName] = []
var _original_material: StandardMaterial3D = null
var _original_overlay: StandardMaterial3D = null


func before_each() -> void:
	super.before_each()
	_sounds = []
	_director = FakeDirector.new()
	add_to_root(_director)
	_red = _fighter(&"red", &"player")
	_foe = _fighter(&"grunt_1", &"enemy")
	_director.actors_by_id = {&"red": _red, &"grunt_1": _foe}
	_fx = CombatFx.new()
	_fx.sound_sink = func(id: StringName) -> void: _sounds.append(id)
	add_to_root(_fx)
	_fx.cfg = DataDB.get_dict("combat/fx")
	_fx.bind_parts(_director, _red, null)


## A fighter with a two-mesh model: one mesh has its own override and overlay (like a PS2-shaded enemy mid wind-up), one has neither.
func _fighter(id: StringName, team: StringName) -> FakeActor:
	var actor: FakeActor = FakeActor.new()
	actor.actor_id = id
	actor.team = team
	actor.name = String(id)
	var model: Node3D = Node3D.new()
	model.name = "Model"
	for index: int in 2:
		var mesh: MeshInstance3D = MeshInstance3D.new()
		mesh.name = "mesh_%d" % index
		mesh.mesh = BoxMesh.new()
		model.add_child(mesh)
	_original_material = StandardMaterial3D.new()
	_original_material.albedo_color = Color(0.2, 0.3, 0.9)
	_original_overlay = StandardMaterial3D.new()
	_original_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_original_overlay.albedo_color = Color(1, 0, 0, 0.3)
	(model.get_child(0) as MeshInstance3D).material_override = _original_material
	(model.get_child(0) as MeshInstance3D).material_overlay = _original_overlay
	actor.add_child(model)
	actor.model = model
	add_to_root(actor)
	return actor


func _meshes(actor: FakeActor) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for child: Node in actor.model.get_children():
		if child is MeshInstance3D:
			out.append(child as MeshInstance3D)
	return out


func _hit(extra: Dictionary = {}) -> Dictionary:
	var info: Dictionary = {"attacker": &"red", "target": &"grunt_1", "move_id": &"light_1", "outcome": &"hit", "damage": 8,
		"launch": 0.0, "knockdown": false, "airborne": false, "hit_stop_ms": 100.0, "shake": "light", "spark": "slash",
		"sfx": "combat_hit_light", "position": Vector3(0, 1, 0)}
	info.merge(extra, true)
	return info


func _flash_cfg() -> Dictionary:
	return _fx.cfg["hit_flash"] as Dictionary


func _is_flat_white(mesh: MeshInstance3D) -> bool:
	var material: StandardMaterial3D = mesh.material_override as StandardMaterial3D
	return material != null and material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED \
			and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and mesh.material_overlay == null \
			and is_equal_approx(material.albedo_color.r, 1.0) and is_equal_approx(material.albedo_color.g, 1.0) \
			and is_equal_approx(material.albedo_color.b, 1.0) and is_equal_approx(material.albedo_color.a, 1.0)


# ---- the flash itself ----

func test_a_landed_hit_turns_the_whole_model_flat_opaque_white() -> void:
	assert_true(bool(_flash_cfg()["enabled"]), "on in the shipped data")
	_director.hit_landed.emit(_hit())
	assert_true(_fx.get_hit_flash().is_flashing(_foe))
	for mesh: MeshInstance3D in _meshes(_foe):
		assert_true(_is_flat_white(mesh), "%s is flat white: unshaded, opaque, no tint over it" % mesh.name)


func test_the_flash_lasts_the_data_duration_in_real_time_even_while_the_fighter_is_frozen() -> void:
	var duration: float = float(_flash_cfg()["duration_s"])
	assert_gt(duration, 0.0)
	assert_lt(duration, 0.3, "a split second")
	_director.scale = 0.0                        # hit-stop: combat time stands still
	_director.hit_landed.emit(_hit())
	_fx.step(duration * 0.5)
	assert_true(_fx.get_hit_flash().is_flashing(_foe), "still white at half time")
	assert_almost_eq(_fx.get_hit_flash().time_left_s(_foe), duration * 0.5, 0.0001)
	for mesh: MeshInstance3D in _meshes(_foe):
		assert_true(_is_flat_white(mesh), "white inside the freeze")
	_fx.step(duration * 0.5 + 0.001)
	assert_false(_fx.get_hit_flash().is_flashing(_foe), "snapped back right after the duration")


func test_the_original_materials_come_back_exactly() -> void:
	var meshes: Array[MeshInstance3D] = _meshes(_foe)
	_director.hit_landed.emit(_hit())
	_fx.step(float(_flash_cfg()["duration_s"]) + 0.01)
	assert_true(meshes[0].material_override == _original_material, "the same material object, not a copy")
	assert_true(meshes[0].material_overlay == _original_overlay, "the wind-up tint is back")
	assert_true(meshes[1].material_override == null, "a mesh that had none has none again")
	assert_true(meshes[1].material_overlay == null)
	assert_eq(_fx.get_hit_flash().active_count(), 0)
	assert_almost_eq(_original_material.albedo_color.b, 0.9, 0.0001, "and the material itself was never touched")


func test_a_second_hit_restarts_the_timer_but_keeps_the_true_originals() -> void:
	var meshes: Array[MeshInstance3D] = _meshes(_foe)
	var duration: float = float(_flash_cfg()["duration_s"])
	_director.hit_landed.emit(_hit())
	_fx.step(duration * 0.8)
	_director.hit_landed.emit(_hit())
	assert_almost_eq(_fx.get_hit_flash().time_left_s(_foe), duration, 0.0001, "restarted")
	_fx.step(duration + 0.01)
	assert_true(meshes[0].material_override == _original_material, "not stuck on the flash material")
	assert_true(meshes[1].material_override == null)


func test_the_enemy_dying_or_being_freed_during_the_flash_is_safe() -> void:
	var dying: FakeActor = _fighter(&"grunt_2", &"enemy")
	_director.actors_by_id[&"grunt_2"] = dying
	var meshes: Array[MeshInstance3D] = _meshes(dying)
	_director.hit_landed.emit(_hit({"target": &"grunt_2"}))
	_director.actor_died.emit(&"grunt_2")
	assert_true(_fx.get_hit_flash().is_flashing(dying), "a killing blow still flashes")
	_fx.step(float(_flash_cfg()["duration_s"]) + 0.01)
	assert_true(meshes[0].material_override == _original_material, "a dead enemy that stays on screen is put back too")
	var freed: FakeActor = _fighter(&"grunt_3", &"enemy")
	_director.actors_by_id[&"grunt_3"] = freed
	_director.hit_landed.emit(_hit({"target": &"grunt_3"}))
	freed.free()
	_fx.step(float(_flash_cfg()["duration_s"]) + 0.01)
	assert_eq(_fx.get_hit_flash().active_count(), 0, "a freed model is simply dropped; nothing crashes")


func test_something_else_swapping_the_material_mid_flash_is_left_alone() -> void:
	var meshes: Array[MeshInstance3D] = _meshes(_foe)
	_director.hit_landed.emit(_hit())
	var theirs: StandardMaterial3D = StandardMaterial3D.new()
	meshes[0].material_override = theirs
	_fx.step(float(_flash_cfg()["duration_s"]) + 0.01)
	assert_true(meshes[0].material_override == theirs, "the flash does not stamp over a newer material")
	assert_true(meshes[1].material_override == null, "the other mesh is restored")


func test_clearing_the_effects_puts_everything_back() -> void:
	var meshes: Array[MeshInstance3D] = _meshes(_foe)
	_director.hit_landed.emit(_hit())
	_fx.get_hit_flash().clear()
	assert_true(meshes[0].material_override == _original_material)
	assert_eq(_fx.get_hit_flash().active_count(), 0)


func test_effects_are_left_out_of_the_flash() -> void:
	var mesh_effect: MeshInstance3D = MeshInstance3D.new()
	mesh_effect.mesh = QuadMesh.new()
	var glow: StandardMaterial3D = StandardMaterial3D.new()
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.albedo_color = Color(1.0, 0.7, 0.2, 0.4)
	mesh_effect.material_override = glow
	var additive_effect: MeshInstance3D = MeshInstance3D.new()
	additive_effect.mesh = QuadMesh.new()
	var additive: StandardMaterial3D = StandardMaterial3D.new()
	additive.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	additive.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	additive_effect.material_override = additive
	_foe.model.add_child(additive_effect)
	var cutout: MeshInstance3D = MeshInstance3D.new()
	cutout.mesh = QuadMesh.new()
	var cutout_material: StandardMaterial3D = StandardMaterial3D.new()
	cutout_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	cutout.material_override = cutout_material
	_foe.model.add_child(cutout)
	_foe.model.add_child(mesh_effect)
	var marked: MeshInstance3D = MeshInstance3D.new()
	marked.mesh = QuadMesh.new()
	marked.set_meta(HitFlash.SKIP_META, true)
	_foe.model.add_child(marked)
	var shadow: MeshInstance3D = MeshInstance3D.new()
	shadow.mesh = QuadMesh.new()
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	_foe.model.add_child(shadow)
	_director.hit_landed.emit(_hit())
	assert_true(mesh_effect.material_override == glow, "a see-through glow stays as it is")
	assert_true(additive_effect.material_override == additive, "an additive sparkle stays as it is")
	assert_true(_is_flat_white(cutout), "a solid body with a cut-out texture still flashes")
	assert_true(marked.material_override == null, "a marked mesh stays as it is")
	assert_true(shadow.material_override == null, "a shadow-only mesh stays as it is")


func test_a_boss_part_flashes_its_own_mesh_in_the_boss_model() -> void:
	var boss: Node3D = Node3D.new()
	boss.name = "FakeBoss"
	var relay: MeshInstance3D = MeshInstance3D.new()
	relay.name = "relay_fl"
	relay.mesh = BoxMesh.new()
	boss.add_child(relay)
	var hull: MeshInstance3D = MeshInstance3D.new()
	hull.name = "hull"
	hull.mesh = BoxMesh.new()
	boss.add_child(hull)
	add_to_root(boss)
	var part: BossPart = BossPart.new()
	part.setup(&"relay_fl", {"kind": "relay", "hp": 50, "on_break": {"drops_pair": "fl"}}, boss)
	boss.add_child(part)
	var roots: Array[Node] = HitFlash.roots_for(part)
	assert_eq(roots.size(), 1)
	assert_true(roots[0] == relay, "found by its part id")
	var flash: HitFlash = HitFlash.new()
	assert_true(flash.start(part, roots, 0.07))
	assert_true(_is_flat_white(relay), "the relay is white")
	assert_true(hull.material_override == null, "the rest of the boss is not")
	flash.clear()
	assert_true(relay.material_override == null)


func test_an_actor_can_name_its_own_flash_nodes() -> void:
	var picky: Node3D = Node3D.new()
	var mine: Node3D = Node3D.new()
	picky.add_child(mine)
	picky.set_script(load("res://tests/fixtures/flash_roots_actor.gd"))
	assert_true(picky.has_method("hit_flash_roots"))
	picky.set("roots", [mine])
	add_to_root(picky)
	var roots: Array[Node] = HitFlash.roots_for(picky)
	assert_eq(roots.size(), 1)
	assert_true(roots[0] == mine)


# ---- when it flashes (flash_plan is pure) ----

func test_per_outcome_rules_come_from_the_data() -> void:
	var settings: Dictionary = _flash_cfg()
	var outcomes: Dictionary = settings["outcomes"] as Dictionary
	for outcome: String in outcomes.keys():
		if outcome.begins_with("_"):
			continue
		var wants: bool = bool((outcomes[outcome] as Dictionary).get("on", true))
		var plan: Dictionary = CombatFx.flash_plan({"outcome": outcome, "damage": 5}, settings, false, true, false)
		assert_eq(not plan.is_empty(), wants, "%s follows the data" % outcome)
	assert_false(CombatFx.flash_plan({"outcome": "hit", "damage": 5}, settings, false, true, false).is_empty(), "plain hits flash")
	assert_true(CombatFx.flash_plan({"outcome": "hit", "damage": 5}, settings, false, false, false).is_empty(), "the F12 switch turns it all off")
	var off: Dictionary = settings.duplicate(true)
	off["enabled"] = false
	assert_true(CombatFx.flash_plan({"outcome": "hit", "damage": 5}, off, false, true, false).is_empty(), "enabled=false in the data")


func test_a_hit_that_took_nothing_off_does_not_flash() -> void:
	var settings: Dictionary = _flash_cfg()
	assert_true(bool(settings["require_damage"]))
	assert_true(CombatFx.flash_plan({"outcome": "hit", "damage": 0}, settings, false, true, false).is_empty(), "a sealed core / a clink")
	var anyway: Dictionary = settings.duplicate(true)
	anyway["require_damage"] = false
	assert_false(CombatFx.flash_plan({"outcome": "hit", "damage": 0}, anyway, false, true, false).is_empty())


func test_a_dimmer_outcome_flashes_greyer_and_shorter() -> void:
	var settings: Dictionary = {"enabled": true, "duration_s": 0.1, "color": "#ffffff", "outcomes": {"hit": {"on": true}, "armored": {"on": true, "brightness": 0.5, "duration_mult": 0.5}}}
	var full: Dictionary = CombatFx.flash_plan({"outcome": "hit", "damage": 3}, settings, false, true, false)
	var dim: Dictionary = CombatFx.flash_plan({"outcome": "armored", "damage": 3}, settings, false, true, false)
	assert_almost_eq(float(full["duration_s"]), 0.1, 0.0001)
	assert_almost_eq(float(dim["duration_s"]), 0.05, 0.0001)
	assert_almost_eq((dim["color"] as Color).r, 0.5, 0.0001)
	assert_almost_eq((full["color"] as Color).r, 1.0, 0.0001)


func test_blocked_hits_do_not_flash_in_the_shipped_data() -> void:
	_director.hit_landed.emit(_hit({"outcome": &"blocked", "damage": 1}))
	assert_false(_fx.get_hit_flash().is_flashing(_foe))


func test_red_does_not_flash_unless_her_toggle_is_on() -> void:
	_director.hit_landed.emit(_hit({"target": &"red", "attacker": &"grunt_1"}))
	assert_false(_fx.get_hit_flash().is_flashing(_red), "off by default")
	_director.feel.set_value("hit_flash_red_on", true)
	_director.hit_landed.emit(_hit({"target": &"red", "attacker": &"grunt_1"}))
	assert_true(_fx.get_hit_flash().is_flashing(_red), "the F12 toggle turns it on")
	_fx.get_hit_flash().clear()
	_director.feel.set_value("hit_flash_red_on", false)
	_director.feel.set_value("hit_flash_on", false)
	_director.hit_landed.emit(_hit())
	assert_false(_fx.get_hit_flash().is_flashing(_foe), "and the master switch beats everything")


func test_the_flash_signal_carries_the_data_duration() -> void:
	var seen: Array[float] = []
	_fx.flash_started.connect(func(_target: Node, seconds: float) -> void: seen.append(seconds))
	_director.hit_landed.emit(_hit())
	assert_eq(seen.size(), 1)
	assert_almost_eq(seen[0], float(_flash_cfg()["duration_s"]), 0.0001)


# ---- the landed-hit sound ----

func test_every_landed_hit_plays_a_sound_with_a_little_pitch_variation() -> void:
	var spread: float = float((_fx.cfg["hit_sound"] as Dictionary)["pitch_var"])
	assert_gt(spread, 0.0, "variation is on in the data")
	var pitches: Dictionary = {}
	for index: int in 12:
		_sounds.clear()
		_fx._frame_plays.clear()
		_director.hit_landed.emit(_hit({"sfx": "combat_hit_light"}))
		assert_eq(_sounds.size(), 1, "one sound per landed hit")
		assert_eq(_sounds[0], &"combat_hit_light")
		assert_ge(_fx.last_pitch_mult, 1.0 - spread - 0.0001)
		assert_le(_fx.last_pitch_mult, 1.0 + spread + 0.0001)
		pitches[snappedf(_fx.last_pitch_mult, 0.0001)] = true
	assert_gt(pitches.size(), 3, "it does not sound the same every time")


func test_a_hit_with_no_sound_of_its_own_still_plays_by_weight() -> void:
	_director.hit_landed.emit(_hit({"sfx": "", "shake": "heavy"}))
	assert_eq(_sounds[0], &"combat_hit_heavy")
	_sounds.clear()
	_fx._frame_plays.clear()
	_director.hit_landed.emit(_hit({"sfx": "", "shake": "light"}))
	assert_eq(_sounds[0], &"combat_hit_light")


func test_the_hit_sounds_exist_in_the_sound_data() -> void:
	var sounds: Dictionary = _fx.cfg["sounds"] as Dictionary
	var defs: Dictionary = (DataDB.get_dict("audio/sfx")["sfx"]) as Dictionary
	for key: String in ["hit_light", "hit_heavy", "hit_air", "launch"]:
		assert_true(defs.has(str(sounds[key])), "%s is registered" % sounds[key])
