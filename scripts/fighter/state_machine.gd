class_name FighterStateMachine
extends Node
## Holds the FighterState children and switches between them by name.

signal state_changed(previous: StringName, current: StringName)

var current: FighterState
var current_name: StringName = &""

var _states: Dictionary = {}


func setup(owner_fighter: Fighter, initial: StringName) -> void:
	for child in get_children():
		if child is FighterState:
			child.fighter = owner_fighter
			_states[StringName(child.name)] = child
	transition_to(initial)


func physics_update(delta: float) -> void:
	if current == null:
		return
	var next: StringName = current.physics_update(delta)
	if next != &"":
		transition_to(next)


func transition_to(state_name: StringName) -> void:
	assert(_states.has(state_name), "Unknown fighter state: %s" % state_name)
	var previous := current_name
	if current != null:
		current.exit()
	current = _states[state_name]
	current_name = state_name
	current.enter(previous)
	state_changed.emit(previous, state_name)
