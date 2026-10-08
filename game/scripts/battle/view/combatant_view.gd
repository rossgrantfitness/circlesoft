class_name CombatantView
extends Node3D
## One fighter on the battle stage: a model loaded BY PATH (so any artist's .glb or .tscn drops in), its looping
## `idle` clip, a blob shadow, and every reaction as a code tween (Ross, 2026-10-06: no new authored clips):
## lunge, cast, defend, hit recoil with squash and white flash, block brace, heal hop, K.O. fall-over (or crash for
## flyers), the grunts' white-flag leave, the victory hop. Pure view: it never decides a result.
##
## Node layout:  CombatantView (home position, yaw, lunges)
##                 +- Pivot (squash, hops, recoil, fall-over)
##                 |    +- the model
##                 +- Shadow (flat dithered blob on the floor)
## Models face +Z (the model contract). Materials are copied per view, so a flash or a face swap on one grunt
## never touches the others.

const PROP_MARK: String = "_prop_"
const FLAG_MARK: String = "_prop_flag"
const FACE_MARK: String = "_face"
const IDLE_CLIP: StringName = &"idle"
const PARAM_TINT: StringName = &"albedo_tint"
const PARAM_UV_OFFSET: StringName = &"uv_offset"
const FACE_SWAP_OFFSET: Vector2 = Vector2(0.5, 0.0)
const FLAG_ARM_BONE: String = "upper_arm_r"
const FLAG_WAVE_BONE: String = "forearm_r"
const SHADOW_LIFT: float = 0.012
const SHADOW_SHADER: String = "res://shaders/psx_unlit.gdshader"
const FALLBACK_HEIGHT: float = 1.0
const MS: float = 1000.0

var combatant_id: String = ""
var side: String = "party"
var slot: int = 0
var kind: String = ""
var display_name: String = ""
var is_boss: bool = false
var hp: int = 0
var hp_max: int = 0
var down: bool = false
var gone: bool = false
var home_position: Vector3 = Vector3.ZERO
var home_yaw: float = 0.0
var model_path: String = ""
var used_fallback: bool = false
## Top of the body (props excluded) and lowest point of the body, in model units: for head points and flyers.
var body_top: float = FALLBACK_HEIGHT
var body_bottom: float = 0.0
var has_flag: bool = false
var swaps_face: bool = false

var pivot: Node3D = null
var model: Node3D = null
var animation_player: AnimationPlayer = null
var skeleton: Skeleton3D = null
var shadow: MeshInstance3D = null

var _tuning: BattleStageTuning = null
var _materials: Array[ShaderMaterial] = []
var _base_tints: Array[Color] = []
var _flag_node: Node3D = null
var _move_tween: Tween = null
var _pose_tween: Tween = null
var _flash_tween: Tween = null
var _face_tween: Tween = null
var _fx_tween: Tween = null
var _dim: Color = Color.WHITE
var _frozen: bool = false
var _saved_speed: float = 1.0
var _arm_raise: float = 0.0
var _arm_wave: float = 0.0


## Builds the view from a snapshot combatant. `path` is the model to load; if it cannot load, a plain stand-in
## (a capsule and a ball in the side's color) is built so a battle never fails on a missing model.
func setup(info: Dictionary, tuning: BattleStageTuning, path: String) -> void:
	_tuning = tuning
	combatant_id = str(info.get("id", ""))
	name = "View_" + combatant_id
	side = str(info.get("side", "party"))
	slot = int(info.get("slot", 0))
	kind = str(info.get("kind", ""))
	display_name = str(info.get("name", combatant_id))
	is_boss = bool(info.get("is_boss", false))
	hp = int(info.get("hp", 0))
	hp_max = int(info.get("hp_max", hp))
	down = bool(info.get("down", false))
	model_path = path
	swaps_face = side == "enemy"
	pivot = Node3D.new()
	pivot.name = "Pivot"
	add_child(pivot)
	model = _load_model(path)
	if model == null:
		used_fallback = true
		model = _build_fallback()
	pivot.add_child(model)
	if is_boss:
		pivot.scale = Vector3.ONE * tuning.number("model.boss_scale")
	_measure()
	_prepare_materials()
	_find_flag()
	_find_player()
	_build_shadow()
	if down:
		_pose_fallen(true)


func _process(_delta: float) -> void:
	if _arm_raise > 0.0 or _arm_wave != 0.0:
		_apply_flag_arm()


# ---- placement ----

func set_home(point: Vector3, yaw: float) -> void:
	home_position = point
	home_yaw = yaw
	position = point
	rotation.y = yaw


func face_toward(world_point: Vector3, ms: float = 0.0) -> void:
	var flat: Vector3 = world_point - global_position if is_inside_tree() else world_point - position
	flat.y = 0.0
	if flat.length() < 0.001:
		return
	var yaw: float = atan2(flat.x, flat.z)
	_turn_to(yaw, ms)


## Top of the head in world space (for the "!" and pop-ups): follows hops and lunges.
func get_head_point() -> Vector3:
	var top: Vector3 = Vector3(0.0, body_top * pivot.scale.y, 0.0)
	return pivot.global_transform * Vector3(0.0, body_top, 0.0) if is_inside_tree() else position + top


func get_center_point() -> Vector3:
	var mid: float = (body_top + body_bottom) * 0.5
	return pivot.global_transform * Vector3(0.0, mid, 0.0) if is_inside_tree() else position + Vector3(0.0, mid, 0.0)


func get_feet_point() -> Vector3:
	return global_position if is_inside_tree() else position


## True when the body floats (the drones): its lowest point is well above the floor.
func is_flyer() -> bool:
	return body_bottom > _tuning.number("model.flyer_min_height")


func idle() -> void:
	if animation_player != null and animation_player.has_animation(IDLE_CLIP):
		animation_player.play(IDLE_CLIP)
		animation_player.seek(float(absi(combatant_id.hash()) % 1000) / 1000.0 * animation_player.current_animation_length, true)


func has_idle_clip() -> bool:
	return animation_player != null and animation_player.has_animation(IDLE_CLIP)


# ---- freezing (the K.O. beat) ----

func freeze(on: bool) -> void:
	if on == _frozen:
		return
	_frozen = on
	for tween: Tween in [_move_tween, _pose_tween, _flash_tween, _face_tween, _fx_tween]:
		if tween != null and tween.is_valid():
			if on:
				tween.pause()
			else:
				tween.play()
	if animation_player != null:
		if on:
			_saved_speed = animation_player.speed_scale
			animation_player.speed_scale = 0.0
		else:
			animation_player.speed_scale = _saved_speed


func is_frozen() -> bool:
	return _frozen


# ---- actions ----

## Melee-style move: lean back through the wind-up (the tell), dash in at the target, jab at the impact.
## `lead_s` is a delay before the move starts (the action's t0 can be a hair in the future).
func lunge(target_point: Vector3, windup_s: float, impact_s: float, lead_s: float = 0.0) -> void:
	var cfg: Dictionary = _tuning.dict("motion.lunge")
	var to_target: Vector3 = target_point - position
	to_target.y = 0.0
	var distance: float = to_target.length()
	var dir: Vector3 = to_target.normalized() if distance > 0.001 else Vector3.RIGHT
	var stop_distance: float = minf(float(cfg["stop_distance"]), distance)
	var strike_point: Vector3 = Vector3(target_point.x, home_position.y, target_point.z) - dir * stop_distance
	var back_point: Vector3 = home_position - dir * float(cfg["lean_back"])
	var dash_s: float = maxf(impact_s - windup_s, float(cfg["dash_min_ms"]) / MS)
	var lean_s: float = maxf(windup_s * float(cfg["lean_back_fraction"]), 0.04)
	var hold_s: float = maxf(windup_s - lean_s, 0.0)
	var jab: float = float(cfg["jab"])
	var jab_s: float = float(cfg["jab_ms"]) / MS
	var yaw: float = atan2(dir.x, dir.z)
	_kill(_move_tween)
	_kill(_pose_tween)
	_turn_to(yaw, lean_s * MS * 0.6)
	_move_tween = create_tween()
	if lead_s > 0.0:
		_move_tween.tween_interval(lead_s)
	_move_tween.tween_property(self, "position", back_point, lean_s).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if hold_s > 0.0:
		_move_tween.tween_interval(hold_s)
	_move_tween.tween_property(self, "position", strike_point, dash_s).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_move_tween.tween_property(self, "position", strike_point + dir * jab, jab_s).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var crouch: Vector3 = BattleStageTuning.vec3_of(cfg["crouch"])
	var stretch: Vector3 = BattleStageTuning.vec3_of(cfg["stretch"])
	_pose_tween = create_tween()
	if lead_s > 0.0:
		_pose_tween.tween_interval(lead_s)
	_pose_tween.tween_property(pivot, "scale", crouch, lean_s).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if hold_s > 0.0:
		_pose_tween.tween_interval(hold_s)
	_pose_tween.tween_property(pivot, "scale", stretch, dash_s * 0.6)
	_pose_tween.tween_property(pivot, "scale", Vector3.ONE, dash_s * 0.4 + jab_s)


## Cast / skill without a target to run at: a squash, then a hop at the impact.
func cast(windup_s: float, impact_s: float, lead_s: float = 0.0) -> void:
	var cfg: Dictionary = _tuning.dict("motion.cast")
	var squash: Vector3 = BattleStageTuning.vec3_of(cfg["squash"])
	var hop: float = float(cfg["hop"])
	var load_s: float = maxf(windup_s * float(cfg["windup_fraction"]), 0.05)
	var up_s: float = maxf(impact_s - load_s, 0.1) * 0.5
	_kill(_pose_tween)
	_pose_tween = create_tween()
	if lead_s > 0.0:
		_pose_tween.tween_interval(lead_s)
	_pose_tween.tween_property(pivot, "scale", squash, load_s).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pose_tween.tween_property(pivot, "scale", Vector3(0.92, 1.12, 0.92), 0.06)
	_pose_tween.parallel().tween_property(pivot, "position:y", hop, up_s).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pose_tween.tween_property(pivot, "position:y", 0.0, up_s).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_pose_tween.parallel().tween_property(pivot, "scale", Vector3.ONE, up_s)


func defend_pose() -> void:
	var cfg: Dictionary = _tuning.dict("motion.defend")
	_kill(_pose_tween)
	_pose_tween = create_tween()
	_pose_tween.tween_property(pivot, "scale", BattleStageTuning.vec3_of(cfg["crouch"]), float(cfg["in_ms"]) / MS)
	_pose_tween.parallel().tween_property(pivot, "rotation:x", deg_to_rad(float(cfg["lean_deg"])), float(cfg["in_ms"]) / MS)


func item_pose() -> void:
	var cfg: Dictionary = _tuning.dict("motion.item")
	_hop(float(cfg["hop"]), float(cfg["ms"]) / MS)


## Everything back to the home spot and the neutral pose (action finished, or defend ended).
func return_home() -> void:
	var cfg: Dictionary = _tuning.dict("motion.lunge")
	var ms: float = float(cfg["return_ms"]) / MS
	_kill(_move_tween)
	_kill(_pose_tween)
	_move_tween = create_tween()
	_move_tween.tween_property(self, "position", home_position, ms).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_turn_to(home_yaw, ms * MS)
	_pose_tween = create_tween()
	_pose_tween.tween_property(pivot, "scale", _rest_scale(), ms)
	_pose_tween.parallel().tween_property(pivot, "position:y", 0.0, ms)
	_pose_tween.parallel().tween_property(pivot, "rotation:x", 0.0, ms)


## A short hop to show it is this fighter's turn.
func ready_pop() -> void:
	var cfg: Dictionary = _tuning.dict("motion.turn_ready")
	_hop(float(cfg["hop"]), float(cfg["ms"]) / MS)


# ---- reactions ----

## The cue flash: the whole model blows out to white-ish for `ms`.
func flash(color: Color, ms: float) -> void:
	_kill(_flash_tween)
	_set_tint_flash(color)
	_flash_tween = create_tween()
	_flash_tween.tween_interval(ms / MS)
	_flash_tween.tween_callback(_clear_flash)


## Got hit: white flash, a recoil away from the source, a squash, and (enemies) the ouch face.
func react_hit(away: Vector3, big: bool) -> void:
	var cfg: Dictionary = _tuning.dict("motion.hit")
	var dir: Vector3 = away
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.001 else Vector3.LEFT
	var distance: float = float(cfg["recoil_big"]) if big else float(cfg["recoil"])
	var ms: float = float(cfg["recoil_ms"]) / MS
	flash(Color(2.6, 2.6, 2.6), float(cfg["flash_ms"]))
	_kill(_move_tween)
	_move_tween = create_tween()
	_move_tween.tween_property(self, "position", position + dir * distance, ms * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_move_tween.tween_property(self, "position", home_position, ms * 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_squash(BattleStageTuning.vec3_of(cfg["squash"]), float(cfg["squash_ms"]) / MS)
	if swaps_face:
		show_hurt_face(float(cfg["face_swap_ms"]))


## Blocked: a brace (small push-back and squash). Perfect: a bright shield-blink instead of a recoil.
func react_block(away: Vector3, perfect: bool) -> void:
	var cfg: Dictionary = _tuning.dict("motion.hit")
	var dir: Vector3 = away
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.001 else Vector3.LEFT
	if perfect:
		flash(Color(2.2, 2.2, 1.9), float(cfg["perfect_block_flash_ms"]))
		_squash(Vector3(1.06, 0.94, 1.06), 0.12)
		return
	_kill(_move_tween)
	_move_tween = create_tween()
	var push: float = float(cfg["block_push"])
	_move_tween.tween_property(self, "position", position + dir * push, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_move_tween.tween_property(self, "position", home_position, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_squash(Vector3(1.1, 0.88, 1.1), 0.14)


## Payback: after a perfect block, a quick counter lunge at whoever swung.
func react_payback(toward_point: Vector3) -> void:
	var cfg: Dictionary = _tuning.dict("motion.hit")
	var dir: Vector3 = toward_point - position
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.001 else Vector3.RIGHT
	_kill(_move_tween)
	_move_tween = create_tween()
	_move_tween.tween_property(self, "position", position + dir * float(cfg["payback_lunge"]), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_move_tween.tween_interval(0.12)
	_move_tween.tween_property(self, "position", home_position, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func react_heal() -> void:
	var cfg: Dictionary = _tuning.dict("motion.hit")
	_hop(float(cfg["heal_hop"]), 0.26)
	flash(_tuning.color("motion.hit.heal_color").lightened(0.2) * 1.6, 120.0)


func show_hurt_face(ms: float) -> void:
	if not swaps_face:
		return
	_kill(_face_tween)
	_set_face_offset(FACE_SWAP_OFFSET)
	_face_tween = create_tween()
	_face_tween.tween_interval(ms / MS)
	_face_tween.tween_callback(_set_face_offset.bind(Vector2.ZERO))


func has_face_sheet() -> bool:
	for material: ShaderMaterial in _materials:
		if material.resource_name.ends_with(FACE_MARK):
			return true
	return false


## Face sheet column currently shown: 0 = first expression, 1 = second.
func face_column() -> int:
	for material: ShaderMaterial in _materials:
		if material.resource_name.ends_with(FACE_MARK):
			var offset: Variant = material.get_shader_parameter(PARAM_UV_OFFSET)
			if offset is Vector2 and (offset as Vector2).x > 0.25:
				return 1
	return 0


## Down for the Count / K.O.: fall over backwards (flyers crash). Enemies then blink out; party stay down.
func knock_out(away: Vector3 = Vector3.LEFT) -> void:
	if down and _pose_fallen_state:
		return
	down = true
	var cfg: Dictionary = _tuning.dict("motion.ko_fall")
	var ms: float = float(cfg["ms"]) / MS
	_kill(_move_tween)
	_kill(_pose_tween)
	_pose_tween = create_tween()
	if is_flyer():
		var crash_s: float = float(cfg["crash_ms"]) / MS
		_pose_tween.tween_property(pivot, "position:y", -body_bottom * 0.92, crash_s).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_pose_tween.parallel().tween_property(pivot, "rotation:y", deg_to_rad(float(cfg["crash_spin_deg"])), crash_s)
		_pose_tween.parallel().tween_property(pivot, "rotation:z", deg_to_rad(80.0), crash_s)
	else:
		_pose_tween.tween_property(pivot, "rotation:x", deg_to_rad(float(cfg["pitch_deg"])), ms).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_pose_tween.parallel().tween_property(pivot, "position:y", float(cfg["sink"]), ms * 0.8)
	_pose_fallen_state = true
	if side == "enemy":
		_pose_tween.tween_callback(_blink_out.bind(float(cfg["blink_ms"]) / MS, float(cfg["blink_hz"])))


## Up again after a revive: stand back up with a hop.
func revive() -> void:
	down = false
	_pose_fallen_state = false
	gone = false
	visible = true
	if shadow != null:
		shadow.visible = true
	var cfg: Dictionary = _tuning.dict("motion.revive")
	var ms: float = float(cfg["ms"]) / MS
	_kill(_pose_tween)
	_pose_tween = create_tween()
	_pose_tween.tween_property(pivot, "rotation", Vector3.ZERO, ms)
	_pose_tween.parallel().tween_property(pivot, "position:y", float(cfg["hop"]), ms * 0.5)
	_pose_tween.tween_property(pivot, "position:y", 0.0, ms * 0.5)
	_pose_tween.parallel().tween_property(pivot, "scale", _rest_scale(), ms * 0.5)
	flash(Color(2.2, 2.4, 2.0), 90.0)


## Gives up (nearly beaten): the grunts raise a white flag, wave it and walk off; anything without a flag
## (the drones) zips away. Ends with the view hidden.
func flee(away_dir: Vector3) -> void:
	var cfg: Dictionary = _tuning.dict("motion.flag")
	var dir: Vector3 = away_dir
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.001 else Vector3.LEFT
	down = true
	_kill(_move_tween)
	_kill(_pose_tween)
	_kill(_fx_tween)
	if has_flag and skeleton != null:
		if animation_player != null:
			animation_player.stop(true)
		if _flag_node != null:
			_flag_node.visible = true
		show_hurt_face(float(cfg["raise_ms"]) / MS)
		_fx_tween = create_tween()
		_fx_tween.tween_property(self, "_arm_raise", 1.0, float(cfg["raise_ms"]) / MS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_fx_tween.tween_method(_set_wave, 0.0, 1.0, float(cfg["wave_ms"]) / MS)
		_fx_tween.tween_callback(_turn_away_and_walk.bind(dir))
	else:
		var zip_s: float = float(cfg["zip_off_ms"]) / MS
		_fx_tween = create_tween()
		_fx_tween.tween_property(pivot, "position:y", pivot.position.y + 0.6, zip_s * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_fx_tween.tween_property(self, "position", position + dir * float(cfg["walk_off_distance"]) + Vector3(0.0, 0.0, 0.0), zip_s).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_fx_tween.tween_callback(_hide_gone)


## The small victory hop.
func victory_hop(delay_s: float = 0.0) -> void:
	if down:
		return
	var cfg: Dictionary = _tuning.dict("motion.victory_hop")
	var height: float = float(cfg["height"])
	var ms: float = float(cfg["ms"]) / MS
	_kill(_pose_tween)
	_pose_tween = create_tween()
	if delay_s > 0.0:
		_pose_tween.tween_interval(delay_s)
	for i: int in int(cfg["count"]):
		_pose_tween.tween_property(pivot, "position:y", height, ms * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_pose_tween.tween_property(pivot, "position:y", 0.0, ms * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_pose_tween.tween_property(pivot, "scale", Vector3(1.1, 0.9, 1.1), 0.05)
		_pose_tween.tween_property(pivot, "scale", Vector3.ONE, 0.07)


# ---- tint and flash ----

func current_tint_energy() -> float:
	if _materials.is_empty():
		return 0.0
	var tint: Variant = _materials[0].get_shader_parameter(PARAM_TINT)
	if tint is Color:
		return (tint as Color).get_luminance()
	return 0.0


func is_flashing() -> bool:
	return _flash_tween != null and _flash_tween.is_valid()


func material_count() -> int:
	return _materials.size()


func _set_tint_flash(color: Color) -> void:
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter(PARAM_TINT, color)


func _clear_flash() -> void:
	for i: int in _materials.size():
		_materials[i].set_shader_parameter(PARAM_TINT, _dimmed(_base_tints[i]))


## Multiplies every color (the boss intro shows the party as dark silhouettes). Color.WHITE puts it back.
func set_dim(color: Color) -> void:
	_dim = color
	if not is_flashing():
		_clear_flash()


func _dimmed(base: Color) -> Color:
	return Color(base.r * _dim.r, base.g * _dim.g, base.b * _dim.b, base.a)


func _set_face_offset(offset: Vector2) -> void:
	for material: ShaderMaterial in _materials:
		if material.resource_name.ends_with(FACE_MARK):
			material.set_shader_parameter(PARAM_UV_OFFSET, offset)


# ---- tween helpers ----

var _pose_fallen_state: bool = false


func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()


func _rest_scale() -> Vector3:
	return Vector3.ONE * (_tuning.number("model.boss_scale") if is_boss else 1.0)


func _turn_to(yaw: float, ms: float) -> void:
	var target: float = rotation.y + angle_difference(rotation.y, yaw)
	if ms <= 0.0:
		rotation.y = yaw
		return
	var tween: Tween = create_tween()
	tween.tween_property(self, "rotation:y", target, ms / MS)


func _squash(scale_to: Vector3, ms: float) -> void:
	_kill(_pose_tween)
	_pose_tween = create_tween()
	_pose_tween.tween_property(pivot, "scale", scale_to, ms * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pose_tween.tween_property(pivot, "scale", _rest_scale(), ms * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hop(height: float, ms: float) -> void:
	_kill(_pose_tween)
	_pose_tween = create_tween()
	_pose_tween.tween_property(pivot, "position:y", height, ms * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pose_tween.tween_property(pivot, "position:y", 0.0, ms * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _pose_fallen(instant: bool) -> void:
	var cfg: Dictionary = _tuning.dict("motion.ko_fall")
	_pose_fallen_state = true
	if is_flyer():
		pivot.position.y = -body_bottom * 0.92
		pivot.rotation = Vector3(0.0, 0.0, deg_to_rad(80.0))
	else:
		pivot.rotation.x = deg_to_rad(float(cfg["pitch_deg"]))
		pivot.position.y = float(cfg["sink"])
	if instant and animation_player != null:
		animation_player.stop(true)


func _blink_out(total_s: float, hz: float) -> void:
	_kill(_fx_tween)
	_fx_tween = create_tween()
	_fx_tween.tween_method(_blink_step.bind(hz), 0.0, total_s, total_s)
	_fx_tween.tween_callback(_hide_gone)


func _blink_step(t: float, hz: float) -> void:
	var shown: bool = fmod(t * hz, 1.0) < 0.5
	if pivot != null:
		pivot.visible = shown
	if shadow != null:
		shadow.visible = shown


func _hide_gone() -> void:
	gone = true
	visible = false


func _turn_away_and_walk(dir: Vector3) -> void:
	var cfg: Dictionary = _tuning.dict("motion.flag")
	var walk_s: float = float(cfg["walk_off_ms"]) / MS
	_turn_to(atan2(dir.x, dir.z), 160.0)
	_kill(_move_tween)
	_move_tween = create_tween()
	_move_tween.tween_property(self, "position", position + dir * float(cfg["walk_off_distance"]), walk_s)
	_move_tween.tween_callback(_hide_gone)
	_kill(_pose_tween)
	_pose_tween = create_tween()
	var steps: int = maxi(int(walk_s / 0.18), 1)
	for i: int in steps:
		_pose_tween.tween_property(pivot, "position:y", 0.1, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_pose_tween.tween_property(pivot, "position:y", 0.0, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _set_wave(t: float) -> void:
	var cfg: Dictionary = _tuning.dict("motion.flag")
	_arm_wave = sin(t * TAU * float(cfg["wave_count"])) * deg_to_rad(float(cfg["wave_deg"]))


# ---- the white-flag arm: bones posed by code (no authored clip) ----

func _apply_flag_arm() -> void:
	if skeleton == null:
		return
	var cfg: Dictionary = _tuning.dict("motion.flag")
	var raise: float = deg_to_rad(float(cfg["arm_raise_deg"])) * _arm_raise
	# the character's right arm hangs at -X; turning it about +Z by a negative angle swings it out and up
	_pose_bone(FLAG_ARM_BONE, Vector3.BACK, -raise)
	_pose_bone(FLAG_WAVE_BONE, Vector3.BACK, _arm_wave)


## Rotates a bone about a skeleton-space axis from its rest orientation (children follow).
func _pose_bone(bone_name: String, axis: Vector3, angle: float) -> void:
	var index: int = skeleton.find_bone(bone_name)
	if index < 0:
		return
	var parent: int = skeleton.get_bone_parent(index)
	var parent_basis: Basis = skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	var rest_basis: Basis = skeleton.get_bone_rest(index).basis
	var turned: Basis = parent_basis.inverse() * Basis(axis, angle) * parent_basis * rest_basis
	skeleton.set_bone_pose_rotation(index, turned.get_rotation_quaternion())


# ---- building ----

func _load_model(wanted: String) -> Node3D:
	var path: String = LookProfiles.resolve_model(wanted)
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var resource: Resource = load(path)
	if resource is PackedScene:
		var instance: Node3D = (resource as PackedScene).instantiate() as Node3D
		LookProfiles.dress_model(instance, path)
		return instance
	return null


func _build_fallback() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Fallback"
	var color: Color = _tuning.color("model.fallback_colors." + side)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load("res://shaders/psx_lit.gdshader") as Shader
	material.set_shader_parameter(&"albedo_texture", BattleTextures.shadow_texture(8, Color.WHITE))
	material.set_shader_parameter(&"albedo_tint", color)
	material.set_shader_parameter(&"uv_scale", Vector2(0.01, 0.01))
	material.set_shader_parameter(&"uv_offset", Vector2(0.5, 0.5))
	var body: MeshInstance3D = MeshInstance3D.new()
	body.name = "Body"
	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.radius = 0.28
	capsule.height = 0.8
	capsule.radial_segments = 8
	capsule.rings = 3
	body.mesh = capsule
	body.position = Vector3(0.0, 0.4, 0.0)
	body.set_surface_override_material(0, material)
	root.add_child(body)
	var head: MeshInstance3D = MeshInstance3D.new()
	head.name = "Head"
	var ball: SphereMesh = SphereMesh.new()
	ball.radius = 0.24
	ball.height = 0.48
	ball.radial_segments = 8
	ball.rings = 4
	head.mesh = ball
	head.position = Vector3(0.0, 0.88, 0.0)
	head.set_surface_override_material(0, material)
	root.add_child(head)
	return root


## Measures the body (props excluded) in model space: top and bottom, for head points and flyer detection.
func _measure() -> void:
	var top: float = -INF
	var bottom: float = INF
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh == null or String(mesh_instance.name).contains(PROP_MARK):
			continue
		var box: AABB = _to_model_space(mesh_instance) * mesh_instance.get_aabb()
		top = maxf(top, box.end.y)
		bottom = minf(bottom, box.position.y)
	body_top = top if top > -INF else FALLBACK_HEIGHT
	body_bottom = bottom if bottom < INF else 0.0


func _to_model_space(node: Node3D) -> Transform3D:
	var xf: Transform3D = Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != model:
		if current is Node3D:
			xf = (current as Node3D).transform * xf
		current = current.get_parent()
	return xf


func _prepare_materials() -> void:
	var tint: Color = _tuning.color("model.tint")
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface: int in mesh_instance.mesh.get_surface_count():
			var source: ShaderMaterial = mesh_instance.get_active_material(surface) as ShaderMaterial
			if source == null:
				continue
			var copy: ShaderMaterial = source.duplicate() as ShaderMaterial
			var base: Variant = copy.get_shader_parameter(PARAM_TINT)
			var base_color: Color = (base as Color) if base is Color else Color.WHITE
			var lit_color: Color = Color(base_color.r * tint.r, base_color.g * tint.g, base_color.b * tint.b, base_color.a)
			copy.set_shader_parameter(PARAM_TINT, lit_color)
			mesh_instance.set_surface_override_material(surface, copy)
			_materials.append(copy)
			_base_tints.append(lit_color)


func _find_flag() -> void:
	for node: Node in model.find_children("*" + FLAG_MARK + "*", "Node3D", true, false):
		_flag_node = node as Node3D
		_flag_node.visible = false
		has_flag = true
		return


func _find_player() -> void:
	var found: Array[Node] = model.find_children("*", "AnimationPlayer", true, false)
	if not found.is_empty():
		animation_player = found[0] as AnimationPlayer
	var skeletons: Array[Node] = model.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
		skeleton = skeletons[0] as Skeleton3D


func _build_shadow() -> void:
	var radius: float = _tuning.number("formation.shadow.radius")
	shadow = MeshInstance3D.new()
	shadow.name = "Shadow"
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(radius * 2.0, radius * 2.0)
	quad.orientation = PlaneMesh.FACE_Y
	shadow.mesh = quad
	shadow.position = Vector3(0.0, SHADOW_LIFT, 0.0)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load(SHADOW_SHADER) as Shader
	var px: int = _tuning.integer("formation.shadow.texture_px")
	material.set_shader_parameter(&"albedo_texture", BattleTextures.shadow_texture(px, _tuning.color("formation.shadow.color")))
	material.set_shader_parameter(&"uv_scale", Vector2.ONE)
	material.set_shader_parameter(&"affine_amount", 0.0)
	shadow.set_surface_override_material(0, material)
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow)
