extends TestCase
## PsxScreen.detach_world() / attach_world(): a room can wait in memory while something else
## (a battle) uses the world, and comes back untouched.

const SCREEN_SCENE: String = "res://scenes/core/psx_screen.tscn"


func _screen() -> PsxScreen:
	var screen: PsxScreen = (load(SCREEN_SCENE) as PackedScene).instantiate() as PsxScreen
	add_to_root(screen)
	return screen


func test_detach_keeps_the_nodes_alive_and_empties_the_world() -> void:
	var screen: PsxScreen = _screen()
	var room: Node3D = Node3D.new()
	room.name = "Room"
	room.position = Vector3(1.0, 2.0, 3.0)
	screen.get_world_root().add_child(room)
	var kept: Array[Node] = screen.detach_world()
	assert_eq(kept.size(), 1)
	assert_eq(screen.get_world_root().get_child_count(), 0, "the world is empty")
	assert_true(is_instance_valid(room), "the room was not freed")
	assert_false(room.is_inside_tree())
	assert_null(room.get_parent())
	own(room)


func test_attach_puts_them_back_as_they_were() -> void:
	var screen: PsxScreen = _screen()
	var first: Node3D = Node3D.new()
	first.name = "First"
	first.position = Vector3(4.0, 0.0, 0.0)
	var second: Node3D = Node3D.new()
	second.name = "Second"
	screen.get_world_root().add_child(first)
	screen.get_world_root().add_child(second)
	var kept: Array[Node] = screen.detach_world()
	var battle: Node3D = Node3D.new()
	battle.name = "Battle"
	screen.get_world_root().add_child(battle)
	screen.clear_world()
	assert_eq(screen.get_world_root().get_child_count(), 0, "clear_world only frees what is in the world")
	assert_true(is_instance_valid(first), "the kept room survived the battle's clear")
	screen.attach_world(kept)
	assert_eq(screen.get_world_root().get_child(0), first)
	assert_eq(screen.get_world_root().get_child(1), second)
	assert_eq(first.position, Vector3(4.0, 0.0, 0.0), "untouched")
	assert_true(first.is_inside_tree())


func test_attach_ignores_nodes_that_are_already_somewhere() -> void:
	var screen: PsxScreen = _screen()
	var node: Node3D = Node3D.new()
	screen.get_world_root().add_child(node)
	var kept: Array[Node] = [node]
	screen.attach_world(kept)
	assert_eq(screen.get_world_root().get_child_count(), 1, "no double add")
