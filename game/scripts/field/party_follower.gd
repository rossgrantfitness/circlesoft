class_name PartyFollower
extends CharacterBody3D
## One crew member walking behind Red (placeholder: the character's own model, an idle clip and a
## little walking bounce in code). It has no collision with Red at all: it sits on layer 4 and
## collides with nothing, and Red only collides with layer 1, so the crew can never block her.
## PartyFollow tells it where to be every frame (move_to).

const LAYER_FOLLOWER: int = 8
const NODE_VISUAL: String = "Visual"
const HEAD_LIFT: float = 0.1
const LIGHT_COMPENSATION: Color = Color(1.28, 1.1, 0.86)
const IDLE_CLIP: StringName = &"idle"

var member_id: String = ""
## How fast it moved last frame (units per second).
var current_speed: float = 0.0

var _tuning: ExplorationTuning = null
var _visual: Node3D = null
var _model: Node3D = null
var _head_top: float = 1.0
var _clock: float = 0.0


func setup(id: String, model_path: String, tuning: ExplorationTuning) -> void:
	member_id = id
	_tuning = tuning
	name = "Follower_" + id
	collision_layer = LAYER_FOLLOWER
	collision_mask = 0
	_visual = Node3D.new()
	_visual.name = NODE_VISUAL
	add_child(_visual)
	_clock = float(id.hash() % 1000) * 0.01
	_load_model(model_path)


## Moves toward `goal` by at most max_speed * delta, turning to face the way it goes and bouncing
## while it moves. Returns how far it moved.
func move_to(goal: Vector3, delta: float, max_speed: float) -> float:
	var before: Vector3 = global_position
	global_position = before.move_toward(goal, max_speed * delta)
	var moved: Vector3 = global_position - before
	current_speed = moved.length() / maxf(delta, 0.0001)
	_clock += delta
	var flat: Vector3 = Vector3(moved.x, 0.0, moved.z)
	if flat.length() > PlayerMotion.MIN_FLAT_LENGTH and delta > 0.0:
		rotation.y = PlayerMotion.turn_toward(rotation.y, PlayerMotion.yaw_for_direction(flat.normalized()),
				_tuning.follow_turn_rate_deg_per_s, delta)
	if _visual != null:
		var walking: bool = current_speed > _tuning.follow_moving_speed
		_visual.position.y = _tuning.follow_bob_height * absf(sin(_clock * _tuning.follow_bob_hz * PI)) if walking else 0.0
	return moved.length()


func is_moving() -> bool:
	return current_speed > _tuning.follow_moving_speed


func face_direction(direction: Vector3) -> void:
	var flat: Vector3 = Vector3(direction.x, 0.0, direction.z)
	if flat.length() > PlayerMotion.MIN_FLAT_LENGTH:
		rotation.y = PlayerMotion.yaw_for_direction(flat.normalized())


func get_model() -> Node3D:
	return _model


## How far above the origin a speech bubble's tail should point.
func get_head_height() -> float:
	return _head_top + HEAD_LIFT


func _load_model(path: String) -> void:
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var packed: PackedScene = load(path) as PackedScene
	_model = packed.instantiate() as Node3D if packed != null else null
	if _model == null:
		return
	_visual.add_child(_model)
	Npc.apply_light_compensation(_model, LIGHT_COMPENSATION)
	for node: Node in _model.find_children("*", "AnimationPlayer", true, false):
		var clips: AnimationPlayer = node as AnimationPlayer
		if clips.has_animation(IDLE_CLIP):
			clips.play(IDLE_CLIP)
			clips.seek(fposmod(_clock, 1.0) * clips.get_animation(IDLE_CLIP).length, true)
		break
	if is_inside_tree():
		_head_top = Npc.measure_head_top(_visual, _model)
