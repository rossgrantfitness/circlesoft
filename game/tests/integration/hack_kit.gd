class_name HackKit
extends RefCounted
## Shared set-up for the hack tests (test_hacks.gd, test_hijack.gd, test_lock_targets.gd): a floor, a CombatDirector that
## is stepped by hand, the real Red and real Grunts. Everything is ticked from `frames()` after a physics frame, so Hitbox
## queries and the Zap Drone's own physics step line up with the hand-stepped fighters.

const RED_SCENE: String = "res://scenes/actors/action_player.tscn"
const GRUNT_SCENE: String = "res://scenes/actors/enemies/grunt.tscn"
const BRUTE_SCENE: String = "res://scenes/actors/enemies/brute.tscn"
const DRONE_SCENE: String = "res://scenes/actors/enemies/signals_drone.tscn"
const TURRET_SCENE: String = "res://scenes/actors/enemies/wall_turret.tscn"
const DT: float = 1.0 / 60.0

var test: TestCase = null
var director: CombatDirector = null
var red: ActionPlayer = null
var enemies: Array[ActionEnemy] = []
var texts: Array[String] = []
var refused: Array[Dictionary] = []
var casts: Array[Dictionary] = []
var hits: Array[Dictionary] = []
var moves: Array[StringName] = []


func _init(owner_test: TestCase) -> void:
	test = owner_test


## A floor, the director (hand-stepped, fake clock), and Red at the origin facing +Z.
func arena(attack_enemies: bool = false) -> void:
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.collision_layer = CombatLayers.bit(CombatLayers.WORLD)
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(120, 1, 120)
	shape_node.shape = box
	floor_body.add_child(shape_node)
	test.add_to_root(floor_body)
	floor_body.global_position = Vector3(0, -0.5, 0)
	director = CombatDirector.new()
	director.feel = FeelKnobs.load_defaults()
	director.feel.set_value("enemies_attack", attack_enemies)
	director.feel.set_value("enemy_dodge_scale", 0.0)
	director.feel.set_value("enemy_block_scale", 0.0)
	director.sync_to_wall_clock = false
	test.add_to_root(director)
	director.set_physics_process(false)
	red = (load(RED_SCENE) as PackedScene).instantiate() as ActionPlayer
	red.read_engine_input = false
	test.add_to_root(red)
	red.set_physics_process(false)
	red.global_position = Vector3(0, 0.02, 0)
	director.hack_cast.connect(func(info: Dictionary) -> void: casts.append(info))
	director.hack_refused.connect(func(info: Dictionary) -> void: refused.append(info))
	director.hit_landed.connect(func(info: Dictionary) -> void: hits.append(info))
	red.hack_pressed.connect(func(info: Dictionary) -> void: texts.append(str(info["text"])))
	red.move_started.connect(func(move_id: StringName) -> void: moves.append(move_id))
	await test.tree.physics_frame
	await test.tree.physics_frame
	await frames(10)


func grunt(at: Vector3, tags: Array[String] = []) -> ActionEnemy:
	var enemy: ActionEnemy = (load(GRUNT_SCENE) as PackedScene).instantiate() as ActionEnemy
	enemy.position = at
	test.add_to_root(enemy)
	enemy.set_physics_process(false)
	for tag: String in tags:
		enemy.tags.append(tag)
	enemies.append(enemy)
	return enemy


## Any enemy scene at `at`, facing `yaw` radians, ticked by `frames()`.
func spawn(scene_path: String, at: Vector3, yaw: float = 0.0) -> ActionEnemy:
	var enemy: ActionEnemy = (load(scene_path) as PackedScene).instantiate() as ActionEnemy
	enemy.position = at
	enemy.rotation.y = yaw
	test.add_to_root(enemy)
	enemy.set_physics_process(false)
	enemies.append(enemy)
	return enemy


## Lets bodies settle on the floor after spawning.
func settle() -> void:
	await test.tree.physics_frame
	await test.tree.physics_frame
	await frames(10)


## Steps the fight `count` physics frames: the director first, then Red, then every enemy.
func frames(count: int) -> void:
	for i: int in range(count):
		await test.tree.physics_frame
		director.tick(DT)
		red.tick(DT)
		for enemy: ActionEnemy in enemies:
			if is_instance_valid(enemy):
				enemy.tick(DT)


## Runs until `done` is true or `limit` frames pass. Returns how many frames it took.
func until(done: Callable, limit: int = 240) -> int:
	var count: int = 0
	while not bool(done.call()) and count < limit:
		await frames(1)
		count += 1
	return count


## Press the hack button for a frame and let go.
func tap_hack() -> void:
	red.press(&"heavy")
	await frames(1)
	red.release(&"heavy")


func caster() -> HackCaster:
	return red.hack_caster()


func battery() -> HackBattery:
	return director.battery


func hits_from(source: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for info: Dictionary in hits:
		if str(info.get("source", "sword")) == source:
			out.append(info)
	return out


func refusals(reason: StringName) -> int:
	var count: int = 0
	for info: Dictionary in refused:
		if info["reason"] == reason:
			count += 1
	return count


func count_nodes(kind: GDScript) -> int:
	var count: int = 0
	var stack: Array[Node] = [test.tree.root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node.get_script() == kind:
			count += 1
		for child: Node in node.get_children():
			stack.append(child)
	return count
