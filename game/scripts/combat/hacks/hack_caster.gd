class_name HackCaster
extends Node
## Red's hack button, from press to effect (docs/slice/slice_tech_plan.md 4, docs/slice/hacks_design.md). It sits on Red
## (ActionPlayer makes one by itself the first time it finds a CombatDirector, so the sandbox and every slice room get it).
##
## One press, in order:
##   1. ActionPlayer buffers a `hack` token (like any press, so a press a little early still counts).
##   2. When Red can act, `begin_cast()` picks the hack (the selected one, or the automatic pick), finds its target
##      (the hard lock, else the soft target, else straight ahead; Overclock needs something hijackable), asks HackRules
##      whether the battery, the cooldowns, the jam and the air allow it, spends the cost and starts the hack's cast move
##      (moves.json `hack_zap`, `hack_emp`, `hack_overclock`, `hack_reboot`).
##   3. The effect starts on the move's `active` moment: a Zap Drone flies, an EMP ring goes off, Overclock takes the
##      target over, Reboot heals. Hits go through `CombatDirector.report_hack_hit`.
## Everything is data: hacks.json (costs, numbers, rules), hack_text.json (the words), the `hacks` feel group (live knobs).
## Hacks never refill the battery. Red's combat clock rules cooldowns, so hit-stop pauses them.
##
## The designer's rules that stand until Ross says otherwise: a second Overclock is refused while one runs; the cost is
## refunded if the target dies during Overclock's reach; Zap and EMP may be cast in the air.

const ACTION_PREV: StringName = &"hack_prev"
const ACTION_NEXT: StringName = &"hack_next"
const ACTION_SLOTS: Array[StringName] = [&"hack_1", &"hack_2", &"hack_3", &"hack_4"]
const BUTTON: StringName = &"heavy"
const TEXT_FILE: String = "hack_text.json"
const REFUSAL_GAP_USEC: int = 500000

var player: ActionPlayer = null
var director: CombatDirector = null
var rules: HackRules = null
var selector: HackSelector = null

var _text: Dictionary = {}
var _cast: Dictionary = {}                 # the cast in flight (see begin_cast)
var _down_usec: int = -1
var _hold_fired: bool = false
var _hijack: Hijackable = null
var _link: OverclockLink = null
var _last_refusal: Dictionary = {}          # reason -> real usec of the last call-out


# ---- setup ----

## Puts the caster on Red. Safe to call twice.
func attach(who: ActionPlayer) -> void:
	player = who
	director = who.find_director()
	rules = HackRules.load_default()
	selector = HackSelector.load_default()
	_text = CombatData.read_json(CombatData.DIR + TEXT_FILE)
	ensure_actions()
	_sync_mode()
	if not who.swing_started.is_connected(_on_swing_started):
		who.swing_started.connect(_on_swing_started)


## For a host that lists the caster among its room parts: binds to the host's hero.
func bind(host: Node) -> void:
	var who: ActionPlayer = host.call(&"get_player") as ActionPlayer if host != null and host.has_method(&"get_player") else null
	if who != null:
		attach(who)


func _exit_tree() -> void:
	_clear_hijack()


## Adds the selection inputs if the project does not have them: mouse wheel and d-pad left/right to change the hack,
## keys 1 to 4 to choose one. (Not in project.godot yet; the Integrator may move them there.)
static func ensure_actions() -> void:
	_ensure_action(ACTION_PREV, [_wheel(MOUSE_BUTTON_WHEEL_UP), _pad(JOY_BUTTON_DPAD_LEFT)])
	_ensure_action(ACTION_NEXT, [_wheel(MOUSE_BUTTON_WHEEL_DOWN), _pad(JOY_BUTTON_DPAD_RIGHT)])
	var keys: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4]
	for i: int in range(ACTION_SLOTS.size()):
		_ensure_action(ACTION_SLOTS[i], [_key(keys[i])])


static func _ensure_action(action: StringName, events: Array[InputEvent]) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for event: InputEvent in events:
		InputMap.action_add_event(action, event)


static func _wheel(button: MouseButton) -> InputEvent:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	return event


static func _pad(button: JoyButton) -> InputEvent:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = button
	return event


static func _key(code: Key) -> InputEvent:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	return event


# ---- what the HUD and tests ask ----

func battery() -> HackBattery:
	return director.battery if director != null else null


## The hack the HUD shows: the selected one (pick), or the last one used (automatic).
func shown() -> StringName:
	_sync_mode()
	return selector.shown()


func selected() -> StringName:
	return selector.selected()


func is_auto() -> bool:
	_sync_mode()
	return selector.mode == HackSelector.MODE_AUTO


func is_casting() -> bool:
	return not _cast.is_empty()


func hijack() -> Hijackable:
	return _hijack if is_instance_valid(_hijack) and _hijack.is_hijacked() else null


## 0..1 of this hack's cooldown still to wait (the HUD sweep).
func cooldown_fraction(id: StringName) -> float:
	return rules.cooldown_fraction(id, _now_ms(), HackRules.knobs_from(_feel()))


## The Overclock target the HUD should mark right now (the hijackable it would take), or null.
func overclock_preview() -> Node3D:
	var found: Dictionary = _find_hijackable("overclock", _aim_dir())
	return found.get("node", null)


# ---- the command deck's API (Ross, Decision 1: a Kingdom Hearts style menu with a hack submenu) ----
# The menu (UI Programmer, VS-11) drives these; the hack button, the 1 to 4 keys and the automatic pick use the same casting path.

## Chooses the hack the hack button fires. False if there is no such hack. Announces it (`hack_selected`).
func set_current(id: StringName) -> bool:
	if selector == null or not selector.set_current(id):
		return false
	if director != null:
		director.hack_selected.emit(id)
	return true


func current() -> StringName:
	return selector.current() if selector != null else &""


## Fires the current hack, as the hack button would in pick mode (buffered, then the rules decide). True if the request was made.
func cast_current() -> bool:
	return cast_direct(current())


## Fires `id` now without changing the current one (a shortcut, or a menu entry picked and confirmed). The cost, cooldown,
## jam, target and air rules still apply; a refusal comes back through `hack_refused`. True if the request was made.
func cast_direct(id: StringName) -> bool:
	if player == null or rules == null or not rules.has_hack(id) or player.town_mode or player.get_form_id() != &"red" or player.dead:
		return false
	player.queue_hack({"held_ms": 0.0, "hack": id}, player.clock.real_now_usec())
	return true


## Everything a menu row needs about one hack: {id, name, icon, role, cost (number, the whole battery for Reboot), cost_all,
## affordable (the battery can pay), ready (no cooldown or jam in the way), castable (a cast now would start), reason (why not,
## or &""), cooldown (0..1 left)}. `castable` includes needing a target (Overclock) and the air.
func hack_status(id: StringName) -> Dictionary:
	if rules == null or director == null or not rules.has_hack(id):
		return {"id": id, "castable": false, "reason": HackRules.R_UNKNOWN}
	var battery_now: HackBattery = director.battery
	var knobs: Dictionary = _knobs()
	var now_ms: float = _now_ms()
	var found: Dictionary = _find_target(id, _aim_dir())
	var verdict: Dictionary = rules.check(id, {
		"charge": battery_now.charge(), "capacity": battery_now.capacity(), "now_ms": now_ms,
		"locked": battery_now.is_locked(now_ms), "airborne": player.is_airborne(),
		"has_target": found.has("node"), "hijack_active": hijack() != null, "knobs": knobs})
	var spec: Dictionary = rules.hack(id)
	return {"id": id, "name": rules.display_name(id), "icon": str(spec.get("icon", "")), "role": str(spec.get("role", "")),
			"cost": rules.cost(id, battery_now.charge(), knobs), "cost_all": str(spec.get("cost", 0.0)) == HackRules.COST_ALL,
			"affordable": rules.affordable(id, battery_now.charge(), battery_now.capacity(), knobs),
			"ready": rules.cooldown_left_ms(id, now_ms) <= 0.0 and not battery_now.is_locked(now_ms),
			"castable": bool(verdict["ok"]), "reason": StringName(str(verdict["reason"])),
			"cooldown": rules.cooldown_fraction(id, now_ms, knobs)}


## The statuses of all four, in menu order.
func hack_list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: StringName in rules.order():
		out.append(hack_status(id))
	return out


func battery_charge() -> float:
	return director.battery.charge() if director != null else 0.0


func battery_capacity() -> float:
	return director.battery.capacity() if director != null else 0.0


# ---- the selection (option A) ----

func select_step(direction: int) -> void:
	_sync_mode()
	if selector.mode != HackSelector.MODE_PICK:
		return
	selector.step(direction)
	_announce_selection()


func select_slot(index: int) -> void:
	_sync_mode()
	if selector.mode != HackSelector.MODE_PICK:
		return
	if selector.select_index(index):
		_announce_selection()


func _announce_selection() -> void:
	var id: StringName = selector.selected()
	if director != null:
		director.hack_selected.emit(id)
	_callout("selected", {"name": rules.display_name(id), "cost": _cost_words(id)})


## One input event from the relay (with its action names): the selection keys, wheel and d-pad.
func handle_input_event(event: InputEvent) -> void:
	if event.is_echo() or (player != null and player.town_mode):
		return
	if InputMap.has_action(ACTION_PREV) and event.is_action_pressed(ACTION_PREV):
		select_step(-1)
	elif InputMap.has_action(ACTION_NEXT) and event.is_action_pressed(ACTION_NEXT):
		select_step(1)
	else:
		for i: int in range(ACTION_SLOTS.size()):
			if InputMap.has_action(ACTION_SLOTS[i]) and event.is_action_pressed(ACTION_SLOTS[i]):
				select_slot(i)


## The same keys, polled (the game when no relay forwards events).
func poll_input() -> void:
	if player == null or player.town_mode:
		return
	if InputMap.has_action(ACTION_PREV) and Input.is_action_just_pressed(ACTION_PREV):
		select_step(-1)
	if InputMap.has_action(ACTION_NEXT) and Input.is_action_just_pressed(ACTION_NEXT):
		select_step(1)
	for i: int in range(ACTION_SLOTS.size()):
		if InputMap.has_action(ACTION_SLOTS[i]) and Input.is_action_just_pressed(ACTION_SLOTS[i]):
			select_slot(i)


# ---- the button ----

## The hack button went down (`real_usec` is its timestamp). Pick mode asks for a cast at once; automatic mode waits to
## learn whether it is a tap or a hold (a hold Reboots).
func on_button_down(real_usec: int) -> void:
	_down_usec = real_usec
	_hold_fired = false
	_sync_mode()
	if selector.mode == HackSelector.MODE_PICK:
		player.queue_hack({"held_ms": 0.0}, real_usec)


## One step, called by ActionPlayer at the end of its tick: automatic-mode hold and release, the cast in flight, a running hijack.
func tick(_delta: float) -> void:
	_poll_button()
	_tick_cast()
	if _hijack != null and (not is_instance_valid(_hijack) or not _hijack.is_hijacked()):
		_clear_hijack()


func _poll_button() -> void:
	if _down_usec < 0 or player == null:
		return
	var held_ms: float = float(player.clock.real_now_usec() - _down_usec) / 1000.0
	var still_down: bool = player.is_held(BUTTON)
	_sync_mode()
	if selector.mode == HackSelector.MODE_AUTO:
		var hold_ms: float = _knobs().get("auto_hold_ms", 0.0)
		if hold_ms <= 0.0:
			hold_ms = float(CombatData.hacks().get("auto", {}).get("reboot_hold_ms", 450.0))
		if still_down and not _hold_fired and held_ms >= hold_ms:
			_hold_fired = true
			player.queue_hack({"held_ms": held_ms}, player.clock.real_now_usec())
		elif not still_down and not _hold_fired:
			player.queue_hack({"held_ms": held_ms}, player.clock.real_now_usec())
	if not still_down:
		_down_usec = -1


# ---- starting a cast ----

## Called by ActionPlayer when a buffered hack press can start now. Returns {started, move, aim}: `move` is the cast move to
## play and `aim` the flat direction to face (zero = keep facing). Nothing starts if the rules say no (the refusal is
## announced and the press is used up).
func begin_cast(request: Dictionary) -> Dictionary:
	var none: Dictionary = {"started": false, "move": &"", "aim": Vector3.ZERO}
	if player == null or director == null or rules == null:
		return none
	_sync_mode()
	var battery_now: HackBattery = director.battery
	var knobs: Dictionary = _knobs()
	var aim: Vector3 = _aim_dir()
	var now_ms: float = _now_ms()
	var hack: StringName = StringName(str(request.get("hack", "")))       # a menu or shortcut named the hack: no picking
	if hack != &"" and not rules.has_hack(hack):
		return none
	if hack != &"":
		pass
	elif selector.mode == HackSelector.MODE_AUTO:
		var pick: Dictionary = selector.pick_auto(_situation(request, aim, knobs), knobs)
		hack = pick["hack"]
		if hack == &"" or bool(pick["fizz"]):
			var tried: StringName = hack if hack != &"" else &"zap_drone"
			_refuse(tried, {"reason": _why_not(tried, battery_now, knobs, aim, now_ms), "cost": rules.cost(tried, battery_now.charge(), knobs)})
			return none
	else:
		hack = selector.selected()
	var found: Dictionary = _find_target(hack, aim)
	var verdict: Dictionary = rules.check(hack, {
		"charge": battery_now.charge(), "capacity": battery_now.capacity(), "now_ms": now_ms,
		"locked": battery_now.is_locked(now_ms), "airborne": player.is_airborne(),
		"has_target": found.has("node"), "hijack_active": hijack() != null, "knobs": knobs})
	if not bool(verdict["ok"]):
		_refuse(hack, verdict)
		return none
	var price: float = float(verdict["cost"])
	var frac: float = battery_now.fill()
	if str(rules.hack(hack).get("cost", 0.0)) == HackRules.COST_ALL and not bool(knobs.get("free_cast", false)):
		battery_now.spend_all()
	elif price > 0.0:
		battery_now.spend(price)
	director.sync_battery()
	rules.start_cooldown(hack, now_ms, knobs)
	selector.note_used(hack)
	var target: Node3D = found.get("node", null)
	var heading: Vector3 = aim
	if target != null:
		var to_target: Vector3 = target.global_position - player.global_position
		to_target.y = 0.0
		if to_target.length() > 0.05:
			heading = to_target.normalized()
	_cast = {"hack": hack, "cost": price, "target": target, "hijackable": found.get("hijackable", null), "aim": heading,
			"charge_frac": frac, "move": rules.cast_move(hack), "bound": false, "fired": false, "swing_id": 0}
	if selector.mode == HackSelector.MODE_AUTO:
		director.hack_selected.emit(hack)
	director.hack_cast.emit({"hack": hack, "name": rules.display_name(hack), "cost": price, "target": _id_of(target),
			"position": player.global_position})
	_callout("cast", {"name": rules.display_name(hack), "left": str(int(roundf(battery_now.charge())))})
	return {"started": true, "move": _cast["move"], "aim": heading}


## ActionPlayer started the cast move; remember which swing it is.
func cast_move_started(swing_id: int) -> void:
	if _cast.is_empty():
		return
	_cast["bound"] = true
	_cast["swing_id"] = swing_id


## The cast move could not start (a missing move in the data): give the cost back as if nothing happened.
func cancel_cast() -> void:
	if _cast.is_empty():
		return
	_give_back()
	_cast = {}


func _give_back() -> void:
	if director != null and director.battery != null and not _cast.is_empty():
		director.battery.refund(float(_cast.get("cost", 0.0)))
		director.sync_battery()
	if rules != null and not _cast.is_empty():
		rules.clear_cooldown(StringName(str(_cast.get("hack", ""))))


func _tick_cast() -> void:
	if _cast.is_empty() or not bool(_cast["bound"]) or player == null:
		return
	var runner: MoveRunner = player.get_runner()
	if runner.current_move() != _cast["move"] or runner.swing_id() != int(_cast["swing_id"]):
		_cast = {}                  # the move ended, or was cut short (a hit on Red) before the effect: the cost stays spent
		return
	if not bool(_cast["fired"]) and runner.elapsed_ms() >= float(runner.data().get("impact_ms", 0.0)):
		_fire()


func _on_swing_started(move_id: StringName, _swing: Dictionary) -> void:
	if not _cast.is_empty() and bool(_cast["bound"]) and not bool(_cast["fired"]) and move_id == _cast["move"]:
		_fire()


# ---- the effects ----

func _fire() -> void:
	if _cast.is_empty() or bool(_cast["fired"]):
		return
	_cast["fired"] = true
	var hack: StringName = StringName(str(_cast["hack"]))
	match str(rules.effect(hack).get("type", "")):
		"projectile":
			_fire_zap(hack)
		"pulse":
			_fire_emp(hack)
		"hijack":
			_fire_overclock(hack)
		"heal":
			_fire_reboot(hack)


func _fire_zap(hack: StringName) -> void:
	var spec: Dictionary = rules.effect(hack)
	var knobs: Dictionary = _knobs()
	var origin: Vector3 = player.global_position + Vector3.UP * 0.8 + player.get_facing() * 0.55
	var dir: Vector3 = (_cast["aim"] as Vector3)
	var target: Node3D = _cast["target"] as Node3D
	if target != null and is_instance_valid(target):
		var aim_at: Vector3 = _lead_point(origin, target, float(spec.get("speed_mps", 20.0)))
		if aim_at.distance_to(origin) > 0.1:
			dir = (aim_at - origin).normalized()
	elif dir.length() < 0.01:
		dir = player.get_facing()
	var drone: ZapDrone = ZapDrone.new()
	drone.name = "ZapDrone"
	drone.source = player
	drone.director = director
	drone.rules = rules
	drone.hack_id = hack
	drone.direction = dir.normalized()
	drone.speed_mps = float(spec.get("speed_mps", 20.0))
	drone.max_m = float(spec.get("max_m", 18.0))
	var pierce: int = int(knobs.get("zap_pierce", 0))
	drone.pierce = pierce if pierce > 0 else int(spec.get("hits", 1))
	drone.rehit_ms = float(spec.get("rehit_ms", 250.0))
	drone.hit = (spec.get("hit", {}) as Dictionary).duplicate(true)
	drone.damage_scale = float(knobs.get("damage_scale", 1.0))
	_world().add_child(drone)
	drone.global_position = origin


func _fire_emp(hack: StringName) -> void:
	var spec: Dictionary = rules.effect(hack)
	var knobs: Dictionary = _knobs()
	var radius: float = float(knobs.get("emp_radius_m", 0.0))
	if radius <= 0.0:
		radius = float(spec.get("radius_m", 4.5))
	var centre: Vector3 = player.global_position
	var ring: EmpPulse = EmpPulse.new()
	ring.name = "EmpPulse"
	ring.radius_m = radius
	_world().add_child(ring)
	ring.global_position = centre
	var template: Dictionary = (spec.get("hit", {}) as Dictionary).duplicate(true)
	template["damage"] = int(roundf(float(template.get("damage", 0)) * float(knobs.get("damage_scale", 1.0))))
	var push: float = float(knobs.get("emp_knockback_m", -1.0))
	if push >= 0.0:
		template["knockback_m"] = push
	var stun_scale: float = float(knobs.get("emp_stun_scale", 1.0))
	for enemy: CombatActor in director.living_enemies():
		if not HackGeometry.in_ring(centre, enemy.global_position, enemy.radius_m, radius):
			continue
		var tags: Array = tags_of(enemy)
		var result: Dictionary = director.report_hack_hit(player, enemy, template, {"move_id": &"hack_emp", "origin": centre,
				"direction": _outward(centre, enemy.global_position), "position": enemy.anchor(&"center")})
		if result.get("outcome", HitResolver.OUTCOME_IGNORED) == HitResolver.OUTCOME_IGNORED:
			continue
		var stun: float = rules.stun_ms(hack, tags, stun_scale)
		if stun > 0.0 and not (tags.has("boss") and bool(spec.get("bosses_ignore_stun", true))) and enemy.has_method(&"apply_stun"):
			enemy.call(&"apply_stun", stun)
	if is_inside_tree():
		for node: Node in get_tree().get_nodes_in_group(ZapDrone.GROUP_HACK_TARGETS):
			var spot: Node3D = node as Node3D
			if spot != null and node.has_method(&"can_take") and bool(node.call(&"can_take", &"emp")) \
					and HackGeometry.flat_distance(centre, _aim_point(spot)) <= radius:
				node.call(&"take_hack", &"emp", {"source": player, "position": centre})


func _fire_overclock(hack: StringName) -> void:
	var spec: Dictionary = rules.effect(hack)
	var knobs: Dictionary = _knobs()
	var hijackable: Hijackable = _cast.get("hijackable", null) as Hijackable
	var duration: float = float(knobs.get("overclock_s", 0.0))
	if duration <= 0.0:
		duration = float(spec.get("duration_s", 10.0))
	if hijackable == null or not is_instance_valid(hijackable) or not hijackable.begin_hijack(player, duration):
		# the target died (or went out of reach of the link) during the reach: the cost comes back
		_give_back()
		_refuse(hack, {"reason": &"target_lost", "cost": float(_cast.get("cost", 0.0))})
		return
	_hijack = hijackable
	_link = OverclockLink.new()
	_link.name = "OverclockLink"
	_link.from_node = player
	_link.hijackable = hijackable
	_world().add_child(_link)


func _fire_reboot(hack: StringName) -> void:
	var spec: Dictionary = rules.effect(hack)
	var amount: int = rules.heal_amount(hack, player.hp_max, float(_cast.get("charge_frac", 1.0)), _knobs())
	if not player.dead and amount > 0:
		player.hp = mini(player.hp + amount, player.hp_max)
		director.hp_changed.emit(player.actor_id, player.hp, player.hp_max)
	player.grant_iframes(float(spec.get("iframes_ms", 600.0)))


func _clear_hijack() -> void:
	_hijack = null
	if _link != null and is_instance_valid(_link):
		_link.queue_free()
	_link = null


## Back to nothing: no cast, no cooldowns, any hijack let go. (The arena reset and a retry call it.)
func reset() -> void:
	_cast = {}
	_down_usec = -1
	_hold_fired = false
	if rules != null:
		rules.reset_cooldowns()
	if _hijack != null and is_instance_valid(_hijack) and _hijack.is_hijacked():
		_hijack.end_hijack()
	_clear_hijack()


# ---- targets ----

## The target a hack wants: {node, hijackable} (or {} for none). Zap: the hard lock, else the soft target (Zap with none
## flies straight). Overclock: the locked thing if it can be hijacked, else the best hijackable in range.
func _find_target(hack: StringName, aim: Vector3) -> Dictionary:
	match rules.target_kind(hack):
		&"enemy":
			var spec: Dictionary = rules.hack(hack).get("target", {}) as Dictionary
			var lock: LockOn = player.lock_on
			if bool(spec.get("use_lock", true)) and lock != null:
				var locked: Node3D = lock.get_target()
				if locked != null and is_instance_valid(locked) and locked.is_inside_tree():
					return {"node": locked}
			var soft: Node3D = null
			var reach: float = float(spec.get("soft_range_m", 14.0))
			var cone: float = float(spec.get("soft_cone_deg", 50.0))
			if lock != null:
				soft = lock.soft_target(aim, player.get_facing(), reach, cone)
			elif director != null:
				var entries: Array[Dictionary] = []
				var nodes: Array[Node3D] = []
				for enemy: CombatActor in director.living_enemies():
					entries.append({"pos": enemy.global_position})
					nodes.append(enemy)
				var index: int = LockOnMath.magnet_pick(entries, player.global_position, aim if aim.length() > 0.01 else player.get_facing(), reach, cone)
				soft = nodes[index] if index >= 0 else null
			return {"node": soft} if soft != null else {}
		&"hijackable":
			return _find_hijackable(hack, aim)
	return {}


func _find_hijackable(hack: StringName, aim: Vector3) -> Dictionary:
	var spec: Dictionary = rules.hack(hack).get("target", {}) as Dictionary
	var reach: float = float(spec.get("soft_range_m", 12.0))
	var cone: float = float(spec.get("soft_cone_deg", 60.0))
	var lock: LockOn = player.lock_on
	if bool(spec.get("use_lock", true)) and lock != null:
		var locked: Node3D = lock.get_target()
		var held: Hijackable = hijackable_of(locked)
		if held != null and held.can_hijack(player.team) and HackGeometry.flat_distance(player.global_position, locked.global_position) <= reach * 1.5:
			return {"node": locked, "hijackable": held}
	var entries: Array[Dictionary] = []
	var found: Array[Hijackable] = []
	for candidate: Hijackable in _hijackables():
		var host: Node3D = candidate.get_parent() as Node3D
		if host == null or not candidate.can_hijack(player.team):
			continue
		entries.append({"pos": host.global_position})
		found.append(candidate)
	var direction: Vector3 = aim if aim.length() > 0.01 else player.get_facing()
	var index: int = LockOnMath.best(entries, direction, player.global_position, {"max_range_m": reach, "max_angle_deg": cone})
	if index < 0:
		return {}
	return {"node": found[index].get_parent(), "hijackable": found[index]}


func _hijackables() -> Array[Hijackable]:
	var out: Array[Hijackable] = []
	if not is_inside_tree():
		return out
	for node: Node in get_tree().get_nodes_in_group(Hijackable.GROUP):
		var hijackable: Hijackable = node as Hijackable
		if hijackable != null and is_instance_valid(hijackable):
			out.append(hijackable)
	return out


## What the automatic picker reads (hacks_design.md, Option C).
func _situation(request: Dictionary, aim: Vector3, knobs: Dictionary) -> Dictionary:
	var pos: Vector3 = player.global_position
	var dists: Array = []
	for enemy: CombatActor in director.living_enemies():
		dists.append(HackGeometry.flat_distance(pos, enemy.global_position))
	var lock_info: Dictionary = {"exists": false, "tags": [], "hijackable": false}
	var locked: Node3D = player.lock_on.get_target() if player.lock_on != null else null
	if locked != null:
		var held: Hijackable = hijackable_of(locked)
		lock_info = {"exists": true, "tags": tags_of(locked), "hijackable": held != null and held.can_hijack(player.team)}
	var cone: Array = []
	for candidate: Hijackable in _hijackables():
		var host: Node3D = candidate.get_parent() as Node3D
		if host == null or not candidate.can_hijack(player.team):
			continue
		cone.append({"dist": HackGeometry.flat_distance(pos, host.global_position),
				"angle_deg": HackGeometry.aim_angle_deg(pos, host.global_position, aim if aim.length() > 0.01 else player.get_facing()),
				"tags": tags_of(host)})
	var battery_now: HackBattery = director.battery
	var affordable: Dictionary = {}
	for id: StringName in rules.order():
		affordable[String(id)] = rules.affordable(id, battery_now.charge(), battery_now.capacity(), knobs)
	if hijack() != null:
		affordable["overclock"] = false          # one at a time: the picker moves on to the next rule
	return {"held_ms": float(request.get("held_ms", 0.0)), "enemy_dists": dists, "lock": lock_info, "cone": cone,
			"affordable": affordable}


## The reason a hack cannot be cast right now, for the refusal words. (Used when the automatic picker fizzles.)
func _why_not(hack: StringName, battery_now: HackBattery, knobs: Dictionary, aim: Vector3, now_ms: float) -> StringName:
	var found: Dictionary = _find_target(hack, aim)
	var verdict: Dictionary = rules.check(hack, {
		"charge": battery_now.charge(), "capacity": battery_now.capacity(), "now_ms": now_ms,
		"locked": battery_now.is_locked(now_ms), "airborne": player.is_airborne(),
		"has_target": found.has("node"), "hijack_active": hijack() != null, "knobs": knobs})
	return StringName(str(verdict["reason"])) if verdict["reason"] != HackRules.OK else &"battery"


# ---- refusals and words ----

func _refuse(hack: StringName, verdict: Dictionary) -> void:
	var reason: StringName = StringName(str(verdict.get("reason", "unknown")))
	var battery_now: HackBattery = director.battery if director != null else null
	var info: Dictionary = {"hack": hack, "name": rules.display_name(hack), "reason": reason,
			"cost": float(verdict.get("cost", 0.0)), "charge": battery_now.charge() if battery_now != null else 0.0}
	if director != null:
		director.hack_refused.emit(info)
	var now_usec: int = player.clock.real_now_usec() if player != null else 0
	if now_usec - int(_last_refusal.get(reason, -REFUSAL_GAP_USEC * 4)) < REFUSAL_GAP_USEC:
		return                      # a mashed button does not stack the same call-out
	_last_refusal[reason] = now_usec
	var refused: Dictionary = _text.get("refused", {}) as Dictionary
	_say(str(refused.get(String(reason), "")), {"name": rules.display_name(hack), "cost": str(int(ceilf(float(info["cost"])))),
			"have": str(int(floorf(float(info["charge"]))))})


func _callout(key: String, vars: Dictionary) -> void:
	_say(str(_text.get(key, "")), vars)


func _say(line: String, vars: Dictionary) -> void:
	if line.is_empty() or player == null:
		return
	for key: Variant in vars.keys():
		line = line.replace("{%s}" % str(key), str(vars[key]))
	player.hack_pressed.emit({"text": line, "callout_ms": float(_text.get("callout_ms", 1200.0))})


func _cost_words(id: StringName) -> String:
	if str(rules.hack(id).get("cost", 0.0)) == HackRules.COST_ALL:
		return "all"
	return str(int(roundf(rules.cost(id, 0.0, _knobs()))))


# ---- small helpers ----

func _sync_mode() -> void:
	selector.set_mode_from_knob(str(_knobs().get("pick_mode", "pick_then_fire")))


func _knobs() -> Dictionary:
	return HackRules.knobs_from(_feel())


func _feel() -> FeelKnobs:
	if director != null and director.feel != null:
		return director.feel
	return player.knobs if player != null else null


func _now_ms() -> float:
	return player.clock.now_ms() if player != null else 0.0


func _world() -> Node:
	return player.get_parent() if player != null and player.get_parent() != null else get_tree().current_scene


## The way she is pushing the stick, else the way she faces (flat, unit).
func _aim_dir() -> Vector3:
	var stick: Vector3 = player.get_move_direction()
	stick.y = 0.0
	if stick.length() > 0.2:
		return stick.normalized()
	var facing: Vector3 = player.get_facing()
	facing.y = 0.0
	return facing.normalized() if facing.length() > 0.01 else Vector3.FORWARD


static func _outward(centre: Vector3, at: Vector3) -> Vector3:
	var flat: Vector3 = at - centre
	flat.y = 0.0
	return flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD


## Where to throw so a straight drone meets a target that is walking or circling: its aim point pushed along its own
## (flat) velocity by the flight time. Two passes are plenty at drone speeds.
static func _lead_point(origin: Vector3, target: Node3D, speed_mps: float) -> Vector3:
	var point: Vector3 = _aim_point(target)
	var body: CharacterBody3D = target as CharacterBody3D
	if body == null or speed_mps <= 0.1:
		return point
	var flat: Vector3 = Vector3(body.velocity.x, 0.0, body.velocity.z)
	var lead: Vector3 = point
	for pass_number: int in range(2):
		lead = point + flat * (origin.distance_to(lead) / speed_mps)
	return lead


static func _aim_point(node: Node3D) -> Vector3:
	if node.has_method(&"aim_point"):
		return node.call(&"aim_point")
	if node is CombatActor:
		return (node as CombatActor).anchor(&"center")
	return node.global_position + Vector3.UP * 0.8


static func _id_of(node: Node) -> StringName:
	if node == null:
		return &""
	if "actor_id" in node:
		return StringName(str(node.get("actor_id")))
	return StringName(node.name)


## The `tags` an enemy (or anything) carries: drone, turret, robot, relay, boss. Empty if it has none.
static func tags_of(thing: Object) -> Array:
	var out: Array = []
	if thing == null or not "tags" in thing:
		return out
	var raw: Variant = thing.get("tags")
	if raw is Array or raw is PackedStringArray:
		for tag: Variant in raw:
			out.append(str(tag))
	return out


## The Hijackable component on `thing`, or null.
static func hijackable_of(thing: Node) -> Hijackable:
	if thing == null or not is_instance_valid(thing):
		return null
	for child: Node in thing.get_children():
		if child is Hijackable:
			return child as Hijackable
	return null
