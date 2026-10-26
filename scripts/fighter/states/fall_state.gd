extends FighterState
## Falling through the air, including walking off an edge and fast-falling.


func physics_update(delta: float) -> StringName:
	var stats := fighter.data
	fighter.face_input()
	fighter.apply_horizontal(delta, fighter.input.move.x, stats.air_speed, stats.air_accel, stats.air_friction)

	if fighter.input.down_just_pressed and fighter.velocity.y >= 0.0:
		fighter.is_fast_falling = true
	fighter.apply_gravity(delta, fighter.is_fast_falling)

	if fighter.input.attack_just_pressed:
		return &"Attack"
	if fighter.input.up_just_pressed and fighter.can_air_jump():
		fighter.start_air_jump()
		return &"Jump"
	if fighter.is_on_floor() and fighter.velocity.y >= 0.0 and not fighter.is_dropping_through():
		fighter.notify_landed()
		if absf(fighter.input.move.x) > 0.0:
			return &"Run"
		return &"Idle"
	return &""
