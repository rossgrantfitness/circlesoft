class_name DashCharges
extends RefCounted
## Red's dash charges (Ross 2026-10-09, "Dash on charges"; docs/decisions.md). Pure maths, no nodes.
##
## She holds up to `max_count` charges. Each dash spends one. Spent charges come back ONE AT A TIME: while any
## charge is missing a single refill timer runs, and every `recharge_s` it hands back one charge. The timer is
## never restarted by a dash (spending another charge mid-refill does not cost the progress already made).
## Between two chained dashes there is a short gap (`start_gap`) during which no new dash may start.
##
## Time is the owner's combat time, so hit-stop freezes the refill like everything else of hers.
## The numbers come in from the feel knobs (dash_charges, dash_recharge_s, dash_chain_gap_s) every call, so the
## F12 panel works live; this class stores none of them except what it needs to draw a fraction.

const MIN_RECHARGE_S: float = 0.01

var count: int = 0
var max_count: int = 0
## Seconds the refill timer has run towards the next charge (0 while full).
var refill_elapsed_s: float = 0.0
## Seconds left of the pause between two chained dashes.
var gap_left_s: float = 0.0

var _recharge_s: float = 2.0


static func create(max_charges: int) -> DashCharges:
	var charges: DashCharges = DashCharges.new()
	charges.max_count = maxi(max_charges, 0)
	charges.count = charges.max_count
	return charges


## Follows the max knob. Raising it adds the new slots as FULL ones (a tuning change must not look like a spend);
## lowering it trims the count to the new max.
func sync_max(new_max: int) -> void:
	var wanted: int = maxi(new_max, 0)
	if wanted == max_count:
		return
	if wanted > max_count:
		count += wanted - max_count
	max_count = wanted
	count = mini(count, max_count)
	if count >= max_count:
		refill_elapsed_s = 0.0


## Moves the clocks on: the gap counts down; while a charge is missing the refill timer runs and pays out
## charges one at a time (the leftover carries, so a long frame loses nothing).
func tick(delta_s: float, recharge_s: float) -> void:
	_recharge_s = maxf(recharge_s, MIN_RECHARGE_S)
	if delta_s <= 0.0:
		return
	gap_left_s = maxf(gap_left_s - delta_s, 0.0)
	if count >= max_count:
		refill_elapsed_s = 0.0
		return
	refill_elapsed_s += delta_s
	while refill_elapsed_s >= _recharge_s and count < max_count:
		refill_elapsed_s -= _recharge_s
		count += 1
	if count >= max_count:
		refill_elapsed_s = 0.0


## Is there a charge to spend (ignores the chain gap)?
func has_charge() -> bool:
	return count > 0


## Can a dash start now: a charge and no chain gap running.
func is_ready() -> bool:
	return count > 0 and gap_left_s <= 0.0


## Spends one charge. False (nothing changes) with none left. The refill timer is left alone.
func spend() -> bool:
	if count <= 0:
		return false
	count -= 1
	return true


## A dash just ended: no new one for `gap_s`.
func start_gap(gap_s: float) -> void:
	gap_left_s = maxf(gap_s, 0.0)


## Back to full, nothing running.
func refill_all() -> void:
	count = max_count
	refill_elapsed_s = 0.0
	gap_left_s = 0.0


## How far the charge that is coming back has got, 0..1 (0 when full).
func refill_fraction() -> float:
	if count >= max_count:
		return 0.0
	return clampf(refill_elapsed_s / _recharge_s, 0.0, 1.0)


## Seconds until the next charge arrives (0 when full).
func seconds_to_next() -> float:
	if count >= max_count:
		return 0.0
	return maxf(_recharge_s - refill_elapsed_s, 0.0)


## What the HUD draws: {count, max, fraction (of the charge being refilled), gap_left_s}.
func snapshot() -> Dictionary:
	return {"count": count, "max": max_count, "fraction": refill_fraction(), "gap_left_s": gap_left_s}
