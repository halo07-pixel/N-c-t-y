extends FighterState
## Holding the guard key on the ground. Hits are mostly absorbed (see GuardRules). The first
## frames are the parry window. Attack from here (or after a parry) at once; with an opponent right
## in front, attack is a throw. Letting go inside the parry window with nothing hit locks the guard
## for a moment, so tapping guard over and over does not work.


func enter(_previous: StringName) -> void:
	fighter.guard_age = 0
	fighter.guard_acted = false


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
	if not fighter.input.guard_held:
		if fighter.guard_age < GuardRules.PARRY_WINDOW_FRAMES and not fighter.guard_acted:
			fighter.lock_guard()
		return &"Idle"
	fighter.guard_energy -= GuardRules.DRAIN_PER_FRAME
	if fighter.guard_energy <= 0.0:
		return fighter.break_guard()
	return &""
