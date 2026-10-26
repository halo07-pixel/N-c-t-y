class_name ScriptedInput
extends InputSource
## Input driven from code. Used by automated tests and the screenshot tool.

var held_move: Vector2 = Vector2.ZERO
var down_held: bool = false
var held_charge: bool = false

var _pending_up: bool = false
var _pending_down: bool = false
var _pending_attack: bool = false
var _pending_special: bool = false
var _pending_charge: bool = false


func tap_up() -> void:
	_pending_up = true


func tap_down() -> void:
	_pending_down = true


func tap_attack() -> void:
	_pending_attack = true


func tap_special() -> void:
	_pending_special = true


## One press of the charge key (transform / ultimate / start charging).
func tap_charge() -> void:
	_pending_charge = true


func get_frame() -> InputFrame:
	var frame := InputFrame.new()
	frame.move = held_move
	frame.up_just_pressed = _pending_up
	frame.down_just_pressed = _pending_down
	frame.down_held = down_held or _pending_down
	frame.attack_just_pressed = _pending_attack
	frame.special_just_pressed = _pending_special
	frame.charge_just_pressed = _pending_charge
	frame.charge_held = held_charge or _pending_charge
	_pending_up = false
	_pending_down = false
	_pending_attack = false
	_pending_special = false
	_pending_charge = false
	return frame
