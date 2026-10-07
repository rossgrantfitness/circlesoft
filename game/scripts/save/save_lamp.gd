class_name SaveLamp
extends Interactable
## A save spot: a lamp in a little wall niche (dungeons), Red's window lamp, an inn's lamp. Press
## interact next to it and Red does the lamp check: she lights the lamp, taps the glass twice and
## gives the sky a thumbs-up, then the save screen opens (SaveManager.open_lamp_menu).
##
## The check is full length the first time each session and short after that; one press skips it
## (the press that started it is ignored for a moment). The beats and timings are data
## (data/world/save.json "lamp_check"). Red never gets a text box: the thumbs-up is her gesture
## pop-up. The lamp is a placeholder: a post, a niche box and a glowing bulb built from code (no
## art asset needed), and it stays lit once used.
##
## `rest`: Red's home and inns heal the party (full HP and Juice) when the check ends; dungeon
## lamps only save ("save only; use a Camp Stove there"). `room_id` and `spawn_id` say where Red
## reappears after Continue: the room's id and the name of a Marker3D to stand on.
##
## How it plugs into the existing interact button: its `conversation` is an empty hook
## conversation "lamp_check" that the lamp registers with the room's dialogue runner itself (see
## _ensure_hook), so the interactor picks it like anything else and calls begin_use(); the check
## starts there. The empty conversation ends at once and does nothing.

enum Phase { IDLE, BEATS, GESTURE, MENU, COOLDOWN }

const HOOK_CONVERSATION: String = "lamp_check"
const THUMBS_CONVERSATION: String = "lamp_check_thumbs"
const DATA_ID: String = "world/save"
const GROUP_LAMP: StringName = &"save_lamp"
const BEAT_LIGHT: String = "light"
const BEAT_TAP: String = "tap"
const BEAT_THUMBS: String = "thumbs_up"
const SKIP_ACTIONS: Array[StringName] = [&"confirm", &"cancel", &"interact"]
const COOLDOWN_FRAMES: int = 3
const NO_GESTURE_WAIT_S: float = 0.3
const PATH_MANAGER: NodePath = ^"/root/SaveManager"
const SHADER_UNLIT: String = "res://shaders/psx_unlit.gdshader"
const SHADER_LIT: String = "res://shaders/psx_lit.gdshader"
const TEXTURE_PATH: String = "res://art/placeholder/textures/checker_128.png"
const COLOR_BRASS: Color = Color(0.85, 0.64, 0.25)
const COLOR_NICHE: Color = Color(0.45, 0.5, 0.62)
const COLOR_GLOW: Color = Color(1.0, 0.88, 0.54)
const COLOR_LIGHT: Color = Color(1.0, 0.7, 0.28)

signal check_started(full: bool)
signal check_skipped
signal menu_opened(prompt: Node)
signal finished

## On: the party is healed when the check ends (Red's home, inns). Off: save only.
@export var rest: bool = false
## Where a save made here continues: the room id and the spawn marker's name.
@export var room_id: String = ""
@export var spawn_id: String = ""
## Builds the placeholder lamp (post, niche, bulb, light) when the node has no children.
@export var build_placeholder: bool = true

## SaveManager and GameState to use. Null means the autoloads.
var save_manager: Node = null
## The dialogue runner for the thumbs-up and the player to freeze. Null means the owning
## FieldRoom's.
var runner: DialogueRunner = null
var player: Node = null
## Off in tests that drive the lamp by hand (tick(), skip()).
var read_engine_input: bool = true
var manual_ticks: bool = false

var _phase: Phase = Phase.IDLE
var _beats: Array = []
var _beat_index: int = -1
var _beat_elapsed: float = 0.0
var _beat_length: float = 0.0
var _full: bool = true
var _grace_left: float = 0.0
var _cooldown_left: int = 0
var _frozen_by_us: bool = false
var _was_frozen: bool = false
var _prompt: Node = null
var _lit: bool = false
var _glow: Dictionary = {}
var _light: OmniLight3D = null
var _bulb_material: ShaderMaterial = null
var _audio: UiAudio = UiAudio.new()


func _init() -> void:
	conversation = HOOK_CONVERSATION
	kind = Kind.EXAMINE


func _ready() -> void:
	super._ready()
	add_to_group(GROUP_LAMP)
	_glow = DataDB.get_value(DATA_ID, "lamp_check.glow", {})
	if build_placeholder and get_child_count() == 0:
		_build_placeholder()
	_set_glow(false, 0.0)
	set_process(not manual_ticks)


func _process(delta: float) -> void:
	tick(delta)


func get_phase() -> Phase:
	return _phase


func is_checking() -> bool:
	return _phase != Phase.IDLE


func is_lit() -> bool:
	return _lit


func get_prompt() -> Node:
	return _prompt


## The interact button's hook. Starts the lamp check (ignored while one is already running).
func begin_use(from_point: Vector3) -> void:
	super.begin_use(from_point)
	start_check()


## Registers the empty hook conversation with the runner (once the real data is indexed).
func _ensure_hook() -> void:
	var active: DialogueRunner = _runner()
	if active != null and not active.has_conversation(HOOK_CONVERSATION):
		active.add_conversations({HOOK_CONVERSATION: []})


func usable_distance(point: Vector3, facing: Vector3, tuning: InteractionTuning) -> float:
	_ensure_hook()
	return super.usable_distance(point, facing, tuning)


## Starts the check. Returns false when one is already running or there is no save manager.
func start_check() -> bool:
	if _phase != Phase.IDLE:
		return false
	var manager: Node = _manager()
	if manager == null:
		return false
	_full = bool(manager.call("is_first_lamp_check"))
	_beats = DataDB.get_value(DATA_ID, "lamp_check.full" if _full else "lamp_check.short", [])
	_grace_left = float(DataDB.get_value(DATA_ID, "lamp_check.skip_grace_s", 0.25))
	add_to_group(UiStage.MODAL_GROUP)
	_freeze()
	_beat_index = -1
	_phase = Phase.BEATS
	check_started.emit(_full)
	_next_beat()
	return true


## One press skips the rest of the check and opens the save screen.
func skip() -> void:
	if _phase != Phase.BEATS and _phase != Phase.GESTURE:
		return
	check_skipped.emit()
	var active: DialogueRunner = _runner()
	if _phase == Phase.GESTURE and active != null and active.is_running():
		active.stop()
	_open_menu()


# ---- the beats ----

func _next_beat() -> void:
	_beat_index += 1
	if _beat_index >= _beats.size():
		_open_menu()
		return
	var beat: Dictionary = _beats[_beat_index]
	var id: String = str(beat.get("id", ""))
	_beat_elapsed = 0.0
	_beat_length = float(beat.get("s", 0.0))
	var sound: String = str(beat.get("sfx", ""))
	if not sound.is_empty():
		_audio.sfx(sound)
	if id == BEAT_THUMBS:
		_start_gesture()


func _start_gesture() -> void:
	_phase = Phase.GESTURE
	_lit = true
	_set_glow(true, 0.0)
	var active: DialogueRunner = _runner()
	if active != null and active.has_conversation(THUMBS_CONVERSATION):
		active.conversation_finished.connect(_on_thumbs_finished, CONNECT_ONE_SHOT)
		if active.start(THUMBS_CONVERSATION):
			return
		active.conversation_finished.disconnect(_on_thumbs_finished)
	# No room runner (a bare lamp): a short beat stands in for the gesture.
	_beat_elapsed = 0.0
	_beat_length = NO_GESTURE_WAIT_S


func _on_thumbs_finished(_conversation_id: String) -> void:
	if _phase == Phase.GESTURE:
		_open_menu()


func tick(delta: float) -> void:
	if _phase == Phase.COOLDOWN:
		_cooldown_left -= 1
		if _cooldown_left <= 0:
			_end_cooldown()
		return
	if _phase != Phase.BEATS and _phase != Phase.GESTURE:
		return
	_grace_left = maxf(0.0, _grace_left - delta)
	if read_engine_input and _grace_left <= 0.0 and _skip_pressed():
		skip()
		return
	_beat_elapsed += delta
	if _phase == Phase.BEATS:
		_animate_beat()
		if _beat_elapsed >= _beat_length:
			_next_beat()
	elif _beat_length > 0.0 and _beat_elapsed >= _beat_length:
		# The no-runner stand-in for the thumbs-up.
		_beat_length = 0.0
		_open_menu()


func _skip_pressed() -> bool:
	for action: StringName in SKIP_ACTIONS:
		if Input.is_action_just_pressed(action):
			return true
	return false


func _animate_beat() -> void:
	var beat: Dictionary = _beats[_beat_index]
	var id: String = str(beat.get("id", ""))
	var t: float = clampf(_beat_elapsed / _beat_length, 0.0, 1.0) if _beat_length > 0.0 else 1.0
	if id == BEAT_LIGHT:
		_lit = true
		_set_glow(true, 0.0, t)
	elif id == BEAT_TAP:
		_set_glow(true, sin(t * PI))


# ---- the save screen ----

func _open_menu() -> void:
	if _phase == Phase.MENU or _phase == Phase.COOLDOWN:
		return
	_phase = Phase.MENU
	_lit = true
	_set_glow(true, 0.0)
	var manager: Node = _manager()
	manager.call("note_lamp_check_done")
	var state: Node = _game_state()
	if state != null:
		var here: Dictionary = state.call("get_location")
		var room: String = room_id if not room_id.is_empty() else str(here.get("room", ""))
		state.call("set_location", room, spawn_id)
	_prompt = manager.call("open_lamp_menu", rest, null) as Node
	if _prompt == null:
		_begin_cooldown()
		return
	_prompt.connect("closed", _on_menu_closed)
	menu_opened.emit(_prompt)


func _on_menu_closed(_saved_slot: int) -> void:
	_prompt = null
	_begin_cooldown()


func _begin_cooldown() -> void:
	_phase = Phase.COOLDOWN
	_cooldown_left = COOLDOWN_FRAMES


func _end_cooldown() -> void:
	_phase = Phase.IDLE
	_thaw()
	remove_from_group(UiStage.MODAL_GROUP)
	finished.emit()


func _exit_tree() -> void:
	if _phase != Phase.IDLE:
		_thaw()
		remove_from_group(UiStage.MODAL_GROUP)


# ---- finding things ----

func _manager() -> Node:
	return save_manager if save_manager != null else get_node_or_null(PATH_MANAGER)


func _game_state() -> Node:
	if game_state != null:
		return game_state
	var manager: Node = _manager()
	if manager != null and manager.get("game_state") != null:
		return manager.get("game_state") as Node
	return get_node_or_null(Interactable.PATH_GAME_STATE)


func _room() -> Node:
	var node: Node = get_parent()
	while node != null:
		if node.get("runner") != null or node is FieldRoom:
			return node
		node = node.get_parent()
	return null


func _runner() -> DialogueRunner:
	if runner != null:
		return runner
	var room: Node = _room()
	return room.get("runner") as DialogueRunner if room != null else null


func _player() -> Node:
	if player != null:
		return player
	var room: Node = _room()
	return room.get("player") as Node if room != null else null


func _freeze() -> void:
	var red: Node = _player()
	if red != null and not _frozen_by_us:
		_was_frozen = bool(red.get("frozen"))
		red.set("frozen", true)
		_frozen_by_us = true


func _thaw() -> void:
	var red: Node = _player()
	if _frozen_by_us and red != null and is_instance_valid(red):
		red.set("frozen", _was_frozen)
	_frozen_by_us = false


## True if a save lamp is within `radius` of `point` (flat distance). The Camp Stove checks this.
static func is_near_any(tree: SceneTree, point: Vector3, radius: float = 2.0) -> bool:
	for node: Node in tree.get_nodes_in_group(GROUP_LAMP):
		if node is SaveLamp:
			var offset: Vector3 = (node as SaveLamp).global_position - point
			if Vector2(offset.x, offset.z).length() <= radius and absf(offset.y) <= 1.5:
				return true
	return false


# ---- the placeholder lamp ----

func _build_placeholder() -> void:
	var texture: Texture2D = load(TEXTURE_PATH) as Texture2D
	var niche: MeshInstance3D = MeshInstance3D.new()
	niche.name = "Niche"
	var niche_mesh: BoxMesh = BoxMesh.new()
	niche_mesh.size = Vector3(0.7, 1.5, 0.3)
	niche.mesh = niche_mesh
	niche.position = Vector3(0.0, 0.75, -0.1)
	niche.material_override = _lit_material(texture, COLOR_NICHE)
	add_child(niche)
	var post: MeshInstance3D = MeshInstance3D.new()
	post.name = "Post"
	var post_mesh: CylinderMesh = CylinderMesh.new()
	post_mesh.top_radius = 0.06
	post_mesh.bottom_radius = 0.09
	post_mesh.height = 1.0
	post_mesh.radial_segments = 6
	post_mesh.rings = 1
	post.mesh = post_mesh
	post.position = Vector3(0.0, 0.5, 0.12)
	post.material_override = _lit_material(texture, COLOR_BRASS)
	add_child(post)
	var bulb: MeshInstance3D = MeshInstance3D.new()
	bulb.name = "Bulb"
	var bulb_mesh: SphereMesh = SphereMesh.new()
	bulb_mesh.radius = 0.17
	bulb_mesh.height = 0.34
	bulb_mesh.radial_segments = 8
	bulb_mesh.rings = 4
	bulb.mesh = bulb_mesh
	bulb.position = Vector3(0.0, 1.15, 0.12)
	_bulb_material = ShaderMaterial.new()
	_bulb_material.shader = load(SHADER_UNLIT) as Shader
	_bulb_material.set_shader_parameter("albedo_texture", texture)
	_bulb_material.set_shader_parameter("uv_scale", Vector2(0.07, 0.07))
	_bulb_material.set_shader_parameter("uv_offset", Vector2(0.02, 0.02))
	_bulb_material.set_shader_parameter("albedo_tint", COLOR_GLOW)
	bulb.material_override = _bulb_material
	add_child(bulb)
	_light = OmniLight3D.new()
	_light.name = "Light"
	_light.light_color = COLOR_LIGHT
	_light.omni_range = 6.0
	_light.position = Vector3(0.0, 1.15, 0.5)
	add_child(_light)


func _lit_material(texture: Texture2D, tint: Color) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load(SHADER_LIT) as Shader
	material.set_shader_parameter("albedo_texture", texture)
	material.set_shader_parameter("albedo_tint", tint)
	return material


## lit false: the dim idle glow. lit true: `lit_amount` (0..1) between dim and fully lit, plus a
## `boost` (0..1) pulse for the taps. The default lit_amount of 1 is "fully lit".
func _set_glow(lit: bool, boost: float, lit_amount: float = 1.0) -> void:
	var dim: float = float(_glow.get("dim_energy", 1.2))
	var bright: float = float(_glow.get("lit_energy", 5.5))
	var bulb_dim: float = float(_glow.get("bulb_dim", 0.35))
	var bulb_bright: float = float(_glow.get("bulb_lit", 1.8))
	var amount: float = clampf(lit_amount, 0.0, 1.0) if lit else 0.0
	var energy: float = lerpf(dim, bright, amount) + float(_glow.get("tap_boost", 2.0)) * boost
	var bulb_energy: float = lerpf(bulb_dim, bulb_bright, amount) + boost * 0.6
	if _light != null:
		_light.light_energy = energy
	if _bulb_material != null:
		_bulb_material.set_shader_parameter("emission_energy", bulb_energy)
