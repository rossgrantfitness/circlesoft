class_name FakeCombatSandbox
extends RefCounted
## A tiny stand-in for the CombatSandbox and its CombatDirector, LockOn and OrbitCamera, for the
## sandbox HUD tests: it emits the contract's signals (docs/pivot/combat_api.md 4.6), answers
## screen_pos_of, and records what the HUD asked it to do. Replace with the real classes when a test
## wants the real thing.

class Actor extends RefCounted:
	var actor_id: StringName = &""
	var team: StringName = &""
	var hp: int = 0
	var hp_max: int = 0

class Director extends RefCounted:
	signal actor_registered(actor_id: StringName, team: StringName)
	signal actor_died(actor_id: StringName)
	signal hp_changed(actor_id: StringName, hp: int, hp_max: int)
	signal hit_landed(info: Dictionary)
	signal parry_judged(info: Dictionary)
	signal perfect_dodge(info: Dictionary)
	signal flare_started(info: Dictionary)
	signal flare_ended
	signal stagger(info: Dictionary)
	signal noise_changed(points: float, fill: float, rank_id: StringName, rank_name: String)
	signal noise_rank_changed(rank_id: StringName, rank_name: String, went_up: bool)
	signal lights_on_changed(active: bool, duration_s: float)
	var feel: FakeFeelKnobs = null
	var fighters: Array = []

	func actors(_team: StringName = &"") -> Array:
		return fighters

class LockOn extends RefCounted:
	signal target_changed(target: Object)

class Camera extends RefCounted:
	signal mode_changed(mode: int)
	var mode: int = 0

	func get_mode() -> int:
		return mode

var director: Director = Director.new()
var lock_on: LockOn = LockOn.new()
var camera: Camera = Camera.new()
var player: Actor = Actor.new()
var positions: Dictionary = {}
var reset_calls: int = 0


func _init() -> void:
	director.feel = FakeFeelKnobs.new()
	player.actor_id = &"red"
	player.team = &"player"
	player.hp = 120
	player.hp_max = 120
	director.fighters = [player]


func add_enemy(id: StringName, at: Vector2, hp: int = 40) -> Actor:
	var enemy: Actor = Actor.new()
	enemy.actor_id = id
	enemy.team = &"enemy"
	enemy.hp = hp
	enemy.hp_max = hp
	director.fighters.append(enemy)
	positions[str(id)] = at
	return enemy


func get_director() -> Director:
	return director


func get_lock_on() -> LockOn:
	return lock_on


func get_camera() -> Camera:
	return camera


func get_player() -> Actor:
	return player


func screen_pos_of(actor_id: StringName, _point: StringName = &"head") -> Vector2:
	return positions.get(str(actor_id), Vector2.ZERO)


func reset_arena() -> void:
	reset_calls += 1
