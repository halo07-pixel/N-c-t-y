class_name DashTap
extends RefCounted
## Finds the double tap of a direction key: press, let go, press the same direction again within
## GuardRules.DASH_DOUBLE_TAP_FRAMES. Feed it the horizontal input once per tick. Only the keyboard
## uses it, so a CPU that walks back and forth never dashes by accident.

const PRESS_THRESHOLD := 0.5

var _held: int = 0
var _tap_direction: int = 0
var _frames_since_tap: int = 0
var _released: bool = false


## Returns -1 or 1 on the tick a double tap completes, otherwise 0.
func update(horizontal: float) -> int:
	_frames_since_tap += 1
	var direction := 0 if absf(horizontal) < PRESS_THRESHOLD else int(signf(horizontal))
	var dash := 0
	if direction == 0:
		_released = true
	elif direction != _held:
		var in_time := _frames_since_tap <= GuardRules.DASH_DOUBLE_TAP_FRAMES
		if direction == _tap_direction and _released and in_time:
			dash = direction
			_tap_direction = 0
		else:
			_tap_direction = direction
			_frames_since_tap = 0
			_released = false
	_held = direction
	return dash
