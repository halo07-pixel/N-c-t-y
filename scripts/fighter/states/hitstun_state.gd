extends FighterState
## Launched by a hit. The fighter cannot act until the stun runs out; the
## launch speed was set by the fighter when the hit arrived.

const SLIDE_FRICTION := 500.0


func physics_update(delta: float) -> StringName:
	fighter.hitstun_frames_left -= 1
	fighter.apply_gravity(delta)
	if fighter.is_on_floor() and fighter.velocity.y >= 0.0:
		fighter.velocity.x = move_toward(fighter.velocity.x, 0.0, SLIDE_FRICTION * delta)
	if fighter.hitstun_frames_left > 0:
		return &""
	if fighter.is_on_floor():
		fighter.notify_landed()
		return &"Idle"
	return &"Fall"
