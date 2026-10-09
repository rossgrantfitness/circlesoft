extends TestCase
## VS-33, QA regression checks on the real slice rooms (docs/bug_log.md). Each known bug is checked with known_bug(): the test
## passes while the bug stands (XFAIL with the bug id in the log) and prints XPASS once it is fixed, so the marker can come out.

const ROOM_ID: String = "junk_j1"
const SPAWN: String = "from_market"
const FIGHT_ID: String = "enc_j1_pair"
const RESPAWN_WAIT_FRAMES: int = 420        # the sandbox's respawn_s is 6 s; physics runs at 60 Hz, so 7 s is enough to see it

var _main: Main = null
var _router: Node = null
var _state: Node = null
var _manager: Node = null
var _old_dir: String = ""
var _dir: String = ""


func before_each() -> void:
	_state = tree.root.get_node("GameState")
	_router = tree.root.get_node("SceneRouter")
	_manager = tree.root.get_node("SaveManager")
	_old_dir = str(_manager.get("save_dir"))
	_dir = "user://test_qa_regressions_%d" % Time.get_ticks_usec()
	ExplorationKit.drop_stale_modals(self)


func after_each() -> void:
	if _main != null and is_instance_valid(_main):
		_main.apply_mode(GameMode.Mode.CLASSIC)
	_router.set("main", null)
	_router.set("instant", false)
	_router.set("current_room_id", "")
	_router.set("pending_room_id", "")
	_router.set("rooms_id", "world/rooms")
	_manager.set("save_dir", _old_dir)
	_manager.set("rooms_data_id", "world/rooms")
	_state.set("rooms_data_id", "world/rooms")
	_state.call("reset")
	Placements.extra_ids = []
	Placements.extra_job_ids = []
	Placements.extra_scene_ids = []
	InputSorting.revert()
	SandboxPauseGate.clear(tree)
	for node: Node in tree.get_nodes_in_group(ActionRoom.GROUP_HUD):
		node.remove_from_group(ActionRoom.GROUP_HUD)
		node.queue_free()
	if DirAccess.dir_exists_absolute(_dir):
		for file_name: String in DirAccess.get_files_at(_dir):
			DirAccess.remove_absolute(_dir.path_join(file_name))
		DirAccess.remove_absolute(_dir)


## A known bug: passes while it stands (XFAIL, names the bug) and passes with XPASS once fixed.
func known_bug(bug_id: String, fixed: bool, message: String) -> void:
	assert_true(true, "known bug check %s" % bug_id)
	if fixed:
		print("XPASS %s: fixed. Take the known-bug marker out of this test." % bug_id)
	else:
		print("XFAIL %s (known bug, docs/bug_log.md): %s" % [bug_id, message])


func _boot(room_id: String, spawn: String) -> ActionRoom:
	_main = (load("res://scenes/core/main.tscn") as PackedScene).instantiate() as Main
	_main.show_title = false
	_main.debug_overlay_enabled = false
	_main.sandbox_boot_enabled = false
	add_to_root(_main)
	_main.apply_mode(GameMode.Mode.SLICE)
	_manager.set("save_dir", _dir)
	_router.set("main", _main)
	_router.set("instant", true)
	_state.call("reset")
	_router.call("start_at", room_id, spawn)
	for i: int in 240:
		await tree.physics_frame
		var room: ActionRoom = _main.get_room() as ActionRoom
		if room != null and room.room_id == room_id and not bool(_router.call("is_busy")) and room.hero != null:
			await tree.physics_frame
			return room
	fail("never reached %s" % room_id)
	return null


func _put_hero(room: ActionRoom, at: Vector3) -> void:
	room.hero.global_position = at
	room.hero.velocity = Vector3.ZERO


func _kill(enemy: Node3D) -> void:
	(enemy as CombatActor).apply_hit({"outcome": "hit", "damage": 99999, "hitstun_ms": 100.0, "knockback": Vector3.ZERO, "launch_mps": 0.0, "poise_after": 0.0})


## B7: an encounter's enemies come back at full health six seconds after they die (ActionEnemy's respawn, sandbox.json respawn_s),
## even after their fight has been cleared. Expected: a killed encounter enemy stays down, so a fight can end. See docs/bug_log.md.
func test_B7_a_killed_encounter_enemy_stays_down_after_its_fight_is_cleared() -> void:
	var room: ActionRoom = await _boot(ROOM_ID, SPAWN)
	if room == null:
		return
	var runner: EncounterRunner = room.encounter_runner
	runner.set_physics_process(false)
	runner.manual_ticks = true
	_put_hero(room, Vector3(30.0, 0.1, 22.0))
	runner.tick(0.1)
	assert_eq(runner.state_of(FIGHT_ID), "running", "walking into the pound starts the pair")
	var cops: Array[Node3D] = runner.enemies_of(FIGHT_ID)
	assert_eq(cops.size(), 2, "two cops")
	for cop: Node3D in cops:
		_kill(cop)
	runner.tick(0.1)
	assert_eq(runner.state_of(FIGHT_ID), "cleared", "with both dead the fight is cleared")
	for i: int in RESPAWN_WAIT_FRAMES:
		await tree.physics_frame
	var back: int = 0
	for cop: Node3D in cops:
		if is_instance_valid(cop) and not bool(cop.get("dead")):
			back += 1
	assert_eq(back, 0, "B7: no cop comes back after its fight is cleared (%d of 2 did)" % back)
	assert_eq(runner.state_of(FIGHT_ID), "cleared", "the cleared fight stays cleared")


## In a slice room, the pause menu offers the "Menu" row (Items, Sword, Config, Save), which is where healing items are used.
func test_a_slice_room_pause_menu_offers_the_menu_row_for_items() -> void:
	var room: ActionRoom = await _boot("market_hideout", "start")
	if room == null:
		return
	var hud: Node = tree.get_first_node_in_group(ActionRoom.GROUP_HUD)
	assert_not_null(hud, "the slice HUD is in the group")
	if hud == null:
		return
	hud.call("open_pause")
	var pause: Object = hud.get("_slice_pause") as Object
	assert_not_null(pause, "the HUD has a pause menu")
	if pause == null:
		return
	var rows: Array = pause.call("item_ids") as Array
	print("QA probe: slice pause rows in a room: %s (menu_enabled %s)" % [str(rows), str(pause.get("menu_enabled"))])
	assert_has(rows, "menu", "the pause menu offers Menu (items and gear) in a slice room")


## B13: the Stand's head cache held a Juice Box (it restores Juice, a gauge the slice never uses). Now the cache holds an item that
## heals Red's health, and the Stand has one visible health pickup. The heal is used through the field menu's own Bag path.
func test_B13_the_stand_gives_red_health_back() -> void:
	var crates: Dictionary = DataDB.get_dict("slice/placements").get("crates", {}) as Dictionary
	var cache: Dictionary = crates.get("jk_j4_head_cache", {}) as Dictionary
	assert_false(cache.is_empty(), "the Stand's head cache is placed")
	var items: Dictionary = {}
	for raw: Variant in DataDB.get_dict("items/items").get("items", []) as Array:
		items[str((raw as Dictionary).get("id", ""))] = raw
	for raw: Variant in cache.get("items", []) as Array:
		var item_id: String = str((raw as Dictionary).get("item", ""))
		var effect: Dictionary = (items.get(item_id, {}) as Dictionary).get("effect", {}) as Dictionary
		assert_true(effect.has("heal_hp"), "B13: %s in the head cache heals health" % item_id)
	var pickups: Dictionary = DataDB.get_dict("slice/placements").get("pickups", {}) as Dictionary
	var heals: int = 0
	for id: Variant in pickups.keys():
		var pickup: Dictionary = pickups[id] as Dictionary
		if str(pickup.get("room", "")) == "junk_j4" and ((items.get(str(pickup.get("item", "")), {}) as Dictionary).get("effect", {}) as Dictionary).has("heal_hp"):
			heals += 1
	assert_gt(heals, 0, "B13: the Stand's room has a health pickup placed")
	_state.call("start_new_game")
	_state.call("update_member", "red", {"hp": 20})
	_state.call("add_item", "ration_bar", 1)
	var result: Dictionary = Bag.use_item("ration_bar", "red", Bag.CTX_FIELD, _state)
	assert_true(bool(result.get("ok", false)), "a Ration Bar can be used from the field menu")
	assert_gt(int((_state.call("get_member", "red") as Dictionary).get("hp", 0)), 20, "and it gives Red health")


## The Stand's health pickup is in the built room, in the group of pickups the interactor can use.
func test_B13_the_stand_scene_has_its_health_pickup() -> void:
	var room: ActionRoom = await _boot("junk_j4", "from_j3")
	if room == null:
		return
	var level: Node = room.get("level") as Node
	var node: Node = level.get_node_or_null("StandHealPickup") if level != null else null
	assert_not_null(node, "B13: the Stand has its health pickup")
	if node != null:
		assert_eq(str(node.get("placement_id")), "jk_j4_heal", "it is the placed heal")


## The J3 Crane Yard's wave-2 Brute (entrance container_gap) stands at its marker until Red comes near, then walks at her. The
## first play run never brought Red close to it (the cops respawned, see B7), so this is a check that it comes when she does.
func test_the_crane_yard_brute_comes_at_red_once_she_is_close() -> void:
	var room: ActionRoom = await _boot("junk_j3", "from_j2")
	if room == null:
		return
	var runner: EncounterRunner = room.encounter_runner
	runner.set_physics_process(false)
	runner.manual_ticks = true
	var level: Node = room.get("level") as Node
	var marker: Node3D = level.get_node_or_null("Encounters/enc_j3_yard/w2_brute_1") as Node3D if level != null else null
	assert_not_null(marker, "the Crane Yard's brute marker is in the scene")
	if marker == null:
		return
	var brute: Node3D = room.call("spawn_enemy", "brute", marker.global_position) as Node3D
	assert_not_null(brute, "a brute can be spawned")
	if brute == null:
		return
	var start: Vector3 = brute.global_position
	_put_hero(room, start + Vector3(0.0, 0.1, 10.0))
	for i: int in 180:
		await tree.physics_frame
		_put_hero(room, room.hero.global_position)
	var moved: float = Vector2(brute.global_position.x - start.x, brute.global_position.z - start.z).length()
	assert_gt(moved, 1.0, "the brute walks at Red when she is 10 m away (moved %.2f m in 3 s)" % moved)


## B9: the J4 loader's wake-up button is switched off in a real room. HackTarget._refresh runs when the loader is built, before
## RobotStage has joined its group, so the button (its Interactable) stays disabled and nothing re-checks it. Red can then never
## wake the loader, so the route from J4 to J5 is shut. Expected: from the floor beside it, the loader can be used.
func test_B9_the_loader_can_be_woken_from_the_floor() -> void:
	var room: ActionRoom = await _boot("junk_j4", "from_j3")
	if room == null:
		return
	var loader: Node3D = null
	var level: Node = room.get("level") as Node
	if level != null:
		loader = level.get_node_or_null("loader_j4") as Node3D
	assert_not_null(loader, "the loader target exists")
	if loader == null:
		return
	var inter: Interactable = null
	for child: Node in loader.find_children("*", "Interactable", true, false):
		inter = child as Interactable
		break
	assert_not_null(inter, "the loader has an Interactable child")
	if inter == null:
		return
	await tree.physics_frame
	var stage_joined: bool = tree.get_first_node_in_group(RobotStage.GROUP) != null
	assert_true(stage_joined, "the robot stage is in its group once the room is up")
	assert_true(inter.enabled, "B9: the loader's wake-up button is on once the room is up (robot stage in group %s)" % str(stage_joined))


## B6: Vela's wake-up greeting plays by itself once on New Game in the hideout (scene hideout_wake, trigger enter at spawn "start").
func test_B6_the_hideout_wake_scene_plays_once_on_new_game() -> void:
	var room: ActionRoom = await _boot("market_hideout", "start")
	if room == null:
		return
	var story: StoryDirector = room.story
	assert_not_null(story, "the hideout has a story director")
	if story == null:
		return
	var started: Array[String] = []
	story.scene_started.connect(func(id: String) -> void: started.append(id))
	for i: int in 120:
		await tree.physics_frame
		if story.is_running() or WorldProgress.has_flag("hideout_wake_seen"):
			break
	assert_true(story.is_running() or WorldProgress.has_flag("hideout_wake_seen"), "B6: the wake scene starts on its own")
	assert_eq(story.current_scene, "hideout_wake", "it is the wake scene")
	assert_false(story.should_start("hideout_wake"), "it does not start a second time")


## B18: ambient barks ran into a script error on every tick once a bubble closed (a freed bubble in a typed array), and then never
## pruned the list. Runs the real barks next to a chatty townsperson for a while: more than one bark plays, the live list empties
## when a bubble closes, and the log must stay free of SCRIPT ERROR lines (the suite's log is grepped for them).
func test_B18_ambient_barks_keep_running_after_a_bubble_closes() -> void:
	var room: ActionRoom = await _boot("market_square", "from_hideout")
	if room == null:
		return
	var chatty: PlacedNpc = null
	for node: Node in tree.get_nodes_in_group(Npc.GROUP):
		var npc: PlacedNpc = node as PlacedNpc
		if npc != null and room.is_ancestor_of(npc) and float(npc.data.get("bark_radius_m", 0.0)) > 0.0 and not (npc.data.get("barks", []) as Array).is_empty():
			chatty = npc
			break
	assert_not_null(chatty, "the square has a townsperson who barks")
	if chatty == null:
		return
	assert_not_null(room.barks, "the room has ambient barks")
	var heard: Array[String] = []
	room.barks.barked.connect(func(_speaker: String, text: String) -> void: heard.append(text))
	var peak: int = 0
	var emptied: bool = false
	for i: int in 2400:
		_put_hero(room, chatty.global_position + Vector3(0.0, 0.05, 2.0))
		await tree.physics_frame
		peak = maxi(peak, room.barks.live_count())
		if peak > 0 and room.barks.live_count() == 0:
			emptied = true
		if heard.size() >= 2 and emptied:
			break
	assert_gt(peak, 0, "a bark bubble came up")
	assert_true(emptied, "B18: the live list empties when the bubble closes")
	assert_gt(heard.size(), 1, "B18: a second bark plays after the first one closed (%d heard)" % heard.size())
