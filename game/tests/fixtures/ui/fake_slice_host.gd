class_name FakeSliceHost
extends FakeCombatSandbox
## A combat host as the slice HUD sees an ActionRoom: the sandbox fake (the REAL CombatDirector, whose battery_changed,
## hack_locked, hack_selected, hack_cast, hack_refused and hijack_changed signals are the real ones) plus the room's
## knock-out signals, the continue call and a boss fight stand-in.

class StubBossFight extends RefCounted:
	signal boss_bar_shown(info: Dictionary)
	signal boss_hp_changed(hp: float, hp_max: float)
	signal boss_phase_changed(index: int, phase_name: String)
	signal boss_bar_hidden()
	signal boss_pips_changed(standing: int, total: int)

signal knocked_out_rule(rule: String)
signal continue_started(room: String, spawn: String)

var boss: StubBossFight = StubBossFight.new()
var continue_calls: int = 0


func continue_after_knockout() -> bool:
	continue_calls += 1
	return true


func get_boss_fight() -> StubBossFight:
	return boss
