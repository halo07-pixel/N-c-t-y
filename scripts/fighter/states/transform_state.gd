extends FighterState
## The Bankai transformation: a short invincible power-up, then back to normal
## control with stronger, faster stats and the Bankai special set.

var _frames: int = 0


func enter(_previous: StringName) -> void:
	_frames = 0
	fighter.start_bankai()
	fighter.grant_invincibility(Reiatsu.TRANSFORM_FRAMES)


func physics_update(delta: float) -> StringName:
	var stats := fighter.data
	fighter.apply_horizontal(delta, 0.0, stats.run_speed, stats.ground_accel, stats.ground_friction)
	fighter.apply_gravity(delta)
	_frames += 1
	if _frames < Reiatsu.TRANSFORM_FRAMES:
		return &""
	return &"Idle" if fighter.is_on_floor() else &"Fall"
