class_name ScriptedInput
extends InputSource
## Input driven from code. Used by automated tests now and by the CPU later.

var held_move: Vector2 = Vector2.ZERO
var down_held: bool = false

var _pending_up: bool = false
var _pending_down: bool = false


func tap_up() -> void:
	_pending_up = true


func tap_down() -> void:
	_pending_down = true


func get_frame() -> InputFrame:
	var frame := InputFrame.new()
	frame.move = held_move
	frame.up_just_pressed = _pending_up
	frame.down_just_pressed = _pending_down
	frame.down_held = down_held or _pending_down
	_pending_up = false
	_pending_down = false
	return frame
