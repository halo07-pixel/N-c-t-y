class_name FighterState
extends Node
## One thing a fighter can be doing (Idle, Run, Jump, Fall, ...).
## The state machine hands each state its fighter once, at setup.

var fighter: Fighter


func enter(_previous: StringName) -> void:
	pass


func exit() -> void:
	pass


## Runs every physics tick. Return the name of the next state, or &"" to stay.
func physics_update(_delta: float) -> StringName:
	return &""
