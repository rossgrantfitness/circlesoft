class_name BossKit
extends RefCounted
## Set-up for the Hushmaster tests: a flat arena with the named markers the fight looks for, a hand-stepped director, the real
## Red, and a BossFight with a stub room (no robot stage). Everything ticks from `frames()` after a physics frame.

const RED_SCENE: String = "res://scenes/actors/action_player.tscn"
const DT: float = 1.0 / 60.0

class StubRoom extends Node3D:
	var director: CombatDirector = null
	var hero: ActionPlayer = null
	var checkpoints: Array[Dictionary] = []
	var room_id: String = "kasp_arena"
	var entry: Dictionary = {}
	var entry_spawn: String = "from_j5"

	func get_director() -> CombatDirector:
		return director

	func get_player() -> ActionPlayer:
		return hero

	func set_phase_checkpoint(spawn: String, form: StringName, full_health: bool = true) -> void:
		checkpoints.append({"spawn": spawn, "form": form, "full_health": full_health})

var test: TestCase = null
var room: StubRoom = null
var director: CombatDirector = null
var red: ActionPlayer = null
var fight: BossFight = null
var boss: Hushmaster = null
var hits: Array[Dictionary] = []
var events: Array[StringName] = []


func _init(owner_test: TestCase) -> void:
	test = owner_test


func arena(start_fight: bool = true, rng_seed: int = 3) -> void:
	room = StubRoom.new()
	test.add_to_root(room)
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.collision_layer = CombatLayers.bit(CombatLayers.WORLD)
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(120, 1, 120)
	shape_node.shape = box
	floor_body.add_child(shape_node)
	room.add_child(floor_body)
	floor_body.position = Vector3(0, -0.5, 0)
	_marker(&"hushmaster_start", Vector3(0, 0, 0))
	_marker(&"drone_hatch_a", Vector3(-10, 0, -6))
	_marker(&"drone_hatch_b", Vector3(10, 0, -6))
	_marker(&"drone_hatch_c", Vector3(0, 0, 11))
	_marker(&"turret_k_nw", Vector3(-13, 0, -14))
	_marker(&"turret_k_ne", Vector3(13, 0, -14))
	_marker(&"turret_k_e", Vector3(18, 0, 8))
	director = CombatDirector.new()
	director.feel = FeelKnobs.load_defaults()
	director.feel.set_value("enemy_damage_scale", 1.0)
	director.sync_to_wall_clock = false
	room.add_child(director)
	director.set_physics_process(false)
	room.director = director
	red = (load(RED_SCENE) as PackedScene).instantiate() as ActionPlayer
	red.read_engine_input = false
	room.add_child(red)
	red.set_physics_process(false)
	red.global_position = Vector3(0, 0.02, 9)
	room.hero = red
	director.hit_landed.connect(func(info: Dictionary) -> void: hits.append(info))
	director.hack_cast.connect(func(_info: Dictionary) -> void: casts_count += 1)
	await test.tree.physics_frame
	await test.tree.physics_frame
	if start_fight:
		await begin(rng_seed)


func _marker(marker_name: StringName, at: Vector3) -> void:
	var node: Marker3D = Marker3D.new()
	node.name = String(marker_name)
	room.add_child(node)
	node.position = at


func begin(rng_seed: int = 3, spawn: String = "from_j5") -> void:
	fight = BossFight.new()
	fight.run_on_physics = false
	fight.seed_value = rng_seed
	room.add_child(fight)
	fight.boss_event.connect(func(id: StringName) -> void: events.append(id))
	room.entry_spawn = spawn
	fight.setup(room, director, red, "hushmaster.json")
	fight.start_for_spawn(spawn)
	boss = fight.hushmaster
	if boss != null:
		boss.set_physics_process(false)
	for turret: WallTurret in fight.turrets:
		turret.set_physics_process(false)
	await frames(10)


func frames(count: int) -> void:
	for i: int in range(count):
		await test.tree.physics_frame
		director.tick(DT)
		red.tick(DT)
		if boss != null and is_instance_valid(boss):
			boss.tick(DT)
		for drone: ActionEnemy in _extras():
			drone.tick(DT)
		if fight != null:
			fight.tick(DT)


## Everything else that fights and must be ticked by hand: drones the boss dropped and the pylon turrets.
func _extras() -> Array[ActionEnemy]:
	var out: Array[ActionEnemy] = []
	if boss != null and is_instance_valid(boss):
		for drone: ActionEnemy in boss.drones():
			drone.set_physics_process(false)
			out.append(drone)
	if fight != null:
		for turret: WallTurret in fight.turrets:
			if is_instance_valid(turret):
				out.append(turret)
	return out


func until(done: Callable, limit: int = 600) -> int:
	var count: int = 0
	while not bool(done.call()) and count < limit:
		await frames(1)
		count += 1
	return count


func hits_on_red() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for info: Dictionary in hits:
		if info["target"] == red.actor_id:
			out.append(info)
	return out


func break_pair(pair: StringName) -> void:
	var relay: BossPart = boss.relay_of(pair)
	relay.apply_hit({"damage": relay.hp, "source": "hack", "outcome": &"hit", "move_id": &"hack_zap"})


func place_red(at: Vector3) -> void:
	red.global_position = at


func moves_started_hack() -> int:
	return casts_count


var casts_count: int = 0


func caster_select(slot: int) -> void:
	red.hack_caster().select_slot(slot)
