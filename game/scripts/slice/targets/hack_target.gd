class_name HackTarget
extends Node3D
## Anything in the world that is not an enemy but a hack (or the interact button) can work: a fuse box, a crane, a drone line's
## power node, a terminal, the loader (docs/slice/slice_tech_plan.md 4.5 and 5.2). This is the base; the kinds are HackDoor,
## HackCrane, DroneLine, HackTerminal and HackLoader.
##
## How the hacks find it (no code in the hacks changes): it joins group `hack_targets`, and ZapDrone and EmpPulse call
##   can_take(hack_id) -> bool, aim_point() -> Vector3, take_hack(hack_id, info) -> bool
## on whatever is in the group. While it is lockable and not finished it also joins `lock_targets`, so lock-on reaches it.
## `interact` means "walk up and press the button": the target makes an Interactable child. Overclock goes through a
## `Hijackable` child, which the kinds that want it (the crane) add.
##
## Sticky: when it finishes, a GameState flag is set (`flag`, default "hack_<id>_done"). The flag is saved with the game and
## a knock-out restart keeps it when the placement says `"sticky": true` (ActionRoom.sticky_ids reads the entry's `flag`).
## So a hacked target is still hacked after a retry, a reload and a save.
##
## Its settings come from data/slice/placements.json section "hack_targets" under its `target_id` (the Level Designer places
## them), or from `data` when a test or tool sets it. Keys: kind, accepts, lockable, sticky, flag, aim_height_m, label and
## whatever the kind reads.

signal hacked(target_id: StringName, hack_id: StringName)
signal completed(target_id: StringName)

const SECTION: String = "hack_targets"
const GROUP_HACK_TARGETS: StringName = &"hack_targets"
const GROUP_LOCK_TARGETS: StringName = &"lock_targets"
const GROUP_TARGET_NODES: StringName = &"hack_target_nodes"
const ACCEPT_ZAP: StringName = &"zap"
const ACCEPT_EMP: StringName = &"emp"
const ACCEPT_OVERCLOCK: StringName = &"overclock"
const ACCEPT_INTERACT: StringName = &"interact"
const TEAL: Color = Color(0.2, 0.95, 0.85)
const DEAD_GREY: Color = Color(0.35, 0.4, 0.42)
const FLAG_PREFIX: String = "hack_"
const FLAG_SUFFIX: String = "_done"

@export var target_id: StringName = &""
@export var accepts: PackedStringArray = PackedStringArray(["zap"])
@export var lockable: bool = true
## Stays done after a retry, a reload and a save (a GameState flag).
@export var sticky: bool = true
@export var aim_height_m: float = 1.0

## The settings, when not read from the placements (tests and tools).
var data: Dictionary = {}
## GameState to use. Null means the autoload.
var game_state: Node = null
## The Interactable the interact button finds (only when `accepts` has "interact").
var interactable: Interactable = null
var last_hack: StringName = &""
## The words this target last showed (tests read them).
var last_messages: Array[String] = []

var _flag: String = ""
var _done_local: bool = false
var _configured: bool = false


func _ready() -> void:
	add_to_group(GROUP_HACK_TARGETS)
	add_to_group(GROUP_TARGET_NODES)
	configure()
	if accepts.has(ACCEPT_INTERACT) and interactable == null:
		make_interactable(Interactable.Kind.OPEN, float(entry().get("reach_m", 0.0)))
	if not has_node("Model"):
		_build_look()
	if is_done():
		_restore_done()
	_refresh()


## Reads the settings (once). The kinds call it early if they need the numbers before `_ready`.
func configure() -> void:
	if _configured:
		return
	_configured = true
	var info: Dictionary = entry()
	if info.has("accepts"):
		accepts = PackedStringArray(_strings(info["accepts"]))
	lockable = bool(info.get("lockable", lockable))
	sticky = bool(info.get("sticky", sticky))
	aim_height_m = float(info.get("aim_height_m", aim_height_m))
	_flag = str(info.get("flag", ""))
	if _flag.is_empty():
		_flag = FLAG_PREFIX + String(target_id) + FLAG_SUFFIX
	_configure(info)


## This target's entry: `data` if set, else the placements section.
func entry() -> Dictionary:
	if not data.is_empty():
		return data
	if target_id == &"":
		return {}
	return Placements.entry(SECTION, String(target_id))


func flag_id() -> String:
	configure()
	return _flag


# ---- the hack interface (what ZapDrone, EmpPulse and the lock-on read) ----

func aim_point() -> Vector3:
	return global_position + Vector3.UP * aim_height_m


func can_take(hack_id: StringName) -> bool:
	configure()
	return accepts.has(String(hack_id)) and not is_done() and _ready_for(hack_id)


## A hack (or the button) works on it. Returns true if it did something.
func take_hack(hack_id: StringName, info: Dictionary = {}) -> bool:
	if not can_take(hack_id):
		return false
	if not _apply(hack_id, info):
		return false
	last_hack = hack_id
	hacked.emit(target_id, hack_id)
	if _finishes_on(hack_id):
		complete()
	return true


## Finished for good (sticky: for the whole run, saved) or for this visit (not sticky).
func is_done() -> bool:
	if _done_local:
		return true
	return sticky and WorldProgress.has_flag(flag_id(), game_state)


## Marks it done: the flag (sticky), the look, the lock-on. Safe to call twice.
func complete() -> void:
	if _done_local:
		return
	_done_local = true
	if sticky:
		WorldProgress.set_flag(flag_id(), game_state)
	_apply_done(true)
	_refresh()
	completed.emit(target_id)


## Puts it back to not-done for this visit (tests, and non-sticky targets on a room reset). A sticky flag is not touched.
func reset_target() -> void:
	_done_local = false
	_apply_done(false)
	_refresh()


## Adds the Interactable child the interact button finds.
func make_interactable(kind: Interactable.Kind, reach: float) -> Interactable:
	interactable = Interactable.new()
	interactable.name = "Interactable"
	interactable.kind = kind
	interactable.reach = reach
	interactable.handler = Callable(self, "_on_interact")
	interactable.game_state = game_state
	add_child(interactable)
	return interactable


func _on_interact(player: CharacterBody3D, interactor: PlayerInteractor) -> bool:
	return take_hack(ACCEPT_INTERACT, {"source": player, "interactor": interactor})


## Shows a line or two through the room's interactor, and remembers them for tests.
func say(lines: Array[String], interactor: PlayerInteractor = null) -> bool:
	last_messages = lines.duplicate()
	if interactor == null or lines.is_empty():
		return false
	return interactor.show_messages(lines, interactable)


func state() -> Node:
	return WorldProgress.game_state(game_state)


func _refresh() -> void:
	var live: bool = lockable and not is_done()
	if live and not is_in_group(GROUP_LOCK_TARGETS):
		add_to_group(GROUP_LOCK_TARGETS)
	elif not live and is_in_group(GROUP_LOCK_TARGETS):
		remove_from_group(GROUP_LOCK_TARGETS)
	if interactable != null:
		var usable: bool = accepts.has(String(ACCEPT_INTERACT)) and not is_done() and _ready_for(ACCEPT_INTERACT)
		interactable.enabled = usable
		if usable and not interactable.is_in_group(Interactable.GROUP):
			interactable.add_to_group(Interactable.GROUP)
		elif not usable and interactable.is_in_group(Interactable.GROUP):
			interactable.remove_from_group(Interactable.GROUP)


static func _strings(raw: Variant) -> Array[String]:
	var out: Array[String] = []
	if raw is Array or raw is PackedStringArray:
		for item: Variant in raw:
			out.append(str(item))
	elif raw != null:
		out.append(str(raw))
	return out


static func vec3(raw: Variant, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	if raw is Array and (raw as Array).size() >= 3:
		var list: Array = raw
		return Vector3(float(list[0]), float(list[1]), float(list[2]))
	return fallback


## A small glowing panel for the placeholder fuse box, terminal and power node.
static func panel_look(color: Color, size: Vector3 = Vector3(0.7, 0.9, 0.35)) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Look"
	var body: MeshInstance3D = PropLook.box(size, PropLook.lit(Color(0.45, 0.47, 0.5)), "Body")
	body.position.y = size.y * 0.5
	root.add_child(body)
	var lamp: MeshInstance3D = PropLook.box(Vector3(size.x * 0.6, size.y * 0.35, 0.06), PropLook.glow(color, 1.8), "Lamp")
	lamp.position = Vector3(0.0, size.y * 0.6, size.z * 0.5 + 0.02)
	root.add_child(lamp)
	return root


## Recolours the "Lamp" of a panel_look.
func set_lamp(color: Color) -> void:
	var lamp: MeshInstance3D = find_child("Lamp", true, false) as MeshInstance3D
	if lamp != null:
		lamp.material_override = PropLook.glow(color, 1.8 if color != DEAD_GREY else 0.4)


# ---- for the kinds to override ----

## Read the kind's own keys.
func _configure(_info: Dictionary) -> void:
	pass


## Extra conditions beyond "accepts and not done".
func _ready_for(_hack_id: StringName) -> bool:
	return true


## Do the thing. Return false if it did nothing.
func _apply(_hack_id: StringName, _info: Dictionary) -> bool:
	return true


## Does this hack finish the target at once? (The crane finishes later, when the cargo arrives.)
func _finishes_on(_hack_id: StringName) -> bool:
	return true


## The look when it flips to done (or back, `done` false). `restoring` is not passed: call _restore_done for a reload.
func _apply_done(_done: bool) -> void:
	set_lamp(DEAD_GREY if _done else TEAL)


## Back in a room where it was already done: be in the finished state without any show.
func _restore_done() -> void:
	_done_local = true
	_apply_done(true)


func _build_look() -> void:
	add_child(panel_look(TEAL))
