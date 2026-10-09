class_name AmbientBarks
extends Node
## Ambient one-liners as Red walks past (docs/slice/slice_tech_plan.md 3, "NPC bubbles"): a market crowd murmuring. A
## PlacedNpc whose placement data has `bark_radius_m` and `barks` (a list of short lines) says the next one in turn when
## Red comes within that radius, then keeps quiet for `bark_cooldown_s` (placement, else data/slice/slice.json "barks").
## The bubble is a normal speech bubble that follows the speaker, closes by itself after a moment, and NEVER stops Red:
## it takes no input, does not freeze her and does not count as a menu being open. At most `max_at_once` show together.
## Barks wait while a conversation, shop or menu is up, and while she is frozen or in a scripted move.
##
## Placement keys (data/slice/placements.json "npcs"): bark_radius_m, barks [String], bark_cooldown_s (optional),
## bark_speaker (optional; the dialogue speaker id, default the NPC's own).

const BUBBLE_SCENE: String = "res://scenes/ui/speech_bubble.tscn"
const SLICE_DATA_ID: String = "slice/slice"

signal barked(speaker_id: String, text: String)

var hero: Node3D = null
var camera: Camera3D = null
## Where bubbles go. Null means the UI stage's root.
var parent_override: Control = null
## Off in tests that call tick() by hand.
var manual_ticks: bool = false
## Skip the real bubble (tests that only count barks).
var show_bubbles: bool = true

var _cfg: Dictionary = {}
var _clock: float = 0.0
var _next_ok: Dictionary[int, float] = {}
var _turn: Dictionary[int, int] = {}
var _live: Array[SpeechBubble] = []


func _ready() -> void:
	_cfg = DataDB.get_value(SLICE_DATA_ID, "barks", {}) as Dictionary
	set_physics_process(not manual_ticks)


func _physics_process(delta: float) -> void:
	tick(delta)


## One step of `delta` seconds. Returns the NPC that barked this step (or null).
func tick(delta: float) -> PlacedNpc:
	_clock += delta
	_live = _live.filter(func(bubble: SpeechBubble) -> bool: return is_instance_valid(bubble))
	if hero == null or not is_instance_valid(hero) or not is_inside_tree():
		return null
	if HeroLink.is_frozen(hero) or HeroLink.is_scripted(hero) or UiStage.is_busy(get_tree()):
		return null
	if _live.size() >= int(_cfg.get("max_at_once", 1)):
		return null
	for node: Node in get_tree().get_nodes_in_group(Npc.GROUP):
		var npc: PlacedNpc = node as PlacedNpc
		if npc == null or not npc.is_inside_tree() or not npc.is_present():
			continue
		if _wants_to_bark(npc):
			_bark(npc)
			return npc
	return null


func _wants_to_bark(npc: PlacedNpc) -> bool:
	var radius: float = float(npc.data.get("bark_radius_m", 0.0))
	if radius <= 0.0 or (npc.data.get("barks", []) as Array).is_empty():
		return false
	if _clock < float(_next_ok.get(npc.get_instance_id(), 0.0)):
		return false
	var flat: Vector3 = npc.global_position - hero.global_position
	flat.y = 0.0
	return flat.length() <= radius


## The NPC says its next line now.
func _bark(npc: PlacedNpc) -> void:
	var id: int = npc.get_instance_id()
	var lines: Array = npc.data.get("barks", []) as Array
	var at: int = int(_turn.get(id, 0))
	_turn[id] = at + 1
	var text: String = str(lines[at % lines.size()])
	var cooldown: float = float(npc.data.get("bark_cooldown_s", _cfg.get("cooldown_s", 12.0)))
	_next_ok[id] = _clock + cooldown
	var speaker: String = str(npc.data.get("bark_speaker", npc.speaker_id))
	barked.emit(speaker, text)
	if show_bubbles:
		_show(npc, speaker, text)


func _show(npc: PlacedNpc, speaker: String, text: String) -> void:
	var scene: PackedScene = load(BUBBLE_SCENE) as PackedScene
	if scene == null:
		return
	var bubble: SpeechBubble = scene.instantiate() as SpeechBubble
	bubble.listen_input = false              # a bark takes no button
	bubble.auto_advance_override = 1         # and turns over by itself
	bubble.manual_ticks = manual_ticks
	bubble.camera = camera
	var parent: Node = parent_override if parent_override != null else UiStage.get_or_create(get_tree()).get_stage_root()
	parent.add_child(bubble)
	bubble.set_target(npc, npc.get_head_height())
	bubble.setup_text(speaker, text, [], SpeechBubble.STYLE_BUBBLE)
	bubble.remove_from_group(UiStage.MODAL_GROUP)       # a bark is not a menu: Red can still walk, talk and use doors
	bubble.advanced.connect(bubble.close)
	_live.append(bubble)


func live_count() -> int:
	_live = _live.filter(func(bubble: SpeechBubble) -> bool: return is_instance_valid(bubble))
	return _live.size()


func _exit_tree() -> void:
	for bubble: SpeechBubble in _live:
		if is_instance_valid(bubble):
			bubble.queue_free()
	_live.clear()
