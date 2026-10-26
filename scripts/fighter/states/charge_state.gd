extends FighterState
## Standing still and gathering Reiatsu while the charge key is held.
## Risky: the fighter can still be hit, but may cancel into a jump or an attack.


func physics_update(delta: float) -> StringName:
	var stats := fighter.data
	fighter.apply_horizontal(delta, 0.0, stats.run_speed, stats.ground_accel, stats.ground_friction)
	fighter.apply_gravity(delta)

	if not fighter.is_on_floor():
		return &"Fall"
	if fighter.wants_attack():
		return &"Attack"
	if fighter.input.up_just_pressed:
		fighter.start_jump()
		return &"Jump"
	if not fighter.input.charge_held:
		return &"Idle"
	fighter.add_reiatsu(Reiatsu.CHARGE_PER_FRAME)
	return &""
