class_name FakeCombatSandbox
extends RefCounted
## The sandbox as the HUD tests see it: the REAL CombatDirector, CombatActor and FeelKnobs (nothing
## else in the HUD tests is faked about the combat model), plus the three things the arena scene owns:
## screen_pos_of, a reset, and the lock-on and camera signals (tiny stubs). Tests emit the director's
## own signals to play a fight at the HUD. Free it with free_nodes() when the test ends.

class StubLockOn extends RefCounted:
	signal target_changed(target: Object)

## Red as the HUD sees her: a fighter that can announce the hack button (ActionPlayer.hack_pressed).
class StubPlayer extends CombatActor:
	signal hack_pressed(info: Dictionary)
	signal dash_refused
	## What ActionPlayer.get_dash_charges() answers (the HUD's dash pips): {count, max, fraction}.
	var dash_charges: Dictionary = {"count": 5, "max": 5, "fraction": 0.0}

	func get_dash_charges() -> Dictionary:
		return dash_charges

class StubCamera extends RefCounted:
	signal mode_changed(mode: int)
	var mode: int = 0

	func get_mode() -> int:
		return mode

var director: CombatDirector = CombatDirector.new()
var lock_on: StubLockOn = StubLockOn.new()
var camera: StubCamera = StubCamera.new()
var player: StubPlayer = null
var positions: Dictionary = {}
var reset_calls: int = 0
var _nodes: Array[Node] = []


func _init() -> void:
	director.feel = FeelKnobs.load_defaults()
	director.sync_to_wall_clock = false
	player = StubPlayer.new()
	player.actor_id = &"red"
	player.team = &"player"
	player.hp = 120
	player.hp_max = 120
	_nodes.append(player)
	director.register(player)
	_nodes.append(director)


func _make_actor(id: StringName, team: StringName, hp: int) -> CombatActor:
	var actor: CombatActor = CombatActor.new()
	actor.actor_id = id
	actor.team = team
	actor.hp = hp
	actor.hp_max = hp
	_nodes.append(actor)
	return actor


func add_enemy(id: StringName, at: Vector2, hp: int = 40) -> CombatActor:
	var enemy: CombatActor = _make_actor(id, &"enemy", hp)
	director.register(enemy)
	positions[str(id)] = at
	return enemy


func free_nodes() -> void:
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()


func get_director() -> CombatDirector:
	return director


func get_feel() -> FeelKnobs:
	return director.feel


func get_lock_on() -> StubLockOn:
	return lock_on


func get_camera() -> StubCamera:
	return camera


func get_player() -> StubPlayer:
	return player


func screen_pos_of(actor_id: StringName, _point: StringName = &"head") -> Vector2:
	return positions.get(str(actor_id), Vector2.ZERO)


func reset_arena() -> void:
	reset_calls += 1
