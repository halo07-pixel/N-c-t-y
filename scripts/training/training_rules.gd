class_name TrainingRules
extends RefCounted
## The rules of Training mode, with no drawing and no nodes: it counts the player's combo on the
## dummy, says when the dummy's damage should be wiped, and cycles what the dummy does.
## The scene feeds it hits and ticks and listens to its signals.

signal combo_changed(hits: int, damage: float)
signal combo_ended(hits: int, damage: float)
signal percent_reset_due

## Frames without a hit that end a combo.
const COMBO_END_FRAMES := 75
## Frames without a hit after which the dummy's percent is wiped, so it can never be KO'd.
const PERCENT_RESET_FRAMES := 180
const MODES: Array[StringName] = [&"stand", &"guard", &"jump", &"cpu1", &"cpu2", &"cpu3"]
const MODE_LABELS := {
	&"stand": "STAND", &"guard": "GUARD", &"jump": "JUMP", &"cpu1": "CPU 1", &"cpu2": "CPU 2", &"cpu3": "CPU 3",
}

var mode_index: int = 0
## The combo in progress.
var hits: int = 0
var damage: float = 0.0
## The last finished combo and the best hit count of this session.
var last_hits: int = 0
var last_damage: float = 0.0
var best_hits: int = 0
## Keep the player's Reiatsu full and every skill ready (toggled with a key).
var infinite_resources: bool = true

var _since_hit: int = 0


func mode() -> StringName:
	return MODES[mode_index]


func mode_label() -> String:
	return MODE_LABELS[mode()]


## 1 to 3 when the dummy is steered by the CPU, otherwise 0.
func cpu_level() -> int:
	match mode():
		&"cpu1":
			return 1
		&"cpu2":
			return 2
		&"cpu3":
			return 3
	return 0


func next_mode() -> StringName:
	mode_index = (mode_index + 1) % MODES.size()
	return mode()


func toggle_resources() -> void:
	infinite_resources = not infinite_resources


## A hit landed somewhere; only the player's (1) hits on the dummy (2) count.
func on_hit(attacker_id: int, victim_id: int, amount: float) -> void:
	if attacker_id != 1 or victim_id != 2:
		return
	hits += 1
	damage += amount
	_since_hit = 0
	combo_changed.emit(hits, damage)


## One physics tick. `dummy_percent` is the dummy's current damage.
func tick(dummy_percent: float) -> void:
	_since_hit += 1
	if hits > 0 and _since_hit >= COMBO_END_FRAMES:
		last_hits = hits
		last_damage = damage
		best_hits = maxi(best_hits, hits)
		hits = 0
		damage = 0.0
		combo_ended.emit(last_hits, last_damage)
	if dummy_percent > 0.0 and _since_hit >= PERCENT_RESET_FRAMES:
		_since_hit = 0
		percent_reset_due.emit()


## Forgets the combo in progress (positions were reset).
func reset() -> void:
	hits = 0
	damage = 0.0
	_since_hit = 0
	combo_changed.emit(0, 0.0)
