class_name CombatActor
extends CharacterBody3D
## Base for every fighter, Red and enemies (contract 4.2). It owns the numbers a hit changes (hp, poise,
## juggle count), a Hurtbox and a Hitbox, and its own CombatClock. It registers with the CombatDirector,
## which steps the clock and turns contacts into results; the actor only shows what happens to it.
##
## Subclasses override the underscore hooks. Nothing here moves the body: ActionPlayer and ActionEnemy do.

signal died(actor_id: StringName)

const GROUP: StringName = &"combat_actors"
const HURTBOX_NAME: String = "Hurtbox"
const HITBOX_NAME: String = "Hitbox"

@export var actor_id: StringName = &""
@export var team: StringName = &"enemy"
## Which set in moves.json this fighter plays (&"red", &"grunt", &"brute").
@export var move_set_id: StringName = &""

var hp: int = 100
var hp_max: int = 100
var poise: float = 0.0
var poise_max: float = 0.0
var weight: float = 1.0
var launchable: bool = true
var height_m: float = 1.0
var radius_m: float = 0.35
var juggle_count: int = 0
var clock: CombatClock = CombatClock.new()
var dead: bool = false
var last_result: Dictionary = {}
var poise_regen_delay_ms: float = 1500.0
var poise_regen_per_s: float = 15.0

var _hurtbox: Hurtbox = null
var _hitbox: Hitbox = null
var _director: CombatDirector = null
var _last_hit_ms: float = -1.0e9
var _air_hit_ms: float = -1.0e9


func _ready() -> void:
	if actor_id == &"":
		actor_id = StringName(name.to_lower())
	add_to_group(GROUP)
	collision_layer = CombatLayers.bit(CombatLayers.body_layer(team))
	collision_mask = CombatLayers.body_mask(team)
	_make_combat_nodes()
	var found: CombatDirector = find_director()
	if found != null:
		found.register(self)


func _exit_tree() -> void:
	if _director != null and is_instance_valid(_director):
		_director.unregister(self)
	_director = null


## The director in the tree (cached), or null in a bare test.
func find_director() -> CombatDirector:
	if _director != null and is_instance_valid(_director):
		return _director
	if not is_inside_tree():
		return null
	_director = get_tree().get_first_node_in_group(CombatDirector.GROUP) as CombatDirector
	return _director


## Called by the director when it registers this fighter.
func bind_director(director: CombatDirector) -> void:
	_director = director
	if _hitbox != null:
		_hitbox.director = director


func get_hurtbox() -> Hurtbox:
	return _hurtbox


func get_hitbox() -> Hitbox:
	return _hitbox


## How much of this physics frame the fighter lives through (0 in hit-stop, less in a flare).
func local_delta(real_delta: float) -> float:
	var director: CombatDirector = find_director()
	return director.delta_for(self, real_delta) if director != null else real_delta


## Multiply the velocity by the local speed around move_and_slide, then divide it back, so a slowed
## fighter moves slowly through the same physics step. A frozen fighter does not move at all.
func slide_scaled(local_scale: float) -> void:
	if local_scale <= 0.0:
		return
	if is_equal_approx(local_scale, 1.0):
		move_and_slide()
		return
	velocity *= local_scale
	move_and_slide()
	velocity /= local_scale


func is_airborne() -> bool:
	return not is_on_floor()


## Dash i-frames, spawn protection and so on. Subclasses override.
func is_invulnerable() -> bool:
	return false


## Super armor right now (a move's armor window, Lights On). Subclasses override.
func is_armored() -> bool:
	return false


## The swing id of the move being played (for threats). Subclasses override.
func current_swing_id() -> int:
	return 0


func forward() -> Vector3:
	var flat: Vector3 = global_transform.basis.z
	flat.y = 0.0
	return flat.normalized() if flat.length() > 0.001 else Vector3.BACK


## A point on the fighter in world space: &"head", &"center", &"feet" or &"lamp".
func anchor(point: StringName) -> Vector3:
	var base: Vector3 = global_position
	match point:
		&"head":
			return base + Vector3(0.0, height_m, 0.0)
		&"feet":
			return base
		&"lamp":
			return base + Vector3(0.0, height_m * 0.62, 0.0) + forward() * (radius_m * 0.5)
		_:
			return base + Vector3(0.0, height_m * 0.5, 0.0)


func snapshot() -> Dictionary:
	return {
		"id": actor_id, "team": team, "airborne": is_airborne(), "invulnerable": is_invulnerable(),
		"poise": poise, "poise_max": poise_max, "armored": is_armored(), "juggle_count": juggle_count,
		"launchable": launchable, "hp": hp, "position": global_position, "forward": forward(), "weight": weight,
	}


## Victim side: take the numbers from a resolved hit. Subclasses add the reaction in _on_hit_reaction.
func apply_hit(result: Dictionary) -> void:
	last_result = result
	hp = maxi(hp - int(result.get("damage", 0)), 0)
	poise = float(result.get("poise_after", poise))
	juggle_count = int(result.get("juggle_count", juggle_count))
	_last_hit_ms = clock.now_ms()
	if bool(result.get("air_hit", false)) or float(result.get("launch_mps", 0.0)) > 0.0:
		_air_hit_ms = clock.now_ms()
	_on_hit_reaction(result)
	if hp <= 0 and not dead:
		dead = true
		_on_death(result)
		died.emit(actor_id)


## Attacker side: my hit connected (air hang, follow jump, rumble). Subclasses override _on_hit_landed.
func on_hit_landed(result: Dictionary) -> void:
	_on_hit_landed(result)


## Attacker side: I got parried (recoil or stagger). Subclasses override _on_parried.
func on_parried(result: Dictionary) -> void:
	_on_parried(result)


## Milliseconds of this fighter's own time since it was last hit in the air (for JuggleRules gravity).
func ms_since_air_hit() -> float:
	return clock.now_ms() - _air_hit_ms


## Call every tick with the LOCAL delta: poise comes back after a quiet moment.
func tick_poise(local_dt: float) -> void:
	if poise_max <= 0.0 or poise >= poise_max or local_dt <= 0.0:
		return
	if clock.now_ms() - _last_hit_ms < poise_regen_delay_ms:
		return
	poise = minf(poise + poise_regen_per_s * local_dt, poise_max)


## Back to full health, upright and ready (respawn, reset arena).
func revive(full_hp: bool = true) -> void:
	dead = false
	if full_hp:
		hp = hp_max
	poise = poise_max
	juggle_count = 0
	last_result = {}
	var director: CombatDirector = find_director()
	if director != null:
		director.hp_changed.emit(actor_id, hp, hp_max)


func _on_hit_reaction(_result: Dictionary) -> void:
	pass


func _on_death(_result: Dictionary) -> void:
	pass


func _on_hit_landed(_result: Dictionary) -> void:
	pass


func _on_parried(_result: Dictionary) -> void:
	pass


func _make_combat_nodes() -> void:
	_hurtbox = get_node_or_null(HURTBOX_NAME) as Hurtbox
	if _hurtbox == null:
		_hurtbox = Hurtbox.new()
		_hurtbox.name = HURTBOX_NAME
		add_child(_hurtbox)
	_hurtbox.setup(self, radius_m, height_m)
	_hitbox = get_node_or_null(HITBOX_NAME) as Hitbox
	if _hitbox == null:
		_hitbox = Hitbox.new()
		_hitbox.name = HITBOX_NAME
		add_child(_hitbox)
	_hitbox.actor = self
