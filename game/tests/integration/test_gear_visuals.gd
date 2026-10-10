extends TestCase
## GearVisuals (scripts/combat/gear_visuals.gd, docs/pivot/combat_api.md 4.7): the sword on Red's weapon_socket.

const RED_PATH: String = "res://art/final/characters/red/red_ross_v1_rigged.glb"
const SIX: Array[StringName] = [&"katana_cyan", &"heavy_duty", &"hook_cyan", &"glass_core", &"machete", &"twin_orange"]


func _red_with_gear() -> Array:
	var model: Node3D = (load(RED_PATH) as PackedScene).instantiate() as Node3D
	add_to_root(model)
	var gear: GearVisuals = GearVisuals.new()
	model.add_child(gear)
	return [model, gear]


func test_equip_hangs_the_sword_on_the_weapon_socket() -> void:
	var pair: Array = _red_with_gear()
	var model: Node3D = pair[0]
	var gear: GearVisuals = pair[1]
	assert_true(gear.equip_sword(&"katana_cyan"))
	assert_eq(gear.current_sword(), &"katana_cyan")
	var sword: Node3D = gear.get_sword()
	assert_not_null(sword)
	var attach: BoneAttachment3D = sword.get_parent() as BoneAttachment3D
	assert_not_null(attach, "the sword rides a BoneAttachment3D")
	assert_eq(attach.bone_name, "weapon_socket")
	assert_true(attach.get_parent() is Skeleton3D)
	assert_eq(sword.position, Vector3.ZERO, "no offset: the file's origin is the grip")
	assert_eq(model.find_children("*", "BoneAttachment3D", true, false).size(), 1)


func test_swapping_changes_the_mesh_and_keeps_one_sword() -> void:
	var pair: Array = _red_with_gear()
	var gear: GearVisuals = pair[1]
	var seen: Dictionary = {}
	for id: StringName in SIX:
		assert_true(gear.equip_sword(id), String(id))
		var meshes: Array[Node] = gear.get_sword().find_children("*", "MeshInstance3D", true, false)
		assert_eq(meshes.size(), 1)
		seen[(meshes[0] as MeshInstance3D).mesh.get_aabb().size] = true
		var attach: Node = gear.get_sword().get_parent()
		assert_eq(attach.get_child_count(), 1, "the old sword is gone")
	assert_ge(seen.size(), 5, "six different swords")


func test_sword_changed_fires_and_unknown_ids_change_nothing() -> void:
	var pair: Array = _red_with_gear()
	var gear: GearVisuals = pair[1]
	var heard: Array[StringName] = []
	gear.sword_changed.connect(func(id: StringName) -> void: heard.append(id))
	gear.equip_sword(&"machete")
	assert_false(gear.equip_sword(&"no_such_sword"))
	assert_eq(gear.current_sword(), &"machete")
	assert_eq(heard, [&"machete"])


func test_blade_points_lie_along_the_blade_by_the_data() -> void:
	var pair: Array = _red_with_gear()
	var gear: GearVisuals = pair[1]
	assert_true(gear.blade_points().is_empty(), "nothing before a sword is equipped")
	gear.equip_sword(&"katana_cyan")
	var points: Dictionary = gear.blade_points()
	var base: Node3D = points["base"]
	var tip: Node3D = points["tip"]
	var trail: Dictionary = gear.sword_entry(&"katana_cyan")["trail"]
	assert_almost_eq(base.position.y, float(trail["base_m"]), 0.001)
	assert_almost_eq(tip.position.y, float(trail["tip_m"]), 0.001)
	assert_eq(base.position.x, 0.0)
	assert_lt(base.position.y, tip.position.y)


func test_the_rack_lists_all_six_and_every_model_loads() -> void:
	var pair: Array = _red_with_gear()
	var gear: GearVisuals = pair[1]
	assert_eq(gear.rack_ids(), SIX)
	assert_eq(gear.default_sword(), &"katana_cyan")
	for id: StringName in SIX:
		var entry: Dictionary = gear.sword_entry(id)
		assert_true(ResourceLoader.exists(str(entry["model"])), String(id))
		assert_true(Color.html(str(entry["trail"]["color"])).a > 0.0)
		assert_lt(float(entry["trail"]["base_m"]), float(entry["trail"]["tip_m"]))
		assert_gt(gear.trail_color(id).get_luminance(), 0.2, "a trail colour that will glow")


func test_a_model_without_the_socket_falls_back_with_a_warning() -> void:
	var plain: Node3D = Node3D.new()
	add_to_root(plain)
	var gear: GearVisuals = GearVisuals.new()
	plain.add_child(gear)
	assert_true(gear.equip_sword(&"katana_cyan"), "still equips, at a fixed offset")
	assert_eq(gear.get_sword().get_parent().position, GearVisuals.FALLBACK_OFFSET)
	var hand_only: Skeleton3D = Skeleton3D.new()
	hand_only.add_bone("hand_r")
	var model: Node3D = Node3D.new()
	model.add_child(hand_only)
	add_to_root(model)
	var gear2: GearVisuals = GearVisuals.new()
	model.add_child(gear2)
	assert_true(gear2.equip_sword(&"machete"))
	assert_eq((gear2.get_sword().get_parent() as BoneAttachment3D).bone_name, "hand_r", "hand_r when there is no weapon_socket")
