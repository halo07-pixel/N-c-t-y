extends FighterState
## Standing still on the ground.


func physics_update(delta: float) -> StringName:
	var stats := fighter.data
	fighter.apply_horizontal(delta, 0.0, stats.run_speed, stats.ground_accel, stats.ground_friction)
	fighter.apply_gravity(delta)

	if not fighter.is_on_floor():
		return &"Fall"
	if fighter.wants_attack():
		return &"Attack"
	if fighter.input.charge_just_pressed:
		return fighter.charge_press_state()
	if fighter.input.up_just_pressed:
		fighter.start_jump()
		return &"Jump"
	if fighter.input.down_just_pressed and fighter.is_standing_on_soft_platform():
		fighter.start_drop_through()
		return &"Fall"
	if absf(fighter.input.move.x) > 0.0:
		return &"Run"
	return &""
