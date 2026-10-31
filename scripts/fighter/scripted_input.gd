class_name ScriptedInput
extends InputSource
## Input driven from code. Used by automated tests and the screenshot tool.

var held_move: Vector2 = Vector2.ZERO
var down_held: bool = false
var held_charge: bool = false
var held_guard: bool = false
var held_special: bool = false
var held_special2: bool = false

var _pending_up: bool = false
var _pending_down: bool = false
var _pending_attack: bool = false
var _pending_special: bool = false
var _pending_special2: bool = false
var _pending_charge: bool = false
var _pending_guard: bool = false


func tap_up() -> void:
	_pending_up = true


func tap_down() -> void:
	_pending_down = true


func tap_attack() -> void:
	_pending_attack = true


func tap_special() -> void:
	_pending_special = true


func tap_special2() -> void:
	_pending_special2 = true


## One press of the charge key (transform / ultimate / start charging).
func tap_charge() -> void:
	_pending_charge = true


## One press of the guard key (also holds it for this frame).
func tap_guard() -> void:
	_pending_guard = true


func get_frame() -> InputFrame:
	var frame := InputFrame.new()
	frame.move = held_move
	frame.up_just_pressed = _pending_up
	frame.down_just_pressed = _pending_down
	frame.down_held = down_held or _pending_down
	frame.attack_just_pressed = _pending_attack
	frame.special_just_pressed = _pending_special
	frame.special2_just_pressed = _pending_special2
	frame.special2_held = held_special2 or _pending_special2
	frame.charge_just_pressed = _pending_charge
	frame.charge_held = held_charge or _pending_charge
	frame.special_held = held_special or _pending_special
	frame.guard_just_pressed = _pending_guard
	frame.guard_held = held_guard or _pending_guard
	_pending_guard = false
	_pending_up = false
	_pending_down = false
	_pending_attack = false
	_pending_special = false
	_pending_special2 = false
	_pending_charge = false
	return frame
