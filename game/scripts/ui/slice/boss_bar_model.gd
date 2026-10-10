class_name BossBarModel
extends RefCounted
## What the boss bar shows, with no drawing: the boss's name, its health (with the trailing chip), the
## phases as pips (the current one lit), and a flash when the phase changes. A fight may have phases that
## are not "boss health" (a transition); the bar only knows the ones it is told about:
##   show_bar({name, hp, hp_max, phases: [{id, name}, ...], phase: 0})
##   set_hp(hp, hp_max) / set_phase(index, name) / hide_bar()

var shown: bool = false
var boss_name: String = ""
var hp: float = 0.0
var hp_max: float = 1.0
var phases: Array[Dictionary] = []
var phase_index: int = 0
## Parts still standing out of the total (the Hushmaster's leg pairs, the Heap's armour plates): small pips right of the bar.
## Set by boss_pips_changed(standing, total); total 0 = none shown.
var pips_standing: int = 0
var pips_total: int = 0
## The pips that just dropped flash for a moment: the first dropped index and how many (B12). Pips fall from the right.
var pips_flash_from: int = 0
var pips_flash_count: int = 0
## Eased fill and the trailing chip, in 0..1.
var fill_shown: float = 0.0
var chip: float = 0.0
## 0..1 slide-in (and 1..0 fade-out).
var presence: float = 0.0

var _chip_wait_s: float = 0.0
var _flash_left_s: float = 0.0
var _pips_flash_left_s: float = 0.0
var _hiding: bool = false


func set_pips(standing: int, total: int) -> void:
	var before_total: int = pips_total
	var before_standing: int = pips_standing
	pips_total = maxi(total, 0)
	pips_standing = clampi(standing, 0, pips_total)
	# A pip going out is the fight's real progress: it flashes. A new row of pips (first count, a new phase) never does.
	if before_total == pips_total and pips_total > 0 and pips_standing < before_standing:
		pips_flash_from = pips_standing
		pips_flash_count = before_standing - pips_standing
		_pips_flash_left_s = SliceUiData.num("boss_bar.part_flash_s", 0.8)
	elif before_total != pips_total or pips_standing > before_standing:
		_pips_flash_left_s = 0.0
		pips_flash_count = 0


## 0..1: how bright the "a pip just went out" flash is right now.
func pips_flash() -> float:
	var total: float = SliceUiData.num("boss_bar.part_flash_s", 0.8)
	return clampf(_pips_flash_left_s / total, 0.0, 1.0) if total > 0.0 else 0.0


## True while pip `index` is one that just dropped and the flash is on (it blinks in steps, never fades).
func pip_flashing(index: int) -> bool:
	if _pips_flash_left_s <= 0.0 or index < pips_flash_from or index >= pips_flash_from + pips_flash_count:
		return false
	var step_s: float = maxf(0.02, SliceUiData.num("boss_bar.part_flash_step_s", 0.08))
	var total: float = SliceUiData.num("boss_bar.part_flash_s", 0.8)
	return int((total - _pips_flash_left_s) / step_s) % 2 == 0


## The id of the phase being shown ("rig", "mech"), or "".
func phase_id() -> String:
	if phase_index >= 0 and phase_index < phases.size():
		return str(phases[phase_index].get("id", ""))
	return ""


## What the pips count in this phase ("Legs", "Plates"), from data/text/slice_ui.json boss.pips_label.
func pips_label() -> String:
	var words: String = SliceUiData.text("boss.pips_label.%s" % phase_id())
	return words if not words.is_empty() else SliceUiData.text("boss.pips_label.default")


## The one-line hint under the pips while none has dropped yet ("Zap the leg relays"); "" afterwards.
func pips_hint() -> String:
	if pips_total <= 0 or pips_standing < pips_total:
		return ""
	var words: String = SliceUiData.text("boss.pips_hint.%s" % phase_id())
	return words if not words.is_empty() else SliceUiData.text("boss.pips_hint.default")


## "3/4".
func pips_count_text() -> String:
	return SliceUiData.fmt("boss.pips_count", {"standing": pips_standing, "total": pips_total})


func show_bar(info: Dictionary) -> void:
	pips_standing = 0
	pips_total = 0
	pips_flash_count = 0
	_pips_flash_left_s = 0.0
	shown = true
	_hiding = false
	boss_name = str(info.get("name", ""))
	hp_max = maxf(1.0, float(info.get("hp_max", 1.0)))
	hp = clampf(float(info.get("hp", hp_max)), 0.0, hp_max)
	phases.clear()
	for phase: Variant in info.get("phases", []):
		if phase is Dictionary:
			phases.append((phase as Dictionary).duplicate())
	phase_index = clampi(int(info.get("phase", 0)), 0, maxi(0, phases.size() - 1))
	fill_shown = fill()
	chip = fill_shown
	_chip_wait_s = 0.0
	_flash_left_s = 0.0


## Starts the fade-out (the bar leaves the screen when the fight or the phase's boss is over).
func hide_bar() -> void:
	_hiding = true


func is_visible() -> bool:
	return shown and presence > 0.0


func set_hp(new_hp: float, new_max: float = -1.0) -> void:
	if new_max > 0.0:
		hp_max = new_max
	var before: float = hp
	hp = clampf(new_hp, 0.0, hp_max)
	if hp < before:
		chip = maxf(chip, before / hp_max)
		_chip_wait_s = SliceUiData.num("boss_bar.chip_delay_s", 0.4)


func fill() -> float:
	return hp / hp_max


func set_phase(index: int, new_name: String = "") -> void:
	var clamped: int = clampi(index, 0, maxi(0, phases.size() - 1))
	if clamped != phase_index:
		_flash_left_s = SliceUiData.num("boss_bar.flash_s", 0.45)
	phase_index = clamped
	if not new_name.is_empty() and phase_index < phases.size():
		phases[phase_index]["name"] = new_name


func phase_count() -> int:
	return phases.size()


func phase_name() -> String:
	if phase_index >= 0 and phase_index < phases.size():
		return str(phases[phase_index].get("name", ""))
	return ""


## 0..1: how bright the phase-change flash is right now.
func flash() -> float:
	var total: float = SliceUiData.num("boss_bar.flash_s", 0.45)
	return clampf(_flash_left_s / total, 0.0, 1.0) if total > 0.0 else 0.0


func tick(delta: float) -> void:
	if not shown:
		return
	var slide: float = SliceUiData.num("boss_bar.slide_s", 0.25)
	var fade: float = SliceUiData.num("boss_bar.fade_s", 0.4)
	if _hiding:
		presence = maxf(0.0, presence - delta / maxf(0.01, fade))
		if presence <= 0.0:
			shown = false
			_hiding = false
		return
	presence = minf(1.0, presence + delta / maxf(0.01, slide))
	fill_shown = move_toward(fill_shown, fill(), SliceUiData.num("boss_bar.hp_per_s", 1.6) * delta)
	if _chip_wait_s > 0.0:
		_chip_wait_s -= delta
	elif chip > fill_shown:
		chip = maxf(fill_shown, chip - SliceUiData.num("boss_bar.chip_per_s", 0.5) * delta)
	_flash_left_s = maxf(0.0, _flash_left_s - delta)
	_pips_flash_left_s = maxf(0.0, _pips_flash_left_s - delta)
