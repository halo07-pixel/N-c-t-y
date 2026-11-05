class_name DummyInput
extends InputSource
## What the training dummy does when it is not the CPU: nothing, hold its guard, or jump on and on.

const GUARD_TAP_FRAMES := 40
const JUMP_FRAMES := 90

var mode: StringName = &"stand"
var _frames: int = 0


func get_frame() -> InputFrame:
	var frame := InputFrame.new()
	_frames += 1
	match mode:
		&"guard":
			frame.guard_held = true
			frame.guard_just_pressed = _frames % GUARD_TAP_FRAMES == 1
		&"jump":
			frame.up_just_pressed = _frames % JUMP_FRAMES == 0
	return frame
