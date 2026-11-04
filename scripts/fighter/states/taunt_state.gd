class_name TauntState
extends FighterState
## A taunt: stand and show off for a moment. No damage, no gauge. Ends by itself, or at once when
## the player attacks, guards, jumps or moves (a hit ends it too, like any state).

const TAUNT_FRAMES := 72

var _frames: int = 0


func enter(_previous: StringName) -> void:
	_frames = 0


func physics_update(delta: float) -> StringName:
	var stats := fighter.data
	fighter.apply_horizontal(delta, 0.0, stats.run_speed, stats.ground_accel, stats.ground_friction)
	fighter.apply_gravity(delta)
	_frames += 1
	if not fighter.is_on_floor():
		return &"Fall"
	var input := fighter.input
	if _frames >= TAUNT_FRAMES or input.attack_just_pressed or input.special_just_pressed \
			or input.guard_just_pressed or input.up_just_pressed or input.charge_just_pressed \
			or absf(input.move.x) > 0.0:
		return &"Idle"
	return &""
