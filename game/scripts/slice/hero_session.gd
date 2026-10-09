class_name HeroSession
extends RefCounted
## What Red carries from room to room in the slice (docs/slice/slice_tech_plan.md 2.3): her health, the hack battery,
## the sword in her hand and her form (red / small / huge). Pure data: a room writes one when she leaves (or when a
## door is used) and reads it when she walks in; the room-entrance snapshot a knock-out returns to is one of these.
## It lives in GameState.slice_run["session"] as a plain dictionary (to_dict / from_dict).
##
## `battery` -1 means none recorded (a new run: the battery stays as the director starts it). `hp` 0 or less means "full".

const KEY_HP: String = "hp"
const KEY_HP_MAX: String = "hp_max"
const KEY_BATTERY: String = "battery"
const KEY_SWORD: String = "sword"
const KEY_FORM: String = "form"
const FORM_RED: StringName = &"red"
const FULL: float = -1.0

var hp: int = 0
var hp_max: int = 0
var battery: float = FULL
var sword: StringName = &""
var form: StringName = FORM_RED


static func from_dict(data: Dictionary) -> HeroSession:
	var session: HeroSession = HeroSession.new()
	session.hp = int(data.get(KEY_HP, 0))
	session.hp_max = int(data.get(KEY_HP_MAX, 0))
	session.battery = float(data.get(KEY_BATTERY, FULL))
	session.sword = StringName(str(data.get(KEY_SWORD, "")))
	var wanted: String = str(data.get(KEY_FORM, "red"))
	session.form = StringName(wanted) if not wanted.is_empty() else FORM_RED
	return session


func to_dict() -> Dictionary:
	return {KEY_HP: hp, KEY_HP_MAX: hp_max, KEY_BATTERY: battery, KEY_SWORD: String(sword), KEY_FORM: String(form)}


func duplicate_session() -> HeroSession:
	return HeroSession.from_dict(to_dict())


## True for a session that has never been written (a new run).
func is_blank() -> bool:
	return hp <= 0 and battery == FULL and sword == &"" and form == FORM_RED


## The health to start a room with when her maximum there is `max_hp`: what she had, kept between 1 and the
## maximum; full when the session has none. A knocked-out Red (0) never carries 0 into a room.
func health_for(max_hp: int) -> int:
	if hp <= 0 or max_hp <= 0:
		return max_hp
	return clampi(hp, 1, max_hp)


func has_battery() -> bool:
	return battery >= 0.0


## The battery charge to start with out of `capacity`: what she had, or full when none is recorded.
func battery_for(capacity: float) -> float:
	if battery < 0.0:
		return capacity
	return clampf(battery, 0.0, capacity)


## The form a room starts her in: the room's own `form` when it names one other than red (a room that begins inside the
## loader), else the form she carries.
func form_for_room(room_form: String) -> StringName:
	if not room_form.is_empty() and room_form != String(FORM_RED):
		return StringName(room_form)
	return form
