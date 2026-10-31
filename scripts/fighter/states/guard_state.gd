extends FighterState
## Holding the guard key on the ground. Hits are mostly absorbed (see GuardRules). The first
## frames are the Perfect Guard window. Guard plus a direction steps away with a Shunpo.


func enter(_previous: StringName) -> void:
	fighter.guard_age = 0


func physics_update(delta: float) -> StringName:
	var stats := fighter.data
	fighter.apply_horizontal(delta, 0.0, stats.run_speed, stats.ground_accel, stats.ground_friction)
	fighter.apply_gravity(delta)
	fighter.guard_age += 1

	if not fighter.is_on_floor():
		return &"Fall"
	if fighter.input.attack_just_pressed and fighter.can_throw():
		fighter.begin_throw()
		return &"Attack"
	if fighter.wants_attack():
		return &"Attack"
	if fighter.input.up_just_pressed:
		fighter.start_jump()
		return &"Jump"
	if absf(fighter.input.move.x) > 0.0 and fighter.can_shunpo():
		return &"Shunpo"
	if not fighter.input.guard_held:
		return &"Idle"
	fighter.guard_energy -= GuardRules.DRAIN_PER_FRAME
	if fighter.guard_energy <= 0.0:
		return fighter.break_guard()
	return &""
