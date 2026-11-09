class_name CpuReader
extends RefCounted
## What the CPU has noticed about its opponent over the last few seconds: do they hide behind the
## guard, jump a lot, keep rushing in? It counts the times the opponent started each of those and
## says which habit stands out (if any), plus how the CPU should lean against it.
## Pure: AIInput feeds it the opponent's state every frame.

const WINDOW_FRAMES := 600 # 10 s of memory
const MIN_EVENTS := 3
const DOMINANT_SHARE := 0.45

const GUARD := &"guard"
const JUMP := &"jump"
const RUSH := &"rush"
const NONE := &"none"

var _events: Array[Vector2i] = [] # (frame, kind index)
var _frame: int = 0
var _last_state: StringName = &""
var _kinds: Array[StringName] = [GUARD, JUMP, RUSH]


## Call once per frame with the opponent's state name and whether they stand on the floor.
func observe(state: StringName, on_floor: bool) -> void:
	_frame += 1
	if state != _last_state:
		match state:
			&"Guard":
				_events.append(Vector2i(_frame, 0))
			&"Jump":
				_events.append(Vector2i(_frame, 1))
			&"Dash", &"Attack":
				_events.append(Vector2i(_frame, 2))
		_last_state = state
	while not _events.is_empty() and _events[0].x < _frame - WINDOW_FRAMES:
		_events.pop_front()


func count_of(kind: StringName) -> int:
	var index := _kinds.find(kind)
	var total := 0
	for event in _events:
		if event.y == index:
			total += 1
	return total


## The habit that makes up most of what the opponent has done, or NONE.
func dominant() -> StringName:
	if _events.size() < MIN_EVENTS:
		return NONE
	var best := NONE
	var best_count := 0
	for kind in _kinds:
		var count := count_of(kind)
		if count > best_count:
			best_count = count
			best = kind
	if float(best_count) / float(_events.size()) < DOMINANT_SHARE:
		return NONE
	return best


## How to lean against the habit: `mixup` (chance to grab instead of poking at a guard),
## `anti_air` (chance to hit upward at a jumper), `defend` (extra chance to guard or counter).
func advice() -> Dictionary:
	var habit := dominant()
	return {
		"mixup": 0.35 if habit == GUARD else 0.0,
		"anti_air": 0.55 if habit == JUMP else 0.0,
		"defend": 0.15 if habit == RUSH else 0.0,
		"poke_scale": 0.6 if habit == GUARD else 1.0,
	}
