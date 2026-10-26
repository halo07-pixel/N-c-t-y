extends FighterState
## Rising after a jump or an air jump.


func physics_update(delta: float) -> StringName:
	var stats := fighter.data
	fighter.face_input()
	fighter.apply_horizontal(delta, fighter.input.move.x, stats.air_speed, stats.air_accel, stats.air_friction)
	fighter.apply_gravity(delta)

	if fighter.wants_attack():
		return &"Attack"
	if fighter.input.up_just_pressed and fighter.can_air_jump():
		fighter.start_air_jump()
		return &""
	if fighter.velocity.y >= 0.0:
		return &"Fall"
	return &""
